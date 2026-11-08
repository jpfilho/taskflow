import 'dart:math';
import '../models/capacidade_operacional_models.dart';
import '../models/executor.dart';
import '../models/equipe.dart';
import '../models/task.dart';
import '../models/feriado.dart';
import '../models/backlog_macro_models.dart';
import 'feriado_service.dart';
import 'executor_service.dart';
import 'equipe_service.dart';
import 'task_service.dart';
import 'carteira_service.dart';

/// Serviço responsável pelo cálculo e balanceamento da Capacidade Operacional,
/// apuração de horas de esforço por executor, dedução de indisponibilidades
/// e avaliação do grau de confiabilidade da demanda da carteira.
class CapacidadeService {
  static final CapacidadeService _instance = CapacidadeService._internal();
  factory CapacidadeService() => _instance;
  CapacidadeService._internal();

  FeriadoService? _feriadoService;
  ExecutorService? _executorService;
  EquipeService? _equipeService;
  TaskService? _taskService;
  CarteiraService? _carteiraService;

  CapacidadeService.comServicos({
    FeriadoService? feriadoService,
    ExecutorService? executorService,
    EquipeService? equipeService,
    TaskService? taskService,
    CarteiraService? carteiraService,
  })  : _feriadoService = feriadoService,
        _executorService = executorService,
        _equipeService = equipeService,
        _taskService = taskService,
        _carteiraService = carteiraService;

  FeriadoService get feriadoService => _feriadoService ??= FeriadoService();
  ExecutorService get executorService => _executorService ??= ExecutorService();
  EquipeService get equipeService => _equipeService ??= EquipeService();
  TaskService get taskService => _taskService ??= TaskService();
  CarteiraService get carteiraService => _carteiraService ??= CarteiraService();

  // ===========================================================================
  // 1. CALENDÁRIO ÚTIL E FERIADOS (INCREMENTO 1)
  // ===========================================================================

  /// Apura os dias úteis de um mês específico, descontando finais de semana e feriados.
  CalendarioMesInfo calcularCalendarioMes({
    required int ano,
    required int mes,
    List<Feriado> feriadosCadastrados = const [],
  }) {
    final ultimoDia = DateTime(ano, mes + 1, 0);
    final totalDias = ultimoDia.day;

    int finaisDeSemana = 0;
    int feriadosUteis = 0;
    final List<String> feriadosNomes = [];

    // Mapear feriados do mês no formato YYYY-MM-DD
    final Set<String> datasFeriados = {};
    final Map<String, String> nomesFeriadosPorData = {};
    for (final f in feriadosCadastrados) {
      if (f.data.year == ano && f.data.month == mes) {
        final dStr = '${f.data.year}-${f.data.month.toString().padLeft(2, "0")}-${f.data.day.toString().padLeft(2, "0")}';
        datasFeriados.add(dStr);
        nomesFeriadosPorData[dStr] = f.descricao;
      }
    }

    for (int d = 1; d <= totalDias; d++) {
      final dataAtual = DateTime(ano, mes, d);
      final isFimDeSemana = dataAtual.weekday == DateTime.saturday || dataAtual.weekday == DateTime.sunday;

      if (isFimDeSemana) {
        finaisDeSemana++;
      } else {
        final dStr = '$ano-${mes.toString().padLeft(2, "0")}-${d.toString().padLeft(2, "0")}';
        if (datasFeriados.contains(dStr)) {
          feriadosUteis++;
          final nome = nomesFeriadosPorData[dStr] ?? 'Feriado';
          if (!feriadosNomes.contains(nome)) {
            feriadosNomes.add(nome);
          }
        }
      }
    }

    final diasUteis = max(0, totalDias - finaisDeSemana - feriadosUteis);

    return CalendarioMesInfo(
      ano: ano,
      mes: mes,
      diasNoMes: totalDias,
      diasFimDeSemana: finaisDeSemana,
      feriadosEmDiasUteis: feriadosUteis,
      diasUteis: diasUteis,
      feriadosNomes: feriadosNomes,
    );
  }

  // ===========================================================================
  // 2. CAPACIDADE BRUTA E AJUSTADA DOS EXECUTORES (INCREMENTO 1)
  // ===========================================================================

