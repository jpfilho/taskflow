// Implementação para mobile/desktop: usa dart:io para ler do path.
// Isolado aqui para que a view não importe dart:io (quebraria Flutter Web).
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Lê os bytes do arquivo a partir do path (mobile/desktop).
Future<Uint8List?> readFileBytes(PlatformFile file) async {
  if (file.path == null || file.path!.isEmpty) return file.bytes;
  return File(file.path!).readAsBytes();
}
