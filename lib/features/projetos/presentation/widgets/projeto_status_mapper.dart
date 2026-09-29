import 'package:flutter/material.dart';
import '../../../../design_system/components/status/tf_status_badge.dart';
import '../../../../design_system/foundations/tf_icons.dart';

/// Mapeador semântico de status operacionais do módulo de Projetos para o TaskFlow Design System.
class ProjetoStatusMapper {
  ProjetoStatusMapper._();

  /// Mapeia o status do Projeto para a severidade visual correspondente do TFDS.
  static TFStatusSeverity mapProjetoStatus(String? status) {
    switch (status?.toUpperCase().trim()) {
      case 'ATIVO':
      case 'EM_ANDAMENTO':
      case 'ANDAMENTO':
        return TFStatusSeverity.success;
      case 'EM PLANEJAMENTO':
      case 'PLANEJAMENTO':
      case 'PENDENTE':
        return TFStatusSeverity.warning;
      case 'CONCLUIDO':
      case 'CONCLUÍDO':
      case 'CONCLUIDA':
      case 'CONCLUÍDA':
        return TFStatusSeverity.info;
      case 'PAUSADO':
      case 'SUSPENSO':
        return TFStatusSeverity.neutral;
      case 'CANCELADO':
      case 'CANCELADA':
        return TFStatusSeverity.danger;
      default:
        return TFStatusSeverity.neutral;
    }
  }

  /// Mapeia o status de prioridade (BAIXA, MEDIA, ALTA, URGENTE).
  static TFStatusSeverity mapPrioridade(String? prioridade) {
    switch (prioridade?.toUpperCase().trim()) {
      case 'URGENTE':
      case 'ALTA':
        return TFStatusSeverity.danger;
      case 'MEDIA':
      case 'MÉDIA':
        return TFStatusSeverity.warning;
      case 'BAIXA':
        return TFStatusSeverity.neutral;
      default:
        return TFStatusSeverity.neutral;
    }
  }

  /// Retorna o ícone representativo para o status do projeto.
  static IconData getStatusIcon(String? status) {
    switch (status?.toUpperCase().trim()) {
      case 'ATIVO':
      case 'EM_ANDAMENTO':
      case 'ANDAMENTO':
        return TFIcons.task;
      case 'EM PLANEJAMENTO':
      case 'PLANEJAMENTO':
      case 'PENDENTE':
        return TFIcons.calendar;
      case 'CONCLUIDO':
      case 'CONCLUÍDO':
      case 'CONCLUIDA':
      case 'CONCLUÍDA':
        return TFIcons.success;
      case 'PAUSADO':
      case 'SUSPENSO':
        return Icons.pause_circle_outline_rounded;
      case 'CANCELADO':
      case 'CANCELADA':
        return TFIcons.cancel;
      default:
        return TFIcons.info;
    }
  }
}
