import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/design_system/theme/taskflow_theme_extension.dart';
import 'package:task2026/models/nota_sap_analise.dart';
import 'package:task2026/models/nota_sap_analise_evidencia.dart';
import 'package:task2026/services/nota_sap_analise_service.dart';
import 'package:task2026/widgets/nota_workspace/nota_anexo_viewer_dialog.dart';
import 'package:task2026/widgets/nota_workspace/nota_workspace_attachments_tab.dart';

class MockNotaSapAnaliseServiceForTab extends Fake
    implements NotaSapAnaliseService {
  final List<NotaSapAnexo> anexosDb = [];
  int alternarRelevanteChamadas = 0;
  String? ultimoAnexoIdRelevante;
  bool? ultimoStatusRelevante;

  @override
  Future<List<NotaSapAnexo>> listarAnexos(String notaSapId) async {
    return List.from(anexosDb);
  }

  @override
  Future<String> obterUrlAssinada(
    NotaSapAnexo anexo, {
    Duration expires = const Duration(hours: 1),
  }) async {
    return 'https://storage.local/test/${anexo.caminhoArquivo}';
  }

  @override
  Future<void> alternarRelevanteParaAnalise({
    required String anexoId,
    required String notaSapId,
    required bool relevante,
  }) async {
    alternarRelevanteChamadas++;
    ultimoAnexoIdRelevante = anexoId;
    ultimoStatusRelevante = relevante;
    final idx = anexosDb.indexWhere((a) => a.id == anexoId);
    if (idx != -1) {
      anexosDb[idx] = anexosDb[idx].copyWith(relevanteAnalise: relevante);
    }
  }

  @override
  Future<Map<String, List<NotaTipoVinculoEvidencia>>> buscarUsoDosAnexos(
      String notaSapId) async {
    return {};
  }
}

