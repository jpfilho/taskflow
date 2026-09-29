import 'package:flutter/material.dart';
import '../../../../design_system/components/buttons/tf_button.dart';
import '../../../../design_system/components/buttons/tf_icon_button.dart';
import '../../../../design_system/components/inputs/tf_text_field.dart';
import '../../../../design_system/foundations/tf_icons.dart';
import '../../../../design_system/foundations/tf_radius.dart';
import '../../../../design_system/theme/taskflow_theme_extension.dart';
import '../../../../models/local.dart';
import '../../data/models/segment.dart';
import '../../data/models/room.dart';
import '../../data/models/media_image.dart';
import '../../data/models/status_album.dart';

class FilterBar extends StatelessWidget {
  final String searchQuery;
  final TextEditingController? searchController;
  final ValueChanged<String> onSearchChanged;
  final List<Segment> segments;
  final List<Local> locais;
  final List<Room> rooms;
  final String? selectedSegmentId;
  final String? selectedLocalId;
  final String? selectedRoomId;
  final MediaImageStatus? selectedStatus;
  final String? selectedStatusAlbumId;
  final List<StatusAlbum> statusAlbums;
  final ValueChanged<String?> onSegmentChanged;
  final ValueChanged<String?> onLocalChanged;
  final ValueChanged<String?> onRoomChanged;
  final ValueChanged<MediaImageStatus?> onStatusChanged;
  final ValueChanged<String?>? onStatusAlbumIdChanged;
  final VoidCallback onClearFilters;
  final VoidCallback? onRefresh;
  /// 0 = grid, 1 = lista hierárquica, 2 = álbuns por local
  final int viewModeIndex;
  final ValueChanged<int> onViewModeChanged;
  final int? totalResults;
  final int? currentResults;

  const FilterBar({
    super.key,
    required this.searchQuery,
    this.searchController,
    required this.onSearchChanged,
    required this.segments,
    required this.locais,
    required this.rooms,
    this.selectedSegmentId,
    this.selectedLocalId,
    this.selectedRoomId,
    this.selectedStatus,
    this.selectedStatusAlbumId,
    this.statusAlbums = const [],
    required this.onSegmentChanged,
    required this.onLocalChanged,
    required this.onRoomChanged,
    required this.onStatusChanged,
    this.onStatusAlbumIdChanged,
    required this.onClearFilters,
    this.onRefresh,
    this.viewModeIndex = 0,
    required this.onViewModeChanged,
    this.totalResults,
    this.currentResults,
  });

  static String? _effectiveRoomId(String? selectedRoomId, List<Room> rooms) {
    if (selectedRoomId == null) return null;
    return rooms.any((r) => r.id == selectedRoomId) ? selectedRoomId : null;
  }

