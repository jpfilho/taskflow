import 'package:flutter/foundation.dart';
import 'backlog_macro_models.dart';
import 'nota_sap.dart';
import 'nota_sap_grupo.dart';

/// Domínio das 7 situações formais de relacionamento entre Prazo e Previsão.
enum SituacaoPrazoCarteira {
  /// SIT-1: Previsão anterior ao mês do prazo (Compatível, com folga de pelo menos um mês).
  sit1Compativel,

  /// SIT-2: Previsão no mesmo mês do prazo (Risco temporal por incerteza dentro do mês).
  sit2RiscoTemporal,

  /// SIT-3: Previsão posterior ao mês do prazo (Violação / Descumprimento previsto).
  sit3ViolacaoPrevista,

  /// SIT-4: Demanda pendente com prazo já expirado (Vencida).
  sit4PrazoVencido,

  /// SIT-5: Demanda sem data de vencimento calculada ou sem prioridade (Sem prazo conhecido).
  sit5SemPrazoConhecido,

  /// SIT-6: Previsão anterior ao mês corrente e ainda pendente/não programada (Previsão ultrapassada).
  sit6PrevisaoUltrapassada,

  /// SIT-7: Sem previsão e com prazo próximo (<= 60 dias) - Atenção urgente.
  sit7SemPrevisaoPrazoProximo;

  String get codigo {
    switch (this) {
      case SituacaoPrazoCarteira.sit1Compativel:
        return 'SIT-1';
      case SituacaoPrazoCarteira.sit2RiscoTemporal:
        return 'SIT-2';
      case SituacaoPrazoCarteira.sit3ViolacaoPrevista:
        return 'SIT-3';
      case SituacaoPrazoCarteira.sit4PrazoVencido:
        return 'SIT-4';
      case SituacaoPrazoCarteira.sit5SemPrazoConhecido:
        return 'SIT-5';
      case SituacaoPrazoCarteira.sit6PrevisaoUltrapassada:
        return 'SIT-6';
      case SituacaoPrazoCarteira.sit7SemPrevisaoPrazoProximo:
        return 'SIT-7';
    }
  }

  String get label {
    switch (this) {
      case SituacaoPrazoCarteira.sit1Compativel:
        return 'Previsão compatível com o prazo';
      case SituacaoPrazoCarteira.sit2RiscoTemporal:
        return 'Previsão no mês do prazo (Atenção)';
      case SituacaoPrazoCarteira.sit3ViolacaoPrevista:
        return 'Previsão posterior ao prazo (Risco de violação)';
      case SituacaoPrazoCarteira.sit4PrazoVencido:
        return 'Prazo vencido';
      case SituacaoPrazoCarteira.sit5SemPrazoConhecido:
        return 'Sem prazo conhecido';
      case SituacaoPrazoCarteira.sit6PrevisaoUltrapassada:
        return 'Previsão ultrapassada';
      case SituacaoPrazoCarteira.sit7SemPrevisaoPrazoProximo:
        return 'Sem previsão e prazo próximo';
    }
  }

  String get labelCurto {
    switch (this) {
      case SituacaoPrazoCarteira.sit1Compativel:
        return 'Compatível';
      case SituacaoPrazoCarteira.sit2RiscoTemporal:
        return 'Risco no Mês';
      case SituacaoPrazoCarteira.sit3ViolacaoPrevista:
        return 'Violação Prevista';
      case SituacaoPrazoCarteira.sit4PrazoVencido:
        return 'Vencida';
      case SituacaoPrazoCarteira.sit5SemPrazoConhecido:
        return 'Sem Prazo';
      case SituacaoPrazoCarteira.sit6PrevisaoUltrapassada:
        return 'Prev. Ultrapassada';
      case SituacaoPrazoCarteira.sit7SemPrevisaoPrazoProximo:
        return 'Sem Prev. (Urgente)';
    }
  }

