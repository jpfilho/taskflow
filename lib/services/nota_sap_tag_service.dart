import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/nota_sap_tag.dart';
import 'usuario_service.dart';

class NotaSapTagService {
  static final NotaSapTagService _instance = NotaSapTagService._internal();
  factory NotaSapTagService({SupabaseClient? client}) {
    if (client != null) {
      _instance._client = client;
    }
    return _instance;
  }
  NotaSapTagService._internal();

  SupabaseClient? _client;
  SupabaseClient get _supabase => _client ?? SupabaseConfig.client;

  // Cache em memória de tags por nota_sap_id
  final Map<String, List<NotaSapTag>> _tagsPorNotaCache = {};
  DateTime? _ultimoCacheFetch;
  static const Duration _cacheTtl = Duration(minutes: 5);
  static const int _batchChunkSize = 100;

  /// Limpa todo o cache em memória.
  void limparCache() {
    _tagsPorNotaCache.clear();
    _ultimoCacheFetch = null;
  }

  /// Invalida cirurgicamente o cache de uma nota específica.
  void limparCacheNota(String notaSapId) {
    _tagsPorNotaCache.remove(notaSapId);
  }

  // ---------------------------------------------------------------------------
  // 1. CATÁLOGO DE TAGS: CONSULTA & DISPONIBILIDADE POR PERFIL
  // ---------------------------------------------------------------------------

  /// Lista as tags do catálogo disponíveis para ATRIBUIÇÃO pelo perfil do usuário.
  /// Usuário comum: GLOBAL + Regionais do usuário + Divisões do usuário + Segmentos do usuário (apenas ativo=true).
  /// Root: Todas as tags com ativo=true.
  Future<List<NotaSapTag>> listarCatalogoDisponivel({required Usuario usuario}) async {
    try {
      final query = _supabase
          .from('notas_sap_tags')
          .select()
          .eq('ativo', true)
          .order('nome');

      final res = await query as List;
      final todas = res.map((m) => NotaSapTag.fromMap(m as Map<String, dynamic>)).toList();

      if (usuario.isRoot) {
        return todas;
      }

      return todas.where((tag) => tag.isDisponivelParaAtribuicao(
        isRoot: usuario.isRoot,
        regionalIds: usuario.regionalIds,
        divisaoIds: usuario.divisaoIds,
        segmentoIds: usuario.segmentoIds,
      )).toList();
    } catch (e) {
      debugPrint('⚠️ [NotaSapTagService] Erro ao listar tags disponíveis: $e');
      return [];
    }
  }