  /// Calcula a capacidade detalhada de uma lista de executores para um determinado mês.
  List<CapacidadeExecutorMes> calcularCapacidadeExecutoresMes({
    required int ano,
    required int mes,
    required List<Executor> executores,
    required List<Equipe> equipes,
    required List<Task> tarefasDoPeriodo,
    required CalendarioMesInfo calendario,
    ConfiguracaoCapacidade config = const ConfiguracaoCapacidade(),
  }) {
    // 1. Mapear equipe de cada executor (respeitando filtros organizacionais se informados)
    final Map<String, Equipe> equipePorExecutorId = {};
    for (final eq in equipes) {
      if (config.apenasEquipesAtivas && !eq.ativo) continue;
      if (config.regionalId != null && config.regionalId!.isNotEmpty && eq.regionalId != config.regionalId) {
        continue;
      }
      if (config.divisaoId != null && config.divisaoId!.isNotEmpty && eq.divisaoId != config.divisaoId) {
        continue;
      }
      if (config.segmentoId != null && config.segmentoId!.isNotEmpty && eq.segmentoId != config.segmentoId) {
        continue;
      }
      for (final execVinc in eq.executores) {
        equipePorExecutorId[execVinc.executorId] = eq;
      }
    }

    // 2. Mapear indisponibilidades (férias, folgas, compensações) por executor no mês
    final Map<String, double> horasIndisponiveisPorExecutor = {};
    final tiposIndisponibilidade = {'FERIAS', 'FOLGA', 'COMP', 'ADMIN', 'TREINAMENTO', 'AFASTAMENTO'};

    for (final task in tarefasDoPeriodo) {
      final tipoUpper = task.tipo.trim().toUpperCase();
      if (!tiposIndisponibilidade.contains(tipoUpper) && !tipoUpper.contains('FERIAS') && !tipoUpper.contains('FOLGA')) {
        continue; // Não é ausência
      }
      if (task.status.toUpperCase() == 'CANC') continue;

      // Calcular horas de ausência incidentes no mês analisado
      final horasAusenciaNoMes = _calcularHorasInterseccaoMes(
        inicio: task.dataInicio,
        fim: task.dataFim,
        ano: ano,
        mes: mes,
        jornadaDiaria: config.jornadaDiariaHoras,
      );

      if (horasAusenciaNoMes <= 0) continue;

      for (final execId in task.executorIds) {
        horasIndisponiveisPorExecutor[execId] = (horasIndisponiveisPorExecutor[execId] ?? 0.0) + horasAusenciaNoMes;
      }
    }

    // 3. Mapear horas comprometidas com tarefas operacionais ativas (Incremento 2)
    final Map<String, double> horasComprometidasPorExecutor = _calcularHorasComprometidasPorExecutor(
      ano: ano,
      mes: mes,
      tarefasDoPeriodo: tarefasDoPeriodo,
      tiposExcluidos: tiposIndisponibilidade,
      config: config,
    );

    // 4. Montar a capacidade de cada executor
    final List<CapacidadeExecutorMes> resultados = [];

    for (final exec in executores) {
      if (!exec.ativo) continue;

      final equipe = equipePorExecutorId[exec.id];
      // Se a configuração pede apenas técnicos alocados em equipes formais:
      if (!config.incluirExecutoresSemEquipe && equipe == null) {
        continue;
      }

      final divIdEfetiva = equipe?.divisaoId ?? exec.divisaoId;
      final regIdEfetiva = equipe?.regionalId;
      final segIdEfetiva = equipe?.segmentoId ??
          (exec.segmentoIds.isNotEmpty ? exec.segmentoIds.first : null);

      if (config.regionalId != null &&
          config.regionalId!.isNotEmpty &&
          regIdEfetiva != config.regionalId) {
        continue;
      }
      if (config.divisaoId != null &&
          config.divisaoId!.isNotEmpty &&
          divIdEfetiva != config.divisaoId) {
        continue;
      }
      if (config.segmentoId != null && config.segmentoId!.isNotEmpty) {
        final matchSeg = segIdEfetiva == config.segmentoId ||
            exec.segmentoIds.contains(config.segmentoId);
        if (!matchSeg) continue;
      }

      final horasBrutas = calendario.diasUteis * config.jornadaDiariaHoras;
      final horasIndisp = horasIndisponiveisPorExecutor[exec.id] ?? 0.0;
      // Capacidade ajustada = (Horas Brutas * Fator Eficiência) - Horas Indisponíveis
      final horasAjustadas = max(0.0, (horasBrutas * config.fatorEficiencia) - horasIndisp);
      final horasComprom = horasComprometidasPorExecutor[exec.id] ?? 0.0;
      final saldo = horasAjustadas - horasComprom;

      resultados.add(CapacidadeExecutorMes(
        executorId: exec.id,
        executorNome: exec.nome,
        matricula: exec.matricula,
        funcao: exec.funcao,
        equipeId: equipe?.id,
        equipeNome: equipe?.nome,
        divisaoId: divIdEfetiva,
        regionalId: regIdEfetiva,
        segmentoId: segIdEfetiva,
        segmentoIds: exec.segmentoIds,
        ano: ano,
        mes: mes,
        diasUteis: calendario.diasUteis,
        jornadaDiaria: config.jornadaDiariaHoras,
        horasBrutas: horasBrutas,
        horasIndisponiveis: horasIndisp,
        fatorEficiencia: config.fatorEficiencia,
        horasAjustadas: horasAjustadas,
        horasComprometidas: horasComprom,
        saldoHoras: saldo,
      ));
    }

    return resultados;
  }

  // ===========================================================================
  // 3. HORAS COMPROMETIDAS POR EXECUTOR SEM DUPLICIDADES (INCREMENTO 2)
  // ===========================================================================

  /// Calcula as horas de esforço operacional de cada executor no mês,
  /// respeitando períodos individuais e prevenindo dupla contagem.
  Map<String, double> _calcularHorasComprometidasPorExecutor({
    required int ano,
    required int mes,
    required List<Task> tarefasDoPeriodo,
    required Set<String> tiposExcluidos,
    required ConfiguracaoCapacidade config,
  }) {
    final Map<String, double> esforcoPorExecutor = {};

    for (final task in tarefasDoPeriodo) {
      final tipoUpper = task.tipo.trim().toUpperCase();
      if (tiposExcluidos.contains(tipoUpper) || tipoUpper.contains('FERIAS') || tipoUpper.contains('FOLGA')) {
        continue; // Já contabilizado como indisponibilidade
      }
      if (task.status.toUpperCase() == 'CANC') continue;

      // Se a tarefa possuir períodos específicos por executor (ExecutorPeriod)
      if (task.executorPeriods.isNotEmpty) {
        for (final ep in task.executorPeriods) {
          double horasExecNoMes = 0;
          for (final seg in ep.periods) {
            horasExecNoMes += _calcularHorasInterseccaoMes(
              inicio: seg.dataInicio,
              fim: seg.dataFim,
              ano: ano,
              mes: mes,
              jornadaDiaria: config.jornadaDiariaHoras,
            );
          }
          if (horasExecNoMes > 0) {
            esforcoPorExecutor[ep.executorId] = (esforcoPorExecutor[ep.executorId] ?? 0.0) + horasExecNoMes;
          }
        }
      } else {
        // Tarefa com lista geral de executores
        final horasNoMes = _calcularHorasInterseccaoMes(
          inicio: task.dataInicio,
          fim: task.dataFim,
          ano: ano,
          mes: mes,
          jornadaDiaria: config.jornadaDiariaHoras,
        );

        if (horasNoMes > 0 && task.executorIds.isNotEmpty) {
          for (final execId in task.executorIds) {
            esforcoPorExecutor[execId] = (esforcoPorExecutor[execId] ?? 0.0) + horasNoMes;
          }
        }
      }
    }

    return esforcoPorExecutor;
  }

