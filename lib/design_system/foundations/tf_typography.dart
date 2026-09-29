import 'package:flutter/material.dart';

/// Escala tipográfica formal do TaskFlow Design System.
/// Projetada para alta legibilidade em interfaces de dados densos e corporativas.
@immutable
class TFTypography {
  final TextStyle display;
  final TextStyle pageTitle;
  final TextStyle sectionTitle;
  final TextStyle cardTitle;
  final TextStyle bodyLarge;
  final TextStyle bodyMedium;
  final TextStyle bodySmall;
  final TextStyle labelLarge;
  final TextStyle labelMedium;
  final TextStyle labelSmall;
  final TextStyle caption;
  final TextStyle micro;

  const TFTypography({
    required this.display,
    required this.pageTitle,
    required this.sectionTitle,
    required this.cardTitle,
    required this.bodyLarge,
    required this.bodyMedium,
    required this.bodySmall,
    required this.labelLarge,
    required this.labelMedium,
    required this.labelSmall,
    required this.caption,
    required this.micro,
  });

  /// Conjunto padrão de estilos tipográficos com números tabulares para alinhamento de dados.
  factory TFTypography.regular() {
    const defaultFontFeatures = [FontFeature.tabularFigures()];

    return const TFTypography(
      // Display: Grande indicador em Dashboards e KPIs
      display: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.5,
        fontFeatures: defaultFontFeatures,
      ),

      // Page Title: Título principal de página (PageHeader)
      pageTitle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.25,
        letterSpacing: -0.3,
        fontFeatures: defaultFontFeatures,
      ),

      // Section Title: Cabeçalho de seções e modais
      sectionTitle: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: -0.2,
        fontFeatures: defaultFontFeatures,
      ),

      // Card Title: Título interno de cards
      cardTitle: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.35,
        letterSpacing: -0.1,
        fontFeatures: defaultFontFeatures,
      ),

      // Body Large: Entradas de texto e botões primários
      bodyLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.4,
        letterSpacing: 0.0,
        fontFeatures: defaultFontFeatures,
      ),

      // Body Medium: Texto padrão de leitura e menus
      bodyMedium: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.35,
        letterSpacing: 0.0,
        fontFeatures: defaultFontFeatures,
      ),

      // Body Small: Células de tabelas densas operacionais (TaskTable / Notas SAP)
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.3,
        letterSpacing: 0.0,
        fontFeatures: defaultFontFeatures,
      ),

      // Labels: Botões e identificadores
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: 0.1,
        fontFeatures: defaultFontFeatures,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: 0.1,
        fontFeatures: defaultFontFeatures,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 1.2,
        letterSpacing: 0.2,
        fontFeatures: defaultFontFeatures,
      ),

      // Caption: Metadados, datas secundárias, breadcrumbs
      caption: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        height: 1.25,
        letterSpacing: 0.1,
        fontFeatures: defaultFontFeatures,
      ),

      // Micro: Badges de status compactos, pílulas de prazo SAP, escalas de Gantt
      micro: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: 0.2,
        fontFeatures: defaultFontFeatures,
      ),
    );
  }

  TFTypography copyWith({
    TextStyle? display,
    TextStyle? pageTitle,
    TextStyle? sectionTitle,
    TextStyle? cardTitle,
    TextStyle? bodyLarge,
    TextStyle? bodyMedium,
    TextStyle? bodySmall,
    TextStyle? labelLarge,
    TextStyle? labelMedium,
    TextStyle? labelSmall,
    TextStyle? caption,
    TextStyle? micro,
  }) {
    return TFTypography(
      display: display ?? this.display,
      pageTitle: pageTitle ?? this.pageTitle,
      sectionTitle: sectionTitle ?? this.sectionTitle,
      cardTitle: cardTitle ?? this.cardTitle,
      bodyLarge: bodyLarge ?? this.bodyLarge,
      bodyMedium: bodyMedium ?? this.bodyMedium,
      bodySmall: bodySmall ?? this.bodySmall,
      labelLarge: labelLarge ?? this.labelLarge,
      labelMedium: labelMedium ?? this.labelMedium,
      labelSmall: labelSmall ?? this.labelSmall,
      caption: caption ?? this.caption,
      micro: micro ?? this.micro,
    );
  }

  static TFTypography lerp(TFTypography a, TFTypography b, double t) {
    return TFTypography(
      display: TextStyle.lerp(a.display, b.display, t)!,
      pageTitle: TextStyle.lerp(a.pageTitle, b.pageTitle, t)!,
      sectionTitle: TextStyle.lerp(a.sectionTitle, b.sectionTitle, t)!,
      cardTitle: TextStyle.lerp(a.cardTitle, b.cardTitle, t)!,
      bodyLarge: TextStyle.lerp(a.bodyLarge, b.bodyLarge, t)!,
      bodyMedium: TextStyle.lerp(a.bodyMedium, b.bodyMedium, t)!,
      bodySmall: TextStyle.lerp(a.bodySmall, b.bodySmall, t)!,
      labelLarge: TextStyle.lerp(a.labelLarge, b.labelLarge, t)!,
      labelMedium: TextStyle.lerp(a.labelMedium, b.labelMedium, t)!,
      labelSmall: TextStyle.lerp(a.labelSmall, b.labelSmall, t)!,
      caption: TextStyle.lerp(a.caption, b.caption, t)!,
      micro: TextStyle.lerp(a.micro, b.micro, t)!,
    );
  }
}
