import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import '../models/task.dart';
import '../models/status.dart';
import '../models/feriado.dart';
import '../models/tipo_atividade.dart';
import '../services/task_service.dart';
import '../services/status_service.dart';
import '../services/feriado_service.dart';
import '../services/tipo_atividade_service.dart';
import '../utils/responsive.dart';
import '../utils/conflict_detection.dart';
import '../services/conflict_service.dart';
import '../services/sync_service.dart';

/// Escala de visualização do eixo temporal do Gantt.
enum GanttScale {
  daily,
  weekly,
  biweekly,
  monthly,
  quarterly,
  semiAnnual,
}

/// Período exibido como uma coluna no Gantt (um dia, uma semana, um mês, etc.).
class GanttPeriod {
  final DateTime start;
  final DateTime end;
  final String label;
  final String? groupLabel;

  const GanttPeriod({
    required this.start,
    required this.end,
    required this.label,
    this.groupLabel,
  });
}

class GanttChart extends StatefulWidget {
  final List<Task> tasks;
  final DateTime startDate;
  final DateTime endDate;
  final GanttScale scale;
  final ValueChanged<GanttScale>? onScaleChanged;
  final ScrollController scrollController;
  final ScrollController? horizontalController;
  final TaskService? taskService;
  final Function()? onTasksUpdated;
  final Function(Task)? onTaskUpdated; // Callback para atualizar apenas uma tarefa específica
  final Function(Task)? onEdit;
  final Function(Task)? onDelete;
  final Function(Task)? onDuplicate;
  final Function(Task)? onCreateSubtask;
  final bool? allSubtasksExpanded; // Estado compartilhado
  final VoidCallback? onToggleAllSubtasks; // Callback compartilhado
  final Set<String>? expandedTasks; // Estado compartilhado de tarefas expandidas
  final Function(String, bool)? onTaskExpanded; // Callback quando uma tarefa é expandida/colapsada
  final String? sortColumn; // Coluna de ordenação atual
  final Function(Task)? getSortValue; // Função para obter valor de ordenação
  /// Lista de tarefas usada só para detectar conflitos (ex.: lista sem filtro de executor).
  /// Se null, usa [tasks]. Quando há filtro, passar aqui a lista completa para manter os conflitos visíveis.
  final List<Task>? tasksForConflictDetection;
  /// Serviço de conflitos no backend (Supabase). Se fornecido e disponível, a detecção de conflitos usa as views em vez do cálculo em memória.
  final ConflictService? conflictService;
  /// Chamado quando o carregamento de conflitos do backend termina (para feedback visual de loading na tela de Atividades).
  final VoidCallback? onConflictsLoaded;

  const GanttChart({
    super.key,
    required this.tasks,
    required this.startDate,
    required this.endDate,
    this.scale = GanttScale.daily,
    this.onScaleChanged,
    required this.scrollController,
    this.horizontalController,
    this.taskService,
    this.onTasksUpdated,
    this.onTaskUpdated,
    this.onEdit,
    this.onDelete,
    this.onDuplicate,
    this.onCreateSubtask,
    this.allSubtasksExpanded,
    this.onToggleAllSubtasks,
    this.expandedTasks,
    this.onTaskExpanded,
    this.sortColumn,
    this.getSortValue,
    this.tasksForConflictDetection,
    this.conflictService,
    this.onConflictsLoaded,
  });

  @override
  State<GanttChart> createState() => _GanttChartState();
}

class _GanttChartState extends State<GanttChart> {
  late ScrollController _horizontalScrollController;
  late ScrollController _monthHeaderScrollController;
  bool _ownsHorizontalController = true;
  final List<ScrollController> _rowScrollControllers = [];
  bool _isScrolling = false;
  DateTime _displayStartDate = DateTime.now();
  DateTime _displayEndDate = DateTime.now();
  bool _hasInitializedScroll = false;

  // Variáveis para drag do mouse
  bool _isDragging = false;
  double _lastDragPosition = 0.0;
  bool _isDraggingFromEmptyArea = false; // Flag para indicar se o drag começou em área vazia
  bool _isSegmentBeingDragged = false; // Flag para indicar se algum segmento está sendo arrastado

  // Variáveis para controle de subtarefas
  Set<String> get _expandedTasks {
    if (widget.expandedTasks != null) {
      return widget.expandedTasks!;
    }
    return _localExpandedTasks;
  }
  final Set<String> _localExpandedTasks = {}; // IDs das tarefas expandidas (fallback local)
  final Map<String, List<Task>> _loadedSubtasks = {}; // Cache de subtarefas carregadas
  /// Conflitos do Supabase: v_conflict_por_dia_executor (has_conflict, descriptions por executor/dia).
  Map<String, ConflictInfo>? _conflictMapFromBackend;
  /// Eventos de execução do Supabase: v_conflict_execution_events (para descrições do tooltip).
  Map<String, List<ExecutionEventFromBackend>>? _eventsByDayFromBackend;
  /// Conflitos de frota: v_conflict_por_dia_frota (has_conflict por frota_id/dia). Exibição em preto.
  Map<String, ConflictInfo>? _conflictMapFrotaFromBackend;
  /// Eventos de execução por frota (v_conflict_execution_events_frota) para tooltip.
  Map<String, List<FleetExecutionEventFromBackend>>? _fleetEventsByDayFromBackend;
  bool _useBackendConflicts = false;
  bool _useFleetConflictBackend = false;

  // Variáveis para status e cores
  final StatusService _statusService = StatusService();
  Map<String, Status> _statusMap = {}; // Mapa de código de status -> Status

  // Variáveis para tipos de atividade e cores
  final TipoAtividadeService _tipoAtividadeService = TipoAtividadeService();
  Map<String, TipoAtividade> _tipoAtividadeMap = {}; // Mapa de código de tipo -> TipoAtividade

  // Variáveis para feriados
  final FeriadoService _feriadoService = FeriadoService();
  Map<DateTime, List<Feriado>> _feriadosMap = {}; // Mapa de data -> Lista de feriados

  bool _isScrollingProgrammatically = false; // Flag para evitar atualizações durante scroll programático

  /// Só pintar vermelho de conflito após o primeiro frame (evita vermelho fantasma no hot restart/carregamento).
  bool _conflictPaintReady = false;
  StreamSubscription<bool>? _syncStreamSub;
  bool _wasSyncing = false;

  // ---------- Conflitos (lógica única em ConflictDetection: eventos diários por executor) ----------
  /// Lista usada para detecção de conflitos (pode ser a lista completa sem filtros).
  List<Task> get _taskList => widget.tasksForConflictDetection ?? widget.tasks;
  /// Lista COMPLETA para resolução de pai/filhos em ConflictDetection (allTasks).
  /// União por id de _taskList e widget.tasks para incluir subtarefas expandidas na árvore.
  List<Task> get _allTasksForConflict {
    final byId = <String, Task>{};
    for (final t in _taskList) {
      byId[t.id] = t;
    }
    for (final t in widget.tasks) {
      byId.putIfAbsent(t.id, () => t);
    }
    return byId.values.toList();
  }

  Set<String> get _allExecutorIds {
    final ids = <String>{};
    for (final task in widget.tasks) {
      ids.addAll(task.executorIds);
      for (final ep in task.executorPeriods) {
        if (ep.executorId.isNotEmpty) ids.add(ep.executorId);
      }
      if (task.executor.isNotEmpty) ids.add(task.executor);
    }
    return ids;
  }

  /// Regra de conflito que deixa vermelho: quando conflictService está presente, vem EXCLUSIVAMENTE da view.
  /// Só considera conflito quando [executorId] é um UUID (executor_id da view). Nome nunca é usado
  /// para não atribuir conflito de uma pessoa a outra com o mesmo nome.
  bool _hasConflictOnDayForExecutor(DateTime day, String executorId) {
    if (widget.conflictService != null) {
      if (_conflictMapFromBackend == null) return false;
      if (!_uuidRegex.hasMatch(executorId.trim())) return false;
      final dayKey = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final info = _conflictMapFromBackend!['${executorId}_$dayKey'];
      return info?.hasConflict ?? false;
    }
    return ConflictDetection.hasConflictOnDayForExecutor(
      _taskList,
      day,
      executorId,
      _allTasksForConflict,
    );
  }

  /// Descrições para tooltip: quando conflictService está presente, vêm da view ou do mapa de conflitos (fallback).
  /// Só considera eventos do [executorId] quando for UUID; nome nunca é usado para não misturar pessoas.
  List<String> _getConflictTaskDescriptionsForDay(DateTime day, String executorId, {String? excludeTaskId}) {
    if (widget.conflictService != null) {
      if (!_uuidRegex.hasMatch(executorId.trim())) return [];
      final dayKey = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      if (_eventsByDayFromBackend != null) {
        final events = _eventsByDayFromBackend![dayKey];
        if (events != null && events.isNotEmpty) {
          final list = events
              .where((e) => e.executorId == executorId)
              .where((e) => excludeTaskId == null || e.taskId != excludeTaskId)
              .map((e) => e.description)
              .where((s) => s.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
          if (list.isNotEmpty) return list;
        }
      }
      // Fallback: usar descriptions do mapa de conflitos (v_conflict_por_dia_executor)
      final info = _conflictMapFromBackend?['${executorId}_$dayKey'];
      if (info != null && info.descriptions.isNotEmpty) return info.descriptions;
      return [];
    }
    return ConflictDetection.getConflictDescriptionsForDay(
      _taskList,
      day,
      executorId,
      excludeTaskId: excludeTaskId,
      allTasks: _allTasksForConflict,
    );
  }

  /// Monta mensagem do tooltip com executor(es) e motivo: outros locais e tarefas que causam o conflito.
  /// Quando [conflictService] está presente, dados vêm EXCLUSIVAMENTE do Supabase.
  /// Agrupa por DIA para que cada dia tenha seu próprio bloco no tooltip (evita agrupar tudo).
  String? _getConflictDetailsMessage(Task task, DateTime start, DateTime end) {
    final executorIds = widget.conflictService != null
        ? _getExecutorIdsForConflictLookup(task)
        : _getExecutorIdsForTask(task);
    if (executorIds.isEmpty) return null;
    final conflictDays = _getConflictDaysForSegment(task, start, end);
    if (conflictDays.isEmpty) return null;

    final idToName = _executorIdToNameMap();
    // Por dia -> por nome do executor -> descrições (evita duplicata quando mesmo executor tem ID e nome)
    final dayToNameToDescriptions = <DateTime, Map<String, Set<String>>>{};
    for (final day in conflictDays) {
      final nameToDescriptions = <String, Set<String>>{};
      for (final execId in executorIds) {
        if (!_hasConflictOnDayForExecutor(day, execId)) continue;
        final list = _getConflictTaskDescriptionsForDay(day, execId, excludeTaskId: task.id);
        final descs = list.where((s) => s.isNotEmpty).toSet();
        if (descs.isEmpty) continue;
        final nome = _executorIdToDisplayName(execId, idToName);
        if (nome.isEmpty) continue;
        nameToDescriptions.putIfAbsent(nome, () => {}).addAll(descs);
      }
      if (nameToDescriptions.isNotEmpty) {
        dayToNameToDescriptions[day] = nameToDescriptions;
      }
    }
    if (dayToNameToDescriptions.isEmpty) return null;

    final lines = <String>['Conflito de agenda nos dias em vermelho.', ''];
    final sortedDays = dayToNameToDescriptions.keys.toList()..sort();
    for (final day in sortedDays) {
      final dayStr = '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}/${day.year}';
      lines.add('$dayStr:');
      final names = dayToNameToDescriptions[day]!.keys.toList()..sort();
      for (final nome in names) {
        final descs = dayToNameToDescriptions[day]![nome]!.toList()..sort();
        lines.add('  • $nome: ${descs.join(' ; ')}');
      }
      lines.add('');
    }
    if (lines.last.isEmpty) lines.removeLast();
    return lines.join('\n');
  }

  /// Tooltip de conflito apenas para um dia (para mostrar só o dia sob o cursor).
  /// Agrupa por nome do executor para evitar linhas duplicadas (mesmo executor com ID e nome).
  String? _getConflictDetailsMessageForSingleDay(Task task, DateTime day) {
    final executorIds = widget.conflictService != null
        ? _getExecutorIdsForConflictLookup(task)
        : _getExecutorIdsForTask(task);
    if (executorIds.isEmpty) return null;
    if (!executorIds.any((e) => _hasConflictOnDayForExecutor(day, e))) return null;
    final idToName = _executorIdToNameMap();
    // Agrupar por nome de exibição para não duplicar linha quando o mesmo executor tem ID e nome
    final nameToDescriptions = <String, Set<String>>{};
    for (final execId in executorIds) {
      if (!_hasConflictOnDayForExecutor(day, execId)) continue;
      final list = _getConflictTaskDescriptionsForDay(day, execId, excludeTaskId: task.id);
      final descs = list.where((s) => s.isNotEmpty).toSet();
      if (descs.isEmpty) continue;
      final nome = _executorIdToDisplayName(execId, idToName);
      if (nome.isEmpty) continue;
      nameToDescriptions.putIfAbsent(nome, () => {}).addAll(descs);
    }
    if (nameToDescriptions.isEmpty) return null;
    final dayStr = '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}/${day.year}';
    final lines = <String>['Conflito em $dayStr:', ''];
    final names = nameToDescriptions.keys.toList()..sort();
    for (final nome in names) {
      final descs = nameToDescriptions[nome]!.toList()..sort();
      lines.add('• $nome: ${descs.join(' ; ')}');
    }
    return lines.join('\n');
  }

  /// Nome exibível para um executor (id ou nome); usa mapa id->nome quando for UUID.
  String _executorIdToDisplayName(String execId, Map<String, String> idToName) {
    final t = execId.trim();
    if (t.isEmpty) return '';
    if (_uuidRegex.hasMatch(t)) return idToName[t] ?? '';
    return idToName[t] ?? t;
  }

  // Corrige datas de segmentos legados que podem ter sido salvos com dataFim +1 dia
  DateTime _normalizeLegacyEndDate(Task task, DateTime start, DateTime end) {
    // Data a partir da qual os novos salvamentos já estão corrigidos
    // Considerar como legado tudo que foi salvo antes de 15/02/2026
    final legacyCutoff = DateTime(2026, 2, 15);
    final updatedAt = task.dataAtualizacao;
    final isLegacy = updatedAt == null || updatedAt.isBefore(legacyCutoff);

    if (!isLegacy) return end;

    // Só ajustar se houver duração positiva; evita encurtar períodos de 1 dia
    if (end.isAfter(start)) {
      final corrected = end.subtract(const Duration(days: 1));
      return corrected.isBefore(start) ? start : corrected;
    }
    return end;
  }

  bool _hasAnyExecutorConflictOnDay(DateTime day) {
    for (final executorId in _allExecutorIds) {
      if (_hasConflictOnDayForExecutor(day, executorId)) return true;
    }
    return false;
  }

  // Faixa de datas onde a tarefa tem EXECUÇÃO (só EXECUÇÃO gera conflito; PLANEJAMENTO/DESLOCAMENTO ignorados)
  DateTimeRange? _getExecutionDateRange(Task task) {
    DateTime? minStart;
    DateTime? maxEnd;

    void consider(DateTime s, DateTime e) {
      minStart = (minStart == null || s.isBefore(minStart!)) ? s : minStart;
      maxEnd = (maxEnd == null || e.isAfter(maxEnd!)) ? e : maxEnd;
    }

    for (final ep in task.executorPeriods) {
      for (final p in ep.periods) {
        if (p.tipoPeriodo.toUpperCase() != 'EXECUCAO') continue;
        final s = DateTime(p.dataInicio.year, p.dataInicio.month, p.dataInicio.day);
        final e = DateTime(p.dataFim.year, p.dataFim.month, p.dataFim.day);
        consider(s, e);
      }
    }

    for (final seg in task.ganttSegments) {
      if (seg.tipoPeriodo.toUpperCase() != 'EXECUCAO') continue;
      final s = DateTime(seg.dataInicio.year, seg.dataInicio.month, seg.dataInicio.day);
      final e = DateTime(seg.dataFim.year, seg.dataFim.month, seg.dataFim.day);
      consider(s, e);
    }

    if (minStart != null && maxEnd != null) {
      return DateTimeRange(start: minStart!, end: maxEnd!);
    }
    return null;
  }

  List<DateTime> _getConflictDaysForTask(Task task, DateTime start, DateTime end) {
    final execRange = _getExecutionDateRange(task);
    if (execRange == null) return const [];

    final executorIds = _getExecutorIdsForTask(task);
    if (executorIds.isEmpty) return const [];

    final conflictDays = <DateTime>[];
    final rangeStart = execRange.start.isBefore(start) ? start : execRange.start;
    final rangeEnd = execRange.end.isAfter(end) ? end : execRange.end;

    var currentDay = DateTime(rangeStart.year, rangeStart.month, rangeStart.day);
    final endDay = DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day);

    while (!currentDay.isAfter(endDay)) {
      bool hasConflict = false;
      for (final execId in executorIds) {
        final dayStart = DateTime(currentDay.year, currentDay.month, currentDay.day);
        final dayEnd = dayStart.add(const Duration(days: 1));
        if (!ConflictDetection.taskHasExecutionOnDayForExecutor(
          task,
          execId,
          dayStart,
          dayEnd,
          _allTasksForConflict,
        )) {
          continue;
        }
        if (_hasConflictOnDayForExecutor(currentDay, execId)) {
          hasConflict = true;
          break;
        }
      }
      if (hasConflict) {
        conflictDays.add(currentDay);
      }
      currentDay = currentDay.add(const Duration(days: 1));
    }

    return conflictDays;
  }

  Set<String> _getExecutorIdsForTask(Task task) => ConflictDetection.getExecutorIdsForTask(task);

