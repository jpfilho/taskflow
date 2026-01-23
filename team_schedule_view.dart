import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../models/task.dart';
import '../models/executor.dart';
import '../models/tipo_atividade.dart';
import '../models/feriado.dart';
import '../models/status.dart';
import '../services/task_service.dart';
import '../services/executor_service.dart';
import '../services/tipo_atividade_service.dart';
import '../services/auth_service_simples.dart';
import '../services/divisao_service.dart';
import '../services/feriado_service.dart';
import '../services/status_service.dart';
import '../services/anexo_service.dart';
import '../services/nota_sap_service.dart';
import '../services/ordem_service.dart';
import '../services/at_service.dart';
import '../services/si_service.dart';
import '../utils/responsive.dart';

class TeamScheduleView extends StatefulWidget {
  final TaskService taskService;
  final ExecutorService executorService;
  final DateTime startDate;
  final DateTime endDate;
  final List<Task>? filteredTasks; // Tarefas já filtradas (opcional)
  final VoidCallback? onTasksUpdated; // Callback para notificar quando tarefas são atualizadas
  final Function(Task)? onEdit; // Callback para editar tarefa
  final Function(Task)? onDelete; // Callback para deletar tarefa
  final Function(Task)? onDuplicate; // Callback para duplicar tarefa
  final Function(Task)? onCreateSubtask; // Callback para criar subtarefa

  const TeamScheduleView({
    super.key,
    required this.taskService,
    required this.executorService,
    required this.startDate,
    required this.endDate,
    this.filteredTasks,
    this.onTasksUpdated,
    this.onEdit,
    this.onDelete,
    this.onDuplicate,
    this.onCreateSubtask,
  });

  @override
  State<TeamScheduleView> createState() => _TeamScheduleViewState();
}

class ExecutorTaskRow {
  final Executor executor;
  final List<Task> tasks;

  ExecutorTaskRow({
    required this.executor,
    required this.tasks,
  });
}

class _TeamScheduleViewState extends State<TeamScheduleView> {
  List<Task> _tasks = [];
  List<Executor> _executores = [];
  bool _isLoading = true;
  List<ExecutorTaskRow> _executorRows = [];
  final ScrollController _tableVerticalScrollController = ScrollController();
  final ScrollController _ganttVerticalScrollController = ScrollController();
  final ScrollController _ganttHorizontalScrollController = ScrollController();
  final double _rowHeight = 28.0;
  bool _isScrolling = false;
  bool _showSegmentTexts = false; // Controla se os textos dos segmentos são exibidos (padrão: oculto)
  
  // Variáveis para tipos de atividade e cores
  final TipoAtividadeService _tipoAtividadeService = TipoAtividadeService();
  Map<String, TipoAtividade> _tipoAtividadeMap = {}; // Mapa de código de tipo -> TipoAtividade
  
  // Variáveis para feriados
  final FeriadoService _feriadoService = FeriadoService();
  Map<DateTime, List<Feriado>> _feriadosMap = {}; // Mapa de data -> Lista de feriados
  
  // Serviço de autenticação para obter perfil do usuário
  final AuthServiceSimples _authService = AuthServiceSimples();
  
  // Serviços para modal de atividades
  final StatusService _statusService = StatusService();
  Map<String, Status> _statusMap = {}; // Mapa de código de status -> Status
  
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
  void initState() {
    super.initState();
    print('🚀 TeamScheduleView: initState');
    
    // Sincronizar scroll vertical (tabela e Gantt)
    _tableVerticalScrollController.addListener(() {
      if (!_isScrolling && _ganttVerticalScrollController.hasClients) {
        _isScrolling = true;
        _ganttVerticalScrollController.jumpTo(_tableVerticalScrollController.offset);
        _isScrolling = false;
      }
    });
    
    _ganttVerticalScrollController.addListener(() {
      if (!_isScrolling && _tableVerticalScrollController.hasClients) {
        _isScrolling = true;
        _tableVerticalScrollController.jumpTo(_ganttVerticalScrollController.offset);
        _isScrolling = false;
      }
    });
    
    _loadData();
    _loadSAPCounts();
  }

  Future<void> _loadSAPCounts() async {
    if (_tasks.isEmpty) return;
    try {
      final taskIds = _tasks.map((t) => t.id).toList();
      
      final notasSAPFuture = _notaSAPService.contarNotasPorTarefas(taskIds);
      final ordensFuture = _ordemService.contarOrdensPorTarefas(taskIds);
      final atsFuture = _atService.contarATsPorTarefas(taskIds);
      final sisFuture = _siService.contarSIsPorTarefas(taskIds);
      
      final results = await Future.wait([
        notasSAPFuture,
        ordensFuture,
        atsFuture,
        sisFuture,
      ]);
      
      if (mounted) {
        setState(() {
          _notasSAPCount = results[0];
          _ordensCount = results[1];
          _atsCount = results[2];
          _sisCount = results[3];
        });
      }
    } catch (e) {
      print('Erro ao carregar contagens SAP: $e');
    }
  }

  @override
  void didUpdateWidget(TeamScheduleView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reconstruir quando o período mudar
    if (oldWidget.startDate != widget.startDate || oldWidget.endDate != widget.endDate) {
      print('🔄 Período mudou, reconstruindo dados...');
      _loadFeriados(); // Recarregar feriados para o novo período
      _buildExecutorRows();
    }
  }

