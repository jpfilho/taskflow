import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/nota_sap.dart';
import '../models/nota_historico_visual.dart';
import '../features/media_albums/data/models/media_image.dart';
import '../features/media_albums/data/models/equipment.dart';
import '../features/media_albums/data/models/room.dart';

/// Serviço responsável pelo cruzamento de contexto (Read-Only) entre Notas SAP e o Módulo de Álbuns.
class NotaHistoricoVisualService {
  final SupabaseClient? _clientOverride;

  NotaHistoricoVisualService({SupabaseClient? client})
      : _clientOverride = client;

  SupabaseClient get _supabase => _clientOverride ?? SupabaseConfig.client;

  /// Blacklist de valores de sala que não devem ser considerados para correspondência específica (Nível B)
  static const Set<String> _blacklistSalas = {
    '',
    '-',
    '--',
    '---',
    'GERAL',
    'N/A',
    'NA',
    'NAO APLICAVEL',
    'NÃO APLICÁVEL',
    'SEM SALA',
    'INDEFINIDO',
  };

  /// Extrai a raiz da instalação SAP para desconsiderar ramificações de trechos finais (ex: -4LT1)
  /// e permitir cruzamento assertivo de ativos (LTs e Subestações).
  static String extrairRaizInstalacaoSap(String? codigoSap) {
    if (codigoSap == null) return '';
    final limpo = codigoSap.trim();
    if (limpo.isEmpty) return '';

    final partes = limpo.split('-');
    if (partes.length < 3) return limpo;

    // Se for Linha de Transmissão (ex: H-L-SIBDSSBD-RB4L01-4LT1 -> H-L-SIBDSSBD-RB4L01)
    if (partes[1].toUpperCase() == 'L' && partes.length >= 4) {
      return partes.take(4).join('-');
    }

    // Se for Subestação (ex: H-S-STSA-RB4S01-4EL1-S401 -> H-S-STSA)
    if (partes[1].toUpperCase() == 'S') {
      return partes.take(3).join('-');
    }

    // Padrão genérico: até 4 blocos
    if (partes.length >= 4) {
      return partes.take(4).join('-');
    }

    return limpo;
  }

  /// Normaliza o valor de sala, descartando entradas genéricas ou inválidas para Nível B.
  static String? normalizarSala(String? sala) {
    if (sala == null) return null;
    final limpa = sala.trim();
    if (limpa.isEmpty) return null;

    final upper = limpa.toUpperCase();
    if (_blacklistSalas.contains(upper)) {
      return null;
    }

    return limpa;
  }

