import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/models/nota_sap.dart';
import 'package:task2026/models/nota_sap_analise.dart';
import 'package:task2026/models/nota_sap_grupo.dart';
import 'package:task2026/models/nota_sap_similaridade.dart';
import 'package:task2026/models/task.dart';
import 'package:task2026/widgets/task_form/notas_grupo_programacao_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Helper para criar NotaSAP simulada
  NotaSAP criarNotaMock({
    required String id,
    required String numero,
    String? descricao,
    String? local,
    String? equipamento,
    String? statusSistema,
  }) {
    return NotaSAP(
      id: id,
      nota: numero,
      descricao: descricao ?? 'Descrição Nota $numero',
      localInstalacao: local ?? 'SE-ABC-01',
      equipamento: equipamento ?? 'DJ-01',
      statusSistema: statusSistema ?? 'MSPR ORDA',
    );
  }

  // Helper para criar NotaSapGrupoItem
  NotaSapGrupoItem criarItemMock({
    required String id,
    required String grupoId,
    required NotaSAP nota,
    List<TarefaHistoricaResumo> tarefas = const [],
  }) {
    return NotaSapGrupoItem(
      id: id,
      grupoId: grupoId,
      notaSapId: nota.id,
      nota: nota,
      tarefasVinculadas: tarefas,
    );
  }

  group('NotasGrupoProgramacaoPanel — Testes de Apresentação e Ergonomia', () {
    testWidgets('1. Renderiza cabeçalho com nome, previsão definida e motivo', (tester) async {
      final notaA = criarNotaMock(id: 'nota-1', numero: '11599101');
      final grupo = NotaSapGrupo(
        id: 'grupo-1',
        nome: 'Intervenção DJ 12T2',
        motivo: 'Aguardar desligamento do barramento',
        mesProgramacaoPrevisto: 11,
        anoProgramacaoPrevisto: 2026,
      );

      final itemA = criarItemMock(id: 'item-1', grupoId: grupo.id, nota: notaA);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotasGrupoProgramacaoPanel(
              notaOrigem: notaA,
              grupo: grupo,
              itens: [itemA],
              selectedNotaIds: {'nota-1'},
              onSelectionChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('GRUPO DE NOTAS VINCULADAS'), findsOneWidget);
      expect(find.text('Intervenção DJ 12T2'), findsOneWidget);
      expect(find.text('Novembro/2026'), findsOneWidget);
      expect(find.text('Aguardar desligamento do barramento'), findsOneWidget);
      expect(find.text('#11599101'), findsOneWidget);
      expect(find.text('Nota principal'), findsOneWidget);
    });

    testWidgets('2. Renderiza previsão "Não definida" quando grupo não possui previsão macro', (tester) async {
      final notaA = criarNotaMock(id: 'nota-1', numero: '11599101');
      final grupo = const NotaSapGrupo(
        id: 'grupo-1',
        nome: 'Manutenção Preventiva Geral',
        // Sem previsão
      );

      final itemA = criarItemMock(id: 'item-1', grupoId: grupo.id, nota: notaA);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotasGrupoProgramacaoPanel(
              notaOrigem: notaA,
              grupo: grupo,
              itens: [itemA],
              selectedNotaIds: {'nota-1'},
              onSelectionChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Não definida'), findsOneWidget);
    });

    testWidgets('3. Exibe aviso contextual sutil se a data da tarefa estiver fora do mês previsto', (tester) async {
      final notaA = criarNotaMock(id: 'nota-1', numero: '11599101');
      final grupo = NotaSapGrupo(
        id: 'grupo-1',
        nome: 'Intervenção DJ 12T2',
        mesProgramacaoPrevisto: 11,
        anoProgramacaoPrevisto: 2026,
      );

      final itemA = criarItemMock(id: 'item-1', grupoId: grupo.id, nota: notaA);

      // Data da tarefa programada para Dezembro/2026 (fora de Novembro)
      final dataTarefa = DateTime(2026, 12, 10);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotasGrupoProgramacaoPanel(
              notaOrigem: notaA,
              grupo: grupo,
              itens: [itemA],
              selectedNotaIds: {'nota-1'},
              onSelectionChanged: (_) {},
              dataProgramadaTarefa: dataTarefa,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('A data programada (Dez/2026) está fora do mês inicialmente previsto para o grupo (Novembro/2026).'),
        findsOneWidget,
      );
    });

    testWidgets('4. Grupo com 4 notas: exibe situações corretas de programação', (tester) async {
      final notaA = criarNotaMock(id: 'nota-1', numero: '11599101', descricao: 'Baixa pressão SF6');
      final notaB = criarNotaMock(id: 'nota-2', numero: '11565867', descricao: 'Baixa pressão SF6 adicional');
      final notaC = criarNotaMock(id: 'nota-3', numero: '11344587', descricao: 'Ressuprimento de gás SF6');
      final notaD = criarNotaMock(id: 'nota-4', numero: '11500001', descricao: 'Falha auxiliar');

      final grupo = NotaSapGrupo(
        id: 'grupo-1',
        nome: 'Intervenção DJ 12T2',
        mesProgramacaoPrevisto: 11,
        anoProgramacaoPrevisto: 2026,
      );

      final itens = [
        criarItemMock(id: 'i-1', grupoId: grupo.id, nota: notaA),
        criarItemMock(id: 'i-2', grupoId: grupo.id, nota: notaB),
        criarItemMock(id: 'i-3', grupoId: grupo.id, nota: notaC),
        criarItemMock(
          id: 'i-4',
          grupoId: grupo.id,
          nota: notaD,
          tarefas: const [TarefaHistoricaResumo(id: '842', tarefaNome: 'Revisão Disjuntor')],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: NotasGrupoProgramacaoPanel(
                notaOrigem: notaA,
                grupo: grupo,
                itens: itens,
                selectedNotaIds: {'nota-1'},
                onSelectionChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Notas A, B, C estão não programadas
      expect(find.text('Ainda não programada'), findsNWidgets(3));
      // Nota D já está programada na Tarefa #842
      expect(find.textContaining('Já programada na Tarefa #842'), findsOneWidget);
      // Destaque de notas pendentes no grupo
      expect(find.text('Há outras 3 Notas ainda não programadas neste grupo.'), findsOneWidget);
    });

    testWidgets('5. Ação [Selecionar todas as não programadas] adiciona notas livres', (tester) async {
      final notaA = criarNotaMock(id: 'nota-1', numero: '11599101');
      final notaB = criarNotaMock(id: 'nota-2', numero: '11565867');
      final notaC = criarNotaMock(id: 'nota-3', numero: '11344587');
      final notaD = criarNotaMock(id: 'nota-4', numero: '11500001');

      final grupo = const NotaSapGrupo(id: 'grupo-1', nome: 'Grupo Teste');

      final itens = [
        criarItemMock(id: 'i-1', grupoId: grupo.id, nota: notaA),
        criarItemMock(id: 'i-2', grupoId: grupo.id, nota: notaB),
        criarItemMock(id: 'i-3', grupoId: grupo.id, nota: notaC),
        criarItemMock(
          id: 'i-4',
          grupoId: grupo.id,
          nota: notaD,
          tarefas: const [TarefaHistoricaResumo(id: '842')],
        ),
      ];

      Set<String> selecaoAtual = {'nota-1'};

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SingleChildScrollView(
                  child: NotasGrupoProgramacaoPanel(
                    notaOrigem: notaA,
                    grupo: grupo,
                    itens: itens,
                    selectedNotaIds: selecaoAtual,
                    onSelectionChanged: (nova) {
                      setState(() {
                        selecaoAtual = nova;
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Clicar no botão "Selecionar todas as não programadas"
      final btnTodas = find.text('Selecionar todas as não programadas');
      expect(btnTodas, findsOneWidget);
      await tester.tap(btnTodas);
      await tester.pumpAndSettle();

      // Agora notas 1, 2 e 3 devem estar selecionadas, mas nota 4 (já programada) NÃO
      expect(selecaoAtual.contains('nota-1'), isTrue);
      expect(selecaoAtual.contains('nota-2'), isTrue);
      expect(selecaoAtual.contains('nota-3'), isTrue);
      expect(selecaoAtual.contains('nota-4'), isFalse);
    });

    testWidgets('6. Ação [Limpar seleção adicional] preserva a nota principal', (tester) async {
      final notaA = criarNotaMock(id: 'nota-1', numero: '11599101');
      final notaB = criarNotaMock(id: 'nota-2', numero: '11565867');

      final grupo = const NotaSapGrupo(id: 'grupo-1', nome: 'Grupo Teste');
      final itens = [
        criarItemMock(id: 'i-1', grupoId: grupo.id, nota: notaA),
        criarItemMock(id: 'i-2', grupoId: grupo.id, nota: notaB),
      ];

      Set<String> selecaoAtual = {'nota-1', 'nota-2'};

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return NotasGrupoProgramacaoPanel(
                  notaOrigem: notaA,
                  grupo: grupo,
                  itens: itens,
                  selectedNotaIds: selecaoAtual,
                  onSelectionChanged: (nova) {
                    setState(() {
                      selecaoAtual = nova;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final btnLimpar = find.text('Limpar seleção adicional');
      expect(btnLimpar, findsOneWidget);
      await tester.tap(btnLimpar);
      await tester.pumpAndSettle();

      // Apenas a nota principal permanece
      expect(selecaoAtual, equals({'nota-1'}));
    });

    testWidgets('7. Tentativa de selecionar nota já programada abre confirmação e cancelamento não seleciona', (tester) async {
      final notaA = criarNotaMock(id: 'nota-1', numero: '11599101');
      final notaProg = criarNotaMock(id: 'nota-prog', numero: '11500001');

      final grupo = const NotaSapGrupo(id: 'grupo-1', nome: 'Grupo Teste');
      final itens = [
        criarItemMock(id: 'i-1', grupoId: grupo.id, nota: notaA),
        criarItemMock(
          id: 'i-2',
          grupoId: grupo.id,
          nota: notaProg,
          tarefas: const [TarefaHistoricaResumo(id: '842')],
        ),
      ];

      Set<String> selecaoAtual = {'nota-1'};

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return NotasGrupoProgramacaoPanel(
                  notaOrigem: notaA,
                  grupo: grupo,
                  itens: itens,
                  selectedNotaIds: selecaoAtual,
                  onSelectionChanged: (nova) {
                    setState(() {
                      selecaoAtual = nova;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Clicar no item da nota já programada
      final itemNotaProg = find.text('#11500001');
      await tester.tap(itemNotaProg);
      await tester.pumpAndSettle();

      // Deve exibir diálogo de confirmação
      expect(find.text('Nota Já Programada'), findsOneWidget);
      expect(find.textContaining('já está vinculada à(s) Tarefa(s) #842'), findsOneWidget);

      // Clicar em Cancelar
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      // Nota NÃO foi selecionada
      expect(selecaoAtual.contains('nota-prog'), isFalse);
    });

    testWidgets('8. Confirmação explícita aceita inclui nota já programada (relação N:M)', (tester) async {
      final notaA = criarNotaMock(id: 'nota-1', numero: '11599101');
      final notaProg = criarNotaMock(id: 'nota-prog', numero: '11500001');

      final grupo = const NotaSapGrupo(id: 'grupo-1', nome: 'Grupo Teste');
      final itens = [
        criarItemMock(id: 'i-1', grupoId: grupo.id, nota: notaA),
        criarItemMock(
          id: 'i-2',
          grupoId: grupo.id,
          nota: notaProg,
          tarefas: const [TarefaHistoricaResumo(id: '842')],
        ),
      ];

      Set<String> selecaoAtual = {'nota-1'};

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return NotasGrupoProgramacaoPanel(
                  notaOrigem: notaA,
                  grupo: grupo,
                  itens: itens,
                  selectedNotaIds: selecaoAtual,
                  onSelectionChanged: (nova) {
                    setState(() {
                      selecaoAtual = nova;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Clicar no item da nota já programada
      await tester.tap(find.text('#11500001'));
      await tester.pumpAndSettle();

      // Confirmar inclusão mesmo assim
      await tester.tap(find.text('Incluir mesmo assim'));
      await tester.pumpAndSettle();

      // Nota FOI selecionada com sucesso
      expect(selecaoAtual.contains('nota-prog'), isTrue);
    });

    testWidgets('9. Exibe badges de análise técnica para notas com status distintos', (tester) async {
      final notaA = criarNotaMock(id: 'nota-1', numero: '11599101');
      final notaB = criarNotaMock(id: 'nota-2', numero: '11565867');
      final notaC = criarNotaMock(id: 'nota-3', numero: '11344587');

      final grupo = const NotaSapGrupo(id: 'grupo-1', nome: 'Grupo Teste');
      final itens = [
        criarItemMock(id: 'i-1', grupoId: grupo.id, nota: notaA),
        criarItemMock(id: 'i-2', grupoId: grupo.id, nota: notaB),
        criarItemMock(id: 'i-3', grupoId: grupo.id, nota: notaC),
      ];

      final analises = {
        'nota-1': const NotaSapAnalise(
          notaSapId: 'nota-1',
          statusAnalise: NotaAnaliseStatus.concluida,
        ),
        'nota-2': const NotaSapAnalise(
          notaSapId: 'nota-2',
          statusAnalise: NotaAnaliseStatus.emAnalise,
        ),
        // nota-3 sem análise
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotasGrupoProgramacaoPanel(
              notaOrigem: notaA,
              grupo: grupo,
              itens: itens,
              analises: analises,
              selectedNotaIds: {'nota-1'},
              onSelectionChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Análise concluída'), findsOneWidget);
      expect(find.text('Em análise'), findsOneWidget);
      expect(find.text('Sem análise'), findsOneWidget);
    });

    testWidgets('10. Grupo totalmente programado exibe mensagem informativa sem bloquear', (tester) async {
      final notaA = criarNotaMock(id: 'nota-1', numero: '11599101');
      final notaB = criarNotaMock(id: 'nota-2', numero: '11565867');

      final grupo = const NotaSapGrupo(id: 'grupo-1', nome: 'Grupo Teste');
      final itens = [
        criarItemMock(
          id: 'i-1',
          grupoId: grupo.id,
          nota: notaA,
          tarefas: const [TarefaHistoricaResumo(id: '100')],
        ),
        criarItemMock(
          id: 'i-2',
          grupoId: grupo.id,
          nota: notaB,
          tarefas: const [TarefaHistoricaResumo(id: '200')],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotasGrupoProgramacaoPanel(
              notaOrigem: notaA,
              grupo: grupo,
              itens: itens,
              selectedNotaIds: {'nota-1'},
              onSelectionChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Todas as Notas deste grupo já possuem programação.'), findsOneWidget);
    });

    testWidgets('12. Mudança de data da tarefa apenas atualiza aviso contextual e preserva seleção', (tester) async {
      final notaA = criarNotaMock(id: 'nota-1', numero: '11599101');
      final notaB = criarNotaMock(id: 'nota-2', numero: '11565867');
      final grupo = NotaSapGrupo(id: 'g-1', nome: 'Grupo Teste', mesProgramacaoPrevisto: 11, anoProgramacaoPrevisto: 2026);
      final itens = [
        criarItemMock(id: 'item-1', grupoId: 'g-1', nota: notaA),
        criarItemMock(id: 'item-2', grupoId: 'g-1', nota: notaB),
      ];

      var selecaoAtual = {'nota-1', 'nota-2'};
      var dataTarefa = DateTime(2026, 11, 15); // Dentro da previsão

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    ElevatedButton(
                      key: const Key('btn-mudar-data'),
                      onPressed: () {
                        setState(() {
                          dataTarefa = DateTime(2026, 12, 10); // Fora da previsão
                        });
                      },
                      child: const Text('Mudar Data'),
                    ),
                    NotasGrupoProgramacaoPanel(
                      notaOrigem: notaA,
                      grupo: grupo,
                      itens: itens,
                      selectedNotaIds: selecaoAtual,
                      onSelectionChanged: (nova) => selecaoAtual = nova,
                      dataProgramadaTarefa: dataTarefa,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Inicialmente dentro do mês: sem aviso divergente
      expect(find.textContaining('fora do mês inicialmente previsto'), findsNothing);
      expect(selecaoAtual, equals({'nota-1', 'nota-2'}));

      // Clicar para mudar a data para Dezembro
      await tester.tap(find.byKey(const Key('btn-mudar-data')));
      await tester.pumpAndSettle();

      // Agora deve exibir o aviso contextual
      expect(find.textContaining('fora do mês inicialmente previsto'), findsOneWidget);
      // E a seleção de notas permanece exatamente a mesma
      expect(selecaoAtual, equals({'nota-1', 'nota-2'}));
    });

    testWidgets('13. Rebuild do widget preserva seleções efetuadas', (tester) async {
      final notaA = criarNotaMock(id: 'nota-1', numero: '11599101');
      final notaB = criarNotaMock(id: 'nota-2', numero: '11565867');
      final grupo = NotaSapGrupo(id: 'g-1', nome: 'Grupo Teste', mesProgramacaoPrevisto: 11, anoProgramacaoPrevisto: 2026);
      final itens = [
        criarItemMock(id: 'item-1', grupoId: 'g-1', nota: notaA),
        criarItemMock(id: 'item-2', grupoId: 'g-1', nota: notaB),
      ];

      final selecao = {'nota-1', 'nota-2'};

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotasGrupoProgramacaoPanel(
              notaOrigem: notaA,
              grupo: grupo,
              itens: itens,
              selectedNotaIds: selecao,
              onSelectionChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 Nota principal + 1 adicional(is)'), findsOneWidget);

      // Forçar rebuild
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotasGrupoProgramacaoPanel(
              notaOrigem: notaA,
              grupo: grupo,
              itens: itens,
              selectedNotaIds: selecao,
              onSelectionChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 Nota principal + 1 adicional(is)'), findsOneWidget);
    });

    testWidgets('14. Edição de tarefa sem nota de origem única (isEdicao = true e notaOrigem = null)', (tester) async {
      final notaA = criarNotaMock(id: 'nota-1', numero: '11599101');
      final notaB = criarNotaMock(id: 'nota-2', numero: '11565867');
      final grupo = NotaSapGrupo(id: 'g-1', nome: 'Grupo Teste', mesProgramacaoPrevisto: 11, anoProgramacaoPrevisto: 2026);
      final itens = [
        criarItemMock(id: 'item-1', grupoId: 'g-1', nota: notaA),
        criarItemMock(id: 'item-2', grupoId: 'g-1', nota: notaB),
      ];

      Set<String> selecaoNotificada = {};

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotasGrupoProgramacaoPanel(
              notaOrigem: null, // Na edição de tarefa pode não haver nota única de origem
              grupo: grupo,
              itens: itens,
              selectedNotaIds: {'nota-1'},
              onSelectionChanged: (nova) => selecaoNotificada = nova,
              isEdicao: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Deve mostrar 1 de 2 Notas selecionadas
      expect(find.text('1 de 2 Notas selecionadas'), findsOneWidget);

      // Clicar em nota-2
      await tester.tap(find.text('#11565867'));
      await tester.pumpAndSettle();

      expect(selecaoNotificada, contains('nota-2'));
    });
  });

  group('Model Task & Propagação de Seleção', () {
    test('11. Task suporta notaSapIdsParaVincular e preserva valores no copyWith', () {
      final task = Task(
        id: 'task-1',
        status: 'PROG',
        regional: 'Norte',
        divisao: 'Transmissão',
        tipo: 'CORRETIVA',
        tarefa: 'Intervenção DJ 12T2',
        coordenador: 'João Coordenador',
        dataInicio: DateTime(2026, 11, 1),
        dataFim: DateTime(2026, 11, 2),
        notaSapIdsParaVincular: ['nota-A', 'nota-B', 'nota-C'],
      );

      expect(task.notaSapIdsParaVincular, equals(['nota-A', 'nota-B', 'nota-C']));

      final copy = task.copyWith(
        tarefa: 'Tarefa Atualizada',
        notaSapIdsParaVincular: ['nota-A'],
      );

      expect(copy.tarefa, equals('Tarefa Atualizada'));
      expect(copy.notaSapIdsParaVincular, equals(['nota-A']));
    });
  });
}
