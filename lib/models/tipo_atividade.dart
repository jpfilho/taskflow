import 'package:flutter/material.dart';

class TipoAtividade {
  final String id;
  final String codigo;
  final String descricao;
  final bool ativo;
  final String? cor; // Cor hexadecimal opcional (formato: #RRGGBB)
  final String? corSegmento; // Cor de fundo do segmento em formato hexadecimal (ex: #FF5733)
  final String? corTextoSegmento; // Cor do texto do segmento em formato hexadecimal (ex: #FFFFFF)
  final List<String> segmentoIds; // IDs dos segmentos (many-to-many)
  final List<String> segmentos; // Nomes dos segmentos (carregado via join)
  final DateTime? createdAt;
  final DateTime? updatedAt;

  TipoAtividade({
    required this.id,
    required this.codigo,
    required this.descricao,
    this.ativo = true,
    this.cor,
    this.corSegmento,
    this.corTextoSegmento,
    this.segmentoIds = const [],
    this.segmentos = const [],
    this.createdAt,
    this.updatedAt,
  });

  // Método auxiliar para obter Color do segmento a partir da string hexadecimal
  Color get segmentBackgroundColor {
    if (corSegmento == null || corSegmento!.isEmpty) {
      // Se não houver cor de segmento, usar a cor principal
      if (cor != null && cor!.isNotEmpty) {
        try {
          return Color(int.parse(cor!.replaceFirst('#', '0xFF')));
        } catch (e) {
          return Colors.grey;
        }
      }
      return Colors.grey;
    }
    try {
      return Color(int.parse(corSegmento!.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.grey; // Cor padrão em caso de erro
    }
  }

  // Método auxiliar para obter Color do texto do segmento a partir da string hexadecimal
  Color get segmentTextColor {
    if (corTextoSegmento == null || corTextoSegmento!.isEmpty) return Colors.white;
    try {
      return Color(int.parse(corTextoSegmento!.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.white; // Cor padrão em caso de erro
    }
  }

  // Método para criar cópia com alterações
  TipoAtividade copyWith({
    String? id,
    String? codigo,
    String? descricao,
    bool? ativo,
    String? cor,
    String? corSegmento,
    String? corTextoSegmento,
    List<String>? segmentoIds,
    List<String>? segmentos,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TipoAtividade(
      id: id ?? this.id,
      codigo: codigo ?? this.codigo,
      descricao: descricao ?? this.descricao,
      ativo: ativo ?? this.ativo,
      cor: cor ?? this.cor,
      corSegmento: corSegmento ?? this.corSegmento,
      corTextoSegmento: corTextoSegmento ?? this.corTextoSegmento,
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
      'codigo': codigo,
      'descricao': descricao,
      'ativo': ativo,
      if (cor != null) 'cor': cor,
      'cor_segmento': corSegmento,
      'cor_texto_segmento': corTextoSegmento,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  // Criar a partir de Map (do Supabase)
  factory TipoAtividade.fromMap(Map<String, dynamic> map) {
    // Extrair lista de segmentos do join many-to-many
    List<String> segmentoIdsList = [];
    List<String> segmentosNomesList = [];
    
    if (map['tipos_atividade_segmentos'] != null) {
      final segmentosData = map['tipos_atividade_segmentos'];
      
      if (segmentosData is List) {
        for (var item in segmentosData) {
          if (item is Map<String, dynamic> && item['segmentos'] != null) {
            final segmentoData = item['segmentos'];
            if (segmentoData is Map<String, dynamic>) {
              final segmentoId = segmentoData['id'] as String?;
              final segmentoNome = segmentoData['segmento'] as String?;
              if (segmentoId != null) {
                segmentoIdsList.add(segmentoId);
                if (segmentoNome != null) {
                  segmentosNomesList.add(segmentoNome);
                }
              }
            }
          }
        }
      } else if (segmentosData is Map<String, dynamic>) {
        // Caso seja um único objeto ao invés de lista
        if (segmentosData['segmentos'] != null) {
          final segmentoData = segmentosData['segmentos'];
          if (segmentoData is Map<String, dynamic>) {
            final segmentoId = segmentoData['id'] as String?;
            final segmentoNome = segmentoData['segmento'] as String?;
            if (segmentoId != null) {
              segmentoIdsList.add(segmentoId);
              if (segmentoNome != null) {
                segmentosNomesList.add(segmentoNome);
              }
            }
          }
        }
      }
    }

    return TipoAtividade(
      id: map['id'] as String,
      codigo: map['codigo'] as String,
      descricao: map['descricao'] as String,
      ativo: map['ativo'] as bool? ?? true,
      cor: map['cor'] as String?,
      corSegmento: map['cor_segmento'] as String?,
      corTextoSegmento: map['cor_texto_segmento'] as String?,
      segmentoIds: segmentoIdsList,
      segmentos: segmentosNomesList,
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
    return 'TipoAtividade(id: $id, codigo: $codigo, descricao: $descricao, segmentos: $segmentos)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TipoAtividade && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}


