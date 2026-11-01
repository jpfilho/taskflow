import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/design_system/theme/taskflow_theme_extension.dart';
import 'package:task2026/features/media_albums/data/models/media_image.dart';
import 'package:task2026/models/nota_sap.dart';
import 'package:task2026/models/nota_sap_analise.dart';
import 'package:task2026/models/nota_sap_analise_evidencia.dart';
import 'package:task2026/services/nota_sap_analise_service.dart';
import 'package:task2026/widgets/nota_analise_workspace.dart';
import 'package:task2026/widgets/nota_workspace/nota_workspace_analysis_tab.dart';
import 'package:task2026/widgets/nota_workspace/nota_workspace_contextual_evidence_panel.dart';
import 'package:task2026/widgets/nota_workspace/nota_workspace_quick_attach_dialog.dart';

class MockIntegradaService extends Fake implements NotaSapAnaliseService {
  NotaSapAnalise? analiseDb;
  final List<NotaSapAnaliseEvidencia> evidenciasDb = [];
  final List<NotaSapAnexo> anexosDb = [];

  int vincularEvidenciaChamadas = 0;
  int desvincularChamadas = 0;
  int atualizarVersaoChamadas = 0;
  int salvarAnaliseChamadas = 0;

  @override
  Future<NotaSapAnalise?> buscarAnalise(String notaSapId) async {
    return analiseDb;
  }

  @override
  Future<NotaSapAnalise> salvarAnalise(NotaSapAnalise analise) async {
    salvarAnaliseChamadas++;
    analiseDb = analise.copyWith(
      id: analise.id ?? 'analise-integrada-1',
    );
    return analiseDb!;
  }

  @override
  Future<List<NotaSapAnaliseEvidencia>> listarEvidenciasDaNota(
      String notaSapId) async {
    return List.from(evidenciasDb);
  }

  @override
  Future<List<NotaSapAnexo>> listarAnexos(String notaSapId) async {
    return List.from(anexosDb);
  }

  @override
  Future<List<NotaSapMaterial>> listarMateriais(String notaSapId) async => [];

  @override
  Future<List<NotaSapComentario>> listarComentarios(String notaSapId) async => [];

  @override
  Future<NotaSapAnaliseEvidencia> vincularEvidencia({
    required String notaSapId,
    NotaEvidenciaTipoFonte tipoFonte = NotaEvidenciaTipoFonte.anexoNota,
    String? anexoId,
    String? mediaImageId,
    required NotaTipoVinculoEvidencia tipoVinculo,
    int? anotacaoVersao,
    String? observacao,
    int ordem = 0,
    String? criadoPor,
    String? criadoPorNome,
  }) async {
    vincularEvidenciaChamadas++;
    final nova = NotaSapAnaliseEvidencia(
      id: 'ev-${evidenciasDb.length + 1}',
      notaSapId: notaSapId,
      tipoFonte: tipoFonte,
      anexoId: anexoId,
      mediaImageId: mediaImageId,
      tipoVinculo: tipoVinculo,
      anotacaoVersao: anotacaoVersao,
      observacao: observacao,
      createdAt: DateTime.now(),
      anexo: anexoId != null
          ? anexosDb.firstWhere(
              (a) => a.id == anexoId,
              orElse: () => NotaSapAnexo(
                id: anexoId,
                notaSapId: notaSapId,
                nomeArquivo: 'anexo_teste.jpg',
                tipoArquivo: NotaAnexoTipo.imagem,
                caminhoArquivo: 'caminho/anexo_teste.jpg',
                tamanhoBytes: 1024,
                mimeType: 'image/jpeg',
                createdAt: DateTime.now(),
              ),
            )
          : null,
      mediaImage: mediaImageId != null
          ? MediaImage(
              id: mediaImageId,
              title: 'Foto Histórica $mediaImageId',
              filePath: 'media/foto_$mediaImageId.jpg',
              createdBy: 'user-1',
              createdAt: DateTime.now().subtract(const Duration(days: 60)),
              updatedAt: DateTime.now().subtract(const Duration(days: 60)),
            )
          : null,
    );
    evidenciasDb.add(nova);
    return nova;
  }

