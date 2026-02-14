import 'package:uuid/uuid.dart';

import '../../data/local/gtd_local_storage.dart';
import '../../data/models/gtd_models.dart';
import '../../data/gtd_sync_service.dart';
import '../gtd_session.dart';

/// Casos de uso de ações: listar, criar, atualizar, concluir, adiar, etc.
class GtdActionsUseCase {
  final GtdLocalStorage _local = GtdLocalStorage.instance();
  final GtdSyncService _sync = GtdSyncService.instance();
  final _uuid = const Uuid();

  String? get _userId => GtdSession.currentUserId;

  Future<List<GtdAction>> getNextActions({
    String? contextId,
    String? energy,
    String? priority,
    bool withDueOnly = false,
    bool withoutDueOnly = false,
    String? search,
  }) async {
    final userId = _userId;
    if (userId == null) return [];
    var list = await _local.getActions(userId, status: GtdActionStatus.next);
    if (contextId != null && contextId.isNotEmpty) {
      list = list.where((a) => a.contextId == contextId).toList();
    }
    if (energy != null && energy.isNotEmpty) {
      list = list.where((a) => a.energy == energy).toList();
    }
    if (priority != null && priority.isNotEmpty) {
      list = list.where((a) => a.priority == priority).toList();
    }
    if (withDueOnly) {
      list = list.where((a) => a.dueAt != null).toList();
    }
    if (withoutDueOnly) {
      list = list.where((a) => a.dueAt == null).toList();
    }
    if (search != null && search.trim().isNotEmpty) {
      final q = search.trim().toLowerCase();
      list = list
          .where(
            (a) =>
                a.title.toLowerCase().contains(q) ||
                (a.notes?.toLowerCase().contains(q) ?? false),
          )
          .toList();
    }
    return list;
  }

  Future<List<GtdAction>> getActionsByProject(String projectId) async {
    final userId = _userId;
    if (userId == null) return [];
    final list = await _local.getActions(userId);
    return list.where((a) => a.projectId == projectId).toList();
  }

  /// Lista ações "Aguardando" (status waiting).
  Future<List<GtdAction>> getWaitingActions() async {
    final userId = _userId;
    if (userId == null) return [];
    return _local.getActions(userId, status: GtdActionStatus.waiting);
  }

  /// Lista ações que têm andamento (notes preenchidas). Exclui concluídas.
  Future<List<GtdAction>> getActionsWithAndamento({String? search}) async {
    final userId = _userId;
    if (userId == null) return [];
    final all = await _local.getActions(userId);
    var list = all
        .where((a) =>
            a.status != GtdActionStatus.done &&
            a.notes != null &&
            a.notes!.trim().isNotEmpty)
        .toList();
    if (search != null && search.trim().isNotEmpty) {
      final q = search.trim().toLowerCase();
      list = list
          .where(
            (a) =>
                a.title.toLowerCase().contains(q) ||
                (a.notes?.toLowerCase().contains(q) ?? false),
          )
          .toList();
    }
    list.sort((a, b) => (b.updatedAt.compareTo(a.updatedAt)));
    return list;
  }

  /// Lista ações "Algum dia" (status someday), com busca opcional.
  Future<List<GtdAction>> getSomedayActions({String? search}) async {
    final userId = _userId;
    if (userId == null) return [];
    var list = await _local.getActions(userId, status: GtdActionStatus.someday);
    if (search != null && search.trim().isNotEmpty) {
      final q = search.trim().toLowerCase();
      list = list
          .where(
            (a) =>
                a.title.toLowerCase().contains(q) ||
                (a.notes?.toLowerCase().contains(q) ?? false),
          )
          .toList();
    }
    return list;
  }

