import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamController<bool>? _connectionController;
  Stream<bool>? _connectionStream;
  bool _isConnected = true; // Assume conectado por padrão

  Stream<bool> get connectionStream {
    _connectionController ??= StreamController<bool>.broadcast();
    _connectionStream ??= _connectionController!.stream;
    return _connectionStream!;
  }

  bool get isConnected => _isConnected;

  Future<void> initialize() async {
    // Verificar estado inicial
    await checkConnectivity();

    // Escutar mudanças de conectividade
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
      _updateConnectionStatus(result);
    });
  }

  Future<void> checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
    _updateConnectionStatus(result);
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    final wasConnected = _isConnected;
    _isConnected = result != ConnectivityResult.none;
    
    if (wasConnected != _isConnected) {
      _connectionController?.add(_isConnected);
      print('📡 Status de conexão: ${_isConnected ? "Conectado" : "Desconectado"}');
    }
  }

  void dispose() {
    _connectionController?.close();
    _connectionController = null;
    _connectionStream = null;
  }
}

