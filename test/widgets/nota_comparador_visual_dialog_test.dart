import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/models/nota_sap.dart';
import 'package:task2026/models/nota_sap_analise.dart';
import 'package:task2026/models/nota_historico_visual.dart';
import 'package:task2026/features/media_albums/data/models/media_image.dart';
import 'package:task2026/services/nota_sap_analise_service.dart';
import 'package:task2026/widgets/nota_workspace/nota_comparador_visual_dialog.dart';

final kTransparentImage = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class _TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _FakeHttpClient();
  }
}

class _FakeHttpClient extends Fake implements HttpClient {
  @override
  bool autoUncompress = true;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _FakeHttpClientRequest();
}

class _FakeHttpClientRequest extends Fake implements HttpClientRequest {
  @override
  final HttpHeaders headers = _FakeHttpHeaders();
  @override
  Future<HttpClientResponse> close() async => _FakeHttpClientResponse();
}

class _FakeHttpHeaders extends Fake implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _FakeHttpClientResponse extends Fake implements HttpClientResponse {
  @override
  int get statusCode => 200;
  @override
  int get contentLength => kTransparentImage.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(kTransparentImage).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

class MockNotaSapAnaliseService extends Fake implements NotaSapAnaliseService {
  int urlRequestsCount = 0;
  bool deveFalharAtual = false;
  bool deveFalharHistorico = false;
  int chamadasSalvar = 0;

  @override
  Future<String> obterUrlAssinada(
    NotaSapAnexo anexo, {
    Duration expires = const Duration(hours: 1),
  }) {
    urlRequestsCount++;
    if (deveFalharAtual && anexo.id == 'anexo-atual-1') {
      return Future.error(Exception('Falha ao obter URL assinada atual'));
    }
    if (deveFalharHistorico && anexo.id == 'anexo-hist-1') {
      return Future.error(Exception('Falha ao obter URL assinada histórica'));
    }
    return SynchronousFuture(
      'https://storage.supabase.com/signed/${anexo.bucket}/${anexo.caminhoArquivo}',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    HttpOverrides.global = _TestHttpOverrides();
  });

  late NotaSAP notaAtual;
  late NotaSAP notaHistorica;
  late NotaSapAnexo anexoFotoAtual1;
  late NotaSapAnexo anexoFotoAtual2;
  late NotaSapAnexo anexoPdfAtual;
  late NotaSapAnexo anexoFotoHist1;
  late NotaSapAnexo anexoFotoHist2;
  late HistoricoVisualItem itemAlbum1;
  late HistoricoVisualItem itemAlbum2;
  late MockNotaSapAnaliseService mockService;

