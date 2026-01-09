import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../utils/responsive.dart';

class Dashboard extends StatelessWidget {
  final TaskService taskService;
  final List<Task>? filteredTasks; // Tarefas já filtradas (opcional)

  const Dashboard({
    super.key,
    required this.taskService,
    this.filteredTasks,
  });

  // Calcular estatísticas a partir de uma lista de tarefas
  Map<String, dynamic> _calculateStatsFromTasks(List<Task> tasks) {
    final now = DateTime.now();
    int total = tasks.length;
    int emAndamento = 0;
    int concluidas = 0;
    int programadas = 0;

    for (var task in tasks) {
      final status = task.status?.toLowerCase() ?? '';
      if (status.contains('conclu') || status.contains('finaliz')) {
        concluidas++;
      } else if (status.contains('andamento') || status.contains('exec')) {
        emAndamento++;
      } else if (task.dataInicio.isAfter(now)) {
        programadas++;
      }
    }

    return {
      'total': total,
      'emAndamento': emAndamento,
      'concluidas': concluidas,
      'programadas': programadas,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    // Se filteredTasks foi fornecido, calcular estatísticas a partir delas
    if (filteredTasks != null) {
      final stats = _calculateStatsFromTasks(filteredTasks!);
      return SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 8 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSummaryCards(stats, isMobile),
            const SizedBox(height: 16),
            _buildDetailedStats(stats, isMobile),
          ],
        ),
      );
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: taskService.getStatistics(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erro: ${snapshot.error}'));
        }
        final stats = snapshot.data ?? {};
        
        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 8 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cards de resumo
              _buildSummaryCards(stats, isMobile),
              const SizedBox(height: 16),
              // Gráficos/Estatísticas detalhadas
              _buildDetailedStats(stats, isMobile),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCards(Map<String, dynamic> stats, bool isMobile) {
    return GridView.count(
      crossAxisCount: isMobile ? 2 : 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: isMobile ? 1.2 : 1.5,
      children: [
        _buildStatCard(
          'Total',
          stats['total'].toString(),
          Icons.assignment,
          Colors.blue,
          isMobile,
        ),
        _buildStatCard(
          'Em Andamento',
          stats['emAndamento'].toString(),
          Icons.schedule,
          Colors.orange,
          isMobile,
        ),
        _buildStatCard(
          'Concluídas',
          stats['concluidas'].toString(),
          Icons.check_circle,
          Colors.green,
          isMobile,
        ),
        _buildStatCard(
          'Programadas',
          stats['programadas'].toString(),
          Icons.event,
          Colors.purple,
          isMobile,
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, bool isMobile) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 8 : 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: isMobile ? 24 : 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: isMobile ? 20 : 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: isMobile ? 10 : 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedStats(Map<String, dynamic> stats, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle('Distribuição por Status', isMobile),
        const SizedBox(height: 8),
        _buildStatusDistribution(stats['porStatus'] as Map<String, int>, stats['total'] as int, isMobile),
        const SizedBox(height: 16),
        _buildSectionTitle('Distribuição por Tipo', isMobile),
        const SizedBox(height: 8),
        _buildTypeDistribution(stats['porTipo'] as Map<String, int>, isMobile),
        const SizedBox(height: 16),
        _buildSectionTitle('Distribuição por Regional', isMobile),
        const SizedBox(height: 8),
        _buildRegionalDistribution(stats['porRegional'] as Map<String, int>, isMobile),
      ],
    );
  }

  Widget _buildSectionTitle(String title, bool isMobile) {
    return Text(
      title,
      style: TextStyle(
        fontSize: isMobile ? 14 : 16,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF1E3A5F),
      ),
    );
  }

  Widget _buildStatusDistribution(Map<String, int> distribution, int total, bool isMobile) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 8 : 16),
        child: Column(
          children: distribution.entries.map((entry) {
            final percentage = total > 0 ? (entry.value / total * 100) : 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: isMobile ? 60 : 80,
                    child: Text(
                      entry.key,
                      style: TextStyle(fontSize: isMobile ? 10 : 12),
                    ),
                  ),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        entry.key == 'ANDA' ? Colors.orange :
                        entry.key == 'CONC' ? Colors.green :
                        Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${entry.value} (${percentage.toStringAsFixed(1)}%)',
                    style: TextStyle(fontSize: isMobile ? 10 : 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTypeDistribution(Map<String, int> distribution, bool isMobile) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 8 : 16),
        child: Column(
          children: distribution.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    entry.key,
                    style: TextStyle(fontSize: isMobile ? 10 : 12),
                  ),
                  Text(
                    entry.value.toString(),
                    style: TextStyle(
                      fontSize: isMobile ? 10 : 12,
                      fontWeight: FontWeight.bold,
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

  Widget _buildRegionalDistribution(Map<String, int> distribution, bool isMobile) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 8 : 16),
        child: Column(
          children: distribution.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    entry.key,
                    style: TextStyle(fontSize: isMobile ? 10 : 12),
                  ),
                  Text(
                    entry.value.toString(),
                    style: TextStyle(
                      fontSize: isMobile ? 10 : 12,
                      fontWeight: FontWeight.bold,
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
}




