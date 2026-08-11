import 'package:uuid/uuid.dart';
import '../../../services/local_database_service.dart';
import '../../../services/sync_service.dart';
import '../models/projeto.dart';
import '../models/projeto_macroetapa.dart';
import '../models/projeto_etapa.dart';
import '../models/projeto_atividade.dart';
import '../models/projeto_membro.dart';
import '../models/projeto_marco.dart';
import '../models/projeto_risco.dart';
import '../models/projeto_dependencia.dart';

class ProjetoService {
  final LocalDatabaseService _localDb = LocalDatabaseService();
  final SyncService _syncService = SyncService();
  final _uuid = const Uuid();

  // ==========================================
  // PROJETOS
  // ==========================================
  Future<List<Projeto>> getProjetos({bool ativos = true}) async {
    final db = await _localDb.database;
    String whereStr = 'deleted_at IS NULL';
    if (ativos) {
      whereStr += " AND status != 'CANCELADO' AND status != 'CONCLUIDO'";
    }
    
    final List<Map<String, dynamic>> maps = await db.query(
      'projetos_local',
      where: whereStr,
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Projeto.fromMap(map)).toList();
  }

  Future<Projeto> createProjeto(Projeto projeto) async {
    final db = await _localDb.database;
    final map = projeto.toMap();
    
    map['id'] = projeto.id.isEmpty ? _uuid.v4() : projeto.id;
    map['sync_status'] = 'pending';
    map['created_at'] = DateTime.now().millisecondsSinceEpoch;
    
    await db.insert('projetos_local', map);
    await _syncService.queueOperation('projetos', 'insert', map['id'], map);
    _syncService.markHasLocalChanges();
    
    return Projeto.fromMap(map);
  }

  Future<Projeto> updateProjeto(Projeto projeto) async {
    final db = await _localDb.database;
    final map = projeto.toMap();
    
    map['sync_status'] = 'pending';
    map['updated_at'] = DateTime.now().millisecondsSinceEpoch;
    
    await db.update(
      'projetos_local',
      map,
      where: 'id = ?',
      whereArgs: [projeto.id],
    );
    
    await _syncService.queueOperation('projetos', 'update', projeto.id, map);
    _syncService.markHasLocalChanges();
    
    return Projeto.fromMap(map);
  }

  Future<void> deleteProjeto(String id) async {
    final db = await _localDb.database;
    final map = {
      'deleted_at': DateTime.now().millisecondsSinceEpoch,
      'sync_status': 'pending'
    };
    
    await db.update(
      'projetos_local',
      map,
      where: 'id = ?',
      whereArgs: [id],
    );
    
    await _syncService.queueOperation('projetos', 'update', id, map);
    _syncService.markHasLocalChanges();
  }

