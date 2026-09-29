import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:task2026/models/chat_unread_snapshot.dart';
import 'package:task2026/services/chat_service.dart';
import 'package:task2026/services/unread_chat_manager.dart';

/// Test doubles e mocks controláveis para homologação E2E multi-sessão
class MockRealtimeChannelHomologacao implements RealtimeChannel {
  @override
  final String topic;
  void Function(RealtimeSubscribeStatus status, Object? error)? _statusCallback;
  bool isUnsubscribed = false;

  MockRealtimeChannelHomologacao(this.topic);

  @override
  RealtimeChannel onPostgresChanges({
    required PostgresChangeEvent event,
    String? schema,
    String? table,
    PostgresChangeFilter? filter,
    required void Function(PostgresChangePayload payload) callback,
  }) {
    return this;
  }

  @override
  RealtimeChannel subscribe([void Function(RealtimeSubscribeStatus status, Object? error)? callback, Duration? timeout]) {
    _statusCallback = callback;
    callback?.call(RealtimeSubscribeStatus.subscribed, null);
    return this;
  }

  @override
  Future<String> unsubscribe([Duration? timeout]) async {
    isUnsubscribed = true;
    _statusCallback?.call(RealtimeSubscribeStatus.closed, null);
    return 'ok';
  }

  void simulateStatus(RealtimeSubscribeStatus status, [Object? error]) {
    _statusCallback?.call(status, error);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeChatServiceHomologacao extends ChatService {
  String? fakeUserId;
  ChatUnreadSnapshot currentSnapshot;
  int markAsReadCallCount = 0;
  List<String> markedGroups = [];
  Completer<void>? markAsReadCompleter;

  FakeChatServiceHomologacao({
    this.fakeUserId,
    required this.currentSnapshot,
  }) : super.forTesting();

  @override
  String? get currentUserId => fakeUserId;

  @override
  Future<ChatUnreadSnapshot> carregarSnapshotNaoLidasCompleto() async {
    return currentSnapshot;
  }

  @override
  Future<void> marcarMensagensComoLidasPorGrupo(String grupoIdOuTarefaId) async {
    markAsReadCallCount++;
    markedGroups.add(grupoIdOuTarefaId);
    if (markAsReadCompleter != null) {
      await markAsReadCompleter!.future;
    }
  }

  @override
  void invalidarCacheNaoLidas() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String userA = 'user-homolog-A-web';
  const String userB = 'user-homolog-B-mobile';
  const String grupoHomologId = 'grupo-homolog-2026';
  const String comunidadeHomologId = 'comunidade-geral';

  group('FASE 6 — HOMOLOGAÇÃO PONTA A PONTA DO CONTADOR DE CHAT', () {
    // -------------------------------------------------------------------------
    // CENÁRIO 1 — MENSAGEM SIMPLES
    // -------------------------------------------------------------------------
    test('Cenário 1: Mensagem Simples de A para B (B recebe +1 via Realtime em tempo real)', () async {
      final fakeServiceB = FakeChatServiceHomologacao(
        fakeUserId: userB,
        currentSnapshot: ChatUnreadSnapshot(
          totalUnread: 0,
          unreadByCommunity: {comunidadeHomologId: 0},
          unreadByGroup: {grupoHomologId: 0},
          groupToCommunity: {grupoHomologId: comunidadeHomologId},
          timestamp: DateTime.now(),
        ),
      );

      final managerB = UnreadChatManager.test(
        chatService: fakeServiceB,
        channelFactory: (name) => MockRealtimeChannelHomologacao(name),
      );

      await managerB.initialize();
      expect(managerB.totalUnread, 0);

      final sw = Stopwatch()..start();

      // Usuário A envia 1 mensagem para o grupo compartilhado
      managerB.handleMensagemInsert({
        'id': 'msg-simples-1',
        'grupo_id': grupoHomologId,
        'usuario_id': userA,
      });

      sw.stop();

      // Validação de contadores imediatos
      expect(managerB.getUnreadForGroup(grupoHomologId), 1, reason: 'Grupo deve ser +1');
      expect(managerB.getUnreadForCommunity(comunidadeHomologId), 1, reason: 'Comunidade deve ser +1');
      expect(managerB.totalUnread, 1, reason: 'Header deve ser +1');
      expect(sw.elapsedMilliseconds, lessThan(50), reason: 'Atualização Realtime deve ser instantânea');
    });

    // -------------------------------------------------------------------------
    // CENÁRIO 2 — MENSAGEM PRÓPRIA
    // -------------------------------------------------------------------------
    test('Cenário 2: Mensagem Própria (Usuário A envia mensagem, contador de A não aumenta)', () async {
      final fakeServiceA = FakeChatServiceHomologacao(
        fakeUserId: userA,
        currentSnapshot: ChatUnreadSnapshot(
          totalUnread: 3,
          unreadByCommunity: {comunidadeHomologId: 3},
          unreadByGroup: {grupoHomologId: 3},
          groupToCommunity: {grupoHomologId: comunidadeHomologId},
          timestamp: DateTime.now(),
        ),
      );

      final managerA = UnreadChatManager.test(
        chatService: fakeServiceA,
        channelFactory: (name) => MockRealtimeChannelHomologacao(name),
      );

      await managerA.initialize();
      expect(managerA.totalUnread, 3);

      // Usuário A envia mensagem no grupo
      managerA.handleMensagemInsert({
        'id': 'msg-propria-1',
        'grupo_id': grupoHomologId,
        'usuario_id': userA, // Próprio remetente
      });

      // Validação: contadores rigorosamente inalterados
      expect(managerA.getUnreadForGroup(grupoHomologId), 3);
      expect(managerA.getUnreadForCommunity(comunidadeHomologId), 3);
      expect(managerA.totalUnread, 3, reason: 'Header inalterado para mensagens próprias');
    });

    // -------------------------------------------------------------------------
    // CENÁRIO 3 — RAJADA
    // -------------------------------------------------------------------------
    test('Cenário 3: Rajada (A envia 10 mensagens rápidas para B, B recebe exatamente +10)', () async {
      final fakeServiceB = FakeChatServiceHomologacao(
        fakeUserId: userB,
        currentSnapshot: ChatUnreadSnapshot(
          totalUnread: 0,
          unreadByCommunity: {comunidadeHomologId: 0},
          unreadByGroup: {grupoHomologId: 0},
          groupToCommunity: {grupoHomologId: comunidadeHomologId},
          timestamp: DateTime.now(),
        ),
      );

      final managerB = UnreadChatManager.test(
        chatService: fakeServiceB,
        channelFactory: (name) => MockRealtimeChannelHomologacao(name),
      );

      await managerB.initialize();

      // Envia rajada de 10 mensagens
      for (int i = 1; i <= 10; i++) {
        managerB.handleMensagemInsert({
          'id': 'rajada-msg-$i',
          'grupo_id': grupoHomologId,
          'usuario_id': userA,
        });
      }

      // Validação: contagem exata +10
      expect(managerB.getUnreadForGroup(grupoHomologId), 10);
      expect(managerB.getUnreadForCommunity(comunidadeHomologId), 10);
      expect(managerB.totalUnread, 10, reason: 'B deve ter exatamente +10 após rajada');
    });

    // -------------------------------------------------------------------------
    // CENÁRIO 4 — LEITURA
    // -------------------------------------------------------------------------
    test('Cenário 4: Leitura (B abre o grupo com 10 não lidas -> zera grupo, comunidade e header)', () async {
      final fakeServiceB = FakeChatServiceHomologacao(
        fakeUserId: userB,
        currentSnapshot: ChatUnreadSnapshot(
          totalUnread: 10,
          unreadByCommunity: {comunidadeHomologId: 10},
          unreadByGroup: {grupoHomologId: 10},
          groupToCommunity: {grupoHomologId: comunidadeHomologId},
          timestamp: DateTime.now(),
        ),
      );

      final managerB = UnreadChatManager.test(
        chatService: fakeServiceB,
        channelFactory: (name) => MockRealtimeChannelHomologacao(name),
      );

      await managerB.initialize();
      expect(managerB.totalUnread, 10);

      // B abre o grupo
      managerB.markGroupAsReadLocal(grupoHomologId);

      // Validação: zerado localmente de forma atômica
      expect(managerB.getUnreadForGroup(grupoHomologId), 0);
      expect(managerB.getUnreadForCommunity(comunidadeHomologId), 0);
      expect(managerB.totalUnread, 0);
    });

    // -------------------------------------------------------------------------
    // CENÁRIO 5 — INDEPENDÊNCIA ENTRE USUÁRIOS
    // -------------------------------------------------------------------------
    test('Cenário 5: Independência entre Usuários (A abre chat -> A zera, B permanece inalterado)', () async {
      final fakeServiceA = FakeChatServiceHomologacao(
        fakeUserId: userA,
        currentSnapshot: ChatUnreadSnapshot(
          totalUnread: 5,
          unreadByCommunity: {comunidadeHomologId: 5},
          unreadByGroup: {grupoHomologId: 5},
          groupToCommunity: {grupoHomologId: comunidadeHomologId},
          timestamp: DateTime.now(),
        ),
      );
      final fakeServiceB = FakeChatServiceHomologacao(
        fakeUserId: userB,
        currentSnapshot: ChatUnreadSnapshot(
          totalUnread: 5,
          unreadByCommunity: {comunidadeHomologId: 5},
          unreadByGroup: {grupoHomologId: 5},
          groupToCommunity: {grupoHomologId: comunidadeHomologId},
          timestamp: DateTime.now(),
        ),
      );

      final managerA = UnreadChatManager.test(chatService: fakeServiceA);
      final managerB = UnreadChatManager.test(chatService: fakeServiceB);

      await managerA.initialize();
      await managerB.initialize();

      expect(managerA.totalUnread, 5);
      expect(managerB.totalUnread, 5);

      // A abre o grupo
      managerA.markGroupAsReadLocal(grupoHomologId);

      // Validação: A zerou, B permanece com 5 intactas
      expect(managerA.totalUnread, 0);
      expect(managerB.totalUnread, 5, reason: 'Leitura de A não deve afetar contadores de B');
      expect(managerB.getUnreadForGroup(grupoHomologId), 5);
    });

    // -------------------------------------------------------------------------
    // CENÁRIO 6 — CHAT ABERTO
    // -------------------------------------------------------------------------
    test('Cenário 6: Chat Aberto (B com chat ativo recebe 10 msgs -> badge 0 e coalescência)', () async {
      final fakeServiceB = FakeChatServiceHomologacao(
        fakeUserId: userB,
        currentSnapshot: ChatUnreadSnapshot(
          totalUnread: 0,
          unreadByCommunity: {comunidadeHomologId: 0},
          unreadByGroup: {grupoHomologId: 0},
          groupToCommunity: {grupoHomologId: comunidadeHomologId},
          timestamp: DateTime.now(),
        ),
      );

      final managerB = UnreadChatManager.test(
        chatService: fakeServiceB,
        channelFactory: (name) => MockRealtimeChannelHomologacao(name),
      );

      await managerB.initialize();

      // B define o grupo como chat ativo
      managerB.setActiveChat(grupoHomologId);
      expect(managerB.activeChatGrupoId, grupoHomologId);

      // A envia 10 mensagens rapidamente para esse grupo
      for (int i = 1; i <= 10; i++) {
        managerB.handleMensagemInsert({
          'id': 'chat-aberto-msg-$i',
          'grupo_id': grupoHomologId,
          'usuario_id': userA,
        });
      }

      // Badge não acumula para o chat ativo
      expect(managerB.getUnreadForGroup(grupoHomologId), 0);
      expect(managerB.totalUnread, 0);

      // Validação da coalescência: não disparou 10 operações concorrentes
      await Future.delayed(const Duration(milliseconds: 50));
      expect(fakeServiceB.markAsReadCallCount, lessThanOrEqualTo(2),
          reason: 'Coalescência deve executar no máximo 2 passagens');
    });

    // -------------------------------------------------------------------------
    // CENÁRIO 7 — LEITURA MULTIDISPOSITIVO
    // -------------------------------------------------------------------------
    test('Cenário 7: Leitura Multidispositivo (B-Mobile lê -> B-Web converge para 0 via Realtime)', () async {
      final fakeServiceWeb = FakeChatServiceHomologacao(
        fakeUserId: userB,
        currentSnapshot: ChatUnreadSnapshot(
          totalUnread: 4,
          unreadByCommunity: {comunidadeHomologId: 4},
          unreadByGroup: {grupoHomologId: 4},
          groupToCommunity: {grupoHomologId: comunidadeHomologId},
          timestamp: DateTime.now(),
        ),
      );

      final managerBWeb = UnreadChatManager.test(
        chatService: fakeServiceWeb,
        channelFactory: (name) => MockRealtimeChannelHomologacao(name),
      );

      await managerBWeb.initialize();
      expect(managerBWeb.totalUnread, 4);

      // Simula que B-Mobile leu as mensagens: backend atualiza snapshot para 0
      fakeServiceWeb.currentSnapshot = ChatUnreadSnapshot(
        totalUnread: 0,
        unreadByCommunity: {comunidadeHomologId: 0},
        unreadByGroup: {grupoHomologId: 0},
        groupToCommunity: {grupoHomologId: comunidadeHomologId},
        timestamp: DateTime.now(),
      );

      // Evento de inserção em mensagens_lidas para o userB recebido no Web
      managerBWeb.handleMensagensLidasInsert({
        'id': 'lida-e2e-1',
        'usuario_id': userB,
      });

      // Aguarda o debounce de reconciliação (300ms)
      await Future.delayed(const Duration(milliseconds: 350));

      // B-Web convergiu para 0
      expect(managerBWeb.totalUnread, 0, reason: 'B-Web deve convergir automaticamente para 0');
    });

    // -------------------------------------------------------------------------
    // CENÁRIO 8 — OFFLINE
    // -------------------------------------------------------------------------
    test('Cenário 8: Offline (B offline mantém snapshot; reconexão recupera +5 pendentes)', () async {
      final fakeServiceB = FakeChatServiceHomologacao(
        fakeUserId: userB,
        currentSnapshot: ChatUnreadSnapshot(
          totalUnread: 2,
          unreadByCommunity: {comunidadeHomologId: 2},
          unreadByGroup: {grupoHomologId: 2},
          groupToCommunity: {grupoHomologId: comunidadeHomologId},
          timestamp: DateTime.now(),
        ),
      );

      MockRealtimeChannelHomologacao? testChannel;
      final managerB = UnreadChatManager.test(
        chatService: fakeServiceB,
        channelFactory: (name) {
          testChannel = MockRealtimeChannelHomologacao(name);
          return testChannel!;
        },
      );

      await managerB.initialize();
      expect(managerB.totalUnread, 2);

      // Simula perda de conexão Realtime
      testChannel!.simulateStatus(RealtimeSubscribeStatus.channelError, 'Sem internet');

      // Enquanto offline: snapshot preservado intacto
      expect(managerB.totalUnread, 2);

      // Durante a desconexão, chegaram 5 novas mensagens no backend (total passa para 7)
      fakeServiceB.currentSnapshot = ChatUnreadSnapshot(
        totalUnread: 7,
        unreadByCommunity: {comunidadeHomologId: 7},
        unreadByGroup: {grupoHomologId: 7},
        groupToCommunity: {grupoHomologId: comunidadeHomologId},
        timestamp: DateTime.now(),
      );

      // Conexão restabelecida
      testChannel!.simulateStatus(RealtimeSubscribeStatus.subscribed);

      // Aguarda reconciliação pós-reconexão
      await Future.delayed(const Duration(milliseconds: 250));

      // B convergiu para 7 (+5 novas)
      expect(managerB.totalUnread, 7, reason: 'B deve convergir exatamente para 7 após reconexão');
    });

    // -------------------------------------------------------------------------
    // CENÁRIO 9 — BACKGROUND
    // -------------------------------------------------------------------------
    test('Cenário 9: Background (Mobile em background -> AppLifecycleState.resumed reconcilia)', () async {
      final fakeServiceB = FakeChatServiceHomologacao(
        fakeUserId: userB,
        currentSnapshot: ChatUnreadSnapshot(
          totalUnread: 1,
          unreadByCommunity: {comunidadeHomologId: 1},
          unreadByGroup: {grupoHomologId: 1},
          groupToCommunity: {grupoHomologId: comunidadeHomologId},
          timestamp: DateTime.now(),
        ),
      );

      final managerB = UnreadChatManager.test(
        chatService: fakeServiceB,
        channelFactory: (name) => MockRealtimeChannelHomologacao(name),
      );

      await managerB.initialize();

      // App vai para background
      managerB.handleAppLifecycleState(AppLifecycleState.paused);
      expect(managerB.totalUnread, 1, reason: 'Snapshot preservado em background');

      // Mensagens chegam no backend enquanto app estava suspenso
      fakeServiceB.currentSnapshot = ChatUnreadSnapshot(
        totalUnread: 4,
        unreadByCommunity: {comunidadeHomologId: 4},
        unreadByGroup: {grupoHomologId: 4},
        groupToCommunity: {grupoHomologId: comunidadeHomologId},
        timestamp: DateTime.now(),
      );

      // App retorna para primeiro plano
      managerB.handleAppLifecycleState(AppLifecycleState.resumed);

      // Aguarda reconciliação disparada pelo resume (200ms)
      await Future.delayed(const Duration(milliseconds: 250));

      expect(managerB.totalUnread, 4, reason: 'Reconciliação recupera snapshot correto no resume');
    });

    // -------------------------------------------------------------------------
    // CENÁRIO 10 — SUSPENSÃO WEB
    // -------------------------------------------------------------------------
    test('Cenário 10: Suspensão Web (Aba inativa/reativada recupera estado)', () async {
      final fakeServiceWeb = FakeChatServiceHomologacao(
        fakeUserId: userA,
        currentSnapshot: ChatUnreadSnapshot(
          totalUnread: 2,
          unreadByCommunity: {comunidadeHomologId: 2},
          unreadByGroup: {grupoHomologId: 2},
          groupToCommunity: {grupoHomologId: comunidadeHomologId},
          timestamp: DateTime.now(),
        ),
      );

      final managerWeb = UnreadChatManager.test(
        chatService: fakeServiceWeb,
        channelFactory: (name) => MockRealtimeChannelHomologacao(name),
      );

      await managerWeb.initialize();

      // Aba suspensa
      managerWeb.handleAppLifecycleState(AppLifecycleState.hidden);

      // Novas mensagens adicionadas
      fakeServiceWeb.currentSnapshot = ChatUnreadSnapshot(
        totalUnread: 6,
        unreadByCommunity: {comunidadeHomologId: 6},
        unreadByGroup: {grupoHomologId: 6},
        groupToCommunity: {grupoHomologId: comunidadeHomologId},
        timestamp: DateTime.now(),
      );

      // Aba reativada
      managerWeb.handleAppLifecycleState(AppLifecycleState.resumed);
      await Future.delayed(const Duration(milliseconds: 250));

      expect(managerWeb.totalUnread, 6);
    });

    // -------------------------------------------------------------------------
    // CENÁRIO 11 — DELETE
    // -------------------------------------------------------------------------
    test('Cenário 11: Delete / Soft-delete (Reconciliação segura sem decremento especulativo)', () async {
      final fakeService = FakeChatServiceHomologacao(
        fakeUserId: userB,
        currentSnapshot: ChatUnreadSnapshot(
          totalUnread: 3,
          unreadByCommunity: {comunidadeHomologId: 3},
          unreadByGroup: {grupoHomologId: 3},
          groupToCommunity: {grupoHomologId: comunidadeHomologId},
          timestamp: DateTime.now(),
        ),
      );

      final manager = UnreadChatManager.test(
        chatService: fakeService,
        channelFactory: (name) => MockRealtimeChannelHomologacao(name),
      );

      await manager.initialize();
      expect(manager.totalUnread, 3);

      // Uma mensagem foi excluída no backend (total passa a ser 2)
      fakeService.currentSnapshot = ChatUnreadSnapshot(
        totalUnread: 2,
        unreadByCommunity: {comunidadeHomologId: 2},
        unreadByGroup: {grupoHomologId: 2},
        groupToCommunity: {grupoHomologId: comunidadeHomologId},
        timestamp: DateTime.now(),
      );

      // Evento de UPDATE com soft-delete recebido
      manager.handleMensagemUpdate({
        'id': 'msg-deletada-1',
        'deleted_at': DateTime.now().toIso8601String(),
      });

      // Aguarda reconciliação
      await Future.delayed(const Duration(milliseconds: 350));

      // Contadores convergiram perfeitamente
      expect(manager.totalUnread, 2);
    });

    // -------------------------------------------------------------------------
    // CENÁRIO 12 — LOGOUT / LOGIN
    // -------------------------------------------------------------------------
    test('Cenário 12: Logout / Login (Logout de A zera contadores imediatamente; login de B exibe somente snapshot de B)', () async {
      final fakeService = FakeChatServiceHomologacao(
        fakeUserId: userA,
        currentSnapshot: ChatUnreadSnapshot(
          totalUnread: 8,
          unreadByCommunity: {comunidadeHomologId: 8},
          unreadByGroup: {grupoHomologId: 8},
          groupToCommunity: {grupoHomologId: comunidadeHomologId},
          timestamp: DateTime.now(),
        ),
      );

      final manager = UnreadChatManager.test(
        chatService: fakeService,
        channelFactory: (name) => MockRealtimeChannelHomologacao(name),
      );

      await manager.initialize();
      expect(manager.totalUnread, 8);

      // Logout de A
      manager.resetUser(null);
      expect(manager.totalUnread, 0, reason: 'Logout deve zerar o Header imediatamente');
      expect(manager.unreadByGroup.isEmpty, true);
      expect(manager.unreadByCommunity.isEmpty, true);

      // Login de B com seus próprios contadores (ex: 3)
      fakeService.fakeUserId = userB;
      fakeService.currentSnapshot = ChatUnreadSnapshot(
        totalUnread: 3,
        unreadByCommunity: {comunidadeHomologId: 3},
        unreadByGroup: {grupoHomologId: 3},
        groupToCommunity: {grupoHomologId: comunidadeHomologId},
        timestamp: DateTime.now(),
      );

      manager.resetUser(userB);
      await manager.refreshAll();

      expect(manager.currentUserId, userB);
      expect(manager.totalUnread, 3, reason: 'Login de B deve exibir exclusivamente o snapshot de B');
    });

    // -------------------------------------------------------------------------
    // CENÁRIO 13 — TROCA RÁPIDA DE SESSÃO
    // -------------------------------------------------------------------------
    test('Cenário 13: Troca Rápida de Sessão (Resposta atrasada de A é descartada por syncGeneration)', () async {
      final fakeService = FakeChatServiceHomologacao(
        fakeUserId: userA,
        currentSnapshot: ChatUnreadSnapshot(
          totalUnread: 10,
          unreadByCommunity: {comunidadeHomologId: 10},
          unreadByGroup: {grupoHomologId: 10},
          groupToCommunity: {grupoHomologId: comunidadeHomologId},
          timestamp: DateTime.now(),
        ),
      );

      final manager = UnreadChatManager.test(chatService: fakeService);

      // Inicia sincronização de A
      manager.resetUser(userA);
      final refreshFutureA = manager.refreshAll();

      // Imediatamente: logout de A e login de B
      manager.resetUser(userB);
      fakeService.fakeUserId = userB;
      fakeService.currentSnapshot = ChatUnreadSnapshot(
        totalUnread: 2,
        unreadByCommunity: {comunidadeHomologId: 2},
        unreadByGroup: {grupoHomologId: 2},
        groupToCommunity: {grupoHomologId: comunidadeHomologId},
        timestamp: DateTime.now(),
      );

      await manager.refreshAll();
      expect(manager.totalUnread, 2);

      // Resposta atrasada de A conclui
      await refreshFutureA;

      // Estado permanece sendo o de B, pois geração de A foi descartada
      expect(manager.currentUserId, userB);
      expect(manager.totalUnread, 2, reason: 'Geração anterior de A deve ser descartada');
    });

    // -------------------------------------------------------------------------
    // CENÁRIO 14 — RECONEXÕES REPETIDAS
    // -------------------------------------------------------------------------
    test('Cenário 14: Reconexões Repetidas (Garante exatamente 1 canal Realtime ativo)', () async {
      int channelCreationCount = 0;
      MockRealtimeChannelHomologacao? currentChannel;

      final fakeService = FakeChatServiceHomologacao(
        fakeUserId: userB,
        currentSnapshot: ChatUnreadSnapshot(
          totalUnread: 0,
          unreadByCommunity: {},
          unreadByGroup: {},
          groupToCommunity: {},
          timestamp: DateTime.now(),
        ),
      );

      final manager = UnreadChatManager.test(
        chatService: fakeService,
        channelFactory: (name) {
          channelCreationCount++;
          currentChannel = MockRealtimeChannelHomologacao(name);
          return currentChannel!;
        },
      );

      await manager.initialize();
      expect(channelCreationCount, 1);
      expect(manager.activeChannelsCount, 1);

      // Simula múltiplas oscilações de status
      for (int i = 0; i < 5; i++) {
        currentChannel!.simulateStatus(RealtimeSubscribeStatus.channelError, 'oscilação');
        currentChannel!.simulateStatus(RealtimeSubscribeStatus.subscribed);
        // startRealtime idempotente não cria novos canais se já existe um ativo
        manager.startRealtime();
      }

      // Validação: exatamente 1 canal ativo mantido
      expect(manager.activeChannelsCount, 1);
      expect(channelCreationCount, 1, reason: 'Nunca deve acumular canais Realtime');
    });

    // -------------------------------------------------------------------------
    // CENÁRIO 15 — WATCHDOG
    // -------------------------------------------------------------------------
    test('Cenário 15: Watchdog (Timer de 60s ignora execução se sync recente ocorreu há < 45s)', () async {
      final fakeService = FakeChatServiceHomologacao(
        fakeUserId: userB,
        currentSnapshot: ChatUnreadSnapshot(
          totalUnread: 4,
          unreadByCommunity: {comunidadeHomologId: 4},
          unreadByGroup: {grupoHomologId: 4},
          groupToCommunity: {grupoHomologId: comunidadeHomologId},
          timestamp: DateTime.now(), // Recente (0s)
        ),
      );

      final manager = UnreadChatManager.test(chatService: fakeService);
      await manager.initialize();
      expect(manager.totalUnread, 4);

      // Watchdog dispara quando sync ocorreu há segundos
      manager.scheduleReconciliation('watchdog_timer');

      await Future.delayed(const Duration(milliseconds: 350));

      // Contagem inalterada e nenhuma oscilação de badge
      expect(manager.totalUnread, 4);
      expect(manager.lastSyncError, isNull);
    });
  });
}
