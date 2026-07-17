class ChatItemFeedbackAnexo {
  final String id;
  final String feedbackId;
  final String nomeArquivo;
  final String tipoArquivo;
  final String caminhoArquivo;
  final int tamanhoBytes;
  final String? mimeType;
  final String createdBy;
  final DateTime createdAt;
  final String? clientId;

  ChatItemFeedbackAnexo({
    required this.id,
    required this.feedbackId,
    required this.nomeArquivo,
    required this.tipoArquivo,
    required this.caminhoArquivo,
    required this.tamanhoBytes,
    this.mimeType,
    required this.createdBy,
    required this.createdAt,
    this.clientId,
  });

  factory ChatItemFeedbackAnexo.fromMap(Map<String, dynamic> map) {
    return ChatItemFeedbackAnexo(
      id: map['id'] as String,
      feedbackId: map['feedback_id'] as String,
      nomeArquivo: map['nome_arquivo'] as String,
      tipoArquivo: map['tipo_arquivo'] as String,
      caminhoArquivo: map['caminho_arquivo'] as String,
      tamanhoBytes: map['tamanho_bytes'] as int,
      mimeType: map['mime_type'] as String?,
      createdBy: map['created_by'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      clientId: map['client_id'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'feedback_id': feedbackId,
      'nome_arquivo': nomeArquivo,
      'tipo_arquivo': tipoArquivo,
      'caminho_arquivo': caminhoArquivo,
      'tamanho_bytes': tamanhoBytes,
      'mime_type': mimeType,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'client_id': clientId,
    };
  }

  ChatItemFeedbackAnexo copyWith({
    String? id,
    String? feedbackId,
    String? nomeArquivo,
    String? tipoArquivo,
    String? caminhoArquivo,
    int? tamanhoBytes,
    String? mimeType,
    String? createdBy,
    DateTime? createdAt,
    String? clientId,
  }) {
    return ChatItemFeedbackAnexo(
      id: id ?? this.id,
      feedbackId: feedbackId ?? this.feedbackId,
      nomeArquivo: nomeArquivo ?? this.nomeArquivo,
      tipoArquivo: tipoArquivo ?? this.tipoArquivo,
      caminhoArquivo: caminhoArquivo ?? this.caminhoArquivo,
      tamanhoBytes: tamanhoBytes ?? this.tamanhoBytes,
      mimeType: mimeType ?? this.mimeType,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      clientId: clientId ?? this.clientId,
    );
  }
}
