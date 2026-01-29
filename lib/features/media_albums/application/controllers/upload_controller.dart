import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/repositories/supabase_media_repository.dart';
import '../../data/repositories/status_album_repository.dart';
import '../../data/models/media_image.dart';
import '../../data/models/status_album.dart';
import '../../util/path_builder.dart';
import '../../../../config/supabase_config.dart';
import '../../../../services/auth_service_simples.dart';

class UploadProgress {
  final String fileName;
  final double progress; // 0.0 a 1.0
  final bool isComplete;
  final String? error;

  UploadProgress({
    required this.fileName,
    required this.progress,
    this.isComplete = false,
    this.error,
  });
}

class UploadController extends ChangeNotifier {
  final SupabaseMediaRepository _repository = SupabaseMediaRepository();
  final StatusAlbumRepository _statusRepository = StatusAlbumRepository();
  final ImagePicker _imagePicker = ImagePicker();

  List<XFile> _selectedFiles = [];
  List<UploadProgress> _uploadProgress = [];
  bool _isUploading = false;
  String? _error;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Estado do formulário (hierarquia: regional → divisão → segmento → local)
  String? _selectedRegionalId;
  String? _selectedDivisaoId;
  String? _selectedSegmentId;
  String? _selectedLocalId;
  String? _selectedEquipmentId; // Resolvido a partir do local (para path/DB)
  String? _selectedRoomId;
  String _title = '';
  String _description = '';
  List<String> _tags = [];
  MediaImageStatus _status = MediaImageStatus.review; // Mantido para compatibilidade
  String? _statusAlbumId; // Novo: ID do status da tabela
  List<StatusAlbum> _statusAlbums = []; // Lista de status disponíveis
  bool _loadingStatusAlbums = false;

  // Getters
  List<XFile> get selectedFiles => _selectedFiles;
  List<UploadProgress> get uploadProgress => _uploadProgress;
  bool get isUploading => _isUploading;
  String? get error => _error;
  String? get selectedRegionalId => _selectedRegionalId;
  String? get selectedDivisaoId => _selectedDivisaoId;
  String? get selectedSegmentId => _selectedSegmentId;
  String? get selectedLocalId => _selectedLocalId;
  String? get selectedEquipmentId => _selectedEquipmentId;
  String? get selectedRoomId => _selectedRoomId;
  String get title => _title;
  String get description => _description;
  List<String> get tags => _tags;
  MediaImageStatus get status => _status; // Mantido para compatibilidade
  String? get statusAlbumId => _statusAlbumId; // Novo
  List<StatusAlbum> get statusAlbums => _statusAlbums; // Novo
  bool get loadingStatusAlbums => _loadingStatusAlbums; // Novo

