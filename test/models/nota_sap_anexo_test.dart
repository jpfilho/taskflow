import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/models/nota_sap_analise.dart';

void main() {
  group('NotaSapAnexo & NotaAnexoTipo - Model & Retrocompatibilidade', () {
    test('Dedução correta de tipos de anexo por MIME e extensão', () {
      expect(NotaAnexoTipo.deduzir('image/jpeg', 'foto.jpg'), NotaAnexoTipo.imagem);
      expect(NotaAnexoTipo.deduzir('image/png', 'print.png'), NotaAnexoTipo.imagem);
      expect(NotaAnexoTipo.deduzir('application/pdf', 'laudo.pdf'), NotaAnexoTipo.pdf);
      expect(NotaAnexoTipo.deduzir('video/mp4', 'inspecao.mp4'), NotaAnexoTipo.video);
      expect(NotaAnexoTipo.deduzir('audio/mpeg', 'audio.mp3'), NotaAnexoTipo.audio);
      expect(NotaAnexoTipo.deduzir(null, 'tabela.xlsx'), NotaAnexoTipo.planilha);
      expect(NotaAnexoTipo.deduzir(null, 'relatorio.docx'), NotaAnexoTipo.documento);
      expect(NotaAnexoTipo.deduzir('application/zip', 'arquivo.zip'), NotaAnexoTipo.outro);
    });

    test('Retrocompatibilidade: registro antigo sem novos campos assume valores padrão seguros', () {
      final mapaAntigo = <String, dynamic>{
        'id': 'c8a2b53f-1234-4567-89ab-cdef01234567',
        'nota_sap_id': '9f123456-789a-bcde-f012-3456789abcde',
        'nome_arquivo': 'defeito_isolador.jpg',
        'tipo_arquivo': 'imagem',
        'caminho_arquivo': 'notas_sap/9f123456/12345_defeito.jpg',
        'tamanho_bytes': 150000,
        'mime_type': 'image/jpeg',
        'legenda': 'Isolador quebrado',
        'usuario_id': 'user-1',
        'usuario_nome': 'Analista 1',
        'created_at': '2026-05-10T14:30:00Z',
      };

      final anexo = NotaSapAnexo.fromMap(mapaAntigo);

      expect(anexo.id, 'c8a2b53f-1234-4567-89ab-cdef01234567');
      expect(anexo.notaSapId, '9f123456-789a-bcde-f012-3456789abcde');
      expect(anexo.nomeArquivo, 'defeito_isolador.jpg');
      expect(anexo.tipoArquivo, NotaAnexoTipo.imagem);
      expect(anexo.caminhoArquivo, 'notas_sap/9f123456/12345_defeito.jpg');
      // Garante que o bucket padrão legado é 'anexos-tarefas'
      expect(anexo.bucket, 'anexos-tarefas');
      expect(anexo.bucketNome, 'anexos-tarefas');
      // Origem legada segura é 'TASKFLOW'
      expect(anexo.origem, 'TASKFLOW');
      expect(anexo.relevanteAnalise, false);
      expect(anexo.sapDocumentId, isNull);
      expect(anexo.sha256, isNull);
    });

    test('Registro novo importado do SAP serializa e deserializa todos os metadados com fidelidade', () {
      final mapaNovoSap = <String, dynamic>{
        'id': '11111111-2222-3333-4444-555555555555',
        'nota_sap_id': '9f123456-789a-bcde-f012-3456789abcde',
        'nome_arquivo': 'sap_doc_11599101_relatorio.pdf',
        'nome_original': 'Relatório Técnico de Avaria.pdf',
        'tipo_arquivo': 'pdf',
        'caminho_arquivo': '9f123456-789a-bcde-f012-3456789abcde/relatorio.pdf',
        'bucket': 'notas-sap-anexos',
        'tamanho_bytes': 2048500,
        'mime_type': 'application/pdf',
        'extensao': 'pdf',
        'origem': 'SAP',
        'legenda': 'Relatório gerado pelo técnico em campo',
        'sap_document_id': 'BDS_DOC_000987654321',
        'sha256': 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        'metadata': {
          'document_type': 'INS_REPORT',
          'sap_user': 'TECNICO01',
        },
        'created_at': '2026-10-29T10:00:00Z',
        'importado_em': '2026-10-29T10:05:00Z',
        'relevante_analise': true,
      };

      final anexo = NotaSapAnexo.fromMap(mapaNovoSap);

      expect(anexo.nomeExibicao, 'Relatório Técnico de Avaria.pdf');
      expect(anexo.bucketNome, 'notas-sap-anexos');
      expect(anexo.tipoArquivo, NotaAnexoTipo.pdf);
      expect(anexo.origem, 'SAP');
      expect(anexo.sapDocumentId, 'BDS_DOC_000987654321');
      expect(anexo.sha256, 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
      expect(anexo.metadata['document_type'], 'INS_REPORT');
      expect(anexo.relevanteAnalise, true);

      final exportado = anexo.toMap();
      expect(exportado['bucket'], 'notas-sap-anexos');
      expect(exportado['origem'], 'SAP');
      expect(exportado['sap_document_id'], 'BDS_DOC_000987654321');
      expect(exportado['relevante_analise'], true);
    });

    test('NotaSapResumoAnalise calcula agregações de contagem por tipo e relevância', () {
      const resumo = NotaSapResumoAnalise(
        notaSapId: 'nota-123',
        status: NotaAnaliseStatus.emAnalise,
        quantidadeAnexos: 17,
        quantidadeImagens: 8,
        quantidadePdfs: 5,
        quantidadeVideos: 2,
        quantidadeDocumentos: 2,
        quantidadeRelevantes: 3,
      );

      expect(resumo.temAnexos, isTrue);
      expect(resumo.quantidadeAnexos, 17);
      expect(resumo.quantidadeImagens, 8);
      expect(resumo.quantidadePdfs, 5);
      expect(resumo.quantidadeVideos, 2);
      expect(resumo.quantidadeDocumentos, 2);
      expect(resumo.quantidadeRelevantes, 3);
    });
  });
}
