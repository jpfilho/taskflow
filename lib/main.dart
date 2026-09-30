import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'dart:async';
import 'dart:convert' show utf8;
import 'dart:typed_data' show Uint8List;
import 'package:excel/excel.dart' hide Border;

// Import condicional para web
import 'html_stub.dart' as html if (dart.library.html) 'dart:html';
import 'mobile/core/responsive/tf_mobile_responsive.dart';
import 'mobile/core/config/mobile_feature_flags.dart';
import 'models/task.dart';
import 'models/task_sort_rule.dart';
import 'services/task_service.dart';
import 'services/performance_monitor.dart';
import 'services/conflict_service.dart';
import 'config/supabase_config.dart';
import 'widgets/header_bar.dart';
import 'widgets/filter_bar.dart';
import 'widgets/sidebar.dart';
import 'widgets/task_table.dart';
import 'widgets/gantt_chart.dart';
import 'widgets/activity_gantt_view.dart';
import 'widgets/hourly_calendar_view.dart';
import 'widgets/task_cards_view.dart';
import 'widgets/planner_view.dart';
import 'widgets/task_form_dialog.dart';
import 'widgets/task_view_dialog.dart';
import 'widgets/dashboard.dart';
import 'widgets/comprehensive_dashboard.dart';
import 'widgets/team_schedule_view.dart';
import 'models/equipe.dart';
import 'services/executor_service.dart';
import 'services/equipe_service.dart';
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
import 'services/chat_service.dart';
import 'services/unread_chat_manager.dart';
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
import 'design_system/taskflow_design_system.dart';
import 'widgets/sync_status_widget.dart';
import 'widgets/perfil_usuario_view.dart';
import 'features/warnings/warnings.dart';
import 'widgets/resizable_panel.dart';
import 'services/auth_service_simples.dart';
import 'services/nota_sap_service.dart';
import 'services/ordem_service.dart';
import 'utils/responsive.dart';
import 'config/app_menu_config.dart';

