import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/design_system/theme/taskflow_theme.dart';
import 'package:task2026/features/apoios_operacionais/presentation/task_apoio_ui_controller.dart';
import 'package:task2026/features/apoios_operacionais/presentation/views/central_apoios_view.dart';

Widget _wrapCentral(
  Widget child, {
  ThemeData? theme,
  Size size = const Size(1280, 840),
}) {
  return MaterialApp(
    theme: theme ?? TaskFlowTheme.light(),
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  group('CentralApoiosView — Fase 5', () {
    testWidgets('Exibe proteção por padrão e ativa modo demonstração DEV sob comando explícito', (tester) async {
      final ctrl = TaskApoioUiController();
      await tester.pumpWidget(
        _wrapCentral(
          CentralApoiosView(
            controller: ctrl,
            usuarioAtualId: 'demo-user-1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Central de Apoios Operacionais'), findsOneWidget);
      expect(find.textContaining('Apoios Operacionais protegidos'), findsOneWidget);
      expect(find.text('Ativar Modo Demonstração (DEV)'), findsOneWidget);

      await tester.tap(find.text('Ativar Modo Demonstração (DEV)'));
      await tester.pumpAndSettle();

      expect(find.textContaining('MODO DEMONSTRAÇÃO (DEV)'), findsOneWidget);
      expect(find.textContaining('Recebidas ('), findsOneWidget);
      expect(find.textContaining('Enviadas ('), findsOneWidget);
      expect(find.textContaining('Programados ('), findsOneWidget);
      expect(find.textContaining('Pendências e riscos ('), findsOneWidget);
    });

    testWidgets('Filtra por KPI, busca textual, abas e executa negociação na Central', (tester) async {
      tester.view.physicalSize = const Size(1280, 840);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final ctrl = TaskApoioUiController();
      await ctrl.ativarModoDemonstracaoDev();

      await tester.pumpWidget(
        _wrapCentral(
          CentralApoiosView(
            controller: ctrl,
            usuarioAtualId: 'demo-user-frota',
            usuarioAtualNome: 'Gestor Frota',
            divisaoAtualId: 'demo-div-frota',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Busca textual por "Prancha"
      await tester.enterText(
        find.byType(TextField).first,
        'Prancha',
      );
      await tester.pumpAndSettle();
      expect(find.text('[DEMONSTRAÇÃO] Prancha transporte'), findsOneWidget);

      // Encaminhar para análise diretamente na tabela via ação contextual "Analisar"
      await tester.tap(find.text('Analisar').first);
      await tester.pumpAndSettle();
      expect(find.text('Aceitar / Decidir'), findsWidgets);

      // Abrir e fechar painel lateral de detalhamento
      expect(find.text('Detalhamento do Apoio'), findsNothing);
      await tester.tap(find.text('[DEMONSTRAÇÃO] Prancha transporte'));
      await tester.pumpAndSettle();
      expect(find.text('Detalhamento do Apoio'), findsOneWidget);
      expect(find.text('Próxima providência'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.text('Detalhamento do Apoio'), findsNothing);

      // Limpar filtros e navegar para Pendências e riscos
      await tester.tap(find.text('Limpar'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Pendências e riscos'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Parcialmente programado'), findsWidgets);

      // Navegar para aba Programados
      await tester.tap(find.textContaining('Programados'));
      await tester.pumpAndSettle();
      expect(find.text('[DEMONSTRAÇÃO] Caminhão Munck com operador'), findsOneWidget);
    });

    testWidgets('Renderiza responsivamente em viewport mobile (390x844) com Tema Escuro sem overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final ctrl = TaskApoioUiController();
      await ctrl.ativarModoDemonstracaoDev();

      await tester.pumpWidget(
        _wrapCentral(
          CentralApoiosView(
            controller: ctrl,
            usuarioAtualId: 'demo-user-1',
            initialTabIndex: 3,
          ),
          theme: TaskFlowTheme.dark(),
          size: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Central de Apoios Operacionais'), findsOneWidget);
      expect(find.textContaining('Pendências e riscos'), findsOneWidget);
    });

    testWidgets(
      'Respeita período global compartilhado, toggle Incluir pendências anteriores e coerência KPI-aba',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 840);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final ctrl = TaskApoioUiController();
        await ctrl.ativarModoDemonstracaoDev();

        // 1. Período de Novembro/2026 (coincide com os dados demo): Recebidas (6) e Enviadas (0)
        await tester.pumpWidget(
          _wrapCentral(
            CentralApoiosView(
              controller: ctrl,
              usuarioAtualId: 'demo-user-frota',
              divisaoAtualId: 'demo-div-frota',
              periodoInicio: DateTime(2026, 11, 1),
              periodoFim: DateTime(2026, 11, 30),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Recebidas (6)'), findsOneWidget);
        expect(find.text('Enviadas (0)'), findsOneWidget);
        expect(find.text('6'), findsWidgets);

        // 2. Período de Dezembro/2026 (fora dos dados demo de Novembro): lista e KPI zeram
        await tester.pumpWidget(
          _wrapCentral(
            CentralApoiosView(
              controller: ctrl,
              usuarioAtualId: 'demo-user-frota',
              divisaoAtualId: 'demo-div-frota',
              periodoInicio: DateTime(2026, 12, 1),
              periodoFim: DateTime(2026, 12, 31),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Recebidas (0)'), findsOneWidget);

        // 3. Ativar "Incluir pendências anteriores" traz pendências de Novembro para o escopo
        await tester.tap(find.text('Incluir pendências anteriores'));
        await tester.pumpAndSettle();

        expect(find.text('Recebidas (6)'), findsNothing);
        expect(find.textContaining('Recebidas ('), findsOneWidget);
        expect(find.text('Recebidas (0)'), findsNothing);
      },
    );

    testWidgets(
      'Modo somente leitura (podeEditar: false) oculta Nova solicitação e ações de edição',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 840);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final ctrl = TaskApoioUiController();
        await ctrl.ativarModoDemonstracaoDev();

        await tester.pumpWidget(
          _wrapCentral(
            CentralApoiosView(
              controller: ctrl,
              usuarioAtualId: 'demo-user-frota',
              divisaoAtualId: 'demo-div-frota',
              podeEditar: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Nova solicitação'), findsNothing);
        expect(find.text('Analisar'), findsNothing);
        expect(find.text('Aceitar / Decidir'), findsNothing);
        expect(find.text('Consultar'), findsWidgets);
      },
    );
  });
}