  /// Classifica a situação de prazo e previsão de forma determinística e testável.
  static SituacaoPrazoCarteira classificar({
    required DateTime? dataVencimento,
    required int? diasRestantes,
    required int? mesPrevisto,
    required int? anoPrevisto,
    required bool isProgramada,
    DateTime? dataReferencia,
  }) {
    final ref = dataReferencia ?? DateTime.now();
    final mesRef = ref.month;
    final anoRef = ref.year;

    // 1. Prazo Vencido (SIT-4): Prioridade máxima de risco consumado
    if (diasRestantes != null && diasRestantes < 0) {
      return SituacaoPrazoCarteira.sit4PrazoVencido;
    }
    if (dataVencimento != null) {
      final hojeApenasData = DateTime(ref.year, ref.month, ref.day);
      final vencApenasData = DateTime(dataVencimento.year, dataVencimento.month, dataVencimento.day);
      if (vencApenasData.isBefore(hojeApenasData)) {
        return SituacaoPrazoCarteira.sit4PrazoVencido;
      }
    }

    final temPrevisao = mesPrevisto != null && anoPrevisto != null;

    // 2. Cenários SEM Previsão
    if (!temPrevisao) {
      if (dataVencimento == null) {
        return SituacaoPrazoCarteira.sit5SemPrazoConhecido;
      }
      if (diasRestantes != null && diasRestantes <= 60 && diasRestantes >= 0) {
        return SituacaoPrazoCarteira.sit7SemPrevisaoPrazoProximo;
      }
      return SituacaoPrazoCarteira.sit5SemPrazoConhecido;
    }

    // 3. Cenários COM Previsão
    final pontosPrevisto = anoPrevisto * 12 + mesPrevisto;
    final pontosAtual = anoRef * 12 + mesRef;

    // Previsão Ultrapassada (SIT-6): mês previsto já passou e não foi programada
    if (pontosPrevisto < pontosAtual && !isProgramada) {
      return SituacaoPrazoCarteira.sit6PrevisaoUltrapassada;
    }

    // Se tem previsão mas não tem prazo conhecido
    if (dataVencimento == null) {
      return SituacaoPrazoCarteira.sit5SemPrazoConhecido;
    }

    final pontosVencimento = dataVencimento.year * 12 + dataVencimento.month;

    // SIT-3: Previsão posterior ao prazo (Risco Crítico)
    if (pontosPrevisto > pontosVencimento) {
      return SituacaoPrazoCarteira.sit3ViolacaoPrevista;
    }

    // SIT-2: Previsão no mesmo mês do prazo (Risco de Incerteza Temporal)
    if (pontosPrevisto == pontosVencimento) {
      return SituacaoPrazoCarteira.sit2RiscoTemporal;
    }

    // SIT-1: Previsão anterior ao mês do prazo (Confortavelmente compatível)
    return SituacaoPrazoCarteira.sit1Compativel;
  }
}

/// Origem de onde a nota obteve sua previsão.
enum OrigemPrevisao {
  /// Previsão herdada de um grupo ativo (padrão principal).
  grupo,

  /// Previsão atribuída diretamente à nota (avulsa).
  individual,

  /// Previsão inferida da data de início de uma tarefa programada.
  programacao,

  /// Nenhuma previsão atribuída.
  nenhuma;

  String get label {
    switch (this) {
      case OrigemPrevisao.grupo:
        return 'Grupo de Previsão';
      case OrigemPrevisao.individual:
        return 'Previsão Individual';
      case OrigemPrevisao.programacao:
        return 'Data da Tarefa Programada';
      case OrigemPrevisao.nenhuma:
        return 'Sem Previsão';
    }
  }
}

/// Dados da previsão de atendimento da demanda.
@immutable
class CarteiraPrevisao {
  final int? mes;
  final int? ano;
  final OrigemPrevisao origem;
  final String? origemId;
  final String? origemNome;
  final String? motivo;

  const CarteiraPrevisao({
    this.mes,
    this.ano,
    required this.origem,
    this.origemId,
    this.origemNome,
    this.motivo,
  });

  bool get temPrevisao => mes != null && ano != null;

  String get formatada {
    if (!temPrevisao) return 'Sem previsão';
    const meses = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    return '${meses[mes! - 1]}/$ano';
  }

  String get compacta {
    if (!temPrevisao) return 'Sem prev.';
    const meses = [
      'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'
    ];
    final ano2D = (ano! % 100).toString().padLeft(2, '0');
    return '${meses[mes! - 1]}/$ano2D';
  }

  static const semPrevisao = CarteiraPrevisao(origem: OrigemPrevisao.nenhuma);
}

