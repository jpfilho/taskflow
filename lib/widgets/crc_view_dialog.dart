import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../models/crc.dart';
import '../services/pdf_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
// Import condicional para web
import '../html_stub.dart' as html if (dart.library.html) 'dart:html';

class CRCViewDialog extends StatefulWidget {
  final CRC crc;
  final Task task;

  const CRCViewDialog({
    super.key,
    required this.crc,
    required this.task,
  });

  @override
  State<CRCViewDialog> createState() => _CRCViewDialogState();
}

class _CRCViewDialogState extends State<CRCViewDialog> {
  final PDFService _pdfService = PDFService();
  bool _isGeneratingPDF = false;

  Future<void> _exportToPDF() async {
    setState(() => _isGeneratingPDF = true);
    try {
      final pdfBytes = await _pdfService.generateCRCPDF(widget.crc, widget.task);
      final fileName = 'CRC_${widget.crc.numeroCrc ?? widget.task.id}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      
      if (mounted) {
        if (kIsWeb) {
          // Para web, fazer download direto usando dart:html
          try {
            print('📥 Iniciando download do PDF: $fileName (${pdfBytes.length} bytes)');
            
            // Criar blob
            final blob = html.Blob([pdfBytes], 'application/pdf');
            final url = html.Url.createObjectUrlFromBlob(blob);
            print('📥 URL criada: $url');
            
            // Método mais confiável: usar window.open como fallback se anchor não funcionar
            try {
              // Tentar método com anchor primeiro
              final anchor = html.AnchorElement(href: url)
                ..setAttribute('download', fileName)
                ..style.display = 'none'
                ..style.visibility = 'hidden'
                ..style.width = '0'
                ..style.height = '0';
              
              // Garantir que o body existe
              var body = html.document.body;
              if (body == null) {
                await Future.delayed(const Duration(milliseconds: 200));
                body = html.document.body;
              }
              
              if (body != null) {
                body.append(anchor);
                print('📥 Anchor adicionado ao body');
                
                // Forçar o download
                anchor.click();
                print('📥 Click executado no anchor');
                
                // Aguardar antes de limpar
                await Future.delayed(const Duration(milliseconds: 3000));
                
                // Remover o elemento
                try {
                  anchor.remove();
                  print('📥 Anchor removido');
                } catch (e) {
                  print('⚠️ Erro ao remover anchor: $e');
                }
              } else {
                // Se body não estiver disponível, usar window.open
                print('⚠️ Body não disponível, usando window.open');
                html.window.open(url, '_blank');
                await Future.delayed(const Duration(milliseconds: 1000));
              }
              
              // Aguardar mais antes de revogar a URL
              await Future.delayed(const Duration(milliseconds: 2000));
              html.Url.revokeObjectUrl(url);
              print('✅ Download iniciado com sucesso');
            } catch (anchorError) {
              // Se anchor falhar, tentar window.open
              print('⚠️ Erro com anchor, tentando window.open: $anchorError');
              html.window.open(url, '_blank');
              await Future.delayed(const Duration(milliseconds: 2000));
              html.Url.revokeObjectUrl(url);
              print('✅ Download iniciado via window.open');
            }
          } catch (e, stackTrace) {
            print('❌ Erro ao fazer download na web: $e');
            print('❌ Stack trace: $stackTrace');
            // Fallback: tentar usar share_plus
            try {
              await Share.shareXFiles(
                [XFile.fromData(pdfBytes, mimeType: 'application/pdf', name: fileName)],
                text: 'CRC - Controle de Pontos Críticos',
              );
            } catch (shareError) {
              print('❌ Erro também no fallback share_plus: $shareError');
              rethrow;
            }
          }
        } else {
          // Para mobile/desktop, salvar em arquivo temporário
          try {
            final directory = await getApplicationDocumentsDirectory();
            final file = File('${directory.path}/$fileName');
            await file.writeAsBytes(pdfBytes);
            
            await Share.shareXFiles(
              [XFile(file.path)],
              text: 'CRC - Controle de Pontos Críticos',
            );
          } catch (e) {
            // Se falhar ao salvar arquivo, tentar compartilhar diretamente
            await Share.shareXFiles(
              [XFile.fromData(pdfBytes, mimeType: 'application/pdf', name: fileName)],
              text: 'CRC - Controle de Pontos Críticos',
            );
          }
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(kIsWeb 
                ? 'PDF gerado! Verifique sua pasta de Downloads.'
                : 'PDF gerado e compartilhado com sucesso!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
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
        setState(() => _isGeneratingPDF = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Dialog(
      child: SizedBox(
        width: isMobile ? double.infinity : 900,
        height: MediaQuery.of(context).size.height * 0.9,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF1E3A5F),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'CRC - Controle de Pontos Críticos',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoCard('Informações Gerais', [
                      _buildInfoRow('Número CRC', widget.crc.numeroCrc ?? '-'),
                      _buildInfoRow(
                        'Data de Elaboração',
                        widget.crc.dataElaboracao != null
                            ? DateFormat('dd/MM/yyyy').format(widget.crc.dataElaboracao!)
                            : '-',
                      ),
                      _buildInfoRow('Responsável', widget.crc.responsavelElaboracao ?? '-'),
                      _buildInfoRow('Aprovador', widget.crc.aprovador ?? '-'),
                      _buildInfoRow(
                        'Data de Aprovação',
                        widget.crc.dataAprovacao != null
                            ? DateFormat('dd/MM/yyyy').format(widget.crc.dataAprovacao!)
                            : '-',
                      ),
                    ]),
                    const SizedBox(height: 16),
                    _buildInfoCard('Dados da Atividade', [
                      _buildInfoRow('Atividade', widget.crc.atividade ?? '-'),
                      _buildInfoRow('Local de Execução', widget.crc.localExecucao ?? '-'),
                      _buildInfoRow(
                        'Data de Execução',
                        widget.crc.dataExecucao != null
                            ? DateFormat('dd/MM/yyyy').format(widget.crc.dataExecucao!)
                            : '-',
                      ),
                      _buildInfoRow('Equipe Executora', widget.crc.equipeExecutora ?? '-'),
                      _buildInfoRow('Coordenador', widget.crc.coordenadorAtividade ?? '-'),
                    ]),
                    const SizedBox(height: 16),
                    _buildInfoCard('Pontos Críticos', [
                      _buildInfoRow('Pontos Críticos', widget.crc.pontosCriticos ?? '-', isMultiline: true),
                    ]),
                    const SizedBox(height: 16),
                    _buildInfoCard('Controles', [
                      _buildInfoRow('Controles', widget.crc.controles ?? '-', isMultiline: true),
                    ]),
                    const SizedBox(height: 16),
                    _buildInfoCard('Verificações', [
                      _buildInfoRow('Verificações', widget.crc.verificacoes ?? '-', isMultiline: true),
                    ]),
                    const SizedBox(height: 16),
                    _buildInfoCard('Responsáveis', [
                      _buildInfoRow('Responsáveis pela Verificação', widget.crc.responsaveisVerificacao ?? '-'),
                    ]),
                    const SizedBox(height: 16),
                    _buildInfoCard('Observações', [
                      _buildInfoRow('Observações', widget.crc.observacoes ?? '-', isMultiline: true),
                    ]),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isGeneratingPDF ? null : _exportToPDF,
                    icon: _isGeneratingPDF
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf),
                    label: Text(_isGeneratingPDF ? 'Gerando...' : 'Exportar PDF'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isMultiline = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 200,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: isMultiline
                ? Text(value, textAlign: TextAlign.justify)
                : Text(value),
          ),
        ],
      ),
    );
  }
}
