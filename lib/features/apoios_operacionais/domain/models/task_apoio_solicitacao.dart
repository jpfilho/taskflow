import '../enums/task_apoio_enums.dart';
import 'task_apoio_periodo.dart';
import 'task_apoio_requisito_recurso.dart';

/// Modelo de solicitação de apoio operacional (`tasks_apoios_solicitacoes`).
/// Preserva separadamente períodos originalmente solicitados, contraproposta e acordados,
/// além de estado local para preparação offline-first.
class TaskApoioSolicitacao {
  final String id;
  final String? idempotencyKey;
  final String? taskSolicitanteId;
  final String taskSolicitanteTituloSnapshot;
  final String? taskSolicitanteOrdemSnapshot;

  final String regionalSolicitanteId;
  final String divisaoSolicitanteId;
  final String? segmentoSolicitanteId;

  final String regionalDestinoId;
  final String divisaoDestinoId;
  final String? segmentoDestinoId;

  final String tipoApoioId;
  final TaskApoioCriticidade criticidade;
  final TaskApoioPrioridade prioridade;
  final TaskApoioModalidade modalidade;

  final String descricao;
  final String? locaisAtendimento;

  final DateTime dataInicioSolicitada;
  final DateTime dataFimSolicitada;

  final DateTime? contrapropostaInicio;
  final DateTime? contrapropostaFim;
  final String? contrapropostaJustificativa;

  final DateTime? dataInicioAcordada;
  final DateTime? dataFimAcordada;
  final DateTime? prazoResposta;

  final TaskApoioStatus status;
  final String? justificativaDecisao;
  final String? observacoes;

  final String solicitanteUsuarioId;
  final String? responsavelAtendimentoId;

  final int versao;
  final bool ativo;
  final DateTime? canceladoEm;
  final String? canceladoPor;
  final String? motivoCancelamento;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  final List<TaskApoioPeriodo> periodos;
  final TaskApoioRequisitoRecurso? requisitosRecursos;
  final TaskApoioSyncStatus syncStatus;
  final String? syncErrorMessage;

  const TaskApoioSolicitacao({
    required this.id,
    this.idempotencyKey,
    this.taskSolicitanteId,
    required this.taskSolicitanteTituloSnapshot,
    this.taskSolicitanteOrdemSnapshot,
    required this.regionalSolicitanteId,
    required this.divisaoSolicitanteId,
    this.segmentoSolicitanteId,
    required this.regionalDestinoId,
    required this.divisaoDestinoId,
    this.segmentoDestinoId,
    required this.tipoApoioId,
    this.criticidade = TaskApoioCriticidade.essencial,
    this.prioridade = TaskApoioPrioridade.media,
    this.modalidade = TaskApoioModalidade.solicitacao,
    required this.descricao,
    this.locaisAtendimento,
    required this.dataInicioSolicitada,
    required this.dataFimSolicitada,
    this.contrapropostaInicio,
    this.contrapropostaFim,
    this.contrapropostaJustificativa,
    this.dataInicioAcordada,
    this.dataFimAcordada,
    this.prazoResposta,
    this.status = TaskApoioStatus.pendente,
    this.justificativaDecisao,
    this.observacoes,
    required this.solicitanteUsuarioId,
    this.responsavelAtendimentoId,
    this.versao = 1,
    this.ativo = true,
    this.canceladoEm,
    this.canceladoPor,
    this.motivoCancelamento,
    this.createdAt,
    this.updatedAt,
    this.periodos = const [],
    this.requisitosRecursos,
    this.syncStatus = TaskApoioSyncStatus.confirmadoServidor,
    this.syncErrorMessage,
  });

  /// Retorna os períodos de necessidade efetivamente vigentes para avaliação:
  /// - Se houver períodos acordados na lista, usa-os;
  /// - Senão, se `status == ACEITA` e houver `dataInicioAcordada`/`dataFimAcordada`, usa o intervalo acordado;
  /// - Enquanto uma contraproposta NÃO estiver aceita, NÃO substitui silenciosamente a necessidade original:
  ///   mantém os períodos originalmente solicitados (ou `dataInicioSolicitada`..`dataFimSolicitada`).
  List<TaskApoioPeriodo> get periodosNecessidadeVigentes {
    if (status == TaskApoioStatus.aceita) {
      final acordados = periodos
          .where((p) => p.origemPeriodo == TaskApoioOrigemPeriodo.acordado)
          .toList();
      if (acordados.isNotEmpty) return acordados;
      if (dataInicioAcordada != null && dataFimAcordada != null) {
        return [
          TaskApoioPeriodo(
            solicitacaoId: id,
            origemPeriodo: TaskApoioOrigemPeriodo.acordado,
            dataInicio: dataInicioAcordada!,
            dataFim: dataFimAcordada!,
          ),
        ];
      }
    }

    final solicitados = periodos
        .where((p) => p.origemPeriodo == TaskApoioOrigemPeriodo.solicitacao)
        .toList();
    if (solicitados.isNotEmpty) return solicitados;

    return [
      TaskApoioPeriodo(
        solicitacaoId: id,
        origemPeriodo: TaskApoioOrigemPeriodo.solicitacao,
        dataInicio: dataInicioSolicitada,
        dataFim: dataFimSolicitada,
      ),
    ];
  }

