import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/crc.dart';

class CRCService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Criar ou atualizar CRC
  Future<CRC?> createOrUpdateCRC(CRC crc) async {
    try {
      if (crc.id == null) {
        // Criar novo
        final response = await _supabase
            .from('crc')
            .insert(crc.toMap())
            .select()
            .single();
        return CRC.fromMap(response);
      } else {
        // Atualizar existente
        final response = await _supabase
            .from('crc')
            .update(crc.toMap())
            .eq('id', crc.id!)
            .select()
            .single();
        return CRC.fromMap(response);
      }
    } catch (e) {
      print('❌ Erro ao salvar CRC: $e');
      rethrow;
    }
  }

  // Buscar CRC por task_id
  Future<CRC?> getCRCByTaskId(String taskId) async {
    try {
      final response = await _supabase
          .from('crc')
          .select()
          .eq('task_id', taskId)
          .maybeSingle();
      
      if (response == null) return null;
      return CRC.fromMap(response);
    } catch (e) {
      print('❌ Erro ao buscar CRC: $e');
      return null;
    }
  }

  // Deletar CRC
  Future<bool> deleteCRC(String id) async {
    try {
      await _supabase.from('crc').delete().eq('id', id);
      return true;
    } catch (e) {
      print('❌ Erro ao deletar CRC: $e');
      return false;
    }
  }

  // Buscar todos os CRC
  Future<List<CRC>> getAllCRC() async {
    try {
      final response = await _supabase
          .from('crc')
          .select()
          .order('created_at', ascending: false);
      
      return (response as List).map((map) => CRC.fromMap(map)).toList();
    } catch (e) {
      print('❌ Erro ao buscar todos os CRC: $e');
      return [];
    }
  }
}
