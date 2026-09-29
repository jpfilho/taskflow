import 'package:flutter/material.dart';
import '../../components/buttons/tf_button.dart';
import '../../components/cards/tf_card.dart';
import '../../components/inputs/tf_text_field.dart';
import '../../components/layout/tf_page_header.dart';
import '../../foundations/tf_radius.dart';
import '../../theme/taskflow_theme_extension.dart';
import '../gallery_section.dart';

class ResponsiveSection extends StatelessWidget {
  const ResponsiveSection({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    final viewports = [
      ('Mobile Portrait', 360.0, 'Smartphones de campo'),
      ('Tablet Portrait', 768.0, 'Tablets de supervisão'),
      ('Desktop HD', 1024.0, 'Monitores padrão de escritório'),
    ];

    return GallerySection(
      title: 'Validação Responsiva',
      description: 'Simulação de componentes reais do TaskFlow sob diferentes larguras controladas de viewport.',
      children: [
        for (final (name, width, desc) in viewports) ...[
          GalleryPreviewCard(
            title: '$name (${width.toInt()}px)',
            description: desc,
            child: Center(
              child: Container(
                width: width,
                padding: EdgeInsets.all(spacing.base),
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: TFRadius.borderRadiusMd,
                  border: Border.all(color: colors.borderStrong),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TFPageHeader(
                      title: 'Ordem #400192',
                      subtitle: 'Subestação Sul',
                      primaryAction: TFButton(
                        label: 'Confirmar',
                        onPressed: () {},
                      ),
                    ),
                    SizedBox(height: spacing.sm),
                    TFCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Formulário Rápido', style: typography.cardTitle),
                          SizedBox(height: spacing.xs),
                          const TFTextField(
                            label: 'Horas Apontadas',
                            hint: 'Ex: 04:30',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
