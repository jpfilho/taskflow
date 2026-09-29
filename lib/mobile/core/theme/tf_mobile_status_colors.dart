import 'package:flutter/material.dart';

/// Domínio de Status Operacionais do TaskFlow (Tarefas, Atividades, Demandas).
enum TFOperationalStatus {
  pendente,
  planejado,
  emExecucao,
  pausado,
  concluido,
  atrasado,
  impedido,
  cancelado,
}

/// Domínio de Estados de Conectividade e Sincronização Local SQLite -> Supabase.
enum TFSyncStatus {
  online,
  offline,
  pending, // Alterações locais pendentes de envio
  syncing,
  synced,
  error,
}

/// Representação visual consolidada (Cor + Borda + Ícone + Texto) para um status.
class TFStatusVisualConfig {
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final Color border;

  const TFStatusVisualConfig({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.border,
  });
}

/// Centralizador de cores e configurações visuais de status com alto contraste.
abstract class TFMobileStatusColors {
  /// Retorna a configuração visual para um status operacional.
  static TFStatusVisualConfig forOperational(
    TFOperationalStatus status, {
    bool isDark = false,
  }) {
    switch (status) {
      case TFOperationalStatus.pendente:
        return TFStatusVisualConfig(
          label: 'Pendente',
          icon: Icons.hourglass_empty_rounded,
          background: isDark ? const Color(0xFF2A2415) : const Color(0xFFFEF3C7),
          foreground: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
          border: isDark ? const Color(0xFF78350F) : const Color(0xFFF59E0B),
        );
      case TFOperationalStatus.planejado:
        return TFStatusVisualConfig(
          label: 'Planejado',
          icon: Icons.calendar_today_rounded,
          background: isDark ? const Color(0xFF132238) : const Color(0xFFEFF6FF),
          foreground: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF),
          border: isDark ? const Color(0xFF1E3A8A) : const Color(0xFF3B82F6),
        );
      case TFOperationalStatus.emExecucao:
        return TFStatusVisualConfig(
          label: 'Em Execução',
          icon: Icons.play_arrow_rounded,
          background: isDark ? const Color(0xFF0F2D37) : const Color(0xFFE0F2FE),
          foreground: isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0369A1),
          border: isDark ? const Color(0xFF0C4A6E) : const Color(0xFF0284C7),
        );
      case TFOperationalStatus.pausado:
        return TFStatusVisualConfig(
          label: 'Pausado',
          icon: Icons.pause_rounded,
          background: isDark ? const Color(0xFF242730) : const Color(0xFFF1F5F9),
          foreground: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
          border: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
        );
      case TFOperationalStatus.concluido:
        return TFStatusVisualConfig(
          label: 'Concluído',
          icon: Icons.check_circle_rounded,
          background: isDark ? const Color(0xFF142E1F) : const Color(0xFFDCFCE7),
          foreground: isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D),
          border: isDark ? const Color(0xFF166534) : const Color(0xFF22C55E),
        );
      case TFOperationalStatus.atrasado:
        return TFStatusVisualConfig(
          label: 'Atrasado',
          icon: Icons.alarm_off_rounded,
          background: isDark ? const Color(0xFF331414) : const Color(0xFFFEE2E2),
          foreground: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
          border: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFEF4444),
        );
      case TFOperationalStatus.impedido:
        return TFStatusVisualConfig(
          label: 'Impedido',
          icon: Icons.block_rounded,
          background: isDark ? const Color(0xFF3B151E) : const Color(0xFFFFE4E6),
          foreground: isDark ? const Color(0xFFFDA4AF) : const Color(0xFFBE123C),
          border: isDark ? const Color(0xFF881337) : const Color(0xFFF43F5E),
        );
      case TFOperationalStatus.cancelado:
        return TFStatusVisualConfig(
          label: 'Cancelado',
          icon: Icons.cancel_rounded,
          background: isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6),
          foreground: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
          border: isDark ? const Color(0xFF374151) : const Color(0xFF9CA3AF),
        );
    }
  }

  /// Retorna a configuração visual para um status de conectividade / sincronização.
  static TFStatusVisualConfig forSync(
    TFSyncStatus status, {
    bool isDark = false,
  }) {
    switch (status) {
      case TFSyncStatus.online:
        return TFStatusVisualConfig(
          label: 'Online',
          icon: Icons.wifi_rounded,
          background: isDark ? const Color(0xFF142E1F) : const Color(0xFFDCFCE7),
          foreground: isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D),
          border: isDark ? const Color(0xFF166534) : const Color(0xFF22C55E),
        );
      case TFSyncStatus.offline:
        return TFStatusVisualConfig(
          label: 'Modo Offline',
          icon: Icons.cloud_off_rounded,
          background: isDark ? const Color(0xFF2F2B1B) : const Color(0xFFFEF3C7),
          foreground: isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309),
          border: isDark ? const Color(0xFF78350F) : const Color(0xFFF59E0B),
        );
      case TFSyncStatus.pending:
        return TFStatusVisualConfig(
          label: 'Pendente de Sincronização',
          icon: Icons.schedule_rounded,
          background: isDark ? const Color(0xFF2A2012) : const Color(0xFFFFEDD5),
          foreground: isDark ? const Color(0xFFFDBA74) : const Color(0xFFC2410C),
          border: isDark ? const Color(0xFF7C2D12) : const Color(0xFFF97316),
        );
      case TFSyncStatus.syncing:
        return TFStatusVisualConfig(
          label: 'Sincronizando...',
          icon: Icons.sync_rounded,
          background: isDark ? const Color(0xFF132238) : const Color(0xFFEFF6FF),
          foreground: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
          border: isDark ? const Color(0xFF1E3A8A) : const Color(0xFF3B82F6),
        );
      case TFSyncStatus.synced:
        return TFStatusVisualConfig(
          label: 'Sincronizado',
          icon: Icons.cloud_done_rounded,
          background: isDark ? const Color(0xFF142E1F) : const Color(0xFFDCFCE7),
          foreground: isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D),
          border: isDark ? const Color(0xFF166534) : const Color(0xFF22C55E),
        );
      case TFSyncStatus.error:
        return TFStatusVisualConfig(
          label: 'Erro de Sincronização',
          icon: Icons.error_outline_rounded,
          background: isDark ? const Color(0xFF331414) : const Color(0xFFFEE2E2),
          foreground: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
          border: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFEF4444),
        );
    }
  }
}
