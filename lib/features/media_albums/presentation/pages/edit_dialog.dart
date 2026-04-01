import 'package:flutter/material.dart';
import '../../data/models/media_image.dart';
import '../../data/models/segment.dart';
import '../../data/models/room.dart';
import '../../data/models/status_album.dart';
import '../../data/repositories/supabase_media_repository.dart';
import '../../data/repositories/status_album_repository.dart';
import '../../util/user_locais_helper.dart';
import '../../../../services/auth_service_simples.dart';
import '../../../../services/regional_service.dart';
import '../../../../services/divisao_service.dart';
import '../../../../models/regional.dart';
import '../../../../models/divisao.dart';
import '../../../../models/local.dart';
import 'package:dropdown_search/dropdown_search.dart';

class EditDialog extends StatefulWidget {
  final MediaImage image;

  const EditDialog({
    super.key,
    required this.image,
  });

  @override
  State<EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<EditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagController = TextEditingController();

  late MediaImage _editedImage;
  List<Regional> _regionais = [];
  List<Divisao> _divisoes = [];
  List<Segment> _segments = [];
  List<Local> _locais = [];
  List<Room> _rooms = [];
  List<StatusAlbum> _statusAlbums = [];
  final StatusAlbumRepository _statusRepository = StatusAlbumRepository();
  final RegionalService _regionalService = RegionalService();
  final DivisaoService _divisaoService = DivisaoService();
  bool _loadingReferences = false;

