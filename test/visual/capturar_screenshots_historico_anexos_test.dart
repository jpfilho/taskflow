import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/design_system/theme/taskflow_theme_extension.dart';
import 'package:task2026/models/nota_sap.dart';
import 'package:task2026/models/nota_sap_analise.dart';
import 'package:task2026/models/nota_sap_analise_evidencia.dart';
import 'package:task2026/models/nota_historico_tecnico.dart';
import 'package:task2026/models/nota_historico_visual.dart';
import 'package:task2026/widgets/nota_workspace/nota_workspace_historico_anexos_section.dart';
import 'package:task2026/widgets/nota_workspace/nota_anexo_viewer_dialog.dart';
import 'package:task2026/services/nota_historico_tecnico_service.dart';
import 'package:task2026/services/nota_historico_visual_service.dart';
import 'package:task2026/services/nota_sap_analise_service.dart';

class MockNotaHistoricoTecnicoService extends NotaHistoricoTecnicoService {
  final Future<NotaHistoricoTecnicoResultado> Function(NotaSAP nota)? onCarregarUtil;
  final Future<NotaHistoricoTecnicoItem> Function(NotaHistoricoTecnicoItem item)? onLazy;

  MockNotaHistoricoTecnicoService({
    this.onCarregarUtil,
    this.onLazy,
  });

  @override
  Future<NotaHistoricoTecnicoResultado> carregarHistoricoAtivoUtil({
    required NotaSAP notaReferencia,
    bool forceRefresh = false,
  }) async {
    if (onCarregarUtil != null) {
      return onCarregarUtil!(notaReferencia);
    }
    return NotaHistoricoTecnicoResultado(
      notaReferencia: notaReferencia,
      calculadoEm: DateTime.now(),
    );
  }

  @override
  Future<NotaHistoricoTecnicoResultado> carregarSimilaresAssincrono(
    NotaHistoricoTecnicoResultado resultadoAtual, {
    bool forceRefresh = false,
  }) async {
    return resultadoAtual;
  }

  @override
  Future<NotaHistoricoTecnicoItem> carregarDetalhesLazy(
    NotaHistoricoTecnicoItem item,
  ) async {
    if (onLazy != null) return onLazy!(item);
    return item;
  }
}

class MockNotaHistoricoVisualService extends NotaHistoricoVisualService {
  final Future<HistoricoVisualResultado> Function(NotaSAP nota)? onBuscar;

  MockNotaHistoricoVisualService({this.onBuscar});

  @override
  Future<HistoricoVisualResultado> buscarHistoricoVisual(
    NotaSAP nota, {
    int limitePorNivel = 12,
  }) async {
    if (onBuscar != null) return onBuscar!(nota);
    return HistoricoVisualResultado.vazio(localNome: nota.local);
  }
}

class MockNotaSapAnaliseService extends Fake implements NotaSapAnaliseService {
  final List<NotaSapAnexo> anexos = [];

  MockNotaSapAnaliseService([List<NotaSapAnexo>? anexosIniciais]) {
    if (anexosIniciais != null) {
      anexos.addAll(anexosIniciais);
    }
  }

  @override
  Future<List<NotaSapAnexo>> listarAnexos(String notaSapId) async {
    return List.from(anexos);
  }

  @override
  Future<Map<String, List<NotaTipoVinculoEvidencia>>> buscarUsoDosAnexos(
      String notaSapId) async {
    return {};
  }

  @override
  Future<Map<String, List<NotaTipoVinculoEvidencia>>> buscarUsoDosAnexosHistoricos(
      String notaSapId) async {
    return {};
  }

  @override
  Future<String> obterUrlAssinada(
    NotaSapAnexo anexo, {
    Duration expires = const Duration(hours: 1),
  }) async {
    return 'https://storage.local/test/${anexo.caminhoArquivo}';
  }

  @override
  Future<Map<String, List<NotaTipoVinculoEvidencia>>> buscarUsoDasFotosDoAlbum(String notaId) async {
    return {};
  }
}

