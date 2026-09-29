// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'export_result.dart';

Future<ExportResult> exportBytesPlatform({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
  String? subject,
}) async {
  try {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..target = '_blank'
      ..style.display = 'none';

    html.document.body?.append(anchor);
    try {
      anchor.dispatchEvent(html.MouseEvent('click'));
    } catch (_) {
      anchor.click();
    }
    anchor.remove();

    Future.delayed(const Duration(seconds: 4), () {
      try {
        html.Url.revokeObjectUrl(url);
      } catch (_) {}
    });

    return ExportResult(
      success: true,
      filename: filename,
      pathOrLocation: 'Pasta de Downloads do seu Navegador',
      canOpenFile: false,
    );
  } catch (e) {
    return ExportResult(
      success: false,
      filename: filename,
      pathOrLocation: '',
      errorMessage: e.toString(),
    );
  }
}

Future<void> openExportedFile(String filePath) async {}
