import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/models/nota_sap.dart';
import 'package:task2026/models/nota_sap_analise.dart';
import 'package:task2026/models/nota_historico_tecnico.dart';
import 'package:task2026/services/nota_historico_tecnico_service.dart';
import 'package:task2026/widgets/nota_workspace/nota_workspace_historico_tecnico_section.dart';
import 'package:task2026/widgets/nota_workspace/nota_anexo_viewer_dialog.dart';

class MockHistoricoService extends NotaHistoricoTecnicoService {
  final NotaHistoricoTecnicoResultado mockResultado;
  final NotaHistoricoTecnicoItem Function(NotaHistoricoTecnicoItem item)? onLazy;

  MockHistoricoService({
    required this.mockResultado,
    this.onLazy,
  });

  @override
  Future<NotaHistoricoTecnicoResultado> carregarHistoricoAtivoUtil({
    required NotaSAP notaReferencia,
    bool forceRefresh = false,
  }) async {
    return mockResultado;
  }

  @override
  Future<NotaHistoricoTecnicoResultado> carregarSimilaresAssincrono(
    NotaHistoricoTecnicoResultado resultadoAtual, {
    bool forceRefresh = false,
  }) async {
    return resultadoAtual;
  }

  @override
  Future<NotaHistoricoTecnicoResultado> carregarLocalAmploAssincrono(
    NotaHistoricoTecnicoResultado resultadoAtual,
  ) async {
    return resultadoAtual;
  }

  @override
  Future<NotaHistoricoTecnicoResultado> buscarHistoricoTecnico({
    required NotaSAP notaReferencia,
    bool forceRefresh = false,
  }) async {
    return mockResultado;
  }

  @override
  Future<NotaHistoricoTecnicoItem> carregarDetalhesLazy(NotaHistoricoTecnicoItem item) async {
    if (onLazy != null) return onLazy!(item);
    return item.copyWithDetalhes(anexos: const [], tasks: const []);
  }
}

Widget _wrapComMaterial(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: child,
      ),
    ),
  );
}

