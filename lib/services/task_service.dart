import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/task.dart';
import '../config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service_simples.dart';
import 'local_database_service.dart';
import 'connectivity_service.dart';
import 'sync_service.dart';
import 'tab_sync_service.dart';
import 'package:sqflite/sqflite.dart';

class TaskService {
  /// Resolve o fuso horário forçando que a data vinda do Supabase seja
  /// analisada literalmente na timezone do dispositivo, ignorando deslocamentos UTC.
  DateTime _parseDateInvariant(String dateStr) {
    if (dateStr.isEmpty) return DateTime.now();
    var clean = dateStr;
    if (clean.length >= 19) {
      clean = clean.substring(0, 19);
    } else if (clean.length == 10) {
      clean = clean + 'T00:00:00';
    }
    return DateTime.parse(clean);
  }

  static final TaskService _instance = TaskService._internal();
  factory TaskService() => _instance;
  TaskService._internal();

  final SupabaseClient _supabase = SupabaseConfig.client;
  final LocalDatabaseService _localDb = LocalDatabaseService();
  final ConnectivityService _connectivity = ConnectivityService();
  final SyncService _syncService = SyncService();
  bool _useSupabase = true; // Flag para alternar entre Supabase e mock/offline
  bool _isMockData = false;

  // TTL de cache local para tasks (ajustável conforme necessidade)
  static const Duration _tasksCacheTtl = Duration(minutes: 30);

  // Rastrear último range de datas usado para invalidar cache quando muda
  DateTime? _lastFilterDateStart;
  DateTime? _lastFilterDateEnd;

  List<Task> _tasks = []; // Cache local para fallback
  int _nextId = 1;

  void _logDebug(String message) {
    // Debug antigo desativado (evita poluir console com [LOCAL], [filters/local], URLs longas).
  }

