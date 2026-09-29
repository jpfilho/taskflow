import 'package:flutter/material.dart';
import '../foundations/tf_radius.dart';
import '../theme/taskflow_theme_extension.dart';

/// Modelo de item de navegação da Gallery.
class GalleryNavItem {
  final String id;
  final String title;
  final IconData icon;
  final String group;

  const GalleryNavItem({
    required this.id,
    required this.title,
    required this.icon,
    required this.group,
  });
}

/// Barra lateral de navegação da Design System Gallery.
class GalleryNavigation extends StatelessWidget {
  final List<GalleryNavItem> items;
  final String selectedId;
  final ValueChanged<String> onSelect;
  final bool isDrawer;

  const GalleryNavigation({
    super.key,
    required this.items,
    required this.selectedId,
    required this.onSelect,
    this.isDrawer = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    // Agrupar itens por categoria
    final groups = <String, List<GalleryNavItem>>{};
    for (final item in items) {
      groups.putIfAbsent(item.group, () => []).add(item);
    }

    Widget content = ListView(
      padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.base),
      children: [
        for (final entry in groups.entries) ...[
          Padding(
            padding: EdgeInsets.only(left: spacing.sm, top: spacing.md, bottom: spacing.xs),
            child: Text(
              entry.key.toUpperCase(),
              style: typography.micro.copyWith(
                color: colors.textMuted,
                letterSpacing: 1.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          for (final item in entry.value) ...[
            _NavItemTile(
              item: item,
              isSelected: item.id == selectedId,
              onTap: () {
                onSelect(item.id);
                if (isDrawer) Navigator.of(context).pop();
              },
            ),
          ],
          SizedBox(height: spacing.xs),
        ],
      ],
    );

    if (isDrawer) {
      return Drawer(
        backgroundColor: colors.surface,
        child: SafeArea(child: content),
      );
    }

    return Container(
      width: 240.0,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          right: BorderSide(color: colors.borderSubtle),
        ),
      ),
      child: content,
    );
  }
}

class _NavItemTile extends StatefulWidget {
  final GalleryNavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItemTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_NavItemTile> createState() => _NavItemTileState();
}

class _NavItemTileState extends State<_NavItemTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    final bg = widget.isSelected
        ? colors.selected
        : (_isHovered ? colors.hover : Colors.transparent);
    final fg = widget.isSelected ? colors.primary : colors.textPrimary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: EdgeInsets.symmetric(vertical: spacing.xxs),
          padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.sm),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: TFRadius.borderRadiusSm,
          ),
          child: Row(
            children: [
              Icon(widget.item.icon, size: 18.0, color: fg),
              SizedBox(width: spacing.sm),
              Expanded(
                child: Text(
                  widget.item.title,
                  style: typography.bodyMedium.copyWith(
                    color: fg,
                    fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
