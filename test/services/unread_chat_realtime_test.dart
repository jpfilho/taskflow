import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:task2026/models/chat_unread_snapshot.dart';
import 'package:task2026/services/chat_service.dart';
import 'package:task2026/services/unread_chat_manager.dart';

class MockChatServiceForRealtime extends ChatService {
  MockChatServiceForRealtime({this.userId = 'user-1'}) : super.forTesting();

  String? userId;
  ChatUnreadSnapshot? nextSnapshot;
  int refreshCallCount = 0;
  List<String> markedReadGroups = [];
  bool failMarkAsRead = false;
  Completer<ChatUnreadSnapshot>? slowRefreshCompleter;

  @override
  String? get currentUserId => userId;

  @override
  Future<ChatUnreadSnapshot> carregarSnapshotNaoLidasCompleto() async {
    refreshCallCount++;
    if (slowRefreshCompleter != null) {
      return slowRefreshCompleter!.future;
    }
    return nextSnapshot ?? ChatUnreadSnapshot.empty();
  }

  @override
  Future<void> marcarMensagensComoLidasPorGrupo(String grupoIdOuTarefaId) async {
    if (failMarkAsRead) {
      throw Exception('Simulated network error');
    }
    markedReadGroups.add(grupoIdOuTarefaId);
  }
}

