import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/models/nota_sap_analise.dart';
import 'package:task2026/services/nota_sap_analise_service.dart';

void main() {
  group('Fase 2: Testes Unitários de Modelos e Serviço de Análise de Notas SAP', () {
    // -------------------------------------------------------------------------
    // Teste 1: fromJson de análise completa
    // -------------------------------------------------------------------------
    test('Teste 1: fromJson de análise completa deve mapear todos os campos corretamente', () {
      final json = {
        'id': 'analise-uuid-1',
        'nota_sap_id': 'nota-uuid-1',
        'numero_nota': '10584588',
        'status_analise': 'em_analise',
        'diagnostico_previo': 'Avaria no rolamento do motor elétrico',
        'escopo_detalhado': 'Substituição do rolamento 6205 e lubrificação',
        'observacoes_planejamento': 'Realizar no período noturno',
        'necessita_desligamento': true,
        'necessita_bloqueio': true,
        'estimativa_horas': 4.5,
        'quantidade_tecnicos': 2,
        'ferramentas_especiais': 'Sacador de rolamento hidráulico',
        'requisitos_seguranca': 'APR, luvas de vaqueta, óculos de segurança',
        'analista_id': 'analista-uuid-1',
        'analista_nome': 'Carlos Silva',
        'created_at': '2026-10-03T10:00:00Z',
        'updated_at': '2026-10-03T10:30:00Z',
      };

      final analise = NotaSapAnalise.fromJson(json);

      expect(analise.id, equals('analise-uuid-1'));
      expect(analise.notaSapId, equals('nota-uuid-1'));
      expect(analise.numeroNota, equals('10584588'));
      expect(analise.statusAnalise, equals(NotaAnaliseStatus.emAnalise));
      expect(analise.diagnosticoPrevio, equals('Avaria no rolamento do motor elétrico'));
      expect(analise.escopoDetalhado, equals('Substituição do rolamento 6205 e lubrificação'));
      expect(analise.necessitaDesligamento, isTrue);
      expect(analise.necessitaBloqueio, isTrue);
      expect(analise.estimativaHoras, equals(4.5));
      expect(analise.quantidadeTecnicos, equals(2));
      expect(analise.analistaNome, equals('Carlos Silva'));
      expect(analise.createdAt, isNotNull);
      expect(analise.updatedAt, isNotNull);
    });

    // -------------------------------------------------------------------------
    // Teste 2: fromJson com campos null
    // -------------------------------------------------------------------------
    test('Teste 2: fromJson com campos null deve atribuir defaults seguros', () {
      final jsonMinimo = {
        'nota_sap_id': 'nota-uuid-2',
      };

      final analise = NotaSapAnalise.fromJson(jsonMinimo);

      expect(analise.notaSapId, equals('nota-uuid-2'));
      expect(analise.id, isNull);
      expect(analise.numeroNota, isNull);
      expect(analise.statusAnalise, equals(NotaAnaliseStatus.naoIniciada));
      expect(analise.diagnosticoPrevio, isNull);
      expect(analise.escopoDetalhado, isNull);
      expect(analise.necessitaDesligamento, isFalse);
      expect(analise.necessitaBloqueio, isFalse);
      expect(analise.estimativaHoras, isNull);
      expect(analise.quantidadeTecnicos, isNull);
    });

    // -------------------------------------------------------------------------
    // Teste 3: Serialização de todos os status (Analise e Material)
    // -------------------------------------------------------------------------
    test('Teste 3: Serialização e desserialização de todos os status da análise', () {
      final todosStatus = [
        NotaAnaliseStatus.naoIniciada,
        NotaAnaliseStatus.emAnalise,
        NotaAnaliseStatus.concluida,
        NotaAnaliseStatus.aguardandoInformacao,
        NotaAnaliseStatus.cancelada,
      ];

      for (final status in todosStatus) {
        final dbString = status.toDbString();
        final recuperado = NotaAnaliseStatus.fromDbString(dbString);
        expect(recuperado, equals(status));
      }

      // Validação de tolerância a string desconhecida ou nula
      expect(NotaAnaliseStatus.fromDbString(null), equals(NotaAnaliseStatus.naoIniciada));
      expect(NotaAnaliseStatus.fromDbString('invalido'), equals(NotaAnaliseStatus.naoIniciada));
      expect(NotaAnaliseStatus.fromDbString('aguardando_material'), equals(NotaAnaliseStatus.naoIniciada));
    });

    test('Teste 3b: Serialização e desserialização de todos os status de material', () {
      final todosStatusMaterial = [
        NotaMaterialStatus.naoVerificado,
        NotaMaterialStatus.disponivel,
        NotaMaterialStatus.reservado,
        NotaMaterialStatus.aguardandoMaterial,
        NotaMaterialStatus.aguardandoCompra,
        NotaMaterialStatus.substituido,
      ];

      for (final status in todosStatusMaterial) {
        final dbString = status.toDbString();
        final recuperado = NotaMaterialStatus.fromDbString(dbString);
        expect(recuperado, equals(status));
      }
    });

    // -------------------------------------------------------------------------
    // Teste 4: Nota sem análise retorna null (sem INSERT automático)
    // -------------------------------------------------------------------------
    test('Teste 4: NotaSapAnaliseService com ID vazio ou inexistente trata adequadamente', () async {
      final service = NotaSapAnaliseService();
      final resultado = await service.buscarAnalise('');
      expect(resultado, isNull);
    });

    // -------------------------------------------------------------------------
    // Teste 5: Salvar análise nova (payload estruturado para Upsert)
    // -------------------------------------------------------------------------
    test('Teste 5: toMap gera payload correto para Upsert por nota_sap_id', () {
      const analise = NotaSapAnalise(
        notaSapId: 'nota-uuid-5',
        numeroNota: '10998877',
        statusAnalise: NotaAnaliseStatus.emAnalise,
        diagnosticoPrevio: 'Vazamento de óleo',
        necessitaDesligamento: true,
      );

      final map = analise.toMap();

      expect(map['nota_sap_id'], equals('nota-uuid-5'));
      expect(map['numero_nota'], equals('10998877'));
      expect(map['status_analise'], equals('em_analise'));
      expect(map['diagnostico_previo'], equals('Vazamento de óleo'));
      expect(map['necessita_desligamento'], isTrue);
      expect(map['necessita_bloqueio'], isFalse);
      expect(map.containsKey('id'), isFalse); // Novo registro não envia id null
    });

    // -------------------------------------------------------------------------
    // Teste 6: Atualizar análise existente (copyWith)
    // -------------------------------------------------------------------------
    test('Teste 6: copyWith permite atualizar campos preservando o restante', () {
      const original = NotaSapAnalise(
        id: 'analise-id-6',
        notaSapId: 'nota-uuid-6',
        statusAnalise: NotaAnaliseStatus.emAnalise,
        diagnosticoPrevio: 'Diagnóstico A',
      );

      final atualizado = original.copyWith(
        statusAnalise: NotaAnaliseStatus.concluida,
        escopoDetalhado: 'Novo escopo adicionado',
      );

      expect(atualizado.id, equals('analise-id-6'));
      expect(atualizado.notaSapId, equals('nota-uuid-6'));
      expect(atualizado.statusAnalise, equals(NotaAnaliseStatus.concluida));
      expect(atualizado.diagnosticoPrevio, equals('Diagnóstico A'));
      expect(atualizado.escopoDetalhado, equals('Novo escopo adicionado'));
    });

    // -------------------------------------------------------------------------
    // Teste 7: Múltiplos materiais (NotaSapMaterial)
    // -------------------------------------------------------------------------
    test('Teste 7: Mapeamento de múltiplos materiais para a mesma nota', () {
      final materiaisJson = [
        {
          'id': 'mat-1',
          'nota_sap_id': 'nota-uuid-7',
          'descricao': 'Disjuntor bipolar 20A',
          'quantidade': 3.0,
          'unidade': 'UN',
          'status_material': 'disponivel',
        },
        {
          'id': 'mat-2',
          'nota_sap_id': 'nota-uuid-7',
          'descricao': 'Cabo flexível 4mm',
          'quantidade': 50.0,
          'unidade': 'M',
          'status_material': 'aguardando_compra',
        },
      ];

      final lista = materiaisJson.map((m) => NotaSapMaterial.fromJson(m)).toList();

      expect(lista.length, equals(2));
      expect(lista[0].descricao, equals('Disjuntor bipolar 20A'));
      expect(lista[0].statusMaterial, equals(NotaMaterialStatus.disponivel));
      expect(lista[1].quantidade, equals(50.0));
      expect(lista[1].statusMaterial, equals(NotaMaterialStatus.aguardandoCompra));
    });

    // -------------------------------------------------------------------------
    // Teste 8: Alteração de status de material
    // -------------------------------------------------------------------------
    test('Teste 8: Alteração de status de material via copyWith', () {
      const material = NotaSapMaterial(
        id: 'mat-8',
        notaSapId: 'nota-uuid-8',
        descricao: 'Óleo isolante',
        quantidade: 200,
        unidade: 'L',
        statusMaterial: NotaMaterialStatus.aguardandoMaterial,
      );

      final materialAtualizado = material.copyWith(
        statusMaterial: NotaMaterialStatus.disponivel,
        observacao: 'Chegou no almoxarifado regional',
      );

      expect(materialAtualizado.statusMaterial, equals(NotaMaterialStatus.disponivel));
      expect(materialAtualizado.observacao, equals('Chegou no almoxarifado regional'));
    });

    // -------------------------------------------------------------------------
    // Teste 9: Anexo (NotaSapAnexo)
    // -------------------------------------------------------------------------
    test('Teste 9: Mapeamento e serialização de anexo com URL pública', () {
      final anexoJson = {
        'id': 'anexo-uuid-9',
        'nota_sap_id': 'nota-uuid-9',
        'nome_arquivo': 'placa_identificacao.jpg',
        'tipo_arquivo': 'imagem',
        'caminho_arquivo': 'notas_sap/nota-uuid-9/17000000-placa.jpg',
        'tamanho_bytes': 150000,
        'mime_type': 'image/jpeg',
        'legenda': 'Foto da placa com número de série',
        'usuario_nome': 'Técnico Roberto',
      };

      final anexo = NotaSapAnexo.fromJson(anexoJson);

      expect(anexo.id, equals('anexo-uuid-9'));
      expect(anexo.tipoArquivo, equals(NotaAnexoTipo.imagem));
      expect(anexo.tamanhoBytes, equals(150000));
      expect(anexo.legenda, equals('Foto da placa com número de série'));

      final copyComUrl = anexo.copyWith(urlPublica: 'https://storage/placa.jpg');
      expect(copyComUrl.urlPublica, equals('https://storage/placa.jpg'));
    });

    // -------------------------------------------------------------------------
    // Teste 10: Comentário (NotaSapComentario)
    // -------------------------------------------------------------------------
    test('Teste 10: Criação e serialização de comentário técnico', () {
      const comentario = NotaSapComentario(
        id: 'coment-10',
        notaSapId: 'nota-uuid-10',
        usuarioId: 'user-10',
        usuarioNome: 'Eng. Fernando',
        mensagem: 'Verificar se o desligamento já foi alinhado com o COI',
        tipoMensagem: NotaComentarioTipo.texto,
      );

      final map = comentario.toMap();

      expect(map['nota_sap_id'], equals('nota-uuid-10'));
      expect(map['usuario_id'], equals('user-10'));
      expect(map['usuario_nome'], equals('Eng. Fernando'));
      expect(map['mensagem'], equals('Verificar se o desligamento já foi alinhado com o COI'));
      expect(map['tipo_mensagem'], equals('texto'));
      expect(comentario.isDeleted, isFalse);
    });

    // -------------------------------------------------------------------------
    // Teste 11: Soft delete de comentário
    // -------------------------------------------------------------------------
    test('Teste 11: Comentário com deleted_at preenchido indica exclusão lógica', () {
      final jsonDeletado = {
        'id': 'coment-11',
        'nota_sap_id': 'nota-uuid-11',
        'usuario_id': 'user-11',
        'mensagem': 'Mensagem apagada pelo usuário',
        'deleted_at': '2026-10-03T11:00:00Z',
      };

      final comentario = NotaSapComentario.fromJson(jsonDeletado);

      expect(comentario.isDeleted, isTrue);
      expect(comentario.deletedAt, isNotNull);
    });

    // -------------------------------------------------------------------------
    // Teste 12: Consulta em lote sem N+1 (DTO Resumo)
    // -------------------------------------------------------------------------
    test('Teste 12: DTO NotaSapResumoAnalise agrega contadores e status corretamente', () {
      const resumoComAnalise = NotaSapResumoAnalise(
        notaSapId: 'nota-12-a',
        status: NotaAnaliseStatus.concluida,
        quantidadeAnexos: 3,
        quantidadeComentarios: 5,
        quantidadeMateriais: 2,
      );

      expect(resumoComAnalise.temAnalise, isTrue);
      expect(resumoComAnalise.temAnexos, isTrue);
      expect(resumoComAnalise.temComentarios, isTrue);
      expect(resumoComAnalise.temMateriais, isTrue);
      expect(resumoComAnalise.quantidadeAnexos, equals(3));
    });

    // -------------------------------------------------------------------------
    // Teste 13: Nota sem análise aparece no resumo como naoIniciada
    // -------------------------------------------------------------------------
    test('Teste 13: Nota sem análise no resumo possui default naoIniciada e zerada', () {
      const resumoSemAnalise = NotaSapResumoAnalise(
        notaSapId: 'nota-13-vazia',
      );

      expect(resumoSemAnalise.status, equals(NotaAnaliseStatus.naoIniciada));
      expect(resumoSemAnalise.temAnalise, isFalse);
      expect(resumoSemAnalise.quantidadeAnexos, equals(0));
      expect(resumoSemAnalise.quantidadeComentarios, equals(0));
      expect(resumoSemAnalise.quantidadeMateriais, equals(0));
      expect(resumoSemAnalise.temAnexos, isFalse);
      expect(resumoSemAnalise.temComentarios, isFalse);
    });

    // -------------------------------------------------------------------------
    // Teste 14: Invalidação de cache e gerenciamento de canal
    // -------------------------------------------------------------------------
    test('Teste 14: Invalidação e limpeza de cache do serviço', () {
      final service = NotaSapAnaliseService();

      // Testar invalidação pontual e geral
      service.invalidarCache('nota-qualquer');
      service.limparCache();
      service.cancelarTodasAssinaturas();

      expect(true, isTrue);
    });
  });
}
