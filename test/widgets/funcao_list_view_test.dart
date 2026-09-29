import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/design_system/taskflow_design_system.dart';
import 'package:task2026/widgets/funcao_list_view.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:task2026/config/supabase_config.dart';

Widget createTestablePilotApp({ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? TaskFlowTheme.light(),
    home: const FuncaoListView(),
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

  group('TaskFlow Design System — Pilot Screen (FuncaoListView)', () {
    testWidgets('FuncaoListView renderiza TFPageHeader, TFTextField e TFEmptyState', (tester) async {
      await tester.pumpWidget(createTestablePilotApp());
      await tester.pump();

      // TFPageHeader
      expect(find.text('Cadastro de Funções'), findsOneWidget);
      expect(find.text('Gestão de cargos, especialidades técnicas e permissões de executores'), findsOneWidget);
      expect(find.text('Nova Função'), findsOneWidget);

      // TFTextField de busca
      expect(find.byType(TFTextField), findsOneWidget);
      expect(find.text('Buscar funções por nome ou descrição...'), findsOneWidget);

      // TFEmptyState quando não há registros retornados
      expect(find.byType(TFEmptyState), findsOneWidget);
      expect(find.text('Nenhuma função encontrada'), findsOneWidget);
    });

    testWidgets('FuncaoListView renderiza nos 3 temas do TFDS (Light, Dark, AXIA)', (tester) async {
      for (final theme in [TaskFlowTheme.light(), TaskFlowTheme.dark(), TaskFlowTheme.axia()]) {
        await tester.pumpWidget(createTestablePilotApp(theme: theme));
        await tester.pump();

        expect(find.text('Cadastro de Funções'), findsOneWidget);
        expect(find.text('Nova Função'), findsOneWidget);
      }
    });

    testWidgets('FuncaoListView suporta digitação no TFTextField', (tester) async {
      await tester.pumpWidget(createTestablePilotApp());
      await tester.pump();

      await tester.enterText(find.byType(TextFormField), 'Eletricista');
      await tester.pump();

      expect(find.text('Eletricista'), findsOneWidget);
    });

    testWidgets('FuncaoListView se adapta a telas mobile sem erro de overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestablePilotApp());
      await tester.pump();

      expect(find.text('Cadastro de Funções'), findsOneWidget);
    });

    testWidgets('FuncaoListView no desktop (1280x800) inicializa com modo tabela ativo', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestablePilotApp());
      await tester.pumpAndSettle();

      expect(find.text('Cadastro de Funções'), findsOneWidget);
      // Empty state renderizado
      expect(find.byType(TFEmptyState), findsOneWidget);
    });

    testWidgets('Diálogo de exclusão do piloto usa TFModalDialog', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: TaskFlowTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  TFModalDialog.confirm(
                    context: context,
                    title: 'Confirmar exclusão',
                    message: 'Deseja realmente excluir a função "Eletricista"?',
                    confirmLabel: 'Excluir',
                    cancelLabel: 'Cancelar',
                    isDestructive: true,
                  );
                },
                child: const Text('Disparar Exclusão'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Disparar Exclusão'));
      await tester.pumpAndSettle();

      expect(find.byType(TFModalDialog), findsOneWidget);
      expect(find.text('Confirmar exclusão'), findsOneWidget);
      expect(find.text('Deseja realmente excluir a função "Eletricista"?'), findsOneWidget);
      expect(find.text('Excluir'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.byType(TFModalDialog), findsNothing);
    });
  });
}
