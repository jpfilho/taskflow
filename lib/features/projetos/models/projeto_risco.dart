import '../utils/date_parser.dart';

class ProjetoRisco {
  final String id;
  final String projetoId;
  final String titulo;
  final String? descricao;
  final String? categoria;
  final String? probabilidade;
  final String? impacto;
  final String? criticidade;
  final String? responsavelId;
  final String? planoMitigacao;
  final String? planoContingencia;
  final String status;
  final DateTime? dataIdentificacao;
  final DateTime? dataLimite;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final String syncStatus;

  ProjetoRisco({
    required this.id,
    required this.projetoId,
    required this.titulo,
    this.descricao,
    this.categoria,
    this.probabilidade,
    this.impacto,
    this.criticidade,
    this.responsavelId,
    this.planoMitigacao,
    this.planoContingencia,
    this.status = 'IDENTIFICADO',
    this.dataIdentificacao,
    this.dataLimite,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.syncStatus = 'pending',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'projeto_id': projetoId,
      'titulo': titulo,
      'descricao': descricao,
      'categoria': categoria,
      'probabilidade': probabilidade,
      'impacto': impacto,
      'criticidade': criticidade,
      'responsavel_id': responsavelId,
      'plano_mitigacao': planoMitigacao,
      'plano_contingencia': planoContingencia,
      'status': status,
      'data_identificacao': dataIdentificacao?.millisecondsSinceEpoch,
      'data_limite': dataLimite?.millisecondsSinceEpoch,
      'created_at': createdAt?.millisecondsSinceEpoch,
      'updated_at': updatedAt?.millisecondsSinceEpoch,
      'deleted_at': deletedAt?.millisecondsSinceEpoch,
      'sync_status': syncStatus,
    };
  }

  factory ProjetoRisco.fromMap(Map<String, dynamic> map) {
    return ProjetoRisco(
      id: map['id'] ?? '',
      projetoId: map['projeto_id'] ?? '',
      titulo: map['titulo'] ?? '',
      descricao: map['descricao'],
      categoria: map['categoria'],
      probabilidade: map['probabilidade'],
      impacto: map['impacto'],
      criticidade: map['criticidade'],
      responsavelId: map['responsavel_id'],
      planoMitigacao: map['plano_mitigacao'],
      planoContingencia: map['plano_contingencia'],
      status: map['status'] ?? 'IDENTIFICADO',
      dataIdentificacao: DateParser.parse(map['data_identificacao']),
      dataLimite: DateParser.parse(map['data_limite']),
      createdAt: DateParser.parse(map['created_at']),
      updatedAt: DateParser.parse(map['updated_at']),
      deletedAt: DateParser.parse(map['deleted_at']),
      syncStatus: map['sync_status'] ?? 'pending',
    );
  }
}
