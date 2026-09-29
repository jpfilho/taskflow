import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../foundations/tf_density.dart';
import '../../foundations/tf_radius.dart';
import '../../theme/taskflow_theme_extension.dart';

/// Controle booleano oficial do TaskFlow Design System.
///
/// Substitui o uso de `Switch` e `SwitchListTile` genéricos.
/// Oferece suporte a estados ON/OFF/Disabled/Hover/Focus, conformidade com
/// acessibilidade (área de toque mínima de 44-48px, suporte a leitor de telas,
/// navegação por teclado) e densidades ajustáveis.
class TFSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;
  final String? description;
  final bool enabled;
  final String? semanticLabel;
  final TFDensityMode? densityMode;

  const TFSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.description,
    this.enabled = true,
    this.semanticLabel,
    this.densityMode,
  });

  @override
  State<TFSwitch> createState() => _TFSwitchState();
}

class _TFSwitchState extends State<TFSwitch> {
  bool _isHovered = false;
  bool _isFocused = false;

  bool get _isEnabled => widget.enabled && widget.onChanged != null;

  void _toggle() {
    if (!_isEnabled) return;
    HapticFeedback.selectionClick();
    widget.onChanged?.call(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;
    final density = context.tfDensity;
    final motion = context.tfMotion;

    final activeDensity = widget.densityMode != null
        ? TFDensity.fromMode(widget.densityMode!)
        : density;

    // Dimensões visuais do trilho e do thumb baseadas na densidade
    double trackWidth = 38.0;
    double trackHeight = 20.0;
    double thumbSize = 14.0;

    switch (activeDensity.mode) {
      case TFDensityMode.comfortable:
        trackWidth = 44.0;
        trackHeight = 24.0;
        thumbSize = 18.0;
        break;
      case TFDensityMode.compact:
        trackWidth = 38.0;
        trackHeight = 20.0;
        thumbSize = 14.0;
        break;
      case TFDensityMode.dense:
        trackWidth = 32.0;
        trackHeight = 16.0;
        thumbSize = 12.0;
        break;
    }

    final double thumbPadding = (trackHeight - thumbSize) / 2;

    // Cores dinâmicas semânticas
    final Color trackColor;
    final Color thumbColor;
    final Color borderColor;

    if (!_isEnabled) {
      trackColor = colors.surfaceSecondary;
      thumbColor = colors.textDisabled;
      borderColor = colors.borderSubtle;
    } else if (widget.value) {
      trackColor = _isHovered
          ? colors.primaryHover
          : colors.primary;
      thumbColor = colors.surface;
      borderColor = Colors.transparent;
    } else {
      trackColor = _isHovered
          ? colors.surfaceSecondary
          : colors.surfaceSecondary.withValues(alpha: 0.6);
      thumbColor = colors.textSecondary;
      borderColor = _isFocused ? colors.borderFocus : colors.borderDefault;
    }

    final switchVisual = FocusableActionDetector(
      enabled: _isEnabled,
      onShowFocusHighlight: (focused) => setState(() => _isFocused = focused),
      onShowHoverHighlight: (hovered) => setState(() => _isHovered = hovered),
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) => _toggle(),
        ),
      },
      child: MouseRegion(
        cursor: _isEnabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
        child: GestureDetector(
          onTap: _toggle,
          child: Container(
            // Garante o alvo de toque acessível mínimo (44x44 / 48x48) mesmo em modo denso
            constraints: const BoxConstraints(
              minWidth: 44.0,
              minHeight: 44.0,
            ),
            alignment: Alignment.center,
            child: AnimatedContainer(
              duration: motion.fast,
              curve: motion.standardCurve,
              width: trackWidth,
              height: trackHeight,
              padding: EdgeInsets.all(thumbPadding),
              decoration: BoxDecoration(
                color: trackColor,
                borderRadius: TFRadius.borderRadiusFull,
                border: Border.all(
                  color: _isFocused ? colors.borderFocus : borderColor,
                  width: _isFocused ? 2.0 : 1.0,
                ),
                boxShadow: _isFocused
                    ? [
                        BoxShadow(
                          color: colors.borderFocus.withValues(alpha: 0.3),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: AnimatedAlign(
                duration: motion.fast,
                curve: motion.standardCurve,
                alignment: widget.value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: thumbSize,
                  height: thumbSize,
                  decoration: BoxDecoration(
                    color: thumbColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final effectiveSemanticLabel = widget.semanticLabel ??
        (widget.label != null
            ? '${widget.label}: ${widget.value ? 'Ativado' : 'Desativado'}'
            : (widget.value ? 'Ativado' : 'Desativado'));

    Widget result = Semantics(
      label: effectiveSemanticLabel,
      toggled: widget.value,
      enabled: _isEnabled,
      button: true,
      child: switchVisual,
    );

    if (widget.label != null || widget.description != null) {
      result = InkWell(
        onTap: _isEnabled ? _toggle : null,
        borderRadius: TFRadius.borderRadiusMd,
        focusColor: Colors.transparent,
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: widget.description != null
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            result,
            SizedBox(width: spacing.xs),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.label != null)
                    Text(
                      widget.label!,
                      style: typography.bodyMedium.copyWith(
                        color: _isEnabled
                            ? colors.textPrimary
                            : colors.textDisabled,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  if (widget.description != null) ...[
                    SizedBox(height: spacing.xxs),
                    Text(
                      widget.description!,
                      style: typography.bodySmall.copyWith(
                        color: _isEnabled
                            ? colors.textSecondary
                            : colors.textDisabled,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    return result;
  }
}
