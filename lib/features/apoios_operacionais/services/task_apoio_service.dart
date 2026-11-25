import '../../../../models/task.dart';
import '../domain/engine/task_apoio_compatibility_engine.dart';
import '../domain/enums/task_apoio_enums.dart';
import '../domain/models/task_apoio_historico.dart';
import '../domain/models/task_apoio_periodo.dart';
import '../domain/models/task_apoio_situacao.dart';
import '../domain/models/task_apoio_solicitacao.dart';
import '../domain/models/task_apoio_tipo.dart';
import '../domain/models/task_apoio_vinculo.dart';
import '../domain/repositories/task_apoio_repository.dart';
import '../domain/rules/task_apoio_state_machine.dart';

/// Serviço de aplicação para Gestão Integrada de Apoios Operacionais.
/// Desacoplado via [ITaskApoioRepository] e integrado ao [TaskApoioCompatibilityEngine].
class TaskApoioService {
  final ITaskApoioRepository _repository;
  final TaskApoioCompatibilityEngine _engine;

  TaskApoioService({
    required ITaskApoioRepository repository,
    TaskApoioCompatibilityEngine? engine,
  })  : _repository = repository,
        _engine = engine ?? TaskApoioCompatibilityEngine();

  // ---------------------------------------------------------------------------
  // CONSULTAS
  // ---------------------------------------------------------------------------

  Future<List<TaskApoioTipo>> listarTiposAtivos() =>
      _repository.listarTiposAtivos();

  Future<List<TaskApoioSolicitacao>> buscarSolicitacoes({
    TaskApoioFiltro filtro = const TaskApoioFiltro(),
  }) =>
      _repository.buscarSolicitacoes(filtro: filtro);

  Future<List<TaskApoioSolicitacao>> buscarSolicitacoesRecebidas({
    required String divisaoDestinoId,
    String? regionalDestinoId,
    String? segmentoDestinoId,
    int limit = 50,
    int offset = 0,
  }) =>
      _repository.buscarSolicitacoesRecebidas(
        divisaoDestinoId: divisaoDestinoId,
        regionalDestinoId: regionalDestinoId,
        segmentoDestinoId: segmentoDestinoId,
        limit: limit,
        offset: offset,
      );

  Future<List<TaskApoioSolicitacao>> buscarSolicitacoesEnviadas({
    required String divisaoSolicitanteId,
    String? regionalSolicitanteId,
    int limit = 50,
    int offset = 0,
  }) =>
      _repository.buscarSolicitacoesEnviadas(
        divisaoSolicitanteId: divisaoSolicitanteId,
        regionalSolicitanteId: regionalSolicitanteId,
        limit: limit,
        offset: offset,
      );

  Future<TaskApoioSolicitacao?> buscarSolicitacaoPorId(String id) {
    return _repository.buscarSolicitacaoPorId(id);
  }

  Future<List<TaskApoioSolicitacao>> buscarSolicitacoesPorAtividade(
    String taskId,
  ) =>
      _repository.buscarSolicitacoesPorTask(taskId);

  /// Busca vínculos onde `taskId` é atividade principal (apoios recebidos).
  Future<List<TaskApoioVinculo>> buscarAtividadesApoioVinculadas(
    String taskId,
  ) async {
    final todos = await _repository.buscarVinculosPorTask(taskId);
    return todos.where((v) => v.taskPrincipalId == taskId).toList();
  }

  /// Busca vínculos onde `taskId` é atividade de apoio (atividades atendidas).
  Future<List<TaskApoioVinculo>> buscarAtividadesAtendidas(
    String taskId,
  ) async {
    final todos = await _repository.buscarVinculosPorTask(taskId);
    return todos.where((v) => v.taskApoioId == taskId).toList();
  }

  /// Visão bidirecional de relacionamentos da atividade (principal + apoio + conjunta).
  Future<List<TaskApoioVinculo>> consultarRelacionamentoBidirecional(
    String taskId,
  ) =>
      _repository.buscarVinculosPorTask(taskId);

  Future<List<TaskApoioHistorico>> buscarHistorico({
    String? solicitacaoId,
    String? vinculoId,
    String? taskId,
  }) =>
      _repository.buscarHistorico(
        solicitacaoId: solicitacaoId,
        vinculoId: vinculoId,
        taskId: taskId,
      );

