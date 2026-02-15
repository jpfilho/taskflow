import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/confirmacao.dart';

class ConfirmacaoService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  /// Lista confirmações com filtros, busca e paginação
  Future<List<Confirmacao>> list({
    String? search,
    Map<String, dynamic>? filters,
    int page = 0,
    int pageSize = 50,
  }) async {
    try {
      dynamic query = _supabase
          .from('confirmacao')
          .select();

      // Aplicar busca (ilike em ordem, n_pessoal, nomes)
      if (search != null && search.isNotEmpty) {
        query = query.or(
          'ordem.ilike.%$search%,n_pessoal.ilike.%$search%,nomes.ilike.%$search%',
        );
      }

      // Aplicar filtros
      if (filters != null) {
        if (filters['centro_de_trab'] != null && filters['centro_de_trab'] != '') {
          query = query.eq('centro_de_trab', filters['centro_de_trab']);
        }
        if (filters['confirmacao_final'] != null && filters['confirmacao_final'] != '') {
          query = query.eq('confirmacao_final', filters['confirmacao_final']);
        }
        if (filters['tipo_atividade'] != null && filters['tipo_atividade'] != '') {
          query = query.eq('tipo_atividade', filters['tipo_atividade']);
        }
        
        // Filtro de data (range)
        if (filters['data_lancamento_inicio'] != null) {
          final dataInicio = filters['data_lancamento_inicio'] as DateTime;
          final dataInicioStr = '${dataInicio.year.toString().padLeft(4, '0')}-${dataInicio.month.toString().padLeft(2, '0')}-${dataInicio.day.toString().padLeft(2, '0')}';
          query = query.gte('data_lancamento', dataInicioStr);
        }
        if (filters['data_lancamento_fim'] != null) {
          final dataFim = filters['data_lancamento_fim'] as DateTime;
          final dataFimStr = '${dataFim.year.toString().padLeft(4, '0')}-${dataFim.month.toString().padLeft(2, '0')}-${dataFim.day.toString().padLeft(2, '0')}';
          query = query.lte('data_lancamento', dataFimStr);
        }
      }

      // Aplicar ordenação
      query = query
          .order('data_lancamento', ascending: false)
          .order('created_at', ascending: false);

      // Aplicar paginação
      final from = page * pageSize;
      final to = from + pageSize - 1;
      query = query.range(from, to);

      final response = await query;
      
      final List<dynamic> data = response as List;
      return data.map((item) => Confirmacao.fromMap(item as Map<String, dynamic>)).toList();
    } catch (e) {
      print('❌ Erro ao listar confirmações: $e');
      rethrow;
    }
  }

  /// Conta total de confirmações (para paginação)
  Future<int> count({
    String? search,
    Map<String, dynamic>? filters,
  }) async {
    try {
      // Usar abordagem alternativa: buscar todos os IDs e contar localmente
      dynamic query = _supabase
          .from('confirmacao')
          .select('id');

      // Aplicar busca
      if (search != null && search.isNotEmpty) {
        query = query.or(
          'ordem.ilike.%$search%,n_pessoal.ilike.%$search%,nomes.ilike.%$search%',
        );
      }

      // Aplicar filtros
      if (filters != null) {
        if (filters['centro_de_trab'] != null && filters['centro_de_trab'] != '') {
          query = query.eq('centro_de_trab', filters['centro_de_trab']);
        }
        if (filters['confirmacao_final'] != null && filters['confirmacao_final'] != '') {
          query = query.eq('confirmacao_final', filters['confirmacao_final']);
        }
        if (filters['tipo_atividade'] != null && filters['tipo_atividade'] != '') {
          query = query.eq('tipo_atividade', filters['tipo_atividade']);
        }
        
        if (filters['data_lancamento_inicio'] != null) {
          final dataInicio = filters['data_lancamento_inicio'] as DateTime;
          final dataInicioStr = '${dataInicio.year.toString().padLeft(4, '0')}-${dataInicio.month.toString().padLeft(2, '0')}-${dataInicio.day.toString().padLeft(2, '0')}';
          query = query.gte('data_lancamento', dataInicioStr);
        }
        if (filters['data_lancamento_fim'] != null) {
          final dataFim = filters['data_lancamento_fim'] as DateTime;
          final dataFimStr = '${dataFim.year.toString().padLeft(4, '0')}-${dataFim.month.toString().padLeft(2, '0')}-${dataFim.day.toString().padLeft(2, '0')}';
          query = query.lte('data_lancamento', dataFimStr);
        }
      }

      final response = await query;
      final List<dynamic> data = response as List;
      return data.length;
    } catch (e) {
      print('❌ Erro ao contar confirmações: $e');
      return 0;
    }
  }

  /// Criar nova confirmação
  Future<Confirmacao> create(Map<String, dynamic> payload) async {
    try {
      // Adicionar updated_at = now() automaticamente
      payload['updated_at'] = DateTime.now().toIso8601String();
      
      final response = await _supabase
          .from('confirmacao')
          .insert(payload)
          .select()
          .single();

      return Confirmacao.fromMap(response);
    } catch (e) {
      print('❌ Erro ao criar confirmação: $e');
      rethrow;
    }
  }

  /// Atualizar confirmação existente
  Future<Confirmacao> update(String id, Map<String, dynamic> payload) async {
    try {
      // Adicionar updated_at = now() automaticamente
      payload['updated_at'] = DateTime.now().toIso8601String();
      
      final response = await _supabase
          .from('confirmacao')
          .update(payload)
          .eq('id', id)
          .select()
          .single();

      return Confirmacao.fromMap(response);
    } catch (e) {
      print('❌ Erro ao atualizar confirmação: $e');
      rethrow;
    }
  }

  /// Deletar confirmação
  Future<void> delete(String id) async {
    try {
      await _supabase
          .from('confirmacao')
          .delete()
          .eq('id', id);
    } catch (e) {
      print('❌ Erro ao deletar confirmação: $e');
      rethrow;
    }
  }

  /// Obter valores únicos para filtros (centro_de_trab, confirmacao_final, tipo_atividade)
  Future<List<String>> getDistinctValues(String column) async {
    try {
      final response = await _supabase
          .from('confirmacao')
          .select(column)
          .not(column, 'is', null);

      final List<dynamic> data = response as List;
      final values = data
          .map((item) => item[column]?.toString())
          .where((value) => value != null && value.isNotEmpty)
          .toSet()
          .toList();
      
      values.sort();
      return values.cast<String>();
    } catch (e) {
      print('❌ Erro ao obter valores distintos de $column: $e');
      return [];
    }
  }
}
