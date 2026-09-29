import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../design_system/components/buttons/tf_icon_button.dart';
import '../../../../design_system/components/cards/tf_card.dart';
import '../../../../design_system/foundations/tf_icons.dart';
import '../../../../design_system/foundations/tf_radius.dart';
import '../../../../design_system/theme/taskflow_theme_extension.dart';
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
    final colors = context.tfColors;
    final spacing = context.tfSpacing;
    final typography = context.tfTypography;

    final createdAt = DateFormat('dd/MM/yyyy').format(document.createdAt);
    final mimeLabel = document.file.extension?.toUpperCase() ?? document.file.mimeType;
    final iconData = _iconForMime(document.file.mimeType, document.file.extension);
    final iconColor = _colorForMime(context, document.file.mimeType, document.file.extension);

    return TFCard(
      padding: EdgeInsets.all(spacing.sm),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: TFRadius.borderRadiusSm,
                ),
                child: Icon(iconData, color: iconColor, size: 24),
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: spacing.xs, vertical: 2),
                          decoration: BoxDecoration(
                            color: colors.surfaceSecondary,
                            borderRadius: TFRadius.borderRadiusSm,
                          ),
                          child: Text(
                            mimeLabel,
                            style: typography.caption.copyWith(
                              color: colors.textSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (document.statusDocument != null) ...[
                          SizedBox(width: spacing.xs),
                          DocumentStatusBadge(status: document.statusDocument),
                        ],
                      ],
                    ),
                    SizedBox(height: spacing.xxs),
                    Text(
                      document.title,
                      style: typography.cardTitle.copyWith(color: colors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (document.description != null && document.description!.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: spacing.xxs),
                        child: Text(
                          document.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: typography.bodySmall.copyWith(color: colors.textSecondary),
                        ),
                      ),
                  ],
                ),
              ),
              if (onDownload != null || onTap != null)
                TFIconButton(
                  icon: TFIcons.download,
                  tooltip: 'Baixar Documento',
                  onPressed: onDownload ?? onTap,
                ),
            ],
          ),
          SizedBox(height: spacing.xs),
          Wrap(
            spacing: spacing.xs,
            runSpacing: spacing.xxs,
            children: [
              if (document.hierarchyPath.isNotEmpty)
                _metaChip(context, document.hierarchyPath, Icons.account_tree_outlined),
              _metaChip(context, 'Criado em: $createdAt', Icons.calendar_today_outlined),
              if (document.creatorName != null && document.creatorName!.isNotEmpty)
                _metaChip(context, document.creatorName!, Icons.person_outline_rounded),
              if (document.tags.isNotEmpty)
                ...document.tags.take(3).map(
                  (t) => _metaChip(context, '#$t', null),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaChip(BuildContext context, String label, IconData? icon) {
    final colors = context.tfColors;
    final spacing = context.tfSpacing;
    final typography = context.tfTypography;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: spacing.xs, vertical: 3),
      decoration: BoxDecoration(
        color: colors.surfaceSecondary,
        borderRadius: TFRadius.borderRadiusSm,
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: colors.textSecondary),
            SizedBox(width: spacing.xxs),
          ],
          Text(
            label,
            style: typography.caption.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }

  IconData _iconForMime(String mime, String? ext) {
    final e = (ext ?? '').toLowerCase();
    if (mime.contains('pdf') || e == 'pdf') return Icons.picture_as_pdf_rounded;
    if (mime.contains('sheet') || e == 'xlsx' || e == 'xls') return Icons.table_chart_rounded;
    if (mime.contains('presentation') || e == 'pptx' || e == 'ppt') return Icons.slideshow_rounded;
    if (mime.contains('word') || e == 'docx' || e == 'doc') return Icons.description_rounded;
    if (mime.contains('text') || e == 'txt') return Icons.notes_rounded;
    if (mime.contains('zip') || e == 'zip' || e == 'rar') return Icons.archive_rounded;
    if (mime.contains('image') || ['jpg', 'jpeg', 'png', 'webp'].contains(e)) return Icons.image_rounded;
    return Icons.insert_drive_file_rounded;
  }

  Color _colorForMime(BuildContext context, String mime, String? ext) {
    final colors = context.tfColors;
    final e = (ext ?? '').toLowerCase();
    if (mime.contains('pdf') || e == 'pdf') return colors.danger;
    if (mime.contains('sheet') || e == 'xlsx' || e == 'xls') return colors.success;
    if (mime.contains('presentation') || e == 'pptx' || e == 'ppt') return colors.warning;
    if (mime.contains('word') || e == 'docx' || e == 'doc') return colors.primary;
    if (mime.contains('image') || ['jpg', 'jpeg', 'png', 'webp'].contains(e)) return colors.primary;
    return colors.info;
  }
}
