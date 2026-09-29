import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/design_system/taskflow_design_system.dart';

/// Helper para testar widgets envolvidos com os temas do TaskFlow Design System.
Widget createTestableWidget({
  required Widget child,
  ThemeData? theme,
}) {
  return MaterialApp(
    theme: theme ?? TaskFlowTheme.light(),
    home: Scaffold(
      body: Center(child: child),
    ),
  );
}

void main() {
  group('TaskFlow Design System — Components Tests', () {
    // 1. TFButton
    testWidgets('TFButton renderiza com label, ícone e responde a cliques', (tester) async {
      bool clicked = false;
      await tester.pumpWidget(createTestableWidget(
        child: TFButton(
          label: 'Salvar Alterações',
          leadingIcon: TFIcons.save,
          onPressed: () => clicked = true,
        ),
      ));

      expect(find.text('Salvar Alterações'), findsOneWidget);
      expect(find.byIcon(TFIcons.save), findsOneWidget);

      await tester.tap(find.text('Salvar Alterações'));
      await tester.pumpAndSettle();
      expect(clicked, isTrue);
    });

    testWidgets('TFButton no estado disabled não responde a cliques', (tester) async {
      bool clicked = false;
      await tester.pumpWidget(createTestableWidget(
        child: const TFButton(
          label: 'Bloqueado',
          onPressed: null,
        ),
      ));

      await tester.tap(find.text('Bloqueado'));
      await tester.pumpAndSettle();
      expect(clicked, isFalse);
    });

    testWidgets('TFButton no estado loading exibe spinner e impede múltiplos cliques', (tester) async {
      bool clicked = false;
      await tester.pumpWidget(createTestableWidget(
        child: TFButton(
          label: 'Processando',
          loading: true,
          onPressed: () => clicked = true,
        ),
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Processando'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(clicked, isFalse);
    });

    testWidgets('TFButton funciona nos três temas (Light, Dark, Axia)', (tester) async {
      for (final theme in [TaskFlowTheme.light(), TaskFlowTheme.dark(), TaskFlowTheme.axia()]) {
        await tester.pumpWidget(createTestableWidget(
          theme: theme,
          child: TFButton(
            label: 'Ação Temática',
            variant: TFButtonVariant.primary,
            onPressed: () {},
          ),
        ));
        expect(find.text('Ação Temática'), findsOneWidget);
      }
    });

    // 2. TFIconButton
    testWidgets('TFIconButton renderiza tooltip obrigatório e responde a cliques', (tester) async {
      bool clicked = false;
      await tester.pumpWidget(createTestableWidget(
        child: TFIconButton(
          icon: TFIcons.edit,
          tooltip: 'Editar Tarefa',
          onPressed: () => clicked = true,
        ),
      ));

      expect(find.byIcon(TFIcons.edit), findsOneWidget);
      expect(find.byType(Tooltip), findsOneWidget);

      await tester.tap(find.byIcon(TFIcons.edit));
      await tester.pumpAndSettle();
      expect(clicked, isTrue);
    });

    // 3. TFStatusBadge
    testWidgets('TFStatusBadge renderiza label, ícone e severidades sem erro', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        child: const TFStatusBadge(
          label: 'Em Andamento',
          severity: TFStatusSeverity.info,
          icon: TFIcons.sync,
        ),
      ));

      expect(find.text('Em Andamento'), findsOneWidget);
      expect(find.byIcon(TFIcons.sync), findsOneWidget);
    });

    // 4. TFTextField
    testWidgets('TFTextField renderiza label, hint, digita texto e exibe erro', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(createTestableWidget(
        child: TFTextField(
          controller: controller,
          label: 'Descrição da Demanda',
          hint: 'Informe os detalhes',
          required: true,
          errorText: 'Campo obrigatório',
        ),
      ));

      expect(find.text('Descrição da Demanda'), findsOneWidget);
      expect(find.text('*'), findsOneWidget);
      expect(find.text('Campo obrigatório'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'Manutenção preventiva');
      expect(controller.text, equals('Manutenção preventiva'));
    });

    // 5. TFCard
    testWidgets('TFCard renderiza conteúdo e suporta clique na variante interativa', (tester) async {
      bool clicked = false;
      await tester.pumpWidget(createTestableWidget(
        child: TFCard(
          variant: TFCardVariant.interactive,
          onTap: () => clicked = true,
          child: const Text('Conteúdo do Card'),
        ),
      ));

      expect(find.text('Conteúdo do Card'), findsOneWidget);
      await tester.tap(find.text('Conteúdo do Card'));
      await tester.pumpAndSettle();
      expect(clicked, isTrue);
    });

    // 6. TFPageHeader
    testWidgets('TFPageHeader renderiza título, subtítulo e ações', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        child: TFPageHeader(
          title: 'Ordens de Manutenção',
          subtitle: 'Visão operacional SAP',
          primaryAction: TFButton(
            label: 'Nova Ordem',
            onPressed: () {},
          ),
        ),
      ));

      expect(find.text('Ordens de Manutenção'), findsOneWidget);
      expect(find.text('Visão operacional SAP'), findsOneWidget);
      expect(find.text('Nova Ordem'), findsOneWidget);
    });

    // 7. TFEmptyState
    testWidgets('TFEmptyState renderiza ícone, título, descrição e botão de ação', (tester) async {
      bool actionTriggered = false;
      await tester.pumpWidget(createTestableWidget(
        child: TFEmptyState(
          icon: TFIcons.search,
          title: 'Nenhum registro encontrado',
          description: 'Ajuste os filtros de busca para encontrar atividades.',
          action: TFButton(
            label: 'Limpar Filtros',
            onPressed: () => actionTriggered = true,
          ),
        ),
      ));

      expect(find.text('Nenhum registro encontrado'), findsOneWidget);
      expect(find.text('Ajuste os filtros de busca para encontrar atividades.'), findsOneWidget);
      expect(find.byIcon(TFIcons.search), findsOneWidget);

      await tester.tap(find.text('Limpar Filtros'));
      await tester.pumpAndSettle();
      expect(actionTriggered, isTrue);
    });

    // 8. TFLoading
    testWidgets('TFLoading renderiza spinner e mensagem de carregamento', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        child: const TFLoading(
          message: 'Carregando dados...',
          mode: TFLoadingMode.section,
        ),
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Carregando dados...'), findsOneWidget);
    });

    // 9. TFSyncIndicator
    testWidgets('TFSyncIndicator renderiza estados de sincronização', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        child: const TFSyncIndicator(
          state: TFSyncState.synced,
          label: 'Totalmente Sincronizado',
        ),
      ));

      expect(find.text('Totalmente Sincronizado'), findsOneWidget);
      expect(find.byIcon(TFIcons.success), findsOneWidget);
    });
  });
}
