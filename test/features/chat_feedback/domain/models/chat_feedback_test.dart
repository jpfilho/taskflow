import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/features/chat_feedback/domain/enums/execution_status.dart';
import 'package:task2026/features/chat_feedback/domain/enums/non_execution_reason.dart';
import 'package:task2026/features/chat_feedback/domain/models/chat_item_feedback.dart';
import 'package:task2026/features/chat_feedback/domain/validators/chat_feedback_validator.dart';

void main() {
  group('ChatFeedbackValidator Tests', () {
    test('Validar feedback executado corretamente', () {
      final feedback = ChatItemFeedback(
        id: '1',
        feedbackItemId: '1',
        sequenceNumber: 1,
        executionStatus: ExecutionStatus.executado,
        executionPercentage: 100,
        followUpRequired: false,
        isClosed: true,
        createdBy: 'user1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final error = ChatFeedbackValidator.validateFeedback(feedback);
      expect(error, isNull);
    });

    test('Validar feedback executado com erro de percentual', () {
      final feedback = ChatItemFeedback(
        id: '1',
        feedbackItemId: '1',
        sequenceNumber: 1,
        executionStatus: ExecutionStatus.executado,
        executionPercentage: 90,
        followUpRequired: false,
        isClosed: true,
        createdBy: 'user1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final error = ChatFeedbackValidator.validateFeedback(feedback);
      expect(error, 'Item executado deve ter 100% de progresso.');
    });

    test('Validar feedback parcial sem comentario falha', () {
      final feedback = ChatItemFeedback(
        id: '1',
        feedbackItemId: '1',
        sequenceNumber: 1,
        executionStatus: ExecutionStatus.parcial,
        executionPercentage: 50,
        followUpRequired: false,
        isClosed: false,
        createdBy: 'user1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final error = ChatFeedbackValidator.validateFeedback(feedback);
      expect(error, 'É obrigatório justificar um item parcialmente executado.');
    });

    test('Validar feedback nao executado sem motivo falha', () {
      final feedback = ChatItemFeedback(
        id: '1',
        feedbackItemId: '1',
        sequenceNumber: 1,
        executionStatus: ExecutionStatus.naoExecutado,
        followUpRequired: false,
        isClosed: false,
        createdBy: 'user1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final error = ChatFeedbackValidator.validateFeedback(feedback);
      expect(error, 'É obrigatório selecionar o motivo para item não executado.');
    });

    test('Validar feedback nao executado com motivo ok', () {
      final feedback = ChatItemFeedback(
        id: '1',
        feedbackItemId: '1',
        sequenceNumber: 1,
        executionStatus: ExecutionStatus.naoExecutado,
        nonExecutionReason: NonExecutionReason.materialUnavailable,
        followUpRequired: false,
        isClosed: false,
        createdBy: 'user1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final error = ChatFeedbackValidator.validateFeedback(feedback);
      expect(error, isNull);
    });
  });

  group('ChatItemFeedback Serialization Tests', () {
    test('toMap e fromMap', () {
      final date = DateTime(2026, 7, 17, 12, 0, 0).toUtc();
      
      final feedback = ChatItemFeedback(
        id: '123',
        feedbackItemId: '456',
        sequenceNumber: 2,
        executionStatus: ExecutionStatus.parcial,
        executionPercentage: 75.5,
        comment: 'Faltou tempo',
        followUpRequired: true,
        isClosed: false,
        createdBy: 'user_x',
        createdAt: date,
        updatedAt: date,
      );

      final map = feedback.toMap();
      
      expect(map['id'], '123');
      expect(map['execution_status'], 'parcial');
      expect(map['execution_percentage'], 75.5);

      final newFeedback = ChatItemFeedback.fromMap(map);
      
      expect(newFeedback.id, '123');
      expect(newFeedback.executionStatus, ExecutionStatus.parcial);
      expect(newFeedback.executionPercentage, 75.5);
      expect(newFeedback.comment, 'Faltou tempo');
      expect(newFeedback.createdAt, date);
    });
  });
}
