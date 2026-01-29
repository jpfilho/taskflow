import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/task.dart';
import '../models/status.dart';
import '../models/regional.dart';
import '../models/divisao.dart';
import '../models/local.dart';
import '../models/segmento.dart';
import '../models/equipe.dart';
import '../models/executor.dart';
import '../services/status_service.dart';
import '../services/executor_service.dart';
import '../services/regional_service.dart';
import '../services/divisao_service.dart';
import '../services/local_service.dart';
import '../services/segmento_service.dart';
import '../services/equipe_service.dart';
import '../services/tipo_atividade_service.dart';
import '../models/tipo_atividade.dart';
import '../utils/responsive.dart';
import 'anexos_section.dart';
import '../services/chat_service.dart';
import '../models/grupo_chat.dart';
import 'chat_screen.dart';
import '../services/task_service.dart';
import '../services/nota_sap_service.dart';
import '../models/nota_sap.dart';
import '../services/auth_service_simples.dart';
import '../services/usuario_service.dart';
import '../services/frota_service.dart';
import '../models/frota.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'nota_sap_selection_dialog.dart';
import 'ordem_selection_dialog.dart';
import 'at_selection_dialog.dart';
import 'si_selection_dialog.dart';
import '../models/ordem.dart';
import '../services/ordem_service.dart';
import '../models/at.dart';
import '../services/at_service.dart';
import '../models/si.dart';
import '../services/si_service.dart';
import 'pex_apr_crc_view.dart';

class TaskFormDialog extends StatefulWidget {
  final Task? task; // null para criar, Task para editar
  final DateTime startDate;
  final DateTime endDate;
  final String? parentTaskId; // ID da tarefa pai (se for criar subtarefa)
  final NotaSAP? notaSAP; // Nota SAP para pré-preencher o formulário
  final Ordem? ordem; // Ordem para pré-preencher o formulário

  const TaskFormDialog({
    super.key,
    this.task,
    required this.startDate,
    required this.endDate,
    this.parentTaskId,
    this.notaSAP,
    this.ordem,
  });

  @override
  State<TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends State<TaskFormDialog> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;
  bool _isUserRoot = false; // Flag para verificar se usuário é root
  
  // ScrollControllers para manter a posição do scroll em cada tab
  final Map<int, ScrollController> _scrollControllers = {};
  final Map<int, double> _savedScrollPositions = {};
  late String _status;
  late String _regional;
  late String _divisao;
  late String _local;
  late String _tipo;
  String? _ordem;
  late String _tarefa;
  late String _executor;
  late String _frota;
  Frota? _selectedFrota; // Frota selecionada
  late String _coordenador;
  late String _si;
  bool _precisaSi = true;
  late DateTime _dataInicio;
  late DateTime _dataFim;
  String? _observacoes;
  double? _horasPrevistas;
  double? _horasExecutadas;

  // IDs selecionados
  String? _statusId;
  String? _regionalId;
  String? _divisaoId;
  String? _localId;
  String? _segmentoId;
  String? _equipeId;

  // Serviços
  final StatusService _statusService = StatusService();
  final RegionalService _regionalService = RegionalService();
  final DivisaoService _divisaoService = DivisaoService();
  final LocalService _localService = LocalService();
  final SegmentoService _segmentoService = SegmentoService();
  final EquipeService _equipeService = EquipeService();
  final ExecutorService _executorService = ExecutorService();
  final TipoAtividadeService _tipoAtividadeService = TipoAtividadeService();
  final ChatService _chatService = ChatService();
  final TaskService _taskService = TaskService();
  final NotaSAPService _notaSAPService = NotaSAPService();
  final AuthServiceSimples _authService = AuthServiceSimples();
  final UsuarioService _usuarioService = UsuarioService();
  final FrotaService _frotaService = FrotaService();
  
  // Perfil do usuário atual
  Usuario? _usuarioAtual;
  List<String> _segmentoIdsPerfil = []; // IDs dos segmentos permitidos no perfil

  // Listas carregadas
  List<Status> _statusList = [];
  List<Regional> _regionaisList = [];
  List<Divisao> _divisoesList = [];
  List<Local> _locaisList = [];
  List<Segmento> _segmentosList = [];
  List<Equipe> _equipesList = [];
  List<Executor> _executoresList = [];
  List<Executor> _coordenadoresList = []; // Lista de coordenadores
  List<TipoAtividade> _tiposAtividadeList = [];
  List<Frota> _frotasList = []; // Lista de frotas filtradas
  bool _isLoading = true;
  bool _isLoadingExecutoresEquipes = false;

  // Seleções
  Status? _selectedStatus;
  Regional? _selectedRegional;
  Divisao? _selectedDivisao;
  Set<String> _selectedLocalIds = {};
  List<Local?> _locaisSelecionados = []; // Lista de locais selecionados (um por dropdown)
  Segmento? _selectedSegmento;
  Set<String> _selectedExecutorIds = {};
  List<Executor?> _executoresSelecionados = []; // Lista de executores selecionados (um por dropdown)
  Set<String> _selectedEquipeIds = {};
  Equipe? _selectedEquipe; // Para compatibilidade temporária
  bool _usarEquipe = false; // Toggle entre equipe e executor individual
  String? _tipoExecutorEquipe; // 'executor' ou 'equipe'
  Set<String> _selectedFrotaIds = {};
  List<Frota?> _frotasSelecionadas = []; // Lista de frotas selecionadas (um por dropdown)

  
  // Lista de segmentos do Gantt (períodos de execução)
  List<GanttSegment> _ganttSegments = [];
  
  // Períodos específicos por executor
  List<ExecutorPeriod> _executorPeriods = [];
  // Períodos específicos por frota
  List<FrotaPeriod> _frotaPeriods = [];

  List<GanttSegment> _cloneTaskSegmentsOrFallback() {
    if (_ganttSegments.isNotEmpty) {
      return _ganttSegments
          .map((s) => GanttSegment(
                dataInicio: s.dataInicio,
                dataFim: s.dataFim,
                label: s.label,
                tipo: s.tipo,
                tipoPeriodo: s.tipoPeriodo,
              ))
          .toList();
    }
    return [
      GanttSegment(
        dataInicio: _dataInicio,
        dataFim: _dataFim,
        label: _tarefa,
        tipo: _mapTaskTypeToSegmentType(_tipo),
        tipoPeriodo: 'EXECUCAO',
      )
    ];
  }
  
  // Notas SAP vinculadas
  List<NotaSAP> _notasSAPVinculadas = [];
  bool _isLoadingNotasSAP = false;
  bool _isAdicionandoNotaSAP = false;
  
  // Ordens vinculadas
  final OrdemService _ordemService = OrdemService();
  List<Ordem> _ordensVinculadas = [];
  bool _isLoadingOrdens = false;
  bool _isAdicionandoOrdem = false;
  
  // ATs vinculadas
  final ATService _atService = ATService();
  List<AT> _atsVinculadas = [];
  bool _isLoadingATs = false;
  bool _isAdicionandoAT = false;
  
  // SIs vinculadas
  final SIService _siService = SIService();
  List<SI> _sisVinculadas = [];
  bool _isLoadingSIs = false;
  bool _isAdicionandoSI = false;
  
  // Controle do grupo SAP
  String _sapSubTab = 'notas'; // 'notas', 'ordens', 'ats', 'sis'

  @override
  void dispose() {
    _tabController.dispose();
    // Limpar todos os ScrollControllers
    for (var controller in _scrollControllers.values) {
      controller.dispose();
    }
    _scrollControllers.clear();
    _savedScrollPositions.clear();
    super.dispose();
  }
  
  // Obter ou criar ScrollController para uma tab específica
  ScrollController _getScrollController(int tabIndex) {
    if (!_scrollControllers.containsKey(tabIndex)) {
      _scrollControllers[tabIndex] = ScrollController();
    }
    return _scrollControllers[tabIndex]!;
  }
  
  // Salvar posição do scroll antes de fazer setState
  void _saveScrollPositions() {
    _savedScrollPositions.clear();
    for (var entry in _scrollControllers.entries) {
      if (entry.value.hasClients) {
        _savedScrollPositions[entry.key] = entry.value.offset;
      }
    }
  }
  
