import 'package:flutter/foundation.dart';
import '../models/frota.dart';
import '../config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'local_database_service.dart';
import 'connectivity_service.dart';
import 'package:sqflite/sqflite.dart';

class FrotaService {
  static final FrotaService _instance = FrotaService._internal();
  factory FrotaService() => _instance;
  FrotaService._internal();

  final SupabaseClient _supabase = SupabaseConfig.client;
  final LocalDatabaseService _localDb = LocalDatabaseService();
  final ConnectivityService _connectivity = ConnectivityService();

  // Converter Map do Supabase para Frota
  Frota _frotaFromMap(Map<String, dynamic> map) {
    return Frota.fromMap(map);
  }

  // Converter Frota para Map (para Supabase)
  Map<String, dynamic> _frotaToMap(Frota frota) {
    return frota.toMap();
  }

  // Buscar todas as frotas
  Future<List<Frota>> getAllFrotas() async {
    // Se offline, ler do banco local
    if (!_connectivity.isConnected) {
      return await _getAllFrotasFromLocal();
    }

    try {
      final response = await _supabase
          .from('frota')
          .select('''
            *,
            regionais!left(regional),
            divisoes!left(divisao),
            segmentos!left(segmento)
          ''')
          .order('nome', ascending: true)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              print('⚠️ Timeout ao buscar frota');
              return <Map<String, dynamic>>[];
            },
          );

      if (response.isEmpty) {
        // Se não houver dados online, tentar do banco local
        return await _getAllFrotasFromLocal();
      }

      final frotasList = response as List;
      final frotas = frotasList
          .map((map) => _frotaFromMap(map as Map<String, dynamic>))
          .toList();
      
      // Salvar no banco local
      for (var frota in frotas) {
        try {
          await _saveFrotaToLocal(frota);
        } catch (e) {
          print('⚠️ Erro ao salvar frota no banco local: $e');
        }
      }
      
