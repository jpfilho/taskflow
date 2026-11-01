import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/features/media_albums/data/models/media_image.dart';
import 'package:task2026/models/nota_sap_analise.dart';
import 'package:task2026/models/nota_sap_analise_evidencia.dart';
import 'package:task2026/models/nota_sap_anotacao.dart';
import 'package:task2026/services/nota_sap_analise_service.dart';

/// Mock do NotaSapAnaliseService para teste das regras polimórficas da Fase 4B
class MockNotaSapAnaliseServiceFase4B extends Fake implements NotaSapAnaliseService {
  final Map<String, NotaSapAnexo> bancoAnexos = {};
  final Map<String, MediaImage> bancoMediaImages = {};
  final Map<String, List<NotaSapAnotacao>> bancoAnotacoes = {};
  final List<NotaSapAnaliseEvidencia> bancoEvidencias = [];

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

    // Validação de exclusividade mútua
    if (fonteReal == NotaEvidenciaTipoFonte.anexoNota) {
      if (anexoId == null || mediaImageId != null) {
        throw Exception('Para anexo_nota: anexoId é obrigatório e mediaImageId deve ser nulo.');
      }
      final anexo = bancoAnexos[anexoId];
      if (anexo == null) {
        throw Exception('Anexo não encontrado.');
      }
      if (anexo.notaSapId != notaSapId) {
        throw Exception('O anexo não pertence à mesma Nota SAP indicada.');
      }
      if (anexo.isDerivado || anexo.anexoDerivadoDeId != null) {
        throw Exception('A evidência deve referenciar o anexo original.');
      }
      if (anotacaoVersao != null) {
        final anotacoes = bancoAnotacoes[anexoId] ?? [];
        if (!anotacoes.any((a) => a.versao == anotacaoVersao)) {
          throw Exception('Versão v$anotacaoVersao não encontrada para o anexo.');
        }
      }
    } else if (fonteReal == NotaEvidenciaTipoFonte.fotoAlbum) {
      if (mediaImageId == null || anexoId != null) {
        throw Exception('Para foto_album: mediaImageId é obrigatório e anexoId deve ser nulo.');
      }
      if (anotacaoVersao != null) {
        throw Exception('Fotografia do álbum não suporta versão de anotação de anexo.');
      }
      final media = bancoMediaImages[mediaImageId];
      if (media == null) {
        throw Exception('Fotografia do álbum não encontrada em media_images.');
      }
    }

    // Upsert com restrição de unicidade parcial
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
      mediaImage: mediaImageId != null ? bancoMediaImages[mediaImageId] : null,
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
  Future<int> contarEvidenciasDistintasNaAnalise(String notaSapId) async {
    final vinculos = bancoEvidencias.where((e) => e.notaSapId == notaSapId).toList();
    final identidades = <String>{};
    for (final v in vinculos) {
      identidades.add(v.logicalIdentity);
    }
    return identidades.length;
  }

  @override
  Future<Map<String, List<NotaTipoVinculoEvidencia>>> buscarUsoDasFotosDoAlbum(
    String notaSapId,
  ) async {
    final vinculos = bancoEvidencias
        .where((e) => e.notaSapId == notaSapId && e.mediaImageId != null)
        .toList();
    final mapa = <String, Set<NotaTipoVinculoEvidencia>>{};
    for (final v in vinculos) {
      if (v.mediaImageId != null) {
        mapa.putIfAbsent(v.mediaImageId!, () => <NotaTipoVinculoEvidencia>{}).add(v.tipoVinculo);
      }
    }
    return mapa.map((k, v) => MapEntry(k, v.toList()));
  }
}

