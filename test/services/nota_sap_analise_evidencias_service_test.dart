import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/models/nota_sap_analise.dart';
import 'package:task2026/models/nota_sap_analise_evidencia.dart';
import 'package:task2026/models/nota_sap_anotacao.dart';
import 'package:task2026/services/nota_sap_analise_service.dart';

/// Mock do NotaSapAnaliseService para teste das regras de domínio da Fase 4
class MockNotaSapAnaliseServiceEvidencias extends Fake implements NotaSapAnaliseService {
  final Map<String, NotaSapAnexo> bancoAnexos = {};
  final Map<String, List<NotaSapAnotacao>> bancoAnotacoes = {};
  final List<NotaSapAnaliseEvidencia> bancoEvidencias = [];
  final Map<String, NotaSapAnalise> bancoAnalises = {};

  @override
  Future<NotaSapAnaliseEvidencia> vincularEvidencia({
    required String notaSapId,
    String? anexoId,
    String? mediaImageId,
    NotaEvidenciaTipoFonte? tipoFonte,
    required NotaTipoVinculoEvidencia tipoVinculo,
    int? anotacaoVersao,
    String? observacao,
    int ordem = 0,
    String? criadoPor,
    String? criadoPorNome,
  }) async {
    final fonteReal = tipoFonte ??
        (mediaImageId != null
            ? NotaEvidenciaTipoFonte.fotoAlbum
            : NotaEvidenciaTipoFonte.anexoNota);

    if (fonteReal == NotaEvidenciaTipoFonte.anexoNota) {
      if (anexoId == null) {
        throw Exception('anexoId é obrigatório para tipo_fonte = anexo_nota');
      }
      // 1. Validação de anexo existente
      final anexo = bancoAnexos[anexoId];
      if (anexo == null) {
        throw Exception('Anexo não encontrado para vincular à evidência.');
      }

      // 2. Validação de mesma Nota SAP
      if (anexo.notaSapId != notaSapId) {
        throw Exception('O anexo não pertence à mesma Nota SAP indicada.');
      }

      // 3. Validação de originalidade (rejeita derivada)
      if (anexo.isDerivado || anexo.anexoDerivadoDeId != null) {
        throw Exception('A evidência deve referenciar o anexo original.');
      }

      // 4. Validação de integridade de versão (FK composta)
      if (anotacaoVersao != null) {
        final anotacoesDoAnexo = bancoAnotacoes[anexoId] ?? [];
        final versaoExiste = anotacoesDoAnexo.any((a) => a.versao == anotacaoVersao);
        if (!versaoExiste) {
          throw Exception(
            'Versão de anotação v$anotacaoVersao não encontrada para o anexo $anexoId.',
          );
        }
      }
    } else {
      if (mediaImageId == null) {
        throw Exception('mediaImageId é obrigatório para tipo_fonte = foto_album');
      }
      if (anotacaoVersao != null) {
        throw Exception('Fotografia do álbum não suporta versão de anotação de anexo.');
      }
    }

    // 5. Upsert respeitando UNIQUE parcial
    final index = bancoEvidencias.indexWhere(
      (e) =>
          e.notaSapId == notaSapId &&
          e.tipoFonte == fonteReal &&
          ((fonteReal == NotaEvidenciaTipoFonte.anexoNota && e.anexoId == anexoId) ||
           (fonteReal == NotaEvidenciaTipoFonte.fotoAlbum && e.mediaImageId == mediaImageId)) &&
          e.tipoVinculo == tipoVinculo,
    );

    final agora = DateTime.now();
    final registro = NotaSapAnaliseEvidencia(
      id: index != -1 ? bancoEvidencias[index].id : 'ev-${bancoEvidencias.length + 1}',
      notaSapId: notaSapId,
      tipoFonte: fonteReal,
      anexoId: anexoId,
      mediaImageId: mediaImageId,
      tipoVinculo: tipoVinculo,
      anotacaoVersao: anotacaoVersao,
      observacao: observacao,
      ordem: ordem,
      criadoPor: criadoPor,
      criadoPorNome: criadoPorNome,
      createdAt: index != -1 ? bancoEvidencias[index].createdAt : agora,
      updatedAt: agora,
      anexo: anexoId != null ? bancoAnexos[anexoId] : null,
    );

    if (index != -1) {
      bancoEvidencias[index] = registro;
    } else {
      bancoEvidencias.add(registro);
    }

    return registro;
  }

