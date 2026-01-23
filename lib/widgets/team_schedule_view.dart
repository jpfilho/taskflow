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
  Map<String, Set<DateTime>> _conflictDaysByExecutor = {};
  final ScrollController _tableVerticalScrollController = ScrollController();
  final ScrollController _ganttVerticalScrollController = ScrollController();
  final ScrollController _ganttHorizontalScrollController = ScrollController();
  final double _rowHeight = 28.0;
  bool _isScrolling = false;
  bool _showSegmentTexts = true; // exibe textos por padrão
  bool _showOnlyLocalText = true; // padrão: mostrar só local; botão alterna para local+tarefa
  
  // Variáveis para tipos de atividade e cores
  final TipoAtividadeService _tipoAtividadeService = TipoAtividadeService();
  Map<String, TipoAtividade> _tipoAtividadeMap = {}; // Mapa de código de tipo -> TipoAtividade
  
  // Variáveis para feriados
  final FeriadoService _feriadoService = FeriadoService();
  Map<DateTime, List<Feriado>> _feriadosMap = {}; // Mapa de data -> Lista de feriados
  
  // Serviço de autenticação para obter perfil do usuário
  final AuthServiceSimples _authService = AuthServiceSimples();
  // Normalização simples para comparações de nomes/logins (sem acentos e caixa-baixa)
  String _normalizeText(String input) {
    var normalized = input.toLowerCase().trim();
    const withDiacritics = 'áàâãäåçéèêëíìîïñóòôõöúùûüýÿÁÀÂÃÄÅÇÉÈÊËÍÌÎÏÑÓÒÔÕÖÚÙÛÜÝ';
    const without =        'aaaaaaceeeeiiiinooooouuuuyyAAAAAACEEEEIIIINOOOOOUUUUY';
    for (var i = 0; i < withDiacritics.length && i < without.length; i++) {
      normalized = normalized.replaceAll(withDiacritics[i], without[i]);
    }
    // Remover pontuação e espaços para comparar nomes compostos
    normalized = normalized.replaceAll(RegExp(r'[^a-z0-9]'), '');
    return normalized;
  }
  
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
      // debug silenciado
      
      // Carregar feriados
      await _loadFeriados();
      
      // Carregar todas as tarefas (sem filtrar por perfil) para permitir que executores multi-segmento
      // vejam suas tarefas em qualquer segmento. A filtragem por perfil continua apenas para os executores.
      final tasks = await widget.taskService.getAllTasks(aplicarPerfil: false);
      // debug silenciado
      
      final executores = await widget.executorService.getAllExecutores();
      final executoresAtivos = executores.where((e) => e.ativo).toList();
      print('✅ Executores ativos: ${executoresAtivos.length}');
      
      // Pré-processar referências de executores nas tarefas (id/nome/login/matrícula)
      final Set<String> taskExecutorIds = {};
      final Set<String> taskExecutorNamesNorm = {};
      String norm(String v) => _normalizeText(v);
      for (var task in tasks) {
        for (var execId in task.executorIds) {
          if (execId.isNotEmpty) taskExecutorIds.add(execId);
        }
        for (var execNome in task.executores) {
          if (execNome.isNotEmpty) taskExecutorNamesNorm.add(norm(execNome));
        }
        if (task.executor.isNotEmpty) {
          final parts = task.executor.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
          for (var part in parts) {
            taskExecutorNamesNorm.add(norm(part));
          }
        }
        if (task.equipeExecutores != null) {
          for (var ee in task.equipeExecutores!) {
            if (ee.executorNome.isNotEmpty) {
              taskExecutorNamesNorm.add(norm(ee.executorNome));
            }
          }
        }
      }

      // Filtrar executores pelo perfil do usuário
      final usuario = _authService.currentUser;
      List<Executor> executoresFiltrados = executoresAtivos;
      
      // Filtrar sempre pelo perfil do usuário (regional/divisão/segmento), ignorando o perfil da tarefa
      if (usuario != null && !usuario.isRoot && usuario.temPerfilConfigurado()) {
        print('🔒 Filtrando executores pelo perfil do usuário...');
        print('   Regionais do perfil: ${usuario.regionalIds.length}');
        print('   Divisões do perfil: ${usuario.divisaoIds.length}');
        print('   Segmentos do perfil: ${usuario.segmentoIds.length}');
        
        // Divisões permitidas: as do usuário + todas as divisões das regionais do usuário
        final Set<String> divisaoIdsPermitidas = Set.from(usuario.divisaoIds);
        if (usuario.regionalIds.isNotEmpty) {
          try {
            final divisaoService = DivisaoService();
            final todasDivisoes = await divisaoService.getAllDivisoes();
            for (var regionalId in usuario.regionalIds) {
              final divisoesDaRegional = todasDivisoes.where((d) => d.regionalId == regionalId);
              divisaoIdsPermitidas.addAll(divisoesDaRegional.map((d) => d.id));
            }
          } catch (e) {
            print('⚠️ Erro ao buscar divisões das regionais: $e');
          }
        }
        
        // Mantém empregado se tiver divisão compatível E pelo menos um segmento do perfil
        // OU se estiver explicitamente referenciado em alguma tarefa (id ou nome/login/matrícula)
        executoresFiltrados = executoresAtivos.where((executor) {
          final temDivisaoPermitida = divisaoIdsPermitidas.isEmpty ||
              (executor.divisaoId != null && divisaoIdsPermitidas.contains(executor.divisaoId));

          final temSegmentoPermitido = usuario.segmentoIds.isEmpty ||
              executor.segmentoIds.any((segmentoId) => usuario.segmentoIds.contains(segmentoId));

          // Somente executores que pertencem ao perfil (regional/divisão/segmento) do usuário
          return temDivisaoPermitida && temSegmentoPermitido;
        }).toList();
        
        print('✅ Executores filtrados (por perfil do usuário): ${executoresFiltrados.length} de ${executoresAtivos.length}');
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
    _buildExecutorRowsFromView();
  }

  /// Recarrega tarefas do banco e reconstrói linhas/segmentos a partir da view,
  /// útil após exclusão/atualização para evitar conflitos stale.
  Future<void> _reloadTasksAndRows() async {
    try {
      final tasks = await widget.taskService.getAllTasks(aplicarPerfil: false);
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
      });
      await _buildExecutorRowsFromView();
    } catch (e, st) {
      print('⚠️ Erro ao recarregar tarefas/linhas: $e');
      print(st);
    }
  }



  Future<void> _buildExecutorRowsFromView() async {
    print('🔄 Carregando execuções via mv_execucoes_dia');
    try {
      final executorIds = _executores.map((e) => e.id).toList();
      final rows = await widget.taskService.getExecucoesDia(
        executorIds: executorIds,
        startDate: widget.startDate,
        endDate: widget.endDate,
      );

      final byExecutor = <String, List<Map<String, dynamic>>>{};
      final conflictDaysByExecutor = <String, Set<DateTime>>{};
      // Helpers para checar vínculo do executor com a tarefa e coletar segmentos não-EXECUÇÃO
      bool matchesExecutor(Executor executor, {String? executorId, String? executorNome}) {
        if (executorId != null && executorId.isNotEmpty && executorId == executor.id) {
          return true;
        }
        final keys = <String>{
          _normalizeText(executor.nome),
          if (executor.nomeCompleto != null) _normalizeText(executor.nomeCompleto!),
          if (executor.login != null) _normalizeText(executor.login!),
          if (executor.matricula != null) _normalizeText(executor.matricula!),
        }..removeWhere((e) => e.isEmpty);
        if (executorNome != null && executorNome.isNotEmpty) {
          if (keys.contains(_normalizeText(executorNome))) return true;
        }
        return false;
      }

      bool isTaskAssignedToExecutor(Task task, Executor executor) {
        // Por ID
        if (task.executorIds.any((id) => id.isNotEmpty && id == executor.id)) return true;

        // Por nomes/textos livres
        final keys = <String>{
          _normalizeText(executor.nome),
          if (executor.nomeCompleto != null) _normalizeText(executor.nomeCompleto!),
          if (executor.login != null) _normalizeText(executor.login!),
          if (executor.matricula != null) _normalizeText(executor.matricula!),
        }..removeWhere((e) => e.isEmpty);

        for (final nome in task.executores) {
          if (nome.isNotEmpty && keys.contains(_normalizeText(nome))) return true;
        }
        if (task.executor.isNotEmpty) {
          for (final nome in task.executor.split(',').map((e) => e.trim())) {
            if (nome.isNotEmpty && keys.contains(_normalizeText(nome))) return true;
          }
        }
        if (task.equipeExecutores != null) {
          for (final ee in task.equipeExecutores!) {
            if (ee.executorNome.isNotEmpty && keys.contains(_normalizeText(ee.executorNome))) {
              return true;
            }
          }
        }
        for (final ep in task.executorPeriods) {
          if (matchesExecutor(executor, executorId: ep.executorId, executorNome: ep.executorNome)) {
            return true;
          }
        }
        return false;
      }

      List<GanttSegment> nonExecSegmentsForExecutor(Task task, Executor executor) {
        // Prioriza períodos específicos do executor
        List<GanttSegment> pickSegments() {
          bool foundExecutorPeriod = false;
          for (final ep in task.executorPeriods) {
            if (matchesExecutor(executor, executorId: ep.executorId, executorNome: ep.executorNome)) {
              foundExecutorPeriod = true;
              final segs = ep.periods
                  .where((p) => p.tipoPeriodo.toUpperCase() != 'EXECUCAO')
                  .toList();
              if (segs.isNotEmpty) return segs;
            }
          }
          // Se não encontrou não-execução no executor_periods, ou não havia períodos específicos,
          // usar segmentos gerais da tarefa
          if (!foundExecutorPeriod || task.ganttSegments.isNotEmpty) {
            final segs = task.ganttSegments
                .where((p) => p.tipoPeriodo.toUpperCase() != 'EXECUCAO')
                .toList();
            if (segs.isNotEmpty) return segs;
          }
          return task.ganttSegments
              .where((p) => p.tipoPeriodo.toUpperCase() != 'EXECUCAO')
              .toList();
        }

        // Normaliza deslocamento: apenas dia de ida (início) e dia de volta (fim)
        List<GanttSegment> normalize(List<GanttSegment> segs) {
          final List<GanttSegment> out = [];
          for (final s in segs) {
            final tipoPeriodo = s.tipoPeriodo.toUpperCase();
            if (tipoPeriodo == 'DESLOCAMENTO') {
              final startDay = DateTime(s.dataInicio.year, s.dataInicio.month, s.dataInicio.day);
              final endDay = DateTime(s.dataFim.year, s.dataFim.month, s.dataFim.day);
              out.add(GanttSegment(
                dataInicio: startDay,
                dataFim: startDay,
                label: s.label,
                tipo: s.tipo,
                tipoPeriodo: s.tipoPeriodo,
              ));
              if (endDay.isAfter(startDay)) {
                out.add(GanttSegment(
                  dataInicio: endDay,
                  dataFim: endDay,
                  label: s.label,
                  tipo: s.tipo,
                  tipoPeriodo: s.tipoPeriodo,
                ));
              }
            } else {
              out.add(s);
            }
          }
          return out;
        }

        final picked = pickSegments();
        return picked.isEmpty ? picked : normalize(picked);
      }

      for (final r in rows) {
        final execId = r['executor_id']?.toString() ?? '';
        if (execId.isEmpty) continue;
        byExecutor.putIfAbsent(execId, () => []).add(r);
        final dayStr = r['day']?.toString();
        if (dayStr != null && r['has_conflict'] == true) {
          final d = DateTime.parse(dayStr);
          final dayKey = DateTime(d.year, d.month, d.day);
          conflictDaysByExecutor.putIfAbsent(execId, () => <DateTime>{}).add(dayKey);
        }
      }

      final executorRows = <ExecutorTaskRow>[];
      final sortedExecutores = _getSortedExecutores();

      for (final executor in sortedExecutores) {
        final list = byExecutor[executor.id] ?? [];
        final tasksById = <String, Task>{};
        final taskDays = <String, List<DateTime>>{};

        for (final r in list) {
          final taskId = r['task_id']?.toString() ?? '';
          if (taskId.isEmpty) continue;
          final dayStr = r['day']?.toString();
          if (dayStr == null) continue;
          final day = DateTime.parse(dayStr);
          // Preferir nome do local (quando enviado pela view), caindo para local do próprio tasks/local_id
          final locName = (r['local_nome'] ?? r['local'] ?? r['loc'] ?? '').toString();
          final locKey = (r['loc_key'] ?? '').toString();
          final locs = locName.isNotEmpty ? locName.split(RegExp(r'\s*\|\s*')).where((e) => e.isNotEmpty).toList() : <String>[];
          final locIds = locKey.isNotEmpty ? locKey.split('|').where((e) => e.isNotEmpty).toList() : <String>[];
          final taskStatus = r['task_status']?.toString() ?? '';
          final taskTipo = r['task_tipo']?.toString() ?? '';
          final taskLabel = (r['task_tarefa'] ?? r['task_tipo'] ?? '').toString();
          final hasConflict = (r['has_conflict'] == true);

          taskDays.putIfAbsent(taskId, () => []).add(day);

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
              frota: '',
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

        // Montar segmentos do Gantt a partir das datas
        for (final entry in tasksById.entries.toList()) {
          final days = taskDays[entry.key] ?? [];
          if (days.isEmpty) continue;
          days.sort();
          final segments = <GanttSegment>[];
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
              segments.add(GanttSegment(
                dataInicio: segStart,
                dataFim: segEnd,
                label: '',
                tipo: 'ADM',
              ));
              segStart = dDate;
              segEnd = dDate;
            }
          }
          if (segStart != null) {
            segments.add(GanttSegment(
              dataInicio: segStart,
              dataFim: segEnd!,
              label: '',
              tipo: 'ADM',
            ));
          }

          if (segments.isNotEmpty) {
            tasksById[entry.key] = entry.value.copyWith(
              ganttSegments: segments,
              dataInicio: segments.first.dataInicio,
              dataFim: segments.last.dataFim,
            );
          }
        }

        // Complementar com segmentos de PLANEJAMENTO/DESLOCAMENTO (não contam conflito)
        for (final task in _tasks) {
          if (task.status.toUpperCase() == 'CANC') continue;
          if (!isTaskAssignedToExecutor(task, executor)) continue;

          final nonExecSegments = nonExecSegmentsForExecutor(task, executor);
          if (nonExecSegments.isEmpty) continue;

          final existing = tasksById[task.id];
          final mergedSegments = <GanttSegment>[
            if (existing != null) ...existing.ganttSegments,
            ...nonExecSegments,
          ];
          if (mergedSegments.isEmpty) continue;

          DateTime minStart = mergedSegments.first.dataInicio;
          DateTime maxEnd = mergedSegments.first.dataFim;
          for (final seg in mergedSegments.skip(1)) {
            if (seg.dataInicio.isBefore(minStart)) minStart = seg.dataInicio;
            if (seg.dataFim.isAfter(maxEnd)) maxEnd = seg.dataFim;
          }

          final baseTask = existing ?? task;
          tasksById[task.id] = baseTask.copyWith(
            ganttSegments: mergedSegments,
            dataInicio: minStart,
            dataFim: maxEnd,
            locais: task.locais.isNotEmpty ? task.locais : baseTask.locais,
            localIds: task.localIds.isNotEmpty ? task.localIds : baseTask.localIds,
            tarefa: task.tarefa.isNotEmpty ? task.tarefa : baseTask.tarefa,
            tipo: task.tipo.isNotEmpty ? task.tipo : baseTask.tipo,
            status: task.status.isNotEmpty ? task.status : baseTask.status,
            hasConflict: existing?.hasConflict ?? false,
          );
        }

        executorRows.add(ExecutorTaskRow(
          executor: executor,
          tasks: tasksById.values.toList(),
        ));
      }

      setState(() {
        _executorRows = executorRows;
        _conflictDaysByExecutor = conflictDaysByExecutor;
      });
      print('✅ Dados via view: ${executorRows.length} executores');
    } catch (e, st) {
      print('❌ Erro ao construir executor rows via view: $e');
      print(st);
      setState(() {
        _executorRows = [];
        _conflictDaysByExecutor = {};
      });
    }
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
    
    // Para EXECUCAO: texto padrão = LOCAL. Botão pin alterna só local vs local+tarefa; Tt alterna visibilidade.
    final fontSize = _getOptimalFontSize(barWidth);
    final availableHeight = _rowHeight - 4; // Descontar padding
    final textColor = _getSegmentTextColor(task);
    final localText = _getTruncatedText(
      task.locais.isNotEmpty ? task.locais.join(', ') : '-',
      barWidth,
    );
    final taskText = _getTruncatedText(task.tarefa, barWidth);

    // Se textos estão ocultos pelo Tt, não renderiza conteúdo
    if (!_showSegmentTexts) {
      return const SizedBox.shrink();
    }

    // Linha única se altura pequena ou modo "só local"
    if (availableHeight < 20 || _showOnlyLocalText) {
      return Text(
        localText.isNotEmpty ? localText : taskText,
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

    // Duas linhas: local e tarefa
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (localText.isNotEmpty)
          Flexible(
            child: Text(
              localText,
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
        if (taskText.isNotEmpty)
          Flexible(
            child: Text(
              taskText,
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
    final isCompact = Responsive.isMobile(context) || Responsive.isTablet(context);
    final monthHeaderHeight = isCompact ? 0.0 : 25.0;

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
          if (monthHeaderHeight > 0)
            Container(
              height: monthHeaderHeight,
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
    final isCompact = Responsive.isMobile(context) || Responsive.isTablet(context);
    final monthHeaderHeight = isCompact ? 0.0 : 25.0;
    final dayHeaderHeight = 50.0;

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
                  if (monthHeaderHeight > 0)
                    Container(
                      height: monthHeaderHeight,
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
                                height: monthHeaderHeight,
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
                        // Botões para controle de texto: pin (local vs local+tarefa) e Tt (mostrar/ocultar)
                        Positioned(
                          right: 8,
                          top: 0,
                          bottom: 0,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
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
                    height: dayHeaderHeight,
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
                        height: dayHeaderHeight,
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
                    final execKeys = <String>{
                      _normalizeText(row.executor.nome),
                      if (row.executor.nomeCompleto != null) _normalizeText(row.executor.nomeCompleto!),
                      if (row.executor.login != null) _normalizeText(row.executor.login!),
                      if (row.executor.matricula != null) _normalizeText(row.executor.matricula!),
                    }..removeWhere((e) => e.isEmpty);
                    
                    for (var ep in task.executorPeriods) {
                      final normEpName = _normalizeText(ep.executorNome);
                      final sameId = ep.executorId.toLowerCase() == row.executor.id.toLowerCase();
                      final sameNameNorm = normEpName.isNotEmpty && execKeys.contains(normEpName);
                      if (sameId || sameNameNorm) {
                        executorPeriod = ep;
                        break;
                      }
                    }
                    
                    // Usar períodos do executor se disponível, senão usar segmentos gerais
                    // e garantir inclusão de PLANEJAMENTO/DESLOCAMENTO mesmo com executorPeriod.
                    final List<GanttSegment> segmentsToUse = [];
                    if (executorPeriod != null && executorPeriod.periods.isNotEmpty) {
                      // Sempre incluir períodos específicos do executor
                      segmentsToUse.addAll(executorPeriod.periods);
                      // Adicionar trechos não-EXEC dos ganttSegments (planejamento/deslocamento)
                      for (final seg in task.ganttSegments) {
                        if (seg.tipoPeriodo.toUpperCase() != 'EXECUCAO') {
                          segmentsToUse.add(seg);
                        }
                      }
                    } else {
                      segmentsToUse.addAll(task.ganttSegments);
                    }
                    // Segments não-EXEC (planejamento/deslocamento) já foram anexados em ganttSegments
                    // quando construímos tasksById. Aqui apenas garantimos que, se o executorPeriod
                    // existir, os não-EXEC dos ganttSegments sejam adicionados junto.
                    
                    return segmentsToUse.map((segment) {
                      // Normalizar datas do segmento
                      final rawStart = DateTime(
                        segment.dataInicio.year,
                        segment.dataInicio.month,
                        segment.dataInicio.day,
                      );
                      final rawEnd = DateTime(
                        segment.dataFim.year,
                        segment.dataFim.month,
                        segment.dataFim.day,
                      );
                      
                      // Período visível da tela
                      final periodStart = DateTime(widget.startDate.year, widget.startDate.month, widget.startDate.day);
                      final periodEnd = DateTime(widget.endDate.year, widget.endDate.month, widget.endDate.day);
                      
                      // Se está totalmente fora do range, descartar
                      if (rawStart.isAfter(periodEnd) || rawEnd.isBefore(periodStart)) {
                        return null;
                      }
                      
                      // Clampar para o range visível (garante inclusive no último dia)
                      final visibleStart = rawStart.isBefore(periodStart) ? periodStart : rawStart;
                      final visibleEnd = rawEnd.isAfter(periodEnd) ? periodEnd : rawEnd;
                      
                      // Se por algum motivo ficou inválido, descartar
                      if (visibleEnd.isBefore(visibleStart)) return null;
                      
                      final startOffset = _getDayOffset(visibleStart, days, dayWidth);
                      final duration = visibleEnd.difference(visibleStart).inDays + 1; // inclusive
                      final barWidth = duration * dayWidth;
                      
                      // Avaliar conflito por dia: se a view sinalizou conflito para o executor no dia,
                      // e o segmento cobre o dia, marcamos como conflito (independente de outras checagens locais).
                      List<DateTime> conflictDays = [];
                      var currentDay = visibleStart;
                      while (currentDay.isBefore(visibleEnd.add(const Duration(days: 1)))) {
                        final hasConflictThisExecutor = _hasConflictOnDayForExecutor(currentDay, row.executor.id);
                        if (hasConflictThisExecutor) {
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
    // Filtrar tarefas que cruzam o período (segmentos gerais ou por executor; fallback datas gerais)
    final periodStart = DateTime(widget.startDate.year, widget.startDate.month, widget.startDate.day);
    final periodEnd = DateTime(widget.endDate.year, widget.endDate.month, widget.endDate.day);

    bool cruzaPeriodo(Task task) {
      // Segmentos gerais
      for (var segment in task.ganttSegments) {
        final s = DateTime(segment.dataInicio.year, segment.dataInicio.month, segment.dataInicio.day);
        final e = DateTime(segment.dataFim.year, segment.dataFim.month, segment.dataFim.day);
        if (!(s.isAfter(periodEnd) || e.isBefore(periodStart))) return true;
      }
      // Segmentos por executor
      for (var ep in task.executorPeriods) {
        for (var segment in ep.periods) {
          final s = DateTime(segment.dataInicio.year, segment.dataInicio.month, segment.dataInicio.day);
          final e = DateTime(segment.dataFim.year, segment.dataFim.month, segment.dataFim.day);
          if (!(s.isAfter(periodEnd) || e.isBefore(periodStart))) return true;
        }
      }
      // Fallback datas gerais se não houver segmentos
      final semSegmentos = task.ganttSegments.isEmpty &&
          (task.executorPeriods.isEmpty || task.executorPeriods.every((ep) => ep.periods.isEmpty));
      if (semSegmentos) {
        return !(task.dataInicio.isAfter(periodEnd) || task.dataFim.isBefore(periodStart));
      }
      return false;
    }

    final tasksNoPeriodo = tasks.where(cruzaPeriodo).toList()
      ..sort((a, b) => a.dataInicio.compareTo(b.dataInicio));

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
                    onSelected: (value) async {
                      switch (value) {
                        case 'edit':
                          onEdit?.call(task);
                          break;
                        case 'delete':
                          final res = onDelete?.call(task);
                          if (res is Future) await res;
                          await _reloadTasksAndRows();
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

  bool _overlapsDay(DateTime start, DateTime end, DateTime dayStart, DateTime dayEnd) {
    // Converte tudo para dia local e trata o fim como exclusivo (próximo dia 00:00)
    final s = start.toLocal();
    final e = end.toLocal();
    final localDayStart = DateTime(dayStart.year, dayStart.month, dayStart.day);
    final localDayEndExclusive = localDayStart.add(const Duration(days: 1));
    return s.isBefore(localDayEndExclusive) && e.isAfter(localDayStart);
  }

  // Verificar se há conflito em um dia para um executor específico (somente segmentos de EXECUÇÃO)
  bool _hasConflictOnDayForExecutor(DateTime day, String executorId) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    // Se a view já sinalizou conflito para este executor/dia, priorizar esse sinal
    final conflicts = _conflictDaysByExecutor[executorId];
    if (conflicts != null && conflicts.contains(dayStart)) {
      return true;
    }

    final executor = _executores.firstWhere(
      (e) => e.id == executorId,
      orElse: () => Executor(id: executorId, nome: ''),
    );
    final Set<String> execKeys = {
      _normalizeText(executor.nome),
      if (executor.nomeCompleto != null) _normalizeText(executor.nomeCompleto!),
      if (executor.login != null) _normalizeText(executor.login!),
      if (executor.matricula != null) _normalizeText(executor.matricula!),
    }..removeWhere((e) => e.isEmpty);
    
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
      bool hasSpecificForExecutor = false;
      
      // Checar se existe algum período específico para este executor
      for (var executorPeriod in task.executorPeriods) {
        final epId = executorPeriod.executorId;
        final matchesExecutor =
            (epId.isNotEmpty && epId.toLowerCase() == executorId.toLowerCase()) ||
            execKeys.contains(_normalizeText(executorPeriod.executorNome));
        if (matchesExecutor && executorPeriod.periods.isNotEmpty) {
          hasSpecificForExecutor = true;
          for (var period in executorPeriod.periods) {
            if (period.tipoPeriodo.toUpperCase() != 'EXECUCAO') continue;
            if (_overlapsDay(period.dataInicio, period.dataFim, dayStart, dayEnd)) {
              taskHasExecSegmentOnDay = true;
              break;
            }
          }
          if (taskHasExecSegmentOnDay) break;
        }
      }
      
      // Só usar segmentos gerais se NÃO houver períodos específicos para este executor
      if (!hasSpecificForExecutor && !taskHasExecSegmentOnDay) {
        for (var segment in task.ganttSegments) {
          if (segment.tipoPeriodo.toUpperCase() != 'EXECUCAO') continue;
          if (_overlapsDay(segment.dataInicio, segment.dataFim, dayStart, dayEnd)) {
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
        
        // debug silenciado
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
                        // Cor base do segmento
                        Container(
                          decoration: BoxDecoration(
                            color: widget.color,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        // Conteúdo do segmento (texto) acima de tudo
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
                        // Overlay de conflito POR DIA (acima de tudo), só nos dias conflitantes
                        if ((widget.conflictDays?.isNotEmpty ?? false))
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Row(
                                children: widget.days.map((day) {
                                  final dayStart = DateTime(day.year, day.month, day.day);
                                  final dayEnd = dayStart.add(const Duration(days: 1));
                                  final coversDay = effectiveStartDate.isBefore(dayEnd) && effectiveEndDate.isAfter(dayStart);
                                  if (!coversDay) return const SizedBox.shrink();
                                  final isConflictDay = widget.conflictDays!.any((d) =>
                                      d.year == day.year && d.month == day.month && d.day == day.day);
                                  return Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: isConflictDay ? Colors.red[600]!.withOpacity(0.9) : Colors.transparent,
                                        borderRadius: isConflictDay ? BorderRadius.circular(3) : null,
                                        border: isConflictDay ? Border.all(color: Colors.red[800]!, width: 3) : null,
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
