import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'dart:convert';
import '../models/task.dart';
import '../models/pex.dart';
import '../services/pdf_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
// Import condicional para web
import '../html_stub.dart' as html if (dart.library.html) 'dart:html';

class PEXViewDialog extends StatefulWidget {
  final PEX pex;
  final Task task;

  const PEXViewDialog({
    super.key,
    required this.pex,
    required this.task,
  });

  @override
  State<PEXViewDialog> createState() => _PEXViewDialogState();
}

class _PEXViewDialogState extends State<PEXViewDialog> {
  final PDFService _pdfService = PDFService();
  bool _isGeneratingPDF = false;

  Future<void> _exportToPDF() async {
    setState(() => _isGeneratingPDF = true);
    try {
      final pdfBytes = await _pdfService.generatePEXPDF(widget.pex, widget.task);
      final fileName = 'PEX_${widget.pex.numeroPex ?? widget.task.id}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      
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
                text: 'PEX - Planejamento Executivo',
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
              text: 'PEX - Planejamento Executivo',
            );
          } catch (e) {
            // Se falhar ao salvar arquivo, tentar compartilhar diretamente
            await Share.shareXFiles(
              [XFile.fromData(pdfBytes, mimeType: 'application/pdf', name: fileName)],
              text: 'PEX - Planejamento Executivo',
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
        width: isMobile ? double.infinity : 1200,
        height: MediaQuery.of(context).size.height * 0.9,
        child: Column(
          children: [
            // Header
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
                  const Icon(Icons.description, color: Colors.white),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'PEX - Planejamento Executivo',
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
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCabecalho(),
                    const SizedBox(height: 24),
                    _buildIdentificacao(),
                    const SizedBox(height: 24),
                    _buildPlanejamento(),
                    const SizedBox(height: 24),
                    _buildRecursos(),
                    const SizedBox(height: 24),
                    _buildDetalhamento(),
                    const SizedBox(height: 24),
                    _buildRecursosHumanos(),
                  ],
                ),
              ),
            ),
            // Footer com botão de exportar PDF
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

