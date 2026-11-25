/// Modelo imutável de evento de histórico (`tasks_apoios_historico`).
class TaskApoioHistorico {
  final String id;
  final String? solicitacaoId;
  final String? vinculoId;
  final String? taskRelacionadaId;
  final String evento;
  final String? statusAnterior;
  final String? statusNovo;
  final String? justificativa;
  final Map<String, dynamic> detalhesJson;
  final String? usuarioId;
  final String? usuarioNome;
  final DateTime createdAt;

  const TaskApoioHistorico({
    required this.id,
    this.solicitacaoId,
    this.vinculoId,
    this.taskRelacionadaId,
    required this.evento,
    this.statusAnterior,
    this.statusNovo,
    this.justificativa,
    this.detalhesJson = const {},
    this.usuarioId,
    this.usuarioNome,
    required this.createdAt,
  });

  factory TaskApoioHistorico.fromJson(Map<String, dynamic> json) {
    final detalhes = json['detalhes_json'] ?? json['detalhesJson'];
    return TaskApoioHistorico(
      id: json['id']?.toString() ?? '',
      solicitacaoId:
          (json['solicitacao_id'] ?? json['solicitacaoId'])?.toString(),
      vinculoId: (json['vinculo_id'] ?? json['vinculoId'])?.toString(),
      taskRelacionadaId:
          (json['task_relacionada_id'] ?? json['taskRelacionadaId'])?.toString(),
      evento: json['evento']?.toString() ?? '',
      statusAnterior:
          (json['status_anterior'] ?? json['statusAnterior'])?.toString(),
      statusNovo: (json['status_novo'] ?? json['statusNovo'])?.toString(),
      justificativa: json['justificativa']?.toString(),
      detalhesJson: detalhes is Map<String, dynamic>
          ? Map<String, dynamic>.from(detalhes)
          : const {},
      usuarioId: (json['usuario_id'] ?? json['usuarioId'])?.toString(),
      usuarioNome: (json['usuario_nome'] ?? json['usuarioNome'])?.toString(),
      createdAt: DateTime.tryParse(
                (json['created_at'] ?? json['createdAt'])?.toString() ?? '',
              )?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'solicitacao_id': solicitacaoId,
      'vinculo_id': vinculoId,
      'task_relacionada_id': taskRelacionadaId,
      'evento': evento,
      'status_anterior': statusAnterior,
      'status_novo': statusNovo,
      'justificativa': justificativa,
      'detalhes_json': detalhesJson,
      'usuario_id': usuarioId,
      'usuario_nome': usuarioNome,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskApoioHistorico &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          evento == other.evento &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(id, evento, createdAt);
}

