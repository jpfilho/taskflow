import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../utils/responsive.dart';
import '../design_system/taskflow_design_system.dart';

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
    final colors = context.tfColors;
    final typography = context.tfTypography;

    // Se filteredTasks foi fornecido, usar diretamente
    if (filteredTasks != null) {
      final tasks = filteredTasks!;
      final fleetStats = _calculateFleetStats(tasks);
      return SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 12 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader('Gestão de Frota', isMobile, colors, typography),
            const SizedBox(height: 20),
            _buildSummaryCards(fleetStats, isMobile, colors, typography),
            const SizedBox(height: 24),
            _buildSectionTitle('Status dos Veículos', isMobile, colors, typography),
            const SizedBox(height: 12),
            _buildFleetList(fleetStats, isMobile, colors, typography),
            const SizedBox(height: 24),
            _buildSectionTitle('Utilização por Tipo', isMobile, colors, typography),
            const SizedBox(height: 12),
            _buildUtilizationChart(fleetStats, isMobile, colors, typography),
          ],
        ),
      );
    }

    return FutureBuilder<List<Task>>(
      future: taskService.getAllTasks(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: TFLoading(message: 'Carregando frota...'));
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
        final fleetStats = _calculateFleetStats(tasks);

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 12 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader('Gestão de Frota', isMobile, colors, typography),
              const SizedBox(height: 20),
              _buildSummaryCards(fleetStats, isMobile, colors, typography),
              const SizedBox(height: 24),
              _buildSectionTitle('Status dos Veículos', isMobile, colors, typography),
              const SizedBox(height: 12),
              _buildFleetList(fleetStats, isMobile, colors, typography),
              const SizedBox(height: 24),
              _buildSectionTitle('Utilização por Tipo', isMobile, colors, typography),
              const SizedBox(height: 12),
              _buildUtilizationChart(fleetStats, isMobile, colors, typography),
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
          child: const Icon(Icons.directions_car, color: Colors.white, size: 28),
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
          'Total de Veículos',
          stats['totalVeiculos'].toString(),
          Icons.directions_car,
          colors.primary,
          isMobile,
          colors,
          typography,
        ),
        _buildStatCard(
          'Em Uso',
          stats['emUso'].toString(),
          Icons.local_shipping,
          colors.warning,
          isMobile,
          colors,
          typography,
        ),
        _buildStatCard(
          'Disponíveis',
          stats['disponiveis'].toString(),
          Icons.check_circle,
          colors.success,
          isMobile,
          colors,
          typography,
        ),
        _buildStatCard(
          'Taxa de Utilização',
          '${stats['taxaUtilizacao'].toStringAsFixed(1)}%',
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

  Widget _buildFleetList(Map<String, dynamic> stats, bool isMobile, TFSemanticColors colors, TFTypography typography) {
    final vehicles = stats['vehicles'] as Map<String, Map<String, dynamic>>;
    
    return Card(
      elevation: 0,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.borderSubtle),
      ),
      child: Column(
        children: vehicles.entries.map((entry) {
          final vehicle = entry.value;
          final status = vehicle['status'] as String;
          final statusColor = _getStatusColor(status, colors);
          return Container(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: colors.borderSubtle, width: 1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.directions_car,
                    color: statusColor,
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
                        style: typography.cardTitle.copyWith(
                          fontSize: isMobile ? 14 : 16,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${vehicle['tasks']} atividades • ${vehicle['lastMaintenance']}',
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
                    status,
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

  Widget _buildUtilizationChart(Map<String, dynamic> stats, bool isMobile, TFSemanticColors colors, TFTypography typography) {
    final utilization = stats['utilization'] as Map<String, int>;
    final maxUtil = utilization.values.isEmpty ? 1 : utilization.values.reduce((a, b) => a > b ? a : b);

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
                        style: typography.labelMedium.copyWith(
                          fontSize: isMobile ? 12 : 14,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        '${entry.value} usos',
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
                        percentage > 0.8 ? colors.primary : percentage > 0.5 ? colors.info : colors.success,
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
      case 'EM USO':
        return colors.warning;
      case 'DISPONÍVEL':
        return colors.success;
      case 'MANUTENÇÃO':
        return colors.danger;
      case 'RESERVADO':
        return colors.primary;
      default:
        return colors.textSecondary;
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

