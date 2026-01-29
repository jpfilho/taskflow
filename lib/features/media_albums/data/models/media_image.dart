import 'status_album.dart';

enum MediaImageStatus {
  ok,
  attention,
  review;

  static MediaImageStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'ok':
        return MediaImageStatus.ok;
      case 'attention':
        return MediaImageStatus.attention;
      case 'review':
      default:
        return MediaImageStatus.review;
    }
  }

  String toValue() {
    switch (this) {
      case MediaImageStatus.ok:
        return 'ok';
      case MediaImageStatus.attention:
        return 'attention';
      case MediaImageStatus.review:
        return 'review';
    }
  }

  String get displayName {
    switch (this) {
      case MediaImageStatus.ok:
        return 'OK';
      case MediaImageStatus.attention:
        return 'Atenção';
      case MediaImageStatus.review:
        return 'Revisão';
    }
  }
}

class MediaImage {
  final String id;
  final String? regionalId;
  final String? divisaoId;
  final String? segmentId;
  final String? localId;
  final String? equipmentId;
  final String? roomId;
  final String title;
  final String? description;
  final List<String> tags;
  final MediaImageStatus status; // Mantido para compatibilidade
  final String? statusAlbumId; // ID do status na tabela status_albums
  final String filePath;
  final String? fileUrl;
  final String? thumbPath;
  /// Path no storage da imagem exportada com anotações (PNG). Original intacta.
  final String? annotatedFilePath;
  /// URL pública da imagem anotada (preenchida pelo repositório a partir de annotatedFilePath).
  final String? annotatedFileUrl;
  final DateTime? annotatedUpdatedAt;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Campos opcionais para joins (não vêm do banco diretamente)
  final String? regionalName;
  final String? divisaoName;
  final String? segmentName;
  final String? localName;
  final String? equipmentName;
  final String? roomName;
  final String? creatorName;
  /// Nome do usuário que fez as anotações (media_annotations.created_by).
  final String? annotatorName;
  final StatusAlbum? statusAlbum; // Objeto completo do status

  MediaImage({
    required this.id,
    this.regionalId,
    this.divisaoId,
    this.segmentId,
    this.localId,
    this.equipmentId,
    this.roomId,
    required this.title,
    this.description,
    this.tags = const [],
    this.status = MediaImageStatus.review,
    this.statusAlbumId,
    required this.filePath,
    this.fileUrl,
    this.thumbPath,
    this.annotatedFilePath,
    this.annotatedFileUrl,
    this.annotatedUpdatedAt,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.regionalName,
    this.divisaoName,
    this.segmentName,
    this.localName,
    this.equipmentName,
    this.roomName,
    this.creatorName,
    this.annotatorName,
    this.statusAlbum,
  });

