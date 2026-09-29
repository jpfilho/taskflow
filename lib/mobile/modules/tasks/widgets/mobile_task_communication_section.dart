import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/tf_mobile_spacing.dart';
import '../../../core/theme/tf_mobile_typography.dart';
import '../../../core/widgets/tf_mobile_buttons.dart';

/// Seção de Comunicação Contextual da Atividade.
/// Abre a conversa pré-existente vinculada à tarefa no Chat do TaskFlow
/// sem criar grupos desnecessários automaticamente.
class MobileTaskCommunicationSection extends StatelessWidget {
  final String? chatGroupId;
  final int unreadCount;
  final VoidCallback onOpenChat;

  const MobileTaskCommunicationSection({
    super.key,
    this.chatGroupId,
    this.unreadCount = 0,
    required this.onOpenChat,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final hasChat = chatGroupId != null && chatGroupId!.isNotEmpty;

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
              const Icon(Icons.chat_bubble_outline_rounded, size: 20.0, color: Color(0xFF3B82F6)),
              const SizedBox(width: TFMobileSpacing.sm),
              Expanded(
                child: Text(
                  'Comunicação da Atividade',
                  style: TFMobileTypography.titleMedium.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (unreadCount > 0) ...[
                const SizedBox(width: TFMobileSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                  decoration: const BoxDecoration(
                    color: Color(0xFFDC2626),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unreadCount.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 10.0, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: TFMobileSpacing.sm),

          if (!hasChat)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: TFMobileSpacing.xs),
              child: Text(
                'Nenhuma conversa vinculada a esta atividade.',
                style: TFMobileTypography.bodyMedium.copyWith(
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Grupo de mensagens ativo com a equipe e supervisão.',
                  style: TFMobileTypography.bodyMedium.copyWith(
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: TFMobileSpacing.md),
                SizedBox(
                  width: double.infinity,
                  height: 48.0,
                  child: TFSecondaryButton(
                    label: 'Abrir Conversa',
                    icon: Icons.forum_outlined,
                    height: 48.0,
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      onOpenChat();
                    },
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
