import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/nota_sap_analise.dart';
import '../models/nota_sap_analise_evidencia.dart';
import '../models/nota_sap_anotacao.dart';
import '../features/media_albums/data/models/media_image.dart';
import 'nota_anotacao_rasterizer_service.dart';

/// Serviço dedicado para gestão da Análise Prévia de Notas SAP
/// Totalmente desacoplado da ingestão do SAP e da criação de tarefas.
class NotaSapAnaliseService {
  static final NotaSapAnaliseService _instance =
      NotaSapAnaliseService._internal();
  factory NotaSapAnaliseService() => _instance;
  NotaSapAnaliseService._internal();

  SupabaseClient get _supabase => SupabaseConfig.client;

  static const String _defaultBucket = 'notas-sap-anexos';
  static const int _batchChunkSize = 100;
  static const Duration _cacheTtl = Duration(minutes: 2);

  // Cache em memória para o resumo dos badges
  final Map<String, NotaSapResumoAnalise> _resumoCache = {};
  DateTime? _ultimoCacheFetch;

  // Cache em memória de Signed URLs: 'bucket:caminho' -> {url, expiraEm}
  final Map<String, ({String url, DateTime expiraEm})> _signedUrlCache = {};

  // Canais Realtime ativos por nota_sap_id
  final Map<String, RealtimeChannel> _canaisAtivos = {};

  // ============================================================================
  // 1. MÉTODOS DE ANÁLISE TÉCNICA
  // ============================================================================

  /// Busca a análise técnica de uma Nota SAP pelo ID da nota.
  /// Retorna NULL se a análise não existir (NÃO cria registro vazio automaticamente).
  Future<NotaSapAnalise?> buscarAnalise(String notaSapId) async {
    try {
      if (notaSapId.trim().isEmpty) return null;

      final response = await _supabase
          .from('notas_sap_analises')
          .select()
          .eq('nota_sap_id', notaSapId)
          .maybeSingle();

      if (response == null) return null;
      return NotaSapAnalise.fromMap(response);
    } catch (e) {
      debugPrint('❌ [NotaSapAnaliseService.buscarAnalise] Erro: $e');
      rethrow;
    }
  }

  /// Busca as análises técnicas para uma lista de notas SAP em lote (Anti N+1).
  /// Retorna um mapa indexado por nota_sap_id com as análises existentes.
  Future<Map<String, NotaSapAnalise>> buscarAnalises(
    List<String> notaSapIds,
  ) async {
    try {
      final idsValidos = notaSapIds.where((id) => id.trim().isNotEmpty).toList();
      if (idsValidos.isEmpty) return {};

      final response = await _supabase
          .from('notas_sap_analises')
          .select()
          .inFilter('nota_sap_id', idsValidos);

      final mapa = <String, NotaSapAnalise>{};
      for (final item in (response as List)) {
        final analise = NotaSapAnalise.fromMap(item as Map<String, dynamic>);
        mapa[analise.notaSapId] = analise;
      }
      return mapa;
    } catch (e) {
      debugPrint('❌ [NotaSapAnaliseService.buscarAnalises] Erro: $e');
      rethrow;
    }
  }

  /// Salva ou atualiza a análise técnica (Upsert por nota_sap_id).
  /// Somente deve ser chamado quando houver ação explícita de preenchimento.
  Future<NotaSapAnalise> salvarAnalise(NotaSapAnalise analise) async {
    final payload = analise.toMap();
    payload.remove('created_at');
    payload['updated_at'] = DateTime.now().toIso8601String();

    try {
      final response = await _supabase
          .from('notas_sap_analises')
          .upsert(
            payload,
            onConflict: 'nota_sap_id',
          )
          .select()
          .single();

      invalidarCache(analise.notaSapId);
      return NotaSapAnalise.fromMap(response);
    } catch (e) {
      // Se analista_id falhar por constraint de chave estrangeira (FK notas_sap_analises_analista_id_fkey)
      // porque o usuário logado é de usuarios e não executores, realiza retry com analista_id = null
      if (e is PostgrestException &&
          e.code == '23503' &&
          (e.message.contains('analista_id_fkey') ||
              (e.details?.toString().contains('executores') ?? false))) {
        debugPrint(
            '⚠️ [NotaSapAnaliseService.salvarAnalise] analista_id não presente em executores. Realizando fallback para analista_id = null.');
        try {
          payload['analista_id'] = null;
          final retryResponse = await _supabase
              .from('notas_sap_analises')
              .upsert(
                payload,
                onConflict: 'nota_sap_id',
              )
              .select()
              .single();

          invalidarCache(analise.notaSapId);
          return NotaSapAnalise.fromMap(retryResponse);
        } catch (retryError) {
          debugPrint('❌ [NotaSapAnaliseService.salvarAnalise] Erro no retry: $retryError');
          rethrow;
        }
      }

      // Se valor_pv não existir na tabela (coluna ainda não criada via migration),
      // realiza retry sem valor_pv para não bloquear o salvamento
      if (e is PostgrestException &&
          (e.code == '42703' ||
              e.message.contains('valor_pv') ||
              (e.details?.toString().contains('valor_pv') ?? false))) {
        debugPrint(
            '⚠️ [NotaSapAnaliseService.salvarAnalise] Coluna valor_pv ainda não existe no banco. Salvando sem valor_pv.');
        try {
          payload.remove('valor_pv');
          final retryResponse = await _supabase
              .from('notas_sap_analises')
              .upsert(
                payload,
                onConflict: 'nota_sap_id',
              )
              .select()
              .single();

          invalidarCache(analise.notaSapId);
          return NotaSapAnalise.fromMap(retryResponse);
        } catch (retryError) {
          debugPrint(
              '❌ [NotaSapAnaliseService.salvarAnalise] Erro no retry sem valor_pv: $retryError');
          rethrow;
        }
      }

      debugPrint('❌ [NotaSapAnaliseService.salvarAnalise] Erro: $e');
      rethrow;
    }
  }

