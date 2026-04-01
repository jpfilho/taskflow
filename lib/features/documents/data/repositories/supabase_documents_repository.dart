
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../config/supabase_config.dart';
import '../../../media_albums/data/models/equipment.dart';
import '../../../media_albums/data/models/room.dart';
import '../../../media_albums/data/models/segment.dart';
import '../../util/path_builder.dart';
import '../models/document.dart';
import '../models/document_status.dart';
import '../models/document_version.dart';

class SupabaseDocumentsRepository {
  final SupabaseClient _supabase = SupabaseConfig.client;

  // ============================================
  // Hierarquia (reaproveita lógica de mídia)
  // ============================================

  Future<List<Segment>> getSegments({List<String>? userSegmentoIds}) async {
    try {
      // Tenta tabela segments do módulo
      final response = await _supabase.from('segments').select().order('name');
      var segments = (response as List)
          .map((e) => Segment.fromMap(e as Map<String, dynamic>))
          .toList();
      if (segments.isNotEmpty) {
        if (userSegmentoIds != null && userSegmentoIds.isNotEmpty) {
          segments = segments
              .where((s) =>
                  s.segmentoId != null && userSegmentoIds.contains(s.segmentoId))
              .toList();
        }
        return segments;
      }
    } catch (e) {
      debugPrint('⚠️ getSegments (segments) fallback: $e');
    }

    // Fallback para tabela do sistema
    try {
      var query = _supabase.from('segmentos').select('id, segmento');
      if (userSegmentoIds != null && userSegmentoIds.isNotEmpty) {
        query = query.inFilter('id', userSegmentoIds);
      }
      final response = await query.order('segmento');
      return (response as List)
          .map((e) => Segment(
                id: e['id'] as String,
                name: e['segmento'] as String,
                segmentoId: e['id'] as String,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ))
          .toList();
    } catch (e) {
      debugPrint('❌ getSegments fallback erro: $e');
      rethrow;
    }
  }

  Future<List<Equipment>> getEquipments({
    List<String>? userLocalNames,
  }) async {
    if (userLocalNames != null && userLocalNames.isEmpty) return [];
    try {
      var query = _supabase
          .from('equipamentos_sap')
          .select('local_instalacao, localizacao, equipamento')
          .or('localizacao.not.is.null,local_instalacao.not.is.null');

      if (userLocalNames != null && userLocalNames.isNotEmpty) {
        final sap = userLocalNames.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        if (sap.length == 1) {
          query = query.ilike('local_instalacao', '%${sap.first}%');
        } else if (sap.isNotEmpty) {
          query = query.or(sap.map((v) => 'local_instalacao.ilike.%$v%').join(','));
        }
      }

      final response = await query;
      final uniq = <String, Equipment>{};
      for (final row in response) {
        final loc = (row['localizacao'] as String?)?.trim();
        if (loc != null && loc.isNotEmpty) {
          uniq.putIfAbsent(
            loc,
            () => Equipment.fromEquipamentosSap(
              loc,
              equipamento: (row['equipamento'] as String?)?.trim(),
              localInstalacao: (row['local_instalacao'] as String?)?.trim(),
            ),
          );
        }
      }
      final list = uniq.values.toList()..sort((a, b) => a.name.compareTo(b.name));
      return list;
    } catch (e) {
      debugPrint('❌ getEquipments erro: $e');
      rethrow;
    }
  }

  Future<List<Room>> getRooms({
    String? localizacao,
    List<String>? userLocalNames,
  }) async {
    if (userLocalNames != null && userLocalNames.isEmpty) return [];
    try {
      var query = _supabase
          .from('equipamentos_sap')
          .select('sala, local_instalacao, localizacao')
          .or('sala.not.is.null,localizacao.not.is.null');
      if (localizacao != null && localizacao.trim().isNotEmpty) {
        query = query.ilike('localizacao', '%${localizacao.trim()}%');
      }
      if (userLocalNames != null && userLocalNames.isNotEmpty) {
        final sap = userLocalNames.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        if (sap.length == 1) {
          query = query.ilike('local_instalacao', '%${sap.first}%');
        } else if (sap.isNotEmpty) {
          query = query.or(sap.map((v) => 'local_instalacao.ilike.%$v%').join(','));
        }
      }
      final response = await query;
      final uniq = <String, Room>{};
      for (final row in response) {
        final sala = (row['sala'] as String?)?.trim();
        final loc = (row['localizacao'] as String?)?.trim();
        final locInst = (row['local_instalacao'] as String?)?.trim();
        if (sala != null && sala.isNotEmpty) {
          final keyBase = loc ?? locInst ?? '';
          final key = 'room:${sala}_$keyBase';
          uniq.putIfAbsent(
            key,
            () => Room.fromEquipamentosSap(
              sala,
              loc ?? locInst ?? '',
            ),
          );
        }
      }
      final list = uniq.values.toList()..sort((a, b) => a.name.compareTo(b.name));
      return list;
    } catch (e) {
      debugPrint('❌ getRooms erro: $e');
      rethrow;
    }
  }