  Future<Map<String, TaskApoioResumo>> buscarResumosEmLote(
    List<String> taskIds,
  ) =>
      _repository.buscarResumosEmLote(taskIds);

  Future<TaskApoioResumo> buscarResumoPorAtividade(String taskId) async {
    final mapa = await _repository.buscarResumosEmLote([taskId]);
    return mapa[taskId] ?? TaskApoioResumo(taskId: taskId);
  }

  Future<TaskApoioIndicadores> calcularIndicadoresGerenciais({
    TaskApoioFiltro filtro = const TaskApoioFiltro(limit: 500),
    Map<String, Task> tasksPorId = const {},
  }) async {
    final lista = await _repository.buscarSolicitacoes(filtro: filtro);
    final tipos = {for (final t in await listarTiposAtivos()) t.id: t};

    int pendentes = 0;
    int emAnalise = 0;
    int contrapropostas = 0;
    int aceitas = 0;
    int recusadas = 0;
    int canceladas = 0;
    int aceitasSemProg = 0;
    int parciais = 0;
    int incompat = 0;
    int recPend = 0;
    int urgentesAbertas = 0;

    for (final sol in lista) {
      switch (sol.status) {
        case TaskApoioStatus.pendente:
          pendentes++;
        case TaskApoioStatus.emAnalise:
          emAnalise++;
        case TaskApoioStatus.contraproposta:
          contrapropostas++;
        case TaskApoioStatus.aceita:
          aceitas++;
        case TaskApoioStatus.recusada:
          recusadas++;
        case TaskApoioStatus.cancelada:
          canceladas++;
        case TaskApoioStatus.desconhecido:
          break;
      }

      if (sol.prioridade == TaskApoioPrioridade.urgente && sol.status.isAtiva) {
        urgentesAbertas++;
      }

      final sit = await avaliarSituacaoSolicitacao(
        solicitacao: sol,
        tipoApoio: tipos[sol.tipoApoioId],
        tasksPorId: tasksPorId,
      );

      switch (sit.situacaoOperacional) {
        case TaskApoioSituacaoOperacional.aceitaSemProgramacao:
          aceitasSemProg++;
        case TaskApoioSituacaoOperacional.parcialmenteProgramada:
          parciais++;
        case TaskApoioSituacaoOperacional.programadaComIncompatibilidade:
          incompat++;
        case TaskApoioSituacaoOperacional.programadaComRecursosPendentes:
          recPend++;
        default:
          break;
      }
    }

    return TaskApoioIndicadores(
      totalSolicitacoes: lista.length,
      pendentes: pendentes,
      emAnalise: emAnalise,
      contrapropostas: contrapropostas,
      aceitas: aceitas,
      recusadas: recusadas,
      canceladas: canceladas,
      aceitasSemProgramacao: aceitasSemProg,
      parcialmenteProgramadas: parciais,
      comIncompatibilidadeOuRisco: incompat,
      comRecursosPendentes: recPend,
      urgentesAbertas: urgentesAbertas,
    );
  }

  // ---------------------------------------------------------------------------
  // SOLICITAÇÕES
  // ---------------------------------------------------------------------------

  Future<TaskApoioSolicitacao> criarSolicitacao(
    TaskApoioSolicitacao solicitacao,
  ) =>
      _repository.criarSolicitacao(solicitacao);

  Future<TaskApoioSolicitacao> alterarNecessidade({
    required String solicitacaoId,
    required int versaoEsperada,
    required String atorUsuarioId,
    String? atorNome,
    String? novaDescricao,
    DateTime? novoInicio,
    DateTime? novoFim,
    List<TaskApoioPeriodo>? novosPeriodos,
  }) async {
    final atual = await _obterSolicitacao(solicitacaoId);
    if (atual.status != TaskApoioStatus.pendente &&
        atual.status != TaskApoioStatus.emAnalise) {
      throw StateError(
        'Alteração direta de necessidade permitida apenas em PENDENTE ou EM_ANALISE.',
      );
    }
    return _repository.atualizarSolicitacao(
      atual.copyWith(
        descricao: novaDescricao ?? atual.descricao,
        dataInicioSolicitada: novoInicio ?? atual.dataInicioSolicitada,
        dataFimSolicitada: novoFim ?? atual.dataFimSolicitada,
        periodos: novosPeriodos ?? atual.periodos,
        versao: versaoEsperada,
      ),
      atorUsuarioId: atorUsuarioId,
      atorNome: atorNome,
      eventoHistorico: 'NECESSIDADE_ALTERADA',
    );
  }

