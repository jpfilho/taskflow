import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../application/controllers/upload_controller.dart';
import '../../application/controllers/gallery_controller.dart';
import '../../data/models/segment.dart';
import '../../data/models/room.dart';
import '../../data/models/equipment.dart';
import '../../data/models/status_album.dart';
import '../../data/repositories/supabase_media_repository.dart';
import '../../util/user_locais_helper.dart';
import '../../../../services/auth_service_simples.dart';
import '../../../../services/regional_service.dart';
import '../../../../services/divisao_service.dart';
import '../../../../models/regional.dart';
import '../../../../models/divisao.dart';
import '../../../../models/local.dart';
import 'package:dropdown_search/dropdown_search.dart';

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
    // Carregar status de álbuns
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

      debugPrint('🔍 Carregando regionais...');
      final allRegionais = await regionalService.getAllRegionais();
      _regionais = isRootOrNoProfile || (userRegionalIds?.isEmpty ?? true)
          ? allRegionais
          : allRegionais.where((r) => userRegionalIds!.contains(r.id)).toList();
      if (_regionais.length == 1) {
        _uploadController.setRegionalId(_regionais.first.id);
      }
      debugPrint('✅ Regionais carregadas: ${_regionais.length}');

      if (!mounted) return;

      debugPrint('🔍 Carregando divisões...');
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
      debugPrint('✅ Divisões carregadas: ${_divisoes.length}');

      if (!mounted) return;

      debugPrint('🔍 Carregando segmentos...');
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
      debugPrint('✅ Segmentos carregados: ${_segments.length}');

      if (!mounted) return;

      debugPrint('🔍 Carregando locais (regional, divisão, segmento do usuário)...');
      _locais = await getLocaisForUsuario(usuario);
      debugPrint('✅ Locais carregados: ${_locais.length}');
      for (var l in _locais.take(5)) {
        debugPrint('   - ${l.local} (id: ${l.id})');
      }
      if (_locais.length > 5) {
        debugPrint('   ... e mais ${_locais.length - 5}');
      }

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
    } catch (e, stackTrace) {
      debugPrint('❌ Erro ao carregar referências: $e');
      debugPrint('   Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar referências: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
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
    
    debugPrint('🔍 _handleLocalChanged: localId = $localId');
    
    _uploadController.setLocalId(localId);
    if (localId != null) {
      final selectedLocalList = _locais.where((l) => l.id == localId).toList();
      if (selectedLocalList.isNotEmpty) {
        final selectedLocal = selectedLocalList.first;
        debugPrint('   Local selecionado: ${selectedLocal.local}');
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
      debugPrint('   Local desmarcado, limpando salas');
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

    if (!mounted) return;

    _uploadController.setTitle(_titleController.text);
    _uploadController.setDescription(_descriptionController.text);

    try {
      final success = await _uploadController.uploadAll();

      if (!mounted) return;

      if (success) {
        // Mostrar toast de sucesso
        _showSuccessToast(context);
        // Aguardar um pouco antes de fechar
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) {
          Navigator.of(context).pop();
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
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  static double _responsivePadding(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < 600) return 16;
    if (w < 1024) return 24;
    return 32;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0f172a) : const Color(0xFFf8fafc),
      body: _uploadController.isUploading
          ? _buildUploadProgress()
          : Column(
              children: [
                // Header sticky
                _buildStickyHeader(context, isDark),
                // Conteúdo principal
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(_responsivePadding(context)),
                    child: Form(
                      key: _formKey,
                      child: isMobile
                          ? _buildMobileLayout(theme, isDark)
                          : _buildDesktopLayout(theme, isDark),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStickyHeader(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark 
            ? const Color(0xFF1e293b).withOpacity(0.8) 
            : Colors.white.withOpacity(0.8),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1280),
          margin: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width < 600 ? 12 : 16,
          ),
          height: 64,
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
              Text(
                'Adicionar Imagens Técnicas',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1e293b),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadProgress() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            'Enviando imagens...',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 32),
          ..._uploadController.uploadProgress.map((progress) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    LinearProgressIndicator(value: progress.progress),
                    const SizedBox(height: 4),
                    Text(
                      progress.fileName,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (progress.error != null)
                      Text(
                        progress.error!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                      ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildImagePicker(theme, isDark),
        const SizedBox(height: 24),
        _buildImagePreviews(theme, isDark),
        const SizedBox(height: 24),
        _buildFormFields(theme, isDark),
        const SizedBox(height: 24),
        _buildActionButtons(theme, isDark),
        const SizedBox(height: 24),
        _buildInfoCard(theme, isDark),
      ],
    );
  }

  Widget _buildDesktopLayout(ThemeData theme, bool isDark) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 1280),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Coluna esquerda (7/12)
          Expanded(
            flex: 7,
            child: Column(
              children: [
                _buildImagePicker(theme, isDark),
                const SizedBox(height: 24),
                _buildImagePreviews(theme, isDark),
              ],
            ),
          ),
          const SizedBox(width: 32),
          // Coluna direita (5/12)
          Expanded(
            flex: 5,
            child: Column(
              children: [
                _buildFormFields(theme, isDark),
                const SizedBox(height: 24),
                _buildActionButtons(theme, isDark),
                const SizedBox(height: 24),
                _buildInfoCard(theme, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePicker(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1e293b) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0),
            style: BorderStyle.solid,
            width: 2,
          ),
        ),
        child: InkWell(
          onTap: () async {
            try {
              await _uploadController.pickImages(fromCamera: false);
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erro ao selecionar imagens: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: isDark 
                        ? const Color(0xFF1e3a8a).withOpacity(0.2) 
                        : const Color(0xFFdbeafe),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.cloud_upload_rounded,
                    size: 32,
                    color: const Color(0xFF2563eb),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Upload de Imagens Técnicas',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1e293b),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Arraste e solte suas fotos aqui ou utilize os botões abaixo. Formatos suportados: JPG, PNG, WEBP.',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildPickerButton(
                      context,
                      Icons.photo_library_rounded,
                      'Galeria',
                      () async {
                        try {
                          await _uploadController.pickImages(fromCamera: false);
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Erro ao selecionar imagens: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      isDark,
                    ),
                    const SizedBox(width: 16),
                    _buildPickerButton(
                      context,
                      Icons.photo_camera_rounded,
                      'Câmera',
                      () async {
                        try {
                          await _uploadController.pickImages(fromCamera: true);
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Erro ao tirar foto: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      isDark,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPickerButton(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onPressed,
    bool isDark,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: const Color(0xFF2563eb)),
      label: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          color: Color(0xFF1e293b),
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isDark ? const Color(0xFF1e293b) : const Color(0xFFf1f5f9),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 0,
      ),
    );
  }

  Widget _buildImagePreviews(ThemeData theme, bool isDark) {
    if (_uploadController.selectedFiles.isEmpty) {
      return const SizedBox.shrink();
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1,
      ),
      itemCount: _uploadController.selectedFiles.length + 1, // +1 para o card de adicionar
      itemBuilder: (context, index) {
        if (index == _uploadController.selectedFiles.length) {
          // Card de adicionar mais
          return InkWell(
            onTap: () async {
              try {
                await _uploadController.pickImages(fromCamera: false);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erro ao selecionar imagens: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1e293b) : const Color(0xFFf1f5f9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? const Color(0xFF475569) : const Color(0xFFcbd5e1),
                  style: BorderStyle.solid,
                  width: 2,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.add_rounded,
                  color: isDark ? Colors.grey[400] : Colors.grey[500],
                  size: 32,
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
              borderRadius: BorderRadius.circular(8),
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
                          color: isDark ? const Color(0xFF1e293b) : const Color(0xFFf1f5f9),
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                    )
                  : Image.file(
                      File(file.path),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: isDark ? const Color(0xFF1e293b) : Colors.grey[200],
                          child: Icon(
                            Icons.broken_image,
                            color: isDark ? Colors.grey[600] : Colors.grey[400],
                          ),
                        );
                      },
                    ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                color: Colors.white,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  padding: const EdgeInsets.all(4),
                  minimumSize: const Size(28, 28),
                ),
                onPressed: () => _uploadController.removeFile(index),
              ),
            ),
            if (_uploadController.uploadProgress.isNotEmpty &&
                index < _uploadController.uploadProgress.length &&
                _uploadController.uploadProgress[index].progress > 0 &&
                _uploadController.uploadProgress[index].progress < 1)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.3),
                  child: Center(
                    child: CircularProgressIndicator(
                      value: _uploadController.uploadProgress[index].progress,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildFormFields(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1e293b) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
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
                _uploadController.selectedRegionalId,
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
                _uploadController.selectedDivisaoId,
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
                _uploadController.selectedSegmentId,
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
              // Sala e ação de nova sala na mesma linha; status na linha seguinte
              Row(
                children: [
                  Expanded(child: _buildSalaDropdownWithSearch(context, isDark)),
                  const SizedBox(width: 12),
                  if (_uploadController.selectedLocalId != null)
                    TextButton.icon(
                      onPressed: _handleAddRoom,
                      icon: const Icon(Icons.add),
                      label: const Text('Nova sala'),
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _buildStatusField(context, isDark),
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
      ),
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
    final selectedLocal = _uploadController.selectedLocalId != null
        ? _locais.where((l) => l.id == _uploadController.selectedLocalId).firstOrNull
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
    final enabled = _uploadController.selectedLocalId != null;
    final selectedRoom = _uploadController.selectedRoomId != null
        ? _rooms.where((r) => r.id == _uploadController.selectedRoomId).firstOrNull
        : null;

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
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
                  suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  suffixIcon: enabled
                      ? IconButton(
                          tooltip: 'Nova sala',
                          icon: const Icon(Icons.add, size: 20),
                          padding: const EdgeInsets.all(8),
                          onPressed: () async {
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
                            if (newName != null && newName.isNotEmpty) {
                              final trimmed = newName.trim();
                              if (_locais.isEmpty) return;
                              final selectedLocal = _locais.firstWhere(
                                (l) => l.id == _uploadController.selectedLocalId,
                                orElse: () => _locais.first,
                              );
                              final localInst = selectedLocal.localInstalacaoSap ?? selectedLocal.local ?? '';
                              final equipmentId = Equipment.generateDeterministicUuid('equipment:$localInst');
                              final roomId = Room.generateDeterministicUuid('room:$trimmed:$localInst');
                              final newRoom = Room(
                                id: roomId,
                                equipmentId: equipmentId,
                                name: trimmed,
                                localizacao: localInst,
                              );
                              setState(() {
                                _rooms = [..._rooms, newRoom];
                              });
                              _uploadController.setRoomId(newRoom.id);
                              try {
                                await _mediaRepository.createRoom(newRoom);
                              } catch (e) {
                                debugPrint('Erro ao criar sala: $e');
                              }
                            }
                          },
                        )
                      : null,
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
        ),
      ],
    );

    if (!enabled) {
      return IgnorePointer(
        child: Opacity(opacity: 0.6, child: content),
      );
    }
    return content;
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
    final selectedStatusAlbumId = _uploadController.statusAlbumId;
    final selectedStatus = selectedStatusAlbumId != null && _uploadController.statusAlbums.isNotEmpty
        ? _uploadController.statusAlbums.firstWhere(
            (s) => s.id == selectedStatusAlbumId,
            orElse: () => _uploadController.statusAlbums.isNotEmpty 
                ? _uploadController.statusAlbums.first 
                : StatusAlbum(id: '', nome: 'Revisão'),
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
                      : (isDark 
                          ? const Color(0xFF78350f).withOpacity(0.3) 
                          : const Color(0xFFfef3c7)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      selectedStatus != null
                          ? _getStatusIconFromName(selectedStatus.nome)
                          : Icons.feedback_rounded,
                      size: 14,
                      color: selectedStatus != null
                          ? selectedStatus.textColor
                          : (isDark ? const Color(0xFFfbbf24) : const Color(0xFF92400e)),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      selectedStatus != null
                          ? selectedStatus.nome
                          : _uploadController.status.displayName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: selectedStatus != null
                            ? selectedStatus.textColor
                            : (isDark ? const Color(0xFFfbbf24) : const Color(0xFF92400e)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _uploadController.statusAlbums.isEmpty
                    ? Center(
                        child: _uploadController.loadingStatusAlbums
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
                          value: selectedStatusAlbumId ?? (_uploadController.statusAlbums.isNotEmpty ? _uploadController.statusAlbums.first.id : null),
                          items: [
                            ..._uploadController.statusAlbums.map((s) => DropdownMenuItem<String>(
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
                              _uploadController.setStatusAlbumId(value);
                              setState(() {});
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
              ..._uploadController.tags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1e293b) : const Color(0xFFf1f5f9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tag,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[300] : const Color(0xFF1e293b),
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => _uploadController.removeTag(tag),
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

  Widget _buildActionButtons(ThemeData theme, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(
                color: isDark ? const Color(0xFF475569) : const Color(0xFFcbd5e1),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _handleUpload,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563eb),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
            child: const Text(
              'Salvar Imagens',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark 
            ? const Color(0xFF1e3a8a).withOpacity(0.1) 
            : const Color(0xFFdbeafe),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark 
              ? const Color(0xFF1e3a8a).withOpacity(0.2) 
              : const Color(0xFFbfdbfe),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_rounded,
            color: const Color(0xFF2563eb),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Certifique-se de que a iluminação está adequada antes de realizar o upload. As imagens serão processadas automaticamente para detecção de anomalias.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFF93c5fd) : const Color(0xFF1e40af),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessToast(BuildContext context) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 32,
        left: MediaQuery.of(context).size.width / 2 - 150,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 300),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, 40 * (1 - value)),
                child: Opacity(
                  opacity: value,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10b981),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Imagens salvas com sucesso!',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    Future.delayed(const Duration(seconds: 3), () {
      overlayEntry.remove();
    });
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
      final localInst = selectedLocal.localInstalacaoSap ?? selectedLocal.local ?? '';
      try {
        await _mediaRepository.insertSalaEquipamentosSap(
          localInstalacao: localInst,
          sala: trimmed,
          localizacao: localInst,
        );
        final created = Room.fromEquipamentosSap(trimmed, localInst);
        if (!mounted) return;
        setState(() {
          // evita duplicar se a sala já existir
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