  factory TaskApoioSolicitacao.fromJson(Map<String, dynamic> json) {
    final periodosRaw = json['periodos'] as List<dynamic>? ?? const [];
    final reqJson = json['requisitos_recursos_json'] ?? json['requisitosRecursos'];
    return TaskApoioSolicitacao(
      id: json['id']?.toString() ?? '',
      idempotencyKey:
          json['idempotency_key']?.toString() ?? json['idempotencyKey']?.toString(),
      taskSolicitanteId: json['task_solicitante_id']?.toString() ??
          json['taskSolicitanteId']?.toString(),
      taskSolicitanteTituloSnapshot:
          (json['task_solicitante_titulo_snapshot'] ??
                  json['taskSolicitanteTituloSnapshot'])
              ?.toString() ??
              '',
      taskSolicitanteOrdemSnapshot:
          (json['task_solicitante_ordem_snapshot'] ??
                  json['taskSolicitanteOrdemSnapshot'])
              ?.toString(),
      regionalSolicitanteId:
          (json['regional_solicitante_id'] ?? json['regionalSolicitanteId'])
                  ?.toString() ??
              '',
      divisaoSolicitanteId:
          (json['divisao_solicitante_id'] ?? json['divisaoSolicitanteId'])
                  ?.toString() ??
              '',
      segmentoSolicitanteId:
          (json['segmento_solicitante_id'] ?? json['segmentoSolicitanteId'])
              ?.toString(),
      regionalDestinoId:
          (json['regional_destino_id'] ?? json['regionalDestinoId'])
                  ?.toString() ??
              '',
      divisaoDestinoId:
          (json['divisao_destino_id'] ?? json['divisaoDestinoId'])
                  ?.toString() ??
              '',
      segmentoDestinoId:
          (json['segmento_destino_id'] ?? json['segmentoDestinoId'])
              ?.toString(),
      tipoApoioId:
          (json['tipo_apoio_id'] ?? json['tipoApoioId'])?.toString() ?? '',
      criticidade: TaskApoioCriticidade.fromDb(json['criticidade']?.toString()),
      prioridade: TaskApoioPrioridade.fromDb(json['prioridade']?.toString()),
      modalidade: TaskApoioModalidade.fromDb(json['modalidade']?.toString()),
      descricao: json['descricao']?.toString() ?? '',
      locaisAtendimento:
          (json['locais_atendimento'] ?? json['locaisAtendimento'])?.toString(),
      dataInicioSolicitada: _parseRequiredDate(
        json['data_inicio_solicitada'] ?? json['dataInicioSolicitada'],
      ),
      dataFimSolicitada: _parseRequiredDate(
        json['data_fim_solicitada'] ?? json['dataFimSolicitada'],
      ),
      contrapropostaInicio: _parseOptionalDate(
        json['contraproposta_inicio'] ?? json['contrapropostaInicio'],
      ),
      contrapropostaFim: _parseOptionalDate(
        json['contraproposta_fim'] ?? json['contrapropostaFim'],
      ),
      contrapropostaJustificativa: (json['contraproposta_justificativa'] ??
              json['contrapropostaJustificativa'])
          ?.toString(),
      dataInicioAcordada: _parseOptionalDate(
        json['data_inicio_acordada'] ?? json['dataInicioAcordada'],
      ),
      dataFimAcordada: _parseOptionalDate(
        json['data_fim_acordada'] ?? json['dataFimAcordada'],
      ),
      prazoResposta: _parseOptionalDate(
        json['prazo_resposta'] ?? json['prazoResposta'],
      ),
      status: TaskApoioStatus.fromDb(json['status']?.toString()),
      justificativaDecisao:
          (json['justificativa_decisao'] ?? json['justificativaDecisao'])
              ?.toString(),
      observacoes: json['observacoes']?.toString(),
      solicitanteUsuarioId:
          (json['solicitante_usuario_id'] ?? json['solicitanteUsuarioId'])
                  ?.toString() ??
              '',
      responsavelAtendimentoId: (json['responsavel_atendimento_id'] ??
              json['responsavelAtendimentoId'])
          ?.toString(),
      versao: (json['versao'] as num?)?.toInt() ?? 1,
      ativo: json['ativo'] != false,
      canceladoEm:
          _parseOptionalDate(json['cancelado_em'] ?? json['canceladoEm']),
      canceladoPor:
          (json['cancelado_por'] ?? json['canceladoPor'])?.toString(),
      motivoCancelamento:
          (json['motivo_cancelamento'] ?? json['motivoCancelamento'])
              ?.toString(),
      createdAt: _parseOptionalDate(json['created_at'] ?? json['createdAt']),
      updatedAt: _parseOptionalDate(json['updated_at'] ?? json['updatedAt']),
      periodos: periodosRaw
          .whereType<Map<String, dynamic>>()
          .map(TaskApoioPeriodo.fromJson)
          .toList(),
      requisitosRecursos: reqJson is Map<String, dynamic>
          ? TaskApoioRequisitoRecurso.fromJson(reqJson)
          : null,
      syncStatus: TaskApoioSyncStatus.fromCode(
        (json['sync_status'] ?? json['syncStatus'])?.toString(),
      ),
      syncErrorMessage:
          (json['sync_error_message'] ?? json['syncErrorMessage'])?.toString(),
    );
  }

