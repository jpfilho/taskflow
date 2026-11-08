import 'package:flutter/foundation.dart';
import '../../../config/supabase_config.dart';
import '../../../services/auth_service_simples.dart';
import 'models/task_warning.dart';

/// Serviço que busca alertas de tarefas via RPC Supabase (get_task_warnings_for_user).
/// Usa o usuário da tabela [usuarios] (login no Flutter), não Supabase Auth.
class TaskWarningsService {
  static Map<String, List<TaskWarning>>? _cache;
  static String? _cacheUserId;
  static DateTime? _cacheTime;
  static const Duration _cacheTtl = Duration(minutes: 2);

  /// Retorna mapa taskId -> lista de warnings visíveis ao usuário logado.
  /// Usuário = AuthServiceSimples.currentUser (tabela usuarios). Em caso de erro retorna mapa vazio.
  static Future<Map<String, List<TaskWarning>>> getWarningsByTaskId() async {
    try {
      final client = SupabaseConfig.client;
      // Usuário da tabela usuarios (login no Flutter), não Supabase Auth
      final usuario = AuthServiceSimples().currentUser;
      final userId = usuario?.id;
      final idValido = userId != null && userId.trim().isNotEmpty;
      if (!idValido) return {};

      if (_cache != null &&
          _cacheUserId == userId &&
          _cacheTime != null &&
          DateTime.now().difference(_cacheTime!) < _cacheTtl) {
        return _cache!;
      }

      final response = await client.rpc(
        'get_task_warnings_for_user',
        params: {'p_user_id': userId},
      ).timeout(const Duration(seconds: 8));
      if (response == null) return {};
      // RPC que retorna TABLE devolve List. Às vezes vem dentro de chave (ex.: data).
      List<dynamic> list;
      if (response is List) {
        list = response;
      } else if (response is Map && response.containsKey('data')) {
        final data = response['data'];
        list = data is List ? data : [response];
      } else {
        list = [response];
      }
      final map = <String, List<TaskWarning>>{};
      for (final raw in list) {
        if (raw == null) continue;
        final row = raw is Map<String, dynamic>
            ? raw
            : Map<String, dynamic>.from(raw is Map ? raw : <String, dynamic>{});
        final w = TaskWarning.fromMap(row);
        if (w.taskId.isEmpty) continue;
        map.putIfAbsent(w.taskId, () => []).add(w);
      }
      _cache = map;
      _cacheUserId = userId;
      _cacheTime = DateTime.now();
      return map;
    } catch (e) {
      if (kDebugMode) {
        final msg = e.toString();
        if (msg.contains('57014') || msg.contains('statement timeout') || msg.contains('TimeoutException')) {
          debugPrint('ℹ️ TaskWarningsService: RPC get_task_warnings_for_user indisponível/timeout (retornando vazio).');
        } else {
          debugPrint('⚠️ TaskWarningsService.getWarningsByTaskId: $e');
        }
      }
      return _cache ?? {};
    }
  }
}
