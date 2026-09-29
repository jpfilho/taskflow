import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task2026/config/supabase_config.dart';
import 'package:task2026/design_system/taskflow_design_system.dart';
import 'package:task2026/widgets/centro_trabalho_list_view.dart';

Widget createTestableApp({ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? TaskFlowTheme.light(),
    home: const CentroTrabalhoListView(),
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

  group('CentroTrabalhoListView TFDS Tests', () {
    testWidgets('renderiza TFPageHeader com botão Voltar, TFTextField e estado inicial', (tester) async {
      await tester.pumpWidget(createTestableApp());
      await tester.pump();

      expect(find.text('Cadastro de Centros de Trabalho'), findsOneWidget);
      expect(find.byTooltip('Voltar'), findsOneWidget);
      expect(find.text('Novo Centro de Trabalho'), findsOneWidget);
      expect(find.byType(TFTextField), findsOneWidget);
      expect(find.byType(TFEmptyState), findsOneWidget);
    });

    testWidgets('renderiza nos 3 temas do TFDS (Light, Dark, AXIA)', (tester) async {
      for (final theme in [TaskFlowTheme.light(), TaskFlowTheme.dark(), TaskFlowTheme.axia()]) {
        await tester.pumpWidget(createTestableApp(theme: theme));
        await tester.pump();

        expect(find.text('Cadastro de Centros de Trabalho'), findsOneWidget);
        expect(find.text('Novo Centro de Trabalho'), findsOneWidget);
      }
    });

    testWidgets('suporta digitação no campo de busca', (tester) async {
      await tester.pumpWidget(createTestableApp());
      await tester.pump();

      await tester.enterText(find.byType(TextFormField), 'BASE 01');
      await tester.pump();

      expect(find.text('BASE 01'), findsOneWidget);
    });

    testWidgets('se adapta a viewport mobile (390x844) sem overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestableApp());
      await tester.pump();

      expect(find.text('Cadastro de Centros de Trabalho'), findsOneWidget);
    });

    testWidgets('no desktop (1280x800) renderiza com layout adequado', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestableApp());
      await tester.pumpAndSettle();

      expect(find.text('Cadastro de Centros de Trabalho'), findsOneWidget);
      expect(find.byType(TFEmptyState), findsOneWidget);
    });
  });
}