  Map<String, dynamic> toJson({bool includeLocalSyncFields = true}) {
    return {
      'id': id,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      'task_solicitante_id': taskSolicitanteId,
      'task_solicitante_titulo_snapshot': taskSolicitanteTituloSnapshot,
      'task_solicitante_ordem_snapshot': taskSolicitanteOrdemSnapshot,
      'regional_solicitante_id': regionalSolicitanteId,
      'divisao_solicitante_id': divisaoSolicitanteId,
      'segmento_solicitante_id': segmentoSolicitanteId,
      'regional_destino_id': regionalDestinoId,
      'divisao_destino_id': divisaoDestinoId,
      'segmento_destino_id': segmentoDestinoId,
      'tipo_apoio_id': tipoApoioId,
      'criticidade': criticidade.dbValue,
      'prioridade': prioridade.dbValue,
      'modalidade': modalidade.dbValue,
      'descricao': descricao,
      'locais_atendimento': locaisAtendimento,
      'data_inicio_solicitada': dataInicioSolicitada.toUtc().toIso8601String(),
      'data_fim_solicitada': dataFimSolicitada.toUtc().toIso8601String(),
      'contraproposta_inicio':
          contrapropostaInicio?.toUtc().toIso8601String(),
      'contraproposta_fim': contrapropostaFim?.toUtc().toIso8601String(),
      'contraproposta_justificativa': contrapropostaJustificativa,
      'data_inicio_acordada': dataInicioAcordada?.toUtc().toIso8601String(),
      'data_fim_acordada': dataFimAcordada?.toUtc().toIso8601String(),
      'prazo_resposta': prazoResposta?.toUtc().toIso8601String(),
      'status': status.dbValue,
      'justificativa_decisao': justificativaDecisao,
      'observacoes': observacoes,
      'solicitante_usuario_id': solicitanteUsuarioId,
      'responsavel_atendimento_id': responsavelAtendimentoId,
      'versao': versao,
      'ativo': ativo,
      'cancelado_em': canceladoEm?.toUtc().toIso8601String(),
      'cancelado_por': canceladoPor,
      'motivo_cancelamento': motivoCancelamento,
      'requisitos_recursos_json': requisitosRecursos?.toJson(),
      if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toUtc().toIso8601String(),
      if (includeLocalSyncFields) ...{
        'periodos': periodos.map((p) => p.toJson()).toList(),
        'sync_status': syncStatus.code,
        'sync_error_message': syncErrorMessage,
      },
    };
  }

