import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../utils/responsive.dart';
import '../design_system/taskflow_design_system.dart';

class CostManagementView extends StatelessWidget {
  final TaskService taskService;
  final List<Task>? filteredTasks;

  const CostManagementView({
    super.key,
    required this.taskService,
    this.filteredTasks,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    if (filteredTasks != null) {
      final tasks = filteredTasks!;
      final costStats = _calculateCostStats(tasks);
      return _buildContent(context, costStats, isMobile);
    }

    return FutureBuilder<List<Task>>(
      future: taskService.getAllTasks(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: TFLoading(message: 'Carregando gestão de custos...'));
        }
        if (snapshot.hasError) {
          return Center(
            child: TFEmptyState(
              icon: Icons.error_outline,
              title: 'Erro ao carregar custos',
              description: '${snapshot.error}',
            ),
          );
        }
        final tasks = snapshot.data ?? [];
        final costStats = _calculateCostStats(tasks);
        return _buildContent(context, costStats, isMobile);
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    Map<String, dynamic> costStats,
    bool isMobile,
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context, 'Gestão de Custos', isMobile),
          const SizedBox(height: 20),
          _buildSummaryCards(context, costStats, isMobile),
          const SizedBox(height: 24),
          _buildSectionTitle(context, 'Custos por Tipo de Manutenção', isMobile),
          const SizedBox(height: 12),
          _buildCostByTypeChart(context, costStats, isMobile),
          const SizedBox(height: 24),
          _buildSectionTitle(context, 'Custos por Regional', isMobile),
          const SizedBox(height: 12),
          _buildCostByRegionalChart(context, costStats, isMobile),
          const SizedBox(height: 24),
          _buildSectionTitle(context, 'Análise de Custos', isMobile),
          const SizedBox(height: 12),
          _buildCostAnalysis(context, costStats, isMobile),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String title, bool isMobile) {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.primary,
            borderRadius: BorderRadius.circular(TFRadius.r12),
          ),
          child: const Icon(Icons.attach_money, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            title,
            style: isMobile ? typography.sectionTitle : typography.pageTitle,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(BuildContext context, Map<String, dynamic> stats, bool isMobile) {
    final colors = context.tfColors;

    return GridView.count(
      crossAxisCount: isMobile ? 2 : 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: isMobile ? 1.3 : 1.5,
      children: [
        _buildSummaryCard(
          context,
          'Custo Total Estimado',
          'R\$ ${(stats['totalCost'] as double).toStringAsFixed(0)}',
          Icons.account_balance_wallet,
          colors.primary,
          isMobile,
        ),
        _buildSummaryCard(
          context,
          'Custo Médio / Tarefa',
          'R\$ ${(stats['averageCost'] as double).toStringAsFixed(0)}',
          Icons.trending_up,
          colors.info,
          isMobile,
        ),
        _buildSummaryCard(
          context,
          'Horas Totais',
          '${(stats['totalHours'] as double).toStringAsFixed(0)}h',
          Icons.access_time,
          colors.warning,
          isMobile,
        ),
        _buildSummaryCard(
          context,
          'Total de Tarefas',
          '${stats['taskCount']}',
          Icons.assignment,
          colors.success,
          isMobile,
        ),
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
              style: (isMobile ? typography.sectionTitle : typography.pageTitle).copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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

  Widget _buildSectionTitle(BuildContext context, String title, bool isMobile) {
    final typography = context.tfTypography;

    return Text(
      title,
      style: isMobile ? typography.sectionTitle : typography.cardTitle,
    );
  }

  Widget _buildCostByTypeChart(BuildContext context, Map<String, dynamic> stats, bool isMobile) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final costByType = stats['costByType'] as Map<String, double>;

    if (costByType.isEmpty) {
      return const TFCard(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('Sem dados de custo por tipo')),
        ),
      );
    }

    final total = stats['totalCost'] as double;

    return TFCard(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          children: costByType.entries.map((entry) {
            final percentage = total > 0 ? (entry.value / total * 100) : 0.0;
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
                        style: typography.labelMedium.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'R\$ ${entry.value.toStringAsFixed(0)} (${percentage.toStringAsFixed(1)}%)',
                        style: typography.caption.copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(TFRadius.r4),
                    child: LinearProgressIndicator(
                      value: percentage / 100,
                      minHeight: 8,
                      backgroundColor: colors.borderSubtle,
                      valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
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

  Widget _buildCostByRegionalChart(BuildContext context, Map<String, dynamic> stats, bool isMobile) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final costByRegional = stats['costByRegional'] as Map<String, double>;

    if (costByRegional.isEmpty) {
      return const TFCard(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('Sem dados de custo por regional')),
        ),
      );
    }

    final total = stats['totalCost'] as double;

    return TFCard(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          children: costByRegional.entries.map((entry) {
            final percentage = total > 0 ? (entry.value / total * 100) : 0.0;
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
                        style: typography.labelMedium.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'R\$ ${entry.value.toStringAsFixed(0)} (${percentage.toStringAsFixed(1)}%)',
                        style: typography.caption.copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(TFRadius.r4),
                    child: LinearProgressIndicator(
                      value: percentage / 100,
                      minHeight: 8,
                      backgroundColor: colors.borderSubtle,
                      valueColor: AlwaysStoppedAnimation<Color>(colors.info),
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

  Widget _buildCostAnalysis(BuildContext context, Map<String, dynamic> stats, bool isMobile) {
    final typography = context.tfTypography;
    final colors = context.tfColors;

    final mostExpensiveType = stats['mostExpensiveType'] as String;
    final mostExpensiveRegional = stats['mostExpensiveRegional'] as String;

    return TFCard(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAnalysisItem(
              context,
              'Tipo com Maior Custo',
              mostExpensiveType,
              Icons.trending_up,
              colors.primary,
            ),
            const SizedBox(height: 12),
            _buildAnalysisItem(
              context,
              'Regional com Maior Custo',
              mostExpensiveRegional,
              Icons.location_on,
              colors.info,
            ),
            const SizedBox(height: 12),
            Text(
              'Os custos são calculados com base nas horas estimadas e taxas padrão por tipo de atividade.',
              style: typography.caption.copyWith(
                color: colors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final typography = context.tfTypography;
    final colors = context.tfColors;

    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: typography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
        ),
        Expanded(
          child: Text(
            value,
            style: typography.bodyMedium.copyWith(color: colors.textSecondary),
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> _calculateCostStats(List<Task> tasks) {
    double totalCost = 0;
    double totalHours = 0;
    final costByType = <String, double>{};
    final costByRegional = <String, double>{};

    const hourlyRate = 150.0;

    for (var task in tasks) {
      final hours = (task.dataFim.difference(task.dataInicio).inHours).toDouble();
      final estimatedHours = hours > 0 ? hours : 8.0;
      final cost = estimatedHours * hourlyRate;

      totalCost += cost;
      totalHours += estimatedHours;

      final type = task.tipo.isNotEmpty ? task.tipo : 'Outro';
      costByType[type] = (costByType[type] ?? 0) + cost;

      final regional = task.regional.isNotEmpty ? task.regional : 'N/A';
      costByRegional[regional] = (costByRegional[regional] ?? 0) + cost;
    }

    final averageCost = tasks.isNotEmpty ? totalCost / tasks.length : 0.0;

    String mostExpensiveType = 'N/A';
    double maxTypeCost = 0;
    costByType.forEach((type, cost) {
      if (cost > maxTypeCost) {
        maxTypeCost = cost;
        mostExpensiveType = type;
      }
    });

    String mostExpensiveRegional = 'N/A';
    double maxRegionalCost = 0;
    costByRegional.forEach((regional, cost) {
      if (cost > maxRegionalCost) {
        maxRegionalCost = cost;
        mostExpensiveRegional = regional;
      }
    });

    return {
      'totalCost': totalCost,
      'averageCost': averageCost,
      'totalHours': totalHours,
      'taskCount': tasks.length,
      'costByType': costByType,
      'costByRegional': costByRegional,
      'mostExpensiveType': mostExpensiveType,
      'mostExpensiveRegional': mostExpensiveRegional,
    };
  }
}
