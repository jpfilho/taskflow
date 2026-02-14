/// Status internos (códigos) para Melhorias e Bugs.
const List<String> kMelhoriasBugsStatusCodes = [
  'BACKLOG',
  'ANALISE',
  'DESENVOLVIMENTO',
  'VALIDACAO',
  'CONCLUIDO',
  'REABERTO',
  'REJEITADO',
  'DUPLICADO',
];

/// Labels humanizados para exibição.
const Map<String, String> kMelhoriasBugsStatusLabels = {
  'BACKLOG': 'Aguardando análise',
  'ANALISE': 'Em análise',
  'DESENVOLVIMENTO': 'Em desenvolvimento',
  'VALIDACAO': 'Em validação',
  'CONCLUIDO': 'Concluído',
  'REABERTO': 'Reaberto',
  'REJEITADO': 'Não será feito',
  'DUPLICADO': 'Duplicado',
};

/// Transições permitidas (boas práticas ágeis).
/// De BACKLOG -> ANALISE, REJEITADO, DUPLICADO
/// De ANALISE -> DESENVOLVIMENTO, BACKLOG, REJEITADO, DUPLICADO
/// De DESENVOLVIMENTO -> VALIDACAO, ANALISE, REJEITADO
/// De VALIDACAO -> CONCLUIDO, DESENVOLVIMENTO, REJEITADO
/// De CONCLUIDO -> REABERTO
/// De REABERTO -> ANALISE, DESENVOLVIMENTO
/// De REJEITADO/DUPLICADO -> (fim)
const Map<String, List<String>> kMelhoriasBugsTransicoes = {
  'BACKLOG': ['ANALISE', 'REJEITADO', 'DUPLICADO'],
  'ANALISE': ['DESENVOLVIMENTO', 'BACKLOG', 'REJEITADO', 'DUPLICADO'],
  'DESENVOLVIMENTO': ['VALIDACAO', 'ANALISE', 'REJEITADO'],
  'VALIDACAO': ['CONCLUIDO', 'DESENVOLVIMENTO', 'REJEITADO'],
  'CONCLUIDO': ['REABERTO'],
  'REABERTO': ['ANALISE', 'DESENVOLVIMENTO'],
  'REJEITADO': [],
  'DUPLICADO': [],
};

String melhoriaBugStatusLabel(String code) {
  return kMelhoriasBugsStatusLabels[code] ?? code;
}

bool melhoriaBugPodeTransicionar(String de, String para) {
  final destinos = kMelhoriasBugsTransicoes[de];
  if (destinos == null) return false;
  return destinos.contains(para);
}

/// Tipos de item.
const String kTipoBug = 'BUG';
const String kTipoMelhoria = 'MELHORIA';

/// Prioridades.
const List<String> kMelhoriasBugsPrioridades = ['BAIXA', 'MEDIA', 'ALTA', 'CRITICA'];

/// Modelo da entidade Melhoria/Bug.
class MelhoriaBug {
  final String id;
  final String tipo; // BUG | MELHORIA
  final String titulo;
  final String? descricao;
  final String status;
  final String? versaoId;
  final String? prioridade;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? concluidoEm;
  final DateTime? reabertoEm;
  final String? versaoCorrigida;

  MelhoriaBug({
    required this.id,
    required this.tipo,
    required this.titulo,
    this.descricao,
    required this.status,
    this.versaoId,
    this.prioridade,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.concluidoEm,
    this.reabertoEm,
    this.versaoCorrigida,
  });

  String get statusLabel => melhoriaBugStatusLabel(status);

  List<String> get proximosStatusPossiveis =>
      kMelhoriasBugsTransicoes[status] ?? [];

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  factory MelhoriaBug.fromMap(Map<String, dynamic> map) {
    return MelhoriaBug(
      id: map['id'] as String,
      tipo: map['tipo'] as String,
      titulo: map['titulo'] as String,
      descricao: map['descricao'] as String?,
      status: (map['status'] as String?) ?? 'BACKLOG',
      versaoId: map['versao_id'] as String?,
      prioridade: map['prioridade'] as String?,
      createdBy: map['created_by'] as String?,
      createdAt: _parseDate(map['created_at']),
      updatedAt: _parseDate(map['updated_at']),
      concluidoEm: _parseDate(map['concluido_em']),
      reabertoEm: _parseDate(map['reaberto_em']),
      versaoCorrigida: map['versao_corrigida'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tipo': tipo,
      'titulo': titulo,
      'descricao': descricao,
      'status': status,
      'versao_id': versaoId,
      'prioridade': prioridade,
      'created_by': createdBy,
      'created_at': createdAt?.millisecondsSinceEpoch,
      'updated_at': updatedAt?.millisecondsSinceEpoch,
      'concluido_em': concluidoEm?.millisecondsSinceEpoch,
      'reaberto_em': reabertoEm?.millisecondsSinceEpoch,
      'versao_corrigida': versaoCorrigida,
    };
  }

  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id,
      'tipo': tipo,
      'titulo': titulo,
      'descricao': descricao,
      'status': status,
      'versao_id': versaoId,
      'prioridade': prioridade,
      'created_by': createdBy,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'concluido_em': concluidoEm?.toIso8601String(),
      'reaberto_em': reabertoEm?.toIso8601String(),
      'versao_corrigida': versaoCorrigida,
    };
  }

  MelhoriaBug copyWith({
    String? id,
    String? tipo,
    String? titulo,
    String? descricao,
    String? status,
    String? versaoId,
    String? prioridade,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? concluidoEm,
    DateTime? reabertoEm,
    String? versaoCorrigida,
  }) {
    return MelhoriaBug(
      id: id ?? this.id,
      tipo: tipo ?? this.tipo,
      titulo: titulo ?? this.titulo,
      descricao: descricao ?? this.descricao,
      status: status ?? this.status,
      versaoId: versaoId ?? this.versaoId,
      prioridade: prioridade ?? this.prioridade,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      concluidoEm: concluidoEm ?? this.concluidoEm,
      reabertoEm: reabertoEm ?? this.reabertoEm,
      versaoCorrigida: versaoCorrigida ?? this.versaoCorrigida,
    );
  }
}
