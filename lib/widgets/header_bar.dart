import 'package:flutter/material.dart';
import '../utils/responsive.dart';
import '../services/auth_service_simples.dart';
import '../services/theme_service.dart';
import '../providers/theme_provider.dart';
import 'perfil_usuario_view.dart';
import 'sync_status_widget.dart';

class HeaderBar extends StatefulWidget {
  final DateTime startDate;
  final DateTime endDate;
  final Function(DateTime, DateTime) onDateRangeChanged;
  final VoidCallback onCreate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onCreateSubtask;
  final VoidCallback? onMenuPressed;
  final VoidCallback? onLogout;
  final Function(String)? onSearch;
  final VoidCallback? onChat;
  final VoidCallback? onConfig;
  final VoidCallback? onPerfilUpdated;
  final Function(String)? onViewModeChanged; // Callback para mudança de modo de visualização
  final String? currentViewMode; // Modo de visualização atual
  final VoidCallback? onToggleGantt; // Callback para alternar visibilidade do Gantt
  final bool? showGantt; // Se o Gantt está visível
  final bool? isAtividadesScreen; // Se está na tela de atividades

  const HeaderBar({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.onDateRangeChanged,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
    this.onCreateSubtask,
    this.onMenuPressed,
    this.onLogout,
    this.onSearch,
    this.onChat,
    this.onConfig,
    this.onPerfilUpdated,
    this.onViewModeChanged,
    this.currentViewMode,
    this.onToggleGantt,
    this.showGantt,
    this.isAtividadesScreen,
  });

  @override
  State<HeaderBar> createState() => _HeaderBarState();
}

class _HeaderBarState extends State<HeaderBar> {
  String _perfilTexto = '';

  @override
  void initState() {
    super.initState();
    _carregarPerfilUsuario();
  }

  @override
  void didUpdateWidget(HeaderBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recarregar perfil se o widget foi atualizado (ex: após atualizar perfil)
    if (widget.onPerfilUpdated != null) {
      _carregarPerfilUsuario();
    }
  }

