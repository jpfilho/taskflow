import 'package:flutter/material.dart';
import '../../../../design_system/components/status/tf_status_badge.dart';
import '../../../../design_system/foundations/tf_radius.dart';
import '../../../../design_system/theme/taskflow_theme_extension.dart';
import '../../data/models/document_status.dart';

class DocumentStatusBadge extends StatelessWidget {
  final DocumentStatus? status;
  final EdgeInsets? padding;

  const DocumentStatusBadge({
    super.key,
    required this.status,
    this.padding,
  });

  static TFStatusSeverity mapSeverity(String? nome) {
    final n = (nome ?? '').toLowerCase().trim();
    if (n.contains('aprovad') || n.contains('conclu') || n.contains('publicad') || n.contains('vigente') || n.contains('ativo')) {
      return TFStatusSeverity.success;
    }
    if (n.contains('pendent') || n.contains('analis') || n.contains('revis') || n.contains('aguard')) {
      return TFStatusSeverity.warning;
    }
    if (n.contains('rejeit') || n.contains('cancelad') || n.contains('vencid') || n.contains('expirad')) {
      return TFStatusSeverity.danger;
    }
    if (n.contains('rascunh') || n.contains('elabora')) {
      return TFStatusSeverity.info;
    }
    return TFStatusSeverity.neutral;
  }

  @override
  Widget build(BuildContext context) {
    if (status == null) {
      return const SizedBox.shrink();
    }

    final typography = context.tfTypography;

    // Se possui cores personalizadas definidas no modelo, renderiza respeitando os tokens
    if (status!.corFundo != null && status!.corFundo!.isNotEmpty) {
      return Container(
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: status!.backgroundColor,
          borderRadius: TFRadius.borderRadiusFull,
        ),
        child: Text(
          status!.nome,
          style: typography.caption.copyWith(
            color: status!.textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return TFStatusBadge(
      label: status!.nome,
      severity: mapSeverity(status!.nome),
    );
  }
}
