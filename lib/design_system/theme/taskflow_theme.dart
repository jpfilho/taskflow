import 'package:flutter/material.dart';
import '../../services/theme_service.dart';
import 'taskflow_theme_extension.dart';
import 'taskflow_light_theme.dart';
import 'taskflow_dark_theme.dart';
import 'taskflow_axia_theme.dart';

/// Ponto de entrada unificado para obtenção de ThemeData no TaskFlow.
abstract class TaskFlowTheme {
  /// Retorna o ThemeData correspondente ao [AppTheme] do sistema.
  static ThemeData getThemeData(AppTheme theme, {TaskFlowThemeExtension? customExtension}) {
    switch (theme) {
      case AppTheme.light:
        return buildTaskFlowLightTheme(customExtension: customExtension);
      case AppTheme.dark:
        return buildTaskFlowDarkTheme(customExtension: customExtension);
      case AppTheme.axia:
        return buildTaskFlowAxiaTheme(customExtension: customExtension);
    }
  }

  /// Atalhos diretos
  static ThemeData light({TaskFlowThemeExtension? customExtension}) =>
      buildTaskFlowLightTheme(customExtension: customExtension);

  static ThemeData dark({TaskFlowThemeExtension? customExtension}) =>
      buildTaskFlowDarkTheme(customExtension: customExtension);

  static ThemeData axia({TaskFlowThemeExtension? customExtension}) =>
      buildTaskFlowAxiaTheme(customExtension: customExtension);
}
