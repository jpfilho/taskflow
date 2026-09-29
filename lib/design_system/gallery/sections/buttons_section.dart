import 'package:flutter/material.dart';
import '../../components/buttons/tf_button.dart';
import '../../foundations/tf_icons.dart';
import '../../theme/taskflow_theme_extension.dart';
import '../gallery_section.dart';

class ButtonsSection extends StatelessWidget {
  const ButtonsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final spacing = context.tfSpacing;

    return GallerySection(
      title: 'TFButton — Botões de Ação',
      description: 'Componente oficial de ação primária, secundária, terciária e crítica com suporte nativo a loading.',
      children: [
        GalleryPreviewCard(
          title: 'Variantes Visuais',
          description: 'primary, secondary, tertiary, danger, ghost',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TFButton(
                label: 'Primary',
                variant: TFButtonVariant.primary,
                leadingIcon: TFIcons.save,
                onPressed: () {},
              ),
              TFButton(
                label: 'Secondary',
                variant: TFButtonVariant.secondary,
                leadingIcon: TFIcons.filter,
                onPressed: () {},
              ),
              TFButton(
                label: 'Tertiary',
                variant: TFButtonVariant.tertiary,
                onPressed: () {},
              ),
              TFButton(
                label: 'Danger',
                variant: TFButtonVariant.danger,
                leadingIcon: TFIcons.delete,
                onPressed: () {},
              ),
              TFButton(
                label: 'Ghost',
                variant: TFButtonVariant.ghost,
                onPressed: () {},
              ),
            ],
          ),
        ),
        GalleryPreviewCard(
          title: 'Escala de Tamanhos',
          description: 'small, medium, large',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TFButton(
                label: 'Small (32px)',
                size: TFButtonSize.small,
                leadingIcon: TFIcons.add,
                onPressed: () {},
              ),
              TFButton(
                label: 'Medium (40px)',
                size: TFButtonSize.medium,
                leadingIcon: TFIcons.add,
                onPressed: () {},
              ),
              TFButton(
                label: 'Large (48px)',
                size: TFButtonSize.large,
                leadingIcon: TFIcons.add,
                onPressed: () {},
              ),
            ],
          ),
        ),
        GalleryPreviewCard(
          title: 'Estados de Interação',
          description: 'enabled, disabled, loading, fullWidth',
          child: Column(
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TFButton(
                    label: 'Ativo',
                    onPressed: () {},
                  ),
                  const TFButton(
                    label: 'Desabilitado',
                    onPressed: null,
                  ),
                  TFButton(
                    label: 'Processando...',
                    loading: true,
                    onPressed: () {},
                  ),
                  TFButton(
                    label: 'Com Ícone Final',
                    trailingIcon: TFIcons.chevronRight,
                    onPressed: () {},
                  ),
                ],
              ),
              SizedBox(height: spacing.md),
              TFButton(
                label: 'Botão Largura Completa (fullWidth: true)',
                fullWidth: true,
                leadingIcon: TFIcons.save,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ],
    );
  }
}
