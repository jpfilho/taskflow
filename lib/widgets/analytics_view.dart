import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../utils/responsive.dart';

class AnalyticsView extends StatelessWidget {
  final TaskService taskService;
  final List<Task>? filteredTasks; // Tarefas já filtradas (opcional)

  const AnalyticsView({
    super.key,
    required this.taskService,
    this.filteredTasks,
  });

  // Calcular estatísticas a partir de uma lista de tarefas (mesma lógica do Dashboard)
  Map<String, dynamic> _calculateStatsFromTasks(List<Task> tasks) {
    final now = DateTime.now();
    int total = tasks.length;
    int emAndamento = 0;
    int concluidas = 0;
    int programadas = 0;

    for (var task in tasks) {
      final status = task.status.toLowerCase() ?? '';
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
        padding: EdgeInsets.all(isMobile ? 12 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader('Análises e Gráficos', isMobile),
            const SizedBox(height: 20),
            _buildChartCard('Distribuição por Status', _buildStatusChart(stats, isMobile), isMobile),
            const SizedBox(height: 16),
            _buildChartCard('Atividades por Tipo', _buildTypeChart(stats, isMobile), isMobile),
            const SizedBox(height: 16),
            _buildChartCard('Atividades por Regional', _buildRegionalChart(stats, isMobile), isMobile),
            const SizedBox(height: 16),
            _buildPerformanceMetrics(stats, isMobile),
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
          padding: EdgeInsets.all(isMobile ? 12 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader('Análises e Gráficos', isMobile),
              const SizedBox(height: 20),
              _buildChartCard('Distribuição por Status', _buildStatusChart(stats, isMobile), isMobile),
              const SizedBox(height: 16),
              _buildChartCard('Atividades por Tipo', _buildTypeChart(stats, isMobile), isMobile),
              const SizedBox(height: 16),
              _buildChartCard('Atividades por Regional', _buildRegionalChart(stats, isMobile), isMobile),
              const SizedBox(height: 16),
              _buildPerformanceMetrics(stats, isMobile),
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
          child: const Icon(Icons.analytics, color: Colors.white, size: 28),
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

  Widget _buildChartCard(String title, Widget chart, bool isMobile) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: isMobile ? 16 : 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E3A5F),
              ),
            ),
            const SizedBox(height: 16),
            chart,
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChart(Map<String, dynamic> stats, bool isMobile) {
    final porStatus = stats['porStatus'] as Map<String, int>;
    final total = stats['total'] as int;
    
    return Column(
      children: porStatus.entries.map((entry) {
        final percentage = total > 0 ? (entry.value / total * 100) : 0.0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: isMobile ? 60 : 80,
                child: Text(
                  entry.key,
                  style: TextStyle(fontSize: isMobile ? 12 : 14),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: percentage / 100,
                        minHeight: isMobile ? 24 : 32,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          entry.key == 'ANDA' ? Colors.orange :
                          entry.key == 'CONC' ? Colors.green :
                          Colors.blue,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Center(
                        child: Text(
                          '${entry.value} (${percentage.toStringAsFixed(1)}%)',
                          style: TextStyle(
                            fontSize: isMobile ? 11 : 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTypeChart(Map<String, dynamic> stats, bool isMobile) {
    final porTipo = stats['porTipo'] as Map<String, int>;
    final maxValue = porTipo.values.isEmpty ? 1 : porTipo.values.reduce((a, b) => a > b ? a : b);

    return Column(
      children: porTipo.entries.map((entry) {
        final percentage = maxValue > 0 ? (entry.value / maxValue) : 0.0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  entry.key,
                  style: TextStyle(fontSize: isMobile ? 12 : 14),
                ),
              ),
              Expanded(
                flex: 2,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: percentage,
                    minHeight: isMobile ? 20 : 24,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getTypeColor(entry.key),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: isMobile ? 40 : 50,
                child: Text(
                  entry.value.toString(),
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 14,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRegionalChart(Map<String, dynamic> stats, bool isMobile) {
    final porRegional = stats['porRegional'] as Map<String, int>;
    
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: porRegional.entries.map((entry) {
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
                entry.value.toString(),
                style: TextStyle(
                  fontSize: isMobile ? 24 : 32,
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
    );
  }

  Widget _buildPerformanceMetrics(Map<String, dynamic> stats, bool isMobile) {
    final total = stats['total'] as int;
    final concluidas = stats['concluidas'] as int;
    final emAndamento = stats['emAndamento'] as int;
    final taxaConclusao = total > 0 ? (concluidas / total * 100) : 0.0;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Métricas de Performance',
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
                  child: _buildMetricCard(
                    'Taxa de Conclusão',
                    '${taxaConclusao.toStringAsFixed(1)}%',
                    Icons.check_circle,
                    Colors.green,
                    isMobile,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    'Em Andamento',
                    emAndamento.toString(),
                    Icons.schedule,
                    Colors.orange,
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

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, bool isMobile) {
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
              fontSize: isMobile ? 20 : 24,
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

  Color _getTypeColor(String type) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.red,
      Colors.cyan,
    ];
    return colors[type.hashCode % colors.length];
  }
}




