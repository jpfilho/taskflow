/// Modelos genéricos e reutilizáveis para a infraestrutura de Notificações Internas
/// do TaskFlow (utilizável futuramente por outros módulos além de Apoios Operacionais).
class NotificacaoInterna {
  final String id;
  final String modulo;
  final String categoria;
  final String eventoTipo;
  final String severidade; // INFO, ATENCAO, RISCO, CRITICO
  final String titulo;
  final String mensagem;
  final String entidadeTipo;
  final String entidadeId;
  final String? taskId;
  final String? solicitacaoId;
  final String? unidadeOrigemId;
  final String? unidadeOrigemNome;
  final String? unidadeDestinoId;
  final String? unidadeDestinoNome;
  final String? atorNome;
  final bool lida;
  final DateTime? lidaEm;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  const NotificacaoInterna({
    required this.id,
    this.modulo = 'APOIOS_OPERACIONAIS',
    required this.categoria,
    required this.eventoTipo,
    this.severidade = 'INFO',
    required this.titulo,
    required this.mensagem,
    required this.entidadeTipo,
    required this.entidadeId,
    this.taskId,
    this.solicitacaoId,
    this.unidadeOrigemId,
    this.unidadeOrigemNome,
    this.unidadeDestinoId,
    this.unidadeDestinoNome,
    this.atorNome,
    this.lida = false,
    this.lidaEm,
    required this.createdAt,
    this.metadata = const {},
  });

  factory NotificacaoInterna.fromJson(Map<String, dynamic> json) {
    return NotificacaoInterna(
      id: json['id']?.toString() ?? '',
      modulo: json['modulo']?.toString() ?? 'APOIOS_OPERACIONAIS',
      categoria: json['categoria']?.toString() ?? 'APOIO',
      eventoTipo: json['evento_tipo']?.toString() ?? '',
      severidade: json['severidade']?.toString() ?? 'INFO',
      titulo: json['titulo']?.toString() ?? '',
      mensagem: json['mensagem']?.toString() ?? '',
      entidadeTipo: json['entidade_tipo']?.toString() ?? '',
      entidadeId: json['entidade_id']?.toString() ?? '',
      taskId: json['task_id']?.toString(),
      solicitacaoId: json['solicitacao_id']?.toString(),
      unidadeOrigemId: json['unidade_origem_id']?.toString(),
      unidadeOrigemNome: json['unidade_origem_nome']?.toString(),
      unidadeDestinoId: json['unidade_destino_id']?.toString(),
      unidadeDestinoNome: json['unidade_destino_nome']?.toString(),
      atorNome: json['ator_nome']?.toString(),
      lida: json['lida'] == true,
      lidaEm: DateTime.tryParse(json['lida_em']?.toString() ?? ''),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      metadata: Map<String, dynamic>.from(
        (json['metadata_json'] as Map?) ?? const {},
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'modulo': modulo,
        'categoria': categoria,
        'evento_tipo': eventoTipo,
        'severidade': severidade,
        'titulo': titulo,
        'mensagem': mensagem,
        'entidade_tipo': entidadeTipo,
        'entidade_id': entidadeId,
        'task_id': taskId,
        'solicitacao_id': solicitacaoId,
        'unidade_origem_id': unidadeOrigemId,
        'unidade_origem_nome': unidadeOrigemNome,
        'unidade_destino_id': unidadeDestinoId,
        'unidade_destino_nome': unidadeDestinoNome,
        'ator_nome': atorNome,
        'lida': lida,
        'lida_em': lidaEm?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'metadata_json': metadata,
      };

  NotificacaoInterna copyWith({bool? lida, DateTime? lidaEm}) {
    return NotificacaoInterna(
      id: id,
      modulo: modulo,
      categoria: categoria,
      eventoTipo: eventoTipo,
      severidade: severidade,
      titulo: titulo,
      mensagem: mensagem,
      entidadeTipo: entidadeTipo,
      entidadeId: entidadeId,
      taskId: taskId,
      solicitacaoId: solicitacaoId,
      unidadeOrigemId: unidadeOrigemId,
      unidadeOrigemNome: unidadeOrigemNome,
      unidadeDestinoId: unidadeDestinoId,
      unidadeDestinoNome: unidadeDestinoNome,
      atorNome: atorNome,
      lida: lida ?? this.lida,
      lidaEm: lidaEm ?? this.lidaEm,
      createdAt: createdAt,
      metadata: metadata,
    );
  }
}

class NotificacaoPreferencia {
  final bool receberInterna;
  final bool receberTelegram;
  final List<String> eventosHabilitados;
  final List<int> antecedenciasDias;

  const NotificacaoPreferencia({
    this.receberInterna = true,
    this.receberTelegram = true,
    this.eventosHabilitados = const ['ALL'],
    this.antecedenciasDias = const [7, 3, 1, 0],
  });

  factory NotificacaoPreferencia.fromJson(Map<String, dynamic> json) {
    return NotificacaoPreferencia(
      receberInterna: json['receber_interna'] != false,
      receberTelegram: json['receber_telegram'] != false,
      eventosHabilitados: List<String>.from(
        (json['eventos_habilitados'] as List?) ?? const ['ALL'],
      ),
      antecedenciasDias: ((json['antecedencias_dias'] as List?) ?? const [7, 3, 1, 0])
          .map((e) => (e as num).toInt())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'receber_interna': receberInterna,
        'receber_telegram': receberTelegram,
        'eventos_habilitados': eventosHabilitados,
        'antecedencias_dias': antecedenciasDias,
      };
}

class ApoioMensagemOperacional {
  final String id;
  final String solicitacaoId;
  final String autorUsuarioId;
  final String autorNome;
  final String? unidadeId;
  final String mensagem;
  final DateTime createdAt;

  const ApoioMensagemOperacional({
    required this.id,
    required this.solicitacaoId,
    required this.autorUsuarioId,
    required this.autorNome,
    this.unidadeId,
    required this.mensagem,
    required this.createdAt,
  });

  factory ApoioMensagemOperacional.fromJson(Map<String, dynamic> json) {
    return ApoioMensagemOperacional(
      id: json['id']?.toString() ?? '',
      solicitacaoId: json['solicitacao_id']?.toString() ?? '',
      autorUsuarioId: json['autor_usuario_id']?.toString() ?? '',
      autorNome: json['autor_nome']?.toString() ?? '',
      unidadeId: json['unidade_id']?.toString(),
      mensagem: json['mensagem']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

