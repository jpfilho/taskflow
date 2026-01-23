import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/apr.dart';

class APRService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Criar ou atualizar APR
  Future<APR?> createOrUpdateAPR(APR apr) async {
    try {
      if (apr.id == null) {
        // Criar novo
        final response = await _supabase
            .from('apr')
            .insert(apr.toMap())
            .select()
            .single();
        return APR.fromMap(response);
      } else {
        // Atualizar existente
        final response = await _supabase
            .from('apr')
            .update(apr.toMap())
            .eq('id', apr.id!)
            .select()
            .single();
        return APR.fromMap(response);
      }
    } catch (e) {
      print('❌ Erro ao salvar APR: $e');
      rethrow;
    }
  }

  // Buscar APR por task_id
  Future<APR?> getAPRByTaskId(String taskId) async {
    try {
      final response = await _supabase
          .from('apr')
          .select()
          .eq('task_id', taskId)
          .maybeSingle();
      
      if (response == null) return null;
      return APR.fromMap(response);
    } catch (e) {
      print('❌ Erro ao buscar APR: $e');
      return null;
    }
  }

  // Deletar APR
  Future<bool> deleteAPR(String id) async {
    try {
      await _supabase.from('apr').delete().eq('id', id);
      return true;
    } catch (e) {
      print('❌ Erro ao deletar APR: $e');
      return false;
    }
  }

  // Buscar todos os APR
  Future<List<APR>> getAllAPR() async {
    try {
      final response = await _supabase
          .from('apr')
          .select()
          .order('created_at', ascending: false);
      
      return (response as List).map((map) => APR.fromMap(map)).toList();
    } catch (e) {
      print('❌ Erro ao buscar todos os APR: $e');
      return [];
    }
  }
}
