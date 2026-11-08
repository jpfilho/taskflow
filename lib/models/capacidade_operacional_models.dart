/// Modelos de Domínio para Gestão de Capacidade Operacional,
/// Alocação de Esforço, Confiabilidade, Priorização Explicável e Simulação Não-Destrutiva.
library;

/// Nível de confiabilidade dos indicadores de capacidade e saldo mensal.
enum NivelConfiabilidadeCapacidade {
  alta,
  media,
  baixa,
}

/// Estado gerencial do balanceamento mensal entre capacidade e demanda.
enum StatusBalanceamentoMensal {
  sobrecarga, // Comprometimento > 100% (Saldo negativo)
  cargaElevada, // Comprometimento entre 85% e 100%
  equilibrado, // Comprometimento entre 50% e 84%
  ocioso, // Comprometimento < 50%
}

/// Origem e semântica da estimativa de esforço de uma Nota SAP.
enum OrigemEstimativaNota {
  confirmadaMaiorZero, // Análise concluída com horas > 0
  zeroConfirmado, // Análise concluída explicitamente com 0h (justificada como administrativa/sem campo)
  zeroPadrao, // Valor 0.0 registrado por default/padrão de sistema sem análise concluída
  ausente, // Nenhuma análise técnica cadastrada
}

/// Configurações e premissas operacionais para o cálculo de capacidade.
class ConfiguracaoCapacidade {
  final double jornadaDiariaHoras; // Padrão: 8.0h
  final double fatorEficiencia; // Padrão: 0.85 (85% do tempo em atividade direta)
  final bool apenasEquipesAtivas; // Se true, considera apenas equipes com ativo = true
  final bool incluirTerceirizados; // Se false, filtra apenas próprios
  final bool incluirExecutoresSemEquipe; // Se true, computa executores avulsos da unidade
  final double horasPadraoBenchmarkPorNota; // Benchmark opcional do SAP (ex: 4.5h)
  final double limiteConfiabilidadeMinimo; // Padrão: 0.80 (80% de cobertura para considerar saldo confiável)
  final String? regionalId;
  final String? divisaoId;
  final String? segmentoId;
  final String? centroTrabalho;

  const ConfiguracaoCapacidade({
    this.jornadaDiariaHoras = 8.0,
    this.fatorEficiencia = 0.85,
    this.apenasEquipesAtivas = true,
    this.incluirTerceirizados = true,
    this.incluirExecutoresSemEquipe = false,
    this.horasPadraoBenchmarkPorNota = 4.5,
    this.limiteConfiabilidadeMinimo = 0.80,
    this.regionalId,
    this.divisaoId,
    this.segmentoId,
    this.centroTrabalho,
  });

  ConfiguracaoCapacidade copyWith({
    double? jornadaDiariaHoras,
    double? fatorEficiencia,
    bool? apenasEquipesAtivas,
    bool? incluirTerceirizados,
    bool? incluirExecutoresSemEquipe,
    double? horasPadraoBenchmarkPorNota,
    double? limiteConfiabilidadeMinimo,
    String? regionalId,
    String? divisaoId,
    String? segmentoId,
    String? centroTrabalho,
    bool clearFiltros = false,
  }) {
    return ConfiguracaoCapacidade(
      jornadaDiariaHoras: jornadaDiariaHoras ?? this.jornadaDiariaHoras,
      fatorEficiencia: fatorEficiencia ?? this.fatorEficiencia,
      apenasEquipesAtivas: apenasEquipesAtivas ?? this.apenasEquipesAtivas,
      incluirTerceirizados: incluirTerceirizados ?? this.incluirTerceirizados,
      incluirExecutoresSemEquipe: incluirExecutoresSemEquipe ?? this.incluirExecutoresSemEquipe,
      horasPadraoBenchmarkPorNota: horasPadraoBenchmarkPorNota ?? this.horasPadraoBenchmarkPorNota,
      limiteConfiabilidadeMinimo: limiteConfiabilidadeMinimo ?? this.limiteConfiabilidadeMinimo,
      regionalId: clearFiltros ? null : (regionalId ?? this.regionalId),
      divisaoId: clearFiltros ? null : (divisaoId ?? this.divisaoId),
      segmentoId: clearFiltros ? null : (segmentoId ?? this.segmentoId),
      centroTrabalho: clearFiltros ? null : (centroTrabalho ?? this.centroTrabalho),
    );
  }
}

