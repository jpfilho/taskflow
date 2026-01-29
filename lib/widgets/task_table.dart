import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../models/task.dart';
import '../models/status.dart';
import '../services/task_service.dart';
import '../services/status_service.dart';
import '../services/chat_service.dart';
import '../services/anexo_service.dart';
import '../services/nota_sap_service.dart';
import '../services/ordem_service.dart';
import '../services/at_service.dart';
import '../services/si_service.dart';
import '../services/frota_service.dart';
import '../models/grupo_chat.dart';
import '../models/nota_sap.dart';
import '../models/ordem.dart';
import '../models/at.dart';
import '../models/si.dart';
import 'chat_screen.dart';
import '../utils/responsive.dart';

class TaskTable extends StatefulWidget {
  final List<Task> tasks;
  final ScrollController scrollController;
  final ScrollController? horizontalController;
  final TaskService? taskService;
  final Function(Task)? onTaskSelected;
  final Function(Task)? onEdit;
  final Function(Task)? onDelete;
  final Function(Task)? onDuplicate;
  final Function(Task)? onCreateSubtask;
  final bool? allSubtasksExpanded; // Estado compartilhado
  final VoidCallback? onToggleAllSubtasks; // Callback compartilhado
  final Set<String>? expandedTasks; // Estado compartilhado de tarefas expandidas
  final Function(String, bool)? onTaskExpanded; // Callback quando uma tarefa é expandida/colapsada
  final String? sortColumn; // Coluna de ordenação atual
  final Function(Task)? getSortValue; // Função para obter valor de ordenação
  
  const TaskTable({
    super.key,
    required this.tasks,
    required this.scrollController,
    this.horizontalController,
    this.taskService,
    this.onTaskSelected,
    this.onEdit,
    this.onDelete,
    this.onDuplicate,
    this.onCreateSubtask,
    this.allSubtasksExpanded,
    this.onToggleAllSubtasks,
    this.expandedTasks,
    this.onTaskExpanded,
    this.sortColumn,
    this.getSortValue,
  });

  @override
  State<TaskTable> createState() => _TaskTableState();
}

class _TaskTableState extends State<TaskTable> {
  Timer? _emptyTimer;
  bool _showEmptyMessage = false;

  Set<String> get _expandedTasks {
    if (widget.expandedTasks != null) {
      return widget.expandedTasks!;
    }
    return _localExpandedTasks;
  }
  final Set<String> _localExpandedTasks = {}; // IDs das tarefas expandidas (fallback local)
  final Map<String, List<Task>> _loadedSubtasks = {}; // Cache de subtarefas carregadas
  final StatusService _statusService = StatusService();
  final ChatService _chatService = ChatService();
  final AnexoService _anexoService = AnexoService();
  final NotaSAPService _notaSAPService = NotaSAPService();
  final OrdemService _ordemService = OrdemService();
  final ATService _atService = ATService();
  final SIService _siService = SIService();
  final FrotaService _frotaService = FrotaService();
  Map<String, Status> _statusMap = {}; // Mapa de código de status -> Status
  Map<String, int> _mensagensCount = {}; // Mapa de taskId -> quantidade de mensagens
  Map<String, int> _anexosCount = {}; // Mapa de taskId -> quantidade de anexos
  Map<String, int> _notasSAPCount = {}; // Mapa de taskId -> quantidade de notas SAP
  Map<String, int> _ordensCount = {}; // Mapa de taskId -> quantidade de ordens
  Map<String, int> _atsCount = {}; // Mapa de taskId -> quantidade de ATs
  Map<String, int> _sisCount = {}; // Mapa de taskId -> quantidade de SIs
  Map<String, int> _frotasCount = {}; // Mapa de taskId -> quantidade de frotas
  Map<String, String> _frotasNomes = {}; // Mapa de taskId -> nome da frota
  bool get _allSubtasksExpanded => widget.allSubtasksExpanded ?? false; // Estado compartilhado ou local

  StreamSubscription<String>? _statusChangeSubscription;
  
  // ScrollController para sincronizar scroll horizontal do cabeçalho com o corpo
  late ScrollController _horizontalScrollController;
  bool _ownsHorizontalController = true;
  bool _isScrollingHeader = false;
  bool _isScrollingBody = false;
  double _lastHorizontalOffset = 0.0; // Último offset horizontal conhecido

  @override
  void initState() {
    super.initState();
    _startEmptyTimer();
    _horizontalScrollController = widget.horizontalController ?? ScrollController();
    _ownsHorizontalController = widget.horizontalController == null;
    _loadStatus();
    _loadCounts();
    _loadAllSubtasks();
    // Escutar mudanças nos status
    _statusChangeSubscription = _statusService.statusChangeStream.listen((_) {
      _loadStatus(); // Recarregar quando houver mudança
    });
  }

  @override
  void dispose() {
    _emptyTimer?.cancel();
    _statusChangeSubscription?.cancel();
    if (_ownsHorizontalController) {
      _horizontalScrollController.dispose();
    }
    super.dispose();
  }

  // Carregar todas as subtarefas automaticamente
  Future<void> _loadAllSubtasks() async {
    if (widget.taskService == null) return;
    
    try {
      // Identificar tarefas principais que podem ter subtarefas
      final mainTasks = widget.tasks.where((t) => t.parentId == null).toList();
      
      // Carregar subtarefas para cada tarefa principal
      for (var mainTask in mainTasks) {
        if (!_loadedSubtasks.containsKey(mainTask.id)) {
          try {
            final subtasks = await widget.taskService!.getSubtasks(mainTask.id);
            if (subtasks.isNotEmpty && mounted) {
              setState(() {
                _loadedSubtasks[mainTask.id] = subtasks;
                // Por padrão, subtarefas começam colapsadas
                // Só expandir se _allSubtasksExpanded for true
                if (widget.allSubtasksExpanded ?? false) {
                  _expandedTasks.add(mainTask.id);
                }
              });
            }
          } catch (e) {
            print('Erro ao carregar subtarefas de ${mainTask.id}: $e');
          }
        }
      }
    } catch (e) {
      print('Erro ao carregar subtarefas: $e');
    }
  }

