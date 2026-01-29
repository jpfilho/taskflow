import 'package:flutter/material.dart';
import '../../data/models/media_image.dart';
import '../../data/models/status_album.dart';

class StatusBadge extends StatelessWidget {
  final MediaImageStatus status; // Mantido para compatibilidade
  final StatusAlbum? statusAlbum; // Novo: status da tabela

  const StatusBadge({
    super.key,
    required this.status,
    this.statusAlbum, // Novo
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Priorizar statusAlbum se disponível
    if (statusAlbum != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: statusAlbum!.backgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getIconForStatus(statusAlbum!.nome),
              size: 12,
              color: statusAlbum!.textColor,
            ),
            const SizedBox(width: 4),
            Text(
              statusAlbum!.nome,
              style: TextStyle(
                color: statusAlbum!.textColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    }

    // Fallback para enum antigo
    Color backgroundColor;
    Color textColor;
    IconData icon;
    String label;

    switch (status) {
      case MediaImageStatus.ok:
        backgroundColor = isDark 
            ? const Color(0xFF065f46).withOpacity(0.4) 
            : const Color(0xFFd1fae5);
        textColor = isDark ? const Color(0xFF6ee7b7) : const Color(0xFF065f46);
        icon = Icons.check_circle;
        label = 'Aprovado';
        break;
      case MediaImageStatus.attention:
        backgroundColor = isDark 
            ? const Color(0xFF7f1d1d).withOpacity(0.4) 
            : const Color(0xFFfee2e2);
        textColor = isDark ? const Color(0xFFfca5a5) : const Color(0xFF991b1b);
        icon = Icons.error_outline;
        label = 'Alerta';
        break;
      case MediaImageStatus.review:
        backgroundColor = isDark 
            ? const Color(0xFF78350f).withOpacity(0.4) 
            : const Color(0xFFfef3c7);
        textColor = isDark ? const Color(0xFFfbbf24) : const Color(0xFF92400e);
        icon = Icons.pending_actions;
        label = 'Em Revisão';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForStatus(String nome) {
    final nomeLower = nome.toLowerCase();
    if (nomeLower.contains('ok') || nomeLower.contains('aprovado')) {
      return Icons.check_circle;
    } else if (nomeLower.contains('atenção') || nomeLower.contains('alerta') || nomeLower.contains('erro')) {
      return Icons.error_outline;
    } else {
      return Icons.pending_actions;
    }
  }
}
