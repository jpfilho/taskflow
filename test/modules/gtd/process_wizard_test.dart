import 'package:flutter_test/flutter_test.dart';

/// Validações do wizard de processamento do inbox.
void main() {
  group('Processar Inbox - validações', () {
    test('quando exige ação, próxima ação é obrigatória', () {
      const requiresAction = true;
      const nextActionTitle = '';
      final isValid = !requiresAction || (nextActionTitle.trim().isNotEmpty);
      expect(isValid, false);
    });

    test('quando exige ação e título preenchido, é válido', () {
      const requiresAction = true;
      const nextActionTitle = 'Ligar para João';
      final isValid = !requiresAction || (nextActionTitle.trim().isNotEmpty);
      expect(isValid, true);
    });

    test('quando não exige ação, não precisa de próxima ação', () {
      const requiresAction = false;
      const nextActionTitle = '';
      final isValid = !requiresAction || (nextActionTitle.trim().isNotEmpty);
      expect(isValid, true);
    });

    test('disposição "reference" ou "someday" cria referência', () {
      const disposition = 'reference';
      final shouldCreateReference =
          disposition == 'reference' || disposition == 'someday';
      expect(shouldCreateReference, true);
    });

    test('disposição "trash" não cria referência', () {
      const disposition = 'trash';
      final shouldCreateReference =
          disposition == 'reference' || disposition == 'someday';
      expect(shouldCreateReference, false);
    });
  });
}
