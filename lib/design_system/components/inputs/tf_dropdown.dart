import 'package:flutter/material.dart';
import '../../foundations/tf_density.dart';
import '../../foundations/tf_icons.dart';
import '../../foundations/tf_radius.dart';
import '../../theme/taskflow_theme_extension.dart';

/// Componente de seleção suspensa (dropdown) oficial do TaskFlow Design System.
///
/// Substitui o uso disperso de [DropdownButtonFormField] e implementações manuais.
/// Suporta estados: default, hover, focus, selected, disabled, loading, error, required e clearable.
/// Conforme com acessibilidade (WCAG AA), foco visível e compatível com os temas Light, Dark e AXIA.
class TFDropdown<T> extends StatefulWidget {
  final String label;
  final T? value;
  final List<T> items;
  final String Function(T) displayText;
  final ValueChanged<T?>? onChanged;
  final FormFieldValidator<T>? validator;
  final bool isRequired;
  final bool enabled;
  final bool isLoading;
  final bool showClearButton;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final Widget? prefixIcon;
  final FocusNode? focusNode;

  const TFDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.displayText,
    required this.onChanged,
    this.validator,
    this.isRequired = false,
    this.enabled = true,
    this.isLoading = false,
    this.showClearButton = false,
    this.hint,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.focusNode,
  });

  @override
  State<TFDropdown<T>> createState() => _TFDropdownState<T>();
}

class _TFDropdownState<T> extends State<TFDropdown<T>> {
  bool _isHovered = false;
  late FocusNode _effectiveFocusNode;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _effectiveFocusNode = widget.focusNode ?? FocusNode();
    _effectiveFocusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(TFDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode?.removeListener(_handleFocusChange);
      _effectiveFocusNode = widget.focusNode ?? FocusNode();
      _effectiveFocusNode.addListener(_handleFocusChange);
    }
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _effectiveFocusNode.dispose();
    } else {
      _effectiveFocusNode.removeListener(_handleFocusChange);
    }
    super.dispose();
  }

  void _handleFocusChange() {
    if (mounted) {
      setState(() {
        _hasFocus = _effectiveFocusNode.hasFocus;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;
    final density = context.tfDensity;

    final isEnabled = widget.enabled && !widget.isLoading && widget.onChanged != null;

    // Altura e padding baseados na densidade ativa
    double fieldHeight = 44.0;
    EdgeInsets contentPadding = EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs);
    switch (density.mode) {
      case TFDensityMode.comfortable:
        fieldHeight = 48.0;
        contentPadding = EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm);
        break;
      case TFDensityMode.compact:
        fieldHeight = 40.0;
        contentPadding = EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs);
        break;
      case TFDensityMode.dense:
        fieldHeight = 36.0;
        contentPadding = EdgeInsets.symmetric(horizontal: spacing.xs, vertical: spacing.xxs);
        break;
    }

    return FormField<T>(
      initialValue: widget.value,
      validator: (val) {
        if (widget.isRequired && (val == null || (val is String && val.isEmpty))) {
          return 'Campo obrigatório';
        }
        if (widget.validator != null) {
          return widget.validator!(val);
        }
        return null;
      },
      builder: (FormFieldState<T> state) {
        final currentError = widget.errorText ?? state.errorText;
        final hasError = currentError != null && currentError.isNotEmpty;

        // Determina cor da borda baseado no estado
        Color borderColor = colors.borderDefault;
        if (!isEnabled) {
          borderColor = colors.borderSubtle;
        } else if (hasError) {
          borderColor = colors.danger;
        } else if (_hasFocus) {
          borderColor = colors.primary;
        } else if (_isHovered) {
          borderColor = colors.borderStrong;
        }

        final backgroundColor = !isEnabled
            ? colors.surfaceSecondary.withValues(alpha: 0.5)
            : colors.surface;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Label superior acessível
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label,
                  style: typography.labelMedium.copyWith(
                    color: isEnabled ? colors.textPrimary : colors.textDisabled,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (widget.isRequired) ...[
                  SizedBox(width: spacing.xxs),
                  Text(
                    '*',
                    style: typography.labelMedium.copyWith(
                      color: colors.danger,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: spacing.xxs),

            // Campo Dropdown
            MouseRegion(
              onEnter: (_) {
                if (isEnabled) setState(() => _isHovered = true);
              },
              onExit: (_) {
                if (isEnabled) setState(() => _isHovered = false);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                constraints: BoxConstraints(minHeight: fieldHeight),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: TFRadius.borderRadiusMd,
                  border: Border.all(
                    color: borderColor,
                    width: _hasFocus ? 1.5 : 1.0,
                  ),
                ),
                padding: contentPadding,
                child: Row(
                  children: [
                    if (widget.prefixIcon != null) ...[
                      IconTheme(
                        data: IconThemeData(
                          color: isEnabled ? colors.textSecondary : colors.textDisabled,
                          size: 18,
                        ),
                        child: widget.prefixIcon!,
                      ),
                      SizedBox(width: spacing.xs),
                    ],
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<T>(
                          value: widget.items.contains(widget.value) ? widget.value : null,
                          focusNode: _effectiveFocusNode,
                          isDense: true,
                          isExpanded: true,
                          elevation: 3,
                          dropdownColor: colors.surfaceElevated,
                          borderRadius: TFRadius.borderRadiusMd,
                          hint: Text(
                            widget.isLoading
                                ? 'Carregando opções...'
                                : widget.hint ?? 'Selecione uma opção',
                            style: typography.bodyMedium.copyWith(
                              color: colors.textMuted,
                            ),
                          ),
                          icon: widget.isLoading
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colors.primary,
                                  ),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (widget.showClearButton && widget.value != null && isEnabled)
                                      IconButton(
                                        icon: const Icon(TFIcons.clear, size: 14),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        tooltip: 'Limpar seleção',
                                        onPressed: () {
                                          state.didChange(null);
                                          widget.onChanged?.call(null);
                                        },
                                      ),
                                    Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: isEnabled ? colors.textSecondary : colors.textDisabled,
                                      size: 20,
                                    ),
                                  ],
                                ),
                          style: typography.bodyMedium.copyWith(
                            color: isEnabled ? colors.textPrimary : colors.textDisabled,
                          ),
                          items: widget.items.map((item) {
                            final isSelected = item == widget.value;
                            return DropdownMenuItem<T>(
                              value: item,
                              child: Text(
                                widget.displayText(item),
                                style: typography.bodyMedium.copyWith(
                                  color: isSelected ? colors.primary : colors.textPrimary,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: isEnabled
                              ? (T? newValue) {
                                  state.didChange(newValue);
                                  widget.onChanged?.call(newValue);
                                }
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Helper text ou Error text
            if (hasError) ...[
              SizedBox(height: spacing.xxs),
              Row(
                children: [
                  Icon(TFIcons.error, size: 13, color: colors.danger),
                  SizedBox(width: spacing.xxs),
                  Expanded(
                    child: Text(
                      currentError,
                      style: typography.bodySmall.copyWith(
                        color: colors.danger,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (widget.helperText != null && widget.helperText!.isNotEmpty) ...[
              SizedBox(height: spacing.xxs),
              Text(
                widget.helperText!,
                style: typography.bodySmall.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
