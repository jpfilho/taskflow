import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../providers/theme_provider.dart';
import 'gallery_shell.dart';

/// Ponto de entrada oficial para a Design System Gallery.
///
/// Protegido com restrição de debug para não ser exposto a usuários finais de produção.
class DesignSystemGallery extends StatelessWidget {
  final ThemeProvider? themeProvider;

  const DesignSystemGallery({
    super.key,
    this.themeProvider,
  });

  /// Abre a Gallery através de navegação direta de forma segura.
  static void open(BuildContext context, {ThemeProvider? themeProvider}) {
    if (!kDebugMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A Design System Gallery só está disponível em modo de desenvolvimento.')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DesignSystemGallery(themeProvider: themeProvider),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GalleryShell(themeProvider: themeProvider);
  }
}
