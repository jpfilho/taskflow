import 'package:flutter/material.dart';
import '../../components/buttons/tf_button.dart';
import '../../components/buttons/tf_icon_button.dart';
import '../../components/inputs/tf_text_field.dart';
import '../../components/status/tf_status_badge.dart';
import '../../foundations/tf_density.dart';
import '../../foundations/tf_icons.dart';
import '../../foundations/tf_radius.dart';
import '../../theme/taskflow_theme_extension.dart';
import '../gallery_section.dart';

class DensityValidationSection extends StatelessWidget {
  const DensityValidationSection({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final spacing = context.tfSpacing;

    final modes = [
      (TFDensityMode.comfortable, 'Comfortable', 'Mobile e Telas de Toque (Controle 48px, Linha 48px)'),
      (TFDensityMode.compact, 'Compact', 'Desktop Padrão (Controle 40px, Linha 38px)'),
      (TFDensityMode.dense, 'Dense', 'Tabelas Operacionais & SAP (Controle 34px, Linha 30px)'),
    ];

    return GallerySection(
      title: 'Comparativo de Densidade',
      description: 'Avaliação comparativa dos 3 modos operacionais do TaskFlow Design System lado a lado.',
      children: [
        for (final (mode, title, desc) in modes) ...[
          GalleryPreviewCard(
            title: 'Modo $title',
            description: desc,
            child: _DensityOverrideContainer(
              mode: mode,
              child: Container(
                padding: EdgeInsets.all(spacing.base),
                decoration: BoxDecoration(
                  color: colors.surfaceSecondary,
                  borderRadius: TFRadius.borderRadiusMd,
                  border: Border.all(color: colors.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        TFButton(
                          label: 'Ação ($title)',
                          size: TFButtonSize.medium,
                          leadingIcon: TFIcons.save,
                          onPressed: () {},
                        ),
                        SizedBox(width: spacing.sm),
                        TFIconButton(
                          icon: TFIcons.refresh,
                          tooltip: 'Atualizar',
                          onPressed: () {},
                        ),
                        SizedBox(width: spacing.sm),
                        TFStatusBadge(
                          label: 'Status $title',
                          severity: TFStatusSeverity.info,
                          icon: TFIcons.sync,
                        ),
                      ],
                    ),
                    SizedBox(height: spacing.md),
                    const TFTextField(
                      label: 'Entrada de Dados',
                      hint: 'Exemplo de preenchimento calibrado por densidade',
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

class _DensityOverrideContainer extends StatelessWidget {
  final TFDensityMode mode;
  final Widget child;

  const _DensityOverrideContainer({
    required this.mode,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final currentTheme = Theme.of(context);
    final ext = currentTheme.extension<TaskFlowThemeExtension>();
    if (ext == null) return child;

    final targetDensity = switch (mode) {
      TFDensityMode.comfortable => TFDensity.comfortable(),
      TFDensityMode.compact => TFDensity.compact(),
      TFDensityMode.dense => TFDensity.dense(),
    };

    final newExt = ext.copyWith(density: targetDensity);
    final newThemeData = currentTheme.copyWith(
      extensions: [newExt],
    );

    return Theme(
      data: newThemeData,
      child: child,
    );
  }
}
