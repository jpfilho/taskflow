import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/design_system/taskflow_design_system.dart';
import 'package:task2026/features/projetos/models/projeto.dart';
import 'package:task2026/features/projetos/presentation/widgets/projeto_form_dialog.dart';

Widget _wrap(Widget child, {ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? TaskFlowTheme.light(),
    home: Scaffold(body: child),
  );
}

void main() {
  group('ProjetoFormDialog Tests', () {
    testWidgets('renderiza em modo criacao com TFFormDialog e campos vazios', (tester) async {
      await tester.pumpWidget(_wrap(const ProjetoFormDialog()));
      await tester.pumpAndSettle();

      expect(find.text('Novo Projeto'), findsOneWidget);
      expect(find.text('Nome do Projeto *'), findsOneWidget);
      expect(find.text('Código / Sigla (Opcional)'), findsOneWidget);
      expect(find.text('Salvar'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
    });

    testWidgets('renderiza em modo edicao populando valores existentes', (tester) async {
      final projeto = Projeto(
        id: 'prj-123',
        nome: 'Expansão da Subestação Norte',
        codigo: 'EXP-NORTE',
        descricao: 'Obras civis e montagem eletromecânica',
        status: 'ATIVO',
        prioridade: 'ALTA',
        progresso: 45.0,
      );

      await tester.pumpWidget(_wrap(ProjetoFormDialog(projeto: projeto)));
      await tester.pumpAndSettle();

      expect(find.text('Editar Projeto'), findsOneWidget);
      expect(find.text('Expansão da Subestação Norte'), findsOneWidget);
      expect(find.text('EXP-NORTE'), findsOneWidget);
      expect(find.text('Obras civis e montagem eletromecânica'), findsOneWidget);
      expect(find.text('ATIVO'), findsOneWidget);
    });

    testWidgets('valida campo nome obrigatorio ao tentar salvar vazio', (tester) async {
      await tester.pumpWidget(_wrap(const ProjetoFormDialog()));
      await tester.pumpAndSettle();

      // Clicar em Salvar sem preencher
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(find.text('Nome é obrigatório'), findsOneWidget);
    });
  });
}