  Future<TaskApoioSolicitacao> encaminharParaAnalise({
    required String solicitacaoId,
    required int versaoEsperada,
    required String responsavelId,
    String? responsavelNome,
  }) async {
    final atual = await _obterSolicitacao(solicitacaoId);
    return _repository.atualizarSolicitacao(
      atual.copyWith(
        status: TaskApoioStatus.emAnalise,
        responsavelAtendimentoId: responsavelId,
        versao: versaoEsperada,
      ),
      atorUsuarioId: responsavelId,
      atorNome: responsavelNome,
      eventoHistorico: 'ENCAMINHADA_ANALISE',
    );
  }

  Future<TaskApoioSolicitacao> aceitar({
    required String solicitacaoId,
    required int versaoEsperada,
    required String atorUsuarioId,
    String? atorNome,
    DateTime? dataInicioAcordada,
    DateTime? dataFimAcordada,
    String? observacoes,
  }) async {
    final atual = await _obterSolicitacao(solicitacaoId);
    return _repository.atualizarSolicitacao(
      atual.copyWith(
        status: TaskApoioStatus.aceita,
        responsavelAtendimentoId: atorUsuarioId,
        dataInicioAcordada: dataInicioAcordada,
        dataFimAcordada: dataFimAcordada,
        observacoes: observacoes ?? atual.observacoes,
        versao: versaoEsperada,
      ),
      atorUsuarioId: atorUsuarioId,
      atorNome: atorNome,
      eventoHistorico: 'SOLICITACAO_ACEITA',
    );
  }

  Future<TaskApoioSolicitacao> recusar({
    required String solicitacaoId,
    required int versaoEsperada,
    required String atorUsuarioId,
    String? atorNome,
    required String justificativa,
  }) async {
    final atual = await _obterSolicitacao(solicitacaoId);
    return _repository.atualizarSolicitacao(
      atual.copyWith(
        status: TaskApoioStatus.recusada,
        responsavelAtendimentoId: atorUsuarioId,
        justificativaDecisao: justificativa,
        versao: versaoEsperada,
      ),
      atorUsuarioId: atorUsuarioId,
      atorNome: atorNome,
      eventoHistorico: 'SOLICITACAO_RECUSADA',
    );
  }

  Future<TaskApoioSolicitacao> apresentarContraproposta({
    required String solicitacaoId,
    required int versaoEsperada,
    required String atorUsuarioId,
    String? atorNome,
    required DateTime inicioProposto,
    required DateTime fimProposto,
    required String justificativa,
  }) async {
    final atual = await _obterSolicitacao(solicitacaoId);
    return _repository.atualizarSolicitacao(
      atual.copyWith(
        status: TaskApoioStatus.contraproposta,
        responsavelAtendimentoId: atorUsuarioId,
        contrapropostaInicio: inicioProposto,
        contrapropostaFim: fimProposto,
        contrapropostaJustificativa: justificativa,
        versao: versaoEsperada,
      ),
      atorUsuarioId: atorUsuarioId,
      atorNome: atorNome,
      eventoHistorico: 'CONTRAPROPOSTA_APRESENTADA',
    );
  }

  Future<TaskApoioSolicitacao> aceitarContraproposta({
    required String solicitacaoId,
    required int versaoEsperada,
    required String atorUsuarioId,
    String? atorNome,
  }) async {
    final atual = await _obterSolicitacao(solicitacaoId);
    if (atual.status != TaskApoioStatus.contraproposta) {
      throw StateError('Solicitação não está em CONTRAPROPOSTA.');
    }
    return _repository.atualizarSolicitacao(
      atual.copyWith(
        status: TaskApoioStatus.aceita,
        dataInicioAcordada: atual.contrapropostaInicio,
        dataFimAcordada: atual.contrapropostaFim,
        versao: versaoEsperada,
      ),
      atorUsuarioId: atorUsuarioId,
      atorNome: atorNome,
      eventoHistorico: 'CONTRAPROPOSTA_ACEITA',
    );
  }

