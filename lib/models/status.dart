import 'package:flutter/material.dart';

class Status {
  final String id;
  final String codigo; // 4 caracteres
  final String status; // Nome/descrição do status
  final String cor; // Cor em formato hexadecimal (ex: #FF5733)
  final String? corSegmento; // Cor de fundo do segmento em formato hexadecimal (ex: #FF5733)
  final String? corTextoSegmento; // Cor do texto do segmento em formato hexadecimal (ex: #FFFFFF)
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Status({
    required this.id,
    required this.codigo,
    required this.status,
    this.cor = '#2196F3', // Cor padrão azul
    this.corSegmento,
    this.corTextoSegmento,
    this.createdAt,
    this.updatedAt,
  });

  // Método auxiliar para obter Color a partir da string hexadecimal
  Color get color {
    try {
      return Color(int.parse(cor.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.blue; // Cor padrão em caso de erro
    }
  }

  // Método auxiliar para obter Color do segmento a partir da string hexadecimal
  Color get segmentBackgroundColor {
    if (corSegmento == null || corSegmento!.isEmpty) return Colors.grey;
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
  Status copyWith({
    String? id,
    String? codigo,
    String? status,
    String? cor,
    String? corSegmento,
    String? corTextoSegmento,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Status(
      id: id ?? this.id,
      codigo: codigo ?? this.codigo,
      status: status ?? this.status,
      cor: cor ?? this.cor,
      corSegmento: corSegmento ?? this.corSegmento,
      corTextoSegmento: corTextoSegmento ?? this.corTextoSegmento,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Converter para Map (para Supabase)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'codigo': codigo,
      'status': status,
      'cor': cor,
      'cor_segmento': corSegmento,
      'cor_texto_segmento': corTextoSegmento,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  // Criar a partir de Map (do Supabase)
  factory Status.fromMap(Map<String, dynamic> map) {
    return Status(
      id: map['id'] as String,
      codigo: map['codigo'] as String,
      status: map['status'] as String,
      cor: map['cor'] as String? ?? '#2196F3',
      corSegmento: map['cor_segmento'] as String?,
      corTextoSegmento: map['cor_texto_segmento'] as String?,
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
    return 'Status(id: $id, codigo: $codigo, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Status && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

