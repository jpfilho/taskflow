import '../utils/date_parser.dart';

class ProjetoEtapa {
  final String id;
  final String projetoId;
  final String macroetapaId;
  final String nome;
  final String? descricao;
  final int ordem;
  final DateTime? dataInicioPrevista;
  final DateTime? dataFimPrevista;
  final DateTime? dataInicioReal;
  final DateTime? dataFimReal;
  final String status;
  final double progresso;
  final double peso;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final String syncStatus;

  ProjetoEtapa({
    required this.id,
    required this.projetoId,
    required this.macroetapaId,
    required this.nome,
    this.descricao,
    this.ordem = 0,
    this.dataInicioPrevista,
    this.dataFimPrevista,
    this.dataInicioReal,
    this.dataFimReal,
    this.status = 'PENDENTE',
    this.progresso = 0.0,
    this.peso = 1.0,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.syncStatus = 'pending',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'projeto_id': projetoId,
      'macroetapa_id': macroetapaId,
      'nome': nome,
      'descricao': descricao,
      'ordem': ordem,
      'data_inicio_prevista': dataInicioPrevista?.millisecondsSinceEpoch,
      'data_fim_prevista': dataFimPrevista?.millisecondsSinceEpoch,
      'data_inicio_real': dataInicioReal?.millisecondsSinceEpoch,
      'data_fim_real': dataFimReal?.millisecondsSinceEpoch,
      'status': status,
      'progresso': progresso,
      'peso': peso,
      'created_at': createdAt?.millisecondsSinceEpoch,
      'updated_at': updatedAt?.millisecondsSinceEpoch,
      'deleted_at': deletedAt?.millisecondsSinceEpoch,
      'sync_status': syncStatus,
    };
  }

  factory ProjetoEtapa.fromMap(Map<String, dynamic> map) {
    return ProjetoEtapa(
      id: map['id'] ?? '',
      projetoId: map['projeto_id'] ?? '',
      macroetapaId: map['macroetapa_id'] ?? '',
      nome: map['nome'] ?? '',
      descricao: map['descricao'],
      ordem: map['ordem'] ?? 0,
      dataInicioPrevista: DateParser.parse(map['data_inicio_prevista']),
      dataFimPrevista: DateParser.parse(map['data_fim_prevista']),
      dataInicioReal: DateParser.parse(map['data_inicio_real']),
      dataFimReal: DateParser.parse(map['data_fim_real']),
      status: map['status'] ?? 'PENDENTE',
      progresso: (map['progresso'] ?? 0.0).toDouble(),
      peso: (map['peso'] ?? 1.0).toDouble(),
      createdAt: DateParser.parse(map['created_at']),
      updatedAt: DateParser.parse(map['updated_at']),
      deletedAt: DateParser.parse(map['deleted_at']),
      syncStatus: map['sync_status'] ?? 'pending',
    );
  }
}
