import 'package:flutter/material.dart';
import '../../data/models/annotation_models.dart' show
    AnnotationItem,
    ArrowAnnotation,
    PolygonAnnotation,
    StrokeAnnotation,
    TextAnnotation,
    annotationHitTest,
    annotationTranslate,
    annotationsToJson;
import '../../data/models/media_image.dart';
import '../../data/repositories/supabase_media_repository.dart';
import '../../util/path_builder.dart';

/// Ferramenta de anotação: pan, select (selecionar/mover/excluir), pencil, arrow, polygon, text.
enum AnnotationTool { pan, select, pencil, arrow, polygon, text }

/// Controller da anotação: ferramenta, cor, espessura, lista de shapes, undo/redo.
/// Carrega JSON ao abrir; save() serializa e persiste + opcional export PNG.
class AnnotationController extends ChangeNotifier {
  AnnotationController({
    required String mediaImageId,
    required SupabaseMediaRepository repository,
  })  : _mediaImageId = mediaImageId,
        _repository = repository;

  final String _mediaImageId;
  final SupabaseMediaRepository _repository;

  AnnotationTool _tool = AnnotationTool.pan;
  int _colorValue = 0xFF000000;
  double _strokeWidth = 3;
  double _fontSize = 16;
  final List<AnnotationItem> _items = [];
  final List<List<AnnotationItem>> _undoStack = [];
  final List<List<AnnotationItem>> _redoStack = [];
  bool _isPanMode = true;
  int? _selectedIndex;
  Offset? _dragStartPosition;
  bool _didPushUndoForMove = false;

  AnnotationTool get tool => _tool;
  int? get selectedIndex => _selectedIndex;
  bool get hasSelection => _selectedIndex != null && _selectedIndex! >= 0 && _selectedIndex! < _items.length;
  AnnotationItem? get selectedItem => hasSelection ? _items[_selectedIndex!] : null;
  bool get selectedIsText => selectedItem is TextAnnotation;
  int get colorValue => _colorValue;
  double get strokeWidth => _strokeWidth;
  double get fontSize => _fontSize;
  List<AnnotationItem> get items => List.unmodifiable(_items);
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  bool get isPanMode => _isPanMode;

  void setTool(AnnotationTool t) {
    if (_tool == t) return;
    _commitCurrentStroke();
    _clearSelection();
    _tool = t;
    _isPanMode = t == AnnotationTool.pan;
    notifyListeners();
  }

  void _clearSelection() {
    _selectedIndex = null;
    _dragStartPosition = null;
    _didPushUndoForMove = false;
  }

  void clearSelection() {
    _clearSelection();
    notifyListeners();
  }

  /// Tolerância em pixels para hit-test (toque/clique).
  static const double _hitTolerance = 12;

  /// Seleciona o item sob [local] (do último ao primeiro). Se nenhum hit, limpa seleção.
  void selectAt(Offset local) {
    for (var i = _items.length - 1; i >= 0; i--) {
      if (annotationHitTest(_items[i], local, _hitTolerance)) {
        _selectedIndex = i;
        _dragStartPosition = local;
        _syncFromSelectedItem();
        notifyListeners();
        return;
      }
    }
    _clearSelection();
    notifyListeners();
  }

  void _syncFromSelectedItem() {
    final item = selectedItem;
    if (item == null) return;
    _colorValue = item.colorValue;
    if (item is TextAnnotation) {
      _fontSize = item.fontSize;
    } else {
      _strokeWidth = item.strokeWidth;
    }
  }

  /// Move o item selecionado (delta desde o último drag start/update).
  void moveSelectedBy(Offset currentLocal) {
    if (_selectedIndex == null || _selectedIndex! >= _items.length || _dragStartPosition == null) return;
    final delta = currentLocal - _dragStartPosition!;
    if (delta.distance < 0.5) return;
    if (!_didPushUndoForMove) {
      _pushUndo();
      _didPushUndoForMove = true;
    }
    final item = _items[_selectedIndex!];
    _items[_selectedIndex!] = annotationTranslate(item, delta);
    _dragStartPosition = currentLocal;
    notifyListeners();
  }

  void deleteSelected() {
    if (_selectedIndex == null || _selectedIndex! >= _items.length) return;
    _pushUndo();
    _items.removeAt(_selectedIndex!);
    _clearSelection();
    notifyListeners();
  }

  void setColor(int value) {
    if (hasSelection) {
      _pushUndo();
      final item = _items[_selectedIndex!];
      if (item is StrokeAnnotation) {
        _items[_selectedIndex!] = item.withColor(value);
      } else if (item is ArrowAnnotation) _items[_selectedIndex!] = item.withColor(value);
      else if (item is PolygonAnnotation) _items[_selectedIndex!] = item.withColor(value);
      else if (item is TextAnnotation) _items[_selectedIndex!] = item.withColor(value);
    }
    _colorValue = value;
    notifyListeners();
  }