/// Representação consolidada de uma demanda (Nota SAP) na carteira gerencial.
@immutable
class CarteiraItem {
  final NotaSAP nota;
  final CarteiraPrevisao previsao;
  final String? grupoId;
  final String? grupoNome;
  final List<BacklogTaskInfo> tasks;
  final double? estimativaHoras;
  final String? statusAnalise;
  final SituacaoPrazoCarteira situacaoPrazo;

  const CarteiraItem({
    required this.nota,
    required this.previsao,
    this.grupoId,
    this.grupoNome,
    this.tasks = const [],
    this.estimativaHoras,
    this.statusAnalise,
    required this.situacaoPrazo,
  });

  String get id => nota.id;
  String get numeroNota => nota.nota;
  String? get descricao => nota.descricao;
  String? get localInstalacao => nota.localInstalacao;
  String? get local => nota.local;
  String? get equipamento => nota.equipamento;
  String? get centroTrabalho => nota.centroTrabalhoResponsavel;
  String? get prioridade => nota.textPrioridade;
  DateTime? get dataVencimento => nota.dataVencimento;
  int? get diasRestantes => nota.diasRestantes;

  /// A nota está pendente de atendimento (aberta no SAP)?
  bool get isPendente => nota.estaAberta;

  /// A nota está em um grupo ativo?
  bool get isAgrupada => grupoId != null && grupoId!.isNotEmpty;

  /// A nota é avulsa (não está em nenhum grupo ativo)?
  bool get isAvulsa => !isAgrupada;

  /// A nota possui previsão macro válida?
  bool get temPrevisaoValida => previsao.temPrevisao;

  /// A nota está programada operacionalmente em tarefa válida?
  bool get isProgramada => tasks.any((t) => t.isValida);

  /// Tasks válidas
  List<BacklogTaskInfo> get tasksValidas => tasks.where((t) => t.isValida).toList();

  /// Flags de risco
  bool get isVencida => situacaoPrazo == SituacaoPrazoCarteira.sit4PrazoVencido;
  bool get isRiscoViolacao => situacaoPrazo == SituacaoPrazoCarteira.sit3ViolacaoPrevista;
  bool get isRiscoTemporal => situacaoPrazo == SituacaoPrazoCarteira.sit2RiscoTemporal;
  bool get isPrevisaoUltrapassada => situacaoPrazo == SituacaoPrazoCarteira.sit6PrevisaoUltrapassada;
  bool get isSemPrevisaoUrgente => situacaoPrazo == SituacaoPrazoCarteira.sit7SemPrevisaoPrazoProximo;

  CarteiraItem copyWith({
    NotaSAP? nota,
    CarteiraPrevisao? previsao,
    String? grupoId,
    String? grupoNome,
    List<BacklogTaskInfo>? tasks,
    double? estimativaHoras,
    String? statusAnalise,
    SituacaoPrazoCarteira? situacaoPrazo,
  }) {
    return CarteiraItem(
      nota: nota ?? this.nota,
      previsao: previsao ?? this.previsao,
      grupoId: grupoId ?? this.grupoId,
      grupoNome: grupoNome ?? this.grupoNome,
      tasks: tasks ?? this.tasks,
      estimativaHoras: estimativaHoras ?? this.estimativaHoras,
      statusAnalise: statusAnalise ?? this.statusAnalise,
      situacaoPrazo: situacaoPrazo ?? this.situacaoPrazo,
    );
  }
}

/// Indicadores Gerenciais Consolidados da Carteira de Manutenção.
@immutable
class CarteiraIndicadores {
  // Volume geral da carteira pendente
  final int totalNotasPendentes;
  final int totalNotasAgrupadas;
  final int totalNotasAvulsas;

  // Previsibilidade
  final int totalComPrevisao;
  final int totalSemPrevisao;
  final double taxaCoberturaPrevisibilidade; // 0 a 100%

  // Esforço estimado (horas)
  final double totalHorasEstimadas;
  final double totalHorasSemPrevisao;
  final int totalNotasComEstimativa;
  final double taxaCoberturaEstimativa; // % de notas que possuem análise de horas

  // Programação Operacional
  final int totalProgramadas;
  final double taxaProgramacao; // 0 a 100%

  // Situações de Risco e Prazos (SIT-1 a SIT-7)
  final int totalVencidas; // SIT-4
  final int totalViolacaoPrevista; // SIT-3
  final int totalRiscoTemporal; // SIT-2
  final int totalCompativel; // SIT-1
  final int totalPrevisaoUltrapassada; // SIT-6
  final int totalSemPrevisaoPrazoProximo; // SIT-7
  final int totalSemPrazoConhecido; // SIT-5

