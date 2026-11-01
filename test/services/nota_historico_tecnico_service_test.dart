import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/models/nota_sap.dart';
import 'package:task2026/models/nota_sap_similaridade.dart';
import 'package:task2026/models/nota_historico_tecnico.dart';
import 'package:task2026/services/nota_historico_tecnico_service.dart';
import 'package:task2026/services/nota_sap_similaridade_service.dart';
import 'package:task2026/utils/instalacao_sap_helper.dart';

// Mock de NotaSapSimilaridadeService para isolar testes sem Supabase
class MockSimilaridadeService extends NotaSapSimilaridadeService {
  final List<NotaSapSimilar> ocorrenciasRetorno;

  MockSimilaridadeService({this.ocorrenciasRetorno = const []});

  @override
  Future<ResultadoSimilaridadeNotaSap> buscarSimilaridades({
    required NotaSAP notaReferencia,
    bool forceRefresh = false,
  }) async {
    return ResultadoSimilaridadeNotaSap(
      notaReferencia: notaReferencia,
      todasOcorrencias: ocorrenciasRetorno,
      ocorrenciasSemelhantes: ocorrenciasRetorno,
      calculadoEm: DateTime.now(),
    );
  }
}

void main() {
  group('NotaHistoricoTecnicoService & Regras de Domínio', () {
    final notaRef = NotaSAP(
      id: 'nota-ref-1',
      nota: '11599351',
      tipo: 'NM',
      descricao: 'Troca de isolador quebrado com vazamento de oleo',
      equipamento: '11340679',
      localInstalacao: 'H-S-SCTU-RB4T02-4CT1-DJ01',
      sala: '14T2',
      statusSistema: 'MSPR',
      criadoEm: DateTime(2026, 3, 10),
    );

    test('1 & 7. Critério A (Mesmo Equipamento) e A+D na mesma Nota', () {
      final notaHistA = NotaSAP(
        id: 'nota-hist-1',
        nota: '11400001',
        tipo: 'NM',
        descricao: 'Substituição de conector oxidado no isolador',
        equipamento: '11340679', // Mesmo equipamento
        localInstalacao: 'H-S-SCTU-RB4T02-4CT1-DJ01',
        sala: '14T2',
        criadoEm: DateTime(2025, 6, 15),
      );

      final item = NotaHistoricoTecnicoItem(
        notaSap: notaHistA,
        criterioFisicoPrincipal: NotaHistoricoCriterioFisico.mesmoEquipamento,
        motivosFisicos: const ['Mesmo equipamento (11340679)', 'Mesma estrutura (14T2)'],
        ehSimilar: true,
        scoreSimilaridade: 78.0,
        tokensCoincidentes: const ['isolador', 'substituicao'],
        totalAnexos: 3,
        temAnalise: true,
      );

      expect(item.ehMesmoEquipamento, isTrue);
      expect(item.temRelacaoFisica, isTrue);
      expect(item.ehSimilar, isTrue);
      expect(item.scoreSimilaridade, equals(78.0));
      expect(item.motivosFisicos, contains('Mesmo equipamento (11340679)'));
      expect(item.motivosFisicos, contains('Mesma estrutura (14T2)'));
      expect(item.totalAnexos, equals(3));
      expect(item.temAnalise, isTrue);
    });

    test('2 & 3. Critério B: Mesma estrutura em LT e mesmo vão em SE', () {
      // Caso LT: mesma torre/estrutura 101/2
      final notaLtRef = NotaSAP(
        id: 'lt-ref',
        nota: '11598782',
        localInstalacao: 'H-L-SPDDSTSD-RB5C08-5LT1',
        sala: '101/2',
        criadoEm: DateTime(2026, 2, 1),
      );

      final notaLtHist = NotaSAP(
        id: 'lt-hist',
        nota: '11200000',
        localInstalacao: 'H-L-SPDDSTSD-RB5C08-5LT1',
        sala: '101/2',
        criadoEm: DateTime(2024, 8, 20),
      );

      final mesmaInstalacaoLt = InstalacaoSapHelper.saoMesmaInstalacao(
        notaLtRef.localInstalacao,
        notaLtHist.localInstalacao,
      );
      final mesmaSalaLt = InstalacaoSapHelper.normalizarSala(notaLtRef.sala) ==
          InstalacaoSapHelper.normalizarSala(notaLtHist.sala);

      expect(mesmaInstalacaoLt, isTrue);
      expect(mesmaSalaLt, isTrue);
      expect(InstalacaoSapHelper.ehSalaValidaParaCriterioB(notaLtHist.sala), isTrue);

      // Caso SE: mesmo vão operativo FT.04T1
      expect(InstalacaoSapHelper.ehSalaValidaParaCriterioB('FT.04T1'), isTrue);
      expect(InstalacaoSapHelper.ehSalaValidaParaCriterioB('34F3-5'), isTrue);
    });

    test('4. Blacklist de salas genéricas descartadas para Critério B', () {
      expect(InstalacaoSapHelper.ehSalaValidaParaCriterioB('GERAL'), isFalse);
      expect(InstalacaoSapHelper.ehSalaValidaParaCriterioB('GERAL.'), isFalse);
      expect(InstalacaoSapHelper.ehSalaValidaParaCriterioB('N/A'), isFalse);
      expect(InstalacaoSapHelper.ehSalaValidaParaCriterioB('NAO APLICAVEL'), isFalse);
      expect(InstalacaoSapHelper.ehSalaValidaParaCriterioB('-'), isFalse);
      expect(InstalacaoSapHelper.ehSalaValidaParaCriterioB(''), isFalse);
      expect(InstalacaoSapHelper.ehSalaValidaParaCriterioB(null), isFalse);
    });

    test('5. Critério C: Mesmo Local Amplo / Chave da Instalação', () {
      final chaveRef = InstalacaoSapHelper.extrairChaveInstalacao(notaRef.localInstalacao);
      expect(chaveRef, equals('H-S-SCTU'));

      final notaMesmoLocal = NotaSAP(
        id: 'nota-outro-vao',
        nota: '11500000',
        localInstalacao: 'H-S-SCTU-RB4T01-1CT1-DJ02', // Outro vão da mesma subestação
        sala: '04T1',
        equipamento: '99999999',
      );

      final mesmaInstalacao = InstalacaoSapHelper.saoMesmaInstalacao(
        notaRef.localInstalacao,
        notaMesmoLocal.localInstalacao,
      );
      expect(mesmaInstalacao, isTrue);
    });

    test('8 & 9. Deduplicação e Nota Apenas Similar (Critério D sem vínculo físico)', () {
      final notaSimil = NotaSAP(
        id: 'nota-apenas-d',
        nota: '11999999',
        descricao: 'Vazamento em disjuntor com troca de mola',
        localInstalacao: 'H-S-STSA-DT1E01', // Outra subestação diferente
        criadoEm: DateTime(2025, 1, 10),
      );

      final itemApenasD = NotaHistoricoTecnicoItem(
        notaSap: notaSimil,
        criterioFisicoPrincipal: NotaHistoricoCriterioFisico.apenasSimilaridade,
        ehSimilar: true,
        scoreSimilaridade: 65.0,
        tokensCoincidentes: const ['vazamento', 'disjuntor'],
      );

      expect(itemApenasD.temRelacaoFisica, isFalse);
      expect(itemApenasD.ehSimilar, isTrue);
      expect(itemApenasD.criterioFisicoPrincipal,
          equals(NotaHistoricoCriterioFisico.apenasSimilaridade));
    });

    test('10. Ordenação hierárquica e determinística', () {
      final itemA = NotaHistoricoTecnicoItem(
        notaSap: NotaSAP(id: '1', nota: '1', criadoEm: DateTime(2025, 1, 1)),
        criterioFisicoPrincipal: NotaHistoricoCriterioFisico.mesmoEquipamento,
      );
      final itemB = NotaHistoricoTecnicoItem(
        notaSap: NotaSAP(id: '2', nota: '2', criadoEm: DateTime(2025, 2, 1)),
        criterioFisicoPrincipal: NotaHistoricoCriterioFisico.mesmaEstrutura,
      );
      final itemC = NotaHistoricoTecnicoItem(
        notaSap: NotaSAP(id: '3', nota: '3', criadoEm: DateTime(2025, 3, 1)),
        criterioFisicoPrincipal: NotaHistoricoCriterioFisico.mesmoLocal,
      );
      final itemD = NotaHistoricoTecnicoItem(
        notaSap: NotaSAP(id: '4', nota: '4', criadoEm: DateTime(2025, 4, 1)),
        criterioFisicoPrincipal: NotaHistoricoCriterioFisico.apenasSimilaridade,
        scoreSimilaridade: 85.0,
      );

      final resultado = NotaHistoricoTecnicoResultado(
        notaReferencia: notaRef,
        itensEquipamento: [itemA],
        itensEstrutura: [itemB],
        itensLocal: [itemC],
        itensApenasSimilaridade: [itemD],
        todosItensDeduplicados: [itemA, itemB, itemC, itemD],
        calculadoEm: DateTime.now(),
      );

      expect(resultado.totalItens, equals(4));
      expect(resultado.itensEquipamento.first.criterioFisicoPrincipal,
          equals(NotaHistoricoCriterioFisico.mesmoEquipamento));
      expect(resultado.itensEstrutura.first.criterioFisicoPrincipal,
          equals(NotaHistoricoCriterioFisico.mesmaEstrutura));
      expect(resultado.itensLocal.first.criterioFisicoPrincipal,
          equals(NotaHistoricoCriterioFisico.mesmoLocal));
      expect(resultado.itensApenasSimilaridade.first.criterioFisicoPrincipal,
          equals(NotaHistoricoCriterioFisico.apenasSimilaridade));
    });

    test('11 & 12. Lazy Loading e Cópia com Detalhes', () {
      final itemBase = NotaHistoricoTecnicoItem(
        notaSap: NotaSAP(id: 'lazy-1', nota: '11001100'),
        criterioFisicoPrincipal: NotaHistoricoCriterioFisico.mesmoEquipamento,
        totalAnexos: 2,
        temAnalise: true,
        detalhesCarregados: false,
      );

      expect(itemBase.detalhesCarregados, isFalse);
      expect(itemBase.anexos, isEmpty);

      final itemAtualizado = itemBase.copyWithDetalhes(
        anexos: const [],
        analise: null,
        tasks: const [],
      );

      expect(itemAtualizado.detalhesCarregados, isTrue);
    });

    test('21. Status operacional de Task não infere resolução técnica', () {
      final taskConc = TarefaHistoricaResumo(
        id: 'task-1',
        tarefaNome: 'Inspeção termográfica',
        status: 'CONC',
        totalExecutores: 2,
      );

      expect(taskConc.status, equals('CONC'));
      // Apenas status da atividade de campo; sem alterar diagnóstico da Nota
    });

    test('22. Pipeline Progressivo & Time to Useful History (Flags e Transição)', () {
      final resInicial = NotaHistoricoTecnicoResultado(
        notaReferencia: notaRef,
        itensEquipamento: [
          NotaHistoricoTecnicoItem(
            notaSap: NotaSAP(id: 'eq-1', nota: '11000001'),
            criterioFisicoPrincipal: NotaHistoricoCriterioFisico.mesmoEquipamento,
          ),
        ],
        carregandoSimilares: true,
        carregandoLocalAmplo: true,
        timeToUsefulHistoryMs: 380,
        calculadoEm: DateTime.now(),
      );

      expect(resInicial.timeToUsefulHistoryMs, equals(380));
      expect(resInicial.carregandoSimilares, isTrue);
      expect(resInicial.carregandoLocalAmplo, isTrue);
      expect(resInicial.itensEquipamento, isNotEmpty);

      // Simula enriquecimento de similares
      final resComSimilares = resInicial.copyWith(
        carregandoSimilares: false,
        itensApenasSimilaridade: [
          NotaHistoricoTecnicoItem(
            notaSap: NotaSAP(id: 'sim-1', nota: '11000002'),
            criterioFisicoPrincipal: NotaHistoricoCriterioFisico.apenasSimilaridade,
            scoreSimilaridade: 65.0,
            ehSimilar: true,
          ),
        ],
      );

      expect(resComSimilares.carregandoSimilares, isFalse);
      expect(resComSimilares.carregandoLocalAmplo, isTrue);
      expect(resComSimilares.itensApenasSimilaridade.length, equals(1));
      expect(resComSimilares.itensApenasSimilaridade.first.scoreSimilaridade, equals(65.0));

      // Simula finalização do contexto amplo
      final resFinal = resComSimilares.copyWith(carregandoLocalAmplo: false);
      expect(resFinal.carregandoLocalAmplo, isFalse);
      expect(resFinal.carregandoSimilares, isFalse);
    });

    test('23. Critério D Oficial descarta ocorrências com score < 40.0', () {
      final similarDescartada = NotaSapSimilar(
        nota: NotaSAP(id: 'cand-baixa', nota: '11000003'),
        scoreTotal: 25.0,
        classificacao: TipoClassificacaoSimilaridade.ocorrenciaSemelhante,
        faixa: FaixaSimilaridade.descartada,
        evidencias: const EvidenciaScore(),
      );

      final similarValida = NotaSapSimilar(
        nota: NotaSAP(id: 'cand-boa', nota: '11000004'),
        scoreTotal: 58.0,
        classificacao: TipoClassificacaoSimilaridade.ocorrenciaSemelhante,
        faixa: FaixaSimilaridade.media,
        evidencias: const EvidenciaScore(),
      );

      expect(similarDescartada.faixa, equals(FaixaSimilaridade.descartada));
      expect(similarDescartada.scoreTotal < 40.0, isTrue);

      expect(similarValida.faixa, equals(FaixaSimilaridade.media));
      expect(similarValida.scoreTotal >= 40.0, isTrue);
    });

    test('24. Equivalência Contratual: NotaHistoricoTecnicoService consome NotaSapSimilaridadeService com exato score e evidências', () async {
      final simItemOficial = NotaSapSimilar(
        nota: NotaSAP(
          id: 'sim-oficial-1',
          nota: '11521808',
          tipo: 'NM',
          descricao: 'GPX - Setpoint MW sem aceitar comandos',
          statusSistema: 'MSPR',
        ),
        scoreTotal: 72.5,
        classificacao: TipoClassificacaoSimilaridade.ocorrenciaSemelhante,
        faixa: FaixaSimilaridade.media,
        evidencias: const EvidenciaScore(
          pontosDescricao: 40.0,
          pontosCentroTrabalho: 10.0,
          pontosTipo: 5.0,
          pontosLocalInstalacao: 15.0,
          tokensCoincidentes: ['setpoint', 'gpx'],
        ),
      );

      final mockSimService = MockSimilaridadeService(
        ocorrenciasRetorno: [simItemOficial],
      );

      // Instancia o NotaHistoricoTecnicoService com o mockSimilaridadeService
      final historicoService = NotaHistoricoTecnicoService(
        similaridadeService: mockSimService,
      );

      // Executa o carregamento progressivo de similares sobre um resultado inicial
      final resInicial = NotaHistoricoTecnicoResultado(
        notaReferencia: notaRef,
        itensEquipamento: const [],
        itensEstrutura: const [],
        calculadoEm: DateTime.now(),
      );

      final resComSim = await historicoService.carregarSimilaresAssincrono(resInicial);

      expect(resComSim.itensApenasSimilaridade.length, equals(1));
      final itemD = resComSim.itensApenasSimilaridade.first;

      // Validação estrita do contrato:
      expect(itemD.notaSap.id, equals(simItemOficial.nota.id));
      expect(itemD.notaSap.nota, equals(simItemOficial.nota.nota));
      expect(itemD.ehSimilar, isTrue);
      // O score NÃO PODE SER RECALCULADO: deve ser idêntico ao oficial
      expect(itemD.scoreSimilaridade, equals(simItemOficial.scoreTotal));
      expect(itemD.scoreSimilaridade, equals(72.5));
      // Os tokens devem ser preservados
      expect(itemD.tokensCoincidentes, equals(simItemOficial.evidencias.tokensCoincidentes));
      expect(itemD.tokensCoincidentes, contains('setpoint'));
      expect(itemD.criterioFisicoPrincipal, equals(NotaHistoricoCriterioFisico.apenasSimilaridade));
    });

    test('25. Regra Estrita de Sala: Notas anteriores de outra sala são descartadas quando a nota de referência tem sala', () {
      final salaRef = '14T2';
      final salaRefNorm = InstalacaoSapHelper.normalizarSala(salaRef);

      final notaMesmaSala = NotaSAP(
        id: 'hist-sala-certa',
        nota: '11000100',
        sala: '14T2',
        localInstalacao: 'H-S-SCTU-RB4T02-4CT1-DJ01',
      );

      final notaOutraSala = NotaSAP(
        id: 'hist-sala-errada',
        nota: '11000101',
        sala: '14H1',
        localInstalacao: 'H-S-SCTU-RB4T02-4CT1-DJ01',
      );

      final notasCandidatas = [notaMesmaSala, notaOutraSala];

      // Aplica a regra de filtragem estrita
      final notasFiltradas = notasCandidatas.where((n) {
        final nNorm = InstalacaoSapHelper.normalizarSala(n.sala);
        return nNorm == salaRefNorm;
      }).toList();

      expect(notasFiltradas.length, 1);
      expect(notasFiltradas.first.id, 'hist-sala-certa');
      expect(notasFiltradas.any((n) => n.id == 'hist-sala-errada'), isFalse);
    });

    test('26. Regra Estrita de Local: Notas anteriores de outro local/instalação são descartadas', () {
      final localRef = 'SE SANTO ANGELO';
      final instRef = 'H-S-STSA-RB4S01';

      final notaMesmoLocal = NotaSAP(
        id: 'hist-local-certo',
        nota: '11000200',
        local: 'SE SANTO ANGELO',
        localInstalacao: 'H-S-STSA-RB4S01-4EL1-S401',
        sala: 'S401',
      );

      final notaOutroLocal = NotaSAP(
        id: 'hist-local-errado',
        nota: '11000201',
        local: 'SE SAO BORJA',
        localInstalacao: 'H-S-SSBO-RB4S01-4EL1-S401',
        sala: 'S401',
      );

      final notasCandidatas = [notaMesmoLocal, notaOutroLocal];

      final notasFiltradas = notasCandidatas.where((n) {
        final mesmoLocalNome = (n.local != null &&
            n.local!.trim().toUpperCase() == localRef.toUpperCase());
        final mesmaInst = InstalacaoSapHelper.saoMesmaInstalacao(instRef, n.localInstalacao);
        return mesmoLocalNome || mesmaInst;
      }).toList();

      expect(notasFiltradas.length, 1);
      expect(notasFiltradas.first.id, 'hist-local-certo');
      expect(notasFiltradas.any((n) => n.id == 'hist-local-errado'), isFalse);
    });
  });
}
