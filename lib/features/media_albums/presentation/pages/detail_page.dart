import 'dart:ui' as ui show ImageByteFormat;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
  /// Exibir por padrão a imagem com anotações quando existir.
  bool _showAnnotated = true;
  /// URL usada no canvas de anotação (pública ou assinada, para não depender de fileUrl expirada).
  String? _annotationImageUrl;
  bool _isSavingAnnotations = false;
  AnnotationController? _annotationController;
  final GlobalKey _annotationRepaintKey = GlobalKey();

  /// URL da imagem atualmente exibida: com anotações ou original conforme _showAnnotated.
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
    // Obter URL válida para o canvas (fileUrl do banco pode estar expirada)
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
            content: Text('Anotações salvas. PNG exportado.'),
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
          title: const Text('Texto'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Digite o texto',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
    if (text != null && text.trim().isNotEmpty) {
      _annotationController!.addTextAt(position, text);
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
        _loadImage(); // Recarregar
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Imagem atualizada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteImage() async {
    if (_image == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: const Text(
          'Tem certeza que deseja excluir esta imagem? Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Deletar do storage
        await _repository.deleteFile(_image!.filePath);
        if (_image!.thumbPath != null) {
          await _repository.deleteFile(_image!.thumbPath!);
        }

        // Deletar do banco
        await _repository.deleteMediaImage(_image!.id);

        if (mounted) {
          Navigator.of(context).pop(true); // Retornar true indica que foi deletada
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao deletar: $e'),
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
        // Baixar bytes e compartilhar como arquivo para apps que não pré-visualizam links
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
        } catch (_) {
          // fallback abaixo
        }
        // Fallback: compartilhar link se não conseguir baixar
        await Share.share(_displayImageUrl!);
      } else {
        // Web: abrir URL
        final uri = Uri.parse(_displayImageUrl!);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao compartilhar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0f172a) : const Color(0xFFf8fafc),
        body: Center(child: CircularProgressIndicator(color: const Color(0xFF1e40af))),
      );
    }

    if (_error != null || _image == null) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0f172a) : const Color(0xFFf8fafc),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                _error ?? 'Imagem não encontrada',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadImage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1e40af),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    if (_annotationMode && _annotationController != null && (_annotationImageUrl != null || _image?.fileUrl != null)) {
      return _buildAnnotationView(context, theme, isDark, isMobile);
    }

    if (_isFullscreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: _buildFullscreenViewer(theme, isDark),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0f172a) : const Color(0xFFf8fafc),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, theme, isDark, isMobile),
            Expanded(
              child: isMobile
                  ? _buildMobileLayout(context, theme, isDark)
                  : _buildDesktopLayout(context, theme, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnotationView(BuildContext context, ThemeData theme, bool isDark, bool isMobile) {
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0f172a) : const Color(0xFFf8fafc),
      appBar: AppBar(
        title: const Text('Editar / Anotar'),
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
          // Altura fixa para a barra de edição evita que o quadro da imagem mude de tamanho
          // ao selecionar (e exibir "Editar seleção" / "Editar texto"), eliminando o deslocamento.
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

  Widget _buildHeader(BuildContext context, ThemeData theme, bool isDark, bool isMobile) {
    final shortTitle = _image!.title.length > 40
        ? '${_image!.title.substring(0, 40)}...'
        : _image!.title;
    final headerPadding = MediaQuery.of(context).size.width < 600 ? 12.0 : (MediaQuery.of(context).size.width < 1024 ? 16.0 : 24.0);
    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: headerPadding),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1e293b) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.arrow_back_rounded,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            style: IconButton.styleFrom(
              backgroundColor: Colors.transparent,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Detalhes da Imagem: $shortTitle',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1e293b),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_image!.annotatedFileUrl != null) ...[
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Com anotações'), icon: Icon(Icons.draw_rounded, size: 18)),
                ButtonSegment(value: false, label: Text('Sem anotações'), icon: Icon(Icons.image_rounded, size: 18)),
              ],
              selected: {_showAnnotated},
              onSelectionChanged: (Set<bool> selected) {
                setState(() => _showAnnotated = selected.first);
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
              ),
            ),
            const SizedBox(width: 12),
          ],
          _headerAction(context, Icons.share_rounded, 'Compartilhar', _shareImage, isDark, isMobile),
          _headerAction(context, Icons.draw_rounded, 'Editar / Anotar', _openAnnotationMode, isDark, isMobile),
          _headerAction(context, Icons.edit_rounded, 'Editar', _editImage, isDark, isMobile),
          Container(
            width: 1,
            height: 24,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: isDark ? const Color(0xFF475569) : const Color(0xFFe2e8f0),
          ),
          InkWell(
            onTap: _deleteImage,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delete_rounded, size: 20, color: theme.colorScheme.error),
                  if (!isMobile) ...[
                    const SizedBox(width: 8),
                    Text(
                      'Excluir',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerAction(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
    bool isDark,
    bool isMobile,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            if (!isMobile) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.35,
          child: _buildImageViewer(theme, isDark),
        ),
        Expanded(
          child: _buildMetadataPanel(context, theme, isDark),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(BuildContext context, ThemeData theme, bool isDark) {
    final width = MediaQuery.of(context).size.width;
    // Tablet: painel mais estreito; desktop: 384px
    final panelWidth = width < 1024
        ? (width * 0.42).clamp(280.0, 400.0)
        : 384.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _buildImageViewer(theme, isDark),
        ),
        SizedBox(
          width: panelWidth,
          child: _buildMetadataPanel(context, theme, isDark),
        ),
      ],
    );
  }

  Widget _buildImageViewer(ThemeData theme, bool isDark) {
    if (_displayImageUrl == null) {
      return Container(
        height: MediaQuery.of(context).size.height - 64,
        color: isDark ? const Color(0xFF020617) : const Color(0xFFe2e8f0),
        child: Center(
          child: Icon(
            Icons.broken_image_rounded,
            size: 64,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
          ),
        ),
      );
    }

    return _isFullscreen
        ? _buildFullscreenViewer(theme, isDark)
        : _buildNormalViewer(theme, isDark);
  }

  Widget _buildNormalViewer(ThemeData theme, bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF020617) : const Color(0xFFe2e8f0),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
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
                bottom: 24,
                right: 24,
                child: Material(
                  color: Colors.transparent,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _zoomButton(
                        context,
                        Icons.zoom_in_rounded,
                        isDark,
                        _zoomIn,
                      ),
                      const SizedBox(width: 8),
                      _zoomButton(
                        context,
                        Icons.zoom_out_rounded,
                        isDark,
                        _zoomOut,
                      ),
                      const SizedBox(width: 8),
                      _zoomButton(
                        context,
                        Icons.fullscreen_rounded,
                        isDark,
                        _enterFullscreen,
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

  Widget _buildFullscreenViewer(ThemeData theme, bool isDark) {
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
          child: Container(
            color: Colors.black,
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
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: _exitFullscreen,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _zoomButton(
                      context,
                      Icons.zoom_in_rounded,
                      true,
                      () => _zoomIn(),
                    ),
                    const SizedBox(width: 8),
                    _zoomButton(
                      context,
                      Icons.zoom_out_rounded,
                      true,
                      () => _zoomOut(),
                    ),
                    const SizedBox(width: 8),
                    _zoomButton(
                      context,
                      Icons.fullscreen_exit_rounded,
                      true,
                      () => _exitFullscreen(),
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

  Widget _zoomButton(
    BuildContext context,
    IconData icon,
    bool isDark,
    VoidCallback onTap,
  ) {
    return Material(
      color: isDark
          ? const Color(0xFF1e293b).withOpacity(0.9)
          : Colors.white.withOpacity(0.9),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () {
          onTap();
          setState(() {}); // Garante atualização visual após zoom
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Icon(
            icon,
            size: 20,
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataPanel(BuildContext context, ThemeData theme, bool isDark) {
    final dateFormat = DateFormat('dd/MM/yyyy \'às\' HH:mm', 'pt_BR');
    final width = MediaQuery.of(context).size.width;
    final panelPadding = width < 600 ? 12.0 : (width < 1024 ? 16.0 : 24.0);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1e293b) : Colors.white,
        border: Border(
          left: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(panelPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status + ID
                  Row(
                    children: [
                      StatusBadge(
                        status: _image!.status,
                        statusAlbum: _image!.statusAlbum,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'ID: #${_image!.id.length > 8 ? _image!.id.substring(0, 8) : _image!.id}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[500] : Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Título
                  Text(
                    _image!.title,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1e293b),
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Descrição (sempre visível)
                  Text(
                    'DESCRIÇÃO',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                      color: isDark ? Colors.grey[500] : Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _image!.description != null && _image!.description!.isNotEmpty
                        ? _image!.description!
                        : 'Sem descrição',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      height: 1.5,
                      fontStyle: _image!.description == null || _image!.description!.isEmpty
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Hierarquia
                  Text(
                    'HIERARQUIA',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                      color: isDark ? Colors.grey[500] : Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_image!.regionalName != null)
                    _buildHierarchyRow(
                      theme,
                      isDark,
                      Icons.public_rounded,
                      'Regional',
                      _image!.regionalName!,
                    ),
                  if (_image!.regionalName != null) const SizedBox(height: 16),
                  if (_image!.divisaoName != null)
                    _buildHierarchyRow(
                      theme,
                      isDark,
                      Icons.account_tree_rounded,
                      'Divisão',
                      _image!.divisaoName!,
                    ),
                  if (_image!.divisaoName != null) const SizedBox(height: 16),
                  if (_image!.segmentName != null)
                    _buildHierarchyRow(
                      theme,
                      isDark,
                      Icons.business_rounded,
                      'Segmento',
                      _image!.segmentName!,
                    ),
                  if (_image!.segmentName != null) const SizedBox(height: 16),
                  if (_image!.localName != null)
                    _buildHierarchyRow(
                      theme,
                      isDark,
                      Icons.place_rounded,
                      'Local',
                      _image!.localName!,
                    ),
                  if (_image!.localName != null) const SizedBox(height: 16),
                  if (_image!.roomName != null)
                    _buildHierarchyRow(
                      theme,
                      isDark,
                      Icons.meeting_room_rounded,
                      'Sala',
                      _image!.roomName!,
                    ),
                  if (_image!.roomName == null)
                    _buildHierarchyRow(
                      theme,
                      isDark,
                      Icons.meeting_room_rounded,
                      'Sala',
                      '—',
                    ),
                  const SizedBox(height: 16),
                  if (_image!.regionalName == null &&
                      _image!.divisaoName == null &&
                      _image!.segmentName == null &&
                      _image!.localName == null &&
                      _image!.roomName == null)
                    Text(
                      'Sem classificação',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[500] : Colors.grey[500],
                      ),
                    ),
                  const SizedBox(height: 24),
                  Divider(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0),
                  ),
                  const SizedBox(height: 24),
                  // Metadados
                  Text(
                    'METADADOS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                      color: isDark ? Colors.grey[500] : Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildMetaRow(
                    theme,
                    isDark,
                    Icons.calendar_today_rounded,
                    'Criado em:',
                    dateFormat.format(_image!.createdAt),
                  ),
                  const SizedBox(height: 12),
                  _buildMetaRow(
                    theme,
                    isDark,
                    Icons.update_rounded,
                    'Atualizado em:',
                    dateFormat.format(_image!.updatedAt),
                  ),
                  const SizedBox(height: 12),
                  _buildMetaRow(
                    theme,
                    isDark,
                    Icons.person_outline_rounded,
                    'Cadastrado por:',
                    _image!.creatorName ?? '—',
                  ),
                  if (_image!.annotatorName != null && _image!.annotatorName!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildMetaRow(
                      theme,
                      isDark,
                      Icons.draw_rounded,
                      'Anotado por:',
                      _image!.annotatorName!,
                    ),
                  ],
                  const SizedBox(height: 24),
                  // Tags
                  Text(
                    'TAGS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                      color: isDark ? Colors.grey[500] : Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_image!.tags.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _image!.tags.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFf1f5f9),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isDark ? const Color(0xFF475569) : const Color(0xFFe2e8f0),
                            ),
                          ),
                          child: Text(
                            tag.startsWith('#') ? tag : '#$tag',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey[300] : Colors.grey[700],
                            ),
                          ),
                        );
                      }).toList(),
                    )
                  else
                    Text(
                      'Nenhuma tag',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[500] : Colors.grey[500],
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Rodapé: Baixar Imagem HD
          Container(
            padding: EdgeInsets.all(panelPadding),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0f172a).withOpacity(0.5) : const Color(0xFFf8fafc),
              border: Border(
                top: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0),
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _displayImageUrl != null ? _downloadImage : null,
                  icon: const Icon(Icons.download_rounded, size: 20),
                  label: const Text('Baixar Imagem HD'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1e40af),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 4,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHierarchyRow(
    ThemeData theme,
    bool isDark,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1e3a8a).withOpacity(0.2)
                : const Color(0xFFdbeafe),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF1e40af)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey[500] : Colors.grey[500],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1e293b),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetaRow(
    ThemeData theme,
    bool isDark,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: isDark ? Colors.grey[500] : Colors.grey[400],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              children: [
                TextSpan(text: '$label '),
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : const Color(0xFF1e293b),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
