import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/design_system/gallery/design_system_gallery.dart';
import 'package:task2026/design_system/gallery/gallery_shell.dart';
import 'package:task2026/design_system/taskflow_design_system.dart';
import 'package:task2026/providers/theme_provider.dart';

Widget createGalleryTestApp({ThemeProvider? themeProvider}) {
  return MaterialApp(
    theme: TaskFlowTheme.light(),
    home: GalleryShell(themeProvider: themeProvider),
  );
}

void main() {
  group('TaskFlow Design System — Gallery Tests', () {
    testWidgets('GalleryShell renderiza com título, navegação e seção inicial', (tester) async {
      await tester.pumpWidget(createGalleryTestApp());
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('TF Design System'), findsOneWidget);
      expect(find.text('Visão Geral'), findsWidgets);
      expect(find.text('TaskFlow Design System — Visão Geral'), findsOneWidget);
    });

    testWidgets('Gallery navega entre seções ao clicar na barra lateral', (tester) async {
      await tester.pumpWidget(createGalleryTestApp());
      await tester.pump(const Duration(milliseconds: 200));

      // Clicar em "Cores & Tokens"
      await tester.tap(find.text('Cores & Tokens'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Cores & Tokens Semânticos'), findsOneWidget);
      expect(find.text('Ação Primária & Marca'), findsOneWidget);

      // Clicar em "Botões (TFButton)"
      await tester.tap(find.text('Botões (TFButton)'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('TFButton — Botões de Ação'), findsOneWidget);
      expect(find.text('Variantes Visuais'), findsOneWidget);
    });

    testWidgets('Gallery alterna modos de densidade via SegmentedButton', (tester) async {
      await tester.pumpWidget(createGalleryTestApp());
      await tester.pump(const Duration(milliseconds: 200));

      // Alternar para modo Dense
      expect(find.text('Dense'), findsOneWidget);
      await tester.tap(find.text('Dense'));
      await tester.pump(const Duration(milliseconds: 200));

      // Alternar para modo Comfort
      expect(find.text('Comfort'), findsOneWidget);
      await tester.tap(find.text('Comfort'));
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('DesignSystemGallery.open instancia rota com sucesso', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () => DesignSystemGallery.open(context),
              child: const Text('Abrir Gallery'),
            );
          },
        ),
      ));

      await tester.tap(find.text('Abrir Gallery'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('TF Design System'), findsOneWidget);
    });
  });
}
