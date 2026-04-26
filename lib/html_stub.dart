// Stub para quando dart:html não está disponível (iOS/Android/desktop).
// Usado ao compilar para plataformas não-web; implementações vazias para compilar.

class MouseEvent {
  MouseEvent(String type);
}

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
  @override
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

class WindowBase {
  void print() {}
}

class _Window {
  void print() {}
  _Location get location => _Location();
  WindowBase? open(String url, String target) => null;
}

class _Location {
  String href = '';
}

class Element {
  void append(dynamic element) {}
  void remove() {}
  void dispatchEvent(dynamic event) {}
  String? id;
}

class NodeTreeSanitizer {
  static NodeTreeSanitizer get trusted => NodeTreeSanitizer();
}

final document = _Document();
final window = _Window();
