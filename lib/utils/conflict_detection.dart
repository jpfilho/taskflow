import 'package:flutter/material.dart';

import '../models/task.dart';

/// Evento diário de execução: um executor está alocado a uma tarefa em um local em um dia com horário.
/// Conflito = dois ou mais eventos no mesmo (executor, dia) com locais distintos e sobreposição de horário.
class ExecutionEvent {
  final String executorId;
  final DateTime day;
  final String locationKey;
  final String taskId;
  final String description;
  final DateTime? startTime;
  final DateTime? endTime;

  const ExecutionEvent({
    required this.executorId,
    required this.day,
    required this.locationKey,
    required this.taskId,
    required this.description,
    this.startTime,
    this.endTime,
  });
}

/// Lógica única de conflito de agenda: normalizar tarefas em eventos diários de execução por executor.
/// Conflito existe quando, para o mesmo (executor, dia), há dois ou mais locais distintos.
///
/// Prioridade para "tem EXECUÇÃO nesse dia para esse executor":
/// executorPeriods da tarefa → executorPeriods do pai → filhos → ganttSegments.
class ConflictDetection {
  ConflictDetection._();

  /// Tarefas canceladas, reprogramadas ou dos tipos ADMIN/ADM/REUNIAO não entram na detecção nem no tooltip.
  static bool isTaskExcludedFromConflict(Task task) {
    final tipo = task.tipo.trim().toUpperCase();
    if (tipo == 'ADMIN' || tipo == 'ADM' || tipo == 'REUNIAO') return true;

    final cod = task.status.trim().toUpperCase();
    final nome = task.statusNome.trim().toUpperCase();
    if (cod.isEmpty && nome.isEmpty) return false;
    if (cod == 'CANC' || cod == 'RPGR' || cod == 'REPR' || cod == 'RPAR') {
      return true;
    }
    if (cod == 'REPROGRAMADA' || cod == 'CANCELADA' || cod == 'CANCELADO') {
      return true;
    }
    if (nome.contains('CANCELAD') || nome.contains('REPROGRAMAD')) return true;
    if (cod.contains('RPGR') || cod.contains('REPR') || cod.contains('CANC')) {
      return true;
    }
    return false;
  }