  Future<TaskApoioSolicitacao> recusarContraproposta({
    required String solicitacaoId,
    required int versaoEsperada,
    required String atorUsuarioId,
    String? atorNome,
    required String justificativa,
  }) async {
    final atual = await _obterSolicitacao(solicitacaoId);
    if (atual.status != TaskApoioStatus.contraproposta) {
      throw StateError('Solicitação não está em CONTRAPROPOSTA.');
    }
    return _repository.atualizarSolicitacao(
      atual.copyWith(
        status: TaskApoioStatus.recusada,
        justificativaDecisao: justificativa,
        versao: versaoEsperada,
      ),
      atorUsuarioId: atorUsuarioId,
      atorNome: atorNome,
      eventoHistorico: 'CONTRAPROPOSTA_RECUSADA',
    );
  }

  Future<TaskApoioSolicitacao> cancelar({
    required String solicitacaoId,
    required int versaoEsperada,
    required String atorUsuarioId,
    String? atorNome,
    required String motivo,
  }) async {
    final atual = await _obterSolicitacao(solicitacaoId);
    return _repository.atualizarSolicitacao(
      atual.copyWith(
        status: TaskApoioStatus.cancelada,
        canceladoPor: atorUsuarioId,
        canceladoEm: DateTime.now().toUtc(),
        motivoCancelamento: motivo,
        versao: versaoEsperada,
      ),
      atorUsuarioId: atorUsuarioId,
      atorNome: atorNome,
      eventoHistorico: 'SOLICITACAO_CANCELADA',
    );
  }

  Future<TaskApoioSolicitacao> solicitarReconfirmacao({
    required String solicitacaoId,
    required int versaoEsperada,
    required String atorUsuarioId,
    String? atorNome,
    required String motivo,
  }) async {
    final atual = await _obterSolicitacao(solicitacaoId);
    TaskApoioStateMachine.validarTransicao(
      atual: atual.status,
      destino: TaskApoioStatus.emAnalise,
    );
    return _repository.atualizarSolicitacao(
      atual.copyWith(
        status: TaskApoioStatus.emAnalise,
        justificativaDecisao: motivo,
        versao: versaoEsperada,
      ),
      atorUsuarioId: atorUsuarioId,
      atorNome: atorNome,
      eventoHistorico: 'RECONFIRMACAO_SOLICITADA',
    );
  }

  // ---------------------------------------------------------------------------
  // VÍNCULOS E COMPATIBILIDADE
  // ---------------------------------------------------------------------------

  Future<TaskApoioVinculo> vincularAtividadeExistente({
    required String id,
    String? idempotencyKey,
    String? solicitacaoId,
    required Task taskPrincipal,
    required Task taskApoio,
    String? tipoApoioId,
    DateTime? coberturaInicio,
    DateTime? coberturaFim,
    String? observacao,
    required bool autorizadoDireto,
    required String createdBy,
    String? atorNome,
  }) {
    final finalidade = solicitacaoId != null
        ? TaskApoioFinalidadeVinculo.apoioOperacional
        : TaskApoioFinalidadeVinculo.vinculoDireto;

    return _repository.criarVinculo(
      TaskApoioVinculo(
        id: id,
        idempotencyKey: idempotencyKey,
        solicitacaoId: solicitacaoId,
        taskPrincipalId: taskPrincipal.id,
        taskApoioId: taskApoio.id,
        taskPrincipalTituloSnapshot: taskPrincipal.tarefa,
        taskApoioTituloSnapshot: taskApoio.tarefa,
        tipoApoioId: tipoApoioId,
        finalidade: finalidade,
        coberturaInicio: coberturaInicio,
        coberturaFim: coberturaFim,
        observacao: observacao,
        autorizadoDireto: autorizadoDireto,
        createdBy: createdBy,
      ),
      atorNome: atorNome,
    );
  }

