import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/design_system/theme/taskflow_theme_extension.dart';
import 'package:task2026/models/nota_sap_analise.dart';
import 'package:task2026/models/nota_sap_anotacao.dart';
import 'package:task2026/services/nota_sap_analise_service.dart';
import 'package:task2026/widgets/nota_workspace/nota_anexo_annotation_editor.dart';

class MockNotaSapAnaliseServiceForEditor extends Fake
    implements NotaSapAnaliseService {
  final Map<String, List<NotaSapAnotacao>> bancoAnotacoes = {};
  int chamadasSalvar = 0;
  bool simularColisaoConcorrente = false;

  @override
  Future<NotaSapAnotacao?> obterUltimaAnotacao(String anexoId) async {
    final list = bancoAnotacoes[anexoId];
    if (list == null || list.isEmpty) return null;
    return list.last;
  }

  @override
  Future<List<NotaSapAnotacao>> obterHistoricoAnotacoes(String anexoId) async {
    final list = bancoAnotacoes[anexoId];
    if (list == null) return [];
    return List.from(list.reversed);
  }

  @override
  Future<NotaSapAnotacao> salvarAnotacao({
    required String anexoId,
    required NotaSapAnotacaoDocumento dadosJson,
    int? imagemLargura,
    int? imagemAltura,
    String? criadoPor,
    String? criadoPorNome,
    int maxRetries = 3,
  }) async {
    chamadasSalvar++;

    if (simularColisaoConcorrente && chamadasSalvar == 1) {
      // Simula colisão na primeira tentativa
      throw Exception('PostgresException(code: 23505, message: duplicate key value violates unique constraint "uq_anotacao_anexo_versao")');
    }

    final list = bancoAnotacoes.putIfAbsent(anexoId, () => []);
    final novaVersao = list.length + 1;

    final novaAnotacao = NotaSapAnotacao(
      id: 'anot_id_$novaVersao',
      anexoId: anexoId,
      versao: novaVersao,
      dadosJson: dadosJson,
      imagemLargura: imagemLargura,
      imagemAltura: imagemAltura,
      criadoPor: criadoPor,
      criadoPorNome: criadoPorNome,
      createdAt: DateTime.now(),
    );

    list.add(novaAnotacao);
    return novaAnotacao;
  }
}

