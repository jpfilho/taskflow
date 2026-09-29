import 'package:flutter/material.dart';
import '../../../../design_system/components/buttons/tf_icon_button.dart';
import '../../../../design_system/components/cards/tf_card.dart';
import '../../../../design_system/components/status/tf_status_badge.dart';
import '../../../../design_system/foundations/tf_icons.dart';
import '../../../../design_system/foundations/tf_radius.dart';
import '../../../../design_system/theme/taskflow_theme_extension.dart';
import '../../models/projeto.dart';
import 'projeto_status_mapper.dart';

/// Card compacto e responsivo para visualização operacional de Projetos.
class ProjetoCard extends StatelessWidget {
  final Projeto projeto;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;

  const ProjetoCard({
    super.key,
    required this.projeto,
    this.onTap,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final spacing = context.tfSpacing;
    final typography = context.tfTypography;

    return TFCard(
      onTap: onTap,
      padding: EdgeInsets.all(spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Título, Código e Ação de Edição
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (projeto.codigo != null && projeto.codigo!.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(bottom: spacing.xxs),
                        child: Text(
                          projeto.codigo!.toUpperCase(),
                          style: typography.caption.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    Text(
                      projeto.nome,
                      style: typography.cardTitle.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onEdit != null)
                TFIconButton(
                  icon: TFIcons.edit,
                  tooltip: 'Editar Projeto',
                  onPressed: onEdit,
                ),
            ],
          ),

          // Descrição (se houver)
          if (projeto.descricao != null && projeto.descricao!.isNotEmpty) ...[
            SizedBox(height: spacing.xs),
            Text(
              projeto.descricao!,
              style: typography.bodySmall.copyWith(color: colors.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          SizedBox(height: spacing.sm),

          // Badges: Status e Prioridade
          Wrap(
            spacing: spacing.xs,
            runSpacing: spacing.xs,
            children: [
              TFStatusBadge(
                label: projeto.status,
                severity: ProjetoStatusMapper.mapProjetoStatus(projeto.status),
                icon: ProjetoStatusMapper.getStatusIcon(projeto.status),
              ),
              TFStatusBadge(
                label: 'Prioridade: ${projeto.prioridade}',
                severity: ProjetoStatusMapper.mapPrioridade(projeto.prioridade),
              ),
            ],
          ),

          SizedBox(height: spacing.md),

          // Barra de Progresso Tematizada
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progresso',
                    style: typography.caption.copyWith(color: colors.textSecondary),
                  ),
                  Text(
                    '${projeto.progresso.toStringAsFixed(1)}%',
                    style: typography.labelSmall.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: spacing.xxs),
              ClipRRect(
                borderRadius: TFRadius.borderRadiusFull,
                child: LinearProgressIndicator(
                  value: (projeto.progresso / 100).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: colors.borderSubtle,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    projeto.progresso >= 100
                        ? colors.success
                        : projeto.progresso > 0
                            ? colors.primary
                            : colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
