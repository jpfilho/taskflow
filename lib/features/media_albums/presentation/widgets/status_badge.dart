import 'package:flutter/material.dart';
import '../../../../design_system/components/status/tf_status_badge.dart';
import '../../../../design_system/foundations/tf_radius.dart';
import '../../../../design_system/theme/taskflow_theme_extension.dart';
import '../../data/models/media_image.dart';
import '../../data/models/status_album.dart';

class StatusBadge extends StatelessWidget {
  final MediaImageStatus status; // Mantido para compatibilidade
  final StatusAlbum? statusAlbum; // Novo: status da tabela

  const StatusBadge({
    super.key,
    required this.status,
    this.statusAlbum,
  });

  static TFStatusSeverity mapSeverity(String? nome) {
    final n = (nome ?? '').toLowerCase().trim();
    if (n.contains('ok') || n.contains('aprovad') || n.contains('conclu')) {
      return TFStatusSeverity.success;
    }
    if (n.contains('atenção') || n.contains('alerta') || n.contains('erro') || n.contains('rejeit')) {
      return TFStatusSeverity.danger;
    }
    if (n.contains('revis') || n.contains('pendent') || n.contains('aguard')) {
      return TFStatusSeverity.warning;
    }
    return TFStatusSeverity.neutral;
  }

  @override
  Widget build(BuildContext context) {
    final typography = context.tfTypography;

    // Priorizar statusAlbum se disponível
    if (statusAlbum != null) {
      if (statusAlbum!.corFundo != null && statusAlbum!.corFundo!.isNotEmpty) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: statusAlbum!.backgroundColor,
            borderRadius: TFRadius.borderRadiusFull,
          ),
          child: Text(
            statusAlbum!.nome,
            style: typography.caption.copyWith(
              color: statusAlbum!.textColor,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
        );
      }

      return TFStatusBadge(
        label: statusAlbum!.nome,
        severity: mapSeverity(statusAlbum!.nome),
      );
    }

    // Fallback para enum antigo
    switch (status) {
      case MediaImageStatus.ok:
        return const TFStatusBadge(
          label: 'Aprovado',
          severity: TFStatusSeverity.success,
        );
      case MediaImageStatus.attention:
        return const TFStatusBadge(
          label: 'Alerta',
          severity: TFStatusSeverity.danger,
        );
      case MediaImageStatus.review:
        return const TFStatusBadge(
          label: 'Em Revisão',
          severity: TFStatusSeverity.warning,
        );
    }
  }
}
