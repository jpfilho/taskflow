import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/models/nota_sap_analise.dart';
import 'package:task2026/models/nota_sap_anotacao.dart';
import 'package:task2026/services/nota_anotacao_rasterizer_service.dart';
import 'package:task2026/services/nota_sap_analise_service.dart';

/// Mock do rasterizador para testes rápidos de serviço sem overhead gráfico
class MockRasterizerService extends Fake implements NotaAnotacaoRasterizerService {
  int chamadasRasterizar = 0;
  Uint8List bytesRetorno = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]); // PNG header

  @override
  Future<Uint8List> rasterizarParaPng({
    required Uint8List imagemBytes,
    required NotaSapAnotacaoDocumento documento,
    dynamic overrideDimensoes,
  }) async {
    chamadasRasterizar++;
    return bytesRetorno;
  }
}

/// Mock do NotaSapAnaliseService para testar a lógica de orquestração de derivadas
class MockNotaSapAnaliseServiceParaDerivadas extends Fake implements NotaSapAnaliseService {
  final Map<String, Uint8List> storageSimulado = {};
  final Map<String, NotaSapAnexo> bancoAnexos = {};
  final Map<String, List<NotaSapAnotacao>> bancoAnotacoes = {};
  final List<String> falhasLimpezaStorage = [];

  bool simularFalhaBancoAposUpload = false;
  bool simularFalhaStorageRemove = false;

  @override
  Future<ResultadoGeracaoDerivada> gerarERegistrarDerivada({
    required NotaSapAnexo anexoOriginal,
    required NotaSapAnotacao anotacao,
    required Uint8List imagemOriginalBytes,
    NotaAnotacaoRasterizerService rasterizer = const NotaAnotacaoRasterizerService(),
  }) async {
    try {
      // 1. Rasterizar
      final pngBytes = await rasterizer.rasterizarParaPng(
        imagemBytes: imagemOriginalBytes,
        documento: anotacao.dadosJson,
      );

      // 2. Path determinístico sem timestamp
      final caminhoStorage =
          '${anexoOriginal.notaSapId}/derived/${anexoOriginal.id}/v${anotacao.versao}.png';
      const bucketDestino = 'notas-sap-anexos';

      final jaExistiaAntes = storageSimulado.containsKey(caminhoStorage);

      // 3. Upload no Storage
      storageSimulado[caminhoStorage] = pngBytes;

      // 4. Simulação de falha de banco após upload
      if (simularFalhaBancoAposUpload) {
        if (!jaExistiaAntes) {
          // Rollback: remove do Storage o arquivo recém-criado
          storageSimulado.remove(caminhoStorage);
        }
        return const ResultadoGeracaoDerivada(
          sucesso: false,
          erro: 'Simulação de erro na gravação do registro derivado no banco.',
        );
      }

      // 5. Inserir/Atualizar metadados no banco
      final nomeBase = anexoOriginal.nomeArquivo.contains('.')
          ? anexoOriginal.nomeArquivo.substring(0, anexoOriginal.nomeArquivo.lastIndexOf('.'))
          : anexoOriginal.nomeArquivo;
      final nomeDerivado = '${nomeBase}_anotada_v${anotacao.versao}.png';

      final derivadaId = 'deriv_${anexoOriginal.id}_v${anotacao.versao}';
      final anexoDerivado = NotaSapAnexo(
        id: derivadaId,
        notaSapId: anexoOriginal.notaSapId,
        anexoDerivadoDeId: anexoOriginal.id,
        nomeArquivo: nomeDerivado,
        nomeOriginal: nomeDerivado,
        tipoArquivo: NotaAnexoTipo.imagem,
        caminhoArquivo: caminhoStorage,
        bucket: bucketDestino,
        tamanhoBytes: pngBytes.length,
        mimeType: 'image/png',
        extensao: 'png',
        origem: 'TASKFLOW',
        sha256: 'mock_sha256_v${anotacao.versao}',
        relevanteAnalise: false,
      );

      bancoAnexos[derivadaId] = anexoDerivado;

      return ResultadoGeracaoDerivada(
        sucesso: true,
        anexoDerivado: anexoDerivado,
        pngBytes: pngBytes,
        sha256: 'mock_sha256_v${anotacao.versao}',
      );
    } catch (e) {
      return ResultadoGeracaoDerivada(
        sucesso: false,
        erro: e.toString(),
      );
    }
  }

  @override
  Future<NotaSapAnexo?> obterDerivadaDaVersao(String anexoOriginalId, int versao) async {
    final sufixo = '/v$versao.png';
    for (final d in bancoAnexos.values) {
      if (d.anexoDerivadoDeId == anexoOriginalId && d.caminhoArquivo.endsWith(sufixo)) {
        return d;
      }
    }
    return null;
  }

