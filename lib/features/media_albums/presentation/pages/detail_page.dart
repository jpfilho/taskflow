import 'dart:ui' as ui show ImageByteFormat;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../design_system/components/buttons/tf_button.dart';
import '../../../../design_system/components/buttons/tf_icon_button.dart';
import '../../../../design_system/components/dialogs/tf_modal_dialog.dart';
import '../../../../design_system/components/feedback/tf_empty_state.dart';
import '../../../../design_system/components/feedback/tf_loading.dart';
import '../../../../design_system/foundations/tf_icons.dart';
import '../../../../design_system/foundations/tf_radius.dart';
import '../../../../design_system/theme/taskflow_theme_extension.dart';
import '../../data/models/media_image.dart';
import '../../data/repositories/supabase_media_repository.dart';
import '../../application/controllers/annotation_controller.dart';
import '../widgets/annotation_canvas.dart';
import '../widgets/annotation_toolbar.dart';
import '../widgets/status_badge.dart';
import 'edit_dialog.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class DetailPage extends StatefulWidget {
  final String imageId;

  const DetailPage({
    super.key,
    required this.imageId,
  });

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  final SupabaseMediaRepository _repository = SupabaseMediaRepository();
  final PhotoViewController _photoViewController = PhotoViewController();
  final PhotoViewScaleStateController _scaleStateController = PhotoViewScaleStateController();
  MediaImage? _image;
  bool _isLoading = true;
  String? _error;
  bool _isFullscreen = false;

  bool _annotationMode = false;
  bool _showAnnotated = true;
  String? _annotationImageUrl;
  bool _isSavingAnnotations = false;
  AnnotationController? _annotationController;
  final GlobalKey _annotationRepaintKey = GlobalKey();

  String? get _displayImageUrl {
    if (_image == null) return null;
    if (_showAnnotated && _image!.annotatedFileUrl != null) return _image!.annotatedFileUrl;
    return _image!.fileUrl;
  }

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void dispose() {
    _photoViewController.dispose();
    _scaleStateController.dispose();
    super.dispose();
  }

  Future<void> _openAnnotationMode() async {
    if (_image == null) return;
    String? urlToUse;
    try {
      urlToUse = await _repository.getSignedUrl(_image!.filePath, expiresIn: 3600);
    } catch (_) {
      urlToUse = _repository.getPublicUrl(_image!.filePath);
    }
    if (urlToUse.isEmpty) urlToUse = _image!.fileUrl;
    if (urlToUse == null || urlToUse.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível obter a URL da imagem. Tente novamente.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _annotationImageUrl = urlToUse;
      _annotationController = AnnotationController(
        mediaImageId: _image!.id,
        repository: _repository,
      );
      _annotationMode = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _annotationController?.load();
    });
  }

  void _closeAnnotationMode() {
    setState(() {
      _annotationImageUrl = null;
      _annotationController = null;
      _annotationMode = false;
    });
  }

  Future<void> _saveAnnotations() async {
    if (_annotationController == null || _image == null || _isSavingAnnotations) return;
    setState(() => _isSavingAnnotations = true);
    try {
      Future<List<int>> exportPng() async {
        final boundary = _annotationRepaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary == null) return [];
        final image = await boundary.toImage(pixelRatio: 3.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        final list = byteData?.buffer.asUint8List();
        return list ?? [];
      }
      await _annotationController!.save(
        exportPngBytes: exportPng,
        mediaImageForPath: _image,
      );
      if (mounted) {
        _loadImage();
        _closeAnnotationMode();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Anotações salvas com sucesso.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar anotações: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingAnnotations = false);
    }
  }

  Future<void> _showTextAnnotationDialog(Offset position) async {
    if (_annotationController == null) return;
    final text = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Texto da Anotação'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Digite a observação...'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Adicionar'),
            ),
          ],
        );
      },
    );
    if (text != null && text.trim().isNotEmpty) {
      _annotationController!.addTextAt(position, text.trim());
    }
  }

  Future<void> _loadImage() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final image = await _repository.getMediaImageById(widget.imageId);
      setState(() {
        _image = image;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _editImage() async {
    if (_image == null) return;

    final updated = await showDialog<MediaImage>(
      context: context,
      builder: (context) => EditDialog(image: _image!),
    );

    if (updated != null) {
      try {
        await _repository.updateMediaImage(updated);
        _loadImage();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Metadados da imagem atualizados!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao atualizar: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteImage() async {
    if (_image == null) return;

    final confirmed = await TFModalDialog.confirm(
      context: context,
      title: 'Excluir Imagem',
      message: 'Tem certeza que deseja excluir esta imagem permanentemente? Esta ação não pode ser desfeita.',
      confirmLabel: 'Excluir Imagem',
      isDestructive: true,
    );

    if (confirmed == true) {
      try {
        await _repository.deleteFile(_image!.filePath);
        if (_image!.thumbPath != null) {
          await _repository.deleteFile(_image!.thumbPath!);
        }
        await _repository.deleteMediaImage(_image!.id);

        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao deletar imagem: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _shareImage() async {
    if (_displayImageUrl == null) return;

    try {
      if (Theme.of(context).platform == TargetPlatform.iOS ||
          Theme.of(context).platform == TargetPlatform.android) {
        try {
          final resp = await http.get(Uri.parse(_displayImageUrl!));
          if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
            final file = XFile.fromData(
              resp.bodyBytes,
              mimeType: 'image/jpeg',
              name: 'imagem.jpg',
            );
            await Share.shareXFiles([file], text: widget.imageId);
            return;
          }
        } catch (_) {}
        await Share.share(_displayImageUrl!);
      } else {
        final uri = Uri.parse(_displayImageUrl!);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao compartilhar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: colors.background,
        body: const Center(child: TFLoading(message: 'Carregando foto e anotações...')),
      );
    }

    if (_error != null || _image == null) {
      return Scaffold(
        backgroundColor: colors.background,
        body: Center(
          child: TFEmptyState(
            title: 'Imagem não encontrada',
            description: _error ?? 'Não foi possível carregar os dados desta imagem.',
            icon: TFIcons.warning,
            action: TFButton(
              label: 'Tentar Novamente',
              leadingIcon: TFIcons.refresh,
              onPressed: _loadImage,
            ),
          ),
        ),
      );
    }

    if (_annotationMode && _annotationController != null && (_annotationImageUrl != null || _image?.fileUrl != null)) {
      return _buildAnnotationView(context, isMobile);
    }

    if (_isFullscreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: _buildFullscreenViewer(),
      );
    }

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, isMobile),
            Expanded(
              child: isMobile
                  ? _buildMobileLayout(context)
                  : _buildDesktopLayout(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnotationView(BuildContext context, bool isMobile) {
    final colors = context.tfColors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Editar / Anotar Imagem'),
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: _closeAnnotationMode,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: AnnotationCanvas(
              imageUrl: _annotationImageUrl ?? _image!.fileUrl!,
              controller: _annotationController!,
              repaintBoundaryKey: _annotationRepaintKey,
              onTextTap: _showTextAnnotationDialog,
            ),
          ),
          SizedBox(
            height: 280,
            child: SingleChildScrollView(
              child: AnnotationToolbar(
                controller: _annotationController!,
                onSave: _saveAnnotations,
                onCancel: _closeAnnotationMode,
                isSaving: _isSavingAnnotations,
                isCompact: isMobile,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isMobile) {
    final colors = context.tfColors;
    final spacing = context.tfSpacing;
    final typography = context.tfTypography;

    final shortTitle = _image!.title.length > 35
        ? '${_image!.title.substring(0, 35)}...'
        : _image!.title;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.xs),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.borderSubtle)),
      ),
      child: Row(
        children: [
          TFIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Voltar',
            onPressed: () => Navigator.of(context).pop(),
          ),
          SizedBox(width: spacing.sm),
          Expanded(
            child: Text(
              shortTitle,
              style: typography.cardTitle.copyWith(color: colors.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_image!.annotatedFileUrl != null && !isMobile) ...[
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Com anotações'), icon: Icon(Icons.draw_rounded, size: 16)),
                ButtonSegment(value: false, label: Text('Original'), icon: Icon(Icons.image_rounded, size: 16)),
              ],
              selected: {_showAnnotated},
              onSelectionChanged: (Set<bool> selected) {
                setState(() => _showAnnotated = selected.first);
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                textStyle: WidgetStateProperty.all(typography.caption),
              ),
            ),
            SizedBox(width: spacing.sm),
          ],
          TFIconButton(
            icon: Icons.share_rounded,
            tooltip: 'Compartilhar',
            onPressed: _shareImage,
          ),
          TFIconButton(
            icon: Icons.draw_rounded,
            tooltip: 'Anotar / Desenhar',
            onPressed: _openAnnotationMode,
          ),
          TFIconButton(
            icon: TFIcons.edit,
            tooltip: 'Editar Metadados',
            onPressed: _editImage,
          ),
          TFIconButton(
            icon: TFIcons.delete,
            tooltip: 'Excluir Imagem',
            onPressed: _deleteImage,
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.35,
          child: _buildImageViewer(),
        ),
        Expanded(
          child: _buildMetadataPanel(context),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final panelWidth = width < 1024 ? 320.0 : 380.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _buildImageViewer(),
        ),
        SizedBox(
          width: panelWidth,
          child: _buildMetadataPanel(context),
        ),
      ],
    );
  }

  Widget _buildImageViewer() {
    final colors = context.tfColors;

    if (_displayImageUrl == null) {
      return Container(
        color: colors.background,
        child: Center(
          child: Icon(
            Icons.broken_image_rounded,
            size: 64,
            color: colors.textSecondary,
          ),
        ),
      );
    }

    return _isFullscreen
        ? _buildFullscreenViewer()
        : _buildNormalViewer();
  }

  Widget _buildNormalViewer() {
    final colors = context.tfColors;
    final spacing = context.tfSpacing;

    return Container(
      color: Colors.black,
      padding: EdgeInsets.all(spacing.sm),
      child: Center(
        child: ClipRRect(
          borderRadius: TFRadius.borderRadiusMd,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Listener(
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent) {
                    if (event.scrollDelta.dy < 0) {
                      _zoomIn();
                      setState(() {});
                    } else if (event.scrollDelta.dy > 0) {
                      _zoomOut();
                      setState(() {});
                    }
                  }
                },
                child: PhotoView(
                  imageProvider: CachedNetworkImageProvider(_displayImageUrl!),
                  controller: _photoViewController,
                  scaleStateController: _scaleStateController,
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 3.0,
                  initialScale: PhotoViewComputedScale.contained,
                  backgroundDecoration: const BoxDecoration(color: Colors.black),
                  enableRotation: false,
                  heroAttributes: PhotoViewHeroAttributes(tag: _image!.id),
                  enablePanAlways: true,
                ),
              ),
              Positioned(
                bottom: spacing.md,
                right: spacing.md,
                child: Container(
                  padding: EdgeInsets.all(spacing.xxs),
                  decoration: BoxDecoration(
                    color: colors.surface.withValues(alpha: 0.85),
                    borderRadius: TFRadius.borderRadiusMd,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TFIconButton(
                        icon: Icons.zoom_in_rounded,
                        tooltip: 'Aproximar',
                        onPressed: () {
                          _zoomIn();
                          setState(() {});
                        },
                      ),
                      TFIconButton(
                        icon: Icons.zoom_out_rounded,
                        tooltip: 'Afastar',
                        onPressed: () {
                          _zoomOut();
                          setState(() {});
                        },
                      ),
                      TFIconButton(
                        icon: Icons.fullscreen_rounded,
                        tooltip: 'Tela Cheia',
                        onPressed: _enterFullscreen,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullscreenViewer() {
    final spacing = context.tfSpacing;

    return Stack(
      children: [
        Listener(
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) {
              if (event.scrollDelta.dy < 0) {
                _zoomIn();
                setState(() {});
              } else if (event.scrollDelta.dy > 0) {
                _zoomOut();
                setState(() {});
              }
            }
          },
          child: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: PhotoView(
              imageProvider: CachedNetworkImageProvider(_displayImageUrl!),
              controller: _photoViewController,
              scaleStateController: _scaleStateController,
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 3.0,
              initialScale: PhotoViewComputedScale.contained,
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              enableRotation: false,
              heroAttributes: PhotoViewHeroAttributes(tag: _image!.id),
              enablePanAlways: true,
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: EdgeInsets.all(spacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                  onPressed: _exitFullscreen,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.zoom_in_rounded, color: Colors.white),
                      onPressed: () {
                        _zoomIn();
                        setState(() {});
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.zoom_out_rounded, color: Colors.white),
                      onPressed: () {
                        _zoomOut();
                        setState(() {});
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.fullscreen_exit_rounded, color: Colors.white),
                      onPressed: _exitFullscreen,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static const double _minScale = 0.5;
  static const double _maxScale = 5.0;
  static const double _zoomStep = 1.25;

  void _zoomIn() {
    final current = _photoViewController.scale ?? 1.0;
    final next = (current * _zoomStep).clamp(_minScale, _maxScale);
    _photoViewController.scale = next;
  }

  void _zoomOut() {
    final current = _photoViewController.scale ?? 1.0;
    final next = (current / _zoomStep).clamp(_minScale, _maxScale);
    _photoViewController.scale = next;
  }

  void _enterFullscreen() {
    setState(() {
      _isFullscreen = true;
    });
  }

  void _exitFullscreen() {
    setState(() {
      _isFullscreen = false;
    });
  }

  Widget _buildMetadataPanel(BuildContext context) {
    final colors = context.tfColors;
    final spacing = context.tfSpacing;
    final typography = context.tfTypography;
    final dateFormat = DateFormat('dd/MM/yyyy \'às\' HH:mm', 'pt_BR');

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(left: BorderSide(color: colors.borderSubtle)),
      ),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(spacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      StatusBadge(
                        status: _image!.status,
                        statusAlbum: _image!.statusAlbum,
                      ),
                      SizedBox(width: spacing.sm),
                      Text(
                        'ID: #${_image!.id.length > 8 ? _image!.id.substring(0, 8) : _image!.id}',
                        style: typography.caption.copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ),
                  SizedBox(height: spacing.sm),
                  Text(
                    _image!.title,
                    style: typography.sectionTitle.copyWith(color: colors.textPrimary),
                  ),
                  SizedBox(height: spacing.md),
                  Text(
                    'DESCRIÇÃO',
                    style: typography.caption.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: colors.textSecondary,
                    ),
                  ),
                  SizedBox(height: spacing.xxs),
                  Text(
                    _image!.description != null && _image!.description!.isNotEmpty
                        ? _image!.description!
                        : 'Sem descrição cadastrada.',
                    style: typography.bodyMedium.copyWith(
                      color: colors.textSecondary,
                      fontStyle: _image!.description == null || _image!.description!.isEmpty
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),
                  SizedBox(height: spacing.md),
                  Divider(color: colors.borderSubtle, height: 1),
                  SizedBox(height: spacing.md),
                  Text(
                    'HIERARQUIA',
                    style: typography.caption.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: colors.textSecondary,
                    ),
                  ),
                  SizedBox(height: spacing.xs),
                  if (_image!.regionalName != null)
                    _buildHierarchyRow(context, Icons.public_rounded, 'Regional', _image!.regionalName!),
                  if (_image!.divisaoName != null)
                    _buildHierarchyRow(context, Icons.account_tree_rounded, 'Divisão', _image!.divisaoName!),
                  if (_image!.segmentName != null)
                    _buildHierarchyRow(context, Icons.business_rounded, 'Segmento', _image!.segmentName!),
                  if (_image!.localName != null)
                    _buildHierarchyRow(context, Icons.place_rounded, 'Local', _image!.localName!),
                  if (_image!.roomName != null)
                    _buildHierarchyRow(context, Icons.meeting_room_rounded, 'Sala', _image!.roomName!),

                  SizedBox(height: spacing.md),
                  Divider(color: colors.borderSubtle, height: 1),
                  SizedBox(height: spacing.md),
                  Text(
                    'METADADOS',
                    style: typography.caption.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: colors.textSecondary,
                    ),
                  ),
                  SizedBox(height: spacing.xs),
                  _buildMetaRow(context, Icons.calendar_today_rounded, 'Criado em:', dateFormat.format(_image!.createdAt)),
                  _buildMetaRow(context, Icons.update_rounded, 'Atualizado em:', dateFormat.format(_image!.updatedAt)),
                  _buildMetaRow(context, Icons.person_outline_rounded, 'Cadastrado por:', _image!.creatorName ?? '—'),
                  if (_image!.annotatorName != null && _image!.annotatorName!.isNotEmpty)
                    _buildMetaRow(context, Icons.draw_rounded, 'Anotado por:', _image!.annotatorName!),

                  if (_image!.tags.isNotEmpty) ...[
                    SizedBox(height: spacing.md),
                    Text(
                      'TAGS',
                      style: typography.caption.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: colors.textSecondary,
                      ),
                    ),
                    SizedBox(height: spacing.xs),
                    Wrap(
                      spacing: spacing.xs,
                      runSpacing: spacing.xxs,
                      children: _image!.tags.map((tag) => Container(
                        padding: EdgeInsets.symmetric(horizontal: spacing.xs, vertical: 3),
                        decoration: BoxDecoration(
                          color: colors.surfaceSecondary,
                          borderRadius: TFRadius.borderRadiusSm,
                          border: Border.all(color: colors.borderSubtle),
                        ),
                        child: Text(
                          tag.startsWith('#') ? tag : '#$tag',
                          style: typography.caption.copyWith(color: colors.textSecondary),
                        ),
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.all(spacing.md),
            decoration: BoxDecoration(
              color: colors.surfaceSecondary.withValues(alpha: 0.3),
              border: Border(top: BorderSide(color: colors.borderSubtle)),
            ),
            child: SizedBox(
              width: double.infinity,
              child: TFButton(
                label: 'Baixar Imagem HD',
                leadingIcon: TFIcons.download,
                onPressed: _displayImageUrl != null ? _downloadImage : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHierarchyRow(BuildContext context, IconData icon, String label, String value) {
    final colors = context.tfColors;
    final spacing = context.tfSpacing;
    final typography = context.tfTypography;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.xxs),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colors.primary),
          SizedBox(width: spacing.xs),
          Text(
            '$label: ',
            style: typography.bodySmall.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: typography.bodySmall.copyWith(color: colors.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(BuildContext context, IconData icon, String label, String value) {
    final colors = context.tfColors;
    final spacing = context.tfSpacing;
    final typography = context.tfTypography;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.xxs),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colors.textSecondary),
          SizedBox(width: spacing.xs),
          Text(
            '$label ',
            style: typography.caption.copyWith(color: colors.textSecondary),
          ),
          Expanded(
            child: Text(
              value,
              style: typography.caption.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadImage() async {
    if (_displayImageUrl == null) return;
    try {
      final uri = Uri.parse(_displayImageUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao abrir imagem: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
