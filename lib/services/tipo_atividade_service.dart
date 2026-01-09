import 'dart:async';
import '../models/tipo_atividade.dart';
import '../config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TipoAtividadeService {
  static final TipoAtividadeService _instance = TipoAtividadeService._internal();
  factory TipoAtividadeService() => _instance;
  TipoAtividadeService._internal();

  final SupabaseClient _supabase = SupabaseConfig.client;

  // Converter Map do Supabase para TipoAtividade
  TipoAtividade _tipoAtividadeFromMap(Map<String, dynamic> map) {
    return TipoAtividade.fromMap(map);
  }

  // Converter TipoAtividade para Map (para Supabase)
  Map<String, dynamic> _tipoAtividadeToMap(TipoAtividade tipoAtividade) {
    return {
      'codigo': tipoAtividade.codigo,
      'descricao': tipoAtividade.descricao,
      'ativo': tipoAtividade.ativo,
      if (tipoAtividade.cor != null) 'cor': tipoAtividade.cor,
    };
  }

  // Buscar todos os tipos de atividade
  Future<List<TipoAtividade>> getAllTiposAtividade() async {
    try {
      final response = await _supabase
          .from('tipos_atividade')
          .select('''
            *,
            tipos_atividade_segmentos!left(segmentos!inner(id, segmento))
          ''')
          .order('codigo', ascending: true)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => <Map<String, dynamic>>[],
          );

      if (response.isEmpty) return [];

      final tiposList = response as List;
      return tiposList
          .map((map) => _tipoAtividadeFromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Erro ao buscar tipos de atividade: $e');
      return [];
    }
  }

  // Buscar tipos de atividade ativos
  Future<List<TipoAtividade>> getTiposAtividadeAtivos() async {
    try {
      final response = await _supabase
          .from('tipos_atividade')
          .select('''
            *,
            tipos_atividade_segmentos!left(segmentos!inner(id, segmento))
          ''')
          .eq('ativo', true)
          .order('codigo', ascending: true)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => <Map<String, dynamic>>[],
          );

      if (response.isEmpty) return [];

      final tiposList = response as List;
      return tiposList
          .map((map) => _tipoAtividadeFromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Erro ao buscar tipos de atividade ativos: $e');
      return [];
    }
  }

  // Buscar tipo de atividade por ID
  Future<TipoAtividade?> getTipoAtividadeById(String id) async {
    try {
      final response = await _supabase
          .from('tipos_atividade')
          .select('''
            *,
            tipos_atividade_segmentos!left(segmentos!inner(id, segmento))
          ''')
          .eq('id', id)
          .single()
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('Timeout ao buscar tipo de atividade'),
          );

      return _tipoAtividadeFromMap(response);
    } catch (e) {
      print('Erro ao buscar tipo de atividade por ID: $e');
      return null;
    }
  }

  // Criar novo tipo de atividade
  Future<TipoAtividade?> createTipoAtividade(TipoAtividade tipoAtividade) async {
    try {
      final data = _tipoAtividadeToMap(tipoAtividade);
      
      // Inserir tipo de atividade
      final response = await _supabase
          .from('tipos_atividade')
          .insert(data)
          .select('id')
          .single()
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('Timeout ao criar tipo de atividade'),
          );

      final tipoId = response['id'] as String;

      // Inserir relacionamentos com segmentos
      if (tipoAtividade.segmentoIds.isNotEmpty) {
        final segmentosData = tipoAtividade.segmentoIds.map((segmentoId) => {
          'tipo_atividade_id': tipoId,
          'segmento_id': segmentoId,
        }).toList();

        await _supabase
            .from('tipos_atividade_segmentos')
            .insert(segmentosData);
      }

      // Buscar tipo completo com joins
      final tipoCompleto = await getTipoAtividadeById(tipoId);
      if (tipoCompleto != null) {
        return tipoCompleto;
      }

      throw Exception('Erro ao buscar tipo de atividade criado');
    } catch (e) {
      print('Erro ao criar tipo de atividade: $e');
      return null;
    }
  }

  // Atualizar tipo de atividade
  Future<TipoAtividade?> updateTipoAtividade(String id, TipoAtividade tipoAtividade) async {
    try {
      final data = _tipoAtividadeToMap(tipoAtividade);

      // Atualizar dados do tipo de atividade
      await _supabase
          .from('tipos_atividade')
          .update(data)
          .eq('id', id)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('Timeout ao atualizar tipo de atividade'),
          );

      // Remover relacionamentos antigos com segmentos
      await _supabase
          .from('tipos_atividade_segmentos')
          .delete()
          .eq('tipo_atividade_id', id);

      // Inserir novos relacionamentos com segmentos
      if (tipoAtividade.segmentoIds.isNotEmpty) {
        final segmentosData = tipoAtividade.segmentoIds.map((segmentoId) => {
          'tipo_atividade_id': id,
          'segmento_id': segmentoId,
        }).toList();

        await _supabase
            .from('tipos_atividade_segmentos')
            .insert(segmentosData);
      }

      // Buscar tipo completo com joins
      final tipoCompleto = await getTipoAtividadeById(id);
      if (tipoCompleto != null) {
        return tipoCompleto;
      }

      throw Exception('Erro ao buscar tipo de atividade atualizado');
    } catch (e) {
      print('Erro ao atualizar tipo de atividade: $e');
      return null;
    }
  }

  // Deletar tipo de atividade
  Future<bool> deleteTipoAtividade(String id) async {
    try {
      await _supabase
          .from('tipos_atividade')
          .delete()
          .eq('id', id)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('Timeout ao deletar tipo de atividade'),
          );

      return true;
    } catch (e) {
      print('Erro ao deletar tipo de atividade: $e');
      return false;
    }
  }

  // Filtrar tipos de atividade
  Future<List<TipoAtividade>> filterTiposAtividade({
    bool? ativo,
  }) async {
    try {
      dynamic query = _supabase.from('tipos_atividade').select('''
        *,
        tipos_atividade_segmentos!left(segmentos!inner(id, segmento))
      ''');

      if (ativo != null) {
        query = query.eq('ativo', ativo);
      }

      final response = await query
          .order('codigo', ascending: true)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => <Map<String, dynamic>>[],
          );

      if (response.isEmpty) return [];

      final tiposList = response as List;
      return tiposList
          .map((map) => _tipoAtividadeFromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Erro ao filtrar tipos de atividade: $e');
      return [];
    }
  }

  // Buscar tipos de atividade por texto
  Future<List<TipoAtividade>> searchTiposAtividade(String query) async {
    if (query.isEmpty) return await getAllTiposAtividade();

    try {
      final response = await _supabase
          .from('tipos_atividade')
          .select('''
            *,
            tipos_atividade_segmentos!left(segmentos!inner(id, segmento))
          ''')
          .or('codigo.ilike.%$query%,descricao.ilike.%$query%')
          .order('codigo', ascending: true)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => <Map<String, dynamic>>[],
          );

      if (response.isEmpty) return [];

      final tiposList = response as List;
      return tiposList
          .map((map) => _tipoAtividadeFromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Erro ao buscar tipos de atividade: $e');
      return [];
    }
  }
}