  TaskApoioSolicitacao copyWith({
    String? id,
    String? idempotencyKey,
    String? taskSolicitanteId,
    String? taskSolicitanteTituloSnapshot,
    String? taskSolicitanteOrdemSnapshot,
    String? regionalSolicitanteId,
    String? divisaoSolicitanteId,
    String? segmentoSolicitanteId,
    String? regionalDestinoId,
    String? divisaoDestinoId,
    String? segmentoDestinoId,
    String? tipoApoioId,
    TaskApoioCriticidade? criticidade,
    TaskApoioPrioridade? prioridade,
    TaskApoioModalidade? modalidade,
    String? descricao,
    String? locaisAtendimento,
    DateTime? dataInicioSolicitada,
    DateTime? dataFimSolicitada,
    DateTime? contrapropostaInicio,
    DateTime? contrapropostaFim,
    String? contrapropostaJustificativa,
    DateTime? dataInicioAcordada,
    DateTime? dataFimAcordada,
    DateTime? prazoResposta,
    TaskApoioStatus? status,
    String? justificativaDecisao,
    String? observacoes,
    String? solicitanteUsuarioId,
    String? responsavelAtendimentoId,
    int? versao,
    bool? ativo,
    DateTime? canceladoEm,
    String? canceladoPor,
    String? motivoCancelamento,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<TaskApoioPeriodo>? periodos,
    TaskApoioRequisitoRecurso? requisitosRecursos,
    TaskApoioSyncStatus? syncStatus,
    String? syncErrorMessage,
  }) {
    return TaskApoioSolicitacao(
      id: id ?? this.id,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      taskSolicitanteId: taskSolicitanteId ?? this.taskSolicitanteId,
      taskSolicitanteTituloSnapshot:
          taskSolicitanteTituloSnapshot ?? this.taskSolicitanteTituloSnapshot,
      taskSolicitanteOrdemSnapshot:
          taskSolicitanteOrdemSnapshot ?? this.taskSolicitanteOrdemSnapshot,
      regionalSolicitanteId:
          regionalSolicitanteId ?? this.regionalSolicitanteId,
      divisaoSolicitanteId: divisaoSolicitanteId ?? this.divisaoSolicitanteId,
      segmentoSolicitanteId:
          segmentoSolicitanteId ?? this.segmentoSolicitanteId,
      regionalDestinoId: regionalDestinoId ?? this.regionalDestinoId,
      divisaoDestinoId: divisaoDestinoId ?? this.divisaoDestinoId,
      segmentoDestinoId: segmentoDestinoId ?? this.segmentoDestinoId,
      tipoApoioId: tipoApoioId ?? this.tipoApoioId,
      criticidade: criticidade ?? this.criticidade,
      prioridade: prioridade ?? this.prioridade,
      modalidade: modalidade ?? this.modalidade,
      descricao: descricao ?? this.descricao,
      locaisAtendimento: locaisAtendimento ?? this.locaisAtendimento,
      dataInicioSolicitada: dataInicioSolicitada ?? this.dataInicioSolicitada,
      dataFimSolicitada: dataFimSolicitada ?? this.dataFimSolicitada,
      contrapropostaInicio: contrapropostaInicio ?? this.contrapropostaInicio,
      contrapropostaFim: contrapropostaFim ?? this.contrapropostaFim,
      contrapropostaJustificativa:
          contrapropostaJustificativa ?? this.contrapropostaJustificativa,
      dataInicioAcordada: dataInicioAcordada ?? this.dataInicioAcordada,
      dataFimAcordada: dataFimAcordada ?? this.dataFimAcordada,
      prazoResposta: prazoResposta ?? this.prazoResposta,
      status: status ?? this.status,
      justificativaDecisao: justificativaDecisao ?? this.justificativaDecisao,
      observacoes: observacoes ?? this.observacoes,
      solicitanteUsuarioId: solicitanteUsuarioId ?? this.solicitanteUsuarioId,
      responsavelAtendimentoId:
          responsavelAtendimentoId ?? this.responsavelAtendimentoId,
      versao: versao ?? this.versao,
      ativo: ativo ?? this.ativo,
      canceladoEm: canceladoEm ?? this.canceladoEm,
      canceladoPor: canceladoPor ?? this.canceladoPor,
      motivoCancelamento: motivoCancelamento ?? this.motivoCancelamento,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      periodos: periodos ?? this.periodos,
      requisitosRecursos: requisitosRecursos ?? this.requisitosRecursos,
      syncStatus: syncStatus ?? this.syncStatus,
      syncErrorMessage: syncErrorMessage ?? this.syncErrorMessage,
    );
  }

  static DateTime _parseRequiredDate(dynamic value) {
    if (value is DateTime) return value.toUtc();
    if (value != null) {
      final parsed = DateTime.tryParse(value.toString());
      if (parsed != null) return parsed.toUtc();
    }
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  static DateTime? _parseOptionalDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc();
    return DateTime.tryParse(value.toString())?.toUtc();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskApoioSolicitacao &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          versao == other.versao &&
          status == other.status &&
          syncStatus == other.syncStatus;

  @override
  int get hashCode => Object.hash(id, versao, status, syncStatus);
}

