import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:task2026/design_system/theme/taskflow_theme_extension.dart';
import 'package:task2026/models/nota_sap.dart';
import 'package:task2026/models/nota_sap_analise.dart';
import 'package:task2026/models/nota_sap_analise_evidencia.dart';
import 'package:task2026/services/nota_sap_analise_service.dart';
import 'package:task2026/widgets/nota_analise_workspace.dart';

class FakeRealtimeChannel extends Fake implements RealtimeChannel {
  @override
  Future<String> unsubscribe([Duration? timeout]) async => 'ok';
}

class MockNotaSapAnaliseService extends Fake implements NotaSapAnaliseService {
  MockNotaSapAnaliseService();

  NotaSapAnalise? analiseDb;
  final List<NotaSapMaterial> materiaisDb = [];
  final List<NotaSapAnexo> anexosDb = [];
  final List<NotaSapComentario> comentariosDb = [];

  int buscarAnaliseChamadas = 0;
  int salvarAnaliseChamadas = 0;
  void Function(NotaSapComentario)? realtimeNovoComentarioCb;

  @override
  Future<NotaSapAnalise?> buscarAnalise(String notaSapId) async {
    buscarAnaliseChamadas++;
    return analiseDb;
  }

  @override
  Future<NotaSapAnalise> salvarAnalise(NotaSapAnalise analise) async {
    salvarAnaliseChamadas++;
    analiseDb = analise.copyWith(
      id: (analise.id == null || analise.id!.isEmpty) ? 'analise-1' : analise.id,
    );
    return analiseDb!;
  }

  @override
  Future<List<NotaSapMaterial>> listarMateriais(String notaSapId) async {
    return List.from(materiaisDb);
  }

