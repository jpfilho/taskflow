import 'package:flutter/material.dart';
import '../../../design_system/components/status/tf_status_badge.dart';
import '../domain/enums/task_apoio_enums.dart';

/// Metadados visuais acessíveis (rótulo amigável, severidade e ícone) para
/// garantir que nenhuma situação dependa apenas de cor ou exponha enums crus.
class TaskApoioBadgeInfo {
  final String label;
  final TFStatusSeverity severity;
  final IconData icon;

  const TaskApoioBadgeInfo({
    required this.label,
    required this.severity,
    required this.icon,
  });
}

class TaskApoioStatusMapper {
  static TaskApoioBadgeInfo paraSituacaoOperacional(
    TaskApoioSituacaoOperacional sit,
  ) {
    switch (sit) {
      case TaskApoioSituacaoOperacional.aguardandoAnalise:
        return const TaskApoioBadgeInfo(
          label: 'Aguardando resposta',
          severity: TFStatusSeverity.warning,
          icon: Icons.hourglass_empty_rounded,
        );
      case TaskApoioSituacaoOperacional.emNegociacao:
        return const TaskApoioBadgeInfo(
          label: 'Em negociação',
          severity: TFStatusSeverity.info,
          icon: Icons.swap_horiz_rounded,
        );
      case TaskApoioSituacaoOperacional.recusada:
        return const TaskApoioBadgeInfo(
          label: 'Recusado',
          severity: TFStatusSeverity.danger,
          icon: Icons.cancel_outlined,
        );
      case TaskApoioSituacaoOperacional.cancelada:
        return const TaskApoioBadgeInfo(
          label: 'Cancelado',
          severity: TFStatusSeverity.neutral,
          icon: Icons.block_rounded,
        );
      case TaskApoioSituacaoOperacional.aceitaSemProgramacao:
        return const TaskApoioBadgeInfo(
          label: 'Aceito, aguardando programação',
          severity: TFStatusSeverity.warning,
          icon: Icons.event_busy_outlined,
        );
      case TaskApoioSituacaoOperacional.parcialmenteProgramada:
        return const TaskApoioBadgeInfo(
          label: 'Parcialmente programado',
          severity: TFStatusSeverity.warning,
          icon: Icons.timelapse_rounded,
        );
      case TaskApoioSituacaoOperacional.programadaComIncompatibilidade:
        return const TaskApoioBadgeInfo(
          label: 'Programado com incompatibilidade',
          severity: TFStatusSeverity.danger,
          icon: Icons.warning_amber_rounded,
        );
      case TaskApoioSituacaoOperacional.programadaComRecursosPendentes:
        return const TaskApoioBadgeInfo(
          label: 'Programado com recursos pendentes',
          severity: TFStatusSeverity.warning,
          icon: Icons.build_circle_outlined,
        );
      case TaskApoioSituacaoOperacional.programadaComRecursosNaoVerificados:
        return const TaskApoioBadgeInfo(
          label: 'Programado com recursos não verificados',
          severity: TFStatusSeverity.info,
          icon: Icons.help_outline_rounded,
        );
      case TaskApoioSituacaoOperacional.programadaCompativel:
        return const TaskApoioBadgeInfo(
          label: 'Programado e compatível',
          severity: TFStatusSeverity.success,
          icon: Icons.check_circle_outline_rounded,
        );
      case TaskApoioSituacaoOperacional.emAndamento:
        return const TaskApoioBadgeInfo(
          label: 'Em andamento',
          severity: TFStatusSeverity.info,
          icon: Icons.play_circle_outline_rounded,
        );
      case TaskApoioSituacaoOperacional.concluida:
        return const TaskApoioBadgeInfo(
          label: 'Concluído',
          severity: TFStatusSeverity.success,
          icon: Icons.task_alt_rounded,
        );
    }
  }

  static TaskApoioBadgeInfo paraStatusNegociacao(TaskApoioStatus status) {
    switch (status) {
      case TaskApoioStatus.pendente:
        return const TaskApoioBadgeInfo(
          label: 'Aguardando resposta',
          severity: TFStatusSeverity.warning,
          icon: Icons.hourglass_empty_rounded,
        );
      case TaskApoioStatus.emAnalise:
        return const TaskApoioBadgeInfo(
          label: 'Em análise',
          severity: TFStatusSeverity.info,
          icon: Icons.manage_search_rounded,
        );
      case TaskApoioStatus.contraproposta:
        return const TaskApoioBadgeInfo(
          label: 'Contraproposta recebida',
          severity: TFStatusSeverity.info,
          icon: Icons.swap_horiz_rounded,
        );
      case TaskApoioStatus.aceita:
        return const TaskApoioBadgeInfo(
          label: 'Aceita',
          severity: TFStatusSeverity.success,
          icon: Icons.thumb_up_alt_outlined,
        );
      case TaskApoioStatus.recusada:
        return const TaskApoioBadgeInfo(
          label: 'Recusada',
          severity: TFStatusSeverity.danger,
          icon: Icons.cancel_outlined,
        );
      case TaskApoioStatus.cancelada:
        return const TaskApoioBadgeInfo(
          label: 'Cancelada',
          severity: TFStatusSeverity.neutral,
          icon: Icons.block_rounded,
        );
      case TaskApoioStatus.desconhecido:
        return const TaskApoioBadgeInfo(
          label: 'Status não reconhecido',
          severity: TFStatusSeverity.neutral,
          icon: Icons.help_outline_rounded,
        );
    }
  }