  /// Consulta fotografias históricas em `media_images` relacionadas estritamente
  /// ao contexto do mesmo Local e mesma Sala da Nota SAP.
  /// 
  /// Não duplica arquivos, não altera o banco e não cria vínculos formais de evidência.
  Future<HistoricoVisualResultado> buscarHistoricoVisual(
    NotaSAP nota, {
    int limitePorNivel = 100,
  }) async {
    try {
      final codigoLocalSap = nota.localInstalacao?.trim();
      final localNomeNota = nota.local?.trim();
      final raizSap = extrairRaizInstalacaoSap(codigoLocalSap);
      final salaNormalizada = normalizarSala(nota.sala);
      final equipNumero = nota.equipamento?.trim();

      if (raizSap.isEmpty &&
          (codigoLocalSap == null || codigoLocalSap.isEmpty) &&
          (localNomeNota == null || localNomeNota.isEmpty)) {
        debugPrint('⚠️ NotaHistoricoVisualService: Nota sem local ou local_instalacao definido.');
        return HistoricoVisualResultado.vazio(
          localNome: nota.local,
          salaNome: salaNormalizada,
          filtroSalaAplicado: salaNormalizada != null,
        );
      }

      // 1. Identificar o Local exato na tabela locais
      List<dynamic> locaisList = [];

      // Tentativa 1: Busca pelo localNome exato da Nota
      if (localNomeNota != null && localNomeNota.isNotEmpty) {
        try {
          final q = await _supabase
              .from('locais')
              .select('id, local, local_instalacao_sap')
              .ilike('local', localNomeNota);
          locaisList = q as List;
        } catch (_) {}
      }

      // Tentativa 2: Busca pelo local_instalacao_sap exato da Nota se ainda vazio
      if (locaisList.isEmpty && codigoLocalSap != null && codigoLocalSap.isNotEmpty) {
        try {
          final q = await _supabase
              .from('locais')
              .select('id, local, local_instalacao_sap')
              .ilike('local_instalacao_sap', codigoLocalSap);
          locaisList = q as List;
        } catch (_) {}
      }

      // Tentativa 3: Se não encontrou exato, busca pela raiz ou substring compartilhada
      if (locaisList.isEmpty && raizSap.isNotEmpty) {
        try {
          final q = await _supabase
              .from('locais')
              .select('id, local, local_instalacao_sap')
              .or('local_instalacao_sap.ilike.%$raizSap%,local_instalacao_sap.ilike.%${codigoLocalSap ?? raizSap}%');
          locaisList = q as List;
        } catch (_) {}
      }

      if (locaisList.isEmpty) {
        debugPrint('ℹ️ NotaHistoricoVisualService: Nenhum local encontrado para $localNomeNota / $raizSap');
        return HistoricoVisualResultado.vazio(
          localNome: localNomeNota ?? nota.local,
          salaNome: salaNormalizada,
          filtroSalaAplicado: salaNormalizada != null,
        );
      }

      final localIds = locaisList.map((l) => l['id'] as String).toSet().toList();
      final localNomePrincipal = locaisList.first['local'] as String? ?? (localNomeNota ?? nota.local);

      // 2. Resolver mapeamentos técnicos de Equipamento e Sala
      final uuidsEquipamentoEsperados = <String>{};
      final roomIdsEsperados = <String>{};
      final mapaRoomIdParaSala = <String, String>{};

      // Se a nota tiver equipamento SAP definido, buscar seus dados técnicos
      if (equipNumero != null && equipNumero.isNotEmpty) {
        try {
          final eqResponse = await _supabase
              .from('equipamentos_sap')
              .select('equipamento, localizacao, local_instalacao')
              .eq('equipamento', equipNumero);

          for (final item in (eqResponse as List)) {
            final loc = (item['localizacao'] as String?)?.trim();
            final locInst = (item['local_instalacao'] as String?)?.trim();
            final num = (item['equipamento'] as String?)?.trim();

            if (loc != null && loc.isNotEmpty) {
              uuidsEquipamentoEsperados.add(Equipment.generateDeterministicUuid('equipment:$loc'));
            }
            if (locInst != null && locInst.isNotEmpty) {
              uuidsEquipamentoEsperados.add(Equipment.generateDeterministicUuid('equipment:$locInst'));
            }
            if (num != null && num.isNotEmpty) {
              uuidsEquipamentoEsperados.add(Equipment.generateDeterministicUuid('equipment:$num'));
            }
          }
        } catch (e) {
          debugPrint('⚠️ Erro ao resolver equipamentos_sap para equipamento $equipNumero: $e');
        }
      }

      // Se a nota tiver sala/estrutura válida, buscar e mapear os IDs de sala
      if (salaNormalizada != null && salaNormalizada.isNotEmpty) {
        try {
          var salasQuery = _supabase
              .from('equipamentos_sap')
              .select('sala, local_instalacao, localizacao')
              .ilike('sala', salaNormalizada);

          if (raizSap.isNotEmpty) {
            salasQuery = salasQuery.ilike('local_instalacao', '%$raizSap%');
          }

          final salasResponse = await salasQuery;

          for (final item in (salasResponse as List)) {
            final s = (item['sala'] as String?)?.trim() ?? salaNormalizada;
            final locInst = (item['local_instalacao'] as String?)?.trim();
            final loc = (item['localizacao'] as String?)?.trim();

            if (locInst != null && locInst.isNotEmpty) {
              final rid = Room.generateDeterministicUuid('room:$s:$locInst');
              roomIdsEsperados.add(rid);
              mapaRoomIdParaSala[rid] = s;
            }
            if (loc != null && loc.isNotEmpty) {
              final rid = Room.generateDeterministicUuid('room:$s:$loc');
              roomIdsEsperados.add(rid);
              mapaRoomIdParaSala[rid] = s;
            }
            final ridGenerico = Room.generateDeterministicUuid('room:$s');
            roomIdsEsperados.add(ridGenerico);
            mapaRoomIdParaSala[ridGenerico] = s;
          }
        } catch (e) {
          debugPrint('⚠️ Erro ao consultar salas em equipamentos_sap: $e');
        }

        // Adiciona UUIDs determinísticos derivados dos locais identificados
        for (final locItem in locaisList) {
          final sapLoc = (locItem['local_instalacao_sap'] as String?)?.trim();
          if (sapLoc != null && sapLoc.isNotEmpty) {
            final rid = Room.generateDeterministicUuid('room:$salaNormalizada:$sapLoc');
            roomIdsEsperados.add(rid);
            mapaRoomIdParaSala[rid] = salaNormalizada;
          }
        }

        if (codigoLocalSap != null && codigoLocalSap.isNotEmpty) {
          final ridLoc = Room.generateDeterministicUuid('room:$salaNormalizada:$codigoLocalSap');
          roomIdsEsperados.add(ridLoc);
          mapaRoomIdParaSala[ridLoc] = salaNormalizada;
        }

        // Adiciona fallback direto gerado a partir da sala normalizada
        final ridFallback = Room.generateDeterministicUuid('room:$salaNormalizada');
        roomIdsEsperados.add(ridFallback);
        mapaRoomIdParaSala[ridFallback] = salaNormalizada;

        // Se existir a tabela rooms no banco, verifica se há registro por nome
        try {
          final roomsDb = await _supabase
              .from('rooms')
              .select('id, name')
              .ilike('name', salaNormalizada);
          for (final r in (roomsDb as List)) {
            final id = r['id'] as String?;
            final name = r['name'] as String? ?? salaNormalizada;
            if (id != null) {
              roomIdsEsperados.add(id);
              mapaRoomIdParaSala[id] = name;
            }
          }
        } catch (_) {}
      }

      // 3. Buscar fotografias candidatas em media_images do mesmo Local
      final mediaResponse = await _supabase
          .from('media_images')
          .select()
          .inFilter('local_id', localIds)
          .order('created_at', ascending: false);

      final todasFotos = (mediaResponse as List).map((row) {
        return MediaImage.fromMap(row as Map<String, dynamic>);
      }).toList();

      if (todasFotos.isEmpty) {
        return HistoricoVisualResultado.vazio(
          localNome: localNomePrincipal,
          salaNome: salaNormalizada,
          filtroSalaAplicado: salaNormalizada != null,
        );
      }

      // 4. Classificação com precedência estrita:
      // Se a nota tiver SALA definida:
      // Somente são aceitas fotos da MESMA SALA da Nota!
      // Nível C (fotos de outras salas do ativo) é estritamente descartado.
      final itensA = <HistoricoVisualItem>[];
      final itensB = <HistoricoVisualItem>[];
      final itensC = <HistoricoVisualItem>[];
      final processadosIds = <String>{};

      for (final foto in todasFotos) {
        final eqId = foto.equipmentId;
        final rId = foto.roomId;

        // Se a nota possui sala definida, a foto DEVE pertencer à mesma sala
        if (salaNormalizada != null) {
          bool bateuSala = false;
          String? salaDetectada;

          if (rId != null && roomIdsEsperados.contains(rId)) {
            bateuSala = true;
            salaDetectada = mapaRoomIdParaSala[rId] ?? salaNormalizada;
          } else if (foto.roomName != null && normalizarSala(foto.roomName) == salaNormalizada) {
            bateuSala = true;
            salaDetectada = foto.roomName;
          }

          // Se NÃO pertence à mesma sala da nota, descarta
          if (!bateuSala) {
            continue;
          }

          // Se pertence à mesma sala e também coincide com o equipamento exato:
          if (eqId != null &&
              uuidsEquipamentoEsperados.isNotEmpty &&
              uuidsEquipamentoEsperados.contains(eqId)) {
            itensA.add(HistoricoVisualItem(
              mediaImage: foto,
              nivel: HistoricoVisualNivel.equipamento,
              motivoCorrespondencia: 'Mesmo Equipamento SAP ($equipNumero)',
              localNome: localNomePrincipal,
              sala: salaDetectada ?? salaNormalizada,
              equipamento: equipNumero,
              createdAt: foto.createdAt,
            ));
            processadosIds.add(foto.id);
          } else {
            // Pertence à mesma sala da nota (Nível B)
            itensB.add(HistoricoVisualItem(
              mediaImage: foto,
              nivel: HistoricoVisualNivel.sala,
              motivoCorrespondencia: 'Mesma Sala/Estrutura (${salaDetectada ?? salaNormalizada})',
              localNome: localNomePrincipal,
              sala: salaDetectada ?? salaNormalizada,
              createdAt: foto.createdAt,
            ));
            processadosIds.add(foto.id);
          }
        } else {
          // Quando a nota NÃO tem sala especificada no SAP (sala genérica ou ausente):
          // Verifica equipamento primeiro
          if (eqId != null &&
              uuidsEquipamentoEsperados.isNotEmpty &&
              uuidsEquipamentoEsperados.contains(eqId)) {
            itensA.add(HistoricoVisualItem(
              mediaImage: foto,
              nivel: HistoricoVisualNivel.equipamento,
              motivoCorrespondencia: 'Mesmo Equipamento SAP ($equipNumero)',
              localNome: localNomePrincipal,
              equipamento: equipNumero,
              createdAt: foto.createdAt,
            ));
            processadosIds.add(foto.id);
          } else {
            // Fotos do mesmo local em geral (Nível C)
            itensC.add(HistoricoVisualItem(
              mediaImage: foto,
              nivel: HistoricoVisualNivel.local,
              motivoCorrespondencia: 'Mesmo Local ($localNomePrincipal)',
              localNome: localNomePrincipal,
              createdAt: foto.createdAt,
            ));
            processadosIds.add(foto.id);
          }
        }
      }

      // Contadores Globais Totais
      final totalA = itensA.length;
      final totalB = itensB.length;
      final totalC = itensC.length;

      // Aplicar limite de paginação inicial para renderização visual leve (quando não houver sala específica)
      final listaFinal = salaNormalizada != null
          ? <HistoricoVisualItem>[...itensA, ...itensB]
          : <HistoricoVisualItem>[
              ...itensA.take(limitePorNivel),
              ...itensB.take(limitePorNivel),
              ...itensC.take(limitePorNivel),
            ];

      return HistoricoVisualResultado(
        itens: listaFinal,
        totalEquipamento: totalA,
        totalSala: totalB,
        totalLocal: totalC,
        raizSapIdentificada: raizSap,
        localNome: localNomePrincipal,
        salaNome: salaNormalizada,
        filtroSalaAplicado: salaNormalizada != null,
      );
    } catch (e, stack) {
      debugPrint('❌ Erro em NotaHistoricoVisualService.buscarHistoricoVisual: $e\n$stack');
      rethrow;
    }
  }
}

