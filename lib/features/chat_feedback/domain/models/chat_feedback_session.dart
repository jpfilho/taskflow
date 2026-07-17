import '../enums/chat_feedback_session_status.dart';

class ChatFeedbackSession {
  final String id;
  final String taskId;
  final String? messageId;
  final ChatFeedbackSessionStatus status;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? submittedAt;
  final String clientId;

  ChatFeedbackSession({
    required this.id,
    required this.taskId,
    this.messageId,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.submittedAt,
    required this.clientId,
  });

  factory ChatFeedbackSession.fromMap(Map<String, dynamic> map) {
    return ChatFeedbackSession(
      id: map['id'] as String,
      taskId: map['task_id'] as String,
      messageId: map['message_id'] as String?,
      status: ChatFeedbackSessionStatus.fromString(map['status'] as String),
      createdBy: map['created_by'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      submittedAt: map['submitted_at'] != null ? DateTime.parse(map['submitted_at'] as String) : null,
      clientId: map['client_id'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'task_id': taskId,
      'message_id': messageId,
      'status': status.toMapValue(),
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'submitted_at': submittedAt?.toIso8601String(),
      'client_id': clientId,
    };
  }

  ChatFeedbackSession copyWith({
    String? id,
    String? taskId,
    String? messageId,
    ChatFeedbackSessionStatus? status,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? submittedAt,
    String? clientId,
  }) {
    return ChatFeedbackSession(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      messageId: messageId ?? this.messageId,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      submittedAt: submittedAt ?? this.submittedAt,
      clientId: clientId ?? this.clientId,
    );
  }
}
