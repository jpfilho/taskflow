import 'dart:math' show sqrt;
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/models/annotation_models.dart';
import '../../application/controllers/annotation_controller.dart';

/// Canvas de anotação: imagem + overlay desenhado. Pan/zoom via InteractiveViewer.
/// Use [repaintBoundaryKey] para export (toImage). Coordenadas são no espaço do filho do viewer.
/// [onTextTap]: quando ferramenta é texto e usuário toca, chama com posição para abrir dialog.
class AnnotationCanvas extends StatefulWidget {
  const AnnotationCanvas({
    super.key,
    required this.imageUrl,
    required this.controller,
    this.repaintBoundaryKey,
    this.onTextTap,
  });

  final String imageUrl;
  final AnnotationController controller;
  final GlobalKey? repaintBoundaryKey;
  final void Function(Offset position)? onTextTap;

  @override
  State<AnnotationCanvas> createState() => _AnnotationCanvasState();
}

class _AnnotationCanvasState extends State<AnnotationCanvas> {
  final GlobalKey _contentKey = GlobalKey();
  bool _dragSelectionStarted = false;
  /// Dimensões intrínsecas da imagem (para manter mesmo aspect ratio na exportação).
  Size? _imageSize;
  bool _resolutionStarted = false;

  RenderBox? get _contentBox =>
      _contentKey.currentContext?.findRenderObject() as RenderBox?;

  Offset? _localPosition(Offset global) {
    return _contentBox?.globalToLocal(global);
  }

