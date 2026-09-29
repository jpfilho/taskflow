import 'package:flutter/material.dart';
import '../../../core/theme/tf_mobile_spacing.dart';
import '../../../core/theme/tf_mobile_typography.dart';

/// Badge visual de alerta de conflito de programação (sobreposição de horário, equipe ou frota).
class MobileAgendaConflictBadge extends StatelessWidget {
  final String? message;

  const MobileAgendaConflictBadge({
    super.key,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TFMobileSpacing.xs,
        vertical: 3.0,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(color: const Color(0xFFEF4444), width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 13.0,
            color: Color(0xFFB91C1C),
          ),
          const SizedBox(width: 4.0),
          Flexible(
            child: Text(
              message ?? 'Conflito de agenda',
              style: TFMobileTypography.caption.copyWith(
                color: const Color(0xFFB91C1C),
                fontWeight: FontWeight.w700,
                fontSize: 10.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
