import 'dart:async';
import '../models/equipe.dart';
import '../config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EquipeService {
  static final EquipeService _instance = EquipeService._internal();
  factory EquipeService() => _instance;
  EquipeService._internal();

  final SupabaseClient _supabase = SupabaseConfig.client;

  // Converter Map do Supabase para Equipe
  Equipe _equipeFromMap(Map<String, dynamic> map) {
    return Equipe.fromMap(map);
  }

  // Converter Equipe para Map (para Supabase)
  Map<String, dynamic> _equipeToMap(Equipe equipe) {
    return {
      'nome': equipe.nome,
      'descricao': equipe.descricao,
      'tipo': equipe.tipo,
      'ativo': equipe.ativo,
    };
  }

  // Buscar todas as equipes
  Future<List<Equipe>> getAllEquipes() async {
    try {
      final response = await _supabase
          .from('equipes')
          .select('''
            *,
            regionais!left(regional),
            divisoes!left(divisao),
            segmentos!left(segmento),
            equipes_executores!left(executor_id, papel, executores!inner(id, nome))
          ''')
          .order('nome', ascending: true)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => <Map<String, dynamic>>[],
          );

      if (response.isEmpty) return [];

      final equipesList = response as List;
      return equipesList
          .map((map) => _equipeFromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Erro ao buscar equipes: $e');
      return [];
    }
  }

  // Buscar equipes ativas
  Future<List<Equipe>> getEquipesAtivas() async {
    try {
      final response = await _supabase
          .from('equipes')
          .select('''
            *,
            equipes_executores!left(executor_id, papel, executores!inner(id, nome))
          ''')
          .eq('ativo', true)
          .order('nome', ascending: true)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => <Map<String, dynamic>>[],
          );

      if (response.isEmpty) return [];

      final equipesList = response as List;
      return equipesList
          .map((map) => _equipeFromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Erro ao buscar equipes ativas: $e');
      return [];
    }
  }

  // Buscar equipe por ID
  Future<Equipe?> getEquipeById(String id) async {
    try {
      final response = await _supabase
          .from('equipes')
          .select('''
            *,
            equipes_executores!left(executor_id, papel, executores!inner(id, nome))
          ''')
          .eq('id', id)
          .single()
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('Timeout ao buscar equipe'),
          );

      return _equipeFromMap(response);
    } catch (e) {
      print('Erro ao buscar equipe por ID: $e');
      return null;
    }
  }

  // Criar nova equipe
  Future<Equipe?> createEquipe(Equipe equipe) async {
    try {
      final data = _equipeToMap(equipe);
      
      // Inserir equipe
      final response = await _supabase
          .from('equipes')
          .insert(data)
          .select('id')
          .single()
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('Timeout ao criar equipe'),
          );

      final equipeId = response['id'] as String;

      // Inserir relacionamentos com executores
      if (equipe.executores.isNotEmpty) {
        final executoresData = equipe.executores.map((equipeExecutor) => {
          'equipe_id': equipeId,
          'executor_id': equipeExecutor.executorId,
          'papel': equipeExecutor.papel,
        }).toList();

        await _supabase
            .from('equipes_executores')
            .insert(executoresData);
      }

      // Buscar equipe completa com joins
      final equipeCompleta = await getEquipeById(equipeId);
      if (equipeCompleta != null) {
        return equipeCompleta;
      }

      throw Exception('Erro ao buscar equipe criada');
    } catch (e) {
      print('Erro ao criar equipe: $e');
      return null;
    }
  }

  // Atualizar equipe
  Future<Equipe?> updateEquipe(String id, Equipe equipe) async {
    try {
      final data = _equipeToMap(equipe);

      // Atualizar dados da equipe
      await _supabase
          .from('equipes')
          .update(data)
          .eq('id', id)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('Timeout ao atualizar equipe'),
          );

      // Remover relacionamentos antigos com executores
      await _supabase
          .from('equipes_executores')
          .delete()
          .eq('equipe_id', id);

      // Inserir novos relacionamentos com executores
      if (equipe.executores.isNotEmpty) {
        final executoresData = equipe.executores.map((equipeExecutor) => {
          'equipe_id': id,
          'executor_id': equipeExecutor.executorId,
          'papel': equipeExecutor.papel,
        }).toList();

        await _supabase
            .from('equipes_executores')
            .insert(executoresData);
      }

      // Buscar equipe completa com joins
      final equipeCompleta = await getEquipeById(id);
      if (equipeCompleta != null) {
        return equipeCompleta;
      }

      throw Exception('Erro ao buscar equipe atualizada');
    } catch (e) {
      print('Erro ao atualizar equipe: $e');
      return null;
    }
  }

  // Deletar equipe
  Future<bool> deleteEquipe(String id) async {
    try {
      await _supabase
          .from('equipes')
          .delete()
          .eq('id', id)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('Timeout ao deletar equipe'),
          );

      return true;
    } catch (e) {
      print('Erro ao deletar equipe: $e');
      return false;
    }
  }

  // Filtrar equipes
  Future<List<Equipe>> filterEquipes({
    String? tipo,
    bool? ativo,
  }) async {
    try {
      dynamic query = _supabase.from('equipes').select('''
        *,
        equipes_executores!left(executor_id, papel, executores!inner(id, nome))
      ''');

      if (tipo != null && tipo.isNotEmpty) {
        query = query.eq('tipo', tipo);
      }

      if (ativo != null) {
        query = query.eq('ativo', ativo);
      }

      final response = await query
          .order('nome', ascending: true)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => <Map<String, dynamic>>[],
          );

      if (response.isEmpty) return [];

      final equipesList = response as List;
      return equipesList
          .map((map) => _equipeFromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Erro ao filtrar equipes: $e');
      return [];
    }
  }

  // Buscar equipes por texto
  Future<List<Equipe>> searchEquipes(String query) async {
    if (query.isEmpty) return await getAllEquipes();

    try {
      final response = await _supabase
          .from('equipes')
          .select('''
            *,
            equipes_executores!left(executor_id, papel, executores!inner(id, nome))
          ''')
          .or('nome.ilike.%$query%,descricao.ilike.%$query%')
          .order('nome', ascending: true)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => <Map<String, dynamic>>[],
          );

      if (response.isEmpty) return [];

      final equipesList = response as List;
      return equipesList
          .map((map) => _equipeFromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Erro ao buscar equipes: $e');
      return [];
    }
  }

  // Buscar equipes filtradas por regional, divisão e segmento
  Future<List<Equipe>> getEquipesFiltradas({
    String? regionalId,
    String? divisaoId,
    String? segmentoId,
  }) async {
    try {
      // Se não houver filtros, retornar todas as equipes ativas
      if (regionalId == null && divisaoId == null && segmentoId == null) {
        return await getEquipesAtivas();
      }

      dynamic query = _supabase.from('equipes').select('''
        *,
        regionais!left(regional),
        divisoes!left(divisao),
        segmentos!left(segmento),
        equipes_executores!left(executor_id, papel, executores!inner(id, nome))
      ''').eq('ativo', true);

      // Filtrar por regional
      if (regionalId != null && regionalId.isNotEmpty) {
        query = query.eq('regional_id', regionalId);
      }

      // Filtrar por divisão
      if (divisaoId != null && divisaoId.isNotEmpty) {
        query = query.eq('divisao_id', divisaoId);
      }

      // Filtrar por segmento
      if (segmentoId != null && segmentoId.isNotEmpty) {
        query = query.eq('segmento_id', segmentoId);
      }

      final response = await query
          .order('nome', ascending: true)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => <Map<String, dynamic>>[],
          );

      if (response.isEmpty) return [];

      final equipesList = response as List;
      return equipesList
          .map((map) => _equipeFromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Erro ao buscar equipes filtradas: $e');
      return [];
    }
  }
}

