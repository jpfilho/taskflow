import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/tf_mobile_spacing.dart';
import '../../../core/theme/tf_mobile_typography.dart';
import '../../../core/theme/tf_mobile_colors.dart';
import '../../../core/theme/tf_mobile_status_colors.dart';
import '../../../core/theme/tf_mobile_touch_targets.dart';
import '../../../core/widgets/tf_mobile_status_chip.dart';
import '../models/mobile_agenda_day_summary.dart';
import 'mobile_agenda_conflict_badge.dart';

/// Card de tarefa operacional dentro da agenda diária mobile.
/// Exibe horários, status semântico, código, título, recursos e conflitos.
class MobileAgendaSlotCard extends StatelessWidget {
  final MobileAgendaTaskItem task;
  final ValueChanged<String> onTapTask;

  const MobileAgendaSlotCard({
    super.key,
    required this.task,
    required this.onTapTask,
  });

  TFOperationalStatus _deriveStatus(String raw) {
    switch (raw.toUpperCase().trim()) {
      case 'ANDA':
        return TFOperationalStatus.emExecucao;
      case 'CONC':
        return TFOperationalStatus.concluido;
      case 'RPAR':
        return TFOperationalStatus.pausado;
      case 'RPGR':
        return TFOperationalStatus.pendente;
      case 'CANC':
        return TFOperationalStatus.cancelado;
      case 'PROG':
      default:
        return TFOperationalStatus.planejado;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _deriveStatus(task.statusRaw);
    final hasTime = task.horarioInicio != null || task.horarioFim != null;
    final timeStr = hasTime
        ? '${task.horarioInicio ?? "--:--"} – ${task.horarioFim ?? "--:--"}'
        : 'Horário Integral';

    return Container(
      margin: const EdgeInsets.only(bottom: TFMobileSpacing.sm),
      decoration: BoxDecoration(
        color: TFMobileColors.surface(context),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: task.hasConflict
              ? const Color(0xFFEF4444).withValues(alpha: 0.6)
              : TFMobileColors.border(context),
          width: task.hasConflict ? 1.5 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTapTask(task.taskId);
          },
          borderRadius: BorderRadius.circular(12.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: TFMobileTouchTargets.min,
            ),
            child: Padding(
              padding: const EdgeInsets.all(TFMobileSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Linha Superior: Horário + Status Chip
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8.0,
                    runSpacing: 4.0,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 15.0,
                            color: TFMobileColors.textSecondary(context),
                          ),
                          const SizedBox(width: 4.0),
                          Text(
                            timeStr,
                            style: TFMobileTypography.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              color: TFMobileColors.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                      TFMobileStatusChip.operational(status: status),
                    ],
                  ),

                  const SizedBox(height: TFMobileSpacing.xs),

                  // Código da Tarefa e Título
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6.0,
                          vertical: 2.0,
                        ),
                        decoration: BoxDecoration(
                          color: TFMobileColors.primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: Text(
                          task.codigo,
                          style: TFMobileTypography.caption.copyWith(
                            color: TFMobileColors.primaryBlue,
                            fontWeight: FontWeight.w800,
                            fontSize: 11.0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6.0),
                      Expanded(
                        child: Text(
                          task.titulo,
                          style: TFMobileTypography.bodyLarge.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  // Linha de Localização (se existir)
                  if (task.local != null && task.local!.isNotEmpty) ...[
                    const SizedBox(height: 6.0),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14.0,
                          color: TFMobileColors.textSecondary(context),
                        ),
                        const SizedBox(width: 4.0),
                        Expanded(
                          child: Text(
                            task.local!,
                            style: TFMobileTypography.caption.copyWith(
                              color: TFMobileColors.textSecondary(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Recursos: Equipe e Frota
                  if (task.equipeNome != null || task.veiculoNome != null) ...[
                    const SizedBox(height: 6.0),
                    Wrap(
                      spacing: TFMobileSpacing.sm,
                      runSpacing: 4.0,
                      children: [
                        if (task.equipeNome != null)
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 240.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.groups_outlined,
                                  size: 14.0,
                                  color: TFMobileColors.primaryBlue,
                                ),
                                const SizedBox(width: 3.0),
                                Flexible(
                                  child: Text(
                                    task.equipeNome!,
                                    style: TFMobileTypography.caption.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: TFMobileColors.textPrimary(context),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (task.veiculoNome != null)
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 240.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.directions_car_outlined,
                                  size: 14.0,
                                  color: TFMobileColors.textSecondary(context),
                                ),
                                const SizedBox(width: 3.0),
                                Flexible(
                                  child: Text(
                                    task.veiculoNome!,
                                    style: TFMobileTypography.caption.copyWith(
                                      color: TFMobileColors.textSecondary(context),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],

                  // Alerta de Conflito de Horário/Recurso
                  if (task.hasConflict) ...[
                    const SizedBox(height: 8.0),
                    MobileAgendaConflictBadge(message: task.conflictReason),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