Widget _wrapWithTheme(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      extensions: [TaskFlowThemeExtension.light()],
    ),
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockNotaSapAnaliseServiceForTab mockService;

  setUp(() {
    mockService = MockNotaSapAnaliseServiceForTab();
    mockService.anexosDb.addAll([
      NotaSapAnexo(
        id: 'anexo-1',
        notaSapId: 'nota-123',
        nomeArquivo: 'sap_isolador.jpg',
        nomeOriginal: 'Foto Isolador Quebrado.jpg',
        tipoArquivo: NotaAnexoTipo.imagem,
        caminhoArquivo: 'nota-123/sap_isolador.jpg',
        tamanhoBytes: 1024 * 50,
        origem: 'SAP',
        relevanteAnalise: true,
        legenda: 'Fissura na cadeia 2',
        createdAt: DateTime(2026, 10, 29, 10, 0),
      ),
      NotaSapAnexo(
        id: 'anexo-2',
        notaSapId: 'nota-123',
        nomeArquivo: 'sap_laudo.pdf',
        nomeOriginal: 'Laudo Pericial Estrutura.pdf',
        tipoArquivo: NotaAnexoTipo.pdf,
        caminhoArquivo: 'nota-123/sap_laudo.pdf',
        tamanhoBytes: 1024 * 200,
        origem: 'SAP',
        relevanteAnalise: false,
        legenda: 'Laudo do engenheiro',
        createdAt: DateTime(2026, 10, 29, 11, 0),
      ),
      NotaSapAnexo(
        id: 'anexo-3',
        notaSapId: 'nota-123',
        nomeArquivo: 'manual_campo.png',
        nomeOriginal: 'Foto Campo Torre.png',
        tipoArquivo: NotaAnexoTipo.imagem,
        caminhoArquivo: 'nota-123/manual_campo.png',
        tamanhoBytes: 1024 * 80,
        origem: 'TASKFLOW',
        relevanteAnalise: false,
        createdAt: DateTime(2026, 10, 29, 12, 0),
      ),
    ]);
  });

  testWidgets(
      'Fase 1: Renderiza cabeçalho-resumo técnico com contadores corretos',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      _wrapWithTheme(
        NotaWorkspaceAttachmentsTab(
          notaSapId: 'nota-123',
          service: mockService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Título do workspace
    expect(find.text('Workspace de Evidências Técnicas'), findsOneWidget);
    expect(find.text('1 evidência(s) crítica(s)'), findsOneWidget);

    // Cards métricos
    expect(find.text('Total Geral'), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // total
    expect(find.text('★ Relevantes'), findsWidgets);
    expect(find.text('Imagens / Fotos'), findsOneWidget);
  });

  testWidgets('Fase 1: Alterna entre Modo Cards e Modo Lista', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      _wrapWithTheme(
        NotaWorkspaceAttachmentsTab(
          notaSapId: 'nota-123',
          service: mockService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Começa em Modo Cards (GridView presente)
    expect(find.byType(GridView), findsWidgets);

    // Clica no botão Modo Lista
    final btnModoLista = find.byTooltip('Modo Lista Detalhada');
    expect(btnModoLista, findsOneWidget);
    await tester.tap(btnModoLista);
    await tester.pumpAndSettle();

    // Modo Lista renderiza itens com ListView
    expect(find.byType(ListView), findsWidgets);
  });

  testWidgets('Fase 1: Busca filtra anexos por nome e legenda em tempo real',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      _wrapWithTheme(
        NotaWorkspaceAttachmentsTab(
          notaSapId: 'nota-123',
          service: mockService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Foto Isolador Quebrado.jpg'), findsWidgets);
    expect(find.text('Laudo Pericial Estrutura.pdf'), findsWidgets);
    expect(find.text('Foto Campo Torre.png'), findsWidgets);

    // Digita "laudo" na busca
    final campoBusca = find.byType(TextField);
    await tester.enterText(campoBusca, 'laudo');
    await tester.pumpAndSettle();

    expect(find.text('Laudo Pericial Estrutura.pdf'), findsWidgets);
    expect(find.text('Foto Isolador Quebrado.jpg'), findsNothing);
    expect(find.text('Foto Campo Torre.png'), findsNothing);
  });

  testWidgets(
      'Fase 1: Alternar botão de estrela de evidência relevante aciona o service',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      _wrapWithTheme(
        NotaWorkspaceAttachmentsTab(
          notaSapId: 'nota-123',
          service: mockService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // No anexo 2 (laudo.pdf) a estrela está vazia (não relevante)
    final estrelas = find.byIcon(Icons.star_border);
    expect(estrelas, findsWidgets);
    await tester.ensureVisible(estrelas.first);
    await tester.tap(estrelas.first);
    await tester.pumpAndSettle();

    expect(mockService.alternarRelevanteChamadas, equals(1));
    expect(mockService.ultimoStatusRelevante, isTrue);
  });

  testWidgets(
      'Fase 2: Desktop split view exibe painel lateral de inspeção rápida quando largura >= 1100',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      _wrapWithTheme(
        NotaWorkspaceAttachmentsTab(
          notaSapId: 'nota-123',
          service: mockService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Deve exibir o painel lateral no desktop
    expect(find.text('Inspeção Técnica Rápida'), findsOneWidget);
    expect(find.text('Galeria'), findsOneWidget);
  });

  testWidgets(
      'Fase 2: Mobile / Tablet não exibe painel lateral quando largura < 1100',
      (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      _wrapWithTheme(
        NotaWorkspaceAttachmentsTab(
          notaSapId: 'nota-123',
          service: mockService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Não deve exibir o painel lateral em telas menores
    expect(find.text('Inspeção Técnica Rápida'), findsNothing);
  });

  testWidgets(
      'Fase 2: Botão Galeria no painel desktop abre o viewer em tela cheia',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      _wrapWithTheme(
        NotaWorkspaceAttachmentsTab(
          notaSapId: 'nota-123',
          service: mockService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final btnGaleria = find.text('Galeria');
    expect(btnGaleria, findsOneWidget);
    await tester.ensureVisible(btnGaleria);
    await tester.tap(btnGaleria);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(NotaAnexoViewerDialog), findsOneWidget);
    final viewer = tester.widget<NotaAnexoViewerDialog>(find.byType(NotaAnexoViewerDialog));
    expect(viewer.anexos.length, equals(3));
    expect(viewer.contextoFiltro, equals('Todas as Evidências'));
  });
}
