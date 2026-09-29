import 'package:flutter/material.dart';
import '../../../core/theme/tf_mobile_spacing.dart';
import '../../../core/theme/tf_mobile_typography.dart';
import '../../../core/theme/tf_mobile_colors.dart';
import '../../../core/theme/tf_mobile_touch_targets.dart';

/// Barra de entrada de mensagens do TaskFlow Mobile com suporte extensível a multimídia e reply.
class TFChatInput extends StatefulWidget {
  final ValueChanged<String> onSend;
  final VoidCallback? onCameraTap;
  final VoidCallback? onAttachmentTap;
  final VoidCallback? onVoiceTap;
  final String? replyToAuthor;
  final String? replyToText;
  final VoidCallback? onCancelReply;
  final bool isOfflinePending;

  const TFChatInput({
    super.key,
    required this.onSend,
    this.onCameraTap,
    this.onAttachmentTap,
    this.onVoiceTap,
    this.replyToAuthor,
    this.replyToText,
    this.onCancelReply,
    this.isOfflinePending = false,
  });

  @override
  State<TFChatInput> createState() => _TFChatInputState();
}

class _TFChatInputState extends State<TFChatInput> {
  final TextEditingController _controller = TextEditingController();
  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final can = _controller.text.trim().isNotEmpty;
      if (can != _canSend) {
        setState(() {
          _canSend = can;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = TFMobileColors.surface(context);
    final borderColor = TFMobileColors.border(context);
    final textPrimary = TFMobileColors.textPrimary(context);

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(top: BorderSide(color: borderColor, width: 1.0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6.0,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Banner de Reply / Resposta se houver
            if (widget.replyToAuthor != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: TFMobileSpacing.md,
                  vertical: TFMobileSpacing.xs,
                ),
                color: TFMobileColors.primaryBlue.withOpacity(0.08),
                child: Row(
                  children: [
                    const Icon(Icons.reply_rounded, size: 18.0, color: TFMobileColors.primaryBlue),
                    const SizedBox(width: TFMobileSpacing.xs),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Respondendo a ${widget.replyToAuthor!}',
                            style: TFMobileTypography.label.copyWith(
                              color: TFMobileColors.primaryBlue,
                            ),
                          ),
                          if (widget.replyToText != null)
                            Text(
                              widget.replyToText!,
                              style: TFMobileTypography.caption,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18.0),
                      onPressed: widget.onCancelReply,
                      splashRadius: 18.0,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1.0),
            ],

            // Indicador de mensagem que será salva offline
            if (widget.isOfflinePending) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: TFMobileSpacing.md, vertical: 2.0),
                color: const Color(0xFFFEF3C7),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off_rounded, size: 12.0, color: Color(0xFFB45309)),
                    const SizedBox(width: 4.0),
                    Text(
                      'Sem conexão: a mensagem será enfileirada e enviada automaticamente.',
                      style: TFMobileTypography.caption.copyWith(color: const Color(0xFFB45309)),
                    ),
                  ],
                ),
              ),
            ],

            // Linha de Digitação e Ações de Mídia
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: TFMobileSpacing.sm,
                vertical: TFMobileSpacing.xs,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Ação Câmera Rápida (≥48px)
                  SizedBox(
                    width: TFMobileTouchTargets.min,
                    height: TFMobileTouchTargets.min,
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt_outlined),
                      color: TFMobileColors.primaryBlue,
                      onPressed: widget.onCameraTap,
                      tooltip: 'Tirar Foto',
                      splashRadius: 24.0,
                    ),
                  ),

                  // Ação Anexar Documento / Evidência (≥48px)
                  SizedBox(
                    width: TFMobileTouchTargets.min,
                    height: TFMobileTouchTargets.min,
                    child: IconButton(
                      icon: const Icon(Icons.attach_file_rounded),
                      color: TFMobileColors.textSecondary(context),
                      onPressed: widget.onAttachmentTap,
                      tooltip: 'Anexar Evidência',
                      splashRadius: 24.0,
                    ),
                  ),

                  // Campo de Texto Multiline
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: 44.0,
                        maxHeight: 120.0,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: TFMobileSpacing.sm),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF0F172A)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(22.0),
                        border: Border.all(color: borderColor),
                      ),
                      child: TextField(
                        controller: _controller,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        style: TFMobileTypography.bodyLarge.copyWith(color: textPrimary),
                        decoration: InputDecoration(
                          hintText: widget.isOfflinePending ? 'Mensagem (offline)...' : 'Digite uma mensagem...',
                          hintStyle: TFMobileTypography.bodyMedium.copyWith(color: Colors.grey.shade500),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: TFMobileSpacing.xs,
                            vertical: 10.0,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: TFMobileSpacing.xs),

                  // Botão de Envio ou Áudio (≥48px)
                  SizedBox(
                    width: TFMobileTouchTargets.min,
                    height: TFMobileTouchTargets.min,
                    child: _canSend
                        ? IconButton(
                            icon: const Icon(Icons.send_rounded),
                            color: TFMobileColors.primaryBlue,
                            iconSize: 24.0,
                            onPressed: _handleSend,
                            tooltip: 'Enviar Mensagem',
                            splashRadius: 24.0,
                          )
                        : IconButton(
                            icon: const Icon(Icons.mic_none_rounded),
                            color: TFMobileColors.textSecondary(context),
                            iconSize: 24.0,
                            onPressed: widget.onVoiceTap,
                            tooltip: 'Gravar Áudio Operacional',
                            splashRadius: 24.0,
                          ),
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