  Future<TaskApoioVinculo> criarProgramacaoConjunta({
    required String id,
    String? idempotencyKey,
    required Task taskA,
    required Task taskB,
    String? observacao,
    required String createdBy,
    String? atorNome,
  }) {
    return _repository.criarVinculo(
      TaskApoioVinculo(
        id: id,
        idempotencyKey: idempotencyKey,
        taskPrincipalId: taskA.id,
        taskApoioId: taskB.id,
        taskPrincipalTituloSnapshot: taskA.tarefa,
        taskApoioTituloSnapshot: taskB.tarefa,
        finalidade: TaskApoioFinalidadeVinculo.programacaoConjunta,
        observacao: observacao,
        autorizadoDireto: true,
        createdBy: createdBy,
      ),
      atorNome: atorNome,
    );
  }

  Future<TaskApoioVinculo> desativarVinculo({
    required String vinculoId,
    required int versaoEsperada,
    required String atorUsuarioId,
    String? atorNome,
    required String motivo,
  }) =>
      _repository.desativarVinculo(
        vinculoId: vinculoId,
        versaoEsperada: versaoEsperada,
        atorUsuarioId: atorUsuarioId,
        atorNome: atorNome,
        motivo: motivo,
      );

  /// Prepara o rascunho de nova atividade de apoio mantendo autonomia da unidade
  /// de destino e sem usar `parent_id`.
  Map<String, dynamic> prepararRascunhoNovaAtividadeApoio({
    required TaskApoioSolicitacao solicitacao,
    required String tipoApoioNome,
  }) {
    return {
      'parent_id': null,
      'regional_id': solicitacao.regionalDestinoId,
      'divisao_id': solicitacao.divisaoDestinoId,
      'segmento_id': solicitacao.segmentoDestinoId,
      'data_inicio':
          (solicitacao.dataInicioAcordada ?? solicitacao.dataInicioSolicitada)
              .toIso8601String(),
      'data_fim': (solicitacao.dataFimAcordada ?? solicitacao.dataFimSolicitada)
          .toIso8601String(),
      'tarefa_sugerida':
          '[$tipoApoioNome] Apoio para ${solicitacao.taskSolicitanteTituloSnapshot}',
      'observacoes': solicitacao.descricao,
      'solicitacao_apoio_id': solicitacao.id,
    };
  }

  Future<TaskApoioSituacao> avaliarSituacaoSolicitacao({
    required TaskApoioSolicitacao solicitacao,
    TaskApoioTipo? tipoApoio,
    Map<String, Task> tasksPorId = const {},
  }) async {
    final vinculos = await _repository.buscarVinculosPorSolicitacao(
      solicitacao.id,
    );
    final comTasks = vinculos
        .map(
          (v) => TaskApoioVinculoComTask(
            vinculo: v,
            taskApoio: v.taskApoioId != null ? tasksPorId[v.taskApoioId] : null,
          ),
        )
        .toList();

    // Coletar outros vínculos das mesmas tasks de apoio para detectar compartilhamento
    final outrosVinculos = <TaskApoioVinculoComTask>[];
    for (final v in vinculos) {
      if (v.taskApoioId == null) continue;
      final relacionados = await _repository.buscarVinculosPorTask(
        v.taskApoioId!,
      );
      for (final outro in relacionados) {
        if (outro.solicitacaoId != solicitacao.id &&
            outro.taskApoioId == v.taskApoioId) {
          outrosVinculos.add(
            TaskApoioVinculoComTask(
              vinculo: outro,
              taskApoio: tasksPorId[outro.taskApoioId],
            ),
          );
        }
      }
    }

    return _engine.calcularSituacaoSolicitacao(
      solicitacao: solicitacao,
      vinculos: comTasks,
      tipoApoio: tipoApoio,
      taskPrincipal: solicitacao.taskSolicitanteId != null
          ? tasksPorId[solicitacao.taskSolicitanteId]
          : null,
      outrosVinculosMesmasTasksApoio: outrosVinculos,
    );
  }

  Future<TaskApoioSolicitacao> _obterSolicitacao(String id) async {
    final s = await _repository.buscarSolicitacaoPorId(id);
    if (s == null) {
      throw StateError('Solicitação $id não encontrada.');
    }
    return s;
  }
}

