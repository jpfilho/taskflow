import 'package:flutter/material.dart';
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

class TaskFormDialog extends StatefulWidget {
  final Task? task; // null para criar, Task para editar
  final DateTime startDate;
  final DateTime endDate;
  final String? parentTaskId; // ID da tarefa pai (se for criar subtarefa)

  const TaskFormDialog({
    super.key,
    this.task,
    required this.startDate,
    required this.endDate,
    this.parentTaskId,
  });

  @override
  State<TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends State<TaskFormDialog> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;
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

  
  // Lista de segmentos do Gantt (períodos de execução)
  List<GanttSegment> _ganttSegments = [];
  
  // Períodos específicos por executor
  List<ExecutorPeriod> _executorPeriods = [];
  
  // Notas SAP vinculadas
  List<NotaSAP> _notasSAPVinculadas = [];
  bool _isLoadingNotasSAP = false;

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    
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
      print('📋 TaskFormDialog: Carregados ${_executorPeriods.length} períodos por executor');
      for (var ep in _executorPeriods) {
        print('   - Executor: ${ep.executorNome} (${ep.periods.length} períodos)');
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
      _dataInicio = widget.startDate;
      _dataFim = widget.endDate;
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
      
      // Carregar notas SAP vinculadas (apenas para tarefas existentes)
      if (widget.task != null) {
        _loadNotasSAP();
      }
    });
  }
  
  Future<void> _loadNotasSAP() async {
    if (widget.task == null) return;
    
    setState(() {
      _isLoadingNotasSAP = true;
    });
    
    try {
      final notas = await _notaSAPService.getNotasPorTarefa(widget.task!.id);
      setState(() {
        _notasSAPVinculadas = notas;
        _isLoadingNotasSAP = false;
      });
    } catch (e) {
      print('❌ Erro ao carregar notas SAP: $e');
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
      print('   Segmentos do Gantt: ${parentTask.ganttSegments.length}');
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
            print('👤 Perfil do usuário carregado: ${_usuarioAtual!.segmentos.length} segmentos');
            print('   Segmentos do perfil: ${_usuarioAtual!.segmentos.join(", ")}');
            print('   IDs dos segmentos: ${_segmentoIdsPerfil.join(", ")}');
          } else if (_usuarioAtual != null && _usuarioAtual!.isRoot) {
            print('👤 Usuário root: sem filtro de segmentos');
            _segmentoIdsPerfil = []; // Root não tem filtro
          }
        } catch (e) {
          print('⚠️ Erro ao carregar perfil do usuário: $e');
          _segmentoIdsPerfil = []; // Se houver erro, não filtrar
        }
      }
      
      final futures = await Future.wait([
        _statusService.getAllStatus(),
        _regionalService.getAllRegionais(),
        _divisaoService.getAllDivisoes(),
        _localService.getAllLocais(),
        _segmentoService.getAllSegmentos(),
        _equipeService.getEquipesAtivas(),
        _frotaService.getAllFrotas(),
      ]);

      setState(() {
        _statusList = futures[0] as List<Status>;
        _regionaisList = futures[1] as List<Regional>;
        _divisoesList = futures[2] as List<Divisao>;
        _locaisList = futures[3] as List<Local>;
        // Não carregar todos os segmentos aqui - serão carregados quando divisão for selecionada
        _segmentosList = [];
        _equipesList = futures[5] as List<Equipe>;
        final todasFrotas = futures[6] as List<Frota>;
        
        // Filtrar frotas pelo perfil do usuário
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
      final coordenadores = await _executorService.getCoordenadores();
      setState(() {
        _coordenadoresList = coordenadores;
      });
      print('👔 Coordenadores carregados: ${coordenadores.length}');
    } catch (e) {
      print('Erro ao carregar coordenadores: $e');
      setState(() {
        _coordenadoresList = [];
      });
    }
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
                labelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.info_outline, size: 20),
                    text: 'Básicas',
                  ),
                  Tab(
                    icon: Icon(Icons.people_outline, size: 20),
                    text: 'Responsáveis',
                  ),
                  Tab(
                    icon: Icon(Icons.calendar_today, size: 20),
                    text: 'Datas/Horas',
                  ),
                  Tab(
                    icon: Icon(Icons.note_outlined, size: 20),
                    text: 'Observações',
                  ),
                  Tab(
                    icon: Icon(Icons.attach_file, size: 20),
                    text: 'Anexos',
                  ),
                  Tab(
                    icon: Icon(Icons.description, size: 20),
                    text: 'Notas SAP',
                  ),
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
                                // Card: Ordem e Tarefa
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
                                            _buildTextField('Ordem (opcional)', _ordem, (value) => _ordem = value.isEmpty ? null : value),
                                            const SizedBox(height: 16),
                                            _buildTextField('Tarefa', _tarefa, (value) => _tarefa = value, maxLines: 3),
                                          ],
                                        )
                                      : Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(flex: 1, child: _buildTextField('Ordem (opcional)', _ordem, (value) => _ordem = value.isEmpty ? null : value)),
                                            const SizedBox(width: 16),
                                            Expanded(flex: 2, child: _buildTextField('Tarefa', _tarefa, (value) => _tarefa = value, maxLines: 3)),
                                          ],
                                        ),
                                ),
                              ],
                            ),
                    ),
                    // Aba 2: Responsáveis
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildExecutorEquipeDropdown(),
                          const SizedBox(height: 12),
                          _buildCoordenadorDropdown(),
                          const SizedBox(height: 12),
                          _buildFrotaDropdown(),
                          const SizedBox(height: 12),
                          _buildTextField('SI', _si, (value) => _si = value),
                        ],
                      ),
                    ),
                    // Aba 3: Datas e Horas (Períodos de Execução)
                    SingleChildScrollView(
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
                    // Aba 4: Observações
                    SingleChildScrollView(
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
                    // Aba 5: Anexos (apenas para tarefas existentes)
                    widget.task != null
                        ? SingleChildScrollView(
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
                                      Icon(
                                        Icons.info_outline,
                                        size: 48,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Salve a tarefa primeiro',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Após criar a tarefa, você poderá adicionar anexos (imagens, vídeos e documentos).',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                    // Aba 6: Notas SAP (apenas para tarefas existentes)
                    widget.task != null
                        ? _buildNotasSAPSection()
                        : SingleChildScrollView(
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
                                      Icon(
                                        Icons.info_outline,
                                        size: 48,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Salve a tarefa primeiro',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Após criar a tarefa, você poderá vincular notas SAP.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
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
    
    return _buildSearchableDropdown<Status>(
      label: 'Status',
      value: statusValue,
      items: _statusList,
      getDisplayText: (status) => status.status,
      onChanged: (Status? value) {
        setState(() {
          _selectedStatus = value;
          if (value != null) {
            _status = value.codigo;
            _statusId = value.id;
          }
        });
      },
      validator: (value) {
        if (value == null) {
          return 'Selecione um status';
        }
        return null;
      },
      hintText: 'Digite para buscar status...',
      isRequired: true,
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

  Widget _buildFrotaDropdown() {
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

      final task = Task(
        id: widget.task?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        statusId: _statusId,
        regionalId: _regionalId,
        divisaoId: _divisaoId,
        segmentoId: _segmentoId,
        localIds: _selectedLocalIds.toList(),
        executorIds: _tipoExecutorEquipe == 'executor' ? _selectedExecutorIds.toList() : [],
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
        frota: _selectedFrota != null ? '${_selectedFrota!.nome} - ${_selectedFrota!.placa}' : (_frota.isNotEmpty && _frota != '-N/A-' ? _frota : ''),
        coordenador: _coordenador,
        si: _si,
        dataInicio: _dataInicio,
        dataFim: _dataFim,
        ganttSegments: ganttSegments,
        executorPeriods: _executorPeriods,
        observacoes: _observacoes,
        horasPrevistas: _horasPrevistas,
        horasExecutadas: _horasExecutadas,
        prioridade: null,
        parentId: widget.parentTaskId ?? widget.task?.parentId,
      );

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
              DropdownButtonFormField<Equipe>(
                value: _equipesList.isEmpty || 
                    (_selectedEquipe != null && !_equipesList.any((e) => e.id == _selectedEquipe!.id))
                    ? null
                    : _selectedEquipe,
                decoration: const InputDecoration(
                  labelText: 'Equipe *',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<Equipe>(
                    value: null,
                    child: Text('Selecione uma equipe'),
                  ),
                  if (_equipesList.isEmpty)
                    const DropdownMenuItem<Equipe>(
                      value: null,
                      enabled: false,
                      child: Text('Nenhuma equipe disponível para os filtros selecionados'),
                    )
                  else
                    ..._equipesList.map((equipe) {
                      return DropdownMenuItem<Equipe>(
                        value: equipe,
                        child: Tooltip(
                          message: equipe.executores.map((e) => '${e.executorNome} (${e.papel})').join('\n'),
                          child: Text(equipe.nome),
                        ),
                      );
                    }),
                ],
                onChanged: _equipesList.isEmpty ? null : (Equipe? value) {
                  setState(() {
                    _selectedEquipe = value;
                    if (value != null) {
                      _selectedEquipeIds = {value.id};
                      _usarEquipe = true;
                      _executor = '';
                      _selectedExecutorIds.clear();
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
              if (_equipesList.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Nenhuma equipe disponível para os filtros selecionados.',
                    style: TextStyle(fontSize: 12, color: Colors.orange[700]),
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
                        final baseSegment = _ganttSegments.isNotEmpty 
                            ? _ganttSegments.first 
                            : GanttSegment(
                                dataInicio: _dataInicio,
                                dataFim: _dataFim,
                                label: _tarefa,
                                tipo: _mapTaskTypeToSegmentType(_tipo),
                                tipoPeriodo: 'EXECUCAO',
                              );
                        
                        _executorPeriods.add(
                          ExecutorPeriod(
                            executorId: executorId,
                            executorNome: executor.nome,
                            periods: [baseSegment],
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
                    
                    final baseSegment = _ganttSegments.isNotEmpty 
                        ? _ganttSegments.first 
                        : GanttSegment(
                            dataInicio: _dataInicio,
                            dataFim: _dataFim,
                            label: _tarefa,
                            tipo: _mapTaskTypeToSegmentType(_tipo),
                            tipoPeriodo: 'EXECUCAO',
                          );
                    
                    _executorPeriods.add(
                      ExecutorPeriod(
                        executorId: executorId,
                        executorNome: executor.nome,
                        periods: [baseSegment],
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
                          // Adicionar período baseado no primeiro segmento geral
                          final baseSegment = _ganttSegments.isNotEmpty 
                              ? _ganttSegments.first 
                              : GanttSegment(
                                  dataInicio: _dataInicio,
                                  dataFim: _dataFim,
                                  label: _tarefa,
                                  tipo: _mapTaskTypeToSegmentType(_tipo),
                                  tipoPeriodo: 'EXECUCAO',
                                );
                          
                          _executorPeriods[index] = executorPeriod.copyWith(
                            periods: [baseSegment],
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
                        final newEnd = newStart.add(const Duration(days: 1));
                        
                        final newPeriod = GanttSegment(
                          dataInicio: newStart,
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
            // DateRangePicker para o período
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
                    final periods = List<GanttSegment>.from(executorPeriod.periods);
                    periods[periodIndex] = segment.copyWith(
                      dataInicio: picked.start,
                      dataFim: picked.end,
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
                      '${segment.dataInicio.day}/${segment.dataInicio.month}/${segment.dataInicio.year} - ${segment.dataFim.day}/${segment.dataFim.month}/${segment.dataFim.year}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    'Tipo',
                    segment.tipo,
                    const ['BEA', 'FER', 'COMP', 'TRN', 'BSL', 'APO', 'OUT', 'ADM'],
                    (value) {
                      setState(() {
                        final periods = List<GanttSegment>.from(executorPeriod.periods);
                        periods[periodIndex] = segment.copyWith(tipo: value);
                        _executorPeriods[executorIndex] = executorPeriod.copyWith(periods: periods);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDropdown(
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
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    'Tipo de Atividade',
                    segment.tipo,
                    const ['BEA', 'FER', 'COMP', 'TRN', 'BSL', 'APO', 'OUT', 'ADM'],
                    (value) {
                      setState(() {
                        _ganttSegments[index] = segment.copyWith(tipo: value);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdown(
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
                ),
              ],
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
                onPressed: () => _adicionarNotaSAP(),
                icon: const Icon(Icons.add),
                label: const Text('Adicionar Nota'),
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
                      backgroundColor: nota.statusSistema?.contains('MSPR') == true
                          ? Colors.orange
                          : nota.statusSistema?.contains('MSPN') == true
                              ? Colors.blue
                              : Colors.grey,
                      child: Text(
                        nota.tipo ?? '?',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    title: Text('Nota: ${nota.nota}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (nota.descricao != null)
                          Text(
                            nota.descricao!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (nota.localInstalacao != null)
                          Text(
                            'Local: ${nota.localInstalacao}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        if (nota.criadoEm != null)
                          Text(
                            'Criado: ${_formatDateNotaSAP(nota.criadoEm!)}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
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
  
  Future<void> _adicionarNotaSAP() async {
    if (widget.task == null) return;
    
    // Buscar todas as notas disponíveis
    final todasNotas = await _notaSAPService.getAllNotas(limit: 1000);
    
    // Filtrar notas já vinculadas
    final notasDisponiveis = todasNotas
        .where((n) => !_notasSAPVinculadas.any((v) => v.id == n.id))
        .toList();
    
    if (notasDisponiveis.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Todas as notas já estão vinculadas ou não há notas disponíveis'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    
    // Mostrar diálogo para selecionar nota
    final notaSelecionada = await showDialog<NotaSAP>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Selecionar Nota SAP'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: notasDisponiveis.length,
            itemBuilder: (context, index) {
              final nota = notasDisponiveis[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: nota.statusSistema?.contains('MSPR') == true
                      ? Colors.orange
                      : nota.statusSistema?.contains('MSPN') == true
                          ? Colors.blue
                          : Colors.grey,
                  child: Text(
                    nota.tipo ?? '?',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
                title: Text('Nota: ${nota.nota}'),
                subtitle: nota.descricao != null
                    ? Text(
                        nota.descricao!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      )
                    : null,
                onTap: () => Navigator.of(context).pop(nota),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
    
    if (notaSelecionada != null) {
      try {
        await _notaSAPService.vincularNotaATarefa(widget.task!.id, notaSelecionada.id);
        await _loadNotasSAP();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Nota ${notaSelecionada.nota} vinculada com sucesso'),
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
}

