import 'nota_sap.dart';
import 'nota_sap_analise.dart';
import 'nota_sap_similaridade.dart';

/// Classificação do Critério Físico de correspondência histórica.
enum NotaHistoricoCriterioFisico {
  /// Critério A: Mesmo equipamento na mesma instalação.
  mesmoEquipamento,

  /// Critério B: Mesma sala / estrutura / vão operativo na mesma instalação.
  mesmaEstrutura,

  /// Critério C: Mesmo local amplo / instalação física (contexto amplo).
  mesmoLocal,

  /// Apenas relação semântica / similaridade técnica (Critério D).
  apenasSimilaridade,
}

/// Item de Histórico Técnico de Notas SAP Anteriores.
///
/// Modela a ocorrência histórica unindo a dimensão física (equipamento, estrutura, local)
/// e a dimensão semântica (similaridade técnica de falha).
class NotaHistoricoTecnicoItem {
  final NotaSAP notaSap;
  final NotaHistoricoCriterioFisico criterioFisicoPrincipal;
  final List<String> motivosFisicos;

  // Dimensão Semântica (Critério D)
  final bool ehSimilar;
  final double? scoreSimilaridade;
  final List<String> tokensCoincidentes;

  // Inventário de Metadados em Lote (Carga Inicial sem N+1)
  final int totalAnexos;
  final bool temAnalise;
  final int totalTasks;

  // Detalhes Completos Carregados Sob Demanda (Lazy Loading)
  final bool detalhesCarregados;
  final List<NotaSapAnexo> anexos;
  final NotaSapAnalise? analise;
  final List<TarefaHistoricaResumo> tasks;

  const NotaHistoricoTecnicoItem({
    required this.notaSap,
    required this.criterioFisicoPrincipal,
    this.motivosFisicos = const [],
    this.ehSimilar = false,
    this.scoreSimilaridade,
    this.tokensCoincidentes = const [],
    this.totalAnexos = 0,
    this.temAnalise = false,
    this.totalTasks = 0,
    this.detalhesCarregados = false,
    this.anexos = const [],
    this.analise,
    this.tasks = const [],
  });

  bool get temRelacaoFisica =>
      criterioFisicoPrincipal != NotaHistoricoCriterioFisico.apenasSimilaridade;

  bool get ehMesmoEquipamento =>
      criterioFisicoPrincipal == NotaHistoricoCriterioFisico.mesmoEquipamento;

  bool get ehMesmaEstrutura =>
      criterioFisicoPrincipal == NotaHistoricoCriterioFisico.mesmaEstrutura;

  bool get ehMesmoLocal =>
      criterioFisicoPrincipal == NotaHistoricoCriterioFisico.mesmoLocal;

  bool get estaAberta {
    final status = (notaSap.statusSistema ?? '').toUpperCase();
    return (status.contains('MSPN') || status.contains('MSPR')) &&
        !status.contains('CONC') &&
        !status.contains('ENCE') &&
        !status.contains('CANC');
  }

  String get dataFormatada {
    final dt = notaSap.criadoEm ?? notaSap.data;
    if (dt == null) return '';
    final dia = dt.day.toString().padLeft(2, '0');
    final mes = dt.month.toString().padLeft(2, '0');
    final ano = dt.year.toString();
    return '$dia/$mes/$ano';
  }

  /// Retorna cópia com os dados detalhados lazy carregados.
  NotaHistoricoTecnicoItem copyWithDetalhes({
    required List<NotaSapAnexo> anexos,
    NotaSapAnalise? analise,
    required List<TarefaHistoricaResumo> tasks,
  }) {
    return NotaHistoricoTecnicoItem(
      notaSap: notaSap,
      criterioFisicoPrincipal: criterioFisicoPrincipal,
      motivosFisicos: motivosFisicos,
      ehSimilar: ehSimilar,
      scoreSimilaridade: scoreSimilaridade,
      tokensCoincidentes: tokensCoincidentes,
      totalAnexos: anexos.isNotEmpty ? anexos.length : totalAnexos,
      temAnalise: analise != null || temAnalise,
      totalTasks: tasks.isNotEmpty ? tasks.length : totalTasks,
      detalhesCarregados: true,
      anexos: anexos,
      analise: analise ?? this.analise,
      tasks: tasks,
    );
  }

