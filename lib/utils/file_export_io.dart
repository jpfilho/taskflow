import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'export_result.dart';

Future<ExportResult> exportBytesPlatform({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
  String? subject,
}) async {
  try {
    io.Directory targetDir;
    if (io.Platform.isAndroid || io.Platform.isIOS) {
      targetDir = await getTemporaryDirectory();
    } else {
      targetDir = (await getDownloadsDirectory()) ?? (await getApplicationDocumentsDirectory());
    }

    final filePath = '${targetDir.path}/$filename';
    final file = io.File(filePath);
    await file.writeAsBytes(bytes, flush: true);

    if (io.Platform.isAndroid || io.Platform.isIOS) {
      final xFile = XFile(file.path, name: filename, mimeType: mimeType);
      await Share.shareXFiles([xFile], text: subject ?? filename);
      return ExportResult(
        success: true,
        filename: filename,
        pathOrLocation: 'Salvo / Compartilhado no dispositivo',
        localFilePath: file.path,
        canOpenFile: true,
      );
    } else {
      return ExportResult(
        success: true,
        filename: filename,
        pathOrLocation: file.path,
        localFilePath: file.path,
        canOpenFile: true,
      );
    }
  } catch (e) {
    debugPrint('Erro ao salvar arquivo no sistema de arquivos: $e');
    return ExportResult(
      success: false,
      filename: filename,
      pathOrLocation: '',
      errorMessage: e.toString(),
    );
  }
}

Future<void> openExportedFile(String filePath) async {
  try {
    if (io.Platform.isMacOS) {
      await io.Process.run('open', [filePath]);
    } else if (io.Platform.isWindows) {
      await io.Process.run('cmd', ['/c', 'start', '', filePath]);
    } else if (io.Platform.isLinux) {
      await io.Process.run('xdg-open', [filePath]);
    } else {
      final uri = Uri.file(filePath);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  } catch (e) {
    debugPrint('Erro ao abrir arquivo exportado: $e');
  }
}
