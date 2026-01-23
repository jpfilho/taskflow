// Stub file para quando dart:html não está disponível (iOS/Android)
// Este arquivo é usado apenas quando compilando para plataformas não-web

class StyleElement {
  String? id;
  String? text;
}

class Blob {
  Blob(List<dynamic> data, [String? mimeType]);
}

class AnchorElement {
  String? href;
  AnchorElement({this.href});
  void setAttribute(String name, String value) {}
  void click() {}
}

class Url {
  static String createObjectUrlFromBlob(Blob blob) => '';
  static void revokeObjectUrl(String url) {}
}

final document = _Document();
final window = _Window();

class _Document {
  Element? get head => null;
  Element? getElementById(String id) => null;
}

class _Window {
  void print() {}
}

class Element {
  void append(dynamic element) {}
}