  /// Volta ação para "Agora" (status next), opcionalmente com data.
  Future<void> moveToNext(GtdAction action, {DateTime? dueAt}) async {
    await updateAction(
      action.copyWith(
        status: GtdActionStatus.next,
        dueAt: dueAt,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<GtdAction> createAction({
    required String title,
    String? projectId,
    String? contextId,
    String? energy,
    String? priority,
    int? timeMin,
    DateTime? dueAt,
    String? waitingFor,
    String? notes,
    String? linkedTaskId,
    bool isRoutine = false,
    String? recurrenceRule,
    String? recurrenceWeekdays,
    DateTime? alarmAt,
    String? sourceInboxId,
    String? delegatedToUserId,
  }) async {
    final userId = _userId;
    if (userId == null) throw StateError('Usuário não autenticado');
    final now = DateTime.now().toUtc();
    final action = GtdAction(
      id: _uuid.v4(),
      userId: userId,
      projectId: projectId,
      contextId: contextId,
      title: title,
      status: GtdActionStatus.next,
      energy: energy,
      priority: priority,
      timeMin: timeMin,
      dueAt: dueAt,
      waitingFor: waitingFor,
      notes: notes,
      linkedTaskId: linkedTaskId,
      isRoutine: isRoutine,
      recurrenceRule: recurrenceRule,
      recurrenceWeekdays: recurrenceWeekdays,
      alarmAt: alarmAt,
      sourceInboxId: sourceInboxId,
      delegatedToUserId: delegatedToUserId,
      createdAt: now,
      updatedAt: now,
    );
    await _local.upsertAction(action);
    await _local.enqueueSync(
      entity: 'gtd_actions',
      entityId: action.id,
      op: 'upsert',
      payload: action.toJson(),
    );
    _sync.sync(userId);
    return action;
  }

  Future<void> updateAction(GtdAction action) async {
    final userId = _userId;
    if (userId == null) return;
    final updated = action.copyWith(updatedAt: DateTime.now().toUtc());
    await _local.upsertAction(updated);
    await _local.enqueueSync(
      entity: 'gtd_actions',
      entityId: action.id,
      op: 'upsert',
      payload: updated.toJson(),
    );
    _sync.sync(userId);
  }

  Future<void> completeAction(GtdAction action) async {
    await updateAction(
      action.copyWith(
        status: GtdActionStatus.done,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> deferAction(GtdAction action, DateTime newDueAt) async {
    await updateAction(
      action.copyWith(dueAt: newDueAt, updatedAt: DateTime.now().toUtc()),
    );
  }

  Future<void> moveToWaiting(
    GtdAction action,
    String waitingFor, {
    String? delegatedToUserId,
  }) async {
    await updateAction(
      action.copyWith(
        status: GtdActionStatus.waiting,
        waitingFor: waitingFor,
        delegatedToUserId: delegatedToUserId,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> moveToSomeday(GtdAction action) async {
    await updateAction(
      action.copyWith(
        status: GtdActionStatus.someday,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  /// Define ou remove o alarme da ação.
  Future<void> setAlarm(GtdAction action, DateTime? alarmAt) async {
    await updateAction(
      action.copyWith(
        alarmAt: alarmAt,
        clearAlarm: alarmAt == null,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  /// Marca ação como rotina (recorrente) ou remove.
  Future<void> setRoutine(
    GtdAction action, {
    required bool isRoutine,
    String? recurrenceRule,
    String? recurrenceWeekdays,
  }) async {
    await updateAction(
      action.copyWith(
        isRoutine: isRoutine,
        recurrenceRule: isRoutine ? recurrenceRule : null,
        recurrenceWeekdays: isRoutine ? recurrenceWeekdays : null,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  /// Excluir ação.
  Future<void> deleteAction(GtdAction action) async {
    final userId = _userId;
    if (userId == null) return;
    await _local.deleteAction(action.id);
    await _local.enqueueSync(
      entity: 'gtd_actions',
      entityId: action.id,
      op: 'delete',
      payload: {'id': action.id},
    );
    _sync.sync(userId);
  }
}