  /// Atualiza apenas o status da análise de forma atômica
  Future<void> atualizarStatusAnalise(
    String notaSapId,
    NotaAnaliseStatus novoStatus,
  ) async {
    try {
      await _supabase.from('notas_sap_analises').upsert({
        'nota_sap_id': notaSapId,
        'status_analise': novoStatus.toDbString(),
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'nota_sap_id');

      invalidarCache(notaSapId);
    } catch (e) {
      debugPrint('❌ [NotaSapAnaliseService.atualizarStatusAnalise] Erro: $e');
      rethrow;
    }
  }

  // ============================================================================
  // 2. MÉTODOS DE MATERIAIS E PEÇAS
  // ============================================================================

  /// Lista os materiais cadastrados para a Nota SAP
  Future<List<NotaSapMaterial>> listarMateriais(String notaSapId) async {
    try {
      final response = await _supabase
          .from('notas_sap_analise_materiais')
          .select()
          .eq('nota_sap_id', notaSapId)
          .order('created_at', ascending: true);

      return (response as List)
          .map((m) => NotaSapMaterial.fromMap(m as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ [NotaSapAnaliseService.listarMateriais] Erro: $e');
      rethrow;
    }
  }

  /// Adiciona um novo material à análise da Nota
  Future<NotaSapMaterial> adicionarMaterial(NotaSapMaterial material) async {
    try {
      final payload = material.toMap();
      payload.remove('id');
      payload.remove('created_at');
      payload.remove('updated_at');

      final response = await _supabase
          .from('notas_sap_analise_materiais')
          .insert(payload)
          .select()
          .single();

      invalidarCache(material.notaSapId);
      return NotaSapMaterial.fromMap(response);
    } catch (e) {
      debugPrint('❌ [NotaSapAnaliseService.adicionarMaterial] Erro: $e');
      rethrow;
    }
  }

  /// Atualiza informações de um material existente (ex: alteração de status)
  Future<NotaSapMaterial> atualizarMaterial(NotaSapMaterial material) async {
    try {
      if (material.id == null) {
        throw ArgumentError('ID do material obrigatório para atualização');
      }

      final payload = material.toMap();
      payload.remove('id');
      payload.remove('created_at');
      payload['updated_at'] = DateTime.now().toIso8601String();

      final response = await _supabase
          .from('notas_sap_analise_materiais')
          .update(payload)
          .eq('id', material.id!)
          .select()
          .single();

      invalidarCache(material.notaSapId);
      return NotaSapMaterial.fromMap(response);
    } catch (e) {
      debugPrint('❌ [NotaSapAnaliseService.atualizarMaterial] Erro: $e');
      rethrow;
    }
  }

  /// Exclui um material da lista
  Future<void> excluirMaterial(String materialId, {String? notaSapId}) async {
    try {
      await _supabase
          .from('notas_sap_analise_materiais')
          .delete()
          .eq('id', materialId);

      if (notaSapId != null) invalidarCache(notaSapId);
    } catch (e) {
      debugPrint('❌ [NotaSapAnaliseService.excluirMaterial] Erro: $e');
      rethrow;
    }
  }

  // ============================================================================
  // 3. MÉTODOS DE ANEXOS E FOTOS
  // ============================================================================

  /// Lista anexos cadastrados para a Nota com versões de anotação enriquecidas em batch.
  /// Por padrão, considera anexo_derivado_de_id IS NULL para não inflar grids e contadores.
  Future<List<NotaSapAnexo>> listarAnexos(String notaSapId) async {
    try {
      final response = await _supabase
          .from('notas_sap_anexos')
          .select()
          .eq('nota_sap_id', notaSapId)
          .isFilter('anexo_derivado_de_id', null)
          .order('created_at', ascending: false);

      final list = (response as List)
          .map((a) => NotaSapAnexo.fromMap(a as Map<String, dynamic>))
          .toList();

      if (list.isNotEmpty) {
        final ids = list.map((a) => a.id).whereType<String>().toList();
        final versoes = await obterUltimasVersoesAnotacoes(ids);
        return list.map((a) {
          final v = a.id != null ? (versoes[a.id!] ?? 0) : 0;
          return a.copyWith(versaoAnotacao: v);
        }).toList();
      }

      return list;
    } catch (e) {
      debugPrint('❌ [NotaSapAnaliseService.listarAnexos] Erro: $e');
      rethrow;
    }
  }

  /// Lista anexos para múltiplas Notas SAP em batch agrupadas por nota_sap_id.
  Future<Map<String, List<NotaSapAnexo>>> listarAnexosPorNotas(List<String> notaSapIds) async {
    if (notaSapIds.isEmpty) return {};
    try {
      final response = await _supabase
          .from('notas_sap_anexos')
          .select()
          .inFilter('nota_sap_id', notaSapIds)
          .isFilter('anexo_derivado_de_id', null)
          .order('created_at', ascending: false);

      final list = (response as List)
          .map((a) => NotaSapAnexo.fromMap(a as Map<String, dynamic>))
          .toList();

      final ids = list.map((a) => a.id).whereType<String>().toList();
      final versoes = ids.isNotEmpty ? await obterUltimasVersoesAnotacoes(ids) : <String, int>{};

      final map = <String, List<NotaSapAnexo>>{};
      for (final a in list) {
        final v = a.id != null ? (versoes[a.id!] ?? 0) : 0;
        final anexoComVersao = a.copyWith(versaoAnotacao: v);
        map.putIfAbsent(a.notaSapId, () => []).add(anexoComVersao);
      }
      return map;
    } catch (e) {
      debugPrint('❌ [NotaSapAnaliseService.listarAnexosPorNotas] Erro: $e');
      return {};
    }
  }

  /// Lista evidências derivadas associadas a um anexo original específico
  Future<List<NotaSapAnexo>> listarDerivadas(String anexoOriginalId) async {
    try {
      final response = await _supabase
          .from('notas_sap_anexos')
          .select()
          .eq('anexo_derivado_de_id', anexoOriginalId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((a) => NotaSapAnexo.fromMap(a as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ [NotaSapAnaliseService.listarDerivadas] Erro: $e');
      rethrow;
    }
  }

  /// Carrega as últimas versões de anotações em batch para uma lista de anexoIds
  Future<Map<String, int>> obterUltimasVersoesAnotacoes(List<String> anexoIds) async {
    if (anexoIds.isEmpty) return {};
    try {
      final response = await _supabase
          .from('notas_sap_anexos_anotacoes')
          .select('anexo_id, versao')
          .inFilter('anexo_id', anexoIds);

      final map = <String, int>{};
      for (final item in (response as List)) {
        final aid = item['anexo_id']?.toString() ?? '';
        final v = (item['versao'] as num?)?.toInt() ?? 0;
        if (v > (map[aid] ?? 0)) {
          map[aid] = v;
        }
      }
      return map;
    } catch (e) {
      debugPrint('⚠️ [obterUltimasVersoesAnotacoes] Erro: $e');
      return {};
    }
  }

  /// Obtém histórico completo de anotações de um anexo (ordenado por versão decrescente)
  Future<List<NotaSapAnotacao>> obterHistoricoAnotacoes(String anexoId) async {
    try {
      final response = await _supabase
          .from('notas_sap_anexos_anotacoes')
          .select()
          .eq('anexo_id', anexoId)
          .order('versao', ascending: false);

      return (response as List)
          .map((item) => NotaSapAnotacao.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ [obterHistoricoAnotacoes] Erro: $e');
      rethrow;
    }
  }

  /// Obtém a última versão da anotação de um anexo (se houver)
  Future<NotaSapAnotacao?> obterUltimaAnotacao(String anexoId) async {
    try {
      final response = await _supabase
          .from('notas_sap_anexos_anotacoes')
          .select()
          .eq('anexo_id', anexoId)
          .order('versao', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return NotaSapAnotacao.fromMap(response);
    } catch (e) {
      debugPrint('❌ [obterUltimaAnotacao] Erro: $e');
      return null;
    }
  }

  /// Salva uma nova versão append-only de anotação com retry contra concorrência
  Future<NotaSapAnotacao> salvarAnotacao({
    required String anexoId,
    required NotaSapAnotacaoDocumento dadosJson,
    int? imagemLargura,
    int? imagemAltura,
    String? criadoPor,
    String? criadoPorNome,
    int maxRetries = 3,
  }) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      attempts++;
      try {
        final ultima = await obterUltimaAnotacao(anexoId);
        final proximaVersao = (ultima?.versao ?? 0) + 1;

        final payload = <String, dynamic>{
          'anexo_id': anexoId,
          'versao': proximaVersao,
          'dados_json': dadosJson.toMap(),
          if (imagemLargura != null) 'imagem_largura': imagemLargura,
          if (imagemAltura != null) 'imagem_altura': imagemAltura,
          if (criadoPor != null) 'criado_por': criadoPor,
          if (criadoPorNome != null) 'criado_por_nome': criadoPorNome,
        };

        final response = await _supabase
            .from('notas_sap_anexos_anotacoes')
            .insert(payload)
            .select()
            .single();

        return NotaSapAnotacao.fromMap(response);
      } catch (e) {
        final errStr = e.toString();
        // Conflito de versão (unique_violation / código 23505)
        if (errStr.contains('23505') || errStr.toLowerCase().contains('unique')) {
          debugPrint('⚠️ [salvarAnotacao] Conflito de versão (tentativa $attempts/$maxRetries). Retentando...');
          if (attempts >= maxRetries) {
            throw Exception('Conflito concorrente ao salvar versão da anotação após $maxRetries tentativas.');
          }
          await Future.delayed(Duration(milliseconds: 50 * attempts));
          continue;
        }
        debugPrint('❌ [salvarAnotacao] Erro: $e');
        rethrow;
      }
    }
    throw Exception('Falha ao salvar anotação após $maxRetries tentativas.');
  }

  /// Gera a imagem PNG derivada a partir da anotação salva e da imagem original,
  /// enviando para o Storage com path determinístico e registrando a derivada de forma idempotente.
  Future<ResultadoGeracaoDerivada> gerarERegistrarDerivada({
    required NotaSapAnexo anexoOriginal,
    required NotaSapAnotacao anotacao,
    required Uint8List imagemOriginalBytes,
    NotaAnotacaoRasterizerService rasterizer = const NotaAnotacaoRasterizerService(),
  }) async {
    try {
      if (anexoOriginal.id == null || anexoOriginal.id!.isEmpty) {
        throw ArgumentError('O anexo original precisa ter ID válido.');
      }

      // 1. Rasterizar em memória na resolução do documento/imagem original
      final pngBytes = await rasterizer.rasterizarParaPng(
        imagemBytes: imagemOriginalBytes,
        documento: anotacao.dadosJson,
      );

      // 2. Calcular hash SHA-256 da derivada
      final hashSha256 = crypto.sha256.convert(pngBytes).toString();

      // 3. Path determinístico: <nota_sap_id>/derived/<anexo_id>/v<versao>.png
      final caminhoStorage =
          '${anexoOriginal.notaSapId}/derived/${anexoOriginal.id}/v${anotacao.versao}.png';
      const bucketDestino = _defaultBucket;

      // 4. Checar existência prévia para idempotência e rollback seguro
      final existente = await _supabase
          .from('notas_sap_anexos')
          .select('id, caminho_arquivo')
          .eq('caminho_arquivo', caminhoStorage)
          .maybeSingle();
      final jaExistiaAntes = existente != null;

      // 5. Upload do PNG para o Supabase Storage (sobrescreve de forma idempotente se mesma versão)
      await _supabase.storage.from(bucketDestino).uploadBinary(
            caminhoStorage,
            pngBytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/png',
            ),
          );

      // 6. Preparar metadados do registro derivado
      final nomeBase = anexoOriginal.nomeArquivo.contains('.')
          ? anexoOriginal.nomeArquivo
              .substring(0, anexoOriginal.nomeArquivo.lastIndexOf('.'))
          : anexoOriginal.nomeArquivo;
      final nomeDerivado = '${nomeBase}_anotada_v${anotacao.versao}.png';

      final payload = <String, dynamic>{
        'nota_sap_id': anexoOriginal.notaSapId,
        'anexo_derivado_de_id': anexoOriginal.id,
        'nome_arquivo': nomeDerivado,
        'nome_original': nomeDerivado,
        'tipo_arquivo': NotaAnexoTipo.imagem.toDbString(),
        'caminho_arquivo': caminhoStorage,
        'bucket': bucketDestino,
        'tamanho_bytes': pngBytes.length,
        'mime_type': 'image/png',
        'extensao': 'png',
        'origem': 'TASKFLOW',
        'sha256': hashSha256,
        'relevante_analise': false, // Relevância é exclusiva do original
      };

      try {
        final Map<String, dynamic> dbResp;
        if (jaExistiaAntes) {
          dbResp = await _supabase
              .from('notas_sap_anexos')
              .update(payload)
              .eq('id', existente['id'])
              .select()
              .single();
        } else {
          dbResp = await _supabase
              .from('notas_sap_anexos')
              .insert(payload)
              .select()
              .single();
        }

        invalidarCache(anexoOriginal.notaSapId);
        return ResultadoGeracaoDerivada(
          sucesso: true,
          anexoDerivado: NotaSapAnexo.fromMap(dbResp),
          pngBytes: pngBytes,
          sha256: hashSha256,
        );
      } catch (dbErr) {
        // Rollback seguro: se falhou a inserção no banco e o arquivo não existia antes, limpa o Storage
        if (!jaExistiaAntes) {
          try {
            await _supabase.storage
                .from(bucketDestino)
                .remove([caminhoStorage]);
          } catch (_) {}
        }
        return ResultadoGeracaoDerivada(
          sucesso: false,
          erro: 'Falha ao registrar metadados da imagem derivada no banco: $dbErr',
        );
      }
    } catch (e) {
      debugPrint('⚠️ [gerarERegistrarDerivada] Erro ao processar derivada: $e');
      return ResultadoGeracaoDerivada(
        sucesso: false,
        erro: 'Erro no processamento ou envio da evidência derivada: $e',
      );
    }
  }

  /// Obtém a derivada correspondente a uma versão específica de um anexo original
  Future<NotaSapAnexo?> obterDerivadaDaVersao(
    String anexoOriginalId,
    int versao,
  ) async {
    try {
      final sufixo = '/v$versao.png';
      final response = await _supabase
          .from('notas_sap_anexos')
          .select()
          .eq('anexo_derivado_de_id', anexoOriginalId)
          .like('caminho_arquivo', '%$sufixo')
          .maybeSingle();

      if (response == null) return null;
      return NotaSapAnexo.fromMap(response);
    } catch (e) {
      debugPrint('⚠️ [obterDerivadaDaVersao] Erro: $e');
      return null;
    }
  }

  /// Retorna a contagem de anotações e de imagens derivadas vinculadas ao anexo original
  Future<Map<String, dynamic>> obterContagemEvidenciasVinculadas(
    String anexoOriginalId,
  ) async {
    try {
      final futures = await Future.wait([
        _supabase
            .from('notas_sap_anexos_anotacoes')
            .select('id')
            .eq('anexo_id', anexoOriginalId),
        _supabase
            .from('notas_sap_anexos')
            .select('id')
            .eq('anexo_derivado_de_id', anexoOriginalId),
        _supabase
            .from('notas_sap_analise_evidencias')
            .select('tipo_vinculo')
            .eq('anexo_id', anexoOriginalId),
      ]);

      final anotacoesList = futures[0] as List;
      final derivadasList = futures[1] as List;
      final analiseList = futures[2] as List;

      final secoesUso = analiseList
          .map((item) => item['tipo_vinculo']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();

      return {
        'anotacoes': anotacoesList.length,
        'derivadas': derivadasList.length,
        'analise': analiseList.length,
        'secoes': secoesUso,
      };
    } catch (e) {
      debugPrint('⚠️ [obterContagemEvidenciasVinculadas] Erro: $e');
      return {'anotacoes': 0, 'derivadas': 0, 'analise': 0, 'secoes': <String>[]};
    }
  }

  /// Upload de arquivo a partir de `File` (Mobile / Desktop)
  Future<NotaSapAnexo> uploadAnexo({
    required String notaSapId,
    required File file,
    String? legenda,
    String? usuarioId,
    String? usuarioNome,
  }) async {
    final bytes = await file.readAsBytes();
    final nomeArquivo = file.path.split(Platform.pathSeparator).last;
    return uploadAnexoFromBytes(
      notaSapId: notaSapId,
      bytes: bytes,
      nomeArquivo: nomeArquivo,
      legenda: legenda,
      usuarioId: usuarioId,
      usuarioNome: usuarioNome,
    );
  }

  /// Upload de arquivo a partir de bytes (Web e comum)
  Future<NotaSapAnexo> uploadAnexoFromBytes({
    required String notaSapId,
    required Uint8List bytes,
    required String nomeArquivo,
    String? mimeType,
    String? legenda,
    String? usuarioId,
    String? usuarioNome,
  }) async {
    try {
      final nomeSanitizado = _sanitizeFileName(nomeArquivo);
      final mime = mimeType ?? _getMimeType(nomeSanitizado);
      final tipo = NotaAnexoTipo.deduzir(mime, nomeSanitizado);
      final ext = nomeArquivo.contains('.') ? nomeArquivo.split('.').last.toLowerCase() : null;

      final prefixoUnico = '${DateTime.now().millisecondsSinceEpoch}_${(bytes.length % 100000).toString().padLeft(5, '0')}';
      // Path canônico: <nota_sap_id>/<prefixo>_<arquivo> (sem o nome do bucket no path)
      final caminhoStorage = '$notaSapId/${prefixoUnico}_$nomeSanitizado';
      final bucketDestino = _defaultBucket;

      // 1. Upload para o Supabase Storage no bucket privado
      await _supabase.storage.from(bucketDestino).uploadBinary(
            caminhoStorage,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: mime,
            ),
          );

      // 2. Gravar metadados no banco
      final payload = <String, dynamic>{
        'nota_sap_id': notaSapId,
        'nome_arquivo': nomeArquivo,
        'nome_original': nomeArquivo,
        'tipo_arquivo': tipo.toDbString(),
        'caminho_arquivo': caminhoStorage,
        'bucket': bucketDestino,
        'tamanho_bytes': bytes.length,
        'mime_type': mime,
        if (ext != null) 'extensao': ext,
        'origem': 'TASKFLOW',
        if (legenda != null && legenda.isNotEmpty) 'legenda': legenda,
        if (usuarioId != null) 'usuario_id': usuarioId,
        if (usuarioNome != null) 'usuario_nome': usuarioNome,
        'relevante_analise': false,
      };

      final response = await _supabase
          .from('notas_sap_anexos')
          .insert(payload)
          .select()
          .single();

      invalidarCache(notaSapId);
      final anexo = NotaSapAnexo.fromMap(response);
      return anexo;
    } catch (e) {
      debugPrint('❌ [NotaSapAnaliseService.uploadAnexoFromBytes] Erro: $e');
      rethrow;
    }
  }

  /// Alterna o status de relevância para análise técnica
  Future<void> alternarRelevanteParaAnalise({
    required String anexoId,
    required String notaSapId,
    required bool relevante,
  }) async {
    try {
      await _supabase
          .from('notas_sap_anexos')
          .update({'relevante_analise': relevante})
          .eq('id', anexoId);

      invalidarCache(notaSapId);
    } catch (e) {
      debugPrint('❌ [NotaSapAnaliseService.alternarRelevanteParaAnalise] Erro: $e');
      rethrow;
    }
  }

  /// Registra anexo importado via script SAP respeitando idempotência
  Future<NotaSapAnexo?> registrarAnexoImportado({
    required String notaSapId,
    required String nomeArquivo,
    String? nomeOriginal,
    required String caminhoArquivo,
    String bucket = _defaultBucket,
    required int tamanhoBytes,
    String? mimeType,
    String? extensao,
    String origem = 'SAP',
    String? legenda,
    String? sapDocumentId,
    String? sha256,
    Map<String, dynamic> metadata = const {},
    DateTime? importadoEm,
  }) async {
    try {
      // 1. Idempotência por sap_document_id
      if (sapDocumentId != null && sapDocumentId.trim().isNotEmpty) {
        final existente = await _supabase
            .from('notas_sap_anexos')
            .select()
            .eq('nota_sap_id', notaSapId)
            .eq('sap_document_id', sapDocumentId.trim())
            .maybeSingle();

        if (existente != null) {
          return NotaSapAnexo.fromMap(existente);
        }
      }

      // 2. Idempotência por sha256
      if (sha256 != null && sha256.trim().isNotEmpty) {
        final existente = await _supabase
            .from('notas_sap_anexos')
            .select()
            .eq('nota_sap_id', notaSapId)
            .eq('sha256', sha256.trim())
            .maybeSingle();

        if (existente != null) {
          return NotaSapAnexo.fromMap(existente);
        }
      }

      final tipo = NotaAnexoTipo.deduzir(mimeType, nomeArquivo);
      final ext = extensao ?? (nomeArquivo.contains('.') ? nomeArquivo.split('.').last.toLowerCase() : null);

      final payload = <String, dynamic>{
        'nota_sap_id': notaSapId,
        'nome_arquivo': nomeArquivo,
        if (nomeOriginal != null) 'nome_original': nomeOriginal,
        'tipo_arquivo': tipo.toDbString(),
        'caminho_arquivo': caminhoArquivo,
        'bucket': bucket,
        'tamanho_bytes': tamanhoBytes,
        if (mimeType != null) 'mime_type': mimeType,
        if (ext != null) 'extensao': ext,
        'origem': origem,
        if (legenda != null && legenda.isNotEmpty) 'legenda': legenda,
        if (sapDocumentId != null) 'sap_document_id': sapDocumentId,
        if (sha256 != null) 'sha256': sha256,
        'metadata': metadata,
        'importado_em': (importadoEm ?? DateTime.now()).toIso8601String(),
        'relevante_analise': false,
      };

      final response = await _supabase
          .from('notas_sap_anexos')
          .insert(payload)
          .select()
          .single();

      invalidarCache(notaSapId);
      return NotaSapAnexo.fromMap(response);
    } catch (e) {
      debugPrint('❌ [NotaSapAnaliseService.registrarAnexoImportado] Erro: $e');
      rethrow;
    }
  }

  /// Exclui um anexo (limpa derivadas no Storage se for original, depois Banco)
  Future<void> excluirAnexo(NotaSapAnexo anexo) async {
    try {
      if (anexo.id != null) {
        // Proteção formal de integridade (RESTRICT): impede exclusão se em uso como evidência
        final evidenciasEmUsoResp = await _supabase
            .from('notas_sap_analise_evidencias')
            .select('id, tipo_vinculo, nota_sap_id, tipo_fonte')
            .eq('anexo_id', anexo.id!);

        final evidenciasEmUso = (evidenciasEmUsoResp as List<dynamic>?) ?? [];
        if (evidenciasEmUso.isNotEmpty) {
          final secoes = evidenciasEmUso
              .map((e) => (e as Map<String, dynamic>)['tipo_vinculo']?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toSet()
              .join(', ');
          throw StateError(
            'Este anexo está vinculado como evidência técnica formal na análise '
            '(seções: $secoes) e precisa ser desvinculado antes da exclusão.',
          );
        }
      }

      final bucketNome = anexo.bucketNome;

      // 1. Se for anexo original, remover todas as derivadas associadas do Storage e Banco
      if (anexo.id != null && anexo.isOriginal) {
        try {
          final derivadasResp = await _supabase
              .from('notas_sap_anexos')
              .select()
              .eq('anexo_derivado_de_id', anexo.id!);
          final derivadas = (derivadasResp as List)
              .map((d) => NotaSapAnexo.fromMap(d as Map<String, dynamic>))
              .toList();

          for (final derivada in derivadas) {
            try {
              await _supabase.storage
                  .from(derivada.bucketNome)
                  .remove([derivada.caminhoArquivo]);
            } catch (_) {}
            if (derivada.id != null) {
              await _supabase.from('notas_sap_anexos').delete().eq('id', derivada.id!);
            }
          }
        } catch (derivadasErr) {
          debugPrint('⚠️ [excluirAnexo] Aviso ao limpar derivadas: $derivadasErr');
        }
      }

      // 2. Remover o próprio binário do Supabase Storage
      try {
        await _supabase.storage
            .from(bucketNome)
            .remove([anexo.caminhoArquivo]);
      } catch (storageErr) {
        debugPrint('⚠️ [excluirAnexo] Aviso no storage ($bucketNome): $storageErr');
      }

      // 3. Remover do Banco de Dados (as anotações são removidas via CASCADE no banco)
      if (anexo.id != null) {
        await _supabase.from('notas_sap_anexos').delete().eq('id', anexo.id!);
      }

      // 4. Limpar cache de URL assinada
      _signedUrlCache.remove('$bucketNome:${anexo.caminhoArquivo}');

      invalidarCache(anexo.notaSapId);
    } catch (e) {
      debugPrint('❌ [NotaSapAnaliseService.excluirAnexo] Erro: $e');
      rethrow;
    }
  }

  /// Obtém URL pública (fallback para buckets legados ou públicos)
  String obterUrlAnexo(NotaSapAnexo anexo) {
    return _supabase.storage
        .from(anexo.bucketNome)
        .getPublicUrl(anexo.caminhoArquivo);
  }

  /// Gera URL assinada com expiração customizada e cache em memória (TTL 50min)
  Future<String> obterUrlAssinada(
    NotaSapAnexo anexo, {
    Duration expires = const Duration(minutes: 60),
  }) async {
    final bucketNome = anexo.bucketNome;
    final cacheKey = '$bucketNome:${anexo.caminhoArquivo}';

    // Verificar se existe no cache válido
    final emCache = _signedUrlCache[cacheKey];
    if (emCache != null && emCache.expiraEm.isAfter(DateTime.now())) {
      return emCache.url;
    }

    try {
      final url = await _supabase.storage
          .from(bucketNome)
          .createSignedUrl(anexo.caminhoArquivo, expires.inSeconds);

      // Armazenar no cache com TTL seguro de 50 minutos
      _signedUrlCache[cacheKey] = (
        url: url,
        expiraEm: DateTime.now().add(const Duration(minutes: 50)),
      );

      return url;
    } catch (e) {
      debugPrint('⚠️ [obterUrlAssinada] Falha ao assinar ($cacheKey): $e');
      return obterUrlAnexo(anexo);
    }
  }

  // ============================================================================
  // 4. MÉTODOS DE DISCUSSÃO / COMENTÁRIOS TÉCNICOS
  // ============================================================================

  /// Lista comentários ativos da Nota SAP (exclui soft-deleted)
  Future<List<NotaSapComentario>> listarComentarios(String notaSapId) async {
    try {
      final response = await _supabase
          .from('notas_sap_comentarios')
          .select()
          .eq('nota_sap_id', notaSapId)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: true);

      return (response as List)
          .map((c) => NotaSapComentario.fromMap(c as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ [NotaSapAnaliseService.listarComentarios] Erro: $e');
      rethrow;
    }
  }

  /// Adiciona novo comentário na timeline técnica da Nota
  Future<NotaSapComentario> adicionarComentario({
    required String notaSapId,
    required String usuarioId,
    String? usuarioNome,
    required String mensagem,
    NotaComentarioTipo tipo = NotaComentarioTipo.texto,
    String? replyToId,
  }) async {
    try {
      final payload = <String, dynamic>{
        'nota_sap_id': notaSapId,
        'usuario_id': usuarioId,
        'mensagem': mensagem.trim(),
        'tipo_mensagem': tipo.toDbString(),
        if (usuarioNome != null) 'usuario_nome': usuarioNome,
        if (replyToId != null) 'reply_to_id': replyToId,
      };

      final response = await _supabase
          .from('notas_sap_comentarios')
          .insert(payload)
          .select()
          .single();

      invalidarCache(notaSapId);
      return NotaSapComentario.fromMap(response);
    } catch (e) {
      debugPrint('❌ [NotaSapAnaliseService.adicionarComentario] Erro: $e');
      rethrow;
    }
  }

  /// Edita um comentário existente
  Future<NotaSapComentario> editarComentario(
    String comentarioId,
    String novaMensagem,
  ) async {
    try {
      final response = await _supabase
          .from('notas_sap_comentarios')
          .update({
            'mensagem': novaMensagem.trim(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', comentarioId)
          .select()
          .single();

      return NotaSapComentario.fromMap(response);
    } catch (e) {
      debugPrint('❌ [NotaSapAnaliseService.editarComentario] Erro: $e');
      rethrow;
    }
  }

  /// Realiza soft delete de um comentário
  Future<void> excluirComentario(
    String comentarioId, {
    String? notaSapId,
  }) async {
    try {
      await _supabase.from('notas_sap_comentarios').update({
        'deleted_at': DateTime.now().toIso8601String(),
      }).eq('id', comentarioId);

      if (notaSapId != null) invalidarCache(notaSapId);
    } catch (e) {
      debugPrint('❌ [NotaSapAnaliseService.excluirComentario] Erro: $e');
      rethrow;
    }
  }

  // ============================================================================
  // 5. SUPABASE REALTIME (CANAIS ISOLADOS POR NOTA)
  // ============================================================================

  /// Assina o canal Realtime de comentários para uma Nota SAP específica.
  /// Garante que apenas 1 subscription ativa exista por nota, evitando memory leaks.
  RealtimeChannel assinarComentarios({
    required String notaSapId,
    required void Function(NotaSapComentario) onNovoComentario,
    void Function(NotaSapComentario)? onAtualizacao,
    void Function(String id)? onExclusao,
  }) {
    // Se já houver canal ativo para esta nota, cancelar antes de recriar
    cancelarAssinaturaComentarios(notaSapId);

    final canalNome = 'public:notas_sap_comentarios:$notaSapId';

    final canal = _supabase.channel(canalNome);

    canal
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notas_sap_comentarios',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'nota_sap_id',
            value: notaSapId,
          ),
          callback: (payload) {
            final novo = payload.newRecord;
            if (novo.isNotEmpty) {
              final comentario = NotaSapComentario.fromMap(novo);
              if (!comentario.isDeleted) {
                onNovoComentario(comentario);
              }
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'notas_sap_comentarios',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'nota_sap_id',
            value: notaSapId,
          ),
          callback: (payload) {
            final atualizado = payload.newRecord;
            if (atualizado.isNotEmpty) {
              final comentario = NotaSapComentario.fromMap(atualizado);
              if (comentario.isDeleted && onExclusao != null && comentario.id != null) {
                onExclusao(comentario.id!);
              } else if (onAtualizacao != null) {
                onAtualizacao(comentario);
              }
            }
          },
        )
        .subscribe();

    _canaisAtivos[notaSapId] = canal;
    return canal;
  }

  /// Cancela e descarta o canal Realtime da Nota
  void cancelarAssinaturaComentarios(String notaSapId) {
    if (_canaisAtivos.containsKey(notaSapId)) {
      final canal = _canaisAtivos.remove(notaSapId);
      canal?.unsubscribe();
    }
  }

  /// Cancela todas as assinaturas abertas
  void cancelarTodasAssinaturas() {
    for (final canal in _canaisAtivos.values) {
      canal.unsubscribe();
    }
    _canaisAtivos.clear();
  }

  // ============================================================================
  // 6. CONSULTA EM LOTE (ANTI N+1 PARA BADGES DA TABELA)
  // ============================================================================

  /// Busca o resumo de análise, anexos e comentários para uma lista de notas
  /// com chunking de até 100 IDs para respeitar limites do PostgREST.
  /// Agrega em memória sem N+1 queries.
  Future<Map<String, NotaSapResumoAnalise>> buscarResumoAnalises(
    List<String> notaSapIds, {
    bool forceRefresh = false,
  }) async {
    if (notaSapIds.isEmpty) return {};

    final agora = DateTime.now();

    // Se temos cache recente e não for refresh forçado, verificar quais faltam
    final idsParaBuscar = <String>[];
    final resultadoFinal = <String, NotaSapResumoAnalise>{};

    if (!forceRefresh &&
        _ultimoCacheFetch != null &&
        agora.difference(_ultimoCacheFetch!) < _cacheTtl) {
      for (final id in notaSapIds) {
        if (_resumoCache.containsKey(id)) {
          resultadoFinal[id] = _resumoCache[id]!;
        } else {
          idsParaBuscar.add(id);
        }
      }
    } else {
      idsParaBuscar.addAll(notaSapIds);
    }

    if (idsParaBuscar.isEmpty) return resultadoFinal;

    // Realizar busca chunked para os IDs restantes
    for (var i = 0; i < idsParaBuscar.length; i += _batchChunkSize) {
      final chunk = idsParaBuscar.sublist(
        i,
        i + _batchChunkSize > idsParaBuscar.length
            ? idsParaBuscar.length
            : i + _batchChunkSize,
      );

      final chunkResults = await _executarConsultasEmLote(chunk);
      resultadoFinal.addAll(chunkResults);
      _resumoCache.addAll(chunkResults);
    }

    _ultimoCacheFetch = agora;
    return resultadoFinal;
  }

  /// Executa 4 consultas paralelas de agregação em memória para um chunk de IDs
  Future<Map<String, NotaSapResumoAnalise>> _executarConsultasEmLote(
    List<String> chunkIds,
  ) async {
    final mapaResumo = <String, NotaSapResumoAnalise>{};

    // Inicializar default para todos do chunk (ausência de registro = naoIniciada)
    for (final id in chunkIds) {
      mapaResumo[id] = NotaSapResumoAnalise(
        notaSapId: id,
        status: NotaAnaliseStatus.naoIniciada,
        quantidadeAnexos: 0,
        quantidadeComentarios: 0,
        quantidadeMateriais: 0,
      );
    }

    try {
      final futures = await Future.wait([
        // 1. Status das análises
        _supabase
            .from('notas_sap_analises')
            .select('nota_sap_id, status_analise')
            .inFilter('nota_sap_id', chunkIds),

        // 2. Detalhes de anexos para agregações por tipo
        _supabase
            .from('notas_sap_anexos')
            .select('nota_sap_id, tipo_arquivo, relevante_analise')
            .inFilter('nota_sap_id', chunkIds),

        // 3. Contagem de comentários ativos
        _supabase
            .from('notas_sap_comentarios')
            .select('nota_sap_id')
            .isFilter('deleted_at', null)
            .inFilter('nota_sap_id', chunkIds),

        // 4. Contagem de materiais
        _supabase
            .from('notas_sap_analise_materiais')
            .select('nota_sap_id')
            .inFilter('nota_sap_id', chunkIds),
      ]);

      // Processar Análises
      final analisesList = futures[0] as List;
      for (final item in analisesList) {
        final nid = item['nota_sap_id']?.toString() ?? '';
        final status =
            NotaAnaliseStatus.fromDbString(item['status_analise']?.toString());
        if (mapaResumo.containsKey(nid)) {
          mapaResumo[nid] = mapaResumo[nid]!.copyWith(status: status);
        }
      }

      // Processar Contagem e Agregações de Anexos
      final anexosList = futures[1] as List;
      final contagemAnexos = <String, int>{};
      final contagemImagens = <String, int>{};
      final contagemPdfs = <String, int>{};
      final contagemVideos = <String, int>{};
      final contagemDocs = <String, int>{};
      final contagemPlanilhas = <String, int>{};
      final contagemAudios = <String, int>{};
      final contagemOutros = <String, int>{};
      final contagemRelevantes = <String, int>{};

      for (final item in anexosList) {
        final nid = item['nota_sap_id']?.toString() ?? '';
        final tipo = (item['tipo_arquivo']?.toString() ?? '').toLowerCase();
        final ehRelevante = item['relevante_analise'] == true;

        contagemAnexos[nid] = (contagemAnexos[nid] ?? 0) + 1;
        if (ehRelevante) {
          contagemRelevantes[nid] = (contagemRelevantes[nid] ?? 0) + 1;
        }

        switch (tipo) {
          case 'imagem':
            contagemImagens[nid] = (contagemImagens[nid] ?? 0) + 1;
            break;
          case 'pdf':
            contagemPdfs[nid] = (contagemPdfs[nid] ?? 0) + 1;
            break;
          case 'video':
            contagemVideos[nid] = (contagemVideos[nid] ?? 0) + 1;
            break;
          case 'documento':
            contagemDocs[nid] = (contagemDocs[nid] ?? 0) + 1;
            break;
          case 'planilha':
            contagemPlanilhas[nid] = (contagemPlanilhas[nid] ?? 0) + 1;
            break;
          case 'audio':
            contagemAudios[nid] = (contagemAudios[nid] ?? 0) + 1;
            break;
          default:
            contagemOutros[nid] = (contagemOutros[nid] ?? 0) + 1;
        }
      }

      for (final entry in contagemAnexos.entries) {
        final nid = entry.key;
        if (mapaResumo.containsKey(nid)) {
          mapaResumo[nid] = mapaResumo[nid]!.copyWith(
            quantidadeAnexos: entry.value,
            quantidadeImagens: contagemImagens[nid] ?? 0,
            quantidadePdfs: contagemPdfs[nid] ?? 0,
            quantidadeVideos: contagemVideos[nid] ?? 0,
            quantidadeDocumentos: contagemDocs[nid] ?? 0,
            quantidadePlanilhas: contagemPlanilhas[nid] ?? 0,
            quantidadeAudios: contagemAudios[nid] ?? 0,
            quantidadeOutros: contagemOutros[nid] ?? 0,
            quantidadeRelevantes: contagemRelevantes[nid] ?? 0,
          );
        }
      }

      // Processar Contagem de Comentários
      final comentariosList = futures[2] as List;
      final contagemComentarios = <String, int>{};
      for (final item in comentariosList) {
        final nid = item['nota_sap_id']?.toString() ?? '';
        contagemComentarios[nid] = (contagemComentarios[nid] ?? 0) + 1;
      }
      for (final entry in contagemComentarios.entries) {
        if (mapaResumo.containsKey(entry.key)) {
          mapaResumo[entry.key] = mapaResumo[entry.key]!.copyWith(
            quantidadeComentarios: entry.value,
          );
        }
      }

      // Processar Contagem de Materiais
      final materiaisList = futures[3] as List;
      final contagemMateriais = <String, int>{};
      for (final item in materiaisList) {
        final nid = item['nota_sap_id']?.toString() ?? '';
        contagemMateriais[nid] = (contagemMateriais[nid] ?? 0) + 1;
      }
      for (final entry in contagemMateriais.entries) {
        if (mapaResumo.containsKey(entry.key)) {
          mapaResumo[entry.key] = mapaResumo[entry.key]!.copyWith(
            quantidadeMateriais: entry.value,
          );
        }
      }

      return mapaResumo;
    } catch (e) {
      debugPrint('⚠️ [NotaSapAnaliseService._executarConsultasEmLote] Erro: $e');
      return mapaResumo;
    }
  }

  /// Invalida o cache de uma Nota (ex: após salvar análise, anexar foto ou comentar)
  void invalidarCache(String notaSapId) {
    _resumoCache.remove(notaSapId);
  }

  /// Limpa todo o cache de badges
  void limparCache() {
    _resumoCache.clear();
    _ultimoCacheFetch = null;
  }

  // ============================================================================
  // 7. INTEGRAÇÃO ENTRE EVIDÊNCIAS E ANÁLISE TÉCNICA (FASE 4)
  // ============================================================================

  /// Lista todas as evidências vinculadas à Nota SAP.
  /// Enriquece cada vínculo com metadados do anexo e a versão mais recente disponível.
  // ============================================================================
  // 7. GESTÃO POLIMÓRFICA DE EVIDÊNCIAS TÉCNICAS (ANEXOS SAP & ÁLBUNS)
  // ============================================================================

  /// Lista todas as evidências vinculadas às seções técnicas da Análise da Nota SAP.
  /// Suporta fontes mistas: Anexos da Nota (`anexo_nota`) e Fotos do Álbum (`foto_album`).
  /// Realiza queries em paralelo com merge em memória O(N), eliminando N+1.
  Future<List<NotaSapAnaliseEvidencia>> listarEvidenciasDaNota(
    String notaSapId,
  ) async {
    try {
      if (notaSapId.trim().isEmpty) return [];

      // 1. Busca os vínculos de evidências da nota
      final response = await _supabase
          .from('notas_sap_analise_evidencias')
          .select()
          .eq('nota_sap_id', notaSapId)
          .order('ordem', ascending: true)
          .order('created_at', ascending: true);

      final vinculosRaw = (response as List<dynamic>?) ?? [];
      if (vinculosRaw.isEmpty) return [];

      // 2. Separa IDs de cada fonte para carregamento em lote (Anti N+1)
      final anexoIds = <String>{};
      final mediaImageIds = <String>{};

      for (final v in vinculosRaw) {
        final map = v as Map<String, dynamic>;
        final aId = map['anexo_id']?.toString();
        final mId = map['media_image_id']?.toString();
        final tipoFonteStr = map['tipo_fonte']?.toString();

        if (tipoFonteStr == 'foto_album' || (mId != null && mId.isNotEmpty)) {
          if (mId != null && mId.isNotEmpty) mediaImageIds.add(mId);
        } else {
          if (aId != null && aId.isNotEmpty) anexoIds.add(aId);
        }
      }

      // 3. Executa queries em paralelo (Q2 e Q3 concorrentes)
      final Future<List<dynamic>> anexosFuture = anexoIds.isNotEmpty
          ? _supabase
              .from('notas_sap_anexos')
              .select()
              .inFilter('id', anexoIds.toList())
          : Future.value([]);

      final Future<Map<String, int>> versoesFuture = anexoIds.isNotEmpty
          ? obterUltimasVersoesAnotacoes(anexoIds.toList())
          : Future.value(<String, int>{});

      final Future<List<dynamic>> mediaImagesFuture = mediaImageIds.isNotEmpty
          ? _supabase
              .from('media_images')
              .select()
              .inFilter('id', mediaImageIds.toList())
          : Future.value([]);

      final results = await Future.wait([
        anexosFuture,
        versoesFuture,
        mediaImagesFuture,
      ]);

      final anexosList = results[0] as List<dynamic>;
      final versoesMaxMap = results[1] as Map<String, int>;
      final mediaImagesList = results[2] as List<dynamic>;

      // 4. Mapeia as entidades em memória para lookup O(1)
      final mapaAnexos = <String, NotaSapAnexo>{};
      for (final a in anexosList) {
        final anexo = NotaSapAnexo.fromMap(a as Map<String, dynamic>);
        if (anexo.id != null) mapaAnexos[anexo.id!] = anexo;
      }

      final mapaMediaImages = <String, MediaImage>{};
      for (final m in mediaImagesList) {
        final img = MediaImage.fromMap(m as Map<String, dynamic>);
        mapaMediaImages[img.id] = img;
      }

      // 5. Q5: Busca em lote os dados das Notas SAP históricas (coluna real: 'nota')
      final notasHistoricasIds = <String>{};
      for (final a in mapaAnexos.values) {
        if (a.notaSapId != notaSapId && a.notaSapId.trim().isNotEmpty) {
          notasHistoricasIds.add(a.notaSapId);
        }
      }

      final mapaNumerosNotas = <String, String>{};
      if (notasHistoricasIds.isNotEmpty) {
        try {
          final notasResp = await _supabase
              .from('notas_sap')
              .select('id, nota')
              .inFilter('id', notasHistoricasIds.toList());
          final notasList = (notasResp as List<dynamic>?) ?? [];
          for (final n in notasList) {
            final nMap = n as Map<String, dynamic>;
            final nId = nMap['id']?.toString();
            final numNota = nMap['nota']?.toString();
            if (nId != null && numNota != null) {
              mapaNumerosNotas[nId] = numNota;
            }
          }
        } catch (eNotas) {
          debugPrint('⚠️ [listarEvidenciasDaNota] Erro ao carregar notas históricas: $eNotas');
        }
      }

      // 6. Merge O(N) e construção dos modelos de domínio
      return vinculosRaw.map((v) {
        final map = Map<String, dynamic>.from(v as Map<String, dynamic>);
        final aId = map['anexo_id']?.toString();
        final mId = map['media_image_id']?.toString();
        final anexo = aId != null ? mapaAnexos[aId] : null;
        final numNotaHist = (anexo != null && anexo.notaSapId != notaSapId)
            ? mapaNumerosNotas[anexo.notaSapId]
            : null;

        return NotaSapAnaliseEvidencia.fromMap(
          map,
          anexoCarregado: anexo,
          mediaImageCarregada: mId != null ? mapaMediaImages[mId] : null,
          numeroNotaHistoricaCarregado: numNotaHist,
          maxVersaoDisponivel: aId != null ? versoesMaxMap[aId] : null,
        );
      }).toList();
    } catch (e) {
      debugPrint('❌ [NotaSapAnaliseService.listarEvidenciasDaNota] Erro: $e');
      return [];
    }
  }

  /// Busca os vínculos de evidências agrupados por anexo_id da nota (Anti N+1).
  Future<Map<String, List<NotaTipoVinculoEvidencia>>> buscarUsoDosAnexos(
    String notaSapId,
  ) async {
    try {
      if (notaSapId.trim().isEmpty) return {};

      final response = await _supabase
          .from('notas_sap_analise_evidencias')
          .select('anexo_id, tipo_vinculo')
          .eq('nota_sap_id', notaSapId)
          .eq('tipo_fonte', 'anexo_nota');

      final lista = (response as List<dynamic>?) ?? [];
      final resultado = <String, List<NotaTipoVinculoEvidencia>>{};

      for (final item in lista) {
        final map = item as Map<String, dynamic>;
        final anexoId = map['anexo_id']?.toString();
        final tipoStr = map['tipo_vinculo']?.toString();
        if (anexoId != null && tipoStr != null) {
          final tipo = NotaTipoVinculoEvidencia.fromValor(tipoStr);
          if (tipo != null) {
            resultado.putIfAbsent(anexoId, () => []).add(tipo);
          }
        }
      }

      return resultado;
    } catch (e) {
      debugPrint('⚠️ [NotaSapAnaliseService.buscarUsoDosAnexos] Erro: $e');
      return {};
    }
  }

  /// Busca os vínculos de evidências históricas vinculadas à análise da nota atual (Anti N+1).
  Future<Map<String, List<NotaTipoVinculoEvidencia>>> buscarUsoDosAnexosHistoricos(
    String notaSapId,
  ) async {
    try {
      if (notaSapId.trim().isEmpty) return {};

      final response = await _supabase
          .from('notas_sap_analise_evidencias')
          .select('anexo_id, tipo_vinculo')
          .eq('nota_sap_id', notaSapId)
          .eq('tipo_fonte', 'anexo_nota_historica');

      final lista = (response as List<dynamic>?) ?? [];
      final resultado = <String, List<NotaTipoVinculoEvidencia>>{};

      for (final item in lista) {
        final map = item as Map<String, dynamic>;
        final anexoId = map['anexo_id']?.toString();
        final tipoStr = map['tipo_vinculo']?.toString();
        if (anexoId != null && tipoStr != null) {
          final tipo = NotaTipoVinculoEvidencia.fromValor(tipoStr);
          if (tipo != null) {
            resultado.putIfAbsent(anexoId, () => []).add(tipo);
          }
        }
      }

      return resultado;
    } catch (e) {
      debugPrint('⚠️ [NotaSapAnaliseService.buscarUsoDosAnexosHistoricos] Erro: $e');
      return {};
    }
  }

  /// Busca os vínculos de evidências agrupados por media_image_id da nota (Anti N+1).
  Future<Map<String, List<NotaTipoVinculoEvidencia>>> buscarUsoDasFotosDoAlbum(
    String notaSapId,
  ) async {
    try {
      if (notaSapId.trim().isEmpty) return {};

      final response = await _supabase
          .from('notas_sap_analise_evidencias')
          .select('media_image_id, tipo_vinculo')
          .eq('nota_sap_id', notaSapId)
          .eq('tipo_fonte', 'foto_album');

      final lista = (response as List<dynamic>?) ?? [];
      final resultado = <String, List<NotaTipoVinculoEvidencia>>{};

      for (final item in lista) {
        final map = item as Map<String, dynamic>;
        final mediaImageId = map['media_image_id']?.toString();
        final tipoStr = map['tipo_vinculo']?.toString();
        if (mediaImageId != null && tipoStr != null) {
          final tipo = NotaTipoVinculoEvidencia.fromValor(tipoStr);
          if (tipo != null) {
            resultado.putIfAbsent(mediaImageId, () => []).add(tipo);
          }
        }
      }

      return resultado;
    } catch (e) {
      debugPrint('⚠️ [NotaSapAnaliseService.buscarUsoDasFotosDoAlbum] Erro: $e');
      return {};
    }
  }

  /// Contagem de evidências físicas distintas utilizadas na análise (COUNT DISTINCT polimórfico).
  /// Se a mesma foto ou anexo estiver em múltiplas seções, contabiliza apenas 1 evidência.
  Future<int> contarEvidenciasDistintasNaAnalise(String notaSapId) async {
    try {
      if (notaSapId.trim().isEmpty) return 0;

      final response = await _supabase
          .from('notas_sap_analise_evidencias')
          .select('tipo_fonte, anexo_id, media_image_id')
          .eq('nota_sap_id', notaSapId);

      final lista = (response as List<dynamic>?) ?? [];
      final distinctKeys = <String>{};

      for (final item in lista) {
        final map = item as Map<String, dynamic>;
        final fonte = map['tipo_fonte']?.toString() ?? 'anexo_nota';
        final aId = map['anexo_id']?.toString();
        final mId = map['media_image_id']?.toString();
        final sourceId = fonte == 'foto_album' ? mId : aId;

        if (sourceId != null && sourceId.isNotEmpty) {
          distinctKeys.add('$fonte:$sourceId');
        }
      }

      return distinctKeys.length;
    } catch (e) {
      debugPrint('⚠️ [contarEvidenciasDistintasNaAnalise] Erro: $e');
      return 0;
    }
  }

  /// Alias de retrocompatibilidade para anexos
  Future<int> contarAnexosUsadosNaAnalise(String notaSapId) =>
      contarEvidenciasDistintasNaAnalise(notaSapId);

  /// Consulta em quais seções da análise técnica um determinado anexo está sendo utilizado.
  Future<List<NotaTipoVinculoEvidencia>> obterSecoesOndeAnexoEhUsado(
    String anexoId,
  ) async {
    try {
      if (anexoId.trim().isEmpty) return [];

      final response = await _supabase
          .from('notas_sap_analise_evidencias')
          .select('tipo_vinculo')
          .eq('anexo_id', anexoId);

      final list = (response as List<dynamic>?) ?? [];
      final secoes = <NotaTipoVinculoEvidencia>[];
      for (final item in list) {
        final tipo = NotaTipoVinculoEvidencia.fromValor(item['tipo_vinculo']?.toString() ?? '');
        if (tipo != null && !secoes.contains(tipo)) {
          secoes.add(tipo);
        }
      }
      return secoes;
    } catch (e) {
      debugPrint('⚠️ [obterSecoesOndeAnexoEhUsado] Erro: $e');
      return [];
    }
  }

  /// Vincula uma evidência (anexo ou foto de álbum) a uma seção técnica da análise da Nota SAP.
  ///
  /// Regras de Domínio e Integridade estritas:
  /// 1. Fonte `anexo_nota`:
  ///    - `anexo_id` obrigatório, `media_image_id` nulo.
  ///    - Anexo deve existir e pertencer à mesma Nota SAP.
  ///    - Anexo deve ser ORIGINAL (`anexo_derivado_de_id == null`).
  ///    - Se `anotacaoVersao != null`, a versão deve existir para aquele anexo em `notas_sap_anexos_anotacoes`.
  /// 2. Fonte `foto_album`:
  ///    - `media_image_id` obrigatório, `anexo_id` nulo, `anotacaoVersao` nula.
  ///    - A fotografia deve existir em `media_images`.
  /// 3. Idempotência por par exclusivo `(nota_sap_id, source_id, tipo_vinculo)`.
  Future<NotaSapAnaliseEvidencia> vincularEvidencia({
    required String notaSapId,
    NotaEvidenciaTipoFonte tipoFonte = NotaEvidenciaTipoFonte.anexoNota,
    String? anexoId,
    String? mediaImageId,
    required NotaTipoVinculoEvidencia tipoVinculo,
    int? anotacaoVersao,
    String? observacao,
    int ordem = 0,
    String? criadoPor,
    String? criadoPorNome,
  }) async {
    try {
      NotaSapAnexo? anexoCarregado;
      MediaImage? mediaImageCarregada;

      if (tipoFonte == NotaEvidenciaTipoFonte.anexoNota) {
        if (anexoId == null || anexoId.trim().isEmpty) {
          throw ArgumentError('anexoId é obrigatório quando a fonte é anexo_nota.');
        }
        if (mediaImageId != null && mediaImageId.trim().isNotEmpty) {
          throw ArgumentError('mediaImageId deve ser nulo quando a fonte é anexo_nota.');
        }

        // Validação de domínio do anexo
        final anexoResp = await _supabase
            .from('notas_sap_anexos')
            .select()
            .eq('id', anexoId)
            .maybeSingle();

        if (anexoResp == null) {
          throw ArgumentError('Anexo não encontrado para vinculação.');
        }

        final anexo = NotaSapAnexo.fromMap(anexoResp);

        if (anexo.notaSapId != notaSapId) {
          throw ArgumentError('O anexo pertence a outra Nota SAP.');
        }

        if (anexo.isDerivado) {
          throw ArgumentError('A evidência deve referenciar o anexo original.');
        }

        if (anotacaoVersao != null) {
          final anotacaoResp = await _supabase
              .from('notas_sap_anexos_anotacoes')
              .select('id')
              .eq('anexo_id', anexoId)
              .eq('versao', anotacaoVersao)
              .maybeSingle();

          if (anotacaoResp == null) {
            throw ArgumentError(
              'A versão de anotação v$anotacaoVersao não existe para este anexo.',
            );
          }
        }

        anexoCarregado = anexo;
      } else if (tipoFonte == NotaEvidenciaTipoFonte.fotoAlbum) {
        if (mediaImageId == null || mediaImageId.trim().isEmpty) {
          throw ArgumentError('mediaImageId é obrigatório quando a fonte é foto_album.');
        }
        if (anexoId != null && anexoId.trim().isNotEmpty) {
          throw ArgumentError('anexoId deve ser nulo quando a fonte é foto_album.');
        }
        if (anotacaoVersao != null) {
          throw ArgumentError('anotacaoVersao não é suportada para foto_album nesta fase.');
        }

        // Validação de existência da imagem
        final imgResp = await _supabase
            .from('media_images')
            .select()
            .eq('id', mediaImageId)
            .maybeSingle();

        if (imgResp == null) {
          throw ArgumentError('Fotografia do álbum não encontrada em media_images.');
        }

        mediaImageCarregada = MediaImage.fromMap(imgResp);
      } else if (tipoFonte == NotaEvidenciaTipoFonte.anexoNotaHistorica) {
        if (anexoId == null || anexoId.trim().isEmpty) {
          throw ArgumentError('anexoId é obrigatório quando a fonte é anexo_nota_historica.');
        }
        if (mediaImageId != null && mediaImageId.trim().isNotEmpty) {
          throw ArgumentError('mediaImageId deve ser nulo quando a fonte é anexo_nota_historica.');
        }

        // Validação de domínio do anexo histórico
        final anexoResp = await _supabase
            .from('notas_sap_anexos')
            .select()
            .eq('id', anexoId)
            .maybeSingle();

        if (anexoResp == null) {
          throw ArgumentError('Anexo histórico não encontrado para vinculação.');
        }

        final anexo = NotaSapAnexo.fromMap(anexoResp);

        // Diferença semântica central: deve pertencer a OUTRA nota
        if (anexo.notaSapId == notaSapId) {
          throw ArgumentError('Este anexo pertence à Nota atual. Use a fonte anexo_nota.');
        }

        if (anexo.isDerivado) {
          throw ArgumentError('A evidência deve referenciar o anexo original.');
        }

        // Validar existência da Nota histórica de origem
        final notaOrigemResp = await _supabase
            .from('notas_sap')
            .select('id, nota')
            .eq('id', anexo.notaSapId)
            .maybeSingle();

        if (notaOrigemResp == null) {
          throw ArgumentError('Nota SAP histórica de origem não encontrada.');
        }

        if (anotacaoVersao != null) {
          final anotacaoResp = await _supabase
              .from('notas_sap_anexos_anotacoes')
              .select('id')
              .eq('anexo_id', anexoId)
              .eq('versao', anotacaoVersao)
              .maybeSingle();

          if (anotacaoResp == null) {
            throw ArgumentError(
              'A versão de anotação v$anotacaoVersao não existe para este anexo histórico.',
            );
          }
        }

        anexoCarregado = anexo;
      }

      final isAnexoBase = tipoFonte == NotaEvidenciaTipoFonte.anexoNota ||
          tipoFonte == NotaEvidenciaTipoFonte.anexoNotaHistorica;

      // Montagem do payload com tipo_fonte explícito
      final now = DateTime.now().toUtc().toIso8601String();
      final payload = {
        'nota_sap_id': notaSapId,
        'tipo_fonte': tipoFonte.toDbString(),
        'anexo_id': isAnexoBase ? anexoId : null,
        'media_image_id': tipoFonte == NotaEvidenciaTipoFonte.fotoAlbum ? mediaImageId : null,
        'tipo_vinculo': tipoVinculo.valor,
        'anotacao_versao': isAnexoBase ? anotacaoVersao : null,
        'observacao': observacao?.trim().isEmpty == true ? null : observacao?.trim(),
        'ordem': ordem,
        'criado_por': criadoPor,
        'criado_por_nome': criadoPorNome,
        'updated_at': now,
      };

      // Consulta existência prévia para atualizar (troca de versão/obs) ou inserir respeitando os índices parciais
      var checkQuery = _supabase
          .from('notas_sap_analise_evidencias')
          .select('id')
          .eq('nota_sap_id', notaSapId)
          .eq('tipo_vinculo', tipoVinculo.valor)
          .eq('tipo_fonte', tipoFonte.toDbString());

      if (isAnexoBase) {
        checkQuery = checkQuery.eq('anexo_id', anexoId!);
      } else {
        checkQuery = checkQuery.eq('media_image_id', mediaImageId!);
      }

      final existente = await checkQuery.maybeSingle();
      Map<String, dynamic> resultado;

      if (existente != null && existente['id'] != null) {
        resultado = await _supabase
            .from('notas_sap_analise_evidencias')
            .update(payload)
            .eq('id', existente['id'])
            .select()
            .single();
      } else {
        resultado = await _supabase
            .from('notas_sap_analise_evidencias')
            .insert(payload)
            .select()
            .single();
      }

      invalidarCache(notaSapId);
      return NotaSapAnaliseEvidencia.fromMap(
        resultado,
        anexoCarregado: anexoCarregado,
        mediaImageCarregada: mediaImageCarregada,
      );
    } catch (e) {
      debugPrint('❌ [NotaSapAnaliseService.vincularEvidencia] Erro: $e');
      rethrow;
    }
  }

  /// Desvincula uma evidência (anexo próprio, foto do álbum ou anexo histórico) de uma seção técnica
  Future<void> desvincularEvidencia({
    required String notaSapId,
    NotaEvidenciaTipoFonte tipoFonte = NotaEvidenciaTipoFonte.anexoNota,
    String? anexoId,
    String? mediaImageId,
    required NotaTipoVinculoEvidencia tipoVinculo,
  }) async {
    try {
      var query = _supabase
          .from('notas_sap_analise_evidencias')
          .delete()
          .eq('nota_sap_id', notaSapId)
          .eq('tipo_vinculo', tipoVinculo.valor)
          .eq('tipo_fonte', tipoFonte.toDbString());

      if ((tipoFonte == NotaEvidenciaTipoFonte.anexoNota ||
              tipoFonte == NotaEvidenciaTipoFonte.anexoNotaHistorica) &&
          anexoId != null) {
        query = query.eq('anexo_id', anexoId);
      } else if (tipoFonte == NotaEvidenciaTipoFonte.fotoAlbum && mediaImageId != null) {
        query = query.eq('media_image_id', mediaImageId);
      }

      await query;
      invalidarCache(notaSapId);
    } catch (e) {
      debugPrint('❌ [NotaSapAnaliseService.desvincularEvidencia] Erro: $e');
      rethrow;
    }
  }

  /// Atualiza explicitamente a versão de anotação vinculada a uma evidência de anexo
  Future<void> atualizarVersaoVinculada({
    required String evidenciaId,
    required String anexoId,
    required int? novaVersao,
  }) async {
    try {
      if (novaVersao != null) {
        final versaoResp = await _supabase
            .from('notas_sap_anexos_anotacoes')
            .select('id')
            .eq('anexo_id', anexoId)
            .eq('versao', novaVersao)
            .maybeSingle();

        if (versaoResp == null) {
          throw ArgumentError(
            'A versão de anotação v$novaVersao não existe para este anexo.',
          );
        }
      }

      await _supabase.from('notas_sap_analise_evidencias').update({
        'anotacao_versao': novaVersao,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', evidenciaId);
    } catch (e) {
      debugPrint('❌ [NotaSapAnaliseService.atualizarVersaoVinculada] Erro: $e');
      rethrow;
    }
  }

  /// Atualiza a observação individual de um vínculo de evidência
  Future<void> atualizarObservacaoVinculo({
    required String evidenciaId,
    required String? observacao,
  }) async {
    try {
      await _supabase.from('notas_sap_analise_evidencias').update({
        'observacao': observacao?.trim().isEmpty == true ? null : observacao?.trim(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', evidenciaId);
    } catch (e) {
      debugPrint('❌ [NotaSapAnaliseService.atualizarObservacaoVinculo] Erro: $e');
      rethrow;
    }
  }

  // ============================================================================
  // 8. FUNÇÕES AUXILIARES DE ARQUIVOS
  // ============================================================================

  /// Determina o tipo de arquivo baseado no nome/extensão
  NotaAnexoTipo determinarTipoArquivo(String fileName) {
    return NotaAnexoTipo.deduzir(null, fileName);
  }

  String _sanitizeFileName(String fileName) {
    final parts = fileName.split('.');
    final ext = parts.length > 1 ? parts.last : '';
    final nameWithoutExt = parts.length > 1
        ? parts.sublist(0, parts.length - 1).join('.')
        : fileName;

    var sanitized = nameWithoutExt
        .replaceAll(RegExp(r'[àáâãäå]'), 'a')
        .replaceAll(RegExp(r'[èéêë]'), 'e')
        .replaceAll(RegExp(r'[ìíîï]'), 'i')
        .replaceAll(RegExp(r'[òóôõö]'), 'o')
        .replaceAll(RegExp(r'[ùúûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[ñ]'), 'n')
        .replaceAll(RegExp(r'[ÀÁÂÃÄÅ]'), 'A')
        .replaceAll(RegExp(r'[ÈÉÊË]'), 'E')
        .replaceAll(RegExp(r'[ÌÍÎÏ]'), 'I')
        .replaceAll(RegExp(r'[ÒÓÔÕÖ]'), 'O')
        .replaceAll(RegExp(r'[ÙÚÛÜ]'), 'U')
        .replaceAll(RegExp(r'[Ç]'), 'C')
        .replaceAll(RegExp(r'[Ñ]'), 'N')
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    if (sanitized.isEmpty) sanitized = 'arquivo';
    return ext.isNotEmpty ? '$sanitized.$ext' : sanitized;
  }

  String _getMimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'pdf':
        return 'application/pdf';
      case 'mp4':
        return 'video/mp4';
      default:
        return 'application/octet-stream';
    }
  }
}

/// Resultado do processamento de geração e registro de evidência derivada
class ResultadoGeracaoDerivada {
  final bool sucesso;
  final NotaSapAnexo? anexoDerivado;
  final String? erro;
  final Uint8List? pngBytes;
  final String? sha256;

  const ResultadoGeracaoDerivada({
    required this.sucesso,
    this.anexoDerivado,
    this.erro,
    this.pngBytes,
    this.sha256,
  });
}
