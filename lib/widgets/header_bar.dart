import 'package:flutter/material.dart';
import '../utils/responsive.dart';
import '../services/auth_service_simples.dart';
import '../services/theme_service.dart';
import '../providers/theme_provider.dart';
import 'perfil_usuario_view.dart';
import 'sync_status_widget.dart';
import 'dart:async';

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
  final bool canEditTasks; // Se pode criar/editar tarefas e ver config

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
    this.canEditTasks = true,
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
    
    return StreamBuilder<String>(
      stream: ColorThemeNotifier().colorChangeStream.where((barType) => barType == 'appbar'),
      builder: (context, streamSnapshot) {
        return FutureBuilder<Map<String, Color>>(
          future: Future.wait([
            ThemeService.getBarBackgroundColor(currentTheme, barType: 'appbar'),
            ThemeService.getBarTextColor(currentTheme, barType: 'appbar'),
            ThemeService.getBarIconColor(currentTheme, barType: 'appbar'),
          ]).then((colors) => {
            'background': colors[0],
            'text': colors[1],
            'icon': colors[2],
          }),
          builder: (context, snapshot) {
        final backgroundColor = snapshot.data?['background'] ?? ThemeService.getBarBackgroundColorSync(currentTheme);
        final textColor = snapshot.data?['text'] ?? ThemeService.getBarTextColorSync(currentTheme);
        final iconColor = snapshot.data?['icon'] ?? ThemeService.getBarIconColorSync(currentTheme);
        
        return Container(
          // No mobile, deixe a altura se ajustar ao conteúdo para evitar overflow.
          height: isMobile ? null : 60,
          color: backgroundColor,
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 8 : 16,
            vertical: isMobile ? 8 : 0,
          ),
          child: isMobile 
              ? _buildMobileHeader(context, textColor, iconColor)
              : _buildDesktopHeader(context, textColor, iconColor),
        );
          },
        );
      },
    );
  }

  Widget _buildMobileHeader(BuildContext context, Color textColor, Color iconColor) {
    final themeProvider = ThemeProvider();
    final currentTheme = themeProvider.currentTheme;
    final barBackground = ThemeService.getBarBackgroundColorSync(currentTheme);
    
    // Mobile: linha compacta ocupando toda a largura, colada às laterais.
    return SizedBox(
      height: 44,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Container(
          width: MediaQuery.of(context).size.width,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.menu, color: iconColor, size: 20),
                    onPressed: widget.onMenuPressed,
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  const SizedBox(width: 6),
                  PopupMenuButton<String>(
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
                        if (resultado == true && widget.onPerfilUpdated != null) {
                          widget.onPerfilUpdated!();
                          _carregarPerfilUsuario();
                        }
                      } else if (value == 'logout') {
                        widget.onLogout?.call();
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 11,
                          backgroundColor: textColor,
                          child: Icon(Icons.person, size: 13, color: barBackground),
                        ),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 120),
                          child: Text(
                            AuthServiceSimples().getUserName() ?? 'Usuário',
                            style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Center(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDateRangePicker(
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today, size: 15, color: Colors.black87),
                          const SizedBox(width: 6),
                          Text(
                            '${_formatShortDate(widget.startDate)}-${_formatShortDate(widget.endDate)}',
                            style: const TextStyle(fontSize: 12, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.add, color: iconColor, size: 20),
                    onPressed: widget.canEditTasks ? widget.onCreate : null,
                    tooltip: 'Criar',
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  const SizedBox(width: 6),
                  if (widget.canEditTasks)
                    IconButton(
                      icon: Icon(Icons.settings, color: iconColor, size: 20),
                      onPressed: widget.onConfig,
                      tooltip: 'Configurações',
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopHeader(BuildContext context, Color textColor, Color iconColor) {
    final themeProvider = ThemeProvider();
    final currentTheme = themeProvider.currentTheme;
    final backgroundColor = ThemeService.getBarBackgroundColorSync(currentTheme);
    
    // Verificar tipo de dispositivo
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);
    final isDesktop = Responsive.isDesktop(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isLargeDesktop = isDesktop && screenWidth >= 1280;
    
    // Detectar se é tablet mesmo quando em landscape (largura > 1024 mas altura < 1024)
    final isTabletLandscape = !isMobile && screenWidth >= 1024 && screenHeight < 1024;
    
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
          // Em desktop grande (>=1280px) ou tablet (incluindo landscape), mostrar no header
          if (widget.onViewModeChanged != null && 
              widget.currentViewMode != null && 
              widget.isAtividadesScreen == true &&
              !isMobile && 
              (isTablet || isTabletLandscape || isLargeDesktop)) ...[
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
                  _buildViewModeButton(Icons.dashboard, 'Dashboard', 'dashboard'),
                ],
              ),
            ),
          ],
          // Botão para mostrar/ocultar Gantt (apenas quando o modo for 'split' E estiver na tela de atividades)
          if (widget.onToggleGantt != null && 
              widget.currentViewMode == 'split' && 
              widget.isAtividadesScreen == true) ...[
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
            onPressed: widget.canEditTasks ? widget.onCreate : null,
            tooltip: 'Criar',
          ),
          IconButton(
            icon: Icon(Icons.chat, color: iconColor),
            onPressed: widget.onChat,
            tooltip: 'Chat',
          ),
          if (widget.canEditTasks)
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

  String _formatShortDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
  }

  Widget _buildViewModeButton(IconData icon, String tooltip, String mode) {
    final themeProvider = ThemeProvider();
    final currentTheme = themeProvider.currentTheme;
    final iconColor = ThemeService.getBarIconColorSync(currentTheme);
    
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