  void setStrokeWidth(double value) {
    final w = value.clamp(1.0, 20.0);
    if (hasSelection) {
      final item = selectedItem;
      if (item is StrokeAnnotation || item is ArrowAnnotation || item is PolygonAnnotation) {
        _pushUndo();
        if (item is StrokeAnnotation) {
          _items[_selectedIndex!] = item.withStrokeWidth(w);
        } else if (item is ArrowAnnotation) _items[_selectedIndex!] = item.withStrokeWidth(w);
        else if (item is PolygonAnnotation) _items[_selectedIndex!] = item.withStrokeWidth(w);
      }
    }
    _strokeWidth = w;
    notifyListeners();
  }

  void setFontSize(double value) {
    final fs = value.clamp(8.0, 48.0);
    if (hasSelection && selectedItem is TextAnnotation) {
      _pushUndo();
      final item = _items[_selectedIndex!] as TextAnnotation;
      _items[_selectedIndex!] = item.withFontSize(fs);
    }
    _fontSize = fs;
    notifyListeners();
  }

  /// Altera o texto do item selecionado (só para TextAnnotation).
  void updateSelectedText(String text) {
    if (!hasSelection || selectedItem is! TextAnnotation) return;
    _pushUndo();
    final item = _items[_selectedIndex!] as TextAnnotation;
    _items[_selectedIndex!] = item.withText(text.trim().isEmpty ? item.text : text.trim());
    notifyListeners();
  }

