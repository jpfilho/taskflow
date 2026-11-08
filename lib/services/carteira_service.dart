import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/backlog_macro_models.dart';
import '../models/carteira_manutencao_models.dart';
import '../models/nota_sap.dart';
import '../models/nota_sap_grupo.dart';
import 'auth_service_simples.dart';
import 'centro_trabalho_service.dart';
import 'nota_sap_service.dart';
import 'package:uuid/uuid.dart';

/// Helper reutilizável para particionar listas em chunks seguros para PostgREST (inFilter).
List<List<T>> _chunkList<T>(List<T> list, int chunkSize) {
  if (list.isEmpty || chunkSize <= 0) return [];
  return [
    for (var i = 0; i < list.length; i += chunkSize)
      list.sublist(i, (i + chunkSize > list.length) ? list.length : i + chunkSize)
  ];
}

/// DTO raiz retornado pelo CarteiraService contendo a visão consolidada da carteira.
class CarteiraResult {
  final CarteiraIndicadores indicadores;
  final List<CarteiraItem> todosItens;
  final List<CarteiraItem> itensFiltrados;
  final List<NotaSapGrupo> gruposAtivos;
  final BacklogMacroResult backlogMacro;
  final DateTime geradoEm;
  final BacklogFiltro filtrosAplicados;

  const CarteiraResult({
    required this.indicadores,
    required this.todosItens,
    required this.itensFiltrados,
    required this.gruposAtivos,
    required this.backlogMacro,
    required this.geradoEm,
    required this.filtrosAplicados,
  });

  bool get isEmpty => todosItens.isEmpty;
  int get totalPendentes => indicadores.totalNotasPendentes;
}

/// Serviço Central da Carteira de Manutenção do TaskFlow.
///
/// Responsável por unificar toda a demanda pendente (agrupada ou avulsa),
/// calcular cobertura de previsibilidade, motor de prazos (7 situações)
/// e alimentar os painéis executivo, tático e operacional.
class CarteiraService {
  final SupabaseClient? _supabaseClient;
  final AuthServiceSimples? _authService;
  final CentroTrabalhoService? _centroTrabalhoService;

  SupabaseClient get _supabase => _supabaseClient ?? SupabaseConfig.client;
  AuthServiceSimples get _auth => _authService ?? AuthServiceSimples();
  CentroTrabalhoService get _ctService =>
      _centroTrabalhoService ?? CentroTrabalhoService();

  CarteiraService({
    SupabaseClient? supabaseClient,
    AuthServiceSimples? authService,
    CentroTrabalhoService? centroTrabalhoService,
  })  : _supabaseClient = supabaseClient,
        _authService = authService,
        _centroTrabalhoService = centroTrabalhoService;

  // Cache em memória
  CarteiraResult? _cachedResult;
  DateTime? _cachedAt;
  static const Duration _cacheTtl = Duration(minutes: 3);

  /// Invalida o cache local para forçar nova consulta ao backend.
  void invalidarCache() {
    _cachedResult = null;
    _cachedAt = null;
    debugPrint('[CarteiraService] Cache invalidado.');
  }

