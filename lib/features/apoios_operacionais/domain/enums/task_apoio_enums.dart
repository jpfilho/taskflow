/// Enums e conversores seguros para o módulo de Gestão Integrada de Apoios Operacionais.
library;

enum TaskApoioStatus {
  pendente('PENDENTE', 'Pendente'),
  emAnalise('EM_ANALISE', 'Em análise'),
  contraproposta('CONTRAPROPOSTA', 'Contraproposta'),
  aceita('ACEITA', 'Aceita'),
  recusada('RECUSADA', 'Recusada'),
  cancelada('CANCELADA', 'Cancelada'),
  desconhecido('DESCONHECIDO', 'Desconhecido');

  final String dbValue;
  final String label;
  const TaskApoioStatus(this.dbValue, this.label);

  bool get isFinal => this == recusada || this == cancelada;
  bool get isAtiva => !isFinal && this != desconhecido;

  static TaskApoioStatus fromDb(String? value) {
    final normalized = value?.trim().toUpperCase();
    for (final item in values) {
      if (item.dbValue == normalized) return item;
    }
    return TaskApoioStatus.desconhecido;
  }
}

enum TaskApoioCriticidade {
  essencial('ESSENCIAL', 'Essencial'),
  complementar('COMPLEMENTAR', 'Complementar'),
  desconhecido('DESCONHECIDO', 'Desconhecido');

  final String dbValue;
  final String label;
  const TaskApoioCriticidade(this.dbValue, this.label);

  static TaskApoioCriticidade fromDb(String? value) {
    final normalized = value?.trim().toUpperCase();
    for (final item in values) {
      if (item.dbValue == normalized) return item;
    }
    return TaskApoioCriticidade.desconhecido;
  }
}

enum TaskApoioPrioridade {
  urgente('URGENTE', 'Urgente'),
  alta('ALTA', 'Alta'),
  media('MEDIA', 'Média'),
  baixa('BAIXA', 'Baixa'),
  desconhecido('DESCONHECIDO', 'Desconhecido');

  final String dbValue;
  final String label;
  const TaskApoioPrioridade(this.dbValue, this.label);

  static TaskApoioPrioridade fromDb(String? value) {
    final normalized = value?.trim().toUpperCase();
    for (final item in values) {
      if (item.dbValue == normalized) return item;
    }
    return TaskApoioPrioridade.desconhecido;
  }
}

enum TaskApoioModalidade {
  solicitacao('SOLICITACAO', 'Solicitação de apoio'),
  programacaoConjunta('PROGRAMACAO_CONJUNTA', 'Programação conjunta'),
  desconhecido('DESCONHECIDO', 'Desconhecido');

  final String dbValue;
  final String label;
  const TaskApoioModalidade(this.dbValue, this.label);

  static TaskApoioModalidade fromDb(String? value) {
    final normalized = value?.trim().toUpperCase();
    for (final item in values) {
      if (item.dbValue == normalized) return item;
    }
    return TaskApoioModalidade.desconhecido;
  }
}

enum TaskApoioFinalidadeVinculo {
  apoioOperacional('APOIO_OPERACIONAL', 'Apoio operacional'),
  vinculoDireto('VINCULO_DIRETO', 'Vínculo direto'),
  programacaoConjunta('PROGRAMACAO_CONJUNTA', 'Programação conjunta'),
  desconhecido('DESCONHECIDO', 'Desconhecido');

  final String dbValue;
  final String label;
  const TaskApoioFinalidadeVinculo(this.dbValue, this.label);

  static TaskApoioFinalidadeVinculo fromDb(String? value) {
    final normalized = value?.trim().toUpperCase();
    for (final item in values) {
      if (item.dbValue == normalized) return item;
    }
    return TaskApoioFinalidadeVinculo.desconhecido;
  }
}

enum TaskApoioStatusConfirmacaoVinculo {
  confirmado('CONFIRMADO', 'Vínculo confirmado'),
  aguardandoConfirmacao(
    'AGUARDANDO_CONFIRMACAO',
    'Aguardando confirmação da unidade responsável',
  ),
  recusado('RECUSADO', 'Vínculo recusado');

  final String dbValue;
  final String label;
  const TaskApoioStatusConfirmacaoVinculo(this.dbValue, this.label);

  static TaskApoioStatusConfirmacaoVinculo fromDb(String? value) {
    final normalized = value?.trim().toUpperCase();
    for (final item in values) {
      if (item.dbValue == normalized) return item;
    }
    return TaskApoioStatusConfirmacaoVinculo.confirmado;
  }
}

enum TaskApoioOrigemPeriodo {
  solicitacao('SOLICITACAO', 'Solicitado'),
  contraproposta('CONTRAPROPOSTA', 'Contraproposta'),
  acordado('ACORDADO', 'Acordado');

  final String dbValue;
  final String label;
  const TaskApoioOrigemPeriodo(this.dbValue, this.label);

  static TaskApoioOrigemPeriodo fromDb(String? value) {
    final normalized = value?.trim().toUpperCase();
    for (final item in values) {
      if (item.dbValue == normalized) return item;
    }
    return TaskApoioOrigemPeriodo.solicitacao;
  }
}

