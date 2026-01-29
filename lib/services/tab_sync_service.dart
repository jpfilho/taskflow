import 'dart:async';

// Import condicional apenas para web
import 'tab_sync_service_stub.dart'
    if (dart.library.html) 'tab_sync_service_web.dart' as impl;

/// Serviço para sincronizar dados entre abas do navegador
/// Usa BroadcastChannel para comunicação entre abas (apenas no web)
class TabSyncService {
  static final TabSyncService _instance = TabSyncService._internal();
  factory TabSyncService() => _instance;
  TabSyncService._internal();

  final impl.TabSyncServiceImplementation _impl = impl.TabSyncServiceImplementation();
  
  /// Stream de eventos recebidos de outras abas
  Stream<Map<String, dynamic>> get events => _impl.events;

  /// Inicializar o serviço (apenas no web)
  void initialize() {
    _impl.initialize();
  }

  /// Enviar evento para todas as abas
  void broadcastEvent(String type, {Map<String, dynamic>? data}) {
    _impl.broadcastEvent(type, data: data);
  }

  /// Notificar que uma tarefa foi criada
  void notifyTaskCreated(String taskId) {
    broadcastEvent('task_created', data: {'task_id': taskId});
  }

  /// Notificar que uma tarefa foi atualizada
  void notifyTaskUpdated(String taskId) {
    broadcastEvent('task_updated', data: {'task_id': taskId});
  }

  /// Notificar que uma tarefa foi deletada
  void notifyTaskDeleted(String taskId) {
    broadcastEvent('task_deleted', data: {'task_id': taskId});
  }

  /// Notificar que as tarefas devem ser recarregadas
  void notifyTasksReload() {
    broadcastEvent('tasks_reload');
  }

  /// Dispose do serviço
  void dispose() {
    _impl.dispose();
  }
}
