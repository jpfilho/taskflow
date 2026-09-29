import 'package:flutter/material.dart';

/// Paleta de cores primitivas (valores absolutos) do TaskFlow.
/// Não deve ser consumida diretamente por componentes finais;
/// utilize sempre [TFSemanticColors] via tema.
abstract class TFPrimitiveColors {
  // Brand / Navy Corporativo
  static const Color navy50 = Color(0xFFEFF6FF);
  static const Color navy100 = Color(0xFFDBEAFE);
  static const Color navy700 = Color(0xFF1D4ED8);
  static const Color navy800 = Color(0xFF1E3A5F); // Identidade TaskFlow
  static const Color navy900 = Color(0xFF0F172A);
  static const Color navy950 = Color(0xFF0A003C); // Axia Navy

  // Blue (Ação primária moderna)
  static const Color blue50 = Color(0xFFEFF6FF);
  static const Color blue100 = Color(0xFFDBEAFE);
  static const Color blue200 = Color(0xFFBFDBFE);
  static const Color blue300 = Color(0xFF93C5FD);
  static const Color blue400 = Color(0xFF60A5FA);
  static const Color blue500 = Color(0xFF3B82F6);
  static const Color blue600 = Color(0xFF2563EB);
  static const Color blue700 = Color(0xFF1D4ED8);
  static const Color blue800 = Color(0xFF1E40AF);
  static const Color blue900 = Color(0xFF1E3A8A);

  // Slate (Neutros operacionais)
  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate900 = Color(0xFF0F172A);
  static const Color slate950 = Color(0xFF020617);

  // Green / Sucesso
  static const Color green50 = Color(0xFFF0FDF4);
  static const Color green100 = Color(0xFFDCFCE7);
  static const Color green500 = Color(0xFF22C55E);
  static const Color green600 = Color(0xFF16A34A);
  static const Color green700 = Color(0xFF15803D);

  // Amber / Alerta
  static const Color amber50 = Color(0xFFFFFBEB);
  static const Color amber100 = Color(0xFFFEF3C7);
  static const Color amber400 = Color(0xFFFBBF24);
  static const Color amber500 = Color(0xFFF59E0B);
  static const Color amber600 = Color(0xFFD97706);
  static const Color amber700 = Color(0xFFB45309);

  // Red / Crítico
  static const Color red50 = Color(0xFFFEF2F2);
  static const Color red100 = Color(0xFFFEE2E2);
  static const Color red500 = Color(0xFFEF4444);
  static const Color red600 = Color(0xFFDC2626);
  static const Color red700 = Color(0xFFB91C1C);

  // Axia Brand Colors
  static const Color axiaBlue = Color(0xFF0000FF);
  static const Color axiaNavy = Color(0xFF0A003C);
  static const Color axiaOffWhite = Color(0xFFFAF5F0);
  static const Color axiaGray = Color(0xFFA0B4D2);
  static const Color axiaYellow = Color(0xFFF9B50B);
}

/// Conjunto completo de tokens de cores semânticas do TaskFlow Design System.
@immutable
class TFSemanticColors {
  // Ação primária
  final Color primary;
  final Color primaryHover;
  final Color primaryPressed;
  final Color primaryForeground;

  // Superfícies
  final Color background;
  final Color surface;
  final Color surfaceSecondary;
  final Color surfaceElevated;

  // Textos
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textDisabled;
  final Color textInverse;

  // Bordas
  final Color borderSubtle;
  final Color borderDefault;
  final Color borderStrong;
  final Color borderFocus;

  // Feedback: Sucesso
  final Color success;
  final Color successForeground;
  final Color successBackground;

  // Feedback: Alerta
  final Color warning;
  final Color warningForeground;
  final Color warningBackground;

  // Feedback: Perigo / Crítico
  final Color danger;
  final Color dangerForeground;
  final Color dangerBackground;

  // Feedback: Informativo
  final Color info;
  final Color infoForeground;
  final Color infoBackground;

  // Estados de Interação
  final Color hover;
  final Color selected;
  final Color focus;
  final Color disabled;

  const TFSemanticColors({
    required this.primary,
    required this.primaryHover,
    required this.primaryPressed,
    required this.primaryForeground,
    required this.background,
    required this.surface,
    required this.surfaceSecondary,
    required this.surfaceElevated,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textDisabled,
    required this.textInverse,
    required this.borderSubtle,
    required this.borderDefault,
    required this.borderStrong,
    required this.borderFocus,
    required this.success,
    required this.successForeground,
    required this.successBackground,
    required this.warning,
    required this.warningForeground,
    required this.warningBackground,
    required this.danger,
    required this.dangerForeground,
    required this.dangerBackground,
    required this.info,
    required this.infoForeground,
    required this.infoBackground,
    required this.hover,
    required this.selected,
    required this.focus,
    required this.disabled,
  });

