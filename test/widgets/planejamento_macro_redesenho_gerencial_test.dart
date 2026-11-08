import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:task2026/design_system/theme/taskflow_theme_extension.dart';
import 'package:task2026/models/backlog_macro_models.dart';
import 'package:task2026/models/nota_sap.dart';
import 'package:task2026/models/nota_sap_grupo.dart';
import 'package:task2026/services/nota_sap_backlog_service.dart';
import 'package:task2026/services/nota_sap_service.dart';
import 'package:task2026/widgets/planejamento_macro/planejamento_macro_view.dart';

class MockNotaSapServiceRedesenho extends NotaSapService {
  final Map<String, NotaSAP> notasPorId;
  final Map<String, NotaSAP> notasPorNumero;
  bool buscouPorId = false;
  bool buscouPorNumero = false;

  MockNotaSapServiceRedesenho({
    this.notasPorId = const {},
    this.notasPorNumero = const {},
  });

  @override
  Future<NotaSAP?> getNotaById(String id) async {
    buscouPorId = true;
    return notasPorId[id];
  }

  @override
  Future<NotaSAP?> getNotaPorNumero(String numeroNota) async {
    buscouPorNumero = true;
    return notasPorNumero[numeroNota];
  }
}

class MockNotaSapBacklogServiceRedesenho extends NotaSapBacklogService {
  final BacklogMacroResult mockResult;
  MockNotaSapBacklogServiceRedesenho({required this.mockResult});

  @override
  Future<BacklogMacroResult> buscarBacklogMacro({
    BacklogFiltro? filtro,
    bool forcarAtualizacao = false,
    DateTime? dataReferencia,
  }) async {
    return mockResult;
  }

