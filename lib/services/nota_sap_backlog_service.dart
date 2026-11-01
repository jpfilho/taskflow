import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/backlog_macro_models.dart';
import '../models/nota_sap_grupo.dart';

/// Helper reutilizável para particionar listas em chunks seguros para PostgREST (inFilter).
List<List<T>> chunkList<T>(List<T> list, int chunkSize) {
  if (list.isEmpty || chunkSize <= 0) return [];
  return [
    for (var i = 0; i < list.length; i += chunkSize)
      list.sublist(i, (i + chunkSize > list.length) ? list.length : i + chunkSize)
  ];
}

/// Serviço dedicado para o Backlog Macro e Planejamento Mensal de Notas SAP.
///
/// Responsabilidades:
/// 1. Consulta em 2 fases: Q1 (Grupos ativos + Itens) -> Q2, Q3, Q4 em paralelo com Future.wait.
/// 2. Chunking inteligente (200 IDs) com controle de concorrência.
/// 3. Agregação em memória O(N) com derivação de status válidos de programação e horas estimadas.
/// 4. Histórico de previsões carregado de forma estritamente LAZY.
/// 5. Cache em memória com TTL de 3 minutos e invalidação controlada.
class NotaSapBacklogService {
  final SupabaseClient? _supabaseClient;
  SupabaseClient get _supabase => _supabaseClient ?? SupabaseConfig.client;

  NotaSapBacklogService({SupabaseClient? supabaseClient})
      : _supabaseClient = supabaseClient;

  // Cache em memória
  BacklogMacroResult? _cachedResult;
  DateTime? _cachedAt;
  static const Duration _cacheTtl = Duration(minutes: 3);

  /// Invalida o cache local para forçar nova consulta ao backend.
  void invalidarCache() {
    _cachedResult = null;
    _cachedAt = null;
    debugPrint('[NotaSapBacklogService] Cache invalidado.');
  }

