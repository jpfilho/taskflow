import '../enums/execution_status.dart';
import '../models/chat_item_feedback.dart';

class ChatFeedbackValidator {
  /// Valida se o feedback possui regras de negócio consistentes
  static String? validateFeedback(ChatItemFeedback feedback) {
    // 1. Percentual
    if (feedback.executionStatus == ExecutionStatus.executado) {
      if (feedback.executionPercentage != null && feedback.executionPercentage != 100) {
        return 'Item executado deve ter 100% de progresso.';
      }
    }

    if (feedback.executionStatus == ExecutionStatus.parcial) {
      if (feedback.executionPercentage == null || feedback.executionPercentage! <= 0 || feedback.executionPercentage! >= 100) {
        return 'Item parcialmente executado deve ter progresso entre 1% e 99%.';
      }
      if (feedback.comment == null || feedback.comment!.trim().isEmpty) {
        return 'É obrigatório justificar um item parcialmente executado.';
      }
    }

    if (feedback.executionStatus == ExecutionStatus.naoExecutado) {
      if (feedback.executionPercentage != null && feedback.executionPercentage != 0) {
        return 'Item não executado deve ter 0% de progresso ou vazio.';
      }
      if (feedback.nonExecutionReason == null) {
        return 'É obrigatório selecionar o motivo para item não executado.';
      }
    }

    if (feedback.executionStatus == ExecutionStatus.naoAplicavel) {
      if (feedback.executionPercentage != null) {
        return 'Item não aplicável não deve possuir percentual.';
      }
    }

    return null; // Válido
  }
}
