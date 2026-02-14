import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models/document.dart';
import 'document_status_badge.dart';

class DocumentCard extends StatelessWidget {
  final Document document;
  final VoidCallback? onTap;
  final VoidCallback? onDownload;

  const DocumentCard({
    super.key,
    required this.document,
    this.onTap,
    this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final createdAt = DateFormat('dd/MM/yyyy').format(document.createdAt);
    final mimeLabel = document.file.extension?.toUpperCase() ?? document.file.mimeType;
    final iconData = _iconForMime(document.file.mimeType, document.file.extension);
    final iconColor = _colorForMime(document.file.mimeType, document.file.extension);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(iconData, color: iconColor, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Chip(
                              label: Text(mimeLabel),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            const SizedBox(width: 6),
                            if (document.statusDocument != null)
                              DocumentStatusBadge(status: document.statusDocument),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          document.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (document.description != null && document.description!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              document.description!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onDownload ?? onTap,
                    icon: const Icon(Icons.download),
                    tooltip: 'Baixar',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: -6,
                children: [
                  if (document.hierarchyPath.isNotEmpty)
                    Chip(
                      label: Text(document.hierarchyPath),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  Chip(
                    label: Text('Criado em: $createdAt'),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  if (document.creatorName != null && document.creatorName!.isNotEmpty)
                    Chip(
                      label: Text('Por ${document.creatorName}'),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  if (document.tags.isNotEmpty)
                    ...document.tags.take(4).map(
                      (t) => Chip(
                        label: Text(t),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForMime(String mime, String? ext) {
    final e = (ext ?? '').toLowerCase();
    if (mime.contains('pdf') || e == 'pdf') return Icons.picture_as_pdf;
    if (mime.contains('sheet') || e == 'xlsx' || e == 'xls') return Icons.table_chart;
    if (mime.contains('presentation') || e == 'pptx' || e == 'ppt') return Icons.slideshow;
    if (mime.contains('word') || e == 'docx' || e == 'doc') return Icons.description;
    if (mime.contains('text') || e == 'txt') return Icons.notes;
    if (mime.contains('zip') || e == 'zip') return Icons.archive;
    if (mime.contains('image') || ['jpg', 'jpeg', 'png', 'webp'].contains(e)) return Icons.image;
    return Icons.insert_drive_file;
    }

  Color _colorForMime(String mime, String? ext) {
    final e = (ext ?? '').toLowerCase();
    if (mime.contains('pdf') || e == 'pdf') return Colors.red.shade400;
    if (mime.contains('sheet') || e == 'xlsx' || e == 'xls') return Colors.green.shade600;
    if (mime.contains('presentation') || e == 'pptx' || e == 'ppt') return Colors.orange.shade600;
    if (mime.contains('word') || e == 'docx' || e == 'doc') return Colors.blue.shade600;
    if (mime.contains('text') || e == 'txt') return Colors.grey.shade700;
    if (mime.contains('zip') || e == 'zip') return Colors.brown.shade600;
    if (mime.contains('image') || ['jpg', 'jpeg', 'png', 'webp'].contains(e)) return Colors.purple.shade400;
    return Colors.blueGrey.shade600;
  }
}
