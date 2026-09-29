import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/models/chat_unread_snapshot.dart';
import 'package:task2026/services/chat_service.dart';
import 'package:task2026/services/unread_chat_manager.dart';

class MockChatServiceForUI extends ChatService {
  MockChatServiceForUI({this.userId = 'user-1'}) : super.forTesting();

  String? userId;
  ChatUnreadSnapshot? currentDbSnapshot;
  bool shouldFailPersistence = false;
  int markAsReadCalls = 0;
  int refreshDbCalls = 0;

  @override
  String? get currentUserId => userId;

  @override
  Future<ChatUnreadSnapshot> carregarSnapshotNaoLidasCompleto() async {
    refreshDbCalls++;
    return currentDbSnapshot ?? ChatUnreadSnapshot.empty();
  }

  @override
  Future<void> marcarMensagensComoLidasPorGrupo(String grupoIdOuTarefaId) async {
    markAsReadCalls++;
    if (shouldFailPersistence) {
      throw Exception('Simulated database error on markAsRead');
    }
    // Em caso de sucesso, no Supabase real o grupo é zerado
    if (currentDbSnapshot != null) {
      final newGroups = Map<String, int>.from(currentDbSnapshot!.unreadByGroup);
      final count = newGroups[grupoIdOuTarefaId] ?? 0;
      newGroups[grupoIdOuTarefaId] = 0;

      final commId = currentDbSnapshot!.groupToCommunity[grupoIdOuTarefaId];
      final newComms = Map<String, int>.from(currentDbSnapshot!.unreadByCommunity);
      if (commId != null) {
        newComms[commId] = (newComms[commId] ?? 0) - count;
        if (newComms[commId]! < 0) newComms[commId] = 0;
      }

      final newTotal = currentDbSnapshot!.totalUnread - count;
      currentDbSnapshot = ChatUnreadSnapshot(
        totalUnread: newTotal < 0 ? 0 : newTotal,
        unreadByCommunity: newComms,
        unreadByGroup: newGroups,
        groupToCommunity: currentDbSnapshot!.groupToCommunity,
        timestamp: DateTime.now(),
      );
    }
  }
}

