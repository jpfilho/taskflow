import 'package:uuid/uuid.dart';

import '../../data/local/gtd_local_storage.dart';
import '../../data/models/gtd_models.dart';
import '../../data/gtd_sync_service.dart';
import '../gtd_session.dart';

/// Caso de uso: revisão semanal.
class GtdWeeklyReviewUseCase {
  final GtdLocalStorage _local = GtdLocalStorage.instance();
  final GtdSyncService _sync = GtdSyncService.instance();
  final _uuid = const Uuid();

  String? get _userId => GtdSession.currentUserId;

  Future<List<GtdWeeklyReview>> getWeeklyReviews({int limit = 20}) async {
    final userId = _userId;
    if (userId == null) return [];
    return _local.getWeeklyReviews(userId, limit: limit);
  }

  Future<GtdWeeklyReview> completeReview({String? notes}) async {
    final userId = _userId;
    if (userId == null) throw StateError('Usuário não autenticado');
    final now = DateTime.now().toUtc();
    final r = GtdWeeklyReview(
      id: _uuid.v4(),
      userId: userId,
      notes: notes?.trim(),
      completedAt: now,
      createdAt: now,
      updatedAt: now,
    );
    await _local.insertWeeklyReview(r);
    await _local.enqueueSync(
      entity: 'gtd_weekly_reviews',
      entityId: r.id,
      op: 'upsert',
      payload: r.toJson(),
    );
    _sync.sync(userId);
    return r;
  }
}
