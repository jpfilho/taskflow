import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/models/chat_unread_snapshot.dart';
import 'package:task2026/services/chat_service.dart';
import 'package:task2026/services/unread_chat_manager.dart';

class FakeChatService extends ChatService {
  FakeChatService({this.userId = 'user-1'}) : super.forTesting();

  String? userId;
  ChatUnreadSnapshot? nextSnapshot;
  Exception? errorToThrow;
  Duration? delay;
  int snapshotCallCount = 0;
  int invalidateCallCount = 0;

  @override
  String? get currentUserId => userId;

  @override
  Future<ChatUnreadSnapshot> carregarSnapshotNaoLidasCompleto() async {
    snapshotCallCount++;
    if (delay != null) {
      await Future.delayed(delay!);
    }
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return nextSnapshot ?? ChatUnreadSnapshot.empty();
  }

  @override
  void invalidarCacheNaoLidas() {
    invalidateCallCount++;
    super.invalidarCacheNaoLidas();
  }
}

class ControlledChatService extends ChatService {
  ControlledChatService() : super.forTesting();

  Completer<ChatUnreadSnapshot>? completer1;
  Completer<ChatUnreadSnapshot>? completer2;
  int call = 0;

  @override
  String? get currentUserId => 'user-1';

  @override
  Future<ChatUnreadSnapshot> carregarSnapshotNaoLidasCompleto() async {
    call++;
    if (call == 1) {
      return completer1!.future;
    } else {
      return completer2!.future;
    }
  }
}

