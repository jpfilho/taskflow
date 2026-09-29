import 'package:flutter/material.dart';
import '../theme/tf_mobile_spacing.dart';
import '../theme/tf_mobile_typography.dart';
import '../theme/tf_mobile_colors.dart';
import '../theme/tf_mobile_touch_targets.dart';

/// Campo de texto oficial do TaskFlow Mobile com tratamento ergonômico de teclado e toque.
class TFMobileTextField extends StatelessWidget {
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final int maxLines;
  final int? minLines;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final FocusNode? focusNode;
  final VoidCallback? onTap;

  const TFMobileTextField({
    super.key,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.maxLines = 1,
    this.minLines,
    this.prefixIcon,
    this.suffixIcon,
    this.focusNode,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = TFMobileColors.textPrimary(context);
    final borderColor = TFMobileColors.border(context);
    final surfaceColor = TFMobileColors.surface(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: TFMobileTypography.titleMedium.copyWith(
              color: textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: TFMobileSpacing.xs),
        ],
        ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: TFMobileTouchTargets.min, // 48px
          ),
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            onFieldSubmitted: onSubmitted,
            onTap: onTap,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            obscureText: obscureText,
            enabled: enabled,
            readOnly: readOnly,
            maxLines: maxLines,
            minLines: minLines,
            style: TFMobileTypography.bodyLarge.copyWith(
              color: enabled ? textPrimary : Colors.grey.shade500,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TFMobileTypography.bodyMedium.copyWith(
                color: Colors.grey.shade500,
              ),
              helperText: helperText,
              helperStyle: TFMobileTypography.caption,
              errorText: errorText,
              errorStyle: TFMobileTypography.caption.copyWith(color: TFMobileColors.error),
              prefixIcon: prefixIcon,
              suffixIcon: suffixIcon,
              filled: true,
              fillColor: enabled ? surfaceColor : Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: TFMobileSpacing.lg,
                vertical: TFMobileSpacing.md,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.0),
                borderSide: BorderSide(color: borderColor, width: 1.2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.0),
                borderSide: BorderSide(color: borderColor, width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.0),
                borderSide: const BorderSide(color: TFMobileColors.primaryBlue, width: 2.0),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.0),
                borderSide: const BorderSide(color: TFMobileColors.error, width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
