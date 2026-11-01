import 'package:flutter/foundation.dart';

/// Status da Análise Técnica da Nota SAP
/// IMPORTANTE: Informativo e não-bloqueante de programação.
enum NotaAnaliseStatus {
  naoIniciada('nao_iniciada', 'Não iniciada'),
  emAnalise('em_analise', 'Em análise'),
  concluida('concluida', 'Concluída'),
  aguardandoInformacao('aguardando_informacao', 'Aguardando informação'),
  cancelada('cancelada', 'Cancelada');

  final String value;
  final String label;

  const NotaAnaliseStatus(this.value, this.label);

  static NotaAnaliseStatus fromDbString(String? val) {
    if (val == null || val.trim().isEmpty) return NotaAnaliseStatus.naoIniciada;
    final normalized = val.trim().toLowerCase();
    for (final status in NotaAnaliseStatus.values) {
      if (status.value == normalized) return status;
    }
    return NotaAnaliseStatus.naoIniciada;
  }

  String toDbString() => value;
}

/// Status do Material necessário para a execução
enum NotaMaterialStatus {
  naoVerificado('nao_verificado', 'Não verificado'),
  disponivel('disponivel', 'Disponível'),
  reservado('reservado', 'Reservado'),
  aguardandoMaterial('aguardando_material', 'Aguardando material'),
  aguardandoCompra('aguardando_compra', 'Aguardando compra'),
  substituido('substituido', 'Substituído');

  final String value;
  final String label;

  const NotaMaterialStatus(this.value, this.label);

  static NotaMaterialStatus fromDbString(String? val) {
    if (val == null || val.trim().isEmpty) return NotaMaterialStatus.naoVerificado;
    final normalized = val.trim().toLowerCase();
    for (final status in NotaMaterialStatus.values) {
      if (status.value == normalized) return status;
    }
    return NotaMaterialStatus.naoVerificado;
  }

  String toDbString() => value;
}

/// Tipo de Anexo da Nota SAP
enum NotaAnexoTipo {
  imagem('imagem', 'Imagem'),
  video('video', 'Vídeo'),
  pdf('pdf', 'PDF'),
  documento('documento', 'Documento'),
  planilha('planilha', 'Planilha'),
  audio('audio', 'Áudio'),
  outro('outro', 'Outro');

  final String value;
  final String label;

  const NotaAnexoTipo(this.value, this.label);

  static NotaAnexoTipo fromDbString(String? val) {
    if (val == null || val.trim().isEmpty) return NotaAnexoTipo.documento;
    final normalized = val.trim().toLowerCase();
    for (final tipo in NotaAnexoTipo.values) {
      if (tipo.value == normalized) return tipo;
    }
    return NotaAnexoTipo.documento;
  }

  /// Deduz o tipo do arquivo pelo MIME ou extensão
  static NotaAnexoTipo deduzir(String? mimeType, String? nomeArquivo) {
    final mime = (mimeType ?? '').toLowerCase().trim();
    final nome = (nomeArquivo ?? '').toLowerCase().trim();

    if (mime.startsWith('image/') ||
        nome.endsWith('.jpg') ||
        nome.endsWith('.jpeg') ||
        nome.endsWith('.png') ||
        nome.endsWith('.webp') ||
        nome.endsWith('.gif') ||
        nome.endsWith('.bmp')) {
      return NotaAnexoTipo.imagem;
    }

    if (mime == 'application/pdf' || nome.endsWith('.pdf')) {
      return NotaAnexoTipo.pdf;
    }

    if (mime.startsWith('video/') ||
        nome.endsWith('.mp4') ||
        nome.endsWith('.webm') ||
        nome.endsWith('.mov') ||
        nome.endsWith('.avi') ||
        nome.endsWith('.mkv')) {
      return NotaAnexoTipo.video;
    }

    if (mime.startsWith('audio/') ||
        nome.endsWith('.mp3') ||
        nome.endsWith('.wav') ||
        nome.endsWith('.ogg') ||
        nome.endsWith('.m4a') ||
        nome.endsWith('.aac')) {
      return NotaAnexoTipo.audio;
    }

    if (mime.contains('spreadsheet') ||
        mime.contains('excel') ||
        nome.endsWith('.xlsx') ||
        nome.endsWith('.xls') ||
        nome.endsWith('.csv')) {
      return NotaAnexoTipo.planilha;
    }

    if (mime.contains('document') ||
        mime.contains('word') ||
        mime.contains('text/') ||
        nome.endsWith('.docx') ||
        nome.endsWith('.doc') ||
        nome.endsWith('.txt') ||
        nome.endsWith('.rtf')) {
      return NotaAnexoTipo.documento;
    }

    return NotaAnexoTipo.outro;
  }

