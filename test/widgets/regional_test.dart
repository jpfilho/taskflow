import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task2026/config/supabase_config.dart';
import 'package:task2026/design_system/taskflow_design_system.dart';
import 'package:task2026/models/regional.dart';
import 'package:task2026/widgets/regional_form_dialog.dart';
import 'package:task2026/widgets/regional_list_view.dart';

Widget createTestableRegionalApp({ThemeData? theme, Widget? child}) {
  return MaterialApp(
    theme: theme ?? TaskFlowTheme.light(),
    home: child ?? const RegionalListView(),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    try {
      await SupabaseConfig.initialize();
    } catch (_) {
      // Já inicializado ou ambiente de teste
    }
  });

  group('Wave 2 — RegionalListView', () {
    testWidgets('RegionalListView renderiza TFPageHeader, TFTextField e lista/vazio', (tester) async {
      await tester.pumpWidget(createTestableRegionalApp());
      await tester.pump();

      expect(find.text('Cadastro de Regionais'), findsOneWidget);
      expect(find.text('Nova Regional'), findsOneWidget);
      expect(find.byType(TFTextField), findsOneWidget);
      expect(find.text('Buscar por regional, sigla ou empresa...'), findsOneWidget);
    });

    testWidgets('RegionalListView renderiza nos 3 temas do TFDS (Light, Dark, AXIA)', (tester) async {
      for (final theme in [TaskFlowTheme.light(), TaskFlowTheme.dark(), TaskFlowTheme.axia()]) {
        await tester.pumpWidget(createTestableRegionalApp(theme: theme));
        await tester.pump();

        expect(find.text('Cadastro de Regionais'), findsOneWidget);
        expect(find.text('Nova Regional'), findsOneWidget);
      }
    });

    testWidgets('RegionalListView se adapta a mobile e desktop', (tester) async {
      // Mobile
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestableRegionalApp());
      await tester.pump();

      expect(find.text('Cadastro de Regionais'), findsOneWidget);

      // Desktop
      tester.view.physicalSize = const Size(1280, 800);
      await tester.pumpWidget(createTestableRegionalApp());
      await tester.pump();

      expect(find.text('Cadastro de Regionais'), findsOneWidget);
    });
  });

  group('Wave 2 — RegionalFormDialog', () {
    testWidgets('RegionalFormDialog renderiza em modo criação com campos vazios', (tester) async {
      await tester.pumpWidget(
        createTestableRegionalApp(
          child: const Scaffold(
            body: RegionalFormDialog(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Nova Regional'), findsOneWidget);
      expect(find.text('Criar Regional'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Regional'), findsOneWidget);
      expect(find.text('Sigla'), findsOneWidget);
      expect(find.text('Empresa'), findsOneWidget);
    });

    testWidgets('RegionalFormDialog renderiza em modo edição com dados preenchidos', (tester) async {
      final regional = Regional(
        id: '123',
        regional: 'Regional Norte',
        divisao: 'RN',
        empresa: 'TaskFlow Corp',
      );

      await tester.pumpWidget(
        createTestableRegionalApp(
          child: Scaffold(
            body: RegionalFormDialog(regional: regional),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Editar Regional'), findsOneWidget);
      expect(find.text('Salvar Alterações'), findsOneWidget);
      expect(find.text('Regional Norte'), findsOneWidget);
      expect(find.text('RN'), findsOneWidget);
      expect(find.text('TaskFlow Corp'), findsOneWidget);
    });

    testWidgets('RegionalFormDialog valida campos obrigatórios', (tester) async {
      await tester.pumpWidget(
        createTestableRegionalApp(
          child: const Scaffold(
            body: RegionalFormDialog(),
          ),
        ),
      );
      await tester.pump();

      // Clicar em Criar Regional sem preencher
      await tester.tap(find.text('Criar Regional'));
      await tester.pump();

      expect(find.text('Campo obrigatório'), findsNWidgets(3));
    });

    testWidgets('RegionalFormDialog submete com sucesso quando dados válidos', (tester) async {
      Regional? savedRegional;

      await tester.pumpWidget(
        MaterialApp(
          theme: TaskFlowTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  savedRegional = await showDialog<Regional>(
                    context: context,
                    builder: (ctx) => const RegionalFormDialog(),
                  );
                },
                child: const Text('Abrir Form'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Form'));
      await tester.pumpAndSettle();

      // Preencher os 3 campos
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'Regional Sul');
      await tester.enterText(textFields.at(1), 'RS');
      await tester.enterText(textFields.at(2), 'Empresa Sul');
      await tester.pump();

      await tester.tap(find.text('Criar Regional'));
      await tester.pumpAndSettle();

      expect(savedRegional, isNotNull);
      expect(savedRegional!.regional, 'Regional Sul');
      expect(savedRegional!.divisao, 'RS');
      expect(savedRegional!.empresa, 'Empresa Sul');
    });
  });
}
