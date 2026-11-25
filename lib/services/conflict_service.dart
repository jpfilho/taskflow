import '../config/supabase_config.dart';
import 'performance_monitor.dart';

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

  // Cache de disponibilidade
  bool? _isBackendAvailableCache;
  DateTime? _lastAvailabilityCheck;
  bool? _isFleetBackendAvailableCache;
  DateTime? _lastFleetAvailabilityCheck;
  static const _availabilityTtl = Duration(minutes: 5);

  // Cache de resultados de consultas de conflito
  final Map<String, Map<String, ConflictInfo>> _conflictRangeCache = {};
  final Map<String, Map<String, List<ExecutionEventFromBackend>>> _executionEventsCache = {};
  final Map<String, Map<String, ConflictInfo>> _fleetConflictRangeCache = {};
  final Map<String, Map<String, List<FleetExecutionEventFromBackend>>> _fleetExecutionEventsCache = {};
  List<ConflictAcceptance>? _activeAcceptancesCache;
  DateTime? _lastDataCacheTime;
  static const _dataCacheTtl = Duration(minutes: 5);

  void invalidateCache() {
    _conflictRangeCache.clear();
    _executionEventsCache.clear();
    _fleetConflictRangeCache.clear();
    _fleetExecutionEventsCache.clear();
    _activeAcceptancesCache = null;
    _lastDataCacheTime = null;
    _isBackendAvailableCache = null;
    _lastAvailabilityCheck = null;
    _isFleetBackendAvailableCache = null;
    _lastFleetAvailabilityCheck = null;
  }

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
    DateTime endDate, {
    List<String>? executorIds,
  }) async {
    final start = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
    final end = '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';
    final cacheKey = '$start--$end--${executorIds?.join(",") ?? "all"}';

    if (_lastDataCacheTime != null &&
        DateTime.now().difference(_lastDataCacheTime!) < _dataCacheTtl &&
        _conflictRangeCache.containsKey(cacheKey)) {
      return Map<String, ConflictInfo>.from(_conflictRangeCache[cacheKey]!);
    }

    PerformanceMonitor.start('ConflictService.getConflictsForRange');
    final result = <String, ConflictInfo>{};
    try {
      List rawRows = [];
      if (executorIds != null && executorIds.length > 100) {
        final chunks = <List<String>>[];
        for (var i = 0; i < executorIds.length; i += 100) {
          chunks.add(executorIds.sublist(i, i + 100 > executorIds.length ? executorIds.length : i + 100));
        }
        
        final futures = chunks.map((chunk) async {
          final query = _supabase
              .from('v_conflict_por_dia_executor')
              .select('executor_id, day, has_conflict')
              .gte('day', start)
              .lte('day', end)
              .inFilter('executor_id', chunk);
          return await query;
        }).toList();

        final responses = await Future.wait(futures);
        rawRows = responses.expand((r) => r as List).toList();
      } else {
        var query = _supabase
            .from('v_conflict_por_dia_executor')
            .select('executor_id, day, has_conflict')
            .gte('day', start)
            .lte('day', end);
        
        if (executorIds != null && executorIds.isNotEmpty) {
          query = query.inFilter('executor_id', executorIds);
        }
        
        final res = await query;
        rawRows = res as List;
      }
      
      for (final row in rawRows) {
        final map = row as Map<String, dynamic>;
        final executorId = map['executor_id']?.toString();
        final dayStr = map['day']?.toString();
        final hasConflict = map['has_conflict'] == true || map['has_conflict']?.toString() == 'true' || map['has_conflict']?.toString() == 't';
        
        if (dayStr == null || executorId == null || executorId.isEmpty) continue;

        DateTime day;
        try {
          day = DateTime.parse(dayStr);
        } catch (e) {
          continue;
        }
        final dayKey = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
        result['${executorId.toLowerCase()}_$dayKey'] = ConflictInfo(hasConflict: hasConflict, descriptions: []);
      }
      _conflictRangeCache[cacheKey] = Map.from(result);
      _lastDataCacheTime = DateTime.now();
      PerformanceMonitor.stop('ConflictService.getConflictsForRange');
    } catch (e) {
      print('⚠️ [getConflictsForRange] Erro: $e');
      PerformanceMonitor.stop('ConflictService.getConflictsForRange');
    }
    return result;
  }

  /// Retorna eventos de execução para um intervalo (para tooltip com excludeTaskId).
  /// Chave do mapa: dayKey (yyyy-MM-dd); valor: lista de eventos naquele dia.
  Future<Map<String, List<ExecutionEventFromBackend>>> getExecutionEventsForRange(
    DateTime startDate,
    DateTime endDate, {
    List<String>? executorIds,
  }) async {
    final start = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
    final end = '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';
    final cacheKey = '$start--$end--${executorIds?.join(",") ?? "all"}';

    if (_lastDataCacheTime != null &&
        DateTime.now().difference(_lastDataCacheTime!) < _dataCacheTtl &&
        _executionEventsCache.containsKey(cacheKey)) {
      return Map<String, List<ExecutionEventFromBackend>>.from(_executionEventsCache[cacheKey]!);
    }

    PerformanceMonitor.start('ConflictService.getExecutionEventsForRange');
    final result = <String, List<ExecutionEventFromBackend>>{};
    try {
      List rawRows = [];
      if (executorIds != null && executorIds.length > 30) {
        final chunks = <List<String>>[];
        for (var i = 0; i < executorIds.length; i += 30) {
          chunks.add(executorIds.sublist(i, i + 30 > executorIds.length ? executorIds.length : i + 30));
        }

        final futures = chunks.map((chunk) async {
          final query = _supabase
              .from('v_conflict_execution_events')
              .select('executor_id, executor_nome, day, location_key, task_id, description')
              .gte('day', start)
              .lte('day', end)
              .inFilter('executor_id', chunk)
              .limit(5000);
          return await query;
        }).toList();

        final responses = await Future.wait(futures).timeout(const Duration(seconds: 6), onTimeout: () => []);
        rawRows = responses.expand((r) => r as List).toList();
      } else {
        var query = _supabase
            .from('v_conflict_execution_events')
            .select('executor_id, executor_nome, day, location_key, task_id, description')
            .gte('day', start)
            .lte('day', end);
            
        if (executorIds != null && executorIds.isNotEmpty) {
          query = query.inFilter('executor_id', executorIds);
        }
        
        final res = await query.limit(5000).timeout(const Duration(seconds: 6), onTimeout: () => []);
        rawRows = res as List;
      }

      for (final row in rawRows) {
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
      _executionEventsCache[cacheKey] = Map.from(result);
      _lastDataCacheTime = DateTime.now();
      PerformanceMonitor.stop('ConflictService.getExecutionEventsForRange');
    } catch (e) {
      PerformanceMonitor.stop('ConflictService.getExecutionEventsForRange');
    }
    return result;
  }

  /// Verifica se a view de conflitos existe (backend disponível).
  Future<bool> isBackendAvailable() async {
    if (_lastAvailabilityCheck != null && _isBackendAvailableCache != null &&
        DateTime.now().difference(_lastAvailabilityCheck!) < _availabilityTtl) {
      return _isBackendAvailableCache!;
    }
    try {
      await _supabase.from('v_conflict_por_dia_executor').select('day').limit(1);
      _isBackendAvailableCache = true;
      _lastAvailabilityCheck = DateTime.now();
      return true;
    } catch (_) {
      _isBackendAvailableCache = false;
      _lastAvailabilityCheck = DateTime.now();
      return false;
    }
  }

  /// Verifica se a view de conflito de frota existe.
  Future<bool> isFleetConflictBackendAvailable() async {
    if (_lastFleetAvailabilityCheck != null && _isFleetBackendAvailableCache != null &&
        DateTime.now().difference(_lastFleetAvailabilityCheck!) < _availabilityTtl) {
      return _isFleetBackendAvailableCache!;
    }
    try {
      await _supabase.from('v_conflict_por_dia_frota').select('day').limit(1);
      _isFleetBackendAvailableCache = true;
      _lastFleetAvailabilityCheck = DateTime.now();
      return true;
    } catch (_) {
      _isFleetBackendAvailableCache = false;
      _lastFleetAvailabilityCheck = DateTime.now();
      return false;
    }
  }

  // ---------- Conflito de FROTA (views v_conflict_por_dia_frota / v_conflict_execution_events_frota) ----------

  /// Conflitos por (frota_id, dia) para exibição em preto (tela de atividades e tela de frota).
  Future<Map<String, ConflictInfo>> getFleetConflictsForRange(
    DateTime startDate,
    DateTime endDate, {
    List<String>? frotaIds,
  }) async {
    final start = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
    final end = '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';
    final cacheKey = '$start--$end--${frotaIds?.join(",") ?? "all"}';

    if (_lastDataCacheTime != null &&
        DateTime.now().difference(_lastDataCacheTime!) < _dataCacheTtl &&
        _fleetConflictRangeCache.containsKey(cacheKey)) {
      return Map<String, ConflictInfo>.from(_fleetConflictRangeCache[cacheKey]!);
    }

    PerformanceMonitor.start('ConflictService.getFleetConflictsForRange');
    final result = <String, ConflictInfo>{};
    try {
      var query = _supabase
          .from('v_conflict_por_dia_frota')
          .select('frota_id, day, has_conflict')
          .gte('day', start)
          .lte('day', end);
          
      if (frotaIds != null && frotaIds.isNotEmpty) {
        query = query.inFilter('frota_id', frotaIds);
      }
      
      final res = await query;
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
        result['${frotaId}_$dayKey'] = ConflictInfo(hasConflict: hasConflict, descriptions: []);
      }
      _fleetConflictRangeCache[cacheKey] = Map.from(result);
      _lastDataCacheTime = DateTime.now();
      PerformanceMonitor.stop('ConflictService.getFleetConflictsForRange');
    } catch (e) {
      PerformanceMonitor.stop('ConflictService.getFleetConflictsForRange');
      return result;
    }
    return result;
  }

  /// Eventos de execução por frota para tooltip (v_conflict_execution_events_frota).
  Future<Map<String, List<FleetExecutionEventFromBackend>>> getFleetExecutionEventsForRange(
    DateTime startDate,
    DateTime endDate, {
    List<String>? frotaIds,
  }) async {
    final start = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
    final end = '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';
    final cacheKey = '$start--$end--${frotaIds?.join(",") ?? "all"}';

    if (_lastDataCacheTime != null &&
        DateTime.now().difference(_lastDataCacheTime!) < _dataCacheTtl &&
        _fleetExecutionEventsCache.containsKey(cacheKey)) {
      return Map<String, List<FleetExecutionEventFromBackend>>.from(_fleetExecutionEventsCache[cacheKey]!);
    }

    final result = <String, List<FleetExecutionEventFromBackend>>{};
    try {
      var query = _supabase
          .from('v_conflict_execution_events_frota')
          .select('frota_id, frota_nome, day, location_key, task_id, description')
          .gte('day', start)
          .lte('day', end);
          
      if (frotaIds != null && frotaIds.isNotEmpty) {
        query = query.inFilter('frota_id', frotaIds);
      }
      
      final res = await query;
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
      _fleetExecutionEventsCache[cacheKey] = Map.from(result);
      _lastDataCacheTime = DateTime.now();
    } catch (_) {}
    return result;
  }

  // ---------- Aceite de Conflitos (conflict_acceptances) ----------

  /// Busca todos os aceites de conflito ativos (não revogados).
  Future<List<ConflictAcceptance>> getActiveAcceptances({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _activeAcceptancesCache != null &&
        _lastDataCacheTime != null &&
        DateTime.now().difference(_lastDataCacheTime!) < _dataCacheTtl) {
      return List<ConflictAcceptance>.from(_activeAcceptancesCache!);
    }

    try {
      final res = await _supabase
          .from('conflict_acceptances')
          .select('id, resource_type, resource_id, resource_nome, task_id_a, task_id_b, reason, accepted_by, accepted_by_name, accepted_at, revoked_at')
          .isFilter('revoked_at', null)
          .order('accepted_at', ascending: false)
          .timeout(const Duration(seconds: 5), onTimeout: () => []);
      final list = (res as List)
          .map((row) => ConflictAcceptance.fromMap(row as Map<String, dynamic>))
          .toList();
      _activeAcceptancesCache = list;
      _lastDataCacheTime ??= DateTime.now();
      return List<ConflictAcceptance>.from(list);
    } catch (e) {
      // Se a tabela ainda não existir no ambiente, degrada graciosamente
      return _activeAcceptancesCache != null
          ? List<ConflictAcceptance>.from(_activeAcceptancesCache!)
          : [];
    }
  }

  /// Verifica em memória se o par (taskA, taskB) está aceito para [resourceType] + [resourceId].
  static bool isPairAccepted(
    List<ConflictAcceptance> acceptances, {
    required String resourceType,
    required String resourceId,
    required String taskA,
    required String taskB,
  }) {
    if (acceptances.isEmpty || taskA.isEmpty || taskB.isEmpty || taskA == taskB) {
      return false;
    }
    return acceptances.any((a) => a.matches(resourceType, resourceId, taskA, taskB));
  }

  /// Registra aceite(s) de conflito entre pares de tarefas para um executor ou frota.
  Future<List<ConflictAcceptance>> acceptConflictPairs(
    List<ConflictAcceptanceDraft> drafts, {
    String? reason,
    String? acceptedBy,
    String? acceptedByName,
  }) async {
    if (drafts.isEmpty) return [];

    final uniquePayloads = <String, Map<String, dynamic>>{};
    final trimmedReason = reason?.trim();
    for (final d in drafts) {
      if (d.resourceId.trim().isEmpty || d.taskIdA.trim().isEmpty || d.taskIdB.trim().isEmpty) {
        continue;
      }
      if (d.taskIdA.trim() == d.taskIdB.trim()) continue;
      final pair = ConflictAcceptance.canonicalPair(d.taskIdA.trim(), d.taskIdB.trim());
      final type = d.resourceType.toUpperCase();
      final resId = d.resourceId.trim();
      final key = '$type|${resId.toLowerCase()}|${pair.$1}|${pair.$2}';
      uniquePayloads[key] = {
        'resource_type': type,
        'resource_id': resId,
        'resource_nome': d.resourceNome.trim(),
        'task_id_a': pair.$1,
        'task_id_b': pair.$2,
        if (trimmedReason != null && trimmedReason.isNotEmpty) 'reason': trimmedReason,
        if (acceptedBy != null && acceptedBy.trim().isNotEmpty) 'accepted_by': acceptedBy.trim(),
        if (acceptedByName != null && acceptedByName.trim().isNotEmpty) 'accepted_by_name': acceptedByName.trim(),
      };
    }

    if (uniquePayloads.isEmpty) return [];

    final inserted = <ConflictAcceptance>[];
    for (final payload in uniquePayloads.values) {
      try {
        final row = await _supabase
            .from('conflict_acceptances')
            .insert(payload)
            .select()
            .single();
        inserted.add(ConflictAcceptance.fromMap(row));
      } catch (e) {
        final msg = e.toString().toLowerCase();
        // Se já existe aceite ativo para esse par (23505 unique_violation), ignora duplicidade
        if (!msg.contains('23505') && !msg.contains('duplicate')) {
          rethrow;
        }
      }
    }

    invalidateCache();
    return inserted;
  }

  /// Revoga (desfaz) um aceite de conflito existente, reativando a detecção.
  Future<void> revokeAcceptance(String acceptanceId, {String? revokedBy}) async {
    await _supabase
        .from('conflict_acceptances')
        .update({
          'revoked_at': DateTime.now().toUtc().toIso8601String(),
          if (revokedBy != null && revokedBy.trim().isNotEmpty) 'revoked_by': revokedBy.trim(),
        })
        .eq('id', acceptanceId);
    invalidateCache();
  }
}

