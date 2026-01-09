class Anexo {
  final String? id;
  final String taskId;
  final String nomeArquivo;
  final String tipoArquivo; // 'imagem', 'video', 'documento'
  final String caminhoArquivo; // Caminho no Supabase Storage
  final int tamanhoBytes;
  final String? mimeType;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Anexo({
    this.id,
    required this.taskId,
    required this.nomeArquivo,
    required this.tipoArquivo,
    required this.caminhoArquivo,
    required this.tamanhoBytes,
    this.mimeType,
    this.createdAt,
    this.updatedAt,
  });

  factory Anexo.fromMap(Map<String, dynamic> map) {
    return Anexo(
      id: map['id'] as String?,
      taskId: map['task_id'] as String,
      nomeArquivo: map['nome_arquivo'] as String,
      tipoArquivo: map['tipo_arquivo'] as String,
      caminhoArquivo: map['caminho_arquivo'] as String,
      tamanhoBytes: map['tamanho_bytes'] as int,
      mimeType: map['mime_type'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'task_id': taskId,
      'nome_arquivo': nomeArquivo,
      'tipo_arquivo': tipoArquivo,
      'caminho_arquivo': caminhoArquivo,
      'tamanho_bytes': tamanhoBytes,
      'mime_type': mimeType,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Anexo copyWith({
    String? id,
    String? taskId,
    String? nomeArquivo,
    String? tipoArquivo,
    String? caminhoArquivo,
    int? tamanhoBytes,
    String? mimeType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Anexo(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      nomeArquivo: nomeArquivo ?? this.nomeArquivo,
      tipoArquivo: tipoArquivo ?? this.tipoArquivo,
      caminhoArquivo: caminhoArquivo ?? this.caminhoArquivo,
      tamanhoBytes: tamanhoBytes ?? this.tamanhoBytes,
      mimeType: mimeType ?? this.mimeType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Método auxiliar para determinar o tipo de arquivo baseado na extensão
  static String getTipoArquivo(String nomeArquivo, {String? mimeType}) {
    final extensao = nomeArquivo.split('.').last.toLowerCase();
    
    // Verificar MIME type primeiro (mais confiável)
    if (mimeType != null) {
      if (mimeType.startsWith('image/')) return 'imagem';
      if (mimeType.startsWith('video/')) return 'video';
      if (mimeType.startsWith('audio/')) return 'audio';
      if (mimeType.startsWith('application/pdf') ||
          mimeType.startsWith('application/msword') ||
          mimeType.startsWith('application/vnd.openxmlformats-officedocument') ||
          mimeType.startsWith('text/')) {
        return 'documento';
      }
    }
    
    // Imagens
    if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg'].contains(extensao)) {
      return 'imagem';
    }
    
    // Vídeos
    if (['mp4', 'avi', 'mov', 'wmv', 'flv', 'webm', 'mkv'].contains(extensao)) {
      return 'video';
    }
    
    // Áudios
    if (['mp3', 'wav', 'ogg', 'm4a', 'aac', 'flac'].contains(extensao)) {
      return 'audio';
    }
    
    // Documentos
    if (['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'csv', 'rtf'].contains(extensao)) {
      return 'documento';
    }
    
    // Outros
    return 'outro';
  }

  // Método auxiliar para obter o ícone baseado no tipo
  static String getIcone(String tipoArquivo) {
    switch (tipoArquivo) {
      case 'imagem':
        return 'image';
      case 'video':
        return 'videocam';
      case 'documento':
        return 'description';
      default:
        return 'attach_file';
    }
  }
}

