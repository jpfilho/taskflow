import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'dart:convert';
import '../models/pex.dart';
import '../models/apr.dart';
import '../models/crc.dart';
import '../models/task.dart';

class PDFService {
  // Gerar PDF do PEX
  Future<Uint8List> generatePEXPDF(PEX pex, Task task) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd.MM.yyyy');
    final timeFormat = DateFormat('HH:mm');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return [
            // Cabeçalho com logo e banner
            _buildPEXHeader(pex, dateFormat),
            pw.SizedBox(height: 16),
            
            // 1. Identificação da Intervenção
            _buildPEXIdentificacao(pex, dateFormat, timeFormat),
            pw.SizedBox(height: 16),
            
            // Configuração (Recebimento, Durante, Devolução)
            _buildPEXConfiguracao(pex),
            pw.SizedBox(height: 16),
            
            // Aterramento
            _buildPEXAterramento(pex),
            pw.SizedBox(height: 16),
            
            // Informações adicionais
            _buildPEXInformacoesAdicionais(pex),
            pw.SizedBox(height: 16),
            
            // Distâncias de segurança
            _buildPEXDistanciasSeguranca(pex),
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildPEXHeader(PEX pex, DateFormat dateFormat) {
    return pw.Container(
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Logo e nome da empresa (esquerda)
          pw.Expanded(
            flex: 2,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'AXIA ENERGIA',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
                // Espaço para logo (seria uma imagem)
              ],
            ),
          ),
          // Banner azul com PEX e Planejamento Executivo (centro)
          pw.Expanded(
            flex: 3,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#1976D2'), // Azul
                border: pw.Border.all(color: PdfColors.black, width: 1),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'PEX',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.Text(
                    'Planejamento Executivo',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // SI e Rev. PEX (direita)
          pw.Expanded(
            flex: 2,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Text('SI', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(width: 4),
                    pw.Text(
                      pex.si ?? '-',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Text('Rev. PEX', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(width: 4),
                    pw.Text(
                      '${pex.revisaoPex ?? 1}',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPEXIdentificacao(PEX pex, DateFormat dateFormat, DateFormat timeFormat) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '1. IDENTIFICAÇÃO DA INTERVENÇÃO',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          // Responsável
          _buildPessoaRowPDF('Responsável', pex.responsavelNome, pex.responsavelIdSap, pex.responsavelContato),
          pw.SizedBox(height: 6),
          // Substituto
          _buildPessoaRowPDF('Substituto', pex.substitutoNome, pex.substitutoIdSap, pex.substitutoContato),
          pw.SizedBox(height: 10),
          // Período
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Período: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              if (pex.dataInicio != null && pex.dataFim != null)
                pw.Text('${dateFormat.format(pex.dataInicio!)} às ${pex.horaInicio ?? ""} a ${dateFormat.format(pex.dataFim!)} às ${pex.horaFim ?? ""}')
              else
                pw.Text('-'),
            ],
          ),
          pw.SizedBox(height: 6),
          // Periodicidade
          if (pex.periodicidade != null || pex.continuo != null) ...[
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Periodicidade: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text(
                  pex.continuo == true 
                    ? 'ALS Contínuo / Diário'
                    : pex.periodicidade == true 
                      ? 'Periódica'
                      : '-',
                ),
              ],
            ),
            pw.SizedBox(height: 6),
          ],
          // Instalação
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Instalação: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Expanded(child: pw.Text(pex.instalacao ?? '-')),
            ],
          ),
          pw.SizedBox(height: 6),
          // Equipamentos
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Equipamentos: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Expanded(child: pw.Text(pex.equipamentos ?? '-')),
            ],
          ),
          pw.SizedBox(height: 6),
          // Resumo da Atividade
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Resumo da Atividade: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Expanded(
                child: pw.Text(
                  pex.resumoAtividade ?? '-',
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPessoaRowPDF(String label, String? nome, String? idSap, String? contato) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 90,
          child: pw.Text(
            '$label:',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Expanded(
          flex: 3,
          child: pw.Text(nome ?? '-'),
        ),
        pw.SizedBox(width: 8),
        pw.SizedBox(
          width: 80,
          child: pw.Text('ID SAP (ou CPF): ${idSap ?? "-"}'),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          flex: 2,
          child: pw.Text('Contato: ${contato ?? "-"}'),
        ),
      ],
    );
  }

