import 'package:flutter/material.dart';
import '../../../core/theme/tf_mobile_spacing.dart';
import '../../../core/theme/tf_mobile_typography.dart';
import '../../../core/theme/tf_mobile_colors.dart';
import '../models/mobile_agenda_day_summary.dart';
import 'mobile_agenda_slot_card.dart';
import 'mobile_agenda_conflict_badge.dart';

/// Card de escala diária por equipe para a visualização 'Por Equipe' da agenda mobile.
class MobileTeamDayCard extends StatelessWidget {
  final MobileTeamAgendaGroup group;
  final ValueChanged<String> onTapTask;

  const MobileTeamDayCard({
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
            // Cabeçalho da Equipe
            Row(
              children: [
                Container(
                  width: 36.0,
                  height: 36.0,
                  decoration: BoxDecoration(
                    color: TFMobileColors.primaryBlue.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.groups_rounded,
                    size: 20.0,
                    color: TFMobileColors.primaryBlue,
                  ),
                ),
                const SizedBox(width: TFMobileSpacing.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.equipeNome,
                        style: TFMobileTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (group.encarregadoNome != null)
                        Text(
                          'Líder: ${group.encarregadoNome}',
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
                message: 'Sobreposição de tarefas nesta equipe',
              ),
            ],

            // Lista de Membros (se houver)
            if (group.membrosNomes.isNotEmpty) ...[
              const SizedBox(height: TFMobileSpacing.xs),
              Text(
                'Membros: ${group.membrosNomes.join(", ")}',
                style: TFMobileTypography.caption.copyWith(
                  color: TFMobileColors.textSecondary(context),
                  fontSize: 11.0,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: TFMobileSpacing.sm),
            const Divider(height: 1.0),
            const SizedBox(height: TFMobileSpacing.sm),

            // Tarefas da Equipe
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