  static String _normalizeExecutorKey(String s) {
    if (s.isEmpty) return '';
    var t = s.trim().toLowerCase();
    const withDiacritics = 'áàâãäåçéèêëíìîïñóòôõöúùûüýÿ';
    const without = 'aaaaaaceeeeiiiinooooouuuuyy';
    for (var i = 0; i < withDiacritics.length && i < without.length; i++) {
      t = t.replaceAll(withDiacritics[i], without[i]);
    }
    return t.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static String taskLocationKey(Task task) {
    if (task.localIds.isNotEmpty) return task.localIds.join('|');
    if (task.localId != null && task.localId!.isNotEmpty) return task.localId!;
    if (task.locais.isNotEmpty) return task.locais.join('|');
    return '';
  }

  static final _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static bool _executorPeriodMatches(
    ExecutorPeriod ep,
    String executorIdOrName,
  ) {
    if (ep.executorId.isNotEmpty && _uuidRegex.hasMatch(executorIdOrName)) {
      return ep.executorId == executorIdOrName;
    }
    final key = _normalizeExecutorKey(executorIdOrName);
    if (key.isEmpty) return false;
    return _normalizeExecutorKey(ep.executorId) == key ||
        _normalizeExecutorKey(ep.executorNome) == key;
  }

  static bool _taskInvolvesExecutor(Task task, String executorId) {
    final hasStructuredIds = task.executorIds.any((id) => id.trim().isNotEmpty) ||
        task.executorPeriods.any((ep) => ep.executorId.trim().isNotEmpty);

    if (hasStructuredIds) {
      if (task.executorIds.contains(executorId)) return true;
      return task.executorPeriods.any((ep) => ep.executorId == executorId);
    }

    final executorKeyNorm = _normalizeExecutorKey(executorId);
    final executorNamesNorm = task.executor
        .split(',')
        .map((s) => _normalizeExecutorKey(s))
        .where((s) => s.isNotEmpty)
        .toSet();
    final executoresNorm = task.executores
        .map((e) => _normalizeExecutorKey(e))
        .where((e) => e.isNotEmpty)
        .toSet();
    return executorNamesNorm.contains(executorKeyNorm) ||
        executoresNorm.contains(executorKeyNorm) ||
        task.executorPeriods.any(
          (ep) => _executorPeriodMatches(ep, executorId),
        );
  }

  /// Retorna true se [dayStart..dayEnd) intercepta [periodStart..periodEnd] (EXECUÇÃO).
  static bool _overlapsDay(
    DateTime periodStart,
    DateTime periodEnd,
    DateTime dayStart,
    DateTime dayEnd,
  ) {
    return periodStart.isBefore(dayEnd) && !periodEnd.isBefore(dayStart);
  }

  /// Instrumentação temporária: listar tarefas que geram ExecutionEvent para EDMUNDO no dia 07 e a fonte.
  /// Desligar após confirmar que TSD não gera evento para EDMUNDO no dia 07.
  static const bool _debugDay07Edmundo = true;

  /// Retorna os intervalos efetivos de execução no dia para o executor.
  static List<DateTimeRange> getExecutionIntervalsOnDayForExecutor(
    Task task,
    String executorId,
    DateTime dayStart,
    DateTime dayEnd,
    List<Task> allTasks, {
    List<String>? debugSourceOut,
  }) {
    DateTimeRange clampPeriodToDay(DateTime start, DateTime end) {
      if (start.hour == 0 && start.minute == 0 && end.hour == 0 && end.minute == 0) {
        return DateTimeRange(
          start: dayStart,
          end: dayEnd.subtract(const Duration(milliseconds: 1)),
        );
      }
      final s = start.isAfter(dayStart) ? start : dayStart;
      final e = end.isBefore(dayEnd) ? end : dayEnd.subtract(const Duration(milliseconds: 1));
      return DateTimeRange(start: s, end: e.isBefore(s) ? s : e);
    }

    final intervals = <DateTimeRange>[];

    // 1. executorPeriods da PRÓPRIA tarefa
    if (task.executorPeriods.isNotEmpty) {
      ExecutorPeriod? epForExecutor;
      for (final ep in task.executorPeriods) {
        if (_executorPeriodMatches(ep, executorId)) {
          epForExecutor = ep;
          break;
        }
      }
      if (epForExecutor == null) return intervals;
      for (final period in epForExecutor.periods) {
        if (period.tipoPeriodo.toUpperCase() != 'EXECUCAO') continue;
        if (_overlapsDay(period.dataInicio, period.dataFim, dayStart, dayEnd)) {
          debugSourceOut?.add('executorPeriods_tarefa');
          intervals.add(clampPeriodToDay(period.dataInicio, period.dataFim));
        }
      }
      return intervals;
    }

    // 2. Subtarefa: executorPeriods do PAI
    if (task.parentId != null) {
      Task? parent;
      for (final t in allTasks) {
        if (t.id == task.parentId) {
          parent = t;
          break;
        }
      }
      if (parent != null && parent.executorPeriods.isNotEmpty) {
        ExecutorPeriod? parentEpForExecutor;
        for (final ep in parent.executorPeriods) {
          if (_executorPeriodMatches(ep, executorId)) {
            parentEpForExecutor = ep;
            break;
          }
        }
        if (parentEpForExecutor == null) return intervals;
        for (final period in parentEpForExecutor.periods) {
          if (period.tipoPeriodo.toUpperCase() != 'EXECUCAO') continue;
          if (_overlapsDay(period.dataInicio, period.dataFim, dayStart, dayEnd)) {
            debugSourceOut?.add('executorPeriods_pai');
            intervals.add(clampPeriodToDay(period.dataInicio, period.dataFim));
          }
        }
        return intervals;
      }
    }

    // 3. Tarefa PAI sem executorPeriods: filhos do mesmo executor
    final children = allTasks.where((t) => t.parentId == task.id).toList();
    if (children.isNotEmpty) {
      final hasStructuredIds = task.executorIds.any((id) => id.trim().isNotEmpty) ||
          task.executorPeriods.any((ep) => ep.executorId.trim().isNotEmpty);

      final bool parentInvolvesExecutor;
      if (hasStructuredIds) {
        parentInvolvesExecutor = task.executorIds.contains(executorId) ||
            task.executorPeriods.any((ep) => ep.executorId == executorId);
      } else {
        final execKey = _normalizeExecutorKey(executorId);
        final parentNamesNorm = task.executor
            .split(',')
            .map((s) => _normalizeExecutorKey(s))
            .where((s) => s.isNotEmpty)
            .toSet();
        parentInvolvesExecutor = parentNamesNorm.contains(execKey) ||
            task.executores.any((e) => _normalizeExecutorKey(e) == execKey);
      }

      if (parentInvolvesExecutor) {
        for (final child in children) {
          final childHasStructuredIds = child.executorIds.any((id) => id.trim().isNotEmpty) ||
              child.executorPeriods.any((ep) => ep.executorId.trim().isNotEmpty);

          final bool childInvolves;
          if (childHasStructuredIds) {
            childInvolves = child.executorIds.contains(executorId) ||
                child.executorPeriods.any((ep) => ep.executorId == executorId);
          } else {
            final execKey = _normalizeExecutorKey(executorId);
            childInvolves = (child.executor.isNotEmpty &&
                    _normalizeExecutorKey(child.executor) == execKey) ||
                child.executores.any(
                  (e) => _normalizeExecutorKey(e) == execKey,
                ) ||
                child.executorPeriods.any(
                  (ep) => _executorPeriodMatches(ep, executorId),
                );
          }
          if (!childInvolves) continue;
          final childIntervals = getExecutionIntervalsOnDayForExecutor(
            child,
            executorId,
            dayStart,
            dayEnd,
            allTasks,
          );
          if (childIntervals.isNotEmpty) {
            debugSourceOut?.add('filhos');
            intervals.addAll(childIntervals);
          }
        }
        return intervals;
      }
      return intervals;
    }

    // 4. ganttSegments da tarefa
    final idsAll = getExecutorIdsForTask(
      task,
    ).where((e) => e.trim().isNotEmpty).toSet();
    final uuidSet = idsAll.where((e) => _uuidRegex.hasMatch(e.trim())).toSet();
    final nameSet = idsAll
        .where((e) => !_uuidRegex.hasMatch(e.trim()))
        .map((e) => _normalizeExecutorKey(e))
        .where((e) => e.isNotEmpty)
        .toSet();
    final multipleExecutors = uuidSet.length > 1 || nameSet.length > 1;
    if (multipleExecutors) return intervals;
    for (final segment in task.ganttSegments) {
      if (segment.tipoPeriodo.toUpperCase() != 'EXECUCAO') continue;
      if (_overlapsDay(segment.dataInicio, segment.dataFim, dayStart, dayEnd)) {
        debugSourceOut?.add('ganttSegments');
        intervals.add(clampPeriodToDay(segment.dataInicio, segment.dataFim));
      }
    }
    return intervals;
  }

  /// Prioridade: executorPeriods da tarefa → executorPeriods do pai → filhos → ganttSegments.
  /// Regra de ouro: se existir executorPeriods (na tarefa ou no pai) para este executor e NÃO
  /// houver segmento EXECUCAO que intercepte o dia, NÃO há execução (nunca cair em ganttSegments).
  static bool taskHasExecutionOnDayForExecutor(
    Task task,
    String executorId,
    DateTime dayStart,
    DateTime dayEnd,
    List<Task> allTasks, {
    List<String>? debugSourceOut,
  }) {
    return getExecutionIntervalsOnDayForExecutor(
      task,
      executorId,
      dayStart,
      dayEnd,
      allTasks,
      debugSourceOut: debugSourceOut,
    ).isNotEmpty;
  }

  /// Conjunto de identificadores de executor (id ou nome) que estão alocados à tarefa.
  static Set<String> getExecutorIdsForTask(Task task) {
    final ids = <String>{};
    final hasUUID = task.executorIds.any((id) => id.trim().isNotEmpty) ||
        task.executorPeriods.any((ep) => ep.executorId.trim().isNotEmpty);

    if (hasUUID) {
      ids.addAll(task.executorIds.where((id) => id.trim().isNotEmpty));
      for (final ep in task.executorPeriods) {
        if (ep.executorId.trim().isNotEmpty) {
          ids.add(ep.executorId.trim());
        }
      }
      return ids;
    }

    for (final s
        in task.executor
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)) {
      ids.add(s);
    }
    for (final name in task.executores) {
      final t = name.trim();
      if (t.isNotEmpty) ids.add(t);
    }
    for (final ep in task.executorPeriods) {
      if (ep.executorNome.trim().isNotEmpty) {
        ids.add(ep.executorNome.trim());
      }
    }
    return ids;
  }

