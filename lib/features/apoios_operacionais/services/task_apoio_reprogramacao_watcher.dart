import '../../../models/task.dart';
import '../domain/enums/task_apoio_enums.dart';
import '../domain/models/task_apoio_impacto_alteracao.dart';
import '../domain/repositories/task_apoio_repository.dart';
import 'task_apoio_service.dart';

/// Mecanismo centralizado para detectar impactos de reprogramações, alterações
/// de Gantt, executores, frota, cancelamento ou exclusão sobre apoios vinculados.
/// Não realiza reprogramações automáticas em atividades de outras unidades.
class TaskApoioReprogramacaoWatcher {
  final ITaskApoioRepository _repository;
  final TaskApoioService _service;

  TaskApoioReprogramacaoWatcher({
    required ITaskApoioRepository repository,
    TaskApoioService? service,
  })  : _repository = repository,
        _service = service ?? TaskApoioService(repository: repository);

  /// Avalia se uma alteração em [taskDepois] (comparada a [taskAntes]) impacta
  /// solicitações ou vínculos existentes.
  Future<TaskApoioImpactoAlteracao?> avaliarImpactoAlteracao({
    required Task taskAntes,
    required Task taskDepois,
    Map<String, Task> tasksPorId = const {},
  }) async {
    final tipo = _detectarTipoAlteracao(taskAntes, taskDepois);
    if (tipo == null) return null;

    final vinculos = await _repository.buscarVinculosPorTask(taskDepois.id);
    final solicitacoesDaTask =
        await _repository.buscarSolicitacoesPorTask(taskDepois.id);

    final solIds = <String>{
      ...solicitacoesDaTask.where((s) => s.status.isAtiva).map((s) => s.id),
      ...vinculos.map((v) => v.solicitacaoId).whereType<String>(),
    };

    if (vinculos.isEmpty && solIds.isEmpty) {
      return null;
    }

    final mapaAtualizado = Map<String, Task>.from(tasksPorId)
      ..[taskDepois.id] = taskDepois;

    bool quebrouCompat = false;
    for (final solId in solIds) {
      final sol = await _repository.buscarSolicitacaoPorId(solId);
      if (sol == null || !sol.status.isAtiva) continue;

      final sit = await _service.avaliarSituacaoSolicitacao(
        solicitacao: sol,
        tasksPorId: mapaAtualizado,
      );
      if (sit.situacaoOperacional ==
              TaskApoioSituacaoOperacional.parcialmenteProgramada ||
          sit.situacaoOperacional ==
              TaskApoioSituacaoOperacional.programadaComIncompatibilidade ||
          sit.situacaoOperacional ==
              TaskApoioSituacaoOperacional.programadaComRecursosPendentes) {
        quebrouCompat = true;
      }
    }

    final requerReconfirmacao = quebrouCompat ||
        tipo == TaskApoioTipoAlteracaoOrigem.cancelamento ||
        tipo == TaskApoioTipoAlteracaoOrigem.reprogramacao ||
        tipo == TaskApoioTipoAlteracaoOrigem.alteracaoPeriodos;

    return TaskApoioImpactoAlteracao(
      taskAlteradaId: taskDepois.id,
      tipoAlteracao: tipo,
      solicitacoesAfetadasIds: solIds.toList(),
      vinculosAfetadosIds: vinculos.map((v) => v.id).toList(),
      requerReconfirmacao: requerReconfirmacao,
      quebrouCompatibilidade: quebrouCompat,
      descricaoImpacto: _descreverImpacto(tipo, solIds.length, quebrouCompat),
      detectadoEm: DateTime.now().toUtc(),
    );
  }

  TaskApoioTipoAlteracaoOrigem? _detectarTipoAlteracao(
    Task antes,
    Task depois,
  ) {
    final sAntes = antes.status.trim().toUpperCase();
    final sDepois = depois.status.trim().toUpperCase();
    if (sAntes != sDepois && (sDepois == 'CANC' || sDepois == 'RPGR')) {
      return TaskApoioTipoAlteracaoOrigem.cancelamento;
    }
    if (antes.dataInicio.toUtc() != depois.dataInicio.toUtc() ||
        antes.dataFim.toUtc() != depois.dataFim.toUtc()) {
      return TaskApoioTipoAlteracaoOrigem.reprogramacao;
    }
    if (antes.ganttSegments.length != depois.ganttSegments.length ||
        antes.frotaPeriods.length != depois.frotaPeriods.length ||
        antes.executorPeriods.length != depois.executorPeriods.length) {
      return TaskApoioTipoAlteracaoOrigem.alteracaoPeriodos;
    }
    if (antes.frotaIds.join(',') != depois.frotaIds.join(',')) {
      return TaskApoioTipoAlteracaoOrigem.alteracaoFrota;
    }
    if (antes.executorIds.join(',') != depois.executorIds.join(',')) {
      return TaskApoioTipoAlteracaoOrigem.alteracaoExecutores;
    }
    return null;
  }

  String _descreverImpacto(
    TaskApoioTipoAlteracaoOrigem tipo,
    int qtdSols,
    bool quebrou,
  ) {
    final base = switch (tipo) {
      TaskApoioTipoAlteracaoOrigem.cancelamento =>
        'Atividade vinculada cancelada/reprogramada',
      TaskApoioTipoAlteracaoOrigem.exclusao => 'Atividade vinculada excluída',
      TaskApoioTipoAlteracaoOrigem.reprogramacao =>
        'Datas gerais da atividade alteradas',
      TaskApoioTipoAlteracaoOrigem.alteracaoPeriodos =>
        'Períodos/segmentos do Gantt alterados',
      TaskApoioTipoAlteracaoOrigem.alteracaoFrota =>
        'Alocação de frota alterada',
      TaskApoioTipoAlteracaoOrigem.alteracaoExecutores =>
        'Alocação de executores alterada',
    };
    return '$base ($qtdSols solicitação(ões) impactada(s)${quebrou ? ', com incompatibilidade detectada' : ''}).';
  }
}

