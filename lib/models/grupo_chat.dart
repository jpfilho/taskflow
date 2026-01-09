class GrupoChat {
  final String? id;
  final String tarefaId; // ID da tarefa
  final String tarefaNome; // Nome da tarefa (para exibição)
  final String comunidadeId; // ID da comunidade (divisão)
  final String? descricao;
  final String? fotoUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? totalMensagens; // Contador de mensagens
  final DateTime? ultimaMensagemAt; // Data da última mensagem
  final String? ultimaMensagemPreview; // Preview da última mensagem
  final int? mensagensNaoLidas; // Contador de mensagens não lidas

  GrupoChat({
    this.id,
    required this.tarefaId,
    required this.tarefaNome,
    required this.comunidadeId,
    this.descricao,
    this.fotoUrl,
    this.createdAt,
    this.updatedAt,
    this.totalMensagens,
    this.ultimaMensagemAt,
    this.ultimaMensagemPreview,
    this.mensagensNaoLidas,
  });

  factory GrupoChat.fromMap(Map<String, dynamic> map) {
    return GrupoChat(
      id: map['id'] as String?,
      tarefaId: map['tarefa_id'] as String,
      tarefaNome: map['tarefa_nome'] as String? ?? map['tarefa_id'] as String,
      comunidadeId: map['comunidade_id'] as String,
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
      ultimaMensagemPreview: map['ultima_mensagem_preview'] as String?,
      mensagensNaoLidas: map['mensagens_nao_lidas'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tarefa_id': tarefaId,
      'tarefa_nome': tarefaNome,
      'comunidade_id': comunidadeId,
      'descricao': descricao,
      'foto_url': fotoUrl,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'total_mensagens': totalMensagens,
      'ultima_mensagem_at': ultimaMensagemAt?.toIso8601String(),
      'ultima_mensagem_preview': ultimaMensagemPreview,
      'mensagens_nao_lidas': mensagensNaoLidas,
    };
  }

  GrupoChat copyWith({
    String? id,
    String? tarefaId,
    String? tarefaNome,
    String? comunidadeId,
    String? descricao,
    String? fotoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? totalMensagens,
    DateTime? ultimaMensagemAt,
    String? ultimaMensagemPreview,
    int? mensagensNaoLidas,
  }) {
    return GrupoChat(
      id: id ?? this.id,
      tarefaId: tarefaId ?? this.tarefaId,
      tarefaNome: tarefaNome ?? this.tarefaNome,
      comunidadeId: comunidadeId ?? this.comunidadeId,
      descricao: descricao ?? this.descricao,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      totalMensagens: totalMensagens ?? this.totalMensagens,
      ultimaMensagemAt: ultimaMensagemAt ?? this.ultimaMensagemAt,
      ultimaMensagemPreview: ultimaMensagemPreview ?? this.ultimaMensagemPreview,
      mensagensNaoLidas: mensagensNaoLidas ?? this.mensagensNaoLidas,
    );
  }
}

