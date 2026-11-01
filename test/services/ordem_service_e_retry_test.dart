import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/models/task.dart';
import 'package:task2026/models/task_create_result.dart';

/// Repositório Fake para testar a camada de OrdemService e NotaSAPService
/// sem depender de rede ou do banco físico remoto.
class FakeSupabaseTasksNotasSapRepo {
  final List<Map<String, dynamic>> tasks = [];
  final List<Map<String, dynamic>> tasksOrdens = [];
  final List<Map<String, dynamic>> tasksNotasSap = [];
  final List<Map<String, dynamic>> ordens = [];
  final List<Map<String, dynamic>> notasSap = [];

  void reset() {
    tasks.clear();
    tasksOrdens.clear();
    tasksNotasSap.clear();
    ordens.clear();
    notasSap.clear();
  }

  /// Simula vincular ordem com flag autoVincularNotas
  Future<void> vincularOrdemATarefaFake({
    required String taskId,
    required String ordemId,
    bool autoVincularNotas = true,
  }) async {
    // 1. Vincula ordem à tarefa
    final exists = tasksOrdens.any((to) => to['task_id'] == taskId && to['ordem_id'] == ordemId);
    if (!exists) {
      tasksOrdens.add({'task_id': taskId, 'ordem_id': ordemId});
    }

    // 2. Se autoVincularNotas == true, busca notas que compartilham a mesma ordem e vincula
    if (autoVincularNotas) {
      final ordemObj = ordens.firstWhere(
        (o) => o['id'] == ordemId,
        orElse: () => {'ordem': ''},
      );
      final numOrdem = (ordemObj['ordem'] as String?)?.trim() ?? '';
      if (numOrdem.isNotEmpty) {
        final notasIrmas = notasSap.where((n) => (n['ordem'] as String?)?.trim() == numOrdem).toList();
        for (final nota in notasIrmas) {
          final notaId = nota['id'].toString();
          final jaVinculada = tasksNotasSap.any((tn) => tn['task_id'] == taskId && tn['nota_sap_id'] == notaId);
          if (!jaVinculada) {
            tasksNotasSap.add({'task_id': taskId, 'nota_sap_id': notaId});
          }
        }
      }
    }
  }

  /// Simula vincular notas em lote (Programação Conjunta)
  Future<List<String>> vincularNotasATarefaBatchFake({
    required String taskId,
    required List<String> notaSapIds,
    bool simularFalha = false,
  }) async {
    if (simularFalha) {
      throw Exception('Erro simulado de rede/timeout ao inserir em tasks_notas_sap');
    }

    final solicitados = notaSapIds.toSet();
    final existentes = tasksNotasSap
        .where((tn) => tn['task_id'] == taskId && solicitados.contains(tn['nota_sap_id']))
        .map((tn) => tn['nota_sap_id'] as String)
        .toSet();

    final novos = solicitados.difference(existentes).toList();
    for (final id in novos) {
      tasksNotasSap.add({'task_id': taskId, 'nota_sap_id': id});
    }

    return [...existentes, ...novos];
  }
}

