import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert' show utf8;
import 'dart:html' as html;
import 'dart:typed_data' show Uint8List;
import 'package:excel/excel.dart';
import 'data/mock_data.dart';
import 'models/task.dart';
import 'services/task_service.dart';
import 'config/supabase_config.dart';
import 'widgets/header_bar.dart';
import 'widgets/filter_bar.dart';
import 'widgets/sidebar.dart';
import 'widgets/task_table.dart';
import 'widgets/gantt_chart.dart';
import 'widgets/task_cards_view.dart';
import 'widgets/planner_view.dart';
import 'widgets/task_form_dialog.dart';
import 'widgets/task_view_dialog.dart';
import 'widgets/dashboard.dart';
import 'widgets/team_schedule_view.dart';
import 'services/executor_service.dart';
import 'widgets/fleet_schedule_view.dart';
import 'services/frota_service.dart';
import 'widgets/documents_view.dart';
import 'widgets/advanced_list_view.dart';
import 'widgets/analytics_view.dart';
import 'widgets/planning_view.dart';
import 'widgets/alerts_view.dart';
import 'widgets/maintenance_history_view.dart';
import 'widgets/maintenance_calendar_view.dart';
import 'widgets/maintenance_checklist_view.dart';
import 'widgets/cost_management_view.dart';
import 'widgets/configuracao_view.dart';
import 'widgets/chat_view.dart';
import 'widgets/notas_sap_view.dart';
import 'widgets/login_screen.dart';
import 'services/auth_service_simples.dart';
import 'utils/responsive.dart';

