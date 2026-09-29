import '../../../core/theme/tf_mobile_status_colors.dart';
import '../../feed/widgets/tf_feed_models.dart';

/// Recurso de veículo alocado para o operador no dia.
class TodayVehicleResource {
  final String model;
  final String plate;
  final String? driverName;

  const TodayVehicleResource({
    required this.model,
    required this.plate,
    this.driverName,
  });
}

/// Recurso de equipe designada no dia.
class TodayTeamResource {
  final String teamName;
  final int membersCount;
  final String? supervisorName;

  const TodayTeamResource({
    required this.teamName,
    this.membersCount = 0,
    this.supervisorName,
  });
}

/// Próxima atividade operacional a ser executada pelo operador.
class NextTaskSummary {
  final String id;
  final String title;
  final String location;
  final String timeRange;
  final TFOperationalStatus status;
  final String? sapOrderOrNote;

  const NextTaskSummary({
    required this.id,
    required this.title,
    required this.location,
    required this.timeRange,
    required this.status,
    this.sapOrderOrNote,
  });
}

/// ViewModel de apresentação da Home "Hoje" no TaskFlow Mobile.
/// Desacopla a interface das tabelas e serviços de backend.
class MobileTodayViewModel {
  final String userName;
  final String userRole;
  final String formattedDate;
  final int totalTasksToday;
  final int pendingTasks;
  final int inProgressTasks;
  final int completedTasks;
  final NextTaskSummary? nextTask;
  final TodayVehicleResource? vehicle;
  final TodayTeamResource? team;
  final List<TFFeedItem> happeningNowEvents;
  final int pendingSyncCount;

  const MobileTodayViewModel({
    required this.userName,
    required this.userRole,
    required this.formattedDate,
    this.totalTasksToday = 0,
    this.pendingTasks = 0,
    this.inProgressTasks = 0,
    this.completedTasks = 0,
    this.nextTask,
    this.vehicle,
    this.team,
    this.happeningNowEvents = const [],
    this.pendingSyncCount = 0,
  });

  bool get hasAssignedVehicle => vehicle != null;
  bool get hasAssignedTeam => team != null;
  bool get hasTasksToday => totalTasksToday > 0;
  bool get hasHappeningNow => happeningNowEvents.isNotEmpty;
}
