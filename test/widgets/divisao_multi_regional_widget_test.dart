import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task2026/config/supabase_config.dart';
import 'package:task2026/design_system/taskflow_design_system.dart';
import 'package:task2026/models/divisao.dart';
import 'package:task2026/widgets/divisao_form_dialog.dart';
import 'package:task2026/widgets/divisao_list_view.dart';

Widget _createTestApp(Widget child, {ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? TaskFlowTheme.light(),
    home: Scaffold(
      body: child,
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

  group('Divisao Multi-Regional — Widget & Filter Tests', () {
    testWidgets('DivisaoFormDialog renderiza campos de multi-seleção de regionais e validação', (tester) async {
      await tester.pumpWidget(_createTestApp(
        const DivisaoFormDialog(),
      ));
      await tester.pump();

      expect(find.text('Nova Divisão'), findsOneWidget);
      expect(find.text('Regionais de Atuação *'), findsOneWidget);
      expect(find.text('Segmentos *'), findsOneWidget);

      // Tenta salvar sem preencher nada
      final salvarBtn = find.text('Criar Divisão');
      expect(salvarBtn, findsOneWidget);
      await tester.tap(salvarBtn);
      await tester.pump();

      // Validação de campo obrigatório
      expect(find.text('Campo obrigatório'), findsOneWidget);
    });

    testWidgets('DivisaoFormDialog em modo edição renderiza título de edição e botões', (tester) async {
      final divisaoExistente = Divisao(
        id: 'div-edit',
        divisao: 'NEPTMC',
        regionalIds: ['reg-1', 'reg-2'],
        regionais: ['Pernambuco', 'Bahia'],
        segmentoIds: ['seg-1'],
        segmentos: ['Manutenção Civil'],
      );

      await tester.pumpWidget(_createTestApp(
        DivisaoFormDialog(divisao: divisaoExistente),
      ));
      await tester.pump();

      expect(find.text('Editar Divisão'), findsOneWidget);
      expect(find.text('Salvar Alterações'), findsOneWidget);
      expect(find.text('NEPTMC'), findsOneWidget);
    });

    testWidgets('DivisaoListView renderiza cabeçalho TFDS e campo de busca', (tester) async {
      await tester.pumpWidget(_createTestApp(
        const DivisaoListView(),
      ));
      await tester.pump();

      expect(find.text('Cadastro de Divisões'), findsOneWidget);
      expect(find.text('Nova Divisão'), findsOneWidget);
      expect(find.byType(TFTextField), findsOneWidget);
    });

    test('Filtro em cascata: Divisão NEPTMC aparece nas regionais em que atua e oculta nas demais', () {
      final divisao = Divisao(
        id: 'div-neptmc',
        divisao: 'NEPTMC',
        regionalIds: ['reg-pe', 'reg-ba', 'reg-ce'],
        regionais: ['Pernambuco', 'Bahia', 'Ceará'],
      );

      final todasDivisoes = [divisao];

      // Quando seleciona Pernambuco: NEPTMC visível
      final divisoesPE = todasDivisoes.where((d) => d.atuaNaRegional('reg-pe')).toList();
      expect(divisoesPE.length, 1);
      expect(divisoesPE.first.divisao, 'NEPTMC');

      // Quando seleciona Bahia: NEPTMC visível
      final divisoesBA = todasDivisoes.where((d) => d.atuaNaRegional('reg-ba')).toList();
      expect(divisoesBA.length, 1);
      expect(divisoesBA.first.divisao, 'NEPTMC');

      // Quando seleciona Ceará: NEPTMC visível
      final divisoesCE = todasDivisoes.where((d) => d.atuaNaRegional('reg-ce')).toList();
      expect(divisoesCE.length, 1);
      expect(divisoesCE.first.divisao, 'NEPTMC');

      // Quando seleciona Maranhão: NEPTMC oculto
      final divisoesMA = todasDivisoes.where((d) => d.atuaNaRegional('reg-ma')).toList();
      expect(divisoesMA.length, 0);

      // Quando id é nulo: retorna false
      expect(divisao.atuaNaRegional(null), isFalse);
    });
  });
}
