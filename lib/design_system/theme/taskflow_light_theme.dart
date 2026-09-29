import 'package:flutter/material.dart';
import '../foundations/tf_colors.dart';
import '../foundations/tf_spacing.dart';
import '../foundations/tf_radius.dart';
import 'taskflow_theme_extension.dart';

/// Construtor oficial do ThemeData do TaskFlow para o Tema Claro (Light).
ThemeData buildTaskFlowLightTheme({TaskFlowThemeExtension? customExtension}) {
  final extension = customExtension ?? TaskFlowThemeExtension.light();
  final colors = extension.colors;
  final typography = extension.typography;

  final colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: colors.primary,
    onPrimary: colors.primaryForeground,
    secondary: TFPrimitiveColors.navy800,
    onSecondary: Colors.white,
    tertiary: TFPrimitiveColors.slate600,
    onTertiary: Colors.white,
    error: colors.danger,
    onError: colors.dangerForeground,
    surface: colors.surface,
    onSurface: colors.textPrimary,
    surfaceContainerHighest: colors.surfaceSecondary,
    onSurfaceVariant: colors.textSecondary,
    outline: colors.borderDefault,
    outlineVariant: colors.borderSubtle,
    shadow: const Color(0x1A0F172A),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colors.background,

    // Extensão de tokens TaskFlow
    extensions: [extension],

    // Tipografia base
    textTheme: TextTheme(
      displayLarge: typography.display,
      headlineMedium: typography.pageTitle,
      titleLarge: typography.sectionTitle,
      titleMedium: typography.cardTitle,
      bodyLarge: typography.bodyLarge.copyWith(color: colors.textPrimary),
      bodyMedium: typography.bodyMedium.copyWith(color: colors.textPrimary),
      bodySmall: typography.bodySmall.copyWith(color: colors.textSecondary),
      labelLarge: typography.labelLarge,
      labelMedium: typography.labelMedium,
      labelSmall: typography.labelSmall,
    ),

    // AppBar padronizada com o Navy da marca TaskFlow
    appBarTheme: AppBarTheme(
      backgroundColor: TFPrimitiveColors.navy800,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: typography.pageTitle.copyWith(color: Colors.white),
    ),

    // CardTheme padronizado com borda sutil
    cardTheme: CardThemeData(
      color: colors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TFRadius.r8),
        side: BorderSide(color: colors.borderSubtle),
      ),
      margin: EdgeInsets.zero,
    ),

    // DividerTheme
    dividerTheme: DividerThemeData(
      color: colors.borderSubtle,
      thickness: 1,
      space: 1,
    ),

    // Input Decoration padrão
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: TFSpacing.s12,
        vertical: TFSpacing.s8,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TFRadius.r8),
        borderSide: BorderSide(color: colors.borderDefault),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TFRadius.r8),
        borderSide: BorderSide(color: colors.borderDefault),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TFRadius.r8),
        borderSide: BorderSide(color: colors.borderFocus, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TFRadius.r8),
        borderSide: BorderSide(color: colors.danger),
      ),
    ),

    // DatePicker e DateRangePicker padronizados com alto contraste
    datePickerTheme: DatePickerThemeData(
      backgroundColor: colors.surface,
      headerBackgroundColor: TFPrimitiveColors.navy800,
      headerForegroundColor: Colors.white,
      headerHeadlineStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
      headerHelpStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.white70),
      rangePickerHeaderBackgroundColor: TFPrimitiveColors.navy800,
      rangePickerHeaderForegroundColor: Colors.white,
      rangePickerHeaderHeadlineStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
      rangePickerHeaderHelpStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.white70),
      rangeSelectionBackgroundColor: const Color(0xFFDCE7FE),
      rangeSelectionOverlayColor: WidgetStateProperty.all(colors.primary.withValues(alpha: 0.08)),
      todayForegroundColor: WidgetStateProperty.all(colors.primary),
      todayBorder: BorderSide(color: colors.primary, width: 1.5),
      dayForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.white;
        }
        if (states.contains(WidgetState.disabled)) {
          return colors.textDisabled;
        }
        return const Color(0xFF0F172A);
      }),
      dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return colors.primary;
        }
        return null;
      }),
    ),
  );
}
