import 'package:flutter/material.dart';
import '../../data/models/media_image.dart';
import 'media_card.dart';

class AlbumGroupList extends StatefulWidget {
  final Map<String, List<MediaImage>> groupedImages;
  final Function(MediaImage) onImageTap;
  final Function(MediaImage)? onImageDelete;
  final ScrollController? scrollController;
  final VoidCallback? onLoadMore;
  final Function(String dummyId)? onLoadRoomImages;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingRoom;

  const AlbumGroupList({
    super.key,
    required this.groupedImages,
    required this.onImageTap,
    this.onImageDelete,
    this.scrollController,
    this.onLoadMore,
    this.onLoadRoomImages,
    this.hasMore = false,
    this.isLoading = false,
    this.isLoadingRoom = false,
  });

  @override
  State<AlbumGroupList> createState() => _AlbumGroupListState();
}

class _AlbumGroupListState extends State<AlbumGroupList> {
  // Mapa de estado de expansão: chave = "grupo/sala", valor = true/false
  final Map<String, bool> _expandedGroups = {};
  final Map<String, bool> _expandedRooms = {};
  // Salas cujo lazy load já foi disparado
  final Set<String> _lazyLoadTriggered = {};

  int _getServerCount(List<MediaImage> imgs) {
    return imgs
        .where((img) =>
            img.id.startsWith('dummy|') || img.id.startsWith('dummy_'))
        .fold<int>(0, (sum, img) {
      if (img.id.startsWith('dummy|')) {
        final parts = img.id.split('|');
        if (parts.length >= 3) return sum + (int.tryParse(parts[2]) ?? 0);
      } else {
        final m = RegExp(r'^dummy_(?:root_)?(\d+)').firstMatch(img.id);
        if (m != null) return sum + int.parse(m.group(1)!);
      }
      return sum;
    });
  }

