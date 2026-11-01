import 'dart:convert';
import 'package:flutter/material.dart';

/// Tipo de elemento vetorial de anotação
enum NotaSapElementoTipo {
  rect('rect', 'Retângulo'),
  circle('circle', 'Círculo'),
  arrow('arrow', 'Seta'),
  text('text', 'Texto');

  final String value;
  final String label;

  const NotaSapElementoTipo(this.value, this.label);

  static NotaSapElementoTipo fromDbString(String? val) {
    if (val == null || val.trim().isEmpty) return NotaSapElementoTipo.rect;
    final normalized = val.trim().toLowerCase();
    for (final tipo in NotaSapElementoTipo.values) {
      if (tipo.value == normalized) return tipo;
    }
    return NotaSapElementoTipo.rect;
  }

  String toDbString() => value;
}

/// Elemento vetorial individual de uma anotação técnica
@immutable
class NotaSapAnotacaoElemento {
  final String id;
  final NotaSapElementoTipo type;
  final double x1;
  final double y1;
  final double? x2;
  final double? y2;
  final double strokeWidth;
  final String color;
  final String? label;
  final String? text;
  final double fontSize;
  final int zIndex;

  const NotaSapAnotacaoElemento({
    required this.id,
    required this.type,
    required this.x1,
    required this.y1,
    this.x2,
    this.y2,
    this.strokeWidth = 3.0,
    this.color = '#E53935',
    this.label,
    this.text,
    this.fontSize = 14.0,
    this.zIndex = 1,
  });

  /// Cor convertida em objeto [Color] do Flutter
  Color get colorValue {
    try {
      final hex = color.replaceAll('#', '').trim();
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      } else if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    } catch (_) {}
    return const Color(0xFFE53935);
  }

  /// Retorna o Rect normalizado (0.0 a 1.0) que delimita o elemento
  Rect get normalizedBoundingBox {
    final xEnd = x2 ?? x1;
    final yEnd = y2 ?? y1;
    final left = x1 < xEnd ? x1 : xEnd;
    final right = x1 < xEnd ? xEnd : x1;
    final top = y1 < yEnd ? y1 : yEnd;
    final bottom = y1 < yEnd ? yEnd : y1;
    return Rect.fromLTRB(left, top, right, bottom);
  }

  factory NotaSapAnotacaoElemento.fromMap(Map<String, dynamic> map) {
    return NotaSapAnotacaoElemento(
      id: map['id']?.toString() ?? '',
      type: NotaSapElementoTipo.fromDbString(map['type']?.toString()),
      x1: (map['x1'] as num?)?.toDouble() ?? 0.0,
      y1: (map['y1'] as num?)?.toDouble() ?? 0.0,
      x2: (map['x2'] as num?)?.toDouble(),
      y2: (map['y2'] as num?)?.toDouble(),
      strokeWidth: (map['strokeWidth'] as num?)?.toDouble() ?? 3.0,
      color: map['color']?.toString() ?? '#E53935',
      label: map['label']?.toString(),
      text: map['text']?.toString(),
      fontSize: (map['fontSize'] as num?)?.toDouble() ?? 14.0,
      zIndex: (map['zIndex'] as num?)?.toInt() ?? 1,
    );
  }

  factory NotaSapAnotacaoElemento.fromJson(String source) =>
      NotaSapAnotacaoElemento.fromMap(json.decode(source) as Map<String, dynamic>);

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id,
      'type': type.toDbString(),
      'x1': x1,
      'y1': y1,
      'strokeWidth': strokeWidth,
      'color': color,
      'zIndex': zIndex,
    };
    if (x2 != null) map['x2'] = x2;
    if (y2 != null) map['y2'] = y2;
    if (label != null) map['label'] = label;
    if (text != null) map['text'] = text;
    if (type == NotaSapElementoTipo.text || fontSize != 14.0) {
      map['fontSize'] = fontSize;
    }
    return map;
  }

  String toJson() => json.encode(toMap());

  NotaSapAnotacaoElemento copyWith({
    String? id,
    NotaSapElementoTipo? type,
    double? x1,
    double? y1,
    double? x2,
    double? y2,
    double? strokeWidth,
    String? color,
    String? label,
    String? text,
    double? fontSize,
    int? zIndex,
  }) {
    return NotaSapAnotacaoElemento(
      id: id ?? this.id,
      type: type ?? this.type,
      x1: x1 ?? this.x1,
      y1: y1 ?? this.y1,
      x2: x2 ?? this.x2,
      y2: y2 ?? this.y2,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      color: color ?? this.color,
      label: label ?? this.label,
      text: text ?? this.text,
      fontSize: fontSize ?? this.fontSize,
      zIndex: zIndex ?? this.zIndex,
    );
  }
}

/// Documento JSON estruturado contendo todos os elementos e viewport
@immutable
class NotaSapAnotacaoDocumento {
  final int version;
  final double canvasWidth;
  final double canvasHeight;
  final int rotationAngle;
  final Map<String, dynamic>? crop;
  final List<NotaSapAnotacaoElemento> elements;

  const NotaSapAnotacaoDocumento({
    this.version = 1,
    required this.canvasWidth,
    required this.canvasHeight,
    this.rotationAngle = 0,
    this.crop,
    this.elements = const [],
  });