/// Apuração do calendário de um mês específico com dias úteis e feriados.
class CalendarioMesInfo {
  final int ano;
  final int mes;
  final int diasNoMes;
  final int diasFimDeSemana;
  final int feriadosEmDiasUteis;
  final int diasUteis;
  final List<String> feriadosNomes;

  const CalendarioMesInfo({
    required this.ano,
    required this.mes,
    required this.diasNoMes,
    required this.diasFimDeSemana,
    required this.feriadosEmDiasUteis,
    required this.diasUteis,
    this.feriadosNomes = const [],
  });

  String get chaveAnoMes => '$ano-${mes.toString().padLeft(2, "0")}';
}

/// Registro de indisponibilidade de um executor (Férias, Folga, Compensação, etc.).
class IndisponibilidadeExecutor {
  final String executorId;
  final String executorNome;
  final String tipo; // 'FERIAS', 'FOLGA', 'COMP', 'ADMIN'
  final DateTime dataInicio;
  final DateTime dataFim;
  final double horasIndisponiveisNoMes;

  const IndisponibilidadeExecutor({
    required this.executorId,
    required this.executorNome,
    required this.tipo,
    required this.dataInicio,
    required this.dataFim,
    required this.horasIndisponiveisNoMes,
  });
}

/// Alocação de esforço em tarefa operacional no mês (sem duplicidades).
class EsforcoTarefaMes {
  final String taskId;
  final String tarefaNome;
  final String tipo;
  final String status;
  final DateTime dataInicio;
  final DateTime dataFim;
  final List<String> executorIds;
  final int quantidadeExecutores;
  final double duracaoNoMesHoras;
  final double esforcoTotalHoras; // duracaoNoMesHoras * quantidadeExecutores reais

  const EsforcoTarefaMes({
    required this.taskId,
    required this.tarefaNome,
    required this.tipo,
    required this.status,
    required this.dataInicio,
    required this.dataFim,
    required this.executorIds,
    required this.quantidadeExecutores,
    required this.duracaoNoMesHoras,
    required this.esforcoTotalHoras,
  });
}

/// Capacidade calculada para um executor individual em um mês específico.
class CapacidadeExecutorMes {
  final String executorId;
  final String executorNome;
  final String? matricula;
  final String? funcao;
  final String? equipeId;
  final String? equipeNome;
  final String? divisaoId;
  final String? regionalId;
  final String? segmentoId;
  final List<String> segmentoIds;
  final int ano;
  final int mes;
  final int diasUteis;
  final double jornadaDiaria;
  final double horasBrutas;
  final double horasIndisponiveis;
  final double fatorEficiencia;
  final double horasAjustadas;
  final double horasComprometidas; // Horas em tarefas operacionais ativas no mês
  final double saldoHoras;

  const CapacidadeExecutorMes({
    required this.executorId,
    required this.executorNome,
    this.matricula,
    this.funcao,
    this.equipeId,
    this.equipeNome,
    this.divisaoId,
    this.regionalId,
    this.segmentoId,
    this.segmentoIds = const [],
    required this.ano,
    required this.mes,
    required this.diasUteis,
    required this.jornadaDiaria,
    required this.horasBrutas,
    required this.horasIndisponiveis,
    required this.fatorEficiencia,
    required this.horasAjustadas,
    required this.horasComprometidas,
    required this.saldoHoras,
  });

  bool get temEquipeVinculada => equipeId != null && equipeId!.isNotEmpty;
  double get taxaComprometimento => horasAjustadas > 0 ? (horasComprometidas / horasAjustadas) * 100 : 0.0;
}

/// Detalhe de estimativa de uma nota individual para auditoria e drill-down.
class ItemEstimativaNota {
  final String notaSapId;
  final String numeroNota;
  final String? descricao;
  final double horasEstimadas;
  final OrigemEstimativaNota origem;
  final bool jaPossuiTarefaProgramada;
  final String? taskIdVinculada;

