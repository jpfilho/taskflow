import 'nota_sap_grupo.dart';

/// Domínio formal de status das tarefas que contam como programação válida.
/// Auditado em banco com 2.000+ tarefas:
/// - CONC (1.244): Concluída
/// - PROG (512): Programada
/// - ANDA (116): Em andamento
/// - RPAR (64): Reprogramada Parcial
/// - RPGR (33): Reprogramada
///
/// Status que NÃO contam como programação:
/// - CANC: Cancelada
/// - Status desconhecidos/nulos (comportamento defensivo)
const Set<String> kStatusTaskQueContamComoProgramada = {
  'PROG',
  'ANDA',
  'CONC',
  'RPAR',
  'RPGR',
};

/// Classificação da aderência temporal entre a Previsão Gerencial Macro e a Programação Real.
enum DivergenciaPrevisaoTask {
  /// Programada no mesmo mês e ano da previsão
  conformePrevisao,

  /// Programada em mês/ano posterior à previsão
  aposPrevisao,

  /// Programada em mês/ano anterior à previsão
  antecipada,

  /// Nota possui task com data válida, mas não possuía previsão gerencial
  programadaSemPrevisaoMacro,

  /// Nota possui previsão gerencial, mas ainda não foi programada (ou tasks estão canceladas)
  previstaNaoProgramada,

  /// Nota sem previsão gerencial e sem programação operacional
  semPrevisao,
}

extension DivergenciaPrevisaoTaskExtension on DivergenciaPrevisaoTask {
  String get rotulo {
    switch (this) {
      case DivergenciaPrevisaoTask.conformePrevisao:
        return 'Programada conforme previsão';
      case DivergenciaPrevisaoTask.aposPrevisao:
        return '⚠ Programada após a previsão';
      case DivergenciaPrevisaoTask.antecipada:
        return '⚡ Antecipada em relação à previsão';
      case DivergenciaPrevisaoTask.programadaSemPrevisaoMacro:
        return 'Programada sem previsão macro';
      case DivergenciaPrevisaoTask.previstaNaoProgramada:
        return 'Prevista, não programada';
      case DivergenciaPrevisaoTask.semPrevisao:
        return 'Sem previsão';
    }
  }
}

/// Informações resumidas de uma Task vinculada a uma Nota SAP.
class BacklogTaskInfo {
  final String id;
  final String? tarefa;
  final String status;
  final DateTime? dataInicio;
  final DateTime? dataFim;

  const BacklogTaskInfo({
    required this.id,
    this.tarefa,
    required this.status,
    this.dataInicio,
    this.dataFim,
  });

  bool get isValida => kStatusTaskQueContamComoProgramada.contains(status.toUpperCase().trim());
  bool get isCancelada => status.toUpperCase().trim() == 'CANC';

  factory BacklogTaskInfo.fromMap(Map<String, dynamic> map) {
    return BacklogTaskInfo(
      id: map['id']?.toString() ?? '',
      tarefa: map['tarefa']?.toString(),
      status: map['status']?.toString() ?? '',
      dataInicio: map['data_inicio'] != null ? DateTime.tryParse(map['data_inicio'].toString()) : null,
      dataFim: map['data_fim'] != null ? DateTime.tryParse(map['data_fim'].toString()) : null,
    );
  }
}

/// Representação enriquecida de uma Nota SAP no contexto do Backlog Macro.
class BacklogNotaItem {
  final String id;
  final String nota;
  final String descricao;
  final String? localInstalacao;
  final String? equipamento;
  final String? centroTrabalhoResponsavel;
  final String? prioridade;
  final String? gpm;
  final String? statusSistema;
  final String? statusUsuario;

  // Análise técnica
  final double? estimativaHoras;
  final String? statusAnalise;
  final String? diagnosticoPrevio;

  // Datas e Priorização
  final DateTime? dataFimDesejada;
  final DateTime? dataCriacao;
  final String? grupoId;

  // Previsão Gerencial Macro
  final int? mesPrevisto;
  final int? anoPrevisto;

  // Programação
  final List<BacklogTaskInfo> tasks;

  const BacklogNotaItem({
    required this.id,
    required this.nota,
    required this.descricao,
    this.localInstalacao,
    this.equipamento,
    this.centroTrabalhoResponsavel,
    this.prioridade,
    this.gpm,
    this.statusSistema,
    this.statusUsuario,
    this.estimativaHoras,
    this.statusAnalise,
    this.diagnosticoPrevio,
    this.dataFimDesejada,
    this.dataCriacao,
    this.grupoId,
    this.mesPrevisto,
    this.anoPrevisto,
    this.tasks = const [],
  });

