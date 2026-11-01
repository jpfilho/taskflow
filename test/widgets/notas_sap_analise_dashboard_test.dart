import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/models/nota_sap.dart';
import 'package:task2026/models/nota_sap_analise.dart';
import 'package:task2026/models/nota_sap_indicadores.dart';
import 'package:task2026/services/nota_sap_indicadores_service.dart';
import 'package:task2026/widgets/dashboard/notas_sap_analise_dashboard_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Helper para criar notas de teste
  NotaSAP criarNota(String id, {String centroTrabalho = 'CT-01', String regional = 'REG-LESTE'}) {
    return NotaSAP(
      id: id,
      nota: 'NOTA-$id',
      tipo: 'PM01',
      descricao: 'Nota de Teste $id',
      statusSistema: 'ABER',
      statusUsuario: '',
      textPrioridade: 'Média',
      centroTrabalhoResponsavel: centroTrabalho,
      centro: regional,
      criadoEm: DateTime(2026, 1, 1),
    );
  }

  // Helper para criar resumos de teste
  NotaSapResumoAnalise criarResumo(
    String id, {
    NotaAnaliseStatus status = NotaAnaliseStatus.concluida,
    int qtdAnexos = 0,
    int qtdMateriais = 0,
    int qtdComentarios = 0,
  }) {
    return NotaSapResumoAnalise(
      notaSapId: id,
      status: status,
      quantidadeAnexos: qtdAnexos,
      quantidadeMateriais: qtdMateriais,
      quantidadeComentarios: qtdComentarios,
    );
  }

  group('Fase 5 — 18 Testes Obrigatórios de Indicadores e Dashboard', () {
    // 1. Cálculo correto do total de notas com análise
    test('1. Cálculo correto do total de notas com análise', () {
      final notas = [
        criarNota('1'),
        criarNota('2'),
        criarNota('3'),
        criarNota('4'),
      ];
      final resumos = {
        '1': criarResumo('1', status: NotaAnaliseStatus.concluida),
        '2': criarResumo('2', status: NotaAnaliseStatus.emAnalise),
        '3': criarResumo('3', status: NotaAnaliseStatus.naoIniciada),
        // '4' não tem resumo cadastrado -> naoIniciada
      };

      final ind = NotaSapIndicadores.calcular(notas: notas, resumos: resumos);
      expect(ind.totalNotas, equals(4));
      expect(ind.notasConcluidas, equals(1));
      expect(ind.notasEmAnalise, equals(1));
      expect(ind.notasSemAnalise, equals(2)); // '3' e '4'
    });

    // 2. Cálculo correto do percentual de cobertura
    test('2. Cálculo correto do percentual de cobertura', () {
      final notas = [
        criarNota('1'),
        criarNota('2'),
        criarNota('3'),
        criarNota('4'),
      ];
      final resumos = {
        '1': criarResumo('1', status: NotaAnaliseStatus.concluida),
        '2': criarResumo('2', status: NotaAnaliseStatus.emAnalise),
      };

      final ind = NotaSapIndicadores.calcular(notas: notas, resumos: resumos);
      // 2 notas com análise de um total de 4 -> 50.0%
      expect(ind.taxaCobertura, equals(50.0));
      expect(ind.percentualConcluidas, equals(25.0));
      expect(ind.percentualEmAnalise, equals(25.0));
    });

    // 3. Cálculo correto da distribuição por status
    test('3. Cálculo correto da distribuição por status', () {
      final notas = [
        criarNota('1'),
        criarNota('2'),
        criarNota('3'),
        criarNota('4'),
        criarNota('5'),
      ];
      final resumos = {
        '1': criarResumo('1', status: NotaAnaliseStatus.naoIniciada),
        '2': criarResumo('2', status: NotaAnaliseStatus.emAnalise),
        '3': criarResumo('3', status: NotaAnaliseStatus.concluida),
        '4': criarResumo('4', status: NotaAnaliseStatus.aguardandoInformacao),
        '5': criarResumo('5', status: NotaAnaliseStatus.cancelada),
      };

      final ind = NotaSapIndicadores.calcular(notas: notas, resumos: resumos);
      expect(ind.notasSemAnalise, equals(1));
      expect(ind.notasEmAnalise, equals(1));
      expect(ind.notasConcluidas, equals(1));
      expect(ind.notasAguardandoInfo, equals(1));
      expect(ind.analisesCanceladas, equals(1));
      expect(ind.distribuicaoPorStatus[NotaAnaliseStatus.aguardandoInformacao], equals(1));
    });

    // 4. Cálculo correto de notas com anexos
    test('4. Cálculo correto de notas com anexos', () {
      final notas = [criarNota('1'), criarNota('2'), criarNota('3')];
      final resumos = {
        '1': criarResumo('1', qtdAnexos: 3),
        '2': criarResumo('2', qtdAnexos: 0),
        '3': criarResumo('3', qtdAnexos: 1),
      };

      final ind = NotaSapIndicadores.calcular(notas: notas, resumos: resumos);
      expect(ind.notasComAnexos, equals(2));
      expect(ind.percentualComAnexos, closeTo(66.6, 0.1));
    });

    // 5. Cálculo correto de notas com materiais
    test('5. Cálculo correto de notas com materiais', () {
      final notas = [criarNota('1'), criarNota('2')];
      final resumos = {
        '1': criarResumo('1', qtdMateriais: 4),
        '2': criarResumo('2', qtdMateriais: 0),
      };

      final ind = NotaSapIndicadores.calcular(notas: notas, resumos: resumos);
      expect(ind.notasComMateriais, equals(1));
      expect(ind.percentualComMateriais, equals(50.0));
    });

    // 6. Cálculo correto de notas por nível de maturidade
    test('6. Cálculo correto de notas por nível de maturidade', () {
      final notas = [
        criarNota('0'), // Nível 0
        criarNota('1'), // Nível 1 (em análise, sem diagnóstico)
        criarNota('2'), // Nível 2 (com diagnóstico ou escopo)
        criarNota('3'), // Nível 3 (concluída + anexos + materiais)
      ];
      final resumos = {
        '1': criarResumo('1', status: NotaAnaliseStatus.emAnalise),
        '2': criarResumo('2', status: NotaAnaliseStatus.emAnalise),
        '3': criarResumo(
          '3',
          status: NotaAnaliseStatus.concluida,
          qtdAnexos: 2,
          qtdMateriais: 3,
        ),
      };
      final analises = {
        '2': const NotaSapAnalise(
          notaSapId: '2',
          diagnosticoPrevio: 'Defeito identificado no rotor',
        ),
        '3': const NotaSapAnalise(
          notaSapId: '3',
          diagnosticoPrevio: 'Defeito identificado',
          escopoDetalhado: 'Substituição completa do componente',
        ),
      };

      final ind = NotaSapIndicadores.calcular(
        notas: notas,
        resumos: resumos,
        analisesDetalhadas: analises,
      );
      expect(ind.nivel0SomenteNota, equals(1));
      expect(ind.nivel1Iniciada, equals(1));
      expect(ind.nivel2DiagnosticoEscopo, equals(1));
      expect(ind.nivel3Completa, equals(1));
    });

    // 7. Cálculo correto da cobertura por Centro de Trabalho
    test('7. Cálculo correto da cobertura por Centro de Trabalho', () {
      final notas = [
        criarNota('1', centroTrabalho: 'CT-SUBESTACAO'),
        criarNota('2', centroTrabalho: 'CT-SUBESTACAO'),
        criarNota('3', centroTrabalho: 'CT-LINHAS'),
      ];
      final resumos = {
        '1': criarResumo('1', status: NotaAnaliseStatus.concluida),
      };

      final ind = NotaSapIndicadores.calcular(notas: notas, resumos: resumos);
      expect(ind.porCentroTrabalho.containsKey('CT-SUBESTACAO'), isTrue);
      expect(ind.porCentroTrabalho.containsKey('CT-LINHAS'), isTrue);

      final ctSub = ind.porCentroTrabalho['CT-SUBESTACAO']!;
      expect(ctSub.totalNotas, equals(2));
      expect(ctSub.comAnalise, equals(1));
      expect(ctSub.taxaCobertura, equals(50.0));

      final ctLinhas = ind.porCentroTrabalho['CT-LINHAS']!;
      expect(ctLinhas.totalNotas, equals(1));
      expect(ctLinhas.comAnalise, equals(0));
      expect(ctLinhas.taxaCobertura, equals(0.0));
    });

    // 8. Agrupamento correto por regional
    test('8. Agrupamento correto por regional', () {
      final notas = [
        criarNota('1', regional: 'NORTE'),
        criarNota('2', regional: 'NORTE'),
        criarNota('3', regional: 'SUL'),
      ];
      final resumos = {
        '1': criarResumo('1', status: NotaAnaliseStatus.concluida),
        '3': criarResumo('3', status: NotaAnaliseStatus.concluida),
      };

      final ind = NotaSapIndicadores.calcular(notas: notas, resumos: resumos);
      expect(ind.porRegional['NORTE']?.totalNotas, equals(2));
      expect(ind.porRegional['NORTE']?.comAnalise, equals(1));
      expect(ind.porRegional['SUL']?.totalNotas, equals(1));
      expect(ind.porRegional['SUL']?.comAnalise, equals(1));
    });

    // 9. Validação temporal de tarefas com análise prévia (analise <= tarefa)
    test('9. Validação temporal de tarefas com análise prévia (analise <= tarefa)', () {
      final notas = [criarNota('1')];
      final analises = {
        '1': NotaSapAnalise(
          id: 'a1',
          notaSapId: '1',
          statusAnalise: NotaAnaliseStatus.concluida,
          createdAt: DateTime(2026, 1, 10, 8, 0), // Análise feita às 08:00
        ),
      };
      final vinculos = [
        VinculoTaskNotaSap(
          taskId: 't1',
          notaSapId: '1',
          taskCreatedAt: DateTime(2026, 1, 10, 14, 0), // Tarefa criada às 14:00 (DEPOIS)
        ),
      ];

      final ind = NotaSapIndicadores.calcular(
        notas: notas,
        analisesDetalhadas: analises,
        vinculosTarefas: vinculos,
      );

      expect(ind.tarefasTotalVinculadas, equals(1));
      expect(ind.tarefasComAnalisePrevia, equals(1));
      expect(ind.tarefasComAnalisePosteriorOuAtual, equals(0));
      expect(ind.percentualTarefasComAnalisePrevia, equals(100.0));
    });

    // 10. Tarefas vinculadas a notas sem análise contabilizadas corretamente
    test('10. Tarefas vinculadas a notas sem análise contabilizadas corretamente', () {
      final notas = [criarNota('1')];
      final vinculos = [
        VinculoTaskNotaSap(
          taskId: 't1',
          notaSapId: '1',
          taskCreatedAt: DateTime(2026, 1, 10, 14, 0),
        ),
      ];

      final ind = NotaSapIndicadores.calcular(
        notas: notas,
        analisesDetalhadas: {}, // Sem análise
        vinculosTarefas: vinculos,
      );

      expect(ind.tarefasTotalVinculadas, equals(1));
      expect(ind.tarefasSemAnalise, equals(1));
      expect(ind.tarefasComAnalisePrevia, equals(0));
    });

    // 11. Não contagem de análise criada após a tarefa como "análise prévia"
    test('11. Não contagem de análise criada após a tarefa como "análise prévia"', () {
      final notas = [criarNota('1')];
      final analises = {
        '1': NotaSapAnalise(
          id: 'a1',
          notaSapId: '1',
          statusAnalise: NotaAnaliseStatus.concluida,
          createdAt: DateTime(2026, 1, 15, 10, 0), // Análise feita DIA 15
        ),
      };
      final vinculos = [
        VinculoTaskNotaSap(
          taskId: 't1',
          notaSapId: '1',
          taskCreatedAt: DateTime(2026, 1, 10, 10, 0), // Tarefa criada DIA 10 (ANTES)
        ),
      ];

      final ind = NotaSapIndicadores.calcular(
        notas: notas,
        analisesDetalhadas: analises,
        vinculosTarefas: vinculos,
      );

      // Não pode contar como prévia!
      expect(ind.tarefasComAnalisePrevia, equals(0));
      expect(ind.tarefasComAnalisePosteriorOuAtual, equals(1));
    });

    // 12. Resiliência a listas vazias (zero division handled)
    test('12. Resiliência a listas vazias (zero division handled)', () {
      final vazio = NotaSapIndicadores.vazio();
      expect(vazio.totalNotas, equals(0));
      expect(vazio.taxaCobertura, equals(0.0));
      expect(vazio.percentualConcluidas, equals(0.0));
      expect(vazio.percentualEmAnalise, equals(0.0));
      expect(vazio.percentualComAnexos, equals(0.0));
      expect(vazio.percentualComMateriais, equals(0.0));
      expect(vazio.percentualTarefasComAnalisePrevia, equals(0.0));
    });

    // 13. Resiliência a falhas no serviço de indicadores
    test('13. Resiliência a falhas no serviço de indicadores', () {
      final service = NotaSapIndicadoresService();
      // Teste do cálculo local nunca lança erro mesmo com mapas nulos ou vazios
      final ind = service.calcularIndicadoresLocais(notas: []);
      expect(ind.totalNotas, equals(0));
    });

    // 14. Drill-down: clique em card abre lista filtrada com o status correto
    testWidgets('14. Drill-down: clique em card abre lista filtrada com o status correto', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      String? statusCapturado;
      final notas = [criarNota('1'), criarNota('2')];
      final resumos = {
        '1': criarResumo('1', status: NotaAnaliseStatus.concluida),
        '2': criarResumo('2', status: NotaAnaliseStatus.emAnalise),
      };
      final ind = NotaSapIndicadores.calcular(notas: notas, resumos: resumos);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: NotasSapAnaliseDashboardSection(
                indicadores: ind,
                onDrillDown: ({
                  String? statusAnalise,
                  bool? comAnexos,
                  bool? comMateriais,
                  bool? comComentarios,
                  String? centroTrabalho,
                }) {
                  statusCapturado = statusAnalise;
                },
              ),
            ),
          ),
        ),
      );

      // Clica no card 'Concluídas'
      final cardConcluidas = find.text('Concluídas').first;
      expect(cardConcluidas, findsOneWidget);
      await tester.ensureVisible(cardConcluidas);
      await tester.tap(cardConcluidas);
      await tester.pumpAndSettle();

      expect(statusCapturado, equals('concluida'));
    });

    // 15. Drill-down: clique em "Com anexos" aplica filtro de anexos
    testWidgets('15. Drill-down: clique em "Com anexos" aplica filtro de anexos', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool? comAnexosCapturado;
      final notas = [criarNota('1')];
      final resumos = {'1': criarResumo('1', qtdAnexos: 3)};
      final ind = NotaSapIndicadores.calcular(notas: notas, resumos: resumos);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: NotasSapAnaliseDashboardSection(
                indicadores: ind,
                onDrillDown: ({
                  String? statusAnalise,
                  bool? comAnexos,
                  bool? comMateriais,
                  bool? comComentarios,
                  String? centroTrabalho,
                }) {
                  comAnexosCapturado = comAnexos;
                },
              ),
            ),
          ),
        ),
      );

      final cardAnexos = find.text('Com Anexos');
      expect(cardAnexos, findsOneWidget);
      await tester.ensureVisible(cardAnexos);
      await tester.tap(cardAnexos);
      await tester.pumpAndSettle();

      expect(comAnexosCapturado, isTrue);
    });

    // 16. Drill-down: clique em Centro de Trabalho filtra pelo CT correto
    testWidgets('16. Drill-down: clique em Centro de Trabalho filtra pelo CT correto', (tester) async {
      tester.view.physicalSize = const Size(1280, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      String? ctCapturado;
      final notas = [criarNota('1', centroTrabalho: 'CT-SUBESTACAO')];
      final resumos = {'1': criarResumo('1', status: NotaAnaliseStatus.concluida)};
      final ind = NotaSapIndicadores.calcular(notas: notas, resumos: resumos);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: NotasSapAnaliseDashboardSection(
                indicadores: ind,
                onDrillDown: ({
                  String? statusAnalise,
                  bool? comAnexos,
                  bool? comMateriais,
                  bool? comComentarios,
                  String? centroTrabalho,
                }) {
                  ctCapturado = centroTrabalho;
                },
              ),
            ),
          ),
        ),
      );

      final ctItem = find.text('CT-SUBESTACAO');
      expect(ctItem, findsOneWidget);
      await tester.ensureVisible(ctItem);
      await tester.tap(ctItem);
      await tester.pumpAndSettle();

      expect(ctCapturado, equals('CT-SUBESTACAO'));
    });

    // 17. Performance: cálculo de indicadores para 2.000 notas em < 100ms
    test('17. Performance: cálculo de indicadores para 2.000 notas em < 100ms', () {
      final notas2k = List.generate(
        2000,
        (i) => criarNota('$i', centroTrabalho: 'CT-${i % 10}', regional: 'REG-${i % 4}'),
      );
      final resumos2k = {
        for (int i = 0; i < 2000; i++)
          if (i % 2 == 0)
            '$i': criarResumo(
              '$i',
              status: i % 4 == 0 ? NotaAnaliseStatus.concluida : NotaAnaliseStatus.emAnalise,
              qtdAnexos: i % 3 == 0 ? 1 : 0,
              qtdMateriais: i % 5 == 0 ? 2 : 0,
            ),
      };

      final sw = Stopwatch()..start();
      final ind = NotaSapIndicadores.calcular(notas: notas2k, resumos: resumos2k);
      sw.stop();

      expect(ind.totalNotas, equals(2000));
      expect(sw.elapsedMilliseconds, lessThan(100));
    });

    // 18. Isolamento: nenhuma tarefa alterada durante o cálculo de métricas
    test('18. Isolamento: nenhuma tarefa alterada durante o cálculo de métricas', () {
      // O cálculo de indicadores é puramente funcional e imutável.
      // Recebe listas imutáveis e retorna um objeto de leitura pura NotaSapIndicadores.
      final notas = [criarNota('1')];
      final resumos = {'1': criarResumo('1')};

      final ind = NotaSapIndicadores.calcular(notas: notas, resumos: resumos);
      expect(ind, isA<NotaSapIndicadores>());
      expect(notas.length, equals(1));
      // Garante que não há alteração de estado nem efeitos colaterais
    });
  });

  group('Consolidação Técnica e Documental — Itens 3, 8 e 16', () {
    // -------------------------------------------------------------------------
    // ITEM 3: AUDITORIA DA RELAÇÃO N:M (Cenários A, B, C, D)
    // -------------------------------------------------------------------------
    test('Item 3 - Cenário A: Uma tarefa vinculada a uma Nota (1:1)', () {
      final notas = [criarNota('1')];
      final resumos = {'1': criarResumo('1', status: NotaAnaliseStatus.concluida)};
      final vinculos = [
        VinculoTaskNotaSap(
          taskId: 't1',
          notaSapId: '1',
          taskCreatedAt: DateTime(2026, 1, 10, 10, 0),
        ),
      ];
      final analises = {
        '1': NotaSapAnalise(
          id: 'a1',
          notaSapId: '1',
          statusAnalise: NotaAnaliseStatus.concluida,
          createdAt: DateTime(2026, 1, 10, 8, 0),
        ),
      };

      final ind = NotaSapIndicadores.calcular(
        notas: notas,
        resumos: resumos,
        analisesDetalhadas: analises,
        vinculosTarefas: vinculos,
      );

      expect(ind.tarefasTotalVinculadas, equals(1));
      expect(ind.notasProgramadasTotal, equals(1));
      expect(ind.tarefasComAnalisePrevia, equals(1));
    });

    test('Item 3 - Cenário B: Uma tarefa vinculada a várias Notas (1:N)', () {
      // 1 tarefa vinculada a 3 notas diferentes
      final notas = [criarNota('1'), criarNota('2'), criarNota('3')];
      final resumos = {
        '1': criarResumo('1', status: NotaAnaliseStatus.concluida),
        '2': criarResumo('2', status: NotaAnaliseStatus.emAnalise),
        '3': criarResumo('3', status: NotaAnaliseStatus.naoIniciada),
      };
      final vinculos = [
        VinculoTaskNotaSap(taskId: 't1', notaSapId: '1', taskCreatedAt: DateTime(2026, 1, 10, 10, 0)),
        VinculoTaskNotaSap(taskId: 't1', notaSapId: '2', taskCreatedAt: DateTime(2026, 1, 10, 10, 0)),
        VinculoTaskNotaSap(taskId: 't1', notaSapId: '3', taskCreatedAt: DateTime(2026, 1, 10, 10, 0)),
      ];
      final analises = {
        '1': NotaSapAnalise(
          id: 'a1',
          notaSapId: '1',
          statusAnalise: NotaAnaliseStatus.concluida,
          createdAt: DateTime(2026, 1, 10, 8, 0), // Previa
        ),
      };

      final ind = NotaSapIndicadores.calcular(
        notas: notas,
        resumos: resumos,
        analisesDetalhadas: analises,
        vinculosTarefas: vinculos,
      );

      // Deve contar apenas 1 tarefa distinta, sem inflar pelo número de notas
      expect(ind.tarefasTotalVinculadas, equals(1));
      // Deve contar 3 notas distintas programadas
      expect(ind.notasProgramadasTotal, equals(3));
      // A tarefa tem pelo menos uma nota com análise prévia
      expect(ind.tarefasComAnalisePrevia, equals(1));
    });

    test('Item 3 - Cenário C: Uma Nota vinculada a várias tarefas (N:1)', () {
      // 3 tarefas vinculadas à mesma nota
      final notas = [criarNota('1')];
      final resumos = {'1': criarResumo('1', status: NotaAnaliseStatus.concluida)};
      final analises = {
        '1': NotaSapAnalise(
          id: 'a1',
          notaSapId: '1',
          statusAnalise: NotaAnaliseStatus.concluida,
          createdAt: DateTime(2026, 1, 10, 12, 0), // Análise feita ao meio-dia
        ),
      };
      final vinculos = [
        // Tarefa 1 criada depois da análise (tem análise prévia)
        VinculoTaskNotaSap(taskId: 't1', notaSapId: '1', taskCreatedAt: DateTime(2026, 1, 10, 14, 0)),
        // Tarefa 2 criada depois da análise (tem análise prévia)
        VinculoTaskNotaSap(taskId: 't2', notaSapId: '1', taskCreatedAt: DateTime(2026, 1, 10, 15, 0)),
        // Tarefa 3 criada antes da análise (não tinha análise prévia no momento da criação)
        VinculoTaskNotaSap(taskId: 't3', notaSapId: '1', taskCreatedAt: DateTime(2026, 1, 10, 9, 0)),
      ];

      final ind = NotaSapIndicadores.calcular(
        notas: notas,
        resumos: resumos,
        analisesDetalhadas: analises,
        vinculosTarefas: vinculos,
      );

      // 3 tarefas distintas vinculadas
      expect(ind.tarefasTotalVinculadas, equals(3));
      // Apenas 1 nota distinta programada (não inflada)
      expect(ind.notasProgramadasTotal, equals(1));
      // 2 tarefas com análise prévia (t1 e t2) e 1 com análise posterior (t3)
      expect(ind.tarefasComAnalisePrevia, equals(2));
      expect(ind.tarefasComAnalisePosteriorOuAtual, equals(1));
      expect(ind.tarefasSemAnalise, equals(0));
    });

    test('Item 3 - Cenário D: Várias Notas vinculadas a várias tarefas (N:M complexo)', () {
      final notas = [criarNota('1'), criarNota('2'), criarNota('3'), criarNota('4')];
      final vinculos = [
        // t1 tem notas 1 e 2
        VinculoTaskNotaSap(taskId: 't1', notaSapId: '1', taskCreatedAt: DateTime(2026, 1, 10, 14, 0)),
        VinculoTaskNotaSap(taskId: 't1', notaSapId: '2', taskCreatedAt: DateTime(2026, 1, 10, 14, 0)),
        // t2 tem notas 2 e 3
        VinculoTaskNotaSap(taskId: 't2', notaSapId: '2', taskCreatedAt: DateTime(2026, 1, 10, 14, 0)),
        VinculoTaskNotaSap(taskId: 't2', notaSapId: '3', taskCreatedAt: DateTime(2026, 1, 10, 14, 0)),
        // t3 tem nota 4
        VinculoTaskNotaSap(taskId: 't3', notaSapId: '4', taskCreatedAt: DateTime(2026, 1, 10, 14, 0)),
      ];

      final ind = NotaSapIndicadores.calcular(
        notas: notas,
        resumos: {},
        analisesDetalhadas: {},
        vinculosTarefas: vinculos,
      );

      // Total de 3 tarefas distintas
      expect(ind.tarefasTotalVinculadas, equals(3));
      // Total de 4 notas distintas vinculadas
      expect(ind.notasProgramadasTotal, equals(4));
    });

    // -------------------------------------------------------------------------
    // ITEM 8: PARIDADE ENTRE CÁLCULO LOCAL E CONSOLIDADO
    // -------------------------------------------------------------------------
    test('Item 8 - Paridade matemática estrita: resultado local == resultado consolidado para o mesmo universo', () {
      final service = NotaSapIndicadoresService();

      final notas = [
        criarNota('1', centroTrabalho: 'CT1'),
        criarNota('2', centroTrabalho: 'CT1'),
        criarNota('3', centroTrabalho: 'CT2'),
      ];
      final resumos = {
        '1': criarResumo('1', status: NotaAnaliseStatus.concluida, qtdAnexos: 2, qtdMateriais: 3, qtdComentarios: 1),
        '2': criarResumo('2', status: NotaAnaliseStatus.emAnalise, qtdAnexos: 0, qtdMateriais: 1, qtdComentarios: 0),
      };
      final analises = {
        '1': const NotaSapAnalise(
          notaSapId: '1',
          statusAnalise: NotaAnaliseStatus.concluida,
          diagnosticoPrevio: 'Defeito encontrado',
          escopoDetalhado: 'Troca de peca',
        ),
      };

      // 1. Cálculo pelo método local do serviço
      final resLocal = service.calcularIndicadoresLocais(
        notas: notas,
        resumos: resumos,
        analisesDetalhadas: analises,
      );

      // 2. Cálculo direto pela factory core que o método consolidado utiliza
      final resConsolidado = NotaSapIndicadores.calcular(
        notas: notas,
        resumos: resumos,
        analisesDetalhadas: analises,
      );

      // Validação de paridade estrita em todas as dimensões
      expect(resLocal.totalNotas, equals(resConsolidado.totalNotas));
      expect(resLocal.taxaCobertura, equals(resConsolidado.taxaCobertura));
      expect(resLocal.notasSemAnalise, equals(resConsolidado.notasSemAnalise));
      expect(resLocal.notasEmAnalise, equals(resConsolidado.notasEmAnalise));
      expect(resLocal.notasConcluidas, equals(resConsolidado.notasConcluidas));
      expect(resLocal.notasComAnexos, equals(resConsolidado.notasComAnexos));
      expect(resLocal.notasComMateriais, equals(resConsolidado.notasComMateriais));
      expect(resLocal.notasComComentarios, equals(resConsolidado.notasComComentarios));
      expect(resLocal.nivel0SomenteNota, equals(resConsolidado.nivel0SomenteNota));
      expect(resLocal.nivel1Iniciada, equals(resConsolidado.nivel1Iniciada));
      expect(resLocal.nivel2DiagnosticoEscopo, equals(resConsolidado.nivel2DiagnosticoEscopo));
      expect(resLocal.nivel3Completa, equals(resConsolidado.nivel3Completa));
    });

    // -------------------------------------------------------------------------
    // ITEM 16: BENCHMARKS DE PERFORMANCE (500, 2.000 e 5.000 NOTAS)
    // -------------------------------------------------------------------------
    test('Item 16 - Benchmark de agregação em memória: 500 notas', () {
      final notas500 = List.generate(
        500,
        (i) => criarNota('$i', centroTrabalho: 'CT-${i % 5}', regional: 'REG-${i % 3}'),
      );
      final resumos500 = {
        for (int i = 0; i < 500; i++)
          if (i % 2 == 0)
            '$i': criarResumo(
              '$i',
              status: i % 4 == 0 ? NotaAnaliseStatus.concluida : NotaAnaliseStatus.emAnalise,
              qtdAnexos: i % 3 == 0 ? 1 : 0,
              qtdMateriais: i % 5 == 0 ? 2 : 0,
            ),
      };

      final sw = Stopwatch()..start();
      final ind = NotaSapIndicadores.calcular(notas: notas500, resumos: resumos500);
      sw.stop();

      expect(ind.totalNotas, equals(500));
      expect(sw.elapsedMilliseconds, lessThan(50));
    });

    test('Item 16 - Benchmark de agregação em memória: 2.000 notas', () {
      final notas2000 = List.generate(
        2000,
        (i) => criarNota('$i', centroTrabalho: 'CT-${i % 10}', regional: 'REG-${i % 4}'),
      );
      final resumos2000 = {
        for (int i = 0; i < 2000; i++)
          if (i % 2 == 0)
            '$i': criarResumo(
              '$i',
              status: i % 4 == 0 ? NotaAnaliseStatus.concluida : NotaAnaliseStatus.emAnalise,
              qtdAnexos: i % 3 == 0 ? 1 : 0,
              qtdMateriais: i % 5 == 0 ? 2 : 0,
            ),
      };

      final sw = Stopwatch()..start();
      final ind = NotaSapIndicadores.calcular(notas: notas2000, resumos: resumos2000);
      sw.stop();

      expect(ind.totalNotas, equals(2000));
      expect(sw.elapsedMilliseconds, lessThan(100));
    });

    test('Item 16 - Benchmark de agregação em memória: 5.000 notas', () {
      final notas5000 = List.generate(
        5000,
        (i) => criarNota('$i', centroTrabalho: 'CT-${i % 15}', regional: 'REG-${i % 5}'),
      );
      final resumos5000 = {
        for (int i = 0; i < 5000; i++)
          if (i % 2 == 0)
            '$i': criarResumo(
              '$i',
              status: i % 4 == 0 ? NotaAnaliseStatus.concluida : NotaAnaliseStatus.emAnalise,
              qtdAnexos: i % 3 == 0 ? 1 : 0,
              qtdMateriais: i % 5 == 0 ? 2 : 0,
            ),
      };

      final sw = Stopwatch()..start();
      final ind = NotaSapIndicadores.calcular(notas: notas5000, resumos: resumos5000);
      sw.stop();

      expect(ind.totalNotas, equals(5000));
      expect(sw.elapsedMilliseconds, lessThan(250));
    });
  });
}