  /// Calcula as horas úteis de intersecção entre o intervalo de uma atividade e um determinado mês.
  double _calcularHorasInterseccaoMes({
    required DateTime inicio,
    required DateTime fim,
    required int ano,
    required int mes,
    required double jornadaDiaria,
  }) {
    final inicioMes = DateTime(ano, mes, 1);
    final fimMes = DateTime(ano, mes + 1, 0, 23, 59, 59);

    if (fim.isBefore(inicioMes) || inicio.isAfter(fimMes)) {
      return 0.0;
    }

    final dataInicioEfetiva = inicio.isBefore(inicioMes) ? inicioMes : inicio;
    final dataFimEfetiva = fim.isAfter(fimMes) ? fimMes : fim;

    if (dataFimEfetiva.isBefore(dataInicioEfetiva)) {
      return 0.0;
    }

    // Se a tarefa for de curta duração (menos de 24h dentro do mesmo dia):
    if (dataInicioEfetiva.year == dataFimEfetiva.year &&
        dataInicioEfetiva.month == dataFimEfetiva.month &&
        dataInicioEfetiva.day == dataFimEfetiva.day) {
      final diffMin = dataFimEfetiva.difference(dataInicioEfetiva).inMinutes;
      final horas = diffMin / 60.0;
      return min(horas, jornadaDiaria);
    }

    // Se cobrir múltiplos dias: conta os dias úteis de intersecção * jornada diária
    int diasUteisInterseccao = 0;
    var d = DateTime(dataInicioEfetiva.year, dataInicioEfetiva.month, dataInicioEfetiva.day);
    final limite = DateTime(dataFimEfetiva.year, dataFimEfetiva.month, dataFimEfetiva.day);

    while (!d.isAfter(limite)) {
      if (d.weekday != DateTime.saturday && d.weekday != DateTime.sunday) {
        diasUteisInterseccao++;
      }
      d = d.add(const Duration(days: 1));
    }

    return diasUteisInterseccao * jornadaDiaria;
  }

  // ===========================================================================
  // 4. CONSOLIDAÇÃO DA DEMANDA DA CARTEIRA E CONFIABILIDADE (INCREMENTO 3)
  // ===========================================================================

  // ===========================================================================
  // 4. CONSOLIDAÇÃO DA DEMANDA DA CARTEIRA E CONFIABILIDADE (INCREMENTO 3 E 4)
  // ===========================================================================

  /// Consolida a demanda prevista para um determinado mês,
  /// segregando notas com estimativa técnica confirmada de notas sem dimensionamento,
  /// diferenciando 0,0h confirmado vs zero padrão, e evitando dupla contagem com tarefas já programadas.
  DemandaCarteiraMes consolidarDemandaCarteiraMes({
    required int ano,
    required int mes,
    required List<BacklogNotaItem> notasPrevistasNoMes,
    Set<String> notasComTarefaProgramadaIds = const {},
    ConfiguracaoCapacidade config = const ConfiguracaoCapacidade(),
  }) {
    int totalNotas = notasPrevistasNoMes.length;
    int confirmadasMaiorZero = 0;
    int zeroConfirmado = 0;
    int zeroPadrao = 0;
    int semAnalise = 0;
    int jaProgramadas = 0;

    double horasEstimadasTotal = 0.0;
    double horasEstimadasNaoProgramadas = 0.0;
    final List<ItemEstimativaNota> itens = [];

    for (final nota in notasPrevistasNoMes) {
      final jaProgramada = notasComTarefaProgramadaIds.contains(nota.notaSapId) ||
          notasComTarefaProgramadaIds.contains(nota.numeroNota);

      if (jaProgramada) {
        jaProgramadas++;
      }

      final estHoras = nota.estimativaHoras;
      final OrigemEstimativaNota origem;

      if (estHoras != null && estHoras > 0) {
        origem = OrigemEstimativaNota.confirmadaMaiorZero;
        confirmadasMaiorZero++;
        horasEstimadasTotal += estHoras;
        if (!jaProgramada) {
          horasEstimadasNaoProgramadas += estHoras;
        }
      } else if (estHoras != null && estHoras == 0.0) {
        // Investigação da origem do valor 0.0:
        // Se a análise tiver status concluída e diagnóstico preenchido, é um zero confirmado (ex: sem campo).
        final status = (nota.statusAnalise ?? '').trim().toLowerCase();
        final diag = (nota.diagnosticoPrevio ?? '').trim();
        if (status == 'concluida' && diag.isNotEmpty) {
          origem = OrigemEstimativaNota.zeroConfirmado;
          zeroConfirmado++;
        } else {
          // Zero default/padrão de sistema sem dimensionamento real
          origem = OrigemEstimativaNota.zeroPadrao;
          zeroPadrao++;
        }
      } else {
        origem = OrigemEstimativaNota.ausente;
        semAnalise++;
      }

      itens.add(
        ItemEstimativaNota(
          notaSapId: nota.notaSapId,
          numeroNota: nota.numeroNota,
          descricao: nota.descricao,
          horasEstimadas: estHoras ?? 0.0,
          origem: origem,
          jaPossuiTarefaProgramada: jaProgramada,
        ),
      );
    }

    final totalValidas = confirmadasMaiorZero + zeroConfirmado;
    final totalSemEstimativa = zeroPadrao + semAnalise;
    final cobertura = totalNotas > 0 ? (totalValidas / totalNotas) * 100.0 : 100.0;
    final horasBenchmark = totalNotas * config.horasPadraoBenchmarkPorNota;

    return DemandaCarteiraMes(
      ano: ano,
      mes: mes,
      totalNotasPrevistas: totalNotas,
      notasComEstimativa: totalValidas,
      notasZeroConfirmado: zeroConfirmado,
      notasZeroPadrao: zeroPadrao,
      notasSemEstimativa: totalSemEstimativa,
      notasJaProgramadas: jaProgramadas,
      horasEstimadasConfirmadas: horasEstimadasTotal,
      horasEstimadasNaoProgramadas: horasEstimadasNaoProgramadas,
      percentualCoberturaEstimativa: cobertura,
      horasBenchmarkHistorico: horasBenchmark,
      itens: itens,
    );
  }

  // ===========================================================================
  // 5. BALANCEAMENTO MENSAL COMPLETO E MEMÓRIA DE CÁLCULO (INCREMENTO 4)
  // ===========================================================================