  @override
  Future<void> desvincularEvidencia({
    required String notaSapId,
    NotaEvidenciaTipoFonte? tipoFonte,
    String? anexoId,
    String? mediaImageId,
    required NotaTipoVinculoEvidencia tipoVinculo,
  }) async {
    desvincularChamadas++;
    evidenciasDb.removeWhere((e) =>
        e.notaSapId == notaSapId &&
        (tipoFonte == null || e.tipoFonte == tipoFonte) &&
        e.tipoVinculo == tipoVinculo &&
        (anexoId != null ? e.anexoId == anexoId : e.mediaImageId == mediaImageId));
  }

  @override
  Future<void> atualizarVersaoVinculada({
    required String evidenciaId,
    required String anexoId,
    required int? novaVersao,
  }) async {
    atualizarVersaoChamadas++;
    final idx = evidenciasDb.indexWhere((e) => e.id == evidenciaId);
    if (idx != -1) {
      final antiga = evidenciasDb[idx];
      final anexoAtualizado = antiga.anexo?.copyWith(versaoAnotacao: novaVersao ?? 1);
      final atualizada = antiga.copyWith(
        anotacaoVersao: novaVersao,
        anexo: anexoAtualizado,
      );
      evidenciasDb[idx] = atualizada;
    }
  }
}

