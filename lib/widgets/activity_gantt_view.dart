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
import '../models/task.dart';
import '../models/status.dart';
import '../models/feriado.dart';
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
  final bool? allSubtasksExpanded;
  final VoidCallback? onToggleAllSubtasks;
  final Set<String>? expandedTasks;
  final Function(String, bool)? onTaskExpanded;
  final String? sortColumn;
  final Function(Task)? getSortValue;
  final Function(Task)? onTaskSelected;
  final Function(Task)? onEdit;
  final Function(Task)? onDelete;
  final Function(Task)? onDuplicate;
  final Function(Task)? onCreateSubtask;
  final Map<String, List<TaskWarning>>? warningsByTaskId;
  final bool isLoading;
  final VoidCallback? onTasksUpdated;
  final VoidCallback? onConflictsLoaded;

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
  });

  @override
  State<ActivityGanttView> createState() => _ActivityGanttViewState();
}

class _ActivityGanttViewState extends State<ActivityGanttView> {
  // ── Scroll ────────────────────────────────────────────────────────────────
  final ScrollController _verticalController = ScrollController();
  final ScrollController _ganttHorizController = ScrollController();
  final ScrollController _ganttHeaderHorizController = ScrollController();
  final ScrollController _tableHeaderHorizController = ScrollController();
  final ScrollController _tableBodyHorizController = ScrollController();
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
  Map<DateTime, List<Feriado>> _feriadosMap = {};

  // ── Conflitos ─────────────────────────────────────────────────────────────
  Map<String, ConflictInfo>? _conflictMapFromBackend;
  Map<String, List<ExecutionEventFromBackend>>? _eventsByDayFromBackend;
  Map<String, ConflictInfo>? _conflictMapFrotaFromBackend;
  Map<String, List<FleetExecutionEventFromBackend>>? _fleetEventsByDayFromBackend;
  bool _useBackendConflicts = false;
  bool _useFleetConflictBackend = false;
  bool _conflictPaintReady = false;
  int _conflictsVersion = 0;
  late ValueNotifier<int> _conflictsVersionNotifier;
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
    _conflictsVersionNotifier = ValueNotifier<int>(_conflictsVersion);

    _displayStartDate = widget.startDate.subtract(const Duration(days: 365));
    _displayEndDate = widget.endDate.add(const Duration(days: 365));

    // Sincronizar scroll horizontal entre cabeçalho e linhas
    _ganttHorizController.addListener(_syncGanttHorizScroll);

    // Cabeçalho da tabela segue o corpo
    _tableBodyHorizController.addListener(() {
      if (!_tableHeaderHorizController.hasClients) return;
      try {
        final max = _tableHeaderHorizController.position.maxScrollExtent;
        final target = _tableBodyHorizController.offset.clamp(0.0, max);
        _tableHeaderHorizController.jumpTo(target);
      } catch (_) {}
    });

