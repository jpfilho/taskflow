import '../enums/task_apoio_enums.dart';

/// Modelo de período de apoio operacional (`tasks_apoios_solicitacoes_periodos`).
/// Suporta períodos contínuos, parciais, descontínuos, prévios ou posteriores.
class TaskApoioPeriodo {
  final String? id;
  final String? solicitacaoId;
  final TaskApoioOrigemPeriodo origemPeriodo;
  final TaskApoioTipoPeriodo tipoPeriodo;
  final DateTime dataInicio;
  final DateTime dataFim;
  final String? observacao;
  final DateTime? createdAt;

  const TaskApoioPeriodo({
    this.id,
    this.solicitacaoId,
    this.origemPeriodo = TaskApoioOrigemPeriodo.solicitacao,
    this.tipoPeriodo = TaskApoioTipoPeriodo.continuo,
    required this.dataInicio,
    required this.dataFim,
    this.observacao,
    this.createdAt,
  });

  bool get isValid => !dataFim.isBefore(dataInicio);

  Duration get duracao =>
      isValid ? dataFim.difference(dataInicio) : Duration.zero;

  factory TaskApoioPeriodo.fromJson(Map<String, dynamic> json) {
    final inicioRaw =
        json['data_inicio'] ?? json['dataInicio'] ?? DateTime.now().toUtc().toIso8601String();
    final fimRaw =
        json['data_fim'] ?? json['dataFim'] ?? DateTime.now().toUtc().toIso8601String();
    return TaskApoioPeriodo(
      id: json['id']?.toString(),
      solicitacaoId:
          json['solicitacao_id']?.toString() ?? json['solicitacaoId']?.toString(),
      origemPeriodo: TaskApoioOrigemPeriodo.fromDb(
        (json['origem_periodo'] ?? json['origemPeriodo'])?.toString(),
      ),
      tipoPeriodo: TaskApoioTipoPeriodo.fromDb(
        (json['tipo_periodo'] ?? json['tipoPeriodo'])?.toString(),
      ),
      dataInicio: DateTime.parse(inicioRaw.toString()).toUtc(),
      dataFim: DateTime.parse(fimRaw.toString()).toUtc(),
      observacao: json['observacao']?.toString(),
      createdAt: _parseOptionalDate(json['created_at'] ?? json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (solicitacaoId != null) 'solicitacao_id': solicitacaoId,
      'origem_periodo': origemPeriodo.dbValue,
      'tipo_periodo': tipoPeriodo.dbValue,
      'data_inicio': dataInicio.toUtc().toIso8601String(),
      'data_fim': dataFim.toUtc().toIso8601String(),
      'observacao': observacao,
      if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
    };
  }

  TaskApoioPeriodo copyWith({
    String? id,
    String? solicitacaoId,
    TaskApoioOrigemPeriodo? origemPeriodo,
    TaskApoioTipoPeriodo? tipoPeriodo,
    DateTime? dataInicio,
    DateTime? dataFim,
    String? observacao,
    DateTime? createdAt,
  }) {
    return TaskApoioPeriodo(
      id: id ?? this.id,
      solicitacaoId: solicitacaoId ?? this.solicitacaoId,
      origemPeriodo: origemPeriodo ?? this.origemPeriodo,
      tipoPeriodo: tipoPeriodo ?? this.tipoPeriodo,
      dataInicio: dataInicio ?? this.dataInicio,
      dataFim: dataFim ?? this.dataFim,
      observacao: observacao ?? this.observacao,
      createdAt: createdAt ?? this.createdAt,
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
      other is TaskApoioPeriodo &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          solicitacaoId == other.solicitacaoId &&
          origemPeriodo == other.origemPeriodo &&
          tipoPeriodo == other.tipoPeriodo &&
          dataInicio.toUtc() == other.dataInicio.toUtc() &&
          dataFim.toUtc() == other.dataFim.toUtc();

  @override
  int get hashCode => Object.hash(
        id,
        solicitacaoId,
        origemPeriodo,
        tipoPeriodo,
        dataInicio.toUtc(),
        dataFim.toUtc(),
      );
}

