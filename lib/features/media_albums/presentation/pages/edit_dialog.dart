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
import '../../../../design_system/taskflow_design_system.dart';
import '../widgets/status_badge.dart';

/// Diálogo modal TFDS para edição de metadados e hierarquia de imagem de mídia.
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

  String? _getValidLocalValue() {
    if (_editedImage.localId == null) return null;
    final exists = _locais.any((l) => l.id == _editedImage.localId);
    return exists ? _editedImage.localId : null;
  }

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
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    return TFFormDialog(
      title: 'Editar Imagem',
      subtitle: 'Atualize os metadados e hierarquia da mídia.',
      onCancel: () => Navigator.of(context).pop(),
      onSave: _save,
      saveLabel: 'Salvar Alterações',
      maxWidth: 680,
      formKey: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Dados Básicos
          TFTextField(
            label: 'Título *',
            controller: _titleController,
            hint: 'Título da foto técnica',
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'O título é obrigatório';
              }
              return null;
            },
          ),
          SizedBox(height: spacing.md),
          TFTextField(
            label: 'Descrição',
            controller: _descriptionController,
            hint: 'Observações técnicas, anomalias ou detalhes',
            maxLines: 3,
          ),
          SizedBox(height: spacing.lg),

          // 2. Hierarquia de Ativos
          Row(
            children: [
              Text(
                'HIERARQUIA DE ATIVOS',
                style: typography.labelMedium.copyWith(
                  color: colors.textSecondary,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_loadingReferences) ...[
                SizedBox(width: spacing.sm),
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
          SizedBox(height: spacing.md),
          TFDropdown<String?>(
            label: 'Regional',
            value: _getValidRegionalValue(),
            items: [null, ..._regionais.map((r) => r.id)],
            displayText: (id) => id == null ? 'Nenhuma' : _regionais.where((r) => r.id == id).firstOrNull?.regional ?? 'Nenhuma',
            onChanged: _handleRegionalChanged,
          ),
          SizedBox(height: spacing.md),
          TFDropdown<String?>(
            label: 'Divisão',
            value: _getValidDivisaoValue(),
            items: [null, ..._divisoes.map((d) => d.id)],
            displayText: (id) => id == null ? 'Nenhuma' : _divisoes.where((d) => d.id == id).firstOrNull?.divisao ?? 'Nenhuma',
            onChanged: _handleDivisaoChanged,
          ),
          SizedBox(height: spacing.md),
          TFDropdown<String?>(
            label: 'Segmento',
            value: _getValidSegmentValue(),
            items: [null, ..._segments.map((s) => s.id)],
            displayText: (id) => id == null ? 'Nenhum' : _segments.where((s) => s.id == id).firstOrNull?.name ?? 'Nenhum',
            onChanged: _handleSegmentChanged,
          ),
          SizedBox(height: spacing.md),
          _buildLocalDropdown(context, colors, typography, spacing),
          SizedBox(height: spacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildSalaDropdown(context, colors, typography, spacing),
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: _buildStatusField(context, colors, typography, spacing),
              ),
            ],
          ),
          SizedBox(height: spacing.lg),

          // 3. Tags
          Text(
            'Tags',
            style: typography.labelMedium.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: spacing.xs),
          _buildTagsContainer(colors, typography, spacing),
        ],
      ),
    );
  }

  Widget _buildLocalDropdown(
    BuildContext context,
    dynamic colors,
    dynamic typography,
    dynamic spacing,
  ) {
    final validLocalId = _getValidLocalValue();
    final selectedLocal = validLocalId != null
        ? _locais.where((l) => l.id == validLocalId).firstOrNull
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Local',
          style: typography.label.copyWith(color: colors.textPrimary),
        ),
        SizedBox(height: spacing.xs),
        DropdownSearch<Local>(
          popupProps: PopupProps.menu(
            showSearchBox: true,
            searchFieldProps: TextFieldProps(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Digite para buscar local...',
                contentPadding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
                border: OutlineInputBorder(
                  borderRadius: TFRadius.borderRadiusMd,
                  borderSide: BorderSide(color: colors.borderDefault),
                ),
              ),
            ),
            menuProps: MenuProps(
              elevation: 4,
              color: colors.surface,
            ),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
              minHeight: 180,
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
              contentPadding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
              border: OutlineInputBorder(
                borderRadius: TFRadius.borderRadiusMd,
                borderSide: BorderSide(color: colors.borderDefault),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: TFRadius.borderRadiusMd,
                borderSide: BorderSide(color: colors.borderDefault),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: TFRadius.borderRadiusMd,
                borderSide: BorderSide(color: colors.primary, width: 2),
              ),
              filled: true,
              fillColor: colors.surface,
            ),
          ),
          dropdownBuilder: (context, selectedItem) {
            return Text(
              selectedItem?.local ?? 'Nenhum local selecionado',
              style: typography.bodyMedium.copyWith(
                color: selectedItem != null ? colors.textPrimary : colors.textPlaceholder,
              ),
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
      ],
    );
  }

  Widget _buildSalaDropdown(
    BuildContext context,
    dynamic colors,
    dynamic typography,
    dynamic spacing,
  ) {
    final enabled = _editedImage.localId != null;
    final validRoomId = _getValidRoomValue();
    final selectedRoom = validRoomId != null
        ? _rooms.where((r) => r.id == validRoomId).firstOrNull
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sala',
          style: typography.label.copyWith(color: colors.textPrimary),
        ),
        SizedBox(height: spacing.xs),
        DropdownSearch<Room>(
          popupProps: PopupProps.menu(
            showSearchBox: true,
            searchFieldProps: TextFieldProps(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Digite para buscar sala...',
                contentPadding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
                border: OutlineInputBorder(
                  borderRadius: TFRadius.borderRadiusMd,
                  borderSide: BorderSide(color: colors.borderDefault),
                ),
              ),
            ),
            menuProps: MenuProps(
              elevation: 4,
              color: colors.surface,
            ),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
              minHeight: 180,
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
              contentPadding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
              border: OutlineInputBorder(
                borderRadius: TFRadius.borderRadiusMd,
                borderSide: BorderSide(color: colors.borderDefault),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: TFRadius.borderRadiusMd,
                borderSide: BorderSide(color: colors.borderDefault),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: TFRadius.borderRadiusMd,
                borderSide: BorderSide(color: colors.primary, width: 2),
              ),
              filled: true,
              fillColor: colors.surface,
            ),
          ),
          dropdownBuilder: (context, selectedItem) {
            return Text(
              selectedItem?.name ?? (enabled ? 'Nenhuma sala selecionada' : 'Selecione um local primeiro'),
              style: typography.bodyMedium.copyWith(
                color: selectedItem != null ? colors.textPrimary : colors.textPlaceholder,
              ),
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatusField(
    BuildContext context,
    dynamic colors,
    dynamic typography,
    dynamic spacing,
  ) {
    final selectedStatusAlbumId = _editedImage.statusAlbumId;
    final selectedStatus = selectedStatusAlbumId != null && _statusAlbums.isNotEmpty
        ? _statusAlbums.firstWhere(
            (s) => s.id == selectedStatusAlbumId,
            orElse: () => _statusAlbums.first,
          )
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Status',
          style: typography.labelMedium.copyWith(color: colors.textPrimary),
        ),
        SizedBox(height: spacing.xs),
        Container(
          padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.xs),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: TFRadius.borderRadiusMd,
            border: Border.all(color: colors.borderDefault),
          ),
          child: Row(
            children: [
              StatusBadge(
                status: _editedImage.status,
                statusAlbum: selectedStatus,
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedStatusAlbumId,
                    items: [
                      ..._statusAlbums.map((s) => DropdownMenuItem<String>(
                            value: s.id,
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: s.backgroundColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: s.textColor, width: 1),
                                  ),
                                ),
                                SizedBox(width: spacing.xs),
                                Text(
                                  s.nome,
                                  style: typography.bodyMedium.copyWith(color: colors.textPrimary),
                                ),
                              ],
                            ),
                          )),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _editedImage = _editedImage.copyWith(statusAlbumId: value);
                        });
                      }
                    },
                    dropdownColor: colors.surface,
                    icon: Icon(TFIcons.chevronDown, size: 16, color: colors.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTagsContainer(
    dynamic colors,
    dynamic typography,
    dynamic spacing,
  ) {
    return Container(
      padding: EdgeInsets.all(spacing.sm),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: TFRadius.borderRadiusMd,
        border: Border.all(color: colors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: spacing.xs,
            runSpacing: spacing.xs,
            children: [
              ..._editedImage.tags.map((tag) {
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xxs),
                  decoration: BoxDecoration(
                    color: colors.surfaceSecondary,
                    borderRadius: TFRadius.borderRadiusSm,
                    border: Border.all(color: colors.borderSubtle),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tag,
                        style: typography.bodySmall.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: spacing.xxs),
                      InkWell(
                        onTap: () => _removeTag(tag),
                        child: Icon(
                          TFIcons.close,
                          size: 14,
                          color: colors.textSecondary,
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
                    width: 140,
                    child: TextField(
                      controller: _tagController,
                      style: typography.bodyMedium.copyWith(color: colors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Adicionar tag...',
                        hintStyle: typography.bodySmall.copyWith(color: colors.textPlaceholder),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: spacing.xs),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _addTag(),
                    ),
                  ),
                  TFIconButton(
                    icon: TFIcons.add,
                    tooltip: 'Adicionar tag',
                    variant: TFIconButtonVariant.subtle,
                    iconSize: 16,
                    onPressed: _addTag,
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
