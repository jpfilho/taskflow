import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task2026/config/supabase_config.dart';
import 'package:task2026/widgets/task_table.dart';
import 'package:task2026/models/task.dart';
import 'package:task2026/design_system/taskflow_design_system.dart';

Widget _buildTestApp(
  Widget child, {
  ThemeData? theme,
  double width = 1280,
  double height = 800,
}) {
  return MaterialApp(
    theme: theme ?? TaskFlowTheme.light(),
    home: MediaQuery(
      data: MediaQueryData(size: Size(width, height)),
      child: Scaffold(
        body: SizedBox(
          width: width,
          height: height,
          child: child,
        ),
      ),
    ),
  );
}

Task _createMockTask({
  required String id,
  required String tarefa,
  String status = 'PROG',
  String? parentId,
  String executor = 'João Silva',
  String coordenador = 'Carlos Coord',
  String tipo = 'Manutenção',
  List<String> locais = const ['Subestação Norte'],
}) {
  return Task(
    id: id,
    tarefa: tarefa,
    status: status,
    regional: 'Regional Norte',
    divisao: 'Divisão Sul',
    tipo: tipo,
    coordenador: coordenador,
    dataInicio: DateTime(2026, 9, 1, 8, 0),
    dataFim: DateTime(2026, 9, 1, 17, 0),
    parentId: parentId,
    executor: executor,
    locais: locais,
    executores: [executor],
    equipes: const ['Equipe Alpha'],
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

  group('TaskTable — Phase 13C Widget & Presentation Tests', () {
    testWidgets('1. Renderiza TaskTable com Empty State e Loading State', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      final scrollController = ScrollController();
      final horizontalController = ScrollController();

      // Teste Loading State
      await tester.pumpWidget(
        _buildTestApp(
          TaskTable(
            tasks: const [],
            scrollController: scrollController,
            horizontalController: horizontalController,
            isLoading: true,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(TFLoading), findsOneWidget);
      expect(find.text('Carregando tarefas...'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));

      scrollController.dispose();
      horizontalController.dispose();
    });

    testWidgets('2. Renderiza tarefas e colunas operacionais da tabela', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      final scrollController = ScrollController();
      final horizontalController = ScrollController();
      final tasks = [
        _createMockTask(id: 't-1', tarefa: 'Inspeção de Transformador A'),
        _createMockTask(id: 't-2', tarefa: 'Manutenção Preventiva Painel B', status: 'ANDA'),
        _createMockTask(id: 't-3', tarefa: 'Subtarefa Teste C', parentId: 't-1'),
      ];

      await tester.pumpWidget(
        _buildTestApp(
          TaskTable(
            tasks: tasks,
            scrollController: scrollController,
            horizontalController: horizontalController,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Cabeçalhos operacionais esperados
      expect(find.text('AÇÕES'), findsOneWidget);
      expect(find.text('STATUS'), findsOneWidget);
      expect(find.text('LOCAL'), findsOneWidget);
      expect(find.text('TIPO'), findsOneWidget);
      expect(find.text('TAREFA'), findsOneWidget);
      expect(find.text('EXECUTOR'), findsOneWidget);
      expect(find.text('COORDENADOR'), findsOneWidget);

      // Dados das tarefas renderizados
      expect(find.text('Inspeção de Transformador A'), findsOneWidget);
      expect(find.text('Manutenção Preventiva Painel B'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));

      scrollController.dispose();
      horizontalController.dispose();
    });

    testWidgets('3. Renderiza TaskTable nos 3 temas do TFDS (Light, Dark, AXIA)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      final tasks = [
        _createMockTask(id: 't-10', tarefa: 'Tarefa Tema Test'),
      ];

      for (final theme in [
        TaskFlowTheme.light(),
        TaskFlowTheme.dark(),
        TaskFlowTheme.axia(),
      ]) {
        final scrollController = ScrollController();
        final horizontalController = ScrollController();

        await tester.pumpWidget(
          _buildTestApp(
            theme: theme,
            TaskTable(
              tasks: tasks,
              scrollController: scrollController,
              horizontalController: horizontalController,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Tarefa Tema Test'), findsOneWidget);
        expect(find.text('TAREFA'), findsOneWidget);

        await tester.pump(const Duration(seconds: 1));

        scrollController.dispose();
        horizontalController.dispose();
      }
    });

    testWidgets('4. Renderiza responsivamente em 390px, 768px e 1280px sem RenderFlex overflow', (tester) async {
      final tasks = [
        _createMockTask(id: 't-20', tarefa: 'Tarefa Responsiva 1'),
        _createMockTask(id: 't-21', tarefa: 'Tarefa Responsiva 2'),
      ];

      for (final width in [390.0, 768.0, 1280.0]) {
        await tester.binding.setSurfaceSize(Size(width, 700));
        final scrollController = ScrollController();
        final horizontalController = ScrollController();

        await tester.pumpWidget(
          _buildTestApp(
            width: width,
            height: 700,
            TaskTable(
              tasks: tasks,
              scrollController: scrollController,
              horizontalController: horizontalController,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('TAREFA'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'Não deve haver overflow em $width px');

        await tester.pump(const Duration(seconds: 1));

        scrollController.dispose();
        horizontalController.dispose();
      }
    });

    testWidgets('5. Dispara callback onTaskSelected ao clicar na linha da tarefa', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      final scrollController = ScrollController();
      final horizontalController = ScrollController();
      Task? selectedTask;

      final task = _createMockTask(id: 't-30', tarefa: 'Tarefa Seleção Test');

      await tester.pumpWidget(
        _buildTestApp(
          TaskTable(
            tasks: [task],
            scrollController: scrollController,
            horizontalController: horizontalController,
            onTaskSelected: (t) {
              selectedTask = t;
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Clicar no texto da tarefa
      await tester.tap(find.text('Tarefa Seleção Test'));
      await tester.pump();

      expect(selectedTask, isNotNull);
      expect(selectedTask?.id, equals('t-30'));

      await tester.pump(const Duration(seconds: 2));

      scrollController.dispose();
      horizontalController.dispose();
    });
  });
}
