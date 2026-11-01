import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/models/backlog_macro_models.dart';
import 'package:task2026/models/nota_sap_grupo.dart';
import 'package:task2026/services/nota_sap_backlog_service.dart';

void main() {
  group('Backlog Macro - Modelos e Regras de Negócio', () {
    test('1. Helper chunkList particiona corretamente com chunks de 200', () {
      final list = List.generate(450, (i) => 'id_$i');
      final chunks = chunkList(list, 200);

      expect(chunks.length, 3);
      expect(chunks[0].length, 200);
      expect(chunks[1].length, 200);
      expect(chunks[2].length, 50);
    });

    test('2. Nota é PROGRAMADA quando possui Task com status PROG, ANDA, CONC, RPAR, RPGR', () {
      for (final status in ['PROG', 'ANDA', 'CONC', 'RPAR', 'RPGR', 'prog', 'Conc']) {
        final nota = BacklogNotaItem(
          id: 'n1',
          nota: '11000001',
          descricao: 'Substituição DJ',
          tasks: [
            BacklogTaskInfo(id: 't1', status: status),
          ],
        );
        expect(nota.isProgramada, isTrue, reason: 'Status $status deve ser considerado programado');
        expect(nota.isPendente, isFalse);
      }
    });

    test('3. Nota é PENDENTE quando Task possui status CANC', () {
      final nota = BacklogNotaItem(
        id: 'n1',
        nota: '11000001',
        descricao: 'Substituição DJ',
        tasks: [
          const BacklogTaskInfo(id: 't1', status: 'CANC'),
        ],
      );
      expect(nota.isProgramada, isFalse);
      expect(nota.isPendente, isTrue);
      expect(nota.tasksCanceladas.length, 1);
      expect(nota.tasksValidas.isEmpty, isTrue);
    });

    test('4. Nota é PENDENTE quando status for desconhecido (regra conservadora)', () {
      final nota = BacklogNotaItem(
        id: 'n1',
        nota: '11000001',
        descricao: 'Substituição DJ',
        tasks: [
          const BacklogTaskInfo(id: 't1', status: 'STATUS_NOVO_INEXISTENTE'),
        ],
      );
      expect(nota.isProgramada, isFalse);
      expect(nota.isPendente, isTrue);
    });

    test('5. Múltiplas Tasks: CANC + PROG resulta em PROGRAMADA', () {
      final nota = BacklogNotaItem(
        id: 'n1',
        nota: '11000001',
        descricao: 'Substituição DJ',
        tasks: [
          const BacklogTaskInfo(id: 't1', status: 'CANC'),
          const BacklogTaskInfo(id: 't2', status: 'PROG'),
        ],
      );
      expect(nota.isProgramada, isTrue);
      expect(nota.tasksValidas.length, 1);
      expect(nota.tasksCanceladas.length, 1);
    });

    test('6. Grupo StatusProgramacao: naoProgramado, parcial e total', () {
      final n1 = const BacklogNotaItem(id: 'n1', nota: '1', descricao: 'd1');
      final n2 = const BacklogNotaItem(
        id: 'n2',
        nota: '2',
        descricao: 'd2',
        tasks: [BacklogTaskInfo(id: 't1', status: 'PROG')],
      );

      final gNaoProg = BacklogGrupoItem(
        id: 'g1',
        nome: 'Grupo 1',
        statusGrupo: 'ativo',
        notas: [n1],
      );
      expect(gNaoProg.statusProgramacao, StatusProgramacaoGrupo.naoProgramado);
      expect(gNaoProg.percentualProgramado, 0.0);

      final gParcial = BacklogGrupoItem(
        id: 'g2',
        nome: 'Grupo 2',
        statusGrupo: 'ativo',
        notas: [n1, n2],
      );
      expect(gParcial.statusProgramacao, StatusProgramacaoGrupo.parcial);
      expect(gParcial.percentualProgramado, 50.0);

      final gTotal = BacklogGrupoItem(
        id: 'g3',
        nome: 'Grupo 3',
        statusGrupo: 'ativo',
        notas: [n2],
      );
      expect(gTotal.statusProgramacao, StatusProgramacaoGrupo.total);
      expect(gTotal.percentualProgramado, 100.0);
    });

    test('7. Cálculo de estimativas de horas totais e pendentes e cobertura', () {
      final n1 = const BacklogNotaItem(
        id: 'n1',
        nota: '1',
        descricao: 'd1',
        estimativaHoras: 10.0, // pendente
      );
      final n2 = const BacklogNotaItem(
        id: 'n2',
        nota: '2',
        descricao: 'd2',
        estimativaHoras: 25.5,
        tasks: [BacklogTaskInfo(id: 't1', status: 'PROG')], // programada
      );
      final n3 = const BacklogNotaItem(
        id: 'n3',
        nota: '3',
        descricao: 'd3', // sem estimativa
      );

      final grupo = BacklogGrupoItem(
        id: 'g1',
        nome: 'Grupo Teste',
        statusGrupo: 'ativo',
        notas: [n1, n2, n3],
      );

      expect(grupo.somaEstimativaTotal, 35.5);
      expect(grupo.somaEstimativaPendente, 10.0);
      expect(grupo.notasComEstimativa, 2);
      expect(grupo.notasSemEstimativa, 1);
    });

    test('8. Previsão Ultrapassada só é verdadeira se mês < atual E houver notas pendentes', () {
      final refTime = DateTime(2026, 11, 15);

      final nPendente = const BacklogNotaItem(id: 'n1', nota: '1', descricao: 'd1');
      final nProg = const BacklogNotaItem(
        id: 'n2',
        nota: '2',
        descricao: 'd2',
        tasks: [BacklogTaskInfo(id: 't1', status: 'PROG')],
      );

      // Mês anterior (Out/26) com pendente -> Ultrapassado
      final gAtrasado = BacklogGrupoItem(
        id: 'g1',
        nome: 'Grupo Outubro',
        mesProgramacaoPrevisto: 10,
        anoProgramacaoPrevisto: 2026,
        statusGrupo: 'ativo',
        notas: [nPendente],
      );
      expect(gAtrasado.isPrevisaoUltrapassada(refTime), isTrue);

      // Mês anterior (Out/26) mas 100% programado -> NÃO é ultrapassado
      final gConcluido = BacklogGrupoItem(
        id: 'g2',
        nome: 'Grupo Outubro Concluido',
        mesProgramacaoPrevisto: 10,
        anoProgramacaoPrevisto: 2026,
        statusGrupo: 'ativo',
        notas: [nProg],
      );
      expect(gConcluido.isPrevisaoUltrapassada(refTime), isFalse);

      // Mês futuro (Dez/26) -> NÃO é ultrapassado
      final gFuturo = BacklogGrupoItem(
        id: 'g3',
        nome: 'Grupo Dezembro',
        mesProgramacaoPrevisto: 12,
        anoProgramacaoPrevisto: 2026,
        statusGrupo: 'ativo',
        notas: [nPendente],
      );
      expect(gFuturo.isPrevisaoUltrapassada(refTime), isFalse);

      // Sem previsão -> NÃO é ultrapassado
      final gSemPrev = BacklogGrupoItem(
        id: 'g4',
        nome: 'Grupo Sem Prev',
        statusGrupo: 'ativo',
        notas: [nPendente],
      );
      expect(gSemPrev.isPrevisaoUltrapassada(refTime), isFalse);
    });

    test('9. Primeira Nota Pendente retorna corretamente a primeira nota com isPendente true', () {
      final n1 = const BacklogNotaItem(
        id: 'n1',
        nota: '111',
        descricao: 'd1',
        tasks: [BacklogTaskInfo(id: 't1', status: 'PROG')],
      );
      final n2 = const BacklogNotaItem(
        id: 'n2',
        nota: '222',
        descricao: 'd2',
      );
      final n3 = const BacklogNotaItem(
        id: 'n3',
        nota: '333',
        descricao: 'd3',
      );

      final grupo = BacklogGrupoItem(
        id: 'g1',
        nome: 'G',
        statusGrupo: 'ativo',
        notas: [n1, n2, n3],
      );

      expect(grupo.primeiraNotaPendente?.id, 'n2');
    });

    test('10. Resumo Mensal agrega métricas de múltiplos grupos com consistência', () {
      final n1 = const BacklogNotaItem(id: 'n1', nota: '1', descricao: 'd1', estimativaHoras: 8.0);
      final n2 = const BacklogNotaItem(
        id: 'n2',
        nota: '2',
        descricao: 'd2',
        estimativaHoras: 12.0,
        tasks: [BacklogTaskInfo(id: 't1', status: 'PROG')],
      );

      final g1 = BacklogGrupoItem(
        id: 'g1',
        nome: 'G1',
        statusGrupo: 'ativo',
        notas: [n1],
      );
      final g2 = BacklogGrupoItem(
        id: 'g2',
        nome: 'G2',
        statusGrupo: 'ativo',
        notas: [n2],
      );

      final mensal = BacklogMensalResumo(
        mes: 11,
        ano: 2026,
        grupos: [g1, g2],
      );

      expect(mensal.totalGrupos, 2);
      expect(mensal.totalNotas, 2);
      expect(mensal.notasProgramadas, 1);
      expect(mensal.notasPendentes, 1);
      expect(mensal.percentualProgramado, 50.0);
      expect(mensal.somaEstimativasTotal, 20.0);
      expect(mensal.somaEstimativasPendentes, 8.0);
      expect(mensal.notasComEstimativa, 2);
    });
  });
}
