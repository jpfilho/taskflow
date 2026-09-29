import 'dart:ui';
import 'package:flutter/material.dart';

/// Escala oficial de raios de borda do TaskFlow Design System.
@immutable
class TFRadius {
  final double none; // 0 px
  final double xs; // 4 px
  final double sm; // 8 px - Padrão do sistema
  final double md; // 12 px - Cards e pílulas
  final double lg; // 16 px - Modais
  final double full; // 999 px - Badges circulares

  const TFRadius({
    this.none = 0.0,
    this.xs = 4.0,
    this.sm = 8.0,
    this.md = 12.0,
    this.lg = 16.0,
    this.full = 999.0,
  });

  // Constantes estáticas
  static const double r0 = 0.0;
  static const double r4 = 4.0;
  static const double r8 = 8.0;
  static const double r12 = 12.0;
  static const double r16 = 16.0;
  static const double rFull = 999.0;

  // Helpers de BorderRadius estáticos
  static const BorderRadius borderRadiusNone = BorderRadius.zero;
  static final BorderRadius borderRadiusXs = BorderRadius.circular(r4);
  static final BorderRadius borderRadiusSm = BorderRadius.circular(r8);
  static final BorderRadius borderRadiusMd = BorderRadius.circular(r12);
  static final BorderRadius borderRadiusLg = BorderRadius.circular(r16);
  static final BorderRadius borderRadiusFull = BorderRadius.circular(rFull);

  // Helpers de BorderRadius da instância
  BorderRadius get borderNone => BorderRadius.zero;
  BorderRadius get borderXs => BorderRadius.circular(xs);
  BorderRadius get borderSm => BorderRadius.circular(sm);
  BorderRadius get borderMd => BorderRadius.circular(md);
  BorderRadius get borderLg => BorderRadius.circular(lg);
  BorderRadius get borderFull => BorderRadius.circular(full);

  TFRadius copyWith({
    double? none,
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? full,
  }) {
    return TFRadius(
      none: none ?? this.none,
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      full: full ?? this.full,
    );
  }

  static TFRadius lerp(TFRadius a, TFRadius b, double t) {
    return TFRadius(
      none: lerpDouble(a.none, b.none, t)!,
      xs: lerpDouble(a.xs, b.xs, t)!,
      sm: lerpDouble(a.sm, b.sm, t)!,
      md: lerpDouble(a.md, b.md, t)!,
      lg: lerpDouble(a.lg, b.lg, t)!,
      full: lerpDouble(a.full, b.full, t)!,
    );
  }
}
