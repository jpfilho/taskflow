/// Modelo de um alerta/warning de tarefa (W1, W2, ...).
class TaskWarning {
  final String taskId;
  final String warningCode;
  final String severity; // HIGH, MEDIUM, LOW
  final String message;
  final String fixHint;
  final Map<String, dynamic>? detailsJson;
  final DateTime? createdAt;
  final DateTime? taskUpdatedAt;

  const TaskWarning({
    required this.taskId,
    required this.warningCode,
    required this.severity,
    required this.message,
    required this.fixHint,
    this.detailsJson,
    this.createdAt,
    this.taskUpdatedAt,
  });

  /// Aceita snake_case (PostgREST) ou camelCase. task_id pode vir como UUID string.
  factory TaskWarning.fromMap(Map<String, dynamic> map) {
    String v(String snake, String camel) => (map[snake] ?? map[camel])?.toString().trim() ?? '';
    Object? d(String snake, String camel) => map[snake] ?? map[camel];
    final taskId = (d('task_id', 'taskId'))?.toString().trim() ?? '';
    final details = d('details_json', 'detailsJson');
    final detailsJson = details is Map ? Map<String, dynamic>.from(details as Map<String, dynamic>) : null;
    return TaskWarning(
      taskId: taskId,
      warningCode: v('warning_code', 'warningCode'),
      severity: (v('severity', 'severity').isEmpty ? 'MEDIUM' : v('severity', 'severity')).toUpperCase(),
      message: v('message', 'message'),
      fixHint: v('fix_hint', 'fixHint'),
      detailsJson: detailsJson,
      createdAt: _parseDateTime(d('created_at', 'createdAt')),
      taskUpdatedAt: _parseDateTime(d('task_updated_at', 'taskUpdatedAt')),
    );
  }

  static DateTime? _parseDateTime(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  /// Ordem de prioridade para cor: HIGH > MEDIUM > LOW.
  static int severityOrder(String s) {
    switch (s.toUpperCase()) {
      case 'HIGH':
        return 3;
      case 'MEDIUM':
        return 2;
      case 'LOW':
        return 1;
      default:
        return 0;
    }
  }
}
