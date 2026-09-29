import 'package:flutter/material.dart';
import '../../../core/theme/tf_mobile_spacing.dart';
import '../../../core/theme/tf_mobile_typography.dart';
import '../../../core/theme/tf_mobile_colors.dart';
import 'tf_chat_badges.dart';

/// Item de conversa (Chat individual, grupo de equipe ou chat de atividade).
class TFConversationTile extends StatelessWidget {
  final String title;
  final String lastMessage;
  final String time;
  final String? subtitleTag;
  final int unreadCount;
  final bool hasMention;
  final bool isOnline;
  final VoidCallback onTap;

  const TFConversationTile({
    super.key,
    required this.title,
    required this.lastMessage,
    required this.time,
    this.subtitleTag,
    this.unreadCount = 0,
    this.hasMention = false,
    this.isOnline = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = TFMobileColors.textPrimary(context);
    final textSecondary = TFMobileColors.textSecondary(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TFMobileSpacing.lg,
          vertical: TFMobileSpacing.md,
        ),
        child: Row(
          children: [
            // Avatar com indicador de online
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 24.0,
                  backgroundColor: TFMobileColors.primaryBlue.withOpacity(0.15),
                  child: Text(
                    title.isNotEmpty ? title.substring(0, 1).toUpperCase() : 'T',
                    style: TFMobileTypography.titleLarge.copyWith(
                      color: TFMobileColors.primaryBlue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (isOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12.0,
                      height: 12.0,
                      decoration: BoxDecoration(
                        color: TFMobileColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: TFMobileColors.surface(context),
                          width: 2.0,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: TFMobileSpacing.md),

            // Conteúdo principal
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TFMobileTypography.titleMedium.copyWith(
                            color: textPrimary,
                            fontWeight: unreadCount > 0 ? FontWeight.w700 : FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: TFMobileSpacing.xs),
                      Text(
                        time,
                        style: TFMobileTypography.caption.copyWith(
                          color: unreadCount > 0 ? TFMobileColors.primaryBlue : textSecondary,
                          fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: TFMobileSpacing.xxs),
                  Row(
                    children: [
                      if (subtitleTag != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
                          margin: const EdgeInsets.only(right: 6.0),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4.0),
                          ),
                          child: Text(
                            subtitleTag!,
                            style: TFMobileTypography.caption.copyWith(
                              fontSize: 10.0,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                      Expanded(
                        child: Text(
                          lastMessage,
                          style: TFMobileTypography.bodyMedium.copyWith(
                            color: unreadCount > 0 ? textPrimary : textSecondary,
                            fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasMention) ...[
                        const SizedBox(width: 4.0),
                        const TFMentionBadge(),
                      ],
                      if (unreadCount > 0) ...[
                        const SizedBox(width: 6.0),
                        TFUnreadBadge(count: unreadCount),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
