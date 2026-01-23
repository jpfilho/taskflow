import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../models/apr.dart';
import '../services/pdf_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
// Import condicional para web
import '../html_stub.dart' as html if (dart.library.html) 'dart:html';

class APRViewDialog extends StatefulWidget {
  final APR apr;
  final Task task;

  const APRViewDialog({
    super.key,
    required this.apr,
    required this.task,
  });

  @override
  State<APRViewDialog> createState() => _APRViewDialogState();
}

class _APRViewDialogState extends State<APRViewDialog> {
  final PDFService _pdfService = PDFService();
  bool _isGeneratingPDF = false;

  Future<void> _exportToPDF() async {
    setState(() => _isGeneratingPDF = true);
    try {
      final pdfBytes = await _pdfService.generateAPRPDF(widget.apr, widget.task);
      final fileName = 'APR_${widget.apr.numeroApr ?? widget.task.id}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      
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
                text: 'APR - Análise Preliminar de Risco',
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
              text: 'APR - Análise Preliminar de Risco',
            );
          } catch (e) {
            // Se falhar ao salvar arquivo, tentar compartilhar diretamente
            await Share.shareXFiles(
              [XFile.fromData(pdfBytes, mimeType: 'application/pdf', name: fileName)],
              text: 'APR - Análise Preliminar de Risco',
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
      child: Container(
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
                  const Icon(Icons.warning, color: Colors.white),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'APR - Análise Preliminar de Risco',
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
                      _buildInfoRow('Número APR', widget.apr.numeroApr ?? '-'),
                      _buildInfoRow(
                        'Data de Elaboração',
                        widget.apr.dataElaboracao != null
                            ? DateFormat('dd/MM/yyyy').format(widget.apr.dataElaboracao!)
                            : '-',
                      ),
                      _buildInfoRow('Responsável', widget.apr.responsavelElaboracao ?? '-'),
                      _buildInfoRow('Aprovador', widget.apr.aprovador ?? '-'),
                      _buildInfoRow(
                        'Data de Aprovação',
                        widget.apr.dataAprovacao != null
                            ? DateFormat('dd/MM/yyyy').format(widget.apr.dataAprovacao!)
                            : '-',
                      ),
                    ]),
                    const SizedBox(height: 16),
                    _buildInfoCard('Dados da Atividade', [
                      _buildInfoRow('Atividade', widget.apr.atividade ?? '-'),
                      _buildInfoRow('Local de Execução', widget.apr.localExecucao ?? '-'),
                      _buildInfoRow(
                        'Data de Execução',
                        widget.apr.dataExecucao != null
                            ? DateFormat('dd/MM/yyyy').format(widget.apr.dataExecucao!)
                            : '-',
                      ),
                      _buildInfoRow('Equipe Executora', widget.apr.equipeExecutora ?? '-'),
                      _buildInfoRow('Coordenador', widget.apr.coordenadorAtividade ?? '-'),
                    ]),
                    const SizedBox(height: 16),
                    _buildInfoCard('Análise de Riscos', [
                      _buildInfoRow('Riscos Identificados', widget.apr.riscosIdentificados ?? '-', isMultiline: true),
                    ]),
                    const SizedBox(height: 16),
                    _buildInfoCard('Medidas de Controle', [
                      _buildInfoRow('Medidas de Controle', widget.apr.medidasControle ?? '-', isMultiline: true),
                    ]),
                    const SizedBox(height: 16),
                    _buildInfoCard('EPIs e Permissões', [
                      _buildInfoRow('EPIs Necessários', widget.apr.episNecessarios ?? '-', isMultiline: true),
                      _buildInfoRow('Permissões Necessárias', widget.apr.permissoesNecessarias ?? '-', isMultiline: true),
                      _buildInfoRow('Autorizações Necessárias', widget.apr.autorizacoesNecessarias ?? '-', isMultiline: true),
                    ]),
                    const SizedBox(height: 16),
                    _buildInfoCard('Procedimentos de Emergência', [
                      _buildInfoRow('Procedimentos', widget.apr.procedimentosEmergencia ?? '-', isMultiline: true),
                    ]),
                    const SizedBox(height: 16),
                    _buildInfoCard('Observações', [
                      _buildInfoRow('Observações', widget.apr.observacoes ?? '-', isMultiline: true),
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