  static String _eventDescription(Task task) {
    final localLabel = task.locais.isNotEmpty
        ? task.locais.join(', ')
        : 'Sem local';
    final tarefa = task.tarefa.isNotEmpty ? task.tarefa : 'Tarefa';
    final statusStr = task.status.trim().isNotEmpty
        ? task.status.trim()
        : (task.statusNome.trim().isNotEmpty ? task.statusNome.trim() : '-');
    return '$localLabel — $tarefa (Status: $statusStr)';
  }

  /// Gera eventos de execução (executor, dia, local, tarefa) para o dia, considerando apenas EXECUÇÃO,
  /// intervalos de horários e a prioridade executorPeriods → pai → filhos → ganttSegments.
  /// [allTasks] usado para resolver parent/children; se null, usa [tasks].
  static List<ExecutionEvent> getExecutionEventsForDay(
    List<Task> tasks,
    DateTime day, [
    List<Task>? allTasks,
  ]) {
    final resolved = allTasks ?? tasks;
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final events = <ExecutionEvent>[];

    for (final task in tasks) {
      if (isTaskExcludedFromConflict(task)) continue;

      for (final executorId in getExecutorIdsForTask(task)) {
        if (!_taskInvolvesExecutor(task, executorId)) continue;
        final isDebug =
            _debugDay07Edmundo &&
            day.day == 7 &&
            _normalizeExecutorKey(executorId) ==
                _normalizeExecutorKey('EDMUNDO');
        final sourceOut = isDebug ? <String>[] : null;
        
        final intervals = getExecutionIntervalsOnDayForExecutor(
          task,
          executorId,
          dayStart,
          dayEnd,
          resolved,
          debugSourceOut: sourceOut,
        );
        if (intervals.isEmpty) continue;

        final locKey = taskLocationKey(task);
        final locationKey = locKey.isNotEmpty ? locKey : 'task-${task.id}';
        
        for (final interval in intervals) {
          events.add(
            ExecutionEvent(
              executorId: executorId,
              day: day,
              locationKey: locationKey,
              taskId: task.id,
              description: _eventDescription(task),
              startTime: interval.start,
              endTime: interval.end,
            ),
          );
        }
        if (isDebug && sourceOut != null && sourceOut.isNotEmpty) {
          debugPrint(
            'ConflictDetection DEBUG dia 07 EDMUNDO: tarefa=${task.tarefa} (${task.id}) fonte=${sourceOut.single}',
          );
        }
      }
    }
    return events;
  }