  // Grupos
  final int totalGruposAtivos;
  final int totalGruposComPrevisao;
  final int totalGruposSemPrevisao;
  final int totalGruposUltrapassados;
  final int totalGruposComRiscoPrazo;

  const CarteiraIndicadores({
    required this.totalNotasPendentes,
    required this.totalNotasAgrupadas,
    required this.totalNotasAvulsas,
    required this.totalComPrevisao,
    required this.totalSemPrevisao,
    required this.taxaCoberturaPrevisibilidade,
    required this.totalHorasEstimadas,
    required this.totalHorasSemPrevisao,
    required this.totalNotasComEstimativa,
    required this.taxaCoberturaEstimativa,
    required this.totalProgramadas,
    required this.taxaProgramacao,
    required this.totalVencidas,
    required this.totalViolacaoPrevista,
    required this.totalRiscoTemporal,
    required this.totalCompativel,
    required this.totalPrevisaoUltrapassada,
    required this.totalSemPrevisaoPrazoProximo,
    required this.totalSemPrazoConhecido,
    required this.totalGruposAtivos,
    required this.totalGruposComPrevisao,
    required this.totalGruposSemPrevisao,
    required this.totalGruposUltrapassados,
    required this.totalGruposComRiscoPrazo,
  });

  /// Constrói os indicadores a partir da lista integral de itens da carteira e grupos.
  factory CarteiraIndicadores.calcular({
    required List<CarteiraItem> itens,
    required List<NotaSapGrupo> gruposAtivos,
    DateTime? dataReferencia,
  }) {
    final ref = dataReferencia ?? DateTime.now();
    final pendentes = itens.where((i) => i.isPendente).toList();
    final total = pendentes.length;

    if (total == 0) {
      return const CarteiraIndicadores(
        totalNotasPendentes: 0,
        totalNotasAgrupadas: 0,
        totalNotasAvulsas: 0,
        totalComPrevisao: 0,
        totalSemPrevisao: 0,
        taxaCoberturaPrevisibilidade: 0.0,
        totalHorasEstimadas: 0.0,
        totalHorasSemPrevisao: 0.0,
        totalNotasComEstimativa: 0,
        taxaCoberturaEstimativa: 0.0,
        totalProgramadas: 0,
        taxaProgramacao: 0.0,
        totalVencidas: 0,
        totalViolacaoPrevista: 0,
        totalRiscoTemporal: 0,
        totalCompativel: 0,
        totalPrevisaoUltrapassada: 0,
        totalSemPrevisaoPrazoProximo: 0,
        totalSemPrazoConhecido: 0,
        totalGruposAtivos: 0,
        totalGruposComPrevisao: 0,
        totalGruposSemPrevisao: 0,
        totalGruposUltrapassados: 0,
        totalGruposComRiscoPrazo: 0,
      );
    }

    int agrupadas = 0;
    int avulsas = 0;
    int comPrevisao = 0;
    int semPrevisao = 0;
    double horasTotal = 0.0;
    double horasSemPrevisao = 0.0;
    int comEstimativa = 0;
    int programadas = 0;

    int vencidas = 0;
    int violacao = 0;
    int riscoTemporal = 0;
    int compativel = 0;
    int ultrapassadas = 0;
    int semPrevProximo = 0;
    int semPrazo = 0;

    for (final item in pendentes) {
      if (item.isAgrupada) {
        agrupadas++;
      } else {
        avulsas++;
      }

      if (item.temPrevisaoValida) {
        comPrevisao++;
      } else {
        semPrevisao++;
      }

      if (item.estimativaHoras != null) {
        comEstimativa++;
        horasTotal += item.estimativaHoras!;
        if (!item.temPrevisaoValida) {
          horasSemPrevisao += item.estimativaHoras!;
        }
      }

      if (item.isProgramada) {
        programadas++;
      }

      switch (item.situacaoPrazo) {
        case SituacaoPrazoCarteira.sit4PrazoVencido:
          vencidas++;
          break;
        case SituacaoPrazoCarteira.sit3ViolacaoPrevista:
          violacao++;
          break;
        case SituacaoPrazoCarteira.sit2RiscoTemporal:
          riscoTemporal++;
          break;
        case SituacaoPrazoCarteira.sit1Compativel:
          compativel++;
          break;
        case SituacaoPrazoCarteira.sit6PrevisaoUltrapassada:
          ultrapassadas++;
          break;
        case SituacaoPrazoCarteira.sit7SemPrevisaoPrazoProximo:
          semPrevProximo++;
          break;
        case SituacaoPrazoCarteira.sit5SemPrazoConhecido:
          semPrazo++;
          break;
      }
    }

    // Análise agregada dos grupos
    int grpComPrevisao = 0;
    int grpSemPrevisao = 0;
    int grpUltrapassados = 0;
    int grpComRisco = 0;

    // Mapear itens por grupo para avaliar risco coletivo do grupo
    final Map<String, List<CarteiraItem>> itensPorGrupo = {};
    for (final it in pendentes) {
      if (it.grupoId != null) {
        itensPorGrupo.putIfAbsent(it.grupoId!, () => []).add(it);
      }
    }

    for (final g in gruposAtivos) {
      if (g.temPrevisao) {
        grpComPrevisao++;
        if (g.isPrevisaoUltrapassada(ref)) {
          grpUltrapassados++;
        }
      } else {
        grpSemPrevisao++;
      }

      final itensDoGrupo = itensPorGrupo[g.id] ?? const [];
      final temRisco = itensDoGrupo.any((i) =>
          i.situacaoPrazo == SituacaoPrazoCarteira.sit3ViolacaoPrevista ||
          i.situacaoPrazo == SituacaoPrazoCarteira.sit4PrazoVencido);
      if (temRisco) {
        grpComRisco++;
      }
    }

    final double taxaCobertura = (comPrevisao / total) * 100.0;
    final double taxaProg = (programadas / total) * 100.0;
    final double taxaEst = (comEstimativa / total) * 100.0;

    return CarteiraIndicadores(
      totalNotasPendentes: total,
      totalNotasAgrupadas: agrupadas,
      totalNotasAvulsas: avulsas,
      totalComPrevisao: comPrevisao,
      totalSemPrevisao: semPrevisao,
      taxaCoberturaPrevisibilidade: taxaCobertura,
      totalHorasEstimadas: horasTotal,
      totalHorasSemPrevisao: horasSemPrevisao,
      totalNotasComEstimativa: comEstimativa,
      taxaCoberturaEstimativa: taxaEst,
      totalProgramadas: programadas,
      taxaProgramacao: taxaProg,
      totalVencidas: vencidas,
      totalViolacaoPrevista: violacao,
      totalRiscoTemporal: riscoTemporal,
      totalCompativel: compativel,
      totalPrevisaoUltrapassada: ultrapassadas,
      totalSemPrevisaoPrazoProximo: semPrevProximo,
      totalSemPrazoConhecido: semPrazo,
      totalGruposAtivos: gruposAtivos.length,
      totalGruposComPrevisao: grpComPrevisao,
      totalGruposSemPrevisao: grpSemPrevisao,
      totalGruposUltrapassados: grpUltrapassados,
      totalGruposComRiscoPrazo: grpComRisco,
    );
  }
}

