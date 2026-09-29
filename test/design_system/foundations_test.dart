import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/design_system/taskflow_design_system.dart';
import 'package:task2026/services/theme_service.dart';

void main() {
  group('TaskFlow Design System — Foundations Tests', () {
    test('Light Theme possui tokens válidos e contraste não-nulo', () {
      final theme = TaskFlowTheme.light();
      final ext = theme.extension<TaskFlowThemeExtension>();

      expect(ext, isNotNull);
      expect(ext!.colors.primary, isNotNull);
      expect(ext.colors.background, isNotNull);
      expect(ext.colors.surface, isNotNull);
      expect(ext.colors.textPrimary, isNotNull);

      // Validação de contraste crítico: texto e superfícies não podem ter a mesma cor
      expect(ext.colors.background != ext.colors.textPrimary, isTrue);
      expect(ext.colors.primary != ext.colors.primaryForeground, isTrue);
      expect(ext.colors.surface != ext.colors.textPrimary, isTrue);
    });

    test('Dark Theme possui tokens válidos e superfícies escuras distintas', () {
      final theme = TaskFlowTheme.dark();
      final ext = theme.extension<TaskFlowThemeExtension>();

      expect(ext, isNotNull);
      expect(ext!.colors.primary, isNotNull);
      expect(ext.colors.background, isNotNull);
      expect(ext.colors.surface, isNotNull);
      expect(ext.colors.textPrimary, isNotNull);

      // Background escuro e texto claro
      expect(ext.colors.background != ext.colors.textPrimary, isTrue);
      expect(ext.colors.primary != ext.colors.primaryForeground, isTrue);
      expect(ext.elevation.overlay.isNotEmpty, isTrue);
    });

    test('AXIA Theme preserva identidade da marca com tokens semânticos', () {
      final theme = TaskFlowTheme.axia();
      final ext = theme.extension<TaskFlowThemeExtension>();

      expect(ext, isNotNull);
      expect(ext!.colors.primary, equals(TFPrimitiveColors.axiaBlue));
      expect(ext.colors.textPrimary, equals(TFPrimitiveColors.axiaNavy));
      expect(ext.colors.background, equals(TFPrimitiveColors.axiaOffWhite));
    });

    test('ThemeService.getThemeData integra os três temas com TaskFlowThemeExtension', () {
      final lightTheme = ThemeService.getThemeData(AppTheme.light);
      expect(lightTheme.extension<TaskFlowThemeExtension>(), isNotNull);

      final darkTheme = ThemeService.getThemeData(AppTheme.dark);
      expect(darkTheme.extension<TaskFlowThemeExtension>(), isNotNull);

      final axiaTheme = ThemeService.getThemeData(AppTheme.axia);
      expect(axiaTheme.extension<TaskFlowThemeExtension>(), isNotNull);
    });

    test('TaskFlowThemeExtension copyWith funciona corretamente', () {
      final original = TaskFlowThemeExtension.light();
      final modified = original.copyWith(
        spacing: const TFSpacing(lg: 28.0),
      );

      expect(modified.spacing.lg, equals(28.0));
      expect(modified.colors.primary, equals(original.colors.primary));
    });

    test('TaskFlowThemeExtension lerp interpola valores adequadamente', () {
      final light = TaskFlowThemeExtension.light();
      final dark = TaskFlowThemeExtension.dark();

      final interpolated = light.lerp(dark, 0.5);

      expect(interpolated, isNotNull);
      expect(interpolated.colors.primary, isNotNull);
      expect(interpolated.spacing.md, equals(light.spacing.md));
    });

    test('TFTypography possui escala formal completa', () {
      final typo = TFTypography.regular();

      expect(typo.display.fontSize, equals(28.0));
      expect(typo.pageTitle.fontSize, equals(22.0));
      expect(typo.sectionTitle.fontSize, equals(16.0));
      expect(typo.bodyLarge.fontSize, equals(14.0));
      expect(typo.bodySmall.fontSize, equals(12.0));
      expect(typo.micro.fontSize, equals(10.0));
      expect(typo.micro.fontWeight, equals(FontWeight.w700));
    });

    test('TFSpacing escala base 4px está correta', () {
      const spacing = TFSpacing();

      expect(spacing.xxs, equals(2.0));
      expect(spacing.xs, equals(4.0));
      expect(spacing.sm, equals(8.0));
      expect(spacing.md, equals(12.0));
      expect(spacing.lg, equals(16.0));
      expect(spacing.xl, equals(20.0));
      expect(spacing.xxl, equals(24.0));
      expect(spacing.xxxl, equals(32.0));
      expect(spacing.huge, equals(48.0));
    });

    test('TFRadius escala está correta', () {
      const radius = TFRadius();

      expect(radius.none, equals(0.0));
      expect(radius.xs, equals(4.0));
      expect(radius.sm, equals(8.0));
      expect(radius.md, equals(12.0));
      expect(radius.lg, equals(16.0));
      expect(radius.full, equals(999.0));

      expect(radius.borderSm, equals(BorderRadius.circular(8.0)));
    });

    test('TFDensity modos de densidade possuem valores adequados', () {
      final comfortable = TFDensity.comfortable();
      final compact = TFDensity.compact();
      final dense = TFDensity.dense();

      expect(comfortable.rowHeight, equals(48.0));
      expect(compact.rowHeight, equals(40.0));
      expect(dense.rowHeight, equals(34.0));

      expect(dense.rowHeight < compact.rowHeight, isTrue);
      expect(compact.rowHeight < comfortable.rowHeight, isTrue);
    });

    test('TFIcons contém aliases padronizados para todas as intenções principais', () {
      expect(TFIcons.add, isNotNull);
      expect(TFIcons.edit, isNotNull);
      expect(TFIcons.delete, isNotNull);
      expect(TFIcons.save, isNotNull);
      expect(TFIcons.cancel, isNotNull);
      expect(TFIcons.search, isNotNull);
      expect(TFIcons.filter, isNotNull);
      expect(TFIcons.sync, isNotNull);
      expect(TFIcons.chat, isNotNull);
      expect(TFIcons.warning, isNotNull);
      expect(TFIcons.ai, isNotNull);
    });
  });
}
