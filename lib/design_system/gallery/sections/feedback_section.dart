import 'package:flutter/material.dart';
import '../../components/buttons/tf_button.dart';
import '../../components/feedback/tf_empty_state.dart';
import '../../components/feedback/tf_loading.dart';
import '../../foundations/tf_icons.dart';
import '../../theme/taskflow_theme_extension.dart';
import '../gallery_section.dart';

class FeedbackSection extends StatelessWidget {
  const FeedbackSection({super.key});

  @override
  Widget build(BuildContext context) {
    final spacing = context.tfSpacing;

    return GallerySection(
      title: 'Feedback: Empty State & Loading',
      description: 'Padronização de respostas para telas sem dados e carregamento assíncrono.',
      children: [
        GalleryPreviewCard(
          title: 'TFEmptyState — Sem Registros',
          description: 'Apresentação amigável com ícone contextual e ação recomendada',
          child: TFEmptyState(
            icon: TFIcons.search,
            title: 'Nenhuma Ordem Localizada',
            description: 'Não existem registros correspondentes aos filtros aplicados nesta regional.',
            action: TFButton(
              label: 'Limpar Filtros',
              leadingIcon: TFIcons.filter,
              variant: TFButtonVariant.secondary,
              onPressed: () {},
            ),
          ),
        ),
        GalleryPreviewCard(
          title: 'TFLoading — Modos de Carregamento',
          description: 'inline, section, page',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Modo Inline: '),
                  SizedBox(width: spacing.sm),
                  const TFLoading(mode: TFLoadingMode.inline),
                ],
              ),
              SizedBox(height: spacing.lg),
              const TFLoading(
                mode: TFLoadingMode.section,
                message: 'Carregando atividades em campo...',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