  @override
  Future<Map<String, int>> obterContagemEvidenciasVinculadas(String anexoOriginalId) async {
    final anotacoes = bancoAnotacoes[anexoOriginalId]?.length ?? 0;
    final derivadas = bancoAnexos.values
        .where((d) => d.anexoDerivadoDeId == anexoOriginalId)
        .length;
    return {'anotacoes': anotacoes, 'derivadas': derivadas};
  }

  @override
  Future<void> excluirAnexo(NotaSapAnexo anexo) async {
    if (anexo.id == null) return;

    // 1. Localizar derivadas
    final derivadas = bancoAnexos.values
        .where((d) => d.anexoDerivadoDeId == anexo.id)
        .toList();

    for (final d in derivadas) {
      if (simularFalhaStorageRemove) {
        falhasLimpezaStorage.add(d.caminhoArquivo);
      } else {
        storageSimulado.remove(d.caminhoArquivo);
      }
      bancoAnexos.remove(d.id);
    }

    // 2. Limpar o original
    storageSimulado.remove(anexo.caminhoArquivo);
    bancoAnexos.remove(anexo.id);
    bancoAnotacoes.remove(anexo.id);

    if (falhasLimpezaStorage.isNotEmpty) {
      throw Exception('Exclusão parcial: falha ao remover ${falhasLimpezaStorage.length} derivada(s) do Storage.');
    }
  }
}

