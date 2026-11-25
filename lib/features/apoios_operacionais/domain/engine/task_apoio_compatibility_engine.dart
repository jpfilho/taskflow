import '../../../../models/task.dart';
import '../enums/task_apoio_enums.dart';
import '../models/task_apoio_compatibilidade.dart';
import '../models/task_apoio_situacao.dart';
import '../models/task_apoio_solicitacao.dart';
import '../models/task_apoio_tipo.dart';
import '../models/task_apoio_vinculo.dart';

/// Parâmetro de entrada representando uma atividade vinculada e seu vínculo.
class TaskApoioVinculoComTask {
  final TaskApoioVinculo vinculo;
  final Task? taskApoio;

  const TaskApoioVinculoComTask({
    required this.vinculo,
    this.taskApoio,
  });
}

/// Motor independente e testável de compatibilidade temporal, Gantt, recursos,
/// apoios compartilhados e situação operacional/gerencial.
class TaskApoioCompatibilityEngine {
  /// Códigos de tipos de apoio onde `DESLOCAMENTO` também é atendimento efetivo.
  static const Set<String> tiposComDeslocamentoEfetivo = {
    'TRANSPORTE',
    'LOGISTICA',
  };

  /// Avalia a compatibilidade completa de uma solicitação frente às atividades vinculadas.
  TaskApoioCompatibilidade avaliarSolicitacao({
    required TaskApoioSolicitacao solicitacao,
    required List<TaskApoioVinculoComTask> vinculos,
    TaskApoioTipo? tipoApoio,
    Task? taskPrincipal,
    List<TaskApoioVinculoComTask> outrosVinculosMesmasTasksApoio = const [],
  }) {
    final necessidadesBrutas = solicitacao.periodosNecessidadeVigentes
        .where((p) => p.isValid)
        .map(
          (p) => TaskApoioIntervalo(
            inicio: p.dataInicio,
            fim: p.dataFim,
            origem: p.origemPeriodo.dbValue,
          ),
        )
        .toList();

    final necessidades = consolidarIntervalos(necessidadesBrutas);
    final duracaoNecessaria = somarDuracoes(necessidades);

    final vinculosAtivos = vinculos
        .where(
          (v) =>
              v.vinculo.ativo &&
              v.vinculo.statusConfirmacao ==
                  TaskApoioStatusConfirmacaoVinculo.confirmado,
        )
        .toList();
    final incluirDeslocamento = tipoApoio != null &&
        tiposComDeslocamentoEfetivo.contains(tipoApoio.codigo.toUpperCase());

    final intervalosProgramadosBrutos = <TaskApoioIntervalo>[];
    final tasksValidas = <Task>[];

    for (final item in vinculosAtivos) {
      final task = item.taskApoio;
      if (task == null || _isTaskCancelada(task)) {
        continue;
      }
      tasksValidas.add(task);
      final extraidos = extrairIntervalosEfetivosDaTask(
        task: task,
        incluirDeslocamento: incluirDeslocamento,
        janelaCoberturaInicio: item.vinculo.coberturaInicio,
        janelaCoberturaFim: item.vinculo.coberturaFim,
      );
      intervalosProgramadosBrutos.addAll(extraidos);
    }

    final programados = consolidarIntervalos(intervalosProgramadosBrutos);
    final duracaoCoberta = calcularDuracaoCoberta(necessidades, programados);
    final lacunas = calcularDiferenca(necessidades, programados);
    final excedentes = calcularDiferenca(programados, necessidades);

    final double percentual;
    if (duracaoNecessaria.inMilliseconds <= 0) {
      percentual = programados.isNotEmpty ? 100.0 : 0.0;
    } else {
      percentual = ((duracaoCoberta.inMilliseconds /
                  duracaoNecessaria.inMilliseconds) *
              100.0)
          .clamp(0.0, 100.0);
    }

    final TaskApoioStatusCompatibilidadeTemporal statusTemporal;
    if (programados.isEmpty || duracaoCoberta.inMilliseconds == 0) {
      statusTemporal = TaskApoioStatusCompatibilidadeTemporal.semCobertura;
    } else if (lacunas.isEmpty) {
      statusTemporal = TaskApoioStatusCompatibilidadeTemporal.integral;
    } else {
      statusTemporal = TaskApoioStatusCompatibilidadeTemporal.parcial;
    }

    // Avaliar recursos
    final avaliacaoRecursos = _avaliarRecursos(
      solicitacao: solicitacao,
      tipoApoio: tipoApoio,
      tasksApoioValidas: tasksValidas,
    );

    // Avaliar compartilhamento
    final alertasCompartilhamento = _avaliarCompartilhamento(
      vinculosAtuais: vinculosAtivos,
      outrosVinculos: outrosVinculosMesmasTasksApoio,
    );

    final statusRecursosFinal = alertasCompartilhamento.isNotEmpty &&
            avaliacaoRecursos.status !=
                TaskApoioStatusCompatibilidadeRecurso.incompativel
        ? TaskApoioStatusCompatibilidadeRecurso.conflitoCompartilhamento
        : avaliacaoRecursos.status;

    final possuiDescontinuo = necessidades.length > 1 || programados.length > 1;
    final possuiPrevioOuPosterior = _verificarPrevioOuPosterior(
      necessidades: necessidades,
      taskPrincipal: taskPrincipal,
    );

    final resumo = _montarResumoExplicativo(
      statusTemporal: statusTemporal,
      percentual: percentual,
      lacunas: lacunas,
      statusRecursos: statusRecursosFinal,
      pendenciasRecursos: avaliacaoRecursos.pendencias,
      alertasCompartilhamento: alertasCompartilhamento,
    );

    return TaskApoioCompatibilidade(
      statusTemporal: statusTemporal,
      statusRecursos: statusRecursosFinal,
      percentualCobertura: double.parse(percentual.toStringAsFixed(2)),
      duracaoNecessaria: duracaoNecessaria,
      duracaoCoberta: duracaoCoberta,
      intervalosNecessariosConsolidados: necessidades,
      intervalosProgramadosConsolidados: programados,
      lacunas: lacunas,
      excedentes: excedentes,
      possuiPeriodosDescontinuos: possuiDescontinuo,
      possuiApoioPrevioOuPosterior: possuiPrevioOuPosterior,
      pendenciasRecursos: avaliacaoRecursos.pendencias,
      alertasCompartilhamento: alertasCompartilhamento,
      resumoExplicativo: resumo,
    );
  }

