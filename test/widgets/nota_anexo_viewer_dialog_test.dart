import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/design_system/theme/taskflow_theme_extension.dart';
import 'package:task2026/models/nota_sap_analise.dart';
import 'package:task2026/services/nota_sap_analise_service.dart';
import 'package:task2026/widgets/nota_workspace/nota_anexo_viewer_dialog.dart';

class MockNotaSapAnaliseServiceForViewer extends Fake
    implements NotaSapAnaliseService {
  int alternarRelevanteChamadas = 0;
  String? ultimoAnexoIdRelevante;
  bool? ultimoStatusRelevante;

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

  late MockNotaSapAnaliseServiceForViewer mockService;

  setUp(() {
    mockService = MockNotaSapAnaliseServiceForViewer();
  });

  final anexoFoto1 = NotaSapAnexo(
    id: 'anexo-1',
    notaSapId: 'nota-123',
    nomeArquivo: 'sap_foto1.jpg',
    nomeOriginal: 'Foto Isolador 1.jpg',
    tipoArquivo: NotaAnexoTipo.imagem,
    caminhoArquivo: 'nota-123/sap_foto1.jpg',
    tamanhoBytes: 1024 * 50,
    origem: 'SAP',
    relevanteAnalise: true,
    legenda: 'Fissura no isolador de ancoragem',
    createdAt: DateTime(2026, 10, 29, 10, 0),
  );

  final anexoPdf = NotaSapAnexo(
    id: 'anexo-2',
    notaSapId: 'nota-123',
    nomeArquivo: 'sap_relatorio.pdf',
    nomeOriginal: 'Relatorio Tecnico Manutencao.pdf',
    tipoArquivo: NotaAnexoTipo.pdf,
    caminhoArquivo: 'nota-123/sap_relatorio.pdf',
    tamanhoBytes: 1024 * 500,
    origem: 'SAP',
    relevanteAnalise: false,
    legenda: 'Relatório do engenheiro de campo',
    createdAt: DateTime(2026, 10, 29, 11, 0),
  );

  final anexoVideo = NotaSapAnexo(
    id: 'anexo-3',
    notaSapId: 'nota-123',
    nomeArquivo: 'inspecao_drone.mp4',
    nomeOriginal: 'Voo Inspecao Torre 12.mp4',
    tipoArquivo: NotaAnexoTipo.video,
    caminhoArquivo: 'nota-123/inspecao_drone.mp4',
    tamanhoBytes: 1024 * 1024 * 12,
    origem: 'TASKFLOW',
    relevanteAnalise: false,
    createdAt: DateTime(2026, 10, 29, 12, 0),
  );

  final anexoDoc = NotaSapAnexo(
    id: 'anexo-4',
    notaSapId: 'nota-123',
    nomeArquivo: 'planilha_materiais.xlsx',
    nomeOriginal: 'Lista Materiais SAP.xlsx',
    tipoArquivo: NotaAnexoTipo.planilha,
    caminhoArquivo: 'nota-123/planilha_materiais.xlsx',
    tamanhoBytes: 1024 * 120,
    origem: 'SAP',
    relevanteAnalise: true,
    createdAt: DateTime(2026, 10, 29, 13, 0),
  );

  testWidgets('Fase 2: Viewer abre na imagem indicada e exibe contador N de Total',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      _wrapWithTheme(
        NotaAnexoViewerDialog(
          anexos: [anexoFoto1, anexoPdf, anexoVideo],
          indiceInicial: 0,
          service: mockService,
          contextoFiltro: '★ Relevantes',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Contador e badge do filtro
    expect(find.text('1 de 3'), findsOneWidget);
    expect(find.text('★ Relevantes'), findsOneWidget);

    // Nome e legenda do anexo 1
    expect(find.text('Foto Isolador 1.jpg'), findsWidgets);
    expect(find.text('Fissura no isolador de ancoragem'), findsOneWidget);

    // Controles de rotação e fechamento
    expect(find.byTooltip('Girar anti-horário (-90°)'), findsOneWidget);
    expect(find.byTooltip('Girar 90° horário (Pressione R)'), findsOneWidget);
    expect(find.byTooltip('Fechar (Esc)'), findsOneWidget);
  });

  testWidgets(
      'Fase 2: Navegação Próxima e Anterior altera o anexo e respeita os limites',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      _wrapWithTheme(
        NotaAnexoViewerDialog(
          anexos: [anexoFoto1, anexoPdf],
          indiceInicial: 0,
          service: mockService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 de 2'), findsOneWidget);
    expect(find.text('Foto Isolador 1.jpg'), findsWidgets);

    // Clica no botão próxima evidência
    final btnProxima = find.byTooltip('Próxima (→)');
    expect(btnProxima, findsOneWidget);
    await tester.tap(btnProxima);
    await tester.pumpAndSettle();

    // Agora está no item 2 de 2 (PDF)
    expect(find.text('2 de 2'), findsOneWidget);
    expect(find.text('Relatorio Tecnico Manutencao.pdf'), findsWidgets);

    // Clica no botão anterior
    final btnAnterior = find.byTooltip('Anterior (←)');
    expect(btnAnterior, findsOneWidget);
    await tester.tap(btnAnterior);
    await tester.pumpAndSettle();

    // Volta ao item 1 de 2
    expect(find.text('1 de 2'), findsOneWidget);
    expect(find.text('Foto Isolador 1.jpg'), findsWidgets);
  });

  testWidgets(
      'Fase 2: Alternar estrela de relevante dentro do viewer dispara callback sem fechar',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    String? callbackAnexoId;
    bool? callbackNovoStatus;

    await tester.pumpWidget(
      _wrapWithTheme(
        NotaAnexoViewerDialog(
          anexos: [anexoFoto1],
          indiceInicial: 0,
          service: mockService,
          onRelevanciaAlternada: (anexo, novoStatus) {
            callbackAnexoId = anexo.id;
            callbackNovoStatus = novoStatus;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // anexoFoto1 já é relevante -> botão diz 'Relevante'
    expect(find.text('Relevante'), findsOneWidget);

    // Clica no botão de relevante
    await tester.tap(find.text('Relevante'));
    await tester.pumpAndSettle();

    // Callback e service foram acionados para desmarcar (false)
    expect(callbackAnexoId, equals('anexo-1'));
    expect(callbackNovoStatus, isFalse);
    expect(mockService.alternarRelevanteChamadas, equals(1));
    expect(mockService.ultimoStatusRelevante, isFalse);

    // Diálogo continua aberto!
    expect(find.byType(NotaAnexoViewerDialog), findsOneWidget);
    expect(find.text('Marcar relevante'), findsOneWidget);
  });

  testWidgets(
      'Fase 2: Suporte técnico a PDF exibe metadados e botão de abrir com Signed URL',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      _wrapWithTheme(
        NotaAnexoViewerDialog(
          anexos: [anexoPdf],
          indiceInicial: 0,
          service: mockService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Documento PDF / Laudo Técnico'), findsOneWidget);
    expect(find.text('Relatorio Tecnico Manutencao.pdf'), findsWidgets);
    expect(find.text('Visualizar PDF'), findsOneWidget);
    expect(find.text('Copiar Link'), findsOneWidget);
  });

  testWidgets(
      'Fase 2: Suporte técnico a Vídeo não possui autoplay e oferece botão de visualização',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      _wrapWithTheme(
        NotaAnexoViewerDialog(
          anexos: [anexoVideo],
          indiceInicial: 0,
          service: mockService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Registro em Vídeo de Campo'), findsOneWidget);
    expect(find.text('Voo Inspecao Torre 12.mp4'), findsWidgets);
    expect(find.text('Visualizar Vídeo'), findsOneWidget);
    expect(find.text('Autoplay desativado por política corporativa de dados.'),
        findsOneWidget);
  });

  testWidgets(
      'Fase 2: Suporte técnico a Planilhas/Documentos exibe metadados e botão [Abrir]',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      _wrapWithTheme(
        NotaAnexoViewerDialog(
          anexos: [anexoDoc],
          indiceInicial: 0,
          service: mockService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Planilha de Dados / Medições'), findsOneWidget);
    expect(find.text('Lista Materiais SAP.xlsx'), findsWidgets);
    expect(find.text('Abrir Planilha'), findsOneWidget);
  });

  testWidgets('Fase 2: Atalho de teclado seta direita navega para a próxima evidência',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      _wrapWithTheme(
        NotaAnexoViewerDialog(
          anexos: [anexoFoto1, anexoPdf],
          indiceInicial: 0,
          service: mockService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 de 2'), findsOneWidget);

    // Dispara tecla Seta Direita
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    // Deve avançar para 2 de 2
    expect(find.text('2 de 2'), findsOneWidget);
    expect(find.text('Relatorio Tecnico Manutencao.pdf'), findsWidgets);
  });
}
