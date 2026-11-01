import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/design_system/theme/taskflow_theme_extension.dart';
import 'package:task2026/models/backlog_macro_models.dart';
import 'package:task2026/models/nota_sap_grupo.dart';
import 'package:task2026/services/nota_sap_backlog_service.dart';
import 'package:task2026/models/task.dart';
import 'package:task2026/models/task_create_result.dart';
import 'package:task2026/services/nota_sap_service.dart';
import 'package:task2026/services/task_service.dart';
import 'package:task2026/widgets/planejamento_macro/planejamento_macro_view.dart';

// Mock do NotaSapBacklogService para testes de UI
class MockNotaSapBacklogService extends NotaSapBacklogService {
  final BacklogMacroResult mockResult;
  final List<NotaSapGrupoPrevisaoHist> mockHistorico;

  MockNotaSapBacklogService({
    required this.mockResult,
    this.mockHistorico = const [],
  });

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
    return mockHistorico;
  }
}

class MockTaskServiceForPlanejamento implements TaskService {
  Task? lastCreatedTask;

  @override
  Future<TaskCreateResult> createTaskWithResult(Task task) async {
    lastCreatedTask = task;
    return TaskCreateResult(
      task: task,
      taskCriada: true,
      notasSolicitadas: const ['11565867'],
      notasVinculadas: const ['11565867'],
      notasComFalha: const [],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
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

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('1. PlanejamentoMacroView exibe cabeçalho, KPIs e blocos de meses', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final n1 = const BacklogNotaItem(
      id: 'n1',
      nota: '11599101',
      descricao: 'Vazamento de SF6 em disjuntor',
      estimativaHoras: 14.0,
      tasks: [BacklogTaskInfo(id: 't1', status: 'PROG')],
    );
    final n2 = const BacklogNotaItem(
      id: 'n2',
      nota: '11565867',
      descricao: 'Revisão geral de comando',
      estimativaHoras: 8.0,
    );

    final grupoNov = BacklogGrupoItem(
      id: 'g1',
      nome: 'Intervenção DJ 12T2',
      motivo: 'Preventiva anual',
      mesProgramacaoPrevisto: 11,
      anoProgramacaoPrevisto: 2026,
      statusGrupo: 'ativo',
      notas: [n1, n2],
    );

    final mensalNov = BacklogMensalResumo(
      mes: 11,
      ano: 2026,
      grupos: [grupoNov],
    );

    final mockResult = BacklogMacroResult(
      global: const BacklogGlobalResumo(
        gruposAtivos: 1,
        gruposComPrevisao: 1,
        gruposSemPrevisao: 0,
        gruposUltrapassados: 0,
        notasEmGrupos: 2,
        notasProgramadas: 1,
        notasPendentes: 1,
        notasUnicas: 2,
        temAnomaliaIntegridade: false,
      ),
      meses: [mensalNov],
      semPrevisao: null,
      geradoEm: DateTime.now(),
      filtrosAplicados: const BacklogFiltro(),
      todosGrupos: [grupoNov],
    );

    final mockService = MockNotaSapBacklogService(mockResult: mockResult);

    await tester.pumpWidget(createWidgetUnderTest(mockService));
    await tester.pumpAndSettle();

    // Validar Cabeçalho
    expect(find.text('Planejamento Macro'), findsOneWidget);
    expect(find.text('Grupos de Notas SAP organizados por previsão de programação mensal.'), findsOneWidget);

    // Validar KPIs Globais
    expect(find.text('Grupos Ativos'), findsOneWidget);
    expect(find.text('Com Previsão'), findsOneWidget);
    expect(find.text('Sem Previsão'), findsOneWidget);
    expect(find.text('Notas Pendentes'), findsOneWidget);

    // Validar Mês e Grupo
    expect(find.text('NOVEMBRO / 2026'), findsOneWidget);
    expect(find.text('Intervenção DJ 12T2'), findsOneWidget);
    expect(find.text('Parcialmente programado'), findsOneWidget);
    expect(find.text('Soma das estimativas individuais: 22.0 h (Pendentes: 8.0 h)'), findsOneWidget);

    // Fazer scroll até o grupo e expandir
    final grupoFinder = find.byKey(const Key('grupo_g1'));
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

    expect(find.text('11599101'), findsOneWidget);
    expect(find.text('11565867'), findsOneWidget);
    expect(find.text('Programar Pendentes (1)'), findsOneWidget);
  });

  testWidgets('2. PlanejamentoMacroView exibe estado de grupo 100% programado sem botão programar pendentes', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final n1 = const BacklogNotaItem(
      id: 'n1',
      nota: '11599101',
      descricao: 'Vazamento de SF6 em disjuntor',
      tasks: [BacklogTaskInfo(id: 't1', status: 'PROG')],
    );

    final grupoTotal = BacklogGrupoItem(
      id: 'g1',
      nome: 'Grupo 100%',
      mesProgramacaoPrevisto: 12,
      anoProgramacaoPrevisto: 2026,
      statusGrupo: 'ativo',
      notas: [n1],
    );

    final mensalDez = BacklogMensalResumo(
      mes: 12,
      ano: 2026,
      grupos: [grupoTotal],
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
      meses: [mensalDez],
      semPrevisao: null,
      geradoEm: DateTime.now(),
      filtrosAplicados: const BacklogFiltro(),
      todosGrupos: [grupoTotal],
    );

    final mockService = MockNotaSapBacklogService(mockResult: mockResult);

    await tester.pumpWidget(createWidgetUnderTest(mockService));
    await tester.pumpAndSettle();

    expect(find.text('Programação concluída'), findsOneWidget);

    // Expandir
    final grupoFinder = find.byKey(const Key('grupo_g1'));
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

    // Botão de programar pendentes NÃO deve existir
    expect(find.textContaining('Programar Pendentes'), findsNothing);
  });

  testWidgets('4. PlanejamentoMacroView aceita taskService injetado e renderiza sem erros', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final mockBacklog = MockNotaSapBacklogService(
      mockResult: BacklogMacroResult(
        global: const BacklogGlobalResumo(
          gruposAtivos: 0,
          gruposComPrevisao: 0,
          gruposSemPrevisao: 0,
          gruposUltrapassados: 0,
          notasEmGrupos: 0,
          notasProgramadas: 0,
          notasPendentes: 0,
          notasUnicas: 0,
          temAnomaliaIntegridade: false,
        ),
        meses: [],
        semPrevisao: null,
        geradoEm: DateTime.now(),
        filtrosAplicados: const BacklogFiltro(),
        todosGrupos: const [],
      ),
    );
    final mockTask = MockTaskServiceForPlanejamento();

    await tester.pumpWidget(createWidgetUnderTest(mockBacklog, taskService: mockTask));
    await tester.pumpAndSettle();

    expect(find.text('Planejamento Macro'), findsOneWidget);
    expect(find.byType(PlanejamentoMacroView), findsOneWidget);
  });
}
