import 'package:flutter/material.dart';

/// Tokens de elevação e sombras do TaskFlow Design System.
/// Prioriza superfícies 'flat' delimitadas por bordas, usando sombras apenas
/// onde há sobreposição física real (cards elevados e modais).
@immutable
class TFElevation {
  final List<BoxShadow> flat; // Nível 0: Sem sombra
  final List<BoxShadow> raised; // Nível 1: Cards interativos e dropdowns
  final List<BoxShadow> overlay; // Nível 2: Diálogos, side sheets e menus flutuantes

  const TFElevation({
    this.flat = const [],
    this.raised = const [
      BoxShadow(
        color: Color(0x0F0F172A),
        blurRadius: 4,
        offset: Offset(0, 1),
      ),
    ],
    this.overlay = const [
      BoxShadow(
        color: Color(0x1F0F172A),
        blurRadius: 16,
        spreadRadius: -2,
        offset: Offset(0, 8),
      ),
      BoxShadow(
        color: Color(0x0F0F172A),
        blurRadius: 6,
        spreadRadius: -1,
        offset: Offset(0, 4),
      ),
    ],
  });

  /// Sombras adaptadas para o tema escuro
  factory TFElevation.dark() {
    return const TFElevation(
      flat: [],
      raised: [
        BoxShadow(
          color: Color(0x40000000),
          blurRadius: 4,
          offset: Offset(0, 1),
        ),
      ],
      overlay: [
        BoxShadow(
          color: Color(0x80000000),
          blurRadius: 20,
          spreadRadius: -2,
          offset: Offset(0, 10),
        ),
      ],
    );
  }

  TFElevation copyWith({
    List<BoxShadow>? flat,
    List<BoxShadow>? raised,
    List<BoxShadow>? overlay,
  }) {
    return TFElevation(
      flat: flat ?? this.flat,
      raised: raised ?? this.raised,
      overlay: overlay ?? this.overlay,
    );
  }

  static TFElevation lerp(TFElevation a, TFElevation b, double t) {
    return TFElevation(
      flat: BoxShadow.lerpList(a.flat, b.flat, t) ?? a.flat,
      raised: BoxShadow.lerpList(a.raised, b.raised, t) ?? a.raised,
      overlay: BoxShadow.lerpList(a.overlay, b.overlay, t) ?? a.overlay,
    );
  }
}
