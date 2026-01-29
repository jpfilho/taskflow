import 'package:flutter/foundation.dart';

/// Stub do VersionCheckService para plataformas não-web (não faz nada).
class VersionCheckService {
  VersionCheckService._();
  static final VersionCheckService instance = VersionCheckService._();

  final ValueNotifier<bool> hasNewVersion = ValueNotifier<bool>(false);

  void start() {}

  void reloadApp() {}
}
