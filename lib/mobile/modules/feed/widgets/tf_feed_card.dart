import 'package:flutter/material.dart';
import '../../../core/theme/tf_mobile_spacing.dart';
import '../../../core/theme/tf_mobile_typography.dart';
import '../../../core/theme/tf_mobile_colors.dart';
import '../../chat/widgets/tf_chat_badges.dart';
import 'tf_feed_models.dart';

/// Card oficial do Feed Operacional do TaskFlow Mobile.
/// Trata de forma diferenciada Publicações de Usuários vs. Eventos Automáticos do Sistema.
class TFFeedCard extends StatelessWidget {
  final TFFeedItem item;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onViewLinkedEntity;
  final VoidCallback? onImageTap;

  const TFFeedCard({
    super.key,
    required this.item,
    this.onLike,
    this.onComment,
    this.onViewLinkedEntity,
    this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    if (item.isAutomatedEvent) {
      return _buildAutomatedEventCard(context);
    }
    return _buildUserPostCard(context);
  }

  /// 1. Card de Evento Automático Operacional (Compacto e Direto)
  Widget _buildAutomatedEventCard(BuildContext context) {
    final surfaceColor = TFMobileColors.surface(context);
    final borderColor = TFMobileColors.border(context);
    final textPrimary = TFMobileColors.textPrimary(context);
    final textSecondary = TFMobileColors.textSecondary(context);

    // Ícone e cores conforme o tipo de evento
    IconData eventIcon;
    Color accentColor;
    Color iconBg;

    if (item.sourceType == TFFeedSourceType.safetyNotice) {
      eventIcon = Icons.shield_rounded;
      accentColor = TFMobileColors.error;
      iconBg = TFMobileColors.errorBg;
    } else if (item.content.toLowerCase().contains('concluída')) {
      eventIcon = Icons.check_circle_rounded;
      accentColor = TFMobileColors.success;
      iconBg = TFMobileColors.successBg;
    } else {
      eventIcon = Icons.play_circle_fill_rounded;
      accentColor = TFMobileColors.primaryBlue;
      iconBg = TFMobileColors.infoBg;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: TFMobileSpacing.sm),
      padding: const EdgeInsets.all(TFMobileSpacing.md),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ícone do evento
          Container(
            width: 38.0,
            height: 38.0,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(eventIcon, size: 20.0, color: accentColor),
          ),
          const SizedBox(width: TFMobileSpacing.md),

          // Informações do evento
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.content,
                        style: TFMobileTypography.titleMedium.copyWith(
                          color: textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: TFMobileSpacing.xs),
                    Text(
                      item.timestamp,
                      style: TFMobileTypography.caption.copyWith(color: textSecondary),
                    ),
                  ],
                ),
                if (item.linkedEntityTitle != null) ...[
                  const SizedBox(height: 2.0),
                  Text(
                    item.linkedEntityTitle!,
                    style: TFMobileTypography.bodyMedium.copyWith(
                      color: textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 2.0),
                Text(
                  '${item.authorName} • ${item.communityOrTeam ?? 'Sistema'}',
                  style: TFMobileTypography.caption.copyWith(
                    color: textSecondary,
                  ),
                ),
                if (item.linkedEntityTitle != null && onViewLinkedEntity != null) ...[
                  const SizedBox(height: TFMobileSpacing.xs),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: InkWell(
                      onTap: onViewLinkedEntity,
                      borderRadius: BorderRadius.circular(4.0),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 4.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Ver atividade',
                              style: TFMobileTypography.label.copyWith(
                                color: TFMobileColors.primaryBlue,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, size: 16.0, color: TFMobileColors.primaryBlue),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 2. Card de Publicação Humana (Rico: Autor, Avatar, Imagem, Interações)
  Widget _buildUserPostCard(BuildContext context) {
    final surfaceColor = TFMobileColors.surface(context);
    final borderColor = TFMobileColors.border(context);
    final textPrimary = TFMobileColors.textPrimary(context);
    final textSecondary = TFMobileColors.textSecondary(context);

    return Container(
      margin: const EdgeInsets.only(bottom: TFMobileSpacing.md),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho da Publicação: Avatar + Autor + Comunidade + Timestamp
          Padding(
            padding: const EdgeInsets.all(TFMobileSpacing.md),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20.0,
                  backgroundColor: TFMobileColors.primaryBlue.withOpacity(0.12),
                  child: Text(
                    item.authorName.isNotEmpty ? item.authorName.substring(0, 1).toUpperCase() : 'U',
                    style: TFMobileTypography.titleMedium.copyWith(
                      color: TFMobileColors.primaryBlue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: TFMobileSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.authorName,
                        style: TFMobileTypography.titleMedium.copyWith(
                          color: textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${item.communityOrTeam ?? 'Geral'} • ${item.timestamp}',
                        style: TFMobileTypography.caption.copyWith(color: textSecondary),
                      ),
                    ],
                  ),
                ),
                if (item.isOfflinePending)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6.0),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.schedule_rounded, size: 12.0, color: Color(0xFFB45309)),
                        const SizedBox(width: 4.0),
                        Text(
                          'Pendente',
                          style: TFMobileTypography.caption.copyWith(
                            color: const Color(0xFFB45309),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Conteúdo do Texto
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: TFMobileSpacing.md),
            child: Text(
              item.content,
              style: TFMobileTypography.bodyLarge.copyWith(color: textPrimary),
            ),
          ),

          // Foto de Serviço ou Evidência
          if (item.imageUrl != null) ...[
            const SizedBox(height: TFMobileSpacing.md),
            InkWell(
              onTap: onImageTap,
              child: Container(
                height: 200.0,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  border: Border.symmetric(
                    horizontal: BorderSide(color: borderColor, width: 1.0),
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.photo_camera_rounded, size: 48.0, color: Colors.grey.shade600),
                          const SizedBox(height: 4.0),
                          Text(
                            'Evidência Fotográfica do Serviço',
                            style: TFMobileTypography.caption.copyWith(color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Vínculo com Atividade / Demanda
          if (item.linkedEntityTitle != null) ...[
            const SizedBox(height: TFMobileSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: TFMobileSpacing.md),
              child: InkWell(
                onTap: onViewLinkedEntity,
                borderRadius: BorderRadius.circular(8.0),
                child: Container(
                  padding: const EdgeInsets.all(TFMobileSpacing.sm),
                  decoration: BoxDecoration(
                    color: TFMobileColors.primaryBlue.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(
                      color: TFMobileColors.primaryBlue.withOpacity(0.3),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.assignment_turned_in_rounded, size: 18.0, color: TFMobileColors.primaryBlue),
                      const SizedBox(width: TFMobileSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Atividade vinculada:',
                              style: TFMobileTypography.caption.copyWith(color: TFMobileColors.primaryBlue),
                            ),
                            Text(
                              item.linkedEntityTitle!,
                              style: TFMobileTypography.label.copyWith(
                                color: textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, size: 18.0, color: TFMobileColors.primaryBlue),
                    ],
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: TFMobileSpacing.sm),
          const Divider(height: 1.0),

          // Barra de Interação: Reações e Comentários (Touch Targets confortáveis)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: TFMobileSpacing.md,
              vertical: TFMobileSpacing.xs,
            ),
            child: Row(
              children: [
                TFReactionButton(
                  emoji: '👍',
                  count: item.likesCount,
                  isSelected: item.isLikedByMe,
                  onTap: onLike ?? () {},
                ),
                const SizedBox(width: TFMobileSpacing.sm),
                InkWell(
                  onTap: onComment,
                  borderRadius: BorderRadius.circular(16.0),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 32.0),
                    padding: const EdgeInsets.symmetric(horizontal: TFMobileSpacing.sm, vertical: 4.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16.0),
                      border: Border.all(color: borderColor, width: 1.2),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.chat_bubble_outline_rounded, size: 14.0),
                        const SizedBox(width: 4.0),
                        Text(
                          item.commentsCount > 0 ? '${item.commentsCount} comentários' : 'Comentar',
                          style: TFMobileTypography.label.copyWith(
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
