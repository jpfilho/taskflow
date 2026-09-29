import 'package:flutter/material.dart';
import 'dart:async';
import '../../../../design_system/components/buttons/tf_button.dart';
import '../../../../design_system/components/buttons/tf_icon_button.dart';
import '../../../../design_system/components/dialogs/tf_modal_dialog.dart';
import '../../../../design_system/components/feedback/tf_empty_state.dart';
import '../../../../design_system/components/feedback/tf_loading.dart';
import '../../../../design_system/components/layout/tf_page_header.dart';
import '../../../../design_system/foundations/tf_icons.dart';
import '../../../../design_system/theme/taskflow_theme_extension.dart';
import '../../../../services/auth_service_simples.dart';
import '../../../../services/connectivity_service.dart';
import '../../../../widgets/sync_status_widget.dart';
import '../../application/controllers/gallery_controller.dart';
import '../../data/models/media_image.dart';
import '../widgets/filter_bar.dart';
import '../widgets/album_group_list.dart';
import '../widgets/media_grid.dart';
import 'detail_page.dart';
import 'status_album_list_view.dart';
import 'upload_page.dart';

class MediaAlbumsGalleryPage extends StatefulWidget {
  final String? initialLocalId;
  final String? initialRoomId;

  const MediaAlbumsGalleryPage({
    super.key,
    this.initialLocalId,
    this.initialRoomId,
  });

  @override
  State<MediaAlbumsGalleryPage> createState() => _MediaAlbumsGalleryPageState();
}

class _MediaAlbumsGalleryPageState extends State<MediaAlbumsGalleryPage> {
  late final GalleryController _controller;
  final ScrollController _scrollController = ScrollController();
  late final TextEditingController _searchController;
  final ConnectivityService _connectivity = ConnectivityService();
  StreamSubscription<bool>? _connSub;
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();
    _controller = GalleryController();
    _searchController = TextEditingController(text: _controller.searchQuery);
    _controller.addListener(_onControllerChanged);
    _isConnected = _connectivity.isConnected;
    _connSub = _connectivity.connectionStream.listen((connected) {
      if (mounted) {
        setState(() {
          _isConnected = connected;
        });
      }
    });

