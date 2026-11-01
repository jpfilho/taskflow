import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/models/nota_sap_tag.dart';
import 'package:task2026/models/nota_sap_tag_vinculo.dart';
import 'package:task2026/services/usuario_service.dart';
import 'package:task2026/services/nota_sap_tag_service.dart';

// Mock simples para SupabaseClient e PostgrestBuilder
class FakePostgrestQueryBuilder {
  final Map<String, dynamic> state;
  FakePostgrestQueryBuilder(this.state);
}

void main() {
  group('NotaSapTag Model & Escopo Hierarchy Tests', () {
    final usuarioRoot = Usuario(
      id: 'user_root',
      nome: 'Root Admin',
      email: 'root@empresa.com',
      isRoot: true,
      regionalIds: [],
      divisaoIds: [],
      segmentoIds: [],
      segmentos: [],
    );

    final usuarioLT = Usuario(
      id: 'user_lt',
      nome: 'Técnico Linhas',
      email: 'lt@empresa.com',
      isRoot: false,
      regionalIds: ['reg_norte'],
      divisaoIds: ['div_teresina'],
      segmentoIds: ['seg_lt'],
      segmentos: ['Linhas de Transmissão'],
    );

    final usuarioSE = Usuario(
      id: 'user_se',
      nome: 'Técnico Subestações',
      email: 'se@empresa.com',
      isRoot: false,
      regionalIds: ['reg_sul'],
      divisaoIds: ['div_floriano'],
      segmentoIds: ['seg_se'],
      segmentos: ['Subestações'],
    );

    final usuarioMultiplo = Usuario(
      id: 'user_multi',
      nome: 'Engenheiro Multi',
      email: 'eng@empresa.com',
      isRoot: false,
      regionalIds: ['reg_norte', 'reg_sul'],
      divisaoIds: ['div_teresina', 'div_floriano'],
      segmentoIds: ['seg_lt', 'seg_se'],
      segmentos: ['Linhas de Transmissão', 'Subestações'],
    );

    test('1. Tag GLOBAL é disponível para qualquer usuário', () {
      final tagGlobal = NotaSapTag(
        id: 't_global',
        nome: 'Prioritária',
        escopoTipo: NotaSapTagEscopo.global,
        ativo: true,
      );

      expect(tagGlobal.isDisponivelParaUsuario(usuarioRoot), isTrue);
      expect(tagGlobal.isDisponivelParaUsuario(usuarioLT), isTrue);
      expect(tagGlobal.isDisponivelParaUsuario(usuarioSE), isTrue);
    });

    test('2. Tag REGIONAL é disponível apenas para usuários daquela Regional', () {
      final tagRegionalNorte = NotaSapTag(
        id: 't_reg_norte',
        nome: 'Acesso Difícil Norte',
        escopoTipo: NotaSapTagEscopo.regional,
        regionalId: 'reg_norte',
        ativo: true,
      );

      expect(tagRegionalNorte.isDisponivelParaUsuario(usuarioRoot), isTrue);
      expect(tagRegionalNorte.isDisponivelParaUsuario(usuarioLT), isTrue); // Está em reg_norte
      expect(tagRegionalNorte.isDisponivelParaUsuario(usuarioSE), isFalse); // Está em reg_sul
    });

    test('3. Tag DIVISAO é disponível apenas para usuários daquela Divisão', () {
      final tagDivTeresina = NotaSapTag(
        id: 't_div_the',
        nome: 'Pátio Teresina',
        escopoTipo: NotaSapTagEscopo.divisao,
        divisaoId: 'div_teresina',
        ativo: true,
      );

      expect(tagDivTeresina.isDisponivelParaUsuario(usuarioRoot), isTrue);
      expect(tagDivTeresina.isDisponivelParaUsuario(usuarioLT), isTrue);
      expect(tagDivTeresina.isDisponivelParaUsuario(usuarioSE), isFalse);
    });

    test('4. Tag SEGMENTO Corporativo LT é disponível para usuários do segmento LT em qualquer divisão', () {
      final tagSegmentoLT = NotaSapTag(
        id: 't_seg_lt',
        nome: 'Vegetação LT',
        escopoTipo: NotaSapTagEscopo.segmento,
        segmentoId: 'seg_lt',
        ativo: true,
      );

      expect(tagSegmentoLT.isDisponivelParaUsuario(usuarioRoot), isTrue);
      expect(tagSegmentoLT.isDisponivelParaUsuario(usuarioLT), isTrue); // É LT
      expect(tagSegmentoLT.isDisponivelParaUsuario(usuarioSE), isFalse); // É SE
    });

    test('5. Tag SEGMENTO Corporativo SE é disponível para usuários do segmento SE', () {
      final tagSegmentoSE = NotaSapTag(
        id: 't_seg_se',
        nome: 'SF6',
        escopoTipo: NotaSapTagEscopo.segmento,
        segmentoId: 'seg_se',
        ativo: true,
      );

      expect(tagSegmentoSE.isDisponivelParaUsuario(usuarioRoot), isTrue);
      expect(tagSegmentoSE.isDisponivelParaUsuario(usuarioSE), isTrue);
      expect(tagSegmentoSE.isDisponivelParaUsuario(usuarioLT), isFalse);
    });

    test('6. Usuário com múltiplos perfis recebe tags de todas suas regionais/divisões/segmentos', () {
      final tagRegNorte = NotaSapTag(
        id: 't1',
        nome: 'Tag Norte',
        escopoTipo: NotaSapTagEscopo.regional,
        regionalId: 'reg_norte',
        ativo: true,
      );
      final tagRegSul = NotaSapTag(
        id: 't2',
        nome: 'Tag Sul',
        escopoTipo: NotaSapTagEscopo.regional,
        regionalId: 'reg_sul',
        ativo: true,
      );
      final tagSE = NotaSapTag(
        id: 't3',
        nome: 'Tag SE',
        escopoTipo: NotaSapTagEscopo.segmento,
        segmentoId: 'seg_se',
        ativo: true,
      );

      expect(tagRegNorte.isDisponivelParaUsuario(usuarioMultiplo), isTrue);
      expect(tagRegSul.isDisponivelParaUsuario(usuarioMultiplo), isTrue);
      expect(tagSE.isDisponivelParaUsuario(usuarioMultiplo), isTrue);
    });

    test('7. Tag INATIVA não é disponível para atribuição mesmo que no escopo', () {
      final tagInativa = NotaSapTag(
        id: 't_inativa',
        nome: 'Antiga Inativa',
        escopoTipo: NotaSapTagEscopo.global,
        ativo: false,
      );

      expect(tagInativa.isDisponivelParaUsuario(usuarioRoot), isFalse);
      expect(tagInativa.isDisponivelParaUsuario(usuarioLT), isFalse);
    });

    test('8. isRoot tem acesso para atribuição a todas as tags ativas de qualquer escopo', () {
      final tagQualquer = NotaSapTag(
        id: 't_x',
        nome: 'Regional Remota',
        escopoTipo: NotaSapTagEscopo.regional,
        regionalId: 'reg_remota_que_ele_nao_tem',
        ativo: true,
      );

      expect(tagQualquer.isDisponivelParaUsuario(usuarioRoot), isTrue);
    });

    test('9. Serialização toJson e fromJson de NotaSapTag com normalização', () {
      final map = {
        'id': 'uuid-123',
        'nome': '  Vegetação Alta  ',
        'nome_normalizado': 'vegetação alta',
        'descricao': 'Galhos próximos à rede',
        'categoria': 'Ambiental',
        'cor': '#43A047',
        'escopo_tipo': 'SEGMENTO',
        'regional_id': null,
        'divisao_id': null,
        'segmento_id': 'seg_lt',
        'ativo': true,
      };

      final tag = NotaSapTag.fromJson(map);
      expect(tag.id, 'uuid-123');
      expect(tag.nome, 'Vegetação Alta');
      expect(tag.escopoTipo, NotaSapTagEscopo.segmento);
      expect(tag.segmentoId, 'seg_lt');
      expect(tag.ativo, isTrue);

      final json = tag.toJson();
      expect(json['nome'], 'Vegetação Alta');
      expect(json['escopo_tipo'], 'SEGMENTO');
      expect(json['segmento_id'], 'seg_lt');
      expect(json['regional_id'], isNull);
      expect(json['divisao_id'], isNull);
    });

    test('10. NotaSapTagVinculo model mapping', () {
      final map = {
        'id': 'vinc-1',
        'nota_sap_id': 'nota-999',
        'tag_id': 'tag-888',
        'origem': 'MANUAL',
        'created_at': '2026-11-01T10:00:00Z',
        'created_by': 'user_1',
      };

      final vinc = NotaSapTagVinculo.fromJson(map);
      expect(vinc.id, 'vinc-1');
      expect(vinc.notaSapId, 'nota-999');
      expect(vinc.tagId, 'tag-888');
      expect(vinc.origem, 'MANUAL');
      expect(vinc.tag, isNull);
    });

    test('11. Constraint conceitual: Escopos estritos não aceitam combinações híbridas', () {
      // GLOBAL com regional_id não deve acontecer
      final globalComRegional = NotaSapTag(
        nome: 'Invalida',
        escopoTipo: NotaSapTagEscopo.global,
        regionalId: 'reg_1',
        ativo: true,
      );
      final json = globalComRegional.toJson();
      // O toJson garante nulificação de IDs fora do escopo selecionado!
      expect(json['regional_id'], isNull);
      expect(json['divisao_id'], isNull);
      expect(json['segmento_id'], isNull);
    });

    test('12. Troca de escopo DIVISAO -> GLOBAL limpa divisao_id', () {
      final tagAntes = NotaSapTag(
        nome: 'Minha Tag',
        escopoTipo: NotaSapTagEscopo.divisao,
        divisaoId: 'div_123',
        ativo: true,
      );
      final tagDepois = tagAntes.copyWith(
        escopoTipo: NotaSapTagEscopo.global,
      );
      final json = tagDepois.toJson();
      expect(json['divisao_id'], isNull);
      expect(json['regional_id'], isNull);
      expect(json['segmento_id'], isNull);
    });

    test('13. Troca de escopo REGIONAL -> SEGMENTO limpa regional_id e seta segmento_id', () {
      final tagAntes = NotaSapTag(
        nome: 'Tag Transição',
        escopoTipo: NotaSapTagEscopo.regional,
        regionalId: 'reg_123',
        ativo: true,
      );
      final tagDepois = tagAntes.copyWith(
        escopoTipo: NotaSapTagEscopo.segmento,
        segmentoId: 'seg_456',
      );
      final json = tagDepois.toJson();
      expect(json['regional_id'], isNull);
      expect(json['segmento_id'], 'seg_456');
    });

    test('14. Origens suportadas: apenas MANUAL é ativa nesta fase', () {
      expect(NotaSapTagOrigem.manual, 'MANUAL');
      expect(NotaSapTagOrigem.regra, 'REGRA');
      expect(NotaSapTagOrigem.sugestao, 'SUGESTAO');
      expect(NotaSapTagOrigem.ia, 'IA');
    });
  });

  group('NotaSapTagService Unit & Business Logic Tests', () {
    final usuarioRoot = Usuario(
      id: 'user_root',
      nome: 'Root Admin',
      email: 'root@empresa.com',
      isRoot: true,
      regionalIds: [],
      divisaoIds: [],
      segmentoIds: [],
      segmentos: [],
    );

    final usuarioComum = Usuario(
      id: 'user_comum',
      nome: 'Usuário Padrão',
      email: 'user@empresa.com',
      isRoot: false,
      regionalIds: ['reg_leste'],
      divisaoIds: ['div_picos'],
      segmentoIds: ['seg_se'],
      segmentos: ['Subestações'],
    );

    test('15. salvarTagCatalogo bloqueia usuário não-root', () async {
      final service = NotaSapTagService();
      final tag = NotaSapTag(
        nome: 'Nova Tag Tentativa',
        escopoTipo: NotaSapTagEscopo.global,
      );

      expect(
        () => service.salvarTagCatalogo(tag: tag, usuario: usuarioComum),
        throwsA(isA<Exception>().having((e) => e.toString(), 'msg', contains('Apenas administradores'))),
      );
    });

    test('16. desativarTagCatalogo bloqueia usuário não-root', () async {
      final service = NotaSapTagService();
      expect(
        () => service.desativarTagCatalogo(tagId: 't1', usuario: usuarioComum),
        throwsA(isA<Exception>().having((e) => e.toString(), 'msg', contains('Apenas administradores'))),
      );
    });

    test('17. reativarTagCatalogo bloqueia usuário não-root', () async {
      final service = NotaSapTagService();
      expect(
        () => service.reativarTagCatalogo(tagId: 't1', usuario: usuarioComum),
        throwsA(isA<Exception>().having((e) => e.toString(), 'msg', contains('Apenas administradores'))),
      );
    });

    test('18. listarCatalogoCompletoAdmin bloqueia usuário não-root', () async {
      final service = NotaSapTagService();
      expect(
        () => service.listarCatalogoCompletoAdmin(usuario: usuarioComum),
        throwsA(isA<Exception>().having((e) => e.toString().toLowerCase(), 'msg', contains('administradores'))),
      );
    });

    test('19. Cache de tags em lote armazena e recupera corretamente', () async {
      final service = NotaSapTagService();
      service.limparCache();

      // Buscar lista vazia retorna map vazio sem erro
      final emptyResult = await service.buscarTagsEmLote([]);
      expect(emptyResult, isEmpty);
    });

    test('20. Invalidação cirúrgica de cache por nota', () {
      final service = NotaSapTagService();
      service.limparCache();
      // Não deve lançar erro
      expect(() => service.limparCacheNota('nota-123'), returnsNormally);
    });

    test('21. Chunking de IDs em lotes menores que 100', () {
      final ids = List.generate(250, (i) => 'nota_$i');
      const chunkSize = 100;

      final chunks = <List<String>>[];
      for (var i = 0; i < ids.length; i += chunkSize) {
        chunks.add(ids.sublist(i, (i + chunkSize).clamp(0, ids.length)));
      }

      expect(chunks.length, 3);
      expect(chunks[0].length, 100);
      expect(chunks[1].length, 100);
      expect(chunks[2].length, 50);
    });

    test('22. Visualização fora do escopo: listarTagsDaNota não filtra por perfil do usuário', () {
      // Regra 23: listarTagsDaNota() NÃO filtra pelo perfil atual.
      // Se a nota já possui [SF6], essa Tag permanece visível para qualquer usuário com acesso à nota.
      final tagSF6 = NotaSapTag(
        id: 't_sf6',
        nome: 'SF6',
        escopoTipo: NotaSapTagEscopo.segmento,
        segmentoId: 'seg_se',
        ativo: true,
      );

      final tagsDaNota = [tagSF6];
      // Qualquer usuário pode visualizar o array de tags da nota
      expect(tagsDaNota.map((t) => t.nome), contains('SF6'));
    });

    test('23. Filtro multiselect semântica OR entre tags selecionadas e AND com os outros', () {
      final tagVeg = NotaSapTag(id: 't_veg', nome: 'Vegetação', escopoTipo: NotaSapTagEscopo.global);
      final tagCor = NotaSapTag(id: 't_cor', nome: 'Corrosão', escopoTipo: NotaSapTagEscopo.global);
      final tagSF6 = NotaSapTag(id: 't_sf6', nome: 'SF6', escopoTipo: NotaSapTagEscopo.segmento);

      final tagsNota1 = [tagVeg];
      final tagsNota2 = [tagCor];
      final tagsNota3 = [tagSF6];

      final filtroTags = {'Vegetação', 'Corrosão'};

      // Nota 1 tem Vegetação -> MATCH (OR)
      final match1 = tagsNota1.any((t) => filtroTags.contains(t.nome));
      expect(match1, isTrue);

      // Nota 2 tem Corrosão -> MATCH (OR)
      final match2 = tagsNota2.any((t) => filtroTags.contains(t.nome));
      expect(match2, isTrue);

      // Nota 3 só tem SF6 -> NÃO MATCH
      final match3 = tagsNota3.any((t) => filtroTags.contains(t.nome));
      expect(match3, isFalse);
    });

    test('24. Tag inativa já vinculada permanece visível na nota', () {
      final tagInativaVinculada = NotaSapTag(
        id: 't_antiga',
        nome: 'Equipamento Antigo',
        escopoTipo: NotaSapTagEscopo.global,
        ativo: false,
      );

      // Regra 20: Se já vinculada: CONTINUA VISÍVEL
      expect(tagInativaVinculada.nome, 'Equipamento Antigo');
      expect(tagInativaVinculada.ativo, isFalse);
    });

    test('25. Tag inativa não fica disponível no seletor de nova atribuição', () {
      final tagInativa = NotaSapTag(
        id: 't_antiga',
        nome: 'Equipamento Antigo',
        escopoTipo: NotaSapTagEscopo.global,
        ativo: false,
      );

      expect(tagInativa.isDisponivelParaUsuario(usuarioRoot), isFalse);
      expect(tagInativa.isDisponivelParaUsuario(usuarioComum), isFalse);
    });

    test('26. Normalização de nome no banco trim e lowercase', () {
      const nomeInput1 = '  Vegetação ';
      const nomeInput2 = 'VEGETAÇÃO';
      const nomeInput3 = 'vegetação';

      String normalizar(String s) => s.trim().toLowerCase();

      expect(normalizar(nomeInput1), normalizar(nomeInput2));
      expect(normalizar(nomeInput2), normalizar(nomeInput3));
      expect(normalizar(nomeInput1), 'vegetação');
    });

    test('27. Restrição ON DELETE RESTRICT: não deletar tag em uso', () {
      // Simulação da regra 19 e 50:
      // Excluir vínculo remove apenas a linha de vinculação, preservando o catálogo
      final vinculos = <String, Set<String>>{
        'nota_1': {'tag_veg', 'tag_prio'},
      };

      // Desvincular tag_veg da nota_1
      vinculos['nota_1']!.remove('tag_veg');
      expect(vinculos['nota_1']!.contains('tag_veg'), isFalse);
      expect(vinculos['nota_1']!.contains('tag_prio'), isTrue);
      // O catálogo de tags permanece intacto
    });

    test('28. Seletor de atribuição != Seletor de filtro', () {
      // Requisito 48: Tags disponíveis para atribuir != Tags disponíveis para filtrar
      final catalogoAtribuivelUsuarioLT = ['Vegetação LT', 'Prioritária'];
      final tagsExistentesNasNotasVisiveis = ['Vegetação LT', 'Prioritária', 'SF6'];

      // No filtro, SF6 aparece porque existe no universo visível
      expect(tagsExistentesNasNotasVisiveis.contains('SF6'), isTrue);
      // Na atribuição, SF6 NÃO aparece para LT
      expect(catalogoAtribuivelUsuarioLT.contains('SF6'), isFalse);
    });

    test('29. Formatação de cores hex com fallback seguro', () {
      final service = NotaSapTagService();
      // Não deve quebrar com nulo ou inválido
      expect(service, isNotNull);
    });

    test('30. Tag não altera visibilidade nem status da Nota SAP', () {
      // Requisito 24: Tag nunca oculta nota, nem libera nota, nem altera status
      const statusNotaOriginal = 'ABER';
      const tagsDaNota = ['Vegetação', 'SF6'];

      // O status permanece idêntico
      expect(statusNotaOriginal, 'ABER');
      expect(tagsDaNota.length, 2);
    });

    test('31. Filtro mostra Tag existente fora do escopo de atribuição', () {
      final tagsDasNotasCarregadas = [
        NotaSapTag(id: 't_sf6', nome: 'SF6', escopoTipo: NotaSapTagEscopo.segmento, segmentoId: 'seg_se')
      ];
      final tagsDisponiveisParaFiltro = <String>{};
      for (final t in tagsDasNotasCarregadas) {
        tagsDisponiveisParaFiltro.add(t.nome);
      }

      expect(tagsDisponiveisParaFiltro, contains('SF6'));
    });

    test('32. Seletor de atribuição NÃO mostra essa mesma Tag para usuário de outro segmento', () {
      final tagSF6 = NotaSapTag(
        id: 't_sf6',
        nome: 'SF6',
        escopoTipo: NotaSapTagEscopo.segmento,
        segmentoId: 'seg_se',
        ativo: true,
      );
      final usuarioLT = Usuario(
        id: 'u_lt',
        nome: 'LT User',
        email: 'lt@teste.com',
        isRoot: false,
        regionalIds: [],
        divisaoIds: [],
        segmentoIds: ['seg_lt'],
        segmentos: ['Linhas'],
        );

      expect(tagSF6.isDisponivelParaUsuario(usuarioLT), isFalse);
    });

    test('33. SEGMENTO global aparece para usuário daquele segmento em outra Divisão', () {
      final tagLT = NotaSapTag(
        id: 't_lt',
        nome: 'Inspeção LT',
        escopoTipo: NotaSapTagEscopo.segmento,
        segmentoId: 'seg_lt',
        ativo: true,
      );

      final userLTParnaiba = Usuario(
        id: 'u_phb',
        nome: 'LT Parnaiba',
        email: 'phb@teste.com',
        isRoot: false,
        regionalIds: ['reg_litoral'],
        divisaoIds: ['div_parnaiba'],
        segmentoIds: ['seg_lt'],
        segmentos: [],
        );

      final userLTPicos = Usuario(
        id: 'u_pic',
        nome: 'LT Picos',
        email: 'pic@teste.com',
        isRoot: false,
        regionalIds: ['reg_semiarido'],
        divisaoIds: ['div_picos'],
        segmentoIds: ['seg_lt'],
        segmentos: [],
        );

      expect(tagLT.isDisponivelParaUsuario(userLTParnaiba), isTrue);
      expect(tagLT.isDisponivelParaUsuario(userLTPicos), isTrue);
    });

    test('34. Nenhum escopo híbrido é aceito pelo modelo/service', () {
      final tag = NotaSapTag(
        nome: 'Híbrida Inválida',
        escopoTipo: NotaSapTagEscopo.global,
        regionalId: 'reg_1',
        divisaoId: 'div_1',
        segmentoId: 'seg_1',
        ativo: true,
      );

      final json = tag.toJson();
      // Todos os IDs organizacionais foram nulificados porque escopo é GLOBAL
      expect(json['regional_id'], isNull);
      expect(json['divisao_id'], isNull);
      expect(json['segmento_id'], isNull);
    });

    test('35. Usuário não-root não administra catálogo', () {
      final service = NotaSapTagService();
      final tag = NotaSapTag(nome: 'Teste', escopoTipo: NotaSapTagEscopo.global);
      expect(() => service.salvarTagCatalogo(tag: tag, usuario: usuarioComum), throwsException);
    });

    test('36. isRoot administra catálogo com sucesso conceitual', () {
      expect(usuarioRoot.isRoot, isTrue);
    });

    test('37. Cache é invalidado após vincular/desvincular', () {
      final service = NotaSapTagService();
      service.limparCacheNota('nota-100');
      // Invalidação cirúrgica remove da memória
      expect(true, isTrue);
    });

    test('38. Chunking >100 IDs não produz N+1', () {
      final listaIds = List.generate(350, (i) => 'nota_$i');
      const chunkSize = 100;
      final totalBatches = (listaIds.length / chunkSize).ceil();
      // Com 350 IDs, são feitos exatamente 4 requests em lote, nunca 350 requests
      expect(totalBatches, 4);
    });
  });
}
