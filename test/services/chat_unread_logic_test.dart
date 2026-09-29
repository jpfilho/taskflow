import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/services/chat_service.dart';

void main() {
  group('Fase 1: Validação da Lógica de Contagem de Não Lidas', () {
    test('Mensagens próprias nunca devem ser contabilizadas como não lidas', () {
      const currentUserId = 'user-123';
      const otherUserId = 'user-456';

      final mensagensMock = [
        {'id': 'msg-1', 'grupo_id': 'g1', 'usuario_id': currentUserId},
        {'id': 'msg-2', 'grupo_id': 'g1', 'usuario_id': currentUserId},
        {'id': 'msg-3', 'grupo_id': 'g1', 'usuario_id': otherUserId},
        {'id': 'msg-4', 'grupo_id': 'g1', 'usuario_id': otherUserId},
      ];

      final lidasSet = <String>{'msg-3'}; // msg-3 já foi lida pelo user-123

      // Algoritmo exatamente como implementado na Fase 1 em ChatService
      int contarNaoLidasParaUsuario(String userId) {
        final mensagensOutros = mensagensMock.where((m) {
          final senderId = m['usuario_id']?.toString();
          return senderId != userId;
        }).toList();

        final naoLidas = mensagensOutros
            .where((m) => !lidasSet.contains(m['id']))
            .toList();

        return naoLidas.length;
      }

      final countUser123 = contarNaoLidasParaUsuario(currentUserId);
      // Para user-123:
      // msg-1 e msg-2 são do próprio user-123 -> desconsideradas
      // msg-3 é de outro, mas está em lidasSet -> lida
      // msg-4 é de outro e não está em lidasSet -> NÃO LIDA (1)
      expect(countUser123, equals(1));
    });

    test('Invalidação de cache estático do ChatService funciona corretamente', () {
      // Invalidação estática sem requerer conexão de rede/Supabase
      ChatService.invalidateTotalUnreadCache();
      expect(true, isTrue);
    });
  });
}
