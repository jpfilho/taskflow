import 'package:flutter/foundation.dart';
import 'nota_sap_analise.dart';
import 'nota_sap.dart';

/// DTO com indicadores agregados de um Centro de Trabalho
@immutable
class IndicadoresCentroTrabalho {
  final String centroTrabalho;
  final int totalNotas;
  final int comAnalise;
  final int concluidas;
  final int comMateriais;
  final int comAnexos;

  const IndicadoresCentroTrabalho({
    required this.centroTrabalho,
    required this.totalNotas,
    required this.comAnalise,
    required this.concluidas,
    this.comMateriais = 0,
    this.comAnexos = 0,
  });

  double get taxaCobertura =>
      totalNotas > 0 ? (comAnalise / totalNotas) * 100 : 0.0;
}

/// DTO com indicadores agregados por Mês
@immutable
class IndicadoresMes {
  final String mesAno; // 'YYYY-MM' ou 'MMM/YY'
  final int totalNotas;
  final int comAnalise;
  final int concluidas;

  const IndicadoresMes({
    required this.mesAno,
    required this.totalNotas,
    required this.comAnalise,
    required this.concluidas,
  });

  double get taxaCobertura =>
      totalNotas > 0 ? (comAnalise / totalNotas) * 100 : 0.0;
}

/// DTO com indicadores agregados de uma Regional
@immutable
class IndicadoresRegional {
  final String regional;
  final int totalNotas;
  final int comAnalise;
  final int concluidas;

  const IndicadoresRegional({
    required this.regional,
    required this.totalNotas,
    required this.comAnalise,
    required this.concluidas,
  });

  double get taxaCobertura =>
      totalNotas > 0 ? (comAnalise / totalNotas) * 100 : 0.0;
}

typedef CoberturaRegional = IndicadoresRegional;

/// Representa um vínculo entre Tarefa e Nota SAP para cálculo de métricas
class VinculoTaskNotaSap {
  final String taskId;
  final String notaSapId;
  final DateTime? taskCreatedAt;
  final DateTime? vinculoCreatedAt;

  const VinculoTaskNotaSap({
    required this.taskId,
    required this.notaSapId,
    this.taskCreatedAt,
    this.vinculoCreatedAt,
  });
}

/// Modelo Completo de Indicadores de Maturidade, Efetividade e Cobertura da Análise de Notas SAP
/// Exclusivamente informativo (Medir != Obrigar).
@immutable
class NotaSapIndicadores {
  // 1. Totais e Status
  final int totalNotas;
  final int notasSemAnalise;
  final int notasEmAnalise;
  final int notasConcluidas;
  final int notasAguardandoInfo;
  final int analisesCanceladas;

  // 2. Cobertura da Análise Técnica
  final double taxaCobertura; // Percentual 0 a 100

  // 3. Conteúdo Técnico Enriquecido
  final int notasComAnexos;
  final int notasComMateriais;
  final int notasComComentarios;
  final int notasComDiagnostico;
  final int notasComEscopo;
  final int notasComEstimativaHoras;
  final int notasComQtdTecnicos;
  final int notasComDesligamento;
  final int notasComLoto;

  // 4. Maturidade da Informação (Informativo, não-bloqueante)
  final int nivel0SomenteNota; // Sem análise técnica iniciada
  final int nivel1Iniciada; // Análise iniciada/aguardando, mas sem diagnóstico ou escopo
  final int nivel2DiagnosticoEscopo; // Com diagnóstico prévio ou escopo detalhado
  final int nivel3Completa; // Diagnóstico/escopo + materiais ou anexos levantados

  // 5. Uso na Programação (Cuidado N:M e validação temporal rigorosa)
  final int tarefasTotalVinculadas; // COUNT(DISTINCT task_id)
  final int tarefasComAnalisePrevia; // analise.createdAt <= task.createdAt
  final int tarefasComAnalisePosteriorOuAtual; // analise existente mas sem garantia temporal
  final int tarefasSemAnalise; // Tarefas com notas sem nenhuma análise
  final int notasProgramadasTotal; // COUNT(DISTINCT nota_sap_id em tasks_notas_sap)
  final int notasProgramadasComAnalise;
  final int notasProgramadasSemAnalise;

