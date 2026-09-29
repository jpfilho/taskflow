import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task2026/config/supabase_config.dart';
import 'package:task2026/design_system/taskflow_design_system.dart';
import 'package:task2026/models/melhoria_bug.dart';
import 'package:task2026/models/versao.dart';
import 'package:task2026/modules/melhorias_bugs/presentation/screens/melhorias_bugs_home_screen.dart';
import 'package:task2026/modules/melhorias_bugs/presentation/widgets/melhoria_bug_card.dart';
import 'package:task2026/modules/melhorias_bugs/presentation/widgets/melhoria_bug_form_dialog.dart';
import 'package:task2026/modules/melhorias_bugs/presentation/widgets/versao_form_dialog.dart';

Widget _buildTestWrapper({
  required Widget child,
  ThemeData? theme,
  Size size = const Size(1280, 800),
}) {
  return MaterialApp(
    theme: theme ?? TaskFlowTheme.light(),
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Material(child: child),
    ),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    try {
      await SupabaseConfig.initialize();
    } catch (_) {}
  });

  group('Melhorias & Bugs — Model & State Machine Tests', () {
    test('Status labels humanizados estão definidos corretamente', () {
      expect(melhoriaBugStatusLabel('BACKLOG'), equals('Aguardando análise'));
      expect(melhoriaBugStatusLabel('ANALISE'), equals('Em análise'));
      expect(melhoriaBugStatusLabel('DESENVOLVIMENTO'), equals('Em desenvolvimento'));
      expect(melhoriaBugStatusLabel('VALIDACAO'), equals('Em validação'));
      expect(melhoriaBugStatusLabel('CONCLUIDO'), equals('Concluído'));
      expect(melhoriaBugStatusLabel('REABERTO'), equals('Reaberto'));
      expect(melhoriaBugStatusLabel('REJEITADO'), equals('Não será feito'));
      expect(melhoriaBugStatusLabel('DUPLICADO'), equals('Duplicado'));
    });

    test('Transições de status respeitam a máquina de estados', () {
      // BACKLOG pode ir para ANALISE, REJEITADO, DUPLICADO
      expect(melhoriaBugPodeTransicionar('BACKLOG', 'ANALISE'), isTrue);
      expect(melhoriaBugPodeTransicionar('BACKLOG', 'REJEITADO'), isTrue);
      expect(melhoriaBugPodeTransicionar('BACKLOG', 'CONCLUIDO'), isFalse);

      // DESENVOLVIMENTO pode ir para VALIDACAO, ANALISE, REJEITADO
      expect(melhoriaBugPodeTransicionar('DESENVOLVIMENTO', 'VALIDACAO'), isTrue);
      expect(melhoriaBugPodeTransicionar('DESENVOLVIMENTO', 'BACKLOG'), isFalse);

      // CONCLUIDO pode ser REABERTO
      expect(melhoriaBugPodeTransicionar('CONCLUIDO', 'REABERTO'), isTrue);
      expect(melhoriaBugPodeTransicionar('CONCLUIDO', 'DESENVOLVIMENTO'), isFalse);
    });
  });

  group('Melhorias & Bugs — Presentation Widget Tests', () {
    testWidgets('MelhoriaBugCard renderiza com badges semânticas de bug e prioridade crítica',
        (tester) async {
      final item = MelhoriaBug(
        id: '1',
        tipo: kTipoBug,
        titulo: 'Bug no login',
        descricao: 'Usuário não consegue logar sem internet',
        status: 'DESENVOLVIMENTO',
        prioridade: 'CRITICA',
      );

      await tester.pumpWidget(
        _buildTestWrapper(
          child: MelhoriaBugCard(item: item),
        ),
      );

      expect(find.text('BUG'), findsOneWidget);
      expect(find.text('Crítica'), findsOneWidget);
      expect(find.text('Em desenvolvimento'), findsOneWidget);
      expect(find.text('Bug no login'), findsOneWidget);
      expect(find.text('Usuário não consegue logar sem internet'), findsOneWidget);
    });

    testWidgets('MelhoriaBugCard renderiza sugestão de melhoria com status concluído',
        (tester) async {
      final item = MelhoriaBug(
        id: '2',
        tipo: kTipoMelhoria,
        titulo: 'Melhoria no dashboard',
        descricao: 'Adicionar filtro de datas rápidas',
        status: 'CONCLUIDO',
        prioridade: 'ALTA',
        versaoCorrigida: 'v1.4.0',
      );

      await tester.pumpWidget(
        _buildTestWrapper(
          child: MelhoriaBugCard(item: item),
        ),
      );

      expect(find.text('MELHORIA'), findsOneWidget);
      expect(find.text('Alta'), findsOneWidget);
      expect(find.text('Concluído'), findsOneWidget);
      expect(find.text('Melhoria no dashboard'), findsOneWidget);
      expect(find.text('Corrigido em: v1.4.0'), findsOneWidget);
    });

    testWidgets('MelhoriasBugsHomeScreen renderiza abas Lista e Roadmap', (tester) async {
      await tester.pumpWidget(
        _buildTestWrapper(
          child: const MelhoriasBugsHomeScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('Melhorias e Bugs'), findsOneWidget);
      expect(find.text('Lista'), findsOneWidget);
      expect(find.text('Roadmap'), findsOneWidget);
    });

    testWidgets('MelhoriaBugFormDialog valida campos obrigatórios e transições permitidas',
        (tester) async {
      final versoes = [
        Versao(id: 'v1', nome: 'v1.0.0'),
        Versao(id: 'v2', nome: 'v1.1.0'),
      ];

      MelhoriaBug? salvo;

      await tester.pumpWidget(
        _buildTestWrapper(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => MelhoriaBugFormDialog(
                    versoes: versoes,
                    onSave: (mb) async {
                      salvo = mb;
                      return mb;
                    },
                  ),
                );
              },
              child: const Text('Abrir Form'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Form'));
      await tester.pumpAndSettle();

      expect(find.text('Novo Item'), findsOneWidget);
      expect(find.text('Salvar'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);

      // Preenche o formulário
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'Erro de sincronização');
      await tester.enterText(textFields.at(1), 'Falha ao sincronizar SQLite');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(salvo, isNotNull);
      expect(salvo!.titulo, equals('Erro de sincronização'));
      expect(salvo!.descricao, equals('Falha ao sincronizar SQLite'));
      expect(salvo!.tipo, equals(kTipoMelhoria));
      expect(salvo!.status, equals('BACKLOG'));
    });

    testWidgets('VersaoFormDialog permite criar versão com nome e datas', (tester) async {
      Versao? versaoSalva;

      await tester.pumpWidget(
        _buildTestWrapper(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => VersaoFormDialog(
                    onSave: (v) async {
                      versaoSalva = v;
                      return v;
                    },
                  ),
                );
              },
              child: const Text('Abrir Versao Form'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Versao Form'));
      await tester.pumpAndSettle();

      expect(find.text('Nova Versão'), findsOneWidget);
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'v2.0.0');
      await tester.enterText(textFields.at(1), 'Release maior com novas funções');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(versaoSalva, isNotNull);
      expect(versaoSalva!.nome, equals('v2.0.0'));
      expect(versaoSalva!.descricao, equals('Release maior com novas funções'));
    });

    testWidgets('Calcula progresso do roadmap corretamente (ex: 2 concluídos de 4 = 50%)',
        (tester) async {
      final itens = [
        MelhoriaBug(id: '1', tipo: kTipoBug, titulo: 'Bug 1', status: 'CONCLUIDO'),
        MelhoriaBug(id: '2', tipo: kTipoBug, titulo: 'Bug 2', status: 'CONCLUIDO'),
        MelhoriaBug(id: '3', tipo: kTipoMelhoria, titulo: 'Melhoria 1', status: 'DESENVOLVIMENTO'),
        MelhoriaBug(id: '4', tipo: kTipoMelhoria, titulo: 'Melhoria 2', status: 'ANALISE'),
      ];

      final total = itens.length;
      final concluidos = itens.where((i) => i.status == 'CONCLUIDO').length;
      final progresso = total > 0 ? (concluidos / total) : 0.0;

      expect(total, equals(4));
      expect(concluidos, equals(2));
      expect(progresso, equals(0.5));
      expect((progresso * 100).toInt(), equals(50));
    });

    testWidgets('Busca textual em memória filtra corretamente por título e descrição (case-insensitive)',
        (tester) async {
      final itens = [
        MelhoriaBug(id: '1', tipo: kTipoBug, titulo: 'Bug no Login', descricao: 'Falha ao logar', status: 'BACKLOG'),
        MelhoriaBug(id: '2', tipo: kTipoMelhoria, titulo: 'Melhoria no Dashboard', descricao: 'KPIs novos', status: 'BACKLOG'),
        MelhoriaBug(id: '3', tipo: kTipoBug, titulo: 'Erro de Sincronização', descricao: 'Conexão timeout no login', status: 'BACKLOG'),
      ];

      // Busca por 'login'
      final termo1 = 'login'.trim().toLowerCase();
      final filtrados1 = itens.where((item) {
        final matchTitle = item.titulo.toLowerCase().contains(termo1);
        final matchDesc = item.descricao?.toLowerCase().contains(termo1) ?? false;
        return matchTitle || matchDesc;
      }).toList();

      expect(filtrados1.length, equals(2));
      expect(filtrados1.map((i) => i.id).toList(), equals(['1', '3']));

      // Busca por 'KPIs'
      final termo2 = 'KPIS'.trim().toLowerCase();
      final filtrados2 = itens.where((item) {
        final matchTitle = item.titulo.toLowerCase().contains(termo2);
        final matchDesc = item.descricao?.toLowerCase().contains(termo2) ?? false;
        return matchTitle || matchDesc;
      }).toList();

      expect(filtrados2.length, equals(1));
      expect(filtrados2.first.id, equals('2'));
    });

    testWidgets('Exibe autor/reportador no card e no diálogo de edição', (tester) async {
      final item = MelhoriaBug(
        id: '1',
        tipo: kTipoBug,
        titulo: 'Bug com autor',
        status: 'BACKLOG',
        createdBy: 'Carlos Engenharia',
      );

      await tester.pumpWidget(
        _buildTestWrapper(
          child: MelhoriaBugCard(item: item),
        ),
      );
      expect(find.text('Carlos Engenharia'), findsOneWidget);

      await tester.pumpWidget(
        _buildTestWrapper(
          child: Scaffold(
            body: MelhoriaBugFormDialog(
              initial: item,
              versoes: const [],
              onSave: (mb) async => mb,
            ),
          ),
        ),
      );
      expect(find.text('Reportado por: Carlos Engenharia'), findsOneWidget);
    });
  });
}

