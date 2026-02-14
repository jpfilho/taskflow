// Barrel: download no Web (dart:html) vs stub (mobile/desktop).
export 'web_download_stub.dart' if (dart.library.html) 'web_download_web.dart';
