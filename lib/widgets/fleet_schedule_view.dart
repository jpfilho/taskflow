import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../models/task.dart';
import '../models/frota.dart';
import '../models/tipo_atividade.dart';
import '../models/feriado.dart';
import '../models/status.dart';
import '../services/task_service.dart';
import '../services/frota_service.dart';
import '../services/tipo_atividade_service.dart';
import '../services/auth_service_simples.dart';
import '../services/feriado_service.dart';
import '../services/status_service.dart';
import '../services/segmento_service.dart';
import '../services/tab_sync_service.dart';
import '../services/conflict_service.dart';
import '../utils/responsive.dart';

class FleetScheduleView extends StatefulWidget {
  final TaskService taskService;
  final FrotaService frotaService;
  final ConflictService? conflictService;
  final DateTime startDate;
  final DateTime endDate;
  final List<Task>? filteredTasks; // Tarefas já filtradas (opcional)
  /// Filtros da barra da tela Frota: regional, divisao, segmento, frota (valores separados por vírgula)
  final Map<String, String?>? fleetFilters;
  /// Callback com opções para os dropdowns da barra (regionais, divisoes, segmentos, frotas) — mesmos dados da tabela.
  final void Function(Map<String, List<String>>)? onFleetDataLoaded;
  final VoidCallback? onTasksUpdated;
  final Function(Task)? onEdit;
  final Function(Task)? onDelete;
  final Function(Task)? onDuplicate;
  final Function(Task)? onCreateSubtask;

  const FleetScheduleView({
    super.key,
    required this.taskService,
    required this.frotaService,
    this.conflictService,
    required this.startDate,
    required this.endDate,
    this.filteredTasks,
    this.fleetFilters,
    this.onFleetDataLoaded,
    this.onTasksUpdated,
    this.onEdit,
    this.onDelete,
    this.onDuplicate,
    this.onCreateSubtask,
  });

  @override
  State<FleetScheduleView> createState() => _FleetScheduleViewState();
}

class FleetTaskRow {
  final Frota frota;
  final List<Task> tasks;

  FleetTaskRow({
    required this.frota,
    required this.tasks,
  });
}

class _FleetScheduleViewState extends State<FleetScheduleView> {
  List<Task> _tasks = [];
  List<Frota> _frotas = [];
  /// Frotas após filtro de perfil (antes do filtro da barra Regional/Divisão/Frota/Local)
  List<Frota> _frotasAfterProfileFilter = [];
  bool _isLoading = true;
  List<FleetTaskRow> _fleetRows = [];
  /// Dias com conflito por frota (v_conflict_por_dia_frota). Exibição em preto com letras brancas.
  Map<String, Set<DateTime>> _conflictDaysByFrota = {};
  /// Conflitos de frota do backend (v_conflict_por_dia_frota).
  Map<String, ConflictInfo>? _conflictMapFrotaFromBackend;
  /// Eventos de execução por frota (v_conflict_execution_events_frota) para tooltip com todos os locais/tarefas.
  Map<String, List<FleetExecutionEventFromBackend>>? _fleetEventsByDayFromBackend;
  final ScrollController _tableVerticalScrollController = ScrollController();
  final ScrollController _ganttVerticalScrollController = ScrollController();
  final ScrollController _ganttHorizontalScrollController = ScrollController();
  final double _rowHeight = 28.0;
  bool _isScrolling = false;
  bool _showSegmentTexts = true; // agora exibe por padrão
  bool _showOnlyLocalText = true; // mostra apenas o local por padrão
  
  // Variáveis para tipos de atividade e cores
  final TipoAtividadeService _tipoAtividadeService = TipoAtividadeService();
  Map<String, TipoAtividade> _tipoAtividadeMap = {}; // Mapa de código de tipo -> TipoAtividade
  
  // Variáveis para feriados
  final FeriadoService _feriadoService = FeriadoService();
  Map<DateTime, List<Feriado>> _feriadosMap = {}; // Mapa de data -> Lista de feriados
  
  // Serviço de autenticação para obter perfil do usuário
  final AuthServiceSimples _authService = AuthServiceSimples();
  final SegmentoService _segmentoService = SegmentoService();
  /// ID do segmento "Frota" (quando usuário tem este segmento, vê todas as frotas da regional)
  String? _segmentoFrotaId;
  
  // Serviços para modal de atividades
  final StatusService _statusService = StatusService();
  Map<String, Status> _statusMap = {}; // Mapa de código de status -> Status
  
  // Serviço de sincronização entre abas
  StreamSubscription<Map<String, dynamic>>? _tabSyncSubscription;
  
  // Subscription do Supabase Realtime
  RealtimeChannel? _realtimeChannel;
  
  // Indicador de atualização manual
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    print('🚀 FleetScheduleView: initState');
    
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
    
    // Inicializar sincronização entre abas (apenas no web)
    if (kIsWeb) {
      try {
        TabSyncService().initialize();
        _tabSyncSubscription = TabSyncService().events.listen((event) {
          final type = event['type']?.toString() ?? 'null';
          print('📡 FleetScheduleView: Evento recebido via BroadcastChannel: $type');
          
          if (type == 'task_created' || type == 'task_updated' || type == 'task_deleted' || type == 'tasks_reload') {
            // Forçar atualização e recarregar dados
            print('🔄 FleetScheduleView: Recarregando dados devido a evento de outra aba: $type');
            if (mounted) {
              _reloadWithViewRefresh(showLoading: false);
              // Notificar o callback se existir
              if (widget.onTasksUpdated != null) {
                widget.onTasksUpdated!();
              }
            }
          }
        });
        print('✅ FleetScheduleView: Sincronização entre abas inicializada');
      } catch (e) {
        print('⚠️ Erro ao inicializar sincronização entre abas: $e');
      }
    }
    
    // Inicializar Supabase Realtime para escutar mudanças na tabela tasks
    try {
      _realtimeChannel = widget.taskService.subscribeToTasks(
        onUpsert: (task) {
          print('📡 FleetScheduleView: Tarefa criada/atualizada via Supabase Realtime: ${task.id}');
          // Forçar atualização e recarregar dados
          if (mounted) {
            _reloadWithViewRefresh(showLoading: false);
            // Notificar o callback se existir
            if (widget.onTasksUpdated != null) {
              widget.onTasksUpdated!();
            }
          }
        },
        onDelete: (taskId) {
          print('📡 FleetScheduleView: Tarefa deletada via Supabase Realtime: $taskId');
          // Forçar atualização e recarregar dados
          if (mounted) {
            _reloadWithViewRefresh(showLoading: false);
            // Notificar o callback se existir
            if (widget.onTasksUpdated != null) {
              widget.onTasksUpdated!();
            }
          }
        },
      );
      print('✅ FleetScheduleView: Subscription Supabase Realtime ativada');
    } catch (e) {
      print('⚠️ Erro ao inicializar Supabase Realtime: $e');
    }
    
