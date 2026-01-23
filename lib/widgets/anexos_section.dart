import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import '../models/anexo.dart';
import '../services/anexo_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';

class AnexosSection extends StatefulWidget {
  final String taskId;
  final bool isEditing;

  const AnexosSection({
    super.key,
    required this.taskId,
    this.isEditing = false,
  });

  @override
  State<AnexosSection> createState() => _AnexosSectionState();
}

class _AnexosSectionState extends State<AnexosSection> {
  final AnexoService _anexoService = AnexoService();
  List<Anexo> _anexos = [];
  bool _isLoading = false;
  bool _isUploading = false;
  final PageController _carouselController = PageController();
  int _currentCarouselIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _loadAnexos();
    }
  }

  @override
  void dispose() {
    _carouselController.dispose();
    super.dispose();
  }

  Future<void> _loadAnexos() async {
    setState(() => _isLoading = true);
    try {
      final anexos = await _anexoService.getAnexosByTaskId(widget.taskId);
      setState(() {
        _anexos = anexos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar anexos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadArquivo() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() => _isUploading = true);

        for (var file in result.files) {
          try {
            if (kIsWeb) {
              // Web: usar bytes
              if (file.bytes != null) {
                await _anexoService.uploadAnexoFromBytes(
                  taskId: widget.taskId,
                  bytes: file.bytes!,
                  nomeArquivo: file.name,
                  mimeType: file.extension != null
                      ? _getMimeTypeFromExtension(file.extension!)
                      : null,
                );
              }
            } else {
              // Mobile/Desktop: usar File
              if (file.path != null) {
                await _anexoService.uploadAnexo(
                  taskId: widget.taskId,
                  file: File(file.path!),
                );
              }
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Erro ao fazer upload de ${file.name}: $e'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }
        }

        setState(() => _isUploading = false);
        
        if (widget.isEditing) {
          await _loadAnexos();
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Arquivo(s) enviado(s) com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao selecionar arquivo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteAnexo(Anexo anexo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text('Deseja realmente excluir o arquivo "${anexo.nomeArquivo}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await _anexoService.deleteAnexo(anexo);
        if (widget.isEditing) {
          await _loadAnexos();
        } else {
          setState(() {
            _anexos.remove(anexo);
          });
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Arquivo excluído com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir arquivo: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _visualizarAnexo(Anexo anexo) async {
    try {
      final url = await _anexoService.getSignedUrl(anexo);
      final uri = Uri.parse(url);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication, // Abre em navegador/app externo
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Não foi possível abrir o arquivo: $url'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao visualizar arquivo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadAnexo(Anexo anexo) async {
    try {
      final url = await _anexoService.getSignedUrl(anexo);
      final uri = Uri.parse(url);
      
      // Em web, abrir URL diretamente para download
      if (kIsWeb) {
        if (await canLaunchUrl(uri)) {
          await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
        }
      } else {
        // Em mobile/desktop, fazer download
        await _anexoService.downloadAnexo(anexo);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Download iniciado'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao fazer download: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getMimeTypeFromExtension(String extension) {
    final mimeTypes = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'mp4': 'video/mp4',
      'avi': 'video/x-msvideo',
    };
    return mimeTypes[extension.toLowerCase()] ?? 'application/octet-stream';
  }

  IconData _getIconePorTipo(String tipo) {
    switch (tipo) {
      case 'imagem':
        return Icons.image;
      case 'video':
        return Icons.videocam;
      case 'documento':
        return Icons.description;
      default:
        return Icons.attach_file;
    }
  }

  Color _getCorPorTipo(String tipo) {
    switch (tipo) {
      case 'imagem':
        return Colors.blue;
      case 'video':
        return Colors.purple;
      case 'documento':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  List<Anexo> get _anexosVisuais {
    return _anexos.where((a) => 
      a.tipoArquivo == 'imagem' || a.tipoArquivo == 'video'
    ).toList();
  }

  Widget _buildCarrosselPreview() {
    final anexosVisuais = _anexosVisuais;
    
    if (anexosVisuais.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 300,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Carrossel
          Expanded(
            child: PageView.builder(
              controller: _carouselController,
              onPageChanged: (index) {
                setState(() {
                  _currentCarouselIndex = index;
                });
              },
              itemCount: anexosVisuais.length,
              itemBuilder: (context, index) {
                final anexo = anexosVisuais[index];
                final url = _anexoService.getPublicUrl(anexo);
                
                if (anexo.tipoArquivo == 'imagem') {
                  return GestureDetector(
                    onTap: () => _mostrarImagemFullScreen(url, anexo.nomeArquivo),
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.black12,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(),
                          ),
                          errorWidget: (context, url, error) => Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline, 
                                  color: Colors.grey[600], size: 48),
                                const SizedBox(height: 8),
                                Text(
                                  'Erro ao carregar imagem',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                } else if (anexo.tipoArquivo == 'video') {
                  // vídeo usa url abaixo
                } else if (anexo.tipoArquivo == 'audio') {
                  return const SizedBox.shrink();
                } else {
                  return const SizedBox.shrink();
                }

                // Fallback para vídeo (usa url)
                return Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.black87,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: double.infinity,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.videocam,
                          size: 64,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                      Positioned(
                        bottom: 12,
                        left: 12,
                        right: 12,
                        child: Text(
                          anexo.nomeArquivo,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Positioned.fill(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _visualizarAnexo(anexo),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarImagemFullScreen(String imageUrl, String nomeArquivo) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: PhotoView(
                imageProvider: CachedNetworkImageProvider(imageUrl),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2,
                backgroundDecoration: const BoxDecoration(
                  color: Colors.transparent,
                ),
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.black,
                  child: const Center(
                    child: Icon(
                      Icons.error_outline,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
                loadingBuilder: (context, event) => Container(
                  color: Colors.black,
                  child: Center(
                    child: CircularProgressIndicator(
                      value: event == null
                          ? 0
                          : event.cumulativeBytesLoaded /
                              event.expectedTotalBytes!,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    nomeArquivo,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Anexos',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            ElevatedButton.icon(
              onPressed: _isUploading ? null : _uploadArquivo,
              icon: _isUploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file, size: 18),
              label: Text(_isUploading ? 'Enviando...' : 'Adicionar arquivo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A5F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_anexos.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: const Center(
              child: Text(
                'Nenhum arquivo anexado',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          )
        else ...[
          // Carrossel de preview para imagens e vídeos
          _buildCarrosselPreview(),
          const SizedBox(height: 8),
          // Lista de todos os anexos
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(4),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _anexos.length,
              itemBuilder: (context, index) {
                final anexo = _anexos[index];
                return ListTile(
                  dense: true,
                  leading: Icon(
                    _getIconePorTipo(anexo.tipoArquivo),
                    color: _getCorPorTipo(anexo.tipoArquivo),
                    size: 24,
                  ),
                  title: Text(
                    anexo.nomeArquivo,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: Text(
                    AnexoService.formatarTamanho(anexo.tamanhoBytes),
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility, size: 20, color: Colors.blue),
                        onPressed: () => _visualizarAnexo(anexo),
                        tooltip: 'Visualizar',
                      ),
                      IconButton(
                        icon: const Icon(Icons.download, size: 20),
                        onPressed: () => _downloadAnexo(anexo),
                        tooltip: 'Download',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                        onPressed: () => _deleteAnexo(anexo),
                        tooltip: 'Excluir',
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

