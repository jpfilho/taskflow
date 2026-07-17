import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task2026/services/task_service.dart';
import 'package:task2026/services/executor_service.dart';
import 'package:task2026/services/conflict_service.dart';
import 'package:task2026/models/task.dart';
import 'package:task2026/models/executor.dart';

void main() {
  test('Teste de query no Supabase para tela de equipes', () async {
    print('🧪 Iniciando teste de diagnóstico de performance para a tela de Equipes...');
    
    SharedPreferences.setMockInitialValues({});
    
    try {
      await Supabase.initialize(
        url: 'http://212.85.0.249:8000',
        anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzY1ODE3OTgzLCJleHAiOjIwODExNzc5ODN9.YQByqDrpmw0en7VeEcjDfvvTx8Ind_q8gD6-bzEY4Yc',
      );
    } catch (e) {
      fail(e.toString());
    }

    final taskService = TaskService();
    final executorService = ExecutorService();

    final startDate = DateTime(2026, 6, 1);
    final endDate = DateTime(2026, 6, 30);

    List<Task> tasks = [];
    try {
      print('🔍 Carregando tarefas do período...');
      final sw = Stopwatch()..start();
      tasks = await taskService.getTasksForRange(
        startDate: startDate,
        endDate: endDate,
        aplicarPerfil: false,
      );
      sw.stop();
      print('   ✅ Retornadas ${tasks.length} tarefas em ${sw.elapsedMilliseconds}ms.');
    } catch (e) {
      print('   ❌ Erro tarefas: $e');
      return;
    }

    List<Executor> executores = [];
    try {
      print('🔍 Carregando executores...');
      final sw = Stopwatch()..start();
      executores = await executorService.getAllExecutores();
      sw.stop();
      print('   ✅ Retornados ${executores.length} executores em ${sw.elapsedMilliseconds}ms.');
    } catch (e) {
      print('   ❌ Erro executores: $e');
      return;
    }

    List<Map<String, dynamic>> rows = [];
    try {
      print('🔍 Executando getExecucoesDia...');
      final sw = Stopwatch()..start();
      final ids = executores.map((e) => e.id).toList();
      rows = await taskService.getExecucoesDia(
        executorIds: ids,
        startDate: startDate,
        endDate: endDate,
      );
      sw.stop();
      print('   ✅ Retornadas ${rows.length} execuções em ${sw.elapsedMilliseconds}ms.');
    } catch (e) {
      print('   ❌ Erro getExecucoesDia: $e');
    }

    // Helper de normalização idêntico ao da tela de Equipes
    String normalizeText(String input) {
      var normalized = input.toLowerCase().trim();
      const withDiacritics = 'áàâãäåçéèêëíìîïñóòôõöúùûüýÿÁÀÂÃÄÅÇÉÈÊËÍÌÎÏÑÓÒÔÕÖÚÙÛÜÝ';
      const without =        'aaaaaaceeeeiiiinooooouuuuyyAAAAAACEEEEIIIINOOOOOUUUUY';
      for (var i = 0; i < withDiacritics.length && i < without.length; i++) {
        normalized = normalized.replaceAll(withDiacritics[i], without[i]);
      }
      normalized = normalized.replaceAll(RegExp(r'[^a-z0-9]'), '');
      return normalized;
    }

    print('⏱ Iniciando lógica de agrupamento e loop de CPU (Simulação de _buildExecutorRowsFromView)...');
    final cpuSw = Stopwatch()..start();

    final byExecutor = <String, List<Map<String, dynamic>>>{};
    for (final r in rows) {
      final execId = r['executor_id']?.toString() ?? '';
      if (execId.isEmpty) continue;
      byExecutor.putIfAbsent(execId, () => []).add(r);
    }

    final Map<String, Set<String>> execKeySetById = {
      for (final e in executores)
        e.id: ({
          normalizeText(e.nome),
          if (e.nomeCompleto != null) normalizeText(e.nomeCompleto!),
          if (e.login != null) normalizeText(e.login!),
          if (e.matricula != null) normalizeText(e.matricula!),
        }..removeWhere((v) => v.isEmpty))
    };

    bool matchesExecutor(Executor executor, {String? executorId, String? executorNome}) {
      if (executorId != null && executorId.isNotEmpty) {
        return executorId == executor.id;
      }
      if (executorNome != null && executorNome.isNotEmpty) {
        final keys = execKeySetById[executor.id] ?? const {};
        return keys.contains(normalizeText(executorNome));
      }
      return false;
    }

    bool isTaskAssignedToExecutor(Task task, Executor executor) {
      final hasStructuredIds = task.executorIds.any((id) => id.trim().isNotEmpty) ||
          task.executorPeriods.any((ep) => ep.executorId.trim().isNotEmpty);

      if (hasStructuredIds) {
        if (task.executorIds.any((id) => id.isNotEmpty && id == executor.id)) return true;
        for (final ep in task.executorPeriods) {
          if (ep.executorId.isNotEmpty && ep.executorId == executor.id) return true;
        }
        return false;
      }

      final keys = execKeySetById[executor.id] ?? const {};

      for (final nome in task.executores) {
        if (nome.isNotEmpty && keys.contains(normalizeText(nome))) return true;
      }
      if (task.executor.isNotEmpty) {
        for (final nome in task.executor.split(',').map((e) => e.trim())) {
          if (nome.isNotEmpty && keys.contains(normalizeText(nome))) return true;
        }
      }
      if (task.equipeExecutores != null) {
        for (final ee in task.equipeExecutores!) {
          if (ee.executorNome.isNotEmpty && keys.contains(normalizeText(ee.executorNome))) return true;
        }
      }
      for (final ep in task.executorPeriods) {
        if (matchesExecutor(executor, executorId: ep.executorId, executorNome: ep.executorNome)) return true;
      }
      return false;
    }

    int totalTasksProcessed = 0;
    int executorCount = 0;

    for (final executor in executores) {
      executorCount++;
      final list = byExecutor[executor.id] ?? [];
      final tasksById = <String, Task>{};
      final taskDaysByTipo = <String, Map<String, List<DateTime>>>{};

      for (final r in list) {
        final taskId = r['task_id']?.toString() ?? '';
        if (taskId.isEmpty) continue;
        final dayStr = r['day']?.toString();
        if (dayStr == null) continue;
        final day = DateTime.parse(dayStr);
        final tipoPeriodo = (r['tipo_periodo']?.toString() ?? 'EXECUCAO').toUpperCase();

        taskDaysByTipo.putIfAbsent(taskId, () => {});
        taskDaysByTipo[taskId]!.putIfAbsent(tipoPeriodo, () => []).add(day);

        tasksById[taskId] = Task(
          id: taskId,
          status: '',
          statusNome: '',
          regional: '',
          divisao: '',
          locais: const [],
          segmento: '',
          equipes: const [],
          tipo: '',
          tarefa: '',
          executores: const [],
          executor: '',
          frota: '',
          coordenador: '',
          si: '',
          dataInicio: day,
          dataFim: day,
          ganttSegments: const [],
          executorPeriods: const [],
          frotaPeriods: const [],
          precisaSi: false,
          executorIds: const [],
          equipeIds: const [],
          frotaIds: const [],
          localIds: const [],
        );
      }

      // Lógica de Enriquecimento pesada de CPU
      for (final task in tasks) {
        if (isTaskAssignedToExecutor(task, executor)) {
          final periodStart = DateTime(startDate.year, startDate.month, startDate.day);
          final periodEnd = DateTime(endDate.year, endDate.month, endDate.day);
          
          bool inRange = false;
          if (task.ganttSegments.isNotEmpty) {
            for (final seg in task.ganttSegments) {
              if (!(seg.dataInicio.isAfter(periodEnd) || seg.dataFim.isBefore(periodStart))) {
                inRange = true;
                break;
              }
            }
          } else {
            inRange = !(task.dataInicio.isAfter(periodEnd) || task.dataFim.isBefore(periodStart));
          }

          if (inRange) {
            tasksById.putIfAbsent(task.id, () => task);
            final daysByTipo = taskDaysByTipo.putIfAbsent(task.id, () => {});
            
            if (task.ganttSegments.isNotEmpty) {
              for (final seg in task.ganttSegments) {
                final tipo = (seg.tipoPeriodo ?? 'EXECUCAO').toUpperCase();
                final daysList = daysByTipo.putIfAbsent(tipo, () => []);
                
                DateTime d = DateTime(seg.dataInicio.year, seg.dataInicio.month, seg.dataInicio.day);
                final end = DateTime(seg.dataFim.year, seg.dataFim.month, seg.dataFim.day);
                
                int loopGuard = 0;
                while (!d.isAfter(end)) {
                  loopGuard++;
                  if (loopGuard > 1000) {
                    print('⚠️ DETECTADO POSSÍVEL LOOP INFINITO no loop de segmentos! d: $d, end: $end');
                    break;
                  }
                  if (!(d.isAfter(periodEnd) || d.isBefore(periodStart))) {
                    if (!daysList.any((existingDay) => 
                        existingDay.year == d.year && 
                        existingDay.month == d.month && 
                        existingDay.day == d.day)) {
                      daysList.add(d);
                    }
                  }
                  d = d.add(const Duration(days: 1));
                }
              }
            } else {
              final daysList = daysByTipo.putIfAbsent('EXECUCAO', () => []);
              DateTime d = DateTime(task.dataInicio.year, task.dataInicio.month, task.dataInicio.day);
              final end = DateTime(task.dataFim.year, task.dataFim.month, task.dataFim.day);
              
              int loopGuard = 0;
              while (!d.isAfter(end)) {
                loopGuard++;
                if (loopGuard > 1000) {
                  print('⚠️ DETECTADO POSSÍVEL LOOP INFINITO no loop de tarefa simples! d: $d, end: $end');
                  break;
                }
                if (!(d.isAfter(periodEnd) || d.isBefore(periodStart))) {
                  if (!daysList.any((existingDay) => 
                      existingDay.year == d.year && 
                      existingDay.month == d.month && 
                      existingDay.day == d.day)) {
                    daysList.add(d);
                  }
                }
                d = d.add(const Duration(days: 1));
              }
            }
          }
        }
      }
      totalTasksProcessed += tasksById.length;
    }

    cpuSw.stop();
    print('🏁 FIM DA SIMULAÇÃO: Loop de CPU processado em ${cpuSw.elapsedMilliseconds}ms. Total de tarefas associadas: $totalTasksProcessed');

    print('\n🔍 Testando queries do ConflictService...');
    final conflictService = ConflictService();
    final executorIds = executores.map((e) => e.id).toList();

    try {
      print('🔍 Testando ConflictService.isBackendAvailable...');
      final sw = Stopwatch()..start();
      final available = await conflictService.isBackendAvailable();
      sw.stop();
      print('   Backend disponível: $available (tempo: ${sw.elapsedMilliseconds}ms)');
      
      if (available) {
        print('🔍 Buscando conflitos com getConflictsForRange...');
        final swConflicts = Stopwatch()..start();
        final conflicts = await conflictService.getConflictsForRange(startDate, endDate, executorIds: executorIds);
        swConflicts.stop();
        print('   ✅ Retornados ${conflicts.length} conflitos em ${swConflicts.elapsedMilliseconds}ms');

        print('🔍 Buscando eventos de execução com getExecutionEventsForRange...');
        final swEvents = Stopwatch()..start();
        final events = await conflictService.getExecutionEventsForRange(startDate, endDate, executorIds: executorIds);
        swEvents.stop();
        print('   ✅ Retornados ${events.length} dias com eventos em ${swEvents.elapsedMilliseconds}ms');
      }
    } catch (e) {
      print('   ❌ Erro ao testar queries de conflitos: $e');
    }
  });
}
