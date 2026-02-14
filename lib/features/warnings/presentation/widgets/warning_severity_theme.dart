import 'package:flutter/material.dart';
import '../../data/models/task_warning.dart';

/// Cores e labels por severidade para uso em badge, drawer e dashboard.
class WarningSeverityTheme {
  static Color colorForSeverity(String severity) {
    switch (severity.toUpperCase()) {
      case 'HIGH':
        return Colors.red.shade700;
      case 'MEDIUM':
        return Colors.orange.shade700;
      case 'LOW':
        return Colors.amber.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  static Color backgroundColorForSeverity(String severity) {
    switch (severity.toUpperCase()) {
      case 'HIGH':
        return Colors.red.shade50;
      case 'MEDIUM':
        return Colors.orange.shade50;
      case 'LOW':
        return Colors.amber.shade50;
      default:
        return Colors.grey.shade100;
    }
  }

  static String labelForSeverity(String severity) {
    switch (severity.toUpperCase()) {
      case 'HIGH':
        return 'Alta Prioridade';
      case 'MEDIUM':
        return 'Média';
      case 'LOW':
        return 'Baixa';
      default:
        return severity;
    }
  }

  /// Maior severidade da lista (HIGH > MEDIUM > LOW).
  static String maxSeverity(List<TaskWarning> warnings) {
    if (warnings.isEmpty) return 'LOW';
    return warnings.reduce((a, b) =>
        TaskWarning.severityOrder(a.severity) >= TaskWarning.severityOrder(b.severity) ? a : b).severity;
  }
}
