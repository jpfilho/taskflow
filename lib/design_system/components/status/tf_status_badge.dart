import 'package:flutter/material.dart';
import '../../foundations/tf_radius.dart';
import '../../theme/taskflow_theme_extension.dart';

/// Níveis de severidade visual suportados pelo TaskFlow Design System.
/// Puramente visual: desacoplado de regras de negócio ou de domínio (SAP, tarefas, etc.).
enum TFStatusSeverity {
  neutral,
  info,
  success,
  warning,
  danger,
}

/// Componente padronizado para exibição de status operacionais.
///
/// Substitui as 34 implementações dispersas identificadas na auditoria.
/// Garante que o status nunca dependa exclusivamente de cor para transmitir informação (A11y),
/// combinando texto explícito, cor de fundo/borda e opcionalmente um ícone.
class TFStatusBadge extends StatelessWidget {
  final String label;
  final TFStatusSeverity severity;
  final Color? customColor;
  final IconData? icon;
  final bool compact;
  final String? tooltip;

  const TFStatusBadge({
    super.key,
    required this.label,
    this.severity = TFStatusSeverity.neutral,
    this.customColor,
    this.icon,
    this.compact = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    final (Color bg, Color fg, Color border) = customColor != null
        ? (
            customColor!.withValues(alpha: 0.15),
            customColor!,
            customColor!,
          )
        : switch (severity) {
            TFStatusSeverity.neutral => (
                colors.surfaceSecondary,
                colors.textSecondary,
                colors.borderDefault,
              ),
            TFStatusSeverity.info => (
                colors.infoBackground,
                colors.info,
                colors.info,
              ),
            TFStatusSeverity.success => (
                colors.successBackground,
                colors.success,
                colors.success,
              ),
            TFStatusSeverity.warning => (
                colors.warningBackground,
                colors.warning,
                colors.warning,
              ),
            TFStatusSeverity.danger => (
                colors.dangerBackground,
                colors.danger,
                colors.danger,
              ),
          };

    final textStyle = compact ? typography.micro : typography.labelSmall;
    final double iconSize = compact ? 12.0 : 14.0;
    final double hPadding = compact ? spacing.xs : spacing.sm;
    final double vPadding = compact ? spacing.xxs : spacing.xs;

    Widget badge = Container(
      padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: vPadding),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: TFRadius.borderRadiusXs,
        border: Border.all(color: border.withValues(alpha: 0.35), width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: fg),
            SizedBox(width: spacing.xs),
          ],
          Text(
            label,
            style: textStyle.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      badge = Tooltip(
        message: tooltip!,
        child: badge,
      );
    }

    return Semantics(
      label: 'Status: $label',
      child: badge,
    );
  }
}
