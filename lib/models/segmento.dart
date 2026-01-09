class Segmento {
  final String id;
  final String segmento;
  final String? descricao;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Segmento({
    required this.id,
    required this.segmento,
    this.descricao,
    this.createdAt,
    this.updatedAt,
  });

  // Método para criar cópia com alterações
  Segmento copyWith({
    String? id,
    String? segmento,
    String? descricao,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Segmento(
      id: id ?? this.id,
      segmento: segmento ?? this.segmento,
      descricao: descricao ?? this.descricao,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Converter para Map (para Supabase)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'segmento': segmento,
      'descricao': descricao,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  // Criar a partir de Map (do Supabase)
  factory Segmento.fromMap(Map<String, dynamic> map) {
    return Segmento(
      id: map['id'] as String,
      segmento: map['segmento'] as String,
      descricao: map['descricao'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  @override
  String toString() {
    return 'Segmento(id: $id, segmento: $segmento)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Segmento && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}







