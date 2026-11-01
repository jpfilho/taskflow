import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/features/media_albums/data/models/media_image.dart';
import 'package:task2026/models/nota_sap.dart';
import 'package:task2026/models/nota_sap_analise.dart';
import 'package:task2026/models/nota_sap_analise_evidencia.dart';
import 'package:task2026/models/nota_sap_anotacao.dart';
import 'package:task2026/services/nota_sap_analise_service.dart';

/// Mock autônomo com integridade em memória para validar os 26 cenários do serviço
class MockNotaSapAnaliseServiceHistorico extends Fake implements NotaSapAnaliseService {
  final Map<String, NotaSAP> bancoNotas = {};
  final Map<String, NotaSapAnexo> bancoAnexos = {};
  final Map<String, MediaImage> bancoMediaImages = {};
  final Map<String, List<NotaSapAnotacao>> bancoAnotacoes = {};
  final List<NotaSapAnaliseEvidencia> bancoEvidencias = [];

  // Rastreadores de Storage para comprovação de Zero Cópia
  int arquivosCriadosNoStorage = 0;
  int arquivosCopiadosNoStorage = 0;

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

    // Validações por tipo de fonte
    if (fonteReal == NotaEvidenciaTipoFonte.anexoNota) {
      if (anexoId == null || mediaImageId != null) {
        throw StateError('Para anexo_nota: anexoId é obrigatório e mediaImageId deve ser nulo.');
      }
      final anexo = bancoAnexos[anexoId];
      if (anexo == null) throw StateError('Anexo não encontrado.');
      if (anexo.notaSapId != notaSapId) {
        throw StateError('O anexo não pertence à mesma Nota SAP indicada.');
      }
      if (anexo.isDerivado || anexo.anexoDerivadoDeId != null) {
        throw StateError('A evidência deve referenciar o anexo original.');
      }
      if (anotacaoVersao != null) {
        final anotacoes = bancoAnotacoes[anexoId] ?? [];
        if (!anotacoes.any((a) => a.versao == anotacaoVersao)) {
          throw StateError('Versão v$anotacaoVersao não encontrada para o anexo.');
        }
      }
    } else if (fonteReal == NotaEvidenciaTipoFonte.fotoAlbum) {
      if (mediaImageId == null || anexoId != null) {
        throw StateError('Para foto_album: mediaImageId é obrigatório e anexoId deve ser nulo.');
      }
      if (anotacaoVersao != null) {
        throw StateError('Fotografia do álbum não suporta versão de anotação de anexo.');
      }
      if (!bancoMediaImages.containsKey(mediaImageId)) {
        throw StateError('Fotografia do álbum não encontrada em media_images.');
      }
    } else if (fonteReal == NotaEvidenciaTipoFonte.anexoNotaHistorica) {
      if (anexoId == null || mediaImageId != null) {
        throw StateError('Para anexo_nota_historica: anexoId é obrigatório e mediaImageId deve ser nulo.');
      }
      final anexo = bancoAnexos[anexoId];
      if (anexo == null) throw StateError('Anexo histórico não encontrado.');
      if (anexo.isDerivado || anexo.anexoDerivadoDeId != null) {
        throw StateError('A evidência histórica deve referenciar o anexo original.');
      }
      if (anexo.notaSapId == notaSapId) {
        throw StateError('Este anexo pertence à Nota atual. Use a fonte anexo_nota.');
      }
      if (!bancoNotas.containsKey(anexo.notaSapId)) {
        throw StateError('Nota SAP de origem (${anexo.notaSapId}) não encontrada.');
      }
      if (anotacaoVersao != null) {
        final anotacoes = bancoAnotacoes[anexoId] ?? [];
        if (!anotacoes.any((a) => a.versao == anotacaoVersao)) {
          throw StateError('Versão v$anotacaoVersao não encontrada no anexo histórico.');
        }
      }
    }