  // ============================================
  // Status
  // ============================================

  Future<List<DocumentStatus>> listStatuses() async {
    final res = await _supabase.from('status_documents').select().order('ordem');
    return (res as List)
        .map((e) => DocumentStatus.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // ============================================
  // Listagem com filtros e busca
  // ============================================

  Future<Map<String, dynamic>> getDocuments({
    int page = 0,
    int pageSize = 20,
    String? searchQuery,
    String? segmentId,
    String? equipmentId,
    List<String>? equipmentIds,
    String? roomId,
    String? statusDocumentId,
    String? regionalId,
    String? divisaoId,
    String? localId,
    String? orderBy = 'created_at',
    bool descending = true,
    List<String>? userRegionalIds,
    List<String>? userDivisaoIds,
    List<String>? userSegmentoIds,
  }) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;
    final hasSearch = searchQuery != null && searchQuery.trim().isNotEmpty;
    final searchLower = hasSearch ? searchQuery.trim().toLowerCase() : '';

    var query = _supabase.from('documents').select();

    if (segmentId != null) query = query.eq('segment_id', segmentId);
    if (equipmentIds != null && equipmentIds.isNotEmpty) {
      query = query.inFilter('equipment_id', equipmentIds);
    } else if (equipmentId != null) {
      query = query.eq('equipment_id', equipmentId);
    }
    if (roomId != null) query = query.eq('room_id', roomId);
    if (statusDocumentId != null) query = query.eq('status_document_id', statusDocumentId);
    if (regionalId != null) query = query.eq('regional_id', regionalId);
    if (divisaoId != null) query = query.eq('divisao_id', divisaoId);
    if (localId != null) query = query.eq('local_id', localId);
    if (userRegionalIds != null && userRegionalIds.isNotEmpty) {
      query = query.inFilter('regional_id', userRegionalIds);
    }
    if (userDivisaoIds != null && userDivisaoIds.isNotEmpty) {
      query = query.inFilter('divisao_id', userDivisaoIds);
    }
    if (userSegmentoIds != null && userSegmentoIds.isNotEmpty) {
      query = query.inFilter('segment_id', userSegmentoIds);
    }

    List<Document> docs;
    int total;

    if (hasSearch) {
      const searchLimit = 200;
      final resp = await query
          .order(orderBy ?? 'created_at', ascending: !descending)
          .range(0, searchLimit - 1);
      final parsed = (resp as List)
          .map((e) => Document.fromMap(e as Map<String, dynamic>))
          .toList();
      final filtered = parsed.where((d) {
        final inTitle = d.title.toLowerCase().contains(searchLower);
        final inDesc = (d.description ?? '').toLowerCase().contains(searchLower);
        final inTags = d.tags.any((t) => t.toLowerCase().contains(searchLower));
        return inTitle || inDesc || inTags;
      }).toList();
      total = filtered.length;
      final start = from.clamp(0, total);
      final end = (from + pageSize).clamp(0, total);
      docs = start < end ? filtered.sublist(start, end) : [];
    } else {
      final resp = await query
          .order(orderBy ?? 'created_at', ascending: !descending)
          .range(from, to);
      docs = (resp as List)
          .map((e) => Document.fromMap(e as Map<String, dynamic>))
          .toList();
      final hasMore = docs.length == pageSize;
      total = hasMore ? (page + 1) * pageSize + 1 : page * pageSize + docs.length;
    }

    final enriched = await _enrichDocuments(docs);

    return {
      'documents': enriched,
      'total': total,
      'page': page,
      'pageSize': pageSize,
    };
  }

  // ============================================
  // Detalhe
  // ============================================

  Future<Document> getDocumentById(String id) async {
    final resp = await _supabase.from('documents').select().eq('id', id).maybeSingle();
    if (resp == null) throw Exception('Documento não encontrado');
    final doc = Document.fromMap(resp);
    final enriched = await _enrichDocuments([doc]);
    // Buscar versões
    final versionsResp = await _supabase
        .from('document_versions')
        .select()
        .eq('document_id', id)
        .order('version', ascending: false);
    final versions = (versionsResp as List)
        .map((e) => DocumentVersion.fromMap(e as Map<String, dynamic>))
        .toList();
    return enriched.first.copyWith(versions: versions);
  }

  // ============================================
  // Criação e versão
  // ============================================

  Future<Document> createDocument(Document document) async {
    final response = await _supabase
        .from('documents')
        .insert(document.toInsertMap())
        .select()
        .single();
    return Document.fromMap(response);
  }

  Future<DocumentVersion> createVersion({
    required String documentId,
    required DocumentFile file,
    required int version,
    required String createdBy,
  }) async {
    final payload = {
      'document_id': documentId,
      'version': version,
      'file_path': file.path,
      'file_url': file.url,
      'mime_type': file.mimeType,
      'file_size': file.size,
      'checksum': file.checksum,
      'created_by': createdBy,
    };
    final resp = await _supabase
        .from('document_versions')
        .insert(payload)
        .select()
        .single();
    // Atualizar documento principal com nova versão
    await _supabase.from('documents').update({
      'file_path': file.path,
      'file_url': file.url,
      'mime_type': file.mimeType,
      'file_size': file.size,
      'file_ext': file.extension,
      'checksum': file.checksum,
    }).eq('id', documentId);
    return DocumentVersion.fromMap(resp);
  }

  /// Upload + criação de documento em uma chamada.
  Future<Document> uploadAndCreateDocument({
    required String userId,
    required List<int> fileBytes,
    required String fileName,
    required String mimeType,
    required String title,
    String? description,
    List<String> tags = const [],
    String? regionalId,
    String? divisaoId,
    String? segmentId,
    String? localId,
    String? equipmentId,
    String? roomId,
    String? statusDocumentId,
    String? checksum,
  }) async {
    final ext = _extractExtension(fileName);
    final path = PathBuilderDocuments.buildDocumentPath(
      userId: userId,
      segmentId: segmentId,
      equipmentId: equipmentId,
      roomId: roomId,
      extension: ext,
    );
    final signedUrl = await uploadFile(
      path: path,
      bytes: fileBytes,
      mimeType: mimeType,
    );

    // Garantir que o segment_id exista na tabela segments (módulo local) quando vier do perfil (segmentos)
    String? finalSegmentId = segmentId;
    if (segmentId != null) {
      finalSegmentId = await _ensureSegmentExists(segmentId);
    }

    final doc = Document(
      id: '',
      regionalId: regionalId,
      divisaoId: divisaoId,
      segmentId: finalSegmentId,
      localId: localId,
      equipmentId: equipmentId,
      roomId: roomId,
      title: title,
      description: description,
      tags: tags,
      file: DocumentFile(
        path: path,
        url: signedUrl,
        mimeType: mimeType,
        size: fileBytes.length,
        checksum: checksum,
        extension: ext,
      ),
      thumbPath: null,
      statusDocumentId: statusDocumentId,
      statusDocument: null,
      createdBy: userId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final created = await createDocument(doc);
    // Criar versão inicial
    await createVersion(
      documentId: created.id,
      file: doc.file,
      version: 1,
      createdBy: userId,
    );
    return created.copyWith(
      file: doc.file,
      statusDocumentId: statusDocumentId,
    );
  }

  /// Upload de nova versão: gera path, envia, cria linha em document_versions e atualiza documents.
  Future<DocumentVersion> uploadNewVersion({
    required Document document,
    required List<int> fileBytes,
    required String fileName,
    required String mimeType,
    String? checksum,
  }) async {
    final ext = _extractExtension(fileName);
    final path = PathBuilderDocuments.buildDocumentPath(
      userId: document.createdBy,
      segmentId: document.segmentId,
      equipmentId: document.equipmentId,
      roomId: document.roomId,
      extension: ext,
    );
    final signedUrl = await uploadFile(
      path: path,
      bytes: fileBytes,
      mimeType: mimeType,
    );
    final nextVersion = await _nextVersion(document.id);
    final file = DocumentFile(
      path: path,
      url: signedUrl,
      mimeType: mimeType,
      size: fileBytes.length,
      checksum: checksum,
      extension: ext,
    );
    return createVersion(
      documentId: document.id,
      file: file,
      version: nextVersion,
      createdBy: document.createdBy,
    );
  }

  // ============================================
  // Storage helpers
  // ============================================

  Future<String> uploadFile({
    required String path,
    required List<int> bytes,
    required String mimeType,
    bool upsert = false,
  }) async {
    await _supabase.storage
        .from(PathBuilderDocuments.bucketName)
        .uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(
            contentType: mimeType,
            upsert: upsert,
          ),
        );
    // Signed URL de 1 ano
    final signedUrl = await _supabase.storage
        .from(PathBuilderDocuments.bucketName)
        .createSignedUrl(path, 31536000);
    return signedUrl;
  }

  String getPublicUrl(String path) {
    return _supabase.storage
        .from(PathBuilderDocuments.bucketName)
        .getPublicUrl(path);
  }

  // ============================================
  // Helpers
  // ============================================

  String _extractExtension(String fileName) {
    if (!fileName.contains('.')) return 'bin';
    return fileName.split('.').last;
  }

  Future<String?> _ensureSegmentExists(String segmentId) async {
    try {
      // Já existe na tabela segments?
      final existing = await _supabase
          .from('segments')
          .select('id')
          .eq('id', segmentId)
          .maybeSingle();
      if (existing != null) return segmentId;

      // Tentar buscar nome na tabela segmentos (do sistema)
      String segmentName = 'Segmento $segmentId';
      try {
        final segmento = await _supabase
            .from('segmentos')
            .select('segmento')
            .eq('id', segmentId)
            .maybeSingle();
        if (segmento != null && segmento['segmento'] != null) {
          segmentName = segmento['segmento'] as String;
        }
      } catch (_) {}

      // Inserir em segments para satisfazer FK
      try {
        final resp = await _supabase
            .from('segments')
            .insert({'id': segmentId, 'name': segmentName})
            .select('id')
            .single();
        return resp['id'] as String;
      } catch (_) {
        // Se não conseguir inserir, devolve null para não violar FK
        return null;
      }
    } catch (_) {
      // Se não conseguimos garantir, devolve null para não violar FK
      return null;
    }
  }

  Future<int> _nextVersion(String documentId) async {
    final resp = await _supabase
        .from('document_versions')
        .select('version')
        .eq('document_id', documentId)
        .order('version', ascending: false)
        .limit(1);
    if (resp.isNotEmpty) {
      final v = (resp.first['version'] as int?) ?? 1;
      return v + 1;
    }
    return 1;
  }

  // ============================================
  // Enriquecimento (nomes e status)
  // ============================================

  Future<List<Document>> _enrichDocuments(List<Document> docs) async {
    if (docs.isEmpty) return [];

    final regionalIds = docs.where((d) => d.regionalId != null).map((d) => d.regionalId!).toSet();
    final divisaoIds = docs.where((d) => d.divisaoId != null).map((d) => d.divisaoId!).toSet();
    final segmentIds = docs.where((d) => d.segmentId != null).map((d) => d.segmentId!).toSet();
    final localIds = docs.where((d) => d.localId != null).map((d) => d.localId!).toSet();
    final equipmentIds = docs.where((d) => d.equipmentId != null).map((d) => d.equipmentId!).toSet();
    final roomIds = docs.where((d) => d.roomId != null).map((d) => d.roomId!).toSet();
    final statusIds = docs.where((d) => d.statusDocumentId != null).map((d) => d.statusDocumentId!).toSet();
    final creatorIds = docs.map((d) => d.createdBy).toSet();

    final regionalMap = <String, String>{};
    final divisaoMap = <String, String>{};
    final segmentMap = <String, String>{};
    final localMap = <String, String>{};
    final equipmentMap = <String, String>{};
    final roomMap = <String, String>{};
    final statusMap = <String, DocumentStatus>{};
    final creatorMap = <String, String>{};

    try {
      if (regionalIds.isNotEmpty) {
        final res = await _supabase
            .from('regionais')
            .select('id, regional')
            .inFilter('id', regionalIds.toList());
        for (final r in res) {
          regionalMap[r['id'] as String] = r['regional'] as String;
        }
      }
    } catch (_) {}

    try {
      if (divisaoIds.isNotEmpty) {
        final res = await _supabase
            .from('divisoes')
            .select('id, divisao')
            .inFilter('id', divisaoIds.toList());
        for (final d in res) {
          divisaoMap[d['id'] as String] = d['divisao'] as String;
        }
      }
    } catch (_) {}

    // segments (tabela local)
    try {
      if (segmentIds.isNotEmpty) {
        final res = await _supabase
            .from('segments')
            .select('id, name')
            .inFilter('id', segmentIds.toList());
        for (final s in res) {
          segmentMap[s['id'] as String] = s['name'] as String;
        }
      }
    } catch (_) {}

    // fallback segmentos
    try {
      final missing = segmentIds.where((id) => !segmentMap.containsKey(id)).toList();
      if (missing.isNotEmpty) {
        final res = await _supabase
            .from('segmentos')
            .select('id, segmento')
            .inFilter('id', missing);
        for (final s in res) {
          segmentMap[s['id'] as String] = s['segmento'] as String;
        }
      }
    } catch (_) {}

    try {
      if (localIds.isNotEmpty) {
        final res = await _supabase
            .from('locais')
            .select('id, local')
            .inFilter('id', localIds.toList());
        for (final l in res) {
          localMap[l['id'] as String] = l['local'] as String;
        }
      }
    } catch (_) {}

    // equipments: tabela local e fallback equipamentos_sap
    try {
      if (equipmentIds.isNotEmpty) {
        final res = await _supabase
            .from('equipments')
            .select('id, name')
            .inFilter('id', equipmentIds.toList());
        for (final e in res) {
          equipmentMap[e['id'] as String] = e['name'] as String;
        }
      }
    } catch (_) {}
    try {
      final missing = equipmentIds.where((id) => !equipmentMap.containsKey(id)).toList();
      if (missing.isNotEmpty) {
        final res = await _supabase
            .from('equipamentos_sap')
            .select('localizacao, local_instalacao')
            .or('localizacao.not.is.null,local_instalacao.not.is.null');
        for (final row in res) {
          final loc = (row['localizacao'] as String?)?.trim();
          if (loc != null && loc.isNotEmpty) {
            final generated = Equipment.generateDeterministicUuid('equipment:$loc');
            if (missing.contains(generated) && !equipmentMap.containsKey(generated)) {
              final locInst = (row['local_instalacao'] as String?)?.trim();
              equipmentMap[generated] = (locInst != null && locInst.isNotEmpty && locInst != loc)
                  ? '$loc ($locInst)'
                  : loc;
            }
          }
        }
      }
    } catch (_) {}

    // rooms: tabela local + fallback equipamentos_sap
    try {
      if (roomIds.isNotEmpty) {
        final res = await _supabase
            .from('rooms')
            .select('id, name')
            .inFilter('id', roomIds.toList());
        for (final r in res) {
          roomMap[r['id'] as String] = r['name'] as String;
        }
      }
    } catch (_) {}
    try {
      final missing = roomIds.where((id) => !roomMap.containsKey(id)).toList();
      if (missing.isNotEmpty) {
        final res = await _supabase
            .from('equipamentos_sap')
            .select('sala, localizacao, local_instalacao')
            .or('sala.not.is.null,localizacao.not.is.null');
        for (final row in res) {
          final sala = (row['sala'] as String?)?.trim();
          final loc = (row['localizacao'] as String?)?.trim();
          final locInst = (row['local_instalacao'] as String?)?.trim();
          if (sala != null && sala.isNotEmpty) {
            if (loc != null && loc.isNotEmpty) {
              final gen = Room.generateDeterministicUuid('room:$sala:$loc');
              if (missing.contains(gen)) roomMap[gen] = sala;
            }
            if (locInst != null && locInst.isNotEmpty) {
              final gen = Room.generateDeterministicUuid('room:$sala:$locInst');
              if (missing.contains(gen)) roomMap[gen] = sala;
            }
          }
        }
      }
    } catch (_) {}

    try {
      if (statusIds.isNotEmpty) {
        final res = await _supabase
            .from('status_documents')
            .select()
            .inFilter('id', statusIds.toList());
        for (final s in res) {
          final status = DocumentStatus.fromMap(s);
          statusMap[status.id] = status;
        }
      }
    } catch (_) {}

    try {
      if (creatorIds.isNotEmpty) {
        final res = await _supabase
            .from('usuarios')
            .select('id, nome')
            .inFilter('id', creatorIds.toList());
        for (final c in res) {
          if (c['nome'] != null) {
            creatorMap[c['id'] as String] = c['nome'] as String;
          }
        }
      }
    } catch (_) {}

    return docs
        .map((d) => d.copyWith(
              regionalName: d.regionalId != null ? regionalMap[d.regionalId] : null,
              divisaoName: d.divisaoId != null ? divisaoMap[d.divisaoId] : null,
              segmentName: d.segmentId != null ? segmentMap[d.segmentId] : null,
              localName: d.localId != null ? localMap[d.localId] : null,
              equipmentName: d.equipmentId != null ? equipmentMap[d.equipmentId] : null,
              roomName: d.roomId != null ? roomMap[d.roomId] : null,
              statusDocument: d.statusDocumentId != null ? statusMap[d.statusDocumentId] : null,
              creatorName: creatorMap[d.createdBy],
            ))
        .toList();
  }
}