  Widget _buildCabecalho() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cabeçalho',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Table(
              children: [
                _buildTableRow('PEX', widget.pex.numeroPex ?? '-'),
                _buildTableRow('SI', widget.pex.si ?? '-'),
                _buildTableRow('Rev. PEX', widget.pex.revisaoPex?.toString() ?? '1'),
                _buildTableRow(
                  'Data de Elaboração',
                  widget.pex.dataElaboracao != null
                      ? DateFormat('dd/MM/yyyy').format(widget.pex.dataElaboracao!)
                      : '-',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentificacao() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '1. IDENTIFICAÇÃO DA INTERVENÇÃO',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildPessoaRow('Responsável', widget.pex.responsavelNome, widget.pex.responsavelIdSap, widget.pex.responsavelContato),
            _buildPessoaRow('Substituto', widget.pex.substitutoNome, widget.pex.substitutoIdSap, widget.pex.substitutoContato),
            _buildPessoaRow('Fiscal Técnico', widget.pex.fiscalTecnicoNome, widget.pex.fiscalTecnicoIdSap, widget.pex.fiscalTecnicoContato),
            _buildPessoaRow('Coordenador', widget.pex.coordenadorNome, widget.pex.coordenadorIdSap, widget.pex.coordenadorContato),
            _buildPessoaRow('Técnico Seg.', widget.pex.tecnicoSegNome, widget.pex.tecnicoSegIdSap, widget.pex.tecnicoSegContato),
            const SizedBox(height: 16),
            Table(
              children: [
                _buildTableRow('Período', _formatPeriodo()),
                _buildTableRow('Instalação', widget.pex.instalacao ?? '-'),
                _buildTableRow('Equipamentos', widget.pex.equipamentos ?? '-'),
                _buildTableRow('Resumo da Atividade', widget.pex.resumoAtividade ?? '-'),
                _buildTableRow('Configuração - Recebimento', widget.pex.configuracaoRecebimento ?? '-'),
                _buildTableRow('Configuração - Durante', widget.pex.configuracaoDurante ?? '-'),
                _buildTableRow('Configuração - Devolução', widget.pex.configuracaoDevolucao ?? '-'),
                _buildTableRow('Aterramento', widget.pex.aterramentoDescricao ?? '-'),
                _buildTableRow('Total Unidades Aterramento', widget.pex.aterramentoTotalUnidades?.toString() ?? '-'),
                _buildTableRow('Nível de Risco', widget.pex.nivelRisco ?? '-'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatPeriodo() {
    if (widget.pex.dataInicio == null || widget.pex.dataFim == null) return '-';
    final inicio = DateFormat('dd/MM/yyyy').format(widget.pex.dataInicio!);
    final fim = DateFormat('dd/MM/yyyy').format(widget.pex.dataFim!);
    return '$inicio ${widget.pex.horaInicio ?? ""} a $fim ${widget.pex.horaFim ?? ""}';
  }

  Widget _buildPessoaRow(String label, String? nome, String? idSap, String? contato) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(nome ?? '-')),
          SizedBox(
            width: 100,
            child: Text('ID: ${idSap ?? "-"}'),
          ),
          SizedBox(
            width: 150,
            child: Text('Contato: ${contato ?? "-"}'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanejamento() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '2. DADOS PARA PLANEJAMENTO DA INTERVENÇÃO',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (widget.pex.dadosPlanejamento != null && widget.pex.dadosPlanejamento!.isNotEmpty)
              Text(widget.pex.dadosPlanejamento!)
            else
              const Text('Não preenchido', style: TextStyle(fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecursos() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '3. RECURSOS / FERRAMENTAS / MATERIAIS',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildRecursosTable('EPI', widget.pex.recursosEpi),
            const SizedBox(height: 16),
            _buildRecursosTable('EPC', widget.pex.recursosEpc),
            const SizedBox(height: 16),
            _buildRecursosTable('Transporte/Máquinas', widget.pex.recursosTransporte),
            const SizedBox(height: 16),
            _buildRecursosTable('Material de Consumo', widget.pex.recursosMaterialConsumo),
            const SizedBox(height: 16),
            _buildRecursosTable('Ferramentas', widget.pex.recursosFerramentas),
            const SizedBox(height: 16),
            _buildRecursosTable('Comunicação', widget.pex.recursosComunicacao),
            const SizedBox(height: 16),
            _buildRecursosTable('Documentação', widget.pex.recursosDocumentacao),
            const SizedBox(height: 16),
            _buildRecursosTable('Instrumentos', widget.pex.recursosInstrumentos),
          ],
        ),
      ),
    );
  }

  Widget _buildRecursosTable(String title, String? jsonData) {
    List<Map<String, dynamic>> recursos = [];
    if (jsonData != null && jsonData.isNotEmpty) {
      try {
        recursos = List<Map<String, dynamic>>.from(jsonDecode(jsonData));
      } catch (e) {
        // Ignorar erro de parsing
      }
    }

    if (recursos.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Table(
          border: TableBorder.all(color: Colors.grey),
          children: [
            const TableRow(
              decoration: BoxDecoration(color: Colors.grey),
              children: [
                TableCell(child: Padding(padding: EdgeInsets.all(8), child: Text('Qtde', style: TextStyle(fontWeight: FontWeight.bold)))),
                TableCell(child: Padding(padding: EdgeInsets.all(8), child: Text('Recurso', style: TextStyle(fontWeight: FontWeight.bold)))),
              ],
            ),
            ...recursos.map((item) => TableRow(
              children: [
                TableCell(child: Padding(padding: const EdgeInsets.all(8), child: Text(item['qtde']?.toString() ?? ''))),
                TableCell(child: Padding(padding: const EdgeInsets.all(8), child: Text(item['recurso']?.toString() ?? ''))),
              ],
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildDetalhamento() {
    List<Map<String, dynamic>> detalhamento = [];
    if (widget.pex.detalhamentoIntervencao != null && widget.pex.detalhamentoIntervencao!.isNotEmpty) {
      try {
        detalhamento = List<Map<String, dynamic>>.from(jsonDecode(widget.pex.detalhamentoIntervencao!));
      } catch (e) {
        // Ignorar erro de parsing
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '4. DETALHAMENTO DA INTERVENÇÃO',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (detalhamento.isEmpty)
              const Text('Não preenchido', style: TextStyle(fontStyle: FontStyle.italic))
            else
              Table(
                border: TableBorder.all(color: Colors.grey),
                children: [
                  const TableRow(
                    decoration: BoxDecoration(color: Colors.grey),
                    children: [
                      TableCell(child: Padding(padding: EdgeInsets.all(8), child: Text('Item', style: TextStyle(fontWeight: FontWeight.bold)))),
                      TableCell(child: Padding(padding: EdgeInsets.all(8), child: Text('Atividade', style: TextStyle(fontWeight: FontWeight.bold)))),
                      TableCell(child: Padding(padding: EdgeInsets.all(8), child: Text('Detalhamento', style: TextStyle(fontWeight: FontWeight.bold)))),
                      TableCell(child: Padding(padding: EdgeInsets.all(8), child: Text('Responsável', style: TextStyle(fontWeight: FontWeight.bold)))),
                    ],
                  ),
                  ...detalhamento.map((item) => TableRow(
                    children: [
                      TableCell(child: Padding(padding: const EdgeInsets.all(8), child: Text(item['item']?.toString() ?? ''))),
                      TableCell(child: Padding(padding: const EdgeInsets.all(8), child: Text(item['atividade']?.toString() ?? ''))),
                      TableCell(child: Padding(padding: const EdgeInsets.all(8), child: Text(item['detalhamento']?.toString() ?? ''))),
                      TableCell(child: Padding(padding: const EdgeInsets.all(8), child: Text(item['responsavel']?.toString() ?? ''))),
                    ],
                  )),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecursosHumanos() {
    List<Map<String, dynamic>> recursos = [];
    if (widget.pex.recursosHumanos != null && widget.pex.recursosHumanos!.isNotEmpty) {
      try {
        recursos = List<Map<String, dynamic>>.from(jsonDecode(widget.pex.recursosHumanos!));
      } catch (e) {
        // Ignorar erro de parsing
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '5. RECURSOS HUMANOS E CIÊNCIA DOS RISCOS',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (recursos.isEmpty)
              const Text('Não preenchido', style: TextStyle(fontStyle: FontStyle.italic))
            else
              Table(
                border: TableBorder.all(color: Colors.grey),
                children: [
                  const TableRow(
                    decoration: BoxDecoration(color: Colors.grey),
                    children: [
                      TableCell(child: Padding(padding: EdgeInsets.all(8), child: Text('Nome', style: TextStyle(fontWeight: FontWeight.bold)))),
                      TableCell(child: Padding(padding: EdgeInsets.all(8), child: Text('Empresa/Equipe', style: TextStyle(fontWeight: FontWeight.bold)))),
                      TableCell(child: Padding(padding: EdgeInsets.all(8), child: Text('Documento/Matrícula', style: TextStyle(fontWeight: FontWeight.bold)))),
                      TableCell(child: Padding(padding: EdgeInsets.all(8), child: Text('Estado Físico/Emocional', style: TextStyle(fontWeight: FontWeight.bold)))),
                      TableCell(child: Padding(padding: EdgeInsets.all(8), child: Text('Ciência dos Riscos', style: TextStyle(fontWeight: FontWeight.bold)))),
                    ],
                  ),
                  ...recursos.map((item) => TableRow(
                    children: [
                      TableCell(child: Padding(padding: const EdgeInsets.all(8), child: Text(item['nome']?.toString() ?? ''))),
                      TableCell(child: Padding(padding: const EdgeInsets.all(8), child: Text(item['empresa_equipe']?.toString() ?? ''))),
                      TableCell(child: Padding(padding: const EdgeInsets.all(8), child: Text(item['documento_matricula']?.toString() ?? ''))),
                      TableCell(child: Center(child: Icon(item['estado_fisico_emocional'] == true ? Icons.check : Icons.close))),
                      TableCell(child: Center(child: Icon(item['ciencia_atividades_riscos'] == true ? Icons.check : Icons.close))),
                    ],
                  )),
                ],
              ),
            const SizedBox(height: 16),
            if (widget.pex.aprovador != null || widget.pex.dataAprovacao != null)
              Table(
                children: [
                  if (widget.pex.aprovador != null)
                    _buildTableRow('Aprovador', widget.pex.aprovador!),
                  if (widget.pex.dataAprovacao != null)
                    _buildTableRow(
                      'Data de Aprovação',
                      DateFormat('dd/MM/yyyy').format(widget.pex.dataAprovacao!),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  TableRow _buildTableRow(String label, String value) {
    return TableRow(
      children: [
        TableCell(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        TableCell(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(value),
          ),
        ),
      ],
    );
  }
}
