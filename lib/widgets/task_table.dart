import 'package:flutter/material.dart';
import '../models/task.dart';
import '../models/status.dart';
import '../services/task_service.dart';
import '../services/status_service.dart';
import '../services/chat_service.dart';
import '../services/anexo_service.dart';
import '../models/grupo_chat.dart';
import 'chat_screen.dart';
import '../utils/responsive.dart';

class TaskTable extends StatefulWidget {
  final List<Task> tasks;
  final ScrollController scrollController;
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
  Map<String, Status> _statusMap = {}; // Mapa de código de status -> Status
  Map<String, int> _mensagensCount = {}; // Mapa de taskId -> quantidade de mensagens
  Map<String, int> _anexosCount = {}; // Mapa de taskId -> quantidade de anexos
  bool get _allSubtasksExpanded => widget.allSubtasksExpanded ?? false; // Estado compartilhado ou local

  @override
  void initState() {
    super.initState();
    _loadStatus();
    _loadCounts();
    _loadAllSubtasks();
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

  Future<void> _loadCounts() async {
    if (widget.tasks.isEmpty || !mounted) return;

    try {
      final taskIds = widget.tasks.map((t) => t.id).toList();
      
      // Carregar contagens de mensagens e anexos em paralelo
      final mensagensFuture = _chatService.contarMensagensPorTarefas(taskIds);
      final anexosFuture = _anexoService.contarAnexosPorTarefas(taskIds);
      
      final results = await Future.wait([mensagensFuture, anexosFuture]);
      
      if (mounted) {
        setState(() {
          _mensagensCount = results[0];
          _anexosCount = results[1];
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
      
      // Se a tarefa está expandida e tem subtarefas carregadas, adicionar
      if (isExpanded && _loadedSubtasks.containsKey(mainTask.id)) {
        hierarchicalTasks.addAll(_loadedSubtasks[mainTask.id]!);
      }
      
      // Se a tarefa está expandida e tem períodos por executor, criar linhas virtuais para cada executor
      if (isExpanded && mainTask.executorPeriods.isNotEmpty) {
        print('👥 DEBUG TaskTable: Adicionando ${mainTask.executorPeriods.length} períodos por executor da tarefa ${mainTask.id.substring(0, 8)}');
        for (var executorPeriod in mainTask.executorPeriods) {
          // Criar uma tarefa virtual representando o executor
          final virtualTaskId = '${mainTask.id}_executor_${executorPeriod.executorId}';
          
          // Calcular data início e fim baseado nos períodos do executor
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
          
          // Criar tarefa virtual com os períodos do executor
          final virtualTask = Task(
            id: virtualTaskId,
            parentId: mainTask.id, // Marcar como "subtask" da tarefa principal
            statusId: mainTask.statusId,
            regionalId: mainTask.regionalId,
            divisaoId: mainTask.divisaoId,
            segmentoId: mainTask.segmentoId,
            localIds: mainTask.localIds,
            executorIds: [executorPeriod.executorId],
            equipeIds: mainTask.equipeIds,
            localId: mainTask.localId,
            equipeId: mainTask.equipeId,
            status: mainTask.status,
            statusNome: mainTask.statusNome,
            regional: mainTask.regional,
            divisao: mainTask.divisao,
            locais: mainTask.locais,
            tipo: mainTask.tipo,
            ordem: mainTask.ordem,
            tarefa: '${executorPeriod.executorNome} - ${mainTask.tarefa}', // Nome do executor + tarefa
            executores: [executorPeriod.executorNome],
            equipes: mainTask.equipes,
            executor: executorPeriod.executorNome,
            frota: mainTask.frota,
            coordenador: mainTask.coordenador,
            si: mainTask.si,
            dataInicio: minDate ?? mainTask.dataInicio,
            dataFim: maxDate ?? mainTask.dataFim,
            ganttSegments: executorPeriod.periods, // Usar os períodos do executor como segmentos
            executorPeriods: [], // Não incluir períodos aninhados
            observacoes: mainTask.observacoes,
            horasPrevistas: mainTask.horasPrevistas,
            horasExecutadas: mainTask.horasExecutadas,
            prioridade: mainTask.prioridade,
          );
          
          hierarchicalTasks.add(virtualTask);
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
    
    print('🔄 DEBUG TaskTable: _toggleExpand chamado - taskId: ${taskId.substring(0, 8)}, newExpandedState: $newExpandedState');
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
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('Nenhuma tarefa encontrada'),
        ),
      );
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
          // Cabeçalho fixo com scroll horizontal
          Container(
            height: isMobile ? 33 : 38,
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
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: _calculateTotalTableWidth(isMobile),
                child: _buildHeaderRow(isMobile),
              ),
            ),
          ),
          // Corpo scrollável (vertical e horizontal)
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableHeight = constraints.maxHeight;
                final availableWidth = constraints.maxWidth;
                if (availableHeight.isInfinite || availableHeight <= 0) {
                  return const Center(child: CircularProgressIndicator());
                }
                // Calcular largura total das colunas
                final acoesWidth = isMobile ? 50.0 : 60.0;
                final statusWidth = isMobile ? 60.0 : 70.0;
                final localWidth = isMobile ? 80.0 : 90.0;
                final tipoWidth = isMobile ? 90.0 : 100.0;
                final tarefaWidth = isMobile ? 150.0 : 200.0;
                final executorWidth = isMobile ? 120.0 : 150.0;
                final coordenadorWidth = isMobile ? 100.0 : 130.0;
    final chatWidth = isMobile ? 50.0 : 60.0;
    final anexosWidth = isMobile ? 50.0 : 60.0;
    // Botão foi movido para a legenda, não precisa mais incluir aqui
    final totalWidth = acoesWidth + statusWidth + localWidth + tipoWidth + tarefaWidth + 
        executorWidth + coordenadorWidth + chatWidth + anexosWidth;
                final minWidth = totalWidth > availableWidth ? totalWidth : availableWidth;
                
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: minWidth,
                    child: SizedBox(
                      height: availableHeight,
                      child: ListView.builder(
                        controller: widget.scrollController,
                        itemCount: hierarchicalTasks.length,
                        itemBuilder: (context, index) {
                          final task = hierarchicalTasks[index];
                          final previousTask = index > 0 ? hierarchicalTasks[index - 1] : null;
                          
                          final isSubtask = task.parentId != null;
                          final hasSubtasks = _loadedSubtasks.containsKey(task.id) 
                              ? _loadedSubtasks[task.id]!.isNotEmpty
                              : false;
                          final isExecutorRow = task.id.contains('_executor_');
                          
                          // Verificar se mudou o grupo (apenas se não for PERÍODO e se não for subtarefa/executor)
                          bool mudouGrupo = false;
                          
                          // Debug inicial
                          if (index == 0) {
                            print('🔍 DEBUG TaskTable: sortColumn=${widget.sortColumn}, getSortValue=${widget.getSortValue != null}');
                          }
                          
                          if (widget.sortColumn != null && 
                              widget.sortColumn != 'PERÍODO' && 
                              previousTask != null &&
                              !previousTask.id.contains('_executor_') &&
                              previousTask.parentId == null &&
                              !isSubtask &&
                              !isExecutorRow &&
                              widget.getSortValue != null) {
                            try {
                              final previousValue = widget.getSortValue!(previousTask);
                              final currentValue = widget.getSortValue!(task);
                              mudouGrupo = previousValue.trim() != currentValue.trim();
                              
                              // Debug - mostrar quando detectar mudança
                              if (mudouGrupo) {
                                print('🔴 DEBUG TaskTable linha $index: MUDOU GRUPO!');
                                print('   Coluna: ${widget.sortColumn}');
                                print('   Valor anterior: "$previousValue"');
                                print('   Valor atual: "$currentValue"');
                              }
                            } catch (e, stackTrace) {
                              // Se houver erro, não mostrar linha separadora
                              print('❌ Erro ao verificar mudança de grupo: $e');
                              print('Stack trace: $stackTrace');
                              mudouGrupo = false;
                            }
                          } else {
                            // Debug para entender por que não está verificando
                            if (index < 3) {
                              print('⚠️ DEBUG TaskTable linha $index: Não verificando mudança - sortColumn=${widget.sortColumn}, previousTask=${previousTask != null}, isSubtask=$isSubtask, isExecutorRow=$isExecutorRow, getSortValue=${widget.getSortValue != null}');
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
                                    height: isMobile ? 40 : 50,
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
                                            : isSubtask 
                                                ? BorderSide(
                                                    color: Colors.blue[300]!,
                                                    width: 3,
                                                  )
                                                : BorderSide.none,
                                      ),
                                    ),
                                    child: _buildDataRow(task, isMobile, index, isSubtask, hasSubtasks, isExecutorRow, hasExecutorPeriods),
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
    final tarefaWidth = isMobile ? 150.0 : 200.0;
    final executorWidth = isMobile ? 120.0 : 150.0;
    final coordenadorWidth = isMobile ? 100.0 : 130.0;
    final chatWidth = isMobile ? 50.0 : 60.0;
    final anexosWidth = isMobile ? 50.0 : 60.0;
    // Botão foi movido para a legenda, não precisa mais incluir aqui
    return acoesWidth + statusWidth + localWidth + tipoWidth + tarefaWidth + 
        executorWidth + coordenadorWidth + chatWidth + anexosWidth;
  }

  Widget _buildHeaderRow(bool isMobile) {
    // Definir larguras fixas para todas as colunas
    final acoesWidth = isMobile ? 50.0 : 60.0;
    final statusWidth = isMobile ? 60.0 : 70.0;
    final localWidth = isMobile ? 80.0 : 90.0;
    final tipoWidth = isMobile ? 90.0 : 100.0;
    final tarefaWidth = isMobile ? 150.0 : 200.0;
    final executorWidth = isMobile ? 120.0 : 150.0;
    final coordenadorWidth = isMobile ? 100.0 : 130.0;
    final chatWidth = isMobile ? 50.0 : 60.0;
    final anexosWidth = isMobile ? 50.0 : 60.0;
    
    return Row(
      children: [
        _buildHeaderCell('AÇÕES', acoesWidth, isMobile),
        _buildHeaderCell('STATUS', statusWidth, isMobile),
        _buildHeaderCell('LOCAL', localWidth, isMobile),
        _buildHeaderCell('TIPO', tipoWidth, isMobile),
        _buildHeaderCell('TAREFA', tarefaWidth, isMobile),
        _buildHeaderCell('EXECUTOR', executorWidth, isMobile),
        _buildHeaderCell('COORDENADOR', coordenadorWidth, isMobile),
        _buildHeaderCell('CHAT', chatWidth, isMobile),
        _buildHeaderCell('ANEXOS', anexosWidth, isMobile),
      ],
    );
  }

  Widget _buildDataRow(Task task, bool isMobile, int index, bool isSubtask, bool hasSubtasks, bool isExecutorRow, bool hasExecutorPeriods) {
    // Criar tooltip com informações adicionais
    final tooltipText = _buildTooltipText(task);
    
    // Usar as mesmas larguras fixas do cabeçalho
    final acoesWidth = isMobile ? 50.0 : 60.0;
    final statusWidth = isMobile ? 60.0 : 70.0;
    final localWidth = isMobile ? 80.0 : 90.0;
    final tipoWidth = isMobile ? 90.0 : 100.0;
    final tarefaWidth = isMobile ? 150.0 : 200.0;
    final executorWidth = isMobile ? 120.0 : 150.0;
    final coordenadorWidth = isMobile ? 100.0 : 130.0;
    final chatWidth = isMobile ? 50.0 : 60.0;
    final anexosWidth = isMobile ? 50.0 : 60.0;
    // Botão foi movido para a legenda, não precisa mais incluir aqui
    
    return Tooltip(
      message: tooltipText,
      preferBelow: false,
      child: ClipRect(
        child: Row(
          children: [
          // Coluna de AÇÕES (primeira coluna)
          _buildActionsCell(task, acoesWidth, isMobile),
          // Coluna de STATUS com ícone de expansão
          _buildStatusCell(task.status, statusWidth, isMobile, task, hasSubtasks, isSubtask, isExecutorRow, hasExecutorPeriods),
          _buildCell(task.locais.isNotEmpty ? task.locais.join(', ') : '', localWidth, isMobile),
          _buildCell(task.tipo, tipoWidth, isMobile),
          // Coluna TAREFA com largura fixa
          SizedBox(
            width: tarefaWidth,
            child: Container(
              padding: EdgeInsets.only(left: (isSubtask || isExecutorRow) ? (isMobile ? 20 : 24) : 0),
              child: _buildCell(
                task.tarefa,
                0,
                isMobile,
                isSubtask: isSubtask,
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
              ),
            ),
          ),
          // Coluna COORDENADOR com largura fixa
          SizedBox(
            width: coordenadorWidth,
            child: _buildCell(task.coordenador, 0, isMobile),
          ),
          // Coluna de CHAT (clicável)
          _buildChatCell(task, chatWidth, isMobile),
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
          ),
        ],
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
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 3 : 6, vertical: isMobile ? 4 : 8),
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
    // Altura aproximada da legenda: padding vertical (8*2) + altura do conteúdo (~24) + border (1)
    // Total aproximado: ~41px
    return 41.0;
  }

  Widget _buildStatusLegend(bool isMobile) {
    if (_statusMap.isEmpty) {
      return SizedBox(height: _getStatusLegendHeight());
    }
    
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

  Widget _buildChatCell(Task task, double width, bool isMobile) {
    final mensagensCount = _mensagensCount[task.id] ?? 0;
    final hasMessages = mensagensCount > 0;
    
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
                color: hasMessages ? Colors.blue : Colors.grey[400],
              ),
              if (hasMessages)
                Padding(
                  padding: EdgeInsets.only(left: isMobile ? 2 : 4),
                  child: Text(
                    '$mensagensCount',
                    style: TextStyle(
                      fontSize: isMobile ? 9 : 10,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
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

  Widget _buildCell(String text, double width, bool isMobile, {bool isSubtask = false, IconData? icon, Color? iconColor}) {
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
                color: isSubtask ? Colors.grey[700] : Colors.grey[800],
                fontStyle: isSubtask ? FontStyle.italic : FontStyle.normal,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: isMobile ? 1 : 2,
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
