import 'package:flutter/material.dart';
import '../../../core/theme/tf_mobile_spacing.dart';
import '../../../core/theme/tf_mobile_typography.dart';
import '../../../core/theme/tf_mobile_colors.dart';

/// Status de envio da mensagem no dispositivo móvel.
enum TFMessageDeliveryStatus {
  pendingOffline, // Salva localmente no SQLite, aguardando conexão
  sending, // Transmitindo
  sent, // Enviada ao Supabase
  delivered, // Entregue aos participantes
  failed, // Erro
}

/// Balão de mensagem do TaskFlow Mobile com suporte operacional e offline.
class TFMessageBubble extends StatelessWidget {
  final String text;
  final String time;
  final bool isMe;
  final String? senderName;
  final String? senderRole;
  final TFMessageDeliveryStatus deliveryStatus;
  final String? attachedImageUrl;
  final String? linkedActivityTitle;
  final VoidCallback? onLinkedActivityTap;
  final VoidCallback? onRetry;

  const TFMessageBubble({
    super.key,
    required this.text,
    required this.time,
    required this.isMe,
    this.senderName,
    this.senderRole,
    this.deliveryStatus = TFMessageDeliveryStatus.sent,
    this.attachedImageUrl,
    this.linkedActivityTitle,
    this.onLinkedActivityTap,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = TFMobileColors.surface(context);
    final textPrimary = TFMobileColors.textPrimary(context);

    // Cores do balão: enviada usa azul forte/suave, recebida usa superfície contrastante
    final bubbleBg = isMe
        ? (isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF))
        : (isDark ? const Color(0xFF1E293B) : surfaceColor);

    final bubbleBorder = isMe
        ? (isDark ? const Color(0xFF3B82F6) : const Color(0xFFBFDBFE))
        : TFMobileColors.border(context);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(
          vertical: TFMobileSpacing.xs,
          horizontal: TFMobileSpacing.sm,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        padding: const EdgeInsets.all(TFMobileSpacing.md),
        decoration: BoxDecoration(
          color: bubbleBg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16.0),
            topRight: const Radius.circular(16.0),
            bottomLeft: Radius.circular(isMe ? 16.0 : 4.0),
            bottomRight: Radius.circular(isMe ? 4.0 : 16.0),
          ),
          border: Border.all(color: bubbleBorder, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 4.0,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Identificação do autor (quando for mensagem recebida em grupo)
            if (!isMe && senderName != null) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      senderName!,
                      style: TFMobileTypography.label.copyWith(
                        color: TFMobileColors.primaryBlue,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (senderRole != null) ...[
                    const SizedBox(width: 4.0),
                    Text(
                      '• ${senderRole!}',
                      style: TFMobileTypography.caption.copyWith(
                        color: TFMobileColors.textSecondary(context),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: TFMobileSpacing.xs),
            ],

            // Imagem anexada (simulação ou foto real)
            if (attachedImageUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Container(
                  height: 160.0,
                  width: double.infinity,
                  color: Colors.grey.shade300,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const Center(
                        child: Icon(Icons.image_rounded, size: 48.0, color: Colors.grey),
                      ),
                      if (deliveryStatus == TFMessageDeliveryStatus.pendingOffline)
                        Positioned(
                          top: 8.0,
                          right: 8.0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(6.0),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.cloud_off_rounded, size: 12.0, color: Colors.orange),
                                const SizedBox(width: 4.0),
                                Text(
                                  'Foto offline',
                                  style: TFMobileTypography.caption.copyWith(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: TFMobileSpacing.sm),
            ],

            // Texto da Mensagem
            Text(
              text,
              style: TFMobileTypography.bodyLarge.copyWith(
                color: textPrimary,
              ),
            ),

            // Card compacto de Atividade Vinculada (quando houver)
            if (linkedActivityTitle != null) ...[
              const SizedBox(height: TFMobileSpacing.sm),
              InkWell(
                onTap: onLinkedActivityTap,
                borderRadius: BorderRadius.circular(8.0),
                child: Container(
                  padding: const EdgeInsets.all(TFMobileSpacing.xs),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : Colors.white,
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(
                      color: TFMobileColors.primaryBlue.withOpacity(0.4),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.assignment_outlined, size: 16.0, color: TFMobileColors.primaryBlue),
                      const SizedBox(width: TFMobileSpacing.xs),
                      Expanded(
                        child: Text(
                          linkedActivityTitle!,
                          style: TFMobileTypography.label.copyWith(
                            color: TFMobileColors.primaryBlue,
                            decoration: TextDecoration.underline,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, size: 16.0, color: TFMobileColors.primaryBlue),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: TFMobileSpacing.xs),

            // Rodapé do balão: Horário e Status de Entrega
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  time,
                  style: TFMobileTypography.caption.copyWith(
                    color: TFMobileColors.textSecondary(context),
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4.0),
                  _buildDeliveryIcon(),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryIcon() {
    switch (deliveryStatus) {
      case TFMessageDeliveryStatus.pendingOffline:
        return const Tooltip(
          message: 'Pendente de sincronização (salva offline)',
          child: Icon(Icons.schedule_rounded, size: 14.0, color: TFMobileColors.warning),
        );
      case TFMessageDeliveryStatus.sending:
        return const SizedBox(
          width: 12.0,
          height: 12.0,
          child: CircularProgressIndicator(strokeWidth: 1.5),
        );
      case TFMessageDeliveryStatus.sent:
        return const Icon(Icons.check_rounded, size: 14.0, color: Colors.grey);
      case TFMessageDeliveryStatus.delivered:
        return const Icon(Icons.done_all_rounded, size: 15.0, color: TFMobileColors.primaryBlue);
      case TFMessageDeliveryStatus.failed:
        return InkWell(
          onTap: onRetry,
          child: const Icon(Icons.error_outline_rounded, size: 14.0, color: TFMobileColors.error),
        );
    }
  }
}