import 'services/local_database_service.dart';
import 'services/sync_service.dart';
import 'services/connectivity_service.dart';
import 'providers/theme_provider.dart';
import 'services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar banco de dados local
  try {
    await LocalDatabaseService().database;
    print('✅ Banco de dados local inicializado!');
  } catch (e) {
    print('⚠️ Erro ao inicializar banco local: $e');
  }
  
  // Inicializar serviço de conectividade
  try {
    await ConnectivityService().initialize();
    print('✅ Serviço de conectividade inicializado!');
  } catch (e) {
    print('⚠️ Erro ao inicializar conectividade: $e');
  }
  
  // Inicializar Supabase
  try {
    await SupabaseConfig.initialize();
    print('✅ Supabase inicializado com sucesso!');
  } catch (e) {
    print('⚠️ Erro ao inicializar Supabase: $e');
    print('📝 O app continuará funcionando offline');
  }
  
  // Inicializar serviço de sincronização
  try {
    await SyncService().initialize();
    print('✅ Serviço de sincronização inicializado!');
  } catch (e) {
    print('⚠️ Erro ao inicializar sincronização: $e');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ThemeProvider _themeProvider = ThemeProvider();

  @override
  void initState() {
    super.initState();
    // Carregar tema ao iniciar
    _themeProvider.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _themeProvider.removeListener(_onThemeChanged);
    _themeProvider.dispose();
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _themeProvider,
      builder: (context, child) {
        return MaterialApp(
          title: 'Task Flow',
          theme: _themeProvider.themeData,
          themeMode: ThemeMode.light, // Usar sempre o tema escolhido, não seguir o sistema
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('pt', 'BR'),
            Locale('en', 'US'),
          ],
          locale: const Locale('pt', 'BR'),
          home: AuthWrapper(themeProvider: _themeProvider),
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
        // Capturar erros de renderização
        ErrorWidget.builder = (FlutterErrorDetails details) {
          print('❌ Erro de renderização: ${details.exception}');
          print('Stack trace: ${details.stack}');
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Erro ao renderizar',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      details.exception.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      // Tentar recarregar
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => AuthWrapper(themeProvider: _themeProvider)),
                      );
                    },
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
          );
        };
        return child!;
      },
        );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  final ThemeProvider? themeProvider;
  
  const AuthWrapper({super.key, this.themeProvider});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthServiceSimples _authService = AuthServiceSimples();
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    setState(() {
      _isAuthenticated = _authService.isAuthenticated;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_isAuthenticated) {
      return LoginScreen(
        onLoginSuccess: () {
          setState(() {
            _isAuthenticated = true;
          });
        },
      );
    }

    return MainScreen(
      themeProvider: widget.themeProvider,
      onLogout: () {
        setState(() {
          _isAuthenticated = false;
        });
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  final ThemeProvider? themeProvider;
  final VoidCallback? onLogout;
  
  const MainScreen({super.key, this.themeProvider, this.onLogout});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final ScrollController _tableScrollController = ScrollController();
  final ScrollController _ganttScrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TaskService _taskService = TaskService();
  final ExecutorService _executorService = ExecutorService();
  final FrotaService _frotaService = FrotaService();
  final AuthServiceSimples _authService = AuthServiceSimples();
  
  List<Task> _tasks = []; // Inicializar com lista vazia
  Task? _selectedTask; // Tarefa selecionada para edição/deleção
  Map<String, String?> _currentFilters = {}; // Filtros ativos
  String _searchQuery = ''; // Termo de busca atual
  // Inicializar com primeiro e último dia do mês/ano atual
  late DateTime _startDate;
  late DateTime _endDate;
  int _selectedTab = 0; // Para mobile: 0 = Tabela, 1 = Gantt, 2 = Planner, 3 = Calendário, 4 = Feed
  String _viewMode = 'split'; // 'split', 'table', 'gantt', 'planner', 'calendar', 'feed'
  bool _sidebarExpanded = false; // Estado da sidebar (expandida/retraída)
  int _sidebarSelectedIndex = 0; // Índice selecionado na sidebar (0 = Grid/Tabela)
  bool _allSubtasksExpanded = false; // Estado compartilhado: todas as subtarefas expandidas ou colapsadas
  Set<String> _expandedTasks = {}; // IDs das tarefas expandidas (compartilhado entre tabela e Gantt)
  int _tasksVersion = 0; // Versão das tarefas para forçar rebuild quando necessário
  bool _showGantt = true; // Controla se o Gantt está visível
  bool _isFiltering = false; // Estado de processamento de filtros
  
  // Cache para executores do usuário (otimização de performance)
  Set<String>? _cachedExecutorIds;
  Set<String>? _cachedExecutorNomes;
  String? _cachedLoginUsuario;

  void _toggleAllSubtasks() {
    setState(() {
      _allSubtasksExpanded = !_allSubtasksExpanded;
      
      // Obter todas as tarefas principais que têm subtarefas ou períodos por executor
      final mainTasks = _tasks.where((t) => t.parentId == null).toList();
      final tasksToToggle = <String>[];
      
      // Verificar tarefas com períodos por executor
      for (var task in mainTasks) {
        if (task.executorPeriods.isNotEmpty) {
          tasksToToggle.add(task.id);
        }
      }
      
      // Atualizar estado de expansão
      if (_allSubtasksExpanded) {
        // Expandir todas
        _expandedTasks.addAll(tasksToToggle);
      } else {
        // Colapsar todas
        _expandedTasks.removeAll(tasksToToggle);
      }
    });
  }

  void _onTaskExpanded(String taskId, bool isExpanded) {
    print('🔄 DEBUG main: _onTaskExpanded chamado - taskId: ${taskId.substring(0, 8)}, isExpanded: $isExpanded');
    print('   Estado antes: ${_expandedTasks.toList()}');
    
    setState(() {
      // Criar um novo Set para forçar rebuild dos widgets (nova referência)
      final newExpandedTasks = Set<String>.from(_expandedTasks);
      if (isExpanded) {
        newExpandedTasks.add(taskId);
      } else {
        newExpandedTasks.remove(taskId);
      }
      // Substituir completamente o Set para que os widgets detectem a mudança
      _expandedTasks = newExpandedTasks;
      // Incrementar versão para forçar rebuild
      _tasksVersion++;
      
      print('   Estado depois: ${_expandedTasks.toList()}');
      print('   _tasksVersion: $_tasksVersion');
    });
  }

  @override
  void initState() {
    super.initState();
    // Inicializar datas com primeiro e último dia do mês/ano atual
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0); // Último dia do mês atual
    
    // Carregar tarefas (do Supabase ou mock)
    _loadTasks();
    
    // Sincronizar scroll entre tabela e Gantt
    _tableScrollController.addListener(() {
      if (_ganttScrollController.hasClients && _tableScrollController.hasClients) {
        final offset = _tableScrollController.offset;
        if ((_ganttScrollController.offset - offset).abs() > 1.0) {
          _ganttScrollController.jumpTo(offset);
        }
      }
    });
    
    _ganttScrollController.addListener(() {
      if (_tableScrollController.hasClients && _ganttScrollController.hasClients) {
        final offset = _ganttScrollController.offset;
        if ((_tableScrollController.offset - offset).abs() > 1.0) {
          _tableScrollController.jumpTo(offset);
        }
      }
    });
  }

  @override
  void dispose() {
    _tableScrollController.dispose();
    _ganttScrollController.dispose();
    super.dispose();
  }

  // Função para ordenar tarefas por período (data de início e fim)
  // Estado de ordenação
  String _sortColumn = 'PERÍODO'; // Coluna padrão: PERÍODO
  bool _sortAscending = true; // Direção padrão: crescente
  
  List<Task> _sortTasks(List<Task> tasks) {
    if (tasks.isEmpty) return [];
    final sortedTasks = List<Task>.from(tasks);
    
    sortedTasks.sort((a, b) {
      int comparison = 0;
      
      switch (_sortColumn) {
        case 'PERÍODO':
          // Obter o primeiro segmento de cada tarefa (ou usar dataInicio/dataFim da tarefa se não houver segmentos)
          DateTime aStart, aEnd, bStart, bEnd;
          
          if (a.ganttSegments.isNotEmpty) {
            aStart = a.ganttSegments.first.dataInicio;
            aEnd = a.ganttSegments.first.dataFim;
          } else {
            aStart = a.dataInicio;
            aEnd = a.dataFim;
          }
          
          if (b.ganttSegments.isNotEmpty) {
            bStart = b.ganttSegments.first.dataInicio;
            bEnd = b.ganttSegments.first.dataFim;
          } else {
            bStart = b.dataInicio;
            bEnd = b.dataFim;
          }
          
          // Primeiro ordenar por data de início
          comparison = aStart.compareTo(bStart);
          if (comparison != 0) {
            return _sortAscending ? comparison : -comparison;
          }
          
          // Se as datas de início forem iguais, ordenar por data de fim
          comparison = aEnd.compareTo(bEnd);
          break;
          
        case 'STATUS':
          final statusA = a.statusNome.isNotEmpty ? a.statusNome : a.status;
          final statusB = b.statusNome.isNotEmpty ? b.statusNome : b.status;
          comparison = statusA.compareTo(statusB);
          break;
          
        case 'LOCAL':
          final localA = a.locais.isNotEmpty ? a.locais.first : '';
          final localB = b.locais.isNotEmpty ? b.locais.first : '';
          comparison = localA.compareTo(localB);
          break;
          
        case 'TIPO':
          comparison = a.tipo.compareTo(b.tipo);
          break;
          
        case 'TAREFA':
          comparison = a.tarefa.compareTo(b.tarefa);
          break;
          
        case 'EXECUTOR':
          comparison = a.executor.compareTo(b.executor);
          break;
          
        case 'COORDENADOR':
          comparison = a.coordenador.compareTo(b.coordenador);
          break;
          
        default:
          // Fallback para período
          comparison = a.dataInicio.compareTo(b.dataInicio);
      }
      
      return _sortAscending ? comparison : -comparison;
    });
    
    return sortedTasks;
  }

  // Obter valor da coluna de ordenação para uma tarefa
  String _getSortValue(Task task) {
    switch (_sortColumn) {
      case 'STATUS':
        final value = task.statusNome.isNotEmpty ? task.statusNome : task.status;
        return value.isNotEmpty ? value : 'SEM STATUS';
      case 'LOCAL':
        final value = task.locais.isNotEmpty ? task.locais.first : '';
        return value.isNotEmpty ? value : 'SEM LOCAL';
      case 'TIPO':
        return task.tipo.isNotEmpty ? task.tipo : 'SEM TIPO';
      case 'TAREFA':
        return task.tarefa.isNotEmpty ? task.tarefa : 'SEM TAREFA';
      case 'EXECUTOR':
        return task.executor.isNotEmpty ? task.executor : 'SEM EXECUTOR';
      case 'COORDENADOR':
        return task.coordenador.isNotEmpty ? task.coordenador : 'SEM COORDENADOR';
      default:
        return '';
    }
  }
  
  // Getter para obter tarefas ordenadas
  List<Task> get _sortedTasks {
    if (_tasks.isEmpty) return [];
    return _sortTasks(_tasks);
  }
  
  // Método para atualizar ordenação
  void _updateSorting(String column, bool ascending) {
    print('🔄 main.dart: _updateSorting chamado - column=$column, ascending=$ascending');
    setState(() {
      _sortColumn = column;
      _sortAscending = ascending;
    });
    print('🔄 main.dart: _sortColumn atualizado para $_sortColumn');
  }

  // Carregar tarefas do Supabase ou mock
  Future<void> _loadTasks() async {
    try {
      // Tentar carregar do Supabase primeiro
      // O TaskService já aplica os filtros de perfil automaticamente
      final tasks = await _taskService.getAllTasks();
      if (mounted) {
        setState(() {
          _tasks = tasks;
          _tasksVersion++; // Incrementar versão para forçar rebuild dos widgets
          print('✅ Tarefas carregadas: ${tasks.length} (versão: $_tasksVersion)');
          
          // Verificar perfil do usuário
          final authService = AuthServiceSimples();
          final usuario = authService.currentUser;
          if (usuario != null) {
            if (usuario.temPerfilConfigurado()) {
              print('🔒 Usuário tem perfil configurado: ${usuario.regionais.length} regionais, ${usuario.divisoes.length} divisões, ${usuario.segmentos.length} segmentos');
            } else {
              print('⚠️ Usuário SEM perfil configurado - nenhuma tarefa será exibida');
            }
          } else {
            print('⚠️ Usuário não autenticado - nenhuma tarefa será exibida');
          }
          
          // Verificar segmentos do Gantt
          for (var task in tasks) {
            if (task.ganttSegments.isNotEmpty) {
              print('📊 Tarefa ${task.id} tem ${task.ganttSegments.length} segmentos');
            }
          }
        });
      }
    } catch (e) {
      // Se falhar, usar dados mock
      print('⚠️ Erro ao carregar do Supabase, usando dados mock: $e');
      _taskService.initializeWithMockData(MockData.getTasks());
      if (mounted) {
        setState(() {
          // Fallback para mock (síncrono)
          _tasks = [];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      final isMobile = Responsive.isMobile(context);
      final isTablet = Responsive.isTablet(context);
      final isDesktop = Responsive.isDesktop(context);

      print('🔵 MainScreen build - isMobile: $isMobile, isTablet: $isTablet, isDesktop: $isDesktop');
      print('   _sidebarSelectedIndex: $_sidebarSelectedIndex');
      print('   _tasks.length: ${_tasks.length}');

      return Scaffold(
      key: _scaffoldKey,
      drawer: isMobile ? _buildDrawer() : null,
      endDrawer: !isMobile ? _buildDrawer() : null,
      body: isMobile
          ? SafeArea(
              bottom: true,
              child: Column(
                children: [
                  // Header Bar
                  HeaderBar(
                    startDate: _startDate,
                    endDate: _endDate,
                    onDateRangeChanged: (start, end) {
                      setState(() {
                        _startDate = start;
                        _endDate = end;
                        _applyFilters(_currentFilters);
                      });
                    },
                    onCreate: () => _createTask(),
                    onEdit: () => _editTask(),
                    onDelete: () => _deleteTask(),
                    onCreateSubtask: _selectedTask != null && _selectedTask!.isMainTask
                        ? () => _createSubtask(_selectedTask!.id)
                        : null,
                    onMenuPressed: () {
                      _scaffoldKey.currentState?.openDrawer();
                    },
                    onLogout: _handleLogout,
                    onSearch: _searchTasks,
                    onChat: () {
                      setState(() {
                        _sidebarSelectedIndex = 15;
                      });
                    },
                    onConfig: () {
                      setState(() {
                        _sidebarSelectedIndex = 14;
                      });
                    },
                    onPerfilUpdated: () {
                      // Recarregar tarefas quando o perfil for atualizado
                      _applyFilters(_currentFilters);
                    },
                    onViewModeChanged: (mode) {
                      setState(() {
                        _viewMode = mode;
                        // Sincronizar _selectedTab com _viewMode para mobile
                        if (mode == 'planner') {
                          _selectedTab = 2;
                        } else if (mode == 'calendar') {
                          _selectedTab = 3;
                        } else if (mode == 'feed') {
                          _selectedTab = 4;
                        } else if (mode == 'split') {
                          _selectedTab = 0; // Default para tabela
                        }
                      });
                    },
                    currentViewMode: _viewMode,
                    onToggleGantt: () {
                      setState(() {
                        _showGantt = !_showGantt;
                      });
                    },
                    showGantt: _showGantt,
                    isAtividadesScreen: _sidebarSelectedIndex == 0,
                  ),
                  // Filter Bar (mobile - ocultar em Configurações e Chat)
                  if (_sidebarSelectedIndex != 14 && _sidebarSelectedIndex != 15)
                    FilterBar(
                      onFiltersChanged: _applyFilters,
                      initialFilters: _currentFilters,
                      startDate: _startDate,
                      endDate: _endDate,
                      onSortChanged: _updateSorting,
                      currentSortColumn: _sortColumn,
                      currentSortAscending: _sortAscending,
                      isFiltering: _isFiltering,
                    ),
                  // Main Content
                  Expanded(
                    child: _buildMainContent(isMobile, isTablet, isDesktop),
                  ),
                  // Footbar para mobile/tablet (botões de visualização)
                  if ((isMobile || isTablet) && _sidebarSelectedIndex == 0) ...[
                    Builder(
                      builder: (context) {
                        print('🔵 Renderizando footbar - isMobile: $isMobile, isTablet: $isTablet, _sidebarSelectedIndex: $_sidebarSelectedIndex');
                        return _buildFootbar(isMobile);
                      },
                    ),
                  ],
                ],
              ),
            )
          : Row(
              children: [
                // Sidebar sempre visível no desktop/tablet
                Sidebar(
                  isExpanded: _sidebarExpanded,
                  onToggle: () {
                    setState(() {
                      _sidebarExpanded = !_sidebarExpanded;
                    });
                  },
                  selectedIndex: _sidebarSelectedIndex,
                  onItemSelected: (index) {
                    setState(() {
                      _sidebarSelectedIndex = index;
                    });
                  },
                  onExport: _exportData,
                  isRoot: _authService.currentUser?.isRoot ?? false,
                ),
                // Conteúdo principal (Header, Filter, Main Content)
                Expanded(
        child: Column(
                    children: [
                      // Header Bar
                      HeaderBar(
                        startDate: _startDate,
                        endDate: _endDate,
                        onDateRangeChanged: (start, end) {
                          setState(() {
                            _startDate = start;
                            _endDate = end;
                            _applyFilters(_currentFilters);
                          });
                        },
                        onCreate: () => _createTask(),
                        onEdit: () => _editTask(),
                        onDelete: () => _deleteTask(),
                        onMenuPressed: () {
                          _scaffoldKey.currentState?.openEndDrawer();
                        },
                        onLogout: _handleLogout,
                        onSearch: _searchTasks,
                        onChat: () {
                          setState(() {
                            _sidebarSelectedIndex = 15;
                          });
                        },
                        onConfig: () {
                          setState(() {
                            _sidebarSelectedIndex = 14;
                          });
                        },
                        onPerfilUpdated: () {
                          // Recarregar tarefas quando o perfil for atualizado
                          _applyFilters(_currentFilters);
                        },
                        onViewModeChanged: (mode) {
                          setState(() {
                            _viewMode = mode;
                            // Sincronizar _selectedTab com _viewMode para mobile
                            if (mode == 'planner') {
                              _selectedTab = 2;
                            } else if (mode == 'calendar') {
                              _selectedTab = 3;
                            } else if (mode == 'feed') {
                              _selectedTab = 4;
                            } else if (mode == 'split') {
                              _selectedTab = 0; // Default para tabela
                            }
                          });
                        },
                        currentViewMode: _viewMode,
                        onToggleGantt: () {
                          setState(() {
                            _showGantt = !_showGantt;
                          });
                        },
                        showGantt: _showGantt,
                        isAtividadesScreen: _sidebarSelectedIndex == 0,
                      ),
                      // Filter Bar (ocultar em Configurações e Chat)
                      if (_sidebarSelectedIndex != 14 && _sidebarSelectedIndex != 15)
                        FilterBar(
                          onFiltersChanged: _applyFilters,
                          initialFilters: _currentFilters,
                          startDate: _startDate,
                          endDate: _endDate,
                          onSortChanged: _updateSorting,
                          currentSortColumn: _sortColumn,
                          currentSortAscending: _sortAscending,
                          isFiltering: _isFiltering,
                        ),
                      // Main Content
                      Expanded(
                        child: _buildMainContent(isMobile, isTablet, isDesktop),
                      ),
                      // Footbar para mobile/tablet (botões de visualização)
                      if ((isMobile || isTablet) && _sidebarSelectedIndex == 0) ...[
                        Builder(
                          builder: (context) {
                            print('🔵 Renderizando footbar (desktop) - isMobile: $isMobile, isTablet: $isTablet, _sidebarSelectedIndex: $_sidebarSelectedIndex');
                            return _buildFootbar(isMobile);
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
      );
    } catch (e, stackTrace) {
      print('❌ ERRO CRÍTICO no build do MainScreen: $e');
      print('Stack trace: $stackTrace');
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Erro ao carregar aplicação',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  e.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  widget.onLogout?.call();
                },
                child: const Text('Fazer logout'),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildMainContent(bool isMobile, bool isTablet, bool isDesktop) {
    try {
      if (isMobile) {
        // Mobile: Se não for a view padrão (Grid), mostrar view específica
        if (_sidebarSelectedIndex != 0 && _sidebarSelectedIndex != 3) {
          return _getViewBySidebarIndex();
        }
        
        // Mobile: Layout com conteúdo (botões de visualização estão no footbar)
        return _buildMobileContentStack();
      } else if (isTablet) {
        // Tablet: Layout vertical ou views específicas
        if (_sidebarSelectedIndex == 0) {
          // Usar _selectedTab para determinar qual view mostrar no tablet também
          print('🔵 Tablet: _selectedTab = $_selectedTab, _viewMode = $_viewMode');
          return _buildMobileContentStack();
        }
        return _getViewBySidebarIndex();
      } else {
      // Desktop: Layout horizontal (original) ou views específicas
      if (_sidebarSelectedIndex == 0) {
        // Se o modo for 'planner', mostrar apenas o PlannerView
        if (_viewMode == 'planner') {
          return PlannerView(
            tasks: _sortedTasks,
            taskService: _taskService,
            onTasksUpdated: () async {
              print('🔄 GanttChart onTasksUpdated: Recarregando tarefas...');
              await _loadTasks();
              // Reaplicar filtros após recarregar para garantir que todas as views sejam atualizadas
              if (_currentFilters.isNotEmpty) {
                print('🔄 Reaplicando filtros após atualização do GanttChart...');
                await _applyFilters(_currentFilters);
              } else {
                // Mesmo sem filtros, garantir que as tarefas sejam atualizadas
                setState(() {
                  _tasksVersion++;
                });
              }
              print('✅ Tarefas recarregadas após atualização do GanttChart');
            },
            onTaskSelected: (task) => _showTaskDetails(task),
            onEdit: (task) => _editTaskById(task.id),
            onDelete: (task) => _deleteTaskById(task.id),
            onDuplicate: (task) => _duplicateTask(task),
            onCreateSubtask: (task) {
              if (task.isMainTask) {
                _createSubtask(task.id);
              }
            },
          );
        }
        // Se o modo for 'calendar', mostrar apenas o Calendário
        if (_viewMode == 'calendar') {
          return MaintenanceCalendarView(
            taskService: _taskService,
            filteredTasks: _tasks, // Passar tarefas filtradas
            onEdit: (task) => _editTaskById(task.id),
            onDelete: (task) => _deleteTaskById(task.id),
            onDuplicate: (task) => _duplicateTask(task),
            onCreateSubtask: (task) {
              if (task.isMainTask) {
                _createSubtask(task.id);
              }
            },
          );
        }
        // Se o modo for 'feed', mostrar apenas o Feed
        if (_viewMode == 'feed') {
          return TaskCardsView(
            key: ValueKey('feed_${_tasksVersion}_${_sortedTasks.length}'),
            tasks: _sortedTasks,
            onEdit: (task) => _editTaskById(task.id),
            onDelete: (task) => _deleteTaskById(task.id),
            onDuplicate: (task) => _duplicateTask(task),
            onCreateSubtask: (task) {
              if (task.isMainTask) {
                _createSubtask(task.id);
              }
            },
          );
        }
        // Caso contrário, mostrar Tabela e Gantt (ou apenas Tabela se _showGantt for false)
        if (!_showGantt) {
          return TaskTable(
            key: ValueKey('task_table_$_tasksVersion'),
            tasks: _sortedTasks,
            scrollController: _tableScrollController,
            taskService: _taskService,
            allSubtasksExpanded: _allSubtasksExpanded,
            onToggleAllSubtasks: _toggleAllSubtasks,
            expandedTasks: _expandedTasks,
            onTaskExpanded: _onTaskExpanded,
            sortColumn: _sortColumn,
            getSortValue: _getSortValue,
            onTaskSelected: (task) {
              _showTaskDetails(task);
            },
            onEdit: (task) => _editTaskById(task.id),
            onDelete: (task) => _deleteTaskById(task.id),
            onDuplicate: (task) => _duplicateTask(task),
            onCreateSubtask: (task) {
              if (task.isMainTask) {
                _createSubtask(task.id);
              }
            },
          );
        }
        return Row(
          children: [
            Expanded(
              flex: 1,
              child: TaskTable(
                key: ValueKey('task_table_$_tasksVersion'),
                tasks: _sortedTasks,
                scrollController: _tableScrollController,
                taskService: _taskService,
                allSubtasksExpanded: _allSubtasksExpanded,
                onToggleAllSubtasks: _toggleAllSubtasks,
                expandedTasks: _expandedTasks,
                onTaskExpanded: _onTaskExpanded,
                sortColumn: _sortColumn,
                getSortValue: _getSortValue,
                onTaskSelected: (task) {
                  _showTaskDetails(task);
                },
                onEdit: (task) => _editTaskById(task.id),
                onDelete: (task) => _deleteTaskById(task.id),
                onDuplicate: (task) => _duplicateTask(task),
                onCreateSubtask: (task) {
                  if (task.isMainTask) {
                    _createSubtask(task.id);
                  }
                },
              ),
            ),
            Expanded(
              flex: 1,
              child: GanttChart(
                key: ValueKey('gantt_chart_${_tasksVersion}_${_expandedTasks.length}_${_expandedTasks.toList()..sort()}'),
                tasks: _sortedTasks,
                startDate: _startDate,
                endDate: _endDate,
                scrollController: _ganttScrollController,
                taskService: _taskService,
                allSubtasksExpanded: _allSubtasksExpanded,
                onToggleAllSubtasks: _toggleAllSubtasks,
                expandedTasks: _expandedTasks,
                onTaskExpanded: _onTaskExpanded,
                sortColumn: _sortColumn,
                getSortValue: _getSortValue,
                onTasksUpdated: () async {
                  print('🔄 GanttChart onTasksUpdated: Recarregando tarefas...');
                  await _loadTasks();
                  // Reaplicar filtros após recarregar para garantir que todas as views sejam atualizadas
                  if (_currentFilters.isNotEmpty) {
                    print('🔄 Reaplicando filtros após atualização do GanttChart...');
                    await _applyFilters(_currentFilters);
                  } else {
                    // Mesmo sem filtros, garantir que as tarefas sejam atualizadas
                    setState(() {
                      _tasksVersion++;
                    });
                  }
                  print('✅ Tarefas recarregadas após atualização do GanttChart');
                },
                onEdit: (task) => _editTaskById(task.id),
                onDelete: (task) => _deleteTaskById(task.id),
                onDuplicate: (task) => _duplicateTask(task),
                onCreateSubtask: (task) {
                  if (task.isMainTask) {
                    _createSubtask(task.id);
                  }
                },
              ),
            ),
          ],
        );
      }
      return _getViewBySidebarIndex();
      }
    } catch (e, stackTrace) {
      print('❌ ERRO em _buildMainContent: $e');
      print('Stack trace: $stackTrace');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Erro ao carregar conteúdo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                e.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _getViewBySidebarIndex() {
    switch (_sidebarSelectedIndex) {
      case 0: // Grid - já tratado acima
        if (!_showGantt) {
          return TaskTable(
            key: ValueKey('task_table_$_tasksVersion'),
            tasks: _sortedTasks,
            scrollController: _tableScrollController,
            taskService: _taskService,
            allSubtasksExpanded: _allSubtasksExpanded,
            onToggleAllSubtasks: _toggleAllSubtasks,
            expandedTasks: _expandedTasks,
            onTaskExpanded: _onTaskExpanded,
            sortColumn: _sortColumn,
            getSortValue: _getSortValue,
            onTaskSelected: (task) {
              setState(() {
                _selectedTask = task;
              });
            },
          );
        }
        return Row(
              children: [
                // Tabela (50% da largura)
                Expanded(
                  flex: 1,
                  child: TaskTable(
                    key: ValueKey('task_table_$_tasksVersion'),
                    tasks: _sortedTasks,
                    scrollController: _tableScrollController,
                    taskService: _taskService,
                    allSubtasksExpanded: _allSubtasksExpanded,
                    onToggleAllSubtasks: _toggleAllSubtasks,
                    expandedTasks: _expandedTasks,
                    onTaskExpanded: _onTaskExpanded,
                    sortColumn: _sortColumn,
                    getSortValue: _getSortValue,
                    onTaskSelected: (task) {
                      setState(() {
                        _selectedTask = task;
                      });
                    },
                  ),
                ),
                // Gantt (50% da largura)
                Expanded(
                  flex: 1,
                  child: GanttChart(
                    key: ValueKey('gantt_chart_${_tasksVersion}_${_expandedTasks.length}_${_expandedTasks.toList()..sort()}'),
                    tasks: _sortedTasks,
                    startDate: _startDate,
                    endDate: _endDate,
                    scrollController: _ganttScrollController,
                    taskService: _taskService,
                    allSubtasksExpanded: _allSubtasksExpanded,
                    onToggleAllSubtasks: _toggleAllSubtasks,
                    sortColumn: _sortColumn,
                    getSortValue: _getSortValue,
                    onEdit: (task) => _editTaskById(task.id),
                    onDelete: (task) => _deleteTaskById(task.id),
                    onDuplicate: (task) => _duplicateTask(task),
                    onCreateSubtask: (task) {
                      if (task.isMainTask) {
                        _createSubtask(task.id);
                      }
                    },
                  ),
                ),
              ],
            );
      case 1: // Pessoas
        return TeamScheduleView(
          taskService: _taskService,
          executorService: _executorService,
          startDate: _startDate,
          endDate: _endDate,
          filteredTasks: _tasks, // Passar tarefas filtradas
          onEdit: (task) => _editTaskById(task.id),
          onDelete: (task) => _deleteTaskById(task.id),
          onDuplicate: (task) => _duplicateTask(task),
          onCreateSubtask: (task) {
            if (task.isMainTask) {
              _createSubtask(task.id);
            }
          },
          onTasksUpdated: () async {
            print('🔄 TeamScheduleView onTasksUpdated: Recarregando tarefas no main.dart...');
            await _loadTasks();
            // Reaplicar filtros após recarregar para garantir que todas as views sejam atualizadas
            if (_currentFilters.isNotEmpty) {
              print('🔄 Reaplicando filtros após atualização do TeamScheduleView...');
              await _applyFilters(_currentFilters);
            } else {
              // Mesmo sem filtros, garantir que as tarefas sejam atualizadas
              setState(() {
                _tasksVersion++;
              });
            }
            print('✅ Tarefas recarregadas após atualização do TeamScheduleView');
          },
        );
      case 2: // Frota
        return FleetScheduleView(
          taskService: _taskService,
          frotaService: _frotaService,
          startDate: _startDate,
          endDate: _endDate,
          filteredTasks: _tasks, // Passar tarefas filtradas
          onTasksUpdated: () async {
            print('🔄 FleetScheduleView onTasksUpdated: Recarregando tarefas...');
            await _loadTasks();
            if (_currentFilters.isNotEmpty) {
              print('🔄 Reaplicando filtros após atualização do FleetScheduleView...');
              await _applyFilters(_currentFilters);
            } else {
              setState(() {
                _tasksVersion++;
              });
            }
            print('✅ Tarefas recarregadas após atualização do FleetScheduleView');
          },
          onEdit: (task) => _editTaskById(task.id),
          onDelete: (task) => _deleteTaskById(task.id),
          onDuplicate: (task) => _duplicateTask(task),
          onCreateSubtask: (task) {
            if (task.isMainTask) {
              _createSubtask(task.id);
            }
          },
        );
      case 4: // Dashboard
        return Dashboard(
          taskService: _taskService,
          filteredTasks: _tasks, // Passar tarefas filtradas
        );
      case 5: // Documento - apenas para root
        final usuario = _authService.currentUser;
        if (usuario != null && usuario.isRoot) {
          return const DocumentsView();
        } else {
          // Se não for root, redirecionar para Atividades
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _sidebarSelectedIndex == 5) {
              setState(() {
                _sidebarSelectedIndex = 0;
              });
            }
          });
          // Se não for root, redirecionar para Atividades (case 0)
          // Usar a mesma lógica do case 0
          if (!_showGantt) {
            return TaskTable(
              key: ValueKey('task_table_$_tasksVersion'),
              tasks: _sortedTasks,
              scrollController: _tableScrollController,
              taskService: _taskService,
              allSubtasksExpanded: _allSubtasksExpanded,
              onToggleAllSubtasks: _toggleAllSubtasks,
              expandedTasks: _expandedTasks,
              onTaskExpanded: _onTaskExpanded,
              sortColumn: _sortColumn,
              getSortValue: _getSortValue,
              onTaskSelected: (task) {
                setState(() {
                  _selectedTask = task;
                });
              },
            );
          }
          return Row(
            children: [
              // Tabela (50% da largura)
              Expanded(
                flex: 1,
                child: TaskTable(
                  key: ValueKey('task_table_$_tasksVersion'),
                  tasks: _sortedTasks,
                  scrollController: _tableScrollController,
                  taskService: _taskService,
                  allSubtasksExpanded: _allSubtasksExpanded,
                  onToggleAllSubtasks: _toggleAllSubtasks,
                  expandedTasks: _expandedTasks,
                  onTaskExpanded: _onTaskExpanded,
                  sortColumn: _sortColumn,
                  getSortValue: _getSortValue,
                  onTaskSelected: (task) {
                    setState(() {
                      _selectedTask = task;
                    });
                  },
                ),
              ),
              // Gantt (50% da largura)
              Expanded(
                flex: 1,
                child: GanttChart(
                  key: ValueKey('gantt_chart_${_tasksVersion}_${_expandedTasks.length}_${_expandedTasks.toList()..sort()}'),
                  tasks: _sortedTasks,
                  startDate: _startDate,
                  endDate: _endDate,
                  scrollController: _ganttScrollController,
                  taskService: _taskService,
                  allSubtasksExpanded: _allSubtasksExpanded,
                  onToggleAllSubtasks: _toggleAllSubtasks,
                  sortColumn: _sortColumn,
                  getSortValue: _getSortValue,
                  onEdit: (task) => _editTaskById(task.id),
                  onDelete: (task) => _deleteTaskById(task.id),
                  onDuplicate: (task) => _duplicateTask(task),
                  onCreateSubtask: (task) {
                    if (task.isMainTask) {
                      _createSubtask(task.id);
                    }
                  },
                  expandedTasks: _expandedTasks,
                  onTaskExpanded: _onTaskExpanded,
                ),
              ),
            ],
          );
        }
      case 6: // Lista
        return AdvancedListView(
          taskService: _taskService,
          filteredTasks: _tasks, // Passar tarefas filtradas
        );
      case 7: // Gráfico
        return AnalyticsView(
          taskService: _taskService,
          filteredTasks: _tasks, // Passar tarefas filtradas
        );
      case 8: // Avançar
        return PlanningView(
          taskService: _taskService,
          filteredTasks: _tasks, // Passar tarefas filtradas
        );
      case 9: // Alertas
        return AlertsView(
          taskService: _taskService,
          filteredTasks: _tasks, // Passar tarefas filtradas
        );
      case 10: // Histórico
        return MaintenanceHistoryView(
          taskService: _taskService,
          filteredTasks: _tasks, // Passar tarefas filtradas
        );
      case 12: // Checklist
        return MaintenanceChecklistView(task: _selectedTask);
      case 13: // Custos
        return CostManagementView(
          taskService: _taskService,
          filteredTasks: _tasks, // Passar tarefas filtradas
        );
      case 14: // Configuração
        return ConfiguracaoView(themeProvider: widget.themeProvider);
      case 15: // Chat
        return const ChatView();
      case 16: // Notas SAP
        return const NotasSAPView();
      default:
        if (!_showGantt) {
          return TaskTable(
            key: ValueKey('task_table_$_tasksVersion'),
            tasks: _sortedTasks,
            scrollController: _tableScrollController,
            taskService: _taskService,
            allSubtasksExpanded: _allSubtasksExpanded,
            onToggleAllSubtasks: _toggleAllSubtasks,
            expandedTasks: _expandedTasks,
            onTaskExpanded: _onTaskExpanded,
            sortColumn: _sortColumn,
            getSortValue: _getSortValue,
            onTaskSelected: (task) {
              _showTaskDetails(task);
            },
            onEdit: (task) => _editTaskById(task.id),
            onDelete: (task) => _deleteTaskById(task.id),
            onDuplicate: (task) => _duplicateTask(task),
            onCreateSubtask: (task) {
              if (task.isMainTask) {
                _createSubtask(task.id);
              }
            },
          );
        }
        return Row(
          children: [
            Expanded(
              flex: 1,
              child: TaskTable(
                key: ValueKey('task_table_$_tasksVersion'),
                tasks: _sortedTasks,
                scrollController: _tableScrollController,
                taskService: _taskService,
                allSubtasksExpanded: _allSubtasksExpanded,
                onToggleAllSubtasks: _toggleAllSubtasks,
                expandedTasks: _expandedTasks,
                onTaskExpanded: _onTaskExpanded,
                sortColumn: _sortColumn,
                getSortValue: _getSortValue,
                onTaskSelected: (task) {
                  _showTaskDetails(task);
                },
                onEdit: (task) => _editTaskById(task.id),
                onDelete: (task) => _deleteTaskById(task.id),
                onDuplicate: (task) => _duplicateTask(task),
                onCreateSubtask: (task) {
                  if (task.isMainTask) {
                    _createSubtask(task.id);
                  }
                },
              ),
            ),
            Expanded(
              flex: 1,
              child: GanttChart(
                key: ValueKey('gantt_chart_${_tasksVersion}_${_expandedTasks.length}_${_expandedTasks.toList()..sort()}'),
                tasks: _sortedTasks,
                startDate: _startDate,
                endDate: _endDate,
                scrollController: _ganttScrollController,
                taskService: _taskService,
                allSubtasksExpanded: _allSubtasksExpanded,
                onToggleAllSubtasks: _toggleAllSubtasks,
                expandedTasks: _expandedTasks,
                onTaskExpanded: _onTaskExpanded,
                sortColumn: _sortColumn,
                getSortValue: _getSortValue,
                onTasksUpdated: () async {
                  print('🔄 GanttChart onTasksUpdated: Recarregando tarefas...');
                  await _loadTasks();
                  // Reaplicar filtros após recarregar para garantir que todas as views sejam atualizadas
                  if (_currentFilters.isNotEmpty) {
                    print('🔄 Reaplicando filtros após atualização do GanttChart...');
                    await _applyFilters(_currentFilters);
                  } else {
                    // Mesmo sem filtros, garantir que as tarefas sejam atualizadas
                    setState(() {
                      _tasksVersion++;
                    });
                  }
                  print('✅ Tarefas recarregadas após atualização do GanttChart');
                },
                onEdit: (task) => _editTaskById(task.id),
                onDelete: (task) => _deleteTaskById(task.id),
                onDuplicate: (task) => _duplicateTask(task),
                onCreateSubtask: (task) {
                  if (task.isMainTask) {
                    _createSubtask(task.id);
                  }
                },
              ),
            ),
          ],
        );
    }
  }

  Widget _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Sidebar(
          isExpanded: true,
          onToggle: () {
            Navigator.of(context).pop();
          },
          selectedIndex: _sidebarSelectedIndex,
          onItemSelected: (index) {
            setState(() {
              _sidebarSelectedIndex = index;
            });
            Navigator.of(context).pop();
          },
          onExport: _exportData,
          isRoot: _authService.currentUser?.isRoot ?? false,
        ),
      ),
    );
  }

  Widget _buildMobileContentStack() {
    print('🔵 _buildMobileContentStack: _selectedTab = $_selectedTab, tasks: ${_sortedTasks.length}');
    
    // Renderizar conteúdo normalmente com tratamento de erro
    try {
      if (_selectedTab == 0) {
        return RepaintBoundary(
          key: const ValueKey('table_boundary'),
          child: TaskTable(
            key: const ValueKey('table'),
            tasks: _sortedTasks,
            scrollController: _tableScrollController,
            taskService: _taskService,
            allSubtasksExpanded: _allSubtasksExpanded,
            onToggleAllSubtasks: _toggleAllSubtasks,
            expandedTasks: _expandedTasks,
            onTaskExpanded: _onTaskExpanded,
            sortColumn: _sortColumn,
            getSortValue: _getSortValue,
            onTaskSelected: (task) {
              _showTaskDetails(task);
            },
            onEdit: (task) => _editTaskById(task.id),
            onDelete: (task) => _deleteTaskById(task.id),
            onDuplicate: (task) => _duplicateTask(task),
            onCreateSubtask: (task) {
              if (task.isMainTask) {
                _createSubtask(task.id);
              }
            },
          ),
        );
      } else if (_selectedTab == 1) {
        return RepaintBoundary(
          key: const ValueKey('gantt_boundary'),
          child: GanttChart(
            key: const ValueKey('gantt'),
            tasks: _sortedTasks,
            startDate: _startDate,
            endDate: _endDate,
            scrollController: _ganttScrollController,
            taskService: _taskService,
            allSubtasksExpanded: _allSubtasksExpanded,
            onToggleAllSubtasks: _toggleAllSubtasks,
            sortColumn: _sortColumn,
            getSortValue: _getSortValue,
            onTasksUpdated: () async {
              print('🔄 GanttChart onTasksUpdated: Recarregando tarefas...');
              await _loadTasks();
              // Reaplicar filtros após recarregar para garantir que todas as views sejam atualizadas
              if (_currentFilters.isNotEmpty) {
                print('🔄 Reaplicando filtros após atualização do GanttChart...');
                await _applyFilters(_currentFilters);
              } else {
                // Mesmo sem filtros, garantir que as tarefas sejam atualizadas
                setState(() {
                  _tasksVersion++;
                });
              }
              print('✅ Tarefas recarregadas após atualização do GanttChart');
            },
            onEdit: (task) => _editTaskById(task.id),
            onDelete: (task) => _deleteTaskById(task.id),
            onDuplicate: (task) => _duplicateTask(task),
            onCreateSubtask: (task) {
              if (task.isMainTask) {
                _createSubtask(task.id);
              }
            },
          ),
        );
      } else if (_selectedTab == 2) {
        return RepaintBoundary(
          key: const ValueKey('planner_boundary'),
          child: PlannerView(
            key: const ValueKey('planner'),
            tasks: _sortedTasks,
            taskService: _taskService,
            onTasksUpdated: () async {
              print('🔄 GanttChart onTasksUpdated: Recarregando tarefas...');
              await _loadTasks();
              // Reaplicar filtros após recarregar para garantir que todas as views sejam atualizadas
              if (_currentFilters.isNotEmpty) {
                print('🔄 Reaplicando filtros após atualização do GanttChart...');
                await _applyFilters(_currentFilters);
              } else {
                // Mesmo sem filtros, garantir que as tarefas sejam atualizadas
                setState(() {
                  _tasksVersion++;
                });
              }
              print('✅ Tarefas recarregadas após atualização do GanttChart');
            },
            onTaskSelected: (task) => _showTaskDetails(task),
            onEdit: (task) => _editTaskById(task.id),
            onDelete: (task) => _deleteTaskById(task.id),
            onDuplicate: (task) => _duplicateTask(task),
            onCreateSubtask: (task) {
              if (task.isMainTask) {
                _createSubtask(task.id);
              }
            },
          ),
        );
      } else if (_selectedTab == 3) {
        return RepaintBoundary(
          key: ValueKey('calendar_boundary_${_tasksVersion}'),
          child: MaintenanceCalendarView(
            key: ValueKey('calendar_${_tasksVersion}'),
            taskService: _taskService,
            onEdit: (task) => _editTaskById(task.id),
            onDelete: (task) => _deleteTaskById(task.id),
            onDuplicate: (task) => _duplicateTask(task),
            onCreateSubtask: (task) {
              if (task.isMainTask) {
                _createSubtask(task.id);
              }
            },
          ),
        );
      } else if (_selectedTab == 4) {
        return RepaintBoundary(
          key: ValueKey('feed_boundary_${_tasksVersion}_${_sortedTasks.length}'),
          child: TaskCardsView(
            key: ValueKey('feed_${_tasksVersion}_${_sortedTasks.length}'),
            tasks: _sortedTasks,
            onEdit: (task) => _editTaskById(task.id),
            onDelete: (task) => _deleteTaskById(task.id),
            onDuplicate: (task) => _duplicateTask(task),
            onCreateSubtask: (task) {
              if (task.isMainTask) {
                _createSubtask(task.id);
              }
            },
          ),
        );
      }
      return const SizedBox.shrink();
    } catch (e, stackTrace) {
      print('❌ Erro ao construir view: $e');
      print('Stack trace: $stackTrace');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Erro ao carregar view: $e'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedTab = 0;
                });
              },
              child: const Text('Voltar para Tabela'),
            ),
          ],
        ),
      );
    }
  }



  // Métodos de CRUD
  Future<void> _createTask() async {
    final result = await showDialog<Task>(
      context: context,
      builder: (context) => TaskFormDialog(
        startDate: _startDate,
        endDate: _endDate,
      ),
    );

    if (result != null) {
      print('🆕 Criando tarefa com ${result.ganttSegments.length} segmentos do Gantt');
      final createdTask = await _taskService.createTask(result);
      print('✅ Tarefa criada: ${createdTask.id} com ${createdTask.ganttSegments.length} segmentos');
      await _loadTasks();
      // Reaplicar filtros para preservar os filtros ativos
      if (_currentFilters.isNotEmpty) {
        await _applyFilters(_currentFilters);
      }
      _showSuccessMessage('Atividade criada com sucesso!');
    }
  }

  void _editTask() {
    if (_selectedTask == null) {
      _showSelectTaskMessage();
      return;
    }

    _editTaskById(_selectedTask!.id);
  }

  Future<void> _createSubtask(String parentTaskId) async {
    final parentTask = await _taskService.getTaskById(parentTaskId);
    if (parentTask == null) {
      _showErrorMessage('Tarefa pai não encontrada');
      return;
    }

    final result = await showDialog<Task>(
      context: context,
      builder: (context) => TaskFormDialog(
        parentTaskId: parentTaskId,
        startDate: _startDate,
        endDate: _endDate,
      ),
    );

    if (result != null) {
      final createdSubtask = await _taskService.createSubtask(parentTaskId, result);
      print('✅ Subtarefa criada: ${createdSubtask.id}');
      await _loadTasks();
      // Reaplicar filtros para preservar os filtros ativos
      if (_currentFilters.isNotEmpty) {
        await _applyFilters(_currentFilters);
      }
      // Forçar rebuild para atualizar tabela e Gantt
      if (mounted) {
        setState(() {});
      }
      _showSuccessMessage('Subtarefa criada com sucesso!');
    }
  }

  Future<void> _editTaskById(String taskId) async {
    final task = await _taskService.getTaskById(taskId);
    if (task == null) {
      _showErrorMessage('Tarefa não encontrada');
      return;
    }

    final result = await showDialog<Task>(
      context: context,
      builder: (context) => TaskFormDialog(
        task: task,
        startDate: _startDate,
        endDate: _endDate,
      ),
    );

    if (result != null) {
      final updated = await _taskService.updateTask(taskId, result);
      if (updated != null) {
        await _loadTasks();
        // Reaplicar filtros para preservar os filtros ativos
        if (_currentFilters.isNotEmpty) {
          await _applyFilters(_currentFilters);
        }
        setState(() {
          _selectedTask = null;
        });
        _showSuccessMessage('Atividade atualizada com sucesso!');
      } else {
        _showErrorMessage('Erro ao atualizar atividade');
      }
    }
  }

  void _deleteTask() {
    if (_selectedTask == null) {
      _showSelectTaskMessage();
      return;
    }

    _deleteTaskById(_selectedTask!.id);
  }

  Future<void> _duplicateTask(Task task) async {
    // Normalizar as datas dos segmentos do Gantt ao duplicar
    final normalizedSegments = task.ganttSegments.map((segment) {
      return GanttSegment(
        dataInicio: DateTime(
          segment.dataInicio.year,
          segment.dataInicio.month,
          segment.dataInicio.day,
        ),
        dataFim: DateTime(
          segment.dataFim.year,
          segment.dataFim.month,
          segment.dataFim.day,
        ),
        label: segment.label,
        tipo: segment.tipo,
      );
    }).toList();
    
    final duplicatedTask = task.copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      tarefa: task.tarefa,
      dataCriacao: DateTime.now(),
      dataAtualizacao: DateTime.now(),
      ganttSegments: normalizedSegments,
      // Normalizar também as datas principais da tarefa
      dataInicio: DateTime(
        task.dataInicio.year,
        task.dataInicio.month,
        task.dataInicio.day,
      ),
      dataFim: DateTime(
        task.dataFim.year,
        task.dataFim.month,
        task.dataFim.day,
      ),
    );
    
    print('🔄 Duplicando tarefa: ${task.id.substring(0, 8)}...');
    print('   Segmentos: ${normalizedSegments.length}');
    if (normalizedSegments.isNotEmpty) {
      print('   Primeiro segmento: ${normalizedSegments.first.dataInicio.toString().substring(0, 10)} até ${normalizedSegments.first.dataFim.toString().substring(0, 10)}');
    }
    
    await _taskService.createTask(duplicatedTask);
    await _loadTasks();
    // Reaplicar filtros para preservar os filtros ativos
    if (_currentFilters.isNotEmpty) {
      await _applyFilters(_currentFilters);
    }
    _showSuccessMessage('Tarefa duplicada com sucesso!');
  }

  Future<void> _deleteTaskById(String taskId) async {
    final task = await _taskService.getTaskById(taskId);
    if (task == null) {
      _showErrorMessage('Tarefa não encontrada');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Deseja realmente excluir a atividade:\n"${task.tarefa}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              final deleted = await _taskService.deleteTask(taskId);
              if (deleted) {
                await _loadTasks();
                // Reaplicar filtros para preservar os filtros ativos
                if (_currentFilters.isNotEmpty) {
                  await _applyFilters(_currentFilters);
                }
                setState(() {
                  _selectedTask = null;
                });
                Navigator.of(context).pop();
                _showSuccessMessage('Atividade excluída com sucesso!');
              } else {
                Navigator.of(context).pop();
                _showErrorMessage('Erro ao excluir atividade');
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  void _showSelectTaskMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Selecione uma atividade na tabela primeiro'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showTaskDetails(Task task) {
    showDialog(
      context: context,
      builder: (context) => TaskViewDialog(task: task),
    );
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Logout'),
        content: const Text('Deseja realmente sair?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final authService = AuthServiceSimples();
        await authService.signOut();
        // Notificar AuthWrapper para atualizar estado
        widget.onLogout?.call();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao fazer logout: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Aplicar filtros
  Future<void> _applyFilters(Map<String, String?> filters) async {
    // Mostrar indicador de loading
    setState(() {
      _isFiltering = true;
    });
    
    try {
      _currentFilters = filters;
      List<Task> filtered;
      
      // Primeiro aplicar os filtros
      filtered = await _taskService.filterTasks(
      status: filters['status'],
      regional: filters['regional'],
      divisao: filters['divisao'],
      local: filters['local'],
      tipo: filters['tipo'],
      executor: filters['executor'],
      coordenador: filters['coordenador'],
      frota: filters['frota'],
      dataInicioMin: _startDate,
      dataFimMax: _endDate,
    );
    
    // Aplicar filtro de "Minhas Tarefas" se ativo
    if (filters['minhasTarefas'] == 'true') {
      final authService = AuthServiceSimples();
      final usuario = authService.currentUser;
      final loginUsuario = usuario?.email ?? authService.getUserEmail() ?? '';
      
      if (loginUsuario.isNotEmpty) {
        // Usar cache se o login não mudou
        Set<String> executorIdsDoUsuario;
        Set<String> nomesExecutoresDoUsuario;
        
        if (_cachedLoginUsuario == loginUsuario && _cachedExecutorIds != null && _cachedExecutorNomes != null) {
          // Usar cache
          executorIdsDoUsuario = _cachedExecutorIds!;
          nomesExecutoresDoUsuario = _cachedExecutorNomes!;
          
          // Se cache está vazio, não há tarefas para mostrar
          if (executorIdsDoUsuario.isEmpty) {
            filtered = [];
          } else {
            // Filtrar tarefas - lógica simplificada e otimizada
            filtered = filtered.where((task) {
              // Verificar se algum executor_id da tarefa está na lista de IDs do usuário
              if (task.executorIds.any((execId) => executorIdsDoUsuario.contains(execId))) {
                return true;
              }
              
              // Verificar se o nome do executor na tarefa corresponde (comparação exata, case-insensitive)
              final executorLower = task.executor.toLowerCase().trim();
              if (executorLower.isNotEmpty && nomesExecutoresDoUsuario.contains(executorLower)) {
                return true;
              }
              
              // Verificar se algum nome na lista de executores corresponde (comparação exata)
              if (task.executores.any((execNome) {
                return nomesExecutoresDoUsuario.contains(execNome.toLowerCase().trim());
              })) {
                return true;
              }
              
              // Verificar coordenador (comparação exata, case-insensitive)
              final coordenadorLower = task.coordenador.toLowerCase().trim();
              if (coordenadorLower.isNotEmpty && nomesExecutoresDoUsuario.contains(coordenadorLower)) {
                return true;
              }
              
              return false;
            }).toList();
          }
        } else {
          // Buscar executores que têm o mesmo login (case-insensitive) - OTIMIZADO
          final executoresDoUsuario = await _executorService.getExecutoresPorLogin(loginUsuario);
          
          if (executoresDoUsuario.isEmpty) {
            // Se não encontrou executores com esse login, não mostrar nenhuma tarefa
            filtered = [];
            _cachedLoginUsuario = loginUsuario;
            _cachedExecutorIds = {};
            _cachedExecutorNomes = {};
          } else {
            // Extrair IDs e nomes dos executores encontrados (normalizados)
            executorIdsDoUsuario = executoresDoUsuario.map((e) => e.id).toSet();
            nomesExecutoresDoUsuario = executoresDoUsuario.map((e) => e.nome.toLowerCase().trim()).toSet();
            
            // Atualizar cache
            _cachedLoginUsuario = loginUsuario;
            _cachedExecutorIds = executorIdsDoUsuario;
            _cachedExecutorNomes = nomesExecutoresDoUsuario;
            
            // Filtrar tarefas - lógica simplificada e otimizada
            filtered = filtered.where((task) {
              // Verificar se algum executor_id da tarefa está na lista de IDs do usuário
              if (task.executorIds.any((execId) => executorIdsDoUsuario.contains(execId))) {
                return true;
              }
              
              // Verificar se o nome do executor na tarefa corresponde (comparação exata, case-insensitive)
              final executorLower = task.executor.toLowerCase().trim();
              if (executorLower.isNotEmpty && nomesExecutoresDoUsuario.contains(executorLower)) {
                return true;
              }
              
              // Verificar se algum nome na lista de executores corresponde (comparação exata)
              if (task.executores.any((execNome) {
                return nomesExecutoresDoUsuario.contains(execNome.toLowerCase().trim());
              })) {
                return true;
              }
              
              // Verificar coordenador (comparação exata, case-insensitive)
              final coordenadorLower = task.coordenador.toLowerCase().trim();
              if (coordenadorLower.isNotEmpty && nomesExecutoresDoUsuario.contains(coordenadorLower)) {
                return true;
              }
              
              return false;
            }).toList();
          }
        }
      }
    } else {
      // Limpar cache quando o filtro não está ativo
      _cachedLoginUsuario = null;
      _cachedExecutorIds = null;
      _cachedExecutorNomes = null;
    }
    
    // Depois aplicar a busca se houver termo de busca
    if (_searchQuery.isNotEmpty) {
      final lowerQuery = _searchQuery.toLowerCase();
      filtered = filtered.where((task) {
        return task.tarefa.toLowerCase().contains(lowerQuery) ||
            (task.ordem?.toLowerCase().contains(lowerQuery) ?? false) ||
            task.executor.toLowerCase().contains(lowerQuery) ||
            task.coordenador.toLowerCase().contains(lowerQuery) ||
            task.locais.any((l) => l.toLowerCase().contains(lowerQuery));
      }).toList();
    }
    
      setState(() {
        _tasks = filtered;
        _tasksVersion++; // Incrementar versão para forçar rebuild dos widgets
        _isFiltering = false; // Ocultar indicador de loading
      });
    } catch (e) {
      print('❌ Erro ao aplicar filtros: $e');
      setState(() {
        _isFiltering = false; // Ocultar indicador mesmo em caso de erro
      });
    }
  }

  // Exportar dados - Mostrar diálogo de escolha de formato
  Future<void> _exportData() async {
    if (!mounted) return;
    
    // Mostrar diálogo para escolher formato
    final formato = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exportar Dados'),
        content: const Text('Escolha o formato de exportação:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'CSV'),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.table_chart, size: 20),
                SizedBox(width: 8),
                Text('CSV'),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'Excel'),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.table_view, size: 20),
                SizedBox(width: 8),
                Text('Excel'),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'PDF'),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.picture_as_pdf, size: 20),
                SizedBox(width: 8),
                Text('PDF'),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (formato == null) return;

    try {
      // Mostrar indicador de carregamento
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gerando arquivo $formato...'),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Obter tarefas para exportar
      final tasksToExport = _tasks.isNotEmpty ? _tasks : await _taskService.getAllTasks();
      
      // Exportar no formato escolhido
      switch (formato) {
        case 'CSV':
          final csvContent = await _generateCSV(tasksToExport);
          await _downloadFile(csvContent, 'atividades_${DateTime.now().millisecondsSinceEpoch}.csv', 'text/csv');
          break;
        case 'Excel':
          final excelBytes = await _generateExcel(tasksToExport);
          await _downloadFileBytes(excelBytes, 'atividades_${DateTime.now().millisecondsSinceEpoch}.xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
          break;
        case 'PDF':
          await _printPage();
          break;
      }
      
      if (mounted) {
        _showSuccessMessage('Dados exportados com sucesso! (${tasksToExport.length} atividades)');
      }
    } catch (e) {
      print('❌ Erro ao exportar dados: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao exportar dados: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Gerar conteúdo CSV
  Future<String> _generateCSV(List<Task> tasks) async {
    final buffer = StringBuffer();
    
    // Cabeçalho CSV
    buffer.writeln(
        'ID,Status,Regional,Divisão,Local,Tipo,Ordem,Tarefa,Executor,Frota,Coordenador,SI,Data Início,Data Fim,Observações');
    
    for (var task in tasks) {
      buffer.writeln([
        task.id,
        task.status,
        task.regional,
        task.divisao,
        task.locais.join('; '),
        task.tipo,
        task.ordem ?? '',
        '"${task.tarefa.replaceAll('"', '""')}"', // Escapar aspas duplas
        '"${task.executor.replaceAll('"', '""')}"',
        task.frota,
        task.coordenador,
        task.si.isNotEmpty ? task.si : '',
        '${task.dataInicio.day.toString().padLeft(2, '0')}/${task.dataInicio.month.toString().padLeft(2, '0')}/${task.dataInicio.year}',
        '${task.dataFim.day.toString().padLeft(2, '0')}/${task.dataFim.month.toString().padLeft(2, '0')}/${task.dataFim.year}',
        task.observacoes != null ? '"${task.observacoes!.replaceAll('"', '""')}"' : '',
      ].join(','));
    }
    
    return buffer.toString();
  }

  // Gerar arquivo Excel
  Future<Uint8List> _generateExcel(List<Task> tasks) async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');
    final sheet = excel['Atividades'];
    
    // Cabeçalhos
    final headers = [
      'ID', 'Status', 'Regional', 'Divisão', 'Local', 'Tipo', 'Ordem',
      'Tarefa', 'Executor', 'Frota', 'Coordenador', 'SI',
      'Data Início', 'Data Fim', 'Observações'
    ];
    
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = headers[i];
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: '#4472C4',
        fontColorHex: '#FFFFFF',
      );
    }
    
    // Dados
    for (int row = 0; row < tasks.length; row++) {
      final task = tasks[row];
      final data = [
        task.id,
        task.status,
        task.regional,
        task.divisao,
        task.locais.join('; '),
        task.tipo,
        task.ordem ?? '',
        task.tarefa,
        task.executor,
        task.frota,
        task.coordenador,
        task.si.isNotEmpty ? task.si : '',
        '${task.dataInicio.day.toString().padLeft(2, '0')}/${task.dataInicio.month.toString().padLeft(2, '0')}/${task.dataInicio.year}',
        '${task.dataFim.day.toString().padLeft(2, '0')}/${task.dataFim.month.toString().padLeft(2, '0')}/${task.dataFim.year}',
        task.observacoes ?? '',
      ];
      
      for (int col = 0; col < data.length; col++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row + 1));
        cell.value = data[col].toString();
      }
    }
    
    final bytes = excel.encode();
    return Uint8List.fromList(bytes!);
  }

  // Imprimir página (usar impressão do navegador)
  Future<void> _printPage() async {
    if (kIsWeb) {
      // Adicionar estilos de impressão dinamicamente se necessário
      final style = html.StyleElement()
        ..id = 'print-styles'
        ..text = '''
          @media print {
            @page {
              size: A4 landscape;
              margin: 10mm;
            }
            body {
              margin: 0;
              padding: 0;
              width: 100%;
              overflow: visible !important;
            }
            button, .sidebar, .header-bar, .filter-bar, .footbar {
              display: none !important;
            }
            .main-content, .task-table, .gantt-chart {
              display: block !important;
              width: 100% !important;
              overflow: visible !important;
            }
            * {
              page-break-inside: auto;
              -webkit-print-color-adjust: exact !important;
              print-color-adjust: exact !important;
            }
            tr, .gantt-row {
              page-break-inside: avoid;
            }
          }
        ''';
      
      // Remover estilo anterior se existir
      html.document.getElementById('print-styles')?.remove();
      html.document.head?.append(style);
      
      // Aguardar um pouco para garantir que os estilos sejam aplicados
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Chamar impressão
      html.window.print();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impressão disponível apenas na versão web'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Fazer download de arquivo (texto)
  Future<void> _downloadFile(String content, String filename, String mimeType) async {
    if (kIsWeb) {
      final bytes = utf8.encode(content);
      final blob = html.Blob([bytes], mimeType);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      print('⚠️ Exportação para mobile/desktop ainda não implementada');
    }
  }

  // Fazer download de arquivo (bytes)
  Future<void> _downloadFileBytes(Uint8List bytes, String filename, String mimeType) async {
    if (kIsWeb) {
      final blob = html.Blob([bytes], mimeType);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      print('⚠️ Exportação para mobile/desktop ainda não implementada');
    }
  }

  // Buscar atividades
  Future<void> _searchTasks(String query) async {
    setState(() {
      _searchQuery = query;
    });
    await _applyFilters(_currentFilters);
  }

  Widget _buildFootbar(bool isMobile) {
    print('🔵 _buildFootbar chamado - isMobile: $isMobile');
    final footbarHeight = isMobile ? 56.0 : 60.0;
    
    final themeProvider = widget.themeProvider ?? ThemeProvider();
    final currentTheme = themeProvider.currentTheme;
    final backgroundColor = ThemeService.getBarBackgroundColor(currentTheme);
    final iconColor = ThemeService.getBarIconColor(currentTheme);
    
    return Container(
      height: footbarHeight,
      decoration: BoxDecoration(
        color: backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildFootbarButton(Icons.table_chart, 'Tabela/Gantt', 'split', isMobile, iconColor),
            _buildFootbarButton(Icons.view_kanban, 'Planner', 'planner', isMobile, iconColor),
            _buildFootbarButton(Icons.calendar_month, 'Calendário', 'calendar', isMobile, iconColor),
            _buildFootbarButton(Icons.dynamic_feed, 'Feed', 'feed', isMobile, iconColor),
          ],
        ),
      ),
    );
  }

  Widget _buildFootbarButton(IconData icon, String label, String mode, bool isMobile, Color iconColor) {
    // No mobile, verificar se o _selectedTab corresponde ao modo
    bool isSelected = false;
    if (mode == 'split') {
      isSelected = _selectedTab == 0 || _selectedTab == 1; // Tabela ou Gantt
    } else if (mode == 'planner') {
      isSelected = _selectedTab == 2;
    } else if (mode == 'calendar') {
      isSelected = _selectedTab == 3;
    } else if (mode == 'feed') {
      isSelected = _selectedTab == 4;
    } else {
      isSelected = _viewMode == mode;
    }
    
    print('🔵 _buildFootbarButton: $label, isSelected: $isSelected, icon: $icon');
    
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            print('🔵 Footbar: Botão clicado - mode: $mode, _selectedTab atual: $_selectedTab');
            setState(() {
              _viewMode = mode;
              // Sincronizar _selectedTab com _viewMode
              if (mode == 'planner') {
                _selectedTab = 2;
                print('🔵 Footbar: Planner selecionado, _selectedTab = 2');
              } else if (mode == 'calendar') {
                _selectedTab = 3;
                print('🔵 Footbar: Calendário selecionado, _selectedTab = 3');
              } else if (mode == 'feed') {
                _selectedTab = 4;
                print('🔵 Footbar: Feed selecionado, _selectedTab = 4');
              } else if (mode == 'split') {
                _selectedTab = 0; // Default para tabela quando clicar em Tabela/Gantt
                print('🔵 Footbar: Split selecionado, _selectedTab = 0');
              }
              print('🔵 Footbar: Após setState - _viewMode = $_viewMode, _selectedTab = $_selectedTab');
            });
          },
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: isMobile ? 4 : 6,
              horizontal: 4,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isSelected ? iconColor : iconColor.withOpacity(0.7),
                  size: isMobile ? 20 : 24,
                ),
                SizedBox(height: isMobile ? 2 : 4),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? iconColor : iconColor.withOpacity(0.7),
                      fontSize: isMobile ? 9 : 10,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