enum TaskApoioTipoPeriodo {
  continuo('CONTINUO', 'Contínuo'),
  parcial('PARCIAL', 'Parcial'),
  descontinuo('DESCONTINUO', 'Descontínuo'),
  previo('PREVIO', 'Prévio'),
  posterior('POSTERIOR', 'Posterior');

  final String dbValue;
  final String label;
  const TaskApoioTipoPeriodo(this.dbValue, this.label);

  static TaskApoioTipoPeriodo fromDb(String? value) {
    final normalized = value?.trim().toUpperCase();
    for (final item in values) {
      if (item.dbValue == normalized) return item;
    }
    return TaskApoioTipoPeriodo.continuo;
  }
}

enum TaskApoioSituacaoOperacional {
  aguardandoAnalise('AGUARDANDO_ANALISE', 'Aguardando análise'),
  emNegociacao('EM_NEGOCIACAO', 'Em negociação'),
  recusada('RECUSADA', 'Recusada'),
  cancelada('CANCELADA', 'Cancelada'),
  aceitaSemProgramacao('ACEITA_SEM_PROGRAMACAO', 'Aceita sem programação'),
  parcialmenteProgramada('PARCIALMENTE_PROGRAMADA', 'Parcialmente programada'),
  programadaComIncompatibilidade(
    'PROGRAMADA_COM_INCOMPATIBILIDADE',
    'Programada com incompatibilidade',
  ),
  programadaComRecursosPendentes(
    'PROGRAMADA_COM_RECURSOS_PENDENTES',
    'Programada com recursos pendentes',
  ),
  programadaComRecursosNaoVerificados(
    'PROGRAMADA_COM_RECURSOS_NAO_VERIFICADOS',
    'Programada com recursos não verificados',
  ),
  programadaCompativel('PROGRAMADA_COMPATIVEL', 'Programada e compatível'),
  emAndamento('EM_ANDAMENTO', 'Em andamento'),
  concluida('CONCLUIDA', 'Concluída');

  final String code;
  final String label;
  const TaskApoioSituacaoOperacional(this.code, this.label);
}

enum TaskApoioSituacaoGerencial {
  semDependencias('SEM_DEPENDENCIAS', 'Sem dependências registradas'),
  apenasComplementares('APENAS_COMPLEMENTARES', 'Apenas apoios complementares'),
  aguardandoConfirmacaoEssencial(
    'AGUARDANDO_CONFIRMACAO_ESSENCIAL',
    'Aguardando confirmação de apoio essencial',
  ),
  essencialAceitoSemProgramacao(
    'ESSENCIAL_ACEITO_SEM_PROGRAMACAO',
    'Apoio essencial aceito sem programação',
  ),
  essencialParcialmenteProgramado(
    'ESSENCIAL_PARCIALMENTE_PROGRAMADO',
    'Apoio essencial parcialmente programado',
  ),
  programacaoComRiscoApoio(
    'PROGRAMACAO_COM_RISCO_APOIO',
    'Programação com risco relacionado a apoio',
  ),
  essenciaisProgramadosCompativeis(
    'ESSENCIAIS_PROGRAMADOS_COMPATIVEIS',
    'Apoios essenciais programados e compatíveis',
  ),
  essenciaisConcluidos('ESSENCIAIS_CONCLUIDOS', 'Apoios essenciais concluídos');

  final String code;
  final String label;
  const TaskApoioSituacaoGerencial(this.code, this.label);
}

enum TaskApoioSyncStatus {
  confirmadoServidor('CONFIRMADO_SERVIDOR', 'Confirmado pelo servidor'),
  pendenteSync('PENDENTE_SYNC', 'Pendente de sincronização'),
  emProcessamento('EM_PROCESSAMENTO', 'Em processamento'),
  rejeitado('REJEITADO', 'Rejeitado'),
  conflitoVersao('CONFLITO_VERSAO', 'Conflito de versão'),
  exigeConexao('EXIGE_CONEXAO', 'Exige conexão');

  final String code;
  final String label;
  const TaskApoioSyncStatus(this.code, this.label);

  static TaskApoioSyncStatus fromCode(String? code) {
    for (final item in values) {
      if (item.code == code) return item;
    }
    return TaskApoioSyncStatus.confirmadoServidor;
  }
}

enum TaskApoioPapelAtor {
  solicitante,
  unidadeApoio,
}

enum TaskApoioStatusCompatibilidadeTemporal {
  integral('INTEGRAL', 'Cobertura integral'),
  parcial('PARCIAL', 'Cobertura parcial'),
  semCobertura('SEM_COBERTURA', 'Sem cobertura'),
  incompativel('INCOMPATIVEL', 'Incompatível');

  final String code;
  final String label;
  const TaskApoioStatusCompatibilidadeTemporal(this.code, this.label);
}

enum TaskApoioStatusCompatibilidadeRecurso {
  compativel('COMPATIVEL', 'Recursos compatíveis'),
  pendente('PENDENTE', 'Recursos pendentes'),
  incompativel('INCOMPATIVEL', 'Recursos incompatíveis'),
  conflitoCompartilhamento(
    'CONFLITO_COMPARTILHAMENTO',
    'Conflito de compartilhamento',
  ),
  naoVerificado('NAO_VERIFICADO', 'Recursos não verificados');

  final String code;
  final String label;
  const TaskApoioStatusCompatibilidadeRecurso(this.code, this.label);
}

