import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/tf_mobile_spacing.dart';
import '../../../core/theme/tf_mobile_typography.dart';
import '../../../core/theme/tf_mobile_status_colors.dart';
import '../../../core/widgets/tf_mobile_status_chip.dart';
import '../models/mobile_task_detail_view_model.dart';

/// Cabeçalho do detalhe fullscreen da atividade.
/// Apresenta status operacional, tipo, prioridade, ID e título com alta legibilidade.
class MobileTaskStatusHeader extends StatelessWidget {
  final MobileTaskDetailViewModel task;
  final VoidCallback onBack;

  const MobileTaskStatusHeader({
    super.key,
    required this.task,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        TFMobileSpacing.lg,
        TFMobileSpacing.md,
        TFMobileSpacing.lg,
        TFMobileSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1.0,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Barra de Navegação Superior
          Row(
            children: [
              SizedBox(
                width: 48.0,
                height: 48.0,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20.0),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    onBack();
                  },
                  tooltip: 'Voltar',
                ),
              ),
              const SizedBox(width: TFMobileSpacing.xs),
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: TFMobileSpacing.xs,
                  runSpacing: TFMobileSpacing.xxs,
                  children: [
                    // Status Chip
                    if (!task.isUnknownStatus)
                      TFMobileStatusChip.operational(
                        status: task.status,
                        dense: true,
                      )
                    else
                      TFMobileStatusChip.custom(
                        customLabel: task.rawStatus,
                        customIcon: Icons.help_outline_rounded,
                        customBackground: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                        customForeground: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                        customBorder: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                        dense: true,
                      ),
                    if (task.syncStatus == TFSyncStatus.pending)
                      TFMobileStatusChip.sync(
                        status: TFSyncStatus.pending,
                        dense: true,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: TFMobileSpacing.xs),
              // ID da Tarefa
              Container(
                padding: const EdgeInsets.symmetric(horizontal: TFMobileSpacing.sm, vertical: 4.0),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6.0),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Text(
                  '#${task.id.length > 8 ? task.id.substring(0, 8) : task.id}',
                  style: TFMobileTypography.caption.copyWith(
                    fontFamily: 'monospace',
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: TFMobileSpacing.md),

          // Tipo e Prioridade
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: TFMobileSpacing.sm, vertical: 2.0),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E3A8A).withOpacity(0.3) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6.0),
                  border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.4)),
                ),
                child: Text(
                  task.type,
                  style: TFMobileTypography.caption.copyWith(
                    color: const Color(0xFF3B82F6),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (task.priority != null) ...[
                const SizedBox(width: TFMobileSpacing.sm),
                _buildPriorityBadge(task.priority!, isDark),
              ],
            ],
          ),
          const SizedBox(height: TFMobileSpacing.sm),

          // Título Completo da Tarefa
          Text(
            task.title,
            style: TFMobileTypography.titleLarge.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityBadge(String priority, bool isDark) {
    final pUpper = priority.toUpperCase();
    Color bg;
    Color fg;

    if (pUpper.contains('ALTA') || pUpper.contains('URG')) {
      bg = isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2);
      fg = isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626);
    } else if (pUpper.contains('MED') || pUpper.contains('MÉD')) {
      bg = isDark ? const Color(0xFF3B2712) : const Color(0xFFFEF3C7);
      fg = isDark ? const Color(0xFFFDE68A) : const Color(0xFFD97706);
    } else {
      bg = isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5);
      fg = isDark ? const Color(0xFF6EE7B7) : const Color(0xFF059669);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: TFMobileSpacing.xs, vertical: 2.0),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6.0),
      ),
      child: Text(
        priority,
        style: TFMobileTypography.caption.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 11.0,
        ),
      ),
    );
  }
}
