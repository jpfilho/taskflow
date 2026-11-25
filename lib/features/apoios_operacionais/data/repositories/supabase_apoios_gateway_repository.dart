import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../config/supabase_config.dart';
import '../../../../models/task.dart';
import '../../../../services/task_service.dart';
import '../../domain/enums/task_apoio_enums.dart';
import '../../domain/models/task_apoio_historico.dart';
import '../../domain/models/task_apoio_situacao.dart';
import '../../domain/models/task_apoio_solicitacao.dart';
import '../../domain/models/task_apoio_tipo.dart';
import '../../domain/models/task_apoio_vinculo.dart';
import '../../domain/repositories/task_apoio_repository.dart';
import '../services/apoios_auth_session_service.dart';

/// Repositório real de Apoios Operacionais que se comunica com o Supabase
/// exclusivamente através do gateway HTTP autenticado (`apiBaseUrl/api/apoios`).
///
/// Segurança:
/// - Nunca utiliza `service_role` no aplicativo Flutter.
/// - Exige token assinado válido de [ApoiosAuthSessionService].
/// - Propaga [TaskApoioAuthRequiredException] se não autenticado ou 401.
/// - Propaga [TaskApoioVersionConflictException] em conflitos 409.
class SupabaseApoiosGatewayRepository implements ITaskApoioRepository {
  final ApoiosAuthSessionService _sessionService;
  final http.Client _httpClient;
  final String? _baseUrlOverride;

  SupabaseApoiosGatewayRepository({
    ApoiosAuthSessionService? sessionService,
    http.Client? httpClient,
    String? baseUrlOverride,
  })  : _sessionService = sessionService ?? ApoiosAuthSessionService(),
        _httpClient = httpClient ?? http.Client(),
        _baseUrlOverride = baseUrlOverride;

  String get _baseUrl => _baseUrlOverride ?? SupabaseConfig.apiBaseUrl;

