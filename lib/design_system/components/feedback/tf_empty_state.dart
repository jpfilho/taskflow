import 'package:flutter/material.dart';
import '../../theme/taskflow_theme_extension.dart';

/// Componente padronizado para telas e seções sem registros.
///
/// Funciona tanto embutido (inline) em tabelas ou painéis quanto em tela cheia (full page).
class TFEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;
  final bool fullPage;

  const TFEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.action,
    this.fullPage = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    Widget content = Padding(
      padding: EdgeInsets.all(fullPage ? spacing.xl : spacing.md),
      child: Center(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 56.0,
                height: 56.0,
                decoration: BoxDecoration(
                  color: colors.surfaceSecondary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 28.0,
                  color: colors.textSecondary,
                ),
              ),
              SizedBox(height: spacing.sm),
              Text(
                title,
                style: typography.sectionTitle.copyWith(
                  color: colors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              if (description != null && description!.isNotEmpty) ...[
                SizedBox(height: spacing.xs),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420.0),
                  child: Text(
                    description!,
                    style: typography.bodyMedium.copyWith(
                      color: colors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              if (action != null) ...[
                SizedBox(height: spacing.md),
                action!,
              ],
            ],
          ),
        ),
      ),
    );

    if (fullPage) {
      return Center(
        child: SingleChildScrollView(
          child: content,
        ),
      );
    }

    return Center(child: content);
  }
}
