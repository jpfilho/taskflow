import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class Equipment {
  final String id; // ID único gerado (UUID baseado no nome)
  final String? segmentId; // Opcional: ID do segmento relacionado
  final String name; // Nome para exibição (combina localizacao e local_instalacao)
  final String? equipamento; // Equipamento relacionado (coluna equipamento de equipamentos_sap)
  final String? localizacao; // Localização (coluna localizacao de equipamentos_sap) - para busca
  final String? localInstalacao; // Local de instalação (coluna local_instalacao de equipamentos_sap) - para busca
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Equipment({
    required this.id,
    this.segmentId,
    required this.name,
    this.equipamento,
    this.localizacao,
    this.localInstalacao,
    this.createdAt,
    this.updatedAt,
  });

  factory Equipment.fromMap(Map<String, dynamic> map) {
    return Equipment(
      id: map['id'] as String,
      segmentId: map['segment_id'] as String?,
      name: map['name'] as String,
      equipamento: map['equipamento'] as String?,
      localizacao: map['localizacao'] as String?,
      localInstalacao: map['local_instalacao'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  // Gerar UUID determinístico a partir de uma string (similar a UUID v5)
  // Método público para uso no repository
  static String generateDeterministicUuid(String input) {
    // Usar SHA-1 para gerar hash determinístico
    final bytes = utf8.encode(input);
    final hash = sha1.convert(bytes);
    final hashBytes = hash.bytes;
    
    // Converter para UUID v4 format (mas determinístico)
    // UUID v4: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
    // onde 4 indica versão 4 e y é 8, 9, A ou B
    final uuidBytes = List<int>.filled(16, 0);
    for (int i = 0; i < 16; i++) {
      uuidBytes[i] = hashBytes[i % hashBytes.length];
    }
    
    // Aplicar máscaras para UUID v4
    uuidBytes[6] = (uuidBytes[6] & 0x0f) | 0x40; // versão 4
    uuidBytes[8] = (uuidBytes[8] & 0x3f) | 0x80; // variante
    
    // Converter para string UUID
    final hex = uuidBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  // Factory para criar a partir de dados de equipamentos_sap
  factory Equipment.fromEquipamentosSap(
    String localizacao, {
    String? equipamento,
    String? localInstalacao,
  }) {
    // Gerar UUID determinístico baseado na localização
    final id = generateDeterministicUuid('equipment:$localizacao');
    
    // Combinar localizacao e local_instalacao para exibição
    // Priorizar localizacao (mais fácil de identificar) e adicionar local_instalacao se diferente
    String displayName;
    if (localInstalacao != null && 
        localInstalacao.trim().isNotEmpty && 
        localInstalacao.trim() != localizacao.trim()) {
      // Se ambos existem e são diferentes, mostrar: "localizacao (local_instalacao)"
      displayName = '${localizacao.trim()} (${localInstalacao.trim()})';
    } else {
      // Caso contrário, mostrar apenas localizacao
      displayName = localizacao.trim();
    }
    
    return Equipment(
      id: id,
      name: displayName,
      equipamento: equipamento,
      localizacao: localizacao.trim(),
      localInstalacao: localInstalacao?.trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'segment_id': segmentId,
      'name': name,
      'equipamento': equipamento,
      'localizacao': localizacao,
      'local_instalacao': localInstalacao,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  Equipment copyWith({
    String? id,
    String? segmentId,
    String? name,
    String? equipamento,
    String? localizacao,
    String? localInstalacao,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Equipment(
      id: id ?? this.id,
      segmentId: segmentId ?? this.segmentId,
      name: name ?? this.name,
      equipamento: equipamento ?? this.equipamento,
      localizacao: localizacao ?? this.localizacao,
      localInstalacao: localInstalacao ?? this.localInstalacao,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
