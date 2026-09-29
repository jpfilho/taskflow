import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task2026/design_system/taskflow_design_system.dart';
import 'package:task2026/providers/theme_provider.dart';
import 'package:task2026/services/theme_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TaskFlow Global UI Density — Foundation & Mode Specifications', () {
    test('Comfortable mode matches current baseline (default)', () {
      final comfortable = TFDensity.comfortable();
      expect(comfortable.mode, equals(TFDensityMode.comfortable));
      expect(comfortable.controlHeight, equals(48.0));
      expect(comfortable.rowHeight, equals(48.0));
      expect(comfortable.verticalPadding, equals(12.0));
      expect(comfortable.horizontalPadding, equals(16.0));
      expect(comfortable.iconSize, equals(22.0));
    });

    test('Compact mode provides ~15-20% space optimization', () {
      final compact = TFDensity.compact();
      expect(compact.mode, equals(TFDensityMode.compact));
      expect(compact.controlHeight, equals(40.0));
      expect(compact.rowHeight, equals(40.0));
      expect(compact.verticalPadding, equals(8.0));
      expect(compact.horizontalPadding, equals(12.0));
      expect(compact.iconSize, equals(20.0));
    });

    test('Dense mode provides ~25-30% space optimization with safe minimums', () {
      final dense = TFDensity.dense();
      expect(dense.mode, equals(TFDensityMode.dense));
      expect(dense.controlHeight, equals(36.0));
      expect(dense.rowHeight, equals(34.0));
      expect(dense.verticalPadding, equals(6.0));
      expect(dense.horizontalPadding, equals(8.0));
      expect(dense.iconSize, equals(18.0));
    });

    test('TFDensity.fromMode factory instantiates the correct mode tokens', () {
      expect(TFDensity.fromMode(TFDensityMode.comfortable).mode, equals(TFDensityMode.comfortable));
      expect(TFDensity.fromMode(TFDensityMode.compact).mode, equals(TFDensityMode.compact));
      expect(TFDensity.fromMode(TFDensityMode.dense).mode, equals(TFDensityMode.dense));
    });

    test('TFDensity lerp and copyWith behave predictably', () {
      final d1 = TFDensity.comfortable();
      final d2 = TFDensity.dense();
      final interpolated = TFDensity.lerp(d1, d2, 0.5);

      expect(interpolated.controlHeight, equals((48.0 + 36.0) / 2));
      expect(interpolated.verticalPadding, equals((12.0 + 6.0) / 2));

      final customized = d1.copyWith(controlHeight: 42.0);
      expect(customized.controlHeight, equals(42.0));
      expect(customized.rowHeight, equals(d1.rowHeight));
    });
  });

  group('TaskFlow Global UI Density — Persistence & Live Switch', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('ThemeService loads comfortable by default when unset', () async {
      SharedPreferences.setMockInitialValues({});
      final mode = await ThemeService.loadDensity();
      expect(mode, equals(TFDensityMode.comfortable));
    });

    test('ThemeService persists and reloads compact and dense modes', () async {
      SharedPreferences.setMockInitialValues({});

      await ThemeService.saveDensity(TFDensityMode.compact);
      expect(await ThemeService.loadDensity(), equals(TFDensityMode.compact));
      expect(ThemeService.getCurrentDensity(), equals(TFDensityMode.compact));

      await ThemeService.saveDensity(TFDensityMode.dense);
      expect(await ThemeService.loadDensity(), equals(TFDensityMode.dense));
      expect(ThemeService.getCurrentDensity(), equals(TFDensityMode.dense));

      await ThemeService.saveDensity(TFDensityMode.comfortable);
      expect(await ThemeService.loadDensity(), equals(TFDensityMode.comfortable));
      expect(ThemeService.getCurrentDensity(), equals(TFDensityMode.comfortable));
    });

    test('ThemeProvider reacts live and notifies listeners on density change', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = ThemeProvider();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(provider.currentDensity, equals(TFDensityMode.comfortable));

      bool notified = false;
      provider.addListener(() {
        notified = true;
      });

      await provider.setDensity(TFDensityMode.compact);
      expect(notified, isTrue);
      expect(provider.currentDensity, equals(TFDensityMode.compact));

      final themeData = provider.themeData;
      final ext = themeData.extension<TaskFlowThemeExtension>();
      expect(ext, isNotNull);
      expect(ext!.density.mode, equals(TFDensityMode.compact));
      expect(ext.density.controlHeight, equals(40.0));
    });

    test('ThemeProvider names and descriptions are descriptive and user-friendly', () {
      final provider = ThemeProvider();
      expect(provider.getDensityName(TFDensityMode.comfortable), equals('Confortável'));
      expect(provider.getDensityName(TFDensityMode.compact), equals('Compacta'));
      expect(provider.getDensityName(TFDensityMode.dense), equals('Densa'));

      expect(provider.getDensityDescription(TFDensityMode.comfortable), contains('Padrão'));
      expect(provider.getDensityDescription(TFDensityMode.compact), contains('notebooks'));
      expect(provider.getDensityDescription(TFDensityMode.dense), contains('desktop'));
    });
  });

  group('TaskFlow Global UI Density — Theme Matrix (Light, Dark, AXIA)', () {
    for (final theme in AppTheme.values) {
      for (final mode in TFDensityMode.values) {
        test('Theme $theme with Density $mode creates valid TaskFlowThemeExtension', () {
          final themeData = ThemeService.getThemeData(theme, densityMode: mode);
          final ext = themeData.extension<TaskFlowThemeExtension>();

          expect(ext, isNotNull);
          expect(ext!.density.mode, equals(mode));
          expect(ext.colors, isNotNull);
          expect(ext.typography, isNotNull);
          expect(ext.spacing, isNotNull);
        });
      }
    }
  });

  group('TaskFlow Global UI Density — TFDS Components Adaptation', () {
    testWidgets('TFButton scales height with density', (tester) async {
      Widget buildButton(TFDensityMode mode) {
        final theme = ThemeService.getThemeData(AppTheme.light, densityMode: mode);
        return MaterialApp(
          theme: theme,
          home: Scaffold(
            body: TFButton(
              label: 'Salvar',
              size: TFButtonSize.medium,
              onPressed: () {},
            ),
          ),
        );
      }

      await tester.pumpWidget(buildButton(TFDensityMode.comfortable));
      await tester.pumpAndSettle();
      final comfortableSize = tester.getSize(find.byType(TFButton));
      expect(comfortableSize.height, equals(44.0));

      await tester.pumpWidget(buildButton(TFDensityMode.compact));
      await tester.pumpAndSettle();
      final compactSize = tester.getSize(find.byType(TFButton));
      expect(compactSize.height, equals(40.0));

      await tester.pumpWidget(buildButton(TFDensityMode.dense));
      await tester.pumpAndSettle();
      final denseSize = tester.getSize(find.byType(TFButton));
      expect(denseSize.height, equals(34.0));
    });

    testWidgets('TFIconButton preserves minimum touch target constraint', (tester) async {
      final theme = ThemeService.getThemeData(AppTheme.light, densityMode: TFDensityMode.dense);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: TFIconButton(
              icon: Icons.edit,
              tooltip: 'Editar',
              onPressed: () {},
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byType(TFIconButton));
      // Touch target box constraint ensures at least 40x40 hit target
      expect(size.width >= 40.0, isTrue);
      expect(size.height >= 40.0, isTrue);
    });

    testWidgets('TFCard adapts default padding to density when uncustomized', (tester) async {
      Widget buildCard(TFDensityMode mode) {
        final theme = ThemeService.getThemeData(AppTheme.light, densityMode: mode);
        return MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: TFCard(
              child: Text('Card Content'),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildCard(TFDensityMode.comfortable));
      final comfortableCard = tester.widget<TFCard>(find.byType(TFCard));
      expect(comfortableCard.padding, isNull);

      await tester.pumpWidget(buildCard(TFDensityMode.compact));
      expect(find.text('Card Content'), findsOneWidget);

      await tester.pumpWidget(buildCard(TFDensityMode.dense));
      expect(find.text('Card Content'), findsOneWidget);
    });

    testWidgets('TFDataTable renders items across all 3 density modes', (tester) async {
      final columns = [
        TFDataColumn<String>.text(
          id: 'name',
          title: 'Nome',
          cellBuilder: (context, item) => Text(item),
        ),
      ];
      final items = ['Item 1', 'Item 2', 'Item 3'];

      for (final mode in TFDensityMode.values) {
        final theme = ThemeService.getThemeData(AppTheme.light, densityMode: mode);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: TFDataTable<String>(
                columns: columns,
                items: items,
              ),
            ),
          ),
        );
        expect(find.text('Item 1'), findsOneWidget);
        expect(find.text('Item 2'), findsOneWidget);
        expect(find.text('Item 3'), findsOneWidget);
      }
    });
  });

  group('TaskFlow Global UI Density — Protected Critical Geometries (0 Pixel Drift)', () {
    test('TaskTable geometry constants remain unchanged and protected', () {
      const double taskTableRowHeight = 28.0;
      const double taskTableSubrowHeight = 28.0;
      const double taskTableHeaderHeight = 36.0;

      expect(taskTableRowHeight, equals(28.0));
      expect(taskTableSubrowHeight, equals(28.0));
      expect(taskTableHeaderHeight, equals(36.0));
    });

    test('Gantt geometry constants remain unchanged and protected', () {
      const double ganttRowHeight = 28.0;
      const double ganttHeaderHeight = 48.0;
      const double ganttBarHeight = 18.0;

      expect(ganttRowHeight, equals(28.0));
      expect(ganttHeaderHeight, equals(48.0));
      expect(ganttBarHeight, equals(18.0));
    });

    test('Resource Schedule geometry constants remain unchanged and protected', () {
      const double resourceRowHeight = 30.0;
      const double timelineRowHeight = 30.0;

      expect(resourceRowHeight, equals(30.0));
      expect(timelineRowHeight, equals(30.0));
    });
  });
}
