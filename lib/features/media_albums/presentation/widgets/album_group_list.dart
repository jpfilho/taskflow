import 'package:flutter/material.dart';
import '../../../../design_system/components/buttons/tf_button.dart';
import '../../../../design_system/components/feedback/tf_empty_state.dart';
import '../../../../design_system/components/feedback/tf_loading.dart';
import '../../../../design_system/foundations/tf_breakpoints.dart';
import '../../../../design_system/foundations/tf_radius.dart';
import '../../../../design_system/theme/taskflow_theme_extension.dart';
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
  final Map<String, bool> _expandedGroups = {};
  final Map<String, bool> _expandedRooms = {};
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

  int _getCrossAxisCount(double width) {
    if (width >= TFBreakpoints.lg) return 4;
    if (width >= TFBreakpoints.md) return 3;
    if (width >= TFBreakpoints.sm) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.tfSpacing;

    if (widget.groupedImages.isEmpty) {
      return Center(
        child: TFEmptyState(
          title: 'Nenhum álbum encontrado',
          description: 'Não foram encontrados álbuns para os filtros selecionados.',
          icon: Icons.folder_open_rounded,
        ),
      );
    }

    final itemCount = widget.groupedImages.length + (widget.hasMore || widget.isLoading ? 1 : 0);

    return ListView.separated(
      controller: widget.scrollController,
      padding: EdgeInsets.symmetric(vertical: spacing.xs),
      itemCount: itemCount,
      separatorBuilder: (_, __) => SizedBox(height: spacing.sm),
      itemBuilder: (context, index) {
        if (index >= widget.groupedImages.length) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: spacing.md),
            child: Center(
              child: widget.isLoading
                  ? const TFLoading(message: 'Carregando mais álbuns...')
                  : widget.hasMore && widget.onLoadMore != null
                      ? TFButton(
                          label: 'Carregar mais',
                          variant: TFButtonVariant.secondary,
                          leadingIcon: Icons.add_circle_outline_rounded,
                          onPressed: widget.onLoadMore,
                        )
                      : const SizedBox.shrink(),
            ),
          );
        }
        final entry = widget.groupedImages.entries.elementAt(index);
        return _buildGroupSection(context, entry.key, entry.value);
      },
    );
  }

  Widget _buildGroupSection(BuildContext context, String groupName, List<MediaImage> images) {
    final colors = context.tfColors;
    final spacing = context.tfSpacing;
    final typography = context.tfTypography;

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

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: TFRadius.borderRadiusMd,
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: ExpansionTile(
          key: PageStorageKey<String>('group_$groupName'),
          initiallyExpanded: groupExpanded,
          onExpansionChanged: (isExpanded) {
            setState(() => _expandedGroups[groupName] = isExpanded);
          },
          tilePadding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xxs),
          title: Row(
            children: [
              Icon(Icons.folder_rounded, color: colors.primary, size: 22),
              SizedBox(width: spacing.sm),
              Expanded(
                child: Text(
                  groupName,
                  style: typography.cardTitle.copyWith(color: colors.textPrimary),
                ),
              ),
              SizedBox(width: spacing.sm),
              Container(
                padding: EdgeInsets.symmetric(horizontal: spacing.xs, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: TFRadius.borderRadiusFull,
                ),
                child: Text(
                  '${_getDisplayCount(images)} fotos',
                  style: typography.caption.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
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
                padding: EdgeInsets.only(left: spacing.sm, right: spacing.sm, bottom: spacing.xs),
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.surfaceSecondary.withValues(alpha: 0.4),
                    borderRadius: TFRadius.borderRadiusSm,
                    border: Border.all(color: colors.borderSubtle.withValues(alpha: 0.6)),
                  ),
                  child: ExpansionTile(
                    key: PageStorageKey<String>('room_$roomKey'),
                    initiallyExpanded: roomExpanded,
                    onExpansionChanged: (isExpanded) {
                      setState(() => _expandedRooms[roomKey] = isExpanded);

                      // Lazy load ao abrir sala vazia
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
                    tilePadding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xxs),
                    title: Row(
                      children: [
                        Icon(Icons.meeting_room_outlined, size: 18, color: colors.primary),
                        SizedBox(width: spacing.xs),
                        Expanded(
                          child: Text(
                            roomName,
                            style: typography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        SizedBox(width: spacing.xs),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: spacing.xs, vertical: 2),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.12),
                            borderRadius: TFRadius.borderRadiusFull,
                          ),
                          child: Text(
                            '${_getDisplayCount(imgs)}',
                            style: typography.caption.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    children: [
                      if (displayImgs.isEmpty &&
                          (widget.isLoading ||
                              (widget.isLoadingRoom &&
                                  _lazyLoadTriggered.contains(roomKey))))
                        Padding(
                          padding: EdgeInsets.all(spacing.md),
                          child: const Center(child: TFLoading(message: 'Carregando fotos da sala...')),
                        )
                      else if (displayImgs.isEmpty)
                        const SizedBox.shrink()
                      else
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final crossCount = _getCrossAxisCount(constraints.maxWidth);
                            final itemWidth = (constraints.maxWidth - (crossCount - 1) * spacing.xs - spacing.sm * 2) / crossCount;

                            return Padding(
                              padding: EdgeInsets.all(spacing.sm),
                              child: Wrap(
                                spacing: spacing.xs,
                                runSpacing: spacing.xs,
                                children: List.generate(displayImgs.length, (idx) {
                                  return SizedBox(
                                    width: itemWidth,
                                    height: itemWidth * 1.15,
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
            SizedBox(height: spacing.xs),
          ],
        ),
      ),
    );
  }
}