void main() {
  group('NotaWorkspaceHistoricoTecnicoSection - Testes de Widget', () {
    final notaRef = NotaSAP(
      id: 'nota-ref',
      nota: '11599351',
      equipamento: '11340679',
      sala: '14T2',
      localInstalacao: 'H-S-SCTU-RB4T02-4CT1-DJ01',
    );

    final notaHist1 = NotaSAP(
      id: 'nota-hist-1',
      nota: '11400868',
      descricao: 'Troca de isolador devido a corrosao severa',
      equipamento: '11340679',
      sala: '14T2',
      statusSistema: 'MSEN',
      criadoEm: DateTime(2025, 3, 14),
    );

    final notaHist2 = NotaSAP(
      id: 'nota-hist-2',
      nota: '11350020',
      descricao: 'Inspeção periódica de estrutura',
      equipamento: '99999999',
      sala: '14T2',
      statusSistema: 'MSPR',
      criadoEm: DateTime(2024, 11, 5),
    );

    final item1 = NotaHistoricoTecnicoItem(
      notaSap: notaHist1,
      criterioFisicoPrincipal: NotaHistoricoCriterioFisico.mesmoEquipamento,
      motivosFisicos: const ['Mesmo equipamento (11340679)', 'Mesma estrutura (14T2)'],
      ehSimilar: true,
      scoreSimilaridade: 82.0,
      totalAnexos: 2,
      temAnalise: true,
      totalTasks: 1,
    );

    final item2 = NotaHistoricoTecnicoItem(
      notaSap: notaHist2,
      criterioFisicoPrincipal: NotaHistoricoCriterioFisico.mesmaEstrutura,
      motivosFisicos: const ['Mesma estrutura (14T2)'],
      totalAnexos: 0,
      totalTasks: 0,
    );

    testWidgets('Exibe lista com cards de notas históricas e badges', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockService = MockHistoricoService(
        mockResultado: NotaHistoricoTecnicoResultado(
          notaReferencia: notaRef,
          itensEquipamento: [item1],
          itensEstrutura: [item2],
          todosItensDeduplicados: [item1, item2],
          calculadoEm: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        _wrapComMaterial(
          NotaWorkspaceHistoricoTecnicoSection(
            nota: notaRef,
            service: mockService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verifica cabeçalho e títulos dos cards
      expect(find.text('Histórico Técnico de Notas Anteriores'), findsOneWidget);
      expect(find.text('Nota SAP 11400868'), findsOneWidget);
      expect(find.text('Nota SAP 11350020'), findsOneWidget);

      // Badges
      expect(find.text('Mesmo Equipamento'), findsWidgets);
      expect(find.text('Mesma Estrutura'), findsWidgets);
      expect(find.text('Similar: 82%'), findsOneWidget);

      // Inventário
      expect(find.text('2 anexos'), findsOneWidget);
      expect(find.text('Análise técnica'), findsOneWidget);
      expect(find.text('1 tarefas'), findsOneWidget);
    });

    testWidgets('Expandir card dispara lazy loading e exibe anexos históricos', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final anexoFake = NotaSapAnexo(
        id: 'anx-1',
        notaSapId: 'nota-hist-1',
        nomeArquivo: 'isolador_danificado.jpg',
        tipoArquivo: NotaAnexoTipo.imagem,
        caminhoArquivo: 'notas-sap/nota-hist-1/isolador_danificado.jpg',
        tamanhoBytes: 1024,
      );

      final mockService = MockHistoricoService(
        mockResultado: NotaHistoricoTecnicoResultado(
          notaReferencia: notaRef,
          itensEquipamento: [item1],
          todosItensDeduplicados: [item1],
          calculadoEm: DateTime.now(),
        ),
        onLazy: (item) {
          return item.copyWithDetalhes(
            anexos: [anexoFake],
            tasks: const [],
          );
        },
      );

      await tester.pumpWidget(
        _wrapComMaterial(
          NotaWorkspaceHistoricoTecnicoSection(
            nota: notaRef,
            service: mockService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Clica em 'Ver Detalhes' para expandir
      await tester.tap(find.text('Ver Detalhes').first);
      await tester.pumpAndSettle();

      // Verifica que a seção de anexos expandiu
      expect(find.text('Anexos Históricos (1)'), findsOneWidget);
      expect(find.text('isolador_danificado.jpg'), findsOneWidget);
    });

    testWidgets('Viewer abre anexo histórico em modo read-only com banner', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final anexoFake = NotaSapAnexo(
        id: 'anx-hist-1',
        notaSapId: 'nota-hist-1',
        nomeArquivo: 'evidencia_antiga.jpg',
        tipoArquivo: NotaAnexoTipo.imagem,
        caminhoArquivo: 'notas-sap/nota-hist-1/evidencia_antiga.jpg',
        tamanhoBytes: 2048,
      );

      final mockService = MockHistoricoService(
        mockResultado: NotaHistoricoTecnicoResultado(
          notaReferencia: notaRef,
          itensEquipamento: [item1],
          todosItensDeduplicados: [item1],
          calculadoEm: DateTime.now(),
        ),
        onLazy: (item) => item.copyWithDetalhes(
          anexos: [anexoFake],
          tasks: const [],
        ),
      );

      await tester.pumpWidget(
        _wrapComMaterial(
          NotaWorkspaceHistoricoTecnicoSection(
            nota: notaRef,
            service: mockService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Expande o card
      await tester.tap(find.text('Ver Detalhes').first);
      await tester.pumpAndSettle();

      // Clica na miniatura do anexo para abrir o viewer
      await tester.tap(find.text('evidencia_antiga.jpg'));
      await tester.pumpAndSettle();

      // Verifica que o viewer abriu com o banner de Nota Histórica (Read-Only)
      expect(find.byType(NotaAnexoViewerDialog), findsOneWidget);
      expect(find.textContaining('NOTA HISTÓRICA SAP 11400868'), findsOneWidget);

      // Garante que os botões de edição NÃO existem no modo histórico
      expect(find.text('Marcar relevante'), findsNothing);
      expect(find.text('Anotar'), findsNothing);

      // Fecha o viewer
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.byType(NotaAnexoViewerDialog), findsNothing);
    });

    testWidgets('Clique em [Abrir Nota] aciona o callback com a nota histórica', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      NotaSAP? notaAberta;

      final mockService = MockHistoricoService(
        mockResultado: NotaHistoricoTecnicoResultado(
          notaReferencia: notaRef,
          itensEquipamento: [item1],
          todosItensDeduplicados: [item1],
          calculadoEm: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        _wrapComMaterial(
          NotaWorkspaceHistoricoTecnicoSection(
            nota: notaRef,
            service: mockService,
            onAbrirNotaHistorica: (n) => notaAberta = n,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Clica no botão 'Abrir Nota'
      await tester.tap(find.text('Abrir Nota'));
      await tester.pumpAndSettle();

      expect(notaAberta, isNotNull);
      expect(notaAberta!.nota, equals('11400868'));
    });
  });
}
