import 'package:flutter/foundation.dart';
import '../../../config/supabase_config.dart';
import '../../../services/auth_service_simples.dart';
import 'models/task_warning.dart';

/// Serviço que busca alertas de tarefas via RPC Supabase (get_task_warnings_for_user).
/// Usa o usuário da tabela [usuarios] (login no Flutter), não Supabase Auth.
class TaskWarningsService {
  /// Retorna mapa taskId -> lista de warnings visíveis ao usuário logado.
  /// Usuário = AuthServiceSimples.currentUser (tabela usuarios). Em caso de erro retorna mapa vazio.
  static Future<Map<String, List<TaskWarning>>> getWarningsByTaskId() async {
    const bool debugWarnings = true; // DEBUG: desativar quando estável
    try {
      final client = SupabaseConfig.client;
      // Usuário da tabela usuarios (login no Flutter), não Supabase Auth
      final usuario = AuthServiceSimples().currentUser;
      final userId = usuario?.id;
      final idValido = userId != null && userId.trim().isNotEmpty;
      if (debugWarnings && kDebugMode) {
        debugPrint('[WARNINGS DEBUG] usuario tabela usuarios: id=${userId ?? "null"} (idValido=$idValido)');
      }
      if (!idValido) return {};

      final response = await client.rpc(
        'get_task_warnings_for_user',
        params: {'p_user_id': userId},
      );
      if (debugWarnings && kDebugMode) {
        debugPrint('[WARNINGS DEBUG] RPC response: type=${response.runtimeType} | null=${response == null}');
        final respList = response is List ? response : null;
        if (respList != null) {
          debugPrint('[WARNINGS DEBUG] RPC list length=${respList.length}');
          final first = respList.isNotEmpty ? respList.first : null;
          final firstMap = first is Map ? first : null;
          if (firstMap != null) {
            debugPrint('[WARNINGS DEBUG] Primeira row keys: ${firstMap.keys.join(", ")}');
            if (firstMap.containsKey('task_id')) {
              debugPrint('[WARNINGS DEBUG] task_id sample: ${firstMap['task_id']}');
            }
          }
        } else if (response is Map) {
          debugPrint('[WARNINGS DEBUG] RPC map keys: ${response.keys.join(", ")}');
        }
      }
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
      int skippedEmptyTaskId = 0;
      for (final raw in list) {
        if (raw == null) continue;
        final row = raw is Map<String, dynamic>
            ? raw
            : Map<String, dynamic>.from(raw is Map ? raw : <String, dynamic>{});
        final w = TaskWarning.fromMap(row);
        if (w.taskId.isEmpty) {
          skippedEmptyTaskId++;
          continue;
        }
        map.putIfAbsent(w.taskId, () => []).add(w);
      }
      if (debugWarnings && kDebugMode) {
        final total = map.values.fold<int>(0, (s, l) => s + l.length);
        debugPrint('[WARNINGS DEBUG] Parsed: ${map.length} tarefas, $total alertas | ignorados taskId vazio: $skippedEmptyTaskId');
        if (map.isEmpty) {
          debugPrint('[WARNINGS DEBUG] 💡 RPC get_task_warnings_for_user() filtra por auth: root vê tudo; gerente vê escopo regional/divisão/segmento; outros só tarefas onde é executor ou coordenador. Se o SQL na view base retornou 75 e aqui 0, o usuário logado não tem permissão para esses 75.');
        }
        if (map.isNotEmpty) {
          final sampleIds = map.keys.take(3).toList();
          debugPrint('[WARNINGS DEBUG] task_ids amostra: $sampleIds');
        }
      }
      return map;
    } catch (e, st) {
      if (kDebugMode) {
        final msg = e.toString();
        if (msg.contains('57014') || msg.contains('statement timeout')) {
          debugPrint('⚠️ TaskWarningsService: RPC get_task_warnings_for_user deu timeout. Aplique a migration 20260227 (timeout 60s + índices) no Supabase.');
        } else {
          debugPrint('⚠️ TaskWarningsService.getWarningsByTaskId: $e');
        }
        debugPrint('$st');
      }
      return {};
    }
  }
}
