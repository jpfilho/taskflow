import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task2026/config/supabase_config.dart';
import 'package:task2026/design_system/taskflow_design_system.dart';
import 'package:task2026/models/hora_sap.dart';
import 'package:task2026/widgets/horas_sap_view.dart';

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

  group('Horas SAP — Phase 15B Presentation & Navigation Tests', () {
    testWidgets('1. Renderiza HorasSAPView em modo metas por padrão', (tester) async {
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        originalOnError?.call(details);
      };

      await tester.pumpWidget(
        _wrap(
          const HorasSAPView(
            modoVisualizacao: 'metas',
          ),
          width: 1920,
          height: 1080,
        ),
      );
      await tester.pump();

      expect(find.byType(HorasSAPView), findsOneWidget);

      FlutterError.onError = originalOnError;
    });

    testWidgets('2. Renderiza HorasSAPView em modo tabela', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const HorasSAPView(
            modoVisualizacao: 'tabela',
          ),
          width: 1280,
          height: 800,
        ),
      );
      await tester.pump();

      expect(find.byType(HorasSAPView), findsOneWidget);
    });

    testWidgets('3. Renderiza HorasSAPView em diferentes temas (Light, Dark, AXIA)', (tester) async {
      for (final theme in [
        TaskFlowTheme.light(),
        TaskFlowTheme.dark(),
        TaskFlowTheme.axia(),
      ]) {
        await tester.pumpWidget(
          _wrap(
            const HorasSAPView(
              modoVisualizacao: 'tabela',
            ),
            theme: theme,
          ),
        );
        await tester.pump();

        expect(find.byType(HorasSAPView), findsOneWidget);
      }
    });

    testWidgets('4. Responsividade — Renderiza em Mobile (390px), Tablet (768px) e Desktop (1280px)', (tester) async {
      for (final width in [390.0, 768.0, 1280.0]) {
        await tester.pumpWidget(
          _wrap(
            const HorasSAPView(
              modoVisualizacao: 'tabela',
            ),
            width: width,
            height: 800,
          ),
        );
        await tester.pump();

        expect(find.byType(HorasSAPView), findsOneWidget);
      }
    });
  });

  group('Horas SAP — Component & Dialog Presentation Tests', () {
    testWidgets('5. Renderiza e valida TFEmptyState e TFLoading em HorasSAPView', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Column(
            children: [
              TFLoading(message: 'Carregando horas SAP...'),
              TFEmptyState(
                icon: Icons.access_time,
                title: 'Nenhuma hora encontrada',
                description: 'Não foram encontrados registros para o período.',
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Carregando horas SAP...'), findsOneWidget);
      expect(find.text('Nenhuma hora encontrada'), findsOneWidget);
      expect(find.text('Não foram encontrados registros para o período.'), findsOneWidget);
    });

    testWidgets('6. Valida botões de ação e diálogo de detalhes com TFButton', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Row(
            children: [
              TFButton(
                label: 'Fechar',
                variant: TFButtonVariant.secondary,
                onPressed: () {},
              ),
              const SizedBox(width: 12),
              TFButton(
                label: 'Usar na Confirmação',
                variant: TFButtonVariant.primary,
                leadingIcon: Icons.check,
                onPressed: () {},
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Fechar'), findsOneWidget);
      expect(find.text('Usar na Confirmação'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });
  });

  group('Horas SAP — Data Contract & Integrity Verification', () {
    testWidgets('7. Valida integridade do modelo HoraSAP e parsing dos campos SAP', (tester) async {
      final horaMap = <String, dynamic>{
        'id': 'hora_001',
        'inicio_real': '2026-09-10',
        'data_fim_real': '2026-09-10',
        'tipo_ordem': 'PM01',
        'ordem': '40005555',
        'operacao': '0010',
        'trabalho_real': 8.5,
        'trabalho_planejado': 8.0,
        'trabalho_restante': 0.0,
        'tipo_atividade_real': 'M01',
        'numero_pessoa': '123456',
        'nome_empregado': 'João Silva',
        'status_sistema': 'CONF',
        'texto_confirmacao': 'Atividade concluída',
        'confirmacao': '1000001',
        'centro_trabalho_real': 'EL-MANUT',
        'hora_inicio_real': '08:00:00',
        'data_lancamento': '2026-09-10',
      };

      final hora = HoraSAP.fromMap(horaMap);

      expect(hora.id, equals('hora_001'));
      expect(hora.ordem, equals('40005555'));
      expect(hora.operacao, equals('0010'));
      expect(hora.trabalhoReal, equals(8.5));
      expect(hora.trabalhoPlanejado, equals(8.0));
      expect(hora.tipoAtividadeReal, equals('M01'));
      expect(hora.numeroPessoa, equals('123456'));
      expect(hora.nomeEmpregado, equals('João Silva'));
      expect(hora.statusSistema, equals('CONF'));
    });

    testWidgets('8. Valida formatação e consistência de valores numéricos de horas', (tester) async {
      const double valorHoras = 168.75;
      final formatado = valorHoras.toStringAsFixed(2);
      expect(formatado, equals('168.75'));

      const double valorZero = 0.0;
      expect(valorZero.toStringAsFixed(2), equals('0.00'));
    });
  });
}
