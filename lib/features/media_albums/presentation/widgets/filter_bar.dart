import 'package:flutter/material.dart';
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
  final MediaImageStatus? selectedStatus; // Mantido para compatibilidade
  final String? selectedStatusAlbumId; // Novo
  final List<StatusAlbum> statusAlbums; // Novo: lista de status da tabela
  final ValueChanged<String?> onSegmentChanged;
  final ValueChanged<String?> onLocalChanged;
  final ValueChanged<String?> onRoomChanged;
  final ValueChanged<MediaImageStatus?> onStatusChanged; // Mantido para compatibilidade
  final ValueChanged<String?>? onStatusAlbumIdChanged; // Novo (opcional)
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
    this.selectedStatus, // Mantido para compatibilidade
    this.selectedStatusAlbumId, // Novo
    this.statusAlbums = const [], // Novo
    required this.onSegmentChanged,
    required this.onLocalChanged,
    required this.onRoomChanged,
    required this.onStatusChanged, // Mantido para compatibilidade
    this.onStatusAlbumIdChanged, // Novo
    required this.onClearFilters,
    this.onRefresh,
    this.viewModeIndex = 0,
    required this.onViewModeChanged,
    this.totalResults,
    this.currentResults,
  });

  /// Valor de sala só se existir na lista (evita assertion do DropdownButton).
  static String? _effectiveRoomId(String? selectedRoomId, List<Room> rooms) {
    if (selectedRoomId == null) return null;
    return rooms.any((r) => r.id == selectedRoomId) ? selectedRoomId : null;
  }

  /// Items do dropdown de salas sem IDs duplicados (evita "2 or more" no DropdownButton).
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

  static String _roomDisplayName(String? selectedRoomId, List<Room> rooms) {
    if (selectedRoomId == null) return 'Todas';
    final found = rooms.where((r) => r.id == selectedRoomId).toList();
    return found.isEmpty ? 'Todas' : found.first.name;
  }

  static String _localDisplayName(String selectedLocalId, List<Local> locais) {
    final found = locais.where((l) => l.id == selectedLocalId).toList();
    return found.isEmpty ? 'Todos' : found.first.local;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (isMobile) {
      return _buildMobileFilterBar(context, theme);
    }

    return _buildDesktopFilterBar(context, theme);
  }

  Widget _buildDesktopFilterBar(BuildContext context, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final hasActiveFilters = selectedSegmentId != null ||
        selectedLocalId != null ||
        selectedRoomId != null ||
        selectedStatus != null ||
        selectedStatusAlbumId != null;
    final width = MediaQuery.of(context).size.width;
    final padding = width < 1024 ? 10.0 : 12.0;
    const double dropdownMinWidth = 180;

    final filterRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRect(
          child: SizedBox(
            width: dropdownMinWidth,
            child: _buildFilterDropdown(
            context,
            'SEGMENTO',
            selectedSegmentId,
            segments.map((s) => DropdownMenuItem<String>(
              value: s.id,
              child: Text(s.name, overflow: TextOverflow.ellipsis),
            )).toList(),
            onSegmentChanged,
            'Segmento',
            isDark,
            compact: true,
          ),
        ),
        ),
        SizedBox(width: padding),
        ClipRect(
          child: SizedBox(
            width: dropdownMinWidth,
            child: _buildFilterDropdown(
            context,
            'LOCAL',
            selectedLocalId,
            locais.map((l) => DropdownMenuItem<String>(
              value: l.id,
              child: Text(l.local, overflow: TextOverflow.ellipsis),
            )).toList(),
            onLocalChanged,
            'Local',
            isDark,
            compact: true,
            enabled: selectedSegmentId != null,
          ),
        ),
        ),
        SizedBox(width: padding),
        ClipRect(
          child: SizedBox(
            width: dropdownMinWidth,
            child: _buildFilterDropdown(
            context,
            'SALA',
            _effectiveRoomId(selectedRoomId, rooms),
            _roomItemsDeduped(rooms),
            onRoomChanged,
            'Sala',
            isDark,
            compact: true,
            enabled: selectedLocalId != null,
          ),
        ),
        ),
        SizedBox(width: padding),
        ClipRect(
          child: SizedBox(
            width: dropdownMinWidth,
            child: _buildStatusDropdown(
            context,
            selectedStatusAlbumId,
            statusAlbums,
            onStatusAlbumIdChanged ?? ((_) {}),
            isDark,
            compact: true,
          ),
        ),
        ),
        SizedBox(width: padding * 2),
        TextButton.icon(
          onPressed: hasActiveFilters ? onClearFilters : null,
          icon: Icon(
            Icons.filter_alt_off,
            size: 16,
            color: hasActiveFilters
                ? (isDark ? Colors.grey[300] : Colors.grey[600])
                : (isDark ? Colors.grey[600] : Colors.grey[400]),
          ),
          label: Text(
            'Limpar',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: hasActiveFilters
                  ? (isDark ? Colors.grey[300] : Colors.grey[600])
                  : (isDark ? Colors.grey[600] : Colors.grey[400]),
            ),
          ),
        ),
        if (onRefresh != null) ...[
          SizedBox(width: padding),
          IconButton(
            onPressed: onRefresh,
            icon: Icon(
              Icons.refresh_rounded,
              size: 20,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            tooltip: 'Atualizar',
            style: IconButton.styleFrom(
              backgroundColor: isDark ? const Color(0xFF0f172a) : const Color(0xFFf8fafc),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
        if (currentResults != null && totalResults != null)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              '$currentResults / $totalResults',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[500],
              ),
            ),
          ),
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0f172a) : const Color(0xFFf8fafc),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildViewButton(
                context,
                Icons.grid_view,
                viewModeIndex == 0,
                () => onViewModeChanged(0),
                isDark,
                tooltip: 'Grade',
              ),
              _buildViewButton(
                context,
                Icons.format_list_bulleted,
                viewModeIndex == 1,
                () => onViewModeChanged(1),
                isDark,
                tooltip: 'Lista hierárquica',
              ),
              _buildViewButton(
                context,
                Icons.folder_rounded,
                viewModeIndex == 2,
                () => onViewModeChanged(2),
                isDark,
                tooltip: 'Álbuns por local',
              ),
            ],
          ),
        ),
      ],
    );

    return Container(
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1e293b) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: filterRow,
      ),
    );
  }

  Widget _buildFilterDropdown(
    BuildContext context,
    String label,
    String? value,
    List<DropdownMenuItem<String>> items,
    ValueChanged<String?> onChanged,
    String defaultText,
    bool isDark, {
    bool compact = false,
    bool enabled = true,
  }) {
    final dropdown = Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0f172a) : const Color(0xFFf8fafc),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0),
        ),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          contentPadding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 8 : 12,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
        items: [
          DropdownMenuItem<String>(
            value: null,
            child: Text(defaultText, overflow: TextOverflow.ellipsis),
          ),
          ...items,
        ],
        onChanged: enabled ? onChanged : null,
        icon: Icon(
          Icons.expand_more,
          size: compact ? 18 : 24,
          color: isDark ? Colors.grey[400] : Colors.grey[500],
        ),
        style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF0f172a),
          fontSize: compact ? 12 : 14,
        ),
        dropdownColor: isDark ? const Color(0xFF1e293b) : Colors.white,
      ),
    );
    if (compact) return dropdown;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[500] : Colors.grey[500],
              letterSpacing: 0.5,
            ),
          ),
        ),
        dropdown,
      ],
    );
  }

  Widget _buildStatusDropdown(
    BuildContext context,
    String? value,
    List<StatusAlbum> statusAlbums,
    ValueChanged<String?> onChanged,
    bool isDark, {
    bool compact = false,
  }) {
    final dropdown = Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0f172a) : const Color(0xFFf8fafc),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0),
        ),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          contentPadding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 8 : 12,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
        items: [
          DropdownMenuItem<String>(
            value: null,
            child: Text(compact ? 'Status' : 'Todos Status', overflow: TextOverflow.ellipsis),
          ),
          ...statusAlbums.map((s) => DropdownMenuItem<String>(
                value: s.id,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: compact ? 10 : 12,
                      height: compact ? 10 : 12,
                      decoration: BoxDecoration(
                        color: s.backgroundColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: s.textColor,
                          width: 1,
                        ),
                      ),
                    ),
                    SizedBox(width: compact ? 6 : 8),
                    Flexible(child: Text(s.nome, overflow: TextOverflow.ellipsis)),
                  ],
                ),
              )),
        ],
        onChanged: onChanged,
        icon: Icon(
          Icons.expand_more,
          size: compact ? 18 : 24,
          color: isDark ? Colors.grey[400] : Colors.grey[500],
        ),
        style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF0f172a),
          fontSize: compact ? 12 : 14,
        ),
        dropdownColor: isDark ? const Color(0xFF1e293b) : Colors.white,
      ),
    );
    if (compact) return dropdown;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'STATUS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[500] : Colors.grey[500],
              letterSpacing: 0.5,
            ),
          ),
        ),
        dropdown,
      ],
    );
  }

  Widget _buildViewButton(
    BuildContext context,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
    bool isDark, {
    String? tooltip,
  }) {
    final button = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected 
              ? (isDark ? const Color(0xFF334155) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: 20,
          color: isSelected
              ? const Color(0xFF1e40af)
              : (isDark ? Colors.grey[400] : Colors.grey[400]),
        ),
      ),
    );
    if (tooltip != null && tooltip.isNotEmpty) {
      return Tooltip(message: tooltip, child: button);
    }
    return button;
  }

  Widget _buildMobileFilterBar(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(
                    context,
                    'Segmento',
                    selectedSegmentId != null
                        ? segments.firstWhere((s) => s.id == selectedSegmentId).name
                        : 'Todos',
                    () => _showSegmentPicker(context),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    context,
                    'Local',
                    selectedLocalId != null && locais.any((l) => l.id == selectedLocalId)
                        ? _localDisplayName(selectedLocalId!, locais)
                        : 'Todos',
                    () => _showLocalPicker(context),
                    enabled: selectedSegmentId != null,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    context,
                    'Sala',
                    _roomDisplayName(selectedRoomId, rooms),
                    () => _showRoomPicker(context),
                    enabled: selectedLocalId != null,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    context,
                    'Status',
                    selectedStatusAlbumId != null
                        ? statusAlbums.firstWhere((s) => s.id == selectedStatusAlbumId, orElse: () => statusAlbums.isNotEmpty ? statusAlbums.first : StatusAlbum(id: '', nome: 'Todos')).nome
                        : (selectedStatus?.displayName ?? 'Todos'),
                    () => _showStatusPicker(context),
                  ),
                ],
              ),
            ),
          ),
          if (onRefresh != null) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 22),
              tooltip: 'Atualizar',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    String label,
    String value,
    VoidCallback onTap, {
    bool enabled = true,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: enabled
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label: ',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              value,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: enabled
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurface.withOpacity(0.4),
            ),
          ],
        ),
      ),
    );
  }

  void _showSegmentPicker(BuildContext context) {
    // TODO: Implementar picker
  }

  void _showLocalPicker(BuildContext context) {
    // TODO: Implementar picker
  }

  void _showRoomPicker(BuildContext context) {
    // TODO: Implementar picker
  }

  void _showStatusPicker(BuildContext context) {
    // TODO: Implementar picker
  }
}
