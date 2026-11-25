import '../enums/task_apoio_enums.dart';

/// Modelo de vínculo lateral entre atividades (`tasks_apoios_vinculos`).
/// Representa apoios operacionais, vínculos diretos e programações conjuntas,
/// mantendo visibilidade bidirecional sem duplicar o registro.
class TaskApoioVinculo {
  final String id;
  final String? idempotencyKey;
  final String? solicitacaoId;
  final String? taskPrincipalId;
  final String? taskApoioId;
  final String taskPrincipalTituloSnapshot;
  final String taskApoioTituloSnapshot;
  final String? tipoApoioId;
  final TaskApoioFinalidadeVinculo finalidade;
  final DateTime? coberturaInicio;
  final DateTime? coberturaFim;
  final String? observacao;
  final bool autorizadoDireto;
  final TaskApoioStatusConfirmacaoVinculo statusConfirmacao;
  final bool ativo;
  final int versao;
  final DateTime? desativadoEm;
  final String? desativadoPor;
  final String? motivoDesativacao;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final TaskApoioSyncStatus syncStatus;

  const TaskApoioVinculo({
    required this.id,
    this.idempotencyKey,
    this.solicitacaoId,
    this.taskPrincipalId,
    this.taskApoioId,
    required this.taskPrincipalTituloSnapshot,
    required this.taskApoioTituloSnapshot,
    this.tipoApoioId,
    this.finalidade = TaskApoioFinalidadeVinculo.apoioOperacional,
    this.coberturaInicio,
    this.coberturaFim,
    this.observacao,
    this.autorizadoDireto = false,
    this.statusConfirmacao = TaskApoioStatusConfirmacaoVinculo.confirmado,
    this.ativo = true,
    this.versao = 1,
    this.desativadoEm,
    this.desativadoPor,
    this.motivoDesativacao,
    required this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.syncStatus = TaskApoioSyncStatus.confirmadoServidor,
  });

  factory TaskApoioVinculo.fromJson(Map<String, dynamic> json) {
    return TaskApoioVinculo(
      id: json['id']?.toString() ?? '',
      idempotencyKey:
          json['idempotency_key']?.toString() ?? json['idempotencyKey']?.toString(),
      solicitacaoId:
          json['solicitacao_id']?.toString() ?? json['solicitacaoId']?.toString(),
      taskPrincipalId: (json['task_principal_id'] ?? json['taskPrincipalId'])
          ?.toString(),
      taskApoioId:
          (json['task_apoio_id'] ?? json['taskApoioId'])?.toString(),
      taskPrincipalTituloSnapshot:
          (json['task_principal_titulo_snapshot'] ??
                  json['taskPrincipalTituloSnapshot'])
              ?.toString() ??
              '',
      taskApoioTituloSnapshot:
          (json['task_apoio_titulo_snapshot'] ?? json['taskApoioTituloSnapshot'])
              ?.toString() ??
              '',
      tipoApoioId:
          (json['tipo_apoio_id'] ?? json['tipoApoioId'])?.toString(),
      finalidade: TaskApoioFinalidadeVinculo.fromDb(
        json['finalidade']?.toString(),
      ),
      coberturaInicio: _parseOptionalDate(
        json['cobertura_inicio'] ?? json['coberturaInicio'],
      ),
      coberturaFim: _parseOptionalDate(
        json['cobertura_fim'] ?? json['coberturaFim'],
      ),
      observacao: json['observacao']?.toString(),
      autorizadoDireto:
          (json['autorizado_direto'] ?? json['autorizadoDireto']) == true,
      statusConfirmacao: TaskApoioStatusConfirmacaoVinculo.fromDb(
        (json['status_confirmacao'] ?? json['statusConfirmacao'])?.toString(),
      ),
      ativo: json['ativo'] != false,
      versao: (json['versao'] as num?)?.toInt() ?? 1,
      desativadoEm:
          _parseOptionalDate(json['desativado_em'] ?? json['desativadoEm']),
      desativadoPor:
          (json['desativado_por'] ?? json['desativadoPor'])?.toString(),
      motivoDesativacao:
          (json['motivo_desativacao'] ?? json['motivoDesativacao'])?.toString(),
      createdBy:
          (json['created_by'] ?? json['createdBy'])?.toString() ?? '',
      createdAt: _parseOptionalDate(json['created_at'] ?? json['createdAt']),
      updatedAt: _parseOptionalDate(json['updated_at'] ?? json['updatedAt']),
      syncStatus: TaskApoioSyncStatus.fromCode(
        (json['sync_status'] ?? json['syncStatus'])?.toString(),
      ),
    );
  }

