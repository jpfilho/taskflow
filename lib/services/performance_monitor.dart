import 'package:flutter/foundation.dart';

class PerformanceMonitor {
  static final Map<String, Stopwatch> _stopwatches = {};

  static void start(String label) {
    if (kDebugMode) {
      final sw = Stopwatch()..start();
      _stopwatches[label] = sw;
      debugPrint('🚀 [PERF START] $label');
    }
  }

  static void stop(String label) {
    if (kDebugMode) {
      final sw = _stopwatches.remove(label);
      if (sw != null) {
        sw.stop();
        debugPrint('🏁 [PERF STOP] $label: ${sw.elapsedMilliseconds}ms');
      }
    }
  }

  static Future<T> track<T>(String label, Future<T> Function() action) async {
    start(label);
    try {
      return await action();
    } finally {
      stop(label);
    }
  }
}