  /// Para conflito (view por executor_id): retorna APENAS executor_id (UUID).
  /// Nomes que não puderem ser resolvidos a um UUID são ignorados, para nunca atribuir
  /// conflito de uma pessoa a outra com o mesmo nome.
  Set<String> _getExecutorIdsForConflictLookup(Task task) {
    final nameToId = <String, String>{};
    for (final ep in task.executorPeriods) {
      if (ep.executorId.trim().isNotEmpty &&
          _uuidRegex.hasMatch(ep.executorId.trim()) &&
          ep.executorNome.trim().isNotEmpty) {
        final nome = ep.executorNome.trim();
        nameToId[nome] = ep.executorId.trim();
        nameToId[ConflictService.normalizeExecutorKey(nome)] = ep.executorId.trim();
      }
    }
    final resolved = <String>{};
    for (final id in ConflictDetection.getExecutorIdsForTask(task)) {
      final t = id.trim();
      if (t.isEmpty) continue;
      if (_uuidRegex.hasMatch(t)) {
        resolved.add(t);
      } else {
        final uuid = nameToId[t] ?? nameToId[ConflictService.normalizeExecutorKey(t)];
        if (uuid != null) resolved.add(uuid);
        // Não adicionar nome quando não há UUID: evita mostrar conflito de outra pessoa com mesmo nome
      }
    }
    return resolved;
  }

  static final _uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