  const ItemEstimativaNota({
    required this.notaSapId,
    required this.numeroNota,
    this.descricao,
    required this.horasEstimadas,
    required this.origem,
    required this.jaPossuiTarefaProgramada,
    this.taskIdVinculada,
  });
}

/// Consolidação da demanda prevista da carteira em um mês/ano.
/// Segrega rigorosamente horas confirmadas de notas sem estimativa e evita duplicidade com tarefas.
class DemandaCarteiraMes {
  final int ano;
  final int mes;
  final int totalNotasPrevistas;
  final int notasComEstimativa;
  final int notasZeroConfirmado;
  final int notasZeroPadrao;
  final int notasSemEstimativa;
  final int notasJaProgramadas;
  final double horasEstimadasConfirmadas;
  final double horasEstimadasNaoProgramadas; // Horas que ainda não foram convertidas em tarefa operacional
  final double percentualCoberturaEstimativa;
  final double horasBenchmarkHistorico; // Informativo paramétrico do SAP
  final List<ItemEstimativaNota> itens;

  const DemandaCarteiraMes({
    required this.ano,
    required this.mes,
    required this.totalNotasPrevistas,
    required this.notasComEstimativa,
    this.notasZeroConfirmado = 0,
    this.notasZeroPadrao = 0,
    required this.notasSemEstimativa,
    this.notasJaProgramadas = 0,
    required this.horasEstimadasConfirmadas,
    double? horasEstimadasNaoProgramadas,
    required this.percentualCoberturaEstimativa,
    this.horasBenchmarkHistorico = 0.0,
    this.itens = const [],
  }) : horasEstimadasNaoProgramadas = horasEstimadasNaoProgramadas ?? horasEstimadasConfirmadas;

  /// Indica se a demanda possui risco de incerteza por falta de estimativa em mais de 20% das notas.
  bool get temRiscoIncerteza => notasSemEstimativa > 0 && percentualCoberturaEstimativa < 80.0;
}

/// Memória de cálculo detalhada para transparência gerencial.
class MemoriaCalculoBalanceamento {
  final String passo1Calendario;
  final String passo2CapacidadeBruta;
  final String passo3Indisponibilidades;
  final String passo4CapacidadeAjustada;
  final String passo5HorasComprometidas;
  final String passo6DemandaEstimada;
  final String passo7SaldoEConfiabilidade;

  const MemoriaCalculoBalanceamento({
    required this.passo1Calendario,
    required this.passo2CapacidadeBruta,
    required this.passo3Indisponibilidades,
    required this.passo4CapacidadeAjustada,
    required this.passo5HorasComprometidas,
    required this.passo6DemandaEstimada,
    required this.passo7SaldoEConfiabilidade,
  });
}

/// Balanço gerencial mensal consolidando Capacidade vs Programação vs Demanda Prevista.
class BalanceamentoCapacidadeMes {
  final int ano;
  final int mes;
  final CalendarioMesInfo calendario;
  final int totalExecutores;
  final int totalExecutoresEmEquipes;
  final int totalExecutoresSemEquipe;
  final double horasBrutas;
  final double horasIndisponiveis;
  final double horasAjustadas;
  final double horasComprometidasProgramadas;
  final double capacidadeDisponivel; // horasAjustadas - horasComprometidasProgramadas
  final DemandaCarteiraMes demanda;
  final double saldoHorasCalculado; // capacidadeDisponivel - demanda.horasEstimadasNaoProgramadas
  final double taxaComprometimentoTotal; // (horasComprometidas + demandaNaoProgramada) / horasAjustadas
  final StatusBalanceamentoMensal status;
  final NivelConfiabilidadeCapacidade nivelConfiabilidade;
  final bool isSaldoConfiavel;
  final String motivoConfiabilidade;
  final MemoriaCalculoBalanceamento? memoriaCalculo;

