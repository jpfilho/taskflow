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
import '../../util/user_locais_helper.dart';

class GalleryController extends ChangeNotifier {
  final SupabaseMediaRepository _repository = SupabaseMediaRepository();
  final StatusAlbumRepository _statusRepository = StatusAlbumRepository();

  // Estado da galeria
  List<MediaImage> _images = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 0;
  final int _pageSize = 20;
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
  List<Room> _rooms = [];
  List<StatusAlbum> _statusAlbums = [];
  bool _loadingReferences = false;

  List<MediaImage> get images => _images;
  bool get isLoading => _isLoading;
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
  /// Locais do usuário; quando há segmento selecionado, apenas locais desse segmento.
  List<Local> get locais {
    if (_selectedSegmentId == null) return _locais;
    final seg = _segments.where((s) => s.id == _selectedSegmentId).toList();
    final segmentoId = seg.isNotEmpty && seg.first.segmentoId != null
        ? seg.first.segmentoId!
        : _selectedSegmentId;
    return _locais.where((l) => l.segmentoId == segmentoId).toList();
  }
  List<Room> get rooms => _rooms;
  List<StatusAlbum> get statusAlbums => _statusAlbums;
  bool get loadingReferences => _loadingReferences;

  /// Carrega dados de referência (segments, locais, rooms)
  Future<void> loadReferences() async {
    if (_loadingReferences) return;

    _loadingReferences = true;
    notifyListeners();

    try {
      // Obter segmentos do perfil do usuário
      // Importar AuthServiceSimples para obter o usuário atual
      try {
        final authService = AuthServiceSimples();
        final usuario = authService.currentUser;
        final userSegmentoIds = usuario?.segmentoIds;
        
        // Se usuário é root ou não tem perfil, mostrar todos os segmentos
        // Caso contrário, filtrar pelos segmentos do perfil
        _segments = await _repository.getSegments(
          userSegmentoIds: (usuario?.isRoot ?? false) || (userSegmentoIds?.isEmpty ?? true)
              ? null
              : userSegmentoIds,
        );
      } catch (e) {
        // Fallback: carregar todos os segmentos
        _segments = await _repository.getSegments();
      }
      
      // Locais do usuário (regional, divisão, segmento) — opções da coluna locais.local
      try {
        final authService = AuthServiceSimples();
        final usuario = authService.currentUser;
        _locais = await getLocaisForUsuario(usuario);
      } catch (e) {
        _locais = [];
      }

      // Se há segmento selecionado e o local atual não pertence a ele, limpar local e salas
      if (_selectedSegmentId != null && _selectedLocalId != null) {
        final seg = _segments.where((s) => s.id == _selectedSegmentId).toList();
        final segmentoId = seg.isNotEmpty && seg.first.segmentoId != null ? seg.first.segmentoId! : _selectedSegmentId;
        final pertenceAoSegmento = _locais.any((l) => l.id == _selectedLocalId && l.segmentoId == segmentoId);
        if (!pertenceAoSegmento) {
          _selectedLocalId = null;
          _selectedRoomId = null;
          _rooms = [];
        }
      }
      // Salas dos equipamentos associados ao local escolhido (equipamentos_sap.local_instalacao = locais.local_instalacao_sap)
      if (_selectedLocalId != null) {
        final selectedLocal = _locais.where((l) => l.id == _selectedLocalId).toList();
        if (selectedLocal.isNotEmpty && selectedLocal.first.localInstalacaoSap != null) {
          try {
            _rooms = await _repository.getRooms(
              localInstalacao: selectedLocal.first.localInstalacaoSap,
              userLocalNames: null,
            );
          } catch (e) {
            _rooms = [];
          }
        } else {
          _rooms = [];
        }
      } else {
        _rooms = [];
      }
      // Manter selectedRoomId só se ainda estiver na lista (evita assertion no dropdown)
      if (_selectedRoomId != null && !_rooms.any((r) => r.id == _selectedRoomId)) {
        _selectedRoomId = null;
      }

      // Carregar status de álbuns da tabela
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

  /// Carrega imagens (primeira página)
  Future<void> loadImages({bool refresh = false}) async {
    if (_isLoading && !refresh) return;

    if (refresh) {
      _currentPage = 0;
      _images = [];
      _hasMore = true;
    }

    _isLoading = true;
    _error = null;
    final searchAtRequest = _searchQuery;
    notifyListeners();

    try {
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
        equipmentIds: equipmentIds,
        roomId: _selectedRoomId,
        status: _selectedStatus,
        statusAlbumId: _selectedStatusAlbumId,
        userRegionalIds: userRegionalIds,
        userDivisaoIds: userDivisaoIds,
        userSegmentoIds: userSegmentoIds,
      );

      // Ignorar resposta se o usuário já digitou outra busca (evita texto “reordenar” e resultados errados)
      if (searchAtRequest != _searchQuery) return;

      if (refresh) {
        _images = result['images'] as List<MediaImage>;
      } else {
        _images = [..._images, ...(result['images'] as List<MediaImage>)];
      }

      final total = result['total'] as int;
      _totalImages = total;
      _hasMore = _images.length < total;
      _currentPage++;
    } catch (e) {
      _error = 'Erro ao carregar imagens: $e';
    } finally {
      _isLoading = false;
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
      _selectedLocalId = null;
      _selectedRoomId = null;
      _rooms = [];
      notifyListeners();
      loadImages(refresh: true);
    }
  }

  /// Atualiza o local selecionado; carrega salas dos equipamentos associados ao local.
  Future<void> setLocalId(String? localId) async {
    if (_selectedLocalId != localId) {
      _selectedLocalId = localId;
      _selectedRoomId = null;
      _rooms = [];
      if (localId != null) {
        final selectedLocal = locais.where((l) => l.id == localId).toList();
        if (selectedLocal.isNotEmpty && selectedLocal.first.localInstalacaoSap != null && selectedLocal.first.localInstalacaoSap!.trim().isNotEmpty) {
          try {
            _rooms = await _repository.getRooms(
              localInstalacao: selectedLocal.first.localInstalacaoSap,
              userLocalNames: null,
            );
          } catch (e) {
            _rooms = [];
          }
          if (_selectedRoomId != null && !_rooms.any((r) => r.id == _selectedRoomId)) {
            _selectedRoomId = null;
          }
        }
        notifyListeners();
      }
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
    notifyListeners();
  }

  /// Define modo de visualização: 0 = grid, 1 = lista hierárquica, 2 = álbuns por local
  void setViewMode(int index) {
    final newIndex = index.clamp(0, 2);
    if (_viewModeIndex != newIndex) {
      _viewModeIndex = newIndex;
      notifyListeners();
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
    _rooms = [];
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

  /// Agrupa imagens por local (álbum = um local); ideal para muitos cadastros.
  Map<String, List<MediaImage>> getGroupedImagesByLocal() {
    final grouped = <String, List<MediaImage>>{};

    for (final image in _images) {
      final key = (image.localName != null && image.localName!.trim().isNotEmpty)
          ? image.localName!
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
