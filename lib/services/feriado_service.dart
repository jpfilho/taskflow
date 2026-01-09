import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/feriado.dart';
import '../config/supabase_config.dart';

class FeriadoService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  // Buscar todos os feriados
  Future<List<Feriado>> getAllFeriados() async {
    try {
      final response = await _supabase
          .from('feriados')
          .select()
          .order('data', ascending: true);

      return List<Map<String, dynamic>>.from(response)
          .map((map) => Feriado.fromMap(map))
          .toList();
    } catch (e) {
      print('Erro ao buscar feriados: $e');
      rethrow;
    }
  }

  // Buscar feriados por data
  Future<List<Feriado>> getFeriadosByDate(DateTime date) async {
    try {
      final dateStr = date.toIso8601String().split('T')[0]; // YYYY-MM-DD
      
      final response = await _supabase
          .from('feriados')
          .select()
          .eq('data', dateStr);

      return List<Map<String, dynamic>>.from(response)
          .map((map) => Feriado.fromMap(map))
          .toList();
    } catch (e) {
      print('Erro ao buscar feriados por data: $e');
      rethrow;
    }
  }

  // Buscar feriados em um range de datas
  Future<List<Feriado>> getFeriadosByDateRange(DateTime startDate, DateTime endDate) async {
    try {
      final startStr = startDate.toIso8601String().split('T')[0];
      final endStr = endDate.toIso8601String().split('T')[0];
      
      final response = await _supabase
          .from('feriados')
          .select()
          .gte('data', startStr)
          .lte('data', endStr)
          .order('data', ascending: true);

      return List<Map<String, dynamic>>.from(response)
          .map((map) => Feriado.fromMap(map))
          .toList();
    } catch (e) {
      print('Erro ao buscar feriados por range de datas: $e');
      rethrow;
    }
  }

  // Buscar feriados por tipo
  Future<List<Feriado>> getFeriadosByTipo(String tipo) async {
    try {
      final response = await _supabase
          .from('feriados')
          .select()
          .eq('tipo', tipo)
          .order('data', ascending: true);

      return List<Map<String, dynamic>>.from(response)
          .map((map) => Feriado.fromMap(map))
          .toList();
    } catch (e) {
      print('Erro ao buscar feriados por tipo: $e');
      rethrow;
    }
  }

  // Buscar feriado por ID
  Future<Feriado?> getFeriadoById(String id) async {
    try {
      final response = await _supabase
          .from('feriados')
          .select()
          .eq('id', id)
          .single();

      return Feriado.fromMap(Map<String, dynamic>.from(response));
    } catch (e) {
      print('Erro ao buscar feriado por ID: $e');
      return null;
    }
  }

  // Criar novo feriado
  Future<Feriado> createFeriado(Feriado feriado) async {
    try {
      final map = feriado.toMap();
      // Remover campos que serão gerados automaticamente
      map.remove('id');
      map.remove('created_at');
      map.remove('updated_at');

      final response = await _supabase
          .from('feriados')
          .insert(map)
          .select()
          .single();

      return Feriado.fromMap(Map<String, dynamic>.from(response));
    } catch (e) {
      print('Erro ao criar feriado: $e');
      rethrow;
    }
  }

  // Atualizar feriado
  Future<Feriado> updateFeriado(Feriado feriado) async {
    try {
      final map = feriado.toMap();
      // Remover campos que não devem ser atualizados
      map.remove('created_at');
      map.remove('updated_at');

      final response = await _supabase
          .from('feriados')
          .update(map)
          .eq('id', feriado.id)
          .select()
          .single();

      return Feriado.fromMap(Map<String, dynamic>.from(response));
    } catch (e) {
      print('Erro ao atualizar feriado: $e');
      rethrow;
    }
  }

  // Deletar feriado
  Future<void> deleteFeriado(String id) async {
    try {
      await _supabase
          .from('feriados')
          .delete()
          .eq('id', id);
    } catch (e) {
      print('Erro ao deletar feriado: $e');
      rethrow;
    }
  }

  // Verificar se uma data é feriado
  Future<bool> isFeriado(DateTime date) async {
    try {
      final feriados = await getFeriadosByDate(date);
      return feriados.isNotEmpty;
    } catch (e) {
      print('Erro ao verificar se é feriado: $e');
      return false;
    }
  }

  // Obter mapa de feriados por data (para uso no Gantt)
  Future<Map<DateTime, List<Feriado>>> getFeriadosMapByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final feriados = await getFeriadosByDateRange(startDate, endDate);
      final Map<DateTime, List<Feriado>> map = {};

      for (var feriado in feriados) {
        final date = DateTime(feriado.data.year, feriado.data.month, feriado.data.day);
        if (!map.containsKey(date)) {
          map[date] = [];
        }
        map[date]!.add(feriado);
      }

      return map;
    } catch (e) {
      print('Erro ao obter mapa de feriados: $e');
      return {};
    }
  }
}

