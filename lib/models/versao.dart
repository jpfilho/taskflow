/// Modelo da entidade Versão (roadmap do produto).
class Versao {
  final String id;
  final String nome;
  final String? descricao;
  final DateTime? dataPrevistaLancamento;
  final DateTime? dataLancamento;
  final int ordem;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Versao({
    required this.id,
    required this.nome,
    this.descricao,
    this.dataPrevistaLancamento,
    this.dataLancamento,
    this.ordem = 0,
    this.createdAt,
    this.updatedAt,
  });

  /// Converte de mapa (SQLite local: timestamps em ms; Supabase: strings ISO).
  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  factory Versao.fromMap(Map<String, dynamic> map) {
    return Versao(
      id: map['id'] as String,
      nome: map['nome'] as String,
      descricao: map['descricao'] as String?,
      dataPrevistaLancamento: _parseDate(map['data_prevista_lancamento']),
      dataLancamento: _parseDate(map['data_lancamento']),
      ordem: (map['ordem'] as int?) ?? 0,
      createdAt: _parseDate(map['created_at']),
      updatedAt: _parseDate(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'descricao': descricao,
      'data_prevista_lancamento': dataPrevistaLancamento != null
          ? (dataPrevistaLancamento!.millisecondsSinceEpoch)
          : null,
      'data_lancamento':
          dataLancamento != null ? dataLancamento!.millisecondsSinceEpoch : null,
      'ordem': ordem,
      'created_at': createdAt?.millisecondsSinceEpoch,
      'updated_at': updatedAt?.millisecondsSinceEpoch,
    };
  }

  /// Para envio ao Supabase (ISO string para datas).
  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id,
      'nome': nome,
      'descricao': descricao,
      'data_prevista_lancamento': dataPrevistaLancamento?.toIso8601String().split('T').first,
      'data_lancamento': dataLancamento?.toIso8601String().split('T').first,
      'ordem': ordem,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Versao copyWith({
    String? id,
    String? nome,
    String? descricao,
    DateTime? dataPrevistaLancamento,
    DateTime? dataLancamento,
    int? ordem,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Versao(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      descricao: descricao ?? this.descricao,
      dataPrevistaLancamento: dataPrevistaLancamento ?? this.dataPrevistaLancamento,
      dataLancamento: dataLancamento ?? this.dataLancamento,
      ordem: ordem ?? this.ordem,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
