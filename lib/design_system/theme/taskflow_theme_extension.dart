import 'package:flutter/material.dart';
import '../foundations/tf_colors.dart';
import '../foundations/tf_typography.dart';
import '../foundations/tf_spacing.dart';
import '../foundations/tf_radius.dart';
import '../foundations/tf_borders.dart';
import '../foundations/tf_elevation.dart';
import '../foundations/tf_density.dart';
import '../foundations/tf_motion.dart';

/// Extensão de tema oficial do TaskFlow Design System.
/// Fornece acesso fortemente tipado aos tokens semânticos e foundations.
class TaskFlowThemeExtension extends ThemeExtension<TaskFlowThemeExtension> {
  final TFSemanticColors colors;
  final TFTypography typography;
  final TFSpacing spacing;
  final TFRadius radius;
  final TFBorders borders;
  final TFElevation elevation;
  final TFDensity density;
  final TFMotion motion;

  const TaskFlowThemeExtension({
    required this.colors,
    required this.typography,
    required this.spacing,
    required this.radius,
    required this.borders,
    required this.elevation,
    required this.density,
    required this.motion,
  });

  /// Configuração de fábrica para o tema Light
  factory TaskFlowThemeExtension.light({TFDensity? customDensity}) {
    return TaskFlowThemeExtension(
      colors: TFSemanticColors.light(),
      typography: TFTypography.regular(),
      spacing: const TFSpacing(),
      radius: const TFRadius(),
      borders: const TFBorders(),
      elevation: const TFElevation(),
      density: customDensity ?? TFDensity.comfortable(),
      motion: const TFMotion(),
    );
  }

  /// Configuração de fábrica para o tema Dark
  factory TaskFlowThemeExtension.dark({TFDensity? customDensity}) {
    return TaskFlowThemeExtension(
      colors: TFSemanticColors.dark(),
      typography: TFTypography.regular(),
      spacing: const TFSpacing(),
      radius: const TFRadius(),
      borders: const TFBorders(),
      elevation: TFElevation.dark(),
      density: customDensity ?? TFDensity.comfortable(),
      motion: const TFMotion(),
    );
  }

  /// Configuração de fábrica para o tema AXIA
  factory TaskFlowThemeExtension.axia({TFDensity? customDensity}) {
    return TaskFlowThemeExtension(
      colors: TFSemanticColors.axia(),
      typography: TFTypography.regular(),
      spacing: const TFSpacing(),
      radius: const TFRadius(),
      borders: const TFBorders(),
      elevation: const TFElevation(),
      density: customDensity ?? TFDensity.comfortable(),
      motion: const TFMotion(),
    );
  }

  @override
  TaskFlowThemeExtension copyWith({
    TFSemanticColors? colors,
    TFTypography? typography,
    TFSpacing? spacing,
    TFRadius? radius,
    TFBorders? borders,
    TFElevation? elevation,
    TFDensity? density,
    TFMotion? motion,
  }) {
    return TaskFlowThemeExtension(
      colors: colors ?? this.colors,
      typography: typography ?? this.typography,
      spacing: spacing ?? this.spacing,
      radius: radius ?? this.radius,
      borders: borders ?? this.borders,
      elevation: elevation ?? this.elevation,
      density: density ?? this.density,
      motion: motion ?? this.motion,
    );
  }

  @override
  TaskFlowThemeExtension lerp(
    covariant ThemeExtension<TaskFlowThemeExtension>? other,
    double t,
  ) {
    if (other is! TaskFlowThemeExtension) {
      return this;
    }

    return TaskFlowThemeExtension(
      colors: TFSemanticColors.lerp(colors, other.colors, t),
      typography: TFTypography.lerp(typography, other.typography, t),
      spacing: TFSpacing.lerp(spacing, other.spacing, t),
      radius: TFRadius.lerp(radius, other.radius, t),
      borders: TFBorders.lerp(borders, other.borders, t),
      elevation: TFElevation.lerp(elevation, other.elevation, t),
      density: TFDensity.lerp(density, other.density, t),
      motion: TFMotion.lerp(motion, other.motion, t),
    );
  }
}

/// Extensões de conveniência no BuildContext para acesso direto e fluido aos tokens.
extension TaskFlowThemeContextExtension on BuildContext {
  /// Retorna a extensão TaskFlowThemeExtension ativa no tema atual.
  TaskFlowThemeExtension get tfTheme {
    final ext = Theme.of(this).extension<TaskFlowThemeExtension>();
    return ext ?? TaskFlowThemeExtension.light();
  }

  /// Atalhos diretos
  TFSemanticColors get tfColors => tfTheme.colors;
  TFTypography get tfTypography => tfTheme.typography;
  TFSpacing get tfSpacing => tfTheme.spacing;
  TFRadius get tfRadius => tfTheme.radius;
  TFBorders get tfBorders => tfTheme.borders;
  TFElevation get tfElevation => tfTheme.elevation;
  TFDensity get tfDensity => tfTheme.density;
  TFMotion get tfMotion => tfTheme.motion;
}
