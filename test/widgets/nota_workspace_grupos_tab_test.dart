import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/models/nota_sap.dart';
import 'package:task2026/models/nota_sap_grupo.dart';
import 'package:task2026/models/nota_sap_similaridade.dart';
import 'package:task2026/services/nota_sap_grupo_service.dart';
import 'package:task2026/services/nota_sap_service.dart';
import 'package:task2026/widgets/nota_workspace/nota_workspace_grupos_tab.dart';
import 'package:task2026/widgets/nota_workspace/nota_similaridade_panel.dart';

class MockNotaSAPService extends NotaSAPService {
  List<NotaSAP> notasMock = [];
  MockNotaSAPService([this.notasMock = const []]);

  @override
  Future<List<NotaSAP>> getAllNotas({
    String? filtroTipoNota,
    List<String>? filtroLocais,
    List<String>? filtroSalas,
    List<String>? filtroTipos,
    List<String>? filtroNotas,
    List<String>? filtroPrioridades,
    List<String>? filtroStatusUsuario,
    List<String>? filtroResponsaveis,
    List<String>? filtroGPMs,
    int? limit,
    int? offset,
  }) async {
    return notasMock;
  }
}

/// Mock do serviço de grupos de Notas SAP para validação rigorosa dos 13 cenários de UI.
class MockNotaSapGrupoService extends NotaSapGrupoService {
  NotaSapGrupo? grupoAtivoMock;
  List<NotaSapGrupoItem> itensMock = [];
  List<NotaSapGrupoPrevisaoHist> historicoMock = [];
  bool lancarErro = false;

  bool metodoAdicionarChamado = false;
  bool metodoRemoverChamado = false;
  bool metodoAlterarPrevisaoChamado = false;

  MockNotaSapGrupoService({
    this.grupoAtivoMock,
    List<NotaSapGrupoItem>? itens,
    List<NotaSapGrupoPrevisaoHist>? historico,
    this.lancarErro = false,
  }) {
    if (itens != null) itensMock = itens;
    if (historico != null) historicoMock = historico;
  }

  @override
  Future<NotaSapGrupo?> buscarGrupoAtivoDaNota(String notaSapId) async {
    if (lancarErro) throw Exception('Falha simulada de conexão');
    return grupoAtivoMock;
  }

  @override
  Future<List<NotaSapGrupoItem>> buscarNotasDoGrupo(String grupoId) async {
    if (lancarErro) throw Exception('Falha simulada de conexão');
    return itensMock;
  }

  @override
  Future<List<NotaSapGrupoPrevisaoHist>> buscarHistoricoPrevisao(String grupoId) async {
    return historicoMock;
  }

  @override
  Future<NotaSapGrupoItem> adicionarNotaAoGrupo({
    required String grupoId,
    required String notaSapId,
    String? motivoVinculo,
    String? usuarioId,
    String? usuarioNome,
  }) async {
    metodoAdicionarChamado = true;
    final novoItem = NotaSapGrupoItem(
      id: 'novo-item-1',
      grupoId: grupoId,
      notaSapId: notaSapId,
      motivoVinculo: motivoVinculo,
    );
    itensMock.add(novoItem);
    return novoItem;
  }

  @override
  Future<void> removerNotaDoGrupo({
    required String grupoId,
    required String notaSapId,
  }) async {
    metodoRemoverChamado = true;
    itensMock.removeWhere((i) => i.notaSapId == notaSapId);
  }

