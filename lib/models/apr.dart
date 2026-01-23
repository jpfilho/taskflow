class APR {
  final String? id;
  final String taskId;
  
  // Informações Gerais
  final String? numeroApr;
  final DateTime? dataElaboracao;
  final String? responsavelElaboracao;
  final String? aprovador;
  final DateTime? dataAprovacao;
  
  // Dados da Atividade
  final String? atividade;
  final String? localExecucao;
  final DateTime? dataExecucao;
  final String? equipeExecutora;
  final String? coordenadorAtividade;
  
  // Análise de Riscos (JSON string ou texto estruturado)
  final String? riscosIdentificados;
  
  // Medidas de Controle (JSON string ou texto estruturado)
  final String? medidasControle;
  
  // EPIs Necessários
  final String? episNecessarios;
  
  // Permissões e Autorizações
  final String? permissoesNecessarias;
  final String? autorizacoesNecessarias;
  
  // Procedimentos de Emergência
  final String? procedimentosEmergencia;
  
  // Observações
  final String? observacoes;
  
  // Status
  final String status; // rascunho, aprovado, em_execucao, concluido
  
  final DateTime? createdAt;
  final DateTime? updatedAt;

  APR({
    this.id,
    required this.taskId,
    this.numeroApr,
    this.dataElaboracao,
    this.responsavelElaboracao,
    this.aprovador,
    this.dataAprovacao,
    this.atividade,
    this.localExecucao,
    this.dataExecucao,
    this.equipeExecutora,
    this.coordenadorAtividade,
    this.riscosIdentificados,
    this.medidasControle,
    this.episNecessarios,
    this.permissoesNecessarias,
    this.autorizacoesNecessarias,
    this.procedimentosEmergencia,
    this.observacoes,
    this.status = 'rascunho',
    this.createdAt,
    this.updatedAt,
  });

  factory APR.fromMap(Map<String, dynamic> map) {
    return APR(
      id: map['id'] as String?,
      taskId: map['task_id'] as String,
      numeroApr: map['numero_apr'] as String?,
      dataElaboracao: map['data_elaboracao'] != null
          ? DateTime.parse(map['data_elaboracao'] as String)
          : null,
      responsavelElaboracao: map['responsavel_elaboracao'] as String?,
      aprovador: map['aprovador'] as String?,
      dataAprovacao: map['data_aprovacao'] != null
          ? DateTime.parse(map['data_aprovacao'] as String)
          : null,
      atividade: map['atividade'] as String?,
      localExecucao: map['local_execucao'] as String?,
      dataExecucao: map['data_execucao'] != null
          ? DateTime.parse(map['data_execucao'] as String)
          : null,
      equipeExecutora: map['equipe_executora'] as String?,
      coordenadorAtividade: map['coordenador_atividade'] as String?,
      riscosIdentificados: map['riscos_identificados'] as String?,
      medidasControle: map['medidas_controle'] as String?,
      episNecessarios: map['epis_necessarios'] as String?,
      permissoesNecessarias: map['permissoes_necessarias'] as String?,
      autorizacoesNecessarias: map['autorizacoes_necessarias'] as String?,
      procedimentosEmergencia: map['procedimentos_emergencia'] as String?,
      observacoes: map['observacoes'] as String?,
      status: map['status'] as String? ?? 'rascunho',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'task_id': taskId,
      'numero_apr': numeroApr,
      'data_elaboracao': dataElaboracao?.toIso8601String(),
      'responsavel_elaboracao': responsavelElaboracao,
      'aprovador': aprovador,
      'data_aprovacao': dataAprovacao?.toIso8601String(),
      'atividade': atividade,
      'local_execucao': localExecucao,
      'data_execucao': dataExecucao?.toIso8601String(),
      'equipe_executora': equipeExecutora,
      'coordenador_atividade': coordenadorAtividade,
      'riscos_identificados': riscosIdentificados,
      'medidas_controle': medidasControle,
      'epis_necessarios': episNecessarios,
      'permissoes_necessarias': permissoesNecessarias,
      'autorizacoes_necessarias': autorizacoesNecessarias,
      'procedimentos_emergencia': procedimentosEmergencia,
      'observacoes': observacoes,
      'status': status,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  APR copyWith({
    String? id,
    String? taskId,
    String? numeroApr,
    DateTime? dataElaboracao,
    String? responsavelElaboracao,
    String? aprovador,
    DateTime? dataAprovacao,
    String? atividade,
    String? localExecucao,
    DateTime? dataExecucao,
    String? equipeExecutora,
    String? coordenadorAtividade,
    String? riscosIdentificados,
    String? medidasControle,
    String? episNecessarios,
    String? permissoesNecessarias,
    String? autorizacoesNecessarias,
    String? procedimentosEmergencia,
    String? observacoes,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return APR(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      numeroApr: numeroApr ?? this.numeroApr,
      dataElaboracao: dataElaboracao ?? this.dataElaboracao,
      responsavelElaboracao: responsavelElaboracao ?? this.responsavelElaboracao,
      aprovador: aprovador ?? this.aprovador,
      dataAprovacao: dataAprovacao ?? this.dataAprovacao,
      atividade: atividade ?? this.atividade,
      localExecucao: localExecucao ?? this.localExecucao,
      dataExecucao: dataExecucao ?? this.dataExecucao,
      equipeExecutora: equipeExecutora ?? this.equipeExecutora,
      coordenadorAtividade: coordenadorAtividade ?? this.coordenadorAtividade,
      riscosIdentificados: riscosIdentificados ?? this.riscosIdentificados,
      medidasControle: medidasControle ?? this.medidasControle,
      episNecessarios: episNecessarios ?? this.episNecessarios,
      permissoesNecessarias: permissoesNecessarias ?? this.permissoesNecessarias,
      autorizacoesNecessarias: autorizacoesNecessarias ?? this.autorizacoesNecessarias,
      procedimentosEmergencia: procedimentosEmergencia ?? this.procedimentosEmergencia,
      observacoes: observacoes ?? this.observacoes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
