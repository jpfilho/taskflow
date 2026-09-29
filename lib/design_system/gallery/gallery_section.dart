import 'package:flutter/material.dart';
import '../foundations/tf_radius.dart';
import '../theme/taskflow_theme_extension.dart';

/// Container padrão para apresentar uma seção dentro da Gallery.
class GallerySection extends StatelessWidget {
  final String title;
  final String description;
  final List<Widget> children;

  const GallerySection({
    super.key,
    required this.title,
    required this.description,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    return SingleChildScrollView(
      padding: EdgeInsets.all(spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: typography.pageTitle.copyWith(color: colors.textPrimary),
          ),
          SizedBox(height: spacing.xs),
          Text(
            description,
            style: typography.bodyMedium.copyWith(color: colors.textSecondary),
          ),
          SizedBox(height: spacing.xl),
          for (final child in children) ...[
            child,
            SizedBox(height: spacing.xl),
          ],
        ],
      ),
    );
  }
}

/// Container de preview com título de caso de uso e moldura visual padronizada.
class GalleryPreviewCard extends StatelessWidget {
  final String title;
  final String? description;
  final Widget child;

  const GalleryPreviewCard({
    super.key,
    required this.title,
    this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: TFRadius.borderRadiusMd,
        border: Border.all(color: colors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.all(spacing.base),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: typography.cardTitle.copyWith(color: colors.textPrimary),
                ),
                if (description != null) ...[
                  SizedBox(height: spacing.xxs),
                  Text(
                    description!,
                    style: typography.caption.copyWith(color: colors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          Divider(height: 1, color: colors.borderSubtle),
          Padding(
            padding: EdgeInsets.all(spacing.base),
            child: child,
          ),
        ],
      ),
    );
  }
}
