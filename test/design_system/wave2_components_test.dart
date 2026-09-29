import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/design_system/taskflow_design_system.dart';

Widget createTestableWidget({required Widget child, ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? TaskFlowTheme.light(),
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: child,
      ),
    ),
  );
}

void main() {
  group('TFDropdown Tests', () {
    testWidgets('renderiza label, hint e opções', (tester) async {
      String? selectedValue;

      await tester.pumpWidget(
        createTestableWidget(
          child: TFDropdown<String>(
            label: 'Regional',
            hint: 'Selecione a regional',
            value: selectedValue,
            items: const ['Recife', 'Fortaleza', 'Salvador'],
            displayText: (item) => item,
            onChanged: (val) => selectedValue = val,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Regional'), findsOneWidget);
      expect(find.text('Selecione a regional'), findsOneWidget);
    });

    testWidgets('abre menu e seleciona valor disparando onChanged', (tester) async {
      String? selectedValue;

      await tester.pumpWidget(
        createTestableWidget(
          child: StatefulBuilder(
            builder: (context, setState) {
              return TFDropdown<String>(
                label: 'Regional',
                value: selectedValue,
                items: const ['Recife', 'Fortaleza', 'Salvador'],
                displayText: (item) => item,
                onChanged: (val) {
                  setState(() {
                    selectedValue = val;
                  });
                },
              );
            },
          ),
        ),
      );
      await tester.pump();

      // Clicar no dropdown para abrir
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();

      // Opção Recife deve estar visível no menu
      expect(find.text('Recife').last, findsOneWidget);
      await tester.tap(find.text('Recife').last);
      await tester.pumpAndSettle();

      expect(selectedValue, equals('Recife'));
    });

    testWidgets('exibe indicador de loading quando isLoading = true', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: TFDropdown<String>(
            label: 'Regional',
            value: null,
            items: const [],
            isLoading: true,
            displayText: (item) => item,
            onChanged: (val) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Carregando opções...'), findsOneWidget);
    });

    testWidgets('renderiza nos 3 temas do TFDS (Light, Dark, AXIA)', (tester) async {
      for (final theme in [TaskFlowTheme.light(), TaskFlowTheme.dark(), TaskFlowTheme.axia()]) {
        await tester.pumpWidget(
          createTestableWidget(
            theme: theme,
            child: TFDropdown<String>(
              label: 'Regional',
              value: 'Recife',
              items: const ['Recife', 'Fortaleza'],
              displayText: (item) => item,
              onChanged: (val) {},
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Regional'), findsOneWidget);
        expect(find.text('Recife'), findsOneWidget);
      }
    });

    testWidgets('suporta botão de limpar seleção', (tester) async {
      String? selectedValue = 'Recife';

      await tester.pumpWidget(
        createTestableWidget(
          child: StatefulBuilder(
            builder: (context, setState) {
              return TFDropdown<String>(
                label: 'Regional',
                value: selectedValue,
                items: const ['Recife', 'Fortaleza'],
                showClearButton: true,
                displayText: (item) => item,
                onChanged: (val) {
                  setState(() {
                    selectedValue = val;
                  });
                },
              );
            },
          ),
        ),
      );
      await tester.pump();

      expect(find.byTooltip('Limpar seleção'), findsOneWidget);
      await tester.tap(find.byTooltip('Limpar seleção'));
      await tester.pump();

      expect(selectedValue, isNull);
    });
  });

  group('TFFormDialog Tests', () {
    testWidgets('renderiza título, subtítulo e ações', (tester) async {
      await tester.pumpWidget(
        createTestableWidget(
          child: TFFormDialog(
            title: 'Nova Regional',
            subtitle: 'Cadastro de base territorial',
            onCancel: () {},
            onSave: () {},
            child: const Text('Conteúdo do formulário'),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Nova Regional'), findsOneWidget);
      expect(find.text('Cadastro de base territorial'), findsOneWidget);
      expect(find.text('Conteúdo do formulário'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Salvar'), findsOneWidget);
    });

    testWidgets('dispara onCancel e onSave ao clicar nos botões', (tester) async {
      bool cancelCalled = false;
      bool saveCalled = false;

      await tester.pumpWidget(
        createTestableWidget(
          child: TFFormDialog(
            title: 'Nova Regional',
            onCancel: () => cancelCalled = true,
            onSave: () => saveCalled = true,
            child: const SizedBox(),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Cancelar'));
      await tester.pump();
      expect(cancelCalled, isTrue);

      await tester.tap(find.text('Salvar'));
      await tester.pump();
      expect(saveCalled, isTrue);
    });

    testWidgets('exibe loading e bloqueia cliques quando isSaving = true', (tester) async {
      bool saveCalled = false;

      await tester.pumpWidget(
        createTestableWidget(
          child: TFFormDialog(
            title: 'Nova Regional',
            isSaving: true,
            onCancel: () {},
            onSave: () => saveCalled = true,
            child: const SizedBox(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Salvar'));
      await tester.pump();
      expect(saveCalled, isFalse);
    });

    testWidgets('renderiza nos 3 temas do TFDS (Light, Dark, AXIA)', (tester) async {
      for (final theme in [TaskFlowTheme.light(), TaskFlowTheme.dark(), TaskFlowTheme.axia()]) {
        await tester.pumpWidget(
          createTestableWidget(
            theme: theme,
            child: TFFormDialog(
              title: 'Nova Regional',
              onCancel: () {},
              onSave: () {},
              child: const Text('Form'),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Nova Regional'), findsOneWidget);
      }
    });
  });
}
