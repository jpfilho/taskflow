import 'package:flutter/material.dart';
import '../../../core/theme/tf_mobile_spacing.dart';
import '../../../core/theme/tf_mobile_typography.dart';
import '../../../core/theme/tf_mobile_colors.dart';
import '../models/mobile_agenda_day_summary.dart';
import 'mobile_agenda_slot_card.dart';
import 'mobile_agenda_conflict_badge.dart';

/// Card de escala diária por veículo para a visualização 'Por Veículo' da agenda mobile.
class MobileFleetDayCard extends StatelessWidget {
  final MobileFleetAgendaGroup group;
  final ValueChanged<String> onTapTask;

  const MobileFleetDayCard({
    super.key,
    required this.group,
    required this.onTapTask,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: TFMobileSpacing.md),
      decoration: BoxDecoration(
        color: TFMobileColors.surface(context),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: group.hasConflict
              ? const Color(0xFFEF4444).withValues(alpha: 0.6)
              : TFMobileColors.border(context),
          width: group.hasConflict ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(TFMobileSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho do Veículo
            Row(
              children: [
                Container(
                  width: 36.0,
                  height: 36.0,
                  decoration: BoxDecoration(
                    color: group.emManutencao
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                        : TFMobileColors.primaryBlue.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.directions_car_rounded,
                    size: 20.0,
                    color: group.emManutencao
                        ? const Color(0xFFD97706)
                        : TFMobileColors.primaryBlue,
                  ),
                ),
                const SizedBox(width: TFMobileSpacing.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              group.veiculoNome,
                              style: TFMobileTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (group.emManutencao) ...[
                            const SizedBox(width: 6.0),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6.0,
                                vertical: 2.0,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(4.0),
                              ),
                              child: Text(
                                'MANUTENÇÃO',
                                style: TFMobileTypography.caption.copyWith(
                                  color: const Color(0xFF92400E),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 9.0,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        'Placa: ${group.placa} • ${group.tipoVeiculo}',
                        style: TFMobileTypography.caption.copyWith(
                          color: TFMobileColors.textSecondary(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 3.0,
                  ),
                  decoration: BoxDecoration(
                    color: TFMobileColors.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Text(
                    '${group.tasks.length} ${group.tasks.length == 1 ? "tarefa" : "tarefas"}',
                    style: TFMobileTypography.caption.copyWith(
                      color: TFMobileColors.primaryBlue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),

            if (group.hasConflict) ...[
              const SizedBox(height: TFMobileSpacing.xs),
              const MobileAgendaConflictBadge(
                message: 'Veículo com sobreposição de tarefas',
              ),
            ],

            if (group.equipeNome != null) ...[
              const SizedBox(height: TFMobileSpacing.xs),
              Text(
                'Condutor/Equipe: ${group.equipeNome}',
                style: TFMobileTypography.caption.copyWith(
                  color: TFMobileColors.textSecondary(context),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: TFMobileSpacing.sm),
            const Divider(height: 1.0),
            const SizedBox(height: TFMobileSpacing.sm),

            // Tarefas do Veículo
            ...group.tasks.map((task) => MobileAgendaSlotCard(
                  task: task,
                  onTapTask: onTapTask,
                )),
          ],
        ),
      ),
    );
  }
}
