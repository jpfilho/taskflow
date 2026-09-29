import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../../design_system/components/cards/tf_card.dart';
import '../../../../design_system/foundations/tf_icons.dart';
import '../../../../design_system/foundations/tf_radius.dart';
import '../../../../design_system/theme/taskflow_theme_extension.dart';
import '../../data/models/media_image.dart';
import 'status_badge.dart';

class MediaCard extends StatefulWidget {
  final MediaImage image;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const MediaCard({
    super.key,
    required this.image,
    required this.onTap,
    this.onDelete,
  });

  @override
  State<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<MediaCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final spacing = context.tfSpacing;
    final typography = context.tfTypography;
    final dateFormat = DateFormat('dd/MM/yyyy', 'pt_BR');

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: TFCard(
        padding: EdgeInsets.zero,
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Imagem com aspect ratio 16:9
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Imagem
                  Hero(
                    tag: widget.image.id,
                    child: widget.image.displayUrl != null
                        ? CachedNetworkImage(
                            imageUrl: widget.image.displayUrl!,
                            fit: BoxFit.cover,
                            memCacheWidth: 400,
                            memCacheHeight: 225,
                            placeholder: (context, url) => Container(
                              color: colors.surfaceSecondary,
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colors.primary,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: colors.surfaceSecondary,
                              child: Icon(
                                Icons.broken_image_rounded,
                                color: colors.textSecondary,
                                size: 32,
                              ),
                            ),
                          )
                        : Container(
                            color: colors.surfaceSecondary,
                            child: Icon(
                              Icons.image_rounded,
                              color: colors.textSecondary,
                              size: 32,
                            ),
                          ),
                  ),
                  // Overlay no hover
                  AnimatedOpacity(
                    opacity: _isHovered ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 180),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.35),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildOverlayButton(
                              context,
                              Icons.visibility_rounded,
                              () => widget.onTap(),
                            ),
                            if (widget.onDelete != null) ...[
                              SizedBox(width: spacing.sm),
                              _buildOverlayButton(
                                context,
                                TFIcons.delete,
                                () => widget.onDelete!(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Badge de status (topo esquerdo)
                  Positioned(
                    top: spacing.xs,
                    left: spacing.xs,
                    child: StatusBadge(
                      status: widget.image.status,
                      statusAlbum: widget.image.statusAlbum,
                    ),
                  ),
                ],
              ),
            ),
            // Informações
            Padding(
              padding: EdgeInsets.all(spacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.image.title,
                    style: typography.cardTitle.copyWith(color: colors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: spacing.xxs),
                  if (widget.image.hierarchyPath.isNotEmpty)
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 13,
                          color: colors.textSecondary,
                        ),
                        SizedBox(width: spacing.xxs),
                        Expanded(
                          child: Text(
                            widget.image.hierarchyPath,
                            style: typography.caption.copyWith(color: colors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  // Tags
                  if (widget.image.tags.isNotEmpty) ...[
                    SizedBox(height: spacing.xs),
                    Wrap(
                      spacing: spacing.xxs,
                      runSpacing: spacing.xxs,
                      children: widget.image.tags.take(4).map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colors.surfaceSecondary,
                            borderRadius: TFRadius.borderRadiusSm,
                            border: Border.all(color: colors.borderSubtle),
                          ),
                          child: Text(
                            tag.startsWith('#') ? tag : '#$tag',
                            style: typography.caption.copyWith(
                              fontSize: 10,
                              color: colors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  SizedBox(height: spacing.xs),
                  Divider(color: colors.borderSubtle, height: 1),
                  SizedBox(height: spacing.xs),
                  // Rodapé: Data e avatar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_outlined,
                                  size: 11,
                                  color: colors.textSecondary,
                                ),
                                SizedBox(width: spacing.xxs),
                                Text(
                                  dateFormat.format(widget.image.createdAt),
                                  style: typography.caption.copyWith(
                                    fontSize: 11,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Por: ${widget.image.creatorName ?? '—'}',
                              style: typography.caption.copyWith(
                                fontSize: 11,
                                color: colors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.primary,
                        ),
                        child: Center(
                          child: Text(
                            (widget.image.creatorName ?? 'U').substring(0, 1).toUpperCase(),
                            style: typography.caption.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlayButton(
    BuildContext context,
    IconData icon,
    VoidCallback onTap,
  ) {
    final colors = context.tfColors;

    return Material(
      color: colors.surface,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            color: colors.textPrimary,
            size: 18,
          ),
        ),
      ),
    );
  }
}