  /// Calcula a situação operacional completa de uma solicitação.
  TaskApoioSituacao calcularSituacaoSolicitacao({
    required TaskApoioSolicitacao solicitacao,
    required List<TaskApoioVinculoComTask> vinculos,
    TaskApoioTipo? tipoApoio,
    Task? taskPrincipal,
    List<TaskApoioVinculoComTask> outrosVinculosMesmasTasksApoio = const [],
  }) {
    final compat = avaliarSolicitacao(
      solicitacao: solicitacao,
      vinculos: vinculos,
      tipoApoio: tipoApoio,
      taskPrincipal: taskPrincipal,
      outrosVinculosMesmasTasksApoio: outrosVinculosMesmasTasksApoio,
    );

    final vinculosAtivos = vinculos
        .where(
          (v) =>
              v.vinculo.ativo &&
              v.vinculo.statusConfirmacao ==
                  TaskApoioStatusConfirmacaoVinculo.confirmado,
        )
        .toList();
    final tasksValidas = vinculosAtivos
        .map((v) => v.taskApoio)
        .whereType<Task>()
        .where((t) => !_isTaskCancelada(t))
        .toList();

    DateTime? menorInicio;
    DateTime? maiorFim;
    for (final iv in compat.intervalosProgramadosConsolidados) {
      if (menorInicio == null || iv.inicio.isBefore(menorInicio)) {
        menorInicio = iv.inicio;
      }
      if (maiorFim == null || iv.fim.isAfter(maiorFim)) {
        maiorFim = iv.fim;
      }
    }

    final situacaoOp = _determinarSituacaoOperacional(
      solicitacao: solicitacao,
      tasksValidas: tasksValidas,
      compat: compat,
    );

    return TaskApoioSituacao(
      solicitacaoId: solicitacao.id,
      statusSolicitacao: solicitacao.status,
      situacaoOperacional: situacaoOp,
      compatibilidade: compat,
      qtdVinculosAtivos: vinculosAtivos.length,
      menorInicioProgramado: menorInicio,
      maiorFimProgramado: maiorFim,
    );
  }

