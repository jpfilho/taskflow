class Demand {
  final String id;
  final String titulo;
  final String? descricao;
  final String status; // pendente, em_progresso, concluido, cancelado
  final String prioridade; // baixa, media, alta, urgente
  final String? categoriaId;
  final String? criadoPor;
  final String? atribuidaPara;
  final DateTime? dataCriacao;
  final DateTime? dataVencimento;
  final DateTime? dataInicio;
  final DateTime? dataConclusao;
  final List<String> tags;
  final Map<String, dynamic> metadata;
  final DateTime? atualizadoEm;

  Demand({
    required this.id,
    required this.titulo,
    required this.status,
    required this.prioridade,
    this.descricao,
    this.categoriaId,
    this.criadoPor,
    this.atribuidaPara,
    this.dataCriacao,
    this.dataVencimento,
    this.dataInicio,
    this.dataConclusao,
    this.tags = const [],
    this.metadata = const {},
    this.atualizadoEm,
  });

  factory Demand.fromMap(Map<String, dynamic> m) {
    DateTime? dt(dynamic v) => v == null ? null : DateTime.parse(v as String);
    return Demand(
      id: m['id'] as String,
      titulo: m['titulo'] as String,
      descricao: m['descricao'] as String?,
      status: m['status'] as String,
      prioridade: m['prioridade'] as String,
      categoriaId: m['categoria_id'] as String?,
      criadoPor: m['criado_por'] as String?,
      atribuidaPara: m['atribuida_para'] as String?,
      dataCriacao: dt(m['data_criacao']),
      dataVencimento: dt(m['data_vencimento']),
      dataInicio: dt(m['data_inicio']),
      dataConclusao: dt(m['data_conclusao']),
      tags: (m['tags'] as List?)?.cast<String>() ?? const [],
      metadata: (m['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
      atualizadoEm: dt(m['atualizado_em']),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'titulo': titulo,
        'descricao': descricao,
        'status': status,
        'prioridade': prioridade,
        'categoria_id': categoriaId,
        'criado_por': criadoPor,
        'atribuida_para': atribuidaPara,
        'data_criacao': dataCriacao?.toIso8601String(),
        'data_vencimento': dataVencimento?.toIso8601String(),
        'data_inicio': dataInicio?.toIso8601String(),
        'data_conclusao': dataConclusao?.toIso8601String(),
        'tags': tags,
        'metadata': metadata,
        'atualizado_em': atualizadoEm?.toIso8601String(),
      };
}
