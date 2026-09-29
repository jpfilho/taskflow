import 'package:flutter/material.dart';
import '../../foundations/tf_icons.dart';
import '../../foundations/tf_radius.dart';
import '../../theme/taskflow_theme_extension.dart';

/// Estados possíveis de sincronização offline-first no TaskFlow.
enum TFSyncState {
  online,
  offline,
  syncing,
  pending,
  synced,
  error,
  conflict,
}

/// Indicador visual do estado de conectividade e sincronização local-remoto.
///
/// Componente puramente visual (não acoplado ao SyncService/SQLite nesta fase).
class TFSyncIndicator extends StatelessWidget {
  final TFSyncState state;
  final String? label;
  final bool compact;
  final VoidCallback? onTap;

  const TFSyncIndicator({
    super.key,
    required this.state,
    this.label,
    this.compact = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    final (IconData icon, Color color, String defaultLabel) = switch (state) {
      TFSyncState.online => (TFIcons.sync, colors.info, 'Conectado'),
      TFSyncState.offline => (TFIcons.offline, colors.textMuted, 'Offline'),
      TFSyncState.syncing => (TFIcons.sync, colors.primary, 'Sincronizando...'),
      TFSyncState.pending => (TFIcons.syncProblem, colors.warning, 'Pendente de envio'),
      TFSyncState.synced => (TFIcons.success, colors.success, 'Sincronizado'),
      TFSyncState.error => (TFIcons.error, colors.danger, 'Falha de sincronização'),
      TFSyncState.conflict => (TFIcons.warning, colors.warning, 'Conflito detectado'),
    };

    final displayLabel = label ?? defaultLabel;

    Widget indicatorIcon;
    if (state == TFSyncState.syncing) {
      indicatorIcon = SizedBox(
        width: compact ? 12.0 : 14.0,
        height: compact ? 12.0 : 14.0,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      );
    } else {
      indicatorIcon = Icon(
        icon,
        size: compact ? 14.0 : 16.0,
        color: color,
      );
    }

    if (compact) {
      Widget iconOnly = Tooltip(
        message: displayLabel,
        child: indicatorIcon,
      );

      if (onTap != null) {
        return InkWell(
          onTap: onTap,
          borderRadius: TFRadius.borderRadiusFull,
          child: Padding(
            padding: EdgeInsets.all(spacing.xs),
            child: iconOnly,
          ),
        );
      }
      return iconOnly;
    }

    Widget pill = Container(
      padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xxs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: TFRadius.borderRadiusFull,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          indicatorIcon,
          SizedBox(width: spacing.xs),
          Text(
            displayLabel,
            style: typography.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: TFRadius.borderRadiusFull,
        child: pill,
      );
    }

    return Semantics(
      label: 'Sincronização: $displayLabel',
      child: pill,
    );
  }
}
