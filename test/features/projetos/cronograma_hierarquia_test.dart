import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task2026/config/supabase_config.dart';
import 'package:task2026/design_system/taskflow_design_system.dart';
import 'package:task2026/features/projetos/models/projeto_etapa.dart';
import 'package:task2026/features/projetos/models/projeto_macroetapa.dart';
import 'package:task2026/features/projetos/presentation/widgets/cronograma_tab.dart';
import 'package:task2026/features/projetos/services/projeto_service.dart';

Widget _wrap(Widget child, {ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? TaskFlowTheme.light(),
    home: Scaffold(body: child),
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

  group('Cronograma Hierarquia WBS Tests', () {
    testWidgets('MacroetapaTile renderiza ordem, nome e status badge', (tester) async {
      final macro = ProjetoMacroetapa(
        id: 'macro-1',
        projetoId: 'prj-1',
        ordem: 1,
        nome: 'Projetos Executivos',
        status: 'EM_ANDAMENTO',
      );

      final service = ProjetoService();

      await tester.pumpWidget(_wrap(
        MacroetapaTile(
          macroetapa: macro,
          service: service,
          onChanged: () {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('Projetos Executivos'), findsOneWidget);
      expect(find.text('EM_ANDAMENTO'), findsOneWidget);
    });

    testWidgets('EtapaTile renderiza ordem, nome e status badge', (tester) async {
      final etapa = ProjetoEtapa(
        id: 'etapa-1',
        projetoId: 'prj-1',
        macroetapaId: 'macro-1',
        ordem: 2,
        nome: 'Fundações das Torres',
        status: 'PENDENTE',
      );

      final service = ProjetoService();

      await tester.pumpWidget(_wrap(
        EtapaTile(
          etapa: etapa,
          service: service,
          onChanged: () {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('2'), findsOneWidget);
      expect(find.text('Fundações das Torres'), findsOneWidget);
      expect(find.text('PENDENTE'), findsOneWidget);
    });
  });
}
