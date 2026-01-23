class CRC {
  final String? id;
  final String taskId;
  
  // Informações Gerais
  final String? numeroCrc;
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
  
  // Pontos Críticos (JSON string ou texto estruturado)
  final String? pontosCriticos;
  
  // Controles (JSON string ou texto estruturado)
  final String? controles;
  
  // Verificações (JSON string ou texto estruturado)
  final String? verificacoes;
  
  // Responsáveis
  final String? responsaveisVerificacao;
  
  // Observações
  final String? observacoes;
  
  // Status
  final String status; // rascunho, aprovado, em_execucao, concluido
  
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CRC({
    this.id,
    required this.taskId,
    this.numeroCrc,
    this.dataElaboracao,
    this.responsavelElaboracao,
    this.aprovador,
    this.dataAprovacao,
    this.atividade,
    this.localExecucao,
    this.dataExecucao,
    this.equipeExecutora,
    this.coordenadorAtividade,
    this.pontosCriticos,
    this.controles,
    this.verificacoes,
    this.responsaveisVerificacao,
    this.observacoes,
    this.status = 'rascunho',
    this.createdAt,
    this.updatedAt,
  });

  factory CRC.fromMap(Map<String, dynamic> map) {
    return CRC(
      id: map['id'] as String?,
      taskId: map['task_id'] as String,
      numeroCrc: map['numero_crc'] as String?,
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
      pontosCriticos: map['pontos_criticos'] as String?,
      controles: map['controles'] as String?,
      verificacoes: map['verificacoes'] as String?,
      responsaveisVerificacao: map['responsaveis_verificacao'] as String?,
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
      'numero_crc': numeroCrc,
      'data_elaboracao': dataElaboracao?.toIso8601String(),
      'responsavel_elaboracao': responsavelElaboracao,
      'aprovador': aprovador,
      'data_aprovacao': dataAprovacao?.toIso8601String(),
      'atividade': atividade,
      'local_execucao': localExecucao,
      'data_execucao': dataExecucao?.toIso8601String(),
      'equipe_executora': equipeExecutora,
      'coordenador_atividade': coordenadorAtividade,
      'pontos_criticos': pontosCriticos,
      'controles': controles,
      'verificacoes': verificacoes,
      'responsaveis_verificacao': responsaveisVerificacao,
      'observacoes': observacoes,
      'status': status,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  CRC copyWith({
    String? id,
    String? taskId,
    String? numeroCrc,
    DateTime? dataElaboracao,
    String? responsavelElaboracao,
    String? aprovador,
    DateTime? dataAprovacao,
    String? atividade,
    String? localExecucao,
    DateTime? dataExecucao,
    String? equipeExecutora,
    String? coordenadorAtividade,
    String? pontosCriticos,
    String? controles,
    String? verificacoes,
    String? responsaveisVerificacao,
    String? observacoes,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CRC(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      numeroCrc: numeroCrc ?? this.numeroCrc,
      dataElaboracao: dataElaboracao ?? this.dataElaboracao,
      responsavelElaboracao: responsavelElaboracao ?? this.responsavelElaboracao,
      aprovador: aprovador ?? this.aprovador,
      dataAprovacao: dataAprovacao ?? this.dataAprovacao,
      atividade: atividade ?? this.atividade,
      localExecucao: localExecucao ?? this.localExecucao,
      dataExecucao: dataExecucao ?? this.dataExecucao,
      equipeExecutora: equipeExecutora ?? this.equipeExecutora,
      coordenadorAtividade: coordenadorAtividade ?? this.coordenadorAtividade,
      pontosCriticos: pontosCriticos ?? this.pontosCriticos,
      controles: controles ?? this.controles,
      verificacoes: verificacoes ?? this.verificacoes,
      responsaveisVerificacao: responsaveisVerificacao ?? this.responsaveisVerificacao,
      observacoes: observacoes ?? this.observacoes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
