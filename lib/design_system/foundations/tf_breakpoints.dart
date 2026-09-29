import 'package:flutter/material.dart';

/// Classificação formal do dispositivo para estratégias de layout.
enum TFDeviceType {
  mobile,
  tablet,
  laptop,
  desktop,
  ultraWide,
}

/// Breakpoints centrais do TaskFlow Design System.
/// Substitui os valores fixos legados de responsive.dart.
abstract class TFBreakpoints {
  // Limites numéricos de largura em pixels
  static const double xs = 480.0; // Celulares compactos
  static const double sm = 768.0; // Celulares amplos / Tablets estreitos (limite mobile)
  static const double md = 1024.0; // Tablets em paisagem / Laptops pequenos
  static const double lg = 1366.0; // Laptops padrão corporativos
  static const double xl = 1920.0; // Monitores Full HD / Desktop padrão
  static const double xxl = 2560.0; // Monitores 2K / 4K / Ultrawide

  /// Retorna se o contexto atual é Mobile (< 768px).
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < sm;
  }

  /// Retorna se o contexto atual é Tablet (>= 768px e < 1024px).
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= sm && width < md;
  }

  /// Retorna se o contexto atual é Desktop/Laptop (>= 1024px).
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= md;
  }

  /// Retorna se o contexto atual é um Desktop Grande (>= 1366px).
  static bool isLargeDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= lg;
  }

  /// Retorna se o contexto atual é Ultrawide (>= 1920px).
  static bool isUltraWide(BuildContext context) {
    return MediaQuery.of(context).size.width >= xl;
  }

  /// Retorna a categoria formal do dispositivo.
  static TFDeviceType getDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < xs) return TFDeviceType.mobile;
    if (width < sm) return TFDeviceType.mobile;
    if (width < md) return TFDeviceType.tablet;
    if (width < lg) return TFDeviceType.laptop;
    if (width < xl) return TFDeviceType.desktop;
    return TFDeviceType.ultraWide;
  }

  /// Retorna a largura recomendada para diálogos e modais de formulário.
  static double getDialogWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < sm) return width * 0.92;
    if (width < md) return 560.0;
    return 640.0;
  }
}
