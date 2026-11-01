import 'nota_sap.dart';
import 'nota_sap_similaridade.dart';

/// Status administrativo do Grupo de Notas SAP.
enum StatusGrupo {
  ativo,
  encerrado,
  cancelado;

  static StatusGrupo fromString(String? val) {
    switch (val?.toLowerCase().trim()) {
      case 'encerrado':
        return StatusGrupo.encerrado;
      case 'cancelado':
        return StatusGrupo.cancelado;
      case 'ativo':
      default:
        return StatusGrupo.ativo;
    }
  }

  String toDbString() => name;

  String get label {
    switch (this) {
      case StatusGrupo.ativo:
        return 'Ativo';
      case StatusGrupo.encerrado:
        return 'Encerrado';
      case StatusGrupo.cancelado:
        return 'Cancelado';
    }
  }
}

/// Status de programação derivado dinamicamente das tarefas vinculadas (tasks_notas_sap).
enum StatusProgramacaoGrupo {
  naoProgramado,
  parcial,
  total;

  String get label {
    switch (this) {
      case StatusProgramacaoGrupo.naoProgramado:
        return 'Não programado';
      case StatusProgramacaoGrupo.parcial:
        return 'Parcialmente programado';
      case StatusProgramacaoGrupo.total:
        return 'Totalmente programado';
    }
  }
}

/// Entidade principal: Grupo de Notas SAP para futura intervenção conjunta.
class NotaSapGrupo {
  final String id;
  final String nome;
  final String? descricao;
  final String? motivo;

  // Contexto geográfico/ativo (opcional / derivado)
  final String? localInstalacao;
  final String? equipamento;
  final String? centroTrabalhoResponsavel;

  // Previsão Macro de Programação (Mês/Ano inteiros, sem data fictícia)
  final int? mesProgramacaoPrevisto;
  final int? anoProgramacaoPrevisto;
  final String? motivoPrevisao;

  // Status administrativo
  final StatusGrupo statusGrupo;

  // Auditoria
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? previsaoAlteradaEm;
  final String? previsaoAlteradaPor;
  final String? previsaoAlteradaPorNome;

  // Itens do grupo (carregados sob demanda)
  final List<NotaSapGrupoItem> itens;

  const NotaSapGrupo({
    required this.id,
    required this.nome,
    this.descricao,
    this.motivo,
    this.localInstalacao,
    this.equipamento,
    this.centroTrabalhoResponsavel,
    this.mesProgramacaoPrevisto,
    this.anoProgramacaoPrevisto,
    this.motivoPrevisao,
    this.statusGrupo = StatusGrupo.ativo,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.previsaoAlteradaEm,
    this.previsaoAlteradaPor,
    this.previsaoAlteradaPorNome,
    this.itens = const [],
  });

  bool get temPrevisao =>
      mesProgramacaoPrevisto != null && anoProgramacaoPrevisto != null;

  /// Retorna a previsão formatada por extenso, ex: "Novembro/2026"
  String get previsaoFormatada {
    if (!temPrevisao) return 'Não definida';
    const meses = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    return '${meses[mesProgramacaoPrevisto! - 1]}/${anoProgramacaoPrevisto!}';
  }

  /// Retorna a previsão compacta, ex: "Nov/26"
  String get previsaoCompacta {
    if (!temPrevisao) return 'Sem prev.';
    const meses = [
      'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'
    ];
    final ano2Digitos = (anoProgramacaoPrevisto! % 100).toString().padLeft(2, '0');
    return '${meses[mesProgramacaoPrevisto! - 1]}/$ano2Digitos';
  }

  StatusGrupo get status => statusGrupo;
  bool get isAtivo => statusGrupo == StatusGrupo.ativo;
  bool get isEncerrado => statusGrupo == StatusGrupo.encerrado;
  bool get isCancelado => statusGrupo == StatusGrupo.cancelado;

  /// Verifica se a previsão é anterior ao mês corrente (runtime).
  bool isPrevisaoUltrapassada([DateTime? dataReferencia]) {
    if (!temPrevisao) return false;
    final ref = dataReferencia ?? DateTime.now();
    final mesRef = ref.month;
    final anoRef = ref.year;

    final pontosPrevisto = anoProgramacaoPrevisto! * 12 + mesProgramacaoPrevisto!;
    final pontosAtual = anoRef * 12 + mesRef;
    return pontosPrevisto < pontosAtual;
  }

