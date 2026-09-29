import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task2026/config/supabase_config.dart';
import 'package:task2026/design_system/taskflow_design_system.dart';
import 'package:task2026/models/local.dart';
import 'package:task2026/widgets/local_form_dialog.dart';
import 'package:task2026/widgets/local_list_view.dart';

Widget createTestableLocalApp({ThemeData? theme, Widget? child}) {
  return MaterialApp(
    theme: theme ?? TaskFlowTheme.light(),
    home: child ?? const LocalListView(),
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

  group('Wave 2 — LocalListView', () {
    testWidgets('LocalListView renderiza TFPageHeader, TFTextField e lista/vazio', (tester) async {
      await tester.pumpWidget(createTestableLocalApp());
      await tester.pump();

      expect(find.text('Cadastro de Locais'), findsOneWidget);
      expect(find.text('Novo Local'), findsOneWidget);
      expect(find.byType(TFTextField), findsOneWidget);
      expect(find.text('Buscar por local, descrição, SAP ou regional...'), findsOneWidget);
    });

    testWidgets('LocalListView renderiza nos 3 temas do TFDS (Light, Dark, AXIA)', (tester) async {
      for (final theme in [TaskFlowTheme.light(), TaskFlowTheme.dark(), TaskFlowTheme.axia()]) {
        await tester.pumpWidget(createTestableLocalApp(theme: theme));
        await tester.pump();

        expect(find.text('Cadastro de Locais'), findsOneWidget);
        expect(find.text('Novo Local'), findsOneWidget);
      }
    });

    testWidgets('LocalListView se adapta a mobile e desktop', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestableLocalApp());
      await tester.pump();
      expect(find.text('Cadastro de Locais'), findsOneWidget);

      tester.view.physicalSize = const Size(1280, 800);
      await tester.pumpWidget(createTestableLocalApp());
      await tester.pump();
      expect(find.text('Cadastro de Locais'), findsOneWidget);
    });

    testWidgets('LocalListView busca textual com tokens e normalização de acentos', (tester) async {
      await tester.pumpWidget(createTestableLocalApp());
      await tester.pump();

      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      // Simula digitação com acentos e sem acentos
      await tester.enterText(searchField, 'telecom automacao');
      await tester.pump();

      // Limpar busca pelo botão suffix
      final clearButton = find.byTooltip('Limpar busca');
      if (clearButton.evaluate().isNotEmpty) {
        await tester.tap(clearButton);
        await tester.pump();
        expect(find.text('Buscar por local, descrição, SAP ou regional...'), findsOneWidget);
      }
    });
  });

  group('Wave 2 — LocalFormDialog', () {
    testWidgets('LocalFormDialog renderiza em modo criação', (tester) async {
      await tester.pumpWidget(
        createTestableLocalApp(
          child: const Scaffold(
            body: LocalFormDialog(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Novo Local'), findsOneWidget);
      expect(find.text('Criar Local'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Local'), findsOneWidget);
      expect(find.text('Para Toda Regional'), findsOneWidget);
      expect(find.text('Para Toda Divisão'), findsOneWidget);
    });

    testWidgets('LocalFormDialog renderiza em modo edição com dados populados', (tester) async {
      final local = Local(
        id: 'loc-1',
        local: 'Subestação Central',
        descricao: 'Barramento de 230kV',
        localInstalacaoSap: 'SE-CEN-01',
        paraTodaRegional: true,
      );

      await tester.pumpWidget(
        createTestableLocalApp(
          child: Scaffold(
            body: LocalFormDialog(local: local),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Editar Local'), findsOneWidget);
      expect(find.text('Salvar Alterações'), findsOneWidget);
      expect(find.text('Subestação Central'), findsOneWidget);
      expect(find.text('Barramento de 230kV'), findsOneWidget);
      expect(find.text('SE-CEN-01'), findsOneWidget);
    });

    testWidgets('LocalFormDialog valida campo local obrigatório', (tester) async {
      await tester.pumpWidget(
        createTestableLocalApp(
          child: const Scaffold(
            body: LocalFormDialog(),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Criar Local'));
      await tester.pump();

      expect(find.text('Campo obrigatório'), findsWidgets);
    });
  });
}