  /// Converte tags do banco (List, String PostgreSQL array ou null) para List<String>.
  static List<String> _parseTags(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e?.toString().trim() ?? '').where((s) => s.isNotEmpty).toList();
    }
    if (value is String) {
      final s = value.trim();
      if (s.isEmpty || s == '{}') return [];
      // Formato PostgreSQL: {"tag1","tag2"} ou {"tag1"}
      if (s.startsWith('{') && s.endsWith('}')) {
        final inner = s.substring(1, s.length - 1);
        if (inner.isEmpty) return [];
        return inner.split(',').map((e) => e.trim().replaceAll('"', '')).where((x) => x.isNotEmpty).toList();
      }
      return [s];
    }
    return [];
  }

  factory MediaImage.fromMap(Map<String, dynamic> map) {
    return MediaImage(
      id: map['id'] as String,
      regionalId: map['regional_id'] as String?,
      divisaoId: map['divisao_id'] as String?,
      segmentId: map['segment_id'] as String?,
      localId: map['local_id'] as String?,
      equipmentId: map['equipment_id'] as String?,
      roomId: map['room_id'] as String?,
      title: map['title'] as String,
      description: map['description'] as String?,
      tags: MediaImage._parseTags(map['tags']),
      status: MediaImageStatus.fromString(map['status'] as String? ?? 'review'),
      statusAlbumId: map['status_album_id'] as String?,
      filePath: map['file_path'] as String,
      fileUrl: map['file_url'] as String?,
      thumbPath: map['thumb_path'] as String?,
      annotatedFilePath: map['annotated_file_path'] as String?,
      annotatedFileUrl: null, // preenchido pelo repositório via getPublicUrl
      annotatedUpdatedAt: map['annotated_updated_at'] != null
          ? DateTime.tryParse(map['annotated_updated_at'] as String)
          : null,
      createdBy: map['created_by'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      regionalName: map['regional_name'] as String?,
      divisaoName: map['divisao_name'] as String?,
      segmentName: map['segment_name'] as String?,
      localName: map['local_name'] as String?,
      equipmentName: map['equipment_name'] as String?,
      roomName: map['room_name'] as String?,
      creatorName: map['creator_name'] as String?,
      annotatorName: map['annotator_name'] as String?,
      statusAlbum: map['status_albums'] != null
          ? StatusAlbum.fromMap(map['status_albums'] as Map<String, dynamic>)
          : null,
    );
  }

  /// URL para exibição: preferir imagem com anotações quando existir.
  String? get displayUrl => annotatedFileUrl ?? fileUrl;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'regional_id': regionalId,
      'divisao_id': divisaoId,
      'segment_id': segmentId,
      if (localId != null) 'local_id': localId,
      'equipment_id': equipmentId,
      'room_id': roomId,
      'title': title,
      'description': description,
      'tags': tags,
      'status': status.toValue(), // Mantido para compatibilidade
      if (statusAlbumId != null) 'status_album_id': statusAlbumId,
      'file_path': filePath,
      'file_url': fileUrl,
      'thumb_path': thumbPath,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'regional_id': regionalId,
      'divisao_id': divisaoId,
      'segment_id': segmentId,
      if (localId != null) 'local_id': localId,
      'equipment_id': equipmentId,
      'room_id': roomId,
      'title': title,
      'description': description,
      'tags': tags,
      'status': status.toValue(), // Mantido para compatibilidade
      if (statusAlbumId != null) 'status_album_id': statusAlbumId,
      'file_path': filePath,
      'file_url': fileUrl,
      'thumb_path': thumbPath,
      'created_by': createdBy,
    };
  }

  MediaImage copyWith({
    String? id,
    String? regionalId,
    String? divisaoId,
    String? segmentId,
    String? localId,
    String? equipmentId,
    String? roomId,
    String? title,
    String? description,
    List<String>? tags,
    MediaImageStatus? status,
    String? statusAlbumId,
    String? filePath,
    String? fileUrl,
    String? thumbPath,
    String? annotatedFilePath,
    String? annotatedFileUrl,
    DateTime? annotatedUpdatedAt,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? regionalName,
    String? divisaoName,
    String? segmentName,
    String? localName,
    String? equipmentName,
    String? roomName,
    String? creatorName,
    String? annotatorName,
    StatusAlbum? statusAlbum,
  }) {
    return MediaImage(
      id: id ?? this.id,
      regionalId: regionalId ?? this.regionalId,
      divisaoId: divisaoId ?? this.divisaoId,
      segmentId: segmentId ?? this.segmentId,
      localId: localId ?? this.localId,
      equipmentId: equipmentId ?? this.equipmentId,
      roomId: roomId ?? this.roomId,
      title: title ?? this.title,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      status: status ?? this.status,
      statusAlbumId: statusAlbumId ?? this.statusAlbumId,
      filePath: filePath ?? this.filePath,
      fileUrl: fileUrl ?? this.fileUrl,
      thumbPath: thumbPath ?? this.thumbPath,
      annotatedFilePath: annotatedFilePath ?? this.annotatedFilePath,
      annotatedFileUrl: annotatedFileUrl ?? this.annotatedFileUrl,
      annotatedUpdatedAt: annotatedUpdatedAt ?? this.annotatedUpdatedAt,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      regionalName: regionalName ?? this.regionalName,
      divisaoName: divisaoName ?? this.divisaoName,
      segmentName: segmentName ?? this.segmentName,
      localName: localName ?? this.localName,
      equipmentName: equipmentName ?? this.equipmentName,
      roomName: roomName ?? this.roomName,
      creatorName: creatorName ?? this.creatorName,
      annotatorName: annotatorName ?? this.annotatorName,
      statusAlbum: statusAlbum ?? this.statusAlbum,
    );
  }

  String get hierarchyPath {
    final parts = <String>[];
    if (regionalName != null) parts.add(regionalName!);
    if (divisaoName != null) parts.add(divisaoName!);
    if (segmentName != null) parts.add(segmentName!);
    if (localName != null) parts.add(localName!);
    if (equipmentName != null) parts.add(equipmentName!);
    if (roomName != null) parts.add(roomName!);
    return parts.join(' > ');
  }
}
