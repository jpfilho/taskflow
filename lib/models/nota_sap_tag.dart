enum NotaSapTagEscopo {
  global,
  regional,
  divisao,
  segmento;

  static NotaSapTagEscopo fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'REGIONAL':
        return NotaSapTagEscopo.regional;
      case 'DIVISAO':
        return NotaSapTagEscopo.divisao;
      case 'SEGMENTO':
        return NotaSapTagEscopo.segmento;
      case 'GLOBAL':
      default:
        return NotaSapTagEscopo.global;
    }
  }

  String toDbString() {
    switch (this) {
      case NotaSapTagEscopo.global:
        return 'GLOBAL';
      case NotaSapTagEscopo.regional:
        return 'REGIONAL';
      case NotaSapTagEscopo.divisao:
        return 'DIVISAO';
      case NotaSapTagEscopo.segmento:
        return 'SEGMENTO';
    }
  }

  String get label {
    switch (this) {
      case NotaSapTagEscopo.global:
        return 'Global';
      case NotaSapTagEscopo.regional:
        return 'Regional';
      case NotaSapTagEscopo.divisao:
        return 'Divisão';
      case NotaSapTagEscopo.segmento:
        return 'Segmento';
    }
  }

  String get descricao => label;
}

class NotaSapTag {
  final String? id;
  final String nome;
  final String? nomeNormalizado;
  final String? descricao;
  final String? categoria;
  final String? cor;
  final String? icone;
  final NotaSapTagEscopo escopoTipo;
  final String? regionalId;
  final String? divisaoId;
  final String? segmentoId;
  final bool ativo;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final int? totalNotas; // Para contagem em administração

  NotaSapTag({
    this.id,
    required this.nome,
    String? nomeNormalizado,
    this.descricao,
    this.categoria = 'GERAL',
    this.cor = '#1E88E5',
    this.icone = 'label_outline',
    this.escopoTipo = NotaSapTagEscopo.global,
    this.regionalId,
    this.divisaoId,
    this.segmentoId,
    this.ativo = true,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.totalNotas,
  }) : nomeNormalizado = nomeNormalizado ?? (nome.isEmpty ? '' : nome.toLowerCase());

  factory NotaSapTag.fromMap(Map<String, dynamic> map) {
    return NotaSapTag(
      id: map['id']?.toString(),
      nome: (map['nome'] as String?)?.trim() ?? '',
      nomeNormalizado: (map['nome_normalizado'] as String?) ??
          ((map['nome'] as String?)?.trim().toLowerCase() ?? ''),
      descricao: map['descricao'] as String?,
      categoria: (map['categoria'] as String?)?.trim() ?? 'GERAL',
      cor: (map['cor'] as String?) ?? '#1E88E5',
      icone: (map['icone'] as String?) ?? 'label_outline',
      escopoTipo: NotaSapTagEscopo.fromString(map['escopo_tipo'] as String?),
      regionalId: map['regional_id']?.toString(),
      divisaoId: map['divisao_id']?.toString(),
      segmentoId: map['segmento_id']?.toString(),
      ativo: map['ativo'] as bool? ?? true,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
      createdBy: map['created_by']?.toString(),
      totalNotas: map['total_notas'] as int?,
    );
  }

  Map<String, dynamic> toMap({bool incluirId = true}) {
    final map = <String, dynamic>{
      'nome': nome.trim(),
      'nome_normalizado': (nomeNormalizado != null && nomeNormalizado!.isNotEmpty)
          ? nomeNormalizado!
          : nome.trim().toLowerCase(),
      'descricao': descricao?.trim(),
      'categoria': categoria?.trim(),
      'cor': cor,
      'icone': icone,
      'escopo_tipo': escopoTipo.toDbString(),
      'regional_id': escopoTipo == NotaSapTagEscopo.regional ? regionalId : null,
      'divisao_id': escopoTipo == NotaSapTagEscopo.divisao ? divisaoId : null,
      'segmento_id': escopoTipo == NotaSapTagEscopo.segmento ? segmentoId : null,
      'ativo': ativo,
    };
    if (incluirId && id != null && id!.isNotEmpty) {
      map['id'] = id;
    }
    if (createdBy != null) {
      map['created_by'] = createdBy;
    }
    return map;
  }

  Map<String, dynamic> toJson() => toMap();
  factory NotaSapTag.fromJson(Map<String, dynamic> json) => NotaSapTag.fromMap(json);

  NotaSapTag copyWith({
    String? id,
    String? nome,
    String? nomeNormalizado,
    String? descricao,
    String? categoria,
    String? cor,
    String? icone,
    NotaSapTagEscopo? escopoTipo,
    String? regionalId,
    String? divisaoId,
    String? segmentoId,
    bool? ativo,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    int? totalNotas,
  }) {
    return NotaSapTag(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      nomeNormalizado: nomeNormalizado ?? this.nomeNormalizado,
      descricao: descricao ?? this.descricao,
      categoria: categoria ?? this.categoria,
      cor: cor ?? this.cor,
      icone: icone ?? this.icone,
      escopoTipo: escopoTipo ?? this.escopoTipo,
      regionalId: regionalId ?? this.regionalId,
      divisaoId: divisaoId ?? this.divisaoId,
      segmentoId: segmentoId ?? this.segmentoId,
      ativo: ativo ?? this.ativo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      totalNotas: totalNotas ?? this.totalNotas,
    );
  }

  /// Verifica se esta Tag está disponível para ATRIBUIÇÃO pelo usuário informado.
  bool isDisponivelParaAtribuicao({
    dynamic usuario,
    bool? isRoot,
    List<String> regionalIds = const [],
    List<String> divisaoIds = const [],
    List<String> segmentoIds = const [],
  }) {
    if (!ativo) return false;

    bool root = isRoot ?? false;
    List<String> regs = regionalIds;
    List<String> divs = divisaoIds;
    List<String> segs = segmentoIds;

    if (usuario != null) {
      try {
        final dynamic u = usuario;
        root = u.isRoot as bool;
        regs = (u.regionalIds as List<dynamic>).map((e) => e.toString()).toList();
        divs = (u.divisaoIds as List<dynamic>).map((e) => e.toString()).toList();
        segs = (u.segmentoIds as List<dynamic>).map((e) => e.toString()).toList();
      } catch (_) {}
    }

    if (root) return true;

    switch (escopoTipo) {
      case NotaSapTagEscopo.global:
        return true;
      case NotaSapTagEscopo.regional:
        return regionalId != null && regs.contains(regionalId);
      case NotaSapTagEscopo.divisao:
        return divisaoId != null && divs.contains(divisaoId);
      case NotaSapTagEscopo.segmento:
        return segmentoId != null && segs.contains(segmentoId);
    }
  }

  /// Atalho de conveniência para verificar disponibilidade de um Usuario
  bool isDisponivelParaUsuario(dynamic usuario) =>
      isDisponivelParaAtribuicao(usuario: usuario);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotaSapTag &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
