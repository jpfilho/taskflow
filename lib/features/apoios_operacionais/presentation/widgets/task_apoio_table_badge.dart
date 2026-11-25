import 'package:flutter/material.dart';
import '../../../../design_system/taskflow_design_system.dart';
import '../../../../models/task.dart';
import '../../domain/models/task_apoio_situacao.dart';
import '../task_apoio_status_mapper.dart';
import '../task_apoio_ui_controller.dart';
import 'task_apoio_view_section.dart';

/// Indicador compacto exibido na coluna configurável "Apoios" da `TaskTable` (Itens 19 e 20).
class TaskApoioTableBadge extends StatelessWidget {
  final Task task;
  final TaskApoioResumo? resumo;
  final TaskApoioUiController controller;
  final String usuarioAtualId;
  final String? usuarioAtualNome;

  const TaskApoioTableBadge({
    super.key,
    required this.task,
    required this.resumo,
    required this.controller,
    required this.usuarioAtualId,
    this.usuarioAtualNome,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final r = resumo;

    if (controller.isBackendProtegido && r == null) {
      return Tooltip(
        message: 'Apoios protegidos (aguardando autenticação)',
        child: Icon(
          Icons.lock_outline_rounded,
          size: 16,
          color: colors.textSecondary,
        ),
      );
    }

    if (r == null ||
        (r.totalSolicitacoes == 0 && r.qtdAtividadesApoiadas == 0)) {
      // Ausência de apoios é representada de forma neutra (Item 19)
      return Text(
        '—',
        style: context.tfTypography.bodySmall.copyWith(
          color: colors.textSecondary,
        ),
      );
    }

    final badgeInfo = TaskApoioStatusMapper.paraSituacaoGerencial(
      r.situacaoGerencial,
      totalSolicitacoes: r.totalSolicitacoes,
      qtdApoiadas: r.qtdAtividadesApoiadas,
    );

    final confirmados =
        (r.totalSolicitacoes - r.qtdAguardandoResposta).clamp(0, r.totalSolicitacoes);
    final solicitouApoio = r.totalSolicitacoes > 0;
    final prestaApoio = r.qtdAtividadesApoiadas > 0;

    final String tooltipMsg;
    if (solicitouApoio && prestaApoio) {
      tooltipMsg =
          'Solicitou apoio: ${badgeInfo.label} ($confirmados/${r.totalSolicitacoes}) • Também apoia ${r.qtdAtividadesApoiadas} atividade(s)';
    } else if (solicitouApoio) {
      tooltipMsg =
          'Solicitou apoio: ${badgeInfo.label} ($confirmados/${r.totalSolicitacoes})';
    } else {
      tooltipMsg = 'Apoio solicitado por outro setor (${r.qtdAtividadesApoiadas})';
    }

    final IconData direcaoIcon = solicitouApoio && prestaApoio
        ? Icons.swap_horiz_rounded
        : (solicitouApoio
            ? Icons.north_east_rounded
            : Icons.south_west_rounded);
    final Color mainColor = _corPorSeveridade(colors, badgeInfo.severity);

    return Tooltip(
      message: tooltipMsg,
      child: InkWell(
        borderRadius: TFRadius.borderRadiusSm,
        onTap: () => _abrirResumoDialog(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: SizedBox(
            width: 24,
            height: 22,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Icon(
                    badgeInfo.icon,
                    size: 17,
                    color: mainColor,
                  ),
                ),
                Positioned(
                  right: -1,
                  top: -1,
                  child: Container(
                    padding: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      direcaoIcon,
                      size: 10,
                      color: mainColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _corPorSeveridade(TFSemanticColors colors, TFStatusSeverity severity) {
    switch (severity) {
      case TFStatusSeverity.success:
        return colors.success;
      case TFStatusSeverity.warning:
        return colors.warning;
      case TFStatusSeverity.danger:
        return colors.danger;
      case TFStatusSeverity.info:
        return colors.info;
      case TFStatusSeverity.neutral:
        return colors.textSecondary;
    }
  }

  void _abrirResumoDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Apoios — ${task.tarefa}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        content: SizedBox(
          width: (MediaQuery.sizeOf(ctx).width - 48).clamp(280.0, 680.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.72,
            ),
            child: SingleChildScrollView(
              child: TaskApoioViewSection(
                task: task,
                controller: controller,
                usuarioAtualId: usuarioAtualId,
                usuarioAtualNome: usuarioAtualNome,
              ),
            ),
          ),
        ),
        actions: [
          TFButton(
            label: 'Fechar',
            variant: TFButtonVariant.tertiary,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }
}
