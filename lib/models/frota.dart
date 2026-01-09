class Frota {
  final String id;
  final String nome;
  final String? marca;
  final String tipoVeiculo; // Ex: CARRO_LEVE, MUNCK, TRATOR, etc.
  final String placa;
  final String? regionalId;
  final String? regional; // Nome da regional (carregado via join)
  final String? divisaoId;
  final String? divisao; // Nome da divisão (carregado via join)
  final String? segmentoId;
  final String? segmento; // Nome do segmento (carregado via join)
  final bool emManutencao;
  final String? observacoes;
  final bool ativo;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Frota({
    required this.id,
    required this.nome,
    this.marca,
    required this.tipoVeiculo,
    required this.placa,
    this.regionalId,
    this.regional,
    this.divisaoId,
    this.divisao,
    this.segmentoId,
    this.segmento,
    this.emManutencao = false,
    this.observacoes,
    this.ativo = true,
    this.createdAt,
    this.updatedAt,
  });

  // Método para criar cópia com alterações
  Frota copyWith({
    String? id,
    String? nome,
    String? marca,
    String? tipoVeiculo,
    String? placa,
    String? regionalId,
    String? regional,
    String? divisaoId,
    String? divisao,
    String? segmentoId,
    String? segmento,
    bool? emManutencao,
    String? observacoes,
    bool? ativo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Frota(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      marca: marca ?? this.marca,
      tipoVeiculo: tipoVeiculo ?? this.tipoVeiculo,
      placa: placa ?? this.placa,
      regionalId: regionalId ?? this.regionalId,
      regional: regional ?? this.regional,
      divisaoId: divisaoId ?? this.divisaoId,
      divisao: divisao ?? this.divisao,
      segmentoId: segmentoId ?? this.segmentoId,
      segmento: segmento ?? this.segmento,
      emManutencao: emManutencao ?? this.emManutencao,
      observacoes: observacoes ?? this.observacoes,
      ativo: ativo ?? this.ativo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Converter para Map (para Supabase)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'marca': marca,
      'tipo_veiculo': tipoVeiculo,
      'placa': placa,
      'regional_id': regionalId,
      'divisao_id': divisaoId,
      'segmento_id': segmentoId,
      'em_manutencao': emManutencao,
      'observacoes': observacoes,
      'ativo': ativo,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // Criar a partir de Map (do Supabase)
  factory Frota.fromMap(Map<String, dynamic> map) {
    // Processar relacionamentos
    String? regionalNome;
    String? divisaoNome;
    String? segmentoNome;

    if (map['regionais'] != null) {
      if (map['regionais'] is Map) {
        regionalNome = map['regionais']['regional'] as String?;
      } else if (map['regionais'] is String) {
        regionalNome = map['regionais'] as String;
      }
    }

    if (map['divisoes'] != null) {
      if (map['divisoes'] is Map) {
        divisaoNome = map['divisoes']['divisao'] as String?;
      } else if (map['divisoes'] is String) {
        divisaoNome = map['divisoes'] as String;
      }
    }

    if (map['segmentos'] != null) {
      if (map['segmentos'] is Map) {
        segmentoNome = map['segmentos']['segmento'] as String?;
      } else if (map['segmentos'] is String) {
        segmentoNome = map['segmentos'] as String;
      }
    }

    return Frota(
      id: map['id'] as String,
      nome: map['nome'] as String,
      marca: map['marca'] as String?,
      tipoVeiculo: map['tipo_veiculo'] as String? ?? 'CARRO_LEVE',
      placa: map['placa'] as String,
      regionalId: map['regional_id'] as String?,
      regional: regionalNome ?? map['regional'] as String?,
      divisaoId: map['divisao_id'] as String?,
      divisao: divisaoNome ?? map['divisao'] as String?,
      segmentoId: map['segmento_id'] as String?,
      segmento: segmentoNome ?? map['segmento'] as String?,
      emManutencao: (map['em_manutencao'] as bool?) ?? false,
      observacoes: map['observacoes'] as String?,
      ativo: (map['ativo'] as bool?) ?? true,
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
    return 'Frota(id: $id, nome: $nome, tipoVeiculo: $tipoVeiculo, placa: $placa)';
  }
}
