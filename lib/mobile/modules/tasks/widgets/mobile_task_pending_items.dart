import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/tf_mobile_spacing.dart';
import '../../../core/theme/tf_mobile_typography.dart';
import '../../../core/widgets/tf_mobile_buttons.dart';
import '../models/mobile_task_detail_view_model.dart';

/// Seção de Segurança do Trabalho e Pendências Reais da Atividade.
/// Informa com alta visibilidade a condição da APR e sincronizações pendentes
/// sem criar bloqueios artificiais não previstos no sistema existente.
class MobileTaskPendingItems extends StatelessWidget {
  final MobileAprStatus aprStatus;
  final bool hasPendingSync;
  final VoidCallback onOpenApr;

  const MobileTaskPendingItems({
    super.key,
    required this.aprStatus,
    this.hasPendingSync = false,
    required this.onOpenApr,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: TFMobileSpacing.lg, vertical: TFMobileSpacing.xs),
      padding: const EdgeInsets.all(TFMobileSpacing.lg),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, size: 20.0, color: Color(0xFF3B82F6)),
              const SizedBox(width: TFMobileSpacing.sm),
              Expanded(
                child: Text(
                  'Segurança & Conformidade',
                  style: TFMobileTypography.titleMedium.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: TFMobileSpacing.md),

          // Estado da APR
          _buildAprCard(context, isDark),

          // Alerta de Sincronização Local
          if (hasPendingSync) ...[
            const SizedBox(height: TFMobileSpacing.sm),
            Container(
              padding: const EdgeInsets.all(TFMobileSpacing.md),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF3B2712) : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(
                  color: isDark ? const Color(0xFF92400E) : const Color(0xFFFDE68A),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sync_problem_rounded, color: Color(0xFFD97706), size: 20.0),
                  const SizedBox(width: TFMobileSpacing.sm),
                  Expanded(
                    child: Text(
                      'Existem registros locais aguardando sincronização com a nuvem.',
                      style: TFMobileTypography.bodyMedium.copyWith(
                        color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAprCard(BuildContext context, bool isDark) {
    switch (aprStatus) {
      case MobileAprStatus.requiredPending:
        return Container(
          padding: const EdgeInsets.all(TFMobileSpacing.md),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: isDark ? const Color(0xFF991B1B) : const Color(0xFFFECACA),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_rounded, color: Color(0xFFDC2626), size: 20.0),
                  const SizedBox(width: TFMobileSpacing.sm),
                  Expanded(
                    child: Text(
                      'APR (Análise Preliminar de Risco) Pendente',
                      style: TFMobileTypography.bodyMedium.copyWith(
                        color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: TFMobileSpacing.xs),
              Text(
                'Recomenda-se preencher a APR antes de iniciar o trabalho em campo.',
                style: TFMobileTypography.caption.copyWith(
                  color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF7F1D1D),
                ),
              ),
              const SizedBox(height: TFMobileSpacing.md),
              SizedBox(
                width: double.infinity,
                height: 48.0,
                child: TFSecondaryButton(
                  label: 'Preencher APR',
                  icon: Icons.assignment_outlined,
                  height: 48.0,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onOpenApr();
                  },
                ),
              ),
            ],
          ),
        );

      case MobileAprStatus.requiredCompleted:
        return Container(
          padding: const EdgeInsets.all(TFMobileSpacing.md),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: isDark ? const Color(0xFF047857) : const Color(0xFFA7F3D0),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 20.0),
              const SizedBox(width: TFMobileSpacing.sm),
              Expanded(
                child: Text(
                  'APR preenchida e em conformidade.',
                  style: TFMobileTypography.bodyMedium.copyWith(
                    color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onOpenApr();
                },
                child: const Text('Visualizar'),
              ),
            ],
          ),
        );

      case MobileAprStatus.notRequired:
      case MobileAprStatus.unknown:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: TFMobileSpacing.xs),
          child: Text(
            'Nenhuma pendência de segurança impeditiva registrada.',
            style: TFMobileTypography.bodyMedium.copyWith(
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        );
    }
  }
}
