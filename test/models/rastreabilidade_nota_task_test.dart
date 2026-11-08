import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/models/backlog_macro_models.dart';

void main() {
  group('Rastreabilidade Nota SAP ↔ Task — Testes de Model e Regras de Negócio', () {
    test('Item 48/52: 0 Tasks e 1 Task CANC -> isProgramada deve ser false', () {
      const notaSemTask = BacklogNotaItem(
        id: 'n0',
        nota: '1000',
        descricao: 'Sem task',
        tasks: [],
      );
      expect(notaSemTask.isProgramada, isFalse);
      expect(notaSemTask.taskProgramacaoAtual, isNull);

      final notaCanc = BacklogNotaItem(
        id: 'n1',
        nota: '1001',
        descricao: 'Com task cancelada',
        tasks: [
          BacklogTaskInfo(
            id: 't-canc',
            status: 'CANC',
            dataInicio: DateTime(2026, 11, 10),
          ),
        ],
      );
      // Item 15 e 52: CANC NÃO torna Nota programada
      expect(notaCanc.isProgramada, isFalse);
      expect(notaCanc.taskProgramacaoAtual?.status, equals('CANC'));
      expect(notaCanc.taskProgramacaoAtual?.isCancelada, isTrue);
    });

    test('Item 48/49: Hierarquia determinística de taskProgramacaoAtual: ANDA > PROG > CONC > CANC', () {
      final tCanc = BacklogTaskInfo(id: 't-canc', status: 'CANC', dataInicio: DateTime(2026, 10, 1));
      final tConc = BacklogTaskInfo(id: 't-conc', status: 'CONC', dataInicio: DateTime(2026, 10, 15), dataFim: DateTime(2026, 10, 16));
      final tProg = BacklogTaskInfo(id: 't-prog', status: 'PROG', dataInicio: DateTime(2026, 11, 20));
      final tAnda = BacklogTaskInfo(id: 't-anda', status: 'ANDA', dataInicio: DateTime(2026, 11, 25));

      // 1 PROG isolada
      final notaProg = BacklogNotaItem(id: 'n1', nota: '1', descricao: 'd', tasks: [tProg]);
      expect(notaProg.isProgramada, isTrue);
      expect(notaProg.taskProgramacaoAtual?.id, equals('t-prog'));

      // 1 ANDA isolada
      final notaAnda = BacklogNotaItem(id: 'n2', nota: '2', descricao: 'd', tasks: [tAnda]);
      expect(notaAnda.isProgramada, isTrue);
      expect(notaAnda.taskProgramacaoAtual?.id, equals('t-anda'));

      // 1 CONC isolada
      final notaConc = BacklogNotaItem(id: 'n3', nota: '3', descricao: 'd', tasks: [tConc]);
      expect(notaConc.isProgramada, isTrue);
      expect(notaConc.taskProgramacaoAtual?.id, equals('t-conc'));

      // PROG + CANC -> PROG vence
      final notaProgCanc = BacklogNotaItem(id: 'n4', nota: '4', descricao: 'd', tasks: [tCanc, tProg]);
      expect(notaProgCanc.isProgramada, isTrue);
      expect(notaProgCanc.taskProgramacaoAtual?.id, equals('t-prog'));

      // ANDA + PROG -> ANDA vence
      final notaAndaProg = BacklogNotaItem(id: 'n5', nota: '5', descricao: 'd', tasks: [tProg, tAnda]);
      expect(notaAndaProg.taskProgramacaoAtual?.id, equals('t-anda'));

      // ANDA + PROG + CONC + CANC -> ANDA vence
      final notaTodas = BacklogNotaItem(id: 'n6', nota: '6', descricao: 'd', tasks: [tCanc, tConc, tProg, tAnda]);
      expect(notaTodas.taskProgramacaoAtual?.id, equals('t-anda'));

      // PROG + CONC -> PROG vence
      final notaProgConc2 = BacklogNotaItem(id: 'n7', nota: '7', descricao: 'd', tasks: [tConc, tProg]);
      expect(notaProgConc2.taskProgramacaoAtual?.id, equals('t-prog'));

      // CONC + CANC -> CONC vence
      final notaConcCanc = BacklogNotaItem(id: 'n8', nota: '8', descricao: 'd', tasks: [tCanc, tConc]);
      expect(notaConcCanc.taskProgramacaoAtual?.id, equals('t-conc'));
    });

    test('Item 48/53: RPAR + RPGR determinístico e preservação de todas as tasks na lista', () {
      final tRpgr = BacklogTaskInfo(id: 't-rpgr', status: 'RPGR', dataInicio: DateTime(2026, 11, 10));
      final tRpar = BacklogTaskInfo(id: 't-rpar', status: 'RPAR', dataInicio: DateTime(2026, 11, 20));

      final notaMulti = BacklogNotaItem(
        id: 'n-multi',
        nota: '202611',
        descricao: 'Multiplas tasks',
        tasks: [tRpgr, tRpar],
      );

      // Preserva TODAS as tasks na lista (Item 12 e 53)
      expect(notaMulti.tasks.length, equals(2));
      expect(notaMulti.tasks[0].id, equals('t-rpgr'));
      expect(notaMulti.tasks[1].id, equals('t-rpar'));

      // Escolhe determinística a mais recente (20/11 > 10/11)
      expect(notaMulti.taskProgramacaoAtual?.id, equals('t-rpar'));
    });

    test('Item 50: Classificação Temporal — Mesmo mês, Antes, Depois, Sem Previsão e Sem Task', () {
      final tNov = BacklogTaskInfo(id: 't-nov', status: 'PROG', dataInicio: DateTime(2026, 11, 15));
      final tDez = BacklogTaskInfo(id: 't-dez', status: 'PROG', dataInicio: DateTime(2026, 12, 5));
      final tOut = BacklogTaskInfo(id: 't-out', status: 'PROG', dataInicio: DateTime(2026, 10, 20));

      // 1. Mesmo mês (Nov/2026 e Task Nov/2026) -> conformePrevisao
      final nMesmoMes = BacklogNotaItem(id: 'n1', nota: '1', descricao: 'd', mesPrevisto: 11, anoPrevisto: 2026, tasks: [tNov]);
      expect(nMesmoMes.classificarDivergencia(), equals(DivergenciaPrevisaoTask.conformePrevisao));
      expect(nMesmoMes.classificarDivergencia().rotulo, equals('Programada conforme previsão'));

      // 2. Depois (Previsão Nov/2026, Task Dez/2026) -> aposPrevisao
      final nDepois = BacklogNotaItem(id: 'n2', nota: '2', descricao: 'd', mesPrevisto: 11, anoPrevisto: 2026, tasks: [tDez]);
      expect(nDepois.classificarDivergencia(), equals(DivergenciaPrevisaoTask.aposPrevisao));
      expect(nDepois.classificarDivergencia().rotulo, equals('⚠ Programada após a previsão'));

      // 3. Antes (Previsão Nov/2026, Task Out/2026) -> antecipada
      final nAntes = BacklogNotaItem(id: 'n3', nota: '3', descricao: 'd', mesPrevisto: 11, anoPrevisto: 2026, tasks: [tOut]);
      expect(nAntes.classificarDivergencia(), equals(DivergenciaPrevisaoTask.antecipada));
      expect(nAntes.classificarDivergencia().rotulo, equals('⚡ Antecipada em relação à previsão'));

      // 4. Sem Previsão (Previsão null, Task válida Nov/2026) -> programadaSemPrevisaoMacro
      final nSemPrev = BacklogNotaItem(id: 'n4', nota: '4', descricao: 'd', mesPrevisto: null, anoPrevisto: null, tasks: [tNov]);
      expect(nSemPrev.classificarDivergencia(), equals(DivergenciaPrevisaoTask.programadaSemPrevisaoMacro));
      expect(nSemPrev.classificarDivergencia().rotulo, equals('Programada sem previsão macro'));

      // 5. Sem Task (Previsão Nov/2026, Tasks vazias) -> previstaNaoProgramada
      final nSemTask = BacklogNotaItem(id: 'n5', nota: '5', descricao: 'd', mesPrevisto: 11, anoPrevisto: 2026, tasks: []);
      expect(nSemTask.classificarDivergencia(), equals(DivergenciaPrevisaoTask.previstaNaoProgramada));
      expect(nSemTask.classificarDivergencia().rotulo, equals('Prevista, não programada'));

      // 6. Nem Previsão nem Task -> semPrevisao
      final nNemPrevNemTask = BacklogNotaItem(id: 'n6', nota: '6', descricao: 'd', mesPrevisto: null, anoPrevisto: null, tasks: []);
      expect(nNemPrevNemTask.classificarDivergencia(), equals(DivergenciaPrevisaoTask.semPrevisao));
      expect(nNemPrevNemTask.classificarDivergencia().rotulo, equals('Sem previsão'));
    });

    test('Item 51: Classificação Temporal — Teste de Virada de Ano (Dez/2026 ↔ Jan/2027)', () {
      final tJan2027 = BacklogTaskInfo(id: 't-jan', status: 'PROG', dataInicio: DateTime(2027, 1, 10));
      final tDez2026 = BacklogTaskInfo(id: 't-dez', status: 'PROG', dataInicio: DateTime(2026, 12, 20));

      // Caso A: Previsão Dez/2026 -> Task Jan/2027 (Dez/2026 para Jan/2027 é aposPrevisao)
      final nDezParaJan = BacklogNotaItem(
        id: 'nA',
        nota: 'A',
        descricao: 'd',
        mesPrevisto: 12,
        anoPrevisto: 2026,
        tasks: [tJan2027],
      );
      expect(nDezParaJan.classificarDivergencia(), equals(DivergenciaPrevisaoTask.aposPrevisao));

      // Caso B: Previsão Jan/2027 -> Task Dez/2026 (Jan/2027 para Dez/2026 é antecipada)
      final nJanParaDez = BacklogNotaItem(
        id: 'nB',
        nota: 'B',
        descricao: 'd',
        mesPrevisto: 1,
        anoPrevisto: 2027,
        tasks: [tDez2026],
      );
      expect(nJanParaDez.classificarDivergencia(), equals(DivergenciaPrevisaoTask.antecipada));
    });

    test('Item 26/52: Task CANC com Previsão NÃO conta como programação válida', () {
      final tCanc = BacklogTaskInfo(id: 't-canc', status: 'CANC', dataInicio: DateTime(2026, 11, 15));
      final notaComCanc = BacklogNotaItem(
        id: 'n-canc',
        nota: '999',
        descricao: 'Cancelada com previsao',
        mesPrevisto: 11,
        anoPrevisto: 2026,
        tasks: [tCanc],
      );

      // Como a única task é cancelada, a nota é tratada como Prevista, NÃO programada
      expect(notaComCanc.classificarDivergencia(), equals(DivergenciaPrevisaoTask.previstaNaoProgramada));
      expect(notaComCanc.isProgramada, isFalse);
    });
  });
}
