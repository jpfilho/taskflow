import 'package:uuid/uuid.dart';

import '../../data/local/gtd_local_storage.dart';
import '../../data/models/gtd_models.dart';
import '../../data/gtd_sync_service.dart';
import '../gtd_session.dart';
import 'gtd_actions_usecase.dart';

/// Casos de uso de projetos e contextos.
class GtdProjectsUseCase {
  final GtdLocalStorage _local = GtdLocalStorage.instance();
  final GtdSyncService _sync = GtdSyncService.instance();
  final GtdActionsUseCase _actionsUseCase = GtdActionsUseCase();
  final _uuid = const Uuid();

  String? get _userId => GtdSession.currentUserId;

  Future<List<GtdContext>> getContexts() async {
    final userId = _userId;
    if (userId == null) return [];
    return _local.getContexts(userId);
  }

  Future<GtdContext> createContext(String name) async {
    final userId = _userId;
    if (userId == null) throw StateError('Usuário não autenticado');
    final now = DateTime.now().toUtc();
    final c = GtdContext(
      id: _uuid.v4(),
      userId: userId,
      name: name.trim(),
      createdAt: now,
      updatedAt: now,
    );
    await _local.upsertContext(c);
    await _local.enqueueSync(
      entity: 'gtd_contexts',
      entityId: c.id,
      op: 'upsert',
      payload: c.toJson(),
    );
    _sync.sync(userId);
    return c;
  }

  Future<List<GtdProject>> getProjects() async {
    final userId = _userId;
    if (userId == null) return [];
    return _local.getProjects(userId);
  }

  Future<GtdProject> createProject(String name, {String? notes}) async {
    final userId = _userId;
    if (userId == null) throw StateError('Usuário não autenticado');
    final now = DateTime.now().toUtc();
    final p = GtdProject(
      id: _uuid.v4(),
      userId: userId,
      name: name.trim(),
      notes: notes?.trim(),
      createdAt: now,
      updatedAt: now,
    );
    await _local.upsertProject(p);
    await _local.enqueueSync(
      entity: 'gtd_projects',
      entityId: p.id,
      op: 'upsert',
      payload: p.toJson(),
    );
    _sync.sync(userId);
    return p;
  }

  /// Atualizar projeto (ex.: notas de andamento).
  Future<void> updateProject(GtdProject project) async {
    final userId = _userId;
    if (userId == null) return;
    final updated = GtdProject(
      id: project.id,
      userId: project.userId,
      name: project.name,
      notes: project.notes,
      createdAt: project.createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
    await _local.upsertProject(updated);
    await _local.enqueueSync(
      entity: 'gtd_projects',
      entityId: project.id,
      op: 'upsert',
      payload: updated.toJson(),
    );
    _sync.sync(userId);
  }

  /// Contagem de ações done / total por projeto.
  Future<Map<String, ({int done, int total})>> getProjectProgress() async {
    final projects = await getProjects();
    final map = <String, ({int done, int total})>{};
    for (final p in projects) {
      final actions = await _actionsUseCase.getActionsByProject(p.id);
      final done = actions
          .where((a) => a.status == GtdActionStatus.done)
          .length;
      map[p.id] = (done: done, total: actions.length);
    }
    return map;
  }
}
