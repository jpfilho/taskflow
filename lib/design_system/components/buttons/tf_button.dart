import 'package:flutter/material.dart';
import '../../foundations/tf_density.dart';
import '../../foundations/tf_radius.dart';
import '../../theme/taskflow_theme_extension.dart';

/// Variantes visuais do botão oficial do TaskFlow Design System.
enum TFButtonVariant {
  primary,
  secondary,
  tertiary,
  danger,
  ghost,
}

/// Escala de tamanhos do TFButton.
enum TFButtonSize {
  small,
  medium,
  large,
}

/// Botão padrão e oficial do TaskFlow.
///
/// Substitui o uso disperso de ElevatedButton, OutlinedButton e TextButton.
/// Consome estritamente os tokens de cores, tipografia, espaçamento e densidade.
class TFButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final TFButtonVariant variant;
  final TFButtonSize size;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool loading;
  final bool fullWidth;
  final FocusNode? focusNode;
  final String? semanticLabel;

  const TFButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = TFButtonVariant.primary,
    this.size = TFButtonSize.medium,
    this.leadingIcon,
    this.trailingIcon,
    this.loading = false,
    this.fullWidth = false,
    this.focusNode,
    this.semanticLabel,
  });

  @override
  State<TFButton> createState() => _TFButtonState();
}

class _TFButtonState extends State<TFButton> {
  bool _isHovered = false;
  bool _isPressed = false;
  bool _isFocused = false;

  bool get _isEnabled => widget.onPressed != null && !widget.loading;

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;
    final density = context.tfDensity;

    // Métricas de tamanho com base no enum e na densidade operacional
    final (double height, double horizontalPadding, TextStyle labelStyle, double iconSize) = switch (widget.size) {
      TFButtonSize.small => (
          density.mode == TFDensityMode.dense ? 28.0 : 32.0,
          spacing.md,
          typography.labelSmall,
          16.0,
        ),
      TFButtonSize.medium => (
          density.mode == TFDensityMode.dense ? 34.0 : (density.mode == TFDensityMode.comfortable ? 44.0 : 40.0),
          spacing.base,
          typography.labelMedium,
          18.0,
        ),
      TFButtonSize.large => (
          density.mode == TFDensityMode.dense ? 40.0 : 48.0,
          spacing.xl,
          typography.labelLarge,
          20.0,
        ),
    };

    // Cores de fundo, borda e texto de acordo com a variante e estado
    final (Color bg, Color fg, Border? border) = _resolveColors(colors);

    Widget content = Row(
      mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (widget.loading) ...[
          SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2.0,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          ),
          SizedBox(width: spacing.sm),
        ] else if (widget.leadingIcon != null) ...[
          Icon(widget.leadingIcon, size: iconSize, color: fg),
          SizedBox(width: spacing.sm),
        ],
        Flexible(
          child: Text(
            widget.label,
            style: labelStyle.copyWith(color: fg),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (!widget.loading && widget.trailingIcon != null) ...[
          SizedBox(width: spacing.sm),
          Icon(widget.trailingIcon, size: iconSize, color: fg),
        ],
      ],
    );

    Widget button = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: height,
      constraints: BoxConstraints(
        minWidth: height,
        minHeight: 32.0,
      ),
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: TFRadius.borderRadiusSm,
        border: border,
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: colors.focus,
                  blurRadius: 0,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Center(
        widthFactor: widget.fullWidth ? null : 1.0,
        child: content,
      ),
    );

    return Semantics(
      button: true,
      enabled: _isEnabled,
      label: widget.semanticLabel ?? widget.label,
      child: FocusableActionDetector(
        focusNode: widget.focusNode,
        enabled: _isEnabled,
        onShowFocusHighlight: (f) => setState(() => _isFocused = f),
        onShowHoverHighlight: (h) => setState(() => _isHovered = h),
        child: GestureDetector(
          onTapDown: _isEnabled ? (_) => setState(() => _isPressed = true) : null,
          onTapUp: _isEnabled ? (_) => setState(() => _isPressed = false) : null,
          onTapCancel: _isEnabled ? () => setState(() => _isPressed = false) : null,
          onTap: _isEnabled ? widget.onPressed : null,
          child: MouseRegion(
            cursor: _isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
            child: widget.fullWidth ? SizedBox(width: double.infinity, child: button) : button,
          ),
        ),
      ),
    );
  }

  (Color, Color, Border?) _resolveColors(dynamic colors) {
    if (!_isEnabled) {
      return (
        widget.variant == TFButtonVariant.ghost || widget.variant == TFButtonVariant.tertiary
            ? Colors.transparent
            : colors.disabled,
        colors.textDisabled,
        widget.variant == TFButtonVariant.secondary
            ? Border.all(color: colors.borderSubtle)
            : null,
      );
    }

    switch (widget.variant) {
      case TFButtonVariant.primary:
        if (_isPressed) return (colors.primaryPressed, colors.primaryForeground, null);
        if (_isHovered) return (colors.primaryHover, colors.primaryForeground, null);
        return (colors.primary, colors.primaryForeground, null);

      case TFButtonVariant.secondary:
        final border = Border.all(
          color: _isFocused ? colors.borderFocus : (_isHovered ? colors.borderStrong : colors.borderDefault),
        );
        if (_isPressed) return (colors.surfaceSecondary, colors.textPrimary, border);
        if (_isHovered) return (colors.hover, colors.textPrimary, border);
        return (colors.surface, colors.textPrimary, border);

      case TFButtonVariant.tertiary:
      case TFButtonVariant.ghost:
        if (_isPressed) return (colors.surfaceSecondary, colors.primary, null);
        if (_isHovered) return (colors.hover, colors.primary, null);
        return (Colors.transparent, colors.primary, null);

      case TFButtonVariant.danger:
        if (_isPressed) return (colors.danger, colors.dangerForeground, null);
        if (_isHovered) return (colors.danger, colors.dangerForeground, null);
        return (colors.danger, colors.dangerForeground, null);
    }
  }
}
