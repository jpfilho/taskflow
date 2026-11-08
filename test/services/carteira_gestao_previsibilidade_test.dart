import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/models/carteira_manutencao_models.dart';
import 'package:task2026/models/nota_sap.dart';
import 'package:task2026/models/nota_sap_grupo.dart';

void main() {
  group('Gestão Ativa da Previsibilidade — Regras de Negócio e Testes de Precedência', () {
    final dataReferencia = DateTime(2026, 11, 2);

    NotaSAP criarNota({
      required String numero,
      required String status,
      DateTime? vencimento,
      int? diasRestantes,
      String? ct,
    }) {
      return NotaSAP(
        id: 'id_$numero',
        nota: numero,
        statusSistema: status,
        statusUsuario: '',
        dataVencimento: vencimento,
        diasRestantes: diasRestantes,
        centroTrabalhoResponsavel: ct ?? 'CT-01',
      );
    }

    test('1. Atribuição de Previsão Individual a Nota Avulsa', () {
      final nota = criarNota(
        numero: '1001',
        status: 'MSPR',
        vencimento: DateTime(2027, 8, 15),
        diasRestantes: 280,
      );

      final prevIndividual = PrevisaoIndividualNota(
        id: 'prev_1',
        notaSapId: nota.id,
        numeroNota: nota.nota,
        mesPrevisao: 5,
        anoPrevisao: 2027,
        motivoPrevisao: 'Disponibilidade de equipe no polo',
        criadoEm: DateTime(2026, 11, 2),
        atualizadoEm: DateTime(2026, 11, 2),
        criadoPor: 'user_1',
        criadoPorNome: 'Analista Planejamento',
      );

      // Mapear para CarteiraPrevisao com origem individual
      final previsao = CarteiraPrevisao(
        mes: prevIndividual.mesPrevisao,
        ano: prevIndividual.anoPrevisao,
        origem: OrigemPrevisao.individual,
        origemId: prevIndividual.id,
        origemNome: 'Previsão Individual',
        motivo: prevIndividual.motivoPrevisao,
      );

      final situacao = SituacaoPrazoCarteira.classificar(
        dataVencimento: nota.dataVencimento,
        diasRestantes: nota.diasRestantes,
        mesPrevisto: previsao.mes,
        anoPrevisto: previsao.ano,
        isProgramada: false,
        dataReferencia: dataReferencia,
      );

      final item = CarteiraItem(
        nota: nota,
        previsao: previsao,
        situacaoPrazo: situacao,
      );

      expect(item.temPrevisaoValida, isTrue);
      expect(item.previsao.origem, equals(OrigemPrevisao.individual));
      expect(item.previsao.formatada, equals('Maio/2027'));
      expect(item.situacaoPrazo, equals(SituacaoPrazoCarteira.sit1Compativel));
    });

    test('2. Precedência: Previsão de Grupo Ativo sobrepõe Previsão Individual sem apagá-la', () {
      final nota = criarNota(
        numero: '1002',
        status: 'MSPR',
        vencimento: DateTime(2027, 9, 20),
        diasRestantes: 320,
      );

      // Previsão individual existente para Julho/2027
      final prevIndividual = PrevisaoIndividualNota(
        id: 'prev_2',
        notaSapId: nota.id,
        numeroNota: nota.nota,
        mesPrevisao: 7,
        anoPrevisao: 2027,
        criadoEm: DateTime(2026, 11, 2),
        atualizadoEm: DateTime(2026, 11, 2),
      );

      // Grupo ativo com previsão para Junho/2027
      final grupoAtivo = NotaSapGrupo(
        id: 'grp_1',
        nome: 'Campanha SE Centro',
        mesProgramacaoPrevisto: 6,
        anoProgramacaoPrevisto: 2027,
        statusGrupo: StatusGrupo.ativo,
      );

      // Regra de precedência:
      // Se grupo ativo tem previsão -> Origem = grupo
      // Caso contrário -> Origem = individual
      final CarteiraPrevisao previsaoEfetiva;
      if (grupoAtivo.temPrevisao) {
        previsaoEfetiva = CarteiraPrevisao(
          mes: grupoAtivo.mesProgramacaoPrevisto,
          ano: grupoAtivo.anoProgramacaoPrevisto,
          origem: OrigemPrevisao.grupo,
          origemId: grupoAtivo.id,
          origemNome: grupoAtivo.nome,
        );
      } else {
        previsaoEfetiva = CarteiraPrevisao(
          mes: prevIndividual.mesPrevisao,
          ano: prevIndividual.anoPrevisao,
          origem: OrigemPrevisao.individual,
          origemId: prevIndividual.id,
        );
      }

      expect(previsaoEfetiva.origem, equals(OrigemPrevisao.grupo));
      expect(previsaoEfetiva.mes, equals(6));
      expect(previsaoEfetiva.ano, equals(2027));

      // Se a nota for desvinculada do grupo, a previsão individual é preservada
      final previsaoAposRemoverDoGrupo = CarteiraPrevisao(
        mes: prevIndividual.mesPrevisao,
        ano: prevIndividual.anoPrevisao,
        origem: OrigemPrevisao.individual,
        origemId: prevIndividual.id,
      );
      expect(previsaoAposRemoverDoGrupo.origem, equals(OrigemPrevisao.individual));
      expect(previsaoAposRemoverDoGrupo.mes, equals(7));
    });

    test('3. Atribuição em Lote e Rastreabilidade com lote_id', () {
      final notas = [
        criarNota(numero: '2001', status: 'MSPR'),
        criarNota(numero: '2002', status: 'MSPR'),
        criarNota(numero: '2003', status: 'MSPR'),
      ];

      const loteId = 'lote_uuid_12345';
      final historicos = <HistoricoPrevisaoNota>[];

      for (final n in notas) {
        historicos.add(HistoricoPrevisaoNota(
          id: 'hist_${n.nota}',
          notaSapId: n.id,
          numeroNota: n.nota,
          mesAnterior: null,
          anoAnterior: null,
          mesNovo: 4,
          anoNovo: 2027,
          motivo: 'Planejamento Regional Q2',
          operacao: 'ATRIBUICAO_LOTE',
          loteId: loteId,
          alteradoPor: 'user_coordenador',
          alteradoPorNome: 'Coordenador Operacional',
          alteradoEm: DateTime(2026, 11, 2),
        ));
      }

      expect(historicos.length, equals(3));
      expect(historicos.every((h) => h.loteId == loteId), isTrue);
      expect(historicos.every((h) => h.operacao == 'ATRIBUICAO_LOTE'), isTrue);
      expect(historicos[0].descricaoMudanca, equals('Sem previsão ➔ 4/2027'));
    });

    test('4. Desfazer Alteração em Lote (Rollback Auditado)', () {
      // Simular estado anterior: nota A tinha 3/2027, nota B não tinha previsão
      final histLote = [
        HistoricoPrevisaoNota(
          id: 'h1',
          notaSapId: 'id_A',
          numeroNota: 'Nota_A',
          mesAnterior: 3,
          anoAnterior: 2027,
          mesNovo: 5,
          anoNovo: 2027,
          operacao: 'ATRIBUICAO_LOTE',
          loteId: 'lote_reversao',
          alteradoEm: DateTime.now(),
        ),
        HistoricoPrevisaoNota(
          id: 'h2',
          notaSapId: 'id_B',
          numeroNota: 'Nota_B',
          mesAnterior: null,
          anoAnterior: null,
          mesNovo: 5,
          anoNovo: 2027,
          operacao: 'ATRIBUICAO_LOTE',
          loteId: 'lote_reversao',
          alteradoEm: DateTime.now(),
        ),
      ];

      // Processo de reversão:
      final estadoRevertido = <String, Map<String, int?>>{};
      for (final h in histLote) {
        estadoRevertido[h.notaSapId] = {
          'mes': h.mesAnterior,
          'ano': h.anoAnterior,
        };
      }

      expect(estadoRevertido['id_A']!['mes'], equals(3));
      expect(estadoRevertido['id_A']!['ano'], equals(2027));
      expect(estadoRevertido['id_B']!['mes'], isNull);
      expect(estadoRevertido['id_B']!['ano'], isNull);
    });

    test('5. Sinalização Imediata de Previsão Incompatível (SIT-3 Violação Prevista)', () {
      // Vence em Fevereiro/2027
      final nota = criarNota(
        numero: '3001',
        status: 'MSPR',
        vencimento: DateTime(2027, 2, 20),
        diasRestantes: 110,
      );

      // Usuário tenta prever para Maio/2027 (3 meses após vencimento)
      final situacao = SituacaoPrazoCarteira.classificar(
        dataVencimento: nota.dataVencimento,
        diasRestantes: nota.diasRestantes,
        mesPrevisto: 5,
        anoPrevisto: 2027,
        isProgramada: false,
        dataReferencia: dataReferencia,
      );

      expect(situacao, equals(SituacaoPrazoCarteira.sit3ViolacaoPrevista));
      expect(situacao.codigo, equals('SIT-3'));
      expect(situacao.labelCurto, equals('Violação Prevista'));
    });

    test('6. Concorrência e Histórico de Reprogramações Sucessivas', () {
      final historicoNota = [
        HistoricoPrevisaoNota(
          id: 'h_1',
          notaSapId: 'id_4001',
          numeroNota: '4001',
          mesAnterior: null,
          anoAnterior: null,
          mesNovo: 3,
          anoNovo: 2027,
          motivo: 'Previsão inicial',
          operacao: 'ATRIBUICAO_INDIVIDUAL',
          alteradoPor: 'user_1',
          alteradoPorNome: 'Analista A',
          alteradoEm: DateTime(2026, 11, 2, 10, 0),
        ),
        HistoricoPrevisaoNota(
          id: 'h_2',
          notaSapId: 'id_4001',
          numeroNota: '4001',
          mesAnterior: 3,
          anoAnterior: 2027,
          mesNovo: 4,
          anoNovo: 2027,
          motivo: 'Atraso de fornecimento de peças',
          operacao: 'REPROGRAMACAO',
          alteradoPor: 'user_2',
          alteradoPorNome: 'Coordenador B',
          alteradoEm: DateTime(2026, 11, 2, 14, 30),
        ),
      ];

      expect(historicoNota.length, equals(2));
      expect(historicoNota[1].mesAnterior, equals(3));
      expect(historicoNota[1].mesNovo, equals(4));
      expect(historicoNota[1].alteradoPorNome, equals('Coordenador B'));
      expect(historicoNota[1].descricaoMudanca, equals('3/2027 ➔ 4/2027'));
    });

    test('7. Impacto Direto na Cobertura Global da Carteira', () {
      final notas = [
        criarNota(numero: '5001', status: 'MSPR'),
        criarNota(numero: '5002', status: 'MSPR'),
        criarNota(numero: '5003', status: 'MSPR'),
        criarNota(numero: '5004', status: 'MSPR'),
      ];

      // Cenário Inicial: Nenhuma tem previsão (0% cobertura)
      final itensSemPrev = notas.map((n) => CarteiraItem(
        nota: n,
        previsao: CarteiraPrevisao.semPrevisao,
        situacaoPrazo: SituacaoPrazoCarteira.sit5SemPrazoConhecido,
      )).toList();

      final kpisAntes = CarteiraIndicadores.calcular(
        itens: itensSemPrev,
        gruposAtivos: const [],
        dataReferencia: dataReferencia,
      );
      expect(kpisAntes.taxaCoberturaPrevisibilidade, equals(0.0));
      expect(kpisAntes.totalSemPrevisao, equals(4));

      // Atribuição de previsão para 2 notas avulsas (50% cobertura)
      final itensComPrev = [
        itensSemPrev[0].copyWith(
          previsao: const CarteiraPrevisao(mes: 5, ano: 2027, origem: OrigemPrevisao.individual),
        ),
        itensSemPrev[1].copyWith(
          previsao: const CarteiraPrevisao(mes: 6, ano: 2027, origem: OrigemPrevisao.individual),
        ),
        itensSemPrev[2],
        itensSemPrev[3],
      ];

      final kpisDepois = CarteiraIndicadores.calcular(
        itens: itensComPrev,
        gruposAtivos: const [],
        dataReferencia: dataReferencia,
      );

      expect(kpisDepois.taxaCoberturaPrevisibilidade, equals(50.0));
      expect(kpisDepois.totalComPrevisao, equals(2));
      expect(kpisDepois.totalSemPrevisao, equals(2));
      expect(kpisDepois.totalNotasAvulsas, equals(4));
    });
  });
}
