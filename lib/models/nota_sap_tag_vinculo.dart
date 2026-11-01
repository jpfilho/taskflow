import 'nota_sap_tag.dart';

class NotaSapTagOrigem {
  static const String manual = 'MANUAL';
  static const String regra = 'REGRA';
  static const String sugestao = 'SUGESTAO';
  static const String ia = 'IA';
}

class NotaSapTagVinculo {
  final String id;
  final String notaSapId;
  final String tagId;
  final String origem; // 'MANUAL', 'REGRA', 'SUGESTAO', 'IA'
  final DateTime? createdAt;
  final String? createdBy;
  final NotaSapTag? tag; // Objeto de Tag quando associado via JOIN

  const NotaSapTagVinculo({
    required this.id,
    required this.notaSapId,
    required this.tagId,
    this.origem = NotaSapTagOrigem.manual,
    this.createdAt,
    this.createdBy,
    this.tag,
  });

  factory NotaSapTagVinculo.fromMap(Map<String, dynamic> map) {
    NotaSapTag? tagObj;
    if (map['notas_sap_tags'] != null && map['notas_sap_tags'] is Map) {
      tagObj = NotaSapTag.fromMap(map['notas_sap_tags'] as Map<String, dynamic>);
    } else if (map['tag'] != null && map['tag'] is Map) {
      tagObj = NotaSapTag.fromMap(map['tag'] as Map<String, dynamic>);
    }

    return NotaSapTagVinculo(
      id: map['id']?.toString() ?? '',
      notaSapId: map['nota_sap_id']?.toString() ?? '',
      tagId: map['tag_id']?.toString() ?? '',
      origem: (map['origem'] as String?)?.toUpperCase() ?? NotaSapTagOrigem.manual,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      createdBy: map['created_by']?.toString(),
      tag: tagObj,
    );
  }

  factory NotaSapTagVinculo.fromJson(Map<String, dynamic> json) => NotaSapTagVinculo.fromMap(json);
  Map<String, dynamic> toJson() => toMap();

  Map<String, dynamic> toMap({bool incluirId = true}) {
    final map = <String, dynamic>{
      'nota_sap_id': notaSapId,
      'tag_id': tagId,
      'origem': origem,
    };
    if (incluirId && id.isNotEmpty) {
      map['id'] = id;
    }
    if (createdBy != null) {
      map['created_by'] = createdBy;
    }
    return map;
  }

  NotaSapTagVinculo copyWith({
    String? id,
    String? notaSapId,
    String? tagId,
    String? origem,
    DateTime? createdAt,
    String? createdBy,
    NotaSapTag? tag,
  }) {
    return NotaSapTagVinculo(
      id: id ?? this.id,
      notaSapId: notaSapId ?? this.notaSapId,
      tagId: tagId ?? this.tagId,
      origem: origem ?? this.origem,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      tag: tag ?? this.tag,
    );
  }
}