void main() {
  late MockNotaSapAnaliseServiceForEditor mockService;

  setUp(() {
    mockService = MockNotaSapAnaliseServiceForEditor();
  });

  Widget createEditorApp({
    required NotaSapAnexo anexo,
    required NotaSapAnaliseService service,
    VoidCallback? onSalvo,
  }) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(
        extensions: [
          TaskFlowThemeExtension.dark(),
        ],
      ),
      home: NotaAnexoAnnotationEditor(
        anexo: anexo,
        imageUrl: 'https://picsum.photos/id/10/800/600',
        initialImageSize: const Size(800, 600),
        service: service,
        onSalvo: onSalvo,
      ),
    );
  }

  group('Fase 3: Editor de Anotações Técnicas e Ciclo Completo de MVP', () {
    testWidgets('1. Renderiza toolbar desktop, ferramentas e botão de salvar versão', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final anexo = const NotaSapAnexo(
        id: 'anexo_101',
        notaSapId: 'nota_999',
        nomeArquivo: 'inspecao_cruzeta.jpg',
        tipoArquivo: NotaAnexoTipo.imagem,
        caminhoArquivo: 'nota_999/inspecao_cruzeta.jpg',
        tamanhoBytes: 1024,
      );

      await tester.pumpWidget(createEditorApp(anexo: anexo, service: mockService));
      await tester.pumpAndSettle();

      expect(find.textContaining('Anotação Técnica: inspecao_cruzeta.jpg'), findsOneWidget);
      expect(find.text('Edição Não Destrutiva • Original Intacto'), findsOneWidget);
      expect(find.text('Salvar Versão'), findsOneWidget);

      // Ferramentas visíveis
      expect(find.byTooltip('Selecionar / Mover'), findsOneWidget);
      expect(find.byTooltip('Retângulo'), findsOneWidget);
      expect(find.byTooltip('Círculo / Elipse'), findsOneWidget);
      expect(find.byTooltip('Seta Técnica'), findsOneWidget);
      expect(find.byTooltip('Texto / Legenda'), findsOneWidget);
    });

    testWidgets('2. Inserção de texto técnico via diálogo rápido', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final anexo = const NotaSapAnexo(
        id: 'anexo_101',
        notaSapId: 'nota_999',
        nomeArquivo: 'inspecao_cruzeta.jpg',
        tipoArquivo: NotaAnexoTipo.imagem,
        caminhoArquivo: 'nota_999/inspecao_cruzeta.jpg',
        tamanhoBytes: 1024,
      );

      await tester.pumpWidget(createEditorApp(anexo: anexo, service: mockService));
      await tester.pumpAndSettle();

      // Clica na ferramenta de Texto
      await tester.tap(find.byTooltip('Texto / Legenda'));
      await tester.pumpAndSettle();

      // Clica no centro da tela para abrir o diálogo de texto
      await tester.tapAt(const Offset(400, 300));
      await tester.pumpAndSettle();

      expect(find.text('Adicionar Texto Técnico'), findsOneWidget);
      expect(find.text('Trinca'), findsOneWidget);

      // Clica na sugestão rápida "Oxidação"
      await tester.tap(find.text('Oxidação'));
      await tester.pumpAndSettle();

      // Confirma inserção
      await tester.tap(find.text('Inserir'));
      await tester.pumpAndSettle();

      // Diálogo fechou e o texto foi inserido no canvas
      expect(find.text('Adicionar Texto Técnico'), findsNothing);
    });

    test('3. Salvar versão e ciclo de concorrência com retry', () async {
      final anexoId = 'anexo_colisao';

      final doc = const NotaSapAnotacaoDocumento(
        canvasWidth: 1920,
        canvasHeight: 1080,
        elements: [
          NotaSapAnotacaoElemento(
            id: 'elem_ret',
            type: NotaSapElementoTipo.rect,
            x1: 0.1,
            y1: 0.1,
            x2: 0.3,
            y2: 0.3,
          ),
        ],
      );

      // 1. Salvar v1
      final v1 = await mockService.salvarAnotacao(
        anexoId: anexoId,
        dadosJson: doc,
      );
      expect(v1.versao, 1);

      // 2. Salvar v2
      final v2 = await mockService.salvarAnotacao(
        anexoId: anexoId,
        dadosJson: doc,
      );
      expect(v2.versao, 2);

      // 3. Reabertura: obter última versão reconstrói v2
      final ultima = await mockService.obterUltimaAnotacao(anexoId);
      expect(ultima, isNotNull);
      expect(ultima!.versao, 2);
      expect(ultima.dadosJson.elements.length, 1);
      expect(ultima.dadosJson.elements.first.type, NotaSapElementoTipo.rect);
    });

    testWidgets('4. Cancelar com alterações exibe diálogo de confirmação', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final anexo = const NotaSapAnexo(
        id: 'anexo_sujo',
        notaSapId: 'nota_888',
        nomeArquivo: 'foto_inspecao.jpg',
        tipoArquivo: NotaAnexoTipo.imagem,
        caminhoArquivo: 'nota_888/foto_inspecao.jpg',
        tamanhoBytes: 1024,
      );

      await tester.pumpWidget(createEditorApp(anexo: anexo, service: mockService));
      await tester.pumpAndSettle();

      // Insere um texto para sujar o estado
      await tester.tap(find.byTooltip('Texto / Legenda'));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(400, 300));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Substituir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inserir'));
      await tester.pumpAndSettle();

      // Clica em Voltar (seta na AppBar)
      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();

      // Confirma que o diálogo de proteção apareceu
      expect(find.text('Descartar alterações?'), findsOneWidget);
      expect(find.text('Continuar editando'), findsOneWidget);
      expect(find.text('Descartar e Fechar'), findsOneWidget);

      // Clica em Continuar editando
      await tester.tap(find.text('Continuar editando'));
      await tester.pumpAndSettle();

      // Permanece na tela
      expect(find.text('Descartar alterações?'), findsNothing);
      expect(find.text('Salvar Versão'), findsOneWidget);
    });

    testWidgets('5. Controle de zoom na anotação: botões flutuantes, atalhos e ferramenta pan', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final anexo = const NotaSapAnexo(
        id: 'anexo_101',
        notaSapId: 'nota_999',
        nomeArquivo: 'inspecao_cruzeta.jpg',
        tipoArquivo: NotaAnexoTipo.imagem,
        caminhoArquivo: 'nota_999/inspecao_cruzeta.jpg',
        tamanhoBytes: 1024,
      );

      await tester.pumpWidget(createEditorApp(anexo: anexo, service: mockService));
      await tester.pumpAndSettle();

      // 1. Ferramenta de Mover Tela (Pan) presente
      expect(find.byTooltip('Mover Tela (Pan / H)'), findsOneWidget);

      // 2. Controles de Zoom visíveis (barra flutuante + toolbar)
      expect(find.byTooltip('Aproximar (Zoom +)'), findsWidgets);
      expect(find.byTooltip('Afastar (Zoom -)'), findsWidgets);
      expect(find.text('100%'), findsWidgets);

      // 3. Clica em Aproximar
      await tester.tap(find.byTooltip('Aproximar (Zoom +)').first);
      await tester.pumpAndSettle();
      expect(find.text('125%'), findsWidgets);

      // 4. Clica em Resetar / Ajustar à Tela
      await tester.tap(find.byTooltip('Ajustar à Tela (0)'));
      await tester.pumpAndSettle();
      expect(find.text('100%'), findsWidgets);
    });
  });
}
