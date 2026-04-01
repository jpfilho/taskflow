import 'package:flutter/material.dart';
import '../utils/responsive.dart';
import '../services/auth_service_simples.dart';
import '../services/theme_service.dart';
import '../providers/theme_provider.dart';
import 'perfil_usuario_view.dart';
import 'sync_status_widget.dart';
import 'gantt_chart.dart';
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
  final int unreadChatCount;
  final VoidCallback? onConfig;
  final Future<void> Function()? onPerfilUpdated;
  final Function(String)? onViewModeChanged;
  final String? currentViewMode;
  final VoidCallback? onToggleGantt;
  final bool? showGantt;
  final bool? isAtividadesScreen;
  final GanttScale? ganttScale;
  final ValueChanged<GanttScale>? onGanttScaleChanged;
  final bool canEditTasks;
  /// Botão "Atualizar" na tela de Atividades (recarrega tarefas e reaplica filtros).
  final Future<void> Function()? onRefreshAtividades;
  final bool isAtividadesRefreshing;
  /// Tela de Horas: botão Atualizar e seletor Tabela/Metas no header.
  final bool? isHorasScreen;
  final String? horasViewMode;
  final Function(String)? onHorasViewModeChanged;
  final VoidCallback? onRefreshHoras;
  /// Visualização horária do Gantt
  final bool? showHourlyView;
  final VoidCallback? onToggleHourlyView;

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
    this.unreadChatCount = 0,
    this.onConfig,
    this.onPerfilUpdated,
    this.onViewModeChanged,
    this.currentViewMode,
    this.onToggleGantt,
    this.showGantt,
    this.isAtividadesScreen,
    this.ganttScale,
    this.onGanttScaleChanged,
    this.canEditTasks = true,
    this.onRefreshAtividades,
    this.isAtividadesRefreshing = false,
    this.isHorasScreen,
    this.horasViewMode,
    this.onHorasViewModeChanged,
    this.onRefreshHoras,
    this.showHourlyView,
    this.onToggleHourlyView,
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      InkWell(
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
                      if (widget.isAtividadesScreen == true && widget.onRefreshAtividades != null) ...[
                        const SizedBox(width: 6),
                        Tooltip(
                          message: 'Atualizar dados',
                          child: widget.isAtividadesRefreshing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.refresh, size: 18),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  onPressed: () => widget.onRefreshAtividades?.call(),
                                ),
                        ),
                      ],
                      if (widget.isAtividadesScreen == true &&
                          widget.showGantt == true &&
                          widget.onGanttScaleChanged != null &&
                          widget.ganttScale != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: DropdownButton<GanttScale>(
                            // Desativar opção de Hora no header: se vier selecionada, cair para Diário
                            value: widget.ganttScale == GanttScale.hourly
                                ? GanttScale.daily
                                : widget.ganttScale,
                            isDense: true,
                            underline: const SizedBox.shrink(),
                            dropdownColor: Colors.white,
                            icon: const Icon(Icons.arrow_drop_down, size: 18, color: Color.fromARGB(221, 252, 252, 252)),
                            style: const TextStyle(fontSize: 11, color: Color.fromARGB(221, 255, 255, 255), fontWeight: FontWeight.w500),
                            items: [
                              DropdownMenuItem(
                                value: GanttScale.daily,
                                child: Text('Dia', style: TextStyle(color: Colors.grey[900], fontSize: 12)),
                              ),
                              DropdownMenuItem(
                                value: GanttScale.weekly,
                                child: Text('Sem', style: TextStyle(color: Colors.grey[900], fontSize: 12)),
                              ),
                              DropdownMenuItem(
                                value: GanttScale.biweekly,
                                child: Text('Quin', style: TextStyle(color: Colors.grey[900], fontSize: 12)),
                              ),
                              DropdownMenuItem(
                                value: GanttScale.monthly,
                                child: Text('Mês', style: TextStyle(color: Colors.grey[900], fontSize: 12)),
                              ),
                              DropdownMenuItem(
                                value: GanttScale.quarterly,
                                child: Text('Trim', style: TextStyle(color: Colors.grey[900], fontSize: 12)),
                              ),
                              DropdownMenuItem(
                                value: GanttScale.semiAnnual,
                                child: Text('Semest', style: TextStyle(color: Colors.grey[900], fontSize: 12)),
                              ),
                            ],
                            onChanged: (v) {
                              if (v != null) widget.onGanttScaleChanged!(v);
                            },
                          ),
                        ),
                        // removido: toggle de horas (agora controlado via dropdown "Hora")
                      ],
                    ],
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
                  Badge(
                    isLabelVisible: widget.unreadChatCount > 0,
                    label: Text(
                      widget.unreadChatCount > 99 ? '99+' : '${widget.unreadChatCount}',
                      style: const TextStyle(fontSize: 9, color: Colors.white),
                    ),
                    backgroundColor: Colors.red,
                    child: IconButton(
                      icon: Icon(Icons.chat, color: iconColor, size: 20),
                      onPressed: widget.onChat,
                      tooltip: 'Chat',
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
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
          // Botão Atualizar Horas (antes das opções de visualização)
          if (widget.isHorasScreen == true && widget.onRefreshHoras != null &&
              !isMobile &&
              (isTablet || isTabletLandscape || isLargeDesktop)) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: 'Atualizar dados',
              child: IconButton(
                icon: Icon(Icons.refresh, size: 20, color: iconColor),
                onPressed: widget.onRefreshHoras,
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
                tooltip: 'Atualizar dados',
              ),
            ),
          ],
          // Seletor de visualização Horas (referência: barra com ícones, estilo tela Atividades)
          if (widget.isHorasScreen == true &&
              widget.horasViewMode != null &&
              widget.onHorasViewModeChanged != null &&
              !isMobile &&
              (isTablet || isTabletLandscape || isLargeDesktop)) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHorasViewModeButton(iconColor, Icons.table_chart, 'Tabela', 'tabela'),
                  _buildHorasViewModeButton(iconColor, Icons.track_changes, 'Metas', 'metas'),
                ],
              ),
            ),
          ],
          // Botão Atualizar (apenas na tela de Atividades)
          if (widget.isAtividadesScreen == true && widget.onRefreshAtividades != null) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: 'Atualizar dados',
              child: widget.isAtividadesRefreshing
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                      ),
                    )
                  : IconButton(
                      icon: Icon(Icons.refresh, size: 20, color: iconColor),
                      onPressed: () async {
                        await widget.onRefreshAtividades?.call();
                      },
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                      tooltip: 'Atualizar dados',
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
            // Seletor de escala do Gantt (apenas quando o Gantt está visível)
            if (widget.showGantt == true && 
                widget.onGanttScaleChanged != null && 
                widget.ganttScale != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: textColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButton<GanttScale>(
                  // Desativar opção de Hora no header desktop: se vier selecionada, cair para Diário
                  value: widget.ganttScale == GanttScale.hourly
                      ? GanttScale.daily
                      : widget.ganttScale,
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  dropdownColor: Colors.white,
                  icon: Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
                  style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
                  selectedItemBuilder: (context) => [
                    Text('Diário', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                    Text('Semanal', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                    Text('Quinzenal', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                    Text('Mensal', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                    Text('Trimestral', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                    Text('Semestral', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                  ],
                  items: [
                    DropdownMenuItem(
                      value: GanttScale.daily,
                      child: Text('Diário', style: TextStyle(color: Colors.grey[900], fontSize: 13)),
                    ),
                    DropdownMenuItem(
                      value: GanttScale.weekly,
                      child: Text('Semanal', style: TextStyle(color: Colors.grey[900], fontSize: 13)),
                    ),
                    DropdownMenuItem(
                      value: GanttScale.biweekly,
                      child: Text('Quinzenal', style: TextStyle(color: Colors.grey[900], fontSize: 13)),
                    ),
                    DropdownMenuItem(
                      value: GanttScale.monthly,
                      child: Text('Mensal', style: TextStyle(color: Colors.grey[900], fontSize: 13)),
                    ),
                    DropdownMenuItem(
                      value: GanttScale.quarterly,
                      child: Text('Trimestral', style: TextStyle(color: Colors.grey[900], fontSize: 13)),
                    ),
                    DropdownMenuItem(
                      value: GanttScale.semiAnnual,
                      child: Text('Semestral', style: TextStyle(color: Colors.grey[900], fontSize: 13)),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) widget.onGanttScaleChanged!(v);
                  },
                ),
              ),
              // removido: toggle de horas (agora controlado via dropdown "Hora")
            ],
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
          Badge(
            isLabelVisible: widget.unreadChatCount > 0,
            label: Text(
              widget.unreadChatCount > 99 ? '99+' : '${widget.unreadChatCount}',
              style: const TextStyle(fontSize: 10, color: Colors.white),
            ),
            backgroundColor: Colors.red,
            child: IconButton(
              icon: Icon(Icons.chat, color: iconColor),
              onPressed: widget.onChat,
              tooltip: 'Chat',
            ),
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
                          await widget.onPerfilUpdated!();
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

  /// Botão de modo de visualização da tela Horas (ícone apenas, estilo referência).
  Widget _buildHorasViewModeButton(Color iconColor, IconData icon, String tooltip, String value) {
    final isSelected = widget.horasViewMode == value;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onHorasViewModeChanged?.call(value),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? iconColor.withOpacity(0.25) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              size: 20,
              color: isSelected ? iconColor : iconColor.withOpacity(0.6),
            ),
          ),
        ),
      ),
    );
  }
}