/// Registro de previsão individual atribuída diretamente a uma Nota SAP.
@immutable
class PrevisaoIndividualNota {
  final String id;
  final String notaSapId;
  final String? numeroNota;
  final int mesPrevisao;
  final int anoPrevisao;
  final String? motivoPrevisao;
  final String? loteId;
  final DateTime criadoEm;
  final String? criadoPor;
  final String? criadoPorNome;
  final DateTime atualizadoEm;
  final String? atualizadoPor;
  final String? atualizadoPorNome;

  const PrevisaoIndividualNota({
    required this.id,
    required this.notaSapId,
    this.numeroNota,
    required this.mesPrevisao,
    required this.anoPrevisao,
    this.motivoPrevisao,
    this.loteId,
    required this.criadoEm,
    this.criadoPor,
    this.criadoPorNome,
    required this.atualizadoEm,
    this.atualizadoPor,
    this.atualizadoPorNome,
  });

  factory PrevisaoIndividualNota.fromMap(Map<String, dynamic> map) {
    return PrevisaoIndividualNota(
      id: map['id']?.toString() ?? '',
      notaSapId: map['nota_sap_id']?.toString() ?? '',
      numeroNota: map['numero_nota']?.toString(),
      mesPrevisao: (map['mes_previsao'] as num?)?.toInt() ?? 1,
      anoPrevisao: (map['ano_previsao'] as num?)?.toInt() ?? DateTime.now().year,
      motivoPrevisao: map['motivo_previsao']?.toString(),
      loteId: map['lote_id']?.toString(),
      criadoEm: map['criado_em'] != null
          ? DateTime.tryParse(map['criado_em'].toString()) ?? DateTime.now()
          : DateTime.now(),
      criadoPor: map['criado_por']?.toString(),
      criadoPorNome: map['criado_por_nome']?.toString(),
      atualizadoEm: map['atualizado_em'] != null
          ? DateTime.tryParse(map['atualizado_em'].toString()) ?? DateTime.now()
          : DateTime.now(),
      atualizadoPor: map['atualizado_por']?.toString(),
      atualizadoPorNome: map['atualizado_por_nome']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nota_sap_id': notaSapId,
      'numero_nota': numeroNota,
      'mes_previsao': mesPrevisao,
      'ano_previsao': anoPrevisao,
      'motivo_previsao': motivoPrevisao,
      'lote_id': loteId,
      'criado_por': criadoPor,
      'criado_por_nome': criadoPorNome,
      'atualizado_por': atualizadoPor,
      'atualizado_por_nome': atualizadoPorNome,
    };
  }

