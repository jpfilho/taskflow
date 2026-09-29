// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Fallback de compatibilidade legado (DOM-based) para navegadores web quando
/// `navigator.clipboard` não está acessível (ex: contextos HTTP inseguros,
/// intranets sem SSL ou certas políticas de iframe).
///
/// Não é garantido em 100% dos navegadores modernos a longo prazo devido à depreciação
/// do `execCommand`, mas oferece compatibilidade estendida para ambientes legados.
bool copyToClipboardWeb(String text) {
  if (text.isEmpty) return false;

  try {
    // 1. Verificar suporte ao comando 'copy' no documento
    final isSupported = html.document.queryCommandSupported('copy');
    if (!isSupported) {
      return false;
    }

    // 2. Preservar elemento focado anteriormente para restaurar foco
    final previousActiveElement = html.document.activeElement;

    // 3. Criar elemento textarea fora da área de visão (evita layout shift e scroll jump)
    final textArea = html.TextAreaElement()
      ..value = text
      ..setAttribute('readonly', '')
      ..style.position = 'fixed'
      ..style.top = '-9999px'
      ..style.left = '-9999px'
      ..style.width = '2em'
      ..style.height = '2em'
      ..style.padding = '0'
      ..style.border = 'none'
      ..style.outline = 'none'
      ..style.boxShadow = 'none'
      ..style.background = 'transparent'
      ..style.opacity = '0';

    html.document.body?.append(textArea);

    try {
      textArea.focus();
      textArea.select();
      textArea.setSelectionRange(0, text.length);

      final successful = html.document.execCommand('copy');
      return successful == true;
    } finally {
      // 4. Cleanup obrigatório do elemento temporário do DOM
      textArea.remove();

      // 5. Restauração de foco de forma segura
      if (previousActiveElement is html.HtmlElement) {
        try {
          previousActiveElement.focus();
        } catch (_) {}
      }
    }
  } catch (e) {
    return false;
  }
}
