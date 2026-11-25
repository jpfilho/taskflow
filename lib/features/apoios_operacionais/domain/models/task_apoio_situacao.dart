import '../enums/task_apoio_enums.dart';
import 'task_apoio_compatibilidade.dart';

/// Situação operacional calculada de uma solicitação de apoio (sem persistir redundância no banco).
class TaskApoioSituacao {
  final String solicitacaoId;
  final TaskApoioStatus statusSolicitacao;
  final TaskApoioSituacaoOperacional situacaoOperacional;
  final TaskApoioCompatibilidade compatibilidade;
  final int qtdVinculosAtivos;
  final DateTime? menorInicioProgramado;
  final DateTime? maiorFimProgramado;

  const TaskApoioSituacao({
    required this.solicitacaoId,
    required this.statusSolicitacao,
    required this.situacaoOperacional,
    required this.compatibilidade,
    this.qtdVinculosAtivos = 0,
    this.menorInicioProgramado,
    this.maiorFimProgramado,
  });

  Map<String, dynamic> toJson() => {
        'solicitacao_id': solicitacaoId,
        'status_solicitacao': statusSolicitacao.dbValue,
        'situacao_operacional': situacaoOperacional.code,
        'compatibilidade': compatibilidade.toJson(),
        'qtd_vinculos_ativos': qtdVinculosAtivos,
        'menor_inicio_programado':
            menorInicioProgramado?.toUtc().toIso8601String(),
        'maior_fim_programado': maiorFimProgramado?.toUtc().toIso8601String(),
      };
}

/// Resumo gerencial consolidado por atividade principal ou de apoio (`v_tasks_apoios_resumo_task`).
class TaskApoioResumo {
  final String taskId;
  final int totalSolicitacoes;
  final int qtdAguardandoResposta;
  final int qtdAceitosSemProgramacao;
  final int qtdIncompativeis;
  final int qtdEssenciaisPendentes;
  final int qtdAtividadesApoiadas;
  final TaskApoioSituacaoGerencial situacaoGerencial;

  const TaskApoioResumo({
    required this.taskId,
    this.totalSolicitacoes = 0,
    this.qtdAguardandoResposta = 0,
    this.qtdAceitosSemProgramacao = 0,
    this.qtdIncompativeis = 0,
    this.qtdEssenciaisPendentes = 0,
    this.qtdAtividadesApoiadas = 0,
    this.situacaoGerencial = TaskApoioSituacaoGerencial.semDependencias,
  });

  bool get possuiPendenciasOuRiscos =>
      qtdAguardandoResposta > 0 ||
      qtdAceitosSemProgramacao > 0 ||
      qtdIncompativeis > 0 ||
      qtdEssenciaisPendentes > 0;

  factory TaskApoioResumo.fromViewJson(Map<String, dynamic> json) {
    final total = (json['total_solicitacoes'] as num?)?.toInt() ?? 0;
    final aguardando =
        (json['qtd_aguardando_resposta'] as num?)?.toInt() ?? 0;
    final semProg =
        (json['qtd_aceitos_sem_programacao'] as num?)?.toInt() ?? 0;
    final incomp = (json['qtd_incompativeis'] as num?)?.toInt() ?? 0;
    final essPend =
        (json['qtd_essenciais_pendentes'] as num?)?.toInt() ?? 0;
    final apoiadas =
        (json['qtd_atividades_apoiadas'] as num?)?.toInt() ?? 0;
    final sitRaw = json['situacao_integrada']?.toString();

    return TaskApoioResumo(
      taskId: json['task_id']?.toString() ?? '',
      totalSolicitacoes: total,
      qtdAguardandoResposta: aguardando,
      qtdAceitosSemProgramacao: semProg,
      qtdIncompativeis: incomp,
      qtdEssenciaisPendentes: essPend,
      qtdAtividadesApoiadas: apoiadas,
      situacaoGerencial: _mapSituacaoGerencialFromDb(sitRaw, total),
    );
  }

  static TaskApoioSituacaoGerencial _mapSituacaoGerencialFromDb(
    String? raw,
    int total,
  ) {
    if (total == 0) return TaskApoioSituacaoGerencial.semDependencias;
    switch (raw) {
      case 'INCOMPATIVEL':
        return TaskApoioSituacaoGerencial.programacaoComRiscoApoio;
      case 'AGUARDANDO_ESSENCIAL':
        return TaskApoioSituacaoGerencial.aguardandoConfirmacaoEssencial;
      case 'ACEITO_SEM_PROGRAMACAO':
        return TaskApoioSituacaoGerencial.essencialAceitoSemProgramacao;
      case 'REGULAR':
        return TaskApoioSituacaoGerencial.essenciaisProgramadosCompativeis;
      default:
        return TaskApoioSituacaoGerencial.semDependencias;
    }
  }

  Map<String, dynamic> toJson() => {
        'task_id': taskId,
        'total_solicitacoes': totalSolicitacoes,
        'qtd_aguardando_resposta': qtdAguardandoResposta,
        'qtd_aceitos_sem_programacao': qtdAceitosSemProgramacao,
        'qtd_incompativeis': qtdIncompativeis,
        'qtd_essenciais_pendentes': qtdEssenciaisPendentes,
        'qtd_atividades_apoiadas': qtdAtividadesApoiadas,
        'situacao_gerencial': situacaoGerencial.code,
      };
}

/// Indicadores gerenciais agregados da Central de Apoios.
class TaskApoioIndicadores {
  final int totalSolicitacoes;
  final int pendentes;
  final int emAnalise;
  final int contrapropostas;
  final int aceitas;
  final int recusadas;
  final int canceladas;
  final int aceitasSemProgramacao;
  final int parcialmenteProgramadas;
  final int comIncompatibilidadeOuRisco;
  final int comRecursosPendentes;
  final int urgentesAbertas;

  const TaskApoioIndicadores({
    this.totalSolicitacoes = 0,
    this.pendentes = 0,
    this.emAnalise = 0,
    this.contrapropostas = 0,
    this.aceitas = 0,
    this.recusadas = 0,
    this.canceladas = 0,
    this.aceitasSemProgramacao = 0,
    this.parcialmenteProgramadas = 0,
    this.comIncompatibilidadeOuRisco = 0,
    this.comRecursosPendentes = 0,
    this.urgentesAbertas = 0,
  });

  Map<String, dynamic> toJson() => {
        'total_solicitacoes': totalSolicitacoes,
        'pendentes': pendentes,
        'em_analise': emAnalise,
        'contrapropostas': contrapropostas,
        'aceitas': aceitas,
        'recusadas': recusadas,
        'canceladas': canceladas,
        'aceitas_sem_programacao': aceitasSemProgramacao,
        'parcialmente_programadas': parcialmenteProgramadas,
        'com_incompatibilidade_ou_risco': comIncompatibilidadeOuRisco,
        'com_recursos_pendentes': comRecursosPendentes,
        'urgentes_abertas': urgentesAbertas,
      };
}

