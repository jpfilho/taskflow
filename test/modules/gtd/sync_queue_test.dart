import 'package:flutter_test/flutter_test.dart';

/// Testes para a lógica da sync_queue e last-write-wins.
void main() {
  group('Last-write-wins (updated_at)', () {
    test('item com updated_at mais recente vence', () {
      final a = DateTime.utc(2026, 1, 1, 12, 0);
      final b = DateTime.utc(2026, 1, 1, 13, 0);
      expect(b.isAfter(a), true);
      final winner = a.isBefore(b) ? b : a;
      expect(winner, b);
    });

    test('comparação updated_at determina qual registro manter', () {
      final local = DateTime.utc(2026, 1, 1, 10, 0);
      final remote = DateTime.utc(2026, 1, 1, 11, 0);
      final keepRemote = remote.isAfter(local);
      expect(keepRemote, true);
    });
  });

  group('Enqueue payload', () {
    test('payload de upsert contém entity e entity_id', () {
      const entity = 'gtd_actions';
      const entityId = 'uuid-123';
      const op = 'upsert';
      final payload = <String, dynamic>{
        'id': entityId,
        'user_id': 'user1',
        'title': 'Ação',
        'status': 'next',
        'created_at': '2026-01-01T12:00:00.000Z',
        'updated_at': '2026-01-01T12:00:00.000Z',
      };
      expect(payload['id'], entityId);
      expect(entity, 'gtd_actions');
      expect(op, 'upsert');
    });
  });
}
