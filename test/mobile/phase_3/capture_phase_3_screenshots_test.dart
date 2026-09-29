import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'package:task2026/models/task.dart';
import 'package:task2026/mobile/core/theme/tf_mobile_status_colors.dart';
import 'package:task2026/mobile/modules/tasks/adapters/mobile_task_adapter.dart';
import 'package:task2026/mobile/modules/tasks/models/mobile_task_view_model.dart';
import 'package:task2026/mobile/modules/tasks/models/mobile_task_detail_view_model.dart';
import 'package:task2026/mobile/modules/tasks/widgets/mobile_task_card.dart';
import 'package:task2026/mobile/modules/tasks/widgets/mobile_task_resources_card.dart';
import 'package:task2026/mobile/modules/tasks/widgets/mobile_task_pending_items.dart';
import 'package:task2026/mobile/modules/tasks/widgets/mobile_task_evidence_section.dart';
import 'package:task2026/mobile/modules/tasks/widgets/mobile_task_communication_section.dart';
import 'package:task2026/mobile/modules/tasks/mobile_task_list_screen.dart';
import 'package:task2026/mobile/modules/tasks/mobile_task_detail_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockStreamHandler(
      const EventChannel('com.llfbandit.app_links/events'),
      MockStreamHandler.inline(
        onListen: (arguments, events) {},
      ),
    );
    try {
      await Supabase.initialize(
        url: 'http://212.85.0.249:8000',
        anonKey:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzY1ODE3OTgzLCJleHAiOjIwODExNzc5ODN9.YQByqDrpmw0en7VeEcjDfvvTx8Ind_q8gD6-bzEY4Yc',
      );
    } catch (_) {}
  });

  final outDir = Directory('docs/mobile_redesign/phase_3/screenshots');
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }

  Future<void> saveBoundary(WidgetTester tester, GlobalKey key, String filename) async {
    await tester.runAsync(() async {
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 2.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          File('${outDir.path}/$filename').writeAsBytesSync(byteData.buffer.asUint8List());
        }
      }
    });
  }

  Task buildSampleTask({
    String id = 'task_101',
    String status = 'PROG',
    String tarefa = 'Manutenção Preventiva de Disjuntor 230kV',
    String? prioridade = 'Alta',
    List<String> locais = const ['SE Teresina II'],
    List<String> executores = const ['Carlos Silva', 'João Souza', 'Marcos Lima'],
    List<String> equipes = const ['Equipe Subestação Alpha'],
    String frota = 'Hilux ABC-1234',
    String ordem = '40012345',
    String si = 'SI-9988',
  }) {
    return Task(
      id: id,
      tarefa: tarefa,
      status: status,
      prioridade: prioridade,
      regional: 'Regional Norte',
      divisao: 'Divisão Transmissão',
      tipo: 'Preventiva',
      coordenador: 'Carlos Henrique Silva (Eng. Residente)',
      locais: locais,
      executores: executores,
      equipes: equipes,
      frota: frota,
      ordem: ordem,
      si: si,
      dataInicio: DateTime.now(),
      dataFim: DateTime.now().add(const Duration(hours: 4)),
      dataCriacao: DateTime.now().subtract(const Duration(days: 1)),
      dataAtualizacao: DateTime.now(),
    );
  }

  // 1. 01_tasks_today.png
  testWidgets('01_tasks_today', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final key = GlobalKey();
    final tasks = [
      buildSampleTask(id: '1', tarefa: 'Inspeção de Linha de Transmissão 500kV', status: 'ANDA'),
      buildSampleTask(id: '2', tarefa: 'Substituição de Chave Seccionadora', status: 'PROG'),
      buildSampleTask(id: '3', tarefa: 'Calibração de Relé de Proteção', status: 'CONC'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: key,
          child: Scaffold(
            body: MobileTaskListScreen(initialTasks: tasks),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await saveBoundary(tester, key, '01_tasks_today.png');
  });

  // 2. 02_tasks_filters.png
  testWidgets('02_tasks_filters', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final key = GlobalKey();
    final tasks = [
      buildSampleTask(id: '1', status: 'ANDA'),
      buildSampleTask(id: '2', status: 'PROG'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: key,
          child: Scaffold(
            body: MobileTaskListScreen(initialTasks: tasks),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tocar no botão de filtros avançados
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();

    await saveBoundary(tester, key, '02_tasks_filters.png');
  });

  // 3. 03_task_card_planned.png
  testWidgets('03_task_card_planned', (tester) async {
    tester.view.physicalSize = const Size(390, 320);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final key = GlobalKey();
    final task = buildSampleTask(status: 'PROG', tarefa: 'Inspeção Termográfica Painel BT');
    final vm = MobileTaskAdapter().toViewModel(task);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: Center(
            child: RepaintBoundary(
              key: key,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: MobileTaskCard(task: vm, onTap: () {}),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await saveBoundary(tester, key, '03_task_card_planned.png');
  });

  // 4. 04_task_card_running.png
  testWidgets('04_task_card_running', (tester) async {
    tester.view.physicalSize = const Size(390, 320);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final key = GlobalKey();
    final task = buildSampleTask(status: 'ANDA', tarefa: 'Manutenção Preventiva de Disjuntor 230kV');
    final vm = MobileTaskAdapter().toViewModel(task);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: Center(
            child: RepaintBoundary(
              key: key,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: MobileTaskCard(task: vm, onTap: () {}),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await saveBoundary(tester, key, '04_task_card_running.png');
  });

  // 5. 05_task_detail.png
  testWidgets('05_task_detail', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final key = GlobalKey();
    final task = buildSampleTask(status: 'ANDA');

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: key,
          child: MobileTaskDetailScreen(
            taskId: task.id,
            initialTask: task,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await saveBoundary(tester, key, '05_task_detail.png');
  });

  // 6. 06_task_team_resources.png
  testWidgets('06_task_team_resources', (tester) async {
    tester.view.physicalSize = const Size(390, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final key = GlobalKey();
    final task = buildSampleTask();
    final detailVm = MobileTaskAdapter().toDetailViewModel(task);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: Center(
            child: RepaintBoundary(
              key: key,
              child: MobileTaskResourcesCard(
                task: detailVm,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await saveBoundary(tester, key, '06_task_team_resources.png');
  });

  // 7. 07_task_safety.png
  testWidgets('07_task_safety', (tester) async {
    tester.view.physicalSize = const Size(390, 420);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: Center(
            child: RepaintBoundary(
              key: key,
              child: MobileTaskPendingItems(
                aprStatus: MobileAprStatus.requiredPending,
                hasPendingSync: true,
                onOpenApr: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await saveBoundary(tester, key, '07_task_safety.png');
  });

  // 8. 08_task_evidence.png
  testWidgets('08_task_evidence', (tester) async {
    tester.view.physicalSize = const Size(390, 240);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: Center(
            child: RepaintBoundary(
              key: key,
              child: MobileTaskEvidenceSection(
                evidences: const [],
                onAddPhoto: (_) async {},
                isReadOnly: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await saveBoundary(tester, key, '08_task_evidence.png');
  });

  // 9. 09_task_chat.png
  testWidgets('09_task_chat', (tester) async {
    tester.view.physicalSize = const Size(390, 240);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: Center(
            child: RepaintBoundary(
              key: key,
              child: MobileTaskCommunicationSection(
                chatGroupId: 'chat_group_123',
                unreadCount: 3,
                onOpenChat: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await saveBoundary(tester, key, '09_task_chat.png');
  });

  // 10. 10_task_offline.png
  testWidgets('10_task_offline', (tester) async {
    tester.view.physicalSize = const Size(390, 500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final key = GlobalKey();
    final task = buildSampleTask(status: 'ANDA', tarefa: 'Manutenção em Modo Avião / Offline');
    final baseVm = MobileTaskAdapter().toViewModel(task);
    final vm = MobileTaskViewModel(
      id: baseVm.id,
      title: baseVm.title,
      rawStatus: baseVm.rawStatus,
      status: baseVm.status,
      type: baseVm.type,
      isUnknownStatus: baseVm.isUnknownStatus,
      syncStatus: TFSyncStatus.pending,
      actions: baseVm.actions,
      priority: baseVm.priority,
      location: baseVm.location,
      asset: baseVm.asset,
      formattedDate: baseVm.formattedDate,
      timeWindow: baseVm.timeWindow,
      teamName: baseVm.teamName,
      vehiclePlate: baseVm.vehiclePlate,
      pendingApr: false,
      pendingSync: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: Center(
            child: RepaintBoundary(
              key: key,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: MobileTaskCard(task: vm, onTap: () {}),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await saveBoundary(tester, key, '10_task_offline.png');
  });

  // 11. 11_task_dark_mode.png
  testWidgets('11_task_dark_mode', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final key = GlobalKey();
    final task = buildSampleTask(status: 'ANDA');

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(brightness: Brightness.dark),
        home: RepaintBoundary(
          key: key,
          child: MobileTaskDetailScreen(
            taskId: task.id,
            initialTask: task,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await saveBoundary(tester, key, '11_task_dark_mode.png');
  });

  // 12. 12_task_large_text.png
  testWidgets('12_task_large_text', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final key = GlobalKey();
    final task = buildSampleTask(status: 'ANDA');

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            textScaler: TextScaler.linear(1.5),
          ),
          child: RepaintBoundary(
            key: key,
            child: MobileTaskDetailScreen(
              taskId: task.id,
              initialTask: task,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await saveBoundary(tester, key, '12_task_large_text.png');
  });
}