  /// Busca execuções diárias (por executor) usando a MV mv_execucoes_dia
  /// Filtros: executorIds (perfil) e período (startDate/endDate)
  Future<List<Map<String, dynamic>>> getExecucoesDia({
    required List<String> executorIds,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (executorIds.isEmpty) return [];

    try {
      final rawRows = await _supabase
          .from('v_execucoes_dia_completa')
          .select()
          .inFilter('executor_id', executorIds)
          .gte('day', DateTime(startDate.year, startDate.month, startDate.day).toIso8601String())
          .lte('day', DateTime(endDate.year,   endDate.month,   endDate.day  ).toIso8601String());

      return (rawRows as List).cast<Map<String, dynamic>>();
    } catch (e) {
      // Fallback para view materializada se a normal não existir
      _logDebug(
        '⚠️ [getExecucoesDia] View normal não encontrada, tentando view materializada: $e',
      );
      try {
        final rows = await _supabase
            .from('mv_execucoes_dia_completa')
            .select()
            .inFilter('executor_id', executorIds)
            .gte(
              'day',
              DateTime(
                startDate.year,
                startDate.month,
                startDate.day,
              ).toIso8601String(),
            )
            .lte(
              'day',
              DateTime(
                endDate.year,
                endDate.month,
                endDate.day,
              ).toIso8601String(),
            );

        return (rows as List).map((e) => e as Map<String, dynamic>).toList();
      } catch (e2) {
        // Fallback para view antiga se a nova não existir
        _logDebug(
          '⚠️ [getExecucoesDia] View materializada não encontrada, usando view antiga: $e2',
        );
        try {
          final rows = await _supabase
              .from('mv_execucoes_dia')
              .select()
              .inFilter('executor_id', executorIds)
              .gte(
                'day',
                DateTime(
                  startDate.year,
                  startDate.month,
                  startDate.day,
                ).toIso8601String(),
              )
              .lte(
                'day',
                DateTime(
                  endDate.year,
                  endDate.month,
                  endDate.day,
                ).toIso8601String(),
              );

          // Adicionar tipo_periodo padrão para view antiga
          return (rows as List).map((e) {
            final map = e as Map<String, dynamic>;
            // View antiga só tem EXECUCAO, então adicionar campo padrão
            if (!map.containsKey('tipo_periodo')) {
              map['tipo_periodo'] = 'EXECUCAO';
            }
            return map;
          }).toList();
        } catch (e3) {
          _logDebug('⚠️ [getExecucoesDia] Erro ao buscar view antiga: $e3');
          return [];
        }
      }
    }
  }

  /// Busca execuções diárias (por frota) usando a view v_execucoes_dia_frota.
  /// Exclui tarefas com status CANC e REPR (a view já filtra).
  /// Filtros: frotaIds (perfil) e período (startDate/endDate).
  Future<List<Map<String, dynamic>>> getExecucoesDiaFrota({
    required List<String> frotaIds,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (frotaIds.isEmpty) return [];

    try {
      final rows = await _supabase
          .from('v_execucoes_dia_frota')
          .select()
          .inFilter('frota_id', frotaIds)
          .gte(
            'day',
            DateTime(
              startDate.year,
              startDate.month,
              startDate.day,
            ).toIso8601String(),
          )
          .lte(
            'day',
            DateTime(
              endDate.year,
              endDate.month,
              endDate.day,
            ).toIso8601String(),
          );

      return (rows as List).map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      _logDebug('⚠️ [getExecucoesDiaFrota] View não encontrada ou erro: $e');
      return [];
    }
  }

  /// Retorna, por task_id, quantidades de notas/ordens/ATs NÃO encerrados
  /// (status do sistema sem ENTE, ENCE ou MSEN). Usado para colorir ícones:
  /// vermelho se algum não encerrado, verde se todos encerrados.
  Future<
    ({
      Map<String, int> notasNaoEncerradas,
      Map<String, int> ordensNaoEncerradas,
      Map<String, int> atsNaoEncerradas,
    })
  >
  getEncerramentoSapPorTarefas(List<String> taskIds) async {
    final empty = (
      notasNaoEncerradas: <String, int>{},
      ordensNaoEncerradas: <String, int>{},
      atsNaoEncerradas: <String, int>{},
    );
    if (taskIds.isEmpty) return empty;
    try {
      dynamic query = _supabase
          .from('tasks_encerramento_sap')
          .select(
            'task_id, qtd_notas_nao_encerradas, qtd_ordens_nao_encerradas, qtd_ats_nao_encerradas',
          );
      if (taskIds.length == 1) {
        query = query.eq('task_id', taskIds[0]);
      } else {
        query = query.inFilter('task_id', taskIds);
      }
      final response = await query as List;
      final notas = <String, int>{};
      final ordens = <String, int>{};
      final ats = <String, int>{};
      for (final item in response) {
        final map = item as Map<String, dynamic>;
        final taskId = map['task_id'] as String?;
        if (taskId == null) continue;
        final n = (map['qtd_notas_nao_encerradas'] as num?)?.toInt() ?? 0;
        final o = (map['qtd_ordens_nao_encerradas'] as num?)?.toInt() ?? 0;
        final a = (map['qtd_ats_nao_encerradas'] as num?)?.toInt() ?? 0;
        if (n > 0) notas[taskId] = n;
        if (o > 0) ordens[taskId] = o;
        if (a > 0) ats[taskId] = a;
      }
      return (
        notasNaoEncerradas: notas,
        ordensNaoEncerradas: ordens,
        atsNaoEncerradas: ats,
      );
    } catch (e) {
      _logDebug(
        '⚠️ [getEncerramentoSapPorTarefas] View não encontrada ou erro: $e',
      );
      return empty;
    }
  }

  // ------- Batch helpers para otimizar filtros/Gantt -------

  static const int _ganttSegmentsChunkSize = 40;

  Future<Map<String, List<GanttSegment>>> _loadGanttSegmentsBatch(
    List<String> taskIds, {
    DateTime? dataInicioMin,
    DateTime? dataFimMax,
    int? limitPerTask,
  }) async {
    if (taskIds.isEmpty) return {};
    final map = <String, List<GanttSegment>>{};
    try {
      // Evitar URL longa demais (Failed to fetch): fazer várias requisições com poucos IDs
      for (var i = 0; i < taskIds.length; i += _ganttSegmentsChunkSize) {
        final chunk = taskIds.skip(i).take(_ganttSegmentsChunkSize).toList();
        var query = _supabase
            .from('gantt_segments')
            .select()
            .filter('task_id', 'in', chunk);
        if (dataFimMax != null) {
          query = query.lte('data_inicio', dataFimMax.toIso8601String());
        }
        if (dataInicioMin != null) {
          query = query.gte('data_fim', dataInicioMin.toIso8601String());
        }
        final rows = await query;
        for (final row in rows as List) {
          final taskId = row['task_id'] as String?;
          if (taskId == null) continue;
          final seg = GanttSegment(
            dataInicio: _parseDateInvariant(row['data_inicio'] as String),
            dataFim: _parseDateInvariant(row['data_fim'] as String),
            label: row['label']?.toString() ?? '',
            tipo: row['tipo']?.toString() ?? 'OUT',
            tipoPeriodo: row['tipo_periodo']?.toString() ?? 'EXECUCAO',
          );
          map.putIfAbsent(taskId, () => []).add(seg);
        }
      }
      if (limitPerTask != null && limitPerTask > 0) {
        for (final entry in map.entries) {
          if (entry.value.length > limitPerTask) {
            map[entry.key] = entry.value.take(limitPerTask).toList();
          }
        }
      }
      return map;
    } catch (e) {
      _logDebug('⚠️ [_loadGanttSegmentsBatch] Erro: $e');
      return map;
    }
  }

  Future<Map<String, List<ExecutorPeriod>>> _loadExecutorPeriodsBatch(
    List<String> taskIds,
  ) async {
    if (taskIds.isEmpty) return {};
    final taskExecutorMap = <String, Map<String, ExecutorPeriod>>{};
    try {
      for (var i = 0; i < taskIds.length; i += _ganttSegmentsChunkSize) {
        final chunk = taskIds.skip(i).take(_ganttSegmentsChunkSize).toList();
        final rows = await _supabase
            .from('executor_periods')
            .select()
            .filter('task_id', 'in', chunk);

        for (final row in rows as List) {
          try {
            final taskId = row['task_id']?.toString();
            final executorId = row['executor_id']?.toString();
            if (taskId == null || executorId == null) continue;

            // Campos críticos obrigatórios
            final executorNome = row['executor_nome']?.toString() ?? '';
            final dataInicio = row['data_inicio'];
            final dataFim = row['data_fim'];
            if (dataInicio == null || dataFim == null) continue;

            final segment = _segmentFromMap(row as Map<String, dynamic>);

            final byExecutor = taskExecutorMap.putIfAbsent(
              taskId,
              () => <String, ExecutorPeriod>{},
            );

            if (byExecutor.containsKey(executorId)) {
              final existing = byExecutor[executorId]!;
              byExecutor[executorId] = existing.copyWith(
                periods: [...existing.periods, segment],
              );
            } else {
              byExecutor[executorId] = ExecutorPeriod(
                executorId: executorId,
                executorNome: executorNome,
                periods: [segment],
              );
            }
          } catch (e) {
            _logDebug('⚠️ [_loadExecutorPeriodsBatch] Linha ignorada: $e');
          }
        }
      }

      // Converter para o formato esperado: taskId -> lista de ExecutorPeriod
      final result = <String, List<ExecutorPeriod>>{};
      for (final entry in taskExecutorMap.entries) {
        result[entry.key] = entry.value.values.toList();
      }
      return result;
    } catch (e) {
      _logDebug('⚠️ [_loadExecutorPeriodsBatch] Erro: $e');
      return {};
    }
  }

  /// Preenche task.locais sempre que estiver vazio: por localIds na tarefa ou buscando em tasks_locais.
  /// Assim a coluna LOCAL aparece mesmo após aplicar filtros (quando o join não retorna tasks_locais).
  Future<List<Task>> _enrichTasksLocaisFromIds(List<Task> tasks) async {
    final needLocais = tasks.where((t) => t.locais.isEmpty).toList();
    if (needLocais.isEmpty) return tasks;

    if (kDebugMode) {
      final comLocalIds = needLocais.where((t) => t.localIds.isNotEmpty).length;
      _logDebug(
        '[LOCAL] _enrichTasksLocaisFromIds: ${needLocais.length} tarefas sem locais ($comLocalIds já têm localIds)',
      );
    }

    // task_id -> lista de local_id (preencher para quem não tem localIds)
    final taskIdToLocalIds = <String, List<String>>{};
    final taskIdsSemLocalIds = needLocais
        .where((t) => t.localIds.isEmpty)
        .map((t) => t.id)
        .toSet()
        .toList();

    if (taskIdsSemLocalIds.isNotEmpty) {
      try {
        final tl = await _supabase
            .from('tasks_locais')
            .select('task_id, local_id')
            .inFilter('task_id', taskIdsSemLocalIds);
        for (final row in tl) {
          final taskId = row['task_id']?.toString();
          final localId = row['local_id']?.toString();
          if (taskId != null && localId != null) {
            taskIdToLocalIds.putIfAbsent(taskId, () => []).add(localId);
          }
        }
        if (kDebugMode) {
          _logDebug(
            '[LOCAL] tasks_locais retornou ${taskIdToLocalIds.length} tarefas com vínculos (${taskIdsSemLocalIds.length} consultadas)',
          );
        }
      } catch (e) {
        _logDebug('⚠️ [_enrichTasksLocaisFromIds] tasks_locais: $e');
      }
    }

    // Montar conjunto de todos os local_ids para buscar nomes
    final allIds = <String>{};
    for (final t in needLocais) {
      if (t.localIds.isNotEmpty) {
        allIds.addAll(t.localIds);
      } else {
        allIds.addAll(taskIdToLocalIds[t.id] ?? []);
      }
    }
    if (allIds.isEmpty) {
      if (kDebugMode) {
        _logDebug(
          '[LOCAL] _enrichTasksLocaisFromIds: nenhum local_id encontrado (nem na tarefa nem em tasks_locais)',
        );
      }
      return tasks;
    }

    try {
      final res = await _supabase
          .from('locais')
          .select('id, local')
          .inFilter('id', allIds.toList());
      if (res.isEmpty) {
        if (kDebugMode) {
          _logDebug('[LOCAL] locais table retornou vazio ou inválido');
        }
        return tasks;
      }
      final idToName = <String, String>{};
      for (final r in res as List) {
        final map = r as Map<String, dynamic>;
        final id = map['id']?.toString();
        final name = map['local']?.toString();
        if (id != null && name != null) idToName[id] = name;
      }
      if (idToName.isEmpty) {
        if (kDebugMode) {
          _logDebug(
            '[LOCAL] nenhum nome encontrado em locais para ids=${allIds.take(5).toList()}...',
          );
        }
        return tasks;
      }

      var enriched = 0;
      final out = tasks.map((t) {
        if (t.locais.isNotEmpty) return t;
        List<String> ids = t.localIds;
        if (ids.isEmpty) ids = taskIdToLocalIds[t.id] ?? [];
        if (ids.isEmpty) return t;
        final names = ids
            .map((id) => idToName[id])
            .whereType<String>()
            .toList();
        if (names.isNotEmpty) enriched++;
        return t.copyWith(locais: names, localIds: ids);
      }).toList();
      if (kDebugMode) {
        _logDebug(
          '[LOCAL] _enrichTasksLocaisFromIds: preencheu locais em $enriched tarefas',
        );
      }
      return out;
    } catch (e) {
      _logDebug('⚠️ [_enrichTasksLocaisFromIds] locais: $e');
      return tasks;
    }
  }

  // Carregar períodos específicos por frota em BATCH (otimizado)
  Future<Map<String, List<FrotaPeriod>>> _loadFrotaPeriodsBatch(
    List<String> taskIds,
  ) async {
    if (taskIds.isEmpty) return {};
    if (!_useSupabase) return {};

    try {
      // Agrupa por tarefa e por frota, acumulando segmentos
      final taskFrotaMap = <String, Map<String, FrotaPeriod>>{};

      for (var i = 0; i < taskIds.length; i += _ganttSegmentsChunkSize) {
        final chunk = taskIds.skip(i).take(_ganttSegmentsChunkSize).toList();
        final rows = await _supabase
            .from('frota_periods')
            .select()
            .filter('task_id', 'in', chunk)
            .order('frota_nome', ascending: true)
            .order('data_inicio', ascending: true);

        for (final row in rows as List) {
          try {
            final taskId = row['task_id']?.toString();
            final frotaId = row['frota_id']?.toString();
            if (taskId == null || frotaId == null) continue;

            final frotaNome = row['frota_nome']?.toString() ?? '';
            final segment = _segmentFromMap(row as Map<String, dynamic>);

            final byFrota = taskFrotaMap.putIfAbsent(
              taskId,
              () => <String, FrotaPeriod>{},
            );

            if (byFrota.containsKey(frotaId)) {
              final existing = byFrota[frotaId]!;
              byFrota[frotaId] = existing.copyWith(
                periods: [...existing.periods, segment],
              );
            } else {
              byFrota[frotaId] = FrotaPeriod(
                frotaId: frotaId,
                frotaNome: frotaNome,
                periods: [segment],
              );
            }
          } catch (e) {
            _logDebug('⚠️ [_loadFrotaPeriodsBatch] Linha ignorada: $e');
          }
        }
      }

      // Converter para o formato esperado: taskId -> lista de FrotaPeriod
      final result = <String, List<FrotaPeriod>>{};
      for (final entry in taskFrotaMap.entries) {
        result[entry.key] = entry.value.values.toList();
      }
      return result;
    } catch (e) {
      _logDebug('⚠️ [_loadFrotaPeriodsBatch] Erro: $e');
      return {};
    }
  }

  // Inicializar com dados mock (fallback)
  void initializeWithMockData(List<Task> mockTasks) {
    _tasks = mockTasks.map((task) {
      if (task.id.isEmpty) {
        return task.copyWith(id: 'TASK_${_nextId++}');
      }
      return task;
    }).toList();
    _nextId = _tasks.length + 1;
    _useSupabase = false; // Usar mock quando inicializado com dados mock
    _isMockData = true;
  }

  // Converter Map do Supabase para Task
  Task _taskFromMap(Map<String, dynamic> map) {
    // Normalizar datas ao carregar do Supabase (remover hora/timezone)
    final dataInicioParsed = _parseDateInvariant(map['data_inicio'] as String);
    final dataFimParsed = _parseDateInvariant(map['data_fim'] as String);

    final dataInicio = DateTime(
      dataInicioParsed.year,
      dataInicioParsed.month,
      dataInicioParsed.day,
    );
    final dataFim = DateTime(
      dataFimParsed.year,
      dataFimParsed.month,
      dataFimParsed.day,
    );

    // Extrair dados dos joins (pode ser Map ou já processado)
    final statusData = map['status'];
    final regionalData = map['regionais'];
    final divisaoData = map['divisoes'];
    final segmentoData = map['segmentos'];
    // PostgREST retorna 'tasks_locais'; alguns clientes podem usar camelCase
    final tasksLocaisData = map['tasks_locais'] ?? map['tasksLocais'];
    final tasksExecutoresData = map['tasks_executores'];
    final tasksEquipesData = map['tasks_equipes'];
    final tasksFrotasData = map['tasks_frotas'];

    Map<String, dynamic>? statusMap;
    Map<String, dynamic>? regionalMap;
    Map<String, dynamic>? divisaoMap;
    Map<String, dynamic>? segmentoMap;

    if (statusData is Map) {
      statusMap = statusData as Map<String, dynamic>;
    }
    if (regionalData is Map) {
      regionalMap = regionalData as Map<String, dynamic>;
    }
    if (divisaoData is Map) {
      divisaoMap = divisaoData as Map<String, dynamic>;
    }
    if (segmentoData is Map) {
      segmentoMap = segmentoData as Map<String, dynamic>;
    }

    // Extrair múltiplos locais (aceitar List, Map único ou item com "local" direto)
    List<String> localIds = [];
    List<String> locais = [];
    if (tasksLocaisData is List) {
      for (var item in tasksLocaisData) {
        if (item is! Map<String, dynamic>) continue;
        final itemMap = item;
        final localMap = itemMap['locais'] as Map<String, dynamic>?;
        final localId =
            localMap?['id'] as String? ?? itemMap['local_id'] as String?;
        final localNome =
            localMap?['local'] as String? ?? itemMap['local'] as String?;
        if (localId != null && localId.toString().isNotEmpty) {
          localIds.add(localId.toString());
          if (localNome != null && localNome.toString().isNotEmpty) {
            locais.add(localNome.toString());
          }
        }
      }
    } else if (tasksLocaisData is Map<String, dynamic>) {
      final single = tasksLocaisData;
      final localMap = single['locais'] as Map<String, dynamic>?;
      final localId =
          localMap?['id'] as String? ?? single['local_id'] as String?;
      final localNome =
          localMap?['local'] as String? ?? single['local'] as String?;
      if (localId != null && localId.toString().isNotEmpty) {
        localIds.add(localId.toString());
        if (localNome != null && localNome.toString().isNotEmpty) {
          locais.add(localNome.toString());
        }
      }
    }

    // Coluna tasks.local (varchar): mesmo nível que tipo — sempre em select *; usar quando embed não preencheu
    if (locais.isEmpty) {
      final taskLocalColumn = map['local'];
      if (taskLocalColumn != null &&
          taskLocalColumn.toString().trim().isNotEmpty) {
        locais = taskLocalColumn
            .toString()
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    }

    // Extrair múltiplos executores
    List<String> executorIds = [];
    List<String> executores = [];
    if (tasksExecutoresData is List) {
      for (var item in tasksExecutoresData) {
        if (item is Map<String, dynamic> && item['executores'] != null) {
          final executorMap = item['executores'] as Map<String, dynamic>;
          final executorId = executorMap['id'] as String?;
          // Usar apenas o nome, não o nome_completo
          final executorNome = executorMap['nome'] as String?;
          if (executorId != null) {
            executorIds.add(executorId);
            if (executorNome != null && executorNome.isNotEmpty) {
              executores.add(executorNome); // Salvar apenas o nome
            }
          }
        }
      }
    }

    // Extrair múltiplas equipes
    List<String> equipeIds = [];
    List<String> equipes = [];
    List<EquipeExecutorInfo>? equipeExecutoresList;
    if (tasksEquipesData is List) {
      equipeExecutoresList = [];
      for (var item in tasksEquipesData) {
        if (item is Map<String, dynamic> && item['equipes'] != null) {
          final equipeMap = item['equipes'] as Map<String, dynamic>;
          final equipeId = equipeMap['id'] as String?;
          final equipeNome = equipeMap['nome'] as String?;
          if (equipeId != null) {
            equipeIds.add(equipeId);
            if (equipeNome != null) {
              equipes.add(equipeNome);
            }
          }

          // Extrair executores da equipe
          if (equipeMap['equipes_executores'] != null) {
            final executoresData = equipeMap['equipes_executores'];
            if (executoresData is List) {
              for (var execItem in executoresData) {
                if (execItem is Map<String, dynamic>) {
                  final executoresMap = execItem['executores'];
                  String executorNome = '';
                  if (executoresMap is Map<String, dynamic>) {
                    executorNome = executoresMap['nome'] as String? ?? '';
                  }
                  equipeExecutoresList.add(
                    EquipeExecutorInfo(
                      executorNome: executorNome,
                      papel: execItem['papel'] as String? ?? 'EXECUTOR',
                    ),
                  );
                }
              }
            }
          }
        }
      }
      if (equipeExecutoresList.isEmpty) {
        equipeExecutoresList = null;
      }
    }

    // Extrair múltiplas frotas
    List<String> frotaIds = [];
    List<String> frotas = [];
    if (tasksFrotasData is List) {
      for (var item in tasksFrotasData) {
        if (item is Map<String, dynamic> && item['frota'] != null) {
          final frotaMap = item['frota'] as Map<String, dynamic>;
          final frotaId = frotaMap['id'] as String?;
          final frotaNome = frotaMap['nome'] as String?;
          final frotaPlaca = frotaMap['placa'] as String?;
          final frotaMarca = frotaMap['marca'] as String?;
          if (frotaId != null) {
            frotaIds.add(frotaId);
            if (frotaNome != null && frotaPlaca != null) {
              final modelo =
                  (frotaMarca != null &&
                      frotaMarca.toString().trim().isNotEmpty)
                  ? ' - ${frotaMarca.toString().trim()}'
                  : '';
              frotas.add('$frotaNome - $frotaPlaca$modelo');
            } else if (frotaNome != null) {
              frotas.add(frotaNome);
            }
          }
        }
      }
    }

    // Compatibilidade: se não houver dados nas tabelas de junção, usar campos antigos
    final localData = map['locais'];
    final equipeData = map['equipes'];
    Map<String, dynamic>? localMap;
    Map<String, dynamic>? equipeMap;

    if (localData is Map && localIds.isEmpty) {
      localMap = localData as Map<String, dynamic>;
      final oldLocalId = map['local_id'] as String?;
      final oldLocalNome = localMap['local'] as String?;
      if (oldLocalId != null) {
        localIds = [oldLocalId];
        if (oldLocalNome != null) {
          locais = [oldLocalNome];
        }
      }
    }

    if (equipeData is Map && equipeIds.isEmpty) {
      equipeMap = equipeData as Map<String, dynamic>;
      final oldEquipeId = map['equipe_id'] as String?;
      final oldEquipeNome = equipeMap['nome'] as String?;
      if (oldEquipeId != null) {
        equipeIds = [oldEquipeId];
        if (oldEquipeNome != null) {
          equipes = [oldEquipeNome];
        }
      }

      // Extrair executores da equipe (compatibilidade)
      if (equipeMap['equipes_executores'] != null &&
          equipeExecutoresList == null) {
        final executoresData = equipeMap['equipes_executores'];
        equipeExecutoresList = [];

        if (executoresData is List) {
          for (var execItem in executoresData) {
            if (execItem is Map<String, dynamic>) {
              final executoresMap = execItem['executores'];
              String executorNome = '';
              if (executoresMap is Map<String, dynamic>) {
                executorNome = executoresMap['nome'] as String? ?? '';
              }
              equipeExecutoresList.add(
                EquipeExecutorInfo(
                  executorNome: executorNome,
                  papel: execItem['papel'] as String? ?? 'EXECUTOR',
                ),
              );
            }
          }
        } else if (executoresData is Map<String, dynamic>) {
          final executoresMap = executoresData['executores'];
          String executorNome = '';
          if (executoresMap is Map<String, dynamic>) {
            executorNome = executoresMap['nome'] as String? ?? '';
          }
          equipeExecutoresList.add(
            EquipeExecutorInfo(
              executorNome: executorNome,
              papel: executoresData['papel'] as String? ?? 'EXECUTOR',
            ),
          );
        }
        if (equipeExecutoresList.isEmpty) {
          equipeExecutoresList = null;
        }
      }
    }

    // Compatibilidade: se não houver locais na lista, usar campo antigo (join) ou coluna da tabela tasks
    if (locais.isEmpty && localMap != null) {
      final oldLocalNome = localMap['local'] as String?;
      if (oldLocalNome != null) {
        locais = [oldLocalNome];
      }
    }
    if (localIds.isEmpty) {
      final oldLocalId = map['local_id'] as String?;
      if (oldLocalId != null) {
        localIds = [oldLocalId];
      }
    }
    // Reaplicar coluna tasks.local se ainda vazio (redundante com bloco acima; mantido como fallback)
    if (locais.isEmpty) {
      final v = map['local'];
      if (v != null && v.toString().trim().isNotEmpty) {
        locais = v
            .toString()
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    }

    // DEBUG LOCAL: entender por que locais fica vazio (remover após resolver)
    if (kDebugMode && locais.isEmpty) {
      final taskId = map['id']?.toString() ?? '?';
      final hasLocalKey = map.containsKey('local');
      final localValue = map['local'];
      final tasksLocaisType = tasksLocaisData == null
          ? 'null'
          : tasksLocaisData.runtimeType.toString();
      final tasksLocaisLength = tasksLocaisData is List
          ? (tasksLocaisData).length
          : (tasksLocaisData is Map ? 1 : 0);
      _logDebug(
        '[LOCAL] taskId=$taskId locais=vazio | map.local existe=$hasLocalKey valor=$localValue tipo=${localValue.runtimeType} | tasks_locais=$tasksLocaisType len=$tasksLocaisLength | local_id=${map['local_id']}',
      );
    }

    // Compatibilidade: se não houver executores na lista, usar campo antigo
    if (executores.isEmpty) {
      final oldExecutor = map['executor'] as String?;
      if (oldExecutor != null && oldExecutor.isNotEmpty) {
        executores = [oldExecutor];
      }
    }

    // Compatibilidade: se não houver equipes na lista, usar campo antigo
    if (equipes.isEmpty && equipeMap != null) {
      final oldEquipeNome = equipeMap['nome'] as String?;
      if (oldEquipeNome != null) {
        equipes = [oldEquipeNome];
      }
    }
    if (equipeIds.isEmpty) {
      final oldEquipeId = map['equipe_id'] as String?;
      if (oldEquipeId != null) {
        equipeIds = [oldEquipeId];
      }
    }

    // Compatibilidade: se não houver frotas na lista, usar campo antigo
    if (frotas.isEmpty) {
      final oldFrota = map['frota'] as String?;
      if (oldFrota != null && oldFrota.isNotEmpty && oldFrota != '-N/A-') {
        frotas = [oldFrota];
      }
    }

    // Usar dados dos joins se disponíveis, senão usar campos antigos (compatibilidade)
    final statusCodigo =
        statusMap?['codigo'] as String? ?? map['status'] as String? ?? '';
    final statusNome = statusMap?['status'] as String? ?? '';
    final regionalNome =
        regionalMap?['regional'] as String? ?? map['regional'] as String? ?? '';
    final divisaoNome =
        divisaoMap?['divisao'] as String? ?? map['divisao'] as String? ?? '';
    final segmentoNome = segmentoMap?['segmento'] as String? ?? '';

    return Task(
      id: map['id'] as String,
      statusId: map['status_id'] as String?,
      regionalId: map['regional_id'] as String?,
      divisaoId: map['divisao_id'] as String?,
      segmentoId: map['segmento_id'] as String?,
      localIds: localIds,
      executorIds: executorIds,
      equipeIds: equipeIds,
      frotaIds: frotaIds,
      localId: map['local_id'] as String?, // Deprecated
      equipeId: map['equipe_id'] as String?, // Deprecated
      status: statusCodigo,
      statusNome: statusNome,
      regional: regionalNome,
      divisao: divisaoNome,
      locais: locais,
      segmento: segmentoNome,
      equipes: equipes,
      equipeExecutores: equipeExecutoresList,
      tipo: map['tipo'] as String,
      ordem: map['ordem'] as String?,
      tarefa: map['tarefa'] as String,
      executores: executores,
      executor: map['executor'] as String? ?? '', // Deprecated
      frota: frotas.isNotEmpty
          ? frotas.join(', ')
          : (map['frota'] as String? ??
                ''), // Compatibilidade: usar lista ou campo antigo
      coordenador: map['coordenador'] as String,
      si: map['si'] as String? ?? '',
      precisaSi: map['precisa_si'] == true,
      dataInicio: dataInicio,
      dataFim: dataFim,
      observacoes: map['observacoes'] as String?,
      horasPrevistas: map['horas_previstas'] != null
          ? (map['horas_previstas'] as num).toDouble()
          : null,
      horasExecutadas: map['horas_executadas'] != null
          ? (map['horas_executadas'] as num).toDouble()
          : null,
      prioridade: map['prioridade'] as String?,
      dataCriacao: map['data_criacao'] != null
          ? _parseDateInvariant(map['data_criacao'] as String)
          : null,
      dataAtualizacao: map['data_atualizacao'] != null
          ? _parseDateInvariant(map['data_atualizacao'] as String)
          : null,
      parentId: map['parent_id'] as String?,
      ganttSegments: [], // Será carregado separadamente
      executorPeriods: [], // Será carregado separadamente
    );
  }

  // Converter Task para Map do Supabase
  Map<String, dynamic> _taskToMap(Task task) {
    final map = <String, dynamic>{
      'id': task.id,
      'tipo': task.tipo,
      'ordem': task.ordem,
      'tarefa': task.tarefa,
      'executor': task.executor,
      'frota': task.frota,
      'coordenador': task.coordenador,
      'si': task.si,
      'precisa_si': task.precisaSi,
      'data_inicio': task.dataInicio.toIso8601String(),
      'data_fim': task.dataFim.toIso8601String(),
      'observacoes': task.observacoes,
      'horas_previstas': task.horasPrevistas,
      'horas_executadas': task.horasExecutadas,
      'prioridade': task.prioridade,
      'data_criacao': task.dataCriacao?.toIso8601String(),
      'data_atualizacao': task.dataAtualizacao?.toIso8601String(),
      'parent_id': task.parentId,
      'status_id': task.statusId,
      'regional_id': task.regionalId,
      'divisao_id': task.divisaoId,
      'segmento_id': task.segmentoId,
      // Não salvar local_id e equipe_id diretamente se houver localIds/equipeIds (usar tabelas de junção)
      'local_id': task.localIds.isEmpty ? task.localId : null,
      'equipe_id': task.equipeIds.isEmpty ? task.equipeId : null,
    };

    // SEMPRE salvar os campos obrigatórios (string) para compatibilidade com constraints NOT NULL
    // Esses campos são obrigatórios na tabela, mesmo quando temos os IDs
    // Garantir que o status está na lista de valores permitidos pela constraint CHECK
    // Inclui RPGR (Reprogramado) para que ao salvar "Reprogramado" não seja sobrescrito para PROG.
    final statusValido = task.status.isNotEmpty
        ? task.status.toUpperCase().trim()
        : 'PROG';
    final statusPermitidos = ['ANDA', 'CONC', 'PROG', 'CANC', 'RPAR', 'RPGR'];
    final statusFinal = statusPermitidos.contains(statusValido)
        ? statusValido
        : 'PROG';
    map['status'] = statusFinal;

    // Log para debug
    if (statusFinal != statusValido) {
      // Debug removido
    }
    map['regional'] = task.regional.isNotEmpty ? task.regional : '';
    map['divisao'] = task.divisao.isNotEmpty ? task.divisao : '';
    map['local'] = task.locais.isNotEmpty ? task.locais.join(', ') : '';
    map['executor'] = task.executores.isNotEmpty
        ? task.executores.join(', ')
        : (task.executor.isNotEmpty ? task.executor : '');
    map['coordenador'] = task.coordenador.isNotEmpty ? task.coordenador : '';

    // Usar IDs se disponíveis
    if (task.statusId != null && task.statusId!.isNotEmpty) {
      map['status_id'] = task.statusId;
    }

    if (task.regionalId != null && task.regionalId!.isNotEmpty) {
      map['regional_id'] = task.regionalId;
    }

    if (task.divisaoId != null && task.divisaoId!.isNotEmpty) {
      map['divisao_id'] = task.divisaoId;
    }

    return map;
  }

  // Converter Map do Supabase para GanttSegment
  GanttSegment _segmentFromMap(Map<String, dynamic> map) {

    // Normalizar datas ao carregar do Supabase (remover hora/timezone)
    final dataInicioParsed = _parseDateInvariant(map['data_inicio'] as String);
    final dataFimParsed = _parseDateInvariant(map['data_fim'] as String);

    final dataInicio = DateTime(
      dataInicioParsed.year,
      dataInicioParsed.month,
      dataInicioParsed.day,
    );
    final dataFim = DateTime(
      dataFimParsed.year,
      dataFimParsed.month,
      dataFimParsed.day,
    );

    final tipoRaw = map['tipo'] as String?;
    final tipo = (tipoRaw != null && tipoRaw.isNotEmpty)
        ? tipoRaw.toUpperCase().trim()
        : 'OUT';
    final label = map['label'] as String? ?? '';

    // Verificar se o tipo é válido
    const validSegmentTypes = [
      'BEA',
      'FER',
      'COMP',
      'TRN',
      'BSL',
      'APO',
      'OUT',
      'ADM',
    ];
    final tipoFinal = validSegmentTypes.contains(tipo) ? tipo : 'OUT';

    if (tipoFinal != tipo) {
      // Debug removido
    }

    // Debug removido - apenas informações essenciais se necessário

    // Carregar tipo_periodo (padrão: EXECUCAO se não existir)
    final tipoPeriodoRaw = map['tipo_periodo'] as String?;
    final tipoPeriodo = (tipoPeriodoRaw != null && tipoPeriodoRaw.isNotEmpty)
        ? tipoPeriodoRaw.toUpperCase().trim()
        : 'EXECUCAO';

    // Validar tipo_periodo
    const validPeriodTypes = ['EXECUCAO', 'PLANEJAMENTO', 'DESLOCAMENTO'];
    final tipoPeriodoFinal = validPeriodTypes.contains(tipoPeriodo)
        ? tipoPeriodo
        : 'EXECUCAO';

    // Debug removido

    return GanttSegment(
      dataInicio: dataInicio,
      dataFim: dataFim,
      label: label,
      tipo: tipoFinal, // Usar tipo validado
      tipoPeriodo: tipoPeriodoFinal, // Usar tipo de período validado
    );
  }

  // Converter GanttSegment para Map do Supabase
  Map<String, dynamic> _segmentToMap(GanttSegment segment, String taskId) {
    // IMPORTANTE: Se o tipo já é um código válido (BEA, FER, COMP, TRN, etc), usar diretamente
    // Não aplicar mapeamento se já for um código válido
    final originalType = segment.tipo.toUpperCase().trim();
    const validSegmentTypes = [
      'BEA',
      'FER',
      'COMP',
      'TRN',
      'BSL',
      'APO',
      'OUT',
      'ADM',
    ];

    String validType;
    if (validSegmentTypes.contains(originalType)) {
      // Tipo já é válido, usar diretamente sem mapeamento
      validType = originalType;
      // Debug removido
    } else {
      // Aplicar mapeamento apenas se não for um código válido
      validType = _mapTaskTypeToSegmentType(segment.tipo);
      if (originalType != validType) {
        // Debug removido
      }
    }

    // Validar tipo_periodo
    final tipoPeriodoRaw = segment.tipoPeriodo.toUpperCase().trim();
    const validPeriodTypes = ['EXECUCAO', 'PLANEJAMENTO', 'DESLOCAMENTO'];
    final tipoPeriodoFinal = validPeriodTypes.contains(tipoPeriodoRaw)
        ? tipoPeriodoRaw
        : 'EXECUCAO';

    final segmentMap = {
      'task_id': taskId,
      'data_inicio': segment.dataInicio.toIso8601String(),
      'data_fim': segment.dataFim.toIso8601String(),
      'label': segment.label,
      'tipo': validType, // Usar tipo validado
      'tipo_periodo': tipoPeriodoFinal, // Usar tipo de período validado
    };

    // Debug removido

    return segmentMap;
  }

  // Carregar segmentos do Gantt para uma tarefa
  // Limita a 100 segmentos por padrão (suficiente para a maioria dos casos)
  Future<List<GanttSegment>> _loadGanttSegments(
    String taskId, {
    int? limit,
    bool loadAll = false,
  }) async {
    if (!_useSupabase) {
      // Fallback para mock
      final task = _tasks.firstWhere(
        (t) => t.id == taskId,
        orElse: () => Task(
          id: '',
          status: '',
          regional: '',
          divisao: '',
          locais: const [],
          tipo: '',
          ordem: '',
          tarefa: '',
          executor: '',
          frota: '',
          coordenador: '',
          si: '',
          dataInicio: DateTime.now(),
          dataFim: DateTime.now(),
          ganttSegments: [],
          precisaSi: false,
        ),
      );
      final segments = task.ganttSegments;
      if (limit != null && segments.length > limit) {
        return segments.take(limit).toList();
      }
      return segments;
    }

    try {
      var query = _supabase
          .from('gantt_segments')
          .select()
          .eq('task_id', taskId)
          .order('data_inicio', ascending: true);

      // Limitar a 100 segmentos por padrão (suficiente para períodos múltiplos)
      // Se loadAll for true, não limita (usar com cuidado)
      final maxLimit = loadAll ? null : (limit ?? 100);
      if (maxLimit != null) {
        query = query.limit(maxLimit);
      }

      // Timeout reduzido para 5 segundos (mais rápido)
      final response = await query.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          return <Map<String, dynamic>>[];
        },
      );

      if (response.isEmpty) {
        // Debug removido
        return [];
      }

      // Debug removido
      final segments = (response as List).map((map) {
        final segment = _segmentFromMap(map as Map<String, dynamic>);
        // Debug removido
        return segment;
      }).toList();

      if (maxLimit != null && segments.length >= maxLimit) {
        // Debug removido
      }

      // Debug removido
      return segments;
    } catch (e) {
      print('Erro ao carregar segmentos para tarefa $taskId: $e');
      // Retornar lista vazia em caso de erro para não bloquear o carregamento das tarefas
      return [];
    }
  }

  // Carregar períodos específicos por executor para uma tarefa
  Future<List<ExecutorPeriod>> _loadExecutorPeriods(String taskId) async {
    // log silenciado

    if (!_useSupabase) {
      print('⚠️ Supabase não está habilitado, retornando lista vazia');
      return [];
    }

    try {
      final response = await _supabase
          .from('executor_periods')
          .select()
          .eq('task_id', taskId)
          .order('executor_nome', ascending: true)
          .order('data_inicio', ascending: true)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              return <Map<String, dynamic>>[];
            },
          );

      if (response.isEmpty) {
        // log silenciado
        return [];
      }

      // log silenciado

      // Agrupar períodos por executor
      final Map<String, ExecutorPeriod> executorPeriodsMap = {};

      for (var map in response as List) {
        final executorId = map['executor_id'] as String;
        final executorNome = map['executor_nome'] as String;

        // Criar segmento a partir do map
        final segment = _segmentFromMap(map);

        if (executorPeriodsMap.containsKey(executorId)) {
          // Adicionar segmento ao executor existente
          final existing = executorPeriodsMap[executorId]!;
          executorPeriodsMap[executorId] = existing.copyWith(
            periods: [...existing.periods, segment],
          );
        } else {
          // Criar novo ExecutorPeriod
          executorPeriodsMap[executorId] = ExecutorPeriod(
            executorId: executorId,
            executorNome: executorNome,
            periods: [segment],
          );
        }
      }

      final result = executorPeriodsMap.values.toList();
      return result;
    } catch (e, stackTrace) {
      print('❌ Erro ao carregar períodos por executor para tarefa $taskId: $e');
      print('   Stack trace: $stackTrace');
      return [];
    }
  }

