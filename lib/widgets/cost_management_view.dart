import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../utils/responsive.dart';

class CostManagementView extends StatelessWidget {
  final TaskService taskService;
  final List<Task>? filteredTasks; // Tarefas já filtradas (opcional)

  const CostManagementView({
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
      final costStats = _calculateCostStats(tasks);
      return SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 12 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader('Gestão de Custos', isMobile),
            const SizedBox(height: 20),
            _buildSummaryCards(costStats, isMobile),
            const SizedBox(height: 24),
            _buildSectionTitle('Custos por Tipo de Manutenção', isMobile),
            const SizedBox(height: 12),
            _buildCostByTypeChart(costStats, isMobile),
            const SizedBox(height: 24),
            _buildSectionTitle('Custos por Regional', isMobile),
            const SizedBox(height: 12),
            _buildCostByRegionalChart(costStats, isMobile),
            const SizedBox(height: 24),
            _buildSectionTitle('Análise de Custos', isMobile),
            const SizedBox(height: 12),
            _buildCostAnalysis(costStats, isMobile),
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
        final costStats = _calculateCostStats(tasks);

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 12 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader('Gestão de Custos', isMobile),
              const SizedBox(height: 20),
              _buildSummaryCards(costStats, isMobile),
              const SizedBox(height: 24),
              _buildSectionTitle('Custos por Tipo de Manutenção', isMobile),
              const SizedBox(height: 12),
              _buildCostByTypeChart(costStats, isMobile),
              const SizedBox(height: 24),
              _buildSectionTitle('Custos por Regional', isMobile),
              const SizedBox(height: 12),
              _buildCostByRegionalChart(costStats, isMobile),
              const SizedBox(height: 24),
              _buildSectionTitle('Análise de Custos', isMobile),
              const SizedBox(height: 12),
              _buildCostAnalysis(costStats, isMobile),
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
          child: const Icon(Icons.attach_money, color: Colors.white, size: 28),
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
      ],
    );
  }

  Widget _buildSummaryCards(Map<String, dynamic> stats, bool isMobile) {
    return GridView.count(
      crossAxisCount: isMobile ? 2 : 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: isMobile ? 1.2 : 1.4,
      children: [
        _buildStatCard(
          'Custo Total',
          'R\$ ${stats['totalCost'].toStringAsFixed(2)}',
          Icons.account_balance_wallet,
          Colors.blue,
          isMobile,
        ),
        _buildStatCard(
          'Custo Médio',
          'R\$ ${stats['avgCost'].toStringAsFixed(2)}',
          Icons.trending_up,
          Colors.green,
          isMobile,
        ),
        _buildStatCard(
          'Custo Previsto',
          'R\$ ${stats['budgetedCost'].toStringAsFixed(2)}',
          Icons.calculate,
          Colors.orange,
          isMobile,
        ),
        _buildStatCard(
          'Economia',
          'R\$ ${stats['savings'].toStringAsFixed(2)}',
          Icons.savings,
          Colors.purple,
          isMobile,
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, bool isMobile) {
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
                fontSize: isMobile ? 16 : 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
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

  Widget _buildSectionTitle(String title, bool isMobile) {
    return Text(
      title,
      style: TextStyle(
        fontSize: isMobile ? 18 : 22,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF1E3A5F),
      ),
    );
  }

  Widget _buildCostByTypeChart(Map<String, dynamic> stats, bool isMobile) {
    final costByType = stats['costByType'] as Map<String, double>;
    final maxCost = costByType.values.isEmpty ? 1.0 : costByType.values.reduce((a, b) => a > b ? a : b);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          children: costByType.entries.map((entry) {
            final percentage = maxCost > 0 ? (entry.value / maxCost) : 0.0;
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
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'R\$ ${entry.value.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
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
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getTypeColor(entry.key),
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

  Widget _buildCostByRegionalChart(Map<String, dynamic> stats, bool isMobile) {
    final costByRegional = stats['costByRegional'] as Map<String, double>;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: costByRegional.entries.map((entry) {
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getTypeColor(entry.key).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getTypeColor(entry.key).withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'R\$ ${entry.value.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: isMobile ? 18 : 22,
                      fontWeight: FontWeight.bold,
                      color: _getTypeColor(entry.key),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.key,
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 14,
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCostAnalysis(Map<String, dynamic> stats, bool isMobile) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Análise de Custos',
              style: TextStyle(
                fontSize: isMobile ? 16 : 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E3A5F),
              ),
            ),
            const SizedBox(height: 16),
            _buildAnalysisRow(
              'Custo por atividade concluída',
              'R\$ ${stats['costPerCompleted'].toStringAsFixed(2)}',
              isMobile,
            ),
            const Divider(),
            _buildAnalysisRow(
              'Custo por hora trabalhada',
              'R\$ ${stats['costPerHour'].toStringAsFixed(2)}',
              isMobile,
            ),
            const Divider(),
            _buildAnalysisRow(
              'Economia vs. Orçamento',
              '${stats['savingsPercentage'].toStringAsFixed(1)}%',
              isMobile,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisRow(String label, String value, bool isMobile) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isMobile ? 13 : 15,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E3A5F),
            ),
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(String type) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
    ];
    return colors[type.hashCode % colors.length];
  }

  Map<String, dynamic> _calculateCostStats(List<Task> tasks) {
    double totalCost = 0.0;
    double budgetedCost = 0.0;
    final costByType = <String, double>{};
    final costByRegional = <String, double>{};
    int completedCount = 0;
    double totalHours = 0.0;

    for (var task in tasks) {
      // Calcular custo estimado baseado em horas e tipo
      final hours = task.horasExecutadas ?? task.horasPrevistas ?? 8.0;
      final hourlyRate = _getHourlyRate(task.tipo);
      final taskCost = hours * hourlyRate;

      totalCost += taskCost;
      budgetedCost += (task.horasPrevistas ?? 8.0) * hourlyRate;

      costByType[task.tipo] = (costByType[task.tipo] ?? 0.0) + taskCost;
      costByRegional[task.regional] = (costByRegional[task.regional] ?? 0.0) + taskCost;

      if (task.status == 'CONC') {
        completedCount++;
        totalHours += hours;
      }
    }

    final avgCost = tasks.isEmpty ? 0.0 : totalCost / tasks.length;
    final savings = budgetedCost - totalCost;
    final costPerCompleted = completedCount > 0 ? totalCost / completedCount : 0.0;
    final costPerHour = totalHours > 0 ? totalCost / totalHours : 0.0;
    final savingsPercentage = budgetedCost > 0 ? (savings / budgetedCost * 100) : 0.0;

    return {
      'totalCost': totalCost,
      'avgCost': avgCost,
      'budgetedCost': budgetedCost,
      'savings': savings,
      'costByType': costByType,
      'costByRegional': costByRegional,
      'costPerCompleted': costPerCompleted,
      'costPerHour': costPerHour,
      'savingsPercentage': savingsPercentage,
    };
  }

  double _getHourlyRate(String tipo) {
    switch (tipo) {
      case 'PMP':
        return 150.0; // Manutenção preventiva
      case 'CORRECAO':
        return 200.0; // Correção/emergência
      case 'TREINAMENTO':
        return 100.0; // Treinamento
      case 'COMPENSACAO':
        return 120.0; // Compensação
      default:
        return 130.0; // Padrão
    }
  }
}

