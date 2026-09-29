import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task2026/config/supabase_config.dart';
import 'package:task2026/design_system/taskflow_design_system.dart';
import 'package:task2026/features/projetos/models/projeto.dart';
import 'package:task2026/features/projetos/models/projeto_membro.dart';
import 'package:task2026/features/projetos/presentation/widgets/equipe_tab.dart';
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

  group('EquipeTab & MembroFormDialog Tests', () {
    testWidgets('MembroFormDialog renderiza em modo criacao e valida campos', (tester) async {
      await tester.pumpWidget(_wrap(const MembroFormDialog(projetoId: 'prj-1')));
      await tester.pumpAndSettle();

      expect(find.text('Adicionar Membro'), findsOneWidget);
      expect(find.text('Identificação / Nome do Usuário *'), findsOneWidget);
      expect(find.text('Papel no Projeto *'), findsOneWidget);
      expect(find.text('Salvar'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);

      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(find.text('Identificação é obrigatória'), findsOneWidget);
    });

    testWidgets('MembroFormDialog renderiza em modo edicao populando dados', (tester) async {
      final membro = ProjetoMembro(
        id: 'mem-1',
        projetoId: 'prj-1',
        usuarioId: 'marcos.eng',
        papel: 'Engenheiro Chefe',
      );

      await tester.pumpWidget(_wrap(MembroFormDialog(projetoId: 'prj-1', membro: membro)));
      await tester.pumpAndSettle();

      expect(find.text('Editar Membro'), findsOneWidget);
      expect(find.text('marcos.eng'), findsOneWidget);
      expect(find.text('Engenheiro Chefe'), findsOneWidget);
    });

    testWidgets('EquipeTab renderiza estado inicial de carregamento ou header', (tester) async {
      final projeto = Projeto(id: 'prj-empty', nome: 'Projeto Teste');
      final service = ProjetoService();

      await tester.pumpWidget(_wrap(EquipeTab(projeto: projeto, service: service)));
      await tester.pump();

      expect(find.byType(EquipeTab), findsOneWidget);
    });
  });
}
