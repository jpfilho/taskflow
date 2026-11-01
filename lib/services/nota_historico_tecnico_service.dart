import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/nota_sap.dart';
import '../models/nota_sap_analise.dart';
import '../models/nota_sap_similaridade.dart';
import '../models/nota_historico_tecnico.dart';
import '../utils/instalacao_sap_helper.dart';
import 'nota_sap_similaridade_service.dart';

/// Serviço do Histórico Técnico de Notas SAP Anteriores (Read-Only).
///
/// Responsável por:
/// 1. Busca paralela e determinística por Equipamento (Critério A), Sala/Estrutura (Critério B)
///    e Instalação (Critério C), restrita à chave canônica da instalação.
/// 2. Integração semântica com o NotaSapSimilaridadeService (Critério D).
/// 3. Deduplicação unificada por ID com preservação simultânea de vínculos físicos e score.
/// 4. Levantamento de inventário em lote (sem N+1).
/// 5. Carregamento sob demanda (Lazy Loading) de anexos, análise técnica e tarefas anteriores.
class NotaHistoricoTecnicoService {
  final SupabaseClient? _supabaseClient;
  final NotaSapSimilaridadeService _similaridadeService;

  SupabaseClient get _supabase => _supabaseClient ?? Supabase.instance.client;

  // Cache em memória durante o ciclo do Workspace
  final Map<String, NotaHistoricoTecnicoResultado> _cacheResultados = {};
  final Map<String, NotaHistoricoTecnicoItem> _cacheDetalhesLazy = {};

  NotaHistoricoTecnicoService({
    SupabaseClient? supabaseClient,
    NotaSapSimilaridadeService? similaridadeService,
  })  : _supabaseClient = supabaseClient,
        _similaridadeService =
            similaridadeService ?? NotaSapSimilaridadeService(supabaseClient: supabaseClient);

  /// Busca o histórico técnico completo (metadados e inventários) da Nota de referência.
  Future<NotaHistoricoTecnicoResultado> buscarHistoricoTecnico({
    required NotaSAP notaReferencia,
    bool forceRefresh = false,
  }) async {
    final resUtil = await carregarHistoricoAtivoUtil(
      notaReferencia: notaReferencia,
      forceRefresh: forceRefresh,
    );

    // Se já estiver com similares e local amplo carregados do cache, retorna
    if (!resUtil.carregandoSimilares && !resUtil.carregandoLocalAmplo) {
      return resUtil;
    }

    final resComSim = await carregarSimilaresAssincrono(resUtil);
    final resCompleto = await carregarLocalAmploAssincrono(resComSim);
    return resCompleto;
  }

