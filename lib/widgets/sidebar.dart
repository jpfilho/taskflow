import 'package:flutter/material.dart';
import '../utils/responsive.dart';
import '../services/theme_service.dart';
import '../providers/theme_provider.dart';
import 'dart:async';

class Sidebar extends StatefulWidget {
  final bool isExpanded;
  final VoidCallback onToggle;
  final Function(int)? onItemSelected;
  final int? selectedIndex;
  final VoidCallback? onExport;
  final bool isRoot; // Indica se o usuário é root
  final bool showGtd; // Módulo GTD (root ou jpfilho@axia.com.br)
  final bool showGtdAndSupressao; // GTD e Supressão de Vegetação (root ou jpfilho@axia.com.br)

  const Sidebar({
    super.key,
    required this.isExpanded,
    required this.onToggle,
    this.onItemSelected,
    this.selectedIndex,
    this.onExport,
    this.isRoot = false,
    this.showGtd = false,
    this.showGtdAndSupressao = false,
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  int get selectedIndex => widget.selectedIndex ?? 0;

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final collapsedWidth = isMobile ? 50.0 : 60.0;
    final expandedWidth = isMobile ? 200.0 : 240.0;
    final currentWidth = widget.isExpanded ? expandedWidth : collapsedWidth;
    final iconSize = isMobile ? 20.0 : 24.0;
    final buttonHeight = isMobile ? 32.0 : 36.0;
    final iconContainerSize = isMobile ? 36.0 : 44.0;
    
    final themeProvider = ThemeProvider();
    final currentTheme = themeProvider.currentTheme;
    final selectedColor = ThemeService.getBarSelectedColor(currentTheme);
    
    return StreamBuilder<String>(
      stream: ColorThemeNotifier().colorChangeStream.where((barType) => barType == 'sidebar'),
      builder: (context, streamSnapshot) {
        return FutureBuilder<Map<String, Color>>(
          future: Future.wait([
            ThemeService.getBarBackgroundColor(currentTheme, barType: 'sidebar'),
            ThemeService.getBarIconColor(currentTheme, barType: 'sidebar'),
          ]).then((colors) => {
            'background': colors[0],
            'icon': colors[1],
          }),
          builder: (context, snapshot) {
        final backgroundColor = snapshot.data?['background'] ?? ThemeService.getBarBackgroundColorSync(currentTheme);
        final iconColor = snapshot.data?['icon'] ?? ThemeService.getBarIconColorSync(currentTheme);
        
        return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: currentWidth,
      decoration: BoxDecoration(
        color: backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          // Botão de toggle (menu/close)
          Container(
            margin: EdgeInsets.all(isMobile ? 8 : 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: Icon(
                widget.isExpanded ? Icons.chevron_left : Icons.menu,
                size: isMobile ? 20 : 24,
                color: iconColor,
              ),
              onPressed: widget.onToggle,
              padding: EdgeInsets.all(isMobile ? 8 : 12),
              constraints: BoxConstraints(
                minWidth: iconContainerSize,
                minHeight: iconContainerSize,
              ),
            ),
          ),
          SizedBox(height: isMobile ? 4 : 8),
          // Botão Export
          Container(
            margin: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12),
            child: ElevatedButton(
              onPressed: widget.onExport,
              style: ElevatedButton.styleFrom(
                backgroundColor: iconColor,
                foregroundColor: backgroundColor,
                padding: EdgeInsets.symmetric(vertical: isMobile ? 8 : 10),
                minimumSize: Size(double.infinity, buttonHeight),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.download, size: 18),
                  if (widget.isExpanded) ...[
                    const SizedBox(width: 8),
                    Text(
                      'Exportar',
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(height: isMobile ? 8 : 16),
          // Ícones verticais
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Sempre visível para todos
                  _buildSidebarIcon(Icons.grid_view, 0, 'Atividades', isMobile, iconSize, iconContainerSize, iconColor, selectedColor),
                  _buildSidebarIcon(Icons.people, 1, 'Equipe', isMobile, iconSize, iconContainerSize, iconColor, selectedColor),
                  _buildSidebarIcon(Icons.directions_car, 2, 'Frota', isMobile, iconSize, iconContainerSize, iconColor, selectedColor),
                  // Divider após Frota
                  Divider(
                    height: isMobile ? 16 : 24,
                    thickness: 1,
                    indent: isMobile ? 8 : 12,
                    endIndent: isMobile ? 8 : 12,
                    color: iconColor.withOpacity(0.2),
                  ),
                  // Horas - disponível para todos os usuários
                  _buildSidebarIcon(Icons.access_time, 20, 'Horas', isMobile, iconSize, iconContainerSize, iconColor, selectedColor),
                  // Apenas para root
                  if (widget.isRoot) ...[
                    _buildSidebarIcon(Icons.dashboard, 4, 'Dashboard', isMobile, iconSize, iconContainerSize, iconColor, selectedColor),
                    _buildSidebarIcon(Icons.description, 5, 'Documento', isMobile, iconSize, iconContainerSize, iconColor, selectedColor),
                    _buildSidebarIcon(Icons.list, 6, 'Lista', isMobile, iconSize, iconContainerSize, iconColor, selectedColor),
                    _buildSidebarIcon(Icons.pie_chart, 7, 'Gráfico', isMobile, iconSize, iconContainerSize, iconColor, selectedColor),
                    _buildSidebarIcon(Icons.arrow_forward, 8, 'Avançar', isMobile, iconSize, iconContainerSize, iconColor, selectedColor),
                    _buildSidebarIcon(Icons.notifications_active, 9, 'Alertas', isMobile, iconSize, iconContainerSize, iconColor, selectedColor),
                    _buildSidebarIcon(Icons.history, 10, 'Histórico', isMobile, iconSize, iconContainerSize, iconColor, selectedColor),
                    _buildSidebarIcon(Icons.checklist, 12, 'Checklist', isMobile, iconSize, iconContainerSize, iconColor, selectedColor),
                    _buildSidebarIcon(Icons.attach_money, 13, 'Custos', isMobile, iconSize, iconContainerSize, iconColor, selectedColor),
                  ],
                  // Divider antes de Notas SAP
                  Divider(
                    height: isMobile ? 16 : 24,
                    thickness: 1,
                    indent: isMobile ? 8 : 12,
                    endIndent: isMobile ? 8 : 12,
                    color: iconColor.withOpacity(0.2),
                  ),
                  // Sempre visível para todos
                  _buildSidebarIcon(Icons.description, 16, 'Notas SAP', isMobile, iconSize, iconContainerSize, iconColor, selectedColor),
                  _buildSidebarIcon(Icons.list_alt, 17, 'Ordens', isMobile, iconSize, iconContainerSize, iconColor, selectedColor),
                  _buildSidebarIcon(Icons.assignment, 18, 'ATs', isMobile, iconSize, iconContainerSize, iconColor, selectedColor),
                  _buildSidebarIcon(Icons.description, 19, 'SIs', isMobile, iconSize, iconContainerSize, iconColor, selectedColor),
                  Divider(
                    height: isMobile ? 16 : 24,
                    thickness: 1,
                    indent: isMobile ? 8 : 12,
                    endIndent: isMobile ? 8 : 12,
                    color: iconColor.withOpacity(0.2),
                  ),
                  if (widget.isRoot)
                    _buildSidebarIcon(Icons.checklist_rtl, 3, 'Demandas', isMobile, iconSize, iconContainerSize, iconColor, selectedColor),
                  if (widget.isRoot || widget.showGtdAndSupressao) ...[
                    Divider(
                      height: isMobile ? 16 : 24,
                      thickness: 1,
                      indent: isMobile ? 8 : 12,
                      endIndent: isMobile ? 8 : 12,
                      color: iconColor.withOpacity(0.2),
                    ),
                    if (widget.isRoot)
                      _buildSidebarIcon(Icons.alt_route, 21, 'Linhas de Transmissão', isMobile, iconSize, iconContainerSize, iconColor, selectedColor),
                    if (widget.showGtdAndSupressao)
                      _buildSidebarIcon(Icons.eco, 22, 'Supressão de Vegetação', isMobile, iconSize, iconContainerSize, iconColor, selectedColor),
                  ],
                  // Divider antes de Documentos/Álbuns
                  Divider(
                    height: isMobile ? 16 : 24,
                    thickness: 1,
                    indent: isMobile ? 8 : 12,
                    endIndent: isMobile ? 8 : 12,
                    color: iconColor.withOpacity(0.2),
                  ),
                  // Documentos - apenas root (como demais restritos)
                  if (widget.isRoot)
                    _buildSidebarIcon(Icons.folder, 24, 'Documentos', isMobile, iconSize, iconContainerSize, iconColor, selectedColor),
                  // Álbuns de Mídia - disponível para todos
                  _buildSidebarIcon(Icons.photo_library, 23, 'Álbuns de Imagens', isMobile, iconSize, iconContainerSize, iconColor, selectedColor),
                  if (widget.showGtd) ...[
                    Divider(
                      height: isMobile ? 16 : 24,
                      thickness: 1,
                      indent: isMobile ? 8 : 12,
                      endIndent: isMobile ? 8 : 12,
                      color: iconColor.withOpacity(0.2),
                    ),
                    _buildSidebarIcon(Icons.check_circle_outline, 25, 'GTD', isMobile, iconSize, iconContainerSize, iconColor, selectedColor),
                  ],
                  Divider(
                    height: isMobile ? 16 : 24,
                    thickness: 1,
                    indent: isMobile ? 8 : 12,
                    endIndent: isMobile ? 8 : 12,
                    color: iconColor.withOpacity(0.2),
                  ),
                  _buildSidebarIcon(Icons.bug_report, 26, 'Melhorias e Bugs', isMobile, iconSize, iconContainerSize, iconColor, selectedColor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
          },
        );
      },
    );
  }

  Widget _buildSidebarIcon(IconData icon, int index, String tooltip, bool isMobile, double iconSize, double containerSize, Color iconColor, Color selectedColor) {
    final isSelected = selectedIndex == index;
    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 4 : 8),
      child: Tooltip(
        message: tooltip,
          child: InkWell(
          onTap: () {
            widget.onItemSelected?.call(index);
          },
          child: Container(
            width: double.infinity,
            height: containerSize,
            margin: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 8),
            padding: EdgeInsets.symmetric(horizontal: widget.isExpanded ? 12 : 0),
            decoration: BoxDecoration(
              color: isSelected 
                  ? selectedColor
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: iconColor.withOpacity(0.3), width: 1)
                  : null,
            ),
            child: widget.isExpanded
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        color: isSelected ? iconColor : iconColor.withOpacity(0.7),
                        size: iconSize,
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          tooltip,
                          style: TextStyle(
                            color: isSelected ? iconColor : iconColor.withOpacity(0.8),
                            fontSize: isMobile ? 11 : 12,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Icon(
                      icon,
                      color: isSelected ? iconColor : iconColor.withOpacity(0.7),
                      size: iconSize,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

