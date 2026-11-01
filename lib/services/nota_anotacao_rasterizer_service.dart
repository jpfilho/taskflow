import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:task2026/models/nota_sap_anotacao.dart';
import 'package:task2026/widgets/nota_workspace/nota_anotacao_transform_helper.dart';

/// Serviço responsável por rasterizar a imagem base e anotações estruturadas (JSON)
/// em uma evidência técnica PNG de alta fidelidade e alta resolução.
/// 
/// PRINCÍPIOS:
/// 1. Renderiza na resolução do documento/imagem original, nunca na do viewport.
/// 2. Não inclui elementos de interface (sem handles, sem bounding boxes de seleção).
/// 3. Respeita a orientação visual decodificada pelo Flutter (EXIF).
/// 4. Preserva tipografia com suporte pleno a UTF-8 (acentuação, cedilha, símbolos).
class NotaAnotacaoRasterizerService {
  const NotaAnotacaoRasterizerService();

  /// Rasteriza a imagem base e os elementos vetoriais em um PNG de alta resolução.
  /// 
  /// [imagemBytes]: Bytes binários da imagem original (JPEG, PNG, etc).
  /// [documento]: Documento estruturado com elementos em coordenadas normalizadas (0.0 a 1.0).
  /// [overrideDimensoes]: Opcional para testes ou exportações em dimensões específicas.
  Future<Uint8List> rasterizarParaPng({
    required Uint8List imagemBytes,
    required NotaSapAnotacaoDocumento documento,
    Size? overrideDimensoes,
  }) async {
    // 1. Decodificar imagem base via motor gráfico nativo do Flutter
    // O instantiateImageCodec aplica automaticamente a orientação EXIF nas versões modernas do Flutter
    final codec = await ui.instantiateImageCodec(imagemBytes);
    final frame = await codec.getNextFrame();
    final ui.Image baseImage = frame.image;

    // 2. Determinar dimensões finais da renderização
    final double targetWidth;
    final double targetHeight;

    if (overrideDimensoes != null && overrideDimensoes.width > 0 && overrideDimensoes.height > 0) {
      targetWidth = overrideDimensoes.width;
      targetHeight = overrideDimensoes.height;
    } else if (documento.canvasWidth > 0 && documento.canvasHeight > 0) {
      targetWidth = documento.canvasWidth;
      targetHeight = documento.canvasHeight;
    } else {
      targetWidth = baseImage.width.toDouble();
      targetHeight = baseImage.height.toDouble();
    }

    final targetRect = Rect.fromLTWH(0, 0, targetWidth, targetHeight);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, targetRect);

    // 3. Desenhar a imagem base preenchendo a área de referência
    final srcRect = Rect.fromLTWH(
      0,
      0,
      baseImage.width.toDouble(),
      baseImage.height.toDouble(),
    );

    final imagePaint = Paint()..filterQuality = FilterQuality.high;
    canvas.drawImageRect(baseImage, srcRect, targetRect, imagePaint);

    // 4. Ordenar elementos por zIndex para renderização em camadas correta
    final elementosOrdenados = List<NotaSapAnotacaoElemento>.from(documento.elements)
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    // Escala geométrica para manter a proporção visual idêntica à vista no editor
    final scaleRef = min(targetWidth, targetHeight);
    final scaleFactor = max(1.0, scaleRef / 800.0);

    // 5. Renderizar cada elemento vetorial
    for (final el in elementosOrdenados) {
      _renderizarElemento(
        canvas: canvas,
        element: el,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
        scaleFactor: scaleFactor,
      );
    }

    // 6. Concluir a gravação e converter para PNG
    final picture = recorder.endRecording();
    final renderedImage = await picture.toImage(
      targetWidth.toInt(),
      targetHeight.toInt(),
    );

    final byteData = await renderedImage.toByteData(
      format: ui.ImageByteFormat.png,
    );

    if (byteData == null) {
      throw Exception('Falha ao codificar imagem rasterizada em formato PNG.');
    }