  /// ETAPA 1 (Time to Useful History): Carrega imediatamente A (Mesmo Equipamento)
  /// e B (Mesma Estrutura) em paralelo com inventário em lote rápido (~400ms).
  Future<NotaHistoricoTecnicoResultado> carregarHistoricoAtivoUtil({
    required NotaSAP notaReferencia,
    bool forceRefresh = false,
  }) async {
    final agora = DateTime.now();
    if (!forceRefresh && _cacheResultados.containsKey(notaReferencia.id)) {
      return _cacheResultados[notaReferencia.id]!;
    }

    final stopwatch = Stopwatch()..start();

    try {
      final chaveInstalacao =
          InstalacaoSapHelper.extrairChaveInstalacao(notaReferencia.localInstalacao);
      final localNome = notaReferencia.local?.trim();
      final eq = (notaReferencia.equipamento ?? '').trim();
      final sala = (notaReferencia.sala ?? '').trim();
      final temSalaValida = InstalacaoSapHelper.ehSalaValidaParaCriterioB(sala);
      final salaRefNorm = InstalacaoSapHelper.normalizarSala(sala);

      // 1. Execução Paralela Estrita: Critério A (Equipamento) e Critério B (Estrutura/Sala)
      // Se a nota tiver sala válida, a busca por equipamento também é restrita à mesma sala
      final futureEq = (eq.isNotEmpty)
          ? _buscarPorEquipamento(
              equipamento: eq,
              chaveInstalacao: chaveInstalacao,
              localNome: localNome,
              sala: temSalaValida ? sala : null,
              notaIdRef: notaReferencia.id,
            )
          : Future.value(<NotaSAP>[]);

      final futureSala = (temSalaValida && (chaveInstalacao != null || (localNome != null && localNome.isNotEmpty)))
          ? _buscarPorSala(
              sala: sala,
              chaveInstalacao: chaveInstalacao,
              localNome: localNome,
              notaIdRef: notaReferencia.id,
            )
          : Future.value(<NotaSAP>[]);

      final resultadosParalelos = await Future.wait([futureEq, futureSala]);
      final notasEq = resultadosParalelos[0];
      final notasSala = resultadosParalelos[1];

      // 2. Mapeamento e Deduplicação inicial de A e B com validação estrita de Local e Sala
      final itensMap = <String, NotaHistoricoTecnicoItem>{};
      final idsAB = <String>{};

      for (final n in notasEq) {
        // Se a nota possui sala definida, descarta notas de outras salas
        if (temSalaValida) {
          final nSalaNorm = InstalacaoSapHelper.normalizarSala(n.sala);
          if (nSalaNorm.isNotEmpty && nSalaNorm != salaRefNorm) {
            continue;
          }
        }
        // Se a nota possui local definido, descarta notas de outros locais
        if (localNome != null && localNome.isNotEmpty && n.local != null && n.local!.trim().isNotEmpty) {
          if (n.local!.trim().toUpperCase() != localNome.toUpperCase() &&
              !InstalacaoSapHelper.saoMesmaInstalacao(notaReferencia.localInstalacao, n.localInstalacao)) {
            continue;
          }
        }

        idsAB.add(n.id);
        final motivos = <String>['Mesmo equipamento ($eq)'];
        if (temSalaValida &&
            n.sala != null &&
            InstalacaoSapHelper.normalizarSala(n.sala) == salaRefNorm) {
          motivos.add('Mesma estrutura ($sala)');
        }

        itensMap[n.id] = NotaHistoricoTecnicoItem(
          notaSap: n,
          criterioFisicoPrincipal: NotaHistoricoCriterioFisico.mesmoEquipamento,
          motivosFisicos: motivos,
        );
      }

      for (final n in notasSala) {
        if (temSalaValida) {
          final nSalaNorm = InstalacaoSapHelper.normalizarSala(n.sala);
          if (nSalaNorm.isNotEmpty && nSalaNorm != salaRefNorm) {
            continue;
          }
        }
        if (localNome != null && localNome.isNotEmpty && n.local != null && n.local!.trim().isNotEmpty) {
          if (n.local!.trim().toUpperCase() != localNome.toUpperCase() &&
              !InstalacaoSapHelper.saoMesmaInstalacao(notaReferencia.localInstalacao, n.localInstalacao)) {
            continue;
          }
        }

        idsAB.add(n.id);
        if (itensMap.containsKey(n.id)) continue;

        itensMap[n.id] = NotaHistoricoTecnicoItem(
          notaSap: n,
          criterioFisicoPrincipal: NotaHistoricoCriterioFisico.mesmaEstrutura,
          motivosFisicos: ['Mesma estrutura ($sala)'],
        );
      }

      // 3. Inventário em Lote (Batch) das Notas A e B visíveis
      if (idsAB.isNotEmpty) {
        final inventario = await _carregarInventarioBatch(idsAB.toList());
        for (final id in idsAB) {
          final item = itensMap[id];
          final inv = inventario[id];
          if (item != null && inv != null) {
            itensMap[id] = NotaHistoricoTecnicoItem(
              notaSap: item.notaSap,
              criterioFisicoPrincipal: item.criterioFisicoPrincipal,
              motivosFisicos: item.motivosFisicos,
              totalAnexos: inv.totalAnexos,
              temAnalise: inv.temAnalise,
              totalTasks: inv.totalTasks,
            );
          }
        }
      }

      final itensEq = itensMap.values
          .where((i) => i.criterioFisicoPrincipal == NotaHistoricoCriterioFisico.mesmoEquipamento)
          .toList()
        ..sort(_compararPorRecencia);

      final itensEstrutura = itensMap.values
          .where((i) => i.criterioFisicoPrincipal == NotaHistoricoCriterioFisico.mesmaEstrutura)
          .toList()
        ..sort(_compararPorRecencia);

      stopwatch.stop();

      final resultadoUtil = NotaHistoricoTecnicoResultado(
        notaReferencia: notaReferencia,
        itensEquipamento: itensEq,
        itensEstrutura: itensEstrutura,
        itensLocal: const [],
        itensApenasSimilaridade: const [],
        todosItensDeduplicados: [...itensEq, ...itensEstrutura],
        calculadoEm: agora,
        carregandoSimilares: true,
        carregandoLocalAmplo: true,
        timeToUsefulHistoryMs: stopwatch.elapsedMilliseconds,
      );

      _cacheResultados[notaReferencia.id] = resultadoUtil;
      return resultadoUtil;
    } catch (e) {
      debugPrint('❌ [NotaHistoricoTecnicoService.carregarHistoricoAtivoUtil] Erro: $e');
      return NotaHistoricoTecnicoResultado(
        notaReferencia: notaReferencia,
        calculadoEm: agora,
      );
    }
  }

