import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // Verificar se o dispositivo suporta autenticação biométrica
  Future<bool> isDeviceSupported() async {
    if (kIsWeb) return false;
    try {
      return await _localAuth.isDeviceSupported();
    } catch (e) {
      print('Erro ao verificar suporte biométrico: $e');
      return false;
    }
  }

  // Verificar se há biometria disponível
  Future<bool> canCheckBiometrics() async {
    if (kIsWeb) return false;
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      print('Erro ao verificar biometria: $e');
      return false;
    }
  }

  // Obter tipos de biometria disponíveis
  Future<List<BiometricType>> getAvailableBiometrics() async {
    if (kIsWeb) return [];
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      print('Erro ao obter biometrias disponíveis: $e');
      return [];
    }
  }

  // Verificar se há credenciais salvas
  Future<bool> hasSavedCredentials() async {
    try {
      final email = await _secureStorage.read(key: 'saved_email');
      final password = await _secureStorage.read(key: 'saved_password');
      return email != null && password != null && email.isNotEmpty && password.isNotEmpty;
    } catch (e) {
      print('Erro ao verificar credenciais salvas: $e');
      return false;
    }
  }

  // Salvar credenciais de forma segura
  Future<void> saveCredentials(String email, String password) async {
    try {
      await _secureStorage.write(key: 'saved_email', value: email);
      await _secureStorage.write(key: 'saved_password', value: password);
    } catch (e) {
      print('Erro ao salvar credenciais: $e');
    }
  }

  // Obter credenciais salvas
  Future<Map<String, String?>> getSavedCredentials() async {
    try {
      final email = await _secureStorage.read(key: 'saved_email');
      final password = await _secureStorage.read(key: 'saved_password');
      return {'email': email, 'password': password};
    } catch (e) {
      print('Erro ao obter credenciais: $e');
      return {'email': null, 'password': null};
    }
  }

  // Remover credenciais salvas
  Future<void> clearSavedCredentials() async {
    try {
      await _secureStorage.delete(key: 'saved_email');
      await _secureStorage.delete(key: 'saved_password');
    } catch (e) {
      print('Erro ao remover credenciais: $e');
    }
  }

  // Autenticar com biometria
  Future<bool> authenticate() async {
    try {
      // Verificar se há biometria disponível
      final canCheck = await canCheckBiometrics();
      if (!canCheck) {
        return false;
      }

      // Verificar se há credenciais salvas
      final hasCredentials = await hasSavedCredentials();
      if (!hasCredentials) {
        return false;
      }

      // Obter tipos de biometria disponíveis
      final availableBiometrics = await getAvailableBiometrics();
      
      // Determinar o tipo de biometria para a mensagem
      String biometricType = 'biometria';
      if (availableBiometrics.contains(BiometricType.face)) {
        biometricType = 'Face ID';
      } else if (availableBiometrics.contains(BiometricType.fingerprint)) {
        biometricType = 'impressão digital';
      } else if (availableBiometrics.contains(BiometricType.strong)) {
        biometricType = 'autenticação forte';
      }

      // Tentar autenticar
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Use $biometricType para fazer login',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      return didAuthenticate;
    } catch (e) {
      print('Erro na autenticação biométrica: $e');
      return false;
    }
  }

  // Verificar se deve mostrar opção de biometria
  Future<bool> shouldShowBiometricOption() async {
    try {
      final isSupported = await isDeviceSupported();
      final canCheck = await canCheckBiometrics();
      final hasCredentials = await hasSavedCredentials();
      
      return isSupported && canCheck && hasCredentials;
    } catch (e) {
      print('Erro ao verificar opção biométrica: $e');
      return false;
    }
  }

  // Obter texto do botão de biometria
  Future<String> getBiometricButtonText() async {
    try {
      final availableBiometrics = await getAvailableBiometrics();
      
      if (availableBiometrics.contains(BiometricType.face)) {
        return 'Entrar com Face ID';
      } else if (availableBiometrics.contains(BiometricType.fingerprint)) {
        return 'Entrar com Impressão Digital';
      } else if (availableBiometrics.contains(BiometricType.strong)) {
        return 'Entrar com Autenticação Forte';
      } else {
        return 'Entrar com Biometria';
      }
    } catch (e) {
      return 'Entrar com Biometria';
    }
  }

  // Obter ícone de biometria
  Future<IconData> getBiometricIcon() async {
    try {
      final availableBiometrics = await getAvailableBiometrics();
      
      if (availableBiometrics.contains(BiometricType.face)) {
        return Icons.face;
      } else if (availableBiometrics.contains(BiometricType.fingerprint)) {
        return Icons.fingerprint;
      } else {
        return Icons.security;
      }
    } catch (e) {
      return Icons.security;
    }
  }
}