  // 6. Agrupamentos Gerenciais
  final Map<String, IndicadoresCentroTrabalho> porCentroTrabalho;
  final Map<String, IndicadoresMes> porMes;
  final Map<String, IndicadoresRegional> porRegional;

  const NotaSapIndicadores({
    required this.totalNotas,
    required this.notasSemAnalise,
    required this.notasEmAnalise,
    required this.notasConcluidas,
    required this.notasAguardandoInfo,
    required this.analisesCanceladas,
    required this.taxaCobertura,
    required this.notasComAnexos,
    required this.notasComMateriais,
    required this.notasComComentarios,
    required this.notasComDiagnostico,
    required this.notasComEscopo,
    required this.notasComEstimativaHoras,
    required this.notasComQtdTecnicos,
    required this.notasComDesligamento,
    required this.notasComLoto,
    required this.nivel0SomenteNota,
    required this.nivel1Iniciada,
    required this.nivel2DiagnosticoEscopo,
    required this.nivel3Completa,
    required this.tarefasTotalVinculadas,
    required this.tarefasComAnalisePrevia,
    required this.tarefasComAnalisePosteriorOuAtual,
    required this.tarefasSemAnalise,
    required this.notasProgramadasTotal,
    required this.notasProgramadasComAnalise,
    required this.notasProgramadasSemAnalise,
    this.porCentroTrabalho = const {},
    this.porMes = const {},
    this.porRegional = const {},
  });

  /// Distribuição consolidada por status para consumo de gráficos e cards
  Map<NotaAnaliseStatus, int> get distribuicaoPorStatus => {
    NotaAnaliseStatus.naoIniciada: notasSemAnalise,
    NotaAnaliseStatus.emAnalise: notasEmAnalise,
    NotaAnaliseStatus.concluida: notasConcluidas,
    NotaAnaliseStatus.aguardandoInformacao: notasAguardandoInfo,
    NotaAnaliseStatus.cancelada: analisesCanceladas,
  };

  // Percentuais de status
  double get percentualSemAnalise =>
      totalNotas > 0 ? (notasSemAnalise / totalNotas) * 100 : 0.0;
  double get percentualEmAnalise =>
      totalNotas > 0 ? (notasEmAnalise / totalNotas) * 100 : 0.0;
  double get percentualConcluidas =>
      totalNotas > 0 ? (notasConcluidas / totalNotas) * 100 : 0.0;
  double get percentualAguardandoInfo =>
      totalNotas > 0 ? (notasAguardandoInfo / totalNotas) * 100 : 0.0;
  double get percentualCanceladas =>
      totalNotas > 0 ? (analisesCanceladas / totalNotas) * 100 : 0.0;

  // Percentuais de conteúdo
  double get percentualComAnexos =>
      totalNotas > 0 ? (notasComAnexos / totalNotas) * 100 : 0.0;
  double get percentualComMateriais =>
      totalNotas > 0 ? (notasComMateriais / totalNotas) * 100 : 0.0;
  double get percentualComComentarios =>
      totalNotas > 0 ? (notasComComentarios / totalNotas) * 100 : 0.0;

  // Percentuais de programação
  double get percentualTarefasComAnalisePrevia => tarefasTotalVinculadas > 0
      ? (tarefasComAnalisePrevia / tarefasTotalVinculadas) * 100
      : 0.0;

  /// Construtor vazio / padrão
  factory NotaSapIndicadores.vazio() {
    return const NotaSapIndicadores(
      totalNotas: 0,
      notasSemAnalise: 0,
      notasEmAnalise: 0,
      notasConcluidas: 0,
      notasAguardandoInfo: 0,
      analisesCanceladas: 0,
      taxaCobertura: 0.0,
      notasComAnexos: 0,
      notasComMateriais: 0,
      notasComComentarios: 0,
      notasComDiagnostico: 0,
      notasComEscopo: 0,
      notasComEstimativaHoras: 0,
      notasComQtdTecnicos: 0,
      notasComDesligamento: 0,
      notasComLoto: 0,
      nivel0SomenteNota: 0,
      nivel1Iniciada: 0,
      nivel2DiagnosticoEscopo: 0,
      nivel3Completa: 0,
      tarefasTotalVinculadas: 0,
      tarefasComAnalisePrevia: 0,
      tarefasComAnalisePosteriorOuAtual: 0,
      tarefasSemAnalise: 0,
      notasProgramadasTotal: 0,
      notasProgramadasComAnalise: 0,
      notasProgramadasSemAnalise: 0,
    );
  }