  /// ETAPA 2: Carrega Similaridade Técnica (Critério D) via motor oficial
  /// e enriquece os itens já existentes ou adiciona novos com score >= 40.0.
  Future<NotaHistoricoTecnicoResultado> carregarSimilaresAssincrono(
    NotaHistoricoTecnicoResultado resultadoAtual, {
    bool forceRefresh = false,
  }) async {
    try {
      final resSimilaridade = await _similaridadeService.buscarSimilaridades(
        notaReferencia: resultadoAtual.notaReferencia,
        forceRefresh: forceRefresh,
      );

      // Mapa de notas similares por ID
      final mapSimilares = <String, NotaSapSimilar>{};
      for (final sim in resSimilaridade.todasOcorrencias) {
        mapSimilares[sim.nota.id] = sim;
      }
      for (final sim in resSimilaridade.historicoMesmoAtivo) {
        mapSimilares[sim.nota.id] = sim;
      }

      // 1. Atualizar itens existentes com score e evidências de similaridade
      final itensAtualizados = <String, NotaHistoricoTecnicoItem>{};
      for (final item in resultadoAtual.todosItensDeduplicados) {
        final sim = mapSimilares[item.notaSap.id];
        if (sim != null) {
          itensAtualizados[item.notaSap.id] = item.copyWithSimilaridade(
            ehSimilar: true,
            scoreSimilaridade: sim.scoreTotal,
            tokensCoincidentes: sim.evidencias.tokensCoincidentes,
          );
        } else {
          itensAtualizados[item.notaSap.id] = item;
        }
      }

      // 2. Identificar novos itens puramente de Critério D (com score oficial >= 40.0)
      final novasNotasD = <String, NotaHistoricoTecnicoItem>{};
      final novosIdsParaInventario = <String>[];

      final salaRef = (resultadoAtual.notaReferencia.sala ?? '').trim();
      final temSalaValida = InstalacaoSapHelper.ehSalaValidaParaCriterioB(salaRef);
      final salaRefNorm = InstalacaoSapHelper.normalizarSala(salaRef);

      for (final sim in resSimilaridade.todasOcorrencias) {
        if (!itensAtualizados.containsKey(sim.nota.id)) {
          // Filtro do Threshold Oficial: descarta menos de 40 pontos
          if (sim.faixa == FaixaSimilaridade.descartada || sim.scoreTotal < 40.0) {
            continue;
          }

          // Se a nota similar possui sala definida e a nota de referência também, devem ser da mesma sala
          if (temSalaValida && sim.nota.sala != null && sim.nota.sala!.trim().isNotEmpty) {
            final salaSim = InstalacaoSapHelper.normalizarSala(sim.nota.sala);
            if (salaSim != salaRefNorm) {
              continue;
            }
          }

          novosIdsParaInventario.add(sim.nota.id);
          novasNotasD[sim.nota.id] = NotaHistoricoTecnicoItem(
            notaSap: sim.nota,
            criterioFisicoPrincipal: NotaHistoricoCriterioFisico.apenasSimilaridade,
            motivosFisicos: const ['Ocorrência semelhante por similaridade técnica'],
            ehSimilar: true,
            scoreSimilaridade: sim.scoreTotal,
            tokensCoincidentes: sim.evidencias.tokensCoincidentes,
          );
        }
      }

      // 3. Inventário em Batch apenas das novas notas adicionadas por D
      if (novosIdsParaInventario.isNotEmpty) {
        final inv = await _carregarInventarioBatch(novosIdsParaInventario);
        for (final id in novosIdsParaInventario) {
          final item = novasNotasD[id];
          final dInv = inv[id];
          if (item != null && dInv != null) {
            novasNotasD[id] = NotaHistoricoTecnicoItem(
              notaSap: item.notaSap,
              criterioFisicoPrincipal: item.criterioFisicoPrincipal,
              motivosFisicos: item.motivosFisicos,
              ehSimilar: item.ehSimilar,
              scoreSimilaridade: item.scoreSimilaridade,
              tokensCoincidentes: item.tokensCoincidentes,
              totalAnexos: dInv.totalAnexos,
              temAnalise: dInv.temAnalise,
              totalTasks: dInv.totalTasks,
            );
          }
        }
      }

      final todosItensApenasSim = novasNotasD.values.toList()
        ..sort((a, b) {
          final sA = a.scoreSimilaridade ?? 0.0;
          final sB = b.scoreSimilaridade ?? 0.0;
          final comp = sB.compareTo(sA);
          if (comp != 0) return comp;
          return _compararPorRecencia(a, b);
        });

      final itensEq = itensAtualizados.values
          .where((i) => i.criterioFisicoPrincipal == NotaHistoricoCriterioFisico.mesmoEquipamento)
          .toList()
        ..sort(_compararPorRecencia);

      final itensEstrutura = itensAtualizados.values
          .where((i) => i.criterioFisicoPrincipal == NotaHistoricoCriterioFisico.mesmaEstrutura)
          .toList()
        ..sort(_compararPorRecencia);

      final itensLocal = itensAtualizados.values
          .where((i) => i.criterioFisicoPrincipal == NotaHistoricoCriterioFisico.mesmoLocal)
          .toList()
        ..sort(_compararPorRecencia);

      final todosOrdenados = [
        ...itensEq,
        ...itensEstrutura,
        ...itensLocal,
        ...todosItensApenasSim,
      ];

      final resultadoAtualizado = resultadoAtual.copyWith(
        itensEquipamento: itensEq,
        itensEstrutura: itensEstrutura,
        itensLocal: itensLocal,
        itensApenasSimilaridade: todosItensApenasSim,
        todosItensDeduplicados: todosOrdenados,
        carregandoSimilares: false,
      );

      _cacheResultados[resultadoAtual.notaReferencia.id] = resultadoAtualizado;
      return resultadoAtualizado;
    } catch (e) {
      debugPrint('⚠️ [NotaHistoricoTecnicoService.carregarSimilaresAssincrono] Erro: $e');
      return resultadoAtual.copyWith(carregandoSimilares: false);
    }
  }