  /// Agrupa eventos por (executor, dia). Conflito existe se há dois ou mais locais distintos no mesmo (executor, dia)
  /// E com sobreposição real de horário entre os eventos.
  /// [allTasks] usado para resolver parent/children; se null, usa [tasks].
  static bool hasConflictOnDayForExecutor(
    List<Task> tasks,
    DateTime day,
    String executorId, [
    List<Task>? allTasks,
  ]) {
    final events = getExecutionEventsForDay(tasks, day, allTasks);
    final execEvents = events
        .where(
          (e) =>
              _normalizeExecutorKey(e.executorId) ==
              _normalizeExecutorKey(executorId),
        )
        .toList();

    final locations = execEvents
        .map((e) => e.locationKey)
        .where((k) => k.isNotEmpty)
        .toSet();
    if (locations.length <= 1) return false;

    // Verificar se existe sobreposição de horário entre eventos de locais distintos
    for (int i = 0; i < execEvents.length; i++) {
      for (int j = i + 1; j < execEvents.length; j++) {
        final ev1 = execEvents[i];
        final ev2 = execEvents[j];
        if (ev1.locationKey == ev2.locationKey) continue;
        if (ev1.taskId == ev2.taskId) continue;

        final start1 = ev1.startTime ?? DateTime(day.year, day.month, day.day, 0, 0);
        final end1 = ev1.endTime ?? DateTime(day.year, day.month, day.day, 23, 59, 59);
        final start2 = ev2.startTime ?? DateTime(day.year, day.month, day.day, 0, 0);
        final end2 = ev2.endTime ?? DateTime(day.year, day.month, day.day, 23, 59, 59);

        // Intervalos se sobrepõem no tempo se: start1 < end2 AND end1 > start2
        if (start1.isBefore(end2) && end1.isAfter(start2)) {
          return true;
        }
      }
    }

    return false;
  }

