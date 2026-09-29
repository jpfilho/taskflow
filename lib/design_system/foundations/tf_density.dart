import 'dart:ui';
import 'package:flutter/material.dart';

/// Níveis de densidade informacional do TaskFlow Design System.
enum TFDensityMode {
  comfortable,
  compact,
  dense,
}

/// Conjunto de dimensões e métricas adaptadas para cada nível de densidade.
@immutable
class TFDensity {
  final TFDensityMode mode;
  final double controlHeight; // Altura de inputs e botões
  final double rowHeight; // Altura de linhas em tabelas operacionais
  final double verticalPadding; // Padding vertical padrão
  final double horizontalPadding; // Padding horizontal padrão
  final double iconSize; // Tamanho de ícones associados a controles

  const TFDensity({
    required this.mode,
    required this.controlHeight,
    required this.rowHeight,
    required this.verticalPadding,
    required this.horizontalPadding,
    required this.iconSize,
  });

  /// Modo Comfortable (Padrão do Sistema): Espaçamento amplo e confortável.
  factory TFDensity.comfortable() {
    return const TFDensity(
      mode: TFDensityMode.comfortable,
      controlHeight: 48.0,
      rowHeight: 48.0,
      verticalPadding: 12.0,
      horizontalPadding: 16.0,
      iconSize: 22.0,
    );
  }

  /// Modo Compact: ~15-20% maior aproveitamento, ideal para notebooks (14"-15.6").
  factory TFDensity.compact() {
    return const TFDensity(
      mode: TFDensityMode.compact,
      controlHeight: 40.0,
      rowHeight: 40.0,
      verticalPadding: 8.0,
      horizontalPadding: 12.0,
      iconSize: 20.0,
    );
  }

  /// Modo Dense: ~25-30% maior densidade de informação para telas desktop.
  factory TFDensity.dense() {
    return const TFDensity(
      mode: TFDensityMode.dense,
      controlHeight: 36.0,
      rowHeight: 34.0,
      verticalPadding: 6.0,
      horizontalPadding: 8.0,
      iconSize: 18.0,
    );
  }

  /// Retorna a instância de TFDensity correspondente ao modo informado
  factory TFDensity.fromMode(TFDensityMode mode) {
    switch (mode) {
      case TFDensityMode.comfortable:
        return TFDensity.comfortable();
      case TFDensityMode.compact:
        return TFDensity.compact();
      case TFDensityMode.dense:
        return TFDensity.dense();
    }
  }

  TFDensity copyWith({
    TFDensityMode? mode,
    double? controlHeight,
    double? rowHeight,
    double? verticalPadding,
    double? horizontalPadding,
    double? iconSize,
  }) {
    return TFDensity(
      mode: mode ?? this.mode,
      controlHeight: controlHeight ?? this.controlHeight,
      rowHeight: rowHeight ?? this.rowHeight,
      verticalPadding: verticalPadding ?? this.verticalPadding,
      horizontalPadding: horizontalPadding ?? this.horizontalPadding,
      iconSize: iconSize ?? this.iconSize,
    );
  }

  static TFDensity lerp(TFDensity a, TFDensity b, double t) {
    return TFDensity(
      mode: t < 0.5 ? a.mode : b.mode,
      controlHeight: lerpDouble(a.controlHeight, b.controlHeight, t)!,
      rowHeight: lerpDouble(a.rowHeight, b.rowHeight, t)!,
      verticalPadding: lerpDouble(a.verticalPadding, b.verticalPadding, t)!,
      horizontalPadding: lerpDouble(a.horizontalPadding, b.horizontalPadding, t)!,
      iconSize: lerpDouble(a.iconSize, b.iconSize, t)!,
    );
  }
}