  /// Busca a carteira de manutenção completa com suporte a cache e filtros.
  Future<CarteiraResult> carregarCarteira({
    BacklogFiltro? filtro,
    bool forcarAtualizacao = false,
    DateTime? dataReferencia,
  }) async {
    final refTime = dataReferencia ?? DateTime.now();

    // 1. Verificar cache (apenas se TTL for válido e não forçado)
    if (!forcarAtualizacao && _cachedResult != null && _cachedAt != null) {
      final diferenca = DateTime.now().difference(_cachedAt!);
      if (diferenca < _cacheTtl) {
        debugPrint('[CarteiraService] Retornando CarteiraResult do cache (${diferenca.inSeconds}s)');
        return _aplicarFiltrosEmMemoria(_cachedResult!, filtro ?? const BacklogFiltro(), refTime);
      }
    }

    try {
      final swTotal = Stopwatch()..start();

      // =======================================================================
      // FASE 1: Buscar Grupos Ativos + Itens e Notas Pendentes em Paralelo
      // =======================================================================
      final userCentrosTrabalho = await _obterCentrosTrabalhoUsuario();

      final resultsFase1 = await Future.wait([
        _buscarGruposAtivosComItens(),
        _buscarNotasPendentesComPrazo(userCentrosTrabalho),
      ]);

      final List<Map<String, dynamic>> gruposRaw = resultsFase1[0];
      final List<Map<String, dynamic>> notasRaw = resultsFase1[1];

      // Mapear Grupos Ativos e a associação (nota_sap_id -> grupo)
      final List<NotaSapGrupo> gruposAtivos = [];
      final Map<String, NotaSapGrupo> grupoPorNotaId = {};
      final Map<String, List<String>> notaIdsPorGrupo = {};

      for (final g in gruposRaw) {
        final grupoObj = NotaSapGrupo.fromMap(g);
        gruposAtivos.add(grupoObj);

        final itens = g['notas_sap_grupos_itens'] as List<dynamic>? ?? [];
        final idsDoGrupo = <String>[];
        for (final it in itens) {
          final nId = it['nota_sap_id']?.toString();
          if (nId != null && nId.isNotEmpty) {
            grupoPorNotaId[nId] = grupoObj;
            idsDoGrupo.add(nId);
          }
        }
        notaIdsPorGrupo[grupoObj.id] = idsDoGrupo;
      }

      // Garantir que todas as notas vinculadas a grupos ativos estejam presentes em notasRaw
      final idsJaCarregados = notasRaw
          .map((n) => n['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
      final idsGruposFaltantes = grupoPorNotaId.keys
          .where((id) => !idsJaCarregados.contains(id))
          .toList();
      if (idsGruposFaltantes.isNotEmpty) {
        final notaService = NotaSAPService(
          supabaseClient: _supabase,
          authService: _auth,
          centroTrabalhoService: _ctService,
        );
        await notaService.garantirCacheEnriquecimento();
        for (final chunk in _chunkList(idsGruposFaltantes, 100)) {
          final extras = await _supabase
              .from('notas_sap')
              .select(NotaSAPService.kColunasEssenciaisNotaSap)
              .inFilter('id', chunk);
          for (final raw in (extras as List)) {
            if (raw is Map) {
              notasRaw.add(notaService.enriquecerMapaNotaComLocalEPrazo(
                raw.map((k, v) => MapEntry(k.toString(), v)),
              ));
            }
          }
        }
      }

      // Se não houver notas pendentes, retornar resultado vazio imediatamente
      if (notasRaw.isEmpty) {
        final vazio = _construirResultadoVazio(filtro ?? const BacklogFiltro(), refTime);
        _cachedResult = vazio;
        _cachedAt = DateTime.now();
        return vazio;
      }

      // Extrair todos os IDs de notas pendentes da carteira
      final List<String> todosNotaIds = notasRaw
          .map((n) => n['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();

      final chunks = _chunkList(todosNotaIds, 50);

      // =======================================================================
      // FASE 2: Chunks em Paralelo de Tarefas, Análises e Previsões Individuais
      // =======================================================================
      final resultsFase2 = await Future.wait([
        _executarChunksTasks(chunks),
        _executarChunksAnalises(chunks),
        _executarChunksPrevisoes(chunks),
      ]);

      final List<Map<String, dynamic>> tasksRaw = resultsFase2[0];
      final List<Map<String, dynamic>> analisesRaw = resultsFase2[1];
      final List<Map<String, dynamic>> previsoesRaw = resultsFase2[2];

      // Mapear Tarefas por nota_sap_id
      final Map<String, List<BacklogTaskInfo>> tasksPorNota = {};
      for (final t in tasksRaw) {
        final nId = t['nota_sap_id']?.toString();
        final taskData = t['tasks'] as Map<String, dynamic>?;
        if (nId != null && taskData != null) {
          final taskInfo = BacklogTaskInfo.fromMap(taskData);
          tasksPorNota.putIfAbsent(nId, () => []).add(taskInfo);
        }
      }

      // Mapear Análises por nota_sap_id
      final Map<String, Map<String, dynamic>> analisePorNota = {};
      for (final a in analisesRaw) {
        final nId = a['nota_sap_id']?.toString();
        if (nId != null) {
          analisePorNota[nId] = a;
        }
      }

      // Mapear Previsões Individuais por nota_sap_id
      final Map<String, PrevisaoIndividualNota> previsaoPorNota = {};
      for (final p in previsoesRaw) {
        final nId = p['nota_sap_id']?.toString();
        if (nId != null) {
          previsaoPorNota[nId] = PrevisaoIndividualNota.fromMap(p);
        }
      }

      // =======================================================================
      // FASE 3: Agregação em Memória O(N) e Classificação de Risco
      // =======================================================================
      final List<CarteiraItem> todosItens = [];
      final Map<String, BacklogNotaItem> backlogNotasMap = {};

      for (final nMap in notasRaw) {
        final notaObj = NotaSAP.fromMap(nMap);

        // Só processar notas abertas/pendentes
        if (!notaObj.estaAberta) continue;

        final nId = notaObj.id;
        final grupoAtivo = grupoPorNotaId[nId];
        final tasks = tasksPorNota[nId] ?? const [];
        final analise = analisePorNota[nId];

        final estimativa = analise != null && analise['estimativa_horas'] != null
            ? double.tryParse(analise['estimativa_horas'].toString())
            : null;
        final statusAnalise = analise?['status_analise']?.toString();

        final bool isProgramada = tasks.any((t) => t.isValida);

        // Resolução e Precedência de Previsão:
        // 1º: Previsão herdada do grupo ativo (se houver e tiver mês/ano)
        // 2º: Previsão individual atribuída diretamente à nota (se houver)
        // 3º: Previsão de grupo ativo sem data definida
        // 4º: Previsão inferida da tarefa programada operacional (se houver)
        // 5º: Sem previsão
        final CarteiraPrevisao previsao;
        final previsaoIndividual = previsaoPorNota[nId];

        if (grupoAtivo != null && grupoAtivo.temPrevisao) {
          previsao = CarteiraPrevisao(
            mes: grupoAtivo.mesProgramacaoPrevisto,
            ano: grupoAtivo.anoProgramacaoPrevisto,
            origem: OrigemPrevisao.grupo,
            origemId: grupoAtivo.id,
            origemNome: grupoAtivo.nome,
            motivo: grupoAtivo.motivoPrevisao,
          );
        } else if (previsaoIndividual != null) {
          previsao = CarteiraPrevisao(
            mes: previsaoIndividual.mesPrevisao,
            ano: previsaoIndividual.anoPrevisao,
            origem: OrigemPrevisao.individual,
            origemId: previsaoIndividual.id,
            origemNome: 'Previsão Individual',
            motivo: previsaoIndividual.motivoPrevisao,
          );
        } else if (grupoAtivo != null && !grupoAtivo.temPrevisao) {
          previsao = CarteiraPrevisao(
            origem: OrigemPrevisao.grupo,
            origemId: grupoAtivo.id,
            origemNome: grupoAtivo.nome,
            motivo: 'Grupo sem previsão definida',
          );
        } else if (isProgramada) {
          // Inferir da primeira tarefa válida com data
          final taskValidaComData = tasks.firstWhere(
            (t) => t.isValida && t.dataInicio != null,
            orElse: () => const BacklogTaskInfo(id: '', status: ''),
          );
          if (taskValidaComData.dataInicio != null) {
            previsao = CarteiraPrevisao(
              mes: taskValidaComData.dataInicio!.month,
              ano: taskValidaComData.dataInicio!.year,
              origem: OrigemPrevisao.programacao,
              origemId: taskValidaComData.id,
              origemNome: taskValidaComData.tarefa ?? 'Tarefa Programada',
            );
          } else {
            previsao = CarteiraPrevisao.semPrevisao;
          }
        } else {
          previsao = CarteiraPrevisao.semPrevisao;
        }

        // Classificação formal da Situação de Prazo (SIT-1 a SIT-7)
        final situacaoPrazo = SituacaoPrazoCarteira.classificar(
          dataVencimento: notaObj.dataVencimento,
          diasRestantes: notaObj.diasRestantes,
          mesPrevisto: previsao.mes,
          anoPrevisto: previsao.ano,
          isProgramada: isProgramada,
          dataReferencia: refTime,
        );

        final item = CarteiraItem(
          nota: notaObj,
          previsao: previsao,
          grupoId: grupoAtivo?.id,
          grupoNome: grupoAtivo?.nome,
          tasks: tasks,
          estimativaHoras: estimativa,
          statusAnalise: statusAnalise,
          situacaoPrazo: situacaoPrazo,
        );

        todosItens.add(item);

        backlogNotasMap[nId] = BacklogNotaItem(
          id: item.id,
          nota: item.numeroNota,
          descricao: item.descricao ?? '',
          localInstalacao: item.localInstalacao,
          equipamento: item.equipamento,
          centroTrabalhoResponsavel: item.centroTrabalho,
          prioridade: item.prioridade,
          gpm: item.nota.gpm,
          statusSistema: item.nota.statusSistema,
          statusUsuario: item.nota.statusUsuario,
          estimativaHoras: estimativa,
          statusAnalise: statusAnalise,
          dataFimDesejada: item.nota.dataVencimento ?? item.nota.conclusaoDesejada,
          dataCriacao: item.nota.criadoEm,
          grupoId: item.grupoId,
          mesPrevisto: item.previsao.mes,
          anoPrevisto: item.previsao.ano,
          tasks: tasks,
        );
      }

      // =======================================================================
      // FASE 4: Montagem do BacklogMacroResult Integrado (Grupos + Notas Avulsas)
      // =======================================================================
      final backlogMacro = _montarBacklogMacroIntegrado(
        gruposAtivos: gruposAtivos,
        notaIdsPorGrupo: notaIdsPorGrupo,
        backlogNotasMap: backlogNotasMap,
        todosItens: todosItens,
        refTime: refTime,
        filtro: const BacklogFiltro(),
      );

      // Calcular Indicadores Consolidados
      final indicadores = CarteiraIndicadores.calcular(
        itens: todosItens,
        gruposAtivos: gruposAtivos,
        dataReferencia: refTime,
      );

      swTotal.stop();
      debugPrint('[CarteiraService] Carteira carregada em ${swTotal.elapsedMilliseconds}ms: '
          '${todosItens.length} notas pendentes (${indicadores.totalNotasAgrupadas} agrupadas, '
          '${indicadores.totalNotasAvulsas} avulsas, Cobertura: ${indicadores.taxaCoberturaPrevisibilidade.toStringAsFixed(1)}%)');

      final baseResult = CarteiraResult(
        indicadores: indicadores,
        todosItens: todosItens,
        itensFiltrados: todosItens,
        gruposAtivos: gruposAtivos,
        backlogMacro: backlogMacro,
        geradoEm: DateTime.now(),
        filtrosAplicados: const BacklogFiltro(),
      );

      // Atualizar cache base (sem filtros)
      _cachedResult = baseResult;
      _cachedAt = DateTime.now();

      return _aplicarFiltrosEmMemoria(baseResult, filtro ?? const BacklogFiltro(), refTime);
    } catch (e, stackTrace) {
      debugPrint('❌ [CarteiraService.carregarCarteira] Erro: $e\n$stackTrace');
      rethrow;
    }
  }

  // ===========================================================================
  // CONSULTAS INTERNAS DO SUPABASE
  // ===========================================================================

  Future<List<Map<String, dynamic>>> _buscarGruposAtivosComItens() async {
    final res = await _supabase
        .from('notas_sap_grupos')
        .select('''
          id,
          nome,
          descricao,
          motivo,
          mes_programacao_previsto,
          ano_programacao_previsto,
          motivo_previsao,
          local_instalacao,
          equipamento,
          centro_trabalho_responsavel,
          status_grupo,
          created_at,
          notas_sap_grupos_itens(
            nota_sap_id
          )
        ''')
        .eq('status_grupo', 'ativo')
        .order('nome', ascending: true);

    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<List<Map<String, dynamic>>> _buscarNotasPendentesComPrazo(
      List<String> centrosTrabalhoUsuario) async {
    final usuario = _auth.currentUser;
    final centros = (usuario != null && !usuario.isRoot && centrosTrabalhoUsuario.isNotEmpty)
        ? centrosTrabalhoUsuario
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList()
        : <String>[];

    final notaService = NotaSAPService(
      supabaseClient: _supabase,
      authService: _auth,
      centroTrabalhoService: _ctService,
    );

    return notaService.buscarMapasNotasSapRapido(
      centrosTrabalhoCompletos: centros,
      filtroTipoNota: 'abertas',
      targetLimit: 1000,
    );
  }

  Future<List<Map<String, dynamic>>> _executarChunksTasks(
      List<List<String>> chunks) async {
    if (chunks.length > 2) {
      final idsSet = <String>{for (final c in chunks) ...c};
      final notaService = NotaSAPService(
        supabaseClient: _supabase,
        authService: _auth,
        centroTrabalhoService: _ctService,
      );
      final mapaVinculos = await notaService.carregarMapaVinculosTarefas();
      final resultado = <Map<String, dynamic>>[];
      for (final id in idsSet) {
        final vincs = mapaVinculos[id];
        if (vincs == null) continue;
        for (final v in vincs) {
          resultado.add({
            'nota_sap_id': id,
            'task_id': v['task_id'],
            'tasks': v['tarefa'],
          });
        }
      }
      return resultado;
    }
    final List<Map<String, dynamic>> acumulador = [];
    for (final chunk in chunks) {
      final res = await _supabase
          .from('tasks_notas_sap')
          .select('''
            nota_sap_id,
            task_id,
            tasks(
              id,
              tarefa,
              status,
              data_inicio,
              data_fim
            )
          ''')
          .inFilter('nota_sap_id', chunk);
      acumulador.addAll(List<Map<String, dynamic>>.from(res as List));
    }
    return acumulador;
  }

  Future<List<Map<String, dynamic>>> _executarChunksAnalises(
      List<List<String>> chunks) async {
    if (chunks.length > 2) {
      final idsSet = <String>{for (final c in chunks) ...c};
      final res = await _supabase
          .from('notas_sap_analises')
          .select('nota_sap_id, estimativa_horas, status_analise');
      return (res as List)
          .whereType<Map>()
          .map((m) => m.map((k, v) => MapEntry(k.toString(), v)))
          .where((m) => idsSet.contains(m['nota_sap_id']?.toString()))
          .toList();
    }
    final List<Map<String, dynamic>> acumulador = [];
    for (final chunk in chunks) {
      final res = await _supabase
          .from('notas_sap_analises')
          .select('nota_sap_id, estimativa_horas, status_analise')
          .inFilter('nota_sap_id', chunk);
      acumulador.addAll(List<Map<String, dynamic>>.from(res as List));
    }
    return acumulador;
  }

  Future<List<Map<String, dynamic>>> _executarChunksPrevisoes(
      List<List<String>> chunks) async {
    final List<Map<String, dynamic>> acumulador = [];
    try {
      if (chunks.length > 2) {
        final idsSet = <String>{for (final c in chunks) ...c};
        final res = await _supabase
            .from('notas_sap_previsoes')
            .select('''
              id,
              nota_sap_id,
              numero_nota,
              mes_previsao,
              ano_previsao,
              motivo_previsao,
              lote_id,
              criado_em,
              criado_por,
              criado_por_nome,
              atualizado_em,
              atualizado_por,
              atualizado_por_nome
            ''');
        return (res as List)
            .whereType<Map>()
            .map((m) => m.map((k, v) => MapEntry(k.toString(), v)))
            .where((m) => idsSet.contains(m['nota_sap_id']?.toString()))
            .toList();
      }
      for (final chunk in chunks) {
        final res = await _supabase
            .from('notas_sap_previsoes')
            .select('''
              id,
              nota_sap_id,
              numero_nota,
              mes_previsao,
              ano_previsao,
              motivo_previsao,
              lote_id,
              criado_em,
              criado_por,
              criado_por_nome,
              atualizado_em,
              atualizado_por,
              atualizado_por_nome
            ''')
            .inFilter('nota_sap_id', chunk);
        acumulador.addAll(List<Map<String, dynamic>>.from(res as List));
      }
    } catch (e) {
      debugPrint('[CarteiraService] Tabela notas_sap_previsoes ainda não instalada ou indisponível: $e');
    }
    return acumulador;
  }

  // ===========================================================================
  // GESTÃO ATIVA DE PREVISIBILIDADE (INDIVIDUAL, LOTE, DESFAZER E AUDITORIA)
  // ===========================================================================

  /// Atribui ou altera a previsão individual de uma nota específica.
  Future<bool> atribuirPrevisaoIndividual({
    required String notaSapId,
    required String numeroNota,
    required int mes,
    required int ano,
    String? motivo,
  }) async {
    final usuario = _auth.currentUser;
    final nowIso = DateTime.now().toIso8601String();

    final payload = {
      'nota_sap_id': notaSapId,
      'numero_nota': numeroNota,
      'mes_previsao': mes,
      'ano_previsao': ano,
      'motivo_previsao': motivo,
      'criado_por': usuario?.id,
      'criado_por_nome': usuario?.nome ?? usuario?.email,
      'atualizado_por': usuario?.id,
      'atualizado_por_nome': usuario?.nome ?? usuario?.email,
      'atualizado_em': nowIso,
    };

    try {
      await _supabase.from('notas_sap_previsoes').upsert(
        payload,
        onConflict: 'nota_sap_id',
      );
      invalidarCache();
      return true;
    } catch (e) {
      debugPrint('[CarteiraService] Erro ao atribuir previsão individual: $e');
      return false;
    }
  }

  /// Atribui previsão em lote para uma lista de notas selecionadas.
  /// Retorna o loteId gerado para permitir rastreabilidade e rollback.
  Future<String?> atribuirPrevisaoEmLote({
    required List<String> notaSapIds,
    required Map<String, String> numeroPorNotaId,
    required int mes,
    required int ano,
    String? motivo,
  }) async {
    if (notaSapIds.isEmpty) return null;
    final usuario = _auth.currentUser;
    final loteId = const Uuid().v4();
    final nowIso = DateTime.now().toIso8601String();

    final chunks = _chunkList(notaSapIds, 50);
    try {
      for (final chunk in chunks) {
        final rows = chunk.map((id) => {
          'nota_sap_id': id,
          'numero_nota': numeroPorNotaId[id] ?? id,
          'mes_previsao': mes,
          'ano_previsao': ano,
          'motivo_previsao': motivo,
          'lote_id': loteId,
          'criado_por': usuario?.id,
          'criado_por_nome': usuario?.nome ?? usuario?.email,
          'atualizado_por': usuario?.id,
          'atualizado_por_nome': usuario?.nome ?? usuario?.email,
          'atualizado_em': nowIso,
        }).toList();

        await _supabase.from('notas_sap_previsoes').upsert(
          rows,
          onConflict: 'nota_sap_id',
        );
      }
      invalidarCache();
      return loteId;
    } catch (e) {
      debugPrint('[CarteiraService] Erro ao atribuir previsão em lote: $e');
      return null;
    }
  }

  /// Desfaz uma operação realizada em lote, revertendo cada nota para seu estado anterior
  /// com base na trilha de auditoria gravada em notas_sap_previsoes_hist.
  Future<bool> desfazerAlteracaoLote({required String loteId}) async {
    try {
      final histRows = await _supabase
          .from('notas_sap_previsoes_hist')
          .select()
          .eq('lote_id', loteId);

      if (histRows.isEmpty) return false;

      final usuario = _auth.currentUser;
      final nowIso = DateTime.now().toIso8601String();

      for (final row in (histRows as List)) {
        final notaSapId = row['nota_sap_id']?.toString();
        if (notaSapId == null) continue;

        final mesAnt = (row['mes_anterior'] as num?)?.toInt();
        final anoAnt = (row['ano_anterior'] as num?)?.toInt();

        if (mesAnt != null && anoAnt != null) {
          await _supabase.from('notas_sap_previsoes').update({
            'mes_previsao': mesAnt,
            'ano_previsao': anoAnt,
            'motivo_previsao': 'DESFEITO DO LOTE $loteId',
            'lote_id': null,
            'atualizado_por': usuario?.id,
            'atualizado_por_nome': usuario?.nome ?? usuario?.email,
            'atualizado_em': nowIso,
          }).eq('nota_sap_id', notaSapId);
        } else {
          await _supabase.from('notas_sap_previsoes').delete().eq('nota_sap_id', notaSapId);
        }
      }

      invalidarCache();
      return true;
    } catch (e) {
      debugPrint('[CarteiraService] Erro ao desfazer lote: $e');
      return false;
    }
  }

  /// Remove a previsão individual de uma nota.
  Future<bool> removerPrevisaoIndividual({required String notaSapId}) async {
    try {
      await _supabase.from('notas_sap_previsoes').delete().eq('nota_sap_id', notaSapId);
      invalidarCache();
      return true;
    } catch (e) {
      debugPrint('[CarteiraService] Erro ao remover previsão individual: $e');
      return false;
    }
  }

  /// Obtém o histórico completo de reprogramações e previsões de uma nota específica.
  Future<List<HistoricoPrevisaoNota>> obterHistoricoPrevisoes({
    required String notaSapId,
  }) async {
    try {
      final res = await _supabase
          .from('notas_sap_previsoes_hist')
          .select()
          .eq('nota_sap_id', notaSapId)
          .order('alterado_em', ascending: false);

      return (res as List)
          .map((m) => HistoricoPrevisaoNota.fromMap(m as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[CarteiraService] Erro ao buscar histórico de previsões: $e');
      return [];
    }
  }

  Future<List<String>> _obterCentrosTrabalhoUsuario() async {
    final usuario = _auth.currentUser;
    if (usuario == null || usuario.isRoot) return [];

    try {
      if (!usuario.temPerfilConfigurado()) {
        return [];
      }

      final todosCentros = await _ctService.getAllCentrosTrabalho();
      final centrosPermitidos = todosCentros.where((centro) {
        final temRegionalPermitida = usuario.regionalIds.isEmpty ||
            usuario.regionalIds.contains(centro.regionalId);
        final temDivisaoPermitida = usuario.divisaoIds.isEmpty ||
            usuario.divisaoIds.contains(centro.divisaoId);
        final temSegmentoPermitido = usuario.segmentoIds.isEmpty ||
            usuario.segmentoIds.contains(centro.segmentoId);

        return temRegionalPermitida && temDivisaoPermitida && temSegmentoPermitido;
      }).toList();

      return centrosPermitidos.map((ct) => ct.centroTrabalho).toList();
    } catch (_) {
      return [];
    }
  }

  // ===========================================================================
  // MONTAGEM DO BACKLOG MACRO INTEGRADO COM NOTAS AVULSAS
  // ===========================================================================

  BacklogMacroResult _montarBacklogMacroIntegrado({
    required List<NotaSapGrupo> gruposAtivos,
    required Map<String, List<String>> notaIdsPorGrupo,
    required Map<String, BacklogNotaItem> backlogNotasMap,
    required List<CarteiraItem> todosItens,
    required DateTime refTime,
    required BacklogFiltro filtro,
  }) {
    final List<BacklogGrupoItem> gruposMontados = [];

    // 1. Montar os Grupos Tradicionais
    for (final g in gruposAtivos) {
      final notaIds = notaIdsPorGrupo[g.id] ?? const [];
      final notasDoGrupo = <BacklogNotaItem>[];

      for (final nId in notaIds) {
        if (backlogNotasMap.containsKey(nId)) {
          notasDoGrupo.add(backlogNotasMap[nId]!);
        }
      }

      if (notasDoGrupo.isNotEmpty) {
        gruposMontados.add(BacklogGrupoItem(
          id: g.id,
          nome: g.nome,
          motivo: g.motivo,
          mesProgramacaoPrevisto: g.mesProgramacaoPrevisto,
          anoProgramacaoPrevisto: g.anoProgramacaoPrevisto,
          localInstalacao: g.localInstalacao,
          equipamento: g.equipamento,
          centroTrabalhoResponsavel: g.centroTrabalhoResponsavel,
          statusGrupo: g.statusGrupo.toDbString(),
          createdAt: g.createdAt,
          notas: notasDoGrupo,
        ));
      }
    }

    // 2. Montar Agrupamento Virtual para Notas Avulsas (Fora de Grupos)
    final avulsas = todosItens.where((i) => i.isAvulsa).toList();
    if (avulsas.isNotEmpty) {
      // Separar avulsas por mês/ano previsto
      final Map<String, List<BacklogNotaItem>> avulsasPorMes = {};
      final List<BacklogNotaItem> avulsasSemPrevisao = [];

      for (final a in avulsas) {
        final bNota = backlogNotasMap[a.id];
        if (bNota == null) continue;

        if (a.temPrevisaoValida) {
          final chave = '${a.previsao.ano}_${a.previsao.mes}';
          avulsasPorMes.putIfAbsent(chave, () => []).add(bNota);
        } else {
          avulsasSemPrevisao.add(bNota);
        }
      }

      // Adicionar grupo virtual para avulsas com previsão
      for (final entry in avulsasPorMes.entries) {
        final parts = entry.key.split('_');
        final ano = int.parse(parts[0]);
        final mes = int.parse(parts[1]);

        gruposMontados.add(BacklogGrupoItem(
          id: 'avulsas_${entry.key}',
          nome: 'Demandas Avulsas Previstas (${mes.toString().padLeft(2, '0')}/$ano)',
          motivo: 'Notas pendentes individuais com previsão direta',
          mesProgramacaoPrevisto: mes,
          anoProgramacaoPrevisto: ano,
          statusGrupo: 'ativo',
          notas: entry.value,
        ));
      }

      // Adicionar grupo virtual para avulsas sem previsão
      if (avulsasSemPrevisao.isNotEmpty) {
        gruposMontados.add(BacklogGrupoItem(
          id: 'avulsas_sem_previsao',
          nome: 'Demandas Avulsas sem Previsão',
          motivo: 'Notas pendentes que ainda não pertencem a grupos e não possuem horizonte definido',
          mesProgramacaoPrevisto: null,
          anoProgramacaoPrevisto: null,
          statusGrupo: 'ativo',
          notas: avulsasSemPrevisao,
        ));
      }
    }

    // 3. Agrupar por Mês/Ano
    final Map<String, List<BacklogGrupoItem>> gruposPorMesAno = {};
    final List<BacklogGrupoItem> semPrevisaoGrupos = [];

    for (final grupo in gruposMontados) {
      if (grupo.temPrevisao) {
        final key = '${grupo.anoProgramacaoPrevisto}_${grupo.mesProgramacaoPrevisto}';
        gruposPorMesAno.putIfAbsent(key, () => []).add(grupo);
      } else {
        semPrevisaoGrupos.add(grupo);
      }
    }

    final List<BacklogMensalResumo> listaMeses = [];
    for (final entry in gruposPorMesAno.entries) {
      final parts = entry.key.split('_');
      final ano = int.parse(parts[0]);
      final mes = int.parse(parts[1]);
      final gruposDoMes = entry.value;

      listaMeses.add(BacklogMensalResumo(
        ano: ano,
        mes: mes,
        grupos: gruposDoMes,
      ));
    }

    listaMeses.sort((a, b) {
      final pA = a.ano! * 12 + a.mes!;
      final pB = b.ano! * 12 + b.mes!;
      return pA.compareTo(pB);
    });

    final resumoSemPrevisao = semPrevisaoGrupos.isNotEmpty
        ? BacklogMensalResumo(grupos: semPrevisaoGrupos)
        : null;

    // Resumo Global
    int notasContadas = 0;
    int notasProg = 0;
    int notasPend = 0;
    int grpUltrapassados = 0;
    int grpComPrev = 0;
    int grpSemPrev = 0;

    for (final g in gruposMontados) {
      notasContadas += g.totalNotas;
      notasProg += g.notasProgramadas;
      notasPend += g.notasPendentes;
      if (g.temPrevisao) {
        grpComPrev++;
        if (g.isPrevisaoUltrapassada(refTime)) {
          grpUltrapassados++;
        }
      } else {
        grpSemPrev++;
      }
    }

    final global = BacklogGlobalResumo(
      gruposAtivos: gruposMontados.length,
      gruposComPrevisao: grpComPrev,
      gruposSemPrevisao: grpSemPrev,
      gruposUltrapassados: grpUltrapassados,
      notasEmGrupos: notasContadas,
      notasProgramadas: notasProg,
      notasPendentes: notasPend,
      notasUnicas: todosItens.length,
      temAnomaliaIntegridade: false,
    );

    return BacklogMacroResult(
      global: global,
      meses: listaMeses,
      semPrevisao: resumoSemPrevisao,
      geradoEm: DateTime.now(),
      filtrosAplicados: filtro,
      todosGrupos: gruposMontados,
    );
  }

  // ===========================================================================
  // FILTRAGEM EM MEMÓRIA
  // ===========================================================================

  CarteiraResult _aplicarFiltrosEmMemoria(
    CarteiraResult base,
    BacklogFiltro filtro,
    DateTime refTime,
  ) {
    if (filtro.isEmpty) {
      return base;
    }

    final filtrados = base.todosItens.where((item) {
      // Filtro de ano
      if (filtro.ano != null && item.previsao.ano != filtro.ano) {
        return false;
      }
      // Filtro de mês
      if (filtro.mes != null && item.previsao.mes != filtro.mes) {
        return false;
      }
      // Filtro apenas com previsão
      if (filtro.apenasComPrevisao == true && !item.temPrevisaoValida) {
        return false;
      }
      // Filtro apenas sem previsão
      if (filtro.apenasSemPrevisao == true && item.temPrevisaoValida) {
        return false;
      }
      // Filtro apenas ultrapassados
      if (filtro.apenasUltrapassados == true && !item.isPrevisaoUltrapassada) {
        return false;
      }
      // Filtro centro de trabalho
      if (filtro.centroTrabalho != null && filtro.centroTrabalho!.isNotEmpty) {
        final ct = (item.centroTrabalho ?? '').toUpperCase();
        if (!ct.contains(filtro.centroTrabalho!.toUpperCase())) return false;
      }
      // Filtro local de instalação
      if (filtro.localInstalacao != null && filtro.localInstalacao!.isNotEmpty) {
        final loc = (item.localInstalacao ?? '').toUpperCase();
        if (!loc.contains(filtro.localInstalacao!.toUpperCase())) return false;
      }
      // Filtro equipamento
      if (filtro.equipamento != null && filtro.equipamento!.isNotEmpty) {
        final eq = (item.equipamento ?? '').toUpperCase();
        if (!eq.contains(filtro.equipamento!.toUpperCase())) return false;
      }
      // Filtro status de programação
      if (filtro.statusProgramacao != null) {
        if (filtro.statusProgramacao == StatusProgramacaoGrupo.total && !item.isProgramada) {
          return false;
        }
        if (filtro.statusProgramacao == StatusProgramacaoGrupo.naoProgramado && item.isProgramada) {
          return false;
        }
      }
      // Busca em texto
      if (filtro.buscaTexto != null && filtro.buscaTexto!.trim().isNotEmpty) {
        final q = filtro.buscaTexto!.toUpperCase();
        final matchNota = item.numeroNota.toUpperCase().contains(q);
        final matchDesc = (item.descricao ?? '').toUpperCase().contains(q);
        final matchEq = (item.equipamento ?? '').toUpperCase().contains(q);
        final matchLoc = (item.localInstalacao ?? '').toUpperCase().contains(q);
        final matchGrp = (item.grupoNome ?? '').toUpperCase().contains(q);
        if (!matchNota && !matchDesc && !matchEq && !matchLoc && !matchGrp) {
          return false;
        }
      }

      return true;
    }).toList();

    final novosIndicadores = CarteiraIndicadores.calcular(
      itens: filtrados,
      gruposAtivos: base.gruposAtivos,
      dataReferencia: refTime,
    );

    return CarteiraResult(
      indicadores: novosIndicadores,
      todosItens: base.todosItens,
      itensFiltrados: filtrados,
      gruposAtivos: base.gruposAtivos,
      backlogMacro: base.backlogMacro,
      geradoEm: DateTime.now(),
      filtrosAplicados: filtro,
    );
  }

  CarteiraResult _construirResultadoVazio(BacklogFiltro filtro, DateTime refTime) {
    const indicadoresVazios = CarteiraIndicadores(
      totalNotasPendentes: 0,
      totalNotasAgrupadas: 0,
      totalNotasAvulsas: 0,
      totalComPrevisao: 0,
      totalSemPrevisao: 0,
      taxaCoberturaPrevisibilidade: 0.0,
      totalHorasEstimadas: 0.0,
      totalHorasSemPrevisao: 0.0,
      totalNotasComEstimativa: 0,
      taxaCoberturaEstimativa: 0.0,
      totalProgramadas: 0,
      taxaProgramacao: 0.0,
      totalVencidas: 0,
      totalViolacaoPrevista: 0,
      totalRiscoTemporal: 0,
      totalCompativel: 0,
      totalPrevisaoUltrapassada: 0,
      totalSemPrevisaoPrazoProximo: 0,
      totalSemPrazoConhecido: 0,
      totalGruposAtivos: 0,
      totalGruposComPrevisao: 0,
      totalGruposSemPrevisao: 0,
      totalGruposUltrapassados: 0,
      totalGruposComRiscoPrazo: 0,
    );

    final macroVazio = BacklogMacroResult(
      global: const BacklogGlobalResumo(
        gruposAtivos: 0,
        gruposComPrevisao: 0,
        gruposSemPrevisao: 0,
        gruposUltrapassados: 0,
        notasEmGrupos: 0,
        notasProgramadas: 0,
        notasPendentes: 0,
        notasUnicas: 0,
        temAnomaliaIntegridade: false,
      ),
      meses: const [],
      geradoEm: DateTime.now(),
      filtrosAplicados: const BacklogFiltro(),
      todosGrupos: const [],
    );

    return CarteiraResult(
      indicadores: indicadoresVazios,
      todosItens: const [],
      itensFiltrados: const [],
      gruposAtivos: const [],
      backlogMacro: macroVazio,
      geradoEm: DateTime.now(),
      filtrosAplicados: filtro,
    );
  }
}
