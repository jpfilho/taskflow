import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pex.dart';

class PEXService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Criar ou atualizar PEX
  Future<PEX?> createOrUpdatePEX(PEX pex) async {
    try {
      // Preparar dados para inserção/atualização
      final data = _preparePEXData(pex);
      
      if (pex.id == null) {
        // Criar novo - remover campos que não devem ser enviados na criação
        data.remove('id');
        data.remove('created_at');
        data.remove('updated_at');
        
        print('📝 Criando novo PEX com ${data.length} campos');
        final response = await _supabase
            .from('pex')
            .insert(data)
            .select()
            .single();
        return PEX.fromMap(response);
      } else {
        // Atualizar existente - remover campos que não devem ser atualizados
        data.remove('id');
        data.remove('created_at');
        // updated_at será atualizado pelo trigger
        
        print('📝 Atualizando PEX ${pex.id} com ${data.length} campos');
        final response = await _supabase
            .from('pex')
            .update(data)
            .eq('id', pex.id!)
            .select()
            .single();
        return PEX.fromMap(response);
      }
    } catch (e) {
      print('❌ Erro ao salvar PEX: $e');
      print('   Tipo do erro: ${e.runtimeType}');
      if (e is PostgrestException) {
        print('   Código: ${e.code}');
        print('   Mensagem: ${e.message}');
        print('   Detalhes: ${e.details}');
        print('   Hint: ${e.hint}');
      }
      rethrow;
    }
  }

  // Preparar dados do PEX removendo valores null e sanitizando
  Map<String, dynamic> _preparePEXData(PEX pex) {
    final map = pex.toMap();
    
    // Remover valores null (exceto para campos que podem ser null)
    final cleaned = <String, dynamic>{};
    
    for (var entry in map.entries) {
      final key = entry.key;
      var value = entry.value;
      
      // Sempre incluir task_id
      if (key == 'task_id') {
        cleaned[key] = value;
        continue;
      }
      
      // Converter datas para formato correto
      if (value is String && value.contains('T') && value.contains('Z')) {
        // É uma data ISO8601, converter para formato DATE ou TIME
        try {
          final dateTime = DateTime.parse(value);
          if (key.contains('_data') || key == 'data_elaboracao' || key == 'data_inicio' || 
              key == 'data_fim' || key == 'data_aprovacao') {
            // Formato DATE: YYYY-MM-DD
            value = '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
          } else if (key.contains('_at')) {
            // Timestamp - manter ISO8601
            value = value;
          }
        } catch (e) {
          print('⚠️ Erro ao converter data $key: $e');
        }
      }
      
      // Incluir campos que podem ser null mas não são null
      if (value != null) {
        // Sanitizar strings
        if (value is String) {
          // Remover caracteres de controle e limitar tamanho
          String cleanedValue = value.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
          if (cleanedValue.isNotEmpty) {
            cleaned[key] = cleanedValue;
          }
        } else {
          cleaned[key] = value;
        }
      }
      // Não incluir campos null (exceto os que são explicitamente nullable no banco)
    }
    
    return cleaned;
  }

  // Buscar PEX por task_id
  Future<PEX?> getPEXByTaskId(String taskId) async {
    try {
      final response = await _supabase
          .from('pex')
          .select()
          .eq('task_id', taskId)
          .maybeSingle();
      
      if (response == null) return null;
      return PEX.fromMap(response);
    } catch (e) {
      print('❌ Erro ao buscar PEX: $e');
      return null;
    }
  }

  // Deletar PEX
  Future<bool> deletePEX(String id) async {
    try {
      await _supabase.from('pex').delete().eq('id', id);
      return true;
    } catch (e) {
      print('❌ Erro ao deletar PEX: $e');
      return false;
    }
  }

  // Buscar todos os PEX
  Future<List<PEX>> getAllPEX() async {
    try {
      final response = await _supabase
          .from('pex')
          .select()
          .order('created_at', ascending: false);
      
      return (response as List).map((map) => PEX.fromMap(map)).toList();
    } catch (e) {
      print('❌ Erro ao buscar todos os PEX: $e');
      return [];
    }
  }
}
