import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../config/supabase_config.dart';
import '../models/versao.dart';
import '../models/melhoria_bug.dart';
import 'auth_service_simples.dart';
import 'connectivity_service.dart';
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
    if (rows.isEmpty && ConnectivityService().isConnected) {
      try {
        final res = await SupabaseConfig.client
            .from('versoes')
            .select()
            .order('ordem', ascending: true);
        return (res as List)
            .map((m) => Versao.fromMap(Map<String, dynamic>.from(m)))
            .toList();
      } catch (_) {}
    }
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

    if (ConnectivityService().isConnected) {
      try {
        await SupabaseConfig.client.from('versoes').upsert(versao.toSupabaseMap());
        await db.update(
          'versoes_local',
          {'sync_status': 'synced', 'last_synced': DateTime.now().millisecondsSinceEpoch},
          where: 'id = ?',
          whereArgs: [id],
        );
      } catch (_) {}
    }

    _syncService.markHasLocalChanges();
    return versao;
  }

  Future<void> deleteVersao(String id) async {
    final db = await _localDb.database;
    await db.delete('versoes_local', where: 'id = ?', whereArgs: [id]);
    _syncService.queueOperation('versoes', 'delete', id, {'id': id});
    if (ConnectivityService().isConnected) {
      try {
        await SupabaseConfig.client.from('versoes').delete().eq('id', id);
      } catch (_) {}
    }
    _syncService.markHasLocalChanges();
  }

  // ---------- Melhorias e Bugs ----------

  Future<int> countAbertos() async {
    try {
      final db = await _localDb.database;
      final result = await db.rawQuery(
        "SELECT COUNT(*) as total FROM melhorias_bugs_local WHERE status NOT IN ('CONCLUIDO', 'REJEITADO', 'DUPLICADO')"
      );
      final countLocal = Sqflite.firstIntValue(result) ?? 0;
      if (countLocal > 0) return countLocal;

      // Fallback ao Supabase caso o banco local ainda não tenha sincronizado
      try {
        final res = await SupabaseConfig.client
            .from('melhorias_bugs')
            .select('id')
            .not('status', 'in', '("CONCLUIDO","REJEITADO","DUPLICADO")');
        return (res as List).length;
      } catch (_) {
        return countLocal;
      }
    } catch (_) {
      return 0;
    }
  }

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
    if (rows.isEmpty && ConnectivityService().isConnected) {
      try {
        dynamic query = SupabaseConfig.client.from('melhorias_bugs').select();
        if (versaoId != null) query = query.eq('versao_id', versaoId);
        if (status != null) query = query.eq('status', status);
        if (tipo != null) query = query.eq('tipo', tipo);
        if (ativosApenas) {
          query = query.not('status', 'in', '("CONCLUIDO","REJEITADO","DUPLICADO")');
        }
        final res = await query.order('created_at', ascending: false);
        return (res as List)
            .map((m) => MelhoriaBug.fromMap(Map<String, dynamic>.from(m)))
            .toList();
      } catch (_) {}
    }
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

  String? _resolveCurrentUser() {
    try {
      final usuario = AuthServiceSimples().currentUser;
      if (usuario != null) {
        if (usuario.nome != null && usuario.nome!.trim().isNotEmpty) {
          return usuario.nome!.trim();
        }
        if (usuario.email.trim().isNotEmpty) {
          return usuario.email.trim();
        }
      }
      final supaEmail = SupabaseConfig.client.auth.currentUser?.email;
      if (supaEmail != null && supaEmail.trim().isNotEmpty) {
        return supaEmail.trim();
      }
    } catch (_) {}
    return null;
  }

  Future<MelhoriaBug> saveMelhoriaBug(MelhoriaBug mb) async {
    final db = await _localDb.database;
    final id = mb.id.isEmpty ? _uuid.v4() : mb.id;
    final now = DateTime.now();
    final autor = (mb.createdBy != null && mb.createdBy!.isNotEmpty)
        ? mb.createdBy
        : _resolveCurrentUser();

    MelhoriaBug atual = mb.copyWith(
      id: id,
      createdBy: autor,
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

    if (ConnectivityService().isConnected) {
      try {
        await SupabaseConfig.client.from('melhorias_bugs').upsert(atual.toSupabaseMap());
        await db.update(
          'melhorias_bugs_local',
          {'sync_status': 'synced', 'last_synced': DateTime.now().millisecondsSinceEpoch},
          where: 'id = ?',
          whereArgs: [id],
        );
      } catch (e) {
        print('⚠️ Sync imediato de melhorias_bugs falhou, fila cuidará: $e');
      }
    }

    _syncService.markHasLocalChanges();
    return atual;
  }

  Future<void> deleteMelhoriaBug(String id) async {
    final db = await _localDb.database;
    await db.delete('melhorias_bugs_local', where: 'id = ?', whereArgs: [id]);
    _syncService.queueOperation('melhorias_bugs', 'delete', id, {'id': id});
    if (ConnectivityService().isConnected) {
      try {
        await SupabaseConfig.client.from('melhorias_bugs').delete().eq('id', id);
      } catch (_) {}
    }
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