    _loadData();
  }

  @override
  void didUpdateWidget(FleetScheduleView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startDate != widget.startDate || oldWidget.endDate != widget.endDate) {
      print('🔄 Período mudou, reconstruindo dados...');
      _loadFeriados();
      _buildFleetRowsFromView();
    } else if (oldWidget.fleetFilters != widget.fleetFilters) {
      final filtered = _applyFleetFiltersToFrotas(_frotasAfterProfileFilter);
      setState(() => _frotas = filtered);
      _buildFleetRowsFromView();
    } else if (oldWidget.conflictService != widget.conflictService) {
      _loadFleetBackendConflicts();
    }
  }

  @override
  void dispose() {
    _tabSyncSubscription?.cancel();
    _realtimeChannel?.unsubscribe();
    _tableVerticalScrollController.dispose();
    _ganttVerticalScrollController.dispose();
    _ganttHorizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    print('📥 FleetScheduleView: Iniciando carregamento de dados...');
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
      // debug silenciado
      
      // Carregar feriados
      await _loadFeriados();
      
      // Carregar tarefas
      final tasks = widget.filteredTasks ?? await widget.taskService.getAllTasks();
      // debug silenciado
      
      // Carregar frotas
      final frotas = await widget.frotaService.getAllFrotas();
      print('✅ Frotas carregadas: ${frotas.length}');
      
      // Resolver ID do segmento "Frota" (usuário com este segmento vê todas as frotas da regional)
      if (_segmentoFrotaId == null) {
        final segmentos = await _segmentoService.getAllSegmentos();
        try {
          final frotaSeg = segmentos.firstWhere(
            (s) => s.segmento.toLowerCase().trim() == 'frota',
          );
          _segmentoFrotaId = frotaSeg.id;
        } catch (_) {
          // Nenhum segmento chamado "Frota" cadastrado
        }
      }
      
      // Filtrar frotas pelo perfil do usuário (se não for root)
      var frotasFiltradas = frotas;
      var usuario = _authService.currentUser;
      // Se o perfil não tem regionais (ex.: cache antigo ou sessão restaurada sem perfil), recarregar do backend
      if (usuario != null && !usuario.isRoot && usuario.regionalIds.isEmpty) {
        usuario = await _authService.refreshCurrentUser();
      }
      if (usuario != null && !usuario.isRoot) {
        print('🔒 Filtrando frotas pelo perfil do usuário...');
        print('   Regionais do perfil: ${usuario.regionalIds.length}');
        print('   Divisões do perfil: ${usuario.divisaoIds.length}');
        print('   Segmentos do perfil: ${usuario.segmentoIds.length}');
        
        final usuarioTemSegmentoFrota = _segmentoFrotaId != null &&
            usuario.segmentoIds.contains(_segmentoFrotaId);
        
        if (usuarioTemSegmentoFrota) {
          // Perfil Frota: acesso a todas as frotas da regional do perfil (sem filtrar por divisão/segmento)
          final regionalIdsLower = usuario.regionalIds.map((id) => id.toString().toLowerCase()).toSet();
          frotasFiltradas = frotas.where((frota) {
            if (frota.regionalId == null || frota.regionalId!.isEmpty) return true;
            return regionalIdsLower.contains(frota.regionalId!.toLowerCase());
          }).toList();
          print('✅ Perfil Frota: mostrando todas as frotas da(s) regional(is): ${frotasFiltradas.length} de ${frotas.length}');
        } else {
          final regionalIdsLower = usuario.regionalIds.map((id) => id.toString().toLowerCase()).toSet();
          final divisaoIdsLower = usuario.divisaoIds.map((id) => id.toString().toLowerCase()).toSet();
          final segmentoIdsLower = usuario.segmentoIds.map((id) => id.toString().toLowerCase()).toSet();
          frotasFiltradas = frotas.where((frota) {
            final temRegionalPermitida = frota.regionalId == null || frota.regionalId!.isEmpty ||
                regionalIdsLower.contains(frota.regionalId!.toLowerCase());
            final temDivisaoPermitida = frota.divisaoId == null || frota.divisaoId!.isEmpty ||
                divisaoIdsLower.contains(frota.divisaoId!.toLowerCase());
            final temSegmentoPermitido = frota.segmentoId == null || frota.segmentoId!.isEmpty ||
                segmentoIdsLower.contains(frota.segmentoId!.toLowerCase());
            return temRegionalPermitida && temDivisaoPermitida && temSegmentoPermitido;
          }).toList();
          print('✅ Frotas filtradas: ${frotasFiltradas.length} de ${frotas.length}');
        }
      } else if (usuario != null && usuario.isRoot) {
        print('👑 Usuário root: mostrando todas as frotas');
      } else {
        print('⚠️ Usuário sem perfil configurado: mostrando todas as frotas');
      }

      _frotasAfterProfileFilter = frotasFiltradas;
      final frotasComFiltroBarra = _applyFleetFiltersToFrotas(frotasFiltradas);
      
      setState(() {
        _tasks = tasks;
        _frotas = frotasComFiltroBarra;
      });
      _notifyFleetFilterOptions(frotasFiltradas, tasks);
      await _buildFleetRowsFromView();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      print('❌ Erro ao carregar dados: $e');
      print('📚 StackTrace: $stackTrace');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadFeriados() async {
    try {
      final feriados = await _feriadoService.getFeriadosByDateRange(
        widget.startDate,
        widget.endDate,
      );
      _feriadosMap = {};
      for (var feriado in feriados) {
        final date = DateTime(feriado.data.year, feriado.data.month, feriado.data.day);
        if (!_feriadosMap.containsKey(date)) {
          _feriadosMap[date] = [];
        }
        _feriadosMap[date]!.add(feriado);
      }
      print('✅ Feriados carregados: ${_feriadosMap.length}');
    } catch (e) {
      print('⚠️ Erro ao carregar feriados: $e');
    }
  }

  bool _isFeriado(DateTime date) {
    final dateKey = DateTime(date.year, date.month, date.day);
    return _feriadosMap.containsKey(dateKey);
  }

  /// Aplica filtros da barra da tela Frota (Regional, Divisão, Segmento, Frota, Local não aplicado aqui).
  List<Frota> _applyFleetFiltersToFrotas(List<Frota> frotas) {
    final filters = widget.fleetFilters;
    if (filters == null || filters.isEmpty) return frotas;
    Set<String>? regionalSet;
    Set<String>? divisaoSet;
    Set<String>? segmentoSet;
    Set<String>? frotaSet;
    if (filters['regional'] != null && filters['regional']!.trim().isNotEmpty) {
      regionalSet = filters['regional']!.split(',').map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toSet();
    }
    if (filters['divisao'] != null && filters['divisao']!.trim().isNotEmpty) {
      divisaoSet = filters['divisao']!.split(',').map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toSet();
    }
    if (filters['segmento'] != null && filters['segmento']!.trim().isNotEmpty) {
      segmentoSet = filters['segmento']!.split(',').map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toSet();
    }
    if (filters['frota'] != null && filters['frota']!.trim().isNotEmpty) {
      frotaSet = filters['frota']!.split(',').map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toSet();
    }
    if (regionalSet == null && divisaoSet == null && segmentoSet == null && frotaSet == null) return frotas;
    return frotas.where((f) {
      if (regionalSet != null) {
        final r = (f.regional ?? '').trim().toLowerCase();
        if (r.isEmpty || !regionalSet.contains(r)) return false;
      }
      if (divisaoSet != null) {
        final d = (f.divisao ?? '').trim().toLowerCase();
        if (d.isEmpty || !divisaoSet.contains(d)) return false;
      }
      if (segmentoSet != null) {
        final s = (f.segmento ?? '').trim().toLowerCase();
        if (s.isEmpty || !segmentoSet.contains(s)) return false;
      }
      if (frotaSet != null) {
        final nome = (f.nome).trim().toLowerCase();
        final placa = (f.placa).trim().toLowerCase();
        final match = frotaSet.any((x) => nome == x || placa == x || nome.contains(x) || placa.contains(x));
        if (!match) return false;
      }
      return true;
    }).toList();
  }

  /// Notifica as opções dos filtros da frota (mesmos dados da tabela) para a barra de filtros.
  void _notifyFleetFilterOptions(List<Frota> frotas, List<Task> tasks) {
    widget.onFleetDataLoaded?.call(_buildFleetFilterOptions(frotas, tasks));
  }

  /// Constrói o mapa de opções: regionals, divisoes, segmentos, frotas (valores únicos da tabela).
  Map<String, List<String>> _buildFleetFilterOptions(List<Frota> frotas, List<Task> tasks) {
    final regionais = <String>{};
    final divisoes = <String>{};
    final segmentos = <String>{};
    final frotasNomes = <String>{};
    for (final f in frotas) {
      final r = (f.regional ?? '').trim();
      if (r.isNotEmpty) regionais.add(r);
      final d = (f.divisao ?? '').trim();
      if (d.isNotEmpty) divisoes.add(d);
      final s = (f.segmento ?? '').trim();
      if (s.isNotEmpty) segmentos.add(s);
      final nome = f.nome.trim();
      final placa = (f.placa).trim();
      frotasNomes.add(placa.isNotEmpty ? '$nome - $placa' : nome);
    }
    return {
      'regionals': regionais.toList(),
      'divisoes': divisoes.toList(),
      'segmentos': segmentos.toList(),
      'frotas': frotasNomes.toList(),
    };
  }

  /// Recarrega dados
  /// Se estiver usando view normal (v_execucoes_dia_completa), não precisa de refresh - atualiza automaticamente
  /// Se estiver usando view materializada, força o refresh primeiro
  Future<void> _reloadWithViewRefresh({bool showLoading = false}) async {
    if (showLoading && mounted) {
      setState(() {
        _isRefreshing = true;
      });
    }
    
    print('🔄 FleetScheduleView: Recarregando dados...');
    try {
      // Tentar atualizar view materializada (se existir)
      // Se estiver usando view normal, isso não faz nada e a view já está atualizada automaticamente
      try {
        await widget.taskService.refreshMvExecucoesDia();
        // Aguardar um pouco apenas se for view materializada (view normal não precisa)
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (e) {
        // Se falhar, pode ser porque está usando view normal (que não precisa de refresh)
        print('ℹ️ View materializada não encontrada ou erro (pode ser normal se estiver usando view normal): $e');
      }
      
      // Recarregar todos os dados (view normal já está atualizada automaticamente)
      await _loadData();
      
      print('✅ FleetScheduleView: Dados recarregados com sucesso');
    } catch (e, stackTrace) {
      print('❌ FleetScheduleView: Erro ao recarregar dados: $e');
      print('   Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar dados: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (showLoading && mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  /// Atualização manual via botão
  Future<void> _manualRefresh() async {
    await _reloadWithViewRefresh(showLoading: true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dados atualizados'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Carrega conflitos de frota do backend (v_conflict_por_dia_frota).
  Future<void> _loadFleetBackendConflicts() async {
    final cs = widget.conflictService;
    if (cs == null) {
      if (_conflictMapFrotaFromBackend != null) {
        setState(() {
          _conflictMapFrotaFromBackend = null;
          _fleetEventsByDayFromBackend = null;
          _conflictDaysByFrota = {};
        });
      }
      return;
    }
    final ok = await cs.isFleetConflictBackendAvailable();
    if (!ok) {
      if (_conflictMapFrotaFromBackend != null) {
        setState(() {
          _conflictMapFrotaFromBackend = null;
          _fleetEventsByDayFromBackend = null;
          _conflictDaysByFrota = {};
        });
      }
      return;
    }
    final start = DateTime(widget.startDate.year, widget.startDate.month, widget.startDate.day);
    final end = DateTime(widget.endDate.year, widget.endDate.month, widget.endDate.day);
    final map = await cs.getFleetConflictsForRange(start, end);
    final events = await cs.getFleetExecutionEventsForRange(start, end);
    if (!mounted) return;
    final conflictDaysByFrota = <String, Set<DateTime>>{};
    for (final entry in map.entries) {
      if (!entry.value.hasConflict) continue;
      final key = entry.key;
      final idx = key.lastIndexOf('_');
      if (idx <= 0) continue;
      final frotaId = key.substring(0, idx);
      final dayStr = key.substring(idx + 1);
      DateTime? day;
      try {
        day = DateTime.parse(dayStr);
      } catch (_) {
        continue;
      }
      final dayKey = DateTime(day.year, day.month, day.day);
      conflictDaysByFrota.putIfAbsent(frotaId, () => <DateTime>{}).add(dayKey);
    }
    setState(() {
      _conflictMapFrotaFromBackend = map;
      _fleetEventsByDayFromBackend = events;
      _conflictDaysByFrota = conflictDaysByFrota;
    });
  }

  /// Constrói linhas a partir da view v_execucoes_dia_frota (exclui CANC e REPR).
  /// Conflitos de frota vêm de v_conflict_por_dia_frota (carregados em _loadFleetBackendConflicts).
  Future<void> _buildFleetRowsFromView() async {
    if (_frotas.isEmpty) {
      setState(() => _fleetRows = []);
      return;
    }
    final frotaIds = _frotas.map((e) => e.id).toList();
    try {
      final rows = await widget.taskService.getExecucoesDiaFrota(
        frotaIds: frotaIds,
        startDate: widget.startDate,
        endDate: widget.endDate,
      );
      if (!mounted) return;
      final byFrota = <String, List<Map<String, dynamic>>>{};
      for (final r in rows) {
        final fid = r['frota_id']?.toString() ?? '';
        if (fid.isEmpty) continue;
        byFrota.putIfAbsent(fid, () => []).add(r);
      }
      // Mapa task_id -> Task completa (tabela tasks) para enriquecer executor, datas, etc.
      final taskFromDb = <String, Task>{};
      for (final t in _tasks) {
        taskFromDb[t.id] = t;
      }
      final fleetRows = <FleetTaskRow>[];
      final sortedFrotas = _getSortedFrotas();
      for (final frota in sortedFrotas) {
        final list = byFrota[frota.id] ?? [];
        final tasksById = <String, Task>{};
        final taskDaysByTipo = <String, Map<String, List<DateTime>>>{};
        for (final r in list) {
          final taskId = r['task_id']?.toString() ?? '';
          if (taskId.isEmpty) continue;
          final dayStr = r['day']?.toString();
          if (dayStr == null) continue;
          final day = DateTime.parse(dayStr);
          final tipoPeriodo = (r['tipo_periodo']?.toString() ?? 'EXECUCAO').toUpperCase();
          final locName = (r['local_nome'] ?? r['local'] ?? r['loc'] ?? '').toString();
          final locKey = (r['loc_key'] ?? '').toString();
          final locs = locName.isNotEmpty ? locName.split(RegExp(r'\s*\|\s*')).where((e) => e.isNotEmpty).toList() : <String>[];
          final locIds = locKey.isNotEmpty ? locKey.split('|').where((e) => e.isNotEmpty).toList() : <String>[];
          final taskStatus = r['task_status']?.toString() ?? '';
          final taskTipo = r['task_tipo']?.toString() ?? '';
          final taskLabel = (r['task_tarefa'] ?? r['task_tipo'] ?? '').toString();
          taskDaysByTipo.putIfAbsent(taskId, () => {});
          taskDaysByTipo[taskId]!.putIfAbsent(tipoPeriodo, () => []).add(day);
          final fullTask = taskFromDb[taskId];
          tasksById.putIfAbsent(
            taskId,
            () => Task(
              id: taskId,
              status: taskStatus,
              statusNome: fullTask?.statusNome ?? '',
              regional: fullTask?.regional ?? '',
              divisao: fullTask?.divisao ?? '',
              locais: locs.isNotEmpty ? locs : (fullTask?.locais ?? []),
              segmento: fullTask?.segmento ?? '',
              equipes: fullTask?.equipes ?? const [],
              tipo: taskTipo,
              tarefa: taskLabel,
              executores: fullTask?.executores ?? const [],
              executor: fullTask?.executor ?? '',
              frota: frota.nome + (frota.placa.isNotEmpty ? ' - ${frota.placa}' : ''),
              coordenador: fullTask?.coordenador ?? '',
              si: fullTask?.si ?? '',
              dataInicio: fullTask?.dataInicio ?? day,
              dataFim: fullTask?.dataFim ?? day,
              ganttSegments: const [],
              executorPeriods: fullTask?.executorPeriods ?? const [],
              frotaPeriods: const [],
              precisaSi: fullTask?.precisaSi ?? false,
              executorIds: fullTask?.executorIds ?? const [],
              equipeIds: fullTask?.equipeIds ?? const [],
              frotaIds: const [],
              localIds: locIds.isNotEmpty ? locIds : (fullTask?.localIds ?? []),
            ),
          );
        }
        // Montar segmentos do Gantt a partir dos dias (agrupados por tipo_periodo)
        for (final entry in tasksById.entries.toList()) {
          final taskId = entry.key;
          final task = entry.value;
          final daysByTipo = taskDaysByTipo[taskId] ?? {};
          if (daysByTipo.isEmpty) continue;
          final segments = <GanttSegment>[];
          DateTime? minStart;
          DateTime? maxEnd;
          for (final tipoPeriodoEntry in daysByTipo.entries) {
            final tipoPeriodo = tipoPeriodoEntry.key;
            final days = tipoPeriodoEntry.value;
            if (days.isEmpty) continue;
            days.sort();
            DateTime? segStart;
            DateTime? segEnd;
            for (final d in days) {
              final dDate = DateTime(d.year, d.month, d.day);
              if (segStart == null) {
                segStart = dDate;
                segEnd = dDate;
                continue;
              }
              if (dDate.difference(segEnd!).inDays <= 1) {
                segEnd = dDate;
              } else {
                segments.add(GanttSegment(dataInicio: segStart, dataFim: segEnd, label: '', tipo: 'ADM', tipoPeriodo: tipoPeriodo));
                if (minStart == null || segStart.isBefore(minStart)) minStart = segStart;
                if (maxEnd == null || segEnd.isAfter(maxEnd)) maxEnd = segEnd;
                segStart = dDate;
                segEnd = dDate;
              }
            }
            if (segStart != null) {
              segments.add(GanttSegment(dataInicio: segStart, dataFim: segEnd ?? segStart, label: '', tipo: 'ADM', tipoPeriodo: tipoPeriodo));
              if (minStart == null || segStart.isBefore(minStart)) minStart = segStart;
              if (maxEnd == null || (segEnd ?? segStart).isAfter(maxEnd)) maxEnd = segEnd ?? segStart;
            }
          }
          if (segments.isNotEmpty && minStart != null && maxEnd != null) {
            tasksById[taskId] = task.copyWith(ganttSegments: segments, dataInicio: minStart, dataFim: maxEnd);
          }
        }
        fleetRows.add(FleetTaskRow(frota: frota, tasks: tasksById.values.toList()));
      }
      if (!mounted) return;
      final rowsWithLocalFilter = fleetRows.map((row) => FleetTaskRow(
        frota: row.frota,
        tasks: row.tasks,
      )).toList();
      setState(() => _fleetRows = rowsWithLocalFilter);
      await _loadFleetBackendConflicts();
      print('✅ FleetScheduleView: Dados via view v_execucoes_dia_frota: ${rowsWithLocalFilter.length} frotas');
    } catch (e, st) {
      print('⚠️ FleetScheduleView: View indisponível, usando fallback: $e');
      print(st);
      setState(() => _conflictDaysByFrota = {});
      _buildFleetRows();
      await _loadFleetBackendConflicts();
    }
  }

  void _buildFleetRows() {
    print('🔨 _buildFleetRows: Iniciando construção (fallback)');
    print('   Período: ${widget.startDate} a ${widget.endDate}');
    
    // Criar mapa de frotas por nome e placa
    final frotaByNome = <String, Frota>{};
    final frotaByPlaca = <String, Frota>{};
    
    for (var frota in _frotas) {
      if (frota.nome.isNotEmpty) {
        frotaByNome[frota.nome.toUpperCase()] = frota;
      }
      if (frota.placa.isNotEmpty) {
        frotaByPlaca[frota.placa.toUpperCase()] = frota;
      }
    }
    
    // Criar mapa de frota -> lista de tarefas
    final fleetTasksMap = <String, List<Task>>{};
    for (var frota in _frotas) {
      fleetTasksMap[frota.id] = [];
    }
    
    final periodStart = DateTime(widget.startDate.year, widget.startDate.month, widget.startDate.day);
    final periodEnd = DateTime(widget.endDate.year, widget.endDate.month, widget.endDate.day);

    // Desconsiderar CANC (cancelados) e REPR (reprogramados)
    const statusExcluidos = ['CANC', 'REPR'];
    final tasksFiltradas = _tasks.where((t) {
      final s = (t.status).toUpperCase().trim();
      return s.isEmpty || !statusExcluidos.contains(s);
    }).toList();

    // Processar tarefas e vincular às frotas
    for (var task in tasksFiltradas) {
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
      
      // Coletar frotas vinculadas
      final frotasVinculadas = <Frota>{};
      
      // Verificar campo frota da tarefa
      if (task.frota.isNotEmpty && task.frota != '-N/A-') {
        // Tentar encontrar por nome
        final frotaNome = task.frota.toUpperCase();
        var frota = frotaByNome[frotaNome];
        
        // Se não encontrou por nome, tentar extrair placa (formato: "Nome - Placa")
        if (frota == null && task.frota.contains(' - ')) {
          final parts = task.frota.split(' - ');
          if (parts.length >= 2) {
            final placa = parts[1].trim().toUpperCase();
            frota = frotaByPlaca[placa];
          }
        }
        
        // Se ainda não encontrou, tentar buscar por placa diretamente
        if (frota == null) {
          frota = frotaByPlaca[frotaNome];
        }
        
        if (frota != null) {
          frotasVinculadas.add(frota);
        }
      }
      
      // Adicionar tarefa às frotas
      for (var frota in frotasVinculadas) {
        if (!fleetTasksMap.containsKey(frota.id)) {
          fleetTasksMap[frota.id] = [];
        }
        fleetTasksMap[frota.id]!.add(task);
      }
    }

    // Criar lista ordenada
    final fleetRows = <FleetTaskRow>[];
    final sortedFrotas = _getSortedFrotas();
    
    for (var frota in sortedFrotas) {
      final tasks = fleetTasksMap[frota.id] ?? [];
      fleetRows.add(FleetTaskRow(
        frota: frota,
        tasks: tasks,
      ));
    }

    final rowsWithLocalFilter = fleetRows.map((row) => FleetTaskRow(
      frota: row.frota,
      tasks: row.tasks,
    )).toList();
    print('✅ Dados construídos: ${rowsWithLocalFilter.length} frotas');
    setState(() {
      _fleetRows = rowsWithLocalFilter;
      _conflictDaysByFrota = {};
    });
  }

  /// Verifica se o segmento cobre o dia (mesma lógica da tela de equipes).
  bool _overlapsDay(DateTime segStart, DateTime segEnd, DateTime dayStart, DateTime dayEnd) {
    final s = DateTime(segStart.year, segStart.month, segStart.day);
    final e = DateTime(segEnd.year, segEnd.month, segEnd.day);
    return s.isBefore(dayEnd) && e.isAfter(dayStart);
  }

  /// Chave de local para comparar conflitos (múltiplos locais no mesmo dia = conflito).
  String _taskLocationKey(Task task) {
    if (task.localIds.isNotEmpty) {
      return task.localIds.join('|');
    }
    if (task.locais.isNotEmpty) {
      return task.locais.join('|');
    }
    return '';
  }

  /// Conflito em um dia para uma frota: view sinalizou ou múltiplos locais distintos (EXECUÇÃO).
  bool _hasConflictOnDayForFrota(DateTime day, String frotaId) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final conflicts = _conflictDaysByFrota[frotaId];
    if (conflicts != null && conflicts.contains(dayStart)) {
      return true;
    }

    FleetTaskRow? row;
    for (final r in _fleetRows) {
      if (r.frota.id == frotaId) {
        row = r;
        break;
      }
    }
    if (row == null || row.tasks.isEmpty) return false;

    final Set<String> locationsWithSegmentsOnDay = {};
    for (final task in row.tasks) {
      if (task.status.toUpperCase().trim() == 'CANC' || task.status.toUpperCase().trim() == 'REPR') {
        continue;
      }
      bool taskHasExecSegmentOnDay = false;
      for (final segment in task.ganttSegments) {
        if (segment.tipoPeriodo.toUpperCase() != 'EXECUCAO') continue;
        if (_overlapsDay(segment.dataInicio, segment.dataFim, dayStart, dayEnd)) {
          taskHasExecSegmentOnDay = true;
          break;
        }
      }
      if (taskHasExecSegmentOnDay) {
        final locKey = _taskLocationKey(task);
        locationsWithSegmentsOnDay.add(locKey.isNotEmpty ? locKey : 'task-${task.id}');
      }
    }
    return locationsWithSegmentsOnDay.length > 1;
  }

  /// Se a frota tem conflito em algum dia do período.
  bool _hasConflictForFrota(String frotaId) {
    final days = _getDaysInPeriod();
    for (final day in days) {
      if (_hasConflictOnDayForFrota(day, frotaId)) return true;
    }
    return false;
  }

  /// Mensagem do tooltip de conflito de frota para um segmento: TODOS os locais/tarefas (eventos), igual ao conflito de executores.
  String _getFleetConflictTooltipMessage(String frotaId, List<DateTime> conflictDays) {
    if (conflictDays.isEmpty) {
      return 'Conflito de frota: mesma frota em mais de um local nestes dias.';
    }
    final lines = <String>['Conflito de frota (dias em preto): mesma frota alocada em mais de um local nestes dias.', ''];
    final added = <String>{};
    // Usar eventos (v_conflict_execution_events_frota) para listar TODOS os locais e tarefas, como no conflito de executores
    if (_fleetEventsByDayFromBackend != null) {
      for (final day in conflictDays) {
        final dayStr = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
        final events = _fleetEventsByDayFromBackend![dayStr];
        if (events != null) {
          for (final e in events) {
            if (e.frotaId != frotaId || e.description.isEmpty) continue;
            if (added.add(e.description)) {
              lines.add('• ${e.description}');
            }
          }
        }
      }
    }
    // Fallback: descriptions do resumo (v_conflict_por_dia_frota)
    if (lines.length <= 2 && _conflictMapFrotaFromBackend != null) {
      for (final day in conflictDays) {
        final dayKey = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
        final info = _conflictMapFrotaFromBackend!['${frotaId}_$dayKey'];
        if (info != null && info.descriptions.isNotEmpty) {
          for (final d in info.descriptions) {
            if (d.trim().isNotEmpty && added.add(d)) {
              lines.add('• $d');
            }
          }
        }
      }
    }
    if (lines.length <= 2) return lines.first;
    return lines.join('\n');
  }

  List<Frota> _getSortedFrotas() {
    final sorted = List<Frota>.from(_frotas);
    sorted.sort((a, b) {
      // Primeiro: ordenar por tipo de veículo
      final tipoA = a.tipoVeiculo.toUpperCase();
      final tipoB = b.tipoVeiculo.toUpperCase();
      
      if (tipoA != tipoB) {
        return tipoA.compareTo(tipoB);
      }
      
      // Se o tipo for o mesmo, ordenar alfabeticamente pelo nome
      final nomeA = a.nome.toUpperCase();
      final nomeB = b.nome.toUpperCase();
      return nomeA.compareTo(nomeB);
    });
    return sorted;
  }

  List<DateTime> _getDaysInPeriod() {
    final days = <DateTime>[];
    var currentDate = DateTime(widget.startDate.year, widget.startDate.month, widget.startDate.day);
    final endDate = DateTime(widget.endDate.year, widget.endDate.month, widget.endDate.day);
    
    while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
      days.add(currentDate);
      currentDate = currentDate.add(const Duration(days: 1));
    }
    
    return days;
  }

  double _getDayOffset(DateTime date, List<DateTime> days, double dayWidth) {
    final dateKey = DateTime(date.year, date.month, date.day);
    final index = days.indexWhere((d) => 
      d.year == dateKey.year && 
      d.month == dateKey.month && 
      d.day == dateKey.day
    );
    
    if (index == -1) {
      return 0;
    }
    
    return index * dayWidth;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);
    
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    final days = _getDaysInPeriod();
    
    if (isMobile || isTablet) {
      return _buildMobileTabletView(days);
    } else {
      return _buildCombinedView(days);
    }
  }

  Widget _buildMobileTabletView(List<DateTime> days) {
    final screenHeight = MediaQuery.of(context).size.height;
    final minDayWidth = 30.0;
    final calculatedHeight = (screenHeight * 0.6).clamp(200.0, screenHeight * 0.9);
    // Largura da tabela: REGIONAL(100) + DIVISÃO(100) + TIPO(100) + PLACA(100) + TAREFAS(80) + NOME(150) = 630px
    // Adicionar margem para garantir que todas as colunas sejam visíveis
    final tableWidth = 650.0;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            width: tableWidth + (days.length * minDayWidth),
            height: calculatedHeight,
            child: Row(
              children: [
                SizedBox(
                  width: tableWidth,
                  child: _buildFleetTable(),
                ),
                SizedBox(
                  width: days.length * minDayWidth,
                  child: _buildGanttView(days, minDayWidth),
                ),
              ],
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
            // Tabela de frotas (40% da tela)
            Expanded(
              flex: 2,
              child: _buildFleetTable(),
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

  Widget _buildFleetTable() {
    if (_fleetRows.isEmpty) {
      return const Center(child: Text('Nenhuma frota encontrada'));
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
          // Cabeçalho fixo
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
                _buildHeaderCell('REGIONAL', 100),
                _buildHeaderCell('DIVISÃO', 100),
                _buildHeaderCell('TIPO', 100),
                _buildHeaderCell('PLACA', 100),
                _buildHeaderCell('TAREFAS', 80),
                _buildHeaderCell('NOME', 150, textAlign: TextAlign.right),
              ],
            ),
          ),
          // Corpo com scroll sincronizado
          Expanded(
            child: ListView.builder(
              controller: _tableVerticalScrollController,
              itemCount: _fleetRows.length,
              itemExtent: _rowHeight,
              itemBuilder: (context, index) {
                final row = _fleetRows[index];
                final previousRow = index > 0 ? _fleetRows[index - 1] : null;
                
                // Verificar se mudou o tipo para adicionar separador
                final mudouTipo = previousRow != null && 
                    previousRow.frota.tipoVeiculo != row.frota.tipoVeiculo;
                
                return Stack(
                  children: [
                    // Linha separadora se mudou o tipo (no topo)
                    if (mudouTipo)
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
                      top: mudouTipo ? 2 : 0,
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _buildFleetTableRow(row, index),
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

  Widget _buildFleetTableRow(FleetTaskRow row, int index) {
    final frota = row.frota;
    final hasConflict = _hasConflictForFrota(frota.id);

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
        color: hasConflict
            ? Colors.black87
            : (row.tasks.isNotEmpty ? Colors.white : Colors.grey[50]),
      ),
      child: Row(
        children: [
          _buildCell(frota.regional ?? '-', 100, hasConflict: hasConflict),
          _buildCell(frota.divisao ?? '-', 100, hasConflict: hasConflict),
          _buildCell(_getTipoVeiculoLabel(frota.tipoVeiculo), 100, hasConflict: hasConflict),
          _buildCell(frota.placa, 100, hasConflict: hasConflict),
          _buildTasksCell(row.tasks.length, row, 80, hasConflict: hasConflict),
          _buildFleetNameCell(frota, 150, hasConflict: hasConflict, row: row),
        ],
      ),
    );
  }

  String _getTipoVeiculoLabel(String tipo) {
    switch (tipo) {
      case 'CARRO_LEVE':
        return 'Carro Leve';
      case 'MUNCK':
        return 'Munck';
      case 'TRATOR':
        return 'Trator';
      case 'CAMINHAO':
        return 'Caminhão';
      case 'PICKUP':
        return 'Pickup';
      case 'VAN':
        return 'Van';
      case 'MOTO':
        return 'Moto';
      case 'ONIBUS':
        return 'Ônibus';
      case 'OUTRO':
        return 'Outro';
      default:
        return tipo;
    }
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
              // Cabeçalho do Gantt (meses mesclados + dias)
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
                        // Botões para mostrar/ocultar textos e alternar local/tarefa
                        Positioned(
                          right: 8,
                          top: 0,
                          bottom: 0,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Botão de atualizar (antes dos outros ícones)
                              Tooltip(
                                message: 'Atualizar dados',
                                child: _isRefreshing
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                                        ),
                                      )
                                    : IconButton(
                                        icon: const Icon(Icons.refresh, size: 18),
                                        color: Colors.grey[700],
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 32,
                                          minHeight: 24,
                                        ),
                                        onPressed: _isRefreshing ? null : _manualRefresh,
                                      ),
                              ),
                              const SizedBox(width: 6),
                              Tooltip(
                                message: _showOnlyLocalText ? 'Mostrar local e tarefa' : 'Mostrar só local',
                                child: IconButton(
                                  icon: Icon(
                                    _showOnlyLocalText ? Icons.location_on : Icons.location_on_outlined,
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
                                      _showOnlyLocalText = !_showOnlyLocalText;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 6),
                              Tooltip(
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
                            ],
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
                            mainAxisSize: MainAxisSize.min,
                            children: days.map((day) {
                              final isWeekend = day.weekday == 6 || day.weekday == 7;
                              final isFeriado = _isFeriado(day);
                              return Container(
                                width: dayWidth,
                                height: 50,
                                padding: EdgeInsets.zero,
                                margin: EdgeInsets.zero,
                                decoration: BoxDecoration(
                                  color: isFeriado
                                      ? Colors.purple[100]
                                      : (isWeekend ? Colors.grey[200] : Colors.white),
                                  border: Border(
                                    right: BorderSide(
                                      color: Colors.grey[300]!,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 2.0),
                                  child: Text(
                                    day.day.toString().padLeft(2, '0'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.normal,
                                      color: isFeriado
                                          ? Colors.purple[800]
                                          : (isWeekend ? Colors.grey[600] : Colors.black),
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
                  itemCount: _fleetRows.length,
                  itemExtent: _rowHeight,
                  itemBuilder: (context, index) {
                    final row = _fleetRows[index];
                    final previousRow = index > 0 ? _fleetRows[index - 1] : null;
                    
                    // Verificar se mudou o tipo para adicionar separador
                    final mudouTipo = previousRow != null && 
                        previousRow.frota.tipoVeiculo != row.frota.tipoVeiculo;
                    
                    return Stack(
                      children: [
                        // Linha separadora se mudou o tipo (no topo)
                        if (mudouTipo)
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
                          top: mudouTipo ? 2 : 0,
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
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }


  Widget _buildGanttRow(FleetTaskRow row, List<DateTime> days, double dayWidth, int index, bool needsScroll) {
    final totalWidth = days.length * dayWidth;
    return SizedBox(
      height: _rowHeight,
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
          color: row.tasks.isEmpty ? Colors.grey[50] : Colors.white,
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
                    mainAxisSize: MainAxisSize.min,
                    children: days.map((day) {
                      final isWeekend = day.weekday == 6 || day.weekday == 7;
                      final isFeriado = _isFeriado(day);
                      return Container(
                        width: dayWidth,
                        height: _rowHeight,
                        decoration: BoxDecoration(
                          color: isFeriado
                              ? Colors.purple[100]
                              : (isWeekend ? Colors.grey[200] : Colors.white),
                          border: Border(
                            right: BorderSide(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  // Segmentos das tarefas (com overlay de conflito por dia, igual à tela de equipes)
                  ...row.tasks.expand((task) {
                    return task.ganttSegments.map((segment) {
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
                      
                      final periodEnd = DateTime(widget.endDate.year, widget.endDate.month, widget.endDate.day);
                      final periodStart = DateTime(widget.startDate.year, widget.startDate.month, widget.startDate.day);
                      
                      if (startDate.isAfter(periodEnd) || endDate.isBefore(periodStart)) {
                        return null;
                      }
                      
                      final startOffset = _getDayOffset(startDate, days, dayWidth);
                      final duration = endDate.difference(startDate).inDays + 1;
                      final barWidth = duration * dayWidth;
                      
                      // Dias de conflito neste segmento (mesma lógica da tela de equipes)
                      List<DateTime> conflictDays = [];
                      var currentDay = startDate.isBefore(periodStart) ? periodStart : startDate;
                      final lastDay = endDate.isAfter(periodEnd) ? periodEnd : endDate;
                      while (!currentDay.isAfter(lastDay)) {
                        if (_hasConflictOnDayForFrota(currentDay, row.frota.id)) {
                          conflictDays.add(DateTime(currentDay.year, currentDay.month, currentDay.day));
                        }
                        currentDay = currentDay.add(const Duration(days: 1));
                      }
                      
                      final segmentColor = _getSegmentColor(segment, task);
                      final conflictTooltipMessage = conflictDays.isNotEmpty
                          ? _getFleetConflictTooltipMessage(row.frota.id, conflictDays)
                          : null;
                      
                      Widget segmentChild = SizedBox(
                        width: barWidth - 1,
                        height: _rowHeight - 2,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: barWidth - 1,
                              height: _rowHeight - 2,
                              decoration: BoxDecoration(
                                color: segmentColor,
                                borderRadius: BorderRadius.circular(2),
                                border: Border.all(
                                  color: segmentColor.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: _buildSegmentContent(segment, task, barWidth),
                            ),
                            // Overlay de conflito por dia (acima de tudo), só nos dias conflitantes.
                            if (conflictDays.isNotEmpty) ...[
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.max,
                                    children: () {
                                      final segmentDays = <DateTime>[];
                                      var d = startDate.isBefore(periodStart) ? periodStart : startDate;
                                      final last = endDate.isAfter(periodEnd) ? periodEnd : endDate;
                                      while (!d.isAfter(last)) {
                                        segmentDays.add(DateTime(d.year, d.month, d.day));
                                        d = d.add(const Duration(days: 1));
                                      }
                                      return segmentDays.map((day) {
                                        final isConflictDay = conflictDays.any((cd) =>
                                            cd.year == day.year && cd.month == day.month && cd.day == day.day);
                                        return Expanded(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: isConflictDay ? Colors.black : Colors.transparent,
                                              borderRadius: isConflictDay ? BorderRadius.circular(2) : null,
                                              border: isConflictDay ? Border.all(color: Colors.black, width: 2) : null,
                                            ),
                                          ),
                                        );
                                      }).toList();
                                    }(),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                      if (conflictTooltipMessage != null && conflictTooltipMessage.isNotEmpty) {
                        segmentChild = Tooltip(
                          message: conflictTooltipMessage,
                          preferBelow: true,
                          child: segmentChild,
                        );
                      }
                      return Positioned(
                        left: startOffset,
                        top: 1,
                        bottom: 1,
                        child: segmentChild,
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
        iconData = Icons.calendar_today;
      } else {
        iconData = Icons.directions_car;
      }
      
      final iconSize = (_rowHeight - 4).clamp(12.0, 20.0);
      
      return Icon(
        iconData,
        size: iconSize,
        color: Colors.white,
      );
    }
    
    // Para EXECUCAO: mostrar texto (local e tarefa) seguindo a lógica da tela de equipes
    final textColor = Colors.white;
    final fontSize = 9.0;
    final availableHeight = _rowHeight - 4;
    final localText = task.locais.isNotEmpty ? task.locais.join(', ') : '-';
    final taskText = task.tarefa.isNotEmpty ? task.tarefa : (segment.label.isNotEmpty ? segment.label : '-');

    Widget _line(String text) => SizedBox(
          width: barWidth - 6,
          child: Text(
            text,
            style: TextStyle(
              fontSize: fontSize,
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            textAlign: TextAlign.center,
        ),
      );

    if (availableHeight < 20 || _showOnlyLocalText) {
      return Center(child: _line(localText));
    }
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        _line(localText),
        if (taskText.isNotEmpty) _line(taskText),
      ],
    );
  }

  Color _getSegmentColor(GanttSegment segment, Task task) {
    // PRIORIDADE 1: Verificar o tipo de período
    switch (segment.tipoPeriodo.toUpperCase()) {
      case 'PLANEJAMENTO':
        return Colors.orange[600]!;
      case 'DESLOCAMENTO':
        return Colors.blue[400]!;
      case 'EXECUCAO':
        // Continuar para verificar cor do tipo de atividade
        break;
      default:
        break;
    }
    
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
          final corStr = tipoAtividade.cor!.replaceFirst('#', '0xFF');
          return Color(int.parse(corStr));
        } catch (e) {
          print('⚠️ Erro ao parsear cor do tipo de atividade: $e');
        }
      }
    }
    
    // PRIORIDADE 4: Atividade de manutenção da frota → vermelho (frota indisponível no período)
    final tipoUpper = task.tipo.toUpperCase();
    if (tipoUpper.contains('MANUT') || tipoUpper == 'R&M') {
      return Colors.red;
    }
    
    // PRIORIDADE 5: Cores padrão baseadas no tipo
    switch (tipoUpper) {
      case 'COMP':
        return Colors.brown[400]!;
      case 'FER':
        return Colors.cyan[400]!;
      case 'MP':
        return Colors.yellow[600]!;
      case 'NM':
        return Colors.yellow[400]!;
      case 'OBRA':
        return Colors.grey[500]!;
      default:
        return Colors.grey[400]!;
    }
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
            color: hasConflict ? Colors.white : Colors.black,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign ?? TextAlign.left,
        ),
      ),
    );
  }

  Widget _buildTasksCell(int taskCount, FleetTaskRow row, double width, {bool hasConflict = false}) {
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
                color: hasConflict ? Colors.white : Colors.black,
              ),
            ),
            if (taskCount > 0) ...[
              const SizedBox(width: 4),
              Tooltip(
                message: 'Ver atividades',
                child: InkWell(
                  onTap: () => _showFleetTasks(row.frota, row.tasks),
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

  /// Retorna true se a frota tem alguma tarefa do tipo OFICINA no dia atual.
  bool _fleetHasOficinaOnCurrentDay(FleetTaskRow row) {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    for (final task in row.tasks) {
      final tipoUpper = task.tipo.toUpperCase().trim();
      if (tipoUpper != 'OFICINA' && !tipoUpper.contains('OFICINA')) continue;
      if (task.ganttSegments.isNotEmpty) {
        for (final seg in task.ganttSegments) {
          final start = DateTime(seg.dataInicio.year, seg.dataInicio.month, seg.dataInicio.day);
          final end = DateTime(seg.dataFim.year, seg.dataFim.month, seg.dataFim.day);
          if (today.isAfter(end) || today.isBefore(start)) continue;
          return true;
        }
      } else {
        final start = DateTime(task.dataInicio.year, task.dataInicio.month, task.dataInicio.day);
        final end = DateTime(task.dataFim.year, task.dataFim.month, task.dataFim.day);
        if (today.isBefore(start) || today.isAfter(end)) continue;
        return true;
      }
    }
    return false;
  }

  Widget _buildFleetNameCell(Frota frota, double width, {bool hasConflict = false, FleetTaskRow? row}) {
    final hasOficinaToday = row != null && _fleetHasOficinaOnCurrentDay(row);
    final useOficinaStyle = hasOficinaToday;
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: useOficinaStyle
                    ? BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4))
                    : null,
                child: Text(
                  frota.nome,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: (hasConflict || useOficinaStyle) ? FontWeight.bold : FontWeight.normal,
                    color: useOficinaStyle ? Colors.white : (hasConflict ? Colors.white : Colors.black),
                  ),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Tooltip(
              message: 'Ver dados da frota',
              child: InkWell(
                onTap: () => _showFleetDetails(frota),
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

  void _showFleetDetails(Frota frota) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _FleetDetailsModal(frota: frota),
    );
  }

  void _showFleetTasks(Frota frota, List<Task> tasks) {
    // Filtrar tarefas que estão no período
    var tasksNoPeriodo = tasks.where((task) {
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
    // Ordem crescente: primeiro por data de início, depois por data de fim
    tasksNoPeriodo = tasksNoPeriodo.toList()
      ..sort((a, b) {
        final cmpInicio = a.dataInicio.compareTo(b.dataInicio);
        if (cmpInicio != 0) return cmpInicio;
        return a.dataFim.compareTo(b.dataFim);
      });

    if (tasksNoPeriodo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${frota.nome} não possui atividades no período selecionado'),
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
      builder: (context) => _FleetTasksModal(
        frota: frota,
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

  Widget _buildTaskInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, color: Colors.grey[800]),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Task task) {
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
                    const SizedBox(height: 8),
                    _buildTaskInfoRow(Icons.calendar_today_outlined, 'Início', DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(task.dataInicio)),
                    _buildTaskInfoRow(Icons.calendar_today, 'Fim', DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(task.dataFim)),
                    if (task.locais.isNotEmpty)
                      _buildTaskInfoRow(Icons.place_outlined, 'Local', task.locais.join(', ')),
                    _buildTaskInfoRow(
                      Icons.person_outline,
                      'Executor',
                      task.executor.isNotEmpty ? task.executor : (task.executores.isNotEmpty ? task.executores.join(', ') : '—'),
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
              if (widget.onEdit != null || widget.onDelete != null || widget.onDuplicate != null || widget.onCreateSubtask != null)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onSelected: (value) {
                    switch (value) {
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
                    if (widget.onEdit != null)
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
                    if (widget.onDuplicate != null)
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
                    if (widget.onCreateSubtask != null && task.isMainTask)
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
                    if (widget.onDelete != null)
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
        ],
      ),
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
      print('Erro ao compartilhar: $error');
    });
  }

  String _formatTaskDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

// Modal para mostrar detalhes da frota
class _FleetDetailsModal extends StatelessWidget {
  final Frota frota;

  const _FleetDetailsModal({required this.frota});

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Container(
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.9,
      ),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header com avatar e nome
            Container(
              padding: EdgeInsets.all(isMobile ? 12 : 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[600]!, Colors.blue[400]!],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: isMobile ? 25 : 30,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.directions_car,
                      color: Colors.blue[600],
                      size: isMobile ? 28 : 32,
                    ),
                  ),
                  SizedBox(width: isMobile ? 12 : 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          frota.nome,
                          style: TextStyle(
                            fontSize: isMobile ? 16 : 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: isMobile ? 4 : 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getTipoVeiculoLabel(frota.tipoVeiculo),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.white),
                    onPressed: () => _shareFleetInfo(context),
                  ),
                ],
              ),
            ),
            SizedBox(height: isMobile ? 12 : 16),
            // Informações
            _buildInfoSection(
              context,
              'Informações do Veículo',
              [
                _buildInfoItem(context, Icons.badge, 'Placa', frota.placa, isMobile, showCopyButton: true),
                if (frota.marca != null && frota.marca!.isNotEmpty)
                  _buildInfoItem(context, Icons.business, 'Marca', frota.marca!, isMobile, showCopyButton: true),
                _buildInfoItem(
                  context,
                  Icons.directions_car,
                  'Tipo',
                  _getTipoVeiculoLabel(frota.tipoVeiculo),
                  isMobile,
                ),
              ],
              isMobile,
            ),
            SizedBox(height: isMobile ? 12 : 16),
            _buildInfoSection(
              context,
              'Organizacional',
              [
                if (frota.regional != null)
                  _buildInfoItem(context, Icons.location_city, 'Regional', frota.regional!, isMobile),
                if (frota.divisao != null)
                  _buildInfoItem(context, Icons.business_center, 'Divisão', frota.divisao!, isMobile),
                if (frota.segmento != null)
                  _buildInfoItem(context, Icons.category, 'Segmento', frota.segmento!, isMobile),
              ],
              isMobile,
            ),
            SizedBox(height: isMobile ? 12 : 16),
            _buildInfoSection(
              context,
              'Status',
              [
                _buildInfoItem(
                  context,
                  Icons.check_circle,
                  'Status',
                  frota.ativo ? 'Ativo' : 'Inativo',
                  isMobile,
                  valueColor: frota.ativo ? Colors.green : Colors.red,
                ),
                if (frota.emManutencao)
                  _buildInfoItem(
                    context,
                    Icons.build,
                    'Manutenção',
                    'Em Manutenção',
                    isMobile,
                    valueColor: Colors.orange,
                  ),
              ],
              isMobile,
            ),
            if (frota.observacoes != null && frota.observacoes!.isNotEmpty) ...[
              SizedBox(height: isMobile ? 12 : 16),
              _buildInfoSection(
                context,
                'Observações',
                [
                  Padding(
                    padding: EdgeInsets.all(isMobile ? 8 : 10),
                    child: Text(
                      frota.observacoes!,
                      style: TextStyle(
                        fontSize: isMobile ? 13 : 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
                isMobile,
              ),
            ],
            SizedBox(height: isMobile ? 12 : 16),
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

  String _getTipoVeiculoLabel(String tipo) {
    switch (tipo) {
      case 'CARRO_LEVE':
        return 'Carro Leve';
      case 'MUNCK':
        return 'Munck';
      case 'TRATOR':
        return 'Trator';
      case 'CAMINHAO':
        return 'Caminhão';
      case 'PICKUP':
        return 'Pickup';
      case 'VAN':
        return 'Van';
      case 'MOTO':
        return 'Moto';
      case 'ONIBUS':
        return 'Ônibus';
      case 'OUTRO':
        return 'Outro';
      default:
        return tipo;
    }
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
                onTap: () async { await _copyToClipboard(context, value, label); },
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

  Future<void> _copyToClipboard(BuildContext context, String text, String label) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label copiado para a área de transferência'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível copiar: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _shareFleetInfo(BuildContext context) {
    final buffer = StringBuffer();
    buffer.writeln('🚗 Dados da Frota\n');
    buffer.writeln('📝 Nome: ${frota.nome}');
    if (frota.marca != null && frota.marca!.isNotEmpty) {
      buffer.writeln('🏭 Marca: ${frota.marca}');
    }
    buffer.writeln('🔢 Placa: ${frota.placa}');
    buffer.writeln('🚙 Tipo: ${_getTipoVeiculoLabel(frota.tipoVeiculo)}');
    if (frota.regional != null) {
      buffer.writeln('📍 Regional: ${frota.regional}');
    }
    if (frota.divisao != null) {
      buffer.writeln('🏢 Divisão: ${frota.divisao}');
    }
    if (frota.segmento != null) {
      buffer.writeln('📂 Segmento: ${frota.segmento}');
    }
    buffer.writeln('✅ Status: ${frota.ativo ? 'Ativo' : 'Inativo'}');
    if (frota.emManutencao) {
      buffer.writeln('🔧 Manutenção: Em Manutenção');
    }
    if (frota.observacoes != null && frota.observacoes!.isNotEmpty) {
      buffer.writeln('\n📄 Observações:');
      buffer.writeln('   ${frota.observacoes}');
    }

    Share.share(
      buffer.toString(),
      subject: 'Frota - ${frota.nome}',
    ).catchError((error) {
      print('Erro ao compartilhar: $error');
    });
  }
}

// Modal para mostrar tarefas da frota
class _FleetTasksModal extends StatefulWidget {
  final Frota frota;
  final List<Task> tasks;
  final DateTime startDate;
  final DateTime endDate;
  final Widget Function(Task) buildTaskCard;
  final Color Function(String) getStatusColor;
  final Function(Task)? onEdit;
  final Function(Task)? onDelete;
  final Function(Task)? onDuplicate;
  final Function(Task)? onCreateSubtask;

  const _FleetTasksModal({
    required this.frota,
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
  State<_FleetTasksModal> createState() => _FleetTasksModalState();
}

class _FleetTasksModalState extends State<_FleetTasksModal> {
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final tasks = widget.tasks;

    return Container(
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.9,
      ),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Atividades de ${widget.frota.nome}',
                  style: TextStyle(
                    fontSize: isMobile ? 18 : 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 8 : 12),
          Text(
            '${tasks.length} atividade${tasks.length != 1 ? 's' : ''} no período',
            style: TextStyle(
              fontSize: isMobile ? 12 : 14,
              color: Colors.grey[600],
            ),
          ),
          if (tasks.length > 1) ...[
            const SizedBox(height: 4),
            Text(
              '${_currentIndex + 1} de ${tasks.length}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
          SizedBox(height: isMobile ? 12 : 16),
          Expanded(
            child: tasks.length > 1
                ? PageView.builder(
                    controller: _pageController,
                    itemCount: tasks.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      return SingleChildScrollView(
                        child: widget.buildTaskCard(tasks[index]),
                      );
                    },
                  )
                : SingleChildScrollView(
                    child: widget.buildTaskCard(tasks.first),
                  ),
          ),
          if (tasks.length > 1) ...[
            SizedBox(height: isMobile ? 12 : 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _currentIndex > 0
                      ? () => _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          )
                      : null,
                ),
                ...List.generate(
                  tasks.length,
                  (index) => Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index == _currentIndex ? Colors.blue[600] : Colors.grey[300],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _currentIndex < tasks.length - 1
                      ? () => _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          )
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
