import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task2026/config/supabase_config.dart';
import 'package:task2026/services/chat_service.dart';
import 'package:task2026/services/unread_chat_manager.dart';

void main() {
  test('Homologação Supabase Real: conexão, snapshot, consistência e tempos', () async {
    SharedPreferences.setMockInitialValues({});
    try {
      await SupabaseConfig.initialize();
    } catch (_) {}

    final client = SupabaseConfig.client;
    expect(client, isNotNull);

    // 1. Validar disponibilidade do Realtime e PostgREST no backend
    final swInit = Stopwatch()..start();
    final grupos = await client
        .from('grupos_chat')
        .select('id, tarefa_nome, comunidade_id')
        .limit(5);
    swInit.stop();
    print('⏱️ [E2E-REAL] Consulta inicial grupos_chat executada em: ${swInit.elapsedMilliseconds}ms (${grupos.length} grupos)');
    expect(grupos.isNotEmpty, true);

    // 2. Testar ChatService com backend real
    final chatService = ChatService();
    final swSnapshot = Stopwatch()..start();
    final snapshot = await chatService.carregarSnapshotNaoLidasCompleto();
    swSnapshot.stop();
    print('⏱️ [E2E-REAL] carregarSnapshotNaoLidasCompleto executado em: ${swSnapshot.elapsedMilliseconds}ms');
    print('📊 [E2E-REAL] Snapshot retornado: totalUnread=${snapshot.totalUnread}, grupos=${snapshot.unreadByGroup.length}, comunidades=${snapshot.unreadByCommunity.length}');

    // 3. Testar UnreadChatManager inicializado com backend real
    final manager = UnreadChatManager();
    final swManager = Stopwatch()..start();
    await manager.refreshAll(force: true);
    swManager.stop();

    print('⏱️ [E2E-REAL] manager.refreshAll() executado em: ${swManager.elapsedMilliseconds}ms');
    print('✅ [E2E-REAL] Manager totalUnread=${manager.totalUnread}, isInitialized=${manager.isInitialized}');

    // 4. Validação de invariantes no ambiente real
    expect(manager.totalUnread, greaterThanOrEqualTo(0));
    for (final count in manager.unreadByGroup.values) {
      expect(count, greaterThanOrEqualTo(0));
    }
    for (final count in manager.unreadByCommunity.values) {
      expect(count, greaterThanOrEqualTo(0));
    }
    
    // Invariante: Header é a soma dos grupos
    final sumGrupos = manager.unreadByGroup.values.fold<int>(0, (a, b) => a + b);
    expect(manager.totalUnread, equals(sumGrupos),
        reason: 'Header deve ser a soma exata dos contadores dos grupos no backend real');
  });
}