  /// Seleciona imagens da galeria ou câmera
  Future<void> pickImages({bool fromCamera = false}) async {
    try {
      final List<XFile> images = [];
      
      if (fromCamera) {
        final image = await _imagePicker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
        );
        if (image != null) {
          images.add(image);
        }
      } else {
        // No web, pickMultiImage pode não funcionar, usar pickImage em loop
        try {
          final pickedImages = await _imagePicker.pickMultiImage(imageQuality: 85);
          images.addAll(pickedImages);
        } catch (e) {
          // Fallback: tentar selecionar uma imagem por vez
          final image = await _imagePicker.pickImage(
            source: ImageSource.gallery,
            imageQuality: 85,
          );
          if (image != null) {
            images.add(image);
          }
        }
      }

      if (images.isNotEmpty) {
        _selectedFiles = [..._selectedFiles, ...images];
        _uploadProgress = List.generate(
          _selectedFiles.length,
          (index) => UploadProgress(
            fileName: _selectedFiles[index].name,
            progress: 0.0,
          ),
        );
        _error = null;
        notifyListeners();
      }
    } catch (e) {
      _error = 'Erro ao selecionar imagens: $e';
      debugPrint('Erro ao selecionar imagens: $e');
      notifyListeners();
      rethrow; // Re-throw para que a UI possa mostrar o erro
    }
  }

  /// Remove uma imagem da seleção
  void removeFile(int index) {
    if (index >= 0 && index < _selectedFiles.length) {
      _selectedFiles.removeAt(index);
      _uploadProgress.removeAt(index);
      notifyListeners();
    }
  }

  /// Limpa todas as imagens selecionadas
  void clearFiles() {
    _selectedFiles.clear();
    _uploadProgress.clear();
    notifyListeners();
  }

  /// Atualiza o segmento selecionado
  void setRegionalId(String? regionalId) {
    if (_selectedRegionalId != regionalId) {
      _selectedRegionalId = regionalId;
      _selectedDivisaoId = null;
      _selectedSegmentId = null;
      _selectedLocalId = null;
      _selectedEquipmentId = null;
      _selectedRoomId = null;
      notifyListeners();
    }
  }

  void setDivisaoId(String? divisaoId) {
    if (_selectedDivisaoId != divisaoId) {
      _selectedDivisaoId = divisaoId;
      _selectedSegmentId = null;
      _selectedLocalId = null;
      _selectedEquipmentId = null;
      _selectedRoomId = null;
      notifyListeners();
    }
  }

  void setSegmentId(String? segmentId) {
    final previousSegmentId = _selectedSegmentId;
    _selectedSegmentId = segmentId;
    if (previousSegmentId != segmentId) {
      _selectedLocalId = null;
      _selectedEquipmentId = null;
      _selectedRoomId = null;
    }
    notifyListeners();
  }

  /// Atualiza o local selecionado (tabela locais, coluna local)
  void setLocalId(String? localId) {
    final previousLocalId = _selectedLocalId;
    _selectedLocalId = localId;
    if (previousLocalId != localId) {
      _selectedEquipmentId = null;
      _selectedRoomId = null;
    }
    notifyListeners();
  }

  /// Define o equipment_id resolvido a partir do local (usado ao salvar)
  void setEquipmentId(String? equipmentId) {
    _selectedEquipmentId = equipmentId;
    notifyListeners();
  }

  /// Atualiza a sala selecionada
  void setRoomId(String? roomId) {
    _selectedRoomId = roomId;
    notifyListeners();
  }

  /// Atualiza o título
  void setTitle(String title) {
    _title = title;
    notifyListeners();
  }

  /// Atualiza a descrição
  void setDescription(String description) {
    _description = description;
    notifyListeners();
  }

  /// Adiciona uma tag
  void addTag(String tag) {
    final trimmed = tag.trim();
    if (trimmed.isNotEmpty && !_tags.contains(trimmed)) {
      _tags.add(trimmed);
      notifyListeners();
    }
  }

  /// Remove uma tag
  void removeTag(String tag) {
    _tags.remove(tag);
    notifyListeners();
  }

  /// Atualiza o status
  void setStatus(MediaImageStatus status) {
    _status = status;
    _statusAlbumId = null; // Limpar statusAlbumId quando usar enum
    notifyListeners();
  }

  void setStatusAlbumId(String? statusAlbumId) {
    _statusAlbumId = statusAlbumId;
    // Determinar status enum baseado no statusAlbumId (opcional, para compatibilidade)
    if (statusAlbumId != null) {
      final statusAlbum = _statusAlbums.firstWhere(
        (s) => s.id == statusAlbumId,
        orElse: () => _statusAlbums.isNotEmpty ? _statusAlbums.first : StatusAlbum(id: '', nome: 'Revisão'),
      );
      // Mapear nome do status para enum (fallback)
      if (statusAlbum.nome.toLowerCase().contains('ok')) {
        _status = MediaImageStatus.ok;
      } else if (statusAlbum.nome.toLowerCase().contains('atenção') || statusAlbum.nome.toLowerCase().contains('atencao')) {
        _status = MediaImageStatus.attention;
      } else {
        _status = MediaImageStatus.review;
      }
    }
    notifyListeners();
  }

  /// Carrega os status de álbuns da tabela
  Future<void> loadStatusAlbums() async {
    if (_loadingStatusAlbums) return;
    
    _loadingStatusAlbums = true;
    notifyListeners();
    
    try {
      _statusAlbums = await _statusRepository.getStatusAlbumsAtivos();
      // Se não há statusAlbumId selecionado, usar o primeiro status ativo como padrão
      if (_statusAlbumId == null && _statusAlbums.isNotEmpty) {
        _statusAlbumId = _statusAlbums.first.id;
        setStatusAlbumId(_statusAlbumId);
      }
    } catch (e) {
      debugPrint('Erro ao carregar status de álbuns: $e');
    } finally {
      _loadingStatusAlbums = false;
      notifyListeners();
    }
  }

  /// Faz upload de todas as imagens selecionadas
  Future<bool> uploadAll() async {
    debugPrint('🚀 uploadAll: Iniciando upload...');
    debugPrint('   Arquivos selecionados: ${_selectedFiles.length}');
    debugPrint('   Título: $_title');
    debugPrint('   Segmento: $_selectedSegmentId');
    debugPrint('   Equipamento: $_selectedEquipmentId');
    debugPrint('   Sala: $_selectedRoomId');
    
    if (_selectedFiles.isEmpty) {
      debugPrint('❌ Nenhuma imagem selecionada');
      _error = 'Nenhuma imagem selecionada';
      notifyListeners();
      return false;
    }

    if (_title.trim().isEmpty) {
      debugPrint('❌ Título obrigatório não preenchido');
      _error = 'O título é obrigatório';
      notifyListeners();
      return false;
    }

    _isUploading = true;
    _error = null;
    notifyListeners();

    try {
      // Obter userId do Supabase
      debugPrint('🔍 Obtendo userId...');
      String? userId = SupabaseConfig.client.auth.currentUser?.id;
      debugPrint('   userId do Supabase: $userId');
      
      if (userId == null) {
        // Fallback: tentar obter do AuthServiceSimples
        debugPrint('   Tentando obter userId do AuthServiceSimples...');
        try {
          final authService = AuthServiceSimples();
          final usuario = authService.currentUser;
          if (usuario != null) {
            userId = usuario.id;
            debugPrint('   userId do AuthServiceSimples: $userId');
          } else {
            debugPrint('   ⚠️ Usuário não encontrado no AuthServiceSimples');
          }
        } catch (e, stackTrace) {
          debugPrint('   ❌ Erro ao obter userId do AuthServiceSimples: $e');
          debugPrint('   Stack trace: $stackTrace');
        }
      }
      
      if (userId == null) {
        debugPrint('❌ Usuário não autenticado');
        throw Exception('Usuário não autenticado');
      }

      debugPrint('✅ userId obtido: $userId');
      final createdImages = <MediaImage>[];

      for (int i = 0; i < _selectedFiles.length; i++) {
        try {
          final file = _selectedFiles[i];
          debugPrint('');
          debugPrint('📤 Upload [$i/${_selectedFiles.length}]: ${file.name}');
          debugPrint('   Caminho: ${file.path}');
          
          // Atualizar progresso
          _uploadProgress[i] = UploadProgress(
            fileName: file.name,
            progress: 0.1,
          );
          notifyListeners();
          debugPrint('   ✅ Progresso: 10% - Iniciado');

          // Ler bytes do arquivo
          debugPrint('   📖 Lendo bytes do arquivo...');
          final bytes = await file.readAsBytes();
          debugPrint('   ✅ Bytes lidos: ${bytes.length} bytes');
          
          _uploadProgress[i] = UploadProgress(
            fileName: file.name,
            progress: 0.3,
          );
          notifyListeners();
          debugPrint('   ✅ Progresso: 30% - Arquivo lido');

          // Determinar extensão
          // No web, file.path pode ser um blob URL, então usar file.name primeiro
          String extension = '';
          
          // Tentar extrair do nome do arquivo primeiro
          if (file.name.isNotEmpty) {
            final parts = file.name.split('.');
            if (parts.length > 1) {
              extension = parts.last.toLowerCase();
              debugPrint('   📎 Extensão extraída do nome: $extension');
            }
          }
          
          // Se não encontrou no nome, tentar do path
          if (extension.isEmpty && file.path.isNotEmpty) {
            // Ignorar blob URLs
            if (!file.path.startsWith('blob:')) {
              final parts = file.path.split('.');
              if (parts.length > 1) {
                extension = parts.last.toLowerCase();
                debugPrint('   📎 Extensão extraída do path: $extension');
              }
            }
          }
          
          // Se ainda não encontrou, tentar inferir do mime type ou usar jpeg como padrão
          if (extension.isEmpty) {
            // Tentar inferir do nome ou usar padrão
            final nameLower = file.name.toLowerCase();
            if (nameLower.contains('jpeg') || nameLower.contains('jpg')) {
              extension = 'jpeg';
            } else if (nameLower.contains('png')) {
              extension = 'png';
            } else if (nameLower.contains('webp')) {
              extension = 'webp';
            } else {
              // Padrão para blob URLs ou arquivos sem extensão clara
              extension = 'jpeg';
              debugPrint('   ⚠️ Extensão não detectada, usando padrão: $extension');
            }
          }
          
          debugPrint('   📎 Extensão final: $extension');
          if (!['jpg', 'jpeg', 'png', 'webp'].contains(extension)) {
            throw Exception('Formato não suportado: $extension');
          }

          // Construir caminho
          debugPrint('   🗂️ Construindo caminho...');
          final path = PathBuilder.buildImagePath(
            userId: userId,
            segmentId: _selectedSegmentId,
            equipmentId: _selectedEquipmentId,
            roomId: _selectedRoomId,
            extension: extension,
          );
          debugPrint('   ✅ Caminho construído: $path');

          _uploadProgress[i] = UploadProgress(
            fileName: file.name,
            progress: 0.5,
          );
          notifyListeners();
          debugPrint('   ✅ Progresso: 50% - Caminho pronto');

          // Fazer upload e obter signed URL (válida por 1 ano)
          debugPrint('   ☁️ Fazendo upload para Supabase Storage...');
          debugPrint('      Bucket: taskflow-media');
          debugPrint('      Path: $path');
          debugPrint('      Content-Type: image/$extension');
          debugPrint('      Tamanho: ${bytes.length} bytes');
          
          final fileUrl = await _repository.uploadFile(
            path: path,
            fileBytes: bytes,
            contentType: 'image/$extension',
          );
          debugPrint('   ✅ Upload concluído! URL: $fileUrl');

          _uploadProgress[i] = UploadProgress(
            fileName: file.name,
            progress: 0.8,
          );
          notifyListeners();
          debugPrint('   ✅ Progresso: 80% - Arquivo enviado');

          // Criar registro no banco
          debugPrint('   💾 Criando registro no banco de dados...');
          final image = MediaImage(
            id: '', // Será gerado pelo banco
            regionalId: _selectedRegionalId,
            divisaoId: _selectedDivisaoId,
            segmentId: _selectedSegmentId,
            localId: _selectedLocalId,
            equipmentId: _selectedEquipmentId,
            roomId: _selectedRoomId,
            title: _title,
            description: _description.trim().isEmpty ? null : _description,
            tags: _tags,
            status: _status,
            statusAlbumId: _statusAlbumId,
            filePath: path,
            fileUrl: fileUrl,
            createdBy: userId,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          debugPrint('   📝 Dados da imagem:');
          debugPrint('      Título: ${image.title}');
          debugPrint('      Segmento: ${image.segmentId}');
          debugPrint('      Equipamento: ${image.equipmentId}');
          debugPrint('      Sala: ${image.roomId}');
          debugPrint('      Tags: ${image.tags}');
          debugPrint('      Status: ${image.status}');

          final created = await _repository.createMediaImage(image);
          debugPrint('   ✅ Registro criado no banco! ID: ${created.id}');
          createdImages.add(created);

          _uploadProgress[i] = UploadProgress(
            fileName: file.name,
            progress: 1.0,
            isComplete: true,
          );
          notifyListeners();
          debugPrint('   ✅ Progresso: 100% - Concluído!');
        } catch (e, stackTrace) {
          debugPrint('   ❌ ERRO no upload [$i]: $e');
          debugPrint('   Stack trace: $stackTrace');
          _uploadProgress[i] = UploadProgress(
            fileName: _selectedFiles[i].name,
            progress: 0.0,
            error: e.toString(),
          );
          notifyListeners();
        }
      }

      _isUploading = false;
      
      // Verificar se houve erros
      final hasErrors = _uploadProgress.any((p) => p.error != null);
      final errors = _uploadProgress.where((p) => p.error != null).map((p) => '${p.fileName}: ${p.error}').toList();
      
      if (hasErrors) {
        debugPrint('');
        debugPrint('❌ Upload concluído com erros:');
        for (var error in errors) {
          debugPrint('   - $error');
        }
        _error = 'Alguns uploads falharam. Verifique os detalhes.';
      } else {
        debugPrint('');
        debugPrint('✅ Upload concluído com sucesso! ${createdImages.length} imagens enviadas.');
        // Limpar formulário após sucesso
        _resetForm();
      }
      
      notifyListeners();
      return !hasErrors;
    } catch (e, stackTrace) {
      debugPrint('');
      debugPrint('❌ ERRO GERAL no uploadAll: $e');
      debugPrint('Stack trace: $stackTrace');
      _isUploading = false;
      _error = 'Erro ao fazer upload: $e';
      notifyListeners();
      return false;
    }
  }

  /// Reseta o formulário
  void _resetForm() {
    _selectedFiles.clear();
    _uploadProgress.clear();
    _selectedRegionalId = null;
    _selectedDivisaoId = null;
    _selectedSegmentId = null;
    _selectedLocalId = null;
    _selectedEquipmentId = null;
    _selectedRoomId = null;
    _title = '';
    _description = '';
    _tags = [];
    _status = MediaImageStatus.review;
    if (_statusAlbums.isNotEmpty) {
      _statusAlbumId = _statusAlbums.first.id;
    } else {
      _statusAlbumId = null;
    }
  }

  /// Reseta tudo (incluindo estado de upload)
  void reset() {
    _resetForm();
    _isUploading = false;
    _error = null;
    notifyListeners();
  }
}
