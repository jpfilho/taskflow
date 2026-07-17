class ChatItemFeedbackHistory {
  final String id;
  final String feedbackId;
  final Map<String, dynamic> changedFields;
  final String changedBy;
  final DateTime changedAt;

  ChatItemFeedbackHistory({
    required this.id,
    required this.feedbackId,
    required this.changedFields,
    required this.changedBy,
    required this.changedAt,
  });

  factory ChatItemFeedbackHistory.fromMap(Map<String, dynamic> map) {
    return ChatItemFeedbackHistory(
      id: map['id'] as String,
      feedbackId: map['feedback_id'] as String,
      changedFields: Map<String, dynamic>.from(map['changed_fields'] as Map),
      changedBy: map['changed_by'] as String,
      changedAt: DateTime.parse(map['changed_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'feedback_id': feedbackId,
      'changed_fields': changedFields,
      'changed_by': changedBy,
      'changed_at': changedAt.toIso8601String(),
    };
  }

  ChatItemFeedbackHistory copyWith({
    String? id,
    String? feedbackId,
    Map<String, dynamic>? changedFields,
    String? changedBy,
    DateTime? changedAt,
  }) {
    return ChatItemFeedbackHistory(
      id: id ?? this.id,
      feedbackId: feedbackId ?? this.feedbackId,
      changedFields: changedFields ?? this.changedFields,
      changedBy: changedBy ?? this.changedBy,
      changedAt: changedAt ?? this.changedAt,
    );
  }
}
