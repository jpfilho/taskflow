import '../../domain/engine/task_apoio_compatibility_engine.dart';
import '../../domain/enums/task_apoio_enums.dart';
import '../../domain/models/task_apoio_historico.dart';
import '../../domain/models/task_apoio_situacao.dart';
import '../../domain/models/task_apoio_solicitacao.dart';
import '../../domain/models/task_apoio_tipo.dart';
import '../../domain/models/task_apoio_vinculo.dart';
import '../../domain/repositories/task_apoio_repository.dart';
import '../../domain/rules/task_apoio_state_machine.dart';
import '../../domain/validators/task_apoio_validator.dart';

/// Implementação em memória para desenvolvimento e testes unitários/integração,
/// espelhando as constraints e triggers implementados na Fase 2.
class InMemoryTaskApoioRepository implements ITaskApoioRepository {
  final List<TaskApoioTipo> _tipos;
  final Map<String, TaskApoioSolicitacao> _solicitacoes = {};
  final Map<String, TaskApoioVinculo> _vinculos = {};
  final List<TaskApoioHistorico> _historico = [];
  int _seqHist = 0;

  InMemoryTaskApoioRepository({List<TaskApoioTipo>? tiposIniciais})
      : _tipos = List<TaskApoioTipo>.from(
          tiposIniciais ?? tiposPadraoSeed,
        );

  static const List<TaskApoioTipo> tiposPadraoSeed = [
    TaskApoioTipo(
      id: 'tipo-frota',
      codigo: 'FROTA_VEICULOS',
      nome: 'Frota e veículos',
      exigeRecursoFrota: true,
      ordem: 1,
    ),
    TaskApoioTipo(
      id: 'tipo-maquinas',
      codigo: 'MAQUINAS_EQUIPAMENTOS',
      nome: 'Máquinas e equipamentos',
      exigeRecursoFrota: true,
      ordem: 2,
    ),
    TaskApoioTipo(
      id: 'tipo-equipe',
      codigo: 'EQUIPE_APOIO',
      nome: 'Equipe de apoio',
      exigeRecursoEquipe: true,
      ordem: 3,
    ),
    TaskApoioTipo(
      id: 'tipo-manobra',
      codigo: 'OPERACAO_MANOBRAS',
      nome: 'Operação e manobras',
      exigeRecursoEquipe: true,
      ordem: 5,
    ),
    TaskApoioTipo(
      id: 'tipo-transporte',
      codigo: 'TRANSPORTE',
      nome: 'Transporte',
      exigeRecursoFrota: true,
      ordem: 6,
    ),
    TaskApoioTipo(
      id: 'tipo-outros',
      codigo: 'OUTROS',
      nome: 'Outros',
      ordem: 10,
    ),
  ];

  @override
  Future<List<TaskApoioTipo>> listarTiposAtivos() async {
    return _tipos.where((t) => t.ativo).toList()
      ..sort((a, b) => a.ordem.compareTo(b.ordem));
  }

  @override
  Future<List<TaskApoioSolicitacao>> buscarSolicitacoes({
    TaskApoioFiltro filtro = const TaskApoioFiltro(),
  }) async {
    final filtradas = _solicitacoes.values.where((s) {
      if (filtro.regionalSolicitanteId != null &&
          s.regionalSolicitanteId != filtro.regionalSolicitanteId) {
        return false;
      }
      if (filtro.divisaoSolicitanteId != null &&
          s.divisaoSolicitanteId != filtro.divisaoSolicitanteId) {
        return false;
      }
      if (filtro.regionalDestinoId != null &&
          s.regionalDestinoId != filtro.regionalDestinoId) {
        return false;
      }
      if (filtro.divisaoDestinoId != null &&
          s.divisaoDestinoId != filtro.divisaoDestinoId) {
        return false;
      }
      if (filtro.segmentoDestinoId != null &&
          s.segmentoDestinoId != filtro.segmentoDestinoId) {
        return false;
      }
      if (filtro.taskId != null && s.taskSolicitanteId != filtro.taskId) {
        return false;
      }
      if (filtro.tipoApoioId != null && s.tipoApoioId != filtro.tipoApoioId) {
        return false;
      }
      if (filtro.statuses != null &&
          filtro.statuses!.isNotEmpty &&
          !filtro.statuses!.contains(s.status)) {
        return false;
      }
      if (filtro.prioridade != null && s.prioridade != filtro.prioridade) {
        return false;
      }
      if (filtro.criticidade != null && s.criticidade != filtro.criticidade) {
        return false;
      }
      if (filtro.dataInicioDe != null &&
          s.dataInicioSolicitada.isBefore(filtro.dataInicioDe!)) {
        return false;
      }
      if (filtro.dataInicioAte != null &&
          s.dataInicioSolicitada.isAfter(filtro.dataInicioAte!)) {
        return false;
      }
      return true;
    }).toList()
      ..sort(
        (a, b) => a.dataInicioSolicitada.compareTo(b.dataInicioSolicitada),
      );

    final start = filtro.offset.clamp(0, filtradas.length);
    final end = (start + filtro.limit).clamp(start, filtradas.length);
    return filtradas.sublist(start, end);
  }

