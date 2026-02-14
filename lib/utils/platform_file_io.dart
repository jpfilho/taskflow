// Barrel com import condicional: evita dart:io na view (incompatível com Web).
// Web -> platform_file_io_web (usa apenas PlatformFile.bytes).
// Mobile/Desktop -> platform_file_io_io (usa dart:io File).
export 'platform_file_io_io.dart' if (dart.library.html) 'platform_file_io_web.dart';
