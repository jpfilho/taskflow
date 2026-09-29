import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/design_system/taskflow_design_system.dart';

Widget createTestableWidget(Widget child, {ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? TaskFlowTheme.light(),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('TFSwitch Tests', () {
    testWidgets('TFSwitch renderiza nos estados ON e OFF e dispara onChanged ao clicar', (tester) async {
      bool currentValue = false;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return createTestableWidget(
              TFSwitch(
                value: currentValue,
                label: 'Status da Tarefa',
                onChanged: (val) {
                  setState(() => currentValue = val);
                },
              ),
            );
          },
        ),
      );
      await tester.pump();

      expect(find.text('Status da Tarefa'), findsOneWidget);
      expect(currentValue, isFalse);

      // Clicar no switch
      await tester.tap(find.byType(TFSwitch));
      await tester.pumpAndSettle();

      expect(currentValue, isTrue);
    });

    testWidgets('TFSwitch desabilitado não dispara onChanged', (tester) async {
      bool wasCalled = false;

      await tester.pumpWidget(
        createTestableWidget(
          TFSwitch(
            value: false,
            enabled: false,
            label: 'Bloqueado',
            onChanged: (_) {
              wasCalled = true;
            },
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(TFSwitch));
      await tester.pumpAndSettle();

      expect(wasCalled, isFalse);
    });

    testWidgets('TFSwitch funciona nos 3 temas do TFDS (Light, Dark, AXIA)', (tester) async {
      for (final theme in [TaskFlowTheme.light(), TaskFlowTheme.dark(), TaskFlowTheme.axia()]) {
        await tester.pumpWidget(
          createTestableWidget(
            TFSwitch(
              value: true,
              label: 'Tema Teste',
              onChanged: (_) {},
            ),
            theme: theme,
          ),
        );
        await tester.pump();

        expect(find.text('Tema Teste'), findsOneWidget);
      }
    });
  });

  group('TFModalDialog Tests', () {
    testWidgets('TFModalDialog renderiza título, subtítulo, conteúdo e ações', (tester) async {
      bool primaryClicked = false;
      bool secondaryClicked = false;

      await tester.pumpWidget(
        createTestableWidget(
          TFModalDialog(
            title: 'Excluir Item',
            subtitle: 'Confirmação necessária',
            severity: TFDialogSeverity.danger,
            icon: TFIcons.delete,
            content: const Text('Tem certeza que deseja apagar?'),
            primaryAction: TFButton(
              label: 'Excluir',
              variant: TFButtonVariant.danger,
              onPressed: () => primaryClicked = true,
            ),
            secondaryAction: TFButton(
              label: 'Cancelar',
              variant: TFButtonVariant.ghost,
              onPressed: () => secondaryClicked = true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Excluir Item'), findsOneWidget);
      expect(find.text('Confirmação necessária'), findsOneWidget);
      expect(find.text('Tem certeza que deseja apagar?'), findsOneWidget);
      expect(find.text('Excluir'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);

      await tester.tap(find.text('Excluir'));
      await tester.pump();
      expect(primaryClicked, isTrue);

      await tester.tap(find.text('Cancelar'));
      await tester.pump();
      expect(secondaryClicked, isTrue);
    });

    testWidgets('TFModalDialog adapta largura conforme TFDialogSize', (tester) async {
      for (final size in [TFDialogSize.small, TFDialogSize.medium, TFDialogSize.large]) {
        await tester.pumpWidget(
          createTestableWidget(
            TFModalDialog(
              title: 'Teste Tamanho',
              size: size,
              content: const Text('Conteúdo do modal'),
            ),
          ),
        );
        await tester.pump();
        expect(find.text('Teste Tamanho'), findsOneWidget);
      }
    });
  });

  group('TFDataTable Tests', () {
    final sampleItems = ['Item Alpha', 'Item Beta', 'Item Gamma'];

    List<TFDataColumn<String>> testColumns = [
      TFDataColumn<String>.text(
        id: 'nome',
        title: 'Nome',
        cellBuilder: (context, item) => Text(item),
      ),
      TFDataColumn<String>(
        id: 'acoes',
        label: const Text('Ações'),
        width: 80,
        cellBuilder: (context, item) => TFIconButton(
          icon: TFIcons.delete,
          tooltip: 'Excluir $item',
          onPressed: () {},
        ),
      ),
    ];

    testWidgets('TFDataTable renderiza cabeçalho, colunas e dados', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          TFDataTable<String>(
            columns: testColumns,
            items: sampleItems,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Nome'), findsOneWidget);
      expect(find.text('Ações'), findsOneWidget);
      expect(find.text('Item Alpha'), findsOneWidget);
      expect(find.text('Item Beta'), findsOneWidget);
      expect(find.text('Item Gamma'), findsOneWidget);
      expect(find.byType(TFIconButton), findsNWidgets(3));
    });

    testWidgets('TFDataTable exibe estado de carregamento quando isLoading é true', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          TFDataTable<String>(
            columns: testColumns,
            items: const [],
            isLoading: true,
            loadingMessage: 'Carregando linhas...',
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(TFLoading), findsOneWidget);
      expect(find.text('Carregando linhas...'), findsOneWidget);
    });

    testWidgets('TFDataTable exibe empty state quando itens estão vazios', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          TFDataTable<String>(
            columns: testColumns,
            items: const [],
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(TFEmptyState), findsOneWidget);
      expect(find.text('Nenhum registro encontrado'), findsOneWidget);
    });

    testWidgets('TFDataTable suporta alternância de densidades', (tester) async {
      for (final density in [TFDensityMode.comfortable, TFDensityMode.compact, TFDensityMode.dense]) {
        await tester.pumpWidget(
          createTestableWidget(
            TFDataTable<String>(
              columns: testColumns,
              items: sampleItems,
              densityMode: density,
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Item Alpha'), findsOneWidget);
      }
    });

    testWidgets('TFDataTable renderiza em Light, Dark e AXIA sem falhas', (tester) async {
      for (final theme in [TaskFlowTheme.light(), TaskFlowTheme.dark(), TaskFlowTheme.axia()]) {
        await tester.pumpWidget(
          createTestableWidget(
            TFDataTable<String>(
              columns: testColumns,
              items: sampleItems,
            ),
            theme: theme,
          ),
        );
        await tester.pump();

        expect(find.text('Item Alpha'), findsOneWidget);
      }
    });
  });
}