  @override
  void initState() {
    super.initState();
    _editedImage = widget.image;
    _titleController.text = widget.image.title;
    _descriptionController.text = widget.image.description ?? '';
    _loadReferences();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _loadReferences() async {
    setState(() => _loadingReferences = true);
    try {
      final repository = SupabaseMediaRepository();
      final authService = AuthServiceSimples();
      final usuario = authService.currentUser;
      final userRegionalIds = usuario?.regionalIds;
      final userDivisaoIds = usuario?.divisaoIds;
      final userSegmentoIds = usuario?.segmentoIds;
      final isRootOrNoProfile = (usuario?.isRoot ?? false) ||
          ((userRegionalIds?.isEmpty ?? true) && (userDivisaoIds?.isEmpty ?? true) && (userSegmentoIds?.isEmpty ?? true));

      final allRegionais = await _regionalService.getAllRegionais();
      _regionais = isRootOrNoProfile || (userRegionalIds?.isEmpty ?? true)
          ? allRegionais
          : allRegionais.where((r) => userRegionalIds!.contains(r.id)).toList();

      final allDivisoes = await _divisaoService.getAllDivisoes();
      if (_editedImage.regionalId != null) {
        _divisoes = allDivisoes.where((d) => d.regionalId == _editedImage.regionalId).toList();
        if (!isRootOrNoProfile && (userDivisaoIds?.isNotEmpty ?? false)) {
          _divisoes = _divisoes.where((d) => userDivisaoIds!.contains(d.id)).toList();
        }
      } else {
        _divisoes = isRootOrNoProfile || (userDivisaoIds?.isEmpty ?? true)
            ? allDivisoes
            : allDivisoes.where((d) => userDivisaoIds!.contains(d.id)).toList();
      }

      final segmentoIdsList = userSegmentoIds != null ? List<String>.from(userSegmentoIds) : null;
      if (_editedImage.divisaoId != null) {
        final selectedDivisao = _divisoes.where((d) => d.id == _editedImage.divisaoId).toList();
        final segmentoIdsDaDivisao = selectedDivisao.isNotEmpty ? List<String>.from(selectedDivisao.first.segmentoIds) : <String>[];
        _segments = await repository.getSegments(
          userSegmentoIds: segmentoIdsDaDivisao.isEmpty
              ? (isRootOrNoProfile ? null : segmentoIdsList)
              : (isRootOrNoProfile ? segmentoIdsDaDivisao : segmentoIdsDaDivisao.where((id) => segmentoIdsList?.contains(id) ?? false).toList()),
        );
        if (segmentoIdsDaDivisao.isNotEmpty && _segments.isEmpty) {
          _segments = await repository.getSegments(userSegmentoIds: segmentoIdsDaDivisao);
        }
      } else {
        _segments = await repository.getSegments(
          userSegmentoIds: isRootOrNoProfile || (segmentoIdsList?.isEmpty ?? true) ? null : segmentoIdsList,
        );
      }

      _locais = await getLocaisForUsuario(usuario);

      if (_editedImage.localId != null) {
        final selectedLocalList = _locais.where((l) => l.id == _editedImage.localId).toList();
        if (selectedLocalList.isNotEmpty && selectedLocalList.first.localInstalacaoSap != null) {
          _rooms = await repository.getRooms(
            localInstalacao: selectedLocalList.first.localInstalacaoSap,
            userLocalNames: null,
          );
        }
      }

      _statusAlbums = await _statusRepository.getStatusAlbumsAtivos();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar referências: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingReferences = false);
      }
    }
  }

  Future<void> _handleRegionalChanged(String? regionalId) async {
    if (!mounted) return;
    setState(() {
      _editedImage = _editedImage.copyWith(
        regionalId: regionalId,
        divisaoId: null,
        segmentId: null,
        localId: null,
        roomId: null,
      );
      _rooms = [];
    });
    await _loadReferences();
  }

  Future<void> _handleDivisaoChanged(String? divisaoId) async {
    if (!mounted) return;
    setState(() {
      _editedImage = _editedImage.copyWith(
        divisaoId: divisaoId,
        segmentId: null,
        localId: null,
        roomId: null,
      );
      _rooms = [];
    });
    await _loadReferences();
  }

  Future<void> _handleSegmentChanged(String? segmentId) async {
    if (!mounted) return;
    setState(() {
      _editedImage = _editedImage.copyWith(
        segmentId: segmentId,
        localId: null,
        roomId: null,
      );
      _rooms = [];
    });
    if (mounted) setState(() {});
  }

  Future<void> _handleLocalChanged(String? localId) async {
    if (!mounted) return;
    setState(() {
      _editedImage = _editedImage.copyWith(
        localId: localId,
        roomId: null,
      );
      _rooms = [];
    });

    if (localId != null) {
      try {
        final repository = SupabaseMediaRepository();
        final selectedLocalList = _locais.where((l) => l.id == localId).toList();
        if (selectedLocalList.isNotEmpty && selectedLocalList.first.localInstalacaoSap != null) {
          _rooms = await repository.getRooms(
            localInstalacao: selectedLocalList.first.localInstalacaoSap,
            userLocalNames: null,
          );
        }
        if (mounted) setState(() {});
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao carregar salas: $e')),
          );
        }
      }
    }
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_editedImage.tags.contains(tag)) {
      setState(() {
        _editedImage = _editedImage.copyWith(
          tags: [..._editedImage.tags, tag],
        );
      });
      _tagController.clear();
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _editedImage = _editedImage.copyWith(
        tags: _editedImage.tags.where((t) => t != tag).toList(),
      );
    });
  }

  /// Valida se o segmentId existe na lista antes de retornar
  String? _getValidRegionalValue() {
    if (_editedImage.regionalId == null) return null;
    final exists = _regionais.any((r) => r.id == _editedImage.regionalId);
    return exists ? _editedImage.regionalId : null;
  }

  String? _getValidDivisaoValue() {
    if (_editedImage.divisaoId == null) return null;
    final exists = _divisoes.any((d) => d.id == _editedImage.divisaoId);
    return exists ? _editedImage.divisaoId : null;
  }

  String? _getValidSegmentValue() {
    if (_editedImage.segmentId == null) return null;
    final exists = _segments.any((s) => s.id == _editedImage.segmentId);
    return exists ? _editedImage.segmentId : null;
  }

  /// Valida se o localId existe na lista antes de retornar
  String? _getValidLocalValue() {
    if (_editedImage.localId == null) return null;
    final exists = _locais.any((l) => l.id == _editedImage.localId);
    return exists ? _editedImage.localId : null;
  }

  /// Valida se o roomId existe na lista antes de retornar
  String? _getValidRoomValue() {
    if (_editedImage.roomId == null) return null;
    final exists = _rooms.any((r) => r.id == _editedImage.roomId);
    return exists ? _editedImage.roomId : null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final updated = _editedImage.copyWith(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      updatedAt: DateTime.now(),
    );

    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;
    final dialogPadding = isMobile ? 12.0 : (width < 1024 ? 20.0 : 24.0);
    final maxDialogWidth = isMobile ? width * 0.96 : 700.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(dialogPadding),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: maxDialogWidth,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1e293b) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Editar Imagem',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF1e293b),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close_rounded,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              // Campos
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 16 : 24),
                  child: _buildFormFields(theme, isDark),
                ),
              ),
              // Botões
              Container(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0f172a).withOpacity(0.5) : const Color(0xFFf8fafc),
                  border: Border(
                    top: BorderSide(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        side: BorderSide(
                          color: isDark ? const Color(0xFF475569) : const Color(0xFFcbd5e1),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Cancelar',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey[300] : const Color(0xFF1e293b),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1e40af),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 4,
                      ),
                      child: const Text(
                        'Salvar Alterações',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormFields(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Título e Descrição
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildFloatingLabelField(
              context,
              'Título *',
              _titleController,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'O título é obrigatório';
                }
                return null;
              },
              isDark: isDark,
            ),
            const SizedBox(height: 16),
            _buildFloatingLabelTextArea(
              context,
              'Descrição',
              _descriptionController,
              isDark: isDark,
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Divisor
        Divider(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0),
          height: 32,
        ),
        // Hierarquia
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'HIERARQUIA DE ATIVOS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: isDark ? Colors.grey[500] : Colors.grey[500],
              ),
            ),
            const SizedBox(height: 16),
            _buildFloatingLabelDropdown<String>(
              context,
              'Regional',
              _getValidRegionalValue(),
              [
                const DropdownMenuItem(value: null, child: Text('Nenhuma')),
                ..._regionais.map((r) => DropdownMenuItem(
                      value: r.id,
                      child: Text(r.regional),
                    )),
              ],
              _handleRegionalChanged,
              isDark: isDark,
            ),
            const SizedBox(height: 16),
            _buildFloatingLabelDropdown<String>(
              context,
              'Divisão',
              _getValidDivisaoValue(),
              [
                const DropdownMenuItem(value: null, child: Text('Nenhuma')),
                ..._divisoes.map((d) => DropdownMenuItem(
                      value: d.id,
                      child: Text(d.divisao),
                    )),
              ],
              _handleDivisaoChanged,
              isDark: isDark,
            ),
            const SizedBox(height: 16),
            _buildFloatingLabelDropdown<String>(
              context,
              'Segmento',
              _getValidSegmentValue(),
              [
                const DropdownMenuItem(value: null, child: Text('Nenhum')),
                ..._segments.map((s) => DropdownMenuItem(
                      value: s.id,
                      child: Text(s.name),
                    )),
              ],
              _handleSegmentChanged,
              isDark: isDark,
            ),
            const SizedBox(height: 16),
            _buildLocalDropdownWithSearch(context, isDark),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSalaDropdownWithSearch(context, isDark),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatusField(context, isDark),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Tags
        Text(
          'Tags',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.grey[300] : const Color(0xFF1e293b),
          ),
        ),
        const SizedBox(height: 8),
        _buildTagsField(context, isDark),
      ],
    );
  }

  Widget _buildFloatingLabelField(
    BuildContext context,
    String label,
    TextEditingController controller, {
    String? Function(String?)? validator,
    bool isDark = false,
  }) {
    return Stack(
      children: [
        TextFormField(
          controller: controller,
          validator: validator,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF1e293b),
          ),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.only(top: 20, bottom: 8, left: 12, right: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF475569) : const Color(0xFFcbd5e1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF475569) : const Color(0xFFcbd5e1),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Color(0xFF2563eb),
                width: 2,
              ),
            ),
            filled: false,
          ),
        ),
        Positioned(
          left: 12,
          top: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            color: isDark ? const Color(0xFF1e293b) : Colors.white,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[500] : Colors.grey[500],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingLabelTextArea(
    BuildContext context,
    String label,
    TextEditingController controller, {
    bool isDark = false,
  }) {
    return Stack(
      children: [
        TextFormField(
          controller: controller,
          maxLines: 3,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF1e293b),
          ),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.only(top: 20, bottom: 8, left: 12, right: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF475569) : const Color(0xFFcbd5e1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF475569) : const Color(0xFFcbd5e1),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Color(0xFF2563eb),
                width: 2,
              ),
            ),
            filled: false,
          ),
        ),
        Positioned(
          left: 12,
          top: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            color: isDark ? const Color(0xFF1e293b) : Colors.white,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[500] : Colors.grey[500],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocalDropdownWithSearch(BuildContext context, bool isDark) {
    final validLocalId = _getValidLocalValue();
    final selectedLocal = validLocalId != null
        ? _locais.where((l) => l.id == validLocalId).firstOrNull
        : null;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        DropdownSearch<Local>(
          popupProps: PopupProps.menu(
            showSearchBox: true,
            searchFieldProps: TextFieldProps(
              decoration: InputDecoration(
                hintText: 'Digite para buscar local...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF475569) : const Color(0xFFcbd5e1),
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                filled: true,
                fillColor: isDark ? const Color(0xFF1e293b) : Colors.white,
              ),
            ),
            menuProps: MenuProps(
              elevation: 4,
              color: isDark ? const Color(0xFF1e293b) : Colors.white,
            ),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
              minHeight: 200,
            ),
          ),
          items: (String filter, LoadProps? loadProps) async => _locais,
          selectedItem: selectedLocal,
          onChanged: (Local? value) => _handleLocalChanged(value?.id),
          itemAsString: (Local l) => l.local,
          compareFn: (Local a, Local b) => a.id == b.id,
          filterFn: (Local item, String filter) {
            if (filter.isEmpty || filter.trim().isEmpty) return true;
            final lower = filter.toLowerCase().trim();
            return item.local.toLowerCase().contains(lower) ||
                (item.descricao?.toLowerCase().contains(lower) ?? false) ||
                (item.localInstalacaoSap?.toLowerCase().contains(lower) ?? false);
          },
          decoratorProps: DropDownDecoratorProps(
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.only(top: 20, bottom: 8, left: 12, right: 32),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF475569) : const Color(0xFFcbd5e1),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF475569) : const Color(0xFFcbd5e1),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFF2563eb),
                  width: 2,
                ),
              ),
              filled: false,
            ),
          ),
          dropdownBuilder: (context, selectedItem) {
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                selectedItem?.local ?? 'Nenhum',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF1e293b),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            );
          },
        ),
        Positioned(
          left: 12,
          top: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            color: isDark ? const Color(0xFF1e293b) : Colors.white,
            child: Text(
              'LOCAL',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[500] : Colors.grey[500],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSalaDropdownWithSearch(BuildContext context, bool isDark) {
    final enabled = _editedImage.localId != null;
    final validRoomId = _getValidRoomValue();
    final selectedRoom = validRoomId != null
        ? _rooms.where((r) => r.id == validRoomId).firstOrNull
        : null;
    final widget = Stack(
      clipBehavior: Clip.none,
      children: [
        DropdownSearch<Room>(
          popupProps: PopupProps.menu(
            showSearchBox: true,
            searchFieldProps: TextFieldProps(
              decoration: InputDecoration(
                hintText: 'Digite para buscar sala...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF475569) : const Color(0xFFcbd5e1),
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                filled: true,
                fillColor: isDark ? const Color(0xFF1e293b) : Colors.white,
              ),
            ),
            menuProps: MenuProps(
              elevation: 4,
              color: isDark ? const Color(0xFF1e293b) : Colors.white,
            ),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
              minHeight: 200,
            ),
          ),
          items: (String filter, LoadProps? loadProps) async => _rooms,
          selectedItem: selectedRoom,
          onChanged: enabled
              ? (Room? value) {
                  setState(() {
                    _editedImage = _editedImage.copyWith(roomId: value?.id);
                  });
                }
              : null,
          itemAsString: (Room r) => r.name,
          compareFn: (Room a, Room b) => a.id == b.id,
          filterFn: (Room item, String filter) {
            if (filter.isEmpty || filter.trim().isEmpty) return true;
            final lower = filter.toLowerCase().trim();
            return item.name.toLowerCase().contains(lower) ||
                (item.localizacao?.toLowerCase().contains(lower) ?? false);
          },
          decoratorProps: DropDownDecoratorProps(
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.only(top: 20, bottom: 8, left: 12, right: 32),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF475569) : const Color(0xFFcbd5e1),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF475569) : const Color(0xFFcbd5e1),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFF2563eb),
                  width: 2,
                ),
              ),
              filled: false,
            ),
          ),
          dropdownBuilder: (context, selectedItem) {
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                selectedItem?.name ?? 'Nenhuma',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF1e293b),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            );
          },
        ),
        Positioned(
          left: 12,
          top: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            color: isDark ? const Color(0xFF1e293b) : Colors.white,
            child: Text(
              'SALA',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[500] : Colors.grey[500],
              ),
            ),
          ),
        ),
      ],
    );
    if (!enabled) {
      return IgnorePointer(
        child: Opacity(opacity: 0.6, child: widget),
      );
    }
    return widget;
  }

  Widget _buildFloatingLabelDropdown<T>(
    BuildContext context,
    String label,
    T? value,
    List<DropdownMenuItem<T>> items,
    ValueChanged<T?>? onChanged, {
    bool isDark = false,
  }) {
    return Stack(
      children: [
        DropdownButtonFormField<T>(
          initialValue: value,
          items: items,
          onChanged: onChanged,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF1e293b),
            fontSize: 14,
          ),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.only(top: 20, bottom: 8, left: 12, right: 32),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF475569) : const Color(0xFFcbd5e1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF475569) : const Color(0xFFcbd5e1),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Color(0xFF2563eb),
                width: 2,
              ),
            ),
            filled: false,
          ),
          icon: Icon(
            Icons.expand_more_rounded,
            color: isDark ? Colors.grey[400] : Colors.grey[500],
          ),
          dropdownColor: isDark ? const Color(0xFF1e293b) : Colors.white,
        ),
        Positioned(
          left: 12,
          top: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            color: isDark ? const Color(0xFF1e293b) : Colors.white,
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[500] : Colors.grey[500],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusField(BuildContext context, bool isDark) {
    // Usar statusAlbum se disponível, senão usar status enum
    final selectedStatusAlbumId = _editedImage.statusAlbumId;
    final selectedStatus = selectedStatusAlbumId != null
        ? _statusAlbums.firstWhere(
            (s) => s.id == selectedStatusAlbumId,
            orElse: () => _statusAlbums.isNotEmpty ? _statusAlbums.first : StatusAlbum(id: '', nome: 'Revisão'),
          )
        : null;

    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.only(top: 20, bottom: 8, left: 12, right: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: isDark ? const Color(0xFF475569) : const Color(0xFFcbd5e1),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: selectedStatus != null
                      ? selectedStatus.backgroundColor
                      : _getStatusColor(_editedImage.status, isDark),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      selectedStatus != null
                          ? _getStatusIconFromName(selectedStatus.nome)
                          : _getStatusIcon(_editedImage.status),
                      size: 14,
                      color: selectedStatus != null
                          ? selectedStatus.textColor
                          : _getStatusColor(_editedImage.status, isDark),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      selectedStatus != null
                          ? selectedStatus.nome
                          : _editedImage.status.displayName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: selectedStatus != null
                            ? selectedStatus.textColor
                            : _getStatusColor(_editedImage.status, isDark),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statusAlbums.isEmpty
                    ? Center(
                        child: _loadingReferences
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                'Nenhum status disponível',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                      )
                    : DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedStatusAlbumId ?? (_statusAlbums.isNotEmpty ? _statusAlbums.first.id : null),
                          items: [
                            ..._statusAlbums.map((s) => DropdownMenuItem<String>(
                                  value: s.id,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: s.backgroundColor,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: s.textColor,
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(s.nome),
                                    ],
                                  ),
                                )),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _editedImage = _editedImage.copyWith(statusAlbumId: value);
                                // Atualizar status enum para compatibilidade
                                final statusAlbum = _statusAlbums.firstWhere(
                                  (s) => s.id == value,
                                  orElse: () => _statusAlbums.isNotEmpty ? _statusAlbums.first : StatusAlbum(id: '', nome: 'Revisão'),
                                );
                                MediaImageStatus newStatus;
                                if (statusAlbum.nome.toLowerCase().contains('ok')) {
                                  newStatus = MediaImageStatus.ok;
                                } else if (statusAlbum.nome.toLowerCase().contains('atenção') || statusAlbum.nome.toLowerCase().contains('atencao')) {
                                  newStatus = MediaImageStatus.attention;
                                } else {
                                  newStatus = MediaImageStatus.review;
                                }
                                _editedImage = _editedImage.copyWith(status: newStatus);
                              });
                            }
                          },
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF1e293b),
                            fontSize: 14,
                          ),
                          dropdownColor: isDark ? const Color(0xFF1e293b) : Colors.white,
                          icon: const SizedBox.shrink(),
                        ),
                      ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 12,
          top: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            color: isDark ? const Color(0xFF1e293b) : Colors.white,
            child: Text(
              'STATUS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[500] : Colors.grey[500],
              ),
            ),
          ),
        ),
      ],
    );
  }

  IconData _getStatusIcon(MediaImageStatus status) {
    switch (status) {
      case MediaImageStatus.ok:
        return Icons.check_circle_rounded;
      case MediaImageStatus.attention:
        return Icons.error_outline_rounded;
      case MediaImageStatus.review:
        return Icons.feedback_rounded;
    }
  }

  IconData _getStatusIconFromName(String nome) {
    final nomeLower = nome.toLowerCase();
    if (nomeLower.contains('ok') || nomeLower.contains('aprovado')) {
      return Icons.check_circle_rounded;
    } else if (nomeLower.contains('atenção') || nomeLower.contains('alerta') || nomeLower.contains('erro') || nomeLower.contains('atencao')) {
      return Icons.error_outline_rounded;
    } else {
      return Icons.feedback_rounded;
    }
  }

  Color _getStatusColor(MediaImageStatus status, bool isDark) {
    switch (status) {
      case MediaImageStatus.ok:
        return isDark ? const Color(0xFF6ee7b7) : const Color(0xFF065f46);
      case MediaImageStatus.attention:
        return isDark ? const Color(0xFFfca5a5) : const Color(0xFF991b1b);
      case MediaImageStatus.review:
        return isDark ? const Color(0xFFfbbf24) : const Color(0xFF92400e);
    }
  }

  Widget _buildTagsField(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: isDark ? const Color(0xFF475569) : const Color(0xFFcbd5e1),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._editedImage.tags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFf1f5f9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tag.startsWith('#') ? tag : '#$tag',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => _removeTag(tag),
                        child: Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              }),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _tagController,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF1e293b),
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Adicionar tag...',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.grey[500] : Colors.grey[400],
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      onSubmitted: (_) => _addTag(),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.add_circle_rounded,
                      color: isDark ? Colors.grey[400] : Colors.grey[500],
                    ),
                    onPressed: _addTag,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
