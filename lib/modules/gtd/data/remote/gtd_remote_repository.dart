import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../config/supabase_config.dart';
import '../models/gtd_models.dart';

/// Repositório remoto GTD (Supabase). Todas as queries filtradas por user_id.
class GtdRemoteRepository {
  SupabaseClient get _client => SupabaseConfig.client;

  // ---------- Contexts ----------
  Future<List<GtdContext>> getContexts(String userId) async {
    final res = await _client
        .from('gtd_contexts')
        .select()
        .eq('user_id', userId)
        .order('name');
    return (res as List)
        .map((e) => GtdContext.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> upsertContext(GtdContext c) async {
    await _client.from('gtd_contexts').upsert(c.toJson());
  }

  Future<void> deleteContext(String id, String userId) async {
    await _client.from('gtd_contexts').delete().match({
      'id': id,
      'user_id': userId,
    });
  }

  Future<List<GtdContext>> getContextsUpdatedAfter(
    String userId,
    DateTime after,
  ) async {
    final iso = after.toUtc().toIso8601String();
    final res = await _client
        .from('gtd_contexts')
        .select()
        .eq('user_id', userId)
        .gt('updated_at', iso)
        .order('updated_at');
    return (res as List)
        .map((e) => GtdContext.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---------- Projects ----------
  Future<List<GtdProject>> getProjects(String userId) async {
    final res = await _client
        .from('gtd_projects')
        .select()
        .eq('user_id', userId)
        .order('name');
    return (res as List)
        .map((e) => GtdProject.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> upsertProject(GtdProject p) async {
    await _client.from('gtd_projects').upsert(p.toJson());
  }

  Future<void> deleteProject(String id, String userId) async {
    await _client.from('gtd_projects').delete().match({
      'id': id,
      'user_id': userId,
    });
  }

  Future<List<GtdProject>> getProjectsUpdatedAfter(
    String userId,
    DateTime after,
  ) async {
    final iso = after.toUtc().toIso8601String();
    final res = await _client
        .from('gtd_projects')
        .select()
        .eq('user_id', userId)
        .gt('updated_at', iso)
        .order('updated_at');
    return (res as List)
        .map((e) => GtdProject.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---------- Inbox ----------
  Future<List<GtdInboxItem>> getInboxItems(
    String userId, {
    bool unprocessedOnly = false,
  }) async {
    final res = await _client
        .from('gtd_inbox')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    var list = (res as List)
        .map((e) => GtdInboxItem.fromJson(e as Map<String, dynamic>))
        .toList();
    if (unprocessedOnly) {
      list = list.where((i) => i.processedAt == null).toList();
    }
    return list;
  }

  Future<void> insertInbox(GtdInboxItem item) async {
    await _client.from('gtd_inbox').insert(item.toJson());
  }

  Future<void> updateInbox(GtdInboxItem item) async {
    await _client
        .from('gtd_inbox')
        .update({
          'content': item.content,
          'processed_at': item.processedAt?.toUtc().toIso8601String(),
          'updated_at': item.updatedAt.toUtc().toIso8601String(),
        })
        .eq('id', item.id)
        .eq('user_id', item.userId);
  }

  Future<void> upsertInbox(GtdInboxItem item) async {
    await _client.from('gtd_inbox').upsert(item.toJson());
  }

  Future<void> deleteInbox(String id, String userId) async {
    await _client
        .from('gtd_inbox')
        .delete()
        .eq('id', id)
        .eq('user_id', userId);
  }

  Future<List<GtdInboxItem>> getInboxUpdatedAfter(
    String userId,
    DateTime after,
  ) async {
    final iso = after.toUtc().toIso8601String();
    final res = await _client
        .from('gtd_inbox')
        .select()
        .eq('user_id', userId)
        .gt('updated_at', iso)
        .order('updated_at');
    return (res as List)
        .map((e) => GtdInboxItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---------- Reference ----------
  Future<List<GtdReferenceItem>> getReferenceItems(String userId) async {
    final res = await _client
        .from('gtd_reference')
        .select()
        .eq('user_id', userId)
        .order('title');
    return (res as List)
        .map((e) => GtdReferenceItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> upsertReference(GtdReferenceItem r) async {
    await _client.from('gtd_reference').upsert(r.toJson());
  }

  Future<void> deleteReference(String id, String userId) async {
    await _client.from('gtd_reference').delete().match({
      'id': id,
      'user_id': userId,
    });
  }

  // ---------- Actions ----------
  Future<List<GtdAction>> getActions(
    String userId, {
    GtdActionStatus? status,
  }) async {
    var query = _client.from('gtd_actions').select().eq('user_id', userId);
    if (status != null) {
      query = query.eq('status', status.value);
    }
    final res = await query.order('due_at', ascending: true);
    return (res as List)
        .map((e) => GtdAction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> upsertAction(GtdAction a) async {
    await _client.from('gtd_actions').upsert(a.toJson());
  }

  Future<void> deleteAction(String id, String userId) async {
    await _client.from('gtd_actions').delete().match({
      'id': id,
      'user_id': userId,
    });
  }

  Future<List<GtdAction>> getActionsUpdatedAfter(
    String userId,
    DateTime after,
  ) async {
    final iso = after.toUtc().toIso8601String();
    final res = await _client
        .from('gtd_actions')
        .select()
        .eq('user_id', userId)
        .gt('updated_at', iso)
        .order('updated_at');
    return (res as List)
        .map((e) => GtdAction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---------- Weekly reviews ----------
  Future<List<GtdWeeklyReview>> getWeeklyReviews(
    String userId, {
    int limit = 20,
  }) async {
    final res = await _client
        .from('gtd_weekly_reviews')
        .select()
        .eq('user_id', userId)
        .order('completed_at', ascending: false)
        .limit(limit);
    return (res as List)
        .map((e) => GtdWeeklyReview.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> insertWeeklyReview(GtdWeeklyReview r) async {
    await _client.from('gtd_weekly_reviews').insert(r.toJson());
  }
}
