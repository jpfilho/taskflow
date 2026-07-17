import '../enums/chat_feedback_item_type.dart';

class ChatFeedbackItem {
  final String id;
  final String sessionId;
  final String taskId;
  final ChatFeedbackItemType itemType;
  final String? sourceItemId;
  final String? itemNumber;
  final String? itemDescription;
  final String? location;
  final String? room;
  final String createdBy;
  final DateTime createdAt;

  ChatFeedbackItem({
    required this.id,
    required this.sessionId,
    required this.taskId,
    required this.itemType,
    this.sourceItemId,
    this.itemNumber,
    this.itemDescription,
    this.location,
    this.room,
    required this.createdBy,
    required this.createdAt,
  });

  factory ChatFeedbackItem.fromMap(Map<String, dynamic> map) {
    return ChatFeedbackItem(
      id: map['id'] as String,
      sessionId: map['session_id'] as String,
      taskId: map['task_id'] as String,
      itemType: ChatFeedbackItemType.fromString(map['item_type'] as String),
      sourceItemId: map['source_item_id'] as String?,
      itemNumber: map['item_number'] as String?,
      itemDescription: map['item_description'] as String?,
      location: map['location'] as String?,
      room: map['room'] as String?,
      createdBy: map['created_by'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'task_id': taskId,
      'item_type': itemType.toMapValue(),
      'source_item_id': sourceItemId,
      'item_number': itemNumber,
      'item_description': itemDescription,
      'location': location,
      'room': room,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }

  ChatFeedbackItem copyWith({
    String? id,
    String? sessionId,
    String? taskId,
    ChatFeedbackItemType? itemType,
    String? sourceItemId,
    String? itemNumber,
    String? itemDescription,
    String? location,
    String? room,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return ChatFeedbackItem(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      taskId: taskId ?? this.taskId,
      itemType: itemType ?? this.itemType,
      sourceItemId: sourceItemId ?? this.sourceItemId,
      itemNumber: itemNumber ?? this.itemNumber,
      itemDescription: itemDescription ?? this.itemDescription,
      location: location ?? this.location,
      room: room ?? this.room,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