  // Restaurar posição do scroll após rebuild
  void _restoreScrollPositions() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (var entry in _savedScrollPositions.entries) {
        final controller = _scrollControllers[entry.key];
        if (controller != null && controller.hasClients) {
          controller.jumpTo(entry.value);
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    // Inicializar com 7 tabs por padrão (incluindo Frota, sem PEX/APR)
    // Será ajustado para 8 se o usuário for root
    _tabController = TabController(length: 7, vsync: this);
    
    // Listener para salvar posição do scroll ao trocar de tab
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        // Tab mudou completamente, salvar posição da tab anterior
        _saveScrollPositions();
      }
    });
    
    if (widget.task != null) {
      // Modo edição
      final task = widget.task!;
      _statusId = task.statusId;
      _regionalId = task.regionalId;
      _divisaoId = task.divisaoId;
      _localId = task.localIds.isNotEmpty ? task.localIds.first : task.localId; // Compatibilidade
      _segmentoId = task.segmentoId;
      _equipeId = task.equipeIds.isNotEmpty ? task.equipeIds.first : task.equipeId; // Compatibilidade
      _usarEquipe = task.equipeIds.isNotEmpty || (task.equipeId != null && task.equipeId!.isNotEmpty);
      _status = task.status;
      _regional = task.regional;
      _divisao = task.divisao;
      _local = task.locais.isNotEmpty ? task.locais.join(', ') : ''; // Para exibição
      _selectedLocalIds = Set<String>.from(task.localIds);
      _tipo = task.tipo;
      _ordem = task.ordem;
      _tarefa = task.tarefa;
      _executor = task.equipeId != null ? '' : task.executor;
      _frota = task.frota;
      _coordenador = task.coordenador;
      _si = task.si;
      _precisaSi = task.precisaSi;
      _dataInicio = task.dataInicio;
      _dataFim = task.dataFim;
      _observacoes = task.observacoes;
      _horasPrevistas = task.horasPrevistas;
      _horasExecutadas = task.horasExecutadas;
      // Carregar segmentos do Gantt
      _ganttSegments = List<GanttSegment>.from(task.ganttSegments);
      // Se não houver segmentos, criar um inicial
      if (_ganttSegments.isEmpty) {
        final segmentType = _mapTaskTypeToSegmentType(_tipo);
        _ganttSegments = [
          GanttSegment(
            dataInicio: _dataInicio,
            dataFim: _dataFim,
            label: _tarefa,
            tipo: segmentType,
            tipoPeriodo: 'EXECUCAO',
          ),
        ];
      }
      
      // Carregar períodos por executor
      _executorPeriods = List<ExecutorPeriod>.from(task.executorPeriods);
      // Carregar períodos por frota vindos da tarefa (pode vir vazio em alguns fluxos)
      _frotaPeriods = List<FrotaPeriod>.from(task.frotaPeriods);
      // Garantir que períodos por frota sejam buscados do Supabase caso não tenham vindo com a tarefa
      _ensureFrotaPeriodsLoaded(task.id);
      print('📋 TaskFormDialog: Carregados ${_executorPeriods.length} períodos por executor');
      for (var ep in _executorPeriods) {
        print('   - Executor: ${ep.executorNome} (${ep.periods.length} períodos)');
      }
    print('📋 TaskFormDialog: Carregados ${_frotaPeriods.length} períodos por frota');
    for (var fp in _frotaPeriods) {
      print('   - Frota: ${fp.frotaNome} (${fp.periods.length} períodos)');
    }
    } else {
      // Modo criação
      _tipo = ''; // Será definido após carregar tipos de atividade
      _ordem = '';
      _tarefa = '';
      _executor = '';
      _frota = '-N/A-';
      _coordenador = '';
      _si = '-N/A-';
      _precisaSi = true;
      _dataInicio = widget.startDate;
      _dataFim = widget.endDate;
      
      // Se há uma nota SAP, pré-preencher campos
      if (widget.notaSAP != null) {
        final nota = widget.notaSAP!;
        _ordem = nota.ordem ?? '';
        _tarefa = nota.descricao ?? '';
        _si = nota.nota;
        _dataInicio = nota.inicioDesejado ?? widget.startDate;
        _dataFim = nota.conclusaoDesejada ?? widget.endDate;
        // A nota SAP será vinculada após criar a tarefa
        _notasSAPVinculadas = [nota]; // Adicionar à lista para mostrar no formulário
      }
      
      // Se há uma ordem, pré-preencher campos
      if (widget.ordem != null) {
        final ordem = widget.ordem!;
        _ordem = ordem.ordem;
        _tarefa = ordem.textoBreve ?? '';
        _si = ordem.codigoSI ?? '-N/A-';
        _dataInicio = ordem.inicioBase ?? widget.startDate;
        _dataFim = ordem.fimBase ?? widget.endDate;
      }
    }
    
    // Carregar dados e, se for subtarefa, herdar campos da tarefa pai
    // Usar WidgetsBinding para garantir que o primeiro frame foi renderizado
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadData();
      
      // Se for criar subtarefa, carregar tarefa pai e herdar campos
      // IMPORTANTE: Aguardar _loadData() terminar antes de carregar tarefa pai
      if (widget.parentTaskId != null && widget.task == null) {
        await _loadParentTask();
      }
      
      // Inicializar segmentos para nova tarefa (apenas se não for subtarefa)
      // Se for subtarefa, os segmentos já foram herdados em _loadParentTask()
      if (widget.task == null && widget.parentTaskId == null) {
        final segmentType = _mapTaskTypeToSegmentType(_tipo);
        _ganttSegments = [
          GanttSegment(
            dataInicio: _dataInicio,
            dataFim: _dataFim,
            label: _tarefa,
            tipo: segmentType,
            tipoPeriodo: 'EXECUCAO',
          ),
        ];
      }
      
      // Carregar notas SAP, ordens, ATs e SIs vinculadas (apenas para tarefas existentes)
      if (widget.task != null) {
        _loadNotasSAP();
        _loadOrdens();
        _loadATs();
        _loadSIs();
      }
    });
  }

  // Busca direta no Supabase se a tarefa não veio com períodos por frota
  Future<void> _ensureFrotaPeriodsLoaded(String? taskId) async {
    if (taskId == null) return;
    if (_frotaPeriods.isNotEmpty) return;

    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('frota_periods')
          .select()
          .eq('task_id', taskId)
          .order('frota_nome', ascending: true)
          .order('data_inicio', ascending: true);

      if (response.isEmpty) return;

      final Map<String, FrotaPeriod> frotaMap = {};

      for (final item in response as List) {
        final frotaId = item['frota_id'] as String;
        final frotaNome = item['frota_nome'] as String? ?? '';
        final diParsed = DateTime.parse(item['data_inicio'] as String);
        final dfParsed = DateTime.parse(item['data_fim'] as String);
        final segment = GanttSegment(
          dataInicio: DateTime(diParsed.year, diParsed.month, diParsed.day),
          dataFim: DateTime(dfParsed.year, dfParsed.month, dfParsed.day),
          label: item['label'] as String? ?? '',
          tipo: (item['tipo'] as String? ?? 'OUT').toUpperCase(),
          tipoPeriodo: (item['tipo_periodo'] as String? ?? 'EXECUCAO').toUpperCase(),
        );

        if (frotaMap.containsKey(frotaId)) {
          final existing = frotaMap[frotaId]!;
          frotaMap[frotaId] = existing.copyWith(
            periods: [...existing.periods, segment],
          );
        } else {
          frotaMap[frotaId] = FrotaPeriod(
            frotaId: frotaId,
            frotaNome: frotaNome,
            periods: [segment],
          );
        }
      }

      if (mounted && frotaMap.isNotEmpty) {
        setState(() {
          _frotaPeriods = frotaMap.values.toList();
        });
        print('📋 TaskFormDialog: Carregados ${_frotaPeriods.length} períodos por frota (fetch direto)');
      }
    } catch (e) {
      print('⚠️ Erro ao carregar períodos por frota diretamente do Supabase: $e');
    }
  }
  
  Future<void> _loadNotasSAP() async {
    // Carregar notas SAP se for edição ou se há uma nota SAP pré-selecionada
    if (widget.task == null && widget.notaSAP == null) {
      print('⚠️ _loadNotasSAP: widget.task é null e widget.notaSAP é null, não carregando');
      return;
    }
    
    if (widget.task == null) {
      print('⚠️ _loadNotasSAP: widget.task é null, não carregando');
      return;
    }
    
    print('📋 Carregando notas SAP para tarefa ${widget.task!.id}...');
    setState(() {
      _isLoadingNotasSAP = true;
    });
    
    try {
      final notas = await _notaSAPService.getNotasPorTarefa(widget.task!.id);
      print('✅ Carregadas ${notas.length} notas SAP vinculadas');
      setState(() {
        _notasSAPVinculadas = notas;
        _isLoadingNotasSAP = false;
      });
    } catch (e, stackTrace) {
      print('❌ Erro ao carregar notas SAP: $e');
      print('   Stack trace: $stackTrace');
      setState(() {
        _isLoadingNotasSAP = false;
      });
    }
  }

  // Carregar tarefa pai e herdar todos os campos
  Future<void> _loadParentTask() async {
    if (widget.parentTaskId == null) return;
    
    try {
      final parentTask = await _taskService.getTaskById(widget.parentTaskId!);
      if (parentTask == null) {
        print('⚠️ Tarefa pai não encontrada: ${widget.parentTaskId}');
        return;
      }
      
      print('📋 Carregando tarefa pai: ${parentTask.tarefa}');
      print('   Status: ${parentTask.status}');
      print('   Regional: ${parentTask.regional}');
      print('   Divisão: ${parentTask.divisao}');
      print('   Segmento: ${parentTask.segmento}');
      print('   Locais: ${parentTask.locais.join(", ")}');
      print('   Tipo: ${parentTask.tipo}');
      print('   Executores: ${parentTask.executores.join(", ")}');
      print('   Equipes: ${parentTask.equipes.join(", ")}');
      print('   Coordenador: ${parentTask.coordenador}');
      print('   Frota: ${parentTask.frota}');
      print('   SI: ${parentTask.si}');
      // debug silenciado
      for (var seg in parentTask.ganttSegments) {
        print('     - ${seg.dataInicio.toString().substring(0, 10)} até ${seg.dataFim.toString().substring(0, 10)} (${seg.tipo}, ${seg.tipoPeriodo})');
      }
      
      // Herdar todos os campos da tarefa pai
      setState(() {
        // IDs
        _statusId = parentTask.statusId;
        _regionalId = parentTask.regionalId;
        _divisaoId = parentTask.divisaoId;
        _segmentoId = parentTask.segmentoId;
        _selectedLocalIds = Set<String>.from(parentTask.localIds);
        _selectedExecutorIds = Set<String>.from(parentTask.executorIds);
        _selectedEquipeIds = Set<String>.from(parentTask.equipeIds);
        _selectedFrotaIds = Set<String>.from(parentTask.frotaIds);
        
        // Inicializar lista de executores selecionados para os dropdowns (será atualizado após carregar executores)
        if (_executoresList.isNotEmpty) {
          final executoresEncontradosParent = _executoresList.where((e) => _selectedExecutorIds.contains(e.id)).toList();
          _executoresSelecionados = executoresEncontradosParent.map<Executor?>((e) => e as Executor?).toList();
        }
        if (_executoresSelecionados.isEmpty) {
          _executoresSelecionados = <Executor?>[null]; // Pelo menos um dropdown vazio
        }
        
        // Valores de exibição
        _status = parentTask.status;
        _regional = parentTask.regional;
        _divisao = parentTask.divisao;
        _local = parentTask.locais.join(', ');
        _tipo = parentTask.tipo;
        _ordem = parentTask.ordem ?? '';
        _frota = parentTask.frota;
        _coordenador = parentTask.coordenador;
        _si = parentTask.si;
        _precisaSi = parentTask.precisaSi;
        
        // Herdar períodos (segmentos do Gantt) da tarefa pai
        if (parentTask.ganttSegments.isNotEmpty) {
          _ganttSegments = parentTask.ganttSegments.map((seg) => GanttSegment(
            dataInicio: seg.dataInicio,
            dataFim: seg.dataFim,
            label: seg.label,
            tipo: seg.tipo,
            tipoPeriodo: seg.tipoPeriodo,
          )).toList();
          print('✅ ${_ganttSegments.length} períodos herdados da tarefa pai');
          
          // Atualizar dataInicio e dataFim da subtarefa com base nos segmentos herdados
          _dataInicio = _ganttSegments.map((s) => s.dataInicio).reduce((a, b) => a.isBefore(b) ? a : b);
          _dataFim = _ganttSegments.map((s) => s.dataFim).reduce((a, b) => a.isAfter(b) ? a : b);
        } else {
          // Se a tarefa pai não tem segmentos, criar um padrão baseado nas datas da tarefa pai
          final segmentType = _mapTaskTypeToSegmentType(parentTask.tipo);
          _ganttSegments = [
            GanttSegment(
              dataInicio: parentTask.dataInicio,
              dataFim: parentTask.dataFim,
              label: '',
              tipo: segmentType,
              tipoPeriodo: 'EXECUCAO',
            ),
          ];
          _dataInicio = parentTask.dataInicio;
          _dataFim = parentTask.dataFim;
          print('⚠️ Tarefa pai não tem segmentos. Criado período padrão.');
        }
        
        // Executor/Equipe
        if (parentTask.equipeIds.isNotEmpty || (parentTask.equipeId != null && parentTask.equipeId!.isNotEmpty)) {
          _usarEquipe = true;
          _tipoExecutorEquipe = 'equipe';
        } else if (parentTask.executores.isNotEmpty) {
          _usarEquipe = false;
          _tipoExecutorEquipe = 'executor';
          _executor = parentTask.executores.first;
        }
        
        // Inicializar lista de locais selecionados para os dropdowns
        final locaisEncontrados = _locaisList.where((l) => _selectedLocalIds.contains(l.id)).toList();
        _locaisSelecionados = locaisEncontrados.map<Local?>((l) => l as Local?).toList();
        if (_locaisSelecionados.isEmpty) {
          _locaisSelecionados = <Local?>[null]; // Pelo menos um dropdown vazio
        }
        
        // Selecionar Status, Regional e Divisão nos dropdowns
        if (_statusId != null && _statusList.isNotEmpty) {
          try {
            _selectedStatus = _statusList.firstWhere((s) => s.id == _statusId);
          } catch (e) {
            print('⚠️ Status ${_statusId} não encontrado na lista');
          }
        }
        
        if (_regionalId != null && _regionaisList.isNotEmpty) {
          try {
            _selectedRegional = _regionaisList.firstWhere((r) => r.id == _regionalId);
          } catch (e) {
            print('⚠️ Regional ${_regionalId} não encontrada na lista');
          }
        }
        
        if (_divisaoId != null && _divisoesList.isNotEmpty) {
          try {
            _selectedDivisao = _divisoesList.firstWhere((d) => d.id == _divisaoId);
          } catch (e) {
            print('⚠️ Divisão ${_divisaoId} não encontrada na lista');
          }
        }
      });
      
      // Carregar segmentos da divisão herdada (aguardar para poder selecionar o segmento)
      if (_divisaoId != null) {
        await _loadSegmentosPorDivisao();
        
        // Após carregar segmentos, selecionar o segmento da tarefa pai
        if (_segmentoId != null && _segmentoId!.isNotEmpty && _segmentosList.isNotEmpty) {
          setState(() {
            try {
              _selectedSegmento = _segmentosList.firstWhere((s) => s.id == _segmentoId);
              print('✅ Segmento da tarefa pai selecionado: ${_selectedSegmento!.segmento}');
            } catch (e) {
              print('⚠️ Segmento ${_segmentoId} da tarefa pai não encontrado na lista');
              _selectedSegmento = null;
            }
          });
        }
      }
      
      // Carregar tipos de atividade e executores/equipes filtrados após selecionar segmento
      await _loadTiposAtividade();
      await _loadExecutoresEquipesFiltrados();
      await _loadCoordenadores();
      
      print('✅ Campos da tarefa pai herdados com sucesso');
    } catch (e) {
      print('❌ Erro ao carregar tarefa pai: $e');
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Carregar perfil do usuário atual
      final usuarioLogado = _authService.currentUser;
      if (usuarioLogado != null && usuarioLogado.id != null) {
        try {
          _usuarioAtual = await _usuarioService.obterUsuarioPorId(usuarioLogado.id!);
          if (_usuarioAtual != null && !_usuarioAtual!.isRoot) {
            _segmentoIdsPerfil = _usuarioAtual!.segmentoIds;
            _isUserRoot = false;
            print('👤 Perfil do usuário carregado: ${_usuarioAtual!.segmentos.length} segmentos');
            print('   Segmentos do perfil: ${_usuarioAtual!.segmentos.join(", ")}');
            print('   IDs dos segmentos: ${_segmentoIdsPerfil.join(", ")}');
          } else if (_usuarioAtual != null && _usuarioAtual!.isRoot) {
            _isUserRoot = true;
            print('👤 Usuário root: sem filtro de segmentos');
            _segmentoIdsPerfil = []; // Root não tem filtro
          }
        } catch (e) {
          print('⚠️ Erro ao carregar perfil do usuário: $e');
          _segmentoIdsPerfil = []; // Se houver erro, não filtrar
        }
      }
      
      // Carregar dados básicos
      final futures = await Future.wait([
        _statusService.getAllStatus(),
        _regionalService.getAllRegionais(),
        _divisaoService.getAllDivisoes(),
        _segmentoService.getAllSegmentos(),
        _equipeService.getEquipesAtivas(),
        _frotaService.getAllFrotas(),
      ]);
      
      // Carregar locais filtrados pelo perfil do usuário
      // Lógica especial: considerar paraTodaRegional, paraTodaDivisao e IDs específicos
      List<Local> locaisFiltrados = [];
      print('🔍 DEBUG Locais: Iniciando carregamento...');
      print('   _usuarioAtual: ${_usuarioAtual != null ? "existe" : "null"}');
      if (_usuarioAtual != null) {
        print('   isRoot: ${_usuarioAtual!.isRoot}');
        print('   temPerfilConfigurado: ${_usuarioAtual!.temPerfilConfigurado()}');
        print('   Regional IDs: ${_usuarioAtual!.regionalIds}');
        print('   Divisão IDs: ${_usuarioAtual!.divisaoIds}');
        print('   Segmento IDs: ${_usuarioAtual!.segmentoIds}');
      }
      
      if (_usuarioAtual != null && !_usuarioAtual!.isRoot && _usuarioAtual!.temPerfilConfigurado()) {
        print('🔒 DEBUG Locais: Filtrando pelo perfil do usuário...');
        // Buscar TODOS os locais primeiro para verificar os flags
        final todosLocais = await _localService.getAllLocais();
        print('   Total de locais no banco: ${todosLocais.length}');
        
        Set<Local> locaisUnicos = {};
        
        // Para cada local, verificar se deve ser incluído baseado no perfil do usuário
        for (final local in todosLocais) {
          bool deveIncluir = false;
          
          // 1. Verificar locais "para toda a regional"
          if (local.paraTodaRegional && local.regionalId != null) {
            if (_usuarioAtual!.regionalIds.contains(local.regionalId)) {
              print('     ✅ Local "${local.local}" incluído: para toda a regional ${local.regionalId}');
              deveIncluir = true;
            }
          }
          
          // 2. Verificar locais "para toda a divisão"
          if (!deveIncluir && local.paraTodaDivisao && local.divisaoId != null) {
            if (_usuarioAtual!.divisaoIds.contains(local.divisaoId)) {
              print('     ✅ Local "${local.local}" incluído: para toda a divisão ${local.divisaoId}');
              deveIncluir = true;
            }
          }
          
          // 3. Verificar locais com segmento específico
          if (!deveIncluir && local.segmentoId != null && local.segmentoId!.isNotEmpty) {
            if (_usuarioAtual!.segmentoIds.contains(local.segmentoId)) {
              print('     ✅ Local "${local.local}" incluído: segmento específico ${local.segmentoId}');
              deveIncluir = true;
            }
          }
          
          // 4. Verificar locais com divisão específica
          if (!deveIncluir && local.divisaoId != null && local.divisaoId!.isNotEmpty) {
            if (_usuarioAtual!.divisaoIds.contains(local.divisaoId)) {
              print('     ✅ Local "${local.local}" incluído: divisão específica ${local.divisaoId}');
              deveIncluir = true;
            }
          }
          
          // 5. Verificar locais com regional específica
          if (!deveIncluir && local.regionalId != null && local.regionalId!.isNotEmpty) {
            if (_usuarioAtual!.regionalIds.contains(local.regionalId)) {
              print('     ✅ Local "${local.local}" incluído: regional específica ${local.regionalId}');
              deveIncluir = true;
            }
          }
          
          if (deveIncluir) {
            locaisUnicos.add(local);
          }
        }
        
        locaisFiltrados = locaisUnicos.toList();
        print('🔒 DEBUG Locais: Total de locais únicos após filtro: ${locaisFiltrados.length}');
        if (locaisFiltrados.isNotEmpty) {
          print('   Primeiros 3 locais:');
          for (var i = 0; i < locaisFiltrados.length && i < 3; i++) {
            final local = locaisFiltrados[i];
            print('     - ${local.local} (paraTodaRegional: ${local.paraTodaRegional}, paraTodaDivisao: ${local.paraTodaDivisao}, regional: ${local.regionalId}, divisao: ${local.divisaoId}, segmento: ${local.segmentoId})');
          }
        }
      } else {
        print('👑 DEBUG Locais: Usuário root ou sem perfil, buscando todos os locais...');
        // Usuário root ou sem perfil: buscar todos os locais
        locaisFiltrados = await _localService.getAllLocais();
        print('👑 DEBUG Locais: Total de locais encontrados: ${locaisFiltrados.length}');
      }

      setState(() {
        _statusList = futures[0] as List<Status>;
        final todasRegionais = futures[1] as List<Regional>;
        final todasDivisoes = futures[2] as List<Divisao>;
        // Locais já foram carregados e filtrados acima
        // Não carregar todos os segmentos aqui - serão carregados quando divisão for selecionada
        _segmentosList = futures[3] as List<Segmento>;
        _equipesList = futures[4] as List<Equipe>;
        final todasFrotas = futures[5] as List<Frota>;
        
        // Ajustar número de tabs baseado no perfil do usuário
        // 6 tabs básicas + 1 PEX/APR (apenas root) + 1 SAP = 7 ou 8
        final int numTabs = _isUserRoot ? 8 : 7;
        if (_tabController.length != numTabs) {
          final int oldIndex = _tabController.index;
          _tabController.dispose();
          _tabController = TabController(
            length: numTabs, 
            vsync: this,
            initialIndex: oldIndex < numTabs ? oldIndex : 0,
          );
        }
        
        // Filtrar pelo perfil do usuário
        _regionaisList = _filtrarRegionaisPorPerfil(todasRegionais);
        _divisoesList = _filtrarDivisoesPorPerfil(todasDivisoes);
        _locaisList = locaisFiltrados; // Já filtrados pelo perfil acima
        _frotasList = _filtrarFrotasPorPerfil(todasFrotas);
        
        _isLoading = false;

        // Selecionar valores se estiver editando
        if (widget.task != null) {
          final task = widget.task!;
          // Status - verificar se existe na lista antes de atribuir
          if (task.statusId != null && task.statusId!.isNotEmpty) {
            try {
              final found = _statusList.firstWhere((s) => s.id == task.statusId);
              _selectedStatus = found;
            } catch (e) {
              // Tentar por código
              try {
                _selectedStatus = _statusList.firstWhere((s) => s.codigo == task.status);
              } catch (e2) {
                _selectedStatus = null;
              }
            }
          } else if (_statusList.isNotEmpty && task.status.isNotEmpty) {
            try {
              _selectedStatus = _statusList.firstWhere((s) => s.codigo == task.status);
            } catch (e) {
              _selectedStatus = null;
            }
          }
          
          // Regional - verificar se existe na lista antes de atribuir
          if (task.regionalId != null && task.regionalId!.isNotEmpty) {
            try {
              _selectedRegional = _regionaisList.firstWhere((r) => r.id == task.regionalId);
            } catch (e) {
              _selectedRegional = null;
            }
          }
          
          // Divisão - verificar se existe na lista antes de atribuir
          if (task.divisaoId != null && task.divisaoId!.isNotEmpty) {
            try {
              _selectedDivisao = _divisoesList.firstWhere((d) => d.id == task.divisaoId);
            } catch (e) {
              _selectedDivisao = null;
            }
          }
          
          // Carregar múltiplos locais - filtrar apenas os que existem na lista
          _selectedLocalIds = Set<String>.from(
            task.localIds.where((id) => _locaisList.any((l) => l.id == id))
          );
          if (_selectedLocalIds.isEmpty && task.localId != null && task.localId!.isNotEmpty) {
            if (_locaisList.any((l) => l.id == task.localId)) {
              _selectedLocalIds.add(task.localId!);
            }
          }
          // Inicializar lista de locais selecionados para os dropdowns
          final locaisEncontrados = _locaisList.where((l) => _selectedLocalIds.contains(l.id)).toList();
          // Criar lista explicitamente tipada como List<Local?>
          _locaisSelecionados = locaisEncontrados.map<Local?>((l) => l as Local?).toList();
          if (_locaisSelecionados.isEmpty) {
            _locaisSelecionados = <Local?>[null]; // Pelo menos um dropdown vazio
          }
          
          // Segmento - verificar se existe na lista antes de atribuir
          if (task.segmentoId != null && task.segmentoId!.isNotEmpty) {
            try {
              _selectedSegmento = _segmentosList.firstWhere((s) => s.id == task.segmentoId);
            } catch (e) {
              _selectedSegmento = null;
            }
          }
          // Carregar múltiplas equipes
          _selectedEquipeIds = Set<String>.from(task.equipeIds);
          if (_selectedEquipeIds.isEmpty && task.equipeId != null && task.equipeId!.isNotEmpty) {
            _selectedEquipeIds.add(task.equipeId!);
            _usarEquipe = true;
          }
          
          // Carregar múltiplos executores (IDs serão usados depois que executores forem carregados)
          _selectedExecutorIds = Set<String>.from(task.executorIds);
          if (_selectedExecutorIds.isEmpty && task.executor.isNotEmpty) {
            // Tentar encontrar executor pelo nome (será feito depois que executores forem carregados)
            // Por enquanto, apenas marcar que precisa buscar pelo nome
          }
          
          // Carregar múltiplas frotas (IDs serão usados depois que frotas forem carregadas)
          _selectedFrotaIds = Set<String>.from(task.frotaIds);
          if (_selectedFrotaIds.isEmpty && task.frota.isNotEmpty && task.frota != '-N/A-') {
            // Tentar encontrar frota pelo nome (será feito depois que frotas forem carregadas)
            // Por enquanto, apenas marcar que precisa buscar pelo nome
          }
        } else {
          // Valores padrão para criação
          // Se for subtarefa, os campos já foram herdados em _loadParentTask
          // Caso contrário, usar valores padrão
          if (widget.parentTaskId == null) {
            if (_statusList.isNotEmpty) {
              _selectedStatus = _statusList.firstWhere(
                (s) => s.codigo == 'PROG',
                orElse: () => _statusList.first,
              );
            }
            if (_regionaisList.isNotEmpty) {
              _selectedRegional = _regionaisList.first;
            }
            if (_divisoesList.isNotEmpty) {
              _selectedDivisao = _divisoesList.first;
              // Carregar segmentos da primeira divisão
              _loadSegmentosPorDivisao();
            }
            // Inicializar lista de locais selecionados com um dropdown vazio
            if (_locaisSelecionados.isEmpty) {
              _locaisSelecionados = <Local?>[null];
            }
            // Não selecionar local por padrão (usuário deve escolher)
            // Segmento será selecionado após carregar da divisão
          } else {
            // Se for subtarefa, aplicar campos herdados após carregar as listas
            // Status
            if (_statusId != null && _statusId!.isNotEmpty) {
              try {
                _selectedStatus = _statusList.firstWhere((s) => s.id == _statusId);
              } catch (e) {
                try {
                  _selectedStatus = _statusList.firstWhere((s) => s.codigo == _status);
                } catch (e2) {
                  _selectedStatus = null;
                }
              }
            }
            // Regional
            if (_regionalId != null && _regionalId!.isNotEmpty) {
              try {
                _selectedRegional = _regionaisList.firstWhere((r) => r.id == _regionalId);
              } catch (e) {
                _selectedRegional = null;
              }
            }
            // Divisão
            if (_divisaoId != null && _divisaoId!.isNotEmpty) {
              try {
                _selectedDivisao = _divisoesList.firstWhere((d) => d.id == _divisaoId);
                // Carregar segmentos da divisão herdada
                _loadSegmentosPorDivisao();
              } catch (e) {
                _selectedDivisao = null;
              }
            }
            // Segmento
            if (_segmentoId != null && _segmentoId!.isNotEmpty && _segmentosList.isNotEmpty) {
              try {
                _selectedSegmento = _segmentosList.firstWhere((s) => s.id == _segmentoId);
              } catch (e) {
                _selectedSegmento = null;
              }
            }
            // Locais
            if (_selectedLocalIds.isNotEmpty) {
              final locaisEncontrados = _locaisList.where((l) => _selectedLocalIds.contains(l.id)).toList();
              _locaisSelecionados = locaisEncontrados.map<Local?>((l) => l as Local?).toList();
              if (_locaisSelecionados.isEmpty) {
                _locaisSelecionados = <Local?>[null];
              }
            }
          }
        }

        // Atualizar valores de exibição
        if (_selectedStatus != null) {
          _status = _selectedStatus!.codigo;
          _statusId = _selectedStatus!.id;
        }
        if (_selectedRegional != null) {
          _regional = _selectedRegional!.regional;
          _regionalId = _selectedRegional!.id;
        }
        if (_selectedDivisao != null) {
          _divisao = _selectedDivisao!.divisao;
          _divisaoId = _selectedDivisao!.id;
        }
        // Atualizar local para exibição
        if (_selectedLocalIds.isNotEmpty) {
          final selectedLocais = _locaisList.where((l) => _selectedLocalIds.contains(l.id)).toList();
          _local = selectedLocais.map((l) => l.local).join(', ');
          _localId = _selectedLocalIds.first; // Para compatibilidade
        }
        if (_selectedSegmento != null) {
          _segmentoId = _selectedSegmento!.id;
        }
      });

      // Carregar segmentos da divisão selecionada (se houver)
      if (_selectedDivisao != null) {
        await _loadSegmentosPorDivisao();
        
        // Após carregar segmentos, selecionar o segmento da tarefa (se houver)
        if (widget.task != null && widget.task!.segmentoId != null && widget.task!.segmentoId!.isNotEmpty) {
          setState(() {
            try {
              _selectedSegmento = _segmentosList.firstWhere((s) => s.id == widget.task!.segmentoId);
              _segmentoId = _selectedSegmento!.id;
              print('✅ Segmento selecionado após carregar: ${_selectedSegmento!.segmento}');
            } catch (e) {
              print('⚠️ Segmento ${widget.task!.segmentoId} não encontrado na lista de segmentos da divisão');
              _selectedSegmento = null;
            }
          });
        }
      }

      // Carregar tipos de atividade
      await _loadTiposAtividade();

      // Carregar executores e equipes filtrados (mesmo sem filtros, carrega todos)
      await _loadExecutoresEquipesFiltrados();
      
      // Carregar coordenadores
      await _loadCoordenadores();
      
      // Carregar frotas filtradas
      await _loadFrotasFiltradas();
      
      print('📋 Após carregar: ${_executoresList.length} executores, ${_equipesList.length} equipes, ${_tiposAtividadeList.length} tipos de atividade');

      // Após carregar executores e equipes, tentar selecionar o executor/equipe da tarefa
      if (widget.task != null) {
        final task = widget.task!;
        if (task.equipeId != null && task.equipeId!.isNotEmpty) {
          try {
            _selectedEquipe = _equipesList.firstWhere(
              (e) => e.id == task.equipeId,
            );
            _usarEquipe = true;
          } catch (e) {
            _selectedEquipe = null;
          }
        } else if (task.executor.isNotEmpty) {
          try {
            final executorSelecionado = _executoresList.firstWhere(
              (e) => e.nome == task.executor || (e.nomeCompleto != null && e.nomeCompleto == task.executor),
            );
            _executor = executorSelecionado.nome; // Salvar apenas o nome
            _usarEquipe = false;
            // Se não há IDs de executores, adicionar o ID encontrado
            if (_selectedExecutorIds.isEmpty) {
              _selectedExecutorIds.add(executorSelecionado.id);
            }
          } catch (e) {
            // Executor não encontrado na lista filtrada, manter o texto original
            print('⚠️ Executor não encontrado: ${task.executor}');
          }
        }
        
        // AGORA que os executores foram carregados, preencher _executoresSelecionados
        // Se ainda não há IDs mas há executor (string), tentar encontrar novamente
        if (_selectedExecutorIds.isEmpty && task.executor.isNotEmpty && !_usarEquipe) {
          try {
            final executorEncontrado = _executoresList.firstWhere(
              (e) => e.nome == task.executor || (e.nomeCompleto != null && e.nomeCompleto == task.executor),
            );
            _selectedExecutorIds.add(executorEncontrado.id);
            print('✅ Executor encontrado pelo nome: ${executorEncontrado.nome} (ID: ${executorEncontrado.id})');
          } catch (e) {
            print('⚠️ Executor ainda não encontrado após carregar lista: ${task.executor}');
          }
        }
        
        // Preencher _executoresSelecionados com os executores encontrados
        if (_selectedExecutorIds.isNotEmpty) {
          final executoresEncontradosEdit = _executoresList.where((e) => _selectedExecutorIds.contains(e.id)).toList();
          _executoresSelecionados = executoresEncontradosEdit.map<Executor?>((e) => e as Executor?).toList();
          if (_executoresSelecionados.isEmpty) {
            _executoresSelecionados = <Executor?>[null]; // Pelo menos um dropdown vazio
          }
          print('✅ ${_executoresSelecionados.length} executores selecionados para os dropdowns');
        } else {
          _executoresSelecionados = <Executor?>[null]; // Pelo menos um dropdown vazio
        }
        
        // AGORA que as frotas foram carregadas, preencher _frotasSelecionadas
        // Se ainda não há IDs mas há frota (string), tentar encontrar
        if (_selectedFrotaIds.isEmpty && task.frota.isNotEmpty && task.frota != '-N/A-' && _frotasList.isNotEmpty) {
          try {
            // Tentar encontrar por nome completo (formato: "Nome - Placa")
            if (task.frota.contains(' - ')) {
              final parts = task.frota.split(' - ');
              if (parts.length >= 2) {
                final nome = parts[0].trim();
                final placa = parts[1].trim();
                final frotaEncontrada = _frotasList.firstWhere(
                  (f) => f.nome == nome && f.placa == placa,
                );
                _selectedFrotaIds.add(frotaEncontrada.id);
                print('✅ Frota encontrada pelo nome e placa: ${frotaEncontrada.nome} - ${frotaEncontrada.placa} (ID: ${frotaEncontrada.id})');
              }
            } else {
              // Tentar encontrar apenas pelo nome
              final frotaEncontrada = _frotasList.firstWhere(
                (f) => f.nome == task.frota || f.placa == task.frota,
              );
              _selectedFrotaIds.add(frotaEncontrada.id);
              print('✅ Frota encontrada pelo nome: ${frotaEncontrada.nome} (ID: ${frotaEncontrada.id})');
            }
          } catch (e) {
            print('⚠️ Frota ainda não encontrada após carregar lista: ${task.frota}');
          }
        }
        
        // Preencher _frotasSelecionadas com as frotas encontradas
        if (_selectedFrotaIds.isNotEmpty) {
          final frotasEncontradasEdit = _frotasList.where((f) => _selectedFrotaIds.contains(f.id)).toList();
          _frotasSelecionadas = frotasEncontradasEdit.map<Frota?>((f) => f as Frota?).toList();
          if (_frotasSelecionadas.isEmpty) {
            _frotasSelecionadas = <Frota?>[null]; // Pelo menos um dropdown vazio
          }
          print('✅ ${_frotasSelecionadas.length} frotas selecionadas para os dropdowns');
        } else {
          _frotasSelecionadas = <Frota?>[null]; // Pelo menos um dropdown vazio
        }
      }
    } catch (e) {
      print('Erro ao carregar dados: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTiposAtividade() async {
    try {
      List<TipoAtividade> tipos;
      
      // Se houver segmento selecionado, filtrar tipos de atividade por segmento
      if (_segmentoId != null && _segmentoId!.isNotEmpty) {
        // Buscar todos os tipos ativos e filtrar por segmento
        final todosTipos = await _tipoAtividadeService.getTiposAtividadeAtivos();
        tipos = todosTipos.where((tipo) {
          // Verificar se o tipo está associado ao segmento selecionado ou não tem segmentos específicos
          return tipo.segmentoIds.contains(_segmentoId) || tipo.segmentoIds.isEmpty;
        }).toList();
      } else {
        // Sem segmento, carregar todos os tipos ativos
        tipos = await _tipoAtividadeService.getTiposAtividadeAtivos();
      }

      setState(() {
        _tiposAtividadeList = tipos;
      });

      // Se não houver tipo selecionado e houver tipos disponíveis, selecionar o primeiro
      if (_tipo.isEmpty && tipos.isNotEmpty) {
        setState(() {
          _tipo = tipos.first.codigo;
        });
      }

      print('📋 Tipos de atividade carregados: ${tipos.length}');
    } catch (e) {
      print('❌ Erro ao carregar tipos de atividade: $e');
      setState(() {
        _tiposAtividadeList = [];
      });
    }
  }

  Future<void> _loadExecutoresEquipesFiltrados() async {
    setState(() {
      _isLoadingExecutoresEquipes = true;
    });

    try {
      final results = await Future.wait([
        _executorService.getExecutoresFiltrados(
          regionalId: _regionalId,
          divisaoId: _divisaoId,
          segmentoId: _segmentoId,
        ),
        _equipeService.getEquipesFiltradas(
          regionalId: _regionalId,
          divisaoId: _divisaoId,
          segmentoId: _segmentoId,
        ),
      ]);

      final executores = results[0] as List<Executor>;
      final equipes = results[1] as List<Equipe>;

      print('📋 Executores carregados: ${executores.length}');
      print('📋 Equipes carregadas: ${equipes.length}');
      print('📋 Filtros aplicados: Regional=$_regionalId, Divisão=$_divisaoId, Segmento=$_segmentoId');
      
      if (executores.isNotEmpty) {
        print('📋 Primeiro executor: ${executores.first.nome}');
      }
      if (equipes.isNotEmpty) {
        print('📋 Primeira equipe: ${equipes.first.nome}');
      }

      setState(() {
        _executoresList = executores;
        _equipesList = equipes;
        _isLoadingExecutoresEquipes = false;
      });
    } catch (e) {
      print('❌ Erro ao carregar executores e equipes: $e');
      setState(() {
        _isLoadingExecutoresEquipes = false;
      });
    }
  }

  Future<void> _loadCoordenadores() async {
    try {
      print('🔍 DEBUG Coordenadores: Iniciando carregamento...');
      
      List<Executor> coordenadores = [];
      
      // Se o usuário tem perfil configurado, filtrar coordenadores pelo perfil
      if (_usuarioAtual != null && !_usuarioAtual!.isRoot && _usuarioAtual!.temPerfilConfigurado()) {
        print('🔒 DEBUG Coordenadores: Filtrando pelo perfil do usuário...');
        print('   Regional IDs: ${_usuarioAtual!.regionalIds}');
        print('   Divisão IDs: ${_usuarioAtual!.divisaoIds}');
        print('   Segmento IDs: ${_usuarioAtual!.segmentoIds}');
        
        // Buscar coordenadores para cada segmento e combinar
        Set<Executor> coordenadoresUnicos = {};
        
        if (_usuarioAtual!.segmentoIds.isNotEmpty) {
          print('   Buscando coordenadores por segmento (${_usuarioAtual!.segmentoIds.length} segmentos)...');
          // Buscar por segmento (mais específico)
          for (final segmentoId in _usuarioAtual!.segmentoIds) {
            print('     Buscando coordenadores para segmento: $segmentoId');
            final coordenadoresSegmento = await _executorService.getCoordenadoresFiltrados(
              segmentoId: segmentoId,
            );
            print('     Encontrados ${coordenadoresSegmento.length} coordenadores para segmento $segmentoId');
            coordenadoresUnicos.addAll(coordenadoresSegmento);
          }
        } else if (_usuarioAtual!.divisaoIds.isNotEmpty) {
          print('   Buscando coordenadores por divisão (${_usuarioAtual!.divisaoIds.length} divisões)...');
          // Buscar por divisão
          for (final divisaoId in _usuarioAtual!.divisaoIds) {
            print('     Buscando coordenadores para divisão: $divisaoId');
            final coordenadoresDivisao = await _executorService.getCoordenadoresFiltrados(
              divisaoId: divisaoId,
            );
            print('     Encontrados ${coordenadoresDivisao.length} coordenadores para divisão $divisaoId');
            coordenadoresUnicos.addAll(coordenadoresDivisao);
          }
        } else if (_usuarioAtual!.regionalIds.isNotEmpty) {
          print('   Buscando coordenadores por regional (${_usuarioAtual!.regionalIds.length} regionais)...');
          // Buscar por regional
          for (final regionalId in _usuarioAtual!.regionalIds) {
            print('     Buscando coordenadores para regional: $regionalId');
            final coordenadoresRegional = await _executorService.getCoordenadoresFiltrados(
              regionalId: regionalId,
            );
            print('     Encontrados ${coordenadoresRegional.length} coordenadores para regional $regionalId');
            coordenadoresUnicos.addAll(coordenadoresRegional);
          }
        } else {
          print('   Sem filtros específicos, buscando todos os coordenadores...');
          // Buscar todos os coordenadores (sem filtro de perfil)
          final todosCoordenadores = await _executorService.getCoordenadores();
          print('   Total de coordenadores encontrados: ${todosCoordenadores.length}');
          coordenadoresUnicos.addAll(todosCoordenadores);
        }
        
        coordenadores = coordenadoresUnicos.toList();
        print('🔒 DEBUG Coordenadores: Total de coordenadores únicos após filtro: ${coordenadores.length}');
      } else {
        print('👑 DEBUG Coordenadores: Usuário root ou sem perfil, buscando todos os coordenadores...');
        // Usuário root ou sem perfil: buscar todos os coordenadores
        coordenadores = await _executorService.getCoordenadores();
        print('👑 DEBUG Coordenadores: Total de coordenadores encontrados: ${coordenadores.length}');
      }
      
      setState(() {
        _coordenadoresList = coordenadores;
      });
      print('👔 Coordenadores carregados: ${coordenadores.length}');
    } catch (e, stackTrace) {
      print('❌ Erro ao carregar coordenadores: $e');
      print('   Stack trace: $stackTrace');
      setState(() {
        _coordenadoresList = [];
      });
    }
  }

  // Filtrar regionais pelo perfil do usuário
  List<Regional> _filtrarRegionaisPorPerfil(List<Regional> todasRegionais) {
    if (_usuarioAtual == null || _usuarioAtual!.isRoot) {
      // Usuário root vê todas as regionais
      return todasRegionais;
    }

    // Filtrar apenas regionais do perfil
    final regionaisPermitidas = _usuarioAtual!.regionalIds;
    if (regionaisPermitidas.isEmpty) {
      return todasRegionais; // Se não tem filtro, mostrar todas
    }

    return todasRegionais.where((r) => regionaisPermitidas.contains(r.id)).toList();
  }

  // Filtrar divisões pelo perfil do usuário
  List<Divisao> _filtrarDivisoesPorPerfil(List<Divisao> todasDivisoes) {
    if (_usuarioAtual == null || _usuarioAtual!.isRoot) {
      // Usuário root vê todas as divisões
      return todasDivisoes;
    }

    // Filtrar apenas divisões do perfil
    final divisoesPermitidas = _usuarioAtual!.divisaoIds;
    if (divisoesPermitidas.isEmpty) {
      return todasDivisoes; // Se não tem filtro, mostrar todas
    }

    return todasDivisoes.where((d) => divisoesPermitidas.contains(d.id)).toList();
  }

  // Filtrar frotas pelo perfil do usuário
  List<Frota> _filtrarFrotasPorPerfil(List<Frota> todasFrotas) {
    if (_usuarioAtual == null || _usuarioAtual!.isRoot) {
      // Usuário root vê todas as frotas
      return todasFrotas.where((f) => f.ativo && !f.emManutencao).toList();
    }

    // Filtrar por regional, divisão e segmento do perfil
    final regionaisPermitidas = _usuarioAtual!.regionalIds;
    final divisoesPermitidas = _usuarioAtual!.divisaoIds;
    final segmentosPermitidos = _usuarioAtual!.segmentoIds;

    return todasFrotas.where((frota) {
      // Apenas frotas ativas e não em manutenção
      if (!frota.ativo || frota.emManutencao) {
        return false;
      }

      // Se não tem regional/divisão/segmento configurados, não filtrar por eles
      bool passaRegional = regionaisPermitidas.isEmpty || 
          (frota.regionalId != null && regionaisPermitidas.contains(frota.regionalId));
      
      bool passaDivisao = divisoesPermitidas.isEmpty || 
          (frota.divisaoId != null && divisoesPermitidas.contains(frota.divisaoId));
      
      bool passaSegmento = segmentosPermitidos.isEmpty || 
          (frota.segmentoId != null && segmentosPermitidos.contains(frota.segmentoId));

      return passaRegional && passaDivisao && passaSegmento;
    }).toList();
  }

  Future<void> _loadFrotasFiltradas() async {
    try {
      // Recarregar frotas e filtrar pelo perfil
      final todasFrotas = await _frotaService.getAllFrotas();
      final frotasFiltradas = _filtrarFrotasPorPerfil(todasFrotas);
      
      setState(() {
        _frotasList = frotasFiltradas;
      });

      // Se estiver editando, tentar encontrar a frota selecionada
      if (widget.task != null && _frota.isNotEmpty && _frota != '-N/A-') {
        try {
          // Tentar encontrar por nome ou placa
          Frota? frotaEncontrada;
          
          // Primeiro, tentar match exato
          try {
            frotaEncontrada = _frotasList.firstWhere(
              (f) => f.nome == _frota || f.placa == _frota,
            );
          } catch (e) {
            // Tentar match com formato "Nome - Placa"
            try {
              frotaEncontrada = _frotasList.firstWhere(
                (f) => '${f.nome} - ${f.placa}' == _frota,
              );
            } catch (e2) {
              // Tentar match parcial
              try {
                frotaEncontrada = _frotasList.firstWhere(
                  (f) => f.nome.contains(_frota) || _frota.contains(f.nome),
                );
              } catch (e3) {
                // Se não encontrou, usar a primeira se houver
                if (_frotasList.isNotEmpty) {
                  frotaEncontrada = _frotasList.first;
                }
              }
            }
          }
          
          _selectedFrota = frotaEncontrada;
          if (_selectedFrota != null) {
            _frota = '${_selectedFrota!.nome} - ${_selectedFrota!.placa}';
          }
        } catch (e) {
          print('⚠️ Frota não encontrada: $_frota');
          _selectedFrota = null;
        }
      }

      print('🚗 Frotas filtradas carregadas: ${frotasFiltradas.length} de ${todasFrotas.length}');
    } catch (e) {
      print('❌ Erro ao carregar frotas: $e');
      setState(() {
        _frotasList = [];
      });
    }
  }

  Future<void> _abrirChatTarefa() async {
    if (widget.task == null) return;
    
    try {
      // Buscar ou criar grupo de chat para a tarefa
      GrupoChat? grupoChat;
      
      // Primeiro, tentar obter grupo existente
      grupoChat = await _chatService.obterGrupoPorTarefaId(widget.task!.id);
      
      // Se não existir, criar um novo grupo
      if (grupoChat == null) {
        // Obter ou criar comunidade baseada na divisão e segmento da tarefa
        if (widget.task!.divisaoId != null && widget.task!.segmentoId != null) {
          final divisaoNome = widget.task!.divisao.isNotEmpty 
              ? widget.task!.divisao 
              : 'Divisão';
          final segmentoNome = widget.task!.segmento.isNotEmpty 
              ? widget.task!.segmento 
              : 'Segmento';
          
          final comunidade = await _chatService.criarOuObterComunidade(
            widget.task!.regionalId ?? '',
            widget.task!.regional,
            widget.task!.divisaoId!,
            divisaoNome,
            widget.task!.segmentoId!,
            segmentoNome,
          );
          
          if (comunidade.id != null) {
            grupoChat = await _chatService.criarOuObterGrupo(
              widget.task!.id,
              widget.task!.tarefa,
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

  @override
  Widget build(BuildContext context) {
    final isSubtask = widget.parentTaskId != null;
    final title = widget.task == null 
        ? (isSubtask ? 'Criar Subtarefa' : 'Criar Tarefa')
        : 'Editar Tarefa';
    final isMobile = Responsive.isMobile(context);
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        width: isMobile ? double.infinity : 700,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
          maxWidth: MediaQuery.of(context).size.width * 0.95,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header com gradiente
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1E3A5F),
                    Color(0xFF2C5282),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
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
                    child: const Icon(
                      Icons.task_alt,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  // Botão de chat (apenas para tarefas existentes)
                  if (widget.task != null)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.chat, color: Colors.white, size: 20),
                        tooltip: 'Abrir chat da tarefa',
                        onPressed: () => _abrirChatTarefa(),
                      ),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
            // Tabs modernas
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!, width: 1),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF1E3A5F),
                unselectedLabelColor: Colors.grey[600],
                indicatorColor: const Color(0xFF1E3A5F),
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.tab,
                isScrollable: isMobile, // Apenas scroll no mobile
                labelStyle: TextStyle(
                  fontSize: isMobile ? 12 : 14,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: TextStyle(
                  fontSize: isMobile ? 12 : 14,
                  fontWeight: FontWeight.w500,
                ),
                tabAlignment: isMobile ? TabAlignment.start : TabAlignment.fill, // Fill no desktop
                tabs: [
                  const Tab(
                    icon: Icon(Icons.info_outline, size: 20),
                    text: 'Básicas',
                  ),
                  const Tab(
                    icon: Icon(Icons.people_outline, size: 20),
                    text: 'Respons.',
                  ),
                  const Tab(
                    icon: Icon(Icons.car_rental, size: 20),
                    text: 'Frota',
                  ),
                  const Tab(
                    icon: Icon(Icons.calendar_today, size: 20),
                    text: 'Datas',
                  ),
                  const Tab(
                    icon: Icon(Icons.note_outlined, size: 20),
                    text: 'Obs.',
                  ),
                  const Tab(
                    icon: Icon(Icons.attach_file, size: 20),
                    text: 'Anexos',
                  ),
                  // Aba PEX/APR apenas para usuários root
                  if (_isUserRoot)
                    const Tab(
                      icon: Icon(Icons.description, size: 20),
                      text: 'PEX/APR',
                    ),
                  _buildSAPGroupTab(context),
                ],
              ),
            ),
            // Form com Tabs
            Flexible(
              child: Form(
                key: _formKey,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Aba 1: Informações Básicas
                    SingleChildScrollView(
                      controller: _getScrollController(0),
                      padding: const EdgeInsets.all(24),
                      child: _isLoading
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(40.0),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Card: Status, Regional, Divisão
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey[200]!),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.03),
                                        blurRadius: 10,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Responsive.isMobile(context)
                                      ? Column(
                                          children: [
                                            _buildStatusDropdown(),
                                            const SizedBox(height: 10),
                                            _buildRegionalDropdown(),
                                            const SizedBox(height: 10),
                                            _buildDivisaoDropdown(),
                                          ],
                                        )
                                      : Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(flex: 1, child: _buildStatusDropdown()),
                                            const SizedBox(width: 16),
                                            Expanded(flex: 1, child: _buildRegionalDropdown()),
                                            const SizedBox(width: 16),
                                            Expanded(flex: 1, child: _buildDivisaoDropdown()),
                                          ],
                                        ),
                                ),
                                const SizedBox(height: 16),
                                // Card: Segmento e Tipo
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey[200]!),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.03),
                                        blurRadius: 10,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                        _buildSegmentoDropdown(),
                                      const SizedBox(height: 10),
                                      _buildTipoAtividadeDropdown(),
                                      const SizedBox(height: 10),
                                      _buildPrecisaSISwitch(),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Card: Locais
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey[200]!),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.03),
                                        blurRadius: 10,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: _buildLocalDropdown(),
                                ),
                                const SizedBox(height: 16),
                                // Card: Tarefa
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey[200]!),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.03),
                                        blurRadius: 10,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: _buildTextField('Tarefa', _tarefa, (value) => _tarefa = value, maxLines: 3),
                                ),
                              ],
                            ),
                    ),
                    // Aba 2: Responsáveis
                    SingleChildScrollView(
                      controller: _getScrollController(1),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildExecutorEquipeDropdown(),
                          const SizedBox(height: 12),
                          _buildCoordenadorDropdown(),
                        ],
                      ),
                    ),
                    // Aba 3: Frota
                    SingleChildScrollView(
                      controller: _getScrollController(2),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildFrotasSection(),
                        ],
                      ),
                    ),
                    // Aba 4: Datas e Horas (Períodos de Execução)
                    SingleChildScrollView(
                      controller: _getScrollController(3),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: _buildPeriodosSection(),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildNumberField('Horas Previstas', _horasPrevistas, (value) => _horasPrevistas = value),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildNumberField('Horas Executadas', _horasExecutadas, (value) => _horasExecutadas = value),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Aba 5: Observações
                    SingleChildScrollView(
                      controller: _getScrollController(4),
                      padding: const EdgeInsets.all(24),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: _buildTextField('Observações', _observacoes ?? '', (value) => _observacoes = value, maxLines: 10),
                      ),
                    ),
                    // Aba 6: Anexos (apenas para tarefas existentes)
                    widget.task != null
                        ? SingleChildScrollView(
                            controller: _getScrollController(5),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                AnexosSection(
                                  taskId: widget.task!.id,
                                  isEditing: true,
                                ),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            controller: _getScrollController(5),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey[300]!),
                                  ),
                                  child: Column(
                                    children: [
                                      const Icon(
                                        Icons.info_outline,
                                        size: 48,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Salve a tarefa primeiro',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Após criar a tarefa, você poderá adicionar anexos (imagens, vídeos e documentos).',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                    // Aba 6 ou 7: PEX/APR/CRC (apenas para tarefas existentes E usuários root)
                    if (_isUserRoot)
                      widget.task != null
                          ? SingleChildScrollView(
                              controller: _getScrollController(6),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  PEXAPRCRCView(task: widget.task!),
                                ],
                              ),
                            )
                          : SingleChildScrollView(
                              controller: _getScrollController(6),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey[300]!),
                                    ),
                                    child: const Column(
                                      children: [
                                        Icon(
                                          Icons.description,
                                          size: 64,
                                          color: Colors.grey,
                                        ),
                                        SizedBox(height: 16),
                                        Text(
                                          'Documentos PEX, APR e CRC podem ser criados após salvar a tarefa',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(fontSize: 14, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                    // Aba 7: Grupo SAP
                    _buildSAPGroupContent(),
                  ],
                ),
              ),
            ),
            // Footer moderno
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!, width: 1),
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A5F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 2,
                      shadowColor: const Color(0xFF1E3A5F).withOpacity(0.3),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.task == null ? Icons.add_circle_outline : Icons.save_outlined,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.task == null ? 'Criar' : 'Salvar',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDropdown() {
    // Verificar se o valor selecionado está na lista (comparar por ID)
    // Se não estiver, definir como null para evitar erro de assertion
    Status? statusValue;
    if (_selectedStatus != null && _statusList.isNotEmpty) {
      try {
        final found = _statusList.firstWhere((s) => s.id == _selectedStatus!.id);
        statusValue = found;
      } catch (e) {
        statusValue = null;
      }
    }
    
    // Criar uma cópia da lista de itens para evitar problemas de referência
    final itemsList = List<Status>.from(_statusList);
    
    return DropdownSearch<Status>(
      popupProps: PopupProps.menu(
        showSearchBox: true,
        searchFieldProps: TextFieldProps(
          decoration: InputDecoration(
            hintText: 'Digite para buscar status...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
        menuProps: const MenuProps(
          elevation: 4,
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6, // 60% da altura da tela
          minHeight: 200,
        ),
      ),
      items: (String filter, LoadProps? loadProps) async {
        return List<Status>.from(itemsList);
      },
      selectedItem: statusValue,
      onChanged: (Status? value) {
        setState(() {
          _selectedStatus = value;
          if (value != null) {
            _status = value.codigo;
            _statusId = value.id;
          }
        });
      },
      itemAsString: (Status status) => status.status,
      compareFn: (Status item1, Status item2) {
        return item1.id == item2.id;
      },
      filterFn: (Status item, String filter) {
        if (filter.isEmpty || filter.trim().isEmpty) {
          return true;
        }
        final lowerFilter = filter.toLowerCase().trim();
        final displayText = item.status.toLowerCase();
        return displayText.contains(lowerFilter);
      },
      validator: (Status? value) {
        if (value == null) {
          return 'Selecione um status';
        }
        return null;
      },
      dropdownBuilder: (context, Status? selectedItem) {
        if (selectedItem == null) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              'Digite para buscar status...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // Bolinha colorida
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: selectedItem.color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.grey[300]!,
                    width: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Texto do status
              Expanded(
                child: Text(
                  selectedItem.status,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        );
      },
      decoratorProps: DropDownDecoratorProps(
        baseStyle: const TextStyle(),
        decoration: InputDecoration(
          labelText: 'Status *',
          labelStyle: TextStyle(
            color: Colors.grey[700],
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          hintText: 'Digite para buscar status...',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1E3A5F), width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          suffixIcon: Icon(
            Icons.arrow_drop_down,
            color: Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildRegionalDropdown() {
    // Verificar se o valor selecionado está na lista (comparar por ID)
    // Se não estiver, definir como null para evitar erro de assertion
    Regional? regionalValue;
    if (_selectedRegional != null && _regionaisList.isNotEmpty) {
      try {
        final found = _regionaisList.firstWhere((r) => r.id == _selectedRegional!.id);
        regionalValue = found;
      } catch (e) {
        regionalValue = null;
      }
    }
    
    return _buildSearchableDropdown<Regional>(
      label: 'Regional',
      value: regionalValue,
      items: _regionaisList,
      getDisplayText: (regional) => regional.regional,
      onChanged: (Regional? value) {
        setState(() {
          _selectedRegional = value;
          if (value != null) {
            _regional = value.regional;
            _regionalId = value.id;
          } else {
            _regionalId = null;
          }
          // Recarregar executores, equipes e frotas quando regional mudar
          _loadExecutoresEquipesFiltrados();
          _loadFrotasFiltradas();
        });
      },
      validator: (value) {
        if (value == null) {
          return 'Selecione uma regional';
        }
        return null;
      },
      hintText: 'Digite para buscar regional...',
      isRequired: true,
    );
  }

  Widget _buildDivisaoDropdown() {
    // Verificar se o valor selecionado está na lista (comparar por ID)
    // Se não estiver, definir como null para evitar erro de assertion
    Divisao? divisaoValue;
    if (_selectedDivisao != null && _divisoesList.isNotEmpty) {
      try {
        final found = _divisoesList.firstWhere((d) => d.id == _selectedDivisao!.id);
        divisaoValue = found;
      } catch (e) {
        divisaoValue = null;
      }
    }
    
    return _buildSearchableDropdown<Divisao>(
      label: 'Divisão',
      value: divisaoValue,
      items: _divisoesList,
      getDisplayText: (divisao) => divisao.divisao,
      onChanged: (Divisao? value) async {
        setState(() {
          _selectedDivisao = value;
          if (value != null) {
            _divisao = value.divisao;
            _divisaoId = value.id;
            // Limpar segmento selecionado quando divisão mudar
            _selectedSegmento = null;
            _segmentoId = null;
          } else {
            _divisaoId = null;
            _selectedSegmento = null;
            _segmentoId = null;
          }
        });
        // Recarregar segmentos filtrados pela divisão
        await _loadSegmentosPorDivisao();
        // Recarregar tipos de atividade, executores, equipes e frotas
        _loadTiposAtividade();
        _loadExecutoresEquipesFiltrados();
        _loadFrotasFiltradas();
      },
      validator: (value) {
        if (value == null) {
          return 'Selecione uma divisão';
        }
        return null;
      },
    );
  }

  Widget _buildLocalDropdown() {
    // Garantir que sempre há pelo menos um dropdown
    if (_locaisSelecionados.isEmpty) {
      _locaisSelecionados = <Local?>[null];
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Locais *',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            // Botão para adicionar mais dropdowns
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  print('🔵 DEBUG: Botão adicionar local pressionado');
                  print('🔵 DEBUG: _locaisSelecionados antes: ${_locaisSelecionados.length} itens');
                  print('🔵 DEBUG: _selectedLocalIds antes: ${_selectedLocalIds.length} itens');
                  print('🔵 DEBUG: Conteúdo antes: $_locaisSelecionados');
                  setState(() {
                    // Adicionar um novo dropdown vazio
                    print('🔵 DEBUG: Adicionando novo dropdown vazio');
                    _locaisSelecionados.add(null as Local?);
                    print('🔵 DEBUG: _locaisSelecionados depois: ${_locaisSelecionados.length} itens');
                    print('🔵 DEBUG: Conteúdo depois: $_locaisSelecionados');
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(Icons.add_circle, size: 24, color: Colors.blue),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Lista de dropdowns lado a lado
        Builder(
          builder: (context) {
            print('🔵 DEBUG: Wrap builder - _locaisSelecionados.length = ${_locaisSelecionados.length}');
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_locaisSelecionados.length, (index) {
                print('🔵 DEBUG: Gerando dropdown para índice $index');
                return _buildSingleLocalDropdown(index);
              }),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSingleLocalDropdown(int index) {
    print('🔵 DEBUG: _buildSingleLocalDropdown chamado para índice $index');
    print('🔵 DEBUG: _locaisSelecionados.length = ${_locaisSelecionados.length}');
    
    // Verificar se o índice é válido
    if (index >= _locaisSelecionados.length) {
      print('⚠️ DEBUG: Índice $index inválido! Retornando SizedBox.shrink()');
      return const SizedBox.shrink();
    }
    
    final localSelecionado = _locaisSelecionados[index];
    print('🔵 DEBUG: localSelecionado[$index] = ${localSelecionado?.local ?? "null"}');
    
    // Filtrar locais disponíveis (todos os locais menos os já selecionados em outros dropdowns)
    // IMPORTANTE: Sempre incluir o local selecionado neste dropdown específico
    final localSelecionadoId = localSelecionado?.id;
    
    // Criar lista de IDs já selecionados em OUTROS dropdowns (não este)
    final outrosLocalIds = <String>{};
    for (int i = 0; i < _locaisSelecionados.length; i++) {
      if (i != index && _locaisSelecionados[i] != null) {
        outrosLocalIds.add(_locaisSelecionados[i]!.id);
      }
    }
    
    final locaisDisponiveis = _locaisList.where((local) {
      // Sempre incluir o local selecionado neste dropdown específico
      if (localSelecionadoId != null && local.id == localSelecionadoId) {
        return true;
      }
      // Excluir apenas locais selecionados em OUTROS dropdowns
      return !outrosLocalIds.contains(local.id);
    }).toList();
    
    // Verificar se o valor selecionado está na lista de disponíveis
    // Se não estiver, usar null para evitar erro de assertion
    Local? valorValido;
    if (localSelecionado != null && localSelecionadoId != null) {
      try {
        valorValido = locaisDisponiveis.firstWhere((l) => l.id == localSelecionadoId);
        print('✅ DEBUG: Local encontrado na lista de disponíveis: ${valorValido.local}');
      } catch (e) {
        print('⚠️ DEBUG: Local não encontrado na lista de disponíveis: ${localSelecionado.local}');
        // Se não encontrou, verificar se o local ainda existe na lista completa
        try {
          _locaisList.firstWhere((l) => l.id == localSelecionadoId);
          print('✅ DEBUG: Local existe na lista completa, mas não está disponível');
          // Se existe na lista completa mas não está disponível, usar null
          valorValido = null;
          // Limpar a seleção inválida de forma assíncrona para evitar problemas de estado
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _locaisSelecionados[index] = null;
                _selectedLocalIds.remove(localSelecionadoId);
              });
            }
          });
        } catch (e2) {
          print('❌ DEBUG: Local não existe mais na lista completa');
          // Local não existe mais, limpar seleção
          valorValido = null;
          // Limpar de forma assíncrona
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _locaisSelecionados[index] = null;
                _selectedLocalIds.remove(localSelecionadoId);
              });
            }
          });
        }
      }
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: Responsive.isMobile(context) ? double.infinity : 450,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildSearchableDropdown<Local>(
                label: 'Local ${index + 1}',
                value: valorValido,
                items: locaisDisponiveis,
                getDisplayText: (local) => local.descricao != null && local.descricao!.isNotEmpty
                    ? '${local.local} - ${local.descricao}'
                    : local.local,
                onChanged: (Local? value) {
                  print('🔵 DEBUG: onChanged chamado para índice $index');
                  print('🔵 DEBUG: Valor selecionado: ${value?.local ?? "null"}');
                  print('🔵 DEBUG: _locaisSelecionados.length antes: ${_locaisSelecionados.length}');
                  
                  if (!mounted) {
                    print('⚠️ DEBUG: Widget não está montado, retornando');
                    return;
                  }
                  
                  setState(() {
                    // Remover o local anterior da lista de selecionados se existir
                    final localAnterior = _locaisSelecionados[index];
                    print('🔵 DEBUG: Local anterior: ${localAnterior?.local ?? "null"}');
                    
                    if (localAnterior != null) {
                      print('🔵 DEBUG: Removendo ${localAnterior.id} de _selectedLocalIds');
                      _selectedLocalIds.remove(localAnterior.id);
                    }
                    
                    // Adicionar o novo local se não for null
                    if (value != null) {
                      print('🔵 DEBUG: Adicionando ${value.id} a _selectedLocalIds');
                      _selectedLocalIds.add(value.id);
                      
                      // Atualizar a lista garantindo o tipo correto
                      if (index < _locaisSelecionados.length) {
                        print('🔵 DEBUG: Atualizando _locaisSelecionados[$index] = ${value.local}');
                        _locaisSelecionados[index] = value;
                      } else {
                        print('⚠️ DEBUG: Índice $index fora dos limites! Adicionando ao final');
                        _locaisSelecionados.add(value);
                      }
                    } else {
                      print('🔵 DEBUG: Valor é null, limpando seleção');
                      // Atualizar para null garantindo o tipo correto
                      if (index < _locaisSelecionados.length) {
                        _locaisSelecionados[index] = null as Local?;
                      } else {
                        print('⚠️ DEBUG: Índice $index fora dos limites ao limpar!');
                        _locaisSelecionados.add(null as Local?);
                      }
                    }
                    
                    print('🔵 DEBUG: _locaisSelecionados.length depois: ${_locaisSelecionados.length}');
                    print('🔵 DEBUG: _selectedLocalIds.length depois: ${_selectedLocalIds.length}');
                    
                    // Atualizar exibição
                    if (_selectedLocalIds.isNotEmpty) {
                      final selectedLocais = _locaisList.where((l) => _selectedLocalIds.contains(l.id)).toList();
                      _local = selectedLocais.map((l) => l.local).join(', ');
                      _localId = _selectedLocalIds.first;
                    } else {
                      _local = '';
                      _localId = null;
                    }
                  });
                },
                hintText: 'Digite para buscar local...',
                compareFn: (Local item1, Local item2) {
                  return item1.id == item2.id;
                },
              ),
            ),
            // Botão para remover este dropdown (se houver mais de um)
            if (_locaisSelecionados.length > 1)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      if (!mounted) return;
                      setState(() {
                        // Remover o local da lista de selecionados se existir
                        final localParaRemover = _locaisSelecionados[index];
                        if (localParaRemover != null) {
                          _selectedLocalIds.remove(localParaRemover.id);
                        }
                        
                        // Remover o dropdown
                        _locaisSelecionados.removeAt(index);
                        
                        // Garantir que sempre há pelo menos um dropdown
                        if (_locaisSelecionados.isEmpty) {
                          _locaisSelecionados = <Local?>[null];
                        }
                        
                        // Atualizar exibição
                        if (_selectedLocalIds.isNotEmpty) {
                          final selectedLocais = _locaisList.where((l) => _selectedLocalIds.contains(l.id)).toList();
                          _local = selectedLocais.map((l) => l.local).join(', ');
                          _localId = _selectedLocalIds.first;
                        } else {
                          _local = '';
                          _localId = null;
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: const Icon(Icons.remove_circle, color: Colors.red, size: 24),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
    );
  }

  Future<void> _loadSegmentosPorDivisao() async {
    if (_selectedDivisao == null || _selectedDivisao!.id.isEmpty) {
      setState(() {
        _segmentosList = [];
        _selectedSegmento = null;
        _segmentoId = null;
      });
      return;
    }

    try {
      final segmentos = await _segmentoService.getSegmentosPorDivisao(_selectedDivisao!.id);
      
      // Filtrar segmentos pelo perfil do usuário (se não for root e tiver segmentos configurados)
      List<Segmento> segmentosFiltrados = segmentos;
      if (_usuarioAtual != null && !_usuarioAtual!.isRoot && _segmentoIdsPerfil.isNotEmpty) {
        segmentosFiltrados = segmentos.where((s) => _segmentoIdsPerfil.contains(s.id)).toList();
        print('🔒 Segmentos filtrados pelo perfil: ${segmentosFiltrados.length} de ${segmentos.length}');
      }
      
      setState(() {
        _segmentosList = segmentosFiltrados;
        
        // Se houver um segmentoId da tarefa e ele estiver na lista, selecioná-lo
        if (widget.task != null && widget.task!.segmentoId != null && widget.task!.segmentoId!.isNotEmpty) {
          try {
            final segmentoDaTarefa = segmentosFiltrados.firstWhere((s) => s.id == widget.task!.segmentoId);
            _selectedSegmento = segmentoDaTarefa;
            _segmentoId = segmentoDaTarefa.id;
            print('✅ Segmento da tarefa selecionado: ${segmentoDaTarefa.segmento}');
          } catch (e) {
            print('⚠️ Segmento da tarefa (${widget.task!.segmentoId}) não encontrado na lista');
            // Se o segmento selecionado anteriormente não estiver mais na lista, limpar seleção
            if (_selectedSegmento != null) {
              final aindaExiste = segmentosFiltrados.any((s) => s.id == _selectedSegmento!.id);
              if (!aindaExiste) {
                _selectedSegmento = null;
                _segmentoId = null;
              }
            }
          }
        } else if (widget.task == null && segmentosFiltrados.length == 1) {
          // Se for criar nova tarefa e houver apenas um segmento no perfil, pré-selecionar
          _selectedSegmento = segmentosFiltrados.first;
          _segmentoId = _selectedSegmento!.id;
          print('✅ Segmento único do perfil pré-selecionado: ${_selectedSegmento!.segmento}');
        } else {
          // Se o segmento selecionado anteriormente não estiver mais na lista, limpar seleção
          if (_selectedSegmento != null) {
            final aindaExiste = segmentosFiltrados.any((s) => s.id == _selectedSegmento!.id);
            if (!aindaExiste) {
              _selectedSegmento = null;
              _segmentoId = null;
            }
          }
        }
      });
    } catch (e) {
      print('Erro ao carregar segmentos por divisão: $e');
      setState(() {
        _segmentosList = [];
        _selectedSegmento = null;
        _segmentoId = null;
      });
    }
  }

  Widget _buildSegmentoDropdown() {
    // Verificar se o valor selecionado está na lista (comparar por ID)
    // Se não estiver, definir como null para evitar erro de assertion
    Segmento? segmentoValue;
    if (_selectedSegmento != null && _segmentosList.isNotEmpty) {
      try {
        final found = _segmentosList.firstWhere((s) => s.id == _selectedSegmento!.id);
        segmentoValue = found;
      } catch (e) {
        segmentoValue = null;
      }
    }
    
    return _buildSearchableDropdown<Segmento>(
      label: 'Segmento',
      value: segmentoValue,
      items: _segmentosList,
      getDisplayText: (segmento) => segmento.segmento,
      onChanged: (Segmento? value) {
        setState(() {
          _selectedSegmento = value;
          if (value != null) {
            _segmentoId = value.id;
          } else {
            _segmentoId = null;
          }
          // Recarregar tipos de atividade, executores, equipes e frotas quando segmento mudar
          _loadTiposAtividade();
          _loadExecutoresEquipesFiltrados();
          _loadFrotasFiltradas();
        });
      },
      validator: (value) {
        if (value == null) {
          return 'Selecione um segmento';
        }
        return null;
      },
      hintText: 'Digite para buscar segmento...',
      isRequired: true,
    );
  }

  Widget _buildCoordenadorDropdown() {
    // Encontrar o coordenador selecionado na lista
    Executor? coordenadorSelecionado;
    if (_coordenador.isNotEmpty && _coordenadoresList.isNotEmpty) {
      try {
        coordenadorSelecionado = _coordenadoresList.firstWhere(
          (c) => c.nomeCompleto == _coordenador || c.nome == _coordenador,
        );
      } catch (e) {
        coordenadorSelecionado = null;
      }
    }

    return _buildSearchableDropdown<Executor>(
      label: 'Coordenador',
      value: coordenadorSelecionado,
      items: _coordenadoresList,
      getDisplayText: (coordenador) => coordenador.nomeCompleto ?? coordenador.nome,
      onChanged: (Executor? value) {
        setState(() {
          if (value != null) {
            _coordenador = value.nome; // Salvar apenas o nome, não o nome completo
          } else {
            _coordenador = '';
          }
        });
      },
      hintText: 'Digite para buscar coordenador...',
    );
  }

  Widget _buildFrotasSection() {
    // Garantir que sempre há pelo menos um dropdown
    if (_frotasSelecionadas.isEmpty) {
      _frotasSelecionadas = <Frota?>[null];
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Frotas',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        // Lista de dropdowns lado a lado
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // Dropdowns de frotas
            ...List.generate(_frotasSelecionadas.length, (index) {
              return _buildSingleFrotaDropdown(index);
            }),
            // Botão para adicionar mais dropdowns (sempre visível após os dropdowns)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    // Adicionar um novo dropdown vazio
                    _frotasSelecionadas.add(null as Frota?);
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(Icons.add_circle, size: 24, color: Colors.blue),
                ),
              ),
            ),
          ],
        ),
        if (_frotasList.isEmpty && (_regionalId != null || _divisaoId != null || _segmentoId != null))
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Nenhuma frota encontrada. Tente ajustar os filtros (Regional/Divisão/Segmento).',
              style: TextStyle(fontSize: 12, color: Colors.orange[700]),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
      ],
    );
  }

  Widget _buildSingleFrotaDropdown(int index) {
    // Verificar se o índice é válido
    if (index >= _frotasSelecionadas.length) {
      return const SizedBox.shrink();
    }
    
    final frotaSelecionada = _frotasSelecionadas[index];
    
    // Filtrar frotas disponíveis (todas as frotas menos as já selecionadas em outros dropdowns)
    // IMPORTANTE: Sempre incluir a frota selecionada neste dropdown específico
    final frotaSelecionadaId = frotaSelecionada?.id;
    
    // Criar lista de IDs já selecionados em OUTROS dropdowns (não este)
    final outrasFrotaIds = <String>{};
    for (int i = 0; i < _frotasSelecionadas.length; i++) {
      if (i != index && _frotasSelecionadas[i] != null) {
        outrasFrotaIds.add(_frotasSelecionadas[i]!.id);
      }
    }
    
    final frotasDisponiveis = _frotasList.where((frota) {
      // Sempre incluir a frota selecionada neste dropdown específico
      if (frotaSelecionadaId != null && frota.id == frotaSelecionadaId) {
        return true;
      }
      // Excluir apenas frotas selecionadas em OUTROS dropdowns
      return !outrasFrotaIds.contains(frota.id);
    }).toList();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: Responsive.isMobile(context) ? double.infinity : 450,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildSearchableDropdown<Frota>(
                label: 'Frota ${index + 1}',
                value: frotaSelecionada,
                items: frotasDisponiveis,
                getDisplayText: (frota) => '${frota.nome} - ${frota.placa}',
                onChanged: (Frota? value) {
                  setState(() {
                    final frotaAnterior = _frotasSelecionadas[index];
                    if (frotaAnterior != null) {
                      _selectedFrotaIds.remove(frotaAnterior.id);
                    }
                    
                    _frotasSelecionadas[index] = value;
                    if (value != null) {
                      _selectedFrotaIds.add(value.id);
                      _frota = _frotasList
                          .where((f) => _selectedFrotaIds.contains(f.id))
                          .map((f) => '${f.nome} - ${f.placa}')
                          .join(', ');
                    } else {
                      // Se não há mais frotas selecionadas, limpar _frota
                      if (_selectedFrotaIds.isEmpty) {
                        _frota = '-N/A-';
                      } else {
                        _frota = _frotasList
                            .where((f) => _selectedFrotaIds.contains(f.id))
                            .map((f) => '${f.nome} - ${f.placa}')
                            .join(', ');
                      }
                    }
                  });
                },
                hintText: 'Digite para buscar frota...',
                compareFn: (Frota item1, Frota item2) {
                  return item1.id == item2.id;
                },
              ),
            ),
            // Botão para remover este dropdown (apenas se houver mais de um)
            if (_frotasSelecionadas.length > 1)
              IconButton(
                icon: const Icon(Icons.remove_circle, color: Colors.red),
                onPressed: () {
                  setState(() {
                    final frotaRemovida = _frotasSelecionadas[index];
                    if (frotaRemovida != null) {
                      _selectedFrotaIds.remove(frotaRemovida.id);
                    }
                    _frotasSelecionadas.removeAt(index);
                    // Atualizar _frota
                    if (_selectedFrotaIds.isEmpty) {
                      _frota = '-N/A-';
                    } else {
                      _frota = _frotasList
                          .where((f) => _selectedFrotaIds.contains(f.id))
                          .map((f) => '${f.nome} - ${f.placa}')
                          .join(', ');
                    }
                  });
                },
                tooltip: 'Remover frota',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrotaDropdown() { // Deprecated - manter para compatibilidade
    // Encontrar a frota selecionada na lista
    Frota? frotaSelecionada = _selectedFrota;
    
    // Se não há frota selecionada mas há texto em _frota, tentar encontrar
    if (frotaSelecionada == null && _frota.isNotEmpty && _frota != '-N/A-' && _frotasList.isNotEmpty) {
      try {
        frotaSelecionada = _frotasList.firstWhere(
          (f) => f.nome == _frota || 
                 f.placa == _frota ||
                 '${f.nome} - ${f.placa}' == _frota ||
                 f.nome.contains(_frota) ||
                 _frota.contains(f.nome),
        );
        _selectedFrota = frotaSelecionada;
      } catch (e) {
        frotaSelecionada = null;
      }
    }

    return _buildSearchableDropdown<Frota>(
      label: 'Frota',
      value: frotaSelecionada,
      items: _frotasList,
      getDisplayText: (frota) {
        final tipoVeiculo = frota.tipoVeiculo.replaceAll('_', ' ');
        final emManutencao = frota.emManutencao ? ' (Em Manutenção)' : '';
        return '${frota.nome} - ${frota.placa} - $tipoVeiculo$emManutencao';
      },
      onChanged: (Frota? value) {
        setState(() {
          _selectedFrota = value;
          if (value != null) {
            _frota = '${value.nome} - ${value.placa}';
          } else {
            _frota = '-N/A-';
          }
        });
      },
      hintText: 'Digite para buscar frota...',
    );
  }

  Widget _buildTipoAtividadeDropdown() {
    TipoAtividade? tipoSelecionado;
    
    // Tentar encontrar o tipo selecionado na lista
    // Se não encontrar ou a lista estiver vazia, usar null
    if (_tipo.isNotEmpty && _tiposAtividadeList.isNotEmpty) {
      try {
        final found = _tiposAtividadeList.firstWhere((t) => t.codigo == _tipo);
        tipoSelecionado = found;
      } catch (e) {
        tipoSelecionado = null;
      }
    } else {
      tipoSelecionado = null;
    }

    return _buildSearchableDropdown<TipoAtividade>(
      label: 'Tipo',
      value: tipoSelecionado,
      items: _tiposAtividadeList,
      getDisplayText: (tipo) => '${tipo.codigo} - ${tipo.descricao}',
      onChanged: (TipoAtividade? value) {
        setState(() {
          if (value != null) {
            _tipo = value.codigo;
          }
        });
      },
      validator: (value) {
        if (value == null) {
          return 'Selecione um tipo de atividade';
        }
        return null;
      },
      hintText: 'Digite para buscar tipo...',
      isRequired: true,
    );
  }

  Widget _buildPrecisaSISwitch() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          'Precisa de SI',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 12),
        Switch(
          value: _precisaSi,
          onChanged: (val) {
            setState(() {
              _precisaSi = val;
            });
          },
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, String value, List<String> options, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.grey[700],
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1E3A5F), width: 2),
        ),
      ),
      items: options.map((option) => DropdownMenuItem(value: option, child: Text(option))).toList(),
      onChanged: onChanged,
      style: const TextStyle(
        fontSize: 14,
        color: Colors.black87,
      ),
    );
  }

  // Widget genérico de dropdown com busca usando dropdown_search
  Widget _buildSearchableDropdown<T extends Object>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) getDisplayText,
    required void Function(T?) onChanged,
    String? Function(T?)? validator,
    String? hintText,
    bool isRequired = false,
    bool Function(T, T)? compareFn,
  }) {
    // Criar uma cópia da lista de itens para evitar problemas de referência
    final itemsList = List<T>.from(items);
    
    return DropdownSearch<T>(
      popupProps: PopupProps.menu(
        showSearchBox: true,
        searchFieldProps: TextFieldProps(
          decoration: InputDecoration(
            hintText: hintText ?? 'Digite para buscar...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
        menuProps: const MenuProps(
          elevation: 4,
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6, // 60% da altura da tela
          minHeight: 200,
        ),
      ),
      items: (String filter, LoadProps? loadProps) async {
        // Sempre retornar todos os itens - o filterFn vai fazer o filtro
        return List<T>.from(itemsList);
      },
      selectedItem: value,
      onChanged: onChanged,
      itemAsString: getDisplayText,
      compareFn: compareFn ?? (T item1, T item2) {
        // Comparação padrão usando o texto de exibição
        return getDisplayText(item1) == getDisplayText(item2);
      },
      filterFn: (T item, String filter) {
        // Função de filtro que é chamada para cada item
        if (filter.isEmpty || filter.trim().isEmpty) {
          return true; // Mostrar todos quando não há filtro
        }
        final lowerFilter = filter.toLowerCase().trim();
        final displayText = getDisplayText(item).toLowerCase();
        return displayText.contains(lowerFilter);
      },
      validator: validator,
      decoratorProps: DropDownDecoratorProps(
        baseStyle: const TextStyle(),
        decoration: InputDecoration(
          labelText: isRequired ? '$label *' : label,
          labelStyle: TextStyle(
            color: Colors.grey[700],
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          hintText: hintText ?? 'Digite para buscar...',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1E3A5F), width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          suffixIcon: Icon(
            Icons.arrow_drop_down,
            color: Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, String? value, ValueChanged<String> onChanged, {int maxLines = 1}) {
    return TextFormField(
      initialValue: value ?? '',
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.grey[700],
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1E3A5F), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
      maxLines: maxLines,
      onChanged: onChanged,
      style: const TextStyle(
        fontSize: 14,
        color: Colors.black87,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          if (label == 'Tarefa') {
            return 'Campo obrigatório';
          }
        }
        return null;
      },
    );
  }

  Widget _buildDateRangeField(String label, DateTime startDate, DateTime endDate, void Function(DateTime, DateTime) onChanged) {
    return InkWell(
      onTap: () async {
        final dateRange = await showDateRangePicker(
          context: context,
          initialDateRange: DateTimeRange(start: startDate, end: endDate),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          helpText: 'Selecione o período',
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: Colors.blue,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: Colors.black,
                ),
              ),
              child: child!,
            );
          },
        );
        if (dateRange != null) {
          onChanged(dateRange.start, dateRange.end);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.grey[700],
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1E3A5F), width: 2),
          ),
          suffixIcon: const Icon(Icons.date_range),
        ),
        child: Text(
          '${startDate.day}/${startDate.month}/${startDate.year} - ${endDate.day}/${endDate.month}/${endDate.year}',
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildDateField(String label, DateTime value, ValueChanged<DateTime> onChanged) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (date != null) onChanged(date);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.grey[700],
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1E3A5F), width: 2),
          ),
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(
          '${value.day}/${value.month}/${value.year}',
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildNumberField(String label, double? value, ValueChanged<double?> onChanged) {
    return TextFormField(
      initialValue: value?.toString() ?? '',
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.grey[700],
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1E3A5F), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
      keyboardType: TextInputType.number,
      style: const TextStyle(
        fontSize: 14,
        color: Colors.black87,
      ),
      onChanged: (value) {
        if (value.isEmpty) {
          onChanged(null);
        } else {
          onChanged(double.tryParse(value));
        }
      },
    );
  }

  void _save() {
    // Validar se pelo menos um local foi selecionado
    if (_selectedLocalIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione pelo menos um local'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (_formKey.currentState!.validate()) {
      // Criar segmento inicial apenas para novas tarefas
      // Cada tarefa precisa ter pelo menos um segmento representando o período de execução
      List<GanttSegment> ganttSegments;
      
      final isSubtask = widget.parentTaskId != null;
      
      // Usar os segmentos editados no formulário
      ganttSegments = _ganttSegments;
      
      // Garantir que sempre há pelo menos um segmento
      if (ganttSegments.isEmpty) {
        String segmentType = _mapTaskTypeToSegmentType(_tipo);
        ganttSegments = [
          GanttSegment(
            dataInicio: _dataInicio,
            dataFim: _dataFim,
            label: _tarefa,
            tipo: segmentType,
            tipoPeriodo: 'EXECUCAO',
          ),
        ];
      }
      
      // Atualizar dataInicio e dataFim da tarefa baseado nos segmentos
      if (ganttSegments.isNotEmpty) {
        _dataInicio = ganttSegments.map((s) => s.dataInicio).reduce((a, b) => a.isBefore(b) ? a : b);
        _dataFim = ganttSegments.map((s) => s.dataFim).reduce((a, b) => a.isAfter(b) ? a : b);
      }
      
      print('💾 TaskFormDialog: Salvando tarefa com ${ganttSegments.length} segmentos');
      for (var seg in ganttSegments) {
        print('   - ${seg.dataInicio.toString().substring(0, 10)} até ${seg.dataFim.toString().substring(0, 10)} (${seg.tipo}, ${seg.tipoPeriodo})');
      }
      
      print('💾 TaskFormDialog: Salvando ${_executorPeriods.length} períodos por executor');
      for (var ep in _executorPeriods) {
        print('   - Executor: ${ep.executorNome} (${ep.periods.length} períodos)');
      }
      print('💾 TaskFormDialog: Salvando ${_frotaPeriods.length} períodos por frota');
      for (var fp in _frotaPeriods) {
        print('   - Frota: ${fp.frotaNome} (${fp.periods.length} períodos)');
      }

      final task = Task(
        id: widget.task?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        statusId: _statusId,
        regionalId: _regionalId,
        divisaoId: _divisaoId,
        segmentoId: _segmentoId,
        localIds: _selectedLocalIds.toList(),
        executorIds: _tipoExecutorEquipe == 'executor' ? _selectedExecutorIds.toList() : [],
        frotaIds: _selectedFrotaIds.toList(),
        equipeIds: _tipoExecutorEquipe == 'equipe' ? _selectedEquipeIds.toList() : [],
        localId: _selectedLocalIds.isNotEmpty ? _selectedLocalIds.first : null, // Compatibilidade
        equipeId: _selectedEquipeIds.isNotEmpty ? _selectedEquipeIds.first : null, // Compatibilidade
        status: _status,
        statusNome: _selectedStatus?.status ?? '',
        regional: _regional,
        divisao: _divisao,
        locais: _locaisList.where((l) => _selectedLocalIds.contains(l.id)).map((l) => l.local).toList(),
        tipo: _tipo,
        ordem: _ordem,
        tarefa: _tarefa,
        executores: _tipoExecutorEquipe == 'executor' 
            ? _executoresList.where((e) => _selectedExecutorIds.contains(e.id)).map((e) => e.nome).toList() // Salvar apenas o nome
            : [],
        equipes: _tipoExecutorEquipe == 'equipe'
            ? _equipesList.where((e) => _selectedEquipeIds.contains(e.id)).map((e) => e.nome).toList()
            : [],
        executor: _tipoExecutorEquipe == 'executor' && _selectedExecutorIds.isNotEmpty
            ? _executoresList.firstWhere((e) => _selectedExecutorIds.contains(e.id), orElse: () => _executoresList.first).nome // Salvar apenas o nome
            : '', // Compatibilidade
        frota: _selectedFrotaIds.isNotEmpty 
            ? _frotasList.where((f) => _selectedFrotaIds.contains(f.id)).map((f) => '${f.nome} - ${f.placa}').join(', ')
            : (_frota.isNotEmpty && _frota != '-N/A-' ? _frota : ''),
        coordenador: _coordenador,
        si: _si,
        dataInicio: _dataInicio,
        dataFim: _dataFim,
        ganttSegments: ganttSegments,
        executorPeriods: _executorPeriods,
        frotaPeriods: _frotaPeriods,
        observacoes: _observacoes,
        horasPrevistas: _horasPrevistas,
        horasExecutadas: _horasExecutadas,
        prioridade: null,
        parentId: widget.parentTaskId ?? widget.task?.parentId,
        precisaSi: _precisaSi,
      );

      // Salvar posição do scroll antes de fechar o dialog
      _saveScrollPositions();
      
      Navigator.of(context).pop(task);
    }
  }
  
  Widget _buildExecutorEquipeDropdown() {
    // Inicializar tipoSelecionado se ainda não foi definido
    if (_tipoExecutorEquipe == null) {
      if (_selectedEquipe != null || _usarEquipe) {
        _tipoExecutorEquipe = 'equipe';
      } else if (_executor.isNotEmpty) {
        _tipoExecutorEquipe = 'executor';
      }
    }

    Executor? executorSelecionado;
    
    // Tentar encontrar o executor na lista se já houver um selecionado
    // Sempre verificar se está na lista antes de usar para evitar erro de assertion
    if (_tipoExecutorEquipe == 'executor' && _executoresList.isNotEmpty) {
      // Primeiro tentar por ID
      if (_selectedExecutorIds.isNotEmpty) {
        try {
          final found = _executoresList.firstWhere(
            (e) => _selectedExecutorIds.contains(e.id),
          );
          executorSelecionado = found;
        } catch (e) {
          executorSelecionado = null;
        }
      }
      
      // Se não encontrou por ID, tentar por nome
      if (executorSelecionado == null && _executor.isNotEmpty) {
        try {
          final found = _executoresList.firstWhere(
            (e) => e.nome == _executor || (e.nomeCompleto != null && e.nomeCompleto == _executor),
          );
          executorSelecionado = found;
        } catch (e) {
          executorSelecionado = null;
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Executor / Equipe',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        if (_isLoadingExecutoresEquipes)
          const CircularProgressIndicator()
        else
          DropdownButtonFormField<String>(
            value: _tipoExecutorEquipe,
            decoration: InputDecoration(
              labelText: 'Tipo',
              labelStyle: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              filled: true,
              fillColor: Colors.white,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF1E3A5F), width: 2),
              ),
            ),
            items: const [
              DropdownMenuItem(value: 'executor', child: Text('Executor Individual')),
              DropdownMenuItem(value: 'equipe', child: Text('Equipe')),
            ],
            onChanged: (value) {
              setState(() {
                _tipoExecutorEquipe = value;
                if (value == 'executor') {
                  _usarEquipe = false;
                  _selectedEquipe = null;
                  _equipeId = null;
                  _executor = '';
                } else if (value == 'equipe') {
                  _usarEquipe = true;
                  _executor = '';
                }
              });
            },
          ),
        const SizedBox(height: 12),
        if (_tipoExecutorEquipe == 'executor')
          _buildExecutoresDropdown()
        else if (_tipoExecutorEquipe == 'equipe')
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isLoadingExecutoresEquipes)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                DropdownButtonFormField<Equipe>(
                  value: _equipesList.isEmpty || 
                      (_selectedEquipe != null && !_equipesList.any((e) => e.id == _selectedEquipe!.id))
                      ? null
                      : _selectedEquipe,
                  decoration: InputDecoration(
                    labelText: 'Equipe *',
                    border: const OutlineInputBorder(),
                    errorText: _equipesList.isEmpty 
                        ? null 
                        : (_tipoExecutorEquipe == 'equipe' && _selectedEquipe == null && _equipesList.isNotEmpty
                            ? 'Selecione uma equipe'
                            : null),
                  ),
                  items: _equipesList.isEmpty
                      ? [
                          const DropdownMenuItem<Equipe>(
                            value: null,
                            enabled: false,
                            child: Text('Nenhuma equipe disponível para os filtros selecionados'),
                          ),
                        ]
                      : [
                          const DropdownMenuItem<Equipe>(
                            value: null,
                            child: Text('Selecione uma equipe'),
                          ),
                          ..._equipesList.map((equipe) {
                            return DropdownMenuItem<Equipe>(
                              value: equipe,
                              child: Tooltip(
                                message: equipe.executores.isNotEmpty
                                    ? equipe.executores.map((e) => '${e.executorNome} (${e.papel})').join('\n')
                                    : 'Sem executores',
                                child: Text(equipe.nome),
                              ),
                            );
                          }),
                        ],
                  onChanged: _equipesList.isEmpty 
                      ? null 
                      : (Equipe? value) {
                          setState(() {
                            _selectedEquipe = value;
                            if (value != null) {
                              _selectedEquipeIds = {value.id};
                              _usarEquipe = true;
                              _executor = '';
                              _selectedExecutorIds.clear();
                            } else {
                              _selectedEquipeIds.clear();
                            }
                          });
                        },
                  validator: (value) {
                    if (_tipoExecutorEquipe == 'equipe' && value == null && _equipesList.isNotEmpty) {
                      return 'Selecione uma equipe';
                    }
                    return null;
                  },
                ),
              if (_equipesList.isEmpty && !_isLoadingExecutoresEquipes)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.orange[700]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Nenhuma equipe disponível para os filtros selecionados.',
                          style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          )
        else
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selecione o tipo (Executor Individual ou Equipe) para continuar.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
                ),
                if (!_isLoadingExecutoresEquipes) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Executores disponíveis: ${_executoresList.length}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                  Text(
                    'Equipes disponíveis: ${_equipesList.length}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ],
            ),
          ),
        if (_selectedEquipe != null && _selectedEquipe!.executores.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            'Executores da equipe:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          ..._selectedEquipe!.executores.map((equipeExecutor) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Row(
                children: [
                  Icon(
                    _getPapelIcon(equipeExecutor.papel),
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${equipeExecutor.executorNome} (${_getPapelLabel(equipeExecutor.papel)})',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildExecutoresDropdown() {
    // Garantir que sempre há pelo menos um dropdown
    if (_executoresSelecionados.isEmpty) {
      _executoresSelecionados = <Executor?>[null];
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Executores *',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        // Lista de dropdowns lado a lado
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // Dropdowns de executores
            ...List.generate(_executoresSelecionados.length, (index) {
              return _buildSingleExecutorDropdown(index);
            }),
            // Botão para adicionar mais dropdowns (sempre visível após os dropdowns)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    // Adicionar um novo dropdown vazio
                    _executoresSelecionados.add(null as Executor?);
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(Icons.add_circle, size: 24, color: Colors.blue),
                ),
              ),
            ),
          ],
        ),
        if (_executoresList.isEmpty && (_regionalId != null || _divisaoId != null || _segmentoId != null))
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Nenhum executor encontrado. Tente ajustar os filtros (Regional/Divisão/Segmento).',
              style: TextStyle(fontSize: 12, color: Colors.orange[700]),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
      ],
    );
  }

  Widget _buildSingleExecutorDropdown(int index) {
    // Verificar se o índice é válido
    if (index >= _executoresSelecionados.length) {
      return const SizedBox.shrink();
    }
    
    final executorSelecionado = _executoresSelecionados[index];
    
    // Filtrar executores disponíveis (todos os executores menos os já selecionados em outros dropdowns)
    // IMPORTANTE: Sempre incluir o executor selecionado neste dropdown específico
    final executorSelecionadoId = executorSelecionado?.id;
    
    // Criar lista de IDs já selecionados em OUTROS dropdowns (não este)
    final outrosExecutorIds = <String>{};
    for (int i = 0; i < _executoresSelecionados.length; i++) {
      if (i != index && _executoresSelecionados[i] != null) {
        outrosExecutorIds.add(_executoresSelecionados[i]!.id);
      }
    }
    
    final executoresDisponiveis = _executoresList.where((executor) {
      // Sempre incluir o executor selecionado neste dropdown específico
      if (executorSelecionadoId != null && executor.id == executorSelecionadoId) {
        return true;
      }
      // Excluir apenas executores selecionados em OUTROS dropdowns
      return !outrosExecutorIds.contains(executor.id);
    }).toList();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: Responsive.isMobile(context) ? double.infinity : 450,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildSearchableDropdown<Executor>(
                label: 'Executor ${index + 1}',
                value: executorSelecionado,
                items: executoresDisponiveis,
                getDisplayText: (executor) => executor.nomeCompleto ?? executor.nome,
                onChanged: (Executor? value) {
                  setState(() {
                    final executorAnterior = _executoresSelecionados[index];
                    if (executorAnterior != null) {
                      _selectedExecutorIds.remove(executorAnterior.id);
                    }
                    
                    _executoresSelecionados[index] = value;
                    if (value != null) {
                      _selectedExecutorIds.add(value.id);
                      _executor = _executoresList
                          .where((e) => _selectedExecutorIds.contains(e.id))
                          .map((e) => e.nome) // Salvar apenas o nome
                          .join(', ');
                    } else {
                      // Se não há mais executores selecionados, limpar _executor
                      if (_selectedExecutorIds.isEmpty) {
                        _executor = '';
                      } else {
                        _executor = _executoresList
                            .where((e) => _selectedExecutorIds.contains(e.id))
                            .map((e) => e.nome) // Salvar apenas o nome
                            .join(', ');
                      }
                    }
                    _usarEquipe = false;
                    _selectedEquipe = null;
                    _selectedEquipeIds.clear();
                  });
                },
                hintText: 'Digite para buscar executor...',
                compareFn: (Executor item1, Executor item2) {
                  return item1.id == item2.id;
                },
              ),
            ),
            // Botão para remover este dropdown (apenas se houver mais de um)
            if (_executoresSelecionados.length > 1)
              IconButton(
                icon: const Icon(Icons.remove_circle, color: Colors.red),
                onPressed: () {
                  setState(() {
                    final executorRemovido = _executoresSelecionados[index];
                    if (executorRemovido != null) {
                      _selectedExecutorIds.remove(executorRemovido.id);
                    }
                    _executoresSelecionados.removeAt(index);
                    // Atualizar _executor
                    if (_selectedExecutorIds.isEmpty) {
                      _executor = '';
                    } else {
                      _executor = _executoresList
                          .where((e) => _selectedExecutorIds.contains(e.id))
                          .map((e) => e.nome) // Salvar apenas o nome
                          .join(', ');
                    }
                  });
                },
                tooltip: 'Remover executor',
              ),
          ],
        ),
      ),
    );
  }

  IconData _getPapelIcon(String papel) {
    switch (papel) {
      case 'FISCAL':
        return Icons.gavel;
      case 'TST':
        return Icons.health_and_safety;
      case 'ENCARREGADO':
        return Icons.badge;
      case 'EXECUTOR':
        return Icons.person;
      default:
        return Icons.person;
    }
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

  // Mapear tipo da tarefa para tipo válido de segmento
  String _mapTaskTypeToSegmentType(String taskType) {
    // Tipos válidos para segmentos: 'BEA', 'FER', 'COMP', 'TRN', 'BSL', 'APO', 'OUT', 'ADM'
    final upperType = taskType.toUpperCase();
    
    // Se o tipo da tarefa já é um tipo válido de segmento, usar diretamente
    const validSegmentTypes = ['BEA', 'FER', 'COMP', 'TRN', 'BSL', 'APO', 'OUT', 'ADM'];
    if (validSegmentTypes.contains(upperType)) {
      return upperType;
    }
    
    // Mapear tipos comuns de tarefa para tipos de segmento
    // Se não encontrar correspondência, usar 'OUT' (Outros) como padrão
    final typeMap = {
      'FER': 'FER',
      'COMP': 'COMP',
      'BSL': 'BSL',
      'TRN': 'TRN',
      'APO': 'APO',
      'ADM': 'ADM',
      'BEA': 'BEA',
    };
    
    return typeMap[upperType] ?? 'OUT';
  }
  
  // Widget para gerenciar períodos de execução (segmentos do Gantt)
  Widget _buildPeriodosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Períodos de Execução',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (_ganttSegments.isEmpty)
          Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Nenhum período cadastrado. Clique no botão + para adicionar.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              // Botão para adicionar período quando não há nenhum
              Center(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        // Adicionar novo período baseado nas datas atuais ou último segmento
                        final lastSegment = _ganttSegments.isNotEmpty 
                            ? _ganttSegments.last 
                            : null;
                        final newStart = lastSegment?.dataFim.add(const Duration(days: 1)) ?? _dataInicio;
                        final newEnd = newStart.add(const Duration(days: 1));
                        
                        _ganttSegments.add(
                          GanttSegment(
                            dataInicio: newStart,
                            dataFim: newEnd,
                            label: _tarefa,
                            tipo: _mapTaskTypeToSegmentType(_tipo),
                            tipoPeriodo: 'EXECUCAO',
                          ),
                        );
                      });
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: const Icon(Icons.add_circle, size: 24, color: Colors.blue),
                    ),
                  ),
                ),
              ),
            ],
          )
        else
          Column(
            children: [
              ...List.generate(_ganttSegments.length, (index) {
                return _buildPeriodoCard(index);
              }),
              // Botão para adicionar mais períodos (sempre visível após os períodos)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      // Adicionar novo período baseado nas datas atuais ou último segmento
                      final lastSegment = _ganttSegments.isNotEmpty 
                          ? _ganttSegments.last 
                          : null;
                      final newStart = lastSegment?.dataFim.add(const Duration(days: 1)) ?? _dataInicio;
                      final newEnd = newStart.add(const Duration(days: 1));
                      
                      _ganttSegments.add(
                        GanttSegment(
                          dataInicio: newStart,
                          dataFim: newEnd,
                          label: _tarefa,
                          tipo: _mapTaskTypeToSegmentType(_tipo),
                          tipoPeriodo: 'EXECUCAO',
                        ),
                      );
                    });
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(top: 8),
                    child: const Icon(Icons.add_circle, size: 24, color: Colors.blue),
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 24),
        // Seção de Períodos por Executor
        _buildExecutorPeriodsSection(),
        const SizedBox(height: 24),
        // Seção de Períodos por Frota
        _buildFrotaPeriodsSection(),
      ],
    );
  }
  
  // Widget para gerenciar períodos específicos por executor
  Widget _buildExecutorPeriodsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Períodos Específicos por Executor',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Configure períodos diferentes para cada executor nesta tarefa',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        if (_executorPeriods.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text(
                  'Nenhum período por executor configurado.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    // Verificar se há executores selecionados
                    if (_selectedExecutorIds.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Selecione pelo menos um executor primeiro'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }
                    
                    setState(() {
                      // Criar períodos para cada executor selecionado
                      for (var executorId in _selectedExecutorIds) {
                        final executor = _executoresList.firstWhere(
                          (e) => e.id == executorId,
                          orElse: () => Executor(
                            id: executorId,
                            nome: 'Executor $executorId',
                          ),
                        );
                        
                        // Criar período inicial baseado no primeiro segmento ou datas da tarefa
                        final baseSegments = _cloneTaskSegmentsOrFallback();
                        _executorPeriods.add(
                          ExecutorPeriod(
                            executorId: executorId,
                            executorNome: executor.nome,
                            periods: baseSegments,
                          ),
                        );
                      }
                    });
                  },
                  icon: const Icon(Icons.person_add),
                  label: const Text('Adicionar Períodos por Executor'),
                ),
              ],
            ),
          )
        else
          Column(
            children: [
              ...List.generate(_executorPeriods.length, (index) {
                return _buildExecutorPeriodCard(index);
              }),
              ElevatedButton.icon(
                onPressed: () {
                  if (_selectedExecutorIds.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Selecione pelo menos um executor primeiro'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }
                  
                  // Verificar se o executor já tem período
                  final availableExecutors = _selectedExecutorIds.where((executorId) {
                    return !_executorPeriods.any((ep) => ep.executorId == executorId);
                  }).toList();
                  
                  if (availableExecutors.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Todos os executores já têm períodos configurados'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }
                  
                  setState(() {
                    // Adicionar período para o primeiro executor disponível
                    final executorId = availableExecutors.first;
                    final executor = _executoresList.firstWhere(
                      (e) => e.id == executorId,
                      orElse: () => Executor(
                        id: executorId,
                        nome: 'Executor $executorId',
                      ),
                    );
                    
                    final baseSegments = _cloneTaskSegmentsOrFallback();
                    _executorPeriods.add(
                      ExecutorPeriod(
                        executorId: executorId,
                        executorNome: executor.nome,
                        periods: baseSegments,
                      ),
                    );
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('Adicionar Executor'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[100],
                ),
              ),
            ],
          ),
      ],
    );
  }
  
  // Widget para exibir e editar períodos de um executor específico
  Widget _buildExecutorPeriodCard(int index) {
    final executorPeriod = _executorPeriods[index];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    executorPeriod.executorNome,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _executorPeriods.removeAt(index);
                    });
                  },
                  tooltip: 'Remover Executor',
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Períodos deste executor:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            if (executorPeriod.periods.isEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    const Text(
                      'Nenhum período configurado. Use os períodos gerais da tarefa.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _executorPeriods[index] = executorPeriod.copyWith(
                            periods: _cloneTaskSegmentsOrFallback(),
                          );
                        });
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Adicionar Período'),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: [
                  ...List.generate(executorPeriod.periods.length, (periodIndex) {
                    return _buildExecutorPeriodItemCard(index, periodIndex);
                  }),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        final lastPeriod = executorPeriod.periods.isNotEmpty 
                            ? executorPeriod.periods.last 
                            : null;
                        final newStart = lastPeriod?.dataFim.add(const Duration(days: 1)) ?? _dataInicio;
                        // Manter horário do último fim ou usar 08:00 -> 17:00 padrão
                        final startHour = lastPeriod?.dataInicio.hour ?? 8;
                        final startMin = lastPeriod?.dataInicio.minute ?? 0;
                        final endHour = lastPeriod?.dataFim.hour ?? 17;
                        final endMin = lastPeriod?.dataFim.minute ?? 0;
                        final startWithTime = DateTime(newStart.year, newStart.month, newStart.day, startHour, startMin);
                        final endWithTime = DateTime(newStart.year, newStart.month, newStart.day, endHour, endMin);
                        final newEnd = endWithTime.isAfter(startWithTime)
                            ? endWithTime
                            : startWithTime.add(const Duration(hours: 1));
                        
                        final newPeriod = GanttSegment(
                          dataInicio: startWithTime,
                          dataFim: newEnd,
                          label: _tarefa,
                          tipo: _mapTaskTypeToSegmentType(_tipo),
                          tipoPeriodo: 'EXECUCAO',
                        );
                        
                        _executorPeriods[index] = executorPeriod.copyWith(
                          periods: [...executorPeriod.periods, newPeriod],
                        );
                      });
                    },
                    icon: const Icon(Icons.add_circle_outline, size: 16),
                    label: const Text('Adicionar Período'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
  
  // Widget para exibir e editar um período específico de um executor
  Widget _buildExecutorPeriodItemCard(int executorIndex, int periodIndex) {
    final executorPeriod = _executorPeriods[executorIndex];
    final segment = executorPeriod.periods[periodIndex];

    String _formatDateTime(DateTime dt) {
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year.toString().substring(2);
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$day/$month/$year $hour:$minute';
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Período ${periodIndex + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      final periods = List<GanttSegment>.from(executorPeriod.periods);
                      periods.removeAt(periodIndex);
                      _executorPeriods[executorIndex] = executorPeriod.copyWith(periods: periods);
                    });
                  },
                  tooltip: 'Remover Período',
                ),
              ],
            ),
            const SizedBox(height: 8),
            // DateRangePicker para o período (mantém horas atuais)
            InkWell(
              onTap: () async {
                final DateTimeRange? picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                  initialDateRange: DateTimeRange(
                    start: segment.dataInicio,
                    end: segment.dataFim,
                  ),
                );
                if (picked != null) {
                  setState(() {
                    final startWithTime = DateTime(
                      picked.start.year,
                      picked.start.month,
                      picked.start.day,
                      segment.dataInicio.hour,
                      segment.dataInicio.minute,
                    );
                    final endWithTime = DateTime(
                      picked.end.year,
                      picked.end.month,
                      picked.end.day,
                      segment.dataFim.hour,
                      segment.dataFim.minute,
                    );
                    final periods = List<GanttSegment>.from(executorPeriod.periods);
                    periods[periodIndex] = segment.copyWith(
                      dataInicio: startWithTime,
                      dataFim: endWithTime,
                    );
                    _executorPeriods[executorIndex] = executorPeriod.copyWith(periods: periods);
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '${_formatDateTime(segment.dataInicio)} - ${_formatDateTime(segment.dataFim)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Seletor de horas início/fim
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.access_time),
                    label: Text('Início ${_formatDateTime(segment.dataInicio).split(' ').last}'),
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(hour: segment.dataInicio.hour, minute: segment.dataInicio.minute),
                      );
                      if (picked != null) {
                        setState(() {
                          final newStart = DateTime(
                            segment.dataInicio.year,
                            segment.dataInicio.month,
                            segment.dataInicio.day,
                            picked.hour,
                            picked.minute,
                          );
                          DateTime newEnd = segment.dataFim;
                          if (newEnd.isBefore(newStart)) {
                            newEnd = newStart.add(const Duration(hours: 1));
                          }
                          final periods = List<GanttSegment>.from(executorPeriod.periods);
                          periods[periodIndex] = segment.copyWith(
                            dataInicio: newStart,
                            dataFim: newEnd,
                          );
                          _executorPeriods[executorIndex] = executorPeriod.copyWith(periods: periods);
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.access_time_filled),
                    label: Text('Fim ${_formatDateTime(segment.dataFim).split(' ').last}'),
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(hour: segment.dataFim.hour, minute: segment.dataFim.minute),
                      );
                      if (picked != null) {
                        setState(() {
                          final newEnd = DateTime(
                            segment.dataFim.year,
                            segment.dataFim.month,
                            segment.dataFim.day,
                            picked.hour,
                            picked.minute,
                          );
                          DateTime newStart = segment.dataInicio;
                          if (newEnd.isBefore(newStart)) {
                            newStart = newEnd.subtract(const Duration(hours: 1));
                          }
                          final periods = List<GanttSegment>.from(executorPeriod.periods);
                          periods[periodIndex] = segment.copyWith(
                            dataInicio: newStart,
                            dataFim: newEnd,
                          );
                          _executorPeriods[executorIndex] = executorPeriod.copyWith(periods: periods);
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildDropdown(
              'Tipo Período',
              segment.tipoPeriodo,
              const ['EXECUCAO', 'PLANEJAMENTO', 'DESLOCAMENTO'],
              (value) {
                setState(() {
                  final periods = List<GanttSegment>.from(executorPeriod.periods);
                  periods[periodIndex] = segment.copyWith(
                    tipoPeriodo: value,
                    dataFim: value == 'DESLOCAMENTO' ? segment.dataInicio : segment.dataFim,
                  );
                  _executorPeriods[executorIndex] = executorPeriod.copyWith(periods: periods);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  // Widget para gerenciar períodos específicos por frota
  Widget _buildFrotaPeriodsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Períodos Específicos por Frota',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Configure períodos diferentes para cada frota nesta tarefa',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        if (_frotaPeriods.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text(
                  'Nenhum período por frota configurado.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    if (_selectedFrotaIds.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Selecione pelo menos uma frota primeiro'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }
                    setState(() {
                      for (var frotaId in _selectedFrotaIds) {
                        final frota = _frotasList.firstWhere(
                          (f) => f.id == frotaId,
                          orElse: () => Frota(
                            id: frotaId,
                            nome: 'Frota $frotaId',
                            placa: '',
                            tipoVeiculo: 'CARRO_LEVE',
                          ),
                        );
                        final baseSegments = _cloneTaskSegmentsOrFallback();
                        _frotaPeriods.add(
                          FrotaPeriod(
                            frotaId: frotaId,
                            frotaNome: frota.nome,
                            periods: baseSegments,
                          ),
                        );
                      }
                    });
                  },
                  icon: const Icon(Icons.local_shipping),
                  label: const Text('Adicionar Períodos por Frota'),
                ),
              ],
            ),
          )
        else
          Column(
            children: [
              ...List.generate(_frotaPeriods.length, (index) {
                return _buildFrotaPeriodCard(index);
              }),
              ElevatedButton.icon(
                onPressed: () {
                  if (_selectedFrotaIds.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Selecione pelo menos uma frota primeiro'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }
                  
                  final availableFrotas = _selectedFrotaIds.where((frotaId) {
                    return !_frotaPeriods.any((fp) => fp.frotaId == frotaId);
                  }).toList();
                  
                  if (availableFrotas.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Todas as frotas já têm períodos configurados'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }
                  
                  setState(() {
                    final frotaId = availableFrotas.first;
                    final frota = _frotasList.firstWhere(
                      (f) => f.id == frotaId,
                      orElse: () => Frota(
                        id: frotaId,
                        nome: 'Frota $frotaId',
                        placa: '',
                        tipoVeiculo: 'CARRO_LEVE',
                      ),
                    );
                    final baseSegments = _cloneTaskSegmentsOrFallback();
                    _frotaPeriods.add(
                      FrotaPeriod(
                        frotaId: frotaId,
                        frotaNome: frota.nome,
                        periods: baseSegments,
                      ),
                    );
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('Adicionar Frota'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[100],
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildFrotaPeriodCard(int index) {
    final frotaPeriod = _frotaPeriods[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    frotaPeriod.frotaNome,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _frotaPeriods.removeAt(index);
                    });
                  },
                  tooltip: 'Remover Frota',
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Períodos desta frota:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            if (frotaPeriod.periods.isEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    const Text(
                      'Nenhum período configurado. Use os períodos gerais da tarefa.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _frotaPeriods[index] = frotaPeriod.copyWith(
                            periods: _cloneTaskSegmentsOrFallback(),
                          );
                        });
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Adicionar Período'),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: [
                  ...List.generate(frotaPeriod.periods.length, (periodIndex) {
                    return _buildFrotaPeriodItemCard(index, periodIndex);
                  }),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        final lastPeriod = frotaPeriod.periods.isNotEmpty 
                            ? frotaPeriod.periods.last 
                            : null;
                        final newStart = lastPeriod?.dataFim.add(const Duration(days: 1)) ?? _dataInicio;
                        final startHour = lastPeriod?.dataInicio.hour ?? 8;
                        final startMin = lastPeriod?.dataInicio.minute ?? 0;
                        final endHour = lastPeriod?.dataFim.hour ?? 17;
                        final endMin = lastPeriod?.dataFim.minute ?? 0;
                        final startWithTime = DateTime(newStart.year, newStart.month, newStart.day, startHour, startMin);
                        final endWithTime = DateTime(newStart.year, newStart.month, newStart.day, endHour, endMin);
                        final newEnd = endWithTime.isAfter(startWithTime)
                            ? endWithTime
                            : startWithTime.add(const Duration(hours: 1));
                        
                        final newPeriod = GanttSegment(
                          dataInicio: startWithTime,
                          dataFim: newEnd,
                          label: _tarefa,
                          tipo: _mapTaskTypeToSegmentType(_tipo),
                          tipoPeriodo: 'EXECUCAO',
                        );
                        
                        _frotaPeriods[index] = frotaPeriod.copyWith(
                          periods: [...frotaPeriod.periods, newPeriod],
                        );
                      });
                    },
                    icon: const Icon(Icons.add_circle_outline, size: 16),
                    label: const Text('Adicionar Período'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrotaPeriodItemCard(int frotaIndex, int periodIndex) {
    final frotaPeriod = _frotaPeriods[frotaIndex];
    final segment = frotaPeriod.periods[periodIndex];

    String _formatDateTime(DateTime dt) {
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year.toString().substring(2);
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$day/$month/$year $hour:$minute';
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Período ${periodIndex + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      final periods = List<GanttSegment>.from(frotaPeriod.periods);
                      periods.removeAt(periodIndex);
                      _frotaPeriods[frotaIndex] = frotaPeriod.copyWith(periods: periods);
                    });
                  },
                  tooltip: 'Remover Período',
                ),
              ],
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final DateTimeRange? picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                  initialDateRange: DateTimeRange(
                    start: segment.dataInicio,
                    end: segment.dataFim,
                  ),
                );
                if (picked != null) {
                  setState(() {
                    final startWithTime = DateTime(
                      picked.start.year,
                      picked.start.month,
                      picked.start.day,
                      segment.dataInicio.hour,
                      segment.dataInicio.minute,
                    );
                    final endWithTime = DateTime(
                      picked.end.year,
                      picked.end.month,
                      picked.end.day,
                      segment.dataFim.hour,
                      segment.dataFim.minute,
                    );
                    
                    final periods = List<GanttSegment>.from(frotaPeriod.periods);
                    periods[periodIndex] = segment.copyWith(
                      dataInicio: startWithTime,
                      dataFim: endWithTime,
                    );
                    _frotaPeriods[frotaIndex] = frotaPeriod.copyWith(periods: periods);
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.date_range, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      '${_formatDateTime(segment.dataInicio)}  —  ${_formatDateTime(segment.dataFim)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const Spacer(),
                    const Icon(Icons.edit_calendar, size: 16, color: Colors.blue),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () async {
                      final startTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(segment.dataInicio),
                      );
                      if (startTime != null) {
                        setState(() {
                          final updatedStart = DateTime(
                            segment.dataInicio.year,
                            segment.dataInicio.month,
                            segment.dataInicio.day,
                            startTime.hour,
                            startTime.minute,
                          );
                          DateTime updatedEnd = segment.dataFim;
                          if (!segment.dataFim.isAfter(updatedStart)) {
                            updatedEnd = updatedStart.add(const Duration(hours: 1));
                          }
                          final periods = List<GanttSegment>.from(frotaPeriod.periods);
                          periods[periodIndex] = segment.copyWith(
                            dataInicio: updatedStart,
                            dataFim: updatedEnd,
                          );
                          _frotaPeriods[frotaIndex] = frotaPeriod.copyWith(periods: periods);
                        });
                      }
                    },
                    icon: const Icon(Icons.access_time, size: 16),
                    label: const Text('Início'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () async {
                      final endTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(segment.dataFim),
                      );
                      if (endTime != null) {
                        setState(() {
                          DateTime updatedEnd = DateTime(
                            segment.dataFim.year,
                            segment.dataFim.month,
                            segment.dataFim.day,
                            endTime.hour,
                            endTime.minute,
                          );
                          if (!updatedEnd.isAfter(segment.dataInicio)) {
                            updatedEnd = segment.dataInicio.add(const Duration(hours: 1));
                          }
                          final periods = List<GanttSegment>.from(frotaPeriod.periods);
                          periods[periodIndex] = segment.copyWith(
                            dataFim: updatedEnd,
                          );
                          _frotaPeriods[frotaIndex] = frotaPeriod.copyWith(periods: periods);
                        });
                      }
                    },
                    icon: const Icon(Icons.access_time_filled, size: 16),
                    label: const Text('Fim'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPeriodoCard(int index) {
    final segment = _ganttSegments[index];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Período ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _ganttSegments.removeAt(index);
                      // Atualizar dataInicio e dataFim da tarefa baseado nos segmentos restantes
                      if (_ganttSegments.isNotEmpty) {
                        _dataInicio = _ganttSegments.map((s) => s.dataInicio).reduce((a, b) => a.isBefore(b) ? a : b);
                        _dataFim = _ganttSegments.map((s) => s.dataFim).reduce((a, b) => a.isAfter(b) ? a : b);
                      } else {
                        // Se não houver mais segmentos, manter as datas atuais ou usar valores padrão
                        _dataInicio = widget.startDate;
                        _dataFim = widget.endDate;
                      }
                    });
                  },
                  tooltip: 'Remover Período',
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Para EXECUCAO e PLANEJAMENTO: usar DateRangePicker
            // Para DESLOCAMENTO: usar dois DatePickers separados (ida e volta)
            if (segment.tipoPeriodo == 'EXECUCAO' || segment.tipoPeriodo == 'PLANEJAMENTO')
              _buildDateRangeField(
                'Período',
                segment.dataInicio,
                segment.dataFim,
                (start, end) {
                  setState(() {
                    _ganttSegments[index] = segment.copyWith(
                      dataInicio: start,
                      dataFim: end,
                    );
                    // Atualizar dataInicio e dataFim da tarefa
                    if (_ganttSegments.isNotEmpty) {
                      _dataInicio = _ganttSegments.map((s) => s.dataInicio).reduce((a, b) => a.isBefore(b) ? a : b);
                      _dataFim = _ganttSegments.map((s) => s.dataFim).reduce((a, b) => a.isAfter(b) ? a : b);
                    }
                  });
                },
              )
            else
              // Para DESLOCAMENTO: dois campos separados (ida e volta)
              Row(
                children: [
                  Expanded(
                    child: _buildDateField(
                      'Data de Ida',
                      segment.dataInicio,
                      (date) {
                        setState(() {
                          _ganttSegments[index] = segment.copyWith(
                            dataInicio: date,
                          );
                          // Atualizar dataInicio da tarefa
                          if (_ganttSegments.isNotEmpty) {
                            _dataInicio = _ganttSegments.map((s) => s.dataInicio).reduce((a, b) => a.isBefore(b) ? a : b);
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDateField(
                      'Data de Volta',
                      segment.dataFim,
                      (date) {
                        setState(() {
                          _ganttSegments[index] = segment.copyWith(
                            dataFim: date,
                          );
                          // Atualizar dataFim da tarefa
                          if (_ganttSegments.isNotEmpty) {
                            _dataFim = _ganttSegments.map((s) => s.dataFim).reduce((a, b) => a.isAfter(b) ? a : b);
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            _buildDropdown(
              'Tipo de Período',
              segment.tipoPeriodo,
              const ['EXECUCAO', 'PLANEJAMENTO', 'DESLOCAMENTO'],
              (value) {
                setState(() {
                  // Se mudou para DESLOCAMENTO, fazer data fim igual à data início
                  final newDataFim = value == 'DESLOCAMENTO' 
                      ? segment.dataInicio 
                      : segment.dataFim;
                  _ganttSegments[index] = segment.copyWith(
                    tipoPeriodo: value,
                    dataFim: newDataFim,
                  );
                  // Atualizar dataFim da tarefa
                  if (_ganttSegments.isNotEmpty) {
                    _dataFim = _ganttSegments.map((s) => s.dataFim).reduce((a, b) => a.isAfter(b) ? a : b);
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildNotasSAPSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Notas SAP Vinculadas',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: _isAdicionandoNotaSAP ? null : () => _adicionarNotaSAP(),
                icon: const Icon(Icons.add),
                label: _isAdicionandoNotaSAP
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Adicionar Nota'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoadingNotasSAP)
            const Center(child: CircularProgressIndicator())
          else if (_notasSAPVinculadas.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                children: [
                  Icon(Icons.description, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Nenhuma nota SAP vinculada',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _notasSAPVinculadas.length,
              itemBuilder: (context, index) {
                final nota = _notasSAPVinculadas[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getStatusUsuarioColor(nota.statusUsuario),
                      child: Text(
                        nota.tipo ?? '?',
                        style: TextStyle(
                          color: _getStatusUsuarioTextColor(nota.statusUsuario),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(
                          'Nota SAP: ',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          nota.nota,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A5F),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (nota.descricao != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              nota.descricao!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (nota.local != null && nota.local!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'Local: ${nota.local}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        if (nota.sala != null && nota.sala!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'Sala: ${nota.sala}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        if (nota.criadoEm != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'Criado: ${_formatDateNotaSAP(nota.criadoEm!)}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _removerNotaSAP(nota),
                    ),
                    onTap: () => _visualizarNotaSAP(nota),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
  
  String _formatDateNotaSAP(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  // Retorna a cor do avatar baseada no status do usuário da nota
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
    if (status.contains('EMAM')) return Colors.yellow;
    
    // ANLS - Azul
    if (status.contains('ANLS')) return Colors.blue;
    
    // Padrão: cinza
    return Colors.grey;
  }

  // Retorna a cor do texto do avatar baseada no status do usuário da nota
  Color _getStatusUsuarioTextColor(String? statusUsuario) {
    if (statusUsuario == null || statusUsuario.isEmpty) return Colors.white;
    
    final status = statusUsuario.toUpperCase();
    
    // Para EMAM (amarelo), usar texto preto para melhor contraste
    if (status.contains('EMAM')) return Colors.black;
    
    // Para os outros, usar texto branco
    return Colors.white;
  }
  
  Future<void> _adicionarNotaSAP() async {
    if (widget.task == null) return;
    setState(() {
      _isAdicionandoNotaSAP = true;
    });
    try {
    // Buscar todas as notas disponíveis
    final todasNotas = await _notaSAPService.getAllNotas(limit: 1000);
    
    // Filtrar notas já vinculadas
    var notasDisponiveis = todasNotas
        .where((n) => !_notasSAPVinculadas.any((v) => v.id == n.id))
        .toList();

    // Excluir notas cujo status_sistema contenha MSEN (concluídas)
    notasDisponiveis = notasDisponiveis.where((n) {
      final status = n.statusSistema?.toUpperCase() ?? '';
      return !status.contains('MSEN');
    }).toList();

    // Restringir ao mesmo local da tarefa, se houver locais definidos
    final locaisTarefa = widget.task?.locais
            .where((l) => l.trim().isNotEmpty)
            .toList() ??
        [];
    if (locaisTarefa.isNotEmpty) {
      final localSet = locaisTarefa
          .map((l) => l.trim().toLowerCase())
          .where((l) => l.isNotEmpty)
          .toSet();
      notasDisponiveis = notasDisponiveis.where((n) {
        final notaLocalRaw = (n.local ?? n.localInstalacao ?? '').trim().toLowerCase();
        if (notaLocalRaw.isEmpty) return false;
        return localSet.any((loc) =>
            notaLocalRaw.contains(loc) || loc.contains(notaLocalRaw));
      }).toList();
    }
    
    if (notasDisponiveis.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Todas as notas já estão vinculadas ou não há notas disponíveis para este local'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    
    // Mostrar diálogo melhorado para selecionar nota(s)
    final notasSelecionadas = await showDialog<List<NotaSAP>>(
      context: context,
      builder: (context) => NotaSAPSelectionDialog(
        notas: notasDisponiveis,
        title: 'Selecionar Nota(s) SAP',
        taskTarefa: widget.task?.tarefa,
      ),
    );
    
    if (notasSelecionadas != null && notasSelecionadas.isNotEmpty) {
      try {
        // Vincular todas as notas selecionadas
        for (final nota in notasSelecionadas) {
          await _notaSAPService.vincularNotaATarefa(widget.task!.id, nota.id);
        }
        await _loadNotasSAP();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                notasSelecionadas.length == 1
                    ? 'Nota ${notasSelecionadas.first.nota} vinculada com sucesso'
                    : '${notasSelecionadas.length} notas vinculadas com sucesso',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao vincular nota: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAdicionandoNotaSAP = false;
        });
      } else {
        _isAdicionandoNotaSAP = false;
      }
    }
  }
  
  Future<void> _removerNotaSAP(NotaSAP nota) async {
    if (widget.task == null) return;
    
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Remoção'),
        content: Text('Deseja remover a nota ${nota.nota} desta tarefa?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    
    if (confirmar == true) {
      try {
        await _notaSAPService.desvincularNotaDeTarefa(widget.task!.id, nota.id);
        await _loadNotasSAP();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Nota ${nota.nota} removida com sucesso'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao remover nota: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
  
  void _visualizarNotaSAP(NotaSAP nota) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Nota SAP: ${nota.nota}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoRowNotaSAP('Tipo', nota.tipo),
              _buildInfoRowNotaSAP('Prioridade', nota.textPrioridade),
              _buildInfoRowNotaSAP('Descrição', nota.descricao),
              _buildInfoRowNotaSAP('Local', nota.localInstalacao),
              _buildInfoRowNotaSAP('Sala', nota.sala),
              _buildInfoRowNotaSAP('Equipamento', nota.equipamento),
              _buildInfoRowNotaSAP('Status Sistema', nota.statusSistema),
              _buildInfoRowNotaSAP('Status Usuário', nota.statusUsuario),
              _buildInfoRowNotaSAP('Centro', nota.centro),
              _buildInfoRowNotaSAP('Executor', nota.denominacaoExecutor),
              if (nota.criadoEm != null)
                _buildInfoRowNotaSAP('Criado em', _formatDateNotaSAP(nota.criadoEm!)),
              if (nota.inicioDesejado != null)
                _buildInfoRowNotaSAP('Início Desejado', _formatDateNotaSAP(nota.inicioDesejado!)),
              if (nota.conclusaoDesejada != null)
                _buildInfoRowNotaSAP('Conclusão Desejada', _formatDateNotaSAP(nota.conclusaoDesejada!)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
  
  // Métodos para Ordens Vinculadas
  Future<void> _loadOrdens() async {
    if (widget.task == null) {
      print('⚠️ _loadOrdens: widget.task é null, não carregando');
      return;
    }
    
    print('📋 Carregando ordens para tarefa ${widget.task!.id}...');
    setState(() {
      _isLoadingOrdens = true;
    });
    
    try {
      final ordens = await _ordemService.getOrdensPorTarefa(widget.task!.id);
      print('✅ Carregadas ${ordens.length} ordens vinculadas');
      setState(() {
        _ordensVinculadas = ordens;
        _isLoadingOrdens = false;
      });
    } catch (e, stackTrace) {
      print('❌ Erro ao carregar ordens: $e');
      print('   Stack trace: $stackTrace');
      setState(() {
        _isLoadingOrdens = false;
      });
    }
  }

  Future<void> _adicionarOrdem() async {
    if (widget.task == null) return;
    
    setState(() {
      _isAdicionandoOrdem = true;
    });
    
    try {
      final todasOrdens = await _ordemService.getAllOrdens(
        limit: null,
        offset: null,
        apenasAbertas: true,
      );
      // Considerar apenas ordens abertas (já filtradas no serviço)
      final ordensDisponiveis = todasOrdens
          .where((o) => !_ordensVinculadas.any((v) => v.id == o.id))
          .toList();
      
      if (ordensDisponiveis.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Todas as ordens já estão vinculadas ou não há ordens disponíveis'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      // Usar o diálogo de seleção de ordens
      final ordensSelecionadas = await showDialog<List<Ordem>>(
        context: context,
        builder: (context) => OrdemSelectionDialog(
          ordens: ordensDisponiveis,
          title: 'Selecionar Ordem',
          taskTarefa: widget.task?.tarefa,
          taskLocal: widget.task?.locais.isNotEmpty == true
              ? widget.task!.locais.first
              : null,
        ),
      );
      
      if (ordensSelecionadas != null && ordensSelecionadas.isNotEmpty) {
        try {
          for (final ordem in ordensSelecionadas) {
            await _ordemService.vincularOrdemATarefa(widget.task!.id, ordem.id);
          }
          await _loadOrdens();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${ordensSelecionadas.length} ordem(ns) vinculada(s) com sucesso'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erro ao vincular ordem(ns): $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao adicionar ordem: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    finally {
      if (mounted) {
        setState(() {
          _isAdicionandoOrdem = false;
        });
      } else {
        _isAdicionandoOrdem = false;
      }
    }
  }

  Future<void> _removerOrdem(Ordem ordem) async {
    if (widget.task == null) return;
    
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Remoção'),
        content: Text('Deseja remover a ordem ${ordem.ordem} desta tarefa?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    
    if (confirmar == true) {
      try {
        await _ordemService.desvincularOrdemDeTarefa(widget.task!.id, ordem.id);
        await _loadOrdens();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ordem ${ordem.ordem} removida com sucesso'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao remover ordem: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildOrdensSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Ordens Vinculadas',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: _isAdicionandoOrdem ? null : () => _adicionarOrdem(),
                icon: const Icon(Icons.add),
                label: _isAdicionandoOrdem
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Adicionar Ordem'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoadingOrdens)
            const Center(child: CircularProgressIndicator())
          else if (_ordensVinculadas.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                children: [
                  Icon(Icons.receipt_long, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Nenhuma ordem vinculada',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _ordensVinculadas.length,
              itemBuilder: (context, index) {
                final ordem = _ordensVinculadas[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: ordem.statusSistema?.contains('ABER') == true
                          ? Colors.orange
                          : ordem.statusSistema?.contains('LIB') == true
                              ? Colors.green
                              : Colors.grey,
                      child: Text(
                        ordem.tipo ?? '?',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text('Ordem: ${ordem.ordem}'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18, color: Colors.blue),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () async {
                            try {
                              await Clipboard.setData(ClipboardData(text: ordem.ordem));
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Ordem copiada!'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Não foi possível copiar a ordem: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          tooltip: 'Copiar ordem',
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (ordem.textoBreve != null)
                          Text(
                            ordem.textoBreve!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (ordem.localInstalacao != null)
                          Text(
                            'Local: ${ordem.localInstalacao}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        if (ordem.inicioBase != null)
                          Text(
                            'Início: ${_formatDateOrdem(ordem.inicioBase!)}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _removerOrdem(ordem),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  String _formatDateOrdem(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  // Métodos para ATs Vinculadas
  Future<void> _loadATs() async {
    if (widget.task == null) {
      print('⚠️ _loadATs: widget.task é null, não carregando');
      return;
    }
    
    print('📋 Carregando ATs para tarefa ${widget.task!.id}...');
    setState(() {
      _isLoadingATs = true;
    });
    
    try {
      final ats = await _atService.getATsPorTarefa(widget.task!.id);
      print('✅ Carregadas ${ats.length} ATs vinculadas');
      setState(() {
        _atsVinculadas = ats;
        _isLoadingATs = false;
      });
    } catch (e, stackTrace) {
      print('❌ Erro ao carregar ATs: $e');
      print('   Stack trace: $stackTrace');
      setState(() {
        _isLoadingATs = false;
      });
    }
  }

  Future<void> _adicionarAT() async {
    if (widget.task == null) return;
    
    setState(() {
      _isAdicionandoAT = true;
    });
    
    try {
      // Buscar todas as ATs (já filtradas por centro de trabalho no serviço)
      final todasATs = await _atService.getAllATs(
        limit: 1000,
        offset: null,
      );
      
      final atsDisponiveis = todasATs
          .where((at) => !_atsVinculadas.any((v) => v.id == at.id))
          .toList();
      
      if (atsDisponiveis.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Todas as ATs já estão vinculadas ou não há ATs disponíveis'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      // Usar o diálogo de seleção de ATs
      final atsSelecionadas = await showDialog<List<AT>>(
        context: context,
        builder: (context) => ATSelectionDialog(
          ats: atsDisponiveis,
          title: 'Selecionar AT',
          taskTarefa: widget.task?.tarefa,
          taskLocal: widget.task?.locais.isNotEmpty == true
              ? widget.task!.locais.first
              : null,
        ),
      );
      
      if (atsSelecionadas != null && atsSelecionadas.isNotEmpty) {
        try {
          for (final at in atsSelecionadas) {
            await _atService.vincularATATarefa(widget.task!.id, at.id);
          }
          await _loadATs();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${atsSelecionadas.length} AT(s) vinculada(s) com sucesso'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erro ao vincular AT(s): $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao adicionar AT: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    finally {
      if (mounted) {
        setState(() {
          _isAdicionandoAT = false;
        });
      } else {
        _isAdicionandoAT = false;
      }
    }
  }

  Future<void> _removerAT(AT at) async {
    if (widget.task == null) return;
    
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Remoção'),
        content: Text('Deseja remover a AT ${at.autorzTrab} desta tarefa?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    
    if (confirmar == true) {
      try {
        await _atService.desvincularATDeTarefa(widget.task!.id, at.id);
        await _loadATs();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('AT ${at.autorzTrab} removida com sucesso'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao remover AT: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildATsSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ATs Vinculadas',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: _isAdicionandoAT ? null : () => _adicionarAT(),
                icon: const Icon(Icons.add),
                label: _isAdicionandoAT
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Adicionar AT'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoadingATs)
            const Center(child: CircularProgressIndicator())
          else if (_atsVinculadas.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                children: [
                  Icon(Icons.assignment, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Nenhuma AT vinculada',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _atsVinculadas.length,
              itemBuilder: (context, index) {
                final at = _atsVinculadas[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: at.statusSistema?.contains('ABER') == true
                          ? Colors.orange
                          : at.statusSistema?.contains('LIB') == true
                              ? Colors.green
                              : Colors.grey,
                      child: Text(
                        at.statusSistema?.substring(0, 1) ?? '?',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    title: Text('AT: ${at.autorzTrab}'),
                    subtitle: Text(at.textoBreve ?? '-'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _removerAT(at),
                    ),
                    onTap: () {
                      // Mostrar detalhes da AT
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('AT: ${at.autorzTrab}'),
                          content: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildInfoRowAT('Texto Breve', at.textoBreve),
                                _buildInfoRowAT('Local', at.localInstalacao),
                                _buildInfoRowAT('Status Sistema', at.statusSistema),
                                _buildInfoRowAT('Status Usuário', at.statusUsuario),
                                _buildInfoRowAT('Centro de Trabalho', at.cntrTrab),
                                if (at.dataInicio != null)
                                  _buildInfoRowAT('Data Início', _formatDateAT(at.dataInicio!)),
                                if (at.dataFim != null)
                                  _buildInfoRowAT('Data Fim', _formatDateAT(at.dataFim!)),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Fechar'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRowAT(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value ?? '-'),
          ),
        ],
      ),
    );
  }

  String _formatDateAT(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Widget _buildInfoRowNotaSAP(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  // Métodos para SIs Vinculadas
  Future<void> _loadSIs() async {
    if (widget.task == null) {
      print('⚠️ _loadSIs: widget.task é null, não carregando');
      return;
    }
    
    if (!mounted) return;
    
    print('📋 Carregando SIs para tarefa ${widget.task!.id}...');
    
    try {
      setState(() {
        _isLoadingSIs = true;
      });
      
      final sis = await _siService.getSIsPorTarefa(widget.task!.id);
      print('✅ Carregadas ${sis.length} SIs vinculadas');
      
      if (mounted) {
        setState(() {
          _sisVinculadas = sis;
          _isLoadingSIs = false;
        });
      }
    } catch (e) {
      print('❌ Erro ao carregar SIs: $e');
      if (mounted) {
        setState(() {
          _isLoadingSIs = false;
        });
      }
    }
  }

  Future<void> _adicionarSI() async {
    if (widget.task == null) return;
    
    setState(() {
      _isAdicionandoSI = true;
    });
    
    try {
      // Buscar todas as SIs (já filtradas por centro de trabalho no serviço)
      final todasSIs = await _siService.getAllSIs(
        limit: 1000,
      );
      
      final sisDisponiveis = todasSIs
          .where((si) => !_sisVinculadas.any((v) => v.id == si.id))
          .toList();
      
      if (sisDisponiveis.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Todas as SIs já estão vinculadas ou não há SIs disponíveis'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      // Usar o diálogo de seleção de SIs
      final sisSelecionadas = await showDialog<List<SI>>(
        context: context,
        builder: (context) => SISelectionDialog(
          sis: sisDisponiveis,
          title: 'Selecionar SI',
          taskTarefa: widget.task?.tarefa,
          taskLocal: widget.task?.locais.isNotEmpty == true
              ? widget.task!.locais.first
              : null,
        ),
      );
      
      if (sisSelecionadas != null && sisSelecionadas.isNotEmpty) {
        try {
          for (final si in sisSelecionadas) {
            await _siService.vincularSITarefa(widget.task!.id, si.id);
          }
          await _loadSIs();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${sisSelecionadas.length} SI(s) vinculada(s) com sucesso'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erro ao vincular SI(s): $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao buscar SIs: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    finally {
      if (mounted) {
        setState(() {
          _isAdicionandoSI = false;
        });
      } else {
        _isAdicionandoSI = false;
      }
    }
  }

  Future<void> _removerSI(SI si) async {
    if (widget.task == null) return;
    
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Remoção'),
        content: Text('Deseja remover a SI ${si.solicitacao} desta tarefa?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remover', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirmar == true) {
      try {
        await _siService.desvincularSITarefa(widget.task!.id, si.id);
        await _loadSIs();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('SI ${si.solicitacao} removida com sucesso'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao remover SI: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildSIsSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SIs Vinculadas',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: _isAdicionandoSI ? null : () => _adicionarSI(),
                icon: const Icon(Icons.add),
                label: _isAdicionandoSI
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Adicionar SI'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoadingSIs)
            const Center(child: CircularProgressIndicator())
          else if (_sisVinculadas.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                children: [
                  Icon(Icons.description, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Nenhuma SI vinculada',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _sisVinculadas.length,
              itemBuilder: (context, index) {
                final si = _sisVinculadas[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: si.statusSistema?.contains('CRI') == true
                          ? Colors.orange
                          : si.statusSistema?.contains('PREP') == true
                              ? Colors.green
                              : Colors.grey,
                      child: Text(
                        si.statusSistema?.substring(0, 1) ?? '?',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    title: Text('SI: ${si.solicitacao}'),
                    subtitle: Text(si.textoBreve ?? '-'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _removerSI(si),
                    ),
                    onTap: () {
                      // Mostrar detalhes da SI
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('SI: ${si.solicitacao}'),
                          content: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildInfoRowSI('Texto Breve', si.textoBreve),
                                _buildInfoRowSI('Local', si.localInstalacao),
                                _buildInfoRowSI('Status Sistema', si.statusSistema),
                                _buildInfoRowSI('Status Usuário', si.statusUsuario),
                                _buildInfoRowSI('Tipo', si.tipo),
                                _buildInfoRowSI('Centro de Trabalho', si.cntrTrab),
                                if (si.dataInicio != null)
                                  _buildInfoRowSI('Data Início', _formatDateSI(si.dataInicio!)),
                                if (si.dataFim != null)
                                  _buildInfoRowSI('Data Fim', _formatDateSI(si.dataFim!)),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Fechar'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRowSI(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value ?? '-'),
          ),
        ],
      ),
    );
  }

  String _formatDateSI(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  // Método auxiliar para construir Tab com badge
  Widget _buildTabWithBadge({
    required IconData icon,
    required String label,
    required int count,
    required BuildContext context,
  }) {
    final isDesktop = Responsive.isDesktop(context);
    final iconSize = isDesktop ? 20.0 : 18.0;
    final fontSize = isDesktop ? 13.0 : 11.0;
    
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: iconSize),
          SizedBox(width: isDesktop ? 6 : 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(fontSize: fontSize),
            ),
          ),
          if (count > 0) ...[
            SizedBox(width: isDesktop ? 4 : 3),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: count > 9 ? (isDesktop ? 5 : 4) : (isDesktop ? 6 : 5),
                vertical: 1,
              ),
              constraints: BoxConstraints(
                minWidth: isDesktop ? 18.0 : 16.0,
              ),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count > 99 ? '99+' : count.toString(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isDesktop ? 9.0 : 8.0,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Método para construir o conteúdo do grupo SAP
  Widget _buildSAPGroupContent() {
    if (widget.task == null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Itens SAP podem ser vinculados após criar a tarefa',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Mostrar o conteúdo baseado na sub-tab selecionada
    switch (_sapSubTab) {
      case 'notas':
        return _buildNotasSAPSection();
      case 'ordens':
        return _buildOrdensSection();
      case 'ats':
        return _buildATsSection();
      case 'sis':
        return _buildSIsSection();
      default:
        return _buildNotasSAPSection();
    }
  }

  // Método para construir a tab do grupo SAP
  Widget _buildSAPGroupTab(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final totalCount = _notasSAPVinculadas.length + 
                      _ordensVinculadas.length + 
                      _atsVinculadas.length + 
                      _sisVinculadas.length;
    
    return Tab(
      child: Builder(
        builder: (tabContext) => PopupMenuButton<String>(
          offset: const Offset(0, 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(Icons.inventory_2, size: isDesktop ? 20.0 : 18.0),
                  if (totalCount > 0)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        width: isDesktop ? 14.0 : 12.0,
                        height: isDesktop ? 14.0 : 12.0,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            totalCount > 9 ? '9+' : totalCount.toString(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isDesktop ? 8.0 : 7.0,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(width: isDesktop ? 6 : 4),
              Flexible(
                child: Text(
                  'SAP',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(fontSize: isDesktop ? 13.0 : 11.0),
                ),
              ),
              SizedBox(width: isDesktop ? 2 : 1),
              Icon(
                Icons.arrow_drop_down,
                size: isDesktop ? 16.0 : 14.0,
              ),
            ],
          ),
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              value: 'notas',
              child: Row(
                children: [
                  const Icon(Icons.description, size: 20, color: Color(0xFF1E3A5F)),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Notas SAP',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  if (_notasSAPVinculadas.length > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _notasSAPVinculadas.length > 99 
                            ? '99+' 
                            : _notasSAPVinculadas.length.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'ordens',
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, size: 20, color: Color(0xFF1E3A5F)),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Ordens',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  if (_ordensVinculadas.length > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _ordensVinculadas.length > 99 
                            ? '99+' 
                            : _ordensVinculadas.length.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'ats',
              child: Row(
                children: [
                  const Icon(Icons.assignment, size: 20, color: Color(0xFF1E3A5F)),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'ATs',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  if (_atsVinculadas.length > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _atsVinculadas.length > 99 
                            ? '99+' 
                            : _atsVinculadas.length.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'sis',
              child: Row(
                children: [
                  const Icon(Icons.info, size: 20, color: Color(0xFF1E3A5F)),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'SIs',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  if (_sisVinculadas.length > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _sisVinculadas.length > 99 
                            ? '99+' 
                            : _sisVinculadas.length.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            setState(() {
              _sapSubTab = value;
              // Calcular o índice correto da tab SAP dinamicamente
              // Tabs: Básicas(0), Respons.(1), Frota(2), Datas(3), Obs.(4), Anexos(5), [PEX/APR(6) se root], SAP(última)
              final sapTabIndex = _isUserRoot ? 7 : 6;
              // Mudar para a tab SAP
              if (sapTabIndex < _tabController.length) {
                _tabController.animateTo(sapTabIndex);
              } else {
                // Fallback: usar o último índice disponível
                _tabController.animateTo(_tabController.length - 1);
              }
            });
          },
        ),
      ),
    );
  }

}

