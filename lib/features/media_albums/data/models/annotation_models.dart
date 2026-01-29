import 'dart:ui' show Offset, Rect;

import 'dart:math' show sqrt;

/// Schema JSON das anotações: array de objetos com "type" e campos específicos.
/// Onde o schema é definido: este arquivo (toJson/fromJson).
/// Para estender ferramentas: (1) adicione um tipo em AnnotationType e um case em
/// [AnnotationItem.fromJson]; (2) crie a classe do modelo com toJson/fromJson;
/// (3) desenhe em AnnotationCanvas _AnnotationPainter e gestos no controller.
/// Tipos atuais: stroke, arrow, polygon, text.

enum AnnotationType { stroke, arrow, polygon, text }

/// Um item de anotação (stroke, arrow, polygon ou text).
abstract class AnnotationItem {
  String get typeKey;
  int get colorValue;
  double get strokeWidth;

  Map<String, dynamic> toJson();
  static AnnotationItem? fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    if (type == null) return null;
    switch (type) {
      case 'stroke':
        return StrokeAnnotation.fromJson(json);
      case 'arrow':
        return ArrowAnnotation.fromJson(json);
      case 'polygon':
        return PolygonAnnotation.fromJson(json);
      case 'text':
        return TextAnnotation.fromJson(json);
      default:
        return null;
    }
  }
}

/// Lista de pontos em coordenadas normalizadas (0..1) ou em pixels; usamos pixels
/// para simplificar (mesmo tamanho de tela ao carregar).
class StrokeAnnotation implements AnnotationItem {
  @override
  String get typeKey => 'stroke';
  @override
  final int colorValue;
  @override
  final double strokeWidth;
  final List<Offset> points;

  StrokeAnnotation({
    required this.colorValue,
    required this.strokeWidth,
    required this.points,
  });

  static List<Offset> _parsePoints(dynamic list) {
    if (list is! List) return [];
    final out = <Offset>[];
    for (final e in list) {
      if (e is Map) {
        final x = (e['x'] as num?)?.toDouble();
        final y = (e['y'] as num?)?.toDouble();
        if (x != null && y != null) out.add(Offset(x, y));
      }
    }
    return out;
  }

  factory StrokeAnnotation.fromJson(Map<String, dynamic> json) {
    return StrokeAnnotation(
      colorValue: json['color'] as int? ?? 0xFF000000,
      strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 3,
      points: _parsePoints(json['points']),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': typeKey,
        'color': colorValue,
        'strokeWidth': strokeWidth,
        'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
      };

  StrokeAnnotation translate(Offset delta) => StrokeAnnotation(
        colorValue: colorValue,
        strokeWidth: strokeWidth,
        points: points.map((p) => p + delta).toList(),
      );

  StrokeAnnotation withColor(int c) => StrokeAnnotation(
        colorValue: c,
        strokeWidth: strokeWidth,
        points: points,
      );
  StrokeAnnotation withStrokeWidth(double w) => StrokeAnnotation(
        colorValue: colorValue,
        strokeWidth: w,
        points: points,
      );
}

class ArrowAnnotation implements AnnotationItem {
  @override
  String get typeKey => 'arrow';
  @override
  final int colorValue;
  @override
  final double strokeWidth;
  final Offset start;
  final Offset end;

  ArrowAnnotation({
    required this.colorValue,
    required this.strokeWidth,
    required this.start,
    required this.end,
  });