  pw.Widget _buildPEXConfiguracao(PEX pex) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Configuração',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          // Recebimento
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Recebimento:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Text(
                  pex.configuracaoRecebimento ?? '-',
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          // Durante
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Durante:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Text(
                  pex.configuracaoDurante ?? '-',
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          // Devolução
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Devolução:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Text(
                  pex.configuracaoDevolucao ?? '-',
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPEXAterramento(PEX pex) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Aterramento',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Text(
                  pex.aterramentoDescricao ?? '-',
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
          if (pex.aterramentoTotalUnidades != null) ...[
            pw.SizedBox(height: 8),
            pw.Row(
              children: [
                pw.Text(
                  'Total:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(width: 8),
                pw.Text('${pex.aterramentoTotalUnidades} unidades'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildPEXInformacoesAdicionais(PEX pex) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Informações adicionais / Outras atividades previstas',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          if (pex.informacoesAdicionais != null && pex.informacoesAdicionais!.isNotEmpty)
            pw.Text(
              pex.informacoesAdicionais!,
              style: const pw.TextStyle(fontSize: 11),
            )
          else
            pw.Text(
              '1. Verificação das Configurações Prévias à Intervenção:\n'
              'As configurações necessárias para a intervenção estão descritas na "SI" e devem ser confirmadas por todos os envolvidos durante o recebimento (condições das chaves, disjuntores, pontos de aterramento, etc);',
              style: const pw.TextStyle(fontSize: 11),
            ),
        ],
      ),
    );
  }

  pw.Widget _buildPEXDistanciasSeguranca(PEX pex) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '2. Atenção à Distância de Segurança (D)',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'É o afastamento mínimo no ar entre o trabalhador (ou suas ferramentas/instrumentos) e a parte energizada, de forma a evitar risco de descarga elétrica.',
            style: const pw.TextStyle(fontSize: 11),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'É calculada pela fórmula: D = d1 + d2',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Onde:',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'd1 = Distância de Segurança Básica ou Valor de Base: Menor distância em qualquer direção, entre executante dos trabalhos, inclusive suas ferramentas, e o ponto energizado mais próximo (tabela do Anexo I da NM-MN-SE-S.002).',
            style: const pw.TextStyle(fontSize: 11),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'd2 = Distância de Segurança Variável: Distância requerida para movimentação do pessoal manipulando instrumentos ou ferramentas, sem invadir a distância d1.',
            style: const pw.TextStyle(fontSize: 11),
          ),
          if (pex.distanciasSeguranca != null && pex.distanciasSeguranca!.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Text(
              pex.distanciasSeguranca!,
              style: const pw.TextStyle(fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildPEXPlanejamento(PEX pex) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '2. DADOS PARA PLANEJAMENTO DA INTERVENÇÃO',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          if (pex.dadosPlanejamento != null && pex.dadosPlanejamento!.isNotEmpty)
            pw.Text(pex.dadosPlanejamento!)
          else
            pw.Text('Não preenchido', style: pw.TextStyle(fontStyle: pw.FontStyle.italic)),
        ],
      ),
    );
  }

  pw.Widget _buildPEXRecursos(PEX pex) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '3. RECURSOS / FERRAMENTAS / MATERIAIS',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          _buildRecursosTablePDF('EPI', pex.recursosEpi),
          pw.SizedBox(height: 8),
          _buildRecursosTablePDF('EPC', pex.recursosEpc),
          pw.SizedBox(height: 8),
          _buildRecursosTablePDF('Transporte/Máquinas', pex.recursosTransporte),
          pw.SizedBox(height: 8),
          _buildRecursosTablePDF('Material de Consumo', pex.recursosMaterialConsumo),
          pw.SizedBox(height: 8),
          _buildRecursosTablePDF('Ferramentas', pex.recursosFerramentas),
          pw.SizedBox(height: 8),
          _buildRecursosTablePDF('Comunicação', pex.recursosComunicacao),
          pw.SizedBox(height: 8),
          _buildRecursosTablePDF('Documentação', pex.recursosDocumentacao),
          pw.SizedBox(height: 8),
          _buildRecursosTablePDF('Instrumentos', pex.recursosInstrumentos),
        ],
      ),
    );
  }

  pw.Widget _buildRecursosTablePDF(String title, String? jsonData) {
    List<Map<String, dynamic>> recursos = [];
    if (jsonData != null && jsonData.isNotEmpty) {
      try {
        recursos = List<Map<String, dynamic>>.from(jsonDecode(jsonData));
      } catch (e) {
        // Ignorar erro
      }
    }

    if (recursos.isEmpty) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.black),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('Qtde', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('Recurso', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
              ],
            ),
            ...recursos.map((item) => pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(item['qtde']?.toString() ?? ''),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(item['recurso']?.toString() ?? ''),
                ),
              ],
            )),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPEXDetalhamento(PEX pex) {
    List<Map<String, dynamic>> detalhamento = [];
    if (pex.detalhamentoIntervencao != null && pex.detalhamentoIntervencao!.isNotEmpty) {
      try {
        detalhamento = List<Map<String, dynamic>>.from(jsonDecode(pex.detalhamentoIntervencao!));
      } catch (e) {
        // Ignorar erro
      }
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '4. DETALHAMENTO DA INTERVENÇÃO',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          if (detalhamento.isEmpty)
            pw.Text('Não preenchido', style: pw.TextStyle(fontStyle: pw.FontStyle.italic))
          else
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.black),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Item', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Atividade', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Detalhamento', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Responsável', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  ],
                ),
                ...detalhamento.map((item) => pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item['item']?.toString() ?? '')),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item['atividade']?.toString() ?? '')),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item['detalhamento']?.toString() ?? '')),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item['responsavel']?.toString() ?? '')),
                  ],
                )),
              ],
            ),
        ],
      ),
    );
  }

  pw.Widget _buildPEXRecursosHumanos(PEX pex, DateFormat dateFormat) {
    List<Map<String, dynamic>> recursos = [];
    if (pex.recursosHumanos != null && pex.recursosHumanos!.isNotEmpty) {
      try {
        recursos = List<Map<String, dynamic>>.from(jsonDecode(pex.recursosHumanos!));
      } catch (e) {
        // Ignorar erro
      }
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '5. RECURSOS HUMANOS E CIÊNCIA DOS RISCOS',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          if (recursos.isEmpty)
            pw.Text('Não preenchido', style: pw.TextStyle(fontStyle: pw.FontStyle.italic))
          else
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.black),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Nome', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Empresa/Equipe', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Documento/Matrícula', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Estado Físico/Emocional', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Ciência dos Riscos', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  ],
                ),
                ...recursos.map((item) => pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item['nome']?.toString() ?? '')),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item['empresa_equipe']?.toString() ?? '')),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item['documento_matricula']?.toString() ?? '')),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Center(child: pw.Text(item['estado_fisico_emocional'] == true ? '✓' : '✗')),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Center(child: pw.Text(item['ciencia_atividades_riscos'] == true ? '✓' : '✗')),
                    ),
                  ],
                )),
              ],
            ),
          if (pex.aprovador != null || pex.dataAprovacao != null) ...[
            pw.SizedBox(height: 12),
            if (pex.aprovador != null)
              pw.Text('Aprovador: ${pex.aprovador}'),
            if (pex.dataAprovacao != null)
              pw.Text('Data de Aprovação: ${dateFormat.format(pex.dataAprovacao!)}'),
          ],
        ],
      ),
    );
  }

  // Gerar PDF do APR
  Future<Uint8List> generateAPRPDF(APR apr, Task task) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text(
                'APR - Análise Preliminar de Risco',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 20),
            _buildAPRContent(apr, dateFormat),
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildAPRContent(APR apr, DateFormat dateFormat) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionPDF('Informações Gerais', [
          _buildInfoRowPDF('Número APR', apr.numeroApr ?? '-'),
          _buildInfoRowPDF('Data de Elaboração', apr.dataElaboracao != null ? dateFormat.format(apr.dataElaboracao!) : '-'),
          _buildInfoRowPDF('Responsável', apr.responsavelElaboracao ?? '-'),
          _buildInfoRowPDF('Aprovador', apr.aprovador ?? '-'),
        ]),
        pw.SizedBox(height: 16),
        _buildSectionPDF('Dados da Atividade', [
          _buildInfoRowPDF('Atividade', apr.atividade ?? '-'),
          _buildInfoRowPDF('Local de Execução', apr.localExecucao ?? '-'),
          _buildInfoRowPDF('Data de Execução', apr.dataExecucao != null ? dateFormat.format(apr.dataExecucao!) : '-'),
          _buildInfoRowPDF('Equipe Executora', apr.equipeExecutora ?? '-'),
        ]),
        pw.SizedBox(height: 16),
        _buildSectionPDF('Análise de Riscos', [
          pw.Text(apr.riscosIdentificados ?? '-'),
        ]),
        pw.SizedBox(height: 16),
        _buildSectionPDF('Medidas de Controle', [
          pw.Text(apr.medidasControle ?? '-'),
        ]),
        pw.SizedBox(height: 16),
        _buildSectionPDF('EPIs e Permissões', [
          _buildInfoRowPDF('EPIs Necessários', apr.episNecessarios ?? '-'),
          _buildInfoRowPDF('Permissões Necessárias', apr.permissoesNecessarias ?? '-'),
          _buildInfoRowPDF('Autorizações Necessárias', apr.autorizacoesNecessarias ?? '-'),
        ]),
        pw.SizedBox(height: 16),
        _buildSectionPDF('Procedimentos de Emergência', [
          pw.Text(apr.procedimentosEmergencia ?? '-'),
        ]),
      ],
    );
  }

  // Gerar PDF do CRC
  Future<Uint8List> generateCRCPDF(CRC crc, Task task) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text(
                'CRC - Controle de Pontos Críticos',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 20),
            _buildCRCContent(crc, dateFormat),
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildCRCContent(CRC crc, DateFormat dateFormat) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionPDF('Informações Gerais', [
          _buildInfoRowPDF('Número CRC', crc.numeroCrc ?? '-'),
          _buildInfoRowPDF('Data de Elaboração', crc.dataElaboracao != null ? dateFormat.format(crc.dataElaboracao!) : '-'),
          _buildInfoRowPDF('Responsável', crc.responsavelElaboracao ?? '-'),
          _buildInfoRowPDF('Aprovador', crc.aprovador ?? '-'),
        ]),
        pw.SizedBox(height: 16),
        _buildSectionPDF('Dados da Atividade', [
          _buildInfoRowPDF('Atividade', crc.atividade ?? '-'),
          _buildInfoRowPDF('Local de Execução', crc.localExecucao ?? '-'),
          _buildInfoRowPDF('Data de Execução', crc.dataExecucao != null ? dateFormat.format(crc.dataExecucao!) : '-'),
        ]),
        pw.SizedBox(height: 16),
        _buildSectionPDF('Pontos Críticos', [
          pw.Text(crc.pontosCriticos ?? '-'),
        ]),
        pw.SizedBox(height: 16),
        _buildSectionPDF('Controles', [
          pw.Text(crc.controles ?? '-'),
        ]),
        pw.SizedBox(height: 16),
        _buildSectionPDF('Verificações', [
          pw.Text(crc.verificacoes ?? '-'),
        ]),
        pw.SizedBox(height: 16),
        _buildSectionPDF('Responsáveis', [
          _buildInfoRowPDF('Responsáveis pela Verificação', crc.responsaveisVerificacao ?? '-'),
        ]),
      ],
    );
  }

  pw.Widget _buildSectionPDF(String title, List<pw.Widget> children) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  pw.Widget _buildInfoRowPDF(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 200,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(
            child: pw.Text(value),
          ),
        ],
      ),
    );
  }
}
