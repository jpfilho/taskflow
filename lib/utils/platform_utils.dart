import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

String _sanitize(String value) {
  return value
      .replaceAll('—', '-')
      .replaceAll('–', '-')
      .replaceAll('‐', '-')
      .replaceAll('−', '-');
}

Future<void> printReport({
  required String title,
  required String period,
  required String emission,
  required List<String> notasHeaders,
  required List<List<String>> notasData,
  required List<String> ordensHeaders,
  required List<List<String>> ordensData,
}) async {
  final cleanTitle = _sanitize(title);
  final cleanPeriod = _sanitize(period);
  final cleanEmission = _sanitize(emission);
  final cleanNotasHeaders = notasHeaders.map(_sanitize).toList();
  final cleanNotasData = notasData.map((row) => row.map(_sanitize).toList()).toList();
  final cleanOrdensHeaders = ordensHeaders.map(_sanitize).toList();
  final cleanOrdensData = ordensData.map((row) => row.map(_sanitize).toList()).toList();

  final pdf = pw.Document();

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(20),
      maxPages: 1000,
      build: (pw.Context context) {
        return [
          // Cabeçalho do Relatório
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'RELATÓRIO DE ATIVIDADES PROGRAMADAS',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: const PdfColor.fromInt(0xFF2C3E50),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Período: $cleanPeriod',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColor.fromInt(0xFF555555),
                    ),
                  ),
                ],
              ),
              pw.Text(
                'Emissão: $cleanEmission',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColor.fromInt(0xFF888888),
                ),
              ),
            ],
          ),
          pw.Divider(thickness: 1.5, color: const PdfColor.fromInt(0xFF333333)),
          pw.SizedBox(height: 10),

          // Seção de Notas SAP
          pw.Text(
            'NOTAS SAP PROGRAMADAS NO PERÍODO (${cleanNotasData.length} registros)',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFF3F51B5),
            ),
          ),
          pw.SizedBox(height: 6),
          if (cleanNotasData.isEmpty)
            pw.Text(
              'Nenhuma nota SAP vinculada às atividades do período.',
              style: const pw.TextStyle(
                fontSize: 8,
                color: PdfColor.fromInt(0xFF888888),
              ),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: cleanNotasHeaders,
              data: cleanNotasData,
              border: pw.TableBorder.all(
                color: const PdfColor.fromInt(0xFFCCCCCC),
                width: 0.3,
              ),
              headerStyle: pw.TextStyle(
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              cellStyle: const pw.TextStyle(
                fontSize: 6.5,
                color: PdfColors.black,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF3F51B5),
              ),
              rowDecoration: const pw.BoxDecoration(
                color: PdfColors.white,
              ),
              oddRowDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF9F9F9),
              ),
              columnWidths: const {
                0: pw.FixedColumnWidth(16),  // #
                1: pw.FixedColumnWidth(38),  // Nota
                2: pw.FixedColumnWidth(20),  // Tipo
                3: pw.FlexColumnWidth(1.6),  // Descrição
                4: pw.FlexColumnWidth(1.3),  // Local Instalação
                5: pw.FixedColumnWidth(30),  // Sala
                6: pw.FixedColumnWidth(40),  // Prioridade
                7: pw.FlexColumnWidth(1.1),  // Status Nota
                8: pw.FlexColumnWidth(1.6),  // Atividade
                9: pw.FixedColumnWidth(40),  // Status Ativ.
                10: pw.FlexColumnWidth(1.3), // Executor(es)
                11: pw.FlexColumnWidth(1.1), // Coordenador
                12: pw.FixedColumnWidth(35), // Início
                13: pw.FixedColumnWidth(35), // Fim
                14: pw.FixedColumnWidth(65), // Observação
              },
            ),

          pw.SizedBox(height: 20),

          // Seção de Ordens SAP
          pw.Text(
            'ORDENS SAP PROGRAMADAS NO PERÍODO (${cleanOrdensData.length} registros)',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFF009688),
            ),
          ),
          pw.SizedBox(height: 6),
          if (cleanOrdensData.isEmpty)
            pw.Text(
              'Nenhuma ordem SAP vinculada às atividades do período.',
              style: const pw.TextStyle(
                fontSize: 8,
                color: PdfColor.fromInt(0xFF888888),
              ),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: cleanOrdensHeaders,
              data: cleanOrdensData,
              border: pw.TableBorder.all(
                color: const PdfColor.fromInt(0xFFCCCCCC),
                width: 0.3,
              ),
              headerStyle: pw.TextStyle(
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              cellStyle: const pw.TextStyle(
                fontSize: 6.5,
                color: PdfColors.black,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF009688),
              ),
              rowDecoration: const pw.BoxDecoration(
                color: PdfColors.white,
              ),
              oddRowDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF9F9F9),
              ),
              columnWidths: const {
                0: pw.FixedColumnWidth(16),  // #
                1: pw.FixedColumnWidth(40),  // Ordem
                2: pw.FixedColumnWidth(22),  // Tipo
                3: pw.FlexColumnWidth(1.6),  // Texto Breve
                4: pw.FlexColumnWidth(1.3),  // Local Instalação
                5: pw.FixedColumnWidth(30),  // Sala
                6: pw.FlexColumnWidth(1.3),  // Status Sistema
                7: pw.FixedColumnWidth(25),  // GPM
                8: pw.FlexColumnWidth(1.6),  // Atividade
                9: pw.FlexColumnWidth(1.4),  // Executor(es)
                10: pw.FlexColumnWidth(1.1), // Coordenador
                11: pw.FixedColumnWidth(35), // Início
                12: pw.FixedColumnWidth(35), // Fim
                13: pw.FixedColumnWidth(65), // Observação
              },
            ),

          pw.SizedBox(height: 15),
          pw.Divider(thickness: 0.5, color: const PdfColor.fromInt(0xFFCCCCCC)),
          pw.Text(
            'Gerado pelo sistema TaskFlow · $cleanEmission',
            style: const pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFF999999)),
          ),
        ];
      },
    ),
  );

  await Printing.layoutPdf(
    onLayout: (PdfPageFormat format) async => pdf.save(),
    name: cleanTitle,
  );
}