  void undo() {
    _commitCurrentStroke();
    if (_undoStack.isEmpty) return;
    _redoStack.add(_copyItems());
    _items
      ..clear()
      ..addAll(_undoStack.removeLast());
    notifyListeners();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_copyItems());
    _items
      ..clear()
      ..addAll(_redoStack.removeLast());
    notifyListeners();
  }

  void clear() {
    _commitCurrentStroke();
    if (_items.isEmpty) return;
    _undoStack.add(_copyItems());
    _items.clear();
    notifyListeners();
  }

  List<AnnotationItem> _copyItems() {
    return _items.map((e) => _cloneItem(e)).toList();
  }

  AnnotationItem _cloneItem(AnnotationItem e) {
    if (e is StrokeAnnotation) {
      return StrokeAnnotation(
        colorValue: e.colorValue,
        strokeWidth: e.strokeWidth,
        points: List.from(e.points),
      );
    }
    if (e is ArrowAnnotation) {
      return ArrowAnnotation(
        colorValue: e.colorValue,
        strokeWidth: e.strokeWidth,
        start: e.start,
        end: e.end,
      );
    }
    if (e is PolygonAnnotation) {
      return PolygonAnnotation(
        colorValue: e.colorValue,
        strokeWidth: e.strokeWidth,
        points: List.from(e.points),
        closed: e.closed,
        fillColorValue: e.fillColorValue,
      );
    }
    if (e is TextAnnotation) {
      return TextAnnotation(
        text: e.text,
        position: e.position,
        fontSize: e.fontSize,
        textColorValue: e.textColorValue,
      );
    }
    throw StateError('Unknown annotation type');
  }

  // --- Drawing state (current stroke / arrow / polygon in progress)
  List<Offset> _currentPoints = [];
  Offset? _arrowStart;
  Offset? _currentArrowEnd;

  void _pushUndo() {
    _undoStack.add(_copyItems());
    _redoStack.clear();
  }

  void _commitCurrentStroke() {
    if (_currentPoints.length >= 2) {
      _pushUndo();
      _items.add(StrokeAnnotation(
        colorValue: _colorValue,
        strokeWidth: _strokeWidth,
        points: List.from(_currentPoints),
      ));
    }
    _currentPoints = [];
    _arrowStart = null;
  }

  void startDraw(Offset local) {
    if (_tool == AnnotationTool.pan) return;
    if (_tool == AnnotationTool.pencil) {
      _currentPoints = [local];
      notifyListeners();
      return;
    }
    if (_tool == AnnotationTool.arrow) {
      _arrowStart = local;
      notifyListeners();
      return;
    }
    if (_tool == AnnotationTool.polygon) {
      final last = _items.isNotEmpty ? _items.last : null;
      if (last is PolygonAnnotation && !last.closed) {
        _items[_items.length - 1] = PolygonAnnotation(
          colorValue: last.colorValue,
          strokeWidth: last.strokeWidth,
          points: [...last.points, local],
          closed: false,
          fillColorValue: last.fillColorValue,
        );
      } else {
        _pushUndo();
        _items.add(PolygonAnnotation(
          colorValue: _colorValue,
          strokeWidth: _strokeWidth,
          points: [local],
          closed: false,
        ));
      }
      notifyListeners();
      return;
    }
  }

  void updateDraw(Offset local) {
    if (_tool == AnnotationTool.pencil && _currentPoints.isNotEmpty) {
      _currentPoints.add(local);
      notifyListeners();
      return;
    }
    if (_tool == AnnotationTool.arrow && _arrowStart != null) {
      _currentArrowEnd = local;
      notifyListeners();
      return;
    }
  }

  void endDraw(Offset local) {
    if (_tool == AnnotationTool.pencil) {
      if (_currentPoints.length >= 2) {
        _pushUndo();
        _items.add(StrokeAnnotation(
          colorValue: _colorValue,
          strokeWidth: _strokeWidth,
          points: List.from(_currentPoints),
        ));
      }
      _currentPoints = [];
      notifyListeners();
      return;
    }
    if (_tool == AnnotationTool.arrow && _arrowStart != null) {
      _pushUndo();
      _items.add(ArrowAnnotation(
        colorValue: _colorValue,
        strokeWidth: _strokeWidth,
        start: _arrowStart!,
        end: local,
      ));
      _arrowStart = null;
      _currentArrowEnd = null;
      notifyListeners();
      return;
    }
  }

  void addPolygonPoint(Offset local) {
    if (_tool != AnnotationTool.polygon || _items.isEmpty) return;
    final last = _items.last;
    if (last is PolygonAnnotation && !last.closed) {
      _items[_items.length - 1] = PolygonAnnotation(
        colorValue: last.colorValue,
        strokeWidth: last.strokeWidth,
        points: [...last.points, local],
        closed: false,
        fillColorValue: last.fillColorValue,
      );
      notifyListeners();
    }
  }

  void undoLastPolygonPoint() {
    if (_items.isEmpty) return;
    final last = _items.last;
    if (last is PolygonAnnotation && !last.closed && last.points.length > 1) {
      final pts = List<Offset>.from(last.points)..removeLast();
      _items[_items.length - 1] = PolygonAnnotation(
        colorValue: last.colorValue,
        strokeWidth: last.strokeWidth,
        points: pts,
        closed: false,
        fillColorValue: last.fillColorValue,
      );
      notifyListeners();
    }
  }

  void closePolygon() {
    if (_items.isEmpty) return;
    final last = _items.last;
    if (last is PolygonAnnotation && !last.closed && last.points.length >= 2) {
      _items[_items.length - 1] = PolygonAnnotation(
        colorValue: last.colorValue,
        strokeWidth: last.strokeWidth,
        points: List.from(last.points),
        closed: true,
        fillColorValue: last.fillColorValue,
      );
      notifyListeners();
    }
  }

  void addTextAt(Offset position, String text) {
    if (text.trim().isEmpty) return;
    _pushUndo();
    _items.add(TextAnnotation(
      text: text.trim(),
      position: position,
      fontSize: _fontSize,
      textColorValue: _colorValue,
    ));
    notifyListeners();
  }

  /// Para o painter: stroke em progresso e seta em progresso
  List<Offset> get currentStrokePoints => List.unmodifiable(_currentPoints);
  Offset? get arrowStart => _arrowStart;
  Offset? get currentArrowEnd => _currentArrowEnd;

  /// Carrega anotações do backend
  Future<void> load() async {
    final list = await _repository.fetchAnnotation(_mediaImageId);
    _items
      ..clear()
      ..addAll(list);
    _undoStack.clear();
    _redoStack.clear();
    notifyListeners();
  }

  /// Salva JSON no backend; [exportPngBytes] opcional para upload do PNG.
  Future<void> save({
    Future<List<int>> Function()? exportPngBytes,
    MediaImage? mediaImageForPath,
  }) async {
    _commitCurrentStroke();
    final json = annotationsToJson(_items);
    await _repository.upsertAnnotation(_mediaImageId, json);

    if (exportPngBytes != null && mediaImageForPath != null) {
      final bytes = await exportPngBytes();
      final path = PathBuilder.buildAnnotatedPngPath(
        userId: mediaImageForPath.createdBy,
        mediaImageId: _mediaImageId,
        segmentId: mediaImageForPath.segmentId,
        equipmentId: mediaImageForPath.equipmentId,
        roomId: mediaImageForPath.roomId,
      );
      await _repository.uploadAnnotatedPng(path: path, bytes: bytes);
      final now = DateTime.now();
      await _repository.updateMediaImageAnnotatedPath(
        _mediaImageId,
        path,
        now,
      );
    }
    notifyListeners();
  }

  /// Retorna JSON para persistência (sem export PNG)
  List<Map<String, dynamic>> toJson() => annotationsToJson(_items);
}
