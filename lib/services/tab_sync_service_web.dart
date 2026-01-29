// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';

/// Implementação web usando BroadcastChannel
class TabSyncServiceImplementation {
  html.BroadcastChannel? _channel;
  final StreamController<Map<String, dynamic>> _eventController = StreamController<Map<String, dynamic>>.broadcast();
  
  Stream<Map<String, dynamic>> get events => _eventController.stream;

  void initialize() {
    try {
      _channel = html.BroadcastChannel('taskflow_sync');
      _channel!.onMessage.listen((event) {
        try {
          // Converter LinkedMap<dynamic, dynamic> para Map<String, dynamic>
          final rawData = event.data;
          Map<String, dynamic> data;
          
          if (rawData is Map) {
            // Converter LinkedMap ou qualquer Map para Map<String, dynamic>
            data = rawData.map((key, value) => MapEntry(
              key.toString(),
              value is Map ? Map<String, dynamic>.from(value.map((k, v) => MapEntry(k.toString(), v))) : value,
            ));
          } else {
            print('⚠️ TabSyncService: Tipo de dados inesperado: ${rawData.runtimeType}');
            return;
          }
          
          _eventController.add(data);
          final eventType = data['type']?.toString() ?? 'null';
          print('📡 TabSyncService: Evento recebido de outra aba: $eventType');
        } catch (e) {
          print('⚠️ Erro ao processar evento de sincronização: $e');
        }
      });
      print('✅ TabSyncService: Inicializado com sucesso');
    } catch (e) {
      print('⚠️ Erro ao inicializar TabSyncService: $e');
    }
  }

  void broadcastEvent(String type, {Map<String, dynamic>? data}) {
    try {
      if (_channel == null) {
        initialize();
      }
      
      if (_channel == null) return;
      
      final event = {
        'type': type,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        if (data != null) ...data,
      };
      
      _channel!.postMessage(event);
      print('📤 TabSyncService: Evento enviado: $type');
    } catch (e) {
      print('⚠️ Erro ao enviar evento de sincronização: $e');
    }
  }

  void dispose() {
    _channel?.close();
    _eventController.close();
  }
}
