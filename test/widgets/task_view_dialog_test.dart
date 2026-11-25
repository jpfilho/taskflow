import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:task2026/design_system/theme/taskflow_theme.dart';
import 'package:task2026/models/task.dart';
import 'package:task2026/widgets/task_view_dialog.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: 'http://localhost:54321',
        anonKey: 'test-anon-key',
      );
    } catch (_) {}
  });

  Task buildFullTask() {
    return Task(
      id: 'task-uuid-1234-5678-9012',
      status: 'ANDA',
      statusNome: 'Em Andamento',
      regional: 'Regional Norte',
      divisao: 'Divisão Teresina',
      segmento: 'Linhas de Transmissão',
      locais: ['SE Teresina I', 'LT 230kV'],
      tipo: 'MANUTENCAO',
      ordem: '400012345',
      tarefa: 'Inspeção termográfica e reaperto de conexões',
      executores: ['João Silva', 'Maria Souza'],
      equipeExecutores: [
        EquipeExecutorInfo(executorNome: 'João Silva', papel: 'ENCARREGADO'),
        EquipeExecutorInfo(executorNome: 'Maria Souza', papel: 'EXECUTOR'),
      ],
      equipes: ['Equipe LT-01'],
      frota: 'Hilux 4x4 (PI-1234)',
      coordenador: 'Carlos Gestor',
      si: 'SI-2026-998',
      precisaSi: true,
      prioridade: 'ALTA',
      hasConflict: true,
      parentId: 'parent-uuid-0001',
      dataInicio: DateTime(2026, 11, 10),
      dataFim: DateTime(2026, 11, 14),
      dataCriacao: DateTime(2026, 11, 1, 9, 30),
      dataAtualizacao: DateTime(2026, 11, 17, 14, 15),
      horasPrevistas: 24,
      horasExecutadas: 12,
      observacoes: 'Necessário desligamento programado e uso de câmera térmica.',
      ganttSegments: [
        GanttSegment(
          dataInicio: DateTime(2026, 11, 10),
          dataFim: DateTime(2026, 11, 10),
          label: 'Deslocamento ida',
          tipo: 'ADM',
          tipoPeriodo: 'DESLOCAMENTO',
        ),
        GanttSegment(
          dataInicio: DateTime(2026, 11, 11),
          dataFim: DateTime(2026, 11, 14),
          label: 'Execução em campo',
          tipo: 'BEA',
          tipoPeriodo: 'EXECUCAO',
        ),
      ],
      executorPeriods: [
        ExecutorPeriod(
          executorId: 'exec-1',
          executorNome: 'João Silva',
          periods: [
            GanttSegment(
              dataInicio: DateTime(2026, 11, 11),
              dataFim: DateTime(2026, 11, 13),
              label: 'Campo',
              tipo: 'BEA',
              tipoPeriodo: 'EXECUCAO',
            ),
          ],
        ),
      ],
      frotaPeriods: [
        FrotaPeriod(
          frotaId: 'frota-1',
          frotaNome: 'Hilux 4x4 (PI-1234)',
          periods: [
            GanttSegment(
              dataInicio: DateTime(2026, 11, 10),
              dataFim: DateTime(2026, 11, 14),
              label: 'Apoio',
              tipo: 'ADM',
              tipoPeriodo: 'EXECUCAO',
            ),
          ],
        ),
      ],
    );
  }

  testWidgets('TaskViewDialog Desktop (1280x800) exibe todos os dados completos da atividade', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final task = buildFullTask();

    await tester.pumpWidget(
      MaterialApp(
        theme: TaskFlowTheme.light(),
        home: Scaffold(
          body: TaskViewDialog(task: task),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Cabeçalho e badges
    expect(find.text('Inspeção termográfica e reaperto de conexões'), findsOneWidget);
    expect(find.text('ANDA — Em Andamento'), findsOneWidget);
    expect(find.text('MANUTENCAO'), findsWidgets);
    expect(find.text('Prioridade: ALTA'), findsOneWidget);
    expect(find.text('Conflito de Agenda'), findsOneWidget);
    expect(find.text('Subtarefa'), findsOneWidget);

    // KPIs e dados completos
    expect(find.text('Período (5 dias)'), findsOneWidget);
    expect(find.text('Esforço (Horas)'), findsNothing);
    expect(find.text('Horas Previstas'), findsNothing);
    expect(find.text('Horas Executadas'), findsNothing);
    expect(find.text('Regional Norte'), findsOneWidget);
    expect(find.text('Divisão Teresina'), findsOneWidget);
    expect(find.text('Linhas de Transmissão'), findsOneWidget);
    expect(find.text('SE Teresina I'), findsOneWidget);
    expect(find.text('LT 230kV'), findsOneWidget);

    // Equipe e papéis
    expect(find.text('Carlos Gestor'), findsOneWidget);
    expect(find.text('Equipe LT-01'), findsOneWidget);
    expect(find.text('João Silva (ENCARREGADO)'), findsOneWidget);
    expect(find.text('Maria Souza (EXECUTOR)'), findsOneWidget);

    // Segmentos e períodos específicos (sem texto da atividade e sem 'OUT', com calendário colorido)
    expect(find.text('Segmentos do Cronograma (2)'), findsOneWidget);
    expect(find.text('Novembro / 2026'), findsOneWidget);
    expect(find.text('Execução'), findsWidgets);
    expect(find.text('Deslocamento'), findsWidgets);
    expect(find.textContaining('OUT'), findsNothing);
    expect(find.text('Deslocamento ida'), findsNothing);
    expect(find.text('Execução em campo'), findsNothing);
    expect(find.text('Períodos por Executor (1)'), findsOneWidget);
    expect(find.text('Períodos por Frota (1)'), findsOneWidget);

    // Observações e auditoria
    expect(find.textContaining('câmera térmica'), findsOneWidget);
    expect(find.text('01/11/2026 09:30'), findsOneWidget);
    expect(find.text('17/11/2026 14:15'), findsOneWidget);
    expect(find.text('Fechar'), findsOneWidget);

    // Coluna de Chat visível e funcional com Expandir/Recolher
    expect(find.text('Chat da Atividade'), findsOneWidget);
    final expandBtn = find.byIcon(Icons.open_in_full);
    expect(expandBtn, findsOneWidget);

    await tester.tap(expandBtn);
    await tester.pump();
    // Modo expandido: exibe botão de recolher e oculta cards de detalhes
    expect(find.byIcon(Icons.close_fullscreen), findsOneWidget);
    expect(find.text('Classificação e Escopo'), findsNothing);

    await tester.tap(find.byIcon(Icons.close_fullscreen));
    await tester.pump();
    // Volta à visualização com detalhes e coluna lateral de Chat
    expect(find.text('Classificação e Escopo'), findsOneWidget);
    expect(find.text('Chat da Atividade'), findsOneWidget);
  });

  testWidgets('TaskViewDialog Mobile (390x844) renderiza em coluna única sem overflow', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final task = buildFullTask();

    await tester.pumpWidget(
      MaterialApp(
        theme: TaskFlowTheme.light(),
        home: Scaffold(
          body: TaskViewDialog(task: task),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Inspeção termográfica e reaperto de conexões'), findsOneWidget);
    expect(find.text('Classificação e Escopo'), findsOneWidget);
    expect(find.text('Fechar'), findsOneWidget);
  });
}
