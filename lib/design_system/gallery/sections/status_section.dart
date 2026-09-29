import 'package:flutter/material.dart';
import '../../components/status/tf_status_badge.dart';
import '../../foundations/tf_icons.dart';
import '../../theme/taskflow_theme_extension.dart';
import '../gallery_section.dart';

class StatusSection extends StatelessWidget {
  const StatusSection({super.key});

  @override
  Widget build(BuildContext context) {
    final spacing = context.tfSpacing;

    return GallerySection(
      title: 'TFStatusBadge — Severidade & Status',
      description: 'Badges operacionais puramente visuais com texto, cor e ícone para acessibilidade total de pessoas daltônicas.',
      children: [
        GalleryPreviewCard(
          title: 'Severidades Visuais Padrão',
          description: 'neutral, info, success, warning, danger',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: const [
              TFStatusBadge(
                label: 'Planejado',
                severity: TFStatusSeverity.neutral,
              ),
              TFStatusBadge(
                label: 'Em Execução',
                severity: TFStatusSeverity.info,
                icon: TFIcons.sync,
              ),
              TFStatusBadge(
                label: 'Concluído',
                severity: TFStatusSeverity.success,
                icon: TFIcons.success,
              ),
              TFStatusBadge(
                label: 'Atenção / D-2',
                severity: TFStatusSeverity.warning,
                icon: TFIcons.warning,
              ),
              TFStatusBadge(
                label: 'Atrasado / Crítico',
                severity: TFStatusSeverity.danger,
                icon: TFIcons.error,
              ),
            ],
          ),
        ),
        GalleryPreviewCard(
          title: 'Modo Compacto (Tabelas de Alta Densidade)',
          description: 'compact: true para TaskTable, Notas SAP e Gantt',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  TFStatusBadge(
                    label: 'PLND',
                    severity: TFStatusSeverity.neutral,
                    compact: true,
                  ),
                  TFStatusBadge(
                    label: 'EXEC',
                    severity: TFStatusSeverity.info,
                    icon: TFIcons.sync,
                    compact: true,
                  ),
                  TFStatusBadge(
                    label: 'CONC',
                    severity: TFStatusSeverity.success,
                    icon: TFIcons.success,
                    compact: true,
                  ),
                  TFStatusBadge(
                    label: 'MSPR',
                    severity: TFStatusSeverity.warning,
                    icon: TFIcons.warning,
                    compact: true,
                  ),
                  TFStatusBadge(
                    label: 'CANC',
                    severity: TFStatusSeverity.danger,
                    icon: TFIcons.error,
                    compact: true,
                  ),
                ],
              ),
              SizedBox(height: spacing.sm),
              const Text(
                'Nota: O componente TFStatusBadge é desacoplado das regras de domínio. '
                'Adapters mapearão os códigos legados (PLND, EXEC, CONC) para TFStatusSeverity.',
                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