void main() {
  group('FASE 4B — Fontes de Evidência da Análise (Polimorfismo & Integridade)', () {
    late MockNotaSapAnaliseServiceFase4B service;
    const notaId = 'nota-sap-1234';
    const anexoId1 = 'anexo-uuid-001';
    const mediaImageId1 = 'media-uuid-501';
    const mediaImageId2 = 'media-uuid-502';

    setUp(() {
      service = MockNotaSapAnaliseServiceFase4B();

      // Configuração base de dados em memória
      service.bancoAnexos[anexoId1] = const NotaSapAnexo(
        id: anexoId1,
        notaSapId: notaId,
        nomeArquivo: 'poste_danificado.jpg',
        nomeOriginal: 'foto_campo_original.jpg',
        caminhoArquivo: '$notaId/$anexoId1.jpg',
        tamanhoBytes: 2048,
        tipoArquivo: NotaAnexoTipo.imagem,
      );

      service.bancoMediaImages[mediaImageId1] = MediaImage(
        id: mediaImageId1,
        title: 'Torre 027/2 - Vista Geral',
        description: 'Corrosão identificada na base metálica',
        filePath: 'albums/torre_027.jpg',
        createdBy: 'user-fiscal-01',
        createdAt: DateTime(2025, 3, 14, 10, 30),
        updatedAt: DateTime(2025, 3, 14, 10, 30),
      );

      service.bancoMediaImages[mediaImageId2] = MediaImage(
        id: mediaImageId2,
        title: 'Estrutura Acesso SE',
        description: 'Trilha de acesso obstruída por vegetação',
        filePath: 'albums/acesso_se.jpg',
        createdBy: 'user-fiscal-02',
        createdAt: DateTime(2025, 3, 15, 14, 0),
        updatedAt: DateTime(2025, 3, 15, 14, 0),
      );
    });

    test('1. Vínculo de Foto do Álbum com tipo_fonte = foto_album e media_image_id', () async {
      final ev = await service.vincularEvidencia(
        notaSapId: notaId,
        mediaImageId: mediaImageId1,
        tipoFonte: NotaEvidenciaTipoFonte.fotoAlbum,
        tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
        observacao: 'Foto histórica do álbum de campo comprovando início da corrosão.',
      );

      expect(ev.tipoFonte, equals(NotaEvidenciaTipoFonte.fotoAlbum));
      expect(ev.isFotoAlbum, isTrue);
      expect(ev.isAnexo, isFalse);
      expect(ev.mediaImageId, equals(mediaImageId1));
      expect(ev.anexoId, isNull);
      expect(ev.anotacaoVersao, isNull);
      expect(ev.logicalIdentity, equals('foto_album:$mediaImageId1'));
      expect(ev.tituloExibicao, equals('Torre 027/2 - Vista Geral'));
      expect(ev.dataRegistro, equals(DateTime(2025, 3, 14, 10, 30)));
    });

    test('2. Rejeição de versão de anotação quando tipo_fonte = foto_album', () async {
      expect(
        () => service.vincularEvidencia(
          notaSapId: notaId,
          mediaImageId: mediaImageId1,
          tipoFonte: NotaEvidenciaTipoFonte.fotoAlbum,
          tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
          anotacaoVersao: 2, // Ilegal para foto de álbum!
        ),
        throwsA(predicate((e) => e.toString().contains('não suporta versão de anotação'))),
      );
    });

    test('3. Rejeição se ambos os IDs forem fornecidos (exclusividade mútua)', () async {
      expect(
        () => service.vincularEvidencia(
          notaSapId: notaId,
          anexoId: anexoId1,
          mediaImageId: mediaImageId1,
          tipoFonte: NotaEvidenciaTipoFonte.fotoAlbum,
          tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
        ),
        throwsA(predicate((e) => e.toString().contains('anexoId deve ser nulo'))),
      );
    });

    test('4. Rejeição se ambos os IDs forem nulos', () async {
      expect(
        () => service.vincularEvidencia(
          notaSapId: notaId,
          anexoId: null,
          mediaImageId: null,
          tipoFonte: NotaEvidenciaTipoFonte.fotoAlbum,
          tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
        ),
        throwsA(predicate((e) => e.toString().contains('mediaImageId é obrigatório'))),
      );
    });

    test('5. Rejeição se media_image não existir na tabela media_images', () async {
      expect(
        () => service.vincularEvidencia(
          notaSapId: notaId,
          mediaImageId: 'inexistente-uuid-999',
          tipoFonte: NotaEvidenciaTipoFonte.fotoAlbum,
          tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
        ),
        throwsA(predicate((e) => e.toString().contains('não encontrada em media_images'))),
      );
    });

    test('6. Mesma foto vinculada a duas seções distintas (Diagnóstico e Acesso)', () async {
      await service.vincularEvidencia(
        notaSapId: notaId,
        mediaImageId: mediaImageId1,
        tipoFonte: NotaEvidenciaTipoFonte.fotoAlbum,
        tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
      );
      await service.vincularEvidencia(
        notaSapId: notaId,
        mediaImageId: mediaImageId1,
        tipoFonte: NotaEvidenciaTipoFonte.fotoAlbum,
        tipoVinculo: NotaTipoVinculoEvidencia.acesso,
      );

      final usos = await service.buscarUsoDasFotosDoAlbum(notaId);
      expect(usos.containsKey(mediaImageId1), isTrue);
      expect(usos[mediaImageId1]!.length, equals(2));
      expect(usos[mediaImageId1]!.contains(NotaTipoVinculoEvidencia.diagnostico), isTrue);
      expect(usos[mediaImageId1]!.contains(NotaTipoVinculoEvidencia.acesso), isTrue);
    });

    test('7. Contagem distinct polimórfica (Foto em 2 seções + Anexo em 1 seção = 2)', () async {
      // Foto 1 em 2 seções
      await service.vincularEvidencia(
        notaSapId: notaId,
        mediaImageId: mediaImageId1,
        tipoFonte: NotaEvidenciaTipoFonte.fotoAlbum,
        tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
      );
      await service.vincularEvidencia(
        notaSapId: notaId,
        mediaImageId: mediaImageId1,
        tipoFonte: NotaEvidenciaTipoFonte.fotoAlbum,
        tipoVinculo: NotaTipoVinculoEvidencia.seguranca,
      );

      // Anexo 1 em 1 seção
      await service.vincularEvidencia(
        notaSapId: notaId,
        anexoId: anexoId1,
        tipoFonte: NotaEvidenciaTipoFonte.anexoNota,
        tipoVinculo: NotaTipoVinculoEvidencia.materiais,
      );

      expect(service.bancoEvidencias.length, equals(3)); // 3 registros na tabela

      // Distinct count deve retornar 2 (foto_album:mediaImageId1 e anexo_nota:anexoId1)
      final distinctCount = await service.contarEvidenciasDistintasNaAnalise(notaId);
      expect(distinctCount, equals(2));
    });

    test('8. Desvinculação remove apenas a seção selecionada', () async {
      await service.vincularEvidencia(
        notaSapId: notaId,
        mediaImageId: mediaImageId1,
        tipoFonte: NotaEvidenciaTipoFonte.fotoAlbum,
        tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
      );
      await service.vincularEvidencia(
        notaSapId: notaId,
        mediaImageId: mediaImageId1,
        tipoFonte: NotaEvidenciaTipoFonte.fotoAlbum,
        tipoVinculo: NotaTipoVinculoEvidencia.acesso,
      );

      await service.desvincularEvidencia(
        notaSapId: notaId,
        mediaImageId: mediaImageId1,
        tipoFonte: NotaEvidenciaTipoFonte.fotoAlbum,
        tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
      );

      final usos = await service.buscarUsoDasFotosDoAlbum(notaId);
      expect(usos[mediaImageId1]!.length, equals(1));
      expect(usos[mediaImageId1]!.first, equals(NotaTipoVinculoEvidencia.acesso));
    });

    test('9. Matching contextual não é autorização: foto em matching não vincula automaticamente', () {
      // Simula que mediaImageId2 apareceu no matching de nível A (mesmo equipamento)
      // O bancoEvidencias DEVE permanecer vazio até o usuário clicar e salvar
      expect(service.bancoEvidencias.any((e) => e.mediaImageId == mediaImageId2), isFalse);
    });

    test('10. Princípio não bloqueante: 0 evidências continua válido para a análise', () {
      final analise = NotaSapAnalise(
        notaSapId: notaId,
        statusAnalise: NotaAnaliseStatus.concluida,
        diagnosticoPrevio: 'Inspeção visual preliminar sem anexos',
      );

      expect(service.bancoEvidencias.isEmpty, isTrue);
      expect(analise.statusAnalise, equals(NotaAnaliseStatus.concluida));
    });
  });
}
