import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:task2026/models/task.dart';
import 'package:task2026/mobile/modules/schedule/models/mobile_agenda_view_mode.dart';
import 'package:task2026/mobile/modules/schedule/mobile_schedule_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('pt_BR', null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
      const EventChannel('com.llfbandit.app_links/events'),
      MockStreamHandler.inline(onListen: (arguments, events) {}),
    );
    try {
      await Supabase.initialize(
        url: 'https://test-taskflow.supabase.co',
        anonKey: 'test-anon-key',
      );
    } catch (_) {}
  });

  final outDir = Directory('docs/mobile_redesign/phase_4/screenshots');
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }

  Future<void> saveBoundary(
      WidgetTester tester, GlobalKey key, String filename) async {
    await tester.runAsync(() async {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 2.0);
        final byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          File('${outDir.path}/$filename')
              .writeAsBytesSync(byteData.buffer.asUint8List());
        }
      }
    });
  }

  List<Task> buildSampleTasks() {
    return [
      Task(
        id: 't-1',
        tarefa: 'Manutenção Preventiva de Disjuntor 230kV',
        tipo: 'PMP',
        status: 'ANDA',
        statusNome: 'Em Andamento',
        prioridade: 'Alta',
        regional: 'Regional Norte',
        divisao: 'Divisão Manutenção',
        segmento: 'Subestações',
        locais: const ['SE Teresina II'],
        executores: const ['Carlos Silva', 'João Souza'],
        equipes: const ['Equipe Subestação Alpha'],
        frota: 'Hilux ABC-1234',
        coordenador: 'Marcos Coordenador',
        dataInicio: DateTime(2026, 9, 18, 8, 0),
        dataFim: DateTime(2026, 9, 18, 11, 30),
      ),
      Task(
        id: 't-2',
        tarefa: 'Inspeção Termográfica em Transformador T-02',
        tipo: 'TERM',
        status: 'PROG',
        statusNome: 'Programada',
        prioridade: 'Média',
        regional: 'Regional Norte',
        divisao: 'Divisão Manutenção',
        segmento: 'Subestações',
        locais: const ['SE Teresina II'],
        executores: const ['Carlos Silva', 'Marcos Lima'],
        equipes: const ['Equipe Subestação Alpha'],
        frota: 'Hilux ABC-1234',
        coordenador: 'Marcos Coordenador',
        dataInicio: DateTime(2026, 9, 18, 13, 30),
        dataFim: DateTime(2026, 9, 18, 17, 0),
        hasConflict: true,
      ),
      Task(
        id: 't-3',
        tarefa: 'Substituição de Cadeias de Isoladores Vão 23-24',
        tipo: 'LINHA',
        status: 'PROG',
        statusNome: 'Programada',
        prioridade: 'Alta',
        regional: 'Regional Norte',
        divisao: 'Linhas de Transmissão',
        segmento: 'LT 500kV',
        locais: const ['LT Teresina - Sobral II'],
        executores: const ['Roberto Silva', 'Felipe Santos'],
        equipes: const ['Equipe Linha Viva 02'],
        frota: 'Caminhão Munck BRA-2E19',
        coordenador: 'Marcos Coordenador',
        dataInicio: DateTime(2026, 9, 18, 8, 30),
        dataFim: DateTime(2026, 9, 18, 16, 0),
      ),
    ];
  }

  testWidgets('Capturar 01_agenda_today_timeline.png', (tester) async {
    final key = GlobalKey();
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: MobileScheduleScreen(
            initialDate: DateTime(2026, 9, 18),
            initialMode: MobileAgendaViewMode.timeline,
            preloadedTasks: buildSampleTasks(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await saveBoundary(tester, key, '01_agenda_today_timeline.png');
  });

  testWidgets('Capturar 02_agenda_by_teams.png', (tester) async {
    final key = GlobalKey();
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: MobileScheduleScreen(
            initialDate: DateTime(2026, 9, 18),
            initialMode: MobileAgendaViewMode.teams,
            preloadedTasks: buildSampleTasks(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await saveBoundary(tester, key, '02_agenda_by_teams.png');
  });

  testWidgets('Capturar 03_agenda_by_fleet.png', (tester) async {
    final key = GlobalKey();
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: MobileScheduleScreen(
            initialDate: DateTime(2026, 9, 18),
            initialMode: MobileAgendaViewMode.fleet,
            preloadedTasks: buildSampleTasks(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await saveBoundary(tester, key, '03_agenda_by_fleet.png');
  });

  testWidgets('Capturar 04_agenda_empty_day.png', (tester) async {
    final key = GlobalKey();
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: MobileScheduleScreen(
            initialDate: DateTime(2026, 9, 18),
            initialMode: MobileAgendaViewMode.timeline,
            preloadedTasks: const [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await saveBoundary(tester, key, '04_agenda_empty_day.png');
  });

  testWidgets('Capturar 05_agenda_dark_mode.png', (tester) async {
    final key = GlobalKey();
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          home: MobileScheduleScreen(
            initialDate: DateTime(2026, 9, 18),
            initialMode: MobileAgendaViewMode.timeline,
            preloadedTasks: buildSampleTasks(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await saveBoundary(tester, key, '05_agenda_dark_mode.png');
  });

  testWidgets('Capturar 06_agenda_large_text.png', (tester) async {
    final key = GlobalKey();
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              textScaler: TextScaler.linear(1.5),
            ),
            child: MobileScheduleScreen(
              initialDate: DateTime(2026, 9, 18),
              initialMode: MobileAgendaViewMode.timeline,
              preloadedTasks: buildSampleTasks(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await saveBoundary(tester, key, '06_agenda_large_text.png');
  });
}
