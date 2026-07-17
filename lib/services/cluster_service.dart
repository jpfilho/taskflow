import 'package:flutter/foundation.dart';
import '../models/nota_sap.dart';
import '../models/ordem.dart';
import 'nota_sap_service.dart';
import 'ordem_service.dart';

class AtivoCluster {
  final String localKey; // Chave de agrupamento (Local normalizado)
  final String local;    // Nome amigável do Local
  final String sala;     // Nome da Sala
  final List<NotaSAP> notas;
  final List<Ordem> ordens;
  final DateTime? prazoCritico;
  final int? diasRestantes;
  final String prioridadeCritica;
  final bool estaProgramado;
  // Mapeamento de demanda para dados da tarefa vinculada (se houver)
  final Map<String, Map<String, dynamic>> tarefasNotas;  // notaId -> tarefa
  final Map<String, Map<String, dynamic>> tarefasOrdens; // ordemId -> tarefa

  AtivoCluster({
    required this.localKey,
    required this.local,
    required this.sala,
    required this.notas,
    required this.ordens,
    this.prazoCritico,
    this.diasRestantes,
    required this.prioridadeCritica,
    required this.estaProgramado,
    required this.tarefasNotas,
    required this.tarefasOrdens,
  });

  int get totalDemandas => notas.length + ordens.length;
}

class ClusterService {
  static final ClusterService _instance = ClusterService._internal();
  factory ClusterService() => _instance;
  ClusterService._internal();

  final NotaSAPService _notaSapService = NotaSAPService();
  final OrdemService _ordemService = OrdemService();