  String toDbString() => value;
}

/// Tipo de Mensagem na Discussão Técnica
enum NotaComentarioTipo {
  texto('texto'),
  anexoLink('anexo_link'),
  sistema('sistema');

  final String value;

  const NotaComentarioTipo(this.value);

  static NotaComentarioTipo fromDbString(String? val) {
    if (val == null || val.trim().isEmpty) return NotaComentarioTipo.texto;
    final normalized = val.trim().toLowerCase();
    for (final tipo in NotaComentarioTipo.values) {
      if (tipo.value == normalized) return tipo;
    }
    return NotaComentarioTipo.texto;
  }

  String toDbString() => value;
}

/// Modelo de Análise Prévia da Nota SAP
@immutable
class NotaSapAnalise {
  final String? id;
  final String notaSapId;
  final String? numeroNota;
  final NotaAnaliseStatus statusAnalise;
  final String? diagnosticoPrevio;
  final String? escopoDetalhado;
  final String? observacoesPlanejamento;
  final bool necessitaDesligamento;
  final bool necessitaBloqueio;
  final double? valorPv;
  final double? estimativaHoras;
  final int? quantidadeTecnicos;
  final String? ferramentasEspeciais;
  final String? requisitosSeguranca;
  final String? analistaId;
  final String? analistaNome;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const NotaSapAnalise({
    this.id,
    required this.notaSapId,
    this.numeroNota,
    this.statusAnalise = NotaAnaliseStatus.naoIniciada,
    this.diagnosticoPrevio,
    this.escopoDetalhado,
    this.observacoesPlanejamento,
    this.necessitaDesligamento = false,
    this.necessitaBloqueio = false,
    this.valorPv,
    this.estimativaHoras,
    this.quantidadeTecnicos,
    this.ferramentasEspeciais,
    this.requisitosSeguranca,
    this.analistaId,
    this.analistaNome,
    this.createdAt,
    this.updatedAt,
  });

  factory NotaSapAnalise.fromJson(Map<String, dynamic> json) =>
      NotaSapAnalise.fromMap(json);

  factory NotaSapAnalise.fromMap(Map<String, dynamic> map) {
    return NotaSapAnalise(
      id: map['id']?.toString(),
      notaSapId: map['nota_sap_id']?.toString() ?? '',
      numeroNota: map['numero_nota']?.toString(),
      statusAnalise: NotaAnaliseStatus.fromDbString(map['status_analise']?.toString()),
      diagnosticoPrevio: map['diagnostico_previo']?.toString(),
      escopoDetalhado: map['escopo_detalhado']?.toString(),
      observacoesPlanejamento: map['observacoes_planejamento']?.toString(),
      necessitaDesligamento: map['necessita_desligamento'] == true,
      necessitaBloqueio: map['necessita_bloqueio'] == true,
      valorPv: map['valor_pv'] != null
          ? (map['valor_pv'] as num).toDouble()
          : null,
      estimativaHoras: map['estimativa_horas'] != null
          ? (map['estimativa_horas'] as num).toDouble()
          : null,
      quantidadeTecnicos: map['quantidade_tecnicos'] != null
          ? (map['quantidade_tecnicos'] as num).toInt()
          : null,
      ferramentasEspeciais: map['ferramentas_especiais']?.toString(),
      requisitosSeguranca: map['requisitos_seguranca']?.toString(),
      analistaId: map['analista_id']?.toString(),
      analistaNome: map['analista_nome']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => toMap();

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'nota_sap_id': notaSapId,
      'status_analise': statusAnalise.toDbString(),
      'necessita_desligamento': necessitaDesligamento,
      'necessita_bloqueio': necessitaBloqueio,
    };

    if (id != null) map['id'] = id;
    if (numeroNota != null) map['numero_nota'] = numeroNota;
    if (diagnosticoPrevio != null) map['diagnostico_previo'] = diagnosticoPrevio;
    if (escopoDetalhado != null) map['escopo_detalhado'] = escopoDetalhado;
    if (observacoesPlanejamento != null) {
      map['observacoes_planejamento'] = observacoesPlanejamento;
    }
    if (valorPv != null) map['valor_pv'] = valorPv;
    if (estimativaHoras != null) map['estimativa_horas'] = estimativaHoras;
    if (quantidadeTecnicos != null) map['quantidade_tecnicos'] = quantidadeTecnicos;
    if (ferramentasEspeciais != null) {
      map['ferramentas_especiais'] = ferramentasEspeciais;
    }
    if (requisitosSeguranca != null) {
      map['requisitos_seguranca'] = requisitosSeguranca;
    }
    if (analistaId != null) map['analista_id'] = analistaId;
    if (analistaNome != null) map['analista_nome'] = analistaNome;

    return map;
  }

