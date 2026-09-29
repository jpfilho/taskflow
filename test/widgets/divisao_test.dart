import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task2026/config/supabase_config.dart';
import 'package:task2026/design_system/taskflow_design_system.dart';
import 'package:task2026/models/divisao.dart';
import 'package:task2026/widgets/divisao_form_dialog.dart';
import 'package:task2026/widgets/divisao_list_view.dart';

Widget createTestableDivisaoApp({ThemeData? theme, Widget? child}) {
  return MaterialApp(
    theme: theme ?? TaskFlowTheme.light(),
    home: child ?? const DivisaoListView(),
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

  group('Wave 2 — DivisaoListView', () {
    testWidgets('DivisaoListView renderiza TFPageHeader, TFTextField e lista/vazio', (tester) async {
      await tester.pumpWidget(createTestableDivisaoApp());
      await tester.pump();

      expect(find.text('Cadastro de Divisões'), findsOneWidget);
      expect(find.text('Nova Divisão'), findsOneWidget);
      expect(find.byType(TFTextField), findsOneWidget);
      expect(find.text('Buscar por divisão, regional ou segmento...'), findsOneWidget);
    });

    testWidgets('DivisaoListView renderiza nos 3 temas do TFDS (Light, Dark, AXIA)', (tester) async {
      for (final theme in [TaskFlowTheme.light(), TaskFlowTheme.dark(), TaskFlowTheme.axia()]) {
        await tester.pumpWidget(createTestableDivisaoApp(theme: theme));
        await tester.pump();

        expect(find.text('Cadastro de Divisões'), findsOneWidget);
        expect(find.text('Nova Divisão'), findsOneWidget);
      }
    });

    testWidgets('DivisaoListView se adapta a mobile e desktop', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestableDivisaoApp());
      await tester.pump();
      expect(find.text('Cadastro de Divisões'), findsOneWidget);

      tester.view.physicalSize = const Size(1280, 800);
      await tester.pumpWidget(createTestableDivisaoApp());
      await tester.pump();
      expect(find.text('Cadastro de Divisões'), findsOneWidget);
    });
  });

  group('Wave 2 — DivisaoFormDialog', () {
    testWidgets('DivisaoFormDialog renderiza em modo criação', (tester) async {
      await tester.pumpWidget(
        createTestableDivisaoApp(
          child: const Scaffold(
            body: DivisaoFormDialog(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Nova Divisão'), findsOneWidget);
      expect(find.text('Criar Divisão'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Divisão'), findsOneWidget);
      expect(find.text('Regionais de Atuação *'), findsOneWidget);
    });

    testWidgets('DivisaoFormDialog renderiza em modo edição com dados populados', (tester) async {
      final divisao = Divisao(
        id: 'div-123',
        divisao: 'Divisão Metropolitana',
        regionalId: 'reg-01',
        regional: 'Regional Centro',
        segmentoIds: ['seg-1'],
        segmentos: ['Comercial'],
      );

      await tester.pumpWidget(
        createTestableDivisaoApp(
          child: Scaffold(
            body: DivisaoFormDialog(divisao: divisao),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Editar Divisão'), findsOneWidget);
      expect(find.text('Salvar Alterações'), findsOneWidget);
      expect(find.text('Divisão Metropolitana'), findsOneWidget);
    });

    testWidgets('DivisaoFormDialog valida campo divisão obrigatório', (tester) async {
      await tester.pumpWidget(
        createTestableDivisaoApp(
          child: const Scaffold(
            body: DivisaoFormDialog(),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Criar Divisão'));
      await tester.pump();

      expect(find.text('Campo obrigatório'), findsWidgets);
    });
  });
}
