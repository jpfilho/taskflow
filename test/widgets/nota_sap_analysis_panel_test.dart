import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/models/nota_sap.dart';
import 'package:task2026/models/nota_sap_analise.dart';
import 'package:task2026/services/nota_sap_analise_service.dart';
import 'package:task2026/widgets/nota_workspace/nota_sap_analysis_panel.dart';

class MockNotaSapAnaliseServiceForPanel extends Fake implements NotaSapAnaliseService {
  final Map<String, NotaSapAnalise?> analisesMock = {};
  final Map<String, NotaSapResumoAnalise> resumosMock = {};

  @override
  Future<NotaSapAnalise?> buscarAnalise(String notaSapId) async {
    return analisesMock[notaSapId];
  }

  @override
  Future<Map<String, NotaSapResumoAnalise>> buscarResumoAnalises(
    List<String> notaSapIds, {
    bool forceRefresh = false,
  }) async {
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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockNota = NotaSAP(
    id: 'nota-123',
    nota: '10009988',
    descricao: 'Substituição de poste danificado',
  );

  Widget createWidget({
    List<NotaSAP> notas = const [],
    String currentEscopo = '',
    String currentObservacoes = '',
    double currentHoras = 0.0,
    ValueChanged<String>? onUsarEscopo,
    ValueChanged<String>? onUsarDiagnostico,
    ValueChanged<double>? onUsarEstimativa,
    ValueChanged<NotaSAP>? onAbrirWorkspace,
    NotaSapAnaliseService? analiseService,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: NotaSapAnalysisPanel(
            notas: notas,
            currentEscopo: currentEscopo,
            currentObservacoes: currentObservacoes,
            currentHoras: currentHoras,
            onUsarEscopo: onUsarEscopo,
            onUsarDiagnostico: onUsarDiagnostico,
            onUsarEstimativa: onUsarEstimativa,
            onAbrirWorkspace: onAbrirWorkspace,
            analiseService: analiseService,
          ),
        ),
      ),
    );
  }

  group('Fase 5 (com ajustes de Seções 27-31): NotaSapAnalysisPanel & Aproveitamento de Dados', () {
    testWidgets('1. Não renderiza nada quando lista de notas é vazia', (tester) async {
      await tester.pumpWidget(createWidget(notas: []));
      await tester.pump();
      expect(find.byType(NotaSapAnalysisPanel), findsOneWidget);
      expect(find.text('Análise Prévia da Nota SAP'), findsNothing);
    });

    testWidgets('2. Exibe estado "Sem análise técnica" para nota não analisada', (tester) async {
      final mockService = MockNotaSapAnaliseServiceForPanel();

      await tester.pumpWidget(createWidget(
        notas: [mockNota],
        analiseService: mockService,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Análise Prévia da Nota SAP'), findsOneWidget);
      expect(find.text('Nota 10009988'), findsOneWidget);
      expect(find.text('Sem análise técnica'), findsOneWidget);
      expect(find.text('Iniciar Análise'), findsOneWidget);
    });

    testWidgets('3. Clique em Iniciar Análise aciona callback onAbrirWorkspace', (tester) async {
      final mockService = MockNotaSapAnaliseServiceForPanel();

      NotaSAP? notaClicada;
      await tester.pumpWidget(createWidget(
        notas: [mockNota],
        analiseService: mockService,
        onAbrirWorkspace: (n) => notaClicada = n,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Iniciar Análise'));
      await tester.pump();

      expect(notaClicada, isNotNull);
      expect(notaClicada!.id, equals('nota-123'));
    });

    testWidgets('4. Exibe chips de aproveitamento quando nota possui análise', (tester) async {
      final analiseMock = NotaSapAnalise(
        id: 'analise-1',
        notaSapId: 'nota-123',
        statusAnalise: NotaAnaliseStatus.concluida,
        escopoDetalhado: 'Substituição de poste de madeira por fibra 12m',
        diagnosticoPrevio: 'Poste quebrado por abalroamento veicular',
        estimativaHoras: 4.5,
      );

      final mockService = MockNotaSapAnaliseServiceForPanel();
      mockService.analisesMock['nota-123'] = analiseMock;
      mockService.resumosMock['nota-123'] = const NotaSapResumoAnalise(
        notaSapId: 'nota-123',
        status: NotaAnaliseStatus.concluida,
        quantidadeMateriais: 3,
        quantidadeAnexos: 2,
      );

      await tester.pumpWidget(createWidget(
        notas: [mockNota],
        analiseService: mockService,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Copiar Escopo'), findsOneWidget);
      expect(find.text('Copiar Diagnóstico'), findsOneWidget);
      expect(find.text('Usar Horas: 4.5h'), findsOneWidget);
      expect(find.text('3 materiais previstos'), findsOneWidget);
      expect(find.textContaining('2 arquivo'), findsOneWidget);
    });

    testWidgets('Teste A: Escopo com destino vazio preenche diretamente', (tester) async {
      final analiseMock = NotaSapAnalise(
        id: 'analise-1',
        notaSapId: 'nota-123',
        statusAnalise: NotaAnaliseStatus.concluida,
        escopoDetalhado: 'Substituição de poste de madeira por fibra 12m',
        diagnosticoPrevio: 'Poste quebrado por abalroamento veicular',
        estimativaHoras: 4.5,
      );

      final mockService = MockNotaSapAnaliseServiceForPanel();
      mockService.analisesMock['nota-123'] = analiseMock;

      String? escopoUsado;

      await tester.pumpWidget(createWidget(
        notas: [mockNota],
        analiseService: mockService,
        currentEscopo: '',
        onUsarEscopo: (val) => escopoUsado = val,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Copiar Escopo'));
      await tester.pumpAndSettle();

      expect(escopoUsado, equals('Substituição de poste de madeira por fibra 12m'));
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('Teste B: Escopo com destino preenchido -> Adicionar ao conteúdo atual', (tester) async {
      final analiseMock = NotaSapAnalise(
        id: 'analise-1',
        notaSapId: 'nota-123',
        statusAnalise: NotaAnaliseStatus.concluida,
        escopoDetalhado: 'Substituição de poste de madeira por fibra 12m',
        diagnosticoPrevio: 'Poste quebrado por abalroamento veicular',
        estimativaHoras: 4.5,
      );

      final mockService = MockNotaSapAnaliseServiceForPanel();
      mockService.analisesMock['nota-123'] = analiseMock;

      String? escopoUsado;

      await tester.pumpWidget(createWidget(
        notas: [mockNota],
        analiseService: mockService,
        currentEscopo: 'Escopo original digitado',
        onUsarEscopo: (val) => escopoUsado = val,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Copiar Escopo'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Adicionar ao conteúdo atual'), findsOneWidget);

      await tester.tap(find.text('Adicionar ao conteúdo atual'));
      await tester.pumpAndSettle();

      expect(
        escopoUsado,
        equals('Escopo original digitado\n\n--- Nota SAP 10009988 ---\nSubstituição de poste de madeira por fibra 12m'),
      );
    });

    testWidgets('Teste C: Escopo com destino preenchido -> Substituir conteúdo', (tester) async {
      final analiseMock = NotaSapAnalise(
        id: 'analise-1',
        notaSapId: 'nota-123',
        statusAnalise: NotaAnaliseStatus.concluida,
        escopoDetalhado: 'Substituição de poste de madeira por fibra 12m',
      );

      final mockService = MockNotaSapAnaliseServiceForPanel();
      mockService.analisesMock['nota-123'] = analiseMock;

      String? escopoUsado;

      await tester.pumpWidget(createWidget(
        notas: [mockNota],
        analiseService: mockService,
        currentEscopo: 'Escopo original',
        onUsarEscopo: (val) => escopoUsado = val,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Copiar Escopo'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Substituir conteúdo'));
      await tester.pumpAndSettle();

      expect(escopoUsado, equals('Substituição de poste de madeira por fibra 12m'));
    });

    testWidgets('Teste D: Escopo com destino preenchido -> Cancelar', (tester) async {
      final analiseMock = NotaSapAnalise(
        id: 'analise-1',
        notaSapId: 'nota-123',
        statusAnalise: NotaAnaliseStatus.concluida,
        escopoDetalhado: 'Substituição de poste de madeira por fibra 12m',
      );

      final mockService = MockNotaSapAnaliseServiceForPanel();
      mockService.analisesMock['nota-123'] = analiseMock;

      String? escopoUsado;

      await tester.pumpWidget(createWidget(
        notas: [mockNota],
        analiseService: mockService,
        currentEscopo: 'Escopo original',
        onUsarEscopo: (val) => escopoUsado = val,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Copiar Escopo'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(escopoUsado, isNull);
    });

    testWidgets('Teste E: Diagnóstico com destino preenchido -> Adicionar', (tester) async {
      final analiseMock = NotaSapAnalise(
        id: 'analise-1',
        notaSapId: 'nota-123',
        statusAnalise: NotaAnaliseStatus.concluida,
        diagnosticoPrevio: 'Poste quebrado na base',
      );

      final mockService = MockNotaSapAnaliseServiceForPanel();
      mockService.analisesMock['nota-123'] = analiseMock;

      String? diagUsado;

      await tester.pumpWidget(createWidget(
        notas: [mockNota],
        analiseService: mockService,
        currentObservacoes: 'Obs inicial',
        onUsarDiagnostico: (val) => diagUsado = val,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Copiar Diagnóstico'));
      await tester.pumpAndSettle();

      expect(find.text('Adicionar ao conteúdo atual'), findsOneWidget);
      await tester.tap(find.text('Adicionar ao conteúdo atual'));
      await tester.pumpAndSettle();

      expect(
        diagUsado,
        equals('Obs inicial\n\n--- Nota SAP 10009988 ---\nPoste quebrado na base'),
      );
    });

    testWidgets('Teste F: Diagnóstico com destino preenchido -> Substituir', (tester) async {
      final analiseMock = NotaSapAnalise(
        id: 'analise-1',
        notaSapId: 'nota-123',
        statusAnalise: NotaAnaliseStatus.concluida,
        diagnosticoPrevio: 'Poste quebrado na base',
      );

      final mockService = MockNotaSapAnaliseServiceForPanel();
      mockService.analisesMock['nota-123'] = analiseMock;

      String? diagUsado;

      await tester.pumpWidget(createWidget(
        notas: [mockNota],
        analiseService: mockService,
        currentObservacoes: 'Obs inicial',
        onUsarDiagnostico: (val) => diagUsado = val,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Copiar Diagnóstico'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Substituir conteúdo'));
      await tester.pumpAndSettle();

      expect(diagUsado, equals('Poste quebrado na base'));
    });

    testWidgets('Teste G: Horas já existentes -> confirmar substituição', (tester) async {
      final analiseMock = NotaSapAnalise(
        id: 'analise-1',
        notaSapId: 'nota-123',
        statusAnalise: NotaAnaliseStatus.concluida,
        estimativaHoras: 4.5,
      );

      final mockService = MockNotaSapAnaliseServiceForPanel();
      mockService.analisesMock['nota-123'] = analiseMock;

      double? horasUsadas;

      await tester.pumpWidget(createWidget(
        notas: [mockNota],
        analiseService: mockService,
        currentHoras: 2.0,
        onUsarEstimativa: (h) => horasUsadas = h,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Usar Horas: 4.5h'));
      await tester.pumpAndSettle();

      // Confirma que abriu diálogo de substituição de horas
      expect(find.text('Substituir Horas Previstas'), findsOneWidget);
      expect(find.textContaining('A tarefa já possui 2.0h previstas'), findsOneWidget);

      // Clica em Cancelar
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(horasUsadas, isNull);

      // Clica novamente e confirma Substituir
      await tester.tap(find.text('Usar Horas: 4.5h'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Substituir'));
      await tester.pumpAndSettle();

      expect(horasUsadas, equals(4.5));
    });

    testWidgets('Horas sem valor anterior (0h) preenche direto sem diálogo', (tester) async {
      final analiseMock = NotaSapAnalise(
        id: 'analise-1',
        notaSapId: 'nota-123',
        statusAnalise: NotaAnaliseStatus.concluida,
        estimativaHoras: 4.5,
      );

      final mockService = MockNotaSapAnaliseServiceForPanel();
      mockService.analisesMock['nota-123'] = analiseMock;

      double? horasUsadas;

      await tester.pumpWidget(createWidget(
        notas: [mockNota],
        analiseService: mockService,
        currentHoras: 0.0,
        onUsarEstimativa: (h) => horasUsadas = h,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Usar Horas: 4.5h'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(horasUsadas, equals(4.5));
    });
  });
}
