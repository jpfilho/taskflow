/// Especificação estruturada opcional de requisitos de recursos para uma solicitação de apoio.
/// Permite solicitações genéricas/descritivas (quando todos os campos são nulos/vazios)
/// ou validação automática quando preenchida.
class TaskApoioRequisitoRecurso {
  final String? tipoVeiculo;
  final String? equipamentoNecessario;
  final int? quantidadeVeiculos;
  final int? quantidadeOperadores;
  final String? capacidadeMinima;
  final String? equipeNecessaria;
  final String? localAtendimento;
  final bool exigeOperador;
  final bool exigeVeiculo;
  final bool especificacaoEstruturada;

  const TaskApoioRequisitoRecurso({
    this.tipoVeiculo,
    this.equipamentoNecessario,
    this.quantidadeVeiculos,
    this.quantidadeOperadores,
    this.capacidadeMinima,
    this.equipeNecessaria,
    this.localAtendimento,
    this.exigeOperador = false,
    this.exigeVeiculo = false,
    this.especificacaoEstruturada = false,
  });

  bool get possuiExigenciaVerificavel =>
      especificacaoEstruturada ||
      exigeVeiculo ||
      exigeOperador ||
      (tipoVeiculo != null && tipoVeiculo!.trim().isNotEmpty) ||
      (equipamentoNecessario != null && equipamentoNecessario!.trim().isNotEmpty) ||
      (quantidadeVeiculos != null && quantidadeVeiculos! > 0) ||
      (quantidadeOperadores != null && quantidadeOperadores! > 0) ||
      (equipeNecessaria != null && equipeNecessaria!.trim().isNotEmpty);

  factory TaskApoioRequisitoRecurso.fromJson(Map<String, dynamic> json) {
    return TaskApoioRequisitoRecurso(
      tipoVeiculo: (json['tipo_veiculo'] ?? json['tipoVeiculo'])?.toString(),
      equipamentoNecessario:
          (json['equipamento_necessario'] ?? json['equipamentoNecessario'])
              ?.toString(),
      quantidadeVeiculos:
          (json['quantidade_veiculos'] ?? json['quantidadeVeiculos'] as num?)
              ?.toInt(),
      quantidadeOperadores:
          (json['quantidade_operadores'] ?? json['quantidadeOperadores'] as num?)
              ?.toInt(),
      capacidadeMinima:
          (json['capacidade_minima'] ?? json['capacidadeMinima'])?.toString(),
      equipeNecessaria:
          (json['equipe_necessaria'] ?? json['equipeNecessaria'])?.toString(),
      localAtendimento:
          (json['local_atendimento'] ?? json['localAtendimento'])?.toString(),
      exigeOperador:
          (json['exige_operador'] ?? json['exigeOperador']) == true,
      exigeVeiculo: (json['exige_veiculo'] ?? json['exigeVeiculo']) == true,
      especificacaoEstruturada:
          (json['especificacao_estruturada'] ?? json['especificacaoEstruturada']) ==
              true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tipo_veiculo': tipoVeiculo,
      'equipamento_necessario': equipamentoNecessario,
      'quantidade_veiculos': quantidadeVeiculos,
      'quantidade_operadores': quantidadeOperadores,
      'capacidade_minima': capacidadeMinima,
      'equipe_necessaria': equipeNecessaria,
      'local_atendimento': localAtendimento,
      'exige_operador': exigeOperador,
      'exige_veiculo': exigeVeiculo,
      'especificacao_estruturada': especificacaoEstruturada,
    };
  }

  TaskApoioRequisitoRecurso copyWith({
    String? tipoVeiculo,
    String? equipamentoNecessario,
    int? quantidadeVeiculos,
    int? quantidadeOperadores,
    String? capacidadeMinima,
    String? equipeNecessaria,
    String? localAtendimento,
    bool? exigeOperador,
    bool? exigeVeiculo,
    bool? especificacaoEstruturada,
  }) {
    return TaskApoioRequisitoRecurso(
      tipoVeiculo: tipoVeiculo ?? this.tipoVeiculo,
      equipamentoNecessario:
          equipamentoNecessario ?? this.equipamentoNecessario,
      quantidadeVeiculos: quantidadeVeiculos ?? this.quantidadeVeiculos,
      quantidadeOperadores: quantidadeOperadores ?? this.quantidadeOperadores,
      capacidadeMinima: capacidadeMinima ?? this.capacidadeMinima,
      equipeNecessaria: equipeNecessaria ?? this.equipeNecessaria,
      localAtendimento: localAtendimento ?? this.localAtendimento,
      exigeOperador: exigeOperador ?? this.exigeOperador,
      exigeVeiculo: exigeVeiculo ?? this.exigeVeiculo,
      especificacaoEstruturada:
          especificacaoEstruturada ?? this.especificacaoEstruturada,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskApoioRequisitoRecurso &&
          runtimeType == other.runtimeType &&
          tipoVeiculo == other.tipoVeiculo &&
          equipamentoNecessario == other.equipamentoNecessario &&
          quantidadeVeiculos == other.quantidadeVeiculos &&
          quantidadeOperadores == other.quantidadeOperadores &&
          capacidadeMinima == other.capacidadeMinima &&
          equipeNecessaria == other.equipeNecessaria &&
          localAtendimento == other.localAtendimento &&
          exigeOperador == other.exigeOperador &&
          exigeVeiculo == other.exigeVeiculo &&
          especificacaoEstruturada == other.especificacaoEstruturada;

  @override
  int get hashCode => Object.hash(
        tipoVeiculo,
        equipamentoNecessario,
        quantidadeVeiculos,
        quantidadeOperadores,
        capacidadeMinima,
        equipeNecessaria,
        localAtendimento,
        exigeOperador,
        exigeVeiculo,
        especificacaoEstruturada,
      );
}

