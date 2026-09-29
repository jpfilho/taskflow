import 'dart:typed_data';
import 'export_result.dart';

Future<ExportResult> exportBytesPlatform({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
  String? subject,
}) async {
  return ExportResult(
    success: false,
    filename: filename,
    pathOrLocation: '',
    errorMessage: 'Plataforma não suportada para exportação direta.',
  );
}

Future<void> openExportedFile(String filePath) async {}
