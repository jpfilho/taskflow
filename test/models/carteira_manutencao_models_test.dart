import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/models/backlog_macro_models.dart';
import 'package:task2026/models/carteira_manutencao_models.dart';
import 'package:task2026/models/nota_sap.dart';
import 'package:task2026/models/nota_sap_grupo.dart';

void main() {
  group('Classificação de Risco e Prazo (7 Situações Formais)', () {
    final ref = DateTime(2027, 3, 10); // Referência: 10/Março/2027

    test('SIT-1: Previsão anterior ao mês do prazo (Compatível)', () {
      final sit = SituacaoPrazoCarteira.classificar(
        dataVencimento: DateTime(2027, 6, 15),
        diasRestantes: 97,
        mesPrevisto: 4, // Abril/2027 < Junho/2027
        anoPrevisto: 2027,
        isProgramada: false,
        dataReferencia: ref,
      );
      expect(sit, SituacaoPrazoCarteira.sit1Compativel);
    });

    test('SIT-2: Previsão no mesmo mês do prazo (Risco de Incerteza Temporal)', () {
      final sit = SituacaoPrazoCarteira.classificar(
        dataVencimento: DateTime(2027, 5, 10),
        diasRestantes: 61,
        mesPrevisto: 5, // Maio/2027 == Maio/2027
        anoPrevisto: 2027,
        isProgramada: false,
        dataReferencia: ref,
      );
      expect(sit, SituacaoPrazoCarteira.sit2RiscoTemporal);
      expect(sit.codigo, 'SIT-2');
    });

    test('SIT-3: Previsão posterior ao mês do prazo (Violação / Descumprimento Previsto)', () {
      final sit = SituacaoPrazoCarteira.classificar(
        dataVencimento: DateTime(2027, 4, 15),
        diasRestantes: 36,
        mesPrevisto: 8, // Agosto/2027 > Abril/2027
        anoPrevisto: 2027,
        isProgramada: false,
        dataReferencia: ref,
      );
      expect(sit, SituacaoPrazoCarteira.sit3ViolacaoPrevista);
      expect(sit.codigo, 'SIT-3');
    });

    test('SIT-4: Prazo vencido por diasRestantes negativo', () {
      final sit = SituacaoPrazoCarteira.classificar(
        dataVencimento: DateTime(2027, 3, 5),
        diasRestantes: -5,
        mesPrevisto: 5,
        anoPrevisto: 2027,
        isProgramada: false,
        dataReferencia: ref,
      );
      expect(sit, SituacaoPrazoCarteira.sit4PrazoVencido);
    });

    test('SIT-4: Prazo vencido por dataVencimento anterior à data de referência', () {
      final sit = SituacaoPrazoCarteira.classificar(
        dataVencimento: DateTime(2027, 2, 28),
        diasRestantes: null,
        mesPrevisto: 4,
        anoPrevisto: 2027,
        isProgramada: false,
        dataReferencia: ref,
      );
      expect(sit, SituacaoPrazoCarteira.sit4PrazoVencido);
    });

    test('SIT-5: Sem prazo conhecido com ou sem previsão', () {
      final sitSemPrev = SituacaoPrazoCarteira.classificar(
        dataVencimento: null,
        diasRestantes: null,
        mesPrevisto: null,
        anoPrevisto: null,
        isProgramada: false,
        dataReferencia: ref,
      );
      expect(sitSemPrev, SituacaoPrazoCarteira.sit5SemPrazoConhecido);

      final sitComPrev = SituacaoPrazoCarteira.classificar(
        dataVencimento: null,
        diasRestantes: null,
        mesPrevisto: 10,
        anoPrevisto: 2027,
        isProgramada: false,
        dataReferencia: ref,
      );
      expect(sitComPrev, SituacaoPrazoCarteira.sit5SemPrazoConhecido);
    });

    test('SIT-6: Previsão ultrapassada e não programada', () {
      final sit = SituacaoPrazoCarteira.classificar(
        dataVencimento: DateTime(2027, 12, 1),
        diasRestantes: 266,
        mesPrevisto: 1, // Janeiro/2027 < Março/2027
        anoPrevisto: 2027,
        isProgramada: false,
        dataReferencia: ref,
      );
      expect(sit, SituacaoPrazoCarteira.sit6PrevisaoUltrapassada);
    });

    test('SIT-6 NÃO ocorre se a nota com previsão antiga já estiver programada', () {
      final sit = SituacaoPrazoCarteira.classificar(
        dataVencimento: DateTime(2027, 12, 1),
        diasRestantes: 266,
        mesPrevisto: 1,
        anoPrevisto: 2027,
        isProgramada: true, // Já programada!
        dataReferencia: ref,
      );
      // Como está programada, avalia a relação com o prazo (Janeiro < Dezembro = compatível)
      expect(sit, SituacaoPrazoCarteira.sit1Compativel);
    });

    test('SIT-7: Sem previsão e prazo próximo (<= 60 dias)', () {
      final sit = SituacaoPrazoCarteira.classificar(
        dataVencimento: DateTime(2027, 4, 15),
        diasRestantes: 36, // <= 60 dias
        mesPrevisto: null,
        anoPrevisto: null,
        isProgramada: false,
        dataReferencia: ref,
      );
      expect(sit, SituacaoPrazoCarteira.sit7SemPrevisaoPrazoProximo);
    });
  });

  group('Regras Centralizadas de Status e Pendência da Nota SAP', () {
    test('Nota com MSPN ou MSPR sem termos de conclusão é considerada ABERTA', () {
      final n1 = NotaSAP(id: '1', nota: '1001', statusSistema: 'MSPN');
      final n2 = NotaSAP(id: '2', nota: '1002', statusSistema: 'MSPR ORDA');
      expect(n1.estaAberta, isTrue);
      expect(n1.estaConcluida, isFalse);
      expect(n2.estaAberta, isTrue);
    });

    test('Nota com MSEN, CONC, ENCE ou CANC é considerada CONCLUÍDA / NÃO PENDENTE', () {
      final n1 = NotaSAP(id: '1', nota: '2001', statusSistema: 'MSEN');
      final n2 = NotaSAP(id: '2', nota: '2002', statusSistema: 'MSPR CONC');
      final n3 = NotaSAP(id: '3', nota: '2003', statusSistema: 'MSPN ENCE');
      final n4 = NotaSAP(id: '4', nota: '2004', statusSistema: 'MSPR CANC');

      expect(n1.estaAberta, isFalse);
      expect(n1.estaConcluida, isTrue);
      expect(n2.estaAberta, isFalse);
      expect(n3.estaAberta, isFalse);
      expect(n4.estaAberta, isFalse);
    });
  });

  group('Cálculo dos Indicadores da Carteira (CarteiraIndicadores)', () {
    test('Calcula cobertura de previsibilidade e agrupadas vs avulsas com rigor matemático', () {
      // 10 notas pendentes:
      // - 4 em grupo com previsão (Out/27)
      // - 2 em grupo sem previsão
      // - 1 avulsa com previsão direta (Nov/27)
      // - 3 avulsas sem previsão
      final grupoComPrev = NotaSapGrupo(
        id: 'g1',
        nome: 'Grupo Subestação Alpha',
        statusGrupo: StatusGrupo.ativo,
        mesProgramacaoPrevisto: 10,
        anoProgramacaoPrevisto: 2027,
      );

      final grupoSemPrev = NotaSapGrupo(
        id: 'g2',
        nome: 'Grupo Transformadores',
        statusGrupo: StatusGrupo.ativo,
        mesProgramacaoPrevisto: null,
        anoProgramacaoPrevisto: null,
      );

      final itens = <CarteiraItem>[
        // 4 notas no grupo g1
        for (var i = 1; i <= 4; i++)
          CarteiraItem(
            nota: NotaSAP(id: 'n$i', nota: '100$i', statusSistema: 'MSPN'),
            previsao: CarteiraPrevisao(
              mes: 10,
              ano: 2027,
              origem: OrigemPrevisao.grupo,
              origemId: 'g1',
              origemNome: grupoComPrev.nome,
            ),
            grupoId: 'g1',
            grupoNome: grupoComPrev.nome,
            estimativaHoras: 10.0,
            situacaoPrazo: SituacaoPrazoCarteira.sit1Compativel,
          ),

        // 2 notas no grupo g2 (sem previsão)
        for (var i = 5; i <= 6; i++)
          CarteiraItem(
            nota: NotaSAP(id: 'n$i', nota: '100$i', statusSistema: 'MSPR'),
            previsao: CarteiraPrevisao.semPrevisao,
            grupoId: 'g2',
            grupoNome: grupoSemPrev.nome,
            estimativaHoras: 5.0,
            situacaoPrazo: SituacaoPrazoCarteira.sit5SemPrazoConhecido,
          ),

        // 1 nota avulsa com previsão individual
        CarteiraItem(
          nota: NotaSAP(id: 'n7', nota: '1007', statusSistema: 'MSPN'),
          previsao: const CarteiraPrevisao(
            mes: 11,
            ano: 2027,
            origem: OrigemPrevisao.individual,
          ),
          grupoId: null,
          grupoNome: null,
          estimativaHoras: 8.0,
          situacaoPrazo: SituacaoPrazoCarteira.sit1Compativel,
        ),

        // 3 notas avulsas sem previsão
        for (var i = 8; i <= 10; i++)
          CarteiraItem(
            nota: NotaSAP(id: 'n$i', nota: '100$i', statusSistema: 'MSPN'),
            previsao: CarteiraPrevisao.semPrevisao,
            grupoId: null,
            grupoNome: null,
            estimativaHoras: null, // Sem análise técnica
            situacaoPrazo: SituacaoPrazoCarteira.sit5SemPrazoConhecido,
          ),
      ];

      final kpis = CarteiraIndicadores.calcular(
        itens: itens,
        gruposAtivos: [grupoComPrev, grupoSemPrev],
      );

      // Verificações
      expect(kpis.totalNotasPendentes, 10);
      expect(kpis.totalNotasAgrupadas, 6); // 4 em g1 + 2 em g2
      expect(kpis.totalNotasAvulsas, 4); // n7 + n8 + n9 + n10

      // Previsibilidade: 4 (do grupo g1) + 1 (avulsa com previsão n7) = 5
      expect(kpis.totalComPrevisao, 5);
      expect(kpis.totalSemPrevisao, 5); // 2 do g2 + 3 avulsas = 5
      expect(kpis.taxaCoberturaPrevisibilidade, 50.0); // (5 / 10) * 100

      // Horas estimadas: 4*10 + 2*5 + 1*8 = 58h
      expect(kpis.totalHorasEstimadas, 58.0);
      // Horas sem previsão: 2*5 = 10h (as notas 8, 9, 10 não têm estimativa)
      expect(kpis.totalHorasSemPrevisao, 10.0);
      expect(kpis.totalNotasComEstimativa, 7); // 7 de 10 possuem análise de horas
      expect(kpis.taxaCoberturaEstimativa, 70.0);

      // Grupos
      expect(kpis.totalGruposAtivos, 2);
      expect(kpis.totalGruposComPrevisao, 1);
      expect(kpis.totalGruposSemPrevisao, 1);
    });

    test('Tarefas CANC não contam como programadas, enquanto PROG e ANDA contam', () {
      final taskCancelada = BacklogTaskInfo(id: 't1', status: 'CANC');
      final taskProgramada = BacklogTaskInfo(id: 't2', status: 'PROG');
      final taskAndamento = BacklogTaskInfo(id: 't3', status: 'ANDA');

      final item1 = CarteiraItem(
        nota: NotaSAP(id: 'n1', nota: '1001', statusSistema: 'MSPN'),
        previsao: CarteiraPrevisao.semPrevisao,
        tasks: [taskCancelada],
        situacaoPrazo: SituacaoPrazoCarteira.sit5SemPrazoConhecido,
      );

      final item2 = CarteiraItem(
        nota: NotaSAP(id: 'n2', nota: '1002', statusSistema: 'MSPR'),
        previsao: CarteiraPrevisao.semPrevisao,
        tasks: [taskProgramada],
        situacaoPrazo: SituacaoPrazoCarteira.sit5SemPrazoConhecido,
      );

      final item3 = CarteiraItem(
        nota: NotaSAP(id: 'n3', nota: '1003', statusSistema: 'MSPR'),
        previsao: CarteiraPrevisao.semPrevisao,
        tasks: [taskCancelada, taskAndamento], // Tem 1 CANC e 1 ANDA
        situacaoPrazo: SituacaoPrazoCarteira.sit5SemPrazoConhecido,
      );

      expect(item1.isProgramada, isFalse);
      expect(item2.isProgramada, isTrue);
      expect(item3.isProgramada, isTrue);

      final kpis = CarteiraIndicadores.calcular(
        itens: [item1, item2, item3],
        gruposAtivos: [],
      );

      expect(kpis.totalNotasPendentes, 3);
      expect(kpis.totalProgramadas, 2); // Apenas item2 e item3
      expect(kpis.taxaProgramacao, closeTo(66.66, 0.01));
    });
  });
}
