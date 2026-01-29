import '../models/centro_trabalho.dart';
import '../config/supabase_config.dart';
import '../services/regional_service.dart';
import '../services/divisao_service.dart';
import '../services/segmento_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CentroTrabalhoService {
  static final CentroTrabalhoService _instance = CentroTrabalhoService._internal();
  factory CentroTrabalhoService() => _instance;
  CentroTrabalhoService._internal();

  final SupabaseClient _supabase = SupabaseConfig.client;
  final RegionalService _regionalService = RegionalService();
  final DivisaoService _divisaoService = DivisaoService();
  final SegmentoService _segmentoService = SegmentoService();

  // Converter Map do Supabase para CentroTrabalho
  CentroTrabalho _centroTrabalhoFromMap(Map<String, dynamic> map) {
    return CentroTrabalho.fromMap(map);
  }

  // Converter CentroTrabalho para Map (para Supabase)
  Map<String, dynamic> _centroTrabalhoToMap(CentroTrabalho centroTrabalho) {
    return {
      'centro_trabalho': centroTrabalho.centroTrabalho,
      'descricao': centroTrabalho.descricao,
      'regional_id': centroTrabalho.regionalId,
      'divisao_id': centroTrabalho.divisaoId,
      'segmento_id': centroTrabalho.segmentoId,
      'gpm': centroTrabalho.gpm,
      'ativo': centroTrabalho.ativo,
    };
  }

  // Buscar todos os centros de trabalho
  Future<List<CentroTrabalho>> getAllCentrosTrabalho() async {
    try {
      final response = await _supabase
          .from('centros_trabalho')
          .select('*, regionais!left(regional), divisoes!left(divisao), segmentos!left(segmento)')
          .order('centro_trabalho', ascending: true)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              return <Map<String, dynamic>>[];
            },
          );

      if (response.isEmpty) return [];

      final centrosList = response as List;
      return centrosList
          .map((map) => _centroTrabalhoFromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Erro ao buscar centros de trabalho: $e');
      // Fallback: buscar sem join
      try {
        final response = await _supabase
            .from('centros_trabalho')
            .select()
            .order('centro_trabalho', ascending: true)
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () => <Map<String, dynamic>>[],
            );

        if (response.isEmpty) return [];

        final centrosList = response as List;
        final centros = centrosList
            .map((map) => _centroTrabalhoFromMap(map as Map<String, dynamic>))
            .toList();

        // Carregar nomes das associações
        final centrosCompletos = <CentroTrabalho>[];
        for (var centro in centros) {
          var centroAtualizado = centro;
          
          if (centro.regionalId.isNotEmpty) {
            final regional = await _regionalService.getRegionalById(centro.regionalId);
            if (regional != null) {
              centroAtualizado = centroAtualizado.copyWith(regional: regional.regional);
            }
          }
          
          if (centro.divisaoId.isNotEmpty) {
            final divisao = await _divisaoService.getDivisaoById(centro.divisaoId);
            if (divisao != null) {
              centroAtualizado = centroAtualizado.copyWith(divisao: divisao.divisao);
            }
          }
          
          if (centro.segmentoId.isNotEmpty) {
            final segmento = await _segmentoService.getSegmentoById(centro.segmentoId);
            if (segmento != null) {
              centroAtualizado = centroAtualizado.copyWith(segmento: segmento.segmento);
            }
          }
          
          centrosCompletos.add(centroAtualizado);
        }

        return centrosCompletos;
      } catch (e2) {
        print('Erro ao buscar centros de trabalho (fallback): $e2');
        return [];
      }
    }
  }

  // Buscar centro de trabalho por ID
  Future<CentroTrabalho?> getCentroTrabalhoById(String id) async {
    try {
      final response = await _supabase
          .from('centros_trabalho')
          .select('*, regionais!left(regional), divisoes!left(divisao), segmentos!left(segmento)')
          .eq('id', id)
          .single()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Timeout ao buscar centro de trabalho');
            },
          );

      return _centroTrabalhoFromMap(response);
    } catch (e) {
      print('Erro ao buscar centro de trabalho por ID: $e');
      return null;
    }
  }

  // Buscar centros de trabalho por filtros
  Future<List<CentroTrabalho>> searchCentrosTrabalho(String query) async {
    try {
      final response = await _supabase
          .from('centros_trabalho')
          .select('*, regionais!left(regional), divisoes!left(divisao), segmentos!left(segmento)')
          .or('centro_trabalho.ilike.%$query%,descricao.ilike.%$query%')
          .order('centro_trabalho', ascending: true)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => <Map<String, dynamic>>[],
          );

      if (response.isEmpty) return [];

      final centrosList = response as List;
      return centrosList
          .map((map) => _centroTrabalhoFromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Erro ao buscar centros de trabalho: $e');
      return [];
    }
  }

  // Criar centro de trabalho
  Future<CentroTrabalho> createCentroTrabalho(CentroTrabalho centroTrabalho) async {
    try {
      final map = _centroTrabalhoToMap(centroTrabalho);
      final response = await _supabase
          .from('centros_trabalho')
          .insert(map)
          .select('*, regionais!left(regional), divisoes!left(divisao), segmentos!left(segmento)')
          .single();

      return _centroTrabalhoFromMap(response);
    } catch (e) {
      print('Erro ao criar centro de trabalho: $e');
      rethrow;
    }
  }

  // Atualizar centro de trabalho
  Future<CentroTrabalho> updateCentroTrabalho(CentroTrabalho centroTrabalho) async {
    try {
      final map = _centroTrabalhoToMap(centroTrabalho);
      map.remove('id'); // Não atualizar o ID
      map['updated_at'] = DateTime.now().toIso8601String();

      final response = await _supabase
          .from('centros_trabalho')
          .update(map)
          .eq('id', centroTrabalho.id)
          .select('*, regionais!left(regional), divisoes!left(divisao), segmentos!left(segmento)')
          .single();

      return _centroTrabalhoFromMap(response);
    } catch (e) {
      print('Erro ao atualizar centro de trabalho: $e');
      rethrow;
    }
  }

  // Deletar centro de trabalho
  Future<bool> deleteCentroTrabalho(String id) async {
    try {
      await _supabase
          .from('centros_trabalho')
          .delete()
          .eq('id', id);
      return true;
    } catch (e) {
      print('Erro ao deletar centro de trabalho: $e');
      return false;
    }
  }

  // Buscar centros de trabalho por regional
  Future<List<CentroTrabalho>> getCentrosTrabalhoPorRegional(String regionalId) async {
    try {
      final response = await _supabase
          .from('centros_trabalho')
          .select('*, regionais!left(regional), divisoes!left(divisao), segmentos!left(segmento)')
          .eq('regional_id', regionalId)
          .order('centro_trabalho', ascending: true);

      if (response.isEmpty) return [];

      final centrosList = response as List;
      return centrosList
          .map((map) => _centroTrabalhoFromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Erro ao buscar centros de trabalho por regional: $e');
      return [];
    }
  }

  // Buscar centros de trabalho por divisão
  Future<List<CentroTrabalho>> getCentrosTrabalhoPorDivisao(String divisaoId) async {
    try {
      final response = await _supabase
          .from('centros_trabalho')
          .select('*, regionais!left(regional), divisoes!left(divisao), segmentos!left(segmento)')
          .eq('divisao_id', divisaoId)
          .order('centro_trabalho', ascending: true);

      if (response.isEmpty) return [];

      final centrosList = response as List;
      return centrosList
          .map((map) => _centroTrabalhoFromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Erro ao buscar centros de trabalho por divisão: $e');
      return [];
    }
  }

  // Buscar centros de trabalho por segmento
  Future<List<CentroTrabalho>> getCentrosTrabalhoPorSegmento(String segmentoId) async {
    try {
      final response = await _supabase
          .from('centros_trabalho')
          .select('*, regionais!left(regional), divisoes!left(divisao), segmentos!left(segmento)')
          .eq('segmento_id', segmentoId)
          .order('centro_trabalho', ascending: true);

      if (response.isEmpty) return [];

      final centrosList = response as List;
      return centrosList
          .map((map) => _centroTrabalhoFromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Erro ao buscar centros de trabalho por segmento: $e');
      return [];
    }
  }
}
