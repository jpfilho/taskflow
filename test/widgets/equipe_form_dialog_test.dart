import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task2026/config/supabase_config.dart';
import 'package:task2026/design_system/taskflow_design_system.dart';
import 'package:task2026/models/equipe.dart';
import 'package:task2026/widgets/equipe_form_dialog.dart';

Widget createTestableFormApp({ThemeData? theme, required Widget child}) {
  return MaterialApp(
    theme: theme ?? TaskFlowTheme.light(),
    home: Scaffold(body: child),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    try {
      await SupabaseConfig.initialize();
    } catch (_) {}
  });

  group('EquipeFormDialog — Dropdowns & Multiescolha Tests', () {
    testWidgets('Renderiza modal de criação de equipe com campos pesquisáveis', (tester) async {
      await tester.pumpWidget(createTestableFormApp(child: const EquipeFormDialog()));
      await tester.pump();

      expect(find.text('Nova Equipe'), findsOneWidget);
      expect(find.text('Regional'), findsOneWidget);
      expect(find.text('Divisão'), findsOneWidget);
      expect(find.text('Segmento'), findsOneWidget);
      expect(find.text('Adicionar Executor'), findsOneWidget);
    });

    testWidgets('Permite abrir o modal de criação de equipe em modo edição com executores alocados', (tester) async {
      final equipe = Equipe(
        id: 'eq-1',
        nome: 'Equipe Teste',
        tipo: 'FIXA',
        ativo: true,
      );

      await tester.pumpWidget(createTestableFormApp(child: EquipeFormDialog(equipe: equipe)));
      await tester.pump();

      expect(find.text('Editar Equipe'), findsOneWidget);
      expect(find.text('Equipe Teste'), findsOneWidget);
      expect(find.text('Salvar Alterações'), findsOneWidget);
    });
  });
}
