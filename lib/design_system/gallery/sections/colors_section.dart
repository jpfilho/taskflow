import 'package:flutter/material.dart';
import '../../foundations/tf_radius.dart';
import '../../theme/taskflow_theme_extension.dart';
import '../gallery_section.dart';

class ColorsSection extends StatelessWidget {
  const ColorsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;

    return GallerySection(
      title: 'Cores & Tokens Semânticos',
      description: 'Paleta semântica ativa adaptando-se em tempo real entre os temas Light, Dark e Axia.',
      children: [
        GalleryPreviewCard(
          title: 'Ação Primária & Marca',
          description: 'Cores para botões primários, links e elementos interativos principais',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ColorSwatch(name: 'primary', color: colors.primary, role: 'Ação principal'),
              _ColorSwatch(name: 'primaryHover', color: colors.primaryHover, role: 'Hover de ação'),
              _ColorSwatch(name: 'primaryPressed', color: colors.primaryPressed, role: 'Pressionado'),
              _ColorSwatch(name: 'primaryForeground', color: colors.primaryForeground, role: 'Texto sobre primary'),
            ],
          ),
        ),
        GalleryPreviewCard(
          title: 'Superfícies & Fundos',
          description: 'Camadas de elevação e separação estrutural de telas operacionais',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ColorSwatch(name: 'background', color: colors.background, role: 'Fundo do Scaffold'),
              _ColorSwatch(name: 'surface', color: colors.surface, role: 'Cards e tabelas'),
              _ColorSwatch(name: 'surfaceSecondary', color: colors.surfaceSecondary, role: 'Inputs e listras zebra'),
              _ColorSwatch(name: 'surfaceElevated', color: colors.surfaceElevated, role: 'Modais e popovers'),
            ],
          ),
        ),
        GalleryPreviewCard(
          title: 'Tipografia & Textos',
          description: 'Hierarquia de leitura e contraste acessível (WCAG AA)',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ColorSwatch(name: 'textPrimary', color: colors.textPrimary, role: 'Títulos e corpo principal'),
              _ColorSwatch(name: 'textSecondary', color: colors.textSecondary, role: 'Subtítulos e labels'),
              _ColorSwatch(name: 'textMuted', color: colors.textMuted, role: 'Placeholders e desabilitados'),
              _ColorSwatch(name: 'textDisabled', color: colors.textDisabled, role: 'Controles inativos'),
            ],
          ),
        ),
        GalleryPreviewCard(
          title: 'Bordas & Linhas',
          description: 'Essencial para a estratégia flat + border do TaskFlow',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ColorSwatch(name: 'borderSubtle', color: colors.borderSubtle, role: 'Divisores e linhas leves'),
              _ColorSwatch(name: 'borderDefault', color: colors.borderDefault, role: 'Borda padrão de cards/inputs'),
              _ColorSwatch(name: 'borderStrong', color: colors.borderStrong, role: 'Hover e ênfase'),
              _ColorSwatch(name: 'borderFocus', color: colors.borderFocus, role: 'Anel de foco acessível'),
            ],
          ),
        ),
        GalleryPreviewCard(
          title: 'Severidade & Feedback Operacional',
          description: 'Cores de status para sucesso, alerta, perigo e informação',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ColorSwatch(name: 'success', color: colors.success, role: 'Concluído / OK'),
              _ColorSwatch(name: 'warning', color: colors.warning, role: 'Atenção / Prazo próximo'),
              _ColorSwatch(name: 'danger', color: colors.danger, role: 'Crítico / Cancelado / Atraso'),
              _ColorSwatch(name: 'info', color: colors.info, role: 'Em execução / Informativo'),
            ],
          ),
        ),
      ],
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final String name;
  final Color color;
  final String role;

  const _ColorSwatch({
    required this.name,
    required this.color,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    final hex = '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

    return Container(
      width: 170.0,
      padding: EdgeInsets.all(spacing.sm),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: TFRadius.borderRadiusSm,
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 48.0,
            decoration: BoxDecoration(
              color: color,
              borderRadius: TFRadius.borderRadiusXs,
              border: Border.all(color: colors.borderDefault.withValues(alpha: 0.2)),
            ),
          ),
          SizedBox(height: spacing.xs),
          Text(
            name,
            style: typography.labelSmall.copyWith(color: colors.textPrimary),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            hex,
            style: typography.micro.copyWith(color: colors.textMuted),
          ),
          SizedBox(height: spacing.xxs),
          Text(
            role,
            style: typography.caption.copyWith(color: colors.textSecondary, fontSize: 10),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