  /// Lista todas as tags ativas do catálogo para fins de filtros e consultas gerais.
  Future<List<NotaSapTag>> listarTodasTagsAtivas() async {
    try {
      final res = await _supabase
          .from('notas_sap_tags')
          .select()
          .eq('ativo', true)
          .order('nome') as List;
      return res.map((m) => NotaSapTag.fromMap(m as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('⚠️ [NotaSapTagService] Erro ao listar todas tags ativas: $e');
      return [];
    }
  }

  /// Lista tags disponíveis para exibição no filtro de acordo com o perfil do usuário logado.
  /// - Se usuario for root: todas as tags ativas.
  /// - Se usuario não for root: apenas tags ativas com escopo Global, ou pertencentes
  ///   às regionais, divisões ou segmentos do usuário.
  /// - Se usuario for nulo: fallback para tags ativas com escopo Global.
  Future<List<NotaSapTag>> listarTagsDisponiveisParaFiltro({Usuario? usuario}) async {
    try {
      final todas = await listarTodasTagsAtivas();

      if (usuario == null) {
        return todas.where((tag) => tag.escopoTipo == NotaSapTagEscopo.global).toList();
      }

      if (usuario.isRoot) {
        return todas;
      }

      return todas.where((tag) => tag.isDisponivelParaAtribuicao(
        isRoot: usuario.isRoot,
        regionalIds: usuario.regionalIds,
        divisaoIds: usuario.divisaoIds,
        segmentoIds: usuario.segmentoIds,
      )).toList();
    } catch (e) {
      debugPrint('⚠️ [NotaSapTagService] Erro ao listar tags para filtro: $e');
      return [];
    }
  }

  /// Lista catálogo completo (ativas e inativas) com contagem de notas vinculadas.
  /// Exclusivo para administração por usuários isRoot.
  Future<List<NotaSapTag>> listarCatalogoCompletoAdmin({required Usuario usuario}) async {
    if (!usuario.isRoot) {
      throw Exception('Acesso restrito: apenas administradores (root) podem gerenciar o catálogo.');
    }

    try {
      final resTags = await _supabase
          .from('notas_sap_tags')
          .select()
          .order('escopo_tipo')
          .order('nome') as List;

      final tags = resTags.map((m) => NotaSapTag.fromMap(m as Map<String, dynamic>)).toList();

      // Buscar contagem de uso de cada tag
      final resContagens = await _supabase
          .from('notas_sap_tags_vinculos')
          .select('tag_id') as List;

      final contagemMap = <String, int>{};
      for (final item in resContagens) {
        final tId = item['tag_id']?.toString() ?? '';
        if (tId.isNotEmpty) {
          contagemMap[tId] = (contagemMap[tId] ?? 0) + 1;
        }
      }

      return tags.map((t) => t.copyWith(totalNotas: contagemMap[t.id] ?? 0)).toList();
    } catch (e) {
      debugPrint('⚠️ [NotaSapTagService] Erro ao listar catálogo admin: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // 2. VÍNCULOS: LISTAGEM DA NOTA & BATCH HYDRATION (SEM N+1)
  // ---------------------------------------------------------------------------

  /// Lista TODAS as tags vinculadas a uma nota específica.
  /// NÃO filtra pelo perfil do usuário atual (visualização ampla e consistente).
  Future<List<NotaSapTag>> listarTagsDaNota(String notaSapId) async {
    if (notaSapId.isEmpty) return [];

    try {
      final res = await _supabase
          .from('notas_sap_tags_vinculos')
          .select('tag_id, origem, created_at, created_by, notas_sap_tags(*)')
          .eq('nota_sap_id', notaSapId) as List;

      final tags = <NotaSapTag>[];
      for (final row in res) {
        final tagMap = row['notas_sap_tags'] as Map<String, dynamic>?;
        if (tagMap != null) {
          tags.add(NotaSapTag.fromMap(tagMap));
        }
      }

      // Atualizar cache cirurgicamente
      _tagsPorNotaCache[notaSapId] = tags;
      return tags;
    } catch (e) {
      debugPrint('⚠️ [NotaSapTagService] Erro ao listar tags da nota $notaSapId: $e');
      return _tagsPorNotaCache[notaSapId] ?? [];
    }
  }

  /// Busca em lote as tags de uma lista de notas SAP com chunking de até 100 IDs.
  /// Retorna `Map<String, List<NotaSapTag>>` sem N+1 queries.
  Future<Map<String, List<NotaSapTag>>> buscarTagsEmLote(
    List<String> notaSapIds, {
    bool forceRefresh = false,
  }) async {
    if (notaSapIds.isEmpty) return {};

    final agora = DateTime.now();
    final idsParaBuscar = <String>[];
    final resultadoFinal = <String, List<NotaSapTag>>{};

    // Verificar itens em cache se não for refresh forçado
    if (!forceRefresh &&
        _ultimoCacheFetch != null &&
        agora.difference(_ultimoCacheFetch!) < _cacheTtl) {
      for (final id in notaSapIds) {
        if (_tagsPorNotaCache.containsKey(id)) {
          resultadoFinal[id] = _tagsPorNotaCache[id]!;
        } else {
          idsParaBuscar.add(id);
        }
      }
    } else {
      idsParaBuscar.addAll(notaSapIds);
    }

    if (idsParaBuscar.isEmpty) return resultadoFinal;

    // Executar consultas chunked (até 100 IDs por query)
    for (var i = 0; i < idsParaBuscar.length; i += _batchChunkSize) {
      final fim = (i + _batchChunkSize > idsParaBuscar.length)
          ? idsParaBuscar.length
          : i + _batchChunkSize;
      final chunk = idsParaBuscar.sublist(i, fim);

      try {
        final res = await _supabase
            .from('notas_sap_tags_vinculos')
            .select('nota_sap_id, tag_id, notas_sap_tags(*)')
            .inFilter('nota_sap_id', chunk) as List;

        // Inicializar listas vazias para todos os IDs do chunk
        for (final id in chunk) {
          resultadoFinal[id] = [];
        }

        // Popular tags encontradas
        for (final row in res) {
          final nId = row['nota_sap_id']?.toString() ?? '';
          final tagMap = row['notas_sap_tags'] as Map<String, dynamic>?;
          if (nId.isNotEmpty && tagMap != null) {
            resultadoFinal[nId]?.add(NotaSapTag.fromMap(tagMap));
          }
        }

        // Atualizar cache
        for (final entry in resultadoFinal.entries) {
          _tagsPorNotaCache[entry.key] = entry.value;
        }
      } catch (e) {
        debugPrint('⚠️ [NotaSapTagService] Erro no chunk de tags em lote: $e');
      }
    }

    _ultimoCacheFetch = agora;
    return resultadoFinal;
  }

  // ---------------------------------------------------------------------------
  // 3. VINCULAR & DESVINCULAR (COM VALIDAÇÃO DE ESCOPO NO SERVICE)
  // ---------------------------------------------------------------------------

  /// Vincula uma Tag a uma Nota SAP.
  /// Valida se a Tag está ativa e disponível para o perfil do usuário antes de inserir.
  Future<void> vincularTag({
    required String notaSapId,
    required String tagId,
    required Usuario usuario,
    String origem = 'MANUAL',
  }) async {
    if (notaSapId.isEmpty || tagId.isEmpty) {
      throw ArgumentError('notaSapId e tagId são obrigatórios');
    }

    // 1. Buscar a Tag no banco para validação rigorosa de escopo e status
    final resTag = await _supabase
        .from('notas_sap_tags')
        .select()
        .eq('id', tagId)
        .maybeSingle();

    if (resTag == null) {
      throw Exception('Tag não encontrada no catálogo');
    }

    final tag = NotaSapTag.fromMap(resTag);
    if (!tag.ativo) {
      throw Exception('Não é permitido vincular uma Tag inativa.');
    }

    // 2. Validar perfil do usuário (Item 31)
    if (!tag.isDisponivelParaAtribuicao(
      isRoot: usuario.isRoot,
      regionalIds: usuario.regionalIds,
      divisaoIds: usuario.divisaoIds,
      segmentoIds: usuario.segmentoIds,
    )) {
      throw Exception('A Tag "${tag.nome}" não está disponível para o escopo organizacional do seu usuário.');
    }

    // 3. Inserir vínculo
    final payload = {
      'nota_sap_id': notaSapId,
      'tag_id': tagId,
      'origem': origem.toUpperCase(),
      'created_by': usuario.id,
    };

    await _supabase.from('notas_sap_tags_vinculos').insert(payload);

    // Invalidação cirúrgica do cache para a nota
    _tagsPorNotaCache.remove(notaSapId);
  }

  /// Remove o vínculo de uma Tag com uma Nota SAP.
  /// Remove apenas o registro de `notas_sap_tags_vinculos` (preserva a Tag no catálogo).
  Future<void> desvincularTag({
    required String notaSapId,
    required String tagId,
  }) async {
    if (notaSapId.isEmpty || tagId.isEmpty) {
      throw ArgumentError('notaSapId e tagId são obrigatórios');
    }

    await _supabase
        .from('notas_sap_tags_vinculos')
        .delete()
        .eq('nota_sap_id', notaSapId)
        .eq('tag_id', tagId);

    // Invalidação cirúrgica do cache para a nota
    _tagsPorNotaCache.remove(notaSapId);
  }

  // ---------------------------------------------------------------------------
  // 4. ADMINISTRAÇÃO DO CATÁLOGO (EXCLUSIVO ROOT)
  // ---------------------------------------------------------------------------

  /// Cria ou edita uma Tag no catálogo.
  /// Garante limpeza de IDs irrelevantes conforme o escopo e normalização do nome.
  Future<NotaSapTag> salvarTagCatalogo({
    required NotaSapTag tag,
    required Usuario usuario,
  }) async {
    if (!usuario.isRoot) {
      if (tag.escopoTipo == NotaSapTagEscopo.global) {
        throw Exception('Apenas administradores (root) podem gerenciar tags com escopo Global.');
      }
      if (!tag.isDisponivelParaAtribuicao(
        isRoot: usuario.isRoot,
        regionalIds: usuario.regionalIds,
        divisaoIds: usuario.divisaoIds,
        segmentoIds: usuario.segmentoIds,
      )) {
        throw Exception('Você só pode criar Tags vinculadas ao seu escopo organizacional.');
      }
      if (tag.id != null && tag.id!.isNotEmpty && tag.createdBy != usuario.id) {
        throw Exception('Apenas administradores (root) podem editar Tags criadas por terceiros.');
      }
    }

    final nomeLimpo = tag.nome.trim();
    if (nomeLimpo.isEmpty) {
      throw ArgumentError('O nome da Tag não pode ser vazio.');
    }

    final payload = tag.toMap(incluirId: false);
    payload['nome'] = nomeLimpo;
    payload['nome_normalizado'] = nomeLimpo.toLowerCase();
    payload['created_by'] = usuario.id;

    // Garantir rigor do escopo (Item 53)
    switch (tag.escopoTipo) {
      case NotaSapTagEscopo.global:
        payload['regional_id'] = null;
        payload['divisao_id'] = null;
        payload['segmento_id'] = null;
        break;
      case NotaSapTagEscopo.regional:
        if (tag.regionalId == null || tag.regionalId!.isEmpty) {
          throw ArgumentError('Regional é obrigatória para o escopo REGIONAL.');
        }
        payload['regional_id'] = tag.regionalId;
        payload['divisao_id'] = null;
        payload['segmento_id'] = null;
        break;
      case NotaSapTagEscopo.divisao:
        if (tag.divisaoId == null || tag.divisaoId!.isEmpty) {
          throw ArgumentError('Divisão é obrigatória para o escopo DIVISAO.');
        }
        payload['regional_id'] = null;
        payload['divisao_id'] = tag.divisaoId;
        payload['segmento_id'] = null;
        break;
      case NotaSapTagEscopo.segmento:
        if (tag.segmentoId == null || tag.segmentoId!.isEmpty) {
          throw ArgumentError('Segmento é obrigatório para o escopo SEGMENTO.');
        }
        payload['regional_id'] = null;
        payload['divisao_id'] = null;
        payload['segmento_id'] = tag.segmentoId;
        break;
    }

    final idTag = tag.id;
    if (idTag == null || idTag.isEmpty) {
      final res = await _supabase
          .from('notas_sap_tags')
          .insert(payload)
          .select()
          .single();
      _limparCacheTotal();
      return NotaSapTag.fromMap(res);
    } else {
      payload['updated_at'] = DateTime.now().toIso8601String();
      final res = await _supabase
          .from('notas_sap_tags')
          .update(payload)
          .eq('id', idTag)
          .select()
          .single();
      _limparCacheTotal();
      return NotaSapTag.fromMap(res);
    }
  }

  /// Desativa uma Tag no catálogo (impede novos vínculos, preserva existentes).
  Future<void> desativarTagCatalogo({
    required String tagId,
    required Usuario usuario,
  }) async {
    if (!usuario.isRoot) {
      throw Exception('Apenas administradores (root) podem desativar Tags.');
    }

    await _supabase
        .from('notas_sap_tags')
        .update({
          'ativo': false,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', tagId);

    _limparCacheTotal();
  }

  /// Reativa uma Tag no catálogo.
  Future<void> reativarTagCatalogo({
    required String tagId,
    required Usuario usuario,
  }) async {
    if (!usuario.isRoot) {
      throw Exception('Apenas administradores (root) podem reativar Tags.');
    }

    await _supabase
        .from('notas_sap_tags')
        .update({
          'ativo': true,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', tagId);

    _limparCacheTotal();
  }

  /// Conta quantas notas estão vinculadas a uma Tag.
  Future<int> contarNotasComTag(String tagId) async {
    try {
      final res = await _supabase
          .from('notas_sap_tags_vinculos')
          .select('id')
          .eq('tag_id', tagId) as List;
      return res.length;
    } catch (e) {
      return 0;
    }
  }

  /// Limpa o cache em memória de tags e vínculos
  void limparCacheTotal() {
    _tagsPorNotaCache.clear();
    _ultimoCacheFetch = null;
  }

  void _limparCacheTotal() => limparCacheTotal();

  /// Para testes automatizados
  @visibleForTesting
  void limparCacheParaTestes() {
    limparCacheTotal();
  }
}
