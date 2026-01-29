import '../models/local.dart';
import '../config/supabase_config.dart';
import '../services/regional_service.dart';
import '../services/divisao_service.dart';
import '../services/segmento_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LocalService {
  static final LocalService _instance = LocalService._internal();
  factory LocalService() => _instance;
  LocalService._internal();

  final SupabaseClient _supabase = SupabaseConfig.client;
  final RegionalService _regionalService = RegionalService();
  final DivisaoService _divisaoService = DivisaoService();
  final SegmentoService _segmentoService = SegmentoService();

  // Converter Map do Supabase para Local
  Local _localFromMap(Map<String, dynamic> map) {
    return Local(
      id: map['id'] as String,
      local: map['local'] as String,
      descricao: map['descricao'] as String?,
      localInstalacaoSap: map['local_instalacao_sap'] as String?,
      paraTodaRegional: map['para_toda_regional'] as bool? ?? false,
      paraTodaDivisao: map['para_toda_divisao'] as bool? ?? false,
      regionalId: map['regional_id'] as String?,
      divisaoId: map['divisao_id'] as String?,
      segmentoId: map['segmento_id'] as String?,
      regional: map['regionais'] != null 
          ? (map['regionais'] as Map<String, dynamic>)['regional'] as String? ?? ''
          : (map['regional'] as String? ?? ''),
      divisao: map['divisoes'] != null 
          ? (map['divisoes'] as Map<String, dynamic>)['divisao'] as String? ?? ''
          : (map['divisao'] as String? ?? ''),
      segmento: map['segmentos'] != null 
          ? (map['segmentos'] as Map<String, dynamic>)['segmento'] as String? ?? ''
          : (map['segmento'] as String? ?? ''),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  // Converter Local para Map (para Supabase)
  Map<String, dynamic> _localToMap(Local local) {
    return {
      'local': local.local,
      'descricao': local.descricao,
      'local_instalacao_sap': local.localInstalacaoSap,
      'para_toda_regional': local.paraTodaRegional,
      'para_toda_divisao': local.paraTodaDivisao,
      // Permitir especificar regional/divisão mesmo quando os checkboxes estão marcados
      'regional_id': local.regionalId,
      'divisao_id': local.divisaoId,
      'segmento_id': local.segmentoId,
    };
  }

  // Buscar todos os locais
  Future<List<Local>> getAllLocais() async {
    try {
      final response = await _supabase
          .from('locais')
          .select('*, regionais!left(regional), divisoes!left(divisao), segmentos!left(segmento)')
          .order('local', ascending: true)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              return <Map<String, dynamic>>[];
            },
          );

      if (response.isEmpty) return [];

      final locaisList = response as List;
      return locaisList
          .map((map) => _localFromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Erro ao buscar locais: $e');
      // Fallback: buscar sem join
      try {
        final response = await _supabase
            .from('locais')
            .select()
            .order('local', ascending: true)
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () => <Map<String, dynamic>>[],
            );

        if (response.isEmpty) return [];

        final locaisList = response as List;
        final locais = locaisList
            .map((map) => _localFromMap(map as Map<String, dynamic>))
            .toList();

        // Carregar nomes das associações
        final locaisCompletos = <Local>[];
        for (var local in locais) {
          var localAtualizado = local;
          
          if (local.regionalId != null && local.regionalId!.isNotEmpty) {
            final regional = await _regionalService.getRegionalById(local.regionalId!);
            if (regional != null) {
              localAtualizado = localAtualizado.copyWith(regional: regional.regional);
            }
          }
          
          if (local.divisaoId != null && local.divisaoId!.isNotEmpty) {
            final divisao = await _divisaoService.getDivisaoById(local.divisaoId!);
            if (divisao != null) {
              localAtualizado = localAtualizado.copyWith(divisao: divisao.divisao);
            }
          }
          
          if (local.segmentoId != null && local.segmentoId!.isNotEmpty) {
            final segmento = await _segmentoService.getSegmentoById(local.segmentoId!);
            if (segmento != null) {
              localAtualizado = localAtualizado.copyWith(segmento: segmento.segmento);
            }
          }
          
          locaisCompletos.add(localAtualizado);
        }

        return locaisCompletos;
      } catch (e2) {
        print('Erro ao buscar locais (fallback): $e2');
        return [];
      }
    }
  }

  // Buscar local por ID
  Future<Local?> getLocalById(String id) async {
    try {
      final response = await _supabase
          .from('locais')
          .select('*, regionais!left(regional), divisoes!left(divisao), segmentos!left(segmento)')
          .eq('id', id)
          .single()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              return <String, dynamic>{};
            },
          );

      if (response.isEmpty) return null;

      return _localFromMap(response);
    } catch (e) {
      print('Erro ao buscar local por ID: $e');
      return null;
    }
  }

  // Criar local
  Future<Local?> createLocal(Local local) async {
    try {
      final localMap = _localToMap(local);
      localMap.remove('id'); // Remover ID para gerar UUID no Supabase

      final response = await _supabase
          .from('locais')
          .insert(localMap)
          .select('*, regionais!left(regional), divisoes!left(divisao), segmentos!left(segmento)')
          .single();

      return _localFromMap(response);
    } catch (e) {
      print('Erro ao criar local: $e');
      return null;
    }
  }

  // Atualizar local
  Future<Local?> updateLocal(String id, Local local) async {
    try {
      final localMap = _localToMap(local);

      final response = await _supabase
          .from('locais')
          .update(localMap)
          .eq('id', id)
          .select('*, regionais!left(regional), divisoes!left(divisao), segmentos!left(segmento)')
          .single();

      return _localFromMap(response);
    } catch (e) {
      print('Erro ao atualizar local: $e');
      return null;
    }
  }

  // Deletar local
  Future<bool> deleteLocal(String id) async {
    try {
      await _supabase.from('locais').delete().eq('id', id);
      return true;
    } catch (e) {
      print('Erro ao deletar local: $e');
      return false;
    }
  }

  // Buscar locais por filtros
  Future<List<Local>> filterLocais({
    String? local,
    String? regionalId,
    String? divisaoId,
    String? segmentoId,
    bool? paraTodaRegional,
    bool? paraTodaDivisao,
  }) async {
    try {
      var query = _supabase.from('locais').select('*, regionais!left(regional), divisoes!left(divisao), segmentos!left(segmento)');

      if (local != null && local.isNotEmpty) {
        query = query.ilike('local', '%$local%');
      }
      if (regionalId != null && regionalId.isNotEmpty) {
        query = query.eq('regional_id', regionalId);
      }
      if (divisaoId != null && divisaoId.isNotEmpty) {
        query = query.eq('divisao_id', divisaoId);
      }
      if (segmentoId != null && segmentoId.isNotEmpty) {
        query = query.eq('segmento_id', segmentoId);
      }
      if (paraTodaRegional != null) {
        query = query.eq('para_toda_regional', paraTodaRegional);
      }
      if (paraTodaDivisao != null) {
        query = query.eq('para_toda_divisao', paraTodaDivisao);
      }

      final response = await query
          .order('local', ascending: true)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              return <Map<String, dynamic>>[];
            },
          );

      if (response.isEmpty) return [];

      final locaisList = response as List;
      return locaisList
          .map((map) => _localFromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Erro ao filtrar locais: $e');
      return [];
    }
  }

  // Buscar locais filtrados por regional, divisão e segmento
  // Lógica especial: locais podem ser "para toda a regional" ou "para toda a divisão"
  Future<List<Local>> getLocaisFiltrados({
    String? regionalId,
    String? divisaoId,
    String? segmentoId,
  }) async {
    try {
      print('🔍 DEBUG LocalService.getLocaisFiltrados:');
      print('   regionalId: $regionalId');
      print('   divisaoId: $divisaoId');
      print('   segmentoId: $segmentoId');
      
      // Buscar TODOS os locais primeiro (precisamos verificar os flags paraTodaRegional/paraTodaDivisao)
      final todosLocais = await getAllLocais();
      print('   Total de locais no banco: ${todosLocais.length}');
      
      // Filtrar locais baseado nos critérios
      final locaisFiltrados = todosLocais.where((local) {
        // 1. Se o local é "para toda a regional" e temos regionalId, incluir se a regional corresponder
        if (local.paraTodaRegional && local.regionalId != null) {
          if (regionalId != null && regionalId.isNotEmpty) {
            if (local.regionalId == regionalId) {
              print('     ✅ Local "${local.local}" incluído: para toda a regional ${local.regionalId}');
              return true;
            }
          }
        }
        
        // 2. Se o local é "para toda a divisão" e temos divisaoId, incluir se a divisão corresponder
        if (local.paraTodaDivisao && local.divisaoId != null) {
          if (divisaoId != null && divisaoId.isNotEmpty) {
            if (local.divisaoId == divisaoId) {
              print('     ✅ Local "${local.local}" incluído: para toda a divisão ${local.divisaoId}');
              return true;
            }
          }
        }
        
        // 3. Se temos segmentoId, incluir locais desse segmento específico
        if (segmentoId != null && segmentoId.isNotEmpty) {
          if (local.segmentoId != null && local.segmentoId == segmentoId) {
            print('     ✅ Local "${local.local}" incluído: segmento específico ${local.segmentoId}');
            return true;
          }
        }
        
        // 4. Se temos divisaoId (sem segmento), incluir locais dessa divisão específica
        if (divisaoId != null && divisaoId.isNotEmpty && (segmentoId == null || segmentoId.isEmpty)) {
          if (local.divisaoId != null && local.divisaoId == divisaoId) {
            print('     ✅ Local "${local.local}" incluído: divisão específica ${local.divisaoId}');
            return true;
          }
        }
        
        // 5. Se temos regionalId (sem divisão/segmento), incluir locais dessa regional específica
        if (regionalId != null && regionalId.isNotEmpty && 
            (divisaoId == null || divisaoId.isEmpty) && 
            (segmentoId == null || segmentoId.isEmpty)) {
          if (local.regionalId != null && local.regionalId == regionalId) {
            print('     ✅ Local "${local.local}" incluído: regional específica ${local.regionalId}');
            return true;
          }
        }
        
        // 6. Se temos regionalId e divisaoId, verificar se a divisão pertence à regional
        if (regionalId != null && regionalId.isNotEmpty && divisaoId != null && divisaoId.isNotEmpty) {
          // Se o local tem divisão que corresponde e a divisão pertence à regional
          if (local.divisaoId != null && local.divisaoId == divisaoId) {
            // Verificar se a divisão pertence à regional (será verificado depois)
            print('     ⚠️ Local "${local.local}" com divisão ${local.divisaoId} - precisa verificar se divisão pertence à regional');
            return true; // Incluir por enquanto, será filtrado depois se necessário
          }
        }
        
        return false;
      }).toList();
      
      // Se temos regionalId, verificar se as divisões dos locais pertencem à regional
      if (regionalId != null && regionalId.isNotEmpty) {
        final divisoesDaRegional = await _supabase
            .from('divisoes')
            .select('id')
            .eq('regional_id', regionalId);
        
        final divisaoIdsDaRegional = (divisoesDaRegional as List)
            .map((d) => d['id'] as String)
            .toList();
        
        print('   Divisões da regional $regionalId: $divisaoIdsDaRegional');
        
        // Filtrar novamente para garantir que locais com divisão específica pertencem à regional
        final locaisFinais = locaisFiltrados.where((local) {
          // Se é para toda a regional e corresponde, incluir
          if (local.paraTodaRegional && local.regionalId == regionalId) {
            return true;
          }
          
          // Se é para toda a divisão e a divisão pertence à regional, incluir
          if (local.paraTodaDivisao && local.divisaoId != null) {
            if (divisaoIdsDaRegional.contains(local.divisaoId)) {
              return true;
            }
          }
          
          // Se tem divisão específica, verificar se pertence à regional
          if (local.divisaoId != null) {
            if (divisaoIdsDaRegional.contains(local.divisaoId)) {
              return true;
            }
          }
          
          // Se tem regional específica e corresponde, incluir
          if (local.regionalId == regionalId) {
            return true;
          }
          
          return false;
        }).toList();
        
        print('✅ DEBUG LocalService.getLocaisFiltrados: Retornando ${locaisFinais.length} locais após filtro de regional');
        if (locaisFinais.isNotEmpty) {
          print('   Primeiros 3 locais:');
          for (var i = 0; i < locaisFinais.length && i < 3; i++) {
            final local = locaisFinais[i];
            print('     - ${local.local} (paraTodaRegional: ${local.paraTodaRegional}, paraTodaDivisao: ${local.paraTodaDivisao}, regional: ${local.regionalId}, divisao: ${local.divisaoId}, segmento: ${local.segmentoId})');
          }
        }
        
        return locaisFinais;
      }
      
      print('✅ DEBUG LocalService.getLocaisFiltrados: Retornando ${locaisFiltrados.length} locais');
      if (locaisFiltrados.isNotEmpty) {
        print('   Primeiros 3 locais:');
        for (var i = 0; i < locaisFiltrados.length && i < 3; i++) {
          final local = locaisFiltrados[i];
          print('     - ${local.local} (paraTodaRegional: ${local.paraTodaRegional}, paraTodaDivisao: ${local.paraTodaDivisao}, regional: ${local.regionalId}, divisao: ${local.divisaoId}, segmento: ${local.segmentoId})');
        }
      }
      
      return locaisFiltrados;
    } catch (e, stackTrace) {
      print('❌ Erro ao buscar locais filtrados: $e');
      print('   Stack trace: $stackTrace');
      return [];
    }
  }

  // Buscar locais por texto (busca em todos os campos)
  Future<List<Local>> searchLocais(String query) async {
    if (query.isEmpty) {
      return getAllLocais();
    }

    try {
      final response = await _supabase
          .from('locais')
          .select('*, regionais!left(regional), divisoes!left(divisao), segmentos!left(segmento)')
          .or(
            'local.ilike.%$query%,descricao.ilike.%$query%',
          )
          .order('local', ascending: true)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              return <Map<String, dynamic>>[];
            },
          );

      if (response.isEmpty) return [];

      final locaisList = response as List;
      return locaisList
          .map((map) => _localFromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Erro ao buscar locais: $e');
      return [];
    }
  }
}

