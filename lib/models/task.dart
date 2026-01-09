// Classe para representar um segmento do Gantt
class GanttSegment {
  final DateTime dataInicio;
  final DateTime dataFim;
  final String label;
  final String tipo; // 'BEA', 'FER', 'COMP', 'TRN', 'BSL', 'APO', 'OUT', 'ADM'
  final String tipoPeriodo; // 'EXECUCAO', 'PLANEJAMENTO', 'DESLOCAMENTO'

  GanttSegment({
    required this.dataInicio,
    required this.dataFim,
    required this.label,
    required this.tipo,
    this.tipoPeriodo = 'EXECUCAO',
  });

  GanttSegment copyWith({
    DateTime? dataInicio,
    DateTime? dataFim,
    String? label,
    String? tipo,
    String? tipoPeriodo,
  }) {
    return GanttSegment(
      dataInicio: dataInicio ?? this.dataInicio,
      dataFim: dataFim ?? this.dataFim,
      label: label ?? this.label,
      tipo: tipo ?? this.tipo,
      tipoPeriodo: tipoPeriodo ?? this.tipoPeriodo,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dataInicio': dataInicio.toIso8601String(),
      'dataFim': dataFim.toIso8601String(),
      'label': label,
      'tipo': tipo,
      'tipoPeriodo': tipoPeriodo,
    };
  }

  factory GanttSegment.fromMap(Map<String, dynamic> map) {
    return GanttSegment(
      dataInicio: DateTime.parse(map['dataInicio'] as String),
      dataFim: DateTime.parse(map['dataFim'] as String),
      label: map['label'] as String? ?? '',
      tipo: map['tipo'] as String,
      tipoPeriodo: map['tipoPeriodo'] as String? ?? 'EXECUCAO',
    );
  }
}

// Classe para representar períodos específicos de um executor
class ExecutorPeriod {
  final String executorId;
  final String executorNome;
  final List<GanttSegment> periods;

  ExecutorPeriod({
    required this.executorId,
    required this.executorNome,
    this.periods = const [],
  });

  ExecutorPeriod copyWith({
    String? executorId,
    String? executorNome,
    List<GanttSegment>? periods,
  }) {
    return ExecutorPeriod(
      executorId: executorId ?? this.executorId,
      executorNome: executorNome ?? this.executorNome,
      periods: periods ?? this.periods,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'executorId': executorId,
      'executorNome': executorNome,
      'periods': periods.map((p) => p.toMap()).toList(),
    };
  }