  factory NotaSapGrupo.fromMap(Map<String, dynamic> map, {List<NotaSapGrupoItem> itens = const []}) {
    return NotaSapGrupo(
      id: map['id']?.toString() ?? '',
      nome: map['nome']?.toString() ?? '',
      descricao: map['descricao']?.toString(),
      motivo: map['motivo']?.toString(),
      localInstalacao: map['local_instalacao']?.toString(),
      equipamento: map['equipamento']?.toString(),
      centroTrabalhoResponsavel: map['centro_trabalho_responsavel']?.toString(),
      mesProgramacaoPrevisto: map['mes_programacao_previsto'] != null
          ? int.tryParse(map['mes_programacao_previsto'].toString())
          : null,
      anoProgramacaoPrevisto: map['ano_programacao_previsto'] != null
          ? int.tryParse(map['ano_programacao_previsto'].toString())
          : null,
      motivoPrevisao: map['motivo_previsao']?.toString(),
      statusGrupo: StatusGrupo.fromString(map['status_grupo']?.toString()),
      createdBy: map['created_by']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
      previsaoAlteradaEm: map['previsao_alterada_em'] != null
          ? DateTime.tryParse(map['previsao_alterada_em'].toString())
          : null,
      previsaoAlteradaPor: map['previsao_alterada_por']?.toString(),
      previsaoAlteradaPorNome: map['previsao_alterada_por_nome']?.toString(),
      itens: itens,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'descricao': descricao,
      'motivo': motivo,
      'local_instalacao': localInstalacao,
      'equipamento': equipamento,
      'centro_trabalho_responsavel': centroTrabalhoResponsavel,
      'mes_programacao_previsto': mesProgramacaoPrevisto,
      'ano_programacao_previsto': anoProgramacaoPrevisto,
      'motivo_previsao': motivoPrevisao,
      'status_grupo': statusGrupo.toDbString(),
      'created_by': createdBy,
      'previsao_alterada_em': previsaoAlteradaEm?.toIso8601String(),
      'previsao_alterada_por': previsaoAlteradaPor,
      'previsao_alterada_por_nome': previsaoAlteradaPorNome,
    };
  }

  NotaSapGrupo copyWith({
    String? id,
    String? nome,
    String? descricao,
    String? motivo,
    String? localInstalacao,
    String? equipamento,
    String? centroTrabalhoResponsavel,
    int? mesProgramacaoPrevisto,
    int? anoProgramacaoPrevisto,
    String? motivoPrevisao,
    StatusGrupo? statusGrupo,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? previsaoAlteradaEm,
    String? previsaoAlteradaPor,
    String? previsaoAlteradaPorNome,
    List<NotaSapGrupoItem>? itens,
    bool clearPrevisao = false,
    bool limparPrevisao = false,
  }) {
    final deveLimpar = clearPrevisao || limparPrevisao;
    return NotaSapGrupo(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      descricao: descricao ?? this.descricao,
      motivo: motivo ?? this.motivo,
      localInstalacao: localInstalacao ?? this.localInstalacao,
      equipamento: equipamento ?? this.equipamento,
      centroTrabalhoResponsavel:
          centroTrabalhoResponsavel ?? this.centroTrabalhoResponsavel,
      mesProgramacaoPrevisto:
          deveLimpar ? null : (mesProgramacaoPrevisto ?? this.mesProgramacaoPrevisto),
      anoProgramacaoPrevisto:
          deveLimpar ? null : (anoProgramacaoPrevisto ?? this.anoProgramacaoPrevisto),
      motivoPrevisao:
          deveLimpar ? null : (motivoPrevisao ?? this.motivoPrevisao),
      statusGrupo: statusGrupo ?? this.statusGrupo,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      previsaoAlteradaEm: previsaoAlteradaEm ?? this.previsaoAlteradaEm,
      previsaoAlteradaPor: previsaoAlteradaPor ?? this.previsaoAlteradaPor,
      previsaoAlteradaPorNome:
          previsaoAlteradaPorNome ?? this.previsaoAlteradaPorNome,
      itens: itens ?? this.itens,
    );
  }
}

/// Item associado ao grupo (relação N:1 com Nota SAP).
class NotaSapGrupoItem {
  final String id;
  final String grupoId;
  final String notaSapId;
  final String? motivoVinculo;
  final String? adicionadoPor;
  final String? adicionadoPorNome;
  final DateTime? adicionadoEm;

  // Dados resolvidos sob demanda
  final NotaSAP? nota;
  final List<TarefaHistoricaResumo> tarefasVinculadas;

  const NotaSapGrupoItem({
    required this.id,
    required this.grupoId,
    required this.notaSapId,
    this.motivoVinculo,
    this.adicionadoPor,
    this.adicionadoPorNome,
    this.adicionadoEm,
    this.nota,
    this.tarefasVinculadas = const [],
  });

  bool get isProgramada => tarefasVinculadas.isNotEmpty;