  @override
  Future<List<TaskApoioSolicitacao>> buscarSolicitacoesRecebidas({
    required String divisaoDestinoId,
    String? regionalDestinoId,
    String? segmentoDestinoId,
    int limit = 50,
    int offset = 0,
  }) {
    return buscarSolicitacoes(
      filtro: TaskApoioFiltro(
        divisaoDestinoId: divisaoDestinoId,
        regionalDestinoId: regionalDestinoId,
        segmentoDestinoId: segmentoDestinoId,
        limit: limit,
        offset: offset,
      ),
    );
  }

  @override
  Future<List<TaskApoioSolicitacao>> buscarSolicitacoesEnviadas({
    required String divisaoSolicitanteId,
    String? regionalSolicitanteId,
    int limit = 50,
    int offset = 0,
  }) {
    return buscarSolicitacoes(
      filtro: TaskApoioFiltro(
        divisaoSolicitanteId: divisaoSolicitanteId,
        regionalSolicitanteId: regionalSolicitanteId,
        limit: limit,
        offset: offset,
      ),
    );
  }

  @override
  Future<List<TaskApoioSolicitacao>> buscarSolicitacoesPorTask(
    String taskId,
  ) {
    return buscarSolicitacoes(
      filtro: TaskApoioFiltro(taskId: taskId, limit: 200),
    );
  }

  @override
  Future<TaskApoioSolicitacao?> buscarSolicitacaoPorId(
    String solicitacaoId,
  ) async {
    return _solicitacoes[solicitacaoId];
  }

  @override
  Future<TaskApoioSolicitacao> criarSolicitacao(
    TaskApoioSolicitacao solicitacao,
  ) async {
    final erros = TaskApoioValidator.validarSolicitacao(solicitacao);
    if (erros.isNotEmpty) {
      throw ArgumentError(erros.join(' '));
    }

    // Idempotência por idempotencyKey
    if (solicitacao.idempotencyKey != null &&
        solicitacao.idempotencyKey!.trim().isNotEmpty) {
      for (final existente in _solicitacoes.values) {
        if (existente.idempotencyKey == solicitacao.idempotencyKey) {
          return existente;
        }
      }
    }

    final agora = DateTime.now().toUtc();
    final criada = solicitacao.copyWith(
      status: TaskApoioStatus.pendente,
      versao: 1,
      ativo: true,
      createdAt: solicitacao.createdAt ?? agora,
      updatedAt: agora,
      syncStatus: TaskApoioSyncStatus.confirmadoServidor,
    );
    _solicitacoes[criada.id] = criada;

    _registrarHistorico(
      solicitacaoId: criada.id,
      taskRelacionadaId: criada.taskSolicitanteId,
      evento: 'SOLICITACAO_CRIADA',
      statusNovo: criada.status.dbValue,
      usuarioId: criada.solicitanteUsuarioId,
      detalhes: {'descricao': criada.descricao},
    );

    return criada;
  }

