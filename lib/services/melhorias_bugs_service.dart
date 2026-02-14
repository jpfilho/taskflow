import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/versao.dart';
import '../models/melhoria_bug.dart';
import 'local_database_service.dart';
import 'sync_service.dart';

/// Serviço offline-first para o módulo Melhorias e Bugs (e Versões).
/// Escreve no SQLite local e enfileira sync com Supabase via SyncService.
class MelhoriasBugsService {
  static final MelhoriasBugsService _instance = MelhoriasBugsService._internal();
  factory MelhoriasBugsService() => _instance;
  MelhoriasBugsService._internal();

  final LocalDatabaseService _localDb = LocalDatabaseService();
  final SyncService _syncService = SyncService();
  final _uuid = const Uuid();

  // ---------- Versões ----------

  Future<List<Versao>> getVersoes() async {
    final db = await _localDb.database;
    final rows = await db.query(
      'versoes_local',
      orderBy: 'ordem ASC, data_prevista_lancamento ASC',
    );
    return rows.map((m) => Versao.fromMap(Map<String, dynamic>.from(m))).toList();
  }

  Future<Versao?> getVersaoById(String id) async {
    final db = await _localDb.database;
    final rows = await db.query(
      'versoes_local',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Versao.fromMap(Map<String, dynamic>.from(rows.first));
  }

  Future<Versao> saveVersao(Versao v) async {
    final db = await _localDb.database;
    final id = v.id.isEmpty ? _uuid.v4() : v.id;
    final now = DateTime.now();
    final versao = v.copyWith(
      id: id,
      updatedAt: now,
      createdAt: v.createdAt ?? now,
    );
    final map = versao.toMap();
    map['sync_status'] = 'pending';
    map['last_synced'] = null;

    final exists = await db.query(
      'versoes_local',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (exists.isEmpty) {
      await db.insert('versoes_local', map, conflictAlgorithm: ConflictAlgorithm.replace);
      _syncService.queueOperation('versoes', 'insert', id, versao.toSupabaseMap());
    } else {
      await db.update(
        'versoes_local',
        map,
        where: 'id = ?',
        whereArgs: [id],
      );
      _syncService.queueOperation('versoes', 'update', id, versao.toSupabaseMap());
    }
    _syncService.markHasLocalChanges();
    return versao;
  }

  Future<void> deleteVersao(String id) async {
    final db = await _localDb.database;
    await db.delete('versoes_local', where: 'id = ?', whereArgs: [id]);
    _syncService.queueOperation('versoes', 'delete', id, {'id': id});
    _syncService.markHasLocalChanges();
  }

  // ---------- Melhorias e Bugs ----------

  Future<List<MelhoriaBug>> getMelhoriasBugs({
    String? versaoId,
    String? status,
    String? tipo,
    bool ativosApenas = false,
  }) async {
    final db = await _localDb.database;
    String? where;
    List<Object?>? whereArgs;
    if (versaoId != null || status != null || tipo != null || ativosApenas) {
      final parts = <String>[];
      whereArgs = [];
      if (versaoId != null) {
        parts.add('versao_id = ?');
        whereArgs.add(versaoId);
      }
      if (status != null) {
        parts.add('status = ?');
        whereArgs.add(status);
      }
      if (tipo != null) {
        parts.add('tipo = ?');
        whereArgs.add(tipo);
      }
      if (ativosApenas) {
        parts.add("status NOT IN ('CONCLUIDO', 'REJEITADO', 'DUPLICADO')");
      }
      where = parts.join(' AND ');
    }
    final rows = await db.query(
      'melhorias_bugs_local',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );
    return rows.map((m) => MelhoriaBug.fromMap(Map<String, dynamic>.from(m))).toList();
  }

  Future<MelhoriaBug?> getMelhoriaBugById(String id) async {
    final db = await _localDb.database;
    final rows = await db.query(
      'melhorias_bugs_local',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MelhoriaBug.fromMap(Map<String, dynamic>.from(rows.first));
  }

  Future<MelhoriaBug> saveMelhoriaBug(MelhoriaBug mb) async {
    final db = await _localDb.database;
    final id = mb.id.isEmpty ? _uuid.v4() : mb.id;
    final now = DateTime.now();
    MelhoriaBug atual = mb.copyWith(
      id: id,
      updatedAt: now,
      createdAt: mb.createdAt ?? now,
    );
    if (atual.status == 'CONCLUIDO' && mb.concluidoEm == null) {
      atual = atual.copyWith(concluidoEm: now);
    }
    if (atual.status == 'REABERTO' && mb.reabertoEm == null) {
      atual = atual.copyWith(reabertoEm: now);
    }
    final map = atual.toMap();
    map['sync_status'] = 'pending';
    map['last_synced'] = null;

    final exists = await db.query(
      'melhorias_bugs_local',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (exists.isEmpty) {
      await db.insert('melhorias_bugs_local', map, conflictAlgorithm: ConflictAlgorithm.replace);
      _syncService.queueOperation('melhorias_bugs', 'insert', id, atual.toSupabaseMap());
    } else {
      await db.update(
        'melhorias_bugs_local',
        map,
        where: 'id = ?',
        whereArgs: [id],
      );
      _syncService.queueOperation('melhorias_bugs', 'update', id, atual.toSupabaseMap());
    }
    _syncService.markHasLocalChanges();
    return atual;
  }

  Future<void> deleteMelhoriaBug(String id) async {
    final db = await _localDb.database;
    await db.delete('melhorias_bugs_local', where: 'id = ?', whereArgs: [id]);
    _syncService.queueOperation('melhorias_bugs', 'delete', id, {'id': id});
    _syncService.markHasLocalChanges();
  }

  /// Atualiza apenas o status (respeitando transições permitidas) e persiste.
  Future<MelhoriaBug?> updateStatus(String id, String novoStatus) async {
    final mb = await getMelhoriaBugById(id);
    if (mb == null) return null;
    if (!melhoriaBugPodeTransicionar(mb.status, novoStatus)) return null;
    return saveMelhoriaBug(mb.copyWith(status: novoStatus));
  }
}
