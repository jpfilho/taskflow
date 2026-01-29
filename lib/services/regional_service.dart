import '../models/regional.dart';
import '../config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegionalService {
  static final RegionalService _instance = RegionalService._internal();
  factory RegionalService() => _instance;
  RegionalService._internal();

  final SupabaseClient _supabase = SupabaseConfig.client;

  // Converter Map do Supabase para Regional
  Regional _regionalFromMap(Map<String, dynamic> map) {
    return Regional(
      id: map['id'] as String,
      regional: map['regional'] as String,
      divisao: map['divisao'] as String,
      empresa: map['empresa'] as String,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  // Converter Regional para Map (para Supabase)
  Map<String, dynamic> _regionalToMap(Regional regional) {
    return {
      'regional': regional.regional,
      'divisao': regional.divisao,
      'empresa': regional.empresa,
    };
  }

  // Buscar todas as regionais
  Future<List<Regional>> getAllRegionais() async {
    try {
      print('🔍 DEBUG RegionalService: Iniciando busca de regionais...');
      final response = await _supabase
          .from('regionais')
          .select()
          .order('regional', ascending: true)
          .order('divisao', ascending: true)
          .order('empresa', ascending: true)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Timeout ao buscar regionais após 30 segundos');
            },
          );

      print('✅ DEBUG RegionalService: Resposta recebida: ${response.length} registros');

      if (response.isEmpty) {
        print('⚠️ DEBUG RegionalService: Nenhuma regional encontrada');
        return [];
      }

      final regionaisList = response as List;
      final regionais = regionaisList
          .map((map) {
            try {
              return _regionalFromMap(map as Map<String, dynamic>);
            } catch (e) {
              print('❌ Erro ao converter regional: $e');
              print('   Dados: $map');
              return null;
            }
          })
          .whereType<Regional>()
          .toList();
      
      print('✅ DEBUG RegionalService: ${regionais.length} regionais convertidas com sucesso');
      return regionais;
    } catch (e, stackTrace) {
      print('❌ Erro ao buscar regionais: $e');
      print('❌ Stack trace: $stackTrace');
      return [];
    }
  }

  // Buscar regional por ID
  Future<Regional?> getRegionalById(String id) async {
    try {
      final response = await _supabase
          .from('regionais')
          .select()
          .eq('id', id)
          .single()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              return <String, dynamic>{};
            },
          );

      if (response.isEmpty) return null;

      return _regionalFromMap(response);
    } catch (e) {
      print('Erro ao buscar regional por ID: $e');
      return null;
    }
  }

  // Verificar se já existe uma regional com o mesmo nome
  Future<bool> existeRegional(String nome) async {
    try {
      final response = await _supabase
          .from('regionais')
          .select('id')
          .eq('regional', nome)
          .maybeSingle();
      
      return response != null;
    } catch (e) {
      print('Erro ao verificar se regional existe: $e');
      return false;
    }
  }

  // Criar regional
  Future<Regional?> createRegional(Regional regional) async {
    try {
      // Verificar se já existe uma regional com o mesmo nome
      final existe = await existeRegional(regional.regional);
      if (existe) {
        throw Exception('Já existe uma regional com o nome "${regional.regional}". Os nomes de regionais devem ser únicos.');
      }

      final regionalMap = _regionalToMap(regional);
      regionalMap.remove('id'); // Remover ID para gerar UUID no Supabase

      final response = await _supabase
          .from('regionais')
          .insert(regionalMap)
          .select()
          .single();

      return _regionalFromMap(response);
    } catch (e) {
      print('Erro ao criar regional: $e');
      rethrow; // Re-lançar o erro para que o UI possa tratá-lo
    }
  }

  // Atualizar regional
  Future<Regional?> updateRegional(String id, Regional regional) async {
    try {
      // Verificar se já existe outra regional com o mesmo nome (excluindo a atual)
      final responseExistente = await _supabase
          .from('regionais')
          .select('id')
          .eq('regional', regional.regional)
          .neq('id', id)
          .maybeSingle();
      
      if (responseExistente != null) {
        throw Exception('Já existe outra regional com o nome "${regional.regional}". Os nomes de regionais devem ser únicos.');
      }

      final regionalMap = _regionalToMap(regional);

      final response = await _supabase
          .from('regionais')
          .update(regionalMap)
          .eq('id', id)
          .select()
          .single();

      return _regionalFromMap(response);
    } catch (e) {
      print('Erro ao atualizar regional: $e');
      rethrow; // Re-lançar o erro para que o UI possa tratá-lo
    }
  }

  // Deletar regional
  Future<bool> deleteRegional(String id) async {
    try {
      await _supabase.from('regionais').delete().eq('id', id);
      return true;
    } catch (e) {
      print('Erro ao deletar regional: $e');
      return false;
    }
  }

  // Buscar regionais por filtros
  Future<List<Regional>> filterRegionais({
    String? regional,
    String? divisao,
    String? empresa,
  }) async {
    try {
      var query = _supabase.from('regionais').select();

      if (regional != null && regional.isNotEmpty) {
        query = query.ilike('regional', '%$regional%');
      }
      if (divisao != null && divisao.isNotEmpty) {
        query = query.ilike('divisao', '%$divisao%');
      }
      if (empresa != null && empresa.isNotEmpty) {
        query = query.ilike('empresa', '%$empresa%');
      }

      final response = await query
          .order('regional', ascending: true)
          .order('divisao', ascending: true)
          .order('empresa', ascending: true)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              return <Map<String, dynamic>>[];
            },
          );

      if (response.isEmpty) return [];

      final regionaisList = response as List;
      return regionaisList
          .map((map) => _regionalFromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Erro ao filtrar regionais: $e');
      return [];
    }
  }

  // Buscar regionais por texto (busca em todos os campos)
  Future<List<Regional>> searchRegionais(String query) async {
    if (query.isEmpty) {
      return getAllRegionais();
    }

    try {
      final response = await _supabase
          .from('regionais')
          .select()
          .or(
            'regional.ilike.%$query%,divisao.ilike.%$query%,empresa.ilike.%$query%',
          )
          .order('regional', ascending: true)
          .order('divisao', ascending: true)
          .order('empresa', ascending: true)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              return <Map<String, dynamic>>[];
            },
          );

      if (response.isEmpty) return [];

      final regionaisList = response as List;
      return regionaisList
          .map((map) => _regionalFromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Erro ao buscar regionais: $e');
      return [];
    }
  }
}

