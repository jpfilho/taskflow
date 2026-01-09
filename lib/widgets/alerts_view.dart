import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../utils/responsive.dart';

class AlertsView extends StatelessWidget {
  final TaskService taskService;
  final List<Task>? filteredTasks; // Tarefas já filtradas (opcional)

  const AlertsView({
    super.key,
    required this.taskService,
    this.filteredTasks,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    // Se filteredTasks foi fornecido, usar diretamente
    if (filteredTasks != null) {
      final tasks = filteredTasks!;
      final alerts = _generateAlerts(tasks);
      return SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 12 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader('Alertas e Notificações', isMobile, tasks),
            const SizedBox(height: 20),
            _buildAlertSummary(alerts, isMobile),
            const SizedBox(height: 24),
            _buildSectionTitle('⚠️ Alertas Críticos', isMobile, Colors.red),
            const SizedBox(height: 12),
            _buildAlertsList(alerts['critical'] as List<Alert>, isMobile, Colors.red),
            const SizedBox(height: 24),
            _buildSectionTitle('⚠️ Avisos Importantes', isMobile, Colors.orange),
            const SizedBox(height: 12),
            _buildAlertsList(alerts['warnings'] as List<Alert>, isMobile, Colors.orange),
            const SizedBox(height: 24),
            _buildSectionTitle('ℹ️ Informações', isMobile, Colors.blue),
            const SizedBox(height: 12),
            _buildAlertsList(alerts['info'] as List<Alert>, isMobile, Colors.blue),
          ],
        ),
      );
    }

    return FutureBuilder<List<Task>>(
      future: taskService.getAllTasks(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erro: ${snapshot.error}'));
        }
        final tasks = snapshot.data ?? [];
        final alerts = _generateAlerts(tasks);

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader('Alertas e Notificações', isMobile, tasks),
          const SizedBox(height: 20),
          _buildAlertSummary(alerts, isMobile),
          const SizedBox(height: 24),
          _buildSectionTitle('⚠️ Alertas Críticos', isMobile, Colors.red),
          const SizedBox(height: 12),
          _buildAlertsList(alerts['critical'] as List<Alert>, isMobile, Colors.red),
          const SizedBox(height: 24),
          _buildSectionTitle('⚠️ Avisos Importantes', isMobile, Colors.orange),
          const SizedBox(height: 12),
          _buildAlertsList(alerts['warnings'] as List<Alert>, isMobile, Colors.orange),
          const SizedBox(height: 24),
          _buildSectionTitle('ℹ️ Informações', isMobile, Colors.blue),
          const SizedBox(height: 12),
          _buildAlertsList(alerts['info'] as List<Alert>, isMobile, Colors.blue),
        ],
      ),
    );
      },
    );
  }

  Widget _buildHeader(String title, bool isMobile, List<Task> tasks) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A5F),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.notifications_active, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: isMobile ? 22 : 28,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E3A5F),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${(_generateAlerts(tasks)['critical'] as List).length}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildAlertSummary(Map<String, dynamic> alerts, bool isMobile) {
    return GridView.count(
      crossAxisCount: isMobile ? 2 : 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: isMobile ? 1.2 : 1.4,
      children: [
        _buildSummaryCard(
          'Críticos',
          (alerts['critical'] as List).length.toString(),
          Icons.error,
          Colors.red,
          isMobile,
        ),
        _buildSummaryCard(
          'Avisos',
          (alerts['warnings'] as List).length.toString(),
          Icons.warning,
          Colors.orange,
          isMobile,
        ),
        _buildSummaryCard(
          'Informações',
          (alerts['info'] as List).length.toString(),
          Icons.info,
          Colors.blue,
          isMobile,
        ),
        _buildSummaryCard(
          'Total',
          ((alerts['critical'] as List).length + 
           (alerts['warnings'] as List).length + 
           (alerts['info'] as List).length).toString(),
          Icons.notifications,
          Colors.purple,
          isMobile,
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color, bool isMobile) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          ),
        ),
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: isMobile ? 28 : 36),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: isMobile ? 22 : 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: isMobile ? 10 : 12,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isMobile, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: isMobile ? 18 : 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildAlertsList(List<Alert> alerts, bool isMobile, Color color) {
    if (alerts.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Text(
              'Nenhum alerta nesta categoria',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }

    return Column(
      children: alerts.map((alert) {
        return _buildAlertCard(alert, isMobile, color);
      }).toList(),
    );
  }

  Widget _buildAlertCard(Alert alert, bool isMobile, Color color) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.3), width: 2),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(alert.icon, color: color, size: isMobile ? 24 : 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.title,
                    style: TextStyle(
                      fontSize: isMobile ? 15 : 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alert.message,
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  if (alert.task != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.assignment, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              alert.task!.tarefa,
                              style: TextStyle(
                                fontSize: isMobile ? 11 : 12,
                                color: Colors.grey[700],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (alert.date != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          alert.date!,
                          style: TextStyle(
                            fontSize: isMobile ? 11 : 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                // Marcar como lido
              },
            ),
          ],
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
      // Atividades atrasadas
      if (task.dataFim.isBefore(now) && task.status != 'CONC') {
        final daysLate = now.difference(task.dataFim).inDays;
        critical.add(Alert(
          title: 'Atividade Atrasada',
          message: 'A atividade está ${daysLate} dia(s) atrasada',
          icon: Icons.error,
          task: task,
          date: 'Vencimento: ${task.dataFim.day}/${task.dataFim.month}/${task.dataFim.year}',
        ));
      }

      // Manutenções preventivas próximas (7 dias)
      if (task.tipo == 'PMP' && task.status == 'PROG') {
        final daysUntil = task.dataInicio.difference(now).inDays;
        if (daysUntil <= 7 && daysUntil >= 0) {
          warnings.add(Alert(
            title: 'Manutenção Preventiva Próxima',
            message: 'Manutenção preventiva em ${daysUntil} dia(s)',
            icon: Icons.warning,
            task: task,
            date: 'Data: ${task.dataInicio.day}/${task.dataInicio.month}/${task.dataInicio.year}',
          ));
        }
      }

      // Atividades sem executor
      if (task.executor.isEmpty || task.executor == '-N/A-') {
        warnings.add(Alert(
          title: 'Atividade sem Executor',
          message: 'Atribua um executor para esta atividade',
          icon: Icons.person_off,
          task: task,
        ));
      }

      // Atividades sem frota quando necessário
      if (task.tipo == 'PMP' && (task.frota.isEmpty || task.frota == '-N/A-')) {
        info.add(Alert(
          title: 'Frota não especificada',
          message: 'Considere especificar a frota para esta manutenção',
          icon: Icons.info,
          task: task,
        ));
      }
    }

    // Alertas gerais
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