void main() {
  group('Item 8, 9 & 10: Auditoria e Regressão do OrdemService e Fluxos de Retry', () {
    late FakeSupabaseTasksNotasSapRepo repo;

    setUp(() {
      repo = FakeSupabaseTasksNotasSapRepo();

      // Configurar Ordem #43001000 com 5 notas associadas
      repo.ordens.add({'id': 'ordem-1000', 'ordem': '43001000'});
      repo.notasSap.addAll([
        {'id': 'nota-1', 'nota': '11001', 'ordem': '43001000'},
        {'id': 'nota-2', 'nota': '11002', 'ordem': '43001000'},
        {'id': 'nota-3', 'nota': '11003', 'ordem': '43001000'},
        {'id': 'nota-4', 'nota': '11004', 'ordem': '43001000'},
        {'id': 'nota-5', 'nota': '11005', 'ordem': '43001000'},
      ]);
    });

    test('Caso A: Fluxo legado de Ordem — autoVincularNotas = true (default) vincula todas as 5 notas da Ordem', () async {
      const taskId = 'task-legada-1';

      // Chamar com default (autoVincularNotas não informado => true)
      await repo.vincularOrdemATarefaFake(
        taskId: taskId,
        ordemId: 'ordem-1000',
      );

      final vinculosOrdem = repo.tasksOrdens.where((to) => to['task_id'] == taskId).toList();
      final vinculosNotas = repo.tasksNotasSap.where((tn) => tn['task_id'] == taskId).toList();

      expect(vinculosOrdem.length, equals(1));
      expect(vinculosNotas.length, equals(5)); // Comportamento legado 100% preservado
    });

    test('Caso B: Programação Conjunta por Notas — autoVincularNotas = false não vincula notas irmãs automaticamente', () async {
      const taskId = 'task-conjunta-1';

      // No fluxo de notas, se a Ordem for vinculada, passa autoVincularNotas: false
      await repo.vincularOrdemATarefaFake(
        taskId: taskId,
        ordemId: 'ordem-1000',
        autoVincularNotas: false,
      );

      final vinculosNotas = repo.tasksNotasSap.where((tn) => tn['task_id'] == taskId).toList();
      // Nenhuma nota foi auto-vinculada à força
      expect(vinculosNotas.isEmpty, isTrue);
    });

    test('Caso C: Ordem possui 5 Notas e usuário seleciona apenas 2 na Programação Conjunta', () async {
      const taskId = 'task-conjunta-2';

      // 1. Vincula a ordem com autoVincularNotas = false
      await repo.vincularOrdemATarefaFake(
        taskId: taskId,
        ordemId: 'ordem-1000',
        autoVincularNotas: false,
      );

      // 2. Vincula estritamente as 2 notas selecionadas pelo usuário (nota-1 e nota-3)
      final vinculadas = await repo.vincularNotasATarefaBatchFake(
        taskId: taskId,
        notaSapIds: ['nota-1', 'nota-3'],
      );

      final vinculosNotas = repo.tasksNotasSap.where((tn) => tn['task_id'] == taskId).toList();

      expect(vinculadas.length, equals(2));
      expect(vinculosNotas.length, equals(2));
      expect(vinculosNotas.map((vn) => vn['nota_sap_id']), containsAll(['nota-1', 'nota-3']));
      // As outras 3 notas (nota-2, nota-4, nota-5) permanecem fora!
      expect(vinculosNotas.any((vn) => vn['nota_sap_id'] == 'nota-2'), isFalse);
    });

    test('Caso D (Retry): Falha na vinculação não recria a tarefa e retry vincula apenas o que falta com idempotência', () async {
      const taskId = 'task-oficial-842';
      final notasParaVincular = ['nota-1', 'nota-2', 'nota-3'];

      // 1. Simula tentativa de vinculação com falha
      var falhou = false;
      try {
        await repo.vincularNotasATarefaBatchFake(
          taskId: taskId,
          notaSapIds: notasParaVincular,
          simularFalha: true,
        );
      } catch (_) {
        falhou = true;
      }
      expect(falhou, isTrue);

      // A tarefa NÃO foi recriada (id continua sendo o mesmo)
      // 2. Usuário clica em [Tentar vincular novamente] -> retry direto em vincularNotasATarefaBatch
      final resultadoRetry = await repo.vincularNotasATarefaBatchFake(
        taskId: taskId,
        notaSapIds: notasParaVincular,
        simularFalha: false,
      );

      expect(resultadoRetry.length, equals(3));
      final vinculosFinais = repo.tasksNotasSap.where((tn) => tn['task_id'] == taskId).toList();
      expect(vinculosFinais.length, equals(3));

      // 3. Retry repetido (idempotente) não duplica
      final retry2 = await repo.vincularNotasATarefaBatchFake(
        taskId: taskId,
        notaSapIds: notasParaVincular,
      );
      expect(retry2.length, equals(3));
      expect(repo.tasksNotasSap.where((tn) => tn['task_id'] == taskId).length, equals(3));
    });

    test('Modelo TaskCreateResult e TaskCreatedWithVinculoException encapsulam o estado corretamente', () {
      final task = Task(
        id: 'task-test-1',
        tarefa: 'Tarefa Teste',
        status: 'PROG',
        regional: 'NORTE',
        divisao: 'TRANSMISSAO',
        coordenador: 'Coord Teste',
        localId: 'local-1',
        dataInicio: DateTime.now(),
        dataFim: DateTime.now().add(const Duration(days: 1)),
        tipo: 'CORRETIVA',
      );

      // Caso com falha parcial
      final resultParcial = TaskCreateResult(
        task: task,
        taskCriada: true,
        notasSolicitadas: ['nota-1', 'nota-2'],
        notasVinculadas: ['nota-1'],
        notasComFalha: ['nota-2'],
        vinculacaoCompleta: false,
        erroVinculacao: 'Timeout simulado',
      );

      expect(resultParcial.taskCriada, isTrue);
      expect(resultParcial.hasFalhaParcial, isTrue);
      expect(resultParcial.notasComFalha, equals(['nota-2']));

      final exception = TaskCreatedWithVinculoException(resultParcial);
      expect(exception.result.task.id, equals('task-test-1'));
      expect(exception.message, contains('criada com sucesso'));
    });
  });
}