  /// Aliases de conveniência para integração com modelos de capacidade
  String get notaSapId => id;
  String get numeroNota => nota;

  /// Uma nota é considerada PROGRAMADA se possui pelo menos uma Task com status válido.
  bool get isProgramada => tasks.any((t) => t.isValida);

  /// Nota pendente de programação.
  bool get isPendente => !isProgramada;

  /// Tem estimativa informada na análise?
  bool get temEstimativa => estimativaHoras != null;

  /// Tasks válidas associadas à nota
  List<BacklogTaskInfo> get tasksValidas => tasks.where((t) => t.isValida).toList();

  /// Tasks canceladas associadas à nota
  List<BacklogTaskInfo> get tasksCanceladas => tasks.where((t) => t.isCancelada).toList();

  /// Retorna a Task principal que representa a programação atual/relevante da Nota.
  /// Hierarquia determinística de prioridade (Itens 9, 10, 11 e 12):
  /// 1º: Em andamento (ANDA) - priorizando início mais recente;
  /// 2º: Programadas / Reprogramadas ativas (PROG, RPAR, RPGR) - priorizando início mais recente;
  /// 3º: Concluídas (CONC) - priorizando conclusão/início mais recente;
  /// 4º: Canceladas (CANC) - histórico quando não houver nenhuma outra.
  BacklogTaskInfo? get taskProgramacaoAtual {
    if (tasks.isEmpty) return null;

    // 1. Em andamento (ANDA)
    final andamento = tasks.where((t) => t.status.toUpperCase().trim() == 'ANDA').toList();
    if (andamento.isNotEmpty) {
      andamento.sort((a, b) {
        if (a.dataInicio != null && b.dataInicio != null) {
          return b.dataInicio!.compareTo(a.dataInicio!);
        }
        if (a.dataInicio != null) return -1;
        if (b.dataInicio != null) return 1;
        return b.id.compareTo(a.id);
      });
      return andamento.first;
    }

    // 2. Programadas / Reprogramadas ativas (PROG, RPAR, RPGR)
    final programadas = tasks.where((t) {
      final st = t.status.toUpperCase().trim();
      return st == 'PROG' || st == 'RPAR' || st == 'RPGR';
    }).toList();
    if (programadas.isNotEmpty) {
      programadas.sort((a, b) {
        if (a.dataInicio != null && b.dataInicio != null) {
          return b.dataInicio!.compareTo(a.dataInicio!);
        }
        if (a.dataInicio != null) return -1;
        if (b.dataInicio != null) return 1;
        return b.id.compareTo(a.id);
      });
      return programadas.first;
    }

    // 3. Concluídas (CONC)
    final concluidas = tasks.where((t) => t.status.toUpperCase().trim() == 'CONC').toList();
    if (concluidas.isNotEmpty) {
      concluidas.sort((a, b) {
        final dataA = a.dataFim ?? a.dataInicio;
        final dataB = b.dataFim ?? b.dataInicio;
        if (dataA != null && dataB != null) {
          return dataB.compareTo(dataA);
        }
        if (dataA != null) return -1;
        if (dataB != null) return 1;
        return b.id.compareTo(a.id);
      });
      return concluidas.first;
    }

    // 4. Canceladas (CANC) - histórico apenas
    final canceladas = tasks.where((t) => t.isCancelada).toList();
    if (canceladas.isNotEmpty) {
      canceladas.sort((a, b) {
        if (a.dataInicio != null && b.dataInicio != null) {
          return b.dataInicio!.compareTo(a.dataInicio!);
        }
        return b.id.compareTo(a.id);
      });
      return canceladas.first;
    }

    // Fallback determinístico
    return tasks.first;
  }

