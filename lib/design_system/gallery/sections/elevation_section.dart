import 'package:flutter/material.dart';
import '../../foundations/tf_radius.dart';
import '../../theme/taskflow_theme_extension.dart';
import '../gallery_section.dart';

class ElevationSection extends StatelessWidget {
  const ElevationSection({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final elevation = context.tfElevation;

    return GallerySection(
      title: 'Elevação & Sombras',
      description: 'A diretriz do TaskFlow prioriza flat + border para densidade e alta legibilidade em dados operacionais.',
      children: [
        GalleryPreviewCard(
          title: 'Níveis Oficiais de Elevação',
          description: 'Comparativo entre flat, raised e overlay',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ElevationBox(
                title: 'Flat (0)',
                desc: 'Padrão TaskFlow (flat + border). Tabelas, cards de lista e inputs.',
                shadows: elevation.flat,
                border: Border.all(color: colors.borderDefault),
              ),
              _ElevationBox(
                title: 'Raised (2)',
                desc: 'Cards interativos em hover, toolbars secundárias e popovers.',
                shadows: elevation.raised,
                border: Border.all(color: colors.borderSubtle),
              ),
              _ElevationBox(
                title: 'Overlay (4)',
                desc: 'Diálogos modais, menus suspensos e painéis flutuantes.',
                shadows: elevation.overlay,
                border: null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ElevationBox extends StatelessWidget {
  final String title;
  final String desc;
  final List<BoxShadow> shadows;
  final Border? border;

  const _ElevationBox({
    required this.title,
    required this.desc,
    required this.shadows,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    return Container(
      width: 200.0,
      padding: EdgeInsets.all(spacing.base),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: TFRadius.borderRadiusMd,
        border: border,
        boxShadow: shadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: typography.cardTitle.copyWith(color: colors.primary),
          ),
          SizedBox(height: spacing.xs),
          Text(
            desc,
            style: typography.caption.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