  /// ETAPA 3: Carrega Contexto Amplo (Critério C) de forma progressiva e não bloqueante.
  Future<NotaHistoricoTecnicoResultado> carregarLocalAmploAssincrono(
    NotaHistoricoTecnicoResultado resultadoAtual,
  ) async {
    final sala = (resultadoAtual.notaReferencia.sala ?? '').trim();
    final temSalaValida = InstalacaoSapHelper.ehSalaValidaParaCriterioB(sala);

    // Se a nota possui sala definida, o critério amplo de outras salas do local NÃO é executado,
    // garantindo que as notas anteriores sejam estritamente da mesma sala e mesmo local.
    if (temSalaValida) {
      return resultadoAtual.copyWith(carregandoLocalAmplo: false);
    }

    final chaveInstalacao =
        InstalacaoSapHelper.extrairChaveInstalacao(resultadoAtual.notaReferencia.localInstalacao);

    if (chaveInstalacao == null) {
      return resultadoAtual.copyWith(carregandoLocalAmplo: false);
    }

    try {
      final notasLocal = await _buscarPorLocalAmplo(
        chaveInstalacao: chaveInstalacao,
        localNome: resultadoAtual.notaReferencia.local,
        notaIdRef: resultadoAtual.notaReferencia.id,
        limite: 5,
      );

      final mapaExistente = <String, NotaHistoricoTecnicoItem>{};
      for (final item in resultadoAtual.todosItensDeduplicados) {
        mapaExistente[item.notaSap.id] = item;
      }

      final novasNotasC = <String, NotaHistoricoTecnicoItem>{};
      final novosIds = <String>[];

      for (final n in notasLocal) {
        if (!mapaExistente.containsKey(n.id)) {
          novosIds.add(n.id);
          novasNotasC[n.id] = NotaHistoricoTecnicoItem(
            notaSap: n,
            criterioFisicoPrincipal: NotaHistoricoCriterioFisico.mesmoLocal,
            motivosFisicos: ['Mesmo local ($chaveInstalacao)'],
          );
        }
      }

      if (novosIds.isNotEmpty) {
        final inv = await _carregarInventarioBatch(novosIds);
        for (final id in novosIds) {
          final item = novasNotasC[id];
          final cInv = inv[id];
          if (item != null && cInv != null) {
            novasNotasC[id] = NotaHistoricoTecnicoItem(
              notaSap: item.notaSap,
              criterioFisicoPrincipal: item.criterioFisicoPrincipal,
              motivosFisicos: item.motivosFisicos,
              totalAnexos: cInv.totalAnexos,
              temAnalise: cInv.temAnalise,
              totalTasks: cInv.totalTasks,
            );
          }
        }
      }

      final itensLocal = [
        ...resultadoAtual.itensLocal,
        ...novasNotasC.values,
      ]..sort(_compararPorRecencia);

      final todosOrdenados = [
        ...resultadoAtual.itensEquipamento,
        ...resultadoAtual.itensEstrutura,
        ...itensLocal,
        ...resultadoAtual.itensApenasSimilaridade,
      ];

      final resultadoFinal = resultadoAtual.copyWith(
        itensLocal: itensLocal,
        todosItensDeduplicados: todosOrdenados,
        carregandoLocalAmplo: false,
      );

      _cacheResultados[resultadoAtual.notaReferencia.id] = resultadoFinal;
      return resultadoFinal;
    } catch (e) {
      debugPrint('⚠️ [NotaHistoricoTecnicoService.carregarLocalAmploAssincrono] Erro: $e');
      return resultadoAtual.copyWith(carregandoLocalAmplo: false);
    }
  }