  @override
  Future<TaskApoioSolicitacao> atualizarSolicitacao(
    TaskApoioSolicitacao solicitacao, {
    required String atorUsuarioId,
    String? atorNome,
    String? eventoHistorico,
  }) async {
    final atual = _solicitacoes[solicitacao.id];
    if (atual == null) {
      throw StateError('Solicitação ${solicitacao.id} não encontrada.');
    }

    if (solicitacao.versao != atual.versao) {
      throw TaskApoioVersionConflictException(
        'Conflito de versão na solicitação ${atual.id} (esperada: ${atual.versao}, informada: ${solicitacao.versao}).',
      );
    }

    TaskApoioStateMachine.validarTransicao(
      atual: atual.status,
      destino: solicitacao.status,
      justificativa: solicitacao.status == TaskApoioStatus.contraproposta
          ? solicitacao.contrapropostaJustificativa
          : (solicitacao.status == TaskApoioStatus.cancelada
              ? (solicitacao.motivoCancelamento ??
                  solicitacao.justificativaDecisao)
              : solicitacao.justificativaDecisao),
      contrapropostaInicio: solicitacao.contrapropostaInicio,
      contrapropostaFim: solicitacao.contrapropostaFim,
    );

    final agora = DateTime.now().toUtc();
    DateTime? acordadaIni = solicitacao.dataInicioAcordada;
    DateTime? acordadaFim = solicitacao.dataFimAcordada;

    if (solicitacao.status == TaskApoioStatus.aceita &&
        acordadaIni == null) {
      if (atual.status == TaskApoioStatus.contraproposta) {
        acordadaIni = solicitacao.contrapropostaInicio ?? atual.contrapropostaInicio;
        acordadaFim = solicitacao.contrapropostaFim ?? atual.contrapropostaFim;
      } else {
        acordadaIni = solicitacao.dataInicioSolicitada;
        acordadaFim = solicitacao.dataFimSolicitada;
      }
    }

    final atualizada = solicitacao.copyWith(
      dataInicioSolicitada: atual.dataInicioSolicitada, // preserva original
      dataFimSolicitada: atual.dataFimSolicitada,
      dataInicioAcordada: acordadaIni,
      dataFimAcordada: acordadaFim,
      ativo: solicitacao.status == TaskApoioStatus.cancelada
          ? false
          : solicitacao.ativo,
      canceladoEm: solicitacao.status == TaskApoioStatus.cancelada
          ? (solicitacao.canceladoEm ?? agora)
          : solicitacao.canceladoEm,
      versao: atual.versao + 1,
      updatedAt: agora,
      syncStatus: TaskApoioSyncStatus.confirmadoServidor,
    );

    _solicitacoes[atualizada.id] = atualizada;

    _registrarHistorico(
      solicitacaoId: atualizada.id,
      taskRelacionadaId: atualizada.taskSolicitanteId,
      evento: eventoHistorico ??
          (atual.status != atualizada.status
              ? 'STATUS_${atualizada.status.dbValue}'
              : 'SOLICITACAO_ATUALIZADA'),
      statusAnterior: atual.status.dbValue,
      statusNovo: atualizada.status.dbValue,
      justificativa: atualizada.justificativaDecisao ??
          atualizada.contrapropostaJustificativa ??
          atualizada.motivoCancelamento,
      usuarioId: atorUsuarioId,
      usuarioNome: atorNome,
    );

    return atualizada;
  }

  @override
  Future<List<TaskApoioVinculo>> buscarVinculosPorTask(
    String taskId, {
    bool apenasAtivos = true,
  }) async {
    return _vinculos.values.where((v) {
      if (apenasAtivos && !v.ativo) return false;
      return v.taskPrincipalId == taskId || v.taskApoioId == taskId;
    }).toList();
  }

  @override
  Future<List<TaskApoioVinculo>> buscarVinculosPorSolicitacao(
    String solicitacaoId, {
    bool apenasAtivos = true,
  }) async {
    return _vinculos.values.where((v) {
      if (apenasAtivos && !v.ativo) return false;
      return v.solicitacaoId == solicitacaoId;
    }).toList();
  }

  @override
  Future<TaskApoioVinculo> criarVinculo(
    TaskApoioVinculo vinculo, {
    String? atorNome,
  }) async {
    final erros = TaskApoioValidator.validarVinculo(vinculo);
    if (erros.isNotEmpty) {
      throw ArgumentError(erros.join(' '));
    }

    if (vinculo.idempotencyKey != null &&
        vinculo.idempotencyKey!.trim().isNotEmpty) {
      for (final ex in _vinculos.values) {
        if (ex.idempotencyKey == vinculo.idempotencyKey) return ex;
      }
    }

    if (vinculo.solicitacaoId != null) {
      final sol = _solicitacoes[vinculo.solicitacaoId];
      if (sol == null) {
        throw StateError('Solicitação ${vinculo.solicitacaoId} não encontrada.');
      }
      if (sol.status.isFinal) {
        throw StateError(
          'Não é possível vincular atividade a solicitação ${sol.status.dbValue}.',
        );
      }
      if (sol.taskSolicitanteId != null &&
          vinculo.taskPrincipalId != sol.taskSolicitanteId) {
        throw ArgumentError(
          'A tarefa principal do vínculo difere da tarefa da solicitação.',
        );
      }
    }

    // Verificar duplicidade simétrica em programação conjunta e duplicidade de vínculo ativo
    for (final ex in _vinculos.values.where((v) => v.ativo)) {
      if (vinculo.finalidade ==
              TaskApoioFinalidadeVinculo.programacaoConjunta &&
          ex.finalidade == TaskApoioFinalidadeVinculo.programacaoConjunta) {
        final mesmoPar = (ex.taskPrincipalId == vinculo.taskPrincipalId &&
                ex.taskApoioId == vinculo.taskApoioId) ||
            (ex.taskPrincipalId == vinculo.taskApoioId &&
                ex.taskApoioId == vinculo.taskPrincipalId);
        if (mesmoPar) {
          throw StateError(
            'Já existe programação conjunta ativa entre estas duas atividades.',
          );
        }
      } else if (ex.solicitacaoId == vinculo.solicitacaoId &&
          ex.taskPrincipalId == vinculo.taskPrincipalId &&
          ex.taskApoioId == vinculo.taskApoioId &&
          ex.finalidade == vinculo.finalidade) {
        throw StateError('Vínculo ativo já existente.');
      }
    }

    final agora = DateTime.now().toUtc();
    final criado = vinculo.copyWith(
      versao: 1,
      ativo: true,
      createdAt: vinculo.createdAt ?? agora,
      updatedAt: agora,
      syncStatus: TaskApoioSyncStatus.confirmadoServidor,
    );
    _vinculos[criado.id] = criado;

    _registrarHistorico(
      solicitacaoId: criado.solicitacaoId,
      vinculoId: criado.id,
      taskRelacionadaId: criado.taskApoioId ?? criado.taskPrincipalId,
      evento: 'VINCULO_CRIADO',
      usuarioId: criado.createdBy,
      usuarioNome: atorNome,
      detalhes: {'finalidade': criado.finalidade.dbValue},
    );

    return criado;
  }

