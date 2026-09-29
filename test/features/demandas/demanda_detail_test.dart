import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task2026/config/supabase_config.dart';
import 'package:task2026/design_system/taskflow_design_system.dart';
import 'package:task2026/features/demandas/presentation/screens/demanda_detail_screen.dart';

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

  group('DemandaDetailScreen Tests', () {
    testWidgets('renderiza estado de erro/empty amigavel quando id nao existe', (tester) async {
      await tester.pumpWidget(_wrap(const DemandaDetailScreen(demandaId: 'id-inexistente')));
      await tester.pumpAndSettle();

      expect(find.byType(TFPageHeader), findsOneWidget);
      expect(find.byType(TFEmptyState), findsOneWidget);
    });
  });
}
