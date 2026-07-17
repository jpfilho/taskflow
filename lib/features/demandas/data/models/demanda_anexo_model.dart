class DemandaAnexo {
  final String id;
  final String demandaId;
  final String tipo; // evidencia_antes, evidencia_depois, anexo_geral
  final String fileName;
  final String filePath;
  final String? fileUrl;
  final String? mimeType;
  final int? fileSize;
  final String? createdBy;
  final DateTime? createdAt;

  DemandaAnexo({
    required this.id,
    required this.demandaId,
    required this.tipo,
    required this.fileName,
    required this.filePath,
    this.fileUrl,
    this.mimeType,
    this.fileSize,
    this.createdBy,
    this.createdAt,
  });

  factory DemandaAnexo.fromMap(Map<String, dynamic> map) {
    return DemandaAnexo(
      id: map['id'] as String,
      demandaId: map['demanda_id'] as String,
      tipo: map['tipo'] as String,
      fileName: map['file_name'] as String,
      filePath: map['file_path'] as String,
      fileUrl: map['file_url'] as String?,
      mimeType: map['mime_type'] as String?,
      fileSize: map['file_size'] != null ? (map['file_size'] as num).toInt() : null,
      createdBy: map['created_by'] as String?,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'demanda_id': demandaId,
      'tipo': tipo,
      'file_name': fileName,
      'file_path': filePath,
      'file_url': fileUrl,
      'mime_type': mimeType,
      'file_size': fileSize,
    };
    if (id.isNotEmpty) {
      map['id'] = id;
    }
    if (createdBy != null) {
      map['created_by'] = createdBy;
    }
    return map;
  }
}