  /// Classifica a divergência temporal entre a Previsão Gerencial e a Programação Real.
  DivergenciaPrevisaoTask classificarDivergencia({int? mesPrevisao, int? anoPrevisao}) {
    final mPrev = mesPrevisao ?? mesPrevisto;
    final aPrev = anoPrevisao ?? anoPrevisto;
    final temPrevisao = mPrev != null && aPrev != null;

    final task = taskProgramacaoAtual;
    // Task cancelada NÃO conta como programação válida (Item 15 e 26)
    final taskValidaComData = (task != null && task.isValida && task.dataInicio != null);

    if (!temPrevisao && !taskValidaComData) {
      return DivergenciaPrevisaoTask.semPrevisao;
    }
    if (temPrevisao && !taskValidaComData) {
      return DivergenciaPrevisaoTask.previstaNaoProgramada;
    }
    if (!temPrevisao && taskValidaComData) {
      return DivergenciaPrevisaoTask.programadaSemPrevisaoMacro;
    }

    final mesTask = task!.dataInicio!.month;
    final anoTask = task.dataInicio!.year;

    // Cálculo em base temporal contínua (ano * 12 + mes) para garantir tratamento correto de virada de ano
    final pontosPrevisao = aPrev! * 12 + mPrev!;
    final pontosTask = anoTask * 12 + mesTask;

    if (pontosTask == pontosPrevisao) {
      return DivergenciaPrevisaoTask.conformePrevisao;
    } else if (pontosTask > pontosPrevisao) {
      return DivergenciaPrevisaoTask.aposPrevisao;
    } else {
      return DivergenciaPrevisaoTask.antecipada;
    }
  }

  factory BacklogNotaItem.fromMap(
    Map<String, dynamic> map, {
    double? estimativaHoras,
    String? statusAnalise,
    String? diagnosticoPrevio,
    DateTime? dataFimDesejada,
    DateTime? dataCriacao,
    String? grupoId,
    int? mesPrevisto,
    int? anoPrevisto,
    List<BacklogTaskInfo> tasks = const [],
  }) {
    return BacklogNotaItem(
      id: map['id']?.toString() ?? '',
      nota: map['nota']?.toString() ?? '',
      descricao: map['descricao']?.toString() ?? '',
      localInstalacao: map['local_instalacao']?.toString(),
      equipamento: map['equipamento']?.toString(),
      centroTrabalhoResponsavel: map['centro_trabalho_responsavel']?.toString(),
      prioridade: map['text_prioridade']?.toString(),
      gpm: map['gpm']?.toString(),
      statusSistema: map['status_sistema']?.toString(),
      statusUsuario: map['status_usuario']?.toString(),
      estimativaHoras: estimativaHoras,
      statusAnalise: statusAnalise,
      diagnosticoPrevio: diagnosticoPrevio ?? map['diagnostico_previo']?.toString(),
      dataFimDesejada: dataFimDesejada ??
          (map['data_fim_desejada'] != null ? DateTime.tryParse(map['data_fim_desejada'].toString()) : null),
      dataCriacao: dataCriacao ??
          (map['data_criacao'] != null ? DateTime.tryParse(map['data_criacao'].toString()) : null),
      grupoId: grupoId ?? map['grupo_id']?.toString(),
      mesPrevisto: mesPrevisto,
      anoPrevisto: anoPrevisto,
      tasks: tasks,
    );
  }
}

/// Item agregado de Grupo no Backlog Macro com cálculos de progresso e estimativas.
class BacklogGrupoItem {
  final String id;
  final String nome;
  final String? motivo;
  final int? mesProgramacaoPrevisto;
  final int? anoProgramacaoPrevisto;
  final String? localInstalacao;
  final String? equipamento;
  final String? centroTrabalhoResponsavel;
  final String statusGrupo;
  final DateTime? createdAt;
  final List<BacklogNotaItem> notas;

  const BacklogGrupoItem({
    required this.id,
    required this.nome,
    this.motivo,
    this.mesProgramacaoPrevisto,
    this.anoProgramacaoPrevisto,
    this.localInstalacao,
    this.equipamento,
    this.centroTrabalhoResponsavel,
    required this.statusGrupo,
    this.createdAt,
    this.notas = const [],
  });

  bool get temPrevisao => mesProgramacaoPrevisto != null && anoProgramacaoPrevisto != null;

  String get previsaoFormatada {
    if (!temPrevisao) return 'Sem previsão';
    const meses = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    return '${meses[mesProgramacaoPrevisto! - 1]}/${anoProgramacaoPrevisto!}';
  }

  String get previsaoCompacta {
    if (!temPrevisao) return 'Sem prev.';
    const meses = [
      'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'
    ];
    final ano2D = (anoProgramacaoPrevisto! % 100).toString().padLeft(2, '0');
    return '${meses[mesProgramacaoPrevisto! - 1]}/$ano2D';
  }

  int get totalNotas => notas.length;
  int get notasProgramadas => notas.where((n) => n.isProgramada).length;
  int get notasPendentes => notas.where((n) => n.isPendente).length;