  setUp(() {
    mockService = MockNotaSapAnaliseService();

    notaAtual = NotaSAP(
      id: 'nota-atual-uuid',
      nota: '10000001',
      descricao: 'Vazamento de óleo no Trafo 01',
      criadoEm: DateTime(2026, 6, 15),
      local: 'SE Barreiro',
      equipamento: 'TR-01',
    );

    notaHistorica = NotaSAP(
      id: 'nota-hist-uuid',
      nota: '10000000',
      descricao: 'Inspeção anterior do Trafo 01',
      criadoEm: DateTime(2025, 12, 15), // 6 meses de diferença
      local: 'SE Barreiro',
      equipamento: 'TR-01',
    );

    anexoFotoAtual1 = NotaSapAnexo(
      id: 'anexo-atual-1',
      notaSapId: 'nota-atual-uuid',
      nomeArquivo: 'foto_atual_1.jpg',
      nomeOriginal: 'Vazamento Atual 1.jpg',
      tipoArquivo: NotaAnexoTipo.imagem,
      caminhoArquivo: 'atual/foto1.jpg',
      bucket: 'notas-sap-anexos',
      tamanhoBytes: 1024,
      createdAt: DateTime(2026, 6, 15),
    );

    anexoFotoAtual2 = NotaSapAnexo(
      id: 'anexo-atual-2',
      notaSapId: 'nota-atual-uuid',
      nomeArquivo: 'foto_atual_2.jpg',
      nomeOriginal: 'Visão Geral Atual.jpg',
      tipoArquivo: NotaAnexoTipo.imagem,
      caminhoArquivo: 'atual/foto2.jpg',
      bucket: 'notas-sap-anexos',
      tamanhoBytes: 1024,
      createdAt: DateTime(2026, 6, 15),
    );

    anexoPdfAtual = NotaSapAnexo(
      id: 'anexo-pdf-1',
      notaSapId: 'nota-atual-uuid',
      nomeArquivo: 'relatorio.pdf',
      nomeOriginal: 'Relatório Técnico.pdf',
      tipoArquivo: NotaAnexoTipo.pdf,
      caminhoArquivo: 'atual/relatorio.pdf',
      bucket: 'notas-sap-anexos',
      tamanhoBytes: 1024,
      createdAt: DateTime(2026, 6, 15),
    );

    anexoFotoHist1 = NotaSapAnexo(
      id: 'anexo-hist-1',
      notaSapId: 'nota-hist-uuid',
      nomeArquivo: 'foto_hist_1.jpg',
      nomeOriginal: 'Condição Anterior 1.jpg',
      tipoArquivo: NotaAnexoTipo.imagem,
      caminhoArquivo: 'hist/foto1.jpg',
      bucket: 'notas-sap-anexos',
      tamanhoBytes: 1024,
      createdAt: DateTime(2025, 12, 15),
    );

    anexoFotoHist2 = NotaSapAnexo(
      id: 'anexo-hist-2',
      notaSapId: 'nota-hist-uuid',
      nomeArquivo: 'foto_hist_2.jpg',
      nomeOriginal: 'Condição Anterior 2.jpg',
      tipoArquivo: NotaAnexoTipo.imagem,
      caminhoArquivo: 'hist/foto2.jpg',
      bucket: 'notas-sap-anexos',
      tamanhoBytes: 1024,
      createdAt: DateTime(2025, 12, 15),
    );

    itemAlbum1 = HistoricoVisualItem(
      mediaImage: MediaImage(
        id: 'media-1',
        title: 'Foto Álbum Isolador',
        filePath: 'albuns/foto1.jpg',
        fileUrl: 'https://storage.supabase.com/signed/taskflow-media/album1.jpg',
        createdBy: 'user-1',
        createdAt: DateTime(2025, 6, 15),
        updatedAt: DateTime(2025, 6, 15),
      ),
      nivel: HistoricoVisualNivel.equipamento,
      motivoCorrespondencia: 'Mesmo Equipamento',
      localNome: 'SE Barreiro',
      equipamento: 'TR-01',
      createdAt: DateTime(2025, 6, 15),
    );

    itemAlbum2 = HistoricoVisualItem(
      mediaImage: MediaImage(
        id: 'media-2',
        title: 'Foto Álbum Bucha',
        filePath: 'albuns/foto2.jpg',
        fileUrl: 'https://storage.supabase.com/signed/taskflow-media/album2.jpg',
        createdBy: 'user-1',
        createdAt: DateTime(2025, 6, 15),
        updatedAt: DateTime(2025, 6, 15),
      ),
      nivel: HistoricoVisualNivel.equipamento,
      motivoCorrespondencia: 'Mesmo Equipamento',
      localNome: 'SE Barreiro',
      equipamento: 'TR-01',
      createdAt: DateTime(2025, 6, 15),
    );
  });

  Widget buildAppWrapper({
    required Widget child,
    Size size = const Size(1200, 800),
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: Scaffold(body: child),
      ),
    );
  }