  /// Retorna cópia com atualização dos dados de similaridade determinística.
  NotaHistoricoTecnicoItem copyWithSimilaridade({
    required bool ehSimilar,
    required double? scoreSimilaridade,
    required List<String> tokensCoincidentes,
  }) {
    return NotaHistoricoTecnicoItem(
      notaSap: notaSap,
      criterioFisicoPrincipal: criterioFisicoPrincipal,
      motivosFisicos: motivosFisicos,
      ehSimilar: ehSimilar,
      scoreSimilaridade: scoreSimilaridade,
      tokensCoincidentes: tokensCoincidentes,
      totalAnexos: totalAnexos,
      temAnalise: temAnalise,
      totalTasks: totalTasks,
      detalhesCarregados: detalhesCarregados,
      anexos: anexos,
      analise: analise,
      tasks: tasks,
    );
  }
}

/// Resultado consolidado do Histórico Técnico de Notas SAP Anteriores.
class NotaHistoricoTecnicoResultado {
  final NotaSAP notaReferencia;
  final List<NotaHistoricoTecnicoItem> itensEquipamento;
  final List<NotaHistoricoTecnicoItem> itensEstrutura;
  final List<NotaHistoricoTecnicoItem> itensLocal;
  final List<NotaHistoricoTecnicoItem> itensApenasSimilaridade;
  final List<NotaHistoricoTecnicoItem> todosItensDeduplicados;
  final DateTime calculadoEm;

  // Estados de Carregamento Progressivo (Não bloqueantes)
  final bool carregandoSimilares;
  final bool carregandoLocalAmplo;
  final int? timeToUsefulHistoryMs;

  const NotaHistoricoTecnicoResultado({
    required this.notaReferencia,
    this.itensEquipamento = const [],
    this.itensEstrutura = const [],
    this.itensLocal = const [],
    this.itensApenasSimilaridade = const [],
    this.todosItensDeduplicados = const [],
    required this.calculadoEm,
    this.carregandoSimilares = false,
    this.carregandoLocalAmplo = false,
    this.timeToUsefulHistoryMs,
  });

  bool get estaVazio => todosItensDeduplicados.isEmpty;
  int get totalItens => todosItensDeduplicados.length;
  int get totalEquipamento => itensEquipamento.length;
  int get totalEstrutura => itensEstrutura.length;
  int get totalLocal => itensLocal.length;
  int get totalApenasSimilaridade => itensApenasSimilaridade.length;

  bool get possuiHistoricoAtivo =>
      itensEquipamento.isNotEmpty || itensEstrutura.isNotEmpty || itensLocal.isNotEmpty;

  NotaHistoricoTecnicoResultado copyWith({
    NotaSAP? notaReferencia,
    List<NotaHistoricoTecnicoItem>? itensEquipamento,
    List<NotaHistoricoTecnicoItem>? itensEstrutura,
    List<NotaHistoricoTecnicoItem>? itensLocal,
    List<NotaHistoricoTecnicoItem>? itensApenasSimilaridade,
    List<NotaHistoricoTecnicoItem>? todosItensDeduplicados,
    DateTime? calculadoEm,
    bool? carregandoSimilares,
    bool? carregandoLocalAmplo,
    int? timeToUsefulHistoryMs,
  }) {
    return NotaHistoricoTecnicoResultado(
      notaReferencia: notaReferencia ?? this.notaReferencia,
      itensEquipamento: itensEquipamento ?? this.itensEquipamento,
      itensEstrutura: itensEstrutura ?? this.itensEstrutura,
      itensLocal: itensLocal ?? this.itensLocal,
      itensApenasSimilaridade:
          itensApenasSimilaridade ?? this.itensApenasSimilaridade,
      todosItensDeduplicados:
          todosItensDeduplicados ?? this.todosItensDeduplicados,
      calculadoEm: calculadoEm ?? this.calculadoEm,
      carregandoSimilares: carregandoSimilares ?? this.carregandoSimilares,
      carregandoLocalAmplo:
          carregandoLocalAmplo ?? this.carregandoLocalAmplo,
      timeToUsefulHistoryMs:
          timeToUsefulHistoryMs ?? this.timeToUsefulHistoryMs,
    );
  }
}