  String get formatada {
    const meses = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    return '${meses[mesPrevisao - 1]}/$anoPrevisao';
  }
}

/// Registro histórico de auditoria e reprogramação de uma Nota SAP.
@immutable
class HistoricoPrevisaoNota {
  final String id;
  final String? previsaoId;
  final String notaSapId;
  final String? numeroNota;
  final int? mesAnterior;
  final int? anoAnterior;
  final int? mesNovo;
  final int? anoNovo;
  final String? motivo;
  final String operacao;
  final String? loteId;
  final String? alteradoPor;
  final String? alteradoPorNome;
  final DateTime alteradoEm;

  const HistoricoPrevisaoNota({
    required this.id,
    this.previsaoId,
    required this.notaSapId,
    this.numeroNota,
    this.mesAnterior,
    this.anoAnterior,
    this.mesNovo,
    this.anoNovo,
    this.motivo,
    required this.operacao,
    this.loteId,
    this.alteradoPor,
    this.alteradoPorNome,
    required this.alteradoEm,
  });

  factory HistoricoPrevisaoNota.fromMap(Map<String, dynamic> map) {
    return HistoricoPrevisaoNota(
      id: map['id']?.toString() ?? '',
      previsaoId: map['previsao_id']?.toString(),
      notaSapId: map['nota_sap_id']?.toString() ?? '',
      numeroNota: map['numero_nota']?.toString(),
      mesAnterior: (map['mes_anterior'] as num?)?.toInt(),
      anoAnterior: (map['ano_anterior'] as num?)?.toInt(),
      mesNovo: (map['mes_novo'] as num?)?.toInt(),
      anoNovo: (map['ano_novo'] as num?)?.toInt(),
      motivo: map['motivo']?.toString(),
      operacao: map['operacao']?.toString() ?? 'ATRIBUICAO_INDIVIDUAL',
      loteId: map['lote_id']?.toString(),
      alteradoPor: map['alterado_por']?.toString(),
      alteradoPorNome: map['alterado_por_nome']?.toString(),
      alteradoEm: map['alterado_em'] != null
          ? DateTime.tryParse(map['alterado_em'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'previsao_id': previsaoId,
      'nota_sap_id': notaSapId,
      'numero_nota': numeroNota,
      'mes_anterior': mesAnterior,
      'ano_anterior': anoAnterior,
      'mes_novo': mesNovo,
      'ano_novo': anoNovo,
      'motivo': motivo,
      'operacao': operacao,
      'lote_id': loteId,
      'alterado_por': alteradoPor,
      'alterado_por_nome': alteradoPorNome,
    };
  }

  String get descricaoMudanca {
    final de = mesAnterior != null && anoAnterior != null
        ? '$mesAnterior/$anoAnterior'
        : 'Sem previsão';
    final para = mesNovo != null && anoNovo != null
        ? '$mesNovo/$anoNovo'
        : 'Removida';
    return '$de ➔ $para';
  }
}
