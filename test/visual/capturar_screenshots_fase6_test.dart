import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:task2026/design_system/taskflow_design_system.dart';
import 'package:task2026/features/apoios_operacionais/data/repositories/task_apoio_offline_store.dart';
import 'package:task2026/features/apoios_operacionais/presentation/task_apoio_ui_controller.dart';
import 'package:task2026/features/apoios_operacionais/presentation/views/central_apoios_view.dart';
import 'package:task2026/features/apoios_operacionais/presentation/widgets/task_apoio_mensagens_dialog.dart';
import 'package:task2026/features/notificacoes/presentation/notificacoes_controller.dart';
import 'package:task2026/features/notificacoes/presentation/widgets/notificacoes_bell_button.dart';
import 'package:task2026/features/notificacoes/presentation/widgets/notificacoes_panel_dialog.dart';
import 'package:task2026/features/notificacoes/presentation/widgets/notificacoes_preferencias_dialog.dart';

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
  GlobalKey boundaryKey,
  String nomeArquivo,
) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.runAsync(() async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.5);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$_outDir/$nomeArquivo');
    await file.writeAsBytes(byteData!.buffer.asUint8List());
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Capturar screenshots da Fase 6', (tester) async {
    await _carregarFonteSistema();

    Future<void> setViewport(Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
    }

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // 1. Painel de Notificações + Sino com contador (Desktop claro)
    await setViewport(const Size(1280, 800));
    final notifCtrl = NotificacoesController(
      persistence: InMemoryApoioPersistence(),
    );
    notifCtrl.ativarModoDemonstracaoDev();
    final key1 = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: TaskFlowTheme.light(),
        home: RepaintBoundary(
          key: key1,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('TaskFlow — Atividades'),
              actions: [
                NotificacoesBellButton(
                  controller: notifCtrl,
                  onPressed: () {},
                ),
              ],
            ),
            body: Center(
              child: NotificacoesPanelDialog(controller: notifCtrl),
            ),
          ),
        ),
      ),
    );
    await _capturar(tester, key1, 'fase6_01_central_notificacoes_bell.png');

    // 2. Preferências de Notificações
    final key2 = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: TaskFlowTheme.light(),
        home: RepaintBoundary(
          key: key2,
          child: Scaffold(
            body: Center(
              child: NotificacoesPreferenciasDialog(controller: notifCtrl),
            ),
          ),
        ),
      ),
    );
    await _capturar(tester, key2, 'fase6_02_preferencias_notificacoes.png');

    // 3. Central de Apoios com indicadores nas abas
    final apoioCtrl = TaskApoioUiController(
      offlineStore: TaskApoioOfflineStore(),
    );
    await apoioCtrl.ativarModoDemonstracaoDev();
    final key3 = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: TaskFlowTheme.light(),
        home: RepaintBoundary(
          key: key3,
          child: Scaffold(
            body: CentralApoiosView(
              controller: apoioCtrl,
              usuarioAtualId: 'demo-user',
              usuarioAtualNome: 'Homologação DEV',
              divisaoAtualId: 'div-manut',
            ),
          ),
        ),
      ),
    );
    await _capturar(tester, key3, 'fase6_03_central_apoios_indicadores.png');

    // 4. Esclarecimentos operacionais (Chat isolado à solicitação)
    final key4 = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: TaskFlowTheme.light(),
        home: RepaintBoundary(
          key: key4,
          child: const Scaffold(
            body: Center(
              child: TaskApoioMensagensDialog(
                solicitacaoId: 'demo-sol-1',
                tituloSolicitacao: 'Caminhão Munck com operador',
                usuarioAtualId: 'demo-frota',
                usuarioAtualNome: 'Frota (Demo)',
                modoDemonstracao: true,
              ),
            ),
          ),
        ),
      ),
    );
    await _capturar(tester, key4, 'fase6_04_esclarecimentos_apoio.png');

    // 5. Mobile (390x844) + Tema Escuro
    await setViewport(const Size(390, 844));
    final key5 = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: TaskFlowTheme.dark(),
        home: RepaintBoundary(
          key: key5,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('TaskFlow'),
              actions: [
                NotificacoesBellButton(
                  controller: notifCtrl,
                  onPressed: () {},
                ),
              ],
            ),
            body: NotificacoesPanelDialog(controller: notifCtrl),
          ),
        ),
      ),
    );
    await _capturar(tester, key5, 'fase6_05_notificacoes_mobile_escuro.png');

    notifCtrl.dispose();
    apoioCtrl.dispose();
  });
}
