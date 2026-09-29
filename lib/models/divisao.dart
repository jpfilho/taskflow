class Divisao {
  final String id;
  final String divisao;
  final List<String> regionalIds; // IDs das regionais associadas (N:N)
  final List<String> regionais; // Nomes das regionais associadas (para exibição)
  final String _legacyRegionalId; // ID da regional primária/legada para compatibilidade
  final String _legacyRegional; // Nome da regional primária/legada para compatibilidade
  final List<String> segmentoIds; // IDs dos segmentos associados (múltiplos)
  final List<String> segmentos; // Nomes dos segmentos (para exibição)
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Divisao({
    required this.id,
    required this.divisao,
    String regionalId = '',
    String regional = '',
    List<String>? regionalIds,
    List<String>? regionais,
    List<String>? segmentoIds,
    List<String>? segmentos,
    this.createdAt,
    this.updatedAt,
  })  : _legacyRegionalId = regionalId,
        _legacyRegional = regional,
        regionalIds = _buildRegionalIds(regionalId, regionalIds),
        regionais = _buildRegionais(regional, regionais),
        segmentoIds = segmentoIds ?? [],
        segmentos = segmentos ?? [];

  static List<String> _buildRegionalIds(String legacyId, List<String>? ids) {
    if (ids != null && ids.isNotEmpty) {
      return List<String>.from(ids);
    }
    if (legacyId.isNotEmpty) {
      return [legacyId];
    }
    return [];
  }

  static List<String> _buildRegionais(String legacyNome, List<String>? nomes) {
    if (nomes != null && nomes.isNotEmpty) {
      return List<String>.from(nomes);
    }
    if (legacyNome.isNotEmpty) {
      return [legacyNome];
    }
    return [];
  }

  /// Getter de compatibilidade legada: retorna o ID da regional primária/legada
  String get regionalId {
    if (_legacyRegionalId.isNotEmpty && regionalIds.contains(_legacyRegionalId)) {
      return _legacyRegionalId;
    }
    return regionalIds.isNotEmpty ? regionalIds.first : _legacyRegionalId;
  }

  /// Getter de compatibilidade legada: retorna o nome da regional primária/legada
  String get regional {
    if (_legacyRegional.isNotEmpty && regionais.contains(_legacyRegional)) {
      return _legacyRegional;
    }
    return regionais.isNotEmpty ? regionais.first : _legacyRegional;
  }

  /// Helper centralizado para verificar se a divisão atua em uma determinada regional
  bool atuaNaRegional(String? id) {
    if (id == null || id.isEmpty) return false;
    if (regionalIds.contains(id)) return true;
    return regionalId == id;
  }

  // Método para criar cópia com alterações
  Divisao copyWith({
    String? id,
    String? divisao,
    String? regionalId,
    String? regional,
    List<String>? regionalIds,
    List<String>? regionais,
    List<String>? segmentoIds,
    List<String>? segmentos,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Divisao(
      id: id ?? this.id,
      divisao: divisao ?? this.divisao,
      regionalId: regionalId ?? this.regionalId,
      regional: regional ?? this.regional,
      regionalIds: regionalIds ?? this.regionalIds,
      regionais: regionais ?? this.regionais,
      segmentoIds: segmentoIds ?? this.segmentoIds,
      segmentos: segmentos ?? this.segmentos,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Converter para Map (para Supabase)
  // Mantém dual-write populando regional_id legado com a regional primária
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'divisao': divisao,
      if (regionalId.isNotEmpty) 'regional_id': regionalId,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  // Criar a partir de Map (do Supabase)
  factory Divisao.fromMap(Map<String, dynamic> map) {
    // 1. Extrair regionais da relação many-to-many (divisoes_regionais)
    List<String> regionalIds = [];
    List<String> regionaisNomes = [];

    if (map['divisoes_regionais'] != null) {
      final relacionamentos = map['divisoes_regionais'];
      if (relacionamentos is List) {
        for (var rel in relacionamentos) {
          if (rel is Map<String, dynamic>) {
            final regionalData = rel['regionais'];
            if (regionalData != null) {
              Map<String, dynamic>? regMap;
              if (regionalData is Map<String, dynamic>) {
                regMap = regionalData;
              } else if (regionalData is List && regionalData.isNotEmpty) {
                regMap = regionalData[0] as Map<String, dynamic>?;
              }

              if (regMap != null) {
                final regId = regMap['id'] as String? ?? rel['regional_id'] as String?;
                final regNome = regMap['regional'] as String?;
                if (regId != null && regId.isNotEmpty && !regionalIds.contains(regId)) {
                  regionalIds.add(regId);
                }
                if (regNome != null && regNome.isNotEmpty && !regionaisNomes.contains(regNome)) {
                  regionaisNomes.add(regNome);
                }
              }
            } else if (rel['regional_id'] != null) {
              final regId = rel['regional_id'] as String;
              if (!regionalIds.contains(regId)) regionalIds.add(regId);
            }
          }
        }
      } else if (relacionamentos is Map<String, dynamic>) {
        final regionalData = relacionamentos['regionais'];
        if (regionalData is Map<String, dynamic>) {
          final regId = regionalData['id'] as String?;
          final regNome = regionalData['regional'] as String?;
          if (regId != null && regId.isNotEmpty) regionalIds.add(regId);
          if (regNome != null && regNome.isNotEmpty) regionaisNomes.add(regNome);
        }
      }
    }

    // Fallback para compatibilidade com estrutura antiga (se não houver N:N carregado)
    final legacyRegId = map['regional_id'] as String? ??
        (map['regionais'] is Map<String, dynamic>
            ? (map['regionais'] as Map<String, dynamic>)['id'] as String? ?? ''
            : '');
    final legacyRegNome = map['regionais'] is Map<String, dynamic>
        ? (map['regionais'] as Map<String, dynamic>)['regional'] as String? ?? ''
        : (map['regional'] as String? ?? '');

    if (regionalIds.isEmpty && legacyRegId.isNotEmpty) {
      regionalIds.add(legacyRegId);
    }
    if (regionaisNomes.isEmpty && legacyRegNome.isNotEmpty) {
      regionaisNomes.add(legacyRegNome);
    }

    // 2. Extrair segmentos da relação many-to-many (divisoes_segmentos)
    List<String> segmentoIds = [];
    List<String> segmentosNomes = [];

    if (map['divisoes_segmentos'] != null) {
      final relacionamentos = map['divisoes_segmentos'];
      if (relacionamentos is List) {
        for (var rel in relacionamentos) {
          if (rel is Map<String, dynamic>) {
            final segmentoData = rel['segmentos'];
            if (segmentoData != null) {
              Map<String, dynamic>? segmentoMap;
              if (segmentoData is Map<String, dynamic>) {
                segmentoMap = segmentoData;
              } else if (segmentoData is List && segmentoData.isNotEmpty) {
                segmentoMap = segmentoData[0] as Map<String, dynamic>?;
              }

              if (segmentoMap != null) {
                final segmentoId = segmentoMap['id'] as String?;
                final segmentoNome = segmentoMap['segmento'] as String?;
                if (segmentoId != null && segmentoId.isNotEmpty && !segmentoIds.contains(segmentoId)) {
                  segmentoIds.add(segmentoId);
                }
                if (segmentoNome != null && segmentoNome.isNotEmpty && !segmentosNomes.contains(segmentoNome)) {
                  segmentosNomes.add(segmentoNome);
                }
              }
            } else if (rel['segmento_id'] != null) {
              final segId = rel['segmento_id'] as String;
              if (!segmentoIds.contains(segId)) segmentoIds.add(segId);
            }
          }
        }
      } else if (relacionamentos is Map<String, dynamic>) {
        final segmentoData = relacionamentos['segmentos'];
        if (segmentoData is Map<String, dynamic>) {
          final segmentoId = segmentoData['id'] as String?;
          final segmentoNome = segmentoData['segmento'] as String?;
          if (segmentoId != null && segmentoId.isNotEmpty) segmentoIds.add(segmentoId);
          if (segmentoNome != null && segmentoNome.isNotEmpty) segmentosNomes.add(segmentoNome);
        }
      }
    }

    // Fallback para segmentos antigos
    if (segmentoIds.isEmpty && map['segmento_id'] != null) {
      final segmentoId = map['segmento_id'] as String?;
      if (segmentoId != null && segmentoId.isNotEmpty) {
        segmentoIds.add(segmentoId);
      }
    }
    if (segmentosNomes.isEmpty && map['segmentos'] != null) {
      final segmentoData = map['segmentos'];
      if (segmentoData is Map<String, dynamic>) {
        final segmentoNome = segmentoData['segmento'] as String? ?? '';
        if (segmentoNome.isNotEmpty) {
          segmentosNomes.add(segmentoNome);
        }
      }
    }

    return Divisao(
      id: map['id'] as String? ?? '',
      divisao: map['divisao'] as String? ?? '',
      regionalId: legacyRegId,
      regional: legacyRegNome,
      regionalIds: regionalIds,
      regionais: regionaisNomes,
      segmentoIds: segmentoIds,
      segmentos: segmentosNomes,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  @override
  String toString() {
    return 'Divisao(id: $id, divisao: $divisao, regionalIds: ${regionalIds.join(", ")}, regionais: ${regionais.join(", ")}, segmentos: ${segmentos.join(", ")})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Divisao && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