  /// Gera o balanço mensal consolidando Capacidade vs Programação vs Demanda Prevista,
  /// com memória de cálculo auditável e controle estrito de confiabilidade.
  BalanceamentoCapacidadeMes calcularBalanceamentoMensal({
    required int ano,
    required int mes,
    required List<CapacidadeExecutorMes> capacidadesExecutores,
    required DemandaCarteiraMes demanda,
    required CalendarioMesInfo calendario,
    ConfiguracaoCapacidade config = const ConfiguracaoCapacidade(),
  }) {
    double totalBrutas = 0.0;
    double totalIndisp = 0.0;
    double totalAjustadas = 0.0;
    double totalComprometidas = 0.0;

    int emEquipes = 0;
    int semEquipe = 0;

    for (final c in capacidadesExecutores) {
      totalBrutas += c.horasBrutas;
      totalIndisp += c.horasIndisponiveis;
      totalAjustadas += c.horasAjustadas;
      totalComprometidas += c.horasComprometidas;

      if (c.temEquipeVinculada) {
        emEquipes++;
      } else {
        semEquipe++;
      }
    }

    final capacidadeDisponivel = max(0.0, totalAjustadas - totalComprometidas);

    // Evita dupla contagem: deduz apenas as horas estimadas de notas que ainda NÃO possuem tarefa programada ativa
    final saldoHoras = capacidadeDisponivel - demanda.horasEstimadasNaoProgramadas;
    final taxaComprometimento = totalAjustadas > 0
        ? ((totalComprometidas + demanda.horasEstimadasNaoProgramadas) / totalAjustadas) * 100.0
        : 0.0;

    // Determinar Status de Balanceamento
    final StatusBalanceamentoMensal status;
    if (saldoHoras < 0 || taxaComprometimento > 100.0) {
      status = StatusBalanceamentoMensal.sobrecarga;
    } else if (taxaComprometimento >= 85.0) {
      status = StatusBalanceamentoMensal.cargaElevada;
    } else if (taxaComprometimento >= 50.0) {
      status = StatusBalanceamentoMensal.equilibrado;
    } else {
      status = StatusBalanceamentoMensal.ocioso;
    }

    // Avaliação Rigorosa de Confiabilidade (Regra Mandatória)
    final NivelConfiabilidadeCapacidade nivelConfiabilidade;
    final bool isSaldoConfiavel;
    final String motivoConfiabilidade;
    final limiteMinimoPct = config.limiteConfiabilidadeMinimo > 1.0
        ? config.limiteConfiabilidadeMinimo
        : (config.limiteConfiabilidadeMinimo * 100.0);

    if (demanda.totalNotasPrevistas == 0) {
      nivelConfiabilidade = NivelConfiabilidadeCapacidade.alta;
      isSaldoConfiavel = true;
      motivoConfiabilidade = 'Sem demandas previstas para este mês.';
    } else if (demanda.percentualCoberturaEstimativa >= limiteMinimoPct) {
      nivelConfiabilidade = NivelConfiabilidadeCapacidade.alta;
      isSaldoConfiavel = true;
      motivoConfiabilidade = 'Alta cobertura de estimativas (${demanda.percentualCoberturaEstimativa.toStringAsFixed(1)}% >= ${limiteMinimoPct.toStringAsFixed(0)}%).';
    } else if (demanda.percentualCoberturaEstimativa >= (limiteMinimoPct / 2)) {
      nivelConfiabilidade = NivelConfiabilidadeCapacidade.media;
      isSaldoConfiavel = saldoHoras < 0; // Sobrecarga já confirmada é conclusiva
      motivoConfiabilidade = 'Atenção: ${demanda.notasSemEstimativa} notas da carteira não possuem estimativa técnica informada. Saldo positivo inconclusivo.';
    } else {
      nivelConfiabilidade = NivelConfiabilidadeCapacidade.baixa;
      isSaldoConfiavel = false;
      motivoConfiabilidade = 'Incerteza Crítica: apenas ${demanda.percentualCoberturaEstimativa.toStringAsFixed(1)}% das notas possuem estimativa. Saldo positivo NÃO representa folga operacional comprovada.';
    }

    // Memória de Cálculo Auditável
    final memoria = MemoriaCalculoBalanceamento(
      passo1Calendario: 'Mês $mes/$ano: ${calendario.diasNoMes} dias corridos - ${calendario.diasFimDeSemana} dias de fins de semana - ${calendario.feriadosEmDiasUteis} feriados úteis = ${calendario.diasUteis} dias úteis.',
      passo2CapacidadeBruta: '${capacidadesExecutores.length} executores elegíveis × ${calendario.diasUteis} dias úteis × ${config.jornadaDiariaHoras.toStringAsFixed(1)}h/dia = ${totalBrutas.toStringAsFixed(1)}h brutas.',
      passo3Indisponibilidades: 'Total de ${totalIndisp.toStringAsFixed(1)}h em férias, folgas e afastamentos deduzidas da capacidade bruta.',
      passo4CapacidadeAjustada: '(${totalBrutas.toStringAsFixed(1)}h brutas - ${totalIndisp.toStringAsFixed(1)}h indisponíveis) × ${(config.fatorEficiencia * 100).toStringAsFixed(0)}% eficiência = ${totalAjustadas.toStringAsFixed(1)}h ajustadas.',
      passo5HorasComprometidas: '${totalComprometidas.toStringAsFixed(1)}h de esforço homem-hora alocadas em tarefas operacionais ativas (Capacidade disponível: ${capacidadeDisponivel.toStringAsFixed(1)}h).',
      passo6DemandaEstimada: 'Carteira de ${demanda.totalNotasPrevistas} notas: ${demanda.horasEstimadasConfirmadas.toStringAsFixed(1)}h estimadas (${demanda.notasJaProgramadas} já programadas em tarefas). Horas líquidas pendentes: ${demanda.horasEstimadasNaoProgramadas.toStringAsFixed(1)}h. Notas sem estimativa: ${demanda.notasSemEstimativa} (${demanda.percentualCoberturaEstimativa.toStringAsFixed(1)}% cobertura).',
      passo7SaldoEConfiabilidade: 'Saldo = ${capacidadeDisponivel.toStringAsFixed(1)}h - ${demanda.horasEstimadasNaoProgramadas.toStringAsFixed(1)}h = ${saldoHoras.toStringAsFixed(1)}h. Confiabilidade: ${nivelConfiabilidade.name.toUpperCase()} (${isSaldoConfiavel ? "Saldo Confiável" : "Saldo NÃO Confiável"}). Motivo: $motivoConfiabilidade',
    );

    return BalanceamentoCapacidadeMes(
      ano: ano,
      mes: mes,
      calendario: calendario,
      totalExecutores: capacidadesExecutores.length,
      totalExecutoresEmEquipes: emEquipes,
      totalExecutoresSemEquipe: semEquipe,
      horasBrutas: totalBrutas,
      horasIndisponiveis: totalIndisp,
      horasAjustadas: totalAjustadas,
      horasComprometidasProgramadas: totalComprometidas,
      capacidadeDisponivel: capacidadeDisponivel,
      demanda: demanda,
      saldoHorasCalculado: saldoHoras,
      taxaComprometimentoTotal: taxaComprometimento,
      status: status,
      nivelConfiabilidade: nivelConfiabilidade,
      isSaldoConfiavel: isSaldoConfiavel,
      motivoConfiabilidade: motivoConfiabilidade,
      memoriaCalculo: memoria,
    );
  }

