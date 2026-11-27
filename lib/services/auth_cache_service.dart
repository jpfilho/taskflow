import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    final json = jsonEncode(usuario.toMap());
    try {
      await _secureStorage.write(key: _userJsonKey, value: json);
    } catch (_) {
      // Falha em cache não deve quebrar o fluxo de login (ex.: Web HTTP sem crypto.subtle)
    }
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userJsonKey, json);
      } catch (_) {}
    }
  }

  Future<Usuario?> loadUser() async {
    String? json;
    try {
      json = await _secureStorage.read(key: _userJsonKey);
    } catch (_) {
      json = null;
    }
    if ((json == null || json.isEmpty) && kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        json = prefs.getString(_userJsonKey);
      } catch (_) {
        json = null;
      }
    }
    if (json == null || json.isEmpty) return null;
    try {
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
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_userJsonKey);
      } catch (_) {}
    }
  }
}
