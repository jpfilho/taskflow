import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../utils/responsive.dart';
import '../design_system/taskflow_design_system.dart';

class AlertsView extends StatelessWidget {
  final TaskService taskService;
  final List<Task>? filteredTasks;

  const AlertsView({
    super.key,
    required this.taskService,
    this.filteredTasks,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    if (filteredTasks != null) {
      final tasks = filteredTasks!;
      final alerts = _generateAlerts(tasks);
      return _buildContent(context, tasks, alerts, isMobile);
    }

    return FutureBuilder<List<Task>>(
      future: taskService.getAllTasks(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: TFLoading(message: 'Carregando alertas...'));
        }
        if (snapshot.hasError) {
          return Center(
            child: TFEmptyState(
              icon: Icons.error_outline,
              title: 'Erro ao carregar alertas',
              description: '${snapshot.error}',
            ),
          );
        }
        final tasks = snapshot.data ?? [];
        final alerts = _generateAlerts(tasks);
        return _buildContent(context, tasks, alerts, isMobile);
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<Task> tasks,
    Map<String, dynamic> alerts,
    bool isMobile,
  ) {
    final colors = context.tfColors;

    final critical = alerts['critical'] as List<Alert>;
    final warnings = alerts['warnings'] as List<Alert>;
    final info = alerts['info'] as List<Alert>;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context, 'Alertas e Notificações', isMobile, tasks),
          const SizedBox(height: 20),
          _buildAlertSummary(context, alerts, isMobile),
          const SizedBox(height: 24),
          _buildSectionTitle(context, 'Alertas Críticos', isMobile, colors.danger, Icons.error_outline),
          const SizedBox(height: 12),
          _buildAlertsList(context, critical, isMobile, colors.danger),
          const SizedBox(height: 24),
          _buildSectionTitle(context, 'Avisos Importantes', isMobile, colors.warning, Icons.warning_amber_rounded),
          const SizedBox(height: 12),
          _buildAlertsList(context, warnings, isMobile, colors.warning),
          const SizedBox(height: 24),
          _buildSectionTitle(context, 'Informações', isMobile, colors.info, Icons.info_outline),
          const SizedBox(height: 12),
          _buildAlertsList(context, info, isMobile, colors.info),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String title, bool isMobile, List<Task> tasks) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final criticalCount = (_generateAlerts(tasks)['critical'] as List).length;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.primary,
            borderRadius: BorderRadius.circular(TFRadius.r12),
          ),
          child: const Icon(Icons.notifications_active, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            title,
            style: isMobile ? typography.sectionTitle : typography.pageTitle,
          ),
        ),
        if (criticalCount > 0)
          TFStatusBadge(
            label: '$criticalCount crítico(s)',
            severity: TFStatusSeverity.danger,
          ),
      ],
    );
  }

  Widget _buildAlertSummary(BuildContext context, Map<String, dynamic> alerts, bool isMobile) {
    final colors = context.tfColors;

    final criticalCount = (alerts['critical'] as List).length;
    final warningsCount = (alerts['warnings'] as List).length;
    final infoCount = (alerts['info'] as List).length;
    final totalCount = criticalCount + warningsCount + infoCount;

    return GridView.count(
      crossAxisCount: isMobile ? 2 : 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: isMobile ? 1.3 : 1.5,
      children: [
        _buildSummaryCard(context, 'Críticos', criticalCount.toString(), Icons.error, colors.danger, isMobile),
        _buildSummaryCard(context, 'Avisos', warningsCount.toString(), Icons.warning, colors.warning, isMobile),
        _buildSummaryCard(context, 'Informações', infoCount.toString(), Icons.info, colors.info, isMobile),
        _buildSummaryCard(context, 'Total', totalCount.toString(), Icons.notifications, colors.primary, isMobile),
      ],
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
    bool isMobile,
  ) {
    final typography = context.tfTypography;
    final colors = context.tfColors;

    return TFCard(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: isMobile ? 24 : 32),
            const SizedBox(height: 6),
            Text(
              value,
              style: (isMobile ? typography.sectionTitle : typography.display).copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: typography.caption.copyWith(color: colors.textSecondary),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(
    BuildContext context,
    String title,
    bool isMobile,
    Color color,
    IconData icon,
  ) {
    final typography = context.tfTypography;

    return Row(
      children: [
        Icon(icon, color: color, size: isMobile ? 20 : 24),
        const SizedBox(width: 8),
        Text(
          title,
          style: isMobile ? typography.cardTitle : typography.sectionTitle,
        ),
      ],
    );
  }

  Widget _buildAlertsList(
    BuildContext context,
    List<Alert> alerts,
    bool isMobile,
    Color color,
  ) {
    if (alerts.isEmpty) {
      return const TFCard(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Text('Nenhum alerta nesta categoria'),
          ),
        ),
      );
    }

    return Column(
      children: alerts.map((alert) {
        return _buildAlertCard(context, alert, isMobile, color);
      }).toList(),
    );
  }

  Widget _buildAlertCard(
    BuildContext context,
    Alert alert,
    bool isMobile,
    Color color,
  ) {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TFCard(
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(TFRadius.r8),
                ),
                child: Icon(alert.icon, color: color, size: isMobile ? 20 : 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.title,
                      style: typography.cardTitle.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alert.message,
                      style: typography.bodyMedium.copyWith(color: colors.textSecondary),
                    ),
                    if (alert.task != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: colors.surfaceSecondary,
                          borderRadius: BorderRadius.circular(TFRadius.r4),
                          border: Border.all(color: colors.borderSubtle),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.assignment_outlined, size: 14, color: colors.textSecondary),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                alert.task!.tarefa,
                                style: typography.caption.copyWith(color: colors.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (alert.date != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 12, color: colors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            alert.date!,
                            style: typography.caption.copyWith(color: colors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _generateAlerts(List<Task> tasks) {
    final now = DateTime.now();
    final critical = <Alert>[];
    final warnings = <Alert>[];
    final info = <Alert>[];

    for (var task in tasks) {
      if (task.dataFim.isBefore(now) && task.status != 'CONC') {
        final daysLate = now.difference(task.dataFim).inDays;
        critical.add(Alert(
          title: 'Atividade Atrasada',
          message: 'A atividade está $daysLate dia(s) atrasada',
          icon: Icons.error,
          task: task,
          date: 'Vencimento: ${task.dataFim.day}/${task.dataFim.month}/${task.dataFim.year}',
        ));
      }

      if (task.tipo == 'PMP' && task.status == 'PROG') {
        final daysUntil = task.dataInicio.difference(now).inDays;
        if (daysUntil <= 7 && daysUntil >= 0) {
          warnings.add(Alert(
            title: 'Manutenção Preventiva Próxima',
            message: 'Manutenção preventiva em $daysUntil dia(s)',
            icon: Icons.warning,
            task: task,
            date: 'Data: ${task.dataInicio.day}/${task.dataInicio.month}/${task.dataInicio.year}',
          ));
        }
      }

      if (task.executor.isEmpty || task.executor == '-N/A-') {
        warnings.add(Alert(
          title: 'Atividade sem Executor',
          message: 'Atribua um executor para esta atividade',
          icon: Icons.person_off,
          task: task,
        ));
      }

      if (task.tipo == 'PMP' && (task.frota.isEmpty || task.frota == '-N/A-')) {
        info.add(Alert(
          title: 'Frota não especificada',
          message: 'Considere especificar a frota para esta manutenção',
          icon: Icons.info,
          task: task,
        ));
      }
    }

    final totalAtrasadas = tasks.where((t) => t.dataFim.isBefore(now) && t.status != 'CONC').length;
    if (totalAtrasadas > 0) {
      critical.insert(0, Alert(
        title: 'Resumo de Atrasos',
        message: '$totalAtrasadas atividade(s) atrasada(s) requerem atenção imediata',
        icon: Icons.error_outline,
      ));
    }

    return {
      'critical': critical,
      'warnings': warnings,
      'info': info,
    };
  }
}

class Alert {
  final String title;
  final String message;
  final IconData icon;
  final Task? task;
  final String? date;

  Alert({
    required this.title,
    required this.message,
    required this.icon,
    this.task,
    this.date,
  });
}