  @override
  Future<NotaSapGrupo> alterarPrevisao({
    required String grupoId,
    int? mes,
    int? ano,
    String? motivo,
    String? usuarioId,
    String? usuarioNome,
  }) async {
    metodoAlterarPrevisaoChamado = true;
    grupoAtivoMock = grupoAtivoMock?.copyWith(
      mesProgramacaoPrevisto: mes,
      anoProgramacaoPrevisto: ano,
      motivoPrevisao: motivo,
      clearPrevisao: mes == null,
    );
    return grupoAtivoMock!;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final notaPrincipal = NotaSAP(
    id: 'nota-uuid-1',
    nota: '11599101',
    descricao: 'Baixa pressão de SF6 no disjuntor',
    equipamento: 'DISJ-138-01',
    localInstalacao: 'SE-PIRAPORA-138KV',
    centroTrabalhoResponsavel: 'MEC-SUB',
    statusSistema: 'ABERTA',
  );

  Widget criarApp(Widget child) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(body: child),
    );
  }

  group('Seção 31: Testes de Widgets da Aba de Grupos & Previsão', () {
    void setupDesktopViewport(WidgetTester tester) {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }
    // -------------------------------------------------------------------------
    // Teste 1: Nota sem grupo
    // -------------------------------------------------------------------------
    testWidgets('1. Nota sem grupo: Exibe estado vazio convidando a criar ou vincular', (tester) async {
      setupDesktopViewport(tester);
      final mockService = MockNotaSapGrupoService(grupoAtivoMock: null);

      await tester.pumpWidget(criarApp(
        NotaWorkspaceGruposTab(nota: notaPrincipal, service: mockService),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Nota Sem Vínculo de Programação Conjunta'), findsOneWidget);
      expect(find.text('Criar Novo Grupo'), findsOneWidget);
      expect(find.text('Vincular a Grupo Existente'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Teste 2: Nota com grupo
    // -------------------------------------------------------------------------
    testWidgets('2. Nota com grupo: Exibe cabeçalho com nome e motivo do grupo', (tester) async {
      setupDesktopViewport(tester);
      final grupo = NotaSapGrupo(
        id: 'grp-1',
        nome: 'Intervenção Vão 12T2',
        motivo: 'Desligamento programado conjunto no setor 138kV',
        mesProgramacaoPrevisto: 11,
        anoProgramacaoPrevisto: 2026,
        statusGrupo: StatusGrupo.ativo,
      );

      final mockService = MockNotaSapGrupoService(
        grupoAtivoMock: grupo,
        itens: [
          NotaSapGrupoItem(
            id: 'item-1',
            grupoId: 'grp-1',
            notaSapId: notaPrincipal.id,
            nota: notaPrincipal,
          ),
        ],
      );

      await tester.pumpWidget(criarApp(
        NotaWorkspaceGruposTab(nota: notaPrincipal, service: mockService),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('INTERVENÇÃO VÃO 12T2'), findsOneWidget);
      expect(find.text('Desligamento programado conjunto no setor 138kV'), findsOneWidget);
      expect(find.text('Ativo'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Teste 3: Grupo sem previsão
    // -------------------------------------------------------------------------
    testWidgets('3. Grupo sem previsão: Exibe indicador de não definida', (tester) async {
      setupDesktopViewport(tester);
      final grupoSemPrev = NotaSapGrupo(
        id: 'grp-sem-prev',
        nome: 'Grupo Sem Previsão',
        mesProgramacaoPrevisto: null,
        anoProgramacaoPrevisto: null,
      );

      final mockService = MockNotaSapGrupoService(
        grupoAtivoMock: grupoSemPrev,
        itens: [
          NotaSapGrupoItem(
            id: 'item-1',
            grupoId: 'grp-sem-prev',
            notaSapId: notaPrincipal.id,
            nota: notaPrincipal,
          ),
        ],
      );

      await tester.pumpWidget(criarApp(
        NotaWorkspaceGruposTab(nota: notaPrincipal, service: mockService),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('NÃO DEFINIDA'), findsWidgets);
      expect(find.text('Definir Previsão'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Teste 4: Grupo com previsão
    // -------------------------------------------------------------------------
    testWidgets('4. Grupo com previsão: Exibe mês/ano formatado por extenso', (tester) async {
      setupDesktopViewport(tester);
      final grupoComPrev = NotaSapGrupo(
        id: 'grp-com-prev',
        nome: 'Grupo Com Previsão',
        mesProgramacaoPrevisto: 11,
        anoProgramacaoPrevisto: 2026,
        motivoPrevisao: 'Alinhado com a equipe de linhas',
      );

      final mockService = MockNotaSapGrupoService(
        grupoAtivoMock: grupoComPrev,
        itens: [
          NotaSapGrupoItem(
            id: 'item-1',
            grupoId: 'grp-com-prev',
            notaSapId: notaPrincipal.id,
            nota: notaPrincipal,
          ),
        ],
      );

      await tester.pumpWidget(criarApp(
        NotaWorkspaceGruposTab(nota: notaPrincipal, service: mockService),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('NOVEMBRO/2026'), findsWidgets);
      expect(find.text('Motivo: Alinhado com a equipe de linhas'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Teste 5: Previsão ultrapassada
    // -------------------------------------------------------------------------
    testWidgets('5. Previsão ultrapassada: Exibe alerta informativo quando mês já passou', (tester) async {
      setupDesktopViewport(tester);
      final grupoAtrasado = NotaSapGrupo(
        id: 'grp-atrasado',
        nome: 'Grupo Atrasado',
        mesProgramacaoPrevisto: 1, // Janeiro do ano passado
        anoProgramacaoPrevisto: 2020,
      );

      final mockService = MockNotaSapGrupoService(
        grupoAtivoMock: grupoAtrasado,
        itens: [
          NotaSapGrupoItem(
            id: 'item-1',
            grupoId: 'grp-atrasado',
            notaSapId: notaPrincipal.id,
            nota: notaPrincipal,
          ),
        ],
      );

      await tester.pumpWidget(criarApp(
        NotaWorkspaceGruposTab(nota: notaPrincipal, service: mockService),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Previsão ultrapassada'), findsOneWidget);
      expect(find.text('Mês previsto já decorrido sem programação completa'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Teste 6: Múltiplas Notas vinculadas
    // -------------------------------------------------------------------------
    testWidgets('6. Múltiplas Notas: Renderiza cards individuais para cada nota do grupo', (tester) async {
      setupDesktopViewport(tester);
      final nota2 = NotaSAP(id: 'nota-2', nota: '11599102', descricao: 'Vazamento TC');
      final nota3 = NotaSAP(id: 'nota-3', nota: '11599103', descricao: 'Ajuste de relé');

      final grupo = NotaSapGrupo(
        id: 'grp-multi',
        nome: 'Revisão Geral do Vão',
      );

      final mockService = MockNotaSapGrupoService(
        grupoAtivoMock: grupo,
        itens: [
          NotaSapGrupoItem(id: 'item-1', grupoId: 'grp-multi', notaSapId: notaPrincipal.id, nota: notaPrincipal),
          NotaSapGrupoItem(id: 'item-2', grupoId: 'grp-multi', notaSapId: nota2.id, nota: nota2),
          NotaSapGrupoItem(id: 'item-3', grupoId: 'grp-multi', notaSapId: nota3.id, nota: nota3),
        ],
      );

      await tester.pumpWidget(criarApp(
        NotaWorkspaceGruposTab(nota: notaPrincipal, service: mockService),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Nota 11599101'), findsOneWidget);
      expect(find.text('Nota 11599102'), findsOneWidget);
      expect(find.text('Nota 11599103'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Teste 7: Nota já programada
    // -------------------------------------------------------------------------
    testWidgets('7. Nota já programada: Exibe badge de programada com ID da tarefa', (tester) async {
      setupDesktopViewport(tester);
      final grupo = NotaSapGrupo(id: 'grp-prog', nome: 'Grupo Programado');

      final mockService = MockNotaSapGrupoService(
        grupoAtivoMock: grupo,
        itens: [
          NotaSapGrupoItem(
            id: 'item-1',
            grupoId: 'grp-prog',
            notaSapId: notaPrincipal.id,
            nota: notaPrincipal,
            tarefasVinculadas: [
              const TarefaHistoricaResumo(
                id: '842',
                tarefaNome: 'Manutenção Preventiva Vão 12T2',
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(criarApp(
        NotaWorkspaceGruposTab(nota: notaPrincipal, service: mockService),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Programada'), findsOneWidget);
      expect(find.text('Tarefa #842'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Teste 8: Programação parcial (Seção 18)
    // -------------------------------------------------------------------------
    testWidgets('8. Programação parcial: Exibe 1 de 2 notas programadas', (tester) async {
      setupDesktopViewport(tester);
      final nota2 = NotaSAP(id: 'nota-2', nota: '11599102', descricao: 'Vazamento TC');

      final grupo = NotaSapGrupo(id: 'grp-parcial', nome: 'Grupo Parcial');

      final mockService = MockNotaSapGrupoService(
        grupoAtivoMock: grupo,
        itens: [
          NotaSapGrupoItem(
            id: 'item-1',
            grupoId: 'grp-parcial',
            notaSapId: notaPrincipal.id,
            nota: notaPrincipal,
            tarefasVinculadas: [
              const TarefaHistoricaResumo(id: '100', tarefaNome: 'Tarefa 100'),
            ],
          ),
          NotaSapGrupoItem(
            id: 'item-2',
            grupoId: 'grp-parcial',
            notaSapId: nota2.id,
            nota: nota2,
            tarefasVinculadas: const [],
          ),
        ],
      );

      await tester.pumpWidget(criarApp(
        NotaWorkspaceGruposTab(nota: notaPrincipal, service: mockService),
      ));
      await tester.pumpAndSettle();

      expect(find.text('1 de 2 notas programadas (Parcial)'), findsOneWidget);
      expect(find.text('Programada'), findsOneWidget);
      expect(find.text('Ainda não programada'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Teste 9: Diálogo de adicionar Nota
    // -------------------------------------------------------------------------
    testWidgets('9. Adicionar Nota: Abre diálogo de busca e inclusão', (tester) async {
      setupDesktopViewport(tester);
      final grupo = NotaSapGrupo(id: 'grp-1', nome: 'Grupo de Teste');
      final mockService = MockNotaSapGrupoService(
        grupoAtivoMock: grupo,
        itens: [
          NotaSapGrupoItem(id: 'item-1', grupoId: 'grp-1', notaSapId: notaPrincipal.id, nota: notaPrincipal),
        ],
      );
      final nota2 = NotaSAP(
        id: 'nota-uuid-2',
        nota: '11599102',
        descricao: 'Vazamento secundário',
        localInstalacao: 'SE-PIRAPORA-138KV',
        statusSistema: 'ABERTA',
      );
      final mockNotaSapService = MockNotaSAPService([nota2]);

      await tester.pumpWidget(criarApp(
        NotaWorkspaceGruposTab(
          nota: notaPrincipal,
          service: mockService,
          notaSapService: mockNotaSapService,
        ),
      ));
      await tester.pumpAndSettle();

      final btnAdicionar = find.text('Adicionar Nota');
      expect(btnAdicionar, findsOneWidget);

      await tester.tap(btnAdicionar);
      await tester.pumpAndSettle();

      expect(find.text('Adicionar Nota ao Grupo'), findsOneWidget);
      expect(find.byType(TextField), findsWidgets);
    });

    // -------------------------------------------------------------------------
    // Teste 10: Remover Nota do grupo
    // -------------------------------------------------------------------------
    testWidgets('10. Remover Nota: Exibe confirmação antes de desvincular', (tester) async {
      setupDesktopViewport(tester);
      final nota2 = NotaSAP(id: 'nota-2', nota: '11599102', descricao: 'Vazamento secundário');
      final grupo = NotaSapGrupo(id: 'grp-1', nome: 'Grupo de Teste');
      final mockService = MockNotaSapGrupoService(
        grupoAtivoMock: grupo,
        itens: [
          NotaSapGrupoItem(id: 'item-1', grupoId: 'grp-1', notaSapId: notaPrincipal.id, nota: notaPrincipal),
          NotaSapGrupoItem(id: 'item-2', grupoId: 'grp-1', notaSapId: nota2.id, nota: nota2),
        ],
      );

      await tester.pumpWidget(criarApp(
        NotaWorkspaceGruposTab(nota: notaPrincipal, service: mockService),
      ));
      await tester.pumpAndSettle();

      final btnRemover = find.byTooltip('Remover esta Nota do grupo');
      expect(btnRemover, findsWidgets);

      await tester.tap(btnRemover.first);
      await tester.pumpAndSettle();

      expect(find.text('Remover Nota do Grupo'), findsOneWidget);
      expect(find.text('Remover'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Teste 11: Alterar previsão e Histórico
    // -------------------------------------------------------------------------
    testWidgets('11. Alterar previsão: Abre diálogo de edição de mês/ano', (tester) async {
      setupDesktopViewport(tester);
      final grupo = NotaSapGrupo(
        id: 'grp-1',
        nome: 'Grupo Com Previsão',
        mesProgramacaoPrevisto: 11,
        anoProgramacaoPrevisto: 2026,
      );

      final mockService = MockNotaSapGrupoService(
        grupoAtivoMock: grupo,
        itens: [
          NotaSapGrupoItem(id: 'item-1', grupoId: 'grp-1', notaSapId: notaPrincipal.id, nota: notaPrincipal),
        ],
        historico: [
          const NotaSapGrupoPrevisaoHist(
            id: 'h-1',
            grupoId: 'grp-1',
            mesAnterior: 10,
            anoAnterior: 2026,
            mesNovo: 11,
            anoNovo: 2026,
            motivo: 'Ajuste de parada',
          ),
        ],
      );

      await tester.pumpWidget(criarApp(
        NotaWorkspaceGruposTab(nota: notaPrincipal, service: mockService),
      ));
      await tester.pumpAndSettle();

      final btnAlterar = find.text('Alterar Previsão');
      expect(btnAlterar, findsOneWidget);

      await tester.tap(btnAlterar);
      await tester.pumpAndSettle();

      expect(find.text('Alterar Previsão de Programação'), findsOneWidget);
      expect(find.text('Salvar Previsão'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Teste 12: Ação no card da Nota vinculada
    // -------------------------------------------------------------------------
    testWidgets('12. Abrir Nota vinculada: Card possui botão para ver detalhes da nota', (tester) async {
      setupDesktopViewport(tester);
      final nota2 = NotaSAP(id: 'nota-2', nota: '11599102', descricao: 'Vazamento secundário');
      final grupo = NotaSapGrupo(id: 'grp-1', nome: 'Grupo de Teste');
      final mockService = MockNotaSapGrupoService(
        grupoAtivoMock: grupo,
        itens: [
          NotaSapGrupoItem(id: 'item-1', grupoId: 'grp-1', notaSapId: notaPrincipal.id, nota: notaPrincipal),
          NotaSapGrupoItem(id: 'item-2', grupoId: 'grp-1', notaSapId: nota2.id, nota: nota2),
        ],
      );

      await tester.pumpWidget(criarApp(
        NotaWorkspaceGruposTab(nota: notaPrincipal, service: mockService),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Abrir Nota'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Teste 13: Vínculo vindo da Similaridade (Seção 24 e 25)
    // -------------------------------------------------------------------------
    testWidgets('13. Vínculo vindo da Similaridade: Exibe botão "Vincular ao grupo"', (tester) async {
      setupDesktopViewport(tester);
      final mockGrupoService = MockNotaSapGrupoService(grupoAtivoMock: null);
      final notaCandidata = NotaSAP(
        id: 'candidata-1',
        nota: '11599200',
        descricao: 'Falha análoga no mesmo vão',
        equipamento: 'DISJ-138-01',
      );

      final itemSimilar = NotaSapSimilar(
        nota: notaCandidata,
        scoreTotal: 85.0,
        faixa: FaixaSimilaridade.alta,
        classificacao: TipoClassificacaoSimilaridade.ocorrenciaSemelhante,
        evidencias: const EvidenciaScore(
          pontosEquipamento: 40,
          pontosLocalInstalacao: 20,
          explicacoes: ['+40 Mesmo equipamento'],
        ),
      );

      final resultadoSim = ResultadoSimilaridadeNotaSap(
        notaReferencia: notaPrincipal,
        calculadoEm: DateTime(2026, 10, 15),
        ocorrenciasSemelhantes: [itemSimilar],
        todasOcorrencias: [itemSimilar],
      );

      await tester.pumpWidget(criarApp(
        NotaSapSimilaridadePanel(
          nota: notaPrincipal,
          dadosIniciais: resultadoSim,
          grupoService: mockGrupoService,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Vincular ao grupo'), findsWidgets);
    });
  });
}