    final hasInitialFilters = widget.initialLocalId != null || widget.initialRoomId != null;
    if (hasInitialFilters) {
      _controller.loadReferences().then((_) async {
        if (!mounted) return;
        if (widget.initialLocalId != null) await _controller.setLocalId(widget.initialLocalId);
        if (widget.initialRoomId != null) _controller.setRoomId(widget.initialRoomId);
      });
    } else {
      _controller.loadReferences();
      _controller.loadImages(refresh: true);
    }

    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (_controller.searchQuery.isEmpty && _searchController.text.isNotEmpty) {
      _searchController.text = '';
      _searchController.selection = const TextSelection.collapsed(offset: 0);
    }
    setState(() {});
  }

  String _userProfileSubtitle() {
    final usuario = AuthServiceSimples().currentUser;
    if (usuario == null) return 'Organização e arquivo visual das operações.';
    final r = usuario.regionais.isEmpty ? '—' : usuario.regionais.join(', ');
    final d = usuario.divisoes.isEmpty ? '—' : usuario.divisoes.join(', ');
    final s = usuario.segmentos.isEmpty ? '—' : usuario.segmentos.join(', ');
    return 'Regional: $r • Divisão: $d • Segmento: $s';
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent * 0.85) {
      _controller.loadMore();
    }
  }

  void _navigateToDetail(MediaImage image) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DetailPage(imageId: image.id),
      ),
    ).then((_) {
      _controller.loadImages(refresh: true);
    });
  }

  void _navigateToUpload() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const UploadPage(),
      ),
    ).then((_) {
      _controller.loadImages(refresh: true);
    });
  }

  void _navigateToStatusList() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const StatusAlbumListView(),
      ),
    ).then((_) {
      _controller.loadReferences();
    });
  }

  Future<void> _handleDelete(MediaImage image) async {
    final confirmed = await TFModalDialog.confirm(
      context: context,
      title: 'Excluir Imagem',
      message: 'Tem certeza que deseja excluir permanentemente esta imagem do álbum?',
      confirmLabel: 'Excluir',
      isDestructive: true,
    );

    if (confirmed == true) {
      await _controller.deleteImage(image.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final spacing = context.tfSpacing;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            TFPageHeader(
              title: 'Álbuns de Mídia & Evidências',
              subtitle: _userProfileSubtitle(),
              primaryAction: TFButton(
                label: 'Adicionar Fotos',
                leadingIcon: TFIcons.add,
                onPressed: _navigateToUpload,
              ),
              secondaryActions: [
                TFButton(
                  label: 'Status',
                  variant: TFButtonVariant.secondary,
                  leadingIcon: Icons.tune_rounded,
                  onPressed: _navigateToStatusList,
                ),
                TFIconButton(
                  icon: TFIcons.refresh,
                  tooltip: 'Atualizar Galeria',
                  onPressed: () => _controller.loadImages(refresh: true),
                ),
                const SyncStatusWidget(),
              ],
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.xs),
              child: FilterBar(
                searchQuery: _controller.searchQuery,
                searchController: _searchController,
                onSearchChanged: _controller.setSearchQuery,
                segments: _controller.segments,
                locais: _controller.locais,
                rooms: _controller.rooms,
                selectedSegmentId: _controller.selectedSegmentId,
                selectedLocalId: _controller.selectedLocalId,
                selectedRoomId: _controller.selectedRoomId,
                selectedStatus: _controller.selectedStatus,
                selectedStatusAlbumId: _controller.selectedStatusAlbumId,
                statusAlbums: _controller.statusAlbums,
                onSegmentChanged: _controller.setSegmentId,
                onLocalChanged: _controller.setLocalId,
                onRoomChanged: _controller.setRoomId,
                onStatusChanged: _controller.setStatus,
                onStatusAlbumIdChanged: _controller.setStatusAlbumId,
                onClearFilters: _controller.clearFilters,
                onRefresh: () => _controller.loadImages(refresh: true),
                viewModeIndex: _controller.viewModeIndex,
                onViewModeChanged: _controller.setViewMode,
                currentResults: _controller.images.length,
                totalResults: _controller.totalImages,
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: spacing.md),
                child: _buildContent(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_controller.error != null) {
      return Center(
        child: TFEmptyState(
          title: 'Erro ao carregar galeria',
          description: _controller.error!,
          icon: TFIcons.warning,
          action: TFButton(
            label: 'Tentar Novamente',
            leadingIcon: TFIcons.refresh,
            onPressed: () => _controller.loadImages(refresh: true),
          ),
        ),
      );
    }

    if (_controller.isLoading && _controller.images.isEmpty) {
      return const Center(child: TFLoading(message: 'Carregando álbuns e imagens...'));
    }

    if (_controller.viewModeIndex == 0) {
      // 0 = Grid Geral
      return MediaGrid(
        images: _controller.images,
        onImageTap: _navigateToDetail,
        onImageDelete: _handleDelete,
        scrollController: _scrollController,
        onLoadMore: _controller.hasMore ? () => _controller.loadMore() : null,
        onAddNew: _navigateToUpload,
        hasMore: _controller.hasMore,
        isLoading: _controller.isLoading,
      );
    }

    // 1 = Por Álbuns / Salas
    return AlbumGroupList(
      groupedImages: _controller.getGroupedImagesByLocal(),
      onImageTap: _navigateToDetail,
      onImageDelete: _handleDelete,
      scrollController: _scrollController,
      onLoadMore: _controller.hasMore ? () => _controller.loadMore() : null,
      onLoadRoomImages: _controller.loadImagesForRoom,
      hasMore: _controller.hasMore,
      isLoading: _controller.isLoading,
      isLoadingRoom: _controller.isLoadingRoom,
    );
  }
}