  const BalanceamentoCapacidadeMes({
    required this.ano,
    required this.mes,
    required this.calendario,
    required this.totalExecutores,
    required this.totalExecutoresEmEquipes,
    required this.totalExecutoresSemEquipe,
    required this.horasBrutas,
    required this.horasIndisponiveis,
    required this.horasAjustadas,
    required this.horasComprometidasProgramadas,
    required this.capacidadeDisponivel,
    required this.demanda,
    required this.saldoHorasCalculado,
    required this.taxaComprometimentoTotal,
    required this.status,
    required this.nivelConfiabilidade,
    required this.isSaldoConfiavel,
    required this.motivoConfiabilidade,
    this.memoriaCalculo,
  });

  String get labelMesAno => '${mes.toString().padLeft(2, "0")}/$ano';
}

// =============================================================================
// INCREMENTO 6: PRIORIZAÇÃO EXPLICÁVEL & SIMULAÇÃO NÃO-DESTRUTIVA
// =============================================================================

/// Categoria do Score de Prioridade Gerencial da Nota.
enum CategoriaPrioridadeNota {
  critica('Crítica', 80.0),
  alta('Alta', 60.0),
  media('Média', 40.0),
  baixa('Baixa', 0.0);

  final String label;
  final double notaCorte;

  const CategoriaPrioridadeNota(this.label, this.notaCorte);
}

/// Fator individual avaliado no cálculo do score explicável.
class FatorPrioridadeNota {
  final String nome;
  final double pontosObtidos;
  final double pesoMaximo;
  final String justificativa;

  const FatorPrioridadeNota({
    required this.nome,
    required this.pontosObtidos,
    required this.pesoMaximo,
    required this.justificativa,
  });
}

/// Score Explicável de Prioridade de uma Nota SAP (Consultivo e Não-Destrutivo).
class ScorePrioridadeNota {
  final String notaSapId;
  final String numeroNota;
  final String? descricao;
  final double scoreTotal; // 0.0 a 100.0
  final CategoriaPrioridadeNota categoria;
  final List<FatorPrioridadeNota> fatores;
  final List<String> motivosTexto;

  const ScorePrioridadeNota({
    required this.notaSapId,
    required this.numeroNota,
    this.descricao,
    required this.scoreTotal,
    required this.categoria,
    required this.fatores,
    required this.motivosTexto,
  });
}

/// Configuração de pesos para o algoritmo de priorização consultiva.
class ConfiguracaoPriorizacao {
  final double pesoPrazoSap; // Padrão: 35%
  final double pesoCriticidade; // Padrão: 25%
  final double pesoRiscoSeguranca; // Padrão: 20%
  final double pesoIdadeNota; // Padrão: 10%
  final double pesoOportunidadeLogistica; // Padrão: 10% (Não pode sobrepor prazos/segurança)

  const ConfiguracaoPriorizacao({
    this.pesoPrazoSap = 35.0,
    this.pesoCriticidade = 25.0,
    this.pesoRiscoSeguranca = 20.0,
    this.pesoIdadeNota = 10.0,
    this.pesoOportunidadeLogistica = 10.0,
  });
}

/// Cenário de Simulação Não-Destrutiva em Memória (What-If).
class CenarioSimulacao {
  final String id;
  final String nome;
  final DateTime criadoEm;
  final Map<String, ({int ano, int mes})> mudancasPrevisaoNotas; // notaSapId -> {ano, mes}
  final Map<String, ({int ano, int mes})> mudancasPrevisaoGrupos; // grupoId -> {ano, mes}
  final int ajusteExecutoresDisponiveis; // Ex: +2 ou -1 executores
  final double? fatorEficienciaSimulado; // Ex: 0.90 ou 0.75

  const CenarioSimulacao({
    required this.id,
    required this.nome,
    required this.criadoEm,
    this.mudancasPrevisaoNotas = const {},
    this.mudancasPrevisaoGrupos = const {},
    this.ajusteExecutoresDisponiveis = 0,
    this.fatorEficienciaSimulado,
  });

  CenarioSimulacao copyWith({
    String? nome,
    Map<String, ({int ano, int mes})>? mudancasPrevisaoNotas,
    Map<String, ({int ano, int mes})>? mudancasPrevisaoGrupos,
    int? ajusteExecutoresDisponiveis,
    double? fatorEficienciaSimulado,
  }) {
    return CenarioSimulacao(
      id: id,
      nome: nome ?? this.nome,
      criadoEm: criadoEm,
      mudancasPrevisaoNotas: mudancasPrevisaoNotas ?? this.mudancasPrevisaoNotas,
      mudancasPrevisaoGrupos: mudancasPrevisaoGrupos ?? this.mudancasPrevisaoGrupos,
      ajusteExecutoresDisponiveis: ajusteExecutoresDisponiveis ?? this.ajusteExecutoresDisponiveis,
      fatorEficienciaSimulado: fatorEficienciaSimulado ?? this.fatorEficienciaSimulado,
    );
  }
}

