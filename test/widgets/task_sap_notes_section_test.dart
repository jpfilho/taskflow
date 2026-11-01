import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/models/nota_sap.dart';
import 'package:task2026/models/nota_sap_analise.dart';
import 'package:task2026/models/task.dart';
import 'package:task2026/services/nota_sap_analise_service.dart';
import 'package:task2026/widgets/nota_workspace/nota_analise_badge.dart';
import 'package:task2026/widgets/task/task_sap_notes_section.dart';

class MockNotaSapAnaliseServiceForTaskSection extends Fake
    implements NotaSapAnaliseService {
  final Map<String, NotaSapAnalise?> analisesMock = {};
  final Map<String, NotaSapResumoAnalise> resumosMock = {};
  final Map<String, List<NotaSapMaterial>> materiaisMock = {};
  final Map<String, List<NotaSapAnexo>> anexosMock = {};
  final Map<String, List<NotaSapComentario>> comentariosMock = {};

  bool failResumos = false;
  bool failDetalhes = false;
  int forceRefreshCount = 0;

  @override
  Future<Map<String, NotaSapResumoAnalise>> buscarResumoAnalises(
    List<String> notaSapIds, {
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) forceRefreshCount++;
    if (failResumos) {
      throw Exception('Simulação de falha de rede no Supabase');
    }
    final res = <String, NotaSapResumoAnalise>{};
    for (final id in notaSapIds) {
      if (resumosMock.containsKey(id)) {
        res[id] = resumosMock[id]!;
      } else {
        res[id] = NotaSapResumoAnalise(
          notaSapId: id,
          status: NotaAnaliseStatus.naoIniciada,
        );
      }
    }
    return res;
  }

  @override
  Future<NotaSapAnalise?> buscarAnalise(String notaSapId) async {
    if (failDetalhes) {
      throw Exception('Erro ao buscar análise da nota $notaSapId');
    }
    return analisesMock[notaSapId];
  }

  @override
  Future<List<NotaSapMaterial>> listarMateriais(String notaSapId) async {
    return materiaisMock[notaSapId] ?? [];
  }

  @override
  Future<List<NotaSapAnexo>> listarAnexos(String notaSapId) async {
    return anexosMock[notaSapId] ?? [];
  }

  @override
  Future<List<NotaSapComentario>> listarComentarios(String notaSapId) async {
    return comentariosMock[notaSapId] ?? [];
  }

  @override
  String obterUrlAnexo(NotaSapAnexo anexo) {
    return 'https://supabase.local/storage/v1/object/public/anexos/${anexo.caminhoArquivo}';
  }

  @override
  Future<String> obterUrlAssinada(
    NotaSapAnexo anexo, {
    Duration expires = const Duration(days: 7),
  }) async {
    return 'https://supabase.local/signed/${anexo.caminhoArquivo}';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockTask = Task(
    id: 'task-100',
    tarefa: 'Manutenção Preventiva de Alimentador',
    status: 'Criada',
    regional: 'Metropolitana',
    divisao: 'Distribuição',
    tipo: 'Preventiva',
    coordenador: 'Coordenador Silva',
    dataInicio: DateTime.now(),
    dataFim: DateTime.now().add(const Duration(hours: 8)),
    observacoes: 'Atenção aos cruzamentos com linha de trem',
    horasPrevistas: 8.0,
  );

  final nota1 = NotaSAP(
    id: 'nota-1',
    nota: '10001111',
    descricao: 'Poste quebrado no vão 12',
    localInstalacao: 'SUB-CENTRO-01',
    equipamento: 'TRAFO-02',
  );

  final nota2 = NotaSAP(
    id: 'nota-2',
    nota: '20002222',
    descricao: 'Cabo rompido fase B',
    localInstalacao: 'SUB-NORTE-02',
  );

  Widget createWidget({
    List<NotaSAP> notas = const [],
    Task? task,
    NotaSapAnaliseService? service,
    bool readOnly = true,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: TaskSapNotesSection(
            notasSAP: notas,
            task: task ?? mockTask,
            analiseService: service,
            readOnly: readOnly,
          ),
        ),
      ),
    );
  }

  group('Fase 6: TaskSapNotesSection (19 Testes Obrigatórios)', () {
    testWidgets('1. Não renderiza nada quando notasSAP é vazia', (tester) async {
      await tester.pumpWidget(createWidget(notas: []));
      await tester.pump();

      expect(find.byType(TaskSapNotesSection), findsOneWidget);
      expect(find.text('NOTAS SAP VINCULADAS'), findsNothing);
    });

    testWidgets('2. Renderiza card para 1 nota SAP vinculada com número e origem', (tester) async {
      final mockService = MockNotaSapAnaliseServiceForTaskSection();

      await tester.pumpWidget(createWidget(
        notas: [nota1],
        service: mockService,
      ));
      await tester.pumpAndSettle();

      expect(find.text('NOTAS SAP VINCULADAS'), findsOneWidget);
      expect(find.text('Nota SAP 10001111'), findsOneWidget);
      expect(find.text('Origem: Nota SAP 10001111'), findsOneWidget);
      expect(find.text('Poste quebrado no vão 12'), findsOneWidget);
    });

    testWidgets('3. Renderiza múltiplos cards quando há N notas SAP vinculadas', (tester) async {
      final mockService = MockNotaSapAnaliseServiceForTaskSection();

      await tester.pumpWidget(createWidget(
        notas: [nota1, nota2],
        service: mockService,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Nota SAP 10001111'), findsOneWidget);
      expect(find.text('Nota SAP 20002222'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // Contador de notas
    });

    testWidgets('4. Identifica origem de cada nota com rótulo "Origem: Nota SAP XXXXXXXX"', (tester) async {
      final mockService = MockNotaSapAnaliseServiceForTaskSection();

      await tester.pumpWidget(createWidget(
        notas: [nota1, nota2],
        service: mockService,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Origem: Nota SAP 10001111'), findsOneWidget);
      expect(find.text('Origem: Nota SAP 20002222'), findsOneWidget);
    });

    testWidgets('5. Exibe "Análise técnica: Não iniciada" para nota sem análise', (tester) async {
      final mockService = MockNotaSapAnaliseServiceForTaskSection();

      await tester.pumpWidget(createWidget(
        notas: [nota1],
        service: mockService,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Não iniciada'), findsWidgets);
    });

    testWidgets('6. Exibe status e contadores via NotaAnaliseBadge quando possui análise', (tester) async {
      final mockService = MockNotaSapAnaliseServiceForTaskSection();
      mockService.resumosMock['nota-1'] = const NotaSapResumoAnalise(
        notaSapId: 'nota-1',
        status: NotaAnaliseStatus.concluida,
        quantidadeMateriais: 4,
        quantidadeAnexos: 3,
        quantidadeComentarios: 2,
      );

      await tester.pumpWidget(createWidget(
        notas: [nota1],
        service: mockService,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(NotaAnaliseBadge), findsOneWidget);
      expect(find.text('Concluída'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('7. Botão [Ver Nota e Análise] exibe rótulo correto conforme status', (tester) async {
      final mockService = MockNotaSapAnaliseServiceForTaskSection();
      mockService.resumosMock['nota-1'] = const NotaSapResumoAnalise(
        notaSapId: 'nota-1',
        status: NotaAnaliseStatus.concluida,
      );

      await tester.pumpWidget(createWidget(
        notas: [nota1],
        service: mockService,
      ));
      await tester.pumpAndSettle();

      // Clica para expandir o tile da nota
      await tester.tap(find.text('Nota SAP 10001111'));
      await tester.pumpAndSettle();

      expect(find.text('Ver Nota e Análise'), findsOneWidget);
    });

    testWidgets('8. Ao expandir nota: exibe bloco "ESCOPO SUGERIDO NA ANÁLISE DA NOTA"', (tester) async {
      final mockService = MockNotaSapAnaliseServiceForTaskSection();
      mockService.resumosMock['nota-1'] = const NotaSapResumoAnalise(
        notaSapId: 'nota-1',
        status: NotaAnaliseStatus.emAnalise,
      );
      mockService.analisesMock['nota-1'] = const NotaSapAnalise(
        id: 'an-1',
        notaSapId: 'nota-1',
        statusAnalise: NotaAnaliseStatus.emAnalise,
        escopoDetalhado: 'Instalar isoladores poliméricos tipo pilar',
        diagnosticoPrevio: 'Isolador quebrado com fuga de corrente',
      );

      await tester.pumpWidget(createWidget(
        notas: [nota1],
        service: mockService,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nota SAP 10001111'));
      await tester.pumpAndSettle();

      expect(find.text('ESCOPO SUGERIDO NA ANÁLISE DA NOTA'), findsOneWidget);
      expect(find.text('Instalar isoladores poliméricos tipo pilar'), findsOneWidget);
    });

    testWidgets('9. Bloco de escopo possui tag diferenciando do escopo oficial da tarefa', (tester) async {
      final mockService = MockNotaSapAnaliseServiceForTaskSection();
      mockService.resumosMock['nota-1'] = const NotaSapResumoAnalise(
        notaSapId: 'nota-1',
        status: NotaAnaliseStatus.emAnalise,
      );
      mockService.analisesMock['nota-1'] = const NotaSapAnalise(
        id: 'an-1',
        notaSapId: 'nota-1',
        escopoDetalhado: 'Escopo sugerido para troca',
      );

      await tester.pumpWidget(createWidget(
        notas: [nota1],
        service: mockService,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nota SAP 10001111'));
      await tester.pumpAndSettle();

      expect(find.text('Sugestão técnica'), findsOneWidget);
    });

    testWidgets('10. Ao expandir nota: exibe bloco "DIAGNÓSTICO PRÉVIO DA NOTA"', (tester) async {
      final mockService = MockNotaSapAnaliseServiceForTaskSection();
      mockService.resumosMock['nota-1'] = const NotaSapResumoAnalise(
        notaSapId: 'nota-1',
        status: NotaAnaliseStatus.concluida,
      );
      mockService.analisesMock['nota-1'] = const NotaSapAnalise(
        id: 'an-1',
        notaSapId: 'nota-1',
        diagnosticoPrevio: 'Abalroamento com quebra de cruzeta',
      );

      await tester.pumpWidget(createWidget(
        notas: [nota1],
        service: mockService,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nota SAP 10001111'));
      await tester.pumpAndSettle();

      expect(find.text('DIAGNÓSTICO PRÉVIO DA NOTA'), findsOneWidget);
      expect(find.text('Abalroamento com quebra de cruzeta'), findsOneWidget);
    });

    testWidgets('11. Exibe chips de equipe/técnicos, estimativa, desligamento e Parcela Variável (PV)', (tester) async {
      final mockService = MockNotaSapAnaliseServiceForTaskSection();
      mockService.resumosMock['nota-1'] = const NotaSapResumoAnalise(
        notaSapId: 'nota-1',
        status: NotaAnaliseStatus.concluida,
      );
      mockService.analisesMock['nota-1'] = const NotaSapAnalise(
        id: 'an-1',
        notaSapId: 'nota-1',
        analistaNome: 'Carlos Analista',
        quantidadeTecnicos: 3,
        estimativaHoras: 5.5,
        necessitaDesligamento: true,
        valorPv: 2500.0,
      );

      await tester.pumpWidget(createWidget(
        notas: [nota1],
        service: mockService,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nota SAP 10001111'));
      await tester.pumpAndSettle();

      expect(find.text('Carlos Analista'), findsOneWidget);
      expect(find.text('3'), findsWidgets);
      expect(find.text('5.5h'), findsOneWidget);
      expect(find.text('Desligamento: '), findsOneWidget);
      expect(find.text('Parcela Variável (PV): '), findsOneWidget);
      expect(find.text('R\$ 2500.00'), findsOneWidget);
    });

    testWidgets('12. Ao expandir seção de Materiais: carrega lista de materiais levantados', (tester) async {
      final mockService = MockNotaSapAnaliseServiceForTaskSection();
      mockService.resumosMock['nota-1'] = const NotaSapResumoAnalise(
        notaSapId: 'nota-1',
        status: NotaAnaliseStatus.concluida,
        quantidadeMateriais: 1,
      );
      mockService.analisesMock['nota-1'] = const NotaSapAnalise(
        id: 'an-1',
        notaSapId: 'nota-1',
      );
      mockService.materiaisMock['nota-1'] = const [
        NotaSapMaterial(
          id: 'mat-1',
          notaSapId: 'nota-1',
          codigoSap: 'MAT-7890',
          descricao: 'Isolador Polimérico 15kV',
          quantidade: 3,
          unidade: 'UN',
        ),
      ];

      await tester.pumpWidget(createWidget(
        notas: [nota1],
        service: mockService,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nota SAP 10001111'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Materiais Levantados'));
      await tester.pumpAndSettle();

      expect(find.text('MAT-7890'), findsOneWidget);
      expect(find.text('Isolador Polimérico 15kV'), findsOneWidget);
      expect(find.text('3.0 UN'), findsOneWidget);
    });

    testWidgets('13. Subseção de Materiais exibe aviso explícito de planejamento técnico', (tester) async {
      final mockService = MockNotaSapAnaliseServiceForTaskSection();
      mockService.resumosMock['nota-1'] = const NotaSapResumoAnalise(
        notaSapId: 'nota-1',
        status: NotaAnaliseStatus.concluida,
        quantidadeMateriais: 1,
      );
      mockService.analisesMock['nota-1'] = const NotaSapAnalise(
        id: 'an-1',
        notaSapId: 'nota-1',
      );
      mockService.materiaisMock['nota-1'] = const [
        NotaSapMaterial(
          id: 'mat-1',
          notaSapId: 'nota-1',
          codigoSap: 'MAT-123',
          descricao: 'Poste de Fibra',
          quantidade: 1,
          unidade: 'UN',
        ),
      ];

      await tester.pumpWidget(createWidget(
        notas: [nota1],
        service: mockService,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nota SAP 10001111'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Materiais Levantados'));
      await tester.pumpAndSettle();

      expect(
        find.text('Materiais levantados no planejamento técnico (não implica reserva física).'),
        findsOneWidget,
      );
    });

    testWidgets('14. Ao expandir seção de Anexos: carrega e lista anexos vinculados', (tester) async {
      final mockService = MockNotaSapAnaliseServiceForTaskSection();
      mockService.resumosMock['nota-1'] = const NotaSapResumoAnalise(
        notaSapId: 'nota-1',
        status: NotaAnaliseStatus.concluida,
        quantidadeAnexos: 1,
      );
      mockService.analisesMock['nota-1'] = const NotaSapAnalise(
        id: 'an-1',
        notaSapId: 'nota-1',
      );
      mockService.anexosMock['nota-1'] = [
        NotaSapAnexo(
          id: 'anexo-1',
          notaSapId: 'nota-1',
          nomeArquivo: 'foto_poste_quebrado.jpg',
          tipoArquivo: NotaAnexoTipo.imagem,
          tamanhoBytes: 1024,
          caminhoArquivo: 'nota_1/foto_poste_quebrado.jpg',
          createdAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(createWidget(
        notas: [nota1],
        service: mockService,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nota SAP 10001111'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Anexos da Nota SAP'));
      await tester.pumpAndSettle();

      expect(find.text('foto_poste_quebrado.jpg'), findsOneWidget);
    });

    testWidgets('15. Ao expandir Discussão: carrega comentários técnicos com aviso de independência', (tester) async {
      final mockService = MockNotaSapAnaliseServiceForTaskSection();
      mockService.resumosMock['nota-1'] = const NotaSapResumoAnalise(
        notaSapId: 'nota-1',
        status: NotaAnaliseStatus.concluida,
        quantidadeComentarios: 1,
      );
      mockService.analisesMock['nota-1'] = const NotaSapAnalise(
        id: 'an-1',
        notaSapId: 'nota-1',
      );
      mockService.comentariosMock['nota-1'] = [
        NotaSapComentario(
          id: 'c-1',
          notaSapId: 'nota-1',
          usuarioId: 'u-1',
          usuarioNome: 'Eng. Carlos',
          mensagem: 'Acesso difícil pelo terreno vizinho',
          createdAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(createWidget(
        notas: [nota1],
        service: mockService,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nota SAP 10001111'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Discussão Técnica da Nota SAP'));
      await tester.pumpAndSettle();

      expect(find.text('Eng. Carlos'), findsOneWidget);
      expect(find.text('Acesso difícil pelo terreno vizinho'), findsOneWidget);
      expect(
        find.text('Histórico técnico da Nota SAP (independente do chat da tarefa).'),
        findsOneWidget,
      );
    });

    testWidgets('16. Erro no carregamento de detalhes da nota exibe mensagem amigável', (tester) async {
      final mockService = MockNotaSapAnaliseServiceForTaskSection();
      mockService.failDetalhes = true;

      await tester.pumpWidget(createWidget(
        notas: [nota1],
        service: mockService,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nota SAP 10001111'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Erro ao carregar detalhes técnicos da nota'), findsOneWidget);
    });

    testWidgets('17. Erro no carregamento dos resumos exibe alerta e mantém notas visíveis', (tester) async {
      final mockService = MockNotaSapAnaliseServiceForTaskSection();
      mockService.failResumos = true;

      await tester.pumpWidget(createWidget(
        notas: [nota1],
        service: mockService,
      ));
      await tester.pumpAndSettle();

      expect(find.text('NOTAS SAP VINCULADAS'), findsOneWidget);
      expect(find.text('Nota SAP 10001111'), findsOneWidget);
      expect(find.text('Não foi possível carregar os indicadores técnicos.'), findsOneWidget);
    });

    testWidgets('18. Botão de atualizar dados recarrega resumos com forceRefresh: true', (tester) async {
      final mockService = MockNotaSapAnaliseServiceForTaskSection();

      await tester.pumpWidget(createWidget(
        notas: [nota1],
        service: mockService,
      ));
      await tester.pumpAndSettle();

      expect(mockService.forceRefreshCount, equals(0));

      await tester.tap(find.byTooltip('Atualizar análise técnica'));
      await tester.pumpAndSettle();

      expect(mockService.forceRefreshCount, equals(1));
    });

    testWidgets('19. Dados da tarefa Task permanecem intactos sem alteração automática', (tester) async {
      final mockService = MockNotaSapAnaliseServiceForTaskSection();
      mockService.resumosMock['nota-1'] = const NotaSapResumoAnalise(
        notaSapId: 'nota-1',
        status: NotaAnaliseStatus.concluida,
      );
      mockService.analisesMock['nota-1'] = const NotaSapAnalise(
        id: 'an-1',
        notaSapId: 'nota-1',
        escopoDetalhado: 'Novo escopo da análise que não deve sobrescrever a tarefa',
        estimativaHoras: 15.0,
      );

      final taskOriginal = Task(
        id: 'task-orig',
        tarefa: 'Tarefa Original Intacta',
        status: 'Criada',
        regional: 'Metropolitana',
        divisao: 'Distribuição',
        tipo: 'Preventiva',
        coordenador: 'Coordenador Silva',
        dataInicio: DateTime.now(),
        dataFim: DateTime.now().add(const Duration(hours: 4)),
        observacoes: 'Observações Originais',
        horasPrevistas: 4.0,
      );

      await tester.pumpWidget(createWidget(
        notas: [nota1],
        task: taskOriginal,
        service: mockService,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nota SAP 10001111'));
      await tester.pumpAndSettle();

      // Confirma que a Task não sofreu mutações nem efeitos colaterais
      expect(taskOriginal.tarefa, equals('Tarefa Original Intacta'));
      expect(taskOriginal.observacoes, equals('Observações Originais'));
      expect(taskOriginal.horasPrevistas, equals(4.0));
    });
  });
}
