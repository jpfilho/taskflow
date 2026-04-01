import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../services/status_service.dart';
import '../utils/responsive.dart';

class PlannerView extends StatefulWidget {
  final List<Task> tasks;
  final TaskService taskService;
  final Function() onTasksUpdated;
  final Function(Task) onTaskSelected;
  final Function(Task) onEdit;
  final Function(Task) onDelete;
  final Function(Task) onDuplicate;
  final Function(Task) onCreateSubtask;

  const PlannerView({
    super.key,
    required this.tasks,
    required this.taskService,
    required this.onTasksUpdated,
    required this.onTaskSelected,
    required this.onEdit,
    required this.onDelete,
    required this.onDuplicate,
    required this.onCreateSubtask,
  });

  @override
  State<PlannerView> createState() => _PlannerViewState();
}

class _PlannerViewState extends State<PlannerView> {
  final StatusService _statusService = StatusService();
  List<Map<String, dynamic>> _statusList = [];
  bool _isLoadingStatus = true;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final statuses = await _statusService.getAllStatus();
      setState(() {
        _statusList = statuses.map((s) => {
          'id': s.id,
          'codigo': s.codigo,
          'descricao': s.status, // Status.status é o nome/descrição
          'cor': s.cor,
        }).toList();
        _isLoadingStatus = false;
      });
    } catch (e) {
      print('❌ Erro ao carregar status: $e');
      setState(() {
        _isLoadingStatus = false;
      });
    }
  }

  // Agrupar tarefas por status
  Map<String, List<Task>> _groupTasksByStatus() {
    final Map<String, List<Task>> grouped = {};
    
    // Inicializar todas as colunas
    for (var status in _statusList) {
      grouped[status['codigo'] as String] = [];
    }
    
    // Agrupar tarefas
    for (var task in widget.tasks) {
      final statusCode = task.status;
      if (grouped.containsKey(statusCode)) {
        grouped[statusCode]!.add(task);
      } else {
        // Se o status não estiver na lista, adicionar à primeira coluna
        if (grouped.isNotEmpty) {
          grouped[grouped.keys.first]!.add(task);
        }
      }
    }
    
    return grouped;
  }

  Future<void> _moveTaskToStatus(Task task, String newStatus) async {
    try {
      print('🔄 Movendo tarefa ${task.tarefa} de ${task.status} para $newStatus');
      
      // Buscar o ID do novo status
      final newStatusObj = _statusList.firstWhere(
        (s) => s['codigo'] == newStatus,
        orElse: () => _statusList.first,
      );
      
      print('📋 Novo status: ${newStatusObj['codigo']} (${newStatusObj['descricao']})');
      print('📋 Status ID: ${newStatusObj['id']}');
      
      // Atualizar a tarefa usando copyWith
      final updatedTask = task.copyWith(
        statusId: newStatusObj['id'] as String,
        status: newStatusObj['codigo'] as String,
        statusNome: newStatusObj['descricao'] as String,
      );
      
      print('✅ Tarefa atualizada localmente. Chamando updateTask...');
      final result = await widget.taskService.updateTask(task.id, updatedTask);
      print('✅ updateTask retornou: ${result != null ? "sucesso" : "null"}');
      
      // Recarregar tarefas
      widget.onTasksUpdated();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tarefa movida para ${newStatusObj['descricao']}'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Erro ao mover tarefa: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao mover tarefa: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingStatus) {
      return const Center(child: CircularProgressIndicator());
    }

    final groupedTasks = _groupTasksByStatus();
    final isMobile = Responsive.isMobile(context);

    return Container(
      color: Colors.grey[100],
      child: Column(
        children: [
          // Header do Planner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.view_kanban, color: Color(0xFF1E3A5F)),
                const SizedBox(width: 8),
                const Text(
                  'Planner',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Nova Tarefa',
                  onPressed: () {
                    // Abrir dialog de nova tarefa
                    widget.onEdit(Task(
                      id: '',
                      statusId: _statusList.first['id'] as String,
                      status: _statusList.first['codigo'] as String,
                      statusNome: _statusList.first['descricao'] as String,
                      regionalId: null,
                      divisaoId: null,
                      segmentoId: null,
                      localIds: [],
                      executorIds: [],
                      equipeIds: [],
                      localId: null,
                      equipeId: null,
                      regional: '',
                      divisao: '',
                      locais: [],
                      segmento: '',
                      equipes: [],
                      equipeExecutores: null,
                      tipo: '',
                      ordem: null,
                      tarefa: '',
                      executores: [],
                      executor: '',
                      frota: '',
                      coordenador: '',
                      si: '',
                      dataInicio: DateTime.now(),
                      dataFim: DateTime.now().add(const Duration(days: 1)),
                      ganttSegments: [],
                      observacoes: null,
                      horasPrevistas: null,
                      horasExecutadas: null,
                      prioridade: null,
                      dataCriacao: null,
                      parentId: null,
                    ));
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.filter_list),
                  tooltip: 'Filtros',
                  onPressed: () {
                    // Implementar filtros
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.view_week),
                  tooltip: 'Agrupar por',
                  onPressed: () {
                    // Implementar agrupamento
                  },
                ),
              ],
            ),
          ),
          
          // Colunas do Kanban
          Expanded(
            child: _buildKanbanColumns(groupedTasks, isMobile),
          ),
        ],
      ),
    );
  }

  Widget _buildKanbanColumns(Map<String, List<Task>> groupedTasks, bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _statusList.length,
        itemBuilder: (context, index) {
          final status = _statusList[index];
          final statusCode = status['codigo'] as String;
          final tasks = groupedTasks[statusCode] ?? [];
          final color = _parseColor(status['cor'] as String?);
          
          return _buildStatusColumn(
            status: status,
            tasks: tasks,
            color: color,
            isMobile: isMobile,
          );
        },
      ),
    );
  }

  Widget _buildStatusColumn({
    required Map<String, dynamic> status,
    required List<Task> tasks,
    required Color color,
    required bool isMobile,
  }) {
    final statusCode = status['codigo'] as String;
    final statusDesc = status['descricao'] as String;
    
    return DragTarget<Task>(
      onWillAcceptWithDetails: (details) {
        final task = details.data;
        final canAccept = task.status != statusCode;
        print('🔍 Verificando se pode aceitar tarefa ${task.tarefa} (status: ${task.status}) na coluna $statusCode: $canAccept');
        return canAccept;
      },
      onAcceptWithDetails: (details) {
        final task = details.data;
        print('📦 Tarefa ${task.tarefa} aceita na coluna $statusCode');
        if (task.status != statusCode) {
          _moveTaskToStatus(task, statusCode);
        }
      },
      onLeave: (task) {
        print('👋 Tarefa ${task?.tarefa} saiu da área da coluna $statusCode');
      },
      builder: (context, candidateData, rejectedData) {
        final isDraggingOver = candidateData.isNotEmpty;
        return Container(
          width: isMobile ? 280 : 320,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: isDraggingOver
                ? Border.all(color: color, width: 3, style: BorderStyle.solid)
                : null,
            boxShadow: [
              BoxShadow(
                color: isDraggingOver
                    ? color.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.1),
                spreadRadius: isDraggingOver ? 2 : 1,
                blurRadius: isDraggingOver ? 4 : 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header da coluna
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDraggingOver
                      ? color.withOpacity(0.2)
                      : color.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        statusDesc,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A5F),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${tasks.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Lista de tarefas
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDraggingOver
                        ? color.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: tasks.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isDraggingOver ? Icons.arrow_downward : Icons.inbox,
                                  color: isDraggingOver ? color : Colors.grey[400],
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  isDraggingOver
                                      ? 'Solte aqui para mover'
                                      : 'Nenhuma tarefa',
                                  style: TextStyle(
                                    color: isDraggingOver ? color : Colors.grey[600],
                                    fontSize: 12,
                                    fontWeight: isDraggingOver ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: tasks.length,
                          itemBuilder: (context, index) {
                            final task = tasks[index];
                            return _buildTaskCard(
                              task: task,
                              color: color,
                              key: ValueKey('${task.id}_$statusCode'),
                            );
                          },
                        ),
                ),
              ),
              
              // Botão para adicionar tarefa nesta coluna
              Container(
                padding: const EdgeInsets.all(8),
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Criar nova tarefa com este status
                    widget.onEdit(Task(
                      id: '',
                      statusId: status['id'] as String,
                      status: statusCode,
                      statusNome: statusDesc,
                      regionalId: null,
                      divisaoId: null,
                      segmentoId: null,
                      localIds: [],
                      executorIds: [],
                      equipeIds: [],
                      localId: null,
                      equipeId: null,
                      regional: '',
                      divisao: '',
                      locais: [],
                      segmento: '',
                      equipes: [],
                      equipeExecutores: null,
                      tipo: '',
                      ordem: null,
                      tarefa: '',
                      executores: [],
                      executor: '',
                      frota: '',
                      coordenador: '',
                      si: '',
                      dataInicio: DateTime.now(),
                      dataFim: DateTime.now().add(const Duration(days: 1)),
                      ganttSegments: [],
                      observacoes: null,
                      horasPrevistas: null,
                      horasExecutadas: null,
                      prioridade: null,
                      dataCriacao: null,
                      parentId: null,
                    ));
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Adicionar tarefa'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: color,
                    side: BorderSide(color: color),
                    minimumSize: const Size(double.infinity, 36),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTaskCard({
    required Task task,
    required Color color,
    required Key key,
  }) {
    final isOverdue = task.dataFim.isBefore(DateTime.now()) && task.status != 'CONC';
    
    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isOverdue ? Colors.red : color.withOpacity(0.3),
          width: isOverdue ? 2 : 1,
        ),
      ),
      child: Draggable<Task>(
        data: task,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        // Remover restrição de eixo para permitir arrastar em todas as direções
        feedback: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 280,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _buildTaskCardContent(task, color),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.3,
          child: Container(
            padding: const EdgeInsets.all(12),
            child: _buildTaskCardContent(task, color),
          ),
        ),
        onDragStarted: () {
          print('🚀 Iniciando drag da tarefa: ${task.tarefa}');
        },
        onDragEnd: (details) {
          print('🏁 Drag finalizado: ${task.tarefa}');
          if (details.wasAccepted) {
            print('✅ Tarefa foi aceita em uma nova coluna');
          } else {
            print('❌ Tarefa não foi aceita');
          }
        },
        child: InkWell(
          onTap: () => widget.onTaskSelected(task),
          onLongPress: () => _showTaskMenu(task),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: _buildTaskCardContent(task, color),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskCardContent(Task task, Color color) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final isOverdue = task.dataFim.isBefore(DateTime.now()) && task.status != 'CONC';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título da tarefa
        Text(
          task.tarefa,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A5F),
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        
        // Informações adicionais
        if (task.locais.isNotEmpty)
          Row(
            children: [
              Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  task.locais.first,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        if (task.locais.isNotEmpty) const SizedBox(height: 4),
        
        // Datas
        Row(
          children: [
            Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              '${dateFormat.format(task.dataInicio)} - ${dateFormat.format(task.dataFim)}',
              style: TextStyle(
                fontSize: 12,
                color: isOverdue ? Colors.red : Colors.grey[600],
                fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        
        // Executores
        if (task.executores.isNotEmpty)
          Row(
            children: [
              Icon(Icons.person, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  task.executores.first,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        
        // Prioridade
        if (task.prioridade != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getPriorityColor(task.prioridade!).withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                task.prioridade!,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: _getPriorityColor(task.prioridade!),
                ),
              ),
            ),
          ),
        
        // Subtarefas
        if (task.parentId != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(Icons.subdirectory_arrow_right, size: 14, color: Colors.blue),
                const SizedBox(width: 4),
                Text(
                  'Subtarefa',
                  style: TextStyle(fontSize: 10, color: Colors.blue),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _showTaskMenu(Task task) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text('Visualizar'),
              onTap: () {
                Navigator.pop(context);
                widget.onTaskSelected(task);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Editar'),
              onTap: () {
                Navigator.pop(context);
                widget.onEdit(task);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Duplicar'),
              onTap: () {
                Navigator.pop(context);
                widget.onDuplicate(task);
              },
            ),
            if (task.isMainTask)
              ListTile(
                leading: const Icon(Icons.add_task),
                title: const Text('Criar Subtarefa'),
                onTap: () {
                  Navigator.pop(context);
                  widget.onCreateSubtask(task);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Excluir', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(task);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(Task task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Tem certeza que deseja excluir a tarefa "${task.tarefa}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onDelete(task);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String? colorString) {
    if (colorString == null || colorString.isEmpty) {
      return Colors.grey;
    }
    
    try {
      // Formato: "#RRGGBB" ou "RRGGBB"
      String hex = colorString.replaceAll('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      }
    } catch (e) {
      print('⚠️ Erro ao parsear cor: $colorString - $e');
    }
    
    return Colors.grey;
  }

  Color _getPriorityColor(String prioridade) {
    switch (prioridade.toUpperCase()) {
      case 'ALTA':
        return Colors.red;
      case 'MEDIA':
      case 'MÉDIA':
        return Colors.orange;
      case 'BAIXA':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

