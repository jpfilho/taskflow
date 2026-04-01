import 'package:flutter/material.dart';
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
    if (images.isEmpty && !isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhuma imagem encontrada',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
            ),
          ],
        ),
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = _getCrossAxisCount(context);
    final spacing = width < 600 ? 12.0 : (width < 1024 ? 16.0 : 24.0);

    return GridView.builder(
      controller: scrollController,
      padding: EdgeInsets.zero,
      addAutomaticKeepAlives: true,
      addRepaintBoundaries: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        childAspectRatio: width < 600 ? 0.82 : 0.85,
      ),
      itemCount: images.length + (hasMore && !isLoading ? 1 : 0) + (onAddNew != null && !hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        // Card de "Adicionar Nova Imagem" no final (apenas se não há mais para carregar)
        if (onAddNew != null && !hasMore && index == images.length) {
          return _buildAddNewCard(context, isDark, onAddNew!);
        }
        
        // Botão de carregar mais (apenas se há mais e não está carregando)
        if (hasMore && !isLoading && index == images.length) {
          return Center(
            child: ElevatedButton(
              onPressed: onLoadMore,
              child: const Text('Carregar mais'),
            ),
          );
        }
        
        // Indicador de carregamento
        if (isLoading && index == images.length) {
          return const Center(
            child: CircularProgressIndicator(),
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
  }

  Widget _buildAddNewCard(BuildContext context, bool isDark, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1e293b) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0),
              width: 2,
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFf8fafc),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add_photo_alternate,
                  size: 28,
                  color: isDark ? Colors.grey[400] : Colors.grey[500],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Carregar Nova Imagem',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0f172a),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'JPG, PNG ou WEBP',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[500] : Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1200) return 4;
    if (width >= 800) return 3;
    if (width >= 600) return 2;
    return 1;
  }
}
