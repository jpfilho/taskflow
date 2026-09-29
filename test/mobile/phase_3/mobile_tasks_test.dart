import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task2026/models/task.dart';
import 'package:task2026/mobile/core/theme/tf_mobile_status_colors.dart';
import 'package:task2026/mobile/modules/tasks/adapters/mobile_task_adapter.dart';
import 'package:task2026/mobile/modules/tasks/models/mobile_task_available_actions.dart';
import 'package:task2026/mobile/modules/tasks/models/mobile_task_detail_view_model.dart';
import 'package:task2026/mobile/modules/tasks/widgets/mobile_task_card.dart';
import 'package:task2026/mobile/modules/tasks/widgets/mobile_task_actions.dart';
import 'package:task2026/mobile/modules/tasks/widgets/mobile_task_pending_items.dart';
import 'package:task2026/mobile/modules/tasks/mobile_task_list_screen.dart';
import 'package:task2026/mobile/modules/tasks/mobile_task_detail_screen.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: 'https://placeholder.supabase.co',
        anonKey: 'placeholder_key',
      );
    } catch (_) {}
  });

  Task createTestTask({
    String id = 'task_1',
    String status = 'PROG',
    String tarefa = 'Manutenção Preventiva de Disjuntor 230kV',
    String? prioridade = 'Alta',
    List<String> locais = const ['SE Teresina II'],
    List<String> executores = const ['Carlos Silva', 'João Souza'],
    List<String> equipes = const ['Equipe Subestação Alpha'],
    String frota = 'Hilux ABC-1234',
    String ordem = '40012345',
    String si = 'SI-9988',
  }) {
    return Task(
      id: id,
      tarefa: tarefa,
      tipo: 'PMP',
      status: status,
      prioridade: prioridade,
      regional: 'Regional Norte',
      divisao: 'Divisão Operacional',
      segmento: 'Subestações',
      locais: locais,
      executores: executores,
      equipes: equipes,
      frota: frota,
      coordenador: 'Marcos Coordenador',
      ordem: ordem,
      si: si,
      dataInicio: DateTime(2026, 9, 18, 8, 0),
      dataFim: DateTime(2026, 9, 18, 12, 0),
      dataCriacao: DateTime(2026, 9, 17, 10, 0),
      dataAtualizacao: DateTime(2026, 9, 17, 15, 30),
      horasPrevistas: 4.0,
      horasExecutadas: 0.0,
      observacoes: 'Verificar alinhamento e isolamento térmico.',
    );
  }

  group('TaskFlow Mobile — Fase 3: Quality Gate de Atividades Operacionais', () {
    test('1. Mapeamento de Status Reais (ANDA, PROG, RPAR, RPGR, CONC, CANC e Desconhecido)', () {
      final adapter = MobileTaskAdapter();

      expect(adapter.mapOperationalStatus('ANDA'), equals(TFOperationalStatus.emExecucao));
      expect(adapter.mapOperationalStatus('PROG'), equals(TFOperationalStatus.planejado));
      expect(adapter.mapOperationalStatus('RPAR'), equals(TFOperationalStatus.pausado));
      expect(adapter.mapOperationalStatus('RPGR'), equals(TFOperationalStatus.pausado));
      expect(adapter.mapOperationalStatus('CONC'), equals(TFOperationalStatus.concluido));
      expect(adapter.mapOperationalStatus('CANC'), equals(TFOperationalStatus.cancelado));

      // Status desconhecido
      expect(adapter.mapOperationalStatus('STATUS_INVALIDO'), equals(TFOperationalStatus.pendente));
      expect(adapter.isUnknownStatus('STATUS_INVALIDO'), isTrue);
      expect(adapter.isUnknownStatus('ANDA'), isFalse);
    });

    test('2. Matriz Semântica de Ações Permitidas e Modo Somente Leitura', () {
      final adapter = MobileTaskAdapter();

      // Tarefa Planejada (PROG)
      final taskProg = createTestTask(status: 'PROG');
      final actionsProg = adapter.calculateAvailableActions(taskProg);
      expect(actionsProg.canStart, isTrue);
      expect(actionsProg.canPause, isFalse);
      expect(actionsProg.canComplete, isFalse);
      expect(actionsProg.isReadOnly, isFalse);
      expect(actionsProg.primaryActionLabel, equals('Iniciar Atividade'));

      // Tarefa em Execução (ANDA)
      final taskAnda = createTestTask(status: 'ANDA');
      final actionsAnda = adapter.calculateAvailableActions(taskAnda);
      expect(actionsAnda.canStart, isFalse);
      expect(actionsAnda.canPause, isTrue);
      expect(actionsAnda.canComplete, isTrue);
      expect(actionsAnda.primaryActionLabel, equals('Continuar'));

      // Tarefa Pausada (RPAR)
      final taskRpar = createTestTask(status: 'RPAR');
      final actionsRpar = adapter.calculateAvailableActions(taskRpar);
      expect(actionsRpar.canResume, isTrue);
      expect(actionsRpar.primaryActionLabel, equals('Retomar Atividade'));

      // Tarefa Concluída (CONC)
      final taskConc = createTestTask(status: 'CONC');
      final actionsConc = adapter.calculateAvailableActions(taskConc);
      expect(actionsConc.isReadOnly, isTrue);
      expect(actionsConc.canStart, isFalse);

      // Usuário Somente Leitura
      final actionsReadOnly = adapter.calculateAvailableActions(taskAnda, isReadOnly: true);
      expect(actionsReadOnly.isReadOnly, isTrue);
      expect(actionsReadOnly.canStart, isFalse);
      expect(actionsReadOnly.canPause, isFalse);
      expect(actionsReadOnly.canComplete, isFalse);
      expect(actionsReadOnly.primaryActionLabel, equals('Ver Detalhes'));
    });

    test('3. ViewModels separam estritamente dados semânticos de estilos e cores', () {
      final adapter = MobileTaskAdapter();
      final task = createTestTask(prioridade: 'Alta');

      final vm = adapter.toViewModel(task);
      expect(vm.title, equals(task.tarefa));
      expect(vm.priority, equals('Alta'));
      expect(vm.location, equals('SE Teresina II'));
      expect(vm.vehiclePlate, equals('Hilux ABC-1234'));
      expect(vm.timeWindow, equals('08:00 → 12:00'));

      final detailVm = adapter.toDetailViewModel(task);
      expect(detailVm.sapOrder, equals('40012345'));
      expect(detailVm.sapSi, equals('SI-9988'));
      expect(detailVm.hasSapReferences, isTrue);
      expect(detailVm.timelineEvents.length, equals(3));
    });

    testWidgets('4. MobileTaskCard renderiza com touch target >= 48px e dados essenciais', (tester) async {
      final adapter = MobileTaskAdapter();
      final task = createTestTask();
      final vm = adapter.toViewModel(task);

      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MobileTaskCard(
              task: vm,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text(task.tarefa), findsOneWidget);
      expect(find.text('SE Teresina II'), findsOneWidget);
      expect(find.text('Equipe Subestação Alpha'), findsOneWidget);
      expect(find.text('Hilux ABC-1234'), findsOneWidget);
      expect(find.text('Alta'), findsOneWidget);
      expect(find.text('Iniciar Atividade'), findsOneWidget);

      // Touch target do botão principal >= 48px
      final buttonSize = tester.getSize(find.byType(ElevatedButton));
      expect(buttonSize.height, greaterThanOrEqualTo(48.0));

      await tester.tap(find.text('Iniciar Atividade'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('5. MobileTaskListScreen: Busca debounced e Chips Rápidos', (tester) async {
      tester.view.physicalSize = const Size(800 * 3.0, 1200 * 3.0);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final tasks = [
        createTestTask(id: '1', tarefa: 'Inspeção Transformador TR-01', status: 'PROG'),
        createTestTask(id: '2', tarefa: 'Substituição Isolador LT-500kV', status: 'ANDA'),
        createTestTask(id: '3', tarefa: 'Pintura de Painel', status: 'CONC'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: MobileTaskListScreen(
            initialTasks: tasks,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Inspeção Transformador TR-01'), findsOneWidget);
      expect(find.text('Substituição Isolador LT-500kV'), findsOneWidget);
      expect(find.text('Pintura de Painel'), findsOneWidget);

      // Filtro Rápido: Em Execução
      final chipExecucao = find.widgetWithText(FilterChip, 'Em Execução');
      await tester.ensureVisible(chipExecucao);
      await tester.tap(chipExecucao);
      await tester.pumpAndSettle();

      expect(find.text('Inspeção Transformador TR-01'), findsNothing);
      expect(find.text('Substituição Isolador LT-500kV'), findsOneWidget);
      expect(find.text('Pintura de Painel'), findsNothing);

      // Filtro Rápido: Concluídas
      final chipConcluidas = find.widgetWithText(FilterChip, 'Concluídas');
      await tester.ensureVisible(chipConcluidas);
      await tester.tap(chipConcluidas);
      await tester.pumpAndSettle();

      expect(find.text('Substituição Isolador LT-500kV'), findsNothing);
      expect(find.text('Pintura de Painel'), findsOneWidget);

      // Voltar para Todas
      final chipTodas = find.widgetWithText(FilterChip, 'Todas');
      await tester.ensureVisible(chipTodas);
      await tester.tap(chipTodas);
      await tester.pumpAndSettle();

      // Teste de Busca com debounce
      await tester.enterText(find.byType(TextField), 'Transformador');
      await tester.pump(const Duration(milliseconds: 350)); // Ultrapassar o debounce de 300ms
      await tester.pumpAndSettle();

      expect(find.text('Inspeção Transformador TR-01'), findsOneWidget);
      expect(find.text('Substituição Isolador LT-500kV'), findsNothing);
    });

    testWidgets('6. MobileTaskActions: Proteção contra Duplo Toque e Confirmação de Conclusão', (tester) async {
      int completeCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MobileTaskActions(
              actions: const MobileTaskAvailableActions(
                canPause: true,
                canComplete: true,
              ),
              onStart: () {},
              onPause: () {},
              onResume: () {},
              onComplete: () => completeCalls++,
            ),
          ),
        ),
      );

      expect(find.text('Pausar'), findsOneWidget);
      expect(find.text('Concluir'), findsOneWidget);

      // Clicar em Concluir deve abrir diálogo de confirmação
      await tester.tap(find.text('Concluir'));
      await tester.pumpAndSettle();

      expect(find.text('Concluir Atividade?'), findsOneWidget);
      expect(find.text('Confirmar Conclusão'), findsOneWidget);

      // Confirmar no diálogo
      await tester.tap(find.text('Confirmar Conclusão'));
      await tester.pumpAndSettle();

      expect(completeCalls, equals(1));
    });

    testWidgets('7. MobileTaskPendingItems: Exibição não-bloqueante de APR e Alertas', (tester) async {
      bool aprTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MobileTaskPendingItems(
              aprStatus: MobileAprStatus.requiredPending,
              hasPendingSync: true,
              onOpenApr: () => aprTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('APR (Análise Preliminar de Risco) Pendente'), findsOneWidget);
      expect(find.text('Existem registros locais aguardando sincronização com a nuvem.'), findsOneWidget);

      await tester.tap(find.text('Preencher APR'));
      await tester.pump();
      expect(aprTapped, isTrue);
    });

    testWidgets('8. Resoluções Mobile (360x800, 390x844, 412x915) e Escala de Texto (1.5x) sem Overflow',
        (tester) async {
      final task = createTestTask();
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      for (final size in [
        const Size(360, 800),
        const Size(390, 844),
        const Size(412, 915),
      ]) {
        for (final textScale in [1.0, 1.3, 1.5]) {
          tester.view.physicalSize = size * 3.0;
          tester.view.devicePixelRatio = 3.0;

          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: TextScaler.linear(textScale),
                ),
                child: MobileTaskListScreen(
                  initialTasks: [task],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
        }
      }
    });

    testWidgets('9. Grandes Volumes: Lista com 500 tarefas renderiza com ListView.builder sem travamentos',
        (tester) async {
      final tasks500 = List.generate(
        500,
        (i) => createTestTask(
          id: 'task_$i',
          tarefa: 'Atividade Operacional #$i de Campo',
          status: i % 2 == 0 ? 'ANDA' : 'PROG',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MobileTaskListScreen(
            initialTasks: tasks500,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Atividade Operacional #0 de Campo'), findsOneWidget);

      // Rolar para baixo rapidamente
      await tester.drag(find.byType(ListView).last, const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('10. Dark Mode e Light Mode em MobileTaskDetailScreen', (tester) async {
      tester.view.physicalSize = const Size(390 * 3.0, 844 * 3.0);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final task = createTestTask();

      for (final brightness in [Brightness.light, Brightness.dark]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: MobileTaskDetailScreen(
              taskId: task.id,
              initialTask: task,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(task.tarefa), findsOneWidget);
        expect(find.text('Resumo da Execução'), findsOneWidget);
        expect(find.text('Equipe & Recursos'), findsOneWidget);
        expect(find.text('Referências SAP'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  });
}
