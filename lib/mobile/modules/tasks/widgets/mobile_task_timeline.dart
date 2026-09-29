import 'package:flutter/material.dart';
import '../../../core/theme/tf_mobile_spacing.dart';
import '../../../core/theme/tf_mobile_typography.dart';
import '../models/mobile_task_detail_view_model.dart';

/// Linha do tempo factual da atividade.
/// Exibe exclusivamente eventos comprováveis (criação, início programado, atualizações)
/// sem fabricar marcos sintéticos a partir de suposições.
class MobileTaskTimeline extends StatelessWidget {
  final List<MobileTimelineEvent> events;

  const MobileTaskTimeline({
    super.key,
    required this.events,
  });

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const SizedBox.shrink();
    }

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
              const Icon(Icons.history_rounded, size: 20.0, color: Color(0xFF3B82F6)),
              const SizedBox(width: TFMobileSpacing.sm),
              Expanded(
                child: Text(
                  'Histórico da Atividade',
                  style: TFMobileTypography.titleMedium.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: TFMobileSpacing.md),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final ev = events[index];
              final isLast = index == events.length - 1;
              final dateStr =
                  '${ev.timestamp.day.toString().padLeft(2, '0')}/${ev.timestamp.month.toString().padLeft(2, '0')} ${ev.timestamp.hour.toString().padLeft(2, '0')}:${ev.timestamp.minute.toString().padLeft(2, '0')}';

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Indicador e linha vertical
                    Column(
                      children: [
                        Container(
                          width: 10.0,
                          height: 10.0,
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              width: 2.0,
                            ),
                          ),
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 2.0,
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: TFMobileSpacing.md),
                    // Conteúdo do evento
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: isLast ? 0 : TFMobileSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: TFMobileSpacing.sm,
                              children: [
                                Text(
                                  ev.title,
                                  style: TFMobileTypography.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  dateStr,
                                  style: TFMobileTypography.caption.copyWith(
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                            if (ev.description != null && ev.description!.isNotEmpty) ...[
                              const SizedBox(height: 2.0),
                              Text(
                                ev.description!,
                                style: TFMobileTypography.caption.copyWith(
                                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
