import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../design_system/taskflow_design_system.dart';
import '../../../../models/melhoria_bug.dart';

class MelhoriaBugCard extends StatelessWidget {
  final MelhoriaBug item;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;

  const MelhoriaBugCard({
    super.key,
    required this.item,
    this.onTap,
    this.onEdit,
  });

  TFStatusSeverity _getStatusSeverity(String status) {
    switch (status) {
      case 'BACKLOG':
        return TFStatusSeverity.neutral;
      case 'ANALISE':
        return TFStatusSeverity.info;
      case 'DESENVOLVIMENTO':
      case 'VALIDACAO':
        return TFStatusSeverity.warning;
      case 'CONCLUIDO':
        return TFStatusSeverity.success;
      case 'REABERTO':
      case 'REJEITADO':
        return TFStatusSeverity.danger;
      case 'DUPLICADO':
        return TFStatusSeverity.neutral;
      default:
        return TFStatusSeverity.neutral;
    }
  }

  TFStatusSeverity _getPrioritySeverity(String? priority) {
    switch (priority) {
      case 'CRITICA':
        return TFStatusSeverity.danger;
      case 'ALTA':
        return TFStatusSeverity.warning;
      case 'MEDIA':
        return TFStatusSeverity.info;
      case 'BAIXA':
        return TFStatusSeverity.neutral;
      default:
        return TFStatusSeverity.neutral;
    }
  }

  String _getPriorityLabel(String? priority) {
    switch (priority) {
      case 'CRITICA':
        return 'Crítica';
      case 'ALTA':
        return 'Alta';
      case 'MEDIA':
        return 'Média';
      case 'BAIXA':
        return 'Baixa';
      default:
        return priority ?? '';
    }
  }

  Widget? _buildPrazoBadge(BuildContext context) {
    if (item.prazo == null) {
      if (item.isAberta) {
        return const TFStatusBadge(
          label: 'Sem prazo',
          severity: TFStatusSeverity.neutral,
          icon: Icons.calendar_today_outlined,
          compact: true,
        );
      }
      return null;
    }

    if (item.isPrazoVencido) {
      final dias = item.diasRestantesPrazo?.abs() ?? 0;
      return TFStatusBadge(
        label: dias == 0 ? 'Venceu hoje' : 'Vencido há ${dias}d',
        severity: TFStatusSeverity.danger,
        icon: Icons.error_outline_rounded,
        compact: true,
      );
    }

    if (item.isPrazoProximo) {
      final dias = item.diasRestantesPrazo ?? 0;
      final text = dias == 0
          ? 'Vence hoje'
          : dias == 1
              ? 'Vence amanhã'
              : 'Vence em ${dias}d';
      return TFStatusBadge(
        label: text,
        severity: TFStatusSeverity.warning,
        icon: Icons.access_time_rounded,
        compact: true,
      );
    }

    return TFStatusBadge(
      label: DateFormat('dd/MM/yyyy').format(item.prazo!),
      severity: TFStatusSeverity.info,
      icon: Icons.event_outlined,
      compact: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final isBug = item.tipo == kTipoBug;
    final statusSeverity = _getStatusSeverity(item.status);
    final prioritySeverity = _getPrioritySeverity(item.prioridade);
    final prazoBadge = _buildPrazoBadge(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TFCard(
        variant: TFCardVariant.interactive,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TFStatusBadge(
                        label: isBug ? 'BUG' : 'MELHORIA',
                        severity: isBug ? TFStatusSeverity.danger : TFStatusSeverity.info,
                        icon: isBug ? Icons.bug_report_outlined : Icons.lightbulb_outline,
                        compact: true,
                      ),
                      if (item.prioridade != null && item.prioridade!.isNotEmpty)
                        TFStatusBadge(
                          label: _getPriorityLabel(item.prioridade),
                          severity: prioritySeverity,
                          compact: true,
                        ),
                      if (prazoBadge != null)
                        prazoBadge,
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TFStatusBadge(
                  label: item.statusLabel,
                  severity: statusSeverity,
                  compact: true,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.titulo,
              style: typography.cardTitle.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (item.descricao != null && item.descricao!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                item.descricao!,
                style: typography.bodySmall.copyWith(
                  color: colors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (item.feedback != null && item.feedback!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.08),
                  borderRadius: TFRadius.borderRadiusSm,
                  border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 14,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Feedback da equipe:',
                            style: typography.caption.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.feedback!,
                            style: typography.bodySmall.copyWith(
                              color: colors.textPrimary,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      if (item.createdBy != null && item.createdBy!.isNotEmpty) ...[
                        Icon(
                          Icons.person_outline_rounded,
                          size: 14,
                          color: colors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            item.createdBy!,
                            style: typography.caption.copyWith(
                              color: colors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      if (item.versaoCorrigida != null && item.versaoCorrigida!.isNotEmpty) ...[
                        if (item.createdBy != null && item.createdBy!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text('•', style: typography.caption.copyWith(color: colors.textMuted)),
                          ),
                        Text(
                          'Corrigido em: ${item.versaoCorrigida}',
                          style: typography.caption.copyWith(
                            color: colors.textMuted,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: colors.textMuted,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
