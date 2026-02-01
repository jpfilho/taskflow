import 'dart:async';

import 'connectivity_service.dart';
import 'sync_service.dart';

class SyncSchedulerService {
  static final SyncSchedulerService _instance = SyncSchedulerService._internal();
  factory SyncSchedulerService() => _instance;
  SyncSchedulerService._internal();

  final ConnectivityService _connectivity = ConnectivityService();
  final SyncService _syncService = SyncService();

  Timer? _timer;
  bool _started = false;

  void start({Duration interval = const Duration(seconds: 20)}) {
    if (_started) return;
    _started = true;
    _timer = Timer.periodic(interval, (_) => _tick());
    _tick();
  }

  Future<void> _tick() async {
    if (!_connectivity.isConnected) return;
    await _syncService.processDueQueue(limit: 20);
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _started = false;
  }
}
