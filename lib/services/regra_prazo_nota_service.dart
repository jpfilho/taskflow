import '../models/regra_prazo_nota.dart';
import '../config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegraPrazoNotaService {
  static final RegraPrazoNotaService _instance = RegraPrazoNotaService._internal();
  factory RegraPrazoNotaService() => _instance;
  RegraPrazoNotaService._internal();

  final SupabaseClient _supabase = SupabaseConfig.client;

  // Buscar segmentos de uma regra
  Future<List<String>> _getSegmentosIds(String regraId) async {
    try {
      final response = await _supabase
          .from('regras_prazo_notas_segmentos')
          .select('segmento_id')
          .eq('regra_prazo_nota_id', regraId);
      
      if (response.isEmpty) return [];
      
      return (response as List)
          .map((map) => map['segmento_id'] as String)
          .toList();
    } catch (e) {
      print('Erro ao buscar segmentos da regra: $e');
      return [];
    }
  }

  // Converter Map do Supabase para RegraPrazoNota
  Future<RegraPrazoNota> _regraFromMap(Map<String, dynamic> map) async {
    final segmentoIds = await _getSegmentosIds(map['id'] as String);
    return RegraPrazoNota.fromMap(map, segmentoIds: segmentoIds);
  }

  // Converter RegraPrazoNota para Map (para Supabase)
  Map<String, dynamic> _regraToMap(RegraPrazoNota regra) {
    final map = regra.toMap();
    // Remover campos que não devem ser enviados no insert/update
    map.remove('id');
    map.remove('created_at');
    map.remove('updated_at');
    return map;
  }

  // Buscar todas as regras
  Future<List<RegraPrazoNota>> getAllRegras() async {
    try {
      final response = await _supabase
          .from('regras_prazo_notas')
          .select()
          .order('prioridade', ascending: true)
          .order('data_referencia', ascending: true)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              return <Map<String, dynamic>>[];
            },
          );

      if (response.isEmpty) return [];

      final regrasList = response as List;
      final regras = <RegraPrazoNota>[];
      for (var map in regrasList) {
        final regra = await _regraFromMap(map);
        regras.add(regra);
      }
      return regras;
    } catch (e) {
      print('Erro ao buscar regras de prazo: $e');
      return [];
    }
  }

  // Buscar regras ativas
  Future<List<RegraPrazoNota>> getRegrasAtivas() async {
    try {
      final response = await _supabase
          .from('regras_prazo_notas')
          .select()
          .eq('ativo', true)
          .order('prioridade', ascending: true)
          .order('data_referencia', ascending: true)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              return <Map<String, dynamic>>[];
            },
          );

      if (response.isEmpty) return [];

      final regrasList = response as List;
      final regras = <RegraPrazoNota>[];
      for (var map in regrasList) {
        final regra = await _regraFromMap(map);
        regras.add(regra);
      }
      return regras;
    } catch (e) {
      print('Erro ao buscar regras ativas: $e');
      return [];
    }
  }

  // Buscar regra por ID
  Future<RegraPrazoNota?> getRegraById(String id) async {
    try {
      final response = await _supabase
          .from('regras_prazo_notas')
          .select()
          .eq('id', id)
          .single()
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              return <String, dynamic>{};
            },
          );

      if (response.isEmpty) return null;

      return await _regraFromMap(response);
    } catch (e) {
      print('Erro ao buscar regra por ID: $e');
      return null;
    }
  }

  // Salvar segmentos de uma regra
  Future<void> _saveSegmentos(String regraId, List<String> segmentoIds) async {
    try {
      // Remover segmentos existentes
      await _supabase
          .from('regras_prazo_notas_segmentos')
          .delete()
          .eq('regra_prazo_nota_id', regraId);
      
      // Inserir novos segmentos
      if (segmentoIds.isNotEmpty) {
        final inserts = segmentoIds.map((segmentoId) => {
          'regra_prazo_nota_id': regraId,
          'segmento_id': segmentoId,
        }).toList();
        
        await _supabase
            .from('regras_prazo_notas_segmentos')
            .insert(inserts);
      }
    } catch (e) {
      print('Erro ao salvar segmentos da regra: $e');
      rethrow;
    }
  }

  // Buscar regra por prioridade, data_referencia e segmento (ativa)
  // Se segmentoId for fornecido, busca regra específica do segmento ou regra geral (sem segmentos)
  Future<RegraPrazoNota?> getRegraAtiva(String prioridade, String dataReferencia, {String? segmentoId}) async {
    try {
      // Buscar todas as regras ativas com essa prioridade e data_referencia
      final response = await _supabase
          .from('regras_prazo_notas')
          .select()
          .eq('prioridade', prioridade)
          .eq('data_referencia', dataReferencia)
          .eq('ativo', true)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              return <Map<String, dynamic>>[];
            },
          );

      if (response.isEmpty) return null;

      // Para cada regra, verificar se se aplica ao segmento
      for (var map in response as List) {
        final regra = await _regraFromMap(map);
        
        // Se a regra não tem segmentos específicos, se aplica a todos
        if (regra.segmentoIds.isEmpty) {
          return regra;
        }
        
        // Se a regra tem segmentos específicos e o segmentoId está na lista
        if (segmentoId != null && regra.segmentoIds.contains(segmentoId)) {
          return regra;
        }
      }

      return null;
    } catch (e) {
      print('Erro ao buscar regra ativa: $e');
      return null;
    }
  }

  // Criar nova regra
  Future<RegraPrazoNota?> createRegra(RegraPrazoNota regra) async {
    try {
      // Salvar a regra principal
      final response = await _supabase
          .from('regras_prazo_notas')
          .insert(_regraToMap(regra))
          .select()
          .single()
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Timeout ao criar regra');
            },
          );

      final regraId = response['id'] as String;
      
      // Salvar segmentos relacionados
      await _saveSegmentos(regraId, regra.segmentoIds);
      
      // Retornar regra completa
      return await _regraFromMap(response);
    } catch (e) {
      print('Erro ao criar regra: $e');
      rethrow;
    }
  }

  // Atualizar regra
  Future<RegraPrazoNota?> updateRegra(String id, RegraPrazoNota regra) async {
    try {
      // Atualizar a regra principal
      final response = await _supabase
          .from('regras_prazo_notas')
          .update(_regraToMap(regra))
          .eq('id', id)
          .select()
          .single()
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Timeout ao atualizar regra');
            },
          );

      // Atualizar segmentos relacionados
      await _saveSegmentos(id, regra.segmentoIds);
      
      // Retornar regra completa
      return await _regraFromMap(response);
    } catch (e) {
      print('Erro ao atualizar regra: $e');
      rethrow;
    }
  }

  // Deletar regra
  // Os segmentos serão deletados automaticamente devido ao ON DELETE CASCADE
  Future<bool> deleteRegra(String id) async {
    try {
      await _supabase
          .from('regras_prazo_notas')
          .delete()
          .eq('id', id)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Timeout ao deletar regra');
            },
          );

      return true;
    } catch (e) {
      print('Erro ao deletar regra: $e');
      return false;
    }
  }

  // Calcular data de vencimento baseado na regra
  DateTime? calcularDataVencimento(RegraPrazoNota regra, DateTime? dataReferencia) {
    if (dataReferencia == null) return null;
    return dataReferencia.add(Duration(days: regra.diasPrazo));
  }
}