  // ===========================================================================
  // 6. CARREGAMENTO INTEGRADO DE HORIZONTE MENSAL
  // ===========================================================================

  /// Carrega o balanço de capacidade para uma faixa de meses (ex: próximos 6 a 12 meses).
  Future<List<BalanceamentoCapacidadeMes>> carregarHorizonteCapacidade({
    required int anoInicio,
    required int mesInicio,
    required int quantidadeMeses,
    String? regionalId,
    String? divisaoId,
    ConfiguracaoCapacidade config = const ConfiguracaoCapacidade(),
  }) async {
    // 1. Carregar feriados do período
    final dataInicio = DateTime(anoInicio, mesInicio, 1);
    final dataFim = DateTime(anoInicio, mesInicio + quantidadeMeses, 0);

    List<Feriado> feriados = [];
    try {
      feriados = await feriadoService.getFeriadosByDateRange(dataInicio, dataFim);
    } catch (_) {
      feriados = [];
    }

    // 2. Carregar executores e equipes
    final todosExecutores = await executorService.getAllExecutores();
    final todasEquipes = await equipeService.getAllEquipes();

    // Filtrar por regional/divisão se informado
    var executoresFiltrados = todosExecutores;
    var equipesFiltradas = todasEquipes;

    if (divisaoId != null && divisaoId.isNotEmpty) {
      executoresFiltrados = executoresFiltrados.where((e) => e.divisaoId == divisaoId).toList();
      equipesFiltradas = equipesFiltradas.where((eq) => eq.divisaoId == divisaoId).toList();
    } else if (regionalId != null && regionalId.isNotEmpty) {
      equipesFiltradas = equipesFiltradas.where((eq) => eq.regionalId == regionalId).toList();
      executoresFiltrados = executoresFiltrados.where((e) {
        return equipesFiltradas.any((eq) => eq.executores.any((ex) => ex.executorId == e.id));
      }).toList();
    }

    // 3. Carregar tarefas do período para computar esforço operacional e indisponibilidades
    List<Task> tarefas = [];
    try {
      tarefas = await taskService.getTasksForRange(
        startDate: dataInicio,
        endDate: dataFim,
        aplicarPerfil: false,
      );
    } catch (_) {
      tarefas = [];
    }

    // 4. Carregar carteira de notas SAP para obter demandas previstas
    CarteiraResult? carteira;
    try {
      carteira = await carteiraService.carregarCarteira();
    } catch (_) {
      carteira = null;
    }

    // Identificar notas que já possuem tarefas associadas no período para evitar dupla contagem
    final Set<String> notasComTarefa = {};
    if (carteira != null) {
      for (final g in carteira.backlogMacro.todosGrupos) {
        for (final n in g.notas) {
          if (n.isProgramada || n.tasksValidas.isNotEmpty) {
            notasComTarefa.add(n.id);
            notasComTarefa.add(n.nota);
          }
        }
      }
    }

    // Agrupar notas da carteira por chave "ano_mes"
    final Map<String, List<BacklogNotaItem>> notasPorMesAno = {};
    if (carteira != null) {
      for (final grupo in carteira.backlogMacro.todosGrupos) {
        if (grupo.temPrevisao) {
          final chave = '${grupo.anoProgramacaoPrevisto}_${grupo.mesProgramacaoPrevisto}';
          notasPorMesAno.putIfAbsent(chave, () => []).addAll(grupo.notas);
        }
      }
    }

    // 5. Iterar sobre cada mês do horizonte
    final List<BalanceamentoCapacidadeMes> balancoHorizonte = [];

    for (int i = 0; i < quantidadeMeses; i++) {
      final mesCorrenteData = DateTime(anoInicio, mesInicio + i, 1);
      final anoCur = mesCorrenteData.year;
      final mesCur = mesCorrenteData.month;

      final calendario = calcularCalendarioMes(
        ano: anoCur,
        mes: mesCur,
        feriadosCadastrados: feriados,
      );

      final capacidadesExec = calcularCapacidadeExecutoresMes(
        ano: anoCur,
        mes: mesCur,
        executores: executoresFiltrados,
        equipes: equipesFiltradas,
        tarefasDoPeriodo: tarefas,
        calendario: calendario,
        config: config,
      );

      final chave = '${anoCur}_$mesCur';
      final notasDoMes = notasPorMesAno[chave] ?? const [];

      final demandaMes = consolidarDemandaCarteiraMes(
        ano: anoCur,
        mes: mesCur,
        notasPrevistasNoMes: notasDoMes,
        notasComTarefaProgramadaIds: notasComTarefa,
        config: config,
      );

      final balanceamento = calcularBalanceamentoMensal(
        ano: anoCur,
        mes: mesCur,
        capacidadesExecutores: capacidadesExec,
        demanda: demandaMes,
        calendario: calendario,
        config: config,
      );

      balancoHorizonte.add(balanceamento);
    }

    return balancoHorizonte;
  }

  // ===========================================================================
  // 7. PRIORIZAÇÃO EXPLICÁVEL DA CARTEIRA (INCREMENTO 6)
  // ===========================================================================

