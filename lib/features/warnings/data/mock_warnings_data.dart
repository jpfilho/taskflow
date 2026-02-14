import 'models/task_warning.dart';

/// Dados fake para UI mock. Substituir por chamada à view/RPC do Supabase depois.
class MockWarningsData {
  /// Retorna mapa taskId -> lista de warnings (mock).
  static Map<String, List<TaskWarning>> getWarningsByTaskId() {
    final now = DateTime.now();
    final hoje = DateTime(now.year, now.month, now.day);
    return {
      'task-mock-1': [
        TaskWarning(
          taskId: 'task-mock-1',
          warningCode: 'W1',
          severity: 'HIGH',
          message: 'Tarefa está com status PROG/ANDA após a data final.',
          fixHint: 'Atualizar o status da tarefa para o status correto (ex.: CONC, CANC, etc.) ou ajustar datas.',
          detailsJson: {
            'status_atual': 'PROG',
            'data_fim': hoje.subtract(const Duration(days: 2)).toIso8601String(),
            'hoje': hoje.toIso8601String(),
          },
          createdAt: now,
          taskUpdatedAt: now,
        ),
      ],
      'task-mock-2': [
        TaskWarning(
          taskId: 'task-mock-2',
          warningCode: 'W2',
          severity: 'HIGH',
          message: 'Tarefa CONC com pendências de encerramento SAP.',
          fixHint: 'Encerrar no SAP a Nota/Ordem/AT pendente e aguardar sincronização.',
          detailsJson: {
            'status_atual': 'CONC',
            'qtd_notas_nao_encerradas': 1,
            'qtd_ordens_nao_encerradas': 0,
            'qtd_ats_nao_encerradas': 0,
          },
          createdAt: now,
          taskUpdatedAt: now,
        ),
        TaskWarning(
          taskId: 'task-mock-2',
          warningCode: 'W1',
          severity: 'HIGH',
          message: 'Tarefa está com status PROG/ANDA após a data final.',
          fixHint: 'Atualizar o status da tarefa para o status correto (ex.: CONC, CANC, etc.) ou ajustar datas.',
          detailsJson: {'status_atual': 'ANDA', 'data_fim': hoje.subtract(const Duration(days: 1)).toIso8601String()},
          createdAt: now,
          taskUpdatedAt: now,
        ),
      ],
      'task-mock-3': [
        TaskWarning(
          taskId: 'task-mock-3',
          warningCode: 'W2',
          severity: 'MEDIUM',
          message: 'Tarefa CONC com pendências de encerramento SAP.',
          fixHint: 'Encerrar no SAP a Nota/Ordem/AT pendente e aguardar sincronização.',
          detailsJson: {
            'qtd_notas_nao_encerradas': 0,
            'qtd_ordens_nao_encerradas': 1,
            'qtd_ats_nao_encerradas': 0,
          },
          createdAt: now,
          taskUpdatedAt: now,
        ),
      ],
    };
  }

  /// Para mock: gera warnings para algumas taskIds existentes (primeiros 2 IDs da lista).
  static Map<String, List<TaskWarning>> forTaskIds(List<String> taskIds) {
    final all = getWarningsByTaskId();
    final fakeIds = all.keys.toList();
    final map = <String, List<TaskWarning>>{};
    for (var i = 0; i < taskIds.length && i < 3; i++) {
      final realId = taskIds[i];
      final fakeList = all[fakeIds[i % fakeIds.length]];
      if (fakeList != null) {
        map[realId] = fakeList.map((w) => TaskWarning(
          taskId: realId,
          warningCode: w.warningCode,
          severity: w.severity,
          message: w.message,
          fixHint: w.fixHint,
          detailsJson: w.detailsJson,
          createdAt: w.createdAt,
          taskUpdatedAt: w.taskUpdatedAt,
        )).toList();
      }
    }
    return map;
  }
}