  /// Monta mapa executorId -> nome para exibir só nomes no tooltip de conflito (nunca mostrar UUID).
  Map<String, String> _executorIdToNameMap() {
    final map = <String, String>{};
    for (final task in _taskList) {
      for (final ep in task.executorPeriods) {
        if (ep.executorId.trim().isNotEmpty && ep.executorNome.trim().isNotEmpty) {
          map[ep.executorId] = ep.executorNome.trim();
          map[ep.executorNome.trim()] = ep.executorNome.trim();
        }
      }
      // Mapear executorIds (UUIDs) para nomes pela ordem: executor "Nome1, Nome2" ou lista executores
      if (task.executorIds.isNotEmpty) {
        final nameList = task.executores.isNotEmpty
            ? task.executores.map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
            : task.executor.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        for (var i = 0; i < task.executorIds.length && i < nameList.length; i++) {
          final eid = task.executorIds[i].trim();
          final nome = nameList[i];
          if (eid.isNotEmpty && nome.isNotEmpty) {
            map[eid] = nome;
            map[nome] = nome;
          }
        }
      }
      for (final name in task.executores) {
        final t = name.trim();
        if (t.isNotEmpty) map[t] = t;
      }
      for (final s in task.executor.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty)) {
        map[s] = s;
      }
    }
    return map;
  }

  /// Converte conjunto de executorIds para string só com nomes (nunca exibe UUID no tooltip).
  String _executorIdsToDisplayNames(Set<String> executorIds) {
    if (executorIds.isEmpty) return '';
    final idToName = _executorIdToNameMap();
    final names = <String>{};
    for (final id in executorIds) {
      final trimmed = id.trim();
      if (trimmed.isEmpty) continue;
      if (_uuidRegex.hasMatch(trimmed)) {
        final name = idToName[trimmed];
        if (name != null && name.isNotEmpty) names.add(name);
        // UUID sem nome: não exibir (não ajuda o usuário)
      } else {
        final name = idToName[trimmed] ?? trimmed;
        if (name.isNotEmpty) names.add(name);
      }
    }
    return names.join(', ');
  }

  /// True se for a linha da tarefa pai que tem linhas de executor expandidas (conflito deve aparecer só nas linhas do executor).
  bool _isParentRowWithExecutorChildrenExpanded(Task task) {
    return task.parentId == null &&
        task.executorPeriods.isNotEmpty &&
        _expandedTasks.contains(task.id);
  }

  /// Dias em que o segmento fica vermelho: quando conflictService está presente, regra EXCLUSIVAMENTE do backend.
  List<DateTime> _getConflictDaysForSegment(Task task, DateTime start, DateTime end) {
    // Tarefa pai com executores expandidos: não pintar vermelho na barra da pai; só nas linhas do executor.
    if (_isParentRowWithExecutorChildrenExpanded(task)) return const [];

    final executorIds = widget.conflictService != null
        ? _getExecutorIdsForConflictLookup(task)
        : _getExecutorIdsForTask(task);
    if (executorIds.isEmpty) return const [];

    // Linha virtual de executor: backend tem task_id da tarefa pai, não do id virtual
    final taskIdForBackend = task.id.contains('_executor_') && task.parentId != null
        ? task.parentId!
        : task.id;

    if (widget.conflictService != null) {
      if (_conflictMapFromBackend == null) return const [];
      final hasEvents = _eventsByDayFromBackend != null && _eventsByDayFromBackend!.isNotEmpty;
      final conflictDays = <DateTime>[];
      var currentDay = DateTime(start.year, start.month, start.day);
      final endDay = DateTime(end.year, end.month, end.day);
      while (!currentDay.isAfter(endDay)) {
        final dayKey = '${currentDay.year}-${currentDay.month.toString().padLeft(2, '0')}-${currentDay.day.toString().padLeft(2, '0')}';
        bool hasConflict = false;
        for (final execId in executorIds) {
          if (hasEvents) {
            final events = _eventsByDayFromBackend![dayKey];
            final hasExecution = events?.any((e) => e.taskId == taskIdForBackend && e.executorId == execId) ?? false;
            if (!hasExecution) continue;
          }
          if (_hasConflictOnDayForExecutor(currentDay, execId)) {
            hasConflict = true;
            break;
          }
        }
        if (hasConflict) conflictDays.add(currentDay);
        currentDay = currentDay.add(const Duration(days: 1));
      }
      return conflictDays;
    }

    final conflictDays = <DateTime>[];
    var currentDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    while (!currentDay.isAfter(endDay)) {
      bool hasConflict = false;
      final dayStart = DateTime(currentDay.year, currentDay.month, currentDay.day);
      final dayEnd = dayStart.add(const Duration(days: 1));
      for (final execId in executorIds) {
        if (!ConflictDetection.taskHasExecutionOnDayForExecutor(
          task,
          execId,
          dayStart,
          dayEnd,
          _allTasksForConflict,
        )) continue;
        if (_hasConflictOnDayForExecutor(currentDay, execId)) {
          hasConflict = true;
          break;
        }
      }
      if (hasConflict) conflictDays.add(currentDay);
      currentDay = currentDay.add(const Duration(days: 1));
    }
    return conflictDays;
  }

  /// IDs de frota da tarefa (frotaIds + frotaPeriods; para linha virtual _frota_ extrai do id).
  Set<String> _getFleetIdsForTask(Task task) {
    final ids = <String>{};
    for (final id in task.frotaIds) {
      if (id.trim().isNotEmpty) ids.add(id.trim());
    }
    for (final fp in task.frotaPeriods) {
      if (fp.frotaId.trim().isNotEmpty) ids.add(fp.frotaId.trim());
    }
    if (task.id.contains('_frota_')) {
      final parts = task.id.split('_frota_');
      if (parts.length >= 2 && parts[1].trim().isNotEmpty) ids.add(parts[1].trim());
    }
    return ids;
  }

  bool _hasConflictOnDayForFrota(DateTime day, String frotaId) {
    if (!_useFleetConflictBackend || _conflictMapFrotaFromBackend == null) return false;
    final dayKey = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    final info = _conflictMapFrotaFromBackend!['${frotaId}_$dayKey'];
    return info?.hasConflict ?? false;
  }

  /// Dias de conflito de FROTA no segmento (para pintar preto com letras brancas).
  List<DateTime> _getConflictDaysForSegmentFrota(Task task, DateTime start, DateTime end) {
    final frotaIds = _getFleetIdsForTask(task);
    if (frotaIds.isEmpty) return const [];

    final conflictDays = <DateTime>[];
    var currentDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);

    while (!currentDay.isAfter(endDay)) {
      for (final frotaId in frotaIds) {
        if (_hasConflictOnDayForFrota(currentDay, frotaId)) {
          conflictDays.add(DateTime(currentDay.year, currentDay.month, currentDay.day));
          break;
        }
      }
      currentDay = currentDay.add(const Duration(days: 1));
    }
    return conflictDays;
  }

  /// Lista TODOS os eventos (locais/tarefas) da frota no dia, para tooltip igual ao de executores.
  List<String> _getFleetConflictDescriptionsForDay(DateTime day, String frotaId) {
    if (_fleetEventsByDayFromBackend == null) return [];
    final dayStr = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    final events = _fleetEventsByDayFromBackend![dayStr];
    if (events == null) return [];
    return events
        .where((e) => e.frotaId == frotaId)
        .map((e) => e.description)
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  String? _getFleetConflictDetailsMessageForSingleDay(Task task, DateTime day) {
    final frotaIds = _getFleetIdsForTask(task);
    if (frotaIds.isEmpty) return null;
    final lines = <String>['Conflito de frota (dias em preto).', ''];
    for (final frotaId in frotaIds) {
      if (!_hasConflictOnDayForFrota(day, frotaId)) continue;
      final allDescriptions = _getFleetConflictDescriptionsForDay(day, frotaId);
      if (allDescriptions.isNotEmpty) {
        lines.add('Frota em conflito neste dia (todos os locais/tarefas):');
        for (final d in allDescriptions) lines.add('• $d');
      }
    }
    if (lines.length <= 2) return 'Conflito de frota: mesma frota em mais de um local neste dia.';
    return lines.join('\n');
  }

  /// Monta mensagem do tooltip de conflito de frota: por dia, todos os locais/tarefas (igual ao de executores).
  String? _getFleetConflictDetailsMessage(Task task, DateTime start, DateTime end) {
    final frotaIds = _getFleetIdsForTask(task);
    if (frotaIds.isEmpty) return null;
    final conflictDays = _getConflictDaysForSegmentFrota(task, start, end);
    if (conflictDays.isEmpty) return null;

    final dayToDescriptions = <DateTime, List<String>>{};
    for (final day in conflictDays) {
      final set = <String>{};
      for (final frotaId in frotaIds) {
        if (!_hasConflictOnDayForFrota(day, frotaId)) continue;
        set.addAll(_getFleetConflictDescriptionsForDay(day, frotaId));
      }
      if (set.isNotEmpty) dayToDescriptions[day] = set.toList()..sort();
    }
    if (dayToDescriptions.isEmpty) return 'Conflito de frota nos dias em preto.';

    final lines = <String>['Conflito de frota nos dias em preto.', ''];
    final sortedDays = dayToDescriptions.keys.toList()..sort();
    for (final day in sortedDays) {
      final dayStr = '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}/${day.year}';
      lines.add('$dayStr:');
      final descs = dayToDescriptions[day]!.toSet().toList()..sort();
      for (final d in descs) lines.add('  • $d');
      lines.add('');
    }
    if (lines.last.isEmpty) lines.removeLast();
    return lines.join('\n');
  }

  Future<void> _loadBackendConflicts() async {
    final cs = widget.conflictService;
    if (cs == null) {
      if (_useBackendConflicts || _useFleetConflictBackend) {
        setState(() {
          _useBackendConflicts = false;
          _useFleetConflictBackend = false;
          _conflictMapFromBackend = null;
          _eventsByDayFromBackend = null;
          _conflictMapFrotaFromBackend = null;
          _fleetEventsByDayFromBackend = null;
        });
      }
      widget.onConflictsLoaded?.call();
      return;
    }
    final start = _displayStartDate;
    final end = _displayEndDate;
    final ok = await cs.isBackendAvailable();
    Map<String, ConflictInfo>? map;
    Map<String, List<ExecutionEventFromBackend>>? events;
    if (ok) {
      map = await cs.getConflictsForRange(start, end);
      events = await cs.getExecutionEventsForRange(start, end);
    }
    final fleetOk = await cs.isFleetConflictBackendAvailable();
    Map<String, ConflictInfo>? fleetMap;
    Map<String, List<FleetExecutionEventFromBackend>>? fleetEvents;
    if (fleetOk) {
      fleetMap = await cs.getFleetConflictsForRange(start, end);
      fleetEvents = await cs.getFleetExecutionEventsForRange(start, end);
    }
    if (!mounted) return;
    setState(() {
      _conflictMapFromBackend = map;
      _eventsByDayFromBackend = events;
      _useBackendConflicts = ok;
      _conflictMapFrotaFromBackend = fleetMap;
      _fleetEventsByDayFromBackend = fleetEvents;
      _useFleetConflictBackend = fleetOk;
    });
    widget.onConflictsLoaded?.call();
  }

  @override
  void initState() {
    super.initState();
    _horizontalScrollController = widget.horizontalController ?? ScrollController();
    _ownsHorizontalController = widget.horizontalController == null;
    _monthHeaderScrollController = ScrollController();

    // Inicializar com o range fornecido, mas expandir para permitir navegação
    _displayStartDate = widget.startDate.subtract(
      const Duration(days: 365),
    ); // 1 ano antes
    _displayEndDate = widget.endDate.add(
      const Duration(days: 365),
    ); // 1 ano depois

    if (widget.conflictService != null) {
      _loadBackendConflicts();
      // Recarregar conflitos quando a sincronização terminar (backend pode ter sido atualizado)
      _syncStreamSub = SyncService().syncingStream.listen((syncing) {
        if (_wasSyncing && !syncing && mounted) {
          _loadBackendConflicts();
        }
        _wasSyncing = syncing;
      });
    }

    // Sincronizar scroll do cabeçalho com as linhas
    _horizontalScrollController.addListener(_syncScroll);
    _horizontalScrollController.addListener(_onScrollChanged);
    
    // NOTA: Não adicionar _syncMonthHeader como listener direto aqui
    // Ele será chamado pelo NotificationListener para evitar conflitos
    // _horizontalScrollController.addListener(_syncMonthHeader);
    
    // NOTA: Não adicionar _syncHorizontalScroll como listener direto aqui
    // Ele será chamado pelo NotificationListener para evitar conflitos
    // _monthHeaderScrollController.addListener(_syncHorizontalScroll);

    // Carregar status para obter cores
    _loadStatus();
    // Carregar tipos de atividade para obter cores
    _loadTiposAtividade();
    // Carregar feriados
    _loadFeriados();
    // Carregar subtarefas automaticamente
    _loadAllSubtasks();

    // Só permitir pintar conflito (vermelho) após o primeiro frame para evitar vermelho fantasma no hot restart
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _conflictPaintReady = true);
    });
  }

  // Carregar todas as subtarefas automaticamente
  Future<void> _loadAllSubtasks({bool forceReload = false}) async {
    if (widget.taskService == null) return;
    
    try {
      // Identificar tarefas principais que podem ter subtarefas
      final mainTasks = widget.tasks.where((t) => t.parentId == null).toList();
      
      // Carregar subtarefas para cada tarefa principal
      for (var mainTask in mainTasks) {
        // Se forceReload for true ou se ainda não foi carregado, recarregar
        if (forceReload || !_loadedSubtasks.containsKey(mainTask.id)) {
          try {
            final subtasks = await widget.taskService!.getSubtasks(mainTask.id);
            if (!mounted) return;
            setState(() {
              _loadedSubtasks[mainTask.id] = subtasks;
              // Por padrão, subtarefas começam colapsadas
              // Só expandir se _allSubtasksExpanded for true
              if (widget.allSubtasksExpanded ?? false) {
                _expandedTasks.add(mainTask.id);
              }
            });
            // Forçar rebuild após um frame para garantir renderização
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {});
              }
            });
          } catch (e) {
            if (mounted) {
              debugPrint('Erro ao carregar subtarefas de ${mainTask.id}: $e');
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Erro ao carregar subtarefas: $e');
      }
    }
  }

  Future<void> _loadStatus() async {
    try {
      final statusList = await _statusService.getAllStatus();
      if (!mounted) return;
      setState(() {
        _statusMap = {
          for (var status in statusList) status.codigo: status
        };
      });
    } catch (e) {
      debugPrint('Erro ao carregar status no Gantt: $e');
    }
  }

  Future<void> _loadTiposAtividade() async {
    try {
      final tiposList = await _tipoAtividadeService.getTiposAtividadeAtivos();
      if (!mounted) return;
      setState(() {
        _tipoAtividadeMap = {
          for (var tipo in tiposList) tipo.codigo: tipo
        };
      });
    } catch (e) {
      debugPrint('Erro ao carregar tipos de atividade no Gantt: $e');
    }
  }

  Future<void> _loadFeriados() async {
    try {
      // Carregar feriados para o período expandido (para permitir scroll)
      final feriadosMap = await _feriadoService.getFeriadosMapByDateRange(
        _displayStartDate,
        _displayEndDate,
      );
      if (!mounted) return;
      setState(() {
        _feriadosMap = feriadosMap;
      });
    } catch (e) {
      debugPrint('Erro ao carregar feriados no Gantt: $e');
    }
  }

  // Verificar se uma data é feriado
  bool _isFeriado(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return _feriadosMap.containsKey(normalizedDate);
  }

  // Método auxiliar para calcular largura dos dias baseado na largura da tela
  double _calculateDayWidth(BuildContext? context) {
    if (context == null) return 28.0; // Fallback padrão (reduzido em 30%)
    
    final screenWidth = MediaQuery.of(context).size.width;
    final ganttWidth = screenWidth * 0.5; // Gantt ocupa 50% da tela
    final daysInMonth = 30.0;
    // Calcular dayWidth para que 30 dias caibam na largura disponível
    // Reduzido em 30%: multiplicar por 0.7
    return ((ganttWidth / daysInMonth) * 0.7).clamp(14.0, 42.0); // Mínimo 14px, máximo 42px (30% menor)
  }

  void _onScrollChanged() {
    if (!_horizontalScrollController.hasClients || _horizontalScrollController.positions.length != 1) return;
    
    // Não atualizar período se estiver fazendo scroll programático
    if (_isScrollingProgrammatically) return;

    final offset = _horizontalScrollController.offset;
    final dayWidth = _calculateDayWidth(context);
    final daysInView = _getDaysInRange(_displayStartDate, _displayEndDate);
    final totalWidth = daysInView.length * dayWidth;

    // Se estiver próximo do início, expandir para trás
    if (offset < 100 && _displayStartDate.year > 2020) {
      setState(() {
        _displayStartDate = _displayStartDate.subtract(
          const Duration(days: 180),
        );
      });
    }

    // Se estiver próximo do fim, expandir para frente
    if (offset > totalWidth - 100 && _displayEndDate.year < 2030) {
      setState(() {
        _displayEndDate = _displayEndDate.add(const Duration(days: 180));
      });
    }
  }

  void _syncScroll() {
    // Não verificar _isScrolling aqui para não interferir com sincronização do mês
    if (!_horizontalScrollController.hasClients || _horizontalScrollController.positions.length != 1) return;

    final offset = _horizontalScrollController.offset;
    // Sincronizar todas as linhas com o cabeçalho
    for (var controller in _rowScrollControllers) {
      if (controller.hasClients && (controller.offset - offset).abs() > 1.0) {
        controller.jumpTo(offset);
      }
    }
  }
  
  void _syncMonthHeader() {
    final horizontalHasClients = _horizontalScrollController.hasClients;
    final horizontalPositions = horizontalHasClients ? _horizontalScrollController.positions.length : 0;
    final monthHasClients = _monthHeaderScrollController.hasClients;
    
    if (!horizontalHasClients || horizontalPositions != 1) {
      return;
    }
    if (!monthHasClients) {
      return;
    }
    
    final horizontalOffset = _horizontalScrollController.offset;
    final monthOffset = _monthHeaderScrollController.offset;
    final difference = (monthOffset - horizontalOffset).abs();
    
    if (difference > 0.1) {
      try {
        _monthHeaderScrollController.jumpTo(horizontalOffset);
      } catch (e) {
        debugPrint('Erro ao sincronizar header do mês: $e');
      }
    }
  }
  
  void _syncHorizontalScroll() {
    // Verificar se os controllers estão prontos
    final monthHasClients = _monthHeaderScrollController.hasClients;
    final monthPositions = monthHasClients ? _monthHeaderScrollController.positions.length : 0;
    final horizontalHasClients = _horizontalScrollController.hasClients;
    final horizontalPositions = horizontalHasClients ? _horizontalScrollController.positions.length : 0;
    
    if (!monthHasClients || monthPositions != 1) {
      return;
    }
    if (!horizontalHasClients || horizontalPositions != 1) {
      return;
    }
    
    final monthOffset = _monthHeaderScrollController.offset;
    final horizontalOffset = _horizontalScrollController.offset;
    final difference = (horizontalOffset - monthOffset).abs();
    
    if (difference > 0.1) {
      try {
        _horizontalScrollController.jumpTo(monthOffset);
        // Também sincronizar as linhas de tarefas
        for (var controller in _rowScrollControllers) {
          if (controller.hasClients) {
            controller.jumpTo(monthOffset);
          }
        }
      } catch (e) {
        debugPrint('Erro ao sincronizar header horizontal: $e');
      }
    }
  }


  @override
  void didUpdateWidget(GanttChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.conflictService != oldWidget.conflictService ||
        widget.startDate != oldWidget.startDate ||
        widget.endDate != oldWidget.endDate) {
      _loadBackendConflicts();
    } else if (widget.conflictService != null) {
      // Recarregar conflitos quando a lista de tarefas (para detecção) mudar — ex.: após restart, quando _loadTasks preenche as tarefas
      final oldList = oldWidget.tasksForConflictDetection ?? oldWidget.tasks;
      final newList = widget.tasksForConflictDetection ?? widget.tasks;
      final oldLen = oldList.length;
      final newLen = newList.length;
      if (oldLen != newLen || (oldLen == 0 && newLen > 0)) {
        _loadBackendConflicts();
      }
    }
    // Verificar se as tarefas mudaram e se têm executorPeriods
    final oldTasksWithPeriods = oldWidget.tasks.where((t) => t.executorPeriods.isNotEmpty).length;
    final newTasksWithPeriods = widget.tasks.where((t) => t.executorPeriods.isNotEmpty).length;
    
    if (oldTasksWithPeriods != newTasksWithPeriods) {
      // debug silenciado
      // debug silenciado
      
      // Listar tarefas com períodos
      for (var task in widget.tasks.where((t) => t.executorPeriods.isNotEmpty)) {
        // debug silenciado
      }
      
      // Forçar rebuild para mostrar os botões de expansão
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            // debug silenciado
          });
        }
      });
    }
    
    // Sincronizar estado de expansão quando allSubtasksExpanded mudar
    if (oldWidget.allSubtasksExpanded != widget.allSubtasksExpanded) {
      // Obter todas as tarefas principais que têm subtarefas OU períodos por executor
      final mainTasks = widget.tasks.where((t) => t.parentId == null).toList();
      final tasksToToggle = <String>[];

      for (var task in mainTasks) {
        final hasSubtasks = _loadedSubtasks.containsKey(task.id) && _loadedSubtasks[task.id]!.isNotEmpty;
        final hasExecutorPeriods = task.executorPeriods.isNotEmpty;
        
        if (hasSubtasks || hasExecutorPeriods) {
          tasksToToggle.add(task.id);
        }
      }
      
      setState(() {
        if (widget.allSubtasksExpanded ?? false) {
          // Expandir todas
          _expandedTasks.addAll(tasksToToggle);
        } else {
          // Colapsar todas
          _expandedTasks.removeAll(tasksToToggle);
        }
      });
    }
    
    // Sincronizar estado de expansão quando expandedTasks mudar externamente
    // Comparar o conteúdo do Set, não apenas a referência
    final oldExpanded = oldWidget.expandedTasks ?? <String>{};
    final newExpanded = widget.expandedTasks ?? <String>{};
    
    if (oldExpanded.length != newExpanded.length || 
        !oldExpanded.every((id) => newExpanded.contains(id)) ||
        !newExpanded.every((id) => oldExpanded.contains(id))) {
      // Apenas atualizar o estado local se necessário (sem múltiplos setState)
      // O rebuild será automático através do ValueKey do ListView
      // Não chamar setState aqui - deixar o Flutter fazer o rebuild naturalmente
    }
    // Atualizar range se as datas mudaram
    if (oldWidget.startDate != widget.startDate ||
        oldWidget.endDate != widget.endDate ||
        oldWidget.scale != widget.scale) {
      if (oldWidget.scale != widget.scale) {
        _hasInitializedScroll = false;
      }
      _loadFeriados();
      
      // Resetar o scroll para o início do novo período
      _hasInitializedScroll = false;
      
      // Scrollar para o início do período selecionado (sem animação para ser mais rápido)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _horizontalScrollController.hasClients) {
          // Como agora mostramos apenas o período selecionado, o scroll deve começar em 0
          _horizontalScrollController.jumpTo(0);
          
          // Sincronizar todas as linhas
          for (var controller in _rowScrollControllers) {
            if (controller.hasClients) {
              controller.jumpTo(0);
            }
          }
          
          _hasInitializedScroll = true;
        }
      });
    }
    // Verificar se as tarefas mudaram
    if (oldWidget.tasks.length != widget.tasks.length) {
      // debug silenciado
      
      // Recarregar subtarefas quando as tarefas mudarem (pode ter sido criada uma nova subtarefa)
      // Usar forceReload=true para garantir que as subtarefas sejam recarregadas
      _loadAllSubtasks(forceReload: true);
      
      // Se todas as subtarefas devem estar colapsadas por padrão, garantir isso
      if (!(widget.allSubtasksExpanded ?? false)) {
        setState(() {
          // Remover todas as tarefas expandidas que têm subtarefas
          final mainTasksWithSubtasks = widget.tasks
              .where((t) => t.parentId == null && _loadedSubtasks.containsKey(t.id) && _loadedSubtasks[t.id]!.isNotEmpty)
              .map((t) => t.id)
              .toList();
          _expandedTasks.removeWhere((id) => mainTasksWithSubtasks.contains(id));
        });
      }
      
      // Se estava vazio e agora tem tarefas, e o scroll já foi inicializado
      // Forçar rebuild para renderizar os segmentos, sem mexer no scroll
      if (oldWidget.tasks.isEmpty && widget.tasks.isNotEmpty && _hasInitializedScroll) {
        // debug silenciado
        // debug silenciado
        // debug silenciado
        // debug silenciado
        // Forçar rebuild imediato
        setState(() {});
        // Aguardar múltiplos frames para garantir que os segmentos sejam renderizados
        // Usar callbacks aninhados para garantir renderização completa
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            // Primeiro callback: garantir que o ListView seja reconstruído
            setState(() {});
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                // Segundo callback: garantir que os segmentos sejam renderizados
                // debug silenciado
                setState(() {});
                // Terceiro callback: garantir renderização completa
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {});
                  }
                });
              }
            });
          }
        });
      }
      
      // Forçar rebuild se necessário
      setState(() {});
    }
    // Verificar se os segmentos mudaram
    final oldSegmentsCount = oldWidget.tasks.fold<int>(0, (sum, task) => sum + task.ganttSegments.length);
    final newSegmentsCount = widget.tasks.fold<int>(0, (sum, task) => sum + task.ganttSegments.length);
    if (oldSegmentsCount != newSegmentsCount) {
      // debug silenciado
      // Apenas forçar rebuild, sem múltiplos callbacks que causam problemas
      setState(() {});
    }
    
    // Verificar se as tarefas mudaram (mesmo número mas conteúdo diferente)
    if (oldWidget.tasks.length == widget.tasks.length && oldWidget.tasks.isNotEmpty) {
      // Verificar se os segmentos das tarefas mudaram mesmo com mesmo número de tarefas
      bool segmentsChanged = false;
      for (int i = 0; i < oldWidget.tasks.length && i < widget.tasks.length; i++) {
        if (oldWidget.tasks[i].ganttSegments.length != widget.tasks[i].ganttSegments.length) {
          segmentsChanged = true;
          break;
        }
      }
      if (segmentsChanged) {
        // debug silenciado
        setState(() {});
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {});
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _syncStreamSub?.cancel();
    _horizontalScrollController.removeListener(_syncScroll);
    _horizontalScrollController.removeListener(_onScrollChanged);
    // _syncMonthHeader não é mais um listener direto
    // _horizontalScrollController.removeListener(_syncMonthHeader);
    // _syncHorizontalScroll não é mais um listener direto
    // _monthHeaderScrollController.removeListener(_syncHorizontalScroll);
    if (_ownsHorizontalController) {
      _horizontalScrollController.dispose();
    }
    _monthHeaderScrollController.dispose();
    for (var controller in _rowScrollControllers) {
      controller.dispose();
    }
    super.dispose();
  }


  // Construir lista hierárquica de tarefas (principais + subtarefas expandidas)
  List<Task> _buildHierarchicalTasks() {
    // debug silenciado
    // debug silenciado
    
    final List<Task> hierarchicalTasks = [];
    final mainTasks = widget.tasks.where((t) => t.parentId == null).toList();
    
    for (final mainTask in mainTasks) {
      hierarchicalTasks.add(mainTask);
      final isExpanded = _expandedTasks.contains(mainTask.id);
      
      if (mainTask.executorPeriods.isNotEmpty) {
        // debug silenciado
      }
      
      // Se a tarefa está expandida e tem subtarefas carregadas, adicionar as subtarefas
      if (isExpanded && _loadedSubtasks.containsKey(mainTask.id)) {
        final subtasks = _loadedSubtasks[mainTask.id]!;
        for (var subtask in subtasks) {
          // debug silenciado
          // debug silenciado
          if (subtask.ganttSegments.isNotEmpty) {
            for (var seg in subtask.ganttSegments) {
              // debug silenciado
            }
          }
        }
        hierarchicalTasks.addAll(subtasks);
      }
      
      // Se a tarefa está expandida e tem períodos por executor, criar linhas virtuais para cada executor
      if (isExpanded && mainTask.executorPeriods.isNotEmpty) {
        // debug silenciado
        for (var executorPeriod in mainTask.executorPeriods) {
          // debug silenciado
          
          // Criar uma tarefa virtual representando o executor
          // Usar um ID único baseado no ID da tarefa + ID do executor
          final virtualTaskId = '${mainTask.id}_executor_${executorPeriod.executorId}';
          
          // Calcular data início e fim baseado nos períodos do executor
          DateTime? minDate;
          DateTime? maxDate;
          for (var period in executorPeriod.periods) {
            if (minDate == null || period.dataInicio.isBefore(minDate)) {
              minDate = period.dataInicio;
            }
            if (maxDate == null || period.dataFim.isAfter(maxDate)) {
              maxDate = period.dataFim;
            }
          }
          
          // Criar tarefa virtual com os períodos do executor
          final virtualTask = Task(
            id: virtualTaskId,
            parentId: mainTask.id, // Marcar como "subtask" da tarefa principal
            statusId: mainTask.statusId,
            regionalId: mainTask.regionalId,
            divisaoId: mainTask.divisaoId,
            segmentoId: mainTask.segmentoId,
            localIds: mainTask.localIds,
            executorIds: [executorPeriod.executorId],
            equipeIds: mainTask.equipeIds,
            localId: mainTask.localId,
            equipeId: mainTask.equipeId,
            status: mainTask.status,
            statusNome: mainTask.statusNome,
            regional: mainTask.regional,
            divisao: mainTask.divisao,
            locais: mainTask.locais,
            tipo: mainTask.tipo,
            ordem: mainTask.ordem,
            tarefa: '${executorPeriod.executorNome} - ${mainTask.tarefa}', // Nome do executor + tarefa
            executores: [executorPeriod.executorNome],
            equipes: mainTask.equipes,
            executor: executorPeriod.executorNome,
            frota: mainTask.frota,
            coordenador: mainTask.coordenador,
            si: mainTask.si,
            dataInicio: minDate ?? mainTask.dataInicio,
            dataFim: maxDate ?? mainTask.dataFim,
            ganttSegments: executorPeriod.periods, // Usar os períodos do executor como segmentos
            executorPeriods: [], // Não incluir períodos aninhados
            observacoes: mainTask.observacoes,
            horasPrevistas: mainTask.horasPrevistas,
            horasExecutadas: mainTask.horasExecutadas,
            prioridade: mainTask.prioridade,
          );
          
          hierarchicalTasks.add(virtualTask);
        }
      }

      // Linhas virtuais para períodos por frota
      if (isExpanded && mainTask.frotaPeriods.isNotEmpty) {
        for (var frotaPeriod in mainTask.frotaPeriods) {
          final virtualTaskId = '${mainTask.id}_frota_${frotaPeriod.frotaId}';

          DateTime? minDate;
          DateTime? maxDate;
          for (var period in frotaPeriod.periods) {
            if (minDate == null || period.dataInicio.isBefore(minDate)) {
              minDate = period.dataInicio;
            }
            if (maxDate == null || period.dataFim.isAfter(maxDate)) {
              maxDate = period.dataFim;
            }
          }

          final virtualTask = Task(
            id: virtualTaskId,
            parentId: mainTask.id,
            statusId: mainTask.statusId,
            regionalId: mainTask.regionalId,
            divisaoId: mainTask.divisaoId,
            segmentoId: mainTask.segmentoId,
            localIds: mainTask.localIds,
            executorIds: mainTask.executorIds,
            equipeIds: mainTask.equipeIds,
            frotaIds: [frotaPeriod.frotaId],
            localId: mainTask.localId,
            equipeId: mainTask.equipeId,
            status: mainTask.status,
            statusNome: mainTask.statusNome,
            regional: mainTask.regional,
            divisao: mainTask.divisao,
            locais: mainTask.locais,
            tipo: mainTask.tipo,
            ordem: mainTask.ordem,
            tarefa: '${frotaPeriod.frotaNome} - ${mainTask.tarefa}',
            executores: mainTask.executores,
            equipes: mainTask.equipes,
            executor: mainTask.executor,
            frota: frotaPeriod.frotaNome,
            coordenador: mainTask.coordenador,
            si: mainTask.si,
            dataInicio: minDate ?? mainTask.dataInicio,
            dataFim: maxDate ?? mainTask.dataFim,
            ganttSegments: frotaPeriod.periods,
            executorPeriods: const [],
            frotaPeriods: const [],
            observacoes: mainTask.observacoes,
            horasPrevistas: mainTask.horasPrevistas,
            horasExecutadas: mainTask.horasExecutadas,
            prioridade: mainTask.prioridade,
          );

          hierarchicalTasks.add(virtualTask);
        }
      }
    }
    
    return hierarchicalTasks;
  }


  void _scrollToPeriod(DateTime startDate, DateTime endDate, {bool animate = true}) {
    if (!_horizontalScrollController.hasClients) return;
    _isScrollingProgrammatically = true;
    final periods = widget.scale == GanttScale.daily
        ? _getDaysAsPeriods(widget.startDate, widget.endDate)
        : _getPeriodsInRange(widget.startDate, widget.endDate, widget.scale);
    const minP = 20.0;
    const maxP = 80.0;
    final desiredVisible = switch (widget.scale) {
      GanttScale.daily => 30.0,
      GanttScale.weekly => 12.0,
      GanttScale.biweekly => 6.0,
      GanttScale.monthly => 12.0,
      GanttScale.quarterly => 4.0,
      GanttScale.semiAnnual => 2.0,
    };
    final ganttWidth = MediaQuery.of(context).size.width * 0.5;
    final periodWidth = periods.isEmpty ? 40.0 : ((ganttWidth / desiredVisible) * 0.7).clamp(minP, maxP);
    final startOffset = _getDateOffsetFromPeriods(startDate, periods, periodWidth);
    
    // debug silenciado
    // debug silenciado
    // debug silenciado
    // debug silenciado
    double maxScrollExtent = 0.0;
    if (_horizontalScrollController.hasClients && _horizontalScrollController.positions.length == 1) {
      maxScrollExtent = _horizontalScrollController.position.maxScrollExtent;
    }
    // debug silenciado
    
    if (startOffset >= 0) {
      final scrollPosition = (startOffset - (periodWidth * 2)).clamp(0.0, maxScrollExtent);
      // debug silenciado
      // debug silenciado
      
      if (animate) {
        _horizontalScrollController.animateTo(
          scrollPosition,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        ).then((_) {
          // Resetar flag após o scroll terminar
          Future.delayed(const Duration(milliseconds: 100), () {
            _isScrollingProgrammatically = false;
          });
        });
        
        // Sincronizar todas as linhas
        for (var controller in _rowScrollControllers) {
          if (controller.hasClients) {
            controller.animateTo(
              scrollPosition,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        }
      } else {
        // Usar jumpTo para inicialização rápida
        _horizontalScrollController.jumpTo(scrollPosition);
        
        // Sincronizar todas as linhas
        for (var controller in _rowScrollControllers) {
          if (controller.hasClients) {
            controller.jumpTo(scrollPosition);
          }
        }
        
        // debug silenciado
        // Aguardar um frame para garantir que o scroll seja aplicado e os segmentos renderizados
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // debug silenciado
          // debug silenciado
          // Aguardar mais um frame para garantir que tudo foi renderizado
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // debug silenciado
            // Resetar flag após garantir que tudo foi renderizado
            _isScrollingProgrammatically = false;
            // Forçar rebuild para garantir que os segmentos sejam renderizados na posição correta
            if (mounted) {
              // debug silenciado
              setState(() {});
            }
          });
        });
      }
    } else {
      // Se não conseguir scrollar, resetar flag imediatamente
      _isScrollingProgrammatically = false;
    }
  }

  bool _isWeekend(DateTime date) {
    return date.weekday == 6 || date.weekday == 7; // Sábado ou Domingo
  }

  Color _getSegmentColor(Task task) {
    // APENAS usar cor do tipo de atividade (não usar mais cor do status)
    if (task.tipo.isNotEmpty) {
      final tipoAtividade = _tipoAtividadeMap[task.tipo];
      if (tipoAtividade != null && tipoAtividade.cor != null && tipoAtividade.cor!.isNotEmpty) {
        try {
          // Converter hexadecimal para Color
          final hexColor = tipoAtividade.cor!.replaceFirst('#', '');
          return Color(int.parse('FF$hexColor', radix: 16));
        } catch (e) {
          // debug silenciado
        }
      }
    }
    
    // Se não houver cor definida no tipo de atividade, usar cor padrão cinza
    return Colors.grey[400]!;
  }
  
  /// Clareia uma cor misturando com branco
  Color _lightenColor(Color color, double factor) {
    // factor: 0.0 = cor original, 1.0 = branco puro
    // Usar 0.4 para deixar 40% mais claro
    return Color.lerp(color, Colors.white, factor) ?? color;
  }

  Color _getSegmentColorByPeriod(GanttSegment segment, Task task, {Task? parentTask, bool isSubtask = false}) {
    // PRIORIDADE 1: Verificar o tipo de período
    // DESLOCAMENTO e PLANEJAMENTO sempre usam suas cores específicas, independente do tipo de atividade
    switch (segment.tipoPeriodo.toUpperCase()) {
      case 'PLANEJAMENTO':
        return Colors.orange[600]!; // Laranja para planejamento (sempre)
      case 'DESLOCAMENTO':
        return Colors.blue[900]!; // Azul escuro para deslocamento (sempre)
      case 'EXECUCAO':
      default:
        Color baseColor;
        
        // Se for subtarefa e tiver tarefa pai, usar a cor da tarefa pai
        if (isSubtask && parentTask != null) {
          // Obter a cor da tarefa pai (recursivamente, mas sem considerar subtarefa)
          baseColor = _getSegmentColorByPeriod(segment, parentTask, isSubtask: false);
          // Clarear a cor em 40%
          final lightenedColor = _lightenColor(baseColor, 0.4);
          // debug silenciado
          return lightenedColor;
        }
        
        // PRIORIDADE 2: Verificar se o tipo de atividade tem cor de segmento definida
        if (task.tipo.isNotEmpty) {
          final tipoAtividade = _tipoAtividadeMap[task.tipo];
          if (tipoAtividade != null && tipoAtividade.corSegmento != null && tipoAtividade.corSegmento!.isNotEmpty) {
            try {
              baseColor = tipoAtividade.segmentBackgroundColor;
              // debug silenciado
              return baseColor;
            } catch (e) {
              // debug silenciado
            }
          }
          // PRIORIDADE 3: Se não houver cor de segmento, usar cor principal do tipo de atividade
          if (tipoAtividade != null && tipoAtividade.cor != null && tipoAtividade.cor!.isNotEmpty) {
            try {
              // Converter hexadecimal para Color
              final hexColor = tipoAtividade.cor!.replaceFirst('#', '');
              baseColor = Color(int.parse('FF$hexColor', radix: 16));
              // debug silenciado
              return baseColor;
            } catch (e) {
              // debug silenciado
            }
          }
        }
        // Se não houver cor definida, usar cinza padrão
        return Colors.grey[400]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final ganttWidth = screenWidth * 0.5;

    final periods = widget.scale == GanttScale.daily
        ? _getDaysAsPeriods(widget.startDate, widget.endDate)
        : _getPeriodsInRange(widget.startDate, widget.endDate, widget.scale);

    const minPeriodWidth = 20.0;
    const maxPeriodWidth = 80.0;
    final desiredVisible = switch (widget.scale) {
      GanttScale.daily => 30.0,
      GanttScale.weekly => 12.0,
      GanttScale.biweekly => 6.0,
      GanttScale.monthly => 12.0,
      GanttScale.quarterly => 4.0,
      GanttScale.semiAnnual => 2.0,
    };
    final periodWidth = periods.isEmpty
        ? 40.0
        : ((ganttWidth / desiredVisible) * 0.7)
            .clamp(minPeriodWidth, maxPeriodWidth);
    final totalWidth = periods.length * periodWidth;

    final today = DateTime.now();
    final todayOffset = _getTodayOffsetFromPeriods(today, periods, periodWidth);
    
    // Calcular posição inicial para mostrar o período selecionado (apenas na primeira renderização)
    if (!_hasInitializedScroll) {
      final targetDate = widget.startDate;
      final initialOffset = _getDateOffsetFromPeriods(targetDate, periods, periodWidth);
      // debug silenciado
      // debug silenciado
      // debug silenciado
      // debug silenciado
      // debug silenciado
      // debug silenciado
      // debug silenciado

      // Scroll para a posição correta na primeira renderização
      // Usar múltiplos callbacks para garantir que tudo seja renderizado corretamente
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // debug silenciado
        // debug silenciado
        // debug silenciado
        
        // Primeiro callback: garantir que os controllers estejam prontos
        if (_horizontalScrollController.hasClients && !_hasInitializedScroll) {
          // Aguardar mais um frame para garantir que os segmentos sejam renderizados
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // debug silenciado
            // debug silenciado
            
            if (mounted && _horizontalScrollController.hasClients) {
              _hasInitializedScroll = true;
              if (_horizontalScrollController.hasClients && _horizontalScrollController.positions.length == 1) {
                // debug silenciado
              } else {
                // debug silenciado
              }
              
              // Como mostramos apenas o período selecionado, scroll deve começar em 0
              _horizontalScrollController.jumpTo(0);
              
              // Sincronizar todas as linhas
              for (var controller in _rowScrollControllers) {
                if (controller.hasClients) {
                  controller.jumpTo(0);
                }
              }
              
              
              // Aguardar mais um frame após o scroll para garantir renderização completa
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  // Forçar rebuild para garantir que os segmentos sejam renderizados na posição correta
                  setState(() {});
                }
              });
            }
          });
        } else {
        }
      });
    }
    // Removido o auto-alinhamento contínuo para permitir navegação livre do usuário

    return Container(
      decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cabeçalho do Gantt com scroll sincronizado
          Column(
            children: [
              // Linha de grupos (meses / trimestres / anos conforme escala)
              Container(
                height: Responsive.kActivitiesHeaderTopHeight,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                ),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification is ScrollUpdateNotification) {
                        _syncHorizontalScroll();
                      } else if (notification is ScrollEndNotification) {
                        _syncHorizontalScroll();
                      }
                      return false;
                    },
                    child: SingleChildScrollView(
                      controller: _monthHeaderScrollController,
                      scrollDirection: Axis.horizontal,
                      physics: const ClampingScrollPhysics(),
                      padding: EdgeInsets.zero,
                      child: SizedBox(
                        width: totalWidth,
                        height: Responsive.kActivitiesHeaderTopHeight,
                        child: Stack(
                          alignment: Alignment.topLeft,
                          fit: StackFit.loose,
                          children: [
                            ..._buildMergedGroupHeaders(periods, periodWidth),
                            // Ícone de arrastar no lado esquerdo do cabeçalho
                            Positioned(
                              left: 0,
                              top: 0,
                              bottom: 0,
                              child: Container(
                                width: 30,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  border: Border(
                                    right: BorderSide(
                                      color: Colors.grey[400]!,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.drag_handle,
                                    color: Colors.grey[700],
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Linha de períodos (dias / semanas / meses etc.)
              Container(
                height: Responsive.kActivitiesHeaderRowHeight,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                ),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: (event) {
                      if (event.kind == PointerDeviceKind.mouse) {
                        if (_isSegmentBeingDragged) {
                          _isDraggingFromEmptyArea = false;
                          _isDragging = false;
                          return;
                        }
                        _isDraggingFromEmptyArea = true;
                        _isDragging = true;
                        _lastDragPosition = event.localPosition.dx;
                      }
                    },
                    onPointerMove: (event) {
                      if (_isSegmentBeingDragged) {
                        _isDragging = false;
                        _isDraggingFromEmptyArea = false;
                        return;
                      }
                      if (_isDragging && _isDraggingFromEmptyArea &&
                          event.kind == PointerDeviceKind.mouse) {
                        final delta = _lastDragPosition - event.localPosition.dx;
                        _lastDragPosition = event.localPosition.dx;
                        final adjustedDelta = delta * 0.2;
                        if (_horizontalScrollController.hasClients) {
                          final newOffset =
                              (_horizontalScrollController.offset + adjustedDelta)
                                  .clamp(
                                    0.0,
                                    _horizontalScrollController
                                        .position
                                        .maxScrollExtent,
                                  );
                          _horizontalScrollController.jumpTo(newOffset);
                        }
                      }
                    },
                    onPointerUp: (event) {
                      if (event.kind == PointerDeviceKind.mouse) {
                        _isDragging = false;
                        _isDraggingFromEmptyArea = false;
                      }
                    },
                    onPointerCancel: (event) {
                      if (event.kind == PointerDeviceKind.mouse) {
                        _isDragging = false;
                        _isDraggingFromEmptyArea = false;
                      }
                    },
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification is ScrollUpdateNotification) {
                          _syncMonthHeader();
                        } else if (notification is ScrollEndNotification) {
                          _syncMonthHeader();
                        }
                        return false;
                      },
                      child: SingleChildScrollView(
                        controller: _horizontalScrollController,
                        scrollDirection: Axis.horizontal,
                        physics: (_isDragging && _isDraggingFromEmptyArea)
                            ? const NeverScrollableScrollPhysics()
                            : const ClampingScrollPhysics(),
                        padding: EdgeInsets.zero,
                        child: SizedBox(
                          width: totalWidth,
                          height: Responsive.kActivitiesHeaderRowHeight,
                          child: Stack(
                            alignment: Alignment.topLeft,
                            fit: StackFit.loose,
                            children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              textDirection: TextDirection.ltr,
                              mainAxisSize: MainAxisSize.min,
                              children: periods.map((p) {
                                final isDaily = widget.scale == GanttScale.daily;
                                final day = p.start;
                                final isWeekend = isDaily && _isWeekend(day);
                                final isFeriado = isDaily && _isFeriado(day);
                                return Container(
                                  width: periodWidth,
                                  height: Responsive.kActivitiesHeaderRowHeight,
                                  padding: EdgeInsets.zero,
                                  margin: EdgeInsets.zero,
                                  decoration: BoxDecoration(
                                    color: isFeriado
                                        ? Colors.purple[100]
                                        : isWeekend
                                            ? Colors.grey[200]
                                            : Colors.white,
                                    border: Border.all(
                                      color: Colors.grey[300]!,
                                      width: 1,
                                    ),
                                  ),
                                  alignment: Alignment.centerLeft,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 2.0),
                                    child: Text(
                                      p.label,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.normal,
                                        color: Colors.black,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            // Linhas verticais entre grupos (primeiro período de cada grupo)
                            ..._buildGroupSeparators(periods, periodWidth),
                            // Indicador do dia atual no cabeçalho
                            if (todayOffset >= 0)
                              Positioned(
                                left: todayOffset + (periodWidth / 2) - 8,
                                top: 0,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: Colors.red[500],
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.red.withOpacity(0.5),
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.circle,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Corpo do Gantt com scroll horizontal habilitado
          Builder(
            builder: (context) {
              // Calcular lista hierárquica uma vez para evitar múltiplas chamadas
              final hierarchicalTasks = _buildHierarchicalTasks();
              
              // Garantir que temos controllers suficientes para todas as linhas
              while (_rowScrollControllers.length < hierarchicalTasks.length) {
                final controller = ScrollController();
                // Adicionar listener para sincronizar com o cabeçalho
                controller.addListener(() {
                  if (!_isScrolling && _horizontalScrollController.hasClients && controller.hasClients) {
                    final offset = controller.offset;
                    if ((_horizontalScrollController.offset - offset).abs() > 1.0) {
                      _isScrolling = true;
                      _horizontalScrollController.jumpTo(offset);
                      // Sincronizar todas as outras linhas
                      for (var ctrl in _rowScrollControllers) {
                        if (ctrl != controller && ctrl.hasClients) {
                          ctrl.jumpTo(offset);
                        }
                      }
                      _isScrolling = false;
                    }
                  }
                });
                _rowScrollControllers.add(controller);
              }
              
              // Calcular hash das subtarefas para forçar rebuild quando mudarem
              final subtasksHash = _loadedSubtasks.values.fold<int>(
                0,
                (sum, subtasks) => sum + subtasks.fold<int>(0, (s, t) => s + t.ganttSegments.length),
              );
              
              // Criar uma chave que inclui os IDs das tarefas expandidas para forçar rebuild
              final expandedTasksKey = _expandedTasks.toList()..sort();
              final expandedKeyString = expandedTasksKey.join(',');
              
              return Expanded(
                child: RepaintBoundary(
                  child: ListView.builder(
                    key: ValueKey('gantt_tasks_${hierarchicalTasks.length}_${expandedKeyString}_${subtasksHash}'),
                    controller: widget.scrollController,
                    itemCount: hierarchicalTasks.length,
                    itemBuilder: (context, index) {
                    final task = hierarchicalTasks[index];
                      final isSubtask = task.parentId != null;
                      final subtasksCount = _loadedSubtasks[task.id]?.length ?? 0;
                      final hasSubtasks = subtasksCount > 0;
                      
                      // Verificar se é uma linha virtual de executor (tem _executor_ no ID)
                      final isExecutorRow = task.id.contains('_executor_');
                      
                      final hasExecutorPeriods = !isSubtask && !isExecutorRow && task.executorPeriods.isNotEmpty;
                      final isExpanded = _expandedTasks.contains(task.id);
                      
                      // Debug: verificar se a tarefa tem períodos por executor (sempre verificar, não apenas quando hasExecutorPeriods)
                      if (!isSubtask && !isExecutorRow) {
                        if (task.executorPeriods.isNotEmpty) {
                          // debug silenciado
                          // debug silenciado
                          // debug silenciado
                          for (var ep in task.executorPeriods) {
                            // debug silenciado
                          }
                        } else {
                          // Debug: verificar se a tarefa deveria ter períodos mas não tem
                          // (pode indicar problema de carregamento)
                          if (task.tarefa.toLowerCase().contains('recuperação') || 
                              task.tarefa.toLowerCase().contains('reator')) {
                            // debug silenciado
                            // debug silenciado
                          }
                        }
                      }
                      
                      // Método para alternar expansão
                      void toggleExpansion() {
                        final newExpandedState = !isExpanded;
                        
                        // Notificar o callback compartilhado se existir
                        if (widget.onTaskExpanded != null) {
                          widget.onTaskExpanded!(task.id, newExpandedState);
                        } else {
                          // Fallback para estado local
                          setState(() {
                            if (newExpandedState) {
                              _localExpandedTasks.add(task.id);
                            } else {
                              _localExpandedTasks.remove(task.id);
                            }
                          });
                        }
                      }

                      // Criar controller para cada linha se necessário
                      while (_rowScrollControllers.length <= index) {
                        final controller = ScrollController();
                        _rowScrollControllers.add(controller);
                      }

                      final rowController = _rowScrollControllers[index];
                      
                      // Sincronizar com o cabeçalho quando o controller estiver pronto
                      if (_hasInitializedScroll && _horizontalScrollController.hasClients) {
                        final targetOffset = _horizontalScrollController.offset;
                        // Sincronizar imediatamente se possível
                        if (rowController.hasClients) {
                          if ((rowController.offset - targetOffset).abs() > 1.0) {
                            rowController.jumpTo(targetOffset);
                          }
                        } else {
                          // Se o controller ainda não tem clients, aguardar
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (rowController.hasClients && mounted) {
                              final currentOffset = rowController.offset;
                              final updatedOffset = _horizontalScrollController.hasClients 
                                  ? _horizontalScrollController.offset 
                                  : targetOffset;
                              if ((currentOffset - updatedOffset).abs() > 1.0) {
                                rowController.jumpTo(updatedOffset);
                              }
                            }
                          });
                        }
                      }

                      // Verificar se mudou o grupo (apenas se não for PERÍODO e se não for subtarefa/executor)
                      final previousTask = index > 0 ? hierarchicalTasks[index - 1] : null;
                      bool mudouGrupo = false;
                      
                      // Debug inicial
                      if (index == 0) {
                      }
                      
                      if (widget.sortColumn != null && 
                          widget.sortColumn != 'PERÍODO' && 
                          previousTask != null &&
                          !previousTask.id.contains('_executor_') &&
                          previousTask.parentId == null &&
                          !isSubtask &&
                          !isExecutorRow &&
                          widget.getSortValue != null) {
                        try {
                          final previousValue = widget.getSortValue!(previousTask);
                          final currentValue = widget.getSortValue!(task);
                          mudouGrupo = previousValue.trim() != currentValue.trim();
                          
                          // Debug - mostrar quando detectar mudança
                          if (mudouGrupo) {
                            // debug silenciado
                            // debug silenciado
                            // debug silenciado
                          }
                        } catch (e, stackTrace) {
                          // Se houver erro, não mostrar linha separadora
                        debugPrint('Erro ao verificar mudança de grupo no Gantt: $e');
                          // debug silenciado
                          mudouGrupo = false;
                        }
                      } else {
                        // Debug para entender por que não está verificando
                        if (index < 3) {
                        }
                      }
                      
                      // Altura padrão da linha (períodos por executor agora são linhas separadas)
                      final rowHeight = 50.0;

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Linha separadora se mudou grupo (no topo)
                          if (mudouGrupo)
                            Container(
                              height: 1,
                              width: double.infinity,
                              color: const Color.fromARGB(255, 0, 0, 0),
                            ),
                          // Linha do Gantt
                          SizedBox(
                            height: rowHeight,
                            child: Stack(
                              children: [
                                Container(
                                  padding: EdgeInsets.zero,
                                  margin: EdgeInsets.zero,
                                  decoration: BoxDecoration(
                                    color: isSubtask ? Colors.grey[50]!.withOpacity(0.5) : Colors.white,
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Colors.grey[300]!,
                                        width: 1,
                                      ),
                                      left: isExecutorRow
                                          ? BorderSide(
                                              color: Colors.orange[400]!,
                                              width: 3,
                                            )
                                          : isSubtask 
                                              ? BorderSide(
                                                  color: Colors.blue[400]!,
                                                  width: 4,
                                                )
                                              : (hasSubtasks || hasExecutorPeriods)
                                                  ? BorderSide(
                                                      color: Colors.blue[200]!,
                                                      width: 2,
                                                    )
                                                  : BorderSide.none,
                                    ),
                                  ),
                                ),
                                // Botão de expansão (se tiver subtarefas ou períodos por executor)
                                if ((hasSubtasks || hasExecutorPeriods) && !isSubtask && !isExecutorRow)
                                  Positioned(
                                    left: 4,
                                    top: 4,
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: toggleExpansion,
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: Colors.blue[50],
                                            border: Border.all(color: Colors.blue[300]!, width: 1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            isExpanded ? Icons.expand_less : Icons.expand_more,
                                            size: 16,
                                            color: Colors.blue[700],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                // Área do gráfico
                                Positioned.fill(
                                  child: Listener(
                                    behavior: HitTestBehavior.deferToChild,
                                    onPointerDown: (event) {
                                  if (event.kind != PointerDeviceKind.mouse) return;
                                  
                                  // Se algum segmento está sendo arrastado, não iniciar o drag do período
                                  if (_isSegmentBeingDragged) {
                                    _isDraggingFromEmptyArea = false;
                                    _isDragging = false;
                                    return;
                                  }
                                  
                                  // Verificar se o clique está em algum segmento
                                  final clickX = event.localPosition.dx;
                                  bool isOnSegment = false;
                                  
                                    for (var segment in task.ganttSegments) {
                                      final startDate = DateTime(
                                        segment.dataInicio.year,
                                        segment.dataInicio.month,
                                        segment.dataInicio.day,
                                      );
                                      final rawEndDate = DateTime(
                                        segment.dataFim.year,
                                        segment.dataFim.month,
                                        segment.dataFim.day,
                                      );
                                      final endDate = _normalizeLegacyEndDate(task, startDate, rawEndDate);
                                      final startOffset = _getDateOffsetFromPeriods(startDate, periods, periodWidth);
                                      final barWidth = _getBarWidthForRange(startDate, endDate, periods, periodWidth);
                                      if (clickX >= startOffset && clickX <= startOffset + barWidth) {
                                        isOnSegment = true;
                                        break;
                                      }
                                    }
                                  
                                  // Só iniciar o drag de scroll se NÃO estiver clicando em um segmento
                                  if (!isOnSegment) {
                                    _isDraggingFromEmptyArea = true;
                                    _isDragging = true;
                                    _lastDragPosition = event.localPosition.dx;
                                  } else {
                                    // Se estiver em um segmento, não iniciar o drag
                                    _isDraggingFromEmptyArea = false;
                                    _isDragging = false;
                                  }
                                },
                                onPointerMove: (event) {
                                  // Se algum segmento está sendo arrastado, não processar o movimento do período
                                  if (_isSegmentBeingDragged) {
                                    _isDragging = false;
                                    _isDraggingFromEmptyArea = false;
                                    return;
                                  }
                                  
                                  if (_isDragging && _isDraggingFromEmptyArea &&
                                      event.kind == PointerDeviceKind.mouse) {
                                    // Verificar novamente se ainda está em uma área vazia
                                    final moveX = event.localPosition.dx;
                                    bool isOnSegment = false;
                                    
                                    for (var segment in task.ganttSegments) {
                                      final startDate = DateTime(
                                        segment.dataInicio.year,
                                        segment.dataInicio.month,
                                        segment.dataInicio.day,
                                      );
                                      final rawEnd = DateTime(
                                        segment.dataFim.year,
                                        segment.dataFim.month,
                                        segment.dataFim.day,
                                      );
                                      final endDate = _normalizeLegacyEndDate(task, startDate, rawEnd);
                                      final startOffset = _getDateOffsetFromPeriods(startDate, periods, periodWidth);
                                      final barWidth = _getBarWidthForRange(startDate, endDate, periods, periodWidth);
                                      if (moveX >= startOffset && moveX <= startOffset + barWidth) {
                                        isOnSegment = true;
                                        break;
                                      }
                                    }
                                    
                                    // Se estiver em um segmento, cancelar o drag
                                    if (isOnSegment) {
                                      _isDragging = false;
                                      _isDraggingFromEmptyArea = false;
                                      return;
                                    }
                                    
                                    final delta = _lastDragPosition - event.localPosition.dx;
                                    _lastDragPosition = event.localPosition.dx;
                                    
                                    // Reduzir ainda mais a velocidade do scroll (multiplicar por 0.2 para tornar bem mais lento)
                                    final adjustedDelta = delta * 0.2;

                                    // Atualizar o scroll desta linha e sincronizar com o cabeçalho
                                    if (rowController.hasClients) {
                                      final newOffset = (rowController.offset + adjustedDelta)
                                          .clamp(
                                            0.0,
                                            rowController.position.maxScrollExtent,
                                          );
                                      _isScrolling = true;
                                      rowController.jumpTo(newOffset);
                                      
                                      // Sincronizar com o cabeçalho
                                      if (_horizontalScrollController.hasClients) {
                                        _horizontalScrollController.jumpTo(newOffset);
                                      }
                                      
                                      // Sincronizar todas as outras linhas
                                      for (var controller in _rowScrollControllers) {
                                        if (controller != rowController && controller.hasClients) {
                                          controller.jumpTo(newOffset);
                                        }
                                      }
                                      
                                      _isScrolling = false;
                                    }
                                  }
                                    },
                                    onPointerUp: (event) {
                                      if (event.kind == PointerDeviceKind.mouse) {
                                        _isDragging = false;
                                        _isDraggingFromEmptyArea = false;
                                      }
                                    },
                                    onPointerCancel: (event) {
                                      if (event.kind == PointerDeviceKind.mouse) {
                                        _isDragging = false;
                                        _isDraggingFromEmptyArea = false;
                                      }
                                    },
                                    child: SingleChildScrollView(
                                controller: rowController,
                                scrollDirection: Axis.horizontal,
                                physics: (_isDragging && _isDraggingFromEmptyArea)
                                    ? const NeverScrollableScrollPhysics()
                                    : const ClampingScrollPhysics(),
                                padding: EdgeInsets.zero,
                                child: SizedBox(
                                  width: totalWidth,
                                  height: rowHeight,
                                  child: Stack(
                                    key: ValueKey('gantt_row_${task.id}_${task.ganttSegments.length}_${task.parentId != null ? "sub" : "main"}'),
                                    alignment: Alignment.topLeft,
                                    fit: StackFit.loose,
                                    children: [
                                    // Grid de dias (sem pintar conflito aqui — conflito só nas barras dos segmentos, com tooltip)
                                    Builder(
                                      builder: (context) {
                                        return Row(
                                      mainAxisAlignment: MainAxisAlignment.start,
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      textDirection: TextDirection.ltr,
                                      mainAxisSize: MainAxisSize.min,
                                      children: periods.map((p) {
                                        final isDaily = widget.scale == GanttScale.daily;
                                        final day = p.start;
                                        final isWeekend = isDaily && _isWeekend(day);
                                        final isFeriado = isDaily && _isFeriado(day);
                                        return Container(
                                          width: periodWidth,
                                          height: rowHeight,
                                          padding: EdgeInsets.zero,
                                          margin: EdgeInsets.zero,
                                          decoration: BoxDecoration(
                                                color: isFeriado
                                                ? Colors.purple[100]
                                                : isWeekend
                                                    ? Colors.grey[200]
                                                    : Colors.white,
                                                border: Border(
                                                  right: BorderSide(
                                                    color: Colors.grey[300]!,
                                                    width: 1,
                                                  ),
                                                  bottom: BorderSide(
                                              color: Colors.grey[300]!,
                                              width: 1,
                                                  ),
                                                  top: BorderSide(
                                                    color: Colors.grey[300]!,
                                                    width: 1,
                                                  ),
                                                  left: BorderSide(
                                                    color: Colors.grey[300]!,
                                                    width: 1,
                                                  ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                        );
                                      },
                                    ),
                                  ..._buildGroupSeparators(periods, periodWidth),
                                  // Barras de tarefas
                                  // Debug: verificar se a tarefa tem segmentos
                                  Builder(
                                    builder: (context) {
                                      if (task.ganttSegments.isEmpty) {
                                        // debug silenciado
                                        // debug silenciado
                                        // debug silenciado
                                        // debug silenciado
                                      } else {
                                        final tipoTarefa = task.parentId != null ? "SUBTAREFA" : "PRINCIPAL";
                                        // debug silenciado
                                        // debug silenciado
                                        for (var seg in task.ganttSegments) {
                                          final segStart = seg.dataInicio.toString().substring(0, 10);
                                          final segEnd = seg.dataFim.toString().substring(0, 10);
                                          final dentroPeriodo = !seg.dataFim.isBefore(widget.startDate) && !seg.dataInicio.isAfter(widget.endDate);
                                          // debug silenciado
                                        }
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                  ...task.ganttSegments.asMap().entries.map((
                                    entry,
                                  ) {
                                    final segmentIndex = entry.key;
                                    final segment = entry.value;
                                    
                                    // Normalizar datas para calcular corretamente
                                    final startDate = DateTime(
                                      segment.dataInicio.year,
                                      segment.dataInicio.month,
                                      segment.dataInicio.day,
                                    );
                                    final endDate = DateTime(
                                      segment.dataFim.year,
                                      segment.dataFim.month,
                                      segment.dataFim.day,
                                    );
                                    
                                    if (endDate.isBefore(widget.startDate)) {
                                      return const SizedBox.shrink();
                                    }
                                    if (startDate.isAfter(widget.endDate)) {
                                      return const SizedBox.shrink();
                                    }
                                    double startOffset;
                                    double barWidth;
                                    if (startDate.isBefore(widget.startDate)) {
                                      startOffset = 0;
                                      final adjustedEndDate = endDate.isAfter(widget.endDate)
                                          ? widget.endDate
                                          : endDate;
                                      barWidth = _getBarWidthForRange(
                                          widget.startDate, adjustedEndDate, periods, periodWidth);
                                    } else {
                                      startOffset = _getDateOffsetFromPeriods(startDate, periods, periodWidth);
                                      final adjustedEndDate = endDate.isAfter(widget.endDate)
                                          ? widget.endDate
                                          : endDate;
                                      barWidth = _getBarWidthForRange(
                                          startDate, adjustedEndDate, periods, periodWidth);
                                    }
                                    if (barWidth < 0) {
                                      barWidth = periodWidth;
                                    }
                                    
                                    // Se startOffset for negativo, significa que a data não está no range
                                    if (startOffset < 0) {
                                      // Data não encontrada no range - retornar widget vazio
                                      return const SizedBox.shrink();
                                    }
                                    
                                    // Garantir que barWidth nunca seja negativo ou zero
                                    if (barWidth <= 0) {
                                      return const SizedBox.shrink();
                                    }

                                    // Buscar tarefa pai se for subtarefa
                                    Task? parentTask;
                                    if (isSubtask && task.parentId != null) {
                                      try {
                                        parentTask = hierarchicalTasks.firstWhere(
                                          (t) => t.id == task.parentId,
                                        );
                                      } catch (e) {
                                        // Se não encontrar a tarefa pai, não usar cor clareada
                                        parentTask = null;
                                      }
                                    }

                                    // Cache da cor para evitar recálculo
                                    final segmentColor = _getSegmentColorByPeriod(
                                      segment, 
                                      task, 
                                      parentTask: parentTask,
                                      isSubtask: isSubtask,
                                    );
                                    // Obter cor do texto do tipo de atividade se disponível
                                    Color segmentTextColor = Colors.white;
                                    if (task.tipo.isNotEmpty) {
                                      final tipoAtividade = _tipoAtividadeMap[task.tipo];
                                      if (tipoAtividade != null && tipoAtividade.corTextoSegmento != null && tipoAtividade.corTextoSegmento!.isNotEmpty) {
                                        try {
                                          segmentTextColor = tipoAtividade.segmentTextColor;
                                        } catch (e) {
                                          // debug silenciado
                                        }
                                      }
                                    }

                                    // Conflitos: só calcular e pintar vermelho após o 1º frame e com lista pronta
                                    // (evita vermelho fantasma no hot restart / carregamento que some sozinho)
                                    final conflictListReady = widget.tasksForConflictDetection != null &&
                                        widget.tasksForConflictDetection!.isNotEmpty;
                                    final conflictDays = (widget.scale == GanttScale.daily &&
                                            conflictListReady &&
                                            _conflictPaintReady)
                                        ? _getConflictDaysForSegment(task, startDate, endDate)
                                        : null;
                                    final conflictDaysFrota = (widget.scale == GanttScale.daily &&
                                            conflictListReady &&
                                            _conflictPaintReady)
                                        ? _getConflictDaysForSegmentFrota(task, startDate, endDate)
                                        : null;
                                    final conflictTooltipMessage = (conflictDays != null && conflictDays.isNotEmpty)
                                        ? _getConflictDetailsMessage(task, startDate, endDate)
                                        : null;
                                    final conflictTooltipMessageFrota = (conflictDaysFrota != null && conflictDaysFrota.isNotEmpty)
                                        ? _getFleetConflictDetailsMessage(task, startDate, endDate)
                                        : null;
                                    final conflictTooltipMessageByDay = <DateTime, String>{};
                                    if (conflictDays != null) {
                                      for (final d in conflictDays) {
                                        final dayNorm = DateTime(d.year, d.month, d.day);
                                        final msg = _getConflictDetailsMessageForSingleDay(task, dayNorm);
                                        if (msg != null && msg.isNotEmpty) {
                                          conflictTooltipMessageByDay[dayNorm] = msg;
                                        }
                                      }
                                    }
                                    final conflictTooltipMessageByDayFrota = <DateTime, String>{};
                                    if (conflictDaysFrota != null) {
                                      for (final d in conflictDaysFrota) {
                                        final dayNorm = DateTime(d.year, d.month, d.day);
                                        final msg = _getFleetConflictDetailsMessageForSingleDay(task, dayNorm);
                                        if (msg != null && msg.isNotEmpty) {
                                          conflictTooltipMessageByDayFrota[dayNorm] = msg;
                                        }
                                      }
                                    }
                                    return Positioned(
                                      left: startOffset,
                                      top: 0,
                                      bottom: 0,
                                      child: RepaintBoundary(
                                        key: ValueKey('segment_${task.id}_$segmentIndex\_cf${widget.tasksForConflictDetection?.length ?? 0}'),
                                        child: _DraggableSegment(
                                          task: task,
                                          segmentIndex: segmentIndex,
                                          segment: segment,
                                          normalizedStartDate: startDate,
                                          normalizedEndDate: endDate,
                                          barWidth: barWidth,
                                          dayWidth: periodWidth,
                                          periods: periods,
                                          color: segmentColor,
                                          textColor: segmentTextColor,
                                          conflictDays: conflictDays,
                                          conflictTooltipMessage: conflictTooltipMessage,
                                          conflictTooltipMessageByDay: conflictTooltipMessageByDay.isEmpty ? null : conflictTooltipMessageByDay,
                                          conflictDaysFrota: conflictDaysFrota,
                                          conflictTooltipMessageFrota: conflictTooltipMessageFrota,
                                          conflictTooltipMessageByDayFrota: conflictTooltipMessageByDayFrota.isEmpty ? null : conflictTooltipMessageByDayFrota,
                                          taskService: widget.taskService,
                                          onTasksUpdated: widget.onTasksUpdated,
                                          onDragStart: _onSegmentDragStart,
                                          onDragEnd: _onSegmentDragEnd,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  // Linha vertical indicando o dia atual (por cima de tudo)
                                  if (todayOffset >= 0)
                                    Positioned(
                                      left: todayOffset + (periodWidth / 2),
                                      top: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 3,
                                        decoration: BoxDecoration(
                                          color: Colors.red[600],
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.red.withOpacity(0.7),
                                              blurRadius: 4,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMergedGroupHeaders(List<GanttPeriod> periods, double periodWidth) {
    final List<Widget> headers = [];
    String? currentGroup;
    int startIndex = 0;
    for (int i = 0; i < periods.length; i++) {
      final g = periods[i].groupLabel ?? '';
      if (currentGroup == null || g != currentGroup) {
        if (currentGroup != null) {
          final w = (i - startIndex) * periodWidth;
          final offset = startIndex * periodWidth;
          headers.add(
            Positioned(
              left: offset,
              top: 0,
              bottom: 0,
              width: w,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  border: Border(
                    right: BorderSide(color: Colors.grey[300]!, width: 1),
                    bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                  ),
                ),
                child: Center(
                  child: Text(
                    currentGroup,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          );
        }
        currentGroup = g;
        startIndex = i;
      }
    }
    if (currentGroup != null) {
      final w = (periods.length - startIndex) * periodWidth;
      final offset = startIndex * periodWidth;
      headers.add(
        Positioned(
          left: offset,
          top: 0,
          bottom: 0,
          width: w,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
            ),
            child: Center(
              child: Text(
                currentGroup,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      );
    }
    return headers;
  }

  List<Widget> _buildGroupSeparators(List<GanttPeriod> periods, double periodWidth) {
    final List<Widget> sep = [];
    String? prevGroup;
    for (int i = 0; i < periods.length; i++) {
      final g = periods[i].groupLabel ?? '';
      if (prevGroup != null && g != prevGroup) {
        sep.add(
          Positioned(
            left: i * periodWidth,
            top: 0,
            bottom: 0,
            child: Container(
              width: 2,
              decoration: BoxDecoration(
                color: Colors.blue[700],
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 2,
                    spreadRadius: 0.5,
                  ),
                ],
              ),
            ),
          ),
        );
      }
      prevGroup = g;
    }
    return sep;
  }

  String _getMonthFullName(DateTime date) {
    const months = [
      '',
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];
    
    if (date.month >= 1 && date.month <= 12) {
      return '${months[date.month]} ${date.year}';
    }
    return '';
  }

  double _getDayOffset(DateTime date, List<DateTime> days, double dayWidth) {
    // Normalizar a data para comparar apenas ano, mês e dia (sem hora/minuto/segundo)
    final normalizedDate = DateTime(date.year, date.month, date.day);
    
    for (int i = 0; i < days.length; i++) {
      // Os dias já devem estar normalizados, mas vamos garantir
      final day = days[i];
      final normalizedDay = DateTime(day.year, day.month, day.day);
      
      // Comparar usando isAtSameMomentAs ou comparação direta
      if (normalizedDay.year == normalizedDate.year &&
          normalizedDay.month == normalizedDate.month &&
          normalizedDay.day == normalizedDate.day) {
        return i * dayWidth;
      }
    }
    
    // Se não encontrou, verificar se está antes ou depois do range
    final firstDay = DateTime(days.first.year, days.first.month, days.first.day);
    final lastDay = DateTime(days.last.year, days.last.month, days.last.day);
    
    if (normalizedDate.isBefore(firstDay)) {
      // Data está antes do range, retornar posição negativa ou 0
      return 0;
    } else if (normalizedDate.isAfter(lastDay)) {
      // Data está depois do range, retornar posição após o último dia
      return days.length * dayWidth;
    }
    
    // Se chegou aqui, algo está errado - retornar 0
    return 0;
  }

  double _getTodayOffset(DateTime today, List<DateTime> days, double dayWidth) {
    // Normalizar a data de hoje
    final normalizedToday = DateTime(today.year, today.month, today.day);
    
    for (int i = 0; i < days.length; i++) {
      final day = days[i];
      final normalizedDay = DateTime(day.year, day.month, day.day);
      
      if (normalizedDay.year == normalizedToday.year &&
          normalizedDay.month == normalizedToday.month &&
          normalizedDay.day == normalizedToday.day) {
        return i * dayWidth;
      }
    }
    return -1; // Retorna -1 se hoje não estiver no range
  }

  List<DateTime> _getDaysInRange(DateTime start, DateTime end) {
    final days = <DateTime>[];
    // Normalizar as datas de início e fim para garantir que começam à meia-noite
    var current = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);

    // Incluir o último dia também (usar <=)
    while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
      // Garantir que cada dia está normalizado (sem hora/minuto/segundo)
      days.add(DateTime(current.year, current.month, current.day));
      current = current.add(const Duration(days: 1));
    }

    return days;
  }

  static const List<String> _monthNames = [
    '', 'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
    'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez',
  ];

  /// Períodos de um dia cada (compatível com escala diária).
  List<GanttPeriod> _getDaysAsPeriods(DateTime start, DateTime end) {
    final days = _getDaysInRange(start, end);
    return days.map((d) {
      final startDay = DateTime(d.year, d.month, d.day);
      final endDay = startDay.add(const Duration(days: 1));
      return GanttPeriod(
        start: startDay,
        end: endDay,
        label: d.day.toString().padLeft(2, '0'),
        groupLabel: _getMonthFullName(startDay),
      );
    }).toList();
  }

  /// Segunda-feira da semana que contém [date] (ISO week).
  DateTime _startOfWeek(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final wd = d.weekday;
    return d.subtract(Duration(days: wd - 1));
  }

  /// Gera períodos conforme a escala (semanal, quinzenal, mensal, trimestral, semestral).
  List<GanttPeriod> _getPeriodsInRange(DateTime start, DateTime end, GanttScale scale) {
    final startNorm = DateTime(start.year, start.month, start.day);
    final endNorm = DateTime(end.year, end.month, end.day);
    final list = <GanttPeriod>[];

    switch (scale) {
      case GanttScale.daily:
        return _getDaysAsPeriods(start, end);
      case GanttScale.weekly: {
        var cur = _startOfWeek(startNorm);
        while (cur.isBefore(endNorm) || cur.isAtSameMomentAs(endNorm)) {
          final endWeek = cur.add(const Duration(days: 7));
          if (endWeek.isAfter(startNorm)) {
            final label = '${cur.day.toString().padLeft(2, '0')}/${cur.month.toString().padLeft(2, '0')}';
            list.add(GanttPeriod(
              start: cur,
              end: endWeek,
              label: label,
              groupLabel: _getMonthFullName(DateTime(cur.year, cur.month)),
            ));
          }
          cur = endWeek;
        }
        break;
      }
      case GanttScale.biweekly: {
        var cur = _startOfWeek(startNorm);
        while (cur.isBefore(endNorm) || cur.isAtSameMomentAs(endNorm)) {
          final endBi = cur.add(const Duration(days: 14));
          if (endBi.isAfter(startNorm)) {
            final endLabel = endBi.subtract(const Duration(days: 1));
            final label = '${cur.day.toString().padLeft(2, '0')}/${cur.month.toString().padLeft(2, '0')}-${endLabel.day.toString().padLeft(2, '0')}/${endLabel.month.toString().padLeft(2, '0')}';
            list.add(GanttPeriod(
              start: cur,
              end: endBi,
              label: label,
              groupLabel: _getMonthFullName(DateTime(cur.year, cur.month)),
            ));
          }
          cur = endBi;
        }
        break;
      }
      case GanttScale.monthly: {
        var cur = DateTime(startNorm.year, startNorm.month, 1);
        while (cur.isBefore(endNorm) || cur.isAtSameMomentAs(endNorm)) {
          final endMonth = DateTime(cur.year, cur.month + 1, 1);
          final label = '${_monthNames[cur.month]} ${cur.year}';
          final q = (cur.month - 1) ~/ 3 + 1;
          list.add(GanttPeriod(
            start: cur,
            end: endMonth,
            label: label,
            groupLabel: 'T$q ${cur.year}',
          ));
          cur = endMonth;
        }
        break;
      }
      case GanttScale.quarterly: {
        var y = startNorm.year;
        var m = ((startNorm.month - 1) ~/ 3) * 3 + 1;
        var cur = DateTime(y, m, 1);
        if (cur.isBefore(startNorm)) {
          m += 3;
          if (m > 12) { m = 1; y++; }
          cur = DateTime(y, m, 1);
        }
        while (cur.isBefore(endNorm) || cur.isAtSameMomentAs(endNorm)) {
          final endQ = DateTime(cur.year, cur.month + 3, 1);
          final label = 'T${(cur.month - 1) ~/ 3 + 1} ${cur.year}';
          list.add(GanttPeriod(
            start: cur,
            end: endQ,
            label: label,
            groupLabel: '${cur.year}',
          ));
          m = cur.month + 3;
          y = cur.year;
          if (m > 12) { m = 1; y++; }
          cur = DateTime(y, m, 1);
        }
        break;
      }
      case GanttScale.semiAnnual: {
        var y = startNorm.year;
        var m = startNorm.month <= 6 ? 1 : 7;
        var cur = DateTime(y, m, 1);
        if (cur.isBefore(startNorm)) {
          cur = DateTime(y, 7, 1);
          if (startNorm.month > 6) cur = DateTime(y + 1, 1, 1);
        }
        while (cur.isBefore(endNorm) || cur.isAtSameMomentAs(endNorm)) {
          final endS = cur.month == 1 ? DateTime(y, 7, 1) : DateTime(y + 1, 1, 1);
          final label = 'S${cur.month == 1 ? 1 : 2} ${cur.year}';
          list.add(GanttPeriod(
            start: cur,
            end: endS,
            label: label,
            groupLabel: '${cur.year}',
          ));
          if (cur.month == 1) {
            cur = DateTime(y, 7, 1);
          } else {
            y++;
            cur = DateTime(y, 1, 1);
          }
        }
        break;
      }
    }
    return list;
  }

  int _getPeriodIndexForDate(DateTime date, List<GanttPeriod> periods) {
    final d = DateTime(date.year, date.month, date.day);
    for (int i = 0; i < periods.length; i++) {
      final p = periods[i];
      if (!d.isBefore(p.start) && d.isBefore(p.end)) return i;
    }
    if (periods.isEmpty) return 0;
    if (d.isBefore(periods.first.start)) return 0;
    return periods.length - 1;
  }

  double _getDateOffsetFromPeriods(DateTime date, List<GanttPeriod> periods, double periodWidth) {
    if (periods.isEmpty) return 0;
    final i = _getPeriodIndexForDate(date, periods);
    return i * periodWidth;
  }

  double _getTodayOffsetFromPeriods(DateTime today, List<GanttPeriod> periods, double periodWidth) {
    if (periods.isEmpty) return -1;
    final d = DateTime(today.year, today.month, today.day);
    if (d.isBefore(periods.first.start) || !d.isBefore(periods.last.end)) return -1;
    final i = _getPeriodIndexForDate(today, periods);
    return i * periodWidth;
  }

  /// Largura em pixels de um intervalo [startDate, endDate] na escala de períodos.
  double _getBarWidthForRange(DateTime startDate, DateTime endDate, List<GanttPeriod> periods, double periodWidth) {
    if (periods.isEmpty) return periodWidth;
    final startNorm = DateTime(startDate.year, startDate.month, startDate.day);
    final endNorm = DateTime(endDate.year, endDate.month, endDate.day);
    int i0 = _getPeriodIndexForDate(startNorm, periods);
    int i1 = _getPeriodIndexForDate(endNorm, periods);
    if (i0 > i1) i1 = i0;
    final span = (i1 - i0 + 1);
    final width = span * periodWidth;
    const padding = 0.5;
    return math.max(periodWidth * 0.5, width - periodWidth * padding);
  }

  // Funções para notificar quando um segmento está sendo arrastado
  void _onSegmentDragStart() {
    setState(() {
      _isSegmentBeingDragged = true;
    });
  }

  void _onSegmentDragEnd() {
    setState(() {
      _isSegmentBeingDragged = false;
    });
  }
}

// Widget para barras arrastáveis
class _DraggableSegment extends StatefulWidget {
  final Task task;
  final int segmentIndex;
  final GanttSegment segment;
  final DateTime normalizedStartDate;
  final DateTime normalizedEndDate;
  final double barWidth;
  final double dayWidth;
  final List<GanttPeriod> periods;
  final Color color;
  final Color textColor;
  final List<DateTime>? conflictDays;
  /// Mensagem completa do tooltip (todos os dias); usado quando não há mapa por dia.
  final String? conflictTooltipMessage;
  /// Tooltip por dia: ao passar o mouse no dia, mostra só os conflitos daquele dia.
  final Map<DateTime, String>? conflictTooltipMessageByDay;
  /// Dias de conflito de FROTA (exibição em preto com letras brancas).
  final List<DateTime>? conflictDaysFrota;
  final String? conflictTooltipMessageFrota;
  final Map<DateTime, String>? conflictTooltipMessageByDayFrota;
  final TaskService? taskService;
  final Function()? onTasksUpdated;
  final Function(Task)? onTaskUpdated;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;

  const _DraggableSegment({
    required this.task,
    required this.segmentIndex,
    required this.segment,
    required this.normalizedStartDate,
    required this.normalizedEndDate,
    required this.barWidth,
    required this.dayWidth,
    required this.periods,
    required this.color,
    this.textColor = Colors.white,
    this.conflictDays,
    this.conflictTooltipMessage,
    this.conflictTooltipMessageByDay,
    this.conflictDaysFrota,
    this.conflictTooltipMessageFrota,
    this.conflictTooltipMessageByDayFrota,
    this.taskService,
    this.onTasksUpdated,
    this.onTaskUpdated,
    this.onDragStart,
    this.onDragEnd,
  });

  @override
  State<_DraggableSegment> createState() => _DraggableSegmentState();
}

enum _DragMode { move, resizeStart, resizeEnd }

class _DraggableSegmentState extends State<_DraggableSegment> {
  double? _dragStartX;
  DateTime? _originalStartDate;
  DateTime? _originalEndDate;
  DateTime? _currentStartDate; // Data temporária durante o arrasto
  DateTime? _currentEndDate; // Data temporária durante o arrasto
  bool _isDragging = false;
  _DragMode? _dragMode;
  static const double _resizeHandleWidth =
      8.0; // Largura da área de redimensionamento
  OverlayEntry? _dayTooltipOverlay;

  @override
  void dispose() {
    _hideDayTooltipOverlay();
    super.dispose();
  }

  void _showDayTooltipOverlay(Offset global, String message) {
    _hideDayTooltipOverlay();
    const double tooltipMaxWidth = 320;
    const double gap = 12;
    // Posiciona à esquerda do cursor: borda direita do tooltip em (global.dx - gap)
    final left = (global.dx - tooltipMaxWidth - gap).clamp(8.0, global.dx - gap - 60);
    _dayTooltipOverlay = OverlayEntry(
      builder: (context) => Positioned(
        left: left,
        top: global.dy + 8,
        width: tooltipMaxWidth,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(4),
          color: Colors.grey[850],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_dayTooltipOverlay!);
  }

  void _hideDayTooltipOverlay() {
    _dayTooltipOverlay?.remove();
    _dayTooltipOverlay = null;
  }

  @override
  void didUpdateWidget(_DraggableSegment oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Só atualizar se o segmento realmente mudou (datas ou cor)
    // Ignorar mudanças em outras propriedades que não afetam a renderização visual
    final segmentChanged = oldWidget.segment.dataInicio != widget.segment.dataInicio ||
                           oldWidget.segment.dataFim != widget.segment.dataFim ||
                           oldWidget.color != widget.color;
    
    if (!_isDragging && segmentChanged) {
      // O segmento foi atualizado do banco, limpar datas temporárias
      setState(() {
        _currentStartDate = null;
        _currentEndDate = null;
      });
    }
  }

  _DragMode _getDragMode(double x) {
    if (x < _resizeHandleWidth) {
      return _DragMode.resizeStart; // Borda esquerda
    } else if (x > widget.barWidth - _resizeHandleWidth) {
      return _DragMode.resizeEnd; // Borda direita
    } else {
      return _DragMode.move; // Centro
    }
  }

  void _onPanStart(DragStartDetails details) {
    _hideDayTooltipOverlay();
    final dragMode = _getDragMode(details.localPosition.dx);
    setState(() {
      _dragStartX = details.localPosition.dx;
      _originalStartDate = widget.segment.dataInicio;
      _originalEndDate = widget.segment.dataFim;
      _isDragging = true;
      _dragMode = dragMode;
    });
    // Notificar o GanttChart que um segmento está sendo arrastado
    widget.onDragStart?.call();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_dragStartX == null || _dragMode == null || widget.taskService == null)
      return;

    final deltaX = details.localPosition.dx - _dragStartX!;
    // Calcular o delta em dias (pode ser fracionário)
    final daysDelta = deltaX / widget.dayWidth;
    
    // Para movimentação, só processar se houver mudança de pelo menos meio dia
    if (_dragMode == _DragMode.move && daysDelta.abs() < 0.5) return;
    
    // Para redimensionamento, processar quando houver qualquer movimento
    // Arredondar para o dia mais próximo
    int roundedDaysDelta;
    if (_dragMode == _DragMode.resizeStart || _dragMode == _DragMode.resizeEnd) {
      // Para redimensionamento, usar arredondamento mais sensível
      // Processar mesmo com movimentos pequenos (>= 0.2 dias)
      if (daysDelta.abs() >= 0.2) {
        roundedDaysDelta = daysDelta.round();
        // Se arredondado para 0 mas movimento >= 0.2, usar 1 ou -1
        if (roundedDaysDelta == 0) {
          roundedDaysDelta = daysDelta > 0 ? 1 : -1;
        }
      } else {
        // Movimento muito pequeno, não processar ainda
        return;
      }
    } else {
      roundedDaysDelta = daysDelta.round();
    }
    
    // Se ainda não houver mudança, não processar
    if (roundedDaysDelta == 0) return;

    DateTime? newStartDate = _originalStartDate;
    DateTime? newEndDate = _originalEndDate;

    switch (_dragMode!) {
      case _DragMode.move:
        // Mover a barra inteira
        newStartDate = _originalStartDate!.add(Duration(days: roundedDaysDelta));
        final duration = _originalEndDate!.difference(_originalStartDate!);
        newEndDate = newStartDate.add(duration);

        final minStart = widget.periods.isNotEmpty ? widget.periods.first.start : newStartDate;
        final maxEnd = widget.periods.isNotEmpty ? widget.periods.last.end : newEndDate;
        if (newStartDate.isBefore(minStart) || newEndDate.isAfter(maxEnd)) {
          return;
        }
        break;

      case _DragMode.resizeStart:
        newStartDate = _originalStartDate!.add(Duration(days: roundedDaysDelta));
        if (newStartDate.isAfter(_originalEndDate!)) {
          newStartDate = _originalEndDate!.subtract(const Duration(days: 1));
        }
        if (widget.periods.isNotEmpty && newStartDate.isBefore(widget.periods.first.start)) {
          newStartDate = widget.periods.first.start;
        }
        break;

      case _DragMode.resizeEnd:
        newEndDate = _originalEndDate!.add(Duration(days: roundedDaysDelta));
        if (newEndDate.isBefore(_originalStartDate!)) {
          newEndDate = _originalStartDate!.add(const Duration(days: 1));
        }
        if (widget.periods.isNotEmpty) {
          final maxDate = widget.periods.last.end;
          if (newEndDate.isAfter(maxDate)) {
            newEndDate = maxDate;
          }
        }
        break;
    }

    // Apenas atualizar visualmente durante o arrasto (não salvar no banco ainda)
    // Normalizar para manter apenas a data (evita horas/milisegundos que podem gerar +1 dia)
    DateTime normalizeDate(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

    setState(() {
      _currentStartDate = newStartDate != null ? normalizeDate(newStartDate) : null;
      _currentEndDate = newEndDate != null ? normalizeDate(newEndDate) : null;
    });
  }

  void _onPanEnd(DragEndDetails details) async {
    // Salvar no banco apenas quando o arrasto terminar
    if (_currentStartDate != null && _currentEndDate != null && widget.taskService != null) {
      // Normalizar antes de salvar para evitar desvio de um dia
      final normalizedStart = DateTime(_currentStartDate!.year, _currentStartDate!.month, _currentStartDate!.day);
      final normalizedEnd = DateTime(_currentEndDate!.year, _currentEndDate!.month, _currentEndDate!.day);
      // Verificar se é uma tarefa virtual (executor row)
      final isExecutorRow = widget.task.id.contains('_executor_');
      
      if (isExecutorRow) {
        // É uma tarefa virtual - salvar como ExecutorPeriod da tarefa principal
        // debug silenciado
        print('   - Tarefa virtual ID: ${widget.task.id}');
        print('   - SegmentIndex: ${widget.segmentIndex}');
        print('   - Data início: ${_currentStartDate}');
        print('   - Data fim: ${_currentEndDate}');
        
        // Extrair ID da tarefa principal e ID do executor do ID da tarefa virtual
        // Formato: {taskId}_executor_{executorId}
        final parts = widget.task.id.split('_executor_');
        if (parts.length != 2) {
          print('⚠️ Erro: ID da tarefa virtual inválido: ${widget.task.id}');
          return;
        }
        final mainTaskId = parts[0];
        final executorId = parts[1];
        
        print('   - Tarefa principal ID: $mainTaskId');
        print('   - Executor ID: $executorId');
        
        // Buscar a tarefa principal
        final mainTask = await widget.taskService!.getTaskById(mainTaskId);
        if (mainTask == null) {
          print('⚠️ Erro: Tarefa principal não encontrada: $mainTaskId');
          return;
        }
        
        // Atualizar o ExecutorPeriod correspondente
        final updatedExecutorPeriods = List<ExecutorPeriod>.from(mainTask.executorPeriods);
        final executorPeriodIndex = updatedExecutorPeriods.indexWhere(
          (ep) => ep.executorId == executorId,
        );
        
        if (executorPeriodIndex >= 0) {
          // Atualizar o período existente
          final executorPeriod = updatedExecutorPeriods[executorPeriodIndex];
          final updatedPeriods = List<GanttSegment>.from(executorPeriod.periods);
          
          if (widget.segmentIndex < updatedPeriods.length) {
            updatedPeriods[widget.segmentIndex] = GanttSegment(
              label: widget.segment.label,
              tipo: widget.segment.tipo,
              tipoPeriodo: widget.segment.tipoPeriodo,
              dataInicio: _currentStartDate!,
              dataFim: _currentEndDate!,
            );
            
            updatedExecutorPeriods[executorPeriodIndex] = ExecutorPeriod(
              executorId: executorPeriod.executorId,
              executorNome: executorPeriod.executorNome,
              periods: updatedPeriods,
            );
            
            print('   ✅ ExecutorPeriod atualizado: ${updatedPeriods.length} períodos');
          } else {
            print('⚠️ Erro: Índice de segmento inválido: ${widget.segmentIndex} (máx: ${updatedPeriods.length - 1})');
            return;
          }
        } else {
          print('⚠️ Erro: ExecutorPeriod não encontrado para executor: $executorId');
          return;
        }
        
        // Atualizar a tarefa principal
        final updatedTask = mainTask.copyWith(
          executorPeriods: updatedExecutorPeriods,
          dataAtualizacao: DateTime.now(),
        );
        
        // Salvar no banco
        await widget.taskService!.updateTask(mainTaskId, updatedTask);
        // debug silenciado
      } else {
        // É uma tarefa normal - salvar como ganttSegment
        final updatedSegments = List<GanttSegment>.from(widget.task.ganttSegments);
        updatedSegments[widget.segmentIndex] = GanttSegment(
          label: widget.segment.label,
          tipo: widget.segment.tipo,
          tipoPeriodo: widget.segment.tipoPeriodo, // Preservar tipoPeriodo
          dataInicio: normalizedStart,
          dataFim: normalizedEnd,
        );
        
        print('💾 GanttChart _onPanEnd: Salvando alterações do segmento');
        print('   - Tarefa ID: ${widget.task.id}');
        print('   - SegmentIndex: ${widget.segmentIndex}');
        print('   - Data início: ${_currentStartDate}');
        print('   - Data fim: ${_currentEndDate}');
        print('   - Tipo: ${widget.segment.tipo}');
        print('   - TipoPeríodo: ${widget.segment.tipoPeriodo}');

        // Atualizar a tarefa
        final updatedTask = widget.task.copyWith(
          ganttSegments: updatedSegments,
          // Ajustar dataInicio e dataFim da tarefa baseado nos segmentos
          dataInicio: updatedSegments
              .map((s) => s.dataInicio)
              .reduce((a, b) => a.isBefore(b) ? a : b),
          dataFim: updatedSegments
              .map((s) => s.dataFim)
              .reduce((a, b) => a.isAfter(b) ? a : b),
          dataAtualizacao: DateTime.now(),
        );

        // Salvar no banco apenas uma vez ao finalizar o arrasto
        final savedTask = await widget.taskService!.updateTask(widget.task.id, updatedTask);
        
        // Atualizar apenas a tarefa específica sem recarregar tudo
        if (savedTask != null) {
          widget.onTaskUpdated?.call(savedTask);
        } else {
          // Fallback: recarregar tudo se não conseguir atualizar a tarefa específica
          final onTasksUpdated = widget.onTasksUpdated;
          if (onTasksUpdated != null) {
            print('🔄 Fallback: Recarregando todas as tarefas após arrasto...');
            final result = onTasksUpdated();
            if (result is Future) {
              await result;
            }
          }
        }
      }
      
      // Manter as datas temporárias até que o widget seja atualizado com os novos dados
      // O didUpdateWidget irá limpar as datas temporárias quando detectar a atualização
    }

    // Limpar apenas o estado de arrasto, mas manter as datas temporárias
    // até que o widget seja atualizado com os novos dados do banco
    setState(() {
      _dragStartX = null;
      _originalStartDate = null;
      _originalEndDate = null;
      // NÃO limpar _currentStartDate e _currentEndDate aqui
      // Eles serão limpos pelo didUpdateWidget quando o segmento for atualizado
      _isDragging = false;
      _dragMode = null;
    });
    // Notificar o GanttChart que o arrasto do segmento terminou
    widget.onDragEnd?.call();
  }

  void _showContextMenu(BuildContext context, Offset position) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    showMenu<void>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 0, 0),
        Rect.fromLTWH(0, 0, overlay.size.width, overlay.size.height),
      ),
      items: [
        PopupMenuItem<void>(
          child: const Row(
            children: [
              Icon(Icons.content_copy, size: 20),
              SizedBox(width: 8),
              Text('Duplicar Período'),
            ],
          ),
          onTap: () {
            Future.delayed(const Duration(milliseconds: 100), () {
              _duplicatePeriod();
            });
          },
        ),
        PopupMenuItem<void>(
          child: const Row(
            children: [
              Icon(Icons.edit, size: 20),
              SizedBox(width: 8),
              Text('Editar Período'),
            ],
          ),
          onTap: () {
            Future.delayed(const Duration(milliseconds: 100), () {
              _showEditPeriodDialog(context);
            });
          },
        ),
        PopupMenuItem<void>(
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 20),
              SizedBox(width: 8),
              Text('Ver Detalhes'),
            ],
          ),
          onTap: () {
            Future.delayed(const Duration(milliseconds: 100), () {
              _showSegmentDetails(context);
            });
          },
        ),
        const PopupMenuDivider(),
        PopupMenuItem<void>(
          child: const Row(
            children: [
              Icon(Icons.delete_outline, size: 20, color: Colors.red),
              SizedBox(width: 8),
              Text('Excluir Período', style: TextStyle(color: Colors.red)),
            ],
          ),
          onTap: () {
            Future.delayed(const Duration(milliseconds: 100), () {
              _deletePeriod(context);
            });
          },
        ),
      ],
    );
  }

  void _duplicatePeriod() async {
    if (widget.taskService == null) {
      print('⚠️ TaskService é null, não é possível duplicar o segmento');
      return;
    }

    print('🔄 Duplicando segmento da tarefa ${widget.task.id}');
    print('   Segmento original: ${widget.segment.dataInicio} até ${widget.segment.dataFim}');
    print('   Segmentos atuais: ${widget.task.ganttSegments.length}');

    // Adicionar um novo segmento duplicado na mesma tarefa
    // Calcular a duração em dias (inclusive, contando o último dia)
    final duration = widget.segment.dataFim.difference(
      widget.segment.dataInicio,
    ).inDays + 1; // +1 para incluir o último dia
    
    print('   Duração calculada: $duration dias');
    
    // Normalizar a data de fim do segmento original para garantir consistência
    final normalizedEnd = DateTime(
      widget.segment.dataFim.year,
      widget.segment.dataFim.month,
      widget.segment.dataFim.day,
    );
    
    // O novo segmento começa 3 dias após o final do segmento original
    final newStart = normalizedEnd.add(const Duration(days: 3));
    // Normalizar a nova data de início (remover hora/minuto/segundo)
    final normalizedNewStart = DateTime(newStart.year, newStart.month, newStart.day);
    
    // O novo segmento termina após a mesma quantidade de dias (duração - 1 porque já incluímos o dia inicial)
    final newEnd = normalizedNewStart.add(Duration(days: duration - 1));
    // Normalizar a nova data de fim
    final normalizedNewEnd = DateTime(newEnd.year, newEnd.month, newEnd.day);

    // Criar novo segmento duplicado
    final newSegment = GanttSegment(
      label: widget.segment.label,
      tipo: widget.segment.tipo,
      tipoPeriodo: widget.segment.tipoPeriodo, // Herdar tipo de período
      dataInicio: normalizedNewStart,
      dataFim: normalizedNewEnd,
    );

    print('   Novo segmento criado: ${normalizedNewStart} até ${normalizedNewEnd}');

    // Adicionar o novo segmento à lista de segmentos da tarefa
    final updatedSegments = List<GanttSegment>.from(widget.task.ganttSegments);
    updatedSegments.add(newSegment);
    
    print('   Total de segmentos após adicionar: ${updatedSegments.length}');

    // Atualizar a tarefa com o novo segmento
    final updatedTask = widget.task.copyWith(
      ganttSegments: updatedSegments,
      // Ajustar dataInicio e dataFim da tarefa baseado em todos os segmentos
      dataInicio: updatedSegments
          .map((s) => s.dataInicio)
          .reduce((a, b) => a.isBefore(b) ? a : b),
      dataFim: updatedSegments
          .map((s) => s.dataFim)
          .reduce((a, b) => a.isAfter(b) ? a : b),
      dataAtualizacao: DateTime.now(),
    );

    // Aguardar a atualização no banco
    print('💾 Salvando tarefa atualizada no banco...');
    final savedTask = await widget.taskService!.updateTask(widget.task.id, updatedTask);
    
    if (savedTask != null) {
      // debug silenciado
    } else {
      print('⚠️ Erro ao salvar tarefa no banco');
    }
    
    // Atualizar apenas a tarefa específica sem recarregar tudo
    if (savedTask != null) {
      widget.onTaskUpdated?.call(savedTask);
    } else {
      // Fallback: recarregar tudo se não conseguir atualizar a tarefa específica
      final onTasksUpdated = widget.onTasksUpdated;
      if (onTasksUpdated != null) {
        print('🔄 Fallback: Recarregando todas as tarefas...');
        final result = onTasksUpdated();
        if (result is Future) {
          await result;
        }
      }
    }

    // Mostrar mensagem de sucesso
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Período duplicado adicionado à tarefa "${widget.task.tarefa}"!',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showEditPeriodDialog(BuildContext context) {
    DateTime newStart = widget.segment.dataInicio;
    DateTime newEnd = widget.segment.dataFim;
    // Normalizar o tipo para garantir que seja um código válido
    String selectedTipo = widget.segment.tipo.toUpperCase().trim();
    const validSegmentTypes = ['BEA', 'FER', 'COMP', 'TRN', 'BSL', 'APO', 'OUT', 'ADM'];
    if (!validSegmentTypes.contains(selectedTipo)) {
      print('⚠️ Tipo inválido no segmento: "$selectedTipo" -> usando "OUT"');
      selectedTipo = 'OUT';
    }
    
    // Tipo de período
    String selectedTipoPeriodo = widget.segment.tipoPeriodo.toUpperCase().trim();
    const validPeriodTypes = ['EXECUCAO', 'PLANEJAMENTO', 'DESLOCAMENTO'];
    if (!validPeriodTypes.contains(selectedTipoPeriodo)) {
      selectedTipoPeriodo = 'EXECUCAO';
    }

    // Tipos válidos de segmento com descrições
    final tiposSegmento = [
      {'codigo': 'BEA', 'descricao': 'BEA'},
      {'codigo': 'FER', 'descricao': 'Ferramenta'},
      {'codigo': 'COMP', 'descricao': 'Componente'},
      {'codigo': 'TRN', 'descricao': 'Linha de Transmissão'},
      {'codigo': 'BSL', 'descricao': 'Baseline'},
      {'codigo': 'APO', 'descricao': 'Apoio'},
      {'codigo': 'ADM', 'descricao': 'Administrativo'},
      {'codigo': 'OUT', 'descricao': 'Outros'},
    ];
    
    // Tipos de período
    final tiposPeriodo = [
      {'codigo': 'EXECUCAO', 'descricao': 'Execução'},
      {'codigo': 'PLANEJAMENTO', 'descricao': 'Planejamento'},
      {'codigo': 'DESLOCAMENTO', 'descricao': 'Deslocamento'},
    ];

    print('📋 _showEditPeriodDialog:');
    print('   Tipo original do segmento: ${widget.segment.tipo}');
    print('   Tipo normalizado: $selectedTipo');
    print('   Label: ${widget.segment.label}');
    print('   Data início: ${widget.segment.dataInicio.toString().substring(0, 10)}');
    print('   Data fim: ${widget.segment.dataFim.toString().substring(0, 10)}');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Editar Período'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Segmento: ${widget.segment.label}'),
                const SizedBox(height: 16),
                // Dropdown para selecionar o tipo
                DropdownButtonFormField<String>(
                  value: selectedTipo,
                  decoration: const InputDecoration(
                    labelText: 'Tipo do Segmento',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: tiposSegmento.map((tipo) {
                    return DropdownMenuItem<String>(
                      value: tipo['codigo'] as String,
                      child: Text('${tipo['codigo']} - ${tipo['descricao']}'),
                    );
                  }).toList(),
                  onChanged: (String? value) {
                    if (value != null) {
                      setDialogState(() {
                        selectedTipo = value;
                        print('📋 Tipo selecionado no dropdown: $selectedTipo');
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                // Dropdown para selecionar o tipo de período
                DropdownButtonFormField<String>(
                  value: selectedTipoPeriodo,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de Período',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: tiposPeriodo.map((tipo) {
                    return DropdownMenuItem<String>(
                      value: tipo['codigo'] as String,
                      child: Text('${tipo['codigo']} - ${tipo['descricao']}'),
                    );
                  }).toList(),
                  onChanged: (String? value) {
                    if (value != null) {
                      setDialogState(() {
                        selectedTipoPeriodo = value;
                        // Se mudou para DESLOCAMENTO, fazer data fim igual à data início
                        if (value == 'DESLOCAMENTO') {
                          newEnd = newStart;
                        }
                        print('📋 Tipo de período selecionado: $selectedTipoPeriodo');
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                // Para EXECUCAO e PLANEJAMENTO: usar DateRangePicker
                // Para DESLOCAMENTO: usar dois DatePickers separados (ida e volta)
                if (selectedTipoPeriodo == 'EXECUCAO' || selectedTipoPeriodo == 'PLANEJAMENTO')
                  ListTile(
                    title: const Text('Período'),
                    subtitle: Text(
                      '${newStart.day}/${newStart.month}/${newStart.year} - ${newEnd.day}/${newEnd.month}/${newEnd.year}',
                    ),
                    trailing: const Icon(Icons.date_range),
                    onTap: () async {
                      final dateRange = await showDateRangePicker(
                        context: context,
                        initialDateRange: DateTimeRange(start: newStart, end: newEnd),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        helpText: 'Selecione o período',
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.light(
                                primary: Colors.blue,
                                onPrimary: Colors.white,
                                surface: Colors.white,
                                onSurface: Colors.black,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (dateRange != null) {
                        setDialogState(() {
                          newStart = dateRange.start;
                          newEnd = dateRange.end;
                        });
                      }
                    },
                  )
                else
                  // Para DESLOCAMENTO: dois campos separados (ida e volta)
                  Column(
                    children: [
                      ListTile(
                        title: const Text('Data de Ida'),
                        subtitle: Text(
                          '${newStart.day}/${newStart.month}/${newStart.year}',
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: newStart,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (date != null) {
                            setDialogState(() {
                              newStart = date;
                            });
                          }
                        },
                      ),
                      ListTile(
                        title: const Text('Data de Volta'),
                        subtitle: Text(
                          '${newEnd.day}/${newEnd.month}/${newEnd.year}',
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: newEnd,
                            firstDate: newStart,
                            lastDate: DateTime(2030),
                          );
                          if (date != null) {
                            setDialogState(() {
                              newEnd = date;
                              if (newEnd.isBefore(newStart)) {
                                newStart = newEnd.subtract(const Duration(days: 1));
                              }
                            });
                          }
                        },
                      ),
                    ],
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (widget.taskService == null) return;

                // debug silenciado
                print('   Tarefa ID: ${widget.task.id}');
                print('   Índice do segmento: ${widget.segmentIndex}');
                print('   Tipo selecionado no dropdown: $selectedTipo');
                print('   Tipo de período selecionado: $selectedTipoPeriodo');
                print('   Tipo original do segmento: ${widget.segment.tipo}');
                print('   Tipo de período original: ${widget.segment.tipoPeriodo}');
                print('   Data início: $newStart');
                print('   Data fim: $newEnd');
                print('   Label: ${widget.segment.label}');

                // Validar o tipo selecionado
                const validSegmentTypes = ['BEA', 'FER', 'COMP', 'TRN', 'BSL', 'APO', 'OUT', 'ADM'];
                final tipoFinal = validSegmentTypes.contains(selectedTipo.toUpperCase().trim()) 
                    ? selectedTipo.toUpperCase().trim() 
                    : 'OUT';
                
                // Validar o tipo de período
                const validPeriodTypes = ['EXECUCAO', 'PLANEJAMENTO', 'DESLOCAMENTO'];
                final tipoPeriodoFinal = validPeriodTypes.contains(selectedTipoPeriodo.toUpperCase().trim())
                    ? selectedTipoPeriodo.toUpperCase().trim()
                    : 'EXECUCAO';
                
                if (tipoFinal != selectedTipo.toUpperCase().trim()) {
                  print('⚠️ Tipo inválido "$selectedTipo" -> usando "$tipoFinal"');
                }
                
                if (tipoPeriodoFinal != selectedTipoPeriodo.toUpperCase().trim()) {
                  print('⚠️ Tipo de período inválido "$selectedTipoPeriodo" -> usando "$tipoPeriodoFinal"');
                }

                // Se for deslocamento, garantir que data fim seja igual à data início
                final finalDataFim = tipoPeriodoFinal == 'DESLOCAMENTO' ? newStart : newEnd;
                
                // Atualizar o segmento com o tipo selecionado
                final updatedSegments = List<GanttSegment>.from(
                  widget.task.ganttSegments,
                );
                updatedSegments[widget.segmentIndex] = GanttSegment(
                  label: widget.segment.label,
                  tipo: tipoFinal, // Usar o tipo validado
                  tipoPeriodo: tipoPeriodoFinal, // Usar o tipo de período validado
                  dataInicio: newStart,
                  dataFim: finalDataFim, // Para deslocamento, será igual à data início
                );

                print('   ✅ Segmento atualizado na lista:');
                print('      tipo=${updatedSegments[widget.segmentIndex].tipo}');
                print('      tipoPeriodo=${updatedSegments[widget.segmentIndex].tipoPeriodo}');
                print('      dataInicio=${updatedSegments[widget.segmentIndex].dataInicio.toString().substring(0, 10)}');
                print('      dataFim=${updatedSegments[widget.segmentIndex].dataFim.toString().substring(0, 10)}');
                print('      label=${updatedSegments[widget.segmentIndex].label}');

                // Atualizar a tarefa
                final updatedTask = widget.task.copyWith(
                  ganttSegments: updatedSegments,
                  dataInicio: updatedSegments
                      .map((s) => s.dataInicio)
                      .reduce((a, b) => a.isBefore(b) ? a : b),
                  dataFim: updatedSegments
                      .map((s) => s.dataFim)
                      .reduce((a, b) => a.isAfter(b) ? a : b),
                  dataAtualizacao: DateTime.now(),
                );

                print('   📤 Enviando tarefa atualizada para TaskService:');
                print('      Tarefa ID: ${updatedTask.id}');
                // debug silenciado
                for (var seg in updatedTask.ganttSegments) {
                  print('        - tipo: ${seg.tipo}, início: ${seg.dataInicio.toString().substring(0, 10)}, fim: ${seg.dataFim.toString().substring(0, 10)}');
                }

                // Aguardar a atualização no banco
                final savedTask = await widget.taskService!.updateTask(widget.task.id, updatedTask);
                
                if (savedTask != null) {
                  print('   ✅ Tarefa salva com sucesso!');
                  print('      Segmentos salvos: ${savedTask.ganttSegments.length}');
                  for (var seg in savedTask.ganttSegments) {
                    print('        - tipo: ${seg.tipo}, início: ${seg.dataInicio.toString().substring(0, 10)}, fim: ${seg.dataFim.toString().substring(0, 10)}');
                  }
                  // Atualizar apenas a tarefa específica sem recarregar tudo
                  widget.onTaskUpdated?.call(savedTask);
                } else {
                  print('   ❌ Erro ao salvar tarefa');
                  // Fallback: recarregar tudo se não conseguir atualizar
                  widget.onTasksUpdated?.call();
                }

                Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Período atualizado com sucesso!'),
                    ),
                  );
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSegmentDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.segment.label),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDetailRow('Tarefa', widget.task.tarefa),
            _buildDetailRow('Tipo', widget.segment.tipo),
            _buildDetailRow(
              'Início',
              '${widget.segment.dataInicio.day}/${widget.segment.dataInicio.month}/${widget.segment.dataInicio.year}',
            ),
            _buildDetailRow(
              'Fim',
              '${widget.segment.dataFim.day}/${widget.segment.dataFim.month}/${widget.segment.dataFim.year}',
            ),
            _buildDetailRow(
              'Duração',
              '${widget.segment.dataFim.difference(widget.segment.dataInicio).inDays + 1} dias',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  void _deletePeriod(BuildContext context) {
    // Verificar se há mais de um segmento (não permitir excluir o último)
    if (widget.task.ganttSegments.length <= 1) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não é possível excluir o último período da tarefa!'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // Confirmar exclusão
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text(
          'Deseja realmente excluir o período "${widget.segment.label}"?\n\n'
          'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmDeletePeriod();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePeriod() async {
    if (widget.taskService == null) {
      print('⚠️ TaskService é null, não é possível excluir o segmento');
      return;
    }

    print('🗑️ Excluindo segmento ${widget.segmentIndex} da tarefa ${widget.task.id}');
    print('   Segmento a excluir: ${widget.segment.dataInicio} até ${widget.segment.dataFim}');
    print('   Segmentos atuais: ${widget.task.ganttSegments.length}');

    // Remover apenas o segmento específico da lista (exclusão independente)
    final updatedSegments = List<GanttSegment>.from(widget.task.ganttSegments);
    updatedSegments.removeAt(widget.segmentIndex);

    print('   Segmentos após exclusão: ${updatedSegments.length}');

    // Se não houver mais segmentos, não fazer nada (já foi validado antes)
    if (updatedSegments.isEmpty) {
      print('⚠️ Não há mais segmentos após exclusão');
      return;
    }

    // Atualizar a tarefa apenas removendo o segmento, sem recalcular datas
    // A exclusão é independente - não afeta outros segmentos ou as datas da tarefa
    final updatedTask = widget.task.copyWith(
      ganttSegments: updatedSegments,
      // Manter as datas originais da tarefa - não recalcular baseado nos segmentos
      // Isso garante que a exclusão seja independente
      dataAtualizacao: DateTime.now(),
    );

    print('💾 Salvando tarefa atualizada no banco...');
    // Aguardar a atualização no banco
    final savedTask = await widget.taskService!.updateTask(widget.task.id, updatedTask);
    
    if (savedTask != null) {
      // debug silenciado
    } else {
      print('⚠️ Erro ao salvar tarefa no banco');
    }
    
    // Atualizar apenas a tarefa específica sem recarregar tudo
    if (savedTask != null) {
      widget.onTaskUpdated?.call(savedTask);
    } else {
      // Fallback: recarregar tudo se não conseguir atualizar a tarefa específica
      final onTasksUpdated = widget.onTasksUpdated;
      if (onTasksUpdated != null) {
        print('🔄 Fallback: Recarregando todas as tarefas...');
        final result = onTasksUpdated();
        if (result is Future) {
          await result;
        }
      }
    }

    // Mostrar mensagem de sucesso
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Período "${widget.segment.label}" excluído com sucesso!',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }


  int _getPeriodIndexForDate(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    for (int i = 0; i < widget.periods.length; i++) {
      final p = widget.periods[i];
      if (!d.isBefore(p.start) && d.isBefore(p.end)) return i;
    }
    if (widget.periods.isEmpty) return 0;
    if (d.isBefore(widget.periods.first.start)) return 0;
    return widget.periods.length - 1;
  }

  bool _periodOverlapsConflict(GanttPeriod p, List<DateTime> conflictDays) {
    for (final d in conflictDays) {
      final day = DateTime(d.year, d.month, d.day);
      if (!day.isBefore(p.start) && day.isBefore(p.end)) return true;
    }
    return false;
  }

  double _getOffsetForDate(DateTime date) {
    if (widget.periods.isEmpty) return 0;
    final i = _getPeriodIndexForDate(date);
    return i * widget.dayWidth;
  }

  double _getBarWidthForRange(DateTime start, DateTime end) {
    if (widget.periods.isEmpty) return widget.dayWidth;
    final dStart = DateTime(start.year, start.month, start.day);
    final dEnd = DateTime(end.year, end.month, end.day);
    int i0 = _getPeriodIndexForDate(dStart);
    int i1 = _getPeriodIndexForDate(dEnd);
    if (i0 > i1) i1 = i0;
    const padding = 0.5;
    return math.max(widget.dayWidth * 0.5, (i1 - i0 + 1) * widget.dayWidth - widget.dayWidth * padding);
  }

  double _getCurrentBarWidth() {
    if (_currentStartDate != null && _currentEndDate != null) {
      return _getBarWidthForRange(_currentStartDate!, _currentEndDate!);
    }
    return widget.barWidth;
  }

  double _getCurrentOffset() {
    if (_currentStartDate != null) {
      final newStartOffset = _getOffsetForDate(_currentStartDate!);
      final originalStartOffset = _getOffsetForDate(widget.segment.dataInicio);
      return newStartOffset - originalStartOffset;
    }
    return 0.0;
  }
  
  // Método para construir o conteúdo do segmento (texto ou ícone).
  // segmentTextColorOverride: quando conflito de frota (preto), usar branco.
  Widget _buildSegmentContent(double barWidth, {Color? segmentTextColorOverride}) {
    final textColor = segmentTextColorOverride ?? widget.textColor;
    final tipoPeriodo = widget.segment.tipoPeriodo.toUpperCase();
    
    // Para PLANEJAMENTO e DESLOCAMENTO: mostrar ícone
    if (tipoPeriodo == 'PLANEJAMENTO' || tipoPeriodo == 'DESLOCAMENTO') {
      IconData iconData;
      if (tipoPeriodo == 'PLANEJAMENTO') {
        iconData = Icons.calendar_today; // Ícone para planejamento
      } else {
        iconData = Icons.directions_car; // Ícone para deslocamento
      }
      
      return Icon(
        iconData,
        color: textColor,
        size: _getOptimalFontSize(barWidth) * 1.5,
        shadows: [
          Shadow(
            offset: const Offset(0.5, 0.5),
            blurRadius: 1.0,
            color: Colors.black.withOpacity(0.5),
          ),
        ],
      );
    }
    
    // Para EXECUCAO: mostrar texto (local e tarefa)
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Linha 1: Local
        if (widget.task.locais.isNotEmpty)
          Text(
            _getTruncatedText(
              widget.task.locais.join(', '),
              barWidth,
            ),
            style: TextStyle(
              color: textColor,
              fontSize: _getOptimalFontSize(barWidth),
              fontWeight: FontWeight.normal,
              shadows: [
                Shadow(
                  offset: const Offset(0.5, 0.5),
                  blurRadius: 1.0,
                  color: Colors.black.withOpacity(0.5),
                ),
              ],
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            textAlign: TextAlign.center,
          ),
        // Linha 2: Tarefa
        if (widget.task.tarefa.isNotEmpty)
          Text(
            _getTruncatedText(
              widget.task.tarefa,
              barWidth,
            ),
            style: TextStyle(
              color: textColor,
              fontSize: _getOptimalFontSize(barWidth),
              fontWeight: FontWeight.normal,
              shadows: [
                Shadow(
                  offset: const Offset(0.5, 0.5),
                  blurRadius: 1.0,
                  color: Colors.black.withOpacity(0.5),
                ),
              ],
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            textAlign: TextAlign.center,
          ),
      ],
    );
  }
  
  String _getTruncatedText(String text, double barWidth) {
    // Considerar padding (8px total) e espaço mínimo para legibilidade
    final availableWidth = barWidth - 8;
    
    if (availableWidth < 20) {
      return '';
    }
    
    // Calcular máximo de caracteres (~5px por caractere)
    final maxChars = (availableWidth / 5).floor();
    
    if (text.length > maxChars) {
      return '${text.substring(0, maxChars - 3)}...';
    }
    
    return text;
  }

  double _getOptimalFontSize(double barWidth) {
    if (barWidth < 50) return 7.0;
    if (barWidth < 80) return 8.0;
    if (barWidth < 120) return 9.0;
    if (barWidth < 180) return 10.0;
    return 11.0;
  }

  String _getExecutorLabelForConflictTooltip() {
    final t = widget.task;
    if (t.executor.trim().isNotEmpty) return t.executor.trim();
    if (t.executores.isNotEmpty) {
      return t.executores.map((e) => e.trim()).where((e) => e.isNotEmpty).join(', ');
    }
    if (t.executorPeriods.isNotEmpty) {
      return t.executorPeriods.map((ep) => ep.executorNome.trim()).where((e) => e.isNotEmpty).join(', ');
    }
    return 'Executor(es) desta tarefa';
  }

  @override
  Widget build(BuildContext context) {
    final isResizing =
        _dragMode == _DragMode.resizeStart || _dragMode == _DragMode.resizeEnd;
    final cursorType =
        _dragMode == _DragMode.resizeStart || _dragMode == _DragMode.resizeEnd
        ? SystemMouseCursors.resizeLeftRight
        : SystemMouseCursors.move;

    final currentBarWidth = _getCurrentBarWidth();
    final currentOffset = _getCurrentOffset();
    final effectiveStartDate = _currentStartDate ?? widget.normalizedStartDate;
    final effectiveEndDate = _currentEndDate ?? widget.normalizedEndDate;
    // Tornar o fim inclusivo para que o último dia seja renderizado
    final effectiveEndDateExclusive = DateTime(
      effectiveEndDate.year,
      effectiveEndDate.month,
      effectiveEndDate.day,
    ).add(const Duration(days: 1));
    final segmentPeriods = widget.periods.where((p) {
      return effectiveStartDate.isBefore(p.end) &&
          effectiveEndDateExclusive.isAfter(p.start);
    }).toList();
    return Transform.translate(
      offset: Offset(currentOffset, 0),
      child: MouseRegion(
        cursor: _isDragging ? cursorType : SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          onLongPress: () {
            final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
            if (renderBox != null) {
              final position = renderBox.localToGlobal(
                Offset(renderBox.size.width / 2, renderBox.size.height / 2),
              );
              _showContextMenu(context, position);
            }
          },
          child: _buildSegmentStack(segmentPeriods, currentBarWidth, isResizing),
        ),
      ),
    );
  }

  Widget _buildSegmentStack(List<GanttPeriod> segmentPeriods, double currentBarWidth, bool isResizing) {
    final hasConflict = widget.conflictDays != null && widget.conflictDays!.isNotEmpty;
    final hasConflictFrota = widget.conflictDaysFrota != null && widget.conflictDaysFrota!.isNotEmpty;
    final tooltipMessage = widget.conflictTooltipMessage?.isNotEmpty == true
        ? widget.conflictTooltipMessage!
        : (hasConflict
            ? 'Conflito de agenda nos dias em vermelho.\nExecutor(es) em conflito: ${_getExecutorLabelForConflictTooltip()}'
            : '');
    final tooltipMessageFrota = widget.conflictTooltipMessageFrota ?? (hasConflictFrota ? 'Conflito de frota nos dias em preto.' : '');
    final usePerDayTooltip = (widget.conflictTooltipMessageByDay != null && widget.conflictTooltipMessageByDay!.isNotEmpty) ||
        (widget.conflictTooltipMessageByDayFrota != null && widget.conflictTooltipMessageByDayFrota!.isNotEmpty);

    final stack = Stack(
      children: [
        Row(
          children: segmentPeriods.map((p) {
            final isConflictDayFrota = widget.conflictDaysFrota != null &&
                _periodOverlapsConflict(p, widget.conflictDaysFrota!);
            final isConflictDay = widget.conflictDays != null &&
                _periodOverlapsConflict(p, widget.conflictDays!);
            final Color cellColor;
            if (isConflictDayFrota) {
              cellColor = Colors.black;
            } else if (isConflictDay) {
              cellColor = Colors.red[600]!;
            } else {
              cellColor = _isDragging ? widget.color.withOpacity(0.7) : widget.color;
            }
            final cell = Container(
              width: widget.dayWidth,
              height: 48.0,
              decoration: BoxDecoration(
                color: cellColor,
                borderRadius: BorderRadius.circular(2),
              ),
            );
            return cell;
          }).toList(),
        ),
        Center(
          child: Container(
            width: currentBarWidth - 1,
            height: 48.0,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(2),
              border: _isDragging
                  ? Border.all(
                      color: isResizing ? Colors.orange : Colors.blue,
                      width: 2,
                    )
                  : null,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3.0, vertical: 1.0),
                child: currentBarWidth < 40
                    ? const SizedBox.shrink()
                    : _buildSegmentContent(
                        currentBarWidth,
                        segmentTextColorOverride: hasConflictFrota ? Colors.white : null,
                      ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: _resizeHandleWidth,
          child: Container(
            color: Colors.transparent,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeLeftRight,
              child: Container(),
            ),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: _resizeHandleWidth,
          child: Container(
            color: Colors.transparent,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeLeftRight,
              child: Container(),
            ),
          ),
        ),
        if (!_isDragging) ...[
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 2,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(2),
                  bottomLeft: Radius.circular(2),
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 2,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(2),
                  bottomRight: Radius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ],
    );

    final combinedTooltip = [if (hasConflict && tooltipMessage.isNotEmpty) tooltipMessage, if (hasConflictFrota && tooltipMessageFrota.isNotEmpty) tooltipMessageFrota].join('\n\n');
    if ((hasConflict || hasConflictFrota) && combinedTooltip.isNotEmpty && !usePerDayTooltip) {
      return Tooltip(
        message: combinedTooltip,
        preferBelow: false,
        child: stack,
      );
    }
    if (usePerDayTooltip) {
      return MouseRegion(
        onHover: (event) {
          final i = (event.localPosition.dx / widget.dayWidth).floor();
          final idx = i.clamp(0, segmentPeriods.length - 1);
          if (idx >= 0 && idx < segmentPeriods.length) {
            final p = segmentPeriods[idx];
            final day = DateTime(p.start.year, p.start.month, p.start.day);
            final msgExec = widget.conflictTooltipMessageByDay?[day];
            final msgFrota = widget.conflictTooltipMessageByDayFrota?[day];
            final parts = [if (msgExec != null && msgExec.isNotEmpty) msgExec, if (msgFrota != null && msgFrota.isNotEmpty) msgFrota];
            if (parts.isNotEmpty) {
              _showDayTooltipOverlay(event.position, parts.join('\n\n'));
              return;
            }
          }
          _hideDayTooltipOverlay();
        },
        onExit: (_) => _hideDayTooltipOverlay(),
        child: stack,
      );
    }
    return stack;
  }
}
