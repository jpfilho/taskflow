import 'package:flutter/foundation.dart';

import '../models/task.dart';

/// Evento diário de execução: um executor está alocado a uma tarefa em um local em um dia.
/// Conflito = dois ou mais eventos no mesmo (executor, dia) com locais distintos.
class ExecutionEvent {
  final String executorId;
  final DateTime day;
  final String locationKey;
  final String taskId;
  final String description;

  const ExecutionEvent({
    required this.executorId,
    required this.day,
    required this.locationKey,
    required this.taskId,
    required this.description,
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

  static bool _executorPeriodMatches(
    ExecutorPeriod ep,
    String executorIdOrName,
  ) {
    final key = _normalizeExecutorKey(executorIdOrName);
    if (key.isEmpty) return false;
    return _normalizeExecutorKey(ep.executorId) == key ||
        _normalizeExecutorKey(ep.executorNome) == key;
  }

  static bool _taskInvolvesExecutor(Task task, String executorId) {
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
    return task.executorIds.contains(executorId) ||
        executorNamesNorm.contains(executorKeyNorm) ||
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
    return periodStart.isBefore(dayEnd) && periodEnd.isAfter(dayStart);
  }

  /// Instrumentação temporária: listar tarefas que geram ExecutionEvent para EDMUNDO no dia 07 e a fonte.
  /// Desligar após confirmar que TSD não gera evento para EDMUNDO no dia 07.
  static const bool _debugDay07Edmundo = true;

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
    // 1. executorPeriods da PRÓPRIA tarefa: execução é definida explicitamente por executor.
    // Se existir executorPeriods mas NÃO houver período para este executor → retornar false (não seguir para pai/filhos/ganttSegments).
    if (task.executorPeriods.isNotEmpty) {
      ExecutorPeriod? epForExecutor;
      for (final ep in task.executorPeriods) {
        if (_executorPeriodMatches(ep, executorId)) {
          epForExecutor = ep;
          break;
        }
      }
      if (epForExecutor == null) return false;
      for (final period in epForExecutor.periods) {
        if (period.tipoPeriodo.toUpperCase() != 'EXECUCAO') continue;
        if (_overlapsDay(period.dataInicio, period.dataFim, dayStart, dayEnd)) {
          if (debugSourceOut != null) {
            debugSourceOut.add('executorPeriods_tarefa');
          }
          return true;
        }
      }
      return false; // tem período para o executor mas nenhum EXECUCAO neste dia
    }

    // 2. Subtarefa: executorPeriods do PAI. Se o pai tem executorPeriods mas não tem período para este executor → retornar false (não cair em ganttSegments).
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
        if (parentEpForExecutor == null) return false;
        for (final period in parentEpForExecutor.periods) {
          if (period.tipoPeriodo.toUpperCase() != 'EXECUCAO') continue;
          if (_overlapsDay(
            period.dataInicio,
            period.dataFim,
            dayStart,
            dayEnd,
          )) {
            if (debugSourceOut != null) {
              debugSourceOut.add('executorPeriods_pai');
            }
            return true;
          }
        }
        return false; // pai tem período para o executor mas nenhum EXECUCAO neste dia
      }
    }

    // 3. Tarefa PAI sem executorPeriods (para este executor): só conta se algum FILHO DO MESMO executor tiver EXECUÇÃO no dia.
    // Regra de ouro: NÃO considerar execução de filhos de outros executores; NÃO cair em ganttSegments do pai.
    // Se a tarefa tem filhos, o pai NUNCA pode cair em ganttSegments (bloco 4).
    final children = allTasks.where((t) => t.parentId == task.id).toList();
    if (children.isNotEmpty) {
      final execKey = _normalizeExecutorKey(executorId);
      final parentNamesNorm = task.executor
          .split(',')
          .map((s) => _normalizeExecutorKey(s))
          .where((s) => s.isNotEmpty)
          .toSet();
      final parentInvolvesExecutor =
          task.executorIds.contains(executorId) ||
          parentNamesNorm.contains(execKey) ||
          task.executores.any((e) => _normalizeExecutorKey(e) == execKey);
      if (parentInvolvesExecutor) {
        for (final child in children) {
          final childInvolves =
              child.executorIds.contains(executorId) ||
              (child.executor.isNotEmpty &&
                  _normalizeExecutorKey(child.executor) == execKey) ||
              child.executores.any(
                (e) => _normalizeExecutorKey(e) == execKey,
              ) ||
              child.executorPeriods.any(
                (ep) => _executorPeriodMatches(ep, executorId),
              );
          if (!childInvolves) continue;
          if (taskHasExecutionOnDayForExecutor(
            child,
            executorId,
            dayStart,
            dayEnd,
            allTasks,
          )) {
            if (debugSourceOut != null) debugSourceOut.add('filhos');
            return true;
          }
        }
        return false; // nenhum filho deste executor tem execução no dia => pai NÃO tem
      }
      return false; // tarefa tem filhos mas não envolve este executor → não cair em ganttSegments
    }

