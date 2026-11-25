import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../../config/supabase_config.dart';
import '../../apoios_operacionais/data/services/apoios_auth_session_service.dart';
import '../../apoios_operacionais/domain/repositories/task_apoio_repository.dart';
import '../domain/models/notificacao_interna.dart';

class NotificacoesGatewayService {
  final ApoiosAuthSessionService _sessionService;
  final http.Client _httpClient;
  final String? _baseUrlOverride;

  NotificacoesGatewayService({
    ApoiosAuthSessionService? sessionService,
    http.Client? httpClient,
    String? baseUrlOverride,
  })  : _sessionService = sessionService ?? ApoiosAuthSessionService(),
        _httpClient = httpClient ?? http.Client(),
        _baseUrlOverride = baseUrlOverride;

  String get _baseUrl => _baseUrlOverride ?? SupabaseConfig.apiBaseUrl;

  Map<String, String> _headers() {
    final token = _sessionService.currentToken;
    if (token == null || token.isEmpty || !_sessionService.hasValidToken) {
      throw const TaskApoioAuthRequiredException();
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _decode(http.Response resp) {
    if (resp.statusCode == 401) {
      throw const TaskApoioAuthRequiredException();
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode < 200 || resp.statusCode >= 300 || data['ok'] == false) {
      throw Exception(data['error']?.toString() ?? 'Erro HTTP ${resp.statusCode}');
    }
    return data;
  }

  Future<int> buscarContadorNaoLidas() async {
    final uri = Uri.parse('$_baseUrl/api/apoios/notificacoes/contador');
    final resp = await _httpClient
        .get(uri, headers: _headers())
        .timeout(const Duration(seconds: 10));
    final body = _decode(resp);
    return ((body['data'] as Map?)?['naoLidas'] as num?)?.toInt() ?? 0;
  }

  Future<List<NotificacaoInterna>> listarNotificacoes({
    bool apenasNaoLidas = false,
    String? categoria,
    int limit = 30,
    int offset = 0,
  }) async {
    final params = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
      if (apenasNaoLidas) 'apenasNaoLidas': 'true',
      if (categoria != null && categoria.isNotEmpty) 'categoria': categoria,
    };
    final uri = Uri.parse('$_baseUrl/api/apoios/notificacoes')
        .replace(queryParameters: params);
    final resp = await _httpClient
        .get(uri, headers: _headers())
        .timeout(const Duration(seconds: 12));
    final body = _decode(resp);
    final list = (body['data'] as List?) ?? const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(NotificacaoInterna.fromJson)
        .toList();
  }

  Future<void> marcarComoLida(String notificacaoId) async {
    final uri =
        Uri.parse('$_baseUrl/api/apoios/notificacoes/$notificacaoId/lida');
    final resp = await _httpClient
        .patch(uri, headers: _headers())
        .timeout(const Duration(seconds: 10));
    _decode(resp);
  }

  Future<void> marcarTodasComoLidas() async {
    final uri =
        Uri.parse('$_baseUrl/api/apoios/notificacoes/marcar-todas-lidas');
    final resp = await _httpClient
        .post(uri, headers: _headers())
        .timeout(const Duration(seconds: 10));
    _decode(resp);
  }

  Future<NotificacaoPreferencia> buscarPreferencias() async {
    final uri = Uri.parse('$_baseUrl/api/apoios/preferencias');
    final resp = await _httpClient
        .get(uri, headers: _headers())
        .timeout(const Duration(seconds: 10));
    final body = _decode(resp);
    return NotificacaoPreferencia.fromJson(
      Map<String, dynamic>.from((body['data'] as Map?) ?? const {}),
    );
  }

  Future<NotificacaoPreferencia> salvarPreferencias(
    NotificacaoPreferencia pref,
  ) async {
    final uri = Uri.parse('$_baseUrl/api/apoios/preferencias');
    final resp = await _httpClient
        .put(uri, headers: _headers(), body: jsonEncode(pref.toJson()))
        .timeout(const Duration(seconds: 10));
    final body = _decode(resp);
    return NotificacaoPreferencia.fromJson(
      Map<String, dynamic>.from((body['data'] as Map?) ?? const {}),
    );
  }

  Future<List<ApoioMensagemOperacional>> listarMensagensSolicitacao(
    String solicitacaoId,
  ) async {
    final uri = Uri.parse(
      '$_baseUrl/api/apoios/solicitacoes/$solicitacaoId/mensagens',
    );
    final resp = await _httpClient
        .get(uri, headers: _headers())
        .timeout(const Duration(seconds: 12));
    final body = _decode(resp);
    final list = (body['data'] as List?) ?? const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(ApoioMensagemOperacional.fromJson)
        .toList();
  }

  Future<ApoioMensagemOperacional> enviarMensagemSolicitacao(
    String solicitacaoId,
    String mensagem,
  ) async {
    final uri = Uri.parse(
      '$_baseUrl/api/apoios/solicitacoes/$solicitacaoId/mensagens',
    );
    final resp = await _httpClient
        .post(
          uri,
          headers: _headers(),
          body: jsonEncode({'mensagem': mensagem}),
        )
        .timeout(const Duration(seconds: 12));
    final body = _decode(resp);
    return ApoioMensagemOperacional.fromJson(
      Map<String, dynamic>.from(body['data'] as Map),
    );
  }
}
