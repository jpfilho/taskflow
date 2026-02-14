/// Uma ordem em que o empregado está programado (atribuída em tarefas) em um mês.
/// Pode haver mais de um registro por ordem quando a mesma ordem está em várias tarefas.
class OrdemProgramadaEmpregadoMes {
  final String matricula;
  final int ano;
  final int mes;
  final String anoMes;
  final String ordem;
  final String? tipo;
  final String? sala;
  final String? textoBreve;
  final String? regionalId;
  final String? divisaoId;
  final String? segmentoId;
  /// ID da tarefa à qual a ordem está atribuída (para link).
  final String? taskId;
  /// Nome/título da tarefa.
  final String? taskTarefa;
  /// Status da tarefa (ex: PROG, CONC, ANDA).
  final String? taskStatus;
  /// Local detalhado (nome do local ou denominacao/local_instalacao da ordem).
  final String? localDetalhe;

  OrdemProgramadaEmpregadoMes({
    required this.matricula,
    required this.ano,
    required this.mes,
    required this.anoMes,
    required this.ordem,
    this.tipo,
    this.sala,
    this.textoBreve,
    this.regionalId,
    this.divisaoId,
    this.segmentoId,
    this.taskId,
    this.taskTarefa,
    this.taskStatus,
    this.localDetalhe,
  });

  factory OrdemProgramadaEmpregadoMes.fromMap(Map<String, dynamic> map) {
    return OrdemProgramadaEmpregadoMes(
      matricula: (map['matricula'] as String? ?? '').trim(),
      ano: (map['ano'] as num?)?.toInt() ?? 0,
      mes: (map['mes'] as num?)?.toInt() ?? 0,
      anoMes: (map['ano_mes'] as String? ?? '').trim(),
      ordem: (map['ordem'] as String? ?? '').trim(),
      tipo: (map['tipo'] as String?)?.trim(),
      sala: (map['sala'] as String?)?.trim(),
      textoBreve: (map['texto_breve'] as String?)?.trim(),
      regionalId: map['regional_id'] as String?,
      divisaoId: map['divisao_id'] as String?,
      segmentoId: map['segmento_id'] as String?,
      taskId: (map['task_id'] as String?)?.trim(),
      taskTarefa: (map['task_tarefa'] as String?)?.trim(),
      taskStatus: (map['task_status'] as String?)?.trim(),
      localDetalhe: (map['local_detalhe'] as String?)?.trim(),
    );
  }
}