  /// Configuração de cores para o Tema Claro (Light)
  factory TFSemanticColors.light() {
    return const TFSemanticColors(
      primary: TFPrimitiveColors.blue600,
      primaryHover: TFPrimitiveColors.blue700,
      primaryPressed: TFPrimitiveColors.blue800,
      primaryForeground: Colors.white,

      background: TFPrimitiveColors.slate50,
      surface: Colors.white,
      surfaceSecondary: TFPrimitiveColors.slate100,
      surfaceElevated: Colors.white,

      textPrimary: TFPrimitiveColors.slate900,
      textSecondary: TFPrimitiveColors.slate600,
      textMuted: TFPrimitiveColors.slate400,
      textDisabled: Color(0xFF94A3B8),
      textInverse: Colors.white,

      borderSubtle: TFPrimitiveColors.slate200,
      borderDefault: TFPrimitiveColors.slate300,
      borderStrong: TFPrimitiveColors.slate400,
      borderFocus: TFPrimitiveColors.blue500,

      success: TFPrimitiveColors.green600,
      successForeground: Colors.white,
      successBackground: TFPrimitiveColors.green100,

      warning: TFPrimitiveColors.amber600,
      warningForeground: TFPrimitiveColors.slate900,
      warningBackground: TFPrimitiveColors.amber100,

      danger: TFPrimitiveColors.red600,
      dangerForeground: Colors.white,
      dangerBackground: TFPrimitiveColors.red100,

      info: TFPrimitiveColors.blue600,
      infoForeground: Colors.white,
      infoBackground: TFPrimitiveColors.blue100,

      hover: Color(0x0A0F172A),
      selected: Color(0x142563EB),
      focus: Color(0x333B82F6),
      disabled: Color(0xFFE2E8F0),
    );
  }

  /// Configuração de cores para o Tema Escuro (Dark)
  factory TFSemanticColors.dark() {
    return const TFSemanticColors(
      primary: TFPrimitiveColors.blue500,
      primaryHover: TFPrimitiveColors.blue400,
      primaryPressed: TFPrimitiveColors.blue600,
      primaryForeground: Colors.white,

      background: TFPrimitiveColors.slate950,
      surface: TFPrimitiveColors.slate900,
      surfaceSecondary: TFPrimitiveColors.slate800,
      surfaceElevated: Color(0xFF1E293B),

      textPrimary: TFPrimitiveColors.slate50,
      textSecondary: TFPrimitiveColors.slate300,
      textMuted: TFPrimitiveColors.slate400,
      textDisabled: TFPrimitiveColors.slate600,
      textInverse: TFPrimitiveColors.slate900,

      borderSubtle: TFPrimitiveColors.slate800,
      borderDefault: TFPrimitiveColors.slate700,
      borderStrong: TFPrimitiveColors.slate600,
      borderFocus: TFPrimitiveColors.blue400,

      success: TFPrimitiveColors.green500,
      successForeground: TFPrimitiveColors.slate950,
      successBackground: Color(0xFF052E16),

      warning: TFPrimitiveColors.amber400,
      warningForeground: TFPrimitiveColors.slate950,
      warningBackground: Color(0xFF451A03),

      danger: TFPrimitiveColors.red500,
      dangerForeground: Colors.white,
      dangerBackground: Color(0xFF450A0A),

      info: TFPrimitiveColors.blue400,
      infoForeground: TFPrimitiveColors.slate950,
      infoBackground: Color(0xFF172554),

      hover: Color(0x14FFFFFF),
      selected: Color(0x283B82F6),
      focus: Color(0x4D60A5FA),
      disabled: TFPrimitiveColors.slate800,
    );
  }

  /// Configuração de cores para a identidade temática AXIA
  factory TFSemanticColors.axia() {
    return const TFSemanticColors(
      primary: TFPrimitiveColors.axiaBlue,
      primaryHover: Color(0xFF0000CC),
      primaryPressed: Color(0xFF000099),
      primaryForeground: Colors.white,

      background: TFPrimitiveColors.axiaOffWhite,
      surface: Colors.white,
      surfaceSecondary: Color(0xFFE9F0FA),
      surfaceElevated: Colors.white,

      textPrimary: TFPrimitiveColors.axiaNavy,
      textSecondary: Color(0xFF2A3950),
      textMuted: Color(0xFF6B7E98),
      textDisabled: TFPrimitiveColors.axiaGray,
      textInverse: TFPrimitiveColors.axiaOffWhite,

      borderSubtle: Color(0xFFD6E2F0),
      borderDefault: TFPrimitiveColors.axiaGray,
      borderStrong: Color(0xFF6B87B5),
      borderFocus: TFPrimitiveColors.axiaBlue,

      success: TFPrimitiveColors.green600,
      successForeground: Colors.white,
      successBackground: TFPrimitiveColors.green100,

      warning: TFPrimitiveColors.axiaYellow,
      warningForeground: TFPrimitiveColors.axiaNavy,
      warningBackground: Color(0xFFFEF7DC),

      danger: TFPrimitiveColors.red600,
      dangerForeground: Colors.white,
      dangerBackground: TFPrimitiveColors.red100,

      info: TFPrimitiveColors.axiaBlue,
      infoForeground: Colors.white,
      infoBackground: Color(0xFFE0E7FF),

      hover: Color(0x0F0A003C),
      selected: Color(0x1F0000FF),
      focus: Color(0x400000FF),
      disabled: Color(0xFFDDE5F0),
    );
  }

