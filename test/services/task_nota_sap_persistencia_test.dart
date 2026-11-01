import 'package:flutter_test/flutter_test.dart';

/// Simulação pura e em memória da lógica de persistência e cálculo de conjuntos
/// de NotaSapService.vincularNotasATarefaBatch e TaskService.createTask,
/// garantindo verificação das propriedades matemáticas de idempotência, rollback
/// seletivo e modelo relacional N:M.
class FakeTasksNotasSapRepository {
  // Tabela simulada: chave composta '$taskId|$notaSapId'
  final Set<String> _tabela = {};

  // Histórico de transações para auditoria
  final List<String> logOperacoes = [];

  bool simularErroNoLote = false;
  String? falharNoId;

  String _chave(String taskId, String notaSapId) => '$taskId|$notaSapId';

  /// Retorna os IDs das notas já vinculadas à tarefa (existentes)
  Set<String> buscarVinculosExistentes(String taskId, Iterable<String> notaSapIds) {
    return notaSapIds.where((notaId) => _tabela.contains(_chave(taskId, notaId))).toSet();
  }

  /// Espelha o algoritmo oficial de NotaSapService.vincularNotasATarefaBatch
  Future<List<String>> vincularNotasATarefaBatch({
    required String taskId,
    required List<String> notaSapIds,
  }) async {
    if (notaSapIds.isEmpty) return [];

    final solicitados = notaSapIds.toSet();
    final idsNovosInseridosComSucesso = <String>[];

    // 1. Identificar existentes
    final existentes = buscarVinculosExistentes(taskId, solicitados);

    // 2. Calcular novos
    final novos = solicitados.difference(existentes).toList();

    logOperacoes.add('TASK $taskId: solicitados=${solicitados.length}, existentes=${existentes.length}, novos=${novos.length}');

    if (novos.isEmpty) {
      return existentes.toList();
    }

    // 3. Inserir lote
    try {
      if (simularErroNoLote) {
        throw Exception('Simulação de falha de rede/PostgREST ao inserir lote');
      }

      for (final id in novos) {
        if (falharNoId != null && id == falharNoId) {
          throw Exception('Falha forçada na inserção da nota $id');
        }
        _tabela.add(_chave(taskId, id));
        idsNovosInseridosComSucesso.add(id);
      }

      return [...existentes, ...idsNovosInseridosComSucesso];
    } catch (e) {
      logOperacoes.add('ERRO no lote da TASK $taskId: $e');

      // Rollback Lógico Seletivo: reverte APENAS novos inseridos nesta execução
      // Vínculos existentes NUNCA são removidos!
      if (idsNovosInseridosComSucesso.isNotEmpty) {
        for (final id in idsNovosInseridosComSucesso) {
          _tabela.remove(_chave(taskId, id));
        }
        logOperacoes.add('ROLLBACK executado para ${idsNovosInseridosComSucesso.length} itens novos');
      }
      rethrow;
    }
  }

  int countVinculosDaTarefa(String taskId) {
    return _tabela.where((k) => k.startsWith('$taskId|')).length;
  }

  int countTarefasDaNota(String notaSapId) {
    return _tabela.where((k) => k.endsWith('|$notaSapId')).length;
  }

  bool existeVinculo(String taskId, String notaSapId) {
    return _tabela.contains(_chave(taskId, notaSapId));
  }
}

