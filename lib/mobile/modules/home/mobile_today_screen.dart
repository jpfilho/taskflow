import 'package:flutter/material.dart';
import '../../core/theme/tf_mobile_spacing.dart';
import '../../core/theme/tf_mobile_typography.dart';
import '../../core/theme/tf_mobile_colors.dart';
import '../../core/theme/tf_mobile_status_colors.dart';
import '../../core/widgets/tf_mobile_card.dart';
import '../../core/widgets/tf_mobile_buttons.dart';
import '../../core/widgets/tf_mobile_status_chip.dart';
import '../../core/widgets/tf_mobile_states.dart';
import '../../core/navigation/tf_mobile_navigator.dart';
import '../feed/widgets/tf_feed_card.dart';
import 'models/mobile_today_view_model.dart';
import 'adapters/mobile_today_adapter.dart';

/// Tela inicial "Hoje" do TaskFlow Mobile.
/// Central operacional do operador sem dados fictícios em produção.
class MobileTodayScreen extends StatefulWidget {
  final TFMobileNavigator navigator;

  const MobileTodayScreen({
    super.key,
    required this.navigator,
  });

  @override
  State<MobileTodayScreen> createState() => _MobileTodayScreenState();
}

class _MobileTodayScreenState extends State<MobileTodayScreen> {
  final MobileTodayAdapter _adapter = MobileTodayAdapter();
  late Future<MobileTodayViewModel> _futureData;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _futureData = _adapter.loadTodayData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = TFMobileColors.textPrimary(context);
    final textSecondary = TFMobileColors.textSecondary(context);

    return RefreshIndicator(
      onRefresh: () async {
        _loadData();
        await _futureData;
      },
      child: FutureBuilder<MobileTodayViewModel>(
        future: _futureData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: TFLoadingState(message: 'Carregando suas atividades de hoje...'),
            );
          }

            final data = snapshot.data ??
                MobileTodayViewModel(
                  userName: 'Colaborador',
                  userRole: 'Operação',
                  formattedDate: 'Hoje',
                );