  Map<String, dynamic> toJson({bool includeLocalSyncFields = true}) {
    return {
      'id': id,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      'solicitacao_id': solicitacaoId,
      'task_principal_id': taskPrincipalId,
      'task_apoio_id': taskApoioId,
      'task_principal_titulo_snapshot': taskPrincipalTituloSnapshot,
      'task_apoio_titulo_snapshot': taskApoioTituloSnapshot,
      'tipo_apoio_id': tipoApoioId,
      'finalidade': finalidade.dbValue,
      'cobertura_inicio': coberturaInicio?.toUtc().toIso8601String(),
      'cobertura_fim': coberturaFim?.toUtc().toIso8601String(),
      'observacao': observacao,
      'autorizado_direto': autorizadoDireto,
      'status_confirmacao': statusConfirmacao.dbValue,
      'ativo': ativo,
      'versao': versao,
      'desativado_em': desativadoEm?.toUtc().toIso8601String(),
      'desativado_por': desativadoPor,
      'motivo_desativacao': motivoDesativacao,
      'created_by': createdBy,
      if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toUtc().toIso8601String(),
      if (includeLocalSyncFields) 'sync_status': syncStatus.code,
    };
  }

  TaskApoioVinculo copyWith({
    String? id,
    String? idempotencyKey,
    String? solicitacaoId,
    String? taskPrincipalId,
    String? taskApoioId,
    String? taskPrincipalTituloSnapshot,
    String? taskApoioTituloSnapshot,
    String? tipoApoioId,
    TaskApoioFinalidadeVinculo? finalidade,
    DateTime? coberturaInicio,
    DateTime? coberturaFim,
    String? observacao,
    bool? autorizadoDireto,
    TaskApoioStatusConfirmacaoVinculo? statusConfirmacao,
    bool? ativo,
    int? versao,
    DateTime? desativadoEm,
    String? desativadoPor,
    String? motivoDesativacao,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    TaskApoioSyncStatus? syncStatus,
  }) {
    return TaskApoioVinculo(
      id: id ?? this.id,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      solicitacaoId: solicitacaoId ?? this.solicitacaoId,
      taskPrincipalId: taskPrincipalId ?? this.taskPrincipalId,
      taskApoioId: taskApoioId ?? this.taskApoioId,
      taskPrincipalTituloSnapshot:
          taskPrincipalTituloSnapshot ?? this.taskPrincipalTituloSnapshot,
      taskApoioTituloSnapshot:
          taskApoioTituloSnapshot ?? this.taskApoioTituloSnapshot,
      tipoApoioId: tipoApoioId ?? this.tipoApoioId,
      finalidade: finalidade ?? this.finalidade,
      coberturaInicio: coberturaInicio ?? this.coberturaInicio,
      coberturaFim: coberturaFim ?? this.coberturaFim,
      observacao: observacao ?? this.observacao,
      autorizadoDireto: autorizadoDireto ?? this.autorizadoDireto,
      statusConfirmacao: statusConfirmacao ?? this.statusConfirmacao,
      ativo: ativo ?? this.ativo,
      versao: versao ?? this.versao,
      desativadoEm: desativadoEm ?? this.desativadoEm,
      desativadoPor: desativadoPor ?? this.desativadoPor,
      motivoDesativacao: motivoDesativacao ?? this.motivoDesativacao,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  static DateTime? _parseOptionalDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc();
    return DateTime.tryParse(value.toString())?.toUtc();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskApoioVinculo &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          versao == other.versao &&
          ativo == other.ativo;

  @override
  int get hashCode => Object.hash(id, versao, ativo);
}