void main() {
  group('Fase 3: Integração da UI com o UnreadChatManager', () {
    late MockChatServiceForUI mockService;
    late UnreadChatManager manager;

    setUp(() {
      mockService = MockChatServiceForUI(userId: 'user-1');
      manager = UnreadChatManager.test(chatService: mockService);
    });

    test('Teste 1: Hierarquia consistente entre Header, Comunidades e Grupos', () async {
      // Grupo A (3) e Grupo B (2) na Comunidade 1 (total 5)
      // Grupo C (4) na Comunidade 2 (total 4)
      // Header deve ser 9
      mockService.currentDbSnapshot = ChatUnreadSnapshot(
        totalUnread: 9,
        unreadByCommunity: {'comm-1': 5, 'comm-2': 4},
        unreadByGroup: {'grupo-a': 3, 'grupo-b': 2, 'grupo-c': 4},
        groupToCommunity: {
          'grupo-a': 'comm-1',
          'grupo-b': 'comm-1',
          'grupo-c': 'comm-2',
        },
        timestamp: DateTime.now(),
      );

      await manager.refreshAll();

      // Header
      expect(manager.totalUnread, equals(9));
      // Comunidades
      expect(manager.getUnreadForCommunity('comm-1'), equals(5));
      expect(manager.getUnreadForCommunity('comm-2'), equals(4));
      // Grupos
      expect(manager.getUnreadForGroup('grupo-a'), equals(3));
      expect(manager.getUnreadForGroup('grupo-b'), equals(2));
      expect(manager.getUnreadForGroup('grupo-c'), equals(4));
    });

    test('Teste 2: Abertura do Grupo A e persistência bem-sucedida', () async {
      mockService.currentDbSnapshot = ChatUnreadSnapshot(
        totalUnread: 9,
        unreadByCommunity: {'comm-1': 5, 'comm-2': 4},
        unreadByGroup: {'grupo-a': 3, 'grupo-b': 2, 'grupo-c': 4},
        groupToCommunity: {
          'grupo-a': 'comm-1',
          'grupo-b': 'comm-1',
          'grupo-c': 'comm-2',
        },
        timestamp: DateTime.now(),
      );

      await manager.refreshAll();

      // Usuário abre o Grupo A
      manager.setActiveChat('grupo-a');
      expect(manager.activeChatGrupoId, equals('grupo-a'));

      // Persistência com sucesso simulada pelo fluxo do ChatScreen
      await mockService.marcarMensagensComoLidasPorGrupo('grupo-a');
      manager.markGroupAsReadLocal('grupo-a');

      // Verificação das invariantes
      expect(manager.getUnreadForGroup('grupo-a'), equals(0));
      expect(manager.getUnreadForCommunity('comm-1'), equals(2)); // reduziu exatamente 3
      expect(manager.totalUnread, equals(6)); // 9 - 3 = 6
      expect(manager.getUnreadForGroup('grupo-b'), equals(2)); // intocado
      expect(manager.getUnreadForGroup('grupo-c'), equals(4)); // intocado
    });

    test('Teste 3: Abrir grupo já zerado não gera contador negativo', () async {
      mockService.currentDbSnapshot = ChatUnreadSnapshot(
        totalUnread: 5,
        unreadByCommunity: {'comm-1': 5},
        unreadByGroup: {'grupo-a': 0, 'grupo-b': 5},
        groupToCommunity: {'grupo-a': 'comm-1', 'grupo-b': 'comm-1'},
        timestamp: DateTime.now(),
      );

      await manager.refreshAll();

      // Grupo A já está zerado
      manager.setActiveChat('grupo-a');
      await mockService.marcarMensagensComoLidasPorGrupo('grupo-a');
      manager.markGroupAsReadLocal('grupo-a');

      expect(manager.getUnreadForGroup('grupo-a'), equals(0));
      expect(manager.getUnreadForCommunity('comm-1'), equals(5));
      expect(manager.totalUnread, equals(5));
    });

    test('Teste 4: Falha simulada na persistência de leitura com reconciliação', () async {
      mockService.currentDbSnapshot = ChatUnreadSnapshot(
        totalUnread: 7,
        unreadByCommunity: {'comm-1': 7},
        unreadByGroup: {'grupo-a': 4, 'grupo-b': 3},
        groupToCommunity: {'grupo-a': 'comm-1', 'grupo-b': 'comm-1'},
        timestamp: DateTime.now(),
      );

      await manager.refreshAll();
      expect(manager.totalUnread, equals(7));

      // Simula erro no banco ao marcar como lida
      mockService.shouldFailPersistence = true;

      // Fluxo resiliente do ChatScreen:
      try {
        await mockService.marcarMensagensComoLidasPorGrupo('grupo-a');
        manager.markGroupAsReadLocal('grupo-a');
      } catch (e) {
        // Em caso de falha, dispara reconciliação com o backend
        await manager.refreshAll(force: true);
      }

      // O contador NÃO fica permanentemente zerado se a persistência falhou!
      expect(manager.getUnreadForGroup('grupo-a'), equals(4));
      expect(manager.getUnreadForCommunity('comm-1'), equals(7));
      expect(manager.totalUnread, equals(7));
    });

    test('Teste 5: Refresh enquanto a UI está aberta não faz badges piscarem para zero', () async {
      mockService.currentDbSnapshot = ChatUnreadSnapshot(
        totalUnread: 8,
        unreadByCommunity: {'comm-1': 8},
        unreadByGroup: {'grupo-a': 8},
        groupToCommunity: {'grupo-a': 'comm-1'},
        timestamp: DateTime.now(),
      );

      await manager.refreshAll();

      var intermediateValues = <int>[];
      manager.addListener(() {
        intermediateValues.add(manager.totalUnread);
      });

      // Dispara um novo refresh
      await manager.refreshAll();

      // Em nenhum momento intermediário o total foi para zero durante a sincronização
      expect(intermediateValues.any((val) => val == 0), isFalse);
      expect(manager.totalUnread, equals(8));
    });

    test('Teste 6: Logout limpa imediatamente Header, Comunidades e Grupos', () async {
      mockService.currentDbSnapshot = ChatUnreadSnapshot(
        totalUnread: 5,
        unreadByCommunity: {'comm-1': 5},
        unreadByGroup: {'grupo-a': 5},
        groupToCommunity: {'grupo-a': 'comm-1'},
        timestamp: DateTime.now(),
      );

      await manager.refreshAll();
      expect(manager.totalUnread, equals(5));

      // Usuário faz logout
      manager.resetUser(null);

      expect(manager.totalUnread, equals(0));
      expect(manager.unreadByCommunity, isEmpty);
      expect(manager.unreadByGroup, isEmpty);
      expect(manager.currentUserId, isNull);
    });

    test('Teste 7: Login com outro usuário não exibe badges do usuário anterior', () async {
      // Usuário A
      mockService.currentDbSnapshot = ChatUnreadSnapshot(
        totalUnread: 15,
        unreadByCommunity: {'comm-1': 15},
        unreadByGroup: {'grupo-a': 15},
        groupToCommunity: {'grupo-a': 'comm-1'},
        timestamp: DateTime.now(),
      );

      await manager.refreshAll();
      expect(manager.totalUnread, equals(15));

      // Troca para Usuário B (que tem apenas 1 mensagem não lida)
      mockService.userId = 'user-2';
      mockService.currentDbSnapshot = ChatUnreadSnapshot(
        totalUnread: 1,
        unreadByCommunity: {'comm-2': 1},
        unreadByGroup: {'grupo-x': 1},
        groupToCommunity: {'grupo-x': 'comm-2'},
        timestamp: DateTime.now(),
      );

      await manager.refreshAll();

      expect(manager.currentUserId, equals('user-2'));
      expect(manager.totalUnread, equals(1));
      expect(manager.unreadByGroup.containsKey('grupo-a'), isFalse);
      expect(manager.getUnreadForGroup('grupo-x'), equals(1));
    });

    test('Teste 8: Múltiplos rebuilds reutilizam a mesma instância singleton do manager', () {
      final manager1 = UnreadChatManager();
      final manager2 = UnreadChatManager();

      expect(identical(manager1, manager2), isTrue);
    });

    test('Teste 9: Desktop e Mobile consomem exatamente o mesmo totalUnread', () async {
      mockService.currentDbSnapshot = ChatUnreadSnapshot(
        totalUnread: 11,
        unreadByCommunity: {'comm-1': 11},
        unreadByGroup: {'grupo-1': 11},
        groupToCommunity: {'grupo-1': 'comm-1'},
        timestamp: DateTime.now(),
      );

      await manager.refreshAll();

      // Simulação do getter do Header desktop e Header mobile
      final desktopBadgeValue = manager.totalUnread;
      final mobileBadgeValue = manager.totalUnread;

      expect(desktopBadgeValue, equals(11));
      expect(mobileBadgeValue, equals(11));
      expect(desktopBadgeValue, equals(mobileBadgeValue));
    });
  });
}
