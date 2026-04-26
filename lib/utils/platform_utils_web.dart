import 'dart:html' as html;

void printHtml(String title, String htmlContent) {
  final html.WindowBase? printWindow = html.window.open('', '_blank');
  if (printWindow == null) return;
  
  // Usamos dynamic para acessar métodos do DOM que não estão expostos no wrapper do Flutter
  final win = printWindow as dynamic;
  (win.document as dynamic).write(htmlContent);
  (win.document as dynamic).close();
  (win as dynamic).print();
}
