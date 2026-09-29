import 'dart:async';
import 'package:flutter/material.dart';
import '../../foundations/tf_breakpoints.dart';
import '../../foundations/tf_icons.dart';
import '../../foundations/tf_radius.dart';
import '../../theme/taskflow_theme_extension.dart';
import '../buttons/tf_button.dart';
import '../buttons/tf_icon_button.dart';

/// Diálogo de formulário oficial do TaskFlow Design System.
///
/// Padroniza todos os modais de criação e edição administrativa (`*FormDialog`).
/// Cuida de:
/// - Estrutura consistente com Header semântico e botão de fechar.
/// - Scroll vertical interno com tratamento para teclado virtual no Mobile.
/// - Rodapé com hierarquia visual estrita: secundário (Cancelar) e primário (Salvar).
/// - Feedback visual de salvamento assíncrono (`isSaving`), desativando duplo clique.
/// - Largura máxima recomendada de 540px no Desktop/Tablet e adaptativa no Mobile.
class TFFormDialog extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final VoidCallback onCancel;
  final FutureOr<void> Function() onSave;
  final String cancelLabel;
  final String saveLabel;
  final bool isSaving;
  final double maxWidth;
  final GlobalKey<FormState>? formKey;

  const TFFormDialog({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    required this.onCancel,
    required this.onSave,
    this.cancelLabel = 'Cancelar',
    this.saveLabel = 'Salvar',
    this.isSaving = false,
    this.maxWidth = 540.0,
    this.formKey,
  });

  /// Método estático para exibição padronizada do formulário em diálogo modal.
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = false,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: builder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;
    final isMobile = TFBreakpoints.isMobile(context);

    final dialogContent = Container(
      width: isMobile ? double.infinity : maxWidth,
      constraints: BoxConstraints(
        maxWidth: maxWidth,
        maxHeight: MediaQuery.of(context).size.height * (isMobile ? 0.92 : 0.85),
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: TFRadius.borderRadiusLg,
        border: Border.all(color: colors.borderDefault),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header do Diálogo
          Container(
            padding: EdgeInsets.symmetric(horizontal: spacing.lg, vertical: spacing.md),
            decoration: BoxDecoration(
              color: colors.surfaceSecondary.withValues(alpha: 0.4),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(TFRadius.r16)),
              border: Border(bottom: BorderSide(color: colors.borderSubtle)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: typography.cardTitle.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        SizedBox(height: spacing.xxs),
                        Text(
                          subtitle!,
                          style: typography.bodySmall.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                TFIconButton(
                  icon: TFIcons.close,
                  tooltip: 'Fechar',
                  variant: TFIconButtonVariant.subtle,
                  iconSize: 18,
                  onPressed: isSaving ? null : onCancel,
                ),
              ],
            ),
          ),

          // 2. Body com Scroll Interno
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(spacing.lg),
              child: formKey != null
                  ? Form(key: formKey, child: child)
                  : child,
            ),
          ),

          // 3. Footer com Ações
          Container(
            padding: EdgeInsets.symmetric(horizontal: spacing.lg, vertical: spacing.md),
            decoration: BoxDecoration(
              color: colors.surfaceSecondary.withValues(alpha: 0.3),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(TFRadius.r16)),
              border: Border(top: BorderSide(color: colors.borderSubtle)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TFButton(
                  label: cancelLabel,
                  variant: TFButtonVariant.secondary,
                  onPressed: isSaving ? null : onCancel,
                ),
                SizedBox(width: spacing.sm),
                TFButton(
                  label: saveLabel,
                  variant: TFButtonVariant.primary,
                  loading: isSaving,
                  onPressed: isSaving ? null : onSave,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? spacing.sm : spacing.lg,
        vertical: spacing.lg,
      ),
      elevation: 0,
      child: dialogContent,
    );
  }
}
