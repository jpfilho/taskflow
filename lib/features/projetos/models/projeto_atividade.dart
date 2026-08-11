import '../utils/date_parser.dart';

class ProjetoAtividade {
  final String id;
  final String projetoId;
  final String macroetapaId;
  final String etapaId;
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
  final String prioridade;
  final String criticidade;
  final bool bloqueada;
  final String? motivoBloqueio;
  final String? executorId;
  final String? equipeId;
  final double? horasPrevistas;
  final double? horasRealizadas;
  final String? taskId;
  final String? createdBy;
  final String? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final String syncStatus;

  ProjetoAtividade({
    required this.id,
    required this.projetoId,
    required this.macroetapaId,
    required this.etapaId,
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
    this.prioridade = 'MEDIA',
    this.criticidade = 'MEDIA',
    this.bloqueada = false,
    this.motivoBloqueio,
    this.executorId,
    this.equipeId,
    this.horasPrevistas,
    this.horasRealizadas,
    this.taskId,
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
      'projeto_id': projetoId,
      'macroetapa_id': macroetapaId,
      'etapa_id': etapaId,
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
      'prioridade': prioridade,
      'criticidade': criticidade,
      'bloqueada': bloqueada ? 1 : 0,
      'motivo_bloqueio': motivoBloqueio,
      'executor_id': executorId,
      'equipe_id': equipeId,
      'horas_previstas': horasPrevistas,
      'horas_realizadas': horasRealizadas,
      'task_id': taskId,
      'created_by': createdBy,
      'updated_by': updatedBy,
      'created_at': createdAt?.millisecondsSinceEpoch,
      'updated_at': updatedAt?.millisecondsSinceEpoch,
      'deleted_at': deletedAt?.millisecondsSinceEpoch,
      'sync_status': syncStatus,
    };
  }

  factory ProjetoAtividade.fromMap(Map<String, dynamic> map) {
    return ProjetoAtividade(
      id: map['id'] ?? '',
      projetoId: map['projeto_id'] ?? '',
      macroetapaId: map['macroetapa_id'] ?? '',
      etapaId: map['etapa_id'] ?? '',
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
      prioridade: map['prioridade'] ?? 'MEDIA',
      criticidade: map['criticidade'] ?? 'MEDIA',
      bloqueada: map['bloqueada'] == 1 || map['bloqueada'] == true,
      motivoBloqueio: map['motivo_bloqueio'],
      executorId: map['executor_id'],
      equipeId: map['equipe_id'],
      horasPrevistas: map['horas_previstas']?.toDouble(),
      horasRealizadas: map['horas_realizadas']?.toDouble(),
      taskId: map['task_id'],
      createdBy: map['created_by'],
      updatedBy: map['updated_by'],
      createdAt: DateParser.parse(map['created_at']),
      updatedAt: DateParser.parse(map['updated_at']),
      deletedAt: DateParser.parse(map['deleted_at']),
      syncStatus: map['sync_status'] ?? 'pending',
    );
  }
}
