import 'package:flutter/material.dart';
import '../../foundations/tf_radius.dart';
import '../../theme/taskflow_theme_extension.dart';

/// Variantes visuais do botão de ícone oficial.
enum TFIconButtonVariant {
  standard,
  subtle,
  danger,
}

/// Botão de ícone padrão do TaskFlow Design System.
///
/// Substitui o uso disperso de [IconButton].
/// Obriga o fornecimento de [tooltip] para conformidade com acessibilidade.
/// Garante touch target de no mínimo 40x40px mesmo quando o pictograma é compacto.
class TFIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final TFIconButtonVariant variant;
  final double iconSize;
  final FocusNode? focusNode;

  const TFIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.variant = TFIconButtonVariant.standard,
    this.iconSize = 20.0,
    this.focusNode,
  });

  @override
  State<TFIconButton> createState() => _TFIconButtonState();
}

class _TFIconButtonState extends State<TFIconButton> {
  bool _isHovered = false;
  bool _isPressed = false;
  bool _isFocused = false;

  bool get _isEnabled => widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;

    final (Color bg, Color fg, Border? border) = _resolveColors(colors);

    Widget button = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 36.0,
      height: 36.0,
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
        child: Icon(
          widget.icon,
          size: widget.iconSize,
          color: fg,
        ),
      ),
    );

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: Semantics(
        button: true,
        enabled: _isEnabled,
        label: widget.tooltip,
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
              // Garante touch target de pelo menos 40x40 para acessibilidade (touch-friendly)
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: 40.0,
                  minHeight: 40.0,
                ),
                child: Center(child: button),
              ),
            ),
          ),
        ),
      ),
    );
  }

  (Color, Color, Border?) _resolveColors(dynamic colors) {
    if (!_isEnabled) {
      return (Colors.transparent, colors.textDisabled, null);
    }

    switch (widget.variant) {
      case TFIconButtonVariant.standard:
        if (_isPressed) return (colors.surfaceSecondary, colors.primary, null);
        if (_isHovered) return (colors.hover, colors.primary, null);
        return (Colors.transparent, colors.textSecondary, null);

      case TFIconButtonVariant.subtle:
        final border = Border.all(
          color: _isFocused ? colors.borderFocus : (_isHovered ? colors.borderStrong : colors.borderSubtle),
        );
        if (_isPressed) return (colors.surfaceSecondary, colors.textPrimary, border);
        if (_isHovered) return (colors.hover, colors.textPrimary, border);
        return (colors.surface, colors.textSecondary, border);

      case TFIconButtonVariant.danger:
        if (_isPressed) return (colors.dangerBackground, colors.danger, null);
        if (_isHovered) return (colors.dangerBackground, colors.danger, null);
        return (Colors.transparent, colors.danger, null);
    }
  }
}
