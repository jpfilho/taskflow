import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../utils/responsive.dart';

class AdvancedListView extends StatefulWidget {
  final TaskService taskService;
  final List<Task>? filteredTasks; // Tarefas já filtradas (opcional)

  const AdvancedListView({
    super.key,
    required this.taskService,
    this.filteredTasks,
  });

  @override
  State<AdvancedListView> createState() => _AdvancedListViewState();
}

class _AdvancedListViewState extends State<AdvancedListView> {
  String _sortBy = 'Data';
  bool _sortAscending = true;
  String _filterStatus = 'Todos';
  List<Task> _allTasks = [];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    // Usar tarefas filtradas se fornecidas, caso contrário buscar do TaskService
    final tasks = widget.filteredTasks ?? await widget.taskService.getAllTasks();
    setState(() {
      _allTasks = tasks;
    });
  }
  
  @override
  void didUpdateWidget(AdvancedListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recarregar se filteredTasks mudou
    if (oldWidget.filteredTasks != widget.filteredTasks) {
      _loadTasks();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final tasks = _getFilteredAndSortedTasks();

    return Column(
      children: [
        _buildHeader(isMobile, tasks.length),
        _buildFilters(isMobile),
        Expanded(
          child: _buildTasksList(tasks, isMobile),
        ),
      ],
    );
  }

  Widget _buildHeader(bool isMobile, int taskCount) {
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
            child: const Icon(Icons.list_alt, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Lista Avançada de Atividades',
              style: TextStyle(
                fontSize: isMobile ? 20 : 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E3A5F),
              ),
            ),
          ),
          Text(
            '$taskCount atividades',
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
              value: _sortBy,
              decoration: InputDecoration(
                labelText: 'Ordenar por',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
              items: ['Data', 'Status', 'Prioridade', 'Tarefa', 'Executor'].map((item) {
                return DropdownMenuItem(value: item, child: Text(item));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _sortBy = value!;
                });
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _filterStatus,
              decoration: InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
              items: ['Todos', 'ANDA', 'CONC', 'PROG'].map((item) {
                return DropdownMenuItem(value: item, child: Text(item));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _filterStatus = value!;
                });
              },
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
            onPressed: () {
              setState(() {
                _sortAscending = !_sortAscending;
              });
            },
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTasksList(List<Task> tasks, bool isMobile) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Nenhuma atividade encontrada',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        return _buildTaskCard(tasks[index], isMobile);
      },
    );
  }

  Widget _buildTaskCard(Task task, bool isMobile) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          // Mostrar detalhes da tarefa
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(task.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      task.status,
                      style: TextStyle(
                        color: _getStatusColor(task.status),
                        fontWeight: FontWeight.w600,
                        fontSize: isMobile ? 11 : 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (task.prioridade != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getPriorityColor(task.prioridade!).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.flag,
                            size: 14,
                            color: _getPriorityColor(task.prioridade!),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            task.prioridade!,
                            style: TextStyle(
                              color: _getPriorityColor(task.prioridade!),
                              fontWeight: FontWeight.w600,
                              fontSize: isMobile ? 11 : 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                task.tarefa,
                style: TextStyle(
                  fontSize: isMobile ? 15 : 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _buildInfoChip(Icons.location_on, task.locais.isNotEmpty ? task.locais.join(', ') : '', isMobile),
                  _buildInfoChip(Icons.person, task.executor, isMobile),
                  _buildInfoChip(Icons.directions_car, task.frota, isMobile),
                  _buildInfoChip(Icons.calendar_today, 
                    '${task.dataInicio.day}/${task.dataInicio.month} - ${task.dataFim.day}/${task.dataFim.month}',
                    isMobile,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, bool isMobile) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: isMobile ? 11 : 12,
            color: Colors.grey[700],
          ),
        ),
      ],
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

  Color _getPriorityColor(String priority) {
    switch (priority.toUpperCase()) {
      case 'ALTA':
        return Colors.red;
      case 'MEDIA':
        return Colors.orange;
      case 'BAIXA':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  List<Task> _getFilteredAndSortedTasks() {
    // Usar tarefas já carregadas
    var tasks = <Task>[];
    
    // Filtrar por status
    if (_filterStatus != 'Todos') {
      tasks = _allTasks.where((task) => task.status == _filterStatus).toList();
    } else {
      tasks = List<Task>.from(_allTasks);
    }

    // Criar uma nova lista modificável para ordenação
    final sortedTasks = List<Task>.from(tasks);
    
    // Ordenar
    sortedTasks.sort((a, b) {
      int comparison = 0;
      switch (_sortBy) {
        case 'Data':
          comparison = a.dataInicio.compareTo(b.dataInicio);
          break;
        case 'Status':
          comparison = a.status.compareTo(b.status);
          break;
        case 'Prioridade':
          comparison = (a.prioridade ?? '').compareTo(b.prioridade ?? '');
          break;
        case 'Tarefa':
          comparison = a.tarefa.compareTo(b.tarefa);
          break;
        case 'Executor':
          comparison = a.executor.compareTo(b.executor);
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });

    return sortedTasks;
  }
}

