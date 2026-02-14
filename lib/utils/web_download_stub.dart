// Stub para plataformas não-web: downloadBytesWeb não faz nada.
// Evita importar dart:html em mobile/desktop.
import 'dart:typed_data';

/// No-op em plataformas não-web. Só use quando kIsWeb == true.
void downloadBytesWeb(Uint8List bytes, String filename, String mime) {
  // Nada a fazer; a view chama apenas quando kIsWeb.
}
