import 'dart:ui';
import 'package:flutter/material.dart';

/// Tokens e estilos de borda do TaskFlow Design System.
@immutable
class TFBorders {
  final double widthSubtle; // 1.0 px
  final double widthDefault; // 1.5 px
  final double widthStrong; // 2.0 px
  final double widthFocus; // 2.0 px

  const TFBorders({
    this.widthSubtle = 1.0,
    this.widthDefault = 1.5,
    this.widthStrong = 2.0,
    this.widthFocus = 2.0,
  });

  // Constantes estáticas
  static const double wSubtle = 1.0;
  static const double wDefault = 1.5;
  static const double wStrong = 2.0;
  static const double wFocus = 2.0;

  // Helpers para geração de BorderSide com cores semânticas
  BorderSide sideSubtle(Color color) => BorderSide(color: color, width: widthSubtle);
  BorderSide sideDefault(Color color) => BorderSide(color: color, width: widthDefault);
  BorderSide sideStrong(Color color) => BorderSide(color: color, width: widthStrong);
  BorderSide sideFocus(Color color) => BorderSide(color: color, width: widthFocus);

  // Helper para geração de Border completo
  Border allSubtle(Color color) => Border.all(color: color, width: widthSubtle);
  Border allDefault(Color color) => Border.all(color: color, width: widthDefault);
  Border allStrong(Color color) => Border.all(color: color, width: widthStrong);
  Border allFocus(Color color) => Border.all(color: color, width: widthFocus);

  TFBorders copyWith({
    double? widthSubtle,
    double? widthDefault,
    double? widthStrong,
    double? widthFocus,
  }) {
    return TFBorders(
      widthSubtle: widthSubtle ?? this.widthSubtle,
      widthDefault: widthDefault ?? this.widthDefault,
      widthStrong: widthStrong ?? this.widthStrong,
      widthFocus: widthFocus ?? this.widthFocus,
    );
  }

  static TFBorders lerp(TFBorders a, TFBorders b, double t) {
    return TFBorders(
      widthSubtle: lerpDouble(a.widthSubtle, b.widthSubtle, t)!,
      widthDefault: lerpDouble(a.widthDefault, b.widthDefault, t)!,
      widthStrong: lerpDouble(a.widthStrong, b.widthStrong, t)!,
      widthFocus: lerpDouble(a.widthFocus, b.widthFocus, t)!,
    );
  }
}
