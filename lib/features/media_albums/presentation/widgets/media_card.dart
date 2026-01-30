import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/models/media_image.dart';
import 'status_badge.dart';
import 'package:intl/intl.dart';

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
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd/MM/yyyy', 'pt_BR');
    final isDark = theme.brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1e293b) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Imagem com aspect ratio 16:9
              AspectRatio(
                aspectRatio: 16 / 9,
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
                                color: isDark ? const Color(0xFF0f172a) : const Color(0xFFf8fafc),
                                child: const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: isDark ? const Color(0xFF1e293b) : Colors.grey[200],
                                child: Icon(
                                  Icons.broken_image,
                                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                                ),
                              ),
                            )
                          : Container(
                              color: isDark ? const Color(0xFF1e293b) : Colors.grey[200],
                              child: Icon(
                                Icons.image,
                                color: isDark ? Colors.grey[600] : Colors.grey[400],
                              ),
                            ),
                    ),
                    // Overlay no hover
                    AnimatedOpacity(
                      opacity: _isHovered ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        color: Colors.black.withOpacity(0.4),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildOverlayButton(
                                context,
                                Icons.visibility,
                                () => widget.onTap(),
                              ),
                              const SizedBox(width: 12),
                              _buildOverlayButton(
                                context,
                                Icons.edit,
                                () => widget.onTap(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Badge de status (topo esquerdo)
                    Positioned(
                      top: 12,
                      left: 12,
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
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                      // Título e botão
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              widget.image.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0f172a),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: widget.onTap,
                            borderRadius: BorderRadius.circular(4),
                            child: Icon(
                              Icons.open_in_new,
                              size: 20,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                      // Descrição (quando houver)
                      if (widget.image.description != null && widget.image.description!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          widget.image.description!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontSize: 12,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 12),
                      // Hierarquia (Regional > Divisão > Segmento > Local > Sala)
                      if (widget.image.regionalName != null ||
                          widget.image.divisaoName != null ||
                          widget.image.segmentName != null || 
                          widget.image.localName != null || 
                          widget.image.roomName != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.image.regionalName != null)
                              _buildHierarchyItem(
                                context,
                                Icons.public,
                                'Regional',
                                widget.image.regionalName!,
                                theme,
                                isDark,
                              ),
                            if (widget.image.divisaoName != null)
                              _buildHierarchyItem(
                                context,
                                Icons.account_tree,
                                'Divisão',
                                widget.image.divisaoName!,
                                theme,
                                isDark,
                              ),
                            if (widget.image.segmentName != null)
                              _buildHierarchyItem(
                                context,
                                Icons.domain,
                                'Segmento',
                                widget.image.segmentName!,
                                theme,
                                isDark,
                              ),
                            if (widget.image.localName != null)
                              _buildHierarchyItem(
                                context,
                                Icons.place,
                                'Local',
                                widget.image.localName!,
                                theme,
                                isDark,
                              ),
                            if (widget.image.roomName != null)
                              _buildHierarchyItem(
                                context,
                                Icons.location_on,
                                'Sala',
                                widget.image.roomName!,
                                theme,
                                isDark,
                              ),
                          ],
                        )
                      else if (widget.image.hierarchyPath.isNotEmpty)
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: isDark ? Colors.grey[400] : Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.image.hierarchyPath,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark ? Colors.grey[400] : Colors.grey[500],
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      // Tags
                      if (widget.image.tags.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: widget.image.tags.take(5).map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFf1f5f9),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF475569) : const Color(0xFFe2e8f0),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                tag.startsWith('#') ? tag : '#$tag',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 12),
                      // Rodapé: Data e avatar
                      Container(
                        padding: const EdgeInsets.only(top: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
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
                                        Icons.calendar_today,
                                        size: 12,
                                        color: isDark ? Colors.grey[500] : Colors.grey[400],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        dateFormat.format(widget.image.createdAt),
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: isDark ? Colors.grey[500] : Colors.grey[400],
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Cadastrado por: ${widget.image.creatorName ?? '—'}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                      fontSize: 11,
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
                                color: theme.colorScheme.primary,
                                border: Border.all(
                                  color: isDark ? const Color(0xFF1e293b) : Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  widget.image.creatorName?.substring(0, 1).toUpperCase() ?? 'U',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverlayButton(
    BuildContext context,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            color: const Color(0xFF0f172a),
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildHierarchyItem(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    ThemeData theme,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: isDark ? Colors.grey[500] : Colors.grey[500],
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? Colors.grey[500] : Colors.grey[500],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.grey[300] : const Color(0xFF1e293b),
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