  double get percentualProgramado =>
      totalNotas == 0 ? 0.0 : (notasProgramadas / totalNotas) * 100.0;

  StatusProgramacaoGrupo get statusProgramacao {
    if (totalNotas == 0 || notasProgramadas == 0) {
      return StatusProgramacaoGrupo.naoProgramado;
    }
    if (notasProgramadas == totalNotas) {
      return StatusProgramacaoGrupo.total;
    }
    return StatusProgramacaoGrupo.parcial;
  }

  /// Verifica se a previsão é anterior ao mês de referência E ainda possui notas pendentes
  bool isPrevisaoUltrapassada([DateTime? dataReferencia]) {
    if (!temPrevisao) return false;
    if (notasPendentes == 0) return false; // Se todas programadas, não é ultrapassada
    final ref = dataReferencia ?? DateTime.now();
    final pontosPrevisto = anoProgramacaoPrevisto! * 12 + mesProgramacaoPrevisto!;
    final pontosAtual = ref.year * 12 + ref.month;
    return pontosPrevisto < pontosAtual;
  }

  // --- Estimativas de horas ---
  double get somaEstimativaTotal {
    double total = 0.0;
    for (final n in notas) {
      if (n.estimativaHoras != null) {
        total += n.estimativaHoras!;
      }
    }
    return total;
  }

  double get somaEstimativaPendente {
    double total = 0.0;
    for (final n in notas) {
      if (n.isPendente && n.estimativaHoras != null) {
        total += n.estimativaHoras!;
      }
    }
    return total;
  }

  int get notasComEstimativa => notas.where((n) => n.temEstimativa).length;
  int get notasSemEstimativa => notas.where((n) => !n.temEstimativa).length;

  /// Retorna a primeira Nota pendente (se houver) para ação de programação.
  BacklogNotaItem? get primeiraNotaPendente {
    for (final n in notas) {
      if (n.isPendente) return n;
    }
    return null;
  }
}

/// Resumo agregado por mês de previsão.
class BacklogMensalResumo {
  final int? mes;
  final int? ano;
  final List<BacklogGrupoItem> grupos;

  const BacklogMensalResumo({
    this.mes,
    this.ano,
    required this.grupos,
  });

  bool get isSemPrevisao => mes == null || ano == null;
  bool get temPrevisao => !isSemPrevisao;

  String get labelMesAno {
    if (isSemPrevisao) return 'SEM PREVISÃO';
    const meses = [
      'JANEIRO', 'FEVEREIRO', 'MARÇO', 'ABRIL', 'MAIO', 'JUNHO',
      'JULHO', 'AGOSTO', 'SETEMBRO', 'OUTUBRO', 'NOVEMBRO', 'DEZEMBRO'
    ];
    return '${meses[mes! - 1]} / $ano';
  }

  String get labelCompacto {
    if (isSemPrevisao) return 'Sem prev.';
    const meses = [
      'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'
    ];
    final ano2D = (ano! % 100).toString().padLeft(2, '0');
    return '${meses[mes! - 1]}/$ano2D';
  }

  int get totalGrupos => grupos.length;

  int get totalNotas {
    int total = 0;
    for (final g in grupos) {
      total += g.totalNotas;
    }
    return total;
  }

  int get notasProgramadas {
    int total = 0;
    for (final g in grupos) {
      total += g.notasProgramadas;
    }
    return total;
  }

  int get notasPendentes {
    int total = 0;
    for (final g in grupos) {
      total += g.notasPendentes;
    }
    return total;
  }

  double get percentualProgramado =>
      totalNotas == 0 ? 0.0 : (notasProgramadas / totalNotas) * 100.0;

  double get somaEstimativasTotal {
    double total = 0.0;
    for (final g in grupos) {
      total += g.somaEstimativaTotal;
    }
    return total;
  }

  double get somaEstimativasPendentes {
    double total = 0.0;
    for (final g in grupos) {
      total += g.somaEstimativaPendente;
    }
    return total;
  }

  int get notasComEstimativa {
    int total = 0;
    for (final g in grupos) {
      total += g.notasComEstimativa;
    }
    return total;
  }

  int get notasSemEstimativa {
    int total = 0;
    for (final g in grupos) {
      total += g.notasSemEstimativa;
    }
    return total;
  }

  bool isUltrapassado([DateTime? dataReferencia]) {
    if (isSemPrevisao) return false;
    final ref = dataReferencia ?? DateTime.now();
    final pontosPrevisto = ano! * 12 + mes!;
    final pontosAtual = ref.year * 12 + ref.month;
    return pontosPrevisto < pontosAtual && notasPendentes > 0;
  }
}

