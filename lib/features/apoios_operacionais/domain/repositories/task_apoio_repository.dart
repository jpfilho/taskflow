import '../enums/task_apoio_enums.dart';
import '../models/task_apoio_historico.dart';
import '../models/task_apoio_situacao.dart';
import '../models/task_apoio_solicitacao.dart';
import '../models/task_apoio_tipo.dart';
import '../models/task_apoio_vinculo.dart';

/// Filtros para consulta paginada de solicitações de apoio.
class TaskApoioFiltro {
  final String? regionalSolicitanteId;
  final String? divisaoSolicitanteId;
  final String? regionalDestinoId;
  final String? divisaoDestinoId;
  final String? segmentoDestinoId;
  final String? taskId;
  final String? tipoApoioId;
  final Set<TaskApoioStatus>? statuses;
  final TaskApoioPrioridade? prioridade;
  final TaskApoioCriticidade? criticidade;
  final DateTime? dataInicioDe;
  final DateTime? dataInicioAte;
  final int limit;
  final int offset;

  const TaskApoioFiltro({
    this.regionalSolicitanteId,
    this.divisaoSolicitanteId,
    this.regionalDestinoId,
    this.divisaoDestinoId,
    this.segmentoDestinoId,
    this.taskId,
    this.tipoApoioId,
    this.statuses,
    this.prioridade,
    this.criticidade,
    this.dataInicioDe,
    this.dataInicioAte,
    this.limit = 50,
    this.offset = 0,
  });
}

/// Exceção explícita para operações bloqueadas por ausência de identidade verificável no backend.
class TaskApoioAuthRequiredException implements Exception {
  final String message;
  const TaskApoioAuthRequiredException([
    this.message =
        'Operação indisponível: identidade autenticada verificável pelo backend ainda não configurada.',
  ]);

  @override
  String toString() => 'TaskApoioAuthRequiredException: $message';
}

/// Exceção explícita para conflito de versão otimista.
class TaskApoioVersionConflictException implements Exception {
  final String message;
  const TaskApoioVersionConflictException(this.message);

  @override
  String toString() => 'TaskApoioVersionConflictException: $message';
}

/// Interface desacoplada de repositório para Gestão Integrada de Apoios Operacionais.
abstract class ITaskApoioRepository {
  Future<List<TaskApoioTipo>> listarTiposAtivos();

  Future<List<TaskApoioSolicitacao>> buscarSolicitacoes({
    TaskApoioFiltro filtro = const TaskApoioFiltro(),
  });

  Future<List<TaskApoioSolicitacao>> buscarSolicitacoesRecebidas({
    required String divisaoDestinoId,
    String? regionalDestinoId,
    String? segmentoDestinoId,
    int limit = 50,
    int offset = 0,
  });

  Future<List<TaskApoioSolicitacao>> buscarSolicitacoesEnviadas({
    required String divisaoSolicitanteId,
    String? regionalSolicitanteId,
    int limit = 50,
    int offset = 0,
  });

  Future<List<TaskApoioSolicitacao>> buscarSolicitacoesPorTask(String taskId);

  Future<TaskApoioSolicitacao?> buscarSolicitacaoPorId(String solicitacaoId);

  Future<TaskApoioSolicitacao> criarSolicitacao(
    TaskApoioSolicitacao solicitacao,
  );

  Future<TaskApoioSolicitacao> atualizarSolicitacao(
    TaskApoioSolicitacao solicitacao, {
    required String atorUsuarioId,
    String? atorNome,
    String? eventoHistorico,
  });

  Future<List<TaskApoioVinculo>> buscarVinculosPorTask(
    String taskId, {
    bool apenasAtivos = true,
  });

  Future<List<TaskApoioVinculo>> buscarVinculosPorSolicitacao(
    String solicitacaoId, {
    bool apenasAtivos = true,
  });

  Future<TaskApoioVinculo> criarVinculo(
    TaskApoioVinculo vinculo, {
    String? atorNome,
  });

  Future<TaskApoioVinculo> desativarVinculo({
    required String vinculoId,
    required int versaoEsperada,
    required String atorUsuarioId,
    String? atorNome,
    required String motivo,
  });

  Future<List<TaskApoioHistorico>> buscarHistorico({
    String? solicitacaoId,
    String? vinculoId,
    String? taskId,
  });

  /// Consulta em lote evitando N+1 na tabela de atividades.
  Future<Map<String, TaskApoioResumo>> buscarResumosEmLote(
    List<String> taskIds,
  );
}

