import 'package:flutter/material.dart';
import '../../core/theme/tf_mobile_spacing.dart';
import '../../core/theme/tf_mobile_typography.dart';
import '../../core/theme/tf_mobile_colors.dart';
import '../../core/theme/tf_mobile_touch_targets.dart';
import '../../core/navigation/tf_mobile_navigator.dart';

/// ModalBottomSheet de Ações Rápidas de Campo disparada pelo botão central 'Campo'.
/// Touch targets garantidos >= 48px com ícones claros e contexto operacional.
class TFFieldQuickActionsSheet extends StatelessWidget {
  final String? activeTaskId;
  final String? activeTaskTitle;
  final TFMobileNavigator navigator;

  const TFFieldQuickActionsSheet({
    super.key,
    this.activeTaskId,
    this.activeTaskTitle,
    required this.navigator,
  });

  static Future<void> show({
    required BuildContext context,
    String? activeTaskId,
    String? activeTaskTitle,
    required TFMobileNavigator navigator,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TFFieldQuickActionsSheet(
        activeTaskId: activeTaskId,
        activeTaskTitle: activeTaskTitle,
        navigator: navigator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = TFMobileColors.surface(context);
    final textPrimary = TFMobileColors.textPrimary(context);
    final textSecondary = TFMobileColors.textSecondary(context);

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 16.0,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TFMobileSpacing.lg,
            vertical: TFMobileSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40.0,
                  height: 5.0,
                  margin: const EdgeInsets.only(bottom: TFMobileSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),

              // Título e Contexto Operacional
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ações Rápidas de Campo',
                          style: TFMobileTypography.titleLarge.copyWith(
                            color: textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (activeTaskTitle != null)
                          Text(
                            'Vinculado a: $activeTaskTitle',
                            style: TFMobileTypography.caption.copyWith(
                              color: TFMobileColors.primaryBlue,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        else
                          Text(
                            'Selecione a ação a executar agora',
                            style: TFMobileTypography.caption.copyWith(color: textSecondary),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                    splashRadius: 20.0,
                  ),
                ],
              ),
              const SizedBox(height: TFMobileSpacing.md),
              const Divider(height: 1.0),
              const SizedBox(height: TFMobileSpacing.md),

              // Grade de Ações de Campo (Mínimo 48px de toque em cada item)
              _buildActionTile(
                context,
                icon: Icons.photo_camera_rounded,
                iconColor: TFMobileColors.primaryBlue,
                bgColor: const Color(0xFFEFF6FF),
                title: 'Tirar Foto / Evidência',
                subtitle: 'Registrar evidência visual de serviço no local',
                onTap: () {
                  Navigator.of(context).pop();
                  navigator.openMediaCapture(activityId: activeTaskId);
                },
              ),
              _buildActionTile(
                context,
                icon: Icons.checklist_rounded,
                iconColor: TFMobileColors.success,
                bgColor: const Color(0xFFDCFCE7),
                title: 'Preencher Checklist',
                subtitle: 'Inspeção de rotina e conformidade técnica',
                onTap: () {
                  Navigator.of(context).pop();
                  navigator.openChecklist(activityId: activeTaskId);
                },
              ),
              _buildActionTile(
                context,
                icon: Icons.shield_rounded,
                iconColor: const Color(0xFFB45309),
                bgColor: const Color(0xFFFEF3C7),
                title: 'APR de Segurança',
                subtitle: 'Análise Preliminar de Risco e liberação',
                onTap: () {
                  Navigator.of(context).pop();
                  navigator.openApr(activityId: activeTaskId);
                },
              ),
              _buildActionTile(
                context,
                icon: Icons.access_time_filled_rounded,
                iconColor: const Color(0xFF0369A1),
                bgColor: const Color(0xFFE0F2FE),
                title: 'Apontar Horas SAP',
                subtitle: 'Registrar horas trabalhadas da equipe',
                onTap: () {
                  Navigator.of(context).pop();
                  navigator.openTimesheet();
                },
              ),
              _buildActionTile(
                context,
                icon: Icons.warning_rounded,
                iconColor: TFMobileColors.error,
                bgColor: const Color(0xFFFEE2E2),
                title: 'Registrar Ocorrência / Impedimento',
                subtitle: 'Relatar anomalia ou bloqueio de serviço',
                onTap: () {
                  Navigator.of(context).pop();
                  navigator.openDemandas();
                },
              ),
              _buildActionTile(
                context,
                icon: Icons.link_rounded,
                iconColor: const Color(0xFF475569),
                bgColor: const Color(0xFFF1F5F9),
                title: 'Vincular Nota / Ordem SAP',
                subtitle: 'Associar documento SAP a uma tarefa',
                onTap: () {
                  Navigator.of(context).pop();
                  navigator.openNotasSap();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final textPrimary = TFMobileColors.textPrimary(context);
    final textSecondary = TFMobileColors.textSecondary(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.0),
      child: Container(
        constraints: const BoxConstraints(minHeight: TFMobileTouchTargets.min),
        padding: const EdgeInsets.symmetric(
          horizontal: TFMobileSpacing.sm,
          vertical: TFMobileSpacing.sm,
        ),
        child: Row(
          children: [
            Container(
              width: 44.0,
              height: 44.0,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Icon(icon, color: iconColor, size: 24.0),
            ),
            const SizedBox(width: TFMobileSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TFMobileTypography.titleMedium.copyWith(
                      color: textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TFMobileTypography.caption.copyWith(color: textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20.0),
          ],
        ),
      ),
    );
  }
}
