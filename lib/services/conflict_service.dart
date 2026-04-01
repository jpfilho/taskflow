import '../config/supabase_config.dart';

/// Informação de conflito para um (executor, dia) vinda do backend.
class ConflictInfo {
  final bool hasConflict;
  final List<String> descriptions;

  const ConflictInfo({
    required this.hasConflict,
    required this.descriptions,
  });
}

/// Serviço que busca detecção de conflitos nas views do Supabase (backend).
///
/// Views utilizadas:
/// - [v_conflict_por_dia_executor]: has_conflict e descriptions por (executor_id, day).
///   Conflito = mais de um local distinto no mesmo (executor_id, dia).
/// - [v_conflict_execution_events]: eventos brutos (executor_id, executor_nome, day, location_key, task_id, description).
///   Usada para tooltip e para resolver nome -> executor_id (evitar misturar executores com mesmo nome).
class ConflictService {
  final _supabase = SupabaseConfig.client;

  /// Normaliza chave do executor para comparação (id ou nome).
  static String normalizeExecutorKey(String s) {
    if (s.isEmpty) return '';
    var t = s.trim().toLowerCase();
    const withDiacritics = 'áàâãäåçéèêëíìîïñóòôõöúùûüýÿ';
    const without = 'aaaaaaceeeeiiiinooooouuuuyy';
    for (var i = 0; i < withDiacritics.length && i < without.length; i++) {
      t = t.replaceAll(withDiacritics[i], without[i]);
    }
    return t.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  /// Carrega conflitos por (executor_id, dia) a partir da view.
  /// Chave do mapa: apenas executor_id + dayKey, para não misturar executores com o mesmo nome.
  Future<Map<String, ConflictInfo>> getConflictsForRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final result = <String, ConflictInfo>{};
    try {
      final start = DateTime(startDate.year, startDate.month, startDate.day).toUtc().toIso8601String().split('T').first;
      final end = DateTime(endDate.year, endDate.month, endDate.day).toUtc().toIso8601String().split('T').first;
      final res = await _supabase
          .from('v_conflict_por_dia_executor')
          .select('executor_id, executor_nome, day, has_conflict, descriptions')
          .gte('day', start)
          .lte('day', end);
      for (final row in res as List) {
        final map = row as Map<String, dynamic>;
        final executorId = map['executor_id']?.toString();
        final dayStr = map['day']?.toString();
        final hasConflict = map['has_conflict'] == true;
        final descList = map['descriptions'];
        final descriptions = descList is List
            ? descList.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList()
            : <String>[];

        if (dayStr == null || executorId == null || executorId.isEmpty) continue;
        DateTime day;
        try {
          day = DateTime.parse(dayStr);
        } catch (_) {
          continue;
        }
        final dayKey = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
        result['${executorId}_$dayKey'] = ConflictInfo(hasConflict: hasConflict, descriptions: descriptions);
      }
    } catch (e) {
      // View pode não existir ou estar indisponível; retorna mapa vazio
      return result;
    }
    return result;
  }