  @override
  Future<List<NotaSapGrupoPrevisaoHist>> buscarHistoricoGrupo(String grupoId) async {
    return const [];
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: 'http://212.85.0.249:8000',
        anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzY1ODE3OTgzLCJleHAiOjIwODExNzc5ODN9.YQByqDrpmw0en7VeEcjDfvvTx8Ind_q8gD6-bzEY4Yc',
      );
    } catch (_) {}
  });

  Widget createWidgetUnderTest(
    MockNotaSapBacklogServiceRedesenho service, {
    NotaSapService? notaSapService,
  }) {
    return MaterialApp(
      theme: ThemeData.light().copyWith(
        extensions: [
          TaskFlowThemeExtension.light(),
        ],
      ),
      home: PlanejamentoMacroView(
        backlogService: service,
        notaSapService: notaSapService,
      ),
    );
  }

  BacklogMacroResult criarCenarioNov26() {
    final t1 = BacklogTaskInfo(id: 't1', tarefa: 'Substituição 1', status: 'PROG', dataInicio: DateTime(2026, 11, 5));
    final t2 = BacklogTaskInfo(id: 't2', tarefa: 'Substituição 2', status: 'PROG', dataInicio: DateTime(2026, 11, 10));
    final t3 = BacklogTaskInfo(id: 't3', tarefa: 'Substituição 3', status: 'PROG', dataInicio: DateTime(2026, 11, 15));
    final t4 = BacklogTaskInfo(id: 't4', tarefa: 'Substituição 4', status: 'PROG', dataInicio: DateTime(2026, 11, 20));
    final t5 = BacklogTaskInfo(id: 't5', tarefa: 'Substituição 5', status: 'ANDA', dataInicio: DateTime(2026, 11, 25));

    // 6 demandas para Nov/2026: 5 programadas, 1 não programada, 2 com risco/vencidas, 6 sem estimativa
    final n1 = BacklogNotaItem(
      id: 'n1',
      nota: '11598101',
      descricao: 'Demand 1',
      statusSistema: 'MSPR',
      mesPrevisto: 11,
      anoPrevisto: 2026,
      dataFimDesejada: DateTime(2026, 1, 1), // Vencida
      tasks: [t1],
    );
    final n2 = BacklogNotaItem(
      id: 'n2',
      nota: '11598102',
      descricao: 'Demand 2',
      statusSistema: 'MSPR',
      mesPrevisto: 11,
      anoPrevisto: 2026,
      dataFimDesejada: DateTime(2026, 1, 1), // Vencida
      tasks: [t2],
    );
    final n3 = BacklogNotaItem(
      id: 'n3',
      nota: '11598103',
      descricao: 'Demand 3',
      statusSistema: 'MSPR',
      mesPrevisto: 11,
      anoPrevisto: 2026,
      tasks: [t3],
    );
    final n4 = BacklogNotaItem(
      id: 'n4',
      nota: '11598104',
      descricao: 'Demand 4',
      statusSistema: 'MSPR',
      mesPrevisto: 11,
      anoPrevisto: 2026,
      tasks: [t4],
    );
    final n5 = BacklogNotaItem(
      id: 'n5',
      nota: '11598105',
      descricao: 'Demand 5',
      statusSistema: 'MSPR',
      mesPrevisto: 11,
      anoPrevisto: 2026,
      tasks: [t5],
    );
    final n6 = const BacklogNotaItem(
      id: 'n6',
      nota: '11598106',
      descricao: 'Demand 6 - Nao Programada',
      statusSistema: 'MSPR',
      mesPrevisto: 11,
      anoPrevisto: 2026,
      tasks: [], // Não programada
    );

    final grupoNov = BacklogGrupoItem(
      id: 'g-nov',
      nome: 'Grupo Geral Nov/26',
      mesProgramacaoPrevisto: 11,
      anoProgramacaoPrevisto: 2026,
      statusGrupo: 'ativo',
      notas: [n1, n2, n3, n4, n5, n6],
    );

    // Demanda sem previsão (para testar a visão Sem Previsão)
    final tSemPrev = BacklogTaskInfo(id: 't-prog-sem-prev', tarefa: 'Manutenção Direta', status: 'PROG', dataInicio: DateTime(2026, 12, 1));
    final nSemPrevProg = BacklogNotaItem(
      id: 'n-sp-1',
      nota: '11599901',
      descricao: 'Nota com task mas sem previsao macro',
      statusSistema: 'MSPR',
      tasks: [tSemPrev], // Programada sem previsão macro
    );
    final nSemPrevSolta = const BacklogNotaItem(
      id: 'n-sp-2',
      nota: '11599902',
      descricao: 'Nota avulsa sem previsao e sem task',
      statusSistema: 'MSPR',
      tasks: [],
    );
    final grupoSemPrevisao = BacklogGrupoItem(
      id: 'avulsas_sp',
      nome: 'Notas Avulsas Sem Previsão',
      statusGrupo: 'ativo',
      notas: [nSemPrevProg, nSemPrevSolta],
    );

    return BacklogMacroResult(
      global: const BacklogGlobalResumo(
        gruposAtivos: 2,
        gruposComPrevisao: 1,
        gruposSemPrevisao: 1,
        gruposUltrapassados: 0,
        notasEmGrupos: 8,
        notasProgramadas: 6,
        notasPendentes: 2,
        notasUnicas: 8,
        temAnomaliaIntegridade: false,
      ),
      meses: [
        BacklogMensalResumo(
          mes: 11,
          ano: 2026,
          grupos: [grupoNov],
        ),
      ],
      semPrevisao: BacklogMensalResumo(
        mes: null,
        ano: null,
        grupos: [grupoSemPrevisao],
      ),
      geradoEm: DateTime.now(),
      filtrosAplicados: const BacklogFiltro(),
      todosGrupos: [grupoNov, grupoSemPrevisao],
    );
  }

  testWidgets('Cenário Nov/26: Ao selecionar o mês exibe Resumo Gerencial, Mensagem Automática e Indicadores de 1º Nível', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final mock = MockNotaSapBacklogServiceRedesenho(mockResult: criarCenarioNov26());
    await tester.pumpWidget(createWidgetUnderTest(mock));
    await tester.pumpAndSettle();

    // 1. Clicar na aba Nov/26 para entrar no contexto exclusivo do mês
    final tabNovFinder = find.text('Nov/26');
    expect(tabNovFinder, findsOneWidget);
    await tester.tap(tabNovFinder);
    await tester.pumpAndSettle();

    // 2. Validar Cabeçalho do Mês
    expect(find.text('NOVEMBRO DE 2026'), findsOneWidget);
    expect(find.text('Cobertura de Programação: 5 de 6'), findsOneWidget);

    // 3. Validar Indicadores de 1º Nível de Decisão (Regras 1, 3 e 7)
    expect(find.text('Demandas Previstas'), findsOneWidget);
    expect(find.text('Ainda Não Programadas'), findsOneWidget);
    expect(find.text('Vencidas / Em Risco'), findsOneWidget);
    expect(find.text('Sem Estimativa'), findsOneWidget);

    // 4. Validar Mensagem Gerencial Automática Determinística (Regra 4)
    expect(find.text('ATENÇÃO GERENCIAL'), findsOneWidget);
    expect(find.textContaining('5 das 6 demandas previstas para Novembro de 2026 já estão programadas.'), findsOneWidget);
    expect(find.textContaining('1 demanda ainda precisa ser programada.'), findsOneWidget);
    expect(find.textContaining('2 demandas apresentam risco de prazo ou atraso.'), findsOneWidget);

    // 5. Validar Barra de Subresumo de Ação (Regra 10)
    expect(find.text('Precisa de ação: 1'), findsOneWidget);
    expect(find.text('Em risco: 2'), findsOneWidget);

    // 6. Validar Seção de Demandas do Mês (Regra 9)
    expect(find.text('Demandas do Mês (6)'), findsOneWidget);
    expect(find.textContaining('11598101'), findsOneWidget);
    expect(find.textContaining('11598106'), findsOneWidget);

    // 7. Validar Bloco Recolhível de Capacidade (Regra 29)
    expect(find.text('Capacidade e Carga Operacional'), findsOneWidget);
  });

  testWidgets('Cenário Sem Previsão: Exibe visão dedicada sem blocos de meses e com distinção explícita de programação', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final mock = MockNotaSapBacklogServiceRedesenho(mockResult: criarCenarioNov26());
    await tester.pumpWidget(createWidgetUnderTest(mock));
    await tester.pumpAndSettle();

    // Clicar na aba "Sem previsão"
    final tabSemPrevisaoFinder = find.text('Sem previsão');
    expect(tabSemPrevisaoFinder, findsOneWidget);
    await tester.tap(tabSemPrevisaoFinder);
    await tester.pumpAndSettle();

    // 1. Validar Cabeçalho Explícito de Sem Previsão (Regra 19)
    expect(find.text('SEM PREVISÃO'), findsOneWidget);
    expect(find.text('Demandas que ainda não possuem horizonte gerencial de atendimento.'), findsOneWidget);

    // 2. Validar que NÃO renderiza blocos de meses (Regra 22)
    expect(find.text('NOVEMBRO DE 2026'), findsNothing);
    expect(find.text('Capacidade e Carga Operacional'), findsNothing);

    // 3. Validar KPIs Específicos de Sem Previsão (Regra 20)
    expect(find.text('Total Sem Previsão'), findsOneWidget);
    expect(find.text('Já Programadas'), findsOneWidget);
    expect(find.text('Sem Programação'), findsOneWidget);

    // 4. Validar Ação Principal em Destaque (Regra 24)
    expect(find.text('Definir Previsão em Lote'), findsOneWidget);

    // 5. Validar Distinção Explícita de Programação (Regra 23)
    expect(find.text('Programada sem previsão macro'), findsNWidgets(2));
    expect(find.text('Requer programação'), findsOneWidget);
  });

  testWidgets('Responsividade Mobile: Telas de 390px e 320px renderizam novo fluxo gerencial sem overflow', (tester) async {
    for (final largura in [390.0, 320.0]) {
      tester.view.physicalSize = Size(largura, 850);
      tester.view.devicePixelRatio = 1.0;

      final mock = MockNotaSapBacklogServiceRedesenho(mockResult: criarCenarioNov26());
      await tester.pumpWidget(createWidgetUnderTest(mock));
      await tester.pumpAndSettle();

      // Navega para Nov/26
      await tester.tap(find.text('Nov/26'));
      await tester.pumpAndSettle();

      // Valida ausência de exceção de overflow
      expect(tester.takeException(), isNull);
      expect(find.text('NOVEMBRO DE 2026'), findsOneWidget);
      expect(find.text('ATENÇÃO GERENCIAL'), findsOneWidget);
    }

    tester.view.resetPhysicalSize();
  });

  testWidgets('Interatividade dos Cards: Clicar nos cards filtra as notas (Programadas, Vencidas, Limpar filtro)', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;

    final mock = MockNotaSapBacklogServiceRedesenho(mockResult: criarCenarioNov26());
    await tester.pumpWidget(createWidgetUnderTest(mock));
    await tester.pumpAndSettle();

    // Navega para o mês de Novembro/2026
    await tester.tap(find.text('Nov/26'));
    await tester.pumpAndSettle();

    // Inicialmente exibe todas as 6 demandas
    expect(find.text('Demandas do Mês (6)'), findsOneWidget);
    expect(find.textContaining('11598101'), findsOneWidget);
    expect(find.textContaining('11598106'), findsOneWidget);

    // 1. Clicar no Card "Programadas"
    await tester.tap(find.text('Programadas'));
    await tester.pumpAndSettle();

    // Deve exibir banner de filtro ativo
    expect(find.textContaining('Filtro ativo: Programadas (5 de 6 demandas)'), findsOneWidget);
    // Demanda não programada (11598106) deve sumir da lista
    expect(find.textContaining('11598106'), findsNothing);
    // Demanda programada (11598101) permanece
    expect(find.textContaining('11598101'), findsOneWidget);

    // 2. Limpar o filtro clicando em "Limpar filtro"
    await tester.tap(find.text('Limpar filtro'));
    await tester.pumpAndSettle();

    // Volta a exibir as 6 demandas
    expect(find.text('Demandas do Mês (6)'), findsOneWidget);
    expect(find.textContaining('11598106'), findsOneWidget);

    // 3. Clicar no Card "Vencidas / Em Risco"
    await tester.tap(find.text('Vencidas / Em Risco'));
    await tester.pumpAndSettle();

    // Deve filtrar para as 2 demandas em risco (11598101 e 11598102)
    expect(find.textContaining('Filtro ativo: Vencidas / Em Risco (2 de 6 demandas)'), findsOneWidget);
    expect(find.textContaining('11598103'), findsNothing);
    expect(find.textContaining('11598101'), findsOneWidget);
    expect(find.textContaining('11598102'), findsOneWidget);

    // 4. Alternar clicando novamente no mesmo card para desativar o filtro
    await tester.tap(find.text('Vencidas / Em Risco'));
    await tester.pumpAndSettle();

    // Volta a exibir todas as 6 demandas
    expect(find.text('Demandas do Mês (6)'), findsOneWidget);
    expect(find.textContaining('11598103'), findsOneWidget);

    tester.view.resetPhysicalSize();
  });

  testWidgets('KPIs Globais da Visão Consolidada: Clicar filtra no Planejamento Macro e NÃO volta para a tabela', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;

    bool chamouDrillDown = false;
    final mock = MockNotaSapBacklogServiceRedesenho(mockResult: criarCenarioNov26());
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.light().copyWith(extensions: [TaskFlowThemeExtension.light()]),
      home: PlanejamentoMacroView(
        backlogService: mock,
        onDrillDown: (tipo, {valor}) {
          chamouDrillDown = true;
        },
      ),
    ));
    await tester.pumpAndSettle();

    // Na visão consolidada ("Todos"), exibe os KPIs globais (fallback de grupos no mock)
    expect(find.text('Grupos Ativos'), findsOneWidget);
    expect(find.text('Notas Pendentes'), findsOneWidget);
    expect(find.text('Sem Previsão'), findsOneWidget); // Card nos KPIs globais

    // Clicar no card "Notas Pendentes" nos KPIs globais
    await tester.tap(find.text('Notas Pendentes'));
    await tester.pumpAndSettle();

    // NÃO deve disparar onDrillDown para a tabela
    expect(chamouDrillDown, isFalse);

    // Permanece no Planejamento Macro com banner de filtro ativo
    expect(find.textContaining('Filtro ativo: Programadas (exibindo apenas demandas correspondentes)'), findsOneWidget);

    // Clicar no card "Sem Previsão" nos KPIs globais
    await tester.tap(find.text('Sem Previsão'));
    await tester.pumpAndSettle();

    // Deve navegar para a visão dedicada de Sem Previsão no próprio Planejamento Macro
    expect(chamouDrillDown, isFalse);
    expect(find.text('Demandas que ainda não possuem horizonte gerencial de atendimento.'), findsOneWidget);

    tester.view.resetPhysicalSize();
  });

  testWidgets('Exibição da Data do Prazo: Exibe Prazo limite, Previsão e Programação juntos', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;

    final mock = MockNotaSapBacklogServiceRedesenho(mockResult: criarCenarioNov26());
    await tester.pumpWidget(createWidgetUnderTest(mock));
    await tester.pumpAndSettle();

    // Selecionar o mês de Novembro/2026
    await tester.tap(find.text('Nov/26'));
    await tester.pumpAndSettle();

    // Deve exibir o label 'Prazo:' nas demandas
    expect(find.text('Prazo: '), findsWidgets);

    // Para demandas com prazo vencido (ex: 01/01/2026 no mock)
    expect(find.text('01/01/2026'), findsWidgets);
    expect(find.text('Vencido'), findsWidgets);

    // Linha de planejamento deve conter Previsão, Programação e Prazo
    expect(find.text('Prev. Nov/2026'), findsWidgets);
    expect(find.text('Prog. 05/11/2026'), findsOneWidget);

    tester.view.resetPhysicalSize();
  });

  testWidgets('Ação Abrir Nota: Busca nota de forma resiliente (ID e fallback por Número)', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;

    final mockNotaSap = NotaSAP(
      id: 'uuid-11598101',
      nota: '11598101',
      descricao: 'Demand 1',
    );
    final sapServiceMock = MockNotaSapServiceRedesenho(
      notasPorId: {'n1': mockNotaSap, 'uuid-11598101': mockNotaSap},
      notasPorNumero: {'11598101': mockNotaSap},
    );

    final mock = MockNotaSapBacklogServiceRedesenho(mockResult: criarCenarioNov26());
    await tester.pumpWidget(createWidgetUnderTest(mock, notaSapService: sapServiceMock));
    await tester.pumpAndSettle();

    // Selecionar o mês Nov/26
    await tester.tap(find.text('Nov/26'));
    await tester.pumpAndSettle();

    // Deve encontrar o botão 'Abrir Nota'
    final btnAbrirNota = find.text('Abrir Nota').first;
    expect(btnAbrirNota, findsOneWidget);

    await tester.tap(btnAbrirNota);
    await tester.pumpAndSettle();

    // Não deve exibir snackbar de erro 'não encontrada'
    expect(find.textContaining('não encontrada no momento'), findsNothing);
    // Deve ter chamado o serviço para buscar a nota
    expect(sapServiceMock.buscouPorId || sapServiceMock.buscouPorNumero, isTrue);

    tester.view.resetPhysicalSize();
  });
}
