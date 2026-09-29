import 'package:flutter/material.dart';
import '../../../../models/task.dart';
import '../../../../models/comunidade.dart';
import '../../../../models/grupo_chat.dart';
import '../../../../services/task_service.dart';
import '../../../../services/chat_service.dart';
import '../../../../widgets/task_cards_view.dart';
import '../../../../widgets/chat_screen.dart';
import '../../../../widgets/chat_grupos_list.dart';
import '../../core/theme/tf_mobile_spacing.dart';
import '../../core/theme/tf_mobile_typography.dart';
import '../../core/theme/tf_mobile_colors.dart';
import '../../core/navigation/tf_mobile_navigator.dart';
import '../chat/widgets/tf_conversation_tile.dart';
import '../chat/widgets/tf_community_tile.dart';

/// Aba de Feed Corporativo & Comunicação Integrada do TaskFlow Mobile.
/// Conecta-se diretamente aos serviços reais de dados do TaskFlow:
/// - Feed Operacional: TaskCardsView com mídias, curtidas e comentários reais das atividades.
/// - Mensagens: Grupos reais de chat das atividades.
/// - Comunidades: Comunidades reais do Supabase.
/// Regra do projeto: ZERO DADOS MOCADOS.
class MobileFeedScreen extends StatefulWidget {
  final TFMobileNavigator navigator;

  const MobileFeedScreen({
    super.key,
    required this.navigator,
  });

  @override
  State<MobileFeedScreen> createState() => _MobileFeedScreenState();
}

