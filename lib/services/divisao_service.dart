import '../models/divisao.dart';
import '../config/supabase_config.dart';
import '../services/regional_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_service.dart';

class DivisaoService {
  static final DivisaoService _instance = DivisaoService._internal();
  factory DivisaoService() => _instance;
  DivisaoService._internal();

  final SupabaseClient _supabase = SupabaseConfig.client;
  final RegionalService _regionalService = RegionalService();
  final ChatService _chatService = ChatService();

  // Converter Map do Supabase para Divisao
  Divisao _divisaoFromMap(Map<String, dynamic> map) {
    return Divisao.fromMap(map);
  }

  // Converter Divisao para Map (para Supabase)
  // Mantém dual-write com regional_id legado para garantir compatibilidade
  Map<String, dynamic> _divisaoToMap(Divisao divisao) {
    return {
      'divisao': divisao.divisao,
      'regional_id': divisao.regionalId,
    };
  }

  // Buscar todas as divisões com suas regionais (N:N) e segmentos (N:N)
  Future<List<Divisao>> getAllDivisoes() async {
    try {
      // 1. Buscar todas as divisões com relacionamentos N:N de segmentos
      final response = await _supabase
          .from('divisoes')
          .select('''
            *,
            divisoes_segmentos!left(
              segmentos!inner(id, segmento)
            )
          ''')
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

      // 2. Enriquecer em lote com divisoes_regionais (N:N)
      return await _enrichDivisoesWithRegionais(divisoes);
    } catch (e) {
      print('Erro ao buscar divisões: $e');
      // Fallback simples sem joins
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

        return await _enrichDivisoesWithRegionais(divisoes);
      } catch (e2) {
        print('Erro ao buscar divisões (fallback total): $e2');
        return [];
      }
    }
  }

  // Enriquecer lista de divisões com vínculos de divisoes_regionais em lote
  Future<List<Divisao>> _enrichDivisoesWithRegionais(List<Divisao> divisoes) async {
    if (divisoes.isEmpty) return divisoes;

    try {
      // Buscar mapa de todas as regionais cadastradas para lookup rápido e seguro
      Map<String, String> regMapById = {};
      try {
        final allRegionais = await _regionalService.getAllRegionais();
        regMapById = {for (var r in allRegionais) r.id: r.regional};
      } catch (_) {}

      // Buscar todos os vínculos de divisoes_regionais
      final relRows = await _supabase
          .from('divisoes_regionais')
          .select('divisao_id, regional_id')
          .timeout(const Duration(seconds: 15), onTimeout: () => <Map<String, dynamic>>[]);

      final Map<String, List<String>> regIdsByDiv = {};
      final Map<String, List<String>> regNomesByDiv = {};

      for (var row in (relRows as List)) {
        final divId = row['divisao_id'] as String?;
        final regId = row['regional_id'] as String?;
        if (divId == null || regId == null) continue;

        final regNome = regMapById[regId] ?? '';

        regIdsByDiv.putIfAbsent(divId, () => []).add(regId);
        if (regNome.isNotEmpty) {
          regNomesByDiv.putIfAbsent(divId, () => []).add(regNome);
        }
      }

      return divisoes.map((d) {
        // Se houver vínculos em divisoes_regionais, usa eles; senão, fallback para regional_id legado
        final rIds = regIdsByDiv[d.id] ?? (d.regionalIds.isNotEmpty ? d.regionalIds : (d.regionalId.isNotEmpty ? [d.regionalId] : []));
        final rNomes = regNomesByDiv[d.id] ?? (d.regionais.isNotEmpty ? d.regionais : (d.regional.isNotEmpty ? [d.regional] : (d.regionalId.isNotEmpty && regMapById.containsKey(d.regionalId) ? [regMapById[d.regionalId]!] : [])));

        return d.copyWith(
          regionalIds: rIds,
          regionais: rNomes,
          regional: rNomes.isNotEmpty ? rNomes.first : d.regional,
        );
      }).toList();
    } catch (e) {
      print('⚠️ Aviso ao enriquecer divisões com divisoes_regionais: $e');
      return divisoes;
    }
  }

  // Buscar divisão por ID
  Future<Divisao?> getDivisaoById(String id) async {
    try {
      final response = await _supabase
          .from('divisoes')
          .select('''
            *,
            divisoes_segmentos!left(
              segmentos!inner(id, segmento)
            )
          ''')
          .eq('id', id)
          .single()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => <String, dynamic>{},
          );

      if (response.isEmpty) return null;

      final div = _divisaoFromMap(response);
      final enriched = await _enrichDivisoesWithRegionais([div]);
      return enriched.isNotEmpty ? enriched.first : div;
    } catch (e) {
      print('❌ Erro ao buscar divisão por ID: $e');
      return null;
    }
  }

  // Verificar se já existe uma divisão com o mesmo nome
  Future<bool> existeDivisao(String nome, [String? regionalId]) async {
    try {
      var query = _supabase.from('divisoes').select('id').eq('divisao', nome);
      if (regionalId != null && regionalId.isNotEmpty) {
        query = query.eq('regional_id', regionalId);
      }
      final response = await query.maybeSingle();
      return response != null;
    } catch (e) {
      print('Erro ao verificar se divisão existe: $e');
      return false;
    }
  }

  // Cadastrar Chat IDs do Telegram para comunidades da divisão (para cada regional e segmento vinculados)
  Future<void> cadastrarTelegramChatIdsParaDivisao(
    String divisaoId,
    String divisaoNome,
    List<String> regionalIds,
    List<String> regionaisNomes,
    List<String> segmentoIds,
    List<String> segmentosNomes,
    Map<String, String>? telegramChatIds,
  ) async {
    try {
      print('🔍 DEBUG: Processando Chat IDs do Telegram para divisão $divisaoNome');
      print('   Total de regionais: ${regionalIds.length}');
      print('   Total de segmentos: ${segmentoIds.length}');

      for (int r = 0; r < regionalIds.length; r++) {
        final regionalId = regionalIds[r];
        final regionalNome = r < regionaisNomes.length ? regionaisNomes[r] : 'Regional';

        for (int s = 0; s < segmentoIds.length; s++) {
          final segmentoId = segmentoIds[s];
          final segmentoNome = s < segmentosNomes.length ? segmentosNomes[s] : 'Segmento';

          try {
            final comunidade = await _chatService.criarOuObterComunidade(
              regionalId,
              regionalNome,
              divisaoId,
              divisaoNome,
              segmentoId,
              segmentoNome,
            );

            final chatId = telegramChatIds?[segmentoId] ?? telegramChatIds?['${regionalId}_$segmentoId'];

            if (chatId == null || chatId.trim().isEmpty) {
              try {
                await _supabase
                    .from('telegram_communities')
                    .delete()
                    .eq('community_id', comunidade.id.toString());
              } catch (_) {}
              continue;
            }

            final chatIdInt = int.tryParse(chatId.trim());
            if (chatIdInt != null) {
              await _supabase
                  .from('telegram_communities')
                  .upsert({
                    'community_id': comunidade.id,
                    'telegram_chat_id': chatIdInt,
                  }, onConflict: 'community_id');
            }
          } catch (eComm) {
            print('⚠️ Erro ao processar comunidade para $regionalNome - $segmentoNome: $eComm');
          }
        }
      }
    } catch (e) {
      print('❌ Erro ao cadastrar Chat IDs do Telegram: $e');
    }
  }

  // Criar divisão
  Future<Divisao?> createDivisao(Divisao divisao, {Map<String, String>? telegramChatIds}) async {
    try {
      print('🔍 DEBUG: Criando divisão');
      print('   Nome: ${divisao.divisao}');
      print('   Regionais IDs: ${divisao.regionalIds}');
      print('   Segmentos IDs: ${divisao.segmentoIds}');

      final divisaoMap = _divisaoToMap(divisao);
      divisaoMap.remove('id');

      // 1. Inserir divisão na tabela divisoes
      final response = await _supabase
          .from('divisoes')
          .insert(divisaoMap)
          .select('id')
          .single();

      final divisaoId = response['id'] as String;
      print('✅ DEBUG: Divisão criada com ID: $divisaoId');

      // 2. Salvar relacionamentos N:N com regionais na tabela divisoes_regionais
      if (divisao.regionalIds.isNotEmpty) {
        final relRegionais = divisao.regionalIds.map((regId) => {
          'divisao_id': divisaoId,
          'regional_id': regId,
        }).toList();

        try {
          await _supabase.from('divisoes_regionais').insert(relRegionais);
          print('✅ DEBUG: Relacionamentos divisoes_regionais inseridos com sucesso');
        } catch (eReg) {
          print('⚠️ Erro ao inserir divisoes_regionais: $eReg');
        }
      }

      // 3. Salvar relacionamentos N:N com segmentos na tabela divisoes_segmentos
      if (divisao.segmentoIds.isNotEmpty) {
        final relSegmentos = divisao.segmentoIds.map((segId) => {
          'divisao_id': divisaoId,
          'segmento_id': segId,
        }).toList();

        try {
          await _supabase.from('divisoes_segmentos').insert(relSegmentos);
          print('✅ DEBUG: Relacionamentos divisoes_segmentos inseridos com sucesso');
        } catch (eSeg) {
          print('⚠️ Erro ao inserir divisoes_segmentos: $eSeg');
        }
      }

      // 4. Buscar a divisão criada com todos os relacionamentos
      final divisaoCriada = await getDivisaoById(divisaoId);

      // 5. Cadastrar Chat IDs do Telegram se fornecidos
      if (telegramChatIds != null && telegramChatIds.isNotEmpty && divisaoCriada != null) {
        await cadastrarTelegramChatIdsParaDivisao(
          divisaoId,
          divisaoCriada.divisao,
          divisaoCriada.regionalIds,
          divisaoCriada.regionais,
          divisaoCriada.segmentoIds,
          divisaoCriada.segmentos,
          telegramChatIds,
        );
      }

      return divisaoCriada ?? divisao.copyWith(id: divisaoId);
    } catch (e, stackTrace) {
      print('❌ Erro ao criar divisão: $e');
      print('❌ Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Atualizar divisão com sincronização Delta para divisoes_regionais e divisoes_segmentos
  Future<Divisao?> updateDivisao(String id, Divisao divisao, {Map<String, String>? telegramChatIds}) async {
    try {
      print('🔍 DEBUG: Atualizando divisão ID: $id');
      print('   Novas Regionais IDs: ${divisao.regionalIds}');
      print('   Novos Segmentos IDs: ${divisao.segmentoIds}');

      final divisaoMap = _divisaoToMap(divisao);

      // 1. Atualizar registro principal em divisoes
      await _supabase
          .from('divisoes')
          .update(divisaoMap)
          .eq('id', id);

      // 2. Atualizar relacionamentos com regionais (Delta / Sync)
      try {
        final existingRegRows = await _supabase
            .from('divisoes_regionais')
            .select('regional_id')
            .eq('divisao_id', id);

        final existingRegIds = (existingRegRows as List)
            .map((r) => r['regional_id'] as String)
            .toSet();
        final newRegIds = divisao.regionalIds.toSet();

        final toInsertReg = newRegIds.difference(existingRegIds);
        final toDeleteReg = existingRegIds.difference(newRegIds);

        if (toDeleteReg.isNotEmpty) {
          for (var regId in toDeleteReg) {
            await _supabase
                .from('divisoes_regionais')
                .delete()
                .eq('divisao_id', id)
                .eq('regional_id', regId);
          }
        }

        if (toInsertReg.isNotEmpty) {
          final insertRows = toInsertReg.map((regId) => {
            'divisao_id': id,
            'regional_id': regId,
          }).toList();
          await _supabase.from('divisoes_regionais').insert(insertRows);
          print('✅ DEBUG: Inseridas ${insertRows.length} novas regionais em divisoes_regionais');
        }
      } catch (eRegDelta) {
        print('❌ Erro ao sincronizar delta divisoes_regionais: $eRegDelta');
      }

      // 3. Atualizar relacionamentos com segmentos (Delta / Sync)
      try {
        final existingSegRows = await _supabase
            .from('divisoes_segmentos')
            .select('segmento_id')
            .eq('divisao_id', id);

        final existingSegIds = (existingSegRows as List)
            .map((r) => r['segmento_id'] as String)
            .toSet();
        final newSegIds = divisao.segmentoIds.toSet();

        final toInsertSeg = newSegIds.difference(existingSegIds);
        final toDeleteSeg = existingSegIds.difference(newSegIds);

        if (toDeleteSeg.isNotEmpty) {
          for (var segId in toDeleteSeg) {
            await _supabase
                .from('divisoes_segmentos')
                .delete()
                .eq('divisao_id', id)
                .eq('segmento_id', segId);
          }
        }

        if (toInsertSeg.isNotEmpty) {
          final insertRows = toInsertSeg.map((segId) => {
            'divisao_id': id,
            'segmento_id': segId,
          }).toList();
          await _supabase.from('divisoes_segmentos').insert(insertRows);
          print('✅ DEBUG: Inseridos ${insertRows.length} novos segmentos em divisoes_segmentos');
        }
      } catch (eSegDelta) {
        print('❌ Erro ao sincronizar delta divisoes_segmentos: $eSegDelta');
      }

      // 4. Buscar a divisão atualizada
      final divisaoAtualizada = await getDivisaoById(id);

      // 5. Atualizar Chat IDs do Telegram
      if (divisaoAtualizada != null) {
        await cadastrarTelegramChatIdsParaDivisao(
          id,
          divisaoAtualizada.divisao,
          divisaoAtualizada.regionalIds,
          divisaoAtualizada.regionais,
          divisaoAtualizada.segmentoIds,
          divisaoAtualizada.segmentos,
          telegramChatIds,
        );
      }

      return divisaoAtualizada ?? divisao;
    } catch (e, stackTrace) {
      print('❌ Erro ao atualizar divisão: $e');
      print('❌ Stack trace: $stackTrace');
      rethrow;
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

  // Filtrar divisões
  Future<List<Divisao>> filterDivisoes({
    String? divisao,
    String? regionalId,
    String? segmento,
  }) async {
    final all = await getAllDivisoes();
    return all.where((d) {
      if (divisao != null && divisao.isNotEmpty && !d.divisao.toLowerCase().contains(divisao.toLowerCase())) {
        return false;
      }
      if (regionalId != null && regionalId.isNotEmpty && !d.atuaNaRegional(regionalId)) {
        return false;
      }
      if (segmento != null && segmento.isNotEmpty && !d.segmentos.any((s) => s.toLowerCase().contains(segmento.toLowerCase()))) {
        return false;
      }
      return true;
    }).toList();
  }

  // Buscar divisões por texto (em memória nos dados carregados para máxima segurança)
  Future<List<Divisao>> searchDivisoes(String query) async {
    final all = await getAllDivisoes();
    if (query.trim().isEmpty) return all;
    final term = query.trim().toLowerCase();
    return all.where((d) {
      return d.divisao.toLowerCase().contains(term) ||
          d.regionais.any((r) => r.toLowerCase().contains(term)) ||
          d.regional.toLowerCase().contains(term) ||
          d.segmentos.any((s) => s.toLowerCase().contains(term));
    }).toList();
  }
}
