import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/design_system/theme/taskflow_theme_extension.dart';
import 'package:task2026/models/nota_sap.dart';
import 'package:task2026/models/nota_sap_analise.dart';
import 'package:task2026/models/nota_sap_analise_evidencia.dart';
import 'package:task2026/services/nota_sap_analise_service.dart';
import 'package:task2026/widgets/nota_workspace/nota_vincular_evidencia_historica_dialog.dart';
import 'package:task2026/widgets/nota_workspace/nota_workspace_contextual_evidence_panel.dart';

class MockNotaSapAnaliseServiceUI extends Fake implements NotaSapAnaliseService {
  final List<NotaSapAnaliseEvidencia> evidencias = [];
  bool vincularChamado = false;
  bool desvincularChamado = false;
  bool atualizarVersaoChamado = false;
  String? ultimoObs;
  int? ultimaVersao;
  NotaTipoVinculoEvidencia? ultimaSecao;

  @override
  Future<NotaSapAnaliseEvidencia> vincularEvidencia({
    required String notaSapId,
    String? anexoId,
    String? mediaImageId,
    NotaEvidenciaTipoFonte? tipoFonte,
    required NotaTipoVinculoEvidencia tipoVinculo,
    int? anotacaoVersao,
    String? observacao,
    int ordem = 0,
    String? criadoPor,
    String? criadoPorNome,
  }) async {
    vincularChamado = true;
    ultimoObs = observacao;
    ultimaVersao = anotacaoVersao;
    ultimaSecao = tipoVinculo;

    final ev = NotaSapAnaliseEvidencia(
      id: 'ev-${evidencias.length + 1}',
      notaSapId: notaSapId,
      tipoFonte: tipoFonte ?? NotaEvidenciaTipoFonte.anexoNotaHistorica,
      anexoId: anexoId,
      tipoVinculo: tipoVinculo,
      anotacaoVersao: anotacaoVersao,
      observacao: observacao,
    );
    evidencias.add(ev);
    return ev;
  }

  @override
  Future<String> obterUrlAssinada(
    NotaSapAnexo anexo, {
    Duration? expires,
    bool forDownload = false,
  }) async {
    return 'https://storage.local/test/${anexo.caminhoArquivo}';
  }

  @override
  Future<void> desvincularEvidencia({
    required String notaSapId,
    String? anexoId,
    String? mediaImageId,
    NotaEvidenciaTipoFonte? tipoFonte,
    required NotaTipoVinculoEvidencia tipoVinculo,
  }) async {
    desvincularChamado = true;
    evidencias.removeWhere((e) => e.anexoId == anexoId && e.tipoVinculo == tipoVinculo);
  }

