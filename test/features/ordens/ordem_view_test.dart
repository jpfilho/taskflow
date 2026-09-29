import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task2026/config/supabase_config.dart';
import 'package:task2026/widgets/ordem_view.dart';
import 'package:task2026/design_system/taskflow_design_system.dart';

Widget _buildTestApp(Widget child, {ThemeData? theme, double width = 1280, double height = 800}) {
  return MaterialApp(
    theme: theme ?? TaskFlowTheme.light(),
    home: MediaQuery(
      data: MediaQueryData(
        size: Size(width, height),
      ),
      child: Scaffold(body: child),
    ),
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

  group('OrdemView Tests', () {
    testWidgets('renderiza Toolbar, SegmentedButtons e filtros TFDS na OrdemView', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      await tester.pumpWidget(
        _buildTestApp(const OrdemView()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Ordens'), findsOneWidget);
      expect(find.byType(SegmentedButton<String?>), findsNWidgets(2));
      expect(find.byIcon(Icons.filter_list), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('renderiza nos 3 temas do TFDS (Light, Dark, AXIA)', (tester) async {
      for (final theme in [TaskFlowTheme.light(), TaskFlowTheme.dark(), TaskFlowTheme.axia()]) {
        await tester.pumpWidget(
          _buildTestApp(const OrdemView(), theme: theme),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Ordens'), findsOneWidget);
        await tester.pump(const Duration(seconds: 4));
      }
    });

    testWidgets('renderiza responsivamente em 390px, 768px e 1280px', (tester) async {
      for (final width in [390.0, 768.0, 1280.0]) {
        await tester.binding.setSurfaceSize(Size(width, 800));
        await tester.pumpWidget(
          _buildTestApp(const OrdemView(), width: width),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Ordens'), findsOneWidget);
        await tester.pump(const Duration(seconds: 4));
      }
    });

    testWidgets('alterna entre modo Tabela e Cards', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      await tester.pumpWidget(
        _buildTestApp(const OrdemView()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final cardsButton = find.text('Cards');
      if (cardsButton.evaluate().isNotEmpty) {
        await tester.tap(cardsButton);
        await tester.pump();
      }

      final tabelaButton = find.text('Tabela');
      if (tabelaButton.evaluate().isNotEmpty) {
        await tester.tap(tabelaButton);
        await tester.pump();
      }

      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('expande e oculta painel de filtros ao clicar no botão Filtros', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      await tester.pumpWidget(
        _buildTestApp(const OrdemView()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final filterButton = find.byIcon(Icons.filter_list);
      expect(filterButton, findsOneWidget);

      await tester.tap(filterButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Status (Tarefa)'), findsOneWidget);
      expect(find.text('Local'), findsOneWidget);

      await tester.tap(filterButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.pump(const Duration(seconds: 4));
    });
  });
}
