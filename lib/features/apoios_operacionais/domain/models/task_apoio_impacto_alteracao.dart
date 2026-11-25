/// Evento de domínio gerado quando uma atividade vinculada sofre alteração relevante
/// (datas, segmentos Gantt, executores, frota, cancelamento ou exclusão).
enum TaskApoioTipoAlteracaoOrigem {
  alteracaoPeriodos,
  alteracaoExecutores,
  alteracaoFrota,
  reprogramacao,
  cancelamento,
  exclusao,
}

class TaskApoioImpactoAlteracao {
  final String taskAlteradaId;
  final TaskApoioTipoAlteracaoOrigem tipoAlteracao;
  final List<String> solicitacoesAfetadasIds;
  final List<String> vinculosAfetadosIds;
  final bool requerReconfirmacao;
  final bool quebrouCompatibilidade;
  final String descricaoImpacto;
  final DateTime detectadoEm;

  const TaskApoioImpactoAlteracao({
    required this.taskAlteradaId,
    required this.tipoAlteracao,
    this.solicitacoesAfetadasIds = const [],
    this.vinculosAfetadosIds = const [],
    this.requerReconfirmacao = false,
    this.quebrouCompatibilidade = false,
    required this.descricaoImpacto,
    required this.detectadoEm,
  });

  Map<String, dynamic> toJson() => {
        'task_alterada_id': taskAlteradaId,
        'tipo_alteracao': tipoAlteracao.name,
        'solicitacoes_afetadas_ids': solicitacoesAfetadasIds,
        'vinculos_afetados_ids': vinculosAfetadosIds,
        'requer_reconfirmacao': requerReconfirmacao,
        'quebrou_compatibilidade': quebrouCompatibilidade,
        'descricao_impacto': descricaoImpacto,
        'detectado_em': detectadoEm.toUtc().toIso8601String(),
      };
}

