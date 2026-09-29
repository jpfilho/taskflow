import 'package:flutter/material.dart';
import '../../foundations/tf_icons.dart';
import '../../foundations/tf_radius.dart';
import '../../theme/taskflow_theme_extension.dart';
import '../gallery_section.dart';

class IconsSection extends StatelessWidget {
  const IconsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    final iconList = [
      ('add', TFIcons.add),
      ('edit', TFIcons.edit),
      ('delete', TFIcons.delete),
      ('save', TFIcons.save),
      ('cancel / close', TFIcons.close),
      ('search', TFIcons.search),
      ('filter', TFIcons.filter),
      ('filterActive', TFIcons.filterActive),
      ('clear', TFIcons.clear),
      ('refresh', TFIcons.refresh),
      ('sync', TFIcons.sync),
      ('syncProblem', TFIcons.syncProblem),
      ('offline', TFIcons.offline),
      ('chat', TFIcons.chat),
      ('attachment', TFIcons.attachment),
      ('upload', TFIcons.upload),
      ('download', TFIcons.download),
      ('calendar', TFIcons.calendar),
      ('history', TFIcons.history),
      ('settings', TFIcons.settings),
      ('warning', TFIcons.warning),
      ('error', TFIcons.error),
      ('success', TFIcons.success),
      ('info', TFIcons.info),
      ('ai', TFIcons.ai),
      ('sap', TFIcons.sap),
      ('task', TFIcons.task),
      ('team', TFIcons.team),
      ('fleet', TFIcons.fleet),
    ];

    return GallerySection(
      title: 'Ícones Semânticos (TFIcons)',
      description: 'Catálogo de intenções de uso frequente para padronizar pictogramas em toda a aplicação.',
      children: [
        GalleryPreviewCard(
          title: 'Aliases Padronizados',
          description: 'Acesse diretamente via TFIcons.<nome>',
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final (name, iconData) in iconList) ...[
                Container(
                  width: 120.0,
                  padding: EdgeInsets.all(spacing.sm),
                  decoration: BoxDecoration(
                    color: colors.surfaceSecondary,
                    borderRadius: TFRadius.borderRadiusSm,
                    border: Border.all(color: colors.borderSubtle),
                  ),
                  child: Column(
                    children: [
                      Icon(iconData, size: 24.0, color: colors.primary),
                      SizedBox(height: spacing.xs),
                      Text(
                        name,
                        style: typography.micro.copyWith(color: colors.textPrimary),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
