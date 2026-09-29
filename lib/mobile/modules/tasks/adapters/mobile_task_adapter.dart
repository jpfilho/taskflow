import 'package:flutter/foundation.dart';
import '../../../../models/task.dart';
import '../../../../models/apr.dart';
import '../../../../models/anexo.dart';
import '../../../../models/grupo_chat.dart';
import '../../../../services/task_service.dart';
import '../../../../services/local_database_service.dart';
import '../../../../services/sync_service.dart';
import '../../../../services/connectivity_service.dart';
import '../../../../services/auth_service_simples.dart';
import '../../../../services/executor_service.dart';
import '../../../core/theme/tf_mobile_status_colors.dart';
import '../models/mobile_task_available_actions.dart';
import '../models/mobile_task_view_model.dart';
import '../models/mobile_task_detail_view_model.dart';

/// Resultado de uma tentativa de transição de status de tarefa.
class TaskTransitionResult {
  final bool success;
  final bool isOfflineQueued;
  final String message;
  final Task? updatedTask;

  const TaskTransitionResult({
    required this.success,
    this.isOfflineQueued = false,
    required this.message,
    this.updatedTask,
  });
}

/// Adapter que consome os serviços oficiais do TaskFlow, desacopla a UI de tabelas
/// e gerencia a tradução para ViewModels, permissões, offline-first e persistência.
class MobileTaskAdapter {
  final TaskService _taskService;
  final LocalDatabaseService _localDb;
  final SyncService _syncService;
  final ConnectivityService _connectivity;
  final AuthServiceSimples _authService;
  final ExecutorService _executorService;

  MobileTaskAdapter({
    TaskService? taskService,
    LocalDatabaseService? localDb,
    SyncService? syncService,
    ConnectivityService? connectivity,
    AuthServiceSimples? authService,
    ExecutorService? executorService,
  })  : _taskService = taskService ?? TaskService(),
        _localDb = localDb ?? LocalDatabaseService(),
        _syncService = syncService ?? SyncService(),
        _connectivity = connectivity ?? ConnectivityService(),
        _authService = authService ?? AuthServiceSimples(),
        _executorService = executorService ?? ExecutorService();

  /// Mapeia o código bruto de status para o enum semântico da UI Mobile.
  /// Status auditados: ANDA, PROG, RPAR, RPGR, CONC, CANC.
  TFOperationalStatus mapOperationalStatus(String rawStatus) {
    final s = rawStatus.toUpperCase().trim();
    switch (s) {
      case 'ANDA':
        return TFOperationalStatus.emExecucao;
      case 'PROG':
        return TFOperationalStatus.planejado;
      case 'RPAR':
      case 'RPGR':
        return TFOperationalStatus.pausado;
      case 'CONC':
        return TFOperationalStatus.concluido;
      case 'CANC':
        return TFOperationalStatus.cancelado;
      default:
        // Status desconhecido: registrar warning sem quebrar a execução
        debugPrint('⚠️ [MobileTaskAdapter] Status desconhecido encontrado: "$rawStatus"');
        return TFOperationalStatus.pendente;
    }
  }

  /// Verifica se o status é desconhecido pelo catálogo oficial do sistema.
  bool isUnknownStatus(String rawStatus) {
    final s = rawStatus.toUpperCase().trim();
    return !const ['ANDA', 'PROG', 'RPAR', 'RPGR', 'CONC', 'CANC'].contains(s);
  }

