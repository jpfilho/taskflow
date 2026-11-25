import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../config/supabase_config.dart';

/// Gerencia o token assinado de sessão para o gateway autenticado de Apoios Operacionais.
/// Isolado por `usuarioId` e armazenado em `FlutterSecureStorage`.
/// Nunca utiliza `service_role` e não altera o fluxo global de login do TaskFlow.
class ApoiosAuthSessionService extends ChangeNotifier {
  static final ApoiosAuthSessionService _instance =
      ApoiosAuthSessionService._internal();
  factory ApoiosAuthSessionService() => _instance;
  ApoiosAuthSessionService._internal();

  static const String _storageKeyPrefix = 'apoios_gateway_token_';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  String? _currentToken;
  String? _currentUserId;

  String? get currentToken => _currentToken;
  String? get currentUserId => _currentUserId;
  bool get hasValidToken =>
      _currentToken != null &&
      _currentToken!.isNotEmpty &&
      !_isJwtExpired(_currentToken!);

  Future<void> setToken({
    required String usuarioId,
    required String token,
  }) async {
    _currentUserId = usuarioId;
    _currentToken = token;
    try {
      await _secureStorage.write(
        key: '$_storageKeyPrefix$usuarioId',
        value: token,
      );
    } catch (_) {
      // Ignorar falha de secure storage em ambientes de teste sem plugin
    }
    notifyListeners();
  }

  Future<String?> restoreTokenForUser(String usuarioId) async {
    try {
      final saved = await _secureStorage.read(
        key: '$_storageKeyPrefix$usuarioId',
      );
      if (saved != null && saved.isNotEmpty && !_isJwtExpired(saved)) {
        _currentUserId = usuarioId;
        _currentToken = saved;
        notifyListeners();
        return saved;
      }
    } catch (_) {}
    return null;
  }

  Future<bool> authenticateWithPassword({
    required String email,
    required String password,
    http.Client? httpClient,
  }) async {
    final client = httpClient ?? http.Client();
    try {
      final url = Uri.parse('${SupabaseConfig.apiBaseUrl}/auth/apoios-login');
      final response = await client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email.trim().toLowerCase(),
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return false;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['ok'] != true) return false;
      final token = data['token']?.toString();
      final userId = (data['usuario'] as Map?)?['id']?.toString();
      if (token == null || token.isEmpty || userId == null || userId.isEmpty) {
        return false;
      }
      await setToken(usuarioId: userId, token: token);
      return true;
    } catch (_) {
      return false;
    } finally {
      if (httpClient == null) client.close();
    }
  }

  Future<bool> exchangeSupabaseSession({http.Client? httpClient}) async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null || session.accessToken.isEmpty) return false;
      final client = httpClient ?? http.Client();
      try {
        final url =
            Uri.parse('${SupabaseConfig.apiBaseUrl}/auth/apoios-exchange');
        final response = await client
            .post(
              url,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ${session.accessToken}',
              },
            )
            .timeout(const Duration(seconds: 8));

        if (response.statusCode != 200) return false;
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['ok'] != true) return false;
        final token = data['token']?.toString();
        final userId = (data['usuario'] as Map?)?['id']?.toString();
        if (token == null ||
            token.isEmpty ||
            userId == null ||
            userId.isEmpty) {
          return false;
        }
        await setToken(usuarioId: userId, token: token);
        return true;
      } finally {
        if (httpClient == null) client.close();
      }
    } catch (_) {
      return false;
    }
  }

  Future<void> clearSession({
    String? usuarioId,
    http.Client? httpClient,
  }) async {
    final tokenToRevoke = _currentToken;
    final targetUser = usuarioId ?? _currentUserId;
    _currentToken = null;
    _currentUserId = null;

    if (tokenToRevoke != null && tokenToRevoke.isNotEmpty) {
      final client = httpClient ?? http.Client();
      try {
        final url = Uri.parse('${SupabaseConfig.apiBaseUrl}/auth/apoios-logout');
        await client
            .post(
              url,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $tokenToRevoke',
              },
            )
            .timeout(const Duration(seconds: 4));
      } catch (_) {
        // Sem bloqueio offline ao fazer logout local
      } finally {
        if (httpClient == null) client.close();
      }
    }

    if (targetUser != null && targetUser.isNotEmpty) {
      try {
        await _secureStorage.delete(key: '$_storageKeyPrefix$targetUser');
      } catch (_) {}
    }
    notifyListeners();
  }

  static bool _isJwtExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final normalized = base64Url.normalize(parts[1]);
      final payload =
          jsonDecode(utf8.decode(base64Url.decode(normalized))) as Map;
      final exp = (payload['exp'] as num?)?.toInt();
      if (exp == null) return true;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return exp <= now + 30;
    } catch (_) {
      return true;
    }
  }
}

