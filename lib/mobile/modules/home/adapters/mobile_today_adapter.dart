import '../../../../models/task.dart';
import '../../../../services/auth_service_simples.dart';
import '../../../../services/task_service.dart';
import '../../../../services/local_database_service.dart';
import '../../../core/theme/tf_mobile_status_colors.dart';
import '../../feed/widgets/tf_feed_models.dart';
import '../models/mobile_today_view_model.dart';

/// Adapter responsável por consultar os serviços existentes do TaskFlow e construir
/// o MobileTodayViewModel de apresentação sem dados fictícios em produção.
class MobileTodayAdapter {
  final TaskService _taskService;

  MobileTodayAdapter({
    TaskService? taskService,
  })  : _taskService = taskService ?? TaskService();

  /// Carrega os dados reais do dia do usuário conectado.
  Future<MobileTodayViewModel> loadTodayData() async {
    try {
      // Data formatada em português
      final now = DateTime.now();
      final formattedDate = _formatDate(now);

      // Obter contagem de pendências de sincronização local do SQLite
      int pendingCount = 0;
      try {
        pendingCount = await LocalDatabaseService().getPendingSyncCount();
      } catch (_) {}

      // Nome real do usuário conectado
      final currentUser = AuthServiceSimples().currentUser;
      final nome = currentUser?.nome;
      final email = currentUser?.email;
      final String userName = (nome != null && nome.isNotEmpty)
          ? nome
          : ((email != null && email.isNotEmpty) ? email.split('@').first : 'Colaborador');

      // Buscar tarefas do TaskService (prioriza tarefas em memória e aplica timeout de segurança)
      List<Task> tasks = _taskService.tasks;
      if (tasks.isEmpty) {
        try {
          tasks = await _taskService.getAllTasks().timeout(
            const Duration(seconds: 4),
            onTimeout: () => _taskService.tasks,
          );
        } catch (_) {
          tasks = _taskService.tasks;
        }
      }

      // Filtrar tarefas relevantes para a jornada de hoje (ocorrem hoje ou estão em andamento)
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final relevantTasks = tasks.where((t) {
        final occursToday = !t.dataFim.isBefore(startOfDay) && !t.dataInicio.isAfter(endOfDay);
        final isEmAndamento = t.status.toUpperCase() == 'ANDA';
        return occursToday || isEmAndamento;
      }).toList();

      int pending = 0;
      int inProgress = 0;
      int completed = 0;
      NextTaskSummary? nextTask;
      final List<TFFeedItem> derivedEvents = [];

      for (final t in relevantTasks) {
        final statusLower = (t.status).toLowerCase();
        if (statusLower.contains('conc') || statusLower.contains('final')) {
          completed++;
          if (derivedEvents.length < 3) {
            derivedEvents.add(
              TFFeedItem(
                id: 'event_${t.id}',
                sourceType: TFFeedSourceType.activityEvent,
                authorName: t.executores.isNotEmpty ? t.executores.first : 'Equipe Operacional',
                timestamp: 'hoje',
                content: 'Atividade concluída',
                linkedEntityTitle: t.tarefa,
                linkedEntityId: t.id,
              ),
            );
          }
        } else if (statusLower.contains('anda') || statusLower.contains('exec')) {
          inProgress++;
          nextTask ??= _mapToNextTask(t, TFOperationalStatus.emExecucao);
          if (derivedEvents.length < 3) {
            derivedEvents.add(
              TFFeedItem(
                id: 'event_${t.id}',
                sourceType: TFFeedSourceType.activityEvent,
                authorName: t.executores.isNotEmpty ? t.executores.first : 'Equipe Operacional',
                timestamp: 'agora',
                content: 'Atividade em andamento',
                linkedEntityTitle: t.tarefa,
                linkedEntityId: t.id,
              ),
            );
          }
        } else {
          pending++;
          nextTask ??= _mapToNextTask(t, TFOperationalStatus.pendente);
        }
      }

      final total = pending + inProgress + completed;

      return MobileTodayViewModel(
        userName: userName,
        userRole: 'Operação e Manutenção',
        formattedDate: formattedDate,
        totalTasksToday: total,
        pendingTasks: pending,
        inProgressTasks: inProgress,
        completedTasks: completed,
        nextTask: nextTask,
        vehicle: null,
        team: null,
        happeningNowEvents: derivedEvents,
        pendingSyncCount: pendingCount,
      );
    } catch (e) {
      // Em caso de falha de conexão ou dados vazios, retorna modelo limpo com estado seguro
      return MobileTodayViewModel(
        userName: 'Colaborador',
        userRole: 'Operação e Manutenção',
        formattedDate: _formatDate(DateTime.now()),
        totalTasksToday: 0,
        pendingTasks: 0,
        inProgressTasks: 0,
        completedTasks: 0,
        nextTask: null,
        vehicle: null,
        team: null,
        happeningNowEvents: const [],
        pendingSyncCount: 0,
      );
    }
  }

  NextTaskSummary _mapToNextTask(Task t, TFOperationalStatus status) {
    return NextTaskSummary(
      id: t.id,
      title: t.tarefa,
      location: t.locais.isNotEmpty ? t.locais.join(', ') : 'Local não especificado',
      timeRange: '${t.dataInicio.hour.toString().padLeft(2, '0')}:${t.dataInicio.minute.toString().padLeft(2, '0')}',
      status: status,
      sapOrderOrNote: t.si.isNotEmpty
          ? 'SI: ${t.si}'
          : (t.ordem != null && t.ordem!.isNotEmpty ? 'Ordem: ${t.ordem}' : null),
    );
  }

  String _formatDate(DateTime dt) {
    const weekdays = [
      'Segunda-feira',
      'Terça-feira',
      'Quarta-feira',
      'Quinta-feira',
      'Sexta-feira',
      'Sábado',
      'Domingo'
    ];
    const months = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro'
    ];
    final weekday = weekdays[dt.weekday - 1];
    final day = dt.day;
    final month = months[dt.month - 1];
    return '$weekday, $day de $month';
  }
}
