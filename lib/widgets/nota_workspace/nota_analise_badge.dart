import 'package:flutter/material.dart';
import '../../design_system/taskflow_design_system.dart';
import '../../models/nota_sap_analise.dart';

/// Widget visual para exibição compacta e informativa do status da análise prévia
/// e contadores de anexos, comentários técnicos e materiais levantados.
class NotaAnaliseBadge extends StatelessWidget {
  final NotaSapResumoAnalise? resumo;
  final VoidCallback? onTapStatus;
  final VoidCallback? onTapAnexos;
  final VoidCallback? onTapComentarios;
  final VoidCallback? onTapMateriais;
  final VoidCallback? onTapGlobal;
  final bool compact;

  const NotaAnaliseBadge({
    super.key,
    this.resumo,
    this.onTapStatus,
    this.onTapAnexos,
    this.onTapComentarios,
    this.onTapMateriais,
    this.onTapGlobal,
    this.compact = false,
  });

  Color _getStatusColor(NotaAnaliseStatus status) {
    switch (status) {
      case NotaAnaliseStatus.naoIniciada:
        return Colors.grey.shade600;
      case NotaAnaliseStatus.emAnalise:
        return Colors.blue.shade700;
      case NotaAnaliseStatus.concluida:
        return Colors.green.shade700;
      case NotaAnaliseStatus.aguardandoInformacao:
        return Colors.orange.shade800;
      case NotaAnaliseStatus.cancelada:
        return Colors.red.shade700;
    }
  }

  String _getStatusLabel(NotaAnaliseStatus status, {bool isNull = false}) {
    if (isNull) return 'Sem análise';
    switch (status) {
      case NotaAnaliseStatus.naoIniciada:
        return 'Não iniciada';
      case NotaAnaliseStatus.emAnalise:
        return 'Em análise';
      case NotaAnaliseStatus.concluida:
        return 'Concluída';
      case NotaAnaliseStatus.aguardandoInformacao:
        return 'Aguardando info';
      case NotaAnaliseStatus.cancelada:
        return 'Cancelada';
    }
  }

  IconData _getStatusIcon(NotaAnaliseStatus status) {
    switch (status) {
      case NotaAnaliseStatus.naoIniciada:
        return Icons.radio_button_unchecked;
      case NotaAnaliseStatus.emAnalise:
        return Icons.timelapse_rounded;
      case NotaAnaliseStatus.concluida:
        return Icons.check_circle_rounded;
      case NotaAnaliseStatus.aguardandoInformacao:
        return Icons.error_outline_rounded;
      case NotaAnaliseStatus.cancelada:
        return Icons.cancel_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    final status = resumo?.status ?? NotaAnaliseStatus.naoIniciada;
    final statusColor = _getStatusColor(status);
    final statusLabel = _getStatusLabel(status, isNull: resumo == null);
    final statusIcon = _getStatusIcon(status);

    final anexos = resumo?.quantidadeAnexos ?? 0;
    final comentarios = resumo?.quantidadeComentarios ?? 0;
    final materiais = resumo?.quantidadeMateriais ?? 0;

    return InkWell(
      onTap: onTapGlobal ?? onTapStatus,
      borderRadius: BorderRadius.circular(TFRadius.r8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Status Principal da Análise
            Tooltip(
              message: 'Status da análise técnica: $statusLabel. Clique para abrir.',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: status == NotaAnaliseStatus.naoIniciada
                      ? colors.surfaceSecondary
                      : statusColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(TFRadius.r8),
                  border: Border.all(
                    color: status == NotaAnaliseStatus.naoIniciada
                        ? colors.borderSubtle
                        : statusColor.withAlpha(80),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      statusIcon,
                      size: 13,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: typography.caption.copyWith(
                        color: status == NotaAnaliseStatus.naoIniciada
                            ? colors.textSecondary
                            : statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 11.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. Indicador de Anexos
            if (anexos > 0) ...[
              SizedBox(width: spacing.xs),
              Tooltip(
                message: '$anexos anexo(s) cadastrado(s). Clique para ver.',
                child: InkWell(
                  onTap: onTapAnexos ?? onTapGlobal,
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: colors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: colors.borderSubtle),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.attach_file,
                          size: 13,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '$anexos',
                          style: typography.caption.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 11.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            // 3. Indicador de Comentários Técnicos
            if (comentarios > 0) ...[
              SizedBox(width: spacing.xs),
              Tooltip(
                message: '$comentarios comentário(s) técnico(s). Clique para ver discussão.',
                child: InkWell(
                  onTap: onTapComentarios ?? onTapGlobal,
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: colors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: colors.borderSubtle),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 13,
                          color: colors.textSecondary,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '$comentarios',
                          style: typography.caption.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 11.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            // 4. Indicador de Materiais (se houver)
            if (materiais > 0) ...[
              SizedBox(width: spacing.xs),
              Tooltip(
                message: '$materiais material(is) registrado(s). Clique para ver materiais.',
                child: InkWell(
                  onTap: onTapMateriais ?? onTapGlobal,
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: colors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: colors.borderSubtle),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 13,
                          color: colors.textSecondary,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '$materiais',
                          style: typography.caption.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 11.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
