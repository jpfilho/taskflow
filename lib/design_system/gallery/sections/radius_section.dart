import 'package:flutter/material.dart';
import '../../theme/taskflow_theme_extension.dart';
import '../gallery_section.dart';

class RadiusSection extends StatelessWidget {
  const RadiusSection({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;
    final radius = context.tfRadius;

    final radii = [
      ('none', 0.0, radius.borderNone, 'Superfícies retas e cabeçalhos'),
      ('xs', 4.0, radius.borderXs, 'Tags, micro badges e chips'),
      ('sm', 8.0, radius.borderSm, 'Padrão do sistema: botões, inputs, cards compactos'),
      ('md', 12.0, radius.borderMd, 'Cards padrão, painéis de tarefas'),
      ('lg', 16.0, radius.borderLg, 'Diálogos modais e formulários suspensos'),
      ('full', 999.0, radius.borderFull, 'Pílulas de status, avatares e contadores'),
    ];

    return GallerySection(
      title: 'Raios de Curvatura (TFRadius)',
      description: 'Valores padronizados para uniformidade estética em todas as superfícies.',
      children: [
        GalleryPreviewCard(
          title: 'Escala de Arredondamento',
          description: 'Amostras de raio com borda sutil em evidência',
          child: Wrap(
            spacing: 20,
            runSpacing: 20,
            children: [
              for (final (name, px, bRadius, desc) in radii) ...[
                Container(
                  width: 140.0,
                  padding: EdgeInsets.all(spacing.sm),
                  decoration: BoxDecoration(
                    color: colors.surfaceSecondary,
                    borderRadius: bRadius,
                    border: Border.all(color: colors.primary, width: 1.5),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: typography.labelMedium.copyWith(color: colors.primary),
                      ),
                      Text(
                        '${px.toInt()}px',
                        style: typography.micro.copyWith(color: colors.textMuted),
                      ),
                      SizedBox(height: spacing.xs),
                      Text(
                        desc,
                        style: typography.caption.copyWith(color: colors.textSecondary, fontSize: 10),
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
