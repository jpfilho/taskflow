import 'nota_sap.dart';
import 'nota_sap_analise.dart';

/// Classificação da relação entre a Nota de referência e a ocorrência histórica.
enum TipoClassificacaoSimilaridade {
  /// Mesmo ativo ou local com a mesma natureza de defeito / falha.
  ocorrenciaSemelhante,

  /// Mesmo equipamento, porém intervenção tecnicamente distinta.
  historicoMesmoAtivo,
}

/// Faixas de similaridade do score determinístico (0 a 100 pontos).
enum FaixaSimilaridade {
  /// 80 a 100 pontos
  alta,

  /// 55 a 79 pontos
  media,

  /// 40 a 54 pontos
  fraca,

  /// Menos de 40 pontos (descartada da exibição padrão)
  descartada;

  static FaixaSimilaridade fromScore(double score) {
    if (score >= 80.0) return FaixaSimilaridade.alta;
    if (score >= 55.0) return FaixaSimilaridade.media;
    if (score >= 40.0) return FaixaSimilaridade.fraca;
    return FaixaSimilaridade.descartada;
  }

  String get label {
    switch (this) {
      case FaixaSimilaridade.alta:
        return 'Alta similaridade';
      case FaixaSimilaridade.media:
        return 'Similaridade média';
      case FaixaSimilaridade.fraca:
        return 'Relação contextual';
      case FaixaSimilaridade.descartada:
        return 'Descartada';
    }
  }
}

/// Detalhamento dos pontos que compõem o score determinístico.
class EvidenciaScore {
  final double pontosEquipamento;
  final double pontosLocalInstalacao;
  final double pontosDescricao;
  final double pontosCentroTrabalho;
  final double pontosTipo;
  final List<String> explicacoes;
  final List<String> tokensCoincidentes;

  const EvidenciaScore({
    this.pontosEquipamento = 0.0,
    this.pontosLocalInstalacao = 0.0,
    this.pontosDescricao = 0.0,
    this.pontosCentroTrabalho = 0.0,
    this.pontosTipo = 0.0,
    this.explicacoes = const [],
    this.tokensCoincidentes = const [],
  });

  double get scoreTotal => (pontosEquipamento +
          pontosLocalInstalacao +
          pontosDescricao +
          pontosCentroTrabalho +
          pontosTipo)
      .clamp(0.0, 100.0);
}

/// Resumo informativo de uma tarefa vinculada à Nota SAP similar.
class TarefaHistoricaResumo {
  final String id;
  final String? tarefaNome;
  final String status;
  final int totalExecutores;
  final List<String> executores;
  final double? horasExecutadas;
  final double? horasPrevistas;
  final DateTime? dataInicio;
  final DateTime? dataFim;

  const TarefaHistoricaResumo({
    required this.id,
    this.tarefaNome,
    this.status = '',
    this.totalExecutores = 0,
    this.executores = const [],
    this.horasExecutadas,
    this.horasPrevistas,
    this.dataInicio,
    this.dataFim,
  });
}

/// Representa uma Nota SAP candidata com pontuação e evidências de similaridade.
class NotaSapSimilar {
  final NotaSAP nota;
  final double scoreTotal;
  final TipoClassificacaoSimilaridade classificacao;
  final FaixaSimilaridade faixa;
  final EvidenciaScore evidencias;
  final List<TarefaHistoricaResumo> tarefasVinculadas;
  final double? horasSapConfirmadas;
  final NotaSapAnalise? analise;
  final List<NotaSapMaterial> materiaisLevantados;
  final int totalAnexos;

  const NotaSapSimilar({
    required this.nota,
    required this.scoreTotal,
    required this.classificacao,
    required this.faixa,
    required this.evidencias,
    this.tarefasVinculadas = const [],
    this.horasSapConfirmadas,
    this.analise,
    this.materiaisLevantados = const [],
    this.totalAnexos = 0,
  });

  /// Identifica se a ocorrência histórica possui análise técnica prévia.
  bool get temAnalise => analise != null;

  /// Identifica se possui diagnóstico registrado.
  bool get temDiagnostico =>
      analise?.diagnosticoPrevio != null &&
      analise!.diagnosticoPrevio!.trim().isNotEmpty;

  /// Identifica se possui fotos ou anexos anteriores.
  bool get temFotosAnexos => totalAnexos > 0;

  /// Identifica se a nota está aberta (em planejamento/análise/execução).
  bool get estaAberta {
    final s = (nota.statusSistema ?? '').toUpperCase();
    return (s.contains('MSPN') || s.contains('MSPR')) &&
        !s.contains('CONC') &&
        !s.contains('ENCE') &&
        !s.contains('CANC');
  }

  /// Identifica se a nota já foi concluída ou encerrada no SAP.
  bool get estaConcluida => !estaAberta;

  /// Data em que a nota foi concluída/encerrada no SAP.
  DateTime? get dataConclusao => nota.dataConclusao;
}

/// Estatísticas de tempo e equipe baseadas na mediana das ocorrências similares.
class EstatisticasTempoEquipe {
  final double? duracaoMedianaHoras;
  final double? duracaoMinimaHoras;
  final double? duracaoMaximaHoras;
  final int totalAmostrasHoras;
  final String fonteHoras;

