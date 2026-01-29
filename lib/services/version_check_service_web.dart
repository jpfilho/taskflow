import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Verifica periodicamente se há nova versão da aplicação (version.txt no servidor).
/// Só ativo na web. Ao detectar nova versão, [hasNewVersion] fica true e o app
/// pode mostrar um banner com botão "Atualizar"; [reloadApp] recarrega a página.
class VersionCheckService {
  VersionCheckService._();
  static final VersionCheckService instance = VersionCheckService._();

  final ValueNotifier<bool> hasNewVersion = ValueNotifier<bool>(false);

  String? _currentVersion;
  static const _checkInterval = Duration(minutes: 3);

  void start() {
    _currentVersion = null;
    _checkVersion();
    Timer.periodic(_checkInterval, (_) => _checkVersion());
    html.document.addEventListener('visibilitychange', _onVisibilityChange);
  }

  void _onVisibilityChange(html.Event _) {
    if (html.document.visibilityState == 'visible') {
      _checkVersion();
    }
  }

  Future<void> _checkVersion() async {
    try {
      final url = Uri.base.resolve('version.txt').replace(
        queryParameters: {'t': '${DateTime.now().millisecondsSinceEpoch}'},
      );
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () => http.Response('', 408),
      );

      if (response.statusCode != 200) return;
      final serverVersion = response.body.trim();
      if (serverVersion.isEmpty) return;

      if (_currentVersion == null) {
        _currentVersion = serverVersion;
        if (kDebugMode) {
          print('📌 Versão atual da aplicação: $serverVersion');
        }
        return;
      }

      if (_currentVersion != serverVersion) {
        _currentVersion = serverVersion;
        hasNewVersion.value = true;
        if (kDebugMode) {
          print('🆕 Nova versão disponível: $serverVersion');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ VersionCheckService: $e');
      }
    }
  }

  void reloadApp() {
    html.window.location.reload();
  }
}
