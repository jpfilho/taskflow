import 'package:flutter/material.dart';
import '../../data/models/media_image.dart';
import 'media_card.dart';

class AlbumGroupList extends StatelessWidget {
  final Map<String, List<MediaImage>> groupedImages;
  final Function(MediaImage) onImageTap;
  final Function(MediaImage)? onImageDelete;
  final ScrollController? scrollController;
  final VoidCallback? onLoadMore;
  final bool hasMore;
  final bool isLoading;

  const AlbumGroupList({
    super.key,
    required this.groupedImages,
    required this.onImageTap,
    this.onImageDelete,
    this.scrollController,
    this.onLoadMore,
    this.hasMore = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (groupedImages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum álbum encontrado',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
            ),
          ],
        ),
      );
    }

    final padding = MediaQuery.of(context).size.width < 600 ? 12.0 : 16.0;
    final itemCount = groupedImages.length + (hasMore || isLoading ? 1 : 0);
    return ListView.builder(
      controller: scrollController,
      padding: EdgeInsets.all(padding),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index >= groupedImages.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      height: 40,
                      width: 40,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : hasMore && onLoadMore != null
                      ? TextButton.icon(
                          onPressed: onLoadMore,
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('Carregar mais'),
                        )
                      : const SizedBox.shrink(),
            ),
          );
        }
        final entry = groupedImages.entries.elementAt(index);
        final groupName = entry.key;
        final images = entry.value;
        return _buildGroupSection(context, groupName, images);
      },
    );
  }

  Widget _buildGroupSection(
    BuildContext context,
    String groupName,
    List<MediaImage> images,
  ) {
    final theme = Theme.of(context);
    // Subagrupamento por sala
    final byRoom = <String, List<MediaImage>>{};
    for (final img in images) {
      final roomKey = (img.roomName != null && img.roomName!.trim().isNotEmpty)
          ? img.roomName!
          : 'Sem sala';
      byRoom.putIfAbsent(roomKey, () => []);
      byRoom[roomKey]!.add(img);
    }
    final roomKeys = byRoom.keys.toList()..sort((a, b) => a.compareTo(b));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabeçalho do grupo
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Icon(
                Icons.folder,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                groupName,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${images.length}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Subgrupos por sala
        ...roomKeys.map((roomName) {
          final imgs = byRoom[roomName]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
                child: Row(
                  children: [
                    Icon(Icons.meeting_room, size: 18, color: theme.colorScheme.secondary),
                    const SizedBox(width: 6),
                    Text(
                      roomName,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${imgs.length}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _getCrossAxisCount(context),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.75,
                ),
                itemCount: imgs.length,
                itemBuilder: (context, index) {
                  final image = imgs[index];
                  return MediaCard(
                    image: image,
                    onTap: () => onImageTap(image),
                    onDelete: onImageDelete != null
                        ? () => onImageDelete!(image)
                        : null,
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          );
        }),
        const SizedBox(height: 32),
      ],
    );
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 4;
    if (width > 800) return 3;
    if (width > 600) return 2;
    return 1;
  }
}
