import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/design_system/theme/taskflow_theme_extension.dart';
import 'package:task2026/models/nota_sap.dart';
import 'package:task2026/models/nota_sap_analise.dart';
import 'package:task2026/models/nota_sap_analise_evidencia.dart';
import 'package:task2026/models/nota_historico_tecnico.dart';
import 'package:task2026/models/nota_historico_visual.dart';
import 'package:task2026/services/nota_historico_tecnico_service.dart';
import 'package:task2026/services/nota_historico_visual_service.dart';
import 'package:task2026/services/nota_sap_analise_service.dart';
import 'package:task2026/widgets/nota_workspace/nota_workspace_historico_anexos_section.dart';
import 'package:task2026/widgets/nota_workspace/nota_workspace_historico_visual_section.dart';
import 'package:task2026/widgets/nota_workspace/nota_workspace_attachments_tab.dart';
import 'package:task2026/widgets/nota_workspace/nota_anexo_viewer_dialog.dart';

class MockNotaHistoricoTecnicoService extends NotaHistoricoTecnicoService {
  final Future<NotaHistoricoTecnicoResultado> Function(NotaSAP nota)? onCarregarUtil;
  final Future<NotaHistoricoTecnicoItem> Function(NotaHistoricoTecnicoItem item)? onLazy;

  MockNotaHistoricoTecnicoService({
    this.onCarregarUtil,
    this.onLazy,
  });

  @override
  Future<NotaHistoricoTecnicoResultado> carregarHistoricoAtivoUtil({
    required NotaSAP notaReferencia,
    bool forceRefresh = false,
  }) async {
    if (onCarregarUtil != null) {
      return onCarregarUtil!(notaReferencia);
    }
    return NotaHistoricoTecnicoResultado(
      notaReferencia: notaReferencia,
      calculadoEm: DateTime.now(),
    );
  }

  @override
  Future<NotaHistoricoTecnicoResultado> carregarSimilaresAssincrono(
    NotaHistoricoTecnicoResultado resultadoAtual, {
    bool forceRefresh = false,
  }) async {
    return resultadoAtual;
  }

  @override
  Future<NotaHistoricoTecnicoItem> carregarDetalhesLazy(
    NotaHistoricoTecnicoItem item,
  ) async {
    if (onLazy != null) return onLazy!(item);
    return item;
  }
}

class MockNotaHistoricoVisualService extends NotaHistoricoVisualService {
  final Future<HistoricoVisualResultado> Function(NotaSAP nota)? onBuscar;

  MockNotaHistoricoVisualService({this.onBuscar});

  @override
  Future<HistoricoVisualResultado> buscarHistoricoVisual(
    NotaSAP nota, {
    int limitePorNivel = 12,
  }) async {
    if (onBuscar != null) return onBuscar!(nota);
    return HistoricoVisualResultado.vazio(localNome: nota.local);
  }
}

class MockNotaSapAnaliseService extends Fake implements NotaSapAnaliseService {
  final List<NotaSapAnexo> anexos = [];

  @override
  Future<List<NotaSapAnexo>> listarAnexos(String notaSapId) async {
    return List.from(anexos);
  }

  @override
  Future<Map<String, List<NotaTipoVinculoEvidencia>>> buscarUsoDosAnexos(
      String notaSapId) async {
    return {};
  }

  @override
  Future<Map<String, List<NotaTipoVinculoEvidencia>>> buscarUsoDosAnexosHistoricos(
      String notaSapId) async {
    return {};
  }

  @override
  Future<String> obterUrlAssinada(
    NotaSapAnexo anexo, {
    Duration expires = const Duration(hours: 1),
  }) async {
    return 'https://storage.local/test/${anexo.caminhoArquivo}';
  }

  @override
  Future<Map<String, List<NotaTipoVinculoEvidencia>>> buscarUsoDasFotosDoAlbum(String notaId) async {
    return {};
  }
}

