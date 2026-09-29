import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_unread_snapshot.dart';
import 'chat_service.dart';

/// Gerenciador central reativo de mensagens não lidas do chat (Single Source of Truth).
/// Mantém o estado consistente entre Header, Comunidades e Grupos, com sincronização Realtime,
/// proteção offline, resiliência a ciclos de vida do app e reconciliação centralizada.
class UnreadChatManager extends ChangeNotifier with WidgetsBindingObserver {
  static final UnreadChatManager _instance = UnreadChatManager._internal();
  factory UnreadChatManager() => _instance;

  UnreadChatManager._internal({
    ChatService? chatService,
    SupabaseClient? supabaseClient,
    RealtimeChannel Function(String channelName)? channelFactory,
  })  : _chatService = chatService ?? ChatService(),
        _supabaseClient = supabaseClient,
        _channelFactory = channelFactory;

  @visibleForTesting
  factory UnreadChatManager.test({
    required ChatService chatService,
    SupabaseClient? supabaseClient,
    RealtimeChannel Function(String channelName)? channelFactory,
  }) {
    return UnreadChatManager._internal(
      chatService: chatService,
      supabaseClient: supabaseClient,
      channelFactory: channelFactory,
    );
  }

  final ChatService _chatService;
  final SupabaseClient? _supabaseClient;
  final RealtimeChannel Function(String channelName)? _channelFactory;

  SupabaseClient? get _supabase {
    if (_supabaseClient != null) return _supabaseClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  // Estado interno
  int _totalUnread = 0;
  Map<String, int> _unreadByCommunity = {};
  Map<String, int> _unreadByGroup = {};
  Map<String, String> _groupToCommunity = {};
  String? _currentUserId;
  String? _activeChatGrupoId;
  DateTime? _lastSync;
  String? _lastSyncError;
  bool _isLoading = false;
  bool _isInitialized = false;

  // Tokens de controle de concorrência e Single-Flight
  int _syncGeneration = 0;
  int _mutationVersion = 0;
  bool _isRefreshing = false;
  bool _reconciliationPending = false;

  // Realtime & Ciclo de vida
  RealtimeChannel? _realtimeChannel;
  bool _hasConnectedRealtime = false;
  Timer? _reconcileDebounceTimer;

  // Coalescência de leitura para o chat ativo (in-flight com pending)
  final Set<String> _activeChatInFlight = <String>{};
  final Set<String> _activeChatPending = <String>{};

  // Deduplicação de eventos de mensagens (fila circular limitada a 200 IDs)
  static const int _maxRecentIds = 200;
  final Set<String> _recentMessageIds = <String>{};
  final List<String> _recentMessageIdsQueue = <String>[];

  // Getters públicos (imutáveis externamente)
  int get totalUnread => _totalUnread;
  Map<String, int> get unreadByCommunity => Map.unmodifiable(_unreadByCommunity);
  Map<String, int> get unreadByGroup => Map.unmodifiable(_unreadByGroup);
  String? get currentUserId => _currentUserId;
  String? get activeChatGrupoId => _activeChatGrupoId;
  DateTime? get lastSync => _lastSync;
  String? get lastSyncError => _lastSyncError;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  int get mutationVersion => _mutationVersion;
  bool get isRealtimeConnected => _hasConnectedRealtime && _realtimeChannel != null;

  @visibleForTesting
  RealtimeChannel? get realtimeChannel => _realtimeChannel;
  @visibleForTesting
  int get activeChannelsCount => _realtimeChannel != null ? 1 : 0;
  @visibleForTesting
  int get processedMessageIdsCount => _recentMessageIds.length;
  @visibleForTesting
  bool get hasInFlightRefresh => _isRefreshing;
  @visibleForTesting
  bool get isReconciliationPending => _reconciliationPending;
  @visibleForTesting
  Set<String> get activeChatInFlight => Set.unmodifiable(_activeChatInFlight);
  @visibleForTesting
  Set<String> get activeChatPending => Set.unmodifiable(_activeChatPending);

  /// Helper de instrumentação temporária de homologação [UNREAD-E2E]
  void _logE2E({
    required String event,
    String? grupoId,
    int? anterior,
    int? posterior,
    String? reason,
    String? realtimeStatus,
  }) {
    final now = DateTime.now().toIso8601String();
    final buf = StringBuffer('[UNREAD-E2E] [$now] user=$_currentUserId event=$event');
    if (grupoId != null) buf.write(' grupo=$grupoId');
    if (anterior != null && posterior != null) buf.write(' count=$anterior->$posterior');
    buf.write(' total=$_totalUnread');
    if (reason != null) buf.write(' reason=$reason');
    if (realtimeStatus != null) buf.write(' rtStatus=$realtimeStatus');
    buf.write(' mutVer=$_mutationVersion gen=$_syncGeneration');
    debugPrint(buf.toString());
  }

  /// Retorna a contagem não lida de um grupo específico (0 se não houver)
  int getUnreadForGroup(String grupoId) => _unreadByGroup[grupoId] ?? 0;

  /// Retorna a contagem não lida de uma comunidade específica (0 se não houver)
  int getUnreadForCommunity(String comunidadeId) => _unreadByCommunity[comunidadeId] ?? 0;

  /// Inicializa o gerenciador com o usuário atual, registra observador de ciclo de vida,
  /// carrega o primeiro snapshot e inicia a subscrição Realtime de forma idempotente.
  Future<void> initialize() async {
    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {
      // Ignora erro em ambientes de teste sem binding completo
    }

    final userId = _chatService.currentUserId;
    if (_currentUserId != userId) {
      resetUser(userId);
    }
    await refreshAll(force: true);
    startRealtime();
    _isInitialized = true;
  }

  @override
  void dispose() {
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}
    stopRealtime();
    super.dispose();
  }

