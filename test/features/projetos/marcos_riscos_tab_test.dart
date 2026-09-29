import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task2026/config/supabase_config.dart';
import 'package:task2026/design_system/taskflow_design_system.dart';
import 'package:task2026/features/projetos/models/projeto.dart';
import 'package:task2026/features/projetos/models/projeto_marco.dart';
import 'package:task2026/features/projetos/models/projeto_risco.dart';
import 'package:task2026/features/projetos/presentation/widgets/marcos_riscos_tab.dart';
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

  group('MarcosRiscosTab Tests', () {
    testWidgets('MarcosRiscosTab renderiza abas do tab controller', (tester) async {
      final projeto = Projeto(id: 'prj-test', nome: 'Projeto Marcos');
      final service = ProjetoService();
      await tester.pumpWidget(_wrap(MarcosRiscosTab(projeto: projeto, service: service)));
      await tester.pump();

      expect(find.text('Marcos (Milestones)'), findsOneWidget);
      expect(find.text('Riscos do Projeto'), findsOneWidget);
    });

    testWidgets('MarcoFormDialog renderiza em modo criacao e valida campos', (tester) async {
      await tester.pumpWidget(_wrap(const MarcoFormDialog(projetoId: 'prj-1')));
      await tester.pumpAndSettle();

      expect(find.text('Novo Marco'), findsOneWidget);
      expect(find.text('Nome do Marco *'), findsOneWidget);
      expect(find.text('Salvar'), findsOneWidget);

      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(find.text('Campo obrigatório'), findsOneWidget);
    });

    testWidgets('MarcoFormDialog renderiza em modo edicao populando dados', (tester) async {
      final marco = ProjetoMarco(
        id: 'mc-1',
        projetoId: 'prj-1',
        nome: 'Energização da SE',
        status: 'PENDENTE',
      );

      await tester.pumpWidget(_wrap(MarcoFormDialog(projetoId: 'prj-1', marco: marco)));
      await tester.pumpAndSettle();

      expect(find.text('Editar Marco'), findsOneWidget);
      expect(find.text('Energização da SE'), findsOneWidget);
    });

    testWidgets('RiscoFormDialog renderiza em modo criacao e edicao', (tester) async {
      final risco = ProjetoRisco(
        id: 'rc-1',
        projetoId: 'prj-1',
        titulo: 'Atraso de Fornecimento',
        probabilidade: 'ALTA',
        impacto: 'ALTO',
        status: 'IDENTIFICADO',
      );

      await tester.pumpWidget(_wrap(RiscoFormDialog(projetoId: 'prj-1', risco: risco)));
      await tester.pumpAndSettle();

      expect(find.text('Editar Risco'), findsOneWidget);
      expect(find.text('Atraso de Fornecimento'), findsOneWidget);
      expect(find.text('Probabilidade'), findsOneWidget);
      expect(find.text('Impacto'), findsOneWidget);
    });
  });
}
