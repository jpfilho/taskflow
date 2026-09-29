import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task2026/config/supabase_config.dart';
import 'package:task2026/design_system/taskflow_design_system.dart';
import 'package:task2026/models/nota_sap.dart';
import 'package:task2026/widgets/notas_sap_view.dart';

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
      child: Scaffold(body: child),
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

  group('Notas SAP - TFDS Presentation & Component Tests', () {
    testWidgets('1. Renderiza cabeçalho, botões de ação e segmented buttons em desktop', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const NotasSAPView(
            key: ValueKey('test_notas_sap'),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Notas SAP'), findsOneWidget);
      expect(find.text('Atualizar'), findsOneWidget);
      expect(find.text('Filtros'), findsOneWidget);
      expect(find.byType(SegmentedButton<String?>), findsNWidgets(2));
    });

    testWidgets('2. Renderiza e valida TFStatusBadge para status da tarefa e prazos', (tester) async {
      final nota = NotaSAP(
        id: 'nota_1',
        nota: '10001234',
        tipo: 'NM',
        descricao: 'Manutenção Preventiva de Teste',
        local: 'SE-TESTE',
        statusSistema: 'MSPR',
        statusUsuario: 'EMAN',
        dataVencimento: DateTime.now().add(const Duration(days: 45)),
        diasRestantes: 45,
      );

      await tester.pumpWidget(
        _wrap(
          Column(
            children: [
              const TFStatusBadge(
                label: 'Em Andamento',
                severity: TFStatusSeverity.info,
                icon: Icons.task,
                compact: true,
              ),
              const TFStatusBadge(
                label: 'Não Programada',
                severity: TFStatusSeverity.neutral,
                icon: Icons.cancel_outlined,
                compact: true,
              ),
              TFStatusBadge(
                label: 'Vence em ${nota.diasRestantes} dias',
                severity: TFStatusSeverity.warning,
                icon: Icons.calendar_today,
                compact: true,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Em Andamento'), findsOneWidget);
      expect(find.text('Não Programada'), findsOneWidget);
      expect(find.text('Vence em 45 dias'), findsOneWidget);
    });

    testWidgets('3. Suporta temas TFDS (Light, Dark, AXIA)', (tester) async {
      for (final theme in [TaskFlowTheme.light(), TaskFlowTheme.dark(), TaskFlowTheme.axia()]) {
        await tester.pumpWidget(
          _wrap(
            const NotasSAPView(),
            theme: theme,
          ),
        );
        await tester.pump();
        expect(find.text('Notas SAP'), findsOneWidget);
      }
    });

    testWidgets('4. Adaptação responsiva (Mobile: 390px, Tablet: 768px, Desktop: 1280px)', (tester) async {
      final sizes = [
        const Size(390, 844),
        const Size(768, 1024),
        const Size(1280, 800),
      ];

      for (final size in sizes) {
        await tester.pumpWidget(
          _wrap(
            const NotasSAPView(),
            width: size.width,
            height: size.height,
          ),
        );
        await tester.pump();
        expect(find.byType(NotasSAPView), findsOneWidget);
      }
    });

    testWidgets('5. Renderiza TFEmptyState com ação de limpar filtros', (tester) async {
      bool actionTriggered = false;

      await tester.pumpWidget(
        _wrap(
          TFEmptyState(
            icon: Icons.description_outlined,
            title: 'Nenhuma nota encontrada',
            description: 'Nenhuma nota corresponde aos filtros selecionados.',
            action: ElevatedButton(
              onPressed: () {
                actionTriggered = true;
              },
              child: const Text('Limpar Filtros'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nenhuma nota encontrada'), findsOneWidget);
      expect(find.text('Limpar Filtros'), findsOneWidget);

      await tester.tap(find.text('Limpar Filtros'));
      expect(actionTriggered, isTrue);
    });
  });
}
