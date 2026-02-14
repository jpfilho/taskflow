// Download de bytes no navegador (dart:html). Robusto para Safari/iOS:
// Blob URL, Anchor no body, dispatchEvent(MouseEvent('click')), target _blank,
// revogar URL após 3–5 s; fallback window.open(url, '_blank').
import 'dart:async';

import 'package:flutter/foundation.dart';

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void downloadBytesWeb(Uint8List bytes, String filename, String mime) {
  String? url;
  try {
    final blob = html.Blob([bytes], mime);
    url = html.Url.createObjectUrlFromBlob(blob);
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
    // Safari e alguns navegadores precisam do URL por mais tempo
    Future.delayed(const Duration(seconds: 4), () {
      if (url != null) html.Url.revokeObjectUrl(url);
    });
  } catch (e) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('downloadBytesWeb: $e');
    }
    if (url != null) {
      final urlToRevoke = url;
      try {
        html.window.open(urlToRevoke, '_blank');
      } catch (_) {}
      Future.delayed(const Duration(seconds: 5), () {
        try {
          html.Url.revokeObjectUrl(urlToRevoke);
        } catch (_) {}
      });
    }
    rethrow;
  }
}
