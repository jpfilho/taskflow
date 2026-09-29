import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'clipboard_helper_stub.dart'
    if (dart.library.html) 'clipboard_helper_web.dart' as web_clip;

/// Utilitário centralizado e resiliente para operações de cópia para a área de transferência.
///
/// Prioriza a API moderna do Flutter ([Clipboard.setData]), recorrendo a um fallback
/// legado baseado em DOM quando executado em navegadores web sob contextos não seguros
/// (HTTP, intranet sem SSL) ou iframes onde a Clipboard API moderna pode estar indisponível.
class ClipboardHelper {
  /// Copia o texto informado para a área de transferência.
  ///
  /// 1. Prioriza a API padrão do Flutter ([Clipboard.setData]).
  /// 2. Se a API moderna falhar no ambiente Web (ex: contexto inseguro / HTTP / iframe restrito),
  ///    tenta o fallback de compatibilidade legado via DOM.
  /// 3. Retorna `true` apenas se a cópia foi realizada com sucesso; caso contrário `false`.
  static Future<bool> copy(String text) async {
    if (text.isEmpty) return false;

    // 1. Tentativa primária: API moderna do Flutter/Plataforma
    try {
      await Clipboard.setData(ClipboardData(text: text));
      return true;
    } catch (e) {
      debugPrint('⚠️ Modern clipboard API unavailable, attempting web fallback if applicable: $e');
      if (kIsWeb) {
        return web_clip.copyToClipboardWeb(text);
      }
      return false;
    }
  }

  /// Copia o texto e exibe um SnackBar informativo padronizado para o usuário.
  ///
  /// Exibe feedback de sucesso somente se a cópia tiver ocorrido com êxito.
  static Future<bool> copyAndNotify(
    BuildContext context,
    String text, {
    String? successMessage,
    String? errorMessage,
    Duration duration = const Duration(seconds: 2),
  }) async {
    final success = await copy(text);
    if (!context.mounted) return success;

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return success;

    messenger.hideCurrentSnackBar();
    if (success) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(successMessage ?? 'Copiado para a área de transferência!'),
          duration: duration,
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            errorMessage ?? 'Não foi possível copiar para a área de transferência.',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
    return success;
  }
}

