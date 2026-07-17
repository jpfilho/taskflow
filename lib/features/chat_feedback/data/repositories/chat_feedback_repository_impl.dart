import 'dart:convert';
import '../../domain/repositories/chat_feedback_repository.dart';
import '../../domain/models/chat_feedback_session.dart';
import '../../domain/models/chat_feedback_item.dart';
import '../../domain/models/chat_item_feedback.dart';
import '../../domain/models/chat_item_feedback_anexo.dart';
import '../../domain/models/chat_item_feedback_history.dart';
import '../../../../services/local_database_service.dart';

class ChatFeedbackRepositoryImpl implements ChatFeedbackRepository {
  final LocalDatabaseService _localDb;

  ChatFeedbackRepositoryImpl(this._localDb);

  @override
  Future<void> saveSessionLocal(ChatFeedbackSession session, List<ChatFeedbackItem> items, List<ChatItemFeedback> feedbacks) async {
    final db = await _localDb.database;
    
    // We store the session as a JSON string in a local table 'chat_feedback_drafts'
    final draftData = {
      'session': session.toMap(),
      'items': items.map((i) => i.toMap()).toList(),
      'feedbacks': feedbacks.map((f) => f.toMap()).toList(),
    };

    await db.insert(
      'chat_feedback_drafts',
      {
        'task_id': session.taskId,
        'draft_data': jsonEncode(draftData),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: null, // Since we use taskId as UNIQUE or Primary Key in SQLite, we should use replace.
    );
    // Wait, the conflictAlgorithm is set below.
  }
  
  @override
  Future<Map<String, dynamic>?> getSessionLocal(String taskId) async {
    final db = await _localDb.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'chat_feedback_drafts',
      where: 'task_id = ?',
      whereArgs: [taskId],
    );

    if (maps.isNotEmpty) {
      final String draftDataStr = maps.first['draft_data'] as String;
      return jsonDecode(draftDataStr) as Map<String, dynamic>;
    }
    return null;
  }
  
  @override
  Future<void> deleteSessionLocal(String taskId) async {
    final db = await _localDb.database;
    await db.delete(
      'chat_feedback_drafts',
      where: 'task_id = ?',
      whereArgs: [taskId],
    );
  }
  
  @override
  Future<void> enqueueSessionSync(ChatFeedbackSession session, List<ChatFeedbackItem> items, List<ChatItemFeedback> feedbacks, List<ChatItemFeedbackAnexo> anexos) async {
    // Enqueue session
    await _localDb.addToSyncQueue(
      'chat_feedback_sessions',
      'insert',
      session.id,
      session.toMap(),
    );
    
    // Enqueue items
    for (final item in items) {
      await _localDb.addToSyncQueue(
        'chat_feedback_items',
        'insert',
        item.id,
        item.toMap(),
      );
    }
    
    // Enqueue feedbacks
    for (final feedback in feedbacks) {
      await _localDb.addToSyncQueue(
        'chat_item_feedbacks',
        'insert',
        feedback.id,
        feedback.toMap(),
      );
    }
    
    // Enqueue anexos
    for (final anexo in anexos) {
      await _localDb.addToSyncQueue(
        'chat_item_feedback_anexos',
        'insert',
        anexo.id,
        anexo.toMap(),
      );
    }
  }
  
  @override
  Future<List<ChatItemFeedbackHistory>> getFeedbackHistory(String feedbackId) async {
    return [];
  }
  
  @override
  Future<List<ChatItemFeedbackAnexo>> getFeedbackAnexos(String feedbackId) async {
    return [];
  }
}
