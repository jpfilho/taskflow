class Empresa {
  final String id;
  final String empresa;
  final String regionalId; // ID da regional associada
  final String regional; // Nome da regional (para exibição)
  final String divisaoId; // ID da divisão associada
  final String divisao; // Nome da divisão (para exibição)
  final String tipo; // 'PROPRIA' ou 'TERCEIRA'
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Empresa({
    required this.id,
    required this.empresa,
    required this.regionalId,
    this.regional = '',
    required this.divisaoId,
    this.divisao = '',
    required this.tipo,
    this.createdAt,
    this.updatedAt,
  });

  // Método para criar cópia com alterações
  Empresa copyWith({
    String? id,
    String? empresa,
    String? regionalId,
    String? regional,
    String? divisaoId,
    String? divisao,
    String? tipo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Empresa(
      id: id ?? this.id,
      empresa: empresa ?? this.empresa,
      regionalId: regionalId ?? this.regionalId,
      regional: regional ?? this.regional,
      divisaoId: divisaoId ?? this.divisaoId,
      divisao: divisao ?? this.divisao,
      tipo: tipo ?? this.tipo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Converter para Map (para Supabase)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'empresa': empresa,
      'regional_id': regionalId,
      'divisao_id': divisaoId,
      'tipo': tipo,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  // Criar a partir de Map (do Supabase)
  factory Empresa.fromMap(Map<String, dynamic> map) {
    // Extrair dados da regional (pode vir de join)
    String regionalNome = '';
    if (map['regionais'] != null) {
      final regionalData = map['regionais'];
      if (regionalData is Map<String, dynamic>) {
        regionalNome = regionalData['regional'] as String? ?? '';
      }
    }

    // Extrair dados da divisão (pode vir de join)
    String divisaoNome = '';
    if (map['divisoes'] != null) {
      final divisaoData = map['divisoes'];
      if (divisaoData is Map<String, dynamic>) {
        divisaoNome = divisaoData['divisao'] as String? ?? '';
      }
    }

    return Empresa(
      id: map['id'] as String,
      empresa: map['empresa'] as String,
      regionalId: map['regional_id'] as String,
      regional: regionalNome,
      divisaoId: map['divisao_id'] as String,
      divisao: divisaoNome,
      tipo: map['tipo'] as String,
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
    return 'Empresa(id: $id, empresa: $empresa, regional: $regional, divisao: $divisao, tipo: $tipo)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Empresa && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}