  void _resolveImageSize() {
    if (_imageSize != null || _resolutionStarted) return;
    _resolutionStarted = true;
    final provider = CachedNetworkImageProvider(widget.imageUrl);
    provider.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((ImageInfo info, bool _) {
        if (!mounted) return;
        final image = info.image;
        setState(() {
          _imageSize = Size(
            image.width.toDouble(),
            image.height.toDouble(),
          );
        });
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final isPanMode = widget.controller.isPanMode;
        return Listener(
          onPointerDown: (e) {
            final local = _localPosition(e.position);
            if (local == null) return;
            if (widget.controller.tool == AnnotationTool.select) {
              widget.controller.selectAt(local);
              _dragSelectionStarted = widget.controller.hasSelection;
              return;
            }
            if (widget.controller.tool == AnnotationTool.text) {
              widget.onTextTap?.call(local);
              return;
            }
            widget.controller.startDraw(local);
          },
          onPointerMove: (e) {
            final local = _localPosition(e.position);
            if (local == null) return;
            if (widget.controller.tool == AnnotationTool.select && _dragSelectionStarted && widget.controller.hasSelection) {
              widget.controller.moveSelectedBy(local);
              return;
            }
            widget.controller.updateDraw(local);
          },
          onPointerUp: (e) {
            _dragSelectionStarted = false;
            final local = _localPosition(e.position);
            if (local != null) widget.controller.endDraw(local);
          },
          onPointerCancel: (_) {
            _dragSelectionStarted = false;
            widget.controller.endDraw(Offset.zero);
          },
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            panEnabled: isPanMode,
            scaleEnabled: true,
            child: LayoutBuilder(
              builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;
              if (w <= 0 || h <= 0) return const SizedBox.shrink();

              // Resolver dimensões da imagem uma vez (para aspect ratio igual ao original na exportação)
              _resolveImageSize();

              double contentW = w;
              double contentH = h;
              if (_imageSize != null && _imageSize!.width > 0 && _imageSize!.height > 0) {
                final scaleW = w / _imageSize!.width;
                final scaleH = h / _imageSize!.height;
                final scaleUsed = scaleW < scaleH ? scaleW : scaleH;
                contentW = _imageSize!.width * scaleUsed;
                contentH = _imageSize!.height * scaleUsed;
              }

              return Center(
                child: RepaintBoundary(
                  key: widget.repaintBoundaryKey ?? GlobalKey(),
                  child: SizedBox(
                    key: _contentKey,
                    width: contentW,
                    height: contentH,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: widget.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const Center(
                            child: CircularProgressIndicator(),
                          ),
                          errorWidget: (_, __, ___) => const Icon(
                            Icons.broken_image_outlined,
                            size: 48,
                          ),
                        ),
                        ListenableBuilder(
                          listenable: widget.controller,
                          builder: (context, _) {
                            return CustomPaint(
                              size: Size(contentW, contentH),
                              painter: _AnnotationPainter(
                                items: widget.controller.items,
                                selectedIndex: widget.controller.selectedIndex,
                                currentPoints: widget.controller.currentStrokePoints,
                                arrowStart: widget.controller.arrowStart,
                                arrowEnd: widget.controller.currentArrowEnd,
                                currentColor: widget.controller.colorValue,
                                currentStrokeWidth: widget.controller.strokeWidth,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      },
    );
  }
}

class _AnnotationPainter extends CustomPainter {
  _AnnotationPainter({
    required this.items,
    this.selectedIndex,
    required this.currentPoints,
    this.arrowStart,
    this.arrowEnd,
    this.currentColor = 0xFF000000,
    this.currentStrokeWidth = 3,
  });

  final List<AnnotationItem> items;
  final int? selectedIndex;
  final List<Offset> currentPoints;
  final Offset? arrowStart;
  final Offset? arrowEnd;
  final int currentColor;
  final double currentStrokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < items.length; i++) {
      final selected = i == selectedIndex;
      _paintItem(canvas, items[i], selected: selected);
    }
    if (currentPoints.isNotEmpty) {
      _paintStroke(canvas, currentPoints, currentColor, currentStrokeWidth);
    }
    if (arrowStart != null && arrowEnd != null) {
      _paintArrow(canvas, arrowStart!, arrowEnd!, currentColor, currentStrokeWidth);
    }
  }

  void _paintItem(Canvas canvas, AnnotationItem item, {bool selected = false}) {
    if (item is StrokeAnnotation) {
      _paintStroke(canvas, item.points, item.colorValue, item.strokeWidth);
      if (selected) _paintSelectionStroke(canvas, item.points, item.strokeWidth);
      return;
    }
    if (item is ArrowAnnotation) {
      _paintArrow(canvas, item.start, item.end, item.colorValue, item.strokeWidth);
      if (selected) _paintSelectionArrow(canvas, item.start, item.end);
      return;
    }
    if (item is PolygonAnnotation) {
      _paintPolygon(
        canvas,
        item.points,
        item.closed,
        item.colorValue,
        item.strokeWidth,
        item.fillColorValue,
      );
      if (selected) _paintSelectionPolygon(canvas, item.points, item.closed);
      return;
    }
    if (item is TextAnnotation) {
      _paintText(
        canvas,
        item.text,
        item.position,
        item.fontSize,
        item.textColorValue,
      );
      if (selected) _paintSelectionText(canvas, item.text, item.position, item.fontSize);
      return;
    }
  }

  /// Destaque de seleção com traço fino fixo para não alterar tamanho aparente ao desmarcar.
  static const double _selectionStrokeWidth = 2;

  void _paintSelectionStroke(Canvas canvas, List<Offset> points, double strokeWidth) {
    if (points.length < 2) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) path.lineTo(points[i].dx, points[i].dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF2196F3).withOpacity(0.6)
        ..strokeWidth = _selectionStrokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _paintSelectionArrow(Canvas canvas, Offset start, Offset end) {
    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = const Color(0xFF2196F3).withOpacity(0.6)
        ..strokeWidth = _selectionStrokeWidth
        ..style = PaintingStyle.stroke,
    );
  }

  void _paintSelectionPolygon(Canvas canvas, List<Offset> points, bool closed) {
    if (points.isEmpty) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) path.lineTo(points[i].dx, points[i].dy);
    if (closed && points.length > 2) path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF2196F3).withOpacity(0.5)
        ..strokeWidth = _selectionStrokeWidth
        ..style = PaintingStyle.stroke,
    );
  }

  void _paintSelectionText(Canvas canvas, String text, Offset position, double fontSize) {
    final span = TextSpan(
      text: text,
      style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w500),
    );
    final tp = TextPainter(text: span, textDirection: TextDirection.ltr)..layout();
    final r = Rect.fromLTWH(position.dx - 4, position.dy - 2, tp.width + 8, tp.height + 4);
    canvas.drawRect(
      r,
      Paint()
        ..color = const Color(0xFF2196F3).withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _paintStroke(
    Canvas canvas,
    List<Offset> points,
    int colorValue,
    double width,
  ) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = Color(colorValue)
      ..strokeWidth = width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  void _paintArrow(
    Canvas canvas,
    Offset start,
    Offset end,
    int colorValue,
    double width,
  ) {
    final paint = Paint()
      ..color = Color(colorValue)
      ..strokeWidth = width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(start, end, paint);
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final len = sqrt(dx * dx + dy * dy);
    if (len < 1) return;
    final ux = dx / len;
    final uy = dy / len;
    const arrowLen = 12.0;
    final a1 = Offset(
      end.dx - arrowLen * ux + arrowLen * 0.5 * (-uy),
      end.dy - arrowLen * uy + arrowLen * 0.5 * ux,
    );
    final a2 = Offset(
      end.dx - arrowLen * ux - arrowLen * 0.5 * (-uy),
      end.dy - arrowLen * uy - arrowLen * 0.5 * ux,
    );
    canvas.drawLine(end, a1, paint);
    canvas.drawLine(end, a2, paint);
  }

  void _paintPolygon(
    Canvas canvas,
    List<Offset> points,
    bool closed,
    int strokeColor,
    double strokeWidth,
    int? fillColor,
  ) {
    if (points.isEmpty) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    if (closed && points.length > 2) path.close();
    if (fillColor != null && closed && points.length > 2) {
      canvas.drawPath(
        path,
        Paint()..color = Color(fillColor).withOpacity(0.3),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = Color(strokeColor)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset position,
    double fontSize,
    int colorValue,
  ) {
    final span = TextSpan(
      text: text,
      style: TextStyle(
        color: Color(colorValue),
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
      ),
    );
    final tp = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, position);
  }

  @override
  bool shouldRepaint(covariant _AnnotationPainter oldDelegate) {
    return oldDelegate.items != items ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.currentPoints != currentPoints ||
        oldDelegate.arrowStart != arrowStart ||
        oldDelegate.arrowEnd != arrowEnd ||
        oldDelegate.currentColor != currentColor ||
        oldDelegate.currentStrokeWidth != currentStrokeWidth;
  }
}
