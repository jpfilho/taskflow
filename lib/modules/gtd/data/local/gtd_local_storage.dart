import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
// FFI desktop: garantir databaseFactory antes de openDatabase
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
// Web: factory para SQLite na web (Wasm)
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../models/gtd_models.dart';

/// Banco local GTD (SQLite) — tabelas espelho e sync_queue.
/// Usa sqflite; em web usa banco em memória.
class GtdLocalStorage {
  static final GtdLocalStorage _instance = GtdLocalStorage._();
  factory GtdLocalStorage.instance() => _instance;

  GtdLocalStorage._();

  static const String _dbName = 'gtd_local.db';
  static const int _version = 5;

  Database? _db;
  Future<Database?>? _openFuture;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    _openFuture ??= _open();
    _db = await _openFuture!;
    return _db!;
  }

  Future<Database> _open() async {
    try {
      Database db;
      if (kIsWeb) {
        // Web: usar factory Wasm antes de openDatabase
        databaseFactory = databaseFactoryFfiWeb;
        debugPrint('GTD local DB: abrindo in-memory (web)');
        db = await openDatabase(
          inMemoryDatabasePath,
          version: _version,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
        );
      } else {
        // Desktop/mobile: garantir factory FFI antes de openDatabase
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        final dir = await getApplicationDocumentsDirectory();
        final path = p.join(dir.path, _dbName);
        debugPrint('GTD local DB: abrindo $path');
        db = await openDatabase(
          path,
          version: _version,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
        );
      }
      // Garantir que o esquema existe (web às vezes não chama onCreate)
      await _ensureSchema(db);
      return db;
    } catch (e, st) {
      debugPrint('GTD local DB: falha ao abrir: $e\n$st');
      rethrow;
    }
  }

  /// Cria tabelas se não existirem (corrige web onde onCreate pode não rodar).
  Future<void> _ensureSchema(Database db) async {
    try {
      final r = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='gtd_inbox'",
      );
      if (r.isEmpty) {
        debugPrint('GTD local DB: tabela gtd_inbox ausente, criando esquema');
        await _onCreate(db, _version);
      }
    } catch (e) {
      debugPrint('GTD local DB: _ensureSchema: $e');
      rethrow;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS gtd_sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        op TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        next_retry_at INTEGER NOT NULL,
        tries INTEGER NOT NULL DEFAULT 0,
        last_error TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS gtd_contexts (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS gtd_projects (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        notes TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS gtd_inbox (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        content TEXT NOT NULL,
        processed_at INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS gtd_reference (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS gtd_actions (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        project_id TEXT,
        context_id TEXT,
        title TEXT NOT NULL,
        status TEXT NOT NULL,
        energy TEXT,
        priority TEXT,
        time_min INTEGER,
        due_at INTEGER,
        waiting_for TEXT,
        notes TEXT,
        linked_task_id TEXT,
        is_routine INTEGER NOT NULL DEFAULT 0,
        recurrence_rule TEXT,
        recurrence_weekdays TEXT,
        alarm_at INTEGER,
        source_inbox_id TEXT,
        delegated_to_user_id TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS gtd_weekly_reviews (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        notes TEXT,
        completed_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_gtd_sync_queue_next ON gtd_sync_queue(next_retry_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_gtd_inbox_user_processed ON gtd_inbox(user_id, processed_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_gtd_actions_user_status ON gtd_actions(user_id, status)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_gtd_actions_updated ON gtd_actions(updated_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_gtd_contexts_user ON gtd_contexts(user_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_gtd_projects_user ON gtd_projects(user_id)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE gtd_actions ADD COLUMN is_routine INTEGER DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE gtd_actions ADD COLUMN recurrence_rule TEXT',
      );
      await db.execute(
        'ALTER TABLE gtd_actions ADD COLUMN recurrence_weekdays TEXT',
      );
      await db.execute(
        'ALTER TABLE gtd_actions ADD COLUMN alarm_at INTEGER',
      );
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE gtd_actions ADD COLUMN source_inbox_id TEXT',
      );
    }
    if (oldVersion < 4) {
      await db.execute(
        'ALTER TABLE gtd_actions ADD COLUMN delegated_to_user_id TEXT',
      );
    }
    if (oldVersion < 5) {
      await db.execute(
        'ALTER TABLE gtd_actions ADD COLUMN priority TEXT',
      );
    }
  }

  static int _toEpoch(DateTime d) => d.toUtc().millisecondsSinceEpoch;
  static DateTime _fromEpoch(int ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);

  // ---------- Sync queue ----------
  Future<void> enqueueSync({
    required String entity,
    required String entityId,
    required String op,
    required Map<String, dynamic> payload,
  }) async {
    final db = await _database;
    final now = DateTime.now().toUtc();
    await db.insert('gtd_sync_queue', {
      'entity': entity,
      'entity_id': entityId,
      'op': op,
      'payload_json': jsonEncode(payload),
      'created_at': _toEpoch(now),
      'next_retry_at': _toEpoch(now),
      'tries': 0,
    });
  }

  Future<List<GtdSyncQueueItem>> getPendingSyncItems() async {
    final db = await _database;
    final now = _toEpoch(DateTime.now().toUtc());
    final list = await db.query(
      'gtd_sync_queue',
      where: 'next_retry_at <= ?',
      whereArgs: [now],
      orderBy: 'next_retry_at ASC',
    );
    return list
        .map(
          (row) => GtdSyncQueueItem(
            id: row['id'] as int,
            entity: row['entity'] as String,
            entityId: row['entity_id'] as String,
            op: row['op'] as String,
            payloadJson: row['payload_json'] as String,
            createdAt: _fromEpoch(row['created_at'] as int),
            nextRetryAt: _fromEpoch(row['next_retry_at'] as int),
            tries: row['tries'] as int,
            lastError: row['last_error'] as String?,
          ),
        )
        .toList();
  }

  Future<void> updateSyncItemRetry(
    int id, {
    required DateTime nextRetryAt,
    String? lastError,
  }) async {
    final db = await _database;
    final tries = await getSyncItemTries(id);
    await db.update(
      'gtd_sync_queue',
      {
        'next_retry_at': _toEpoch(nextRetryAt),
        'tries': tries + 1,
        'last_error': lastError,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteSyncItem(int id) async {
    final db = await _database;
    await db.delete('gtd_sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>?> getSyncItemPayload(int id) async {
    final db = await _database;
    final rows = await db.query(
      'gtd_sync_queue',
      columns: ['payload_json'],
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    return jsonDecode(rows.first['payload_json'] as String)
        as Map<String, dynamic>;
  }

  Future<int> getSyncItemTries(int id) async {
    final db = await _database;
    final rows = await db.query(
      'gtd_sync_queue',
      columns: ['tries'],
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return 0;
    return rows.first['tries'] as int;
  }

  // ---------- Contexts ----------
  Future<void> upsertContext(GtdContext c) async {
    final db = await _database;
    await db.insert('gtd_contexts', {
      'id': c.id,
      'user_id': c.userId,
      'name': c.name,
      'created_at': _toEpoch(c.createdAt),
      'updated_at': _toEpoch(c.updatedAt),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<GtdContext>> getContexts(String userId) async {
    final db = await _database;
    final rows = await db.query(
      'gtd_contexts',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'name',
    );
    return rows
        .map(
          (r) => GtdContext(
            id: r['id'] as String,
            userId: r['user_id'] as String,
            name: r['name'] as String,
            createdAt: _fromEpoch(r['created_at'] as int),
            updatedAt: _fromEpoch(r['updated_at'] as int),
          ),
        )
        .toList();
  }

  // ---------- Projects ----------
  Future<void> upsertProject(GtdProject p) async {
    final db = await _database;
    await db.insert('gtd_projects', {
      'id': p.id,
      'user_id': p.userId,
      'name': p.name,
      'notes': p.notes,
      'created_at': _toEpoch(p.createdAt),
      'updated_at': _toEpoch(p.updatedAt),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<GtdProject>> getProjects(String userId) async {
    final db = await _database;
    final rows = await db.query(
      'gtd_projects',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'name',
    );
    return rows
        .map(
          (r) => GtdProject(
            id: r['id'] as String,
            userId: r['user_id'] as String,
            name: r['name'] as String,
            notes: r['notes'] as String?,
            createdAt: _fromEpoch(r['created_at'] as int),
            updatedAt: _fromEpoch(r['updated_at'] as int),
          ),
        )
        .toList();
  }

  // ---------- Inbox ----------
  Future<void> insertInbox(GtdInboxItem item) async {
    final db = await _database;
    await db.insert('gtd_inbox', {
      'id': item.id,
      'user_id': item.userId,
      'content': item.content,
      'processed_at': item.processedAt != null
          ? _toEpoch(item.processedAt!)
          : null,
      'created_at': _toEpoch(item.createdAt),
      'updated_at': _toEpoch(item.updatedAt),
    });
  }

  Future<void> updateInbox(GtdInboxItem item) async {
    final db = await _database;
    await db.update(
      'gtd_inbox',
      {
        'content': item.content,
        'processed_at': item.processedAt != null
            ? _toEpoch(item.processedAt!)
            : null,
        'updated_at': _toEpoch(item.updatedAt),
      },
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<void> upsertInbox(GtdInboxItem item) async {
    final db = await _database;
    await db.insert('gtd_inbox', {
      'id': item.id,
      'user_id': item.userId,
      'content': item.content,
      'processed_at': item.processedAt != null
          ? _toEpoch(item.processedAt!)
          : null,
      'created_at': _toEpoch(item.createdAt),
      'updated_at': _toEpoch(item.updatedAt),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteInbox(String id) async {
    final db = await _database;
    await db.delete('gtd_inbox', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<GtdInboxItem>> getInboxItems(
    String userId, {
    bool unprocessedOnly = false,
  }) async {
    final db = await _database;
    List<Map<String, dynamic>> rows;
    if (unprocessedOnly) {
      rows = await db.query(
        'gtd_inbox',
        where: 'user_id = ? AND processed_at IS NULL',
        whereArgs: [userId],
        orderBy: 'created_at DESC',
      );
    } else {
      rows = await db.query(
        'gtd_inbox',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'created_at DESC',
      );
    }
    return rows
        .map(
          (r) => GtdInboxItem(
            id: r['id'] as String,
            userId: r['user_id'] as String,
            content: r['content'] as String,
            processedAt: r['processed_at'] != null
                ? _fromEpoch(r['processed_at'] as int)
                : null,
            createdAt: _fromEpoch(r['created_at'] as int),
            updatedAt: _fromEpoch(r['updated_at'] as int),
          ),
        )
        .toList();
  }

  // ---------- Reference ----------
  Future<void> upsertReference(GtdReferenceItem r) async {
    final db = await _database;
    await db.insert('gtd_reference', {
      'id': r.id,
      'user_id': r.userId,
      'title': r.title,
      'content': r.content,
      'created_at': _toEpoch(r.createdAt),
      'updated_at': _toEpoch(r.updatedAt),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<GtdReferenceItem>> getReferenceItems(String userId) async {
    final db = await _database;
    final rows = await db.query(
      'gtd_reference',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'title',
    );
    return rows
        .map(
          (r) => GtdReferenceItem(
            id: r['id'] as String,
            userId: r['user_id'] as String,
            title: r['title'] as String,
            content: r['content'] as String?,
            createdAt: _fromEpoch(r['created_at'] as int),
            updatedAt: _fromEpoch(r['updated_at'] as int),
          ),
        )
        .toList();
  }

  // ---------- Actions ----------
  Future<void> upsertAction(GtdAction a) async {
    final db = await _database;
    await db.insert('gtd_actions', {
      'id': a.id,
      'user_id': a.userId,
      'project_id': a.projectId,
      'context_id': a.contextId,
      'title': a.title,
      'status': a.status.value,
      'energy': a.energy,
      'priority': a.priority,
      'time_min': a.timeMin,
      'due_at': a.dueAt != null ? _toEpoch(a.dueAt!) : null,
      'waiting_for': a.waitingFor,
      'notes': a.notes,
      'linked_task_id': a.linkedTaskId,
      'is_routine': a.isRoutine ? 1 : 0,
      'recurrence_rule': a.recurrenceRule,
      'recurrence_weekdays': a.recurrenceWeekdays,
      'alarm_at': a.alarmAt != null ? _toEpoch(a.alarmAt!) : null,
      'source_inbox_id': a.sourceInboxId,
      'delegated_to_user_id': a.delegatedToUserId,
      'created_at': _toEpoch(a.createdAt),
      'updated_at': _toEpoch(a.updatedAt),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<GtdAction>> getActions(
    String userId, {
    GtdActionStatus? status,
  }) async {
    final db = await _database;
    List<Map<String, dynamic>> rows;
    if (status != null) {
      rows = await db.query(
        'gtd_actions',
        where: 'user_id = ? AND status = ?',
        whereArgs: [userId, status.value],
        orderBy: 'due_at ASC NULLS LAST, created_at ASC',
      );
    } else {
      rows = await db.query(
        'gtd_actions',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'due_at ASC NULLS LAST, created_at ASC',
      );
    }
    return rows.map((r) => _actionFromRow(r)).toList();
  }

  GtdAction _actionFromRow(Map<String, dynamic> r) => GtdAction(
        id: r['id'] as String,
        userId: r['user_id'] as String,
        projectId: r['project_id'] as String?,
        contextId: r['context_id'] as String?,
        title: r['title'] as String,
        status:
            GtdActionStatusExt.fromString((r['status'] as String?) ?? 'next'),
        energy: r['energy'] as String?,
        priority: r['priority'] as String?,
        timeMin: r['time_min'] as int?,
        dueAt: r['due_at'] != null ? _fromEpoch(r['due_at'] as int) : null,
        waitingFor: r['waiting_for'] as String?,
        notes: r['notes'] as String?,
        linkedTaskId: r['linked_task_id'] as String?,
        isRoutine: (r['is_routine'] as int?) == 1,
        recurrenceRule: r['recurrence_rule'] as String?,
        recurrenceWeekdays: r['recurrence_weekdays'] as String?,
        alarmAt: r['alarm_at'] != null ? _fromEpoch(r['alarm_at'] as int) : null,
        sourceInboxId: r['source_inbox_id'] as String?,
        delegatedToUserId: r['delegated_to_user_id'] as String?,
        createdAt: _fromEpoch(r['created_at'] as int),
        updatedAt: _fromEpoch(r['updated_at'] as int),
      );

  Future<GtdInboxItem?> getInboxItem(String userId, String id) async {
    final db = await _database;
    final rows = await db.query(
      'gtd_inbox',
      where: 'user_id = ? AND id = ?',
      whereArgs: [userId, id],
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return GtdInboxItem(
      id: r['id'] as String,
      userId: r['user_id'] as String,
      content: r['content'] as String,
      processedAt: r['processed_at'] != null
          ? _fromEpoch(r['processed_at'] as int)
          : null,
      createdAt: _fromEpoch(r['created_at'] as int),
      updatedAt: _fromEpoch(r['updated_at'] as int),
    );
  }

  Future<void> deleteAction(String id) async {
    final db = await _database;
    await db.delete('gtd_actions', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Weekly reviews ----------
  Future<void> insertWeeklyReview(GtdWeeklyReview r) async {
    final db = await _database;
    await db.insert('gtd_weekly_reviews', {
      'id': r.id,
      'user_id': r.userId,
      'notes': r.notes,
      'completed_at': _toEpoch(r.completedAt),
      'created_at': _toEpoch(r.createdAt),
      'updated_at': _toEpoch(r.updatedAt),
    });
  }

  Future<List<GtdWeeklyReview>> getWeeklyReviews(
    String userId, {
    int limit = 20,
  }) async {
    final db = await _database;
    final rows = await db.query(
      'gtd_weekly_reviews',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'completed_at DESC',
      limit: limit,
    );
    return rows
        .map(
          (r) => GtdWeeklyReview(
            id: r['id'] as String,
            userId: r['user_id'] as String,
            notes: r['notes'] as String?,
            completedAt: _fromEpoch(r['completed_at'] as int),
            createdAt: _fromEpoch(r['created_at'] as int),
            updatedAt: _fromEpoch(r['updated_at'] as int),
          ),
        )
        .toList();
  }

  // ---------- Pull (updated_at > lastSync) ----------
  Future<List<GtdContext>> getContextsUpdatedAfter(
    String userId,
    DateTime after,
  ) async {
    final db = await _database;
    final rows = await db.query(
      'gtd_contexts',
      where: 'user_id = ? AND updated_at > ?',
      whereArgs: [userId, _toEpoch(after)],
      orderBy: 'updated_at',
    );
    return rows
        .map(
          (r) => GtdContext(
            id: r['id'] as String,
            userId: r['user_id'] as String,
            name: r['name'] as String,
            createdAt: _fromEpoch(r['created_at'] as int),
            updatedAt: _fromEpoch(r['updated_at'] as int),
          ),
        )
        .toList();
  }

  Future<List<GtdProject>> getProjectsUpdatedAfter(
    String userId,
    DateTime after,
  ) async {
    final db = await _database;
    final rows = await db.query(
      'gtd_projects',
      where: 'user_id = ? AND updated_at > ?',
      whereArgs: [userId, _toEpoch(after)],
      orderBy: 'updated_at',
    );
    return rows
        .map(
          (r) => GtdProject(
            id: r['id'] as String,
            userId: r['user_id'] as String,
            name: r['name'] as String,
            notes: r['notes'] as String?,
            createdAt: _fromEpoch(r['created_at'] as int),
            updatedAt: _fromEpoch(r['updated_at'] as int),
          ),
        )
        .toList();
  }

  Future<List<GtdInboxItem>> getInboxUpdatedAfter(
    String userId,
    DateTime after,
  ) async {
    final db = await _database;
    final rows = await db.query(
      'gtd_inbox',
      where: 'user_id = ? AND updated_at > ?',
      whereArgs: [userId, _toEpoch(after)],
      orderBy: 'updated_at',
    );
    return rows
        .map(
          (r) => GtdInboxItem(
            id: r['id'] as String,
            userId: r['user_id'] as String,
            content: r['content'] as String,
            processedAt: r['processed_at'] != null
                ? _fromEpoch(r['processed_at'] as int)
                : null,
            createdAt: _fromEpoch(r['created_at'] as int),
            updatedAt: _fromEpoch(r['updated_at'] as int),
          ),
        )
        .toList();
  }

  Future<List<GtdAction>> getActionsUpdatedAfter(
    String userId,
    DateTime after,
  ) async {
    final db = await _database;
    final rows = await db.query(
      'gtd_actions',
      where: 'user_id = ? AND updated_at > ?',
      whereArgs: [userId, _toEpoch(after)],
      orderBy: 'updated_at',
    );
    return rows.map((r) => _actionFromRow(r)).toList();
  }

  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}
