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
  static const int _databaseVersion = 1;

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
        synced INTEGER DEFAULT 0
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
    await db.execute('CREATE INDEX idx_sync_queue_synced ON sync_queue(synced)');
    await db.execute('CREATE INDEX idx_sync_queue_table ON sync_queue(table_name)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Implementar migrações futuras aqui
  }

  // Métodos para gerenciar fila de sincronização
  Future<int> addToSyncQueue(String tableName, String operation, String recordId, Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('sync_queue', {
      'table_name': tableName,
      'operation': operation,
      'record_id': recordId,
      'data': jsonEncode(data),
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'synced': 0,
    });
  }

  Future<List<Map<String, dynamic>>> getPendingSyncItems() async {
    final db = await database;
    return await db.query(
      'sync_queue',
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'created_at ASC',
    );
  }

  Future<void> markAsSynced(int syncQueueId) async {
    final db = await database;
    await db.update(
      'sync_queue',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [syncQueueId],
    );
  }

  Future<void> clearSyncedItems() async {
    final db = await database;
    await db.delete('sync_queue', where: 'synced = ?', whereArgs: [1]);
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

  // Limpar banco local (útil para testes ou reset)
  Future<void> clearLocalDatabase() async {
    final db = await database;
    await db.delete('sync_queue');
    await db.delete('gantt_segments_local');
    await db.delete('tasks_locais_local');
    await db.delete('tasks_executores_local');
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

