import 'package:flutter/material.dart';
import '../../components/cards/tf_card.dart';
import '../../components/status/tf_status_badge.dart';
import '../../foundations/tf_icons.dart';
import '../../theme/taskflow_theme_extension.dart';
import '../gallery_section.dart';

class CardsSection extends StatelessWidget {
  const CardsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    return GallerySection(
      title: 'TFCard — Superfícies Padronizadas',
      description: 'Superfícies de agrupamento baseadas na diretriz flat + border com variantes para dados operacionais.',
      children: [
        GalleryPreviewCard(
          title: 'Variantes de TFCard',
          description: 'defaultCard, interactive, highlighted',
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(
                width: 280.0,
                child: TFCard(
                  variant: TFCardVariant.defaultCard,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text('Nota 40019284', style: TextStyle(fontWeight: FontWeight.bold)),
                          TFStatusBadge(label: 'Pendente', severity: TFStatusSeverity.warning),
                        ],
                      ),
                      SizedBox(height: spacing.sm),
                      Text(
                        'Substituição de mufla terminal em cabo subterrâneo 69kV.',
                        style: typography.bodySmall.copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 280.0,
                child: TFCard(
                  variant: TFCardVariant.interactive,
                  onTap: () {},
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text('Card Interativo', style: TextStyle(fontWeight: FontWeight.bold)),
                          Icon(TFIcons.chevronRight, size: 16),
                        ],
                      ),
                      SizedBox(height: spacing.sm),
                      Text(
                        'Passe o mouse para ver a borda reforçada e clique para navegar.',
                        style: typography.bodySmall.copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 280.0,
                child: TFCard(
                  variant: TFCardVariant.highlighted,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text('Atividade Prioritária', style: TextStyle(fontWeight: FontWeight.bold)),
                          TFStatusBadge(label: 'Crítico', severity: TFStatusSeverity.danger),
                        ],
                      ),
                      SizedBox(height: spacing.sm),
                      Text(
                        'Variante destacada com elevação suave e borda primária ativa.',
                        style: typography.bodySmall.copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
