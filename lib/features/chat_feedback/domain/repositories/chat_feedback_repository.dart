import '../models/chat_feedback_session.dart';
import '../models/chat_feedback_item.dart';
import '../models/chat_item_feedback.dart';
import '../models/chat_item_feedback_anexo.dart';
import '../models/chat_item_feedback_history.dart';

abstract class ChatFeedbackRepository {
  /// Salva a sessão no banco local (Rascunho)
  Future<void> saveSessionLocal(ChatFeedbackSession session, List<ChatFeedbackItem> items, List<ChatItemFeedback> feedbacks);

  /// Busca uma sessão local pelo ID
  Future<Map<String, dynamic>?> getSessionLocal(String taskId);
  
  /// Deleta a sessão local
  Future<void> deleteSessionLocal(String taskId);

  /// Adiciona toda a árvore da sessão na fila de sincronização offline (Submit)
  Future<void> enqueueSessionSync(ChatFeedbackSession session, List<ChatFeedbackItem> items, List<ChatItemFeedback> feedbacks, List<ChatItemFeedbackAnexo> anexos);

  /// Busca o histórico de um feedback específico
  Future<List<ChatItemFeedbackHistory>> getFeedbackHistory(String feedbackId);
  
  /// Busca anexos de um feedback
  Future<List<ChatItemFeedbackAnexo>> getFeedbackAnexos(String feedbackId);
}
