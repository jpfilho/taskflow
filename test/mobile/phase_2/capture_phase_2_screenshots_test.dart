import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:task2026/mobile/shell/mobile_shell.dart';
import 'package:task2026/mobile/shell/widgets/tf_field_quick_actions_sheet.dart';
import 'package:task2026/mobile/core/navigation/tf_mobile_navigator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: 'http://212.85.0.249:8000',
        anonKey:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzY1ODE3OTgzLCJleHAiOjIwODExNzc5ODN9.YQByqDrpmw0en7VeEcjDfvvTx8Ind_q8gD6-bzEY4Yc',
      );
    } catch (_) {}
  });

  final outDir = Directory('docs/mobile_redesign/phase_2/screenshots');
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }

  Future<void> saveBoundary(WidgetTester tester, GlobalKey key, String filename) async {
    await tester.runAsync(() async {
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 1.5);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          File('${outDir.path}/$filename').writeAsBytesSync(byteData.buffer.asUint8List());
        }
      }
    });
  }

  testWidgets('01_today_screen', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
        home: RepaintBoundary(
          key: key,
          child: TFMobileShell(onLogout: () {}),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await saveBoundary(tester, key, '01_today_screen.png');
  });

  testWidgets('02_tasks_tab', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
        home: RepaintBoundary(
          key: key,
          child: TFMobileShell(onLogout: () {}),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Atividades'));
    await tester.pump(const Duration(milliseconds: 200));
    await saveBoundary(tester, key, '02_tasks_tab.png');
  });

  testWidgets('03_field_quick_actions', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.black45,
          body: Align(
            alignment: Alignment.bottomCenter,
            child: RepaintBoundary(
              key: key,
              child: Builder(
                builder: (ctx) => TFFieldQuickActionsSheet(
                  navigator: TFMobileNavigator(context: ctx),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await saveBoundary(tester, key, '03_field_quick_actions.png');
  });

  testWidgets('04_feed_stream', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
        home: RepaintBoundary(
          key: key,
          child: TFMobileShell(onLogout: () {}),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Feed'));
    await tester.pump(const Duration(milliseconds: 200));
    await saveBoundary(tester, key, '04_feed_stream.png');
  });

  testWidgets('06_messages_tab', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
        home: RepaintBoundary(
          key: key,
          child: TFMobileShell(onLogout: () {}),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Feed'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Mensagens'));
    await tester.pump(const Duration(milliseconds: 200));
    await saveBoundary(tester, key, '06_messages_tab.png');
  });

  testWidgets('07_more_screen', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
        home: RepaintBoundary(
          key: key,
          child: TFMobileShell(onLogout: () {}),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Mais'));
    await tester.pump(const Duration(milliseconds: 200));
    await saveBoundary(tester, key, '07_more_screen.png');
  });

  testWidgets('09_dark_mode', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
        home: RepaintBoundary(
          key: key,
          child: TFMobileShell(onLogout: () {}),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await saveBoundary(tester, key, '09_dark_mode.png');
  });

  testWidgets('10_large_text_accessibility', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final key = GlobalKey();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          textScaler: TextScaler.linear(1.4),
        ),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
          home: RepaintBoundary(
            key: key,
            child: TFMobileShell(onLogout: () {}),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await saveBoundary(tester, key, '10_large_text_accessibility.png');
  });
}