void main() {
  group('Seção 20: Testes de Persistência, Idempotência e Consistência (tasks_notas_sap)', () {
    late FakeTasksNotasSapRepository repo;

    setUp(() {
      repo = FakeTasksNotasSapRepository();
    });

    test('1. A → 1 vínculo criado', () async {
      final res = await repo.vincularNotasATarefaBatch(
        taskId: 'task-100',
        notaSapIds: ['nota-A'],
      );

      expect(res, equals(['nota-A']));
      expect(repo.countVinculosDaTarefa('task-100'), equals(1));
      expect(repo.existeVinculo('task-100', 'nota-A'), isTrue);
    });

    test('2. A+B → 2 vínculos criados em lote', () async {
      final res = await repo.vincularNotasATarefaBatch(
        taskId: 'task-100',
        notaSapIds: ['nota-A', 'nota-B'],
      );

      expect(res, containsAll(['nota-A', 'nota-B']));
      expect(repo.countVinculosDaTarefa('task-100'), equals(2));
      expect(repo.existeVinculo('task-100', 'nota-A'), isTrue);
      expect(repo.existeVinculo('task-100', 'nota-B'), isTrue);
    });

    test('3. A+B+C → exatamente 3 vínculos criados na mesma tarefa', () async {
      final res = await repo.vincularNotasATarefaBatch(
        taskId: 'task-100',
        notaSapIds: ['nota-A', 'nota-B', 'nota-C'],
      );

      expect(res, containsAll(['nota-A', 'nota-B', 'nota-C']));
      expect(repo.countVinculosDaTarefa('task-100'), equals(3));
      expect(repo.existeVinculo('task-100', 'nota-A'), isTrue);
      expect(repo.existeVinculo('task-100', 'nota-B'), isTrue);
      expect(repo.existeVinculo('task-100', 'nota-C'), isTrue);
    });

    test('4. Chamada duplicada com os mesmos IDs → Idempotente, continua 3', () async {
      await repo.vincularNotasATarefaBatch(
        taskId: 'task-100',
        notaSapIds: ['nota-A', 'nota-B', 'nota-C'],
      );
      expect(repo.countVinculosDaTarefa('task-100'), equals(3));

      // Segunda chamada com os mesmos IDs
      final res2 = await repo.vincularNotasATarefaBatch(
        taskId: 'task-100',
        notaSapIds: ['nota-A', 'nota-B', 'nota-C'],
      );

      // Deve retornar os 3 existentes sem adicionar duplicatas
      expect(res2.length, equals(3));
      expect(repo.countVinculosDaTarefa('task-100'), equals(3));
    });

    test('5. A já existente + B → mantém A e adiciona B (total 2)', () async {
      // Estado anterior: tarefa já vinculada à nota A
      await repo.vincularNotasATarefaBatch(
        taskId: 'task-100',
        notaSapIds: ['nota-A'],
      );
      expect(repo.countVinculosDaTarefa('task-100'), equals(1));

      // Nova operação solicitando [A, B]
      final res = await repo.vincularNotasATarefaBatch(
        taskId: 'task-100',
        notaSapIds: ['nota-A', 'nota-B'],
      );

      expect(res, containsAll(['nota-A', 'nota-B']));
      expect(repo.countVinculosDaTarefa('task-100'), equals(2));
      expect(repo.existeVinculo('task-100', 'nota-A'), isTrue);
      expect(repo.existeVinculo('task-100', 'nota-B'), isTrue);
    });

    test('6. Falha em novo vínculo → Rollback seletivo preserva os vínculos antigos', () async {
      // Pré-condição: Task 100 já possui vínculo com Nota A
      await repo.vincularNotasATarefaBatch(
        taskId: 'task-100',
        notaSapIds: ['nota-A'],
      );
      expect(repo.countVinculosDaTarefa('task-100'), equals(1));

      // Configurar falha proposital durante a inserção de C
      repo.falharNoId = 'nota-C';

      expect(
        () => repo.vincularNotasATarefaBatch(
          taskId: 'task-100',
          notaSapIds: ['nota-A', 'nota-B', 'nota-C'],
        ),
        throwsA(isA<Exception>()),
      );

      // Verificação de consistência:
      // Nota A (pré-existente) continua existindo!
      expect(repo.existeVinculo('task-100', 'nota-A'), isTrue);
      // Nota B (que havia sido inserida temporariamente no lote com erro) foi revertida pelo rollback!
      expect(repo.existeVinculo('task-100', 'nota-B'), isFalse);
      expect(repo.existeVinculo('task-100', 'nota-C'), isFalse);
      // Total na tabela continua exatamente 1 (o vínculo original A)
      expect(repo.countVinculosDaTarefa('task-100'), equals(1));
    });

    test('7. Edição de tarefa: adiciona apenas novos vínculos sem alterar os anteriores', () async {
      // Tarefa existente com [A, B]
      await repo.vincularNotasATarefaBatch(
        taskId: 'task-200',
        notaSapIds: ['nota-A', 'nota-B'],
      );
      expect(repo.countVinculosDaTarefa('task-200'), equals(2));

      // Usuário no formulário seleciona [A, B, C]
      final res = await repo.vincularNotasATarefaBatch(
        taskId: 'task-200',
        notaSapIds: ['nota-A', 'nota-B', 'nota-C'],
      );

      expect(res, containsAll(['nota-A', 'nota-B', 'nota-C']));
      expect(repo.countVinculosDaTarefa('task-200'), equals(3));
      // D continua fora
      expect(repo.existeVinculo('task-200', 'nota-D'), isFalse);
    });

    test('8. Relação N:M permanece válida: mesma Nota em duas tarefas distintas', () async {
      // Vincular Nota B na Tarefa 50
      await repo.vincularNotasATarefaBatch(
        taskId: 'task-50',
        notaSapIds: ['nota-B'],
      );

      // Vincular Nota B também na nova Tarefa 100 junto com Nota A
      await repo.vincularNotasATarefaBatch(
        taskId: 'task-100',
        notaSapIds: ['nota-A', 'nota-B'],
      );

      // Verificações N:M:
      // Nota B pertence a 2 tarefas
      expect(repo.countTarefasDaNota('nota-B'), equals(2));
      expect(repo.existeVinculo('task-50', 'nota-B'), isTrue);
      expect(repo.existeVinculo('task-100', 'nota-B'), isTrue);

      // Tarefa 100 tem 2 notas
      expect(repo.countVinculosDaTarefa('task-100'), equals(2));
      // Tarefa 50 tem 1 nota
      expect(repo.countVinculosDaTarefa('task-50'), equals(1));
    });
  });
}
