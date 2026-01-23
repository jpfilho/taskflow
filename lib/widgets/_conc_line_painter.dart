import 'package:flutter/material.dart';

/// Linha para valores de CONC sobreposta às barras CRSI.
class ConcLinePainter extends CustomPainter {
  final List<int> counts;
  final double maxValue;
  final double bottomPadding;
  final double barMaxHeight;
  final double step;
  final Color color;

  ConcLinePainter({
    required this.counts,
    required this.maxValue,
    required this.bottomPadding,
    required this.barMaxHeight,
    required this.step,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (counts.isEmpty || maxValue <= 0) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final points = <Offset>[];
    for (int i = 0; i < counts.length; i++) {
      final valor = counts[i].toDouble();
      final fator = (valor / maxValue).clamp(0, 1);
      final x = (step * i) + (step / 2);
      final y = size.height - bottomPadding - (barMaxHeight * fator);
      points.add(Offset(x, y));
    }

    if (points.length >= 2) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    // Marcadores
    final markerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (final p in points) {
      canvas.drawCircle(p, 4, markerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ConcLinePainter oldDelegate) {
    return oldDelegate.counts != counts || oldDelegate.maxValue != maxValue;
  }
}
