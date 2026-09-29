import 'package:flutter/foundation.dart';

/// Resumo factual de um dia específico para o carrossel horizontal de seleção de datas.
@immutable
class MobileAgendaDaySummary {
  final DateTime date;
  final int totalTasks;
  final int runningTasks;
  final int completedTasks;
  final int plannedTasks;
  final bool hasConflict;
  final bool isToday;

  const MobileAgendaDaySummary({
    required this.date,
    this.totalTasks = 0,
    this.runningTasks = 0,
    this.completedTasks = 0,
    this.plannedTasks = 0,
    this.hasConflict = false,
    this.isToday = false,
  });

  bool get isWeekend => date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
}

/// Item factual de tarefa projetado para renderização na agenda diária.
@immutable
class MobileAgendaTaskItem {
  final String taskId;
  final String codigo;
  final String titulo;
  final String statusRaw;
  final String statusLabel;
  final String? horarioInicio;
  final String? horarioFim;
  final String? local;
  final String? equipeNome;
  final String? veiculoNome;
  final bool hasConflict;
  final String? conflictReason;
  final bool isSyncPending;
  final String? priority;

  const MobileAgendaTaskItem({
    required this.taskId,
    required this.codigo,
    required this.titulo,
    required this.statusRaw,
    required this.statusLabel,
    this.horarioInicio,
    this.horarioFim,
    this.local,
    this.equipeNome,
    this.veiculoNome,
    this.hasConflict = false,
    this.conflictReason,
    this.isSyncPending = false,
    this.priority,
  });
}

/// Bloco cronológico de horário (ex: Manhã, Tarde, Noite ou faixa horária) contendo tarefas.
@immutable
class MobileAgendaSlot {
  final String title;
  final String timeRange;
  final List<MobileAgendaTaskItem> tasks;

  const MobileAgendaSlot({
    required this.title,
    required this.timeRange,
    required this.tasks,
  });
}

/// Agrupamento por equipe com as atividades programadas para o dia.
@immutable
class MobileTeamAgendaGroup {
  final String equipeId;
  final String equipeNome;
  final String? encarregadoNome;
  final List<String> membrosNomes;
  final String? veiculoPlaca;
  final List<MobileAgendaTaskItem> tasks;
  final bool hasConflict;

  const MobileTeamAgendaGroup({
    required this.equipeId,
    required this.equipeNome,
    this.encarregadoNome,
    this.membrosNomes = const [],
    this.veiculoPlaca,
    required this.tasks,
    this.hasConflict = false,
  });
}

/// Agrupamento por veículo da frota com as atividades programadas para o dia.
@immutable
class MobileFleetAgendaGroup {
  final String frotaId;
  final String veiculoNome;
  final String placa;
  final String tipoVeiculo;
  final String? equipeNome;
  final List<MobileAgendaTaskItem> tasks;
  final bool hasConflict;
  final bool emManutencao;

  const MobileFleetAgendaGroup({
    required this.frotaId,
    required this.veiculoNome,
    required this.placa,
    required this.tipoVeiculo,
    this.equipeNome,
    required this.tasks,
    this.hasConflict = false,
    this.emManutencao = false,
  });
}