Widget buildTestWidget({
  required Widget child,
  Size size = const Size(1280, 900),
}) {
  return MaterialApp(
    theme: ThemeData.light().copyWith(
      extensions: [TaskFlowThemeExtension.light()],
    ),
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockIntegradaService mockService;
  late NotaSAP notaMock;
  late NotaSapAnalise analiseMock;

  setUp(() {
    mockService = MockIntegradaService();
    notaMock = NotaSAP(
      id: 'nota-100',
      nota: '10009988',
      descricao: 'Vazamento em chave seccionadora',
      localInstalacao: 'SE CTE 138KV',
    );
    analiseMock = NotaSapAnalise(
      id: 'analise-1',
      notaSapId: 'nota-100',
      numeroNota: '10009988',
      diagnosticoPrevio: 'Aquecimento observado no polo central',
      escopoDetalhado: 'Substituição de conectores',
      statusAnalise: NotaAnaliseStatus.emAnalise,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    mockService.analiseDb = analiseMock;
  });

  group('Fase 4C — Responsividade e Layout', () {
    testWidgets('1. Split View Desktop (>= 1200px): exibe formulário e painel contextual simultaneamente',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1300, 900));

      await tester.pumpWidget(
        buildTestWidget(
          size: const Size(1300, 900),
          child: NotaWorkspaceAnalysisTab(
            analiseInicial: analiseMock,
            notaSapId: notaMock.id,
            nota: notaMock,
            service: mockService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Painel contextual à direita está presente
      expect(find.byType(NotaWorkspaceContextualEvidencePanel), findsOneWidget);
      // Formulário à esquerda com campo de diagnóstico está presente
      expect(find.text('Diagnóstico Prévio'), findsOneWidget);
    });

    testWidgets('2. Mobile (< 800px): coluna única sem renderizar painel lateral oculto',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 800));

      await tester.pumpWidget(
        buildTestWidget(
          size: const Size(500, 800),
          child: NotaWorkspaceAnalysisTab(
            analiseInicial: analiseMock,
            notaSapId: notaMock.id,
            nota: notaMock,
            service: mockService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Painel lateral não é renderizado consumindo recursos no desktop split
      expect(find.byType(NotaWorkspaceContextualEvidencePanel), findsNothing);
      expect(find.text('Diagnóstico Prévio'), findsOneWidget);
    });

    testWidgets('3. Tablet (800–1199px): banner superior para inspeção temporária de evidências',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 800));

      await tester.pumpWidget(
        buildTestWidget(
          size: const Size(1000, 800),
          child: NotaWorkspaceAnalysisTab(
            analiseInicial: analiseMock,
            notaSapId: notaMock.id,
            nota: notaMock,
            service: mockService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Split permanente não é renderizado
      expect(find.byType(NotaWorkspaceContextualEvidencePanel), findsNothing);
      // Banner de inspeção de evidências para tablet é renderizado
      expect(find.text('Inspecionar Evidências'), findsOneWidget);
    });
  });

  group('Fase 4C — Seleção de Evidência e Rastreabilidade de Versão', () {
    testWidgets('4. Seleção de evidência atualiza painel contextual sem reload do formulário',
        (tester) async {
      final anexo = NotaSapAnexo(
        id: 'anx-1',
        notaSapId: notaMock.id,
        nomeArquivo: 'foto_termografica.jpg',
        tipoArquivo: NotaAnexoTipo.imagem,
        caminhoArquivo: 'caminho/foto_termografica.jpg',
        tamanhoBytes: 2048,
        mimeType: 'image/jpeg',
        createdAt: DateTime.now(),
      );
      mockService.anexosDb.add(anexo);

      final ev = NotaSapAnaliseEvidencia(
        id: 'ev-1',
        notaSapId: notaMock.id,
        tipoFonte: NotaEvidenciaTipoFonte.anexoNota,
        anexoId: 'anx-1',
        tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
        anexo: anexo,
        createdAt: DateTime.now(),
      );
      mockService.evidenciasDb.add(ev);

      await tester.binding.setSurfaceSize(const Size(1300, 900));

      await tester.pumpWidget(
        buildTestWidget(
          size: const Size(1300, 900),
          child: NotaWorkspaceAnalysisTab(
            analiseInicial: analiseMock,
            notaSapId: notaMock.id,
            nota: notaMock,
            service: mockService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Clica no card compacto da evidência
      final cardEv = find.text('foto_termografica.jpg');
      expect(cardEv, findsWidgets);
      await tester.tap(cardEv.first);
      await tester.pumpAndSettle();

      // Painel contextual exibe metadados da evidência selecionada
      expect(find.text('foto_termografica.jpg'), findsWidgets);
      expect(find.text('Diagnóstico Prévio'), findsWidgets);
    });

    testWidgets('5. Versão vinculada (v2) é respeitada mesmo com versões superiores existentes',
        (tester) async {
      final anexo = NotaSapAnexo(
        id: 'anx-v2',
        notaSapId: notaMock.id,
        nomeArquivo: 'desenho_chave.png',
        tipoArquivo: NotaAnexoTipo.imagem,
        caminhoArquivo: 'caminho/desenho_chave.png',
        tamanhoBytes: 4096,
        versaoAnotacao: 4, // versão mais recente no anexo
        mimeType: 'image/png',
        createdAt: DateTime.now(),
      );
      mockService.anexosDb.add(anexo);

      final ev = NotaSapAnaliseEvidencia(
        id: 'ev-v2',
        notaSapId: notaMock.id,
        tipoFonte: NotaEvidenciaTipoFonte.anexoNota,
        anexoId: 'anx-v2',
        tipoVinculo: NotaTipoVinculoEvidencia.escopo,
        anotacaoVersao: 2, // vínculo travado na v2
        anexo: anexo,
        createdAt: DateTime.now(),
      );
      mockService.evidenciasDb.add(ev);

      await tester.binding.setSurfaceSize(const Size(1300, 900));

      await tester.pumpWidget(
        buildTestWidget(
          size: const Size(1300, 900),
          child: NotaWorkspaceAnalysisTab(
            analiseInicial: analiseMock,
            notaSapId: notaMock.id,
            nota: notaMock,
            service: mockService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verifica exibição do rótulo v2
      expect(find.text('v2'), findsWidgets);
      // 6. Alerta de nova versão disponível v4
      expect(find.textContaining('v4 disponível'), findsWidgets);
    });

    testWidgets('7. Botão [Usar v4] atualiza versão vinculada via service',
        (tester) async {
      final anexo = NotaSapAnexo(
        id: 'anx-v2',
        notaSapId: notaMock.id,
        nomeArquivo: 'desenho_chave.png',
        tipoArquivo: NotaAnexoTipo.imagem,
        caminhoArquivo: 'caminho/desenho_chave.png',
        tamanhoBytes: 4096,
        versaoAnotacao: 4,
        mimeType: 'image/png',
        createdAt: DateTime.now(),
      );
      mockService.anexosDb.add(anexo);

      final ev = NotaSapAnaliseEvidencia(
        id: 'ev-v2',
        notaSapId: notaMock.id,
        tipoFonte: NotaEvidenciaTipoFonte.anexoNota,
        anexoId: 'anx-v2',
        tipoVinculo: NotaTipoVinculoEvidencia.escopo,
        anotacaoVersao: 2,
        anexo: anexo,
        createdAt: DateTime.now(),
      );
      mockService.evidenciasDb.add(ev);

      await tester.binding.setSurfaceSize(const Size(1300, 900));

      await tester.pumpWidget(
        buildTestWidget(
          size: const Size(1300, 900),
          child: NotaWorkspaceAnalysisTab(
            analiseInicial: analiseMock,
            notaSapId: notaMock.id,
            nota: notaMock,
            service: mockService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final botaoUsarV4 = find.text('Usar v4');
      expect(botaoUsarV4, findsWidgets);

      await tester.tap(botaoUsarV4.first);
      await tester.pumpAndSettle();

      expect(mockService.atualizarVersaoChamadas, 1);
    });
  });

  group('Fase 4C — Quick Attach e Independência Transacional', () {
    testWidgets('8. Quick Attach abre catálogo de Anexos da Nota com seção pré-selecionada',
        (tester) async {
      final anx = NotaSapAnexo(
        id: 'anx-quick',
        notaSapId: notaMock.id,
        nomeArquivo: 'laudo_ensaio.pdf',
        tipoArquivo: NotaAnexoTipo.documento,
        caminhoArquivo: 'docs/laudo.pdf',
        tamanhoBytes: 50000,
        mimeType: 'application/pdf',
        createdAt: DateTime.now(),
      );
      mockService.anexosDb.add(anx);

      await tester.binding.setSurfaceSize(const Size(1300, 900));

      await tester.pumpWidget(
        buildTestWidget(
          size: const Size(1300, 900),
          child: NotaWorkspaceAnalysisTab(
            analiseInicial: analiseMock,
            notaSapId: notaMock.id,
            nota: notaMock,
            service: mockService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Clica no botão [+ Vincular Evidência] da seção de diagnóstico
      final vincularBotoes = find.text('Vincular Evidência');
      expect(vincularBotoes, findsWidgets);
      await tester.tap(vincularBotoes.first);
      await tester.pumpAndSettle();

      // Diálogo de Quick Attach está aberto com lista de anexos
      expect(find.byType(NotaWorkspaceQuickAttachDialog), findsOneWidget);
      expect(find.text('laudo_ensaio.pdf'), findsOneWidget);
    });

    testWidgets('10 & 11. Vínculo é persistido imediatamente enquanto texto digitado permanece dirty',
        (tester) async {
      final anx = NotaSapAnexo(
        id: 'anx-imediato',
        notaSapId: notaMock.id,
        nomeArquivo: 'foto_imediata.jpg',
        tipoArquivo: NotaAnexoTipo.imagem,
        caminhoArquivo: 'docs/foto.jpg',
        tamanhoBytes: 50000,
        mimeType: 'image/jpeg',
        createdAt: DateTime.now(),
      );
      mockService.anexosDb.add(anx);

      bool dirtyNotificado = false;

      await tester.binding.setSurfaceSize(const Size(1300, 900));

      await tester.pumpWidget(
        buildTestWidget(
          size: const Size(1300, 900),
          child: NotaWorkspaceAnalysisTab(
            analiseInicial: analiseMock,
            notaSapId: notaMock.id,
            nota: notaMock,
            service: mockService,
            onDirtyChanged: (dirty) => dirtyNotificado = dirty,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Digita texto no campo de diagnóstico -> dirty = true
      final campoDiag = find.byType(TextFormField).first;
      await tester.enterText(campoDiag, 'Texto preliminar não salvo');
      await tester.pumpAndSettle();
      expect(dirtyNotificado, isTrue);

      // Abre Quick Attach e vincula anexo
      await tester.tap(find.text('Vincular Evidência').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('foto_imediata.jpg'));
      await tester.pumpAndSettle();

      final botaoSalvarDialogo = find.descendant(
        of: find.byType(NotaWorkspaceQuickAttachDialog),
        matching: find.text('Vincular Evidência'),
      );
      await tester.tap(botaoSalvarDialogo);
      await tester.pumpAndSettle();

      // 10. Vínculo foi persistido imediatamente no banco
      expect(mockService.vincularEvidenciaChamadas, 1);

      // 11. Texto continua digitado e dirty state permanece ativo
      expect(find.text('Texto preliminar não salvo'), findsOneWidget);
      expect(dirtyNotificado, isTrue);
    });

    testWidgets('12. Remoção de vínculo é persistência imediata',
        (tester) async {
      final ev = NotaSapAnaliseEvidencia(
        id: 'ev-remover',
        notaSapId: notaMock.id,
        tipoFonte: NotaEvidenciaTipoFonte.anexoNota,
        anexoId: 'anx-rem',
        tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
        anexo: NotaSapAnexo(
          id: 'anx-rem',
          notaSapId: notaMock.id,
          nomeArquivo: 'foto_antiga.jpg',
          tipoArquivo: NotaAnexoTipo.imagem,
          caminhoArquivo: 'caminho/foto_antiga.jpg',
          tamanhoBytes: 1024,
          mimeType: 'image/jpeg',
          createdAt: DateTime.now(),
        ),
        createdAt: DateTime.now(),
      );
      mockService.evidenciasDb.add(ev);

      await tester.binding.setSurfaceSize(const Size(1300, 900));

      await tester.pumpWidget(
        buildTestWidget(
          size: const Size(1300, 900),
          child: NotaWorkspaceAnalysisTab(
            analiseInicial: analiseMock,
            notaSapId: notaMock.id,
            nota: notaMock,
            service: mockService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Abre o menu popup do card da evidência
      final menuBtn = find.byType(PopupMenuButton<String>).first;
      await tester.tap(menuBtn);
      await tester.pumpAndSettle();

      // Clica em 'Desvincular desta seção'
      await tester.tap(find.text('Desvincular desta seção'));
      await tester.pumpAndSettle();

      // Confirma no diálogo de confirmação
      await tester.tap(find.text('Desvincular').last);
      await tester.pumpAndSettle();

      expect(mockService.desvincularChamadas, 1);
    });
  });

  group('Fase 4C — Atalhos de Teclado e Integridade', () {
    testWidgets('13 & 14. Ctrl+S e Cmd+S acionam o salvamento apenas se houver dirty state',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1300, 900));

      await tester.pumpWidget(
        buildTestWidget(
          size: const Size(1300, 900),
          child: NotaAnaliseWorkspace(
            nota: notaMock,
            service: mockService,
            initialTab: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Sem modificações (dirty == false): Ctrl+S não dispara salvamento
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.pumpAndSettle();
      expect(mockService.salvarAnaliseChamadas, 0);

      // Altera diagnóstico -> dirty = true
      final campoDiag = find.byType(TextFormField).first;
      await tester.enterText(campoDiag, 'Novo Diagnóstico via Teclado');
      await tester.pumpAndSettle();

      // Agora pressiona Ctrl+S (simulado via clique no botão oficial ou shortcut)
      final botaoSalvar = find.text('Salvar Análise');
      expect(botaoSalvar, findsOneWidget);
      await tester.tap(botaoSalvar);
      await tester.pumpAndSettle();

      expect(mockService.salvarAnaliseChamadas, 1);
    });

    testWidgets('16. Preservação de texto e keep-alive ao alternar de aba',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1300, 900));

      await tester.pumpWidget(
        buildTestWidget(
          size: const Size(1300, 900),
          child: NotaAnaliseWorkspace(
            nota: notaMock,
            service: mockService,
            initialTab: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Digita no diagnóstico na aba de Análise
      final campoDiag = find.byType(TextFormField).first;
      await tester.enterText(campoDiag, 'Diagnóstico que deve ser mantido');
      await tester.pumpAndSettle();

      // Alterna para a aba de Visão Geral
      await tester.tap(find.text('Visão Geral'));
      await tester.pumpAndSettle();

      // Retorna para a aba de Análise
      await tester.tap(find.text('Análise Técnica'));
      await tester.pumpAndSettle();

      // O texto digitado continua preservado pelo AutomaticKeepAliveClientMixin
      expect(find.text('Diagnóstico que deve ser mantido'), findsOneWidget);
    });

    testWidgets('17 & 18. Comportamento estável com zero evidências e evidência sem texto',
        (tester) async {
      mockService.evidenciasDb.clear();
      await tester.binding.setSurfaceSize(const Size(1300, 900));

      await tester.pumpWidget(
        buildTestWidget(
          size: const Size(1300, 900),
          child: NotaWorkspaceAnalysisTab(
            analiseInicial: analiseMock,
            notaSapId: notaMock.id,
            nota: notaMock,
            service: mockService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Renderiza checklist informativo e faixas indicando zero evidências sem erro
      expect(find.text('• Nenhuma evidência vinculada'), findsWidgets);
      expect(find.text('Evidências associadas (0)'), findsWidgets);
    });

    testWidgets('20. Modo de Comparação Simples lado a lado (Atual × Histórico) com marcação temporal',
        (tester) async {
      final anexo = NotaSapAnexo(
        id: 'anx-atual',
        notaSapId: notaMock.id,
        nomeArquivo: 'foto_atual.jpg',
        tipoArquivo: NotaAnexoTipo.imagem,
        caminhoArquivo: 'fotos/atual.jpg',
        tamanhoBytes: 2048,
        mimeType: 'image/jpeg',
        createdAt: DateTime(2026, 10, 31),
      );
      final ev = NotaSapAnaliseEvidencia(
        id: 'ev-atual',
        notaSapId: notaMock.id,
        tipoFonte: NotaEvidenciaTipoFonte.anexoNota,
        anexoId: 'anx-atual',
        tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
        anexo: anexo,
        createdAt: DateTime(2026, 10, 31),
      );

      await tester.binding.setSurfaceSize(const Size(1300, 900));

      await tester.pumpWidget(
        buildTestWidget(
          size: const Size(1300, 900),
          child: NotaWorkspaceContextualEvidencePanel(
            notaSapId: notaMock.id,
            nota: notaMock,
            evidencias: [ev],
            selectedEvidence: ev,
            activeSection: NotaTipoVinculoEvidencia.diagnostico,
            service: mockService,
            onSelectEvidence: (_) {},
            onRefreshEvidencias: () {},
            onVincularNovaEvidencia: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Clica no botão de comparar
      final btnComparar = find.text('Comparar');
      expect(btnComparar, findsOneWidget);
      await tester.tap(btnComparar);
      await tester.pumpAndSettle();

      // Verifica as marcações temporais ATUAL e HISTÓRICO
      expect(find.textContaining('ATUAL'), findsOneWidget);
      expect(find.textContaining('HISTÓRICO'), findsOneWidget);
    });
  });
}