    return byteData.buffer.asUint8List();
  }

  /// Renderiza um elemento técnico individual sobre o Canvas sem artefatos de UI
  void _renderizarElemento({
    required Canvas canvas,
    required NotaSapAnotacaoElemento element,
    required double targetWidth,
    required double targetHeight,
    required double scaleFactor,
  }) {
    final imageRect = Rect.fromLTWH(0, 0, targetWidth, targetHeight);
    final cor = element.colorValue;
    final strokeWidth = max(2.0, element.strokeWidth * scaleFactor);

    final paintStroke = Paint()
      ..color = cor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (element.type) {
      case NotaSapElementoTipo.rect:
        final p1 = NotaAnotacaoTransformHelper.normalizedToScreen(
          normalizedOffset: Offset(element.x1, element.y1),
          imageRect: imageRect,
        );
        final p2 = NotaAnotacaoTransformHelper.normalizedToScreen(
          normalizedOffset: Offset(element.x2 ?? element.x1, element.y2 ?? element.y1),
          imageRect: imageRect,
        );
        final rect = Rect.fromPoints(p1, p2);
        final rrect = RRect.fromRectAndRadius(
          rect,
          Radius.circular(6 * scaleFactor),
        );
        canvas.drawRRect(rrect, paintStroke);
        break;

      case NotaSapElementoTipo.circle:
        final p1 = NotaAnotacaoTransformHelper.normalizedToScreen(
          normalizedOffset: Offset(element.x1, element.y1),
          imageRect: imageRect,
        );
        final p2 = NotaAnotacaoTransformHelper.normalizedToScreen(
          normalizedOffset: Offset(element.x2 ?? element.x1, element.y2 ?? element.y1),
          imageRect: imageRect,
        );
        final rect = Rect.fromPoints(p1, p2);
        canvas.drawOval(rect, paintStroke);
        break;

      case NotaSapElementoTipo.arrow:
        final p1 = NotaAnotacaoTransformHelper.normalizedToScreen(
          normalizedOffset: Offset(element.x1, element.y1),
          imageRect: imageRect,
        );
        final p2 = NotaAnotacaoTransformHelper.normalizedToScreen(
          normalizedOffset: Offset(element.x2 ?? element.x1, element.y2 ?? element.y1),
          imageRect: imageRect,
        );

        // Linha principal da seta
        canvas.drawLine(p1, p2, paintStroke);

        // Ponta da seta proporcional
        final dx = p2.dx - p1.dx;
        final dy = p2.dy - p1.dy;
        final length = sqrt(dx * dx + dy * dy);
        if (length > 1.0) {
          final angle = atan2(dy, dx);
          final headSize = max(14.0 * scaleFactor, strokeWidth * 3.5);

          final arrowPath = Path();
          arrowPath.moveTo(p2.dx, p2.dy);
          arrowPath.lineTo(
            p2.dx - headSize * cos(angle - pi / 6),
            p2.dy - headSize * sin(angle - pi / 6),
          );
          arrowPath.lineTo(
            p2.dx - headSize * cos(angle + pi / 6),
            p2.dy - headSize * sin(angle + pi / 6),
          );
          arrowPath.close();

          final arrowPaint = Paint()
            ..color = cor
            ..style = PaintingStyle.fill;
          canvas.drawPath(arrowPath, arrowPaint);
        }
        break;

      case NotaSapElementoTipo.text:
        final textContent = element.text ?? element.label ?? '';
        if (textContent.trim().isEmpty) return;

        final pos = NotaAnotacaoTransformHelper.normalizedToScreen(
          normalizedOffset: Offset(element.x1, element.y1),
          imageRect: imageRect,
        );

        // Escala da fonte ajustada à resolução da imagem de referência
        final logicalFontSize = element.fontSize;
        final fontSize = max(12.0, logicalFontSize * scaleFactor);

        final textSpan = TextSpan(
          text: textContent,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
        );

        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
          maxLines: 4,
          ellipsis: '...',
        );
        textPainter.layout(maxWidth: targetWidth * 0.85);

        // Fundo com cápsula de alto contraste (fundo escuro + borda com a cor do elemento)
        final paddingH = 10.0 * scaleFactor;
        final paddingV = 6.0 * scaleFactor;
        final bgRect = Rect.fromLTWH(
          pos.dx - paddingH,
          pos.dy - paddingV,
          textPainter.width + (paddingH * 2),
          textPainter.height + (paddingV * 2),
        );
        final bgRRect = RRect.fromRectAndRadius(
          bgRect,
          Radius.circular(6 * scaleFactor),
        );

        final bgPaint = Paint()
          ..color = const Color(0xCC000000)
          ..style = PaintingStyle.fill;
        canvas.drawRRect(bgRRect, bgPaint);

        final borderPaint = Paint()
          ..color = cor
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.5, 2.0 * scaleFactor);
        canvas.drawRRect(bgRRect, borderPaint);

        textPainter.paint(canvas, pos);
        break;
    }
  }
}
