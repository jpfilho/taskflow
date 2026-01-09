import '../models/divisao.dart';
import '../config/supabase_config.dart';
import '../services/regional_service.dart';
import '../services/segmento_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DivisaoService {
  static final DivisaoService _instance = DivisaoService._internal();
  factory DivisaoService() => _instance;
  DivisaoService._internal();

  final SupabaseClient _supabase = SupabaseConfig.client;
  final RegionalService _regionalService = RegionalService();
  final SegmentoService _segmentoService = SegmentoService();

  // Converter Map do Supabase para Divisao
  Divisao _divisaoFromMap(Map<String, dynamic> map) {
    return Divisao.fromMap(map);
  }

  // Converter Divisao para Map (para Supabase)
  Map<String, dynamic> _divisaoToMap(Divisao divisao) {
    return {
      'divisao': divisao.divisao,
      'regional_id': divisao.regionalId,
    };
  }

  // Buscar todas as divisões
  Future<List<Divisao>> getAllDivisoes() async {
    try {
      // Buscar divisões com regionais e relacionamentos many-to-many com segmentos
      final response = await _supabase
          .from('divisoes')
          .select('''
            *,
            regionais!inner(id, regional, divisao, empresa),
            divisoes_segmentos!left(
              segmentos!inner(id, segmento)
            )
          ''')
          .order('divisao', ascending: true)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              print('⚠️ Timeout ao buscar divisões');
              return <Map<String, dynamic>>[];
            },
          );

      if (response.isEmpty) return [];

      final divisoesList = response as List;
      return divisoesList
          .map((map) => _divisaoFromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Erro ao buscar divisões: $e');
      // Tentar buscar sem join se falhar
      try {
        final response = await _supabase
            .from('divisoes')
            .select()
            .order('divisao', ascending: true)
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () => <Map<String, dynamic>>[],
            );

        if (response.isEmpty) return [];

        final divisoesList = response as List;
        final divisoes = divisoesList
            .map((map) => _divisaoFromMap(map as Map<String, dynamic>))
            .toList();

        // Carregar nomes das regionais e segmentos
        final divisoesCompleta = <Divisao>[];
        for (var divisao in divisoes) {
          var divisaoAtualizada = divisao;
          
          // Carregar regional
          final regional = await _regionalService.getRegionalById(divisao.regionalId);
          if (regional != null) {
            divisaoAtualizada = divisaoAtualizada.copyWith(regional: regional.regional);
          }
          
          // Carregar segmentos (múltiplos)
          if (divisao.segmentoIds.isNotEmpty) {
            final segmentosNomes = <String>[];
            for (var segmentoId in divisao.segmentoIds) {
              final segmento = await _segmentoService.getSegmentoById(segmentoId);
              if (segmento != null) {
                segmentosNomes.add(segmento.segmento);
              }
            }
            divisaoAtualizada = divisaoAtualizada.copyWith(segmentos: segmentosNomes);
          }
          
          divisoesCompleta.add(divisaoAtualizada);
        }

        return divisoesCompleta;
      } catch (e2) {
        print('Erro ao buscar divisões (fallback): $e2');
        return [];
      }
    }
  }

  // Buscar divisão por ID
  Future<Divisao?> getDivisaoById(String id) async {
    try {
      final response = await _supabase
          .from('divisoes')
          .select('''
            *,
            regionais!inner(id, regional, divisao, empresa),
            divisoes_segmentos!left(
              segmentos!inner(id, segmento)
            )
          ''')
          .eq('id', id)
          .single()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              print('⚠️ Timeout ao buscar divisão por ID');
              return <String, dynamic>{};
            },
          );

      if (response.isEmpty) {
        print('⚠️ Resposta vazia ao buscar divisão por ID');
        return null;
      }

      print('📥 Dados brutos da divisão: $response');
      final divisao = _divisaoFromMap(response);
      print('📋 Divisão carregada: ${divisao.divisao}');
      print('📋 Segmentos IDs: ${divisao.segmentoIds}');
      print('📋 Segmentos nomes: ${divisao.segmentos}');
      return divisao;
    } catch (e) {
      print('❌ Erro ao buscar divisão por ID: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  // Verificar se já existe uma divisão com o mesmo nome na mesma regional
  Future<bool> existeDivisao(String nome, String regionalId) async {
    try {
      final response = await _supabase
          .from('divisoes')
          .select('id')
          .eq('divisao', nome)
          .eq('regional_id', regionalId)
          .maybeSingle();
      
      return response != null;
    } catch (e) {
      print('Erro ao verificar se divisão existe: $e');
      return false;
    }
  }

  // Criar divisão
  Future<Divisao?> createDivisao(Divisao divisao) async {
    try {
      print('🔍 DEBUG: Criando divisão');
      print('   Nome: ${divisao.divisao}');
      print('   Regional ID: ${divisao.regionalId}');
      print('   Segmentos IDs: ${divisao.segmentoIds}');
      
      // Verificar se já existe uma divisão com o mesmo nome na mesma regional
      final existe = await existeDivisao(divisao.divisao, divisao.regionalId);
      if (existe) {
        throw Exception('Já existe uma divisão com o nome "${divisao.divisao}" nesta regional. Os nomes de divisões devem ser únicos dentro de cada regional.');
      }

      final divisaoMap = _divisaoToMap(divisao);
      divisaoMap.remove('id'); // Remover ID para gerar UUID no Supabase
      print('🔍 DEBUG: Map para inserção: $divisaoMap');

      // Criar a divisão primeiro
      print('🔍 DEBUG: Inserindo divisão na tabela divisoes...');
      print('🔍 DEBUG: Dados a serem inseridos: $divisaoMap');
      
      String divisaoId;
      try {
        final response = await _supabase
            .from('divisoes')
            .insert(divisaoMap)
            .select('id')
            .single();

        divisaoId = response['id'] as String;
        print('✅ DEBUG: Divisão criada com ID: $divisaoId');
      } catch (insertError) {
        print('❌ DEBUG: Erro ao inserir divisão: $insertError');
        print('❌ DEBUG: Tipo do erro: ${insertError.runtimeType}');
        print('❌ DEBUG: Stack trace: ${StackTrace.current}');
        
        // Verificar se é erro de NOT NULL
        final errorString = insertError.toString();
        if (errorString.contains('null value') || 
            errorString.contains('NOT NULL') || 
            errorString.contains('violates not-null constraint')) {
          throw Exception('ERRO: A tabela divisoes ainda tem a coluna segmento_id como obrigatória (NOT NULL).\n\nExecute o script SQL "corrigir_estrutura_divisoes_completo.sql" no Supabase Dashboard para corrigir isso.');
        }
        
        // Verificar se é erro de constraint UNIQUE
        if (errorString.contains('unique') || errorString.contains('duplicate')) {
          throw Exception('Já existe uma divisão com o nome "${divisao.divisao}" nesta regional.');
        }
        
        // Re-lançar o erro original com mais contexto
        throw Exception('Erro ao criar divisão: ${errorString.replaceFirst('PostgrestException: ', '')}');
      }

      // Salvar relacionamentos com segmentos na tabela divisoes_segmentos
      if (divisao.segmentoIds.isNotEmpty) {
        print('🔍 DEBUG: Inserindo ${divisao.segmentoIds.length} relacionamentos com segmentos...');
        final relacionamentos = divisao.segmentoIds.map((segmentoId) => {
          'divisao_id': divisaoId,
          'segmento_id': segmentoId,
        }).toList();
        print('🔍 DEBUG: Relacionamentos: $relacionamentos');

        try {
          await _supabase
              .from('divisoes_segmentos')
              .insert(relacionamentos);
          print('✅ DEBUG: Relacionamentos inseridos com sucesso');
        } catch (segmentosError) {
          print('❌ DEBUG: Erro ao inserir relacionamentos com segmentos: $segmentosError');
          // Não re-lançar o erro aqui, pois a divisão já foi criada
          // Apenas logar o erro
        }
      } else {
        print('⚠️ DEBUG: Nenhum segmento selecionado');
      }

      // Buscar a divisão criada com todos os relacionamentos
      print('🔍 DEBUG: Buscando divisão criada...');
      final divisaoCriada = await getDivisaoById(divisaoId);
      print('✅ DEBUG: Divisão criada e carregada: ${divisaoCriada?.divisao}');
      return divisaoCriada;
    } catch (e, stackTrace) {
      print('❌ Erro ao criar divisão: $e');
      print('❌ Stack trace: $stackTrace');
      rethrow; // Re-lançar o erro para que o UI possa tratá-lo
    }
  }

  // Atualizar divisão
  Future<Divisao?> updateDivisao(String id, Divisao divisao) async {
    try {
      print('🔍 DEBUG: Atualizando divisão');
      print('   ID: $id');
      print('   Nome: ${divisao.divisao}');
      print('   Regional ID: ${divisao.regionalId}');
      print('   Segmentos IDs: ${divisao.segmentoIds}');
      
      // Verificar se já existe outra divisão com o mesmo nome na mesma regional (excluindo a atual)
      final responseExistente = await _supabase
          .from('divisoes')
          .select('id')
          .eq('divisao', divisao.divisao)
          .eq('regional_id', divisao.regionalId)
          .neq('id', id)
          .maybeSingle();
      
      if (responseExistente != null) {
        throw Exception('Já existe outra divisão com o nome "${divisao.divisao}" nesta regional. Os nomes de divisões devem ser únicos dentro de cada regional.');
      }

      final divisaoMap = _divisaoToMap(divisao);
      print('🔍 DEBUG: Map para atualização: $divisaoMap');

      // Atualizar dados da divisão
      print('🔍 DEBUG: Atualizando divisão na tabela divisoes...');
      await _supabase
          .from('divisoes')
          .update(divisaoMap)
          .eq('id', id);
      print('✅ DEBUG: Divisão atualizada');

      // Remover relacionamentos antigos
      print('🔍 DEBUG: Removendo relacionamentos antigos...');
      await _supabase
          .from('divisoes_segmentos')
          .delete()
          .eq('divisao_id', id);
      print('✅ DEBUG: Relacionamentos antigos removidos');

      // Criar novos relacionamentos com segmentos
      if (divisao.segmentoIds.isNotEmpty) {
        print('🔍 DEBUG: Inserindo ${divisao.segmentoIds.length} novos relacionamentos com segmentos...');
        final relacionamentos = divisao.segmentoIds.map((segmentoId) => {
          'divisao_id': id,
          'segmento_id': segmentoId,
        }).toList();
        print('🔍 DEBUG: Relacionamentos: $relacionamentos');

        await _supabase
            .from('divisoes_segmentos')
            .insert(relacionamentos);
        print('✅ DEBUG: Novos relacionamentos inseridos');
      } else {
        print('⚠️ DEBUG: Nenhum segmento selecionado');
      }

      // Buscar a divisão atualizada com todos os relacionamentos
      print('🔍 DEBUG: Buscando divisão atualizada...');
      final divisaoAtualizada = await getDivisaoById(id);
      print('✅ DEBUG: Divisão atualizada e carregada: ${divisaoAtualizada?.divisao}');
      return divisaoAtualizada;
    } catch (e, stackTrace) {
      print('❌ Erro ao atualizar divisão: $e');
      print('❌ Stack trace: $stackTrace');
      rethrow; // Re-lançar o erro para que o UI possa tratá-lo
    }
  }

  // Deletar divisão
  Future<bool> deleteDivisao(String id) async {
    try {
      await _supabase.from('divisoes').delete().eq('id', id);
      return true;
    } catch (e) {
      print('Erro ao deletar divisão: $e');
      return false;
    }
  }

  // Buscar divisões por filtros
  Future<List<Divisao>> filterDivisoes({
    String? divisao,
    String? regionalId,
    String? segmento,
  }) async {
    try {
      var query = _supabase.from('divisoes').select('''
        *,
        regionais!inner(regional, divisao, empresa),
        divisoes_segmentos(
          segmentos(segmento)
        )
      ''');

      if (divisao != null && divisao.isNotEmpty) {
        query = query.ilike('divisao', '%$divisao%');
      }
      if (regionalId != null && regionalId.isNotEmpty) {
        query = query.eq('regional_id', regionalId);
      }
      if (segmento != null && segmento.isNotEmpty) {
        query = query.ilike('segmento', '%$segmento%');
      }

      final response = await query
          .order('divisao', ascending: true)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              print('⚠️ Timeout ao filtrar divisões');
              return <Map<String, dynamic>>[];
            },
          );

      if (response.isEmpty) return [];

      final divisoesList = response as List;
      return divisoesList
          .map((map) => _divisaoFromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Erro ao filtrar divisões: $e');
      return [];
    }
  }

  // Buscar divisões por texto (busca em todos os campos)
  Future<List<Divisao>> searchDivisoes(String query) async {
    if (query.isEmpty) {
      return getAllDivisoes();
    }

    try {
      final response = await _supabase
          .from('divisoes')
          .select('''
            *,
            regionais!inner(regional, divisao, empresa),
            divisoes_segmentos(
              segmentos(segmento)
            )
          ''')
          .or(
            'divisao.ilike.%$query%',
          )
          .order('divisao', ascending: true)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              print('⚠️ Timeout ao buscar divisões');
              return <Map<String, dynamic>>[];
            },
          );

      if (response.isEmpty) return [];

      final divisoesList = response as List;
      return divisoesList
          .map((map) => _divisaoFromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Erro ao buscar divisões: $e');
      return [];
    }
  }
}

