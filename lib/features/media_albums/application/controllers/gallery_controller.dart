import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/repositories/supabase_media_repository.dart';
import '../../data/repositories/status_album_repository.dart';
import '../../data/models/media_image.dart';
import '../../data/models/segment.dart';
import '../../data/models/room.dart';
import '../../data/models/status_album.dart';
import '../../../../models/local.dart';
import '../../../../services/auth_service_simples.dart';
import '../../../../services/connectivity_service.dart';

class GalleryController extends ChangeNotifier {
  final SupabaseMediaRepository _repository = SupabaseMediaRepository();
  final StatusAlbumRepository _statusRepository = StatusAlbumRepository();
  final ConnectivityService _connectivity = ConnectivityService();

  // Estado da galeria
  List<MediaImage> _images = [];
  bool _isLoading = false;
  bool _isLoadingRoom = false; // Separado para não bloquear a galeria toda no lazy load
  bool _hasMore = true;
  int _currentPage = 0;
  final int _pageSize = 50;
  int? _totalImages;
  String? _error;

  // Filtros
  String _searchQuery = '';
  Timer? _searchDebounce;

  String? _selectedSegmentId;
  String? _selectedLocalId;
  String? _selectedRoomId;
  MediaImageStatus? _selectedStatus;
  String? _selectedStatusAlbumId;
  /// 0 = grid, 1 = lista hierárquica, 2 = álbuns por local
  int _viewModeIndex = 0;

  List<Segment> _segments = [];
  List<Local> _locais = [];
  List<Room> _allAvailableRooms = [];
  Map<String, List<Room>> _roomsByLocal = {};
  List<StatusAlbum> _statusAlbums = [];
  List<Map<String, String?>> _availableFolders = [];
  bool _loadingReferences = false;

  List<MediaImage> get images => _images;
  bool get isLoading => _isLoading;
  bool get isLoadingRoom => _isLoadingRoom;
  bool get hasMore => _hasMore;
  int? get totalImages => _totalImages;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  String? get selectedSegmentId => _selectedSegmentId;
  String? get selectedLocalId => _selectedLocalId;
  String? get selectedRoomId => _selectedRoomId;
  MediaImageStatus? get selectedStatus => _selectedStatus;
  String? get selectedStatusAlbumId => _selectedStatusAlbumId;
  bool get groupByHierarchy => _viewModeIndex == 1;
  bool get groupByAlbumsByLocal => _viewModeIndex == 2;
  int get viewModeIndex => _viewModeIndex;
  List<Segment> get segments => _segments;

  /// Locais que possuem imagens cadastradas para o usuário.
  /// Quando há segmento selecionado, apenas locais desse segmento.
  List<Local> get locais {
    if (_selectedSegmentId == null) return _locais;
    final seg = _segments.where((s) => s.id == _selectedSegmentId).toList();
    final segmentoId = seg.isNotEmpty && seg.first.segmentoId != null
        ? seg.first.segmentoId!
        : _selectedSegmentId;
    return _locais.where((l) => l.segmentoId == segmentoId || l.segmentoId == _selectedSegmentId).toList();
  }

  /// Salas que possuem imagens cadastradas para o local selecionado (ou todas se nenhum local selecionado).
  List<Room> get rooms {
    if (_selectedLocalId != null) {
      return _roomsByLocal[_selectedLocalId] ?? [];
    }
    return _allAvailableRooms;
  }

  List<StatusAlbum> get statusAlbums => _statusAlbums;
  bool get loadingReferences => _loadingReferences;