  @override
  Future<NotaSapMaterial> adicionarMaterial(NotaSapMaterial material) async {
    final novo = NotaSapMaterial(
      id: 'mat-${materiaisDb.length + 1}',
      notaSapId: material.notaSapId,
      analiseId: material.analiseId,
      codigoSap: material.codigoSap,
      descricao: material.descricao,
      quantidade: material.quantidade,
      unidade: material.unidade,
      statusMaterial: material.statusMaterial,
      observacao: material.observacao,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    materiaisDb.add(novo);
    return novo;
  }

  @override
  Future<NotaSapMaterial> atualizarMaterial(NotaSapMaterial material) async {
    final idx = materiaisDb.indexWhere((m) => m.id == material.id);
    if (idx != -1) {
      materiaisDb[idx] = material;
    }
    return material;
  }

  @override
  Future<void> excluirMaterial(String materialId, {String? notaSapId}) async {
    materiaisDb.removeWhere((m) => m.id == materialId);
  }

  @override
  Future<List<NotaSapAnexo>> listarAnexos(String notaSapId) async {
    return List.from(anexosDb);
  }

  @override
  Future<Map<String, List<NotaTipoVinculoEvidencia>>> buscarUsoDosAnexos(
      String notaSapId) async {
    return {};
  }

  @override
  Future<NotaSapAnexo> uploadAnexoFromBytes({
    required String notaSapId,
    required Uint8List bytes,
    required String nomeArquivo,
    String? mimeType,
    String? legenda,
    String? usuarioId,
    String? usuarioNome,
  }) async {
    final anexo = NotaSapAnexo(
      id: 'anexo-${anexosDb.length + 1}',
      notaSapId: notaSapId,
      nomeArquivo: nomeArquivo,
      tipoArquivo: NotaAnexoTipo.documento,
      caminhoArquivo: 'notas_sap/$notaSapId/$nomeArquivo',
      tamanhoBytes: bytes.length,
      mimeType: mimeType ?? 'application/octet-stream',
      legenda: legenda,
      usuarioId: usuarioId,
      usuarioNome: usuarioNome,
      createdAt: DateTime.now(),
    );
    anexosDb.add(anexo);
    return anexo;
  }

  @override
  Future<void> excluirAnexo(NotaSapAnexo anexo) async {
    anexosDb.removeWhere((a) => a.id == anexo.id);
  }

  @override
  Future<List<NotaSapComentario>> listarComentarios(String notaSapId) async {
    return List.from(comentariosDb);
  }

  @override
  Future<NotaSapComentario> adicionarComentario({
    required String notaSapId,
    required String usuarioId,
    String? usuarioNome,
    required String mensagem,
    NotaComentarioTipo tipo = NotaComentarioTipo.texto,
    String? replyToId,
  }) async {
    final c = NotaSapComentario(
      id: 'coment-${comentariosDb.length + 1}',
      notaSapId: notaSapId,
      usuarioId: usuarioId,
      usuarioNome: usuarioNome,
      mensagem: mensagem,
      tipoMensagem: tipo,
      replyToId: replyToId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    comentariosDb.add(c);
    return c;
  }

  @override
  Future<NotaSapComentario> editarComentario(
    String comentarioId,
    String novaMensagem,
  ) async {
    final idx = comentariosDb.indexWhere((c) => c.id == comentarioId);
    if (idx != -1) {
      final editado = comentariosDb[idx].copyWith(
        mensagem: novaMensagem,
        updatedAt: DateTime.now(),
      );
      comentariosDb[idx] = editado;
      return editado;
    }
    throw Exception('Comentário não encontrado');
  }

  @override
  Future<void> excluirComentario(String comentarioId, {String? notaSapId}) async {
    final idx = comentariosDb.indexWhere((c) => c.id == comentarioId);
    if (idx != -1) {
      comentariosDb.removeAt(idx);
    }
  }

  @override
  RealtimeChannel assinarComentarios({
    required String notaSapId,
    required void Function(NotaSapComentario) onNovoComentario,
    void Function(NotaSapComentario)? onAtualizacao,
    void Function(String id)? onExclusao,
  }) {
    realtimeNovoComentarioCb = onNovoComentario;
    return FakeRealtimeChannel();
  }

  @override
  void cancelarAssinaturaComentarios(String notaSapId) {
    realtimeNovoComentarioCb = null;
  }
}

Widget buildTestableWidget({
  required Widget child,
  Size size = const Size(1200, 900),
}) {
  return MaterialApp(
    theme: ThemeData(
      extensions: [TaskFlowThemeExtension.light()],
    ),
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: child,
    ),
  );
}

void main() {
  late MockNotaSapAnaliseService mockService;
  late NotaSAP notaMock;

  setUp(() {
    mockService = MockNotaSapAnaliseService();
    notaMock = NotaSAP(
      id: 'nota-123',
      nota: '20261003',
      descricao: 'Transformador TR-01 com vazamento de óleo',
      tipo: 'NM',
      textPrioridade: 'Alta',
      localInstalacao: 'SE TERESINA I',
      equipamento: 'TR-01',
      statusSistema: 'MSPN ORDA',
      statusUsuario: 'REGI',
    );
  });

  group('Fase 3: Testes de Widgets do Workspace da Nota SAP', () {
    testWidgets('Teste 1: Abrir Workspace com Nota sem análise -> exibe dados, nenhum INSERT',
        (tester) async {
      mockService.analiseDb = null;

      await tester.pumpWidget(buildTestableWidget(
        child: NotaAnaliseWorkspace(
          nota: notaMock,
          service: mockService,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Nota SAP: 20261003'), findsOneWidget);
      expect(find.text('Não iniciada'), findsOneWidget);
      // Exibido no cabeçalho fixo (com prefixo de Local/Sala) e na aba de Visão Geral
      expect(find.textContaining('Transformador TR-01 com vazamento de óleo'), findsNWidgets(2));
      expect(find.textContaining('SE TERESINA I'), findsWidgets);

      expect(mockService.salvarAnaliseChamadas, 0);
      expect(mockService.buscarAnaliseChamadas, 1);
    });

    testWidgets('Teste 2: Salvar primeira análise técnica via botão Salvar Análise',
        (tester) async {
      mockService.analiseDb = null;

      await tester.pumpWidget(buildTestableWidget(
        child: NotaAnaliseWorkspace(
          nota: notaMock,
          service: mockService,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Análise Técnica'));
      await tester.pumpAndSettle();

      final inputs = find.byType(TextFormField);
      await tester.enterText(inputs.first, 'Identificado vazamento na bucha H1');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Salvar Análise'));
      await tester.pumpAndSettle();

      expect(mockService.salvarAnaliseChamadas, 1);
      expect(mockService.analiseDb?.diagnosticoPrevio, 'Identificado vazamento na bucha H1');
      expect(mockService.analiseDb?.statusAnalise, NotaAnaliseStatus.emAnalise);
    });

    testWidgets('Teste 3: Reabrir e carregar análise existente com campos preenchidos',
        (tester) async {
      mockService.analiseDb = NotaSapAnalise(
        id: 'analise-existente',
        notaSapId: 'nota-123',
        numeroNota: '20261003',
        statusAnalise: NotaAnaliseStatus.concluida,
        diagnosticoPrevio: 'Defeito corrigido com sucesso',
        necessitaDesligamento: true,
        estimativaHoras: 4.0,
      );

      await tester.pumpWidget(buildTestableWidget(
        child: NotaAnaliseWorkspace(
          nota: notaMock,
          service: mockService,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Concluída'), findsOneWidget);

      await tester.tap(find.text('Análise Técnica'));
      await tester.pumpAndSettle();

      expect(find.text('Defeito corrigido com sucesso'), findsOneWidget);
    });

    testWidgets('Teste 4: Editar análise existente altera campo e salva',
        (tester) async {
      mockService.analiseDb = NotaSapAnalise(
        id: 'analise-existente',
        notaSapId: 'nota-123',
        numeroNota: '20261003',
        statusAnalise: NotaAnaliseStatus.emAnalise,
        diagnosticoPrevio: 'Texto Antigo',
      );

      await tester.pumpWidget(buildTestableWidget(
        child: NotaAnaliseWorkspace(
          nota: notaMock,
          service: mockService,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Análise Técnica'));
      await tester.pumpAndSettle();

      final input = find.byType(TextFormField).first;
      await tester.enterText(input, 'Texto Atualizado');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Salvar Análise'));
      await tester.pumpAndSettle();

      expect(mockService.salvarAnaliseChamadas, 1);
      expect(mockService.analiseDb?.diagnosticoPrevio, 'Texto Atualizado');
    });

    testWidgets('Teste 5: Adicionar material via diálogo na aba de Materiais',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        child: NotaAnaliseWorkspace(
          nota: notaMock,
          service: mockService,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Materiais'));
      await tester.pumpAndSettle();

      expect(find.text('Nenhum material cadastrado para esta Nota SAP'), findsOneWidget);

      await tester.tap(find.text('Adicionar Material'));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), '104999');
      await tester.enterText(textFields.at(1), 'Junta de Vedação Nitrílica');

      await tester.tap(find.text('Adicionar'));
      await tester.pumpAndSettle();

      expect(mockService.materiaisDb.length, 1);
      expect(mockService.materiaisDb.first.descricao, 'Junta de Vedação Nitrílica');
      expect(find.text('Junta de Vedação Nitrílica'), findsOneWidget);
    });

    testWidgets('Teste 6: Editar material existente',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      mockService.materiaisDb.add(NotaSapMaterial(
        id: 'mat-1',
        notaSapId: 'nota-123',
        descricao: 'Bucha Original',
        quantidade: 1.0,
        unidade: 'UN',
        statusMaterial: NotaMaterialStatus.naoVerificado,
      ));

      await tester.pumpWidget(buildTestableWidget(
        child: NotaAnaliseWorkspace(
          nota: notaMock,
          service: mockService,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Materiais'));
      await tester.pumpAndSettle();

      expect(find.text('Bucha Original'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();

      final descField = find.byType(TextFormField).at(1);
      await tester.enterText(descField, 'Bucha Cerâmica 69kV');

      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(mockService.materiaisDb.first.descricao, 'Bucha Cerâmica 69kV');
    });

    testWidgets('Teste 7: Excluir material com diálogo de confirmação',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      mockService.materiaisDb.add(NotaSapMaterial(
        id: 'mat-1',
        notaSapId: 'nota-123',
        descricao: 'Material a Excluir',
        quantidade: 2.0,
      ));

      await tester.pumpWidget(buildTestableWidget(
        child: NotaAnaliseWorkspace(
          nota: notaMock,
          service: mockService,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Materiais'));
      await tester.pumpAndSettle();

      expect(find.text('Material a Excluir'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();

      expect(find.text('Excluir Material'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Excluir'));
      await tester.pumpAndSettle();

      expect(mockService.materiaisDb.isEmpty, true);
    });

    testWidgets('Teste 8: Adicionar comentário na aba Discussão Técnica',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestableWidget(
        child: NotaAnaliseWorkspace(
          nota: notaMock,
          service: mockService,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Discussão Técnica'));
      await tester.pumpAndSettle();

      expect(find.text('Nenhum comentário registrado ainda'), findsOneWidget);

      final textField = find.byType(TextField);
      await tester.enterText(textField, 'Aterramento da carcaça conferido');
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(mockService.comentariosDb.length, 1);
      expect(mockService.comentariosDb.first.mensagem, 'Aterramento da carcaça conferido');
      expect(find.text('Aterramento da carcaça conferido'), findsOneWidget);
    });

    testWidgets('Teste 9: Receber comentário Realtime na Discussão Técnica',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestableWidget(
        child: NotaAnaliseWorkspace(
          nota: notaMock,
          service: mockService,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Discussão Técnica'));
      await tester.pumpAndSettle();

      expect(mockService.realtimeNovoComentarioCb != null, true);
      mockService.realtimeNovoComentarioCb!(NotaSapComentario(
        id: 'realtime-1',
        notaSapId: 'nota-123',
        usuarioId: 'u-99',
        usuarioNome: 'Engenheiro Campo',
        mensagem: 'Válvula de dreno desobstruída agora.',
      ));
      await tester.pumpAndSettle();

      expect(find.text('Válvula de dreno desobstruída agora.'), findsOneWidget);
      expect(find.text('Engenheiro Campo'), findsOneWidget);
    });

    testWidgets('Teste 10: Listar e exibir anexos na aba Anexos',
        (tester) async {
      mockService.anexosDb.add(NotaSapAnexo(
        id: 'anexo-doc-1',
        notaSapId: 'nota-123',
        nomeArquivo: 'relatorio_inspecao.pdf',
        tipoArquivo: NotaAnexoTipo.documento,
        caminhoArquivo: 'notas_sap/nota-123/relatorio_inspecao.pdf',
        tamanhoBytes: 204800,
      ));

      await tester.pumpWidget(buildTestableWidget(
        child: NotaAnaliseWorkspace(
          nota: notaMock,
          service: mockService,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Anexos'));
      await tester.pumpAndSettle();

      expect(find.text('relatorio_inspecao.pdf'), findsOneWidget);
      expect(find.text('Workspace de Evidências Técnicas'), findsOneWidget);
    });

    testWidgets('Teste 11: Excluir anexo da lista com confirmação',
        (tester) async {
      mockService.anexosDb.add(NotaSapAnexo(
        id: 'anexo-doc-1',
        notaSapId: 'nota-123',
        nomeArquivo: 'arquivo_antigo.pdf',
        tipoArquivo: NotaAnexoTipo.documento,
        caminhoArquivo: 'notas_sap/nota-123/arquivo_antigo.pdf',
        tamanhoBytes: 50000,
      ));

      await tester.pumpWidget(buildTestableWidget(
        child: NotaAnaliseWorkspace(
          nota: notaMock,
          service: mockService,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Anexos'));
      await tester.pumpAndSettle();

      expect(find.text('arquivo_antigo.pdf'), findsOneWidget);

      final btnMore = find.byIcon(Icons.more_vert).first;
      await tester.ensureVisible(btnMore);
      await tester.pumpAndSettle();
      await tester.tap(btnMore);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();

      expect(find.text('Excluir Anexo'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Excluir Permanentemente'));
      await tester.pumpAndSettle();

      expect(mockService.anexosDb.isEmpty, true);
    });

    testWidgets('Teste 12: Fechar com alterações não salvas exibe diálogo de proteção',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        child: NotaAnaliseWorkspace(
          nota: notaMock,
          service: mockService,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Análise Técnica'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'Alteração sem salvar');
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(
          find.text(
              'Existem alterações na análise técnica que não foram salvas. Deseja salvar antes de fechar?'),
          findsOneWidget);
      expect(find.text('Continuar editando'), findsOneWidget);
      expect(find.text('Descartar'), findsOneWidget);
      expect(find.text('Salvar e Fechar'), findsOneWidget);
    });

    testWidgets('Teste 13: Fechar sem alterações não salvas fecha diretamente',
        (tester) async {
      bool fechou = false;

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(extensions: [TaskFlowThemeExtension.light()]),
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              await NotaAnaliseWorkspace.abrir(
                context,
                nota: notaMock,
                service: mockService,
              );
              fechou = true;
            },
            child: const Text('Abrir'),
          ),
        ),
      ));

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      expect(find.text('Nota SAP: 20261003'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(fechou, true);
      expect(find.text('Alterações não salvas'), findsNothing);
    });

    testWidgets('Teste 14: Nota sem análise continua podendo programar tarefa normalmente',
        (tester) async {
      mockService.analiseDb = null;
      bool programacaoDisparada = false;

      await tester.pumpWidget(buildTestableWidget(
        child: NotaAnaliseWorkspace(
          nota: notaMock,
          service: mockService,
          onProgramarTarefa: () {
            programacaoDisparada = true;
          },
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Programar Tarefa'));
      await tester.pumpAndSettle();

      expect(find.text('Programação da Nota SAP'), findsOneWidget);
      expect(find.textContaining('Esta Nota SAP ainda não possui análise técnica prévia'), findsOneWidget);

      await tester.tap(find.text('Criar Nova Tarefa'));
      await tester.pumpAndSettle();

      expect(programacaoDisparada, true);
    });

    testWidgets('Teste 15: Nota com análise parcial programa diretamente sem bloqueio',
        (tester) async {
      mockService.analiseDb = NotaSapAnalise(
        id: 'analise-parcial',
        notaSapId: 'nota-123',
        numeroNota: '20261003',
        statusAnalise: NotaAnaliseStatus.emAnalise,
        diagnosticoPrevio: 'Análise ainda em andamento...',
      );

      bool programacaoDisparada = false;

      await tester.pumpWidget(buildTestableWidget(
        child: NotaAnaliseWorkspace(
          nota: notaMock,
          service: mockService,
          onProgramarTarefa: () {
            programacaoDisparada = true;
          },
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Programar Tarefa'));
      await tester.pumpAndSettle();

      expect(find.text('Programação da Nota SAP'), findsOneWidget);
      await tester.tap(find.text('Criar Nova Tarefa'));
      await tester.pumpAndSettle();

      expect(programacaoDisparada, true);
    });

    testWidgets('Teste 16: Navegação sequencial entre Nota Anterior e Próxima Nota',
        (tester) async {
      final nota1 = notaMock.copyWith(id: 'nota-1', nota: '20261001');
      final nota2 = notaMock.copyWith(id: 'nota-2', nota: '20261002');
      final nota3 = notaMock.copyWith(id: 'nota-3', nota: '20261003');
      final listaNotas = [nota1, nota2, nota3];

      NotaSAP? notaMudouPara;

      await tester.pumpWidget(buildTestableWidget(
        child: NotaAnaliseWorkspace(
          nota: nota1,
          listaNotas: listaNotas,
          service: mockService,
          onNotaMudou: (novaNota) {
            notaMudouPara = novaNota;
          },
        ),
      ));
      await tester.pumpAndSettle();

      // 1. Inicia na primeira nota
      expect(find.text('Nota SAP: 20261001'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text(' / 3'), findsOneWidget);

      // 2. Clica em Próxima
      await tester.tap(find.byTooltip('Próxima Nota (Alt+→)'));
      await tester.pumpAndSettle();

      // Verifica que avançou para a nota 2
      expect(find.text('Nota SAP: 20261002'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text(' / 3'), findsOneWidget);
      expect(notaMudouPara?.id, equals('nota-2'));

      // 3. Clica em Próxima novamente para ir à nota 3
      await tester.tap(find.byTooltip('Próxima Nota (Alt+→)'));
      await tester.pumpAndSettle();

      expect(find.text('Nota SAP: 20261003'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text(' / 3'), findsOneWidget);
      expect(notaMudouPara?.id, equals('nota-3'));

      // 4. Clica em Anterior para voltar para a nota 2
      await tester.tap(find.byTooltip('Nota Anterior (Alt+←)'));
      await tester.pumpAndSettle();

      expect(find.text('Nota SAP: 20261002'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text(' / 3'), findsOneWidget);
      expect(notaMudouPara?.id, equals('nota-2'));
    });

    testWidgets('Teste 17: Sem lista de notas, controles de navegação não são exibidos',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        child: NotaAnaliseWorkspace(
          nota: notaMock,
          service: mockService,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Próxima Nota (Alt+→)'), findsNothing);
      expect(find.byTooltip('Nota Anterior (Alt+←)'), findsNothing);
    });

    testWidgets(
        'Teste 18: Selecionar nota atual alterna entre Selecionar e Selecionada e exibe badge',
        (tester) async {
      Set<String>? notasSelecionadasNotificadas;

      await tester.pumpWidget(buildTestableWidget(
        child: NotaAnaliseWorkspace(
          nota: notaMock,
          service: mockService,
          onNotasSelecionadasMudou: (selecionadas) {
            notasSelecionadasNotificadas = selecionadas;
          },
        ),
      ));
      await tester.pumpAndSettle();

      // Inicialmente não selecionada
      expect(find.text('Selecionar'), findsOneWidget);
      expect(find.text('Selecionada'), findsNothing);
      expect(find.text('Programar Tarefa'), findsOneWidget);

      // Clica em 'Selecionar'
      await tester.tap(find.text('Selecionar'));
      await tester.pumpAndSettle();

      // Agora deve estar selecionada
      expect(find.text('Selecionada'), findsOneWidget);
      expect(find.text('1 selecionada'), findsOneWidget);
      expect(notasSelecionadasNotificadas?.contains(notaMock.id), true);

      // Clica novamente para desmarcar
      await tester.tap(find.text('Selecionada'));
      await tester.pumpAndSettle();

      expect(find.text('Selecionar'), findsOneWidget);
      expect(find.text('1 selecionada'), findsNothing);
      expect(notasSelecionadasNotificadas?.isEmpty, true);
    });

    testWidgets(
        'Teste 19: Selecionar múltiplas notas na navegação atualiza botão para Programar Tarefas (N) e dispara onProgramarMultiplasNotas',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final nota1 = notaMock.copyWith(id: 'nota-1', nota: '20261001');
      final nota2 = notaMock.copyWith(id: 'nota-2', nota: '20261002');
      final listaNotas = [nota1, nota2];

      List<NotaSAP>? notasProgramadasRecebidas;

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(extensions: [TaskFlowThemeExtension.light()]),
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              await NotaAnaliseWorkspace.abrir(
                context,
                nota: nota1,
                listaNotas: listaNotas,
                service: mockService,
                onProgramarMultiplasNotas: (notas) {
                  notasProgramadasRecebidas = notas;
                },
              );
            },
            child: const Text('Abrir'),
          ),
        ),
      ));

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      // Seleciona a nota 1
      await tester.tap(find.text('Selecionar'));
      await tester.pumpAndSettle();
      expect(find.text('1 selecionada'), findsOneWidget);

      // Avança para a nota 2
      await tester.tap(find.byTooltip('Próxima Nota (Alt+→)'));
      await tester.pumpAndSettle();

      // Na nota 2, ela ainda não está selecionada
      expect(find.text('Selecionar'), findsOneWidget);

      // Seleciona a nota 2
      await tester.tap(find.text('Selecionar'));
      await tester.pumpAndSettle();

      // Agora temos 2 selecionadas e o botão exibe 'Programar Tarefas (2)'
      expect(find.text('2 selecionadas'), findsOneWidget);
      expect(find.text('Programar Tarefas (2)'), findsOneWidget);

      // Clica em Programar Tarefas (2)
      await tester.ensureVisible(find.text('Programar Tarefas (2)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Programar Tarefas (2)'));
      await tester.pumpAndSettle();

      // Modal de confirmação para múltiplas notas
      expect(find.text('Programação de 2 Notas SAP'), findsOneWidget);
      expect(
          find.text(
              'Você selecionou 2 notas para programar em conjunto. Como deseja prosseguir?'),
          findsOneWidget);

      // Confirma 'Criar Nova Tarefa (2 notas)'
      await tester.tap(find.text('Criar Nova Tarefa (2 notas)'));
      await tester.pumpAndSettle();

      expect(notasProgramadasRecebidas, isNotNull);
      expect(notasProgramadasRecebidas!.length, 2);
      expect(notasProgramadasRecebidas!.map((n) => n.id),
          containsAll(['nota-1', 'nota-2']));
    });

    testWidgets(
        'Teste 20: Limpar seleção pelo badge de contagem desmarca todas as notas',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        child: NotaAnaliseWorkspace(
          nota: notaMock,
          notasSelecionadasIniciais: {notaMock.id},
          service: mockService,
        ),
      ));
      await tester.pumpAndSettle();

      // Inicialmente já vem selecionada pelo parâmetro inicial
      expect(find.text('Selecionada'), findsOneWidget);
      expect(find.text('1 selecionada'), findsOneWidget);

      // Clica no ícone de fechar (x) do badge
      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pumpAndSettle();

      // Não há mais selecionadas
      expect(find.text('1 selecionada'), findsNothing);
      expect(find.text('Selecionar'), findsOneWidget);
    });

    testWidgets('Teste 21: Tipo de Nota é renderizado antes do nome Nota SAP no cabeçalho',
        (tester) async {
      final notaComTipo = notaMock.copyWith(tipo: 'PM');

      await tester.pumpWidget(buildTestableWidget(
        child: NotaAnaliseWorkspace(
          nota: notaComTipo,
          service: mockService,
        ),
      ));
      await tester.pumpAndSettle();

      // Valida que o tipo PM é exibido junto com Nota SAP (no badge do cabeçalho e na visualização)
      expect(find.text('PM'), findsWidgets);
      expect(find.text('Nota SAP: 20261003'), findsOneWidget);
    });
  });
}