  @override
  void dispose() {
    _tableVerticalScrollController.dispose();
    _ganttVerticalScrollController.dispose();
    _ganttHorizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    print('📥 TeamScheduleView: Iniciando carregamento de dados...');
    setState(() {
      _isLoading = true;
    });

    try {
      // Carregar tipos de atividade primeiro
      final tiposAtividade = await _tipoAtividadeService.getAllTiposAtividade();
      _tipoAtividadeMap = {};
      for (var tipo in tiposAtividade) {
        _tipoAtividadeMap[tipo.codigo] = tipo;
      }
      print('✅ Tipos de atividade carregados: ${_tipoAtividadeMap.length}');
      
      // Carregar status
      final statuses = await _statusService.getAllStatus();
      _statusMap = {};
      for (var status in statuses) {
        _statusMap[status.codigo] = status;
      }
      print('✅ Status carregados: ${_statusMap.length}');
      
      // Carregar feriados
      await _loadFeriados();
      
      // Usar tarefas filtradas se fornecidas, caso contrário buscar do TaskService
      final tasks = widget.filteredTasks ?? await widget.taskService.getAllTasks();
      print('✅ Tarefas carregadas: ${tasks.length}');
      
      final executores = await widget.executorService.getAllExecutores();
      final executoresAtivos = executores.where((e) => e.ativo).toList();
      print('✅ Executores ativos: ${executoresAtivos.length}');
      
      // Filtrar executores pelo perfil do usuário
      final usuario = _authService.currentUser;
      List<Executor> executoresFiltrados = executoresAtivos;
      
      if (usuario != null && !usuario.isRoot && usuario.temPerfilConfigurado()) {
        print('🔒 Filtrando executores pelo perfil do usuário...');
        print('   Regionais do perfil: ${usuario.regionalIds.length}');
        print('   Divisões do perfil: ${usuario.divisaoIds.length}');
        print('   Segmentos do perfil: ${usuario.segmentoIds.length}');
        
        // Se o usuário tem regionais configuradas, precisamos buscar as divisões dessas regionais
        // e incluir essas divisões no filtro
        Set<String> divisaoIdsPermitidas = Set.from(usuario.divisaoIds);
        
        // Se tiver regionais configuradas, buscar divisões das regionais
        if (usuario.regionalIds.isNotEmpty) {
          try {
            final divisaoService = DivisaoService();
            final todasDivisoes = await divisaoService.getAllDivisoes();
            for (var regionalId in usuario.regionalIds) {
              final divisoesDaRegional = todasDivisoes.where((d) => d.regionalId == regionalId);
              final divisaoIds = divisoesDaRegional.map((d) => d.id).toList();
              divisaoIdsPermitidas.addAll(divisaoIds);
            }
          } catch (e) {
            print('⚠️ Erro ao buscar divisões das regionais: $e');
          }
        }
        
        executoresFiltrados = executoresAtivos.where((executor) {
          // Verificar se o executor pertence a uma divisão permitida (do perfil ou das regionais)
          bool temDivisaoPermitida = divisaoIdsPermitidas.isEmpty || 
              (executor.divisaoId != null && divisaoIdsPermitidas.contains(executor.divisaoId));
          
          // Verificar se o executor tem algum segmento do perfil
          bool temSegmentoPermitido = usuario.segmentoIds.isEmpty ||
              executor.segmentoIds.any((segmentoId) => usuario.segmentoIds.contains(segmentoId));
          
          return temDivisaoPermitida && temSegmentoPermitido;
        }).toList();
        
        print('✅ Executores filtrados: ${executoresFiltrados.length} de ${executoresAtivos.length}');
      } else if (usuario != null && usuario.isRoot) {
        print('👑 Usuário root: mostrando todos os executores');
      } else {
        print('⚠️ Usuário sem perfil configurado: mostrando todos os executores');
      }
      
      setState(() {
        _tasks = tasks;
        _executores = executoresFiltrados;
        _isLoading = false;
      });
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _buildExecutorRows();
      });
    } catch (e, stackTrace) {
      print('❌ Erro ao carregar dados: $e');
      print('📚 StackTrace: $stackTrace');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _buildExecutorRows() {
    print('🔨 _buildExecutorRows: Iniciando construção');
    print('   Período: ${widget.startDate} a ${widget.endDate}');
    
    // Criar mapa de executores
    final executorById = <String, Executor>{};
    final executorByNome = <String, Executor>{};
    final executorByNomeCompleto = <String, Executor>{};
    
    for (var executor in _executores) {
      executorById[executor.id] = executor;
      if (executor.nome.isNotEmpty) {
        executorByNome[executor.nome.toUpperCase()] = executor;
      }
      if (executor.nomeCompleto != null && executor.nomeCompleto!.isNotEmpty) {
        executorByNomeCompleto[executor.nomeCompleto!.toUpperCase()] = executor;
      }
    }
    
    // Criar mapa de executor -> lista de tarefas
    final executorTasksMap = <String, List<Task>>{};
    for (var executor in _executores) {
      executorTasksMap[executor.id] = [];
    }
    
    final periodStart = DateTime(widget.startDate.year, widget.startDate.month, widget.startDate.day);
    final periodEnd = DateTime(widget.endDate.year, widget.endDate.month, widget.endDate.day);

    // Processar tarefas e vincular aos executores
    for (var task in _tasks) {
      // Verificar se a tarefa tem segmentos no período selecionado
      bool hasSegmentInPeriod = false;
      for (var segment in task.ganttSegments) {
        final startDate = DateTime(segment.dataInicio.year, segment.dataInicio.month, segment.dataInicio.day);
        final endDate = DateTime(segment.dataFim.year, segment.dataFim.month, segment.dataFim.day);
        
        if (!(startDate.isAfter(periodEnd) || endDate.isBefore(periodStart))) {
          hasSegmentInPeriod = true;
          break;
        }
      }
      
      if (!hasSegmentInPeriod && task.ganttSegments.isEmpty) {
        if (task.dataInicio.isAfter(periodEnd) || task.dataFim.isBefore(periodStart)) {
          continue;
        }
      }
      
      // Coletar executores vinculados
      final executoresVinculados = <Executor>{};
      
      for (var executorId in task.executorIds) {
        final executor = executorById[executorId];
        if (executor != null) executoresVinculados.add(executor);
      }
      
      for (var executorNome in task.executores) {
        if (executorNome.isNotEmpty && executorNome != '-N/A-') {
          final executor = executorByNome[executorNome.toUpperCase()] ?? 
                          executorByNomeCompleto[executorNome.toUpperCase()];
          if (executor != null) executoresVinculados.add(executor);
        }
      }
      
      if (task.equipeExecutores != null) {
        for (var equipeExecutor in task.equipeExecutores!) {
          final executor = executorByNome[equipeExecutor.executorNome.toUpperCase()] ?? 
                          executorByNomeCompleto[equipeExecutor.executorNome.toUpperCase()];
          if (executor != null) executoresVinculados.add(executor);
        }
      }
      
      // Adicionar tarefa aos executores
      for (var executor in executoresVinculados) {
        if (!executorTasksMap.containsKey(executor.id)) {
          executorTasksMap[executor.id] = [];
        }
        executorTasksMap[executor.id]!.add(task);
      }
    }

    // Criar lista ordenada
    final executorRows = <ExecutorTaskRow>[];
    final sortedExecutores = _getSortedExecutores();
    
    for (var executor in sortedExecutores) {
      final tasks = executorTasksMap[executor.id] ?? [];
      executorRows.add(ExecutorTaskRow(
        executor: executor,
        tasks: tasks,
      ));
    }

    print('✅ Dados construídos: ${executorRows.length} executores');
    
    setState(() {
      _executorRows = executorRows;
    });
  }

  List<Executor> _getSortedExecutores() {
    final sorted = List<Executor>.from(_executores);
    sorted.sort((a, b) {
      // Primeiro: ordenar por função (Executor < Coordenador < Gerente)
      final funcaoA = (a.funcao ?? '').toUpperCase();
      final funcaoB = (b.funcao ?? '').toUpperCase();
      
      int funcaoOrderA = _getFuncaoOrder(funcaoA);
      int funcaoOrderB = _getFuncaoOrder(funcaoB);
      
      if (funcaoOrderA != funcaoOrderB) {
        return funcaoOrderA.compareTo(funcaoOrderB);
      }
      
      // Se a função for a mesma, ordenar alfabeticamente pelo nome
      final nomeA = (a.nomeCompleto ?? a.nome).toUpperCase();
      final nomeB = (b.nomeCompleto ?? b.nome).toUpperCase();
      return nomeA.compareTo(nomeB);
    });
    return sorted;
  }
  
  int _getFuncaoOrder(String funcao) {
    // Ordem: Executor (1) < Coordenador (2) < Gerente (3)
    // Outras funções ficam no final (4)
    if (funcao.contains('EXECUTOR')) {
      return 1;
    } else if (funcao.contains('COORDENADOR')) {
      return 2;
    } else if (funcao.contains('GERENTE')) {
      return 3;
    } else {
      return 4;
    }
  }

  List<DateTime> _getDaysInPeriod() {
    final days = <DateTime>[];
    var currentDate = DateTime(widget.startDate.year, widget.startDate.month, widget.startDate.day);
    final endDate = DateTime(widget.endDate.year, widget.endDate.month, widget.endDate.day);
    
    while (currentDate.isBefore(endDate.add(const Duration(days: 1)))) {
      days.add(DateTime(currentDate.year, currentDate.month, currentDate.day));
      currentDate = currentDate.add(const Duration(days: 1));
    }
    return days;
  }

  double _getDayOffset(DateTime date, List<DateTime> days, double dayWidth) {
    final index = days.indexWhere((d) => 
      d.year == date.year && d.month == date.month && d.day == date.day
    );
    return index >= 0 ? index * dayWidth : 0;
  }

  // Método para construir o conteúdo do segmento (texto ou ícone)
  Widget _buildSegmentContent(GanttSegment segment, Task task, double barWidth) {
    // Se os textos estão desabilitados, retornar widget vazio
    if (!_showSegmentTexts) {
      return const SizedBox.shrink();
    }
    
    final tipoPeriodo = segment.tipoPeriodo.toUpperCase();
    
    // Para PLANEJAMENTO e DESLOCAMENTO: mostrar ícone
    if (tipoPeriodo == 'PLANEJAMENTO' || tipoPeriodo == 'DESLOCAMENTO') {
      IconData iconData;
      if (tipoPeriodo == 'PLANEJAMENTO') {
        iconData = Icons.calendar_today; // Ícone para planejamento
      } else {
        iconData = Icons.directions_car; // Ícone para deslocamento
      }
      
      // Ajustar tamanho do ícone para não ultrapassar a altura da linha
      final iconSize = (_rowHeight - 4).clamp(12.0, 20.0);
      
      final textColor = _getSegmentTextColor(task);
      return Icon(
        iconData,
        color: textColor,
        size: iconSize,
        shadows: [
          Shadow(
            offset: const Offset(0.5, 0.5),
            blurRadius: 1.0,
            color: Colors.black.withOpacity(0.5),
          ),
        ],
      );
    }
    
    // Para EXECUCAO: mostrar texto (local e tarefa)
    // Com altura reduzida, mostrar apenas uma linha se possível
    final fontSize = _getOptimalFontSize(barWidth);
    final availableHeight = _rowHeight - 4; // Descontar padding
    
    // Se a altura disponível for muito pequena, mostrar apenas local ou tarefa
    final textColor = _getSegmentTextColor(task);
    if (availableHeight < 20) {
      return Text(
        _getTruncatedText(
          task.locais.isNotEmpty ? task.locais.first : task.tarefa,
          barWidth,
        ),
        style: TextStyle(
          color: textColor,
          fontSize: fontSize.clamp(8.0, 10.0),
          fontWeight: FontWeight.w600,
          shadows: [
            Shadow(
              offset: const Offset(0.5, 0.5),
              blurRadius: 1.0,
              color: Colors.black.withOpacity(0.5),
            ),
          ],
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        textAlign: TextAlign.center,
      );
    }
    
    // Se houver altura suficiente, mostrar duas linhas
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Linha 1: Local
        if (task.locais.isNotEmpty)
          Flexible(
            child: Text(
              _getTruncatedText(
                task.locais.join(', '),
                barWidth,
              ),
              style: TextStyle(
                color: textColor,
                fontSize: fontSize.clamp(8.0, 10.0),
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(
                    offset: const Offset(0.5, 0.5),
                    blurRadius: 1.0,
                    color: Colors.black.withOpacity(0.5),
                  ),
                ],
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              textAlign: TextAlign.center,
            ),
          ),
        // Linha 2: Tarefa
        if (task.tarefa.isNotEmpty)
          Flexible(
            child: Text(
              _getTruncatedText(
                task.tarefa,
                barWidth,
              ),
              style: TextStyle(
                color: textColor,
                fontSize: fontSize.clamp(8.0, 10.0),
                fontWeight: FontWeight.w500,
                shadows: [
                  Shadow(
                    offset: const Offset(0.5, 0.5),
                    blurRadius: 1.0,
                    color: Colors.black.withOpacity(0.5),
                  ),
                ],
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
  
  String _getTruncatedText(String text, double barWidth) {
    // Calcular tamanho aproximado do texto
    final fontSize = _getOptimalFontSize(barWidth);
    final charWidth = fontSize * 0.6; // Aproximação: cada caractere ocupa ~60% do tamanho da fonte
    final maxChars = (barWidth / charWidth).floor();
    
    if (text.length <= maxChars) {
      return text;
    }
    
    // Truncar e adicionar "..."
    return '${text.substring(0, maxChars - 3)}...';
  }
  
  double _getOptimalFontSize(double barWidth) {
    // Tamanho mínimo: 7px, máximo: 10px (ajustado para altura reduzida)
    // Ajustar baseado na largura da barra
    if (barWidth < 30) {
      return 7.0;
    } else if (barWidth < 60) {
      return 8.0;
    } else if (barWidth < 100) {
      return 9.0;
    } else {
      return 10.0;
    }
  }

  Future<void> _loadFeriados() async {
    try {
      // Carregar feriados para o período
      final feriadosMap = await _feriadoService.getFeriadosMapByDateRange(
        widget.startDate,
        widget.endDate,
      );
      setState(() {
        _feriadosMap = feriadosMap;
      });
    } catch (e) {
      print('Erro ao carregar feriados no Gantt de equipes: $e');
    }
  }

  // Verificar se uma data é feriado
  bool _isFeriado(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return _feriadosMap.containsKey(normalizedDate);
  }

  Color _getSegmentColor(GanttSegment segment, Task task) {
    // PRIORIDADE 1: Verificar o tipo de período
    // DESLOCAMENTO e PLANEJAMENTO sempre usam suas cores específicas, independente do tipo de atividade
    switch (segment.tipoPeriodo.toUpperCase()) {
      case 'PLANEJAMENTO':
        return Colors.orange[600]!; // Laranja para planejamento (sempre)
      case 'DESLOCAMENTO':
        return Colors.blue[900]!; // Azul escuro para deslocamento (sempre)
      case 'EXECUCAO':
      default:
        // PRIORIDADE 2: Verificar se o tipo de atividade tem cor de segmento definida
        if (task.tipo.isNotEmpty) {
          final tipoAtividade = _tipoAtividadeMap[task.tipo];
          if (tipoAtividade != null && tipoAtividade.corSegmento != null && tipoAtividade.corSegmento!.isNotEmpty) {
            try {
              final color = tipoAtividade.segmentBackgroundColor;
              return color;
            } catch (e) {
              print('⚠️ Erro ao converter cor de segmento do tipo de atividade "${tipoAtividade.corSegmento}": $e');
            }
          }
          // PRIORIDADE 3: Se não houver cor de segmento, usar cor principal do tipo de atividade
          if (tipoAtividade != null && tipoAtividade.cor != null && tipoAtividade.cor!.isNotEmpty) {
            try {
              // Converter hexadecimal para Color
              final hexColor = tipoAtividade.cor!.replaceFirst('#', '');
              final color = Color(int.parse('FF$hexColor', radix: 16));
              return color;
            } catch (e) {
              print('⚠️ Erro ao converter cor do tipo de atividade "${tipoAtividade.cor}": $e');
            }
          }
        }
        // Se não houver cor definida, usar cinza padrão
        return Colors.grey[400]!;
    }
  }

  Color _getSegmentTextColor(Task task) {
    // Verificar se o tipo de atividade tem cor de texto do segmento definida
    if (task.tipo.isNotEmpty) {
      final tipoAtividade = _tipoAtividadeMap[task.tipo];
      if (tipoAtividade != null && tipoAtividade.corTextoSegmento != null && tipoAtividade.corTextoSegmento!.isNotEmpty) {
        try {
          return tipoAtividade.segmentTextColor;
        } catch (e) {
          print('⚠️ Erro ao converter cor do texto do segmento: $e');
        }
      }
    }
    // Cor padrão branca
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);
    final days = _getDaysInPeriod();

    // Para mobile e tablet, usar layout com scroll horizontal e vertical
    if (isMobile || isTablet) {
      return _buildMobileTabletView(days);
    } else {
      return _buildCombinedView(days);
    }
  }

  Widget _buildMobileTabletView(List<DateTime> days) {
    // Calcular largura mínima dos dias (mínimo 30px para legibilidade)
    final minDayWidth = 30.0;
    final totalGanttWidth = days.length * minDayWidth;
    // Largura da tabela: DIVISÃO(100) + EMPRESA(100) + FUNÇÃO(100) + MATRÍCULA(100) + TAREFAS(80) + NOME(150) = 630px
    // Adicionar margem para garantir que todas as colunas sejam visíveis
    final tableWidth = 650.0;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // Usar a altura disponível das constraints, garantindo que seja válida
        final availableHeight = constraints.maxHeight;
        final screenSize = MediaQuery.of(context).size;
        final orientation = MediaQuery.of(context).orientation;
        
        // Em portrait, usar altura mais conservadora
        final calculatedHeight = availableHeight.isFinite && availableHeight > 0 
            ? availableHeight 
            : (orientation == Orientation.portrait 
                ? screenSize.height * 0.6 
                : screenSize.height * 0.7).clamp(200.0, screenSize.height * 0.9);
        
        return SizedBox(
          height: calculatedHeight,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              width: tableWidth + totalGanttWidth,
              height: calculatedHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tabela de executores (largura fixa com scroll vertical)
                  SizedBox(
                    width: tableWidth,
                    height: calculatedHeight,
                    child: _buildExecutorTable(),
                  ),
                  // Gantt (largura dinâmica baseada nos dias com scroll vertical)
                  SizedBox(
                    width: totalGanttWidth,
                    height: calculatedHeight,
                    child: _buildGanttView(days, minDayWidth),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCombinedView(List<DateTime> days) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calcular largura disponível para o Gantt (60% da tela)
        final ganttWidth = constraints.maxWidth * 0.6;
        // Calcular largura dos dias para que o período completo caiba sem scroll
        // Subtrair um pouco para margem de segurança
        final calculatedDayWidth = ((ganttWidth - 20) / days.length).clamp(15.0, 100.0);
        
        return Row(
          children: [
            // Tabela de executores (40% da tela)
            Expanded(
              flex: 2,
              child: _buildExecutorTable(),
            ),
            // Gantt (60% da tela)
            Expanded(
              flex: 3,
              child: _buildGanttView(days, calculatedDayWidth),
            ),
          ],
        );
      },
    );
  }


  Widget _buildExecutorTable() {
    if (_executorRows.isEmpty) {
      return const Center(child: Text('Nenhum executor encontrado'));
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          // Espaço equivalente à linha de meses do Gantt (25px)
          Container(
            height: 25,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey[300]!,
                  width: 1,
                ),
              ),
            ),
          ),
          // Cabeçalho fixo - mesma formatação de atividades
          Container(
            height: 50,
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
            child: Row(
              children: [
                _buildHeaderCell('DIVISÃO', 100),
                _buildHeaderCell('EMPRESA', 100),
                _buildHeaderCell('FUNÇÃO', 100),
                _buildHeaderCell('MATRÍCULA', 100),
                _buildHeaderCell('TAREFAS', 80),
                _buildHeaderCell('NOME', 150, textAlign: TextAlign.right),
              ],
            ),
          ),
          // Corpo com scroll sincronizado
          Expanded(
            child: ListView.builder(
              controller: _tableVerticalScrollController,
              itemCount: _executorRows.length,
              itemExtent: _rowHeight,
              itemBuilder: (context, index) {
                final row = _executorRows[index];
                final previousRow = index > 0 ? _executorRows[index - 1] : null;
                
                // Verificar se mudou a função para adicionar separador
                final mudouFuncao = previousRow != null && 
                    (previousRow.executor.funcao ?? 'EXECUTOR') != (row.executor.funcao ?? 'EXECUTOR');
                
                return Stack(
                  children: [
                    // Linha separadora se mudou a função (no topo)
                    if (mudouFuncao)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 2,
                          color: Colors.grey[400],
                        ),
                      ),
                    // Linha da tabela
                    Positioned(
                      top: mudouFuncao ? 2 : 0,
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _buildExecutorTableRow(row, index),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExecutorTableRow(ExecutorTaskRow row, int index) {
    final executor = row.executor;
    // Verificar se este executor tem conflito em qualquer dia do período
    final hasConflict = _hasConflictForExecutor(executor.id);
    
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
        color: hasConflict
            ? Colors.red[100]
            : (row.tasks.isNotEmpty ? Colors.white : Colors.grey[50]),
      ),
      child: Row(
        children: [
          _buildCell(executor.divisao ?? '-', 100, hasConflict: hasConflict),
          _buildCell(executor.empresa ?? '-', 100, hasConflict: hasConflict),
          _buildCell(executor.funcao ?? 'EXECUTOR', 100, hasConflict: hasConflict),
          _buildCell(executor.matricula ?? '-', 100, hasConflict: hasConflict),
          _buildTasksCell(row.tasks.length, row, 80, hasConflict: hasConflict),
          _buildExecutorNameCell(executor, 150, hasConflict: hasConflict),
        ],
      ),
    );
  }

  Widget _buildGanttView(List<DateTime> days, double dayWidth) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = days.length * dayWidth;
        final ganttAvailableWidth = constraints.maxWidth;
        final needsScroll = totalWidth > ganttAvailableWidth;
        
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
          ),
          child: Column(
            children: [
              // Cabeçalho do Gantt (meses mesclados + dias) - mesma formatação de atividades
              Column(
                children: [
                  // Linha de meses mesclados
                  Container(
                    height: 25,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Stack(
                      children: [
                        Align(
                          alignment: Alignment.topLeft,
                          child: SingleChildScrollView(
                            controller: _ganttHorizontalScrollController,
                            scrollDirection: Axis.horizontal,
                            physics: needsScroll 
                              ? const AlwaysScrollableScrollPhysics() 
                              : const NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.zero,
                            child: SizedBox(
                              width: totalWidth,
                              height: 25,
                              child: Stack(
                                alignment: Alignment.topLeft,
                                fit: StackFit.loose,
                                children: [
                                  // Meses mesclados
                                  ..._buildMergedMonthHeaders(days, dayWidth),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Botão para mostrar/ocultar textos dos segmentos
                        Positioned(
                          right: 8,
                          top: 0,
                          bottom: 0,
                          child: Tooltip(
                            message: _showSegmentTexts ? 'Ocultar textos' : 'Mostrar textos',
                            child: IconButton(
                              icon: Icon(
                                _showSegmentTexts ? Icons.text_fields : Icons.text_fields_outlined,
                                size: 18,
                                color: Colors.grey[700],
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 24,
                              ),
                              onPressed: () {
                                setState(() {
                                  _showSegmentTexts = !_showSegmentTexts;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Linha de dias
                  Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: SingleChildScrollView(
                      controller: _ganttHorizontalScrollController,
                      scrollDirection: Axis.horizontal,
                      physics: needsScroll 
                        ? const AlwaysScrollableScrollPhysics() 
                        : const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      child: SizedBox(
                        width: totalWidth,
                        height: 50,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          textDirection: TextDirection.ltr,
                          mainAxisSize: MainAxisSize.min,
                          children: days.map((day) {
                              final isWeekend = day.weekday == 6 || day.weekday == 7;
                              final isFeriado = _isFeriado(day);
                              final hasConflict = _hasAnyExecutorConflictOnDay(day);
                              return Container(
                                width: dayWidth,
                                height: 50,
                                padding: EdgeInsets.zero,
                                margin: EdgeInsets.zero,
                                decoration: BoxDecoration(
                                  color: hasConflict
                                      ? Colors.red[200]
                                      : isFeriado
                                          ? Colors.purple[100]
                                          : (isWeekend
                                              ? Colors.grey[200]
                                              : Colors.white),
                                  border: Border(
                                    right: BorderSide(
                                      color: hasConflict ? Colors.red[400]! : Colors.grey[300]!,
                                      width: hasConflict ? 2 : 1,
                                    ),
                                  ),
                                ),
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 2.0),
                                  child: Tooltip(
                                    message: hasConflict
                                        ? 'Conflito de execução em locais diferentes'
                                        : (isFeriado ? 'Feriado' : ''),
                                    child: Text(
                                      day.day.toString().padLeft(2, '0'),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: hasConflict ? FontWeight.bold : FontWeight.normal,
                                        color: hasConflict
                                            ? Colors.red[900]
                                            : isFeriado
                                                ? Colors.purple[900]
                                                : (isWeekend ? Colors.grey[800] : Colors.black),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Corpo do Gantt com scroll sincronizado
              Expanded(
                child: ListView.builder(
                  controller: _ganttVerticalScrollController,
                  itemCount: _executorRows.length,
                  itemExtent: _rowHeight,
                  itemBuilder: (context, index) {
                    final row = _executorRows[index];
                    final previousRow = index > 0 ? _executorRows[index - 1] : null;
                    
                    // Verificar se mudou a função para adicionar separador
                    final mudouFuncao = previousRow != null && 
                        (previousRow.executor.funcao ?? 'EXECUTOR') != (row.executor.funcao ?? 'EXECUTOR');
                    
                    return Stack(
                      children: [
                        // Linha separadora se mudou a função (no topo)
                        if (mudouFuncao)
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 2,
                              color: Colors.grey[400],
                            ),
                          ),
                        // Linha do Gantt
                        Positioned(
                          top: mudouFuncao ? 2 : 0,
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: _buildGanttRow(row, days, dayWidth, index, needsScroll),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGanttRow(ExecutorTaskRow row, List<DateTime> days, double dayWidth, int index, bool needsScroll) {
    final totalWidth = days.length * dayWidth;
    // Verificar se este executor tem conflito em qualquer dia do período
    final hasConflict = _hasConflictForExecutor(row.executor.id);
    return SizedBox(
      height: _rowHeight,
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
          color: hasConflict
              ? Colors.red[100]
              : (row.tasks.isEmpty ? Colors.grey[50] : Colors.white),
        ),
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            // Sincronizar scroll horizontal de todas as linhas
            if (notification is ScrollUpdateNotification) {
              if (!_isScrolling) {
                _isScrolling = true;
                // O scroll já está sincronizado pelo controller compartilhado
                _isScrolling = false;
              }
            }
            return false;
          },
          child: SingleChildScrollView(
            controller: _ganttHorizontalScrollController,
            scrollDirection: Axis.horizontal,
            physics: needsScroll 
              ? const AlwaysScrollableScrollPhysics() 
              : const NeverScrollableScrollPhysics(),
            child: SizedBox(
              width: totalWidth,
              child: Stack(
                children: [
                  // Grid de dias
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    textDirection: TextDirection.ltr,
                    mainAxisSize: MainAxisSize.min,
                    children: days.map((day) {
                      final isWeekend = day.weekday == 6 || day.weekday == 7;
                      final isFeriado = _isFeriado(day);
                      // Verificar se há conflito neste dia para este executor específico
                      final hasConflict = _hasConflictOnDayForExecutor(day, row.executor.id);
                      return Container(
                        width: dayWidth,
                        height: _rowHeight,
                        decoration: BoxDecoration(
                          color: hasConflict
                              ? Colors.red[200]
                              : isFeriado
                                  ? Colors.purple[100]
                                  : (isWeekend ? Colors.grey[200] : Colors.white),
                          border: Border(
                            right: BorderSide(
                              color: hasConflict ? Colors.red[400]! : Colors.grey[300]!,
                              width: hasConflict ? 2 : 1,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  // Segmentos das tarefas (usar períodos por executor se disponível)
                  ...row.tasks.expand((task) {
                    // Verificar se há períodos específicos para este executor
                    ExecutorPeriod? executorPeriod;
                    for (var ep in task.executorPeriods) {
                      final sameId = ep.executorId == row.executor.id;
                      final sameName = ep.executorId.isEmpty &&
                          ep.executorNome.toLowerCase().trim() ==
                              row.executor.nome.toLowerCase().trim();
                      if (sameId || sameName) {
                        executorPeriod = ep;
                        break;
                      }
                    }
                    
                    // Usar períodos do executor se disponível, senão usar segmentos gerais
                    final segmentsToUse = executorPeriod != null && executorPeriod.periods.isNotEmpty
                        ? executorPeriod.periods
                        : task.ganttSegments;
                    
                    return segmentsToUse.map((segment) {
                      final startDate = DateTime(
                        segment.dataInicio.year,
                        segment.dataInicio.month,
                        segment.dataInicio.day,
                      );
                      final endDate = DateTime(
                        segment.dataFim.year,
                        segment.dataFim.month,
                        segment.dataFim.day,
                      );
                      
                      // Verificar se o segmento está no período
                      final periodEnd = DateTime(widget.endDate.year, widget.endDate.month, widget.endDate.day);
                      final periodStart = DateTime(widget.startDate.year, widget.startDate.month, widget.startDate.day);
                      
                      if (startDate.isAfter(periodEnd) || endDate.isBefore(periodStart)) {
                        return null;
                      }
                      
                      final startOffset = _getDayOffset(startDate, days, dayWidth);
                      final duration = endDate.difference(startDate).inDays + 1;
                      final barWidth = duration * dayWidth;
                      
                      // Verificar se o segmento tem conflito em algum dos seus dias (apenas execução)
                      final isExecutionSegment = (segment.tipoPeriodo.toUpperCase() == 'EXECUCAO');
                      // Avaliar conflito por dia para pintar apenas os dias com conflito
                      List<DateTime> conflictDays = [];
                      var currentDay = startDate;
                      while (currentDay.isBefore(endDate.add(const Duration(days: 1)))) {
                        if (isExecutionSegment && _hasConflictOnDayForExecutor(currentDay, row.executor.id)) {
                          conflictDays.add(currentDay);
                        }
                        currentDay = currentDay.add(const Duration(days: 1));
                      }
                      
                      // Cor base do segmento
                      final segmentColor = _getSegmentColor(segment, task);
                      
                      // Encontrar o índice do segmento
                      final segmentIndex = segmentsToUse.indexOf(segment);
                      
                      return Positioned(
                        left: startOffset,
                        top: 1,
                        bottom: 1,
                        child: _DraggableExecutorSegment(
                          task: task,
                          executorId: row.executor.id,
                          executorPeriod: executorPeriod,
                          segmentIndex: segmentIndex,
                          segment: segment,
                          barWidth: barWidth,
                          dayWidth: dayWidth,
                          days: days,
                          color: segmentColor,
                          conflictDays: conflictDays,
                          taskService: widget.taskService,
                          onTasksUpdated: () async {
                            // Recarregar tarefas do banco para garantir que as alterações sejam refletidas
                            print('🔄 _DraggableExecutorSegment onTasksUpdated: Recarregando tarefas do banco...');
                            try {
                              // Sempre recarregar do banco para garantir que as alterações sejam refletidas
                              final tasks = await widget.taskService.getAllTasks();
                              
                              if (mounted) {
                                setState(() {
                                  _tasks = tasks;
                                });
                                _buildExecutorRows();
                                print('✅ Tarefas recarregadas no TeamScheduleView: ${tasks.length} tarefas');
                                
                                // Notificar callback global (main.dart) para atualizar todas as views
                                if (widget.onTasksUpdated != null) {
                                  print('🔄 Notificando callback global do TeamScheduleView...');
                                  widget.onTasksUpdated!();
                                  print('✅ Callback global do TeamScheduleView chamado');
                                }
                              }
                            } catch (e) {
                              print('⚠️ Erro ao atualizar tarefas após arrasto no TeamScheduleView: $e');
                            }
                          },
                          onDragStart: () {
                            // Callback quando o arrasto começa
                          },
                          onDragEnd: () {
                            // Callback quando o arrasto termina
                          },
                          buildSegmentContent: (segment, task, barWidth) => _buildSegmentContent(segment, task, barWidth),
                        ),
                      );
                    }).whereType<Widget>();
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String text, double width, {TextAlign? textAlign}) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 11,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign ?? TextAlign.left,
        ),
      ),
    );
  }

  Widget _buildCell(String text, double width, {TextAlign? textAlign, bool hasConflict = false}) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: hasConflict ? FontWeight.bold : FontWeight.normal,
            color: hasConflict ? Colors.red[900] : Colors.black,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign ?? TextAlign.left,
        ),
      ),
    );
  }

  Widget _buildTasksCell(int taskCount, ExecutorTaskRow row, double width, {bool hasConflict = false}) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              taskCount.toString(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: hasConflict ? FontWeight.bold : FontWeight.normal,
                color: hasConflict ? Colors.red[900] : Colors.black,
              ),
            ),
            if (taskCount > 0) ...[
              const SizedBox(width: 4),
              Tooltip(
                message: 'Ver atividades',
                child: InkWell(
                  onTap: () => _showExecutorTasks(row.executor, row.tasks),
                  child: Icon(
                    Icons.visibility,
                    size: 16,
                    color: Colors.blue[600],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExecutorNameCell(Executor executor, double width, {bool hasConflict = false}) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                executor.nome,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: hasConflict ? FontWeight.bold : FontWeight.normal,
                  color: hasConflict ? Colors.red[900] : Colors.black,
                ),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Tooltip(
              message: 'Ver dados do executor',
              child: InkWell(
                onTap: () => _showExecutorDetails(executor),
                child: Icon(
                  Icons.visibility,
                  size: 16,
                  color: Colors.blue[600],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExecutorDetails(Executor executor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ExecutorDetailsModal(executor: executor),
    );
  }

  void _shareTaskInfo(BuildContext context, Task task) {
    final buffer = StringBuffer();
    buffer.writeln('📋 Detalhes da Tarefa\n');
    buffer.writeln('📝 Tarefa: ${task.tarefa}');
    if (task.tipo.isNotEmpty) {
      buffer.writeln('🏷️ Tipo: ${task.tipo}');
    }
    if (task.status.isNotEmpty) {
      buffer.writeln('📊 Status: ${task.status}');
    }
    if (task.executor.isNotEmpty) {
      buffer.writeln('👤 Executor: ${task.executor}');
    }
    if (task.coordenador.isNotEmpty) {
      buffer.writeln('👔 Coordenador: ${task.coordenador}');
    }
    if (task.locais.isNotEmpty) {
      buffer.writeln('📍 Local: ${task.locais.join(', ')}');
    }
    if (task.frota.isNotEmpty) {
      buffer.writeln('🚗 Frota: ${task.frota}');
    }
    buffer.writeln('\n📅 Período:');
    buffer.writeln('   Início: ${_formatTaskDate(task.dataInicio)}');
    buffer.writeln('   Fim: ${_formatTaskDate(task.dataFim)}');
    if (task.observacoes != null && task.observacoes!.isNotEmpty) {
      buffer.writeln('\n📄 Observações:');
      buffer.writeln('   ${task.observacoes}');
    }

    Share.share(
      buffer.toString(),
      subject: 'Tarefa - ${task.tarefa}',
    ).catchError((error) {
      // Ignorar erro se o usuário cancelar o compartilhamento
      print('Erro ao compartilhar: $error');
    });
  }

  String _formatTaskDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _showExecutorTasks(Executor executor, List<Task> tasks) {
    // Filtrar tarefas que estão no período
    final tasksNoPeriodo = tasks.where((task) {
      // Verificar se a tarefa tem segmentos no período
      if (task.ganttSegments.isNotEmpty) {
        return task.ganttSegments.any((segment) {
          return (segment.dataInicio.isBefore(widget.endDate.add(const Duration(days: 1))) &&
                  segment.dataFim.isAfter(widget.startDate.subtract(const Duration(days: 1))));
        });
      }
      // Fallback: verificar dataInicio e dataFim
      return (task.dataInicio.isBefore(widget.endDate.add(const Duration(days: 1))) &&
              task.dataFim.isAfter(widget.startDate.subtract(const Duration(days: 1))));
    }).toList();

    if (tasksNoPeriodo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${executor.nome} não possui atividades no período selecionado'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ExecutorTasksModal(
        executor: executor,
        tasks: tasksNoPeriodo,
        startDate: widget.startDate,
        endDate: widget.endDate,
        buildTaskCard: _buildTaskCard,
        getStatusColor: _getStatusColor,
        onEdit: widget.onEdit,
        onDelete: widget.onDelete,
        onDuplicate: widget.onDuplicate,
        onCreateSubtask: widget.onCreateSubtask,
      ),
    );
  }

  Color _getStatusColor(String status) {
    // Buscar status cadastrado
    final statusObj = _statusMap[status];
    if (statusObj != null) {
      return statusObj.color;
    }
    
    // Fallback para cores padrão se não encontrar
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

  Widget _buildTaskCard(Task task, {
    List<String>? imagens,
    Function(Task)? onEdit,
    Function(Task)? onDelete,
    Function(Task)? onDuplicate,
    Function(Task)? onCreateSubtask,
    Map<String, PageController>? imagePageControllers,
    Map<String, int>? currentImageIndex,
    VoidCallback? onImagePageChanged,
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
                // Botão de compartilhar
                IconButton(
                  icon: Icon(
                    Icons.share,
                    size: 18,
                    color: Colors.blue[600],
                  ),
                  onPressed: () => _shareTaskInfo(context, task),
                  tooltip: 'Compartilhar tarefa',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
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
              SizedBox(
                height: 200,
                child: Stack(
                  children: [
                    PageView.builder(
                      controller: imagePageControllers?[task.id],
                      itemCount: imagens.length,
                      onPageChanged: (index) {
                        if (currentImageIndex != null) {
                          currentImageIndex[task.id] = index;
                        }
                        // Notificar mudança de página para atualizar os botões
                        onImagePageChanged?.call();
                      },
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              imagens[index],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                    // Botões de navegação (apenas se houver múltiplas imagens)
                    if (imagens.length > 1) ...[
                      // Botão anterior (esquerda)
                      if ((currentImageIndex?[task.id] ?? 0) > 0)
                        Positioned(
                          left: 8,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: Material(
                              color: Colors.black.withOpacity(0.3),
                              shape: const CircleBorder(),
                              child: InkWell(
                                onTap: () {
                                  final controller = imagePageControllers?[task.id];
                                  if (controller != null && controller.hasClients) {
                                    controller.previousPage(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  }
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.chevron_left,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      // Botão próximo (direita)
                      if ((currentImageIndex?[task.id] ?? 0) < imagens.length - 1)
                        Positioned(
                          right: 8,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: Material(
                              color: Colors.black.withOpacity(0.3),
                              shape: const CircleBorder(),
                              child: InkWell(
                                onTap: () {
                                  final controller = imagePageControllers?[task.id];
                                  if (controller != null && controller.hasClients) {
                                    controller.nextPage(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  }
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.chevron_right,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                          ),
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
                            (index) => GestureDetector(
                              onTap: () {
                                final controller = imagePageControllers?[task.id];
                                if (controller != null && controller.hasClients) {
                                  controller.animateToPage(
                                    index,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                }
                              },
                              child: Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: (currentImageIndex?[task.id] ?? 0) == index
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
                      ),
                    ],
                  ],
                ),
              ),
            ],
            // Informações adicionais
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (task.locais.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        task.locais.join(', '),
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${_formatDate(task.dataInicio)} - ${_formatDate(task.dataFim)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ],
                ),
                // Informações do SAP
                if ((_notasSAPCount[task.id] ?? 0) > 0 ||
                    (_ordensCount[task.id] ?? 0) > 0 ||
                    (_atsCount[task.id] ?? 0) > 0 ||
                    (_sisCount[task.id] ?? 0) > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory_2, size: 16, color: Colors.blue[600]),
                      const SizedBox(width: 4),
                      Text(
                        'SAP: ${(_notasSAPCount[task.id] ?? 0) + (_ordensCount[task.id] ?? 0) + (_atsCount[task.id] ?? 0) + (_sisCount[task.id] ?? 0)}',
                        style: TextStyle(fontSize: 12, color: Colors.blue[700], fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year.toString().substring(2)}';
  }

  List<Widget> _buildMergedMonthHeaders(List<DateTime> days, double dayWidth) {
    final List<Widget> monthHeaders = [];
    DateTime? currentMonthDate;
    int startIndex = 0;
    
    for (int i = 0; i < days.length; i++) {
      final day = days[i];
      
      // Se mudou de mês/ano ou é o primeiro dia
      if (currentMonthDate == null || 
          day.month != currentMonthDate.month || 
          day.year != currentMonthDate.year) {
        // Se havia um mês anterior, criar o header mesclado
        if (currentMonthDate != null) {
          final monthWidth = (i - startIndex) * dayWidth;
          final monthOffset = startIndex * dayWidth;
          
          monthHeaders.add(
            Positioned(
              left: monthOffset,
              top: 0,
              bottom: 0,
              width: monthWidth,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  border: Border(
                    right: BorderSide(
                      color: Colors.grey[300]!,
                      width: 1,
                    ),
                    bottom: BorderSide(
                      color: Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                ),
                child: Center(
                  child: Text(
                    _getMonthFullName(currentMonthDate),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        
        // Iniciar novo mês
        currentMonthDate = DateTime(day.year, day.month);
        startIndex = i;
      }
    }
    
    // Adicionar o último mês
    if (currentMonthDate != null) {
      final monthWidth = (days.length - startIndex) * dayWidth;
      final monthOffset = startIndex * dayWidth;
      
      monthHeaders.add(
        Positioned(
          left: monthOffset,
          top: 0,
          bottom: 0,
          width: monthWidth,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey[300]!,
                  width: 1,
                ),
              ),
            ),
            child: Center(
              child: Text(
                _getMonthFullName(currentMonthDate),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ),
          ),
        ),
      );
    }
    
    return monthHeaders;
  }

  String _getMonthFullName(DateTime date) {
    const months = [
      '',
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];
    
    if (date.month >= 1 && date.month <= 12) {
      return '${months[date.month]} ${date.year}';
    }
    return '';
  }

  // Retorna uma chave de localização (preferencialmente IDs) para comparar conflitos
  String _taskLocationKey(Task task) {
    if (task.localIds.isNotEmpty) {
      return task.localIds.join('|');
    }
    if (task.localId != null && task.localId!.isNotEmpty) {
      return task.localId!;
    }
    if (task.locais.isNotEmpty) {
      return task.locais.join('|');
    }
    return '';
  }

  // Verificar se há conflito em um dia para um executor específico (somente segmentos de EXECUÇÃO)
  bool _hasConflictOnDayForExecutor(DateTime day, String executorId) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    
    // Encontrar a linha do executor
    final row = _executorRows.firstWhere(
      (r) => r.executor.id == executorId,
      orElse: () => ExecutorTaskRow(executor: Executor(id: '', nome: ''), tasks: []),
    );
    
    if (row.tasks.isEmpty) return false;
    
    // Contar quantos LOCAIS DIFERENTES têm segmentos de EXECUÇÃO sobrepondo este dia
    // Não contar conflito se estiverem no mesmo local
    Set<String> locationsWithSegmentsOnDay = {};
    
    for (var task in row.tasks) {
      // Ignorar tarefas canceladas ou reprogramadas
      if (task.status == 'CANC' || task.status == 'REPR') {
        continue;
      }
      bool taskHasExecSegmentOnDay = false;
      bool hasIndividualPeriods = false;
      
      // Priorizar períodos específicos do executor (executorPeriods). Se existir período individual, ignorar o gantt geral.
      for (var executorPeriod in task.executorPeriods) {
        if (executorPeriod.executorId == executorId && executorPeriod.periods.isNotEmpty) {
          hasIndividualPeriods = true;
          for (var period in executorPeriod.periods) {
            if (period.tipoPeriodo.toUpperCase() != 'EXECUCAO') continue;
            final periodStart = period.dataInicio;
            final periodEnd = period.dataFim;
            
            // Verificar se o período sobrepõe o dia
            if (periodStart.isBefore(dayEnd) && periodEnd.isAfter(dayStart)) {
              taskHasExecSegmentOnDay = true;
              break;
            }
          }
          if (taskHasExecSegmentOnDay) break;
        }
      }
      
      // Só usar segmentos gerais da tarefa se não houver períodos individuais para este executor
      if (!hasIndividualPeriods && !taskHasExecSegmentOnDay) {
        for (var segment in task.ganttSegments) {
          if (segment.tipoPeriodo.toUpperCase() != 'EXECUCAO') continue;
          final segmentStart = segment.dataInicio;
          final segmentEnd = segment.dataFim;
          
          // Verificar se o segmento sobrepõe o dia
          if (segmentStart.isBefore(dayEnd) && segmentEnd.isAfter(dayStart)) {
            taskHasExecSegmentOnDay = true;
            break;
          }
        }
      }
      
      // Adicionar o local ao conjunto se tem algum segmento/período de EXECUÇÃO no dia
      // Uma tarefa só conta uma vez, mesmo que tenha múltiplos segmentos/períodos
      if (taskHasExecSegmentOnDay) {
        final locKey = _taskLocationKey(task);
        // Se não houver local, usar o próprio id da tarefa para garantir unicidade
        locationsWithSegmentsOnDay.add(locKey.isNotEmpty ? locKey : 'task-${task.id}');
      }
    }
    
    // Conflito só existe se há mais de um LOCAL diferente sobrepondo o dia
    return locationsWithSegmentsOnDay.length > 1;
  }

  // Verificar se qualquer executor possui conflito no dia (para o cabeçalho)
  bool _hasAnyExecutorConflictOnDay(DateTime day) {
    for (var row in _executorRows) {
      if (_hasConflictOnDayForExecutor(day, row.executor.id)) {
        return true;
      }
    }
    return false;
  }

  // Verificar se um executor tem conflito em qualquer dia do período
  bool _hasConflictForExecutor(String executorId) {
    final days = _getDaysInPeriod();
    for (var day in days) {
      if (_hasConflictOnDayForExecutor(day, executorId)) {
        return true;
      }
    }
    return false;
  }

}

// Widget para barras arrastáveis no TeamScheduleView (suporta ExecutorPeriods)
class _DraggableExecutorSegment extends StatefulWidget {
  final Task task;
  final String executorId;
  final ExecutorPeriod? executorPeriod;
  final int segmentIndex;
  final GanttSegment segment;
  final double barWidth;
  final double dayWidth;
  final List<DateTime> days;
  final Color color;
  final List<DateTime>? conflictDays;
  final TaskService? taskService;
  final Function()? onTasksUpdated;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;
  final Widget Function(GanttSegment segment, Task task, double barWidth) buildSegmentContent;

  const _DraggableExecutorSegment({
    required this.task,
    required this.executorId,
    this.executorPeriod,
    required this.segmentIndex,
    required this.segment,
    required this.barWidth,
    required this.dayWidth,
    required this.days,
    required this.color,
    this.conflictDays,
    this.taskService,
    this.onTasksUpdated,
    this.onDragStart,
    this.onDragEnd,
    required this.buildSegmentContent,
  });

  @override
  State<_DraggableExecutorSegment> createState() => _DraggableExecutorSegmentState();
}

enum _ExecutorDragMode { move, resizeStart, resizeEnd }

class _DraggableExecutorSegmentState extends State<_DraggableExecutorSegment> {
  double? _dragStartX;
  DateTime? _originalStartDate;
  DateTime? _originalEndDate;
  DateTime? _currentStartDate;
  DateTime? _currentEndDate;
  bool _isDragging = false;
  _ExecutorDragMode? _dragMode;
  static const double _resizeHandleWidth = 8.0;
  int _lastAppliedDaysDelta = 0; // Rastrear o último delta aplicado para evitar saltos

  @override
  void didUpdateWidget(_DraggableExecutorSegment oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging && 
        (oldWidget.segment.dataInicio != widget.segment.dataInicio ||
         oldWidget.segment.dataFim != widget.segment.dataFim)) {
      setState(() {
        _currentStartDate = null;
        _currentEndDate = null;
      });
    }
  }

  _ExecutorDragMode _getDragMode(double x) {
    if (x < _resizeHandleWidth) {
      return _ExecutorDragMode.resizeStart;
    } else if (x > widget.barWidth - _resizeHandleWidth) {
      return _ExecutorDragMode.resizeEnd;
    } else {
      return _ExecutorDragMode.move;
    }
  }

  void _onPanStart(DragStartDetails details) {
    final dragMode = _getDragMode(details.localPosition.dx);
    setState(() {
      _dragStartX = details.localPosition.dx;
      _originalStartDate = widget.segment.dataInicio;
      _originalEndDate = widget.segment.dataFim;
      _isDragging = true;
      _dragMode = dragMode;
      _lastAppliedDaysDelta = 0; // Resetar o último delta aplicado
    });
    widget.onDragStart?.call();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_dragStartX == null || _dragMode == null || widget.taskService == null) return;

    final deltaX = details.localPosition.dx - _dragStartX!;
    final daysDelta = deltaX / widget.dayWidth;
    
    // Calcular o delta total arredondado
    final totalDaysDelta = daysDelta.round();
    
    // Calcular o delta incremental desde o último aplicado
    final incrementalDelta = totalDaysDelta - _lastAppliedDaysDelta;
    
    int roundedDaysDelta;
    
    // CASO ESPECIAL: Verificar PRIMEIRO se está tentando voltar para a posição original
    // Isso deve ser verificado ANTES de qualquer threshold para não ser bloqueado
    // Detecta quando está próximo da posição original (daysDelta próximo de 0) 
    // e há um delta aplicado anteriormente na direção oposta
    // Usar margem maior (0.5 dias) para ser mais permissivo ao detectar retorno à posição original
    final isReturningToOriginal = _lastAppliedDaysDelta != 0 &&
                                   daysDelta.abs() < 0.5 &&
                                   ((daysDelta <= 0 && _lastAppliedDaysDelta > 0) || 
                                    (daysDelta >= 0 && _lastAppliedDaysDelta < 0));
    
    if (isReturningToOriginal) {
      // Permitir voltar completamente para a posição original
      roundedDaysDelta = -_lastAppliedDaysDelta;
      _lastAppliedDaysDelta = 0;
      print('🔄 Retornando para posição original: delta aplicado = $roundedDaysDelta, daysDelta = $daysDelta');
    } else {
      // Para movimentação, só processar se houver mudança de pelo menos meio dia
      if (_dragMode == _ExecutorDragMode.move && daysDelta.abs() < 0.5) return;
      
      // Para redimensionamento, ser mais sensível (>= 0.3 dias)
      // Para movimentação, ser mais restritivo (>= 0.5 dias)
      final threshold = (_dragMode == _ExecutorDragMode.resizeStart || _dragMode == _ExecutorDragMode.resizeEnd) 
          ? 0.3 
          : 0.5;
      
      // Verificar se o movimento total é significativo
      if (daysDelta.abs() < threshold) {
        return; // Movimento muito pequeno, não processar
      }
      
      if (incrementalDelta.abs() >= 1) {
        // Aplicar apenas 1 dia por vez (na direção do movimento)
        roundedDaysDelta = incrementalDelta > 0 ? 1 : -1;
        _lastAppliedDaysDelta = totalDaysDelta; // Atualizar o último delta aplicado
      } else {
        // Se o movimento incremental for menor que 1 dia, não aplicar ainda
        return; // Ainda não chegou a 1 dia completo desde o último movimento
      }
    }
    
    // Se ainda não houver mudança, não processar
    if (roundedDaysDelta == 0) return;

    DateTime? newStartDate = _originalStartDate;
    DateTime? newEndDate = _originalEndDate;

    switch (_dragMode!) {
      case _ExecutorDragMode.move:
        // Mover: ambas as datas mudam, mas mantendo a duração (tamanho) constante
        newStartDate = _originalStartDate!.add(Duration(days: roundedDaysDelta));
        // Calcular a duração original e aplicar à nova data de início
        final duration = _originalEndDate!.difference(_originalStartDate!);
        newEndDate = newStartDate.add(duration);
        if (newStartDate.isBefore(widget.days.first) ||
            newEndDate.isAfter(widget.days.last.add(const Duration(days: 1)))) {
          return;
        }
        print('🔄 MOVE: ${_originalStartDate} -> ${newStartDate}, ${_originalEndDate} -> ${newEndDate} (duração mantida: ${duration.inDays} dias)');
        break;
      case _ExecutorDragMode.resizeStart:
        // Redimensionar pela borda esquerda: APENAS a data de início muda
        newStartDate = _originalStartDate!.add(Duration(days: roundedDaysDelta));
        // Permitir retrair até a data de fim, mas não além (manter pelo menos 1 dia)
        if (newStartDate.isAfter(_originalEndDate!)) {
          newStartDate = _originalEndDate!.subtract(const Duration(days: 1));
        }
        // Permitir expandir até o primeiro dia disponível
        if (newStartDate.isBefore(widget.days.first)) {
          newStartDate = widget.days.first;
        }
        // CRÍTICO: Não alterar newEndDate ao redimensionar pela esquerda
        newEndDate = _originalEndDate;
        print('🔧 RESIZE_START: início ${_originalStartDate} -> ${newStartDate}, fim mantido: ${_originalEndDate}');
        break;
      case _ExecutorDragMode.resizeEnd:
        // Redimensionar pela borda direita: APENAS a data de fim muda
        newEndDate = _originalEndDate!.add(Duration(days: roundedDaysDelta));
        // Permitir retrair até a data de início, mas não antes (manter pelo menos 1 dia)
        if (newEndDate.isBefore(_originalStartDate!)) {
          newEndDate = _originalStartDate!.add(const Duration(days: 1));
        }
        // Permitir expandir até o último dia disponível
        final maxDate = widget.days.last.add(const Duration(days: 1));
        if (newEndDate.isAfter(maxDate)) {
          newEndDate = maxDate;
        }
        // CRÍTICO: Não alterar newStartDate ao redimensionar pela direita
        newStartDate = _originalStartDate;
        print('🔧 RESIZE_END: início mantido: ${_originalStartDate}, fim ${_originalEndDate} -> ${newEndDate}');
        break;
    }

    setState(() {
      _currentStartDate = newStartDate;
      _currentEndDate = newEndDate;
    });
  }

  void _onPanEnd(DragEndDetails details) async {
    if (_currentStartDate != null && _currentEndDate != null && widget.taskService != null) {
      print('💾 _onPanEnd: Salvando alterações...');
      print('   - ExecutorPeriod: ${widget.executorPeriod != null}');
      print('   - ExecutorId: ${widget.executorId}');
      print('   - SegmentIndex: ${widget.segmentIndex}');
      print('   - Data início: ${_currentStartDate}');
      print('   - Data fim: ${_currentEndDate}');
      
      Task updatedTask;
      
      if (widget.executorPeriod != null) {
        // Atualizar ExecutorPeriod
        print('📝 Atualizando ExecutorPeriod para executor ${widget.executorId}');
        final updatedPeriods = List<GanttSegment>.from(widget.executorPeriod!.periods);
        print('   - Períodos antes: ${updatedPeriods.length}');
        print('   - Segmento ${widget.segmentIndex} antes: ${updatedPeriods[widget.segmentIndex].dataInicio} até ${updatedPeriods[widget.segmentIndex].dataFim}');
        
        updatedPeriods[widget.segmentIndex] = GanttSegment(
          label: widget.segment.label,
          tipo: widget.segment.tipo,
          tipoPeriodo: widget.segment.tipoPeriodo,
          dataInicio: _currentStartDate!,
          dataFim: _currentEndDate!,
        );
        
        print('   - Segmento ${widget.segmentIndex} depois: ${updatedPeriods[widget.segmentIndex].dataInicio} até ${updatedPeriods[widget.segmentIndex].dataFim}');
        
        final updatedExecutorPeriods = List<ExecutorPeriod>.from(widget.task.executorPeriods);
        final executorPeriodIndex = updatedExecutorPeriods.indexWhere(
          (ep) => ep.executorId == widget.executorId,
        );
        
        print('   - ExecutorPeriodIndex encontrado: $executorPeriodIndex');
        
        if (executorPeriodIndex >= 0) {
          print('   - Atualizando ExecutorPeriod existente no índice $executorPeriodIndex');
          updatedExecutorPeriods[executorPeriodIndex] = ExecutorPeriod(
            executorId: widget.executorPeriod!.executorId,
            executorNome: widget.executorPeriod!.executorNome,
            periods: updatedPeriods,
          );
          print('   - ExecutorPeriod atualizado com ${updatedPeriods.length} períodos');
          print('   - Períodos atualizados:');
          for (var i = 0; i < updatedPeriods.length; i++) {
            print('     [$i] ${updatedPeriods[i].dataInicio.toString().substring(0, 10)} até ${updatedPeriods[i].dataFim.toString().substring(0, 10)}');
          }
        } else {
          print('   ⚠️ ExecutorPeriod não encontrado! Criando novo...');
          print('   - ExecutorId procurado: ${widget.executorId}');
          print('   - ExecutorPeriods existentes: ${updatedExecutorPeriods.length}');
          for (var i = 0; i < updatedExecutorPeriods.length; i++) {
            print('     [$i] executorId: ${updatedExecutorPeriods[i].executorId}');
          }
          // Se não encontrou, criar um novo ExecutorPeriod
          updatedExecutorPeriods.add(ExecutorPeriod(
            executorId: widget.executorId,
            executorNome: widget.executorPeriod!.executorNome,
            periods: updatedPeriods,
          ));
          print('   - Novo ExecutorPeriod adicionado com ${updatedPeriods.length} períodos');
        }
        
        updatedTask = widget.task.copyWith(
          executorPeriods: updatedExecutorPeriods,
          dataAtualizacao: DateTime.now(),
        );
        
        print('   ✅ Tarefa atualizada com ${updatedExecutorPeriods.length} ExecutorPeriods');
      } else {
        // Atualizar segmentos gerais da tarefa
        print('📝 Atualizando segmentos gerais da tarefa');
        final updatedSegments = List<GanttSegment>.from(widget.task.ganttSegments);
        updatedSegments[widget.segmentIndex] = GanttSegment(
          label: widget.segment.label,
          tipo: widget.segment.tipo,
          tipoPeriodo: widget.segment.tipoPeriodo,
          dataInicio: _currentStartDate!,
          dataFim: _currentEndDate!,
        );
        
        updatedTask = widget.task.copyWith(
          ganttSegments: updatedSegments,
          dataInicio: updatedSegments
              .map((s) => s.dataInicio)
              .reduce((a, b) => a.isBefore(b) ? a : b),
          dataFim: updatedSegments
              .map((s) => s.dataFim)
              .reduce((a, b) => a.isAfter(b) ? a : b),
          dataAtualizacao: DateTime.now(),
        );
      }

      print('💾 Chamando updateTask...');
      await widget.taskService!.updateTask(widget.task.id, updatedTask);
      print('✅ updateTask concluído');
      
      // Notificar callback local (atualiza apenas o TeamScheduleView)
      final localOnTasksUpdated = widget.onTasksUpdated;
      if (localOnTasksUpdated != null) {
        print('🔄 Chamando onTasksUpdated local do TeamScheduleView...');
        localOnTasksUpdated();
        print('✅ onTasksUpdated local do TeamScheduleView concluído');
      }
      
      // Notificar callback global (atualiza todas as views no main.dart)
      // Isso é feito através do callback do _DraggableExecutorSegment que já chama o onTasksUpdated
      // que por sua vez recarrega as tarefas do banco
    } else {
      print('⚠️ _onPanEnd: Não salvou - dados incompletos');
      print('   - _currentStartDate: ${_currentStartDate}');
      print('   - _currentEndDate: ${_currentEndDate}');
      print('   - taskService: ${widget.taskService != null}');
    }

    setState(() {
      _dragStartX = null;
      _originalStartDate = null;
      _originalEndDate = null;
      _isDragging = false;
      _dragMode = null;
      _lastAppliedDaysDelta = 0; // Resetar o último delta aplicado
    });
    widget.onDragEnd?.call();
  }

  // Calcular largura da barra usando datas temporárias durante arrasto ou após salvar
  double _getCurrentBarWidth() {
    // Usar datas temporárias se existirem (durante arrasto ou após salvar, antes da atualização)
    if (_currentStartDate != null && _currentEndDate != null) {
      final duration = _currentEndDate!.difference(_currentStartDate!).inDays + 1;
      return duration * widget.dayWidth;
    }
    return widget.barWidth;
  }

  // Calcular offset para ajustar posição durante arrasto ou após salvar
  double _getCurrentOffset() {
    // Usar datas temporárias se existirem (durante arrasto ou após salvar, antes da atualização)
    if (_currentStartDate != null) {
      // Calcular posição da nova data de início
      final newStartOffset = _getDayOffset(_currentStartDate!, widget.days, widget.dayWidth);
      // Calcular posição da data de início original do widget
      final originalStartOffset = _getDayOffset(widget.segment.dataInicio, widget.days, widget.dayWidth);
      // Retornar diferença
      return newStartOffset - originalStartOffset;
    }
    return 0.0;
  }

  double _getDayOffset(DateTime date, List<DateTime> days, double dayWidth) {
    // Normalizar a data para comparar apenas ano, mês e dia
    final normalizedDate = DateTime(date.year, date.month, date.day);
    
    for (int i = 0; i < days.length; i++) {
      final day = days[i];
      final normalizedDay = DateTime(day.year, day.month, day.day);
      
      if (normalizedDay.year == normalizedDate.year &&
          normalizedDay.month == normalizedDate.month &&
          normalizedDay.day == normalizedDate.day) {
        return i * dayWidth;
      }
    }
    
    // Se não encontrou, retornar 0
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final currentOffset = _getCurrentOffset();
    final currentBarWidth = _getCurrentBarWidth();
    final effectiveStartDate = _currentStartDate ?? widget.segment.dataInicio;
    final effectiveEndDate = _currentEndDate ?? widget.segment.dataFim;
    
    // Determinar o cursor e estilo baseado no modo de arrasto
    final isResizing = _dragMode == _ExecutorDragMode.resizeStart || _dragMode == _ExecutorDragMode.resizeEnd;

    // Usar Transform.translate para ajustar a posição durante o arrasto
    // O Positioned já posiciona o widget na posição original, então só precisamos
    // ajustar a diferença durante o arrasto
    return Transform.translate(
      offset: Offset(currentOffset, 0),
      child: Stack(
        children: [
          // Barra principal (área central para movimento)
          MouseRegion(
            cursor: _isDragging 
                ? (isResizing ? SystemMouseCursors.resizeLeftRight : SystemMouseCursors.move)
                : SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.deferToChild, // Não interceptar eventos das bordas
              onPanStart: (details) {
                // Só definir como move se realmente estiver na área central (não nas bordas)
                final barWidth = currentBarWidth;
                final resizeHandleWidth = 8.0;
                final x = details.localPosition.dx;
                
                // Se não estiver nas bordas, é movimento
                if (x > resizeHandleWidth && x < barWidth - resizeHandleWidth) {
                  _dragMode = _ExecutorDragMode.move;
                  print('🔧 Área central clicada - MOVE');
                  _onPanStart(details);
                }
                // Se estiver nas bordas, deixar as áreas de redimensionamento tratarem
              },
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              child: SizedBox(
                width: currentBarWidth,
                child: ClipRect(
                  child: Container(
                    decoration: BoxDecoration(
                      // Mudar cor e adicionar borda durante o arrasto para feedback visual claro
                      color: _isDragging 
                          ? widget.color.withOpacity(0.7)
                          : widget.color,
                      borderRadius: BorderRadius.circular(3),
                      border: _isDragging
                          ? Border.all(
                              color: isResizing ? Colors.orange : Colors.blue,
                              width: 2,
                            )
                          : null,
                      boxShadow: _isDragging
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Stack(
                      children: [
                        // Pintura por dia para destacar conflitos apenas nos dias envolvidos
                        Row(
                          children: widget.days.map((day) {
                            final dayStart = DateTime(day.year, day.month, day.day);
                            final dayEnd = dayStart.add(const Duration(days: 1));
                            final coversDay = (effectiveStartDate.isBefore(dayEnd) && effectiveEndDate.isAfter(dayStart));
                            if (!coversDay) {
                              return const SizedBox.shrink();
                            }
                            final isConflictDay = widget.conflictDays?.any((d) =>
                                    d.year == day.year && d.month == day.month && d.day == day.day) ??
                                false;
                            return Expanded(
                              child: Container(
                                height: double.infinity,
                                decoration: BoxDecoration(
                                  color: isConflictDay ? Colors.red[600]! : widget.color,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        // Conteúdo do segmento (texto)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 0),
                            child: widget.buildSegmentContent(
                              GanttSegment(
                                dataInicio: effectiveStartDate,
                                dataFim: effectiveEndDate,
                                label: widget.segment.label,
                                tipo: widget.segment.tipo,
                                tipoPeriodo: widget.segment.tipoPeriodo,
                              ),
                              widget.task,
                              currentBarWidth,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Área de redimensionamento esquerda (início) - invisível mas clicável
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 8, // Aumentada para melhor detecção
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeLeftRight,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque, // Interceptar eventos primeiro
                onPanStart: (details) {
                  _dragMode = _ExecutorDragMode.resizeStart;
                  print('🔧 Área esquerda clicada - RESIZE_START');
                  _onPanStart(details);
                },
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            ),
          ),
          // Área de redimensionamento direita (fim) - invisível mas clicável
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 8, // Aumentada para melhor detecção
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeLeftRight,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque, // Interceptar eventos primeiro
                onPanStart: (details) {
                  _dragMode = _ExecutorDragMode.resizeEnd;
                  print('🔧 Área direita clicada - RESIZE_END');
                  _onPanStart(details);
                },
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            ),
          ),
          // Indicadores visuais nas bordas (quando não está arrastando)
          if (!_isDragging) ...[
            // Indicador esquerdo
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 2,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.4),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(3),
                    bottomLeft: Radius.circular(3),
                  ),
                ),
              ),
            ),
            // Indicador direito
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 2,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.4),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(3),
                    bottomRight: Radius.circular(3),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Widget modal para exibir tarefas do executor no período
class _ExecutorTasksModal extends StatefulWidget {
  final Executor executor;
  final List<Task> tasks;
  final DateTime startDate;
  final DateTime endDate;
  final Widget Function(Task, {List<String>? imagens, Function(Task)? onEdit, Function(Task)? onDelete, Function(Task)? onDuplicate, Function(Task)? onCreateSubtask, Map<String, PageController>? imagePageControllers, Map<String, int>? currentImageIndex, VoidCallback? onImagePageChanged}) buildTaskCard;
  final Color Function(String) getStatusColor;
  final Function(Task)? onEdit;
  final Function(Task)? onDelete;
  final Function(Task)? onDuplicate;
  final Function(Task)? onCreateSubtask;

  const _ExecutorTasksModal({
    required this.executor,
    required this.tasks,
    required this.startDate,
    required this.endDate,
    required this.buildTaskCard,
    required this.getStatusColor,
    this.onEdit,
    this.onDelete,
    this.onDuplicate,
    this.onCreateSubtask,
  });

  @override
  State<_ExecutorTasksModal> createState() => _ExecutorTasksModalState();
}

class _ExecutorTasksModalState extends State<_ExecutorTasksModal> {
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

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year.toString().substring(2)}';
  }

  List<GanttSegment> _executorExecPeriods(Task task) {
    for (var executorPeriod in task.executorPeriods) {
      if (executorPeriod.executorId == widget.executor.id) {
        return executorPeriod.periods
            .where((p) => p.tipoPeriodo.toUpperCase() == 'EXECUCAO')
            .toList();
      }
    }
    return [];
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Atividades de ${widget.executor.nome}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Período: ${_formatDate(widget.startDate)} a ${_formatDate(widget.endDate)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
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
          // Ordenar tarefas por início/fim antes de renderizar
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
                  final sortedTasks = [...widget.tasks]..sort((a, b) {
                    final cmpInicio = a.dataInicio.compareTo(b.dataInicio);
                    if (cmpInicio != 0) return cmpInicio;
                    return a.dataFim.compareTo(b.dataFim);
                  });
                  final task = sortedTasks[index];
                  final imagens = _imagensPorTarefa[task.id] ?? [];
                  final execPeriods = _executorExecPeriods(task);
                  final hasExecPeriods = execPeriods.isNotEmpty;
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Período da tarefa', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[800])),
                                const SizedBox(height: 4),
                                Text('${_formatDate(task.dataInicio)} - ${_formatDate(task.dataFim)}'),
                                if (hasExecPeriods) ...[
                                  const SizedBox(height: 10),
                                  Text('Período(s) do executor', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[800])),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: execPeriods
                                        .map((p) => Chip(
                                              label: Text('${_formatDate(p.dataInicio)} - ${_formatDate(p.dataFim)}'),
                                              backgroundColor: Colors.blue[50],
                                            ))
                                        .toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        widget.buildTaskCard(
                          task,
                          imagens: imagens,
                          onEdit: widget.onEdit,
                          onDelete: widget.onDelete,
                          onDuplicate: widget.onDuplicate,
                          onCreateSubtask: widget.onCreateSubtask,
                          imagePageControllers: _imagePageControllers,
                          currentImageIndex: _currentImageIndex,
                          onImagePageChanged: () {
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                child: (() {
                  final sortedTasks = [...widget.tasks]..sort((a, b) {
                    final cmpInicio = a.dataInicio.compareTo(b.dataInicio);
                    if (cmpInicio != 0) return cmpInicio;
                    return a.dataFim.compareTo(b.dataFim);
                  });
                  final task = sortedTasks.first;
                  final execPeriods = _executorExecPeriods(task);
                  final hasExecPeriods = execPeriods.isNotEmpty;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Período da tarefa', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[800])),
                              const SizedBox(height: 4),
                              Text('${_formatDate(task.dataInicio)} - ${_formatDate(task.dataFim)}'),
                              if (hasExecPeriods) ...[
                                const SizedBox(height: 10),
                                Text('Período(s) do executor', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[800])),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: execPeriods
                                      .map((p) => Chip(
                                            label: Text('${_formatDate(p.dataInicio)} - ${_formatDate(p.dataFim)}'),
                                            backgroundColor: Colors.blue[50],
                                          ))
                                      .toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      widget.buildTaskCard(
                        task,
                        imagens: _imagensPorTarefa[task.id] ?? [],
                        onEdit: widget.onEdit,
                        onDelete: widget.onDelete,
                        onDuplicate: widget.onDuplicate,
                        onCreateSubtask: widget.onCreateSubtask,
                        imagePageControllers: _imagePageControllers,
                        currentImageIndex: _currentImageIndex,
                        onImagePageChanged: () {
                          setState(() {});
                        },
                      ),
                    ],
                  );
                })(),
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

// Widget modal para exibir dados do executor
class _ExecutorDetailsModal extends StatelessWidget {
  final Executor executor;

  const _ExecutorDetailsModal({
    required this.executor,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.9,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header com avatar e nome
            Row(
              children: [
                Container(
                  width: isMobile ? 50 : 60,
                  height: isMobile ? 50 : 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.blue[400]!,
                        Colors.blue[600]!,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      executor.nome.isNotEmpty
                          ? executor.nome[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: isMobile ? 20 : 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        executor.nomeCompleto ?? executor.nome,
                        style: TextStyle(
                          fontSize: isMobile ? 16 : 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (executor.funcao != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Text(
                            executor.funcao!,
                            style: TextStyle(
                              fontSize: isMobile ? 11 : 12,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Botão de compartilhar
                IconButton(
                  icon: Icon(
                    Icons.share,
                    size: isMobile ? 20 : 22,
                    color: Colors.blue[600],
                  ),
                  onPressed: () => _shareExecutorInfo(context),
                  tooltip: 'Compartilhar informações',
                ),
              ],
            ),
            SizedBox(height: isMobile ? 12 : 16),
            // Cards de informações
            _buildInfoSection(
              context,
              'Informações Pessoais',
              [
                _buildInfoItem(
                  context,
                  Icons.badge,
                  'Matrícula',
                  executor.matricula ?? 'Não informado',
                  isMobile,
                  showCopyButton: true,
                ),
                _buildInfoItem(
                  context,
                  Icons.person,
                  'Login',
                  executor.login ?? 'Não informado',
                  isMobile,
                  showCopyButton: true,
                ),
                _buildInfoItem(
                  context,
                  Icons.phone,
                  'Telefone',
                  executor.telefone ?? 'Não informado',
                  isMobile,
                  showCopyButton: true,
                ),
                _buildInfoItem(
                  context,
                  Icons.phone_in_talk,
                  'Ramal',
                  executor.ramal ?? 'Não informado',
                  isMobile,
                  showCopyButton: true,
                ),
              ],
              isMobile,
            ),
            SizedBox(height: isMobile ? 10 : 12),
            _buildInfoSection(
              context,
              'Organizacional',
              [
                _buildInfoItem(
                  context,
                  Icons.business,
                  'Empresa',
                  executor.empresa ?? 'Não informado',
                  isMobile,
                ),
                _buildInfoItem(
                  context,
                  Icons.account_tree,
                  'Divisão',
                  executor.divisao ?? 'Não informado',
                  isMobile,
                ),
                if (executor.segmentos.isNotEmpty)
                  _buildInfoItem(
                    context,
                    Icons.category,
                    'Segmentos',
                    executor.segmentos.join(', '),
                    isMobile,
                  ),
              ],
              isMobile,
            ),
            SizedBox(height: isMobile ? 10 : 12),
            _buildInfoSection(
              context,
              'Status',
              [
                _buildInfoItem(
                  context,
                  executor.ativo ? Icons.check_circle : Icons.cancel,
                  'Status',
                  executor.ativo ? 'Ativo' : 'Inativo',
                  isMobile,
                  valueColor: executor.ativo ? Colors.green : Colors.red,
                ),
                if (executor.createdAt != null)
                  _buildInfoItem(
                    context,
                    Icons.calendar_today,
                    'Cadastrado em',
                    _formatDate(executor.createdAt!),
                    isMobile,
                  ),
                if (executor.updatedAt != null)
                  _buildInfoItem(
                    context,
                    Icons.update,
                    'Atualizado em',
                    _formatDate(executor.updatedAt!),
                    isMobile,
                  ),
              ],
              isMobile,
            ),
            SizedBox(height: isMobile ? 12 : 16),
            // Botão de fechar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  elevation: 2,
                ),
                child: Text(
                  'Fechar',
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(
    BuildContext context,
    String title,
    List<Widget> items,
    bool isMobile,
  ) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: isMobile ? 8 : 10),
          ...items,
        ],
      ),
    );
  }

  Widget _buildInfoItem(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    bool isMobile, {
    Color? valueColor,
    bool showCopyButton = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isMobile ? 8 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 6 : 7),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              size: isMobile ? 16 : 18,
              color: Colors.blue[700],
            ),
          ),
          SizedBox(width: isMobile ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: isMobile ? 2 : 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isMobile ? 13 : 14,
                    color: valueColor ?? Colors.grey[800],
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (showCopyButton && value != 'Não informado')
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: InkWell(
                onTap: () => _copyToClipboard(context, value, label),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.copy,
                    size: isMobile ? 16 : 18,
                    color: Colors.blue[600],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copiado para a área de transferência'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareExecutorInfo(BuildContext context) {
    final buffer = StringBuffer();
    buffer.writeln('📋 Dados do Executor\n');
    buffer.writeln('👤 Nome: ${executor.nomeCompleto ?? executor.nome}');
    if (executor.funcao != null) {
      buffer.writeln('💼 Função: ${executor.funcao}');
    }
    buffer.writeln('\n📝 Informações Pessoais:');
    if (executor.matricula != null && executor.matricula!.isNotEmpty) {
      buffer.writeln('• Matrícula: ${executor.matricula}');
    }
    if (executor.login != null && executor.login!.isNotEmpty) {
      buffer.writeln('• Login: ${executor.login}');
    }
    if (executor.telefone != null && executor.telefone!.isNotEmpty) {
      buffer.writeln('• Telefone: ${executor.telefone}');
    }
    if (executor.ramal != null && executor.ramal!.isNotEmpty) {
      buffer.writeln('• Ramal: ${executor.ramal}');
    }
    buffer.writeln('\n🏢 Organizacional:');
    if (executor.empresa != null && executor.empresa!.isNotEmpty) {
      buffer.writeln('• Empresa: ${executor.empresa}');
    }
    if (executor.divisao != null && executor.divisao!.isNotEmpty) {
      buffer.writeln('• Divisão: ${executor.divisao}');
    }
    if (executor.segmentos.isNotEmpty) {
      buffer.writeln('• Segmentos: ${executor.segmentos.join(', ')}');
    }
    buffer.writeln('\n📊 Status: ${executor.ativo ? 'Ativo' : 'Inativo'}');

    Share.share(
      buffer.toString(),
      subject: 'Dados do Executor - ${executor.nome}',
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
