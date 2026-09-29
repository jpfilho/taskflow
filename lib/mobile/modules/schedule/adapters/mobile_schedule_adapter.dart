import 'package:intl/intl.dart';
import '../../../../models/task.dart';
import '../../../../models/equipe.dart';
import '../../../../models/frota.dart';
import '../../../../services/task_service.dart';
import '../../../../services/equipe_service.dart';
import '../../../../services/frota_service.dart';
import '../../../../services/connectivity_service.dart';
import '../models/mobile_agenda_day_summary.dart';

/// Camada de adaptação para a programação diária e agenda mobile.
/// Mapeia tarefas, equipes e frotas reais para as estruturas da UI mobile,
/// com suporte offline-first nativo e zero dependência de dados mockados.
class MobileScheduleAdapter {
  final TaskService _taskService;
  final EquipeService _equipeService;
  final FrotaService _frotaService;
  final ConnectivityService _connectivity;

  MobileScheduleAdapter({
    TaskService? taskService,
    EquipeService? equipeService,
    FrotaService? frotaService,
    ConnectivityService? connectivity,
  })  : _taskService = taskService ?? TaskService(),
        _equipeService = equipeService ?? EquipeService(),
        _frotaService = frotaService ?? FrotaService(),
        _connectivity = connectivity ?? ConnectivityService();

  /// Carrega todas as tarefas do intervalo especificado com fallback offline.
  Future<List<Task>> loadTasksForRange(DateTime start, DateTime end) async {
    try {
      if (_connectivity.isConnected) {
        final tasks = await _taskService.getTasksForRange(startDate: start, endDate: end);
        if (tasks.isNotEmpty) return tasks;
      }
    } catch (_) {
      // Falha online -> fallback para getAllTasks
    }

    try {
      return await _taskService.getAllTasks();
    } catch (_) {
      return [];
    }
  }

  /// Gera os resumos diários para o carrossel horizontal de datas.
  List<MobileAgendaDaySummary> buildDaysSummaries({
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required List<Task> tasks,
    required DateTime selectedDate,
  }) {
    final now = DateTime.now();
    final todayNormalized = DateTime(now.year, now.month, now.day);

    final summaries = <MobileAgendaDaySummary>[];
    var current = DateTime(rangeStart.year, rangeStart.month, rangeStart.day);
    final endNormalized = DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day);

    while (!current.isAfter(endNormalized)) {
      final dayTasks = tasks.where((t) => taskOccursOnDay(t, current)).toList();

      int running = 0;
      int completed = 0;
      int planned = 0;
      bool hasConflict = false;

      for (final t in dayTasks) {
        final st = t.status.toUpperCase().trim();
        if (st == 'ANDA') {
          running++;
        } else if (st == 'CONC') {
          completed++;
        } else {
          planned++;
        }
        if (t.hasConflict) {
          hasConflict = true;
        }
      }

      final isToday = current.year == todayNormalized.year &&
          current.month == todayNormalized.month &&
          current.day == todayNormalized.day;

      summaries.add(MobileAgendaDaySummary(
        date: current,
        totalTasks: dayTasks.length,
        runningTasks: running,
        completedTasks: completed,
        plannedTasks: planned,
        hasConflict: hasConflict,
        isToday: isToday,
      ));

      current = current.add(const Duration(days: 1));
    }