  /// Consolida a situação gerencial da atividade principal com base nas situações
  /// das suas solicitações de apoio.
  TaskApoioResumo consolidarResumoTaskPrincipal({
    required String taskId,
    required List<TaskApoioSolicitacao> solicitacoesDaTask,
    required List<TaskApoioSituacao> situacoes,
    int qtdAtividadesApoiadas = 0,
  }) {
    if (solicitacoesDaTask.isEmpty) {
      return TaskApoioResumo(
        taskId: taskId,
        qtdAtividadesApoiadas: qtdAtividadesApoiadas,
        situacaoGerencial: TaskApoioSituacaoGerencial.semDependencias,
      );
    }

    final ativas = <TaskApoioSolicitacao>[];
    for (final s in solicitacoesDaTask) {
      if (s.status != TaskApoioStatus.cancelada &&
          s.status != TaskApoioStatus.recusada) {
        ativas.add(s);
      }
    }

    if (ativas.isEmpty) {
      return TaskApoioResumo(
        taskId: taskId,
        totalSolicitacoes: solicitacoesDaTask.length,
        qtdAtividadesApoiadas: qtdAtividadesApoiadas,
        situacaoGerencial: TaskApoioSituacaoGerencial.semDependencias,
      );
    }

    final sitMap = {for (final s in situacoes) s.solicitacaoId: s};
    int aguardando = 0;
    int aceitosSemProg = 0;
    int incompativeis = 0;
    int essenciaisPendentes = 0;
    bool temEssencial = false;
    bool todosEssenciaisConcluidos = true;
    bool temEssencialParcial = false;

    for (final sol in ativas) {
      final isEssencial = sol.criticidade == TaskApoioCriticidade.essencial;
      if (isEssencial) temEssencial = true;

      final sit = sitMap[sol.id];
      final op = sit?.situacaoOperacional;

      if (sol.status == TaskApoioStatus.pendente ||
          sol.status == TaskApoioStatus.emAnalise ||
          sol.status == TaskApoioStatus.contraproposta) {
        aguardando++;
        if (isEssencial) {
          essenciaisPendentes++;
          todosEssenciaisConcluidos = false;
        }
      } else if (op == TaskApoioSituacaoOperacional.aceitaSemProgramacao) {
        aceitosSemProg++;
        if (isEssencial) todosEssenciaisConcluidos = false;
      } else if (op ==
              TaskApoioSituacaoOperacional.programadaComIncompatibilidade ||
          op == TaskApoioSituacaoOperacional.programadaComRecursosPendentes) {
        incompativeis++;
        if (isEssencial) todosEssenciaisConcluidos = false;
      } else if (op == TaskApoioSituacaoOperacional.parcialmenteProgramada) {
        if (isEssencial) {
          temEssencialParcial = true;
          todosEssenciaisConcluidos = false;
        }
      } else if (op != TaskApoioSituacaoOperacional.concluida) {
        if (isEssencial) todosEssenciaisConcluidos = false;
      }
    }

    final TaskApoioSituacaoGerencial gerencial;
    if (!temEssencial) {
      gerencial = TaskApoioSituacaoGerencial.apenasComplementares;
    } else if (incompativeis > 0) {
      gerencial = TaskApoioSituacaoGerencial.programacaoComRiscoApoio;
    } else if (essenciaisPendentes > 0) {
      gerencial = TaskApoioSituacaoGerencial.aguardandoConfirmacaoEssencial;
    } else if (aceitosSemProg > 0) {
      gerencial = TaskApoioSituacaoGerencial.essencialAceitoSemProgramacao;
    } else if (temEssencialParcial) {
      gerencial = TaskApoioSituacaoGerencial.essencialParcialmenteProgramado;
    } else if (todosEssenciaisConcluidos) {
      gerencial = TaskApoioSituacaoGerencial.essenciaisConcluidos;
    } else {
      gerencial = TaskApoioSituacaoGerencial.essenciaisProgramadosCompativeis;
    }

    return TaskApoioResumo(
      taskId: taskId,
      totalSolicitacoes: solicitacoesDaTask.length,
      qtdAguardandoResposta: aguardando,
      qtdAceitosSemProgramacao: aceitosSemProg,
      qtdIncompativeis: incompativeis,
      qtdEssenciaisPendentes: essenciaisPendentes,
      qtdAtividadesApoiadas: qtdAtividadesApoiadas,
      situacaoGerencial: gerencial,
    );
  }

