import 'package:flutter/material.dart';
import '../theme/tf_mobile_touch_targets.dart';
import '../theme/tf_mobile_spacing.dart';
import '../theme/tf_mobile_typography.dart';
import '../theme/tf_mobile_colors.dart';

/// Botão Primário do TaskFlow Mobile (Ações principais de campo: Iniciar, Concluir, Salvar, Publicar).
class TFPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final double height;
  final bool fullWidth;

  const TFPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.height = TFMobileTouchTargets.standard, // 52px
    this.fullWidth = true,
  }) : assert(height >= TFMobileTouchTargets.min, 'Altura mínima deve ser >= 48px');

  @override
  Widget build(BuildContext context) {
    Widget child = isLoading
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
        : Row(
            mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20.0, color: Colors.white),
                const SizedBox(width: TFMobileSpacing.sm),
              ],
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: TFMobileTypography.titleMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          );

    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: height,
        minWidth: fullWidth ? double.infinity : 0.0,
      ),
      child: SizedBox(
        width: fullWidth ? double.infinity : null,
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: TFMobileColors.primaryBlue,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade400,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            padding: const EdgeInsets.symmetric(horizontal: TFMobileSpacing.md),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Botão Secundário do TaskFlow Mobile (Borda visível, fundo sutil).
class TFSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final double height;
  final bool fullWidth;

  const TFSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.height = TFMobileTouchTargets.standard,
    this.fullWidth = true,
  }) : assert(height >= TFMobileTouchTargets.min, 'Altura mínima deve ser >= 48px');

  @override
  Widget build(BuildContext context) {
    final textPrimary = TFMobileColors.textPrimary(context);
    final borderColor = TFMobileColors.border(context);

    Widget child = isLoading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(textPrimary),
            ),
          )
        : Row(
            mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20.0, color: textPrimary),
                const SizedBox(width: TFMobileSpacing.sm),
              ],
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: TFMobileTypography.titleMedium.copyWith(
                      color: textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          );

    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: height,
        minWidth: fullWidth ? double.infinity : 0.0,
      ),
      child: SizedBox(
        width: fullWidth ? double.infinity : null,
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: textPrimary,
            side: BorderSide(color: borderColor, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            padding: const EdgeInsets.symmetric(horizontal: TFMobileSpacing.md),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Botão Terciário (Texto sem borda, para cancelar ou ações discretas).
class TFTertiaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;

  const TFTertiaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = TFMobileTouchTargets.min,
  }) : assert(height >= TFMobileTouchTargets.min);

  @override
  Widget build(BuildContext context) {
    final primaryColor = TFMobileColors.primaryBlue;

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: height, minWidth: TFMobileTouchTargets.min),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: TFMobileSpacing.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18.0),
              const SizedBox(width: TFMobileSpacing.xs),
            ],
            Text(
              label,
              style: TFMobileTypography.titleMedium.copyWith(
                color: primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botão Destrutivo (Excluir, Cancelar Tarefa, Bloquear, Remover).
class TFDestructiveButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool fullWidth;

  const TFDestructiveButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.fullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: TFMobileTouchTargets.standard,
      width: fullWidth ? double.infinity : null,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: TFMobileColors.error,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          padding: const EdgeInsets.symmetric(horizontal: TFMobileSpacing.lg),
        ),
        child: Row(
          mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20.0, color: Colors.white),
              const SizedBox(width: TFMobileSpacing.sm),
            ],
            Text(
              label,
              style: TFMobileTypography.titleMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botão de Ícone com garantia de touch target mínimo de 48 × 48 px.
class TFIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final Color? backgroundColor;
  final double iconSize;

  const TFIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color,
    this.backgroundColor,
    this.iconSize = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = TFMobileColors.textPrimary(context);

    Widget button = Container(
      width: TFMobileTouchTargets.min,
      height: TFMobileTouchTargets.min,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, size: iconSize),
        color: color ?? textPrimary,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        splashRadius: 24.0,
      ),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        child: button,
      );
    }

    return button;
  }
}