  /// Carrega sob demanda (Lazy Loading) os detalhes da Nota Histórica:
  /// - Anexos originais
  /// - Análise técnica anterior
  /// - Tarefas operacionais vinculadas
  Future<NotaHistoricoTecnicoItem> carregarDetalhesLazy(NotaHistoricoTecnicoItem item) async {
    final notaId = item.notaSap.id;
    if (_cacheDetalhesLazy.containsKey(notaId)) {
      return _cacheDetalhesLazy[notaId]!;
    }

    try {
      final futures = await Future.wait([
        _carregarAnexosDaNota(notaId),
        _carregarAnaliseDaNota(notaId),
        _carregarTasksDaNota(notaId),
      ]);

      final anexos = futures[0] as List<NotaSapAnexo>;
      final analise = futures[1] as NotaSapAnalise?;
      final tasks = futures[2] as List<TarefaHistoricaResumo>;

      final itemAtualizado = item.copyWithDetalhes(
        anexos: anexos,
        analise: analise,
        tasks: tasks,
      );

      _cacheDetalhesLazy[notaId] = itemAtualizado;
      return itemAtualizado;
    } catch (e) {
      debugPrint('❌ [NotaHistoricoTecnicoService.carregarDetalhesLazy] Erro para nota $notaId: $e');
      return item;
    }
  }

