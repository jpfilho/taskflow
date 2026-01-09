class Feriado {
  final String id;
  final DateTime data;
  final String descricao;
  final String tipo; // 'NACIONAL', 'ESTADUAL', 'MUNICIPAL'
  final String? pais;
  final String? estado;
  final String? cidade;
  final DateTime createdAt;
  final DateTime updatedAt;

  Feriado({
    required this.id,
    required this.data,
    required this.descricao,
    required this.tipo,
    this.pais,
    this.estado,
    this.cidade,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Feriado.fromMap(Map<String, dynamic> map) {
    return Feriado(
      id: map['id'] as String,
      data: DateTime.parse(map['data'] as String),
      descricao: map['descricao'] as String,
      tipo: map['tipo'] as String,
      pais: map['pais'] as String?,
      estado: map['estado'] as String?,
      cidade: map['cidade'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'data': data.toIso8601String().split('T')[0], // Apenas a data (YYYY-MM-DD)
      'descricao': descricao,
      'tipo': tipo,
      'pais': pais,
      'estado': estado,
      'cidade': cidade,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Feriado copyWith({
    String? id,
    DateTime? data,
    String? descricao,
    String? tipo,
    String? pais,
    String? estado,
    String? cidade,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Feriado(
      id: id ?? this.id,
      data: data ?? this.data,
      descricao: descricao ?? this.descricao,
      tipo: tipo ?? this.tipo,
      pais: pais ?? this.pais,
      estado: estado ?? this.estado,
      cidade: cidade ?? this.cidade,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}