  // ==========================================
  // MACROETAPAS
  // ==========================================
  Future<List<ProjetoMacroetapa>> getMacroetapas(String projetoId) async {
    final db = await _localDb.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'projeto_macroetapas_local',
      where: 'projeto_id = ? AND deleted_at IS NULL',
      whereArgs: [projetoId],
      orderBy: 'ordem ASC, created_at ASC',
    );
    return maps.map((map) => ProjetoMacroetapa.fromMap(map)).toList();
  }

  Future<ProjetoMacroetapa> createMacroetapa(ProjetoMacroetapa macroetapa) async {
    final db = await _localDb.database;
    final map = macroetapa.toMap();
    
    map['id'] = macroetapa.id.isEmpty ? _uuid.v4() : macroetapa.id;
    map['sync_status'] = 'pending';
    map['created_at'] = DateTime.now().millisecondsSinceEpoch;
    
    await db.insert('projeto_macroetapas_local', map);
    await _syncService.queueOperation('projeto_macroetapas', 'insert', map['id'], map);
    _syncService.markHasLocalChanges();
    
    return ProjetoMacroetapa.fromMap(map);
  }

  Future<ProjetoMacroetapa> updateMacroetapa(ProjetoMacroetapa macroetapa) async {
    final db = await _localDb.database;
    final map = macroetapa.toMap();
    
    map['sync_status'] = 'pending';
    map['updated_at'] = DateTime.now().millisecondsSinceEpoch;
    
    await db.update(
      'projeto_macroetapas_local',
      map,
      where: 'id = ?',
      whereArgs: [macroetapa.id],
    );
    
    await _syncService.queueOperation('projeto_macroetapas', 'update', macroetapa.id, map);
    _syncService.markHasLocalChanges();
    
    return ProjetoMacroetapa.fromMap(map);
  }

  Future<void> deleteMacroetapa(String id) async {
    final db = await _localDb.database;
    final map = {
      'deleted_at': DateTime.now().millisecondsSinceEpoch,
      'sync_status': 'pending'
    };
    await db.update('projeto_macroetapas_local', map, where: 'id = ?', whereArgs: [id]);
    await _syncService.queueOperation('projeto_macroetapas', 'update', id, map);
    _syncService.markHasLocalChanges();
  }

  // ==========================================
  // ETAPAS
  // ==========================================
  Future<List<ProjetoEtapa>> getEtapas(String macroetapaId) async {
    final db = await _localDb.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'projeto_etapas_local',
      where: 'macroetapa_id = ? AND deleted_at IS NULL',
      whereArgs: [macroetapaId],
      orderBy: 'ordem ASC, created_at ASC',
    );
    return maps.map((map) => ProjetoEtapa.fromMap(map)).toList();
  }

  Future<ProjetoEtapa> createEtapa(ProjetoEtapa etapa) async {
    final db = await _localDb.database;
    final map = etapa.toMap();
    
    map['id'] = etapa.id.isEmpty ? _uuid.v4() : etapa.id;
    map['sync_status'] = 'pending';
    map['created_at'] = DateTime.now().millisecondsSinceEpoch;
    
    await db.insert('projeto_etapas_local', map);
    await _syncService.queueOperation('projeto_etapas', 'insert', map['id'], map);
    _syncService.markHasLocalChanges();
    
    return ProjetoEtapa.fromMap(map);
  }

  Future<ProjetoEtapa> updateEtapa(ProjetoEtapa etapa) async {
    final db = await _localDb.database;
    final map = etapa.toMap();
    
    map['sync_status'] = 'pending';
    map['updated_at'] = DateTime.now().millisecondsSinceEpoch;
    
    await db.update('projeto_etapas_local', map, where: 'id = ?', whereArgs: [etapa.id]);
    await _syncService.queueOperation('projeto_etapas', 'update', etapa.id, map);
    _syncService.markHasLocalChanges();
    
    return ProjetoEtapa.fromMap(map);
  }

  Future<void> deleteEtapa(String id) async {
    final db = await _localDb.database;
    final map = {'deleted_at': DateTime.now().millisecondsSinceEpoch, 'sync_status': 'pending'};
    await db.update('projeto_etapas_local', map, where: 'id = ?', whereArgs: [id]);
    await _syncService.queueOperation('projeto_etapas', 'update', id, map);
    _syncService.markHasLocalChanges();
  }

  // ==========================================
  // ATIVIDADES
  // ==========================================
  Future<List<ProjetoAtividade>> getAtividades(String etapaId) async {
    final db = await _localDb.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'projeto_atividades_local',
      where: 'etapa_id = ? AND deleted_at IS NULL',
      whereArgs: [etapaId],
      orderBy: 'ordem ASC, created_at ASC',
    );
    return maps.map((map) => ProjetoAtividade.fromMap(map)).toList();
  }

  Future<List<ProjetoAtividade>> getTodasAtividadesDoProjeto(String projetoId) async {
    final db = await _localDb.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'projeto_atividades_local',
      where: 'projeto_id = ? AND deleted_at IS NULL',
      whereArgs: [projetoId],
      orderBy: 'data_inicio_prevista ASC, ordem ASC',
    );
    return maps.map((map) => ProjetoAtividade.fromMap(map)).toList();
  }

  Future<ProjetoAtividade> createAtividade(ProjetoAtividade atividade) async {
    final db = await _localDb.database;
    final map = atividade.toMap();
    
    map['id'] = atividade.id.isEmpty ? _uuid.v4() : atividade.id;
    map['sync_status'] = 'pending';
    map['created_at'] = DateTime.now().millisecondsSinceEpoch;
    
    await db.insert('projeto_atividades_local', map);
    await _syncService.queueOperation('projeto_atividades', 'insert', map['id'], map);
    _syncService.markHasLocalChanges();
    
    return ProjetoAtividade.fromMap(map);
  }

  Future<ProjetoAtividade> updateAtividade(ProjetoAtividade atividade) async {
    final db = await _localDb.database;
    final map = atividade.toMap();
    
    map['sync_status'] = 'pending';
    map['updated_at'] = DateTime.now().millisecondsSinceEpoch;
    
    await db.update('projeto_atividades_local', map, where: 'id = ?', whereArgs: [atividade.id]);
    await _syncService.queueOperation('projeto_atividades', 'update', atividade.id, map);
    _syncService.markHasLocalChanges();
    
    return ProjetoAtividade.fromMap(map);
  }

  Future<void> deleteAtividade(String id) async {
    final db = await _localDb.database;
    final map = {'deleted_at': DateTime.now().millisecondsSinceEpoch, 'sync_status': 'pending'};
    await db.update('projeto_atividades_local', map, where: 'id = ?', whereArgs: [id]);
    await _syncService.queueOperation('projeto_atividades', 'update', id, map);
    _syncService.markHasLocalChanges();
  }

  // ==========================================
  // MEMBROS
  // ==========================================
  Future<List<ProjetoMembro>> getMembros(String projetoId) async {
    final db = await _localDb.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'projeto_membros_local',
      where: 'projeto_id = ?',
      whereArgs: [projetoId],
    );
    return maps.map((map) => ProjetoMembro.fromMap(map)).toList();
  }

  Future<ProjetoMembro> addMembro(ProjetoMembro membro) async {
    final db = await _localDb.database;
    final map = membro.toMap();
    map['id'] = membro.id.isEmpty ? _uuid.v4() : membro.id;
    map['sync_status'] = 'pending';
    map['created_at'] = DateTime.now().millisecondsSinceEpoch;
    
    await db.insert('projeto_membros_local', map);
    await _syncService.queueOperation('projeto_membros', 'insert', map['id'], map);
    _syncService.markHasLocalChanges();
    return ProjetoMembro.fromMap(map);
  }

  Future<void> removeMembro(String id) async {
    final db = await _localDb.database;
    // Membros não usam soft delete, mas podemos mandar delete pro supabase
    await db.delete('projeto_membros_local', where: 'id = ?', whereArgs: [id]);
    await _syncService.queueOperation('projeto_membros', 'delete', id, {});
    _syncService.markHasLocalChanges();
  }

  // ==========================================
  // MARCOS
  // ==========================================
  Future<List<ProjetoMarco>> getMarcos(String projetoId) async {
    final db = await _localDb.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'projeto_marcos_local',
      where: 'projeto_id = ? AND deleted_at IS NULL',
      whereArgs: [projetoId],
      orderBy: 'data_prevista ASC',
    );
    return maps.map((map) => ProjetoMarco.fromMap(map)).toList();
  }

  Future<ProjetoMarco> createMarco(ProjetoMarco marco) async {
    final db = await _localDb.database;
    final map = marco.toMap();
    map['id'] = marco.id.isEmpty ? _uuid.v4() : marco.id;
    map['sync_status'] = 'pending';
    map['created_at'] = DateTime.now().millisecondsSinceEpoch;
    
    await db.insert('projeto_marcos_local', map);
    await _syncService.queueOperation('projeto_marcos', 'insert', map['id'], map);
    _syncService.markHasLocalChanges();
    return ProjetoMarco.fromMap(map);
  }

  Future<ProjetoMarco> updateMarco(ProjetoMarco marco) async {
    final db = await _localDb.database;
    final map = marco.toMap();
    map['sync_status'] = 'pending';
    map['updated_at'] = DateTime.now().millisecondsSinceEpoch;
    
    await db.update('projeto_marcos_local', map, where: 'id = ?', whereArgs: [marco.id]);
    await _syncService.queueOperation('projeto_marcos', 'update', marco.id, map);
    _syncService.markHasLocalChanges();
    return ProjetoMarco.fromMap(map);
  }

  Future<void> deleteMarco(String id) async {
    final db = await _localDb.database;
    final map = {'deleted_at': DateTime.now().millisecondsSinceEpoch, 'sync_status': 'pending'};
    await db.update('projeto_marcos_local', map, where: 'id = ?', whereArgs: [id]);
    await _syncService.queueOperation('projeto_marcos', 'update', id, map);
    _syncService.markHasLocalChanges();
  }

  // ==========================================
  // RISCOS
  // ==========================================
  Future<List<ProjetoRisco>> getRiscos(String projetoId) async {
    final db = await _localDb.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'projeto_riscos_local',
      where: 'projeto_id = ? AND deleted_at IS NULL',
      whereArgs: [projetoId],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => ProjetoRisco.fromMap(map)).toList();
  }

  Future<ProjetoRisco> createRisco(ProjetoRisco risco) async {
    final db = await _localDb.database;
    final map = risco.toMap();
    map['id'] = risco.id.isEmpty ? _uuid.v4() : risco.id;
    map['sync_status'] = 'pending';
    map['created_at'] = DateTime.now().millisecondsSinceEpoch;
    
    await db.insert('projeto_riscos_local', map);
    await _syncService.queueOperation('projeto_riscos', 'insert', map['id'], map);
    _syncService.markHasLocalChanges();
    return ProjetoRisco.fromMap(map);
  }

  Future<ProjetoRisco> updateRisco(ProjetoRisco risco) async {
    final db = await _localDb.database;
    final map = risco.toMap();
    map['sync_status'] = 'pending';
    map['updated_at'] = DateTime.now().millisecondsSinceEpoch;
    
    await db.update('projeto_riscos_local', map, where: 'id = ?', whereArgs: [risco.id]);
    await _syncService.queueOperation('projeto_riscos', 'update', risco.id, map);
    _syncService.markHasLocalChanges();
    return ProjetoRisco.fromMap(map);
  }

  Future<void> deleteRisco(String id) async {
    final db = await _localDb.database;
    final map = {'deleted_at': DateTime.now().millisecondsSinceEpoch, 'sync_status': 'pending'};
    await db.update('projeto_riscos_local', map, where: 'id = ?', whereArgs: [id]);
    await _syncService.queueOperation('projeto_riscos', 'update', id, map);
    _syncService.markHasLocalChanges();
  }

  // ==========================================
  // DEPENDÊNCIAS
  // ==========================================
  Future<List<ProjetoDependencia>> getDependencias(String projetoId) async {
    final db = await _localDb.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'projeto_atividade_dependencias_local',
      where: 'projeto_id = ? AND deleted_at IS NULL',
      whereArgs: [projetoId],
    );
    return maps.map((map) => ProjetoDependencia.fromMap(map)).toList();
  }

  Future<ProjetoDependencia> createDependencia(ProjetoDependencia dependencia) async {
    final db = await _localDb.database;
    final map = dependencia.toMap();
    map['id'] = dependencia.id.isEmpty ? _uuid.v4() : dependencia.id;
    map['sync_status'] = 'pending';
    map['created_at'] = DateTime.now().millisecondsSinceEpoch;
    
    await db.insert('projeto_atividade_dependencias_local', map);
    await _syncService.queueOperation('projeto_atividade_dependencias', 'insert', map['id'], map);
    _syncService.markHasLocalChanges();
    return ProjetoDependencia.fromMap(map);
  }

  Future<void> deleteDependencia(String id) async {
    final db = await _localDb.database;
    final map = {'deleted_at': DateTime.now().millisecondsSinceEpoch, 'sync_status': 'pending'};
    await db.update('projeto_atividade_dependencias_local', map, where: 'id = ?', whereArgs: [id]);
    await _syncService.queueOperation('projeto_atividade_dependencias', 'update', id, map);
    _syncService.markHasLocalChanges();
  }
}