  final int? equipeMedianaTecnicos;
  final int? equipeMinimaTecnicos;
  final int? equipeMaximaTecnicos;
  final int totalAmostrasEquipe;

  const EstatisticasTempoEquipe({
    this.duracaoMedianaHoras,
    this.duracaoMinimaHoras,
    this.duracaoMaximaHoras,
    this.totalAmostrasHoras = 0,
    this.fonteHoras = 'Nenhuma amostra',
    this.equipeMedianaTecnicos,
    this.equipeMinimaTecnicos,
    this.equipeMaximaTecnicos,
    this.totalAmostrasEquipe = 0,
  });

  bool get temDadosHoras => totalAmostrasHoras > 0 && duracaoMedianaHoras != null;
  bool get temDadosEquipe =>
      totalAmostrasEquipe > 0 && equipeMedianaTecnicos != null;
}

/// Material levantado em ocorrências semelhantes com contagem de frequência.
class MaterialFrequencia {
  final String? codigoSap;
  final String descricao;
  final int quantidadeOcorrencias;
  final int totalAnalisesAvaliadas;
  final String unidade;

  const MaterialFrequencia({
    this.codigoSap,
    required this.descricao,
    required this.quantidadeOcorrencias,
    required this.totalAnalisesAvaliadas,
    this.unidade = 'UN',
  });

  String get frequenciaTexto =>
      'Presente em $quantidadeOcorrencias de $totalAnalisesAvaliadas análises';
}

/// Demanda aberta (Nota SAP não concluída) candidata a agrupamento conjunto.
class DemandaAbertaRelacionada {
  final NotaSAP nota;
  final String motivo;
  final List<String> criteriosCoincidentes;

  const DemandaAbertaRelacionada({
    required this.nota,
    required this.motivo,
    this.criteriosCoincidentes = const [],
  });
}

/// Resultado consolidado da consulta e scoring de similaridade para uma Nota SAP.
class ResultadoSimilaridadeNotaSap {
  final NotaSAP notaReferencia;
  final List<NotaSapSimilar> ocorrenciasSemelhantes;
  final List<NotaSapSimilar> todasOcorrencias;
  final List<NotaSapSimilar> historicoMesmoAtivo;
  final EstatisticasTempoEquipe estatisticas;
  final List<MaterialFrequencia> materiaisFrequentes;
  final List<DemandaAbertaRelacionada> demandasAbertasRelacionadas;
  final DateTime calculadoEm;

  const ResultadoSimilaridadeNotaSap({
    required this.notaReferencia,
    this.ocorrenciasSemelhantes = const [],
    this.todasOcorrencias = const [],
    this.historicoMesmoAtivo = const [],
    this.estatisticas = const EstatisticasTempoEquipe(),
    this.materiaisFrequentes = const [],
    this.demandasAbertasRelacionadas = const [],
    required this.calculadoEm,
  });

  bool get temOcorrencias =>
      ocorrenciasSemelhantes.isNotEmpty ||
      todasOcorrencias.isNotEmpty ||
      historicoMesmoAtivo.isNotEmpty;

  bool get temDemandasAbertas =>
      demandasAbertasRelacionadas.isNotEmpty || outrasDemandasAbertas.isNotEmpty;

  bool get temDados =>
      temOcorrencias ||
      temDemandasAbertas ||
      ocorrenciasAbertas.isNotEmpty ||
      totalAbertas > 0;

  /// Ocorrências com similaridade determinística que estão atualmente abertas.
  List<NotaSapSimilar> get ocorrenciasAbertas =>
      ocorrenciasSemelhantes.where((o) => o.estaAberta).toList();

  /// Ocorrências históricas com similaridade determinística já concluídas.
  List<NotaSapSimilar> get ocorrenciasConcluidas =>
      ocorrenciasSemelhantes.where((o) => o.estaConcluida).toList();

  /// Ocorrências abertas de todas as ocorrências avaliadas
  List<NotaSapSimilar> get todasOcorrenciasAbertas =>
      todasOcorrencias.where((o) => o.estaAberta).toList();

  /// Ocorrências concluídas de todas as ocorrências avaliadas
  List<NotaSapSimilar> get todasOcorrenciasConcluidas =>
      todasOcorrencias.where((o) => o.estaConcluida).toList();

  /// Demandas abertas que ainda não estão listadas como ocorrências de similaridade técnica
  List<DemandaAbertaRelacionada> get outrasDemandasAbertas {
    final idsOcorrencias = {
      ...ocorrenciasAbertas.map((o) => o.nota.id),
      ...ocorrenciasAbertas.map((o) => o.nota.nota),
    };
    return demandasAbertasRelacionadas
        .where((d) => !idsOcorrencias.contains(d.nota.id) && !idsOcorrencias.contains(d.nota.nota))
        .toList();
  }

  /// Total de demandas e ocorrências em aberto (para foco operacional conjunto).
  int get totalAbertas =>
      outrasDemandasAbertas.length + ocorrenciasAbertas.length;

  /// Total de ocorrências já concluídas (histórico técnico de referência).
  int get totalConcluidas =>
      ocorrenciasConcluidas.length + historicoMesmoAtivo.length;
}
