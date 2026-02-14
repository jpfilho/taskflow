class DocumentVersion {
  final String id;
  final String documentId;
  final int version;
  final String filePath;
  final String? fileUrl;
  final String mimeType;
  final int? fileSize;
  final String? checksum;
  final String createdBy;
  final DateTime createdAt;

  DocumentVersion({
    required this.id,
    required this.documentId,
    required this.version,
    required this.filePath,
    this.fileUrl,
    required this.mimeType,
    this.fileSize,
    this.checksum,
    required this.createdBy,
    required this.createdAt,
  });

  factory DocumentVersion.fromMap(Map<String, dynamic> map) {
    return DocumentVersion(
      id: map['id'] as String,
      documentId: map['document_id'] as String,
      version: map['version'] as int? ?? 1,
      filePath: map['file_path'] as String,
      fileUrl: map['file_url'] as String?,
      mimeType: map['mime_type'] as String,
      fileSize: (map['file_size'] as num?)?.toInt(),
      checksum: map['checksum'] as String?,
      createdBy: map['created_by'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'document_id': documentId,
      'version': version,
      'file_path': filePath,
      'file_url': fileUrl,
      'mime_type': mimeType,
      'file_size': fileSize,
      'checksum': checksum,
      'created_by': createdBy,
    };
  }
}
