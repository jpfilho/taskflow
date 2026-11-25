import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:task2026/design_system/taskflow_design_system.dart';
import 'package:task2026/features/apoios_operacionais/data/repositories/task_apoio_offline_store.dart';
import 'package:task2026/features/apoios_operacionais/domain/models/task_apoio_situacao.dart';
import 'package:task2026/features/apoios_operacionais/presentation/task_apoio_ui_controller.dart';
import 'package:task2026/features/apoios_operacionais/presentation/views/apoios_gerencial_dashboard_view.dart';
import 'package:task2026/features/apoios_operacionais/presentation/views/central_apoios_view.dart';
import 'package:task2026/features/apoios_operacionais/presentation/widgets/gantt_integrado_apoios_widget.dart';

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
  String nome,
) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.5);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$_outDir/$nome');
    await file.writeAsBytes(byteData!.buffer.asUint8List());
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Capturar screenshots reais da Fase 7', (tester) async {
    await tester.runAsync(_carregarFonteSistema);

    final ctrl = TaskApoioUiController(
      offlineStore: TaskApoioOfflineStore(),
    );
    await tester.runAsync(ctrl.ativarModoDemonstracaoDev);
    final sols = await tester.runAsync(() => ctrl.service.buscarSolicitacoes());
    final sits = <String, TaskApoioSituacao>{};
    for (final s in sols!) {
      sits[s.id] =
          (await tester.runAsync(() => ctrl.avaliarSituacao(s)))!;
    }

    Future<void> setSize(Size s) async {
      tester.view.physicalSize = s;
      tester.view.devicePixelRatio = 1.0;
    }

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // 1. Gantt Integrado Desktop Claro (múltiplos apoios, lacuna, compartilhado)
    await setSize(const Size(1280, 800));
    final key1 = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: TaskFlowTheme.light(),
        home: RepaintBoundary(
          key: key1,
          child: Scaffold(
            body: GanttIntegradoApoiosWidget(
              controller: ctrl,
              atividadesPrincipais: ctrl.tasksConhecidas.values.take(4).toList(),
              usuarioAtualId: 'demo-user',
            ),
          ),
        ),
      ),
    );
    await _capturar(
        tester, key1, 'fase7_01_gantt_integrado_multiplos_apoios.png');

    // 2. Painel Gerencial + Distribuição + Reunião Semanal
    final key2 = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: TaskFlowTheme.light(),
        home: RepaintBoundary(
          key: key2,
          child: Scaffold(
            body: ApoiosGerencialDashboardView(
              controller: ctrl,
              solicitacoes: sols,
              situacoes: sits,
              usuarioAtualId: 'demo-user',
            ),
          ),
        ),
      ),
    );
    await _capturar(tester, key2, 'fase7_02_painel_gerencial_reuniao.png');

    // 3. Central de Apoios com aba Gestão & Reunião e botão Gantt Integrado
    final key3 = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: TaskFlowTheme.light(),
        home: RepaintBoundary(
          key: key3,
          child: Scaffold(
            body: CentralApoiosView(
              controller: ctrl,
              usuarioAtualId: 'demo-user',
              usuarioAtualNome: 'Homologação DEV',
            ),
          ),
        ),
      ),
    );
    await _capturar(tester, key3, 'fase7_03_central_com_aba_gestao.png');

    // 4. Mobile (390x844) + Tema Escuro no Gantt Integrado
    await setSize(const Size(390, 844));
    final key4 = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: TaskFlowTheme.dark(),
        home: RepaintBoundary(
          key: key4,
          child: Scaffold(
            body: GanttIntegradoApoiosWidget(
              controller: ctrl,
              atividadesPrincipais: ctrl.tasksConhecidas.values.take(3).toList(),
              usuarioAtualId: 'demo-user',
            ),
          ),
        ),
      ),
    );
    await _capturar(tester, key4, 'fase7_04_gantt_mobile_escuro.png');
  });
}

