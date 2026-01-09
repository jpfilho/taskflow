class Regional {
  final String id;
  final String regional;
  final String divisao;
  final String empresa;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Regional({
    required this.id,
    required this.regional,
    required this.divisao,
    required this.empresa,
    this.createdAt,
    this.updatedAt,
  });

  // Método para criar cópia com alterações
  Regional copyWith({
    String? id,
    String? regional,
    String? divisao,
    String? empresa,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Regional(
      id: id ?? this.id,
      regional: regional ?? this.regional,
      divisao: divisao ?? this.divisao,
      empresa: empresa ?? this.empresa,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Converter para Map (para Supabase)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'regional': regional,
      'divisao': divisao,
      'empresa': empresa,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  // Criar a partir de Map (do Supabase)
  factory Regional.fromMap(Map<String, dynamic> map) {
    return Regional(
      id: map['id'] as String,
      regional: map['regional'] as String,
      divisao: map['divisao'] as String,
      empresa: map['empresa'] as String,
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
    return 'Regional(id: $id, regional: $regional, divisao: $divisao, empresa: $empresa)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Regional && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}







