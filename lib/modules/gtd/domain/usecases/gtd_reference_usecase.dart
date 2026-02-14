import 'package:uuid/uuid.dart';

import '../../data/local/gtd_local_storage.dart';
import '../../data/models/gtd_models.dart';
import '../../data/gtd_sync_service.dart';
import '../gtd_session.dart';

/// Casos de uso: referência e algum dia/talvez.
class GtdReferenceUseCase {
  final GtdLocalStorage _local = GtdLocalStorage.instance();
  final GtdSyncService _sync = GtdSyncService.instance();
  final _uuid = const Uuid();

  String? get _userId => GtdSession.currentUserId;

  Future<List<GtdReferenceItem>> getReferenceItems() async {
    final userId = _userId;
    if (userId == null) return [];
    return _local.getReferenceItems(userId);
  }

  Future<GtdReferenceItem> createReference(
    String title, {
    String? content,
  }) async {
    final userId = _userId;
    if (userId == null) throw StateError('Usuário não autenticado');
    final now = DateTime.now().toUtc();
    final r = GtdReferenceItem(
      id: _uuid.v4(),
      userId: userId,
      title: title.trim(),
      content: content?.trim(),
      createdAt: now,
      updatedAt: now,
    );
    await _local.upsertReference(r);
    await _local.enqueueSync(
      entity: 'gtd_reference',
      entityId: r.id,
      op: 'upsert',
      payload: r.toJson(),
    );
    _sync.sync(userId);
    return r;
  }
}
