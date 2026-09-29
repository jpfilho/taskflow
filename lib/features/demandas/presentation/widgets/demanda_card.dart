import 'package:flutter/material.dart';
import '../../../../design_system/components/cards/tf_card.dart';
import '../../../../design_system/components/status/tf_status_badge.dart';
import '../../../../design_system/foundations/tf_icons.dart';
import '../../../../design_system/theme/taskflow_theme_extension.dart';
import '../../data/models/demanda_model.dart';
import 'demanda_prazo_helper.dart';
import 'demanda_status_mapper.dart';

/// Card compacto para exibição operacional de uma demanda em viewports Mobile/Tablet ou modo Grade.
class DemandaCard extends StatelessWidget {
  final Demanda demanda;
  final VoidCallback? onTap;

  const DemandaCard({
    super.key,
    required this.demanda,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    final situacao = DemandaPrazoHelper.obterSituacao(demanda.prazo, demanda.status);
    final textoPrazo = DemandaPrazoHelper.obterTexto(situacao, demanda.prazo);
    final severityPrazo = DemandaPrazoHelper.obterSeverity(situacao);
    final severityStatus = DemandaStatusMapper.mapSeverity(demanda.status);

    final bool isAtrasada = situacao == SituacaoPrazo.atrasada;

    return TFCard(
      variant: isAtrasada ? TFCardVariant.highlighted : TFCardVariant.interactive,
      padding: EdgeInsets.all(spacing.md),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Status Badge e Prazo Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: TFStatusBadge(
                  label: demanda.status,
                  severity: severityStatus,
                  compact: true,
                ),
              ),
              SizedBox(width: spacing.xs),
              TFStatusBadge(
                label: textoPrazo,
                severity: severityPrazo,
                compact: true,
              ),
            ],
          ),
          SizedBox(height: spacing.sm),

          // Título da Demanda
          Text(
            demanda.demanda,
            style: typography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: spacing.sm),

          // Local / Sala
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 14,
                color: colors.textSecondary,
              ),
              SizedBox(width: spacing.xs),
              Expanded(
                child: Text(
                  "${demanda.local}${demanda.sala != null && demanda.sala!.isNotEmpty ? ' • ${demanda.sala}' : ''}",
                  style: typography.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.xs),

          // Rodapé: Responsável e Prioridade
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Responsável
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      size: 14,
                      color: colors.textSecondary,
                    ),
                    SizedBox(width: spacing.xs),
                    Flexible(
                      child: Text(
                        demanda.responsavel,
                        style: typography.bodySmall.copyWith(
                          color: colors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // Prioridade
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    TFIcons.info,
                    size: 14,
                    color: demanda.prioridade == 'Crítica' ? colors.danger : colors.textSecondary,
                  ),
                  SizedBox(width: spacing.xxs),
                  Text(
                    demanda.prioridade,
                    style: typography.labelSmall.copyWith(
                      color: demanda.prioridade == 'Crítica'
                          ? colors.danger
                          : demanda.prioridade == 'Alta'
                              ? colors.warning
                              : colors.textSecondary,
                      fontWeight: demanda.prioridade == 'Crítica' || demanda.prioridade == 'Alta'
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
