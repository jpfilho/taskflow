import '../models/segmento.dart';
import '../config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SegmentoService {
  static final SegmentoService _instance = SegmentoService._internal();
  factory SegmentoService() => _instance;
  SegmentoService._internal();

  final SupabaseClient _supabase = SupabaseConfig.client;

  // Converter Map do Supabase para Segmento
  Segmento _segmentoFromMap(Map<String, dynamic> map) {
    return Segmento(
      id: map['id'] as String,
      segmento: map['segmento'] as String,
      descricao: map['descricao'] as String?,
      cor: map['cor'] as String?,
      corTexto: map['cor_texto'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  // Converter Segmento para Map (para Supabase)
  Map<String, dynamic> _segmentoToMap(Segmento segmento) {
    return {
      'segmento': segmento.segmento,
      'descricao': segmento.descricao,
      'cor': segmento.cor,
      'cor_texto': segmento.corTexto,
    };
  }

  // Buscar todos os segmentos
  Future<List<Segmento>> getAllSegmentos() async {
    try {
      print('🔍 DEBUG SegmentoService: Iniciando busca de segmentos...');
      final response = await _supabase
          .from('segmentos')
          .select()
          .order('segmento', ascending: true)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              print('⚠️ Timeout ao buscar segmentos');
              throw Exception('Timeout ao buscar segmentos após 30 segundos');
            },
          );

      print('✅ DEBUG SegmentoService: Resposta recebida: ${response.length} registros');

      if (response.isEmpty) {
        print('⚠️ DEBUG SegmentoService: Nenhum segmento encontrado');
        return [];
      }

      final segmentosList = response as List;
      final segmentos = segmentosList
          .map((map) {
            try {
              return _segmentoFromMap(map as Map<String, dynamic>);
            } catch (e) {
              print('❌ Erro ao converter segmento: $e');
              print('   Dados: $map');
              return null;
            }
          })
          .whereType<Segmento>()
          .toList();
      
      print('✅ DEBUG SegmentoService: ${segmentos.length} segmentos convertidos com sucesso');
      return segmentos;
    } catch (e, stackTrace) {
      print('❌ Erro ao buscar segmentos: $e');
      print('❌ Stack trace: $stackTrace');
      return [];
    }
  }

  // Buscar segmento por ID
  Future<Segmento?> getSegmentoById(String id) async {
    try {
      final response = await _supabase
        .from('segmentos')
        .select()
        .eq('id', id)
        .single()
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            print('⚠️ Timeout ao buscar segmento por ID');
            return <String, dynamic>{};
          },
        );

      if (response.isEmpty) return null;

      return _segmentoFromMap(response);
    } catch (e) {
      print('Erro ao buscar segmento por ID: $e');
      return null;
    }
  }

  // Buscar segmentos por divisão (via tabela divisoes_segmentos)
  Future<List<Segmento>> getSegmentosPorDivisao(String divisaoId) async {
    try {
      print('🔍 DEBUG SegmentoService: Buscando segmentos para divisão $divisaoId');
      
      final response = await _supabase
        .from('divisoes_segmentos')
        .select('''
          segmentos!inner(
            id,
            segmento,
            descricao,
            cor,
            cor_texto,
            created_at,
            updated_at
          )
        ''')
        .eq('divisao_id', divisaoId)
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            print('⚠️ Timeout ao buscar segmentos por divisão');
            return <Map<String, dynamic>>[];
          },
        );

      print('✅ DEBUG SegmentoService: Resposta recebida: ${response.length} registros');

      if (response.isEmpty) {
        print('⚠️ DEBUG SegmentoService: Nenhum segmento encontrado para esta divisão');
        return [];
      }

      final segmentosList = <Segmento>[];
      for (var item in response) {
        if (item['segmentos'] != null) {
          try {
            final segmentoMap = item['segmentos'] as Map<String, dynamic>;
            segmentosList.add(_segmentoFromMap(segmentoMap));
          } catch (e) {
            print('❌ Erro ao converter segmento: $e');
            print('   Dados: ${item['segmentos']}');
          }
        }
      }
      
      // Ordenar por nome
      segmentosList.sort((a, b) => a.segmento.compareTo(b.segmento));
      
      print('✅ DEBUG SegmentoService: ${segmentosList.length} segmentos convertidos com sucesso');
      return segmentosList;
    } catch (e, stackTrace) {
      print('❌ Erro ao buscar segmentos por divisão: $e');
      print('❌ Stack trace: $stackTrace');
      return [];
    }
  }

  // Criar segmento
  Future<Segmento?> createSegmento(Segmento segmento) async {
    try {
      final segmentoMap = _segmentoToMap(segmento);
      segmentoMap.remove('id'); // Remover ID para gerar UUID no Supabase

      final response = await _supabase
          .from('segmentos')
          .insert(segmentoMap)
          .select()
          .single();

      return _segmentoFromMap(response);
    } catch (e) {
      print('Erro ao criar segmento: $e');
      return null;
    }
  }

  // Atualizar segmento
  Future<Segmento?> updateSegmento(String id, Segmento segmento) async {
    try {
      final segmentoMap = _segmentoToMap(segmento);

      final response = await _supabase
          .from('segmentos')
          .update(segmentoMap)
          .eq('id', id)
          .select()
          .single();

      return _segmentoFromMap(response);
    } catch (e) {
      print('Erro ao atualizar segmento: $e');
      return null;
    }
  }

  // Deletar segmento
  Future<bool> deleteSegmento(String id) async {
    try {
      await _supabase.from('segmentos').delete().eq('id', id);
      return true;
    } catch (e) {
      print('Erro ao deletar segmento: $e');
      return false;
    }
  }

  // Buscar segmentos por filtros
  Future<List<Segmento>> filterSegmentos({
    String? segmento,
  }) async {
    try {
      var query = _supabase.from('segmentos').select();

      if (segmento != null && segmento.isNotEmpty) {
        query = query.ilike('segmento', '%$segmento%');
      }

      final response = await query
          .order('segmento', ascending: true)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              print('⚠️ Timeout ao filtrar segmentos');
              return <Map<String, dynamic>>[];
            },
          );

      if (response.isEmpty) return [];

      final segmentosList = response as List;
      return segmentosList
          .map((map) => _segmentoFromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Erro ao filtrar segmentos: $e');
      return [];
    }
  }

  // Buscar segmentos por texto (busca em todos os campos)
  Future<List<Segmento>> searchSegmentos(String query) async {
    if (query.isEmpty) {
      return getAllSegmentos();
    }

    try {
      final response = await _supabase
          .from('segmentos')
          .select()
          .or(
            'segmento.ilike.%$query%,descricao.ilike.%$query%',
          )
          .order('segmento', ascending: true)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              print('⚠️ Timeout ao buscar segmentos');
              return <Map<String, dynamic>>[];
            },
          );

      if (response.isEmpty) return [];

      final segmentosList = response as List;
      return segmentosList
          .map((map) => _segmentoFromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Erro ao buscar segmentos: $e');
      return [];
    }
  }
}


