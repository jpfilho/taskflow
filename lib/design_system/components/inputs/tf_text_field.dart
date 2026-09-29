import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../foundations/tf_radius.dart';
import '../../theme/taskflow_theme_extension.dart';

/// Campo de entrada de texto oficial do TaskFlow Design System.
///
/// Substitui FloatingLabelTextField e usos customizados de TextFormField.
/// Consome a escala tipográfica, tokens de cores e espaçamento do TFDS.
class TFTextField extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final bool required;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool enabled;
  final bool readOnly;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final VoidCallback? onTap;

  const TFTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.required = false,
    this.prefixIcon,
    this.suffixIcon,
    this.enabled = true,
    this.readOnly = false,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
    this.onChanged,
    this.validator,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;
    final density = context.tfDensity;

    final hasError = errorText != null && errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Padding(
            padding: EdgeInsets.only(bottom: spacing.xs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label!,
                  style: typography.labelMedium.copyWith(
                    color: enabled ? colors.textPrimary : colors.textDisabled,
                  ),
                ),
                if (required) ...[
                  SizedBox(width: spacing.xxs),
                  Text(
                    '*',
                    style: typography.labelMedium.copyWith(
                      color: colors.danger,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          readOnly: readOnly,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          onChanged: onChanged,
          validator: validator,
          onTap: onTap,
          style: typography.bodyLarge.copyWith(
            color: enabled ? colors.textPrimary : colors.textDisabled,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: typography.bodyLarge.copyWith(
              color: colors.textDisabled,
            ),
            helperText: helperText,
            helperStyle: typography.caption.copyWith(
              color: colors.textSecondary,
            ),
            errorText: errorText,
            errorStyle: typography.caption.copyWith(
              color: colors.danger,
            ),
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: enabled ? colors.surface : colors.surfaceSecondary,
            contentPadding: EdgeInsets.symmetric(
              horizontal: spacing.base,
              vertical: density.verticalPadding,
            ),
            border: OutlineInputBorder(
              borderRadius: TFRadius.borderRadiusMd,
              borderSide: BorderSide(
                color: hasError ? colors.danger : colors.borderDefault,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: TFRadius.borderRadiusMd,
              borderSide: BorderSide(
                color: hasError ? colors.danger : colors.borderDefault,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: TFRadius.borderRadiusMd,
              borderSide: BorderSide(
                color: hasError ? colors.danger : colors.primary,
                width: 2.0,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: TFRadius.borderRadiusMd,
              borderSide: BorderSide(
                color: colors.borderDefault.withValues(alpha: 0.5),
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: TFRadius.borderRadiusMd,
              borderSide: BorderSide(
                color: colors.danger,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: TFRadius.borderRadiusMd,
              borderSide: BorderSide(
                color: colors.danger,
                width: 2.0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
