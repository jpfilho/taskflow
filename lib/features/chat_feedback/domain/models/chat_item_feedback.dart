import '../enums/execution_status.dart';
import '../enums/non_execution_reason.dart';

class ChatItemFeedback {
  final String id;
  final String feedbackItemId;
  final int sequenceNumber;
  final ExecutionStatus executionStatus;
  final double? executionPercentage;
  final NonExecutionReason? nonExecutionReason;
  final String? comment;
  final DateTime? executionDate;
  final bool followUpRequired;
  final bool isClosed;
  final String createdBy;
  final DateTime createdAt;
  final String? updatedBy;
  final DateTime updatedAt;
  final String? clientId;

  ChatItemFeedback({
    required this.id,
    required this.feedbackItemId,
    required this.sequenceNumber,
    required this.executionStatus,
    this.executionPercentage,
    this.nonExecutionReason,
    this.comment,
    this.executionDate,
    required this.followUpRequired,
    required this.isClosed,
    required this.createdBy,
    required this.createdAt,
    this.updatedBy,
    required this.updatedAt,
    this.clientId,
  });

  factory ChatItemFeedback.fromMap(Map<String, dynamic> map) {
    return ChatItemFeedback(
      id: map['id'] as String,
      feedbackItemId: map['feedback_item_id'] as String,
      sequenceNumber: map['sequence_number'] as int,
      executionStatus: ExecutionStatus.fromString(map['execution_status'] as String),
      executionPercentage: map['execution_percentage'] != null ? (map['execution_percentage'] as num).toDouble() : null,
      nonExecutionReason: NonExecutionReason.fromString(map['non_execution_reason'] as String?),
      comment: map['comment'] as String?,
      executionDate: map['execution_date'] != null ? DateTime.parse(map['execution_date'] as String) : null,
      followUpRequired: map['follow_up_required'] as bool? ?? false,
      isClosed: map['is_closed'] as bool? ?? false,
      createdBy: map['created_by'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedBy: map['updated_by'] as String?,
      updatedAt: DateTime.parse(map['updated_at'] as String),
      clientId: map['client_id'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'feedback_item_id': feedbackItemId,
      'sequence_number': sequenceNumber,
      'execution_status': executionStatus.toMapValue(),
      'execution_percentage': executionPercentage,
      'non_execution_reason': nonExecutionReason?.toMapValue(),
      'comment': comment,
      'execution_date': executionDate?.toIso8601String(),
      'follow_up_required': followUpRequired,
      'is_closed': isClosed,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_by': updatedBy,
      'updated_at': updatedAt.toIso8601String(),
      'client_id': clientId,
    };
  }

  ChatItemFeedback copyWith({
    String? id,
    String? feedbackItemId,
    int? sequenceNumber,
    ExecutionStatus? executionStatus,
    double? executionPercentage,
    NonExecutionReason? nonExecutionReason,
    String? comment,
    DateTime? executionDate,
    bool? followUpRequired,
    bool? isClosed,
    String? createdBy,
    DateTime? createdAt,
    String? updatedBy,
    DateTime? updatedAt,
    String? clientId,
  }) {
    return ChatItemFeedback(
      id: id ?? this.id,
      feedbackItemId: feedbackItemId ?? this.feedbackItemId,
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
      executionStatus: executionStatus ?? this.executionStatus,
      executionPercentage: executionPercentage ?? this.executionPercentage,
      nonExecutionReason: nonExecutionReason ?? this.nonExecutionReason,
      comment: comment ?? this.comment,
      executionDate: executionDate ?? this.executionDate,
      followUpRequired: followUpRequired ?? this.followUpRequired,
      isClosed: isClosed ?? this.isClosed,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedAt: updatedAt ?? this.updatedAt,
      clientId: clientId ?? this.clientId,
    );
  }
}
