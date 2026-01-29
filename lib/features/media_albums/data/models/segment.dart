class Segment {
  final String id;
  final String name;
  final String? segmentoId; // ID do segmento do sistema (tabela segmentos)
  final DateTime createdAt;
  final DateTime updatedAt;

  Segment({
    required this.id,
    required this.name,
    this.segmentoId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Segment.fromMap(Map<String, dynamic> map) {
    return Segment(
      id: map['id'] as String,
      name: map['name'] as String,
      segmentoId: map['segmento_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'segmento_id': segmentoId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Segment copyWith({
    String? id,
    String? name,
    String? segmentoId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Segment(
      id: id ?? this.id,
      name: name ?? this.name,
      segmentoId: segmentoId ?? this.segmentoId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
