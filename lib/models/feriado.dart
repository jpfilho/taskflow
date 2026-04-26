class Feriado {
  final String id;
  final DateTime data;
  final String descricao;
  final String tipo; // 'NACIONAL', 'ESTADUAL', 'MUNICIPAL'
  final String? pais;
  final String? estado;
  final String? cidade;
  final List<String> localIds;
  final List<String>? locaisNomes;
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
    this.localIds = const [],
    this.locaisNomes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Feriado.fromMap(Map<String, dynamic> map) {
    List<String> parsedLocalIds = [];
    List<String> parsedLocaisNomes = [];

    if (map['feriados_locais'] != null) {
      final List locaisData = map['feriados_locais'] as List;
      for (var localData in locaisData) {
        if (localData['local_id'] != null) {
          parsedLocalIds.add(localData['local_id'] as String);
        }
        if (localData['locais'] != null && localData['locais']['local'] != null) {
          parsedLocaisNomes.add(localData['locais']['local'] as String);
        }
      }
    }

    return Feriado(
      id: map['id'] as String,
      data: DateTime.parse(map['data'] as String),
      descricao: map['descricao'] as String,
      tipo: map['tipo'] as String,
      pais: map['pais'] as String?,
      estado: map['estado'] as String?,
      cidade: map['cidade'] as String?,
      localIds: parsedLocalIds,
      locaisNomes: parsedLocaisNomes.isNotEmpty ? parsedLocaisNomes : null,
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
      // localIds and locaisNomes are not saved directly in the feriados table,
      // they are managed via the N:N feriados_locais table in the service.
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
    List<String>? localIds,
    List<String>? locaisNomes,
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
      localIds: localIds ?? this.localIds,
      locaisNomes: locaisNomes ?? this.locaisNomes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}






