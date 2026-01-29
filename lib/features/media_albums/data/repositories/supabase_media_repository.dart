import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import '../../../../config/supabase_config.dart';
import '../../../../services/auth_service_simples.dart';
import '../../util/path_builder.dart';
import '../models/segment.dart';
import '../models/equipment.dart';
import '../models/room.dart';
import '../models/media_image.dart';
import '../models/status_album.dart';
import '../models/annotation_models.dart';

class SupabaseMediaRepository {
  final SupabaseClient _supabase = SupabaseConfig.client;

  // ============================================
  // SEGMENTS
  // ============================================

  /// Busca segmentos, opcionalmente filtrados pelo perfil do usuário
  Future<List<Segment>> getSegments({List<String>? userSegmentoIds}) async {
    try {
      debugPrint('🔍 getSegments: Buscando segmentos...');
      debugPrint('   userSegmentoIds: $userSegmentoIds');
      
      // PRIMEIRO: Tentar buscar da tabela 'segments' (módulo de mídia)
      try {
        var query = _supabase
            .from('segments')
            .select();

        final response = await query.order('name', ascending: true);

        var segments = (response as List)
            .map((e) => Segment.fromMap(e as Map<String, dynamic>))
            .toList();

        debugPrint('   Segmentos encontrados na tabela segments: ${segments.length}');

        // Se a tabela segments tem dados, usar ela
        if (segments.isNotEmpty) {
          // Se o usuário tem segmentos no perfil, filtrar segments
          if (userSegmentoIds != null && userSegmentoIds.isNotEmpty) {
            // Tentar filtrar por segmento_id primeiro (se a coluna existir)
            try {
              // Verificar se há segments com segmento_id correspondente
              final segmentsComSegmentoId = segments.where((s) {
                if (s.segmentoId != null) {
                  return userSegmentoIds.contains(s.segmentoId);
                }
                return false;
              }).toList();

              // Se encontrou segments com segmento_id, usar esses
              if (segmentsComSegmentoId.isNotEmpty) {
                segments = segmentsComSegmentoId;
                debugPrint('   Filtrados por segmento_id: ${segments.length}');
              } else {
                // Fallback: filtrar por nome (assumindo que o nome corresponde)
                final segmentosResponse = await _supabase
                    .from('segmentos')
                    .select('id, segmento')
                    .inFilter('id', userSegmentoIds);

                final segmentosNomes = segmentosResponse
                    .map((s) => (s['segmento'] as String).toLowerCase().trim())
                    .toSet();

                // Filtrar segments que correspondem aos nomes dos segmentos do perfil
                segments = segments.where((s) {
                  return segmentosNomes.contains(s.name.toLowerCase().trim());
                }).toList();
                debugPrint('   Filtrados por nome: ${segments.length}');
              }
            } catch (e) {
              // Se falhar ao buscar segmentos, retornar todos (fallback)
              debugPrint('⚠️ Aviso: Não foi possível filtrar segmentos pelo perfil: $e');
            }
          }

          return segments;
        }
      } catch (e) {
        debugPrint('⚠️ Tabela segments não encontrada ou vazia: $e');
      }

      // FALLBACK: Se a tabela 'segments' não existe ou está vazia,
      // usar a tabela 'segmentos' do sistema
      debugPrint('   Usando fallback: tabela segmentos do sistema');
      var query = _supabase
          .from('segmentos')
          .select('id, segmento');

      if (userSegmentoIds != null && userSegmentoIds.isNotEmpty) {
        query = query.inFilter('id', userSegmentoIds);
      }

      final response = await query.order('segmento', ascending: true);

      final segments = (response as List)
          .map((e) {
            // Converter segmento do sistema para Segment do módulo de mídia
            return Segment(
              id: e['id'] as String,
              name: e['segmento'] as String,
              segmentoId: e['id'] as String, // Mesmo ID
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
          })
          .toList();

      debugPrint('   Segmentos do sistema carregados: ${segments.length}');
      return segments;
    } catch (e, stackTrace) {
      debugPrint('❌ Erro ao buscar segmentos: $e');
      debugPrint('   Stack trace: $stackTrace');
      throw Exception('Erro ao buscar segmentos: $e');
    }
  }

  Future<Segment> createSegment(String name) async {
    try {
      final response = await _supabase
          .from('segments')
          .insert({'name': name})
          .select()
          .single();

      return Segment.fromMap(response as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Erro ao criar segmento: $e');
    }
  }

  // ============================================
  // EQUIPMENTS (baseado em equipamentos_sap.localizacao)
  // ============================================

  Future<List<Equipment>> getEquipments({
    String? segmentId,
    List<String>? userSegmentoIds,
    /// Valores de locais.local_instalacao_sap permitidos (regional, divisão, segmento).
    /// Equipamentos são filtrados onde equipamentos_sap.local_instalacao corresponde a um deles.
    /// Se null: não filtra. Se vazio: retorna [].
    List<String>? userLocalNames,
  }) async {
    try {
      debugPrint('🔍 getEquipments: Buscando equipamentos (localizações)...');
      debugPrint('   userSegmentoIds: $userSegmentoIds');
      debugPrint('   userLocalNames (local_instalacao_sap): ${userLocalNames?.length ?? 0}');
      
      if (userLocalNames != null && userLocalNames.isEmpty) {
        debugPrint('   Sem locais permitidos → retornando lista vazia');
        return [];
      }

      var query = _supabase
          .from('equipamentos_sap')
          .select('local_instalacao, localizacao, equipamento')
          .or('localizacao.not.is.null,local_instalacao.not.is.null');

      // Filtrar por locais: equipamentos_sap.local_instalacao deve corresponder a locais.local_instalacao_sap
      if (userLocalNames != null && userLocalNames.isNotEmpty) {
        final sap = userLocalNames.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        if (sap.isNotEmpty) {
          try {
            if (sap.length == 1) {
              query = query.ilike('local_instalacao', '%${sap[0]}%');
            } else {
              final orConditions = sap.map((v) => 'local_instalacao.ilike.%$v%').join(',');
              query = query.or(orConditions);
            }
          } catch (e) {
            debugPrint('   ⚠️ Filtro por locais ignorado: $e');
          }
        }
      }

      final response = await query;
      debugPrint('   Registros encontrados em equipamentos_sap: ${response.length}');

      // Extrair valores únicos combinando local_instalacao e localizacao
      // Usar localizacao como chave principal (mais fácil de identificar)
      // e armazenar local_instalacao para exibição combinada
      final localizacoesUnicas = <String, Map<String, String?>>{};
      for (var item in response) {
        final localInstalacao = item['local_instalacao'] as String?;
        final localizacao = item['localizacao'] as String?;
        final equipamento = item['equipamento'] as String?;
        
        // Priorizar localizacao como chave (mais fácil de identificar)
        final chaveLocalizacao = (localizacao != null && localizacao.trim().isNotEmpty)
            ? localizacao.trim()
            : (localInstalacao != null && localInstalacao.trim().isNotEmpty)
                ? localInstalacao.trim()
                : null;
        
        if (chaveLocalizacao != null) {
          // Armazenar ambos os valores para exibição combinada
          if (!localizacoesUnicas.containsKey(chaveLocalizacao)) {
            localizacoesUnicas[chaveLocalizacao] = {
              'localizacao': localizacao?.trim(),
              'local_instalacao': localInstalacao?.trim(),
              'equipamento': equipamento?.trim(),
            };
          }
        }
      }

      debugPrint('   Localizações únicas encontradas: ${localizacoesUnicas.length}');

      // Converter para lista de Equipment com exibição combinada
      final equipments = localizacoesUnicas.entries
          .map((entry) {
            final dados = entry.value;
            final localizacao = dados['localizacao'] ?? entry.key;
            final localInstalacao = dados['local_instalacao'];
            final equipamento = dados['equipamento'];
            
            return Equipment.fromEquipamentosSap(
              localizacao,
              equipamento: equipamento,
              localInstalacao: localInstalacao,
            );
          })
          .toList();

      // Ordenar por nome
      equipments.sort((a, b) => a.name.compareTo(b.name));

      debugPrint('✅ Equipamentos retornados: ${equipments.length}');
      return equipments;
    } catch (e, stackTrace) {
      debugPrint('❌ Erro ao buscar equipamentos: $e');
      debugPrint('   Stack trace: $stackTrace');
      throw Exception('Erro ao buscar equipamentos: $e');
    }
  }

  // NOTA: createEquipment não é mais necessário pois equipamentos vêm de equipamentos_sap
  // Mantido para compatibilidade, mas não faz nada útil
  Future<Equipment> createEquipment({
    required String segmentId,
    required String name,
  }) async {
    // Como equipamentos vêm de equipamentos_sap, apenas retornar um Equipment baseado no nome
    return Equipment.fromEquipamentosSap(name);
  }

  // ============================================
  // ROOMS (baseado em equipamentos_sap.sala)
  // ============================================

  Future<List<Room>> getRooms({
    String? equipmentId,
    String? localizacao,
    String? localInstalacao,
    /// Valores de locais.local_instalacao_sap permitidos. Filtra por equipamentos_sap.local_instalacao.
    List<String>? userLocalNames,
  }) async {
    try {
      debugPrint('🔍 getRooms: Buscando salas...');
      debugPrint('   localizacao: $localizacao');
      debugPrint('   localInstalacao: $localInstalacao');
      debugPrint('   equipmentId: $equipmentId');
      
      if (userLocalNames != null && userLocalNames.isEmpty) {
        debugPrint('   Sem locais permitidos → retornando lista vazia');
        return [];
      }

      /// Monta a query: filtro por equipamento e opcionalmente por userLocalNames (local_instalacao_sap).
      dynamic buildQuery(bool applyLocalFilter) {
        var q = _supabase
            .from('equipamentos_sap')
            .select('sala, local_instalacao, localizacao');
        if (applyLocalFilter && userLocalNames != null && userLocalNames.isNotEmpty) {
          final sap = userLocalNames.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
          if (sap.isNotEmpty) {
            try {
              if (sap.length == 1) {
                q = q.ilike('local_instalacao', '%${sap[0]}%');
              } else {
                final orConditions = sap.map((v) => 'local_instalacao.ilike.%$v%').join(',');
                q = q.or(orConditions);
              }
            } catch (_) {}
          }
        }
        if (localizacao != null && localizacao.trim().isNotEmpty) {
          q = q.ilike('localizacao', '%${localizacao.trim()}%');
        } else if (localInstalacao != null && localInstalacao.trim().isNotEmpty) {
          q = q.ilike('local_instalacao', '%${localInstalacao.trim()}%');
        }
        return q;
      }

      dynamic response = await buildQuery(true);
      if (userLocalNames != null && userLocalNames.isNotEmpty && response.length == 0) {
        debugPrint('   ⚠️ 0 salas com filtro de locais; buscando salas do equipamento sem filtro de locais');
        response = await buildQuery(false);
      }
      debugPrint('   Registros encontrados em equipamentos_sap: ${response.length}');

      // Extrair valores únicos de sala
      final salasUnicas = <String, Room>{};
      for (var item in response) {
        final sala = item['sala'] as String?;
        final localInstalacao = item['local_instalacao'] as String?;
        final localizacaoValue = item['localizacao'] as String?;
        
        if (sala != null && sala.trim().isNotEmpty) {
          // Usar local_instalacao como preferência, localizacao como fallback
          final localizacaoParaRoom = (localInstalacao != null && localInstalacao.trim().isNotEmpty)
              ? localInstalacao.trim()
              : (localizacaoValue != null && localizacaoValue.trim().isNotEmpty)
                  ? localizacaoValue.trim()
                  : localizacao ?? '';
          
          // Criar chave única: sala + localizacao
          final key = '${sala.trim()}_$localizacaoParaRoom';
          if (!salasUnicas.containsKey(key)) {
            salasUnicas[key] = Room.fromEquipamentosSap(
              sala.trim(),
              localizacaoParaRoom,
            );
          }
        }
      }

      debugPrint('   Salas únicas encontradas: ${salasUnicas.length}');
      for (var r in salasUnicas.values.take(5)) {
        debugPrint('   - ${r.name} (localizacao: ${r.localizacao})');
      }
      if (salasUnicas.length > 5) {
        debugPrint('   ... e mais ${salasUnicas.length - 5}');
      }

      // Converter para lista e ordenar
      final rooms = salasUnicas.values.toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      debugPrint('✅ Salas retornadas: ${rooms.length}');
      return rooms;
    } catch (e, stackTrace) {
      debugPrint('❌ Erro ao buscar salas: $e');
      debugPrint('   Stack trace: $stackTrace');
      throw Exception('Erro ao buscar salas: $e');
    }
  }

  // NOTA: createRoom não é mais necessário pois salas vêm de equipamentos_sap
  // Mantido para compatibilidade, mas não faz nada útil
  Future<Room> createRoom({
    required String equipmentId,
    required String name,
  }) async {
    // Como salas vêm de equipamentos_sap, precisamos da localização também
    // Por enquanto, retornar um Room vazio (não deve ser usado)
    throw Exception('createRoom não é suportado. Salas vêm de equipamentos_sap.');
  }

  // ============================================
  // MEDIA IMAGES
  // ============================================

  /// Retorna os equipment_id (UUIDs determinísticos) dos equipamentos associados ao local
  /// (equipamentos_sap.local_instalacao corresponde a [localInstalacaoSap]).
  Future<List<String>> getEquipmentIdsForLocalInstalacaoSap(String localInstalacaoSap) async {
    try {
      final response = await _supabase
          .from('equipamentos_sap')
          .select('localizacao')
          .ilike('local_instalacao', '%${localInstalacaoSap.trim()}%');
      final ids = <String>{};
      for (var row in response) {
        final loc = row['localizacao'] as String?;
        if (loc != null && loc.trim().isNotEmpty) {
          ids.add(Equipment.generateDeterministicUuid('equipment:${loc.trim()}'));
        }
      }
      return ids.toList();
    } catch (e) {
      debugPrint('⚠️ getEquipmentIdsForLocalInstalacaoSap: $e');
      return [];
    }
  }

  /// Conta imagens por local_id e room_id (para exibir na tela de ordens).
  /// Retorna no máximo 999; se houver mais, retorna 999.
  Future<int> countImagesByLocalAndRoom(String? localId, String? roomId) async {
    if (localId == null && roomId == null) return 0;
    try {
      var q = _supabase.from('media_images').select('id');
      if (localId != null && roomId != null) {
        q = q.eq('local_id', localId).eq('room_id', roomId);
      } else if (localId != null) {
        q = q.eq('local_id', localId);
      } else if (roomId != null) {
        q = q.eq('room_id', roomId);
      }
      final list = await q.limit(1000);
      final n = (list as List).length;
      return n >= 999 ? 999 : n;
    } catch (e) {
      debugPrint('⚠️ countImagesByLocalAndRoom: $e');
      return 0;
    }
  }

  /// Busca imagens com paginação e filtros.
  /// [equipmentIds]: quando preenchido (ex.: local selecionado), filtra por equipment_id in list.
  /// [userRegionalIds], [userDivisaoIds], [userSegmentoIds]: quando preenchidos, restringe ao perfil do usuário.
  Future<Map<String, dynamic>> getMediaImages({
    int page = 0,
    int pageSize = 20,
    String? searchQuery,
    String? segmentId,
    String? equipmentId,
    List<String>? equipmentIds,
    String? roomId,
    MediaImageStatus? status,
    String? statusAlbumId,
    String? orderBy = 'created_at',
    bool descending = true,
    List<String>? userRegionalIds,
    List<String>? userDivisaoIds,
    List<String>? userSegmentoIds,
  }) async {
    try {
      var queryBuilder = _supabase
          .from('media_images')
          .select();

      // Com busca por texto: não filtrar no SQL (para incluir tags); buscar mais e filtrar em Dart
      final hasSearch = searchQuery != null && searchQuery.trim().isNotEmpty;
      final searchLower = hasSearch ? searchQuery.trim().toLowerCase() : '';

      if (segmentId != null) {
        queryBuilder = queryBuilder.eq('segment_id', segmentId);
      }

      if (equipmentIds != null && equipmentIds.isNotEmpty) {
        queryBuilder = queryBuilder.inFilter('equipment_id', equipmentIds);
      } else if (equipmentId != null) {
        queryBuilder = queryBuilder.eq('equipment_id', equipmentId);
      }

      if (roomId != null) {
        queryBuilder = queryBuilder.eq('room_id', roomId);
      }

      if (statusAlbumId != null) {
        queryBuilder = queryBuilder.eq('status_album_id', statusAlbumId);
      } else if (status != null) {
        queryBuilder = queryBuilder.eq('status', status.toValue());
      }

      // Filtro por perfil do usuário (regional, divisão, segmento)
      if (userRegionalIds != null && userRegionalIds.isNotEmpty) {
        queryBuilder = queryBuilder.inFilter('regional_id', userRegionalIds);
      }
      if (userDivisaoIds != null && userDivisaoIds.isNotEmpty) {
        queryBuilder = queryBuilder.inFilter('divisao_id', userDivisaoIds);
      }
      if (userSegmentoIds != null && userSegmentoIds.isNotEmpty) {
        queryBuilder = queryBuilder.inFilter('segment_id', userSegmentoIds);
      }

      final from = page * pageSize;
      final to = from + pageSize - 1;

      List<MediaImage> images;
      int totalFiltered;

      if (hasSearch) {
        // Busca: carrega um lote limitado e filtra em memória (título, descrição, tags).
        // Paginação aplicada em cima do resultado filtrado para não travar com muitos itens.
        const int searchLimit = 200;
        final responseSearch = await queryBuilder
            .order(orderBy ?? 'created_at', ascending: !descending)
            .range(0, searchLimit - 1);

        final allParsed = (responseSearch as List).map((e) {
          final map = e as Map<String, dynamic>;
          return MediaImage.fromMap(map);
        }).toList();

        final filtered = allParsed.where((img) {
          final matchTitle = img.title.toLowerCase().contains(searchLower);
          final matchDesc = (img.description ?? '').toLowerCase().contains(searchLower);
          final matchTags = img.tags.any((t) => t.toLowerCase().contains(searchLower));
          return matchTitle || matchDesc || matchTags;
        }).toList();

        totalFiltered = filtered.length;
        final start = from.clamp(0, totalFiltered);
        final end = (from + pageSize).clamp(0, totalFiltered);
        images = start < end ? filtered.sublist(start, end) : [];
      } else {
        final response = await queryBuilder
            .order(orderBy ?? 'created_at', ascending: !descending)
            .range(from, to);

        images = (response as List).map((e) {
          final map = e as Map<String, dynamic>;
          return MediaImage.fromMap(map);
        }).toList();

        final hasMore = images.length == pageSize;
        totalFiltered = hasMore ? (page + 1) * pageSize + 1 : page * pageSize + images.length;
      }

      // Buscar nomes dos relacionamentos separadamente (nome distinto para não sombrear parâmetro equipmentIds)
      final regionalIds = images.where((img) => img.regionalId != null).map((img) => img.regionalId!).toSet();
      final divisaoIds = images.where((img) => img.divisaoId != null).map((img) => img.divisaoId!).toSet();
      final segmentIds = images.where((img) => img.segmentId != null).map((img) => img.segmentId!).toSet();
      final localIds = images.where((img) => img.localId != null).map((img) => img.localId!).toSet();
      final imageEquipmentIds = images.where((img) => img.equipmentId != null).map((img) => img.equipmentId!).toSet();
      final roomIds = images.where((img) => img.roomId != null).map((img) => img.roomId!).toSet();
      final statusAlbumIds = images.where((img) => img.statusAlbumId != null).map((img) => img.statusAlbumId!).toSet();

      final regionalMap = <String, String>{};
      final divisaoMap = <String, String>{};
      final segmentMap = <String, String>{};
      final localMap = <String, String>{};
      final equipmentMap = <String, String>{};
      final roomMap = <String, String>{};

      if (regionalIds.isNotEmpty) {
        try {
          final regionais = await _supabase
              .from('regionais')
              .select('id, regional')
              .inFilter('id', regionalIds.toList());
          for (final r in regionais) {
            regionalMap[r['id'] as String] = r['regional'] as String;
          }
        } catch (e) {
          debugPrint('⚠️ Erro ao buscar regionais: $e');
        }
      }

      if (divisaoIds.isNotEmpty) {
        try {
          final divisoes = await _supabase
              .from('divisoes')
              .select('id, divisao')
              .inFilter('id', divisaoIds.toList());
          for (final d in divisoes) {
            divisaoMap[d['id'] as String] = d['divisao'] as String;
          }
        } catch (e) {
          debugPrint('⚠️ Erro ao buscar divisões: $e');
        }
      }

      if (segmentIds.isNotEmpty) {
        // Primeiro tentar buscar da tabela segments (módulo de mídia)
        try {
          final segments = await _supabase
              .from('segments')
              .select('id, name')
              .inFilter('id', segmentIds.toList());
          for (final seg in segments) {
            segmentMap[seg['id'] as String] = seg['name'] as String;
          }
        } catch (e) {
          debugPrint('⚠️ Erro ao buscar segments: $e');
        }
        
        // Se ainda faltarem segmentos, buscar da tabela segmentos (sistema)
        final missingIds = segmentIds.where((id) => !segmentMap.containsKey(id)).toList();
        if (missingIds.isNotEmpty) {
          try {
            final segmentos = await _supabase
                .from('segmentos')
                .select('id, segmento')
                .inFilter('id', missingIds);
            for (final seg in segmentos) {
              segmentMap[seg['id'] as String] = seg['segmento'] as String;
            }
          } catch (e) {
            debugPrint('⚠️ Erro ao buscar segmentos: $e');
          }
        }
      }

      if (localIds.isNotEmpty) {
        try {
          final locais = await _supabase
              .from('locais')
              .select('id, local')
              .inFilter('id', localIds.toList());
          for (final l in locais) {
            localMap[l['id'] as String] = l['local'] as String;
          }
        } catch (e) {
          debugPrint('⚠️ Erro ao buscar locais: $e');
        }
      }

      if (imageEquipmentIds.isNotEmpty) {
        // Primeiro tentar buscar da tabela equipments (módulo de mídia)
        try {
          final equipments = await _supabase
              .from('equipments')
              .select('id, name')
              .inFilter('id', imageEquipmentIds.toList());
          for (final eq in equipments) {
            equipmentMap[eq['id'] as String] = eq['name'] as String;
          }
        } catch (e) {
          debugPrint('⚠️ Erro ao buscar equipments: $e');
        }
        
        // Se ainda faltarem equipamentos, buscar da tabela equipamentos_sap
        // Gerando UUIDs determinísticos para cada localizacao e comparando
        final missingEquipmentIds = imageEquipmentIds.where((id) => !equipmentMap.containsKey(id)).toList();
        if (missingEquipmentIds.isNotEmpty) {
          try {
            // Buscar todas as localizações únicas de equipamentos_sap
            final equipamentosSap = await _supabase
                .from('equipamentos_sap')
                .select('local_instalacao, localizacao, equipamento')
                .or('localizacao.not.is.null,local_instalacao.not.is.null');
            
            // Gerar UUIDs determinísticos e comparar com os IDs faltantes
            for (final item in equipamentosSap) {
              final localizacao = item['localizacao'] as String?;
              final localInstalacao = item['local_instalacao'] as String?;
              
              if (localizacao != null && localizacao.trim().isNotEmpty) {
                final generatedId = Equipment.generateDeterministicUuid('equipment:${localizacao.trim()}');
                if (missingEquipmentIds.contains(generatedId)) {
                  // Construir nome de exibição
                  String displayName;
                  if (localInstalacao != null && 
                      localInstalacao.trim().isNotEmpty && 
                      localInstalacao.trim() != localizacao.trim()) {
                    displayName = '${localizacao.trim()} (${localInstalacao.trim()})';
                  } else {
                    displayName = localizacao.trim();
                  }
                  equipmentMap[generatedId] = displayName;
                }
              }
            }
          } catch (e) {
            debugPrint('⚠️ Erro ao buscar equipamentos_sap: $e');
          }
        }
      }

      if (roomIds.isNotEmpty) {
        // Primeiro tentar buscar da tabela rooms (módulo de mídia)
        try {
          final rooms = await _supabase
              .from('rooms')
              .select('id, name')
              .inFilter('id', roomIds.toList());
          for (final room in rooms) {
            roomMap[room['id'] as String] = room['name'] as String;
          }
        } catch (e) {
          debugPrint('⚠️ Erro ao buscar rooms: $e');
        }
        
        // Se ainda faltarem salas, buscar da tabela equipamentos_sap
        // Gerando UUIDs determinísticos para cada sala+localizacao e comparando
        final missingRoomIds = roomIds.where((id) => !roomMap.containsKey(id)).toList();
        if (missingRoomIds.isNotEmpty) {
          try {
            debugPrint('   🔍 Buscando ${missingRoomIds.length} salas faltantes de equipamentos_sap...');
            // Buscar todas as salas únicas de equipamentos_sap
            final equipamentosSap = await _supabase
                .from('equipamentos_sap')
                .select('sala, local_instalacao, localizacao')
                .or('sala.not.is.null,localizacao.not.is.null');
            
            debugPrint('   📊 Registros encontrados em equipamentos_sap: ${equipamentosSap.length}');
            
            // Gerar UUIDs determinísticos e comparar com os IDs faltantes
            int foundCount = 0;
            for (final item in equipamentosSap) {
              final sala = item['sala'] as String?;
              final localizacao = item['localizacao'] as String?;
              final localInstalacao = item['local_instalacao'] as String?;
              
              if (sala != null && sala.trim().isNotEmpty) {
                // Tentar com localizacao primeiro
                if (localizacao != null && localizacao.trim().isNotEmpty) {
                  final generatedId = Room.generateDeterministicUuid('room:${sala.trim()}:${localizacao.trim()}');
                  if (missingRoomIds.contains(generatedId) && !roomMap.containsKey(generatedId)) {
                    roomMap[generatedId] = sala.trim();
                    foundCount++;
                    debugPrint('   ✅ Sala encontrada (localizacao): $sala (ID: $generatedId)');
                  }
                }
                
                // Tentar com localInstalacao também (pode ter sido usado na criação)
                if (localInstalacao != null && localInstalacao.trim().isNotEmpty) {
                  final generatedIdWithLocalInst = Room.generateDeterministicUuid('room:${sala.trim()}:${localInstalacao.trim()}');
                  if (missingRoomIds.contains(generatedIdWithLocalInst) && !roomMap.containsKey(generatedIdWithLocalInst)) {
                    roomMap[generatedIdWithLocalInst] = sala.trim();
                    foundCount++;
                    debugPrint('   ✅ Sala encontrada (local_instalacao): $sala (ID: $generatedIdWithLocalInst)');
                  }
                }
              }
            }
            debugPrint('   📈 Total de salas encontradas: $foundCount de ${missingRoomIds.length}');
          } catch (e) {
            debugPrint('⚠️ Erro ao buscar salas de equipamentos_sap: $e');
          }
        }
      }

      // Buscar status de álbuns separadamente
      final statusAlbumMap = <String, Map<String, dynamic>>{};
      if (statusAlbumIds.isNotEmpty) {
        try {
          final statusAlbums = await _supabase
              .from('status_albums')
              .select()
              .inFilter('id', statusAlbumIds.toList());
          for (final status in statusAlbums) {
            statusAlbumMap[status['id'] as String] = status as Map<String, dynamic>;
          }
        } catch (e) {
          debugPrint('⚠️ Erro ao buscar status_albums: $e');
        }
      }

      // Nome do usuário que cadastrou (created_by -> usuarios.nome)
      final creatorIds = images.map((img) => img.createdBy).toSet().toList();
      final creatorMap = <String, String>{};
      if (creatorIds.isNotEmpty) {
        try {
          final usuarios = await _supabase
              .from('usuarios')
              .select('id, nome')
              .inFilter('id', creatorIds);
          for (final u in usuarios) {
            final nome = u['nome'] as String?;
            if (nome != null && nome.isNotEmpty) {
              creatorMap[u['id'] as String] = nome;
            }
          }
        } catch (e) {
          debugPrint('⚠️ Erro ao buscar nomes de criadores: $e');
        }
      }

      // Adicionar nomes, status e URL da imagem anotada às imagens
      final imagesWithNames = images.map((img) {
        final statusAlbumData = img.statusAlbumId != null 
            ? statusAlbumMap[img.statusAlbumId] 
            : null;
        var withNames = img.copyWith(
          regionalName: img.regionalId != null ? regionalMap[img.regionalId] : null,
          divisaoName: img.divisaoId != null ? divisaoMap[img.divisaoId] : null,
          segmentName: img.segmentId != null ? segmentMap[img.segmentId] : null,
          localName: img.localId != null ? localMap[img.localId] : null,
          equipmentName: img.equipmentId != null ? equipmentMap[img.equipmentId] : null,
          roomName: img.roomId != null ? roomMap[img.roomId] : null,
          creatorName: creatorMap[img.createdBy],
          statusAlbum: statusAlbumData != null 
              ? StatusAlbum.fromMap(statusAlbumData)
              : null,
        );
        if (withNames.annotatedFilePath != null) {
          withNames = withNames.copyWith(
            annotatedFileUrl: getPublicUrl(withNames.annotatedFilePath!),
          );
        }
        return withNames;
      }).toList();

      // Total: quando há busca, usar totalFiltered; senão, estimativa por página
      final total = hasSearch
          ? totalFiltered
          : (images.length == pageSize ? (page + 1) * pageSize + 1 : page * pageSize + images.length);

      return {
        'images': imagesWithNames,
        'total': total,
        'page': page,
        'pageSize': pageSize,
      };
    } catch (e) {
      throw Exception('Erro ao buscar imagens: $e');
    }
  }

  /// Busca uma imagem por ID
  Future<MediaImage> getMediaImageById(String id) async {
    try {
      final response = await _supabase
          .from('media_images')
          .select()
          .eq('id', id)
          .single();

      var image = MediaImage.fromMap(response as Map<String, dynamic>);

      // Buscar status_album se existir
      StatusAlbum? statusAlbumForImage;
      if (image.statusAlbumId != null) {
        try {
          final statusResponse = await _supabase
              .from('status_albums')
              .select()
              .eq('id', image.statusAlbumId!)
              .maybeSingle();
          if (statusResponse != null) {
            statusAlbumForImage = StatusAlbum.fromMap(statusResponse as Map<String, dynamic>);
          }
        } catch (e) {
          debugPrint('⚠️ Erro ao buscar status_album: $e');
        }
      }

      // Buscar nomes dos relacionamentos
      String? regionalName;
      String? divisaoName;
      String? segmentName;
      String? localName;
      String? equipmentName;
      String? roomName;

      if (image.localId != null) {
        try {
          final l = await _supabase.from('locais').select('local').eq('id', image.localId!).maybeSingle();
          localName = l?['local'] as String?;
        } catch (e) {
          debugPrint('⚠️ Erro ao buscar local: $e');
        }
      }

      if (image.regionalId != null) {
        try {
          final r = await _supabase.from('regionais').select('regional').eq('id', image.regionalId!).maybeSingle();
          regionalName = r?['regional'] as String?;
        } catch (e) {
          debugPrint('⚠️ Erro ao buscar regional: $e');
        }
      }

      if (image.divisaoId != null) {
        try {
          final d = await _supabase.from('divisoes').select('divisao').eq('id', image.divisaoId!).maybeSingle();
          divisaoName = d?['divisao'] as String?;
        } catch (e) {
          debugPrint('⚠️ Erro ao buscar divisão: $e');
        }
      }

      if (image.segmentId != null) {
        // Primeiro tentar buscar da tabela segments (módulo de mídia)
        try {
          final segment = await _supabase
              .from('segments')
              .select('name')
              .eq('id', image.segmentId!)
              .maybeSingle();
          segmentName = segment?['name'] as String?;
        } catch (e) {
          debugPrint('⚠️ Erro ao buscar segment: $e');
        }
        
        // Se não encontrou, buscar da tabela segmentos (sistema)
        if (segmentName == null) {
          try {
            final segmento = await _supabase
                .from('segmentos')
                .select('segmento')
                .eq('id', image.segmentId!)
                .maybeSingle();
            segmentName = segmento?['segmento'] as String?;
          } catch (e) {
            debugPrint('⚠️ Erro ao buscar segmento: $e');
          }
        }
      }

      if (image.equipmentId != null) {
        // Primeiro tentar buscar da tabela equipments (módulo de mídia)
        try {
          final equipment = await _supabase
              .from('equipments')
              .select('name')
              .eq('id', image.equipmentId!)
              .maybeSingle();
          equipmentName = equipment?['name'] as String?;
        } catch (e) {
          debugPrint('⚠️ Erro ao buscar equipment: $e');
        }
        
        // Se não encontrou, buscar da tabela equipamentos_sap
        if (equipmentName == null) {
          try {
            final equipamentosSap = await _supabase
                .from('equipamentos_sap')
                .select('local_instalacao, localizacao, equipamento')
                .or('localizacao.not.is.null,local_instalacao.not.is.null');
            
            for (final item in equipamentosSap) {
              final localizacao = item['localizacao'] as String?;
              final localInstalacao = item['local_instalacao'] as String?;
              
              if (localizacao != null && localizacao.trim().isNotEmpty) {
                final generatedId = Equipment.generateDeterministicUuid('equipment:${localizacao.trim()}');
                if (generatedId == image.equipmentId) {
                  // Construir nome de exibição
                  if (localInstalacao != null && 
                      localInstalacao.trim().isNotEmpty && 
                      localInstalacao.trim() != localizacao.trim()) {
                    equipmentName = '${localizacao.trim()} (${localInstalacao.trim()})';
                  } else {
                    equipmentName = localizacao.trim();
                  }
                  break;
                }
              }
            }
          } catch (e) {
            debugPrint('⚠️ Erro ao buscar equipamento de equipamentos_sap: $e');
          }
        }
      }

      if (image.roomId != null) {
        // Primeiro tentar buscar da tabela rooms (módulo de mídia)
        try {
          final room = await _supabase
              .from('rooms')
              .select('name')
              .eq('id', image.roomId!)
              .maybeSingle();
          roomName = room?['name'] as String?;
        } catch (e) {
          debugPrint('⚠️ Erro ao buscar room: $e');
        }
        
        // Se não encontrou, buscar da tabela equipamentos_sap
        if (roomName == null) {
          try {
            debugPrint('   🔍 Buscando sala (roomId: ${image.roomId}) de equipamentos_sap...');
            final equipamentosSap = await _supabase
                .from('equipamentos_sap')
                .select('sala, local_instalacao, localizacao')
                .or('sala.not.is.null,localizacao.not.is.null');
            
            debugPrint('   📊 Registros encontrados: ${equipamentosSap.length}');
            
            for (final item in equipamentosSap) {
              final sala = item['sala'] as String?;
              final localizacao = item['localizacao'] as String?;
              final localInstalacao = item['local_instalacao'] as String?;
              
              if (sala != null && sala.trim().isNotEmpty) {
                // Tentar com localizacao primeiro
                if (localizacao != null && localizacao.trim().isNotEmpty) {
                  final generatedId = Room.generateDeterministicUuid('room:${sala.trim()}:${localizacao.trim()}');
                  if (generatedId == image.roomId) {
                    roomName = sala.trim();
                    debugPrint('   ✅ Sala encontrada (localizacao): $roomName');
                    break;
                  }
                }
                
                // Tentar com localInstalacao também (pode ter sido usado na criação)
                if (roomName == null && localInstalacao != null && localInstalacao.trim().isNotEmpty) {
                  final generatedIdWithLocalInst = Room.generateDeterministicUuid('room:${sala.trim()}:${localInstalacao.trim()}');
                  if (generatedIdWithLocalInst == image.roomId) {
                    roomName = sala.trim();
                    debugPrint('   ✅ Sala encontrada (local_instalacao): $roomName');
                    break;
                  }
                }
              }
            }
            
            if (roomName == null) {
              debugPrint('   ⚠️ Sala não encontrada para roomId: ${image.roomId}');
            }
          } catch (e) {
            debugPrint('⚠️ Erro ao buscar sala de equipamentos_sap: $e');
          }
        }
      }

      // Buscar status_album se existir
      StatusAlbum? statusAlbumData;
      if (image.statusAlbumId != null) {
        try {
          final statusResponse = await _supabase
              .from('status_albums')
              .select()
              .eq('id', image.statusAlbumId!)
              .maybeSingle();
          if (statusResponse != null) {
            statusAlbumData = StatusAlbum.fromMap(statusResponse as Map<String, dynamic>);
          }
        } catch (e) {
          debugPrint('⚠️ Erro ao buscar status_album: $e');
        }
      }

      // Nome do usuário que cadastrou
      String? creatorName;
      try {
        final creator = await _supabase
            .from('usuarios')
            .select('nome')
            .eq('id', image.createdBy)
            .maybeSingle();
        creatorName = creator?['nome'] as String?;
      } catch (e) {
        debugPrint('⚠️ Erro ao buscar criador: $e');
      }

      // Nome do usuário que fez as anotações (media_annotations.created_by)
      String? annotatorName;
      try {
        final ann = await _supabase
            .from('media_annotations')
            .select('created_by')
            .eq('media_image_id', image.id)
            .maybeSingle();
        final annotatorId = ann?['created_by'] as String?;
        if (annotatorId != null) {
          final annotator = await _supabase
              .from('usuarios')
              .select('nome')
              .eq('id', annotatorId)
              .maybeSingle();
          annotatorName = annotator?['nome'] as String?;
        }
      } catch (e) {
        debugPrint('⚠️ Erro ao buscar anotador: $e');
      }

      var result = image.copyWith(
        regionalName: regionalName,
        divisaoName: divisaoName,
        segmentName: segmentName,
        localName: localName,
        equipmentName: equipmentName,
        roomName: roomName,
        statusAlbum: statusAlbumForImage ?? statusAlbumData,
        creatorName: creatorName,
        annotatorName: annotatorName,
      );
      // Preencher URL da imagem anotada para exibição por padrão
      if (result.annotatedFilePath != null) {
        result = result.copyWith(
          annotatedFileUrl: getPublicUrl(result.annotatedFilePath!),
        );
      }
      return result;
    } catch (e) {
      throw Exception('Erro ao buscar imagem: $e');
    }
  }

  /// Garante que um segmento existe na tabela segments (sincroniza se necessário)
  Future<String> _ensureSegmentExists(String segmentId, String segmentName) async {
    try {
      debugPrint('   🔄 Verificando se segmento existe na tabela segments...');
      debugPrint('      segmentId: $segmentId');
      debugPrint('      segmentName: $segmentName');
      
      // Verificar se o segmento já existe na tabela segments
      final existing = await _supabase
          .from('segments')
          .select('id')
          .eq('id', segmentId)
          .maybeSingle();
      
      if (existing != null) {
        debugPrint('      ✅ Segmento já existe na tabela segments');
        return segmentId;
      }
      
      // Se não existe, criar na tabela segments
      debugPrint('      ⚠️ Segmento não encontrado, criando na tabela segments...');
      try {
        final response = await _supabase
            .from('segments')
            .insert({
              'id': segmentId,
              'name': segmentName,
            })
            .select('id')
            .single();
        
        debugPrint('      ✅ Segmento criado na tabela segments: ${response['id']}');
        return response['id'] as String;
      } catch (e) {
        // Se falhar por constraint (já existe), tentar buscar novamente
        if (e.toString().contains('duplicate') || e.toString().contains('unique')) {
          debugPrint('      ℹ️ Segmento já existe (race condition), buscando...');
          final found = await _supabase
              .from('segments')
              .select('id')
              .eq('id', segmentId)
              .maybeSingle();
          if (found != null) {
            return found['id'] as String;
          }
        }
        rethrow;
      }
    } catch (e) {
      debugPrint('      ❌ Erro ao garantir segmento: $e');
      // Se falhar, retornar o ID original e deixar a foreign key falhar
      // (melhor que silenciosamente ignorar)
      return segmentId;
    }
  }

  /// Cria uma nova imagem
  Future<MediaImage> createMediaImage(MediaImage image) async {
    try {
      debugPrint('💾 createMediaImage: Criando registro...');
      debugPrint('   Título: ${image.title}');
      debugPrint('   Segmento: ${image.segmentId}');
      debugPrint('   Equipamento: ${image.equipmentId}');
      debugPrint('   Sala: ${image.roomId}');
      debugPrint('   File Path: ${image.filePath}');
      debugPrint('   File URL: ${image.fileUrl}');
      debugPrint('   Created By: ${image.createdBy}');
      debugPrint('   Tags: ${image.tags}');
      debugPrint('   Status: ${image.status}');
      
      // Garantir que o segmento existe na tabela segments antes de inserir
      String? finalSegmentId = image.segmentId;
      if (finalSegmentId != null) {
        // Buscar o nome do segmento para criar se necessário
        String segmentName = 'Segmento $finalSegmentId'; // Nome padrão
        try {
          // Tentar buscar da tabela segmentos primeiro
          final segmento = await _supabase
              .from('segmentos')
              .select('segmento')
              .eq('id', finalSegmentId)
              .maybeSingle();
          if (segmento != null) {
            segmentName = segmento['segmento'] as String? ?? segmentName;
          }
        } catch (e) {
          debugPrint('   ⚠️ Não foi possível buscar nome do segmento: $e');
        }
        
        finalSegmentId = await _ensureSegmentExists(finalSegmentId, segmentName);
      }
      
      final insertMap = image.toInsertMap();
      // Atualizar segment_id se foi modificado
      if (finalSegmentId != null && finalSegmentId != image.segmentId) {
        insertMap['segment_id'] = finalSegmentId;
      }
      
      debugPrint('   📝 Dados para inserção:');
      for (var entry in insertMap.entries) {
        debugPrint('      ${entry.key}: ${entry.value}');
      }
      
      debugPrint('   🔍 Inserindo no banco...');
      final response = await _supabase
          .from('media_images')
          .insert(insertMap)
          .select()
          .single();
      
      debugPrint('   ✅ Registro criado com sucesso!');
      final created = MediaImage.fromMap(response as Map<String, dynamic>);
      debugPrint('   ID gerado: ${created.id}');
      
      return created;
    } catch (e, stackTrace) {
      debugPrint('   ❌ ERRO em createMediaImage: $e');
      debugPrint('   Stack trace: $stackTrace');
      throw Exception('Erro ao criar imagem: $e');
    }
  }

  /// Atualiza uma imagem
  Future<MediaImage> updateMediaImage(MediaImage image) async {
    try {
      // Preparar dados de atualização
      final updateData = <String, dynamic>{
        'title': image.title,
        'description': image.description,
        'tags': image.tags,
        'status': image.status.toValue(),
        'regional_id': image.regionalId,
        'divisao_id': image.divisaoId,
        'segment_id': image.segmentId,
        'local_id': image.localId,
        'equipment_id': image.equipmentId,
        'room_id': image.roomId,
      };
      
      // Tentar adicionar status_album_id apenas se não for null
      // Se a coluna não existir, o erro será capturado abaixo
      if (image.statusAlbumId != null) {
        updateData['status_album_id'] = image.statusAlbumId;
      }
      
      final response = await _supabase
          .from('media_images')
          .update(updateData)
          .eq('id', image.id)
          .select()
          .single();

      var updatedImage = MediaImage.fromMap(response as Map<String, dynamic>);
      
      // Buscar status_album se existir
      if (updatedImage.statusAlbumId != null) {
        try {
          final statusResponse = await _supabase
              .from('status_albums')
              .select()
              .eq('id', updatedImage.statusAlbumId!)
              .maybeSingle();
          if (statusResponse != null) {
            final statusAlbum = StatusAlbum.fromMap(statusResponse as Map<String, dynamic>);
            updatedImage = updatedImage.copyWith(statusAlbum: statusAlbum);
          }
        } catch (e) {
          debugPrint('⚠️ Erro ao buscar status_album: $e');
        }
      }
      
      return updatedImage;
    } catch (e) {
      // Verificar se o erro é relacionado à coluna status_album_id não existir
      final errorString = e.toString();
      if (errorString.contains('status_album_id') && 
          (errorString.contains('schema cache') || errorString.contains('column'))) {
        throw Exception(
          'A coluna status_album_id não existe na tabela media_images. '
          'Por favor, execute a migração SQL em: '
          'lib/features/media_albums/migrations/EXECUTAR_TODAS_MIGRATIONS.sql'
        );
      }
      throw Exception('Erro ao atualizar imagem: $e');
    }
  }

  /// Deleta uma imagem
  Future<void> deleteMediaImage(String id) async {
    try {
      await _supabase
          .from('media_images')
          .delete()
          .eq('id', id);
    } catch (e) {
      throw Exception('Erro ao deletar imagem: $e');
    }
  }

  // ============================================
  // MEDIA ANNOTATIONS (JSON + export PNG)
  // ============================================

  /// Busca anotações de uma imagem. Retorna lista vazia se não existir.
  Future<List<AnnotationItem>> fetchAnnotation(String mediaImageId) async {
    try {
      final response = await _supabase
          .from('media_annotations')
          .select('annotations_json')
          .eq('media_image_id', mediaImageId)
          .maybeSingle();
      if (response == null) return [];
      final json = response['annotations_json'];
      return annotationsFromJson(json);
    } catch (e) {
      debugPrint('⚠️ fetchAnnotation: $e');
      return [];
    }
  }

  /// Insere ou atualiza anotações (upsert por media_image_id).
  /// Usa autenticação interna do Flutter (AuthServiceSimples), não Supabase Auth.
  Future<void> upsertAnnotation(
    String mediaImageId,
    List<Map<String, dynamic>> annotationsJson,
  ) async {
    final usuario = AuthServiceSimples().currentUser;
    final userId = usuario?.id;
    if (userId == null || userId.isEmpty) throw Exception('Usuário não autenticado');
    final existing = await _supabase
        .from('media_annotations')
        .select('id, version')
        .eq('media_image_id', mediaImageId)
        .maybeSingle();
    if (existing != null) {
      final version = ((existing['version'] as int?) ?? 1) + 1;
      await _supabase
          .from('media_annotations')
          .update({
            'annotations_json': annotationsJson,
            'version': version,
          })
          .eq('media_image_id', mediaImageId);
    } else {
      await _supabase.from('media_annotations').insert({
        'media_image_id': mediaImageId,
        'annotations_json': annotationsJson,
        'created_by': userId,
      });
    }
  }

  /// Upload de PNG anotado para o bucket. Path deve seguir PathBuilder.buildAnnotatedPngPath.
  Future<String> uploadAnnotatedPng({
    required String path,
    required List<int> bytes,
  }) async {
    await _supabase.storage
        .from(PathBuilder.bucketName)
        .uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(
            contentType: 'image/png',
            upsert: true,
          ),
        );
    return getPublicUrl(path);
  }

  /// Atualiza media_images com path e data do PNG anotado.
  Future<void> updateMediaImageAnnotatedPath(
    String mediaImageId,
    String annotatedFilePath,
    DateTime annotatedUpdatedAt,
  ) async {
    await _supabase
        .from('media_images')
        .update({
          'annotated_file_path': annotatedFilePath,
          'annotated_updated_at': annotatedUpdatedAt.toUtc().toIso8601String(),
        })
        .eq('id', mediaImageId);
  }

  // ============================================
  // STORAGE
  // ============================================

  /// Faz upload de um arquivo para o storage
  Future<String> uploadFile({
    required String path,
    required List<int> fileBytes,
    String? contentType,
  }) async {
    try {
      debugPrint('📤 uploadFile: Iniciando upload...');
      debugPrint('   Path: $path');
      debugPrint('   Content-Type: $contentType');
      debugPrint('   Tamanho: ${fileBytes.length} bytes');
      debugPrint('   Bucket: ${PathBuilder.bucketName}');
      
      // Verificar se o bucket existe (tentativa opcional - não bloqueia se falhar)
      debugPrint('   🔍 Verificando bucket...');
      bool bucketExists = false;
      try {
        final buckets = await _supabase.storage.listBuckets();
        bucketExists = buckets.any((b) => b.name == PathBuilder.bucketName);
        debugPrint('   ${bucketExists ? "✅" : "❌"} Bucket existe: $bucketExists');
        
        if (!bucketExists) {
          debugPrint('   ⚠️ Bucket "${PathBuilder.bucketName}" não encontrado na lista.');
          debugPrint('   💡 Isso pode ser normal se o bucket for público e não tivermos permissão para listar.');
          debugPrint('   💡 Tentando upload mesmo assim...');
          debugPrint('   💡 Se falhar, certifique-se de que o bucket existe e está PÚBLICO:');
          debugPrint('      Storage > Buckets > taskflow-media > Edit > Public bucket: ✅');
        }
      } catch (e) {
        debugPrint('   ⚠️ Erro ao verificar bucket: $e');
        // Se o erro for de permissão para listar buckets, continuar tentando o upload
        // (o bucket pode existir mas não temos permissão para listar - comum em buckets públicos)
        debugPrint('   ⚠️ Sem permissão para listar buckets, mas tentando upload mesmo assim...');
        debugPrint('   💡 Isso é normal para buckets públicos.');
      }
      
      // Upload do arquivo
      debugPrint('   ☁️ Fazendo upload do arquivo...');
      
      // Log do path (bucket público não precisa verificar userId)
      debugPrint('   🔍 Path do arquivo:');
      debugPrint('      Path completo: $path');
      
      try {
        await _supabase.storage
            .from(PathBuilder.bucketName)
            .uploadBinary(
              path,
              Uint8List.fromList(fileBytes),
              fileOptions: FileOptions(
                contentType: contentType ?? 'image/jpeg',
                upsert: false,
              ),
            );
        debugPrint('   ✅ Arquivo enviado com sucesso!');
      } catch (e) {
        debugPrint('   ❌ Erro no upload: $e');
        if (e.toString().contains('row-level security') || e.toString().contains('403')) {
          debugPrint('   ⚠️ Erro de RLS (Row Level Security)');
          debugPrint('   💡 Diagnóstico:');
          debugPrint('      - Path: $path');
          debugPrint('   💡 Soluções:');
          debugPrint('      1. Verifique se o bucket "taskflow-media" foi criado e está PÚBLICO:');
          debugPrint('         Storage > Buckets > taskflow-media > Edit > Public bucket: ✅');
          debugPrint('      2. Execute: lib/features/media_albums/migrations/CORRIGIR_POLITICAS_STORAGE.sql');
          debugPrint('      3. Verifique se as políticas RLS foram criadas corretamente');
          debugPrint('      4. As políticas devem ser simples: bucket_id = \'taskflow-media\'');
          debugPrint('   💡 NOTA: O bucket deve ser PÚBLICO (como os outros: anexos-tarefas, sap_exports, etc.)');
          debugPrint('   💡 Veja: lib/features/media_albums/migrations/CRIAR_BUCKET_MANUAL.md');
        }
        rethrow;
      }

      // Como o bucket é privado, gerar signed URL
      // A signed URL expira em 1 ano (pode ser ajustado)
      // Isso garante que a URL salva no banco continue funcionando por muito tempo
      debugPrint('   🔗 Gerando signed URL...');
      final signedUrl = await _supabase.storage
          .from(PathBuilder.bucketName)
          .createSignedUrl(path, 31536000); // 1 ano em segundos (365 * 24 * 60 * 60)
      debugPrint('   ✅ Signed URL gerada: $signedUrl');

      return signedUrl;
    } catch (e, stackTrace) {
      debugPrint('   ❌ ERRO em uploadFile: $e');
      debugPrint('   Stack trace: $stackTrace');
      throw Exception('Erro ao fazer upload: $e');
    }
  }

  /// Obtém URL assinada (signed) para um arquivo privado
  /// expiresIn: tempo de expiração em segundos (padrão: 1 hora)
  Future<String> getSignedUrl(String path, {int expiresIn = 3600}) async {
    try {
      final signedUrl = await _supabase.storage
          .from(PathBuilder.bucketName)
          .createSignedUrl(path, expiresIn);

      return signedUrl;
    } catch (e) {
      throw Exception('Erro ao obter URL assinada: $e');
    }
  }

  /// Obtém URL pública (se o bucket for público)
  /// NOTA: Não funciona se o bucket for privado
  String getPublicUrl(String path) {
    return _supabase.storage
        .from(PathBuilder.bucketName)
        .getPublicUrl(path);
  }

  /// Deleta um arquivo do storage
  Future<void> deleteFile(String path) async {
    try {
      await _supabase.storage
          .from(PathBuilder.bucketName)
          .remove([path]);
    } catch (e) {
      throw Exception('Erro ao deletar arquivo: $e');
    }
  }
}