  /// Descrições "LOCAL — Tarefa (Status: ...)" para tooltip de conflito no dia/executor, opcionalmente excluindo uma tarefa.
  /// Inclui apenas as tarefas que realmente participam de um conflito de horário.
  /// [allTasks] usado para resolver parent/children; se null, usa [tasks].
  static List<String> getConflictDescriptionsForDay(
    List<Task> tasks,
    DateTime day,
    String executorId, {
    String? excludeTaskId,
    List<Task>? allTasks,
  }) {
    final events = getExecutionEventsForDay(tasks, day, allTasks);
    final keyNorm = _normalizeExecutorKey(executorId);
    final execEvents = events
        .where((e) => _normalizeExecutorKey(e.executorId) == keyNorm)
        .toList();

    // Identificar as tarefas que realmente colidem em horário
    final conflictingTaskIds = <String>{};
    for (int i = 0; i < execEvents.length; i++) {
      for (int j = i + 1; j < execEvents.length; j++) {
        final ev1 = execEvents[i];
        final ev2 = execEvents[j];
        if (ev1.locationKey == ev2.locationKey) continue;
        if (ev1.taskId == ev2.taskId) continue;

        final start1 = ev1.startTime ?? DateTime(day.year, day.month, day.day, 0, 0);
        final end1 = ev1.endTime ?? DateTime(day.year, day.month, day.day, 23, 59, 59);
        final start2 = ev2.startTime ?? DateTime(day.year, day.month, day.day, 0, 0);
        final end2 = ev2.endTime ?? DateTime(day.year, day.month, day.day, 23, 59, 59);

        if (start1.isBefore(end2) && end1.isAfter(start2)) {
          conflictingTaskIds.add(ev1.taskId);
          conflictingTaskIds.add(ev2.taskId);
        }
      }
    }

    return execEvents
        .where((e) => conflictingTaskIds.contains(e.taskId))
        .where((e) => excludeTaskId == null || e.taskId != excludeTaskId)
        .map((e) => e.description)
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }
}