    return summaries;
  }

  /// Verifica se a tarefa tem execução ou programação no dia indicado.
  static bool taskOccursOnDay(Task task, DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day, 0, 0, 0);
    final dayEnd = DateTime(day.year, day.month, day.day, 23, 59, 59);

    if (task.dataFim.isBefore(dayStart) || task.dataInicio.isAfter(dayEnd)) {
      return false;
    }
    return true;
  }

  /// Converte uma Task em MobileAgendaTaskItem.
  MobileAgendaTaskItem mapTaskToItem(Task task, {DateTime? day}) {
    String? hInicio;
    String? hFim;

    if (task.dataInicio.hour != 0 || task.dataInicio.minute != 0) {
      hInicio = DateFormat('HH:mm').format(task.dataInicio);
    }
    if (task.dataFim.hour != 0 || task.dataFim.minute != 0) {
      hFim = DateFormat('HH:mm').format(task.dataFim);
    }

    final localDesc = task.locais.isNotEmpty
        ? task.locais.join(', ')
        : (task.regional.isNotEmpty ? task.regional : null);

    final equipeDesc = task.equipes.isNotEmpty ? task.equipes.first : null;
    final frotaDesc = task.frota.trim().isNotEmpty ? task.frota.trim() : null;

    final statusUpper = task.status.toUpperCase().trim();
    String statusLabel;
    switch (statusUpper) {
      case 'ANDA':
        statusLabel = 'Em Andamento';
        break;
      case 'PROG':
        statusLabel = 'Programada';
        break;
      case 'RPAR':
        statusLabel = 'Reprog. Parcial';
        break;
      case 'RPGR':
        statusLabel = 'Reprogramada';
        break;
      case 'CONC':
        statusLabel = 'Concluída';
        break;
      case 'CANC':
        statusLabel = 'Cancelada';
        break;
      default:
        statusLabel = task.statusNome.isNotEmpty ? task.statusNome : task.status;
    }

    return MobileAgendaTaskItem(
      taskId: task.id,
      codigo: task.tipo.isNotEmpty ? task.tipo : 'TASK',
      titulo: task.tarefa.isNotEmpty ? task.tarefa : 'Sem título',
      statusRaw: task.status,
      statusLabel: statusLabel,
      horarioInicio: hInicio,
      horarioFim: hFim,
      local: localDesc,
      equipeNome: equipeDesc,
      veiculoNome: frotaDesc,
      hasConflict: task.hasConflict,
      conflictReason: task.hasConflict ? 'Conflito de recursos identificado' : null,
      isSyncPending: false,
      priority: task.prioridade,
    );
  }

  /// Constrói a visualização cronológica por faixas de horários para o dia.
  List<MobileAgendaSlot> buildTimelineSlots(List<Task> dayTasks, DateTime day) {
    if (dayTasks.isEmpty) return [];

    final manha = <MobileAgendaTaskItem>[];
    final tarde = <MobileAgendaTaskItem>[];
    final noite = <MobileAgendaTaskItem>[];
    final diaInteiro = <MobileAgendaTaskItem>[];

    for (final task in dayTasks) {
      final item = mapTaskToItem(task, day: day);
      final hour = task.dataInicio.hour;

      if (task.dataInicio.hour == 0 &&
          task.dataInicio.minute == 0 &&
          task.dataFim.hour == 23) {
        diaInteiro.add(item);
      } else if (hour >= 6 && hour < 12) {
        manha.add(item);
      } else if (hour >= 12 && hour < 18) {
        tarde.add(item);
      } else if (hour >= 18 || hour < 6) {
        noite.add(item);
      } else {
        diaInteiro.add(item);
      }
    }

    final slots = <MobileAgendaSlot>[];

    if (manha.isNotEmpty) {
      slots.add(MobileAgendaSlot(
        title: 'Manhã',
        timeRange: '06:00 – 12:00',
        tasks: manha,
      ));
    }
    if (tarde.isNotEmpty) {
      slots.add(MobileAgendaSlot(
        title: 'Tarde',
        timeRange: '12:00 – 18:00',
        tasks: tarde,
      ));
    }
    if (noite.isNotEmpty) {
      slots.add(MobileAgendaSlot(
        title: 'Noite / Plantão',
        timeRange: '18:00 – 06:00',
        tasks: noite,
      ));
    }
    if (diaInteiro.isNotEmpty) {
      slots.add(MobileAgendaSlot(
        title: 'Dia Todo / Contínuo',
        timeRange: 'Jornada Integral',
        tasks: diaInteiro,
      ));
    }

    return slots;
  }

  /// Agrupa tarefas por equipe de forma síncrona e instantânea.
  List<MobileTeamAgendaGroup> buildTeamsGroupsSync(
    List<Task> dayTasks,
    DateTime day, {
    List<Equipe> equipesCadastradas = const [],
  }) {
    final Map<String, List<MobileAgendaTaskItem>> tasksByTeam = {};

    for (final task in dayTasks) {
      final item = mapTaskToItem(task, day: day);
      final teamKey =
          task.equipes.isNotEmpty ? task.equipes.first : 'Sem Equipe Atribuída';

      tasksByTeam.putIfAbsent(teamKey, () => []).add(item);
    }

    final groups = <MobileTeamAgendaGroup>[];
    final Map<String, Equipe> equipeMap = {
      for (final e in equipesCadastradas) e.nome.trim().toLowerCase(): e
    };

    tasksByTeam.forEach((teamName, items) {
      final eq = equipeMap[teamName.trim().toLowerCase()];
      String? encarregado;
      final membros = <String>[];

      if (eq != null && eq.executores.isNotEmpty) {
        for (final ex in eq.executores) {
          final papel = ex.papel.toUpperCase().trim();
          final nome = ex.executorNome;
          if (nome.isNotEmpty) {
            if (papel == 'ENCARREGADO' || papel == 'LIDER') {
              encarregado = nome;
            } else {
              membros.add(nome);
            }
          }
        }
      }

      final hasConflict = items.any((it) => it.hasConflict);

      groups.add(MobileTeamAgendaGroup(
        equipeId: eq?.id ?? teamName,
        equipeNome: teamName,
        encarregadoNome: encarregado,
        membrosNomes: membros,
        tasks: items,
        hasConflict: hasConflict,
      ));
    });

    return groups;
  }

  /// Constrói o agrupamento de tarefas por equipe com enriquecimento opcional.
  Future<List<MobileTeamAgendaGroup>> buildTeamsGroups(
      List<Task> dayTasks, DateTime day) async {
    List<Equipe> equipesCadastradas = [];
    try {
      equipesCadastradas = await _equipeService.getAllEquipes();
    } catch (_) {}

    return buildTeamsGroupsSync(dayTasks, day, equipesCadastradas: equipesCadastradas);
  }

  /// Agrupa tarefas por veículo da frota de forma síncrona e instantânea.
  List<MobileFleetAgendaGroup> buildFleetGroupsSync(
    List<Task> dayTasks,
    DateTime day, {
    List<Frota> frotasCadastradas = const [],
  }) {
    final Map<String, List<MobileAgendaTaskItem>> tasksByFleet = {};

    for (final task in dayTasks) {
      final item = mapTaskToItem(task, day: day);
      final fleetKey = task.frota.trim().isNotEmpty
          ? task.frota.trim()
          : 'Sem Veículo Vinculado';

      tasksByFleet.putIfAbsent(fleetKey, () => []).add(item);
    }

    final groups = <MobileFleetAgendaGroup>[];
    final Map<String, Frota> frotaMap = {
      for (final f in frotasCadastradas) f.nome.trim().toLowerCase(): f,
      for (final f in frotasCadastradas) f.placa.trim().toLowerCase(): f,
    };

    tasksByFleet.forEach((fleetName, items) {
      final fr = frotaMap[fleetName.trim().toLowerCase()];
      final hasConflict = items.any((it) => it.hasConflict);

      groups.add(MobileFleetAgendaGroup(
        frotaId: fr?.id ?? fleetName,
        veiculoNome: fr?.nome ?? fleetName,
        placa: fr?.placa ?? (fleetName.contains('-') ? fleetName : 'Não informada'),
        tipoVeiculo: fr?.tipoVeiculo ?? 'Operacional',
        equipeNome: items.firstWhere((it) => it.equipeNome != null, orElse: () => items.first).equipeNome,
        tasks: items,
        hasConflict: hasConflict,
        emManutencao: fr?.emManutencao ?? false,
      ));
    });

    return groups;
  }

  /// Constrói o agrupamento de tarefas por veículo da frota com enriquecimento opcional.
  Future<List<MobileFleetAgendaGroup>> buildFleetGroups(
      List<Task> dayTasks, DateTime day) async {
    List<Frota> frotasCadastradas = [];
    try {
      frotasCadastradas = await _frotaService.getAllFrotas();
    } catch (_) {}

    return buildFleetGroupsSync(dayTasks, day, frotasCadastradas: frotasCadastradas);
  }
}