class _MobileFeedScreenState extends State<MobileFeedScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TaskService _taskService = TaskService();
  final ChatService _chatService = ChatService();

  List<Task> _tasks = [];
  bool _isLoadingTasks = true;

  List<Comunidade> _comunidades = [];
  List<GrupoChat> _grupos = [];
  bool _isLoadingChat = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadTasks();
    _loadChatData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoadingTasks = true);
    try {
      List<Task> loadedTasks = _taskService.tasks;
      if (loadedTasks.isEmpty) {
        loadedTasks = await _taskService.getAllTasks();
      }
      if (mounted) {
        setState(() {
          _tasks = loadedTasks;
          _isLoadingTasks = false;
        });
        // Se ainda não carregou os grupos das tarefas, busca agora com as tarefas carregadas
        if (_grupos.isEmpty && _tasks.isNotEmpty) {
          _loadChatData();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _tasks = _taskService.tasks;
          _isLoadingTasks = false;
        });
      }
    }
  }

  Future<void> _loadChatData() async {
    setState(() => _isLoadingChat = true);
    try {
      final comunidades = await _chatService.listarComunidades();

      List<GrupoChat> grupos = [];
      final taskList = _tasks.isNotEmpty ? _tasks : _taskService.tasks;
      if (taskList.isNotEmpty) {
        final taskIds = taskList.map((t) => t.id).toList();
        final rawGrupos = await _chatService.obterGruposPorTarefasIds(taskIds);
        grupos = rawGrupos.where((g) => g.id != null && g.id!.isNotEmpty).toList();
        // Ordenar por data da última mensagem ou atualização mais recente
        grupos.sort((a, b) {
          final dateA = a.ultimaMensagemAt ?? a.updatedAt ?? a.createdAt ?? DateTime(2000);
          final dateB = b.ultimaMensagemAt ?? b.updatedAt ?? b.createdAt ?? DateTime(2000);
          return dateB.compareTo(dateA);
        });
      }

      if (mounted) {
        setState(() {
          _comunidades = comunidades;
          _grupos = grupos;
          _isLoadingChat = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingChat = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = TFMobileColors.surface(context);
    final borderColor = TFMobileColors.border(context);

    return Scaffold(
      backgroundColor: TFMobileColors.background(context),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48.0),
        child: Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            border: Border(bottom: BorderSide(color: borderColor, width: 1.0)),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: TFMobileColors.primaryBlue,
            unselectedLabelColor: TFMobileColors.textSecondary(context),
            indicatorColor: TFMobileColors.primaryBlue,
            indicatorWeight: 3.0,
            tabs: const [
              Tab(text: 'Feed Operacional'),
              Tab(text: 'Mensagens'),
              Tab(text: 'Comunidades'),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFeedView(),
          _buildMessagesView(),
          _buildCommunitiesView(),
        ],
      ),
    );
  }

  // ==========================================
  // 1. VISÃO DO FEED OPERACIONAL REAL
  // Usa o TaskCardsView oficial do sistema com todas as fotos reais,
  // mensagens de chat, contagens SAP e curtidas em tempo real
  // ==========================================
  Widget _buildFeedView() {
    if (_isLoadingTasks && _tasks.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_tasks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(TFMobileSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.dynamic_feed, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Nenhuma atividade encontrada no Feed.',
                style: TFMobileTypography.titleMedium.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        final refreshed = await _taskService.getAllTasks(ignoreCache: true);
        if (mounted) {
          setState(() {
            _tasks = refreshed;
          });
        }
      },
      child: TaskCardsView(
        tasks: _tasks,
        onEdit: (task) => widget.navigator.openTaskDetail(task.id),
      ),
    );
  }

  // ==========================================
  // 2. VISÃO DE MENSAGENS E CHATS OPERACIONAIS REAIS
  // ==========================================
  Widget _buildMessagesView() {
    if (_isLoadingChat && _grupos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_grupos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(TFMobileSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.chat_bubble_outline_rounded, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Nenhuma conversa ativa no momento',
                style: TFMobileTypography.titleMedium.copyWith(
                  color: TFMobileColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'As mensagens e fotos enviadas pelas turmas de campo em cada atividade aparecerão aqui.',
                style: TFMobileTypography.bodyMedium.copyWith(
                  color: TFMobileColors.textSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadChatData,
      child: ListView.separated(
        itemCount: _grupos.length,
        separatorBuilder: (_, __) => const Divider(height: 1.0),
        itemBuilder: (context, index) {
          final grupo = _grupos[index];
          final timeStr = grupo.ultimaMensagemAt != null
              ? '${grupo.ultimaMensagemAt!.day.toString().padLeft(2, '0')}/${grupo.ultimaMensagemAt!.month.toString().padLeft(2, '0')}'
              : '';

          return TFConversationTile(
            title: grupo.tarefaNome,
            lastMessage: (grupo.ultimaMensagemPreview != null && grupo.ultimaMensagemPreview!.isNotEmpty)
                ? grupo.ultimaMensagemPreview!
                : (grupo.descricao?.isNotEmpty == true ? grupo.descricao! : 'Chat da atividade'),
            time: timeStr,
            subtitleTag: 'Atividade',
            unreadCount: grupo.mensagensNaoLidas ?? 0,
            onTap: () {
              if (grupo.id != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      body: ChatScreen(
                        grupoId: grupo.id!,
                        onBack: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }

  // ==========================================
  // 3. VISÃO DE COMUNIDADES CORPORATIVAS REAIS
  // ==========================================
  Widget _buildCommunitiesView() {
    if (_isLoadingChat && _comunidades.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_comunidades.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(TFMobileSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.groups_outlined, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Nenhuma comunidade cadastrada',
                style: TFMobileTypography.titleMedium.copyWith(
                  color: TFMobileColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Comunidades por divisão e segmento técnico cadastradas no sistema serão listadas aqui.',
                style: TFMobileTypography.bodyMedium.copyWith(
                  color: TFMobileColors.textSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadChatData,
      child: ListView.builder(
        padding: const EdgeInsets.all(TFMobileSpacing.md),
        itemCount: _comunidades.length,
        itemBuilder: (context, index) {
          final com = _comunidades[index];
          final name = '${com.divisaoNome} - ${com.segmentoNome}';
          final desc = (com.descricao != null && com.descricao!.isNotEmpty)
              ? com.descricao!
              : (com.regionalNome.isNotEmpty ? 'Regional ${com.regionalNome}' : 'Comunidade Operacional');

          return TFCommunityTile(
            name: name,
            description: desc,
            category: com.regionalNome.isNotEmpty ? com.regionalNome : 'Geral',
            membersCount: com.totalMensagens ?? 0,
            unreadCount: 0,
            icon: Icons.domain_rounded,
            onTap: () {
              if (com.id != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      body: ChatGruposList(
                        comunidadeId: com.id!,
                        onGrupoSelected: (grupoId) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => Scaffold(
                                body: ChatScreen(
                                  grupoId: grupoId,
                                  onBack: () => Navigator.of(context).pop(),
                                ),
                              ),
                            ),
                          );
                        },
                        onBack: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }
}
