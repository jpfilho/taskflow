class CentroTrabalho {
  final String id;
  final String centroTrabalho; // Nome do centro de trabalho
  final String? descricao;
  final String regionalId; // ID da regional (obrigatório)
  final String? regional; // Nome da regional (carregado via join)
  final String divisaoId; // ID da divisão (obrigatório)
  final String? divisao; // Nome da divisão (carregado via join)
  final String segmentoId; // ID do segmento (obrigatório)
  final String? segmento; // Nome do segmento (carregado via join)
  final int? gpm; // GPM (numérico)
  final bool ativo;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CentroTrabalho({
    required this.id,
    required this.centroTrabalho,
    this.descricao,
    required this.regionalId,
    this.regional,
    required this.divisaoId,
    this.divisao,
    required this.segmentoId,
    this.segmento,
    this.gpm,
    this.ativo = true,
    this.createdAt,
    this.updatedAt,
  });

  // Método para criar cópia com alterações
  CentroTrabalho copyWith({
    String? id,
    String? centroTrabalho,
    String? descricao,
    String? regionalId,
    String? regional,
    String? divisaoId,
    String? divisao,
    String? segmentoId,
    String? segmento,
    int? gpm,
    bool? ativo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CentroTrabalho(
      id: id ?? this.id,
      centroTrabalho: centroTrabalho ?? this.centroTrabalho,
      descricao: descricao ?? this.descricao,
      regionalId: regionalId ?? this.regionalId,
      regional: regional ?? this.regional,
      divisaoId: divisaoId ?? this.divisaoId,
      divisao: divisao ?? this.divisao,
      segmentoId: segmentoId ?? this.segmentoId,
      segmento: segmento ?? this.segmento,
      gpm: gpm ?? this.gpm,
      ativo: ativo ?? this.ativo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Converter para Map (para Supabase)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'centro_trabalho': centroTrabalho,
      'descricao': descricao,
      'regional_id': regionalId,
      'divisao_id': divisaoId,
      'segmento_id': segmentoId,
      'gpm': gpm,
      'ativo': ativo,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  // Criar a partir de Map (do Supabase)
  factory CentroTrabalho.fromMap(Map<String, dynamic> map) {
    // Extrair dados de relacionamentos (joins)
    String? regionalNome;
    String? divisaoNome;
    String? segmentoNome;

    if (map['regionais'] != null) {
      final regionalData = map['regionais'] as Map<String, dynamic>?;
      regionalNome = regionalData?['regional'] as String?;
    } else if (map['regional'] != null) {
      regionalNome = map['regional'] as String?;
    }

    if (map['divisoes'] != null) {
      final divisaoData = map['divisoes'] as Map<String, dynamic>?;
      divisaoNome = divisaoData?['divisao'] as String?;
    } else if (map['divisao'] != null) {
      divisaoNome = map['divisao'] as String?;
    }

    if (map['segmentos'] != null) {
      final segmentoData = map['segmentos'] as Map<String, dynamic>?;
      segmentoNome = segmentoData?['segmento'] as String?;
    } else if (map['segmento'] != null) {
      segmentoNome = map['segmento'] as String?;
    }

    return CentroTrabalho(
      id: map['id'] as String,
      centroTrabalho: map['centro_trabalho'] as String,
      descricao: map['descricao'] as String?,
      regionalId: map['regional_id'] as String? ?? 
                  (map['regionais'] != null ? (map['regionais'] as Map<String, dynamic>)['id'] as String : ''),
      regional: regionalNome ?? '',
      divisaoId: map['divisao_id'] as String? ?? 
                 (map['divisoes'] != null ? (map['divisoes'] as Map<String, dynamic>)['id'] as String : ''),
      divisao: divisaoNome ?? '',
      segmentoId: map['segmento_id'] as String? ?? 
                  (map['segmentos'] != null ? (map['segmentos'] as Map<String, dynamic>)['id'] as String : ''),
      segmento: segmentoNome ?? '',
      gpm: map['gpm'] != null ? (map['gpm'] is int ? map['gpm'] as int : int.tryParse(map['gpm'].toString())) : null,
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
    return 'CentroTrabalho(id: $id, centroTrabalho: $centroTrabalho, regional: $regional, divisao: $divisao, segmento: $segmento)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CentroTrabalho && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