  /// Carrega dados de referência (segments, locais, rooms) que DE FATO possuem fotos
  /// cadastradas em media_images, respeitando as restrições de perfil (Regional, Divisão, Segmentos).
  Future<void> loadReferences() async {
    if (_loadingReferences) return;

    _loadingReferences = true;
    notifyListeners();

    try {
      final authService = AuthServiceSimples();
      final usuario = authService.currentUser;
      final userRegionalIds = (usuario?.isRoot ?? false) || (usuario?.regionalIds.isEmpty ?? true) ? null : usuario?.regionalIds;
      final userDivisaoIds = (usuario?.isRoot ?? false) || (usuario?.divisaoIds.isEmpty ?? true) ? null : usuario?.divisaoIds;
      final userSegmentoIds = (usuario?.isRoot ?? false) || (usuario?.segmentoIds.isEmpty ?? true) ? null : usuario?.segmentoIds;

      final filterData = await _repository.getAvailableFilterOptions(
        userRegionalIds: userRegionalIds,
        userDivisaoIds: userDivisaoIds,
        userSegmentoIds: userSegmentoIds,
      );

      _segments = filterData['segments'] as List<Segment>;
      _locais = filterData['locais'] as List<Local>;
      _roomsByLocal = filterData['roomsByLocal'] as Map<String, List<Room>>;
      _allAvailableRooms = filterData['rooms'] as List<Room>;

      // Se há segmento selecionado que não existe mais nas fotos disponíveis, limpa
      if (_selectedSegmentId != null && !_segments.any((s) => s.id == _selectedSegmentId)) {
        _selectedSegmentId = null;
        _selectedLocalId = null;
        _selectedRoomId = null;
      }

      // Se há local selecionado que não existe mais nos locais do segmento/perfil, limpa
      if (_selectedLocalId != null && !locais.any((l) => l.id == _selectedLocalId)) {
        _selectedLocalId = null;
        _selectedRoomId = null;
      }

      // Se há sala selecionada que não existe mais nas salas disponíveis, limpa
      if (_selectedRoomId != null && !rooms.any((r) => r.id == _selectedRoomId)) {
        _selectedRoomId = null;
      }

      // Status de álbuns da tabela
      try {
        _statusAlbums = await _statusRepository.getStatusAlbumsAtivos();
        debugPrint('✅ Status de álbuns carregados: ${_statusAlbums.length}');
      } catch (e) {
        debugPrint('⚠️ Erro ao carregar status de álbuns: $e');
        _statusAlbums = [];
      }
    } catch (e) {
      _error = 'Erro ao carregar referências: $e';
    } finally {
      _loadingReferences = false;
      notifyListeners();
    }
  }

