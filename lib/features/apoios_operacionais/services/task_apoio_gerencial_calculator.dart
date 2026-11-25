import '../../../models/task.dart';
import '../domain/enums/task_apoio_enums.dart';
import '../domain/models/task_apoio_gerencial.dart';
import '../domain/models/task_apoio_historico.dart';
import '../domain/models/task_apoio_situacao.dart';
import '../domain/models/task_apoio_solicitacao.dart';
import '../domain/models/task_apoio_vinculo.dart';

/// Calculadora pura dos indicadores gerenciais e de desempenho entre unidades (Fase 7).
/// Reutiliza exclusivamente [TaskApoioSituacao] produzida pelo [TaskApoioCompatibilityEngine],
/// evitando dupla contabilização e sem somar horas de apoio às atividades principais.
class TaskApoioGerencialCalculator {
  const TaskApoioGerencialCalculator._();

  static TaskApoioGerencialIndicadores calcular({
    required List<TaskApoioSolicitacao> solicitacoes,
    required Map<String, TaskApoioSituacao> situacoesPorSolicitacao,
    required Map<String, Task> tasksPorId,
    Map<String, List<TaskApoioVinculo>> vinculosPorSolicitacao = const {},
    Map<String, List<TaskApoioHistorico>> historicoPorSolicitacao = const {},
    Map<String, String> nomesUnidades = const {},
    Map<String, String> nomesTipos = const {},
    String? divisaoAtualId,
    TaskApoioGerencialPerspectiva perspectiva =
        TaskApoioGerencialPerspectiva.consolidada,
    DateTime? referenciaAgora,
  }) {
    final agora = referenciaAgora ?? DateTime.now().toUtc();

    final filtradas = solicitacoes.where((s) {
      if (perspectiva == TaskApoioGerencialPerspectiva.solicitante &&
          divisaoAtualId != null &&
          divisaoAtualId.isNotEmpty) {
        return s.divisaoSolicitanteId == divisaoAtualId;
      }
      if (perspectiva == TaskApoioGerencialPerspectiva.prestadora &&
          divisaoAtualId != null &&
          divisaoAtualId.isNotEmpty) {
        return s.divisaoDestinoId == divisaoAtualId;
      }
      return true;
    }).toList();

    int recebidas = 0;
    int enviadas = 0;
    int aguardando = 0;
    int negociacao = 0;
    int aceitas = 0;
    int aceitasSemProg = 0;
    int parciais = 0;
    int programadosComp = 0;
    int essenciaisRisco = 0;
    int recPendentes = 0;
    int recNaoVerif = 0;
    int reconfPend = 0;
    int prazoUltrap = 0;
    int recusadas = 0;
    int canceladas = 0;
    int concluidos = 0;

    final tasksAfetadas = <String>{};
    final temposPrimeiraRespHoras = <double>[];
    final temposDecisaoHoras = <double>[];
    final temposAceiteParaProgHoras = <double>[];
    final coberturasPercent = <double>[];
    int elegiveisPrazoResp = 0;
    int respondidasNoPrazo = 0;
    int elegiveisAtendPrazo = 0;
    int atendidasNoPrazo = 0;
    int totalReprogramacoes = 0;

    final porUnidade = <String, _DistAcc>{};
    final porTipo = <String, _DistAcc>{};
    final itensReuniao = <TaskApoioItemReuniaoSemanal>[];

    for (final s in filtradas) {
      final sit = situacoesPorSolicitacao[s.id];
      final op = sit?.situacaoOperacional;

      if (divisaoAtualId != null && divisaoAtualId.isNotEmpty) {
        if (s.divisaoDestinoId == divisaoAtualId) recebidas++;
        if (s.divisaoSolicitanteId == divisaoAtualId) enviadas++;
      }

      if (s.status == TaskApoioStatus.pendente ||
          s.status == TaskApoioStatus.emAnalise) {
        aguardando++;
      }
      if (s.status == TaskApoioStatus.contraproposta) {
        negociacao++;
      }
      if (s.status == TaskApoioStatus.aceita) aceitas++;
      if (s.status == TaskApoioStatus.recusada) recusadas++;
      if (s.status == TaskApoioStatus.cancelada) canceladas++;

      if (op == TaskApoioSituacaoOperacional.aceitaSemProgramacao) {
        aceitasSemProg++;
      } else if (op == TaskApoioSituacaoOperacional.parcialmenteProgramada) {
        parciais++;
      } else if (op == TaskApoioSituacaoOperacional.programadaCompativel) {
        programadosComp++;
      } else if (op == TaskApoioSituacaoOperacional.concluida) {
        concluidos++;
      }

      final emRisco = op ==
              TaskApoioSituacaoOperacional.programadaComIncompatibilidade ||
          op == TaskApoioSituacaoOperacional.parcialmenteProgramada ||
          op == TaskApoioSituacaoOperacional.aceitaSemProgramacao;

      if (s.criticidade == TaskApoioCriticidade.essencial && emRisco) {
        essenciaisRisco++;
        if (s.taskSolicitanteId != null) {
          tasksAfetadas.add(s.taskSolicitanteId!);
        }
      }

      if (op == TaskApoioSituacaoOperacional.programadaComRecursosPendentes) {
        recPendentes++;
      }

      if (sit != null &&
          sit.compatibilidade.statusRecursos ==
              TaskApoioStatusCompatibilidadeRecurso.naoVerificado &&
          sit.qtdVinculosAtivos > 0) {
        recNaoVerif++;
      }

      final hist = historicoPorSolicitacao[s.id] ?? const [];
      final precisaReconf = (s.observacoes ?? '')
              .toLowerCase()
              .contains('reconfirma') ||
          hist.any((h) => h.evento.contains('RECONFIRMACAO'));
      if (precisaReconf) {
        reconfPend++;
      }

      if (s.prazoResposta != null &&
          s.prazoResposta!.isBefore(agora) &&
          (s.status == TaskApoioStatus.pendente ||
              s.status == TaskApoioStatus.emAnalise ||
              s.status == TaskApoioStatus.contraproposta)) {
        prazoUltrap++;
      }

      if (sit != null && sit.qtdVinculosAtivos > 0 && s.status.isAtiva) {
        coberturasPercent.add(sit.compatibilidade.percentualCobertura);
      }

      // Métricas baseadas em histórico real (sem inventar dados)
      DateTime? primeiraRespEm;
      DateTime? decisaoDefEm;
      DateTime? aceiteEm;
      DateTime? progEm;
      for (final h in hist) {
        if (h.evento == 'ATIVIDADE_REPROGRAMADA' ||
            h.evento.contains('REPROGRAMA')) {
          totalReprogramacoes++;
        }
        if (h.statusNovo == 'EM_ANALISE' ||
            h.statusNovo == 'ACEITA' ||
            h.statusNovo == 'RECUSADA' ||
            h.statusNovo == 'CONTRAPROPOSTA') {
          if (primeiraRespEm == null || h.createdAt.isBefore(primeiraRespEm)) {
            primeiraRespEm = h.createdAt;
          }
        }
        if (h.statusNovo == 'ACEITA' || h.statusNovo == 'RECUSADA') {
          if (decisaoDefEm == null || h.createdAt.isBefore(decisaoDefEm)) {
            decisaoDefEm = h.createdAt;
          }
        }
        if (h.statusNovo == 'ACEITA') {
          if (aceiteEm == null || h.createdAt.isBefore(aceiteEm)) {
            aceiteEm = h.createdAt;
          }
        }
        if (h.evento == 'ATIVIDADE_APOIO_CRIADA' ||
            h.evento == 'VINCULO_CRIADO') {
          if (progEm == null || h.createdAt.isBefore(progEm)) {
            progEm = h.createdAt;
          }
        }
      }

      final criadoEm = s.createdAt;
      if (criadoEm != null &&
          primeiraRespEm != null &&
          !primeiraRespEm.isBefore(criadoEm)) {
        temposPrimeiraRespHoras.add(
          primeiraRespEm.difference(criadoEm).inMinutes / 60.0,
        );
      }
      if (criadoEm != null &&
          decisaoDefEm != null &&
          !decisaoDefEm.isBefore(criadoEm)) {
        temposDecisaoHoras.add(
          decisaoDefEm.difference(criadoEm).inMinutes / 60.0,
        );
      }
      if (aceiteEm != null && progEm != null && !progEm.isBefore(aceiteEm)) {
        temposAceiteParaProgHoras.add(
          progEm.difference(aceiteEm).inMinutes / 60.0,
        );
      }
      if (s.prazoResposta != null && s.status.isAtiva) {
        if (primeiraRespEm != null) {
          elegiveisPrazoResp++;
          if (!primeiraRespEm.isAfter(s.prazoResposta!)) {
            respondidasNoPrazo++;
          }
        } else if (s.prazoResposta!.isBefore(agora)) {
          elegiveisPrazoResp++;
        }
      }
      if (op == TaskApoioSituacaoOperacional.concluida) {
        elegiveisAtendPrazo++;
        final fimAcordado = s.dataFimAcordada ?? s.dataFimSolicitada;
        final vinculosAtivos = vinculosPorSolicitacao[s.id] ?? const [];
        final fimProg = vinculosAtivos
            .map((v) => tasksPorId[v.taskApoioId]?.dataFim)
            .whereType<DateTime>()
            .fold<DateTime?>(
              null,
              (prev, dt) => prev == null || dt.isAfter(prev) ? dt : prev,
            );
        if (fimProg == null || !fimProg.isAfter(fimAcordado)) {
          atendidasNoPrazo++;
        }
      }

      // Distribuição por unidade de destino (prestadora) ou solicitante
      final unitId = perspectiva == TaskApoioGerencialPerspectiva.prestadora
          ? s.divisaoSolicitanteId
          : s.divisaoDestinoId;
      final unitNome = nomesUnidades[unitId] ?? unitId;
      porUnidade.putIfAbsent(unitId, () => _DistAcc(unitId, unitNome)).add(
            essencial: s.criticidade == TaskApoioCriticidade.essencial,
            riscoOuPendencia: emRisco ||
                s.status == TaskApoioStatus.pendente ||
                s.status == TaskApoioStatus.contraproposta,
            progCompativel:
                op == TaskApoioSituacaoOperacional.programadaCompativel,
          );

      final tipoNome = nomesTipos[s.tipoApoioId] ?? s.tipoApoioId;
      porTipo.putIfAbsent(s.tipoApoioId, () => _DistAcc(s.tipoApoioId, tipoNome))
          .add(
            essencial: s.criticidade == TaskApoioCriticidade.essencial,
            riscoOuPendencia: emRisco ||
                s.status == TaskApoioStatus.pendente ||
                s.status == TaskApoioStatus.contraproposta,
            progCompativel:
                op == TaskApoioSituacaoOperacional.programadaCompativel,
          );

      // Reunião semanal: somente itens ativos que requerem atenção/acompanhamento
      if (sit != null &&
          s.status.isAtiva &&
          op != TaskApoioSituacaoOperacional.concluida &&
          op != TaskApoioSituacaoOperacional.programadaCompativel) {
        final (respId, prov, sev) = _definirProvidencia(s, op, nomesUnidades);
        itensReuniao.add(
          TaskApoioItemReuniaoSemanal(
            solicitacao: s,
            situacao: sit,
            unidadeResponsavelId: respId,
            unidadeResponsavelNome: nomesUnidades[respId] ?? respId,
            providenciaSugerida: prov,
            severidadeOrdem: sev,
          ),
        );
      }
    }

    itensReuniao.sort((a, b) {
      final bySev = a.severidadeOrdem.compareTo(b.severidadeOrdem);
      if (bySev != 0) return bySev;
      return a.solicitacao.dataInicioSolicitada
          .compareTo(b.solicitacao.dataInicioSolicitada);
    });

    double? media(List<double> vals) =>
        vals.isEmpty ? null : vals.reduce((a, b) => a + b) / vals.length;

    return TaskApoioGerencialIndicadores(
      totalSolicitacoes: filtradas.length,
      solicitacoesRecebidas: recebidas,
      solicitacoesEnviadas: enviadas,
      aguardandoResposta: aguardando,
      emNegociacao: negociacao,
      aceitas: aceitas,
      aceitasSemProgramacao: aceitasSemProg,
      parcialmenteProgramados: parciais,
      programadosCompativeis: programadosComp,
      essenciaisEmRisco: essenciaisRisco,
      recursosPendentes: recPendentes,
      recursosNaoVerificados: recNaoVerif,
      reconfirmacaoPendente: reconfPend,
      prazoUltrapassado: prazoUltrap,
      recusadas: recusadas,
      canceladas: canceladas,
      concluidos: concluidos,
      atividadesPrincipaisAfetadas: tasksAfetadas.length,
      tempoMedioPrimeiraRespostaHoras: media(temposPrimeiraRespHoras),
      tempoMedioDecisaoDefinitivaHoras: media(temposDecisaoHoras),
      taxaRespostaNoPrazoPercent: elegiveisPrazoResp == 0
          ? null
          : (respondidasNoPrazo / elegiveisPrazoResp) * 100.0,
      taxaAtendimentoNoPrazoPercent: elegiveisAtendPrazo == 0
          ? null
          : (atendidasNoPrazo / elegiveisAtendPrazo) * 100.0,
      coberturaTemporalMediaPercent: media(coberturasPercent),
      tempoMedioAceiteParaProgramacaoHoras: media(temposAceiteParaProgHoras),
      totalReprogramacoes: totalReprogramacoes,
      distribuicaoPorUnidade: porUnidade.values.map((e) => e.build()).toList()
        ..sort((a, b) => b.totalSolicitacoes.compareTo(a.totalSolicitacoes)),
      distribuicaoPorTipo: porTipo.values.map((e) => e.build()).toList()
        ..sort((a, b) => b.totalSolicitacoes.compareTo(a.totalSolicitacoes)),
      itensReuniaoSemanal: itensReuniao,
    );
  }