/// KPIs globais no topo do Backlog Macro.
class BacklogGlobalResumo {
  final int gruposAtivos;
  final int gruposComPrevisao;
  final int gruposSemPrevisao;
  final int gruposUltrapassados;

  final int notasEmGrupos;
  final int notasProgramadas;
  final int notasPendentes;

  /// Quantidade de notas distintas em grupos ativos (para controle de integridade).
  final int notasUnicas;
  final bool temAnomaliaIntegridade;

  const BacklogGlobalResumo({
    required this.gruposAtivos,
    required this.gruposComPrevisao,
    required this.gruposSemPrevisao,
    required this.gruposUltrapassados,
    required this.notasEmGrupos,
    required this.notasProgramadas,
    required this.notasPendentes,
    required this.notasUnicas,
    required this.temAnomaliaIntegridade,
  });

  double get percentualProgramado =>
      notasEmGrupos == 0 ? 0.0 : (notasProgramadas / notasEmGrupos) * 100.0;
}

/// DTO com os filtros aplicados ao Backlog Macro.
class BacklogFiltro {
  final int? ano;
  final int? mes;
  final String? centroTrabalho;
  final String? localInstalacao;
  final String? equipamento;
  final StatusProgramacaoGrupo? statusProgramacao;
  final bool? apenasComPrevisao;
  final bool? apenasSemPrevisao;
  final bool? apenasUltrapassados;
  final String? buscaTexto;
  final String? regionalId;
  final String? divisaoId;

  const BacklogFiltro({
    this.ano,
    this.mes,
    this.centroTrabalho,
    this.localInstalacao,
    this.equipamento,
    this.statusProgramacao,
    this.apenasComPrevisao,
    this.apenasSemPrevisao,
    this.apenasUltrapassados,
    this.buscaTexto,
    this.regionalId,
    this.divisaoId,
  });

  bool get isEmpty =>
      ano == null &&
      mes == null &&
      centroTrabalho == null &&
      localInstalacao == null &&
      equipamento == null &&
      statusProgramacao == null &&
      apenasComPrevisao == null &&
      apenasSemPrevisao == null &&
      apenasUltrapassados == null &&
      (buscaTexto == null || buscaTexto!.trim().isEmpty) &&
      regionalId == null &&
      divisaoId == null;

  BacklogFiltro copyWith({
    int? ano,
    int? mes,
    String? centroTrabalho,
    String? localInstalacao,
    String? equipamento,
    StatusProgramacaoGrupo? statusProgramacao,
    bool? apenasComPrevisao,
    bool? apenasSemPrevisao,
    bool? apenasUltrapassados,
    String? buscaTexto,
    String? regionalId,
    String? divisaoId,
    bool clearAnoMes = false,
  }) {
    return BacklogFiltro(
      ano: clearAnoMes ? null : (ano ?? this.ano),
      mes: clearAnoMes ? null : (mes ?? this.mes),
      centroTrabalho: centroTrabalho ?? this.centroTrabalho,
      localInstalacao: localInstalacao ?? this.localInstalacao,
      equipamento: equipamento ?? this.equipamento,
      statusProgramacao: statusProgramacao ?? this.statusProgramacao,
      apenasComPrevisao: apenasComPrevisao ?? this.apenasComPrevisao,
      apenasSemPrevisao: apenasSemPrevisao ?? this.apenasSemPrevisao,
      apenasUltrapassados: apenasUltrapassados ?? this.apenasUltrapassados,
      buscaTexto: buscaTexto ?? this.buscaTexto,
      regionalId: regionalId ?? this.regionalId,
      divisaoId: divisaoId ?? this.divisaoId,
    );
  }
}

/// DTO raiz retornado pelo NotaSapBacklogService.
class BacklogMacroResult {
  final BacklogGlobalResumo global;
  final List<BacklogMensalResumo> meses;
  final BacklogMensalResumo? semPrevisao;
  final DateTime geradoEm;
  final BacklogFiltro filtrosAplicados;
  final List<BacklogGrupoItem> todosGrupos;

  const BacklogMacroResult({
    required this.global,
    required this.meses,
    this.semPrevisao,
    required this.geradoEm,
    required this.filtrosAplicados,
    required this.todosGrupos,
  });

  bool get isEmpty => todosGrupos.isEmpty;
}
