import 'package:flutter/material.dart';
import '../../foundations/tf_radius.dart';
import '../../theme/taskflow_theme_extension.dart';
import '../gallery_section.dart';

class SpacingSection extends StatelessWidget {
  const SpacingSection({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    final scales = [
      ('xxs', 2.0, spacing.xxs),
      ('xs', 4.0, spacing.xs),
      ('sm', 8.0, spacing.sm),
      ('md', 12.0, spacing.md),
      ('base / lg', 16.0, spacing.base),
      ('xl', 20.0, spacing.xl),
      ('xxl', 24.0, spacing.xxl),
      ('xxxl', 32.0, spacing.xxxl),
      ('huge', 48.0, spacing.huge),
    ];

    return GallerySection(
      title: 'Espaçamentos & Grid',
      description: 'Escala geométrica baseada em múltiplos de 4px para eliminação de magic numbers.',
      children: [
        GalleryPreviewCard(
          title: 'Escala Oficial de TFSpacing',
          description: 'Representação visual da proporção e distância dos tokens',
          child: Column(
            children: [
              for (final (name, px, val) in scales) ...[
                Padding(
                  padding: EdgeInsets.symmetric(vertical: spacing.xs),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 100.0,
                        child: Text(
                          '$name (${px.toInt()}px)',
                          style: typography.labelSmall.copyWith(color: colors.textPrimary),
                        ),
                      ),
                      Container(
                        height: 20.0,
                        width: val * 4.0,
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.7),
                          borderRadius: TFRadius.borderRadiusXs,
                        ),
                      ),
                      SizedBox(width: spacing.sm),
                      Text(
                        '${val.toInt()}px',
                        style: typography.caption.copyWith(color: colors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