  /// Extrai períodos efetivos de uma atividade respeitando `ganttSegments`,
  /// `frotaPeriods` e `executorPeriods`, diferenciando PLANEJAMENTO, DESLOCAMENTO e EXECUCAO.
  List<TaskApoioIntervalo> extrairIntervalosEfetivosDaTask({
    required Task task,
    bool incluirDeslocamento = false,
    DateTime? janelaCoberturaInicio,
    DateTime? janelaCoberturaFim,
  }) {
    if (_isTaskCancelada(task)) return const [];

    final tiposPermitidos = <String>{'EXECUCAO'};
    if (incluirDeslocamento) {
      tiposPermitidos.add('DESLOCAMENTO');
    }

    final coletados = <TaskApoioIntervalo>[];

    bool segmentoValido(GanttSegment seg) {
      final tipo = seg.tipoPeriodo.trim().toUpperCase();
      return tiposPermitidos.contains(tipo) && !seg.dataFim.isBefore(seg.dataInicio);
    }

    // Corrige o deslocamento de fuso horário quando `_loadGanttSegmentsBatch`
    // corta `+00:00` de timestamps UTC (ex.: 00:00 local salvo como 03:00Z
    // lido como 03:00 local, enquanto `task.dataInicio` foi truncado para 00:00 local).
    DateTime normalizarDataSegmento(DateTime dt, DateTime referenciaTask) {
      if (dt.isUtc) return dt;
      if (referenciaTask.hour != 0 || referenciaTask.minute != 0) return dt;
      final offsetMin = dt.timeZoneOffset.inMinutes;
      if (offsetMin == 0) return dt;
      final utcReinterpretado = DateTime.utc(
        dt.year,
        dt.month,
        dt.day,
        dt.hour,
        dt.minute,
        dt.second,
        dt.millisecond,
      ).toLocal();
      if (utcReinterpretado.year == referenciaTask.year &&
          utcReinterpretado.month == referenciaTask.month &&
          utcReinterpretado.day == referenciaTask.day &&
          utcReinterpretado.hour == 0 &&
          utcReinterpretado.minute == 0) {
        return utcReinterpretado;
      }
      return dt;
    }

    for (final seg in task.ganttSegments) {
      if (segmentoValido(seg)) {
        coletados.add(
          TaskApoioIntervalo(
            inicio: normalizarDataSegmento(seg.dataInicio, task.dataInicio),
            fim: normalizarDataSegmento(seg.dataFim, task.dataFim),
            origem: 'gantt_segments:${seg.tipoPeriodo}',
            taskId: task.id,
          ),
        );
      }
    }

    for (final fp in task.frotaPeriods) {
      for (final seg in fp.periods) {
        if (segmentoValido(seg)) {
          coletados.add(
            TaskApoioIntervalo(
              inicio: seg.dataInicio,
              fim: seg.dataFim,
              origem: 'frota_periods:${seg.tipoPeriodo}',
              taskId: task.id,
            ),
          );
        }
      }
    }

    for (final ep in task.executorPeriods) {
      for (final seg in ep.periods) {
        if (segmentoValido(seg)) {
          coletados.add(
            TaskApoioIntervalo(
              inicio: seg.dataInicio,
              fim: seg.dataFim,
              origem: 'executor_periods:${seg.tipoPeriodo}',
              taskId: task.id,
            ),
          );
        }
      }
    }

    // Se a atividade não possui nenhum segmento detalhado (nem mesmo só planejamento),
    // usa o período geral da tarefa. Se possuir segmentos apenas de PLANEJAMENTO,
    // não considera planejamento como execução efetiva!
    final possuiAlgumDetalheGantt = task.ganttSegments.isNotEmpty ||
        task.frotaPeriods.any((fp) => fp.periods.isNotEmpty) ||
        task.executorPeriods.any((ep) => ep.periods.isNotEmpty);

    if (!possuiAlgumDetalheGantt && !task.dataFim.isBefore(task.dataInicio)) {
      coletados.add(
        TaskApoioIntervalo(
          inicio: task.dataInicio,
          fim: task.dataFim,
          origem: 'task_geral',
          taskId: task.id,
        ),
      );
    }

    final consolidados = consolidarIntervalos(coletados);

    if (janelaCoberturaInicio == null && janelaCoberturaFim == null) {
      return consolidados;
    }

    final janIni = (janelaCoberturaInicio ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true))
        .toUtc();
    final janFim = (janelaCoberturaFim ??
            DateTime.utc(2100, 1, 1))
        .toUtc();