            return ListView(
              padding: const EdgeInsets.all(TFMobileSpacing.lg),
              children: [
                // Saudação e Data
                Text(
                  'Bom dia, ${data.userName}',
                  style: TFMobileTypography.display.copyWith(color: textPrimary),
                ),
                const SizedBox(height: 2.0),
                Text(
                  data.formattedDate,
                  style: TFMobileTypography.bodyMedium.copyWith(color: textSecondary),
                ),

                const SizedBox(height: TFMobileSpacing.lg),

                // Card de Recursos do Dia (Veículo e Turma) ou Estado Vazio
                _buildDailyResourcesCard(data),

                const SizedBox(height: TFMobileSpacing.xl),

                // Resumo Numérico das Atividades de Hoje
                _buildSectionHeader('MINHAS ATIVIDADES DE HOJE (${data.totalTasksToday})'),
                if (!data.hasTasksToday)
                  Container(
                    padding: const EdgeInsets.all(TFMobileSpacing.lg),
                    margin: const EdgeInsets.only(bottom: TFMobileSpacing.md),
                    decoration: BoxDecoration(
                      color: TFMobileColors.surface(context),
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(color: TFMobileColors.border(context)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.assignment_turned_in_outlined, color: Colors.grey, size: 24.0),
                            const SizedBox(width: TFMobileSpacing.sm),
                            Text('Nenhuma atividade agendada', style: TFMobileTypography.titleMedium),
                          ],
                        ),
                        const SizedBox(height: TFMobileSpacing.xs),
                        Text(
                          'Você não possui ordens ou tarefas alocadas para o dia de hoje.',
                          style: TFMobileTypography.bodyMedium.copyWith(color: textSecondary),
                        ),
                        const SizedBox(height: TFMobileSpacing.md),
                        TFSecondaryButton(
                          label: 'Ver Todas as Atividades',
                          height: 48.0,
                          onPressed: () => widget.navigator.goToTasks(),
                        ),
                      ],
                    ),
                  )
                else ...[
                  // Resumo dos contadores
                  Row(
                    children: [
                      _buildCounterBadge('Pendentes', data.pendingTasks, const Color(0xFFB45309), const Color(0xFFFEF3C7)),
                      const SizedBox(width: TFMobileSpacing.sm),
                      _buildCounterBadge('Em Execução', data.inProgressTasks, TFMobileColors.primaryBlue, const Color(0xFFDBEAFE)),
                      const SizedBox(width: TFMobileSpacing.sm),
                      _buildCounterBadge('Concluídas', data.completedTasks, TFMobileColors.success, const Color(0xFFDCFCE7)),
                    ],
                  ),
                  const SizedBox(height: TFMobileSpacing.md),

                  // Próxima Atividade em Destaque
                  if (data.nextTask != null)
                    TFMobileCard(
                      title: data.nextTask!.title,
                      subtitle: data.nextTask!.location,
                      status: data.nextTask!.status,
                      leadingAccent: TFMobileColors.primaryBlue,
                      metadata: [
                        _buildMetaItem(Icons.access_time_rounded, data.nextTask!.timeRange),
                        if (data.nextTask!.sapOrderOrNote != null)
                          _buildMetaItem(Icons.assignment_outlined, data.nextTask!.sapOrderOrNote!),
                      ],
                      primaryAction: TFPrimaryButton(
                        label: data.nextTask!.status == TFOperationalStatus.emExecucao
                            ? 'Continuar Execução'
                            : 'Iniciar Atividade',
                        height: 48.0,
                        onPressed: () {
                          widget.navigator.openTaskDetail(data.nextTask!.id, taskTitle: data.nextTask!.title);
                        },
                      ),
                    ),
                ],

                const SizedBox(height: TFMobileSpacing.xl),

                // Seção: ACONTECENDO AGORA (Sincronizada com o Feed)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionHeader('ACONTECENDO AGORA'),
                    TextButton(
                      onPressed: () => widget.navigator.goToFeed(),
                      child: Text(
                        'Ver Feed',
                        style: TFMobileTypography.label.copyWith(
                          color: TFMobileColors.primaryBlue,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (!data.hasHappeningNow)
                  Container(
                    padding: const EdgeInsets.all(TFMobileSpacing.md),
                    decoration: BoxDecoration(
                      color: TFMobileColors.surface(context),
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(color: TFMobileColors.border(context)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Colors.grey, size: 20.0),
                        const SizedBox(width: TFMobileSpacing.sm),
                        Expanded(
                          child: Text(
                            'Nenhuma atualização recente no momento.',
                            style: TFMobileTypography.caption.copyWith(color: textSecondary),
                          ),
                        ),
                        TextButton(
                          onPressed: () => widget.navigator.goToFeed(),
                          child: const Text('Ir para o Feed'),
                        ),
                      ],
                    ),
                  )
                else
                  ...data.happeningNowEvents.map((item) {
                    return TFFeedCard(
                      item: item,
                      onViewLinkedEntity: () {
                        if (item.linkedEntityId != null) {
                          widget.navigator.openTaskDetail(item.linkedEntityId!, taskTitle: item.linkedEntityTitle);
                        }
                      },
                    );
                  }),
              ],
            );
          },
        ),
      );
  }

  Widget _buildDailyResourcesCard(MobileTodayViewModel data) {
    final surfaceColor = TFMobileColors.surface(context);
    final borderColor = TFMobileColors.border(context);
    final textSecondary = TFMobileColors.textSecondary(context);

    return Container(
      padding: const EdgeInsets.all(TFMobileSpacing.md),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        children: [
          // Veículo
          Row(
            children: [
              const Icon(Icons.directions_car_rounded, color: TFMobileColors.primaryBlue, size: 24.0),
              const SizedBox(width: TFMobileSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Veículo do Dia', style: TFMobileTypography.caption.copyWith(color: textSecondary)),
                    Text(
                      data.hasAssignedVehicle
                          ? '${data.vehicle!.model} (${data.vehicle!.plate})'
                          : 'Nenhum veículo associado hoje',
                      style: TFMobileTypography.titleMedium,
                    ),
                  ],
                ),
              ),
              if (data.hasAssignedVehicle)
                const TFMobileStatusChip.operational(status: TFOperationalStatus.emExecucao, dense: true),
            ],
          ),
          const Divider(height: 16.0),
          // Equipe
          Row(
            children: [
              const Icon(Icons.group_rounded, color: Color(0xFF0369A1), size: 24.0),
              const SizedBox(width: TFMobileSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Equipe Operacional', style: TFMobileTypography.caption.copyWith(color: textSecondary)),
                    Text(
                      data.hasAssignedTeam
                          ? '${data.team!.teamName} (${data.team!.membersCount} técnicos)'
                          : 'Nenhuma equipe associada',
                      style: TFMobileTypography.titleMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCounterBadge(String label, int count, Color color, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: TFMobileSpacing.sm),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TFMobileTypography.titleLarge.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: TFMobileTypography.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14.0, color: TFMobileColors.textSecondary(context)),
        const SizedBox(width: 4.0),
        Text(text, style: TFMobileTypography.caption),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TFMobileSpacing.sm),
      child: Text(
        title,
        style: TFMobileTypography.titleMedium.copyWith(
          color: TFMobileColors.primaryBlue,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