import 'services/local_database_service.dart';
import 'services/sync_service.dart';
import 'services/connectivity_service.dart';
import 'services/version_check_service.dart';
import 'providers/theme_provider.dart';
import 'services/theme_service.dart';
import 'utils/file_export_helper.dart';
import 'services/pdf_service.dart';
import 'features/media_albums/presentation/pages/gallery_page.dart';
import 'features/documents/presentation/pages/documents_page.dart';
import 'modules/gtd/domain/gtd_session.dart';
import 'modules/gtd/presentation/screens/gtd_home_page.dart';
import 'modules/melhorias_bugs/presentation/screens/melhorias_bugs_home_screen.dart';
import 'widgets/activity_report_view.dart';
import 'features/ai_assistants/presentation/screens/ai_assistants_list_screen.dart';
import 'features/projetos/presentation/screens/projetos_home_screen.dart';
import 'design_system/gallery/design_system_gallery.dart';
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
          onGenerateRoute: (settings) {
            if (kDebugMode && settings.name == '/debug/design-system') {
              return MaterialPageRoute(
                settings: settings,
                builder: (_) => DesignSystemGallery(themeProvider: _themeProvider),
              );
            }
            return null;
          },
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

    // Mobile / Tablet estreito (< 768px): fluxo móvel oficial com tela de atalhos e Drawer integrado
    if (Responsive.isMobileForHome(context)) {
      return _AuthenticatedMobileShell(
        themeProvider: widget.themeProvider,
        onLogout: () {
          _authService.signOut();
          UnreadChatManager().resetUser(null);
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
        UnreadChatManager().resetUser(null);
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
  String? _selectedViewMode;
  int? _selectedTab;

  void _onShortcutTap(int index, {String? viewMode, int? selectedTab}) {
    setState(() {
      _showShortcuts = false;
      _selectedSidebarIndex = index;
      _selectedViewMode = viewMode;
      _selectedTab = selectedTab;
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
      initialViewMode: _selectedViewMode,
      initialSelectedTab: _selectedTab,
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
  /// Modo de visualização inicial (ex: 'feed', 'split', etc).
  final String? initialViewMode;
  /// Aba selecionada inicial (ex: 0=tabela, 4=feed).
  final int? initialSelectedTab;
  /// Callback para voltar à tela de atalhos (mobile); evita back para login.
  final VoidCallback? onBackToShortcuts;
  /// True quando foi aberto a partir da tela de atalhos no mobile.
  final bool isMobileFromShortcuts;

  const MainScreen({
    super.key,
    this.themeProvider,
    this.onLogout,
    this.initialSidebarIndex,
    this.initialViewMode,
    this.initialSelectedTab,
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
  final NotaSAPService _notaSapService = NotaSAPService();
  final OrdemService _ordemService = OrdemService();
  final PDFService _pdfService = PDFService();
  final EquipeService _equipeService = EquipeService();
  
  List<Task> _tasks = []; // Tarefas filtradas (para telas gerais)
  bool _isTasksLoading = true; // Flag para indicar carregamento em andamento
  List<Task> _tasksSemFiltros = []; // Tarefas sem filtros (para tela de equipes)
  Task? _selectedTask; // Tarefa selecionada para edição/deleção
  Map<String, String?> _currentFilters = {}; // Filtros ativos (tela Atividades)
  bool _isFiltering = false; // Indica se os filtros estão sendo processados (feedback visual)
  Map<String, String?> _fleetFilters = {}; // Filtros da tela Frota (Regional, Divisão, Frota, Local)
  Map<String, List<String>>? _fleetFilterOptions; // Opções dos dropdowns da Frota (regionais, divisoes, frotas, locais)
  Map<String, String?> _teamFilters = {}; // Filtros da tela Equipes (divisao, empresa, funcao, matricula, nome)
  Map<String, List<String>>? _teamFilterOptions; // Opções dos dropdowns da Equipes
  List<Equipe> _todasEquipes = []; // Equipes do perfil do usuário logado
  List<String> _nomesEquipesPerfil = []; // Nomes das equipes para o dropdown de Atividades
  String _searchQuery = ''; // Termo de busca atual
  Set<String>? _conflictFilterTaskIds; // Filtro de tarefas com conflitos
  // Inicializar com primeiro e último dia do mês/ano atual
  late DateTime _startDate;
  late DateTime _endDate;
  int _selectedTab = 0; // Para mobile: 0 = Tabela, 1 = Gantt, 2 = Planner, 3 = Calendário, 4 = Feed, 5 = Dashboard
  String _viewMode = 'split'; // 'split', 'table', 'gantt', 'planner', 'calendar', 'feed', 'report'
  bool _sidebarExpanded = false; // Estado da sidebar (expandida/retraída)
  int _sidebarSelectedIndex = 0; // Índice selecionado na sidebar (0 = Grid/Tabela)
  bool _allSubtasksExpanded = false; // Estado compartilhado: todas as subtarefas expandidas ou colapsadas
  Set<String> _expandedTasks = {}; // IDs das tarefas expandidas (compartilhado entre tabela e Gantt)
  int _tasksVersion = 0; // Versão das tarefas para forçar rebuild quando necessário
  bool _showGantt = true; // Controla se o Gantt está visível
  GanttScale _ganttScale = GanttScale.daily; // Escala do eixo temporal do Gantt
  bool _showHourlyView = false; // Ativa/desativa visualização horária no Gantt
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

  // Gerenciador central de contagem de mensagens não lidas
  final UnreadChatManager _unreadChatManager = UnreadChatManager();
  int _unreadChatCount = 0;
  Timer? _chatCountTimer;

  /// Atualiza o índice da sidebar e, se estiver SAINDO do chat (index 15),
  /// recarrega o snapshot de mensagens não lidas no manager.
  void _setSidebarIndex(int newIndex) {
    final wasInChat = _sidebarSelectedIndex == 15;
    _sidebarSelectedIndex = newIndex;
    if (wasInChat && newIndex != 15) {
      _unreadChatManager.refreshAll();
    }
  }

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

  void _toggleHourlyView() {
    setState(() {
      _showHourlyView = !_showHourlyView;
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
      if (email.isEmpty) {
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
    if (widget.initialViewMode != null) {
      _viewMode = widget.initialViewMode!;
    }
    if (widget.initialSelectedTab != null) {
      _selectedTab = widget.initialSelectedTab!;
    }
    // Inicializar datas com primeiro e último dia do mês/ano atual
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0); // Último dia do mês atual
    
    // Carregar tarefas (do Supabase ou mock)
    _loadTasks();

    // Carregar equipes do perfil do usuário logado (para filtro de equipe em Atividades)
    _loadEquipesPerfil();

    // Carregar permissões de edição/criação de tarefas
    _loadTaskEditPermission();
    
    // Sincronizar scroll entre tabela e Gantt (100% sincronizado)
    _tableScrollController.addListener(_syncTableToGantt);
    _ganttScrollController.addListener(_syncGanttToTable);
    TaskSortService.instance.rulesNotifier.addListener(_onSortRulesChanged);

    // Inicializar UnreadChatManager de forma suave após o primeiro frame (sem bloquear renderização de tarefas)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _unreadChatManager.initialize();
      }
    });

    // Timer de 90s atua estritamente como reconciliação periódica de segurança
    _chatCountTimer = Timer.periodic(const Duration(seconds: 90), (_) {
      _unreadChatManager.scheduleReconciliation('watchdog_timer', delay: Duration.zero);
    });
  }

  @override
  void didUpdateWidget(covariant MainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSidebarIndex != null && widget.initialSidebarIndex != oldWidget.initialSidebarIndex) {
      _setSidebarIndex(widget.initialSidebarIndex!);
    }
    if (widget.initialViewMode != null && widget.initialViewMode != oldWidget.initialViewMode) {
      setState(() {
        _viewMode = widget.initialViewMode!;
      });
    }
    if (widget.initialSelectedTab != null && widget.initialSelectedTab != oldWidget.initialSelectedTab) {
      setState(() {
        _selectedTab = widget.initialSelectedTab!;
      });
    }
  }

  @override
  void dispose() {
    // Remover listeners antes de dispor
    _tableScrollController.removeListener(_syncTableToGantt);
    _ganttScrollController.removeListener(_syncGanttToTable);
    TaskSortService.instance.rulesNotifier.removeListener(_onSortRulesChanged);
    _tableScrollController.dispose();
    _ganttScrollController.dispose();
    _chatCountTimer?.cancel();
    super.dispose();
  }

  void _onSortRulesChanged() {
    if (mounted) {
      setState(() {
        _sortColumn = TaskSortService.instance.primaryColumn;
        _sortAscending = TaskSortService.instance.primaryAscending;
        _tasks = _sortTasks(_tasks);
        _tasksSemFiltros = _sortTasks(_tasksSemFiltros);
        _applyFilters(_currentFilters);
      });
    }
  }

  /// Recarrega o snapshot de mensagens não lidas no manager (reconciliação sob demanda).
  Future<void> _carregarContagemChat() async {
    try {
      await _unreadChatManager.refreshAll();
    } catch (e) {
      debugPrint('⚠️ Erro ao sincronizar contagem de chat: $e');
    }
  }

  // Função para ordenar tarefas por período (data de início e fim)
  // Estado de ordenação
  String _sortColumn = TaskSortService.instance.primaryColumn; // Coluna padrão ajustada para LOCAL
  bool _sortAscending = TaskSortService.instance.primaryAscending; // Direção padrão: crescente
  
  int _compareTasksByColumn(Task a, Task b, String column) {
    DateTime getStart(Task t) {
      if (t.ganttSegments.isNotEmpty) {
        return t.ganttSegments.first.dataInicio;
      }
      return t.dataInicio;
    }

    DateTime getEnd(Task t) {
      if (t.ganttSegments.isNotEmpty) {
        return t.ganttSegments.first.dataFim;
      }
      return t.dataFim;
    }

    switch (column) {
      case 'PERÍODO':
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
        final compStart = aStart.compareTo(bStart);
        if (compStart != 0) return compStart;
        return aEnd.compareTo(bEnd);

      case 'STATUS':
        final statusA = a.statusNome.isNotEmpty ? a.statusNome : a.status;
        final statusB = b.statusNome.isNotEmpty ? b.statusNome : b.status;
        return statusA.compareTo(statusB);

      case 'LOCAL':
        final localA = a.locais.isNotEmpty ? a.locais.first : '';
        final localB = b.locais.isNotEmpty ? b.locais.first : '';
        return localA.compareTo(localB);

      case 'TIPO':
        return a.tipo.compareTo(b.tipo);

      case 'TAREFA':
        return a.tarefa.compareTo(b.tarefa);

      case 'EXECUTOR':
        return a.executor.compareTo(b.executor);

      case 'COORDENADOR':
        return a.coordenador.compareTo(b.coordenador);

      default:
        return a.dataInicio.compareTo(b.dataInicio);
    }
  }

  List<Task> _sortTasks(List<Task> tasks) {
    if (tasks.isEmpty) return [];
    final sortedTasks = List<Task>.from(tasks);
    final rules = TaskSortService.instance.rules;

    sortedTasks.sort((a, b) {
      for (final rule in rules) {
        final comp = _compareTasksByColumn(a, b, rule.column);
        if (comp != 0) {
          return rule.ascending ? comp : -comp;
        }
      }
      // Se empatar em todos os critérios configurados, desempata pelo período (data início)
      return _compareTasksByColumn(a, b, 'PERÍODO');
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
    try {
      final map = await TaskWarningsService.getWarningsByTaskId();
      if (mounted) setState(() => _warningsByTaskId = map);
    } catch (e) {
      if (mounted) setState(() => _warningsByTaskId = {});
    }
  }
  
  Future<void> _loadEquipesPerfil() async {
    try {
      final usuario = _authService.currentUser;
      List<Equipe> equipes = [];

      if (usuario != null && !usuario.isRoot && usuario.temPerfilConfigurado()) {
        equipes = await _equipeService.getEquipesPorPerfilUsuario(
          regionalIds: usuario.regionalIds,
          divisaoIds: usuario.divisaoIds,
          segmentoIds: usuario.segmentoIds,
        );
      } else {
        equipes = await _equipeService.getEquipesAtivas();
      }

      final nomes = equipes.map((e) => e.nome.trim()).where((n) => n.isNotEmpty).toSet().toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      if (mounted) {
        setState(() {
          _todasEquipes = equipes;
          _nomesEquipesPerfil = nomes;
        });
      }
    } catch (e) {
      print('⚠️ Erro ao carregar equipes do perfil do usuário para filtro: $e');
    }
  }

  // Método para atualizar ordenação
  void _updateSorting(String column, bool ascending) {
    print('🔄 main.dart: _updateSorting chamado - column=$column, ascending=$ascending');
    setState(() {
      _sortColumn = column;
      _sortAscending = ascending;
    });
    TaskSortService.instance.setPrimaryRule(column, ascending);
    print('🔄 main.dart: _sortColumn atualizado para $_sortColumn');
  }

  // Carregar tarefas do Supabase ou mock
  // Adicionar uma nova tarefa à lista sem recarregar tudo (evita o "pisca" ao criar)
  Future<void> _addTaskToList(String taskId, [Task? preloadedTask]) async {
    try {
      // Usar a tarefa pré-carregada ou buscar do banco com joins completos
      final newTask = preloadedTask ?? await _taskService.getTaskById(taskId);
      if (newTask == null) {
        print('⚠️ Tarefa $taskId não encontrada após criação');
        return;
      }

      // Atualizar na base completa em memória
      final semFiltroIndex = _tasksSemFiltros.indexWhere((t) => t.id == taskId);
      if (semFiltroIndex != -1) {
        _tasksSemFiltros[semFiltroIndex] = newTask;
      } else {
        _tasksSemFiltros.add(newTask);
      }

      // Reaplicar filtros vigentes de forma canônica
      if (_currentFilters.isNotEmpty) {
        await _applyFilters(_currentFilters);
      } else {
        setState(() {
          final index = _tasks.indexWhere((t) => t.id == taskId);
          if (index != -1) {
            _tasks[index] = newTask;
          } else {
            _tasks.add(newTask);
          }
          _tasksVersion++;
        });
      }

      // Recarregar alertas para incluir possíveis warnings da nova tarefa
      await _loadWarnings();

      print('✅ Tarefa $taskId adicionada à lista local mantendo filtros (versão: $_tasksVersion)');
    } catch (e, stackTrace) {
      print('❌ Erro ao adicionar tarefa à lista: $e');
      print('   Stack trace: $stackTrace');
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

      // 1. Atualizar na lista completa sem filtros (_tasksSemFiltros)
      final semFiltroIndex = _tasksSemFiltros.indexWhere((t) => t.id == taskId);
      if (semFiltroIndex != -1) {
        _tasksSemFiltros[semFiltroIndex] = updatedTask;
      } else {
        _tasksSemFiltros.add(updatedTask);
      }

      // 2. Reaplicar os filtros atuais usando a filtragem canônica completa
      // Se houver filtros, _applyFilters garante que tarefas com multiseleção por vírgula,
      // equipes e executores permaneçam visíveis sem sumir.
      if (_currentFilters.isNotEmpty) {
        await _applyFilters(_currentFilters);
      } else {
        setState(() {
          final index = _tasks.indexWhere((t) => t.id == taskId);
          if (index != -1) {
            _tasks[index] = updatedTask;
          } else {
            _tasks.add(updatedTask);
          }
          _tasksVersion++;
        });
      }

      // Recarregar alertas para refletir correção de warning (ex.: status PROG→CONC)
      await _loadWarnings();

      print('✅ Tarefa $taskId atualizada na lista local mantendo filtros (versão: $_tasksVersion)');
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
    print('🚀 [DEBUG-LOAD] 1. _loadTasks() INICIADO | periodo: ${_startDate.toIso8601String()} ate ${_endDate.toIso8601String()}');
    if (mounted) setState(() => _isTasksLoading = true);
    PerformanceMonitor.start('MainScreen._loadTasks');
    try {
      print('🔍 [DEBUG-LOAD] 2. Disparando _taskService.filterTasks...');
      final sw = Stopwatch()..start();
      final baseTasks = await _taskService.filterTasks(
        dataInicioMin: _startDate,
        dataFimMax: _endDate,
      );
      sw.stop();
      print('📦 [DEBUG-LOAD] 3. _taskService.filterTasks RETORNOU ${baseTasks.length} tarefas em ${sw.elapsedMilliseconds}ms');

      _tasksSemFiltros = baseTasks;

      if (mounted) {
        if (_currentFilters.isNotEmpty) {
          print('🔍 [DEBUG-LOAD] 4. Aplicando filtros ativos: $_currentFilters');
          await _applyFilters(_currentFilters);
          print('📦 [DEBUG-LOAD] 4.1. Filtros aplicados | _tasks=${_tasks.length}');
        } else {
          print('📦 [DEBUG-LOAD] 4. Nenhum filtro ativo, atribuindo baseTasks à lista _tasks (${baseTasks.length})');
          setState(() {
            _tasks = baseTasks;
          });
        }

        setState(() {
          _isTasksLoading = false;
          _tasksVersion++;
        });
        print('✅ [DEBUG-LOAD] 5. setState concluído: _isTasksLoading=false, _tasks=${_tasks.length}, _tasksForTable=${_tasksForTable.length}');

        print('🔍 [DEBUG-LOAD] 6. Disparando _loadWarnings() em background...');
        _loadWarnings().then((_) {
          print('📦 [DEBUG-LOAD] 6.1. Warnings carregados: ${_warningsByTaskId?.length ?? 0} registros');
        }).catchError((e) {
          print('⚠️ [DEBUG-LOAD] 6.1. Erro ao carregar warnings (ignorado): $e');
        });

        if (!_autoSyncTriggeredAfterLoad) {
          _autoSyncTriggeredAfterLoad = true;
          print('🔄 [DEBUG-LOAD] 7. Disparando SyncService().syncAll() em background...');
          SyncService().syncAll();
        }
        print('🏁 [DEBUG-LOAD] 8. _loadTasks() FINALIZADO COM SUCESSO!');
      } else {
        print('⚠️ [DEBUG-LOAD] MainScreen NÃO montado após filterTasks.');
      }
    } catch (e, stack) {
      print('❌ [DEBUG-LOAD] ERRO CRÍTICO em _loadTasks: $e');
      print('Stack trace: $stack');
      if (mounted) setState(() => _isTasksLoading = false);
    } finally {
      PerformanceMonitor.stop('MainScreen._loadTasks');
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
      bottomNavigationBar: isMobile
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Segunda footer bar para telas com modos específicos (Atividades, Notas SAP, Horas SAP)
                if (_sidebarSelectedIndex == 0 || _sidebarSelectedIndex == 16 || _sidebarSelectedIndex == 20)
                  _buildFootbar(isMobile, false),
                // Footer bar global permanente para todas as telas
                _buildMobileGlobalFooterBar(),
              ],
            )
          : null,
      body: isMobile
          ? SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // Header Bar
                  if (isMobile && _sidebarSelectedIndex == 0 && (_viewMode == 'feed' || _selectedTab == 4))
                    _buildMobileFeedHeader()
                  else if (_sidebarSelectedIndex != 15 && !(isMobile && _sidebarSelectedIndex == 14))
                    HeaderBar(
                    startDate: _startDate,
                    endDate: _endDate,
                    onDateRangeChanged: (start, end) {
                      setState(() {
                        _startDate = start;
                        _endDate = end;
                      });
                      _loadTasks();
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
                        _setSidebarIndex(15);
                      });
                    },
                    unreadChatCount: _unreadChatCount,
                    isConflictFilterActive: _conflictFilterTaskIds != null,
                    onClearConflictFilter: () {
                      setState(() {
                        _conflictFilterTaskIds = null;
                      });
                    },
                    onConfig: () {
                      setState(() {
                        _setSidebarIndex(14);
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
                    showHourlyView: _showHourlyView,
                    onToggleHourlyView: _toggleHourlyView,
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
                  else if (_sidebarSelectedIndex != 3 &&
                      _sidebarSelectedIndex != 14 &&
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
                      _sidebarSelectedIndex != 26 &&
                      _sidebarSelectedIndex != 27 &&
                      _sidebarSelectedIndex != 28 &&
                      _sidebarSelectedIndex != 29 &&
                      !(_sidebarSelectedIndex == 0 && (_viewMode == 'feed' || _selectedTab == 4)))
                    FilterBar(
                      onFiltersChanged: _applyFilters,
                      initialFilters: _currentFilters,
                      startDate: _startDate,
                      endDate: _endDate,
                      visibleTasks: _tasksSemFiltros,
                      onSortChanged: _updateSorting,
                      currentSortColumn: _sortColumn,
                      currentSortAscending: _sortAscending,
                      isFiltering: _isFiltering,
                      filterOnlyWithWarnings: _filterOnlyWithWarnings,
                      onFilterOnlyWithWarnings: (v) => setState(() => _filterOnlyWithWarnings = v),
                      warningsCountInTable: _tasksWithWarningsCount,
                      warningsTotalCount: _warningsTotalCount,
                      equipesDisponiveis: _nomesEquipesPerfil,
                      onToggleGantt: () {
                        setState(() {
                          final newShowGantt = !_showGantt;
                          _showGantt = newShowGantt;
                          if (isMobile) {
                            if (newShowGantt) {
                              _selectedTab = 1;
                            } else {
                              _selectedTab = 0;
                            }
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
                      _setSidebarIndex(index);
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
                          });
                          _loadTasks();
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
                            _setSidebarIndex(15);
                          });
                        },
                        unreadChatCount: _unreadChatCount,
                        isConflictFilterActive: _conflictFilterTaskIds != null,
                        onClearConflictFilter: () {
                          setState(() {
                            _conflictFilterTaskIds = null;
                          });
                        },
                        onConfig: () {
                          setState(() {
                            _setSidebarIndex(14);
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
                        showHourlyView: _showHourlyView,
                        onToggleHourlyView: _toggleHourlyView,
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
                      else if (_sidebarSelectedIndex != 3 &&
                          _sidebarSelectedIndex != 14 &&
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
                          _sidebarSelectedIndex != 26 &&
                          _sidebarSelectedIndex != 27 &&
                          _sidebarSelectedIndex != 28 &&
                          _sidebarSelectedIndex != 29)
                        FilterBar(
                          onFiltersChanged: _applyFilters,
                          initialFilters: _currentFilters,
                          startDate: _startDate,
                          endDate: _endDate,
                          visibleTasks: _tasksSemFiltros,
                          onSortChanged: _updateSorting,
                          currentSortColumn: _sortColumn,
                          currentSortAscending: _sortAscending,
                          isFiltering: _isFiltering,
                          filterOnlyWithWarnings: _filterOnlyWithWarnings,
                          onFilterOnlyWithWarnings: (v) => setState(() => _filterOnlyWithWarnings = v),
                          warningsCountInTable: _tasksWithWarningsCount,
                          warningsTotalCount: _warningsTotalCount,
                          equipesDisponiveis: _nomesEquipesPerfil,
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
        // Modo relatório de impressão
        if (_viewMode == 'report') {
          return ActivityReportView(
            key: ValueKey('report_${_tasksVersion}_${_startDate}_${_endDate}'),
            tasks: _tasks,
            startDate: _startDate,
            endDate: _endDate,
            notaSapService: _notaSapService,
            ordemService: _ordemService,
          );
        }
        // Desktop: widget unificado que elimina dessincronização vertical
        print('🖥️ [DEBUG-BUILD] Renderizando ActivityGanttView: _tasksForTable=${_tasksForTable.length}, _tasks=${_tasks.length}, _isTasksLoading=$_isTasksLoading');
        return ActivityGanttView(
          key: const ValueKey('activity_gantt'),
          tasks: _tasksForTable,
          startDate: _startDate,
          endDate: _endDate,
          scale: _ganttScale,
          onScaleChanged: (v) => setState(() => _ganttScale = v),
          taskService: _taskService,
          conflictService: _conflictService,
          tasksForConflictDetection: _tasksSemFiltros.isNotEmpty ? _tasksSemFiltros : _tasks,
          tasksVersion: _tasksVersion,
          allSubtasksExpanded: _allSubtasksExpanded,
          onToggleAllSubtasks: _toggleAllSubtasks,
          expandedTasks: _expandedTasks,
          onTaskExpanded: _onTaskExpanded,
          sortColumn: _sortColumn,
          getSortValue: _getSortValue,
          warningsByTaskId: _warningsByTaskIdForTable,
          isLoading: _isTasksLoading,
          conflictFilterTaskIds: _conflictFilterTaskIds,
          onFilterConflictTasks: (taskIds) {
            setState(() {
              _conflictFilterTaskIds = taskIds;
            });
          },
          onTaskSelected: (task) => _showTaskDetails(task),
          onEdit: (task, {executorIdToEdit}) => _editTaskById(
            task.id,
            initialTabIndex: executorIdToEdit != null ? 3 : null,
            initialExecutorIdToEdit: executorIdToEdit,
          ),
          onDelete: (task) => _deleteTaskById(task.id),
          onDuplicate: (task) => _duplicateTask(task),
          onCreateSubtask: (task) {
            if (task.isMainTask) _createSubtask(task.id);
          },
          onTasksUpdated: () async {
            await _updateTaskInList('');
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
                isLoading: _isTasksLoading,
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
                isLoading: _isTasksLoading,
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
          rightChild: _ganttScale == GanttScale.hourly
              ? HourlyCalendarView(
                  tasks: _tasksForTable,
                  startDate: _startDate,
                  endDate: _endDate,
                )
              : GanttChart(
            key: ValueKey('gantt_chart_${_expandedTasks.length}_${_expandedTasks.toList()..sort()}'),
            tasks: _tasksForTable,
            tasksVersion: _tasksVersion,
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
            showHourlyView: _showHourlyView,
            onHourlyViewChanged: (_) => _toggleHourlyView(),
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
          tasksVersion: _tasksVersion,
          teamFilters: _teamFilters,
          onTeamDataLoaded: (opts) {
            setState(() { _teamFilterOptions = opts; });
                    },
          onEdit: (task, {executorIdToEdit}) => _editTaskById(
            task.id,
            initialTabIndex: 3, // Aba Datas
            initialExecutorIdToEdit: executorIdToEdit,
          ),
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
            setState(() { _fleetFilterOptions = opts; });
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
                isLoading: _isTasksLoading,
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
                isLoading: _isTasksLoading,
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
              key: ValueKey('gantt_chart_${_expandedTasks.length}_${_expandedTasks.toList()..sort()}'),
              tasks: _tasksForTable,
              tasksVersion: _tasksVersion,
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
              showHourlyView: _showHourlyView,
              onHourlyViewChanged: (_) => _toggleHourlyView(),
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
        return ChatView(
          onMenuPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        );
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
      case 28: // Assistentes IA
        return const AiAssistantsListScreen();
      case 29: // Projetos
        return const ProjetosHomeScreen();
      default:
        if (!_showGantt) {
          return TaskTable(
                isLoading: _isTasksLoading,
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
                isLoading: _isTasksLoading,
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
                key: ValueKey('gantt_chart_${_expandedTasks.length}_${_expandedTasks.toList()..sort()}'),
                tasks: _tasksForTable,
                tasksVersion: _tasksVersion,
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
                showHourlyView: _showHourlyView,
                onHourlyViewChanged: (_) => _toggleHourlyView(),
              ),
            ),
          ],
        );
    }
  }

  Widget _buildDrawer() {
    final showBackToShortcuts = widget.onBackToShortcuts != null;
    final menuVisibility = MenuVisibility.getForCurrentUser();
    final themeProvider = widget.themeProvider ?? ThemeProvider();
    final currentTheme = themeProvider.currentTheme;
    final barBg = ThemeService.getBarBackgroundColorSync(currentTheme);
    final iconColor = ThemeService.getBarIconColorSync(currentTheme);
    final user = _authService.currentUser;
    final userName = _authService.getUserName() ?? 'Usuário';
    final userEmail = user?.email ?? '';

    return Drawer(
      backgroundColor: barBg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabeçalho de perfil do Drawer
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              decoration: BoxDecoration(
                color: barBg,
                border: Border(
                  bottom: BorderSide(
                    color: iconColor.withValues(alpha: 0.15),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: iconColor.withValues(alpha: 0.15),
                        child: Text(
                          userName.isNotEmpty ? userName.substring(0, 1).toUpperCase() : 'U',
                          style: TextStyle(
                            color: iconColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: TextStyle(
                                color: iconColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (userEmail.isNotEmpty)
                              Text(
                                userEmail,
                                style: TextStyle(
                                  color: iconColor.withValues(alpha: 0.7),
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: iconColor, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: user?.isRoot == true
                              ? Colors.red.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          user?.isRoot == true ? 'ROOT' : 'OPERADOR',
                          style: TextStyle(
                            color: iconColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (!kIsWeb)
                        const SyncStatusWidget(),
                    ],
                  ),
                ],
              ),
            ),

            // Botão Início (Atalhos Rápidos)
            if (showBackToShortcuts)
              Container(
                margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: Material(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onBackToShortcuts!();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Icon(Icons.apps_rounded, color: iconColor, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Início (Painel de Atalhos)',
                              style: TextStyle(
                                color: iconColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Icon(Icons.chevron_right, color: iconColor.withValues(alpha: 0.5), size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Módulos do TaskFlow via Sidebar oficial expandida
            Expanded(
              child: Sidebar(
                isExpanded: true,
                customWidth: double.infinity,
                onToggle: () {
                  Navigator.of(context).pop();
                },
                selectedIndex: _sidebarSelectedIndex,
                onItemSelected: (index) {
                  setState(() {
                    _setSidebarIndex(index);
                  });
                  Navigator.of(context).pop();
                },
                onExport: _exportData,
                isRoot: menuVisibility.isRoot,
                showGtd: menuVisibility.showGtd,
                showGtdAndSupressao: menuVisibility.showGtdAndSupressao,
              ),
            ),

            // Rodapé do Drawer com Perfil e Logout
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: barBg,
                border: Border(
                  top: BorderSide(
                    color: iconColor.withValues(alpha: 0.15),
                  ),
                ),
              ),
              child: Row(
                children: [
                  TextButton.icon(
                    icon: Icon(Icons.person_outline, size: 18, color: iconColor),
                    label: Text('Meu Perfil', style: TextStyle(fontSize: 12, color: iconColor)),
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PerfilUsuarioView()),
                      );
                    },
                  ),
                  const Spacer(),
                  if (widget.onLogout != null)
                    TextButton.icon(
                      icon: const Icon(Icons.logout, size: 18, color: Colors.redAccent),
                      label: const Text('Sair', style: TextStyle(fontSize: 12, color: Colors.redAccent)),
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onLogout!();
                      },
                    ),
                ],
              ),
            ),
          ],
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
                isLoading: _isTasksLoading,
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
                isLoading: _isTasksLoading,
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
                      tasksVersion: _tasksVersion,
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
                isLoading: _isTasksLoading,
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
            tasksVersion: _tasksVersion,
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
          key: ValueKey('calendar_boundary_$_tasksVersion'),
          child: MaintenanceCalendarView(
            key: ValueKey('calendar_$_tasksVersion'),
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
      await _addTaskToList(createdSubtask.id, createdSubtask);
      _showSuccessMessage('Subtarefa criada com sucesso!');
    }
  }

  Future<void> _editTaskById(String taskId, {int? initialTabIndex, String? initialExecutorIdToEdit}) async {
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
        initialTabIndex: initialTabIndex,
        initialExecutorIdToEdit: initialExecutorIdToEdit,
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
    
    final createdTask = await _taskService.createTask(duplicatedTask);

    // Se o filtro de tarefas em conflito estiver ativo e a original estava nele, incluir a duplicada
    if (_conflictFilterTaskIds != null && _conflictFilterTaskIds!.contains(task.id)) {
      setState(() {
        _conflictFilterTaskIds = {..._conflictFilterTaskIds!, createdTask.id};
      });
    }

    // Adiciona a tarefa diretamente na base em memória e reaplica os filtros ativos
    // sem recarregar tudo do zero (evita que a original e a duplicada sumam da visualização)
    await _addTaskToList(createdTask.id, createdTask);
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
              Navigator.of(context).pop();
              final deleted = await _taskService.deleteTask(taskId);
              if (deleted) {
                await _loadTasks();
                // Reaplicar filtros para preservar os filtros ativos
                if (_currentFilters.isNotEmpty) {
                  await _applyFilters(_currentFilters);
                }
                if (mounted) {
                  setState(() {
                    _selectedTask = null;
                  });
                  _showSuccessMessage('Atividade excluída com sucesso!');
                }
              } else {
                if (mounted) {
                  _showErrorMessage('Erro ao excluir atividade');
                }
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
      builder: (context) => TaskViewDialog(
        task: task,
        onEdit: (t) => _editTaskById(t.id),
      ),
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

  /// Converte string CSV em Set<String> (usado na filtragem client-side)
  Set<String> _parseFilterSet(String? value) {
    if (value == null || value.trim().isEmpty) return {};
    return value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
  }

  // Aplicar filtros
  Future<void> _applyFilters(Map<String, String?> filters) async {
    if (mounted) setState(() => _isFiltering = true);
    try {
      _currentFilters = filters;

      // ─── Filtragem 100% no cliente usando _tasksSemFiltros já em memória ───
      // Nenhuma query ao banco — _tasksSemFiltros é a lista base carregada por
      // _loadTasks() com a janela de datas atual. Só vai ao banco quando a janela
      // de datas muda (via _loadTasks).
      List<Task> filtered = List.from(_tasksSemFiltros);

      // Pré-processar conjuntos de filtros (multiseleção separada por vírgula)
      final statusSet      = _parseFilterSet(filters['status']);
      final regionalSet    = _parseFilterSet(filters['regional']);
      final divisaoSet     = _parseFilterSet(filters['divisao']);
      final localSet       = _parseFilterSet(filters['local']);
      final tipoSet        = _parseFilterSet(filters['tipo']);
      final equipeSet      = _parseFilterSet(filters['equipe']);
      final executorSet    = _parseFilterSet(filters['executor']);
      final coordenadorSet = _parseFilterSet(filters['coordenador']);
      final frotaSet       = _parseFilterSet(filters['frota']);
      final minhasTarefas  = filters['minhasTarefas'] == 'true';

      // Mapear dados das equipes selecionadas para correlacionar tarefas diretamente ou por membros executores
      Set<String>? selectedEquipeIds;
      Set<String>? selectedEquipeNomes;
      Set<String>? selectedEquipeExecutorIds;
      Set<String>? selectedEquipeExecutorNomes;

      if (equipeSet.isNotEmpty && !equipeSet.contains('todos')) {
        selectedEquipeIds = {};
        selectedEquipeNomes = {};
        selectedEquipeExecutorIds = {};
        selectedEquipeExecutorNomes = {};

        for (final eq in _todasEquipes) {
          final eqId = eq.id.trim().toLowerCase();
          final eqNome = eq.nome.trim().toLowerCase();
          if (equipeSet.any((sel) {
            final s = sel.trim().toLowerCase();
            return eqId == s || eqNome == s || eqNome.contains(s) || s.contains(eqNome);
          })) {
            selectedEquipeIds.add(eqId);
            selectedEquipeNomes.add(eqNome);
            for (final ee in eq.executores) {
              final execId = ee.executorId.trim().toLowerCase();
              if (execId.isNotEmpty) selectedEquipeExecutorIds.add(execId);
              final execNome = ee.executorNome.trim().toLowerCase();
              if (execNome.isNotEmpty) selectedEquipeExecutorNomes.add(execNome);
            }
          }
        }
      }

      final hasFieldFilters = statusSet.isNotEmpty ||
          regionalSet.isNotEmpty || divisaoSet.isNotEmpty ||
          localSet.isNotEmpty    || tipoSet.isNotEmpty    ||
          equipeSet.isNotEmpty   || executorSet.isNotEmpty ||
          coordenadorSet.isNotEmpty || frotaSet.isNotEmpty;

      if (hasFieldFilters) {
        filtered = filtered.where((task) {
          if (statusSet.isNotEmpty) {
            final s = (task.statusNome.isNotEmpty ? task.statusNome : task.status).toLowerCase();
            if (!statusSet.any((f) => s.contains(f.toLowerCase()))) return false;
          }
          if (regionalSet.isNotEmpty) {
            final r = task.regional.toLowerCase();
            if (!regionalSet.any((f) => r.contains(f.toLowerCase()))) return false;
          }
          if (divisaoSet.isNotEmpty) {
            final d = task.divisao.toLowerCase();
            if (!divisaoSet.any((f) => d.contains(f.toLowerCase()))) return false;
          }
          if (localSet.isNotEmpty) {
            if (!task.locais.any((l) => localSet.any((f) => l.toLowerCase().contains(f.toLowerCase())))) return false;
          }
          if (tipoSet.isNotEmpty) {
            final t = task.tipo.toLowerCase();
            if (!tipoSet.any((f) => t.contains(f.toLowerCase()))) return false;
          }
          if (equipeSet.isNotEmpty && !equipeSet.contains('todos')) {
            // 1. Associação direta à equipe (por ID ou nome na tarefa)
            final activeIds = selectedEquipeIds;
            final activeNomes = selectedEquipeNomes;
            final activeExecIds = selectedEquipeExecutorIds;
            final activeExecNomes = selectedEquipeExecutorNomes;

            final matchesDirectEquipe = (activeIds != null && task.equipeIds.any((id) => activeIds.contains(id.trim().toLowerCase()))) ||
                task.equipes.any((eq) {
                  final eqLower = eq.trim().toLowerCase();
                  return equipeSet.any((sel) {
                    final s = sel.trim().toLowerCase();
                    return eqLower == s || eqLower.contains(s) || s.contains(eqLower);
                  }) || (activeNomes != null && activeNomes.contains(eqLower));
                });

            // 2. Associação indireta: qualquer executor da tarefa pertence à equipe selecionada (mesmo princípio da tela Equipe e Frota)
            final matchesTeamMember = (activeExecIds != null && (
                task.executorIds.any((id) => activeExecIds.contains(id.trim().toLowerCase())) ||
                task.executorPeriods.any((ep) => activeExecIds.contains(ep.executorId.trim().toLowerCase()))
            )) || (activeExecNomes != null && activeExecNomes.isNotEmpty && (
                task.executores.any((ex) => activeExecNomes.contains(ex.trim().toLowerCase())) ||
                (task.executor.isNotEmpty && activeExecNomes.any((en) => task.executor.toLowerCase().contains(en)))
            ));

            if (!matchesDirectEquipe && !matchesTeamMember) return false;
          }
          if (executorSet.isNotEmpty) {
            final execMatch = executorSet.any((f) {
              final fl = f.toLowerCase();
              return task.executor.toLowerCase().contains(fl) ||
                  task.executores.any((e) => e.toLowerCase().contains(fl));
            });
            if (!execMatch) return false;
          }
          if (coordenadorSet.isNotEmpty) {
            final c = task.coordenador.toLowerCase();
            if (!coordenadorSet.any((f) => c.contains(f.toLowerCase()))) return false;
          }
          if (frotaSet.isNotEmpty) {
            final frotaMatch = frotaSet.any((f) {
              final fl = f.toLowerCase();
              return (task.frota.toLowerCase().contains(fl)) ||
                  task.frotaIds.any((id) => id.toLowerCase().contains(fl));
            });
            if (!frotaMatch) return false;
          }
          return true;
        }).toList();
      }

      // Filtro "Minhas Tarefas"
      if (minhasTarefas) {
        final authService = AuthServiceSimples();
        final usuario = authService.currentUser;
        final loginUsuario = usuario?.email ?? authService.getUserEmail() ?? '';

        if (loginUsuario.isNotEmpty) {
          Set<String> executorIdsDoUsuario;
          Set<String> nomesExecutoresDoUsuario;

          if (_cachedLoginUsuario == loginUsuario &&
              _cachedExecutorIds != null &&
              _cachedExecutorNomes != null) {
            executorIdsDoUsuario = _cachedExecutorIds!;
            nomesExecutoresDoUsuario = _cachedExecutorNomes!;
          } else {
            final executoresDoUsuario =
                await _executorService.getExecutoresPorLogin(loginUsuario);
            if (executoresDoUsuario.isEmpty) {
              filtered = [];
              _cachedLoginUsuario = loginUsuario;
              _cachedExecutorIds = {};
              _cachedExecutorNomes = {};
              executorIdsDoUsuario = {};
              nomesExecutoresDoUsuario = {};
            } else {
              executorIdsDoUsuario =
                  executoresDoUsuario.map((e) => e.id).toSet();
              nomesExecutoresDoUsuario = executoresDoUsuario
                  .map((e) => e.nome.toLowerCase().trim())
                  .toSet();
              _cachedLoginUsuario = loginUsuario;
              _cachedExecutorIds = executorIdsDoUsuario;
              _cachedExecutorNomes = nomesExecutoresDoUsuario;
            }
          }

          if (executorIdsDoUsuario.isNotEmpty) {
            filtered = filtered.where((task) {
              if (task.executorIds.any((id) => executorIdsDoUsuario.contains(id))) return true;
              final execLower = task.executor.toLowerCase().trim();
              if (execLower.isNotEmpty && nomesExecutoresDoUsuario.contains(execLower)) return true;
              if (task.executores.any((n) => nomesExecutoresDoUsuario.contains(n.toLowerCase().trim()))) return true;
              final coordLower = task.coordenador.toLowerCase().trim();
              if (coordLower.isNotEmpty && nomesExecutoresDoUsuario.contains(coordLower)) return true;
              return false;
            }).toList();
          }
        }
      } else {
        _cachedLoginUsuario = null;
        _cachedExecutorIds = null;
        _cachedExecutorNomes = null;
      }

      // Busca por texto livre
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

      if (mounted) {
        setState(() {
          _tasks = filtered;
          _tasksVersion++;
        });
      }
    } catch (e) {
      print('❌ Erro ao aplicar filtros: $e');
    } finally {
      if (mounted) setState(() => _isFiltering = false);
    }
  }


  // Exportar dados - Mostrar diálogo de escolha de formato
  Future<void> _exportData() async {
    if (!mounted) return;
    
    // Mostrar diálogo para escolher formato
    final formato = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.file_download_outlined, color: Colors.blue),
            SizedBox(width: 8),
            Text('Exportar Programação'),
          ],
        ),
        content: const Text('Escolha o formato desejado para exportar as atividades:'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context, 'CSV'),
            icon: const Icon(Icons.table_chart, size: 20),
            label: const Text('CSV'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(context, 'Excel'),
            icon: const Icon(Icons.table_view, size: 20),
            label: const Text('Excel (.xlsx)'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(context, 'PDF'),
            icon: const Icon(Icons.picture_as_pdf, size: 20),
            label: const Text('PDF'),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gerando arquivo $formato...'),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Obter tarefas para exportar (prioriza tarefas filtradas/visíveis atuais)
      final tasksToExport = _tasksSemFiltros.isNotEmpty
          ? (_tasks.isNotEmpty ? _tasks : _tasksSemFiltros)
          : (_tasks.isNotEmpty ? _tasks : await _taskService.getAllTasks());

      if (tasksToExport.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nenhuma atividade disponível para exportação.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final now = DateTime.now();
      final nowStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      ExportResult result;

      switch (formato) {
        case 'CSV':
          final filename = 'programacao_atividades_$nowStr.csv';
          final csvContent = await _generateCSV(tasksToExport);
          result = await FileExportHelper.exportString(
            content: csvContent,
            filename: filename,
            mimeType: 'text/csv',
            subject: 'Programação de Atividades (CSV)',
          );
          break;
        case 'Excel':
          final filename = 'programacao_atividades_$nowStr.xlsx';
          final excelBytes = await _generateExcel(tasksToExport);
          result = await FileExportHelper.exportBytes(
            bytes: excelBytes,
            filename: filename,
            mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            subject: 'Programação de Atividades (Excel)',
          );
          break;
        case 'PDF':
          final filename = 'programacao_atividades_$nowStr.pdf';
          final pdfBytes = await _pdfService.generateTasksPDF(
            tasksToExport,
            startDate: _startDate,
            endDate: _endDate,
          );
          result = await FileExportHelper.exportBytes(
            bytes: pdfBytes,
            filename: filename,
            mimeType: 'application/pdf',
            subject: 'Programação de Atividades (PDF)',
          );
          break;
        default:
          return;
      }

      if (!mounted) return;

      if (result.success) {
        await FileExportHelper.showExportSuccessDialog(
          context,
          result,
          itemsCount: tasksToExport.length,
          formatName: formato,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao exportar arquivo: ${result.errorMessage ?? 'Falha desconhecida'}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      print('❌ Erro ao exportar dados: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao exportar dados: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
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
    final footbarHeight = isMobile ? 48.0 : (isTablet ? 64.0 : 60.0);
    
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
        border: Border(
          bottom: BorderSide(
            color: Colors.black.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        bottom: false,
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

  Widget _buildMobileFeedHeader() {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(color: colors.borderSubtle),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.menu_rounded, color: colors.textPrimary),
            tooltip: 'Menu',
            onPressed: () {
              _scaffoldKey.currentState?.openDrawer();
            },
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Feed de Atividades',
              style: typography.cardTitle.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
          if (_isAtividadesRefreshing)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: colors.textMuted),
              tooltip: 'Atualizar feed',
              onPressed: _refreshAtividades,
            ),
        ],
      ),
    );
  }

  Widget _buildMobileGlobalFooterBar() {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    final isFeedActive = _sidebarSelectedIndex == 0 && (_selectedTab == 4 || _viewMode == 'feed');
    final isProgramacaoActive = _sidebarSelectedIndex == 0 && !isFeedActive;
    final isChatActive = _sidebarSelectedIndex == 15;
    final isConfigActive = _sidebarSelectedIndex == 14;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.borderSubtle),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMobileFooterItem(
                icon: Icons.home_rounded,
                label: 'Início',
                isSelected: false,
                colors: colors,
                typography: typography,
                onTap: () {
                  widget.onBackToShortcuts?.call();
                },
              ),
              _buildMobileFooterItem(
                icon: Icons.grid_view_rounded,
                label: 'Programação',
                isSelected: isProgramacaoActive,
                colors: colors,
                typography: typography,
                onTap: () {
                  setState(() {
                    _setSidebarIndex(0);
                    _viewMode = 'split';
                    _selectedTab = 0;
                  });
                },
              ),
              _buildMobileFooterItem(
                icon: Icons.dynamic_feed_rounded,
                label: 'Feed',
                isSelected: isFeedActive,
                colors: colors,
                typography: typography,
                onTap: () {
                  setState(() {
                    _setSidebarIndex(0);
                    _viewMode = 'feed';
                    _selectedTab = 4;
                  });
                },
              ),
              _buildMobileFooterItem(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Chat',
                isSelected: isChatActive,
                colors: colors,
                typography: typography,
                onTap: () {
                  _setSidebarIndex(15);
                },
              ),
              _buildMobileFooterItem(
                icon: Icons.settings_rounded,
                label: 'Config',
                isSelected: isConfigActive,
                colors: colors,
                typography: typography,
                onTap: () {
                  _setSidebarIndex(14);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileFooterItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required TFSemanticColors colors,
    required TFTypography typography,
    required VoidCallback onTap,
  }) {
    final activeColor = colors.primary;
    final inactiveColor = colors.textMuted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? activeColor : inactiveColor,
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: typography.labelSmall.copyWith(
                color: isSelected ? activeColor : inactiveColor,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
