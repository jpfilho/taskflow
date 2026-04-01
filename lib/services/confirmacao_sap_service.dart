import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/confirmacao_sap.dart';
import '../config/supabase_config.dart';

class ConfirmacaoSapService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  Future<List<ConfirmacaoSap>> list({
    String? search,
    Map<String, dynamic>? filters,
    int page = 0,
    int pageSize = 50,
  }) async {
    try {
      var query = _supabase
          .from('confirmacao_sap')
          .select('*');

      if (search != null && search.isNotEmpty) {
        query = query.or(
          'confirmacao.ilike.%$search%,'
          'ordem.ilike.%$search%,'
          'texto_breve.ilike.%$search%,'
          'criado_por.ilike.%$search%,'
          'tipo.ilike.%$search%,'
          'operacao.ilike.%$search%,'
          'centro_trabalho.ilike.%$search%'
        );
      }

      // Aplicar filtros adicionais
      if (filters != null && filters.isNotEmpty) {
        filters.forEach((key, value) {
          if (value != null) {
            if (value is Iterable && value.isNotEmpty) {
              query = query.inFilter(key, value.toList());
            } else if (value is String && value.isNotEmpty) {
              query = query.eq(key, value);
            }
          }
        });
      }

      final from = page * pageSize;
      final to = from + pageSize - 1;

      final response = await query
          .order('confirmacao', ascending: false)
          .range(from, to);

      final List<dynamic> data = response as List;
      return data.map((item) => ConfirmacaoSap.fromMap(item as Map<String, dynamic>)).toList();
    } catch (e) {
      print('❌ Erro ao listar confirmações SAP: $e');
      rethrow;
    }
  }

  Future<int> count({
    String? search,
    Map<String, dynamic>? filters,
  }) async {
    try {
      var query = _supabase
          .from('confirmacao_sap')
          .select('confirmacao');

      if (search != null && search.isNotEmpty) {
        query = query.or(
          'confirmacao.ilike.%$search%,'
          'ordem.ilike.%$search%,'
          'texto_breve.ilike.%$search%,'
          'criado_por.ilike.%$search%,'
          'tipo.ilike.%$search%,'
          'operacao.ilike.%$search%,'
          'centro_trabalho.ilike.%$search%'
        );
      }

      // Aplicar filtros adicionais
      if (filters != null && filters.isNotEmpty) {
        filters.forEach((key, value) {
          if (value != null) {
            if (value is Iterable && value.isNotEmpty) {
              query = query.inFilter(key, value.toList());
            } else if (value is String && value.isNotEmpty) {
              query = query.eq(key, value);
            }
          }
        });
      }

      final response = await query;
      final List<dynamic> data = response as List;
      return data.length;
    } catch (e) {
      print('❌ Erro ao contar confirmações SAP: $e');
      return 0;
    }
  }

  /// Obter valores únicos para filtros
  Future<List<String>> getDistinctValues(String column) async {
    try {
      final response = await _supabase
          .from('confirmacao_sap')
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
      print('❌ Erro ao obter valores distintos de SAP ($column): $e');
      return [];
    }
  }
}
