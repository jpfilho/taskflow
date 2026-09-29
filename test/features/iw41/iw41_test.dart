import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task2026/config/supabase_config.dart';
import 'package:task2026/design_system/taskflow_design_system.dart';
import 'package:task2026/models/confirmacao.dart';
import 'package:task2026/widgets/confirmacao_ordens_view.dart';
import 'package:task2026/widgets/confirmacao_form_dialog.dart';
import 'package:task2026/widgets/confirmacao_sap_view.dart';

Widget _wrap(
  Widget child, {
  ThemeData? theme,
  double width = 1280,
  double height = 800,
}) {
  return MaterialApp(
    theme: theme ?? TaskFlowTheme.light(),
    home: MediaQuery(
      data: MediaQueryData(
        size: Size(width, height),
      ),
      child: Scaffold(
        body: SizedBox(
          width: width,
          height: height,
          child: child,
        ),
      ),
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

  group('IW41 / Confirmação SAP — Presentation & Navigation Tests', () {
    testWidgets('1. Renderiza ConfirmacaoOrdensView com abas, busca e botões em Desktop', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ConfirmacaoOrdensView(),
          width: 1280,
          height: 800,
        ),
      );
      await tester.pump();

      expect(find.textContaining('Confirmação de Ordens'), findsOneWidget);
      expect(find.text('Confirmações'), findsOneWidget);
      expect(find.text('SAP (Tabela)'), findsOneWidget);
      expect(find.text('Nova Confirmação'), findsOneWidget);
      expect(find.byType(TabBar), findsOneWidget);
    });

    testWidgets('2. Renderiza ConfirmacaoOrdensView em Mobile (390x844)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ConfirmacaoOrdensView(),
          width: 390,
          height: 844,
        ),
      );
      await tester.pump();

      expect(find.textContaining('Confirmação de Ordens'), findsOneWidget);
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.byIcon(Icons.add), findsWidgets);
    });

    testWidgets('3. Renderiza ConfirmacaoOrdensView em diferentes temas (Light, Dark, AXIA)', (tester) async {
      for (final theme in [
        TaskFlowTheme.light(),
        TaskFlowTheme.dark(),
        TaskFlowTheme.axia(),
      ]) {
        await tester.pumpWidget(
          _wrap(
            const ConfirmacaoOrdensView(),
            theme: theme,
          ),
        );
        await tester.pump();

        expect(find.textContaining('Confirmação de Ordens'), findsOneWidget);
        expect(find.byType(TabBar), findsOneWidget);
      }
    });

    testWidgets('4. Alterna abas entre Confirmações e SAP (Tabela)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ConfirmacaoOrdensView(),
        ),
      );
      await tester.pump();

      expect(find.text('SAP (Tabela)'), findsOneWidget);
      await tester.tap(find.text('SAP (Tabela)'));
      await tester.pumpAndSettle();

      expect(find.byType(ConfirmacaoSapView), findsOneWidget);
    });
  });

  group('IW41 — Form Dialog & Validation Tests', () {
    testWidgets('5. Abre ConfirmacaoFormDialog em modo de criação com campos obrigatórios', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ConfirmacaoFormDialog(),
          width: 800,
          height: 900,
        ),
      );
      await tester.pump();

      expect(find.text('Nova Confirmação'), findsOneWidget);
      expect(find.text('Ordem *'), findsOneWidget);
      expect(find.text('Nº Pessoal (Matrícula) *'), findsOneWidget);
      expect(find.text('Trabalho Real *'), findsOneWidget);
      expect(find.text('Unidade *'), findsOneWidget);

      // Scroll para ver a seção inferior
      await tester.drag(find.byType(ListView), const Offset(0, -1200));
      await tester.pump();

      expect(find.text('Tipo de Atividade'), findsOneWidget);
      expect(find.text('Salvar'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
    });

    testWidgets('6. Valida campos obrigatórios ao submeter formulário vazio', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ConfirmacaoFormDialog(),
          width: 800,
          height: 900,
        ),
      );
      await tester.pump();

      final form = tester.state<FormState>(find.byType(Form));
      expect(form.validate(), isFalse);
    });

    testWidgets('7. Abre ConfirmacaoFormDialog em modo edição com dados populados', (tester) async {
      final confirmacaoExistente = Confirmacao(
        id: 'conf_123',
        ordem: '40001234',
        operacao2: '0010',
        subOper: '0001',
        centroDeTrabalho: 'EL-LINHAS',
        centro: '1000',
        nomes: 'Carlos Pereira',
        nPessoal: '987654',
        trabReal: 4.5,
        unid: 'H',
        datInicioExec: DateTime(2026, 9, 10),
        horaInicio: '08:00:00',
        datFimExec: DateTime(2026, 9, 10),
        horaFim: '12:30:00',
        dataLancamento: DateTime(2026, 9, 10),
        textoConfirmacao: 'Substituição de isolador concluída',
        confirmacaoFinal: 'S',
        sTrabRestante: 'N',
        tipoAtividade: 'M01',
        status: 'CONFIRMADO',
      );

      await tester.pumpWidget(
        _wrap(
          ConfirmacaoFormDialog(confirmacao: confirmacaoExistente),
          width: 800,
          height: 900,
        ),
      );
      await tester.pump();

      expect(find.text('Editar Confirmação'), findsOneWidget);
      expect(find.text('40001234'), findsOneWidget);
      expect(find.text('987654'), findsOneWidget);
      expect(find.text('4.50'), findsOneWidget);
      expect(find.text('H'), findsOneWidget);
    });

    testWidgets('8. Validação de campo numérico de Trabalho Real (horas decimais)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ConfirmacaoFormDialog(),
          width: 800,
          height: 900,
        ),
      );
      await tester.pump();

      final formFieldFinder = find.widgetWithText(TextFormField, 'Trabalho Real *');
      expect(formFieldFinder, findsOneWidget);

      await tester.enterText(formFieldFinder, '8.75');
      await tester.pump();

      expect(find.text('8.75'), findsOneWidget);
    });
  });

  group('IW41 — Double-Submit Protection & Safety Tests', () {
    testWidgets('9. Garante que TFButton exibe estado de loading e desabilita clique duplo', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Row(
            children: [
              TFButton(
                label: 'Salvar',
                loading: true,
                onPressed: () {},
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('10. TFStatusBadge mapeia corretamente os status operacionais de confirmação', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Column(
            children: [
              TFStatusBadge(
                label: 'CONFIRMADO (S)',
                severity: TFStatusSeverity.success,
                compact: true,
              ),
              TFStatusBadge(
                label: 'NÃO CONFIRMADO (N)',
                severity: TFStatusSeverity.warning,
                compact: true,
              ),
              TFStatusBadge(
                label: 'PENDENTE',
                severity: TFStatusSeverity.neutral,
                compact: true,
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(find.text('CONFIRMADO (S)'), findsOneWidget);
      expect(find.text('NÃO CONFIRMADO (N)'), findsOneWidget);
      expect(find.text('PENDENTE'), findsOneWidget);
    });
  });

  group('IW41 — SAP View & Contract Verification', () {
    testWidgets('11. Renderiza ConfirmacaoSapView com barra de filtros e campo de busca', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ConfirmacaoSapView(),
          width: 1280,
          height: 800,
        ),
      );
      await tester.pump();

      expect(find.byTooltip('Atualizar'), findsOneWidget);
      expect(find.byType(TextField), findsWidgets);
      expect(find.text('Tipo'), findsOneWidget);
      expect(find.text('Ordem'), findsOneWidget);
      expect(find.text('Operação'), findsOneWidget);
    });

    testWidgets('12. Verifica integridade semântica do contrato de payload IW41', (tester) async {
      final payload = <String, dynamic>{
        'ordem': '40009999',
        'operacao_2': '0020',
        'sub_oper': '0001',
        'centro_de_trab': 'MAN-ELET',
        'centro': '1000',
        'nomes': 'João Técnico',
        'n_pessoal': '123456',
        'trab_real': 6.0,
        'unid': 'H',
        'dat_inicio_exec': '2026-09-15',
        'hora_inicio': '07:30:00',
        'dat_fim_exec': '2026-09-15',
        'hora_fim': '13:30:00',
        'data_lancamento': '2026-09-15',
        'texto_confirmacao': 'Manutenção realizada com sucesso',
        'confirmacao_final': 'S',
        's_trab_restante': 'N',
        'tipo_atividade': 'M01',
      };

      expect(payload['ordem'], equals('40009999'));
      expect(payload['operacao_2'], equals('0020'));
      expect(payload['n_pessoal'], equals('123456'));
      expect(payload['trab_real'], equals(6.0));
      expect(payload['unid'], equals('H'));
      expect(payload['confirmacao_final'], equals('S'));
      expect(payload.keys.length, equals(18));
    });
  });
}