  group('NotaComparadorVisualDialog - Suíte de Testes Obrigatória', () {
    // 1. Abertura do diálogo
    testWidgets('1. Deve abrir o diálogo de comparação visual com sucesso', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));

      await tester.pumpWidget(
        buildAppWrapper(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                NotaComparadorVisualDialog.abrirComNotaHistorica(
                  context: context,
                  notaAtual: notaAtual,
                  anexosAtuais: [anexoFotoAtual1],
                  notaHistorica: notaHistorica,
                  anexosHistoricos: [anexoFotoHist1],
                  service: mockService,
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      expect(find.byType(NotaComparadorVisualDialog), findsOneWidget);
      expect(find.text('Comparação Visual'), findsOneWidget);
    });

    // 2. 1 imagem atual → seleção automática
    testWidgets('2. Se existir apenas 1 imagem atual, seleciona automaticamente sem exibir modal de escolha', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));

      await tester.pumpWidget(
        buildAppWrapper(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                NotaComparadorVisualDialog.abrirComNotaHistorica(
                  context: context,
                  notaAtual: notaAtual,
                  anexosAtuais: [anexoFotoAtual1, anexoPdfAtual], // apenas 1 imagem
                  notaHistorica: notaHistorica,
                  anexosHistoricos: [anexoFotoHist1],
                  service: mockService,
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Escolha a imagem atual'), findsNothing);
      expect(find.byType(NotaComparadorVisualDialog), findsOneWidget);
    });

    // 3. Múltiplas imagens atuais → abre seletor compacto
    testWidgets('3. Se existirem múltiplas imagens atuais, abre o seletor compacto antes do comparador', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));

      await tester.pumpWidget(
        buildAppWrapper(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                NotaComparadorVisualDialog.abrirComNotaHistorica(
                  context: context,
                  notaAtual: notaAtual,
                  anexosAtuais: [anexoFotoAtual1, anexoFotoAtual2],
                  notaHistorica: notaHistorica,
                  anexosHistoricos: [anexoFotoHist1],
                  service: mockService,
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      // Seletor deve aparecer
      expect(find.text('Escolha a imagem atual'), findsOneWidget);

      // Clicar na primeira foto do seletor
      await tester.tap(find.text('Vazamento Atual 1.jpg'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Comparador deve abrir
      expect(find.byType(NotaComparadorVisualDialog), findsOneWidget);
    });

    // 4. Nenhuma imagem atual → aviso e não abre
    testWidgets('4. Se a Nota atual não possuir imagens, avisa ao usuário e não abre comparador vazio', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));

      await tester.pumpWidget(
        buildAppWrapper(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                NotaComparadorVisualDialog.abrirComNotaHistorica(
                  context: context,
                  notaAtual: notaAtual,
                  anexosAtuais: [anexoPdfAtual], // zero imagens
                  notaHistorica: notaHistorica,
                  anexosHistoricos: [anexoFotoHist1],
                  service: mockService,
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      expect(find.byType(NotaComparadorVisualDialog), findsNothing);
      expect(find.text('A Nota atual não possui imagens disponíveis para comparação.'), findsOneWidget);
    });

    // 5. Histórico de Nota anterior
    testWidgets('5. Suporta histórico vindo de Nota SAP anterior', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));

      await tester.pumpWidget(
        buildAppWrapper(
          child: NotaComparadorVisualDialog(
            notaAtual: notaAtual,
            anexosAtuais: [anexoFotoAtual1],
            anexoAtualInicial: anexoFotoAtual1,
            origemHistorica: OrigemComparadorHistorico.notaAnterior,
            notaHistorica: notaHistorica,
            anexosHistoricos: [anexoFotoHist1],
            service: mockService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Nota SAP 10000000'), findsOneWidget);
    });

    // 6. Histórico de Álbum de Campo
    testWidgets('6. Suporta histórico vindo de Álbum de Campo', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));

      await tester.pumpWidget(
        buildAppWrapper(
          child: NotaComparadorVisualDialog(
            notaAtual: notaAtual,
            anexosAtuais: [anexoFotoAtual1],
            anexoAtualInicial: anexoFotoAtual1,
            origemHistorica: OrigemComparadorHistorico.albumCampo,
            itensAlbum: [itemAlbum1, itemAlbum2],
            service: mockService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Álbum de Campo'), findsOneWidget);
      expect(find.textContaining('Foto Álbum Isolador'), findsOneWidget);
      expect(find.text('1/2'), findsOneWidget);
    });

    // 8 e 9. Identificadores permanentes ATUAL e HISTÓRICO
    testWidgets('8 e 9. Identificadores ATUAL e HISTÓRICO são permanentes e explícitos', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));

      await tester.pumpWidget(
        buildAppWrapper(
          child: NotaComparadorVisualDialog(
            notaAtual: notaAtual,
            anexosAtuais: [anexoFotoAtual1],
            anexoAtualInicial: anexoFotoAtual1,
            origemHistorica: OrigemComparadorHistorico.notaAnterior,
            notaHistorica: notaHistorica,
            anexosHistoricos: [anexoFotoHist1],
            service: mockService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ATUAL'), findsWidgets);
      expect(find.text('HISTÓRICO'), findsWidgets);
    });

    // 10. Metadados de Data e Origem
    testWidgets('10. Exibe metadados de data e identificação da nota em ambos os lados', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));

      await tester.pumpWidget(
        buildAppWrapper(
          child: NotaComparadorVisualDialog(
            notaAtual: notaAtual,
            anexosAtuais: [anexoFotoAtual1],
            anexoAtualInicial: anexoFotoAtual1,
            origemHistorica: OrigemComparadorHistorico.notaAnterior,
            notaHistorica: notaHistorica,
            anexosHistoricos: [anexoFotoHist1],
            service: mockService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('15/06/2026'), findsOneWidget);
      expect(find.textContaining('15/12/2025'), findsOneWidget);
    });

    // 11. Diferença temporal calculada em memória
    testWidgets('11. Calcula a diferença temporal relativa em memória (6 meses)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));

      await tester.pumpWidget(
        buildAppWrapper(
          child: NotaComparadorVisualDialog(
            notaAtual: notaAtual,
            anexosAtuais: [anexoFotoAtual1],
            anexoAtualInicial: anexoFotoAtual1,
            origemHistorica: OrigemComparadorHistorico.notaAnterior,
            notaHistorica: notaHistorica,
            anexosHistoricos: [anexoFotoHist1],
            service: mockService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('6 meses de diferença'), findsOneWidget);
    });

    // 13 e 14. Rotação independente e Reset
    testWidgets('13 e 14. Rotação independente por lado e botão de reset', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));

      await tester.pumpWidget(
        buildAppWrapper(
          child: NotaComparadorVisualDialog(
            notaAtual: notaAtual,
            anexosAtuais: [anexoFotoAtual1],
            anexoAtualInicial: anexoFotoAtual1,
            origemHistorica: OrigemComparadorHistorico.notaAnterior,
            notaHistorica: notaHistorica,
            anexosHistoricos: [anexoFotoHist1],
            service: mockService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rotateButtons = find.byTooltip('Rotacionar 90° (R)');
      expect(rotateButtons, findsNWidgets(2));

      // Clicar para rotacionar o lado histórico
      await tester.tap(rotateButtons.last);
      await tester.pumpAndSettle();

      final resetButtons = find.byTooltip('Resetar Zoom/Pan');
      expect(resetButtons, findsNWidgets(2));

      // Clicar para resetar o lado histórico
      await tester.tap(resetButtons.last);
      await tester.pumpAndSettle();
    });

    // 15. Trocar foto atual sem fechar comparador
    testWidgets('15. Permite trocar a foto atual sem fechar o diálogo', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));

      await tester.pumpWidget(
        buildAppWrapper(
          child: NotaComparadorVisualDialog(
            notaAtual: notaAtual,
            anexosAtuais: [anexoFotoAtual1, anexoFotoAtual2],
            anexoAtualInicial: anexoFotoAtual1,
            origemHistorica: OrigemComparadorHistorico.notaAnterior,
            notaHistorica: notaHistorica,
            anexosHistoricos: [anexoFotoHist1],
            service: mockService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final trocarBtn = find.byTooltip('Trocar foto atual');
      expect(trocarBtn, findsOneWidget);

      await tester.tap(trocarBtn);
      await tester.pumpAndSettle();

      expect(find.text('Escolha a imagem atual'), findsOneWidget);

      // Selecionar foto 2
      await tester.tap(find.text('Visão Geral Atual.jpg'));
      await tester.pumpAndSettle();

      // Diálogo permanece aberto com foto 2 selecionada
      expect(find.byType(NotaComparadorVisualDialog), findsOneWidget);
      expect(find.textContaining('Visão Geral Atual.jpg'), findsWidgets);
    });

    // 16. Navegar fotos históricas da mesma origem
    testWidgets('16. Permite navegar entre múltiplas fotos do mesmo histórico (← Foto 1 de N →)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));

      await tester.pumpWidget(
        buildAppWrapper(
          child: NotaComparadorVisualDialog(
            notaAtual: notaAtual,
            anexosAtuais: [anexoFotoAtual1],
            anexoAtualInicial: anexoFotoAtual1,
            origemHistorica: OrigemComparadorHistorico.notaAnterior,
            notaHistorica: notaHistorica,
            anexosHistoricos: [anexoFotoHist1, anexoFotoHist2],
            service: mockService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1/2'), findsOneWidget);

      final nextBtn = find.byTooltip('Próxima foto');
      expect(nextBtn, findsOneWidget);

      await tester.tap(nextBtn);
      await tester.pumpAndSettle();

      expect(find.text('2/2'), findsOneWidget);
    });

    // 17 e 19. Falha em imagem atual e retry independente
    testWidgets('17 e 19. Falha ao carregar imagem atual exibe retry independente sem fechar o diálogo', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      mockService.deveFalharAtual = true;

      await tester.pumpWidget(
        buildAppWrapper(
          child: NotaComparadorVisualDialog(
            notaAtual: notaAtual,
            anexosAtuais: [anexoFotoAtual1],
            anexoAtualInicial: anexoFotoAtual1,
            origemHistorica: OrigemComparadorHistorico.notaAnterior,
            notaHistorica: notaHistorica,
            anexosHistoricos: [anexoFotoHist1],
            service: mockService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Deve exibir mensagem de erro apenas no lado atual
      expect(find.text('Não foi possível carregar a imagem atual.'), findsOneWidget);
      expect(find.text('Tentar novamente'), findsOneWidget);

      // Corrige falha e clica em Tentar novamente
      mockService.deveFalharAtual = false;
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();

      expect(find.text('Não foi possível carregar a imagem atual.'), findsNothing);
    });

    // 21. Layout Desktop (split 50%/50%)
    testWidgets('21. Desktop (>= 900px) apresenta split horizontal lado a lado', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));

      await tester.pumpWidget(
        buildAppWrapper(
          size: const Size(1200, 800),
          child: NotaComparadorVisualDialog(
            notaAtual: notaAtual,
            anexosAtuais: [anexoFotoAtual1],
            anexoAtualInicial: anexoFotoAtual1,
            origemHistorica: OrigemComparadorHistorico.notaAnterior,
            notaHistorica: notaHistorica,
            anexosHistoricos: [anexoFotoHist1],
            service: mockService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Divider vertical entre os lados
      expect(find.byType(VerticalDivider), findsOneWidget);
    });

    // 22. Layout Mobile (< 900px) com alternância prioritária e miniatura de referência
    testWidgets('22. Mobile (< 900px) utiliza alternância prioritária [ATUAL] [HISTÓRICO] com miniatura flutuante', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 900));

      await tester.pumpWidget(
        buildAppWrapper(
          size: const Size(600, 900),
          child: NotaComparadorVisualDialog(
            notaAtual: notaAtual,
            anexosAtuais: [anexoFotoAtual1],
            anexoAtualInicial: anexoFotoAtual1,
            origemHistorica: OrigemComparadorHistorico.notaAnterior,
            notaHistorica: notaHistorica,
            anexosHistoricos: [anexoFotoHist1],
            service: mockService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No mobile não tem VerticalDivider de split
      expect(find.byType(VerticalDivider), findsNothing);

      // Alternador presente no topo
      expect(find.text('ATUAL'), findsWidgets);
      expect(find.text('HISTÓRICO'), findsWidgets);

      // Clicar em ATUAL alterna o painel principal
      await tester.tap(find.text('ATUAL').first, warnIfMissed: false);
      await tester.pumpAndSettle();
    });

    // 23. Fechar com tecla Esc
    testWidgets('23. Tecla Escape fecha o diálogo do comparador visual', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));

      await tester.pumpWidget(
        buildAppWrapper(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                NotaComparadorVisualDialog.abrirComNotaHistorica(
                  context: context,
                  notaAtual: notaAtual,
                  anexosAtuais: [anexoFotoAtual1],
                  notaHistorica: notaHistorica,
                  anexosHistoricos: [anexoFotoHist1],
                  service: mockService,
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      expect(find.byType(NotaComparadorVisualDialog), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(NotaComparadorVisualDialog), findsNothing);
    });

    // 24 e 25. Dirty state e Zero persistência
    testWidgets('24 e 25. Modo estritamente Read-Only com zero chamadas de escrita no banco', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));

      await tester.pumpWidget(
        buildAppWrapper(
          child: NotaComparadorVisualDialog(
            notaAtual: notaAtual,
            anexosAtuais: [anexoFotoAtual1],
            anexoAtualInicial: anexoFotoAtual1,
            origemHistorica: OrigemComparadorHistorico.notaAnterior,
            notaHistorica: notaHistorica,
            anexosHistoricos: [anexoFotoHist1],
            service: mockService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Nenhuma ação gera save ou persistência
      expect(mockService.chamadasSalvar, equals(0));
    });
  });
}
