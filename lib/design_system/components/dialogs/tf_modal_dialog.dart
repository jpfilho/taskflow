import 'package:flutter/material.dart';
import '../../foundations/tf_breakpoints.dart';
import '../../foundations/tf_colors.dart';
import '../../foundations/tf_icons.dart';
import '../../foundations/tf_radius.dart';
import '../../theme/taskflow_theme_extension.dart';
import '../buttons/tf_button.dart';
import '../buttons/tf_icon_button.dart';

/// Tamanhos semânticos oficiais para modais e diálogos no TFDS.
enum TFDialogSize {
  /// Diálogos curtos de confirmação e alertas (máx 420px).
  small,

  /// Formulários padrões, edições e seleções (máx 580px).
  medium,

  /// Formulários extensos, tabelas ou visualizadores (máx 740px).
  large,
}

/// Níveis de severidade visual para modais.
enum TFDialogSeverity {
  standard,
  info,
  success,
  warning,
  danger,
}

/// Componente de diálogo modal oficial do TaskFlow Design System.
///
/// Substitui o uso disperso de `AlertDialog` e `Dialog` nativos.
/// Oferece estrutura padronizada com cabeçalho (título, subtítulo, ícone e botão fechar),
/// área de conteúdo responsiva com rolagem automática e barra inferior de ações.
class TFModalDialog extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final TFDialogSeverity severity;
  final TFDialogSize size;
  final Widget content;
  final Widget? primaryAction;
  final Widget? secondaryAction;
  final bool showCloseButton;
  final VoidCallback? onClose;

  const TFModalDialog({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.severity = TFDialogSeverity.standard,
    this.size = TFDialogSize.medium,
    required this.content,
    this.primaryAction,
    this.secondaryAction,
    this.showCloseButton = true,
    this.onClose,
  });

  /// Exibe o diálogo modal usando a infraestrutura do Navigator.
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    String? subtitle,
    IconData? icon,
    TFDialogSeverity severity = TFDialogSeverity.standard,
    TFDialogSize size = TFDialogSize.medium,
    required Widget content,
    Widget? primaryAction,
    Widget? secondaryAction,
    bool showCloseButton = true,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (dialogContext) => TFModalDialog(
        title: title,
        subtitle: subtitle,
        icon: icon,
        severity: severity,
        size: size,
        content: content,
        primaryAction: primaryAction,
        secondaryAction: secondaryAction,
        showCloseButton: showCloseButton,
        onClose: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  /// Atalho de conveniência padronizado para diálogos de confirmação/exclusão.
  static Future<bool> confirm({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Confirmar',
    String cancelLabel = 'Cancelar',
    bool isDestructive = false,
    IconData? icon,
  }) async {
    final result = await show<bool>(
      context: context,
      title: title,
      icon: icon ?? (isDestructive ? TFIcons.delete : TFIcons.warning),
      severity: isDestructive ? TFDialogSeverity.danger : TFDialogSeverity.warning,
      size: TFDialogSize.small,
      content: Text(message),
      primaryAction: TFButton(
        label: confirmLabel,
        variant: isDestructive ? TFButtonVariant.danger : TFButtonVariant.primary,
        onPressed: () => Navigator.of(context).pop(true),
      ),
      secondaryAction: TFButton(
        label: cancelLabel,
        variant: TFButtonVariant.ghost,
        onPressed: () => Navigator.of(context).pop(false),
      ),
    );
    return result ?? false;
  }

  double _getMaxWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = TFBreakpoints.isMobile(context);

    if (isMobile) {
      return screenWidth * 0.94;
    }

    switch (size) {
      case TFDialogSize.small:
        return 420.0;
      case TFDialogSize.medium:
        return 580.0;
      case TFDialogSize.large:
        return 740.0;
    }
  }

  Color _getHeaderIconColor(TFSemanticColors colors) {
    switch (severity) {
      case TFDialogSeverity.danger:
        return colors.danger;
      case TFDialogSeverity.warning:
        return colors.warning;
      case TFDialogSeverity.success:
        return colors.success;
      case TFDialogSeverity.info:
        return colors.info;
      case TFDialogSeverity.standard:
        return colors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;
    final isMobile = TFBreakpoints.isMobile(context);

    final maxWidth = _getMaxWidth(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? spacing.sm : spacing.lg,
        vertical: spacing.lg,
      ),
      elevation: 0,
      child: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: TFRadius.borderRadiusLg,
            border: Border.all(color: colors.borderDefault, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Cabeçalho
              Padding(
                padding: EdgeInsets.fromLTRB(spacing.lg, spacing.lg, spacing.md, spacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (icon != null) ...[
                      Container(
                        padding: EdgeInsets.all(spacing.xs),
                        decoration: BoxDecoration(
                          color: _getHeaderIconColor(colors).withValues(alpha: 0.12),
                          borderRadius: TFRadius.borderRadiusMd,
                        ),
                        child: Icon(
                          icon,
                          size: 24,
                          color: _getHeaderIconColor(colors),
                        ),
                      ),
                      SizedBox(width: spacing.md),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: typography.sectionTitle.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (subtitle != null) ...[
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
                    if (showCloseButton)
                      TFIconButton(
                        icon: TFIcons.close,
                        tooltip: 'Fechar',
                        variant: TFIconButtonVariant.subtle,
                        onPressed: onClose ?? () => Navigator.of(context).pop(),
                      ),
                  ],
                ),
              ),

              Divider(height: 1, thickness: 1, color: colors.borderSubtle),

              // 2. Área de Conteúdo
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(spacing.lg),
                  child: DefaultTextStyle(
                    style: typography.bodyMedium.copyWith(color: colors.textPrimary),
                    child: content,
                  ),
                ),
              ),

              // 3. Barra de Ações Inferior (se houver ações)
              if (primaryAction != null || secondaryAction != null) ...[
                Divider(height: 1, thickness: 1, color: colors.borderSubtle),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: spacing.lg, vertical: spacing.md),
                  color: colors.surfaceSecondary.withValues(alpha: 0.4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (secondaryAction != null) ...[
                        secondaryAction!,
                        SizedBox(width: spacing.sm),
                      ],
                      if (primaryAction != null) primaryAction!,
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
