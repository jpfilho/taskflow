class Local {
  final String id;
  final String local;
  final String? descricao;
  final String? localInstalacaoSap;
  final bool paraTodaRegional;
  final bool paraTodaDivisao;
  final String? regionalId;
  final String? divisaoId;
  final String? segmentoId;
  // Campos para exibição (carregados via join)
  final String regional; // Nome da regional
  final String divisao; // Nome da divisão
  final String segmento; // Nome do segmento
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Local({
    required this.id,
    required this.local,
    this.descricao,
    this.localInstalacaoSap,
    this.paraTodaRegional = false,
    this.paraTodaDivisao = false,
    this.regionalId,
    this.divisaoId,
    this.segmentoId,
    this.regional = '',
    this.divisao = '',
    this.segmento = '',
    this.createdAt,
    this.updatedAt,
  });

  // Método para criar cópia com alterações
  Local copyWith({
    String? id,
    String? local,
    String? descricao,
    String? localInstalacaoSap,
    bool? paraTodaRegional,
    bool? paraTodaDivisao,
    String? regionalId,
    String? divisaoId,
    String? segmentoId,
    String? regional,
    String? divisao,
    String? segmento,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Local(
      id: id ?? this.id,
      local: local ?? this.local,
      descricao: descricao ?? this.descricao,
      localInstalacaoSap: localInstalacaoSap ?? this.localInstalacaoSap,
      paraTodaRegional: paraTodaRegional ?? this.paraTodaRegional,
      paraTodaDivisao: paraTodaDivisao ?? this.paraTodaDivisao,
      regionalId: regionalId ?? this.regionalId,
      divisaoId: divisaoId ?? this.divisaoId,
      segmentoId: segmentoId ?? this.segmentoId,
      regional: regional ?? this.regional,
      divisao: divisao ?? this.divisao,
      segmento: segmento ?? this.segmento,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Converter para Map (para Supabase)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'local': local,
      'descricao': descricao,
      'local_instalacao_sap': localInstalacaoSap,
      'para_toda_regional': paraTodaRegional,
      'para_toda_divisao': paraTodaDivisao,
      'regional_id': regionalId,
      'divisao_id': divisaoId,
      'segmento_id': segmentoId,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  // Criar a partir de Map (do Supabase)
  factory Local.fromMap(Map<String, dynamic> map) {
    return Local(
      id: map['id'] as String,
      local: map['local'] as String,
      descricao: map['descricao'] as String?,
      localInstalacaoSap: map['local_instalacao_sap'] as String?,
      paraTodaRegional: map['para_toda_regional'] as bool? ?? false,
      paraTodaDivisao: map['para_toda_divisao'] as bool? ?? false,
      regionalId: map['regional_id'] as String?,
      divisaoId: map['divisao_id'] as String?,
      segmentoId: map['segmento_id'] as String?,
      regional: map['regionais'] != null 
          ? (map['regionais'] as Map<String, dynamic>)['regional'] as String? ?? ''
          : (map['regional'] as String? ?? ''),
      divisao: map['divisoes'] != null 
          ? (map['divisoes'] as Map<String, dynamic>)['divisao'] as String? ?? ''
          : (map['divisao'] as String? ?? ''),
      segmento: map['segmentos'] != null 
          ? (map['segmentos'] as Map<String, dynamic>)['segmento'] as String? ?? ''
          : (map['segmento'] as String? ?? ''),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  // Método auxiliar para obter descrição das associações
  String get associacoesDescricao {
    final partes = <String>[];
    if (paraTodaRegional) {
      partes.add('Toda Regional');
    }
    if (paraTodaDivisao) {
      partes.add('Toda Divisão');
    }
    if (regional.isNotEmpty) {
      partes.add('Regional: $regional');
    }
    if (divisao.isNotEmpty) {
      partes.add('Divisão: $divisao');
    }
    if (segmento.isNotEmpty) {
      partes.add('Segmento: $segmento');
    }
    return partes.isEmpty ? 'Sem associação' : partes.join(', ');
  }

  @override
  String toString() {
    return 'Local(id: $id, local: $local, associacoes: $associacoesDescricao)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Local && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}