  int _getDisplayCount(List<MediaImage> imgs) {
    final loadedCount = imgs
        .where((img) =>
            !img.id.startsWith('dummy_') && !img.id.startsWith('dummy|'))
        .length;
    final serverCount = _getServerCount(imgs);
    return loadedCount > serverCount ? loadedCount : serverCount;
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 4;
    if (width > 800) return 3;
    if (width > 600) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.groupedImages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_outlined, size: 64,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text('Nenhum álbum encontrado',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
          ],
        ),
      );
    }

    final padding = MediaQuery.of(context).size.width < 600 ? 12.0 : 16.0;
    final itemCount =
        widget.groupedImages.length + (widget.hasMore || widget.isLoading ? 1 : 0);

    return ListView.builder(
      controller: widget.scrollController,
      padding: EdgeInsets.all(padding),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index >= widget.groupedImages.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: widget.isLoading
                  ? const SizedBox(
                      height: 40, width: 40,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : widget.hasMore && widget.onLoadMore != null
                      ? TextButton.icon(
                          onPressed: widget.onLoadMore,
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('Carregar mais'))
                      : const SizedBox.shrink(),
            ),
          );
        }
        final entry = widget.groupedImages.entries.elementAt(index);
        return _buildGroupSection(context, entry.key, entry.value);
      },
    );
  }

  Widget _buildGroupSection(
      BuildContext context, String groupName, List<MediaImage> images) {
    final theme = Theme.of(context);

    // Sub-agrupamento por sala
    final byRoom = <String, List<MediaImage>>{};
    for (final img in images) {
      final roomKey = (img.roomName != null && img.roomName!.trim().isNotEmpty)
          ? img.roomName!.trim()
          : 'Sem sala';
      byRoom.putIfAbsent(roomKey, () => []);
      byRoom[roomKey]!.add(img);
    }
    final roomKeys = byRoom.keys.toList()..sort((a, b) => a.compareTo(b));

    final groupExpanded = _expandedGroups[groupName] ?? false;

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: PageStorageKey<String>('group_$groupName'),
        initiallyExpanded: groupExpanded,
        onExpansionChanged: (isExpanded) {
          setState(() => _expandedGroups[groupName] = isExpanded);
        },
        tilePadding: EdgeInsets.zero,
        title: Row(children: [
          Icon(Icons.folder, color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(groupName,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12)),
            child: Text('${_getDisplayCount(images)}',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold)),
          ),
        ]),
        children: [
          ...roomKeys.map((roomName) {
            final imgs = byRoom[roomName]!;
            final roomKey = '${groupName}_$roomName';
            final roomExpanded = _expandedRooms[roomKey] ?? false;

            // Imagens reais (sem dummies)
            final displayImgs = imgs
                .where((img) =>
                    !img.id.startsWith('dummy_') &&
                    !img.id.startsWith('dummy|'))
                .toList();

            return Padding(
              padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
              child: Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: PageStorageKey<String>('room_$roomKey'),
                  initiallyExpanded: roomExpanded,
                  onExpansionChanged: (isExpanded) {
                    setState(() => _expandedRooms[roomKey] = isExpanded);

                    // Lazy load: disparar apenas na primeira abertura quando vazia
                    if (isExpanded &&
                        displayImgs.isEmpty &&
                        !_lazyLoadTriggered.contains(roomKey)) {
                      final dummyImg = imgs.firstWhere(
                        (img) =>
                            img.id.startsWith('dummy|') ||
                            img.id.startsWith('dummy_'),
                        orElse: () => imgs.first,
                      );
                      if (dummyImg.id.startsWith('dummy|')) {
                        _lazyLoadTriggered.add(roomKey);
                        widget.onLoadRoomImages?.call(dummyImg.id);
                      }
                    }
                  },
                  tilePadding: const EdgeInsets.only(left: 4),
                  title: Row(children: [
                    Icon(Icons.meeting_room,
                        size: 18, color: theme.colorScheme.secondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(roomName,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(10)),
                      child: Text('${_getDisplayCount(imgs)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.bold)),
                    ),
                  ]),
                  children: [
                    if (displayImgs.isEmpty &&
                        (widget.isLoading ||
                            (widget.isLoadingRoom &&
                                _lazyLoadTriggered.contains(roomKey))))
                      _RoomLoadingShimmer(
                        theme: theme,
                        serverCount: _getServerCount(imgs),
                        crossCount: _getCrossAxisCount(context),
                      )
                    else if (displayImgs.isEmpty)
                      const SizedBox.shrink()
                    else
                      Builder(
                        builder: (context) {
                          final crossCount = _getCrossAxisCount(context);
                          final screenWidth = MediaQuery.of(context).size.width;
                          final padding = screenWidth < 600 ? 12.0 : 16.0;
                          final availableWidth = screenWidth - padding * 2 - 8.0 /* left indent */;
                          final itemSize = (availableWidth - (crossCount - 1) * 8) / crossCount;
                          return Padding(
                            padding: const EdgeInsets.all(8),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: List.generate(displayImgs.length, (idx) {
                                return SizedBox(
                                  width: itemSize,
                                  height: itemSize,
                                  child: MediaCard(
                                    image: displayImgs[idx],
                                    onTap: () => widget.onImageTap(displayImgs[idx]),
                                    onDelete: widget.onImageDelete != null
                                        ? () => widget.onImageDelete!(displayImgs[idx])
                                        : null,
                                  ),
                                );
                              }),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Shimmer animado exibido enquanto as imagens de uma sala estão sendo carregadas.
class _RoomLoadingShimmer extends StatefulWidget {
  final ThemeData theme;
  final int serverCount;
  final int crossCount;

  const _RoomLoadingShimmer({
    required this.theme,
    required this.serverCount,
    required this.crossCount,
  });

  @override
  State<_RoomLoadingShimmer> createState() => _RoomLoadingShimmerState();
}

class _RoomLoadingShimmerState extends State<_RoomLoadingShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.serverCount.clamp(2, 8);
    final isDark = widget.theme.brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0);
    final highlightColor = isDark ? const Color(0xFF3D4A5C) : const Color(0xFFF0F4F8);

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 4),
            child: Row(children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: widget.theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              AnimatedBuilder(
                animation: _animation,
                builder: (_, __) => Text(
                  _getDots(_animation.value),
                  style: widget.theme.textTheme.bodySmall?.copyWith(
                    color: widget.theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ]),
          ),
          AnimatedBuilder(
            animation: _animation,
            builder: (context, _) {
              final color = Color.lerp(baseColor, highlightColor, _animation.value)!;
              final screenWidth = MediaQuery.of(context).size.width;
              final padding = screenWidth < 600 ? 12.0 : 16.0;
              final availableWidth = screenWidth - padding * 2 - 8.0;
              final itemSize = (availableWidth - (widget.crossCount - 1) * 8) / widget.crossCount;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(count, (_) => Container(
                  width: itemSize,
                  height: itemSize,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                )),
              );
            },
          ),
        ],
      ),
    );
  }

  String _getDots(double t) {
    if (t < 0.33) return 'Buscando imagens.   ';
    if (t < 0.66) return 'Buscando imagens..  ';
    return 'Buscando imagens...';
  }
}
