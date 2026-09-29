import '../../../core/theme/tf_mobile_status_colors.dart';
import 'mobile_task_available_actions.dart';

/// ViewModel otimizado para o MobileTaskCard e listagem rápida de atividades.
/// Separa estritamente dados semânticos de decisões visuais (cores/estilos).
class MobileTaskViewModel {
  final String id;
  final String title;
  final String rawStatus;
  final TFOperationalStatus status;
  final bool isUnknownStatus;
  final String type;
  final String? location;
  final String? asset;
  final String? timeWindow;
  final String? formattedDate;
  final String? teamName;
  final String? leadExecutor;
  final String? vehiclePlate;
  final String? priority; // Fonte real: valor literal de task.prioridade ou null
  final bool pendingApr;
  final bool pendingSync;
  final TFSyncStatus syncStatus;
  final MobileTaskAvailableActions actions;

  const MobileTaskViewModel({
    required this.id,
    required this.title,
    required this.rawStatus,
    required this.status,
    this.isUnknownStatus = false,
    required this.type,
    this.location,
    this.asset,
    this.timeWindow,
    this.formattedDate,
    this.teamName,
    this.leadExecutor,
    this.vehiclePlate,
    this.priority,
    this.pendingApr = false,
    this.pendingSync = false,
    this.syncStatus = TFSyncStatus.synced,
    required this.actions,
  });

  /// Indica se há pendências reais a exibir no card.
  bool get hasPendingItems => pendingApr || pendingSync;
}
