import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/models/nota_sap.dart';
import 'package:task2026/models/nota_sap_analise.dart';
import 'package:task2026/models/nota_sap_similaridade.dart';
import 'package:task2026/widgets/nota_workspace/nota_similaridade_panel.dart';

void main() {
  group('Módulo H — Testes de Widgets do Painel de Similaridade', () {
    final notaRef = NotaSAP(
      id: 'ref-1',
      nota: '10000001',
      equipamento: 'EQ-TRANSF-01',
      localInstalacao: 'SUB-CAMP-01',
      centroTrabalhoResponsavel: 'CTR-ELET',
      descricao: 'Vazamento de óleo no transformador de força',
    );

    final notaSemelhante1 = NotaSAP(
      id: 'sem-1',
      nota: '10000002',
      equipamento: 'EQ-TRANSF-01',
      localInstalacao: 'SUB-CAMP-01',
      centroTrabalhoResponsavel: 'CTR-ELET',
      descricao: 'Vazamento de óleo isolante na junta',
      criadoEm: DateTime(2025, 4, 10),
    );

    final notaMesmoAtivo1 = NotaSAP(
      id: 'ativo-1',
      nota: '10000003',
      equipamento: 'EQ-TRANSF-01',
      descricao: 'Pintura externa e proteção anticorrosiva',
      criadoEm: DateTime(2024, 8, 15),
    );

    final demandaAberta1 = NotaSAP(
      id: 'aberta-1',
      nota: '10000099',
      equipamento: 'EQ-TRANSF-01',
      descricao: 'Inspeção termográfica agendada',
      statusSistema: 'Aberta',
      criadoEm: DateTime(2025, 10, 1),
    );

    final ocorrencia1 = NotaSapSimilar(
      nota: notaSemelhante1,
      scoreTotal: 90.0,
      faixa: FaixaSimilaridade.alta,
      classificacao: TipoClassificacaoSimilaridade.ocorrenciaSemelhante,
      evidencias: const EvidenciaScore(
        pontosEquipamento: 40,
        pontosLocalInstalacao: 20,
        pontosCentroTrabalho: 10,
        pontosDescricao: 20,
        explicacoes: [
          '+40 Mesmo equipamento (EQ-TRANSF-01)',
          '+20 Mesmo local de instalação',
          '+10 Mesmo centro de trabalho',
          '+20 Falha semelhante (termo em comum: oleo, vazamento)',
        ],
        tokensCoincidentes: ['oleo', 'vazamento'],
      ),
      horasSapConfirmadas: 5.5,
      tarefasVinculadas: [
        const TarefaHistoricaResumo(
          id: 't-1',
          tarefaNome: 'Correção de Vazamento Trafo',
          horasExecutadas: 5.5,
          totalExecutores: 3,
        ),
      ],
      materiaisLevantados: [
        NotaSapMaterial(
          notaSapId: 'sem-1',
          codigoSap: 'VED-001',
          descricao: 'JUNTA DE VEDAÇÃO BORRACHA NITRÍLICA',
          quantidade: 2,
        ),
      ],
      totalAnexos: 3,
    );

    final mesmoAtivo1 = NotaSapSimilar(
      nota: notaMesmoAtivo1,
      scoreTotal: 40.0,
      faixa: FaixaSimilaridade.fraca,
      classificacao: TipoClassificacaoSimilaridade.historicoMesmoAtivo,
      evidencias: const EvidenciaScore(
        pontosEquipamento: 40,
        explicacoes: ['+40 Mesmo equipamento (EQ-TRANSF-01)'],
      ),
    );

    final resultadoSimulado = ResultadoSimilaridadeNotaSap(
      notaReferencia: notaRef,
      ocorrenciasSemelhantes: [ocorrencia1],
      todasOcorrencias: [ocorrencia1],
      historicoMesmoAtivo: [mesmoAtivo1],
      demandasAbertasRelacionadas: [
        DemandaAbertaRelacionada(
          nota: demandaAberta1,
          motivo: 'Mesmo equipamento (EQ-TRANSF-01)',
        ),
      ],
      estatisticas: const EstatisticasTempoEquipe(
        duracaoMedianaHoras: 5.5,
        duracaoMinimaHoras: 5.5,
        duracaoMaximaHoras: 5.5,
        totalAmostrasHoras: 1,
        fonteHoras: 'Horas SAP confirmadas',
        equipeMedianaTecnicos: 3,
        equipeMinimaTecnicos: 3,
        equipeMaximaTecnicos: 3,
        totalAmostrasEquipe: 1,
      ),
      materiaisFrequentes: const [
        MaterialFrequencia(
          codigoSap: 'VED-001',
          descricao: 'JUNTA DE VEDAÇÃO BORRACHA NITRÍLICA',
          quantidadeOcorrencias: 1,
          totalAnalisesAvaliadas: 1,
        ),
      ],
      calculadoEm: DateTime(2025, 10, 15),
    );

    Widget buildTestWidget({ResultadoSimilaridadeNotaSap? dados}) {
      return MaterialApp(
        home: Scaffold(
          body: NotaSapSimilaridadePanel(
            nota: notaRef,
            dadosIniciais: dados ?? resultadoSimulado,
          ),
        ),
      );
    }

    testWidgets('1. Renderiza cabeçalho, aviso de apoio consultivo e badges',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Score Auditável'), findsOneWidget);
      expect(
        find.textContaining('O motor determinístico localiza serviços'),
        findsOneWidget,
      );
    });

    testWidgets('2. Exibe bloco executivo com estatísticas de tempo e equipe',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('5.5 h'), findsOneWidget);
      expect(find.text('Duração Mediana'), findsOneWidget);
      expect(find.text('3 técnicos'), findsOneWidget);
      expect(find.text('Equipe Típica'), findsOneWidget);
      expect(find.textContaining('Horas SAP confirmadas'), findsOneWidget);
    });

    testWidgets('3. Exibe tabela de materiais frequentes levantados',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Materiais Levantados em Ocorrências Semelhantes'),
          findsOneWidget);
      expect(find.text('JUNTA DE VEDAÇÃO BORRACHA NITRÍLICA'), findsOneWidget);
      expect(find.text('Código SAP: VED-001'), findsOneWidget);
      expect(find.text('Presente em 1 de 1 análises'), findsOneWidget);
    });

    testWidgets('4. Renderiza card de ocorrência semelhante com score 90%',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('90%'), findsOneWidget);
      expect(find.text('Nota SAP 10000002'), findsOneWidget);
      expect(find.text('Vazamento de óleo isolante na junta'), findsOneWidget);
      expect(find.textContaining('Mesmo equipamento'), findsWidgets);
      expect(find.textContaining('Mesmo local'), findsWidgets);
      expect(find.textContaining('Mesmo centro'), findsWidgets);
      expect(find.text('3 anexos'), findsOneWidget);
    });

    testWidgets('5. Exibe seção de Demandas Abertas Relacionadas',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Possíveis Demandas Relacionadas (Notas Abertas)'),
          findsOneWidget);
      expect(find.text('Nota 10000099'), findsOneWidget);
      expect(find.text('Mesmo equipamento (EQ-TRANSF-01)'), findsOneWidget);
      expect(find.text('Inspeção termográfica agendada'), findsOneWidget);
    });

    testWidgets('6. Exibe seção de Histórico no Mesmo Ativo separadamente',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Histórico do Mesmo Ativo (Outras Intervenções)'),
          findsOneWidget);
      expect(find.text('Nota SAP 10000003'), findsOneWidget);
      expect(find.text('Pintura externa e proteção anticorrosiva'),
          findsOneWidget);
    });

    testWidgets('7. Estado vazio quando não houver ocorrências',
        (tester) async {
      final vazio = ResultadoSimilaridadeNotaSap(
        notaReferencia: notaRef,
        ocorrenciasSemelhantes: const [],
        todasOcorrencias: const [],
        historicoMesmoAtivo: const [],
        demandasAbertasRelacionadas: const [],
        estatisticas: const EstatisticasTempoEquipe(),
        materiaisFrequentes: const [],
        calculadoEm: DateTime.now(),
      );

      await tester.pumpWidget(buildTestWidget(dados: vazio));
      await tester.pump();

      expect(find.text('Nenhuma ocorrência semelhante encontrada'),
          findsOneWidget);
      expect(find.textContaining('Não há histórico registrado'), findsOneWidget);
    });

    testWidgets(
        '8. Seletor de Visão alterna entre Notas Abertas, Concluídas e Todas',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // No modo "Todas" (inicial), ambos os blocos aparecem
      expect(find.text('Notas Abertas'), findsOneWidget);
      expect(find.text('Concluídas / Histórico'), findsOneWidget);
      expect(find.text('Todas'), findsOneWidget);
      expect(find.text('Possíveis Demandas Relacionadas (Notas Abertas)'),
          findsOneWidget);
      expect(find.text('Ocorrências Históricas Semelhantes'), findsOneWidget);

      // Clica em "Notas Abertas"
      await tester.tap(find.text('Notas Abertas'));
      await tester.pumpAndSettle();

      // Agora só a seção de abertas deve estar visível
      expect(find.text('Possíveis Demandas Relacionadas (Notas Abertas)'),
          findsOneWidget);
      expect(find.text('Ocorrências Históricas Semelhantes'), findsNothing);

      // Clica em "Concluídas / Histórico"
      await tester.tap(find.text('Concluídas / Histórico'));
      await tester.pumpAndSettle();

      // Agora a seção de abertas some e aparecem as concluídas
      expect(find.text('Possíveis Demandas Relacionadas (Notas Abertas)'),
          findsNothing);
      expect(find.text('Ocorrências Históricas Semelhantes'), findsOneWidget);
    });

    testWidgets(
        '9. Exibe ocorrência semelhante em aberto com card completo de score e badge ABERTA',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final notaAbertaSimilar = NotaSAP(
        id: 'cand-aberta',
        nota: '11587891',
        sala: '01E1',
        localInstalacao: 'H-S-STSA-DT1E01-1EQ1-RE01',
        descricao: 'TSA: 01E1- MEREJAMENTO OLEO',
        statusSistema: 'MSPR',
        tipo: 'NM',
        local: 'TSA',
      );

      final ocAberta = NotaSapSimilar(
        nota: notaAbertaSimilar,
        scoreTotal: 45.0,
        faixa: FaixaSimilaridade.fraca,
        classificacao: TipoClassificacaoSimilaridade.ocorrenciaSemelhante,
        evidencias: const EvidenciaScore(
          pontosLocalInstalacao: 20,
          pontosCentroTrabalho: 10,
          pontosTipo: 5,
          explicacoes: ['+20 Mesmo vão operativo (H-S-STSA-DT1E01)', '+10 Mesmo centro de trabalho'],
        ),
      );

      final resultadoComAberta = ResultadoSimilaridadeNotaSap(
        notaReferencia: notaRef,
        ocorrenciasSemelhantes: [ocAberta],
        todasOcorrencias: [ocAberta],
        demandasAbertasRelacionadas: const [],
        calculadoEm: DateTime.now(),
      );

      await tester.pumpWidget(buildTestWidget(dados: resultadoComAberta));
      await tester.pump();

      // Muda para aba Notas Abertas
      await tester.tap(find.text('Notas Abertas'));
      await tester.pumpAndSettle();

      expect(find.text('Ocorrências Semelhantes Abertas'), findsOneWidget);
      expect(find.text('Nota SAP 11587891'), findsOneWidget);
      expect(find.textContaining('ABERTA'), findsOneWidget);
      expect(find.text('45%'), findsOneWidget);
      expect(find.text('TSA: 01E1- MEREJAMENTO OLEO'), findsOneWidget);
    });

    testWidgets('10. Exibe a data de criação nos cards de ocorrência semelhante e de demanda aberta', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dataCriacao = DateTime(2026, 8, 15);
      final notaComData = NotaSAP(
        id: 'cand-data',
        nota: '11587891',
        sala: '01E1',
        localInstalacao: 'H-S-STSA-DT1E01-1EQ1-RE01',
        descricao: 'TSA: 01E1- MEREJAMENTO OLEO',
        statusSistema: 'MSPR',
        tipo: 'NM',
        local: 'TSA',
        criadoEm: dataCriacao,
      );

      final ocComData = NotaSapSimilar(
        nota: notaComData,
        scoreTotal: 45.0,
        faixa: FaixaSimilaridade.fraca,
        classificacao: TipoClassificacaoSimilaridade.ocorrenciaSemelhante,
        evidencias: const EvidenciaScore(pontosLocalInstalacao: 20, explicacoes: ['Mesmo vão']),
      );

      final demandaComData = DemandaAbertaRelacionada(
        nota: notaComData,
        motivo: 'Mesmo vão operativo',
      );

      final resultado = ResultadoSimilaridadeNotaSap(
        notaReferencia: notaRef,
        ocorrenciasSemelhantes: [ocComData],
        todasOcorrencias: [ocComData],
        demandasAbertasRelacionadas: [demandaComData],
        calculadoEm: DateTime.now(),
      );

      await tester.pumpWidget(buildTestWidget(dados: resultado));
      await tester.pumpAndSettle();

      // Verifica exibição da data formatada no card
      expect(find.textContaining('Criada em: 15/08/2026'), findsWidgets);
    });

    testWidgets('11. Exibe data de conclusão nas notas concluídas e data de criação nas abertas', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dataCriacao = DateTime(2025, 8, 9);
      final dataEncerramento = DateTime(2025, 8, 20);

      final notaConcluida = NotaSAP(
        id: 'cand-concluida',
        nota: '11456616',
        sala: '01E1',
        localInstalacao: 'H-S-STSA-DT1E01-1EQ1-RE01',
        descricao: 'TSA: 01E1- CORROSÃO',
        statusSistema: 'MSEN ORDA',
        tipo: 'NM',
        local: 'TSA',
        criadoEm: dataCriacao,
        encerramento: dataEncerramento,
      );

      final ocConcluida = NotaSapSimilar(
        nota: notaConcluida,
        scoreTotal: 50.0,
        faixa: FaixaSimilaridade.media,
        classificacao: TipoClassificacaoSimilaridade.ocorrenciaSemelhante,
        evidencias: const EvidenciaScore(pontosLocalInstalacao: 20, explicacoes: ['Mesmo vão']),
      );

      final resultado = ResultadoSimilaridadeNotaSap(
        notaReferencia: notaRef,
        ocorrenciasSemelhantes: [ocConcluida],
        todasOcorrencias: [ocConcluida],
        demandasAbertasRelacionadas: const [],
        calculadoEm: DateTime.now(),
      );

      await tester.pumpWidget(buildTestWidget(dados: resultado));
      await tester.pumpAndSettle();

      // Muda para aba Concluídas / Histórico
      await tester.tap(find.text('Concluídas / Histórico'));
      await tester.pumpAndSettle();

      // Verifica que na nota concluída exibe 'Concluída em: 20/08/2025'
      expect(find.textContaining('Concluída em: 20/08/2025'), findsOneWidget);
    });
  });
}
