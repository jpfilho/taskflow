import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/models/backlog_macro_models.dart';
import 'package:task2026/models/carteira_manutencao_models.dart';
import 'package:task2026/models/nota_sap.dart';
import 'package:task2026/models/nota_sap_grupo.dart';

void main() {
  group('Carteira de Manutenção — Testes de Integração e Regras de Negócio', () {
    final dataHoje = DateTime(2027, 4, 15);

    test('1. Deduplicação Estrita: Notas não são duplicadas nem na contagem nem nos agrupamentos', () {
      final n1 = NotaSAP(id: 'nota-1', nota: '1001', statusSistema: 'MSPN');
      final n2 = NotaSAP(id: 'nota-2', nota: '1002', statusSistema: 'MSPR');

      final task1 = BacklogTaskInfo(id: 't1', status: 'PROG', dataInicio: DateTime(2027, 5, 1));
      final task2 = BacklogTaskInfo(id: 't2', status: 'ANDA', dataInicio: DateTime(2027, 5, 2));

      // Nota 1 tem 2 tarefas operacionais válidas
      final item1 = CarteiraItem(
        nota: n1,
        previsao: const CarteiraPrevisao(mes: 5, ano: 2027, origem: OrigemPrevisao.grupo, origemId: 'g1'),
        grupoId: 'g1',
        grupoNome: 'Grupo 1',
        tasks: [task1, task2],
        situacaoPrazo: SituacaoPrazoCarteira.sit1Compativel,
      );

      final item2 = CarteiraItem(
        nota: n2,
        previsao: CarteiraPrevisao.semPrevisao,
        grupoId: null,
        grupoNome: null,
        tasks: const [],
        situacaoPrazo: SituacaoPrazoCarteira.sit5SemPrazoConhecido,
      );

      final ind = CarteiraIndicadores.calcular(
        itens: [item1, item2],
        gruposAtivos: [
          const NotaSapGrupo(id: 'g1', nome: 'Grupo 1', mesProgramacaoPrevisto: 5, anoProgramacaoPrevisto: 2027),
        ],
        dataReferencia: dataHoje,
      );

      expect(ind.totalNotasPendentes, 2);
      expect(ind.totalNotasAgrupadas, 1);
      expect(ind.totalNotasAvulsas, 1);
      expect(ind.totalProgramadas, 1); // Nota 1 tem 2 tarefas, mas conta como 1 nota programada!
    });

    test('2. Unificação de Status: Notas MSEN, CONC, ENCE e CANC são ignoradas na carteira pendente', () {
      final itens = [
        CarteiraItem(
          nota: NotaSAP(id: 'n1', nota: '1001', statusSistema: 'MSPN'), // Aberta
          previsao: CarteiraPrevisao.semPrevisao,
          situacaoPrazo: SituacaoPrazoCarteira.sit5SemPrazoConhecido,
        ),
        CarteiraItem(
          nota: NotaSAP(id: 'n2', nota: '1002', statusSistema: 'MSEN'), // Concluída
          previsao: CarteiraPrevisao.semPrevisao,
          situacaoPrazo: SituacaoPrazoCarteira.sit5SemPrazoConhecido,
        ),
        CarteiraItem(
          nota: NotaSAP(id: 'n3', nota: '1003', statusSistema: 'MSPR CONC'), // Concluída
          previsao: CarteiraPrevisao.semPrevisao,
          situacaoPrazo: SituacaoPrazoCarteira.sit5SemPrazoConhecido,
        ),
        CarteiraItem(
          nota: NotaSAP(id: 'n4', nota: '1004', statusSistema: 'CANC'), // Cancelada
          previsao: CarteiraPrevisao.semPrevisao,
          situacaoPrazo: SituacaoPrazoCarteira.sit5SemPrazoConhecido,
        ),
      ];

      final ind = CarteiraIndicadores.calcular(
        itens: itens,
        gruposAtivos: const [],
        dataReferencia: dataHoje,
      );

      // Apenas a nota 1 é pendente! As outras 3 são concluídas/canceladas
      expect(ind.totalNotasPendentes, 1);
    });

    test('3. Precedência e Cálculo de Cobertura de Previsibilidade', () {
      // 10 notas:
      // - 6 notas com previsão válida (60% de cobertura)
      // - 4 notas sem previsão
      final itens = <CarteiraItem>[
        for (var i = 1; i <= 6; i++)
          CarteiraItem(
            nota: NotaSAP(id: 'n$i', nota: '100$i', statusSistema: 'MSPN'),
            previsao: CarteiraPrevisao(
              mes: 7,
              ano: 2027,
              origem: i <= 4 ? OrigemPrevisao.grupo : OrigemPrevisao.individual,
            ),
            situacaoPrazo: SituacaoPrazoCarteira.sit1Compativel,
          ),
        for (var i = 7; i <= 10; i++)
          CarteiraItem(
            nota: NotaSAP(id: 'n$i', nota: '100$i', statusSistema: 'MSPN'),
            previsao: CarteiraPrevisao.semPrevisao,
            situacaoPrazo: SituacaoPrazoCarteira.sit5SemPrazoConhecido,
          ),
      ];

      final ind = CarteiraIndicadores.calcular(
        itens: itens,
        gruposAtivos: const [],
        dataReferencia: dataHoje,
      );

      expect(ind.totalNotasPendentes, 10);
      expect(ind.totalComPrevisao, 6);
      expect(ind.totalSemPrevisao, 4);
      expect(ind.taxaCoberturaPrevisibilidade, 60.0);
    });

    test('4. Confrontação Previsão vs. Prazo nas 7 Situações', () {
      // Cenário com uma nota em cada situação
      final itens = [
        // SIT-1: Prev = 06/2027, Venc = 15/08/2027 (Compatível)
        CarteiraItem(
          nota: NotaSAP(
            id: 'n1',
            nota: '1001',
            statusSistema: 'MSPN',
            dataVencimento: DateTime(2027, 8, 15),
            diasRestantes: 122,
          ),
          previsao: const CarteiraPrevisao(mes: 6, ano: 2027, origem: OrigemPrevisao.grupo),
          situacaoPrazo: SituacaoPrazoCarteira.classificar(
            dataVencimento: DateTime(2027, 8, 15),
            diasRestantes: 122,
            mesPrevisto: 6,
            anoPrevisto: 2027,
            isProgramada: false,
            dataReferencia: dataHoje,
          ),
        ),

        // SIT-2: Prev = 06/2027, Venc = 10/06/2027 (Risco Temporal)
        CarteiraItem(
          nota: NotaSAP(
            id: 'n2',
            nota: '1002',
            statusSistema: 'MSPN',
            dataVencimento: DateTime(2027, 6, 10),
            diasRestantes: 56,
          ),
          previsao: const CarteiraPrevisao(mes: 6, ano: 2027, origem: OrigemPrevisao.grupo),
          situacaoPrazo: SituacaoPrazoCarteira.classificar(
            dataVencimento: DateTime(2027, 6, 10),
            diasRestantes: 56,
            mesPrevisto: 6,
            anoPrevisto: 2027,
            isProgramada: false,
            dataReferencia: dataHoje,
          ),
        ),

        // SIT-3: Prev = 09/2027, Venc = 20/06/2027 (Violação Prevista)
        CarteiraItem(
          nota: NotaSAP(
            id: 'n3',
            nota: '1003',
            statusSistema: 'MSPN',
            dataVencimento: DateTime(2027, 6, 20),
            diasRestantes: 66,
          ),
          previsao: const CarteiraPrevisao(mes: 9, ano: 2027, origem: OrigemPrevisao.grupo),
          situacaoPrazo: SituacaoPrazoCarteira.classificar(
            dataVencimento: DateTime(2027, 6, 20),
            diasRestantes: 66,
            mesPrevisto: 9,
            anoPrevisto: 2027,
            isProgramada: false,
            dataReferencia: dataHoje,
          ),
        ),

        // SIT-4: Vencida (Venc = 01/04/2027, hoje = 15/04/2027)
        CarteiraItem(
          nota: NotaSAP(
            id: 'n4',
            nota: '1004',
            statusSistema: 'MSPN',
            dataVencimento: DateTime(2027, 4, 1),
            diasRestantes: -14,
          ),
          previsao: const CarteiraPrevisao(mes: 5, ano: 2027, origem: OrigemPrevisao.grupo),
          situacaoPrazo: SituacaoPrazoCarteira.classificar(
            dataVencimento: DateTime(2027, 4, 1),
            diasRestantes: -14,
            mesPrevisto: 5,
            anoPrevisto: 2027,
            isProgramada: false,
            dataReferencia: dataHoje,
          ),
        ),

        // SIT-5: Sem Prazo Conhecido
        CarteiraItem(
          nota: NotaSAP(id: 'n5', nota: '1005', statusSistema: 'MSPN'),
          previsao: const CarteiraPrevisao(mes: 7, ano: 2027, origem: OrigemPrevisao.grupo),
          situacaoPrazo: SituacaoPrazoCarteira.classificar(
            dataVencimento: null,
            diasRestantes: null,
            mesPrevisto: 7,
            anoPrevisto: 2027,
            isProgramada: false,
            dataReferencia: dataHoje,
          ),
        ),

        // SIT-6: Previsão Ultrapassada (Prev = 02/2027 < hoje 04/2027 e não programada)
        CarteiraItem(
          nota: NotaSAP(
            id: 'n6',
            nota: '1006',
            statusSistema: 'MSPN',
            dataVencimento: DateTime(2027, 10, 1),
            diasRestantes: 169,
          ),
          previsao: const CarteiraPrevisao(mes: 2, ano: 2027, origem: OrigemPrevisao.grupo),
          situacaoPrazo: SituacaoPrazoCarteira.classificar(
            dataVencimento: DateTime(2027, 10, 1),
            diasRestantes: 169,
            mesPrevisto: 2,
            anoPrevisto: 2027,
            isProgramada: false,
            dataReferencia: dataHoje,
          ),
        ),

        // SIT-7: Sem Previsão e Prazo Próximo (Venc = 20/05/2027, diasRestantes = 35 <= 60)
        CarteiraItem(
          nota: NotaSAP(
            id: 'n7',
            nota: '1007',
            statusSistema: 'MSPN',
            dataVencimento: DateTime(2027, 5, 20),
            diasRestantes: 35,
          ),
          previsao: CarteiraPrevisao.semPrevisao,
          situacaoPrazo: SituacaoPrazoCarteira.classificar(
            dataVencimento: DateTime(2027, 5, 20),
            diasRestantes: 35,
            mesPrevisto: null,
            anoPrevisto: null,
            isProgramada: false,
            dataReferencia: dataHoje,
          ),
        ),
      ];

      final ind = CarteiraIndicadores.calcular(
        itens: itens,
        gruposAtivos: const [],
        dataReferencia: dataHoje,
      );

      expect(ind.totalNotasPendentes, 7);
      expect(ind.totalCompativel, 1); // SIT-1
      expect(ind.totalRiscoTemporal, 1); // SIT-2
      expect(ind.totalViolacaoPrevista, 1); // SIT-3
      expect(ind.totalVencidas, 1); // SIT-4
      expect(ind.totalSemPrazoConhecido, 1); // SIT-5
      expect(ind.totalPrevisaoUltrapassada, 1); // SIT-6
      expect(ind.totalSemPrevisaoPrazoProximo, 1); // SIT-7
    });
  });
}
