import 'package:flutter/material.dart';
import '../../../core/theme/tf_mobile_spacing.dart';
import '../../../core/theme/tf_mobile_typography.dart';
import '../../../core/theme/tf_mobile_colors.dart';
import '../../../core/theme/tf_mobile_touch_targets.dart';
import 'tf_feed_models.dart';

/// Barra e componente de composição rápida de atualizações no Feed do TaskFlow Mobile.
/// Suporta contexto operacional pré-definido (Atividade, Demanda, Projeto, Comunidade).
class TFFeedComposer extends StatelessWidget {
  final String? contextLabel; // ex: "na Atividade 1234" ou "na Regional Fortaleza"
  final TFFeedContextType contextType;
  final VoidCallback onTap;
  final VoidCallback? onCameraTap;
  final VoidCallback? onOccurrenceTap;
  final VoidCallback? onBestPracticeTap;

  const TFFeedComposer({
    super.key,
    this.contextLabel,
    this.contextType = TFFeedContextType.general,
    required this.onTap,
    this.onCameraTap,
    this.onOccurrenceTap,
    this.onBestPracticeTap,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = TFMobileColors.surface(context);
    final borderColor = TFMobileColors.border(context);
    final textSecondary = TFMobileColors.textSecondary(context);

    final placeholder = contextLabel != null
        ? 'Compartilhar atualização $contextLabel...'
        : 'Compartilhe uma atualização com sua equipe...';

    return Container(
      margin: const EdgeInsets.only(bottom: TFMobileSpacing.md),
      padding: const EdgeInsets.all(TFMobileSpacing.md),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Campo de toque que simula a abertura da caixa de criação
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: TFMobileSpacing.md, vertical: 12.0),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF0F172A)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24.0),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14.0,
                    backgroundColor: TFMobileColors.primaryBlue.withOpacity(0.15),
                    child: const Icon(Icons.person_rounded, size: 16.0, color: TFMobileColors.primaryBlue),
                  ),
                  const SizedBox(width: TFMobileSpacing.sm),
                  Expanded(
                    child: Text(
                      placeholder,
                      style: TFMobileTypography.bodyMedium.copyWith(color: textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: TFMobileSpacing.sm),
          const Divider(height: 1.0),
          const SizedBox(height: TFMobileSpacing.xs),

          // Botões de Ação Rápida de Campo (Touch Targets ≥ 48px)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: _buildActionButton(
                  context,
                  icon: Icons.photo_camera_rounded,
                  label: 'Foto de Serviço',
                  color: TFMobileColors.primaryBlue,
                  onTap: onCameraTap ?? onTap,
                ),
              ),
              Expanded(
                child: _buildActionButton(
                  context,
                  icon: Icons.warning_amber_rounded,
                  label: 'Ocorrência',
                  color: TFMobileColors.warning,
                  onTap: onOccurrenceTap ?? onTap,
                ),
              ),
              Expanded(
                child: _buildActionButton(
                  context,
                  icon: Icons.lightbulb_outline_rounded,
                  label: 'Boa Prática',
                  color: TFMobileColors.success,
                  onTap: onBestPracticeTap ?? onTap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: TFMobileTouchTargets.min, // 48px
      ),
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18.0, color: color),
        label: Text(
          label,
          style: TFMobileTypography.caption.copyWith(
            fontWeight: FontWeight.w600,
            color: TFMobileColors.textPrimary(context),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: TFMobileSpacing.xs),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
