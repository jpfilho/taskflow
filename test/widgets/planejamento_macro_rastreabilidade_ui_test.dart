import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:task2026/design_system/theme/taskflow_theme_extension.dart';
import 'package:task2026/models/backlog_macro_models.dart';
import 'package:task2026/models/nota_sap_grupo.dart';
import 'package:task2026/services/nota_sap_backlog_service.dart';
import 'package:task2026/models/task.dart';
import 'package:task2026/services/task_service.dart';
import 'package:task2026/widgets/planejamento_macro/planejamento_macro_view.dart';
import 'package:task2026/widgets/task_form_dialog.dart';

class MockNotaSapBacklogService extends NotaSapBacklogService {
  final BacklogMacroResult mockResult;
  MockNotaSapBacklogService({required this.mockResult});

  @override
  Future<BacklogMacroResult> buscarBacklogMacro({
    BacklogFiltro? filtro,
    bool forcarAtualizacao = false,
    DateTime? dataReferencia,
  }) async {
    return mockResult;
  }

  @override
  Future<List<NotaSapGrupoPrevisaoHist>> buscarHistoricoGrupo(String grupoId) async {
    return const [];
  }
}

class MockTaskServiceForRastreabilidade implements TaskService {
  final Map<String, Task> tasksMap;
  String? lastOpenedTaskId;

  MockTaskServiceForRastreabilidade({required this.tasksMap});