  @override
  Future<TaskApoioVinculo> desativarVinculo({
    required String vinculoId,
    required int versaoEsperada,
    required String atorUsuarioId,
    String? atorNome,
    required String motivo,
  }) async {
    final atual = _vinculos[vinculoId];
    if (atual == null) {
      throw StateError('Vínculo $vinculoId não encontrado.');
    }
    if (versaoEsperada != atual.versao) {
      throw TaskApoioVersionConflictException(
        'Conflito de versão no vínculo $vinculoId (esperada: ${atual.versao}, informada: $versaoEsperada).',
      );
    }

    final agora = DateTime.now().toUtc();
    final desativado = atual.copyWith(
      ativo: false,
      desativadoEm: agora,
      desativadoPor: atorUsuarioId,
      motivoDesativacao: motivo,
      versao: atual.versao + 1,
      updatedAt: agora,
    );
    _vinculos[vinculoId] = desativado;

    _registrarHistorico(
      solicitacaoId: desativado.solicitacaoId,
      vinculoId: desativado.id,
      taskRelacionadaId: desativado.taskApoioId,
      evento: 'VINCULO_DESATIVADO',
      justificativa: motivo,
      usuarioId: atorUsuarioId,
      usuarioNome: atorNome,
    );

    return desativado;
  }

  @override
  Future<List<TaskApoioHistorico>> buscarHistorico({
    String? solicitacaoId,
    String? vinculoId,
    String? taskId,
  }) async {
    return _historico.where((h) {
      if (solicitacaoId != null && h.solicitacaoId != solicitacaoId) {
        return false;
      }
      if (vinculoId != null && h.vinculoId != vinculoId) return false;
      if (taskId != null && h.taskRelacionadaId != taskId) return false;
      return true;
    }).toList();
  }

  @override
  Future<Map<String, TaskApoioResumo>> buscarResumosEmLote(
    List<String> taskIds,
  ) async {
    final engine = TaskApoioCompatibilityEngine();
    final resultado = <String, TaskApoioResumo>{};

    for (final taskId in taskIds.toSet()) {
      final sols = _solicitacoes.values
          .where((s) => s.taskSolicitanteId == taskId)
          .toList();
      final apoiadas = _vinculos.values
          .where((v) => v.ativo && v.taskApoioId == taskId)
          .length;

      final situacoes = sols.map((sol) {
        final vincs = _vinculos.values
            .where((v) => v.ativo && v.solicitacaoId == sol.id)
            .map((v) => TaskApoioVinculoComTask(vinculo: v))
            .toList();
        return engine.calcularSituacaoSolicitacao(
          solicitacao: sol,
          vinculos: vincs,
        );
      }).toList();

      resultado[taskId] = engine.consolidarResumoTaskPrincipal(
        taskId: taskId,
        solicitacoesDaTask: sols,
        situacoes: situacoes,
        qtdAtividadesApoiadas: apoiadas,
      );
    }

    return resultado;
  }

  void _registrarHistorico({
    String? solicitacaoId,
    String? vinculoId,
    String? taskRelacionadaId,
    required String evento,
    String? statusAnterior,
    String? statusNovo,
    String? justificativa,
    String? usuarioId,
    String? usuarioNome,
    Map<String, dynamic> detalhes = const {},
  }) {
    _seqHist++;
    _historico.add(
      TaskApoioHistorico(
        id: 'hist-$_seqHist',
        solicitacaoId: solicitacaoId,
        vinculoId: vinculoId,
        taskRelacionadaId: taskRelacionadaId,
        evento: evento,
        statusAnterior: statusAnterior,
        statusNovo: statusNovo,
        justificativa: justificativa,
        detalhesJson: detalhes,
        usuarioId: usuarioId,
        usuarioNome: usuarioNome,
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }
}
