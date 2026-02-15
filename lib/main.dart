import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'dart:async';
import 'dart:convert' show utf8;
import 'dart:typed_data' show Uint8List;
import 'package:excel/excel.dart';

// Import condicional para web
import 'html_stub.dart' as html if (dart.library.html) 'dart:html';
import 'data/mock_data.dart';
import 'models/task.dart';
import 'services/task_service.dart';
import 'services/conflict_service.dart';
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
import 'widgets/comprehensive_dashboard.dart';
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
import 'widgets/ordem_view.dart';
import 'widgets/at_view.dart';
import 'widgets/si_view.dart';
import 'widgets/linhas_transmissao_view.dart';
import 'widgets/supressao_vegetacao_view.dart';
import 'widgets/horas_sap_view.dart';
import 'widgets/confirmacao_ordens_view.dart';
import 'widgets/demandas_view.dart';
import 'widgets/login_screen.dart';
import 'widgets/home_shortcuts_screen.dart';
import 'features/warnings/warnings.dart';
import 'widgets/resizable_panel.dart';
import 'services/auth_service_simples.dart';
import 'utils/responsive.dart';
import 'config/app_menu_config.dart';

import 'services/local_database_service.dart';
import 'services/sync_service.dart';
import 'services/connectivity_service.dart';
import 'services/version_check_service.dart';
import 'providers/theme_provider.dart';
import 'services/theme_service.dart';
import 'dart:async';
import 'features/media_albums/presentation/pages/gallery_page.dart';
import 'features/documents/presentation/pages/documents_page.dart';
import 'modules/gtd/domain/gtd_session.dart';
import 'modules/gtd/presentation/screens/gtd_home_page.dart';
import 'modules/melhorias_bugs/presentation/screens/melhorias_bugs_home_screen.dart';
// sqflite: factory obrigatória antes de qualquer openDatabase (web e desktop)
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Obrigatório: databaseFactory antes de qualquer openDatabase (evita "databaseFactory not initialized")
  try {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
      print('✅ SQLite (web) inicializado!');
    } else {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      print('✅ SQLite FFI (desktop/mobile) inicializado!');
    }
  } catch (e) {
    print('⚠️ Erro ao inicializar SQLite: $e');
  }
  
  // Inicializar Supabase ANTES do banco local
  try {
    await SupabaseConfig.initialize();
    print('✅ Supabase inicializado com sucesso!');
  } catch (e) {
    print('⚠️ Erro ao inicializar Supabase: $e');
    print('📝 O app continuará funcionando offline');
  }
  
  // Inicializar banco de dados local
  try {
    await LocalDatabaseService().database;
    print('✅ Banco de dados local inicializado!');
  } catch (e) {
    print('⚠️ Erro ao inicializar banco local: $e');
    print('📝 Continuando sem banco local...');
  }

  // Inicializar serviço de conectividade
  try {
    await ConnectivityService().initialize();
    print('✅ Serviço de conectividade inicializado!');
  } catch (e) {
    print('⚠️ Erro ao inicializar conectividade: $e');
  }
  
  // Inicializar serviço de sincronização
  try {
    await SyncService().initialize();
    print('✅ Serviço de sincronização inicializado!');
  } catch (e) {
    print('⚠️ Erro ao inicializar sincronização: $e');
  }

  // Verificação de nova versão (web: consulta version.txt; outras plataformas: no-op)
  if (kIsWeb) {
    VersionCheckService.instance.start();
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
        // Banner de nova versão (web): avisa quando há deploy e permite atualizar sem Ctrl+F5
        return Stack(
          fit: StackFit.expand,
          children: [
            child!,
            ValueListenableBuilder<bool>(
              valueListenable: VersionCheckService.instance.hasNewVersion,
              builder: (context, showBanner, _) {
                if (!showBanner) return const SizedBox.shrink();
                return Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Material(
                      elevation: 4,
                      color: Colors.blue.shade700,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            const Icon(Icons.system_update, color: Colors.white, size: 24),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Nova versão disponível. Atualize para carregar as últimas alterações.',
                                style: TextStyle(color: Colors.white, fontSize: 14),
                              ),
                            ),
                            TextButton(
                              onPressed: () => VersionCheckService.instance.reloadApp(),
                              child: const Text(
                                'Atualizar agora',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
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
    final restored = await _authService.restoreSession();
    if (mounted) {
      setState(() {
        _isAuthenticated = restored || _authService.isAuthenticated;
        _isLoading = false;
      });
    }
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

    // Mobile (largura < 768): tela de atalhos primeiro; desktop/web: Programação direto.
    if (Responsive.isMobileForHome(context)) {
      return _AuthenticatedMobileShell(
        themeProvider: widget.themeProvider,
        onLogout: () {
          _authService.signOut();
          setState(() {
            _isAuthenticated = false;
          });
        },
      );
    }

    return MainScreen(
      themeProvider: widget.themeProvider,
      onLogout: () {
        _authService.signOut();
        setState(() {
          _isAuthenticated = false;
        });
      },
    );
  }
}

/// Shell pós-login no mobile: mostra atalhos ou MainScreen conforme navegação.
class _AuthenticatedMobileShell extends StatefulWidget {
  final ThemeProvider? themeProvider;
  final VoidCallback onLogout;

  const _AuthenticatedMobileShell({
    this.themeProvider,
    required this.onLogout,
  });

  @override
  State<_AuthenticatedMobileShell> createState() => _AuthenticatedMobileShellState();
}

class _AuthenticatedMobileShellState extends State<_AuthenticatedMobileShell> {
  bool _showShortcuts = true;
  int _selectedSidebarIndex = 0;

  void _onShortcutTap(int index) {
    setState(() {
      _showShortcuts = false;
      _selectedSidebarIndex = index;
    });
  }

  void _onBackToShortcuts() {
    setState(() {
      _showShortcuts = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showShortcuts) {
      return HomeShortcutsScreen(
        onShortcutTap: _onShortcutTap,
      );
    }
    return MainScreen(
      themeProvider: widget.themeProvider,
      onLogout: widget.onLogout,
      initialSidebarIndex: _selectedSidebarIndex,
      onBackToShortcuts: _onBackToShortcuts,
      isMobileFromShortcuts: true,
    );
  }
}

class MainScreen extends StatefulWidget {
  final ThemeProvider? themeProvider;
  final VoidCallback? onLogout;
  /// Índice inicial da sidebar (usado ao abrir a partir da tela de atalhos no mobile).
  final int? initialSidebarIndex;
  /// Callback para voltar à tela de atalhos (mobile); evita back para login.
  final VoidCallback? onBackToShortcuts;
  /// True quando foi aberto a partir da tela de atalhos no mobile.
  final bool isMobileFromShortcuts;

  const MainScreen({
    super.key,
    this.themeProvider,
    this.onLogout,
    this.initialSidebarIndex,
    this.onBackToShortcuts,
    this.isMobileFromShortcuts = false,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final ScrollController _tableScrollController = ScrollController();
  final ScrollController _ganttScrollController = ScrollController();
  bool _isSyncingScroll = false; // Flag para evitar loops infinitos na sincronização
  double _lastTableOffset = 0.0; // Último offset conhecido da tabela
  double _lastGanttOffset = 0.0; // Último offset conhecido do Gantt
  double? _savedTableScrollPosition; // Posição do scroll salva antes de operações que podem resetar
  double? _savedGanttScrollPosition; // Posição do scroll do Gantt salva antes de operações que podem resetar
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<HorasSAPViewState> _horasViewKey = GlobalKey<HorasSAPViewState>();
  final TaskService _taskService = TaskService();
  final ConflictService _conflictService = ConflictService();
  final ExecutorService _executorService = ExecutorService();
  final FrotaService _frotaService = FrotaService();
  final AuthServiceSimples _authService = AuthServiceSimples();
  
  List<Task> _tasks = []; // Tarefas filtradas (para telas gerais)
  List<Task> _tasksSemFiltros = []; // Tarefas sem filtros (para tela de equipes)
  Task? _selectedTask; // Tarefa selecionada para edição/deleção
  Map<String, String?> _currentFilters = {}; // Filtros ativos (tela Atividades)
  Map<String, String?> _fleetFilters = {}; // Filtros da tela Frota (Regional, Divisão, Frota, Local)
  Map<String, List<String>>? _fleetFilterOptions; // Opções dos dropdowns da Frota (regionais, divisoes, frotas, locais)
  Map<String, String?> _teamFilters = {}; // Filtros da tela Equipes (divisao, empresa, funcao, matricula, nome)
  Map<String, List<String>>? _teamFilterOptions; // Opções dos dropdowns da Equipes
  String _searchQuery = ''; // Termo de busca atual
  // Inicializar com primeiro e último dia do mês/ano atual
  late DateTime _startDate;
  late DateTime _endDate;
  int _selectedTab = 0; // Para mobile: 0 = Tabela, 1 = Gantt, 2 = Planner, 3 = Calendário, 4 = Feed, 5 = Dashboard
  String _viewMode = 'split'; // 'split', 'table', 'gantt', 'planner', 'calendar', 'feed'
  bool _sidebarExpanded = false; // Estado da sidebar (expandida/retraída)
  int _sidebarSelectedIndex = 0; // Índice selecionado na sidebar (0 = Grid/Tabela)
  bool _allSubtasksExpanded = false; // Estado compartilhado: todas as subtarefas expandidas ou colapsadas
  Set<String> _expandedTasks = {}; // IDs das tarefas expandidas (compartilhado entre tabela e Gantt)
  int _tasksVersion = 0; // Versão das tarefas para forçar rebuild quando necessário
  bool _showGantt = true; // Controla se o Gantt está visível
  GanttScale _ganttScale = GanttScale.daily; // Escala do eixo temporal do Gantt
  bool _isAtividadesRefreshing = false; // Botão "Atualizar" na tela de Atividades
  bool _canEditTasks = false; // Permissão para criar/editar tarefas
  bool _canEditTasksChecked = false; // Indica se a permissão já foi verificada
  bool _isCheckingTaskPermission = false; // Evita múltiplas verificações simultâneas
  String _notasViewMode = 'cards'; // 'tabela', 'cards', 'calendario', 'dashboard'
  String _horasViewMode = 'metas'; // 'tabela' ou 'metas' para a tela de Horas
  bool _filterOnlyWithWarnings = false; // Toggle "Mostrar apenas tarefas com alerta"
  /// Alertas por task_id (Supabase get_task_warnings_for_user). null = ainda não carregou.
  Map<String, List<TaskWarning>>? _warningsByTaskId;
  
  // Cache para executores do usuário (otimização de performance)
  Set<String>? _cachedExecutorIds;
  Set<String>? _cachedExecutorNomes;
  String? _cachedLoginUsuario;

  /// Uma vez por sessão: após carregar tarefas do Supabase, disparar sync automático (rede com acesso ao BD).
  bool _autoSyncTriggeredAfterLoad = false;

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

  Future<void> _loadTaskEditPermission() async {
    if (_isCheckingTaskPermission) return;
    _isCheckingTaskPermission = true;

    try {
      final usuario = _authService.currentUser;
      if (usuario == null) {
        print('🔐 Permissão tarefas: usuário não autenticado -> negar (sem criar/editar)');
        _canEditTasks = false;
        _canEditTasksChecked = true;
        return;
      }

      // Root sempre pode
      if (usuario.isRoot) {
        print('🔐 Permissão tarefas: usuário root (${usuario.email ?? 'sem email'}) -> permitir (root)');
        _canEditTasks = true;
        _canEditTasksChecked = true;
        return;
      }

      final email = usuario.email;
      if (email == null || email.isEmpty) {
        print('🔐 Permissão tarefas: usuário sem email -> negar (sem criar/editar)');
        _canEditTasks = false;
        _canEditTasksChecked = true;
        return;
      }

      final permitido = await _executorService.isCoordenadorOuGerentePorLogin(email);
      print(
        '🔐 Permissão tarefas: login=$email | isRoot=${usuario.isRoot} | coordenador/gerente=$permitido '
        '| regra: apenas coordenador ou gerente pode criar/editar',
      );
      _canEditTasks = permitido;
      _canEditTasksChecked = true;
    } catch (e, stackTrace) {
      print('❌ Erro ao verificar permissão de edição de tarefas: $e');
      print('   Stack trace: $stackTrace');
      _canEditTasks = false;
      _canEditTasksChecked = true;
    } finally {
      _isCheckingTaskPermission = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<bool> _ensureCanEditTasks() async {
    if (!_canEditTasksChecked) {
      await _loadTaskEditPermission();
    }

    if (!_canEditTasks) {
      _showErrorMessage('Apenas coordenador ou gerente pode criar/editar tarefas.');
      return false;
    }

    return true;
  }

  Future<void> _onTaskExpanded(String taskId, bool isExpanded) async {
    print('🔄 DEBUG main: _onTaskExpanded chamado - taskId: ${taskId.substring(0, 8)}, isExpanded: $isExpanded');
    // debug silenciado
    
    // Atualizar estado de expansão
    final newExpandedTasks = Set<String>.from(_expandedTasks);
    if (isExpanded) {
      newExpandedTasks.add(taskId);
    } else {
      newExpandedTasks.remove(taskId);
    }
    _expandedTasks = newExpandedTasks;

    // Manter subtarefas em _tasks para que TaskTable e Gantt usem a mesma lista hierárquica
    // Remover subtarefas existentes do pai (evita duplicar em reexpansões)
    _tasks.removeWhere((t) => t.parentId == taskId);

    if (isExpanded) {
      try {
        final subtasks = await _taskService.getSubtasks(taskId);
        if (subtasks.isNotEmpty) {
          final parentIndex = _tasks.indexWhere((t) => t.id == taskId);
          if (parentIndex != -1) {
            _tasks.insertAll(parentIndex + 1, subtasks);
          } else {
            _tasks.addAll(subtasks);
          }
        }
      } catch (e) {
        print('⚠️ Erro ao carregar subtarefas para $taskId: $e');
      }
    }

    // Forçar rebuild
    setState(() {
      _tasksVersion++;
      print('   _tasksVersion: $_tasksVersion');
    });
  }

  // Salvar posição do scroll antes de operações que podem resetar
  void _saveScrollPositions() {
    if (_tableScrollController.hasClients) {
      _savedTableScrollPosition = _tableScrollController.offset;
    }
    if (_ganttScrollController.hasClients) {
      _savedGanttScrollPosition = _ganttScrollController.offset;
    }
  }
  
  // Restaurar posição do scroll após operações que podem resetar
  void _restoreScrollPositions() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (_savedTableScrollPosition != null && _tableScrollController.hasClients) {
          _tableScrollController.jumpTo(_savedTableScrollPosition!);
          _lastTableOffset = _savedTableScrollPosition!;
        }
        if (_savedGanttScrollPosition != null && _ganttScrollController.hasClients) {
          _ganttScrollController.jumpTo(_savedGanttScrollPosition!);
          _lastGanttOffset = _savedGanttScrollPosition!;
        }
        // Limpar posições salvas após restaurar
        _savedTableScrollPosition = null;
        _savedGanttScrollPosition = null;
      }
    });
  }

  // Sincronizar scroll da tabela para o Gantt
  void _syncTableToGantt() {
    if (_isSyncingScroll) return; // Evitar loops infinitos
    
    try {
      if (!_ganttScrollController.hasClients || !_tableScrollController.hasClients) {
        return;
      }
      
      final tableOffset = _tableScrollController.offset;
      
      // Verificar se o offset realmente mudou (tolerância mínima apenas para evitar chamadas desnecessárias)
      if ((tableOffset - _lastTableOffset).abs() < 0.001) {
        return; // Offset não mudou, ignorar
      }
      
      _lastTableOffset = tableOffset;
      
      // Verificar novamente antes de acessar o offset do Gantt
      if (!_ganttScrollController.hasClients) {
        return;
      }
      
      final ganttOffset = _ganttScrollController.offset;
      
      // Sincronizar SEMPRE que houver qualquer diferença (sem tolerância)
      if ((ganttOffset - tableOffset).abs() > 0.001) {
        _isSyncingScroll = true;
        // Sincronizar imediatamente sem delay
        try {
          if (_ganttScrollController.hasClients && mounted) {
            _lastGanttOffset = tableOffset;
            _ganttScrollController.jumpTo(tableOffset);
          }
        } catch (e) {
          // Ignorar erros de scroll (controller pode ter sido desanexado)
          print('⚠️ Erro ao sincronizar scroll tabela->Gantt: $e');
        } finally {
          // Resetar flag imediatamente após o frame
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _isSyncingScroll = false;
            }
          });
        }
      }
    } catch (e) {
      // Ignorar erros de scroll (controller pode ter sido desanexado)
      print('⚠️ Erro em _syncTableToGantt: $e');
    }
  }
  
  // Sincronizar scroll do Gantt para a tabela
  void _syncGanttToTable() {
    if (_isSyncingScroll) return; // Evitar loops infinitos
    
    try {
      if (!_tableScrollController.hasClients || !_ganttScrollController.hasClients) {
        return;
      }
      
      final ganttOffset = _ganttScrollController.offset;
      
      // Verificar se o offset realmente mudou (tolerância mínima apenas para evitar chamadas desnecessárias)
      if ((ganttOffset - _lastGanttOffset).abs() < 0.001) {
        return; // Offset não mudou, ignorar
      }
      
      _lastGanttOffset = ganttOffset;
      
      // Verificar novamente antes de acessar o offset da tabela
      if (!_tableScrollController.hasClients) {
        return;
      }
      
      final tableOffset = _tableScrollController.offset;
      
      // Sincronizar SEMPRE que houver qualquer diferença (sem tolerância)
      if ((tableOffset - ganttOffset).abs() > 0.001) {
        _isSyncingScroll = true;
        // Sincronizar imediatamente sem delay
        try {
          if (_tableScrollController.hasClients && mounted) {
            _lastTableOffset = ganttOffset;
            _tableScrollController.jumpTo(ganttOffset);
          }
        } catch (e) {
          // Ignorar erros de scroll (controller pode ter sido desanexado)
          print('⚠️ Erro ao sincronizar scroll Gantt->tabela: $e');
        } finally {
          // Resetar flag imediatamente após o frame
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _isSyncingScroll = false;
            }
          });
        }
      }
    } catch (e) {
      // Ignorar erros de scroll (controller pode ter sido desanexado)
      print('⚠️ Erro em _syncGanttToTable: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialSidebarIndex != null) {
      _sidebarSelectedIndex = widget.initialSidebarIndex!;
    }
    // Inicializar datas com primeiro e último dia do mês/ano atual
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0); // Último dia do mês atual
    
    // Carregar tarefas (do Supabase ou mock)
    _loadTasks();

    // Carregar permissões de edição/criação de tarefas
    _loadTaskEditPermission();
    
    // Sincronizar scroll entre tabela e Gantt (100% sincronizado)
    _tableScrollController.addListener(_syncTableToGantt);
    _ganttScrollController.addListener(_syncGanttToTable);
  }

  @override
  void dispose() {
    // Remover listeners antes de dispor
    _tableScrollController.removeListener(_syncTableToGantt);
    _ganttScrollController.removeListener(_syncGanttToTable);
    _tableScrollController.dispose();
    _ganttScrollController.dispose();
    super.dispose();
  }

  // Função para ordenar tarefas por período (data de início e fim)
  // Estado de ordenação
  String _sortColumn = 'LOCAL'; // Coluna padrão ajustada para LOCAL
  bool _sortAscending = true; // Direção padrão: crescente
  
  List<Task> _sortTasks(List<Task> tasks) {
    if (tasks.isEmpty) return [];
    final sortedTasks = List<Task>.from(tasks);
    
    sortedTasks.sort((a, b) {
      int comparison = 0;

      DateTime _getStart(Task t) {
        if (t.ganttSegments.isNotEmpty) {
          return t.ganttSegments.first.dataInicio;
        }
        return t.dataInicio;
      }

      DateTime _getEnd(Task t) {
        if (t.ganttSegments.isNotEmpty) {
          return t.ganttSegments.first.dataFim;
        }
        return t.dataFim;
      }
      
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
          if (comparison == 0) {
            final aStart = _getStart(a);
            final bStart = _getStart(b);
            comparison = aStart.compareTo(bStart);
            if (comparison == 0) {
              comparison = _getEnd(a).compareTo(_getEnd(b));
            }
          }
          break;
          
        case 'LOCAL':
          final localA = a.locais.isNotEmpty ? a.locais.first : '';
          final localB = b.locais.isNotEmpty ? b.locais.first : '';
          comparison = localA.compareTo(localB);
          if (comparison == 0) {
            final aStart = _getStart(a);
            final bStart = _getStart(b);
            comparison = aStart.compareTo(bStart);
            if (comparison == 0) {
              comparison = _getEnd(a).compareTo(_getEnd(b));
            }
          }
          break;
          
        case 'TIPO':
          comparison = a.tipo.compareTo(b.tipo);
          if (comparison == 0) {
            final aStart = _getStart(a);
            final bStart = _getStart(b);
            comparison = aStart.compareTo(bStart);
            if (comparison == 0) {
              comparison = _getEnd(a).compareTo(_getEnd(b));
            }
          }
          break;
          
        case 'TAREFA':
          comparison = a.tarefa.compareTo(b.tarefa);
          if (comparison == 0) {
            final aStart = _getStart(a);
            final bStart = _getStart(b);
            comparison = aStart.compareTo(bStart);
            if (comparison == 0) {
              comparison = _getEnd(a).compareTo(_getEnd(b));
            }
          }
          break;
          
        case 'EXECUTOR':
          comparison = a.executor.compareTo(b.executor);
          if (comparison == 0) {
            final aStart = _getStart(a);
            final bStart = _getStart(b);
            comparison = aStart.compareTo(bStart);
            if (comparison == 0) {
              comparison = _getEnd(a).compareTo(_getEnd(b));
            }
          }
          break;
          
        case 'COORDENADOR':
          comparison = a.coordenador.compareTo(b.coordenador);
          if (comparison == 0) {
            final aStart = _getStart(a);
            final bStart = _getStart(b);
            comparison = aStart.compareTo(bStart);
            if (comparison == 0) {
              comparison = _getEnd(a).compareTo(_getEnd(b));
            }
          }
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

  /// Tarefas para tabela/Gantt: se filtro "Com alerta" ativo, apenas tarefas com pelo menos um warning.
  List<Task> get _tasksForTable {
    final base = _sortedTasks;
    if (!_filterOnlyWithWarnings || base.isEmpty) return base;
    final warningsMap = _warningsByTaskIdForTable;
    final idsWithWarnings = warningsMap.keys.where((id) => (warningsMap[id] ?? []).isNotEmpty).toSet();
    return base.where((t) => idsWithWarnings.contains(t.id)).toList();
  }

  /// Mapa taskId -> warnings (Supabase). Retorna mapa vazio se ainda não carregou.
  Map<String, List<TaskWarning>> get _warningsByTaskIdForTable =>
      _warningsByTaskId ?? {};

  /// Quantidade de tarefas PAI (parentId == null) com alerta = mesmo número de linhas na tabela.
  int get _tasksWithWarningsCount {
    final w = _warningsByTaskIdForTable;
    final base = _sortedTasks;
    return base.where((t) => t.parentId == null && (w[t.id] ?? []).isNotEmpty).length;
  }

  /// Total de tarefas com alerta retornadas pelo RPC (para exibir "7 de 19").
  int get _warningsTotalCount => _warningsByTaskId?.length ?? 0;

  Future<void> _loadWarnings() async {
    const bool _debugWarnings = true; // DEBUG: por que warnings não refletem no Flutter
    try {
      final map = await TaskWarningsService.getWarningsByTaskId();
      if (kDebugMode && _debugWarnings) {
        final totalW = map.values.fold<int>(0, (s, l) => s + l.length);
        final taskIdsInList = _tasks.map((t) => t.id).toSet();
        final warningTaskIds = map.keys.toSet();
        final intersection = warningTaskIds.intersection(taskIdsInList);
        debugPrint('[WARNINGS DEBUG] main: ${map.length} tarefas c/ warnings ($totalW alertas); ${_tasks.length} tarefas na lista; interseção=${intersection.length} (warnings c/ tarefa na tabela)');
        if (map.isNotEmpty && intersection.isEmpty) {
          debugPrint('[WARNINGS DEBUG] ⚠️ Nenhum task_id dos warnings está na lista de tarefas exibidas. Possível causa: RPC get_task_warnings_for_user filtra por usuário (root/gerente/executor); ou período/filtros excluem essas tarefas.');
        }
      }
      if (mounted) setState(() => _warningsByTaskId = map);
    } catch (e) {
      if (kDebugMode && _debugWarnings) debugPrint('[WARNINGS DEBUG] main _loadWarnings erro: $e');
      if (mounted) setState(() => _warningsByTaskId = {});
    }
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
  // Adicionar uma nova tarefa à lista sem recarregar tudo (evita o "pisca" ao criar)
  Future<void> _addTaskToList(String taskId) async {
    try {
      // Buscar a tarefa recém-criada do banco
      final newTask = await _taskService.getTaskById(taskId);
      if (newTask == null) {
        print('⚠️ Tarefa $taskId não encontrada após criação');
        return;
      }

      // Verificar se a tarefa passa pelos filtros atuais antes de adicionar
      setState(() {
        bool shouldAdd = true;
        
        // Aplicar filtros de perfil
        final usuario = _authService.currentUser;
        if (usuario != null && !usuario.isRoot && usuario.temPerfilConfigurado()) {
          bool passaRegional = true;
          bool passaDivisao = true;
          bool passaSegmento = true;

          if (usuario.regionalIds.isNotEmpty) {
            passaRegional = newTask.regionalId != null && usuario.temAcessoRegional(newTask.regionalId);
          }
          if (usuario.divisaoIds.isNotEmpty) {
            passaDivisao = newTask.divisaoId != null && usuario.temAcessoDivisao(newTask.divisaoId);
          }
          if (usuario.segmentoIds.isNotEmpty) {
            passaSegmento = newTask.segmentoId != null && usuario.temAcessoSegmento(newTask.segmentoId);
          }

          shouldAdd = passaRegional && passaDivisao && passaSegmento;
        }

        // Verificar filtros de data
        if (shouldAdd && (_startDate != null || _endDate != null)) {
          bool hasSegmentInRange = false;
          for (var segment in newTask.ganttSegments) {
            final startDate = DateTime(segment.dataInicio.year, segment.dataInicio.month, segment.dataInicio.day);
            final endDate = DateTime(segment.dataFim.year, segment.dataFim.month, segment.dataFim.day);
            
            if (_startDate != null && _endDate != null) {
              if (!(startDate.isAfter(_endDate) || endDate.isBefore(_startDate))) {
                hasSegmentInRange = true;
                break;
              }
            } else if (_startDate != null) {
              if (endDate.isAfter(_startDate) || endDate.isAtSameMomentAs(_startDate)) {
                hasSegmentInRange = true;
                break;
              }
            } else if (_endDate != null) {
              if (startDate.isBefore(_endDate) || startDate.isAtSameMomentAs(_endDate)) {
                hasSegmentInRange = true;
                break;
              }
            }
          }
          if (!hasSegmentInRange && newTask.ganttSegments.isEmpty) {
            if (_startDate != null && _endDate != null) {
              if (newTask.dataInicio.isAfter(_endDate) || newTask.dataFim.isBefore(_startDate)) {
                hasSegmentInRange = false;
              } else {
                hasSegmentInRange = true;
              }
            }
          }
          shouldAdd = hasSegmentInRange;
        }

        // Aplicar outros filtros se existirem
        if (shouldAdd && _currentFilters.isNotEmpty) {
          // Verificar filtros básicos
          if (_currentFilters['status'] != null && newTask.status != _currentFilters['status']) {
            shouldAdd = false;
          }
          if (shouldAdd && _currentFilters['regional'] != null && newTask.regional != _currentFilters['regional']) {
            shouldAdd = false;
          }
          if (shouldAdd && _currentFilters['divisao'] != null && newTask.divisao != _currentFilters['divisao']) {
            shouldAdd = false;
          }
          if (shouldAdd && _currentFilters['tipo'] != null && newTask.tipo != _currentFilters['tipo']) {
            shouldAdd = false;
          }
          if (shouldAdd && _currentFilters['executor'] != null) {
            final executorMatch = newTask.executores.any((e) => e == _currentFilters['executor']) ||
                                 newTask.executor == _currentFilters['executor'];
            if (!executorMatch) {
              shouldAdd = false;
            }
          }
          if (shouldAdd && _currentFilters['coordenador'] != null && newTask.coordenador != _currentFilters['coordenador']) {
            shouldAdd = false;
          }
          if (shouldAdd && _currentFilters['local'] != null) {
            final localMatch = newTask.locais.any((l) => l == _currentFilters['local']);
            if (!localMatch) {
              shouldAdd = false;
            }
          }
          if (shouldAdd && _currentFilters['frota'] != null) {
            final frotaMatch = newTask.frota == _currentFilters['frota'] ||
                              (newTask.frotaIds.isNotEmpty && _currentFilters['frota'] != null);
            if (!frotaMatch) {
              shouldAdd = false;
            }
          }
        }

        if (shouldAdd) {
          // Verificar se a tarefa já não está na lista (evitar duplicatas)
          final index = _tasks.indexWhere((t) => t.id == taskId);
          if (index == -1) {
            _tasks.add(newTask);
            _tasksVersion++; // Incrementar versão para forçar rebuild
            print('✅ Tarefa $taskId adicionada à lista local (versão: $_tasksVersion)');
          } else {
            print('ℹ️ Tarefa $taskId já está na lista, atualizando...');
            _tasks[index] = newTask;
            _tasksVersion++;
          }
        } else {
          print('ℹ️ Tarefa $taskId não passa pelos filtros atuais, não será adicionada à lista');
        }
      });
    } catch (e, stackTrace) {
      print('❌ Erro ao adicionar tarefa à lista: $e');
      print('   Stack trace: $stackTrace');
      // Em caso de erro, fazer reload completo como fallback
      await _loadTasks();
      if (_currentFilters.isNotEmpty) {
        await _applyFilters(_currentFilters);
      }
    }
  }

  // Atualizar apenas uma tarefa específica na lista sem recarregar tudo
  Future<void> _updateTaskInList(String taskId) async {
    try {
      // Buscar apenas a tarefa atualizada do banco
      final updatedTask = await _taskService.getTaskById(taskId);
      if (updatedTask == null) {
        print('⚠️ Tarefa $taskId não encontrada após atualização');
        return;
      }

      // Atualizar a tarefa na lista local mantendo os filtros
      setState(() {
        final index = _tasks.indexWhere((t) => t.id == taskId);
        if (index != -1) {
          // Verificar se a tarefa atualizada ainda passa pelos filtros
          bool shouldKeep = true;
          
          // Aplicar filtros de perfil
          final usuario = _authService.currentUser;
          if (usuario != null && !usuario.isRoot && usuario.temPerfilConfigurado()) {
            bool passaRegional = true;
            bool passaDivisao = true;
            bool passaSegmento = true;

            if (usuario.regionalIds.isNotEmpty) {
              passaRegional = updatedTask.regionalId != null && usuario.temAcessoRegional(updatedTask.regionalId);
            }
            if (usuario.divisaoIds.isNotEmpty) {
              passaDivisao = updatedTask.divisaoId != null && usuario.temAcessoDivisao(updatedTask.divisaoId);
            }
            if (usuario.segmentoIds.isNotEmpty) {
              passaSegmento = updatedTask.segmentoId != null && usuario.temAcessoSegmento(updatedTask.segmentoId);
            }

            shouldKeep = passaRegional && passaDivisao && passaSegmento;
          }

          // Verificar filtros de data
          if (shouldKeep && (_startDate != null || _endDate != null)) {
            bool hasSegmentInRange = false;
            for (var segment in updatedTask.ganttSegments) {
              final startDate = DateTime(segment.dataInicio.year, segment.dataInicio.month, segment.dataInicio.day);
              final endDate = DateTime(segment.dataFim.year, segment.dataFim.month, segment.dataFim.day);
              
              if (_startDate != null && _endDate != null) {
                if (!(startDate.isAfter(_endDate) || endDate.isBefore(_startDate))) {
                  hasSegmentInRange = true;
                  break;
                }
              } else if (_startDate != null) {
                if (endDate.isAfter(_startDate) || endDate.isAtSameMomentAs(_startDate)) {
                  hasSegmentInRange = true;
                  break;
                }
              } else if (_endDate != null) {
                if (startDate.isBefore(_endDate) || startDate.isAtSameMomentAs(_endDate)) {
                  hasSegmentInRange = true;
                  break;
                }
              }
            }
            if (!hasSegmentInRange && updatedTask.ganttSegments.isEmpty) {
              if (_startDate != null && _endDate != null) {
                if (updatedTask.dataInicio.isAfter(_endDate) || updatedTask.dataFim.isBefore(_startDate)) {
                  hasSegmentInRange = false;
                } else {
                  hasSegmentInRange = true;
                }
              }
            }
            shouldKeep = hasSegmentInRange;
          }

          // Aplicar outros filtros se existirem
          if (shouldKeep && _currentFilters.isNotEmpty) {
            // Verificar filtros básicos
            if (_currentFilters['status'] != null && updatedTask.status != _currentFilters['status']) {
              shouldKeep = false;
            }
            if (shouldKeep && _currentFilters['regional'] != null && updatedTask.regional != _currentFilters['regional']) {
              shouldKeep = false;
            }
            if (shouldKeep && _currentFilters['divisao'] != null && updatedTask.divisao != _currentFilters['divisao']) {
              shouldKeep = false;
            }
            if (shouldKeep && _currentFilters['tipo'] != null && updatedTask.tipo != _currentFilters['tipo']) {
              shouldKeep = false;
            }
            if (shouldKeep && _currentFilters['executor'] != null) {
              final executorMatch = updatedTask.executores.any((e) => e == _currentFilters['executor']) ||
                                   updatedTask.executor == _currentFilters['executor'];
              if (!executorMatch) {
                shouldKeep = false;
              }
            }
            if (shouldKeep && _currentFilters['coordenador'] != null && updatedTask.coordenador != _currentFilters['coordenador']) {
              shouldKeep = false;
            }
            if (shouldKeep && _currentFilters['local'] != null) {
              final localMatch = updatedTask.locais.any((l) => l == _currentFilters['local']);
              if (!localMatch) {
                shouldKeep = false;
              }
            }
          }

          if (shouldKeep) {
            // Atualizar a tarefa na lista
            _tasks[index] = updatedTask;
            _tasksVersion++; // Incrementar versão para forçar rebuild
          } else {
            // Remover a tarefa se não passar mais pelos filtros
            _tasks.removeAt(index);
            _tasksVersion++;
          }
        } else {
          // Tarefa não está na lista, verificar se deve ser adicionada
          bool shouldAdd = true;
          
          // Aplicar mesmos filtros acima
          final usuario = _authService.currentUser;
          if (usuario != null && !usuario.isRoot && usuario.temPerfilConfigurado()) {
            bool passaRegional = true;
            bool passaDivisao = true;
            bool passaSegmento = true;

            if (usuario.regionalIds.isNotEmpty) {
              passaRegional = updatedTask.regionalId != null && usuario.temAcessoRegional(updatedTask.regionalId);
            }
            if (usuario.divisaoIds.isNotEmpty) {
              passaDivisao = updatedTask.divisaoId != null && usuario.temAcessoDivisao(updatedTask.divisaoId);
            }
            if (usuario.segmentoIds.isNotEmpty) {
              passaSegmento = updatedTask.segmentoId != null && usuario.temAcessoSegmento(updatedTask.segmentoId);
            }

            shouldAdd = passaRegional && passaDivisao && passaSegmento;
          }

          if (shouldAdd && (_startDate != null || _endDate != null)) {
            bool hasSegmentInRange = false;
            for (var segment in updatedTask.ganttSegments) {
              final startDate = DateTime(segment.dataInicio.year, segment.dataInicio.month, segment.dataInicio.day);
              final endDate = DateTime(segment.dataFim.year, segment.dataFim.month, segment.dataFim.day);
              
              if (_startDate != null && _endDate != null) {
                if (!(startDate.isAfter(_endDate) || endDate.isBefore(_startDate))) {
                  hasSegmentInRange = true;
                  break;
                }
              }
            }
            shouldAdd = hasSegmentInRange;
          }

          if (shouldAdd && _currentFilters.isNotEmpty) {
            // Aplicar mesmos filtros acima
            if (_currentFilters['status'] != null && updatedTask.status != _currentFilters['status']) {
              shouldAdd = false;
            }
            // ... outros filtros
          }

          if (shouldAdd) {
            _tasks.add(updatedTask);
            _tasksVersion++;
          }
        }
      });

      // Recarregar alertas para refletir correção de warning (ex.: status PROG→CONC)
      await _loadWarnings();

      print('✅ Tarefa $taskId atualizada na lista local (versão: $_tasksVersion)');
    } catch (e) {
      print('❌ Erro ao atualizar tarefa na lista: $e');
      // Em caso de erro, fazer reload completo como fallback
      await _loadTasks();
      if (_currentFilters.isNotEmpty) {
        await _applyFilters(_currentFilters);
      }
    }
  }

  /// Recarrega tarefas na tela de Atividades (botão Atualizar). Reaplica filtros se houver.
  Future<void> _refreshAtividades() async {
    if (_isAtividadesRefreshing) return;
    if (!mounted) return;
    setState(() => _isAtividadesRefreshing = true);
    try {
      await _loadTasks();
      if (mounted && _currentFilters.isNotEmpty) {
        await _applyFilters(_currentFilters);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dados atualizados'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAtividadesRefreshing = false);
    }
  }

  Future<void> _loadTasks() async {
    try {
      // Carregar lista base SEM filtros (somente janela de datas) para a tela de equipes
      final baseTasks = await _taskService.filterTasks(
        status: null,
        regional: null,
        divisao: null,
        local: null,
        tipo: null,
        executor: null,
        coordenador: null,
        frota: null,
        dataInicioMin: _startDate,
        dataFimMax: _endDate,
      );

      // Em seguida, aplicar filtros atuais (se existirem) para as demais telas
      List<Task> filtered;
      if (_currentFilters.isNotEmpty) {
        filtered = await _taskService.filterTasks(
          status: _parseFilterList(_currentFilters['status']),
          regional: _parseFilterList(_currentFilters['regional']),
          divisao: _parseFilterList(_currentFilters['divisao']),
          local: _parseFilterList(_currentFilters['local']),
          tipo: _parseFilterList(_currentFilters['tipo']),
          executor: _parseFilterList(_currentFilters['executor']),
          coordenador: _parseFilterList(_currentFilters['coordenador']),
          frota: _parseFilterList(_currentFilters['frota']),
          dataInicioMin: _startDate,
          dataFimMax: _endDate,
        );
      } else {
        filtered = baseTasks;
      }

      if (mounted) {
        setState(() {
          _tasksSemFiltros = baseTasks;
          _tasks = filtered;
          _tasksVersion++; // Incrementar versão para forçar rebuild dos widgets
        });
        await _loadWarnings();
        // Sincronização automática quando há rede e acesso ao Supabase (uma vez por sessão após carregar)
        if (!_autoSyncTriggeredAfterLoad) {
          _autoSyncTriggeredAfterLoad = true;
          SyncService().syncAll();
        }
      }
    } catch (e) {
      // Se falhar, usar dados mock
      print('⚠️ Erro ao carregar do Supabase, usando dados mock: $e');
      _taskService.initializeWithMockData(MockData.getTasks());
      if (mounted) {
        setState(() {
          // Fallback para mock (síncrono)
          _tasksSemFiltros = [];
          _tasks = [];
        });

        // Reaplicar filtros vigentes (inclui período selecionado no HeaderBar)
        await _applyFilters(_currentFilters);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      final isMobile = Responsive.isMobile(context);
      final isTablet = Responsive.isTablet(context);
      final isDesktop = Responsive.isDesktop(context);
      // Regras de visibilidade do menu (Sidebar): mesma fonte que a tela de atalhos
      final menuVisibility = MenuVisibility.getForCurrentUser();

      // Detectar tablet em landscape (largura >= 1024 mas altura < 1024)
      final screenWidth = MediaQuery.of(context).size.width;
      final screenHeight = MediaQuery.of(context).size.height;
      final isTabletLandscape = !isMobile && screenWidth >= 1024 && screenHeight < 1024;

      // debug silenciado
      // debug silenciado
      // debug silenciado

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
                    canEditTasks: _canEditTasks,
                    onPerfilUpdated: () async {
                      _cachedLoginUsuario = null;
                      _cachedExecutorIds = null;
                      _cachedExecutorNomes = null;
                      await _loadTasks();
                      await _applyFilters(_currentFilters);
                    },
                    ganttScale: _ganttScale,
                    onGanttScaleChanged: (v) => setState(() => _ganttScale = v),
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
                    onRefreshAtividades: _refreshAtividades,
                    isAtividadesRefreshing: _isAtividadesRefreshing,
                    isHorasScreen: _sidebarSelectedIndex == 20,
                    horasViewMode: _horasViewMode,
                    onHorasViewModeChanged: (mode) {
                      setState(() {
                        _horasViewMode = mode;
                      });
                    },
                    onRefreshHoras: () => _horasViewKey.currentState?.refresh(),
                  ),
                  // Filter Bar (mobile): Frota usa filtros específicos; demais telas barra completa
                  if (_sidebarSelectedIndex == 2)
                    FilterBar(
                      fleetMode: true,
                      fleetFilterOptions: _fleetFilterOptions,
                      onFiltersChanged: (f) {
                        setState(() { _fleetFilters = f; });
                      },
                      initialFilters: _fleetFilters,
                      startDate: _startDate,
                      endDate: _endDate,
                      visibleTasks: _tasksSemFiltros,
                    )
                  else if (_sidebarSelectedIndex == 1)
                    FilterBar(
                      teamMode: true,
                      teamFilterOptions: _teamFilterOptions,
                      onFiltersChanged: (f) {
                        setState(() { _teamFilters = f; });
                      },
                      initialFilters: _teamFilters,
                      startDate: _startDate,
                      endDate: _endDate,
                      visibleTasks: _tasksSemFiltros,
                    )
                  else if (_sidebarSelectedIndex != 14 &&
                      _sidebarSelectedIndex != 14 &&
                      _sidebarSelectedIndex != 15 &&
                      _sidebarSelectedIndex != 16 &&
                      _sidebarSelectedIndex != 17 &&
                      _sidebarSelectedIndex != 18 &&
                      _sidebarSelectedIndex != 19 &&
                      _sidebarSelectedIndex != 20 &&
                      _sidebarSelectedIndex != 21 &&
                      _sidebarSelectedIndex != 22 &&
                      _sidebarSelectedIndex != 23 &&
                      _sidebarSelectedIndex != 25 &&
                      _sidebarSelectedIndex != 26)
                    FilterBar(
                      onFiltersChanged: _applyFilters,
                      initialFilters: _currentFilters,
                      startDate: _startDate,
                      endDate: _endDate,
                      visibleTasks: _tasks,
                      onSortChanged: _updateSorting,
                      currentSortColumn: _sortColumn,
                      currentSortAscending: _sortAscending,
                      isFiltering: false,
                      filterOnlyWithWarnings: _filterOnlyWithWarnings,
                      onFilterOnlyWithWarnings: (v) => setState(() => _filterOnlyWithWarnings = v),
                      warningsCountInTable: _tasksWithWarningsCount,
                      warningsTotalCount: _warningsTotalCount,
                      onToggleGantt: () {
                        setState(() {
                          final newShowGantt = !_showGantt;
                          _showGantt = newShowGantt;
                          if (isMobile) {
                            if (newShowGantt) _selectedTab = 1;
                            else _selectedTab = 0;
                          }
                        });
                      },
                      showGantt: _showGantt,
                      currentViewMode: _viewMode,
                    ),
                  // Main Content
                  Expanded(
                    child: _buildMainContent(isMobile, isTablet, isDesktop),
                  ),
                  // Footbar para mobile (botões de visualização)
                  if (isMobile && (_sidebarSelectedIndex == 0 || _sidebarSelectedIndex == 16 || _sidebarSelectedIndex == 20)) ...[
                    Builder(
                      builder: (context) {
                        // debug silenciado
                        return _buildFootbar(isMobile, false);
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
                  isRoot: menuVisibility.isRoot,
                  showGtd: menuVisibility.showGtd,
                  showGtdAndSupressao: menuVisibility.showGtdAndSupressao,
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
                        canEditTasks: _canEditTasks,
                        onPerfilUpdated: () async {
                          _cachedLoginUsuario = null;
                          _cachedExecutorIds = null;
                          _cachedExecutorNomes = null;
                          await _loadTasks();
                          await _applyFilters(_currentFilters);
                        },
                        ganttScale: _ganttScale,
                        onGanttScaleChanged: (v) => setState(() => _ganttScale = v),
                        onViewModeChanged: (mode) {
                          setState(() {
                            _viewMode = mode;
                            if (mode == 'planner') {
                              _selectedTab = 2;
                            } else if (mode == 'calendar') {
                              _selectedTab = 3;
                            } else if (mode == 'feed') {
                              _selectedTab = 4;
                            } else if (mode == 'dashboard') {
                              _selectedTab = 5;
                            } else if (mode == 'split') {
                              _selectedTab = 0;
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
                        onRefreshAtividades: _refreshAtividades,
                        isAtividadesRefreshing: _isAtividadesRefreshing,
                        isHorasScreen: _sidebarSelectedIndex == 20,
                        horasViewMode: _horasViewMode,
                        onHorasViewModeChanged: (mode) {
                          setState(() {
                            _horasViewMode = mode;
                          });
                        },
                        onRefreshHoras: () => _horasViewKey.currentState?.refresh(),
                      ),
                      // Filter Bar: na Frota (2) usa filtros específicos; ocultar em Configurações, Chat, etc.
                      if (_sidebarSelectedIndex == 2)
                        FilterBar(
                          fleetMode: true,
                          fleetFilterOptions: _fleetFilterOptions,
                          onFiltersChanged: (f) {
                            setState(() { _fleetFilters = f; });
                          },
                          initialFilters: _fleetFilters,
                          startDate: _startDate,
                          endDate: _endDate,
                          visibleTasks: _tasksSemFiltros,
                        )
                      else if (_sidebarSelectedIndex == 1)
                        FilterBar(
                          teamMode: true,
                          teamFilterOptions: _teamFilterOptions,
                          onFiltersChanged: (f) {
                            setState(() { _teamFilters = f; });
                          },
                          initialFilters: _teamFilters,
                          startDate: _startDate,
                          endDate: _endDate,
                          visibleTasks: _tasksSemFiltros,
                        )
                      else if (_sidebarSelectedIndex != 14 &&
                          _sidebarSelectedIndex != 14 &&
                          _sidebarSelectedIndex != 15 &&
                          _sidebarSelectedIndex != 16 &&
                          _sidebarSelectedIndex != 17 &&
                          _sidebarSelectedIndex != 18 &&
                          _sidebarSelectedIndex != 19 &&
                          _sidebarSelectedIndex != 20 &&
                          _sidebarSelectedIndex != 21 &&
                          _sidebarSelectedIndex != 22 &&
                          _sidebarSelectedIndex != 23 &&
                          _sidebarSelectedIndex != 25 &&
                          _sidebarSelectedIndex != 26)
                        FilterBar(
                          onFiltersChanged: _applyFilters,
                          initialFilters: _currentFilters,
                          startDate: _startDate,
                          endDate: _endDate,
                          visibleTasks: _tasks,
                          onSortChanged: _updateSorting,
                          currentSortColumn: _sortColumn,
                          currentSortAscending: _sortAscending,
                          isFiltering: false,
                          filterOnlyWithWarnings: _filterOnlyWithWarnings,
                          onFilterOnlyWithWarnings: (v) => setState(() => _filterOnlyWithWarnings = v),
                          warningsCountInTable: _tasksWithWarningsCount,
                          warningsTotalCount: _warningsTotalCount,
                          onToggleGantt: () {
                            setState(() { _showGantt = !_showGantt; });
                          },
                          showGantt: _showGantt,
                          currentViewMode: _viewMode,
                        ),
                      // Main Content
                      Expanded(
                        child: _buildMainContent(isMobile, isTablet, isDesktop),
                      ),
                      // Footbar para mobile (botões de visualização)
                      if (isMobile && (_sidebarSelectedIndex == 0 || _sidebarSelectedIndex == 16 || _sidebarSelectedIndex == 20)) ...[
                        Builder(
                          builder: (context) {
                            print('🔵 Renderizando footbar (desktop) - isMobile: $isMobile, _sidebarSelectedIndex: $_sidebarSelectedIndex');
                            return _buildFootbar(isMobile, false);
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
        // Verificar se é tablet em landscape (largura >= 1024 mas altura < 1024)R
        // IMPORTANTE: Se a largura for >= 1280px, sempre usar layout desktop (horizontal)
        // mesmo que a altura seja menor, para evitar Gantt por cima da tabela em notebooks
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        final isTabletLandscape = screenWidth >= 1024 && screenWidth < 1280 && screenHeight < 1024;
        
        if (isTabletLandscape && _sidebarSelectedIndex == 0) {
          // Tablet em landscape: usar layout similar ao tablet
          print('🔵 Tablet Landscape: _selectedTab = $_selectedTab, _viewMode = $_viewMode');
          return _buildMobileContentStack();
        }
        // Se largura >= 1280px, sempre usar layout desktop (horizontal) mesmo em notebooks
        // Desktop: Layout horizontal (original) ou views específicas
      if (_sidebarSelectedIndex == 0) {
        // Se o modo for 'dashboard', mostrar dashboard de tarefas
        if (_viewMode == 'dashboard') {
          return Dashboard(
            taskService: _taskService,
            filteredTasks: _sortedTasks,
            warningsByTaskId: _warningsByTaskIdForTable,
          );
        }
        // Se o modo for 'planner', mostrar apenas o PlannerView
        if (_viewMode == 'planner') {
          return PlannerView(
            key: ValueKey('planner_${_tasksVersion}_${_sortedTasks.length}'),
            tasks: _sortedTasks,
            taskService: _taskService,
            onTasksUpdated: () async {
              print('🔄 PlannerView onTasksUpdated: Recarregando tarefas...');
              await _loadTasks();
              // Reaplicar filtros após recarregar para garantir que todas as views sejam atualizadas
              if (_currentFilters.isNotEmpty) {
                print('🔄 Reaplicando filtros após atualização do PlannerView...');
                await _applyFilters(_currentFilters);
              } else {
                // Mesmo sem filtros, garantir que as tarefas sejam atualizadas
                setState(() {
                  _tasksVersion++;
                });
              }
              print('✅ Tarefas recarregadas após atualização do PlannerView');
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
        // Desktop: Sempre mostrar tabela completa primeiro e depois o Gantt (verticalmente)
        // Caso contrário, mostrar Tabela e Gantt (ou apenas Tabela se _showGantt for false)
        if (!_showGantt) {
          return TaskTable(
            key: ValueKey('task_table_$_tasksVersion'),
            tasks: _tasksForTable,
            warningsByTaskId: _warningsByTaskIdForTable,
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
        // Desktop: Layout horizontal - tabela à esquerda, Gantt colado na lateral direita
        return LayoutBuilder(
          builder: (context, constraints) {
            // Calcular largura mínima da tabela (soma de todas as colunas)
            // Valores baseados em task_table.dart: acoes(60) + status(70) + local(90) + tipo(100) + 
            // tarefa(200) + executor(150) + coordenador(130) + frota(50) + chat(50) + anexos(50) + 
            // notasSAP(50) + ordens(50) + ats(50) + sis(50) = 1270px
            final tableMinWidth = 1300.0;
            // Limitar a largura da tabela ao máximo de 63% da tela ou largura mínima, o que for maior
            final screenWidth = constraints.maxWidth;
            final tableWidth = tableMinWidth.clamp(400.0, screenWidth * 0.62);
            
            return Row(
              children: [
                // Tabela: largura fixa baseada no conteúdo necessário
                SizedBox(
                  width: tableWidth,
                  child: TaskTable(
                    key: ValueKey('task_table_$_tasksVersion'),
                    tasks: _tasksForTable,
                    warningsByTaskId: _warningsByTaskIdForTable,
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
                // Gantt: ocupar TODO o espaço restante até a lateral direita
                Expanded(
                  child: GanttChart(
                    key: ValueKey('gantt_chart_${_tasksVersion}_${_expandedTasks.length}_${_expandedTasks.toList()..sort()}'),
                    tasks: _tasksForTable,
                    startDate: _startDate,
                    endDate: _endDate,
                    scale: _ganttScale,
                    onScaleChanged: (v) => setState(() => _ganttScale = v),
                    scrollController: _ganttScrollController,
                    taskService: _taskService,
                    allSubtasksExpanded: _allSubtasksExpanded,
                    onToggleAllSubtasks: _toggleAllSubtasks,
                    expandedTasks: _expandedTasks,
                    onTaskExpanded: _onTaskExpanded,
                    sortColumn: _sortColumn,
                    getSortValue: _getSortValue,
                    tasksForConflictDetection: _tasksSemFiltros.isNotEmpty ? _tasksSemFiltros : _tasks,
                    conflictService: _conflictService,
                    onTasksUpdated: () async {
                      // Não fazer nada aqui - a atualização será feita via onTaskUpdated específico
                      print('🔄 GanttChart onTasksUpdated: Atualização otimizada (sem reload completo)');
                    },
                    onTaskUpdated: (task) async {
                      // Atualizar apenas a tarefa específica sem recarregar tudo
                      await _updateTaskInList(task.id);
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
          },
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
            tasks: _tasksForTable,
            warningsByTaskId: _warningsByTaskIdForTable,
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
        return ResizablePanel(
          initialLeftWidth: MediaQuery.of(context).size.width * 0.5,
          minLeftWidth: 200,
          minRightWidth: 200,
          leftChild: TaskTable(
            key: ValueKey('task_table_$_tasksVersion'),
            tasks: _tasksForTable,
            warningsByTaskId: _warningsByTaskIdForTable,
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
          rightChild: GanttChart(
            key: ValueKey('gantt_chart_${_tasksVersion}_${_expandedTasks.length}_${_expandedTasks.toList()..sort()}'),
            tasks: _tasksForTable,
            startDate: _startDate,
            endDate: _endDate,
            scale: _ganttScale,
            onScaleChanged: (v) => setState(() => _ganttScale = v),
            scrollController: _ganttScrollController,
            taskService: _taskService,
            allSubtasksExpanded: _allSubtasksExpanded,
            onToggleAllSubtasks: _toggleAllSubtasks,
            sortColumn: _sortColumn,
            getSortValue: _getSortValue,
            tasksForConflictDetection: _tasksSemFiltros.isNotEmpty ? _tasksSemFiltros : _tasks,
            conflictService: _conflictService,
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
      case 1: // Pessoas / Equipes
        return TeamScheduleView(
          taskService: _taskService,
          executorService: _executorService,
          conflictService: _conflictService,
          startDate: _startDate,
          endDate: _endDate,
          filteredTasks: _tasksSemFiltros, // Equipes deve usar lista sem filtros
          teamFilters: _teamFilters,
          onTeamDataLoaded: (opts) {
            if (opts != null) {
              setState(() { _teamFilterOptions = opts; });
            }
          },
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
          conflictService: _conflictService,
          startDate: _startDate,
          endDate: _endDate,
          filteredTasks: _tasksSemFiltros,
          fleetFilters: _fleetFilters,
          onFleetDataLoaded: (opts) {
            if (opts != null) {
              setState(() { _fleetFilterOptions = opts; });
            }
          },
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
      case 3: // Demandas
        return const DemandasView();
      case 4: // Dashboard
        return ComprehensiveDashboard(
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
              tasks: _tasksForTable,
              warningsByTaskId: _warningsByTaskIdForTable,
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
          return ResizablePanel(
            initialLeftWidth: MediaQuery.of(context).size.width * 0.5,
            minLeftWidth: 200,
            minRightWidth: 200,
            leftChild: TaskTable(
              key: ValueKey('task_table_$_tasksVersion'),
              tasks: _tasksForTable,
              warningsByTaskId: _warningsByTaskIdForTable,
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
            rightChild: GanttChart(
              key: ValueKey('gantt_chart_${_tasksVersion}_${_expandedTasks.length}_${_expandedTasks.toList()..sort()}'),
              tasks: _tasksForTable,
              startDate: _startDate,
              endDate: _endDate,
              scale: _ganttScale,
              onScaleChanged: (v) => setState(() => _ganttScale = v),
              scrollController: _ganttScrollController,
              taskService: _taskService,
              allSubtasksExpanded: _allSubtasksExpanded,
              onToggleAllSubtasks: _toggleAllSubtasks,
              sortColumn: _sortColumn,
              getSortValue: _getSortValue,
              tasksForConflictDetection: _tasksSemFiltros.isNotEmpty ? _tasksSemFiltros : _tasks,
              conflictService: _conflictService,
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
        return NotasSAPView(
          searchQuery: _searchQuery,
          modoVisualizacao: _notasViewMode,
          onModoChange: (mode) {
            setState(() {
              _notasViewMode = mode;
            });
          },
        );
      case 17: // Ordens
        return OrdemView(searchQuery: _searchQuery);
      case 18: // ATs
        return const ATView();
      case 19: // SIs
        return const SIView();
      case 20: // Horas
        return HorasSAPView(
          key: _horasViewKey,
          searchQuery: _searchQuery,
          modoVisualizacao: _horasViewMode,
          onModoChange: (mode) {
            setState(() {
              _horasViewMode = mode;
            });
          },
        );
      case 21: // Linhas de Transmissão
        if (!(_authService.currentUser?.isRoot ?? false)) {
          return _rootOnlyPlaceholder('Linhas de Transmissão');
        }
        return const LinhasTransmissaoView();
      case 22: // Supressão de Vegetação (root ou jpfilho@axia.com.br)
        if (!GtdSession.canAccessGtd) {
          return _rootOnlyPlaceholder('Supressão de Vegetação');
        }
        return const SupressaoVegetacaoView();
      case 23: // Álbuns de Imagens
        return const MediaAlbumsGalleryPage();
      case 24: // Documentos
        return const DocumentsPage();
      case 25: // GTD
        if (!GtdSession.canAccessGtd) {
          return _rootOnlyPlaceholder('GTD');
        }
        return const GtdHomePage();
      case 26: // Melhorias e Bugs
        return const MelhoriasBugsHomeScreen();
      case 27: // Confirmação de Ordens
        return const ConfirmacaoOrdensView();
      default:
        if (!_showGantt) {
          return TaskTable(
            key: ValueKey('task_table_$_tasksVersion'),
            tasks: _tasksForTable,
            warningsByTaskId: _warningsByTaskIdForTable,
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
                tasks: _tasksForTable,
                warningsByTaskId: _warningsByTaskIdForTable,
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
                tasks: _tasksForTable,
                startDate: _startDate,
                endDate: _endDate,
                scale: _ganttScale,
                onScaleChanged: (v) => setState(() => _ganttScale = v),
                scrollController: _ganttScrollController,
                taskService: _taskService,
                allSubtasksExpanded: _allSubtasksExpanded,
                onToggleAllSubtasks: _toggleAllSubtasks,
                expandedTasks: _expandedTasks,
                onTaskExpanded: _onTaskExpanded,
                sortColumn: _sortColumn,
                getSortValue: _getSortValue,
                tasksForConflictDetection: _tasksSemFiltros.isNotEmpty ? _tasksSemFiltros : _tasks,
                conflictService: _conflictService,
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
    final showBackToShortcuts = widget.onBackToShortcuts != null;
    final menuVisibility = MenuVisibility.getForCurrentUser();
    return Drawer(
      child: SafeArea(
        child: showBackToShortcuts
            ? Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.home),
                    title: const Text('Início'),
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onBackToShortcuts!();
                    },
                  ),
                  const Divider(height: 1),
                  Expanded(
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
                      isRoot: menuVisibility.isRoot,
                      showGtd: menuVisibility.showGtd,
                      showGtdAndSupressao: menuVisibility.showGtdAndSupressao,
                    ),
                  ),
                ],
              )
            : Sidebar(
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
                isRoot: menuVisibility.isRoot,
                showGtd: menuVisibility.showGtd,
                showGtdAndSupressao: menuVisibility.showGtdAndSupressao,
              ),
      ),
    );
  }

  Widget _buildMobileContentStack() {
    print('🔵 _buildMobileContentStack: _selectedTab = $_selectedTab, _viewMode = $_viewMode, tasks: ${_sortedTasks.length}');
    
    // Renderizar conteúdo normalmente com tratamento de erro
    try {
      // Se o modo for 'split', mostrar ambos lado a lado com scroll horizontal (ou apenas tabela se _showGantt for false)
      if (_viewMode == 'split') {
        final screenWidth = MediaQuery.of(context).size.width;
        
        // Se _showGantt for false, mostrar apenas a tabela
        if (!_showGantt) {
          return RepaintBoundary(
            key: const ValueKey('table_boundary'),
            child: TaskTable(
              key: const ValueKey('table'),
              tasks: _tasksForTable,
              warningsByTaskId: _warningsByTaskIdForTable,
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
        }
        
        // Se _showGantt for true, mostrar ambos lado a lado
        final tableWidth = screenWidth * 0.6; // 60% para tabela
        final ganttWidth = screenWidth * 0.4; // 40% para Gantt
        
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            width: screenWidth * 1.5, // Largura total maior que a tela para permitir scroll
            child: Row(
              children: [
                SizedBox(
                  width: tableWidth,
                  child: RepaintBoundary(
                    key: const ValueKey('table_boundary'),
                    child: TaskTable(
                      key: const ValueKey('table'),
                      tasks: _tasksForTable,
                      warningsByTaskId: _warningsByTaskIdForTable,
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
                ),
                SizedBox(
                  width: ganttWidth,
                  child: RepaintBoundary(
                    key: const ValueKey('gantt_boundary'),
                    child: GanttChart(
                      key: const ValueKey('gantt'),
                      tasks: _tasksForTable,
                      startDate: _startDate,
                      endDate: _endDate,
                      scale: _ganttScale,
                      onScaleChanged: (v) => setState(() => _ganttScale = v),
                      scrollController: _ganttScrollController,
                      taskService: _taskService,
                      allSubtasksExpanded: _allSubtasksExpanded,
                      onToggleAllSubtasks: _toggleAllSubtasks,
                      expandedTasks: _expandedTasks,
                      onTaskExpanded: _onTaskExpanded,
                      sortColumn: _sortColumn,
                      getSortValue: _getSortValue,
                      tasksForConflictDetection: _tasksSemFiltros.isNotEmpty ? _tasksSemFiltros : _tasks,
                      conflictService: _conflictService,
                onTasksUpdated: () async {
                  // Não fazer nada aqui - a atualização será feita via onTaskUpdated específico
                  print('🔄 GanttChart onTasksUpdated: Atualização otimizada (sem reload completo)');
                },
                onTaskUpdated: (Task updatedTask) async {
                  // Atualizar apenas a tarefa específica sem recarregar tudo
                  print('🔄 GanttChart onTaskUpdated: Atualizando tarefa ${updatedTask.id}...');
                  await _updateTaskInList(updatedTask.id);
                  print('✅ Tarefa ${updatedTask.id} atualizada sem recarregar tudo');
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
                ),
              ],
            ),
          ),
        );
      }
      
      if (_selectedTab == 0) {
        return RepaintBoundary(
          key: const ValueKey('table_boundary'),
          child: TaskTable(
            key: const ValueKey('table'),
            tasks: _tasksForTable,
            warningsByTaskId: _warningsByTaskIdForTable,
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
            tasks: _tasksForTable,
            startDate: _startDate,
            endDate: _endDate,
            scale: _ganttScale,
            onScaleChanged: (v) => setState(() => _ganttScale = v),
            scrollController: _ganttScrollController,
            taskService: _taskService,
            allSubtasksExpanded: _allSubtasksExpanded,
            onToggleAllSubtasks: _toggleAllSubtasks,
            sortColumn: _sortColumn,
            getSortValue: _getSortValue,
            tasksForConflictDetection: _tasksSemFiltros.isNotEmpty ? _tasksSemFiltros : _tasks,
            conflictService: _conflictService,
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
            key: ValueKey('planner_${_tasksVersion}_${_sortedTasks.length}'),
            tasks: _sortedTasks,
            taskService: _taskService,
            onTasksUpdated: () async {
              print('🔄 PlannerView onTasksUpdated: Recarregando tarefas...');
              await _loadTasks();
              // Reaplicar filtros após recarregar para garantir que todas as views sejam atualizadas
              if (_currentFilters.isNotEmpty) {
                print('🔄 Reaplicando filtros após atualização do PlannerView...');
                await _applyFilters(_currentFilters);
              } else {
                // Mesmo sem filtros, garantir que as tarefas sejam atualizadas
                setState(() {
                  _tasksVersion++;
                });
              }
              print('✅ Tarefas recarregadas após atualização do PlannerView');
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
            filteredTasks: _tasks, // Passar tarefas filtradas
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
      } else if (_selectedTab == 5) {
        return RepaintBoundary(
          key: ValueKey('dashboard_boundary_${_tasksVersion}_${_sortedTasks.length}'),
          child: Dashboard(
            taskService: _taskService,
            filteredTasks: _sortedTasks,
            warningsByTaskId: _warningsByTaskIdForTable,
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
    if (!await _ensureCanEditTasks()) return;
    final result = await showDialog<Task>(
      context: context,
      builder: (context) => TaskFormDialog(
        startDate: _startDate,
        endDate: _endDate,
      ),
    );

    if (result != null) {
      // Salvar posição do scroll antes de criar
      _saveScrollPositions();
      
      print('🆕 Criando tarefa com ${result.ganttSegments.length} segmentos do Gantt');
      final createdTask = await _taskService.createTask(result);
      print('✅ Tarefa criada: ${createdTask.id} com ${createdTask.ganttSegments.length} segmentos');
      
      // Verificar se há nota SAP para vincular (quando criada a partir da tela de notas SAP)
      // Isso será feito na tela de notas SAP após receber a tarefa criada
      
      // Adicionar a nova tarefa à lista sem recarregar tudo (evita o "pisca")
      await _addTaskToList(createdTask.id);
      
      // Restaurar posição do scroll após adicionar
      _restoreScrollPositions();
      
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
    if (!await _ensureCanEditTasks()) return;
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
    if (!await _ensureCanEditTasks()) return;
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
      // Salvar posição do scroll antes de atualizar
      _saveScrollPositions();
      
      final updated = await _taskService.updateTask(taskId, result);
      if (updated != null) {
        // Atualizar apenas a tarefa específica sem recarregar tudo (evita o "pisca")
        await _updateTaskInList(taskId);
        setState(() {
          _selectedTask = null;
        });
        
        // Restaurar posição do scroll após atualizar
        _restoreScrollPositions();
        
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
    if (!await _ensureCanEditTasks()) return;
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
    // debug silenciado
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

  /// Converte valor de filtro (string única ou vírgula-separada) para lista para filterTasks.
  List<String>? _parseFilterList(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final list = value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    return list.isEmpty ? null : list;
  }

  // Aplicar filtros
  Future<void> _applyFilters(Map<String, String?> filters) async {
    try {
      _currentFilters = filters;

      // Sempre manter lista base sem filtros (apenas janela de datas) para a tela de equipes
      final baseTasks = await _taskService.filterTasks(
        status: null,
        regional: null,
        divisao: null,
        local: null,
        tipo: null,
        executor: null,
        coordenador: null,
        frota: null,
        dataInicioMin: _startDate,
        dataFimMax: _endDate,
      );
      List<Task> filtered;
      
      // Detectar se há filtros (além de "minhasTarefas") para evitar chamada extra desnecessária
      final hasFieldFilters = filters.entries.any((entry) {
        if (entry.key == 'minhasTarefas') return false;
        final value = entry.value;
        return value != null && value.isNotEmpty;
      });

      if (hasFieldFilters) {
        // Aplicar filtros específicos (multiseleção: valores em lista)
        filtered = await _taskService.filterTasks(
          status: _parseFilterList(filters['status']),
          regional: _parseFilterList(filters['regional']),
          divisao: _parseFilterList(filters['divisao']),
          local: _parseFilterList(filters['local']),
          tipo: _parseFilterList(filters['tipo']),
          executor: _parseFilterList(filters['executor']),
          coordenador: _parseFilterList(filters['coordenador']),
          frota: _parseFilterList(filters['frota']),
          dataInicioMin: _startDate,
          dataFimMax: _endDate,
        );
      } else {
        // Sem filtros (ou apenas "Minhas Tarefas"): usar base para evitar nova consulta
        filtered = baseTasks;
      }
    
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
        _tasksSemFiltros = baseTasks;
        _tasks = filtered;
        _tasksVersion++; // Incrementar versão para forçar rebuild dos widgets
      });
    } catch (e) {
      print('❌ Erro ao aplicar filtros: $e');
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
    if (!kIsWeb) {
      print('⚠️ Exportação para mobile/desktop ainda não implementada');
      return;
    }
    
    // Código apenas para web
    final bytes = utf8.encode(content);
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  // Fazer download de arquivo (bytes)
  Future<void> _downloadFileBytes(Uint8List bytes, String filename, String mimeType) async {
    if (!kIsWeb) {
      print('⚠️ Exportação para mobile/desktop ainda não implementada');
      return;
    }
    
    // Código apenas para web
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  // Buscar atividades
  Future<void> _searchTasks(String query) async {
    setState(() {
      _searchQuery = query;
    });
    // Se estiver na tela de notas, a busca será aplicada automaticamente via didUpdateWidget
    // Se estiver na tela de atividades, aplicar filtros normalmente
    if (_sidebarSelectedIndex == 0) {
      await _applyFilters(_currentFilters);
    }
    // Para outras telas (Notas SAP, etc), o didUpdateWidget do widget filho cuidará da busca
  }

  Widget _buildFootbar(bool isMobile, bool isTablet) {
    print('🔵 _buildFootbar chamado - isMobile: $isMobile, isTablet: $isTablet');
    final footbarHeight = isMobile ? 56.0 : (isTablet ? 64.0 : 60.0);
    
    final themeProvider = widget.themeProvider ?? ThemeProvider();
    final currentTheme = themeProvider.currentTheme;
    
    return StreamBuilder<String>(
      stream: ColorThemeNotifier().colorChangeStream.where((barType) => barType == 'footbar'),
      builder: (context, streamSnapshot) {
        return FutureBuilder<Map<String, Color>>(
          future: Future.wait([
            ThemeService.getBarBackgroundColor(currentTheme, barType: 'footbar'),
            ThemeService.getBarIconColor(currentTheme, barType: 'footbar'),
          ]).then((colors) => {
            'background': colors[0],
            'icon': colors[1],
          }),
          builder: (context, snapshot) {
        final backgroundColor = snapshot.data?['background'] ?? ThemeService.getBarBackgroundColorSync(currentTheme);
        final iconColor = snapshot.data?['icon'] ?? ThemeService.getBarIconColorSync(currentTheme);
        
        // Determinar quais botões mostrar baseado na tela atual
        final List<Widget> buttons = [];
        
        if (_sidebarSelectedIndex == 0) {
          // Tela de Atividades - mostrar botões de visualização
          buttons.addAll([
            _buildFootbarButton(Icons.table_chart, 'Tabela/Gantt', 'split', isMobile, isTablet, iconColor),
            _buildFootbarButton(Icons.view_kanban, 'Planner', 'planner', isMobile, isTablet, iconColor),
            _buildFootbarButton(Icons.calendar_month, 'Calendário', 'calendar', isMobile, isTablet, iconColor),
            _buildFootbarButton(Icons.dynamic_feed, 'Feed', 'feed', isMobile, isTablet, iconColor),
              _buildFootbarButton(Icons.dashboard, 'Dashboard', 'dashboard', isMobile, isTablet, iconColor),
          ]);
        } else if (_sidebarSelectedIndex == 16) {
          // Notas SAP: modos Tabela/Cards/Calendário/Dashboard
          buttons.addAll([
            _buildFootbarButton(Icons.table_chart, 'Tabela', 'notas_tabela', isMobile, isTablet, iconColor),
            _buildFootbarButton(Icons.view_module, 'Cards', 'notas_cards', isMobile, isTablet, iconColor),
            _buildFootbarButton(Icons.calendar_today, 'Calendário', 'notas_calendario', isMobile, isTablet, iconColor),
            _buildFootbarButton(Icons.dashboard, 'Dashboard', 'notas_dashboard', isMobile, isTablet, iconColor),
          ]);
        } else if (_sidebarSelectedIndex == 20) {
          // Horas: footbar troca Tabela/Metas
          buttons.addAll([
            _buildFootbarButton(Icons.table_chart, 'Tabela', 'horas_tabela', isMobile, isTablet, iconColor),
            _buildFootbarButton(Icons.track_changes, 'Metas', 'horas_metas', isMobile, isTablet, iconColor),
          ]);
        }
        
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
          children: buttons,
        ),
      ),
    );
          },
        );
      },
    );
  }

  Widget _rootOnlyPlaceholder(String nomeTela) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock, size: 64, color: Colors.redAccent),
          const SizedBox(height: 12),
          Text(
            'Acesso restrito',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            '$nomeTela disponível apenas para usuário root.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildFootbarButton(IconData icon, String label, String mode, bool isMobile, bool isTablet, Color iconColor, {int? sidebarIndex}) {
    // No mobile, verificar se o _selectedTab corresponde ao modo ou se é uma tela específica
    bool isSelected = false;
    if (sidebarIndex != null) {
      // Para telas específicas (Notas, Horas), verificar se o índice do sidebar corresponde
      isSelected = _sidebarSelectedIndex == sidebarIndex;
    } else if (mode == 'split') {
      isSelected = _selectedTab == 0 || _selectedTab == 1; // Tabela ou Gantt
    } else if (mode == 'planner') {
      isSelected = _selectedTab == 2;
    } else if (mode == 'calendar') {
      isSelected = _selectedTab == 3;
    } else if (mode == 'feed') {
      isSelected = _selectedTab == 4;
    } else if (mode == 'dashboard') {
      isSelected = _selectedTab == 5;
    } else if (mode == 'notas_tabela') {
      isSelected = _sidebarSelectedIndex == 16 && _notasViewMode == 'tabela';
    } else if (mode == 'notas_cards') {
      isSelected = _sidebarSelectedIndex == 16 && _notasViewMode == 'cards';
    } else if (mode == 'notas_calendario') {
      isSelected = _sidebarSelectedIndex == 16 && _notasViewMode == 'calendario';
    } else if (mode == 'notas_dashboard') {
      isSelected = _sidebarSelectedIndex == 16 && _notasViewMode == 'dashboard';
    } else if (mode == 'horas_tabela') {
      isSelected = _sidebarSelectedIndex == 20 && _horasViewMode == 'tabela';
    } else if (mode == 'horas_metas') {
      isSelected = _sidebarSelectedIndex == 20 && _horasViewMode == 'metas';
    } else {
      isSelected = _viewMode == mode;
    }
    
    print('🔵 _buildFootbarButton: $label, isSelected: $isSelected, icon: $icon, sidebarIndex: $sidebarIndex');
    
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            print('🔵 Footbar: Botão clicado - mode: $mode, sidebarIndex: $sidebarIndex, _selectedTab atual: $_selectedTab');
            setState(() {
              if (sidebarIndex != null) {
                // Se for uma tela específica, apenas mudar o índice do sidebar
                _sidebarSelectedIndex = sidebarIndex;
                print('🔵 Footbar: Tela específica selecionada, _sidebarSelectedIndex = $sidebarIndex');
              } else if (mode == 'notas_tabela' || mode == 'notas_cards' || mode == 'notas_calendario' || mode == 'notas_dashboard') {
                _sidebarSelectedIndex = 16;
                _notasViewMode = mode == 'notas_tabela'
                    ? 'tabela'
                    : mode == 'notas_cards'
                        ? 'cards'
                        : mode == 'notas_calendario'
                            ? 'calendario'
                            : 'dashboard';
                print('🔵 Footbar: Notas modo selecionado = $_notasViewMode');
              } else if (mode == 'horas_tabela' || mode == 'horas_metas') {
                // Footbar da tela de Horas controla Tabela/Metas
                _sidebarSelectedIndex = 20;
                _horasViewMode = mode == 'horas_tabela' ? 'tabela' : 'metas';
                print('🔵 Footbar: Horas modo selecionado = $_horasViewMode');
              } else {
                // Para modos de visualização, sincronizar _viewMode e _selectedTab
                _viewMode = mode;
                if (mode == 'planner') {
                  _selectedTab = 2;
                  print('🔵 Footbar: Planner selecionado, _selectedTab = 2');
                } else if (mode == 'calendar') {
                  _selectedTab = 3;
                  print('🔵 Footbar: Calendário selecionado, _selectedTab = 3');
                } else if (mode == 'feed') {
                  _selectedTab = 4;
                  print('🔵 Footbar: Feed selecionado, _selectedTab = 4');
                } else if (mode == 'dashboard') {
                  _selectedTab = 5;
                  print('🔵 Footbar: Dashboard selecionado, _selectedTab = 5');
                } else if (mode == 'split') {
                  _selectedTab = 0; // Default para tabela quando clicar em Tabela/Gantt
                  print('🔵 Footbar: Split selecionado, _selectedTab = 0');
                }
              }
              print('🔵 Footbar: Após setState - _viewMode = $_viewMode, _selectedTab = $_selectedTab, _sidebarSelectedIndex = $_sidebarSelectedIndex, _horasViewMode = $_horasViewMode');
            });
          },
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: isMobile ? 4 : (isTablet ? 8 : 6),
              horizontal: 4,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isSelected ? iconColor : iconColor.withOpacity(0.7),
                  size: isMobile ? 20 : (isTablet ? 26 : 24),
                ),
                SizedBox(height: isMobile ? 2 : (isTablet ? 4 : 4)),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? iconColor : iconColor.withOpacity(0.7),
                      fontSize: isMobile ? 9 : (isTablet ? 11 : 10),
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
