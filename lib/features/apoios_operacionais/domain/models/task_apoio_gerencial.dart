import '../models/task_apoio_situacao.dart';
import '../models/task_apoio_solicitacao.dart';

enum TaskApoioGerencialPerspectiva {
  consolidada('Visão Consolidada'),
  solicitante('Unidade Solicitante'),
  prestadora('Unidade Prestadora');

  final String label;
  const TaskApoioGerencialPerspectiva(this.label);
}

class TaskApoioDistribuicaoItem {
  final String chaveId;
  final String nome;
  final int totalSolicitacoes;
  final int essenciais;
  final int pendentesOuRisco;
  final int programadosCompativeis;

  const TaskApoioDistribuicaoItem({
    required this.chaveId,
    required this.nome,
    required this.totalSolicitacoes,
    required this.essenciais,
    required this.pendentesOuRisco,
    required this.programadosCompativeis,
  });
}

class TaskApoioItemReuniaoSemanal {
  final TaskApoioSolicitacao solicitacao;
  final TaskApoioSituacao situacao;
  final String unidadeResponsavelId;
  final String unidadeResponsavelNome;
  final String providenciaSugerida;
  final int severidadeOrdem; // menor = mais crítico

  const TaskApoioItemReuniaoSemanal({
    required this.solicitacao,
    required this.situacao,
    required this.unidadeResponsavelId,
    required this.unidadeResponsavelNome,
    required this.providenciaSugerida,
    required this.severidadeOrdem,
  });
}

/// Indicadores gerenciais e de desempenho entre unidades (Fase 7).
/// Campos de taxa/tempo são anuláveis (`null`) quando não há base válida para
/// cálculo, devendo ser apresentados como `"Sem dados suficientes"`.
class TaskApoioGerencialIndicadores {
  // Contadores obrigatórios (unidade: solicitações / atividades conforme rótulo)
  final int totalSolicitacoes;
  final int solicitacoesRecebidas;
  final int solicitacoesEnviadas;
  final int aguardandoResposta;
  final int emNegociacao;
  final int aceitas;
  final int aceitasSemProgramacao;
  final int parcialmenteProgramados;
  final int programadosCompativeis;
  final int essenciaisEmRisco;
  final int recursosPendentes;
  final int recursosNaoVerificados;
  final int reconfirmacaoPendente;
  final int prazoUltrapassado;
  final int recusadas;
  final int canceladas;
  final int concluidos;
  final int atividadesPrincipaisAfetadas;

  // Desempenho entre unidades (null = sem dados suficientes)
  final double? tempoMedioPrimeiraRespostaHoras;
  final double? tempoMedioDecisaoDefinitivaHoras;
  final double? taxaRespostaNoPrazoPercent;
  final double? taxaAtendimentoNoPrazoPercent;
  final double? coberturaTemporalMediaPercent;
  final double? tempoMedioAceiteParaProgramacaoHoras;
  final int totalReprogramacoes;

  // Distribuições e visão de reunião semanal
  final List<TaskApoioDistribuicaoItem> distribuicaoPorUnidade;
  final List<TaskApoioDistribuicaoItem> distribuicaoPorTipo;
  final List<TaskApoioItemReuniaoSemanal> itensReuniaoSemanal;

  const TaskApoioGerencialIndicadores({
    this.totalSolicitacoes = 0,
    this.solicitacoesRecebidas = 0,
    this.solicitacoesEnviadas = 0,
    this.aguardandoResposta = 0,
    this.emNegociacao = 0,
    this.aceitas = 0,
    this.aceitasSemProgramacao = 0,
    this.parcialmenteProgramados = 0,
    this.programadosCompativeis = 0,
    this.essenciaisEmRisco = 0,
    this.recursosPendentes = 0,
    this.recursosNaoVerificados = 0,
    this.reconfirmacaoPendente = 0,
    this.prazoUltrapassado = 0,
    this.recusadas = 0,
    this.canceladas = 0,
    this.concluidos = 0,
    this.atividadesPrincipaisAfetadas = 0,
    this.tempoMedioPrimeiraRespostaHoras,
    this.tempoMedioDecisaoDefinitivaHoras,
    this.taxaRespostaNoPrazoPercent,
    this.taxaAtendimentoNoPrazoPercent,
    this.coberturaTemporalMediaPercent,
    this.tempoMedioAceiteParaProgramacaoHoras,
    this.totalReprogramacoes = 0,
    this.distribuicaoPorUnidade = const [],
    this.distribuicaoPorTipo = const [],
    this.itensReuniaoSemanal = const [],
  });
}

