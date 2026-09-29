import '../../../core/theme/tf_mobile_status_colors.dart';
import 'mobile_task_available_actions.dart';

/// Status da Análise Preliminar de Risco (APR) derivado de dados reais.
enum MobileAprStatus {
  requiredPending,   // Exigida e ainda não preenchida
  requiredCompleted, // Exigida e preenchida
  notRequired,       // Não aplicável/dispensada
  unknown,           // Não foi possível determinar
}

/// Representação factual de um item de evidência fotográfica.
class MobileEvidenceItem {
  final String id;
  final String fileName;
  final bool isLocalPending;
  final String? url;
  final DateTime? createdAt;

  const MobileEvidenceItem({
    required this.id,
    required this.fileName,
    this.isLocalPending = false,
    this.url,
    this.createdAt,
  });
}

/// Evento comprovável na linha do tempo da tarefa (sem dados fabricados).
class MobileTimelineEvent {
  final String title;
  final DateTime timestamp;
  final String? description;

  const MobileTimelineEvent({
    required this.title,
    required this.timestamp,
    this.description,
  });
}

/// ViewModel completo para exibição na tela de detalhes da atividade.
class MobileTaskDetailViewModel {
  final String id;
  final String title;
  final String rawStatus;
  final TFOperationalStatus status;
  final bool isUnknownStatus;
  final String type;
  final String? priority;
  final String? location;
  final String? asset;
  final String? regional;
  final String? divisao;
  final String? timeWindow;
  final String? formattedDate;

  // Recursos e Equipe
  final String? teamName;
  final String? leadExecutor;
  final List<String> executorsList;
  final String? vehiclePlate;
  final String? coordenador;

  // Datas e Horas
  final DateTime dataInicio;
  final DateTime dataFim;
  final double? horasPrevistas;
  final double? horasExecutadas;
  final String? observations;

  // Referências SAP reais (apenas preenchidas)
  final String? sapOrder;
  final String? sapNotification;
  final String? sapSi;
  final String? sapAt;

  // Segurança (APR)
  final MobileAprStatus aprStatus;

  // Evidências
  final List<MobileEvidenceItem> evidences;

  // Chat
  final String? chatGroupId;
  final int unreadChatCount;

  // Timeline
  final List<MobileTimelineEvent> timelineEvents;

  // Ações e Sincronização
  final MobileTaskAvailableActions actions;
  final TFSyncStatus syncStatus;

  const MobileTaskDetailViewModel({
    required this.id,
    required this.title,
    required this.rawStatus,
    required this.status,
    this.isUnknownStatus = false,
    required this.type,
    this.priority,
    this.location,
    this.asset,
    this.regional,
    this.divisao,
    this.timeWindow,
    this.formattedDate,
    this.teamName,
    this.leadExecutor,
    this.executorsList = const [],
    this.vehiclePlate,
    this.coordenador,
    required this.dataInicio,
    required this.dataFim,
    this.horasPrevistas,
    this.horasExecutadas,
    this.observations,
    this.sapOrder,
    this.sapNotification,
    this.sapSi,
    this.sapAt,
    this.aprStatus = MobileAprStatus.unknown,
    this.evidences = const [],
    this.chatGroupId,
    this.unreadChatCount = 0,
    this.timelineEvents = const [],
    required this.actions,
    this.syncStatus = TFSyncStatus.synced,
  });

  /// Indica se a tarefa possui referências SAP associadas.
  bool get hasSapReferences =>
      (sapOrder != null && sapOrder!.isNotEmpty) ||
      (sapNotification != null && sapNotification!.isNotEmpty) ||
      (sapSi != null && sapSi!.isNotEmpty) ||
      (sapAt != null && sapAt!.isNotEmpty);
}
