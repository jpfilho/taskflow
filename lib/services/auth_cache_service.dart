import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'usuario_service.dart';

/// Cache seguro para sessão/autenticação (email + payload do usuário)
/// Usado para restaurar login em modo offline sem depender de rede.
class AuthCacheService {
  static final AuthCacheService _instance = AuthCacheService._internal();
  factory AuthCacheService() => _instance;
  AuthCacheService._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const String _userJsonKey = 'session_user_json';

  Future<void> saveUser(Usuario usuario) async {
    try {
      final json = jsonEncode(usuario.toMap());
      await _secureStorage.write(key: _userJsonKey, value: json);
    } catch (_) {
      // Falha em cache não deve quebrar o fluxo de login
    }
  }

  Future<Usuario?> loadUser() async {
    try {
      final json = await _secureStorage.read(key: _userJsonKey);
      if (json == null || json.isEmpty) return null;
      final map = jsonDecode(json) as Map<String, dynamic>;
      return Usuario.fromMap(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    try {
      await _secureStorage.delete(key: _userJsonKey);
    } catch (_) {}
  }
}
