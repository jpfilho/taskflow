import 'package:flutter/material.dart';
import '../theme/tf_mobile_spacing.dart';
import '../theme/tf_mobile_typography.dart';
import '../theme/tf_mobile_colors.dart';
import '../theme/tf_mobile_touch_targets.dart';

/// BottomSheet arrastável oficial do TaskFlow Mobile com suporte a teclado e rodapé fixo.
class TFMobileBottomSheet extends StatelessWidget {
  final String title;
  final Widget content;
  final Widget? stickyFooter;
  final VoidCallback? onClose;
  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;
  final bool isScrollControlled;

  const TFMobileBottomSheet({
    super.key,
    required this.title,
    required this.content,
    this.stickyFooter,
    this.onClose,
    this.initialChildSize = 0.65,
    this.minChildSize = 0.35,
    this.maxChildSize = 0.95,
    this.isScrollControlled = true,
  });

  /// Método helper para abrir a folha inferior nativa.
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget content,
    Widget? stickyFooter,
    double initialChildSize = 0.65,
    double minChildSize = 0.35,
    double maxChildSize = 0.95,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TFMobileBottomSheet(
        title: title,
        content: content,
        stickyFooter: stickyFooter,
        initialChildSize: initialChildSize,
        minChildSize: minChildSize,
        maxChildSize: maxChildSize,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = TFMobileColors.surface(context);
    final textPrimary = TFMobileColors.textPrimary(context);
    final viewInsets = MediaQuery.of(context).viewInsets;

    return AnimatedPadding(
      padding: viewInsets,
      duration: const Duration(milliseconds: 150),
      child: DraggableScrollableSheet(
        initialChildSize: initialChildSize,
        minChildSize: minChildSize,
        maxChildSize: maxChildSize,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 16.0,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40.0,
                      height: 5.0,
                      margin: const EdgeInsets.symmetric(vertical: TFMobileSpacing.sm),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),

                  // Header com Título e Botão Fechar (≥48px)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: TFMobileSpacing.lg,
                      vertical: TFMobileSpacing.xs,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TFMobileTypography.titleLarge.copyWith(
                              color: textPrimary,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: TFMobileTouchTargets.min,
                          height: TFMobileTouchTargets.min,
                          child: IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: onClose ?? () => Navigator.of(context).pop(),
                            splashRadius: 24.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1.0),

                  // Conteúdo com rolagem
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(TFMobileSpacing.lg),
                      child: content,
                    ),
                  ),

                  // Rodapé fixo na base (Sticky Footer para botões de ação)
                  if (stickyFooter != null) ...[
                    const Divider(height: 1.0),
                    Padding(
                      padding: const EdgeInsets.all(TFMobileSpacing.lg),
                      child: stickyFooter!,
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