  Future<NotaSapAnaliseEvidencia> atualizarVersaoEvidencia({
    required String evidenciaId,
    required int? novaAnotacaoVersao,
  }) async {
    atualizarVersaoChamado = true;
    final idx = evidencias.indexWhere((e) => e.id == evidenciaId);
    final atualizada = evidencias[idx].copyWith(anotacaoVersao: novaAnotacaoVersao);
    evidencias[idx] = atualizada;
    return atualizada;
  }
}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      extensions: [TaskFlowThemeExtension.light()],
    ),
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockNotaSapAnaliseServiceUI service;

  final notaAtual = NotaSAP(
    id: 'nota-atual-1',
    nota: '10002026',
    descricao: 'Nota Atual',
  );

  final anexoHistorico = NotaSapAnexo(
    id: 'anexo-hist-1',
    notaSapId: 'nota-origem-9',
    nomeArquivo: 'foto_2023.jpg',
    nomeOriginal: 'foto_antiga.jpg',
    tipoArquivo: NotaAnexoTipo.imagem,
    caminhoArquivo: 'nota-origem-9/foto_2023.jpg',
    tamanhoBytes: 3000,
    origem: 'SAP',
    versaoAnotacao: 1,
    createdAt: DateTime(2023, 5, 10),
  );

  setUp(() {
    service = MockNotaSapAnaliseServiceUI();
  });

  group('TESTES UI — ANEXO HISTÓRICO COMO EVIDÊNCIA FORMAL', () {
    testWidgets('1. Diálogo de Vínculo: Exibe seções e opções de representação', (tester) async {
      tester.view.physicalSize = const Size(1280, 960);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () {
                NotaVincularEvidenciaHistoricaDialog.exibir(
                  context: ctx,
                  anexoHistorico: anexoHistorico,
                  notaAtual: notaAtual,
                  service: service,
                  numeroNotaHistorica: '90000099',
                );
              },
              child: const Text('Abrir Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Dialog'));
      await tester.pumpAndSettle();

      // Verifica título do diálogo e número da Nota de origem
      expect(find.text('Vincular Evidência Histórica'), findsOneWidget);
      expect(find.textContaining('90000099'), findsWidgets);

      // Verifica seções disponíveis em Chips
      expect(find.text('Diagnóstico Prévio'), findsOneWidget);
      expect(find.text('Escopo Detalhado'), findsOneWidget);

      // Verifica representação Original puro vs Anotado v1
      expect(find.text('Original puro'), findsOneWidget);
      expect(find.text('Anotado (v1)'), findsOneWidget);

      // Botão Cancelar fecha sem vincular
      final botaoCancelar = find.text('Cancelar');
      await tester.ensureVisible(botaoCancelar);
      await tester.tap(botaoCancelar);
      await tester.pumpAndSettle();
      expect(find.text('Vincular Evidência Histórica'), findsNothing);
      expect(service.vincularChamado, isFalse);
    });

    testWidgets('2. Diálogo de Vínculo: Selecionar seção, observação e Confirmar', (tester) async {
      tester.view.physicalSize = const Size(1280, 960);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () {
                NotaVincularEvidenciaHistoricaDialog.exibir(
                  context: ctx,
                  anexoHistorico: anexoHistorico,
                  notaAtual: notaAtual,
                  service: service,
                );
              },
              child: const Text('Abrir Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Dialog'));
      await tester.pumpAndSettle();

      // Seleciona a seção Escopo Detalhado
      await tester.tap(find.text('Escopo Detalhado'));
      await tester.pumpAndSettle();

      // Digita observação
      await tester.enterText(
        find.byType(TextField),
        'Corrosão semelhante à ocorrida em 2023.',
      );

      // Clica em Confirmar Vínculo
      final botaoConfirmar = find.text('Confirmar Vínculo');
      await tester.ensureVisible(botaoConfirmar);
      await tester.tap(botaoConfirmar);
      await tester.pumpAndSettle();

      expect(service.vincularChamado, isTrue);
      expect(service.ultimaSecao, equals(NotaTipoVinculoEvidencia.escopo));
      expect(service.ultimoObs, equals('Corrosão semelhante à ocorrida em 2023.'));
    });

    testWidgets('3. Painel Contextual: Badge histórico âmbar e botão Ver Nota Origem', (tester) async {
      bool abrirOrigemInvocado = false;
      NotaSAP? notaOrigemInvocada;

      final evidenciaHistorica = NotaSapAnaliseEvidencia(
        id: 'ev-hist-1',
        notaSapId: notaAtual.id,
        tipoFonte: NotaEvidenciaTipoFonte.anexoNotaHistorica,
        anexoId: anexoHistorico.id,
        tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
        anexo: anexoHistorico,
        numeroNotaHistorica: '90000099',
        observacao: 'Fissura estrutural prévia',
        createdAt: DateTime(2026, 10, 31),
      );

      await tester.pumpWidget(
        _wrap(
          NotaWorkspaceContextualEvidencePanel(
            notaSapId: notaAtual.id,
            nota: notaAtual,
            evidencias: [evidenciaHistorica],
            selectedEvidence: evidenciaHistorica,
            activeSection: NotaTipoVinculoEvidencia.diagnostico,
            service: service,
            onSelectEvidence: (_) {},
            onRefreshEvidencias: () {},
            onVincularNovaEvidencia: (_) {},
            onAbrirNotaHistorica: (notaHist) {
              abrirOrigemInvocado = true;
              notaOrigemInvocada = notaHist;
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verifica tag e texto de evidência histórica
      expect(find.textContaining('EVIDÊNCIA HISTÓRICA'), findsWidgets);
      expect(find.textContaining('90000099'), findsWidgets);

      // Verifica botão para abrir a Nota de Origem
      final botaoOrigem = find.text('Nota 90000099');
      expect(botaoOrigem, findsOneWidget);

      await tester.tap(botaoOrigem);
      await tester.pumpAndSettle();

      expect(abrirOrigemInvocado, isTrue);
      expect(notaOrigemInvocada?.nota, equals('90000099'));
    });

    testWidgets('4. Painel Contextual: Remover vínculo (desvincular)', (tester) async {
      final evidenciaHistorica = NotaSapAnaliseEvidencia(
        id: 'ev-hist-1',
        notaSapId: notaAtual.id,
        tipoFonte: NotaEvidenciaTipoFonte.anexoNotaHistorica,
        anexoId: anexoHistorico.id,
        tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
        anexo: anexoHistorico,
        numeroNotaHistorica: '90000099',
      );
      service.evidencias.add(evidenciaHistorica);

      await tester.pumpWidget(
        _wrap(
          NotaWorkspaceContextualEvidencePanel(
            notaSapId: notaAtual.id,
            nota: notaAtual,
            evidencias: [evidenciaHistorica],
            selectedEvidence: evidenciaHistorica,
            activeSection: NotaTipoVinculoEvidencia.diagnostico,
            service: service,
            onSelectEvidence: (_) {},
            onRefreshEvidencias: () {},
            onVincularNovaEvidencia: (_) {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Clica no botão de desvincular
      final botaoDesvincular = find.byTooltip('Desvincular desta seção');
      expect(botaoDesvincular, findsOneWidget);

      await tester.tap(botaoDesvincular);
      await tester.pumpAndSettle();

      expect(service.desvincularChamado, isTrue);
    });
  });
}
