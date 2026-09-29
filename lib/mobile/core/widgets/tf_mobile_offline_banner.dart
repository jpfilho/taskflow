import 'package:flutter/material.dart';
import '../theme/tf_mobile_spacing.dart';
import '../theme/tf_mobile_typography.dart';
import '../theme/tf_mobile_status_colors.dart';
import '../theme/tf_mobile_touch_targets.dart';

/// Banner de status de conectividade e sincronização offline para o TaskFlow Mobile.
class TFOfflineBanner extends StatelessWidget {
  final TFSyncStatus status;
  final int pendingCount;
  final VoidCallback? onSyncNow;

  const TFOfflineBanner({
    super.key,
    required this.status,
    this.pendingCount = 0,
    this.onSyncNow,
  });

  @override
  Widget build(BuildContext context) {
    // Se estiver online e 100% sincronizado sem pendências, não ocupa espaço desnecessário
    if (status == TFSyncStatus.synced && pendingCount == 0) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final config = TFMobileStatusColors.forSync(status, isDark: isDark);

    String message;
    if (status == TFSyncStatus.offline) {
      message = pendingCount > 0
          ? 'Modo Offline: $pendingCount alteração(ões) salva(s) localmente'
          : 'Modo Offline: trabalhando com dados em cache';
    } else if (status == TFSyncStatus.syncing) {
      message = 'Sincronizando $pendingCount alteração(ões) com o servidor...';
    } else if (status == TFSyncStatus.pending || pendingCount > 0) {
      message = '$pendingCount item(ns) aguardando conexão para envio';
    } else if (status == TFSyncStatus.error) {
      message = 'Falha na sincronização. Toque para tentar novamente.';
    } else {
      message = 'Dispositivo Conectado';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: TFMobileSpacing.lg,
        vertical: TFMobileSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: config.background,
        border: Border(
          bottom: BorderSide(color: config.border, width: 1.5),
        ),
      ),
      child: Row(
        children: [
          Icon(config.icon, size: 20.0, color: config.foreground),
          const SizedBox(width: TFMobileSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: TFMobileTypography.label.copyWith(
                color: config.foreground,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onSyncNow != null && status != TFSyncStatus.syncing) ...[
            const SizedBox(width: TFMobileSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: TFMobileTouchTargets.min),
              child: TextButton.icon(
                onPressed: onSyncNow,
                icon: Icon(Icons.sync_rounded, size: 18.0, color: config.foreground),
                label: Text(
                  'Sincronizar',
                  style: TFMobileTypography.label.copyWith(
                    color: config.foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: TFMobileSpacing.sm),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
