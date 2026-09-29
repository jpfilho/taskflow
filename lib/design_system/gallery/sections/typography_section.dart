import 'package:flutter/material.dart';
import '../../theme/taskflow_theme_extension.dart';
import '../gallery_section.dart';

class TypographySection extends StatelessWidget {
  const TypographySection({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    final styles = [
      ('display', '28px / Bold', typography.display, 'Programação de Linhas 230kV'),
      ('pageTitle', '22px / SemiBold', typography.pageTitle, 'Ordens de Manutenção Prioritárias'),
      ('sectionTitle', '16px / SemiBold', typography.sectionTitle, 'Equipes em Campo — Regional Teresina'),
      ('cardTitle', '14px / SemiBold', typography.cardTitle, 'SE Teresina II — Vão 04E2'),
      ('bodyLarge', '14px / Regular', typography.bodyLarge, 'Abertura de chamada técnica para verificação de isoladores em cadeia de suspensão.'),
      ('bodyMedium', '13px / Regular', typography.bodyMedium, 'Texto padrão de interface, filtros rápidos e detalhes de atividades.'),
      ('bodySmall', '12px / Regular', typography.bodySmall, 'Células de tabelas densas, notas SAP e contadores de prazo.'),
      ('labelLarge', '14px / SemiBold', typography.labelLarge, 'Salvar e Confirmar'),
      ('labelMedium', '12px / SemiBold', typography.labelMedium, 'Filtrar por Status'),
      ('labelSmall', '11px / Medium', typography.labelSmall, 'PRIORIDADE 1'),
      ('caption', '11px / Regular', typography.caption, 'Atualizado há 5 minutos via SQLite Offline'),
      ('micro', '10px / Bold', typography.micro, 'SAP 1048291 • D-2 DIAS'),
    ];

    return GallerySection(
      title: 'Tipografia & Escala Formal',
      description: 'Hierarquia de texto projetada para densidade de dados operacionais e números tabulares.',
      children: [
        GalleryPreviewCard(
          title: 'Escala Tipográfica Oficial',
          description: '12 níveis com font-weight, line-height e letter-spacing padronizados',
          child: Column(
            children: [
              for (final (name, spec, style, sample) in styles) ...[
                Padding(
                  padding: EdgeInsets.symmetric(vertical: spacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 140.0,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: typography.labelMedium.copyWith(color: colors.primary)),
                            Text(spec, style: typography.micro.copyWith(color: colors.textMuted)),
                          ],
                        ),
                      ),
                      SizedBox(width: spacing.md),
                      Expanded(
                        child: Text(
                          sample,
                          style: style.copyWith(color: colors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: colors.borderSubtle),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
