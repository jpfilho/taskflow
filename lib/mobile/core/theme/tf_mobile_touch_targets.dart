import 'package:flutter/material.dart';

/// Constantes oficiais de Touch Targets do TaskFlow Mobile.
/// Regra estrita: Nenhuma ação primária ou interativa deve possuir área < 48x48px.
abstract class TFMobileTouchTargets {
  /// Área mínima absoluta para qualquer elemento tocável (padrão WCAG / Material).
  static const double min = 48.0;

  /// Altura padrão para botões de formulário, tabs e ações operacionais cotidianas.
  static const double standard = 52.0;

  /// Altura para botões primários críticos de campo (Iniciar, Concluir, Foto, Enviar).
  static const double large = 56.0;

  /// Dimensões mínimas de BoxConstraints para botões de ícone (IconButton).
  static const BoxConstraints minIconConstraints = BoxConstraints(
    minWidth: min,
    minHeight: min,
  );

  /// Dimensões padrão para Floating Action Buttons operacionais.
  static const double fabSize = 56.0;
  static const double fabLarge = 64.0;
}
