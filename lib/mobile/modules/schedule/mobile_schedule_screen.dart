import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/theme/tf_mobile_spacing.dart';
import '../../core/theme/tf_mobile_typography.dart';
import '../../core/theme/tf_mobile_colors.dart';
import '../../core/theme/tf_mobile_touch_targets.dart';
import '../../core/widgets/tf_mobile_states.dart';
import '../../core/navigation/tf_mobile_navigator.dart';
import '../../../models/task.dart';
import 'models/mobile_agenda_view_mode.dart';
import 'models/mobile_agenda_day_summary.dart';
import 'adapters/mobile_schedule_adapter.dart';
import 'widgets/day_carousel_selector.dart';
import 'widgets/mobile_agenda_slot_card.dart';
import 'widgets/mobile_team_day_card.dart';
import 'widgets/mobile_fleet_day_card.dart';

/// Tela de Programação e Agenda Mobile para smartphones (Fase 4).
/// Substitui o gráfico Gantt mensal por uma agenda cronológica vertical ergonômica,
/// com seletor de dia em carrossel e modos de visualização por Horário, Equipes e Frota.
class MobileScheduleScreen extends StatefulWidget {
  final DateTime? initialDate;
  final MobileAgendaViewMode initialMode;
  final TFMobileNavigator? navigator;
  final MobileScheduleAdapter? adapter;
  final List<Task>? preloadedTasks;

  const MobileScheduleScreen({
    super.key,
    this.initialDate,
    this.initialMode = MobileAgendaViewMode.timeline,
    this.navigator,
    this.adapter,
    this.preloadedTasks,
  });

  @override
  State<MobileScheduleScreen> createState() => _MobileScheduleScreenState();
}

class _MobileScheduleScreenState extends State<MobileScheduleScreen> {
  late DateTime _selectedDate;
  late MobileAgendaViewMode _viewMode;
  late final MobileScheduleAdapter _adapter;

  bool _isLoading = true;
  List<Task> _allTasks = [];
  List<MobileAgendaDaySummary> _daysSummaries = [];

  // Dados calculados para o dia selecionado
  List<Task> _dayTasks = [];
  List<MobileAgendaSlot> _timelineSlots = [];
  List<MobileTeamAgendaGroup> _teamGroups = [];
  List<MobileFleetAgendaGroup> _fleetGroups = [];

  // Intervalo de dias do carrossel (15 dias antes a 20 dias depois)
  late final DateTime _rangeStart;
  late final DateTime _rangeEnd;

  @override
  void initState() {
    super.initState();
    final baseDate = widget.initialDate ?? DateTime.now();
    _selectedDate = DateTime(baseDate.year, baseDate.month, baseDate.day);
    _viewMode = widget.initialMode;
    _adapter = widget.adapter ?? MobileScheduleAdapter();

    _rangeStart = _selectedDate.subtract(const Duration(days: 14));
    _rangeEnd = _selectedDate.add(const Duration(days: 21));

    _daysSummaries = _adapter.buildDaysSummaries(
      rangeStart: _rangeStart,
      rangeEnd: _rangeEnd,
      tasks: widget.preloadedTasks ?? const [],
      selectedDate: _selectedDate,
    );

    if (widget.preloadedTasks != null) {
      _allTasks = widget.preloadedTasks!;
      _dayTasks = _allTasks
          .where((t) => MobileScheduleAdapter.taskOccursOnDay(t, _selectedDate))
          .toList();
      _timelineSlots = _adapter.buildTimelineSlots(_dayTasks, _selectedDate);
      _teamGroups = _adapter.buildTeamsGroupsSync(_dayTasks, _selectedDate);
      _fleetGroups = _adapter.buildFleetGroupsSync(_dayTasks, _selectedDate);
      _isLoading = false;
      _computeDayData().then((_) {
        if (mounted) setState(() {});
      });
    } else {
      _loadScheduleData();
    }
  }

