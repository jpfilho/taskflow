import 'package:flutter/material.dart';
import '../../../core/theme/tf_mobile_typography.dart';
import '../../../core/theme/tf_mobile_colors.dart';
import '../../../core/theme/tf_mobile_spacing.dart';

/// Badge de mensagens não lidas com alta visibilidade.
class TFUnreadBadge extends StatelessWidget {
  final int count;

  const TFUnreadBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    final text = count > 99 ? '99+' : count.toString();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: TFMobileColors.primaryBlue,
        borderRadius: BorderRadius.circular(10.0),
      ),
      constraints: const BoxConstraints(minWidth: 20.0, minHeight: 20.0),
      child: Center(
        child: Text(
          text,
          style: TFMobileTypography.caption.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 11.0,
          ),
        ),
      ),
    );
  }
}

/// Badge de Menção Direta (@Você).
class TFMentionBadge extends StatelessWidget {
  const TFMentionBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: TFMobileColors.warning,
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.alternate_email_rounded, size: 12.0, color: Colors.white),
          const SizedBox(width: 2.0),
          Text(
            'Mencionou você',
            style: TFMobileTypography.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 11.0,
            ),
          ),
        ],
      ),
    );
  }
}

/// Botão de Reação rápida tátil para mensagens e posts (👍, ❤️, ⚡).
class TFReactionButton extends StatelessWidget {
  final String emoji;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const TFReactionButton({
    super.key,
    required this.emoji,
    required this.count,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected ? TFMobileColors.primaryBlue : TFMobileColors.border(context);
    final bgColor = isSelected
        ? TFMobileColors.primaryBlue.withOpacity(0.12)
        : TFMobileColors.surface(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.0),
      child: Container(
        constraints: const BoxConstraints(minHeight: 32.0),
        padding: const EdgeInsets.symmetric(horizontal: TFMobileSpacing.sm, vertical: 4.0),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14.0)),
            if (count > 0) ...[
              const SizedBox(width: 4.0),
              Text(
                count.toString(),
                style: TFMobileTypography.label.copyWith(
                  color: isSelected ? TFMobileColors.primaryBlue : TFMobileColors.textSecondary(context),
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
