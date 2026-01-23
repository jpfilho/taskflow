import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../utils/responsive.dart';
import 'task_view_dialog.dart';

class MaintenanceHistoryView extends StatefulWidget {
  final TaskService taskService;
  final List<Task>? filteredTasks; // Tarefas já filtradas (opcional)

  const MaintenanceHistoryView({
    super.key,
    required this.taskService,
    this.filteredTasks,
  });

  @override
  State<MaintenanceHistoryView> createState() => _MaintenanceHistoryViewState();
}

class _MaintenanceHistoryViewState extends State<MaintenanceHistoryView> {
  String _selectedFilter = 'Todas';
  String _selectedPeriod = 'Últimos 6 meses';

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    // Se filteredTasks foi fornecido, usar diretamente
    if (widget.filteredTasks != null) {
      final allTasks = widget.filteredTasks!;
      final history = _getFilteredHistory(allTasks);
      return Column(
        children: [
          _buildHeader(isMobile, allTasks),
          _buildFilters(isMobile),
          Expanded(
            child: _buildHistoryList(history, isMobile),
          ),
        ],
      );
    }

    return FutureBuilder<List<Task>>(
      future: widget.taskService.getAllTasks(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erro: ${snapshot.error}'));
        }
        final allTasks = snapshot.data ?? [];
        final history = _getFilteredHistory(allTasks);

    return Column(
      children: [
        _buildHeader(isMobile, allTasks),
        _buildFilters(isMobile),
        Expanded(
          child: _buildHistoryList(history, isMobile),
        ),
      ],
    );
      },
    );
  }

  Widget _buildHeader(bool isMobile, List<Task> allTasks) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A5F),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.history, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Histórico de Manutenções',
              style: TextStyle(
                fontSize: isMobile ? 20 : 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E3A5F),
              ),
            ),
          ),
          Text(
            '${_getFilteredHistory(allTasks).length} registros',
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      color: Colors.grey[50],
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedFilter,
              decoration: InputDecoration(
                labelText: 'Filtro',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
              items: ['Todas', 'Concluídas', 'Canceladas', 'Preventivas', 'Corretivas'].map((item) {
                return DropdownMenuItem(value: item, child: Text(item));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedFilter = value!;
                });
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedPeriod,
              decoration: InputDecoration(
                labelText: 'Período',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
              items: ['Últimos 3 meses', 'Últimos 6 meses', 'Último ano', 'Todo período'].map((item) {
                return DropdownMenuItem(value: item, child: Text(item));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedPeriod = value!;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(List<Task> history, bool isMobile) {
    if (history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Nenhum histórico encontrado',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    // Agrupar por mês
    final grouped = <String, List<Task>>{};
    for (var task in history) {
      final monthKey = '${task.dataFim.month}/${task.dataFim.year}';
      grouped.putIfAbsent(monthKey, () => []).add(task);
    }

    return ListView.builder(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final monthKey = grouped.keys.toList()[index];
        final tasks = grouped[monthKey]!;
        return _buildMonthGroup(monthKey, tasks, isMobile);
      },
    );
  }

  Widget _buildMonthGroup(String monthKey, List<Task> tasks, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            _formatMonth(monthKey),
            style: TextStyle(
              fontSize: isMobile ? 16 : 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E3A5F),
            ),
          ),
        ),
        ...tasks.map((task) => _buildHistoryCard(task, isMobile)),
      ],
    );
  }

  Widget _buildHistoryCard(Task task, bool isMobile) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          _showTaskDetails(context, task);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 60,
                decoration: BoxDecoration(
                  color: _getStatusColor(task.status),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(task.status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            task.status,
                            style: TextStyle(
                              fontSize: isMobile ? 10 : 11,
                              color: _getStatusColor(task.status),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            task.tipo,
                            style: TextStyle(
                              fontSize: isMobile ? 10 : 11,
                              color: Colors.blue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
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
                          '${task.dataInicio.day}/${task.dataInicio.month}/${task.dataInicio.year} - ${task.dataFim.day}/${task.dataFim.month}/${task.dataFim.year}',
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
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  void _showTaskDetails(BuildContext context, Task task) {
    showDialog(
      context: context,
      builder: (context) => TaskViewDialog(task: task),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'ANDA':
        return Colors.orange;
      case 'CONC':
        return Colors.green;
      case 'PROG':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _formatMonth(String monthKey) {
    final parts = monthKey.split('/');
    final month = int.parse(parts[0]);
    final year = parts[1];
    final months = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    return '${months[month - 1]} $year';
  }

  List<Task> _getFilteredHistory(List<Task> allTasks) {
    var tasks = List<Task>.from(allTasks); // Criar cópia mutável
    final now = DateTime.now();

    // Filtrar por período
    switch (_selectedPeriod) {
      case 'Últimos 3 meses':
        final cutoff = now.subtract(const Duration(days: 90));
        tasks = tasks.where((t) => t.dataFim.isAfter(cutoff)).toList();
        break;
      case 'Últimos 6 meses':
        final cutoff = now.subtract(const Duration(days: 180));
        tasks = tasks.where((t) => t.dataFim.isAfter(cutoff)).toList();
        break;
      case 'Último ano':
        final cutoff = now.subtract(const Duration(days: 365));
        tasks = tasks.where((t) => t.dataFim.isAfter(cutoff)).toList();
        break;
    }

    // Filtrar por tipo
    switch (_selectedFilter) {
      case 'Concluídas':
        tasks = tasks.where((t) => t.status == 'CONC').toList();
        break;
      case 'Canceladas':
        tasks = tasks.where((t) => t.status == 'CANC').toList();
        break;
      case 'Preventivas':
        tasks = tasks.where((t) => t.tipo == 'PMP').toList();
        break;
      case 'Corretivas':
        tasks = tasks.where((t) => t.tipo == 'CORRECAO').toList();
        break;
    }

    // Criar lista mutável para ordenação
    final sortedTasks = List<Task>.from(tasks);
    // Ordenar por data (mais recente primeiro)
    sortedTasks.sort((a, b) => b.dataFim.compareTo(a.dataFim));

    return sortedTasks;
  }
}

