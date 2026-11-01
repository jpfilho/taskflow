import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/models/nota_sap.dart';
import 'package:task2026/models/nota_sap_tag.dart';
import 'package:task2026/services/usuario_service.dart';
import 'package:task2026/widgets/nota_workspace/nota_tag_selector_dialog.dart';
import 'package:task2026/widgets/nota_workspace/nota_workspace_overview_tab.dart';
import 'package:task2026/design_system/theme/taskflow_theme.dart';

Widget _wrapWithTheme(Widget child) {
  return MaterialApp(
    theme: TaskFlowTheme.light(),
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final fakeNota = NotaSAP(
    id: 'nota_test_001',
    nota: '1000987654',
    tipo: 'PD',
    descricao: 'Vegetação alta próxima aos condutores LT',
    local: 'SE TERESINA I',
    localInstalacao: 'PI-THE-01',
  );

  final tagVeg = NotaSapTag(
    id: 'tag_veg',
    nome: 'Vegetação',
    categoria: 'Técnica',
    cor: '#43A047',
    escopoTipo: NotaSapTagEscopo.segmento,
    segmentoId: 'seg_lt',
    ativo: true,
  );

  testWidgets('W1. NotaWorkspaceOverviewTab renderiza seção de tags e chips vinculados', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _wrapWithTheme(
        NotaWorkspaceOverviewTab(
          nota: fakeNota,
        ),
      ),
    );
    await tester.pump();

    // Deve exibir o card de Tags da Nota
    expect(find.text('Tags da Nota'), findsOneWidget);
    expect(find.text('Adicionar Tag'), findsOneWidget);
  });

  testWidgets('W2. Formatação visual de chips compactos (até 3 tags + badge +N com tooltip)', (tester) async {
    final tags = [
      NotaSapTag(id: '1', nome: 'Tag1', cor: '#1E88E5'),
      NotaSapTag(id: '2', nome: 'Tag2', cor: '#43A047'),
      NotaSapTag(id: '3', nome: 'Tag3', cor: '#FB8C00'),
      NotaSapTag(id: '4', nome: 'Tag4', cor: '#E53935'),
      NotaSapTag(id: '5', nome: 'Tag5', cor: '#8E24AA'),
    ];

    // Simula a construção de chips compactos com limite 3
    final visiveis = tags.take(3).toList();
    final restantes = tags.skip(3).toList();

    await tester.pumpWidget(
      _wrapWithTheme(
        Row(
          children: [
            ...visiveis.map((t) => Chip(label: Text(t.nome))),
            if (restantes.isNotEmpty)
              Tooltip(
                message: restantes.map((t) => t.nome).join(', '),
                child: Text('+${restantes.length}'),
              ),
          ],
        ),
      ),
    );
    await tester.pump();

    // 3 primeiras visíveis
    expect(find.text('Tag1'), findsOneWidget);
    expect(find.text('Tag2'), findsOneWidget);
    expect(find.text('Tag3'), findsOneWidget);
    // As excedentes não são renderizadas como chips individuais
    expect(find.text('Tag4'), findsNothing);
    expect(find.text('Tag5'), findsNothing);
    // Badge +2 exibido
    expect(find.text('+2'), findsOneWidget);

    // Tooltip exibe Tag4, Tag5
    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
    expect(tooltip.message, 'Tag4, Tag5');
  });

  testWidgets('W3. NotaSapTagSelectorDialog renderiza campo de busca e botão cancelar', (tester) async {
    await tester.pumpWidget(
      _wrapWithTheme(
        NotaSapTagSelectorDialog(
          notaSapId: fakeNota.id,
          tagsAtuaisDaNota: [tagVeg],
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Adicionar Tag à Nota'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
  });

  testWidgets('W4. NotaSapTagSelectorDialog exibe botão Nova Tag e alterna para criação inline', (tester) async {
    await tester.pumpWidget(
      _wrapWithTheme(
        NotaSapTagSelectorDialog(
          notaSapId: fakeNota.id,
          tagsAtuaisDaNota: const [],
        ),
      ),
    );
    await tester.pump();

    // Botão "Nova Tag" visível no topo
    final btnNovaTag = find.text('Nova Tag');
    expect(btnNovaTag, findsOneWidget);

    // Clicar em "Nova Tag" para alternar para criação
    await tester.tap(btnNovaTag);
    await tester.pumpAndSettle();

    // Agora está no modo criação
    expect(find.text('Criar Nova Tag'), findsOneWidget);
    expect(find.text('Nome da Tag *'), findsOneWidget);
    expect(find.text('Cor da Tag'), findsOneWidget);
    expect(find.text('Criar e Vincular'), findsOneWidget);
    expect(find.text('Voltar'), findsOneWidget);

    // Clicar em "Voltar" retorna à listagem
    await tester.tap(find.text('Voltar'));
    await tester.pumpAndSettle();

    expect(find.text('Adicionar Tag à Nota'), findsOneWidget);
  });

  testWidgets('W5. NotaSapTagSelectorDialog com usuário comum inicializa escopo organizacional de segmento', (tester) async {
    final userLT = Usuario(
      email: 'operador.lt@taskflow.com',
      nome: 'Operador LT',
      isRoot: false,
      segmentoIds: ['seg_lt'],
      segmentos: ['Linhas de Transmissão'],
    );

    await tester.pumpWidget(
      _wrapWithTheme(
        NotaSapTagSelectorDialog(
          notaSapId: fakeNota.id,
          tagsAtuaisDaNota: const [],
          usuario: userLT,
        ),
      ),
    );
    await tester.pump();

    // Alternar para criação
    await tester.tap(find.text('Nova Tag'));
    await tester.pumpAndSettle();

    // Deve renderizar opção de segmento no formulário
    expect(find.textContaining('Segmento: Linhas de Transmissão'), findsWidgets);
  });
}
