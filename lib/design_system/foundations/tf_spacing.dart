import 'dart:ui';
import 'package:flutter/material.dart';

/// Escala enxuta de espaçamentos base 4px do TaskFlow Design System.
@immutable
class TFSpacing {
  final double xxs; // 2 px
  final double xs; // 4 px
  final double sm; // 8 px
  final double md; // 12 px
  final double lg; // 16 px
  final double xl; // 20 px
  final double xxl; // 24 px
  final double xxxl; // 32 px
  final double huge; // 48 px

  const TFSpacing({
    this.xxs = 2.0,
    this.xs = 4.0,
    this.sm = 8.0,
    this.md = 12.0,
    this.lg = 16.0,
    this.xl = 20.0,
    this.xxl = 24.0,
    this.xxxl = 32.0,
    this.huge = 48.0,
  });

  // Alias semântico para 16px (padrão)
  double get base => lg;

  // Constantes estáticas para uso direto sem context quando necessário
  static const double s2 = 2.0;
  static const double s4 = 4.0;
  static const double s8 = 8.0;
  static const double s12 = 12.0;
  static const double s16 = 16.0;
  static const double s20 = 20.0;
  static const double s24 = 24.0;
  static const double s32 = 32.0;
  static const double s48 = 48.0;

  TFSpacing copyWith({
    double? xxs,
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xl,
    double? xxl,
    double? xxxl,
    double? huge,
  }) {
    return TFSpacing(
      xxs: xxs ?? this.xxs,
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
      xxl: xxl ?? this.xxl,
      xxxl: xxxl ?? this.xxxl,
      huge: huge ?? this.huge,
    );
  }

  static TFSpacing lerp(TFSpacing a, TFSpacing b, double t) {
    return TFSpacing(
      xxs: lerpDouble(a.xxs, b.xxs, t)!,
      xs: lerpDouble(a.xs, b.xs, t)!,
      sm: lerpDouble(a.sm, b.sm, t)!,
      md: lerpDouble(a.md, b.md, t)!,
      lg: lerpDouble(a.lg, b.lg, t)!,
      xl: lerpDouble(a.xl, b.xl, t)!,
      xxl: lerpDouble(a.xxl, b.xxl, t)!,
      xxxl: lerpDouble(a.xxxl, b.xxxl, t)!,
      huge: lerpDouble(a.huge, b.huge, t)!,
    );
  }
}
