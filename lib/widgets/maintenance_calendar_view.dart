import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/task.dart';
import '../models/grupo_chat.dart';
import '../services/task_service.dart';
import '../services/anexo_service.dart';
import '../services/chat_service.dart';
import '../services/divisao_service.dart';
import '../services/nota_sap_service.dart';
import '../services/ordem_service.dart';
import '../services/at_service.dart';
import '../services/si_service.dart';
import '../models/nota_sap.dart';
import '../models/ordem.dart';
import '../models/at.dart';
import '../models/si.dart';
import '../widgets/chat_screen.dart';
import '../utils/responsive.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MaintenanceCalendarView extends StatefulWidget {
  final TaskService taskService;
  final List<Task>? filteredTasks; // Tarefas já filtradas (opcional)
  final Function(Task)? onEdit;
  final Function(Task)? onDelete;
  final Function(Task)? onDuplicate;
  final Function(Task)? onCreateSubtask;

  const MaintenanceCalendarView({
    super.key,
    required this.taskService,
    this.filteredTasks,
    this.onEdit,
    this.onDelete,
    this.onDuplicate,
    this.onCreateSubtask,
  });

  @override
  State<MaintenanceCalendarView> createState() => _MaintenanceCalendarViewState();
}

class _MaintenanceCalendarViewState extends State<MaintenanceCalendarView> {
  DateTime _currentMonth = DateTime.now();
  
  // Serviços do SAP
  final NotaSAPService _notaSAPService = NotaSAPService();
  final OrdemService _ordemService = OrdemService();
  final ATService _atService = ATService();
  final SIService _siService = SIService();

