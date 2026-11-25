import '../enums/task_apoio_enums.dart';

/// Intervalo de tempo normalizado em UTC para o motor de compatibilidade.
class TaskApoioIntervalo {
  final DateTime inicio;
  final DateTime fim;
  final String? origem;
  final String? taskId;

  TaskApoioIntervalo({
    required DateTime inicio,
    required DateTime fim,
    this.origem,
    this.taskId,
  })  : inicio = inicio.toUtc(),
        fim = fim.toUtc();

  bool get isValid => !fim.isBefore(inicio);
  Duration get duracao => isValid ? fim.difference(inicio) : Duration.zero;

  Map<String, dynamic> toJson() => {
        'inicio': inicio.toIso8601String(),
        'fim': fim.toIso8601String(),
        if (origem != null) 'origem': origem,
        if (taskId != null) 'task_id': taskId,
      };

  factory TaskApoioIntervalo.fromJson(Map<String, dynamic> json) {
    return TaskApoioIntervalo(
      inicio: DateTime.parse(json['inicio'].toString()),
      fim: DateTime.parse(json['fim'].toString()),
      origem: json['origem']?.toString(),
      taskId: json['task_id']?.toString(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskApoioIntervalo &&
          runtimeType == other.runtimeType &&
          inicio == other.inicio &&
          fim == other.fim;

  @override
  int get hashCode => Object.hash(inicio, fim);
}

/// Resultado estruturado do motor de compatibilidade temporal, recursos e compartilhamento.
class TaskApoioCompatibilidade {
  final TaskApoioStatusCompatibilidadeTemporal statusTemporal;
  final TaskApoioStatusCompatibilidadeRecurso statusRecursos;
  final double percentualCobertura;
  final Duration duracaoNecessaria;
  final Duration duracaoCoberta;
  final List<TaskApoioIntervalo> intervalosNecessariosConsolidados;
  final List<TaskApoioIntervalo> intervalosProgramadosConsolidados;
  final List<TaskApoioIntervalo> lacunas;
  final List<TaskApoioIntervalo> excedentes;
  final bool possuiPeriodosDescontinuos;
  final bool possuiApoioPrevioOuPosterior;
  final List<String> pendenciasRecursos;
  final List<String> alertasCompartilhamento;
  final String resumoExplicativo;

  const TaskApoioCompatibilidade({
    required this.statusTemporal,
    required this.statusRecursos,
    required this.percentualCobertura,
    required this.duracaoNecessaria,
    required this.duracaoCoberta,
    this.intervalosNecessariosConsolidados = const [],
    this.intervalosProgramadosConsolidados = const [],
    this.lacunas = const [],
    this.excedentes = const [],
    this.possuiPeriodosDescontinuos = false,
    this.possuiApoioPrevioOuPosterior = false,
    this.pendenciasRecursos = const [],
    this.alertasCompartilhamento = const [],
    this.resumoExplicativo = '',
  });

  bool get isTotalmenteCompativel =>
      statusTemporal == TaskApoioStatusCompatibilidadeTemporal.integral &&
      statusRecursos == TaskApoioStatusCompatibilidadeRecurso.compativel &&
      lacunas.isEmpty &&
      alertasCompartilhamento.isEmpty;

  Map<String, dynamic> toJson() {
    return {
      'status_temporal': statusTemporal.code,
      'status_recursos': statusRecursos.code,
      'percentual_cobertura': percentualCobertura,
      'duracao_necessaria_minutos': duracaoNecessaria.inMinutes,
      'duracao_coberta_minutos': duracaoCoberta.inMinutes,
      'intervalos_necessarios':
          intervalosNecessariosConsolidados.map((e) => e.toJson()).toList(),
      'intervalos_programados':
          intervalosProgramadosConsolidados.map((e) => e.toJson()).toList(),
      'lacunas': lacunas.map((e) => e.toJson()).toList(),
      'excedentes': excedentes.map((e) => e.toJson()).toList(),
      'possui_periodos_descontinuos': possuiPeriodosDescontinuos,
      'possui_apoio_previo_ou_posterior': possuiApoioPrevioOuPosterior,
      'pendencias_recursos': pendenciasRecursos,
      'alertas_compartilhamento': alertasCompartilhamento,
      'resumo_explicativo': resumoExplicativo,
    };
  }
}

