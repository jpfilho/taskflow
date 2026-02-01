import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

class LocalDatabaseService {
  static final LocalDatabaseService _instance = LocalDatabaseService._internal();
  factory LocalDatabaseService() => _instance;
  LocalDatabaseService._internal();

  static Database? _database;
  static const String _databaseName = 'taskflow_local.db';
  static const int _databaseVersion = 3;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // No web, sqflite usa IndexedDB e não há path_provider; evitar MissingPluginException
    if (kIsWeb) {
      return await openDatabase(
        inMemoryDatabasePath,
        version: _databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    }

    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _databaseName);
    
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Tabela de sincronização (fila de operações pendentes)
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        operation TEXT NOT NULL,
        record_id TEXT NOT NULL,
        data TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        synced INTEGER DEFAULT 0,
        status TEXT DEFAULT 'pending', -- pending, retrying, failed, done
        retry_count INTEGER DEFAULT 0,
        backoff_ms INTEGER DEFAULT 0,
        next_retry_at INTEGER,
        last_error TEXT
      )
    ''');

    // Tabela de tarefas local
    await db.execute('''
      CREATE TABLE tasks_local (
        id TEXT PRIMARY KEY,
        status TEXT NOT NULL,
        regional TEXT,
        divisao TEXT,
        local TEXT,
        tipo TEXT,
        ordem TEXT,
        tarefa TEXT NOT NULL,
        executor TEXT,
        frota TEXT,
        coordenador TEXT,
        si TEXT,
        data_inicio INTEGER,
        data_fim INTEGER,
        observacoes TEXT,
        horas_previstas REAL,
        horas_executadas REAL,
        prioridade TEXT,
        parent_id TEXT,
        segmento_id TEXT,
        regional_id TEXT,
        divisao_id TEXT,
        data_criacao INTEGER,
        data_atualizacao INTEGER,
        created_at INTEGER,
        updated_at INTEGER,
        sync_status TEXT DEFAULT 'pending',
        last_synced INTEGER
      )
    ''');

    // Tabela de segmentos Gantt local
    await db.execute('''
      CREATE TABLE gantt_segments_local (
        id TEXT PRIMARY KEY,
        task_id TEXT NOT NULL,
        data_inicio INTEGER NOT NULL,
        data_fim INTEGER NOT NULL,
        label TEXT,
        tipo TEXT NOT NULL,
        tipo_periodo TEXT DEFAULT 'EXECUCAO',
        sync_status TEXT DEFAULT 'pending',
        last_synced INTEGER,
        FOREIGN KEY (task_id) REFERENCES tasks_local(id) ON DELETE CASCADE
      )
    ''');

    // Tabela de relacionamentos tasks_locais
    await db.execute('''
      CREATE TABLE tasks_locais_local (
        task_id TEXT NOT NULL,
        local_id TEXT NOT NULL,
        PRIMARY KEY (task_id, local_id),
        FOREIGN KEY (task_id) REFERENCES tasks_local(id) ON DELETE CASCADE
      )
    ''');

    // Tabela de relacionamentos tasks_executores
    await db.execute('''
      CREATE TABLE tasks_executores_local (
        task_id TEXT NOT NULL,
        executor_id TEXT NOT NULL,
        PRIMARY KEY (task_id, executor_id),
        FOREIGN KEY (task_id) REFERENCES tasks_local(id) ON DELETE CASCADE
      )
    ''');

    // Tabela de relacionamentos tasks_equipes
    await db.execute('''
      CREATE TABLE tasks_equipes_local (
        task_id TEXT NOT NULL,
        equipe_id TEXT NOT NULL,
        PRIMARY KEY (task_id, equipe_id),
        FOREIGN KEY (task_id) REFERENCES tasks_local(id) ON DELETE CASCADE
      )
    ''');

    // Tabela de relacionamentos tasks_frotas
    await db.execute('''
      CREATE TABLE tasks_frotas_local (
        task_id TEXT NOT NULL,
        frota_id TEXT NOT NULL,
        PRIMARY KEY (task_id, frota_id),
        FOREIGN KEY (task_id) REFERENCES tasks_local(id) ON DELETE CASCADE
      )
    ''');

    // Tabela de anexos local
    await db.execute('''
      CREATE TABLE anexos_local (
        id TEXT PRIMARY KEY,
        task_id TEXT NOT NULL,
        nome_arquivo TEXT NOT NULL,
        tipo_arquivo TEXT,
        tamanho INTEGER,
        url TEXT,
        caminho_local TEXT,
        data_upload INTEGER,
        sync_status TEXT DEFAULT 'pending',
        last_synced INTEGER,
        FOREIGN KEY (task_id) REFERENCES tasks_local(id) ON DELETE CASCADE
      )
    ''');

    // Tabela de usuários local (para login offline)
    await db.execute('''
      CREATE TABLE usuarios_local (
        id TEXT PRIMARY KEY,
        email TEXT UNIQUE NOT NULL,
        nome TEXT,
        senha_hash TEXT,
        is_root INTEGER DEFAULT 0,
        ativo INTEGER DEFAULT 1,
        data_criacao INTEGER,
        data_atualizacao INTEGER,
        sync_status TEXT DEFAULT 'pending',
        last_synced INTEGER
      )
    ''');

    // Tabela de perfil do usuário local
    await db.execute('''
      CREATE TABLE usuarios_regionais_local (
        usuario_id TEXT NOT NULL,
        regional_id TEXT NOT NULL,
        PRIMARY KEY (usuario_id, regional_id),
        FOREIGN KEY (usuario_id) REFERENCES usuarios_local(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE usuarios_divisoes_local (
        usuario_id TEXT NOT NULL,
        divisao_id TEXT NOT NULL,
        PRIMARY KEY (usuario_id, divisao_id),
        FOREIGN KEY (usuario_id) REFERENCES usuarios_local(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE usuarios_segmentos_local (
        usuario_id TEXT NOT NULL,
        segmento_id TEXT NOT NULL,
        PRIMARY KEY (usuario_id, segmento_id),
        FOREIGN KEY (usuario_id) REFERENCES usuarios_local(id) ON DELETE CASCADE
      )
    ''');

    // Tabela de regionais local
    await db.execute('''
      CREATE TABLE regionais_local (
        id TEXT PRIMARY KEY,
        regional TEXT NOT NULL,
        sigla TEXT,
        sync_status TEXT DEFAULT 'pending',
        last_synced INTEGER
      )
    ''');

    // Tabela de divisões local
    await db.execute('''
      CREATE TABLE divisoes_local (
        id TEXT PRIMARY KEY,
        divisao TEXT NOT NULL,
        sigla TEXT,
        regional_id TEXT,
        sync_status TEXT DEFAULT 'pending',
        last_synced INTEGER
      )
    ''');

    // Tabela de segmentos local
    await db.execute('''
      CREATE TABLE segmentos_local (
        id TEXT PRIMARY KEY,
        segmento TEXT NOT NULL,
        divisao_id TEXT,
        sync_status TEXT DEFAULT 'pending',
        last_synced INTEGER
      )
    ''');

    // Tabela de locais local
    await db.execute('''
      CREATE TABLE locais_local (
        id TEXT PRIMARY KEY,
        local TEXT NOT NULL,
        regional_id TEXT,
        divisao_id TEXT,
        segmento_id TEXT,
        sync_status TEXT DEFAULT 'pending',
        last_synced INTEGER
      )
    ''');

    // Tabela de executores local
    await db.execute('''
      CREATE TABLE executores_local (
        id TEXT PRIMARY KEY,
        nome TEXT NOT NULL,
        nome_completo TEXT,
        funcao TEXT,
        empresa TEXT,
        matricula TEXT,
        ativo INTEGER DEFAULT 1,
        sync_status TEXT DEFAULT 'pending',
        last_synced INTEGER
      )
    ''');

    // Tabela de tipos de atividade local
    await db.execute('''
      CREATE TABLE tipos_atividade_local (
        codigo TEXT PRIMARY KEY,
        tipo TEXT NOT NULL,
        cor TEXT,
        sync_status TEXT DEFAULT 'pending',
        last_synced INTEGER
      )
    ''');

    // Tabela de status local
    await db.execute('''
      CREATE TABLE status_local (
        codigo TEXT PRIMARY KEY,
        status TEXT NOT NULL,
        cor TEXT,
        sync_status TEXT DEFAULT 'pending',
        last_synced INTEGER
      )
    ''');

    // Tabela de feriados local
    await db.execute('''
      CREATE TABLE feriados_local (
        id TEXT PRIMARY KEY,
        dia INTEGER NOT NULL,
        mes INTEGER NOT NULL,
        ano INTEGER,
        descricao TEXT NOT NULL,
        tipo TEXT,
        pais TEXT,
        estado TEXT,
        cidade TEXT,
        sync_status TEXT DEFAULT 'pending',
        last_synced INTEGER
      )
    ''');

    // Tabela de frota local
    await db.execute('''
      CREATE TABLE frota_local (
        id TEXT PRIMARY KEY,
        nome TEXT NOT NULL,
        marca TEXT,
        tipo_veiculo TEXT NOT NULL,
        placa TEXT NOT NULL,
        regional_id TEXT,
        regional TEXT,
        divisao_id TEXT,
        divisao TEXT,
        segmento_id TEXT,
        segmento TEXT,
        em_manutencao INTEGER DEFAULT 0,
        observacoes TEXT,
        ativo INTEGER DEFAULT 1,
        created_at TEXT,
        updated_at TEXT,
        sync_status TEXT DEFAULT 'pending',
        last_synced INTEGER
      )
    ''');

    // Índices para melhor performance
    await db.execute('CREATE INDEX idx_tasks_local_parent_id ON tasks_local(parent_id)');
    await db.execute('CREATE INDEX idx_tasks_local_status ON tasks_local(status)');
    await db.execute('CREATE INDEX idx_tasks_local_regional ON tasks_local(regional)');
    await db.execute('CREATE INDEX idx_gantt_segments_local_task_id ON gantt_segments_local(task_id)');
    await db.execute('CREATE INDEX idx_tasks_equipes_local_task_id ON tasks_equipes_local(task_id)');
    await db.execute('CREATE INDEX idx_tasks_frotas_local_task_id ON tasks_frotas_local(task_id)');
    await db.execute('CREATE INDEX idx_sync_queue_synced ON sync_queue(synced)');
    await db.execute('CREATE INDEX idx_sync_queue_table ON sync_queue(table_name)');
    await db.execute('CREATE INDEX idx_sync_queue_next_retry ON sync_queue(next_retry_at)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Adicionar colunas de backoff/retry na fila
      try {
        await db.execute("ALTER TABLE sync_queue ADD COLUMN status TEXT DEFAULT 'pending'");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE sync_queue ADD COLUMN retry_count INTEGER DEFAULT 0");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE sync_queue ADD COLUMN backoff_ms INTEGER DEFAULT 0");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE sync_queue ADD COLUMN next_retry_at INTEGER");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE sync_queue ADD COLUMN last_error TEXT");
      } catch (_) {}
      try {
        await db.execute('CREATE INDEX idx_sync_queue_next_retry ON sync_queue(next_retry_at)');
      } catch (_) {}
    }
    if (oldVersion < 3) {
      try {
        await db.execute('''
          CREATE TABLE tasks_equipes_local (
            task_id TEXT NOT NULL,
            equipe_id TEXT NOT NULL,
            PRIMARY KEY (task_id, equipe_id),
            FOREIGN KEY (task_id) REFERENCES tasks_local(id) ON DELETE CASCADE
          )
        ''');
      } catch (_) {}
      try {
        await db.execute('''
          CREATE TABLE tasks_frotas_local (
            task_id TEXT NOT NULL,
            frota_id TEXT NOT NULL,
            PRIMARY KEY (task_id, frota_id),
            FOREIGN KEY (task_id) REFERENCES tasks_local(id) ON DELETE CASCADE
          )
        ''');
      } catch (_) {}
      try {
        await db.execute('CREATE INDEX idx_tasks_equipes_local_task_id ON tasks_equipes_local(task_id)');
      } catch (_) {}
      try {
        await db.execute('CREATE INDEX idx_tasks_frotas_local_task_id ON tasks_frotas_local(task_id)');
      } catch (_) {}
    }
  }

  // Métodos para gerenciar fila de sincronização
  Future<int> addToSyncQueue(
    String tableName,
    String operation,
    String recordId,
    Map<String, dynamic> data, {
    String status = 'pending',
    int retryCount = 0,
    int backoffMs = 0,
    int? nextRetryAt,
    String? lastError,
  }) async {
    final db = await database;
    return await db.insert('sync_queue', {
      'table_name': tableName,
      'operation': operation,
      'record_id': recordId,
      'data': jsonEncode(data),
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'synced': 0,
      'status': status,
      'retry_count': retryCount,
      'backoff_ms': backoffMs,
      'next_retry_at': nextRetryAt,
      'last_error': lastError,
    });
  }

  Future<List<Map<String, dynamic>>> getPendingSyncItems({int? limit}) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    return await db.query(
      'sync_queue',
      where: 'synced = ? AND (status = ? OR status = ?) AND (next_retry_at IS NULL OR next_retry_at <= ?)',
      whereArgs: [0, 'pending', 'retrying', now],
      orderBy: 'created_at ASC',
      limit: limit,
    );
  }

  Future<void> coalesceSyncQueueItem(
    String tableName,
    String operation,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    final db = await database;
    final pending = await db.query(
      'sync_queue',
      where: 'synced = ? AND table_name = ? AND record_id = ? AND (status = ? OR status = ?)',
      whereArgs: [0, tableName, recordId, 'pending', 'retrying'],
      orderBy: 'created_at DESC',
    );

    Map<String, dynamic>? keep;
    if (pending.isNotEmpty) {
      if (operation == 'delete') {
        // Remover pendencias anteriores e inserir delete
        await db.delete(
          'sync_queue',
          where: 'synced = ? AND table_name = ? AND record_id = ?',
          whereArgs: [0, tableName, recordId],
        );
        await addToSyncQueue(tableName, operation, recordId, data);
        return;
      }

      // Preferir insert quando existe (para evitar update de registro inexistente)
      keep = pending.firstWhere(
        (row) => row['operation'] == 'insert',
        orElse: () => pending.firstWhere(
          (row) => row['operation'] == 'update',
          orElse: () => pending.first,
        ),
      );

      if (keep['operation'] == 'delete') {
        // Se ja existe delete pendente, nao sobrescrever
        return;
      }
    }

    if (keep != null && keep['id'] != null) {
      final keepId = keep['id'] as int;
      final keepOperation = keep['operation'] as String?;
      String effectiveOperation = operation;
      if (keepOperation == 'insert' || operation == 'insert') {
        effectiveOperation = 'insert';
      } else if (keepOperation == 'update' || operation == 'update') {
        effectiveOperation = 'update';
      } else {
        effectiveOperation = keepOperation ?? operation;
      }
      await db.update(
        'sync_queue',
        {
          'data': jsonEncode(data),
          'operation': effectiveOperation,
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'status': 'pending',
          'retry_count': 0,
          'backoff_ms': 0,
          'next_retry_at': null,
          'last_error': null,
        },
        where: 'id = ?',
        whereArgs: [keepId],
      );
      // Remover duplicados pendentes do mesmo registro
      await db.delete(
        'sync_queue',
        where: 'synced = ? AND table_name = ? AND record_id = ? AND id != ?',
        whereArgs: [0, tableName, recordId, keepId],
      );
    } else {
      await addToSyncQueue(tableName, operation, recordId, data);
    }
  }

  Future<void> markAsSynced(int syncQueueId) async {
    final db = await database;
    await db.update(
      'sync_queue',
      {'synced': 1, 'status': 'done', 'last_error': null, 'retry_count': 0, 'backoff_ms': 0, 'next_retry_at': null},
      where: 'id = ?',
      whereArgs: [syncQueueId],
    );
  }

  Future<void> markAsFailed(int syncQueueId, String error, int retryCount, int backoffMs, int? nextRetryAt) async {
    final db = await database;
    await db.update(
      'sync_queue',
      {
        'status': 'retrying',
        'last_error': error,
        'retry_count': retryCount,
        'backoff_ms': backoffMs,
        'next_retry_at': nextRetryAt,
      },
      where: 'id = ?',
      whereArgs: [syncQueueId],
    );
  }

  Future<void> markAsPermanentlyFailed(int syncQueueId, String error) async {
    final db = await database;
    await db.update(
      'sync_queue',
      {
        'status': 'failed',
        'last_error': error,
        'next_retry_at': null,
      },
      where: 'id = ?',
      whereArgs: [syncQueueId],
    );
  }

  Future<void> clearSyncedItems() async {
    final db = await database;
    await db.delete('sync_queue', where: 'synced = ?', whereArgs: [1]);
  }

  Future<List<String>> _getRelationIds({
    required String tableName,
    required String taskId,
    required String relationColumn,
  }) async {
    final db = await database;
    final rows = await db.query(
      tableName,
      columns: [relationColumn],
      where: 'task_id = ?',
      whereArgs: [taskId],
    );
    return rows
        .map((row) => row[relationColumn])
        .whereType<String>()
        .toList();
  }

  Future<List<String>> getTaskLocalIds(String taskId) async {
    return _getRelationIds(
      tableName: 'tasks_locais_local',
      taskId: taskId,
      relationColumn: 'local_id',
    );
  }

  Future<List<String>> getTaskExecutorIds(String taskId) async {
    return _getRelationIds(
      tableName: 'tasks_executores_local',
      taskId: taskId,
      relationColumn: 'executor_id',
    );
  }

  Future<List<String>> getTaskEquipeIds(String taskId) async {
    return _getRelationIds(
      tableName: 'tasks_equipes_local',
      taskId: taskId,
      relationColumn: 'equipe_id',
    );
  }

  Future<List<String>> getTaskFrotaIds(String taskId) async {
    return _getRelationIds(
      tableName: 'tasks_frotas_local',
      taskId: taskId,
      relationColumn: 'frota_id',
    );
  }


  // Métodos para gerenciar status de sincronização
  Future<void> updateSyncStatus(String tableName, String recordId, String status) async {
    final db = await database;
    final tableNameLocal = '${tableName}_local';
    
    try {
      await db.update(
        tableNameLocal,
        {
          'sync_status': status,
          'last_synced': status == 'synced' ? DateTime.now().millisecondsSinceEpoch : null,
        },
        where: 'id = ?',
        whereArgs: [recordId],
      );
    } catch (e) {
      print('Erro ao atualizar status de sincronização: $e');
    }
  }

  /// Obtém o timestamp mais recente de last_synced de uma tabela local.
  Future<int?> getMaxLastSynced(String localTable) async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        'SELECT MAX(last_synced) as max_synced FROM $localTable WHERE last_synced IS NOT NULL',
      );
      if (result.isEmpty) return null;
      final value = result.first['max_synced'];
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString());
    } catch (e) {
      print('Erro ao obter max(last_synced) de $localTable: $e');
      return null;
    }
  }

  /// Verifica se o cache está fresco considerando o TTL informado.
  Future<bool> isCacheFresh(String localTable, Duration ttl) async {
    final maxSynced = await getMaxLastSynced(localTable);
    if (maxSynced == null) return false;
    final ageMs = DateTime.now().millisecondsSinceEpoch - maxSynced;
    return ageMs <= ttl.inMilliseconds;
  }

  // Limpar banco local (útil para testes ou reset)
  Future<void> clearLocalDatabase() async {
    final db = await database;
    await db.delete('sync_queue');
    await db.delete('gantt_segments_local');
    await db.delete('tasks_locais_local');
    await db.delete('tasks_executores_local');
    await db.delete('tasks_equipes_local');
    await db.delete('tasks_frotas_local');
    await db.delete('anexos_local');
    await db.delete('tasks_local');
    await db.delete('usuarios_regionais_local');
    await db.delete('usuarios_divisoes_local');
    await db.delete('usuarios_segmentos_local');
    await db.delete('usuarios_local');
    await db.delete('regionais_local');
    await db.delete('divisoes_local');
    await db.delete('segmentos_local');
    await db.delete('locais_local');
    await db.delete('executores_local');
    await db.delete('tipos_atividade_local');
    await db.delete('status_local');
    await db.delete('feriados_local');
  }

  // Fechar banco
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}