  factory ArrowAnnotation.fromJson(Map<String, dynamic> json) {
    final s = json['start'] as Map<String, dynamic>?;
    final e = json['end'] as Map<String, dynamic>?;
    return ArrowAnnotation(
      colorValue: json['color'] as int? ?? 0xFF000000,
      strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 3,
      start: s != null
          ? Offset((s['x'] as num).toDouble(), (s['y'] as num).toDouble())
          : Offset.zero,
      end: e != null
          ? Offset((e['x'] as num).toDouble(), (e['y'] as num).toDouble())
          : Offset.zero,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': typeKey,
        'color': colorValue,
        'strokeWidth': strokeWidth,
        'start': {'x': start.dx, 'y': start.dy},
        'end': {'x': end.dx, 'y': end.dy},
      };

  ArrowAnnotation translate(Offset delta) => ArrowAnnotation(
        colorValue: colorValue,
        strokeWidth: strokeWidth,
        start: start + delta,
        end: end + delta,
      );

  ArrowAnnotation withColor(int c) => ArrowAnnotation(
        colorValue: c,
        strokeWidth: strokeWidth,
        start: start,
        end: end,
      );
  ArrowAnnotation withStrokeWidth(double w) => ArrowAnnotation(
        colorValue: colorValue,
        strokeWidth: w,
        start: start,
        end: end,
      );
}

class PolygonAnnotation implements AnnotationItem {
  @override
  String get typeKey => 'polygon';
  @override
  final int colorValue;
  @override
  final double strokeWidth;
  final List<Offset> points;
  final bool closed;
  final int? fillColorValue;

  PolygonAnnotation({
    required this.colorValue,
    required this.strokeWidth,
    required this.points,
    this.closed = true,
    this.fillColorValue,
  });

  factory PolygonAnnotation.fromJson(Map<String, dynamic> json) {
    return PolygonAnnotation(
      colorValue: json['color'] as int? ?? 0xFF000000,
      strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 3,
      points: StrokeAnnotation._parsePoints(json['points']),
      closed: json['closed'] as bool? ?? true,
      fillColorValue: json['fillColor'] as int?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': typeKey,
        'color': colorValue,
        'strokeWidth': strokeWidth,
        'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
        'closed': closed,
        if (fillColorValue != null) 'fillColor': fillColorValue,
      };

  PolygonAnnotation translate(Offset delta) => PolygonAnnotation(
        colorValue: colorValue,
        strokeWidth: strokeWidth,
        points: points.map((p) => p + delta).toList(),
        closed: closed,
        fillColorValue: fillColorValue,
      );

  PolygonAnnotation withColor(int c) => PolygonAnnotation(
        colorValue: c,
        strokeWidth: strokeWidth,
        points: points,
        closed: closed,
        fillColorValue: fillColorValue,
      );
  PolygonAnnotation withStrokeWidth(double w) => PolygonAnnotation(
        colorValue: colorValue,
        strokeWidth: w,
        points: points,
        closed: closed,
        fillColorValue: fillColorValue,
      );
}

class TextAnnotation implements AnnotationItem {
  @override
  String get typeKey => 'text';
  @override
  int get colorValue => textColorValue;
  @override
  double get strokeWidth => 0;
  final String text;
  final Offset position;
  final double fontSize;
  final int textColorValue;

  TextAnnotation({
    required this.text,
    required this.position,
    this.fontSize = 16,
    this.textColorValue = 0xFF000000,
  });

  factory TextAnnotation.fromJson(Map<String, dynamic> json) {
    final p = json['position'] as Map<String, dynamic>?;
    return TextAnnotation(
      text: json['text'] as String? ?? '',
      position: p != null
          ? Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble())
          : Offset.zero,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16,
      textColorValue: json['color'] as int? ?? 0xFF000000,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': typeKey,
        'text': text,
        'position': {'x': position.dx, 'y': position.dy},
        'fontSize': fontSize,
        'color': textColorValue,
      };

  TextAnnotation translate(Offset delta) => TextAnnotation(
        text: text,
        position: position + delta,
        fontSize: fontSize,
        textColorValue: textColorValue,
      );