  /// Carrega a estrutura de pastas e as imagens paginadas quando no modo Grid Geral.
  /// No modo Álbuns (1), as imagens são carregadas sob demanda via [loadImagesForRoom].
  Future<void> loadImages({bool refresh = false}) async {
    if (_isLoading && !refresh) return;

    if (refresh) {
      _currentPage = 0;
      _images.clear();
      _hasMore = true;
    }

    _isLoading = true;
    _error = null;
    final searchAtRequest = _searchQuery;
    notifyListeners();

    try {
      // Offline: não buscar remoto
      if (!_connectivity.isConnected) {
        _error = _images.isEmpty
            ? 'Offline: conecte-se para carregar álbuns'
            : 'Offline: exibindo álbuns já carregados';
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Carrega sempre a estrutura de pastas com contagens reais do servidor
      await _loadAvailableFolders();

      final totalFromFolders = _availableFolders
          .where((f) {
            final localName = f['local_name']?.toString().trim() ?? '';
            return localName.isNotEmpty;
          })
          .fold<int>(0, (sum, f) => sum + (int.tryParse(f['count'] ?? '0') ?? 0));

      if (_viewModeIndex == 0) {
        // Modo 0 (Grid Geral): Carrega as fotos paginadas diretamente do Supabase
        final authService = AuthServiceSimples();
        final usuario = authService.currentUser;
        final userRegionalIds = (usuario?.isRoot ?? false) || (usuario?.regionalIds.isEmpty ?? true) ? null : usuario?.regionalIds;
        final userDivisaoIds = (usuario?.isRoot ?? false) || (usuario?.divisaoIds.isEmpty ?? true) ? null : usuario?.divisaoIds;
        final userSegmentoIds = (usuario?.isRoot ?? false) || (usuario?.segmentoIds.isEmpty ?? true) ? null : usuario?.segmentoIds;

        List<String>? equipmentIds;
        if (_selectedLocalId != null) {
          final selectedLocalList = locais.where((l) => l.id == _selectedLocalId).toList();
          if (selectedLocalList.isNotEmpty) {
            final selectedLocal = selectedLocalList.first;
            if (selectedLocal.localInstalacaoSap != null && selectedLocal.localInstalacaoSap!.trim().isNotEmpty) {
              equipmentIds = await _repository.getEquipmentIdsForLocalInstalacaoSap(selectedLocal.localInstalacaoSap!);
            }
          }
        }

        final result = await _repository.getMediaImages(
          page: _currentPage,
          pageSize: _pageSize,
          searchQuery: searchAtRequest.isEmpty ? null : searchAtRequest,
          segmentId: _selectedSegmentId,
          localId: _selectedLocalId,
          equipmentIds: equipmentIds,
          roomId: _selectedRoomId,
          status: _selectedStatus,
          statusAlbumId: _selectedStatusAlbumId,
          userRegionalIds: userRegionalIds,
          userDivisaoIds: userDivisaoIds,
          userSegmentoIds: userSegmentoIds,
        );

        // Se a busca mudou no meio do caminho, descarta
        if (searchAtRequest != _searchQuery) return;

        final newImages = result['images'] as List<MediaImage>;
        if (refresh) {
          _images = newImages;
        } else {
          for (final img in newImages) {
            if (!_images.any((existing) => existing.id == img.id)) {
              _images.add(img);
            }
          }
        }

        final total = result['total'] as int;
        _totalImages = total;
        _hasMore = _images.length < total;
        _currentPage++;
      } else {
        // Modo 1 ou 2 (Por Álbuns): Usa a contagem das pastas
        _totalImages = totalFromFolders;
        _hasMore = false;
      }
    } catch (e) {
      _error = 'Erro ao carregar álbuns: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Lazy loader para buscar as imagens atreladas a uma sala específica ao abrir a sanfona
  Future<void> loadImagesForRoom(String dummyId) async {
    debugPrint('🚀 [LazyLoad] Chamado com dummyId: "$dummyId"');
    
    String? localId;
    String? roomId;
    final parts = dummyId.split('|');
    debugPrint('🔍 [LazyLoad] parts: $parts (total: ${parts.length})');
    
    if (parts.length >= 6 && parts[1] == 'room') {
       localId = parts[4];
       roomId = parts[5];
       debugPrint('📁 [LazyLoad] Tipo ROOM → localId=$localId, roomId=$roomId');
    } else if (parts.length >= 4 && parts[1] == 'root') {
       localId = parts[3];
       roomId = null; 
       debugPrint('📁 [LazyLoad] Tipo ROOT → localId=$localId');
    } else {
       debugPrint('❌ [LazyLoad] Formato inválido, partes insuficientes: ${parts.length}');
    }

    if (localId == null || localId.isEmpty) {
      debugPrint('❌ [LazyLoad] localId nulo ou vazio — abortando!');
      return;
    }

    _isLoadingRoom = true;
    notifyListeners();

    try {
      final authService = AuthServiceSimples();
      final usuario = authService.currentUser;
      final userRegionalIds = (usuario?.isRoot ?? false) || (usuario?.regionalIds.isEmpty ?? true) ? null : usuario?.regionalIds;
      final userDivisaoIds = (usuario?.isRoot ?? false) || (usuario?.divisaoIds.isEmpty ?? true) ? null : usuario?.divisaoIds;
      final userSegmentoIds = (usuario?.isRoot ?? false) || (usuario?.segmentoIds.isEmpty ?? true) ? null : usuario?.segmentoIds;

      debugPrint('📡 [LazyLoad] Buscando getMediaImages(localId=$localId, roomId=$roomId)');
      final result = await _repository.getMediaImages(
        page: 0,
        pageSize: 100,
        localId: localId,
        roomId: (roomId != null && roomId.isNotEmpty) ? roomId : null,
        userRegionalIds: userRegionalIds,
        userDivisaoIds: userDivisaoIds,
        userSegmentoIds: userSegmentoIds,
      );

      final newImages = result['images'] as List<MediaImage>;
      debugPrint('✅ [LazyLoad] Recebidas ${newImages.length} imagens do servidor');
      if (newImages.isNotEmpty) {
        final sample = newImages.first;
        debugPrint('🔎 [LazyLoad] Sample image: id=${sample.id} localName="${sample.localName}" roomName="${sample.roomName}"');
      }
      
      int added = 0;
      for (final newImg in newImages) {
        if (!_images.any((existing) => existing.id == newImg.id)) {
           _images.add(newImg);
           added++;
        }
      }
      debugPrint('✅ [LazyLoad] $added imagens novas adicionadas. Total _images=${_images.length}');
      
      // Debug: verificar como ficam as chaves após getGroupedImagesByLocal
      final grouped = getGroupedImagesByLocal();
      debugPrint('🗂️ [LazyLoad] Após grouped: chaves=${grouped.keys.toList()}');
      for (final entry in grouped.entries) {
        final realImgs = entry.value.where((img) => !img.id.startsWith('dummy')).length;
        if (realImgs > 0) {
          debugPrint('   📂 ${entry.key}: $realImgs imagens reais');
        }
      }

    } catch (e, stack) {
      debugPrint('⚠️ [LazyLoad] ERRO: $e');
      debugPrint('   Stack: $stack');
    } finally {
      _isLoadingRoom = false;
      notifyListeners();
    }
  }

  /// Carrega mais imagens (página seguinte)
  Future<void> loadMore() async {
    if (!_hasMore || _isLoading) return;
    await loadImages();
  }

  /// Atualiza a busca (com debounce para não reordenar texto e não disparar muitas requisições)
  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _searchDebounce = null;
      loadImages(refresh: true);
    });
    notifyListeners();
  }