    // 4. ganttSegments da tarefa (somente quando não há executorPeriods, nem pai com executorPeriods, e não há filhos)
    // IMPORTANTE: se a tarefa tiver múltiplos executores e não houver executorPeriods
    // para diferenciá-los, não é possível atribuir EXECUÇÃO a um executor específico.
    // Nesses casos, NÃO considerar execução individual pelo ganttSegments (evita falsos positivos).
    final idsAll = getExecutorIdsForTask(
      task,
    ).where((e) => e.trim().isNotEmpty).toSet();
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    final uuidSet = idsAll.where((e) => uuidRegex.hasMatch(e.trim())).toSet();
    final nameSet = idsAll
        .where((e) => !uuidRegex.hasMatch(e.trim()))
        .map((e) => _normalizeExecutorKey(e))
        .where((e) => e.isNotEmpty)
        .toSet();
    final multipleExecutors = uuidSet.length > 1 || nameSet.length > 1;
    if (multipleExecutors) return false;
    for (final segment in task.ganttSegments) {
      if (segment.tipoPeriodo.toUpperCase() != 'EXECUCAO') continue;
      if (_overlapsDay(segment.dataInicio, segment.dataFim, dayStart, dayEnd)) {
        if (debugSourceOut != null) debugSourceOut.add('ganttSegments');
        return true;
      }
    }
    return false;
  }

  /// Conjunto de identificadores de executor (id ou nome) que estão alocados à tarefa.
  static Set<String> getExecutorIdsForTask(Task task) {
    final ids = <String>{};
    ids.addAll(task.executorIds);
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
      if (ep.executorId.isNotEmpty) ids.add(ep.executorId);
      if (ep.executorNome.trim().isNotEmpty) ids.add(ep.executorNome.trim());
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

  /// Gera eventos de execução (executor, dia, local, tarefa) para o dia, considerando apenas EXECUÇÃO
  /// e a prioridade executorPeriods → pai → filhos → ganttSegments. Tarefas excluídas por status são ignoradas.
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
        if (!taskHasExecutionOnDayForExecutor(
          task,
          executorId,
          dayStart,
          dayEnd,
          resolved,
          debugSourceOut: sourceOut,
        )) {
          continue;
        }

        final locKey = taskLocationKey(task);
        final locationKey = locKey.isNotEmpty ? locKey : 'task-${task.id}';
        events.add(
          ExecutionEvent(
            executorId: executorId,
            day: day,
            locationKey: locationKey,
            taskId: task.id,
            description: _eventDescription(task),
          ),
        );
        if (isDebug && sourceOut != null && sourceOut.isNotEmpty) {
          debugPrint(
            'ConflictDetection DEBUG dia 07 EDMUNDO: tarefa=${task.tarefa} (${task.id}) fonte=${sourceOut.single}',
          );
        }
      }
    }
    return events;
  }

  /// Agrupa eventos por (executor, dia). Conflito existe se há dois ou mais locais distintos no mesmo (executor, dia).
  /// [allTasks] usado para resolver parent/children; se null, usa [tasks].
  static bool hasConflictOnDayForExecutor(
    List<Task> tasks,
    DateTime day,
    String executorId, [
    List<Task>? allTasks,
  ]) {
    final events = getExecutionEventsForDay(tasks, day, allTasks);
    final locations = events
        .where(
          (e) =>
              _normalizeExecutorKey(e.executorId) ==
              _normalizeExecutorKey(executorId),
        )
        .map((e) => e.locationKey)
        .where((k) => k.isNotEmpty)
        .toSet();
    return locations.length > 1;
  }

  /// Descrições "LOCAL — Tarefa (Status: ...)" para tooltip de conflito no dia/executor, opcionalmente excluindo uma tarefa.
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
    return events
        .where((e) => _normalizeExecutorKey(e.executorId) == keyNorm)
        .where((e) => excludeTaskId == null || e.taskId != excludeTaskId)
        .map((e) => e.description)
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }
}
