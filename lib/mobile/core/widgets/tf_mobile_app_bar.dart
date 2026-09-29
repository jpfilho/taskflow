import 'package:flutter/material.dart';
import '../theme/tf_mobile_spacing.dart';
import '../theme/tf_mobile_typography.dart';
import '../theme/tf_mobile_colors.dart';
import '../theme/tf_mobile_status_colors.dart';
import '../theme/tf_mobile_touch_targets.dart';

/// Barra de aplicativo minimalista e ergonômica para smartphone.
class TFMobileAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final bool showBack;
  final VoidCallback? onBack;
  final TFSyncStatus? syncStatus;
  final Widget? primaryAction;
  final List<Widget>? actions;

  const TFMobileAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.showBack = false,
    this.onBack,
    this.syncStatus,
    this.primaryAction,
    this.actions,
  });

  @override
  Size get preferredSize => Size.fromHeight(subtitle != null ? 60.0 : 56.0);

  @override
  Widget build(BuildContext context) {
    final surfaceColor = TFMobileColors.surface(context);
    final borderColor = TFMobileColors.border(context);
    final textPrimary = TFMobileColors.textPrimary(context);
    final textSecondary = TFMobileColors.textSecondary(context);

    return AppBar(
      toolbarHeight: subtitle != null ? 60.0 : 56.0,
      backgroundColor: surfaceColor,
      elevation: 0,
      scrolledUnderElevation: 1.0,
      centerTitle: false,
      automaticallyImplyLeading: false,
      leading: showBack
          ? SizedBox(
              width: TFMobileTouchTargets.min,
              height: TFMobileTouchTargets.min,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                color: textPrimary,
                iconSize: 20.0,
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                tooltip: 'Voltar',
                splashRadius: 24.0,
              ),
            )
          : null,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: TFMobileTypography.titleLarge.copyWith(
                    color: textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (syncStatus != null) ...[
                const SizedBox(width: TFMobileSpacing.xs),
                _buildSyncIndicator(syncStatus!),
              ],
            ],
          ),
          if (subtitle != null) ...[
            Text(
              subtitle!,
              style: TFMobileTypography.caption.copyWith(
                color: textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
      actions: [
        if (actions != null) ...actions!,
        if (primaryAction != null) primaryAction!,
        const SizedBox(width: TFMobileSpacing.xs),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1.0),
        child: Container(color: borderColor, height: 1.0),
      ),
    );
  }

  Widget _buildSyncIndicator(TFSyncStatus status) {
    IconData icon;
    Color color;
    switch (status) {
      case TFSyncStatus.online:
      case TFSyncStatus.synced:
        icon = Icons.cloud_done_rounded;
        color = TFMobileColors.success;
        break;
      case TFSyncStatus.syncing:
        icon = Icons.sync_rounded;
        color = TFMobileColors.primaryBlue;
        break;
      case TFSyncStatus.pending:
      case TFSyncStatus.offline:
        icon = Icons.cloud_off_rounded;
        color = TFMobileColors.warning;
        break;
      case TFSyncStatus.error:
        icon = Icons.error_outline_rounded;
        color = TFMobileColors.error;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Icon(icon, size: 16.0, color: color),
    );
  }
}
