class Demanda {
  final String id;
  final String origem;
  final String local;
  final String? sala;
  final String demanda;
  final String? nota;
  final String? ordem;
  final String? si;
  final String? at;
  final String responsavel;
  final DateTime prazo;
  final String status;
  final String prioridade;
  final String? observacoes;
  final DateTime? dataConclusao;
  final String? createdBy;
  final String? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Demanda({
    required this.id,
    required this.origem,
    required this.local,
    this.sala,
    required this.demanda,
    this.nota,
    this.ordem,
    this.si,
    this.at,
    required this.responsavel,
    required this.prazo,
    required this.status,
    required this.prioridade,
    this.observacoes,
    this.dataConclusao,
    this.createdBy,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
  });

  factory Demanda.fromMap(Map<String, dynamic> map) {
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      return DateTime.parse(value as String);
    }

    DateTime parseDate(dynamic value) {
      return DateTime.parse(value as String);
    }

    return Demanda(
      id: map['id'] as String,
      origem: map['origem'] as String,
      local: map['local'] as String,
      sala: map['sala'] as String?,
      demanda: map['demanda'] as String,
      nota: map['nota'] as String?,
      ordem: map['ordem'] as String?,
      si: map['si'] as String?,
      at: map['at'] as String?,
      responsavel: map['responsavel'] as String,
      prazo: parseDate(map['prazo']),
      status: map['status'] as String,
      prioridade: map['prioridade'] as String? ?? 'Normal',
      observacoes: map['observacoes'] as String?,
      dataConclusao: parseDateTime(map['data_conclusao']),
      createdBy: map['created_by'] as String?,
      updatedBy: map['updated_by'] as String?,
      createdAt: parseDateTime(map['created_at']),
      updatedAt: parseDateTime(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    String formatDate(DateTime dt) {
      return "${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
    }

    final map = <String, dynamic>{
      'origem': origem,
      'local': local,
      'sala': sala,
      'demanda': demanda,
      'nota': nota,
      'ordem': ordem,
      'si': si,
      'at': at,
      'responsavel': responsavel,
      'prazo': formatDate(prazo),
      'status': status,
      'prioridade': prioridade,
      'observacoes': observacoes,
      'data_conclusao': dataConclusao?.toIso8601String(),
    };

    if (id.isNotEmpty) {
      map['id'] = id;
    }
    if (createdBy != null) {
      map['created_by'] = createdBy;
    }
    if (updatedBy != null) {
      map['updated_by'] = updatedBy;
    }

    return map;
  }

  Demanda copyWith({
    String? id,
    String? origem,
    String? local,
    String? sala,
    String? demanda,
    String? nota,
    String? ordem,
    String? si,
    String? at,
    String? responsavel,
    DateTime? prazo,
    String? status,
    String? prioridade,
    String? observacoes,
    DateTime? dataConclusao,
    String? createdBy,
    String? updatedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Demanda(
      id: id ?? this.id,
      origem: origem ?? this.origem,
      local: local ?? this.local,
      sala: sala ?? this.sala,
      demanda: demanda ?? this.demanda,
      nota: nota ?? this.nota,
      ordem: ordem ?? this.ordem,
      si: si ?? this.si,
      at: at ?? this.at,
      responsavel: responsavel ?? this.responsavel,
      prazo: prazo ?? this.prazo,
      status: status ?? this.status,
      prioridade: prioridade ?? this.prioridade,
      observacoes: observacoes ?? this.observacoes,
      dataConclusao: dataConclusao ?? this.dataConclusao,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