  TFSemanticColors copyWith({
    Color? primary,
    Color? primaryHover,
    Color? primaryPressed,
    Color? primaryForeground,
    Color? background,
    Color? surface,
    Color? surfaceSecondary,
    Color? surfaceElevated,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? textDisabled,
    Color? textInverse,
    Color? borderSubtle,
    Color? borderDefault,
    Color? borderStrong,
    Color? borderFocus,
    Color? success,
    Color? successForeground,
    Color? successBackground,
    Color? warning,
    Color? warningForeground,
    Color? warningBackground,
    Color? danger,
    Color? dangerForeground,
    Color? dangerBackground,
    Color? info,
    Color? infoForeground,
    Color? infoBackground,
    Color? hover,
    Color? selected,
    Color? focus,
    Color? disabled,
  }) {
    return TFSemanticColors(
      primary: primary ?? this.primary,
      primaryHover: primaryHover ?? this.primaryHover,
      primaryPressed: primaryPressed ?? this.primaryPressed,
      primaryForeground: primaryForeground ?? this.primaryForeground,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceSecondary: surfaceSecondary ?? this.surfaceSecondary,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      textDisabled: textDisabled ?? this.textDisabled,
      textInverse: textInverse ?? this.textInverse,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      borderDefault: borderDefault ?? this.borderDefault,
      borderStrong: borderStrong ?? this.borderStrong,
      borderFocus: borderFocus ?? this.borderFocus,
      success: success ?? this.success,
      successForeground: successForeground ?? this.successForeground,
      successBackground: successBackground ?? this.successBackground,
      warning: warning ?? this.warning,
      warningForeground: warningForeground ?? this.warningForeground,
      warningBackground: warningBackground ?? this.warningBackground,
      danger: danger ?? this.danger,
      dangerForeground: dangerForeground ?? this.dangerForeground,
      dangerBackground: dangerBackground ?? this.dangerBackground,
      info: info ?? this.info,
      infoForeground: infoForeground ?? this.infoForeground,
      infoBackground: infoBackground ?? this.infoBackground,
      hover: hover ?? this.hover,
      selected: selected ?? this.selected,
      focus: focus ?? this.focus,
      disabled: disabled ?? this.disabled,
    );
  }

  static TFSemanticColors lerp(TFSemanticColors a, TFSemanticColors b, double t) {
    return TFSemanticColors(
      primary: Color.lerp(a.primary, b.primary, t)!,
      primaryHover: Color.lerp(a.primaryHover, b.primaryHover, t)!,
      primaryPressed: Color.lerp(a.primaryPressed, b.primaryPressed, t)!,
      primaryForeground: Color.lerp(a.primaryForeground, b.primaryForeground, t)!,
      background: Color.lerp(a.background, b.background, t)!,
      surface: Color.lerp(a.surface, b.surface, t)!,
      surfaceSecondary: Color.lerp(a.surfaceSecondary, b.surfaceSecondary, t)!,
      surfaceElevated: Color.lerp(a.surfaceElevated, b.surfaceElevated, t)!,
      textPrimary: Color.lerp(a.textPrimary, b.textPrimary, t)!,
      textSecondary: Color.lerp(a.textSecondary, b.textSecondary, t)!,
      textMuted: Color.lerp(a.textMuted, b.textMuted, t)!,
      textDisabled: Color.lerp(a.textDisabled, b.textDisabled, t)!,
      textInverse: Color.lerp(a.textInverse, b.textInverse, t)!,
      borderSubtle: Color.lerp(a.borderSubtle, b.borderSubtle, t)!,
      borderDefault: Color.lerp(a.borderDefault, b.borderDefault, t)!,
      borderStrong: Color.lerp(a.borderStrong, b.borderStrong, t)!,
      borderFocus: Color.lerp(a.borderFocus, b.borderFocus, t)!,
      success: Color.lerp(a.success, b.success, t)!,
      successForeground: Color.lerp(a.successForeground, b.successForeground, t)!,
      successBackground: Color.lerp(a.successBackground, b.successBackground, t)!,
      warning: Color.lerp(a.warning, b.warning, t)!,
      warningForeground: Color.lerp(a.warningForeground, b.warningForeground, t)!,
      warningBackground: Color.lerp(a.warningBackground, b.warningBackground, t)!,
      danger: Color.lerp(a.danger, b.danger, t)!,
      dangerForeground: Color.lerp(a.dangerForeground, b.dangerForeground, t)!,
      dangerBackground: Color.lerp(a.dangerBackground, b.dangerBackground, t)!,
      info: Color.lerp(a.info, b.info, t)!,
      infoForeground: Color.lerp(a.infoForeground, b.infoForeground, t)!,
      infoBackground: Color.lerp(a.infoBackground, b.infoBackground, t)!,
      hover: Color.lerp(a.hover, b.hover, t)!,
      selected: Color.lerp(a.selected, b.selected, t)!,
      focus: Color.lerp(a.focus, b.focus, t)!,
      disabled: Color.lerp(a.disabled, b.disabled, t)!,
    );
  }
}
