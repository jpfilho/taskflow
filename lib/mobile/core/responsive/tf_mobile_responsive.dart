import 'package:flutter/material.dart';

/// Classificação formal do dispositivo para o TaskFlow Mobile.
enum TFMobileDeviceCategory {
  mobileCompact, // < 360px (telas muito pequenas)
  mobileStandard, // 360px a 599px (smartphones padrão)
  tablet, // 600px a 1023px
  desktop, // >= 1024px
}

/// Helper central de responsividade do TaskFlow Mobile.
/// Compatível com os breakpoints pré-existentes do sistema.
abstract class TFMobileResponsive {
  static const double compactBreakpoint = 360.0;
  static const double mobileBreakpoint = 600.0;
  static const double tabletBreakpoint = 1024.0;

  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  static bool isCompactMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < compactBreakpoint;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= tabletBreakpoint;
  }

  static TFMobileDeviceCategory getCategory(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < compactBreakpoint) return TFMobileDeviceCategory.mobileCompact;
    if (width < mobileBreakpoint) return TFMobileDeviceCategory.mobileStandard;
    if (width < tabletBreakpoint) return TFMobileDeviceCategory.tablet;
    return TFMobileDeviceCategory.desktop;
  }

  /// Retorna um valor condicional conforme o dispositivo.
  static T value<T>({
    required BuildContext context,
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop(context)) return desktop ?? tablet ?? mobile;
    if (isTablet(context)) return tablet ?? mobile;
    return mobile;
  }
}
