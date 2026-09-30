// activity_gantt_view.dart
//
// Widget que combina a tabela de atividades e o gráfico Gantt em um único
// ListView.builder vertical. Cada linha renderiza a célula da tabela (esquerda)
// e a barra/área do Gantt (direita) juntas, eliminando completamente a necessidade
// de sincronização de scroll entre dois widgets independentes.
//
// Estrutura:
//   Column
//   ├── Row (cabeçalho fixo)
//   │   ├── TableHeader (largura fixa, scroll horizontal interno)
//   │   └── GanttHeader (mês + dias, scroll horizontal compartilhado com linhas)
//   └── Expanded
//       └── ListView.builder (UM único ScrollController vertical)
//           └── Linha i → Row
//               ├── TableRowWidget (tabela, sem scroll horizontal)
//               └── GanttRowWidget (Gantt, scroll horizontal via _ganttHorizController)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../utils/clipboard_helper.dart';
import '../models/task.dart';
import '../models/status.dart';
import 'package:task2026/widgets/common/taskflow_calendar_marker_tooltip.dart';
import '../models/feriado.dart';
import '../services/performance_monitor.dart';
import '../models/tipo_atividade.dart';
import '../models/grupo_chat.dart';
import '../models/nota_sap.dart';
import '../models/ordem.dart';
import '../models/at.dart';
import '../models/si.dart';
import '../services/task_service.dart';
import '../services/status_service.dart';
import '../services/chat_service.dart';
import '../services/anexo_service.dart';
import '../services/nota_sap_service.dart';
import '../services/ordem_service.dart';
import '../services/at_service.dart';
import '../services/si_service.dart';
import '../services/frota_service.dart';
import '../services/feriado_service.dart';
import '../services/tipo_atividade_service.dart';
import '../services/conflict_service.dart';
import '../services/sync_service.dart';
import '../utils/responsive.dart';
import '../utils/conflict_detection.dart';
import '../features/warnings/warnings.dart';
import 'gantt_chart.dart' show GanttScale, GanttPeriod;
import 'gantt_segment_widget.dart';
import 'chat_view.dart';
import '../design_system/taskflow_design_system.dart';
import '../models/task_table_column.dart';
import 'common/task_table_column_picker_dialog.dart';

/// Widget unificado: tabela de atividades + Gantt numa única rolagem vertical.
class ActivityGanttView extends StatefulWidget {
  final List<Task> tasks;
  final DateTime startDate;
  final DateTime endDate;
  final GanttScale scale;
  final ValueChanged<GanttScale>? onScaleChanged;
  final TaskService? taskService;
  final ConflictService? conflictService;
  final List<Task>? tasksForConflictDetection;
  final int tasksVersion; // Versão para detectar atualizações externas
  final bool? allSubtasksExpanded;
  final VoidCallback? onToggleAllSubtasks;
  final Set<String>? expandedTasks;
  final Function(String, bool)? onTaskExpanded;
  final String? sortColumn;
  final Function(Task)? getSortValue;
  final Function(Task)? onTaskSelected;
  final void Function(Task, {String? executorIdToEdit})? onEdit;
  final Function(Task)? onDelete;
  final Function(Task)? onDuplicate;
  final Function(Task)? onCreateSubtask;
  final Map<String, List<TaskWarning>>? warningsByTaskId;
  final bool isLoading;
  final VoidCallback? onTasksUpdated;
  final VoidCallback? onConflictsLoaded;
  final Set<String>? conflictFilterTaskIds;
  final ValueChanged<Set<String>?>? onFilterConflictTasks;

  const ActivityGanttView({
    super.key,
    required this.tasks,
    required this.startDate,
    required this.endDate,
    this.scale = GanttScale.daily,
    this.onScaleChanged,
    this.taskService,
    this.conflictService,
    this.tasksForConflictDetection,
    this.tasksVersion = 0,
    this.allSubtasksExpanded,
    this.onToggleAllSubtasks,
    this.expandedTasks,
    this.onTaskExpanded,
    this.sortColumn,
    this.getSortValue,
    this.onTaskSelected,
    this.onEdit,
    this.onDelete,
    this.onDuplicate,
    this.onCreateSubtask,
    this.warningsByTaskId,
    this.isLoading = false,
    this.onTasksUpdated,
    this.onConflictsLoaded,
    this.conflictFilterTaskIds,
    this.onFilterConflictTasks,
  });

  @override
  State<ActivityGanttView> createState() => _ActivityGanttViewState();
}

class _ActivityGanttViewState extends State<ActivityGanttView> {
  // ── Scroll ────────────────────────────────────────────────────────────────
  final ScrollController _verticalController = ScrollController();
  final ScrollController _ganttHorizController = ScrollController();
  final ScrollController _ganttBottomHorizController = ScrollController();
  final ScrollController _ganttHeaderHorizController = ScrollController();
  final ScrollController _tableHeaderHorizController = ScrollController();

  final List<ScrollController> _rowScrollControllers = [];
  bool _isHorizScrolling = false;
  bool _isDragging = false;
  double _lastDragPosition = 0.0;
  bool _isDraggingFromEmptyArea = false;
  bool _isSegmentBeingDragged = false;

  // ── Estado de expansão ────────────────────────────────────────────────────
  Set<String> get _expandedTasks => widget.expandedTasks ?? _localExpandedTasks;
  final Set<String> _localExpandedTasks = {};
  final Map<String, List<Task>> _loadedSubtasks = {};

  // ── Serviços (estado partilhado, antes duplicado nos dois widgets) ─────────
  final StatusService _statusService = StatusService();
  final ChatService _chatService = ChatService();
  final AnexoService _anexoService = AnexoService();
  final NotaSAPService _notaSAPService = NotaSAPService();
  final OrdemService _ordemService = OrdemService();
  final ATService _atService = ATService();
  final SIService _siService = SIService();
  final FrotaService _frotaService = FrotaService();
  final FeriadoService _feriadoService = FeriadoService();
  final TipoAtividadeService _tipoAtividadeService = TipoAtividadeService();

  // ── Dados carregados ──────────────────────────────────────────────────────
  Map<String, Status> _statusMap = {};
  Map<String, int> _mensagensCount = {};
  Map<String, int> _anexosCount = {};
  Map<String, int> _notasSAPCount = {};
  Map<String, int> _ordensCount = {};
  Map<String, int> _atsCount = {};
  Map<String, int> _sisCount = {};
  Map<String, int> _notasNaoEncerradas = {};
  Map<String, int> _ordensNaoEncerradas = {};
  Map<String, int> _atsNaoEncerradas = {};
  Map<String, int> _frotasCount = {};
  Map<String, String> _frotasNomes = {};
  Map<String, TipoAtividade> _tipoAtividadeMap = {};

  // ── Cache estático compartilhado entre montagens da tela ───────────────────
  static Map<DateTime, List<Feriado>> _staticFeriadosMap = {};
  static Map<String, ConflictInfo>? _staticConflictMapFromBackend;
  static Set<String> _staticDaysWithConflicts = {};
  static Map<String, List<ExecutionEventFromBackend>>? _staticEventsByDayFromBackend;
  static Map<String, ConflictInfo>? _staticConflictMapFrotaFromBackend;
  static Map<String, List<FleetExecutionEventFromBackend>>? _staticFleetEventsByDayFromBackend;

  Map<DateTime, List<Feriado>> _feriadosMap = Map.from(_staticFeriadosMap);

  // ── Conflitos ─────────────────────────────────────────────────────────────
  Map<String, ConflictInfo>? _conflictMapFromBackend = _staticConflictMapFromBackend;
  Set<String> _daysWithConflicts = Set.from(_staticDaysWithConflicts); // Otimização: dias que têm pelo menos um conflito
  Map<String, List<ExecutionEventFromBackend>>? _eventsByDayFromBackend = _staticEventsByDayFromBackend;
  Map<String, ConflictInfo>? _conflictMapFrotaFromBackend = _staticConflictMapFrotaFromBackend;
  Map<String, List<FleetExecutionEventFromBackend>>? _fleetEventsByDayFromBackend = _staticFleetEventsByDayFromBackend;
  bool _useBackendConflicts = false;
  bool _useFleetConflictBackend = false;
  bool _conflictPaintReady = true;
  int _conflictsVersion = 0;
  final ValueNotifier<int> _conflictsVersionNotifier = ValueNotifier<int>(0);
  bool _isFetchingConflicts = false; 
  Timer? _debounceConflictsTimer; 
  DateTime? _lastFetchStart;
  DateTime? _lastFetchEnd;
  String? _lastTasksSignature;
  StreamSubscription<bool>? _syncStreamSub;
  bool _wasSyncing = false;

  // ── Gantt: período de exibição ────────────────────────────────────────────
  DateTime _displayStartDate = DateTime.now();
  DateTime _displayEndDate = DateTime.now();
  bool _hasInitializedScroll = false;
  bool _isScrollingProgrammatically = false;

  // ── UI misc ───────────────────────────────────────────────────────────────
  Timer? _emptyTimer;
  bool _showEmptyMessage = false;
  StreamSubscription<String>? _statusChangeSubscription;

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  // ── Getters de conveniência ───────────────────────────────────────────────
  bool get _allSubtasksExpanded => widget.allSubtasksExpanded ?? false;
  List<Task> get _taskList => widget.tasksForConflictDetection ?? widget.tasks;

  // =========================================================================
  // Lifecycle
  // =========================================================================

  @override
  void initState() {
    super.initState();

    final start = widget.startDate.subtract(const Duration(days: 15));
    final end = widget.endDate.add(const Duration(days: 15));

    _displayStartDate = start;
    _displayEndDate = end;

    _ganttHorizController.addListener(_syncGanttHorizScroll);
    TaskTableColumnService.instance.columnsNotifier.addListener(_onColumnsChanged);
    _ganttBottomHorizController.addListener(() {
      if (_isHorizScrolling || !_ganttBottomHorizController.hasClients) return;
      final offset = _ganttBottomHorizController.offset;
      if (_ganttHorizController.hasClients && (_ganttHorizController.offset - offset).abs() > 1.0) {
        _ganttHorizController.jumpTo(offset.clamp(0.0, _ganttHorizController.position.maxScrollExtent));
      }
    });

    _loadStatus();
    _loadCounts();
    _loadAllSubtasks();
    _loadTiposAtividade();
    _loadFeriados();
    _prefillLocalConflicts();

    if (widget.conflictService != null) {
      _loadBackendConflicts();
      _syncStreamSub = SyncService().syncingStream.listen((syncing) {
        if (_wasSyncing && !syncing && mounted) {
          _loadBackendConflicts();
        }
        _wasSyncing = syncing;
      });
    }

    _statusChangeSubscription = _statusService.statusChangeStream.listen((_) {
      _loadStatus();
    });

    _startEmptyTimer();
  }

  void _prefillLocalConflicts() {
    // Mantido vazio para evitar travar a renderização inicial no Flutter Web.
    // Os conflitos são carregados de forma assíncrona por _loadBackendConflicts().
  }