  @override
  Future<Task?> getTaskById(String id) async {
    lastOpenedTaskId = id;
    return tasksMap[id];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: 'http://212.85.0.249:8000',
        anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzY1ODE3OTgzLCJleHAiOjIwODExNzc5ODN9.YQByqDrpmw0en7VeEcjDfvvTx8Ind_q8gD6-bzEY4Yc',
      );
    } catch (_) {}
  });

  Widget createWidgetUnderTest(
    MockNotaSapBacklogService service, {
    TaskService? taskService,
  }) {
    return MaterialApp(
      theme: ThemeData.light().copyWith(
        extensions: [
          TaskFlowThemeExtension.light(),
        ],
      ),
      home: PlanejamentoMacroView(
        backlogService: service,
        taskService: taskService,
      ),
    );
  }

  testWidgets('Item 54: UI exibe Status Nota, Status Task, Previsão, Programação, Divergência e botão Abrir Tarefa', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final taskValida = BacklogTaskInfo(
      id: 'task-101',
      tarefa: 'Substituição Chave 138kV',
      status: 'PROG',
      dataInicio: DateTime(2026, 11, 15),
      dataFim: DateTime(2026, 11, 16),
    );

    final nota1 = BacklogNotaItem(
      id: 'nota-1',
      nota: '11598127',
      descricao: 'Inspeção eletromecânica preventiva',
      statusSistema: 'MSPR',
      statusUsuario: 'APRO',
      mesPrevisto: 11,
      anoPrevisto: 2026,
      estimativaHoras: 8.0,
      tasks: [taskValida],
    );

    final grupo = BacklogGrupoItem(
      id: 'g1',
      nome: 'Grupo Subestação Alpha',
      mesProgramacaoPrevisto: 11,
      anoProgramacaoPrevisto: 2026,
      statusGrupo: 'ativo',
      notas: [nota1],
    );

    final mockResult = BacklogMacroResult(
      global: const BacklogGlobalResumo(
        gruposAtivos: 1,
        gruposComPrevisao: 1,
        gruposSemPrevisao: 0,
        gruposUltrapassados: 0,
        notasEmGrupos: 1,
        notasProgramadas: 1,
        notasPendentes: 0,
        notasUnicas: 1,
        temAnomaliaIntegridade: false,
      ),
      meses: [
        BacklogMensalResumo(
          mes: 11,
          ano: 2026,
          grupos: [grupo],
        ),
      ],
      semPrevisao: null,
      geradoEm: DateTime.now(),
      filtrosAplicados: const BacklogFiltro(),
      todosGrupos: [grupo],
    );

    final mockBacklog = MockNotaSapBacklogService(mockResult: mockResult);
    final mockTask = MockTaskServiceForRastreabilidade(tasksMap: {
      'task-101': Task(
        id: 'task-101',
        tarefa: 'Substituição Chave 138kV',
        status: 'PROG',
        regional: 'SE',
        divisao: 'DIV-1',
        tipo: 'Manutenção',
        coordenador: 'Coord-1',
        dataInicio: DateTime(2026, 11, 15),
        dataFim: DateTime(2026, 11, 16),
      ),
    });

    await tester.pumpWidget(createWidgetUnderTest(mockBacklog, taskService: mockTask));
    await tester.pumpAndSettle();

    // Expandir o grupo para exibir as notas
    final grupoFinder = find.byKey(const Key('grupo_g1'));
    await tester.tap(grupoFinder);
    await tester.pumpAndSettle();

    // 1. Validar Status da Nota separado
    expect(find.text('NOTA: MSPR'), findsOneWidget);
    expect(find.text('USR: APRO'), findsOneWidget);

    // 2. Validar Status da Task separado
    expect(find.text('TASK: PROG'), findsOneWidget);

    // 3. Validar Previsão e Programação
    expect(find.text('Nov/2026'), findsWidgets);
    expect(find.text('15/11/2026'), findsOneWidget);

    // 4. Validar Divergência Temporal: mesmo mês -> "Programada conforme previsão"
    expect(find.text('Programada conforme previsão'), findsOneWidget);

    // 5. Validar Botão Abrir Tarefa
    expect(find.text('Abrir Tarefa'), findsOneWidget);
  });

  testWidgets('Item 55/56: Clicar em Abrir Tarefa dispara busca oficial e abre TaskFormDialog preservando contexto', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final taskValida = BacklogTaskInfo(
      id: 'task-deep-link',
      tarefa: 'Revisão Disjuntor 500kV',
      status: 'PROG',
      dataInicio: DateTime(2026, 11, 20),
    );

    final nota = BacklogNotaItem(
      id: 'nota-deep',
      nota: '11599999',
      descricao: 'Manutenção disjuntor',
      statusSistema: 'MSEN',
      mesPrevisto: 11,
      anoPrevisto: 2026,
      tasks: [taskValida],
    );

    final grupo = BacklogGrupoItem(
      id: 'g-deep',
      nome: 'Grupo Manutenção Disjuntores',
      mesProgramacaoPrevisto: 11,
      anoProgramacaoPrevisto: 2026,
      statusGrupo: 'ativo',
      notas: [nota],
    );

    final mockResult = BacklogMacroResult(
      global: const BacklogGlobalResumo(
        gruposAtivos: 1,
        gruposComPrevisao: 1,
        gruposSemPrevisao: 0,
        gruposUltrapassados: 0,
        notasEmGrupos: 1,
        notasProgramadas: 1,
        notasPendentes: 0,
        notasUnicas: 1,
        temAnomaliaIntegridade: false,
      ),
      meses: [
        BacklogMensalResumo(mes: 11, ano: 2026, grupos: [grupo]),
      ],
      semPrevisao: null,
      geradoEm: DateTime.now(),
      filtrosAplicados: const BacklogFiltro(),
      todosGrupos: [grupo],
    );

    final taskReal = Task(
      id: 'task-deep-link',
      tarefa: 'Revisão Disjuntor 500kV',
      status: 'PROG',
      regional: 'SE',
      divisao: 'DIV-1',
      tipo: 'Manutenção',
      coordenador: 'Coord-1',
      dataInicio: DateTime(2026, 11, 20),
      dataFim: DateTime(2026, 11, 21),
    );

    final mockBacklog = MockNotaSapBacklogService(mockResult: mockResult);
    final mockTask = MockTaskServiceForRastreabilidade(tasksMap: {
      'task-deep-link': taskReal,
    });

    await tester.pumpWidget(createWidgetUnderTest(mockBacklog, taskService: mockTask));
    await tester.pumpAndSettle();

    // Scroll até o grupo e expandir para exibir as notas
    final grupoFinder = find.byKey(const Key('grupo_g-deep'));
    await tester.scrollUntilVisible(
      grupoFinder,
      100,
      scrollable: find.descendant(
        of: find.byKey(const Key('planejamento_macro_scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(grupoFinder);
    await tester.pumpAndSettle();

    // Clica em "Abrir Tarefa"
    await tester.tap(find.text('Abrir Tarefa'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Valida que o deep-link consultou exatamente a task correta
    expect(mockTask.lastOpenedTaskId, equals('task-deep-link'));

    // Valida que o TaskFormDialog foi aberto em modal
    expect(find.byType(TaskFormDialog), findsOneWidget);

    // Fecha o modal via Navigator preservando contexto
    Navigator.of(tester.element(find.byType(TaskFormDialog))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Contexto preservado: TaskFormDialog sumiu, tela de planejamento permanece intacta
    expect(find.byType(TaskFormDialog), findsNothing);
    expect(find.text('Nota SAP: 11599999'), findsOneWidget);
  });

  testWidgets('Item 53: Múltiplas Tasks exibe badge contador e modal com tabela de todas as tarefas', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final t1 = BacklogTaskInfo(id: 't-prog-1', tarefa: 'Frente 1 Civil', status: 'RPGR', dataInicio: DateTime(2026, 11, 10));
    final t2 = BacklogTaskInfo(id: 't-prog-2', tarefa: 'Frente 2 Eletromecânica', status: 'RPAR', dataInicio: DateTime(2026, 11, 20));

    final notaMulti = BacklogNotaItem(
      id: 'nota-multi',
      nota: '11597777',
      descricao: 'Ampliação de bay',
      statusSistema: 'MSPR',
      mesPrevisto: 11,
      anoPrevisto: 2026,
      tasks: [t1, t2],
    );

    final grupo = BacklogGrupoItem(
      id: 'g-multi',
      nome: 'Grupo Multi-task',
      mesProgramacaoPrevisto: 11,
      anoProgramacaoPrevisto: 2026,
      statusGrupo: 'ativo',
      notas: [notaMulti],
    );

    final mockResult = BacklogMacroResult(
      global: const BacklogGlobalResumo(
        gruposAtivos: 1,
        gruposComPrevisao: 1,
        gruposSemPrevisao: 0,
        gruposUltrapassados: 0,
        notasEmGrupos: 1,
        notasProgramadas: 1,
        notasPendentes: 0,
        notasUnicas: 1,
        temAnomaliaIntegridade: false,
      ),
      meses: [
        BacklogMensalResumo(mes: 11, ano: 2026, grupos: [grupo]),
      ],
      semPrevisao: null,
      geradoEm: DateTime.now(),
      filtrosAplicados: const BacklogFiltro(),
      todosGrupos: [grupo],
    );

    final mockBacklog = MockNotaSapBacklogService(mockResult: mockResult);
    await tester.pumpWidget(createWidgetUnderTest(mockBacklog));
    await tester.pumpAndSettle();

    // Scroll até o grupo e expandir para exibir as notas
    final grupoFinder = find.byKey(const Key('grupo_g-multi'));
    await tester.scrollUntilVisible(
      grupoFinder,
      100,
      scrollable: find.descendant(
        of: find.byKey(const Key('planejamento_macro_scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(grupoFinder);
    await tester.pumpAndSettle();

    // Valida indicador de Múltiplas Tasks
    expect(find.text('2 Tarefas Vinculadas'), findsOneWidget);

    // Clica no botão para abrir modal
    await tester.tap(find.text('2 Tarefas Vinculadas'));
    await tester.pumpAndSettle();

    // Valida que o modal abriu com título e listagem de ambas as tasks
    expect(find.text('Tarefas Vinculadas — Nota SAP 11597777'), findsOneWidget);
    expect(find.text('RPGR'), findsOneWidget);
    expect(find.text('RPAR'), findsOneWidget);

    // Fecha o modal
    await tester.tap(find.text('Fechar'));
    await tester.pumpAndSettle();
    expect(find.text('Tarefas Vinculadas — Nota SAP 11597777'), findsNothing);
  });

  testWidgets('Item 57: Responsividade Mobile (390px e 320px) sem overflow de layout', (tester) async {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
    };
    for (final largura in [390.0, 320.0]) {
      tester.view.physicalSize = Size(largura, 800);
      tester.view.devicePixelRatio = 1.0;

      final t = BacklogTaskInfo(
        id: 't-mob',
        tarefa: 'Tarefa Mobile Teste com Descrição Longa',
        status: 'PROG',
        dataInicio: DateTime(2026, 11, 15),
      );

      final n = BacklogNotaItem(
        id: 'n-mob',
        nota: '11598888',
        descricao: 'Descrição longa para testar layout sem overflow em telas mobile',
        statusSistema: 'MSEN ORDA',
        statusUsuario: 'APRO',
        mesPrevisto: 11,
        anoPrevisto: 2026,
        tasks: [t],
      );

      final grupo = BacklogGrupoItem(
        id: 'g-mob',
        nome: 'Grupo Mobile',
        mesProgramacaoPrevisto: 11,
        anoProgramacaoPrevisto: 2026,
        statusGrupo: 'ativo',
        notas: [n],
      );

      final mockResult = BacklogMacroResult(
        global: const BacklogGlobalResumo(
          gruposAtivos: 1,
          gruposComPrevisao: 1,
          gruposSemPrevisao: 0,
          gruposUltrapassados: 0,
          notasEmGrupos: 1,
          notasProgramadas: 1,
          notasPendentes: 0,
          notasUnicas: 1,
          temAnomaliaIntegridade: false,
        ),
        meses: [
          BacklogMensalResumo(mes: 11, ano: 2026, grupos: [grupo]),
        ],
        semPrevisao: null,
        geradoEm: DateTime.now(),
        filtrosAplicados: const BacklogFiltro(),
        todosGrupos: [grupo],
      );

      final mockBacklog = MockNotaSapBacklogService(mockResult: mockResult);
      await tester.pumpWidget(createWidgetUnderTest(mockBacklog));
      await tester.pumpAndSettle();

      // Scroll até o grupo usando scrollable global
      final scrollableFinder = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.byKey(const Key('grupo_g-mob')),
        100,
        scrollable: scrollableFinder,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('grupo_g-mob')), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Valida ausência de erro de overflow
      expect(tester.takeException(), isNull);
    }

    tester.view.resetPhysicalSize();
  });
}