  static (String, String, int) _definirProvidencia(
    TaskApoioSolicitacao s,
    TaskApoioSituacaoOperacional? op,
    Map<String, String> nomesUnidades,
  ) {
    if (op == TaskApoioSituacaoOperacional.programadaComIncompatibilidade) {
      return (
        s.divisaoDestinoId,
        'Ajustar período programado ou reconfirmar janela com a unidade solicitante.',
        1,
      );
    }
    if ((s.observacoes ?? '').toLowerCase().contains('reconfirma')) {
      return (
        s.divisaoDestinoId,
        'Reconfirmar disponibilidade após reprogramação da atividade principal.',
        2,
      );
    }
    if (op == TaskApoioSituacaoOperacional.parcialmenteProgramada) {
      return (
        s.divisaoDestinoId,
        'Completar programação para cobrir as lacunas de horário identificadas.',
        3,
      );
    }
    if (op == TaskApoioSituacaoOperacional.aceitaSemProgramacao) {
      return (
        s.divisaoDestinoId,
        'Criar ou vincular atividade de apoio na programação da unidade.',
        4,
      );
    }
    if (op == TaskApoioSituacaoOperacional.programadaComRecursosPendentes) {
      return (
        s.divisaoDestinoId,
        'Alocar veículo/operador/equipe exigidos na atividade de apoio.',
        5,
      );
    }
    if (s.status == TaskApoioStatus.contraproposta) {
      return (
        s.divisaoSolicitanteId,
        'Analisar contraproposta de ${nomesUnidades[s.divisaoDestinoId] ?? s.divisaoDestinoId}.',
        6,
      );
    }
    return (
      s.divisaoDestinoId,
      'Responder solicitação de apoio (${s.criticidade.label}).',
      7,
    );
  }
}

class _DistAcc {
  final String id;
  final String nome;
  int total = 0;
  int essenciais = 0;
  int risco = 0;
  int prog = 0;

  _DistAcc(this.id, this.nome);

  void add({
    required bool essencial,
    required bool riscoOuPendencia,
    required bool progCompativel,
  }) {
    total++;
    if (essencial) essenciais++;
    if (riscoOuPendencia) risco++;
    if (progCompativel) prog++;
  }

  TaskApoioDistribuicaoItem build() => TaskApoioDistribuicaoItem(
        chaveId: id,
        nome: nome,
        totalSolicitacoes: total,
        essenciais: essenciais,
        pendentesOuRisco: risco,
        programadosCompativeis: prog,
      );
}
