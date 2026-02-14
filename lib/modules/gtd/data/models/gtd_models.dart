// Modelos/entidades GTD (compatíveis com local e remoto).

class GtdContext {
  final String id;
  final String userId;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GtdContext({
    required this.id,
    required this.userId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'name': name,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  static GtdContext fromJson(Map<String, dynamic> json) => GtdContext(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    name: json['name'] as String,
    createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
    updatedAt: DateTime.parse(json['updated_at'] as String).toUtc(),
  );
}

class GtdProject {
  final String id;
  final String userId;
  final String name;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GtdProject({
    required this.id,
    required this.userId,
    required this.name,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'name': name,
    'notes': notes,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  static GtdProject fromJson(Map<String, dynamic> json) => GtdProject(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    name: json['name'] as String,
    notes: json['notes'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
    updatedAt: DateTime.parse(json['updated_at'] as String).toUtc(),
  );
}

class GtdInboxItem {
  final String id;
  final String userId;
  final String content;
  final DateTime? processedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GtdInboxItem({
    required this.id,
    required this.userId,
    required this.content,
    this.processedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isProcessed => processedAt != null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'content': content,
    'processed_at': processedAt?.toUtc().toIso8601String(),
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  static GtdInboxItem fromJson(Map<String, dynamic> json) => GtdInboxItem(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    content: json['content'] as String,
    processedAt: json['processed_at'] != null
        ? DateTime.parse(json['processed_at'] as String).toUtc()
        : null,
    createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
    updatedAt: DateTime.parse(json['updated_at'] as String).toUtc(),
  );
}

class GtdReferenceItem {
  final String id;
  final String userId;
  final String title;
  final String? content;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GtdReferenceItem({
    required this.id,
    required this.userId,
    required this.title,
    this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'title': title,
    'content': content,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  static GtdReferenceItem fromJson(Map<String, dynamic> json) =>
      GtdReferenceItem(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        title: json['title'] as String,
        content: json['content'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
        updatedAt: DateTime.parse(json['updated_at'] as String).toUtc(),
      );
}

enum GtdActionStatus { next, waiting, someday, done }

extension GtdActionStatusExt on GtdActionStatus {
  String get value => name;
  static GtdActionStatus fromString(String s) {
    return GtdActionStatus.values.firstWhere(
      (e) => e.name == s,
      orElse: () => GtdActionStatus.next,
    );
  }
}

/// Regra de recorrência para tarefas de rotina: daily, weekly, monthly.
const List<String> gtdRecurrenceRules = ['daily', 'weekly', 'monthly'];

/// Valores de prioridade: high (alta), med (média), low (baixa).
const List<String> gtdPriorityValues = ['high', 'med', 'low'];

String gtdPriorityLabel(String value) {
  switch (value) {
    case 'high': return 'Alta';
    case 'med': return 'Média';
    case 'low': return 'Baixa';
    default: return value;
  }
}

class GtdAction {
  final String id;
  final String userId;
  final String? projectId;
  final String? contextId;
  final String title;
  final GtdActionStatus status;
  final String? energy; // low, med, high
  final String? priority; // high (alta), med (média), low (baixa)
  final int? timeMin;
  final DateTime? dueAt;
  final String? waitingFor;
  final String? notes;
  final String? linkedTaskId;
  final bool isRoutine;
  final String? recurrenceRule; // daily, weekly, monthly
  final String? recurrenceWeekdays; // para weekly: 0=dom,1=seg,...,6=sáb
  final DateTime? alarmAt; // data/hora do alarme (lembrete)
  final String? sourceInboxId; // id do item do inbox que originou esta ação
  final String? delegatedToUserId; // id do usuário a quem a ação foi delegada
  final DateTime createdAt;
  final DateTime updatedAt;

  const GtdAction({
    required this.id,
    required this.userId,
    this.projectId,
    this.contextId,
    required this.title,
    this.status = GtdActionStatus.next,
    this.energy,
    this.priority,
    this.timeMin,
    this.dueAt,
    this.waitingFor,
    this.notes,
    this.linkedTaskId,
    this.isRoutine = false,
    this.recurrenceRule,
    this.recurrenceWeekdays,
    this.alarmAt,
    this.sourceInboxId,
    this.delegatedToUserId,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'project_id': projectId,
        'context_id': contextId,
        'title': title,
        'status': status.value,
        'energy': energy,
        'priority': priority,
        'time_min': timeMin,
        'due_at': dueAt?.toUtc().toIso8601String(),
        'waiting_for': waitingFor,
        'notes': notes,
        'linked_task_id': linkedTaskId,
        'is_routine': isRoutine,
        'recurrence_rule': recurrenceRule,
        'recurrence_weekdays': recurrenceWeekdays,
        'alarm_at': alarmAt?.toUtc().toIso8601String(),
        'source_inbox_id': sourceInboxId,
        'delegated_to_user_id': delegatedToUserId,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  static GtdAction fromJson(Map<String, dynamic> json) => GtdAction(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        projectId: json['project_id'] as String?,
        contextId: json['context_id'] as String?,
        title: json['title'] as String,
        status: GtdActionStatusExt.fromString(
          (json['status'] as String?) ?? 'next',
        ),
        energy: json['energy'] as String?,
        priority: json['priority'] as String?,
        timeMin: json['time_min'] as int?,
        dueAt: json['due_at'] != null
            ? DateTime.parse(json['due_at'] as String).toUtc()
            : null,
        waitingFor: json['waiting_for'] as String?,
        notes: json['notes'] as String?,
        linkedTaskId: json['linked_task_id'] as String?,
        isRoutine: json['is_routine'] == true,
        recurrenceRule: json['recurrence_rule'] as String?,
        recurrenceWeekdays: json['recurrence_weekdays'] as String?,
        alarmAt: json['alarm_at'] != null
            ? DateTime.parse(json['alarm_at'] as String).toUtc()
            : null,
        sourceInboxId: json['source_inbox_id'] as String?,
        delegatedToUserId: json['delegated_to_user_id'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
        updatedAt: DateTime.parse(json['updated_at'] as String).toUtc(),
      );

  GtdAction copyWith({
    String? title,
    String? projectId,
    String? contextId,
    GtdActionStatus? status,
    String? energy,
    String? priority,
    int? timeMin,
    DateTime? dueAt,
    String? waitingFor,
    String? notes,
    String? linkedTaskId,
    bool? isRoutine,
    String? recurrenceRule,
    String? recurrenceWeekdays,
    DateTime? alarmAt,
    bool clearAlarm = false,
    String? sourceInboxId,
    String? delegatedToUserId,
    DateTime? updatedAt,
  }) =>
      GtdAction(
        id: id,
        userId: userId,
        projectId: projectId ?? this.projectId,
        contextId: contextId ?? this.contextId,
        title: title ?? this.title,
        status: status ?? this.status,
        energy: energy ?? this.energy,
        priority: priority ?? this.priority,
        timeMin: timeMin ?? this.timeMin,
        dueAt: dueAt ?? this.dueAt,
        waitingFor: waitingFor ?? this.waitingFor,
        notes: notes ?? this.notes,
        linkedTaskId: linkedTaskId ?? this.linkedTaskId,
        isRoutine: isRoutine ?? this.isRoutine,
        recurrenceRule: recurrenceRule ?? this.recurrenceRule,
        recurrenceWeekdays:
            recurrenceWeekdays ?? this.recurrenceWeekdays,
        alarmAt: clearAlarm ? null : (alarmAt ?? this.alarmAt),
        sourceInboxId: sourceInboxId ?? this.sourceInboxId,
        delegatedToUserId: delegatedToUserId ?? this.delegatedToUserId,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

class GtdWeeklyReview {
  final String id;
  final String userId;
  final String? notes;
  final DateTime completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GtdWeeklyReview({
    required this.id,
    required this.userId,
    this.notes,
    required this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'notes': notes,
    'completed_at': completedAt.toUtc().toIso8601String(),
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  static GtdWeeklyReview fromJson(Map<String, dynamic> json) => GtdWeeklyReview(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    notes: json['notes'] as String?,
    completedAt: DateTime.parse(json['completed_at'] as String).toUtc(),
    createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
    updatedAt: DateTime.parse(json['updated_at'] as String).toUtc(),
  );
}

/// Item da fila de sincronização (sync_queue).
class GtdSyncQueueItem {
  final int id;
  final String entity;
  final String entityId;
  final String op; // upsert, delete
  final String payloadJson;
  final DateTime createdAt;
  final DateTime nextRetryAt;
  final int tries;
  final String? lastError;

  const GtdSyncQueueItem({
    required this.id,
    required this.entity,
    required this.entityId,
    required this.op,
    required this.payloadJson,
    required this.createdAt,
    required this.nextRetryAt,
    required this.tries,
    this.lastError,
  });
}