  /// Atualiza o segmento selecionado
  Future<void> setSegmentId(String? segmentId) async {
    if (_selectedSegmentId != segmentId) {
      _selectedSegmentId = segmentId;
      if (_selectedLocalId != null && !locais.any((l) => l.id == _selectedLocalId)) {
        _selectedLocalId = null;
        _selectedRoomId = null;
      }
      notifyListeners();
      loadImages(refresh: true);
    }
  }

  /// Atualiza o local selecionado
  Future<void> setLocalId(String? localId) async {
    if (_selectedLocalId != localId) {
      _selectedLocalId = localId;
      if (_selectedRoomId != null && !rooms.any((r) => r.id == _selectedRoomId)) {
        _selectedRoomId = null;
      }
      notifyListeners();
      loadImages(refresh: true);
    }
  }

  /// Atualiza a sala selecionada
  void setRoomId(String? roomId) {
    if (_selectedRoomId != roomId) {
      _selectedRoomId = roomId;
      loadImages(refresh: true);
    }
  }

  /// Atualiza o status selecionado (compatibilidade)
  void setStatus(MediaImageStatus? status) {
    if (_selectedStatus != status) {
      _selectedStatus = status;
      _selectedStatusAlbumId = null; // Limpar status_album_id quando usar enum
      loadImages(refresh: true);
    }
  }

  /// Atualiza o status selecionado por ID (novo)
  void setStatusAlbumId(String? statusAlbumId) {
    if (_selectedStatusAlbumId != statusAlbumId) {
      _selectedStatusAlbumId = statusAlbumId;
      _selectedStatus = null; // Limpar enum quando usar status_album_id
      loadImages(refresh: true);
    }
  }

