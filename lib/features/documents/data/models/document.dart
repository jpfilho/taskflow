import 'document_status.dart';
import 'document_version.dart';

class DocumentFile {
  final String path;
  final String? url;
  final String mimeType;
  final int? size;
  final String? checksum;
  final String? extension;

  const DocumentFile({
    required this.path,
    required this.mimeType,
    this.url,
    this.size,
    this.checksum,
    this.extension,
  });
}

class Document {
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

  final DocumentFile file;
  final String? thumbPath;

  final String? statusDocumentId;
  final DocumentStatus? statusDocument;

  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Campos enriquecidos
  final String? regionalName;
  final String? divisaoName;
  final String? segmentName;
  final String? localName;
  final String? equipmentName;
  final String? roomName;
  final String? creatorName;

  final List<DocumentVersion>? versions;

  const Document({
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
    required this.file,
    this.thumbPath,
    this.statusDocumentId,
    this.statusDocument,
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
    this.versions,
  });

  static List<String> _parseTags(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value
          .map((e) => e?.toString().trim() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (value is String) {
      final s = value.trim();
      if (s.isEmpty || s == '{}') return [];
      if (s.startsWith('{') && s.endsWith('}')) {
        final inner = s.substring(1, s.length - 1);
        if (inner.isEmpty) return [];
        return inner
            .split(',')
            .map((e) => e.trim().replaceAll('"', ''))
            .where((x) => x.isNotEmpty)
            .toList();
      }
      return [s];
    }
    return [];
  }

  factory Document.fromMap(Map<String, dynamic> map) {
    final versionsList = map['versions'] as List<dynamic>?;
    return Document(
      id: map['id'] as String,
      regionalId: map['regional_id'] as String?,
      divisaoId: map['divisao_id'] as String?,
      segmentId: map['segment_id'] as String?,
      localId: map['local_id'] as String?,
      equipmentId: map['equipment_id'] as String?,
      roomId: map['room_id'] as String?,
      title: map['title'] as String,
      description: map['description'] as String?,
      tags: _parseTags(map['tags']),
      file: DocumentFile(
        path: map['file_path'] as String,
        url: map['file_url'] as String?,
        mimeType: map['mime_type'] as String,
        size: (map['file_size'] as num?)?.toInt(),
        checksum: map['checksum'] as String?,
        extension: map['file_ext'] as String?,
      ),
      thumbPath: map['thumb_path'] as String?,
      statusDocumentId: map['status_document_id'] as String?,
      statusDocument: map['status_document'] != null
          ? DocumentStatus.fromMap(map['status_document'] as Map<String, dynamic>)
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
      versions: versionsList?.map((e) => DocumentVersion.fromMap(e as Map<String, dynamic>)).toList(),
    );
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
      'mime_type': file.mimeType,
      'file_size': file.size,
      'file_ext': file.extension,
      'checksum': file.checksum,
      'file_path': file.path,
      'file_url': file.url,
      'thumb_path': thumbPath,
      if (statusDocumentId != null) 'status_document_id': statusDocumentId,
      'created_by': createdBy,
    };
  }

  Document copyWith({
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
    DocumentFile? file,
    String? thumbPath,
    String? statusDocumentId,
    DocumentStatus? statusDocument,
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
    List<DocumentVersion>? versions,
  }) {
    return Document(
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
      file: file ?? this.file,
      thumbPath: thumbPath ?? this.thumbPath,
      statusDocumentId: statusDocumentId ?? this.statusDocumentId,
      statusDocument: statusDocument ?? this.statusDocument,
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
      versions: versions ?? this.versions,
    );
  }

  String? get displayUrl => file.url;

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
