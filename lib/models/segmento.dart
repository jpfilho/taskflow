import 'package:flutter/material.dart';

class Segmento {
  final String id;
  final String segmento;
  final String? descricao;
  final String? cor; // Cor de fundo em formato hexadecimal (ex: #FF5733)
  final String? corTexto; // Cor do texto em formato hexadecimal (ex: #FFFFFF)
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Segmento({
    required this.id,
    required this.segmento,
    this.descricao,
    this.cor,
    this.corTexto,
    this.createdAt,
    this.updatedAt,
  });

  // Método auxiliar para obter Color a partir da string hexadecimal
  Color get backgroundColor {
    if (cor == null || cor!.isEmpty) return Colors.grey;
    try {
      return Color(int.parse(cor!.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.grey; // Cor padrão em caso de erro
    }
  }

  // Método auxiliar para obter Color do texto a partir da string hexadecimal
  Color get textColor {
    if (corTexto == null || corTexto!.isEmpty) return Colors.white;
    try {
      return Color(int.parse(corTexto!.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.white; // Cor padrão em caso de erro
    }
  }

  // Método para criar cópia com alterações
  Segmento copyWith({
    String? id,
    String? segmento,
    String? descricao,
    String? cor,
    String? corTexto,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Segmento(
      id: id ?? this.id,
      segmento: segmento ?? this.segmento,
      descricao: descricao ?? this.descricao,
      cor: cor ?? this.cor,
      corTexto: corTexto ?? this.corTexto,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Converter para Map (para Supabase)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'segmento': segmento,
      'descricao': descricao,
      'cor': cor,
      'cor_texto': corTexto,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  // Criar a partir de Map (do Supabase)
  factory Segmento.fromMap(Map<String, dynamic> map) {
    return Segmento(
      id: map['id'] as String,
      segmento: map['segmento'] as String,
      descricao: map['descricao'] as String?,
      cor: map['cor'] as String?,
      corTexto: map['cor_texto'] as String?,
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
    return 'Segmento(id: $id, segmento: $segmento)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Segmento && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}







