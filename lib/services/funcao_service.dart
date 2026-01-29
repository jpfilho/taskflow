import 'dart:async';
import '../models/funcao.dart';
import '../config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FuncaoService {
  static final FuncaoService _instance = FuncaoService._internal();
  factory FuncaoService() => _instance;
  FuncaoService._internal();

  final SupabaseClient _supabase = SupabaseConfig.client;

  // Converter Map do Supabase para Funcao
  Funcao _funcaoFromMap(Map<String, dynamic> map) {
    return Funcao.fromMap(map);
  }

  // Converter Funcao para Map (para Supabase)
  Map<String, dynamic> _funcaoToMap(Funcao funcao) {
    return {
      'funcao': funcao.funcao,
      'descricao': funcao.descricao,
      'ativo': funcao.ativo,
    };
  }

  // Buscar todas as funções
  Future<List<Funcao>> getAllFuncoes() async {
    try {
      final response = await _supabase
          .from('funcoes')
          .select()
          .order('funcao', ascending: true)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              return <Map<String, dynamic>>[];
            },
          );

      if (response.isEmpty) return [];

      final funcoesList = response as List;
      return funcoesList
          .map((map) => _funcaoFromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Erro ao buscar funções: $e');
      return [];
    }
  }

  // Buscar funções ativas
  Future<List<Funcao>> getFuncoesAtivas() async {
    try {
      final response = await _supabase
          .from('funcoes')
          .select()
          .eq('ativo', true)
          .order('funcao', ascending: true)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => <Map<String, dynamic>>[],
          );

      if (response.isEmpty) return [];

      final funcoesList = response as List;
      return funcoesList
          .map((map) => _funcaoFromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Erro ao buscar funções ativas: $e');
      return [];
    }
  }

  // Buscar função por ID
  Future<Funcao?> getFuncaoById(String id) async {
    try {
      final response = await _supabase
          .from('funcoes')
          .select()
          .eq('id', id)
          .single()
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('Timeout ao buscar função'),
          );

      return _funcaoFromMap(response);
    } catch (e) {
      print('Erro ao buscar função por ID: $e');
      return null;
    }
  }

  // Criar nova função
  Future<Funcao?> createFuncao(Funcao funcao) async {
    try {
      final data = _funcaoToMap(funcao);
      final response = await _supabase
          .from('funcoes')
          .insert(data)
          .select()
          .single()
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('Timeout ao criar função'),
          );

      return _funcaoFromMap(response);
    } catch (e) {
      print('Erro ao criar função: $e');
      return null;
    }
  }

  // Atualizar função
  Future<Funcao?> updateFuncao(String id, Funcao funcao) async {
    try {
      final data = _funcaoToMap(funcao);
      final response = await _supabase
          .from('funcoes')
          .update(data)
          .eq('id', id)
          .select()
          .single()
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('Timeout ao atualizar função'),
          );

      return _funcaoFromMap(response);
    } catch (e) {
      print('Erro ao atualizar função: $e');
      return null;
    }
  }

  // Deletar função
  Future<bool> deleteFuncao(String id) async {
    try {
      await _supabase
          .from('funcoes')
          .delete()
          .eq('id', id)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('Timeout ao deletar função'),
          );

      return true;
    } catch (e) {
      print('Erro ao deletar função: $e');
      return false;
    }
  }

  // Filtrar funções
  Future<List<Funcao>> filterFuncoes({
    bool? ativo,
  }) async {
    try {
      dynamic query = _supabase.from('funcoes').select();

      if (ativo != null) {
        query = query.eq('ativo', ativo);
      }

      final response = await query
          .order('funcao', ascending: true)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => <Map<String, dynamic>>[],
          );

      if (response.isEmpty) return [];

      final funcoesList = response as List;
      return funcoesList
          .map((map) => _funcaoFromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Erro ao filtrar funções: $e');
      return [];
    }
  }

  // Buscar funções por texto
  Future<List<Funcao>> searchFuncoes(String query) async {
    if (query.isEmpty) return await getAllFuncoes();

    try {
      final response = await _supabase
          .from('funcoes')
          .select()
          .or('funcao.ilike.%$query%,descricao.ilike.%$query%')
          .order('funcao', ascending: true)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => <Map<String, dynamic>>[],
          );

      if (response.isEmpty) return [];

      final funcoesList = response as List;
      return funcoesList
          .map((map) => _funcaoFromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Erro ao buscar funções: $e');
      return [];
    }
  }
}

