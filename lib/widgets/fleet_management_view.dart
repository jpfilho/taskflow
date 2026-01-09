import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../utils/responsive.dart';

class FleetManagementView extends StatelessWidget {
  final TaskService taskService;
  final List<Task>? filteredTasks; // Tarefas já filtradas (opcional)

  const FleetManagementView({
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
      final fleetStats = _calculateFleetStats(tasks);
      return SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 12 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader('Gestão de Frota', isMobile),
            const SizedBox(height: 20),
            _buildSummaryCards(fleetStats, isMobile),
            const SizedBox(height: 24),
            _buildSectionTitle('Status dos Veículos', isMobile),
            const SizedBox(height: 12),
            _buildFleetList(fleetStats, isMobile),
            const SizedBox(height: 24),
            _buildSectionTitle('Utilização por Tipo', isMobile),
            const SizedBox(height: 12),
            _buildUtilizationChart(fleetStats, isMobile),
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
        final fleetStats = _calculateFleetStats(tasks);

        return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader('Gestão de Frota', isMobile),
          const SizedBox(height: 20),
          _buildSummaryCards(fleetStats, isMobile),
          const SizedBox(height: 24),
          _buildSectionTitle('Status dos Veículos', isMobile),
          const SizedBox(height: 12),
          _buildFleetList(fleetStats, isMobile),
          const SizedBox(height: 24),
          _buildSectionTitle('Utilização por Tipo', isMobile),
          const SizedBox(height: 12),
          _buildUtilizationChart(fleetStats, isMobile),
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
          child: const Icon(Icons.directions_car, color: Colors.white, size: 28),
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
          'Total de Veículos',
          stats['totalVeiculos'].toString(),
          Icons.directions_car,
          Colors.blue,
          isMobile,
        ),
        _buildStatCard(
          'Em Uso',
          stats['emUso'].toString(),
          Icons.local_shipping,
          Colors.orange,
          isMobile,
        ),
        _buildStatCard(
          'Disponíveis',
          stats['disponiveis'].toString(),
          Icons.check_circle,
          Colors.green,
          isMobile,
        ),
        _buildStatCard(
          'Taxa de Utilização',
          '${stats['taxaUtilizacao'].toStringAsFixed(1)}%',
          Icons.trending_up,
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

  Widget _buildSectionTitle(String title, bool isMobile) {
    return Text(
      title,
      style: TextStyle(
        fontSize: isMobile ? 16 : 20,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF1E3A5F),
      ),
    );
  }

  Widget _buildFleetList(Map<String, dynamic> stats, bool isMobile) {
    final vehicles = stats['vehicles'] as Map<String, Map<String, dynamic>>;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: vehicles.entries.map((entry) {
          final vehicle = entry.value;
          final status = vehicle['status'] as String;
          return Container(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!, width: 1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.directions_car,
                    color: _getStatusColor(status),
                    size: isMobile ? 24 : 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key,
                        style: TextStyle(
                          fontSize: isMobile ? 14 : 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${vehicle['tasks']} atividades • ${vehicle['lastMaintenance']}',
                        style: TextStyle(
                          fontSize: isMobile ? 11 : 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: isMobile ? 10 : 11,
                      color: _getStatusColor(status),
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

  Widget _buildUtilizationChart(Map<String, dynamic> stats, bool isMobile) {
    final utilization = stats['utilization'] as Map<String, int>;
    final maxUtil = utilization.values.isEmpty ? 1 : utilization.values.reduce((a, b) => a > b ? a : b);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          children: utilization.entries.map((entry) {
            final percentage = maxUtil > 0 ? (entry.value / maxUtil) : 0.0;
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
                        '${entry.value} usos',
                        style: TextStyle(
                          fontSize: isMobile ? 11 : 12,
                          color: Colors.grey[600],
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
                        percentage > 0.8 ? Colors.blue : percentage > 0.5 ? Colors.cyan : Colors.teal,
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

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'EM USO':
        return Colors.orange;
      case 'DISPONÍVEL':
        return Colors.green;
      case 'MANUTENÇÃO':
        return Colors.red;
      case 'RESERVADO':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Map<String, dynamic> _calculateFleetStats(List<Task> tasks) {
    final vehicles = <String, Map<String, dynamic>>{};
    final utilization = <String, int>{};
    int emUso = 0;
    int disponiveis = 0;

    for (var task in tasks) {
      if (task.frota.isNotEmpty && task.frota != '-N/A-') {
        if (!vehicles.containsKey(task.frota)) {
          vehicles[task.frota] = {
            'tasks': 0,
            'status': task.status == 'ANDA' ? 'EM USO' : 'DISPONÍVEL',
            'lastMaintenance': 'Última: ${DateTime.now().day}/${DateTime.now().month}',
          };
        }
        vehicles[task.frota]!['tasks'] = (vehicles[task.frota]!['tasks'] as int) + 1;
        
        final tipo = task.tipo;
        utilization[tipo] = (utilization[tipo] ?? 0) + 1;

        if (task.status == 'ANDA') {
          emUso++;
          vehicles[task.frota]!['status'] = 'EM USO';
        } else {
          disponiveis++;
        }
      }
    }

    final totalVeiculos = vehicles.length;
    final taxaUtilizacao = totalVeiculos > 0 ? (emUso / totalVeiculos * 100) : 0.0;

    return {
      'totalVeiculos': totalVeiculos,
      'emUso': emUso,
      'disponiveis': disponiveis,
      'taxaUtilizacao': taxaUtilizacao,
      'vehicles': vehicles,
      'utilization': utilization,
    };
  }
}

