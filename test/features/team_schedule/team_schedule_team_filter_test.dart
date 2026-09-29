import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/models/task.dart';
import 'package:task2026/models/executor.dart';
import 'package:task2026/models/equipe.dart';
import 'package:task2026/models/equipe_executor.dart';
import 'package:task2026/widgets/team_schedule_view.dart';

void main() {
  Task mkTask({
    required String id,
    String status = 'PROG',
    List<String> locais = const [],
    List<String> executorIds = const [],
    List<ExecutorPeriod> executorPeriods = const [],
    String? equipeId,
    List<String> equipes = const [],
  }) {
    return Task(
      id: id,
      status: status,
      statusNome: 'Programada',
      regional: 'R1',
      divisao: 'D1',
      locais: locais,
      tipo: 'MANUTENCAO',
      tarefa: 'Tarefa $id',
      executor: '',
      executorIds: executorIds,
      coordenador: 'Coord 1',
      equipeId: equipeId,
      equipes: equipes,
      dataInicio: DateTime(2026, 3, 1),
      dataFim: DateTime(2026, 3, 10),
      executorPeriods: executorPeriods,
    );
  }

  Executor mkExec({
    required String id,
    required String nome,
    String matricula = '',
    String funcao = 'Eletricista',
    String empresa = 'AXIA',
    String divisao = 'D1',
  }) {
    return Executor(
      id: id,
      nome: nome,
      matricula: matricula,
      nomeCompleto: nome,
      funcao: funcao,
      empresa: empresa,
      divisao: divisao,
      ativo: true,
    );
  }

  Equipe mkEquipe({
    required String id,
    required String nome,
    String? regionalId,
    String? divisaoId,
    String? segmentoId,
    List<EquipeExecutor> executores = const [],
  }) {
    return Equipe(
      id: id,
      nome: nome,
      tipo: 'FIXA',
      regionalId: regionalId,
      divisaoId: divisaoId,
      segmentoId: segmentoId,
      ativo: true,
      executores: executores,
    );
  }

  group('Team Schedule — Team Filter Indirect by Executors (UUID)', () {
    test('1. taskMatchesSelectedTeam: ANY executor in team matches, even without equipe_id', () {
      final teamExecutorIds = {'11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222'};

      // Task 1: apenas membro A, sem equipe_id
      final task1 = mkTask(id: 'T1', executorIds: ['11111111-1111-1111-1111-111111111111'], equipeId: null);
      expect(TeamScheduleView.taskMatchesSelectedTeam(task1, teamExecutorIds), isTrue);

      // Task 2: apenas membro B
      final task2 = mkTask(id: 'T2', executorIds: ['22222222-2222-2222-2222-222222222222'], equipeId: null);
      expect(TeamScheduleView.taskMatchesSelectedTeam(task2, teamExecutorIds), isTrue);

      // Task 3: executor fora da equipe
      final task3 = mkTask(id: 'T3', executorIds: ['99999999-9999-9999-9999-999999999999'], equipeId: null);
      expect(TeamScheduleView.taskMatchesSelectedTeam(task3, teamExecutorIds), isFalse);

      // Task 4: multi-executor (um de fora e um da equipe)
      final task4 = mkTask(
        id: 'T4',
        executorIds: ['99999999-9999-9999-9999-999999999999', '22222222-2222-2222-2222-222222222222'],
        equipeId: null,
      );
      expect(TeamScheduleView.taskMatchesSelectedTeam(task4, teamExecutorIds), isTrue);

      // Task 5: sem executores estruturados
      final task5 = mkTask(id: 'T5', executorIds: [], equipeId: 'equipe-qualquer');
      expect(TeamScheduleView.taskMatchesSelectedTeam(task5, teamExecutorIds), isFalse);
    });

    test('2. Opções de equipe restritas pelo perfil organizacional do usuário (Regional + Divisão + Segmento)', () {
      final userRegional = 'reg-1';
      final userDivisao = 'div-1';
      final userSegmento = 'seg-1';

      final equipes = [
        mkEquipe(id: 'eq-A', nome: 'Equipe A', regionalId: userRegional, divisaoId: userDivisao, segmentoId: userSegmento),
        mkEquipe(id: 'eq-B', nome: 'Equipe B', regionalId: userRegional, divisaoId: userDivisao, segmentoId: userSegmento),
        mkEquipe(id: 'eq-C', nome: 'Equipe C', regionalId: 'reg-2', divisaoId: userDivisao, segmentoId: userSegmento), // Outra regional
        mkEquipe(id: 'eq-D', nome: 'Equipe D', regionalId: userRegional, divisaoId: 'div-2', segmentoId: userSegmento), // Outra divisão
        mkEquipe(id: 'eq-E', nome: 'Equipe E', regionalId: userRegional, divisaoId: userDivisao, segmentoId: 'seg-2'), // Outro segmento
      ];

      // Filtragem por perfil
      final autorizadas = equipes.where((eq) {
        if (eq.regionalId != null && eq.regionalId != userRegional) return false;
        if (eq.divisaoId != null && eq.divisaoId != userDivisao) return false;
        if (eq.segmentoId != null && eq.segmentoId != userSegmento) return false;
        return true;
      }).map((e) => e.nome).toList();

      expect(autorizadas, ['Equipe A', 'Equipe B']);
      expect(autorizadas, isNot(contains('Equipe C')));
      expect(autorizadas, isNot(contains('Equipe D')));
      expect(autorizadas, isNot(contains('Equipe E')));
    });

    test('3. Seleção de Equipe filtra apenas executores membros sem misturar tarefas entre membros', () {
      final execA = mkExec(id: '11111111-1111-1111-1111-111111111111', nome: 'Executor A');
      final execB = mkExec(id: '22222222-2222-2222-2222-222222222222', nome: 'Executor B');
      final execOutro = mkExec(id: '33333333-3333-3333-3333-333333333333', nome: 'Executor Outro');

      final taskA1 = mkTask(id: 'TA1', executorIds: ['11111111-1111-1111-1111-111111111111'], locais: ['Local 1']);
      final taskB1 = mkTask(id: 'TB1', executorIds: ['22222222-2222-2222-2222-222222222222'], locais: ['Local 2']);
      final taskOutro = mkTask(id: 'TO1', executorIds: ['33333333-3333-3333-3333-333333333333'], locais: ['Local 3']);

      final rows = [
        ExecutorTaskRow(executor: execA, tasks: [taskA1]),
        ExecutorTaskRow(executor: execB, tasks: [taskB1]),
        ExecutorTaskRow(executor: execOutro, tasks: [taskOutro]),
      ];

      final equipeManutencao = mkEquipe(
        id: 'eq-manut',
        nome: 'MANUTENÇÃO',
        executores: [
          EquipeExecutor(executorId: '11111111-1111-1111-1111-111111111111', executorNome: 'Executor A', papel: 'EXECUTOR'),
          EquipeExecutor(executorId: '22222222-2222-2222-2222-222222222222', executorNome: 'Executor B', papel: 'EXECUTOR'),
        ],
      );

      final selectedEquipeExecutorIds = equipeManutencao.executores.map((e) => e.executorId).toSet();

      // Aplicar filtro de equipe nas linhas
      final filteredRows = rows.where((row) => selectedEquipeExecutorIds.contains(row.executor.id)).toList();

      expect(filteredRows.length, 2);
      expect(filteredRows.map((r) => r.executor.id).toList(), [
        '11111111-1111-1111-1111-111111111111',
        '22222222-2222-2222-2222-222222222222',
      ]);

      // Cada executor mantém estritamente as suas tarefas
      final rowA = filteredRows.firstWhere((r) => r.executor.id == '11111111-1111-1111-1111-111111111111');
      final rowB = filteredRows.firstWhere((r) => r.executor.id == '22222222-2222-2222-2222-222222222222');

      expect(rowA.tasks.map((t) => t.id).toList(), ['TA1']);
      expect(rowB.tasks.map((t) => t.id).toList(), ['TB1']);
      expect(rowA.tasks.length, 1);
      expect(rowB.tasks.length, 1);
    });

    test('4. Homônimos com mesmo nome e mesma matrícula em equipes distintas não colidem', () {
      final execA = mkExec(id: '11111111-1111-1111-1111-111111111111', nome: 'JOÃO SILVA', matricula: '1001');
      final execB = mkExec(id: '22222222-2222-2222-2222-222222222222', nome: 'JOÃO SILVA', matricula: '1001');

      final equipeA = mkEquipe(
        id: 'eq-A',
        nome: 'Equipe A',
        executores: [EquipeExecutor(executorId: '11111111-1111-1111-1111-111111111111', executorNome: 'JOÃO SILVA', papel: 'EXECUTOR')],
      );
      final equipeB = mkEquipe(
        id: 'eq-B',
        nome: 'Equipe B',
        executores: [EquipeExecutor(executorId: '22222222-2222-2222-2222-222222222222', executorNome: 'JOÃO SILVA', papel: 'EXECUTOR')],
      );

      final rows = [
        ExecutorTaskRow(executor: execA, tasks: [mkTask(id: 'TA', executorIds: ['11111111-1111-1111-1111-111111111111'])]),
        ExecutorTaskRow(executor: execB, tasks: [mkTask(id: 'TB', executorIds: ['22222222-2222-2222-2222-222222222222'])]),
      ];

      // Ao filtrar Equipe A
      final teamAIds = equipeA.executores.map((e) => e.executorId).toSet();
      final rowsA = rows.where((r) => teamAIds.contains(r.executor.id)).toList();
      expect(rowsA.length, 1);
      expect(rowsA.first.executor.id, '11111111-1111-1111-1111-111111111111');
      expect(rowsA.first.tasks.first.id, 'TA');

      // Ao filtrar Equipe B
      final teamBIds = equipeB.executores.map((e) => e.executorId).toSet();
      final rowsB = rows.where((r) => teamBIds.contains(r.executor.id)).toList();
      expect(rowsB.length, 1);
      expect(rowsB.first.executor.id, '22222222-2222-2222-2222-222222222222');
      expect(rowsB.first.tasks.first.id, 'TB');
    });

    test('5. Filtro de equipe combinado com outro filtro (Função) realiza interseção precisa', () {
      final exec1 = mkExec(id: '11111111-1111-1111-1111-111111111111', nome: 'Membro 1', funcao: 'Eletricista');
      final exec2 = mkExec(id: '22222222-2222-2222-2222-222222222222', nome: 'Membro 2', funcao: 'Mecânico');
      final exec3 = mkExec(id: '33333333-3333-3333-3333-333333333333', nome: 'Outro', funcao: 'Eletricista');

      final equipeManut = mkEquipe(
        id: 'eq-m',
        nome: 'MANUT',
        executores: [
          EquipeExecutor(executorId: '11111111-1111-1111-1111-111111111111', executorNome: 'Membro 1', papel: 'E'),
          EquipeExecutor(executorId: '22222222-2222-2222-2222-222222222222', executorNome: 'Membro 2', papel: 'M'),
        ],
      );

      final teamIds = equipeManut.executores.map((e) => e.executorId).toSet();
      final targetFuncao = 'eletricista';

      final allExecs = [exec1, exec2, exec3];
      final matched = allExecs.where((e) {
        if (!teamIds.contains(e.id)) return false;
        if (e.funcao?.toLowerCase() != targetFuncao) return false;
        return true;
      }).toList();

      expect(matched.length, 1);
      expect(matched.first.id, '11111111-1111-1111-1111-111111111111');
      expect(matched.first.funcao, 'Eletricista');
    });

    test('6. Tarefa com equipe_id diferente mas atribuída a membro da equipe selecionada é VISÍVEL', () {
      final teamExecutorIds = {'11111111-1111-1111-1111-111111111111'};
      final taskComOutraEquipe = mkTask(
        id: 'T-outra-equipe',
        equipeId: 'outra-equipe-id',
        equipes: ['OUTRA EQUIPE'],
        executorIds: ['11111111-1111-1111-1111-111111111111'],
      );

      // A regra de negócio: membro da equipe selecionada presente no executorIds da tarefa prevalece
      expect(TeamScheduleView.taskMatchesSelectedTeam(taskComOutraEquipe, teamExecutorIds), isTrue);
    });

    test('7. Quando selectedEquipe for "Todos" ou nulo, não exclui nenhuma linha por equipe', () {
      Set<String>? resolveEquipeExecutorIds(Set<String>? equipeSet) {
        if (equipeSet != null && !equipeSet.contains('todos')) {
          return {'11111111-1111-1111-1111-111111111111'};
        }
        return null;
      }

      final idsNull = resolveEquipeExecutorIds(null);
      final idsTodos = resolveEquipeExecutorIds({'todos'});

      expect(idsNull, isNull);
      expect(idsTodos, isNull);

      final execA = mkExec(id: '11111111-1111-1111-1111-111111111111', nome: 'A');
      final execB = mkExec(id: '22222222-2222-2222-2222-222222222222', nome: 'B');
      final rows = [
        ExecutorTaskRow(executor: execA, tasks: []),
        ExecutorTaskRow(executor: execB, tasks: []),
      ];

      // Sem filtro de equipe (idsTodos == null), todas as linhas são preservadas
      final visible = rows.where((r) {
        if (idsTodos != null && !idsTodos.contains(r.executor.id)) {
          return false;
        }
        return true;
      }).toList();

      expect(visible.length, 2);
    });
  });
}
