import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'local/gtd_local_storage.dart';
import 'models/gtd_models.dart';
import 'remote/gtd_remote_repository.dart';
import '../../../../services/connectivity_service.dart';

/// Sincronização GTD: push da sync_queue + pull incremental.
/// Backoff exponencial; last-write-wins por updated_at.
class GtdSyncService {
  static final GtdSyncService _instance = GtdSyncService._();
  factory GtdSyncService.instance() => _instance;

  GtdSyncService._();

  final GtdLocalStorage _local = GtdLocalStorage.instance();
  final GtdRemoteRepository _remote = GtdRemoteRepository();
  final ConnectivityService _connectivity = ConnectivityService();

  static const int maxRetries = 5;
  static const int baseBackoffMs = 2000;
  static const int maxBackoffMs = 300000; // 5 min
  static const int syncIntervalMinutes = 5;

  DateTime? _lastSyncAt;
  bool _isSyncing = false;
  Timer? _periodicTimer;
  StreamSubscription<bool>? _connectivitySub;

  DateTime? get lastSyncAt => _lastSyncAt;
  bool get isSyncing => _isSyncing;

  final StreamController<bool> _syncingController =
      StreamController<bool>.broadcast();
  Stream<bool> get syncingStream => _syncingController.stream;

  String? _initializedUserId;

  /// Inicializar: escutar conectividade e rodar sync periódico (idempotente).
  Future<void> initialize(String userId) async {
    await _connectivity.initialize();
    if (_periodicTimer != null) {
      await sync(userId);
      return;
    }
    _initializedUserId = userId;
    _connectivitySub = _connectivity.connectionStream.listen((isConnected) {
      if (isConnected && !_isSyncing && _initializedUserId != null) {
        sync(_initializedUserId!);
      }
    });
    await sync(userId);
    _periodicTimer = Timer.periodic(Duration(minutes: syncIntervalMinutes), (
      _,
    ) {
      if (_connectivity.isConnected &&
          !_isSyncing &&
          _initializedUserId != null) {
        sync(_initializedUserId!);
      }
    });
  }

  void dispose() {
    _periodicTimer?.cancel();
    _connectivitySub?.cancel();
    _syncingController.close();
  }

  /// Executar sincronização completa (push + pull).
  Future<void> sync(String userId) async {
    if (!_connectivity.isConnected || _isSyncing) return;
    _isSyncing = true;
    _syncingController.add(true);
    try {
      await _pushQueue(userId);
      await _pullIncremental(userId);
      _lastSyncAt = DateTime.now().toUtc();
    } catch (e) {
      // Manter dados locais; tentar de novo depois
    } finally {
      _isSyncing = false;
      _syncingController.add(false);
    }
  }

  /// Enviar itens da sync_queue para o Supabase.
  Future<void> _pushQueue(String userId) async {
    final items = await _local.getPendingSyncItems();
    for (final item in items) {
      if (item.entityId.isEmpty) continue;
      try {
        final payload = jsonDecode(item.payloadJson) as Map<String, dynamic>;
        if (item.op == 'delete') {
          await _remoteDelete(item.entity, item.entityId, userId);
        } else {
          await _remoteUpsert(item.entity, payload, userId);
        }
        await _local.deleteSyncItem(item.id);
      } catch (e) {
        final tries = item.tries + 1;
        final backoffMs = math.min(
          baseBackoffMs * math.pow(2, tries).toInt(),
          maxBackoffMs,
        );
        final nextRetry = DateTime.now().toUtc().add(
          Duration(milliseconds: backoffMs),
        );
        await _local.updateSyncItemRetry(
          item.id,
          nextRetryAt: nextRetry,
          lastError: e.toString(),
        );
      }
    }
  }

  Future<void> _remoteUpsert(
    String entity,
    Map<String, dynamic> payload,
    String userId,
  ) async {
    switch (entity) {
      case 'gtd_contexts':
        await _remote.upsertContext(GtdContext.fromJson(payload));
        break;
      case 'gtd_projects':
        await _remote.upsertProject(GtdProject.fromJson(payload));
        break;
      case 'gtd_inbox':
        await _remote.upsertInbox(GtdInboxItem.fromJson(payload));
        break;
      case 'gtd_reference':
        await _remote.upsertReference(GtdReferenceItem.fromJson(payload));
        break;
      case 'gtd_actions':
        await _remote.upsertAction(GtdAction.fromJson(payload));
        break;
      case 'gtd_weekly_reviews':
        await _remote.insertWeeklyReview(GtdWeeklyReview.fromJson(payload));
        break;
      default:
        break;
    }
  }

  Future<void> _remoteDelete(
    String entity,
    String entityId,
    String userId,
  ) async {
    switch (entity) {
      case 'gtd_contexts':
        await _remote.deleteContext(entityId, userId);
        break;
      case 'gtd_projects':
        await _remote.deleteProject(entityId, userId);
        break;
      case 'gtd_inbox':
        await _remote.deleteInbox(entityId, userId);
        break;
      case 'gtd_actions':
        await _remote.deleteAction(entityId, userId);
        break;
      case 'gtd_reference':
        await _remote.deleteReference(entityId, userId);
        break;
      default:
        break;
    }
  }

  /// Pull incremental: updated_at > lastSyncAt; last-write-wins (upsert local).
  Future<void> _pullIncremental(String userId) async {
    final after = _lastSyncAt ?? DateTime(1970);
    final contexts = await _remote.getContextsUpdatedAfter(userId, after);
    final projects = await _remote.getProjectsUpdatedAfter(userId, after);
    final inbox = await _remote.getInboxUpdatedAfter(userId, after);
    final actions = await _remote.getActionsUpdatedAfter(userId, after);
    for (final c in contexts) {
      await _local.upsertContext(c);
    }
    for (final p in projects) {
      await _local.upsertProject(p);
    }
    for (final i in inbox) {
      await _local.upsertInbox(i);
    }
    for (final a in actions) {
      await _local.upsertAction(a);
    }
  }
}
