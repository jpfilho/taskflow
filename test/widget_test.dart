import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task2026/design_system/taskflow_design_system.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('TaskFlow — Bootstrap Smoke Tests', () {
    testWidgets('1. Root App Shell boots and mounts MaterialApp cleanly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          title: 'TaskFlow',
          theme: TaskFlowTheme.light(),
          darkTheme: TaskFlowTheme.dark(),
          home: Scaffold(
            appBar: AppBar(
              title: const Text('TaskFlow Bootstrap'),
            ),
            body: const Center(
              child: TFCard(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('TaskFlow Ready'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.text('TaskFlow Bootstrap'), findsOneWidget);
      expect(find.text('TaskFlow Ready'), findsOneWidget);
    });

    testWidgets('2. TaskFlow Theme extensions are accessible at runtime', (tester) async {
      late BuildContext capturedContext;

      await tester.pumpWidget(
        MaterialApp(
          theme: TaskFlowTheme.light(),
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pump();

      expect(capturedContext.tfColors, isNotNull);
      expect(capturedContext.tfTypography, isNotNull);
      expect(capturedContext.tfSpacing, isNotNull);
      expect(capturedContext.tfRadius, isNotNull);
    });
  });
}
