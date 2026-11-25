/// Modelo de catálogo de tipo de apoio operacional (`tasks_apoios_tipos`).
class TaskApoioTipo {
  final String id;
  final String codigo;
  final String nome;
  final String? descricao;
  final String? icone;
  final String? corHex;
  final bool exigeRecursoFrota;
  final bool exigeRecursoEquipe;
  final int ordem;
  final bool ativo;

  const TaskApoioTipo({
    required this.id,
    required this.codigo,
    required this.nome,
    this.descricao,
    this.icone,
    this.corHex,
    this.exigeRecursoFrota = false,
    this.exigeRecursoEquipe = false,
    this.ordem = 0,
    this.ativo = true,
  });

  factory TaskApoioTipo.fromJson(Map<String, dynamic> json) {
    return TaskApoioTipo(
      id: json['id']?.toString() ?? '',
      codigo: json['codigo']?.toString() ?? '',
      nome: json['nome']?.toString() ?? '',
      descricao: json['descricao']?.toString(),
      icone: json['icone']?.toString(),
      corHex: json['cor_hex']?.toString() ?? json['corHex']?.toString(),
      exigeRecursoFrota:
          (json['exige_recurso_frota'] ?? json['exigeRecursoFrota']) == true,
      exigeRecursoEquipe:
          (json['exige_recurso_equipe'] ?? json['exigeRecursoEquipe']) == true,
      ordem: (json['ordem'] as num?)?.toInt() ?? 0,
      ativo: json['ativo'] != false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'codigo': codigo,
      'nome': nome,
      'descricao': descricao,
      'icone': icone,
      'cor_hex': corHex,
      'exige_recurso_frota': exigeRecursoFrota,
      'exige_recurso_equipe': exigeRecursoEquipe,
      'ordem': ordem,
      'ativo': ativo,
    };
  }

  TaskApoioTipo copyWith({
    String? id,
    String? codigo,
    String? nome,
    String? descricao,
    String? icone,
    String? corHex,
    bool? exigeRecursoFrota,
    bool? exigeRecursoEquipe,
    int? ordem,
    bool? ativo,
  }) {
    return TaskApoioTipo(
      id: id ?? this.id,
      codigo: codigo ?? this.codigo,
      nome: nome ?? this.nome,
      descricao: descricao ?? this.descricao,
      icone: icone ?? this.icone,
      corHex: corHex ?? this.corHex,
      exigeRecursoFrota: exigeRecursoFrota ?? this.exigeRecursoFrota,
      exigeRecursoEquipe: exigeRecursoEquipe ?? this.exigeRecursoEquipe,
      ordem: ordem ?? this.ordem,
      ativo: ativo ?? this.ativo,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskApoioTipo &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          codigo == other.codigo &&
          nome == other.nome &&
          ativo == other.ativo;

  @override
  int get hashCode => Object.hash(id, codigo, nome, ativo);
}

