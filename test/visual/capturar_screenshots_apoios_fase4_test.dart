import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:task2026/design_system/taskflow_design_system.dart';
import 'package:task2026/features/apoios_operacionais/domain/models/task_apoio_tipo.dart';
import 'package:task2026/features/apoios_operacionais/presentation/task_apoio_ui_controller.dart';
import 'package:task2026/features/apoios_operacionais/presentation/widgets/task_apoio_banner_estado.dart';
import 'package:task2026/features/apoios_operacionais/presentation/widgets/task_apoio_solicitar_dialog.dart';
import 'package:task2026/features/apoios_operacionais/presentation/widgets/task_apoio_view_section.dart';
import 'package:task2026/features/apoios_operacionais/presentation/widgets/task_apoio_vincular_dialog.dart';
import 'package:task2026/models/task.dart';
import 'package:task2026/models/task_table_column.dart';
import 'package:task2026/widgets/task_form_dialog.dart';
import 'package:task2026/widgets/task_table.dart';
import 'package:task2026/widgets/task_view_dialog.dart';

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
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pump(const Duration(milliseconds: 250));
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
  bool wrapScroll = false,
}) {
  final base = theme ?? TaskFlowTheme.light();
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: 'Roboto'),
    ),
    home: RepaintBoundary(
      key: key,
      child: Scaffold(
        body: wrapScroll
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(child: child),
              )
            : child,
      ),
    ),
  );
}

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

  testWidgets('Capturar screenshots reais integradas Fase 4 — Apoios Operacionais', (tester) async {
    await tester.runAsync(_carregarFonteSistema);

    final ctrlDemo = TaskApoioUiController();
    await tester.runAsync(ctrlDemo.ativarModoDemonstracaoDev);

    Future<void> setSize(Size s) async {
      tester.view.physicalSize = s;
      tester.view.devicePixelRatio = 1.0;
    }

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final taskA = ctrlDemo.tasksConhecidas['demo-task-a']!;
    final taskB = ctrlDemo.tasksConhecidas['demo-task-b']!;
    final taskD = ctrlDemo.tasksConhecidas['demo-task-d']!;
    final taskH = ctrlDemo.tasksConhecidas['demo-task-h']!;
    final taskMunck = ctrlDemo.tasksConhecidas['demo-task-a-munck']!;

    // 1. TaskFormDialog REAL sem apoios (Cenário H)
    await setSize(const Size(1180, 860));
    var key = GlobalKey();
    await tester.pumpWidget(
      _appShell(
        key,
        TaskFormDialog(
          task: taskH,
          startDate: taskH.dataInicio,
          endDate: taskH.dataFim,
          apoioController: ctrlDemo,
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
    await tester.pump();
    final secH = find.text('Apoios Operacionais (opcional)');
    if (secH.evaluate().isNotEmpty) {
      await tester.ensureVisible(secH.first);
    }
    await _capturar(tester, key, 'apoios_01_form_sem_apoios.png');

    // 2. TaskFormDialog REAL com apoios expandido (Cenário A)
    key = GlobalKey();
    await tester.pumpWidget(
      _appShell(
        key,
        TaskFormDialog(
          task: taskA,
          startDate: taskA.dataInicio,
          endDate: taskA.dataFim,
          apoioController: ctrlDemo,
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
    await tester.pump();
    final secFinder = find.text('Apoios Operacionais (opcional)');
    if (secFinder.evaluate().isNotEmpty) {
      await tester.ensureVisible(secFinder.first);
      await tester.tap(secFinder.first);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.ensureVisible(secFinder.first);
    }
    await _capturar(tester, key, 'apoios_02_form_com_apoios.png');

    // 3. Solicitação de apoio + 4. Opções adicionais
    await setSize(const Size(720, 780));
    key = GlobalKey();
    await tester.pumpWidget(
      _appShell(
        key,
        TaskApoioSolicitarDialog(
          taskSolicitanteTitulo: 'Manutenção de Disjuntor SE Boa Vista',
          regionalSolicitanteId: 'r1',
          divisaoSolicitanteId: 'd1',
          usuarioSolicitanteId: 'u1',
          dataInicioSugerida: DateTime.utc(2026, 11, 23, 8),
          dataFimSugerida: DateTime.utc(2026, 11, 25, 17),
          localSugerido: 'SE Boa Vista',
          tiposApoio: const [
            TaskApoioTipo(id: 't1', codigo: 'FROTA_VEICULOS', nome: 'Frota e veículos'),
          ],
          regionais: const [
            TaskApoioUnidadeOpcao(id: 'r1', nome: 'Regional Sul'),
          ],
          divisoes: const [
            TaskApoioUnidadeOpcao(id: 'd2', nome: 'Divisão de Frota', parentId: 'r1'),
          ],
          segmentos: const [
            TaskApoioUnidadeOpcao(id: 's1', nome: 'Pesados / Munck', parentId: 'd2'),
          ],
        ),
        wrapScroll: true,
      ),
    );
    await _capturar(tester, key, 'apoios_03_solicitar_apoio.png');

    await setSize(const Size(720, 940));
    await tester.tap(find.text('Opções adicionais (opcional)'));
    await _capturar(tester, key, 'apoios_04_opcoes_adicionais.png');

    // 5. Vinculação de atividade existente
    await setSize(const Size(760, 680));
    key = GlobalKey();
    await tester.pumpWidget(
      _appShell(
        key,
        TaskApoioVincularDialog(
          taskPrincipalId: 'demo-task-a',
          divisaoPrincipalId: 'demo-div-manut',
          onBuscarAtividades: ({
            String? termo,
            String? regional,
            String? divisao,
            String? status,
            int limit = 20,
            int offset = 0,
          }) async =>
              [taskMunck, ctrlDemo.tasksConhecidas['demo-task-b1']!],
        ),
        wrapScroll: true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.textContaining('Caminhão Munck 12t'));
    await _capturar(tester, key, 'apoios_05_vincular_existente.png');

    // 6. TaskViewDialog REAL de atividade solicitante (Cenário D múltiplas divisões)
    await setSize(const Size(1280, 900));
    key = GlobalKey();
    await tester.pumpWidget(
      _appShell(
        key,
        TaskViewDialog(
          task: taskD,
          apoioController: ctrlDemo,
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
    await tester.pump();
    final apoioTitle1 = find.text('Apoios Operacionais');
    if (apoioTitle1.evaluate().isNotEmpty) {
      await tester.ensureVisible(apoioTitle1.first);
      await tester.pump();
    }
    await _capturar(tester, key, 'apoios_06_view_solicitante.png');

    // 7. TaskViewDialog REAL de atividade prestadora de apoio (Cenário E compartilhado)
    key = GlobalKey();
    await tester.pumpWidget(
      _appShell(
        key,
        TaskViewDialog(
          task: taskMunck,
          apoioController: ctrlDemo,
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
    await tester.pump();
    final apoioTitle2 = find.text('Apoios Operacionais');
    if (apoioTitle2.evaluate().isNotEmpty) {
      await tester.ensureVisible(apoioTitle2.first);
      await tester.pump();
    }
    await _capturar(tester, key, 'apoios_07_view_prestadora.png');

    // 8. TaskTable REAL com coluna "Apoios" visível e carregamento em lote
    await setSize(const Size(1360, 560));
    await tester.runAsync(() => TaskTableColumnService.instance.saveColumns({
      TaskTableColumn.status,
      TaskTableColumn.local,
      TaskTableColumn.tarefa,
      TaskTableColumn.frota,
      TaskTableColumn.apoios,
    }));
    final scrollCtrl = ScrollController();
    addTearDown(scrollCtrl.dispose);
    key = GlobalKey();
    await tester.pumpWidget(
      _appShell(
        key,
        TaskTable(
          tasks: [taskA, taskB, taskD, taskMunck, taskH],
          scrollController: scrollCtrl,
          apoioController: ctrlDemo,
          currentUserId: 'demo-user-1',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await _capturar(tester, key, 'apoios_08_indicadores_tabela.png');

    // 9. Detalhamento de apoio parcialmente programado + 10. Histórico
    await setSize(const Size(960, 740));
    key = GlobalKey();
    await tester.pumpWidget(
      _appShell(
        key,
        TaskApoioViewSection(
          task: taskB,
          controller: ctrlDemo,
          usuarioAtualId: 'demo-user-1',
        ),
        wrapScroll: true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await _capturar(tester, key, 'apoios_09_parcial_lacuna.png');

    await tester.tap(find.text('Detalhes e histórico'));
    await _capturar(tester, key, 'apoios_10_historico.png');

    // 11. Estados de indisponibilidade
    await setSize(const Size(900, 380));
    key = GlobalKey();
    await tester.pumpWidget(
      _appShell(
        key,
        Column(
          children: [
            TaskApoioBannerEstado(
              estado: TaskApoioDisponibilidadeEstado.autenticacaoPendente,
              onAtivarDemo: () {},
            ),
            const SizedBox(height: 12),
            TaskApoioBannerEstado(
              estado: TaskApoioDisponibilidadeEstado.backendIndisponivel,
              mensagemErro: 'Timeout ao consultar servidor DEV.',
              onTentarNovamente: () {},
            ),
          ],
        ),
        wrapScroll: true,
      ),
    );
    await _capturar(tester, key, 'apoios_11_indisponibilidade.png');

    // 12. Interface em tela de dimensão reduzida (mobile 390x844, tema escuro)
    await setSize(const Size(390, 844));
    key = GlobalKey();
    await tester.pumpWidget(
      _appShell(
        key,
        TaskApoioViewSection(
          task: taskB,
          controller: ctrlDemo,
          usuarioAtualId: 'demo-user-1',
        ),
        theme: TaskFlowTheme.dark(),
        wrapScroll: true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await _capturar(tester, key, 'apoios_12_mobile_reduzida.png');
  });
}