    _loadStatus();
    _loadCounts();
    _loadAllSubtasks();
    _loadTiposAtividade();
    _loadFeriados();

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _conflictPaintReady = true;
        });
      }
    });
  }

  @override
  void didUpdateWidget(ActivityGanttView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Recarregar quando as tarefas mudarem
    final tasksChanged =
        oldWidget.tasks.length != widget.tasks.length ||
        oldWidget.tasks.map((t) => t.id).join(',') !=
            widget.tasks.map((t) => t.id).join(',');

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

    // Sincronizar expansão global
    if (oldWidget.allSubtasksExpanded != widget.allSubtasksExpanded) {
      final mainTasks = widget.tasks.where((t) => t.parentId == null).toList();
      final toToggle = <String>[];
      for (var task in mainTasks) {
        final hasSubs = (_loadedSubtasks[task.id]?.isNotEmpty ?? false);
        final hasExec = task.executorPeriods.isNotEmpty;
        if (hasSubs || hasExec) toToggle.add(task.id);
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
    if (oldWidget.startDate != widget.startDate ||
        oldWidget.endDate != widget.endDate ||
        oldWidget.scale != widget.scale) {
      _hasInitializedScroll = false;
      _loadFeriados();
      if (widget.conflictService != null) _loadBackendConflicts();
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
    }
  }

  @override
  void dispose() {
    _conflictsVersionNotifier.dispose();
    _syncStreamSub?.cancel();
    _statusChangeSubscription?.cancel();
    _emptyTimer?.cancel();
    _verticalController.dispose();
    _ganttHorizController.removeListener(_syncGanttHorizScroll);
    _ganttHorizController.dispose();
    _ganttHeaderHorizController.dispose();
    _tableHeaderHorizController.dispose();
    _tableBodyHorizController.dispose();
    for (var ctrl in _rowScrollControllers) {
      ctrl.dispose();
    }
    super.dispose();
  }

  // =========================================================================
  // Scroll
  // =========================================================================

  void _syncGanttHorizScroll() {
    if (_isHorizScrolling) return;
    if (!_ganttHorizController.hasClients) return;
    final offset = _ganttHorizController.offset;

    _isHorizScrolling = true;
    // Sincronizar cabeçalho do gantt
    if (_ganttHeaderHorizController.hasClients) {
      try {
        _ganttHeaderHorizController.jumpTo(
          offset.clamp(0.0, _ganttHeaderHorizController.position.maxScrollExtent),
        );
      } catch (_) {}
    }
    // Sincronizar todas as linhas
    for (var ctrl in _rowScrollControllers) {
      if (ctrl.hasClients && (ctrl.offset - offset).abs() > 1.0) {
        try {
          ctrl.jumpTo(offset.clamp(0.0, ctrl.position.maxScrollExtent));
        } catch (_) {}
      }
    }
    _isHorizScrolling = false;
  }

  ScrollController _getRowController(int index) {
    while (_rowScrollControllers.length <= index) {
      final ctrl = ScrollController();
      ctrl.addListener(() {
        if (_isHorizScrolling || !ctrl.hasClients) return;
        final offset = ctrl.offset;
        if (_ganttHorizController.hasClients &&
            (_ganttHorizController.offset - offset).abs() > 1.0) {
          _isHorizScrolling = true;
          _ganttHorizController.jumpTo(
            offset.clamp(0.0, _ganttHorizController.position.maxScrollExtent),
          );
          if (_ganttHeaderHorizController.hasClients) {
            try {
              _ganttHeaderHorizController.jumpTo(
                offset.clamp(0.0, _ganttHeaderHorizController.position.maxScrollExtent),
              );
            } catch (_) {}
          }
          for (var other in _rowScrollControllers) {
            if (other != ctrl && other.hasClients) {
              try {
                other.jumpTo(
                  offset.clamp(0.0, other.position.maxScrollExtent),
                );
              } catch (_) {}
            }
          }
          _isHorizScrolling = false;
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
    _emptyTimer = Timer(const Duration(seconds: 15), () {
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
      if (mounted) setState(() => _feriadosMap = map);
    } catch (e) {
      debugPrint('ActivityGanttView: erro ao carregar feriados: $e');
    }
  }

  Future<void> _loadAllSubtasks({bool forceReload = false}) async {
    if (widget.taskService == null) return;
    final mainTasks = widget.tasks.where((t) => t.parentId == null).toList();
    for (var task in mainTasks) {
      if (forceReload || !_loadedSubtasks.containsKey(task.id)) {
        try {
          final subtasks = await widget.taskService!.getSubtasks(task.id);
          if (!mounted) return;
          setState(() {
            _loadedSubtasks[task.id] = subtasks;
            if (_allSubtasksExpanded) _expandedTasks.add(task.id);
          });
        } catch (e) {
          debugPrint('ActivityGanttView: erro subtarefas ${task.id}: $e');
        }
      }
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

      // Nomes das frotas
      final frotasCountMap = results[6] as Map<String, int>;
      final frotasNomesMap = <String, String>{};
      for (var task in widget.tasks) {
        if ((frotasCountMap[task.id] ?? 0) > 0) {
          if (task.frota.isNotEmpty && task.frota != '-N/A-') {
            frotasNomesMap[task.id] = task.frota;
          } else {
            try {
              final nome = await _frotaService.getFrotaNomePorTarefa(task.id);
              if (nome != null) frotasNomesMap[task.id] = nome;
            } catch (_) {}
          }
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
    final cs = widget.conflictService;
    if (cs == null) return;
    final ok = await cs.isBackendAvailable();
    Map<String, ConflictInfo>? map;
    Map<String, List<ExecutionEventFromBackend>>? events;
    if (ok) {
      map = await cs.getConflictsForRange(_displayStartDate, _displayEndDate);
      events = await cs.getExecutionEventsForRange(_displayStartDate, _displayEndDate);
    }
    final fleetOk = await cs.isFleetConflictBackendAvailable();
    Map<String, ConflictInfo>? fleetMap;
    Map<String, List<FleetExecutionEventFromBackend>>? fleetEvents;
    if (fleetOk) {
      fleetMap = await cs.getFleetConflictsForRange(_displayStartDate, _displayEndDate);
      fleetEvents = await cs.getFleetExecutionEventsForRange(_displayStartDate, _displayEndDate);
    }
    if (!mounted) return;
    setState(() {
      _conflictMapFromBackend = map;
      _eventsByDayFromBackend = events;
      _useBackendConflicts = ok;
      _conflictMapFrotaFromBackend = fleetMap;
      _fleetEventsByDayFromBackend = fleetEvents;
      _useFleetConflictBackend = fleetOk;
      _conflictsVersion++;
    });
    _conflictsVersionNotifier.value = _conflictsVersion;
    widget.onConflictsLoaded?.call();
  }

  // =========================================================================
  // Lista hierárquica (única fonte de verdade)
  // =========================================================================

  List<Task> _buildHierarchicalTasks() {
    final List<Task> result = [];
    final mainTasks = widget.tasks.where((t) => t.parentId == null).toList();

    for (final main in mainTasks) {
      result.add(main);
      final isExpanded = _expandedTasks.contains(main.id);

      if (isExpanded && _loadedSubtasks.containsKey(main.id)) {
        result.addAll(_loadedSubtasks[main.id]!);
      }

      if (isExpanded) {
        final _addedExecutors = <String>{};

        if (main.executorPeriods.isNotEmpty) {
          for (var ep in main.executorPeriods) {
            _addedExecutors.add(ep.executorId);
            DateTime? minDate, maxDate;
            for (var p in ep.periods) {
              if (minDate == null || p.dataInicio.isBefore(minDate)) minDate = p.dataInicio;
              if (maxDate == null || p.dataFim.isAfter(maxDate)) maxDate = p.dataFim;
            }
            result.add(Task(
              id: '${main.id}_executor_${ep.executorId}',
              parentId: main.id,
              statusId: main.statusId,
              regionalId: main.regionalId,
              divisaoId: main.divisaoId,
              segmentoId: main.segmentoId,
              localIds: main.localIds,
              executorIds: [ep.executorId],
              equipeIds: main.equipeIds,
              localId: main.localId,
              equipeId: main.equipeId,
              status: main.status,
              statusNome: main.statusNome,
              regional: main.regional,
              divisao: main.divisao,
              locais: main.locais,
              tipo: main.tipo,
              ordem: main.ordem,
              tarefa: '${ep.executorNome} - ${main.tarefa}',
              executores: [ep.executorNome],
              equipes: main.equipes,
              executor: ep.executorNome,
              frota: main.frota,
              coordenador: main.coordenador,
              si: main.si,
              dataInicio: minDate ?? main.dataInicio,
              dataFim: maxDate ?? main.dataFim,
              ganttSegments: ep.periods,
              executorPeriods: const [],
              observacoes: main.observacoes,
              horasPrevistas: main.horasPrevistas,
              horasExecutadas: main.horasExecutadas,
              prioridade: main.prioridade,
            ));
          }
        }

        if (main.executorIds.isNotEmpty) {
          for (int i = 0; i < main.executorIds.length; i++) {
            final exId = main.executorIds[i];
            if (_addedExecutors.contains(exId)) continue;
            final exName = i < main.executores.length ? main.executores[i] : 'Executor';
            result.add(Task(
              id: '${main.id}_executor_$exId',
              parentId: main.id,
              statusId: main.statusId,
              regionalId: main.regionalId,
              divisaoId: main.divisaoId,
              segmentoId: main.segmentoId,
              localIds: main.localIds,
              executorIds: [exId],
              equipeIds: main.equipeIds,
              localId: main.localId,
              equipeId: main.equipeId,
              status: main.status,
              statusNome: main.statusNome,
              regional: main.regional,
              divisao: main.divisao,
              locais: main.locais,
              tipo: main.tipo,
              ordem: main.ordem,
              tarefa: '$exName - ${main.tarefa}',
              executores: [exName],
              equipes: main.equipes,
              executor: exName,
              frota: main.frota,
              coordenador: main.coordenador,
              si: main.si,
              dataInicio: main.dataInicio,
              dataFim: main.dataFim,
              ganttSegments: main.ganttSegments, // Herda do main
              executorPeriods: const [],
              observacoes: main.observacoes,
              horasPrevistas: main.horasPrevistas,
              horasExecutadas: main.horasExecutadas,
              prioridade: main.prioridade,
            ));
          }
        }

        final _addedFrotas = <String>{};

        if (main.frotaPeriods.isNotEmpty) {
          for (var fp in main.frotaPeriods) {
            _addedFrotas.add(fp.frotaId);
            DateTime? minDate, maxDate;
            for (var p in fp.periods) {
              if (minDate == null || p.dataInicio.isBefore(minDate)) minDate = p.dataInicio;
              if (maxDate == null || p.dataFim.isAfter(maxDate)) maxDate = p.dataFim;
            }
            result.add(Task(
              id: '${main.id}_frota_${fp.frotaId}',
              parentId: main.id,
              statusId: main.statusId,
              regionalId: main.regionalId,
              divisaoId: main.divisaoId,
              segmentoId: main.segmentoId,
              localIds: main.localIds,
              executorIds: main.executorIds,
              equipeIds: main.equipeIds,
              frotaIds: [fp.frotaId],
              localId: main.localId,
              equipeId: main.equipeId,
              status: main.status,
              statusNome: main.statusNome,
              regional: main.regional,
              divisao: main.divisao,
              locais: main.locais,
              tipo: main.tipo,
              ordem: main.ordem,
              tarefa: '${fp.frotaNome} - ${main.tarefa}',
              executores: main.executores,
              equipes: main.equipes,
              executor: main.executor,
              frota: fp.frotaNome,
              coordenador: main.coordenador,
              si: main.si,
              dataInicio: minDate ?? main.dataInicio,
              dataFim: maxDate ?? main.dataFim,
              ganttSegments: fp.periods,
              executorPeriods: const [],
              frotaPeriods: const [],
              observacoes: main.observacoes,
              horasPrevistas: main.horasPrevistas,
              horasExecutadas: main.horasExecutadas,
              prioridade: main.prioridade,
            ));
          }
        }

        if (main.frotaIds.isNotEmpty) {
          for (int i = 0; i < main.frotaIds.length; i++) {
            final fId = main.frotaIds[i];
            if (_addedFrotas.contains(fId)) continue;
            // The frota name can be retrieved from existing lists if there are lists. But currently we just use the name from main if it's there.
            // Wait, we need the actual name of the frota. ActivityGanttView has `_frotasNomes`.
            // But we can just pass the generic name from main or use ID. _buildTableRowPanel looks up the name!
            result.add(Task(
              id: '${main.id}_frota_$fId',
              parentId: main.id,
              statusId: main.statusId,
              regionalId: main.regionalId,
              divisaoId: main.divisaoId,
              segmentoId: main.segmentoId,
              localIds: main.localIds,
              executorIds: main.executorIds,
              equipeIds: main.equipeIds,
              frotaIds: [fId],
              localId: main.localId,
              equipeId: main.equipeId,
              status: main.status,
              statusNome: main.statusNome,
              regional: main.regional,
              divisao: main.divisao,
              locais: main.locais,
              tipo: main.tipo,
              ordem: main.ordem,
              tarefa: 'Frota - ${main.tarefa}',
              executores: main.executores,
              equipes: main.equipes,
              executor: main.executor,
              frota: main.frota,
              coordenador: main.coordenador,
              si: main.si,
              dataInicio: main.dataInicio,
              dataFim: main.dataFim,
              ganttSegments: main.ganttSegments, // Herda do main
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
      result.add(GanttPeriod(
        start: cur,
        end: cur.add(const Duration(days: 1)),
        label: '${cur.day}',
        groupLabel: '$month/${cur.year}',
      ));
      cur = cur.add(const Duration(days: 1));
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
      cur = periodEnd;
    }
    return result;
  }

  DateTime _getPeriodEnd(DateTime start, GanttScale scale) {
    switch (scale) {
      case GanttScale.weekly:
        return start.add(const Duration(days: 7));
      case GanttScale.biweekly:
        return start.add(const Duration(days: 14));
      case GanttScale.monthly:
        return DateTime(start.year, start.month + 1, 1);
      case GanttScale.quarterly:
        final endMonth = ((start.month - 1) ~/ 3 + 1) * 3;
        return DateTime(start.year, endMonth + 1, 1);
      case GanttScale.semiAnnual:
        final endMonth = start.month <= 6 ? 6 : 12;
        return DateTime(start.year, endMonth + 1, 1);
      default:
        return start.add(const Duration(days: 1));
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
      if (!normalized.isBefore(ps) && !normalized.isAfter(pe)) {
        return i * periodWidth;
      }
    }
    return -1;
  }

  double _getBarWidthForRange(DateTime start, DateTime end, List<GanttPeriod> periods, double periodWidth) {
    int count = 0;
    for (var p in periods) {
      final ps = DateTime(p.start.year, p.start.month, p.start.day);
      final pe = DateTime(p.end.year, p.end.month, p.end.day);
      if (!pe.isBefore(start) && !ps.isAfter(end)) count++;
    }
    return count * periodWidth;
  }

  double _getTodayOffset(List<GanttPeriod> periods, double periodWidth) {
    final today = DateTime.now();
    return _getDateOffsetFromPeriods(today, periods, periodWidth);
  }

  bool _isWeekend(DateTime date) => date.weekday == 6 || date.weekday == 7;
  bool _isFeriado(DateTime date) {
    final n = DateTime(date.year, date.month, date.day);
    return _feriadosMap.containsKey(n);
  }

  DateTime _normalizeLegacyEndDate(Task task, DateTime start, DateTime end) {
    final cutoff = DateTime(2026, 2, 15);
    final isLegacy = task.dataAtualizacao == null || task.dataAtualizacao!.isBefore(cutoff);
    if (!isLegacy) return end;
    if (end.isAfter(start) && end.difference(start).inDays > 0) {
      return end.subtract(const Duration(days: 1));
    }
    return end;
  }

  // =========================================================================
  // Cores
  // =========================================================================

  Color _getStatusBackgroundColor(String status) {
    if (status == 'ANDA' || status == 'PROG') return Colors.white;
    final s = _statusMap[status];
    if (s != null) {
      if (s.codigo == 'ANDA' || s.codigo == 'PROG') return Colors.white;
      return s.color.withOpacity(0.15);
    }
    return Colors.white;
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
      if (_conflictMapFromBackend == null) return false;
      if (!_uuidRegex.hasMatch(executorId.trim())) return false;
      final key = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      return _conflictMapFromBackend!['${executorId}_$key']?.hasConflict ?? false;
    }
    return ConflictDetection.hasConflictOnDayForExecutor(_taskList, day, executorId, _taskList);
  }

  bool _hasConflictOnDayForFrota(DateTime day, String frotaId) {
    if (_conflictMapFrotaFromBackend == null) return false;
    final key = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    return _conflictMapFrotaFromBackend!['${frotaId}_$key']?.hasConflict ?? false;
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

  // =========================================================================
  // Builders de cabeçalho
  // =========================================================================

  Widget _buildTableHeader(bool isMobile) {
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
          child: Center(
            child: Text(
              'ATIVIDADES',
              style: TextStyle(
                fontSize: isMobile ? 9 : 10,
                fontWeight: FontWeight.w600,
                color: Colors.grey[500],
                letterSpacing: 1.0,
              ),
            ),
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
                  _buildTableHeaderCell('AÇÕES', _tableColWidths(isMobile).acoes, isMobile),
                  _buildTableHeaderCell('STATUS', _tableColWidths(isMobile).status, isMobile),
                  _buildTableHeaderCell('LOCAL', _tableColWidths(isMobile).local, isMobile),
                  _buildTableHeaderCell('TIPO', _tableColWidths(isMobile).tipo, isMobile),
                  _buildTableHeaderCell('TAREFA', _tableColWidths(isMobile).tarefa, isMobile),
                  _buildTableHeaderCell('EXECUTOR', _tableColWidths(isMobile).executor, isMobile),
                  _buildTableHeaderCell('COORDENADOR', _tableColWidths(isMobile).coordenador, isMobile),
                  _buildTableHeaderCell('FROTA', _tableColWidths(isMobile).frota, isMobile),
                  _buildTableHeaderCell('CHAT', _tableColWidths(isMobile).chat, isMobile),
                  _buildTableHeaderCell('ANEXOS', _tableColWidths(isMobile).anexos, isMobile),
                  _buildTableHeaderCell('NOTA', _tableColWidths(isMobile).notasSAP, isMobile),
                  _buildTableHeaderCell('ORDEM', _tableColWidths(isMobile).ordens, isMobile),
                  _buildTableHeaderCell('AT', _tableColWidths(isMobile).ats, isMobile),
                  _buildTableHeaderCell('SI', _tableColWidths(isMobile).sis, isMobile),
                  _buildTableHeaderCell('ALERTAS', _tableColWidths(isMobile).alertas, isMobile),
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
                      final isFeriado = isDay && _isFeriado(p.start);
                      return Positioned(
                        left: i * periodWidth,
                        top: 0,
                        bottom: 0,
                        width: periodWidth,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isFeriado ? Colors.purple[100] : isWeekend ? Colors.grey[200] : Colors.white,
                            border: Border.all(color: Colors.grey[300]!, width: 1),
                          ),
                          alignment: Alignment.center,
                          child: Text(p.label, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                        ),
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
    final isSubtask = task.parentId != null;
    final subtasksCount = _loadedSubtasks[task.id]?.length ?? 0;
    final hasSubtasks = subtasksCount > 0;
    final isExecutorRow = task.id.contains('_executor_');
    final isFrotaRow = task.id.contains('_frota_');
    final hasExecutorPeriods = !isSubtask && !isExecutorRow && task.executorPeriods.isNotEmpty;
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
                hasExecutorPeriods, isExpanded, statusBg, subtasksCount, toggleExpansion,
              ),
              // ── Divisor visual ────────────────────────────────────────────
              Container(width: 1, color: Colors.grey[300]),
              // ── Painel do Gantt (scroll horizontal) ───────────────────────
              Expanded(
                child: _buildGanttRowPanel(
                  task, index, isSubtask, hasSubtasks, isExecutorRow, hasExecutorPeriods,
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

  _TableColWidths _tableColWidths(bool isMobile) => _TableColWidths(isMobile);
  double _calcTableWidth(bool isMobile) => _tableColWidths(isMobile).total;

  Widget _buildTableRowPanel(
    Task task,
    bool isMobile,
    bool isSubtask,
    bool hasSubtasks,
    bool isExecutorRow,
    bool isFrotaRow,
    bool hasExecutorPeriods,
    bool isExpanded,
    Color statusBg,
    int subtasksCount,
    VoidCallback toggleExpansion,
  ) {
    final w = _tableColWidths(isMobile);
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
                    ? BorderSide(color: Colors.orange[400]!, width: 3)
                    : isFrotaRow
                    ? BorderSide(color: Colors.green[400]!, width: 3)
                    : isSubtask
                    ? BorderSide(color: Colors.blue[300]!, width: 3)
                    : BorderSide.none,
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: _tableBodyHorizController,
              physics: const NeverScrollableScrollPhysics(),
              child: SizedBox(
                width: w.total,
                child: Row(
                  children: [
                    _buildActionsCell(task, w.acoes, isMobile),
                    _buildStatusCell(task, w.status, isMobile, hasSubtasks, isSubtask || isFrotaRow,
                        isExecutorRow, hasExecutorPeriods, isExpanded, subtasksCount, toggleExpansion),
                    _buildCell(task.locais.isNotEmpty ? task.locais.join(', ') : '', w.local, isMobile,
                        hasColoredBackground: statusBg != Colors.white),
                    _buildCell(task.tipo, w.tipo, isMobile, hasColoredBackground: statusBg != Colors.white),
                    SizedBox(
                      width: w.tarefa,
                      child: Container(
                        padding: EdgeInsets.only(left: (isSubtask || isExecutorRow || isFrotaRow) ? (isMobile ? 20 : 24) : 0),
                        child: _buildCell(task.tarefa, 0, isMobile,
                            isSubtask: isSubtask || isFrotaRow,
                            hasColoredBackground: statusBg != Colors.white,
                            maxLines: 2, softWrap: true, overflow: TextOverflow.fade,
                            fontWeight: (task.status == 'PROG' || task.status == 'ANDA') ? FontWeight.w600 : null),
                      ),
                    ),
                    _buildCell(
                      task.equipeExecutores?.isNotEmpty == true
                          ? '${task.equipes.isNotEmpty ? task.equipes.join(', ') : ''} (${task.equipeExecutores!.length})'
                          : task.executores.isNotEmpty ? task.executores.join(', ') : task.executor,
                      w.executor, isMobile,
                      hasColoredBackground: statusBg != Colors.white, maxLines: 2, softWrap: true, overflow: TextOverflow.fade,
                    ),
                    _buildCell(task.coordenador, w.coordenador, isMobile, hasColoredBackground: statusBg != Colors.white),
                    _buildFrotaCell(task, w.frota, isMobile, statusBg),
                    _buildChatCell(task, w.chat, isMobile, statusBg),
                    _buildIconCountCell(
                      Icons.attach_file,
                      _anexosCount[task.id] ?? 0,
                      w.anexos, isMobile, statusBg,
                    ),
                    _buildNotaSAPCell(task, w.notasSAP, isMobile, statusBg),
                    _buildOrdemCell(task, w.ordens, isMobile, statusBg),
                    _buildATCell(task, w.ats, isMobile, statusBg),
                    _buildSICell(task, w.sis, isMobile, statusBg),
                    _buildAlertasCell(task, w.alertas, isMobile, statusBg, taskWarnings),
                  ],
                ),
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
            switch (val) {
              case 'view': widget.onTaskSelected?.call(task); break;
              case 'edit': widget.onEdit?.call(task); break;
              case 'delete': widget.onDelete?.call(task); break;
              case 'duplicate': widget.onDuplicate?.call(task); break;
              case 'subtask': widget.onCreateSubtask?.call(task); break;
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
    bool isExecutorRow, bool hasExecutorPeriods, bool isExpanded, int subtasksCount,
    VoidCallback toggleExpansion,
  ) {
    final badge = _getStatusBadgeColor(task.status);
    return SizedBox(
      width: width,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 3 : 6, vertical: isMobile ? 4 : 8),
        decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey[300]!, width: 0.5))),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasSubtasks || hasExecutorPeriods)
              Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more, size: isMobile ? 16 : 18, color: Colors.blue[700]),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: toggleExpansion,
                ),
                if (hasSubtasks && !isExpanded)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(color: Colors.blue[100], borderRadius: BorderRadius.circular(10)),
                    child: Text('$subtasksCount', style: TextStyle(fontSize: isMobile ? 8 : 9, color: Colors.blue[900], fontWeight: FontWeight.bold)),
                  ),
              ])
            else if (isSubtask)
              Padding(
                padding: EdgeInsets.only(left: isMobile ? 16 : 20),
                child: Icon(Icons.subdirectory_arrow_right, size: isMobile ? 14 : 16, color: Colors.grey[600]),
              )
            else
              const SizedBox(width: 8),
            Tooltip(
              message: _statusMap[task.status]?.status ?? task.status,
              child: Container(
                width: isMobile ? 12 : 14,
                height: isMobile ? 12 : 14,
                decoration: BoxDecoration(color: badge, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
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
    bool hasExecutorPeriods,
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
              color: isSubtask ? Colors.grey[50]!.withOpacity(0.5) : Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                left: isExecutorRow
                    ? BorderSide(color: Colors.orange[400]!, width: 3)
                    : isSubtask
                    ? BorderSide(color: Colors.blue[400]!, width: 4)
                    : (hasSubtasks || hasExecutorPeriods)
                    ? BorderSide(color: Colors.blue[200]!, width: 2)
                    : BorderSide.none,
              ),
            ),
          ),
          if ((hasSubtasks || hasExecutorPeriods) && !isSubtask && !isExecutorRow)
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
                        final isFer = isDay && _isFeriado(p.start);
                        return Positioned(
                          left: i * periodWidth,
                          top: 0,
                          bottom: 0,
                          width: periodWidth,
                          child: Container(
                            decoration: BoxDecoration(
                              color: isFer ? Colors.purple[100] : isWknd ? Colors.grey[200] : Colors.white,
                              border: Border.all(color: Colors.grey[300]!, width: 1),
                            ),
                          ),
                        );
                      }),
                      ..._buildGroupSeparators(periods, periodWidth),
                      // Segmentos (barras)
                      ...task.ganttSegments.asMap().entries.map((entry) {
                        final segIdx = entry.key;
                        final seg = entry.value;
                        final start = DateTime(seg.dataInicio.year, seg.dataInicio.month, seg.dataInicio.day);
                        var end = DateTime(seg.dataFim.year, seg.dataFim.month, seg.dataFim.day);
                        end = _normalizeLegacyEndDate(task, start, end);

                        if (end.isBefore(widget.startDate) || start.isAfter(widget.endDate)) {
                          print('DEBUG RENDER [$segIdx] ${seg.tipoPeriodo}: FORA DO PERIODO (start: $start, end: $end)');
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

                        return Positioned(
                          left: startOff,
                          top: 0,
                          bottom: 0,
                          child: GanttSegmentWidget(
                            key: ValueKey('seg_${task.id}_${segIdx}_cv$_conflictsVersion'),
                            task: task,
                            segmentIndex: segIdx,
                            segment: seg,
                            normalizedStartDate: start,
                            normalizedEndDate: end,
                            barWidth: barW,
                            dayWidth: periodWidth,
                            periods: periods,
                            color: segColor,
                            textColor: Colors.white,
                            conflictDays: conflictDays,
                            conflictTooltipMessage: null,
                            conflictTooltipMessageByDay: null,
                            conflictDaysFrota: conflictDaysFrota,
                            conflictTooltipMessageFrota: null,
                            conflictTooltipMessageByDayFrota: null,
                            taskService: widget.taskService,
                            onTasksUpdated: widget.onTasksUpdated,
                            onDragStart: _onSegmentDragStart,
                            onDragEnd: _onSegmentDragEnd,
                            conflictsVersionNotifier: _conflictsVersionNotifier,
                          ),
                        );
                      }),
                      // Linha do dia atual
                      if (todayOffset >= 0)
                        Positioned(
                          left: todayOffset + (periodWidth / 2),
                          top: 0,
                          bottom: 0,
                          child: Container(
                            width: 3,
                            decoration: BoxDecoration(
                              color: Colors.red[600],
                              boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.7), blurRadius: 4, spreadRadius: 1)],
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

  bool _isClickOnSegment(double clickX, Task task, List<GanttPeriod> periods, double periodWidth) {
    for (var seg in task.ganttSegments) {
      final start = DateTime(seg.dataInicio.year, seg.dataInicio.month, seg.dataInicio.day);
      final end = _normalizeLegacyEndDate(task, start, DateTime(seg.dataFim.year, seg.dataFim.month, seg.dataFim.day));
      final off = _getDateOffsetFromPeriods(start, periods, periodWidth);
      final w = _getBarWidthForRange(start, end, periods, periodWidth);
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
    // Reusar dialog do TaskTable — Por ora exibe simples
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Frota: $nome')));
  }

  Future<void> _mostrarNotasSAP(Task task) async {
    final notas = await _notaSAPService.getNotasPorTarefa(task.id);
    if (!mounted) return;
    if (notas.isNotEmpty) setState(() => _notasSAPCount[task.id] = notas.length);
    if (notas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhuma nota SAP vinculada')));
    }
  }

  Future<void> _mostrarOrdens(Task task) async {
    final ordens = await _ordemService.getOrdensPorTarefa(task.id);
    if (!mounted) return;
    if (ordens.isNotEmpty) setState(() => _ordensCount[task.id] = ordens.length);
    if (ordens.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhuma ordem vinculada')));
    }
  }

  Future<void> _mostrarATs(Task task) async {
    final ats = await _atService.getATsPorTarefa(task.id);
    if (!mounted) return;
    if (ats.isNotEmpty) setState(() => _atsCount[task.id] = ats.length);
    if (ats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhuma AT vinculada')));
    }
  }

  Future<void> _mostrarSIs(Task task) async {
    final sis = await _siService.getSIsPorTarefa(task.id);
    if (!mounted) return;
    if (sis.isNotEmpty) setState(() => _sisCount[task.id] = sis.length);
    if (sis.isEmpty) {
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

    if (hierarchicalTasks.isEmpty) {
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

    return Column(
      children: [
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
            itemBuilder: (ctx, index) => RepaintBoundary(
              child: _buildUnifiedRow(
                ctx, hierarchicalTasks[index], index, hierarchicalTasks,
                periods, periodWidth, totalWidth, todayOffset, ganttWidth, isMobile,
              ),
            ),
          ),
        ),
      ],
    );
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
      : acoes = isMobile ? 50 : 60,
        status = isMobile ? 60 : 70,
        local = isMobile ? 80 : 90,
        tipo = isMobile ? 90 : 100,
        tarefa = isMobile ? 150 : 184,
        executor = isMobile ? 120 : 150,
        coordenador = isMobile ? 85 : 110,
        frota = isMobile ? 45 : 50,
        chat = isMobile ? 45 : 50,
        anexos = isMobile ? 45 : 50,
        notasSAP = isMobile ? 45 : 50,
        ordens = isMobile ? 45 : 50,
        ats = isMobile ? 38 : 42,
        sis = isMobile ? 38 : 42,
        alertas = isMobile ? 45 : 50;

  double get total =>
      acoes + status + local + tipo + tarefa + executor + coordenador +
      frota + chat + anexos + notasSAP + ordens + ats + sis + alertas + 32;
}