  /// Calcula os indicadores a partir das notas e mapas de análise
  /// Tratamento anti-duplicidade em N:M garantido via conjuntos e contagens distintas.
  factory NotaSapIndicadores.calcular({
    required List<NotaSAP> notas,
    Map<String, NotaSapResumoAnalise> resumos = const {},
    Map<String, NotaSapAnalise> analisesDetalhadas = const {},
    List<VinculoTaskNotaSap> vinculosTarefas = const [],
    Set<String> notasProgramadasIds = const {},
  }) {
    final total = notas.length;
    if (total == 0) return NotaSapIndicadores.vazio();

    int semAnalise = 0;
    int emAnalise = 0;
    int concluidas = 0;
    int aguardandoInfo = 0;
    int canceladas = 0;

    int comAnexos = 0;
    int comMateriais = 0;
    int comComentarios = 0;
    int comDiagnostico = 0;
    int comEscopo = 0;
    int comEstimativaHoras = 0;
    int comQtdTecnicos = 0;
    int comDesligamento = 0;
    int comLoto = 0;

    int n0 = 0;
    int n1 = 0;
    int n2 = 0;
    int n3 = 0;

    final Map<String, int> ctTotal = {};
    final Map<String, int> ctComAnalise = {};
    final Map<String, int> ctConcluidas = {};
    final Map<String, int> ctMateriais = {};
    final Map<String, int> ctAnexos = {};

    final Map<String, int> mesTotal = {};
    final Map<String, int> mesComAnalise = {};
    final Map<String, int> mesConcluidas = {};

    final Map<String, int> regTotal = {};
    final Map<String, int> regComAnalise = {};
    final Map<String, int> regConcluidas = {};

    // Deduplicação de notas pelo ID para evitar qualquer repetição de lista
    final Set<String> notasProcessadas = {};

    for (final nota in notas) {
      if (notasProcessadas.contains(nota.id)) continue;
      notasProcessadas.add(nota.id);

      final resumo = resumos[nota.id];
      final detalhada = analisesDetalhadas[nota.id];
      final status = resumo?.status ??
          detalhada?.statusAnalise ??
          NotaAnaliseStatus.naoIniciada;

      final temAnalise = status != NotaAnaliseStatus.naoIniciada;

      // Status
      switch (status) {
        case NotaAnaliseStatus.naoIniciada:
          semAnalise++;
          break;
        case NotaAnaliseStatus.emAnalise:
          emAnalise++;
          break;
        case NotaAnaliseStatus.concluida:
          concluidas++;
          break;
        case NotaAnaliseStatus.aguardandoInformacao:
          aguardandoInfo++;
          break;
        case NotaAnaliseStatus.cancelada:
          canceladas++;
          break;
      }

      // Contadores de conteúdo
      final qtdAnexos = resumo?.quantidadeAnexos ?? 0;
      final qtdMateriais = resumo?.quantidadeMateriais ?? 0;
      final qtdComentarios = resumo?.quantidadeComentarios ?? 0;

      if (qtdAnexos > 0) comAnexos++;
      if (qtdMateriais > 0) comMateriais++;
      if (qtdComentarios > 0) comComentarios++;

      final temDiag = detalhada?.diagnosticoPrevio != null &&
          detalhada!.diagnosticoPrevio!.trim().isNotEmpty;
      final temEscopo = detalhada?.escopoDetalhado != null &&
          detalhada!.escopoDetalhado!.trim().isNotEmpty;

      if (temDiag) comDiagnostico++;
      if (temEscopo) comEscopo++;
      if (detalhada?.estimativaHoras != null && detalhada!.estimativaHoras! > 0) {
        comEstimativaHoras++;
      }
      if (detalhada?.quantidadeTecnicos != null &&
          detalhada!.quantidadeTecnicos! > 0) {
        comQtdTecnicos++;
      }
      if (detalhada?.necessitaDesligamento == true) {
        comDesligamento++;
      }
      if (detalhada?.necessitaBloqueio == true) {
        comLoto++;
      }

      // Maturidade da Informação
      if (!temAnalise) {
        n0++;
      } else {
        final temConteudoBase = temDiag || temEscopo;
        final temConteudoAvancado = qtdMateriais > 0 || qtdAnexos > 0;

        if (temConteudoBase && temConteudoAvancado) {
          n3++;
        } else if (temConteudoBase) {
          n2++;
        } else {
          n1++;
        }
      }

      // Agrupamento por Centro de Trabalho
      final ct = (nota.centroTrabalhoResponsavel?.trim().isNotEmpty == true)
          ? nota.centroTrabalhoResponsavel!.trim()
          : 'Não informado';
      ctTotal[ct] = (ctTotal[ct] ?? 0) + 1;
      if (temAnalise) {
        ctComAnalise[ct] = (ctComAnalise[ct] ?? 0) + 1;
      }
      if (status == NotaAnaliseStatus.concluida) {
        ctConcluidas[ct] = (ctConcluidas[ct] ?? 0) + 1;
      }
      if (qtdMateriais > 0) {
        ctMateriais[ct] = (ctMateriais[ct] ?? 0) + 1;
      }
      if (qtdAnexos > 0) {
        ctAnexos[ct] = (ctAnexos[ct] ?? 0) + 1;
      }

      // Agrupamento por Regional (centro ou local)
      final reg = (nota.centro?.trim().isNotEmpty == true)
          ? nota.centro!.trim()
          : (nota.local?.trim().isNotEmpty == true
              ? nota.local!.trim()
              : 'Sem regional');
      regTotal[reg] = (regTotal[reg] ?? 0) + 1;
      if (temAnalise) {
        regComAnalise[reg] = (regComAnalise[reg] ?? 0) + 1;
      }
      if (status == NotaAnaliseStatus.concluida) {
        regConcluidas[reg] = (regConcluidas[reg] ?? 0) + 1;
      }

      // Agrupamento por Mês (criacao da nota)
      final dtCriacao = nota.criadoEm;
      if (dtCriacao != null) {
        final mesAno =
            '${dtCriacao.year}-${dtCriacao.month.toString().padLeft(2, '0')}';
        mesTotal[mesAno] = (mesTotal[mesAno] ?? 0) + 1;
        if (temAnalise) {
          mesComAnalise[mesAno] = (mesComAnalise[mesAno] ?? 0) + 1;
        }
        if (status == NotaAnaliseStatus.concluida) {
          mesConcluidas[mesAno] = (mesConcluidas[mesAno] ?? 0) + 1;
        }
      }
    }

    // Cobertura geral
    final totalComAnalise = total - semAnalise;
    final taxaCobertura = total > 0 ? (totalComAnalise / total) * 100 : 0.0;

    // Métricas por Centro de Trabalho DTO
    final Map<String, IndicadoresCentroTrabalho> porCentroTrabalho = {};
    for (final entry in ctTotal.entries) {
      final ct = entry.key;
      porCentroTrabalho[ct] = IndicadoresCentroTrabalho(
        centroTrabalho: ct,
        totalNotas: entry.value,
        comAnalise: ctComAnalise[ct] ?? 0,
        concluidas: ctConcluidas[ct] ?? 0,
        comMateriais: ctMateriais[ct] ?? 0,
        comAnexos: ctAnexos[ct] ?? 0,
      );
    }

    // Métricas por Regional DTO
    final Map<String, IndicadoresRegional> porRegional = {};
    for (final entry in regTotal.entries) {
      final reg = entry.key;
      porRegional[reg] = IndicadoresRegional(
        regional: reg,
        totalNotas: entry.value,
        comAnalise: regComAnalise[reg] ?? 0,
        concluidas: regConcluidas[reg] ?? 0,
      );
    }

    // Métricas por Mês DTO
    final Map<String, IndicadoresMes> porMes = {};
    for (final entry in mesTotal.entries) {
      final mesAno = entry.key;
      porMes[mesAno] = IndicadoresMes(
        mesAno: mesAno,
        totalNotas: entry.value,
        comAnalise: mesComAnalise[mesAno] ?? 0,
        concluidas: mesConcluidas[mesAno] ?? 0,
      );
    }

    // -------------------------------------------------------------
    // CÁLCULO DE VÍNCULOS COM A PROGRAMAÇÃO (RELAÇÃO N:M E TEMPORAL)
    // -------------------------------------------------------------
    // Agrupar vínculos por tarefa para contar tarefas distintas
    final Map<String, List<VinculoTaskNotaSap>> vinculosPorTask = {};
    final Set<String> notasVinculadasSet = {};

    for (final v in vinculosTarefas) {
      vinculosPorTask.putIfAbsent(v.taskId, () => []).add(v);
      notasVinculadasSet.add(v.notaSapId);
    }

    int tarefasComPrevia = 0;
    int tarefasComPosterior = 0;
    int tarefasSem = 0;

    for (final entry in vinculosPorTask.entries) {
      final vinculosDaTask = entry.value;
      bool temAnalisePreviaParaEstaTask = false;
      bool temAnaliseAtualParaEstaTask = false;

      for (final v in vinculosDaTask) {
        final resumo = resumos[v.notaSapId];
        final detalhada = analisesDetalhadas[v.notaSapId];
        final status = resumo?.status ??
            detalhada?.statusAnalise ??
            NotaAnaliseStatus.naoIniciada;

        if (status != NotaAnaliseStatus.naoIniciada) {
          temAnaliseAtualParaEstaTask = true;

          // Verificação temporal estrita: analise.createdAt <= task.createdAt
          final analiseCreatedAt = detalhada?.createdAt;
          final taskCreatedAt = v.taskCreatedAt;

          if (analiseCreatedAt != null && taskCreatedAt != null) {
            if (analiseCreatedAt.isBefore(taskCreatedAt) ||
                analiseCreatedAt.isAtSameMomentAs(taskCreatedAt)) {
              temAnalisePreviaParaEstaTask = true;
            }
          }
        }
      }

      if (temAnalisePreviaParaEstaTask) {
        tarefasComPrevia++;
      } else if (temAnaliseAtualParaEstaTask) {
        tarefasComPosterior++;
      } else {
        tarefasSem++;
      }
    }

    // Contagem de notas programadas
    final todasNotasProgramadasIds = Set<String>.from(notasProgramadasIds)
      ..addAll(notasVinculadasSet);

    int notasProgComAnalise = 0;
    int notasProgSemAnalise = 0;

    for (final notaId in todasNotasProgramadasIds) {
      final resumo = resumos[notaId];
      final detalhada = analisesDetalhadas[notaId];
      final status = resumo?.status ??
          detalhada?.statusAnalise ??
          NotaAnaliseStatus.naoIniciada;

      if (status != NotaAnaliseStatus.naoIniciada) {
        notasProgComAnalise++;
      } else {
        notasProgSemAnalise++;
      }
    }

    return NotaSapIndicadores(
      totalNotas: total,
      notasSemAnalise: semAnalise,
      notasEmAnalise: emAnalise,
      notasConcluidas: concluidas,
      notasAguardandoInfo: aguardandoInfo,
      analisesCanceladas: canceladas,
      taxaCobertura: taxaCobertura,
      notasComAnexos: comAnexos,
      notasComMateriais: comMateriais,
      notasComComentarios: comComentarios,
      notasComDiagnostico: comDiagnostico,
      notasComEscopo: comEscopo,
      notasComEstimativaHoras: comEstimativaHoras,
      notasComQtdTecnicos: comQtdTecnicos,
      notasComDesligamento: comDesligamento,
      notasComLoto: comLoto,
      nivel0SomenteNota: n0,
      nivel1Iniciada: n1,
      nivel2DiagnosticoEscopo: n2,
      nivel3Completa: n3,
      tarefasTotalVinculadas: vinculosPorTask.keys.length,
      tarefasComAnalisePrevia: tarefasComPrevia,
      tarefasComAnalisePosteriorOuAtual: tarefasComPosterior,
      tarefasSemAnalise: tarefasSem,
      notasProgramadasTotal: todasNotasProgramadasIds.length,
      notasProgramadasComAnalise: notasProgComAnalise,
      notasProgramadasSemAnalise: notasProgSemAnalise,
      porCentroTrabalho: porCentroTrabalho,
      porMes: porMes,
      porRegional: porRegional,
    );
  }
}