  Future<void> _loadScheduleData() async {
    setState(() => _isLoading = true);

    try {
      final tasks = await _adapter.loadTasksForRange(_rangeStart, _rangeEnd);
      if (mounted) {
        setState(() {
          _allTasks = tasks;
        });
        await _computeDayData();
      }
    } catch (_) {
      if (mounted) {
        await _computeDayData();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _computeDayData() async {
    _daysSummaries = _adapter.buildDaysSummaries(
      rangeStart: _rangeStart,
      rangeEnd: _rangeEnd,
      tasks: _allTasks,
      selectedDate: _selectedDate,
    );

    _dayTasks = _allTasks
        .where((t) => MobileScheduleAdapter.taskOccursOnDay(t, _selectedDate))
        .toList();

    _timelineSlots = _adapter.buildTimelineSlots(_dayTasks, _selectedDate);
    _teamGroups = _adapter.buildTeamsGroupsSync(_dayTasks, _selectedDate);
    _fleetGroups = _adapter.buildFleetGroupsSync(_dayTasks, _selectedDate);

    // Enriquecimento assíncrono em segundo plano (não bloqueia UI)
    try {
      final teams = await _adapter.buildTeamsGroups(_dayTasks, _selectedDate);
      final fleet = await _adapter.buildFleetGroups(_dayTasks, _selectedDate);
      if (mounted) {
        setState(() {
          _teamGroups = teams;
          _fleetGroups = fleet;
        });
      }
    } catch (_) {}
  }

  void _onSelectDay(DateTime day) {
    setState(() {
      _selectedDate = DateTime(day.year, day.month, day.day);
      _dayTasks = _allTasks
          .where((t) => MobileScheduleAdapter.taskOccursOnDay(t, _selectedDate))
          .toList();
      _timelineSlots = _adapter.buildTimelineSlots(_dayTasks, _selectedDate);
      _teamGroups = _adapter.buildTeamsGroupsSync(_dayTasks, _selectedDate);
      _fleetGroups = _adapter.buildFleetGroupsSync(_dayTasks, _selectedDate);
    });
    _computeDayData().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _onSwitchMode(MobileAgendaViewMode mode) {
    HapticFeedback.selectionClick();
    setState(() {
      _viewMode = mode;
    });
  }

  void _goToToday() {
    final now = DateTime.now();
    _onSelectDay(DateTime(now.year, now.month, now.day));
  }

  void _openTaskDetail(String taskId) {
    if (widget.navigator != null) {
      widget.navigator!.openTaskDetail(taskId);
    } else {
      TFMobileNavigator(context: context).openTaskDetail(taskId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateFormatted = DateFormat("EEEE, d 'de' MMMM", 'pt_BR')
        .format(_selectedDate);
    final capitalizedDate = dateFormatted[0].toUpperCase() +
        dateFormatted.substring(1);

    return Scaffold(
      backgroundColor: TFMobileColors.background(context),
      appBar: AppBar(
        backgroundColor: TFMobileColors.surface(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Programação & Agenda',
              style: TFMobileTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              capitalizedDate,
              style: TFMobileTypography.caption.copyWith(
                color: TFMobileColors.primaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          // Botão 'Hoje' rápido
          TextButton.icon(
            onPressed: _goToToday,
            icon: const Icon(Icons.today_rounded, size: 16.0),
            label: const Text('Hoje'),
            style: TextButton.styleFrom(
              foregroundColor: TFMobileColors.primaryBlue,
              textStyle: TFMobileTypography.caption.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Atualizar programação',
            onPressed: _loadScheduleData,
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Carrossel Horizontal de Seleção de Dia
          DayCarouselSelector(
            days: _daysSummaries,
            selectedDate: _selectedDate,
            onDaySelected: _onSelectDay,
          ),

          // 2. Alternador de Modo de Visão (Horário | Equipes | Frota)
          _buildViewModeToggle(context, isDark),

          // 3. Conteúdo Principal da Programação
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadScheduleData,
                    child: _buildMainContent(context),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewModeToggle(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TFMobileSpacing.md,
        vertical: TFMobileSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: TFMobileColors.surface(context),
        border: Border(
          bottom: BorderSide(color: TFMobileColors.border(context), width: 1.0),
        ),
      ),
      child: Row(
        children: [
          _buildModeChip(MobileAgendaViewMode.timeline, Icons.access_time_rounded),
          const SizedBox(width: TFMobileSpacing.xs),
          _buildModeChip(MobileAgendaViewMode.teams, Icons.groups_rounded),
          const SizedBox(width: TFMobileSpacing.xs),
          _buildModeChip(MobileAgendaViewMode.fleet, Icons.directions_car_rounded),
        ],
      ),
    );
  }

  Widget _buildModeChip(MobileAgendaViewMode mode, IconData icon) {
    final isSelected = _viewMode == mode;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Semantics(
        selected: isSelected,
        button: true,
        label: 'Ver por ${mode.fullLabel}',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _onSwitchMode(mode),
            borderRadius: BorderRadius.circular(8.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: TFMobileTouchTargets.min,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 4.0,
                  vertical: TFMobileSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFEBF5FF))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(
                    color: isSelected
                        ? TFMobileColors.primaryBlue
                        : Colors.transparent,
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 15.0,
                      color: isSelected
                          ? TFMobileColors.primaryBlue
                          : TFMobileColors.textSecondary(context),
                    ),
                    const SizedBox(width: 4.0),
                    Flexible(
                      child: Text(
                        mode.shortLabel,
                        style: TFMobileTypography.caption.copyWith(
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? TFMobileColors.primaryBlue
                              : TFMobileColors.textSecondary(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    if (_dayTasks.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 60.0),
          TFEmptyState(
            title: 'Sem atividades programadas',
            description:
                'Nenhuma tarefa encontrada para este dia. Selecione outra data no carrossel acima.',
            icon: Icons.event_available_rounded,
          ),
        ],
      );
    }

    switch (_viewMode) {
      case MobileAgendaViewMode.timeline:
        return _buildTimelineView(context);
      case MobileAgendaViewMode.teams:
        return _buildTeamsView(context);
      case MobileAgendaViewMode.fleet:
        return _buildFleetView(context);
    }
  }

  Widget _buildTimelineView(BuildContext context) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(TFMobileSpacing.md),
      itemCount: _timelineSlots.length,
      itemBuilder: (context, index) {
        final slot = _timelineSlots[index];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho do Bloco de Horário
            Padding(
              padding: const EdgeInsets.only(bottom: TFMobileSpacing.xs, top: 4.0),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6.0,
                runSpacing: 2.0,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8.0,
                        height: 8.0,
                        decoration: const BoxDecoration(
                          color: TFMobileColors.primaryBlue,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: TFMobileSpacing.xs),
                      Text(
                        slot.title,
                        style: TFMobileTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w800,
                          color: TFMobileColors.textPrimary(context),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '(${slot.timeRange})',
                    style: TFMobileTypography.caption.copyWith(
                      color: TFMobileColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),

            // Tarefas do bloco
            ...slot.tasks.map((task) => MobileAgendaSlotCard(
                  task: task,
                  onTapTask: _openTaskDetail,
                )),

            const SizedBox(height: TFMobileSpacing.sm),
          ],
        );
      },
    );
  }

  Widget _buildTeamsView(BuildContext context) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(TFMobileSpacing.md),
      itemCount: _teamGroups.length,
      itemBuilder: (context, index) {
        final group = _teamGroups[index];
        return MobileTeamDayCard(
          group: group,
          onTapTask: _openTaskDetail,
        );
      },
    );
  }

  Widget _buildFleetView(BuildContext context) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(TFMobileSpacing.md),
      itemCount: _fleetGroups.length,
      itemBuilder: (context, index) {
        final group = _fleetGroups[index];
        return MobileFleetDayCard(
          group: group,
          onTapTask: _openTaskDetail,
        );
      },
    );
  }
}
