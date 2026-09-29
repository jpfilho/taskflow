import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/tf_mobile_spacing.dart';
import '../../../core/theme/tf_mobile_typography.dart';
import '../../../core/theme/tf_mobile_status_colors.dart';
import '../../../core/widgets/tf_mobile_status_chip.dart';
import '../../../core/widgets/tf_mobile_buttons.dart';
import '../models/mobile_task_view_model.dart';

/// Card operacional de atividade para smartphones.
/// Destaca estritamente as informações necessárias para execução em campo,
/// com touch targets >= 48px, alto contraste e feedback tátil sutil.
class MobileTaskCard extends StatelessWidget {
  final MobileTaskViewModel task;
  final VoidCallback onTap;
  final VoidCallback? onPrimaryAction;
  final bool isProcessing;

  const MobileTaskCard({
    super.key,
    required this.task,
    required this.onTap,
    this.onPrimaryAction,
    this.isProcessing = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      margin: const EdgeInsets.only(bottom: TFMobileSpacing.md),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: borderColor, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
            blurRadius: 8.0,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16.0),
        child: InkWell(
          onTap: isProcessing
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap();
                },
          borderRadius: BorderRadius.circular(16.0),
          child: Padding(
            padding: const EdgeInsets.all(TFMobileSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Cabeçalho: Status + Prioridade Factual
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: TFMobileSpacing.sm,
                  runSpacing: TFMobileSpacing.xs,
                  children: [
                    if (!task.isUnknownStatus)
                      TFMobileStatusChip.operational(
                        status: task.status,
                        dense: true,
                      )
                    else
                      TFMobileStatusChip.custom(
                        customLabel: task.rawStatus,
                        customIcon: Icons.help_outline_rounded,
                        customBackground: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                        customForeground: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                        customBorder: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                        dense: true,
                      ),
                    if (task.syncStatus == TFSyncStatus.pending)
                      TFMobileStatusChip.sync(
                        status: TFSyncStatus.pending,
                        dense: true,
                      ),
                    if (task.priority != null) _buildPriorityBadge(context, task.priority!, isDark),
                  ],
                ),
                const SizedBox(height: TFMobileSpacing.md),

                // 2. Título da Atividade
                Text(
                  task.title,
                  style: TFMobileTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: TFMobileSpacing.sm),

                // 3. Localização / Ativo
                if (task.location != null || task.asset != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: TFMobileSpacing.xs),
                    child: Row(
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 16.0,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: TFMobileSpacing.xs),
                        Expanded(
                          child: Text(
                            task.location ?? task.asset ?? '',
                            style: TFMobileTypography.bodyMedium.copyWith(
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                // 4. Data e Horário
                if (task.formattedDate != null || task.timeWindow != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: TFMobileSpacing.xs),
                    child: Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 16.0,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: TFMobileSpacing.xs),
                        Expanded(
                          child: Text(
                            [
                              if (task.formattedDate != null) task.formattedDate,
                              if (task.timeWindow != null) task.timeWindow,
                            ].join(' • '),
                            style: TFMobileTypography.caption.copyWith(
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                // 5. Equipe e Veículo
                if (task.teamName != null || task.vehiclePlate != null)
                  Padding(
                    padding: const EdgeInsets.only(top: TFMobileSpacing.xxs),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: TFMobileSpacing.xs,
                      runSpacing: TFMobileSpacing.xxs,
                      children: [
                        if (task.teamName != null) ...[
                          Icon(
                            Icons.groups_outlined,
                            size: 16.0,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          Text(
                            task.teamName!,
                            style: TFMobileTypography.caption.copyWith(
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        if (task.teamName != null && task.vehiclePlate != null)
                          Text('•', style: TextStyle(color: Colors.grey.shade500)),
                        if (task.vehiclePlate != null) ...[
                          Icon(
                            Icons.directions_car_outlined,
                            size: 16.0,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          Text(
                            task.vehiclePlate!,
                            style: TFMobileTypography.caption.copyWith(
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                // 6. Alerta de Pendências Reais (se houver)
                if (task.hasPendingItems) ...[
                  const SizedBox(height: TFMobileSpacing.sm),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: TFMobileSpacing.sm,
                      vertical: TFMobileSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF3B2712) : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(
                        color: isDark ? const Color(0xFF92400E) : const Color(0xFFFDE68A),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 16.0,
                          color: Color(0xFFD97706),
                        ),
                        const SizedBox(width: TFMobileSpacing.xs),
                        Expanded(
                          child: Text(
                            task.pendingApr ? 'APR não preenchida' : 'Alterações pendentes de sincronização',
                            style: TFMobileTypography.caption.copyWith(
                              color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: TFMobileSpacing.md),

                // 7. Ação Principal com Touch Target >= 48px e Proteção contra Duplo Toque
                SizedBox(
                  width: double.infinity,
                  height: 48.0,
                  child: task.actions.isReadOnly
                      ? TFSecondaryButton(
                          label: 'Ver Detalhes',
                          height: 48.0,
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            onTap();
                          },
                        )
                      : TFPrimaryButton(
                          label: isProcessing ? 'Processando...' : task.actions.primaryActionLabel,
                          height: 48.0,
                          onPressed: isProcessing
                              ? null
                              : () {
                                  HapticFeedback.lightImpact();
                                  if (onPrimaryAction != null) {
                                    onPrimaryAction!();
                                  } else {
                                    onTap();
                                  }
                                },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(BuildContext context, String priority, bool isDark) {
    final pUpper = priority.toUpperCase();
    Color bg;
    Color fg;

    if (pUpper.contains('ALTA') || pUpper.contains('URG')) {
      bg = isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2);
      fg = isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626);
    } else if (pUpper.contains('MED') || pUpper.contains('MÉD')) {
      bg = isDark ? const Color(0xFF3B2712) : const Color(0xFFFEF3C7);
      fg = isDark ? const Color(0xFFFDE68A) : const Color(0xFFD97706);
    } else {
      bg = isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5);
      fg = isDark ? const Color(0xFF6EE7B7) : const Color(0xFF059669);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: TFMobileSpacing.xs, vertical: 2.0),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6.0),
      ),
      child: Text(
        priority,
        style: TFMobileTypography.caption.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 11.0,
        ),
      ),
    );
  }
}
