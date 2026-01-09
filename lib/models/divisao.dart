class Divisao {
  final String id;
  final String divisao;
  final String regionalId; // ID da regional associada
  final String regional; // Nome da regional (para exibição)
  final List<String> segmentoIds; // IDs dos segmentos associados (múltiplos)
  final List<String> segmentos; // Nomes dos segmentos (para exibição)
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Divisao({
    required this.id,
    required this.divisao,
    required this.regionalId,
    this.regional = '',
    List<String>? segmentoIds,
    List<String>? segmentos,
    this.createdAt,
    this.updatedAt,
  }) : segmentoIds = segmentoIds ?? [],
       segmentos = segmentos ?? [];

  // Método para criar cópia com alterações
  Divisao copyWith({
    String? id,
    String? divisao,
    String? regionalId,
    String? regional,
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
      segmentoIds: segmentoIds ?? this.segmentoIds,
      segmentos: segmentos ?? this.segmentos,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Converter para Map (para Supabase)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'divisao': divisao,
      'regional_id': regionalId,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  // Criar a partir de Map (do Supabase)
  factory Divisao.fromMap(Map<String, dynamic> map) {
    // Extrair segmentos da relação many-to-many
    List<String> segmentoIds = [];
    List<String> segmentosNomes = [];
    
    // Debug: imprimir estrutura recebida
    if (map['divisoes_segmentos'] != null) {
      print('🔍 divisoes_segmentos encontrado: ${map['divisoes_segmentos']}');
      print('🔍 Tipo: ${map['divisoes_segmentos'].runtimeType}');
    }
    
    // Se vier da tabela de relacionamento (estrutura nova)
    if (map['divisoes_segmentos'] != null) {
      final relacionamentos = map['divisoes_segmentos'];
      if (relacionamentos is List) {
        print('🔍 Processando ${relacionamentos.length} relacionamentos');
        for (var rel in relacionamentos) {
          if (rel is Map<String, dynamic>) {
            print('🔍 Relacionamento: $rel');
            final segmentoData = rel['segmentos'];
            print('🔍 Segmento data: $segmentoData');
            
            if (segmentoData != null) {
              // Pode ser um Map ou um objeto aninhado
              Map<String, dynamic>? segmentoMap;
              if (segmentoData is Map<String, dynamic>) {
                segmentoMap = segmentoData;
              } else if (segmentoData is List && segmentoData.isNotEmpty) {
                // Se for uma lista, pegar o primeiro item
                segmentoMap = segmentoData[0] as Map<String, dynamic>?;
              }
              
              if (segmentoMap != null) {
                final segmentoId = segmentoMap['id'] as String?;
                final segmentoNome = segmentoMap['segmento'] as String?;
                print('🔍 Segmento ID: $segmentoId, Nome: $segmentoNome');
                if (segmentoId != null && segmentoId.isNotEmpty) {
                  segmentoIds.add(segmentoId);
                }
                if (segmentoNome != null && segmentoNome.isNotEmpty) {
                  segmentosNomes.add(segmentoNome);
                }
              }
            }
          }
        }
      } else if (relacionamentos is Map<String, dynamic>) {
        // Se for um único objeto ao invés de lista
        print('🔍 Relacionamento único: $relacionamentos');
        final segmentoData = relacionamentos['segmentos'];
        if (segmentoData is Map<String, dynamic>) {
          final segmentoId = segmentoData['id'] as String?;
          final segmentoNome = segmentoData['segmento'] as String?;
          if (segmentoId != null && segmentoId.isNotEmpty) {
            segmentoIds.add(segmentoId);
          }
          if (segmentoNome != null && segmentoNome.isNotEmpty) {
            segmentosNomes.add(segmentoNome);
          }
        }
      }
    }
    
    print('✅ Segmentos IDs extraídos: $segmentoIds');
    print('✅ Segmentos nomes extraídos: $segmentosNomes');
    
    // Fallback para compatibilidade com estrutura antiga (se houver segmento_id direto)
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
      id: map['id'] as String,
      divisao: map['divisao'] as String,
      regionalId: map['regional_id'] as String? ?? 
                  (map['regionais'] != null ? (map['regionais'] as Map<String, dynamic>)['id'] as String : ''),
      regional: map['regionais'] != null 
          ? (map['regionais'] as Map<String, dynamic>)['regional'] as String? ?? ''
          : (map['regional'] as String? ?? ''),
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
    return 'Divisao(id: $id, divisao: $divisao, regionalId: $regionalId, segmentos: ${segmentos.join(", ")})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Divisao && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

