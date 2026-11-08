import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/models/nota_sap.dart';
import 'package:task2026/models/nota_sap_analise.dart';
import 'package:task2026/models/task.dart';
import 'package:task2026/services/nota_sap_analise_service.dart';
import 'package:task2026/widgets/notas_sap_vinculadas_dialog.dart';

class MockNotaSapAnaliseServiceForDialog extends Fake implements NotaSapAnaliseService {
  final Map<String, List<NotaSapAnexo>> anexosMock = {};

  @override
  Future<Map<String, List<NotaSapAnexo>>> listarAnexosPorNotas(List<String> notaSapIds) async {
    final map = <String, List<NotaSapAnexo>>{};
    for (final id in notaSapIds) {
      if (anexosMock.containsKey(id)) {
        map[id] = anexosMock[id]!;
      }
    }
    return map;
  }

  @override
  Future<String> obterUrlAssinada(
    NotaSapAnexo anexo, {
    Duration expires = const Duration(minutes: 60),
  }) async {
    return 'https://via.placeholder.com/150';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockTask = Task(
    id: 'task-100',
    tarefa: '123456',
    tipo: 'MANUTENCAO',
    regional: 'NORTE',
    divisao: 'DIV_01',
    coordenador: 'Coordenador 1',
    dataInicio: DateTime(2026, 11, 10, 8),
    dataFim: DateTime(2026, 11, 10, 17),
    status: 'PROG',
    observacoes: 'Manutenção Preventiva de Disjuntor',
  );

  final mockNota = NotaSAP(
    id: 'nota-001',
    nota: '11009988',
    tipo: 'PM',
    descricao: 'Revisão técnica de chave seccionadora',
    statusSistema: 'MSPR',
    statusUsuario: 'ANLS',
    equipamento: 'DJ-01',
    sala: 'SALA-02',
    dataVencimento: DateTime(2026, 11, 20),
    diasRestantes: 12,
  );

  final mockAnexo1 = const NotaSapAnexo(
    id: 'anexo-01',
    notaSapId: 'nota-001',
    nomeArquivo: 'foto_chave_avariada.jpg',
    caminhoArquivo: 'notas/nota-001/foto_chave_avariada.jpg',
    tipoArquivo: NotaAnexoTipo.imagem,
    mimeType: 'image/jpeg',
    tamanhoBytes: 102400,
    legenda: 'Fissura visível no contato',
  );

  final mockAnexo2 = const NotaSapAnexo(
    id: 'anexo-02',
    notaSapId: 'nota-001',
    nomeArquivo: 'laudo_tecnico.pdf',
    caminhoArquivo: 'notas/nota-001/laudo_tecnico.pdf',
    tipoArquivo: NotaAnexoTipo.pdf,
    mimeType: 'application/pdf',
    tamanhoBytes: 204800,
    legenda: 'Laudo termográfico preliminar',
  );

  testWidgets('NotasSapVinculadasDialog exibe cabeçalho, botão de Análise Técnica e miniaturas de anexos', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final mockService = MockNotaSapAnaliseServiceForDialog();
    mockService.anexosMock['nota-001'] = [mockAnexo1, mockAnexo2];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotasSapVinculadasDialog(
            notas: [mockNota],
            task: mockTask,
            analiseService: mockService,
          ),
        ),
      ),
    );

    // Aguarda carregar os anexos
    await tester.pumpAndSettle();

    // 1. Cabeçalho
    expect(find.text('Notas SAP Vinculadas'), findsOneWidget);
    expect(find.textContaining('Tarefa: 123456'), findsOneWidget);

    // 2. Dados da Nota
    expect(find.text('Nota 11009988'), findsOneWidget);
    expect(find.text('Revisão técnica de chave seccionadora'), findsOneWidget);
    expect(find.text('DJ-01'), findsOneWidget);
    expect(find.text('Sala: SALA-02'), findsOneWidget);

    // 3. Botão destacado para o Formulário de Análise Técnica
    expect(find.text('Análise Técnica'), findsOneWidget);
    expect(find.byIcon(Icons.analytics_outlined), findsOneWidget);

    // 4. Seção de Anexos com Miniaturas
    expect(find.text('Anexos / Evidências (2)'), findsOneWidget);
    expect(find.text('• Clique na miniatura para ampliar'), findsOneWidget);

    // Miniatura PDF deve exibir ícone de PDF e nome
    expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
    expect(find.text('laudo_tecnico.pdf'), findsOneWidget);
  });

  testWidgets('NotasSapVinculadasDialog exibe mensagem amigável quando nota não possui anexos', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final mockService = MockNotaSapAnaliseServiceForDialog(); // sem anexos

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotasSapVinculadasDialog(
            notas: [mockNota],
            task: mockTask,
            analiseService: mockService,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Deve exibir texto amigável e link para adicionar anexo na análise
    expect(find.text('Nenhum anexo registrado nesta Nota SAP.'), findsOneWidget);
    expect(find.text('Adicionar Anexo na Análise'), findsOneWidget);
  });
}