  @override
  Future<void> desvincularEvidencia({
    required String notaSapId,
    String? anexoId,
    String? mediaImageId,
    NotaEvidenciaTipoFonte? tipoFonte,
    required NotaTipoVinculoEvidencia tipoVinculo,
  }) async {
    bancoEvidencias.removeWhere(
      (e) =>
          e.notaSapId == notaSapId &&
          e.tipoVinculo == tipoVinculo &&
          ((anexoId != null && e.anexoId == anexoId) ||
           (mediaImageId != null && e.mediaImageId == mediaImageId)),
    );
  }

  @override
  Future<void> atualizarVersaoVinculada({
    required String evidenciaId,
    required String anexoId,
    required int? novaVersao,
  }) async {
    final index = bancoEvidencias.indexWhere((e) => e.id == evidenciaId);
    if (index == -1) {
      throw Exception('Vínculo de evidência não encontrado.');
    }

    // Validação da versão
    if (novaVersao != null) {
      final anotacoesDoAnexo = bancoAnotacoes[anexoId] ?? [];
      final versaoExiste = anotacoesDoAnexo.any((a) => a.versao == novaVersao);
      if (!versaoExiste) {
        throw Exception('Versão v$novaVersao não encontrada para o anexo.');
      }
    }

    final atual = bancoEvidencias[index];
    bancoEvidencias[index] = atual.copyWith(
      anotacaoVersao: novaVersao,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> atualizarObservacaoVinculo({
    required String evidenciaId,
    required String? observacao,
  }) async {
    final index = bancoEvidencias.indexWhere((e) => e.id == evidenciaId);
    if (index == -1) {
      throw Exception('Vínculo de evidência não encontrado.');
    }

    final atual = bancoEvidencias[index];
    bancoEvidencias[index] = atual.copyWith(
      observacao: observacao,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<List<NotaSapAnaliseEvidencia>> listarEvidenciasDaNota(
    String notaSapId,
  ) async {
    final vinculos = bancoEvidencias
        .where((e) => e.notaSapId == notaSapId)
        .toList();

    return vinculos.map((v) {
      final anexo = v.anexoId != null ? bancoAnexos[v.anexoId] : null;
      final anotacoes = v.anexoId != null ? (bancoAnotacoes[v.anexoId] ?? []) : <NotaSapAnotacao>[];
      final maxVersao = anotacoes.isEmpty
          ? null
          : anotacoes.map((a) => a.versao).reduce((a, b) => a > b ? a : b);

      return v.copyWith(
        anexo: anexo,
        versaoMaisRecenteAnexo: maxVersao,
      );
    }).toList();
  }

  @override
  Future<Map<String, List<NotaTipoVinculoEvidencia>>> buscarUsoDosAnexos(
    String notaSapId,
  ) async {
    final vinculos = bancoEvidencias
        .where((e) => e.notaSapId == notaSapId && e.anexoId != null)
        .toList();

    final mapa = <String, Set<NotaTipoVinculoEvidencia>>{};
    for (final v in vinculos) {
      if (v.anexoId != null) {
        mapa.putIfAbsent(v.anexoId!, () => <NotaTipoVinculoEvidencia>{}).add(v.tipoVinculo);
      }
    }

    return mapa.map((k, v) => MapEntry(k, v.toList()));
  }

  @override
  Future<int> contarAnexosUsadosNaAnalise(String notaSapId) async {
    final usos = await buscarUsoDosAnexos(notaSapId);
    return usos.keys.length; // DISTINCT anexo_id
  }
}

void main() {
  group('Fase 4: Integração de Evidências com Análise Técnica da Nota SAP', () {
    late MockNotaSapAnaliseServiceEvidencias service;
    const notaId = 'nota-uuid-1000';
    const anexoFotoAId = 'anexo-uuid-foto-a';
    const anexoFotoBId = 'anexo-uuid-foto-b';
    const anexoPdfId = 'anexo-uuid-manual-pdf';
    const anexoDerivadoId = 'anexo-uuid-derivado-png';

    setUp(() {
      service = MockNotaSapAnaliseServiceEvidencias();

      // Cadastra anexos de teste
      service.bancoAnexos[anexoFotoAId] = const NotaSapAnexo(
        id: anexoFotoAId,
        notaSapId: notaId,
        nomeArquivo: 'foto_poste_a.jpg',
        caminhoArquivo: '$notaId/foto_poste_a.jpg',
        tamanhoBytes: 1024,
        tipoArquivo: NotaAnexoTipo.imagem,
      );

      service.bancoAnexos[anexoFotoBId] = const NotaSapAnexo(
        id: anexoFotoBId,
        notaSapId: notaId,
        nomeArquivo: 'foto_transformador_b.jpg',
        caminhoArquivo: '$notaId/foto_transformador_b.jpg',
        tamanhoBytes: 2048,
        tipoArquivo: NotaAnexoTipo.imagem,
      );

      service.bancoAnexos[anexoPdfId] = const NotaSapAnexo(
        id: anexoPdfId,
        notaSapId: notaId,
        nomeArquivo: 'manual_fabricante.pdf',
        caminhoArquivo: '$notaId/manual_fabricante.pdf',
        tamanhoBytes: 4096,
        tipoArquivo: NotaAnexoTipo.documento,
      );

      service.bancoAnexos[anexoDerivadoId] = const NotaSapAnexo(
        id: anexoDerivadoId,
        notaSapId: notaId,
        nomeArquivo: 'foto_poste_a_v2.png',
        caminhoArquivo: '$notaId/derived/$anexoFotoAId/v2.png',
        tamanhoBytes: 1024,
        tipoArquivo: NotaAnexoTipo.imagem,
        anexoDerivadoDeId: anexoFotoAId, // É DERIVADA!
      );

      // Cadastra anotações (versões) para Foto A (v1, v2)
      service.bancoAnotacoes[anexoFotoAId] = [
        NotaSapAnotacao(
          id: 'annot-1',
          anexoId: anexoFotoAId,
          versao: 1,
          dadosJson: const NotaSapAnotacaoDocumento(canvasWidth: 1920, canvasHeight: 1080, elements: []),
          createdAt: DateTime.now(),
        ),
        NotaSapAnotacao(
          id: 'annot-2',
          anexoId: anexoFotoAId,
          versao: 2,
          dadosJson: const NotaSapAnotacaoDocumento(canvasWidth: 1920, canvasHeight: 1080, elements: []),
          createdAt: DateTime.now(),
        ),
      ];

      // Foto B não tem anotações ainda
      service.bancoAnotacoes[anexoFotoBId] = [];
    });

    test('1. Vínculo de anexo original sem anotação (anotacao_versao == null)', () async {
      final ev = await service.vincularEvidencia(
        notaSapId: notaId,
        anexoId: anexoFotoAId,
        tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
        anotacaoVersao: null,
      );

      expect(ev.anotacaoVersao, isNull);
      expect(ev.isOriginalSemAnotacao, isTrue);
      expect(ev.rotuloVersao, equals('Original'));
    });

    test('2. Vínculo com versão de anotação específica existente (v2)', () async {
      final ev = await service.vincularEvidencia(
        notaSapId: notaId,
        anexoId: anexoFotoAId,
        tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
        anotacaoVersao: 2,
      );

      expect(ev.anotacaoVersao, equals(2));
      expect(ev.isComAnotacao, isTrue);
      expect(ev.rotuloVersao, equals('v2'));
    });

    test('3. Vínculo de PDF / Documento sem anotação', () async {
      final ev = await service.vincularEvidencia(
        notaSapId: notaId,
        anexoId: anexoPdfId,
        tipoVinculo: NotaTipoVinculoEvidencia.materiais,
        anotacaoVersao: null,
        observacao: 'Manual técnico de instalação',
      );

      expect(ev.anotacaoVersao, isNull);
      expect(ev.tipoVinculo, equals(NotaTipoVinculoEvidencia.materiais));
      expect(ev.observacao, equals('Manual técnico de instalação'));
    });

    test('4. Mesmo anexo vinculado a múltiplas seções técnicas (diagnóstico e segurança)', () async {
      await service.vincularEvidencia(
        notaSapId: notaId,
        anexoId: anexoFotoAId,
        tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
        anotacaoVersao: 2,
      );

      await service.vincularEvidencia(
        notaSapId: notaId,
        anexoId: anexoFotoAId,
        tipoVinculo: NotaTipoVinculoEvidencia.seguranca,
        anotacaoVersao: null,
      );

      final vinculos = await service.listarEvidenciasDaNota(notaId);
      expect(vinculos.length, equals(2));

      final tipos = vinculos.map((e) => e.tipoVinculo).toSet();
      expect(tipos.contains(NotaTipoVinculoEvidencia.diagnostico), isTrue);
      expect(tipos.contains(NotaTipoVinculoEvidencia.seguranca), isTrue);
    });

    test('5. Observações distintas por seção para o mesmo anexo', () async {
      await service.vincularEvidencia(
        notaSapId: notaId,
        anexoId: anexoFotoAId,
        tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
        observacao: 'Mostra corrosão no terminal',
      );

      await service.vincularEvidencia(
        notaSapId: notaId,
        anexoId: anexoFotoAId,
        tipoVinculo: NotaTipoVinculoEvidencia.seguranca,
        observacao: 'Condutor energizado próximo à área de acesso',
      );

      final vinculos = await service.listarEvidenciasDaNota(notaId);
      final evDiag = vinculos.firstWhere((e) => e.tipoVinculo == NotaTipoVinculoEvidencia.diagnostico);
      final evSeg = vinculos.firstWhere((e) => e.tipoVinculo == NotaTipoVinculoEvidencia.seguranca);

      expect(evDiag.observacao, equals('Mostra corrosão no terminal'));
      expect(evSeg.observacao, equals('Condutor energizado próximo à área de acesso'));
    });

    test('6. Desvincular de uma seção mantendo as outras intactas', () async {
      await service.vincularEvidencia(
        notaSapId: notaId,
        anexoId: anexoFotoAId,
        tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
      );
      await service.vincularEvidencia(
        notaSapId: notaId,
        anexoId: anexoFotoAId,
        tipoVinculo: NotaTipoVinculoEvidencia.seguranca,
      );

      // Desvincula somente segurança
      await service.desvincularEvidencia(
        notaSapId: notaId,
        anexoId: anexoFotoAId,
        tipoVinculo: NotaTipoVinculoEvidencia.seguranca,
      );

      final vinculos = await service.listarEvidenciasDaNota(notaId);
      expect(vinculos.length, equals(1));
      expect(vinculos.first.tipoVinculo, equals(NotaTipoVinculoEvidencia.diagnostico));
    });

    test('7. Vínculo antes de existir registro em notas_sap_analises (sem analise_id)', () async {
      // Confirma que não há análise criada no banco
      expect(service.bancoAnalises.containsKey(notaId), isFalse);

      // Vínculo é permitido com sucesso usando exclusivamente nota_sap_id
      final ev = await service.vincularEvidencia(
        notaSapId: notaId,
        anexoId: anexoFotoAId,
        tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
      );

      expect(ev.notaSapId, equals(notaId));
      expect(service.bancoEvidencias.length, equals(1));
    });

    test('8. Criação posterior da análise técnica mantém evidências visíveis', () async {
      // 1. Vincula evidência antes da análise
      await service.vincularEvidencia(
        notaSapId: notaId,
        anexoId: anexoFotoAId,
        tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
      );

      // 2. Análise é criada posteriormente com o mesmo nota_sap_id
      service.bancoAnalises[notaId] = NotaSapAnalise(
        notaSapId: notaId,
        statusAnalise: NotaAnaliseStatus.emAnalise,
        diagnosticoPrevio: 'Diagnóstico preliminar',
      );

      // 3. Evidências continuam imediatamente associadas e visíveis sem migração
      final evidencias = await service.listarEvidenciasDaNota(notaId);
      expect(evidencias.length, equals(1));
      expect(evidencias.first.anexoId, equals(anexoFotoAId));
    });

    test('9. Rastreabilidade histórica: criação de nova versão v4 mantém o vínculo em v2', () async {
      // Vincula na v2
      await service.vincularEvidencia(
        notaSapId: notaId,
        anexoId: anexoFotoAId,
        tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
        anotacaoVersao: 2,
      );

      // Novas versões v3 e v4 são criadas para Foto A
      service.bancoAnotacoes[anexoFotoAId]!.add(
        NotaSapAnotacao(
          id: 'annot-3',
          anexoId: anexoFotoAId,
          versao: 3,
          dadosJson: const NotaSapAnotacaoDocumento(canvasWidth: 1920, canvasHeight: 1080, elements: []),
          createdAt: DateTime.now(),
        ),
      );
      service.bancoAnotacoes[anexoFotoAId]!.add(
        NotaSapAnotacao(
          id: 'annot-4',
          anexoId: anexoFotoAId,
          versao: 4,
          dadosJson: const NotaSapAnotacaoDocumento(canvasWidth: 1920, canvasHeight: 1080, elements: []),
          createdAt: DateTime.now(),
        ),
      );

      // O vínculo permanece inalterado em v2
      final evidencias = await service.listarEvidenciasDaNota(notaId);
      final ev = evidencias.first;
      expect(ev.anotacaoVersao, equals(2));
      expect(ev.versaoMaisRecenteAnexo, equals(4));
      expect(ev.hasVersaoMaisRecente, isTrue); // Indica que v4 está disponível
    });

    test('10. Atualização explícita de v2 para v4 altera vínculo existente sem duplicar', () async {
      final evCriada = await service.vincularEvidencia(
        notaSapId: notaId,
        anexoId: anexoFotoAId,
        tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
        anotacaoVersao: 2,
      );

      // Adiciona v4
      service.bancoAnotacoes[anexoFotoAId]!.add(
        NotaSapAnotacao(
          id: 'annot-4',
          anexoId: anexoFotoAId,
          versao: 4,
          dadosJson: const NotaSapAnotacaoDocumento(canvasWidth: 1920, canvasHeight: 1080, elements: []),
          createdAt: DateTime.now(),
        ),
      );

      // Executa atualização explícita
      await service.atualizarVersaoVinculada(
        evidenciaId: evCriada.id!,
        anexoId: anexoFotoAId,
        novaVersao: 4,
      );

      final evidencias = await service.listarEvidenciasDaNota(notaId);
      expect(evidencias.length, equals(1)); // Não duplicou
      expect(evidencias.first.anotacaoVersao, equals(4));
      expect(evidencias.first.hasVersaoMaisRecente, isFalse);
    });

    test('11. Rejeição de versão de anotação inexistente (v99)', () async {
      expect(
        () => service.vincularEvidencia(
          notaSapId: notaId,
          anexoId: anexoFotoAId,
          tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
          anotacaoVersao: 99,
        ),
        throwsA(predicate((e) => e.toString().contains('v99 não encontrada'))),
      );
    });

    test('12. Rejeição cross-anexo: versão pertencente a outro anexo é rejeitada', () async {
      // Foto A tem v2, mas Foto B não tem v2
      expect(
        () => service.vincularEvidencia(
          notaSapId: notaId,
          anexoId: anexoFotoBId,
          tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
          anotacaoVersao: 2, // v2 pertence a Foto A!
        ),
        throwsA(predicate((e) => e.toString().contains('v2 não encontrada para o anexo $anexoFotoBId'))),
      );
    });

    test('13. Rejeição de anexo pertencente a outra Nota SAP', () async {
      const outraNotaId = 'nota-uuid-9999';
      service.bancoAnexos['anexo-outra-nota'] = const NotaSapAnexo(
        id: 'anexo-outra-nota',
        notaSapId: outraNotaId,
        nomeArquivo: 'alheio.jpg',
        caminhoArquivo: '$outraNotaId/alheio.jpg',
        tamanhoBytes: 1024,
        tipoArquivo: NotaAnexoTipo.imagem,
      );

      expect(
        () => service.vincularEvidencia(
          notaSapId: notaId,
          anexoId: 'anexo-outra-nota',
          tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
        ),
        throwsA(predicate((e) => e.toString().contains('não pertence à mesma Nota SAP'))),
      );
    });

    test('14. Rejeição de anexo derivado (deve rejeitar PNG derivado e aceitar original)', () async {
      expect(
        () => service.vincularEvidencia(
          notaSapId: notaId,
          anexoId: anexoDerivadoId,
          tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
        ),
        throwsA(predicate((e) => e.toString().contains('A evidência deve referenciar o anexo original'))),
      );
    });

    test('15. Contagem DISTINCT de anexos na análise (mesmo anexo em 2 seções conta 1)', () async {
      // Vincula Foto A a duas seções distintas
      await service.vincularEvidencia(
        notaSapId: notaId,
        anexoId: anexoFotoAId,
        tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
      );
      await service.vincularEvidencia(
        notaSapId: notaId,
        anexoId: anexoFotoAId,
        tipoVinculo: NotaTipoVinculoEvidencia.seguranca,
      );

      // Vincula PDF à seção de materiais
      await service.vincularEvidencia(
        notaSapId: notaId,
        anexoId: anexoPdfId,
        tipoVinculo: NotaTipoVinculoEvidencia.materiais,
      );

      // Total de relações criadas = 3
      expect(service.bancoEvidencias.length, equals(3));

      // Contagem de anexos distintos usados na análise = 2 (Foto A e PDF)
      final contagemDistinta = await service.contarAnexosUsadosNaAnalise(notaId);
      expect(contagemDistinta, equals(2));
    });

    test('16. Filtro DISTINCT de anexos na análise', () async {
      await service.vincularEvidencia(
        notaSapId: notaId,
        anexoId: anexoFotoAId,
        tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
      );
      await service.vincularEvidencia(
        notaSapId: notaId,
        anexoId: anexoFotoAId,
        tipoVinculo: NotaTipoVinculoEvidencia.escopo,
      );

      final usos = await service.buscarUsoDosAnexos(notaId);
      expect(usos.containsKey(anexoFotoAId), isTrue);
      expect(usos.containsKey(anexoFotoBId), isFalse);

      final listaAnexos = [
        service.bancoAnexos[anexoFotoAId]!,
        service.bancoAnexos[anexoFotoBId]!,
      ];

      final anexosNaAnalise = listaAnexos.where((a) => usos.containsKey(a.id)).toList();
      expect(anexosNaAnalise.length, equals(1));
      expect(anexosNaAnalise.first.id, equals(anexoFotoAId));
    });

    test('17. hasVersaoMaisRecente é true quando versao_recente > versao_vinculada', () {
      final ev = NotaSapAnaliseEvidencia(
        id: 'ev-1',
        notaSapId: notaId,
        anexoId: anexoFotoAId,
        tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
        anotacaoVersao: 2,
        versaoMaisRecenteAnexo: 4,
      );

      expect(ev.hasVersaoMaisRecente, isTrue);
    });

    test('18. hasVersaoMaisRecente é false quando vinculado na mais recente ou original', () {
      final evNaMaisRecente = NotaSapAnaliseEvidencia(
        id: 'ev-1',
        notaSapId: notaId,
        anexoId: anexoFotoAId,
        tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
        anotacaoVersao: 4,
        versaoMaisRecenteAnexo: 4,
      );
      expect(evNaMaisRecente.hasVersaoMaisRecente, isFalse);

      final evOriginal = NotaSapAnaliseEvidencia(
        id: 'ev-2',
        notaSapId: notaId,
        anexoId: anexoFotoAId,
        tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
        anotacaoVersao: null,
        versaoMaisRecenteAnexo: 4,
      );
      expect(evOriginal.hasVersaoMaisRecente, isFalse);
    });

    test('19. Idempotência do upsert ao vincular mesma seção (atualiza e não duplica)', () async {
      final ev1 = await service.vincularEvidencia(
        notaSapId: notaId,
        anexoId: anexoFotoAId,
        tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
        observacao: 'Primeira nota',
      );

      final ev2 = await service.vincularEvidencia(
        notaSapId: notaId,
        anexoId: anexoFotoAId,
        tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
        observacao: 'Segunda nota atualizada',
      );

      expect(ev1.id, equals(ev2.id));
      expect(service.bancoEvidencias.length, equals(1));
      expect(service.bancoEvidencias.first.observacao, equals('Segunda nota atualizada'));
    });

    test('20. Princípio não bloqueante: análise pode ser salva com 0 evidências', () {
      // Simula salvamento de análise técnica sem nenhuma evidência vinculada
      final analiseSemEvidencias = NotaSapAnalise(
        notaSapId: notaId,
        statusAnalise: NotaAnaliseStatus.concluida,
        diagnosticoPrevio: 'Diagnóstico confirmado via campo',
        escopoDetalhado: 'Substituição de poste',
      );

      expect(service.bancoEvidencias.isEmpty, isTrue);
      expect(analiseSemEvidencias.statusAnalise, equals(NotaAnaliseStatus.concluida));
      expect(analiseSemEvidencias.diagnosticoPrevio, isNotEmpty);
    });
  });
}
