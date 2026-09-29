import 'package:flutter/material.dart';

/// Tokens de duração e curvas de animação do TaskFlow Design System.
@immutable
class TFMotion {
  final Duration fast; // 150ms - Micro-interações, hover, toggles
  final Duration normal; // 250ms - Expansão de painéis, aberturas de drawer
  final Duration slow; // 400ms - Transições de tela inteira, diálogos modais

  final Curve standardCurve; // Curva padrão simétrica
  final Curve entranceCurve; // Curva para elementos entrando em tela
  final Curve exitCurve; // Curva para elementos saindo de tela

  const TFMotion({
    this.fast = const Duration(milliseconds: 150),
    this.normal = const Duration(milliseconds: 250),
    this.slow = const Duration(milliseconds: 400),
    this.standardCurve = Curves.easeInOutCubic,
    this.entranceCurve = Curves.easeOutCubic,
    this.exitCurve = Curves.easeInCubic,
  });

  TFMotion copyWith({
    Duration? fast,
    Duration? normal,
    Duration? slow,
    Curve? standardCurve,
    Curve? entranceCurve,
    Curve? exitCurve,
  }) {
    return TFMotion(
      fast: fast ?? this.fast,
      normal: normal ?? this.normal,
      slow: slow ?? this.slow,
      standardCurve: standardCurve ?? this.standardCurve,
      entranceCurve: entranceCurve ?? this.entranceCurve,
      exitCurve: exitCurve ?? this.exitCurve,
    );
  }

  static TFMotion lerp(TFMotion a, TFMotion b, double t) {
    return t < 0.5 ? a : b;
  }
}
