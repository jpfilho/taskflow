import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/nota_sap_anotacao.dart';

/// Helper central para conversões geométricas e tratamento de Letterboxing / BoxFit.contain
class NotaAnotacaoTransformHelper {
  /// Calcula o retângulo real da imagem desenhada dentro de um container com [BoxFit.contain]
  static Rect calculateImageRect({
    required Size containerSize,
    required Size imageSize,
    BoxFit fit = BoxFit.contain,
  }) {
    if (containerSize.width <= 0 ||
        containerSize.height <= 0 ||
        imageSize.width <= 0 ||
        imageSize.height <= 0) {
      return Rect.zero;
    }

    final double containerAspect = containerSize.width / containerSize.height;
    final double imageAspect = imageSize.width / imageSize.height;

    double drawWidth;
    double drawHeight;

    if (containerAspect > imageAspect) {
      // Container mais largo que a imagem (barras nas laterais / letterboxing horizontal)
      drawHeight = containerSize.height;
      drawWidth = drawHeight * imageAspect;
    } else {
      // Container mais alto que a imagem (barras em cima/baixo / letterboxing vertical)
      drawWidth = containerSize.width;
      drawHeight = drawWidth / imageAspect;
    }

    final double left = (containerSize.width - drawWidth) / 2.0;
    final double top = (containerSize.height - drawHeight) / 2.0;

    return Rect.fromLTWH(left, top, drawWidth, drawHeight);
  }

  /// Converte um ponto da tela para coordenadas normalizadas (0.0 a 1.0)
  static Offset screenToNormalized({
    required Offset screenOffset,
    required Rect imageRect,
    bool clamp = true,
  }) {
    if (imageRect.width <= 0 || imageRect.height <= 0) {
      return Offset.zero;
    }

    double nx = (screenOffset.dx - imageRect.left) / imageRect.width;
    double ny = (screenOffset.dy - imageRect.top) / imageRect.height;

    if (clamp) {
      nx = nx.clamp(0.0, 1.0);
      ny = ny.clamp(0.0, 1.0);
    }

    return Offset(nx, ny);
  }

  /// Converte coordenadas normalizadas (0.0 a 1.0) para coordenadas na tela
  static Offset normalizedToScreen({
    required Offset normalizedOffset,
    required Rect imageRect,
  }) {
    return Offset(
      imageRect.left + normalizedOffset.dx * imageRect.width,
      imageRect.top + normalizedOffset.dy * imageRect.height,
    );
  }

  /// Converte um Rect normalizado para coordenadas de tela
  static Rect normalizedRectToScreen({
    required Rect normalizedRect,
    required Rect imageRect,
  }) {
    return Rect.fromLTWH(
      imageRect.left + normalizedRect.left * imageRect.width,
      imageRect.top + normalizedRect.top * imageRect.height,
      normalizedRect.width * imageRect.width,
      normalizedRect.height * imageRect.height,
    );
  }

  /// Converte um Rect de tela para coordenadas normalizadas
  static Rect screenRectToNormalized({
    required Rect screenRect,
    required Rect imageRect,
  }) {
    if (imageRect.width <= 0 || imageRect.height <= 0) return Rect.zero;

    final p1 = screenToNormalized(
      screenOffset: screenRect.topLeft,
      imageRect: imageRect,
    );
    final p2 = screenToNormalized(
      screenOffset: screenRect.bottomRight,
      imageRect: imageRect,
    );

    return Rect.fromLTRB(p1.dx, p1.dy, p2.dx, p2.dy);
  }

  /// Hit testing para identificar qual elemento foi tocado/clicado
  static bool hitTestElement({
    required NotaSapAnotacaoElemento element,
    required Offset normalizedPoint,
    required Rect imageRect,
    double hitSlopPixels = 12.0,
  }) {
    if (imageRect.width <= 0 || imageRect.height <= 0) return false;

    // Converte a tolerância de pixels para proporção normalizada
    final double tolX = hitSlopPixels / imageRect.width;
    final double tolY = hitSlopPixels / imageRect.height;
    final double avgTol = (tolX + tolY) / 2.0;

    switch (element.type) {
      case NotaSapElementoTipo.rect:
        final box = element.normalizedBoundingBox;
        // Permite seleção tanto pela borda quanto pelo interior
        final expanded = box.inflate(avgTol);
        return expanded.contains(normalizedPoint);

      case NotaSapElementoTipo.circle:
        final box = element.normalizedBoundingBox;
        final cx = box.center.dx;
        final cy = box.center.dy;
        final rx = box.width / 2.0;
        final ry = box.height / 2.0;
        if (rx <= 0 || ry <= 0) {
          return (normalizedPoint - Offset(cx, cy)).distance <= avgTol;
        }
        // Equação da elipse normalizada (com margem de tolerância)
        final normDist = math.pow((normalizedPoint.dx - cx) / (rx + avgTol), 2) +
            math.pow((normalizedPoint.dy - cy) / (ry + avgTol), 2);
        return normDist <= 1.0;

      case NotaSapElementoTipo.arrow:
        final p1 = Offset(element.x1, element.y1);
        final p2 = Offset(element.x2 ?? element.x1, element.y2 ?? element.y1);
        final dist = _distanceToSegment(normalizedPoint, p1, p2);
        return dist <= avgTol;

      case NotaSapElementoTipo.text:
        final box = element.normalizedBoundingBox;
        // Se for só um ponto inicial de texto, garante uma caixa mínima de hit
        final textWidthNorm = math.max(box.width, 0.15);
        final textHeightNorm = math.max(box.height, 0.05);
        final textBox = Rect.fromLTWH(
          element.x1,
          element.y1,
          textWidthNorm,
          textHeightNorm,
        ).inflate(avgTol);
        return textBox.contains(normalizedPoint);
    }
  }

  /// Distância de um ponto a um segmento de reta P1 -> P2
  static double _distanceToSegment(Offset p, Offset p1, Offset p2) {
    final double l2 = (p2 - p1).distanceSquared;
    if (l2 == 0) return (p - p1).distance;
    final double t = math.max(
      0.0,
      math.min(1.0, ((p.dx - p1.dx) * (p2.dx - p1.dx) + (p.dy - p1.dy) * (p2.dy - p1.dy)) / l2),
    );
    final Offset projection = Offset(
      p1.dx + t * (p2.dx - p1.dx),
      p1.dy + t * (p2.dy - p1.dy),
    );
    return (p - projection).distance;
  }
}