  /// Avalia a carteira de notas sob critérios objetivos e transparentes,
  /// gerando um score explicável (0 a 100) e os motivos que justificam a prioridade.
  /// NÃO altera previsões nem persiste dados (consultivo e não-destrutivo).
  List<ScorePrioridadeNota> calcularPriorizacaoNotas({
    required List<BacklogNotaItem> notas,
    ConfiguracaoPriorizacao config = const ConfiguracaoPriorizacao(),
    DateTime? dataReferencia,
  }) {
    final ref = dataReferencia ?? DateTime.now();
    final List<ScorePrioridadeNota> resultados = [];

    for (final nota in notas) {
      final fatores = <FatorPrioridadeNota>[];
      final motivos = <String>[];

      // Fator 1: Prazo SAP (Peso: 35%)
      double pontosPrazo = 0.0;
      String justPrazo;
      if (nota.dataFimDesejada != null) {
        final diffDias = nota.dataFimDesejada!.difference(ref).inDays;
        if (diffDias < 0) {
          pontosPrazo = config.pesoPrazoSap;
          justPrazo = 'Prazo SAP ultrapassado em ${diffDias.abs()} dias (+${pontosPrazo.toStringAsFixed(0)} pts)';
          motivos.add(justPrazo);
        } else if (diffDias <= 30) {
          pontosPrazo = config.pesoPrazoSap * 0.75;
          justPrazo = 'Vencimento iminente em $diffDias dias (+${pontosPrazo.toStringAsFixed(0)} pts)';
          motivos.add(justPrazo);
        } else if (diffDias <= 60) {
          pontosPrazo = config.pesoPrazoSap * 0.45;
          justPrazo = 'Vencimento no próximo bimestre em $diffDias dias (+${pontosPrazo.toStringAsFixed(0)} pts)';
          motivos.add(justPrazo);
        } else {
          pontosPrazo = config.pesoPrazoSap * 0.15;
          justPrazo = 'Prazo confortável ($diffDias dias restantes)';
        }
      } else {
        pontosPrazo = config.pesoPrazoSap * 0.20;
        justPrazo = 'Sem prazo limite definido no SAP';
      }
      fatores.add(FatorPrioridadeNota(
        nome: 'Prazo SAP',
        pontosObtidos: pontosPrazo,
        pesoMaximo: config.pesoPrazoSap,
        justificativa: justPrazo,
      ));

      // Fator 2: Criticidade / Prioridade SAP (Peso: 25%)
      double pontosCrit = 0.0;
      String justCrit;
      final prioridadeStr = (nota.prioridade ?? '').trim().toUpperCase();
      if (prioridadeStr.contains('MUITO ALTA') || prioridadeStr == '1') {
        pontosCrit = config.pesoCriticidade;
        justCrit = 'Prioridade máxima no cadastro SAP (+${pontosCrit.toStringAsFixed(0)} pts)';
        motivos.add(justCrit);
      } else if (prioridadeStr.contains('ALTA') || prioridadeStr == '2') {
        pontosCrit = config.pesoCriticidade * 0.75;
        justCrit = 'Prioridade alta no cadastro SAP (+${pontosCrit.toStringAsFixed(0)} pts)';
        motivos.add(justCrit);
      } else if (prioridadeStr.contains('MÉDIA') || prioridadeStr.contains('MEDIA') || prioridadeStr == '3') {
        pontosCrit = config.pesoCriticidade * 0.40;
        justCrit = 'Prioridade média';
      } else {
        pontosCrit = config.pesoCriticidade * 0.15;
        justCrit = 'Prioridade baixa ou normal';
      }
      fatores.add(FatorPrioridadeNota(
        nome: 'Criticidade SAP',
        pontosObtidos: pontosCrit,
        pesoMaximo: config.pesoCriticidade,
        justificativa: justCrit,
      ));

      // Fator 3: Risco Operacional / Segurança (Peso: 20%)
      double pontosRisco = 0.0;
      String justRisco;
      final descUpper = nota.descricao.toUpperCase();
      final hasSeguranca = descUpper.contains('SEGURANÇA') || descUpper.contains('RISCO') || descUpper.contains('URGENTE');
      final hasDesligamento = descUpper.contains('DESLIGAMENTO') || descUpper.contains('INTERVENÇÃO');

      if (hasSeguranca) {
        pontosRisco = config.pesoRiscoSeguranca;
        justRisco = 'Condição com impacto em segurança ou meio ambiente (+${pontosRisco.toStringAsFixed(0)} pts)';
        motivos.add(justRisco);
      } else if (hasDesligamento) {
        pontosRisco = config.pesoRiscoSeguranca * 0.60;
        justRisco = 'Requer desligamento ou programação especial (+${pontosRisco.toStringAsFixed(0)} pts)';
        motivos.add(justRisco);
      } else {
        pontosRisco = 0.0;
        justRisco = 'Sem risco operacional agravado registrado';
      }
      fatores.add(FatorPrioridadeNota(
        nome: 'Risco Operacional',
        pontosObtidos: pontosRisco,
        pesoMaximo: config.pesoRiscoSeguranca,
        justificativa: justRisco,
      ));

      // Fator 4: Idade da Nota na Carteira (Peso: 10%)
      double pontosIdade = 0.0;
      String justIdade;
      if (nota.dataCriacao != null) {
        final diasNaCarteira = ref.difference(nota.dataCriacao!).inDays;
        if (diasNaCarteira > 365) {
          pontosIdade = config.pesoIdadeNota;
          justIdade = 'Nota acumulada há mais de 1 ano ($diasNaCarteira dias) (+${pontosIdade.toStringAsFixed(0)} pts)';
          motivos.add(justIdade);
        } else if (diasNaCarteira > 180) {
          pontosIdade = config.pesoIdadeNota * 0.60;
          justIdade = 'Nota acumulada há mais de 6 meses ($diasNaCarteira dias)';
          motivos.add(justIdade);
        } else {
          pontosIdade = config.pesoIdadeNota * 0.20;
          justIdade = 'Demanda recente na carteira';
        }
      } else {
        pontosIdade = 0.0;
        justIdade = 'Data de criação não informada';
      }
      fatores.add(FatorPrioridadeNota(
        nome: 'Idade da Demanda',
        pontosObtidos: pontosIdade,
        pesoMaximo: config.pesoIdadeNota,
        justificativa: justIdade,
      ));

      // Fator 5: Oportunidade Logística e Agrupamento (Peso: 10%)
      // Não pode sobrepor prazos ou segurança crítica
      double pontosOportunidade = 0.0;
      String justOportunidade;
      if (nota.grupoId != null && nota.grupoId!.isNotEmpty) {
        pontosOportunidade = config.pesoOportunidadeLogistica;
        justOportunidade = 'Vinculada a grupo de atendimento conjunto (+${pontosOportunidade.toStringAsFixed(0)} pts)';
        motivos.add(justOportunidade);
      } else {
        pontosOportunidade = 0.0;
        justOportunidade = 'Nota avulsa sem agrupamento logístico';
      }
      fatores.add(FatorPrioridadeNota(
        nome: 'Oportunidade Logística',
        pontosObtidos: pontosOportunidade,
        pesoMaximo: config.pesoOportunidadeLogistica,
        justificativa: justOportunidade,
      ));

      // Score Total e Classificação
      final totalScore = min(100.0, pontosPrazo + pontosCrit + pontosRisco + pontosIdade + pontosOportunidade);
      final CategoriaPrioridadeNota categoria;
      if (totalScore >= CategoriaPrioridadeNota.critica.notaCorte) {
        categoria = CategoriaPrioridadeNota.critica;
      } else if (totalScore >= CategoriaPrioridadeNota.alta.notaCorte) {
        categoria = CategoriaPrioridadeNota.alta;
      } else if (totalScore >= CategoriaPrioridadeNota.media.notaCorte) {
        categoria = CategoriaPrioridadeNota.media;
      } else {
        categoria = CategoriaPrioridadeNota.baixa;
      }

      resultados.add(
        ScorePrioridadeNota(
          notaSapId: nota.notaSapId,
          numeroNota: nota.numeroNota,
          descricao: nota.descricao,
          scoreTotal: totalScore,
          categoria: categoria,
          fatores: fatores,
          motivosTexto: motivos,
        ),
      );
    }

    // Ordenar do maior score para o menor
    resultados.sort((a, b) => b.scoreTotal.compareTo(a.scoreTotal));
    return resultados;
  }