  factory ExecutorPeriod.fromMap(Map<String, dynamic> map) {
    return ExecutorPeriod(
      executorId: map['executorId'] as String,
      executorNome: map['executorNome'] as String,
      periods: (map['periods'] as List<dynamic>?)
          ?.map((p) => GanttSegment.fromMap(p as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
}

// Classe para informações de executores de equipe
class EquipeExecutorInfo {
  final String executorNome;
  final String papel; // 'FISCAL', 'TST', 'ENCARREGADO', 'EXECUTOR'

  EquipeExecutorInfo({
    required this.executorNome,
    required this.papel,
  });
}

// Classe principal para representar uma tarefa
class Task {
  final String id;
  
  // IDs de relacionamento (novos campos)
  final String? statusId;
  final String? regionalId;
  final String? divisaoId;
  final String? segmentoId;
  final List<String> localIds;
  final List<String> executorIds;
  final List<String> equipeIds;
  
  // Campos antigos (deprecated, para compatibilidade)
  final String? localId;
  final String? equipeId;
  
  // Campos de texto (nomes)
  final String status; // 'ANDA', 'CONC', 'PROG', 'CANC', 'RPAR'
  final String statusNome;
  final String regional;
  final String divisao;
  final List<String> locais;
  final String segmento;
  final List<String> equipes;
  final List<EquipeExecutorInfo>? equipeExecutores;
  
  // Campos principais da tarefa
  final String tipo;
  final String? ordem;
  final String tarefa;
  final List<String> executores;
  final String executor; // Deprecated, usar executores
  final String frota;
  final String coordenador;
  final String si;
  
  // Datas
  final DateTime dataInicio;
  final DateTime dataFim;
  final DateTime? dataCriacao;
  final DateTime? dataAtualizacao;
  
  // Segmentos do Gantt
  final List<GanttSegment> ganttSegments;
  
  // Períodos específicos por executor (permite que cada executor tenha períodos diferentes)
  final List<ExecutorPeriod> executorPeriods;
  
  // Campos adicionais
  final String? observacoes;
  final double? horasPrevistas;
  final double? horasExecutadas;
  final String? prioridade;
  final String? parentId;

  Task({
    required this.id,
    this.statusId,
    this.regionalId,
    this.divisaoId,
    this.segmentoId,
    this.localIds = const [],
    this.executorIds = const [],
    this.equipeIds = const [],
    this.localId,
    this.equipeId,
    required this.status,
    this.statusNome = '',
    required this.regional,
    required this.divisao,
    this.locais = const [],
    this.segmento = '',
    this.equipes = const [],
    this.equipeExecutores,
    required this.tipo,
    this.ordem,
    required this.tarefa,
    this.executores = const [],
    this.executor = '',
    this.frota = '',
    required this.coordenador,
    this.si = '',
    required this.dataInicio,
    required this.dataFim,
    this.dataCriacao,
    this.dataAtualizacao,
    this.ganttSegments = const [],
    this.executorPeriods = const [],
    this.observacoes,
    this.horasPrevistas,
    this.horasExecutadas,
    this.prioridade,
    this.parentId,
  });

  // Getter para verificar se é uma tarefa principal (não subtarefa)
  bool get isMainTask => parentId == null || parentId!.isEmpty;

  // Método para criar cópia com alterações
  Task copyWith({
    String? id,
    String? statusId,
    String? regionalId,
    String? divisaoId,
    String? segmentoId,
    List<String>? localIds,
    List<String>? executorIds,
    List<String>? equipeIds,
    String? localId,
    String? equipeId,
    String? status,
    String? statusNome,
    String? regional,
    String? divisao,
    List<String>? locais,
    String? segmento,
    List<String>? equipes,
    List<EquipeExecutorInfo>? equipeExecutores,
    String? tipo,
    String? ordem,
    String? tarefa,
    List<String>? executores,
    String? executor,
    String? frota,
    String? coordenador,
    String? si,
    DateTime? dataInicio,
    DateTime? dataFim,
    DateTime? dataCriacao,
    DateTime? dataAtualizacao,
    List<GanttSegment>? ganttSegments,
    List<ExecutorPeriod>? executorPeriods,
    String? observacoes,
    double? horasPrevistas,
    double? horasExecutadas,
    String? prioridade,
    String? parentId,
  }) {
    return Task(
      id: id ?? this.id,
      statusId: statusId ?? this.statusId,
      regionalId: regionalId ?? this.regionalId,
      divisaoId: divisaoId ?? this.divisaoId,
      segmentoId: segmentoId ?? this.segmentoId,
      localIds: localIds ?? this.localIds,
      executorIds: executorIds ?? this.executorIds,
      equipeIds: equipeIds ?? this.equipeIds,
      localId: localId ?? this.localId,
      equipeId: equipeId ?? this.equipeId,
      status: status ?? this.status,
      statusNome: statusNome ?? this.statusNome,
      regional: regional ?? this.regional,
      divisao: divisao ?? this.divisao,
      locais: locais ?? this.locais,
      segmento: segmento ?? this.segmento,
      equipes: equipes ?? this.equipes,
      equipeExecutores: equipeExecutores ?? this.equipeExecutores,
      tipo: tipo ?? this.tipo,
      ordem: ordem ?? this.ordem,
      tarefa: tarefa ?? this.tarefa,
      executores: executores ?? this.executores,
      executor: executor ?? this.executor,
      frota: frota ?? this.frota,
      coordenador: coordenador ?? this.coordenador,
      si: si ?? this.si,
      dataInicio: dataInicio ?? this.dataInicio,
      dataFim: dataFim ?? this.dataFim,
      dataCriacao: dataCriacao ?? this.dataCriacao,
      dataAtualizacao: dataAtualizacao ?? this.dataAtualizacao,
      ganttSegments: ganttSegments ?? this.ganttSegments,
      executorPeriods: executorPeriods ?? this.executorPeriods,
      observacoes: observacoes ?? this.observacoes,
      horasPrevistas: horasPrevistas ?? this.horasPrevistas,
      horasExecutadas: horasExecutadas ?? this.horasExecutadas,
      prioridade: prioridade ?? this.prioridade,
      parentId: parentId ?? this.parentId,
    );
  }

  @override
  String toString() {
    return 'Task(id: $id, tarefa: $tarefa, status: $status, tipo: $tipo)';
  }
}
