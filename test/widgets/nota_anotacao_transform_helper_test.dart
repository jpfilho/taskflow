import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/models/nota_sap_anotacao.dart';
import 'package:task2026/widgets/nota_workspace/nota_anotacao_transform_helper.dart';

void main() {
  group('Fase 3: Helper de Transformação, Letterboxing e Coordenadas Normalizadas', () {
    test('1. Letterboxing com imagem horizontal extrema (4000x1000) em container (1200x800)', () {
      const containerSize = Size(1200, 800);
      const imageSize = Size(4000, 1000); // Proporção 4:1

      final rect = NotaAnotacaoTransformHelper.calculateImageRect(
        containerSize: containerSize,
        imageSize: imageSize,
      );

      // Deve ocupar toda a largura (1200) e altura proporcional (300)
      expect(rect.width, 1200.0);
      expect(rect.height, 300.0);
      expect(rect.left, 0.0);
      expect(rect.top, 250.0); // Centralizado verticalmente: (800 - 300) / 2 = 250
    });

    test('2. Letterboxing com imagem vertical extrema (1000x4000) em container (1200x800)', () {
      const containerSize = Size(1200, 800);
      const imageSize = Size(1000, 4000); // Proporção 1:4

      final rect = NotaAnotacaoTransformHelper.calculateImageRect(
        containerSize: containerSize,
        imageSize: imageSize,
      );

      // Deve ocupar toda a altura (800) e largura proporcional (200)
      expect(rect.height, 800.0);
      expect(rect.width, 200.0);
      expect(rect.top, 0.0);
      expect(rect.left, 500.0); // Centralizado horizontalmente: (1200 - 200) / 2 = 500
    });

    test('3. Letterboxing com imagem quadrada (2000x2000) em container widescreen (1600x900)', () {
      const containerSize = Size(1600, 900);
      const imageSize = Size(2000, 2000);

      final rect = NotaAnotacaoTransformHelper.calculateImageRect(
        containerSize: containerSize,
        imageSize: imageSize,
      );

      // Deve ocupar toda a altura (900) e largura igual (900)
      expect(rect.height, 900.0);
      expect(rect.width, 900.0);
      expect(rect.top, 0.0);
      expect(rect.left, 350.0); // (1600 - 900) / 2 = 350
    });

    test('4. Conversão precisa entre Tela e Normalizado (0.0 a 1.0)', () {
      const imageRect = Rect.fromLTWH(100, 200, 1000, 500);

      // Canto superior esquerdo
      final normTopLeft = NotaAnotacaoTransformHelper.screenToNormalized(
        screenOffset: const Offset(100, 200),
        imageRect: imageRect,
      );
      expect(normTopLeft, const Offset(0.0, 0.0));

      // Centro
      final normCenter = NotaAnotacaoTransformHelper.screenToNormalized(
        screenOffset: const Offset(600, 450),
        imageRect: imageRect,
      );
      expect(normCenter, const Offset(0.5, 0.5));

      // Canto inferior direito
      final normBottomRight = NotaAnotacaoTransformHelper.screenToNormalized(
        screenOffset: const Offset(1100, 700),
        imageRect: imageRect,
      );
      expect(normBottomRight, const Offset(1.0, 1.0));

      // Reversão de normalizado para tela
      final screenFromNorm = NotaAnotacaoTransformHelper.normalizedToScreen(
        normalizedOffset: const Offset(0.5, 0.5),
        imageRect: imageRect,
      );
      expect(screenFromNorm, const Offset(600, 450));
    });

    test('5. Responsividade Cruzada: Anotação criada no Desktop permanece exata no Mobile', () {
      // Desktop: Monitor Full HD (1920x1080)
      const desktopContainer = Size(1920, 1080);
      const photoSize = Size(4000, 3000); // Câmera 4:3
      final desktopRect = NotaAnotacaoTransformHelper.calculateImageRect(
        containerSize: desktopContainer,
        imageSize: photoSize,
      );

      // Usuário marca um ponto exato na imagem (ex: 20% da esquerda e 40% do topo da foto)
      const normalizedPoint = Offset(0.2, 0.4);
      final desktopScreenPoint = NotaAnotacaoTransformHelper.normalizedToScreen(
        normalizedOffset: normalizedPoint,
        imageRect: desktopRect,
      );

      // Mobile: Smartphone tela vertical (390x844)
      const mobileContainer = Size(390, 844);
      final mobileRect = NotaAnotacaoTransformHelper.calculateImageRect(
        containerSize: mobileContainer,
        imageSize: photoSize,
      );

      // Mesma coordenada normalizada convertida para a tela mobile
      final mobileScreenPoint = NotaAnotacaoTransformHelper.normalizedToScreen(
        normalizedOffset: normalizedPoint,
        imageRect: mobileRect,
      );

      // Verificação: Reconvertendo a coordenada de tela desktop para normalizada
      final reconvertedDesktop = NotaAnotacaoTransformHelper.screenToNormalized(
        screenOffset: desktopScreenPoint,
        imageRect: desktopRect,
      );
      expect(reconvertedDesktop.dx, closeTo(0.2, 0.0001));
      expect(reconvertedDesktop.dy, closeTo(0.4, 0.0001));

      // Verificação: Reconvertendo a coordenada da tela mobile para normalizada
      final reconvertedNormalized = NotaAnotacaoTransformHelper.screenToNormalized(
        screenOffset: mobileScreenPoint,
        imageRect: mobileRect,
      );

      expect(reconvertedNormalized.dx, closeTo(0.2, 0.0001));
      expect(reconvertedNormalized.dy, closeTo(0.4, 0.0001));
    });

    test('6. Hit testing para seleção de Retângulo, Círculo, Seta e Texto', () {
      const imageRect = Rect.fromLTWH(0, 0, 1000, 1000);

      // Retângulo entre (0.2, 0.2) e (0.5, 0.5)
      const rectEl = NotaSapAnotacaoElemento(
        id: 'rect1',
        type: NotaSapElementoTipo.rect,
        x1: 0.2,
        y1: 0.2,
        x2: 0.5,
        y2: 0.5,
      );

      // Ponto dentro do retângulo
      expect(
        NotaAnotacaoTransformHelper.hitTestElement(
          element: rectEl,
          normalizedPoint: const Offset(0.35, 0.35),
          imageRect: imageRect,
        ),
        isTrue,
      );

      // Ponto fora do retângulo
      expect(
        NotaAnotacaoTransformHelper.hitTestElement(
          element: rectEl,
          normalizedPoint: const Offset(0.8, 0.8),
          imageRect: imageRect,
        ),
        isFalse,
      );

      // Seta de (0.1, 0.1) a (0.9, 0.9)
      const arrowEl = NotaSapAnotacaoElemento(
        id: 'arrow1',
        type: NotaSapElementoTipo.arrow,
        x1: 0.1,
        y1: 0.1,
        x2: 0.9,
        y2: 0.9,
      );

      // Ponto sobre a linha da seta
      expect(
        NotaAnotacaoTransformHelper.hitTestElement(
          element: arrowEl,
          normalizedPoint: const Offset(0.5, 0.5),
          imageRect: imageRect,
        ),
        isTrue,
      );

      // Ponto afastado da linha da seta
      expect(
        NotaAnotacaoTransformHelper.hitTestElement(
          element: arrowEl,
          normalizedPoint: const Offset(0.1, 0.8),
          imageRect: imageRect,
        ),
        isFalse,
      );
    });
  });
}