  /// Alterna agrupamento por hierarquia (compatibilidade)
  void toggleGroupByHierarchy() {
    _viewModeIndex = _viewModeIndex == 1 ? 0 : 1;
    if (_viewModeIndex == 0) {
      loadImages(refresh: true);
    } else {
      notifyListeners();
    }
  }

  /// Define modo de visualização: 0 = grid, 1 = lista hierárquica, 2 = álbuns por local
  void setViewMode(int index) {
    final newIndex = index.clamp(0, 2);
    if (_viewModeIndex != newIndex) {
      _viewModeIndex = newIndex;
      if (_viewModeIndex == 0) {
        loadImages(refresh: true);
      } else {
        notifyListeners();
      }
    }
  }

  /// Deleta uma imagem
  Future<bool> deleteImage(String imageId) async {
    try {
      // Buscar a imagem para obter o filePath
      final image = _images.firstWhere((img) => img.id == imageId);
      
      // Deletar do storage
      try {
        await _repository.deleteFile(image.filePath);
        if (image.thumbPath != null) {
          await _repository.deleteFile(image.thumbPath!);
        }
      } catch (e) {
        // Continuar mesmo se falhar deletar do storage
        debugPrint('Aviso: Erro ao deletar arquivo do storage: $e');
      }

      // Deletar do banco
      await _repository.deleteMediaImage(imageId);

      // Remover da lista local
      _images.removeWhere((img) => img.id == imageId);
      notifyListeners();

      return true;
    } catch (e) {
      _error = 'Erro ao deletar imagem: $e';
      notifyListeners();
      return false;
    }
  }

