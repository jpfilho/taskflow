class Funcao {
  final String id;
  final String funcao;
  final String? descricao;
  final bool ativo;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Funcao({
    required this.id,
    required this.funcao,
    this.descricao,
    this.ativo = true,
    this.createdAt,
    this.updatedAt,
  });

  // Método para criar cópia com alterações
  Funcao copyWith({
    String? id,
    String? funcao,
    String? descricao,
    bool? ativo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Funcao(
      id: id ?? this.id,
      funcao: funcao ?? this.funcao,
      descricao: descricao ?? this.descricao,
      ativo: ativo ?? this.ativo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Converter para Map (para Supabase)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'funcao': funcao,
      'descricao': descricao,
      'ativo': ativo,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  // Criar a partir de Map (do Supabase)
  factory Funcao.fromMap(Map<String, dynamic> map) {
    return Funcao(
      id: map['id'] as String,
      funcao: map['funcao'] as String,
      descricao: map['descricao'] as String?,
      ativo: map['ativo'] as bool? ?? true,
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
    return 'Funcao(id: $id, funcao: $funcao, ativo: $ativo)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Funcao && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}