  static TaskApoioBadgeInfo paraSituacaoGerencial(
    TaskApoioSituacaoGerencial sit, {
    int totalSolicitacoes = 0,
    int qtdApoiadas = 0,
  }) {
    if (totalSolicitacoes == 0 && qtdApoiadas > 0) {
      return TaskApoioBadgeInfo(
        label: 'Presta apoio ($qtdApoiadas)',
        severity: TFStatusSeverity.info,
        icon: Icons.handshake_outlined,
      );
    }
    switch (sit) {
      case TaskApoioSituacaoGerencial.semDependencias:
        return const TaskApoioBadgeInfo(
          label: 'Sem apoios',
          severity: TFStatusSeverity.neutral,
          icon: Icons.remove_circle_outline,
        );
      case TaskApoioSituacaoGerencial.apenasComplementares:
        return const TaskApoioBadgeInfo(
          label: 'Apoios complementares',
          severity: TFStatusSeverity.info,
          icon: Icons.info_outline_rounded,
        );
      case TaskApoioSituacaoGerencial.aguardandoConfirmacaoEssencial:
        return const TaskApoioBadgeInfo(
          label: 'Apoios pendentes',
          severity: TFStatusSeverity.warning,
          icon: Icons.hourglass_top_rounded,
        );
      case TaskApoioSituacaoGerencial.essencialAceitoSemProgramacao:
        return const TaskApoioBadgeInfo(
          label: 'Aceito s/ programação',
          severity: TFStatusSeverity.warning,
          icon: Icons.event_busy_outlined,
        );
      case TaskApoioSituacaoGerencial.essencialParcialmenteProgramado:
        return const TaskApoioBadgeInfo(
          label: 'Parcialmente programado',
          severity: TFStatusSeverity.warning,
          icon: Icons.timelapse_rounded,
        );
      case TaskApoioSituacaoGerencial.programacaoComRiscoApoio:
        return const TaskApoioBadgeInfo(
          label: 'Em risco — apoio',
          severity: TFStatusSeverity.danger,
          icon: Icons.warning_amber_rounded,
        );
      case TaskApoioSituacaoGerencial.essenciaisProgramadosCompativeis:
        return const TaskApoioBadgeInfo(
          label: 'Apoios confirmados',
          severity: TFStatusSeverity.success,
          icon: Icons.check_circle_outline_rounded,
        );
      case TaskApoioSituacaoGerencial.essenciaisConcluidos:
        return const TaskApoioBadgeInfo(
          label: 'Apoios concluídos',
          severity: TFStatusSeverity.success,
          icon: Icons.task_alt_rounded,
        );
    }
  }

  static TaskApoioBadgeInfo paraSyncStatus(TaskApoioSyncStatus sync) {
    switch (sync) {
      case TaskApoioSyncStatus.confirmadoServidor:
        return const TaskApoioBadgeInfo(
          label: 'Confirmado',
          severity: TFStatusSeverity.success,
          icon: Icons.cloud_done_outlined,
        );
      case TaskApoioSyncStatus.pendenteSync:
        return const TaskApoioBadgeInfo(
          label: 'Pendente de envio',
          severity: TFStatusSeverity.warning,
          icon: Icons.cloud_upload_outlined,
        );
      case TaskApoioSyncStatus.emProcessamento:
        return const TaskApoioBadgeInfo(
          label: 'Sincronizando',
          severity: TFStatusSeverity.info,
          icon: Icons.sync_rounded,
        );
      case TaskApoioSyncStatus.rejeitado:
        return const TaskApoioBadgeInfo(
          label: 'Rejeitado',
          severity: TFStatusSeverity.danger,
          icon: Icons.error_outline_rounded,
        );
      case TaskApoioSyncStatus.conflitoVersao:
        return const TaskApoioBadgeInfo(
          label: 'Conflito de versão',
          severity: TFStatusSeverity.danger,
          icon: Icons.merge_type_rounded,
        );
      case TaskApoioSyncStatus.exigeConexao:
        return const TaskApoioBadgeInfo(
          label: 'Exige conexão',
          severity: TFStatusSeverity.warning,
          icon: Icons.wifi_off_rounded,
        );
    }
  }
}
