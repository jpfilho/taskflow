class Comunidade {
  final String? id;
  final String divisaoId; // ID da divisão
  final String divisaoNome; // Nome da divisão (para exibição)
  final String segmentoId; // ID do segmento
  final String segmentoNome; // Nome do segmento (para exibição)
  final String? descricao;
  final String? fotoUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? totalMensagens; // Contador de mensagens (para exibição)
  final DateTime? ultimaMensagemAt; // Data da última mensagem

  Comunidade({
    this.id,
    required this.divisaoId,
    required this.divisaoNome,
    required this.segmentoId,
    required this.segmentoNome,
    this.descricao,
    this.fotoUrl,
    this.createdAt,
    this.updatedAt,
    this.totalMensagens,
    this.ultimaMensagemAt,
  });

  factory Comunidade.fromMap(Map<String, dynamic> map) {
    return Comunidade(
      id: map['id'] as String?,
      divisaoId: map['divisao_id'] as String,
      divisaoNome: map['divisao_nome'] as String? ?? map['divisao_id'] as String,
      segmentoId: map['segmento_id'] as String,
      segmentoNome: map['segmento_nome'] as String? ?? map['segmento_id'] as String,
      descricao: map['descricao'] as String?,
      fotoUrl: map['foto_url'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
      totalMensagens: map['total_mensagens'] as int?,
      ultimaMensagemAt: map['ultima_mensagem_at'] != null
          ? DateTime.parse(map['ultima_mensagem_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'divisao_id': divisaoId,
      'divisao_nome': divisaoNome,
      'segmento_id': segmentoId,
      'segmento_nome': segmentoNome,
      'descricao': descricao,
      'foto_url': fotoUrl,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'total_mensagens': totalMensagens,
      'ultima_mensagem_at': ultimaMensagemAt?.toIso8601String(),
    };
  }
}

