import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task2026/config/supabase_config.dart';
import 'package:task2026/design_system/taskflow_design_system.dart';
import 'package:task2026/models/funcao.dart';
import 'package:task2026/models/status.dart';
import 'package:task2026/models/centro_trabalho.dart';
import 'package:task2026/models/segmento.dart';
import 'package:task2026/models/equipe.dart';
import 'package:task2026/widgets/funcao_form_dialog.dart';
import 'package:task2026/widgets/status_form_dialog.dart';
import 'package:task2026/widgets/centro_trabalho_form_dialog.dart';
import 'package:task2026/widgets/segmento_form_dialog.dart';
import 'package:task2026/widgets/equipe_form_dialog.dart';

Widget createTestableFormApp({ThemeData? theme, required Widget child}) {
  return MaterialApp(
    theme: theme ?? TaskFlowTheme.light(),
    home: Scaffold(body: child),
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

  group('Wave 1 Forms — FuncaoFormDialog', () {
    testWidgets('FuncaoFormDialog renderiza em modo criação', (tester) async {
      await tester.pumpWidget(createTestableFormApp(child: const FuncaoFormDialog()));
      await tester.pump();

      expect(find.text('Nova Função'), findsOneWidget);
      expect(find.text('Criar Função'), findsOneWidget);
      expect(find.text('Nome da Função'), findsOneWidget);
      expect(find.text('Descrição'), findsOneWidget);
      expect(find.text('Ativo'), findsOneWidget);
    });

    testWidgets('FuncaoFormDialog renderiza em modo edição com valores iniciais', (tester) async {
      final funcao = Funcao(
        id: 'f-1',
        funcao: 'Eletricista',
        descricao: 'Manutenção de rede',
        ativo: true,
      );

      await tester.pumpWidget(createTestableFormApp(child: FuncaoFormDialog(funcao: funcao)));
      await tester.pump();

      expect(find.text('Editar Função'), findsOneWidget);
      expect(find.text('Salvar Alterações'), findsOneWidget);
      expect(find.text('Eletricista'), findsOneWidget);
      expect(find.text('Manutenção de rede'), findsOneWidget);
    });

    testWidgets('FuncaoFormDialog valida campos obrigatórios', (tester) async {
      await tester.pumpWidget(createTestableFormApp(child: const FuncaoFormDialog()));
      await tester.pump();

      await tester.tap(find.text('Criar Função'));
      await tester.pumpAndSettle();

      expect(find.text('Campo obrigatório'), findsOneWidget);
    });
  });

  group('Wave 1 Forms — StatusFormDialog', () {
    testWidgets('StatusFormDialog renderiza em modo criação', (tester) async {
      await tester.pumpWidget(createTestableFormApp(child: const StatusFormDialog()));
      await tester.pump();

      expect(find.text('Novo Status'), findsOneWidget);
      expect(find.text('Criar Status'), findsOneWidget);
      expect(find.text('Código do Status'), findsOneWidget);
      expect(find.text('Status'), findsOneWidget);
      expect(find.text('Cor Principal do Status *'), findsOneWidget);
    });

    testWidgets('StatusFormDialog renderiza em modo edição', (tester) async {
      final status = Status(
        id: 's-1',
        codigo: 'EXEC',
        status: 'Em Execução',
        cor: '#2196F3',
      );

      await tester.pumpWidget(createTestableFormApp(child: StatusFormDialog(status: status)));
      await tester.pump();

      expect(find.text('Editar Status'), findsOneWidget);
      expect(find.text('Salvar Alterações'), findsOneWidget);
      expect(find.text('EXEC'), findsOneWidget);
      expect(find.text('Em Execução'), findsOneWidget);
    });

    testWidgets('StatusFormDialog valida campos obrigatórios', (tester) async {
      await tester.pumpWidget(createTestableFormApp(child: const StatusFormDialog()));
      await tester.pump();

      await tester.tap(find.text('Criar Status'));
      await tester.pumpAndSettle();

      expect(find.text('Campo obrigatório'), findsAtLeastNWidgets(1));
    });
  });

  group('Wave 1 Forms — CentroTrabalhoFormDialog', () {
    testWidgets('CentroTrabalhoFormDialog renderiza estrutura base', (tester) async {
      await tester.pumpWidget(createTestableFormApp(child: const CentroTrabalhoFormDialog()));
      await tester.pump();

      expect(find.text('Novo Centro de Trabalho'), findsOneWidget);
      expect(find.text('Criar Centro de Trabalho'), findsOneWidget);
    });

    testWidgets('CentroTrabalhoFormDialog renderiza em modo edição', (tester) async {
      final ct = CentroTrabalho(
        id: 'ct-1',
        centroTrabalho: 'CT-NORTE',
        descricao: 'Centro Operacional Norte',
        regionalId: 'reg-1',
        divisaoId: 'div-1',
        segmentoId: 'seg-1',
        ativo: true,
      );

      await tester.pumpWidget(createTestableFormApp(child: CentroTrabalhoFormDialog(centroTrabalho: ct)));
      await tester.pump();

      expect(find.text('Editar Centro de Trabalho'), findsOneWidget);
      expect(find.text('Salvar Alterações'), findsOneWidget);
    });
  });

  group('Wave 1 Forms — SegmentoFormDialog', () {
    testWidgets('SegmentoFormDialog renderiza em modo criação', (tester) async {
      await tester.pumpWidget(createTestableFormApp(child: const SegmentoFormDialog()));
      await tester.pump();

      expect(find.text('Novo Segmento'), findsOneWidget);
      expect(find.text('Criar Segmento'), findsOneWidget);
      expect(find.text('Segmento'), findsOneWidget);
      expect(find.text('Descrição'), findsOneWidget);
      expect(find.text('Cor de Fundo do Segmento'), findsOneWidget);
      expect(find.text('Cor do Texto do Segmento'), findsOneWidget);
    });

    testWidgets('SegmentoFormDialog renderiza em modo edição com dados', (tester) async {
      final segmento = Segmento(
        id: 'seg-1',
        segmento: 'Distribuição',
        descricao: 'Rede de baixa e média tensão',
        cor: '#FF9800',
        corTexto: '#FFFFFF',
      );

      await tester.pumpWidget(createTestableFormApp(child: SegmentoFormDialog(segmento: segmento)));
      await tester.pump();

      expect(find.text('Editar Segmento'), findsOneWidget);
      expect(find.text('Salvar Alterações'), findsOneWidget);
      expect(find.text('Distribuição'), findsOneWidget);
      expect(find.text('Rede de baixa e média tensão'), findsOneWidget);
    });

    testWidgets('SegmentoFormDialog valida campo obrigatório', (tester) async {
      await tester.pumpWidget(createTestableFormApp(child: const SegmentoFormDialog()));
      await tester.pump();

      await tester.tap(find.text('Criar Segmento'));
      await tester.pumpAndSettle();

      expect(find.text('Campo obrigatório'), findsOneWidget);
    });
  });

  group('Wave 1 Forms — EquipeFormDialog', () {
    testWidgets('EquipeFormDialog renderiza em modo criação', (tester) async {
      await tester.pumpWidget(createTestableFormApp(child: const EquipeFormDialog()));
      await tester.pump();

      expect(find.text('Nova Equipe'), findsOneWidget);
      expect(find.text('Criar Equipe'), findsOneWidget);
      expect(find.text('Nome da Equipe'), findsOneWidget);
      expect(find.text('Descrição'), findsOneWidget);
      expect(find.text('Tipo'), findsOneWidget);
      expect(find.text('Adicionar Executor'), findsOneWidget);
      expect(find.text('Ativo'), findsOneWidget);
    });

    testWidgets('EquipeFormDialog renderiza em modo edição', (tester) async {
      final equipe = Equipe(
        id: 'eq-1',
        nome: 'Equipe Alpha',
        descricao: 'Equipe linha viva',
        tipo: 'FIXA',
        ativo: true,
      );

      await tester.pumpWidget(createTestableFormApp(child: EquipeFormDialog(equipe: equipe)));
      await tester.pump();

      expect(find.text('Editar Equipe'), findsOneWidget);
      expect(find.text('Salvar Alterações'), findsOneWidget);
      expect(find.text('Equipe Alpha'), findsOneWidget);
      expect(find.text('Equipe linha viva'), findsOneWidget);
    });

    testWidgets('EquipeFormDialog valida campo obrigatório', (tester) async {
      await tester.pumpWidget(createTestableFormApp(child: const EquipeFormDialog()));
      await tester.pump();

      await tester.tap(find.text('Criar Equipe'));
      await tester.pumpAndSettle();

      expect(find.text('Campo obrigatório'), findsOneWidget);
    });
  });
}
