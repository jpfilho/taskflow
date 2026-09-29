import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/mobile/core/config/mobile_feature_flags.dart';
import 'package:task2026/mobile/core/navigation/mobile_routes.dart';
import 'package:task2026/mobile/core/theme/tf_mobile_touch_targets.dart';
import 'package:task2026/mobile/shell/mobile_shell.dart';
import 'package:task2026/mobile/shell/widgets/tf_field_quick_actions_sheet.dart';
import 'package:task2026/mobile/modules/home/mobile_today_screen.dart';
import 'package:task2026/mobile/modules/tasks/mobile_tasks_tab.dart';
import 'package:task2026/mobile/modules/feed/mobile_feed_screen.dart';
import 'package:task2026/mobile/modules/more/mobile_more_screen.dart';
import 'package:task2026/mobile/core/navigation/tf_mobile_navigator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: 'http://212.85.0.249:8000',
        anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzY1ODE3OTgzLCJleHAiOjIwODExNzc5ODN9.YQByqDrpmw0en7VeEcjDfvvTx8Ind_q8gD6-bzEY4Yc',
      );
    } catch (_) {}
  });

  group('TaskFlow Mobile — Fase 2: Quality Gate do MobileShell e Navegação', () {
    testWidgets('1. MobileShell renderiza com barra inferior de 5 botões e IndexedStack com 4 abas', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: TFMobileShell(
            onLogout: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Verifica se os 5 rótulos da barra de navegação estão presentes
      expect(find.text('Hoje'), findsOneWidget);
      expect(find.text('Atividades'), findsOneWidget);
      expect(find.text('Campo'), findsOneWidget);
      expect(find.text('Feed'), findsOneWidget);
      expect(find.text('Mais'), findsOneWidget);

      // Verifica que o IndexedStack possui exatamente 4 abas de conteúdo
      final indexedStackFinder = find.byType(IndexedStack);
      expect(indexedStackFinder, findsOneWidget);
      final indexedStack = tester.widget<IndexedStack>(indexedStackFinder);
      expect(indexedStack.children.length, equals(4));

      // Aba inicial é Hoje (índice 0)
      expect(indexedStack.index, equals(0));
      expect(find.byType(MobileTodayScreen), findsOneWidget);
    });

    testWidgets('2. O botão central Campo funciona como AÇÃO e abre TFFieldQuickActionsSheet', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: TFMobileShell(
            onLogout: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Toca no botão Campo
      final campoButton = find.text('Campo');
      expect(campoButton, findsOneWidget);
      await tester.tap(campoButton);
      await tester.pump(const Duration(milliseconds: 500));

      // Verifica que abriu a BottomSheet de ações rápidas
      expect(find.byType(TFFieldQuickActionsSheet), findsOneWidget);
      expect(find.text('Ações Rápidas de Campo'), findsOneWidget);
      expect(find.text('Tirar Foto / Evidência'), findsOneWidget);
      expect(find.text('Preencher Checklist'), findsOneWidget);
      expect(find.text('APR de Segurança'), findsOneWidget);
      expect(find.text('Apontar Horas SAP'), findsOneWidget);

      // Verifica que o IndexedStack PERMANECEU no índice 0 (Hoje)
      final indexedStack = tester.widget<IndexedStack>(find.byType(IndexedStack));
      expect(indexedStack.index, equals(0));
    });

    testWidgets('3. Alternância entre abas e persistência de estado via IndexedStack', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: TFMobileShell(
            onLogout: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Toca na aba Atividades (índice 1)
      await tester.tap(find.text('Atividades'));
      await tester.pump(const Duration(milliseconds: 100));
      var indexedStack = tester.widget<IndexedStack>(find.byType(IndexedStack));
      expect(indexedStack.index, equals(1));
      expect(find.byType(MobileTasksTab), findsOneWidget);

      // 2. Toca na aba Feed (índice 2)
      await tester.tap(find.text('Feed'));
      await tester.pump(const Duration(milliseconds: 100));
      indexedStack = tester.widget<IndexedStack>(find.byType(IndexedStack));
      expect(indexedStack.index, equals(2));
      expect(find.byType(MobileFeedScreen), findsOneWidget);

      // 3. Toca na aba Mais (índice 3)
      await tester.tap(find.text('Mais'));
      await tester.pump(const Duration(milliseconds: 100));
      indexedStack = tester.widget<IndexedStack>(find.byType(IndexedStack));
      expect(indexedStack.index, equals(3));
      expect(find.byType(MobileMoreScreen), findsOneWidget);

      // 4. Retorna para Hoje (índice 0)
      await tester.tap(find.text('Hoje'));
      await tester.pump(const Duration(milliseconds: 100));
      indexedStack = tester.widget<IndexedStack>(find.byType(IndexedStack));
      expect(indexedStack.index, equals(0));
    });

    testWidgets('4. PopScope: Botão voltar no Android retorna para a aba Hoje antes de sair', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: TFMobileShell(
            onLogout: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Vai para a aba Mais (índice 3)
      await tester.tap(find.text('Mais'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, equals(3));

      // Simula pressionar botão voltar no dispositivo
      final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
      await widgetsAppState.didPopRoute();
      await tester.pump(const Duration(milliseconds: 100));

      // Deve ter voltado para o índice 0 (Hoje)
      expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, equals(0));
    });

    testWidgets('5. MobileMoreScreen possui categorias organizadas e logout isolado na base', (tester) async {
      tester.view.physicalSize = const Size(390, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool loggedOut = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: MobileMoreScreen(
                navigator: TFMobileNavigator(context: ctx),
                onLogout: () {
                  loggedOut = true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Verifica presença dos cabeçalhos de categoria
      expect(find.text('OPERAÇÃO & RECURSOS'), findsOneWidget);
      expect(find.text('SISTEMA SAP'), findsOneWidget);
      expect(find.text('ENGENHARIA & ESPECIALIDADES'), findsOneWidget);
      expect(find.text('PRODUTIVIDADE & SUPORTE'), findsOneWidget);
      expect(find.text('SISTEMA & PREFERÊNCIAS'), findsOneWidget);

      // Verifica presença da seção isolada de logout
      expect(find.text('Sessão do Usuário'), findsOneWidget);
      expect(find.text('Sair da Conta'), findsOneWidget);

      // Toca em Sair da Conta e confirma no diálogo
      await tester.tap(find.text('Sair da Conta'));
      await tester.pumpAndSettle();

      expect(find.text('Encerrar Sessão'), findsOneWidget);
      expect(find.text('Sim, Sair'), findsOneWidget);

      await tester.tap(find.text('Sim, Sair'));
      await tester.pumpAndSettle();

      expect(loggedOut, isTrue);
    });

    testWidgets('6. Resoluções Mobile 360x800, 390x844 e 412x915 sem RenderFlex overflow', (tester) async {
      for (final res in [const Size(360, 800), const Size(390, 844), const Size(412, 915)]) {
        tester.view.physicalSize = res;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: TFMobileShell(
              onLogout: () {},
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('7. Text Scale 1.0, 1.3 e 1.5 sem quebras ou travamentos', (tester) async {
      for (final scale in [1.0, 1.3, 1.5]) {
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: const Size(390, 844),
              textScaler: TextScaler.linear(scale),
            ),
            child: MaterialApp(
              home: TFMobileShell(
                onLogout: () {},
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        final exc = tester.takeException();
        if (exc != null) {
          if (exc is FlutterError) {
            debugPrint('DETAILED ERROR: ${exc.toStringDeep()}');
          } else {
            debugPrint('FAILED AT SCALE $scale: $exc');
          }
        }
        expect(exc, isNull);
      }
    });
  });
}
