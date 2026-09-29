import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../utils/responsive.dart';
import '../design_system/taskflow_design_system.dart';

class TeamManagementView extends StatelessWidget {
  final TaskService taskService;

  const TeamManagementView({
    super.key,
    required this.taskService,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return FutureBuilder<List<Task>>(
      future: taskService.getAllTasks(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: TFLoading(message: 'Carregando equipes...'));
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Erro: ${snapshot.error}',
              style: typography.bodyMedium.copyWith(color: colors.danger),
            ),
          );
        }
        final tasks = snapshot.data ?? [];
        final teamStats = _calculateTeamStats(tasks);

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 12 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader('Gestão de Equipes', isMobile, colors, typography),
              const SizedBox(height: 20),
              _buildSummaryCards(teamStats, isMobile, colors, typography),
              const SizedBox(height: 24),
              _buildSectionTitle('Equipes por Regional', isMobile, colors, typography),
              const SizedBox(height: 12),
              _buildTeamList(teamStats, isMobile, colors, typography),
              const SizedBox(height: 24),
              _buildSectionTitle('Distribuição de Carga de Trabalho', isMobile, colors, typography),
              const SizedBox(height: 12),
              _buildWorkloadChart(teamStats, isMobile, colors, typography),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(String title, bool isMobile, TFSemanticColors colors, TFTypography typography) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.people, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            title,
            style: typography.pageTitle.copyWith(
              fontSize: isMobile ? 22 : 28,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(Map<String, dynamic> stats, bool isMobile, TFSemanticColors colors, TFTypography typography) {
    return GridView.count(
      crossAxisCount: isMobile ? 2 : 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: isMobile ? 1.2 : 1.4,
      children: [
        _buildStatCard(
          'Total de Executores',
          stats['totalExecutores'].toString(),
          Icons.person,
          colors.primary,
          isMobile,
          colors,
          typography,
        ),
        _buildStatCard(
          'Equipes Ativas',
          stats['equipesAtivas'].toString(),
          Icons.groups,
          colors.success,
          isMobile,
          colors,
          typography,
        ),
        _buildStatCard(
          'Atividades em Andamento',
          stats['atividadesAndamento'].toString(),
          Icons.work,
          colors.warning,
          isMobile,
          colors,
          typography,
        ),
        _buildStatCard(
          'Taxa de Conclusão',
          '${stats['taxaConclusao'].toStringAsFixed(1)}%',
          Icons.trending_up,
          colors.info,
          isMobile,
          colors,
          typography,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    bool isMobile,
    TFSemanticColors colors,
    TFTypography typography,
  ) {
    return Card(
      elevation: 0,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.borderSubtle),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.12), color.withOpacity(0.03)],
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
              style: typography.display.copyWith(
                fontSize: isMobile ? 22 : 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Flexible(
              child: Text(
                title,
                style: typography.labelSmall.copyWith(
                  fontSize: isMobile ? 10 : 12,
                  color: colors.textSecondary,
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

  Widget _buildSectionTitle(String title, bool isMobile, TFSemanticColors colors, TFTypography typography) {
    return Text(
      title,
      style: typography.sectionTitle.copyWith(
        fontSize: isMobile ? 16 : 20,
        fontWeight: FontWeight.bold,
        color: colors.textPrimary,
      ),
    );
  }

  Widget _buildTeamList(Map<String, dynamic> stats, bool isMobile, TFSemanticColors colors, TFTypography typography) {
    final teams = stats['teams'] as Map<String, Map<String, dynamic>>;
    
    return Card(
      elevation: 0,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.borderSubtle),
      ),
      child: Column(
        children: teams.entries.map((entry) {
          final team = entry.value;
          final statusColor = _getStatusColor(team['status'] as String, colors);
          return Container(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: colors.borderSubtle, width: 1),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: isMobile ? 20 : 24,
                  backgroundColor: statusColor.withOpacity(0.15),
                  child: Icon(
                    Icons.group,
                    color: statusColor,
                    size: isMobile ? 20 : 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key,
                        style: typography.cardTitle.copyWith(
                          fontSize: isMobile ? 14 : 16,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${team['members']} membros • ${team['tasks']} atividades',
                        style: typography.bodySmall.copyWith(
                          fontSize: isMobile ? 11 : 12,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    team['status'] as String,
                    style: typography.labelSmall.copyWith(
                      fontSize: isMobile ? 10 : 11,
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWorkloadChart(Map<String, dynamic> stats, bool isMobile, TFSemanticColors colors, TFTypography typography) {
    final workload = stats['workload'] as Map<String, int>;
    final maxWorkload = workload.values.isEmpty ? 1 : workload.values.reduce((a, b) => a > b ? a : b);

    return Card(
      elevation: 0,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.borderSubtle),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          children: workload.entries.map((entry) {
            final percentage = maxWorkload > 0 ? (entry.value / maxWorkload) : 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: typography.labelMedium.copyWith(
                          fontSize: isMobile ? 12 : 14,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        '${entry.value} atividades',
                        style: typography.bodySmall.copyWith(
                          fontSize: isMobile ? 11 : 12,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: percentage,
                      minHeight: isMobile ? 8 : 10,
                      backgroundColor: colors.surfaceSecondary,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        percentage > 0.8 ? colors.danger : percentage > 0.5 ? colors.warning : colors.success,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Color _getStatusColor(String status, TFSemanticColors colors) {
    switch (status.toUpperCase()) {
      case 'ATIVO':
        return colors.success;
      case 'OCUPADO':
        return colors.warning;
      case 'DISPONÍVEL':
        return colors.primary;
      default:
        return colors.textSecondary;
    }
  }

  Map<String, dynamic> _calculateTeamStats(List<Task> tasks) {
    final executors = <String, int>{};
    final teams = <String, Map<String, dynamic>>{};
    final workload = <String, int>{};
    int totalAndamento = 0;
    int totalConcluidas = 0;

    for (var task in tasks) {
      // Contar executores
      final executorsList = task.executor.split(',').map((e) => e.trim()).toList();
      for (var executor in executorsList) {
        if (executor.isNotEmpty && executor != '-N/A-') {
          executors[executor] = (executors[executor] ?? 0) + 1;
          workload[executor] = (workload[executor] ?? 0) + 1;
        }
      }

      // Contar por regional (equipe)
      if (!teams.containsKey(task.regional)) {
        teams[task.regional] = {
          'members': executorsList.length,
          'tasks': 0,
          'status': 'ATIVO',
        };
      }
      teams[task.regional]!['tasks'] = (teams[task.regional]!['tasks'] as int) + 1;

      if (task.status == 'ANDA') totalAndamento++;
      if (task.status == 'CONC') totalConcluidas++;
    }

    final taxaConclusao = tasks.isEmpty ? 0.0 : (totalConcluidas / tasks.length * 100);

    return {
      'totalExecutores': executors.length,
      'equipesAtivas': teams.length,
      'atividadesAndamento': totalAndamento,
      'taxaConclusao': taxaConclusao,
      'teams': teams,
      'workload': workload,
    };
  }
}