  /// Busca o Backlog Macro completo com suporte a cache e filtros.
  Future<BacklogMacroResult> buscarBacklogMacro({
    BacklogFiltro? filtro,
    bool forcarAtualizacao = false,
    DateTime? dataReferencia,
  }) async {
    final refTime = dataReferencia ?? DateTime.now();

    // 1. Verificar cache (apenas se não houver filtro que exija pushdown e TTL válido)
    if (!forcarAtualizacao && _cachedResult != null && _cachedAt != null) {
      final diferenca = DateTime.now().difference(_cachedAt!);
      if (diferenca < _cacheTtl) {
        debugPrint('[NotaSapBacklogService] Retornando BacklogMacro do cache (${diferenca.inSeconds}s)');
        return _aplicarFiltrosEmMemoria(_cachedResult!, filtro ?? const BacklogFiltro(), refTime);
      }
    }

    try {
      final stopwatchTotal = Stopwatch()..start();

      // =========================================================================
      // FASE 1: Q1 - Grupos Ativos + Itens
      // =========================================================================
      final swQ1 = Stopwatch()..start();
      var queryGrupos = _supabase
          .from('notas_sap_grupos')
          .select('''
            id,
            nome,
            motivo,
            mes_programacao_previsto,
            ano_programacao_previsto,
            local_instalacao,
            equipamento,
            centro_trabalho_responsavel,
            status_grupo,
            created_at,
            notas_sap_grupos_itens(
              nota_sap_id
            )
          ''')
          .eq('status_grupo', 'ativo');

      // Push-down de filtros no Q1 quando aplicáveis
      if (filtro?.mes != null) {
        queryGrupos = queryGrupos.eq('mes_programacao_previsto', filtro!.mes!);
      }
      if (filtro?.ano != null) {
        queryGrupos = queryGrupos.eq('ano_programacao_previsto', filtro!.ano!);
      }

      final gruposRaw = await queryGrupos.order('nome', ascending: true);
      swQ1.stop();

      final List<Map<String, dynamic>> gruposData = List<Map<String, dynamic>>.from(gruposRaw as List);

      // Extrair todos os IDs de notas pertencentes aos grupos ativos
      final Set<String> todosNotaIds = {};
      for (final g in gruposData) {
        final itens = g['notas_sap_grupos_itens'] as List<dynamic>? ?? [];
        for (final it in itens) {
          final nId = it['nota_sap_id']?.toString();
          if (nId != null && nId.isNotEmpty) {
            todosNotaIds.add(nId);
          }
        }
      }

      // Se não houver notas em grupos ativos, retornar resultado vazio imediatamente
      if (todosNotaIds.isEmpty) {
        final vazio = _construirResultadoVazio(filtro ?? const BacklogFiltro());
        if (filtro == null || filtro.isEmpty) {
          _cachedResult = vazio;
          _cachedAt = DateTime.now();
        }
        return vazio;
      }

      final notaIdsList = todosNotaIds.toList();
      final chunks = chunkList(notaIdsList, 200);

      // =========================================================================
      // FASE 2: Q2, Q3, Q4 em paralelo com Future.wait e Chunking
      // =========================================================================
      final swParalelo = Stopwatch()..start();

      final results = await Future.wait([
        _executarChunksNotas(chunks),
        _executarChunksTasks(chunks),
        _executarChunksAnalises(chunks),
      ]);

      swParalelo.stop();

      final List<Map<String, dynamic>> notasRaw = results[0];
      final List<Map<String, dynamic>> tasksRaw = results[1];
      final List<Map<String, dynamic>> analisesRaw = results[2];

      // =========================================================================
      // FASE 3: Agregação em Memória O(N)
      // =========================================================================
      final swAgregacao = Stopwatch()..start();

      // 1. Mapear Análises por nota_sap_id
      final Map<String, Map<String, dynamic>> analisePorNota = {};
      for (final a in analisesRaw) {
        final nId = a['nota_sap_id']?.toString();
        if (nId != null) {
          analisePorNota[nId] = a;
        }
      }

      // 2. Mapear Tasks por nota_sap_id
      final Map<String, List<BacklogTaskInfo>> tasksPorNota = {};
      for (final t in tasksRaw) {
        final nId = t['nota_sap_id']?.toString();
        final taskData = t['tasks'] as Map<String, dynamic>?;
        if (nId != null && taskData != null) {
          final taskInfo = BacklogTaskInfo.fromMap(taskData);
          tasksPorNota.putIfAbsent(nId, () => []).add(taskInfo);
        }
      }

      // 3. Mapear BacklogNotaItem por ID
      final Map<String, BacklogNotaItem> notasPorId = {};
      for (final n in notasRaw) {
        final nId = n['id']?.toString();
        if (nId != null) {
          final analise = analisePorNota[nId];
          final tasks = tasksPorNota[nId] ?? const [];
          final estimativa = analise != null && analise['estimativa_horas'] != null
              ? double.tryParse(analise['estimativa_horas'].toString())
              : null;
          final statusAnalise = analise?['status_analise']?.toString();

          notasPorId[nId] = BacklogNotaItem.fromMap(
            n,
            estimativaHoras: estimativa,
            statusAnalise: statusAnalise,
            tasks: tasks,
          );
        }
      }

      // 4. Montar os BacklogGrupoItem
      final List<BacklogGrupoItem> gruposMontados = [];
      for (final g in gruposData) {
        final gId = g['id'].toString();
        final itens = g['notas_sap_grupos_itens'] as List<dynamic>? ?? [];
        final List<BacklogNotaItem> notasDoGrupo = [];

        for (final it in itens) {
          final nId = it['nota_sap_id']?.toString();
          if (nId != null && notasPorId.containsKey(nId)) {
            notasDoGrupo.add(notasPorId[nId]!);
          }
        }

        // Grupos sem nenhuma nota vinculada não devem poluir o Planejamento Macro
        if (notasDoGrupo.isEmpty) {
          continue;
        }

        gruposMontados.add(BacklogGrupoItem(
          id: gId,
          nome: g['nome']?.toString() ?? '',
          motivo: g['motivo']?.toString(),
          mesProgramacaoPrevisto: g['mes_programacao_previsto'] != null
              ? int.tryParse(g['mes_programacao_previsto'].toString())
              : null,
          anoProgramacaoPrevisto: g['ano_programacao_previsto'] != null
              ? int.tryParse(g['ano_programacao_previsto'].toString())
              : null,
          localInstalacao: g['local_instalacao']?.toString(),
          equipamento: g['equipamento']?.toString(),
          centroTrabalhoResponsavel: g['centro_trabalho_responsavel']?.toString(),
          statusGrupo: g['status_grupo']?.toString() ?? 'ativo',
          createdAt: g['created_at'] != null ? DateTime.tryParse(g['created_at'].toString()) : null,
          notas: notasDoGrupo,
        ));
      }

      // 5. Agrupar por Mês/Ano e "Sem Previsão"
      final Map<String, List<BacklogGrupoItem>> gruposPorMesAno = {};
      final List<BacklogGrupoItem> gruposSemPrevisao = [];

      for (final grupo in gruposMontados) {
        if (grupo.temPrevisao) {
          final key = '${grupo.anoProgramacaoPrevisto}_${grupo.mesProgramacaoPrevisto}';
          gruposPorMesAno.putIfAbsent(key, () => []).add(grupo);
        } else {
          gruposSemPrevisao.add(grupo);
        }
      }

      // 6. Ordenação dos grupos dentro de cada mês:
      // Prioridade visual: parcial -> naoProgramado -> total; depois maior quantidade de pendentes; depois nome
      void ordenarGrupos(List<BacklogGrupoItem> lista) {
        lista.sort((a, b) {
          int scoreStatus(StatusProgramacaoGrupo s) {
            switch (s) {
              case StatusProgramacaoGrupo.parcial:
                return 0; // Mais crítico
              case StatusProgramacaoGrupo.naoProgramado:
                return 1;
              case StatusProgramacaoGrupo.total:
                return 2;
            }
          }

          final c1 = scoreStatus(a.statusProgramacao).compareTo(scoreStatus(b.statusProgramacao));
          if (c1 != 0) return c1;

          final c2 = b.notasPendentes.compareTo(a.notasPendentes); // Mais pendentes primeiro
          if (c2 != 0) return c2;

          return a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
        });
      }

      final List<BacklogMensalResumo> listaMeses = [];
      for (final entry in gruposPorMesAno.entries) {
        final parts = entry.key.split('_');
        final ano = int.parse(parts[0]);
        final mes = int.parse(parts[1]);
        final gruposDoMes = entry.value;
        ordenarGrupos(gruposDoMes);

        listaMeses.add(BacklogMensalResumo(
          ano: ano,
          mes: mes,
          grupos: gruposDoMes,
        ));
      }

      // Ordenar os meses:
      // Mais antigos (ultrapassados) -> mês atual -> meses futuros
      listaMeses.sort((a, b) {
        final pontosA = a.ano! * 12 + a.mes!;
        final pontosB = b.ano! * 12 + b.mes!;
        return pontosA.compareTo(pontosB);
      });

      ordenarGrupos(gruposSemPrevisao);
      final resumoSemPrevisao = gruposSemPrevisao.isNotEmpty
          ? BacklogMensalResumo(grupos: gruposSemPrevisao)
          : null;

      // 7. Calcular KPIs Globais com deduplicação defensiva de notas
      int totalNotasContadas = 0;
      int totalNotasProgramadas = 0;
      int totalNotasPendentes = 0;
      int totalGruposUltrapassados = 0;
      final Set<String> notasUnicasGlobais = {};

      for (final g in gruposMontados) {
        totalNotasContadas += g.totalNotas;
        totalNotasProgramadas += g.notasProgramadas;
        totalNotasPendentes += g.notasPendentes;
        if (g.isPrevisaoUltrapassada(refTime)) {
          totalGruposUltrapassados++;
        }
        for (final n in g.notas) {
          notasUnicasGlobais.add(n.id);
        }
      }

      final bool temAnomaliaIntegridade = totalNotasContadas != notasUnicasGlobais.length;
      if (temAnomaliaIntegridade) {
        debugPrint(
          '[NotaSapBacklogService] ALERTA DE INTEGRIDADE: $totalNotasContadas notas em grupos vs ${notasUnicasGlobais.length} notas únicas!',
        );
      }

      final globalResumo = BacklogGlobalResumo(
        gruposAtivos: gruposMontados.length,
        gruposComPrevisao: gruposMontados.where((g) => g.temPrevisao).length,
        gruposSemPrevisao: gruposSemPrevisao.length,
        gruposUltrapassados: totalGruposUltrapassados,
        notasEmGrupos: totalNotasContadas,
        notasProgramadas: totalNotasProgramadas,
        notasPendentes: totalNotasPendentes,
        notasUnicas: notasUnicasGlobais.length,
        temAnomaliaIntegridade: temAnomaliaIntegridade,
      );

      swAgregacao.stop();
      stopwatchTotal.stop();

      debugPrint(
        '[NotaSapBacklogService] BacklogMacro carregado com sucesso: '
        'Q1: ${swQ1.elapsedMilliseconds}ms | Q2-Q4 (paralelo): ${swParalelo.elapsedMilliseconds}ms | '
        'Agregação: ${swAgregacao.elapsedMilliseconds}ms | Total: ${stopwatchTotal.elapsedMilliseconds}ms | '
        '${gruposMontados.length} grupos, ${notasUnicasGlobais.length} notas, ${chunks.length} chunks',
      );

      final resultado = BacklogMacroResult(
        global: globalResumo,
        meses: listaMeses,
        semPrevisao: resumoSemPrevisao,
        geradoEm: DateTime.now(),
        filtrosAplicados: filtro ?? const BacklogFiltro(),
        todosGrupos: gruposMontados,
      );

      // Salvar em cache se for carga completa sem filtros restritivos
      if (filtro == null || filtro.isEmpty) {
        _cachedResult = resultado;
        _cachedAt = DateTime.now();
      }

      return _aplicarFiltrosEmMemoria(resultado, filtro ?? const BacklogFiltro(), refTime);
    } catch (e, stack) {
      debugPrint('[NotaSapBacklogService] Erro ao buscar BacklogMacro: $e\n$stack');
      rethrow;
    }
  }

