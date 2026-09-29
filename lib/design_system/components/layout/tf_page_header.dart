import 'package:flutter/material.dart';
import '../../foundations/tf_breakpoints.dart';
import '../../theme/taskflow_theme_extension.dart';
import '../buttons/tf_icon_button.dart';

/// Cabeçalho oficial de página do TaskFlow Design System.
///
/// Padroniza o topo de todas as visões do sistema.
/// Adapta-se automaticamente a telas Desktop/Tablet (em linha) e Mobile (em coluna com ações empilhadas).
class TFPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? breadcrumb;
  final VoidCallback? onBack;
  final Widget? leading;
  final Widget? primaryAction;
  final List<Widget>? secondaryActions;

  const TFPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.breadcrumb,
    this.onBack,
    this.leading,
    this.primaryAction,
    this.secondaryActions,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;
    final isMobile = TFBreakpoints.isMobile(context);

    Widget? backButton = leading;
    if (backButton == null && onBack != null) {
      backButton = TFIconButton(
        icon: Icons.arrow_back_rounded,
        tooltip: 'Voltar',
        variant: TFIconButtonVariant.subtle,
        onPressed: onBack,
      );
    }

    Widget titleContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: typography.pageTitle.copyWith(
            color: colors.textPrimary,
          ),
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          SizedBox(height: spacing.xxs),
          Text(
            subtitle!,
            style: typography.bodyMedium.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ],
    );

    Widget titleRow = backButton != null
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              backButton,
              SizedBox(width: spacing.sm),
              Expanded(child: titleContent),
            ],
          )
        : titleContent;

    Widget titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (breadcrumb != null) ...[
          breadcrumb!,
          SizedBox(height: spacing.xs),
        ],
        titleRow,
      ],
    );

    final hasActions = primaryAction != null || (secondaryActions != null && secondaryActions!.isNotEmpty);

    Widget actionsBlock = Row(
      mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: isMobile ? MainAxisAlignment.start : MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (secondaryActions != null) ...[
          for (final action in secondaryActions!) ...[
            action,
            SizedBox(width: spacing.sm),
          ],
        ],
        if (primaryAction != null) ...[
          if (isMobile) Expanded(child: primaryAction!) else primaryAction!,
        ],
      ],
    );

    if (isMobile) {
      return Padding(
        padding: EdgeInsets.only(bottom: spacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            titleBlock,
            if (hasActions) ...[
              SizedBox(height: spacing.md),
              actionsBlock,
            ],
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: spacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: titleBlock),
          if (hasActions) ...[
            SizedBox(width: spacing.base),
            actionsBlock,
          ],
        ],
      ),
    );
  }
}