/// Rascunho para criação de aceite de conflito.
class ConflictAcceptanceDraft {
  final String resourceType; // 'EXECUTOR' | 'FROTA'
  final String resourceId;
  final String resourceNome;
  final String taskIdA;
  final String taskIdB;

  const ConflictAcceptanceDraft({
    required this.resourceType,
    required this.resourceId,
    required this.resourceNome,
    required this.taskIdA,
    required this.taskIdB,
  });
}

/// Aceite persistido de conflito entre um par de tarefas para um executor ou frota.
class ConflictAcceptance {
  final String id;
  final String resourceType; // 'EXECUTOR' | 'FROTA'
  final String resourceId;
  final String resourceNome;
  final String taskIdA;
  final String taskIdB;
  final String? reason;
  final String? acceptedBy;
  final String? acceptedByName;
  final DateTime acceptedAt;
  final DateTime? revokedAt;

  const ConflictAcceptance({
    required this.id,
    required this.resourceType,
    required this.resourceId,
    required this.resourceNome,
    required this.taskIdA,
    required this.taskIdB,
    this.reason,
    this.acceptedBy,
    this.acceptedByName,
    required this.acceptedAt,
    this.revokedAt,
  });

  static (String, String) canonicalPair(String t1, String t2) {
    return t1.compareTo(t2) <= 0 ? (t1, t2) : (t2, t1);
  }

