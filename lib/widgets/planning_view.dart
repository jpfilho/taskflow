import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../utils/responsive.dart';

class PlanningView extends StatelessWidget {
  final TaskService taskService;
  final List<Task>? filteredTasks; // Tarefas já filtradas (opcional)

  const PlanningView({
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
      final upcomingTasks = _getUpcomingTasks(tasks);
      final overdueTasks = _getOverdueTasks(tasks);
      return SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 12 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader('Planejamento e Próximas Atividades', isMobile),
            const SizedBox(height: 20),
            if (overdueTasks.isNotEmpty) ...[
              _buildSectionTitle('⚠️ Atrasadas', isMobile, Colors.red),
              const SizedBox(height: 12),
              _buildTasksList(overdueTasks, isMobile, Colors.red),
              const SizedBox(height: 24),
            ],
            _buildSectionTitle('📅 Próximas Atividades', isMobile, const Color(0xFF1E3A5F)),
            const SizedBox(height: 12),
            _buildTasksList(upcomingTasks, isMobile, Colors.blue),
            const SizedBox(height: 24),
            _buildPlanningSummary(tasks, isMobile),
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
        final upcomingTasks = _getUpcomingTasks(tasks);
        final overdueTasks = _getOverdueTasks(tasks);

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 12 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader('Planejamento e Próximas Atividades', isMobile),
              const SizedBox(height: 20),
              if (overdueTasks.isNotEmpty) ...[
                _buildSectionTitle('⚠️ Atrasadas', isMobile, Colors.red),
                const SizedBox(height: 12),
                _buildTasksList(overdueTasks, isMobile, Colors.red),
                const SizedBox(height: 24),
              ],
              _buildSectionTitle('📅 Próximas Atividades', isMobile, const Color(0xFF1E3A5F)),
              const SizedBox(height: 12),
              _buildTasksList(upcomingTasks, isMobile, Colors.blue),
              const SizedBox(height: 24),
              _buildPlanningSummary(tasks, isMobile),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(String title, bool isMobile) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A5F),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.calendar_today, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: isMobile ? 20 : 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E3A5F),
            ),
          ),
        ),
      ],
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

  Widget _buildTasksList(List<Task> tasks, bool isMobile, Color accentColor) {
    if (tasks.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Text(
              'Nenhuma atividade encontrada',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }

    return Column(
      children: tasks.take(5).map((task) {
        return _buildTaskCard(task, isMobile, accentColor);
      }).toList(),
    );
  }

  Widget _buildTaskCard(Task task, bool isMobile, Color accentColor) {
    final daysUntil = task.dataInicio.difference(DateTime.now()).inDays;
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 60,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.tarefa,
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${task.dataInicio.day}/${task.dataInicio.month}/${task.dataInicio.year}',
                        style: TextStyle(
                          fontSize: isMobile ? 11 : 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.person, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          task.executor,
                          style: TextStyle(
                            fontSize: isMobile ? 11 : 12,
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                daysUntil < 0 
                  ? '${daysUntil.abs()}d atrasado'
                  : daysUntil == 0
                    ? 'Hoje'
                    : '$daysUntil dias',
                style: TextStyle(
                  fontSize: isMobile ? 11 : 12,
                  color: accentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanningSummary(List<Task> tasks, bool isMobile) {
    final thisWeek = _getTasksThisWeek(tasks);
    final thisMonth = _getTasksThisMonth(tasks);
    
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumo do Planejamento',
              style: TextStyle(
                fontSize: isMobile ? 16 : 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E3A5F),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Esta Semana',
                    thisWeek.length.toString(),
                    Icons.today,
                    Colors.blue,
                    isMobile,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    'Este Mês',
                    thisMonth.length.toString(),
                    Icons.calendar_month,
                    Colors.green,
                    isMobile,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: isMobile ? 28 : 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: isMobile ? 24 : 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: isMobile ? 11 : 12,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  List<Task> _getUpcomingTasks(List<Task> tasks) {
    final now = DateTime.now();
    final filtered = tasks.where((task) {
      return task.dataInicio.isAfter(now) && 
             task.dataInicio.isBefore(now.add(const Duration(days: 30))) &&
             task.status != 'CONC';
    }).toList();
    // Criar lista mutável para ordenação
    final sorted = List<Task>.from(filtered);
    sorted.sort((a, b) => a.dataInicio.compareTo(b.dataInicio));
    return sorted;
  }

  List<Task> _getOverdueTasks(List<Task> tasks) {
    final now = DateTime.now();
    final filtered = tasks.where((task) {
      return task.dataFim.isBefore(now) && task.status != 'CONC';
    }).toList();
    // Criar lista mutável para ordenação
    final sorted = List<Task>.from(filtered);
    sorted.sort((a, b) => a.dataFim.compareTo(b.dataFim));
    return sorted;
  }

  List<Task> _getTasksThisWeek(List<Task> tasks) {
    final now = DateTime.now();
    final weekEnd = now.add(const Duration(days: 7));
    return tasks.where((task) {
      return task.dataInicio.isAfter(now) && task.dataInicio.isBefore(weekEnd);
    }).toList();
  }

  List<Task> _getTasksThisMonth(List<Task> tasks) {
    final now = DateTime.now();
    final monthEnd = DateTime(now.year, now.month + 1, 1);
    return tasks.where((task) {
      return task.dataInicio.isAfter(now) && task.dataInicio.isBefore(monthEnd);
    }).toList();
  }
}

