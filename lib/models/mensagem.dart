class Mensagem {
  final String? id;
  final String grupoId; // ID da tarefa (grupo)
  final String usuarioId; // ID do usuário que enviou
  final String? usuarioNome; // Nome do usuário (para exibição)
  final String conteudo;
  final String? tipo; // 'texto', 'imagem', 'video', 'documento', 'audio', 'localizacao'
  final String? arquivoUrl; // URL do arquivo se for mídia
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool? lida; // Se a mensagem foi lida
  final List<String>? usuariosLidos; // IDs dos usuários que leram
  final String? mensagemRespondidaId; // ID da mensagem que está sendo respondida
  final Mensagem? mensagemRespondida; // Mensagem completa que está sendo respondida (para exibição)
  final List<String>? usuariosMencionados; // IDs dos usuários mencionados (@mention)
  final Map<String, dynamic>? localizacao; // Dados de localização {lat, lng, endereco}

  Mensagem({
    this.id,
    required this.grupoId,
    required this.usuarioId,
    this.usuarioNome,
    required this.conteudo,
    this.tipo = 'texto',
    this.arquivoUrl,
    required this.createdAt,
    this.updatedAt,
    this.lida,
    this.usuariosLidos,
    this.mensagemRespondidaId,
    this.mensagemRespondida,
    this.usuariosMencionados,
    this.localizacao,
  });

  factory Mensagem.fromMap(Map<String, dynamic> map) {
    Mensagem? mensagemRespondida;
    if (map['mensagem_respondida'] != null) {
      try {
        mensagemRespondida = Mensagem.fromMap(map['mensagem_respondida'] as Map<String, dynamic>);
      } catch (e) {
        // Ignorar erro se não conseguir parsear
      }
    }
    
    Map<String, dynamic>? localizacao;
    if (map['localizacao'] != null) {
      if (map['localizacao'] is Map) {
        localizacao = Map<String, dynamic>.from(map['localizacao'] as Map);
      } else if (map['localizacao'] is String) {
        try {
          localizacao = Map<String, dynamic>.from(
            Map<String, dynamic>.from(
              (map['localizacao'] as String).split(',').asMap().map((i, v) => 
                MapEntry(i == 0 ? 'lat' : i == 1 ? 'lng' : 'endereco', v.trim())
              )
            )
          );
        } catch (e) {
          // Ignorar erro
        }
      }
    }
    
    return Mensagem(
      id: map['id'] as String?,
      grupoId: map['grupo_id'] as String,
      usuarioId: map['usuario_id'] as String,
      usuarioNome: map['usuario_nome'] as String?,
      conteudo: map['conteudo'] as String,
      tipo: map['tipo'] as String? ?? 'texto',
      arquivoUrl: map['arquivo_url'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
      lida: map['lida'] as bool?,
      usuariosLidos: map['usuarios_lidos'] != null
          ? List<String>.from(map['usuarios_lidos'] as List)
          : null,
      mensagemRespondidaId: map['mensagem_respondida_id'] as String?,
      mensagemRespondida: mensagemRespondida,
      usuariosMencionados: map['usuarios_mencionados'] != null
          ? List<String>.from(map['usuarios_mencionados'] as List)
          : null,
      localizacao: localizacao,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'grupo_id': grupoId,
      'usuario_id': usuarioId,
      'usuario_nome': usuarioNome,
      'conteudo': conteudo,
      'tipo': tipo ?? 'texto',
      'arquivo_url': arquivoUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'lida': lida,
      'usuarios_lidos': usuariosLidos,
      'mensagem_respondida_id': mensagemRespondidaId,
      'usuarios_mencionados': usuariosMencionados,
      'localizacao': localizacao != null ? {
        'lat': localizacao!['lat'],
        'lng': localizacao!['lng'],
        'endereco': localizacao!['endereco'],
      } : null,
    };
  }

  Mensagem copyWith({
    String? id,
    String? grupoId,
    String? usuarioId,
    String? usuarioNome,
    String? conteudo,
    String? tipo,
    String? arquivoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? lida,
    List<String>? usuariosLidos,
    String? mensagemRespondidaId,
    Mensagem? mensagemRespondida,
    List<String>? usuariosMencionados,
    Map<String, dynamic>? localizacao,
  }) {
    return Mensagem(
      id: id ?? this.id,
      grupoId: grupoId ?? this.grupoId,
      usuarioId: usuarioId ?? this.usuarioId,
      usuarioNome: usuarioNome ?? this.usuarioNome,
      conteudo: conteudo ?? this.conteudo,
      tipo: tipo ?? this.tipo,
      arquivoUrl: arquivoUrl ?? this.arquivoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lida: lida ?? this.lida,
      usuariosLidos: usuariosLidos ?? this.usuariosLidos,
      mensagemRespondidaId: mensagemRespondidaId ?? this.mensagemRespondidaId,
      mensagemRespondida: mensagemRespondida ?? this.mensagemRespondida,
      usuariosMencionados: usuariosMencionados ?? this.usuariosMencionados,
      localizacao: localizacao ?? this.localizacao,
    );
  }
}

