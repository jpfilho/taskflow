import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task2026/config/supabase_config.dart';
import 'package:task2026/design_system/theme/taskflow_theme_extension.dart';
import 'package:task2026/models/backlog_macro_models.dart';
import 'package:task2026/models/nota_sap.dart';
import 'package:task2026/models/nota_sap_grupo.dart';
import 'package:task2026/services/nota_sap_backlog_service.dart';
import 'package:task2026/services/nota_sap_service.dart';
import 'package:task2026/widgets/planejamento_macro/planejamento_macro_view.dart';

// Mock do NotaSapBacklogService para testes de fluxo de navegação
class MockNotaSapBacklogService extends NotaSapBacklogService {
  BacklogMacroResult mockResult;
  int chamadasBuscar = 0;
  BacklogFiltro? ultimoFiltro;

  MockNotaSapBacklogService({
    required this.mockResult,
  });

  @override
  Future<BacklogMacroResult> buscarBacklogMacro({
    BacklogFiltro? filtro,
    bool forcarAtualizacao = false,
    DateTime? dataReferencia,
  }) async {
    chamadasBuscar++;
    ultimoFiltro = filtro;
    return mockResult;
  }

  @override
  Future<List<NotaSapGrupoPrevisaoHist>> buscarHistoricoGrupo(String grupoId) async {
    return [];
  }
}

// Mock do NotaSapService para resolver getNotaById
class MockNotaSapService extends NotaSapService {
  final Map<String, NotaSAP> notasMap;

  MockNotaSapService({required this.notasMap});

  @override
  Future<NotaSAP?> getNotaById(String id) async {
    return notasMap[id];
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    try {
      await SupabaseConfig.initialize();
    } catch (_) {}
  });

  Widget buildTestApp({
    required MockNotaSapBacklogService backlogService,
    required MockNotaSapService notaSapService,
  }) {
    return MaterialApp(
      theme: ThemeData.light().copyWith(
        extensions: [
          TaskFlowThemeExtension.light(),
        ],
      ),
      home: PlanejamentoMacroView(
        backlogService: backlogService,
        notaSapService: notaSapService,
      ),
    );
  }

  testWidgets('Navegação Planejamento Macro: abrir, selecionar mês, preservar filtro e refresh', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final notaA = const BacklogNotaItem(
      id: 'nota_a',
      nota: '11001',
      descricao: 'Troca de bucha DJ 1',
      estimativaHoras: 10.0,
      tasks: [], // Pendente
    );

    final notaB = const BacklogNotaItem(
      id: 'nota_b',
      nota: '11002',
      descricao: 'Reaperto geral DJ 1',
      estimativaHoras: 5.0,
      tasks: [BacklogTaskInfo(id: 't_b', status: 'PROG')], // Programada
    );

    final grupo1 = BacklogGrupoItem(
      id: 'g1',
      nome: 'Manutenção Preventiva DJ 1',
      motivo: 'Plano anual',
      mesProgramacaoPrevisto: 11,
      anoProgramacaoPrevisto: 2026,
      statusGrupo: 'ativo',
      notas: [notaA, notaB],
    );

    final mensalNov = BacklogMensalResumo(
      mes: 11,
      ano: 2026,
      grupos: [grupo1],
    );

    final mockResultInicial = BacklogMacroResult(
      global: const BacklogGlobalResumo(
        gruposAtivos: 1,
        gruposComPrevisao: 1,
        gruposSemPrevisao: 0,
        gruposUltrapassados: 0,
        notasEmGrupos: 2,
        notasProgramadas: 1,
        notasPendentes: 1,
        notasUnicas: 2,
        temAnomaliaIntegridade: false,
      ),
      meses: [mensalNov],
      semPrevisao: null,
      geradoEm: DateTime.now(),
      filtrosAplicados: const BacklogFiltro(),
      todosGrupos: [grupo1],
    );

    final backlogMock = MockNotaSapBacklogService(mockResult: mockResultInicial);
    final notaSapMock = MockNotaSapService(notasMap: {
      'nota_a': NotaSAP(
        id: 'nota_a',
        nota: '11001',
        descricao: 'Troca de bucha DJ 1',
        tipo: 'PM',
        statusUsuario: 'ABER',
        equipamento: 'DJ-01',
      ),
      'nota_b': NotaSAP(
        id: 'nota_b',
        nota: '11002',
        descricao: 'Reaperto geral DJ 1',
        tipo: 'PM',
        statusUsuario: 'ABER',
        equipamento: 'DJ-01',
      ),
    });

    // 1. Abrir Planejamento Macro
    await tester.pumpWidget(buildTestApp(
      backlogService: backlogMock,
      notaSapService: notaSapMock,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Planejamento Macro'), findsOneWidget);
    expect(find.text('Manutenção Preventiva DJ 1'), findsOneWidget);
    expect(backlogMock.chamadasBuscar, 1);

    // 2. Expandir grupo na visão consolidada para ver opções
    final grupoFinder = find.byKey(const Key('grupo_g1'));
    await tester.tap(grupoFinder);
    await tester.pumpAndSettle();

    expect(find.text('Programar Pendentes (1)'), findsOneWidget);
    expect(find.text('Ver Grupo'), findsOneWidget);

    // 3. Selecionar filtro de mês no carrossel de navegação (novo fluxo gerencial)
    final chipNov = find.text('Nov/26');
    expect(chipNov, findsOneWidget);
    await tester.tap(chipNov);
    await tester.pumpAndSettle();

    // Deve ter disparado nova busca com ano/mes do filtro
    expect(backlogMock.chamadasBuscar, 2);
    expect(backlogMock.ultimoFiltro?.mes, 11);
    expect(backlogMock.ultimoFiltro?.ano, 2026);

    // 4. Testar botão de atualização manual (Refresh)
    final refreshBtn = find.byTooltip('Atualizar dados (ignora cache)');
    expect(refreshBtn, findsOneWidget);
    await tester.tap(refreshBtn);
    await tester.pumpAndSettle();

    expect(backlogMock.chamadasBuscar, 3);

    // 5. Testar busca rápida por texto preservando filtros
    final buscaField = find.byType(TextField);
    expect(buscaField, findsOneWidget);
    await tester.enterText(buscaField, 'Preventiva');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(backlogMock.ultimoFiltro?.buscaTexto, 'Preventiva');
    expect(backlogMock.ultimoFiltro?.mes, 11); // Filtro de mês preservado!
  });
}
