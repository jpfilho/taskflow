import 'package:flutter/material.dart';
import '../../components/cards/tf_card.dart';
import '../../theme/taskflow_theme_extension.dart';
import '../gallery_section.dart';

class OverviewSection extends StatelessWidget {
  const OverviewSection({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    return GallerySection(
      title: 'TaskFlow Design System — Visão Geral',
      description: 'Foundations, Tokens e Componentes Base homologados para a plataforma TaskFlow.',
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'Temas Suportados',
                value: '3',
                subtitle: 'Light, Dark e AXIA',
                color: colors.primary,
              ),
            ),
            SizedBox(width: spacing.md),
            Expanded(
              child: _MetricCard(
                title: 'Modos de Densidade',
                value: '3',
                subtitle: 'Comfortable, Compact, Dense',
                color: colors.info,
              ),
            ),
            SizedBox(width: spacing.md),
            Expanded(
              child: _MetricCard(
                title: 'Componentes Base',
                value: '9',
                subtitle: 'Buttons, Inputs, Cards, etc.',
                color: colors.success,
              ),
            ),
            SizedBox(width: spacing.md),
            Expanded(
              child: _MetricCard(
                title: 'Telas Migradas',
                value: '0',
                subtitle: 'Zero telas de produção alteradas',
                color: colors.warning,
              ),
            ),
          ],
        ),
        GalleryPreviewCard(
          title: 'Arquitetura de Consumo',
          description: 'Fluxo padronizado de resolução de estilo no Flutter',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ThemeProvider → ThemeService → ThemeData (M3) → TaskFlowThemeExtension → Semantic Tokens → TF Components',
                style: typography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.primary,
                ),
              ),
              SizedBox(height: spacing.sm),
              Text(
                'Os componentes consomem diretamente o BuildContext tipado sem saber qual tema está ativo. '
                'O código legado permanece 100% operacional sem quebras.',
                style: typography.bodyMedium.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    return TFCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: typography.caption.copyWith(color: colors.textSecondary),
          ),
          SizedBox(height: spacing.xs),
          Text(
            value,
            style: typography.display.copyWith(color: color),
          ),
          SizedBox(height: spacing.xxs),
          Text(
            subtitle,
            style: typography.micro.copyWith(color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}
