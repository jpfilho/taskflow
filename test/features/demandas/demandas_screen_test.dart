import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task2026/config/supabase_config.dart';
import 'package:task2026/design_system/taskflow_design_system.dart';
import 'package:task2026/features/demandas/data/models/demanda_model.dart';
import 'package:task2026/features/demandas/presentation/screens/demandas_screen.dart';
import 'package:task2026/features/demandas/presentation/widgets/demanda_card.dart';

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

  group('DemandaCard Tests', () {
    testWidgets('renderiza status badge, prazo, local e responsavel', (tester) async {
      final demanda = Demanda(
        id: 'dem-1',
        origem: 'Inspeção',
        local: 'Subestação Central',
        sala: 'Sala Técnica',
        demanda: 'Troca de disjuntor geral de média tensão',
        responsavel: 'Carlos Santos',
        prazo: DateTime.now().add(const Duration(days: 10)),
        status: 'Aberta',
        prioridade: 'Crítica',
      );

      await tester.pumpWidget(_wrap(DemandaCard(demanda: demanda)));
      await tester.pumpAndSettle();

      expect(find.text('Aberta'), findsOneWidget);
      expect(find.text('Troca de disjuntor geral de média tensão'), findsOneWidget);
      expect(find.textContaining('Subestação Central'), findsOneWidget);
      expect(find.text('Carlos Santos'), findsOneWidget);
      expect(find.text('Crítica'), findsOneWidget);
      expect(find.byType(TFStatusBadge), findsNWidgets(2));
    });
  });

  group('DemandasScreen Tests', () {
    testWidgets('renderiza TFPageHeader, TFTextField de busca e contadores KPI', (tester) async {
      await tester.pumpWidget(_wrap(const DemandasScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(TFPageHeader), findsOneWidget);
      expect(find.text('Demandas Operacionais'), findsOneWidget);
      expect(find.text('Nova Demanda'), findsOneWidget);
      expect(find.byType(TFTextField), findsOneWidget);
    });
  });
}
