// Implementação para Flutter Web: não usa dart:io (incompatível com web).
// Usar FilePicker com withData: true e PlatformFile.bytes.
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Lê os bytes do arquivo selecionado. No Web, depende de [PlatformFile.bytes]
/// (obtido com FilePicker com [withData: true]).
Future<Uint8List?> readFileBytes(PlatformFile file) async {
  return file.bytes;
}
