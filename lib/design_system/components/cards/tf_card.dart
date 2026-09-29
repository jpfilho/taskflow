import 'package:flutter/material.dart';
import '../../foundations/tf_radius.dart';
import '../../theme/taskflow_theme_extension.dart';

/// Variantes visuais do TFCard.
enum TFCardVariant {
  defaultCard,
  interactive,
  highlighted,
}

/// Container padronizado de superfície do TaskFlow Design System.
///
/// Segue a diretriz arquitetural do TaskFlow: flat + border elegante,
/// com suporte a interatividade e destaque suave.
class TFCard extends StatefulWidget {
  final Widget child;
  final TFCardVariant variant;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final bool selected;

  const TFCard({
    super.key,
    required this.child,
    this.variant = TFCardVariant.defaultCard,
    this.padding,
    this.onTap,
    this.selected = false,
  });

  @override
  State<TFCard> createState() => _TFCardState();
}

class _TFCardState extends State<TFCard> {
  bool _isHovered = false;

  bool get _isClickable => widget.onTap != null || widget.variant == TFCardVariant.interactive;

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final density = context.tfDensity;

    final defaultPadding = EdgeInsets.symmetric(
      horizontal: density.horizontalPadding,
      vertical: density.verticalPadding + 4.0,
    );

    // Borda e fundo de acordo com variante, seleção e hover
    final (Color bg, Border border, List<BoxShadow>? shadows) = _resolveStyle(colors);

    Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: widget.padding ?? defaultPadding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: TFRadius.borderRadiusMd,
        border: border,
        boxShadow: shadows,
      ),
      child: widget.child,
    );

    if (_isClickable) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: card,
        ),
      );
    }

    return card;
  }

  (Color, Border, List<BoxShadow>?) _resolveStyle(dynamic colors) {
    if (widget.selected) {
      return (
        colors.selected,
        Border.all(color: colors.primary, width: 1.5),
        null,
      );
    }

    switch (widget.variant) {
      case TFCardVariant.defaultCard:
        return (
          colors.surface,
          Border.all(color: colors.borderDefault),
          null,
        );

      case TFCardVariant.interactive:
        return (
          _isHovered ? colors.surfaceSecondary : colors.surface,
          Border.all(color: _isHovered ? colors.borderStrong : colors.borderDefault),
          _isHovered
              ? [
                  BoxShadow(
                    color: colors.textPrimary.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        );

      case TFCardVariant.highlighted:
        return (
          colors.surfaceElevated,
          Border.all(color: colors.primary.withValues(alpha: 0.4), width: 1.5),
          [
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        );
    }
  }
}