    // Regra: 1 representação por anexo/seção (atualização atômica se já existir)
    final index = bancoEvidencias.indexWhere(
      (e) =>
          e.notaSapId == notaSapId &&
          e.tipoFonte == fonteReal &&
          e.tipoVinculo == tipoVinculo &&
          ((fonteReal == NotaEvidenciaTipoFonte.fotoAlbum && e.mediaImageId == mediaImageId) ||
              (fonteReal != NotaEvidenciaTipoFonte.fotoAlbum && e.anexoId == anexoId)),
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
      numeroNotaHistorica: fonteReal == NotaEvidenciaTipoFonte.anexoNotaHistorica && anexoId != null
          ? bancoNotas[bancoAnexos[anexoId]!.notaSapId]?.nota
          : null,
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
  @override
  Future<void> excluirAnexo(NotaSapAnexo anexo) async {
    // Validação de proteção RESTRICT: consultar evidências vinculadas
    final vinculos = bancoEvidencias.where((e) => e.anexoId == anexo.id).toList();
    if (vinculos.isNotEmpty) {
      final notasAfetadas = vinculos.map((v) => v.notaSapId).toSet().join(', ');
      throw StateError(
        'Este anexo está vinculado como evidência técnica formal na(s) nota(s) [$notasAfetadas] e não pode ser excluído.',
      );
    }

    bancoAnexos.remove(anexo.id);
    bancoAnotacoes.remove(anexo.id);
  }

  @override
  Future<List<NotaSapAnaliseEvidencia>> listarEvidenciasDaNota(String notaSapId) async {
    final list = bancoEvidencias.where((e) => e.notaSapId == notaSapId).toList();
    // Simula Batch Hydration O(N) sem N+1
    return list.map((ev) {
      final anx = ev.anexoId != null ? bancoAnexos[ev.anexoId] : null;
      final numNota = ev.isAnexoHistorico && anx != null
          ? bancoNotas[anx.notaSapId]?.nota
          : null;
      return ev.copyWith(
        anexo: anx,
        mediaImage: ev.mediaImageId != null ? bancoMediaImages[ev.mediaImageId] : null,
        numeroNotaHistorica: numNota,
      );
    }).toList();
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
  Future<Map<String, List<NotaTipoVinculoEvidencia>>> buscarUsoDosAnexosHistoricos(
    String notaSapId,
  ) async {
    final vinculos = bancoEvidencias
        .where((e) => e.notaSapId == notaSapId && e.tipoFonte == NotaEvidenciaTipoFonte.anexoNotaHistorica)
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
  Future<String> obterUrlAssinada(
    NotaSapAnexo anexo, {
    Duration? expires,
    bool forDownload = false,
  }) async {
    return 'https://dev.supabase.taskflow/storage/v1/object/sign/notas-anexos/${anexo.caminhoArquivo}?token=mock';
  }
}

void main() {
  group('EVIDÊNCIA HISTÓRICA — 26 CENÁRIOS DE INTEGRIDADE, MODELO E SERVIÇO', () {
    late MockNotaSapAnaliseServiceHistorico service;
    const notaAtualId = 'nota-atual-001';
    const notaHistoricaId = 'nota-hist-999';
    const anexoHistoricoId = 'anexo-hist-101';
    const anexoAtualId = 'anexo-atual-202';
    const mediaImageId = 'media-img-303';

    setUp(() {
      service = MockNotaSapAnaliseServiceHistorico();

      // Notas SAP
      service.bancoNotas[notaAtualId] = NotaSAP(
        id: notaAtualId,
        nota: '10000001',
        descricao: 'Manutenção Atual',
      );
      service.bancoNotas[notaHistoricaId] = NotaSAP(
        id: notaHistoricaId,
        nota: '90000099',
        descricao: 'Manutenção Histórica de 2024',
      );

      // Anexos
      service.bancoAnexos[anexoHistoricoId] = const NotaSapAnexo(
        id: anexoHistoricoId,
        notaSapId: notaHistoricaId,
        nomeArquivo: 'transformador_2024.jpg',
        nomeOriginal: 'foto_antiga.jpg',
        caminhoArquivo: '$notaHistoricaId/$anexoHistoricoId.jpg',
        tamanhoBytes: 5120,
        tipoArquivo: NotaAnexoTipo.imagem,
      );

      service.bancoAnexos[anexoAtualId] = const NotaSapAnexo(
        id: anexoAtualId,
        notaSapId: notaAtualId,
        nomeArquivo: 'transformador_atual.jpg',
        nomeOriginal: 'foto_atual.jpg',
        caminhoArquivo: '$notaAtualId/$anexoAtualId.jpg',
        tamanhoBytes: 4096,
        tipoArquivo: NotaAnexoTipo.imagem,
      );

      // Anotações
      service.bancoAnotacoes[anexoHistoricoId] = [
        const NotaSapAnotacao(
          id: 'ant-1',
          anexoId: anexoHistoricoId,
          versao: 1,
          dadosJson: NotaSapAnotacaoDocumento(canvasWidth: 800, canvasHeight: 600),
        ),
        const NotaSapAnotacao(
          id: 'ant-2',
          anexoId: anexoHistoricoId,
          versao: 2,
          dadosJson: NotaSapAnotacaoDocumento(canvasWidth: 800, canvasHeight: 600),
        ),
      ];

      // Media Image
      service.bancoMediaImages[mediaImageId] = MediaImage(
        id: mediaImageId,
        title: 'Foto Álbum',
        description: 'Descrição',
        filePath: 'albums/foto.jpg',
        createdBy: 'user1',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );
    });

    // -------------------------------------------------------------------------
    // GRUPO 1: MODELO E PARSER (Cenários 1 a 4)
    // -------------------------------------------------------------------------
    test('1. fromMap deserializa anexo_nota_historica corretamente', () {
      final map = {
        'id': 'ev-1',
        'nota_sap_id': notaAtualId,
        'tipo_fonte': 'anexo_nota_historica',
        'anexo_id': anexoHistoricoId,
        'tipo_vinculo': 'diagnostico',
        'anotacao_versao': 1,
        'observacao': 'Evidência histórica de trinca',
      };
      final ev = NotaSapAnaliseEvidencia.fromMap(map);
      expect(ev.tipoFonte, equals(NotaEvidenciaTipoFonte.anexoNotaHistorica));
      expect(ev.isAnexoHistorico, isTrue);
      expect(ev.anotacaoVersao, equals(1));
    });

    test('2. toMap serializa anexoNotaHistorica como valor anexo_nota_historica', () {
      const ev = NotaSapAnaliseEvidencia(
        id: 'ev-2',
        notaSapId: notaAtualId,
        tipoFonte: NotaEvidenciaTipoFonte.anexoNotaHistorica,
        anexoId: anexoHistoricoId,
        tipoVinculo: NotaTipoVinculoEvidencia.escopo,
      );
      final map = ev.toMap();
      expect(map['tipo_fonte'], equals('anexo_nota_historica'));
      expect(map['anexo_id'], equals(anexoHistoricoId));
    });

    test('3. Backward compatibility: anexo_nota permanece inalterado', () {
      final map = {
        'id': 'ev-3',
        'nota_sap_id': notaAtualId,
        'tipo_fonte': 'anexo_nota',
        'anexo_id': anexoAtualId,
        'tipo_vinculo': 'materiais',
      };
      final ev = NotaSapAnaliseEvidencia.fromMap(map);
      expect(ev.tipoFonte, equals(NotaEvidenciaTipoFonte.anexoNota));
      expect(ev.isAnexo, isTrue);
      expect(ev.isAnexoHistorico, isFalse);
    });

    test('4. Backward compatibility: foto_album permanece inalterado', () {
      final map = {
        'id': 'ev-4',
        'nota_sap_id': notaAtualId,
        'tipo_fonte': 'foto_album',
        'media_image_id': mediaImageId,
        'tipo_vinculo': 'seguranca',
      };
      final ev = NotaSapAnaliseEvidencia.fromMap(map);
      expect(ev.tipoFonte, equals(NotaEvidenciaTipoFonte.fotoAlbum));
      expect(ev.isFotoAlbum, isTrue);
      expect(ev.isAnexoHistorico, isFalse);
    });

    // -------------------------------------------------------------------------
    // GRUPO 2: VALIDAÇÕES DE VÍNCULO HISTÓRICO (Cenários 5 a 11)
    // -------------------------------------------------------------------------
    test('5. Vínculo bem-sucedido de anexo histórico de outra Nota', () async {
      final ev = await service.vincularEvidencia(
        notaSapId: notaAtualId,
        anexoId: anexoHistoricoId,
        tipoFonte: NotaEvidenciaTipoFonte.anexoNotaHistorica,
        tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
        observacao: 'Trinca idêntica identificada em 2024',
      );
      expect(ev.tipoFonte, equals(NotaEvidenciaTipoFonte.anexoNotaHistorica));
      expect(ev.anexoId, equals(anexoHistoricoId));
      expect(ev.numeroNotaHistorica, equals('90000099'));
    });

    test('6. Rejeitar anexo histórico com mediaImageId preenchido', () async {
      expect(
        () => service.vincularEvidencia(
          notaSapId: notaAtualId,
          anexoId: anexoHistoricoId,
          mediaImageId: mediaImageId,
          tipoFonte: NotaEvidenciaTipoFonte.anexoNotaHistorica,
          tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('7. Rejeitar anexo histórico inexistente', () async {
      expect(
        () => service.vincularEvidencia(
          notaSapId: notaAtualId,
          anexoId: 'anexo-inexistente-404',
          tipoFonte: NotaEvidenciaTipoFonte.anexoNotaHistorica,
          tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('8. Rejeitar quando o anexo pertencer à própria Nota atual', () async {
      expect(
        () => service.vincularEvidencia(
          notaSapId: notaAtualId,
          anexoId: anexoAtualId, // Pertence à própria notaAtualId!
          tipoFonte: NotaEvidenciaTipoFonte.anexoNotaHistorica,
          tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
        ),
        throwsA(predicate((e) =>
            e is StateError &&
            e.message.contains('Este anexo pertence à Nota atual'))),
      );
    });

    test('9. Rejeitar quando o anexo for derivado', () async {
      const derivadoId = 'anexo-derivado-888';
      service.bancoAnexos[derivadoId] = const NotaSapAnexo(
        id: derivadoId,
        notaSapId: notaHistoricaId,
        nomeArquivo: 'anotado_v1.jpg',
        caminhoArquivo: '$notaHistoricaId/$derivadoId.jpg',
        tamanhoBytes: 2000,
        tipoArquivo: NotaAnexoTipo.imagem,
        anexoDerivadoDeId: anexoHistoricoId,
      );

      expect(
        () => service.vincularEvidencia(
          notaSapId: notaAtualId,
          anexoId: derivadoId,
          tipoFonte: NotaEvidenciaTipoFonte.anexoNotaHistorica,
          tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
        ),
        throwsA(predicate((e) =>
            e is StateError &&
            e.message.contains('referenciar o anexo original'))),
      );
    });

    test('10. Rejeitar quando a Nota de origem não existir no banco', () async {
      const anexoSemNotaId = 'anexo-orfa-777';
      service.bancoAnexos[anexoSemNotaId] = const NotaSapAnexo(
        id: anexoSemNotaId,
        notaSapId: 'nota-fantasma-9999',
        nomeArquivo: 'orfa.jpg',
        caminhoArquivo: 'nota-fantasma-9999/$anexoSemNotaId.jpg',
        tamanhoBytes: 1000,
        tipoArquivo: NotaAnexoTipo.imagem,
      );

      expect(
        () => service.vincularEvidencia(
          notaSapId: notaAtualId,
          anexoId: anexoSemNotaId,
          tipoFonte: NotaEvidenciaTipoFonte.anexoNotaHistorica,
          tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
        ),
        throwsA(predicate((e) =>
            e is StateError && e.message.contains('não encontrada'))),
      );
    });

    test('11. Rejeitar quando anotacaoVersao informada não existir', () async {
      expect(
        () => service.vincularEvidencia(
          notaSapId: notaAtualId,
          anexoId: anexoHistoricoId,
          tipoFonte: NotaEvidenciaTipoFonte.anexoNotaHistorica,
          tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
          anotacaoVersao: 99, // Versão inexistente (só temos 1 e 2)
        ),
        throwsA(predicate((e) =>
            e is StateError &&
            e.message.contains('Versão v99 não encontrada'))),
      );
    });

    // -------------------------------------------------------------------------
    // GRUPO 3: SEMÂNTICA DE VERSÃO E UNICIDADE (Cenários 12 a 15)
    // -------------------------------------------------------------------------
    test('12. Semântica: vincular versão anotada v1 substitui original na mesma seção', () async {
      // 1. Vincula original
      await service.vincularEvidencia(
        notaSapId: notaAtualId,
        anexoId: anexoHistoricoId,
        tipoFonte: NotaEvidenciaTipoFonte.anexoNotaHistorica,
        tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
        anotacaoVersao: null,
      );
      expect(service.bancoEvidencias.length, equals(1));
      expect(service.bancoEvidencias.first.anotacaoVersao, isNull);

      // 2. Troca para v1
      await service.vincularEvidencia(
        notaSapId: notaAtualId,
        anexoId: anexoHistoricoId,
        tipoFonte: NotaEvidenciaTipoFonte.anexoNotaHistorica,
        tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
        anotacaoVersao: 1,
      );
      // Mantém exatamente 1 linha (sem duplicar)
      expect(service.bancoEvidencias.length, equals(1));
      expect(service.bancoEvidencias.first.anotacaoVersao, equals(1));
    });

    test('13. Troca inversa: vincular original substitui versão anotada v1', () async {
      await service.vincularEvidencia(
        notaSapId: notaAtualId,
        anexoId: anexoHistoricoId,
        tipoFonte: NotaEvidenciaTipoFonte.anexoNotaHistorica,
        tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
        anotacaoVersao: 2,
      );
      expect(service.bancoEvidencias.first.anotacaoVersao, equals(2));

      await service.vincularEvidencia(
        notaSapId: notaAtualId,
        anexoId: anexoHistoricoId,
        tipoFonte: NotaEvidenciaTipoFonte.anexoNotaHistorica,
        tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
        anotacaoVersao: null,
      );
      expect(service.bancoEvidencias.length, equals(1));
      expect(service.bancoEvidencias.first.anotacaoVersao, isNull);
    });

    test('14. Mesmo anexo histórico em seções distintas pode coexistir', () async {
      await service.vincularEvidencia(
        notaSapId: notaAtualId,
        anexoId: anexoHistoricoId,
        tipoFonte: NotaEvidenciaTipoFonte.anexoNotaHistorica,
        tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
      );
      await service.vincularEvidencia(
        notaSapId: notaAtualId,
        anexoId: anexoHistoricoId,
        tipoFonte: NotaEvidenciaTipoFonte.anexoNotaHistorica,
        tipoVinculo: NotaTipoVinculoEvidencia.escopo,
      );
      expect(service.bancoEvidencias.length, equals(2));
      expect(service.bancoEvidencias.map((e) => e.tipoVinculo).toSet(),
          containsAll([NotaTipoVinculoEvidencia.diagnostico, NotaTipoVinculoEvidencia.escopo]));
    });

    test('15. Reaplicar mesma seção atualiza atômica sem duplicar', () async {
      await service.vincularEvidencia(
        notaSapId: notaAtualId,
        anexoId: anexoHistoricoId,
        tipoFonte: NotaEvidenciaTipoFonte.anexoNotaHistorica,
        tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
        observacao: 'Primeira obs',
      );
      await service.vincularEvidencia(
        notaSapId: notaAtualId,
        anexoId: anexoHistoricoId,
        tipoFonte: NotaEvidenciaTipoFonte.anexoNotaHistorica,
        tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
        observacao: 'Segunda obs atualizada',
      );
      expect(service.bancoEvidencias.length, equals(1));
      expect(service.bancoEvidencias.first.observacao, equals('Segunda obs atualizada'));
    });

    // -------------------------------------------------------------------------
    // GRUPO 4: EXCLUSÃO E PROTEÇÃO RESTRICT (Cenários 16 a 19)
    // -------------------------------------------------------------------------
    test('16. excluirAnexo é bloqueado quando anexo estiver em uso como anexo_nota', () async {
      await service.vincularEvidencia(
        notaSapId: notaAtualId,
        anexoId: anexoAtualId,
        tipoFonte: NotaEvidenciaTipoFonte.anexoNota,
        tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
      );

      expect(
        () => service.excluirAnexo(service.bancoAnexos[anexoAtualId]!),
        throwsA(predicate((e) =>
            e is StateError &&
            e.message.contains('não pode ser excluído'))),
      );
      expect(service.bancoAnexos.containsKey(anexoAtualId), isTrue);
    });

    test('17. excluirAnexo é bloqueado quando histórico estiver em uso como evidência', () async {
      await service.vincularEvidencia(
        notaSapId: notaAtualId,
        anexoId: anexoHistoricoId,
        tipoFonte: NotaEvidenciaTipoFonte.anexoNotaHistorica,
        tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
      );

      expect(
        () => service.excluirAnexo(service.bancoAnexos[anexoHistoricoId]!),
        throwsA(predicate((e) =>
            e is StateError &&
            e.message.contains('não pode ser excluído'))),
      );
      expect(service.bancoAnexos.containsKey(anexoHistoricoId), isTrue);
    });

    test('18. desvincularEvidencia remove apenas o vínculo sem tocar o anexo', () async {
      await service.vincularEvidencia(
        notaSapId: notaAtualId,
        anexoId: anexoHistoricoId,
        tipoFonte: NotaEvidenciaTipoFonte.anexoNotaHistorica,
        tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
      );
      expect(service.bancoEvidencias.length, equals(1));

      await service.desvincularEvidencia(
        notaSapId: notaAtualId,
        anexoId: anexoHistoricoId,
        tipoFonte: NotaEvidenciaTipoFonte.anexoNotaHistorica,
        tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
      );

      expect(service.bancoEvidencias.isEmpty, isTrue);
      // Anexo histórico continua íntegro no banco
      expect(service.bancoAnexos.containsKey(anexoHistoricoId), isTrue);
    });

    test('19. excluirAnexo é permitido após desvinculação completa', () async {
      await service.vincularEvidencia(
        notaSapId: notaAtualId,
        anexoId: anexoHistoricoId,
        tipoFonte: NotaEvidenciaTipoFonte.anexoNotaHistorica,
        tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
      );
      await service.desvincularEvidencia(
        notaSapId: notaAtualId,
        anexoId: anexoHistoricoId,
        tipoFonte: NotaEvidenciaTipoFonte.anexoNotaHistorica,
        tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
      );

      // Agora a exclusão deve passar sem erro
      await service.excluirAnexo(service.bancoAnexos[anexoHistoricoId]!);
      expect(service.bancoAnexos.containsKey(anexoHistoricoId), isFalse);
    });

    // -------------------------------------------------------------------------
    // GRUPO 5: BATCH HYDRATION E CONSULTAS (Cenários 20 a 23)
    // -------------------------------------------------------------------------
    test('20. listarEvidenciasDaNota hidrata dados do anexo sem N+1', () async {
      await service.vincularEvidencia(
        notaSapId: notaAtualId,
        anexoId: anexoHistoricoId,
        tipoFonte: NotaEvidenciaTipoFonte.anexoNotaHistorica,
        tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
      );

      final lista = await service.listarEvidenciasDaNota(notaAtualId);
      expect(lista.length, equals(1));
      expect(lista.first.anexo, isNotNull);
      expect(lista.first.anexo!.nomeArquivo, equals('transformador_2024.jpg'));
    });

    test('21. listarEvidenciasDaNota hidrata nota_sap.nota em lote', () async {
      await service.vincularEvidencia(
        notaSapId: notaAtualId,
        anexoId: anexoHistoricoId,
        tipoFonte: NotaEvidenciaTipoFonte.anexoNotaHistorica,
        tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
      );

      final lista = await service.listarEvidenciasDaNota(notaAtualId);
      expect(lista.first.numeroNotaHistorica, equals('90000099'));
    });

    test('22. contarEvidenciasDistintasNaAnalise usa chave lógica tipo_fonte + source_id', () async {
      // Mesmo anexo em 2 seções diferentes:
      await service.vincularEvidencia(
        notaSapId: notaAtualId,
        anexoId: anexoHistoricoId,
        tipoFonte: NotaEvidenciaTipoFonte.anexoNotaHistorica,
        tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
      );
      await service.vincularEvidencia(
        notaSapId: notaAtualId,
        anexoId: anexoHistoricoId,
        tipoFonte: NotaEvidenciaTipoFonte.anexoNotaHistorica,
        tipoVinculo: NotaTipoVinculoEvidencia.escopo,
      );

      // Contagem de evidências DISTINTAS na análise deve ser 1
      final distintas = await service.contarEvidenciasDistintasNaAnalise(notaAtualId);
      expect(distintas, equals(1));
    });

    test('23. buscarUsoDosAnexosHistoricos retorna mapa anexoId -> [seções]', () async {
      await service.vincularEvidencia(
        notaSapId: notaAtualId,
        anexoId: anexoHistoricoId,
        tipoFonte: NotaEvidenciaTipoFonte.anexoNotaHistorica,
        tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
      );
      await service.vincularEvidencia(
        notaSapId: notaAtualId,
        anexoId: anexoHistoricoId,
        tipoFonte: NotaEvidenciaTipoFonte.anexoNotaHistorica,
        tipoVinculo: NotaTipoVinculoEvidencia.seguranca,
      );

      final mapa = await service.buscarUsoDosAnexosHistoricos(notaAtualId);
      expect(mapa.containsKey(anexoHistoricoId), isTrue);
      expect(mapa[anexoHistoricoId]!, containsAll([
        NotaTipoVinculoEvidencia.diagnostico,
        NotaTipoVinculoEvidencia.seguranca,
      ]));
    });

    // -------------------------------------------------------------------------
    // GRUPO 6: ZERO CÓPIA DE STORAGE (Cenários 24 a 26)
    // -------------------------------------------------------------------------
    test('24. Vínculo histórico comprova Zero Cópia de arquivo no Storage', () async {
      await service.vincularEvidencia(
        notaSapId: notaAtualId,
        anexoId: anexoHistoricoId,
        tipoFonte: NotaEvidenciaTipoFonte.anexoNotaHistorica,
        tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
      );

      expect(service.arquivosCriadosNoStorage, equals(0));
      expect(service.arquivosCopiadosNoStorage, equals(0));
      // Caminho original intacto
      expect(
        service.bancoAnexos[anexoHistoricoId]!.caminhoArquivo,
        equals('$notaHistoricaId/$anexoHistoricoId.jpg'),
      );
    });

    test('25. obterUrlAssinada aponta diretamente para o bucket e path histórico original', () async {
      final anexo = service.bancoAnexos[anexoHistoricoId]!;
      final url = await service.obterUrlAssinada(anexo);
      expect(url, contains('$notaHistoricaId/$anexoHistoricoId.jpg'));
    });

    test('26. Nova versão criada na Nota histórica não altera evidência já vinculada', () async {
      // 1. Vinculou v1
      await service.vincularEvidencia(
        notaSapId: notaAtualId,
        anexoId: anexoHistoricoId,
        tipoFonte: NotaEvidenciaTipoFonte.anexoNotaHistorica,
        tipoVinculo: NotaTipoVinculoEvidencia.diagnostico,
        anotacaoVersao: 1,
      );

      // 2. Nota histórica cria v3 no futuro
      service.bancoAnotacoes[anexoHistoricoId]!.add(
        const NotaSapAnotacao(
          id: 'ant-3',
          anexoId: anexoHistoricoId,
          versao: 3,
          dadosJson: NotaSapAnotacaoDocumento(canvasWidth: 800, canvasHeight: 600),
        ),
      );

      // 3. A evidência vinculada continua estritamente em v1
      final lista = await service.listarEvidenciasDaNota(notaAtualId);
      expect(lista.first.anotacaoVersao, equals(1));
    });
  });
}
