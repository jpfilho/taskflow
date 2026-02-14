import 'package:flutter/material.dart';

class DocumentStatus {
  final String id;
  final String nome;
  final String? descricao;
  final String? corFundo;
  final String? corTexto;
  final bool ativo;
  final int ordem;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  const DocumentStatus({
    required this.id,
    required this.nome,
    this.descricao,
    this.corFundo,
    this.corTexto,
    this.ativo = true,
    this.ordem = 0,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  Color get backgroundColor {
    if (corFundo == null || corFundo!.isEmpty) return Colors.grey;
    try {
      return Color(int.parse(corFundo!.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.grey;
    }
  }

  Color get textColor {
    if (corTexto == null || corTexto!.isEmpty) return Colors.white;
    try {
      return Color(int.parse(corTexto!.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.white;
    }
  }

  factory DocumentStatus.fromMap(Map<String, dynamic> map) {
    return DocumentStatus(
      id: map['id'] as String,
      nome: map['nome'] as String,
      descricao: map['descricao'] as String?,
      corFundo: map['cor_fundo'] as String?,
      corTexto: map['cor_texto'] as String?,
      ativo: map['ativo'] as bool? ?? true,
      ordem: map['ordem'] as int? ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String)
          : null,
      createdBy: map['created_by'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      if (descricao != null) 'descricao': descricao,
      if (corFundo != null) 'cor_fundo': corFundo,
      if (corTexto != null) 'cor_texto': corTexto,
      'ativo': ativo,
      'ordem': ordem,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      if (createdBy != null) 'created_by': createdBy,
    };
  }

  DocumentStatus copyWith({
    String? id,
    String? nome,
    String? descricao,
    String? corFundo,
    String? corTexto,
    bool? ativo,
    int? ordem,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return DocumentStatus(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      descricao: descricao ?? this.descricao,
      corFundo: corFundo ?? this.corFundo,
      corTexto: corTexto ?? this.corTexto,
      ativo: ativo ?? this.ativo,
      ordem: ordem ?? this.ordem,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
