import 'package:flutter/material.dart';

import '../../../../design_system/taskflow_design_system.dart';
import '../notificacoes_controller.dart';

/// Ícone de sino no cabeçalho principal para Notificações Operacionais Internas.
/// Mantém contagem estritamente separada do `unreadChatCount` do Chat.
class NotificacoesBellButton extends StatelessWidget {
  final NotificacoesController controller;
  final VoidCallback onPressed;

  const NotificacoesBellButton({
    super.key,
    required this.controller,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final count = controller.naoLidas;
        final colors = context.tfColors;
        return Tooltip(
          message: count > 0
              ? 'Notificações operacionais ($count não lida${count > 1 ? 's' : ''})'
              : 'Notificações operacionais',
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: Icon(
                  count > 0
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_outlined,
                  color: count > 0 ? colors.primary : colors.textSecondary,
                ),
                onPressed: onPressed,
              ),
              if (count > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: colors.danger,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(minWidth: 16),
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
