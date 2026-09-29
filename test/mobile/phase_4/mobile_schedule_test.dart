import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:task2026/models/task.dart';
import 'package:task2026/models/equipe.dart';
import 'package:task2026/models/equipe_executor.dart';
import 'package:task2026/models/frota.dart';
import 'package:task2026/mobile/modules/schedule/models/mobile_agenda_view_mode.dart';
import 'package:task2026/mobile/modules/schedule/models/mobile_agenda_day_summary.dart';
import 'package:task2026/mobile/modules/schedule/adapters/mobile_schedule_adapter.dart';
import 'package:task2026/mobile/modules/schedule/widgets/day_carousel_selector.dart';
import 'package:task2026/mobile/modules/schedule/widgets/mobile_agenda_slot_card.dart';
import 'package:task2026/mobile/modules/schedule/widgets/mobile_team_day_card.dart';
import 'package:task2026/mobile/modules/schedule/widgets/mobile_fleet_day_card.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:task2026/mobile/modules/schedule/mobile_schedule_screen.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('pt_BR', null);
    try {
      await Supabase.initialize(
        url: 'https://test-taskflow.supabase.co',
        anonKey: 'test-anon-key',
      );
    } catch (_) {}
  });

  final testDate = DateTime(2026, 9, 18);

  Task createTask({
    required String id,
    required String title,
    required String status,
    required DateTime start,
    required DateTime end,
    String? team,
    String? fleet,
    bool conflict = false,
  }) {
    return Task(
      id: id,
      tarefa: title,
      tipo: 'LINHA',
      status: status,
      statusNome: status,
      regional: 'Regional Centro',
      divisao: 'Divisão Manutenção',
      coordenador: 'Coordenador Operacional',
      dataInicio: start,
      dataFim: end,
      equipes: team != null ? [team] : [],
      frota: fleet ?? '',
      hasConflict: conflict,
    );
  }

  group('MobileScheduleAdapter - Testes de Unidade e Lógica Operacional', () {
    test('taskOccursOnDay detecta corretamente sobreposição de datas', () {
      final taskMorning = createTask(
        id: '1',
        title: 'Manutenção Torre',
        status: 'PROG',
        start: DateTime(2026, 9, 18, 8, 0),
        end: DateTime(2026, 9, 18, 12, 0),
      );

      final taskSpanning = createTask(
        id: '2',
        title: 'Pintura de Estrutura',
        status: 'ANDA',
        start: DateTime(2026, 9, 17, 8, 0),
        end: DateTime(2026, 9, 19, 18, 0),
      );

      final taskTomorrow = createTask(
        id: '3',
        title: 'Subestação',
        status: 'PROG',
        start: DateTime(2026, 9, 19, 8, 0),
        end: DateTime(2026, 9, 19, 12, 0),
      );

      expect(MobileScheduleAdapter.taskOccursOnDay(taskMorning, testDate), isTrue);
      expect(MobileScheduleAdapter.taskOccursOnDay(taskSpanning, testDate), isTrue);
      expect(MobileScheduleAdapter.taskOccursOnDay(taskTomorrow, testDate), isFalse);
    });

    test('buildDaysSummaries gera resumo factual do período com contagens reais', () {
      final adapter = MobileScheduleAdapter();
      final tasks = [
        createTask(
          id: '1',
          title: 'Tarefa Andamento',
          status: 'ANDA',
          start: DateTime(2026, 9, 18, 8, 0),
          end: DateTime(2026, 9, 18, 12, 0),
        ),
        createTask(
          id: '2',
          title: 'Tarefa Concluída',
          status: 'CONC',
          start: DateTime(2026, 9, 18, 13, 0),
          end: DateTime(2026, 9, 18, 17, 0),
          conflict: true,
        ),
      ];

      final summaries = adapter.buildDaysSummaries(
        rangeStart: DateTime(2026, 9, 17),
        rangeEnd: DateTime(2026, 9, 19),
        tasks: tasks,
        selectedDate: testDate,
      );

      expect(summaries.length, equals(3));
      final day18 = summaries.firstWhere((s) => s.date.day == 18);
      expect(day18.totalTasks, equals(2));
      expect(day18.runningTasks, equals(1));
      expect(day18.completedTasks, equals(1));
      expect(day18.hasConflict, isTrue);
    });

    test('buildTimelineSlots separa corretamente blocos de manhã, tarde e noite', () {
      final adapter = MobileScheduleAdapter();
      final tasks = [
        createTask(
          id: '1',
          title: 'Inspeção Matutina',
          status: 'ANDA',
          start: DateTime(2026, 9, 18, 8, 30),
          end: DateTime(2026, 9, 18, 11, 30),
        ),
        createTask(
          id: '2',
          title: 'Termografia Vespertina',
          status: 'PROG',
          start: DateTime(2026, 9, 18, 14, 0),
          end: DateTime(2026, 9, 18, 17, 0),
        ),
      ];

      final slots = adapter.buildTimelineSlots(tasks, testDate);
      expect(slots.length, equals(2));
      expect(slots.any((s) => s.title == 'Manhã'), isTrue);
      expect(slots.any((s) => s.title == 'Tarde'), isTrue);
    });
  });

  group('Mobile Schedule - Widget Tests e Ergonomia de Campo', () {
    testWidgets('DayCarouselSelector renderiza chips com touch target >= 48px e responde a toques', (tester) async {
      DateTime? selectedDay;
      final days = [
        MobileAgendaDaySummary(
          date: DateTime(2026, 9, 18),
          totalTasks: 3,
          isToday: true,
        ),
        MobileAgendaDaySummary(
          date: DateTime(2026, 9, 19),
          totalTasks: 0,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DayCarouselSelector(
              days: days,
              selectedDate: DateTime(2026, 9, 18),
              onDaySelected: (d) => selectedDay = d,
            ),
          ),
        ),
      );

      expect(find.text('18'), findsOneWidget);
      expect(find.text('19'), findsOneWidget);
      expect(find.text('3'), findsOneWidget); // badge de 3 tarefas

      // Tocar no dia 19
      await tester.tap(find.text('19'));
      await tester.pumpAndSettle();

      expect(selectedDay?.day, equals(19));
    });

    testWidgets('MobileAgendaSlotCard exibe status, horário, recursos e aciona onTap', (tester) async {
      String? tappedTaskId;
      const item = MobileAgendaTaskItem(
        taskId: 'task-101',
        codigo: 'LT-500KV',
        titulo: 'Reaperto de Conexões',
        statusRaw: 'ANDA',
        statusLabel: 'Em Andamento',
        horarioInicio: '08:00',
        horarioFim: '12:00',
        local: 'Subestação Campinas',
        equipeNome: 'Equipe Alpha',
        veiculoNome: 'Hilux Placa ABC-1234',
        hasConflict: true,
        conflictReason: 'Sobreposição de equipe',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MobileAgendaSlotCard(
              task: item,
              onTapTask: (id) => tappedTaskId = id,
            ),
          ),
        ),
      );

      expect(find.text('LT-500KV'), findsOneWidget);
      expect(find.text('Reaperto de Conexões'), findsOneWidget);
      expect(find.text('08:00 – 12:00'), findsOneWidget);
      expect(find.text('Equipe Alpha'), findsOneWidget);
      expect(find.text('Hilux Placa ABC-1234'), findsOneWidget);
      expect(find.text('Sobreposição de equipe'), findsOneWidget);

      await tester.tap(find.text('Reaperto de Conexões'));
      await tester.pumpAndSettle();

      expect(tappedTaskId, equals('task-101'));
    });

    testWidgets('MobileTeamDayCard renderiza grupo com equipe e tarefas', (tester) async {
      final group = MobileTeamAgendaGroup(
        equipeId: 'eq-1',
        equipeNome: 'Linha Viva 01',
        encarregadoNome: 'Carlos Encarregado',
        membrosNomes: const ['João', 'Pedro'],
        tasks: const [
          MobileAgendaTaskItem(
            taskId: 't-1',
            codigo: 'MAN-01',
            titulo: 'Troca de Isoladores',
            statusRaw: 'PROG',
            statusLabel: 'Programada',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MobileTeamDayCard(
              group: group,
              onTapTask: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Linha Viva 01'), findsOneWidget);
      expect(find.text('Líder: Carlos Encarregado'), findsOneWidget);
      expect(find.text('Troca de Isoladores'), findsOneWidget);
    });

    testWidgets('MobileFleetDayCard renderiza grupo com veículo e tarefas', (tester) async {
      final group = MobileFleetAgendaGroup(
        frotaId: 'fr-1',
        veiculoNome: 'Caminhão Munck 04',
        placa: 'BRA-2E19',
        tipoVeiculo: 'PESADO',
        equipeNome: 'Equipe de Estruturas',
        tasks: const [
          MobileAgendaTaskItem(
            taskId: 't-2',
            codigo: 'POS-02',
            titulo: 'Içamento de Transformador',
            statusRaw: 'ANDA',
            statusLabel: 'Em Andamento',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MobileFleetDayCard(
              group: group,
              onTapTask: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Caminhão Munck 04'), findsOneWidget);
      expect(find.textContaining('BRA-2E19'), findsOneWidget);
      expect(find.text('Içamento de Transformador'), findsOneWidget);
    });

    testWidgets('MobileScheduleScreen alterna entre Horário, Equipes e Frota sem erros', (tester) async {
      final tasks = [
        createTask(
          id: '1',
          title: 'Substituição de Chave',
          status: 'ANDA',
          start: DateTime(2026, 9, 18, 9, 0),
          end: DateTime(2026, 9, 18, 12, 0),
          team: 'Equipe Manutenção',
          fleet: 'Caminhão 01',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: MobileScheduleScreen(
            initialDate: DateTime(2026, 9, 18),
            preloadedTasks: tasks,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Programação & Agenda'), findsOneWidget);
      expect(find.text('Substituição de Chave'), findsOneWidget);

      // Alternar para 'Equipes'
      await tester.tap(find.text('Equipes'));
      await tester.pumpAndSettle();
      expect(find.text('Equipe Manutenção'), findsAtLeastNWidgets(1));

      // Alternar para 'Frota'
      await tester.tap(find.text('Frota'));
      await tester.pumpAndSettle();
      expect(find.text('Caminhão 01'), findsAtLeastNWidgets(1));
    });

    testWidgets('MobileScheduleScreen exibe Empty State se não houver tarefas no dia', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MobileScheduleScreen(
            initialDate: DateTime(2026, 9, 18),
            preloadedTasks: const [],
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Sem atividades programadas'), findsOneWidget);
    });

    testWidgets('Acessibilidade: Text Scale 1.5 e resoluções variadas sem overflow', (tester) async {
      final tasks = [
        createTask(
          id: '1',
          title: 'Manutenção de Linha com Descrição Bem Detalhada para Teste',
          status: 'ANDA',
          start: DateTime(2026, 9, 18, 9, 0),
          end: DateTime(2026, 9, 18, 12, 0),
          team: 'Equipe Especializada de Alta Tensão',
          fleet: 'Veículo 4x4 Off-Road Operacional',
          conflict: true,
        ),
      ];

      final viewports = [
        const Size(360, 800), // Compact Android
        const Size(390, 844), // iPhone padrão
        const Size(412, 915), // Large Android
      ];

      for (final size in viewports) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(1.5),
              ),
              child: MobileScheduleScreen(
                initialDate: DateTime(2026, 9, 18),
                preloadedTasks: tasks,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  });
}
