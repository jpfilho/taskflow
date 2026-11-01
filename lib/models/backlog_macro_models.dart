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
    this.tasks = const [],
  });

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

  factory BacklogNotaItem.fromMap(
    Map<String, dynamic> map, {
    double? estimativaHoras,
    String? statusAnalise,
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
      (buscaTexto == null || buscaTexto!.trim().isEmpty);

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