  factory NotaSapGrupoItem.fromMap(
    Map<String, dynamic> map, {
    NotaSAP? nota,
    List<TarefaHistoricaResumo> tarefas = const [],
  }) {
    return NotaSapGrupoItem(
      id: map['id']?.toString() ?? '',
      grupoId: map['grupo_id']?.toString() ?? '',
      notaSapId: map['nota_sap_id']?.toString() ?? '',
      motivoVinculo: map['motivo_vinculo']?.toString(),
      adicionadoPor: map['adicionado_por']?.toString(),
      adicionadoPorNome: map['adicionado_por_nome']?.toString(),
      adicionadoEm: map['adicionado_em'] != null
          ? DateTime.tryParse(map['adicionado_em'].toString())
          : null,
      nota: nota,
      tarefasVinculadas: tarefas,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'grupo_id': grupoId,
      'nota_sap_id': notaSapId,
      'motivo_vinculo': motivoVinculo,
      'adicionado_por': adicionadoPor,
      'adicionado_por_nome': adicionadoPorNome,
    };
  }

  NotaSapGrupoItem copyWith({
    String? id,
    String? grupoId,
    String? notaSapId,
    String? motivoVinculo,
    String? adicionadoPor,
    String? adicionadoPorNome,
    DateTime? adicionadoEm,
    NotaSAP? nota,
    List<TarefaHistoricaResumo>? tarefasVinculadas,
  }) {
    return NotaSapGrupoItem(
      id: id ?? this.id,
      grupoId: grupoId ?? this.grupoId,
      notaSapId: notaSapId ?? this.notaSapId,
      motivoVinculo: motivoVinculo ?? this.motivoVinculo,
      adicionadoPor: adicionadoPor ?? this.adicionadoPor,
      adicionadoPorNome: adicionadoPorNome ?? this.adicionadoPorNome,
      adicionadoEm: adicionadoEm ?? this.adicionadoEm,
      nota: nota ?? this.nota,
      tarefasVinculadas: tarefasVinculadas ?? this.tarefasVinculadas,
    );
  }
}

/// Histórico cronológico de modificação ou cancelamento de previsão.
class NotaSapGrupoPrevisaoHist {
  final String id;
  final String grupoId;
  final int? mesAnterior;
  final int? anoAnterior;
  final int? mesNovo;
  final int? anoNovo;
  final String? motivo;
  final String? alteradoPor;
  final String? alteradoPorNome;
  final DateTime? alteradoEm;

  const NotaSapGrupoPrevisaoHist({
    required this.id,
    required this.grupoId,
    this.mesAnterior,
    this.anoAnterior,
    this.mesNovo,
    this.anoNovo,
    this.motivo,
    this.alteradoPor,
    this.alteradoPorNome,
    this.alteradoEm,
  });

  bool get eraDefinida => mesAnterior != null && anoAnterior != null;
  bool get ficouDefinida => mesNovo != null && anoNovo != null;

  String _formatarMesAno(int? m, int? a) {
    if (m == null || a == null) return 'Sem previsão';
    const meses = [
      'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'
    ];
    final ano2D = (a % 100).toString().padLeft(2, '0');
    return '${meses[m - 1]}/$ano2D';
  }

  String _formatarMesAnoExtenso(int? m, int? a) {
    if (m == null || a == null) return 'Sem previsão';
    const meses = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    return '${meses[m - 1]}/$a';
  }

  String get previsaoAnteriorFormatada => _formatarMesAnoExtenso(mesAnterior, anoAnterior);
  String get previsaoNovaFormatada => _formatarMesAnoExtenso(mesNovo, anoNovo);
  String get descricaoMudanca => '$previsaoAnteriorFormatada → $previsaoNovaFormatada';

  String get transicaoTexto {
    final de = _formatarMesAno(mesAnterior, anoAnterior);
    final para = _formatarMesAno(mesNovo, anoNovo);
    return '$de → $para';
  }

  factory NotaSapGrupoPrevisaoHist.fromMap(Map<String, dynamic> map) {
    return NotaSapGrupoPrevisaoHist(
      id: map['id']?.toString() ?? '',
      grupoId: map['grupo_id']?.toString() ?? '',
      mesAnterior: map['mes_anterior'] != null
          ? int.tryParse(map['mes_anterior'].toString())
          : null,
      anoAnterior: map['ano_anterior'] != null
          ? int.tryParse(map['ano_anterior'].toString())
          : null,
      mesNovo: map['mes_novo'] != null
          ? int.tryParse(map['mes_novo'].toString())
          : null,
      anoNovo: map['ano_novo'] != null
          ? int.tryParse(map['ano_novo'].toString())
          : null,
      motivo: map['motivo']?.toString(),
      alteradoPor: map['alterado_por']?.toString(),
      alteradoPorNome: map['alterado_por_nome']?.toString(),
      alteradoEm: map['alterado_em'] != null
          ? DateTime.tryParse(map['alterado_em'].toString())
          : null,
    );
  }
}

