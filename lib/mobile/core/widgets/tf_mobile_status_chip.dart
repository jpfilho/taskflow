import 'package:flutter/material.dart';
import '../theme/tf_mobile_status_colors.dart';
import '../theme/tf_mobile_typography.dart';
import '../theme/tf_mobile_spacing.dart';

/// Chip de status universal do TaskFlow Mobile com alto contraste sob sol.
/// Combina cor de fundo, borda, ícone e texto para máxima acessibilidade.
class TFMobileStatusChip extends StatelessWidget {
  final TFOperationalStatus? operationalStatus;
  final TFSyncStatus? syncStatus;
  final String? customLabel;
  final IconData? customIcon;
  final Color? customBackground;
  final Color? customForeground;
  final Color? customBorder;
  final VoidCallback? onTap;
  final bool dense;

  const TFMobileStatusChip.operational({
    super.key,
    required TFOperationalStatus status,
    this.dense = false,
    this.onTap,
  })  : operationalStatus = status,
        syncStatus = null,
        customLabel = null,
        customIcon = null,
        customBackground = null,
        customForeground = null,
        customBorder = null;

  const TFMobileStatusChip.sync({
    super.key,
    required TFSyncStatus status,
    this.dense = false,
    this.onTap,
  })  : syncStatus = status,
        operationalStatus = null,
        customLabel = null,
        customIcon = null,
        customBackground = null,
        customForeground = null,
        customBorder = null;

  const TFMobileStatusChip.custom({
    super.key,
    required this.customLabel,
    required this.customIcon,
    required this.customBackground,
    required this.customForeground,
    required this.customBorder,
    this.dense = false,
    this.onTap,
  })  : operationalStatus = null,
        syncStatus = null;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    TFStatusVisualConfig config;
    if (operationalStatus != null) {
      config = TFMobileStatusColors.forOperational(operationalStatus!, isDark: isDark);
    } else if (syncStatus != null) {
      config = TFMobileStatusColors.forSync(syncStatus!, isDark: isDark);
    } else {
      config = TFStatusVisualConfig(
        label: customLabel ?? '',
        icon: customIcon ?? Icons.info_outline_rounded,
        background: customBackground ?? Colors.grey.shade200,
        foreground: customForeground ?? Colors.black87,
        border: customBorder ?? Colors.grey.shade400,
      );
    }

    final chipWidget = Container(
      constraints: BoxConstraints(
        minHeight: dense ? 28.0 : 36.0,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: dense ? TFMobileSpacing.sm : TFMobileSpacing.md,
        vertical: dense ? TFMobileSpacing.xxs : TFMobileSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: config.background,
        borderRadius: BorderRadius.circular(18.0),
        border: Border.all(
          color: config.border,
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            config.icon,
            size: dense ? 14.0 : 16.0,
            color: config.foreground,
          ),
          const SizedBox(width: TFMobileSpacing.xs),
          Flexible(
            child: Text(
              config.label,
              style: TFMobileTypography.label.copyWith(
                color: config.foreground,
                fontSize: dense ? 11.0 : 12.0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18.0),
        child: chipWidget,
      );
    }

    return chipWidget;
  }
}
