import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:task2026/models/chat_unread_snapshot.dart';
import 'package:task2026/services/chat_service.dart';
import 'package:task2026/services/unread_chat_manager.dart';

class MockChatServiceForResilience extends ChatService {
  MockChatServiceForResilience({this.userId = 'user-1'}) : super.forTesting();

  String? userId;
  ChatUnreadSnapshot? nextSnapshot;
  int refreshCallCount = 0;
  int markReadCallCount = 0;
  List<String> markedReadGroups = [];
  bool shouldFailRefresh = false;
  bool shouldFailMarkRead = false;
  Completer<ChatUnreadSnapshot>? slowRefreshCompleter;
  Completer<void>? slowMarkReadCompleter;

  @override
  String? get currentUserId => userId;

  @override
  Future<ChatUnreadSnapshot> carregarSnapshotNaoLidasCompleto() async {
    refreshCallCount++;
    if (slowRefreshCompleter != null) {
      await slowRefreshCompleter!.future;
    }
    if (shouldFailRefresh) {
      throw Exception('Simulated network offline');
    }
    return nextSnapshot ?? ChatUnreadSnapshot.empty();
  }

  @override
  Future<void> marcarMensagensComoLidasPorGrupo(String grupoIdOuTarefaId) async {
    markReadCallCount++;
    if (slowMarkReadCompleter != null) {
      await slowMarkReadCompleter!.future;
    }
    if (shouldFailMarkRead) {
      throw Exception('Simulated mark-read network failure');
    }
    markedReadGroups.add(grupoIdOuTarefaId);
  }
}

