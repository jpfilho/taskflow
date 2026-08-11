import '../utils/date_parser.dart';

class ProjetoDependencia {
  final String id;
  final String projetoId;
  final String atividadePredecessoraId;
  final String atividadeSucessoraId;
  final String tipo; // FS, SS, FF, SF
  final double lagDias;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final String syncStatus;

  ProjetoDependencia({
    required this.id,
    required this.projetoId,
    required this.atividadePredecessoraId,
    required this.atividadeSucessoraId,
    this.tipo = 'FS',
    this.lagDias = 0.0,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.syncStatus = 'pending',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'projeto_id': projetoId,
      'atividade_predecessora_id': atividadePredecessoraId,
      'atividade_sucessora_id': atividadeSucessoraId,
      'tipo': tipo,
      'lag_dias': lagDias,
      'created_at': createdAt?.millisecondsSinceEpoch,
      'updated_at': updatedAt?.millisecondsSinceEpoch,
      'deleted_at': deletedAt?.millisecondsSinceEpoch,
      'sync_status': syncStatus,
    };
  }

  factory ProjetoDependencia.fromMap(Map<String, dynamic> map) {
    return ProjetoDependencia(
      id: map['id'] ?? '',
      projetoId: map['projeto_id'] ?? '',
      atividadePredecessoraId: map['atividade_predecessora_id'] ?? '',
      atividadeSucessoraId: map['atividade_sucessora_id'] ?? '',
      tipo: map['tipo'] ?? 'FS',
      lagDias: (map['lag_dias'] ?? 0.0).toDouble(),
      createdAt: DateParser.parse(map['created_at']),
      updatedAt: DateParser.parse(map['updated_at']),
      deletedAt: DateParser.parse(map['deleted_at']),
      syncStatus: map['sync_status'] ?? 'pending',
    );
  }
}