  /// Retorna eventos de execução para um intervalo (para tooltip com excludeTaskId).
  /// Chave do mapa: dayKey (yyyy-MM-dd); valor: lista de eventos naquele dia.
  Future<Map<String, List<ExecutionEventFromBackend>>> getExecutionEventsForRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final result = <String, List<ExecutionEventFromBackend>>{};
    try {
      final start = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
      final end = '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';
      final res = await _supabase
          .from('v_conflict_execution_events')
          .select('executor_id, executor_nome, day, location_key, task_id, description')
          .gte('day', start)
          .lte('day', end);
      for (final row in res as List) {
        final map = row as Map<String, dynamic>;
        final dayStr = map['day']?.toString();
        if (dayStr == null) continue;
        DateTime day;
        try {
          day = DateTime.parse(dayStr);
        } catch (_) {
          continue;
        }
        final event = ExecutionEventFromBackend(
          executorId: map['executor_id']?.toString() ?? '',
          executorNome: map['executor_nome']?.toString() ?? '',
          day: day,
          locationKey: map['location_key']?.toString() ?? '',
          taskId: map['task_id']?.toString() ?? '',
          description: map['description']?.toString() ?? '',
        );
        if (event.taskId.isEmpty) continue;
        final dayKey = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
        result.putIfAbsent(dayKey, () => []).add(event);
      }
    } catch (_) {
      // view pode não existir
    }
    return result;
  }

  /// Verifica se a view de conflitos existe (backend disponível).
  Future<bool> isBackendAvailable() async {
    try {
      await _supabase.from('v_conflict_por_dia_executor').select('day').limit(1);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---------- Conflito de FROTA (views v_conflict_por_dia_frota / v_conflict_execution_events_frota) ----------

  /// Conflitos por (frota_id, dia) para exibição em preto (tela de atividades e tela de frota).
  Future<Map<String, ConflictInfo>> getFleetConflictsForRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final result = <String, ConflictInfo>{};
    try {
      final start = DateTime(startDate.year, startDate.month, startDate.day).toUtc().toIso8601String().split('T').first;
      final end = DateTime(endDate.year, endDate.month, endDate.day).toUtc().toIso8601String().split('T').first;
      final res = await _supabase
          .from('v_conflict_por_dia_frota')
          .select('frota_id, frota_nome, day, has_conflict, descriptions')
          .gte('day', start)
          .lte('day', end);
      for (final row in res as List) {
        final map = row as Map<String, dynamic>;
        final frotaId = map['frota_id']?.toString();
        final dayStr = map['day']?.toString();
        final hasConflict = map['has_conflict'] == true;
        final descList = map['descriptions'];
        final descriptions = descList is List
            ? descList.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList()
            : <String>[];

        if (dayStr == null || frotaId == null || frotaId.isEmpty) continue;
        DateTime day;
        try {
          day = DateTime.parse(dayStr);
        } catch (_) {
          continue;
        }
        final dayKey = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
        result['${frotaId}_$dayKey'] = ConflictInfo(hasConflict: hasConflict, descriptions: descriptions);
      }
    } catch (e) {
      return result;
    }
    return result;
  }

  /// Eventos de execução por frota para tooltip (v_conflict_execution_events_frota).
  Future<Map<String, List<FleetExecutionEventFromBackend>>> getFleetExecutionEventsForRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final result = <String, List<FleetExecutionEventFromBackend>>{};
    try {
      final start = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
      final end = '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';
      final res = await _supabase
          .from('v_conflict_execution_events_frota')
          .select('frota_id, frota_nome, day, location_key, task_id, description')
          .gte('day', start)
          .lte('day', end);
      for (final row in res as List) {
        final map = row as Map<String, dynamic>;
        final dayStr = map['day']?.toString();
        if (dayStr == null) continue;
        DateTime day;
        try {
          day = DateTime.parse(dayStr);
        } catch (_) {
          continue;
        }
        final event = FleetExecutionEventFromBackend(
          frotaId: map['frota_id']?.toString() ?? '',
          frotaNome: map['frota_nome']?.toString() ?? '',
          day: day,
          locationKey: map['location_key']?.toString() ?? '',
          taskId: map['task_id']?.toString() ?? '',
          description: map['description']?.toString() ?? '',
        );
        if (event.taskId.isEmpty) continue;
        final dayKey = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
        result.putIfAbsent(dayKey, () => []).add(event);
      }
    } catch (_) {}
    return result;
  }

  /// Verifica se a view de conflito de frota existe.
  Future<bool> isFleetConflictBackendAvailable() async {
    try {
      await _supabase.from('v_conflict_por_dia_frota').select('day').limit(1);
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Evento de execução retornado pelo backend (um executor em uma tarefa em um local em um dia).
class ExecutionEventFromBackend {
  final String executorId;
  final String executorNome;
  final DateTime day;
  final String locationKey;
  final String taskId;
  final String description;

  const ExecutionEventFromBackend({
    required this.executorId,
    required this.executorNome,
    required this.day,
    required this.locationKey,
    required this.taskId,
    required this.description,
  });
}

/// Evento de execução por frota retornado pelo backend (v_conflict_execution_events_frota).
class FleetExecutionEventFromBackend {
  final String frotaId;
  final String frotaNome;
  final DateTime day;
  final String locationKey;
  final String taskId;
  final String description;

  const FleetExecutionEventFromBackend({
    required this.frotaId,
    required this.frotaNome,
    required this.day,
    required this.locationKey,
    required this.taskId,
    required this.description,
  });
}
