import 'package:flutter/material.dart';
import '../../theme/taskflow_theme_extension.dart';

/// Modo de apresentação do indicador de carregamento.
enum TFLoadingMode {
  inline,
  section,
  page,
}

/// Indicador oficial de carregamento do TaskFlow Design System.
///
/// Substitui spinners genéricos e garante coerência de cor e escala com o tema ativo.
class TFLoading extends StatelessWidget {
  final TFLoadingMode mode;
  final String? message;
  final double? size;

  const TFLoading({
    super.key,
    this.mode = TFLoadingMode.section,
    this.message,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    final double spinnerSize = size ?? switch (mode) {
      TFLoadingMode.inline => 16.0,
      TFLoadingMode.section => 32.0,
      TFLoadingMode.page => 44.0,
    };

    final double strokeWidth = mode == TFLoadingMode.inline ? 2.0 : 3.0;

    Widget spinner = SizedBox(
      width: spinnerSize,
      height: spinnerSize,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
      ),
    );

    if (message != null && message!.isNotEmpty) {
      spinner = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          spinner,
          SizedBox(height: spacing.md),
          Text(
            message!,
            style: typography.bodyMedium.copyWith(
              color: colors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return switch (mode) {
      TFLoadingMode.inline => spinner,
      TFLoadingMode.section => Center(
          child: Padding(
            padding: EdgeInsets.all(spacing.lg),
            child: spinner,
          ),
        ),
      TFLoadingMode.page => Center(
          child: Padding(
            padding: EdgeInsets.all(spacing.xxl),
            child: spinner,
          ),
        ),
    };
  }
}
