import 'package:flutter_test/flutter_test.dart';
import 'package:supabase/supabase.dart';

void main() {
  test('Auditoria de Volume e Estrutura na Base de Desenvolvimento', () async {
    final client = SupabaseClient(
      'http://212.85.0.249:8000',
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzY1ODE3OTgzLCJleHAiOjIwODExNzc5ODN9.YQByqDrpmw0en7VeEcjDfvvTx8Ind_q8gD6-bzEY4Yc',
    );

    print('\n========== AUDITORIA DE VOLUME REAL (DEV) ==========');
    final countTasks = await client.from('tasks').select('id').count(CountOption.exact);
    final countNotas = await client.from('notas_sap').select('id').count(CountOption.exact);
    final countGrupos = await client.from('notas_sap_grupos').select('id').count(CountOption.exact);
    final countExecs = await client.from('executores').select('id').count(CountOption.exact);
    final countEquipes = await client.from('equipes').select('id').count(CountOption.exact);
    final countFeriados = await client.from('feriados').select('id').count(CountOption.exact);

    print('Total Tasks: ${countTasks.count}');
    print('Total Notas SAP: ${countNotas.count}');
    print('Total Grupos de Notas: ${countGrupos.count}');
    print('Total Executores: ${countExecs.count}');
    print('Total Equipes: ${countEquipes.count}');
    print('Total Feriados: ${countFeriados.count}');

    // Amostra de status das Notas SAP
    final statusNotasRaw = await client.from('notas_sap').select('status_sistema').limit(1000);
    final Map<String, int> contagemStatus = {};
    for (final row in (statusNotasRaw as List)) {
      final st = row['status_sistema']?.toString() ?? 'SEM_STATUS';
      contagemStatus[st] = (contagemStatus[st] ?? 0) + 1;
    }
    print('\nAmostra de 1000 Status de Notas SAP:');
    contagemStatus.forEach((k, v) => print('  - $k: $v'));

    // Amostra de status das Tarefas
    final statusTasksRaw = await client.from('tasks').select('status').limit(1000);
    final Map<String, int> contagemStatusTasks = {};
    for (final row in (statusTasksRaw as List)) {
      final st = row['status']?.toString() ?? 'SEM_STATUS';
      contagemStatusTasks[st] = (contagemStatusTasks[st] ?? 0) + 1;
    }
    print('\nAmostra de 1000 Status de Tarefas:');
    contagemStatusTasks.forEach((k, v) => print('  - $k: $v'));

    // Amostra de estimativas de horas
    final estimativasRaw = await client.from('notas_sap').select('estimativa_horas, analise_previa, status_analise_previa').limit(1000);
    int comHorasMaiorZero = 0;
    int comZero = 0;
    int nulos = 0;
    for (final row in (estimativasRaw as List)) {
      final est = row['estimativa_horas'];
      if (est == null) {
        nulos++;
      } else {
        final val = double.tryParse(est.toString()) ?? 0.0;
        if (val > 0) comHorasMaiorZero++;
        else comZero++;
      }
    }
    print('\nAmostra de 1000 Estimativas de Horas em Notas SAP:');
    print('  - Com Horas > 0: $comHorasMaiorZero');
    print('  - Com 0.0h: $comZero');
    print('  - Nulos (sem estimativa): $nulos');
    print('====================================================\n');
  });
}
