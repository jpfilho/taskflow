import 'package:flutter/foundation.dart' show debugPrint;
import 'package:uuid/uuid.dart';

import '../../data/local/gtd_local_storage.dart';
import '../../data/models/gtd_models.dart';
import '../../data/gtd_sync_service.dart';
import '../gtd_session.dart';

/// Casos de uso do Inbox: capturar, listar, processar.
class GtdInboxUseCase {
  final GtdLocalStorage _local = GtdLocalStorage.instance();
  final GtdSyncService _sync = GtdSyncService.instance();
  final _uuid = const Uuid();

  String? get _userId => GtdSession.currentUserId;
  bool get canAccess => GtdSession.canAccessGtd;

  Future<List<GtdInboxItem>> getInboxItems({
    bool unprocessedOnly = false,
  }) async {
    final userId = _userId;
    if (userId == null) return [];
    return _local.getInboxItems(userId, unprocessedOnly: unprocessedOnly);
  }

  /// Retorna um item do inbox por id (para mostrar origem de uma ação).
  Future<GtdInboxItem?> getInboxItem(String id) async {
    final userId = _userId;
    if (userId == null) return null;
    return _local.getInboxItem(userId, id);
  }

  /// Capturar item no inbox: persiste local e enfileira sync.
  Future<GtdInboxItem> capture(String content) async {
    final userId = _userId;
    if (userId == null) throw StateError('Usuário não autenticado');
    debugPrint('GTD capture: userId=$userId');
    final now = DateTime.now().toUtc();
    final item = GtdInboxItem(
      id: _uuid.v4(),
      userId: userId,
      content: content.trim(),
      processedAt: null,
      createdAt: now,
      updatedAt: now,
    );
    try {
      await _local.insertInbox(item);
    } catch (e, st) {
      debugPrint('GTD capture: insertInbox falhou: $e\n$st');
      rethrow;
    }
    try {
      await _local.enqueueSync(
        entity: 'gtd_inbox',
        entityId: item.id,
        op: 'upsert',
        payload: item.toJson(),
      );
    } catch (e, st) {
      debugPrint('GTD capture: enqueueSync falhou: $e\n$st');
      rethrow;
    }
    _sync.sync(userId);
    return item;
  }

  /// Atualizar conteúdo de um item do inbox.
  Future<void> updateItem(GtdInboxItem item, String newContent) async {
    final userId = _userId;
    if (userId == null) return;
    final updated = GtdInboxItem(
      id: item.id,
      userId: item.userId,
      content: newContent.trim(),
      processedAt: item.processedAt,
      createdAt: item.createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
    await _local.updateInbox(updated);
    await _local.enqueueSync(
      entity: 'gtd_inbox',
      entityId: item.id,
      op: 'upsert',
      payload: updated.toJson(),
    );
    _sync.sync(userId);
  }

  /// Excluir item do inbox.
  Future<void> deleteItem(GtdInboxItem item) async {
    final userId = _userId;
    if (userId == null) return;
    await _local.deleteInbox(item.id);
    await _local.enqueueSync(
      entity: 'gtd_inbox',
      entityId: item.id,
      op: 'delete',
      payload: {'id': item.id},
    );
    _sync.sync(userId);
  }

  /// Marcar inbox como processado (após wizard).
  Future<void> markProcessed(GtdInboxItem item) async {
    final userId = _userId;
    if (userId == null) return;
    final updated = GtdInboxItem(
      id: item.id,
      userId: item.userId,
      content: item.content,
      processedAt: DateTime.now().toUtc(),
      createdAt: item.createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
    await _local.updateInbox(updated);
    await _local.enqueueSync(
      entity: 'gtd_inbox',
      entityId: item.id,
      op: 'upsert',
      payload: updated.toJson(),
    );
    _sync.sync(userId);
  }
}