/// DTO com o status de programação derivado do grupo.
class GrupoStatusProgramacao {
  final int totalNotas;
  final int notasProgramadas;
  final int notasNaoProgramadas;
  final StatusProgramacaoGrupo status;
  final List<String> tarefasIds;

  const GrupoStatusProgramacao({
    required this.totalNotas,
    required this.notasProgramadas,
    required this.notasNaoProgramadas,
    required this.status,
    this.tarefasIds = const [],
  });

  bool get isTotal => status == StatusProgramacaoGrupo.total;
  bool get isParcial => status == StatusProgramacaoGrupo.parcial;
  bool get isNaoProgramado => status == StatusProgramacaoGrupo.naoProgramado;

  double get percentualProgramado =>
      totalNotas == 0 ? 0.0 : (notasProgramadas / totalNotas) * 100.0;

  String get descricao {
    switch (status) {
      case StatusProgramacaoGrupo.naoProgramado:
        return 'Grupo sem programação';
      case StatusProgramacaoGrupo.parcial:
        return 'Grupo parcialmente programado';
      case StatusProgramacaoGrupo.total:
        return 'Grupo totalmente programado';
    }
  }

  List<String> get tarefasVinculadasIds => tarefasIds;

  String get resumoFormatado {
    if (totalNotas == 0) return 'Grupo sem notas vinculadas';
    switch (status) {
      case StatusProgramacaoGrupo.naoProgramado:
        return 'Nenhuma das $totalNotas notas programada';
      case StatusProgramacaoGrupo.parcial:
        return '$notasProgramadas de $totalNotas notas programadas (Parcial)';
      case StatusProgramacaoGrupo.total:
        return 'Todas as $totalNotas notas programadas';
    }
  }

  /// Calcula dinamicamente o status a partir de um mapa de notas e tarefas vinculadas.
  factory GrupoStatusProgramacao.calcularMap({
    required String grupoId,
    required int totalNotas,
    required Map<String, List<String>> notasSapComTarefas,
  }) {
    final total = totalNotas;
    if (total == 0) {
      return const GrupoStatusProgramacao(
        totalNotas: 0,
        notasProgramadas: 0,
        notasNaoProgramadas: 0,
        status: StatusProgramacaoGrupo.naoProgramado,
      );
    }

    final tarefasUnicas = <String>{};
    int programadas = 0;

    for (final entry in notasSapComTarefas.entries) {
      if (entry.value.isNotEmpty) {
        programadas++;
        tarefasUnicas.addAll(entry.value);
      }
    }

    final naoProgramadas = total - programadas;
    final StatusProgramacaoGrupo st;
    if (programadas == 0) {
      st = StatusProgramacaoGrupo.naoProgramado;
    } else if (programadas == total) {
      st = StatusProgramacaoGrupo.total;
    } else {
      st = StatusProgramacaoGrupo.parcial;
    }

    return GrupoStatusProgramacao(
      totalNotas: total,
      notasProgramadas: programadas,
      notasNaoProgramadas: naoProgramadas,
      status: st,
      tarefasIds: tarefasUnicas.toList(),
    );
  }

  /// Calcula dinamicamente o status com base na lista de itens e tarefas vinculadas.
  factory GrupoStatusProgramacao.calcular(List<NotaSapGrupoItem> itens) {
    final total = itens.length;
    if (total == 0) {
      return const GrupoStatusProgramacao(
        totalNotas: 0,
        notasProgramadas: 0,
        notasNaoProgramadas: 0,
        status: StatusProgramacaoGrupo.naoProgramado,
      );
    }

    final tarefasUnicas = <String>{};
    int programadas = 0;

    for (final item in itens) {
      if (item.isProgramada) {
        programadas++;
        for (final t in item.tarefasVinculadas) {
          tarefasUnicas.add(t.id);
        }
      }
    }

    final naoProgramadas = total - programadas;
    final StatusProgramacaoGrupo st;
    if (programadas == 0) {
      st = StatusProgramacaoGrupo.naoProgramado;
    } else if (programadas == total) {
      st = StatusProgramacaoGrupo.total;
    } else {
      st = StatusProgramacaoGrupo.parcial;
    }

    return GrupoStatusProgramacao(
      totalNotas: total,
      notasProgramadas: programadas,
      notasNaoProgramadas: naoProgramadas,
      status: st,
      tarefasIds: tarefasUnicas.toList(),
    );
  }
}
