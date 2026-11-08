import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/models/nota_sap_tag.dart';
import 'package:task2026/services/usuario_service.dart';

void main() {
  group('Filtro de Tags por Perfil do Usuário na Análise de Notas', () {
    final tagGlobal = NotaSapTag(
      id: 'tag_global',
      nome: 'Urgente Global',
      escopoTipo: NotaSapTagEscopo.global,
      ativo: true,
    );

    final tagRegionalNorte = NotaSapTag(
      id: 'tag_reg_norte',
      nome: 'Regional Norte Tag',
      escopoTipo: NotaSapTagEscopo.regional,
      regionalId: 'reg_norte',
      ativo: true,
    );

    final tagRegionalSul = NotaSapTag(
      id: 'tag_reg_sul',
      nome: 'Regional Sul Tag',
      escopoTipo: NotaSapTagEscopo.regional,
      regionalId: 'reg_sul',
      ativo: true,
    );

    final tagDivisaoTeresina = NotaSapTag(
      id: 'tag_div_the',
      nome: 'Divisão Teresina Tag',
      escopoTipo: NotaSapTagEscopo.divisao,
      divisaoId: 'div_teresina',
      ativo: true,
    );

    final tagDivisaoFloriano = NotaSapTag(
      id: 'tag_div_flo',
      nome: 'Divisão Floriano Tag',
      escopoTipo: NotaSapTagEscopo.divisao,
      divisaoId: 'div_floriano',
      ativo: true,
    );

    final tagSegmentoLT = NotaSapTag(
      id: 'tag_seg_lt',
      nome: 'Segmento LT Tag',
      escopoTipo: NotaSapTagEscopo.segmento,
      segmentoId: 'seg_lt',
      ativo: true,
    );

    final tagSegmentoSE = NotaSapTag(
      id: 'tag_seg_se',
      nome: 'Segmento SE Tag',
      escopoTipo: NotaSapTagEscopo.segmento,
      segmentoId: 'seg_se',
      ativo: true,
    );

    final tagInativaNorte = NotaSapTag(
      id: 'tag_inativa_norte',
      nome: 'Inativa Norte',
      escopoTipo: NotaSapTagEscopo.regional,
      regionalId: 'reg_norte',
      ativo: false,
    );

    final catalogoCompleto = [
      tagGlobal,
      tagRegionalNorte,
      tagRegionalSul,
      tagDivisaoTeresina,
      tagDivisaoFloriano,
      tagSegmentoLT,
      tagSegmentoSE,
      tagInativaNorte,
    ];

    List<String> calcularTagsDisponiveisParaUsuario(Usuario? usuario, List<NotaSapTag> catalogo) {
      final tagNomesSet = <String>{};
      for (final tag in catalogo) {
        if (!tag.ativo) continue;
        final permitida = usuario == null
            ? (tag.escopoTipo == NotaSapTagEscopo.global)
            : (usuario.isRoot ||
                tag.isDisponivelParaAtribuicao(
                  isRoot: usuario.isRoot,
                  regionalIds: usuario.regionalIds,
                  divisaoIds: usuario.divisaoIds,
                  segmentoIds: usuario.segmentoIds,
                ));
        if (permitida && tag.nome.isNotEmpty) {
          tagNomesSet.add(tag.nome);
        }
      }
      return tagNomesSet.toList()..sort();
    }

    test('1. Usuário Norte/Teresina/LT só vê Global, Regional Norte, Divisão Teresina e Segmento LT', () {
      final usuarioLT = Usuario(
        id: 'u_lt',
        email: 'tecnico.lt@empresa.com',
        isRoot: false,
        regionalIds: ['reg_norte'],
        divisaoIds: ['div_teresina'],
        segmentoIds: ['seg_lt'],
        regionais: ['Norte'],
        divisoes: ['Teresina'],
        segmentos: ['Linhas de Transmissão'],
      );

      final tags = calcularTagsDisponiveisParaUsuario(usuarioLT, catalogoCompleto);

      expect(tags, contains('Urgente Global'));
      expect(tags, contains('Regional Norte Tag'));
      expect(tags, contains('Divisão Teresina Tag'));
      expect(tags, contains('Segmento LT Tag'));

      // NÃO deve conter tags de outras regionais, divisões ou segmentos
      expect(tags.contains('Regional Sul Tag'), isFalse);
      expect(tags.contains('Divisão Floriano Tag'), isFalse);
      expect(tags.contains('Segmento SE Tag'), isFalse);
      expect(tags.contains('Inativa Norte'), isFalse);
    });

    test('2. Usuário Sul/Floriano/SE só vê Global, Regional Sul, Divisão Floriano e Segmento SE', () {
      final usuarioSE = Usuario(
        id: 'u_se',
        email: 'tecnico.se@empresa.com',
        isRoot: false,
        regionalIds: ['reg_sul'],
        divisaoIds: ['div_floriano'],
        segmentoIds: ['seg_se'],
        regionais: ['Sul'],
        divisoes: ['Floriano'],
        segmentos: ['Subestações'],
      );

      final tags = calcularTagsDisponiveisParaUsuario(usuarioSE, catalogoCompleto);

      expect(tags, contains('Urgente Global'));
      expect(tags, contains('Regional Sul Tag'));
      expect(tags, contains('Divisão Floriano Tag'));
      expect(tags, contains('Segmento SE Tag'));

      expect(tags.contains('Regional Norte Tag'), isFalse);
      expect(tags.contains('Divisão Teresina Tag'), isFalse);
      expect(tags.contains('Segmento LT Tag'), isFalse);
    });

    test('3. Usuário isRoot vê todas as tags ativas de qualquer escopo', () {
      final usuarioRoot = Usuario(
        id: 'u_root',
        email: 'root@empresa.com',
        isRoot: true,
      );

      final tags = calcularTagsDisponiveisParaUsuario(usuarioRoot, catalogoCompleto);

      expect(tags, contains('Urgente Global'));
      expect(tags, contains('Regional Norte Tag'));
      expect(tags, contains('Regional Sul Tag'));
      expect(tags, contains('Divisão Teresina Tag'));
      expect(tags, contains('Divisão Floriano Tag'));
      expect(tags, contains('Segmento LT Tag'));
      expect(tags, contains('Segmento SE Tag'));
      // Inativa não deve aparecer
      expect(tags.contains('Inativa Norte'), isFalse);
    });

    test('4. Usuário nulo/deslogado só vê tags com escopo Global', () {
      final tags = calcularTagsDisponiveisParaUsuario(null, catalogoCompleto);

      expect(tags, contains('Urgente Global'));
      expect(tags.length, 1);
      expect(tags.contains('Regional Norte Tag'), isFalse);
      expect(tags.contains('Segmento LT Tag'), isFalse);
    });

    test('5. Sanitização de tags selecionadas purga opções fora do perfil', () {
      final usuarioLT = Usuario(
        id: 'u_lt',
        email: 'tecnico.lt@empresa.com',
        isRoot: false,
        regionalIds: ['reg_norte'],
        divisaoIds: ['div_teresina'],
        segmentoIds: ['seg_lt'],
      );

      final tagsPermitidas = calcularTagsDisponiveisParaUsuario(usuarioLT, catalogoCompleto);
      final filtroAtivo = {'Segmento LT Tag', 'Segmento SE Tag', 'Urgente Global'};

      // Purga tags não permitidas
      filtroAtivo.removeWhere((t) => !tagsPermitidas.contains(t));

      expect(filtroAtivo, contains('Segmento LT Tag'));
      expect(filtroAtivo, contains('Urgente Global'));
      expect(filtroAtivo.contains('Segmento SE Tag'), isFalse);
    });
  });
}

