import 'package:flutter/material.dart';

/// Escala oficial de espaçamento base 4px do TaskFlow Mobile.
/// Elimina valores arbitrários e garante consistência espacial e ergonômica.
abstract class TFMobileSpacing {
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
  static const double huge = 48.0;

  // Insets comuns para mobile
  static const EdgeInsets edgeInsetsScreen = EdgeInsets.symmetric(
    horizontal: lg,
    vertical: md,
  );

  static const EdgeInsets edgeInsetsCard = EdgeInsets.all(md);

  static const EdgeInsets edgeInsetsCardDense = EdgeInsets.all(sm);

  static const EdgeInsets edgeInsetsModal = EdgeInsets.all(lg);
}
