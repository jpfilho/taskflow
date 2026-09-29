import 'package:flutter/material.dart';
import '../../../core/theme/tf_mobile_spacing.dart';
import '../../../core/theme/tf_mobile_typography.dart';
import '../../../core/theme/tf_mobile_colors.dart';
import 'tf_chat_badges.dart';

/// Card de comunidade operacional (Regional, Segmento, Especialidade técnica).
class TFCommunityTile extends StatelessWidget {
  final String name;
  final String description;
  final String category; // ex: "Regional", "Especialidade", "Equipe"
  final int membersCount;
  final int unreadCount;
  final IconData icon;
  final VoidCallback onTap;

  const TFCommunityTile({
    super.key,
    required this.name,
    required this.description,
    required this.category,
    required this.membersCount,
    this.unreadCount = 0,
    this.icon = Icons.groups_rounded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = TFMobileColors.textPrimary(context);
    final textSecondary = TFMobileColors.textSecondary(context);
    final surfaceColor = TFMobileColors.surface(context);
    final borderColor = TFMobileColors.border(context);

    return Container(
      margin: const EdgeInsets.only(bottom: TFMobileSpacing.sm),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12.0),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12.0),
          child: Padding(
            padding: const EdgeInsets.all(TFMobileSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 48.0,
                  height: 48.0,
                  decoration: BoxDecoration(
                    color: TFMobileColors.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: Icon(icon, color: TFMobileColors.primaryBlue, size: 24.0),
                ),
                const SizedBox(width: TFMobileSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4.0),
                            ),
                            child: Text(
                              category.toUpperCase(),
                              style: TFMobileTypography.caption.copyWith(
                                fontSize: 10.0,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(width: TFMobileSpacing.xs),
                          Expanded(
                            child: Text(
                              name,
                              style: TFMobileTypography.titleMedium.copyWith(
                                color: textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: TFMobileSpacing.xxs),
                      Text(
                        description,
                        style: TFMobileTypography.bodyMedium.copyWith(
                          color: textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: TFMobileSpacing.xs),
                      Text(
                        '$membersCount membros operacionais',
                        style: TFMobileTypography.caption.copyWith(
                          color: TFMobileColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                if (unreadCount > 0) ...[
                  const SizedBox(width: TFMobileSpacing.sm),
                  TFUnreadBadge(count: unreadCount),
                ],
                const SizedBox(width: TFMobileSpacing.xs),
                const Icon(Icons.chevron_right_rounded, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
