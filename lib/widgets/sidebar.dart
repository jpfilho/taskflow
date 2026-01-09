import 'package:flutter/material.dart';
import '../utils/responsive.dart';
import '../services/theme_service.dart';
import '../providers/theme_provider.dart';

class Sidebar extends StatefulWidget {
  final bool isExpanded;
  final VoidCallback onToggle;
  final Function(int)? onItemSelected;
  final int? selectedIndex;
  final VoidCallback? onExport;
  final bool isRoot; // Indica se o usuário é root

  const Sidebar({
    super.key,
    required this.isExpanded,
    required this.onToggle,
    this.onItemSelected,
    this.selectedIndex,
    this.onExport,
    this.isRoot = false,
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
    final backgroundColor = ThemeService.getBarBackgroundColor(currentTheme);
    final iconColor = ThemeService.getBarIconColor(currentTheme);
    final selectedColor = ThemeService.getBarSelectedColor(currentTheme);
    
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
                  _buildSidebarIcon(Icons.people, 1, 'Pessoas', isMobile, iconSize, iconContainerSize, iconColor, selectedColor),
                  _buildSidebarIcon(Icons.directions_car, 2, 'Frota', isMobile, iconSize, iconContainerSize, iconColor, selectedColor),
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
                  ],
                  // Sempre visível para todos
                  _buildSidebarIcon(Icons.attach_money, 13, 'Custos', isMobile, iconSize, iconContainerSize, iconColor, selectedColor),
                  // Sempre visível para todos
                  _buildSidebarIcon(Icons.description, 16, 'Notas SAP', isMobile, iconSize, iconContainerSize, iconColor, selectedColor),
                ],
              ),
            ),
          ),
        ],
      ),
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

