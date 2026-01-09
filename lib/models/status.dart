import 'package:flutter/material.dart';

class Status {
  final String id;
  final String codigo; // 4 caracteres
  final String status; // Nome/descrição do status
  final String cor; // Cor em formato hexadecimal (ex: #FF5733)
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Status({
    required this.id,
    required this.codigo,
    required this.status,
    this.cor = '#2196F3', // Cor padrão azul
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

  // Método para criar cópia com alterações
  Status copyWith({
    String? id,
    String? codigo,
    String? status,
    String? cor,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Status(
      id: id ?? this.id,
      codigo: codigo ?? this.codigo,
      status: status ?? this.status,
      cor: cor ?? this.cor,
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

