import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:msal_flutter/msal_flutter.dart';

import '../config/azure_auth_config.dart';

class AzureLoginResult {
  final bool sucesso;
  final String? email;
  final String? idToken;
  final String? accessToken;
  final String? erro;

  AzureLoginResult({
    required this.sucesso,
    this.email,
    this.idToken,
    this.accessToken,
    this.erro,
  });
}

/// Serviço para autenticação interativa via Entra ID (Azure AD) usando MSAL.
class AzureAuthService {
  PublicClientApplication? _pca;

  Future<PublicClientApplication> _getPca() async {
    if (kIsWeb) {
      throw Exception('Login Microsoft via MSAL (flutter) não é suportado no Web. Use fluxo OAuth JS.');
    }
    if (_pca != null) return _pca!;

    if (azureClientId.startsWith('PREENCHER') ||
        azureTenantId.startsWith('PREENCHER')) {
      throw Exception('Configure azureClientId e azureTenantId em azure_auth_config.dart');
    }

    _pca = await PublicClientApplication.createPublicClientApplication(
      azureClientId,
      authority: azureAuthority,
      redirectUri: azureRedirectUri,
    );
    return _pca!;
  }

  Future<AzureLoginResult> signInInteractive() async {
    try {
      final pca = await _getPca();
      const scopes = ['openid', 'profile', 'email'];

      final token = await pca.acquireToken(scopes);
      if (token.isEmpty) {
        return AzureLoginResult(sucesso: false, erro: 'Token vazio retornado');
      }

      final email = _decodeEmailFromToken(token);

      return AzureLoginResult(
        sucesso: true,
        email: email,
        idToken: null,
        accessToken: token,
      );
    } catch (e) {
      return AzureLoginResult(sucesso: false, erro: e.toString());
    }
  }

  Future<void> signOut() async {
    try {
      final pca = await _getPca();
      await pca.logout();
    } catch (_) {
      // Ignorar erros silenciosamente
    }
  }

  String? _decodeEmailFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return null;
      final normalized = base64Url.normalize(parts[1]);
      final payload = utf8.decode(base64Url.decode(normalized));
      final map = json.decode(payload) as Map<String, dynamic>;
      return (map['preferred_username'] ??
              map['upn'] ??
              map['email'] ??
              map['unique_name'])
          ?.toString();
    } catch (_) {
      return null;
    }
  }
}
