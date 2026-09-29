import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task2026/config/supabase_config.dart';
import 'package:task2026/design_system/taskflow_design_system.dart';
import 'package:task2026/models/tipo_atividade.dart';
import 'package:task2026/widgets/tipo_atividade_form_dialog.dart';
import 'package:task2026/widgets/tipo_atividade_list_view.dart';

Widget createTestableTipoAtividadeApp({ThemeData? theme, Widget? child}) {
  return MaterialApp(
    theme: theme ?? TaskFlowTheme.light(),
    home: child ?? const TipoAtividadeListView(),
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

  group('Wave 2 — TipoAtividadeListView', () {
    testWidgets('TipoAtividadeListView renderiza TFPageHeader, TFTextField e lista/vazio', (tester) async {
      await tester.pumpWidget(createTestableTipoAtividadeApp());
      await tester.pump();

      expect(find.text('Tipos de Atividade'), findsOneWidget);
      expect(find.text('Novo Tipo'), findsOneWidget);
      expect(find.byType(TFTextField), findsOneWidget);
      expect(find.text('Buscar por código ou descrição...'), findsOneWidget);
    });

    testWidgets('TipoAtividadeListView renderiza nos 3 temas do TFDS (Light, Dark, AXIA)', (tester) async {
      for (final theme in [TaskFlowTheme.light(), TaskFlowTheme.dark(), TaskFlowTheme.axia()]) {
        await tester.pumpWidget(createTestableTipoAtividadeApp(theme: theme));
        await tester.pump();

        expect(find.text('Tipos de Atividade'), findsOneWidget);
        expect(find.text('Novo Tipo'), findsOneWidget);
      }
    });

    testWidgets('TipoAtividadeListView se adapta a mobile e desktop', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestableTipoAtividadeApp());
      await tester.pump();
      expect(find.text('Tipos de Atividade'), findsOneWidget);

      tester.view.physicalSize = const Size(1280, 800);
      await tester.pumpWidget(createTestableTipoAtividadeApp());
      await tester.pump();
      expect(find.text('Tipos de Atividade'), findsOneWidget);
    });
  });

  group('Wave 2 — TipoAtividadeFormDialog', () {
    testWidgets('TipoAtividadeFormDialog renderiza em modo criação', (tester) async {
      await tester.pumpWidget(
        createTestableTipoAtividadeApp(
          child: const Scaffold(
            body: TipoAtividadeFormDialog(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Novo Tipo de Atividade'), findsOneWidget);
      expect(find.text('Criar Tipo de Atividade'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Código'), findsOneWidget);
      expect(find.text('Descrição'), findsOneWidget);
      expect(find.byType(TFSwitch), findsOneWidget);
    });

    testWidgets('TipoAtividadeFormDialog renderiza em modo edição com dados populados', (tester) async {
      final tipo = TipoAtividade(
        id: 'tipo-1',
        codigo: 'MANUT',
        descricao: 'Manutenção Preventiva e Corretiva',
        ativo: true,
        cor: '#3B82F6',
      );

      await tester.pumpWidget(
        createTestableTipoAtividadeApp(
          child: Scaffold(
            body: TipoAtividadeFormDialog(tipoAtividade: tipo),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Editar Tipo de Atividade'), findsOneWidget);
      expect(find.text('Salvar Alterações'), findsOneWidget);
      expect(find.text('MANUT'), findsOneWidget);
      expect(find.text('Manutenção Preventiva e Corretiva'), findsOneWidget);
    });

    testWidgets('TipoAtividadeFormDialog valida campos obrigatórios', (tester) async {
      await tester.pumpWidget(
        createTestableTipoAtividadeApp(
          child: const Scaffold(
            body: TipoAtividadeFormDialog(),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Criar Tipo de Atividade'));
      await tester.pump();

      expect(find.text('Campo obrigatório'), findsWidgets);
    });
  });
}