  Future<void> _carregarPerfilUsuario() async {
    try {
      final authService = AuthServiceSimples();
      final usuario = authService.currentUser;
      
      if (usuario != null) {
        // Usuários root mostram "ROOT" no header
        if (usuario.isRoot) {
          setState(() {
            _perfilTexto = 'ROOT';
          });
          return;
        }
        
        // Usuários normais mostram regional.divisão
        if (usuario.temPerfilConfigurado()) {
          // Pegar primeira regional e primeira divisão
          final regional = usuario.regionais.isNotEmpty ? usuario.regionais.first : '';
          final divisao = usuario.divisoes.isNotEmpty ? usuario.divisoes.first : '';
          
          if (regional.isNotEmpty && divisao.isNotEmpty) {
            setState(() {
              _perfilTexto = '$regional.$divisao';
            });
          } else if (regional.isNotEmpty) {
            setState(() {
              _perfilTexto = regional;
            });
          } else {
            setState(() {
              _perfilTexto = '';
            });
          }
        } else {
          setState(() {
            _perfilTexto = '';
          });
        }
      } else {
        setState(() {
          _perfilTexto = '';
        });
      }
    } catch (e) {
      print('Erro ao carregar perfil do usuário no header: $e');
      setState(() {
        _perfilTexto = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final themeProvider = ThemeProvider();
    final currentTheme = themeProvider.currentTheme;
    
    final backgroundColor = ThemeService.getBarBackgroundColor(currentTheme);
    final textColor = ThemeService.getBarTextColor(currentTheme);
    final iconColor = ThemeService.getBarIconColor(currentTheme);
    
    return Container(
      height: isMobile ? 60 : 60,
      color: backgroundColor,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 16),
      child: isMobile 
          ? _buildMobileHeader(context, textColor, iconColor)
          : _buildDesktopHeader(context, textColor, iconColor),
    );
  }

  Widget _buildMobileHeader(BuildContext context, Color textColor, Color iconColor) {
    final themeProvider = ThemeProvider();
    final currentTheme = themeProvider.currentTheme;
    final backgroundColor = ThemeService.getBarBackgroundColor(currentTheme);
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Primeira linha: Menu e Usuário
        SizedBox(
          height: 30,
          child: Row(
            children: [
              // Botão de menu para abrir drawer
              IconButton(
                icon: Icon(Icons.menu, color: iconColor, size: 18),
                  onPressed: widget.onMenuPressed,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
              Builder(
                builder: (context) => PopupMenuButton<String>(
                  offset: const Offset(0, 40),
                  color: Colors.white,
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'perfil',
                      child: Row(
                        children: [
                          Icon(Icons.person, size: 18, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Meu Perfil', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    if (widget.onLogout != null)
                      const PopupMenuItem(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(Icons.logout, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Sair', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                  ],
                  onSelected: (value) async {
                    if (value == 'perfil') {
                      final resultado = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PerfilUsuarioView(),
                        ),
                      );
                      // Se o perfil foi atualizado (resultado == true), recarregar tarefas
                      if (resultado == true && widget.onPerfilUpdated != null) {
                        widget.onPerfilUpdated!();
                        _carregarPerfilUsuario(); // Recarregar perfil após atualização
                      }
                    } else if (value == 'logout') {
                      widget.onLogout?.call();
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: textColor,
                          child: Icon(Icons.person, size: 14, color: backgroundColor),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            AuthServiceSimples().getUserName() ?? 'Usuário',
                            style: TextStyle(color: textColor, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Segunda linha: Título e ações
        SizedBox(
          height: 38,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _perfilTexto.isNotEmpty
                      ? 'Programação Mensal: $_perfilTexto'
                      : 'Programação Mensal',
                  style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SyncStatusWidget(),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(Icons.add, color: iconColor, size: 18),
                onPressed: widget.onCreate,
                tooltip: 'Criar',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
              IconButton(
                icon: Icon(Icons.chat, color: iconColor, size: 18),
                onPressed: widget.onChat,
                tooltip: 'Chat',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
              IconButton(
                icon: Icon(Icons.settings, color: iconColor, size: 18),
                onPressed: widget.onConfig,
                tooltip: 'Configurações',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopHeader(BuildContext context, Color textColor, Color iconColor) {
    final themeProvider = ThemeProvider();
    final currentTheme = themeProvider.currentTheme;
    final backgroundColor = ThemeService.getBarBackgroundColor(currentTheme);
    
    // Verificar tipo de dispositivo
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);
    final isDesktop = Responsive.isDesktop(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeDesktop = isDesktop && screenWidth >= 1280;
    
    return Builder(
      builder: (context) => Row(
        children: [
          // Usuário e título
          CircleAvatar(
            radius: 16,
            backgroundColor: textColor,
            child: Icon(Icons.person, size: 20, color: backgroundColor),
          ),
          const SizedBox(width: 12),
          Text(
            AuthServiceSimples().getUserName() ?? AuthServiceSimples().getUserEmail() ?? 'Usuário',
            style: TextStyle(color: textColor, fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _perfilTexto.isNotEmpty
                        ? 'Programação Mensal: $_perfilTexto'
                        : 'Programação Mensal',
                    style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.onSearch != null && !isMobile && !isTablet) ...[
                  const SizedBox(width: 12),
                  Flexible(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 200),
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: TextField(
                        onChanged: widget.onSearch,
                        decoration: const InputDecoration(
                          hintText: 'Buscar...',
                          prefixIcon: Icon(Icons.search, size: 18),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Seletor de visualização (apenas quando onViewModeChanged estiver definido E estiver na tela de atividades)
          // Em mobile/tablet, esses botões devem estar no footbar (não aparecem aqui)
          // Em desktop grande (>=1280px), mostrar no header
          if (widget.onViewModeChanged != null && 
              widget.currentViewMode != null && 
              widget.isAtividadesScreen == true &&
              !isMobile && 
              !isTablet && 
              isLargeDesktop) ...[
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                color: textColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildViewModeButton(Icons.table_chart, 'Tabela/Gantt', 'split'),
                  _buildViewModeButton(Icons.view_kanban, 'Planner', 'planner'),
                  _buildViewModeButton(Icons.calendar_month, 'Calendário', 'calendar'),
                  _buildViewModeButton(Icons.dynamic_feed, 'Feed', 'feed'),
                ],
              ),
            ),
          ],
          // Botão para mostrar/ocultar Gantt (apenas quando o modo for 'split')
          if (widget.onToggleGantt != null && widget.currentViewMode == 'split') ...[
            const SizedBox(width: 8),
            Tooltip(
              message: widget.showGantt == true ? 'Ocultar Gantt' : 'Mostrar Gantt',
              child: IconButton(
                icon: Icon(
                  widget.showGantt == true ? Icons.timeline : Icons.timeline_outlined,
                  color: iconColor,
                  size: 20,
                ),
                onPressed: widget.onToggleGantt,
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
            ),
          ],
          const SizedBox(width: 20),
          // Seletor de datas (clicável)
          InkWell(
            onTap: () async {
              // Mostrar date range picker
              final DateTimeRange? picked = await showDateRangePicker(
                context: context,
                initialDateRange: DateTimeRange(start: widget.startDate, end: widget.endDate),
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
                locale: const Locale('pt', 'BR'),
              );
              if (picked != null) {
                widget.onDateRangeChanged(picked.start, picked.end);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_formatDate(widget.startDate)} a ${_formatDate(widget.endDate)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.calendar_today, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Widget de status de sincronização
          const SyncStatusWidget(),
          const SizedBox(width: 8),
          // Ações
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: iconColor),
            onPressed: widget.onCreate,
            tooltip: 'Criar',
          ),
          IconButton(
            icon: Icon(Icons.chat, color: iconColor),
            onPressed: widget.onChat,
            tooltip: 'Chat',
          ),
          IconButton(
            icon: Icon(Icons.settings, color: iconColor),
            onPressed: widget.onConfig,
            tooltip: 'Configurações',
          ),
          const SizedBox(width: 8),
          const SizedBox(width: 8),
          // Menu do usuário com perfil e logout
          PopupMenuButton<String>(
            icon: Icon(Icons.account_circle, color: iconColor),
            color: Colors.white,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'perfil',
                child: Row(
                  children: [
                    Icon(Icons.person, size: 20, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Meu Perfil'),
                  ],
                ),
              ),
              if (widget.onLogout != null)
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 20, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Sair'),
                    ],
                  ),
                ),
            ],
            onSelected: (value) async {
              if (value == 'perfil') {
                final resultado = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PerfilUsuarioView(),
                  ),
                );
                // Se o perfil foi atualizado (resultado == true), recarregar tarefas
                if (resultado == true && widget.onPerfilUpdated != null) {
                  widget.onPerfilUpdated!();
                  _carregarPerfilUsuario(); // Recarregar perfil após atualização
                }
              } else if (value == 'logout') {
                widget.onLogout?.call();
              }
            },
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year.toString().substring(2)}';
  }

  Widget _buildViewModeButton(IconData icon, String tooltip, String mode) {
    final themeProvider = ThemeProvider();
    final currentTheme = themeProvider.currentTheme;
    final iconColor = ThemeService.getBarIconColor(currentTheme);
    
    final isSelected = widget.currentViewMode == mode;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => widget.onViewModeChanged?.call(mode),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? iconColor.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            icon,
            color: isSelected ? iconColor : iconColor.withOpacity(0.7),
            size: 20,
          ),
        ),
      ),
    );
  }
}