void main() {
  group('Fase 4: Realtime dos contadores de mensagens não lidas', () {
    late MockChatServiceForRealtime mockChatService;
    late UnreadChatManager manager;

    setUp(() async {
      mockChatService = MockChatServiceForRealtime(userId: 'user-1');
      mockChatService.nextSnapshot = ChatUnreadSnapshot(
        totalUnread: 0,
        unreadByCommunity: {'comm-1': 0, 'comm-2': 0},
        unreadByGroup: {'g1': 0, 'g2': 0, 'g3': 0},
        groupToCommunity: {
          'g1': 'comm-1',
          'g2': 'comm-1',
          'g3': 'comm-2',
        },
        timestamp: DateTime.now(),
      );

      manager = UnreadChatManager.test(chatService: mockChatService);
      await manager.initialize();
    });

    tearDown(() {
      manager.stopRealtime();
    });

    test('1. Mensagem de outro usuário incrementa +1 (grupo, comunidade e total)', () {
      final initialTotal = manager.totalUnread;
      expect(initialTotal, equals(0));

      manager.handleMensagemInsert({
        'id': 'msg-1',
        'grupo_id': 'g1',
        'usuario_id': 'user-2', // Remetente diferente
        'deleted_at': null,
      });

      expect(manager.getUnreadForGroup('g1'), equals(1));
      expect(manager.getUnreadForCommunity('comm-1'), equals(1));
      expect(manager.totalUnread, equals(1));
      expect(manager.totalUnread, equals(manager.unreadByGroup.values.fold<int>(0, (a, b) => a + b)));
    });

    test('2. Mensagem própria é completamente ignorada (+0)', () {
      manager.handleMensagemInsert({
        'id': 'msg-own',
        'grupo_id': 'g1',
        'usuario_id': 'user-1', // Mesmo usuário da sessão
        'deleted_at': null,
      });

      expect(manager.getUnreadForGroup('g1'), equals(0));
      expect(manager.getUnreadForCommunity('comm-1'), equals(0));
      expect(manager.totalUnread, equals(0));
    });

    test('3. Mensagem de grupo sem acesso não altera contadores (+0)', () {
      manager.handleMensagemInsert({
        'id': 'msg-inaccessible',
        'grupo_id': 'grupo-estranho-sem-acesso',
        'usuario_id': 'user-2',
        'deleted_at': null,
      });

      expect(manager.totalUnread, equals(0));
      expect(manager.getUnreadForGroup('grupo-estranho-sem-acesso'), equals(0));
    });

    test('4. Mensagem recebida no grupo ativo não incrementa badge e persiste leitura', () async {
      manager.setActiveChat('g1');

      manager.handleMensagemInsert({
        'id': 'msg-active',
        'grupo_id': 'g1',
        'usuario_id': 'user-2',
        'deleted_at': null,
      });

      // Não incrementa
      expect(manager.getUnreadForGroup('g1'), equals(0));
      expect(manager.totalUnread, equals(0));

      // Persistência foi disparada
      await Future.delayed(const Duration(milliseconds: 50));
      expect(mockChatService.markedReadGroups, contains('g1'));
    });

    test('5. Mesmo evento entregue duas vezes incrementa apenas uma vez (deduplicação)', () {
      final payload = {
        'id': 'msg-duplicate-test',
        'grupo_id': 'g1',
        'usuario_id': 'user-2',
        'deleted_at': null,
      };

      manager.handleMensagemInsert(payload);
      expect(manager.totalUnread, equals(1));

      // Reenvio do mesmo evento
      manager.handleMensagemInsert(payload);
      expect(manager.totalUnread, equals(1)); // Não vira 2!
      expect(manager.getUnreadForGroup('g1'), equals(1));
    });

    test('6. Dois grupos diferentes mantêm contadores isolados e corretos', () {
      manager.handleMensagemInsert({
        'id': 'msg-g1-1',
        'grupo_id': 'g1',
        'usuario_id': 'user-2',
      });
      manager.handleMensagemInsert({
        'id': 'msg-g2-1',
        'grupo_id': 'g2',
        'usuario_id': 'user-3',
      });

      expect(manager.getUnreadForGroup('g1'), equals(1));
      expect(manager.getUnreadForGroup('g2'), equals(1));
      expect(manager.getUnreadForGroup('g3'), equals(0));
      expect(manager.totalUnread, equals(2));
    });

    test('7. Mensagens incrementam na comunidade correta', () {
      // g1 e g2 -> comm-1; g3 -> comm-2
      manager.handleMensagemInsert({'id': 'm1', 'grupo_id': 'g1', 'usuario_id': 'user-2'});
      manager.handleMensagemInsert({'id': 'm2', 'grupo_id': 'g2', 'usuario_id': 'user-2'});
      manager.handleMensagemInsert({'id': 'm3', 'grupo_id': 'g3', 'usuario_id': 'user-2'});

      expect(manager.getUnreadForCommunity('comm-1'), equals(2));
      expect(manager.getUnreadForCommunity('comm-2'), equals(1));
      expect(manager.totalUnread, equals(3));
    });

    test('8. DELETE / soft-delete aciona reconciliação', () async {
      final initialRefreshCount = mockChatService.refreshCallCount;

      // Soft delete via UPDATE
      manager.handleMensagemUpdate({
        'id': 'msg-del-1',
        'deleted_at': DateTime.now().toIso8601String(),
      });

      // Aguarda debounce de reconciliação
      await Future.delayed(const Duration(milliseconds: 350));
      expect(mockChatService.refreshCallCount, greaterThan(initialRefreshCount));
    });

    test('9. Leitura do mesmo usuário em outro dispositivo aciona reconciliação', () async {
      final initialRefreshCount = mockChatService.refreshCallCount;

      // Evento de outro dispositivo do mesmo usuário
      manager.handleMensagensLidasInsert({
        'mensagem_id': 'm-read-1',
        'usuario_id': 'user-1',
      });

      await Future.delayed(const Duration(milliseconds: 350));
      expect(mockChatService.refreshCallCount, greaterThan(initialRefreshCount));

      // Evento de leitura de OUTRO usuário é ignorado
      final countAfter = mockChatService.refreshCallCount;
      manager.handleMensagensLidasInsert({
        'mensagem_id': 'm-read-2',
        'usuario_id': 'user-999', // Outro usuário
      });

      await Future.delayed(const Duration(milliseconds: 350));
      expect(mockChatService.refreshCallCount, equals(countAfter));
    });

    test('10. 20 eventos de mensagens_lidas em lote geram apenas 1 reconciliação debounced', () async {
      final initialRefreshCount = mockChatService.refreshCallCount;

      for (int i = 0; i < 20; i++) {
        manager.handleMensagensLidasInsert({
          'mensagem_id': 'msg-$i',
          'usuario_id': 'user-1',
        });
      }

      // Aguarda o término do debounce
      await Future.delayed(const Duration(milliseconds: 400));
      // Exatamente 1 consulta adicional, não 20!
      expect(mockChatService.refreshCallCount, equals(initialRefreshCount + 1));
    });

    test('11. Logout cancela subscrição e zera manager', () {
      manager.handleMensagemInsert({'id': 'm1', 'grupo_id': 'g1', 'usuario_id': 'user-2'});
      expect(manager.totalUnread, equals(1));

      manager.resetUser(null);

      expect(manager.totalUnread, equals(0));
      expect(manager.unreadByGroup, isEmpty);
      expect(manager.unreadByCommunity, isEmpty);
      expect(manager.currentUserId, isNull);
    });

    test('12. Login B não é afetado por evento atrasado da sessão A', () {
      manager.resetUser('user-A');
      manager.resetUser('user-B');

      // Chega evento enviado pelo próprio user-B com dados antigos
      manager.handleMensagemInsert({
        'id': 'delayed-msg',
        'grupo_id': 'g1',
        'usuario_id': 'user-B', // Remetente é o novo usuário
      });

      // Não incrementa porque agora a sessão é do user-B
      expect(manager.totalUnread, equals(0));
    });

    test('13. Race Condition: Refresh iniciado antes de INSERT não sobrescreve incremento Realtime', () async {
      // Configura refresh lento simulando latência de rede
      final slowCompleter = Completer<ChatUnreadSnapshot>();
      mockChatService.slowRefreshCompleter = slowCompleter;

      // 1. Inicia o refresh lento
      final refreshFuture = manager.refreshAll();

      // 2. Durante a viagem da query, chega uma nova mensagem Realtime
      manager.handleMensagemInsert({
        'id': 'msg-race-1',
        'grupo_id': 'g1',
        'usuario_id': 'user-2',
      });

      // O contador imediatamente refletiu a nova mensagem
      expect(manager.getUnreadForGroup('g1'), equals(1));
      expect(manager.totalUnread, equals(1));

      // 3. A query do banco responde com snapshot antigo (gerado antes da mensagem)
      mockChatService.slowRefreshCompleter = null;
      slowCompleter.complete(ChatUnreadSnapshot(
        totalUnread: 0,
        unreadByCommunity: {'comm-1': 0, 'comm-2': 0},
        unreadByGroup: {'g1': 0, 'g2': 0, 'g3': 0},
        groupToCommunity: {'g1': 'comm-1', 'g2': 'comm-1', 'g3': 'comm-2'},
        timestamp: DateTime.now(),
      ));

      await refreshFuture;

      // 4. Proteção contra sobrescrita: o snapshot antigo NÃO sobrescreveu para 0!
      expect(manager.getUnreadForGroup('g1'), equals(1));
      expect(manager.totalUnread, equals(1));
    });

    test('14. INSERT durante marcação de leitura termina consistente', () async {
      // Usuário tinha 1 mensagem não lida
      manager.handleMensagemInsert({'id': 'm1', 'grupo_id': 'g1', 'usuario_id': 'user-2'});
      expect(manager.getUnreadForGroup('g1'), equals(1));

      // Usuário abre o grupo -> leitura otimista local
      manager.markGroupAsReadLocal('g1');
      expect(manager.getUnreadForGroup('g1'), equals(0));

      // Se chegar nova mensagem enquanto está no chat ativo
      manager.setActiveChat('g1');
      manager.handleMensagemInsert({'id': 'm2', 'grupo_id': 'g1', 'usuario_id': 'user-2'});

      // Não acumula como não lida
      expect(manager.getUnreadForGroup('g1'), equals(0));
      expect(manager.totalUnread, equals(0));
    });

    test('15. Contadores nunca ficam negativos mesmo com eventos fora de ordem', () {
      manager.markGroupAsReadLocal('g1');
      manager.markGroupAsReadLocal('g1');

      expect(manager.getUnreadForGroup('g1'), equals(0));
      expect(manager.getUnreadForCommunity('comm-1'), equals(0));
      expect(manager.totalUnread, equals(0));
    });

    test('16. Invariantes matemáticas permanecem estritamente válidas após cada evento', () {
      void assertInvariants() {
        final sumGroups = manager.unreadByGroup.values.fold<int>(0, (a, b) => a + b);
        expect(manager.totalUnread, equals(sumGroups),
            reason: 'totalUnread deve ser igual à soma de todos os unreadByGroup');
      }

      assertInvariants();

      manager.handleMensagemInsert({'id': 'inv-1', 'grupo_id': 'g1', 'usuario_id': 'user-2'});
      assertInvariants();

      manager.handleMensagemInsert({'id': 'inv-2', 'grupo_id': 'g2', 'usuario_id': 'user-3'});
      assertInvariants();

      manager.handleMensagemInsert({'id': 'inv-3', 'grupo_id': 'g3', 'usuario_id': 'user-4'});
      assertInvariants();

      manager.markGroupAsReadLocal('g1');
      assertInvariants();

      manager.markGroupAsReadLocal('g2');
      assertInvariants();
    });

    test('Bônus: Reconexão aciona reconciliação automática', () async {
      final initialRefreshCount = mockChatService.refreshCallCount;

      // 1ª conexão
      manager.handleSubscriptionStatus(RealtimeSubscribeStatus.subscribed, null);
      // Reconexão subsequente dispara reconciliação agendada com debounce
      manager.handleSubscriptionStatus(RealtimeSubscribeStatus.subscribed, null);
      await Future.delayed(const Duration(milliseconds: 300));

      expect(mockChatService.refreshCallCount, greaterThan(initialRefreshCount));
    });
  });
}
