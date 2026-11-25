import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/task_apoio_historico.dart';
import '../../domain/models/task_apoio_situacao.dart';
import '../../domain/models/task_apoio_solicitacao.dart';
import '../../domain/models/task_apoio_tipo.dart';
import '../../domain/models/task_apoio_vinculo.dart';
import '../../domain/repositories/task_apoio_repository.dart';

/// Adaptador de acesso ao backend Supabase para Apoios Operacionais.
///
/// SEGURANÇA OBRIGATÓRIA (Fase 2/3):
/// Enquanto o TaskFlow não possuir identidade autenticada verificável pelo backend
/// (JWT válido / Edge Function autenticada), TODAS as operações operacionais
/// permanecem bloqueadas com [TaskApoioAuthRequiredException].
/// - Nunca utiliza `service_role` no aplicativo Flutter.
/// - Nunca envia `p_usuario_id` como prova de identidade em RPC pública.
class ProtectedBackendTaskApoioAdapter implements ITaskApoioRepository {
  final SupabaseClient? _client;
  final bool Function()? _hasVerifiedBackendSession;

  const ProtectedBackendTaskApoioAdapter({
    SupabaseClient? client,
    bool Function()? hasVerifiedBackendSession,
  })  : _client = client,
        _hasVerifiedBackendSession = hasVerifiedBackendSession;

  void _garantirIdentidadeVerificavel() {
    final session = _client?.auth.currentSession;
    final verificada = (_hasVerifiedBackendSession?.call() ?? false) ||
        (session != null && session.accessToken.isNotEmpty);
    if (!verificada) {
      throw const TaskApoioAuthRequiredException();
    }
    // Mesmo se houver sessão futura, enquanto os endpoints seguros da Fase 4/Auth
    // não forem habilitados, não executa escrita direta em tabelas protegidas.
    throw const TaskApoioAuthRequiredException(
      'Endpoint protegido aguardando habilitação da camada autenticada no backend.',
    );
  }

  SupabaseClient? _resolveClient() {
    if (_client != null) return _client;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<TaskApoioTipo>> listarTiposAtivos() async {
    final client = _resolveClient();
    if (client == null) {
      throw const TaskApoioAuthRequiredException(
        'Cliente Supabase não inicializado para consulta de catálogo.',
      );
    }
    final data = await client
        .from('tasks_apoios_tipos')
        .select()
        .eq('ativo', true)
        .order('ordem', ascending: true);
    return (data as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(TaskApoioTipo.fromJson)
        .toList();
  }

  @override
  Future<List<TaskApoioSolicitacao>> buscarSolicitacoes({
    TaskApoioFiltro filtro = const TaskApoioFiltro(),
  }) async {
    _garantirIdentidadeVerificavel();
    return const [];
  }

  @override
  Future<List<TaskApoioSolicitacao>> buscarSolicitacoesRecebidas({
    required String divisaoDestinoId,
    String? regionalDestinoId,
    String? segmentoDestinoId,
    int limit = 50,
    int offset = 0,
  }) async {
    _garantirIdentidadeVerificavel();
    return const [];
  }

  @override
  Future<List<TaskApoioSolicitacao>> buscarSolicitacoesEnviadas({
    required String divisaoSolicitanteId,
    String? regionalSolicitanteId,
    int limit = 50,
    int offset = 0,
  }) async {
    _garantirIdentidadeVerificavel();
    return const [];
  }

  @override
  Future<List<TaskApoioSolicitacao>> buscarSolicitacoesPorTask(
    String taskId,
  ) async {
    _garantirIdentidadeVerificavel();
    return const [];
  }

  @override
  Future<TaskApoioSolicitacao?> buscarSolicitacaoPorId(
    String solicitacaoId,
  ) async {
    _garantirIdentidadeVerificavel();
    return null;
  }

  @override
  Future<TaskApoioSolicitacao> criarSolicitacao(
    TaskApoioSolicitacao solicitacao,
  ) async {
    _garantirIdentidadeVerificavel();
    throw const TaskApoioAuthRequiredException();
  }

  @override
  Future<TaskApoioSolicitacao> atualizarSolicitacao(
    TaskApoioSolicitacao solicitacao, {
    required String atorUsuarioId,
    String? atorNome,
    String? eventoHistorico,
  }) async {
    _garantirIdentidadeVerificavel();
    throw const TaskApoioAuthRequiredException();
  }

  @override
  Future<List<TaskApoioVinculo>> buscarVinculosPorTask(
    String taskId, {
    bool apenasAtivos = true,
  }) async {
    _garantirIdentidadeVerificavel();
    return const [];
  }

  @override
  Future<List<TaskApoioVinculo>> buscarVinculosPorSolicitacao(
    String solicitacaoId, {
    bool apenasAtivos = true,
  }) async {
    _garantirIdentidadeVerificavel();
    return const [];
  }

  @override
  Future<TaskApoioVinculo> criarVinculo(
    TaskApoioVinculo vinculo, {
    String? atorNome,
  }) async {
    _garantirIdentidadeVerificavel();
    throw const TaskApoioAuthRequiredException();
  }

  @override
  Future<TaskApoioVinculo> desativarVinculo({
    required String vinculoId,
    required int versaoEsperada,
    required String atorUsuarioId,
    String? atorNome,
    required String motivo,
  }) async {
    _garantirIdentidadeVerificavel();
    throw const TaskApoioAuthRequiredException();
  }

  @override
  Future<List<TaskApoioHistorico>> buscarHistorico({
    String? solicitacaoId,
    String? vinculoId,
    String? taskId,
  }) async {
    _garantirIdentidadeVerificavel();
    return const [];
  }

  @override
  Future<Map<String, TaskApoioResumo>> buscarResumosEmLote(
    List<String> taskIds,
  ) async {
    _garantirIdentidadeVerificavel();
    return const {};
  }
}