void main() {
  late MockNotaSapAnaliseServiceParaDerivadas mockService;
  late MockRasterizerService mockRasterizer;

  setUp(() {
    mockService = MockNotaSapAnaliseServiceParaDerivadas();
    mockRasterizer = MockRasterizerService();
  });

  group('Fase 3.1: Ciclo de Evidências Derivadas, Idempotência e Exclusão Segura', () {
    final original = const NotaSapAnexo(
      id: 'anexo_orig_1',
      notaSapId: 'nota_sap_999',
      nomeArquivo: 'transformador_fase_a.jpg',
      tipoArquivo: NotaAnexoTipo.imagem,
      caminhoArquivo: 'nota_sap_999/transformador_fase_a.jpg',
      tamanhoBytes: 500000,
    );

    final anotacaoV1 = NotaSapAnotacao(
      id: 'anot_1',
      anexoId: 'anexo_orig_1',
      versao: 1,
      dadosJson: const NotaSapAnotacaoDocumento(
        canvasWidth: 1920,
        canvasHeight: 1080,
        elements: [
          NotaSapAnotacaoElemento(
            id: 'e1',
            type: NotaSapElementoTipo.rect,
            x1: 0.1,
            y1: 0.1,
            x2: 0.3,
            y2: 0.3,
          ),
        ],
      ),
      createdAt: DateTime.now(),
    );

    test('1. Ciclo completo: JSON v1 -> PNG v1 -> Storage determinístico -> Registro Derivado', () async {
      final res = await mockService.gerarERegistrarDerivada(
        anexoOriginal: original,
        anotacao: anotacaoV1,
        imagemOriginalBytes: Uint8List(10),
        rasterizer: mockRasterizer,
      );

      expect(res.sucesso, isTrue);
      expect(res.anexoDerivado, isNotNull);
      expect(res.anexoDerivado!.anexoDerivadoDeId, 'anexo_orig_1');
      expect(res.anexoDerivado!.nomeArquivo, 'transformador_fase_a_anotada_v1.png');
      expect(res.anexoDerivado!.caminhoArquivo, 'nota_sap_999/derived/anexo_orig_1/v1.png');
      expect(res.anexoDerivado!.origem, 'TASKFLOW');
      expect(res.anexoDerivado!.relevanteAnalise, isFalse);

      // Objeto existe no Storage
      expect(mockService.storageSimulado.containsKey('nota_sap_999/derived/anexo_orig_1/v1.png'), isTrue);

      // Consulta de derivada por versão
      final buscada = await mockService.obterDerivadaDaVersao('anexo_orig_1', 1);
      expect(buscada, isNotNull);
      expect(buscada!.id, res.anexoDerivado!.id);
    });

    test('2. Path determinístico: sem timestamp e previsível para mesma versão', () async {
      final res = await mockService.gerarERegistrarDerivada(
        anexoOriginal: original,
        anotacao: anotacaoV1,
        imagemOriginalBytes: Uint8List(10),
        rasterizer: mockRasterizer,
      );

      expect(res.anexoDerivado!.caminhoArquivo, 'nota_sap_999/derived/anexo_orig_1/v1.png');
      expect(res.anexoDerivado!.caminhoArquivo.contains('timestamp'), isFalse);
    });

    test('3. Idempotência: Mesma versão gerada novamente atualiza registro sem duplicar', () async {
      // Primeira geração
      await mockService.gerarERegistrarDerivada(
        anexoOriginal: original,
        anotacao: anotacaoV1,
        imagemOriginalBytes: Uint8List(10),
        rasterizer: mockRasterizer,
      );
      expect(mockService.bancoAnexos.length, 1);

      // Segunda geração da mesma versão v1
      final res2 = await mockService.gerarERegistrarDerivada(
        anexoOriginal: original,
        anotacao: anotacaoV1,
        imagemOriginalBytes: Uint8List(10),
        rasterizer: mockRasterizer,
      );

      expect(res2.sucesso, isTrue);
      // Não duplicou no banco
      expect(mockService.bancoAnexos.length, 1);
      // Não duplicou no storage com arquivos como v1_2.png
      expect(mockService.storageSimulado.length, 1);
    });

    test('4. Rollback seguro: Falha de banco após upload remove arquivo novo do Storage; se já existia, preserva', () async {
      // Caso A: Arquivo novo. Falha no banco deve remover o upload recém-feito
      mockService.simularFalhaBancoAposUpload = true;
      final resFalha = await mockService.gerarERegistrarDerivada(
        anexoOriginal: original,
        anotacao: anotacaoV1,
        imagemOriginalBytes: Uint8List(10),
        rasterizer: mockRasterizer,
      );

      expect(resFalha.sucesso, isFalse);
      expect(resFalha.erro, contains('Simulação de erro'));
      // Storage limpo pelo rollback
      expect(mockService.storageSimulado.containsKey('nota_sap_999/derived/anexo_orig_1/v1.png'), isFalse);

      // Caso B: Arquivo já existia antes. Falha no banco não apaga o arquivo pré-existente
      mockService.simularFalhaBancoAposUpload = false;
      await mockService.gerarERegistrarDerivada(
        anexoOriginal: original,
        anotacao: anotacaoV1,
        imagemOriginalBytes: Uint8List(10),
        rasterizer: mockRasterizer,
      );
      expect(mockService.storageSimulado.containsKey('nota_sap_999/derived/anexo_orig_1/v1.png'), isTrue);

      // Agora simula falha ao regerar: o arquivo anterior não pode ser excluído
      mockService.simularFalhaBancoAposUpload = true;
      await mockService.gerarERegistrarDerivada(
        anexoOriginal: original,
        anotacao: anotacaoV1,
        imagemOriginalBytes: Uint8List(10),
        rasterizer: mockRasterizer,
      );
      // Arquivo pré-existente foi preservado
      expect(mockService.storageSimulado.containsKey('nota_sap_999/derived/anexo_orig_1/v1.png'), isTrue);
    });

    test('5. Exclusão em cascata: Excluir original remove derivadas do Storage e banco (0 órfãos)', () async {
      // 1. Cadastra original e gera v1 e v2
      mockService.bancoAnexos[original.id!] = original;
      mockService.storageSimulado[original.caminhoArquivo] = Uint8List(50);

      final anotacaoV2 = NotaSapAnotacao(
        id: 'anot_2',
        anexoId: 'anexo_orig_1',
        versao: 2,
        dadosJson: const NotaSapAnotacaoDocumento(
          canvasWidth: 1920,
          canvasHeight: 1080,
          elements: [],
        ),
        createdAt: DateTime.now(),
      );

      await mockService.gerarERegistrarDerivada(
        anexoOriginal: original,
        anotacao: anotacaoV1,
        imagemOriginalBytes: Uint8List(10),
        rasterizer: mockRasterizer,
      );
      await mockService.gerarERegistrarDerivada(
        anexoOriginal: original,
        anotacao: anotacaoV2,
        imagemOriginalBytes: Uint8List(10),
        rasterizer: mockRasterizer,
      );

      // Antes da exclusão: contagem vinculada
      final vinculados = await mockService.obterContagemEvidenciasVinculadas('anexo_orig_1');
      expect(vinculados['derivadas'], 2);

      // Executa exclusão do original
      await mockService.excluirAnexo(original);

      // Verificação: 0 registros no banco, 0 arquivos no Storage
      expect(mockService.bancoAnexos.isEmpty, isTrue);
      expect(mockService.storageSimulado.isEmpty, isTrue);
    });

    test('6. Simulação de falha na limpeza do Storage acusa exclusão parcial para retry', () async {
      mockService.bancoAnexos[original.id!] = original;
      mockService.storageSimulado[original.caminhoArquivo] = Uint8List(50);

      await mockService.gerarERegistrarDerivada(
        anexoOriginal: original,
        anotacao: anotacaoV1,
        imagemOriginalBytes: Uint8List(10),
        rasterizer: mockRasterizer,
      );

      // Ativa falha simulada no storage remove
      mockService.simularFalhaStorageRemove = true;

      expect(
        () => mockService.excluirAnexo(original),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'mensagem',
          contains('Exclusão parcial'),
        )),
      );

      expect(mockService.falhasLimpezaStorage.length, 1);
    });
  });
}
