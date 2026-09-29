import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../application/controllers/upload_controller.dart';
import '../../application/controllers/gallery_controller.dart';
import '../../data/models/segment.dart';
import '../../data/models/room.dart';
import '../../data/repositories/supabase_media_repository.dart';
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

/// Página TFDS para upload de imagens técnicas e fotos operacionais.
class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  late final UploadController _uploadController;
  late final GalleryController _galleryController;
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagController = TextEditingController();
  final SupabaseMediaRepository _mediaRepository = SupabaseMediaRepository();

  List<Regional> _regionais = [];
  List<Divisao> _divisoes = [];
  List<Segment> _segments = [];
  List<Local> _locais = [];
  List<Room> _rooms = [];
  bool _loadingReferences = false;

  @override
  void initState() {
    super.initState();
    _uploadController = UploadController();
    _uploadController.addListener(_onUploadControllerChanged);
    _galleryController = GalleryController();
    _loadReferences();
    _uploadController.loadStatusAlbums();
  }

  @override
  void dispose() {
    _uploadController.removeListener(_onUploadControllerChanged);
    _uploadController.dispose();
    _galleryController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _onUploadControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadReferences() async {
    if (!mounted) return;

    setState(() => _loadingReferences = true);
    try {
      final repository = SupabaseMediaRepository();
      final regionalService = RegionalService();
      final divisaoService = DivisaoService();
      final authService = AuthServiceSimples();
      final usuario = authService.currentUser;
      final userRegionalIds = usuario?.regionalIds;
      final userDivisaoIds = usuario?.divisaoIds;
      final userSegmentoIds = usuario?.segmentoIds;
      final isRootOrNoProfile = (usuario?.isRoot ?? false) ||
          ((userRegionalIds?.isEmpty ?? true) && (userDivisaoIds?.isEmpty ?? true) && (userSegmentoIds?.isEmpty ?? true));

      final allRegionais = await regionalService.getAllRegionais();
      _regionais = isRootOrNoProfile || (userRegionalIds?.isEmpty ?? true)
          ? allRegionais
          : allRegionais.where((r) => userRegionalIds!.contains(r.id)).toList();
      if (_regionais.length == 1) {
        _uploadController.setRegionalId(_regionais.first.id);
      }

      if (!mounted) return;

      final allDivisoes = await divisaoService.getAllDivisoes();
      if (_uploadController.selectedRegionalId != null) {
        _divisoes = allDivisoes
            .where((d) => d.regionalId == _uploadController.selectedRegionalId)
            .toList();
        if (!isRootOrNoProfile && (userDivisaoIds?.isNotEmpty ?? false)) {
          _divisoes = _divisoes.where((d) => userDivisaoIds!.contains(d.id)).toList();
        }
      } else {
        _divisoes = isRootOrNoProfile || (userDivisaoIds?.isEmpty ?? true)
            ? allDivisoes
            : allDivisoes.where((d) => userDivisaoIds!.contains(d.id)).toList();
      }
      if (_divisoes.length == 1) {
        _uploadController.setDivisaoId(_divisoes.first.id);
      }

      if (!mounted) return;

      final segmentoIdsList = userSegmentoIds != null ? List<String>.from(userSegmentoIds) : null;
      if (_uploadController.selectedDivisaoId != null) {
        final selectedDivisao = _divisoes.where((d) => d.id == _uploadController.selectedDivisaoId).toList();
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
      if (_segments.length == 1) {
        _uploadController.setSegmentId(_segments.first.id);
      }

      if (!mounted) return;

      _locais = await getLocaisForUsuario(usuario);

      if (!mounted) return;

      if (_uploadController.selectedLocalId != null) {
        final selectedLocalList = _locais.where((l) => l.id == _uploadController.selectedLocalId).toList();
        if (selectedLocalList.isNotEmpty && selectedLocalList.first.localInstalacaoSap != null) {
          _rooms = await repository.getRooms(
            localInstalacao: selectedLocalList.first.localInstalacaoSap,
            userLocalNames: null,
          );
        }
      }

      if (mounted) {
        setState(() {
          _loadingReferences = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar referências: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar referências: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _loadingReferences = false;
        });
      }
    }
  }

  Future<void> _handleRegionalChanged(String? regionalId) async {
    if (!mounted) return;
    _uploadController.setRegionalId(regionalId);
    await _loadReferences();
  }

  Future<void> _handleDivisaoChanged(String? divisaoId) async {
    if (!mounted) return;
    _uploadController.setDivisaoId(divisaoId);
    await _loadReferences();
  }

  Future<void> _handleSegmentChanged(String? segmentId) async {
    if (!mounted) return;
    _uploadController.setSegmentId(segmentId);
    _rooms = [];
    if (mounted) setState(() {});
  }

  Future<void> _handleLocalChanged(String? localId) async {
    if (!mounted) return;
    _uploadController.setLocalId(localId);
    if (localId != null) {
      final selectedLocalList = _locais.where((l) => l.id == localId).toList();
      if (selectedLocalList.isNotEmpty) {
        final selectedLocal = selectedLocalList.first;
        if (selectedLocal.localInstalacaoSap != null && selectedLocal.localInstalacaoSap!.trim().isNotEmpty) {
          _uploadController.setRoomId(null);
          _rooms = await SupabaseMediaRepository().getRooms(
            localInstalacao: selectedLocal.localInstalacaoSap,
            userLocalNames: null,
          );
          final equipmentIds = await SupabaseMediaRepository().getEquipmentIdsForLocalInstalacaoSap(selectedLocal.localInstalacaoSap!);
          _uploadController.setEquipmentId(equipmentIds.isNotEmpty ? equipmentIds.first : null);
        }
      }
      if (mounted) setState(() {});
    } else {
      _rooms = [];
      _uploadController.setRoomId(null);
      _uploadController.setEquipmentId(null);
      if (mounted) setState(() {});
    }
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty) {
      _uploadController.addTag(tag);
      _tagController.clear();
    }
  }

  Future<void> _handleUpload() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_uploadController.selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione pelo menos uma imagem para upload.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!mounted) return;

    _uploadController.setTitle(_titleController.text);
    _uploadController.setDescription(_descriptionController.text);

    try {
      final success = await _uploadController.uploadAll();

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Imagens salvas com sucesso!'),
            backgroundColor: Color(0xFF10b981),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else if (_uploadController.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_uploadController.error!),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao fazer upload: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;
    final isMobile = TFBreakpoints.isMobile(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: _uploadController.isUploading
          ? _buildUploadProgress(colors, typography, spacing)
          : Column(
              children: [
                TFPageHeader(
                  title: 'Adicionar Imagens Técnicas',
                  subtitle: 'Upload de fotos de ativos, anomalias e registros operacionais.',
                  leading: TFIconButton(
                    icon: TFIcons.chevronLeft,
                    tooltip: 'Voltar',
                    variant: TFIconButtonVariant.subtle,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(spacing.lg),
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 1280),
                        child: Form(
                          key: _formKey,
                          child: isMobile
                              ? _buildMobileLayout(colors, typography, spacing)
                              : _buildDesktopLayout(colors, typography, spacing),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildUploadProgress(
    dynamic colors,
    dynamic typography,
    dynamic spacing,
  ) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: EdgeInsets.all(spacing.xl),
        child: TFCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const TFLoading(message: 'Enviando imagens...'),
              SizedBox(height: spacing.lg),
              ..._uploadController.uploadProgress.map((progress) => Padding(
                    padding: EdgeInsets.symmetric(vertical: spacing.xs),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: TFRadius.borderRadiusFull,
                          child: LinearProgressIndicator(
                            value: progress.progress,
                            backgroundColor: colors.surfaceSecondary,
                            valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                            minHeight: 6,
                          ),
                        ),
                        SizedBox(height: spacing.xxs),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                progress.fileName,
                                style: typography.bodySmall.copyWith(color: colors.textSecondary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${(progress.progress * 100).toInt()}%',
                              style: typography.bodySmall.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        if (progress.error != null)
                          Text(
                            progress.error!,
                            style: typography.bodySmall.copyWith(color: colors.danger),
                          ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(
    dynamic colors,
    dynamic typography,
    dynamic spacing,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildImagePicker(colors, typography, spacing),
        SizedBox(height: spacing.lg),
        _buildImagePreviews(colors, typography, spacing),
        SizedBox(height: spacing.lg),
        _buildFormFields(colors, typography, spacing),
        SizedBox(height: spacing.lg),
        _buildActionButtons(spacing),
        SizedBox(height: spacing.lg),
        _buildInfoCard(colors, typography, spacing),
      ],
    );
  }

  Widget _buildDesktopLayout(
    dynamic colors,
    dynamic typography,
    dynamic spacing,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 7,
          child: Column(
            children: [
              _buildImagePicker(colors, typography, spacing),
              SizedBox(height: spacing.lg),
              _buildImagePreviews(colors, typography, spacing),
            ],
          ),
        ),
        SizedBox(width: spacing.xl),
        Expanded(
          flex: 5,
          child: Column(
            children: [
              _buildFormFields(colors, typography, spacing),
              SizedBox(height: spacing.lg),
              _buildActionButtons(spacing),
              SizedBox(height: spacing.lg),
              _buildInfoCard(colors, typography, spacing),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImagePicker(
    dynamic colors,
    dynamic typography,
    dynamic spacing,
  ) {
    return TFCard(
      child: InkWell(
        onTap: () => _uploadController.pickImages(fromCamera: false),
        borderRadius: TFRadius.borderRadiusMd,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: spacing.xxl, horizontal: spacing.lg),
          decoration: BoxDecoration(
            borderRadius: TFRadius.borderRadiusMd,
            border: Border.all(
              color: colors.borderDefault,
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: TFRadius.borderRadiusLg,
                ),
                child: Icon(
                  TFIcons.upload,
                  size: 32,
                  color: colors.primary,
                ),
              ),
              SizedBox(height: spacing.md),
              Text(
                'Upload de Imagens Técnicas',
                style: typography.cardTitle.copyWith(color: colors.textPrimary),
              ),
              SizedBox(height: spacing.xs),
              Text(
                'Selecione ou capture fotos de inspeção e anomalias. Formatos: JPG, PNG, WEBP.',
                style: typography.bodyMedium.copyWith(color: colors.textSecondary),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: spacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TFButton(
                    label: 'Galeria',
                    leadingIcon: Icons.folder_open_rounded,
                    variant: TFButtonVariant.secondary,
                    onPressed: () => _uploadController.pickImages(fromCamera: false),
                  ),
                  SizedBox(width: spacing.md),
                  TFButton(
                    label: 'Câmera',
                    leadingIcon: Icons.camera_alt_outlined,
                    variant: TFButtonVariant.secondary,
                    onPressed: () => _uploadController.pickImages(fromCamera: true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreviews(
    dynamic colors,
    dynamic typography,
    dynamic spacing,
  ) {
    if (_uploadController.selectedFiles.isEmpty) {
      return const SizedBox.shrink();
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: TFBreakpoints.isMobile(context) ? 3 : 4,
        crossAxisSpacing: spacing.md,
        mainAxisSpacing: spacing.md,
        childAspectRatio: 1,
      ),
      itemCount: _uploadController.selectedFiles.length + 1,
      itemBuilder: (context, index) {
        if (index == _uploadController.selectedFiles.length) {
          return InkWell(
            onTap: () => _uploadController.pickImages(fromCamera: false),
            borderRadius: TFRadius.borderRadiusMd,
            child: Container(
              decoration: BoxDecoration(
                color: colors.surfaceSecondary.withValues(alpha: 0.4),
                borderRadius: TFRadius.borderRadiusMd,
                border: Border.all(color: colors.borderDefault),
              ),
              child: Center(
                child: Icon(
                  TFIcons.add,
                  color: colors.textSecondary,
                  size: 28,
                ),
              ),
            ),
          );
        }

        final file = _uploadController.selectedFiles[index];
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: TFRadius.borderRadiusMd,
              child: kIsWeb
                  ? FutureBuilder<Uint8List>(
                      future: file.readAsBytes(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          return Image.memory(
                            snapshot.data!,
                            fit: BoxFit.cover,
                          );
                        }
                        return Container(
                          color: colors.surfaceSecondary,
                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        );
                      },
                    )
                  : Image.file(
                      File(file.path),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: colors.surfaceSecondary,
                          child: Icon(Icons.image_outlined, color: colors.textSecondary),
                        );
                      },
                    ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  color: Colors.white,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () => _uploadController.removeFile(index),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFormFields(
    dynamic colors,
    dynamic typography,
    dynamic spacing,
  ) {
    return TFCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TFTextField(
            label: 'Título *',
            controller: _titleController,
            hint: 'Identificação da imagem técnica',
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
            hint: 'Observações, anomalias ou notas de inspeção',
            maxLines: 3,
          ),
          SizedBox(height: spacing.lg),

          // Hierarquia de Ativos
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
            value: _uploadController.selectedRegionalId,
            items: [null, ..._regionais.map((r) => r.id)],
            displayText: (id) => id == null ? 'Nenhuma' : (_regionais.where((r) => r.id == id).firstOrNull?.regional ?? 'Nenhuma'),
            onChanged: _handleRegionalChanged,
          ),
          SizedBox(height: spacing.md),
          TFDropdown<String?>(
            label: 'Divisão',
            value: _uploadController.selectedDivisaoId,
            items: [null, ..._divisoes.map((d) => d.id)],
            displayText: (id) => id == null ? 'Nenhuma' : (_divisoes.where((d) => d.id == id).firstOrNull?.divisao ?? 'Nenhuma'),
            onChanged: _handleDivisaoChanged,
          ),
          SizedBox(height: spacing.md),
          TFDropdown<String?>(
            label: 'Segmento',
            value: _uploadController.selectedSegmentId,
            items: [null, ..._segments.map((s) => s.id)],
            displayText: (id) => id == null ? 'Nenhum' : (_segments.where((s) => s.id == id).firstOrNull?.name ?? 'Nenhum'),
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

          // Tags
          Text(
            'Tags',
            style: typography.label.copyWith(
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
    final selectedLocal = _uploadController.selectedLocalId != null
        ? _locais.where((l) => l.id == _uploadController.selectedLocalId).firstOrNull
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
    final enabled = _uploadController.selectedLocalId != null;
    final selectedRoom = _uploadController.selectedRoomId != null
        ? _rooms.where((r) => r.id == _uploadController.selectedRoomId).firstOrNull
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Sala',
              style: typography.label.copyWith(color: colors.textPrimary),
            ),
            if (enabled)
              InkWell(
                onTap: _handleAddRoom,
                child: Text(
                  '+ Nova sala',
                  style: typography.bodySmall.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
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
          onChanged: enabled ? (Room? value) => _uploadController.setRoomId(value?.id) : null,
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
    final selectedStatusAlbumId = _uploadController.statusAlbumId;
    final selectedStatus = selectedStatusAlbumId != null && _uploadController.statusAlbums.isNotEmpty
        ? _uploadController.statusAlbums.firstWhere(
            (s) => s.id == selectedStatusAlbumId,
            orElse: () => _uploadController.statusAlbums.first,
          )
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Status',
          style: typography.label.copyWith(color: colors.textPrimary),
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
              if (selectedStatus != null)
                StatusBadge(
                  status: _uploadController.status,
                  statusAlbum: selectedStatus,
                )
              else
                Text(
                  _uploadController.status.displayName,
                  style: typography.bodyMedium.copyWith(color: colors.textPrimary),
                ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedStatusAlbumId ?? (_uploadController.statusAlbums.isNotEmpty ? _uploadController.statusAlbums.first.id : null),
                    items: [
                      ..._uploadController.statusAlbums.map((s) => DropdownMenuItem<String>(
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
                        _uploadController.setStatusAlbumId(value);
                        setState(() {});
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
              ..._uploadController.tags.map((tag) {
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
                        onTap: () => _uploadController.removeTag(tag),
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

  Widget _buildActionButtons(dynamic spacing) {
    return Row(
      children: [
        Expanded(
          child: TFButton(
            label: 'Cancelar',
            variant: TFButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        SizedBox(width: spacing.md),
        Expanded(
          flex: 2,
          child: TFButton(
            label: 'Salvar Imagens',
            leadingIcon: TFIcons.save,
            variant: TFButtonVariant.primary,
            onPressed: _handleUpload,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(
    dynamic colors,
    dynamic typography,
    dynamic spacing,
  ) {
    return Container(
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: colors.info.withValues(alpha: 0.08),
        borderRadius: TFRadius.borderRadiusMd,
        border: Border.all(color: colors.info.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            TFIcons.info,
            color: colors.info,
            size: 20,
          ),
          SizedBox(width: spacing.sm),
          Expanded(
            child: Text(
              'Certifique-se de que a iluminação está adequada antes de realizar o upload. As imagens serão indexadas na hierarquia de ativos selecionada.',
              style: typography.bodySmall.copyWith(
                color: colors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAddRoom() async {
    if (_uploadController.selectedLocalId == null) return;
    final controller = TextEditingController();
    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Adicionar nova sala'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Nome da sala',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Adicionar'),
            ),
          ],
        );
      },
    );
    if (newName != null && newName.trim().isNotEmpty) {
      if (_locais.isEmpty) return;
      final trimmed = newName.trim();
      final selectedLocal = _locais.firstWhere(
        (l) => l.id == _uploadController.selectedLocalId,
        orElse: () => _locais.first,
      );
      final localInst = selectedLocal.localInstalacaoSap ?? selectedLocal.local;
      try {
        await _mediaRepository.insertSalaEquipamentosSap(
          localInstalacao: localInst,
          sala: trimmed,
          localizacao: localInst,
        );
        final created = Room.fromEquipamentosSap(trimmed, localInst);
        if (!mounted) return;
        setState(() {
          _rooms = [
            ..._rooms.where((r) => r.id != created.id),
            created,
          ]..sort((a, b) => a.name.compareTo(b.name));
        });
        _uploadController.setRoomId(created.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sala adicionada em equipamentos_sap.'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        debugPrint('Erro ao criar sala: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao salvar sala: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