  // ===========================================================================
  // 8. SIMULAÇÃO NÃO-DESTRUTIVA EM MEMÓRIA (INCREMENTO 6)
  // ===========================================================================

  /// Executa simulações "what-if" totalmente isoladas em memória,
  /// permitindo testar redistribuição de demandas, variação de equipe ou ajuste de eficiência
  /// sem persistir nenhuma alteração no banco de dados.
  /// Executa simulações "what-if" totalmente isoladas em memória,
  /// permitindo testar redistribuição de demandas (notas e grupos inteiros),
  /// variação de equipe ou ajuste de eficiência sem persistir nenhuma alteração no banco de dados.
  BalanceamentoCapacidadeMes simularCenario({
    required BalanceamentoCapacidadeMes balancoBase,
    required CenarioSimulacao cenario,
    required List<CapacidadeExecutorMes> capacidadesExecutoresOriginais,
    List<BacklogNotaItem> todasNotasCarteira = const [],
    ConfiguracaoCapacidade config = const ConfiguracaoCapacidade(),
  }) {
    // 1. Clonar ou ajustar lista de capacidades com deltas simulados
    final fatorEficienciaSimulado = cenario.fatorEficienciaSimulado ?? config.fatorEficiencia;
    final List<CapacidadeExecutorMes> capacidadesSimuladas = [];

    for (final c in capacidadesExecutoresOriginais) {
      final horasAjustadasSimuladas = max(0.0, (c.horasBrutas - c.horasIndisponiveis) * fatorEficienciaSimulado);
      capacidadesSimuladas.add(
        CapacidadeExecutorMes(
          executorId: c.executorId,
          executorNome: c.executorNome,
          matricula: c.matricula,
          funcao: c.funcao,
          equipeId: c.equipeId,
          equipeNome: c.equipeNome,
          divisaoId: c.divisaoId,
          regionalId: c.regionalId,
          ano: c.ano,
          mes: c.mes,
          diasUteis: c.diasUteis,
          jornadaDiaria: c.jornadaDiaria,
          horasBrutas: c.horasBrutas,
          horasIndisponiveis: c.horasIndisponiveis,
          fatorEficiencia: fatorEficienciaSimulado,
          horasAjustadas: horasAjustadasSimuladas,
          horasComprometidas: c.horasComprometidas,
          saldoHoras: horasAjustadasSimuladas - c.horasComprometidas,
        ),
      );
    }

    // 2. Se houver acréscimo/decréscimo simulado de executores disponíveis
    if (cenario.ajusteExecutoresDisponiveis != 0) {
      final diasUteis = balancoBase.calendario.diasUteis;
      final horasBrutasUnitarias = diasUteis * config.jornadaDiariaHoras;
      final horasAjustadasUnitarias = horasBrutasUnitarias * fatorEficienciaSimulado;

      if (cenario.ajusteExecutoresDisponiveis > 0) {
        for (int i = 1; i <= cenario.ajusteExecutoresDisponiveis; i++) {
          capacidadesSimuladas.add(
            CapacidadeExecutorMes(
              executorId: 'simulado_$i',
              executorNome: 'Executor Simulado $i',
              ano: balancoBase.ano,
              mes: balancoBase.mes,
              diasUteis: diasUteis,
              jornadaDiaria: config.jornadaDiariaHoras,
              horasBrutas: horasBrutasUnitarias,
              horasIndisponiveis: 0.0,
              fatorEficiencia: fatorEficienciaSimulado,
              horasAjustadas: horasAjustadasUnitarias,
              horasComprometidas: 0.0,
              saldoHoras: horasAjustadasUnitarias,
            ),
          );
        }
      } else if (cenario.ajusteExecutoresDisponiveis < 0) {
        final removerQtd = min(capacidadesSimuladas.length, cenario.ajusteExecutoresDisponiveis.abs());
        capacidadesSimuladas.removeRange(capacidadesSimuladas.length - removerQtd, capacidadesSimuladas.length);
      }
    }

    // 3. Simular deltas na demanda prevista (Notas e Grupos)
    final anoAlvo = balancoBase.ano;
    final mesAlvo = balancoBase.mes;

    // A. Filtrar itens do mês base que foram transferidos para fora
    final List<ItemEstimativaNota> itensSimulados = [];
    final Set<String> idsProcessados = {};

    for (final item in balancoBase.demanda.itens) {
      ({int ano, int mes})? novaPrev;

      // Verificar se a nota individual foi movida
      if (cenario.mudancasPrevisaoNotas.containsKey(item.notaSapId)) {
        novaPrev = cenario.mudancasPrevisaoNotas[item.notaSapId];
      } else if (cenario.mudancasPrevisaoNotas.containsKey(item.numeroNota)) {
        novaPrev = cenario.mudancasPrevisaoNotas[item.numeroNota];
      }

      // Se a nota pertence a um grupo que foi movido
      final grupoIdNota = todasNotasCarteira.cast<BacklogNotaItem?>().firstWhere(
            (n) => n?.notaSapId == item.notaSapId || n?.numeroNota == item.numeroNota,
            orElse: () => null,
          )?.grupoId;

      if (novaPrev == null && grupoIdNota != null && cenario.mudancasPrevisaoGrupos.containsKey(grupoIdNota)) {
        novaPrev = cenario.mudancasPrevisaoGrupos[grupoIdNota];
      }

      if (novaPrev != null) {
        // Se a nova previsão for o mês alvo, mantém; se mudou para outro mês, sai do mês alvo
        if (novaPrev.ano == anoAlvo && novaPrev.mes == mesAlvo) {
          itensSimulados.add(item);
          idsProcessados.add(item.notaSapId);
        }
      } else {
        // Sem alteração, permanece no mês
        itensSimulados.add(item);
        idsProcessados.add(item.notaSapId);
      }
    }

    // B. Se houver lista de notas externas da carteira, verificar quais foram migradas PARA o mês alvo
    for (final notaExterna in todasNotasCarteira) {
      if (idsProcessados.contains(notaExterna.notaSapId)) continue;

      ({int ano, int mes})? novaPrev;
      if (cenario.mudancasPrevisaoNotas.containsKey(notaExterna.notaSapId)) {
        novaPrev = cenario.mudancasPrevisaoNotas[notaExterna.notaSapId];
      } else if (cenario.mudancasPrevisaoNotas.containsKey(notaExterna.numeroNota)) {
        novaPrev = cenario.mudancasPrevisaoNotas[notaExterna.numeroNota];
      } else if (notaExterna.grupoId != null && cenario.mudancasPrevisaoGrupos.containsKey(notaExterna.grupoId!)) {
        novaPrev = cenario.mudancasPrevisaoGrupos[notaExterna.grupoId!];
      }

      if (novaPrev != null && novaPrev.ano == anoAlvo && novaPrev.mes == mesAlvo) {
        final estHoras = notaExterna.estimativaHoras;
        final origem = estHoras == null
            ? OrigemEstimativaNota.ausente
            : estHoras > 0
                ? OrigemEstimativaNota.confirmadaMaiorZero
                : (notaExterna.statusAnalise == 'concluida' ||
                        (notaExterna.diagnosticoPrevio != null && notaExterna.diagnosticoPrevio!.isNotEmpty))
                    ? OrigemEstimativaNota.zeroConfirmado
                    : OrigemEstimativaNota.zeroPadrao;

        itensSimulados.add(
          ItemEstimativaNota(
            notaSapId: notaExterna.notaSapId,
            numeroNota: notaExterna.numeroNota,
            descricao: notaExterna.descricao,
            horasEstimadas: estHoras ?? 0.0,
            origem: origem,
            jaPossuiTarefaProgramada: notaExterna.isProgramada || notaExterna.tasksValidas.isNotEmpty,
          ),
        );
        idsProcessados.add(notaExterna.notaSapId);
      }
    }

    int confirmadas = 0;
    int semEst = 0;
    double horasEstimadas = 0.0;
    double horasEstimadasNaoProg = 0.0;

    for (final it in itensSimulados) {
      if (it.origem == OrigemEstimativaNota.confirmadaMaiorZero) {
        confirmadas++;
        horasEstimadas += it.horasEstimadas;
        if (!it.jaPossuiTarefaProgramada) {
          horasEstimadasNaoProg += it.horasEstimadas;
        }
      } else if (it.origem == OrigemEstimativaNota.zeroConfirmado) {
        confirmadas++;
      } else {
        semEst++;
      }
    }

    final totalNotasSimuladas = itensSimulados.length;
    final coberturaSimulada = totalNotasSimuladas > 0 ? (confirmadas / totalNotasSimuladas) * 100.0 : 100.0;

    final demandaSimulada = DemandaCarteiraMes(
      ano: anoAlvo,
      mes: mesAlvo,
      totalNotasPrevistas: totalNotasSimuladas,
      notasComEstimativa: confirmadas,
      notasSemEstimativa: semEst,
      horasEstimadasConfirmadas: horasEstimadas,
      horasEstimadasNaoProgramadas: horasEstimadasNaoProg,
      percentualCoberturaEstimativa: coberturaSimulada,
      horasBenchmarkHistorico: totalNotasSimuladas * config.horasPadraoBenchmarkPorNota,
      itens: itensSimulados,
    );

    return calcularBalanceamentoMensal(
      ano: anoAlvo,
      mes: mesAlvo,
      capacidadesExecutores: capacidadesSimuladas,
      demanda: demandaSimulada,
      calendario: balancoBase.calendario,
      config: config.copyWith(fatorEficiencia: fatorEficienciaSimulado),
    );
  }

