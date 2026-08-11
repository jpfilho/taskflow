import '../utils/date_parser.dart';

class ProjetoMarco {
  final String id;
  final String projetoId;
  final String nome;
  final String? descricao;
  final DateTime? dataPrevista;
  final DateTime? dataReal;
  final String status;
  final int ordem;
  final String criticidade;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final String syncStatus;

  ProjetoMarco({
    required this.id,
    required this.projetoId,
    required this.nome,
    this.descricao,
    this.dataPrevista,
    this.dataReal,
    this.status = 'PENDENTE',
    this.ordem = 0,
    this.criticidade = 'ALTA',
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.syncStatus = 'pending',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'projeto_id': projetoId,
      'nome': nome,
      'descricao': descricao,
      'data_prevista': dataPrevista?.millisecondsSinceEpoch,
      'data_real': dataReal?.millisecondsSinceEpoch,
      'status': status,
      'ordem': ordem,
      'criticidade': criticidade,
      'created_at': createdAt?.millisecondsSinceEpoch,
      'updated_at': updatedAt?.millisecondsSinceEpoch,
      'deleted_at': deletedAt?.millisecondsSinceEpoch,
      'sync_status': syncStatus,
    };
  }

  factory ProjetoMarco.fromMap(Map<String, dynamic> map) {
    return ProjetoMarco(
      id: map['id'] ?? '',
      projetoId: map['projeto_id'] ?? '',
      nome: map['nome'] ?? '',
      descricao: map['descricao'],
      dataPrevista: DateParser.parse(map['data_prevista']),
      dataReal: DateParser.parse(map['data_real']),
      status: map['status'] ?? 'PENDENTE',
      ordem: map['ordem'] ?? 0,
      criticidade: map['criticidade'] ?? 'ALTA',
      createdAt: DateParser.parse(map['created_at']),
      updatedAt: DateParser.parse(map['updated_at']),
      deletedAt: DateParser.parse(map['deleted_at']),
      syncStatus: map['sync_status'] ?? 'pending',
    );
  }
}