  Map<String, String> _authHeaders() {
    final token = _sessionService.currentToken;
    if (token == null || token.isEmpty || !_sessionService.hasValidToken) {
      throw const TaskApoioAuthRequiredException(
        'Sessão autenticada de Apoios Operacionais não encontrada.',
      );
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _decodeOrThrow(http.Response response) {
    if (response.statusCode == 401) {
      throw const TaskApoioAuthRequiredException(
        'Sessão expirada ou inválida no gateway de Apoios Operacionais.',
      );
    }

    Map<String, dynamic> body = const {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        body = decoded;
      }
    } catch (_) {
      throw Exception(
        'Resposta inválida do gateway (${response.statusCode}): ${response.body}',
      );
    }

    if (response.statusCode == 409) {
      throw TaskApoioVersionConflictException(
        body['error']?.toString() ?? 'Conflito de versão otimista.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300 || body['ok'] == false) {
      throw Exception(
        body['error']?.toString() ??
            'Erro no gateway de Apoios (${response.statusCode}).',
      );
    }
    return body;
  }

  @override
  Future<List<TaskApoioTipo>> listarTiposAtivos() async {
    final uri = Uri.parse('$_baseUrl/api/apoios/tipos');
    final resp = await _httpClient
        .get(uri, headers: _authHeaders())
        .timeout(const Duration(seconds: 12));
    final body = _decodeOrThrow(resp);
    final list = (body['data'] as List?) ?? const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(TaskApoioTipo.fromJson)
        .toList();
  }

  Future<List<TaskApoioTipo>> listarTodosTipos() async {
    final uri = Uri.parse('$_baseUrl/api/apoios/tipos?incluirInativos=true');
    final resp = await _httpClient
        .get(uri, headers: _authHeaders())
        .timeout(const Duration(seconds: 12));
    final body = _decodeOrThrow(resp);
    final list = (body['data'] as List?) ?? const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(TaskApoioTipo.fromJson)
        .toList();
  }

  Future<TaskApoioTipo> criarTipoApoio({
    required String codigo,
    required String nome,
    String? descricao,
    int ordem = 0,
    bool ativo = true,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/apoios/tipos');
    final resp = await _httpClient
        .post(
          uri,
          headers: _authHeaders(),
          body: jsonEncode({
            'codigo': codigo,
            'nome': nome,
            'descricao': descricao,
            'ordem': ordem,
            'ativo': ativo,
          }),
        )
        .timeout(const Duration(seconds: 12));
    final body = _decodeOrThrow(resp);
    return TaskApoioTipo.fromJson(Map<String, dynamic>.from(body['data'] as Map));
  }

  Future<TaskApoioTipo> atualizarTipoApoio(
    String id, {
    String? codigo,
    String? nome,
    String? descricao,
    int? ordem,
    bool? ativo,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/apoios/tipos/$id');
    final payload = <String, dynamic>{
      if (codigo != null) 'codigo': codigo,
      if (nome != null) 'nome': nome,
      if (descricao != null) 'descricao': descricao,
      if (ordem != null) 'ordem': ordem,
      if (ativo != null) 'ativo': ativo,
    };
    final resp = await _httpClient
        .patch(uri, headers: _authHeaders(), body: jsonEncode(payload))
        .timeout(const Duration(seconds: 12));
    final body = _decodeOrThrow(resp);
    return TaskApoioTipo.fromJson(Map<String, dynamic>.from(body['data'] as Map));
  }

  Future<void> excluirTipoApoio(String id) async {
    final uri = Uri.parse('$_baseUrl/api/apoios/tipos/$id');
    final resp = await _httpClient
        .delete(uri, headers: _authHeaders())
        .timeout(const Duration(seconds: 12));
    _decodeOrThrow(resp);
  }

  @override
  Future<List<TaskApoioSolicitacao>> buscarSolicitacoes({
    TaskApoioFiltro filtro = const TaskApoioFiltro(),
  }) async {
    final params = <String, String>{
      'limit': '${filtro.limit}',
      'offset': '${filtro.offset}',
    };
    if (filtro.taskId != null && filtro.taskId!.isNotEmpty) {
      params['taskId'] = filtro.taskId!;
    }
    if (filtro.divisaoSolicitanteId != null &&
        filtro.divisaoSolicitanteId!.isNotEmpty) {
      params['divisaoSolicitanteId'] = filtro.divisaoSolicitanteId!;
    }
    if (filtro.divisaoDestinoId != null && filtro.divisaoDestinoId!.isNotEmpty) {
      params['divisaoDestinoId'] = filtro.divisaoDestinoId!;
    }
    if (filtro.statuses != null && filtro.statuses!.length == 1) {
      params['status'] = filtro.statuses!.first.dbValue;
    }

    final uri = Uri.parse('$_baseUrl/api/apoios/solicitacoes')
        .replace(queryParameters: params);
    final resp = await _httpClient
        .get(uri, headers: _authHeaders())
        .timeout(const Duration(seconds: 15));
    final body = _decodeOrThrow(resp);
    final list = (body['data'] as List?) ?? const [];
    var items = list
        .whereType<Map<String, dynamic>>()
        .map(TaskApoioSolicitacao.fromJson)
        .toList();

    if (filtro.statuses != null && filtro.statuses!.length > 1) {
      items = items.where((s) => filtro.statuses!.contains(s.status)).toList();
    }
    if (filtro.tipoApoioId != null) {
      items = items.where((s) => s.tipoApoioId == filtro.tipoApoioId).toList();
    }
    if (filtro.prioridade != null) {
      items = items.where((s) => s.prioridade == filtro.prioridade).toList();
    }
    if (filtro.criticidade != null) {
      items = items.where((s) => s.criticidade == filtro.criticidade).toList();
    }
    return items;
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
  Future<List<TaskApoioSolicitacao>> buscarSolicitacoesPorTask(String taskId) {
    return buscarSolicitacoes(
      filtro: TaskApoioFiltro(taskId: taskId, limit: 100),
    );
  }

  @override
  Future<TaskApoioSolicitacao?> buscarSolicitacaoPorId(
    String solicitacaoId,
  ) async {
    final uri = Uri.parse('$_baseUrl/api/apoios/solicitacoes/$solicitacaoId');
    final resp = await _httpClient
        .get(uri, headers: _authHeaders())
        .timeout(const Duration(seconds: 12));
    if (resp.statusCode == 404) return null;
    final body = _decodeOrThrow(resp);
    final data = body['data'];
    if (data is Map<String, dynamic>) {
      return TaskApoioSolicitacao.fromJson(data);
    }
    return null;
  }

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  @override
  Future<TaskApoioSolicitacao> criarSolicitacao(
    TaskApoioSolicitacao solicitacao,
  ) async {
    final uri = Uri.parse('$_baseUrl/api/apoios/solicitacoes');
    final payload = solicitacao.toJson(includeLocalSyncFields: false);
    if (!_uuidRegex.hasMatch(payload['id']?.toString() ?? '')) {
      payload.remove('id');
    }
    final periodos = solicitacao.periodos.map((p) {
      final pj = p.toJson();
      if (!_uuidRegex.hasMatch(pj['id']?.toString() ?? '')) {
        pj.remove('id');
      }
      return pj;
    }).toList();
    final resp = await _httpClient
        .post(
          uri,
          headers: _authHeaders(),
          body: jsonEncode({
            'solicitacao': payload,
            'periodos': periodos,
          }),
        )
        .timeout(const Duration(seconds: 15));
    final body = _decodeOrThrow(resp);
    return TaskApoioSolicitacao.fromJson(
      Map<String, dynamic>.from(body['data'] as Map),
    );
  }

  @override
  Future<TaskApoioSolicitacao> atualizarSolicitacao(
    TaskApoioSolicitacao solicitacao, {
    required String atorUsuarioId,
    String? atorNome,
    String? eventoHistorico,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/apoios/solicitacoes/${solicitacao.id}');
    final payload = solicitacao.toJson(includeLocalSyncFields: false);
    final resp = await _httpClient
        .patch(
          uri,
          headers: _authHeaders(),
          body: jsonEncode({
            'solicitacao': payload,
            'versaoEsperada': solicitacao.versao,
            'observacaoHistorico':
                eventoHistorico ?? solicitacao.justificativaDecisao,
          }),
        )
        .timeout(const Duration(seconds: 15));
    final body = _decodeOrThrow(resp);
    return TaskApoioSolicitacao.fromJson(
      Map<String, dynamic>.from(body['data'] as Map),
    );
  }

  @override
  Future<List<TaskApoioVinculo>> buscarVinculosPorTask(
    String taskId, {
    bool apenasAtivos = true,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/apoios/vinculos/task/$taskId');
    final resp = await _httpClient
        .get(uri, headers: _authHeaders())
        .timeout(const Duration(seconds: 12));
    final body = _decodeOrThrow(resp);
    final list = (body['data'] as List?) ?? const [];
    var items = list
        .whereType<Map<String, dynamic>>()
        .map(TaskApoioVinculo.fromJson)
        .toList();
    if (apenasAtivos) {
      items = items.where((v) => v.ativo).toList();
    }
    return items;
  }

  @override
  Future<List<TaskApoioVinculo>> buscarVinculosPorSolicitacao(
    String solicitacaoId, {
    bool apenasAtivos = true,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/apoios/solicitacoes/$solicitacaoId');
    final resp = await _httpClient
        .get(uri, headers: _authHeaders())
        .timeout(const Duration(seconds: 12));
    if (resp.statusCode == 404) return const [];
    final body = _decodeOrThrow(resp);
    final data = body['data'];
    if (data is! Map<String, dynamic>) return const [];
    final raw = (data['vinculos'] as List?) ?? const [];
    var items = raw
        .whereType<Map<String, dynamic>>()
        .map(TaskApoioVinculo.fromJson)
        .toList();
    if (apenasAtivos) {
      items = items.where((v) => v.ativo).toList();
    }
    return items;
  }

  @override
  Future<TaskApoioVinculo> criarVinculo(
    TaskApoioVinculo vinculo, {
    String? atorNome,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/apoios/vinculos');
    final resp = await _httpClient
        .post(
          uri,
          headers: _authHeaders(),
          body: jsonEncode({
            'vinculo': vinculo.toJson(includeLocalSyncFields: false),
          }),
        )
        .timeout(const Duration(seconds: 15));
    final body = _decodeOrThrow(resp);
    return TaskApoioVinculo.fromJson(
      Map<String, dynamic>.from(body['data'] as Map),
    );
  }

  @override
  Future<TaskApoioVinculo> desativarVinculo({
    required String vinculoId,
    required int versaoEsperada,
    required String atorUsuarioId,
    String? atorNome,
    required String motivo,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/apoios/vinculos/$vinculoId');
    final resp = await _httpClient
        .patch(
          uri,
          headers: _authHeaders(),
          body: jsonEncode({
            'vinculo': {
              'ativo': false,
              'motivo_desativacao': motivo,
              'versao': versaoEsperada,
            },
          }),
        )
        .timeout(const Duration(seconds: 15));
    final body = _decodeOrThrow(resp);
    return TaskApoioVinculo.fromJson(
      Map<String, dynamic>.from(body['data'] as Map),
    );
  }

  @override
  Future<List<TaskApoioHistorico>> buscarHistorico({
    String? solicitacaoId,
    String? vinculoId,
    String? taskId,
  }) async {
    if (solicitacaoId == null || solicitacaoId.isEmpty) {
      return const [];
    }
    final uri = Uri.parse('$_baseUrl/api/apoios/historico/$solicitacaoId');
    final resp = await _httpClient
        .get(uri, headers: _authHeaders())
        .timeout(const Duration(seconds: 12));
    final body = _decodeOrThrow(resp);
    final list = (body['data'] as List?) ?? const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(TaskApoioHistorico.fromJson)
        .toList();
  }

  @override
  Future<Map<String, TaskApoioResumo>> buscarResumosEmLote(
    List<String> taskIds,
  ) async {
    if (taskIds.isEmpty) return const {};
    final uri = Uri.parse('$_baseUrl/api/apoios/resumos').replace(
      queryParameters: {'taskIds': taskIds.toSet().join(',')},
    );
    final resp = await _httpClient
        .get(uri, headers: _authHeaders())
        .timeout(const Duration(seconds: 15));
    final body = _decodeOrThrow(resp);
    final data = Map<String, dynamic>.from((body['data'] as Map?) ?? const {});
    final solsRaw = (data['solicitacoes'] as List?) ?? const [];
    final vinculosComoApoioRaw = (data['vinculosComoApoio'] as List?) ?? const [];

    final solsPorTask = <String, List<Map<String, dynamic>>>{};
    for (final s in solsRaw.whereType<Map<String, dynamic>>()) {
      final tid = s['task_solicitante_id']?.toString();
      if (tid != null) {
        solsPorTask.putIfAbsent(tid, () => []).add(s);
      }
    }

    final apoioCountPorTask = <String, int>{};
    for (final v in vinculosComoApoioRaw.whereType<Map<String, dynamic>>()) {
      final tid = v['task_apoio_id']?.toString();
      if (tid != null) {
        apoioCountPorTask[tid] = (apoioCountPorTask[tid] ?? 0) + 1;
      }
    }

    final result = <String, TaskApoioResumo>{};
    for (final taskId in taskIds.toSet()) {
      final sols = solsPorTask[taskId] ?? const [];
      int aguardando = 0;
      int aceitosSemProg = 0;
      int incompativeis = 0;
      int essenciaisPendentes = 0;
      int recusadas = 0;
      int ativasOuRecusadas = 0;

      for (final s in sols) {
        final status = (s['status']?.toString() ?? '').toUpperCase();
        if (status == 'CANCELADA') continue;
        ativasOuRecusadas++;

        final crit = (s['criticidade']?.toString() ?? '').toUpperCase();
        final sit = s['situacao'] as Map<String, dynamic>?;
        final sitCode = (sit?['situacao_geral']?.toString() ?? '').toUpperCase();

        if (status == 'RECUSADA') {
          recusadas++;
          incompativeis++;
          continue;
        }

        if (status == 'PENDENTE' ||
            status == 'EM_ANALISE' ||
            status == 'CONTRAPROPOSTA') {
          aguardando++;
          if (crit == 'ESSENCIAL') essenciaisPendentes++;
        }
        if (sitCode == 'ACEITO_SEM_PROGRAMACAO') {
          aceitosSemProg++;
          if (crit == 'ESSENCIAL') essenciaisPendentes++;
        } else if (sitCode.contains('INCOMPATIVEL') ||
            sitCode.contains('PARCIAL') ||
            sitCode.contains('RISCO') ||
            sitCode.contains('RECUSAD')) {
          incompativeis++;
        }
      }

      TaskApoioSituacaoGerencial situacaoGerencial =
          TaskApoioSituacaoGerencial.semDependencias;
      if (ativasOuRecusadas > 0) {
        if (incompativeis > 0 || recusadas > 0) {
          situacaoGerencial =
              TaskApoioSituacaoGerencial.programacaoComRiscoApoio;
        } else if (aguardando > 0 && essenciaisPendentes > 0) {
          situacaoGerencial =
              TaskApoioSituacaoGerencial.aguardandoConfirmacaoEssencial;
        } else if (aceitosSemProg > 0) {
          situacaoGerencial =
              TaskApoioSituacaoGerencial.essencialAceitoSemProgramacao;
        } else if (aguardando > 0) {
          situacaoGerencial =
              TaskApoioSituacaoGerencial.apenasComplementares;
        } else {
          situacaoGerencial =
              TaskApoioSituacaoGerencial.essenciaisProgramadosCompativeis;
        }
      }

      result[taskId] = TaskApoioResumo(
        taskId: taskId,
        totalSolicitacoes: sols.length,
        qtdAguardandoResposta: aguardando,
        qtdAceitosSemProgramacao: aceitosSemProg,
        qtdIncompativeis: incompativeis,
        qtdEssenciaisPendentes: essenciaisPendentes,
        qtdAtividadesApoiadas: apoioCountPorTask[taskId] ?? 0,
        situacaoGerencial: situacaoGerencial,
      );
    }
    return result;
  }

  /// Cria uma atividade real na tabela `tasks` e vincula automaticamente
  /// à solicitação de apoio no backend via gateway autenticado.
  Future<Map<String, dynamic>> criarAtividadeDeApoio({
    required String solicitacaoId,
    required String tarefa,
    String? observacoes,
    required DateTime dataInicio,
    required DateTime dataFim,
    String? regionalId,
    String? divisaoId,
    String? segmentoId,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/apoios/atividades-apoio');
    final resp = await _httpClient
        .post(
          uri,
          headers: _authHeaders(),
          body: jsonEncode({
            'solicitacaoId': solicitacaoId,
            'task': {
              'tarefa': tarefa,
              'observacoes': observacoes,
              'data_inicio': dataInicio.toIso8601String(),
              'data_fim': dataFim.toIso8601String(),
              'regional_id': regionalId,
              'divisao_id': divisaoId,
              'segmento_id': segmentoId,
            },
          }),
        )
        .timeout(const Duration(seconds: 15));
    final body = _decodeOrThrow(resp);
    return Map<String, dynamic>.from(body['data'] as Map);
  }

  /// Carrega em lote solicitações e resumo seguro das atividades vinculadas
  /// para o Gantt Integrado (zero N+1).
  Future<Map<String, dynamic>> buscarGanttIntegrado({
    List<String> taskIds = const [],
  }) async {
    final uri = Uri.parse('$_baseUrl/api/apoios/gantt-integrado').replace(
      queryParameters: taskIds.isEmpty
          ? null
          : {'taskIds': taskIds.toSet().take(500).join(',')},
    );
    final resp = await _httpClient
        .get(uri, headers: _authHeaders())
        .timeout(const Duration(seconds: 15));
    final body = _decodeOrThrow(resp);
    return Map<String, dynamic>.from((body['data'] as Map?) ?? const {});
  }

  /// Busca os dados completos (somente leitura) de uma atividade relacionada
  /// a uma solicitação/vínculo de apoio, mesmo que pertença a outra unidade.
  Future<Task?> buscarTaskRelacionadaPorId(String taskId) async {
    if (taskId.isEmpty) return null;
    final uri = Uri.parse('$_baseUrl/api/apoios/tasks/$taskId');
    final resp = await _httpClient
        .get(uri, headers: _authHeaders())
        .timeout(const Duration(seconds: 12));
    if (resp.statusCode == 404 || resp.statusCode == 403) {
      return null;
    }
    final body = _decodeOrThrow(resp);
    final data = body['data'];
    if (data is! Map) return null;
    return TaskService().taskFromGatewayMap(Map<String, dynamic>.from(data));
  }
}