/// Registro explicativo do impacto que uma alteração simulada de previsão causa no prazo SAP da nota.
class ImpactoPrazoSimulacao {
  final String notaSapId;
  final String numeroNota;
  final String? descricao;
  final DateTime? dataFimDesejada;
  final ({int ano, int mes})? previsaoOriginal;
  final ({int ano, int mes}) previsaoSimulada;
  final bool eraAtrasada;
  final bool ficouAtrasada;
  final int diferencaMeses; // Negativo = antecipou, Positivo = postergou

  const ImpactoPrazoSimulacao({
    required this.notaSapId,
    required this.numeroNota,
    this.descricao,
    this.dataFimDesejada,
    this.previsaoOriginal,
    required this.previsaoSimulada,
    required this.eraAtrasada,
    required this.ficouAtrasada,
    required this.diferencaMeses,
  });

  /// A simulação gerou um novo risco de atraso regulatório?
  bool get gerouNovoRisco => !eraAtrasada && ficouAtrasada;

  /// A simulação corrigiu um atraso pré-existente?
  bool get corrigiuAtraso => eraAtrasada && !ficouAtrasada;

  String get descricaoImpacto {
    if (gerouNovoRisco) {
      return 'ALERTA: Reprogramação causará atraso no prazo SAP (Meta: ${_formatarData(dataFimDesejada)})';
    }
    if (corrigiuAtraso) {
      return 'POSITIVO: Antecipação eliminou o risco de atraso regulatório!';
    }
    if (ficouAtrasada) {
      return 'Nota permanece em atraso no período simulado.';
    }
    return diferencaMeses < 0
        ? 'Antecipada em ${diferencaMeses.abs()} mês(es) dentro do prazo.'
        : diferencaMeses > 0
            ? 'Postergada em $diferencaMeses mês(es) dentro do prazo.'
            : 'Previsão mantida.';
  }

  static String _formatarData(DateTime? dt) {
    if (dt == null) return 'N/D';
    return '${dt.day.toString().padLeft(2, "0")}/${dt.month.toString().padLeft(2, "0")}/${dt.year}';
  }
}

/// Resultado comparativo detalhado entre o Cenário Original (Base) e o Cenário Simulado.
class ComparativoCenarioSimulacao {
  final BalanceamentoCapacidadeMes balancoBase;
  final BalanceamentoCapacidadeMes balancoSimulado;
  final List<ImpactoPrazoSimulacao> impactosPrazos;

  const ComparativoCenarioSimulacao({
    required this.balancoBase,
    required this.balancoSimulado,
    this.impactosPrazos = const [],
  });

  // Deltas matemáticos
  double get deltaCapacidadeHoras => balancoSimulado.horasAjustadas - balancoBase.horasAjustadas;
  double get deltaDemandaHoras => balancoSimulado.demanda.horasEstimadasNaoProgramadas - balancoBase.demanda.horasEstimadasNaoProgramadas;
  double get deltaSaldoHoras => balancoSimulado.saldoHorasCalculado - balancoBase.saldoHorasCalculado;
  int get deltaExecutores => balancoSimulado.totalExecutores - balancoBase.totalExecutores;

  // Impactos em prazos
  int get totalNovosAtrasos => impactosPrazos.where((i) => i.gerouNovoRisco).length;
  int get totalAtrasosEliminados => impactosPrazos.where((i) => i.corrigiuAtraso).length;
  int get totalNotasEmAtrasoSimulado => impactosPrazos.where((i) => i.ficouAtrasada).length;

  /// Mudança no status do balanceamento (ex: de sobrecarga para equilibrado)
  bool get melhorouStatus {
    return balancoSimulado.status.index > balancoBase.status.index;
  }
}


