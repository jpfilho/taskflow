import 'package:flutter/material.dart';
import '../theme/tf_mobile_colors.dart';
import '../theme/tf_mobile_spacing.dart';
import '../theme/tf_mobile_typography.dart';
import '../theme/tf_mobile_status_colors.dart';
import 'tf_mobile_status_chip.dart';

/// Card base operacional reutilizável do TaskFlow Mobile.
/// Projetado para uso unificado em Atividades, Demandas, Ordens/Notas SAP e Feed.
class TFMobileCard extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final TFOperationalStatus? status;
  final TFSyncStatus? syncStatus;
  final bool offlinePending;
  final String? priority;
  final Color? leadingAccent;
  final Widget? body;
  final List<Widget>? metadata;
  final Widget? footer;
  final Widget? primaryAction;
  final Widget? secondaryAction;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final EdgeInsetsGeometry? padding;

  const TFMobileCard({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.status,
    this.syncStatus,
    this.offlinePending = false,
    this.priority,
    this.leadingAccent,
    this.body,
    this.metadata,
    this.footer,
    this.primaryAction,
    this.secondaryAction,
    this.onTap,
    this.semanticLabel,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = TFMobileColors.surface(context);
    final borderColor = TFMobileColors.border(context);
    final textPrimary = TFMobileColors.textPrimary(context);
    final textSecondary = TFMobileColors.textSecondary(context);

    Widget content = Padding(
      padding: padding ?? const EdgeInsets.all(TFMobileSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Leading + Título/Subtítulo + Status / Sync
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: TFMobileSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TFMobileTypography.titleMedium.copyWith(
                        color: textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: TFMobileSpacing.xxs),
                      Text(
                        subtitle!,
                        style: TFMobileTypography.bodyMedium.copyWith(
                          color: textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: TFMobileSpacing.sm),
              // Tags e Status
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (status != null)
                    TFMobileStatusChip.operational(
                      status: status!,
                      dense: true,
                    ),
                  if (offlinePending || (syncStatus != null && syncStatus == TFSyncStatus.pending)) ...[
                    const SizedBox(height: TFMobileSpacing.xs),
                    TFMobileStatusChip.sync(
                      status: TFSyncStatus.pending,
                      dense: true,
                    ),
                  ] else if (syncStatus != null && syncStatus != TFSyncStatus.synced) ...[
                    const SizedBox(height: TFMobileSpacing.xs),
                    TFMobileStatusChip.sync(
                      status: syncStatus!,
                      dense: true,
                    ),
                  ],
                ],
              ),
            ],
          ),

          // Body customizado
          if (body != null) ...[
            const SizedBox(height: TFMobileSpacing.md),
            body!,
          ],

          // Metadados (ex: Equipe, Veículo, Horário, Local)
          if (metadata != null && metadata!.isNotEmpty) ...[
            const SizedBox(height: TFMobileSpacing.md),
            Wrap(
              spacing: TFMobileSpacing.md,
              runSpacing: TFMobileSpacing.xs,
              children: metadata!,
            ),
          ],

          // Rodapé e Ações
          if (footer != null || primaryAction != null || secondaryAction != null) ...[
            const SizedBox(height: TFMobileSpacing.lg),
            const Divider(height: 1.0),
            const SizedBox(height: TFMobileSpacing.sm),
            if (footer != null) footer!,
            if (primaryAction != null || secondaryAction != null) ...[
              const SizedBox(height: TFMobileSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (secondaryAction != null) ...[
                    Expanded(child: secondaryAction!),
                    if (primaryAction != null) const SizedBox(width: TFMobileSpacing.sm),
                  ],
                  if (primaryAction != null)
                    Expanded(child: primaryAction!),
                ],
              ),
            ],
          ],
        ],
      ),
    );

    // Borda esquerda de destaque (Leading Accent) se fornecida
    if (leadingAccent != null) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(12.0),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 6.0,
                color: leadingAccent,
              ),
              Expanded(child: content),
            ],
          ),
        ),
      );
    }

    return Semantics(
      label: semanticLabel ?? title,
      button: onTap != null,
      child: Container(
        margin: const EdgeInsets.only(bottom: TFMobileSpacing.md),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: borderColor,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black38 : Colors.black.withOpacity(0.04),
              blurRadius: 6.0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12.0),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12.0),
            child: content,
          ),
        ),
      ),
    );
  }
}
