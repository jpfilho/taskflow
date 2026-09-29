import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'clipboard_helper.dart';
import 'export_result.dart';
import 'file_export_stub.dart'
    if (dart.library.html) 'file_export_web.dart'
    if (dart.library.io) 'file_export_io.dart' as platform_impl;

export 'export_result.dart';

/// Helper multiplataforma para exportação de arquivos (Web, macOS, Windows, Linux, Android, iOS).
class FileExportHelper {
  /// Salva e exporta bytes (Excel, PDF, binários) para a plataforma atual.
  static Future<ExportResult> exportBytes({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    String? subject,
  }) async {
    return platform_impl.exportBytesPlatform(
      bytes: bytes,
      filename: filename,
      mimeType: mimeType,
      subject: subject,
    );
  }

  /// Salva e exporta strings (CSV, texto, JSON) para a plataforma atual.
  static Future<ExportResult> exportString({
    required String content,
    required String filename,
    required String mimeType,
    String? subject,
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(content));
    return exportBytes(
      bytes: bytes,
      filename: filename,
      mimeType: mimeType,
      subject: subject,
    );
  }

  /// Abre o arquivo exportado localmente no sistema operacional.
  static Future<void> openFile(String filePath) async {
    await platform_impl.openExportedFile(filePath);
  }

  /// Exibe um diálogo informativo detalhado após a exportação com o nome e caminho do arquivo.
  static Future<void> showExportSuccessDialog(
    BuildContext context,
    ExportResult result, {
    int? itemsCount,
    String? formatName,
  }) async {
    if (!context.mounted) return;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline, color: Colors.green, size: 28),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Exportação Concluída',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (itemsCount != null) ...[
              Text(
                '$itemsCount atividade${itemsCount != 1 ? 's' : ''} exportada${itemsCount != 1 ? 's' : ''} com sucesso no formato ${formatName ?? ''}.',
                style: TextStyle(
                  color: isDark ? Colors.grey[300] : Colors.grey[800],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
            ],
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.insert_drive_file_outlined, size: 16, color: Colors.blue),
                      const SizedBox(width: 6),
                      const Text(
                        'Nome do arquivo:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  SelectableText(
                    result.filename,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const Divider(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.folder_open_outlined, size: 16, color: Colors.orange),
                      const SizedBox(width: 6),
                      const Text(
                        'Local de salvamento:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  SelectableText(
                    result.pathOrLocation,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (result.localFilePath != null)
            TextButton.icon(
              onPressed: () {
                ClipboardHelper.copyAndNotify(
                  context,
                  result.localFilePath!,
                  successMessage: 'Caminho do arquivo copiado!',
                );
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copiar Caminho'),
            ),
          if (result.canOpenFile && result.localFilePath != null)
            ElevatedButton.icon(
              onPressed: () {
                openFile(result.localFilePath!);
              },
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Abrir Arquivo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
              ),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