  // Carregar períodos específicos por frota para uma tarefa
  Future<List<FrotaPeriod>> _loadFrotaPeriods(String taskId) async {
    if (!_useSupabase) {
      return [];
    }
    try {
      final response = await _supabase
          .from('frota_periods')
          .select()
          .eq('task_id', taskId)
          .order('frota_nome', ascending: true)
          .order('data_inicio', ascending: true)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => <Map<String, dynamic>>[],
          );

      if (response.isEmpty) return [];

      final Map<String, FrotaPeriod> frotaMap = {};

      for (var map in response as List) {
        final frotaId = map['frota_id'] as String;
        final frotaNome = map['frota_nome'] as String? ?? '';
        final segment = _segmentFromMap(map);

        if (frotaMap.containsKey(frotaId)) {
          final existing = frotaMap[frotaId]!;
          frotaMap[frotaId] = existing.copyWith(
            periods: [...existing.periods, segment],
          );
        } else {
          frotaMap[frotaId] = FrotaPeriod(
            frotaId: frotaId,
            frotaNome: frotaNome,
            periods: [segment],
          );
        }
      }

      return frotaMap.values.toList();
    } catch (e) {
      print('❌ Erro ao carregar períodos por frota para tarefa $taskId: $e');
      return [];
    }
  }

  // Salvar períodos específicos por executor
  Future<void> _saveExecutorPeriods(
    String taskId,
    List<ExecutorPeriod> executorPeriods,
  ) async {
    // debug silenciado

    if (!_useSupabase) {
      // debug silenciado
      return;
    }

    try {
      // Primeiro, deletar todos os períodos existentes para esta tarefa
      // debug silenciado
      await _supabase.from('executor_periods').delete().eq('task_id', taskId);

      if (executorPeriods.isEmpty) {
        // debug silenciado
        return;
      }

      // Preparar dados para inserção
      final List<Map<String, dynamic>> periodsToInsert = [];

      for (var executorPeriod in executorPeriods) {
        // debug silenciado
        // debug silenciado

        if (executorPeriod.periods.isEmpty) {
          // debug silenciado
          continue;
        }

        for (var segment in executorPeriod.periods) {
          final periodData = {
            'task_id': taskId,
            'executor_id': executorPeriod.executorId,
            'executor_nome': executorPeriod.executorNome,
            'data_inicio': segment.dataInicio.toIso8601String(),
            'data_fim': segment.dataFim.toIso8601String(),
            'label': segment.label,
            'tipo': segment.tipo,
            'tipo_periodo': segment.tipoPeriodo,
          };

          // debug silenciado
          periodsToInsert.add(periodData);
        }
      }

      if (periodsToInsert.isEmpty) {
        // debug silenciado
        return;
      }

      // debug silenciado
      await _supabase.from('executor_periods').insert(periodsToInsert);
      // debug silenciado
    } catch (e, stackTrace) {
      print('❌ Erro ao salvar períodos por executor para tarefa $taskId: $e');
      print('   Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Salvar períodos específicos por frota
  Future<void> _saveFrotaPeriods(
    String taskId,
    List<FrotaPeriod> frotaPeriods,
  ) async {
    if (!_useSupabase) {
      return;
    }

    try {
      await _supabase.from('frota_periods').delete().eq('task_id', taskId);

      if (frotaPeriods.isEmpty) {
        return;
      }

      final List<Map<String, dynamic>> periodsToInsert = [];

      for (var frotaPeriod in frotaPeriods) {
        if (frotaPeriod.periods.isEmpty) {
          continue;
        }
        for (var segment in frotaPeriod.periods) {
          periodsToInsert.add({
            'task_id': taskId,
            'frota_id': frotaPeriod.frotaId,
            'frota_nome': frotaPeriod.frotaNome,
            'data_inicio': segment.dataInicio.toIso8601String(),
            'data_fim': segment.dataFim.toIso8601String(),
            'label': segment.label,
            'tipo': segment.tipo,
            'tipo_periodo': segment.tipoPeriodo,
          });
        }
      }

      if (periodsToInsert.isNotEmpty) {
        await _supabase.from('frota_periods').insert(periodsToInsert);
      }
    } catch (e) {
      print('❌ Erro ao salvar períodos por frota para tarefa $taskId: $e');
      rethrow;
    }
  }

  // Mapear tipo da tarefa para tipo válido de segmento
  String _mapTaskTypeToSegmentType(String taskType) {
    // Tipos válidos para segmentos: 'BEA', 'FER', 'COMP', 'TRN', 'BSL', 'APO', 'OUT', 'ADM'
    final upperType = taskType.toUpperCase().trim();

    // Se o tipo da tarefa já é um tipo válido de segmento, usar diretamente
    const validSegmentTypes = [
      'BEA',
      'FER',
      'COMP',
      'TRN',
      'BSL',
      'APO',
      'OUT',
      'ADM',
    ];
    if (validSegmentTypes.contains(upperType)) {
      return upperType;
    }

    // Mapear tipos comuns de tarefa para tipos de segmento
    // Incluir variações e nomes descritivos
    final typeMap = {
      // Tipos diretos (já validados acima, mas incluídos para completude)
      'FER': 'FER',
      'COMP': 'COMP',
      'BSL': 'BSL',
      'TRN': 'TRN',
      'APO': 'APO',
      'ADM': 'ADM',
      'BEA': 'BEA',
      // Variações e nomes descritivos
      'LINHA DE TRANSMISSÃO': 'TRN',
      'LINHAS DE TRANSMISSÃO': 'TRN',
      'TRANSMISSÃO': 'TRN',
      'TRANSMISSAO': 'TRN',
      'FERRAMENTA': 'FER',
      'FERRAMENTAS': 'FER',
      'COMPONENTE': 'COMP',
      'COMPONENTES': 'COMP',
      'BASELINE': 'BSL',
      'APOIO': 'APO',
      'ADMINISTRATIVO': 'ADM',
      'ADMINISTRAÇÃO': 'ADM',
      'ADMINISTRACAO': 'ADM',
    };

    final mappedType = typeMap[upperType] ?? 'OUT';

    // Log se o tipo foi mapeado
    // silenciar logs de mapeamento/alerta para evitar ruído

    return mappedType;
  }

  // Métodos auxiliares para banco local
  Future<List<Task>> _getAllTasksFromLocal() async {
    try {
      final db = await _localDb.database;
      final tasksRows = await db.query(
        'tasks_local',
        orderBy: 'data_inicio ASC',
      );

      final tasks = <Task>[];
      for (var row in tasksRows) {
        try {
          final task = await _taskFromLocalMap(row);
          tasks.add(task);
        } catch (e) {
          print('Erro ao converter tarefa do banco local: $e');
        }
      }

      // Aplicar filtros de perfil
      return await _aplicarFiltrosPerfil(tasks);
    } catch (e) {
      print('Erro ao buscar tarefas do banco local: $e');
      return [];
    }
  }

  Future<Task> _taskFromLocalMap(Map<String, dynamic> map) async {
    final db = await _localDb.database;
    final taskId = map['id'] as String;

    // Carregar relacionamentos
    final localIdsRows = await db.query(
      'tasks_locais_local',
      where: 'task_id = ?',
      whereArgs: [taskId],
    );
    final localIds = localIdsRows.map((r) => r['local_id'] as String).toList();

    // Carregar nomes dos locais (locais_local) para preencher coluna LOCAL
    List<String> locais = [];
    if (localIds.isNotEmpty) {
      final placeholders = List.filled(localIds.length, '?').join(',');
      final locaisRows = await db.query(
        'locais_local',
        where: 'id IN ($placeholders)',
        whereArgs: localIds,
      );
      final idToName = <String, String>{};
      for (final r in locaisRows) {
        final id = r['id'] as String?;
        final nome = r['local'] as String?;
        if (id != null && nome != null) idToName[id] = nome;
      }
      locais = localIds.map((id) => idToName[id]).whereType<String>().toList();
    }
    if (locais.isEmpty) {
      final colunaLocal = map['local'];
      if (colunaLocal != null && colunaLocal.toString().trim().isNotEmpty) {
        locais = colunaLocal
            .toString()
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    }

    final executorIdsRows = await db.query(
      'tasks_executores_local',
      where: 'task_id = ?',
      whereArgs: [taskId],
    );
    final executorIds = executorIdsRows
        .map((r) => r['executor_id'] as String)
        .toList();

    // Carregar nomes dos executores (executores_local) para preencher coluna EXECUTOR
    List<String> executores = [];
    if (executorIds.isNotEmpty) {
      final placeholders = List.filled(executorIds.length, '?').join(',');
      final executoresRows = await db.query(
        'executores_local',
        where: 'id IN ($placeholders)',
        whereArgs: executorIds,
      );
      final idToName = <String, String>{};
      for (final r in executoresRows) {
        final id = r['id'] as String?;
        final nome = r['nome'] as String?;
        if (id != null && nome != null) idToName[id] = nome;
      }
      executores = executorIds
          .map((id) => idToName[id])
          .whereType<String>()
          .toList();
    }

    // Carregar segmentos
    final segmentsRows = await db.query(
      'gantt_segments_local',
      where: 'task_id = ?',
      whereArgs: [taskId],
      orderBy: 'data_inicio ASC',
    );
    // Usar isUtc: true para alinhar ao Supabase (ISO UTC); evita deslocamento de 1 dia no Gantt quando os dados vêm do cache
    final segments = segmentsRows.map((row) {
      return GanttSegment(
        dataInicio: DateTime.fromMillisecondsSinceEpoch(
          row['data_inicio'] as int,
          isUtc: true,
        ),
        dataFim: DateTime.fromMillisecondsSinceEpoch(
          row['data_fim'] as int,
          isUtc: true,
        ),
        label: row['label'] as String? ?? '',
        tipo: row['tipo'] as String? ?? 'OUT',
        tipoPeriodo: row['tipo_periodo'] as String? ?? 'EXECUCAO',
      );
    }).toList();

    return Task(
      id: taskId,
      statusId: map['status_id'] as String?,
      regionalId: map['regional_id'] as String?,
      divisaoId: map['divisao_id'] as String?,
      segmentoId: map['segmento_id'] as String?,
      localIds: localIds,
      executorIds: executorIds,
      equipeIds: [], // TODO: Implementar equipes no banco local
      status: map['status'] as String? ?? 'PROG',
      statusNome: map['status'] as String? ?? 'Programado',
      regional: map['regional'] as String? ?? '',
      divisao: map['divisao'] as String? ?? '',
      locais: locais,
      segmento: map['segmento'] as String? ?? '',
      tipo: map['tipo'] as String? ?? '',
      ordem: map['ordem'] as String?,
      tarefa: map['tarefa'] as String? ?? '',
      executores: executores,
      executor: map['executor'] as String? ?? '',
      frota: map['frota'] as String? ?? '',
      coordenador: map['coordenador'] as String? ?? '',
      si: map['si'] as String? ?? '',
      dataInicio: map['data_inicio'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['data_inicio'] as int,
              isUtc: true,
            )
          : DateTime.now(),
      dataFim: map['data_fim'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['data_fim'] as int,
              isUtc: true,
            )
          : DateTime.now(),
      ganttSegments: segments,
      executorPeriods:
          [], // TODO: Carregar períodos por executor do banco local
      observacoes: map['observacoes'] as String?,
      horasPrevistas: (map['horas_previstas'] as num?)?.toDouble(),
      horasExecutadas: (map['horas_executadas'] as num?)?.toDouble(),
      prioridade: map['prioridade'] as String?,
      parentId: map['parent_id'] as String?,
      dataCriacao: map['data_criacao'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['data_criacao'] as int)
          : null,
      dataAtualizacao: map['data_atualizacao'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['data_atualizacao'] as int)
          : null,
    );
  }

  Future<void> _saveTaskToLocal(Task task, {bool markSynced = false}) async {
    try {
      final db = await _localDb.database;
      final taskMap = {
        'id': task.id,
        'status': task.status,
        'status_id': task.statusId,
        'regional': task.regional,
        'regional_id': task.regionalId,
        'divisao': task.divisao,
        'divisao_id': task.divisaoId,
        'segmento': task.segmento,
        'segmento_id': task.segmentoId,
        'local': task.locais.isNotEmpty ? task.locais.join(', ') : null,
        'tipo': task.tipo,
        'ordem': task.ordem,
        'tarefa': task.tarefa,
        'executor': task.executor,
        'frota': task.frota,
        'coordenador': task.coordenador,
        'si': task.si,
        'data_inicio': task.dataInicio.millisecondsSinceEpoch,
        'data_fim': task.dataFim.millisecondsSinceEpoch,
        'observacoes': task.observacoes,
        'horas_previstas': task.horasPrevistas,
        'horas_executadas': task.horasExecutadas,
        'prioridade': task.prioridade,
        'parent_id': task.parentId,
        'data_criacao': task.dataCriacao?.millisecondsSinceEpoch,
        'data_atualizacao':
            task.dataAtualizacao?.millisecondsSinceEpoch ??
            DateTime.now().millisecondsSinceEpoch,
        'sync_status': markSynced ? 'synced' : 'pending',
        'last_synced': markSynced
            ? DateTime.now().millisecondsSinceEpoch
            : null,
      };

      await db.insert(
        'tasks_local',
        taskMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Salvar relacionamentos
      await db.delete(
        'tasks_locais_local',
        where: 'task_id = ?',
        whereArgs: [task.id],
      );
      for (var localId in task.localIds) {
        await db.insert('tasks_locais_local', {
          'task_id': task.id,
          'local_id': localId,
        });
      }

      await db.delete(
        'tasks_executores_local',
        where: 'task_id = ?',
        whereArgs: [task.id],
      );
      for (var executorId in task.executorIds) {
        await db.insert('tasks_executores_local', {
          'task_id': task.id,
          'executor_id': executorId,
        });
      }

      // Salvar segmentos (replace se mesmo id já existir, ex.: re-salvar mesma tarefa)
      // Quando markSynced é true (ex.: cache após buscar do Supabase), segmentos também ficam 'synced'
      await db.delete(
        'gantt_segments_local',
        where: 'task_id = ?',
        whereArgs: [task.id],
      );
      final segmentStatus = markSynced ? 'synced' : 'pending';
      final segmentLastSynced = markSynced
          ? DateTime.now().millisecondsSinceEpoch
          : null;
      for (var segment in task.ganttSegments) {
        await db.insert('gantt_segments_local', {
          'id':
              '${DateTime.now().millisecondsSinceEpoch}_${task.ganttSegments.indexOf(segment)}',
          'task_id': task.id,
          'data_inicio': segment.dataInicio.millisecondsSinceEpoch,
          'data_fim': segment.dataFim.millisecondsSinceEpoch,
          'label': segment.label,
          'tipo': segment.tipo,
          'tipo_periodo': segment.tipoPeriodo,
          'sync_status': segmentStatus,
          'last_synced': segmentLastSynced,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    } catch (e) {
      print('Erro ao salvar tarefa no banco local: $e');
      rethrow;
    }
  }

  // CRUD Operations
  Future<List<Task>> getAllTasks({bool aplicarPerfil = true}) async {
    if (!_useSupabase) {
      _logDebug(
        '⏱ [tasks] getAllTasks (mock/in-memory) -> ${_tasks.length} tarefas',
      );
      return List.unmodifiable(_tasks);
    }

    // Se offline, ler do banco local
    if (!_connectivity.isConnected) {
      _logDebug('⏱ [tasks] getAllTasks offline -> lendo do banco local');
      return await _getAllTasksFromLocal();
    }

    // Se online, tentar do Supabase primeiro, depois do local como fallback
    final totalSw = Stopwatch()..start();
    final fetchSw = Stopwatch()..start();
    _logDebug('⏱ [tasks] getAllTasks iniciado (Supabase)');
    dynamic response;
    try {
      // Tentar fazer select com joins primeiro
      response = await _supabase
          .from('tasks')
          .select('''
            *,
            status!left(codigo, status),
            regionais!left(regional),
            divisoes!left(divisao),
            segmentos!left(segmento),
            tasks_locais!left(locais!inner(id, local)),
            tasks_executores!left(executores!inner(id, nome, nome_completo)),
            tasks_equipes!left(equipes!inner(id, nome, equipes_executores!left(executor_id, papel, executores!inner(id, nome)))),
            tasks_frotas!left(frota!inner(id, nome, placa, marca))
          ''')
          .order('data_inicio', ascending: true)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              return <Map<String, dynamic>>[];
            },
          );
    } catch (e) {
      // Se os joins falharem (foreign keys não existem ainda), tentar sem joins
      print('⚠️ Erro ao buscar tarefas com joins: $e');
      print('🔄 Tentando buscar sem joins (compatibilidade)...');
      try {
        response = await _supabase
            .from('tasks')
            .select()
            .order('data_inicio', ascending: true)
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                return <Map<String, dynamic>>[];
              },
            );
      } catch (e2) {
        print('❌ Erro ao buscar tarefas (fallback): $e2');
        return [];
      }
    }

    fetchSw.stop();
    _logDebug(
      '⏱ [tasks] fetch Supabase concluído em ${fetchSw.elapsedMilliseconds}ms, registros=${response is List ? response.length : 0}',
    );

    if (response.isEmpty) {
      _logDebug('⏱ [tasks] Nenhum registro retornado do Supabase');
      totalSw.stop();
      return [];
    }

    try {
      final tasksList = response as List;
      final tasks = <Task>[];
      final buildSw = Stopwatch()..start();

      // Primeiro, criar todas as tarefas sem segmentos
      for (var map in tasksList) {
        final task = _taskFromMap(map as Map<String, dynamic>);
        tasks.add(task);
      }
      buildSw.stop();
      _logDebug(
        '⏱ [tasks] Montagem inicial de ${tasks.length} tarefas em ${buildSw.elapsedMilliseconds}ms',
      );

      // OTIMIZAÇÃO: Carregar segmentos e períodos em BATCH (uma query para todas as tarefas)
      // Em vez de 231 queries individuais, fazemos apenas 3 queries batch
      final segSw = Stopwatch()..start();
      final taskIds = tasks.map((t) => t.id).toList();

      // Carregar tudo em batch (muito mais rápido!)
      final batchSw = Stopwatch()..start();
      final batchResults = await Future.wait([
        _loadGanttSegmentsBatch(taskIds, limitPerTask: 100),
        _loadExecutorPeriodsBatch(taskIds),
        _loadFrotaPeriodsBatch(taskIds),
      ]);
      batchSw.stop();
      _logDebug(
        '⏱ [tasks] Batch queries concluídas em ${batchSw.elapsedMilliseconds}ms',
      );

      final segMap = batchResults[0] as Map<String, List<GanttSegment>>;
      final epMap = batchResults[1] as Map<String, List<ExecutorPeriod>>;
      final fpMap = batchResults[2] as Map<String, List<FrotaPeriod>>;

      // Aplicar segmentos e períodos às tarefas
      final applySw = Stopwatch()..start();
      int totalSegments = 0;
      int tasksWithSegments = 0;
      int totalExecutorPeriods = 0;
      int tasksWithExecutorPeriods = 0;

      for (var i = 0; i < tasks.length; i++) {
        final task = tasks[i];
        final segments = segMap[task.id] ?? [];
        final executorPeriods = epMap[task.id] ?? [];
        final frotaPeriods = fpMap[task.id] ?? [];

        // Se não houver segmentos, criar um inicial baseado nas datas da tarefa
        final finalSegments = segments.isEmpty
            ? [
                GanttSegment(
                  dataInicio: task.dataInicio,
                  dataFim: task.dataFim,
                  label: task.tarefa,
                  tipo: _mapTaskTypeToSegmentType(task.tipo),
                  tipoPeriodo: 'EXECUCAO',
                ),
              ]
            : segments;

        tasks[i] = task.copyWith(
          ganttSegments: finalSegments,
          executorPeriods: executorPeriods,
          frotaPeriods: frotaPeriods,
        );

        totalSegments += finalSegments.length;
        if (finalSegments.isNotEmpty) tasksWithSegments++;

        if (executorPeriods.isNotEmpty) {
          tasksWithExecutorPeriods++;
          totalExecutorPeriods += executorPeriods.fold<int>(
            0,
            (prev, ep) => prev + ep.periods.length,
          );
        }
      }
      applySw.stop();
      segSw.stop();
      _logDebug(
        '⏱ [tasks] Aplicação de segmentos/períodos concluída em ${applySw.elapsedMilliseconds}ms',
      );
      _logDebug(
        '⏱ [tasks] Segmentos/Períodos: tempo=${segSw.elapsedMilliseconds}ms | tarefas=${tasks.length} | com segmentos=$tasksWithSegments (total seg=$totalSegments) | com períodos=$tasksWithExecutorPeriods (total períodos=$totalExecutorPeriods)',
      );

      // Aplicar filtros de perfil do usuário
      final filtroSw = Stopwatch()..start();
      final tasksFiltradas = aplicarPerfil
          ? await _aplicarFiltrosPerfil(tasks)
          : tasks;
      filtroSw.stop();
      totalSw.stop();
      _logDebug(
        '⏱ [tasks] Filtro de perfil em ${filtroSw.elapsedMilliseconds}ms -> ${tasksFiltradas.length} tarefas | total getAllTasks=${totalSw.elapsedMilliseconds}ms',
      );
      return tasksFiltradas;
    } catch (e) {
      print('❌ Erro ao processar tarefas do Supabase: $e');
      // Fallback para banco local
      print('🔄 Tentando buscar do banco local...');
      try {
        return await _getAllTasksFromLocal();
      } catch (e2) {
        print('❌ Erro ao buscar do banco local: $e2');
        // Último fallback: cache em memória
        final tasksFallback = List<Task>.unmodifiable(_tasks);
        return await _aplicarFiltrosPerfil(tasksFallback);
      }
    }
  }

  Future<Task?> getTaskById(String id) async {
    if (!_useSupabase) {
      try {
        return _tasks.firstWhere((task) => task.id == id);
      } catch (e) {
        return null;
      }
    }

    try {
      final response = await _supabase
          .from('tasks')
          .select('''
            *,
            status!left(codigo, status),
            regionais!left(regional),
            divisoes!left(divisao),
            segmentos!left(segmento),
            tasks_locais!left(locais!inner(id, local)),
            tasks_executores!left(executores!inner(id, nome, nome_completo)),
            tasks_equipes!left(equipes!inner(id, nome, equipes_executores!left(executor_id, papel, executores!inner(id, nome)))),
            tasks_frotas!left(frota!inner(id, nome, placa, marca))
          ''')
          .eq('id', id)
          .single();

      final task = _taskFromMap(response);
      final segments = await _loadGanttSegments(task.id, limit: 100);
      // Se não houver segmentos, criar um inicial baseado nas datas da tarefa
      final finalSegments = segments.isEmpty
          ? [
              GanttSegment(
                dataInicio: task.dataInicio,
                dataFim: task.dataFim,
                label: task.tarefa,
                tipo: _mapTaskTypeToSegmentType(task.tipo),
                tipoPeriodo: 'EXECUCAO',
              ),
            ]
          : segments;
      // Carregar períodos por executor
      final executorPeriods = await _loadExecutorPeriods(id);

      return task.copyWith(
        ganttSegments: finalSegments,
        executorPeriods: executorPeriods,
      );
    } catch (e) {
      print('Erro ao buscar tarefa: $e');
      return null;
    }
  }

  Future<Task> createTask(Task task) async {
    final newTask = task.copyWith(
      dataCriacao: DateTime.now(),
      dataAtualizacao: DateTime.now(),
    );

    if (!_useSupabase) {
      final taskWithId = newTask.copyWith(id: 'TASK_${_nextId++}');
      _tasks.add(taskWithId);
      return taskWithId;
    }

    try {
      // Criar tarefa
      final taskMap = _taskToMap(newTask);
      taskMap.remove('id'); // Remover ID para gerar UUID no Supabase

      print('💾 Salvando tarefa no banco:');
      print('   - status: ${taskMap['status']}');
      print('   - regional: ${taskMap['regional']}');
      print('   - divisao: ${taskMap['divisao']}');
      print('   - local: ${taskMap['local']}');
      print('   - executor: ${taskMap['executor']}');
      print('   - coordenador: ${taskMap['coordenador']}');
      print('   - localIds: ${newTask.localIds}');
      print('   - executorIds: ${newTask.executorIds}');
      print('   - equipeIds: ${newTask.equipeIds}');

      final response = await _supabase
          .from('tasks')
          .insert(taskMap)
          .select()
          .single();

      final createdTaskId = response['id'] as String;

      // Salvar no banco local primeiro
      final taskToSave = newTask.copyWith(id: createdTaskId);
      try {
        await _saveTaskToLocal(taskToSave, markSynced: true);
      } catch (e) {
        print('⚠️ Erro ao salvar tarefa no banco local: $e');
      }

      // Inserir relacionamentos many-to-many
      // Locais
      print(
        '🔍 Verificando locais para salvar: ${task.localIds.length} locais',
      );
      if (task.localIds.isNotEmpty) {
        final locaisData = task.localIds
            .map((localId) => {'task_id': createdTaskId, 'local_id': localId})
            .toList();
        print(
          '💾 Tentando inserir ${locaisData.length} locais na tabela tasks_locais',
        );
        try {
          await _supabase.from('tasks_locais').insert(locaisData);
          print('✅ Locais salvos com sucesso');
        } catch (e) {
          print('❌ Erro ao salvar locais: $e');
          // Se a tabela não existir, tentar salvar no campo antigo
          if (e.toString().contains('tasks_locais') ||
              e.toString().contains('does not exist')) {
            print(
              '⚠️ Tabela tasks_locais não existe. Salvando no campo local_id (compatibilidade)',
            );
            // Não fazer nada, deixar o campo local_id ser salvo normalmente
          } else {
            rethrow;
          }
        }
      } else {
        print('⚠️ Nenhum local selecionado para salvar');
      }

      // Executores
      if (task.executorIds.isNotEmpty) {
        final executoresData = task.executorIds
            .map(
              (executorId) => {
                'task_id': createdTaskId,
                'executor_id': executorId,
              },
            )
            .toList();
        await _supabase.from('tasks_executores').insert(executoresData);
        print(
          '💾 Salvando ${executoresData.length} executores para tarefa $createdTaskId',
        );
      }

      // Equipes
      if (task.equipeIds.isNotEmpty) {
        final equipesData = task.equipeIds
            .map(
              (equipeId) => {'task_id': createdTaskId, 'equipe_id': equipeId},
            )
            .toList();
        await _supabase.from('tasks_equipes').insert(equipesData);
        print(
          '💾 Salvando ${equipesData.length} equipes para tarefa $createdTaskId',
        );
      }

      // Frotas
      if (task.frotaIds.isNotEmpty) {
        final frotasData = task.frotaIds
            .map((frotaId) => {'task_id': createdTaskId, 'frota_id': frotaId})
            .toList();
        await _supabase.from('tasks_frotas').insert(frotasData);
        print(
          '💾 Salvando ${frotasData.length} frotas para tarefa $createdTaskId',
        );
      }

      // Carregar tarefa completa com joins
      final createdTaskResponse = await _supabase
          .from('tasks')
          .select('''
            *,
            status!left(codigo, status),
            regionais!left(regional),
            divisoes!left(divisao),
            segmentos!left(segmento),
            tasks_locais!left(locais!inner(id, local)),
            tasks_executores!left(executores!inner(id, nome, nome_completo)),
            tasks_equipes!left(equipes!inner(id, nome, equipes_executores!left(executor_id, papel, executores!inner(id, nome)))),
            tasks_frotas!left(frota!inner(id, nome, placa, marca))
          ''')
          .eq('id', createdTaskId)
          .single();

      final createdTask = _taskFromMap(createdTaskResponse);

      // Garantir que sempre haja pelo menos um segmento
      // Se não houver segmentos, criar um inicial baseado nas datas da tarefa
      final isSubtask = newTask.parentId != null;
      List<GanttSegment> segmentsToSave = newTask.ganttSegments;

      print(
        '📋 TaskService.createTask: Criando ${isSubtask ? "subtarefa" : "tarefa"}',
      );
      print('   Tarefa ID: ${createdTask.id}');
      print('   Parent ID: ${newTask.parentId}');
      print('   Segmentos recebidos: ${segmentsToSave.length}');
      for (var seg in segmentsToSave) {
        print(
          '     - ${seg.dataInicio.toString().substring(0, 10)} até ${seg.dataFim.toString().substring(0, 10)} (${seg.tipo})',
        );
      }

      if (segmentsToSave.isEmpty) {
        final segmentType = _mapTaskTypeToSegmentType(newTask.tipo);
        segmentsToSave = [
          GanttSegment(
            dataInicio: newTask.dataInicio,
            dataFim: newTask.dataFim,
            label: newTask.tarefa,
            tipo: segmentType,
            tipoPeriodo: 'EXECUCAO',
          ),
        ];
        print(
          '🆕 Criando segmento inicial para ${isSubtask ? "subtarefa" : "tarefa"} ${createdTask.id}',
        );
        print('   Tipo: $segmentType');
        print(
          '   Data início: ${newTask.dataInicio.toString().substring(0, 10)}',
        );
        print('   Data fim: ${newTask.dataFim.toString().substring(0, 10)}');
      }

      // Salvar segmentos no banco
      final segments = segmentsToSave
          .map((s) => _segmentToMap(s, createdTask.id))
          .toList();
      print(
        '💾 Salvando ${segments.length} segmentos do Gantt para ${isSubtask ? "subtarefa" : "tarefa"} ${createdTask.id}',
      );
      for (var seg in segments) {
        print(
          '     - tipo: ${seg['tipo']}, início: ${seg['data_inicio']}, fim: ${seg['data_fim']}',
        );
      }

      await _supabase.from('gantt_segments').insert(segments);
      // Debug removido

      // Carregar segmentos recém-criados para garantir que estão corretos
      final loadedSegments = await _loadGanttSegments(
        createdTask.id,
        limit: 100,
      );
      print('📊 Segmentos carregados após criação: ${loadedSegments.length}');
      if (loadedSegments.length != segments.length) {
        print(
          '⚠️ AVISO: Número de segmentos salvos (${segments.length}) diferente do número carregado (${loadedSegments.length})',
        );
      }
      for (var seg in loadedSegments) {
        print(
          '     - ${seg.dataInicio.toString().substring(0, 10)} até ${seg.dataFim.toString().substring(0, 10)} (${seg.tipo})',
        );
      }

      // Salvar períodos por executor se existirem
      print(
        '📋 Verificando períodos por executor na nova tarefa: ${newTask.executorPeriods.length}',
      );
      if (newTask.executorPeriods.isNotEmpty) {
        print(
          '💾 Salvando ${newTask.executorPeriods.length} períodos por executor...',
        );
        await _saveExecutorPeriods(createdTask.id, newTask.executorPeriods);
      } else {
        print('ℹ️ Nenhum período por executor para salvar na nova tarefa');
      }

      // Salvar períodos por frota se existirem
      print(
        '📋 Verificando períodos por frota na nova tarefa: ${newTask.frotaPeriods.length}',
      );
      if (newTask.frotaPeriods.isNotEmpty) {
        print(
          '💾 Salvando ${newTask.frotaPeriods.length} períodos por frota...',
        );
        await _saveFrotaPeriods(createdTask.id, newTask.frotaPeriods);
      } else {
        print('ℹ️ Nenhum período por frota para salvar na nova tarefa');
      }

      // Carregar períodos salvos
      final loadedExecutorPeriods = await _loadExecutorPeriods(createdTask.id);
      final loadedFrotaPeriods = await _loadFrotaPeriods(createdTask.id);

      final finalTask = createdTask.copyWith(
        ganttSegments: loadedSegments,
        executorPeriods: loadedExecutorPeriods,
        frotaPeriods: loadedFrotaPeriods,
      );

      // Atualizar no banco local com os segmentos carregados (já enviados ao Supabase = synced)
      try {
        await _saveTaskToLocal(finalTask, markSynced: true);
      } catch (e) {
        print('⚠️ Erro ao atualizar tarefa no banco local: $e');
      }

      // Atualizar a view de execuções para refletir o novo estado
      await refreshMvExecucoesDia();

      // Notificar outras abas sobre a criação da tarefa
      if (kIsWeb) {
        try {
          TabSyncService().notifyTaskCreated(createdTask.id);
        } catch (e) {
          print('⚠️ Erro ao notificar criação de tarefa: $e');
        }
      }

      return finalTask;
    } catch (e) {
      print('Erro ao criar tarefa no Supabase: $e');
      // Se offline ou erro, salvar apenas no banco local
      final taskId = 'TASK_${DateTime.now().millisecondsSinceEpoch}';
      final taskWithId = newTask.copyWith(id: taskId);

      try {
        await _saveTaskToLocal(taskWithId);
        // Adicionar à fila de sincronização
        await _syncService.queueOperation(
          'tasks',
          'insert',
          taskId,
          _taskToMap(taskWithId),
        );
        _syncService.markHasLocalChanges();
        // Sincronizar automaticamente quando houver rede
        if (_connectivity.isConnected) {
          _syncService.syncAll();
        }
      } catch (e2) {
        print('❌ Erro ao salvar tarefa no banco local: $e2');
      }

      // Notificar outras abas sobre a criação da tarefa
      if (kIsWeb) {
        try {
          TabSyncService().notifyTaskCreated(taskId);
        } catch (e) {
          print('⚠️ Erro ao notificar criação de tarefa: $e');
        }
      }

      return taskWithId;
    }
  }

  Future<Task?> updateTask(String id, Task updatedTask) async {
    final task = updatedTask.copyWith(id: id, dataAtualizacao: DateTime.now());

    if (!_useSupabase) {
      final index = _tasks.indexWhere((t) => t.id == id);
      if (index == -1) return null;

      _tasks[index] = task;
      return task;
    }

    try {
      // Atualizar tarefa
      final taskMap = _taskToMap(task);
      taskMap.remove('id'); // Não atualizar o ID

      print('💾 Atualizando tarefa no banco:');
      print('   - id: $id');
      print('   - status: ${taskMap['status']}');
      print('   - status_id: ${taskMap['status_id']}');
      print('   - task.status original: ${task.status}');

      // Garantir que taskMap contém apenas valores válidos e serializáveis
      final cleanMap = <String, dynamic>{};
      taskMap.forEach((key, value) {
        // Ignorar valores que são funções, callbacks ou outros tipos não serializáveis
        if (value is Function) {
          print('⚠️ Ignorando valor do tipo Function para a chave: $key');
          return;
        }

        // Converter valores para tipos primitivos válidos
        if (value == null) {
          cleanMap[key] = null;
        } else if (value is String ||
            value is int ||
            value is double ||
            value is bool) {
          cleanMap[key] = value;
        } else if (value is DateTime) {
          cleanMap[key] = value.toIso8601String();
        } else if (value is List) {
          // Listas devem ser de tipos primitivos
          cleanMap[key] = value;
        } else {
          // Converter outros tipos para string
          print(
            '⚠️ Convertendo valor não primitivo para string: $key = $value (${value.runtimeType})',
          );
          cleanMap[key] = value.toString();
        }
      });

      print('📤 Enviando update com ${cleanMap.length} campos');
      print('   Campos: ${cleanMap.keys.join(', ')}');
      print(
        '   Valores: status=${cleanMap['status']}, status_id=${cleanMap['status_id']}',
      );

      // Fazer o update de forma explícita, garantindo que não há problemas de tipo
      final updateResponse = await _supabase
          .from('tasks')
          .update(cleanMap)
          .eq('id', id)
          .select();

      print(
        '✅ Tarefa atualizada no banco. Resposta: ${updateResponse.length} registro(s)',
      );

      // Salvar no banco local como já sincronizado (evita "X pendentes" após editar)
      try {
        await _saveTaskToLocal(task, markSynced: true);
      } catch (e) {
        print('⚠️ Erro ao salvar tarefa no banco local: $e');
      }

      // Atualizar relacionamentos many-to-many
      // Locais: remover antigos e inserir novos
      print(
        '🔍 Verificando locais para atualizar: ${task.localIds.length} locais',
      );
      try {
        await _supabase.from('tasks_locais').delete().eq('task_id', id);
        if (task.localIds.isNotEmpty) {
          final locaisData = task.localIds
              .map((localId) => {'task_id': id, 'local_id': localId})
              .toList();
          print(
            '💾 Tentando inserir ${locaisData.length} locais na tabela tasks_locais',
          );
          await _supabase.from('tasks_locais').insert(locaisData);
          print('✅ Locais atualizados com sucesso');
        } else {
          print('⚠️ Nenhum local selecionado para atualizar');
        }
      } catch (e) {
        print('❌ Erro ao atualizar locais: $e');
        // Se a tabela não existir, não fazer nada (compatibilidade)
        if (e.toString().contains('tasks_locais') ||
            e.toString().contains('does not exist')) {
          print(
            '⚠️ Tabela tasks_locais não existe. Pulando atualização de locais.',
          );
        } else {
          rethrow;
        }
      }

      // Executores: remover antigos e inserir novos
      await _supabase.from('tasks_executores').delete().eq('task_id', id);
      if (task.executorIds.isNotEmpty) {
        final executoresData = task.executorIds
            .map((executorId) => {'task_id': id, 'executor_id': executorId})
            .toList();
        await _supabase.from('tasks_executores').insert(executoresData);
        print(
          '💾 Salvando ${executoresData.length} executores para tarefa $id',
        );
      }

      // Equipes: remover antigas e inserir novas
      await _supabase.from('tasks_equipes').delete().eq('task_id', id);
      if (task.equipeIds.isNotEmpty) {
        final equipesData = task.equipeIds
            .map((equipeId) => {'task_id': id, 'equipe_id': equipeId})
            .toList();
        await _supabase.from('tasks_equipes').insert(equipesData);
        print('💾 Salvando ${equipesData.length} equipes para tarefa $id');
      }

      // Frotas: remover antigas e inserir novas
      await _supabase.from('tasks_frotas').delete().eq('task_id', id);
      if (task.frotaIds.isNotEmpty) {
        final frotasData = task.frotaIds
            .map((frotaId) => {'task_id': id, 'frota_id': frotaId})
            .toList();
        await _supabase.from('tasks_frotas').insert(frotasData);
        print('💾 Atualizando ${frotasData.length} frotas para tarefa $id');
      }

      // Atualizar segmentos do Gantt (remover antigos e criar novos)
      print('🔄 Atualizando segmentos do Gantt para tarefa $id');
      print('   Segmentos recebidos: ${task.ganttSegments.length}');
      for (var seg in task.ganttSegments) {
        print(
          '     - ${seg.dataInicio.toString().substring(0, 10)} até ${seg.dataFim.toString().substring(0, 10)} (${seg.tipo})',
        );
      }

      // Deletar segmentos antigos
      await _supabase.from('gantt_segments').delete().eq('task_id', id);
      print('🗑️ Segmentos antigos deletados');

      // Garantir que sempre haja pelo menos um segmento
      List<GanttSegment> segmentsToSave = task.ganttSegments;
      if (segmentsToSave.isEmpty) {
        // Se não houver segmentos, criar um inicial baseado nas datas da tarefa
        final segmentType = _mapTaskTypeToSegmentType(task.tipo);
        segmentsToSave = [
          GanttSegment(
            dataInicio: task.dataInicio,
            dataFim: task.dataFim,
            label: task.tarefa,
            tipo: segmentType,
            tipoPeriodo: 'EXECUCAO',
          ),
        ];
        print('🆕 Criando segmento inicial para tarefa $id (atualização)');
        print(
          '   Segmento criado: ${task.dataInicio.toString().substring(0, 10)} até ${task.dataFim.toString().substring(0, 10)}',
        );
      }

      // Salvar segmentos no banco
      final segments = segmentsToSave.map((s) => _segmentToMap(s, id)).toList();
      print(
        '💾 Salvando ${segments.length} segmentos do Gantt para tarefa $id',
      );
      for (var seg in segments) {
        print(
          '     - ${seg['data_inicio']} até ${seg['data_fim']} (${seg['tipo']})',
        );
      }

      try {
        print('📤 Inserindo segmentos no banco:');
        for (var seg in segments) {
          print(
            '   - tipo: ${seg['tipo']}, início: ${seg['data_inicio']}, fim: ${seg['data_fim']}',
          );
        }
        await _supabase.from('gantt_segments').insert(segments);
        // Debug removido

        // Salvar períodos por executor se existirem
        print(
          '📋 Verificando períodos por executor na tarefa: ${task.executorPeriods.length}',
        );
        if (task.executorPeriods.isNotEmpty) {
          print(
            '💾 Salvando ${task.executorPeriods.length} períodos por executor...',
          );
          await _saveExecutorPeriods(id, task.executorPeriods);
        } else {
          print('🗑️ Nenhum período por executor, deletando existentes...');
          // Se não houver períodos por executor, deletar os existentes
          await _supabase.from('executor_periods').delete().eq('task_id', id);
        }

        // Salvar períodos por frota se existirem
        print(
          '📋 Verificando períodos por frota na tarefa: ${task.frotaPeriods.length}',
        );
        if (task.frotaPeriods.isNotEmpty) {
          print(
            '💾 Salvando ${task.frotaPeriods.length} períodos por frota...',
          );
          await _saveFrotaPeriods(id, task.frotaPeriods);
        } else {
          print('🗑️ Nenhum período por frota, deletando existentes...');
          await _supabase.from('frota_periods').delete().eq('task_id', id);
        }

        // Verificar se foram salvos corretamente
        final loadedSegments = await _loadGanttSegments(id, limit: 100);
        final loadedExecutorPeriods = await _loadExecutorPeriods(id);
        final loadedFrotaPeriods = await _loadFrotaPeriods(id);
        print(
          '📊 Segmentos carregados após atualização: ${loadedSegments.length}',
        );
        print(
          '📊 Períodos por executor carregados: ${loadedExecutorPeriods.length}',
        );
        print('📊 Períodos por frota carregados: ${loadedFrotaPeriods.length}');
        if (loadedSegments.length != segments.length) {
          print(
            '⚠️ AVISO: Número de segmentos salvos (${segments.length}) diferente do número carregado (${loadedSegments.length})',
          );
        }

        // Verificar se os tipos foram preservados
        print('🔍 Verificando tipos dos segmentos:');
        for (var i = 0; i < segments.length && i < loadedSegments.length; i++) {
          final savedTipo = segments[i]['tipo'] as String;
          final loadedTipo = loadedSegments[i].tipo;
          if (savedTipo != loadedTipo) {
            print(
              '   ⚠️ SEGMENTO $i: Tipo salvo "$savedTipo" diferente do tipo carregado "$loadedTipo"',
            );
          } else {
            print(
              '   ✅ SEGMENTO $i: Tipo preservado corretamente: "$savedTipo"',
            );
          }
        }

        final updatedTask = task.copyWith(
          ganttSegments: loadedSegments,
          executorPeriods: loadedExecutorPeriods,
          frotaPeriods: loadedFrotaPeriods,
        );

        // Atualizar a view de execuções para refletir a alteração
        await refreshMvExecucoesDia();

        // Notificar outras abas sobre a atualização da tarefa
        if (kIsWeb) {
          try {
            TabSyncService().notifyTaskUpdated(id);
          } catch (e) {
            print('⚠️ Erro ao notificar atualização de tarefa: $e');
          }
        }

        return updatedTask;
      } catch (e) {
        print('❌ Erro ao salvar segmentos: $e');
        print('   Stack trace: ${StackTrace.current}');
        rethrow;
      }
    } catch (e) {
      print('Erro ao atualizar tarefa: $e');
      // Fallback para mock
      final index = _tasks.indexWhere((t) => t.id == id);
      if (index == -1) return null;
      _tasks[index] = task;
      return task;
    }
  }

  Future<bool> deleteTask(String id) async {
    if (!_useSupabase) {
      final index = _tasks.indexWhere((task) => task.id == id);
      if (index == -1) return false;
      // Remover também todas as subtarefas
      _tasks.removeWhere((t) => t.id == id || t.parentId == id);
      return true;
    }

    try {
      // O Supabase vai deletar automaticamente os segmentos e subtarefas
      // devido ao CASCADE nas foreign keys
      await _supabase.from('tasks').delete().eq('id', id);

      // Atualizar a view de execuções para refletir a exclusão
      await refreshMvExecucoesDia();

      // Notificar outras abas sobre a exclusão da tarefa
      if (kIsWeb) {
        try {
          TabSyncService().notifyTaskDeleted(id);
        } catch (e) {
          print('⚠️ Erro ao notificar exclusão de tarefa: $e');
        }
      }

      // Deletar do banco local também
      try {
        final db = await _localDb.database;
        await db.delete('tasks_local', where: 'id = ?', whereArgs: [id]);
        await db.delete(
          'tasks_locais_local',
          where: 'task_id = ?',
          whereArgs: [id],
        );
        await db.delete(
          'tasks_executores_local',
          where: 'task_id = ?',
          whereArgs: [id],
        );
        await db.delete(
          'gantt_segments_local',
          where: 'task_id = ?',
          whereArgs: [id],
        );
      } catch (e) {
        print('⚠️ Erro ao deletar tarefa do banco local: $e');
      }

      return true;
    } catch (e) {
      print('Erro ao deletar tarefa do Supabase: $e');
      // Se offline ou erro, deletar apenas do banco local
      try {
        final db = await _localDb.database;
        await db.delete('tasks_local', where: 'id = ?', whereArgs: [id]);
        await db.delete(
          'tasks_locais_local',
          where: 'task_id = ?',
          whereArgs: [id],
        );
        await db.delete(
          'tasks_executores_local',
          where: 'task_id = ?',
          whereArgs: [id],
        );
        await db.delete(
          'gantt_segments_local',
          where: 'task_id = ?',
          whereArgs: [id],
        );

        // Adicionar à fila de sincronização
        await _syncService.queueOperation('tasks', 'delete', id, {'id': id});
      } catch (e2) {
        print('❌ Erro ao deletar tarefa do banco local: $e2');
        return false;
      }

      return true;
    }
  }

  // Métodos para gerenciar subtarefas
  Future<List<Task>> getSubtasks(String parentId) async {
    if (!_useSupabase) {
      return _tasks.where((task) => task.parentId == parentId).toList();
    }

    try {
      dynamic response;
      try {
        response = await _supabase
            .from('tasks')
            .select('''
            *,
            status!left(codigo, status),
            regionais!left(regional),
            divisoes!left(divisao),
            segmentos!left(segmento),
            tasks_locais!left(locais!inner(id, local)),
            tasks_executores!left(executores!inner(id, nome, nome_completo)),
            tasks_equipes!left(equipes!inner(id, nome, equipes_executores!left(executor_id, papel, executores!inner(id, nome)))),
            tasks_frotas!left(frota!inner(id, nome, placa, marca))
          ''')
            .eq('parent_id', parentId)
            .order('data_inicio');
      } catch (e) {
        final isNetworkError =
            e.toString().contains('Failed to fetch') ||
            e.toString().contains('SocketException') ||
            e.toString().contains('Connection');
        if (isNetworkError) {
          if (kDebugMode) {
            print(
              '⚠️ Rede indisponível ao buscar subtarefas (parent_id=$parentId), usando cache local.',
            );
          }
          return _tasks.where((task) => task.parentId == parentId).toList();
        }
        if (kDebugMode) {
          print(
            '⚠️ Erro ao buscar subtarefas com joins, tentando select simples: ${e.runtimeType}',
          );
        }
        response = await _supabase
            .from('tasks')
            .select()
            .eq('parent_id', parentId)
            .order('data_inicio');
      }

      if (response.isEmpty) return [];

      final tasks = <Task>[];
      for (var map in response as List) {
        final task = _taskFromMap(map as Map<String, dynamic>);
        final segments = await _loadGanttSegments(task.id, limit: 100);
        // Se não houver segmentos, criar um inicial baseado nas datas da tarefa
        final finalSegments = segments.isEmpty
            ? [
                GanttSegment(
                  dataInicio: task.dataInicio,
                  dataFim: task.dataFim,
                  label: task.tarefa,
                  tipo: _mapTaskTypeToSegmentType(task.tipo),
                  tipoPeriodo: 'EXECUCAO',
                ),
              ]
            : segments;
        tasks.add(task.copyWith(ganttSegments: finalSegments));
      }

      return tasks;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Erro ao buscar subtarefas ($parentId): ${e.runtimeType}');
      }
      return _tasks.where((task) => task.parentId == parentId).toList();
    }
  }

  Future<Task> createSubtask(String parentId, Task subtask) async {
    final newSubtask = subtask.copyWith(
      parentId: parentId,
      dataCriacao: DateTime.now(),
      dataAtualizacao: DateTime.now(),
    );

    if (!_useSupabase) {
      final subtaskWithId = newSubtask.copyWith(id: 'SUBTASK_${_nextId++}');
      _tasks.add(subtaskWithId);
      return subtaskWithId;
    }

    try {
      final taskMap = _taskToMap(newSubtask);
      taskMap.remove('id');

      final response = await _supabase
          .from('tasks')
          .insert(taskMap)
          .select()
          .single();

      final createdSubtask = _taskFromMap(response);

      // Garantir que sempre haja pelo menos um segmento
      // Se não houver segmentos, criar um inicial baseado nas datas da subtarefa
      List<GanttSegment> segmentsToSave = newSubtask.ganttSegments;
      if (segmentsToSave.isEmpty) {
        final segmentType = _mapTaskTypeToSegmentType(newSubtask.tipo);
        segmentsToSave = [
          GanttSegment(
            dataInicio: newSubtask.dataInicio,
            dataFim: newSubtask.dataFim,
            label: newSubtask.tarefa,
            tipo: segmentType,
            tipoPeriodo: 'EXECUCAO',
          ),
        ];
      }

      // Salvar segmentos no banco
      final segments = segmentsToSave
          .map((s) => _segmentToMap(s, createdSubtask.id))
          .toList();

      print(
        '💾 Salvando ${segments.length} segmentos do Gantt para subtarefa ${createdSubtask.id}',
      );
      for (var seg in segments) {
        print(
          '     - tipo: ${seg['tipo']}, início: ${seg['data_inicio']}, fim: ${seg['data_fim']}',
        );
      }

      await _supabase.from('gantt_segments').insert(segments);
      // Debug removido

      // Carregar segmentos recém-criados para garantir que estão corretos
      final loadedSegments = await _loadGanttSegments(
        createdSubtask.id,
        limit: 100,
      );
      print(
        '📊 Segmentos carregados após criação da subtarefa: ${loadedSegments.length}',
      );
      if (loadedSegments.length != segments.length) {
        print(
          '⚠️ AVISO: Número de segmentos salvos (${segments.length}) diferente do número carregado (${loadedSegments.length})',
        );
      }
      for (var seg in loadedSegments) {
        print(
          '     - ${seg.dataInicio.toString().substring(0, 10)} até ${seg.dataFim.toString().substring(0, 10)} (${seg.tipo})',
        );
      }

      // Atualizar a view de execuções para refletir a criação da subtarefa
      await refreshMvExecucoesDia();

      return createdSubtask.copyWith(ganttSegments: loadedSegments);
    } catch (e) {
      print('Erro ao criar subtarefa: $e');
      final subtaskWithId = newSubtask.copyWith(id: 'SUBTASK_${_nextId++}');
      _tasks.add(subtaskWithId);
      return subtaskWithId;
    }
  }

  // Obter apenas tarefas principais (sem pai)
  Future<List<Task>> getMainTasks() async {
    final allTasks = await getAllTasks();
    return allTasks.where((task) => task.parentId == null).toList();
  }

  // Atualiza a materialized view de execuções dia-a-dia após alterações relevantes
  // NOTA: Se estiver usando view normal (v_execucoes_dia_completa), não precisa de refresh
  // Método público para permitir atualização manual da view materializada (se ainda estiver em uso)
  Future<void> refreshMvExecucoesDia() async {
    if (!_useSupabase) return;
    try {
      // Tentar atualizar a view materializada (se ainda estiver em uso)
      // Se estiver usando view normal, este método não faz nada (view normal atualiza automaticamente)
      try {
        print('🔄 Atualizando mv_execucoes_dia_completa (se existir)...');
        await _supabase.rpc('refresh_mv_execucoes_dia_completa');
        print('✅ mv_execucoes_dia_completa atualizada');
      } catch (e) {
        // Se a view materializada não existir, tentar view antiga
        try {
          print(
            '⚠️ View materializada completa não encontrada, tentando view antiga: $e',
          );
          print('🔄 Atualizando mv_execucoes_dia...');
          await _supabase.rpc('refresh_mv_execucoes_dia');
          print('✅ mv_execucoes_dia atualizada');
        } catch (e2) {
          // Se nenhuma view materializada existir, provavelmente está usando view normal
          // View normal atualiza automaticamente, então não precisa fazer nada
          print(
            'ℹ️ Nenhuma view materializada encontrada. Usando view normal (atualiza automaticamente)',
          );
        }
      }
    } catch (e) {
      // Não bloquear o fluxo se o refresh falhar; apenas logar
      print('⚠️ Não foi possível atualizar views materializadas: $e');
      print(
        'ℹ️ Se estiver usando view normal (v_execucoes_dia_completa), isso é esperado',
      );
    }
  }

  // Aplicar filtros de perfil do usuário automaticamente
  Future<List<Task>> _aplicarFiltrosPerfil(List<Task> tasks) async {
    try {
      final authService = AuthServiceSimples();
      final usuario = authService.currentUser;

      // Se não há usuário logado, não retornar nenhuma tarefa
      if (usuario == null) {
        print('⚠️ Usuário não autenticado - nenhuma tarefa será exibida');
        return [];
      }

      // Usuários root têm acesso a todas as tarefas
      if (usuario.isRoot) {
        print('🔓 Usuário ROOT detectado - acesso total a todas as tarefas');
        print('   Email: ${usuario.email}');
        print('   Nome: ${usuario.nome}');
        // debug silenciado
        return tasks;
      }

      // debug silenciado
      // debug silenciado

      // Se não tem perfil configurado, não retornar nenhuma tarefa
      if (!usuario.temPerfilConfigurado()) {
        print(
          '⚠️ Usuário sem perfil configurado - nenhuma tarefa será exibida',
        );
        return [];
      }

      // Log do perfil do usuário
      // Debug removido
      // debug silenciado
      // debug silenciado
      // debug silenciado
      // debug silenciado
      // debug silenciado
      // debug silenciado

      // Filtrar tarefas baseado no perfil do usuário
      // Debug removido
      final tarefasFiltradas = tasks.where((task) {
        bool passaRegional = true;
        bool passaDivisao = true;
        bool passaSegmento = true;

        // Verificar acesso à regional
        if (usuario.regionalIds.isNotEmpty) {
          passaRegional =
              task.regionalId != null &&
              usuario.temAcessoRegional(task.regionalId);
          // Debug removido
        }

        // Verificar acesso à divisão
        if (usuario.divisaoIds.isNotEmpty) {
          passaDivisao =
              task.divisaoId != null &&
              usuario.temAcessoDivisao(task.divisaoId);
          // Debug removido
        }

        // Verificar acesso ao segmento
        if (usuario.segmentoIds.isNotEmpty) {
          passaSegmento =
              task.segmentoId != null &&
              usuario.temAcessoSegmento(task.segmentoId);
          // Debug removido
        }

        final passa = passaRegional && passaDivisao && passaSegmento;
        // Debug removido
        return passa;
      }).toList();

      // Debug removido
      return tarefasFiltradas;
    } catch (e) {
      print('Erro ao aplicar filtros de perfil: $e');
      return []; // Em caso de erro, não retornar nenhuma tarefa por segurança
    }
  }

  // Filtros (listas = multiseleção; null ou vazio = sem filtro)
  Future<List<Task>> filterTasks({
    List<String>? status,
    List<String>? regional,
    List<String>? divisao,
    List<String>? local,
    List<String>? tipo,
    List<String>? executor,
    List<String>? coordenador,
    List<String>? frota,
    DateTime? dataInicioMin,
    DateTime? dataFimMax,
  }) async {
    // Alternar automaticamente para modo offline quando não for mock
    final isConnected = _connectivity.isConnected;
    if (!_isMockData) {
      _useSupabase = isConnected;
    }

    // Se cache está fresco ou estamos offline/mode mock, usar local
    final cacheFresh = await _localDb.isCacheFresh(
      'tasks_local',
      _tasksCacheTtl,
    );

    // Verificar se o range de datas mudou — se sim, forçar re-query do Supabase
    final dateRangeChanged =
        _lastFilterDateStart != dataInicioMin ||
        _lastFilterDateEnd != dataFimMax;
    if (dateRangeChanged) {
      _logDebug(
        '[cache] Range de datas mudou: '
        '${_lastFilterDateStart?.toIso8601String()} → ${dataInicioMin?.toIso8601String()}, '
        '${_lastFilterDateEnd?.toIso8601String()} → ${dataFimMax?.toIso8601String()} — invalidando cache',
      );
    }
    _lastFilterDateStart = dataInicioMin;
    _lastFilterDateEnd = dataFimMax;

    final shouldUseLocal =
        (!_useSupabase || cacheFresh || !isConnected) && !dateRangeChanged;

    if (shouldUseLocal) {
      // Sempre recarregar do banco local para garantir dados cacheados
      _tasks = await _getAllTasksFromLocal();

      final totalSw = Stopwatch()..start();
      final entrada = _tasks.length;
      _logDebug(
        '⏱ [filters/local] start | in=$entrada | status=$status, regional=$regional, '
        'divisao=$divisao, local=$local, tipo=$tipo, executor=$executor, '
        'coordenador=$coordenador, frota=$frota, '
        'dataInicioMin=${dataInicioMin?.toIso8601String()}, dataFimMax=${dataFimMax?.toIso8601String()}',
      );

      bool matchOne(String? value, List<String>? filterList) {
        if (filterList == null || filterList.isEmpty) return true;
        if (value == null) return false;
        final parts = value
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty);
        return parts.any((p) => filterList.contains(p));
      }

      final filtradas = _tasks
          .where((task) {
            if (status != null &&
                status.isNotEmpty &&
                !status.contains(task.status)) {
              return false;
            }
            if (regional != null &&
                regional.isNotEmpty &&
                !regional.contains(task.regional)) {
              return false;
            }
            if (divisao != null &&
                divisao.isNotEmpty &&
                !divisao.contains(task.divisao)) {
              return false;
            }
            if (local != null &&
                local.isNotEmpty &&
                !task.locais.any((l) => local.contains(l))) {
              return false;
            }
            if (tipo != null && tipo.isNotEmpty && !matchOne(task.tipo, tipo)) {
              return false;
            }
            if (executor != null && executor.isNotEmpty) {
              final execList = task.executores
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();
              final execFromField = task.executor
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty);
              final match =
                  execList.any((e) => executor.contains(e)) ||
                  execFromField.any((e) => executor.contains(e));
              if (!match) return false;
            }
            if (coordenador != null &&
                coordenador.isNotEmpty &&
                !matchOne(task.coordenador, coordenador)) {
              return false;
            }
            if (frota != null &&
                frota.isNotEmpty &&
                !matchOne(task.frota, frota)) {
              return false;
            }
            // Filtrar por período considerando os segmentos do Gantt
            if (dataInicioMin != null || dataFimMax != null) {
              // Se a tarefa tem segmentos, verificar se algum está no período
              if (task.ganttSegments.isNotEmpty) {
                bool hasSegmentInRange = false;

                for (var segment in task.ganttSegments) {
                  final segmentStart = DateTime(
                    segment.dataInicio.year,
                    segment.dataInicio.month,
                    segment.dataInicio.day,
                  );
                  final segmentEnd = DateTime(
                    segment.dataFim.year,
                    segment.dataFim.month,
                    segment.dataFim.day,
                  );

                  bool segmentInRange = true;

                  if (dataInicioMin != null) {
                    final periodStart = DateTime(
                      dataInicioMin.year,
                      dataInicioMin.month,
                      dataInicioMin.day,
                    );
                    if (segmentEnd.isBefore(periodStart)) {
                      segmentInRange = false;
                    }
                  }

                  if (dataFimMax != null && segmentInRange) {
                    final periodEnd = DateTime(
                      dataFimMax.year,
                      dataFimMax.month,
                      dataFimMax.day,
                    );
                    if (segmentStart.isAfter(periodEnd)) {
                      segmentInRange = false;
                    }
                  }

                  if (segmentInRange) {
                    hasSegmentInRange = true;
                    break;
                  }
                }

                if (!hasSegmentInRange) return false;
              } else {
                // Se não tem segmentos, usar as datas principais da tarefa
                if (dataInicioMin != null &&
                    task.dataFim.isBefore(dataInicioMin)) {
                  return false;
                }
                if (dataFimMax != null && task.dataInicio.isAfter(dataFimMax)) {
                  return false;
                }
              }
            }
            return true;
          })
          .map((task) {
            if (task.ganttSegments.isEmpty) {
              final fallbackSegment = GanttSegment(
                dataInicio: task.dataInicio,
                dataFim: task.dataFim,
                label: task.tarefa,
                tipo: _mapTaskTypeToSegmentType(task.tipo),
                tipoPeriodo: 'EXECUCAO',
              );
              return task.copyWith(ganttSegments: [fallbackSegment]);
            }
            return task;
          })
          .toList();

      totalSw.stop();
      _logDebug(
        '⏱ [filters/local] done | out=${filtradas.length} | tempo=${totalSw.elapsedMilliseconds}ms',
      );
      return filtradas;
    }

    try {
      // Filtro LOCAL via M:N (tasks_locais -> locais): obter task_ids antes da query principal
      List<String>? taskIdsForLocalFilter;
      if (local != null && local.isNotEmpty) {
        try {
          final locaisRes = await _supabase
              .from('locais')
              .select('id')
              .inFilter('local', local);
          final localIds = <String>[];
          for (final r in locaisRes) {
            final id = r['id']?.toString();
            if (id != null && id.isNotEmpty) localIds.add(id);
          }
          if (localIds.isEmpty) {
            if (kDebugMode) {
              _logDebug(
                '[LOCAL] Filtro local M:N: nenhum id em locais para nomes=$local -> retorno vazio',
              );
            }
            return [];
          }
          final tlRes = await _supabase
              .from('tasks_locais')
              .select('task_id')
              .inFilter('local_id', localIds);
          final ids = <String>{};
          for (final r in tlRes) {
            final tid = r['task_id']?.toString();
            if (tid != null && tid.isNotEmpty) ids.add(tid);
          }
          taskIdsForLocalFilter = ids.toList();
          if (kDebugMode) {
            _logDebug(
              '[LOCAL] Filtro local M:N: ${taskIdsForLocalFilter.length} task_ids para locais=$local',
            );
          }
          if (taskIdsForLocalFilter.isEmpty) return [];
        } catch (e) {
          if (kDebugMode) _logDebug('⚠️ [filterTasks] Filtro local M:N: $e');
          return [];
        }
      }

      dynamic response;

      // Query principal: sem gantt_segments (carregados em batch); tasks_locais com locais!left para não perder linhas
      try {
        final querySw = Stopwatch()..start();
        var query = _supabase.from('tasks').select('''
            *, local,
            status!left(codigo, status),
            regionais!left(regional),
            divisoes!left(divisao),
            segmentos!left(segmento),
            tasks_locais!left(local_id, locais!left(id, local)),
            tasks_executores!left(executores!left(id, nome, nome_completo)),
            tasks_equipes!left(equipes!left(id, nome, equipes_executores!left(executor_id, papel, executores!left(id, nome)))),
            tasks_frotas!left(frota!left(id, nome, placa, marca))
          ''');

        if (status != null && status.isNotEmpty) {
          if (status.length == 1) {
            query = query.eq('status', status.single);
          } else {
            query = query.inFilter('status', status);
          }
        }
        if (regional != null && regional.isNotEmpty) {
          if (regional.length == 1) {
            query = query.eq('regional', regional.single);
          } else {
            query = query.inFilter('regional', regional);
          }
        }
        if (divisao != null && divisao.isNotEmpty) {
          if (divisao.length == 1) {
            query = query.eq('divisao', divisao.single);
          } else {
            query = query.inFilter('divisao', divisao);
          }
        }
        if (taskIdsForLocalFilter != null) {
          query = query.inFilter('id', taskIdsForLocalFilter);
        }
        if (tipo != null && tipo.isNotEmpty) {
          if (tipo.length == 1) {
            query = query.eq('tipo', tipo.single);
          } else {
            query = query.inFilter('tipo', tipo);
          }
        }
        if (executor != null && executor.isNotEmpty) {
          if (executor.length == 1) {
            query = query.ilike('executor', '%${executor.single}%');
          } else {
            query = query.or(
              executor
                  .map((e) => 'executor.ilike.%${e.replaceAll('%', '\\%')}%')
                  .join(','),
            );
          }
        }
        if (coordenador != null && coordenador.isNotEmpty) {
          if (coordenador.length == 1) {
            query = query.eq('coordenador', coordenador.single);
          } else {
            query = query.inFilter('coordenador', coordenador);
          }
        }
        if (frota != null && frota.isNotEmpty) {
          if (frota.length == 1) {
            query = query.eq('frota', frota.single);
          } else {
            query = query.inFilter('frota', frota);
          }
        }
        // Overlap apenas em datas da tarefa; segmentos filtrados depois em batch
        if (dataFimMax != null) {
          query = query.lte('data_inicio', dataFimMax.toIso8601String());
        }
        if (dataInicioMin != null) {
          query = query.gte('data_fim', dataInicioMin.toIso8601String());
        }

        response = await query.order('data_inicio');
        querySw.stop();
      } catch (e) {
        print('⚠️ Erro ao filtrar tarefas com joins: $e');
        final querySw = Stopwatch()..start();
        var query = _supabase.from('tasks').select('''
            *, local,
            tasks_locais!left(local_id, locais!left(id, local))
          ''');

        if (status != null && status.isNotEmpty) {
          if (status.length == 1) {
            query = query.eq('status', status.single);
          } else {
            query = query.inFilter('status', status);
          }
        }
        if (regional != null && regional.isNotEmpty) {
          if (regional.length == 1) {
            query = query.eq('regional', regional.single);
          } else {
            query = query.inFilter('regional', regional);
          }
        }
        if (divisao != null && divisao.isNotEmpty) {
          if (divisao.length == 1) {
            query = query.eq('divisao', divisao.single);
          } else {
            query = query.inFilter('divisao', divisao);
          }
        }
        if (taskIdsForLocalFilter != null) {
          query = query.inFilter('id', taskIdsForLocalFilter);
        }
        if (tipo != null && tipo.isNotEmpty) {
          if (tipo.length == 1) {
            query = query.eq('tipo', tipo.single);
          } else {
            query = query.inFilter('tipo', tipo);
          }
        }
        if (executor != null && executor.isNotEmpty) {
          if (executor.length == 1) {
            query = query.ilike('executor', '%${executor.single}%');
          } else {
            query = query.or(
              executor
                  .map((e) => 'executor.ilike.%${e.replaceAll('%', '\\%')}%')
                  .join(','),
            );
          }
        }
        if (coordenador != null && coordenador.isNotEmpty) {
          if (coordenador.length == 1) {
            query = query.eq('coordenador', coordenador.single);
          } else {
            query = query.inFilter('coordenador', coordenador);
          }
        }
        if (frota != null && frota.isNotEmpty) {
          if (frota.length == 1) {
            query = query.eq('frota', frota.single);
          } else {
            query = query.inFilter('frota', frota);
          }
        }
        if (dataFimMax != null) {
          query = query.lte('data_inicio', dataFimMax.toIso8601String());
        }
        if (dataInicioMin != null) {
          query = query.gte('data_fim', dataInicioMin.toIso8601String());
        }

        response = await query.order('data_inicio');
        querySw.stop();
      }

      if (response.isEmpty) return [];

      final procSw = Stopwatch()..start();
      final rows = response as List;

      // DEBUG: forma real da resposta (PostgREST pode usar chaves diferentes ou aninhamento)
      if (kDebugMode && rows.isNotEmpty) {
        final first = rows.first as Map<String, dynamic>;
        final topKeys = first.keys.toList()..sort();
        final localVal = first['local'];
        final tasksLocaisVal = first['tasks_locais'];
        _logDebug(
          '[LOCAL] 1ª row keys (${topKeys.length}): ${topKeys.join(', ')}',
        );
        _logDebug(
          '[LOCAL] first["local"] = $localVal (${localVal.runtimeType})',
        );
        _logDebug(
          '[LOCAL] first["tasks_locais"] = ${tasksLocaisVal.runtimeType} ${tasksLocaisVal is List ? "length=${(tasksLocaisVal).length}" : ""}',
        );
        if (tasksLocaisVal is List && (tasksLocaisVal).isNotEmpty) {
          final item = (tasksLocaisVal).first;
          _logDebug('[LOCAL] tasks_locais[0] = $item');
        } else if (tasksLocaisVal is Map<String, dynamic>) {
          _logDebug(
            '[LOCAL] tasks_locais(single) keys: ${(tasksLocaisVal as Map).keys.join(', ')}',
          );
        }
      }

      // Deduplicar por id e mesclar locais (PostgREST duplica linhas por tasks_locais)
      final byId = <String, Task>{};
      for (var map in rows) {
        final task = _taskFromMap(map as Map<String, dynamic>);
        if (byId.containsKey(task.id)) {
          final existing = byId[task.id]!;
          final mergedLocais = <String>{
            ...existing.locais,
            ...task.locais,
          }.toList();
          final mergedLocalIds = <String>{
            ...existing.localIds,
            ...task.localIds,
          }.toList();
          byId[task.id] = existing.copyWith(
            locais: mergedLocais,
            localIds: mergedLocalIds,
          );
        } else {
          byId[task.id] = task;
        }
      }
      final tasksBase = byId.values.toList();
      final taskIds = byId.keys.toList();

      if (kDebugMode) {
        final semLocais = tasksBase.where((t) => t.locais.isEmpty).length;
        _logDebug(
          '[LOCAL] filterTasks: ${tasksBase.length} tarefas (dedup), $semLocais sem locais após _taskFromMap',
        );
      }

      // Buscar segmentos em lote já filtrados por período
      final segMap = await _loadGanttSegmentsBatch(
        taskIds,
        dataInicioMin: dataInicioMin,
        dataFimMax: dataFimMax,
        limitPerTask: 200,
      );

      // Buscar períodos por executor e por frota em lote (conflito de frota no Gantt usa frotaIds/frotaPeriods)
      final epMap = await _loadExecutorPeriodsBatch(taskIds);
      final fpMap = await _loadFrotaPeriodsBatch(taskIds);

      final tasks = <Task>[];
      for (final task in tasksBase) {
        final segments = segMap[task.id] ?? [];
        // Se não houver segmentos vindos do banco (ou filtrados), cria um fallback baseado na tarefa
        final fallbackSegment = GanttSegment(
          dataInicio: task.dataInicio,
          dataFim: task.dataFim,
          label: task.tarefa,
          tipo: _mapTaskTypeToSegmentType(task.tipo),
          tipoPeriodo: 'EXECUCAO',
        );
        List<GanttSegment> finalSegments = segments.isNotEmpty
            ? segments
            : [fallbackSegment];

        // Se houver filtro de período, remover segmentos fora do intervalo; se nenhum segmento ficar no período, descartar a tarefa
        if (dataInicioMin != null || dataFimMax != null) {
          final filtered = <GanttSegment>[];
          for (final seg in finalSegments) {
            final segStart = DateTime(
              seg.dataInicio.year,
              seg.dataInicio.month,
              seg.dataInicio.day,
            );
            final segEnd = DateTime(
              seg.dataFim.year,
              seg.dataFim.month,
              seg.dataFim.day,
            );
            bool ok = true;
            if (dataInicioMin != null &&
                segEnd.isBefore(
                  DateTime(
                    dataInicioMin.year,
                    dataInicioMin.month,
                    dataInicioMin.day,
                  ),
                )) {
              ok = false;
            }
            if (dataFimMax != null &&
                segStart.isAfter(
                  DateTime(dataFimMax.year, dataFimMax.month, dataFimMax.day),
                )) {
              ok = false;
            }
            if (ok) filtered.add(seg);
          }
          finalSegments = filtered;
          // Se não há segmento no período, não inclui a tarefa
          if (finalSegments.isEmpty) {
            continue;
          }
        }

        final executorPeriods = epMap[task.id] ?? [];
        final frotaPeriods = fpMap[task.id] ?? [];

        tasks.add(
          task.copyWith(
            ganttSegments: finalSegments,
            executorPeriods: executorPeriods,
            frotaPeriods: frotaPeriods,
          ),
        );
      }

      // Preencher coluna LOCAL: se o join não trouxe nomes (tasks_locais/locais), buscar por localIds
      final tasksWithLocais = await _enrichTasksLocaisFromIds(tasks);
      if (kDebugMode) {
        final comLocais = tasksWithLocais
            .where((t) => t.locais.isNotEmpty)
            .length;
        _logDebug(
          '[LOCAL] filterTasks: após _enrichTasksLocaisFromIds, $comLocais tarefas com locais',
        );
      }

      // Aplicar filtros de perfil do usuário
      final tasksFiltradas = await _aplicarFiltrosPerfil(tasksWithLocais);

      // Atualizar cache local como 'synced' para reutilizar offline/TTL
      for (final task in tasksFiltradas) {
        try {
          await _saveTaskToLocal(task, markSynced: true);
        } catch (e) {
          print('⚠️ Erro ao salvar tarefa no cache local: $e');
        }
      }
      procSw.stop();
      // debug removido
      return tasksFiltradas;
    } catch (e) {
      print('Erro ao filtrar tarefas: $e');
      return [];
    }
  }

  // Busca
  Future<List<Task>> searchTasks(String query) async {
    if (query.isEmpty) return await getAllTasks();

    if (!_useSupabase) {
      final lowerQuery = query.toLowerCase();
      return _tasks.where((task) {
        return task.tarefa.toLowerCase().contains(lowerQuery) ||
            (task.ordem?.toLowerCase().contains(lowerQuery) ?? false) ||
            task.executor.toLowerCase().contains(lowerQuery) ||
            task.coordenador.toLowerCase().contains(lowerQuery) ||
            task.locais.any((l) => l.toLowerCase().contains(lowerQuery));
      }).toList();
    }

    try {
      dynamic response;
      try {
        response = await _supabase
            .from('tasks')
            .select('''
            *,
            status!left(codigo, status),
            regionais!left(regional),
            divisoes!left(divisao),
            segmentos!left(segmento),
            tasks_locais!left(locais!inner(id, local)),
            tasks_executores!left(executores!inner(id, nome, nome_completo)),
            tasks_equipes!left(equipes!inner(id, nome, equipes_executores!left(executor_id, papel, executores!inner(id, nome)))),
            tasks_frotas!left(frota!inner(id, nome, placa, marca))
          ''')
            .or(
              'tarefa.ilike.%$query%,ordem.ilike.%$query%,executor.ilike.%$query%,coordenador.ilike.%$query%',
            )
            .order('data_inicio');
      } catch (e) {
        // Fallback se joins falharem
        print('⚠️ Erro ao buscar tarefas com joins: $e');
        response = await _supabase
            .from('tasks')
            .select()
            .or(
              'tarefa.ilike.%$query%,ordem.ilike.%$query%,executor.ilike.%$query%,coordenador.ilike.%$query%',
            )
            .order('data_inicio');
      }

      if (response.isEmpty) return [];

      final tasks = <Task>[];
      for (var map in response as List) {
        final task = _taskFromMap(map as Map<String, dynamic>);
        final segments = await _loadGanttSegments(task.id, limit: 100);
        // Se não houver segmentos, criar um inicial baseado nas datas da tarefa
        final finalSegments = segments.isEmpty
            ? [
                GanttSegment(
                  dataInicio: task.dataInicio,
                  dataFim: task.dataFim,
                  label: task.tarefa,
                  tipo: _mapTaskTypeToSegmentType(task.tipo),
                  tipoPeriodo: 'EXECUCAO',
                ),
              ]
            : segments;
        tasks.add(task.copyWith(ganttSegments: finalSegments));
      }

      return tasks;
    } catch (e) {
      print('Erro ao buscar tarefas: $e');
      return [];
    }
  }

  // Estatísticas
  // IMPORTANTE: Aceita lista opcional de tarefas para evitar buscar todas do banco
  // Se tasks não for fornecida, usa getAllTasks() (pode ser pesado - evitar em produção)
  Future<Map<String, dynamic>> getStatistics({List<Task>? tasks}) async {
    final allTasks = tasks ?? await getAllTasks(aplicarPerfil: true);
    final total = allTasks.length;
    final porStatus = <String, int>{};
    final porTipo = <String, int>{};
    final porRegional = <String, int>{};
    int emAndamento = 0;
    int concluidas = 0;
    int programadas = 0;
    int canceladas = 0;
    int atrasadas = 0;
    int venceHoje = 0;
    int semExecutor = 0;
    int semLocal = 0;
    int semCoordenador = 0;

    final now = DateTime.now();
    final List<Task> atrasadasList = [];
    final List<Task> venceHojeList = [];
    final List<Task> semExecutorList = [];
    final List<Task> semLocalList = [];
    final List<Task> semCoordenadorList = [];
    final List<Task> canceladasList = [];
    final List<Task> emAndamentoList = [];
    final List<Task> programadasList = [];
    final List<Task> concluidasList = [];
    final List<Task> listaTotal = [];

    for (var task in allTasks) {
      listaTotal.add(task);
      final status = task.status.trim().toUpperCase();
      final isConcluida = status.contains('CONC') || status.contains('RPAR');
      final isAndamento = status.contains('ANDA');
      final isProgramada = status.contains('PROG');
      final isCancelada = status.contains('CANC');

      porStatus[task.status.isEmpty ? 'Sem Status' : task.status] =
          (porStatus[task.status.isEmpty ? 'Sem Status' : task.status] ?? 0) +
          1;
      porTipo[task.tipo.isEmpty ? 'Sem Tipo' : task.tipo] =
          (porTipo[task.tipo.isEmpty ? 'Sem Tipo' : task.tipo] ?? 0) + 1;
      porRegional[task.regional.isEmpty ? 'Sem Regional' : task.regional] =
          (porRegional[task.regional.isEmpty
                  ? 'Sem Regional'
                  : task.regional] ??
              0) +
          1;

      if (isConcluida) {
        concluidas++;
        concluidasList.add(task);
      } else if (isAndamento) {
        emAndamento++;
        emAndamentoList.add(task);
      } else if (isProgramada) {
        programadas++;
        programadasList.add(task);
      } else if (isCancelada) {
        canceladas++;
        canceladasList.add(task);
      }

      if (task.executor.isEmpty && task.executores.isEmpty) {
        semExecutor++;
        semExecutorList.add(task);
      }
      if (task.locais.isEmpty &&
          (task.localId == null || task.localId!.isEmpty)) {
        semLocal++;
        semLocalList.add(task);
      }
      if (task.coordenador.isEmpty) {
        semCoordenador++;
        semCoordenadorList.add(task);
      }

      // Prazos e datas
      final fim = task.dataFim;
      if (!isConcluida &&
          !isCancelada &&
          (isAndamento || isProgramada) &&
          fim.isBefore(now)) {
        atrasadas++;
        atrasadasList.add(task);
      } else if (!isConcluida &&
          !isCancelada &&
          fim.year == now.year &&
          fim.month == now.month &&
          fim.day == now.day) {
        venceHoje++;
        venceHojeList.add(task);
      }
    }

    return {
      'total': total,
      'emAndamento': emAndamento,
      'concluidas': concluidas,
      'programadas': programadas,
      'canceladas': canceladas,
      'atrasadas': atrasadas,
      'venceHoje': venceHoje,
      'semExecutor': semExecutor,
      'semLocal': semLocal,
      'semCoordenador': semCoordenador,
      'listaAtrasadas': atrasadasList,
      'listaVenceHoje': venceHojeList,
      'listaSemExecutor': semExecutorList,
      'listaSemLocal': semLocalList,
      'listaSemCoordenador': semCoordenadorList,
      'listaCanceladas': canceladasList,
      'listaEmAndamento': emAndamentoList,
      'listaProgramadas': programadasList,
      'listaConcluidas': concluidasList,
      'listaTotal': listaTotal,
      'porStatus': porStatus,
      'porTipo': porTipo,
      'porRegional': porRegional,
    };
  }

  // Buscar valores únicos de filtros baseado no período e perfil do usuário
  // OTIMIZADO: Usa função SQL do Supabase em vez de buscar todas as tarefas
  Future<Map<String, List<String>>> getFilterValues({
    DateTime? dataInicioMin,
    DateTime? dataFimMax,
    String? status,
    String? regional,
    String? divisao,
    String? local,
    String? tipo,
    String? executor,
    String? coordenador,
    String? frota,
  }) async {
    if (!_useSupabase) {
      // Fallback para modo offline/mock
      return {
        'regionais': [],
        'divisoes': [],
        'status': [],
        'locais': [],
        'tipos': [],
        'executores': [],
        'frotas': [],
        'coordenadores': [],
      };
    }

    try {
      print('📋 Buscando valores de filtros via função SQL otimizada...');

      // Chamar função SQL do Supabase via RPC
      final response = await _supabase.rpc(
        'get_valores_filtros',
        params: {
          'p_data_inicio_min': dataInicioMin?.toIso8601String(),
          'p_data_fim_max': dataFimMax?.toIso8601String(),
          'p_status': status,
          'p_regional': regional,
          'p_divisao': divisao,
          'p_local': local,
          'p_tipo': tipo,
          'p_executor': executor,
          'p_coordenador': coordenador,
          'p_frota': frota,
        },
      );

      final results = response as List;

      // Agrupar valores por tipo de filtro
      final regionais = <String>{};
      final divisoes = <String>{};
      final statusValues = <String>{};
      final locais = <String>{};
      final tipos = <String>{};
      final executores = <String>{};
      final frotas = <String>{};
      final coordenadores = <String>{};

      for (var row in results) {
        final tipoFiltro = row['tipo_filtro'] as String?;
        final valor = row['valor'] as String?;

        if (valor == null || valor.isEmpty) continue;

        switch (tipoFiltro) {
          case 'regional':
            regionais.add(valor);
            break;
          case 'divisao':
            divisoes.add(valor);
            break;
          case 'status':
            statusValues.add(valor);
            break;
          case 'local':
            locais.add(valor);
            break;
          case 'tipo':
            tipos.add(valor);
            break;
          case 'executor':
            executores.add(valor);
            break;
          case 'frota':
            frotas.add(valor);
            break;
          case 'coordenador':
            coordenadores.add(valor);
            break;
        }
      }

      print('✅ Valores de filtros carregados:');
      print('   Regionais: ${regionais.length}');
      print('   Divisões: ${divisoes.length}');
      print('   Status: ${statusValues.length}');
      print('   Locais: ${locais.length}');
      print('   Tipos: ${tipos.length}');
      print('   Executores: ${executores.length}');
      print('   Frotas: ${frotas.length}');
      print('   Coordenadores: ${coordenadores.length}');

      return {
        'regionais': regionais.toList()..sort(),
        'divisoes': divisoes.toList()..sort(),
        'status': statusValues.toList()..sort(),
        'locais': locais.toList()..sort(),
        'tipos': tipos.toList()..sort(),
        'executores': executores.toList()..sort(),
        'frotas': frotas.toList()..sort(),
        'coordenadores': coordenadores.toList()..sort(),
      };
    } catch (e, stackTrace) {
      print('❌ Erro ao buscar valores de filtros via função SQL: $e');
      print('   Stack trace: $stackTrace');
      // Fallback: usar método antigo se a função não existir
      print('🔄 Tentando método antigo como fallback...');
      try {
        final tasks = await filterTasks(
          dataInicioMin: dataInicioMin,
          dataFimMax: dataFimMax,
          status: status != null ? [status] : null,
          regional: regional != null ? [regional] : null,
          divisao: divisao != null ? [divisao] : null,
          local: local != null ? [local] : null,
          tipo: tipo != null ? [tipo] : null,
          executor: executor != null ? [executor] : null,
          coordenador: coordenador != null ? [coordenador] : null,
          frota: frota != null ? [frota] : null,
        );

        final regionais = <String>{};
        final divisoes = <String>{};
        final statusValues = <String>{};
        final locais = <String>{};
        final tipos = <String>{};
        final executores = <String>{};
        final frotas = <String>{};
        final coordenadores = <String>{};

        for (var task in tasks) {
          if (task.regional.isNotEmpty) regionais.add(task.regional);
          if (task.divisao.isNotEmpty) divisoes.add(task.divisao);
          if (task.status.isNotEmpty) statusValues.add(task.status);
          for (var localItem in task.locais) {
            if (localItem.isNotEmpty) locais.add(localItem);
          }
          if (task.tipo.isNotEmpty) tipos.add(task.tipo);
          for (var executorItem in task.executores) {
            if (executorItem.isNotEmpty) executores.add(executorItem);
          }
          if (task.frota.isNotEmpty) frotas.add(task.frota);
          if (task.coordenador.isNotEmpty) coordenadores.add(task.coordenador);
        }

        return {
          'regionais': regionais.toList()..sort(),
          'divisoes': divisoes.toList()..sort(),
          'status': statusValues.toList()..sort(),
          'locais': locais.toList()..sort(),
          'tipos': tipos.toList()..sort(),
          'executores': executores.toList()..sort(),
          'frotas': frotas.toList()..sort(),
          'coordenadores': coordenadores.toList()..sort(),
        };
      } catch (e2) {
        print('❌ Erro no fallback também: $e2');
        return {
          'regionais': [],
          'divisoes': [],
          'status': [],
          'locais': [],
          'tipos': [],
          'executores': [],
          'frotas': [],
          'coordenadores': [],
        };
      }
    }
  }

  // Exportar para CSV
  Future<String> exportToCSV() async {
    final allTasks = await getAllTasks();
    final buffer = StringBuffer();
    buffer.writeln(
      'ID,Status,Regional,Divisão,Local,Tipo,Ordem,Tarefa,Executor,Frota,Coordenador,SI,Data Início,Data Fim',
    );

    for (var task in allTasks) {
      buffer.writeln(
        [
          task.id,
          task.status,
          task.regional,
          task.divisao,
          task.locais.join('; '),
          task.tipo,
          task.ordem ?? '',
          '"${task.tarefa}"',
          '"${task.executor}"',
          task.frota,
          task.coordenador,
          task.si,
          '${task.dataInicio.day}/${task.dataInicio.month}/${task.dataInicio.year}',
          '${task.dataFim.day}/${task.dataFim.month}/${task.dataFim.year}',
        ].join(','),
      );
    }

    return buffer.toString();
  }

  /// Subscribe para mudanças em tempo real na tabela tasks
  /// Retorna um RealtimeChannel que pode ser usado para escutar INSERT, UPDATE e DELETE
  RealtimeChannel subscribeToTasks({
    required void Function(Task task) onUpsert,
    required void Function(String taskId) onDelete,
  }) {
    final channel = _supabase
        .channel('public:tasks')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'tasks',
          callback: (payload) {
            try {
              final record = payload.newRecord;
              final task = _taskFromMap(record);
              print(
                '📡 TaskService: Nova tarefa detectada via Realtime: ${task.id}',
              );
              onUpsert(task);
            } catch (e) {
              print('⚠️ Erro ao processar INSERT de tarefa via Realtime: $e');
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'tasks',
          callback: (payload) {
            try {
              final record = payload.newRecord;
              final task = _taskFromMap(record);
              print(
                '📡 TaskService: Tarefa atualizada via Realtime: ${task.id}',
              );
              onUpsert(task);
            } catch (e) {
              print('⚠️ Erro ao processar UPDATE de tarefa via Realtime: $e');
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'tasks',
          callback: (payload) {
            try {
              final record = payload.oldRecord;
              if (record['id'] != null) {
                final taskId = record['id'] as String;
                print('📡 TaskService: Tarefa deletada via Realtime: $taskId');
                onDelete(taskId);
              }
            } catch (e) {
              print('⚠️ Erro ao processar DELETE de tarefa via Realtime: $e');
            }
          },
        )
        .subscribe();

    print('✅ TaskService: Subscription Realtime ativada para tabela tasks');
    return channel;
  }
}
