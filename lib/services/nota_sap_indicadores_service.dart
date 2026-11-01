import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/nota_sap.dart';
import '../models/nota_sap_analise.dart';
import '../models/nota_sap_indicadores.dart';
import 'nota_sap_analise_service.dart';

/// Serviço de Indicadores, Métricas e Visibilidade Gerencial da Análise de Notas SAP
/// Exclusivamente informativo (Medir != Obrigar).
/// Totalmente desacoplado de criação de tarefas e da rotina operacional de campo.
class NotaSapIndicadoresService {
  static final NotaSapIndicadoresService _instance =
      NotaSapIndicadoresService._internal();
  factory NotaSapIndicadoresService() => _instance;
  NotaSapIndicadoresService._internal();

  SupabaseClient get _supabase => SupabaseConfig.client;
  final NotaSapAnaliseService _analiseService = NotaSapAnaliseService();

  // Cache em memória para os indicadores consolidados
  NotaSapIndicadores? _indicadoresCache;
  DateTime? _ultimoCacheFetch;
  static const Duration _cacheTtl = Duration(minutes: 5);

  /// Calcula indicadores diretamente em memória a partir dos dados já carregados na tela
  /// Extremamente rápido e sem custo de rede adicional
  NotaSapIndicadores calcularIndicadoresLocais({
    required List<NotaSAP> notas,
    Map<String, NotaSapResumoAnalise> resumos = const {},
    Map<String, NotaSapAnalise> analisesDetalhadas = const {},
    List<VinculoTaskNotaSap> vinculosTarefas = const [],
    Set<String> notasProgramadasIds = const {},
  }) {
    return NotaSapIndicadores.calcular(
      notas: notas,
      resumos: resumos,
      analisesDetalhadas: analisesDetalhadas,
      vinculosTarefas: vinculosTarefas,
      notasProgramadasIds: notasProgramadasIds,
    );
  }