  static List<DropdownMenuItem<String>> _roomItemsDeduped(List<Room> rooms) {
    final seen = <String>{};
    return rooms
        .where((r) => seen.add(r.id))
        .map((r) => DropdownMenuItem<String>(
              value: r.id,
              child: Text(r.name, overflow: TextOverflow.ellipsis),
            ))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final spacing = context.tfSpacing;
    final typography = context.tfTypography;

    final hasActiveFilters = selectedSegmentId != null ||
        selectedLocalId != null ||
        selectedRoomId != null ||
        selectedStatus != null ||
        selectedStatusAlbumId != null ||
        searchQuery.isNotEmpty;

    return Container(
      padding: EdgeInsets.all(spacing.sm),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: TFRadius.borderRadiusMd,
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Busca e Modos de Visão
          Row(
            children: [
              Expanded(
                child: TFTextField(
                  controller: searchController,
                  hint: 'Buscar fotos por título, tag ou autor...',
                  prefixIcon: Icon(TFIcons.search, size: 18, color: colors.textSecondary),
                  onChanged: onSearchChanged,
                ),
              ),
              SizedBox(width: spacing.sm),
              // Segmented Button para modos de visão
              Container(
                decoration: BoxDecoration(
                  color: colors.surfaceSecondary,
                  borderRadius: TFRadius.borderRadiusSm,
                  border: Border.all(color: colors.borderSubtle),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _viewModeButton(context, 0, Icons.grid_view_rounded, 'Grid Geral'),
                    _viewModeButton(context, 1, Icons.folder_copy_rounded, 'Por Álbuns'),
                  ],
                ),
              ),
              if (onRefresh != null) ...[
                SizedBox(width: spacing.xs),
                TFIconButton(
                  icon: TFIcons.refresh,
                  tooltip: 'Atualizar Galeria',
                  onPressed: onRefresh,
                ),
              ],
            ],
          ),
          SizedBox(height: spacing.sm),

          // 2. Filtros Dropdown e Reset
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildDropdown(
                  context,
                  label: 'Segmento',
                  value: selectedSegmentId,
                  items: segments.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                  onChanged: onSegmentChanged,
                ),
                SizedBox(width: spacing.xs),
                _buildDropdown(
                  context,
                  label: 'Local',
                  value: selectedLocalId,
                  items: locais.map((l) => DropdownMenuItem(value: l.id, child: Text(l.local))).toList(),
                  onChanged: onLocalChanged,
                  enabled: selectedSegmentId != null,
                ),
                SizedBox(width: spacing.xs),
                _buildDropdown(
                  context,
                  label: 'Sala',
                  value: _effectiveRoomId(selectedRoomId, rooms),
                  items: _roomItemsDeduped(rooms),
                  onChanged: onRoomChanged,
                  enabled: selectedLocalId != null,
                ),
                if (statusAlbums.isNotEmpty) ...[
                  SizedBox(width: spacing.xs),
                  _buildDropdown(
                    context,
                    label: 'Status',
                    value: selectedStatusAlbumId,
                    items: statusAlbums.map((s) => DropdownMenuItem(value: s.id, child: Text(s.nome))).toList(),
                    onChanged: (v) => onStatusAlbumIdChanged?.call(v),
                  ),
                ],
                if (hasActiveFilters) ...[
                  SizedBox(width: spacing.sm),
                  TFButton(
                    label: 'Limpar Filtros',
                    variant: TFButtonVariant.ghost,
                    leadingIcon: Icons.clear_all_rounded,
                    onPressed: onClearFilters,
                  ),
                ],
              ],
            ),
          ),

          if (totalResults != null) ...[
            SizedBox(height: spacing.xs),
            Text(
              'Exibindo ${currentResults ?? 0} de $totalResults fotos',
              style: typography.caption.copyWith(color: colors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _viewModeButton(BuildContext context, int index, IconData icon, String tooltip) {
    final colors = context.tfColors;
    final isSelected = viewModeIndex == index;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => onViewModeChanged(index),
        borderRadius: TFRadius.borderRadiusSm,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? colors.primary : Colors.transparent,
            borderRadius: TFRadius.borderRadiusSm,
          ),
          child: Icon(
            icon,
            size: 18,
            color: isSelected ? Colors.white : colors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown(
    BuildContext context, {
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    bool enabled = true,
  }) {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: enabled ? colors.surface : colors.surfaceSecondary.withValues(alpha: 0.5),
        borderRadius: TFRadius.borderRadiusSm,
        border: Border.all(
          color: value != null ? colors.primary : colors.borderSubtle,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          hint: Text(label, style: typography.bodySmall.copyWith(color: colors.textSecondary)),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text('$label: Todos', style: typography.bodySmall),
            ),
            ...items,
          ],
          onChanged: enabled ? onChanged : null,
          style: typography.bodySmall.copyWith(
            color: colors.textPrimary,
            fontWeight: value != null ? FontWeight.w600 : FontWeight.normal,
          ),
          dropdownColor: colors.surface,
          icon: Icon(Icons.arrow_drop_down, color: colors.textSecondary, size: 18),
        ),
      ),
    );
  }
}
