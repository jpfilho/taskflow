import 'package:flutter/material.dart';

/// Paleta de cores com alto contraste otimizada para uso sob luz solar e modo escuro.
abstract class TFMobileColors {
  // Brand Corporativo
  static const Color primaryBlue = Color(0xFF1D4ED8); // Azul forte para destaque
  static const Color primaryHover = Color(0xFF1E40AF);
  static const Color primaryDark = Color(0xFF172554);

  // Neutros Light (Alto contraste sobre fundos claros)
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFCBD5E1); // Borda visível sob sol
  static const Color lightBorderStrong = Color(0xFF94A3B8);
  static const Color lightTextPrimary = Color(0xFF0F172A); // Quase preto para máxima nitidez
  static const Color lightTextSecondary = Color(0xFF334155); // Cinza escuro legível
  static const Color lightTextMuted = Color(0xFF64748B);

  // Neutros Dark
  static const Color darkBackground = Color(0xFF0B0F19);
  static const Color darkSurface = Color(0xFF151C2C);
  static const Color darkBorder = Color(0xFF2E3A52);
  static const Color darkBorderStrong = Color(0xFF475569);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFFCBD5E1);
  static const Color darkTextMuted = Color(0xFF94A3B8);

  // Ações de Sucesso, Alerta e Perigo
  static const Color success = Color(0xFF15803D); // Verde contrastante
  static const Color successBg = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFB45309); // Âmbar contrastante
  static const Color warningBg = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFB91C1C); // Vermelho contrastante
  static const Color errorBg = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF1D4ED8);
  static const Color infoBg = Color(0xFFDBEAFE);

  // Helpers contextuais
  static Color background(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkBackground
        : lightBackground;
  }

  static Color surface(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkSurface
        : lightSurface;
  }

  static Color border(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkBorder
        : lightBorder;
  }

  static Color textPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkTextPrimary
        : lightTextPrimary;
  }

  static Color textSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkTextSecondary
        : lightTextSecondary;
  }
}
