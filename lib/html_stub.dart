// Stub file para quando dart:html não está disponível (iOS/Android)
// Este arquivo é usado apenas quando compilando para plataformas não-web

class StyleElement {
  String? id;
  String? text;
  StyleElement();
}

class Blob {
  Blob(List<dynamic> data, [String? mimeType]);
}

class AnchorElement extends Element {
  String? href;
  String? id;
  AnchorElement({this.href}) : super();
  void setAttribute(String name, String value) {}
  void click() {}
  void setInnerHtml(String html, {dynamic treeSanitizer}) {}
  dynamic get style => _Style();
}

class _Style {
  String display = '';
  String position = '';
  String left = '';
  String visibility = '';
  String width = '';
  String height = '';
  String cssText = '';
  String top = '';
  String right = '';
  String backgroundColor = '';
  String color = '';
  String padding = '';
  String borderRadius = '';
  String textDecoration = '';
  String fontSize = '';
  String fontWeight = '';
  String zIndex = '';
  String boxShadow = '';
  String cursor = '';
}

class Url {
  static String createObjectUrlFromBlob(Blob blob) => '';
  static void revokeObjectUrl(String url) {}
}

class _Document {
  Element? get head => _HeadElement();
  Element? get body => _BodyElement();
  Element? get documentElement => _DocumentElement();
  Element? getElementById(String id) => null;
  Element? querySelector(String selector) => null;
}

class _DocumentElement extends Element {
  _DocumentElement() : super();
}

class _HeadElement extends Element {
  _HeadElement() : super();
}

class _BodyElement extends Element {
  _BodyElement() : super();
}

class _Window {
  void print() {}
  _Location get location => _Location();
  void open(String url, String target) {}
}

class _Location {
  String href = '';
}

class Element {
  void append(dynamic element) {}
  void remove() {}
  String? id;
}

class NodeTreeSanitizer {
  static NodeTreeSanitizer get trusted => NodeTreeSanitizer();
}

final document = _Document();
final window = _Window();
