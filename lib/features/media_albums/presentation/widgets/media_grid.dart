import 'package:flutter/material.dart';
import '../../../../design_system/components/buttons/tf_button.dart';
import '../../../../design_system/components/feedback/tf_empty_state.dart';
import '../../../../design_system/components/feedback/tf_loading.dart';
import '../../../../design_system/foundations/tf_breakpoints.dart';
import '../../../../design_system/foundations/tf_icons.dart';
import '../../../../design_system/foundations/tf_radius.dart';
import '../../../../design_system/theme/taskflow_theme_extension.dart';
import '../../data/models/media_image.dart';
import 'media_card.dart';

class MediaGrid extends StatelessWidget {
  final List<MediaImage> images;
  final Function(MediaImage) onImageTap;
  final Function(MediaImage)? onImageDelete;
  final VoidCallback? onLoadMore;
  final VoidCallback? onAddNew;
  final bool isLoading;
  final bool hasMore;
  final ScrollController? scrollController;

  const MediaGrid({
    super.key,
    required this.images,
    required this.onImageTap,
    this.onImageDelete,
    this.onLoadMore,
    this.onAddNew,
    this.isLoading = false,
    this.hasMore = false,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = context.tfSpacing;

    if (images.isEmpty && !isLoading) {
      return Center(
        child: TFEmptyState(
          title: 'Nenhuma imagem encontrada',
          description: 'Não foram encontradas fotos com os filtros aplicados.',
          icon: Icons.photo_library_outlined,
          action: onAddNew != null
              ? TFButton(
                  label: 'Nova Imagem',
                  leadingIcon: TFIcons.add,
                  onPressed: onAddNew,
                )
              : null,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = _getCrossAxisCount(width);
        final gridSpacing = width < TFBreakpoints.sm ? spacing.sm : spacing.md;

        return GridView.builder(
          controller: scrollController,
          padding: EdgeInsets.zero,
          addAutomaticKeepAlives: true,
          addRepaintBoundaries: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: gridSpacing,
            mainAxisSpacing: gridSpacing,
            childAspectRatio: width < TFBreakpoints.sm ? 0.82 : 0.88,
          ),
          itemCount: images.length + (hasMore && !isLoading ? 1 : 0) + (onAddNew != null && !hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            // Card de "Adicionar Nova Imagem" no final (se aplicável)
            if (onAddNew != null && !hasMore && index == images.length) {
              return _buildAddNewCard(context, onAddNew!);
            }

            // Botão de carregar mais
            if (hasMore && !isLoading && index == images.length) {
              return Center(
                child: TFButton(
                  label: 'Carregar mais',
                  variant: TFButtonVariant.secondary,
                  leadingIcon: Icons.expand_more_rounded,
                  onPressed: onLoadMore,
                ),
              );
            }

            // Indicador de carregamento
            if (isLoading && index == images.length) {
              return const Center(
                child: TFLoading(message: 'Carregando fotos...'),
              );
            }

            final image = images[index];
            return MediaCard(
              image: image,
              onTap: () => onImageTap(image),
              onDelete: onImageDelete != null
                  ? () => onImageDelete!(image)
                  : null,
            );
          },
        );
      },
    );
  }

  Widget _buildAddNewCard(BuildContext context, VoidCallback onTap) {
    final colors = context.tfColors;
    final spacing = context.tfSpacing;
    final typography = context.tfTypography;

    return InkWell(
      onTap: onTap,
      borderRadius: TFRadius.borderRadiusMd,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: TFRadius.borderRadiusMd,
          border: Border.all(
            color: colors.primary.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_photo_alternate_rounded,
                size: 26,
                color: colors.primary,
              ),
            ),
            SizedBox(height: spacing.sm),
            Text(
              'Carregar Nova Imagem',
              style: typography.cardTitle.copyWith(color: colors.textPrimary),
            ),
            SizedBox(height: spacing.xxs),
            Text(
              'JPG, PNG ou WEBP',
              style: typography.caption.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  int _getCrossAxisCount(double width) {
    if (width >= TFBreakpoints.lg) return 4;
    if (width >= TFBreakpoints.md) return 3;
    if (width >= TFBreakpoints.sm) return 2;
    return 1;
  }
}