  NotaSapAnalise copyWith({
    String? id,
    String? notaSapId,
    String? numeroNota,
    NotaAnaliseStatus? statusAnalise,
    String? diagnosticoPrevio,
    String? escopoDetalhado,
    String? observacoesPlanejamento,
    bool? necessitaDesligamento,
    bool? necessitaBloqueio,
    double? valorPv,
    double? estimativaHoras,
    int? quantidadeTecnicos,
    String? ferramentasEspeciais,
    String? requisitosSeguranca,
    String? analistaId,
    String? analistaNome,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NotaSapAnalise(
      id: id ?? this.id,
      notaSapId: notaSapId ?? this.notaSapId,
      numeroNota: numeroNota ?? this.numeroNota,
      statusAnalise: statusAnalise ?? this.statusAnalise,
      diagnosticoPrevio: diagnosticoPrevio ?? this.diagnosticoPrevio,
      escopoDetalhado: escopoDetalhado ?? this.escopoDetalhado,
      observacoesPlanejamento:
          observacoesPlanejamento ?? this.observacoesPlanejamento,
      necessitaDesligamento:
          necessitaDesligamento ?? this.necessitaDesligamento,
      necessitaBloqueio: necessitaBloqueio ?? this.necessitaBloqueio,
      valorPv: valorPv ?? this.valorPv,
      estimativaHoras: estimativaHoras ?? this.estimativaHoras,
      quantidadeTecnicos: quantidadeTecnicos ?? this.quantidadeTecnicos,
      ferramentasEspeciais: ferramentasEspeciais ?? this.ferramentasEspeciais,
      requisitosSeguranca: requisitosSeguranca ?? this.requisitosSeguranca,
      analistaId: analistaId ?? this.analistaId,
      analistaNome: analistaNome ?? this.analistaNome,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Modelo de Material / Peça da Nota SAP
@immutable
class NotaSapMaterial {
  final String? id;
  final String notaSapId;
  final String? analiseId;
  final String? codigoSap;
  final String descricao;
  final double quantidade;
  final String unidade;
  final NotaMaterialStatus statusMaterial;
  final String? observacao;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const NotaSapMaterial({
    this.id,
    required this.notaSapId,
    this.analiseId,
    this.codigoSap,
    required this.descricao,
    this.quantidade = 1.0,
    this.unidade = 'UN',
    this.statusMaterial = NotaMaterialStatus.naoVerificado,
    this.observacao,
    this.createdAt,
    this.updatedAt,
  });

  factory NotaSapMaterial.fromJson(Map<String, dynamic> json) =>
      NotaSapMaterial.fromMap(json);

  factory NotaSapMaterial.fromMap(Map<String, dynamic> map) {
    return NotaSapMaterial(
      id: map['id']?.toString(),
      notaSapId: map['nota_sap_id']?.toString() ?? '',
      analiseId: map['analise_id']?.toString(),
      codigoSap: map['codigo_sap']?.toString(),
      descricao: map['descricao']?.toString() ?? '',
      quantidade: map['quantidade'] != null
          ? (map['quantidade'] as num).toDouble()
          : 1.0,
      unidade: map['unidade']?.toString() ?? 'UN',
      statusMaterial:
          NotaMaterialStatus.fromDbString(map['status_material']?.toString()),
      observacao: map['observacao']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => toMap();

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'nota_sap_id': notaSapId,
      'descricao': descricao,
      'quantidade': quantidade,
      'unidade': unidade,
      'status_material': statusMaterial.toDbString(),
    };

    if (id != null) map['id'] = id;
    if (analiseId != null) map['analise_id'] = analiseId;
    if (codigoSap != null) map['codigo_sap'] = codigoSap;
    if (observacao != null) map['observacao'] = observacao;

    return map;
  }

  NotaSapMaterial copyWith({
    String? id,
    String? notaSapId,
    String? analiseId,
    String? codigoSap,
    String? descricao,
    double? quantidade,
    String? unidade,
    NotaMaterialStatus? statusMaterial,
    String? observacao,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NotaSapMaterial(
      id: id ?? this.id,
      notaSapId: notaSapId ?? this.notaSapId,
      analiseId: analiseId ?? this.analiseId,
      codigoSap: codigoSap ?? this.codigoSap,
      descricao: descricao ?? this.descricao,
      quantidade: quantidade ?? this.quantidade,
      unidade: unidade ?? this.unidade,
      statusMaterial: statusMaterial ?? this.statusMaterial,
      observacao: observacao ?? this.observacao,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Modelo de Anexo / Imagem da Nota SAP
@immutable
class NotaSapAnexo {
  final String? id;
  final String notaSapId;
  final String nomeArquivo;
  final String? nomeOriginal;
  final NotaAnexoTipo tipoArquivo;
  final String caminhoArquivo;
  final String bucket;
  final int tamanhoBytes;
  final String? mimeType;
  final String? extensao;
  final String origem; // 'SAP', 'TASKFLOW', 'USUARIO', 'IMPORTACAO'
  final String? legenda;
  final String? sapDocumentId;
  final String? sha256;
  final Map<String, dynamic> metadata;
  final String? usuarioId;
  final String? usuarioNome;
  final DateTime? createdAt;
  final DateTime? importadoEm;
  final bool relevanteAnalise;
  final String? urlPublica;
  final String? urlAssinada;
  final String? anexoDerivadoDeId;
  final int versaoAnotacao;

  const NotaSapAnexo({
    this.id,
    required this.notaSapId,
    required this.nomeArquivo,
    this.nomeOriginal,
    required this.tipoArquivo,
    required this.caminhoArquivo,
    this.bucket = 'notas-sap-anexos',
    required this.tamanhoBytes,
    this.mimeType,
    this.extensao,
    this.origem = 'SAP',
    this.legenda,
    this.sapDocumentId,
    this.sha256,
    this.metadata = const {},
    this.usuarioId,
    this.usuarioNome,
    this.createdAt,
    this.importadoEm,
    this.relevanteAnalise = false,
    this.urlPublica,
    this.urlAssinada,
    this.anexoDerivadoDeId,
    this.versaoAnotacao = 0,
  });

  String? get descricao => legenda;

  String get nomeExibicao =>
      (nomeOriginal != null && nomeOriginal!.trim().isNotEmpty)
          ? nomeOriginal!
          : nomeArquivo;

  String get bucketNome => bucket.isNotEmpty ? bucket : 'notas-sap-anexos';

  bool get isDerivado => anexoDerivadoDeId != null;
  bool get isOriginal => anexoDerivadoDeId == null;
  bool get possuiAnotacao => versaoAnotacao > 0;

  String get tamanhoFormatado {
    if (tamanhoBytes < 1024) return '$tamanhoBytes B';
    if (tamanhoBytes < 1024 * 1024) {
      return '${(tamanhoBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(tamanhoBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory NotaSapAnexo.fromJson(Map<String, dynamic> json) =>
      NotaSapAnexo.fromMap(json);

  factory NotaSapAnexo.fromMap(Map<String, dynamic> map) {
    // Deduz tipo se for novo tipo ou legado
    final tipoRaw = map['tipo_arquivo']?.toString();
    final mimeRaw = map['mime_type']?.toString();
    final nomeRaw = map['nome_arquivo']?.toString() ?? '';
    final tipoDeduzido = tipoRaw != null && tipoRaw.isNotEmpty
        ? NotaAnexoTipo.fromDbString(tipoRaw)
        : NotaAnexoTipo.deduzir(mimeRaw, nomeRaw);

    Map<String, dynamic> parsedMeta = const {};
    if (map['metadata'] is Map) {
      parsedMeta = Map<String, dynamic>.from(map['metadata'] as Map);
    }

    return NotaSapAnexo(
      id: map['id']?.toString(),
      notaSapId: map['nota_sap_id']?.toString() ?? '',
      nomeArquivo: nomeRaw,
      nomeOriginal: map['nome_original']?.toString(),
      tipoArquivo: tipoDeduzido,
      caminhoArquivo: map['caminho_arquivo']?.toString() ?? '',
      // Se nulo no banco antigo, assume 'anexos-tarefas' para não quebrar
      bucket: map['bucket']?.toString() ?? 'anexos-tarefas',
      tamanhoBytes: (map['tamanho_bytes'] as num?)?.toInt() ?? 0,
      mimeType: mimeRaw,
      extensao: map['extensao']?.toString(),
      origem: map['origem']?.toString() ?? 'TASKFLOW',
      legenda: map['legenda']?.toString(),
      sapDocumentId: map['sap_document_id']?.toString(),
      sha256: map['sha256']?.toString(),
      metadata: parsedMeta,
      usuarioId: map['usuario_id']?.toString(),
      usuarioNome: map['usuario_nome']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      importadoEm: map['importado_em'] != null
          ? DateTime.tryParse(map['importado_em'].toString())
          : null,
      relevanteAnalise: map['relevante_analise'] == true,
      urlPublica: map['url_publica']?.toString(),
      urlAssinada: map['url_assinada']?.toString(),
      anexoDerivadoDeId: map['anexo_derivado_de_id']?.toString(),
      versaoAnotacao: (map['versao_anotacao'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => toMap();

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'nota_sap_id': notaSapId,
      'nome_arquivo': nomeArquivo,
      'tipo_arquivo': tipoArquivo.toDbString(),
      'caminho_arquivo': caminhoArquivo,
      'bucket': bucket,
      'tamanho_bytes': tamanhoBytes,
      'origem': origem,
      'relevante_analise': relevanteAnalise,
    };

    if (id != null) map['id'] = id;
    if (nomeOriginal != null) map['nome_original'] = nomeOriginal;
    if (mimeType != null) map['mime_type'] = mimeType;
    if (extensao != null) map['extensao'] = extensao;
    if (legenda != null) map['legenda'] = legenda;
    if (sapDocumentId != null) map['sap_document_id'] = sapDocumentId;
    if (sha256 != null) map['sha256'] = sha256;
    if (metadata.isNotEmpty) map['metadata'] = metadata;
    if (usuarioId != null) map['usuario_id'] = usuarioId;
    if (usuarioNome != null) map['usuario_nome'] = usuarioNome;
    if (anexoDerivadoDeId != null) {
      map['anexo_derivado_de_id'] = anexoDerivadoDeId;
    }
    if (importadoEm != null) {
      map['importado_em'] = importadoEm!.toIso8601String();
    }

    return map;
  }

  NotaSapAnexo copyWith({
    String? id,
    String? notaSapId,
    String? nomeArquivo,
    String? nomeOriginal,
    NotaAnexoTipo? tipoArquivo,
    String? caminhoArquivo,
    String? bucket,
    int? tamanhoBytes,
    String? mimeType,
    String? extensao,
    String? origem,
    String? legenda,
    String? sapDocumentId,
    String? sha256,
    Map<String, dynamic>? metadata,
    String? usuarioId,
    String? usuarioNome,
    DateTime? createdAt,
    DateTime? importadoEm,
    bool? relevanteAnalise,
    String? urlPublica,
    String? urlAssinada,
    String? anexoDerivadoDeId,
    int? versaoAnotacao,
  }) {
    return NotaSapAnexo(
      id: id ?? this.id,
      notaSapId: notaSapId ?? this.notaSapId,
      nomeArquivo: nomeArquivo ?? this.nomeArquivo,
      nomeOriginal: nomeOriginal ?? this.nomeOriginal,
      tipoArquivo: tipoArquivo ?? this.tipoArquivo,
      caminhoArquivo: caminhoArquivo ?? this.caminhoArquivo,
      bucket: bucket ?? this.bucket,
      tamanhoBytes: tamanhoBytes ?? this.tamanhoBytes,
      mimeType: mimeType ?? this.mimeType,
      extensao: extensao ?? this.extensao,
      origem: origem ?? this.origem,
      legenda: legenda ?? this.legenda,
      sapDocumentId: sapDocumentId ?? this.sapDocumentId,
      sha256: sha256 ?? this.sha256,
      metadata: metadata ?? this.metadata,
      usuarioId: usuarioId ?? this.usuarioId,
      usuarioNome: usuarioNome ?? this.usuarioNome,
      createdAt: createdAt ?? this.createdAt,
      importadoEm: importadoEm ?? this.importadoEm,
      relevanteAnalise: relevanteAnalise ?? this.relevanteAnalise,
      urlPublica: urlPublica ?? this.urlPublica,
      urlAssinada: urlAssinada ?? this.urlAssinada,
      anexoDerivadoDeId: anexoDerivadoDeId ?? this.anexoDerivadoDeId,
      versaoAnotacao: versaoAnotacao ?? this.versaoAnotacao,
    );
  }
}

/// Modelo de Comentário / Mensagem da Discussão da Nota
@immutable
class NotaSapComentario {
  final String? id;
  final String notaSapId;
  final String usuarioId;
  final String? usuarioNome;
  final String mensagem;
  final NotaComentarioTipo tipoMensagem;
  final String? replyToId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  const NotaSapComentario({
    this.id,
    required this.notaSapId,
    required this.usuarioId,
    this.usuarioNome,
    required this.mensagem,
    this.tipoMensagem = NotaComentarioTipo.texto,
    this.replyToId,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  String get tempoFormatado {
    if (createdAt == null) return '';
    final diff = DateTime.now().difference(createdAt!);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inHours < 1) return '${diff.inMinutes}m atrás';
    if (diff.inDays < 1) return '${diff.inHours}h atrás';
    return '${createdAt!.day.toString().padLeft(2, '0')}/${createdAt!.month.toString().padLeft(2, '0')} ${createdAt!.hour.toString().padLeft(2, '0')}:${createdAt!.minute.toString().padLeft(2, '0')}';
  }

  factory NotaSapComentario.fromJson(Map<String, dynamic> json) =>
      NotaSapComentario.fromMap(json);

  factory NotaSapComentario.fromMap(Map<String, dynamic> map) {
    return NotaSapComentario(
      id: map['id']?.toString(),
      notaSapId: map['nota_sap_id']?.toString() ?? '',
      usuarioId: map['usuario_id']?.toString() ?? '',
      usuarioNome: map['usuario_nome']?.toString(),
      mensagem: map['mensagem']?.toString() ?? '',
      tipoMensagem:
          NotaComentarioTipo.fromDbString(map['tipo_mensagem']?.toString()),
      replyToId: map['reply_to_id']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
      deletedAt: map['deleted_at'] != null
          ? DateTime.tryParse(map['deleted_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => toMap();

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'nota_sap_id': notaSapId,
      'usuario_id': usuarioId,
      'mensagem': mensagem,
      'tipo_mensagem': tipoMensagem.toDbString(),
    };

    if (id != null) map['id'] = id;
    if (usuarioNome != null) map['usuario_nome'] = usuarioNome;
    if (replyToId != null) map['reply_to_id'] = replyToId;
    if (deletedAt != null) map['deleted_at'] = deletedAt?.toIso8601String();

    return map;
  }

  NotaSapComentario copyWith({
    String? id,
    String? notaSapId,
    String? usuarioId,
    String? usuarioNome,
    String? mensagem,
    NotaComentarioTipo? tipoMensagem,
    String? replyToId,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return NotaSapComentario(
      id: id ?? this.id,
      notaSapId: notaSapId ?? this.notaSapId,
      usuarioId: usuarioId ?? this.usuarioId,
      usuarioNome: usuarioNome ?? this.usuarioNome,
      mensagem: mensagem ?? this.mensagem,
      tipoMensagem: tipoMensagem ?? this.tipoMensagem,
      replyToId: replyToId ?? this.replyToId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}

/// DTO Resumo para renderização leve de badges na tabela (sem N+1)
@immutable
class NotaSapResumoAnalise {
  final String notaSapId;
  final NotaAnaliseStatus status;
  final int quantidadeAnexos;
  final int quantidadeImagens;
  final int quantidadePdfs;
  final int quantidadeVideos;
  final int quantidadeDocumentos;
  final int quantidadePlanilhas;
  final int quantidadeAudios;
  final int quantidadeOutros;
  final int quantidadeRelevantes;
  final int quantidadeComentarios;
  final int quantidadeMateriais;

  const NotaSapResumoAnalise({
    required this.notaSapId,
    this.status = NotaAnaliseStatus.naoIniciada,
    this.quantidadeAnexos = 0,
    this.quantidadeImagens = 0,
    this.quantidadePdfs = 0,
    this.quantidadeVideos = 0,
    this.quantidadeDocumentos = 0,
    this.quantidadePlanilhas = 0,
    this.quantidadeAudios = 0,
    this.quantidadeOutros = 0,
    this.quantidadeRelevantes = 0,
    this.quantidadeComentarios = 0,
    this.quantidadeMateriais = 0,
  });

  bool get temAnalise => status != NotaAnaliseStatus.naoIniciada;
  bool get temAnexos => quantidadeAnexos > 0;
  bool get temComentarios => quantidadeComentarios > 0;
  bool get temMateriais => quantidadeMateriais > 0;

  int get totalAnexos => quantidadeAnexos;
  int get totalComentarios => quantidadeComentarios;
  int get totalMateriais => quantidadeMateriais;

  NotaSapResumoAnalise copyWith({
    String? notaSapId,
    NotaAnaliseStatus? status,
    int? quantidadeAnexos,
    int? quantidadeImagens,
    int? quantidadePdfs,
    int? quantidadeVideos,
    int? quantidadeDocumentos,
    int? quantidadePlanilhas,
    int? quantidadeAudios,
    int? quantidadeOutros,
    int? quantidadeRelevantes,
    int? quantidadeComentarios,
    int? quantidadeMateriais,
  }) {
    return NotaSapResumoAnalise(
      notaSapId: notaSapId ?? this.notaSapId,
      status: status ?? this.status,
      quantidadeAnexos: quantidadeAnexos ?? this.quantidadeAnexos,
      quantidadeImagens: quantidadeImagens ?? this.quantidadeImagens,
      quantidadePdfs: quantidadePdfs ?? this.quantidadePdfs,
      quantidadeVideos: quantidadeVideos ?? this.quantidadeVideos,
      quantidadeDocumentos: quantidadeDocumentos ?? this.quantidadeDocumentos,
      quantidadePlanilhas: quantidadePlanilhas ?? this.quantidadePlanilhas,
      quantidadeAudios: quantidadeAudios ?? this.quantidadeAudios,
      quantidadeOutros: quantidadeOutros ?? this.quantidadeOutros,
      quantidadeRelevantes: quantidadeRelevantes ?? this.quantidadeRelevantes,
      quantidadeComentarios:
          quantidadeComentarios ?? this.quantidadeComentarios,
      quantidadeMateriais: quantidadeMateriais ?? this.quantidadeMateriais,
    );
  }
}
