class RegraPrazoNota {
  final String id;
  final String prioridade; // Alta, Baixa, Emergência, Média, Monitoramento, Por Oportunidade, Urgência
  final int diasPrazo; // Quantidade de dias para conclusão
  final String dataReferencia; // 'criacao' ou 'inicio_desejado'
  final List<String> segmentoIds; // Lista de IDs de segmentos. Se vazia = todos os segmentos
  final bool ativo; // Se a regra está ativa
  final String? descricao; // Descrição opcional
  final DateTime? createdAt;
  final DateTime? updatedAt;

  RegraPrazoNota({
    required this.id,
    required this.prioridade,
    required this.diasPrazo,
    required this.dataReferencia,
    this.segmentoIds = const [],
    this.ativo = true,
    this.descricao,
    this.createdAt,
    this.updatedAt,
  });

  // Método para criar cópia com alterações
  RegraPrazoNota copyWith({
    String? id,
    String? prioridade,
    int? diasPrazo,
    String? dataReferencia,
    List<String>? segmentoIds,
    bool? ativo,
    String? descricao,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RegraPrazoNota(
      id: id ?? this.id,
      prioridade: prioridade ?? this.prioridade,
      diasPrazo: diasPrazo ?? this.diasPrazo,
      dataReferencia: dataReferencia ?? this.dataReferencia,
      segmentoIds: segmentoIds ?? this.segmentoIds,
      ativo: ativo ?? this.ativo,
      descricao: descricao ?? this.descricao,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Converter para Map (para Supabase)
  // Nota: segmentoIds não é incluído aqui, pois é gerenciado via tabela de junção
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'prioridade': prioridade,
      'dias_prazo': diasPrazo,
      'data_referencia': dataReferencia,
      'ativo': ativo,
      'descricao': descricao,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  // Criar a partir de Map (do Supabase)
  // Nota: segmentoIds deve ser carregado separadamente via tabela de junção
  factory RegraPrazoNota.fromMap(Map<String, dynamic> map, {List<String> segmentoIds = const []}) {
    return RegraPrazoNota(
      id: map['id'] as String,
      prioridade: map['prioridade'] as String,
      diasPrazo: map['dias_prazo'] as int,
      dataReferencia: map['data_referencia'] as String,
      segmentoIds: segmentoIds,
      ativo: map['ativo'] as bool? ?? true,
      descricao: map['descricao'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  // Obter label amigável para data_referencia
  String get dataReferenciaLabel {
    switch (dataReferencia) {
      case 'criacao':
        return 'Data de Criação';
      case 'inicio_desejado':
        return 'Início da Avaria';
      default:
        return dataReferencia;
    }
  }

  @override
  String toString() {
    return 'RegraPrazoNota(id: $id, prioridade: $prioridade, diasPrazo: $diasPrazo, dataReferencia: $dataReferencia, ativo: $ativo)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RegraPrazoNota && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
