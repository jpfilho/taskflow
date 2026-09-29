import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task2026/config/supabase_config.dart';
import 'package:task2026/design_system/taskflow_design_system.dart';
import 'package:task2026/features/demandas/data/models/demanda_model.dart';
import 'package:task2026/features/demandas/presentation/screens/demanda_form_screen.dart';

Widget _wrap(Widget child, {ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? TaskFlowTheme.light(),
    home: child,
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

  group('DemandaFormScreen Tests', () {
    testWidgets('renderiza em modo criacao com PageHeader e botoes TFDS', (tester) async {
      await tester.pumpWidget(_wrap(const DemandaFormScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(TFPageHeader), findsOneWidget);
      expect(find.text('Nova Demanda'), findsOneWidget);
      expect(find.text('Salvar Demanda'), findsWidgets);
      expect(find.byType(TFButton), findsWidgets);
      expect(find.byType(TFTextField), findsWidgets);
    });

    testWidgets('renderiza em modo edicao preenchendo valores existentes', (tester) async {
      final demanda = Demanda(
        id: 'dem-123',
        origem: 'Inspeção',
        local: 'Subestação Norte',
        sala: 'Sala 02',
        demanda: 'Substituição de relé térmico',
        nota: '100234567',
        ordem: '400123456',
        si: '12345678/01A',
        at: 'AT-03',
        responsavel: 'João Silva',
        prazo: DateTime(2026, 10, 15),
        status: 'Em execução',
        prioridade: 'Alta',
        observacoes: 'Urgente para liberação de barramento',
      );

      await tester.pumpWidget(_wrap(DemandaFormScreen(demandaExistente: demanda)));
      await tester.pumpAndSettle();

      expect(find.text('Editar Demanda'), findsOneWidget);
      expect(find.text('Substituição de relé térmico'), findsOneWidget);
      expect(find.text('Sala 02'), findsOneWidget);
      expect(find.text('100234567'), findsOneWidget);
      expect(find.text('400123456'), findsOneWidget);
    });

    testWidgets('valida campos obrigatorios ao tentar salvar vazio', (tester) async {
      await tester.pumpWidget(_wrap(const DemandaFormScreen()));
      await tester.pumpAndSettle();

      // Clica em Salvar sem preencher nada
      final salvarBtn = find.widgetWithText(TFButton, 'Salvar Demanda').first;
      await tester.tap(salvarBtn);
      await tester.pumpAndSettle();

      expect(find.text('Campo obrigatório'), findsWidgets);
    });
  });
}
