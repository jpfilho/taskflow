import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/utils/clipboard_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ClipboardHelper Unit & Widget Tests', () {
    final List<MethodCall> methodCalls = [];

    setUp(() {
      methodCalls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (MethodCall methodCall) async {
        methodCalls.add(methodCall);
        if (methodCall.method == 'Clipboard.setData') {
          return null;
        } else if (methodCall.method == 'Clipboard.getData') {
          return {'text': 'mocked clipboard content'};
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    test('copy(empty string) returns false without calling platform channel', () async {
      final result = await ClipboardHelper.copy('');
      expect(result, isFalse);
      expect(methodCalls, isEmpty);
    });

    test('copy(text) successfully delegates to platform channel and returns true', () async {
      final result = await ClipboardHelper.copy('Hello TaskFlow');
      expect(result, isTrue);
      expect(methodCalls.any((call) => call.method == 'Clipboard.setData'), isTrue);
      final setDataCall = methodCalls.firstWhere((call) => call.method == 'Clipboard.setData');
      expect(setDataCall.arguments, {'text': 'Hello TaskFlow'});
    });

    test('copy(text) returns false in non-web when platform channel throws PlatformException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (MethodCall methodCall) async {
        if (methodCall.method == 'Clipboard.setData') {
          throw PlatformException(
            code: 'copy_fail',
            message: 'Clipboard is not available in the context.',
          );
        }
        return null;
      });

      final result = await ClipboardHelper.copy('Sample Text');
      expect(result, isFalse);
    });

    testWidgets('copyAndNotify shows success SnackBar on success', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  ClipboardHelper.copyAndNotify(
                    context,
                    'Texto Copiado',
                    successMessage: 'Nota copiada com sucesso!',
                  );
                },
                child: const Text('Copiar'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Copiar'));
      await tester.pumpAndSettle();

      expect(find.text('Nota copiada com sucesso!'), findsOneWidget);
    });

    testWidgets('copyAndNotify shows default success SnackBar if no message passed', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  ClipboardHelper.copyAndNotify(context, 'Texto');
                },
                child: const Text('Copiar'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Copiar'));
      await tester.pumpAndSettle();

      expect(find.text('Copiado para a área de transferência!'), findsOneWidget);
    });

    testWidgets('copyAndNotify shows error SnackBar and does NOT show success when text is empty', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  ClipboardHelper.copyAndNotify(
                    context,
                    '',
                    errorMessage: 'Falha personalizada ao copiar',
                  );
                },
                child: const Text('Copiar Vazio'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Copiar Vazio'));
      await tester.pumpAndSettle();

      expect(find.text('Falha personalizada ao copiar'), findsOneWidget);
      expect(find.text('Copiado para a área de transferência!'), findsNothing);
    });

    testWidgets('copyAndNotify shows default error SnackBar when copy fails', (WidgetTester tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (MethodCall methodCall) async {
        if (methodCall.method == 'Clipboard.setData') {
          throw PlatformException(code: 'copy_fail');
        }
        return null;
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  ClipboardHelper.copyAndNotify(context, 'Falhar');
                },
                child: const Text('Copiar'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Copiar'));
      await tester.pumpAndSettle();

      expect(find.text('Não foi possível copiar para a área de transferência.'), findsOneWidget);
    });
  });
}