  @override
  void didUpdateWidget(ActivityGanttView oldWidget) {
    super.didUpdateWidget(oldWidget);

    final tasksChanged =
        oldWidget.tasks.length != widget.tasks.length ||
        oldWidget.tasks.map((t) => t.id).join(',') !=
            widget.tasks.map((t) => t.id).join(',') ||
        oldWidget.tasksVersion != widget.tasksVersion;
    
    final rangeChanged = oldWidget.startDate != widget.startDate || oldWidget.endDate != widget.endDate;

    if (tasksChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _loadCounts();
        _loadedSubtasks.clear();
        _loadAllSubtasks();
        
        if (widget.tasks.isEmpty) {
          _startEmptyTimer();
        } else {
          _emptyTimer?.cancel();
          _showEmptyMessage = false;
        }
      });
    }

    if (tasksChanged || rangeChanged) {
      if (widget.conflictService != null) {
        _debounceConflictsTimer?.cancel();
        _debounceConflictsTimer = Timer(const Duration(milliseconds: 300), () {
          _loadBackendConflicts();
        });
      }
    }

    // Sincronizar expansão global
    if (oldWidget.allSubtasksExpanded != widget.allSubtasksExpanded) {
      final mainTasks = widget.tasks.where((t) => t.parentId == null).toList();
      final toToggle = <String>[];
      for (var task in mainTasks) {
        final hasSubs = (_loadedSubtasks[task.id]?.isNotEmpty ?? false);
        final hasExec = task.executorPeriods.isNotEmpty;
        final hasFrota = task.frotaPeriods.isNotEmpty;
        if (hasSubs || hasExec || hasFrota) toToggle.add(task.id);
      }
      setState(() {
        if (widget.allSubtasksExpanded ?? false) {
          _expandedTasks.addAll(toToggle);
        } else {
          _expandedTasks.removeAll(toToggle);
        }
      });
    }

    // Recarregar conflitos quando datas ou escala mudarem
    if (rangeChanged || oldWidget.scale != widget.scale) {
      _hasInitializedScroll = false;
      _displayStartDate = widget.startDate.subtract(const Duration(days: 15));
      _displayEndDate = widget.endDate.add(const Duration(days: 15));
      _loadFeriados();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _ganttHorizController.hasClients) {
          _ganttHorizController.jumpTo(0);
          _ganttHeaderHorizController.jumpTo(0);
          for (var ctrl in _rowScrollControllers) {
            if (ctrl.hasClients) ctrl.jumpTo(0);
          }
          _hasInitializedScroll = true;
        }
      });
    } else if (tasksChanged && _feriadosMap.isEmpty) {
      _loadFeriados();
    }
  }

  @override
  void dispose() {
    _debounceConflictsTimer?.cancel();
    _conflictsVersionNotifier.dispose();
    _syncStreamSub?.cancel();
    _statusChangeSubscription?.cancel();
    _emptyTimer?.cancel();
    TaskTableColumnService.instance.columnsNotifier.removeListener(_onColumnsChanged);
    _verticalController.dispose();
    _ganttHorizController.removeListener(_syncGanttHorizScroll);
    _ganttHorizController.dispose();
    _ganttHeaderHorizController.dispose();
    _tableHeaderHorizController.dispose();
    _ganttBottomHorizController.dispose();

    for (var ctrl in _rowScrollControllers) {
      ctrl.dispose();
    }
    super.dispose();
  }

  // =========================================================================
  // Scroll
  // =========================================================================

  void _syncGanttHorizScroll() {
    if (_isHorizScrolling || !_ganttHorizController.hasClients) return;
    final offset = _ganttHorizController.offset;

    _isHorizScrolling = true;
    try {
      if (_ganttHeaderHorizController.hasClients && (_ganttHeaderHorizController.offset - offset).abs() > 1.0) {
        _ganttHeaderHorizController.jumpTo(
          offset.clamp(0.0, _ganttHeaderHorizController.position.maxScrollExtent),
        );
      }
      for (var ctrl in _rowScrollControllers) {
        if (ctrl.hasClients && (ctrl.offset - offset).abs() > 1.0) {
          ctrl.jumpTo(offset.clamp(0.0, ctrl.position.maxScrollExtent));
        }
      }
      if (_ganttBottomHorizController.hasClients && (_ganttBottomHorizController.offset - offset).abs() > 1.0) {
        _ganttBottomHorizController.jumpTo(
          offset.clamp(0.0, _ganttBottomHorizController.position.maxScrollExtent),
        );
      }
    } catch (_) {
    } finally {
      _isHorizScrolling = false;
    }
  }

  ScrollController _getRowController(int index) {
    while (_rowScrollControllers.length <= index) {
      final ctrl = ScrollController();
      ctrl.addListener(() {
        if (_isHorizScrolling || !ctrl.hasClients) return;
        final offset = ctrl.offset;
        if (_ganttHorizController.hasClients && (_ganttHorizController.offset - offset).abs() > 1.0) {
          _ganttHorizController.jumpTo(
            offset.clamp(0.0, _ganttHorizController.position.maxScrollExtent),
          );
        }
      });
      _rowScrollControllers.add(ctrl);
    }
    return _rowScrollControllers[index];
  }

  // =========================================================================
  // Carregamento de dados
  // =========================================================================

  void _startEmptyTimer() {
    _emptyTimer?.cancel();
    _showEmptyMessage = false;
    _emptyTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && widget.tasks.isEmpty && !widget.isLoading) {
        setState(() => _showEmptyMessage = true);
      }
    });
  }

  Future<void> _loadStatus() async {
    if (!mounted) return;
    try {
      final list = await _statusService.getAllStatus();
      if (mounted) {
        setState(() {
          _statusMap = {for (var s in list) s.codigo: s};
        });
      }
    } catch (e) {
      debugPrint('ActivityGanttView: erro ao carregar status: $e');
    }
  }

  Future<void> _loadTiposAtividade() async {
    try {
      final list = await _tipoAtividadeService.getTiposAtividadeAtivos();
      if (mounted) {
        setState(() {
          _tipoAtividadeMap = {for (var t in list) t.codigo: t};
        });
      }
    } catch (e) {
      debugPrint('ActivityGanttView: erro ao carregar tipos: $e');
    }
  }

  Future<void> _loadFeriados() async {
    try {
      final map = await _feriadoService.getFeriadosMapByDateRange(
        _displayStartDate,
        _displayEndDate,
      );
      if (mounted) {
        setState(() {
          _feriadosMap = map;
          _staticFeriadosMap = Map.from(map);
        });
      }
    } catch (e) {
      debugPrint('ActivityGanttView: erro ao carregar feriados: $e');
    }
  }

  Future<void> _loadAllSubtasks({bool forceReload = false}) async {
    if (widget.taskService == null) return;
    if (!forceReload && !_allSubtasksExpanded && _expandedTasks.isEmpty) return;

    final tasksToLoad = widget.tasks
        .where((t) => t.parentId == null && (forceReload || _allSubtasksExpanded || _expandedTasks.contains(t.id)))
        .where((t) => forceReload || !_loadedSubtasks.containsKey(t.id))
        .toList();

    if (tasksToLoad.isEmpty) return;

    final Map<String, List<Task>> newSubtasks = {};
    final Set<String> newExpanded = {};

    for (var task in tasksToLoad) {
      try {
        final subtasks = await widget.taskService!.getSubtasks(task.id);
        if (subtasks.isNotEmpty) {
          newSubtasks[task.id] = subtasks;
          if (_allSubtasksExpanded) newExpanded.add(task.id);
        }
      } catch (e) {
        debugPrint('ActivityGanttView: erro subtarefas ${task.id}: $e');
      }
    }

    if (mounted && newSubtasks.isNotEmpty) {
      setState(() {
        _loadedSubtasks.addAll(newSubtasks);
        _expandedTasks.addAll(newExpanded);
      });
    }
  }

  Future<void> _loadCounts() async {
    if (widget.tasks.isEmpty || !mounted) return;
    try {
      final ids = widget.tasks.map((t) => t.id).toList();
      final results = await Future.wait([
        _chatService.contarMensagensPorTarefas(ids).catchError((_) => <String, int>{}),
        _anexoService.contarAnexosPorTarefas(ids).catchError((_) => <String, int>{}),
        _notaSAPService.contarNotasPorTarefas(ids).catchError((_) => <String, int>{}),
        _ordemService.contarOrdensPorTarefas(ids).catchError((_) => <String, int>{}),
        _atService.contarATsPorTarefas(ids).catchError((_) => <String, int>{}),
        _siService.contarSIsPorTarefas(ids).catchError((_) => <String, int>{}),
        _frotaService.contarFrotasPorTarefas(ids).catchError((_) => <String, int>{}),
        widget.taskService != null
            ? widget.taskService!
                  .getEncerramentoSapPorTarefas(ids)
                  .catchError(
                    (_) => (
                      notasNaoEncerradas: <String, int>{},
                      ordensNaoEncerradas: <String, int>{},
                      atsNaoEncerradas: <String, int>{},
                    ),
                  )
            : Future.value((
                notasNaoEncerradas: <String, int>{},
                ordensNaoEncerradas: <String, int>{},
                atsNaoEncerradas: <String, int>{},
              )),
      ]);

      final enc = results[7];
      final notasNaoEnc = Map<String, int>.from((enc as dynamic).notasNaoEncerradas as Map);
      final ordensNaoEnc = Map<String, int>.from((enc as dynamic).ordensNaoEncerradas as Map);
      final atsNaoEnc = Map<String, int>.from((enc as dynamic).atsNaoEncerradas as Map);

      final frotasCountMap = results[6] as Map<String, int>;
      final frotasNomesMap = <String, String>{};
      for (var task in widget.tasks) {
        if ((frotasCountMap[task.id] ?? 0) > 0 && task.frota.isNotEmpty && task.frota != '-N/A-') {
          frotasNomesMap[task.id] = task.frota;
        }
      }

      if (mounted) {
        setState(() {
          _mensagensCount = results[0] as Map<String, int>;
          _anexosCount = results[1] as Map<String, int>;
          _notasSAPCount = results[2] as Map<String, int>;
          _ordensCount = results[3] as Map<String, int>;
          _atsCount = results[4] as Map<String, int>;
          _sisCount = results[5] as Map<String, int>;
          _frotasCount = frotasCountMap;
          _frotasNomes = frotasNomesMap;
          _notasNaoEncerradas = notasNaoEnc;
          _ordensNaoEncerradas = ordensNaoEnc;
          _atsNaoEncerradas = atsNaoEnc;
        });
      }
    } catch (e) {
      debugPrint('ActivityGanttView: erro ao carregar contagens: $e');
    }
  }

  Future<void> _loadBackendConflicts() async {
    PerformanceMonitor.start('Gantt.loadBackendConflicts');
    final cs = widget.conflictService;
    if (!mounted || cs == null) {
      PerformanceMonitor.stop('Gantt.loadBackendConflicts');
      return;
    }
    
    // Gerar uma assinatura das tarefas atuais para evitar recargas inúteis
    final currentSignature = widget.tasks.map((t) => t.id).join(',');
    if (_lastFetchStart == widget.startDate && 
        _lastFetchEnd == widget.endDate && 
        _lastTasksSignature == currentSignature &&
        _useBackendConflicts) {
      return; // Já temos os dados para este cenário
    }

    if (_isFetchingConflicts) return; // Já existe uma busca em curso

    setState(() => _isFetchingConflicts = true);
    
    try {
      final start = widget.startDate;
      final end = widget.endDate;

      // Otimização: Coletar apenas os IDs de executores e frotas presentes nestas tarefas
      final executorIds = <String>{};
      final frotaIds = <String>{};
      for (final t in widget.tasks) {
        for (final id in t.executorIds) {
          if (_uuidRegex.hasMatch(id.trim())) {
            executorIds.add(id.trim());
          }
        }
        // Se o campo executor (nome) por acaso for um UUID, também incluímos
        if (t.executor.isNotEmpty && _uuidRegex.hasMatch(t.executor.trim())) {
          executorIds.add(t.executor.trim());
        }
        frotaIds.addAll(t.frotaIds);
      }

      // 1. Verificar disponibilidade em paralelo
      final availability = await Future.wait([
        cs.isBackendAvailable(),
        cs.isFleetConflictBackendAvailable(),
      ]);
      final ok = availability[0];
      final fleetOk = availability[1];

      // 2. Buscar dados em paralelo para todo o período
      final results = await Future.wait([
        ok ? cs.getConflictsForRange(start, end) : Future.value(<String, ConflictInfo>{}),
        ok ? cs.getExecutionEventsForRange(start, end) : Future.value(<String, List<ExecutionEventFromBackend>>{}),
        fleetOk ? cs.getFleetConflictsForRange(start, end) : Future.value(<String, ConflictInfo>{}),
        fleetOk ? cs.getFleetExecutionEventsForRange(start, end) : Future.value(<String, List<FleetExecutionEventFromBackend>>{}),
      ]);

      if (!mounted) return;

      setState(() {
        _conflictMapFromBackend      = results[0] as Map<String, ConflictInfo>?;
        _eventsByDayFromBackend      = results[1] as Map<String, List<ExecutionEventFromBackend>>?;
        _conflictMapFrotaFromBackend = results[2] as Map<String, ConflictInfo>?;
        _fleetEventsByDayFromBackend = results[3] as Map<String, List<FleetExecutionEventFromBackend>>?;
        _useBackendConflicts         = ok;
        _useFleetConflictBackend     = fleetOk;
        _conflictsVersion++;
        
        _lastFetchStart = start;
        _lastFetchEnd = end;
        _lastTasksSignature = currentSignature;

        // Otimização: Preencher o Set de dias com conflito apenas para tarefas visíveis (tarefas e subtarefas)
        _daysWithConflicts.clear();
        if (_conflictMapFromBackend != null && widget.tasks.isNotEmpty) {
          // Criar um mapa rápido de quais dias cada executor tem tarefas visíveis
          final Map<String, Set<String>> visibleDaysByExecutor = {};
          final allVisibleTasks = <Task>[
            ...widget.tasks,
            ..._loadedSubtasks.values.expand((list) => list),
          ];
          for (final t in allVisibleTasks) {
            final ids = _getExecutorIdsForTask(t);
            if (t.ganttSegments.isEmpty) {
              DateTime cur = DateTime(t.dataInicio.year, t.dataInicio.month, t.dataInicio.day);
              final taskEnd = DateTime(t.dataFim.year, t.dataFim.month, t.dataFim.day);
              while (!cur.isAfter(taskEnd)) {
                final dayKey = '${cur.year}-${cur.month.toString().padLeft(2, '0')}-${cur.day.toString().padLeft(2, '0')}';
                for (final id in ids) {
                  visibleDaysByExecutor.putIfAbsent(id.toLowerCase(), () => {}).add(dayKey);
                }
                cur = cur.add(const Duration(days: 1));
              }
            } else {
              for (final segment in t.ganttSegments) {
                final isDeslocamento = (segment.tipoPeriodo ?? '').toUpperCase() == 'DESLOCAMENTO';
                if (isDeslocamento) {
                  final days = [
                    segment.dataInicio,
                    if (segment.dataFim.isAfter(segment.dataInicio)) segment.dataFim,
                  ];
                  for (final d in days) {
                    final dayKey = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                    for (final id in ids) {
                      visibleDaysByExecutor.putIfAbsent(id.toLowerCase(), () => {}).add(dayKey);
                    }
                  }
                } else {
                  DateTime cur = DateTime(segment.dataInicio.year, segment.dataInicio.month, segment.dataInicio.day);
                  final segEnd = DateTime(segment.dataFim.year, segment.dataFim.month, segment.dataFim.day);
                  while (!cur.isAfter(segEnd)) {
                    final dayKey = '${cur.year}-${cur.month.toString().padLeft(2, '0')}-${cur.day.toString().padLeft(2, '0')}';
                    for (final id in ids) {
                      visibleDaysByExecutor.putIfAbsent(id.toLowerCase(), () => {}).add(dayKey);
                    }
                    cur = cur.add(const Duration(days: 1));
                  }
                }
              }
            }
          }

          for (var entry in _conflictMapFromBackend!.entries) {
            if (entry.value.hasConflict) {
              final lastUnderscore = entry.key.lastIndexOf('_');
              if (lastUnderscore != -1) {
                final execId = entry.key.substring(0, lastUnderscore).toLowerCase();
                final dateKey = entry.key.substring(lastUnderscore + 1);
                
                // Só adiciona se o executor tem uma tarefa VISÍVEL neste dia
                if (visibleDaysByExecutor[execId]?.contains(dateKey) ?? false) {
                  _daysWithConflicts.add(dateKey);
                }
              }
            }
          }
          _staticConflictMapFromBackend = _conflictMapFromBackend;
          _staticEventsByDayFromBackend = _eventsByDayFromBackend;
          _staticConflictMapFrotaFromBackend = _conflictMapFrotaFromBackend;
          _staticFleetEventsByDayFromBackend = _fleetEventsByDayFromBackend;
          _staticDaysWithConflicts = Set.from(_daysWithConflicts);
        }
      });
      _conflictsVersionNotifier.value = _conflictsVersion;
      PerformanceMonitor.stop('Gantt.loadBackendConflicts');
    } catch (e) {
      debugPrint('Erro ao carregar conflitos do backend: $e');
      PerformanceMonitor.stop('Gantt.loadBackendConflicts');
    } finally {
      if (mounted) {
        setState(() => _isFetchingConflicts = false);
      }
    }
  }

  // =========================================================================
  // Lista hierárquica (única fonte de verdade)
  // =========================================================================

  List<Task> _buildHierarchicalTasks() {
    final List<Task> result = [];
    
    Set<String>? finalFilterIds;
    if (widget.conflictFilterTaskIds != null) {
      finalFilterIds = Set<String>.from(widget.conflictFilterTaskIds!);
      // If a subtask is in the conflict filter, ensure its parent is also included so it can be rendered
      for (final t in widget.tasks) {
        if (widget.conflictFilterTaskIds!.contains(t.id) && t.parentId != null) {
          finalFilterIds.add(t.parentId!);
        }
      }
      for (final sublist in _loadedSubtasks.values) {
        for (final sub in sublist) {
          if (widget.conflictFilterTaskIds!.contains(sub.id) && sub.parentId != null) {
            finalFilterIds.add(sub.parentId!);
          }
        }
      }
    }
    
    final sourceTasks = finalFilterIds != null 
        ? widget.tasks.where((t) => finalFilterIds!.contains(t.id)).toList()
        : widget.tasks;
        
    final mainTasks = sourceTasks.where((t) => t.parentId == null).toList();

    for (final main in mainTasks) {
      result.add(main);
      final isExpanded = _expandedTasks.contains(main.id);

      if (isExpanded && _loadedSubtasks.containsKey(main.id)) {
        final subs = _loadedSubtasks[main.id]!;
        if (finalFilterIds != null) {
          result.addAll(subs.where((s) => finalFilterIds!.contains(s.id)));
        } else {
          result.addAll(subs);
        }
      }

      if (isExpanded) {
        if (main.executorPeriods.isNotEmpty) {
          // Agrupar executores que possuem o mesmo período
          final Map<String, List<ExecutorPeriod>> groupedExecutors = {};
          final Map<String, ({DateTime minDate, DateTime maxDate})> groupDates = {};

          for (var ep in main.executorPeriods) {
            DateTime? minDate, maxDate;
            for (var p in ep.periods) {
              if (minDate == null || p.dataInicio.isBefore(minDate)) minDate = p.dataInicio;
              if (maxDate == null || p.dataFim.isAfter(maxDate)) maxDate = p.dataFim;
            }
            minDate ??= main.dataInicio;
            maxDate ??= main.dataFim;

            final periodKey =
                '${minDate.year}-${minDate.month.toString().padLeft(2, '0')}-${minDate.day.toString().padLeft(2, '0')}_'
                '${maxDate.year}-${maxDate.month.toString().padLeft(2, '0')}-${maxDate.day.toString().padLeft(2, '0')}';

            groupedExecutors.putIfAbsent(periodKey, () => []).add(ep);
            groupDates[periodKey] = (minDate: minDate, maxDate: maxDate);
          }

          for (var entry in groupedExecutors.entries) {
            final periodKey = entry.key;
            final group = entry.value;
            final dates = groupDates[periodKey]!;

            final executorNomes = group
                .map((e) => e.executorNome.trim())
                .where((n) => n.isNotEmpty)
                .toSet()
                .toList();
            final nomesJuntos = executorNomes.join(', ');
            final executorIds = group.map((e) => e.executorId).toList();

            final List<GanttSegment> combinedSegments = [];
            for (var ep in group) {
              for (var seg in ep.periods) {
                final exists = combinedSegments.any((s) =>
                    s.dataInicio.isAtSameMomentAs(seg.dataInicio) &&
                    s.dataFim.isAtSameMomentAs(seg.dataFim));
                if (!exists) {
                  combinedSegments.add(seg);
                }
              }
            }
            if (combinedSegments.isEmpty) {
              combinedSegments.add(GanttSegment(
                dataInicio: dates.minDate,
                dataFim: dates.maxDate,
                label: 'EXECUCAO',
                tipo: 'EXECUCAO',
              ));
            }

            result.add(Task(
              id: '${main.id}_executor_${group.first.executorId}_${dates.minDate.millisecondsSinceEpoch}',
              parentId: main.id,
              statusId: main.statusId,
              regionalId: main.regionalId,
              divisaoId: main.divisaoId,
              segmentoId: main.segmentoId,
              localIds: main.localIds,
              executorIds: executorIds,
              equipeIds: main.equipeIds,
              frotaIds: main.frotaIds,
              localId: main.localId,
              equipeId: main.equipeId,
              status: main.status,
              statusNome: main.statusNome,
              regional: main.regional,
              divisao: main.divisao,
              locais: main.locais,
              tipo: main.tipo,
              ordem: main.ordem,
              tarefa: nomesJuntos,
              executores: executorNomes,
              equipes: main.equipes,
              executor: nomesJuntos,
              frota: main.frota,
              coordenador: main.coordenador,
              si: main.si,
              dataInicio: dates.minDate,
              dataFim: dates.maxDate,
              ganttSegments: combinedSegments,
              executorPeriods: const [],
              frotaPeriods: const [],
              observacoes: main.observacoes,
              horasPrevistas: main.horasPrevistas,
              horasExecutadas: main.horasExecutadas,
              prioridade: main.prioridade,
            ));
          }
        }

        if (main.frotaPeriods.isNotEmpty) {
          // Agrupar frotas que possuem o mesmo período
          final Map<String, List<FrotaPeriod>> groupedFrota = {};
          final Map<String, ({DateTime minDate, DateTime maxDate})> groupDates = {};

          for (var fp in main.frotaPeriods) {
            DateTime? minDate, maxDate;
            for (var p in fp.periods) {
              if (minDate == null || p.dataInicio.isBefore(minDate)) minDate = p.dataInicio;
              if (maxDate == null || p.dataFim.isAfter(maxDate)) maxDate = p.dataFim;
            }
            minDate ??= main.dataInicio;
            maxDate ??= main.dataFim;

            final periodKey =
                '${minDate.year}-${minDate.month.toString().padLeft(2, '0')}-${minDate.day.toString().padLeft(2, '0')}_'
                '${maxDate.year}-${maxDate.month.toString().padLeft(2, '0')}-${maxDate.day.toString().padLeft(2, '0')}';

            groupedFrota.putIfAbsent(periodKey, () => []).add(fp);
            groupDates[periodKey] = (minDate: minDate, maxDate: maxDate);
          }

          for (var entry in groupedFrota.entries) {
            final periodKey = entry.key;
            final group = entry.value;
            final dates = groupDates[periodKey]!;

            final frotaNomes = group
                .map((f) => f.frotaNome.trim())
                .where((n) => n.isNotEmpty)
                .toSet()
                .toList();
            final veiculosJuntos = frotaNomes.join(', ');
            final frotaIds = group.map((f) => f.frotaId).toList();

            final List<GanttSegment> combinedSegments = [];
            for (var fp in group) {
              for (var seg in fp.periods) {
                final exists = combinedSegments.any((s) =>
                    s.dataInicio.isAtSameMomentAs(seg.dataInicio) &&
                    s.dataFim.isAtSameMomentAs(seg.dataFim));
                if (!exists) {
                  combinedSegments.add(seg);
                }
              }
            }
            if (combinedSegments.isEmpty) {
              combinedSegments.add(GanttSegment(
                dataInicio: dates.minDate,
                dataFim: dates.maxDate,
                label: 'EXECUCAO',
                tipo: 'EXECUCAO',
              ));
            }

            result.add(Task(
              id: '${main.id}_frota_${group.first.frotaId}_${dates.minDate.millisecondsSinceEpoch}',
              parentId: main.id,
              statusId: main.statusId,
              regionalId: main.regionalId,
              divisaoId: main.divisaoId,
              segmentoId: main.segmentoId,
              localIds: main.localIds,
              executorIds: main.executorIds,
              equipeIds: main.equipeIds,
              frotaIds: frotaIds,
              localId: main.localId,
              equipeId: main.equipeId,
              status: main.status,
              statusNome: main.statusNome,
              regional: main.regional,
              divisao: main.divisao,
              locais: main.locais,
              tipo: main.tipo,
              ordem: main.ordem,
              tarefa: veiculosJuntos,
              executores: main.executores,
              equipes: main.equipes,
              executor: main.executor,
              frota: veiculosJuntos,
              coordenador: main.coordenador,
              si: main.si,
              dataInicio: dates.minDate,
              dataFim: dates.maxDate,
              ganttSegments: combinedSegments,
              executorPeriods: const [],
              frotaPeriods: const [],
              observacoes: main.observacoes,
              horasPrevistas: main.horasPrevistas,
              horasExecutadas: main.horasExecutadas,
              prioridade: main.prioridade,
            ));
          }
        }
      }
    }
    return result;
  }

  // =========================================================================
  // Helpers de Gantt (período, offset, largura de barra)
  // =========================================================================

  List<GanttPeriod> _getPeriods() {
    final scale = widget.scale == GanttScale.hourly ? GanttScale.daily : widget.scale;
    switch (scale) {
      case GanttScale.daily:
        return _getDaysAsPeriods(widget.startDate, widget.endDate);
      case GanttScale.weekly:
      case GanttScale.biweekly:
      case GanttScale.monthly:
      case GanttScale.quarterly:
      case GanttScale.semiAnnual:
        return _getPeriodsInRange(widget.startDate, widget.endDate, scale);
      default:
        return _getDaysAsPeriods(widget.startDate, widget.endDate);
    }
  }

  List<GanttPeriod> _getDaysAsPeriods(DateTime start, DateTime end) {
    final result = <GanttPeriod>[];
    var cur = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);
    while (!cur.isAfter(last)) {
      final month = _getMonthAbbr(cur.month);
      // end deve ser cur + 1 dia (exclusivo), igual à convenção do gantt_chart.dart.
      // Isso garante que o GanttSegmentWidget filtre corretamente todos os dias,
      // incluindo o último dia do segmento, evitando célula em branco no fim.
      final nextDay = cur.add(const Duration(days: 1));
      result.add(GanttPeriod(
        start: cur,
        end: nextDay,
        label: '${cur.day}',
        groupLabel: '$month/${cur.year}',
      ));
      cur = nextDay;
    }
    return result;
  }

  List<GanttPeriod> _getPeriodsInRange(DateTime start, DateTime end, GanttScale scale) {
    final result = <GanttPeriod>[];
    var cur = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);
    while (!cur.isAfter(last)) {
      final periodEnd = _getPeriodEnd(cur, scale);
      final label = _getPeriodLabel(cur, scale);
      final group = _getPeriodGroup(cur, scale);
      result.add(GanttPeriod(start: cur, end: periodEnd, label: label, groupLabel: group));
      cur = periodEnd.add(const Duration(days: 1));
    }
    return result;
  }

  DateTime _getPeriodEnd(DateTime start, GanttScale scale) {
    switch (scale) {
      case GanttScale.weekly:
        return start.add(const Duration(days: 6));
      case GanttScale.biweekly:
        return start.add(const Duration(days: 13));
      case GanttScale.monthly:
        return DateTime(start.year, start.month + 1, 0);
      case GanttScale.quarterly:
        final endMonth = ((start.month - 1) ~/ 3 + 1) * 3;
        return DateTime(start.year, endMonth + 1, 0);
      case GanttScale.semiAnnual:
        final endMonth = start.month <= 6 ? 6 : 12;
        return DateTime(start.year, endMonth + 1, 0);
      default:
        return start;
    }
  }

  String _getPeriodLabel(DateTime date, GanttScale scale) {
    switch (scale) {
      case GanttScale.weekly:
        return 'S${_weekOfYear(date)}';
      case GanttScale.biweekly:
        return 'Q${((date.day - 1) ~/ 14) + 1}';
      case GanttScale.monthly:
        return _getMonthAbbr(date.month);
      case GanttScale.quarterly:
        return 'T${((date.month - 1) ~/ 3) + 1}';
      case GanttScale.semiAnnual:
        return date.month <= 6 ? '1S' : '2S';
      case GanttScale.daily:
      default:
        return date.day.toString().padLeft(2, '0');
    }
  }

  String _getPeriodGroup(DateTime date, GanttScale scale) {
    switch (scale) {
      case GanttScale.weekly:
      case GanttScale.biweekly:
        return '${_getMonthAbbr(date.month)}/${date.year}';
      case GanttScale.monthly:
        return '${date.year}';
      case GanttScale.quarterly:
      case GanttScale.semiAnnual:
        return '${date.year}';
      default:
        return '${_getMonthAbbr(date.month)}/${date.year}';
    }
  }

  int _weekOfYear(DateTime date) {
    final startOfYear = DateTime(date.year, 1, 1);
    return ((date.difference(startOfYear).inDays) / 7).ceil() + 1;
  }

  String _getMonthAbbr(int month) {
    const abbrs = ['', 'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
    return month >= 1 && month <= 12 ? abbrs[month] : '';
  }

  double _calcPeriodWidth(List<GanttPeriod> periods, double ganttWidth) {
    final scale = widget.scale == GanttScale.hourly ? GanttScale.daily : widget.scale;
    const min = 20.0, max = 80.0;
    final desired = switch (scale) {
      GanttScale.hourly => 24.0,
      GanttScale.daily => 30.0,
      GanttScale.weekly => 12.0,
      GanttScale.biweekly => 6.0,
      GanttScale.monthly => 12.0,
      GanttScale.quarterly => 4.0,
      GanttScale.semiAnnual => 2.0,
    };
    return periods.isEmpty ? 40.0 : ((ganttWidth / desired) * 0.7).clamp(min, max);
  }

  double _getDateOffsetFromPeriods(DateTime date, List<GanttPeriod> periods, double periodWidth) {
    final normalized = DateTime(date.year, date.month, date.day);
    for (int i = 0; i < periods.length; i++) {
      final ps = DateTime(periods[i].start.year, periods[i].start.month, periods[i].start.day);
      final pe = DateTime(periods[i].end.year, periods[i].end.month, periods[i].end.day);
      // pe é exclusivo (start + 1 dia): interval [ps, pe) → ps <= normalized < pe
      if (!normalized.isBefore(ps) && normalized.isBefore(pe)) {
        return i * periodWidth;
      }
    }
    return -1;
  }

  double _getBarWidthForRange(DateTime start, DateTime end, List<GanttPeriod> periods, double periodWidth) {
    int count = 0;
    // Converter end inclusive → end exclusivo para comparação uniforme com pe exclusivo
    final endExclusive = end.add(const Duration(days: 1));
    for (var p in periods) {
      final ps = DateTime(p.start.year, p.start.month, p.start.day);
      final pe = DateTime(p.end.year, p.end.month, p.end.day);
      // Sobreposição de intervalos semi-abertos [ps,pe) e [start, endExclusive):
      // ps < endExclusive  AND  pe > start
      if (ps.isBefore(endExclusive) && pe.isAfter(start)) count++;
    }

    return count * periodWidth;
  }

  double _getTodayOffset(List<GanttPeriod> periods, double periodWidth) {
    final today = DateTime.now();
    return _getDateOffsetFromPeriods(today, periods, periodWidth);
  }

  bool _isWeekend(DateTime date) => date.weekday == 6 || date.weekday == 7;
  bool _isFeriado(DateTime date) => _getGlobalHolidayColor(date) != null;

  Color? _getGlobalHolidayColor(DateTime date) {
    final n = DateTime(date.year, date.month, date.day);
    if (!_feriadosMap.containsKey(n)) return null;
    final feriados = _feriadosMap[n]!;
    if (feriados.isEmpty) return null;
    if (feriados.any((f) => f.tipo == 'EVENTO')) return Colors.orange[100];
    return Colors.purple[100];
  }

  String? _getGlobalHolidayTooltip(DateTime date) {
    final n = DateTime(date.year, date.month, date.day);
    if (!_feriadosMap.containsKey(n)) return null;
    final feriados = _feriadosMap[n]!;
    if (feriados.isEmpty) return null;
    return feriados.map((f) => '${f.tipo}: ${f.descricao}').join('\n');
  }
  
  bool _isFeriadoForTask(DateTime date, Task task) {
    return _getHolidayColorForTask(date, task) != null;
  }

  String? _getHolidayTooltipForTask(DateTime date, Task task) {
    final n = DateTime(date.year, date.month, date.day);
    if (!_feriadosMap.containsKey(n)) return null;
    final feriadosNoDia = _feriadosMap[n]!;
    if (feriadosNoDia.isEmpty) return null;

    final applicableFeriados = feriadosNoDia.where((feriado) {
      if (feriado.tipo == 'NACIONAL' || feriado.tipo == 'EVENTO') return true;
      if (feriado.localIds.isEmpty) return true;
      if (task.localIds.isNotEmpty) {
        return feriado.localIds.any((lId) => task.localIds.contains(lId));
      }
      return true;
    }).toList();

    if (applicableFeriados.isEmpty) return null;
    return applicableFeriados.map((f) => '${f.tipo}: ${f.descricao}').join('\n');
  }

  Color? _getHolidayColorForTask(DateTime date, Task task) {
    final n = DateTime(date.year, date.month, date.day);
    if (!_feriadosMap.containsKey(n)) return null;
    final feriadosNoDia = _feriadosMap[n]!;
    if (feriadosNoDia.isEmpty) return null;

    final applicableFeriados = feriadosNoDia.where((feriado) {
      if (feriado.tipo == 'NACIONAL' || feriado.tipo == 'EVENTO') return true;
      if (feriado.localIds.isEmpty) return true;
      if (task.localIds.isNotEmpty) {
        return feriado.localIds.any((lId) => task.localIds.contains(lId));
      }
      return true;
    }).toList();

    if (applicableFeriados.isEmpty) return null;

    // Priorizar EVENTO (laranja) sobre feriados normais (roxo) se houver ambos
    if (applicableFeriados.any((f) => f.tipo == 'EVENTO')) {
      return Colors.orange[100];
    }

    return Colors.purple[100];
  }

  DateTime _normalizeLegacyEndDate(Task task, DateTime start, DateTime end) {
    return end;
  }

  // =========================================================================
  // Cores
  // =========================================================================

  Color _getStatusBackgroundColor(String status) {
    if (status == 'PROG') return Colors.white;
    final s = _statusMap[status];
    if (s != null) {
      if (s.codigo == 'PROG') return Colors.white;
      return s.color.withValues(alpha: 0.15);
    }
    switch (status) {
      case 'PROG':
        return Colors.white;
      case 'CONC':
        return Colors.green.withValues(alpha: 0.15);
      case 'ANDA':
        return Colors.orange.withValues(alpha: 0.15);
      default:
        return Colors.white;
    }
  }

  Color _getStatusBadgeColor(String status) {
    final s = _statusMap[status];
    return s?.color ?? Colors.grey;
  }

  Color _getSegmentColorByPeriod(GanttSegment segment, Task task, {Task? parentTask, bool isSubtask = false}) {
    switch (segment.tipoPeriodo.toUpperCase().trim()) {
      case 'PLANEJAMENTO':
        return Colors.orange[600]!;
      case 'DESLOCAMENTO':
        return Colors.blue[900]!;
      case 'EXECUCAO':
      default:
        if (isSubtask && parentTask != null) {
          final base = _getSegmentColorByPeriod(segment, parentTask, isSubtask: false);
          return Color.lerp(base, Colors.white, 0.4) ?? base;
        }
        if (task.tipo.isNotEmpty) {
          final tipo = _tipoAtividadeMap[task.tipo];
          if (tipo != null) {
            if (tipo.corSegmento != null && tipo.corSegmento!.isNotEmpty) {
              try { return tipo.segmentBackgroundColor; } catch (_) {}
            }
            if (tipo.cor != null && tipo.cor!.isNotEmpty) {
              try {
                final hex = tipo.cor!.replaceFirst('#', '');
                return Color(int.parse('FF$hex', radix: 16));
              } catch (_) {}
            }
          }
        }
        return Colors.grey[400]!;
    }
  }

  // =========================================================================
  // Conflitos
  // =========================================================================

  bool _hasConflictOnDayForExecutor(DateTime day, String executorId) {
    if (widget.conflictService != null) {
      if (_conflictMapFromBackend != null) {
        final key = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
        final info = _conflictMapFromBackend!['${executorId.toLowerCase()}_$key'] ??
            _conflictMapFromBackend!['${ConflictService.normalizeExecutorKey(executorId)}_$key'];
        return info?.hasConflict ?? false;
      }
      // Se _conflictMapFromBackend ainda não carregou do backend, não executa cálculos pesados no build da UI.
      // O carregamento assíncrono (_loadBackendConflicts) atualizará a UI assim que concluir.
      return false;
    }
    return false;
  }

  bool _hasConflictOnDayForFrota(DateTime day, String frotaId) {
    if (_conflictMapFrotaFromBackend == null) return false;
    final key = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    final info = _conflictMapFrotaFromBackend!['${frotaId}_$key'] ??
        _conflictMapFrotaFromBackend!['${frotaId.toLowerCase()}_$key'];
    return info?.hasConflict ?? false;
  }

  bool _hasAnyExecutorConflictOnDay(DateTime day) {
    final key = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    return _daysWithConflicts.contains(key);
  }

  List<String> _getExecutorIdsForTask(Task task) {
    final ids = <String>{};
    ids.addAll(task.executorIds);
    for (var ep in task.executorPeriods) {
      if (ep.executorId.isNotEmpty) ids.add(ep.executorId);
    }
    if (task.executor.isNotEmpty) ids.add(task.executor);
    return ids.toList();
  }

  List<String> _getFleetIdsForTask(Task task) => task.frotaIds;

  Set<DateTime> _getConflictDaysForSegment(Task task, DateTime start, DateTime end) {
    final executorIds = _getExecutorIdsForTask(task);
    final days = <DateTime>{};
    var cur = start;
    while (!cur.isAfter(end)) {
      for (final id in executorIds) {
        if (_hasConflictOnDayForExecutor(cur, id)) {
          days.add(cur);
          break;
        }
      }
      cur = cur.add(const Duration(days: 1));
    }
    return days;
  }

  Set<DateTime> _getConflictDaysForSegmentFrota(Task task, DateTime start, DateTime end) {
    final frotaIds = _getFleetIdsForTask(task);
    final days = <DateTime>{};
    var cur = start;
    while (!cur.isAfter(end)) {
      for (final id in frotaIds) {
        if (_hasConflictOnDayForFrota(cur, id)) {
          days.add(cur);
          break;
        }
      }
      cur = cur.add(const Duration(days: 1));
    }
    return days;
  }

  /// Tooltip de conflito apenas para um dia (para mostrar só o dia sob o cursor).
  /// Agrupa por nome do executor para evitar linhas duplicadas (mesmo executor com ID e nome).
  String? _getConflictDetailsMessageForSingleDay(Task task, DateTime day) {
    final executorIds = _getExecutorIdsForConflictLookup(task);
    if (executorIds.isEmpty) return null;

    if (widget.conflictService != null && _useBackendConflicts && _eventsByDayFromBackend != null) {
      final key = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final allEvents = _eventsByDayFromBackend![key] ?? [];
      if (allEvents.isEmpty) return null;

      final relevantEvents = allEvents.where((e) => executorIds.contains(e.executorId)).toList();
      if (relevantEvents.isEmpty) return null;

      final idToName = _executorIdToNameMap();
      final nameToDescriptions = <String, Set<String>>{};
      for (final e in relevantEvents) {
        if (e.taskId == task.id) continue;
        final nome = idToName[e.executorId] ?? e.executorId;
        nameToDescriptions.putIfAbsent(nome, () => {}).add(e.description);
      }
      if (nameToDescriptions.isEmpty) return null;

      final dayStr = '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}/${day.year}';
      final lines = <String>['Conflito em $dayStr (Backend):', ''];
      final names = nameToDescriptions.keys.toList()..sort();
      for (final nome in names) {
        final descs = nameToDescriptions[nome]!.toList()..sort();
        lines.add('• $nome: ${descs.join(' ; ')}');
      }
      return lines.join('\n');
    }

    return null;
  }

  Set<String> _getConflictTaskIdsForSingleDay(Task task, DateTime day) {
    final executorIds = _getExecutorIdsForConflictLookup(task);
    if (executorIds.isEmpty) return {};

    if (widget.conflictService != null && _useBackendConflicts && _eventsByDayFromBackend != null) {
      final key = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final allEvents = _eventsByDayFromBackend![key] ?? [];
      if (allEvents.isEmpty) return {};

      final relevantEvents = allEvents.where((e) => executorIds.contains(e.executorId)).toList();
      return relevantEvents.map((e) => e.taskId).toSet();
    }
    
    final events = ConflictDetection.getExecutionEventsForDay(
      _taskList, day, _taskList,
    );
    return events
        .where((e) => executorIds.contains(e.executorId))
        .map((e) => e.taskId)
        .where((s) => s.isNotEmpty)
        .toSet();
  }

  String? _getFleetConflictDetailsMessageForSingleDay(Task task, DateTime day) {
    final frotaIds = _getFleetIdsForTask(task);
    if (frotaIds.isEmpty) return null;

    if (widget.conflictService != null && _useFleetConflictBackend && _fleetEventsByDayFromBackend != null) {
      final key = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final allEvents = _fleetEventsByDayFromBackend![key] ?? [];
      if (allEvents.isEmpty) return null;

      final relevantEvents = allEvents.where((e) => frotaIds.contains(e.frotaId)).toList();
      if (relevantEvents.isEmpty) return null;

      final nameToDescriptions = <String, Set<String>>{};
      for (final e in relevantEvents) {
        if (e.taskId == task.id) continue;
        nameToDescriptions.putIfAbsent(e.frotaNome, () => {}).add(e.description);
      }
      if (nameToDescriptions.isEmpty) return null;

      final dayStr = '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}/${day.year}';
      final lines = <String>['Conflito de frota em $dayStr:', ''];
      for (final entry in nameToDescriptions.entries) {
        lines.add('• ${entry.key}: ${entry.value.join(' ; ')}');
      }
      return lines.join('\n');
    }

    final lines = <String>['Conflito de frota (dias em preto).', ''];
    for (final frotaId in frotaIds) {
      if (!_hasConflictOnDayForFrota(day, frotaId)) continue;
      // Detecção local de frota não implementada detalhadamente aqui
      lines.add('• Frota em conflito neste dia.');
    }
    if (lines.length <= 2) return null;
    return lines.join('\n');
  }

  Set<String> _getExecutorIdsForConflictLookup(Task task) {
    final nameToId = <String, String>{};
    for (final ep in task.executorPeriods) {
      if (ep.executorId.trim().isNotEmpty && _uuidRegex.hasMatch(ep.executorId.trim()) && ep.executorNome.trim().isNotEmpty) {
        final nome = ep.executorNome.trim();
        nameToId[nome] = ep.executorId.trim();
        nameToId[ConflictService.normalizeExecutorKey(nome)] = ep.executorId.trim();
      }
    }
    final resolved = <String>{};
    for (final id in ConflictDetection.getExecutorIdsForTask(task)) {
      final t = id.trim();
      if (t.isEmpty) continue;
      if (_uuidRegex.hasMatch(t)) {
        resolved.add(t);
      } else {
        final uuid = nameToId[t] ?? nameToId[ConflictService.normalizeExecutorKey(t)];
        if (uuid != null) resolved.add(uuid);
      }
    }
    return resolved;
  }

  Map<String, String> _executorIdToNameMap() {
    final map = <String, String>{};
    for (final task in _taskList) {
      for (final ep in task.executorPeriods) {
        if (ep.executorId.trim().isNotEmpty && ep.executorNome.trim().isNotEmpty) {
          map[ep.executorId] = ep.executorNome.trim();
          map[ep.executorNome.trim()] = ep.executorNome.trim();
        }
      }
      if (task.executorIds.isNotEmpty) {
        final nameList = task.executores.isNotEmpty ? task.executores : task.executor.split(',').map((e) => e.trim()).toList();
        for (var i = 0; i < task.executorIds.length && i < nameList.length; i++) {
          final eid = task.executorIds[i].trim();
          final nome = nameList[i];
          if (eid.isNotEmpty && nome.isNotEmpty) {
            map[eid] = nome;
            map[nome] = nome;
          }
        }
      }
    }
    return map;
  }

  String _executorIdToDisplayName(String execId, Map<String, String> idToName) {
    final t = execId.trim();
    if (t.isEmpty) return '';
    if (_uuidRegex.hasMatch(t)) return idToName[t] ?? '';
    return idToName[t] ?? t;
  }

  // =========================================================================
  // Builders de cabeçalho
  // =========================================================================

  Widget _buildTableHeader(bool isMobile) {
    final colService = TaskTableColumnService.instance;
    final visibleCols = colService.visibleColumns;
    final w = _tableColWidths(isMobile);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Faixa superior alinhada com a linha de mês do cabeçalho do Gantt
        Container(
          height: Responsive.kActivitiesHeaderTopHeight,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border(bottom: BorderSide(color: Colors.grey[300]!, width: 1)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: Center(
                  child: Text(
                    'ATIVIDADES',
                    style: TextStyle(
                      fontSize: isMobile ? 9 : 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
              Tooltip(
                message: 'Personalizar colunas (expandir área do Gantt)',
                child: InkWell(
                  onTap: () => TaskTableColumnPickerDialog.show(context, isMobile: isMobile),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.tune_rounded, size: isMobile ? 13 : 15, color: Colors.blue[800]),
                        const SizedBox(width: 4),
                        Text(
                          'Colunas',
                          style: TextStyle(
                            fontSize: isMobile ? 9 : 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Linha de colunas (alinhada com a linha de dias do Gantt)
        Container(
          height: Responsive.kActivitiesHeaderRowHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[700]!, Colors.blue[600]!],
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 2, offset: const Offset(0, 2)),
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: _tableHeaderHorizController,
            physics: const NeverScrollableScrollPhysics(),
            child: SizedBox(
              width: _calcTableWidth(isMobile),
              child: Row(
                children: [
                  if (visibleCols.contains(TaskTableColumn.acoes))
                    _buildTableHeaderCell('AÇÕES', w.acoes, isMobile),
                  if (visibleCols.contains(TaskTableColumn.status))
                    _buildTableHeaderCell('STATUS', w.status, isMobile),
                  if (visibleCols.contains(TaskTableColumn.local))
                    _buildTableHeaderCell('LOCAL', w.local, isMobile),
                  if (visibleCols.contains(TaskTableColumn.tipo))
                    _buildTableHeaderCell('TIPO', w.tipo, isMobile),
                  if (visibleCols.contains(TaskTableColumn.tarefa))
                    _buildTableHeaderCell('TAREFA', w.tarefa, isMobile),
                  if (visibleCols.contains(TaskTableColumn.executor))
                    _buildTableHeaderCell('EXECUTOR', w.executor, isMobile),
                  if (visibleCols.contains(TaskTableColumn.coordenador))
                    _buildTableHeaderCell('COORDENADOR', w.coordenador, isMobile),
                  if (visibleCols.contains(TaskTableColumn.frota))
                    _buildTableHeaderCell('FROTA', w.frota, isMobile),
                  if (visibleCols.contains(TaskTableColumn.chat))
                    _buildTableHeaderCell('CHAT', w.chat, isMobile),
                  if (visibleCols.contains(TaskTableColumn.anexos))
                    _buildTableHeaderCell('ANEXOS', w.anexos, isMobile),
                  if (visibleCols.contains(TaskTableColumn.nota))
                    _buildTableHeaderCell('NOTA', w.notasSAP, isMobile),
                  if (visibleCols.contains(TaskTableColumn.ordem))
                    _buildTableHeaderCell('ORDEM', w.ordens, isMobile),
                  if (visibleCols.contains(TaskTableColumn.at))
                    _buildTableHeaderCell('AT', w.ats, isMobile),
                  if (visibleCols.contains(TaskTableColumn.si))
                    _buildTableHeaderCell('SI', w.sis, isMobile),
                  if (visibleCols.contains(TaskTableColumn.alertas))
                    _buildTableHeaderCell('ALERTAS', w.alertas, isMobile),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeaderCell(String text, double width, bool isMobile) {
    return SizedBox(
      width: width,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 3 : 6, vertical: 4),
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: Colors.white.withOpacity(0.2), width: 1)),
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
      ),
    );
  }

  Widget _buildGanttHeader(List<GanttPeriod> periods, double periodWidth, double totalWidth, double todayOffset) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Linha 1: grupos (mês/ano)
        Container(
          height: Responsive.kActivitiesHeaderTopHeight,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border(bottom: BorderSide(color: Colors.grey[300]!, width: 1)),
          ),
          child: Scrollbar(
            controller: _ganttHeaderHorizController,
            child: SingleChildScrollView(
              controller: _ganttHeaderHorizController,
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: SizedBox(
                width: totalWidth,
                height: Responsive.kActivitiesHeaderTopHeight,
                child: Stack(
                  children: _buildMergedGroupHeaders(periods, periodWidth),
                ),
              ),
            ),
          ),
        ),
        // Linha 2: períodos (dias / semanas etc.)
        Container(
          height: Responsive.kActivitiesHeaderRowHeight,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border(bottom: BorderSide(color: Colors.grey[300]!, width: 1)),
          ),
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (e) {
              if (e.kind == PointerDeviceKind.mouse) {
                _isDraggingFromEmptyArea = true;
                _isDragging = true;
                _lastDragPosition = e.localPosition.dx;
              }
            },
            onPointerMove: (e) {
              if (_isDragging && _isDraggingFromEmptyArea && e.kind == PointerDeviceKind.mouse) {
                final delta = (_lastDragPosition - e.localPosition.dx) * 0.2;
                _lastDragPosition = e.localPosition.dx;
                if (_ganttHorizController.hasClients) {
                  final newOff = (_ganttHorizController.offset + delta)
                      .clamp(0.0, _ganttHorizController.position.maxScrollExtent);
                  _ganttHorizController.jumpTo(newOff);
                }
              }
            },
            onPointerUp: (_) { _isDragging = false; _isDraggingFromEmptyArea = false; },
            onPointerCancel: (_) { _isDragging = false; _isDraggingFromEmptyArea = false; },
            child: Scrollbar(
              controller: _ganttHorizController,
              child: SingleChildScrollView(
                  controller: _ganttHorizController,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: SizedBox(
                  width: totalWidth,
                  height: Responsive.kActivitiesHeaderRowHeight,
                  child: Stack(
                    children: [
                      SizedBox(width: totalWidth, height: 1),
                      ...List.generate(periods.length, (i) {
                        final p = periods[i];
                        final isDay = widget.scale == GanttScale.daily;
                        final isWeekend = isDay && _isWeekend(p.start);
                        final holidayColor = isDay ? _getGlobalHolidayColor(p.start) : null;
                        final tooltip = isDay ? _getGlobalHolidayTooltip(p.start) : null;
                        final hasConflict = isDay && _hasAnyExecutorConflictOnDay(p.start);

                        Widget cell = Container(
                          decoration: BoxDecoration(
                            color: hasConflict ? Colors.red[100] : (holidayColor ?? (isWeekend ? Colors.grey[200] : Colors.white)),
                            border: Border.all(color: Colors.grey[300]!, width: 1),
                          ),
                          alignment: Alignment.center,
                          child: Center(
                            child: Text(p.label, 
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: hasConflict ? FontWeight.bold : FontWeight.normal,
                                color: hasConflict ? Colors.red[900] : Colors.black,
                              ), 
                              overflow: TextOverflow.ellipsis
                            ),
                          ),
                        );

                        if (tooltip != null) {
                          final n = DateTime(p.start.year, p.start.month, p.start.day);
                          final feriados = _feriadosMap[n] ?? [];
                          
                          if (feriados.isNotEmpty) {
                            final f = feriados.first;
                            MarkerType mType = MarkerType.nationalHoliday;
                            if (f.tipo == 'ESTADUAL') mType = MarkerType.stateHoliday;
                            else if (f.tipo == 'MUNICIPAL') mType = MarkerType.cityHoliday;
                            else if (f.tipo == 'EVENTO') mType = MarkerType.specialEvent;

                            cell = TaskFlowCalendarMarkerTooltip(
                              data: CalendarMarkerData(
                                title: feriados.map((e) => e.descricao).join(' + '),
                                type: mType,
                                date: p.start,
                                observation: f.tipo == 'EVENTO' ? 'Evento Setor Elétrico' : 'Dia não útil',
                              ),
                              child: cell,
                            );
                          }
                        }

                        return Positioned(
                          left: i * periodWidth,
                          top: 0,
                          bottom: 0,
                          width: periodWidth,
                          child: cell,
                        );
                      }),
                      ..._buildGroupSeparators(periods, periodWidth),
                      if (todayOffset >= 0)
                        Positioned(
                          left: todayOffset + (periodWidth / 2) - 8,
                          top: 0,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(color: Colors.red[500], shape: BoxShape.circle),
                            child: const Icon(Icons.circle, size: 12, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildMergedGroupHeaders(List<GanttPeriod> periods, double periodWidth) {
    final headers = <Widget>[];
    String? currentGroup;
    int startIndex = 0;
    for (int i = 0; i < periods.length; i++) {
      final g = periods[i].groupLabel ?? '';
      if (currentGroup == null || g != currentGroup) {
        if (currentGroup != null) {
          headers.add(_groupHeaderWidget(currentGroup, startIndex, i, periodWidth));
        }
        currentGroup = g;
        startIndex = i;
      }
    }
    if (currentGroup != null) {
      headers.add(_groupHeaderWidget(currentGroup, startIndex, periods.length, periodWidth));
    }
    return headers;
  }

  Widget _groupHeaderWidget(String label, int from, int to, double periodWidth) {
    return Positioned(
      left: from * periodWidth,
      top: 0,
      bottom: 0,
      width: (to - from) * periodWidth,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          border: Border(
            right: BorderSide(color: Colors.grey[300]!, width: 1),
            bottom: BorderSide(color: Colors.grey[300]!, width: 1),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[700]),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildGroupSeparators(List<GanttPeriod> periods, double periodWidth) {
    final seps = <Widget>[];
    String? prev;
    for (int i = 0; i < periods.length; i++) {
      final g = periods[i].groupLabel ?? '';
      if (prev != null && g != prev) {
        seps.add(Positioned(
          left: i * periodWidth,
          top: 0,
          bottom: 0,
          child: Container(
            width: 2,
            color: Colors.blue[700],
          ),
        ));
      }
      prev = g;
    }
    return seps;
  }

  // =========================================================================
  // Builder de linha unificada
  // =========================================================================

  Widget _buildUnifiedRow(
    BuildContext context,
    Task task,
    int index,
    List<Task> hierarchicalTasks,
    List<GanttPeriod> periods,
    double periodWidth,
    double totalWidth,
    double todayOffset,
    double ganttWidth,
    bool isMobile,
  ) {
    final isExecutorRow = task.id.contains('_executor_');
    final isFrotaRow = task.id.contains('_frota_');
    final isSubtask = task.parentId != null && !isExecutorRow && !isFrotaRow;
    final subtasksCount = _loadedSubtasks[task.id]?.length ?? 0;
    final hasSubtasks = subtasksCount > 0;
    final hasExecutorPeriods = !isSubtask && !isExecutorRow && !isFrotaRow && task.executorPeriods.isNotEmpty;
    final hasFrotaPeriods = !isSubtask && !isExecutorRow && !isFrotaRow && task.frotaPeriods.isNotEmpty;
    final isExpanded = _expandedTasks.contains(task.id);
    final statusBg = _getStatusBackgroundColor(task.status);

    // Separador de grupo (sortação)
    bool mudouGrupo = false;
    if (index > 0 && widget.sortColumn != null && widget.sortColumn != 'PERÍODO') {
      final prev = hierarchicalTasks[index - 1];
      if (prev.parentId == null && task.parentId == null &&
          !prev.id.contains('_executor_') && !prev.id.contains('_frota_') &&
          !isExecutorRow && !isFrotaRow && !isSubtask &&
          widget.getSortValue != null) {
        try {
          mudouGrupo = widget.getSortValue!(prev).trim() != widget.getSortValue!(task).trim();
        } catch (_) {}
      }
    }

    void toggleExpansion() {
      final newState = !isExpanded;
      if (widget.onTaskExpanded != null) {
        widget.onTaskExpanded!(task.id, newState);
      } else {
        setState(() {
          if (newState) _localExpandedTasks.add(task.id); else _localExpandedTasks.remove(task.id);
        });
      }
    }

    final rowController = _getRowController(index);

    // Sincronizar posição horizontal ao montar
    if (_hasInitializedScroll && _ganttHorizController.hasClients) {
      final target = _ganttHorizController.offset;
      if (rowController.hasClients) {
        if ((rowController.offset - target).abs() > 1.0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (rowController.hasClients) {
              try {
                rowController.jumpTo(target.clamp(0.0, rowController.position.maxScrollExtent));
              } catch (_) {}
            }
          });
        }
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (rowController.hasClients && mounted) {
            final targetPost = _ganttHorizController.hasClients ? _ganttHorizController.offset : target;
            if ((rowController.offset - targetPost).abs() > 1.0) {
              try {
                rowController.jumpTo(targetPost.clamp(0.0, rowController.position.maxScrollExtent));
              } catch (_) {}
            }
          }
        });
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (mudouGrupo)
          Container(height: 1, width: double.infinity, color: Colors.black),
        SizedBox(
          height: 50,
          child: Row(
            children: [
              // ── Painel da tabela (largura fixa) ───────────────────────────
              _buildTableRowPanel(
                task, isMobile, isSubtask, hasSubtasks, isExecutorRow, isFrotaRow,
                hasExecutorPeriods, hasFrotaPeriods, isExpanded, statusBg, subtasksCount, toggleExpansion,
              ),
              // ── Divisor visual ────────────────────────────────────────────
              Container(width: 1, color: Colors.grey[300]),
              // ── Painel do Gantt (scroll horizontal) ───────────────────────
              Expanded(
                child: _buildGanttRowPanel(
                  task, index, isSubtask, hasSubtasks, isExecutorRow, isFrotaRow,
                  hasExecutorPeriods, hasFrotaPeriods,
                  isExpanded, periods, periodWidth, totalWidth, todayOffset,
                  rowController, toggleExpansion, hierarchicalTasks,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // Painel da tabela (linha)
  // =========================================================================

  void _onColumnsChanged() {
    if (mounted) setState(() {});
  }

  _TableColWidths _tableColWidths(bool isMobile) => _TableColWidths(isMobile);
  double _calcTableWidth(bool isMobile) => TaskTableColumnService.instance.calculateTotalWidth(isMobile);

  String _formatDateRange(DateTime start, DateTime end) {
    final sDay = start.day.toString().padLeft(2, '0');
    final sMonth = start.month.toString().padLeft(2, '0');
    final eDay = end.day.toString().padLeft(2, '0');
    final eMonth = end.month.toString().padLeft(2, '0');
    final days = end.difference(start).inDays + 1;
    return '$sDay/$sMonth a $eDay/$eMonth (${days}d)';
  }

  Widget _buildTaskTitleCell(
    Task task,
    double width,
    bool isMobile, {
    required bool isSubtask,
    required bool isExecutorRow,
    required bool isFrotaRow,
    required Color statusBg,
  }) {
    Widget content;

    if (isExecutorRow) {
      final periodStr = _formatDateRange(task.dataInicio, task.dataFim);
      content = Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.orange[300]!, width: 0.8),
            ),
            child: Tooltip(
              message: 'Período por executor',
              child: Icon(
                Icons.person,
                size: isMobile ? 12 : 14,
                color: Colors.orange[800],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.executor.isNotEmpty ? task.executor : task.tarefa,
                  style: TextStyle(
                    fontSize: isMobile ? 10 : 11.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Período: $periodStr',
                  style: TextStyle(
                    fontSize: isMobile ? 8.5 : 9.5,
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      );
    } else if (isFrotaRow) {
      final periodStr = _formatDateRange(task.dataInicio, task.dataFim);
      content = Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.green[300]!, width: 0.8),
            ),
            child: Tooltip(
              message: 'Período por frota',
              child: Icon(
                Icons.directions_car,
                size: isMobile ? 12 : 14,
                color: Colors.green[800],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.frota.isNotEmpty ? task.frota : task.tarefa,
                  style: TextStyle(
                    fontSize: isMobile ? 10 : 11.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Período: $periodStr',
                  style: TextStyle(
                    fontSize: isMobile ? 8.5 : 9.5,
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      );
    } else if (isSubtask) {
      content = Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.blue[300]!, width: 0.8),
            ),
            child: Tooltip(
              message: 'Subtarefa',
              child: Icon(
                Icons.subdirectory_arrow_right,
                size: isMobile ? 12 : 14,
                color: Colors.blue[800],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              task.tarefa,
              style: TextStyle(
                fontSize: isMobile ? 10.5 : 11.5,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    } else {
      content = Text(
        task.tarefa,
        style: TextStyle(
          fontSize: isMobile ? 10 : 11.5,
          fontWeight: (task.status == 'PROG' || task.status == 'ANDA') ? FontWeight.w600 : FontWeight.normal,
          color: Colors.black87,
        ),
        maxLines: 2,
        softWrap: true,
        overflow: TextOverflow.fade,
      );
    }

    return Container(
      width: width,
      height: 50,
      padding: EdgeInsets.only(
        left: (isSubtask || isExecutorRow || isFrotaRow) ? (isMobile ? 10 : 14) : (isMobile ? 4 : 6),
        right: isMobile ? 4 : 6,
        top: 4,
        bottom: 4,
      ),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey[300]!, width: 0.5)),
      ),
      child: content,
    );
  }

  Widget _buildTableRowPanel(
    Task task,
    bool isMobile,
    bool isSubtask,
    bool hasSubtasks,
    bool isExecutorRow,
    bool isFrotaRow,
    bool hasExecutorPeriods,
    bool hasFrotaPeriods,
    bool isExpanded,
    Color statusBg,
    int subtasksCount,
    VoidCallback toggleExpansion,
  ) {
    final w = _tableColWidths(isMobile);
    final visibleCols = TaskTableColumnService.instance.visibleColumns;
    final baseId = task.id.split('_executor_').first.split('_frota_').first;
    final taskWarnings = (widget.warningsByTaskId ?? {})[baseId] ?? [];

    return SizedBox(
      width: _calcTableWidth(isMobile),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onTaskSelected?.call(task),
          hoverColor: Colors.blue[100]!.withOpacity(0.3),
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: statusBg,
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!, width: 0.5),
                left: isExecutorRow
                    ? BorderSide(color: Colors.orange[400]!, width: 4)
                    : isFrotaRow
                    ? BorderSide(color: Colors.green[500]!, width: 4)
                    : isSubtask
                    ? BorderSide(color: Colors.blue[400]!, width: 4)
                    : BorderSide.none,
              ),
            ),
            child: SizedBox(
                width: _calcTableWidth(isMobile),
                child: Row(
                  children: [
                    if (visibleCols.contains(TaskTableColumn.acoes))
                      _buildActionsCell(task, w.acoes, isMobile),
                    if (visibleCols.contains(TaskTableColumn.status))
                      _buildStatusCell(task, w.status, isMobile, hasSubtasks, isSubtask,
                          isExecutorRow, isFrotaRow, hasExecutorPeriods, hasFrotaPeriods, isExpanded, subtasksCount, toggleExpansion),
                    if (visibleCols.contains(TaskTableColumn.local))
                      _buildCell(
                        task.locais.isNotEmpty ? task.locais.join(', ') : '',
                        w.local,
                        isMobile,
                        hasColoredBackground: statusBg != Colors.white,
                        isSubtask: isExecutorRow || isFrotaRow,
                      ),
                    if (visibleCols.contains(TaskTableColumn.tipo))
                      _buildCell(
                        task.tipo,
                        w.tipo,
                        isMobile,
                        hasColoredBackground: statusBg != Colors.white,
                        isSubtask: isExecutorRow || isFrotaRow,
                      ),
                    if (visibleCols.contains(TaskTableColumn.tarefa))
                      _buildTaskTitleCell(
                        task,
                        w.tarefa,
                        isMobile,
                        isSubtask: isSubtask,
                        isExecutorRow: isExecutorRow,
                        isFrotaRow: isFrotaRow,
                        statusBg: statusBg,
                      ),
                    if (visibleCols.contains(TaskTableColumn.executor))
                      _buildCell(
                        isFrotaRow
                            ? '—'
                            : (task.equipeExecutores?.isNotEmpty == true
                                ? '${task.equipes.isNotEmpty ? task.equipes.join(', ') : ''} (${task.equipeExecutores!.length})'
                                : task.executores.isNotEmpty ? task.executores.join(', ') : task.executor),
                        w.executor,
                        isMobile,
                        hasColoredBackground: statusBg != Colors.white,
                        maxLines: 2,
                        softWrap: true,
                        overflow: TextOverflow.fade,
                        fontWeight: isExecutorRow ? FontWeight.bold : null,
                      ),
                    if (visibleCols.contains(TaskTableColumn.coordenador))
                      _buildCell(
                        task.coordenador,
                        w.coordenador,
                        isMobile,
                        hasColoredBackground: statusBg != Colors.white,
                        isSubtask: isExecutorRow || isFrotaRow,
                      ),
                    if (visibleCols.contains(TaskTableColumn.frota))
                      isExecutorRow
                          ? _buildCell('—', w.frota, isMobile)
                          : _buildFrotaCell(task, w.frota, isMobile, statusBg),
                    if (visibleCols.contains(TaskTableColumn.chat))
                      _buildChatCell(task, w.chat, isMobile, statusBg),
                    if (visibleCols.contains(TaskTableColumn.anexos))
                      _buildIconCountCell(
                        Icons.attach_file,
                        _anexosCount[task.id] ?? 0,
                        w.anexos, isMobile, statusBg,
                      ),
                    if (visibleCols.contains(TaskTableColumn.nota))
                      _buildNotaSAPCell(task, w.notasSAP, isMobile, statusBg),
                    if (visibleCols.contains(TaskTableColumn.ordem))
                      _buildOrdemCell(task, w.ordens, isMobile, statusBg),
                    if (visibleCols.contains(TaskTableColumn.at))
                      _buildATCell(task, w.ats, isMobile, statusBg),
                    if (visibleCols.contains(TaskTableColumn.si))
                      _buildSICell(task, w.sis, isMobile, statusBg),
                    if (visibleCols.contains(TaskTableColumn.alertas))
                      _buildAlertasCell(task, w.alertas, isMobile, statusBg, taskWarnings),
                  ],
                ),
              ),
          ),
        ),
      ),
    );
  }

  // ── Células da tabela ─────────────────────────────────────────────────────

  Widget _buildCell(
    String text,
    double width,
    bool isMobile, {
    bool hasColoredBackground = false,
    bool isSubtask = false,
    int? maxLines,
    bool softWrap = false,
    TextOverflow overflow = TextOverflow.ellipsis,
    FontWeight? fontWeight,
    IconData? icon,
    Color? iconColor,
  }) {
    final cell = Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 3 : 6, vertical: isMobile ? 4 : 6),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey[300]!, width: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: isMobile ? 12 : 14, color: iconColor ?? Colors.grey[400]),
            if (text.isNotEmpty) SizedBox(width: isMobile ? 2 : 4),
          ],
          if (text.isNotEmpty)
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: isMobile ? 10 : 11,
                  color: hasColoredBackground ? Colors.grey[800] : Colors.black87,
                  fontWeight: fontWeight,
                  fontStyle: isSubtask ? FontStyle.italic : FontStyle.normal,
                ),
                overflow: overflow,
                maxLines: maxLines,
                softWrap: softWrap,
              ),
            ),
        ],
      ),
    );
    if (width > 0) return SizedBox(width: width, child: cell);
    return cell;
  }

  Widget _buildIconCountCell(IconData icon, int count, double width, bool isMobile, Color statusBg) {
    return SizedBox(
      width: width,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 3 : 6, vertical: isMobile ? 4 : 8),
        decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey[300]!, width: 0.5))),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: isMobile ? 12 : 14, color: count > 0 ? Colors.green : Colors.grey[400]),
            if (count > 0)
              Padding(
                padding: EdgeInsets.only(left: isMobile ? 2 : 4),
                child: Text('$count', style: TextStyle(fontSize: isMobile ? 9 : 10, color: statusBg != Colors.white ? Colors.grey[800] : Colors.black87)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCell(Task task, double width, bool isMobile) {
    return SizedBox(
      width: width,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 3 : 6, vertical: isMobile ? 4 : 8),
        decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey[300]!, width: 0.5))),
        child: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onSelected: (val) {
            final baseId = task.id.split('_executor_').first.split('_frota_').first;
            final originalTask = task.copyWith(id: baseId);
            
            // Extract executor ID if it's an executor row
            String? executorId;
            if (task.id.contains('_executor_')) {
              final parts = task.id.split('_executor_');
              if (parts.length > 1) {
                executorId = parts[1];
              }
            }
            
            switch (val) {
              case 'view': widget.onTaskSelected?.call(originalTask); break;
              case 'edit': widget.onEdit?.call(originalTask, executorIdToEdit: executorId); break;
              case 'delete': widget.onDelete?.call(originalTask); break;
              case 'duplicate': widget.onDuplicate?.call(originalTask); break;
              case 'subtask': widget.onCreateSubtask?.call(originalTask); break;
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'view', child: Row(children: [Icon(Icons.visibility, size: 18, color: Colors.blue), SizedBox(width: 8), Text('Visualizar')])),
            const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18, color: Colors.blue), SizedBox(width: 8), Text('Editar')])),
            const PopupMenuItem(value: 'duplicate', child: Row(children: [Icon(Icons.copy, size: 18, color: Colors.orange), SizedBox(width: 8), Text('Duplicar')])),
            if (task.isMainTask) const PopupMenuItem(value: 'subtask', child: Row(children: [Icon(Icons.add_task, size: 18, color: Colors.green), SizedBox(width: 8), Text('Inserir Subtarefa')])),
            const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Excluir')])),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCell(
    Task task, double width, bool isMobile, bool hasSubtasks, bool isSubtask,
    bool isExecutorRow, bool isFrotaRow, bool hasExecutorPeriods, bool hasFrotaPeriods,
    bool isExpanded, int subtasksCount, VoidCallback toggleExpansion,
  ) {
    final badge = _getStatusBadgeColor(task.status);
    final hasChildren = hasSubtasks || hasExecutorPeriods || hasFrotaPeriods;
    final isChildRow = isSubtask || isExecutorRow || isFrotaRow;

    return SizedBox(
      width: width,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 2 : 4, vertical: isMobile ? 4 : 8),
        decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey[300]!, width: 0.5))),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasChildren)
              IconButton(
                icon: Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: isMobile ? 16 : 18,
                  color: Colors.blue[700],
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: toggleExpansion,
              )
            else if (isChildRow)
              Padding(
                padding: EdgeInsets.only(left: isMobile ? 10 : 14),
                child: Icon(Icons.subdirectory_arrow_right, size: isMobile ? 13 : 15, color: Colors.grey[600]),
              )
            else
              const SizedBox(width: 8),
            const SizedBox(width: 4),
            Tooltip(
              message: _statusMap[task.status]?.status ?? task.status,
              child: Container(
                width: isMobile ? 10 : 12,
                height: isMobile ? 10 : 12,
                decoration: BoxDecoration(
                  color: (isExecutorRow || isFrotaRow) ? badge.withValues(alpha: 0.6) : badge,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrotaCell(Task task, double width, bool isMobile, Color statusBg) {
    final count = _frotasCount[task.id] ?? 0;
    final fallback = task.frotaIds.isNotEmpty ? task.frotaIds.length : (task.frota.isNotEmpty && task.frota != '-N/A-' ? 1 : 0);
    final computed = count > 0 ? count : fallback;
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: computed > 0 ? () => _mostrarFrotas(task) : null,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 3 : 6, vertical: isMobile ? 4 : 8),
          decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey[300]!, width: 0.5))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.local_shipping, size: isMobile ? 12 : 14, color: computed > 0 ? Colors.green : Colors.grey[400]),
            if (computed > 0) Padding(padding: EdgeInsets.only(left: isMobile ? 2 : 4), child: Text('$computed', style: TextStyle(fontSize: isMobile ? 9 : 10))),
          ]),
        ),
      ),
    );
  }

  Widget _buildChatCell(Task task, double width, bool isMobile, Color statusBg) {
    final count = _mensagensCount[task.id] ?? 0;
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: () => _abrirChatTarefa(task),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 3 : 6, vertical: isMobile ? 4 : 8),
          decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey[300]!, width: 0.5))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.chat, size: isMobile ? 12 : 14, color: count > 0 ? Colors.green : Colors.grey[400]),
            if (count > 0) Padding(padding: EdgeInsets.only(left: isMobile ? 2 : 4), child: Text('$count', style: TextStyle(fontSize: isMobile ? 9 : 10))),
          ]),
        ),
      ),
    );
  }

  Widget _buildNotaSAPCell(Task task, double width, bool isMobile, Color statusBg) {
    final count = _notasSAPCount[task.id] ?? 0;
    final naoEnc = _notasNaoEncerradas[task.id] ?? 0;
    final isConc = task.status.toUpperCase().trim() == 'CONC';
    final color = !isConc ? (count > 0 ? Colors.black87 : Colors.grey[400]!) : (count == 0 ? Colors.grey[400]! : naoEnc > 0 ? Colors.red : Colors.green);
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: () => _mostrarNotasSAP(task),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 3 : 6, vertical: isMobile ? 4 : 8),
          decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey[300]!, width: 0.5))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.description, size: isMobile ? 12 : 14, color: color),
            if (count > 0) Padding(padding: EdgeInsets.only(left: isMobile ? 2 : 4), child: Text('$count', style: TextStyle(fontSize: isMobile ? 9 : 10))),
          ]),
        ),
      ),
    );
  }

  Widget _buildOrdemCell(Task task, double width, bool isMobile, Color statusBg) {
    final count = _ordensCount[task.id] ?? 0;
    final naoEnc = _ordensNaoEncerradas[task.id] ?? 0;
    final isConc = task.status.toUpperCase().trim() == 'CONC';
    final color = !isConc ? (count > 0 ? Colors.black87 : Colors.grey[400]!) : (count == 0 ? Colors.grey[400]! : naoEnc > 0 ? Colors.red : Colors.green);
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: () => _mostrarOrdens(task),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 3 : 6, vertical: isMobile ? 4 : 8),
          decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey[300]!, width: 0.5))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.list_alt, size: isMobile ? 12 : 14, color: color),
            if (count > 0) Padding(padding: EdgeInsets.only(left: isMobile ? 2 : 4), child: Text('$count', style: TextStyle(fontSize: isMobile ? 9 : 10))),
          ]),
        ),
      ),
    );
  }

  Widget _buildATCell(Task task, double width, bool isMobile, Color statusBg) {
    final count = _atsCount[task.id] ?? 0;
    final naoEnc = _atsNaoEncerradas[task.id] ?? 0;
    final isConc = task.status.toUpperCase().trim() == 'CONC';
    final color = !isConc ? (count > 0 ? Colors.black87 : Colors.grey[400]!) : (count == 0 ? Colors.grey[400]! : naoEnc > 0 ? Colors.red : Colors.green);
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: () => _mostrarATs(task),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 3 : 6, vertical: isMobile ? 4 : 8),
          decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey[300]!, width: 0.5))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.assignment, size: isMobile ? 12 : 14, color: color),
            if (count > 0) Padding(padding: EdgeInsets.only(left: isMobile ? 2 : 4), child: Text('$count', style: TextStyle(fontSize: isMobile ? 9 : 10))),
          ]),
        ),
      ),
    );
  }

  Widget _buildSICell(Task task, double width, bool isMobile, Color statusBg) {
    final count = _sisCount[task.id] ?? 0;
    final hasSi = task.si.isNotEmpty && task.si != '-N/A-';
    final needs = task.precisaSi;
    final color = needs && !hasSi && count == 0 ? Colors.redAccent : (count > 0 || hasSi) ? Colors.teal : Colors.grey[400];
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: () => _mostrarSIs(task),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 3 : 6, vertical: isMobile ? 4 : 8),
          decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey[300]!, width: 0.5))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.description, size: isMobile ? 12 : 14, color: color),
            if (count > 0) Padding(padding: EdgeInsets.only(left: isMobile ? 2 : 4), child: Text('$count', style: TextStyle(fontSize: isMobile ? 9 : 10))),
          ]),
        ),
      ),
    );
  }

  Widget _buildAlertasCell(Task task, double width, bool isMobile, Color statusBg, List<TaskWarning> warnings) {
    return SizedBox(
      width: width,
      height: 50,
      child: WarningsBadge(
        warnings: warnings,
        isMobile: isMobile,
        rowBackgroundColor: statusBg,
        onTap: () {
          if (warnings.isEmpty) return;
          showWarningsPanel(
            context: context,
            taskTarefaLabel: task.tarefa,
            warnings: warnings,
            task: task,
            allTasks: widget.tasks,
            debugTaskId: task.id,
            debugTaskStatus: task.status,
            debugTaskStatusId: task.statusId,
            onUpdateStatus: () { if (context.mounted) { Navigator.of(context).pop(); widget.onEdit?.call(task); } },
            onAdjustDates: () { if (context.mounted) { Navigator.of(context).pop(); widget.onEdit?.call(task); } },
          );
        },
      ),
    );
  }

  // =========================================================================
  // Painel do Gantt (linha)
  // =========================================================================

  Widget _buildGanttRowPanel(
    Task task,
    int index,
    bool isSubtask,
    bool hasSubtasks,
    bool isExecutorRow,
    bool isFrotaRow,
    bool hasExecutorPeriods,
    bool hasFrotaPeriods,
    bool isExpanded,
    List<GanttPeriod> periods,
    double periodWidth,
    double totalWidth,
    double todayOffset,
    ScrollController rowController,
    VoidCallback toggleExpansion,
    List<Task> hierarchicalTasks,
  ) {
    return SizedBox(
      height: 50,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: isSubtask
                  ? Colors.blue.withValues(alpha: 0.02)
                  : isExecutorRow
                  ? Colors.orange.withValues(alpha: 0.03)
                  : isFrotaRow
                  ? Colors.green.withValues(alpha: 0.03)
                  : Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                left: isExecutorRow
                    ? BorderSide(color: Colors.orange[400]!, width: 4)
                    : isFrotaRow
                    ? BorderSide(color: Colors.green[500]!, width: 4)
                    : isSubtask
                    ? BorderSide(color: Colors.blue[400]!, width: 4)
                    : (hasSubtasks || hasExecutorPeriods || hasFrotaPeriods)
                    ? BorderSide(color: Colors.blue[200]!, width: 2)
                    : BorderSide.none,
              ),
            ),
          ),
          if ((hasSubtasks || hasExecutorPeriods || hasFrotaPeriods) && !isSubtask && !isExecutorRow && !isFrotaRow)
            Positioned(
              left: 4,
              top: 4,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: toggleExpansion,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      border: Border.all(color: Colors.blue[300]!, width: 1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(isExpanded ? Icons.expand_less : Icons.expand_more, size: 16, color: Colors.blue[700]),
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.deferToChild,
              onPointerDown: (e) {
                if (e.kind != PointerDeviceKind.mouse) return;
                if (_isSegmentBeingDragged) { _isDraggingFromEmptyArea = false; _isDragging = false; return; }
                bool onSeg = _isClickOnSegment(e.localPosition.dx, task, periods, periodWidth);
                if (!onSeg) { _isDraggingFromEmptyArea = true; _isDragging = true; _lastDragPosition = e.localPosition.dx; }
                else { _isDraggingFromEmptyArea = false; _isDragging = false; }
              },
              onPointerMove: (e) {
                if (_isSegmentBeingDragged) { _isDragging = false; _isDraggingFromEmptyArea = false; return; }
                if (_isDragging && _isDraggingFromEmptyArea && e.kind == PointerDeviceKind.mouse) {
                  final delta = (_lastDragPosition - e.localPosition.dx) * 0.2;
                  _lastDragPosition = e.localPosition.dx;
                  if (rowController.hasClients) {
                    final newOff = (rowController.offset + delta).clamp(0.0, rowController.position.maxScrollExtent);
                    _isHorizScrolling = true;
                    rowController.jumpTo(newOff);
                    if (_ganttHorizController.hasClients) _ganttHorizController.jumpTo(newOff);
                    for (var ctrl in _rowScrollControllers) {
                      if (ctrl != rowController && ctrl.hasClients) ctrl.jumpTo(newOff);
                    }
                    _isHorizScrolling = false;
                  }
                }
              },
              onPointerUp: (_) { _isDragging = false; _isDraggingFromEmptyArea = false; },
              onPointerCancel: (_) { _isDragging = false; _isDraggingFromEmptyArea = false; },
              child: SingleChildScrollView(
                controller: rowController,
                scrollDirection: Axis.horizontal,
                physics: (_isDragging && _isDraggingFromEmptyArea) ? const NeverScrollableScrollPhysics() : const ClampingScrollPhysics(),
                child: SizedBox(
                  width: totalWidth,
                  height: 50,
                  child: Stack(
                    alignment: Alignment.topLeft,
                    fit: StackFit.loose,
                    children: [
                      // Grid de dias
                      ...List.generate(periods.length, (i) {
                        final p = periods[i];
                        final isDay = widget.scale == GanttScale.daily;
                        final isWknd = isDay && _isWeekend(p.start);
                        final ferColor = isDay ? _getHolidayColorForTask(p.start, task) : null;
                        final ferTooltip = isDay ? _getHolidayTooltipForTask(p.start, task) : null;
                        Widget dayCell = Container(
                          decoration: BoxDecoration(
                            color: ferColor ?? (isWknd ? Colors.grey[200] : Colors.white),
                            border: Border.all(color: Colors.grey[300]!, width: 1),
                          ),
                        );
                        if (ferTooltip != null) {
                          dayCell = Tooltip(
                            message: ferTooltip,
                            child: dayCell,
                          );
                        }
                        return Positioned(
                          left: i * periodWidth,
                          top: 0,
                          bottom: 0,
                          width: periodWidth,
                          child: dayCell,
                        );
                      }),
                      ..._buildGroupSeparators(periods, periodWidth),
                      // Segmentos (barras)
                      ..._getRenderSegments(task).map((item) {
                        final segIdx = item.segmentIndex;
                        final seg = item.segment;
                        final start = item.start;
                        final end = item.end;

                        if (end.isBefore(widget.startDate) || start.isAfter(widget.endDate)) {
                          return const SizedBox.shrink();
                        }

                        double startOff, barW;
                        if (start.isBefore(widget.startDate)) {
                          startOff = 0;
                          final adjEnd = end.isAfter(widget.endDate) ? widget.endDate : end;
                          barW = _getBarWidthForRange(widget.startDate, adjEnd, periods, periodWidth);
                        } else {
                          startOff = _getDateOffsetFromPeriods(start, periods, periodWidth);
                          final adjEnd = end.isAfter(widget.endDate) ? widget.endDate : end;
                          barW = _getBarWidthForRange(start, adjEnd, periods, periodWidth);
                        }
                        if (startOff < 0 || barW <= 0) return const SizedBox.shrink();

                        Task? parentTask;
                        if (isSubtask && task.parentId != null) {
                          try { parentTask = hierarchicalTasks.firstWhere((t) => t.id == task.parentId); } catch (_) {}
                        }

                        final segColor = _getSegmentColorByPeriod(seg, task, parentTask: parentTask, isSubtask: isSubtask);
                        final conflictListReady = widget.tasksForConflictDetection?.isNotEmpty ?? false;
                        final backendExecReady = widget.conflictService != null && _conflictMapFromBackend != null;
                        final conflictDays = (widget.scale == GanttScale.daily && (backendExecReady || (conflictListReady && _conflictPaintReady)))
                            ? _getConflictDaysForSegment(task, start, end).toList()
                            : null;
                        final conflictDaysFrota = (widget.scale == GanttScale.daily && _conflictMapFrotaFromBackend != null)
                            ? _getConflictDaysForSegmentFrota(task, start, end).toList()
                            : null;

                        final conflictTooltipMessageByDay = <DateTime, String>{};
                        final conflictTaskIdsByDay = <DateTime, Set<String>>{};
                        if (conflictDays != null) {
                          for (final d in conflictDays) {
                            final dayNorm = DateTime(d.year, d.month, d.day);
                            final msg = _getConflictDetailsMessageForSingleDay(task, dayNorm);
                            if (msg != null && msg.isNotEmpty) {
                              conflictTooltipMessageByDay[dayNorm] = msg;
                            }
                            final ids = _getConflictTaskIdsForSingleDay(task, dayNorm);
                            if (ids.isNotEmpty) {
                              conflictTaskIdsByDay[dayNorm] = ids;
                            }
                          }
                        }

                        final conflictTooltipMessageByDayFrota = <DateTime, String>{};
                        if (conflictDaysFrota != null) {
                          for (final d in conflictDaysFrota) {
                            final dayNorm = DateTime(d.year, d.month, d.day);
                            final msg = _getFleetConflictDetailsMessageForSingleDay(task, dayNorm);
                            if (msg != null && msg.isNotEmpty) {
                              conflictTooltipMessageByDayFrota[dayNorm] = msg;
                            }
                          }
                        }

                        return Positioned(
                          left: startOff,
                          top: 0,
                          bottom: 0,
                          child: GanttSegmentWidget(
                            key: ValueKey('seg_${task.id}_${segIdx}_${item.subIndex}_cv$_conflictsVersion'),
                            task: task,
                            segmentIndex: segIdx,
                            subSegmentIndex: item.subIndex,
                            segment: seg,
                            normalizedStartDate: start,
                            normalizedEndDate: end,
                            barWidth: barW,
                            dayWidth: periodWidth,
                            periods: periods,
                            color: segColor,
                            textColor: segColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                            conflictDays: conflictDays,
                            conflictTooltipMessage: null,
                            conflictTooltipMessageByDay: conflictTooltipMessageByDay.isEmpty ? null : conflictTooltipMessageByDay,
                            conflictTaskIdsByDay: conflictTaskIdsByDay.isEmpty ? null : conflictTaskIdsByDay,
                            conflictDaysFrota: conflictDaysFrota,
                            conflictTooltipMessageFrota: null,
                            conflictTooltipMessageByDayFrota: conflictTooltipMessageByDayFrota.isEmpty ? null : conflictTooltipMessageByDayFrota,
                            taskService: widget.taskService,
                            onTasksUpdated: widget.onTasksUpdated,
                            onDragStart: _onSegmentDragStart,
                            onDragEnd: _onSegmentDragEnd,
                            conflictsVersionNotifier: _conflictsVersionNotifier,
                            onFilterConflictTasks: (Set<String> taskIds) {
                              if (widget.onFilterConflictTasks != null) {
                                widget.onFilterConflictTasks!(taskIds.isEmpty ? null : taskIds);
                              }
                            },
                            isConflictFilterActive: widget.conflictFilterTaskIds != null,
                          ),
                        );
                      }),
                      // Linha do dia atual
                      if (todayOffset >= 0)
                        Positioned(
                          left: todayOffset + (periodWidth / 2),
                          top: 0,
                          bottom: 0,
                          child: IgnorePointer(
                            ignoring: true,
                            child: Container(
                              width: 3,
                              decoration: BoxDecoration(
                                color: Colors.red[600],
                                boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.7), blurRadius: 4, spreadRadius: 1)],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_ActivityRenderSegment> _getRenderSegments(Task task) {
    final List<_ActivityRenderSegment> items = [];
    for (int i = 0; i < task.ganttSegments.length; i++) {
      final seg = task.ganttSegments[i];
      final tipoPeriodo = (seg.tipoPeriodo ?? '').toUpperCase();
      if (tipoPeriodo == 'DESLOCAMENTO') {
        final startDay = DateTime(seg.dataInicio.year, seg.dataInicio.month, seg.dataInicio.day);
        final endDay = DateTime(seg.dataFim.year, seg.dataFim.month, seg.dataFim.day);
        items.add(_ActivityRenderSegment(
          segmentIndex: i,
          subIndex: 0,
          segment: seg,
          start: startDay,
          end: startDay,
        ));
        if (endDay.isAfter(startDay)) {
          items.add(_ActivityRenderSegment(
            segmentIndex: i,
            subIndex: 1,
            segment: seg,
            start: endDay,
            end: endDay,
          ));
        }
      } else {
        final start = DateTime(seg.dataInicio.year, seg.dataInicio.month, seg.dataInicio.day);
        var end = DateTime(seg.dataFim.year, seg.dataFim.month, seg.dataFim.day);
        end = _normalizeLegacyEndDate(task, start, end);
        items.add(_ActivityRenderSegment(
          segmentIndex: i,
          subIndex: 0,
          segment: seg,
          start: start,
          end: end,
        ));
      }
    }
    return items;
  }

  bool _isClickOnSegment(double clickX, Task task, List<GanttPeriod> periods, double periodWidth) {
    for (final item in _getRenderSegments(task)) {
      final off = _getDateOffsetFromPeriods(item.start, periods, periodWidth);
      final w = _getBarWidthForRange(item.start, item.end, periods, periodWidth);
      if (clickX >= off && clickX <= off + w) return true;
    }
    return false;
  }

  void _onSegmentDragStart() => setState(() => _isSegmentBeingDragged = true);
  void _onSegmentDragEnd() => setState(() => _isSegmentBeingDragged = false);

  // =========================================================================
  // Ações das células
  // =========================================================================

  Future<void> _mostrarFrotas(Task task) async {
    final nome = _frotasNomes[task.id] ?? task.frota;
    if (!mounted) return;
    if (nome.isEmpty || nome == '-N/A-') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhuma frota vinculada')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Frota: $nome')));
  }

  Future<void> _mostrarNotasSAP(Task task) async {
    final notas = await _notaSAPService.getNotasPorTarefa(task.id);
    if (!mounted) return;
    if (notas.isNotEmpty) {
      setState(() => _notasSAPCount[task.id] = notas.length);
      _mostrarDialogNotasSAP(notas, task);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhuma nota SAP vinculada')));
    }
  }

  Future<void> _mostrarOrdens(Task task) async {
    final ordens = await _ordemService.getOrdensPorTarefa(task.id);
    if (!mounted) return;
    if (ordens.isNotEmpty) {
      setState(() => _ordensCount[task.id] = ordens.length);
      _mostrarDialogOrdens(ordens, task);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhuma ordem vinculada')));
    }
  }

  Future<void> _mostrarATs(Task task) async {
    final ats = await _atService.getATsPorTarefa(task.id);
    if (!mounted) return;
    if (ats.isNotEmpty) {
      setState(() => _atsCount[task.id] = ats.length);
      _mostrarDialogATs(ats, task);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhuma AT vinculada')));
    }
  }

  Future<void> _mostrarSIs(Task task) async {
    final sis = await _siService.getSIsPorTarefa(task.id);
    if (!mounted) return;
    if (sis.isNotEmpty) {
      setState(() => _sisCount[task.id] = sis.length);
      _mostrarDialogSIs(sis, task);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhuma SI vinculada')));
    }
  }

  Future<void> _abrirChatTarefa(Task task) async {
    try {
      final chatService = ChatService();
      GrupoChat? grupoChat = await chatService.obterGrupoPorTarefaId(task.id);
      if (grupoChat == null) {
        if (task.divisaoId != null && task.segmentoId != null) {
          final comunidade = await chatService.criarOuObterComunidade(
            task.regionalId ?? '', task.regional,
            task.divisaoId!, task.divisao.isNotEmpty ? task.divisao : 'Divisão',
            task.segmentoId!, task.segmento.isNotEmpty ? task.segmento : 'Segmento',
          );
          if (comunidade.id != null) {
            grupoChat = await chatService.criarOuObterGrupo(task.id, task.tarefa, comunidade.id!);
          }
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tarefa precisa ter divisão e segmento para abrir chat.'), backgroundColor: Colors.orange));
          return;
        }
      }
      if (mounted && grupoChat != null && grupoChat.id != null) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => ChatView(initialGrupoId: grupoChat!.id!, initialComunidadeId: grupoChat.comunidadeId),
          fullscreenDialog: true,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao abrir chat: $e'), backgroundColor: Colors.red));
    }
  }

  // =========================================================================
  // Build principal
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final ganttWidth = screenWidth * 0.5;

    final periods = _getPeriods();
    final periodWidth = _calcPeriodWidth(periods, ganttWidth);
    final totalWidth = periods.length * periodWidth;
    final todayOffset = _getTodayOffset(periods, periodWidth);

    // Inicializar scroll para o período selecionado na primeira vez
    if (!_hasInitializedScroll && periods.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final target = _getDateOffsetFromPeriods(widget.startDate, periods, periodWidth);
        if (target >= 0 && _ganttHorizController.hasClients) {
          final scrollTo = (target - periodWidth * 2).clamp(0.0, _ganttHorizController.position.maxScrollExtent);
          _ganttHorizController.jumpTo(scrollTo);
        }
        _hasInitializedScroll = true;
      });
    }

    final hierarchicalTasks = _buildHierarchicalTasks();
    print('📊 [DEBUG-GANTT-VIEW] build: widget.tasks=${widget.tasks.length}, isLoading=${widget.isLoading}, hierarchicalTasks=${hierarchicalTasks.length}, showEmpty=$_showEmptyMessage, periods=${periods.length}, totalWidth=$totalWidth');

    if (hierarchicalTasks.isEmpty) {
      print('⚠️ [DEBUG-GANTT-VIEW] hierarchicalTasks está VAZIO! Exibindo loading? (${!_showEmptyMessage || widget.isLoading})');
      if (!_showEmptyMessage || widget.isLoading) {
        return const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(height: 8),
            Text('Carregando tarefas...'),
          ]),
        );
      }
      return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Nenhuma tarefa encontrada')));
    }

    print('🚀 [DEBUG-GANTT-VIEW] Montando Column com Row (Header) e ListView (${hierarchicalTasks.length} linhas)...');

    return Column(
      children: [
        // ── Barra de progresso de carregamento ──────────────────────────────
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: widget.isLoading
              ? SizedBox(
                  key: const ValueKey('loading'),
                  height: 3,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                )
              : const SizedBox(key: ValueKey('idle'), height: 3),
        ),
        // ── Cabeçalho unificado ──────────────────────────────────────────────
        Row(
          children: [
            // Cabeçalho da tabela
            SizedBox(
              width: _calcTableWidth(isMobile),
              child: _buildTableHeader(isMobile),
            ),
            Container(width: 1, color: Colors.grey[300]),
            // Cabeçalho do Gantt
            Expanded(child: _buildGanttHeader(periods, periodWidth, totalWidth, todayOffset)),
          ],
        ),
        // ── Corpo: único ListView vertical ───────────────────────────────────
        Expanded(
          child: ListView.builder(
            controller: _verticalController,
            itemCount: hierarchicalTasks.length,
            itemBuilder: (ctx, index) {
              if (index == 0) {
                print('🛠️ [DEBUG-GANTT-VIEW] Renderizando primeiro item do ListView (index 0): ${hierarchicalTasks[0].tarefa}');
              }
              return RepaintBoundary(
                child: _buildUnifiedRow(
                  ctx, hierarchicalTasks[index], index, hierarchicalTasks,
                  periods, periodWidth, totalWidth, todayOffset, ganttWidth, isMobile,
                ),
              );
            },
          ),
        ),
        // ── Barra de Rolagem Horizontal Inferior (Sincronizada) ──────────────
        if (hierarchicalTasks.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[300]!, width: 1)),
            ),
            child: Row(
              children: [
                SizedBox(width: _calcTableWidth(isMobile)),
                Expanded(
                  child: Container(
                    height: 18,
                    color: Colors.grey[50],
                    child: Scrollbar(
                      controller: _ganttBottomHorizController,
                      thickness: 10,
                      radius: const Radius.circular(5),
                      child: SingleChildScrollView(
                        controller: _ganttBottomHorizController,
                        scrollDirection: Axis.horizontal,
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: SizedBox(width: totalWidth, height: 18),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
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
    await ClipboardHelper.copyAndNotify(
      context,
      texto,
      successMessage: mensagemSucesso,
      errorMessage: 'Não foi possível copiar o texto.',
      duration: const Duration(seconds: 1),
    );
  }

  Color _getStatusUsuarioColor(String? statusUsuario) {
    if (statusUsuario == null || statusUsuario.isEmpty) return Colors.grey;
    final status = statusUsuario.toUpperCase();
    if (status.contains('CONC')) return Colors.green;
    if (status.contains('CADU') || status.contains('CAIM')) return Colors.grey;
    if (status.contains('REGI')) return Colors.orange;
    if (status.contains('EMAM')) return Colors.yellow[700] ?? Colors.amber;
    if (status.contains('ANLS')) return Colors.blue;
    return Colors.grey;
  }

  Color _getStatusUsuarioTextColor(String? statusUsuario) {
    if (statusUsuario == null || statusUsuario.isEmpty) return Colors.white;
    final status = statusUsuario.toUpperCase();
    if (status.contains('EMAM')) return Colors.black;
    return Colors.white;
  }

  Color _getStatusSistemaColor(String? statusSistema) {
    if (statusSistema == null || statusSistema.isEmpty) return Colors.grey;
    final status = statusSistema.toUpperCase();
    if (status.contains('MSPR')) return Colors.orange;
    if (status.contains('MSPN')) return Colors.blue;
    if (status.contains('MECE') || status.contains('CONC')) return Colors.green;
    return const Color(0xFF1E3A5F);
  }

  Widget _buildNotaSAPCard(NotaSAP nota, int index) {
    final statusSis = nota.statusSistema?.trim();
    final statusUsu = nota.statusUsuario?.trim();
    final sala = nota.sala?.trim();
    final descricao = nota.descricao?.trim();
    final local = nota.localInstalacao?.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: EdgeInsets.zero,
        leading: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A5F).withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.description_outlined, color: Color(0xFF1E3A5F), size: 20),
        ),
        title: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Nota: ${nota.nota}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF1E3A5F),
                      ),
                    ),
                    if (nota.tipo != null && nota.tipo!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          nota.tipo!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                    if (statusSis != null && statusSis.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getStatusSistemaColor(statusSis).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _getStatusSistemaColor(statusSis).withOpacity(0.4),
                          ),
                        ),
                        child: Text(
                          statusSis,
                          style: TextStyle(
                            color: _getStatusSistemaColor(statusSis),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (statusUsu != null && statusUsu.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getStatusUsuarioColor(statusUsu),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          statusUsu,
                          style: TextStyle(
                            color: _getStatusUsuarioTextColor(statusUsu),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    if (sala != null && sala.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.indigo.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.indigo.withOpacity(0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.meeting_room_outlined, size: 13, color: Colors.indigo),
                            const SizedBox(width: 4),
                            Text(
                              'Sala: $sala',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.indigo,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (descricao != null && descricao.isNotEmpty)
                      Text(
                        descricao,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[850],
                        ),
                      ),
                    if (local != null && local.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_on_outlined, size: 13, color: Colors.grey[700]),
                            const SizedBox(width: 4),
                            Text(
                              local,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18, color: Colors.blue),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _copiarParaAreaTransferencia(nota.nota, 'Nota copiada!'),
                tooltip: 'Copiar nota',
              ),
            ],
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 1),
                const SizedBox(height: 12),
                _buildInfoRowModern('Tipo', nota.tipo),
                _buildInfoRowModern('Status Sistema', nota.statusSistema),
                _buildInfoRowModern('Status Usuário', nota.statusUsuario),
                _buildInfoRowModern('Descrição', nota.descricao),
                _buildInfoRowModern('Detalhes', nota.detalhes),
                _buildInfoRowModern('Local Instalação', nota.localInstalacao),
                _buildInfoRowModern('Sala', nota.sala),
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
    final statusSis = ordem.statusSistema?.trim();
    final statusUsu = ordem.statusUsuario?.trim();
    final sala = ordem.sala?.trim();
    final descricao = (ordem.textoBreve?.trim().isNotEmpty == true)
        ? ordem.textoBreve!.trim()
        : ordem.denominacaoObjeto?.trim();
    final local = (ordem.localInstalacao?.trim().isNotEmpty == true)
        ? ordem.localInstalacao!.trim()
        : (ordem.denominacaoLocalInstalacao?.trim().isNotEmpty == true
            ? ordem.denominacaoLocalInstalacao!.trim()
            : ordem.local?.trim());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.orange.withOpacity(0.25)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: EdgeInsets.zero,
        leading: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.receipt_long_outlined, color: Colors.orange, size: 20),
        ),
        title: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Ordem: ${ordem.ordem}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFFE65100),
                      ),
                    ),
                    if (ordem.tipo != null && ordem.tipo!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          ordem.tipo!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                    if (statusSis != null && statusSis.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getStatusSistemaColor(statusSis).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _getStatusSistemaColor(statusSis).withOpacity(0.4),
                          ),
                        ),
                        child: Text(
                          statusSis,
                          style: TextStyle(
                            color: _getStatusSistemaColor(statusSis),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (statusUsu != null && statusUsu.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getStatusUsuarioColor(statusUsu),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          statusUsu,
                          style: TextStyle(
                            color: _getStatusUsuarioTextColor(statusUsu),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    if (sala != null && sala.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.indigo.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.indigo.withOpacity(0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.meeting_room_outlined, size: 13, color: Colors.indigo),
                            const SizedBox(width: 4),
                            Text(
                              'Sala: $sala',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.indigo,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (descricao != null && descricao.isNotEmpty)
                      Text(
                        descricao,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[850],
                        ),
                      ),
                    if (local != null && local.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_on_outlined, size: 13, color: Colors.grey[700]),
                            const SizedBox(width: 4),
                            Text(
                              local,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18, color: Colors.blue),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _copiarParaAreaTransferencia(ordem.ordem, 'Ordem copiada!'),
                tooltip: 'Copiar ordem',
              ),
            ],
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 1),
                const SizedBox(height: 12),
                _buildInfoRowModern('Tipo', ordem.tipo),
                _buildInfoRowModern('Status Sistema', ordem.statusSistema),
                _buildInfoRowModern('Status Usuário', ordem.statusUsuario),
                _buildInfoRowModern('Texto Breve', ordem.textoBreve),
                _buildInfoRowModern('Denominação Local', ordem.denominacaoLocalInstalacao),
                _buildInfoRowModern('Denominação Objeto', ordem.denominacaoObjeto),
                _buildInfoRowModern('Local Instalação', ordem.localInstalacao),
                _buildInfoRowModern('Sala', ordem.sala),
                _buildInfoRowModern('Local', ordem.local),
                _buildInfoRowModern('Código SI', ordem.codigoSI),
                _buildInfoRowModern('GPM', ordem.gpm),
                if (ordem.inicioBase != null)
                  _buildInfoRowModern('Início Base', _formatDate(ordem.inicioBase!)),
                if (ordem.fimBase != null)
                  _buildInfoRowModern('Fim Base', _formatDate(ordem.fimBase!)),
                if (ordem.tolerancia != null)
                  _buildInfoRowModern('Tolerância', _formatDate(ordem.tolerancia!)),
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


  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

}

/// Larguras das colunas da tabela (centralizado).
class _TableColWidths {
  final double acoes;
  final double status;
  final double local;
  final double tipo;
  final double tarefa;
  final double executor;
  final double coordenador;
  final double frota;
  final double chat;
  final double anexos;
  final double notasSAP;
  final double ordens;
  final double ats;
  final double sis;
  final double alertas;

  _TableColWidths(bool isMobile)
      : acoes = TaskTableColumn.acoes.width(isMobile),
        status = TaskTableColumn.status.width(isMobile),
        local = TaskTableColumn.local.width(isMobile),
        tipo = TaskTableColumn.tipo.width(isMobile),
        tarefa = TaskTableColumn.tarefa.width(isMobile),
        executor = TaskTableColumn.executor.width(isMobile),
        coordenador = TaskTableColumn.coordenador.width(isMobile),
        frota = TaskTableColumn.frota.width(isMobile),
        chat = TaskTableColumn.chat.width(isMobile),
        anexos = TaskTableColumn.anexos.width(isMobile),
        notasSAP = TaskTableColumn.nota.width(isMobile),
        ordens = TaskTableColumn.ordem.width(isMobile),
        ats = TaskTableColumn.at.width(isMobile),
        sis = TaskTableColumn.si.width(isMobile),
        alertas = TaskTableColumn.alertas.width(isMobile);

  double get total => TaskTableColumnService.instance.calculateTotalWidth(false);
}

class _ActivityRenderSegment {
  final int segmentIndex;
  final int subIndex;
  final GanttSegment segment;
  final DateTime start;
  final DateTime end;

  const _ActivityRenderSegment({
    required this.segmentIndex,
    required this.subIndex,
    required this.segment,
    required this.start,
    required this.end,
  });
}

