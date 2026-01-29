import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
import '../services/tab_sync_service.dart';
import '../utils/responsive.dart';

class FleetScheduleView extends StatefulWidget {
  final TaskService taskService;
  final FrotaService frotaService;
  final DateTime startDate;
  final DateTime endDate;
  final List<Task>? filteredTasks; // Tarefas já filtradas (opcional)
  final VoidCallback? onTasksUpdated; // Callback para notificar quando tarefas são atualizadas
  final Function(Task)? onEdit; // Callback para editar tarefa
  final Function(Task)? onDelete; // Callback para deletar tarefa
  final Function(Task)? onDuplicate; // Callback para duplicar tarefa
  final Function(Task)? onCreateSubtask; // Callback para criar subtarefa

  const FleetScheduleView({
    super.key,
    required this.taskService,
    required this.frotaService,
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
  bool _isLoading = true;
  List<FleetTaskRow> _fleetRows = [];
  /// Dias com conflito por frota (mesmo conceito da tela de equipes: múltiplos locais no mesmo dia).
  Map<String, Set<DateTime>> _conflictDaysByFrota = {};
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
    // Reconstruir quando o período mudar
    if (oldWidget.startDate != widget.startDate || oldWidget.endDate != widget.endDate) {
      print('🔄 Período mudou, reconstruindo dados...');
      _loadFeriados(); // Recarregar feriados para o novo período
      _buildFleetRowsFromView();
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
      
      // Filtrar frotas pelo perfil do usuário (se não for root)
      var frotasFiltradas = frotas;
      final usuario = _authService.currentUser;
      if (usuario != null && !usuario.isRoot) {
        print('🔒 Filtrando frotas pelo perfil do usuário...');
        print('   Regionais do perfil: ${usuario.regionalIds.length}');
        print('   Divisões do perfil: ${usuario.divisaoIds.length}');
        print('   Segmentos do perfil: ${usuario.segmentoIds.length}');
        
        frotasFiltradas = frotas.where((frota) {
          // Verificar se a frota pertence a uma regional permitida
          final temRegionalPermitida = frota.regionalId == null || 
              usuario.regionalIds.contains(frota.regionalId);
          
          // Verificar se a frota pertence a uma divisão permitida
          final temDivisaoPermitida = frota.divisaoId == null || 
              usuario.divisaoIds.contains(frota.divisaoId);
          
          // Verificar se a frota pertence a um segmento permitido
          final temSegmentoPermitido = frota.segmentoId == null || 
              usuario.segmentoIds.contains(frota.segmentoId);
          
          return temRegionalPermitida && temDivisaoPermitida && temSegmentoPermitido;
        }).toList();
        
        print('✅ Frotas filtradas: ${frotasFiltradas.length} de ${frotas.length}');
      } else if (usuario != null && usuario.isRoot) {
        print('👑 Usuário root: mostrando todas as frotas');
      } else {
        print('⚠️ Usuário sem perfil configurado: mostrando todas as frotas');
      }
      
      setState(() {
        _tasks = tasks;
        _frotas = frotasFiltradas;
      });
      // Manter loading até as linhas (view) estarem prontas, para não mostrar
      // "Nenhuma frota encontrada" antes de terminar o carregamento.
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

  /// Constrói linhas a partir da view v_execucoes_dia_frota (exclui CANC e REPR).
  /// Em caso de erro ou view indisponível, faz fallback para _buildFleetRows().
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
      final conflictDaysByFrota = <String, Set<DateTime>>{};
      for (final r in rows) {
        final fid = r['frota_id']?.toString() ?? '';
        if (fid.isEmpty) continue;
        byFrota.putIfAbsent(fid, () => []).add(r);
        if (r['has_conflict'] == true) {
          final dayStr = r['day']?.toString();
          if (dayStr != null) {
            final d = DateTime.parse(dayStr);
            final dayKey = DateTime(d.year, d.month, d.day);
            conflictDaysByFrota.putIfAbsent(fid, () => <DateTime>{}).add(dayKey);
          }
        }
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
          final hasConflict = (r['has_conflict'] == true);
          taskDaysByTipo.putIfAbsent(taskId, () => {});
          taskDaysByTipo[taskId]!.putIfAbsent(tipoPeriodo, () => []).add(day);
          tasksById.putIfAbsent(
            taskId,
            () => Task(
              id: taskId,
              status: taskStatus,
              statusNome: '',
              regional: '',
              divisao: '',
              locais: locs,
              segmento: '',
              equipes: const [],
              tipo: taskTipo,
              tarefa: taskLabel,
              executores: const [],
              executor: '',
              frota: frota.nome + (frota.placa.isNotEmpty ? ' - ${frota.placa}' : ''),
              coordenador: '',
              si: '',
              dataInicio: day,
              dataFim: day,
              ganttSegments: const [],
              executorPeriods: const [],
              frotaPeriods: const [],
              precisaSi: false,
              executorIds: const [],
              equipeIds: const [],
              frotaIds: const [],
              localIds: locIds,
              hasConflict: hasConflict,
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
      setState(() {
        _fleetRows = fleetRows;
        _conflictDaysByFrota = conflictDaysByFrota;
      });
      print('✅ FleetScheduleView: Dados via view v_execucoes_dia_frota: ${fleetRows.length} frotas');
    } catch (e, st) {
      print('⚠️ FleetScheduleView: View indisponível, usando fallback: $e');
      print(st);
      setState(() => _conflictDaysByFrota = {});
      _buildFleetRows();
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

    print('✅ Dados construídos: ${fleetRows.length} frotas');
    
    setState(() {
      _fleetRows = fleetRows;
      _conflictDaysByFrota = {}; // fallback não tem sinal de conflito da view
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
            ? Colors.red[100]
            : (row.tasks.isNotEmpty ? Colors.white : Colors.grey[50]),
      ),
      child: Row(
        children: [
          _buildCell(frota.regional ?? '-', 100, hasConflict: hasConflict),
          _buildCell(frota.divisao ?? '-', 100, hasConflict: hasConflict),
          _buildCell(_getTipoVeiculoLabel(frota.tipoVeiculo), 100, hasConflict: hasConflict),
          _buildCell(frota.placa, 100, hasConflict: hasConflict),
          _buildTasksCell(row.tasks.length, row, 80, hasConflict: hasConflict),
          _buildFleetNameCell(frota, 150, hasConflict: hasConflict),
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
                            textDirection: TextDirection.ltr,
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
                    textDirection: TextDirection.ltr,
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
                      
                      return Positioned(
                        left: startOffset,
                        top: 1,
                        bottom: 1,
                        child: SizedBox(
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
                              // Overlay de conflito por dia (acima de tudo), só nos dias conflitantes
                              if (conflictDays.isNotEmpty)
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: Row(
                                      children: days.map((day) {
                                        final dayStart = DateTime(day.year, day.month, day.day);
                                        final dayEnd = dayStart.add(const Duration(days: 1));
                                        final coversDay = startDate.isBefore(dayEnd) && endDate.isAfter(dayStart);
                                        if (!coversDay) return const SizedBox.shrink();
                                        final isConflictDay = conflictDays.any((d) =>
                                            d.year == day.year && d.month == day.month && d.day == day.day);
                                        return Expanded(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: isConflictDay ? Colors.red[600]!.withOpacity(0.9) : Colors.transparent,
                                              borderRadius: isConflictDay ? BorderRadius.circular(2) : null,
                                              border: isConflictDay ? Border.all(color: Colors.red[800]!, width: 2) : null,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                            ],
                          ),
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
    
    // PRIORIDADE 4: Cores padrão baseadas no tipo
    switch (task.tipo.toUpperCase()) {
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
      case 'R&M':
        return Colors.blueGrey[400]!;
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
            color: hasConflict ? Colors.red[900] : Colors.black,
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
                color: hasConflict ? Colors.red[900] : Colors.black,
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

  Widget _buildFleetNameCell(Frota frota, double width, {bool hasConflict = false}) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                frota.nome,
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
