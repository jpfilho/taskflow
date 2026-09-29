import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task2026/config/supabase_config.dart';
import 'package:task2026/design_system/taskflow_design_system.dart';
import 'package:task2026/models/empresa.dart';
import 'package:task2026/widgets/empresa_form_dialog.dart';
import 'package:task2026/widgets/empresa_list_view.dart';

Widget createTestableEmpresaApp({ThemeData? theme, Widget? child}) {
  return MaterialApp(
    theme: theme ?? TaskFlowTheme.light(),
    home: child ?? const EmpresaListView(),
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

  group('Wave 2 — EmpresaListView', () {
    testWidgets('EmpresaListView renderiza TFPageHeader, TFTextField e lista/vazio', (tester) async {
      await tester.pumpWidget(createTestableEmpresaApp());
      await tester.pump();

      expect(find.text('Cadastro de Empresas'), findsOneWidget);
      expect(find.text('Nova Empresa'), findsOneWidget);
      expect(find.byType(TFTextField), findsOneWidget);
      expect(find.text('Buscar empresas por nome, regional ou divisão...'), findsOneWidget);
    });

    testWidgets('EmpresaListView renderiza nos 3 temas do TFDS (Light, Dark, AXIA)', (tester) async {
      for (final theme in [TaskFlowTheme.light(), TaskFlowTheme.dark(), TaskFlowTheme.axia()]) {
        await tester.pumpWidget(createTestableEmpresaApp(theme: theme));
        await tester.pump();

        expect(find.text('Cadastro de Empresas'), findsOneWidget);
        expect(find.text('Nova Empresa'), findsOneWidget);
      }
    });

    testWidgets('EmpresaListView se adapta a mobile e desktop', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestableEmpresaApp());
      await tester.pump();
      expect(find.text('Cadastro de Empresas'), findsOneWidget);

      tester.view.physicalSize = const Size(1280, 800);
      await tester.pumpWidget(createTestableEmpresaApp());
      await tester.pump();
      expect(find.text('Cadastro de Empresas'), findsOneWidget);
    });
  });

  group('Wave 2 — EmpresaFormDialog', () {
    testWidgets('EmpresaFormDialog renderiza em modo criação', (tester) async {
      await tester.pumpWidget(
        createTestableEmpresaApp(
          child: const Scaffold(
            body: EmpresaFormDialog(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Nova Empresa'), findsOneWidget);
      expect(find.text('Criar Empresa'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Nome da Empresa'), findsOneWidget);
      expect(find.text('Regional'), findsOneWidget);
      expect(find.text('Divisão'), findsOneWidget);
      expect(find.text('Tipo'), findsOneWidget);
    });

    testWidgets('EmpresaFormDialog renderiza em modo edição com dados populados', (tester) async {
      final empresa = Empresa(
        id: 'emp-1',
        empresa: 'Eletronorte Manutenção',
        regionalId: 'reg-01',
        regional: 'Regional Norte',
        divisaoId: 'div-01',
        divisao: 'Divisão Transmissão',
        tipo: 'TERCEIRA',
      );

      await tester.pumpWidget(
        createTestableEmpresaApp(
          child: Scaffold(
            body: EmpresaFormDialog(empresa: empresa),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Editar Empresa'), findsOneWidget);
      expect(find.text('Salvar Alterações'), findsOneWidget);
      expect(find.text('Eletronorte Manutenção'), findsOneWidget);
    });

    testWidgets('EmpresaFormDialog valida campo nome obrigatório', (tester) async {
      await tester.pumpWidget(
        createTestableEmpresaApp(
          child: const Scaffold(
            body: EmpresaFormDialog(),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Criar Empresa'));
      await tester.pump();

      expect(find.text('Campo obrigatório'), findsWidgets);
    });
  });
}
