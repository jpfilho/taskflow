import 'package:flutter/material.dart';
import '../../components/buttons/tf_icon_button.dart';
import '../../foundations/tf_icons.dart';
import '../gallery_section.dart';

class IconButtonsSection extends StatelessWidget {
  const IconButtonsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return GallerySection(
      title: 'TFIconButton — Botões de Ícone',
      description: 'Botões compactos com tooltip obrigatório e garantia de touch target de pelo menos 40x40px.',
      children: [
        GalleryPreviewCard(
          title: 'Variantes de TFIconButton',
          description: 'standard, subtle, danger',
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TFIconButton(
                icon: TFIcons.edit,
                tooltip: 'Editar Atividade',
                variant: TFIconButtonVariant.standard,
                onPressed: () {},
              ),
              TFIconButton(
                icon: TFIcons.refresh,
                tooltip: 'Atualizar Dados',
                variant: TFIconButtonVariant.subtle,
                onPressed: () {},
              ),
              TFIconButton(
                icon: TFIcons.filter,
                tooltip: 'Filtrar Lista',
                variant: TFIconButtonVariant.subtle,
                onPressed: () {},
              ),
              TFIconButton(
                icon: TFIcons.delete,
                tooltip: 'Excluir Registro',
                variant: TFIconButtonVariant.danger,
                onPressed: () {},
              ),
              const TFIconButton(
                icon: TFIcons.settings,
                tooltip: 'Configurações (Desabilitado)',
                onPressed: null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