  int _compararPorRecencia(NotaHistoricoTecnicoItem a, NotaHistoricoTecnicoItem b) {
    final dtA = a.notaSap.criadoEm ?? DateTime(1970);
    final dtB = b.notaSap.criadoEm ?? DateTime(1970);
    return dtB.compareTo(dtA);
  }

  // ===========================================================================
  // MÉTODOS DE CONSULTA NO BANCO DE DADOS
  // ===========================================================================

  Future<List<NotaSAP>> _buscarPorEquipamento({
    required String equipamento,
    required String? chaveInstalacao,
    String? localNome,
    String? sala,
    required String notaIdRef,
  }) async {
    try {
      var query = _supabase
          .from('notas_sap')
          .select()
          .eq('equipamento', equipamento)
          .neq('id', notaIdRef);

      if (sala != null && sala.isNotEmpty) {
        query = query.ilike('sala', sala);
      }

      if (localNome != null && localNome.trim().isNotEmpty) {
        query = query.ilike('local', localNome.trim());
      } else if (chaveInstalacao != null && chaveInstalacao.isNotEmpty) {
        query = query.ilike('local_instalacao', '$chaveInstalacao%');
      }

      final res = await query.order('criado_em', ascending: false).limit(10);
      return (res as List).map((m) => NotaSAP.fromMap(m)).toList();
    } catch (e) {
      debugPrint('⚠️ Erro busca por equipamento: $e');
      return const [];
    }
  }

  Future<List<NotaSAP>> _buscarPorSala({
    required String sala,
    required String? chaveInstalacao,
    String? localNome,
    required String notaIdRef,
  }) async {
    try {
      var query = _supabase
          .from('notas_sap')
          .select()
          .ilike('sala', sala)
          .neq('id', notaIdRef);

      if (localNome != null && localNome.trim().isNotEmpty) {
        query = query.ilike('local', localNome.trim());
      } else if (chaveInstalacao != null && chaveInstalacao.isNotEmpty) {
        query = query.ilike('local_instalacao', '$chaveInstalacao%');
      }

      final res = await query.order('criado_em', ascending: false).limit(10);
      return (res as List).map((m) => NotaSAP.fromMap(m)).toList();
    } catch (e) {
      debugPrint('⚠️ Erro busca por sala: $e');
      return const [];
    }
  }

  Future<List<NotaSAP>> _buscarPorLocalAmplo({
    required String chaveInstalacao,
    String? localNome,
    required String notaIdRef,
    int limite = 5,
  }) async {
    try {
      var query = _supabase
          .from('notas_sap')
          .select()
          .neq('id', notaIdRef);

      if (localNome != null && localNome.trim().isNotEmpty) {
        query = query.ilike('local', localNome.trim());
      } else if (chaveInstalacao.isNotEmpty) {
        query = query.ilike('local_instalacao', '$chaveInstalacao%');
      }

      final res = await query
          .order('criado_em', ascending: false)
          .limit(limite);

      return (res as List).map((m) => NotaSAP.fromMap(m)).toList();
    } catch (e) {
      debugPrint('⚠️ Erro busca por local amplo: $e');
      return const [];
    }
  }

