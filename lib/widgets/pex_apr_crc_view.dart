import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'dart:ui' show Rect;
import '../models/task.dart';
import '../models/pex.dart';
import '../models/apr.dart';
import '../models/crc.dart';
import '../services/pex_service.dart';
import '../services/apr_service.dart';
import '../services/crc_service.dart';
import '../services/pdf_service.dart';
import 'pex_form_dialog.dart';
import 'apr_form_dialog.dart';
import 'crc_form_dialog.dart';
import 'pex_view_dialog.dart';
import 'apr_view_dialog.dart';
import 'crc_view_dialog.dart';
// Import condicional para web
import '../html_stub.dart' as html if (dart.library.html) 'dart:html';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class PEXAPRCRCView extends StatefulWidget {
  final Task task;

  const PEXAPRCRCView({
    super.key,
    required this.task,
  });

  @override
  State<PEXAPRCRCView> createState() => _PEXAPRCRCViewState();
}

class _PEXAPRCRCViewState extends State<PEXAPRCRCView> {
  final PEXService _pexService = PEXService();
  final APRService _aprService = APRService();
  final CRCService _crcService = CRCService();
  final PDFService _pdfService = PDFService();

  PEX? _pex;
  APR? _apr;
  CRC? _crc;
  bool _isLoading = true;
  bool _isDownloadingPEX = false;
  bool _isDownloadingAPR = false;
  bool _isDownloadingCRC = false;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _pexService.getPEXByTaskId(widget.task.id),
        _aprService.getAPRByTaskId(widget.task.id),
        _crcService.getCRCByTaskId(widget.task.id),
      ]);

      if (mounted) {
        setState(() {
          _pex = results[0] as PEX?;
          _apr = results[1] as APR?;
          _crc = results[2] as CRC?;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Erro ao carregar documentos: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openPEXForm() async {
    final result = await showDialog<PEX>(
      context: context,
      builder: (context) => PEXFormDialog(
        task: widget.task,
        pex: _pex,
      ),
    );

    if (result != null) {
      await _loadDocuments();
    }
  }

  Future<void> _openAPRForm() async {
    final result = await showDialog<APR>(
      context: context,
      builder: (context) => APRFormDialog(
        task: widget.task,
        apr: _apr,
      ),
    );

    if (result != null) {
      await _loadDocuments();
    }
  }

  Future<void> _openCRCForm() async {
    final result = await showDialog<CRC>(
      context: context,
      builder: (context) => CRCFormDialog(
        task: widget.task,
        crc: _crc,
      ),
    );

    if (result != null) {
      await _loadDocuments();
    }
  }

  Future<void> _viewPEX() async {
    if (_pex == null) return;
    await showDialog(
      context: context,
      builder: (context) => PEXViewDialog(pex: _pex!, task: widget.task),
    );
  }

  Future<void> _viewAPR() async {
    if (_apr == null) return;
    await showDialog(
      context: context,
      builder: (context) => APRViewDialog(apr: _apr!, task: widget.task),
    );
  }

  Future<void> _viewCRC() async {
    if (_crc == null) return;
    await showDialog(
      context: context,
      builder: (context) => CRCViewDialog(crc: _crc!, task: widget.task),
    );
  }

  Future<void> _downloadPEX() async {
    if (_pex == null) return;
    setState(() => _isDownloadingPEX = true);
    try {
      final pdfBytes = await _pdfService.generatePEXPDF(_pex!, widget.task);
      final fileName = 'PEX_${_pex!.numeroPex ?? widget.task.id}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      await _downloadPDF(pdfBytes, fileName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao gerar PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloadingPEX = false);
      }
    }
  }

  Future<void> _downloadAPR() async {
    if (_apr == null) return;
    setState(() => _isDownloadingAPR = true);
    try {
      final pdfBytes = await _pdfService.generateAPRPDF(_apr!, widget.task);
      final fileName = 'APR_${_apr!.numeroApr ?? widget.task.id}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      await _downloadPDF(pdfBytes, fileName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao gerar PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloadingAPR = false);
      }
    }
  }

  Future<void> _downloadCRC() async {
    if (_crc == null) return;
    setState(() => _isDownloadingCRC = true);
    try {
      final pdfBytes = await _pdfService.generateCRCPDF(_crc!, widget.task);
      final fileName = 'CRC_${_crc!.numeroCrc ?? widget.task.id}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      await _downloadPDF(pdfBytes, fileName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao gerar PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloadingCRC = false);
      }
    }
  }

  Future<void> _downloadPDF(Uint8List pdfBytes, String fileName) async {
    print('🔍 DEBUG _downloadPDF: Iniciando download');
    print('🔍 DEBUG _downloadPDF: kIsWeb = $kIsWeb');
    print('🔍 DEBUG _downloadPDF: fileName = $fileName');
    print('🔍 DEBUG _downloadPDF: pdfBytes.length = ${pdfBytes.length}');
    
    if (kIsWeb) {
      print('🌐 DEBUG: Executando em ambiente web');
      try {
        print('🔍 DEBUG: Criando Blob...');
        final blob = html.Blob([pdfBytes], 'application/pdf');
        print('🔍 DEBUG: Blob criado com sucesso');
        
        print('🔍 DEBUG: Criando URL do Blob...');
        final url = html.Url.createObjectUrlFromBlob(blob);
        print('🔍 DEBUG: URL criada: $url');
        
        // Criar um link visível e clicável na página
        print('🔍 DEBUG: Criando link visível para download...');
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..setAttribute('target', '_blank')
          ..id = 'pdf-download-link-$fileName';
        
        // Estilizar o link para ser visível
        anchor.style.cssText = '''
          position: fixed;
          top: 20px;
          right: 20px;
          background-color: #4CAF50;
          color: white;
          padding: 15px 25px;
          border-radius: 8px;
          text-decoration: none;
          font-size: 16px;
          font-weight: bold;
          z-index: 99999;
          box-shadow: 0 4px 6px rgba(0,0,0,0.3);
          cursor: pointer;
        ''';
        
        // Adicionar texto ao link usando innerHTML
        try {
          anchor.setInnerHtml('📥 Clique para Baixar PDF', treeSanitizer: html.NodeTreeSanitizer.trusted);
        } catch (e) {
          print('⚠️ DEBUG: Erro ao adicionar texto ao link: $e');
          // Tentar método alternativo
          anchor.href = url;
        }
        
        // Remover link anterior se existir
        final existingLink = html.document.getElementById('pdf-download-link-$fileName');
        if (existingLink != null) {
          existingLink.remove();
        }
        
        // Adicionar ao body
        html.document.body?.append(anchor);
        print('✅ DEBUG: Link visível adicionado ao body');
        
        // Tentar abrir automaticamente também
        try {
          print('🔍 DEBUG: Tentando abrir em nova aba automaticamente...');
          html.window.open(url, '_blank');
          print('✅ DEBUG: Comando window.open executado');
        } catch (e) {
          print('⚠️ DEBUG: Erro ao abrir automaticamente: $e');
        }
        
        // Mostrar diálogo com instruções
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.download, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Download do PDF'),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Clique no botão verde no canto superior direito da tela para baixar o PDF.',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Ou use o atalho:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    const Text('• No Mac: Cmd + S'),
                    const Text('• No Windows/Linux: Ctrl + S'),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        // Tentar clicar no link programaticamente
                        try {
                          anchor.click();
                        } catch (e) {
                          print('⚠️ DEBUG: Erro ao clicar no link: $e');
                        }
                      },
                      icon: const Icon(Icons.download),
                      label: const Text('Baixar Agora'),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Fechar'),
                  ),
                ],
              );
            },
          );
        }
        
        // Remover o link após 30 segundos
        Future.delayed(const Duration(seconds: 30), () {
          try {
            final linkToRemove = html.document.getElementById('pdf-download-link-$fileName');
            if (linkToRemove != null) {
              linkToRemove.remove();
              print('✅ DEBUG: Link removido após 30 segundos');
            }
          } catch (e) {
            print('⚠️ DEBUG: Erro ao remover link: $e');
          }
        });
        
        // Aguardar antes de revogar URL (dar tempo para o usuário salvar)
        Future.delayed(const Duration(minutes: 5), () {
          html.Url.revokeObjectUrl(url);
          print('✅ DEBUG: URL revogada após 5 minutos');
        });
        
        print('✅ DEBUG: Processo de download iniciado');
      } catch (e, stackTrace) {
        print('❌ DEBUG: Erro geral no download: $e');
        print('❌ DEBUG: Stack trace: $stackTrace');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao preparar download: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } else {
      print('📱 DEBUG: Executando em ambiente mobile/desktop');
      try {
        print('🔍 DEBUG: Obtendo diretório de documentos...');
        final directory = await getApplicationDocumentsDirectory();
        print('✅ DEBUG: Diretório obtido: ${directory.path}');
        
        final file = File('${directory.path}/$fileName');
        print('🔍 DEBUG: Escrevendo arquivo: ${file.path}');
        await file.writeAsBytes(pdfBytes);
        print('✅ DEBUG: Arquivo escrito com sucesso');
        
        print('🔍 DEBUG: Compartilhando arquivo...');
        // No mobile, usar share simples sem sharePositionOrigin
        // Isso evita o erro PlatformException
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'PDF gerado: $fileName',
          sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1), // Posição padrão válida
        );
        print('✅ DEBUG: Arquivo compartilhado');
      } catch (e, stackTrace) {
        print('❌ DEBUG: Erro ao compartilhar arquivo: $e');
        print('❌ DEBUG: Stack trace: $stackTrace');
        
        // Se falhar, pelo menos salvar o arquivo e informar o usuário
        try {
          final directory = await getApplicationDocumentsDirectory();
          final file = File('${directory.path}/$fileName');
          await file.writeAsBytes(pdfBytes);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('PDF salvo com sucesso!\nLocal: ${file.path}'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'OK',
                  textColor: Colors.white,
                  onPressed: () {},
                ),
              ),
            );
          }
          print('✅ DEBUG: Arquivo salvo localmente');
        } catch (saveError) {
          print('❌ DEBUG: Erro ao salvar arquivo: $saveError');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erro ao salvar PDF: $saveError'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      }
    }
    print('🏁 DEBUG _downloadPDF: Finalizado');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDocumentCard(
          title: 'PEX - Planejamento Executivo',
          icon: Icons.description,
          hasDocument: _pex != null,
          status: _pex?.status,
          onCreate: _openPEXForm,
          onView: _viewPEX,
          onDownload: _downloadPEX,
          isDownloading: _isDownloadingPEX,
        ),
        const SizedBox(height: 8),
        _buildDocumentCard(
          title: 'APR - Análise Preliminar de Risco',
          icon: Icons.warning,
          hasDocument: _apr != null,
          status: _apr?.status,
          onCreate: _openAPRForm,
          onView: _viewAPR,
          onDownload: _downloadAPR,
          isDownloading: _isDownloadingAPR,
        ),
        const SizedBox(height: 8),
        _buildDocumentCard(
          title: 'CRC - Controle de Pontos Críticos',
          icon: Icons.check_circle,
          hasDocument: _crc != null,
          status: _crc?.status,
          onCreate: _openCRCForm,
          onView: _viewCRC,
          onDownload: _downloadCRC,
          isDownloading: _isDownloadingCRC,
        ),
      ],
    );
  }

  Widget _buildDocumentCard({
    required String title,
    required IconData icon,
    required bool hasDocument,
    String? status,
    required VoidCallback onCreate,
    required VoidCallback onView,
    required VoidCallback? onDownload,
    bool isDownloading = false,
  }) {
    Color statusColor = Colors.grey;
    String statusText = 'Não criado';
    
    if (hasDocument && status != null) {
      switch (status) {
        case 'rascunho':
          statusColor = Colors.orange;
          statusText = 'Rascunho';
          break;
        case 'aprovado':
          statusColor = Colors.blue;
          statusText = 'Aprovado';
          break;
        case 'em_execucao':
          statusColor = Colors.purple;
          statusText = 'Em Execução';
          break;
        case 'concluido':
          statusColor = Colors.green;
          statusText = 'Concluído';
          break;
      }
    }

    return Card(
      child: ListTile(
        leading: Icon(icon, color: statusColor),
        title: Text(title),
        subtitle: Text(statusText),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasDocument) ...[
              IconButton(
                icon: const Icon(Icons.visibility),
                tooltip: 'Visualizar',
                onPressed: onView,
              ),
              IconButton(
                icon: isDownloading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download),
                tooltip: 'Download PDF',
                onPressed: isDownloading ? null : onDownload,
              ),
            ],
            IconButton(
              icon: Icon(hasDocument ? Icons.edit : Icons.add),
              tooltip: hasDocument ? 'Editar' : 'Criar',
              onPressed: onCreate,
            ),
          ],
        ),
      ),
    );
  }
}
