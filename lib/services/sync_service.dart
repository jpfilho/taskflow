import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'local_database_service.dart';
import 'connectivity_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final SupabaseClient _supabase = SupabaseConfig.client;
  final LocalDatabaseService _localDb = LocalDatabaseService();
  final ConnectivityService _connectivity = ConnectivityService();
  bool _isSyncing = false;

  bool get isSyncing => _isSyncing;

  // Inicializar serviço de sincronização
  Future<void> initialize() async {
    await _connectivity.initialize();
    
    // Escutar mudanças de conectividade
    _connectivity.connectionStream.listen((isConnected) {
      if (isConnected && !_isSyncing) {
        // Tentar sincronizar quando conectar
        syncAll();
      }
    });
  }

  // Sincronizar todas as tabelas pendentes
  Future<void> syncAll() async {
    if (!_connectivity.isConnected || _isSyncing) {
      return;
    }

    _isSyncing = true;
    print('🔄 Iniciando sincronização...');

    try {
      // Sincronizar fila de operações
      await _syncQueue();

      // Sincronizar dados pendentes de cada tabela
      await _syncTable('tasks_local', 'tasks');
      await _syncTable('gantt_segments_local', 'gantt_segments');
      await _syncTable('usuarios_local', 'usuarios');
      await _syncTable('regionais_local', 'regionais');
      await _syncTable('divisoes_local', 'divisoes');
      await _syncTable('segmentos_local', 'segmentos');
      await _syncTable('locais_local', 'locais');
      await _syncTable('executores_local', 'executores');
      await _syncTable('tipos_atividade_local', 'tipos_atividade');
      await _syncTable('status_local', 'status');
      await _syncTable('feriados_local', 'feriados');

      // Baixar dados atualizados do Supabase
      await _pullFromSupabase();

      print('✅ Sincronização concluída');
    } catch (e) {
      print('❌ Erro na sincronização: $e');
    } finally {
      _isSyncing = false;
    }
  }

  // Sincronizar fila de operações
  Future<void> _syncQueue() async {
    final pendingItems = await _localDb.getPendingSyncItems();

    for (var item in pendingItems) {
      try {
        final tableName = item['table_name'] as String;
        final operation = item['operation'] as String;
        final recordId = item['record_id'] as String;
        final data = jsonDecode(item['data'] as String) as Map<String, dynamic>;
        final queueId = item['id'] as int;

        bool success = false;

        switch (operation) {
          case 'insert':
            success = await _insertToSupabase(tableName, data);
            break;
          case 'update':
            success = await _updateInSupabase(tableName, recordId, data);
            break;
          case 'delete':
            success = await _deleteFromSupabase(tableName, recordId);
            break;
        }

        if (success) {
          await _localDb.markAsSynced(queueId);
        }
      } catch (e) {
        print('Erro ao sincronizar item da fila: $e');
      }
    }
  }

  // Sincronizar tabela específica
  Future<void> _syncTable(String localTable, String supabaseTable) async {
    final db = await _localDb.database;
    final pendingRecords = await db.query(
      localTable,
      where: 'sync_status = ?',
      whereArgs: ['pending'],
    );

    for (var record in pendingRecords) {
      try {
        final recordId = record['id'] as String;
        final recordMap = Map<String, dynamic>.from(record);
        
        // Remover campos de controle
        recordMap.remove('sync_status');
        recordMap.remove('last_synced');

        // Converter timestamps para DateTime
        _convertTimestamps(recordMap);

        // Tentar inserir/atualizar no Supabase
        final exists = await _recordExistsInSupabase(supabaseTable, recordId);
        
        if (exists) {
          await _updateInSupabase(supabaseTable, recordId, recordMap);
        } else {
          await _insertToSupabase(supabaseTable, recordMap);
        }

        await _localDb.updateSyncStatus(localTable.replaceAll('_local', ''), recordId, 'synced');
      } catch (e) {
        print('Erro ao sincronizar registro: $e');
      }
    }
  }

  // Baixar dados atualizados do Supabase
  Future<void> _pullFromSupabase() async {
    try {
      // Baixar tarefas
      await _pullTable('tasks', 'tasks_local');
      await _pullTable('gantt_segments', 'gantt_segments_local');
      // Adicionar outras tabelas conforme necessário
    } catch (e) {
      print('Erro ao baixar dados do Supabase: $e');
    }
  }

  // Baixar tabela específica do Supabase
  Future<void> _pullTable(String supabaseTable, String localTable) async {
    try {
      final response = await _supabase
          .from(supabaseTable)
          .select()
          .order('updated_at', ascending: false)
          .limit(1000);

      final db = await _localDb.database;
      
      for (var record in response) {
          final recordMap = Map<String, dynamic>.from(record);
          final recordId = recordMap['id'] as String;

          // Converter DateTime para timestamp
          _convertDateTimesToTimestamps(recordMap);

          // Verificar se já existe localmente
          final existing = await db.query(
            localTable,
            where: 'id = ?',
            whereArgs: [recordId],
            limit: 1,
          );

          if (existing.isEmpty) {
            // Inserir novo registro
            recordMap['sync_status'] = 'synced';
            recordMap['last_synced'] = DateTime.now().millisecondsSinceEpoch;
            await db.insert(localTable, recordMap, conflictAlgorithm: ConflictAlgorithm.replace);
          } else {
            // Atualizar se o registro do Supabase for mais recente
            final localUpdated = existing.first['updated_at'] as int?;
            final supabaseUpdated = recordMap['updated_at'] as int?;
            
            if (supabaseUpdated != null && (localUpdated == null || supabaseUpdated > localUpdated)) {
              recordMap['sync_status'] = 'synced';
              recordMap['last_synced'] = DateTime.now().millisecondsSinceEpoch;
              await db.update(localTable, recordMap, where: 'id = ?', whereArgs: [recordId]);
            }
          }
        }
    } catch (e) {
      print('Erro ao baixar tabela $supabaseTable: $e');
    }
  }

  // Inserir no Supabase
  Future<bool> _insertToSupabase(String tableName, Map<String, dynamic> data) async {
    try {
      await _supabase.from(tableName).insert(data);
      return true;
    } catch (e) {
      print('Erro ao inserir no Supabase: $e');
      return false;
    }
  }

  // Atualizar no Supabase
  Future<bool> _updateInSupabase(String tableName, String recordId, Map<String, dynamic> data) async {
    try {
      await _supabase.from(tableName).update(data).eq('id', recordId);
      return true;
    } catch (e) {
      print('Erro ao atualizar no Supabase: $e');
      return false;
    }
  }

  // Deletar do Supabase
  Future<bool> _deleteFromSupabase(String tableName, String recordId) async {
    try {
      await _supabase.from(tableName).delete().eq('id', recordId);
      return true;
    } catch (e) {
      print('Erro ao deletar do Supabase: $e');
      return false;
    }
  }

  // Verificar se registro existe no Supabase
  Future<bool> _recordExistsInSupabase(String tableName, String recordId) async {
    try {
      final response = await _supabase
          .from(tableName)
          .select('id')
          .eq('id', recordId)
          .maybeSingle();
      return response != null;
    } catch (e) {
      return false;
    }
  }

  // Converter timestamps para DateTime
  void _convertTimestamps(Map<String, dynamic> map) {
    final timestampFields = [
      'data_inicio', 'data_fim', 'data_criacao', 'data_atualizacao',
      'created_at', 'updated_at', 'data_upload', 'dia', 'mes', 'ano'
    ];

    for (var field in timestampFields) {
      if (map.containsKey(field) && map[field] is int) {
        final timestamp = map[field] as int;
        map[field] = DateTime.fromMillisecondsSinceEpoch(timestamp).toIso8601String();
      }
    }
  }

  // Converter DateTime para timestamps
  void _convertDateTimesToTimestamps(Map<String, dynamic> map) {
    final dateFields = [
      'data_inicio', 'data_fim', 'data_criacao', 'data_atualizacao',
      'created_at', 'updated_at', 'data_upload'
    ];

    for (var field in dateFields) {
      if (map.containsKey(field) && map[field] is String) {
        try {
          final dateTime = DateTime.parse(map[field] as String);
          map[field] = dateTime.millisecondsSinceEpoch;
        } catch (e) {
          // Ignorar campos que não são datas válidas
        }
      }
    }
  }

  // Adicionar operação à fila de sincronização
  Future<void> queueOperation(String tableName, String operation, String recordId, Map<String, dynamic> data) async {
    if (_connectivity.isConnected) {
      // Tentar sincronizar imediatamente
      bool success = false;
      switch (operation) {
        case 'insert':
          success = await _insertToSupabase(tableName, data);
          break;
        case 'update':
          success = await _updateInSupabase(tableName, recordId, data);
          break;
        case 'delete':
          success = await _deleteFromSupabase(tableName, recordId);
          break;
      }

      if (!success) {
        // Se falhar, adicionar à fila
        await _localDb.addToSyncQueue(tableName, operation, recordId, data);
      }
    } else {
      // Se offline, adicionar à fila
      await _localDb.addToSyncQueue(tableName, operation, recordId, data);
    }
  }

  void dispose() {
    _connectivity.dispose();
  }
}

