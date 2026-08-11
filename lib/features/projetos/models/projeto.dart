import '../utils/date_parser.dart';

class Projeto {
  final String id;
  final String? codigo;
  final String nome;
  final String? descricao;
  final String? categoria;
  final String? tipo;
  final String status;
  final String prioridade;
  final String? regionalId;
  final String? divisaoId;
  final String? segmentoId;
  final String? localId;
  final String? coordenadorId;
  final String? responsavelId;
  final DateTime? dataInicioPrevista;
  final DateTime? dataFimPrevista;
  final DateTime? dataInicioReal;
  final DateTime? dataFimReal;
  final double progresso;
  final double? orcamentoPrevisto;
  final double? orcamentoRealizado;
  final String? createdBy;
  final String? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final String syncStatus;

  Projeto({
    required this.id,
    this.codigo,
    required this.nome,
    this.descricao,
    this.categoria,
    this.tipo,
    this.status = 'EM PLANEJAMENTO',
    this.prioridade = 'MEDIA',
    this.regionalId,
    this.divisaoId,
    this.segmentoId,
    this.localId,
    this.coordenadorId,
    this.responsavelId,
    this.dataInicioPrevista,
    this.dataFimPrevista,
    this.dataInicioReal,
    this.dataFimReal,
    this.progresso = 0.0,
    this.orcamentoPrevisto,
    this.orcamentoRealizado,
    this.createdBy,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.syncStatus = 'pending',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'codigo': codigo,
      'nome': nome,
      'descricao': descricao,
      'categoria': categoria,
      'tipo': tipo,
      'status': status,
      'prioridade': prioridade,
      'regional_id': regionalId,
      'divisao_id': divisaoId,
      'segmento_id': segmentoId,
      'local_id': localId,
      'coordenador_id': coordenadorId,
      'responsavel_id': responsavelId,
      'data_inicio_prevista': dataInicioPrevista?.millisecondsSinceEpoch,
      'data_fim_prevista': dataFimPrevista?.millisecondsSinceEpoch,
      'data_inicio_real': dataInicioReal?.millisecondsSinceEpoch,
      'data_fim_real': dataFimReal?.millisecondsSinceEpoch,
      'progresso': progresso,
      'orcamento_previsto': orcamentoPrevisto,
      'orcamento_realizado': orcamentoRealizado,
      'created_by': createdBy,
      'updated_by': updatedBy,
      'created_at': createdAt?.millisecondsSinceEpoch,
      'updated_at': updatedAt?.millisecondsSinceEpoch,
      'deleted_at': deletedAt?.millisecondsSinceEpoch,
      'sync_status': syncStatus,
    };
  }

  factory Projeto.fromMap(Map<String, dynamic> map) {
    return Projeto(
      id: map['id'] ?? '',
      codigo: map['codigo'],
      nome: map['nome'] ?? '',
      descricao: map['descricao'],
      categoria: map['categoria'],
      tipo: map['tipo'],
      status: map['status'] ?? 'EM PLANEJAMENTO',
      prioridade: map['prioridade'] ?? 'MEDIA',
      regionalId: map['regional_id'],
      divisaoId: map['divisao_id'],
      segmentoId: map['segmento_id'],
      localId: map['local_id'],
      coordenadorId: map['coordenador_id'],
      responsavelId: map['responsavel_id'],
      dataInicioPrevista: DateParser.parse(map['data_inicio_prevista']),
      dataFimPrevista: DateParser.parse(map['data_fim_prevista']),
      dataInicioReal: DateParser.parse(map['data_inicio_real']),
      dataFimReal: DateParser.parse(map['data_fim_real']),
      progresso: (map['progresso'] ?? 0.0).toDouble(),
      orcamentoPrevisto: map['orcamento_previsto']?.toDouble(),
      orcamentoRealizado: map['orcamento_realizado']?.toDouble(),
      createdBy: map['created_by'],
      updatedBy: map['updated_by'],
      createdAt: DateParser.parse(map['created_at']),
      updatedAt: DateParser.parse(map['updated_at']),
      deletedAt: DateParser.parse(map['deleted_at']),
      syncStatus: map['sync_status'] ?? 'pending',
    );
  }
}