  /// Avalia a permissão do usuário atual em relação à tarefa.
  Future<bool> canUserMutateTask(Task task) async {
    try {
      final user = _authService.currentUser;
      if (user == null) return false;
      if (user.isRoot) return true;

      final email = user.email;
      if (email.isNotEmpty) {
        final isCoord = await _executorService.isCoordenadorOuGerentePorLogin(email);
        if (isCoord) return true;
      }

      // Usuário comum: verificar se está na lista de executores da tarefa
      if (task.executores.isNotEmpty && user.nome != null && user.nome!.isNotEmpty) {
        final userNomeLower = user.nome!.toLowerCase().trim();
        final match = task.executores.any(
          (e) => e.toLowerCase().trim().contains(userNomeLower) || userNomeLower.contains(e.toLowerCase().trim()),
        );
        if (match) return true;
      }

      // Por padrão em ambiente mobile autenticado, permitir mutação se não houver restrição
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Calcula a matriz semântica de ações disponíveis para a tarefa.
  MobileTaskAvailableActions calculateAvailableActions(
    Task task, {
    bool isReadOnly = false,
  }) {
    if (isReadOnly) {
      return MobileTaskAvailableActions.readOnly();
    }

    final raw = task.status.toUpperCase().trim();
    final unknown = isUnknownStatus(raw);

    // Se o status for desconhecido, desabilitar ações críticas por precaução
    if (unknown) {
      return const MobileTaskAvailableActions(
        canStart: false,
        canPause: false,
        canResume: false,
        canComplete: false,
        canEdit: false,
        canAddEvidence: true,
        canOpenApr: true,
        canOpenChat: true,
        isReadOnly: true,
      );
    }

    switch (raw) {
      case 'PROG':
        return const MobileTaskAvailableActions(
          canStart: true,
          canPause: false,
          canResume: false,
          canComplete: false,
          canEdit: true,
          canAddEvidence: true,
          canOpenApr: true,
          canOpenChat: true,
        );
      case 'ANDA':
        return const MobileTaskAvailableActions(
          canStart: false,
          canPause: true,
          canResume: false,
          canComplete: true,
          canEdit: true,
          canAddEvidence: true,
          canOpenApr: true,
          canOpenChat: true,
        );
      case 'RPAR':
      case 'RPGR':
        return const MobileTaskAvailableActions(
          canStart: false,
          canPause: false,
          canResume: true,
          canComplete: false,
          canEdit: true,
          canAddEvidence: true,
          canOpenApr: true,
          canOpenChat: true,
        );
      case 'CONC':
      case 'CANC':
      default:
        return const MobileTaskAvailableActions(
          canStart: false,
          canPause: false,
          canResume: false,
          canComplete: false,
          canEdit: false,
          canAddEvidence: true,
          canOpenApr: false,
          canOpenChat: true,
          isReadOnly: true,
        );
    }
  }

  /// Converte uma Task em MobileTaskViewModel para card e lista.
  MobileTaskViewModel toViewModel(
    Task task, {
    bool isReadOnly = false,
    bool pendingSync = false,
    bool pendingApr = false,
  }) {
    final statusEnum = mapOperationalStatus(task.status);
    final unknown = isUnknownStatus(task.status);
    final actions = calculateAvailableActions(task, isReadOnly: isReadOnly);

    final locationDisplay = task.locais.isNotEmpty ? task.locais.join(', ') : null;
    final teamDisplay = task.equipes.isNotEmpty ? task.equipes.join(', ') : null;
    final leadDisplay = task.executores.isNotEmpty ? task.executores.first : null;
    final vehicleDisplay = task.frota.isNotEmpty && task.frota != '-N/A-' ? task.frota : null;
    final dateDisplay = _formatDate(task.dataInicio);
    final timeDisplay = _formatTimeWindow(task.dataInicio, task.dataFim);

    // Prioridade real: sem heurística nem valores inventados
    final priorityClean = task.prioridade != null && task.prioridade!.trim().isNotEmpty
        ? task.prioridade!.trim()
        : null;

    return MobileTaskViewModel(
      id: task.id,
      title: task.tarefa,
      rawStatus: task.status,
      status: statusEnum,
      isUnknownStatus: unknown,
      type: task.tipo,
      location: locationDisplay,
      asset: task.segmento.isNotEmpty ? task.segmento : null,
      timeWindow: timeDisplay,
      formattedDate: dateDisplay,
      teamName: teamDisplay,
      leadExecutor: leadDisplay,
      vehiclePlate: vehicleDisplay,
      priority: priorityClean,
      pendingApr: pendingApr,
      pendingSync: pendingSync,
      syncStatus: pendingSync ? TFSyncStatus.pending : TFSyncStatus.synced,
      actions: actions,
    );
  }

  /// Converte uma Task em MobileTaskDetailViewModel com informações ricas.
  MobileTaskDetailViewModel toDetailViewModel(
    Task task, {
    bool isReadOnly = false,
    APR? apr,
    List<Anexo> anexos = const [],
    GrupoChat? chatGroup,
    int unreadChat = 0,
    bool pendingSync = false,
  }) {
    final statusEnum = mapOperationalStatus(task.status);
    final unknown = isUnknownStatus(task.status);
    final actions = calculateAvailableActions(task, isReadOnly: isReadOnly);

    final locationDisplay = task.locais.isNotEmpty ? task.locais.join(', ') : null;
    final teamDisplay = task.equipes.isNotEmpty ? task.equipes.join(', ') : null;
    final leadDisplay = task.executores.isNotEmpty ? task.executores.first : null;
    final vehicleDisplay = task.frota.isNotEmpty && task.frota != '-N/A-' ? task.frota : null;

    // Prioridade factual
    final priorityClean = task.prioridade != null && task.prioridade!.trim().isNotEmpty
        ? task.prioridade!.trim()
        : null;

    // Avaliação do status da APR com base em dados reais
    MobileAprStatus aprStatus = MobileAprStatus.unknown;
    if (apr != null) {
      aprStatus = MobileAprStatus.requiredCompleted;
    } else if (task.precisaSi || (task.prioridade?.toUpperCase().contains('ALTA') ?? false)) {
      aprStatus = MobileAprStatus.requiredPending;
    } else {
      aprStatus = MobileAprStatus.notRequired;
    }

    // Mapeamento factual de evidências
    final evidences = anexos.map((a) {
      return MobileEvidenceItem(
        id: a.id ?? a.nomeArquivo,
        fileName: a.nomeArquivo,
        url: a.caminhoArquivo,
        createdAt: a.createdAt,
      );
    }).toList();

    // Timeline com base exclusivamente em timestamps comprováveis
    final List<MobileTimelineEvent> timeline = [];
    if (task.dataCriacao != null) {
      timeline.add(
        MobileTimelineEvent(
          title: 'Atividade cadastrada',
          timestamp: task.dataCriacao!,
          description: 'Inserida no planejamento',
        ),
      );
    }
    timeline.add(
      MobileTimelineEvent(
        title: 'Início programado',
        timestamp: task.dataInicio,
        description: 'Janela de execução',
      ),
    );
    if (task.dataAtualizacao != null && task.dataAtualizacao != task.dataCriacao) {
      timeline.add(
        MobileTimelineEvent(
          title: task.status == 'CONC' ? 'Atividade concluída' : 'Última atualização',
          timestamp: task.dataAtualizacao!,
        ),
      );
    }

    return MobileTaskDetailViewModel(
      id: task.id,
      title: task.tarefa,
      rawStatus: task.status,
      status: statusEnum,
      isUnknownStatus: unknown,
      type: task.tipo,
      priority: priorityClean,
      location: locationDisplay,
      asset: task.segmento.isNotEmpty ? task.segmento : null,
      regional: task.regional.isNotEmpty ? task.regional : null,
      divisao: task.divisao.isNotEmpty ? task.divisao : null,
      timeWindow: _formatTimeWindow(task.dataInicio, task.dataFim),
      formattedDate: _formatDate(task.dataInicio),
      teamName: teamDisplay,
      leadExecutor: leadDisplay,
      executorsList: task.executores,
      vehiclePlate: vehicleDisplay,
      coordenador: task.coordenador.isNotEmpty ? task.coordenador : null,
      dataInicio: task.dataInicio,
      dataFim: task.dataFim,
      horasPrevistas: task.horasPrevistas,
      horasExecutadas: task.horasExecutadas,
      observations: task.observacoes != null && task.observacoes!.trim().isNotEmpty
          ? task.observacoes!.trim()
          : null,
      sapOrder: task.ordem != null && task.ordem!.trim().isNotEmpty ? task.ordem!.trim() : null,
      sapNotification: null, // Sem inferência: notas sap são carregadas via NotaSAPService se vinculadas
      sapSi: task.si.isNotEmpty ? task.si : null,
      sapAt: null,
      aprStatus: aprStatus,
      evidences: evidences,
      chatGroupId: chatGroup?.id,
      unreadChatCount: unreadChat,
      timelineEvents: timeline,
      actions: actions,
      syncStatus: pendingSync ? TFSyncStatus.pending : TFSyncStatus.synced,
    );
  }

  // ========== OPERAÇÕES DE TRANSIÇÃO DE STATUS ==========

  /// Inicia a execução da tarefa (PROG -> ANDA).
  Future<TaskTransitionResult> startTask(Task task) async {
    return _transitionStatus(task, 'ANDA', 'Atividade iniciada com sucesso.');
  }

  /// Pausa a execução da tarefa (ANDA -> RPAR).
  Future<TaskTransitionResult> pauseTask(Task task) async {
    return _transitionStatus(task, 'RPAR', 'Atividade pausada.');
  }

  /// Retoma a execução da tarefa (RPAR -> ANDA).
  Future<TaskTransitionResult> resumeTask(Task task) async {
    return _transitionStatus(task, 'ANDA', 'Atividade retomada com sucesso.');
  }

  /// Conclui a execução da tarefa (ANDA -> CONC).
  Future<TaskTransitionResult> completeTask(Task task) async {
    return _transitionStatus(task, 'CONC', 'Atividade concluída com sucesso!');
  }

  /// Método centralizado que orquestra a alteração respeitando online e offline-first.
  Future<TaskTransitionResult> _transitionStatus(
    Task task,
    String targetStatus,
    String successMessage,
  ) async {
    final updatedTask = task.copyWith(
      status: targetStatus,
      dataAtualizacao: DateTime.now(),
    );

    final isOnline = _connectivity.isConnected;

    if (isOnline) {
      try {
        final result = await _taskService.updateTask(task.id, updatedTask);
        if (result != null) {
          return TaskTransitionResult(
            success: true,
            isOfflineQueued: false,
            message: successMessage,
            updatedTask: result,
          );
        }
      } catch (e) {
        debugPrint('⚠️ [MobileTaskAdapter] Falha na atualização online: $e. Aplicando fallback offline.');
      }
    }

    // Fluxo Offline-First: persistir localmente e enfileirar na sync_queue
    try {
      await _saveOffline(updatedTask);
      _syncService.markHasLocalChanges();

      return TaskTransitionResult(
        success: true,
        isOfflineQueued: true,
        message: 'Alteração salva no dispositivo. Aguardando sincronização.',
        updatedTask: updatedTask,
      );
    } catch (e) {
      debugPrint('❌ [MobileTaskAdapter] Erro crítico ao salvar offline: $e');
      return TaskTransitionResult(
        success: false,
        isOfflineQueued: false,
        message: 'Não foi possível atualizar a atividade.',
        updatedTask: task,
      );
    }
  }

  /// Salva a tarefa no banco SQLite local e enfileira na fila de sync.
  Future<void> _saveOffline(Task task) async {
    try {
      final db = await _localDb.database;
      final taskMap = {
        'id': task.id,
        'status': task.status,
        'status_id': task.statusId,
        'regional': task.regional,
        'regional_id': task.regionalId,
        'divisao': task.divisao,
        'divisao_id': task.divisaoId,
        'segmento': task.segmento,
        'segmento_id': task.segmentoId,
        'local': task.locais.isNotEmpty ? task.locais.join(', ') : null,
        'tipo': task.tipo,
        'ordem': task.ordem,
        'tarefa': task.tarefa,
        'executor': task.executores.isNotEmpty ? task.executores.join(', ') : task.executor,
        'frota': task.frota,
        'coordenador': task.coordenador,
        'si': task.si,
        'data_inicio': task.dataInicio.millisecondsSinceEpoch,
        'data_fim': task.dataFim.millisecondsSinceEpoch,
        'observacoes': task.observacoes,
        'horas_previstas': task.horasPrevistas,
        'horas_executadas': task.horasExecutadas,
        'prioridade': task.prioridade,
        'parent_id': task.parentId,
        'data_criacao': task.dataCriacao?.millisecondsSinceEpoch,
        'data_atualizacao': DateTime.now().millisecondsSinceEpoch,
        'sync_status': 'pending',
        'last_synced': null,
      };

      await db.insert(
        'tasks_local',
        taskMap,
        conflictAlgorithm: null, // Deixar atualizar ou substituir
      );

      await _localDb.addToSyncQueue(
        'tasks',
        'update',
        task.id,
        taskMap,
      );
    } catch (e) {
      debugPrint('⚠️ [MobileTaskAdapter] _saveOffline: $e');
      rethrow;
    }
  }

  // ========== HELPERS DE FORMATAÇÃO ==========

  static String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  static String _formatTimeWindow(DateTime start, DateTime end) {
    final startStr = '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
    final endStr = '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
    if (startStr == '00:00' && endStr == '00:00') {
      return 'Dia inteiro';
    }
    return '$startStr → $endStr';
  }
}
