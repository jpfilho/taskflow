import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/design_system/theme/taskflow_theme_extension.dart';
import 'package:task2026/models/nota_sap.dart';
import 'package:task2026/models/nota_sap_analise.dart';
import 'package:task2026/models/nota_historico_visual.dart';
import 'package:task2026/features/media_albums/data/models/media_image.dart';
import 'package:task2026/services/nota_sap_analise_service.dart';
import 'package:task2026/widgets/nota_workspace/nota_comparador_visual_dialog.dart';
import 'package:photo_view/photo_view.dart';

final kSolidPixel = Uint8List.fromList([
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
  int get contentLength => kSolidPixel.length;
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
    return Stream<List<int>>.value(kSolidPixel).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

class MockNotaSapAnaliseService extends Fake implements NotaSapAnaliseService {
  bool falharHistorico = false;

  @override
  Future<String> obterUrlAssinada(
    NotaSapAnexo anexo, {
    Duration expires = const Duration(hours: 1),
  }) {
    if (falharHistorico && (anexo.id?.contains('hist') == true)) {
      return Future.error(Exception('Erro de rede ao carregar imagem histórica'));
    }
    return SynchronousFuture(
      'https://storage.supabase.com/signed/${anexo.bucket}/${anexo.caminhoArquivo}',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final outDir = Directory('docs/screenshots_comparador_visual');
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }

  setUpAll(() {
    HttpOverrides.global = _TestHttpOverrides();
  });

  Future<void> capturarScreenshot(WidgetTester tester, GlobalKey key, String filename) async {
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 100));
      final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();
      final file = File('docs/screenshots_comparador_visual/$filename');
      file.writeAsBytesSync(pngBytes);
    });
  }

  Widget wrapWithBoundary({
    required Widget child,
    required GlobalKey key,
    required Size size,
  }) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        extensions: [
          TaskFlowThemeExtension.light(),
        ],
      ),
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: RepaintBoundary(
            key: key,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  // 1. Desktop - Nota × Nota (1400x900)
  testWidgets('01_desktop_nota_vs_nota', (tester) async {
    final key = GlobalKey();
    const size = Size(1400, 900);
    await tester.binding.setSurfaceSize(size);

    final notaAtual = NotaSAP(
      id: 'nota-11598127',
      nota: '11598127',
      descricao: 'Vegetação na faixa de servidão sob condutores',
      criadoEm: DateTime(2026, 8, 25),
      local: 'H-L-STSDSTSA-RB4L03-4LT1',
      equipamento: '11776176',
    );

    final anexoAtual = NotaSapAnexo(
      id: 'anexo-11598127-1',
      notaSapId: 'nota-11598127',
      nomeArquivo: 'sap_1793442313_1_11598127_vegetacao_fase1.jpg',
      nomeOriginal: 'Vegetação_Proximidade_Fase_A.jpg',
      tipoArquivo: NotaAnexoTipo.imagem,
      caminhoArquivo: 'notas/11598127/vegetacao.jpg',
      bucket: 'notas-sap-anexos',
      tamanhoBytes: 1024,
      createdAt: DateTime(2026, 8, 25),
    );

    final notaHist = NotaSAP(
      id: 'nota-11524543',
      nota: '11524543',
      descricao: 'TR- VEGETACAO SOB FASES 1° TER',
      criadoEm: DateTime(2026, 2, 20),
      local: 'H-L-STSDSTSA-RB4L03-4LT1',
      equipamento: '11776176',
    );

    final anexoHist = NotaSapAnexo(
      id: 'anexo-hist-11524543',
      notaSapId: 'nota-11524543',
      nomeArquivo: 'sap_1793442313_2_11524543_vegetacao_antiga.jpg',
      nomeOriginal: 'Condição_Vegetacao_Fev2026.jpg',
      tipoArquivo: NotaAnexoTipo.imagem,
      caminhoArquivo: 'notas/11524543/vegetacao.jpg',
      bucket: 'notas-sap-anexos',
      tamanhoBytes: 1024,
      createdAt: DateTime(2026, 2, 20),
    );

    final widget = NotaComparadorVisualDialog(
      notaAtual: notaAtual,
      anexosAtuais: [anexoAtual],
      anexoAtualInicial: anexoAtual,
      origemHistorica: OrigemComparadorHistorico.notaAnterior,
      notaHistorica: notaHist,
      anexosHistoricos: [anexoHist],
      service: MockNotaSapAnaliseService(),
    );

    await tester.pumpWidget(wrapWithBoundary(child: widget, key: key, size: size));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await capturarScreenshot(tester, key, '01_desktop_nota_vs_nota.png');
  });

  // 2. Desktop - Nota × Álbum de Campo (1400x900)
  testWidgets('02_desktop_nota_vs_album', (tester) async {
    final key = GlobalKey();
    const size = Size(1400, 900);
    await tester.binding.setSurfaceSize(size);

    final notaAtual = NotaSAP(
      id: 'nota-11598030',
      nota: '11598030',
      descricao: 'Inspeção de isoladores e ferragens da torre',
      criadoEm: DateTime(2026, 8, 20),
      local: 'H-L-SIBDSSBD-RB4L01-4LT1',
      equipamento: '11753968',
    );

    final anexoAtual = NotaSapAnexo(
      id: 'anexo-11598030-1',
      notaSapId: 'nota-11598030',
      nomeArquivo: 'sap_1793442313_1_11598030_isolador.jpg',
      nomeOriginal: 'Isolador_Polimerico_Torre_015.jpg',
      tipoArquivo: NotaAnexoTipo.imagem,
      caminhoArquivo: 'notas/11598030/isolador.jpg',
      bucket: 'notas-sap-anexos',
      tamanhoBytes: 1024,
      createdAt: DateTime(2026, 8, 20),
    );

    final albumItem1 = HistoricoVisualItem(
      mediaImage: MediaImage(
        id: 'a4ac00d4-5858-4df7-a17c-41f5e73bba78',
        title: 'Inspeção 2025 IBDSBD - Cadeia de Isoladores',
        filePath: 'albuns/ibdsbd/foto1.jpg',
        fileUrl: 'https://storage.supabase.com/signed/taskflow-media/album1.jpg',
        createdBy: 'equipe-lt',
        createdAt: DateTime(2025, 4, 15),
        updatedAt: DateTime(2025, 4, 15),
      ),
      nivel: HistoricoVisualNivel.local,
      motivoCorrespondencia: 'Mesmo Local de Instalação (LT IBDSBD)',
      localNome: 'LT 230kV Ibirité - São Benedito',
      equipamento: 'Torre 015/1',
      createdAt: DateTime(2025, 4, 15),
    );

    final widget = NotaComparadorVisualDialog(
      notaAtual: notaAtual,
      anexosAtuais: [anexoAtual],
      anexoAtualInicial: anexoAtual,
      origemHistorica: OrigemComparadorHistorico.albumCampo,
      itensAlbum: [albumItem1],
      service: MockNotaSapAnaliseService(),
    );

    await tester.pumpWidget(wrapWithBoundary(child: widget, key: key, size: size));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await capturarScreenshot(tester, key, '02_desktop_nota_vs_album.png');
  });

  // 3. Desktop - Zoom Independente (1400x900)
  testWidgets('03_desktop_zoom_independente', (tester) async {
    final key = GlobalKey();
    const size = Size(1400, 900);
    await tester.binding.setSurfaceSize(size);

    final notaAtual = NotaSAP(
      id: 'nota-11598115',
      nota: '11598115',
      descricao: 'Corrosão severa em pino de isolador de suspensão',
      criadoEm: DateTime(2026, 8, 22),
      local: 'H-L-SBEASTSA-RB4L01-4LT1',
      equipamento: '11739178',
    );

    final anexoAtual = NotaSapAnexo(
      id: 'anexo-11598115-1',
      notaSapId: 'nota-11598115',
      nomeArquivo: 'sap_11598115_corrosao_detalhe.jpg',
      nomeOriginal: 'Macro_Corrosao_Pino_Isolador.jpg',
      tipoArquivo: NotaAnexoTipo.imagem,
      caminhoArquivo: 'notas/11598115/corrosao.jpg',
      bucket: 'notas-sap-anexos',
      tamanhoBytes: 1024,
      createdAt: DateTime(2026, 8, 22),
    );

    final notaHist = NotaSAP(
      id: 'nota-10834065',
      nota: '10834065',
      descricao: 'Oxidação no pino do primeiro isolador',
      criadoEm: DateTime(2021, 5, 31),
      local: 'H-L-SBEASTSA-RB4L01-4LT1',
      equipamento: '11739178',
    );

    final anexoHist = NotaSapAnexo(
      id: 'anexo-hist-10834065',
      notaSapId: 'nota-10834065',
      nomeArquivo: 'sap_10834065_foto_historica.jpg',
      nomeOriginal: 'Oxidacao_Pino_2021.jpg',
      tipoArquivo: NotaAnexoTipo.imagem,
      caminhoArquivo: 'notas/10834065/foto.jpg',
      bucket: 'notas-sap-anexos',
      tamanhoBytes: 1024,
      createdAt: DateTime(2021, 5, 31),
    );

    final widget = NotaComparadorVisualDialog(
      notaAtual: notaAtual,
      anexosAtuais: [anexoAtual],
      anexoAtualInicial: anexoAtual,
      origemHistorica: OrigemComparadorHistorico.notaAnterior,
      notaHistorica: notaHist,
      anexosHistoricos: [anexoHist],
      service: MockNotaSapAnaliseService(),
    );

    await tester.pumpWidget(wrapWithBoundary(child: widget, key: key, size: size));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Aplicar zoom no lado Atual via duplo tap
    final photoViews = find.byType(PhotoView);
    if (photoViews.evaluate().isNotEmpty) {
      await tester.tap(photoViews.first);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(photoViews.first);
      await tester.pump();
    }

    await capturarScreenshot(tester, key, '03_desktop_zoom_independente.png');
  });

  // 4. Desktop - Rotação Independente (1400x900)
  testWidgets('04_desktop_rotacao_independente', (tester) async {
    final key = GlobalKey();
    const size = Size(1400, 900);
    await tester.binding.setSurfaceSize(size);

    final notaAtual = NotaSAP(
      id: 'nota-11447191',
      nota: '11447191',
      descricao: 'Alinhamento dos contatos da seccionadora 32J2-4',
      criadoEm: DateTime(2025, 8, 10),
      local: 'H-S-STSA-DT2J02-2EL1-S401',
      equipamento: '11339529',
    );

    final anexoAtual = NotaSapAnexo(
      id: 'anexo-11447191-1',
      notaSapId: 'nota-11447191',
      nomeArquivo: 'sap_11447191_contatos_seccionadora.jpg',
      nomeOriginal: 'Contatos_Seccionadora_Superior.jpg',
      tipoArquivo: NotaAnexoTipo.imagem,
      caminhoArquivo: 'notas/11447191/foto1.jpg',
      bucket: 'notas-sap-anexos',
      tamanhoBytes: 1024,
      createdAt: DateTime(2025, 8, 10),
    );

    final notaHist = NotaSAP(
      id: 'nota-11332915',
      nota: '11332915',
      descricao: 'Contatos 32J2-4 não bem fechados',
      criadoEm: DateTime(2024, 7, 22),
      local: 'H-S-STSA-DT2J02-2EL1-S401',
      equipamento: '11339529',
    );

    final anexoHist = NotaSapAnexo(
      id: 'anexo-hist-11332915',
      notaSapId: 'nota-11332915',
      nomeArquivo: 'sap_11332915_contatos_ano_anterior.jpg',
      nomeOriginal: 'Contatos_Abertos_2024.jpg',
      tipoArquivo: NotaAnexoTipo.imagem,
      caminhoArquivo: 'notas/11332915/foto1.jpg',
      bucket: 'notas-sap-anexos',
      tamanhoBytes: 1024,
      createdAt: DateTime(2024, 7, 22),
    );

    final widget = NotaComparadorVisualDialog(
      notaAtual: notaAtual,
      anexosAtuais: [anexoAtual],
      anexoAtualInicial: anexoAtual,
      origemHistorica: OrigemComparadorHistorico.notaAnterior,
      notaHistorica: notaHist,
      anexosHistoricos: [anexoHist],
      service: MockNotaSapAnaliseService(),
    );

    await tester.pumpWidget(wrapWithBoundary(child: widget, key: key, size: size));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Rotacionar o lado Atual em 90 graus
    final rotateButtons = find.byTooltip('Rotacionar 90° (R)');
    if (rotateButtons.evaluate().isNotEmpty) {
      await tester.tap(rotateButtons.first);
      await tester.pump();
    }

    await capturarScreenshot(tester, key, '04_desktop_rotacao_independente.png');
  });

  // 5. Mobile - Aba Atual Ativa (390x844)
  testWidgets('05_mobile_atual', (tester) async {
    final key = GlobalKey();
    const size = Size(390, 844);
    await tester.binding.setSurfaceSize(size);

    final notaAtual = NotaSAP(
      id: 'nota-11598780',
      nota: '11598780',
      descricao: 'Estais folgados na torre 095/2',
      criadoEm: DateTime(2026, 8, 26),
      local: 'H-L-SPDDSTSD-RB5C08-5LT1',
      equipamento: '11745864',
    );

    final anexoAtual = NotaSapAnexo(
      id: 'anexo-11598780-1',
      notaSapId: 'nota-11598780',
      nomeArquivo: 'sap_11598780_estais.jpg',
      nomeOriginal: 'Estai_Principal_Frouxo.jpg',
      tipoArquivo: NotaAnexoTipo.imagem,
      caminhoArquivo: 'notas/11598780/estais.jpg',
      bucket: 'notas-sap-anexos',
      tamanhoBytes: 1024,
      createdAt: DateTime(2026, 8, 26),
    );

    final notaHist = NotaSAP(
      id: 'nota-11061528',
      nota: '11061528',
      descricao: '4 Estais folgados',
      criadoEm: DateTime(2022, 8, 26),
      local: 'H-L-SPDDSTSD-RB5C08-5LT1',
      equipamento: '11745864',
    );

    final anexoHist = NotaSapAnexo(
      id: 'anexo-hist-11061528',
      notaSapId: 'nota-11061528',
      nomeArquivo: 'sap_11061528_estais_2022.jpg',
      nomeOriginal: 'Estais_Condicao_2022.jpg',
      tipoArquivo: NotaAnexoTipo.imagem,
      caminhoArquivo: 'notas/11061528/foto.jpg',
      bucket: 'notas-sap-anexos',
      tamanhoBytes: 1024,
      createdAt: DateTime(2022, 8, 26),
    );

    final widget = NotaComparadorVisualDialog(
      notaAtual: notaAtual,
      anexosAtuais: [anexoAtual],
      anexoAtualInicial: anexoAtual,
      origemHistorica: OrigemComparadorHistorico.notaAnterior,
      notaHistorica: notaHist,
      anexosHistoricos: [anexoHist],
      service: MockNotaSapAnaliseService(),
    );

    await tester.pumpWidget(wrapWithBoundary(child: widget, key: key, size: size));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await capturarScreenshot(tester, key, '05_mobile_atual.png');
  });

  // 6. Mobile - Aba Histórico Ativa (390x844)
  testWidgets('06_mobile_historico', (tester) async {
    final key = GlobalKey();
    const size = Size(390, 844);
    await tester.binding.setSurfaceSize(size);

    final notaAtual = NotaSAP(
      id: 'nota-11598780',
      nota: '11598780',
      descricao: 'Estais folgados na torre 095/2',
      criadoEm: DateTime(2026, 8, 26),
      local: 'H-L-SPDDSTSD-RB5C08-5LT1',
      equipamento: '11745864',
    );

    final anexoAtual = NotaSapAnexo(
      id: 'anexo-11598780-1',
      notaSapId: 'nota-11598780',
      nomeArquivo: 'sap_11598780_estais.jpg',
      nomeOriginal: 'Estai_Principal_Frouxo.jpg',
      tipoArquivo: NotaAnexoTipo.imagem,
      caminhoArquivo: 'notas/11598780/estais.jpg',
      bucket: 'notas-sap-anexos',
      tamanhoBytes: 1024,
      createdAt: DateTime(2026, 8, 26),
    );

    final notaHist = NotaSAP(
      id: 'nota-11061528',
      nota: '11061528',
      descricao: '4 Estais folgados',
      criadoEm: DateTime(2022, 8, 26),
      local: 'H-L-SPDDSTSD-RB5C08-5LT1',
      equipamento: '11745864',
    );

    final anexoHist = NotaSapAnexo(
      id: 'anexo-hist-11061528',
      notaSapId: 'nota-11061528',
      nomeArquivo: 'sap_11061528_estais_2022.jpg',
      nomeOriginal: 'Estais_Condicao_2022.jpg',
      tipoArquivo: NotaAnexoTipo.imagem,
      caminhoArquivo: 'notas/11061528/foto.jpg',
      bucket: 'notas-sap-anexos',
      tamanhoBytes: 1024,
      createdAt: DateTime(2022, 8, 26),
    );

    final widget = NotaComparadorVisualDialog(
      notaAtual: notaAtual,
      anexosAtuais: [anexoAtual],
      anexoAtualInicial: anexoAtual,
      origemHistorica: OrigemComparadorHistorico.notaAnterior,
      notaHistorica: notaHist,
      anexosHistoricos: [anexoHist],
      service: MockNotaSapAnaliseService(),
    );

    await tester.pumpWidget(wrapWithBoundary(child: widget, key: key, size: size));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Tocar no botão de alternância HISTÓRICO
    await tester.tap(find.text('HISTÓRICO').first);
    await tester.pump();

    await capturarScreenshot(tester, key, '06_mobile_historico.png');
  });

  // 7. Mobile - PiP Contexto Flutuante (390x844)
  testWidgets('07_mobile_pip', (tester) async {
    final key = GlobalKey();
    const size = Size(390, 844);
    await tester.binding.setSurfaceSize(size);

    final notaAtual = NotaSAP(
      id: 'nota-11456649',
      nota: '11456649',
      descricao: 'Inspeção de vazamento de óleo no Trafo 01',
      criadoEm: DateTime(2025, 9, 15),
      local: 'H-S-STSA-SASE01-1TR1-TR01',
      equipamento: '11456552',
    );

    final anexoAtual = NotaSapAnexo(
      id: 'anexo-11456649-1',
      notaSapId: 'nota-11456649',
      nomeArquivo: 'sap_11456649_oleo_trafo.jpg',
      nomeOriginal: 'Vazamento_Base_Trafo.jpg',
      tipoArquivo: NotaAnexoTipo.imagem,
      caminhoArquivo: 'notas/11456649/oleo.jpg',
      bucket: 'notas-sap-anexos',
      tamanhoBytes: 1024,
      createdAt: DateTime(2025, 9, 15),
    );

    final notaHist = NotaSAP(
      id: 'nota-11210022',
      nota: '11210022',
      descricao: 'Coleta de óleo - Frasco âmbar',
      criadoEm: DateTime(2023, 9, 4),
      local: 'H-S-STSA-SASE01-1TR1-TR01',
      equipamento: '11456552',
    );

    final anexoHist = NotaSapAnexo(
      id: 'anexo-hist-11210022',
      notaSapId: 'nota-11210022',
      nomeArquivo: 'sap_11210022_oleo_frasco.jpg',
      nomeOriginal: 'Oleo_Frasco_2023.jpg',
      tipoArquivo: NotaAnexoTipo.imagem,
      caminhoArquivo: 'notas/11210022/oleo.jpg',
      bucket: 'notas-sap-anexos',
      tamanhoBytes: 1024,
      createdAt: DateTime(2023, 9, 4),
    );

    final widget = NotaComparadorVisualDialog(
      notaAtual: notaAtual,
      anexosAtuais: [anexoAtual],
      anexoAtualInicial: anexoAtual,
      origemHistorica: OrigemComparadorHistorico.notaAnterior,
      notaHistorica: notaHist,
      anexosHistoricos: [anexoHist],
      service: MockNotaSapAnaliseService(),
    );

    await tester.pumpWidget(wrapWithBoundary(child: widget, key: key, size: size));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await capturarScreenshot(tester, key, '07_mobile_pip.png');
  });

  // 8. Desktop - Falha Simulada de um Lado + Retry Independente (1400x900)
  testWidgets('08_estado_erro_um_lado', (tester) async {
    final key = GlobalKey();
    const size = Size(1400, 900);
    await tester.binding.setSurfaceSize(size);

    final notaAtual = NotaSAP(
      id: 'nota-11579479',
      nota: '11579479',
      descricao: 'Aquecimento na conexão do TC 34T2-5',
      criadoEm: DateTime(2026, 7, 10),
      local: 'H-S-STSD-RB5T02-4CT1-S501',
      equipamento: '11336154',
    );

    final anexoAtual = NotaSapAnexo(
      id: 'anexo-11579479-1',
      notaSapId: 'nota-11579479',
      nomeArquivo: 'sap_11579479_tc_aquecimento.jpg',
      nomeOriginal: 'Termografia_TC_34T2.jpg',
      tipoArquivo: NotaAnexoTipo.imagem,
      caminhoArquivo: 'notas/11579479/termo.jpg',
      bucket: 'notas-sap-anexos',
      tamanhoBytes: 1024,
      createdAt: DateTime(2026, 7, 10),
    );

    final notaHist = NotaSAP(
      id: 'nota-11434388',
      nota: '11434388',
      descricao: 'TSD:34T2-5 RESISTENCIA AQUECIM',
      criadoEm: DateTime(2025, 5, 26),
      local: 'H-S-STSD-RB5T02-4CT1-S501',
      equipamento: '11336154',
    );

    final anexoHist = NotaSapAnexo(
      id: 'anexo-hist-11434388',
      notaSapId: 'nota-11434388',
      nomeArquivo: 'sap_11434388_resistencia.jpg',
      nomeOriginal: 'Foto_Historica_TC.jpg',
      tipoArquivo: NotaAnexoTipo.imagem,
      caminhoArquivo: 'notas/11434388/foto.jpg',
      bucket: 'notas-sap-anexos',
      tamanhoBytes: 1024,
      createdAt: DateTime(2025, 5, 26),
    );

    final mock = MockNotaSapAnaliseService()..falharHistorico = true;

    final widget = NotaComparadorVisualDialog(
      notaAtual: notaAtual,
      anexosAtuais: [anexoAtual],
      anexoAtualInicial: anexoAtual,
      origemHistorica: OrigemComparadorHistorico.notaAnterior,
      notaHistorica: notaHist,
      anexosHistoricos: [anexoHist],
      service: mock,
    );

    await tester.pumpWidget(wrapWithBoundary(child: widget, key: key, size: size));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await capturarScreenshot(tester, key, '08_estado_erro_um_lado.png');
  });
}
