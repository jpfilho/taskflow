class DemandAttachment {
  final String id;
  final String demandaId;
  final String url; // storage path or public URL
  final String? nome;
  final int? tamanhoBytes;
  final String? contentType;
  final DateTime? criadoEm;
  final String? criadoPor;

  DemandAttachment({
    required this.id,
    required this.demandaId,
    required this.url,
    this.nome,
    this.tamanhoBytes,
    this.contentType,
    this.criadoEm,
    this.criadoPor,
  });

  factory DemandAttachment.fromMap(Map<String, dynamic> map) {
    DateTime? dt(dynamic v) => v == null ? null : DateTime.parse(v as String);
    return DemandAttachment(
      id: map['id'] as String,
      demandaId: map['demanda_id'] as String,
      url: map['url'] as String,
      nome: map['nome'] as String?,
      tamanhoBytes: map['tamanho_bytes'] as int?,
      contentType: map['content_type'] as String?,
      criadoEm: dt(map['criado_em']),
      criadoPor: map['criado_por'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'demanda_id': demandaId,
        'url': url,
        'nome': nome,
        'tamanho_bytes': tamanhoBytes,
        'content_type': contentType,
        'criado_em': criadoEm?.toIso8601String(),
        'criado_por': criadoPor,
      };
}