  @override
  void didUpdateWidget(TaskTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Sincronizar estado de expansão quando allSubtasksExpanded mudar
    if (oldWidget.allSubtasksExpanded != widget.allSubtasksExpanded) {
      // Obter todas as tarefas principais que têm subtarefas OU períodos por executor
      final mainTasks = widget.tasks.where((t) => t.parentId == null).toList();
      final tasksToToggle = <String>[];
      
      for (var task in mainTasks) {
        final hasSubtasks = _loadedSubtasks.containsKey(task.id) && _loadedSubtasks[task.id]!.isNotEmpty;
        final hasExecutorPeriods = task.executorPeriods.isNotEmpty;
        
        if (hasSubtasks || hasExecutorPeriods) {
          tasksToToggle.add(task.id);
        }
      }
      
      if (mounted) {
        setState(() {
          if (widget.allSubtasksExpanded ?? false) {
            // Expandir todas
            _expandedTasks.addAll(tasksToToggle);
          } else {
            // Colapsar todas
            _expandedTasks.removeAll(tasksToToggle);
          }
        });
      }
    }
    
    // Sincronizar estado de expansão quando expandedTasks mudar externamente
    if (oldWidget.expandedTasks != widget.expandedTasks && widget.expandedTasks != null) {
      if (mounted) {
        setState(() {
          // O estado já está sincronizado através do getter _expandedTasks
        });
      }
    }
    
    // Recarregar contagens e subtarefas se as tarefas mudaram
    // Usar WidgetsBinding para evitar setState durante build
    final tasksChanged = oldWidget.tasks.length != widget.tasks.length ||
        oldWidget.tasks.map((t) => t.id).join(',') != widget.tasks.map((t) => t.id).join(',');
    
    if (tasksChanged && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          if (widget.tasks.isEmpty) {
            _startEmptyTimer();
          } else {
            _emptyTimer?.cancel();
            _showEmptyMessage = false;
          }
          _loadCounts();
          // Limpar cache de subtarefas para forçar recarregamento
          _loadedSubtasks.clear();
          _loadAllSubtasks();
          
          // Se todas as subtarefas devem estar colapsadas por padrão, garantir isso
          if (!(widget.allSubtasksExpanded ?? false) && mounted) {
            setState(() {
              // Remover todas as tarefas expandidas que têm subtarefas
              final mainTasksWithSubtasks = widget.tasks
                  .where((t) => t.parentId == null && _loadedSubtasks.containsKey(t.id) && _loadedSubtasks[t.id]!.isNotEmpty)
                  .map((t) => t.id)
                  .toList();
              _expandedTasks.removeWhere((id) => mainTasksWithSubtasks.contains(id));
            });
          }
        }
      });
    }
  }

  void _startEmptyTimer() {
    _emptyTimer?.cancel();
    _showEmptyMessage = false;
    _emptyTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && widget.tasks.isEmpty) {
        setState(() {
          _showEmptyMessage = true;
        });
      }
    });
  }

  Future<void> _loadCounts() async {
    if (widget.tasks.isEmpty || !mounted) return;

    try {
      final taskIds = widget.tasks.map((t) => t.id).toList();
      
      // Carregar contagens em paralelo
      final mensagensFuture = _chatService.contarMensagensPorTarefas(taskIds);
      final anexosFuture = _anexoService.contarAnexosPorTarefas(taskIds);
      final notasSAPFuture = _notaSAPService.contarNotasPorTarefas(taskIds);
      final ordensFuture = _ordemService.contarOrdensPorTarefas(taskIds);
      final atsFuture = _atService.contarATsPorTarefas(taskIds);
      final sisFuture = _siService.contarSIsPorTarefas(taskIds);
      final frotasFuture = _frotaService.contarFrotasPorTarefas(taskIds);
      
      final results = await Future.wait([
        mensagensFuture,
        anexosFuture,
        notasSAPFuture,
        ordensFuture,
        atsFuture,
        sisFuture,
        frotasFuture,
      ]);
      
      // Carregar nomes das frotas
      final frotasNomesMap = <String, String>{};
      for (var taskId in taskIds) {
        if (results[6][taskId] != null && results[6][taskId]! > 0) {
          final frotaNome = await _frotaService.getFrotaNomePorTarefa(taskId);
          if (frotaNome != null) {
            frotasNomesMap[taskId] = frotaNome;
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _mensagensCount = results[0];
          _anexosCount = results[1];
          _notasSAPCount = results[2];
          _ordensCount = results[3];
          _atsCount = results[4];
          _sisCount = results[5];
          _frotasCount = results[6];
          _frotasNomes = frotasNomesMap;
        });
      }
    } catch (e) {
      print('Erro ao carregar contagens: $e');
    }
  }

  Future<void> _loadStatus() async {
    if (!mounted) return;
    try {
      final statusList = await _statusService.getAllStatus();
      if (mounted) {
        setState(() {
          _statusMap = {
            for (var status in statusList) status.codigo: status
          };
        });
      }
    } catch (e) {
      print('Erro ao carregar status: $e');
    }
  }

  Color _getStatusBackgroundColor(String status) {
    // ANDA (Andamento) e PROG (Programado) devem ter fundo branco
    if (status == 'ANDA' || status == 'PROG') {
      return Colors.white;
    }
    
    // Buscar status cadastrado
    final statusObj = _statusMap[status];
    if (statusObj != null) {
      // Verificar se o código do status é ANDA ou PROG
      if (statusObj.codigo == 'ANDA' || statusObj.codigo == 'PROG') {
        return Colors.white;
      }
      // Usar a cor do status com opacidade bem reduzida para fundo
      return statusObj.color.withOpacity(0.5); // Bem clarinha
    }
    
    // Fallback para cores padrão se não encontrar
    switch (status) {
      case 'ANDA':
        return Colors.white;
      case 'CONC':
        return Colors.green[50]!;
      case 'PROG':
        return Colors.white;
      default:
        return Colors.grey[50]!;
    }
  }

  Color _getStatusBadgeColor(String status) {
    // Buscar status cadastrado
    final statusObj = _statusMap[status];
    if (statusObj != null) {
      // Usar a cor do status para o badge
      return statusObj.color;
    }
    
    // Fallback para cores padrão se não encontrar
    switch (status) {
      case 'ANDA':
        return Colors.orange[400]!;
      case 'CONC':
        return Colors.green[500]!;
      case 'PROG':
        return Colors.blue[500]!;
      default:
        return Colors.grey[500]!;
    }
  }

  // Organizar tarefas em hierarquia
  List<Task> _buildHierarchicalTasks() {
    final List<Task> hierarchicalTasks = [];
    final mainTasks = widget.tasks.where((t) => t.parentId == null).toList();
    
    for (final mainTask in mainTasks) {
      hierarchicalTasks.add(mainTask);
      final isExpanded = _expandedTasks.contains(mainTask.id);
      
      // Subtarefas vindas diretamente da lista de tasks (carregadas no pai)
      final subtasksFromWidget = widget.tasks
          .where((t) => t.parentId == mainTask.id)
          .toList();

      // Se a tarefa está expandida e tem subtarefas (do pai ou carregadas aqui), adicionar
      if (isExpanded) {
        if (subtasksFromWidget.isNotEmpty) {
          hierarchicalTasks.addAll(subtasksFromWidget);
        } else if (_loadedSubtasks.containsKey(mainTask.id)) {
          hierarchicalTasks.addAll(_loadedSubtasks[mainTask.id]!);
        }
      }
      
      // Se a tarefa está expandida, criar linhas virtuais para períodos por executor e por frota
      if (isExpanded) {
        if (mainTask.executorPeriods.isNotEmpty) {
          for (var executorPeriod in mainTask.executorPeriods) {
            final virtualTaskId = '${mainTask.id}_executor_${executorPeriod.executorId}';
            
            DateTime? minDate;
            DateTime? maxDate;
            for (var period in executorPeriod.periods) {
              if (minDate == null || period.dataInicio.isBefore(minDate)) {
                minDate = period.dataInicio;
              }
              if (maxDate == null || period.dataFim.isAfter(maxDate)) {
                maxDate = period.dataFim;
              }
            }
            
            final virtualTask = Task(
              id: virtualTaskId,
              parentId: mainTask.id,
              statusId: mainTask.statusId,
              regionalId: mainTask.regionalId,
              divisaoId: mainTask.divisaoId,
              segmentoId: mainTask.segmentoId,
              localIds: mainTask.localIds,
              executorIds: [executorPeriod.executorId],
              equipeIds: mainTask.equipeIds,
              frotaIds: mainTask.frotaIds,
              localId: mainTask.localId,
              equipeId: mainTask.equipeId,
              status: mainTask.status,
              statusNome: mainTask.statusNome,
              regional: mainTask.regional,
              divisao: mainTask.divisao,
              locais: mainTask.locais,
              tipo: mainTask.tipo,
              ordem: mainTask.ordem,
              tarefa: '${executorPeriod.executorNome} - ${mainTask.tarefa}',
              executores: [executorPeriod.executorNome],
              equipes: mainTask.equipes,
              executor: executorPeriod.executorNome,
              frota: mainTask.frota,
              coordenador: mainTask.coordenador,
              si: mainTask.si,
              dataInicio: minDate ?? mainTask.dataInicio,
              dataFim: maxDate ?? mainTask.dataFim,
              ganttSegments: executorPeriod.periods,
              executorPeriods: const [],
              frotaPeriods: const [],
              observacoes: mainTask.observacoes,
              horasPrevistas: mainTask.horasPrevistas,
              horasExecutadas: mainTask.horasExecutadas,
              prioridade: mainTask.prioridade,
            );
            
            hierarchicalTasks.add(virtualTask);
          }
        }

        if (mainTask.frotaPeriods.isNotEmpty) {
          for (var frotaPeriod in mainTask.frotaPeriods) {
            final virtualTaskId = '${mainTask.id}_frota_${frotaPeriod.frotaId}';

            DateTime? minDate;
            DateTime? maxDate;
            for (var period in frotaPeriod.periods) {
              if (minDate == null || period.dataInicio.isBefore(minDate)) {
                minDate = period.dataInicio;
              }
              if (maxDate == null || period.dataFim.isAfter(maxDate)) {
                maxDate = period.dataFim;
              }
            }

            final virtualTask = Task(
              id: virtualTaskId,
              parentId: mainTask.id,
              statusId: mainTask.statusId,
              regionalId: mainTask.regionalId,
              divisaoId: mainTask.divisaoId,
              segmentoId: mainTask.segmentoId,
              localIds: mainTask.localIds,
              executorIds: mainTask.executorIds,
              equipeIds: mainTask.equipeIds,
              frotaIds: [frotaPeriod.frotaId],
              localId: mainTask.localId,
              equipeId: mainTask.equipeId,
              status: mainTask.status,
              statusNome: mainTask.statusNome,
              regional: mainTask.regional,
              divisao: mainTask.divisao,
              locais: mainTask.locais,
              tipo: mainTask.tipo,
              ordem: mainTask.ordem,
              tarefa: '${frotaPeriod.frotaNome} - ${mainTask.tarefa}',
              executores: mainTask.executores,
              equipes: mainTask.equipes,
              executor: mainTask.executor,
              frota: frotaPeriod.frotaNome,
              coordenador: mainTask.coordenador,
              si: mainTask.si,
              dataInicio: minDate ?? mainTask.dataInicio,
              dataFim: maxDate ?? mainTask.dataFim,
              ganttSegments: frotaPeriod.periods,
              executorPeriods: const [],
              frotaPeriods: const [],
              observacoes: mainTask.observacoes,
              horasPrevistas: mainTask.horasPrevistas,
              horasExecutadas: mainTask.horasExecutadas,
              prioridade: mainTask.prioridade,
            );

            hierarchicalTasks.add(virtualTask);
          }
        }
      }
    }
    
    return hierarchicalTasks;
  }

  void _toggleAllSubtasks() {
    // Se há callback compartilhado, usar ele; senão, usar lógica local
    if (widget.onToggleAllSubtasks != null) {
      widget.onToggleAllSubtasks!();
    } else {
      setState(() {
        final newState = !_allSubtasksExpanded;
        
        // Obter todas as tarefas principais que têm subtarefas
        final mainTasksWithSubtasks = widget.tasks
            .where((t) => t.parentId == null && _loadedSubtasks.containsKey(t.id) && _loadedSubtasks[t.id]!.isNotEmpty)
            .map((t) => t.id)
            .toList();
        
        if (newState) {
          // Expandir todas
          _expandedTasks.addAll(mainTasksWithSubtasks);
        } else {
          // Colapsar todas
          _expandedTasks.removeWhere((id) => mainTasksWithSubtasks.contains(id));
        }
      });
    }
  }

  Future<void> _toggleExpand(String taskId) async {
    final isCurrentlyExpanded = _expandedTasks.contains(taskId);
    final newExpandedState = !isCurrentlyExpanded;
    
    print('   Estado atual: ${_expandedTasks.toList()}');
    print('   onTaskExpanded disponível: ${widget.onTaskExpanded != null}');
    
    // Notificar o callback compartilhado se existir
    if (widget.onTaskExpanded != null) {
      print('   Chamando onTaskExpanded...');
      widget.onTaskExpanded!(taskId, newExpandedState);
    } else {
      // Fallback para estado local
      print('   Usando estado local...');
      setState(() {
        if (newExpandedState) {
          _localExpandedTasks.add(taskId);
        } else {
          _localExpandedTasks.remove(taskId);
        }
      });
    }
    
    // Carregar subtarefas se ainda não foram carregadas
    if (newExpandedState && widget.taskService != null && !_loadedSubtasks.containsKey(taskId)) {
      try {
        final subtasks = await widget.taskService!.getSubtasks(taskId);
        if (mounted) {
          setState(() {
            _loadedSubtasks[taskId] = subtasks;
          });
        }
      } catch (e) {
        print('Erro ao carregar subtarefas: $e');
      }
    } else if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);
    final isDesktop = Responsive.isDesktop(context);
    final screenWidth = MediaQuery.of(context).size.width;
    // Apenas desktops grandes (>= 1280px) mostram a legenda
    final isLargeDesktop = isDesktop && screenWidth >= 1280;
    
    final hierarchicalTasks = _buildHierarchicalTasks();
    
    if (hierarchicalTasks.isEmpty) {
      if (!_showEmptyMessage) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(height: 8),
                Text('Carregando tarefas...'),
              ],
            ),
          ),
        );
      } else {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text('Nenhuma tarefa encontrada'),
          ),
        );
      }
    }
    
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          // Legenda de status (apenas em desktops grandes >= 1280px)
          // Se não for desktop grande, manter espaço reservado para manter altura consistente
          if (isLargeDesktop) 
            _buildStatusLegend(isMobile)
          else
            SizedBox(
              height: _getStatusLegendHeight(),
            ),
          // Botão de expandir/colapsar (apenas em mobile/tablet, quando legenda não é exibida)
          if (isMobile || isTablet) _buildToggleButton(isMobile),
          // Cabeçalho fixo com scroll horizontal - altura fixa de 25px para alinhar com Gantt
          Container(
            height: 25,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue[700]!,
                  Colors.blue[600]!,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 2,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                // Sincronizar scroll do cabeçalho com o corpo
                if (_isScrollingBody || !_horizontalScrollController.hasClients) {
                  return false;
                }
                
                final newOffset = notification.metrics.pixels;
                // Verificar se o offset realmente mudou (evitar loops)
                if ((newOffset - _lastHorizontalOffset).abs() < 0.1) {
                  return false;
                }
                
                // Verificar novamente se o controller ainda está anexado antes de acessar offset
                if (!_horizontalScrollController.hasClients) {
                  return false;
                }
                
                // Verificar se o controller já está na posição desejada (evitar jumpTo desnecessário)
                try {
                  if ((_horizontalScrollController.offset - newOffset).abs() < 0.1) {
                    _lastHorizontalOffset = newOffset;
                    return false;
                  }
                } catch (e) {
                  // Controller pode ter sido desanexado, ignorar
                  return false;
                }
                
                _isScrollingHeader = true;
                _lastHorizontalOffset = newOffset;
                _horizontalScrollController.jumpTo(newOffset);
                // Resetar flag de forma assíncrona para evitar loops
                Future.microtask(() {
                  _isScrollingHeader = false;
                });
                return false;
              },
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const AlwaysScrollableScrollPhysics(),
                controller: _horizontalScrollController,
                child: SizedBox(
                  width: _calculateTotalTableWidth(isMobile),
                  child: _buildHeaderRow(isMobile),
                ),
              ),
            ),
          ),
          // Corpo scrollável (vertical e horizontal)
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableHeight = constraints.maxHeight;
                if (availableHeight.isInfinite || availableHeight <= 0) {
                  return const Center(child: CircularProgressIndicator());
                }
                // Usar a mesma largura do cabeçalho (já inclui folga de segurança)
                final minWidth = _calculateTotalTableWidth(isMobile);
                
                return NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    // Sincronizar scroll do corpo com o cabeçalho
                    if (_isScrollingHeader || !_horizontalScrollController.hasClients) {
                      return false;
                    }
                    
                    final newOffset = notification.metrics.pixels;
                    // Verificar se o offset realmente mudou (evitar loops)
                    if ((newOffset - _lastHorizontalOffset).abs() < 0.1) {
                      return false;
                    }
                    
                    // Verificar novamente se o controller ainda está anexado antes de acessar offset
                    if (!_horizontalScrollController.hasClients) {
                      return false;
                    }
                    
                    // Verificar se o controller já está na posição desejada (evitar jumpTo desnecessário)
                    try {
                      if ((_horizontalScrollController.offset - newOffset).abs() < 0.1) {
                        _lastHorizontalOffset = newOffset;
                        return false;
                      }
                    } catch (e) {
                      // Controller pode ter sido desanexado, ignorar
                      return false;
                    }
                    
                    _isScrollingBody = true;
                    _lastHorizontalOffset = newOffset;
                    _horizontalScrollController.jumpTo(newOffset);
                    // Resetar flag de forma assíncrona para evitar loops
                    Future.microtask(() {
                      _isScrollingBody = false;
                    });
                    return false;
                  },
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const AlwaysScrollableScrollPhysics(),
                    controller: _horizontalScrollController,
                    child: SizedBox(
                      width: minWidth,
                      child: ListView.builder(
                        controller: widget.scrollController,
                        shrinkWrap: false,
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: hierarchicalTasks.length,
                        itemBuilder: (context, index) {
                          final task = hierarchicalTasks[index];
                          final previousTask = index > 0 ? hierarchicalTasks[index - 1] : null;
                          
                          final isSubtask = task.parentId != null;
                          final hasSubtasks = _loadedSubtasks.containsKey(task.id) 
                              ? _loadedSubtasks[task.id]!.isNotEmpty
                              : false;
                          final isExecutorRow = task.id.contains('_executor_');
                          final isFrotaRow = task.id.contains('_frota_');
                          
                          // Verificar se mudou o grupo (apenas se não for PERÍODO e se não for subtarefa/executor)
                          bool mudouGrupo = false;
                          
                          // Debug inicial
                          if (index == 0) {
                          }
                          
                          if (widget.sortColumn != null && 
                              widget.sortColumn != 'PERÍODO' && 
                              previousTask != null &&
                              !previousTask.id.contains('_executor_') &&
                              !previousTask.id.contains('_frota_') &&
                              previousTask.parentId == null &&
                              !isSubtask &&
                              !isExecutorRow &&
                              !isFrotaRow &&
                              widget.getSortValue != null) {
                            try {
                              final previousValue = widget.getSortValue!(previousTask);
                              final currentValue = widget.getSortValue!(task);
                              mudouGrupo = previousValue.trim() != currentValue.trim();
                              
                              // Removido debug
                            } catch (e, stackTrace) {
                              // Se houver erro, não mostrar linha separadora
                              print('❌ Erro ao verificar mudança de grupo: $e');
                              print('Stack trace: $stackTrace');
                              mudouGrupo = false;
                            }
                          }
                          
                          final hasExecutorPeriods = !isSubtask && !isExecutorRow && task.executorPeriods.isNotEmpty;
                          final statusBackgroundColor = _getStatusBackgroundColor(task.status);
                          
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Linha separadora se mudou grupo (no topo)
                              if (mudouGrupo)
                                Container(
                                  height: 1,
                                  width: double.infinity,
                                  color: const Color.fromARGB(255, 0, 0, 0),
                                ),
                              // Linha da tabela
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => widget.onTaskSelected?.call(task),
                                  hoverColor: Colors.blue[100]!.withOpacity(0.3),
                                  child: Container(
                                    height: 50, // Altura fixa de 50px para alinhar com Gantt
                                    decoration: BoxDecoration(
                                      color: statusBackgroundColor, // Fundo com cor do status bem clarinha
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Colors.grey[200]!,
                                          width: 0.5,
                                        ),
                                        left: isExecutorRow
                                            ? BorderSide(
                                                color: Colors.orange[400]!,
                                                width: 3,
                                              )
                                            : isFrotaRow
                                                ? BorderSide(
                                                    color: Colors.green[400]!,
                                                    width: 3,
                                                  )
                                                : isSubtask
                                                    ? BorderSide(
                                                        color: Colors.blue[300]!,
                                                        width: 3,
                                                      )
                                                    : BorderSide.none,
                                      ),
                                    ),
                                    child: _buildDataRow(
                                      task,
                                      isMobile,
                                      index,
                                      isSubtask,
                                      hasSubtasks,
                                      isExecutorRow,
                                      isFrotaRow,
                                      hasExecutorPeriods,
                                      statusBackgroundColor,
                                      minWidth,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  double _calculateTotalTableWidth(bool isMobile) {
    final acoesWidth = isMobile ? 50.0 : 60.0;
    final statusWidth = isMobile ? 60.0 : 70.0;
    final localWidth = isMobile ? 80.0 : 90.0;
    final tipoWidth = isMobile ? 90.0 : 100.0;
    final tarefaWidth = isMobile ? 150.0 : 184.0;
    final executorWidth = isMobile ? 120.0 : 150.0;
    final coordenadorWidth = isMobile ? 100.0 : 130.0;
    final frotaWidth = isMobile ? 45.0 : 50.0;
    final chatWidth = isMobile ? 45.0 : 50.0;
    final anexosWidth = isMobile ? 45.0 : 50.0;
    final notasSAPWidth = isMobile ? 45.0 : 50.0;
    final ordensWidth = isMobile ? 45.0 : 50.0;
    final atsWidth = isMobile ? 45.0 : 50.0;
    final sisWidth = isMobile ? 45.0 : 50.0;
    // Botão foi movido para a legenda, não precisa mais incluir aqui
    // Adiciona uma margem de segurança maior para evitar overflow por arredondamentos/paddings
    const double safetyPadding = 32.0;
    return acoesWidth +
        statusWidth +
        localWidth +
        tipoWidth +
        tarefaWidth +
        executorWidth +
        coordenadorWidth +
        frotaWidth +
        chatWidth +
        anexosWidth +
        notasSAPWidth +
        ordensWidth +
        atsWidth +
        sisWidth +
        safetyPadding;
  }

  Widget _buildHeaderRow(bool isMobile) {
    // Definir larguras fixas para todas as colunas
    final acoesWidth = isMobile ? 50.0 : 60.0;
    final statusWidth = isMobile ? 60.0 : 70.0;
    final localWidth = isMobile ? 80.0 : 90.0;
    final tipoWidth = isMobile ? 90.0 : 100.0;
    final tarefaWidth = isMobile ? 150.0 : 184.0;
    final executorWidth = isMobile ? 120.0 : 150.0;
    final coordenadorWidth = isMobile ? 100.0 : 130.0;
    final frotaWidth = isMobile ? 45.0 : 50.0;
    final chatWidth = isMobile ? 45.0 : 50.0;
    final anexosWidth = isMobile ? 45.0 : 50.0;
    final notasSAPWidth = isMobile ? 45.0 : 50.0;
    final ordensWidth = isMobile ? 45.0 : 50.0;
    final atsWidth = isMobile ? 45.0 : 50.0;
    final sisWidth = isMobile ? 45.0 : 50.0;
    
    return Row(
      children: [
        _buildHeaderCell('AÇÕES', acoesWidth, isMobile),
        _buildHeaderCell('STATUS', statusWidth, isMobile),
        _buildHeaderCell('LOCAL', localWidth, isMobile),
        _buildHeaderCell('TIPO', tipoWidth, isMobile),
        _buildHeaderCell('TAREFA', tarefaWidth, isMobile),
        _buildHeaderCell('EXECUTOR', executorWidth, isMobile),
        _buildHeaderCell('COORDENADOR', coordenadorWidth, isMobile),
        _buildHeaderCell('FROTA', frotaWidth, isMobile),
        _buildHeaderCell('CHAT', chatWidth, isMobile),
        _buildHeaderCell('ANEXOS', anexosWidth, isMobile),
        _buildHeaderCell('NOTA', notasSAPWidth, isMobile),
        _buildHeaderCell('ORDEM', ordensWidth, isMobile),
        _buildHeaderCell('AT', atsWidth, isMobile),
        _buildHeaderCell('SI', sisWidth, isMobile),
      ],
    );
  }

  Widget _buildDataRow(
    Task task,
    bool isMobile,
    int index,
    bool isSubtask,
    bool hasSubtasks,
    bool isExecutorRow,
    bool isFrotaRow,
    bool hasExecutorPeriods,
    Color statusBackgroundColor,
    double rowMinWidth,
  ) {
    // Criar tooltip com informações adicionais
    final tooltipText = _buildTooltipText(task);
    
    // Usar as mesmas larguras fixas do cabeçalho
    final acoesWidth = isMobile ? 50.0 : 60.0;
    final statusWidth = isMobile ? 60.0 : 70.0;
    final localWidth = isMobile ? 80.0 : 90.0;
    final tipoWidth = isMobile ? 90.0 : 100.0;
    final tarefaWidth = isMobile ? 150.0 : 184.0;
    final executorWidth = isMobile ? 120.0 : 150.0;
    final coordenadorWidth = isMobile ? 100.0 : 130.0;
    final frotaWidth = isMobile ? 45.0 : 50.0;
    final chatWidth = isMobile ? 45.0 : 50.0;
    final anexosWidth = isMobile ? 45.0 : 50.0;
    final notasSAPWidth = isMobile ? 45.0 : 50.0;
    final ordensWidth = isMobile ? 45.0 : 50.0;
    final atsWidth = isMobile ? 45.0 : 50.0;
    final sisWidth = isMobile ? 45.0 : 50.0;
    // Botão foi movido para a legenda, não precisa mais incluir aqui

    return Tooltip(
      message: tooltipText,
      preferBelow: false,
      child: ClipRect(
        child: SizedBox(
          width: rowMinWidth,
          child: Row(
            children: [
          // Coluna de AÇÕES (primeira coluna)
          _buildActionsCell(task, acoesWidth, isMobile),
          // Coluna de STATUS com ícone de expansão
          _buildStatusCell(task.status, statusWidth, isMobile, task, hasSubtasks, isSubtask || isFrotaRow, isExecutorRow, hasExecutorPeriods),
          _buildCell(
            task.locais.isNotEmpty ? task.locais.join(', ') : '',
            localWidth,
            isMobile,
            hasColoredBackground: statusBackgroundColor != Colors.white,
            fontWeight: (task.status == 'PROG' || task.status == 'ANDA') ? FontWeight.w600 : null,
          ),
          _buildCell(task.tipo, tipoWidth, isMobile, hasColoredBackground: statusBackgroundColor != Colors.white),
          // Coluna TAREFA com largura fixa
          SizedBox(
            width: tarefaWidth,
            child: Container(
              padding: EdgeInsets.only(left: (isSubtask || isExecutorRow || isFrotaRow) ? (isMobile ? 20 : 24) : 0),
              child: _buildCell(
                task.tarefa,
                0,
                isMobile,
                isSubtask: isSubtask || isFrotaRow,
                hasColoredBackground: statusBackgroundColor != Colors.white,
                maxLines: 2,
                softWrap: true,
                overflow: TextOverflow.fade,
                fontWeight: (task.status == 'PROG' || task.status == 'ANDA') ? FontWeight.w600 : null,
              ),
            ),
          ),
          // Coluna EXECUTOR com largura fixa
          SizedBox(
            width: executorWidth,
            child: Tooltip(
              message: task.equipeExecutores != null && task.equipeExecutores!.isNotEmpty
                  ? 'Equipe: ${task.equipes.isNotEmpty ? task.equipes.join(', ') : ''}\n\nExecutores:\n${task.equipeExecutores!.map((e) => '• ${e.executorNome} (${_getPapelLabel(e.papel)})').join('\n')}'
                  : task.executores.isNotEmpty ? task.executores.join(', ') : task.executor,
              child: _buildCell(
                task.equipeExecutores != null && task.equipeExecutores!.isNotEmpty
                    ? '${task.equipes.isNotEmpty ? task.equipes.join(', ') : ''} (${task.equipeExecutores!.length})'
                    : task.executores.isNotEmpty ? task.executores.join(', ') : task.executor,
                0,
                isMobile,
                hasColoredBackground: statusBackgroundColor != Colors.white,
                maxLines: 2,
                softWrap: true,
                overflow: TextOverflow.fade,
              ),
            ),
          ),
          // Coluna COORDENADOR com largura fixa
          SizedBox(
            width: coordenadorWidth,
            child: _buildCell(task.coordenador, 0, isMobile, hasColoredBackground: statusBackgroundColor != Colors.white),
          ),
          // Coluna de FROTA (clicável)
          _buildFrotaCell(task, frotaWidth, isMobile, statusBackgroundColor),
          // Coluna de CHAT (clicável)
          _buildChatCell(task, chatWidth, isMobile, statusBackgroundColor),
          // Coluna de ANEXOS
          _buildCell(
            _anexosCount[task.id] != null && _anexosCount[task.id]! > 0
                ? '${_anexosCount[task.id]}'
                : '',
            anexosWidth,
            isMobile,
            icon: Icons.attach_file,
            iconColor: _anexosCount[task.id] != null && _anexosCount[task.id]! > 0
                ? Colors.green
                : Colors.grey[400],
            hasColoredBackground: statusBackgroundColor != Colors.white,
          ),
          // Coluna de NOTAS SAP (clicável)
          _buildNotaSAPCell(task, notasSAPWidth, isMobile, statusBackgroundColor),
          // Coluna de ORDENS (clicável)
          _buildOrdemCell(task, ordensWidth, isMobile, statusBackgroundColor),
          // Coluna de ATs (clicável)
          _buildATCell(task, atsWidth, isMobile, statusBackgroundColor),
          // Coluna de SIs (clicável)
          _buildSICell(task, sisWidth, isMobile, statusBackgroundColor),
            ],
          ),
        ),
      ),
    );
  }

  String _buildTooltipText(Task task) {
    final List<String> parts = [];
    
    if (task.regional.isNotEmpty) {
      parts.add('Regional: ${task.regional}');
    }
    if (task.divisao.isNotEmpty) {
      parts.add('Divisão: ${task.divisao}');
    }
    if (task.ordem != null && task.ordem!.isNotEmpty) {
      parts.add('Ordem: ${task.ordem!}');
    }
    // Adicionar informações da equipe se houver
    if (task.equipeExecutores != null && task.equipeExecutores!.isNotEmpty) {
      parts.add('\nEquipe: ${task.equipes.isNotEmpty ? task.equipes.join(', ') : ''}');
      parts.add('Executores:');
      for (var executor in task.equipeExecutores!) {
        parts.add('  • ${executor.executorNome} (${_getPapelLabel(executor.papel)})');
      }
    } else if (task.executores.isNotEmpty) {
      parts.add('Executores: ${task.executores.join(', ')}');
    } else if (task.executor.isNotEmpty) {
      parts.add('Executor: ${task.executor}');
    }
    if (task.frota.isNotEmpty) {
      parts.add('Frota: ${task.frota}');
    }
    if (task.si.isNotEmpty) {
      parts.add('SI: ${task.si}');
    }
    
    return parts.isEmpty ? 'Sem informações adicionais' : parts.join('\n');
  }

  String _getPapelLabel(String papel) {
    switch (papel) {
      case 'FISCAL':
        return 'Fiscal';
      case 'TST':
        return 'TST';
      case 'ENCARREGADO':
        return 'Encarregado';
      case 'EXECUTOR':
        return 'Executor';
      default:
        return papel;
    }
  }
  
  Widget _buildActionsCell(Task task, double width, bool isMobile) {
    return SizedBox(
      width: width,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 3 : 6, vertical: isMobile ? 4 : 8),
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              color: Colors.grey[300]!,
              width: 0.5,
            ),
          ),
        ),
        child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onSelected: (value) {
                switch (value) {
                  case 'view':
                    widget.onTaskSelected?.call(task);
                    break;
                  case 'edit':
                    widget.onEdit?.call(task);
                    break;
                  case 'delete':
                    widget.onDelete?.call(task);
                    break;
                  case 'duplicate':
                    widget.onDuplicate?.call(task);
                    break;
                  case 'subtask':
                    widget.onCreateSubtask?.call(task);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'view',
                  child: Row(
                    children: [
                      Icon(Icons.visibility, size: 18, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Visualizar'),
                    ],
                  ),
                ),
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
            if (task.isMainTask)
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
      ),
    );
  }

  Widget _buildHeaderCell(String text, double width, bool isMobile) {
    final cellWidget = Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 3 : 6, vertical: 4), // Padding vertical reduzido para caber em 25px
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: isMobile ? 9 : 11,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );

    if (width > 0) {
      return SizedBox(width: width, child: cellWidget);
    }
    return cellWidget;
  }

  Widget _buildStatusCell(String status, double width, bool isMobile, Task task, bool hasSubtasks, bool isSubtask, bool isExecutorRow, bool hasExecutorPeriods) {
    final badgeColor = _getStatusBadgeColor(status);
    final subtasksCount = _loadedSubtasks[task.id]?.length ?? 0;
    final hasSubs = subtasksCount > 0;
    final isExpanded = _expandedTasks.contains(task.id);
    
    final cellWidget = Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 3 : 6, vertical: isMobile ? 4 : 8),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: Colors.grey[300]!,
            width: 0.5,
          ),
        ),
      ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ícone de expandir/colapsar ou indentação
            if (hasSubs || hasSubtasks || hasExecutorPeriods)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      size: isMobile ? 16 : 18,
                      color: Colors.blue[700],
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _toggleExpand(task.id),
                  ),
                  if (hasSubs && !isExpanded)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$subtasksCount',
                        style: TextStyle(
                          fontSize: isMobile ? 8 : 9,
                          color: Colors.blue[900],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              )
            else if (isSubtask)
              Padding(
                padding: EdgeInsets.only(left: isMobile ? 16 : 20),
                child: Icon(
                  Icons.subdirectory_arrow_right,
                  size: isMobile ? 14 : 16,
                  color: Colors.grey[600],
                ),
              )
            else
              const SizedBox(width: 8),
            // Bolinha de status
            Tooltip(
              message: _getStatusLabel(status),
              child: Container(
                width: isMobile ? 12 : 14,
                height: isMobile ? 12 : 14,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
    );

    if (width > 0) {
      return SizedBox(width: width, child: cellWidget);
    }
    return cellWidget;
  }

  double _getStatusLegendHeight() {
    // Altura fixa de 50px para alinhar com o cabeçalho de dias do Gantt (50px)
    // Total: Legenda (50px) + Cabeçalho (25px) = 75px = Gantt Mês (25px) + Gantt Dias (50px)
    return 50.0;
  }

  Widget _buildStatusLegend(bool isMobile) {
    if (_statusMap.isEmpty) {
      return SizedBox(height: _getStatusLegendHeight());
    }
    
    return Container(
      height: 50, // Altura fixa de 50px para alinhar com o cabeçalho de dias do Gantt
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12, vertical: isMobile ? 6 : 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: isMobile ? 8 : 12,
              runSpacing: isMobile ? 4 : 6,
              children: _statusMap.values.map((status) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: isMobile ? 10 : 12,
                height: isMobile ? 10 : 12,
                decoration: BoxDecoration(
                  color: status.color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                status.status,
                style: TextStyle(
                  fontSize: isMobile ? 10 : 11,
                  color: Colors.grey[700],
                ),
              ),
            ],
          );
        }).toList(),
            ),
          ),
          // Botão para expandir/colapsar todas as subtarefas (na legenda)
          IconButton(
            icon: Icon(
              _allSubtasksExpanded ? Icons.unfold_less : Icons.unfold_more,
              size: isMobile ? 18 : 20,
              color: Colors.grey[700],
            ),
            tooltip: _allSubtasksExpanded ? 'Colapsar todas as subtarefas' : 'Expandir todas as subtarefas',
            onPressed: widget.onToggleAllSubtasks ?? _toggleAllSubtasks,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12, vertical: isMobile ? 6 : 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            icon: Icon(
              _allSubtasksExpanded ? Icons.unfold_less : Icons.unfold_more,
              size: isMobile ? 18 : 20,
              color: Colors.grey[700],
            ),
            tooltip: _allSubtasksExpanded ? 'Colapsar todas as subtarefas' : 'Expandir todas as subtarefas',
            onPressed: widget.onToggleAllSubtasks ?? _toggleAllSubtasks,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  String _getStatusLabel(String status) {
    // Buscar status cadastrado
    final statusObj = _statusMap[status];
    if (statusObj != null) {
      return '${statusObj.codigo} - ${statusObj.status}';
    }
    
    // Fallback para labels padrão
    switch (status) {
      case 'ANDA':
        return 'ANDA - Em Andamento';
      case 'CONC':
        return 'CONC - Concluído';
      case 'PROG':
        return 'PROG - Em Progresso';
      case 'CANC':
        return 'CANC - Cancelado';
      case 'RPAR':
        return 'RPAR - Reparado';
      default:
        return status;
    }
  }

  Widget _buildFrotaCell(Task task, double width, bool isMobile, Color statusBackgroundColor) {
    final frotasCount = _frotasCount[task.id] ?? 0;
    final hasFrota = frotasCount > 0;
    final frotaColor = hasFrota ? Colors.green : Colors.grey[400];
    
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: hasFrota ? () => _mostrarFrotas(task) : null,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 3 : 6, vertical: isMobile ? 4 : 8),
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                color: Colors.grey[300]!,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_shipping,
                size: isMobile ? 12 : 14,
                color: frotaColor,
              ),
              if (hasFrota)
                Padding(
                  padding: EdgeInsets.only(left: isMobile ? 2 : 4),
                  child: Text(
                    '$frotasCount',
                    style: TextStyle(
                      fontSize: isMobile ? 9 : 10,
                      color: statusBackgroundColor != Colors.white ? Colors.grey[800] : Colors.black87,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatCell(Task task, double width, bool isMobile, Color statusBackgroundColor) {
    final mensagensCount = _mensagensCount[task.id] ?? 0;
    final hasMessages = mensagensCount > 0;
    final chatColor = hasMessages ? Colors.green : Colors.grey[400];
    
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: () => _abrirChatTarefa(task),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 3 : 6, vertical: isMobile ? 4 : 8),
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                color: Colors.grey[300]!,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat,
                size: isMobile ? 12 : 14,
                color: chatColor,
              ),
              if (hasMessages)
                Padding(
                  padding: EdgeInsets.only(left: isMobile ? 2 : 4),
                  child: Text(
                    '$mensagensCount',
                    style: TextStyle(
                      fontSize: isMobile ? 9 : 10,
                      color: statusBackgroundColor != Colors.white ? Colors.grey[800] : Colors.black87,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotaSAPCell(Task task, double width, bool isMobile, Color statusBackgroundColor) {
    final notasCount = _notasSAPCount[task.id] ?? 0;
    final hasNotas = notasCount > 0;
    final notaColor = hasNotas ? Colors.green : Colors.grey[400];
    
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: hasNotas ? () => _mostrarNotasSAP(task) : null,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 3 : 6, vertical: isMobile ? 4 : 8),
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                color: Colors.grey[300]!,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.description,
                size: isMobile ? 12 : 14,
                color: notaColor,
              ),
              if (hasNotas)
                Padding(
                  padding: EdgeInsets.only(left: isMobile ? 2 : 4),
                  child: Text(
                    '$notasCount',
                    style: TextStyle(
                      fontSize: isMobile ? 9 : 10,
                      color: statusBackgroundColor != Colors.white ? Colors.grey[800] : Colors.black87,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrdemCell(Task task, double width, bool isMobile, Color statusBackgroundColor) {
    final ordensCount = _ordensCount[task.id] ?? 0;
    final hasOrdens = ordensCount > 0;
    final ordemColor = hasOrdens ? Colors.green : Colors.grey[400];
    
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: hasOrdens ? () => _mostrarOrdens(task) : null,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 3 : 6, vertical: isMobile ? 4 : 8),
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                color: Colors.grey[300]!,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.list_alt,
                size: isMobile ? 12 : 14,
                color: ordemColor,
              ),
              if (hasOrdens)
                Padding(
                  padding: EdgeInsets.only(left: isMobile ? 2 : 4),
                  child: Text(
                    '$ordensCount',
                    style: TextStyle(
                      fontSize: isMobile ? 9 : 10,
                      color: statusBackgroundColor != Colors.white ? Colors.grey[800] : Colors.black87,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildATCell(Task task, double width, bool isMobile, Color statusBackgroundColor) {
    final atsCount = _atsCount[task.id] ?? 0;
    final hasATs = atsCount > 0;
    final atColor = hasATs ? Colors.green : Colors.grey[400];
    
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: hasATs ? () => _mostrarATs(task) : null,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 3 : 6, vertical: isMobile ? 4 : 8),
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                color: Colors.grey[300]!,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.assignment,
                size: isMobile ? 12 : 14,
                color: atColor,
              ),
              if (hasATs)
                Padding(
                  padding: EdgeInsets.only(left: isMobile ? 2 : 4),
                  child: Text(
                    '$atsCount',
                    style: TextStyle(
                      fontSize: isMobile ? 9 : 10,
                      color: statusBackgroundColor != Colors.white ? Colors.grey[800] : Colors.black87,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSICell(Task task, double width, bool isMobile, Color statusBackgroundColor) {
    final sisCount = _sisCount[task.id] ?? 0;
    final hasSIs = sisCount > 0;
    final hasSiField = task.si.isNotEmpty && task.si != '-N/A-';
    final needsSi = task.precisaSi;
    final hasAnySi = hasSIs || hasSiField;
    final iconColor = needsSi && !hasAnySi
        ? Colors.redAccent
        : hasAnySi
            ? Colors.teal
            : Colors.grey[400];
    
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: hasSIs ? () => _mostrarSIs(task) : null,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 3 : 6, vertical: isMobile ? 4 : 8),
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                color: Colors.grey[300]!,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.description,
                size: isMobile ? 12 : 14,
                color: iconColor,
              ),
              if (hasSIs)
                Padding(
                  padding: EdgeInsets.only(left: isMobile ? 2 : 4),
                  child: Text(
                    '$sisCount',
                    style: TextStyle(
                      fontSize: isMobile ? 9 : 10,
                      color: statusBackgroundColor != Colors.white ? Colors.grey[800] : Colors.black87,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _mostrarFrotas(Task task) async {
    try {
      final frotaNome = _frotasNomes[task.id] ?? task.frota;
      if (!mounted) return;
      
      if (frotaNome.isEmpty || frotaNome == '-N/A-') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhuma frota vinculada')),
        );
        return;
      }
      
      _mostrarDialogFrotas(frotaNome, task);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar frota: $e')),
        );
      }
    }
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

  void _mostrarDialogFrotas(String frotaNome, Task task) {
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
                      child: const Icon(Icons.local_shipping, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Frota Vinculada',
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
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.local_shipping, color: Colors.orange[700], size: 32),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                frotaNome,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange[900],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar com cor baseada no status de usuário
            CircleAvatar(
              backgroundColor: _getStatusUsuarioColor(nota.statusUsuario),
              radius: 20,
              child: Text(
                nota.tipo ?? '?',
                style: TextStyle(
                  color: _getStatusUsuarioTextColor(nota.statusUsuario),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Informações principais
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Número da nota, descrição e ações
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nota: ${nota.nota}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF1E3A5F),
                              ),
                            ),
                            if (nota.descricao != null && nota.descricao!.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  nota.descricao!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.visibility, size: 18, color: Colors.purple),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _mostrarDetalhesNotaCompleta(nota),
                        tooltip: 'Visualizar detalhes',
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
                  const SizedBox(height: 8),
                  // Status do usuário, Sala e Prazo na mesma linha (desktop) ou separados (mobile)
                  if (Responsive.isDesktop(context))
                    Row(
                      children: [
                        // Status do usuário
                        if (nota.statusUsuario != null && nota.statusUsuario!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusUsuarioColor(nota.statusUsuario),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              nota.statusUsuario!,
                              style: TextStyle(
                                color: _getStatusUsuarioTextColor(nota.statusUsuario),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        // Sala
                        if (nota.sala != null && nota.sala!.isNotEmpty) ...[
                          if (nota.statusUsuario != null && nota.statusUsuario!.isNotEmpty)
                            const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.room, size: 14, color: Colors.grey[700]),
                                const SizedBox(width: 4),
                                Text(
                                  'Sala: ${nota.sala}',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        // Prazo
                        if (nota.dataVencimento != null && nota.diasRestantes != null) ...[
                          if ((nota.statusUsuario != null && nota.statusUsuario!.isNotEmpty) ||
                              (nota.sala != null && nota.sala!.isNotEmpty))
                            const SizedBox(width: 8),
                          _buildPrazoBadgeNota(nota),
                        ],
                      ],
                    )
                  else
                    // Mobile: Status, Sala e Prazo em linhas separadas
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status do usuário
                        if (nota.statusUsuario != null && nota.statusUsuario!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusUsuarioColor(nota.statusUsuario),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              nota.statusUsuario!,
                              style: TextStyle(
                                color: _getStatusUsuarioTextColor(nota.statusUsuario),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        // Sala
                        if (nota.sala != null && nota.sala!.isNotEmpty) ...[
                          if (nota.statusUsuario != null && nota.statusUsuario!.isNotEmpty)
                            const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.room, size: 14, color: Colors.grey[700]),
                                const SizedBox(width: 4),
                                Text(
                                  'Sala: ${nota.sala}',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        // Prazo
                        if (nota.dataVencimento != null && nota.diasRestantes != null) ...[
                          if ((nota.statusUsuario != null && nota.statusUsuario!.isNotEmpty) ||
                              (nota.sala != null && nota.sala!.isNotEmpty))
                            const SizedBox(height: 6),
                          _buildPrazoBadgeNota(nota),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Construir badge de prazo (mesmo padrão da tabela)
  Widget _buildPrazoBadgeNota(NotaSAP nota) {
    if (nota.dataVencimento == null || nota.diasRestantes == null) {
      return const SizedBox.shrink();
    }

    final diasRestantes = nota.diasRestantes!;
    final dataVencimento = nota.dataVencimento!;
    
    // Determinar cor baseado nos dias restantes
    Color badgeColor;
    Color textColor;
    
    if (diasRestantes <= 0) {
      // Preto: já passou da data ou vence hoje
      badgeColor = Colors.black;
      textColor = Colors.white;
    } else if (diasRestantes <= 30) {
      // Vermelho: vence em até 30 dias
      badgeColor = Colors.red;
      textColor = Colors.white;
    } else if (diasRestantes <= 90) {
      // Amarelo: vence em até 90 dias
      badgeColor = Colors.yellow[700] ?? Colors.amber;
      textColor = Colors.black;
    } else {
      // Azul: mais de 90 dias
      badgeColor = Colors.blue;
      textColor = Colors.white;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today,
            size: 14,
            color: textColor,
          ),
          const SizedBox(width: 4),
          Text(
            _formatDateNota(dataVencimento),
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              diasRestantes < 0
                  ? '${diasRestantes} dias' // Mostrar valor negativo quando vencido
                  : diasRestantes == 0
                      ? 'Vence hoje'
                      : diasRestantes == 1
                          ? '1 dia'
                          : '$diasRestantes dias',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Funções auxiliares para cores baseadas no status de usuário
  Color _getStatusUsuarioColor(String? statusUsuario) {
    if (statusUsuario == null || statusUsuario.isEmpty) return Colors.grey;
    
    final status = statusUsuario.toUpperCase();
    
    // CONC - Verde
    if (status.contains('CONC')) return Colors.green;
    
    // CADU ou CAIM - Cinza
    if (status.contains('CADU') || status.contains('CAIM')) return Colors.grey;
    
    // REGI - Laranja
    if (status.contains('REGI')) return Colors.orange;
    
    // EMAM - Amarelo
    if (status.contains('EMAM')) return Colors.yellow[700] ?? Colors.amber;
    
    // ANLS - Azul
    if (status.contains('ANLS')) return Colors.blue;
    
    // Padrão - Cinza
    return Colors.grey;
  }

  Color _getStatusUsuarioTextColor(String? statusUsuario) {
    if (statusUsuario == null || statusUsuario.isEmpty) return Colors.white;
    
    final status = statusUsuario.toUpperCase();
    
    // Para EMAM (amarelo), usar texto preto para melhor contraste
    if (status.contains('EMAM')) return Colors.black;
    
    // Para os outros, usar texto branco
    return Colors.white;
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
                      child: const Icon(Icons.list_alt, color: Colors.white, size: 24),
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
          child: const Icon(Icons.list_alt, color: Colors.orange, size: 20),
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
                _buildInfoRowModern('Status Sistema', at.statusSistema),
                _buildInfoRowModern('Status Usuário', at.statusUsuario),
                _buildInfoRowModern('Texto Breve', at.textoBreve),
                _buildInfoRowModern('Edificação', at.edificacao),
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
                      child: const Icon(Icons.description, color: Colors.white, size: 24),
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
          child: const Icon(Icons.description, color: Colors.teal, size: 20),
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
                height: 1.4,
              ),
              maxLines: label == 'Detalhes' ? null : 3,
              overflow: label == 'Detalhes' ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDetalhesNotaCompleta(NotaSAP nota) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header modernizado
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[700]!, Colors.blue[500]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.description, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nota SAP: ${nota.nota}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (nota.tipo != null)
                            Text(
                              'Tipo: ${nota.tipo}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.white, size: 20),
                      onPressed: () => _copiarParaAreaTransferencia(nota.nota, 'Nota copiada!'),
                      tooltip: 'Copiar nota',
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 24),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Fechar',
                    ),
                  ],
                ),
              ),
              // Conteúdo
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRowDialog('Tipo', nota.tipo),
                      _buildInfoRowDialog('Descrição', nota.descricao),
                      _buildInfoRowDialog('Detalhes', nota.detalhes),
                      _buildInfoRowDialog('Status Sistema', nota.statusSistema),
                      _buildInfoRowDialog('Status Usuário', nota.statusUsuario),
                      _buildInfoRowDialog('Prioridade', nota.textPrioridade),
                      _buildInfoRowDialog('Ordem', nota.ordem),
                      _buildInfoRowDialog('Local de Instalação', nota.localInstalacao),
                      _buildInfoRowDialog('Local', nota.local),
                      _buildInfoRowDialog('Sala', nota.sala),
                      _buildInfoRowDialog('Equipamento', nota.equipamento),
                      _buildInfoRowDialog('Centro', nota.centro),
                      _buildInfoRowDialog('Centro Trabalho Responsável', nota.centroTrabalhoResponsavel),
                      _buildInfoRowDialog('Executor', nota.denominacaoExecutor),
                      _buildInfoRowDialog('GPM', nota.gpm),
                      if (nota.criadoEm != null)
                        _buildInfoRowDialog('Criado em', _formatDateNota(nota.criadoEm!)),
                      if (nota.inicioDesejado != null)
                        _buildInfoRowDialog('Início Desejado', _formatDateNota(nota.inicioDesejado!)),
                      if (nota.conclusaoDesejada != null)
                        _buildInfoRowDialog('Conclusão Desejada', _formatDateNota(nota.conclusaoDesejada!)),
                      if (nota.dataReferencia != null)
                        _buildInfoRowDialog('Data Referência', _formatDateNota(nota.dataReferencia!)),
                      if (nota.inicioAvaria != null)
                        _buildInfoRowDialog('Início Avaria', _formatDateNota(nota.inicioAvaria!)),
                      if (nota.fimAvaria != null)
                        _buildInfoRowDialog('Fim Avaria', _formatDateNota(nota.fimAvaria!)),
                      if (nota.encerramento != null)
                        _buildInfoRowDialog('Encerramento', _formatDateNota(nota.encerramento!)),
                      if (nota.modificadoEm != null)
                        _buildInfoRowDialog('Modificado em', _formatDateNota(nota.modificadoEm!)),
                    ],
                  ),
                ),
              ),
              // Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  border: Border(
                    top: BorderSide(color: Colors.grey[200]!, width: 1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Fechar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        foregroundColor: Colors.grey[800],
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRowDialog(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black87,
                height: 1.4,
              ),
              maxLines: label == 'Detalhes' ? null : 3,
              overflow: label == 'Detalhes' ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateNota(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _abrirChatTarefa(Task task) async {
    try {
      // Buscar ou criar grupo de chat para a tarefa
      GrupoChat? grupoChat;
      
      // Primeiro, tentar obter grupo existente
      grupoChat = await _chatService.obterGrupoPorTarefaId(task.id);
      
      // Se não existir, criar um novo grupo
      if (grupoChat == null) {
        // Obter ou criar comunidade baseada na divisão e segmento da tarefa
        if (task.divisaoId != null && task.segmentoId != null) {
          final divisaoNome = task.divisao.isNotEmpty 
              ? task.divisao 
              : 'Divisão';
          final segmentoNome = task.segmento.isNotEmpty 
              ? task.segmento 
              : 'Segmento';
          
          final comunidade = await _chatService.criarOuObterComunidade(
            task.regionalId ?? '',
            task.regional,
            task.divisaoId!,
            divisaoNome,
            task.segmentoId!,
            segmentoNome,
          );
          
          if (comunidade.id != null) {
            grupoChat = await _chatService.criarOuObterGrupo(
              task.id,
              task.tarefa,
              comunidade.id!,
            );
          }
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
      if (mounted && grupoChat != null && grupoChat.id != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              grupoId: grupoChat!.id!,
              onBack: () => Navigator.of(context).pop(),
            ),
            fullscreenDialog: true,
          ),
        );
      }
    } catch (e) {
      print('Erro ao abrir chat da tarefa: $e');
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

  Widget _buildCell(
    String text,
    double width,
    bool isMobile, {
    bool isSubtask = false,
    IconData? icon,
    Color? iconColor,
    bool hasColoredBackground = false,
    int maxLines = 1,
    bool softWrap = false,
    TextOverflow overflow = TextOverflow.ellipsis,
    FontWeight? fontWeight,
  }) {
    final cellWidget = Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 3 : 6, vertical: isMobile ? 4 : 8),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: Colors.grey[300]!,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Padding(
              padding: EdgeInsets.only(right: isMobile ? 2 : 4),
              child: Icon(
                icon,
                size: isMobile ? 12 : 14,
                color: iconColor ?? Colors.grey[600],
              ),
            ),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: isMobile ? 9 : 10,
                color: hasColoredBackground 
                    ? (isSubtask ? Colors.grey[700] : Colors.grey[800])
                    : (isSubtask ? Colors.black87 : Colors.black87),
                fontStyle: isSubtask ? FontStyle.italic : FontStyle.normal,
                fontWeight: fontWeight,
              ),
              overflow: overflow,
              maxLines: maxLines, // permitir quebra controlada quando pedido
              softWrap: softWrap,
            ),
          ),
        ],
      ),
    );

    if (width > 0) {
      return SizedBox(width: width, child: cellWidget);
    }
    return cellWidget;
  }
}