class FakeChannelForTest implements RealtimeChannel {
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
    callback?.call(RealtimeSubscribeStatus.subscribed, null);
    return this;
  }

  @override
  Future<String> unsubscribe([Duration? timeout]) async {
    return 'ok';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Fase 5: Resiliência, Reconexão, Offline e Reconciliação', () {
    late MockChatServiceForResilience mockService;
    late UnreadChatManager manager;

    setUp(() async {
      mockService = MockChatServiceForResilience(userId: 'user-1');
      mockService.nextSnapshot = ChatUnreadSnapshot(
        totalUnread: 5,
        unreadByCommunity: {'comm-1': 5, 'comm-2': 0},
        unreadByGroup: {'g1': 3, 'g2': 2, 'g3': 0},
        groupToCommunity: {'g1': 'comm-1', 'g2': 'comm-1', 'g3': 'comm-2'},
        timestamp: DateTime.now(),
      );

      manager = UnreadChatManager.test(chatService: mockService);
      await manager.initialize();
    });

    tearDown(() {
      manager.stopRealtime();
    });

    test('1. Erro de rede durante refreshAll() mantém o último snapshot válido intacto', () async {
      expect(manager.totalUnread, equals(5));
      expect(manager.getUnreadForGroup('g1'), equals(3));

      // Simula queda de rede no Supabase
      mockService.shouldFailRefresh = true;

      await manager.refreshAll(force: true);

      // Snapshot não foi zerado!
      expect(manager.totalUnread, equals(5));
      expect(manager.getUnreadForGroup('g1'), equals(3));
      expect(manager.getUnreadForGroup('g2'), equals(2));
      expect(manager.getUnreadForCommunity('comm-1'), equals(5));
      expect(manager.lastSyncError, isNotNull);
      expect(manager.isLoading, isFalse);
    });

    test('2. Reconnect de WebSocket aciona reconciliação', () async {
      final initialCalls = mockService.refreshCallCount;

      // 1ª conexão estabelecida
      manager.handleSubscriptionStatus(RealtimeSubscribeStatus.subscribed, null);
      // Reconexão (queda e retorno)
      manager.handleSubscriptionStatus(RealtimeSubscribeStatus.subscribed, null);

      await Future.delayed(const Duration(milliseconds: 250));
      expect(mockService.refreshCallCount, greaterThan(initialCalls));
    });

    test('3. Múltiplos reconnects próximos coalescem em uma única reconciliação', () async {
      // Estabelece conexão inicial
      manager.handleSubscriptionStatus(RealtimeSubscribeStatus.subscribed, null);
      final initialCalls = mockService.refreshCallCount;

      // 3 reconexões em sequência rápida
      manager.handleSubscriptionStatus(RealtimeSubscribeStatus.subscribed, null);
      manager.handleSubscriptionStatus(RealtimeSubscribeStatus.subscribed, null);
      manager.handleSubscriptionStatus(RealtimeSubscribeStatus.subscribed, null);

      await Future.delayed(const Duration(milliseconds: 350));
      // Coalescido: apenas 1 chamada a mais
      expect(mockService.refreshCallCount, equals(initialCalls + 1));
    });

    test('4. AppLifecycleState.resumed aciona reconciliação', () async {
      final initialCalls = mockService.refreshCallCount;

      manager.handleAppLifecycleState(AppLifecycleState.resumed);

      await Future.delayed(const Duration(milliseconds: 350));
      expect(mockService.refreshCallCount, equals(initialCalls + 1));
    });

    test('5. Vários resumed próximos coalescem em apenas uma reconciliação', () async {
      final initialCalls = mockService.refreshCallCount;

      manager.handleAppLifecycleState(AppLifecycleState.resumed);
      manager.handleAppLifecycleState(AppLifecycleState.resumed);
      manager.handleAppLifecycleState(AppLifecycleState.resumed);

      await Future.delayed(const Duration(milliseconds: 350));
      expect(mockService.refreshCallCount, equals(initialCalls + 1));
    });

    test('6. Watchdog timer + resumed simultâneos coalescem em uma reconciliação', () async {
      // Simula lastSync antigo (>45s) para o timer ser elegível
      mockService.nextSnapshot = ChatUnreadSnapshot(
        totalUnread: 5,
        unreadByCommunity: {'comm-1': 5},
        unreadByGroup: {'g1': 5},
        groupToCommunity: {'g1': 'comm-1'},
        timestamp: DateTime.now().subtract(const Duration(seconds: 60)),
      );
      await manager.refreshAll(force: true);

      final initialCalls = mockService.refreshCallCount;

      manager.scheduleReconciliation('watchdog_timer', delay: const Duration(milliseconds: 100));
      manager.scheduleReconciliation('app_resumed', delay: const Duration(milliseconds: 100));

      await Future.delayed(const Duration(milliseconds: 250));
      expect(mockService.refreshCallCount, equals(initialCalls + 1));
    });

    test('7. Read receipt + reconnect simultâneos coalescem em uma reconciliação', () async {
      // Estabelece conexão
      manager.handleSubscriptionStatus(RealtimeSubscribeStatus.subscribed, null);
      final initialCalls = mockService.refreshCallCount;

      manager.handleMensagensLidasInsert({'mensagem_id': 'm1', 'usuario_id': 'user-1'});
      manager.handleSubscriptionStatus(RealtimeSubscribeStatus.subscribed, null);

      await Future.delayed(const Duration(milliseconds: 350));
      expect(mockService.refreshCallCount, equals(initialCalls + 1));
    });

    test('8. Single-Flight: Reconciliação durante refresh marca reconciliationPending sem abrir query paralela', () async {
      final completer = Completer<ChatUnreadSnapshot>();
      mockService.slowRefreshCompleter = completer;

      final initialCalls = mockService.refreshCallCount;

      // Inicia refresh 1
      final future1 = manager.refreshAll();
      expect(manager.hasInFlightRefresh, isTrue);

      // Nova solicitação de reconciliação chega enquanto o refresh 1 está em voo
      manager.scheduleReconciliation('solicitacao_concorrente', delay: Duration.zero);

      // Não abre query paralela, marca reconciliationPending = true
      expect(mockService.refreshCallCount, equals(initialCalls + 1));
      expect(manager.isReconciliationPending, isTrue);

      // Completa a operação do refresh 1
      mockService.slowRefreshCompleter = null;
      completer.complete(mockService.nextSnapshot!);
      await future1;

      // Aguarda execução da reconciliação pendente acumulada após o término do voo
      await Future.delayed(const Duration(milliseconds: 200));

      expect(mockService.refreshCallCount, equals(initialCalls + 2));
      expect(manager.isReconciliationPending, isFalse);
    });

    test('9. Mutação durante refresh in-flight agenda reconciliação posterior', () async {
      final completer = Completer<ChatUnreadSnapshot>();
      mockService.slowRefreshCompleter = completer;

      // Inicia refresh lento
      final refreshFuture = manager.refreshAll();

      // Chega mensagem via Realtime durante o voo
      manager.handleMensagemInsert({
        'id': 'msg-new',
        'grupo_id': 'g1',
        'usuario_id': 'user-2',
      });
      expect(manager.getUnreadForGroup('g1'), equals(4)); // 3 + 1

      // Libera refresh
      mockService.slowRefreshCompleter = null;
      completer.complete(ChatUnreadSnapshot(
        totalUnread: 3,
        unreadByCommunity: {'comm-1': 3},
        unreadByGroup: {'g1': 3},
        groupToCommunity: {'g1': 'comm-1'},
        timestamp: DateTime.now(),
      ));

      await refreshFuture;

      // A contagem Realtime não foi sobrescrita pelo snapshot antigo!
      expect(manager.getUnreadForGroup('g1'), equals(4));
    });

    test('10. Logout durante refresh in-flight descarta a resposta da sessão antiga', () async {
      final completer = Completer<ChatUnreadSnapshot>();
      mockService.slowRefreshCompleter = completer;

      // Inicia refresh para user-1
      final refreshFuture = manager.refreshAll();

      // Usuário faz logout e entra user-2
      manager.resetUser('user-2');
      expect(manager.totalUnread, equals(0));
      expect(manager.currentUserId, equals('user-2'));

      // Resposta lenta de user-1 finalmente chega
      mockService.slowRefreshCompleter = null;
      completer.complete(ChatUnreadSnapshot(
        totalUnread: 99,
        unreadByCommunity: {'comm-old': 99},
        unreadByGroup: {'g-old': 99},
        groupToCommunity: {'g-old': 'comm-old'},
        timestamp: DateTime.now(),
      ));

      await refreshFuture;

      // O estado de user-2 não foi corrompido pelos dados de user-1
      expect(manager.totalUnread, equals(0));
      expect(manager.unreadByGroup, isEmpty);
      expect(manager.currentUserId, equals('user-2'));
    });

    test('11. Logout durante debounce cancela qualquer query futura da sessão anterior', () async {
      final initialCalls = mockService.refreshCallCount;

      // Agenda reconciliação com delay
      manager.scheduleReconciliation('scheduled_event', delay: const Duration(milliseconds: 200));

      // Desloga antes do timer disparar
      manager.resetUser(null);

      await Future.delayed(const Duration(milliseconds: 300));
      // Nenhuma consulta foi feita após o logout
      expect(mockService.refreshCallCount, equals(initialCalls));
    });

    test('12. Troca de usuário A -> B zera completamente contadores e snapshot', () {
      expect(manager.totalUnread, equals(5));

      manager.resetUser('user-B');

      expect(manager.totalUnread, equals(0));
      expect(manager.unreadByGroup, isEmpty);
      expect(manager.unreadByCommunity, isEmpty);
      expect(manager.currentUserId, equals('user-B'));
      expect(manager.lastSync, isNull);
    });

    test('13. 10 mensagens rápidas no chat ativo geram no máximo 2 passagens coalescidas de leitura', () async {
      manager.setActiveChat('g1');

      final completer = Completer<void>();
      mockService.slowMarkReadCompleter = completer;
      final initialMarkCount = mockService.markReadCallCount;

      // 10 mensagens chegam em rajada no chat ativo
      for (int i = 0; i < 10; i++) {
        manager.handleMensagemInsert({
          'id': 'msg-burst-$i',
          'grupo_id': 'g1',
          'usuario_id': 'user-2',
        });
      }

      // O badge continua 0 (não incrementa no chat ativo)
      expect(manager.getUnreadForGroup('g1'), equals(3)); // Mantém sem somar as 10 novas

      // Libera a primeira operação que estava em voo
      mockService.slowMarkReadCompleter = null;
      completer.complete();

      await Future.delayed(const Duration(milliseconds: 100));

      // As 10 mensagens geraram no máximo 2 execuções (1ª em voo + 2ª de varredura das pendentes), NÃO 10!
      expect(mockService.markReadCallCount - initialMarkCount, inInclusiveRange(1, 2));
    });

    test('14. Mensagem chega durante leitura in-flight e aciona segunda passagem', () async {
      manager.setActiveChat('g1');

      final completer = Completer<void>();
      mockService.slowMarkReadCompleter = completer;
      final initialMarkCount = mockService.markReadCallCount;

      // Mensagem 1 inicia a chamada em voo
      manager.handleMensagemInsert({'id': 'm-1', 'grupo_id': 'g1', 'usuario_id': 'user-2'});
      expect(manager.activeChatInFlight, contains('g1'));

      // Mensagem 2 chega enquanto a chamada 1 está rodando
      manager.handleMensagemInsert({'id': 'm-2', 'grupo_id': 'g1', 'usuario_id': 'user-2'});
      expect(manager.activeChatPending, contains('g1'));

      // Conclui a 1ª chamada
      mockService.slowMarkReadCompleter = null;
      completer.complete();

      await Future.delayed(const Duration(milliseconds: 80));

      // Segunda passagem foi executada e as pendências foram esvaziadas
      expect(mockService.markReadCallCount, equals(initialMarkCount + 2));
      expect(manager.activeChatPending, isEmpty);
    });

    test('15. Falha de persistência no chat ativo agenda reconciliação de recuperação', () async {
      manager.setActiveChat('g1');
      mockService.shouldFailMarkRead = true;
      final initialRefreshCalls = mockService.refreshCallCount;

      manager.handleMensagemInsert({'id': 'm-fail', 'grupo_id': 'g1', 'usuario_id': 'user-2'});

      // Aguarda reconciliação agendada pós-falha
      await Future.delayed(const Duration(milliseconds: 1200));
      expect(mockService.refreshCallCount, greaterThan(initialRefreshCalls));
    });

    test('16. AppLifecycleState.paused/hidden não zera os badges', () {
      expect(manager.totalUnread, equals(5));

      manager.handleAppLifecycleState(AppLifecycleState.paused);
      expect(manager.totalUnread, equals(5));

      manager.handleAppLifecycleState(AppLifecycleState.hidden);
      expect(manager.totalUnread, equals(5));

      manager.handleAppLifecycleState(AppLifecycleState.inactive);
      expect(manager.totalUnread, equals(5));
    });

    test('17. AppLifecycleState.resumed mantém o snapshot enquanto busca atualização', () async {
      final completer = Completer<ChatUnreadSnapshot>();
      mockService.slowRefreshCompleter = completer;

      // App volta ao foreground
      manager.handleAppLifecycleState(AppLifecycleState.resumed);

      // Enquanto a sincronização está em andamento, o snapshot atual permanece visível
      expect(manager.totalUnread, equals(5));
      expect(manager.getUnreadForGroup('g1'), equals(3));

      // Atualiza o nextSnapshot e libera o completer
      final newSnapshot = ChatUnreadSnapshot(
        totalUnread: 2,
        unreadByCommunity: {'comm-1': 2},
        unreadByGroup: {'g1': 2},
        groupToCommunity: {'g1': 'comm-1'},
        timestamp: DateTime.now(),
      );
      mockService.nextSnapshot = newSnapshot;
      mockService.slowRefreshCompleter = null;
      completer.complete(newSnapshot);

      await Future.delayed(const Duration(milliseconds: 350));
      expect(manager.totalUnread, equals(2));
    });

    test('18. Ciclos repetidos de login/logout/foreground não duplicam canais Realtime', () {
      int createdChannelsCount = 0;
      final channelManager = UnreadChatManager.test(
        chatService: mockService,
        channelFactory: (name) {
          createdChannelsCount++;
          return FakeChannelForTest();
        },
      );

      channelManager.startRealtime();
      expect(createdChannelsCount, equals(1));
      expect(channelManager.activeChannelsCount, equals(1));

      // Chamadas repetidas e resumed não criam novos canais (idempotência)
      channelManager.startRealtime();
      channelManager.handleAppLifecycleState(AppLifecycleState.resumed);
      channelManager.handleAppLifecycleState(AppLifecycleState.resumed);
      expect(createdChannelsCount, equals(1));
      expect(channelManager.activeChannelsCount, equals(1));

      // Logout encerra o canal existente
      channelManager.resetUser(null);
      expect(channelManager.activeChannelsCount, equals(0));

      // Novo login cria um novo canal único
      channelManager.resetUser('user-new');
      channelManager.startRealtime();
      expect(createdChannelsCount, equals(2));
      expect(channelManager.activeChannelsCount, equals(1));
    });

    test('19. Invariantes matemáticas são preservadas em todas as comunidades e grupos', () {
      void verifyInvariants() {
        final totalGroups = manager.unreadByGroup.values.fold<int>(0, (a, b) => a + b);
        expect(manager.totalUnread, equals(totalGroups));

        final totalComm = manager.unreadByCommunity.values.fold<int>(0, (a, b) => a + b);
        expect(manager.totalUnread, equals(totalComm));
      }

      verifyInvariants();

      // Chega mensagem no grupo 1
      manager.handleMensagemInsert({'id': 'inv-1', 'grupo_id': 'g1', 'usuario_id': 'user-2'});
      verifyInvariants();

      // Chega mensagem no grupo 3 (outra comunidade)
      manager.handleMensagemInsert({'id': 'inv-2', 'grupo_id': 'g3', 'usuario_id': 'user-2'});
      verifyInvariants();

      // Marca grupo 1 como lido localmente
      manager.markGroupAsReadLocal('g1');
      verifyInvariants();
    });

    test('20. Contadores nunca ficam negativos mesmo com leituras duplicadas ou concorrentes', () {
      manager.markGroupAsReadLocal('g1');
      manager.markGroupAsReadLocal('g1');
      manager.markGroupAsReadLocal('g2');
      manager.markGroupAsReadLocal('g2');
      manager.markGroupAsReadLocal('g3');

      expect(manager.totalUnread, isNot(isNegative));
      expect(manager.getUnreadForGroup('g1'), isNot(isNegative));
      expect(manager.getUnreadForGroup('g2'), isNot(isNegative));
      expect(manager.getUnreadForCommunity('comm-1'), isNot(isNegative));
      expect(manager.totalUnread, equals(0));
    });

    test('21. Cenário de Carga e Telemetria: 100 INSERTs + 20 Read Receipts + 3 Reconnects + 3 Resumed + Timer', () async {
      final initialCalls = mockService.refreshCallCount;

      // 1. 100 mensagens normais chegam em grupos não ativos
      for (int i = 0; i < 100; i++) {
        manager.handleMensagemInsert({
          'id': 'bulk-msg-$i',
          'grupo_id': i % 2 == 0 ? 'g1' : 'g2',
          'usuario_id': 'user-other',
        });
      }

      // NENHUMA query de banco foi gerada pelos 100 INSERTs!
      expect(mockService.refreshCallCount, equals(initialCalls),
          reason: '100 INSERTs normais não devem gerar queries adicionais.');

      // 2. 20 Read receipts chegam em rajada
      for (int i = 0; i < 20; i++) {
        manager.handleMensagensLidasInsert({
          'mensagem_id': 'read-$i',
          'usuario_id': 'user-1',
        });
      }

      // 3. 3 Reconnects de WebSocket
      manager.handleSubscriptionStatus(RealtimeSubscribeStatus.subscribed, null);
      manager.handleSubscriptionStatus(RealtimeSubscribeStatus.subscribed, null);
      manager.handleSubscriptionStatus(RealtimeSubscribeStatus.subscribed, null);

      // 4. 3 Callbacks de Resumed
      manager.handleAppLifecycleState(AppLifecycleState.resumed);
      manager.handleAppLifecycleState(AppLifecycleState.resumed);
      manager.handleAppLifecycleState(AppLifecycleState.resumed);

      // 5. Watchdog timer dispara
      manager.scheduleReconciliation('watchdog_timer', delay: Duration.zero);

      // Aguarda coalescência do debounce central
      await Future.delayed(const Duration(milliseconds: 400));

      // Todos os eventos coalesceram em exatamente UMA reconciliação centralizada!
      expect(mockService.refreshCallCount, equals(initialCalls + 1),
          reason: 'Todos os eventos coalescentes devem gerar apenas 1 reconciliação central.');
    });
  });
}
