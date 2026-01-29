import 'dart:async';

/// Implementação stub (para plataformas não-web)
class TabSyncServiceImplementation {
  final StreamController<Map<String, dynamic>> _eventController = StreamController<Map<String, dynamic>>.broadcast();
  
  Stream<Map<String, dynamic>> get events => _eventController.stream;

  void initialize() {
    // Não faz nada em plataformas não-web
  }

  void broadcastEvent(String type, {Map<String, dynamic>? data}) {
    // Não faz nada em plataformas não-web
  }

  void dispose() {
    _eventController.close();
  }
}