  /// Busca e agrega indicadores no Supabase respeitando filtros de período, regional e centro de trabalho
  /// Não executa queries destrutivas nem cria views sem autorização.
  Future<NotaSapIndicadores> buscarIndicadoresConsolidados({
    DateTime? dataInicio,
    DateTime? dataFim,
    String? centroTrabalho,
    String? regional,
    String? divisao,
    bool forceRefresh = false,
  }) async {
    try {
      // 1. Verificar cache se forceRefresh for false
      if (!forceRefresh &&
          _indicadoresCache != null &&
          _ultimoCacheFetch != null &&
          DateTime.now().difference(_ultimoCacheFetch!) < _cacheTtl) {
        return _indicadoresCache!;
      }

      // 2. Consulta resiliente das notas SAP do período
      dynamic queryNotas = _supabase.from('notas_sap').select('''
        id,
        tipo,
        criado_em,
        text_prioridade,
        nota,
        ordem,
        descricao,
        local_instalacao,
        local,
        sala,
        status_sistema,
        status_usuario,
        centro_trabalho_responsavel,
        centro
      ''');

      if (dataInicio != null) {
        queryNotas = queryNotas.gte('criado_em', dataInicio.toIso8601String());
      }
      if (dataFim != null) {
        queryNotas = queryNotas.lte('criado_em', dataFim.toIso8601String());
      }
      if (centroTrabalho != null && centroTrabalho.trim().isNotEmpty) {
        queryNotas = queryNotas.eq('centro_trabalho_responsavel', centroTrabalho);
      }
      if (regional != null && regional.trim().isNotEmpty) {
        queryNotas = queryNotas.eq('centro', regional);
      }

      final List<dynamic> notasRaw = await queryNotas;
      final List<NotaSAP> notas = notasRaw
          .map((e) => NotaSAP.fromMap(e as Map<String, dynamic>))
          .toList();

      if (notas.isEmpty) {
        final vazio = NotaSapIndicadores.vazio();
        _indicadoresCache = vazio;
        _ultimoCacheFetch = DateTime.now();
        return vazio;
      }

      final idsNotas = notas.map((n) => n.id).toList();

      // 3. Buscar resumos de análise (em chunks seguros de 100)
      final resumos = await _analiseService.buscarResumoAnalises(
        idsNotas,
        forceRefresh: forceRefresh,
      );

      // 4. Buscar análises completas para as notas que têm análise
      final idsComAnalise = idsNotas
          .where((id) => resumos[id]?.status != NotaAnaliseStatus.naoIniciada)
          .toList();

      final analisesDetalhadas = idsComAnalise.isNotEmpty
          ? await _analiseService.buscarAnalises(idsComAnalise)
          : <String, NotaSapAnalise>{};

      // 5. Buscar vínculos com tarefas para verificar uso na programação (N:M e temporal)
      final List<VinculoTaskNotaSap> vinculos = [];
      final Set<String> notasProgIds = {};

      try {
        final List<dynamic> vinculosRaw = await _supabase
            .from('tasks_notas_sap')
            .select('task_id, nota_sap_id, created_at, tasks(id, created_at)')
            .filter('nota_sap_id', 'in', idsNotas);

        for (final item in vinculosRaw) {
          final taskId = item['task_id']?.toString() ?? '';
          final notaId = item['nota_sap_id']?.toString() ?? '';
          final vinculoCreated = item['created_at'] != null
              ? DateTime.tryParse(item['created_at'].toString())
              : null;

          final taskObj = item['tasks'];
          final taskCreated = (taskObj != null && taskObj['created_at'] != null)
              ? DateTime.tryParse(taskObj['created_at'].toString())
              : null;

          if (taskId.isNotEmpty && notaId.isNotEmpty) {
            vinculos.add(VinculoTaskNotaSap(
              taskId: taskId,
              notaSapId: notaId,
              taskCreatedAt: taskCreated,
              vinculoCreatedAt: vinculoCreated,
            ));
            notasProgIds.add(notaId);
          }
        }
      } catch (eVinculos) {
        debugPrint('⚠️ [NotaSapIndicadoresService] Aviso ao carregar vínculos com tarefas: $eVinculos');
      }

      // 6. Calcular indicadores agregados
      final resultado = NotaSapIndicadores.calcular(
        notas: notas,
        resumos: resumos,
        analisesDetalhadas: analisesDetalhadas,
        vinculosTarefas: vinculos,
        notasProgramadasIds: notasProgIds,
      );

      _indicadoresCache = resultado;
      _ultimoCacheFetch = DateTime.now();
      return resultado;
    } catch (e) {
      debugPrint('❌ [NotaSapIndicadoresService] Erro ao buscar indicadores consolidados: $e');
      // Retorna vazio resiliente em caso de falha de conexão
      return _indicadoresCache ?? NotaSapIndicadores.vazio();
    }
  }

  // ============================================================================
  // TELEMETRIA FUNCIONAL LEVE (PROPOSTA SEÇÃO 10 a 14)
  // ============================================================================

  /// Registra um evento de telemetria de uso técnico de forma assíncrona e silenciosa
  /// Não bloqueia nenhuma ação operacional do usuário.
  Future<void> registrarEventoTelemetria({
    required String evento, // 'escopo_usado_na_tarefa', 'diagnostico_usado_na_tarefa', 'horas_usadas_na_tarefa', etc.
    required String notaSapId,
    String? taskId,
    String? usuarioId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final userId = usuarioId ?? _supabase.auth.currentUser?.id;
      await _supabase.from('notas_sap_analise_eventos').insert({
        'evento': evento,
        'nota_sap_id': notaSapId,
        'task_id': taskId,
        'usuario_id': userId,
        'created_at': DateTime.now().toIso8601String(),
        if (metadata != null) 'metadata': metadata,
      });
    } catch (_) {
      // Ignora falhas de telemetria se a tabela ainda não tiver sido criada em produção
    }
  }

  /// Invalida o cache local de indicadores
  void invalidarCache() {
    _indicadoresCache = null;
    _ultimoCacheFetch = null;
  }
}