  /// Gera um relatório comparativo detalhado (Antes vs Depois) da simulação,
  /// avaliando deltas de capacidade, demanda, saldo e impacto específico nos prazos SAP das notas.
  ComparativoCenarioSimulacao gerarComparativoSimulacao({
    required BalanceamentoCapacidadeMes balancoBase,
    required BalanceamentoCapacidadeMes balancoSimulado,
    required CenarioSimulacao cenario,
    required List<BacklogNotaItem> notasAvaliadas,
  }) {
    final List<ImpactoPrazoSimulacao> impactos = [];

    for (final nota in notasAvaliadas) {
      ({int ano, int mes})? prevSimulada;

      if (cenario.mudancasPrevisaoNotas.containsKey(nota.notaSapId)) {
        prevSimulada = cenario.mudancasPrevisaoNotas[nota.notaSapId];
      } else if (cenario.mudancasPrevisaoNotas.containsKey(nota.numeroNota)) {
        prevSimulada = cenario.mudancasPrevisaoNotas[nota.numeroNota];
      } else if (nota.grupoId != null && cenario.mudancasPrevisaoGrupos.containsKey(nota.grupoId!)) {
        prevSimulada = cenario.mudancasPrevisaoGrupos[nota.grupoId!];
      }

      if (prevSimulada != null) {
        final ({int ano, int mes}) prevOrig = (
          ano: balancoBase.ano,
          mes: balancoBase.mes,
        );

        final diferencaMeses = (prevSimulada.ano * 12 + prevSimulada.mes) - (prevOrig.ano * 12 + prevOrig.mes);

        // Avaliar prazo SAP
        final dataLimite = nota.dataFimDesejada;
        bool eraAtrasada = false;
        bool ficouAtrasada = false;

        if (dataLimite != null) {
          final pontosLimite = dataLimite.year * 12 + dataLimite.month;
          final pontosOrig = prevOrig.ano * 12 + prevOrig.mes;
          final pontosSim = prevSimulada.ano * 12 + prevSimulada.mes;

          eraAtrasada = pontosOrig > pontosLimite;
          ficouAtrasada = pontosSim > pontosLimite;
        }

        impactos.add(
          ImpactoPrazoSimulacao(
            notaSapId: nota.notaSapId,
            numeroNota: nota.numeroNota,
            descricao: nota.descricao,
            dataFimDesejada: dataLimite,
            previsaoOriginal: prevOrig,
            previsaoSimulada: prevSimulada,
            eraAtrasada: eraAtrasada,
            ficouAtrasada: ficouAtrasada,
            diferencaMeses: diferencaMeses,
          ),
        );
      }
    }

    return ComparativoCenarioSimulacao(
      balancoBase: balancoBase,
      balancoSimulado: balancoSimulado,
      impactosPrazos: impactos,
    );
  }
}