    final recortados = <TaskApoioIntervalo>[];
    for (final iv in consolidados) {
      final ini = iv.inicio.isAfter(janIni) ? iv.inicio : janIni;
      final fim = iv.fim.isBefore(janFim) ? iv.fim : janFim;
      if (fim.isAfter(ini)) {
        recortados.add(
          TaskApoioIntervalo(
            inicio: ini,
            fim: fim,
            origem: iv.origem,
            taskId: iv.taskId,
          ),
        );
      }
    }
    return recortados;
  }

  /// Consolida intervalos sobrepostos ou adjacentes, evitando dupla contabilização.
  List<TaskApoioIntervalo> consolidarIntervalos(
    List<TaskApoioIntervalo> intervalos,
  ) {
    final validos = intervalos.where((i) => i.isValid && i.duracao.inMilliseconds > 0).toList();
    if (validos.isEmpty) return const [];

    validos.sort((a, b) {
      final cmp = a.inicio.compareTo(b.inicio);
      return cmp != 0 ? cmp : a.fim.compareTo(b.fim);
    });

    final merged = <TaskApoioIntervalo>[validos.first];
    for (int i = 1; i < validos.length; i++) {
      final atual = validos[i];
      final ultimo = merged.last;
      if (!atual.inicio.isAfter(ultimo.fim)) {
        final novoFim = atual.fim.isAfter(ultimo.fim) ? atual.fim : ultimo.fim;
        merged[merged.length - 1] = TaskApoioIntervalo(
          inicio: ultimo.inicio,
          fim: novoFim,
          origem: ultimo.origem,
          taskId: ultimo.taskId,
        );
      } else {
        merged.add(atual);
      }
    }
    return merged;
  }

  Duration somarDuracoes(List<TaskApoioIntervalo> intervalos) {
    var totalMs = 0;
    for (final iv in intervalos) {
      totalMs += iv.duracao.inMilliseconds;
    }
    return Duration(milliseconds: totalMs);
  }

  /// Calcula a duração total de `alvo` coberta por `cobertura` (ambos já consolidados).
  Duration calcularDuracaoCoberta(
    List<TaskApoioIntervalo> alvo,
    List<TaskApoioIntervalo> cobertura,
  ) {
    var totalMs = 0;
    for (final a in alvo) {
      for (final c in cobertura) {
        final ini = a.inicio.isAfter(c.inicio) ? a.inicio : c.inicio;
        final fim = a.fim.isBefore(c.fim) ? a.fim : c.fim;
        if (fim.isAfter(ini)) {
          totalMs += fim.difference(ini).inMilliseconds;
        }
      }
    }
    return Duration(milliseconds: totalMs);
  }

  /// Calcula `base \ subtrair` (lacunas quando `base = necessidades, subtrair = programados`).
  List<TaskApoioIntervalo> calcularDiferenca(
    List<TaskApoioIntervalo> base,
    List<TaskApoioIntervalo> subtrair,
  ) {
    var restantes = List<TaskApoioIntervalo>.from(base);

    for (final sub in subtrair) {
      final proximo = <TaskApoioIntervalo>[];
      for (final b in restantes) {
        if (!sub.fim.isAfter(b.inicio) || !sub.inicio.isBefore(b.fim)) {
          proximo.add(b);
          continue;
        }
        if (sub.inicio.isAfter(b.inicio)) {
          proximo.add(
            TaskApoioIntervalo(
              inicio: b.inicio,
              fim: sub.inicio,
              origem: b.origem,
            ),
          );
        }
        if (sub.fim.isBefore(b.fim)) {
          proximo.add(
            TaskApoioIntervalo(
              inicio: sub.fim,
              fim: b.fim,
              origem: b.origem,
            ),
          );
        }
      }
      restantes = proximo;
    }

    return restantes;
  }

  _AvaliacaoRecursosResult _avaliarRecursos({
    required TaskApoioSolicitacao solicitacao,
    required TaskApoioTipo? tipoApoio,
    required List<Task> tasksApoioValidas,
  }) {
    final req = solicitacao.requisitosRecursos;
    final exigeVeiculoPorTipo = tipoApoio?.exigeRecursoFrota ?? false;
    final exigeEquipePorTipo = tipoApoio?.exigeRecursoEquipe ?? false;

    final possuiExigenciaEstruturada =
        (req != null && req.possuiExigenciaVerificavel) ||
            exigeVeiculoPorTipo ||
            exigeEquipePorTipo;

    if (!possuiExigenciaEstruturada) {
      return const _AvaliacaoRecursosResult(
        status: TaskApoioStatusCompatibilidadeRecurso.naoVerificado,
        pendencias: [
          'Solicitação genérica/descritiva sem especificação estruturada de recursos.',
        ],
      );
    }

    if (tasksApoioValidas.isEmpty) {
      return const _AvaliacaoRecursosResult(
        status: TaskApoioStatusCompatibilidadeRecurso.pendente,
        pendencias: ['Nenhuma atividade de apoio ativa vinculada.'],
      );
    }

    final pendencias = <String>[];
    bool incompatibilidade = false;

    final precisaVeiculo =
        (req?.exigeVeiculo ?? false) ||
            exigeVeiculoPorTipo ||
            (req?.tipoVeiculo?.trim().isNotEmpty ?? false) ||
            ((req?.quantidadeVeiculos ?? 0) > 0);
    final precisaOperador =
        (req?.exigeOperador ?? false) ||
            exigeEquipePorTipo ||
            ((req?.quantidadeOperadores ?? 0) > 0);

    final frotasAlocadas = <String>{};
    final frotasNomes = <String>[];
    final executoresAlocados = <String>{};

    for (final t in tasksApoioValidas) {
      frotasAlocadas.addAll(t.frotaIds);
      if (t.frota.trim().isNotEmpty) {
        frotasNomes.add(t.frota.trim());
      }
      executoresAlocados.addAll(t.executorIds);
      for (final ex in t.executores) {
        if (ex.trim().isNotEmpty) executoresAlocados.add(ex.trim());
      }
    }

    if (precisaVeiculo) {
      final qtdMin = req?.quantidadeVeiculos ?? 1;
      final totalFrota =
          frotasAlocadas.isNotEmpty ? frotasAlocadas.length : frotasNomes.length;
      if (totalFrota == 0) {
        pendencias.add('Veículo/frota ainda não alocado na atividade de apoio.');
      } else if (totalFrota < qtdMin) {
        pendencias.add(
          'Quantidade de veículos alocada ($totalFrota) inferior à solicitada ($qtdMin).',
        );
      } else if (req?.tipoVeiculo != null &&
          req!.tipoVeiculo!.trim().isNotEmpty &&
          frotasNomes.isNotEmpty) {
        final esperado = req.tipoVeiculo!.trim().toLowerCase();
        final algumCompativel =
            frotasNomes.any((n) => n.toLowerCase().contains(esperado));
        if (!algumCompativel) {
          incompatibilidade = true;
          pendencias.add(
            'Veículo alocado (${frotasNomes.join(', ')}) diverge do tipo solicitado (${req.tipoVeiculo}).',
          );
        }
      }
    }

    if (precisaOperador) {
      final qtdMinOp = req?.quantidadeOperadores ?? 1;
      if (executoresAlocados.isEmpty) {
        pendencias.add('Operador/executor ainda não alocado na atividade de apoio.');
      } else if (executoresAlocados.length < qtdMinOp) {
        pendencias.add(
          'Quantidade de operadores (${executoresAlocados.length}) inferior à solicitada ($qtdMinOp).',
        );
      }
    }

    if (incompatibilidade) {
      return _AvaliacaoRecursosResult(
        status: TaskApoioStatusCompatibilidadeRecurso.incompativel,
        pendencias: pendencias,
      );
    }
    if (pendencias.isNotEmpty) {
      return _AvaliacaoRecursosResult(
        status: TaskApoioStatusCompatibilidadeRecurso.pendente,
        pendencias: pendencias,
      );
    }

    return const _AvaliacaoRecursosResult(
      status: TaskApoioStatusCompatibilidadeRecurso.compativel,
      pendencias: [],
    );
  }

  List<String> _avaliarCompartilhamento({
    required List<TaskApoioVinculoComTask> vinculosAtuais,
    required List<TaskApoioVinculoComTask> outrosVinculos,
  }) {
    if (outrosVinculos.isEmpty) return const [];

    final alertas = <String>[];
    for (final atual in vinculosAtuais) {
      final tAtual = atual.taskApoio;
      if (tAtual == null || _isTaskCancelada(tAtual)) continue;

      final frotaUnica = tAtual.frotaIds.length <= 1;
      final locaisAtuais = tAtual.locais.map((l) => l.trim().toLowerCase()).toSet();

      for (final outro in outrosVinculos) {
        if (!outro.vinculo.ativo || outro.vinculo.id == atual.vinculo.id) {
          continue;
        }
        final tOutro = outro.taskApoio;
        if (tOutro == null || _isTaskCancelada(tOutro)) continue;
        if (tOutro.id != tAtual.id) continue;

        final janAIni = atual.vinculo.coberturaInicio ?? tAtual.dataInicio;
        final janAFim = atual.vinculo.coberturaFim ?? tAtual.dataFim;
        final janBIni = outro.vinculo.coberturaInicio ?? tOutro.dataInicio;
        final janBFim = outro.vinculo.coberturaFim ?? tOutro.dataFim;

        final sobrepoe = janAIni.isBefore(janBFim) && janBIni.isBefore(janAFim);
        if (!sobrepoe) {
          // Atendimento sucessivo é legítimo
          continue;
        }

        final locaisOutros =
            tOutro.locais.map((l) => l.trim().toLowerCase()).toSet();
        final mesmoLocal =
            locaisAtuais.isNotEmpty &&
            locaisOutros.isNotEmpty &&
            locaisAtuais.intersection(locaisOutros).isNotEmpty;

        if (frotaUnica && !mesmoLocal) {
          alertas.add(
            'Recurso único (${tAtual.tarefa}) compartilhado simultaneamente com "${outro.vinculo.taskPrincipalTituloSnapshot}" — validar disponibilidade.',
          );
        }
      }
    }
    return alertas;
  }

  TaskApoioSituacaoOperacional _determinarSituacaoOperacional({
    required TaskApoioSolicitacao solicitacao,
    required List<Task> tasksValidas,
    required TaskApoioCompatibilidade compat,
  }) {
    switch (solicitacao.status) {
      case TaskApoioStatus.recusada:
        return TaskApoioSituacaoOperacional.recusada;
      case TaskApoioStatus.cancelada:
        return TaskApoioSituacaoOperacional.cancelada;
      case TaskApoioStatus.pendente:
      case TaskApoioStatus.emAnalise:
        return TaskApoioSituacaoOperacional.aguardandoAnalise;
      case TaskApoioStatus.contraproposta:
        return TaskApoioSituacaoOperacional.emNegociacao;
      case TaskApoioStatus.aceita:
      case TaskApoioStatus.desconhecido:
        break;
    }

    if (tasksValidas.isEmpty) {
      return TaskApoioSituacaoOperacional.aceitaSemProgramacao;
    }

    final todasConcluidas =
        tasksValidas.every((t) => t.status.trim().toUpperCase() == 'CONC');
    if (todasConcluidas &&
        compat.statusTemporal ==
            TaskApoioStatusCompatibilidadeTemporal.integral) {
      return TaskApoioSituacaoOperacional.concluida;
    }

    final algumaEmAndamento =
        tasksValidas.any((t) => t.status.trim().toUpperCase() == 'ANDA');
    if (algumaEmAndamento) {
      return TaskApoioSituacaoOperacional.emAndamento;
    }

    if (compat.statusTemporal ==
        TaskApoioStatusCompatibilidadeTemporal.semCobertura) {
      return TaskApoioSituacaoOperacional.programadaComIncompatibilidade;
    }

    if (compat.statusTemporal ==
        TaskApoioStatusCompatibilidadeTemporal.parcial) {
      return TaskApoioSituacaoOperacional.parcialmenteProgramada;
    }

    if (compat.statusRecursos ==
            TaskApoioStatusCompatibilidadeRecurso.incompativel ||
        compat.statusRecursos ==
            TaskApoioStatusCompatibilidadeRecurso.conflitoCompartilhamento) {
      return TaskApoioSituacaoOperacional.programadaComIncompatibilidade;
    }

    if (compat.statusRecursos ==
        TaskApoioStatusCompatibilidadeRecurso.pendente) {
      return TaskApoioSituacaoOperacional.programadaComRecursosPendentes;
    }

    if (compat.statusRecursos ==
        TaskApoioStatusCompatibilidadeRecurso.naoVerificado) {
      return TaskApoioSituacaoOperacional.programadaComRecursosNaoVerificados;
    }

    return TaskApoioSituacaoOperacional.programadaCompativel;
  }

  bool _isTaskCancelada(Task task) {
    final s = task.status.trim().toUpperCase();
    return s == 'CANC' || s == 'CANCELADA' || s == 'RPGR';
  }

  bool _verificarPrevioOuPosterior({
    required List<TaskApoioIntervalo> necessidades,
    required Task? taskPrincipal,
  }) {
    if (taskPrincipal == null || necessidades.isEmpty) return false;
    final pIni = taskPrincipal.dataInicio.toUtc();
    final pFim = taskPrincipal.dataFim.toUtc();
    return necessidades.any(
      (n) => n.inicio.isBefore(pIni) || n.fim.isAfter(pFim),
    );
  }

  String _montarResumoExplicativo({
    required TaskApoioStatusCompatibilidadeTemporal statusTemporal,
    required double percentual,
    required List<TaskApoioIntervalo> lacunas,
    required TaskApoioStatusCompatibilidadeRecurso statusRecursos,
    required List<String> pendenciasRecursos,
    required List<String> alertasCompartilhamento,
  }) {
    final partes = <String>[
      '${statusTemporal.label} (${percentual.toStringAsFixed(0)}%)',
    ];
    if (lacunas.isNotEmpty) {
      partes.add('${lacunas.length} lacuna(s) de atendimento');
    }
    partes.add(statusRecursos.label);
    if (pendenciasRecursos.isNotEmpty) {
      partes.add(pendenciasRecursos.first);
    }
    if (alertasCompartilhamento.isNotEmpty) {
      partes.add(alertasCompartilhamento.first);
    }
    return partes.join(' • ');
  }
}

class _AvaliacaoRecursosResult {
  final TaskApoioStatusCompatibilidadeRecurso status;
  final List<String> pendencias;

  const _AvaliacaoRecursosResult({
    required this.status,
    required this.pendencias,
  });
}

