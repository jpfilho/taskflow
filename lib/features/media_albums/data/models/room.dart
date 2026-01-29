import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'equipment.dart';

class Room {
  final String id; // ID único gerado (UUID baseado no nome)
  final String equipmentId; // ID da localização (Equipment) relacionada
  final String name; // Nome da sala (coluna sala de equipamentos_sap)
  final String? localizacao; // Localização relacionada (coluna localizacao de equipamentos_sap)
  final DateTime? createdAt;
  final DateTime? updatedAt;

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

  Room({
    required this.id,
    required this.equipmentId,
    required this.name,
    this.localizacao,
    this.createdAt,
    this.updatedAt,
  });

  factory Room.fromMap(Map<String, dynamic> map) {
    return Room(
      id: map['id'] as String,
      equipmentId: map['equipment_id'] as String,
      name: map['name'] as String,
      localizacao: map['localizacao'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  // Factory para criar a partir de dados de equipamentos_sap
  factory Room.fromEquipamentosSap(String sala, String localizacao) {
    // Gerar UUID determinístico baseado na sala + localização
    final id = generateDeterministicUuid('room:$sala:$localizacao');
    // Gerar equipmentId baseado na localização (deve corresponder ao Equipment)
    // IMPORTANTE: Usar o mesmo prefixo 'equipment:' que Equipment.fromEquipamentosSap
    final equipmentId = Equipment.generateDeterministicUuid('equipment:$localizacao');
    return Room(
      id: id,
      equipmentId: equipmentId,
      name: sala,
      localizacao: localizacao,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'equipment_id': equipmentId,
      'name': name,
      'localizacao': localizacao,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  Room copyWith({
    String? id,
    String? equipmentId,
    String? name,
    String? localizacao,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Room(
      id: id ?? this.id,
      equipmentId: equipmentId ?? this.equipmentId,
      name: name ?? this.name,
      localizacao: localizacao ?? this.localizacao,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