  Future<Map<String, _InventarioBatch>> _carregarInventarioBatch(List<String> notaIds) async {
    final mapa = <String, _InventarioBatch>{};
    for (final id in notaIds) {
      mapa[id] = _InventarioBatch();
    }

    try {
      final fAnexos = _supabase
          .from('notas_sap_anexos')
          .select('nota_sap_id')
          .inFilter('nota_sap_id', notaIds);

      final fAnalises = _supabase
          .from('notas_sap_analises')
          .select('nota_sap_id')
          .inFilter('nota_sap_id', notaIds);

      final fTasks = _supabase
          .from('tasks_notas_sap')
          .select('nota_sap_id')
          .inFilter('nota_sap_id', notaIds);

      final resList = await Future.wait<dynamic>([fAnexos, fAnalises, fTasks]);

      final resAnexos = resList[0] as List;
      for (final r in resAnexos) {
        final nid = r['nota_sap_id']?.toString();
        if (nid != null && mapa.containsKey(nid)) {
          mapa[nid]!.totalAnexos++;
        }
      }

      final resAnalises = resList[1] as List;
      for (final r in resAnalises) {
        final nid = r['nota_sap_id']?.toString();
        if (nid != null && mapa.containsKey(nid)) {
          mapa[nid]!.temAnalise = true;
        }
      }

      final resTasks = resList[2] as List;
      for (final r in resTasks) {
        final nid = r['nota_sap_id']?.toString();
        if (nid != null && mapa.containsKey(nid)) {
          mapa[nid]!.totalTasks++;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Erro ao carregar inventário batch: $e');
    }

    return mapa;
  }

  Future<List<NotaSapAnexo>> _carregarAnexosDaNota(String notaId) async {
    try {
      final res = await _supabase
          .from('notas_sap_anexos')
          .select()
          .eq('nota_sap_id', notaId)
          .order('created_at', ascending: false);

      return (res as List).map((m) => NotaSapAnexo.fromMap(m)).toList();
    } catch (e) {
      debugPrint('⚠️ Erro ao carregar anexos da nota $notaId: $e');
      return const [];
    }
  }

  Future<NotaSapAnalise?> _carregarAnaliseDaNota(String notaId) async {
    try {
      final res = await _supabase
          .from('notas_sap_analises')
          .select()
          .eq('nota_sap_id', notaId)
          .maybeSingle();

      if (res != null) {
        return NotaSapAnalise.fromMap(res);
      }
    } catch (e) {
      debugPrint('⚠️ Erro ao carregar análise da nota $notaId: $e');
    }
    return null;
  }

  Future<List<TarefaHistoricaResumo>> _carregarTasksDaNota(String notaId) async {
    try {
      final res = await _supabase
          .from('tasks_notas_sap')
          .select('task_id, tasks(id, tarefa, status, horas_executadas, horas_previstas, executor, data_inicio, data_fim)')
          .eq('nota_sap_id', notaId);

      final lista = <TarefaHistoricaResumo>[];
      for (final item in (res as List)) {
        final taskData = item['tasks'] as Map<String, dynamic>?;
        if (taskData != null) {
          final executoresList = <String>[];
          final rawExec = taskData['executor'];
          if (rawExec is List) {
            executoresList.addAll(rawExec.map((e) => e.toString()));
          } else if (rawExec != null && rawExec.toString().trim().isNotEmpty) {
            executoresList.add(rawExec.toString().trim());
          }

          lista.add(
            TarefaHistoricaResumo(
              id: taskData['id']?.toString() ?? '',
              tarefaNome: taskData['tarefa']?.toString(),
              status: taskData['status']?.toString() ?? '',
              totalExecutores: executoresList.length,
              executores: executoresList,
              horasExecutadas: taskData['horas_executadas'] != null
                  ? (taskData['horas_executadas'] as num).toDouble()
                  : null,
              horasPrevistas: taskData['horas_previstas'] != null
                  ? (taskData['horas_previstas'] as num).toDouble()
                  : null,
              dataInicio: taskData['data_inicio'] != null
                  ? DateTime.tryParse(taskData['data_inicio'].toString())
                  : null,
              dataFim: taskData['data_fim'] != null
                  ? DateTime.tryParse(taskData['data_fim'].toString())
                  : null,
            ),
          );
        }
      }
      return lista;
    } catch (e) {
      debugPrint('⚠️ Erro ao carregar tasks da nota $notaId: $e');
      return const [];
    }
  }

  /// Limpa caches em memória.
  void limparCache() {
    _cacheResultados.clear();
    _cacheDetalhesLazy.clear();
  }
}

class _InventarioBatch {
  int totalAnexos = 0;
  bool temAnalise = false;
  int totalTasks = 0;
}