Widget _wrapComTema(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      extensions: [
        TaskFlowThemeExtension.light(),
      ],
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        child: child,
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    final dir = Directory('docs/screenshots_validacao_historico_anexos');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
  });

  Future<void> capturePng(WidgetTester tester, GlobalKey key, String filename) async {
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 100));
      final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();
      final file = File('docs/screenshots_validacao_historico_anexos/$filename');
      file.writeAsBytesSync(pngBytes);
    });
  }

  final notaAtual = NotaSAP(
    id: 'nota-atual-11598127',
    nota: '11598127',
    descricao: 'ROÇAR PRAÇA DE TORRE E INSPEÇÃO ESTRUTURA',
    equipamento: '11776176',
    localInstalacao: 'H-L-STSDSTSA-RB4L03-4LT1',
    local: 'STSDSTSA RB4L03',
    sala: '002/3',
    centroTrabalhoResponsavel: 'MNLT.TSA',
    tipo: 'NM',
    criadoEm: DateTime(2026, 8, 15),
  );

  final notaHistorica1 = NotaSAP(
    id: 'nota-hist-11524543',
    nota: '11524543',
    descricao: 'TR- VEGETACAO SOB FASES 1° TERÇO DO VÃO',
    equipamento: '11776176',
    localInstalacao: 'H-L-STSDSTSA-RB4L03-4LT1',
    local: 'STSDSTSA RB4L03',
    sala: '002/3',
    tipo: 'NM',
    criadoEm: DateTime(2026, 2, 20),
  );

  final anexoHist1 = NotaSapAnexo(
    id: 'anexo-hist-1',
    notaSapId: 'nota-hist-11524543',
    nomeArquivo: 'sap_1793448931_1_11524543_Fase1.jpg',
    nomeOriginal: '11524543_Fase1.jpg',
    tipoArquivo: NotaAnexoTipo.imagem,
    caminhoArquivo: 'nota-hist-11524543/sap_1793448931_1_11524543_Fase1.jpg',
    tamanhoBytes: 320000,
    legenda: 'Registro histórico SAP de poda anterior',
    origem: 'SAP',
  );

  final notaHistorica2 = NotaSAP(
    id: 'nota-hist-11474484',
    nota: '11474484',
    descricao: 'PRI: 04T5 - GOTEJAMENTO DE ÓLEO',
    equipamento: '11348129',
    localInstalacao: 'H-S-SPRI-RB4T05-4EQ1-TR01',
    local: 'SPRI',
    sala: '04T5',
    tipo: 'NM',
    criadoEm: DateTime(2025, 10, 3),
  );

  final anexoHistPdf = NotaSapAnexo(
    id: 'anexo-hist-pdf',
    notaSapId: 'nota-hist-11474484',
    nomeArquivo: 'sap_1793442313_2_11474484_Laudo_Tecnico.pdf',
    nomeOriginal: 'Laudo Pericial PRI 04T5.pdf',
    tipoArquivo: NotaAnexoTipo.pdf,
    caminhoArquivo: 'nota-hist-11474484/sap_1793442313_2_11474484_Laudo_Tecnico.pdf',
    tamanhoBytes: 1250000,
    legenda: 'Laudo técnico de ensaio cromatográfico e gotejamento',
    origem: 'SAP',
  );

  final itemHist1 = NotaHistoricoTecnicoItem(
    notaSap: notaHistorica1,
    criterioFisicoPrincipal: NotaHistoricoCriterioFisico.mesmoEquipamento,
    totalAnexos: 1,
    anexos: [anexoHist1],
  );

  final itemHistPdf = NotaHistoricoTecnicoItem(
    notaSap: notaHistorica2,
    criterioFisicoPrincipal: NotaHistoricoCriterioFisico.mesmaEstrutura,
    totalAnexos: 1,
    anexos: [anexoHistPdf],
  );

  const histVisualResultado = HistoricoVisualResultado(
    itens: [],
    totalEquipamento: 0,
    totalSala: 3,
    totalLocal: 2,
    localNome: 'STSDSTSA RB4L03',
  );

  testWidgets('1. Captura Desktop — Notas Anteriores (1400x900)', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final key = GlobalKey();

    final techService = MockNotaHistoricoTecnicoService(
      onCarregarUtil: (n) async => NotaHistoricoTecnicoResultado(
        notaReferencia: n,
        calculadoEm: DateTime.now(),
        itensEquipamento: [itemHist1],
        itensEstrutura: [itemHistPdf],
        todosItensDeduplicados: [itemHist1, itemHistPdf],
      ),
      onLazy: (item) async {
        if (item.notaSap.id == notaHistorica1.id) return itemHist1;
        if (item.notaSap.id == notaHistorica2.id) return itemHistPdf;
        return item;
      },
    );

    final visualService = MockNotaHistoricoVisualService(
      onBuscar: (_) async => histVisualResultado,
    );

    await tester.pumpWidget(
      _wrapComTema(
        RepaintBoundary(
          key: key,
          child: Container(
            width: 600,
            padding: const EdgeInsets.all(16),
            child: NotaWorkspaceHistoricoAnexosSection(
              nota: notaAtual,
              historicoTecnicoService: techService,
              historicoVisualService: visualService,
              analiseService: MockNotaSapAnaliseService(),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await capturePng(tester, key, '01_desktop_notas_anteriores.png');
    expect(find.text('Notas Anteriores'), findsOneWidget);
  });

  testWidgets('2. Captura Desktop — Álbuns de Campo selecionado (1400x900)', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final key = GlobalKey();

    final techService = MockNotaHistoricoTecnicoService(
      onCarregarUtil: (n) async => NotaHistoricoTecnicoResultado(
        notaReferencia: n,
        calculadoEm: DateTime.now(),
        itensEquipamento: [itemHist1],
        todosItensDeduplicados: [itemHist1],
      ),
      onLazy: (item) async => itemHist1,
    );

    final visualService = MockNotaHistoricoVisualService(
      onBuscar: (_) async => histVisualResultado,
    );

    await tester.pumpWidget(
      _wrapComTema(
        RepaintBoundary(
          key: key,
          child: Container(
            width: 600,
            padding: const EdgeInsets.all(16),
            child: NotaWorkspaceHistoricoAnexosSection(
              nota: notaAtual,
              historicoTecnicoService: techService,
              historicoVisualService: visualService,
              analiseService: MockNotaSapAnaliseService(),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Clica no seletor 'Álbuns de Campo'
    await tester.tap(find.text('Álbuns de Campo'));
    await tester.pumpAndSettle();

    await capturePng(tester, key, '02_desktop_albuns_selecionado.png');
  });

  testWidgets('3. Captura Desktop — Ambos Vazios (Vazio Total) (1400x900)', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final key = GlobalKey();

    final techService = MockNotaHistoricoTecnicoService(
      onCarregarUtil: (n) async => NotaHistoricoTecnicoResultado(
        notaReferencia: n,
        calculadoEm: DateTime.now(),
        itensEquipamento: [],
        itensEstrutura: [],
        todosItensDeduplicados: [],
      ),
    );
    final visualService = MockNotaHistoricoVisualService(
      onBuscar: (_) async => const HistoricoVisualResultado(
        itens: [],
        totalEquipamento: 0,
        totalSala: 0,
        totalLocal: 0,
        localNome: 'Vazio Total',
      ),
    );

    await tester.pumpWidget(
      _wrapComTema(
        RepaintBoundary(
          key: key,
          child: Container(
            width: 600,
            padding: const EdgeInsets.all(16),
            child: NotaWorkspaceHistoricoAnexosSection(
              nota: notaAtual,
              historicoTecnicoService: techService,
              historicoVisualService: visualService,
              analiseService: MockNotaSapAnaliseService(),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await capturePng(tester, key, '03_desktop_ambos_vazios.png');
    expect(find.text('Nenhum anexo histórico encontrado para este ativo/local.'), findsOneWidget);
  });

  testWidgets('4. Captura Desktop Médio (1024x768)', (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final key = GlobalKey();

    final techService = MockNotaHistoricoTecnicoService(
      onCarregarUtil: (n) async => NotaHistoricoTecnicoResultado(
        notaReferencia: n,
        calculadoEm: DateTime.now(),
        itensEquipamento: [itemHist1],
        itensEstrutura: [itemHistPdf],
        todosItensDeduplicados: [itemHist1, itemHistPdf],
      ),
      onLazy: (item) async {
        if (item.notaSap.id == notaHistorica1.id) return itemHist1;
        if (item.notaSap.id == notaHistorica2.id) return itemHistPdf;
        return item;
      },
    );
    final visualService = MockNotaHistoricoVisualService(
      onBuscar: (_) async => histVisualResultado,
    );

    await tester.pumpWidget(
      _wrapComTema(
        RepaintBoundary(
          key: key,
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(16),
            child: NotaWorkspaceHistoricoAnexosSection(
              nota: notaAtual,
              historicoTecnicoService: techService,
              historicoVisualService: visualService,
              analiseService: MockNotaSapAnaliseService(),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await capturePng(tester, key, '04_desktop_medio_1024.png');
  });

  testWidgets('5. Captura Mobile — Botão Histórico (390x844)', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final key = GlobalKey();

    await tester.pumpWidget(
      _wrapComTema(
        RepaintBoundary(
          key: key,
          child: Container(
            width: 390,
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Anexos da Nota Atual (2)'),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.history),
                      label: const Text('Ver Histórico de Anexos (2)'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await capturePng(tester, key, '05_mobile_botao_historico.png');
    expect(find.textContaining('Ver Histórico de Anexos'), findsOneWidget);
  });

  testWidgets('6. Captura Mobile — Histórico Aberto em Bottom Sheet (390x844)', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final key = GlobalKey();

    final techService = MockNotaHistoricoTecnicoService(
      onCarregarUtil: (n) async => NotaHistoricoTecnicoResultado(
        notaReferencia: n,
        calculadoEm: DateTime.now(),
        itensEquipamento: [itemHist1],
        itensEstrutura: [itemHistPdf],
        todosItensDeduplicados: [itemHist1, itemHistPdf],
      ),
      onLazy: (item) async {
        if (item.notaSap.id == notaHistorica1.id) return itemHist1;
        if (item.notaSap.id == notaHistorica2.id) return itemHistPdf;
        return item;
      },
    );
    final visualService = MockNotaHistoricoVisualService(
      onBuscar: (_) async => histVisualResultado,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [TaskFlowThemeExtension.light()]),
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () {
                showModalBottomSheet(
                  context: ctx,
                  isScrollControlled: true,
                  builder: (sheetCtx) => RepaintBoundary(
                    key: key,
                    child: Container(
                      height: 700,
                      padding: const EdgeInsets.all(16),
                      child: SingleChildScrollView(
                        child: NotaWorkspaceHistoricoAnexosSection(
                          nota: notaAtual,
                          historicoTecnicoService: techService,
                          historicoVisualService: visualService,
                          analiseService: MockNotaSapAnaliseService(),
                        ),
                      ),
                    ),
                  ),
                );
              },
              child: const Text('Abrir Sheet'),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir Sheet'));
    await tester.pumpAndSettle();

    await capturePng(tester, key, '06_mobile_historico_aberto.png');
  });

  testWidgets('7. Captura Viewer Histórico de Imagem Read-Only', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final key = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [TaskFlowThemeExtension.light()]),
        home: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: NotaAnexoViewerDialog(
              anexos: [anexoHist1],
              indiceInicial: 0,
              service: MockNotaSapAnaliseService(),
              isHistoricoReadOnly: true,
              notaHistoricaNumero: '11524543',
              notaHistoricaData: '20/02/2026',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await capturePng(tester, key, '07_viewer_historico_imagem.png');
    expect(find.textContaining('MODO DE CONSULTA'), findsOneWidget);
  });

  testWidgets('8. Captura Viewer Histórico de PDF Read-Only', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final key = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [TaskFlowThemeExtension.light()]),
        home: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: NotaAnexoViewerDialog(
              anexos: [anexoHistPdf],
              indiceInicial: 0,
              service: MockNotaSapAnaliseService(),
              isHistoricoReadOnly: true,
              notaHistoricaNumero: '11474484',
              notaHistoricaData: '03/10/2025',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await capturePng(tester, key, '08_viewer_historico_pdf.png');
    expect(find.textContaining('MODO DE CONSULTA'), findsOneWidget);
  });
}