  /// Trata mudanças de estado do ciclo de vida da aplicação (AppLifecycleState).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    handleAppLifecycleState(state);
  }

  /// Ponto de entrada testável para o ciclo de vida do app.
  @visibleForTesting
  void handleAppLifecycleState(AppLifecycleState state) {
    debugPrint('[UNREAD-RT] APP_LIFECYCLE state=$state');
    switch (state) {
      case AppLifecycleState.resumed:
        final userId = _chatService.currentUserId;
        if (userId != null && userId != _currentUserId) {
          resetUser(userId);
        }
        startRealtime();
        scheduleReconciliation('app_resumed', delay: const Duration(milliseconds: 200));
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        // Background: preserva o último snapshot conhecido intacto sem zerar badges
        break;
    }
  }

  /// Inicia a subscription Realtime centralizada para os contadores.
  /// Idempotente: não recria o canal se já estiver ativo.
  void startRealtime() {
    if (_realtimeChannel != null) {
      return; // Já ativo, preserva subscription existente
    }

    final client = _supabase;
    if (client == null && _channelFactory == null) {
      debugPrint('ℹ️ [UNREAD-RT] Supabase client não disponível para Realtime.');
      return;
    }

    final userId = _currentUserId ?? _chatService.currentUserId;
    if (userId == null || userId.isEmpty) {
      debugPrint('ℹ️ [UNREAD-RT] Usuário não identificado; Realtime postergado.');
      return;
    }
    _currentUserId ??= userId;

    final channelName = 'unread_chat_counters_$userId';
    debugPrint('📡 [UNREAD-RT] Criando canal Realtime: $channelName');

    try {
      final channel = _channelFactory != null ? _channelFactory(channelName) : client!.channel(channelName);
      _realtimeChannel = channel
        ..onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'mensagens',
          callback: (payload) => handleMensagemInsert(payload.newRecord),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'mensagens',
          callback: (payload) => handleMensagemUpdate(payload.newRecord),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'mensagens',
          callback: (payload) => handleMensagemDelete(payload.oldRecord),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'mensagens_lidas',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'usuario_id',
            value: userId,
          ),
          callback: (payload) => handleMensagensLidasInsert(payload.newRecord),
        )
        ..subscribe((status, [error]) {
          handleSubscriptionStatus(status, error);
        });
    } catch (e) {
      debugPrint('⚠️ [UNREAD-RT] Erro ao iniciar canal Realtime: $e');
    }
  }

  /// Encerra e remove o canal Realtime ativo.
  void stopRealtime() {
    _reconcileDebounceTimer?.cancel();
    _reconcileDebounceTimer = null;

    if (_realtimeChannel != null) {
      try {
        final client = _supabase;
        _realtimeChannel?.unsubscribe();
        if (client != null) {
          client.removeChannel(_realtimeChannel!);
        }
      } catch (e) {
        debugPrint('⚠️ [UNREAD-RT] Erro ao desinscrever canal: $e');
      }
      _realtimeChannel = null;
    }
    _hasConnectedRealtime = false;
  }

  /// Trata mudança de status da conexão Realtime (incluindo detecção de reconexão).
  @visibleForTesting
  void handleSubscriptionStatus(RealtimeSubscribeStatus status, Object? error) {
    _logE2E(event: 'REALTIME_STATUS', realtimeStatus: status.name);
    if (status == RealtimeSubscribeStatus.subscribed) {
      if (_hasConnectedRealtime) {
        debugPrint('[UNREAD-RT] RECONCILE reason=realtime_reconnected');
        scheduleReconciliation('realtime_reconnected', delay: const Duration(milliseconds: 200));
      } else {
        _hasConnectedRealtime = true;
        debugPrint('✅ [UNREAD-RT] Realtime conectado com sucesso para usuário $_currentUserId');
      }
    } else if (status == RealtimeSubscribeStatus.channelError ||
        status == RealtimeSubscribeStatus.timedOut) {
      debugPrint('⚠️ [UNREAD-RT] Problema na conexão Realtime: $status (${error ?? "sem detalhes"})');
    }
  }

  /// Coordenador central de reconciliação:
  /// Coalesce chamadas concorrentes ou próximas, respeita operações em andamento (single-flight)
  /// e ignora execuções redundantes do watchdog timer.
  void scheduleReconciliation(
    String reason, {
    Duration delay = const Duration(milliseconds: 300),
    bool force = true,
  }) {
    _logE2E(event: 'RECONCILE_SCHEDULED', reason: reason);
    // 1. Regra para watchdog timer: não consultar novamente se houve sync bem-sucedido há menos de 45s
    if (reason == 'watchdog_timer' && _lastSync != null) {
      final diff = DateTime.now().difference(_lastSync!);
      if (diff < const Duration(seconds: 45)) {
        debugPrint('[UNREAD-RT] RECONCILE ignorado para watchdog_timer (sincronizado há ${diff.inSeconds}s)');
        return;
      }
    }

    // 2. Se um refresh já estiver em execução, sinaliza necessidade posterior sem abrir query paralela (Single-Flight)
    if (_isRefreshing) {
      _reconciliationPending = true;
      debugPrint('[UNREAD-RT] RECONCILE enfileirado para após o refresh in-flight (reason=$reason)');
      return;
    }

    // 3. Debounce centralizado
    _reconcileDebounceTimer?.cancel();
    debugPrint('[UNREAD-RT] RECONCILE agendado: reason=$reason (delay=${delay.inMilliseconds}ms)');
    _reconcileDebounceTimer = Timer(delay, () {
      debugPrint('[UNREAD-RT] RECONCILE disparando: reason=$reason');
      refreshAll(force: force);
    });
  }

  /// Sincroniza atomicamente todas as contagens com o backend Supabase.
  /// Protegido por geração contra respostas fora de ordem e com coordenação single-flight para reconciliações.
  Future<void> refreshAll({bool force = false}) async {
    final userId = _chatService.currentUserId;
    if (userId != _currentUserId) {
      resetUser(userId);
    }

    final int currentGeneration = ++_syncGeneration;
    final int startMutationVersion = _mutationVersion;
    _isRefreshing = true;
    _isLoading = true;

    try {
      if (force) {
        invalidateCache();
      }

      final ChatUnreadSnapshot snapshot = await _chatService.carregarSnapshotNaoLidasCompleto();

      // 1. Descarta se outra geração de refresh mais recente iniciou
      if (currentGeneration != _syncGeneration) {
        return;
      }

      // 2. Proteção Realtime x Refresh:
      // Se _mutationVersion mudou durante o tempo em que o snapshot foi buscado no Supabase,
      // significa que eventos Realtime mais novos foram processados localmente.
      if (startMutationVersion != _mutationVersion) {
        debugPrint('[UNREAD-RT] RACE_DETECTED snapshot descartado por mutação concorrente (start=$startMutationVersion, now=$_mutationVersion). Re-agendando.');
        _isLoading = false;
        scheduleReconciliation('race_detected', delay: const Duration(milliseconds: 150));
        return;
      }

      // Substituição atômica de todo o estado
      _totalUnread = snapshot.totalUnread;
      _unreadByCommunity = Map<String, int>.from(snapshot.unreadByCommunity);
      _unreadByGroup = Map<String, int>.from(snapshot.unreadByGroup);
      _groupToCommunity = Map<String, String>.from(snapshot.groupToCommunity);
      _lastSync = snapshot.timestamp;
      _lastSyncError = null;
      _isLoading = false;
      _isInitialized = true;

      _logE2E(event: 'REFRESH_APPLIED', reason: 'success');

      // Notificação atômica e única para todos os ouvintes
      notifyListeners();
    } catch (e) {
      // Se for a geração atual, desliga o loading e registra o erro SEM destruir o snapshot existente
      if (currentGeneration == _syncGeneration) {
        _lastSyncError = e.toString();
        _isLoading = false;
        _logE2E(event: 'REFRESH_ERROR', reason: e.toString());
        notifyListeners();
      }
      debugPrint('⚠️ [UNREAD-RT] Erro ao sincronizar contagens: $e. Mantendo último snapshot válido.');
    } finally {
      if (currentGeneration == _syncGeneration) {
        _isRefreshing = false;
        if (_reconciliationPending) {
          _reconciliationPending = false;
          debugPrint('[UNREAD-RT] REFRESH executando reconciliação pendente acumulada durante o voo');
          scheduleReconciliation('pending_after_in_flight', delay: const Duration(milliseconds: 100), force: true);
        }
      }
    }
  }

  /// Valida deduplicação com histórico circular limitado a 200 IDs.
  bool _isDuplicate(String id) {
    if (_recentMessageIds.contains(id)) {
      return true;
    }
    _recentMessageIds.add(id);
    _recentMessageIdsQueue.add(id);
    if (_recentMessageIdsQueue.length > _maxRecentIds) {
      final oldest = _recentMessageIdsQueue.removeAt(0);
      _recentMessageIds.remove(oldest);
    }
    return false;
  }

  /// Trata evento de INSERT na tabela `mensagens`.
  @visibleForTesting
  void handleMensagemInsert(Map<String, dynamic> record) {
    final sessionUserId = _currentUserId;
    if (sessionUserId == null) return;

    final id = record['id']?.toString();
    final grupoId = record['grupo_id']?.toString();
    final remetenteId = record['usuario_id']?.toString();
    final deletedAt = record['deleted_at'];

    debugPrint('[UNREAD-RT] INSERT mensagem=$id grupo=$grupoId');

    // 1. Deduplicação
    if (id != null && _isDuplicate(id)) {
      _logE2E(event: 'DUPLICATE_IGNORED', grupoId: grupoId);
      debugPrint('[UNREAD-RT] DUPLICATE ignored mensagem=$id');
      return;
    }

    // 2. Validações preliminares
    if (deletedAt != null) return;
    if (grupoId == null || grupoId.isEmpty) return;

    // 3. Remetente é o próprio usuário -> ignorar completamente
    if (remetenteId == sessionUserId) {
      _logE2E(event: 'OWN_MESSAGE_IGNORED', grupoId: grupoId);
      debugPrint('[UNREAD-RT] IGNORE own-message');
      return;
    }

    // 4. Grupo pertence ao snapshot/grupos acessíveis
    if (!_groupToCommunity.containsKey(grupoId)) {
      _logE2E(event: 'INACCESSIBLE_IGNORED', grupoId: grupoId);
      debugPrint('[UNREAD-RT] IGNORE inaccessible-group grupo=$grupoId');
      return;
    }

    // 5. Grupo aberto no chat ativo -> não incrementa e persiste de forma coalescida
    if (grupoId == _activeChatGrupoId) {
      _logE2E(event: 'ACTIVE_CHAT_MSG', grupoId: grupoId);
      debugPrint('[UNREAD-RT] ACTIVE_CHAT mark-read grupo=$grupoId');
      _triggerActiveChatMarkRead(grupoId);
      return;
    }

    // 6. Grupo não aberto -> incrementa atomicamente O(1) sem consultas adicionais
    _mutationVersion++;
    final currentGroup = _unreadByGroup[grupoId] ?? 0;
    final newGroups = Map<String, int>.from(_unreadByGroup);
    newGroups[grupoId] = currentGroup + 1;

    final newCommunities = Map<String, int>.from(_unreadByCommunity);
    final comunidadeId = _groupToCommunity[grupoId];
    if (comunidadeId != null) {
      final currentComm = newCommunities[comunidadeId] ?? 0;
      newCommunities[comunidadeId] = currentComm + 1;
    }

    final oldTotal = _totalUnread;
    _totalUnread = _totalUnread + 1;
    _unreadByGroup = newGroups;
    _unreadByCommunity = newCommunities;

    _logE2E(
      event: 'MSG_INCREMENT',
      grupoId: grupoId,
      anterior: currentGroup,
      posterior: currentGroup + 1,
    );

    debugPrint('[UNREAD-RT] INCREMENT total $oldTotal -> $_totalUnread');
    notifyListeners();
  }

  /// Dispara persistência de leitura para o chat ativo com proteção in-flight e coalescência.
  /// Garante que 10 mensagens simultâneas gerem no máximo 2 passagens de persistência.
  void _triggerActiveChatMarkRead(String grupoId) {
    if (_activeChatInFlight.contains(grupoId)) {
      _activeChatPending.add(grupoId);
      debugPrint('[UNREAD-RT] ACTIVE_CHAT mark-read queued (in-flight active for grupo=$grupoId)');
      return;
    }

    _executeActiveChatMarkRead(grupoId);
  }

  Future<void> _executeActiveChatMarkRead(String grupoId) async {
    _activeChatInFlight.add(grupoId);
    debugPrint('[UNREAD-RT] ACTIVE_CHAT mark-read executing for grupo=$grupoId');

    try {
      await _chatService.marcarMensagensComoLidasPorGrupo(grupoId);
    } catch (e) {
      debugPrint('⚠️ [UNREAD-RT] Falha ao persistir leitura no chat ativo: $e');
      scheduleReconciliation('active_chat_mark_read_failed', delay: const Duration(seconds: 1));
    } finally {
      _activeChatInFlight.remove(grupoId);

      // Se novas mensagens chegaram durante a persistência, executa uma segunda passagem controlada
      if (_activeChatPending.contains(grupoId)) {
        _activeChatPending.remove(grupoId);
        debugPrint('[UNREAD-RT] ACTIVE_CHAT mark-read second pass for grupo=$grupoId');
        _executeActiveChatMarkRead(grupoId);
      }
    }
  }

  /// Trata UPDATE na tabela `mensagens` (detecta soft-delete).
  @visibleForTesting
  void handleMensagemUpdate(Map<String, dynamic> record) {
    if (record['deleted_at'] != null) {
      debugPrint('[UNREAD-RT] RECONCILE reason=soft_delete_mensagem id=${record['id']}');
      scheduleReconciliation('soft_delete_mensagem');
    }
  }

  /// Trata DELETE na tabela `mensagens`.
  @visibleForTesting
  void handleMensagemDelete(Map<String, dynamic> record) {
    debugPrint('[UNREAD-RT] RECONCILE reason=delete_mensagem id=${record['id']}');
    scheduleReconciliation('delete_mensagem');
  }

  /// Trata INSERT na tabela `mensagens_lidas` (ex: leitura em outro dispositivo).
  @visibleForTesting
  void handleMensagensLidasInsert(Map<String, dynamic> record) {
    final sessionUserId = _currentUserId;
    if (sessionUserId == null) return;

    // Filtro rigoroso client-side: somente eventos do próprio usuário
    if (record['usuario_id']?.toString() != sessionUserId) {
      return;
    }

    debugPrint('[UNREAD-RT] RECONCILE reason=mensagens_lidas_insert usuario=$sessionUserId');
    scheduleReconciliation('mensagens_lidas_insert');
  }

  /// Invalida o cache em memória e marca para recarga
  void invalidateCache() {
    _chatService.invalidarCacheNaoLidas();
    _lastSync = null;
  }

  /// Limpa imediatamente todo o estado ao detectar logout ou troca de usuário
  void resetUser(String? newUserId) {
    debugPrint('[UNREAD-RT] SESSION_CHANGED old=$_currentUserId new=$newUserId');
    stopRealtime();
    _reconcileDebounceTimer?.cancel();
    _reconcileDebounceTimer = null;
    _reconciliationPending = false;
    _isRefreshing = false;
    _activeChatInFlight.clear();
    _activeChatPending.clear();

    _currentUserId = newUserId;
    _totalUnread = 0;
    _unreadByCommunity = {};
    _unreadByGroup = {};
    _groupToCommunity = {};
    _activeChatGrupoId = null;
    _lastSync = null;
    _lastSyncError = null;
    _isLoading = false;
    _recentMessageIds.clear();
    _recentMessageIdsQueue.clear();
    _syncGeneration++;
    _mutationVersion++;
    invalidateCache();

    _logE2E(event: 'SESSION_CHANGED', reason: 'user_reset');
    notifyListeners();
  }

  /// Define o grupo de chat atualmente visualizado pelo usuário
  void setActiveChat(String? grupoId) {
    if (_activeChatGrupoId != grupoId) {
      _activeChatGrupoId = grupoId;
      notifyListeners();
    }
  }

  /// Limpa o grupo de chat ativo (ex: ao fechar a janela do chat)
  void clearActiveChat() {
    setActiveChat(null);
  }

  /// Atualização otimista local ao abrir um grupo de chat:
  /// Zera o contador do grupo e desconta da comunidade e do total.
  /// Garante que nenhum contador fique negativo.
  void markGroupAsReadLocal(String grupoId) {
    final currentGroupUnread = _unreadByGroup[grupoId] ?? 0;
    if (currentGroupUnread <= 0) return;

    _mutationVersion++;
    final newGroups = Map<String, int>.from(_unreadByGroup);
    newGroups[grupoId] = 0;

    final newCommunities = Map<String, int>.from(_unreadByCommunity);
    final comunidadeId = _groupToCommunity[grupoId];
    if (comunidadeId != null && newCommunities.containsKey(comunidadeId)) {
      final currentCommUnread = newCommunities[comunidadeId] ?? 0;
      final updatedCommUnread = currentCommUnread - currentGroupUnread;
      newCommunities[comunidadeId] = updatedCommUnread < 0 ? 0 : updatedCommUnread;
    }

    final newTotal = _totalUnread - currentGroupUnread;
    _totalUnread = newTotal < 0 ? 0 : newTotal;
    _unreadByGroup = newGroups;
    _unreadByCommunity = newCommunities;

    _logE2E(
      event: 'READ_LOCAL',
      grupoId: grupoId,
      anterior: currentGroupUnread,
      posterior: 0,
      reason: 'mark_group_as_read_local',
    );

    notifyListeners();
  }
}


