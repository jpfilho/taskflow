import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/models/nota_sap_analise.dart';
import 'package:task2026/services/nota_sap_analise_service.dart';

void main() {
  group('NotaSapAnaliseService - MIME e nome de download', () {
    test('mimeTypeForFileName retorna MIME correto para docx, xlsx, pptx e pdf', () {
      expect(
        NotaSapAnaliseService.mimeTypeForFileName('relatorio.docx'),
        equals('application/vnd.openxmlformats-officedocument.wordprocessingml.document'),
      );
      expect(
        NotaSapAnaliseService.mimeTypeForFileName('planilha.xlsx'),
        equals('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
      );
      expect(
        NotaSapAnaliseService.mimeTypeForFileName('apresentacao.pptx'),
        equals('application/vnd.openxmlformats-officedocument.presentationml.presentation'),
      );
      expect(
        NotaSapAnaliseService.mimeTypeForFileName('laudo.pdf'),
        equals('application/pdf'),
      );
    });

    test('resolveDownloadFileName preserva ou acrescenta extensão .docx', () {
      final comExt = NotaSapAnexo(
        notaSapId: 'n1',
        nomeArquivo: '123_relatorio.docx',
        nomeOriginal: 'Relatorio Tecnico.docx',
        tipoArquivo: NotaAnexoTipo.documento,
        caminhoArquivo: 'n1/123_relatorio.docx',
        tamanhoBytes: 1024,
        extensao: 'docx',
      );
      expect(NotaSapAnaliseService.resolveDownloadFileName(comExt), equals('Relatorio Tecnico.docx'));

      final semExtNoNome = NotaSapAnexo(
        notaSapId: 'n1',
        nomeArquivo: 'Relatorio Tecnico',
        nomeOriginal: 'Relatorio Tecnico',
        tipoArquivo: NotaAnexoTipo.documento,
        caminhoArquivo: 'n1/123_relatorio.docx',
        tamanhoBytes: 1024,
        extensao: 'docx',
      );
      expect(NotaSapAnaliseService.resolveDownloadFileName(semExtNoNome), equals('Relatorio Tecnico.docx'));
    });
  });
}