Widget _wrapComTema(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      extensions: [
        TaskFlowThemeExtension.light(),
      ],
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        child: child,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final notaAtual = NotaSAP(
    id: 'nota-atual-1',
    nota: '11592131',
    descricao: 'PD-LE MV ARVORE NO MURO',
    localInstalacao: 'H-L-STSASPRI-RB4S01-4LT1',
    local: 'STSASPRI',
    sala: '003/2',
    equipamento: '11767076',
    criadoEm: DateTime(2026, 10, 15),
  );

  final notaHistA = NotaSAP(
    id: 'nota-hist-A',
    nota: '11585837',
    descricao: 'PD-SOB FASE LE MV ARVORES',
    localInstalacao: 'H-L-STSASPRI-RB4S01-4LT1',
    sala: '003/2',
    equipamento: '11767076',
    statusSistema: 'MSPR',
    criadoEm: DateTime(2026, 8, 7),
  );

  final notaHistB = NotaSAP(
    id: 'nota-hist-B',
    nota: '11565366',
    descricao: 'SUBSTITUICAO ISOLADOR DE ANEL',
    localInstalacao: 'H-L-STSASPRI-RB4S01-4LT1',
    sala: '003/2',
    equipamento: '99999999',
    statusSistema: 'MSEN',
    criadoEm: DateTime(2026, 5, 20),
  );

  final notaSemAnexo = NotaSAP(
    id: 'nota-sem-anexo',
    nota: '11400000',
    descricao: 'INSPECAO VISUAL ROTINEIRA',
    sala: '003/2',
    equipamento: '11767076',
    criadoEm: DateTime(2026, 1, 10),
  );

  final anexoFoto = NotaSapAnexo(
    id: 'anexo-foto-1',
    notaSapId: 'nota-hist-A',
    nomeArquivo: '11585837_Imagem1.jpg',
    nomeOriginal: 'Foto Arvores.jpg',
    tipoArquivo: NotaAnexoTipo.imagem,
    caminhoArquivo: 'nota-hist-A/11585837_Imagem1.jpg',
    tamanhoBytes: 1024 * 500,
    origem: 'SAP',
    createdAt: DateTime(2026, 8, 7),
  );

  final anexoPdf = NotaSapAnexo(
    id: 'anexo-pdf-1',
    notaSapId: 'nota-hist-A',
    nomeArquivo: 'laudo_tecnico.pdf',
    nomeOriginal: 'Laudo Pericial.pdf',
    tipoArquivo: NotaAnexoTipo.pdf,
    caminhoArquivo: 'nota-hist-A/laudo_tecnico.pdf',
    tamanhoBytes: 1024 * 1200,
    origem: 'SAP',
    createdAt: DateTime(2026, 8, 7),
  );

  final itemA = NotaHistoricoTecnicoItem(
    notaSap: notaHistA,
    criterioFisicoPrincipal: NotaHistoricoCriterioFisico.mesmoEquipamento,
    motivosFisicos: const ['Mesmo equipamento (11767076)'],
    totalAnexos: 2,
    detalhesCarregados: true,
    anexos: [anexoFoto, anexoPdf],
  );

  final itemB = NotaHistoricoTecnicoItem(
    notaSap: notaHistB,
    criterioFisicoPrincipal: NotaHistoricoCriterioFisico.mesmaEstrutura,
    motivosFisicos: const ['Mesma estrutura (003/2)'],
    totalAnexos: 1,
    detalhesCarregados: true,
    anexos: [anexoFoto],
  );

  final itemSemAnexo = NotaHistoricoTecnicoItem(
    notaSap: notaSemAnexo,
    criterioFisicoPrincipal: NotaHistoricoCriterioFisico.mesmoEquipamento,
    motivosFisicos: const ['Mesmo equipamento (11767076)'],
    totalAnexos: 0,
    detalhesCarregados: true,
    anexos: const [],
  );

  group('NotaWorkspaceHistoricoAnexosSection - Testes Completos', () {
    testWidgets('1, 2, 3: Default Notas Anteriores, contadores e seletor', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockTecnico = MockNotaHistoricoTecnicoService(
        onCarregarUtil: (n) async => NotaHistoricoTecnicoResultado(
          notaReferencia: n,
          itensEquipamento: [itemA],
          itensEstrutura: [itemB],
          todosItensDeduplicados: [itemA, itemB, itemSemAnexo],
          calculadoEm: DateTime.now(),
        ),
      );

      final mockVisual = MockNotaHistoricoVisualService(
        onBuscar: (n) async => const HistoricoVisualResultado(
          itens: [],
          totalEquipamento: 0,
          totalSala: 0,
          totalLocal: 0,
        ),
      );

      await tester.pumpWidget(
        _wrapComTema(
          NotaWorkspaceHistoricoAnexosSection(
            nota: notaAtual,
            historicoTecnicoService: mockTecnico,
            historicoVisualService: mockVisual,
            analiseService: MockNotaSapAnaliseService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Título
      expect(find.text('Histórico de Anexos'), findsOneWidget);

      // Seletor presente
      expect(find.text('Notas Anteriores'), findsOneWidget);
      expect(find.text('Álbuns de Campo'), findsOneWidget);

      // Contadores nos seletores: 2 notas com anexo
      expect(find.text('2'), findsWidgets);

      // Contador discriminado: "2 Notas • 3 anexos encontrados"
      expect(find.text('2 Notas • 3 anexos encontrados'), findsOneWidget);

      // Alterna para Álbuns de Campo
      await tester.tap(find.text('Álbuns de Campo'));
      await tester.pumpAndSettle();

      expect(find.text('0 fotografias registradas nos álbuns'), findsOneWidget);
    });

    testWidgets('4: Fallback automático inicial para Álbuns quando Notas = 0 e Álbuns > 0', (tester) async {
      final mockTecnico = MockNotaHistoricoTecnicoService(
        onCarregarUtil: (n) async => NotaHistoricoTecnicoResultado(
          notaReferencia: n,
          todosItensDeduplicados: const [],
          calculadoEm: DateTime.now(),
        ),
      );

      final mockVisual = MockNotaHistoricoVisualService(
        onBuscar: (n) async => const HistoricoVisualResultado(
          itens: [],
          totalEquipamento: 3,
          totalSala: 2,
          totalLocal: 1,
        ),
      );

      await tester.pumpWidget(
        _wrapComTema(
          NotaWorkspaceHistoricoAnexosSection(
            nota: notaAtual,
            historicoTecnicoService: mockTecnico,
            historicoVisualService: mockVisual,
            analiseService: MockNotaSapAnaliseService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Como notas com anexos é 0 e álbuns tem 6 fotos, default vira Álbuns de Campo automaticamente
      expect(find.text('6 fotografias registradas nos álbuns'), findsOneWidget);
    });

    testWidgets('5: Seleção manual não é alterada automaticamente por término de carregamento', (tester) async {
      final mockTecnico = MockNotaHistoricoTecnicoService(
        onCarregarUtil: (n) async => NotaHistoricoTecnicoResultado(
          notaReferencia: n,
          todosItensDeduplicados: [itemA],
          calculadoEm: DateTime.now(),
        ),
      );

      final mockVisual = MockNotaHistoricoVisualService(
        onBuscar: (n) async => const HistoricoVisualResultado(
          itens: [],
          totalEquipamento: 2,
          totalSala: 0,
          totalLocal: 0,
        ),
      );

      await tester.pumpWidget(
        _wrapComTema(
          NotaWorkspaceHistoricoAnexosSection(
            nota: notaAtual,
            historicoTecnicoService: mockTecnico,
            historicoVisualService: mockVisual,
            analiseService: MockNotaSapAnaliseService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Usuário clica manualmente em Álbuns de Campo
      await tester.tap(find.text('Álbuns de Campo'));
      await tester.pumpAndSettle();

      // Recarrega os dados simulando término de requisição assíncrona
      final refreshBtn = find.byTooltip('Recarregar histórico de anexos');
      expect(refreshBtn, findsOneWidget);
      await tester.tap(refreshBtn);
      await tester.pumpAndSettle();

      // Preserva a seleção manual do usuário (Álbuns de Campo)
      expect(find.text('2 fotografias registradas nos álbuns'), findsOneWidget);
    });

    testWidgets('6, 7, 8: Critérios A e B com anexos aparecem, e nota sem anexo NÃO aparece', (tester) async {
      final mockTecnico = MockNotaHistoricoTecnicoService(
        onCarregarUtil: (n) async => NotaHistoricoTecnicoResultado(
          notaReferencia: n,
          itensEquipamento: [itemA],
          itensEstrutura: [itemB],
          todosItensDeduplicados: [itemA, itemB, itemSemAnexo],
          calculadoEm: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        _wrapComTema(
          NotaWorkspaceHistoricoAnexosSection(
            nota: notaAtual,
            historicoTecnicoService: mockTecnico,
            analiseService: MockNotaSapAnaliseService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Nota A (11585837) aparece
      expect(find.text('Nota SAP 11585837'), findsOneWidget);
      expect(find.text('Mesmo Equipamento'), findsOneWidget);

      // Nota B (11565366) aparece
      expect(find.text('Nota SAP 11565366'), findsOneWidget);
      expect(find.text('Mesma Estrutura'), findsOneWidget);

      // Nota sem anexo (11400000) NÃO deve aparecer no painel de anexos
      expect(find.text('Nota SAP 11400000'), findsNothing);
    });

    testWidgets('11: Estado vazio integrado quando ambos estiverem vazios', (tester) async {
      final mockTecnico = MockNotaHistoricoTecnicoService(
        onCarregarUtil: (n) async => NotaHistoricoTecnicoResultado(
          notaReferencia: n,
          todosItensDeduplicados: const [],
          calculadoEm: DateTime.now(),
        ),
      );

      final mockVisual = MockNotaHistoricoVisualService(
        onBuscar: (n) async => const HistoricoVisualResultado(
          itens: [],
          totalEquipamento: 0,
          totalSala: 0,
          totalLocal: 0,
        ),
      );

      await tester.pumpWidget(
        _wrapComTema(
          NotaWorkspaceHistoricoAnexosSection(
            nota: notaAtual,
            historicoTecnicoService: mockTecnico,
            historicoVisualService: mockVisual,
            analiseService: MockNotaSapAnaliseService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Nenhum anexo histórico encontrado para o local "STSASPRI" e sala "003/2".'),
        findsOneWidget,
      );
    });

    testWidgets('12, 13, 14: Agrupamento por Nota, origem visível e PDF histórico', (tester) async {
      final mockTecnico = MockNotaHistoricoTecnicoService(
        onCarregarUtil: (n) async => NotaHistoricoTecnicoResultado(
          notaReferencia: n,
          todosItensDeduplicados: [itemA],
          calculadoEm: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        _wrapComTema(
          NotaWorkspaceHistoricoAnexosSection(
            nota: notaAtual,
            historicoTecnicoService: mockTecnico,
            analiseService: MockNotaSapAnaliseService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Agrupamento: cabeçalho da nota
      expect(find.text('Nota SAP 11585837'), findsOneWidget);
      expect(find.text('07/08/2026'), findsOneWidget); // Data absoluta
      expect(find.text('PD-SOB FASE LE MV ARVORES'), findsOneWidget); // Descrição
      expect(find.text('2 anexos'), findsOneWidget);

      // Miniaturas de Foto e PDF
      expect(find.text('Foto Arvores.jpg'), findsOneWidget);
      expect(find.text('Laudo Pericial.pdf'), findsOneWidget);
      expect(find.text('PDF'), findsOneWidget);
    });

    testWidgets('15: Abertura do Viewer histórico em modo Read-Only', (tester) async {
      final mockTecnico = MockNotaHistoricoTecnicoService(
        onCarregarUtil: (n) async => NotaHistoricoTecnicoResultado(
          notaReferencia: n,
          todosItensDeduplicados: [itemA],
          calculadoEm: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        _wrapComTema(
          NotaWorkspaceHistoricoAnexosSection(
            nota: notaAtual,
            historicoTecnicoService: mockTecnico,
            analiseService: MockNotaSapAnaliseService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Clica na miniatura da foto
      final miniaturaFoto = find.text('Foto Arvores.jpg');
      expect(miniaturaFoto, findsOneWidget);
      await tester.tap(miniaturaFoto);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Deve abrir o NotaAnexoViewerDialog com isHistoricoReadOnly == true
      expect(find.byType(NotaAnexoViewerDialog), findsOneWidget);
      final viewer = tester.widget<NotaAnexoViewerDialog>(find.byType(NotaAnexoViewerDialog));
      expect(viewer.isHistoricoReadOnly, isTrue);
      expect(viewer.notaHistoricaNumero, equals('11585837'));

      // Banner MODO DE CONSULTA
      expect(find.textContaining('MODO DE CONSULTA'), findsOneWidget);
    });

    testWidgets('23: Botão [Ver Nota] dispara o callback onAbrirNotaHistorica', (tester) async {
      NotaSAP? notaClicada;

      final mockTecnico = MockNotaHistoricoTecnicoService(
        onCarregarUtil: (n) async => NotaHistoricoTecnicoResultado(
          notaReferencia: n,
          todosItensDeduplicados: [itemA],
          calculadoEm: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        _wrapComTema(
          NotaWorkspaceHistoricoAnexosSection(
            nota: notaAtual,
            historicoTecnicoService: mockTecnico,
            historicoVisualService: MockNotaHistoricoVisualService(),
            analiseService: MockNotaSapAnaliseService(),
            onAbrirNotaHistorica: (n) => notaClicada = n,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final btnVerNota = find.text('Ver Nota');
      expect(btnVerNota, findsOneWidget);
      await tester.tap(btnVerNota);
      await tester.pumpAndSettle();

      expect(notaClicada, isNotNull);
      expect(notaClicada?.nota, equals('11585837'));
    });

    testWidgets('16: Álbuns de Campo continuam funcionando perfeitamente via delegação', (tester) async {
      final mockTecnico = MockNotaHistoricoTecnicoService(
        onCarregarUtil: (n) async => NotaHistoricoTecnicoResultado(
          notaReferencia: n,
          todosItensDeduplicados: [itemA],
          calculadoEm: DateTime.now(),
        ),
      );

      final mockVisual = MockNotaHistoricoVisualService(
        onBuscar: (n) async => const HistoricoVisualResultado(
          itens: [],
          totalEquipamento: 4,
          totalSala: 1,
          totalLocal: 2,
        ),
      );

      await tester.pumpWidget(
        _wrapComTema(
          NotaWorkspaceHistoricoAnexosSection(
            nota: notaAtual,
            historicoTecnicoService: mockTecnico,
            historicoVisualService: mockVisual,
            analiseService: MockNotaSapAnaliseService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Clica na aba Álbuns de Campo
      final abaAlbuns = find.text('Álbuns de Campo');
      expect(abaAlbuns, findsOneWidget);
      await tester.tap(abaAlbuns);
      await tester.pumpAndSettle();

      // Confirma que delegou para NotaWorkspaceHistoricoVisualSection
      expect(find.byType(NotaWorkspaceHistoricoVisualSection), findsOneWidget);
    });

    testWidgets('19, 20, 21, 22: Nota atual renderiza independentemente e suporte Desktop Split e Mobile', (tester) async {
      // Teste no NotaWorkspaceAttachmentsTab
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockAnaliseTab = MockNotaSapAnaliseService();

      await tester.pumpWidget(
        _wrapComTema(
          NotaWorkspaceAttachmentsTab(
            notaSapId: notaAtual.id,
            nota: notaAtual,
            service: mockAnaliseTab,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Aba renderiza workspace de evidências
      expect(find.text('Workspace de Evidências Técnicas'), findsOneWidget);
      // No desktop split (1280px), o painel histórico direito está presente
      expect(find.byType(NotaWorkspaceHistoricoAnexosSection), findsOneWidget);

      // Agora testa tela menor (Mobile / Narrow tablet < 900px)
      tester.view.physicalSize = const Size(700, 900);
      await tester.pumpWidget(
        _wrapComTema(
          NotaWorkspaceAttachmentsTab(
            notaSapId: notaAtual.id,
            nota: notaAtual,
            service: mockAnaliseTab,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Na tela mobile, exibe o botão/card de acesso ao histórico
      expect(find.text('Histórico de Anexos'), findsWidgets);
      expect(find.text('Consultar notas anteriores e álbuns de campo'), findsOneWidget);
    });
  });
}

