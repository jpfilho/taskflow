import 'package:flutter/material.dart';
import 'dart:async';
import '../../../../services/auth_service_simples.dart';
import '../../../../services/connectivity_service.dart';
import '../../../../widgets/sync_status_widget.dart';
import '../../application/controllers/gallery_controller.dart';
import '../../data/models/media_image.dart';
import '../widgets/filter_bar.dart';
import '../widgets/media_grid.dart';
import '../widgets/album_group_list.dart';
import 'detail_page.dart';
import 'upload_page.dart';

class MediaAlbumsGalleryPage extends StatefulWidget {
  /// Filtros iniciais (ex.: ao abrir a partir da tela de Ordens por local/sala).
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

    // Carregar referências; se houver filtros iniciais, aplicar após carregar e abrir filtrado
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

    // Scroll listener para infinite scroll
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
    // Sincronizar campo de busca quando filtros são limpos (ex.: botão Limpar)
    if (_controller.searchQuery.isEmpty && _searchController.text.isNotEmpty) {
      _searchController.text = '';
      _searchController.selection = TextSelection.collapsed(offset: 0);
    }
    setState(() {});
  }

  /// Texto com perfil do usuário: Regional X - Divisao Y - Segmento Z.
  String _userProfileSubtitle() {
    final usuario = AuthServiceSimples().currentUser;
    if (usuario == null) return ' - Regional — - Divisao — - Segmento —';
    final r = usuario.regionais.isEmpty ? '—' : usuario.regionais.join(', ');
    final d = usuario.divisoes.isEmpty ? '—' : usuario.divisoes.join(', ');
    final s = usuario.segmentos.isEmpty ? '—' : usuario.segmentos.join(', ');
    return ' - Regional $r - Divisao $d - Segmento $s';
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
      // Recarregar após voltar (pode ter sido editada/deletada)
      _controller.loadImages(refresh: true);
    });
  }

  void _navigateToUpload() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const UploadPage(),
      ),
    ).then((_) {
      // Recarregar após upload
      _controller.loadImages(refresh: true);
    });
  }

  static double _responsivePadding(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < 600) return 12;
    if (w < 1024) return 20;
    return 32;
  }

  static double _responsiveSpacing(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < 600) return 16;
    if (w < 1024) return 20;
    return 32;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;
    final isTablet = width >= 600 && width < 1024;
    final padding = _responsivePadding(context);
    final spacing = _responsiveSpacing(context);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0f172a) : const Color(0xFFf8fafc),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_isConnected)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_off, color: Colors.orange[800], size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Offline: exibindo dados já carregados. Conecte-se para sincronizar novos álbuns.',
                          style: TextStyle(color: Colors.orange[900], fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SyncStatusWidget(),
                    ],
                  ),
                ),
              // Header (mobile sem título para economizar espaço; desktop/tablet com título)
              isMobile
                  ? Row(
                      children: [
                        Expanded(
                          child: _buildSearchField(context, theme, isDark),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _navigateToUpload,
                          icon: const Icon(Icons.add, size: 20),
                          label: const Text('Adicionar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1e40af),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Álbuns de Imagens${_userProfileSubtitle()}',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF0f172a),
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            SizedBox(
                              width: isTablet ? 240 : 320,
                              child: _buildSearchField(context, theme, isDark),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: _navigateToUpload,
                              icon: const Icon(Icons.add, size: 20),
                              label: const Text('Adicionar'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1e40af),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
              SizedBox(height: spacing),
              // Barra de filtros (mesmo controller da busca para não reordenar texto)
              FilterBar(
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
              SizedBox(height: padding),
              // Conteúdo
              Expanded(
                child: _controller.error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _controller.error!,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => _controller.loadImages(refresh: true),
                          child: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
                  )
                : _controller.isLoading && _controller.images.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : _controller.viewModeIndex == 1 || _controller.viewModeIndex == 2
                        ? AlbumGroupList(
                            groupedImages: _controller.viewModeIndex == 2
                                ? _controller.getGroupedImagesByLocal()
                                : _controller.getGroupedImages(),
                            onImageTap: _navigateToDetail,
                            scrollController: _scrollController,
                            onLoadMore: _controller.hasMore
                                ? () => _controller.loadMore()
                                : null,
                            hasMore: _controller.hasMore,
                            isLoading: _controller.isLoading,
                            onImageDelete: (image) async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Confirmar exclusão'),
                                  content: const Text(
                                    'Tem certeza que deseja excluir esta imagem?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Cancelar'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      style: TextButton.styleFrom(
                                        foregroundColor: theme.colorScheme.error,
                                      ),
                                      child: const Text('Excluir'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirmed == true) {
                                await _controller.deleteImage(image.id);
                              }
                            },
                          )
                        : MediaGrid(
                            images: _controller.images,
                            onImageTap: _navigateToDetail,
                            scrollController: _scrollController,
                            onLoadMore: _controller.hasMore
                                ? () => _controller.loadMore()
                                : null,
                            isLoading: _controller.isLoading,
                            hasMore: _controller.hasMore,
                            onImageDelete: (image) async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Confirmar exclusão'),
                                  content: const Text(
                                    'Tem certeza que deseja excluir esta imagem?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Cancelar'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      style: TextButton.styleFrom(
                                        foregroundColor: theme.colorScheme.error,
                                      ),
                                      child: const Text('Excluir'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirmed == true) {
                                await _controller.deleteImage(image.id);
                              }
                            },
                            onAddNew: _navigateToUpload,
                          ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: null,
    );
  }

  Widget _buildSearchField(BuildContext context, ThemeData theme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1e293b) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0),
        ),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Buscar por título, descrição ou tags...',
          hintStyle: TextStyle(
            color: isDark ? Colors.grey[500] : Colors.grey[400],
          ),
          prefixIcon: Icon(
            Icons.search,
            color: isDark ? Colors.grey[400] : Colors.grey[500],
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF0f172a),
        ),
        onChanged: _controller.setSearchQuery,
      ),
    );
  }
}
