import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/mobile/preview/mobile_design_system_preview.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final resolutions = <String, Size>{
    '360x800': const Size(360, 800),
    '390x844': const Size(390, 844),
    '412x915': const Size(412, 915),
  };

  for (final entry in resolutions.entries) {
    final resolutionName = entry.key;
    final size = entry.value;

    testWidgets('Gera screenshots da tela de preview na resolução $resolutionName',
        (tester) async {
      final boundaryKey = GlobalKey();

      tester.binding.window.physicalSizeTestValue = size;
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      addTearDown(() {
        tester.binding.window.clearPhysicalSizeTestValue();
        tester.binding.window.clearDevicePixelRatioTestValue();
      });

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: boundaryKey,
            child: const MobileDesignSystemPreview(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final boundary =
          boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 2.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          final pngBytes = byteData.buffer.asUint8List();
          final outDir = Directory('docs/mobile_redesign/phase_1');
          if (!outDir.existsSync()) {
            outDir.createSync(recursive: true);
          }
          final outFile = File('${outDir.path}/preview_$resolutionName.png');
          outFile.writeAsBytesSync(pngBytes);
        }
      }
    });
  }
}
