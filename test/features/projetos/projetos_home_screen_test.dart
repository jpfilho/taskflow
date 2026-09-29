import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/design_system/taskflow_design_system.dart';
import 'package:task2026/features/projetos/models/projeto.dart';
import 'package:task2026/features/projetos/presentation/widgets/projeto_card.dart';

Widget _wrap(Widget child, {ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? TaskFlowTheme.light(),
    home: Scaffold(body: child),
  );
}

void main() {
  group('ProjetoCard Tests', () {
    testWidgets('renderiza dados do projeto, badges de status, prioridade e progresso', (tester) async {
      final projeto = Projeto(
        id: 'prj-001',
        nome: 'Construção da LT 230kV',
        codigo: 'LT-230',
        descricao: 'Linha de transmissão ligando subestações A e B',
        status: 'ATIVO',
        prioridade: 'ALTA',
        progresso: 75.5,
      );

      await tester.pumpWidget(_wrap(ProjetoCard(projeto: projeto)));
      await tester.pumpAndSettle();

      expect(find.text('LT-230'), findsOneWidget);
      expect(find.text('Construção da LT 230kV'), findsOneWidget);
      expect(find.text('Linha de transmissão ligando subestações A e B'), findsOneWidget);
      expect(find.text('ATIVO'), findsOneWidget);
      expect(find.text('Prioridade: ALTA'), findsOneWidget);
      expect(find.text('75.5%'), findsOneWidget);
    });

    testWidgets('renderiza nos 3 temas do TFDS (Light, Dark, AXIA)', (tester) async {
      final projeto = Projeto(
        id: 'prj-002',
        nome: 'Projeto Multi-Tema',
        status: 'EM PLANEJAMENTO',
        prioridade: 'MEDIA',
        progresso: 10.0,
      );

      for (final theme in [TaskFlowTheme.light(), TaskFlowTheme.dark(), TaskFlowTheme.axia()]) {
        await tester.pumpWidget(_wrap(ProjetoCard(projeto: projeto), theme: theme));
        await tester.pumpAndSettle();

        expect(find.text('Projeto Multi-Tema'), findsOneWidget);
        expect(find.text('EM PLANEJAMENTO'), findsOneWidget);
      }
    });
  });
}