  // ===========================================================================
  // EXECUÇÃO CONTROLADA DE CHUNKS
  // ===========================================================================

  Future<List<Map<String, dynamic>>> _executarChunksNotas(List<List<String>> chunks) async {
    final List<Map<String, dynamic>> acumulador = [];
    for (final chunk in chunks) {
      final res = await _supabase
          .from('notas_sap')
          .select('''
            id,
            nota,
            descricao,
            local_instalacao,
            equipamento,
            centro_trabalho_responsavel,
            text_prioridade,
            gpm,
            status_sistema,
            status_usuario
          ''')
          .inFilter('id', chunk);
      acumulador.addAll(List<Map<String, dynamic>>.from(res as List));
    }
    return acumulador;
  }

  Future<List<Map<String, dynamic>>> _executarChunksTasks(List<List<String>> chunks) async {
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

  Future<List<Map<String, dynamic>>> _executarChunksAnalises(List<List<String>> chunks) async {
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

  // ===========================================================================
  // CONSULTA LAZY: HISTÓRICO DE PREVISÕES DO GRUPO
  // ===========================================================================

  /// Busca o histórico de alterações de previsão de um grupo específico de forma estritamente lazy.
  Future<List<NotaSapGrupoPrevisaoHist>> buscarHistoricoGrupo(String grupoId) async {
    try {
      final res = await _supabase
          .from('notas_sap_grupos_previsoes_hist')
          .select('''
            id,
            grupo_id,
            mes_anterior,
            ano_anterior,
            mes_novo,
            ano_novo,
            motivo,
            alterado_por,
            alterado_por_nome,
            alterado_em
          ''')
          .eq('grupo_id', grupoId)
          .order('alterado_em', ascending: false);

      final list = List<Map<String, dynamic>>.from(res as List);
      return list.map((m) => NotaSapGrupoPrevisaoHist.fromMap(m)).toList();
    } catch (e) {
      debugPrint('[NotaSapBacklogService] Erro ao buscar histórico do grupo $grupoId: $e');
      return [];
    }
  }

  // ===========================================================================
  // FILTRAGEM EM MEMÓRIA
  // ===========================================================================

  BacklogMacroResult _aplicarFiltrosEmMemoria(
    BacklogMacroResult original,
    BacklogFiltro filtro,
    DateTime refTime,
  ) {
    if (filtro.isEmpty) return original;

    final gruposFiltrados = original.todosGrupos.where((g) {
      // 1. Mês e Ano
      if (filtro.mes != null && g.mesProgramacaoPrevisto != filtro.mes) return false;
      if (filtro.ano != null && g.anoProgramacaoPrevisto != filtro.ano) return false;

      // 2. Previsão
      if (filtro.apenasComPrevisao == true && !g.temPrevisao) return false;
      if (filtro.apenasSemPrevisao == true && g.temPrevisao) return false;
      if (filtro.apenasUltrapassados == true && !g.isPrevisaoUltrapassada(refTime)) return false;

      // 3. Status de Programação
      if (filtro.statusProgramacao != null && g.statusProgramacao != filtro.statusProgramacao) {
        return false;
      }

      // 4. Centro de Trabalho
      if (filtro.centroTrabalho != null && filtro.centroTrabalho!.isNotEmpty) {
        final ctMatch = g.centroTrabalhoResponsavel?.toLowerCase() == filtro.centroTrabalho!.toLowerCase() ||
            g.notas.any((n) => n.centroTrabalhoResponsavel?.toLowerCase() == filtro.centroTrabalho!.toLowerCase());
        if (!ctMatch) return false;
      }

      // 5. Local de Instalação
      if (filtro.localInstalacao != null && filtro.localInstalacao!.isNotEmpty) {
        final locMatch = (g.localInstalacao?.toLowerCase().contains(filtro.localInstalacao!.toLowerCase()) ?? false) ||
            g.notas.any((n) => n.localInstalacao?.toLowerCase().contains(filtro.localInstalacao!.toLowerCase()) ?? false);
        if (!locMatch) return false;
      }

      // 6. Equipamento
      if (filtro.equipamento != null && filtro.equipamento!.isNotEmpty) {
        final eqMatch = (g.equipamento?.toLowerCase().contains(filtro.equipamento!.toLowerCase()) ?? false) ||
            g.notas.any((n) => n.equipamento?.toLowerCase().contains(filtro.equipamento!.toLowerCase()) ?? false);
        if (!eqMatch) return false;
      }

      // 7. Busca Textual Ampla
      if (filtro.buscaTexto != null && filtro.buscaTexto!.trim().isNotEmpty) {
        final q = filtro.buscaTexto!.trim().toLowerCase();
        final matchGrupo = g.nome.toLowerCase().contains(q) ||
            (g.motivo?.toLowerCase().contains(q) ?? false) ||
            (g.localInstalacao?.toLowerCase().contains(q) ?? false) ||
            (g.equipamento?.toLowerCase().contains(q) ?? false);

        final matchNota = g.notas.any((n) =>
            n.nota.toLowerCase().contains(q) ||
            n.descricao.toLowerCase().contains(q) ||
            (n.localInstalacao?.toLowerCase().contains(q) ?? false) ||
            (n.equipamento?.toLowerCase().contains(q) ?? false));

        if (!matchGrupo && !matchNota) return false;
      }

      return true;
    }).toList();

    // Reagrupar
    final Map<String, List<BacklogGrupoItem>> gruposPorMesAno = {};
    final List<BacklogGrupoItem> gruposSemPrevisao = [];

    for (final grupo in gruposFiltrados) {
      if (grupo.temPrevisao) {
        final key = '${grupo.anoProgramacaoPrevisto}_${grupo.mesProgramacaoPrevisto}';
        gruposPorMesAno.putIfAbsent(key, () => []).add(grupo);
      } else {
        gruposSemPrevisao.add(grupo);
      }
    }

    final List<BacklogMensalResumo> listaMeses = [];
    for (final entry in gruposPorMesAno.entries) {
      final parts = entry.key.split('_');
      final ano = int.parse(parts[0]);
      final mes = int.parse(parts[1]);
      listaMeses.add(BacklogMensalResumo(ano: ano, mes: mes, grupos: entry.value));
    }

    listaMeses.sort((a, b) {
      final pontosA = a.ano! * 12 + a.mes!;
      final pontosB = b.ano! * 12 + b.mes!;
      return pontosA.compareTo(pontosB);
    });

    final resumoSemPrevisao = gruposSemPrevisao.isNotEmpty
        ? BacklogMensalResumo(grupos: gruposSemPrevisao)
        : null;

    // Recalcular KPIs com os grupos filtrados
    int totalNotasContadas = 0;
    int totalNotasProgramadas = 0;
    int totalNotasPendentes = 0;
    int totalGruposUltrapassados = 0;
    final Set<String> notasUnicas = {};

    for (final g in gruposFiltrados) {
      totalNotasContadas += g.totalNotas;
      totalNotasProgramadas += g.notasProgramadas;
      totalNotasPendentes += g.notasPendentes;
      if (g.isPrevisaoUltrapassada(refTime)) {
        totalGruposUltrapassados++;
      }
      for (final n in g.notas) {
        notasUnicas.add(n.id);
      }
    }

    final globalResumo = BacklogGlobalResumo(
      gruposAtivos: gruposFiltrados.length,
      gruposComPrevisao: gruposFiltrados.where((g) => g.temPrevisao).length,
      gruposSemPrevisao: gruposSemPrevisao.length,
      gruposUltrapassados: totalGruposUltrapassados,
      notasEmGrupos: totalNotasContadas,
      notasProgramadas: totalNotasProgramadas,
      notasPendentes: totalNotasPendentes,
      notasUnicas: notasUnicas.length,
      temAnomaliaIntegridade: totalNotasContadas != notasUnicas.length,
    );

    return BacklogMacroResult(
      global: globalResumo,
      meses: listaMeses,
      semPrevisao: resumoSemPrevisao,
      geradoEm: original.geradoEm,
      filtrosAplicados: filtro,
      todosGrupos: gruposFiltrados,
    );
  }

  BacklogMacroResult _construirResultadoVazio(BacklogFiltro filtro) {
    return BacklogMacroResult(
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
      semPrevisao: null,
      geradoEm: DateTime.now(),
      filtrosAplicados: filtro,
      todosGrupos: const [],
    );
  }
}