  factory NotaSapAnotacaoDocumento.fromMap(Map<String, dynamic> map) {
    final rawElements = map['elements'];
    final List<NotaSapAnotacaoElemento> elementsList = [];
    if (rawElements is List) {
      for (final el in rawElements) {
        if (el is Map<String, dynamic>) {
          elementsList.add(NotaSapAnotacaoElemento.fromMap(el));
        } else if (el is Map) {
          elementsList.add(
            NotaSapAnotacaoElemento.fromMap(Map<String, dynamic>.from(el)),
          );
        }
      }
    }

    Map<String, dynamic>? parsedCrop;
    if (map['crop'] is Map) {
      parsedCrop = Map<String, dynamic>.from(map['crop'] as Map);
    }

    return NotaSapAnotacaoDocumento(
      version: (map['version'] as num?)?.toInt() ?? 1,
      canvasWidth: (map['canvasWidth'] as num?)?.toDouble() ?? 1920.0,
      canvasHeight: (map['canvasHeight'] as num?)?.toDouble() ?? 1080.0,
      rotationAngle: (map['rotationAngle'] as num?)?.toInt() ?? 0,
      crop: parsedCrop,
      elements: List.unmodifiable(elementsList),
    );
  }

  factory NotaSapAnotacaoDocumento.fromJson(String source) =>
      NotaSapAnotacaoDocumento.fromMap(
          json.decode(source) as Map<String, dynamic>);

  Map<String, dynamic> toMap() {
    return {
      'version': version,
      'canvasWidth': canvasWidth,
      'canvasHeight': canvasHeight,
      'rotationAngle': rotationAngle,
      'crop': crop,
      'elements': elements.map((e) => e.toMap()).toList(),
    };
  }

  String toJson() => json.encode(toMap());

  NotaSapAnotacaoDocumento copyWith({
    int? version,
    double? canvasWidth,
    double? canvasHeight,
    int? rotationAngle,
    Map<String, dynamic>? crop,
    List<NotaSapAnotacaoElemento>? elements,
  }) {
    return NotaSapAnotacaoDocumento(
      version: version ?? this.version,
      canvasWidth: canvasWidth ?? this.canvasWidth,
      canvasHeight: canvasHeight ?? this.canvasHeight,
      rotationAngle: rotationAngle ?? this.rotationAngle,
      crop: crop ?? this.crop,
      elements: elements != null ? List.unmodifiable(elements) : this.elements,
    );
  }
}

/// Registro persistido de uma versão de anotação (tabela public.notas_sap_anexos_anotacoes)
@immutable
class NotaSapAnotacao {
  final String? id;
  final String anexoId;
  final int versao;
  final NotaSapAnotacaoDocumento dadosJson;
  final int? imagemLargura;
  final int? imagemAltura;
  final String? criadoPor;
  final String? criadoPorNome;
  final DateTime? createdAt;

  const NotaSapAnotacao({
    this.id,
    required this.anexoId,
    required this.versao,
    required this.dadosJson,
    this.imagemLargura,
    this.imagemAltura,
    this.criadoPor,
    this.criadoPorNome,
    this.createdAt,
  });

  factory NotaSapAnotacao.fromMap(Map<String, dynamic> map) {
    NotaSapAnotacaoDocumento doc;
    final rawDados = map['dados_json'];
    if (rawDados is Map<String, dynamic>) {
      doc = NotaSapAnotacaoDocumento.fromMap(rawDados);
    } else if (rawDados is Map) {
      doc = NotaSapAnotacaoDocumento.fromMap(Map<String, dynamic>.from(rawDados));
    } else if (rawDados is String) {
      doc = NotaSapAnotacaoDocumento.fromJson(rawDados);
    } else {
      doc = const NotaSapAnotacaoDocumento(
        canvasWidth: 1920,
        canvasHeight: 1080,
      );
    }

    return NotaSapAnotacao(
      id: map['id']?.toString(),
      anexoId: map['anexo_id']?.toString() ?? '',
      versao: (map['versao'] as num?)?.toInt() ?? 1,
      dadosJson: doc,
      imagemLargura: (map['imagem_largura'] as num?)?.toInt(),
      imagemAltura: (map['imagem_altura'] as num?)?.toInt(),
      criadoPor: map['criado_por']?.toString(),
      criadoPorNome: map['criado_por_nome']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }

  factory NotaSapAnotacao.fromJson(String source) =>
      NotaSapAnotacao.fromMap(json.decode(source) as Map<String, dynamic>);

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'anexo_id': anexoId,
      'versao': versao,
      'dados_json': dadosJson.toMap(),
    };
    if (id != null) map['id'] = id;
    if (imagemLargura != null) map['imagem_largura'] = imagemLargura;
    if (imagemAltura != null) map['imagem_altura'] = imagemAltura;
    if (criadoPor != null) map['criado_por'] = criadoPor;
    if (criadoPorNome != null) map['criado_por_nome'] = criadoPorNome;
    if (createdAt != null) map['created_at'] = createdAt!.toIso8601String();
    return map;
  }

  String toJson() => json.encode(toMap());

  NotaSapAnotacao copyWith({
    String? id,
    String? anexoId,
    int? versao,
    NotaSapAnotacaoDocumento? dadosJson,
    int? imagemLargura,
    int? imagemAltura,
    String? criadoPor,
    String? criadoPorNome,
    DateTime? createdAt,
  }) {
    return NotaSapAnotacao(
      id: id ?? this.id,
      anexoId: anexoId ?? this.anexoId,
      versao: versao ?? this.versao,
      dadosJson: dadosJson ?? this.dadosJson,
      imagemLargura: imagemLargura ?? this.imagemLargura,
      imagemAltura: imagemAltura ?? this.imagemAltura,
      criadoPor: criadoPor ?? this.criadoPor,
      criadoPorNome: criadoPorNome ?? this.criadoPorNome,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