      return frotas;
    } catch (e) {
      print('Erro ao buscar frota do Supabase: $e');
      // Fallback para banco local
      return await _getAllFrotasFromLocal();
    }
  }

  Future<List<Frota>> _getAllFrotasFromLocal() async {
    try {
      final db = await _localDb.database;
      final frotasRows = await db.query('frota_local', orderBy: 'nome ASC');
      
      return frotasRows.map((row) => _frotaFromLocalMap(row)).toList();
    } catch (e) {
      print('Erro ao buscar frota do banco local: $e');
      return [];
    }
  }

  Frota _frotaFromLocalMap(Map<String, dynamic> row) {
    return Frota(
      id: row['id'] as String,
      nome: row['nome'] as String,
      marca: row['marca'] as String?,
      tipoVeiculo: row['tipo_veiculo'] as String? ?? 'CARRO_LEVE',
      placa: row['placa'] as String,
      regionalId: row['regional_id'] as String?,
      regional: row['regional'] as String?,
      divisaoId: row['divisao_id'] as String?,
      divisao: row['divisao'] as String?,
      segmentoId: row['segmento_id'] as String?,
      segmento: row['segmento'] as String?,
      emManutencao: (row['em_manutencao'] as int? ?? 0) == 1,
      observacoes: row['observacoes'] as String?,
      ativo: (row['ativo'] as int? ?? 1) == 1,
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String)
          : null,
      updatedAt: row['updated_at'] != null
          ? DateTime.parse(row['updated_at'] as String)
          : null,
    );
  }

  Future<void> _saveFrotaToLocal(Frota frota) async {
    // Em web não há suporte a path_provider/sqflite; evitar MissingPluginException
    if (kIsWeb) return;
    try {
      final db = await _localDb.database;
      await db.insert(
        'frota_local',
        {
          'id': frota.id,
          'nome': frota.nome,
          'marca': frota.marca,
          'tipo_veiculo': frota.tipoVeiculo,
          'placa': frota.placa,
          'regional_id': frota.regionalId,
          'regional': frota.regional,
          'divisao_id': frota.divisaoId,
          'divisao': frota.divisao,
          'segmento_id': frota.segmentoId,
          'segmento': frota.segmento,
          'em_manutencao': frota.emManutencao ? 1 : 0,
          'observacoes': frota.observacoes,
          'ativo': frota.ativo ? 1 : 0,
          'created_at': frota.createdAt?.toIso8601String(),
          'updated_at': frota.updatedAt?.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('Erro ao salvar frota no banco local: $e');
      rethrow;
    }
  }

  // Buscar frota por ID
  Future<Frota?> getFrotaById(String id) async {
    if (!_connectivity.isConnected) {
      try {
        final db = await _localDb.database;
        final rows = await db.query(
          'frota_local',
          where: 'id = ?',
          whereArgs: [id],
        );
        if (rows.isEmpty) return null;
        return _frotaFromLocalMap(rows.first);
      } catch (e) {
        print('Erro ao buscar frota por ID no banco local: $e');
        return null;
      }
    }

    try {
      final response = await _supabase
          .from('frota')
          .select('''
            *,
            regionais!left(regional),
            divisoes!left(divisao),
            segmentos!left(segmento)
          ''')
          .eq('id', id)
          .single();

      return _frotaFromMap(Map<String, dynamic>.from(response));
    } catch (e) {
      print('Erro ao buscar frota por ID: $e');
      return null;
    }
  }

  // Criar frota
  Future<Frota> createFrota(Frota frota) async {
    // Salvar no banco local primeiro
    final frotaId = frota.id.isNotEmpty 
        ? frota.id 
        : 'FROTA_${DateTime.now().millisecondsSinceEpoch}';
    final frotaWithId = frota.copyWith(id: frotaId);
    
    try {
      await _saveFrotaToLocal(frotaWithId);
      await _localDb.updateSyncStatus('frota', frotaId, 'pending');
    } catch (e) {
      print('⚠️ Erro ao salvar frota no banco local: $e');
    }
    
    // Se online, tentar salvar no Supabase
    if (_connectivity.isConnected) {
      try {
        final map = _frotaToMap(frotaWithId);
        map.remove('id'); // Remover ID para deixar o banco gerar
        map.remove('created_at');
        map.remove('updated_at');
        
        // Limpar valores nulos
        map.removeWhere((key, value) => value == null || (value is String && value.isEmpty && key != 'nome' && key != 'placa' && key != 'tipo_veiculo'));
        
        print('📝 Criando frota com dados: $map');

        final response = await _supabase
            .from('frota')
            .insert(map)
            .select('''
              *,
              regionais!left(regional),
              divisoes!left(divisao),
              segmentos!left(segmento)
            ''')
            .single()
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                throw Exception('Timeout ao criar frota');
              },
            );

        final frotaCompleta = _frotaFromMap(Map<String, dynamic>.from(response));
        
        // Atualizar no banco local com o ID do Supabase
        try {
          await _saveFrotaToLocal(frotaCompleta);
          await _localDb.updateSyncStatus('frota', frotaCompleta.id, 'synced');
        } catch (e) {
          print('⚠️ Erro ao atualizar frota no banco local: $e');
        }
        
        return frotaCompleta;
      } catch (e) {
        print('❌ Erro ao criar frota no Supabase: $e');
        // Retornar a frota local mesmo se falhar no Supabase
        return frotaWithId;
      }
    }
    
    return frotaWithId;
  }

  // Atualizar frota
  Future<Frota> updateFrota(String id, Frota frota) async {
    final frotaAtualizada = frota.copyWith(id: id);
    
    // Atualizar no banco local
    try {
      await _saveFrotaToLocal(frotaAtualizada);
      await _localDb.updateSyncStatus('frota', id, 'pending');
    } catch (e) {
      print('⚠️ Erro ao atualizar frota no banco local: $e');
    }
    
    // Se online, tentar atualizar no Supabase
    if (_connectivity.isConnected) {
      try {
        final map = _frotaToMap(frotaAtualizada);
        map.remove('id');
        map.remove('created_at');
        map.remove('updated_at');
        
        // Limpar valores nulos
        map.removeWhere((key, value) => value == null || (value is String && value.isEmpty && key != 'nome' && key != 'placa' && key != 'tipo_veiculo'));
        
        await _supabase
            .from('frota')
            .update(map)
            .eq('id', id)
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                throw Exception('Timeout ao atualizar frota');
              },
            );

        // Buscar frota atualizada
        final frotaCompleta = await getFrotaById(id);
        if (frotaCompleta != null) {
          // Atualizar no banco local
          try {
            await _saveFrotaToLocal(frotaCompleta);
            await _localDb.updateSyncStatus('frota', id, 'synced');
          } catch (e) {
            print('⚠️ Erro ao atualizar frota no banco local: $e');
          }
          return frotaCompleta;
        }
      } catch (e) {
        print('❌ Erro ao atualizar frota no Supabase: $e');
      }
    }
    
    return frotaAtualizada;
  }

  // Deletar frota
  Future<void> deleteFrota(String id) async {
    // Marcar como deletado no banco local
    try {
      final db = await _localDb.database;
      await db.delete('frota_local', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      print('⚠️ Erro ao deletar frota do banco local: $e');
    }
    
    // Se online, tentar deletar no Supabase
    if (_connectivity.isConnected) {
      try {
        await _supabase
            .from('frota')
            .delete()
            .eq('id', id)
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                throw Exception('Timeout ao deletar frota');
              },
            );
      } catch (e) {
        print('❌ Erro ao deletar frota no Supabase: $e');
        rethrow;
      }
    }
  }

  // Buscar frotas por tipo
  Future<List<Frota>> getFrotasByTipo(String tipoVeiculo) async {
    final allFrotas = await getAllFrotas();
    return allFrotas.where((f) => f.tipoVeiculo == tipoVeiculo).toList();
  }

  // Buscar frotas em manutenção
  Future<List<Frota>> getFrotasEmManutencao() async {
    final allFrotas = await getAllFrotas();
    return allFrotas.where((f) => f.emManutencao).toList();
  }

  // Buscar frotas ativas
  Future<List<Frota>> getFrotasAtivas() async {
    final allFrotas = await getAllFrotas();
    return allFrotas.where((f) => f.ativo).toList();
  }

  // Contar frotas vinculadas por tarefas (otimizado - usa VIEW do Supabase)
  Future<Map<String, int>> contarFrotasPorTarefas(List<String> taskIds) async {
    try {
      if (taskIds.isEmpty) return {};

      // Usar VIEW otimizada do Supabase para buscar todas as contagens de uma vez
      dynamic query = _supabase
          .from('contagens_frotas_tarefas')
          .select('task_id, quantidade');
      
      if (taskIds.length == 1) {
        query = query.eq('task_id', taskIds[0]);
      } else {
        final orConditions = taskIds.map((id) => 'task_id.eq.$id').join(',');
        query = query.or(orConditions);
      }
      
      final response = await query;

      final contagens = <String, int>{};
      for (var item in response) {
        final taskId = item['task_id'] as String;
        final quantidade = item['quantidade'] as int;
        if (quantidade > 0) {
          contagens[taskId] = quantidade;
        }
      }

      return contagens;
    } catch (e) {
      print('❌ Erro ao contar frotas das tarefas: $e');
      return {};
    }
  }

  // Obter nome da frota de uma tarefa
  Future<String?> getFrotaNomePorTarefa(String taskId) async {
    try {
      final response = await _supabase
          .from('contagens_frotas_tarefas')
          .select('frota_nome')
          .eq('task_id', taskId)
          .maybeSingle();

      if (response == null) return null;

      final frotaNome = response['frota_nome'] as String?;
      if (frotaNome != null && frotaNome.isNotEmpty && frotaNome != '-N/A-') {
        return frotaNome;
      }
      return null;
    } catch (e) {
      print('❌ Erro ao buscar nome da frota da tarefa: $e');
      return null;
    }
  }
}
