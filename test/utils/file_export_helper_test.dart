import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/utils/file_export_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FileExportHelper Tests', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall methodCall) async {
          return '/tmp';
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        null,
      );
    });

    test('exportString produces valid ExportResult', () async {
      final result = await FileExportHelper.exportString(
        content: 'id,name\n1,test',
        filename: 'test.csv',
        mimeType: 'text/csv',
      );

      expect(result.filename, 'test.csv');
      expect(result.success, isTrue);
      expect(result.pathOrLocation.isNotEmpty, isTrue);
    });

    test('exportBytes produces valid ExportResult', () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final result = await FileExportHelper.exportBytes(
        bytes: bytes,
        filename: 'test.xlsx',
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );

      expect(result.filename, 'test.xlsx');
      expect(result.success, isTrue);
      expect(result.pathOrLocation.isNotEmpty, isTrue);
    });

    testWidgets('showExportSuccessDialog renders dialog with filename and path', (WidgetTester tester) async {
      const result = ExportResult(
        success: true,
        filename: 'programacao_atividades_20260917.xlsx',
        pathOrLocation: '/Users/test/Downloads/programacao_atividades_20260917.xlsx',
        localFilePath: '/Users/test/Downloads/programacao_atividades_20260917.xlsx',
        canOpenFile: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  FileExportHelper.showExportSuccessDialog(
                    context,
                    result,
                    itemsCount: 42,
                    formatName: 'Excel',
                  );
                },
                child: const Text('Exportar'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Exportar'));
      await tester.pumpAndSettle();

      expect(find.text('Exportação Concluída'), findsOneWidget);
      expect(find.text('programacao_atividades_20260917.xlsx'), findsOneWidget);
      expect(find.text('/Users/test/Downloads/programacao_atividades_20260917.xlsx'), findsOneWidget);
      expect(find.text('42 atividades exportadas com sucesso no formato Excel.'), findsOneWidget);
      expect(find.text('Copiar Caminho'), findsOneWidget);
      expect(find.text('Abrir Arquivo'), findsOneWidget);
    });
  });
}