  bool matches(String type, String resId, String t1, String t2) {
    if (revokedAt != null) return false;
    if (resourceType.toUpperCase() != type.toUpperCase()) return false;
    final resNorm = resId.trim().toLowerCase();
    final selfIdNorm = resourceId.trim().toLowerCase();
    final selfNameNorm = ConflictService.normalizeExecutorKey(resourceNome);
    final resKeyNorm = ConflictService.normalizeExecutorKey(resId);
    final sameResource = selfIdNorm == resNorm ||
        (selfNameNorm.isNotEmpty && selfNameNorm == resKeyNorm);
    if (!sameResource) return false;
    final pair = canonicalPair(t1.trim(), t2.trim());
    return taskIdA == pair.$1 && taskIdB == pair.$2;
  }

  factory ConflictAcceptance.fromMap(Map<String, dynamic> map) {
    return ConflictAcceptance(
      id: map['id']?.toString() ?? '',
      resourceType: (map['resource_type']?.toString() ?? 'EXECUTOR').toUpperCase(),
      resourceId: map['resource_id']?.toString() ?? '',
      resourceNome: map['resource_nome']?.toString() ?? '',
      taskIdA: map['task_id_a']?.toString() ?? '',
      taskIdB: map['task_id_b']?.toString() ?? '',
      reason: map['reason']?.toString(),
      acceptedBy: map['accepted_by']?.toString(),
      acceptedByName: map['accepted_by_name']?.toString(),
      acceptedAt: DateTime.tryParse(map['accepted_at']?.toString() ?? '') ?? DateTime.now(),
      revokedAt: map['revoked_at'] != null ? DateTime.tryParse(map['revoked_at'].toString()) : null,
    );
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
