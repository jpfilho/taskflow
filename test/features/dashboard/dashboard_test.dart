import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task2026/config/supabase_config.dart';
import 'package:task2026/design_system/taskflow_design_system.dart';
import 'package:task2026/models/task.dart';
import 'package:task2026/models/nota_sap.dart';
import 'package:task2026/models/at.dart';
import 'package:task2026/services/task_service.dart';
import 'package:task2026/widgets/dashboard.dart';
import 'package:task2026/widgets/notas_sap_dashboard_view.dart';
import 'package:task2026/widgets/ats_dashboard_view.dart';
import 'package:task2026/widgets/analytics_view.dart';

Widget _wrap(
  Widget child, {
  ThemeData? theme,
  double width = 1280,
  double height = 800,
}) {
  return MaterialApp(
    theme: theme ?? TaskFlowTheme.light(),
    home: MediaQuery(
      data: MediaQueryData(
        size: Size(width, height),
      ),
      child: Scaffold(body: child),
    ),
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

  final sampleTasks = [
    Task(
      id: 'task-1',
      tarefa: 'Manutenção SE Centro',
      tipo: 'PREVENTIVA',
      regional: 'SUL',
      divisao: 'DISTRIBUICAO',
      status: 'ANDA',
      executor: 'João Silva',
      executores: ['João Silva'],
      coordenador: 'Carlos Coord',
      locais: ['SE Centro'],
      dataInicio: DateTime.now().subtract(const Duration(days: 2)),
      dataFim: DateTime.now().add(const Duration(days: 2)),
    ),
    Task(
      id: 'task-2',
      tarefa: 'Inspeção Linha Norte',
      tipo: 'CORRETIVA',
      regional: 'NORTE',
      divisao: 'TRANSMISSAO',
      status: 'CONC',
      executor: 'Maria Santos',
      executores: ['Maria Santos'],
      coordenador: 'Carlos Coord',
      locais: ['SE Norte'],
      dataInicio: DateTime.now().subtract(const Duration(days: 5)),
      dataFim: DateTime.now().subtract(const Duration(days: 1)),
    ),
    Task(
      id: 'task-3',
      tarefa: 'Troca de Disjuntor',
      tipo: 'EMERGENCIAL',
      regional: 'LESTE',
      divisao: 'DISTRIBUICAO',
      status: 'PROG',
      executor: '',
      executores: [],
      coordenador: '',
      locais: [],
      dataInicio: DateTime.now().subtract(const Duration(days: 3)),
      dataFim: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  group('Dashboard Tests', () {
    testWidgets('renderiza EmptyState quando não há tarefas filtradas', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Dashboard(
            taskService: TaskService(),
            filteredTasks: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nenhuma tarefa disponível'), findsOneWidget);
      expect(find.text('Aplique filtros para ver as estatísticas.'), findsOneWidget);
    });

    testWidgets('renderiza KPIs corretamente com lista de tarefas', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Dashboard(
            taskService: TaskService(),
            filteredTasks: sampleTasks,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Total'), findsOneWidget);
      expect(find.text('Em Andamento'), findsAtLeastNWidgets(1));
      expect(find.text('Concluídas'), findsOneWidget);
      expect(find.text('Programadas'), findsOneWidget);
      expect(find.text('Canceladas'), findsAtLeastNWidgets(1));
      expect(find.text('Alertas Ativos'), findsOneWidget);

      expect(find.text('3'), findsAtLeastNWidgets(1)); // total
      expect(find.text('1'), findsAtLeastNWidgets(1)); // andamento, conc, prog
    });

    testWidgets('renderiza em tema Dark e AXIA sem falhas', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Dashboard(
            taskService: TaskService(),
            filteredTasks: sampleTasks,
          ),
          theme: TaskFlowTheme.dark(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Total'), findsOneWidget);

      await tester.pumpWidget(
        _wrap(
          Dashboard(
            taskService: TaskService(),
            filteredTasks: sampleTasks,
          ),
          theme: TaskFlowTheme.axia(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Total'), findsOneWidget);
    });

    testWidgets('renderiza responsivamente em 390px, 768px e 1280px', (tester) async {
      // Mobile 390px
      await tester.pumpWidget(
        _wrap(
          Dashboard(
            taskService: TaskService(),
            filteredTasks: sampleTasks,
          ),
          width: 390,
          height: 844,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Total'), findsOneWidget);

      // Tablet 768px
      await tester.pumpWidget(
        _wrap(
          Dashboard(
            taskService: TaskService(),
            filteredTasks: sampleTasks,
          ),
          width: 768,
          height: 1024,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Total'), findsOneWidget);

      // Desktop 1280px
      await tester.pumpWidget(
        _wrap(
          Dashboard(
            taskService: TaskService(),
            filteredTasks: sampleTasks,
          ),
          width: 1280,
          height: 800,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Total'), findsOneWidget);
    });
  });

  group('NotasSAPDashboardView Tests', () {
    final sampleNotas = [
      NotaSAP(
        id: 'nota-1',
        nota: '10002345',
        descricao: 'Substituição de Chave Seccionadora',
        tipo: 'N1',
        local: 'SE Cascavel',
        gpm: 'GPM Sul',
        statusSistema: 'ABER',
        textPrioridade: 'Alta',
        dataVencimento: DateTime.now().add(const Duration(days: 15)),
      ),
      NotaSAP(
        id: 'nota-2',
        nota: '10002346',
        descricao: 'Revisão de Transformador T1',
        tipo: 'N2',
        local: 'SE Curitiba',
        gpm: 'GPM Leste',
        statusSistema: 'MSEN',
        textPrioridade: 'Normal',
        dataVencimento: DateTime.now().subtract(const Duration(days: 5)),
      ),
      NotaSAP(
        id: 'nota-3',
        nota: '10002347',
        descricao: 'Inspeção Termográfica SE Ponta Grossa',
        tipo: 'N1',
        local: 'SE Ponta Grossa',
        gpm: 'GPM Centro',
        statusSistema: 'ABER',
        textPrioridade: 'Muito Alta',
        dataVencimento: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];

    testWidgets('renderiza overview cards e seções analíticas de Notas SAP', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NotasSAPDashboardView(notas: sampleNotas),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Total'), findsOneWidget);
      expect(find.text('Abertas'), findsOneWidget);
      expect(find.text('Concluídas'), findsOneWidget);
      expect(find.text('Vencidas'), findsOneWidget);
      expect(find.text('Em Risco'), findsOneWidget);
      expect(find.text('No Prazo'), findsOneWidget);
      expect(find.text('Sem Prazo'), findsOneWidget);
    });

    testWidgets('renderiza NotasSAPDashboardView em tema Dark e AXIA', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NotasSAPDashboardView(notas: sampleNotas),
          theme: TaskFlowTheme.dark(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Total'), findsOneWidget);

      await tester.pumpWidget(
        _wrap(
          NotasSAPDashboardView(notas: sampleNotas),
          theme: TaskFlowTheme.axia(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Total'), findsOneWidget);
    });
  });

  group('AtsDashboardView Tests', () {
    final sampleATs = [
      AT(
        id: 'at-1',
        autorzTrab: 'AT-2026-001',
        textoBreve: 'Manutenção Preventiva',
        statusUsuario: 'CRSI',
        statusSistema: 'LIB',
        dataFim: DateTime.now(),
      ),
      AT(
        id: 'at-2',
        autorzTrab: 'AT-2026-002',
        textoBreve: 'Troca de Fusível',
        statusUsuario: 'CONC',
        statusSistema: 'CONC',
        dataFim: DateTime.now(),
      ),
    ];

    testWidgets('renderiza KPIs e gráfico de ATs com dados', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AtsDashboardView(
            ats: sampleATs,
            atsProgramadasIds: {'at-1'},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ATs Programadas'), findsOneWidget);
      expect(find.text('ATs Concluídas'), findsOneWidget);
      expect(find.text('Não Programadas'), findsOneWidget);
      expect(find.text('ATs por Fim Base (mês/ano)'), findsOneWidget);
    });

    testWidgets('renderiza AtsDashboardView vazio corretamente', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AtsDashboardView(
            ats: [],
            atsProgramadasIds: {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sem dados de ATs'), findsOneWidget);
    });
  });

  group('AnalyticsView Tests', () {
    testWidgets('renderiza AnalyticsView com resumo e gráficos de progresso', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AnalyticsView(
            taskService: TaskService(),
            filteredTasks: sampleTasks,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Análises e Gráficos'), findsOneWidget);
      expect(find.text('Distribuição por Status'), findsOneWidget);
      expect(find.text('Atividades por Tipo'), findsOneWidget);
      expect(find.text('Atividades por Regional'), findsOneWidget);
    });
  });
}
