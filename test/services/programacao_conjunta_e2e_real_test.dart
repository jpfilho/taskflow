import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:task2026/config/supabase_config.dart';
import 'package:task2026/services/nota_sap_service.dart';

class _RealHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context);
  }
}

void main() {
  HttpOverrides.global = _RealHttpOverrides();

  group('Item 26 & 27: Testes Manuais Ponta a Ponta no Ambiente de Desenvolvimento', () {
    late NotaSAPService notaSapService;
    late SupabaseClient client;

    // IDs de controle para limpeza após os testes
    final tarefasCriadas = <String>[];
    final notasReais = <String>[];

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      try {
        await SupabaseConfig.initialize();
      } catch (_) {}
      client = SupabaseConfig.client;
      notaSapService = NotaSAPService();

      // Buscar 3 notas reais existentes no banco sem ordens vinculadas para isolar
      // o teste de triggers legados de replicação de ordem do SAP
      final notasDb = await client
          .from('notas_sap')
          .select('id')
          .or('ordem.is.null,ordem.eq.')
          .limit(3);
      for (final n in notasDb) {
        notasReais.add(n['id'].toString());
      }
    });

    tearDownAll(() async {
      // Limpeza segura dos registros de teste criados
      for (final taskId in tarefasCriadas) {
        try {
          await client.from('tasks_notas_sap').delete().eq('task_id', taskId);
          await client.from('tasks').delete().eq('id', taskId);
        } catch (_) {}
      }
    });

    Future<String> criarTarefaAuxiliar(String titulo) async {
      final res = await client.from('tasks').insert({
        'tarefa': '[TESTE_AUTO] $titulo',
        'status': 'PROG',
        'regional': 'NORTE',
        'divisao': 'TRANSMISSAO',
        'local': 'SE-PIRAPORA',
        'data_inicio': DateTime.now().toIso8601String(),
        'data_fim': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
        'tipo': 'CORRETIVA',
        'executor': 'Equipe Teste',
        'coordenador': 'Coord Teste',
        'frota': 'Veiculo Teste',
        'ordem': '',
        'si': '',
        'precisa_si': false,
        'horas_previstas': 4.0,
        'horas_executadas': 0.0,
      }).select('id').single();

      final id = res['id'].toString();
      tarefasCriadas.add(id);
      return id;
    }

    test('Caso 1: Nota sem grupo → Criar Task (1 nota selecionada → 1 vínculo)', () async {
      final taskId = await criarTarefaAuxiliar('Caso 1 Nota Sem Grupo');
      final notaA = notasReais[0];

      // Vincular Nota A
      final vinculadas = await notaSapService.vincularNotasATarefaBatch(
        taskId: taskId,
        notaSapIds: [notaA],
      );

      // Conferir na tabela real tasks_notas_sap
      final rows = await client
          .from('tasks_notas_sap')
          .select('nota_sap_id')
          .eq('task_id', taskId);

      print('📋 [Caso 1] task_id: ${taskId.substring(0, 8)}... | selecionadas: 1 | persistidas: ${rows.length}');

      expect(vinculadas.length, equals(1));
      expect(rows.length, equals(1));
      expect(rows[0]['nota_sap_id'], equals(notaA));
    });

    test('Caso 2: Grupo A+B+C → Selecionar somente A (1 nota selecionada → 1 vínculo)', () async {
      final taskId = await criarTarefaAuxiliar('Caso 2 Somente A do Grupo');
      final notaA = notasReais[0];

      final vinculadas = await notaSapService.vincularNotasATarefaBatch(
        taskId: taskId,
        notaSapIds: [notaA],
      );

      final rows = await client
          .from('tasks_notas_sap')
          .select('nota_sap_id')
          .eq('task_id', taskId);

      print('📋 [Caso 2] task_id: ${taskId.substring(0, 8)}... | selecionadas: 1 | persistidas: ${rows.length}');

      expect(vinculadas.length, equals(1));
      expect(rows.length, equals(1));
    });

    test('Caso 3: Grupo A+B+C → Selecionar A+B (2 notas selecionadas → 2 vínculos)', () async {
      final taskId = await criarTarefaAuxiliar('Caso 3 A+B do Grupo');
      final notas = [notasReais[0], notasReais[1]];

      final vinculadas = await notaSapService.vincularNotasATarefaBatch(
        taskId: taskId,
        notaSapIds: notas,
      );

      final rows = await client
          .from('tasks_notas_sap')
          .select('nota_sap_id')
          .eq('task_id', taskId);

      print('📋 [Caso 3] task_id: ${taskId.substring(0, 8)}... | selecionadas: 2 | persistidas: ${rows.length}');

      expect(vinculadas.length, equals(2));
      expect(rows.length, equals(2));
    });

    test('Caso 4: Grupo A+B+C → Selecionar todas (3 notas selecionadas → 3 vínculos)', () async {
      final taskId = await criarTarefaAuxiliar('Caso 4 Todas A+B+C');
      final notas = [notasReais[0], notasReais[1], notasReais[2]];

      final vinculadas = await notaSapService.vincularNotasATarefaBatch(
        taskId: taskId,
        notaSapIds: notas,
      );

      final rows = await client
          .from('tasks_notas_sap')
          .select('nota_sap_id')
          .eq('task_id', taskId);

      print('📋 [Caso 4] task_id: ${taskId.substring(0, 8)}... | selecionadas: 3 | persistidas: ${rows.length}');

      expect(vinculadas.length, equals(3));
      expect(rows.length, equals(3));
    });

    test('Caso 5: B já programada em outra tarefa → Incluir novamente após confirmação (N:M)', () async {
      // 1. Tarefa anterior com B
      final taskAnteriorId = await criarTarefaAuxiliar('Tarefa Prévia com B');
      final notaB = notasReais[1];
      await notaSapService.vincularNotasATarefaBatch(
        taskId: taskAnteriorId,
        notaSapIds: [notaB],
      );

      // 2. Nova tarefa vinculando A e também B (confirmada pelo usuário)
      final novaTaskId = await criarTarefaAuxiliar('Nova Tarefa com A+B');
      final vinculadas = await notaSapService.vincularNotasATarefaBatch(
        taskId: novaTaskId,
        notaSapIds: [notasReais[0], notaB],
      );

      final rowsNovaTask = await client
          .from('tasks_notas_sap')
          .select('nota_sap_id')
          .eq('task_id', novaTaskId);

      final rowsNotaB = await client
          .from('tasks_notas_sap')
          .select('task_id')
          .eq('nota_sap_id', notaB);

      print('📋 [Caso 5] nova_task_id: ${novaTaskId.substring(0, 8)}... | selecionadas: 2 | persistidas nova task: ${rowsNovaTask.length} | total tarefas da Nota B: ${rowsNotaB.length}');

      expect(vinculadas.length, equals(2));
      expect(rowsNovaTask.length, equals(2));
      expect(rowsNotaB.length, greaterThanOrEqualTo(2));
    });

    test('Caso 6: Editar Task A+B → Adicionar C (apenas novos vínculos persistidos, anteriores intactos)', () async {
      final taskId = await criarTarefaAuxiliar('Caso 6 Edicao A+B para A+B+C');
      final notaA = notasReais[0];
      final notaB = notasReais[1];
      final notaC = notasReais[2];

      // 1. Estado inicial da tarefa: A + B
      await notaSapService.vincularNotasATarefaBatch(
        taskId: taskId,
        notaSapIds: [notaA, notaB],
      );

      final rowsIniciais = await client
          .from('tasks_notas_sap')
          .select('nota_sap_id')
          .eq('task_id', taskId);
      expect(rowsIniciais.length, equals(2));

      // 2. Edição adicionando C: a lista final selecionada é [A, B, C]
      final resultadoEdicao = await notaSapService.vincularNotasATarefaBatch(
        taskId: taskId,
        notaSapIds: [notaA, notaB, notaC],
      );

      final rowsFinais = await client
          .from('tasks_notas_sap')
          .select('nota_sap_id')
          .eq('task_id', taskId);

      print('📋 [Caso 6] task_id: ${taskId.substring(0, 8)}... | selecionadas: 3 | persistidas finais: ${rowsFinais.length}');

      expect(resultadoEdicao, containsAll([notaA, notaB, notaC]));
      expect(rowsFinais.length, equals(3));
    });
  });
}