  TextAnnotation withColor(int c) => TextAnnotation(
        text: text,
        position: position,
        fontSize: fontSize,
        textColorValue: c,
      );
  TextAnnotation withFontSize(double fs) => TextAnnotation(
        text: text,
        position: position,
        fontSize: fs,
        textColorValue: textColorValue,
      );
  TextAnnotation withText(String t) => TextAnnotation(
        text: t,
        position: position,
        fontSize: fontSize,
        textColorValue: textColorValue,
      );
}

/// Hit-test: retorna true se [point] está sobre o item (dentro da tolerância).
bool annotationHitTest(AnnotationItem item, Offset point, double tolerance) {
  if (item is StrokeAnnotation) {
    if (item.points.isEmpty) return false;
    if (item.points.length == 1) {
      final d = (point - item.points.first).distance;
      return d <= tolerance + item.strokeWidth / 2;
    }
    for (var i = 0; i < item.points.length - 1; i++) {
      final a = item.points[i];
      final b = item.points[i + 1];
      final d = _distanceToSegment(point, a, b);
      if (d <= tolerance + item.strokeWidth / 2) return true;
    }
    return false;
  }
  if (item is ArrowAnnotation) {
    final d = _distanceToSegment(point, item.start, item.end);
    if (d <= tolerance + item.strokeWidth / 2) return true;
    final arrowLen = 12.0;
    final dx = item.end.dx - item.start.dx;
    final dy = item.end.dy - item.start.dy;
    final len = sqrt(dx * dx + dy * dy);
    if (len >= 1) {
      final ux = dx / len;
      final uy = dy / len;
      final tip = item.end;
      final d1 = (point - tip).distance;
      final d2 = (point - (tip - Offset(arrowLen * ux, arrowLen * uy))).distance;
      if (d1 <= tolerance + 8 || d2 <= tolerance + 8) return true;
    }
    return false;
  }
  if (item is PolygonAnnotation) {
    if (item.points.isEmpty) return false;
    if (item.points.length == 1) {
      return (point - item.points.first).distance <= tolerance + item.strokeWidth / 2;
    }
    for (var i = 0; i < item.points.length - 1; i++) {
      final d = _distanceToSegment(point, item.points[i], item.points[i + 1]);
      if (d <= tolerance + item.strokeWidth / 2) return true;
    }
    if (item.closed && item.points.length > 2) {
      final d = _distanceToSegment(point, item.points.last, item.points.first);
      if (d <= tolerance + item.strokeWidth / 2) return true;
    }
    if (item.closed && item.points.length >= 3 && _pointInPolygon(point, item.points)) return true;
    return false;
  }
  if (item is TextAnnotation) {
    final w = item.text.length * item.fontSize * 0.55;
    final h = item.fontSize * 1.2;
    final r = Rect.fromLTWH(item.position.dx, item.position.dy, w, h);
    return r.contains(point) ||
        (point.dx >= r.left - tolerance &&
            point.dx <= r.right + tolerance &&
            point.dy >= r.top - tolerance &&
            point.dy <= r.bottom + tolerance);
  }
  return false;
}

double _distanceToSegment(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final ap = p - a;
  final abLen = sqrt(ab.dx * ab.dx + ab.dy * ab.dy);
  if (abLen < 1e-10) return ap.distance;
  final t = (ap.dx * ab.dx + ap.dy * ab.dy) / (abLen * abLen).clamp(0.0, 1.0);
  final proj = a + Offset(ab.dx * t, ab.dy * t);
  return (p - proj).distance;
}

bool _pointInPolygon(Offset p, List<Offset> points) {
  var inside = false;
  final n = points.length;
  for (var i = 0, j = n - 1; i < n; j = i++) {
    if (((points[i].dy > p.dy) != (points[j].dy > p.dy)) &&
        (p.dx < (points[j].dx - points[i].dx) * (p.dy - points[i].dy) / (points[j].dy - points[i].dy) + points[i].dx)) {
      inside = !inside;
    }
  }
  return inside;
}

/// Retorna cópia do item transladada por [delta].
AnnotationItem annotationTranslate(AnnotationItem item, Offset delta) {
  if (item is StrokeAnnotation) return item.translate(delta);
  if (item is ArrowAnnotation) return item.translate(delta);
  if (item is PolygonAnnotation) return item.translate(delta);
  if (item is TextAnnotation) return item.translate(delta);
  return item;
}

/// Converte lista de anotações para JSONB (array).
List<Map<String, dynamic>> annotationsToJson(List<AnnotationItem> items) {
  return items.map((e) => e.toJson()).toList();
}

/// Converte JSONB array para lista de anotações.
List<AnnotationItem> annotationsFromJson(dynamic value) {
  if (value == null) return [];
  if (value is! List) return [];
  final out = <AnnotationItem>[];
  for (final e in value) {
    if (e is Map<String, dynamic>) {
      final item = AnnotationItem.fromJson(e);
      if (item != null) out.add(item);
    }
  }
  return out;
}
