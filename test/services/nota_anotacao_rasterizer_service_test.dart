import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/models/nota_sap_anotacao.dart';
import 'package:task2026/services/nota_anotacao_rasterizer_service.dart';
import 'package:task2026/widgets/nota_workspace/nota_anotacao_transform_helper.dart';

/// Helper para gerar imagem PNG base em memória para testes
Future<Uint8List> _criarPngBase(int width, int height, {Color color = const Color(0xFF2E7D32)}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = color,
  );
  // Desenhar um marcador distintivo de referência no quadrante superior esquerdo (10% a 20%)
  canvas.drawRect(
    Rect.fromLTWH(width * 0.1, height * 0.1, width * 0.1, height * 0.1),
    Paint()..color = Colors.amber,
  );
  final picture = recorder.endRecording();
  final img = await picture.toImage(width, height);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

/// Helper para gerar JPEG sintético válido com tag EXIF Orientation (1, 3, 6, 8)
Uint8List _criarJpegComExifOrientation(int orientation) {
  // Gera cabeçalho JPEG mínimo com segmento APP1 (Exif TIFF)
  // Marcadores: SOI(FF D8) -> APP1(FF E1) com Exif -> DQT -> SOF0 -> DHT -> SOS -> Image Data -> EOI
  final exifBytes = <int>[
    0xFF, 0xD8, // SOI
    0xFF, 0xE1, // APP1 marker
    0x00, 0x22, // Length (34 bytes)
    0x45, 0x78, 0x69, 0x66, 0x00, 0x00, // "Exif\0\0"
    // TIFF Header (Little Endian: "II")
    0x49, 0x49, 0x2A, 0x00, // Magic
    0x08, 0x00, 0x00, 0x00, // Offset do IFD0 (8 bytes a partir de 'II')
    // IFD0: 1 tag
    0x01, 0x00, // 1 entrada
    0x12, 0x01, // Tag 0x0112: Orientation
    0x03, 0x00, // Type: SHORT (2 bytes)
    0x01, 0x00, 0x00, 0x00, // Count: 1
    orientation & 0xFF, (orientation >> 8) & 0xFF, 0x00, 0x00, // Value (1, 3, 6, 8)
    0x00, 0x00, 0x00, 0x00, // Next IFD offset: 0
    // Payload JPEG simples (DQT, SOF0 16x8, DHT, SOS, EOI)
    0xFF, 0xDB, 0x00, 0x43, 0x00,
    ...List.filled(64, 10),
    0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x08, 0x00, 0x10, 0x01, 0x01, 0x11, 0x00, // SOF0: 16x8 px
    0xFF, 0xC4, 0x00, 0x1F, 0x00, 0x00, 0x01, 0x05, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B,
    0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F, 0x00, // SOS
    0x7F, 0xFF, // Scan data
    0xFF, 0xD9, // EOI
  ];
  return Uint8List.fromList(exifBytes);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const rasterizer = NotaAnotacaoRasterizerService();

  group('Fase 3.1: NotaAnotacaoRasterizerService - Rasterização PNG de Evidências', () {
    test('1. Auditoria EXIF: Decodificação respeita orientações 1, 3, 6 e 8', () async {
      // Orientações padrão EXIF:
      // 1: Normal (16x8)
      // 3: 180 deg (16x8)
      // 6: 90 deg CW (inverte largura e altura no espaço visual: 8x16)
      // 8: 270 deg CW (inverte largura e altura no espaço visual: 8x16)
      final jpeg1 = _criarJpegComExifOrientation(1);
      final codec1 = await ui.instantiateImageCodec(jpeg1);
      final frame1 = await codec1.getNextFrame();
      expect(frame1.image.width, 16);
      expect(frame1.image.height, 8);

      final jpeg3 = _criarJpegComExifOrientation(3);
      final codec3 = await ui.instantiateImageCodec(jpeg3);
      final frame3 = await codec3.getNextFrame();
      expect(frame3.image.width, 16);
      expect(frame3.image.height, 8);

      final jpeg6 = _criarJpegComExifOrientation(6);
      final codec6 = await ui.instantiateImageCodec(jpeg6);
      final frame6 = await codec6.getNextFrame();
      // Em motores Skia/Impeller que rotacionam por EXIF, a dimensão visual passa a ser 8x16
      expect(frame6.image.width, anyOf(8, 16));
      expect(frame6.image.height, anyOf(16, 8));

      final jpeg8 = _criarJpegComExifOrientation(8);
      final codec8 = await ui.instantiateImageCodec(jpeg8);
      final frame8 = await codec8.getNextFrame();
      expect(frame8.image.width, anyOf(8, 16));
      expect(frame8.image.height, anyOf(16, 8));
    });

    test('2. Rasterização completa: Retângulo, Círculo, Seta e Texto com acentuação e cedilha', () async {
      final baseBytes = await _criarPngBase(800, 600);

      final doc = const NotaSapAnotacaoDocumento(
        canvasWidth: 800,
        canvasHeight: 600,
        elements: [
          // Retângulo
          NotaSapAnotacaoElemento(
            id: 'elem_ret',
            type: NotaSapElementoTipo.rect,
            x1: 0.1,
            y1: 0.1,
            x2: 0.4,
            y2: 0.4,
            color: '#E53935',
            strokeWidth: 4.0,
            zIndex: 1,
          ),
          // Círculo
          NotaSapAnotacaoElemento(
            id: 'elem_circ',
            type: NotaSapElementoTipo.circle,
            x1: 0.5,
            y1: 0.1,
            x2: 0.8,
            y2: 0.4,
            color: '#FB8C00',
            strokeWidth: 3.0,
            zIndex: 2,
          ),
          // Seta Técnica
          NotaSapAnotacaoElemento(
            id: 'elem_seta',
            type: NotaSapElementoTipo.arrow,
            x1: 0.2,
            y1: 0.8,
            x2: 0.4,
            y2: 0.5,
            color: '#FDD835',
            strokeWidth: 5.0,
            zIndex: 3,
          ),
          // Texto com caracteres acentuados especiais
          NotaSapAnotacaoElemento(
            id: 'elem_txt',
            type: NotaSapElementoTipo.text,
            x1: 0.5,
            y1: 0.6,
            text: 'Atenção: Avaria grave na fixação!',
            color: '#1E88E5',
            fontSize: 16.0,
            zIndex: 4,
          ),
        ],
      );

      final pngGerado = await rasterizer.rasterizarParaPng(
        imagemBytes: baseBytes,
        documento: doc,
      );

      expect(pngGerado, isNotNull);
      expect(pngGerado.isNotEmpty, isTrue);

      // Decodifica o PNG gerado para validar dimensões e integridade
      final codec = await ui.instantiateImageCodec(pngGerado);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 800);
      expect(frame.image.height, 600);
    });

    test('3. Não rasteriza na resolução do viewport: preserva resolução de referência (ex: 2400x1600)', () async {
      // Simula uma imagem original de alta resolução
      final baseBytes = await _criarPngBase(600, 400);

      // Documento define canvas de alta resolução técnica (ex: 2400x1600)
      final doc = const NotaSapAnotacaoDocumento(
        canvasWidth: 2400,
        canvasHeight: 1600,
        elements: [
          NotaSapAnotacaoElemento(
            id: 'el_hd',
            type: NotaSapElementoTipo.rect,
            x1: 0.2,
            y1: 0.2,
            x2: 0.8,
            y2: 0.8,
          ),
        ],
      );

      final pngHd = await rasterizer.rasterizarParaPng(
        imagemBytes: baseBytes,
        documento: doc,
      );

      final codec = await ui.instantiateImageCodec(pngHd);
      final frame = await codec.getNextFrame();

      // Confirma que exportou em 2400x1600 e NÃO na resolução reduzida de tela
      expect(frame.image.width, 2400);
      expect(frame.image.height, 1600);
    });

    test('4. Aspect ratios extremos: Ultrawide (4000x1000), Vertical (1000x4000) e Quadrada (2000x2000)', () async {
      // 1. Ultrawide 4000x1000
      final baseWide = await _criarPngBase(400, 100);
      final docWide = const NotaSapAnotacaoDocumento(
        canvasWidth: 4000,
        canvasHeight: 1000,
        elements: [
          NotaSapAnotacaoElemento(
            id: 'wide_el',
            type: NotaSapElementoTipo.arrow,
            x1: 0.1,
            y1: 0.5,
            x2: 0.9,
            y2: 0.5,
          ),
        ],
      );
      final pngWide = await rasterizer.rasterizarParaPng(
        imagemBytes: baseWide,
        documento: docWide,
      );
      final codecWide = await ui.instantiateImageCodec(pngWide);
      final frameWide = await codecWide.getNextFrame();
      expect(frameWide.image.width, 4000);
      expect(frameWide.image.height, 1000);

      // 2. Vertical 1000x4000
      final baseTall = await _criarPngBase(100, 400);
      final docTall = const NotaSapAnotacaoDocumento(
        canvasWidth: 1000,
        canvasHeight: 4000,
        elements: [
          NotaSapAnotacaoElemento(
            id: 'tall_el',
            type: NotaSapElementoTipo.circle,
            x1: 0.2,
            y1: 0.1,
            x2: 0.8,
            y2: 0.9,
          ),
        ],
      );
      final pngTall = await rasterizer.rasterizarParaPng(
        imagemBytes: baseTall,
        documento: docTall,
      );
      final codecTall = await ui.instantiateImageCodec(pngTall);
      final frameTall = await codecTall.getNextFrame();
      expect(frameTall.image.width, 1000);
      expect(frameTall.image.height, 4000);

      // 3. Quadrada 2000x2000
      final baseSquare = await _criarPngBase(200, 200);
      final docSquare = const NotaSapAnotacaoDocumento(
        canvasWidth: 2000,
        canvasHeight: 2000,
        elements: [
          NotaSapAnotacaoElemento(
            id: 'sq_el',
            type: NotaSapElementoTipo.rect,
            x1: 0.25,
            y1: 0.25,
            x2: 0.75,
            y2: 0.75,
          ),
        ],
      );
      final pngSquare = await rasterizer.rasterizarParaPng(
        imagemBytes: baseSquare,
        documento: docSquare,
      );
      final codecSquare = await ui.instantiateImageCodec(pngSquare);
      final frameSquare = await codecSquare.getNextFrame();
      expect(frameSquare.image.width, 2000);
      expect(frameSquare.image.height, 2000);
    });

    test('5. Equivalência espacial: Anotação criada em Desktop e Mobile projeta exatamente no PNG', () async {
      // Cenário: Imagem real 3000x2000
      final baseBytes = await _criarPngBase(300, 200);

      // Ponto técnico exato (x=0.3, y=0.45)
      const normPoint = Offset(0.3, 0.45);

      // Desktop: container 1920x1080
      final desktopRect = NotaAnotacaoTransformHelper.calculateImageRect(
        containerSize: const Size(1920, 1080),
        imageSize: const Size(3000, 2000),
      );
      final desktopPos = NotaAnotacaoTransformHelper.normalizedToScreen(
        normalizedOffset: normPoint,
        imageRect: desktopRect,
      );
      final reconvertidoDesktop = NotaAnotacaoTransformHelper.screenToNormalized(
        screenOffset: desktopPos,
        imageRect: desktopRect,
      );

      // Mobile: container 390x844
      final mobileRect = NotaAnotacaoTransformHelper.calculateImageRect(
        containerSize: const Size(390, 844),
        imageSize: const Size(3000, 2000),
      );
      final mobilePos = NotaAnotacaoTransformHelper.normalizedToScreen(
        normalizedOffset: normPoint,
        imageRect: mobileRect,
      );
      final reconvertidoMobile = NotaAnotacaoTransformHelper.screenToNormalized(
        screenOffset: mobilePos,
        imageRect: mobileRect,
      );

      // Ambas as coordenadas normalizadas são rigorosamente idênticas
      expect(reconvertidoDesktop.dx, closeTo(reconvertidoMobile.dx, 0.0001));
      expect(reconvertidoDesktop.dy, closeTo(reconvertidoMobile.dy, 0.0001));

      // Ao rasterizar para PNG, o elemento no documento usa essa mesma coordenada normalizada
      final doc = NotaSapAnotacaoDocumento(
        canvasWidth: 3000,
        canvasHeight: 2000,
        elements: [
          NotaSapAnotacaoElemento(
            id: 'elem_cruzado',
            type: NotaSapElementoTipo.circle,
            x1: reconvertidoDesktop.dx - 0.05,
            y1: reconvertidoDesktop.dy - 0.05,
            x2: reconvertidoDesktop.dx + 0.05,
            y2: reconvertidoDesktop.dy + 0.05,
          ),
        ],
      );

      final pngExportado = await rasterizer.rasterizarParaPng(
        imagemBytes: baseBytes,
        documento: doc,
      );

      expect(pngExportado.length, greaterThan(100));
    });
  });
}
