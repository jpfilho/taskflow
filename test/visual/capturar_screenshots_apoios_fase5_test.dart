import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/design_system/taskflow_design_system.dart';
import 'package:task2026/features/apoios_operacionais/presentation/task_apoio_ui_controller.dart';
import 'package:task2026/features/apoios_operacionais/presentation/views/central_apoios_view.dart';

const _outDir =
    '/Users/josepereiradasilvafilho/.gemini/antigravity/brain/2808d1d6-7029-4475-b85c-53d7dad9143d';

Future<void> _carregarFonteSistema() async {
  final file = File('/System/Library/Fonts/Supplemental/Arial.ttf');
  if (file.existsSync()) {
    final bytes = await file.readAsBytes();
    final byteData = ByteData.sublistView(bytes);
    final loader = FontLoader('Roboto')..addFont(Future.value(byteData));
    await loader.load();
  }
}

Future<void> _capturar(
  WidgetTester tester,
  GlobalKey key,
  String filename,
) async {
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$_outDir/$filename');
    await file.writeAsBytes(byteData!.buffer.asUint8List());
  });
}

Widget _appShell(
  GlobalKey key,
  Widget child, {
  ThemeData? theme,
}) {
  final base = theme ?? TaskFlowTheme.light();
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: 'Roboto'),
    ),
    home: RepaintBoundary(
      key: key,
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('Capturar screenshots reais Fase 5 — Central de Apoios', (tester) async {
    await tester.runAsync(_carregarFonteSistema);

    Future<void> setSize(Size s) async {
      tester.view.physicalSize = s;
      tester.view.devicePixelRatio = 1.0;
    }

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // 1. Central protegida (padrão sem auth verificável)
    await setSize(const Size(1280, 760));
    var key = GlobalKey();
    final ctrlProtegido = TaskApoioUiController();
    await tester.pumpWidget(
      _appShell(
        key,
        CentralApoiosView(
          controller: ctrlProtegido,
          usuarioAtualId: 'u1',
        ),
      ),
    );
    await _capturar(tester, key, 'fase5_01_central_protegida.png');

    // 2. Central em Desktop — Aba Recebidas + KPIs + Filtros (Modo Demo DEV)
    final ctrlDemo = TaskApoioUiController();
    await tester.runAsync(ctrlDemo.ativarModoDemonstracaoDev);
    key = GlobalKey();
    await tester.pumpWidget(
      _appShell(
        key,
        CentralApoiosView(
          controller: ctrlDemo,
          usuarioAtualId: 'demo-user-frota',
          usuarioAtualNome: 'Gestor Frota',
          divisaoAtualId: 'demo-div-frota',
          initialTabIndex: 0,
        ),
      ),
    );
    await _capturar(tester, key, 'fase5_02_central_recebidas_kpis.png');

    // 3. Aba Programados
    await tester.tap(find.textContaining('Programados ('));
    await _capturar(tester, key, 'fase5_03_central_programados.png');

    // 4. Aba Pendências e riscos
    await tester.tap(find.textContaining('Pendências e riscos ('));
    await _capturar(tester, key, 'fase5_04_central_pendencias_riscos.png');

    // 5. Mobile 390x844 + Tema Escuro
    await setSize(const Size(390, 844));
    key = GlobalKey();
    await tester.pumpWidget(
      _appShell(
        key,
        CentralApoiosView(
          controller: ctrlDemo,
          usuarioAtualId: 'demo-user-1',
          initialTabIndex: 3,
        ),
        theme: TaskFlowTheme.dark(),
      ),
    );
    await _capturar(tester, key, 'fase5_05_central_mobile_escuro.png');
  });
}