  // Mapas para armazenar contagens do SAP por tarefa
  Map<String, int> _notasSAPCount = {};
  Map<String, int> _ordensCount = {};
  Map<String, int> _atsCount = {};
  Map<String, int> _sisCount = {};

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    // Se filteredTasks foi fornecido, usar diretamente; caso contrário, buscar do TaskService
    if (widget.filteredTasks != null) {
      final tasks = _getTasksForMonth(widget.filteredTasks!);
      return Column(
        children: [
          _buildMonthNavigator(isMobile),
          Expanded(
            child: _buildCalendar(tasks, isMobile),
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
        final tasks = _getTasksForMonth(allTasks);

        return Column(
          children: [
            _buildMonthNavigator(isMobile),
            Expanded(
              child: _buildCalendar(tasks, isMobile),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMonthNavigator(bool isMobile) {
    final monthNames = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      color: Colors.grey[50],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
              });
            },
          ),
          Text(
            '${monthNames[_currentMonth.month - 1]} ${_currentMonth.year}',
            style: TextStyle(
              fontSize: isMobile ? 16 : 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(Map<int, List<Task>> tasks, bool isMobile) {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final daysInMonth = lastDay.day;
    final startWeekday = firstDay.weekday;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calcular o espaço disponível (altura total - cabeçalho - padding)
        final headerHeight = isMobile ? 40.0 : 50.0;
        final padding = isMobile ? 16.0 : 24.0;
        final spacing = 8.0;
        final availableHeight = constraints.maxHeight - headerHeight - padding - spacing;
        
        // Converter startWeekday para formato onde domingo = 0
        final startWeekdayAdjusted = startWeekday % 7;
        final totalCells = daysInMonth + startWeekdayAdjusted;
        final weeksNeeded = (totalCells / 7).ceil();
        
        // Calcular altura de cada célula baseado no espaço disponível
        final cellSpacing = 4.0;
        final totalSpacing = (weeksNeeded - 1) * cellSpacing;
        final cellHeight = (availableHeight - totalSpacing) / weeksNeeded;
        
        // Calcular largura de cada célula (7 colunas)
        final availableWidth = constraints.maxWidth - padding;
        final totalCellSpacing = 6 * cellSpacing; // 6 espaços entre 7 colunas
        final cellWidth = (availableWidth - totalCellSpacing) / 7;
        
        return Padding(
          padding: EdgeInsets.all(isMobile ? 8 : 12),
          child: Column(
            children: [
              _buildWeekdayHeaders(isMobile),
              SizedBox(height: spacing),
              Expanded(
                child: _buildCalendarGrid(
                  tasks, 
                  daysInMonth, 
                  startWeekday, 
                  isMobile,
                  cellWidth: cellWidth,
                  cellHeight: cellHeight,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWeekdayHeaders(bool isMobile) {
    final weekdays = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
    return Row(
      children: weekdays.map((day) {
        return Expanded(
          child: Center(
            child: Text(
              day,
              style: TextStyle(
                fontSize: isMobile ? 11 : 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCalendarGrid(
    Map<int, List<Task>> tasks, 
    int daysInMonth, 
    int startWeekday, 
    bool isMobile,
    {required double cellWidth, required double cellHeight}
  ) {
    // Converter startWeekday para formato onde domingo = 0 (para alinhar com o grid que começa em domingo)
    // startWeekday em Dart: 1=segunda, 2=terça, ..., 7=domingo
    // Grid: 0=domingo, 1=segunda, ..., 6=sábado
    final startWeekdayAdjusted = startWeekday % 7; // Converte 7 (domingo) para 0
    
    // Calcular o número total de células necessárias (dias do mês + espaços vazios no início)
    final totalCells = daysInMonth + startWeekdayAdjusted;
    // Calcular o número de semanas necessárias (arredondar para cima)
    final weeksNeeded = (totalCells / 7).ceil();
    final itemCount = weeksNeeded * 7;
    
    return GridView.builder(
      shrinkWrap: false,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: cellWidth / cellHeight, // Usar proporção calculada dinamicamente
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // Se está antes do primeiro dia do mês, mostrar célula vazia
        if (index < startWeekdayAdjusted) {
          return const SizedBox.shrink();
        }
        
        // Calcular o dia do mês
        final day = index - startWeekdayAdjusted + 1;
        
        // Se o dia excede os dias do mês, mostrar célula vazia
        if (day > daysInMonth) {
          return const SizedBox.shrink();
        }

        final dayTasks = tasks[day] ?? [];
        final isToday = day == DateTime.now().day && 
                       _currentMonth.month == DateTime.now().month &&
                       _currentMonth.year == DateTime.now().year;

        return _buildDayCell(day, dayTasks, isToday, isMobile);
      },
    );
  }

  Widget _buildDayCell(int day, List<Task> tasks, bool isToday, bool isMobile) {
    return InkWell(
      onTap: () {
        if (tasks.isNotEmpty) {
          _showDayTasks(day, tasks);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isToday ? Colors.blue.withOpacity(0.1) : Colors.white,
          border: Border.all(
            color: isToday ? Colors.blue : Colors.grey[300]!,
            width: isToday ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(4),
              child: Text(
                day.toString(),
                style: TextStyle(
                  fontSize: isMobile ? 12 : 14,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  color: isToday ? Colors.blue : Colors.grey[800],
                ),
              ),
            ),
            if (tasks.isNotEmpty)
              Expanded(
                child: Column(
                  children: tasks.take(3).map((task) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getStatusColor(task.status),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        task.tarefa,
                        style: TextStyle(
                          fontSize: isMobile ? 7 : 8,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                ),
              ),
            if (tasks.length > 3)
              Padding(
                padding: const EdgeInsets.all(2),
                child: Text(
                  '+${tasks.length - 3}',
                  style: TextStyle(
                    fontSize: isMobile ? 8 : 9,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showDayTasks(int day, List<Task> tasks) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _DayTasksModal(
        day: day,
        tasks: tasks,
        buildTaskCard: (task, {imagens, onEdit, onDelete, onDuplicate, onCreateSubtask, imagePageControllers, currentImageIndex}) {
          return _buildTaskCard(
            task,
            imagens: imagens,
            onEdit: onEdit,
            onDelete: onDelete,
            onDuplicate: onDuplicate,
            onCreateSubtask: onCreateSubtask,
            imagePageControllers: imagePageControllers,
            currentImageIndex: currentImageIndex,
          );
        },
        getStatusColor: _getStatusColor,
        onEdit: widget.onEdit,
        onDelete: widget.onDelete,
        onDuplicate: widget.onDuplicate,
        onCreateSubtask: widget.onCreateSubtask,
      ),
    );
  }

  Widget _buildTaskCard(Task task, {
    List<String>? imagens,
    Function(Task)? onEdit,
    Function(Task)? onDelete,
    Function(Task)? onDuplicate,
    Function(Task)? onCreateSubtask,
    Map<String, PageController>? imagePageControllers,
    Map<String, int>? currentImageIndex,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: _getStatusColor(task.status),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.tarefa,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${task.tipo} • ${task.executor}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(task.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  task.status,
                  style: TextStyle(
                    color: _getStatusColor(task.status),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              // Botão de chat
              IconButton(
                icon: const Icon(Icons.chat, size: 20, color: Colors.blue),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _abrirChatTarefa(task),
                tooltip: 'Abrir chat da tarefa',
              ),
              if (onEdit != null || onDelete != null || onDuplicate != null || onCreateSubtask != null)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        onEdit?.call(task);
                        break;
                      case 'delete':
                        onDelete?.call(task);
                        break;
                      case 'duplicate':
                        onDuplicate?.call(task);
                        break;
                      case 'subtask':
                        onCreateSubtask?.call(task);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    if (onEdit != null)
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('Editar'),
                          ],
                        ),
                      ),
                    if (onDuplicate != null)
                      const PopupMenuItem(
                        value: 'duplicate',
                        child: Row(
                          children: [
                            Icon(Icons.copy, size: 18, color: Colors.orange),
                            SizedBox(width: 8),
                            Text('Duplicar'),
                          ],
                        ),
                      ),
                    if (onCreateSubtask != null && task.isMainTask)
                      const PopupMenuItem(
                        value: 'subtask',
                        child: Row(
                          children: [
                            Icon(Icons.add_task, size: 18, color: Colors.green),
                            SizedBox(width: 8),
                            Text('Inserir Subtarefa'),
                          ],
                        ),
                      ),
                    if (onDelete != null)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Excluir'),
                          ],
                        ),
                      ),
                  ],
                ),
            ],
          ),
          // Carrossel de anexos (imagens)
          if (imagens != null && imagens.isNotEmpty) ...[
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                // Buscar o controller e índice atual para esta tarefa
                final controller = imagePageControllers?[task.id];
                final currentIdx = currentImageIndex?[task.id] ?? 0;
                
                return _buildImageCarousel(
                  task,
                  imagens,
                  controller: controller,
                  currentIndex: currentIdx,
                  onPageChanged: (index) {
                    // Atualizar o índice através do callback
                    if (currentImageIndex != null) {
                      currentImageIndex[task.id] = index;
                    }
                  },
                );
              },
            ),
          ],
          if (task.locais.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    task.locais.join(', '),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (task.observacoes != null && task.observacoes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Observações:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              task.observacoes!,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
          // Informações SAP
          const SizedBox(height: 12),
          _buildSAPActionButton(task),
          ],
        ),
      ),
    );
  }

  Future<void> _abrirChatTarefa(Task task) async {
    try {
      final chatService = ChatService();
      
      // Buscar ou criar grupo de chat para a tarefa
      GrupoChat? grupoChat = await chatService.obterGrupoPorTarefaId(task.id);
      
      // Se não existir, criar um novo grupo
      if (grupoChat == null) {
        // Obter ou criar comunidade baseada na divisão e segmento da tarefa
        if (task.divisaoId != null && task.segmentoId != null) {
          final divisaoService = DivisaoService();
          final divisao = await divisaoService.getDivisaoById(task.divisaoId!);
          
          if (divisao == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Não é possível criar chat: divisão não encontrada'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            return;
          }
          
          // Verificar se o segmento está na lista de segmentos da divisão
          if (!divisao.segmentoIds.contains(task.segmentoId)) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Não é possível criar chat: segmento não encontrado na divisão'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            return;
          }
          
          // Obter nome do segmento
          final segmentoIndex = divisao.segmentoIds.indexOf(task.segmentoId!);
          final segmentoNome = segmentoIndex >= 0 && segmentoIndex < divisao.segmentos.length
              ? divisao.segmentos[segmentoIndex]
              : 'Segmento';
          
          final comunidade = await chatService.criarOuObterComunidade(
            task.regionalId ?? '',
            task.regional,
            task.divisaoId!,
            divisao.divisao,
            task.segmentoId!,
            segmentoNome,
          );
          
          grupoChat = await chatService.criarOuObterGrupo(
            task.id,
            task.tarefa,
            comunidade.id!,
          );
        } else {
          // Se não tiver divisão/segmento, mostrar mensagem
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Não é possível criar chat: tarefa precisa ter divisão e segmento configurados.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
      }
      
      // Abrir tela de chat em uma nova rota
      if (mounted) {
        final grupoId = grupoChat.id;
        if (grupoId != null && grupoId.isNotEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                grupoId: grupoId,
                onBack: () => Navigator.pop(context),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao abrir chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildImageCarousel(Task task, List<String> imagens, {
    PageController? controller,
    ValueChanged<int>? onPageChanged,
    int? currentIndex,
  }) {
    final hasMultipleImages = imagens.length > 1;
    
    // Se houver apenas uma imagem, mostrar diretamente sem PageView
    if (!hasMultipleImages) {
      return AspectRatio(
        aspectRatio: 1.0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: imagens.first,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: Colors.grey[200],
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: Colors.grey[200],
              child: const Center(
                child: Icon(
                  Icons.image,
                  size: 48,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Se houver múltiplas imagens, criar carrossel
    return AspectRatio(
      aspectRatio: 1.0,
      child: Stack(
        children: [
          PageView.builder(
            controller: controller,
            itemCount: imagens.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, index) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: imagens[index],
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(
                        Icons.image,
                        size: 48,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          // Indicadores de página (dots)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                imagens.length,
                (index) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (currentIndex ?? 0) == index
                        ? Colors.blue
                        : Colors.white.withOpacity(0.8),
                    border: Border.all(
                      color: Colors.grey[400]!,
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSAPActionButton(Task task) {
    final totalSAPItems = (_notasSAPCount[task.id] ?? 0) +
        (_ordensCount[task.id] ?? 0) +
        (_atsCount[task.id] ?? 0) +
        (_sisCount[task.id] ?? 0);

    if (totalSAPItems == 0) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<String>(
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.business, size: 24, color: Colors.blue[600]),
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1),
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              child: Text(
                totalSAPItems.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
      tooltip: 'Itens SAP Vinculados',
      onSelected: (value) {
        switch (value) {
          case 'notas':
            _mostrarNotasSAP(task);
            break;
          case 'ordens':
            _mostrarOrdens(task);
            break;
          case 'ats':
            _mostrarATs(task);
            break;
          case 'sis':
            _mostrarSIs(task);
            break;
        }
      },
      itemBuilder: (context) => [
        if ((_notasSAPCount[task.id] ?? 0) > 0)
          PopupMenuItem(
            value: 'notas',
            child: Row(
              children: [
                const Icon(Icons.description, color: Colors.blue, size: 18),
                const SizedBox(width: 8),
                Text('Notas SAP (${_notasSAPCount[task.id]})'),
              ],
            ),
          ),
        if ((_ordensCount[task.id] ?? 0) > 0)
          PopupMenuItem(
            value: 'ordens',
            child: Row(
              children: [
                const Icon(Icons.receipt_long, color: Colors.orange, size: 18),
                const SizedBox(width: 8),
                Text('Ordens (${_ordensCount[task.id]})'),
              ],
            ),
          ),
        if ((_atsCount[task.id] ?? 0) > 0)
          PopupMenuItem(
            value: 'ats',
            child: Row(
              children: [
                const Icon(Icons.assignment, color: Colors.purple, size: 18),
                const SizedBox(width: 8),
                Text('ATs (${_atsCount[task.id]})'),
              ],
            ),
          ),
        if ((_sisCount[task.id] ?? 0) > 0)
          PopupMenuItem(
            value: 'sis',
            child: Row(
              children: [
                const Icon(Icons.info, color: Colors.teal, size: 18),
                const SizedBox(width: 8),
                Text('SIs (${_sisCount[task.id]})'),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _mostrarNotasSAP(Task task) async {
    try {
      final notas = await _notaSAPService.getNotasPorTarefa(task.id);
      if (!mounted) return;
      
      if (notas.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhuma nota SAP vinculada')),
        );
        return;
      }
      
      _mostrarDialogNotasSAP(notas, task);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar notas: $e')),
        );
      }
    }
  }

  Future<void> _mostrarOrdens(Task task) async {
    try {
      final ordens = await _ordemService.getOrdensPorTarefa(task.id);
      if (!mounted) return;
      
      if (ordens.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhuma ordem vinculada')),
        );
        return;
      }
      
      _mostrarDialogOrdens(ordens, task);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar ordens: $e')),
        );
      }
    }
  }

  Future<void> _mostrarATs(Task task) async {
    try {
      final ats = await _atService.getATsPorTarefa(task.id);
      if (!mounted) return;
      
      if (ats.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhuma AT vinculada')),
        );
        return;
      }
      
      _mostrarDialogATs(ats, task);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar ATs: $e')),
        );
      }
    }
  }

  Future<void> _mostrarSIs(Task task) async {
    try {
      final sis = await _siService.getSIsPorTarefa(task.id);
      if (!mounted) return;
      
      if (sis.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhuma SI vinculada')),
        );
        return;
      }
      
      _mostrarDialogSIs(sis, task);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar SIs: $e')),
        );
      }
    }
  }

  void _mostrarDialogNotasSAP(List<NotaSAP> notas, Task task) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[600]!, Colors.blue[400]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.description, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Notas SAP Vinculadas',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Tarefa: ${task.tarefa}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: notas.length,
                  itemBuilder: (context, index) {
                    final nota = notas[index];
                    return _buildNotaSAPCard(nota, index);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copiarParaAreaTransferencia(String texto, String mensagemSucesso) async {
    try {
      await Clipboard.setData(ClipboardData(text: texto));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensagemSucesso), duration: const Duration(seconds: 1)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível copiar: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Widget _buildNotaSAPCard(NotaSAP nota, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.description, color: Colors.blue, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Nota: ${nota.nota}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 18, color: Colors.blue),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _copiarParaAreaTransferencia(nota.nota, 'Nota copiada!'),
              tooltip: 'Copiar nota',
            ),
          ],
        ),
        subtitle: nota.tipo != null ? Text('Tipo: ${nota.tipo}') : null,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRowModern('Tipo', nota.tipo),
                _buildInfoRowModern('Status Sistema', nota.statusSistema),
                _buildInfoRowModern('Status Usuário', nota.statusUsuario),
                _buildInfoRowModern('Descrição', nota.descricao),
                _buildInfoRowModern('Local Instalação', nota.localInstalacao),
                _buildInfoRowModern('Ordem', nota.ordem),
                _buildInfoRowModern('GPM', nota.gpm),
                _buildInfoRowModern('Centro Trabalho', nota.centroTrabalhoResponsavel),
                if (nota.inicioDesejado != null)
                  _buildInfoRowModern('Início Desejado', _formatDate(nota.inicioDesejado!)),
                if (nota.conclusaoDesejada != null)
                  _buildInfoRowModern('Conclusão Desejada', _formatDate(nota.conclusaoDesejada!)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogOrdens(List<Ordem> ordens, Task task) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange[600]!, Colors.orange[400]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.receipt_long, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ordens Vinculadas',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Tarefa: ${task.tarefa}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: ordens.length,
                  itemBuilder: (context, index) {
                    final ordem = ordens[index];
                    return _buildOrdemCard(ordem, index);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrdemCard(Ordem ordem, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.orange.withOpacity(0.2)),
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.receipt_long, color: Colors.orange, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Ordem: ${ordem.ordem}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 18, color: Colors.blue),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _copiarParaAreaTransferencia(ordem.ordem, 'Ordem copiada!'),
              tooltip: 'Copiar ordem',
            ),
          ],
        ),
        subtitle: ordem.tipo != null ? Text('Tipo: ${ordem.tipo}') : null,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRowModern('Tipo', ordem.tipo),
                _buildInfoRowModern('Status Sistema', ordem.statusSistema),
                _buildInfoRowModern('Status Usuário', ordem.statusUsuario),
                _buildInfoRowModern('Texto Breve', ordem.textoBreve),
                _buildInfoRowModern('Denominação Local', ordem.denominacaoLocalInstalacao),
                _buildInfoRowModern('Denominação Objeto', ordem.denominacaoObjeto),
                _buildInfoRowModern('Local Instalação', ordem.localInstalacao),
                _buildInfoRowModern('Código SI', ordem.codigoSI),
                _buildInfoRowModern('GPM', ordem.gpm),
                if (ordem.inicioBase != null)
                  _buildInfoRowModern('Início Base', _formatDate(ordem.inicioBase!)),
                if (ordem.fimBase != null)
                  _buildInfoRowModern('Fim Base', _formatDate(ordem.fimBase!)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogATs(List<AT> ats, Task task) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple[600]!, Colors.purple[400]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.assignment, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ATs Vinculadas',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Tarefa: ${task.tarefa}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: ats.length,
                  itemBuilder: (context, index) {
                    final at = ats[index];
                    return _buildATCard(at, index);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildATCard(AT at, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.purple.withOpacity(0.2)),
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.assignment, color: Colors.purple, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'AT: ${at.autorzTrab}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 18, color: Colors.blue),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _copiarParaAreaTransferencia(at.autorzTrab, 'AT copiada!'),
              tooltip: 'Copiar AT',
            ),
          ],
        ),
        subtitle: at.statusSistema != null ? Text('Status: ${at.statusSistema}') : null,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRowModern('Edificação', at.edificacao),
                _buildInfoRowModern('Status Sistema', at.statusSistema),
                _buildInfoRowModern('Status Usuário', at.statusUsuario),
                _buildInfoRowModern('Texto Breve', at.textoBreve),
                _buildInfoRowModern('Local Instalação', at.localInstalacao),
                _buildInfoRowModern('Centro Trabalho', at.cntrTrab),
                _buildInfoRowModern('Cen', at.cen),
                _buildInfoRowModern('SI', at.si),
                if (at.dataInicio != null)
                  _buildInfoRowModern('Data Início', _formatDate(at.dataInicio!)),
                if (at.dataFim != null)
                  _buildInfoRowModern('Data Fim', _formatDate(at.dataFim!)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogSIs(List<SI> sis, Task task) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.teal[600]!, Colors.teal[400]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.info, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SIs Vinculadas',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Tarefa: ${task.tarefa}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sis.length,
                  itemBuilder: (context, index) {
                    final si = sis[index];
                    return _buildSICard(si, index);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSICard(SI si, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.teal.withOpacity(0.2)),
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.teal.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.info, color: Colors.teal, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'SI: ${si.solicitacao}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 18, color: Colors.blue),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _copiarParaAreaTransferencia(si.solicitacao, 'SI copiada!'),
              tooltip: 'Copiar SI',
            ),
          ],
        ),
        subtitle: si.tipo != null ? Text('Tipo: ${si.tipo}') : null,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRowModern('Tipo', si.tipo),
                _buildInfoRowModern('Status Sistema', si.statusSistema),
                _buildInfoRowModern('Status Usuário', si.statusUsuario),
                _buildInfoRowModern('Texto Breve', si.textoBreve),
                _buildInfoRowModern('Local Instalação', si.localInstalacao),
                _buildInfoRowModern('Criado Por', si.criadoPor),
                _buildInfoRowModern('Centro Trabalho', si.cntrTrab),
                _buildInfoRowModern('Cen', si.cen),
                _buildInfoRowModern('Atrib AT', si.atribAT),
                if (si.dataInicio != null)
                  _buildInfoRowModern('Data Início', _formatDate(si.dataInicio!)),
                if (si.dataFim != null)
                  _buildInfoRowModern('Data Fim', _formatDate(si.dataFim!)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRowModern(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
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

  Map<int, List<Task>> _getTasksForMonth(List<Task> allTasks) {
    final tasksByDay = <int, List<Task>>{};

    for (var task in allTasks) {
      // Verificar todos os períodos (ganttSegments) da tarefa
      if (task.ganttSegments.isNotEmpty) {
        for (var segment in task.ganttSegments) {
          // Verificar se o período está no mês atual
          final segmentStart = segment.dataInicio;
          final segmentEnd = segment.dataFim;
          
          // Se o período cruza com o mês atual
          final monthStart = DateTime(_currentMonth.year, _currentMonth.month, 1);
          final monthEnd = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
          
          // Verificar se há sobreposição entre o período e o mês
          if (segmentEnd.isAfter(monthStart.subtract(const Duration(days: 1))) &&
              segmentStart.isBefore(monthEnd.add(const Duration(days: 1)))) {
            
            // Determinar o intervalo de dias a processar
            final startDate = segmentStart.isBefore(monthStart) ? monthStart : segmentStart;
            final endDate = segmentEnd.isAfter(monthEnd) ? monthEnd : segmentEnd;
            
            // Adicionar a tarefa em todos os dias do período que estão no mês
            var currentDate = startDate;
            while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
              if (currentDate.year == _currentMonth.year &&
                  currentDate.month == _currentMonth.month) {
                final day = currentDate.day;
                // Evitar duplicatas verificando se a tarefa já está no dia
                final dayTasks = tasksByDay.putIfAbsent(day, () => <Task>[]);
                if (!dayTasks.any((t) => t.id == task.id)) {
                  dayTasks.add(task);
                }
              }
              currentDate = currentDate.add(const Duration(days: 1));
            }
          }
        }
      } else {
        // Fallback: se não houver segmentos, usar dataInicio e dataFim da tarefa
        final taskStart = task.dataInicio;
        final taskEnd = task.dataFim;
        
        final monthStart = DateTime(_currentMonth.year, _currentMonth.month, 1);
        final monthEnd = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
        
        if (taskEnd.isAfter(monthStart.subtract(const Duration(days: 1))) &&
            taskStart.isBefore(monthEnd.add(const Duration(days: 1)))) {
          
          final startDate = taskStart.isBefore(monthStart) ? monthStart : taskStart;
          final endDate = taskEnd.isAfter(monthEnd) ? monthEnd : taskEnd;
          
          var currentDate = startDate;
          while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
            if (currentDate.year == _currentMonth.year &&
                currentDate.month == _currentMonth.month) {
              final day = currentDate.day;
              final dayTasks = tasksByDay.putIfAbsent(day, () => <Task>[]);
              if (!dayTasks.any((t) => t.id == task.id)) {
                dayTasks.add(task);
              }
            }
            currentDate = currentDate.add(const Duration(days: 1));
          }
        }
      }
    }

    return tasksByDay;
  }
}

// Widget modal para exibir tarefas do dia com navegação
class _DayTasksModal extends StatefulWidget {
  final int day;
  final List<Task> tasks;
  final Widget Function(Task, {List<String>? imagens, Function(Task)? onEdit, Function(Task)? onDelete, Function(Task)? onDuplicate, Function(Task)? onCreateSubtask, Map<String, PageController>? imagePageControllers, Map<String, int>? currentImageIndex}) buildTaskCard;
  final Color Function(String) getStatusColor;
  final Function(Task)? onEdit;
  final Function(Task)? onDelete;
  final Function(Task)? onDuplicate;
  final Function(Task)? onCreateSubtask;

  const _DayTasksModal({
    required this.day,
    required this.tasks,
    required this.buildTaskCard,
    required this.getStatusColor,
    this.onEdit,
    this.onDelete,
    this.onDuplicate,
    this.onCreateSubtask,
  });

  @override
  State<_DayTasksModal> createState() => _DayTasksModalState();
}

class _DayTasksModalState extends State<_DayTasksModal> {
  late PageController _pageController;
  int _currentIndex = 0;
  final AnexoService _anexoService = AnexoService();
  final Map<String, List<String>> _imagensPorTarefa = {};
  final Map<String, PageController> _imagePageControllers = {};
  final Map<String, int> _currentImageIndex = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _loadAnexos();
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var controller in _imagePageControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAnexos() async {
    try {
      for (var task in widget.tasks) {
        try {
          final anexos = await _anexoService.getAnexosByTaskId(task.id);
          final imagens = anexos
              .where((anexo) => anexo.tipoArquivo == 'imagem')
              .map((img) => _anexoService.getPublicUrl(img))
              .toList();
          
          setState(() {
            _imagensPorTarefa[task.id] = imagens;
            if (imagens.length > 1) {
              _currentImageIndex[task.id] = 0;
              _imagePageControllers[task.id] = PageController();
            }
          });
        } catch (e) {
          print('Erro ao carregar anexos da tarefa ${task.id}: $e');
          setState(() {
            _imagensPorTarefa[task.id] = [];
          });
        }
      }
    } catch (e) {
      print('Erro ao carregar anexos: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header com título e contador
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Atividades do dia ${widget.day}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (widget.tasks.length > 1)
                Text(
                  '${_currentIndex + 1} de ${widget.tasks.length}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Conteúdo: PageView se houver múltiplas tarefas, ou card simples
          if (widget.tasks.length > 1)
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.tasks.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  final task = widget.tasks[index];
                  final imagens = _imagensPorTarefa[task.id] ?? [];
                  return SingleChildScrollView(
                    child: widget.buildTaskCard(
                      task,
                      imagens: imagens,
                      onEdit: widget.onEdit,
                      onDelete: widget.onDelete,
                      onDuplicate: widget.onDuplicate,
                      onCreateSubtask: widget.onCreateSubtask,
                      imagePageControllers: _imagePageControllers,
                      currentImageIndex: _currentImageIndex,
                    ),
                  );
                },
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                child: widget.buildTaskCard(
                  widget.tasks.first,
                  imagens: _imagensPorTarefa[widget.tasks.first.id] ?? [],
                  onEdit: widget.onEdit,
                  onDelete: widget.onDelete,
                  onDuplicate: widget.onDuplicate,
                  onCreateSubtask: widget.onCreateSubtask,
                  imagePageControllers: _imagePageControllers,
                  currentImageIndex: _currentImageIndex,
                ),
              ),
            ),
          // Indicadores e navegação (apenas se houver múltiplas tarefas)
          if (widget.tasks.length > 1) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Botão anterior
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _currentIndex > 0
                      ? () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      : null,
                ),
                // Indicadores de página
                ...List.generate(
                  widget.tasks.length,
                  (index) => Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentIndex == index
                          ? Colors.blue
                          : Colors.grey[300],
                    ),
                  ),
                ),
                // Botão próximo
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _currentIndex < widget.tasks.length - 1
                      ? () {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      : null,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}