  Future<List<AtivoCluster>> getClustersAtivos({
    String? regionalId,
    String? divisaoId,
    String? segmentoId,
    bool apenasNaoProgramados = false,
  }) async {
    try {
      // 1. Carregar todas as Notas SAP abertas
      final notasAbertasBrutas = await _notaSapService.getAllNotas(
        filtroTipoNota: 'abertas',
      );

      // Evitar duplicação por número da nota
      final seenNotas = <String>{};
      final notasAbertas = <NotaSAP>[];
      for (final n in notasAbertasBrutas) {
        if (seenNotas.add(n.nota)) {
          notasAbertas.add(n);
        }
      }

      // 2. Carregar todas as Ordens abertas
      final ordensAbertasBrutas = await _ordemService.getAllOrdens(
        apenasAbertas: true,
      );

      // Evitar duplicação por número da ordem
      final seenOrdens = <String>{};
      final ordensAbertas = <Ordem>[];
      for (final o in ordensAbertasBrutas) {
        if (seenOrdens.add(o.ordem)) {
          ordensAbertas.add(o);
        }
      }

      // 3. Obter notas e ordens programadas para saber se já estão vinculadas
      final notasProgramadas = await _notaSapService.getNotasProgramadas();
      final ordensProgramadas = await _ordemService.getOrdensProgramadas();

      final setNotasProgramadasIds = notasProgramadas.map((item) {
        final nota = item['nota'] as NotaSAP?;
        return nota?.id;
      }).whereType<String>().toSet();

      final setOrdensProgramadasIds = ordensProgramadas.map((item) {
        final ordem = item['ordem'] as Ordem?;
        return ordem?.id;
      }).whereType<String>().toSet();

      // Mapear notaId -> tarefa e ordemId -> tarefa
      final Map<String, Map<String, dynamic>> mapaTarefasNotas = {};
      final Map<String, Map<String, dynamic>> mapaTarefasOrdens = {};

      for (final item in notasProgramadas) {
        final nota = item['nota'] as NotaSAP?;
        final tarefa = item['tarefa'] as Map<String, dynamic>?;
        if (nota != null && tarefa != null) {
          mapaTarefasNotas[nota.id] = tarefa;
        }
      }

      for (final item in ordensProgramadas) {
        final ordem = item['ordem'] as Ordem?;
        final tarefa = item['tarefa'] as Map<String, dynamic>?;
        if (ordem != null && tarefa != null) {
          mapaTarefasOrdens[ordem.id] = tarefa;
        }
      }

      // Estrutura temporária para agrupar as demandas
      // Chave: LOCAL_INSTALACAO|SALA
      final Map<String, List<NotaSAP>> notasAgrupadas = {};
      final Map<String, List<Ordem>> ordensAgrupadas = {};
      final Map<String, Map<String, String>> infoAtivos = {}; // Para guardar o local amigável/sala/localInstalacao original

      String obterChaveCluster(String? localInstalacao, String? sala) {
        final locInst = (localInstalacao != null && localInstalacao.isNotEmpty) 
            ? localInstalacao.trim().toUpperCase() 
            : 'SEM LOCAL INSTALACAO';
        final sal = (sala != null && sala.isNotEmpty) ? sala.trim().toUpperCase() : 'SEM SALA';
        return '$locInst|$sal';
      }

      String extrairNomeLocal(String? localFriendly, String? localInstalacao) {
        if (localFriendly != null && localFriendly.isNotEmpty) {
          return localFriendly;
        }
        if (localInstalacao == null || localInstalacao.isEmpty) {
          return 'SEM LOCAL';
        }
        final partes = localInstalacao.split('-');
        if (partes.length > 2) {
          return partes[2]; // Retorna ex: "SRIDSETD", "SPRI", "SFZD"
        }
        return localInstalacao;
      }

      // Agrupar Notas
      for (final nota in notasAbertas) {
        // Se solicitado apenas não programados, filtrar
        if (apenasNaoProgramados && setNotasProgramadasIds.contains(nota.id)) {
          continue;
        }

        final chave = obterChaveCluster(nota.localInstalacao, nota.sala);
        if (!notasAgrupadas.containsKey(chave)) {
          notasAgrupadas[chave] = [];
        }
        notasAgrupadas[chave]!.add(nota);

        final localAmigavel = extrairNomeLocal(nota.local, nota.localInstalacao);
        if (!infoAtivos.containsKey(chave) || (infoAtivos[chave]?['local'] == infoAtivos[chave]?['localInstalacao'] && nota.local != null && nota.local!.isNotEmpty)) {
          infoAtivos[chave] = {
            'local': localAmigavel,
            'localInstalacao': nota.localInstalacao ?? '',
            'sala': (nota.sala != null && nota.sala!.isNotEmpty) ? nota.sala! : 'Sem Sala',
          };
        }
      }

      // Agrupar Ordens
      for (final ordem in ordensAbertas) {
        // Se solicitado apenas não programados, filtrar
        if (apenasNaoProgramados && setOrdensProgramadasIds.contains(ordem.id)) {
          continue;
        }

        final chave = obterChaveCluster(ordem.localInstalacao, ordem.sala);
        if (!ordensAgrupadas.containsKey(chave)) {
          ordensAgrupadas[chave] = [];
        }
        ordensAgrupadas[chave]!.add(ordem);

        final localAmigavel = extrairNomeLocal(ordem.local, ordem.localInstalacao);
        if (!infoAtivos.containsKey(chave) || (infoAtivos[chave]?['local'] == infoAtivos[chave]?['localInstalacao'] && ordem.local != null && ordem.local!.isNotEmpty)) {
          infoAtivos[chave] = {
            'local': localAmigavel,
            'localInstalacao': ordem.localInstalacao ?? '',
            'sala': (ordem.sala != null && ordem.sala!.isNotEmpty) ? ordem.sala! : 'Sem Sala',
          };
        }
      }

      // Reunir todas as chaves únicas
      final todasChaves = {...notasAgrupadas.keys, ...ordensAgrupadas.keys};
      final List<AtivoCluster> clusters = [];

      for (final chave in todasChaves) {
        final notasCluster = notasAgrupadas[chave] ?? [];
        final ordensCluster = ordensAgrupadas[chave] ?? [];
        final info = infoAtivos[chave]!;

        // Calcular prazo crítico (menor vencimento/tolerância)
        DateTime? prazoCritico;
        for (final nota in notasCluster) {
          if (nota.dataVencimento != null) {
            if (prazoCritico == null || nota.dataVencimento!.isBefore(prazoCritico)) {
              prazoCritico = nota.dataVencimento;
            }
          }
        }
        for (final ordem in ordensCluster) {
          final dataRef = ordem.tolerancia ?? ordem.fimBase;
          if (dataRef != null) {
            if (prazoCritico == null || dataRef.isBefore(prazoCritico)) {
              prazoCritico = dataRef;
            }
          }
        }

        // Calcular dias restantes
        int? diasRestantes;
        if (prazoCritico != null) {
          final hoje = DateTime.now();
          final dataF = DateTime(prazoCritico.year, prazoCritico.month, prazoCritico.day);
          final hojeF = DateTime(hoje.year, hoje.month, hoje.day);
          diasRestantes = dataF.difference(hojeF).inDays;
        }

        // Calcular prioridade crítica
        String prioridadeCritica = 'MONITORAMENTO';
        for (final nota in notasCluster) {
          final prio = (nota.textPrioridade ?? '').toUpperCase();
          if (prio.contains('ALTA') || prio.contains('EMERGÊNCIA')) {
            prioridadeCritica = 'ALTA';
            break;
          } else if (prio.contains('MÉDIA') || prio.contains('MEDIA') || prio.contains('URGENTE')) {
            if (prioridadeCritica != 'ALTA') {
              prioridadeCritica = 'MÉDIA';
            }
          } else if (prio.contains('BAIXA')) {
            if (prioridadeCritica != 'ALTA' && prioridadeCritica != 'MÉDIA') {
              prioridadeCritica = 'BAIXA';
            }
          }
        }

        // Verificar se tudo já está programado no cluster
        bool estaProgramado = true;
        for (final nota in notasCluster) {
          if (!setNotasProgramadasIds.contains(nota.id)) {
            estaProgramado = false;
            break;
          }
        }
        if (estaProgramado) {
          for (final ordem in ordensCluster) {
            if (!setOrdensProgramadasIds.contains(ordem.id)) {
              estaProgramado = false;
              break;
            }
          }
        }

        // Extrair tarefas correspondentes ao cluster
        final Map<String, Map<String, dynamic>> clusterTarefasNotas = {};
        for (final n in notasCluster) {
          if (mapaTarefasNotas.containsKey(n.id)) {
            clusterTarefasNotas[n.id] = mapaTarefasNotas[n.id]!;
          }
        }

        final Map<String, Map<String, dynamic>> clusterTarefasOrdens = {};
        for (final o in ordensCluster) {
          if (mapaTarefasOrdens.containsKey(o.id)) {
            clusterTarefasOrdens[o.id] = mapaTarefasOrdens[o.id]!;
          }
        }

        clusters.add(AtivoCluster(
          localKey: chave,
          local: info['local']!,
          sala: info['sala']!,
          notas: notasCluster,
          ordens: ordensCluster,
          prazoCritico: prazoCritico,
          diasRestantes: diasRestantes,
          prioridadeCritica: prioridadeCritica,
          estaProgramado: estaProgramado,
          tarefasNotas: clusterTarefasNotas,
          tarefasOrdens: clusterTarefasOrdens,
        ));
      }

      // Ordenar clusters pelo prazo crítico (mais críticos primeiro, nulos por último)
      clusters.sort((a, b) {
        if (a.prazoCritico == null && b.prazoCritico == null) return 0;
        if (a.prazoCritico == null) return 1;
        if (b.prazoCritico == null) return -1;
        return a.prazoCritico!.compareTo(b.prazoCritico!);
      });

      return clusters;
    } catch (e) {
      debugPrint('❌ Erro no ClusterService.getClustersAtivos: $e');
      return [];
    }
  }
}