void main() {
  group('Fase 2: UnreadChatManager (Single Source of Truth)', () {
    late FakeChatService fakeChatService;
    late UnreadChatManager manager;

    setUp(() {
      fakeChatService = FakeChatService(userId: 'user-1');
      manager = UnreadChatManager.test(chatService: fakeChatService);
    });

    test('1. Inicialização com zero mensagens', () async {
      fakeChatService.nextSnapshot = ChatUnreadSnapshot.empty();

      await manager.initialize();

      expect(manager.isInitialized, isTrue);
      expect(manager.totalUnread, equals(0));
      expect(manager.unreadByCommunity, isEmpty);
      expect(manager.unreadByGroup, isEmpty);
      expect(manager.currentUserId, equals('user-1'));
      expect(manager.isLoading, isFalse);
    });

    test('2. Carregamento de múltiplos grupos', () async {
      fakeChatService.nextSnapshot = ChatUnreadSnapshot(
        totalUnread: 7,
        unreadByCommunity: {'comm-1': 5, 'comm-2': 2},
        unreadByGroup: {'g1': 3, 'g2': 2, 'g3': 2},
        groupToCommunity: {'g1': 'comm-1', 'g2': 'comm-1', 'g3': 'comm-2'},
        timestamp: DateTime.now(),
      );

      await manager.refreshAll();

      expect(manager.unreadByGroup.length, equals(3));
      expect(manager.getUnreadForGroup('g1'), equals(3));
      expect(manager.getUnreadForGroup('g2'), equals(2));
      expect(manager.getUnreadForGroup('g3'), equals(2));
      expect(manager.getUnreadForCommunity('comm-1'), equals(5));
      expect(manager.getUnreadForCommunity('comm-2'), equals(2));
    });

    test('3. Cálculo correto do total', () async {
      fakeChatService.nextSnapshot = ChatUnreadSnapshot(
        totalUnread: 12,
        unreadByCommunity: {'comm-1': 12},
        unreadByGroup: {'g1': 5, 'g2': 7},
        groupToCommunity: {'g1': 'comm-1', 'g2': 'comm-1'},
        timestamp: DateTime.now(),
      );

      await manager.refreshAll();

      expect(manager.totalUnread, equals(12));
    });

    test('4. Consistência: totalUnread == soma dos grupos acessíveis', () async {
      fakeChatService.nextSnapshot = ChatUnreadSnapshot(
        totalUnread: 9,
        unreadByCommunity: {'comm-1': 4, 'comm-2': 5},
        unreadByGroup: {'g1': 4, 'g2': 2, 'g3': 3},
        groupToCommunity: {'g1': 'comm-1', 'g2': 'comm-2', 'g3': 'comm-2'},
        timestamp: DateTime.now(),
      );

      await manager.refreshAll();

      final somaGrupos = manager.unreadByGroup.values.fold<int>(0, (sum, val) => sum + val);
      final somaComunidades = manager.unreadByCommunity.values.fold<int>(0, (sum, val) => sum + val);

      expect(manager.totalUnread, equals(somaGrupos));
      expect(manager.totalUnread, equals(somaComunidades));
    });

    test('5. markGroupAsReadLocal() reduz corretamente grupo, comunidade e total', () async {
      fakeChatService.nextSnapshot = ChatUnreadSnapshot(
        totalUnread: 10,
        unreadByCommunity: {'comm-1': 6, 'comm-2': 4},
        unreadByGroup: {'g1': 4, 'g2': 2, 'g3': 4},
        groupToCommunity: {'g1': 'comm-1', 'g2': 'comm-1', 'g3': 'comm-2'},
        timestamp: DateTime.now(),
      );

      await manager.refreshAll();
      expect(manager.totalUnread, equals(10));
      expect(manager.getUnreadForGroup('g1'), equals(4));
      expect(manager.getUnreadForCommunity('comm-1'), equals(6));

      // Marca o grupo g1 como lido localmente
      manager.markGroupAsReadLocal('g1');

      expect(manager.getUnreadForGroup('g1'), equals(0));
      expect(manager.getUnreadForCommunity('comm-1'), equals(2)); // 6 - 4
      expect(manager.totalUnread, equals(6)); // 10 - 4
      expect(manager.getUnreadForGroup('g2'), equals(2)); // intocado
      expect(manager.getUnreadForGroup('g3'), equals(4)); // intocado
    });

    test('6. Contador nunca fica negativo', () async {
      fakeChatService.nextSnapshot = ChatUnreadSnapshot(
        totalUnread: 2,
        unreadByCommunity: {'comm-1': 2},
        unreadByGroup: {'g1': 2},
        groupToCommunity: {'g1': 'comm-1'},
        timestamp: DateTime.now(),
      );

      await manager.refreshAll();

      // Marca o grupo g1 como lido duas vezes
      manager.markGroupAsReadLocal('g1');
      manager.markGroupAsReadLocal('g1'); // segunda chamada não deve negativar

      expect(manager.getUnreadForGroup('g1'), equals(0));
      expect(manager.getUnreadForCommunity('comm-1'), equals(0));
      expect(manager.totalUnread, equals(0));
    });

    test('7. resetUser() elimina completamente o estado anterior', () async {
      fakeChatService.nextSnapshot = ChatUnreadSnapshot(
        totalUnread: 8,
        unreadByCommunity: {'comm-1': 8},
        unreadByGroup: {'g1': 8},
        groupToCommunity: {'g1': 'comm-1'},
        timestamp: DateTime.now(),
      );

      await manager.refreshAll();
      manager.setActiveChat('g1');

      expect(manager.totalUnread, equals(8));
      expect(manager.activeChatGrupoId, equals('g1'));

      // Logout / reset
      manager.resetUser(null);

      expect(manager.totalUnread, equals(0));
      expect(manager.unreadByCommunity, isEmpty);
      expect(manager.unreadByGroup, isEmpty);
      expect(manager.activeChatGrupoId, isNull);
      expect(manager.currentUserId, isNull);
      expect(manager.lastSync, isNull);
    });

    test('8. Troca de usuário não reaproveita cache', () async {
      fakeChatService.nextSnapshot = ChatUnreadSnapshot(
        totalUnread: 5,
        unreadByCommunity: {'comm-1': 5},
        unreadByGroup: {'g1': 5},
        groupToCommunity: {'g1': 'comm-1'},
        timestamp: DateTime.now(),
      );

      await manager.refreshAll();
      expect(manager.totalUnread, equals(5));

      // Troca para o usuário 2
      fakeChatService.userId = 'user-2';
      fakeChatService.nextSnapshot = ChatUnreadSnapshot(
        totalUnread: 1,
        unreadByCommunity: {'comm-2': 1},
        unreadByGroup: {'g9': 1},
        groupToCommunity: {'g9': 'comm-2'},
        timestamp: DateTime.now(),
      );

      // Ao chamar refreshAll com novo usuário, o estado anterior é limpo
      await manager.refreshAll();

      expect(manager.currentUserId, equals('user-2'));
      expect(manager.totalUnread, equals(1));
      expect(manager.unreadByGroup.containsKey('g1'), isFalse);
      expect(manager.getUnreadForGroup('g9'), equals(1));
    });

    test('9. Duas chamadas concorrentes de refreshAll() não permitem resposta antiga sobrescrever estado mais recente', () async {
      final controlledService = ControlledChatService();
      controlledService.completer1 = Completer<ChatUnreadSnapshot>();
      controlledService.completer2 = Completer<ChatUnreadSnapshot>();

      final testManager = UnreadChatManager.test(chatService: controlledService);

      // Chamada 1 inicia (lenta)
      final future1 = testManager.refreshAll();

      // Chamada 2 inicia (rápida)
      final future2 = testManager.refreshAll();

      // Chamada 2 completa primeiro com total = 2
      controlledService.completer2!.complete(ChatUnreadSnapshot(
        totalUnread: 2,
        unreadByCommunity: {'comm-1': 2},
        unreadByGroup: {'g1': 2},
        groupToCommunity: {'g1': 'comm-1'},
        timestamp: DateTime.now(),
      ));

      await future2;
      expect(testManager.totalUnread, equals(2));

      // Chamada 1 completa DEPOIS com snapshot antigo (total = 10)
      controlledService.completer1!.complete(ChatUnreadSnapshot(
        totalUnread: 10,
        unreadByCommunity: {'comm-1': 10},
        unreadByGroup: {'g1': 10},
        groupToCommunity: {'g1': 'comm-1'},
        timestamp: DateTime.now().subtract(const Duration(seconds: 1)),
      ));

      await future1;

      // O estado NÃO pode ser sobrescrito pelo snapshot antigo (10)! Deve permanecer 2.
      expect(testManager.totalUnread, equals(2));
    });

    test('10. Erro do backend não destrói snapshot válido já existente', () async {
      // 1º carregamento bem-sucedido
      fakeChatService.nextSnapshot = ChatUnreadSnapshot(
        totalUnread: 6,
        unreadByCommunity: {'comm-1': 6},
        unreadByGroup: {'g1': 6},
        groupToCommunity: {'g1': 'comm-1'},
        timestamp: DateTime.now(),
      );

      await manager.refreshAll();
      expect(manager.totalUnread, equals(6));
      expect(manager.getUnreadForGroup('g1'), equals(6));

      // 2º carregamento simula erro de conexão do Supabase
      fakeChatService.errorToThrow = Exception('Falha de conexão com Supabase');

      await manager.refreshAll();

      // Snapshot anterior deve permanecer intacto
      expect(manager.totalUnread, equals(6));
      expect(manager.getUnreadForGroup('g1'), equals(6));
      expect(manager.getUnreadForCommunity('comm-1'), equals(6));
      expect(manager.isLoading, isFalse);
    });
  });
}