  /// Atualiza uma imagem
  Future<bool> updateImage(MediaImage image) async {
    try {
      final updated = await _repository.updateMediaImage(image);
      
      // Atualizar na lista local
      final index = _images.indexWhere((img) => img.id == image.id);
      if (index >= 0) {
        _images[index] = updated;
        notifyListeners();
      }

      return true;
    } catch (e) {
      _error = 'Erro ao atualizar imagem: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> _loadAvailableFolders() async {
     try {
       final authService = AuthServiceSimples();
       final usuario = authService.currentUser;
       // Coletar segmentIds baseados nos filtros ativos
       List<String>? segmentFilter;
       if (_selectedSegmentId != null) {
          segmentFilter = [_selectedSegmentId!];
       } else {
          segmentFilter = (usuario?.isRoot ?? false) || (usuario?.segmentoIds.isEmpty ?? true) ? null : usuario?.segmentoIds;
       }
       
       final regionalFilter = (usuario?.isRoot ?? false) || (usuario?.regionalIds.isEmpty ?? true) ? null : usuario?.regionalIds;
       final divisaoFilter = (usuario?.isRoot ?? false) || (usuario?.divisaoIds.isEmpty ?? true) ? null : usuario?.divisaoIds;
       
       _availableFolders = await _repository.getAvailableAlbumFolders(
          userSegmentoIds: segmentFilter,
          userRegionalIds: regionalFilter,
          userDivisaoIds: divisaoFilter,
       );
     } catch (e) {
       debugPrint('Erro silent ao carregar pastas disponíveis: $e');
     }
  }

  /// Limpa todos os filtros
  void clearFilters() {
    _searchDebounce?.cancel();
    _searchDebounce = null;
    _searchQuery = '';
    _selectedSegmentId = null;
    _selectedLocalId = null;
    _selectedRoomId = null;
    _selectedStatus = null;
    _selectedStatusAlbumId = null;
    loadImages(refresh: true);
  }

  /// Agrupa imagens por hierarquia (Regional > Divisão > Segmento > Local > Sala)
  Map<String, List<MediaImage>> getGroupedImages() {
    final grouped = <String, List<MediaImage>>{};

    for (final image in _images) {
      final key = image.hierarchyPath.isEmpty 
          ? 'Sem classificação' 
          : image.hierarchyPath;
      
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(image);
    }

    return grouped;
  }

  /// Agrupa imagens por local (álbum = um local).
  Map<String, List<MediaImage>> getGroupedImagesByLocal() {
    final grouped = <String, List<MediaImage>>{};

    // 1) Primeiramente popular o array local com as pastas e subpastas estruturais garantidas do Repository
    
    // 1â) Pré-calcular: quais locais têm pelo menos um room_id (sala real, mesmo que nome seja nulo)
    // Isso evita criar dummy root 'Sem sala' quando o local JÁ tem salas reais associadas
    final locaisComRoomId = <String>{};
    for (final folder in _availableFolders) {
      final lId = folder['local_id']?.trim() ?? '';
      final rId = folder['room_id']?.trim() ?? '';
      if (lId.isNotEmpty && rId.isNotEmpty) {
        locaisComRoomId.add(lId);
      }
    }
    
    for (final folder in _availableFolders) {
      final local = folder['local_name']?.trim();
        final room = folder['room_name']?.trim();
        final countStr = folder['count']?.toString() ?? '0';
        
        // Tratar locais vazios ou nulos da mesma forma que os objetos MediaImage
        final robustLocal = (local != null && local.isNotEmpty) ? local : 'Sem local';
        final robustRoom = (room != null && room.isNotEmpty) ? room : 'Sem sala';

        if (!grouped.containsKey(robustLocal)) {
           grouped[robustLocal] = [];
        }
        
        // Pasta Raízes do Local (sem vínculo com salas)
        if (room == null || room.isEmpty) {
           final localId = folder['local_id']?.trim() ?? '';
           final hasRoomId = (folder['room_id']?.trim() ?? '').isNotEmpty;
           
           // Se tem room_id mas sem nome: é uma sala não resolvida — ela já aparece via dummy|room
           // Não criar root dummy para não duplicar com a entrada de sala
           if (hasRoomId) continue;
           
           // Não criar root dummy se o local já tem salas reais (evita Sem sala fantasma)
           if (locaisComRoomId.contains(localId)) continue;
           
           final alreadyHasRootDummy = grouped[robustLocal]!.any((img) => img.id.startsWith('dummy_root_') || img.id.startsWith('dummy|root|'));
           if (!alreadyHasRootDummy && countStr != '0') {
              grouped[robustLocal]!.add(
                 MediaImage(
                    id: 'dummy|root|$countStr|$localId',
                    filePath: '',
                    createdBy: '',
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                    title: 'Placeholder',
                    tags: [],
                    roomName: null, 
                 )
              );
           }
        } else {
           // Pastas correspondentes às Salas
           final alreadyHasRoom = grouped[robustLocal]!.any((img) => (img.roomName?.trim() ?? 'Sem sala') == robustRoom);
           if (!alreadyHasRoom) {
              final localId = folder['local_id'] ?? '';
              final roomId = folder['room_id'] ?? '';
              grouped[robustLocal]!.add(
                 MediaImage(
                    id: 'dummy|room|$countStr|$robustRoom|$localId|$roomId',
                    filePath: '',
                    createdBy: '',
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                    title: 'Placeholder',
                    tags: [],
                    roomName: room,
                 )
              );
           }
        }
    }

    // 2) Popular imagens (já carregadas da paginacao respectiva do momento) nessas chaves
    for (final image in _images) {
      final localName = image.localName?.trim();
      final key = (localName != null && localName.isNotEmpty)
          ? localName
          : 'Sem local';
      
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(image);
    }

    // Ordenar grupos por nome do local
    final sorted = <String, List<MediaImage>>{};
    final keys = grouped.keys.toList()..sort((a, b) => a.compareTo(b));
    for (final k in keys) {
      sorted[k] = grouped[k]!;
    }
    return sorted;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchDebounce = null;
    super.dispose();
  }
}
