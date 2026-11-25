import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:task2026/design_system/theme/taskflow_theme.dart';
import 'package:task2026/features/apoios_operacionais/presentation/task_apoio_ui_controller.dart';
import 'package:task2026/features/apoios_operacionais/presentation/views/central_apoios_view.dart';
import 'package:task2026/features/apoios_operacionais/presentation/widgets/task_apoio_solicitar_dialog.dart';
import 'package:task2026/features/apoios_operacionais/presentation/widgets/task_apoio_vincular_dialog.dart';

const _outDir =
    '/Users/josepereiradasilvafilho/.gemini/antigravity/brain/2808d1d6-7029-4475-b85c-53d7dad9143d';

Future<void> _carregarFonteSistema() async {
  final file = File('/System/Library/Fonts/Supplemental/Arial.ttf');
  if (file.existsSync()) {
    final bytes = file.readAsBytesSync();
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
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.5);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$_outDir/$filename')
        .writeAsBytes(byteData!.buffer.asUint8List());
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Capturar screenshots UX/UI da nova Central de Apoios', (
    tester,
  ) async {
    await _carregarFonteSistema();
    Future<void> setSize(Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
    }

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final ctrl = TaskApoioUiController();
    await ctrl.ativarModoDemonstracaoDev();
    ctrl.registrarNomesUnidades({
      'demo-reg-1': 'Regional Sul (Demo)',
      'demo-div-frota': 'Divisão de Frota (Demo)',
      'demo-div-manut': 'Divisão de Manutenção (Demo)',
    });
    final pIni = DateTime(2026, 11, 1);
    final pFim = DateTime(2026, 11, 30);

    // 1. Desktop 1920x1080 — Central com tabela ocupando 100% (painel fechado)
    await setSize(const Size(1920, 1080));
    final key1 = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: TaskFlowTheme.light(),
        home: RepaintBoundary(
          key: key1,
          child: Scaffold(
            body: CentralApoiosView(
              controller: ctrl,
              usuarioAtualId: 'demo-user-1',
              usuarioAtualNome: 'Gestor Planejamento',
              regionalAtualId: 'demo-reg-1',
              divisaoAtualId: 'demo-div-frota',
              periodoInicio: pIni,
              periodoFim: pFim,
            ),
          ),
        ),
      ),
    );
    await _capturar(tester, key1, 'ux_01_central_desktop_1920_fechado.png');

    // 2. Desktop 1366x768 — Central com painel lateral de detalhamento aberto
    await setSize(const Size(1366, 768));
    final key2 = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: TaskFlowTheme.light(),
        home: RepaintBoundary(
          key: key2,
          child: Scaffold(
            body: CentralApoiosView(
              controller: ctrl,
              usuarioAtualId: 'demo-user-1',
              usuarioAtualNome: 'Gestor Planejamento',
              regionalAtualId: 'demo-reg-1',
              divisaoAtualId: 'demo-div-frota',
              periodoInicio: pIni,
              periodoFim: pFim,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('[DEMONSTRAÇÃO] Trator para roço de faixa'));
    await _capturar(tester, key2, 'ux_02_central_desktop_1366_painel_aberto.png');

    // 3. Desktop 1280x800 — Tema Escuro
    await setSize(const Size(1280, 800));
    final key3 = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        key: const ValueKey('app_dark'),
        themeAnimationDuration: Duration.zero,
        theme: TaskFlowTheme.dark(),
        home: RepaintBoundary(
          key: key3,
          child: Scaffold(
            body: CentralApoiosView(
              controller: ctrl,
              usuarioAtualId: 'demo-user-1',
              usuarioAtualNome: 'Gestor Planejamento',
              regionalAtualId: 'demo-reg-1',
              divisaoAtualId: 'demo-div-frota',
              periodoInicio: pIni,
              periodoFim: pFim,
              initialTabIndex: 3,
            ),
          ),
        ),
      ),
    );
    await _capturar(tester, key3, 'ux_03_central_desktop_1280_tema_escuro.png');

    // 4. Desktop 1280x800 — Tema Axia
    final key4 = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        key: const ValueKey('app_axia'),
        themeAnimationDuration: Duration.zero,
        theme: TaskFlowTheme.axia(),
        home: RepaintBoundary(
          key: key4,
          child: Scaffold(
            body: CentralApoiosView(
              controller: ctrl,
              usuarioAtualId: 'demo-user-1',
              usuarioAtualNome: 'Gestor Planejamento',
              regionalAtualId: 'demo-reg-1',
              divisaoAtualId: 'demo-div-frota',
              periodoInicio: pIni,
              periodoFim: pFim,
            ),
          ),
        ),
      ),
    );
    await _capturar(tester, key4, 'ux_04_central_desktop_axia.png');

    // 5. Mobile 390x844 — Cards compactos em Tema Claro e Escuro
    await setSize(const Size(390, 844));
    final key5 = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        key: const ValueKey('app_mobile_dark'),
        themeAnimationDuration: Duration.zero,
        theme: TaskFlowTheme.dark(),
        home: RepaintBoundary(
          key: key5,
          child: Scaffold(
            body: CentralApoiosView(
              controller: ctrl,
              usuarioAtualId: 'demo-user-1',
              regionalAtualId: 'demo-reg-1',
              divisaoAtualId: 'demo-div-frota',
              periodoInicio: pIni,
              periodoFim: pFim,
            ),
          ),
        ),
      ),
    );
    await _capturar(tester, key5, 'ux_05_central_mobile_390_escuro.png');

    // 6. Formulário de Solicitação de Apoio (1280x800)
    await setSize(const Size(1280, 800));
    final key6 = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: TaskFlowTheme.light(),
        home: RepaintBoundary(
          key: key6,
          child: Scaffold(
            body: Center(
              child: TaskApoioSolicitarDialog(
                taskSolicitanteTitulo: 'Manutenção Preventiva SE Teresina',
                regionalSolicitanteId: 'demo-reg-1',
                divisaoSolicitanteId: 'demo-div-manut',
                usuarioSolicitanteId: 'demo-user-1',
                dataInicioSugerida: DateTime(2026, 11, 20, 8),
                dataFimSugerida: DateTime(2026, 11, 22, 17),
                tiposApoio: ctrl.tiposAtivos,
                regionais: const [
                  TaskApoioUnidadeOpcao(id: 'demo-reg-1', nome: 'Teresina'),
                ],
                divisoes: const [
                  TaskApoioUnidadeOpcao(
                    id: 'demo-div-frota',
                    nome: 'NEPTRFMT',
                    parentId: 'demo-reg-1',
                  ),
                ],
                segmentos: const [
                  TaskApoioUnidadeOpcao(
                    id: 'seg-lt',
                    nome: 'Linhas de Transmissão',
                    parentId: 'demo-div-frota',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await _capturar(tester, key6, 'ux_06_formulario_solicitacao.png');

    // 7. Diálogo de Vinculação Existente (1280x800)
    final key7 = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: TaskFlowTheme.light(),
        home: RepaintBoundary(
          key: key7,
          child: Scaffold(
            body: Center(
              child: TaskApoioVincularDialog(
                taskPrincipalId: 'demo-task-1',
                divisaoPrincipalId: 'demo-div-manut',
                onBuscarAtividades: ({
                  String? termo,
                  String? regional,
                  String? divisao,
                  String? status,
                  int limit = 20,
                  int offset = 0,
                }) async =>
                    ctrl.tasksConhecidas.values.toList(),
              ),
            ),
          ),
        ),
      ),
    );
    await _capturar(tester, key7, 'ux_07_formulario_vinculacao.png');
  });
}

