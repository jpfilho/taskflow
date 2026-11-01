import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/nota_sap.dart';
import '../models/nota_sap_grupo.dart';
import '../models/nota_sap_similaridade.dart';

/// Serviço dedicado para gestão de Grupos de Notas SAP, Vínculos e Previsão Macro.
///
/// Responsabilidades:
/// 1. Criação, edição, encerramento e cancelamento de grupos.
/// 2. Gestão de vínculos (Adicionar / Remover Notas do Grupo).
/// 3. Garantia de regra de negócio: Uma Nota só participa de 1 grupo ATIVO por vez.
/// 4. Gestão e histórico de previsões macro (Mês/Ano).
/// 5. Derivação dinâmica do status de programação consultando `tasks_notas_sap`.
class NotaSapGrupoService {
  final SupabaseClient? _supabaseClient;

  SupabaseClient get _supabase => _supabaseClient ?? SupabaseConfig.client;

  NotaSapGrupoService({SupabaseClient? supabaseClient})
      : _supabaseClient = supabaseClient;

  // ===========================================================================
  // 1. GESTÃO DO GRUPO (CRUD BÁSICO)
  // ===========================================================================

  /// Cria um novo grupo de Notas SAP.
  Future<NotaSapGrupo> criarGrupo({
    required String nome,
    String? descricao,
    String? motivo,
    String? localInstalacao,
    String? equipamento,
    String? centroTrabalhoResponsavel,
    int? mesProgramacaoPrevisto,
    int? anoProgramacaoPrevisto,
    String? motivoPrevisao,
    String? usuarioId,
    String? usuarioNome,
  }) async {
    try {
      // Validação de paridade
      if ((mesProgramacaoPrevisto != null && anoProgramacaoPrevisto == null) ||
          (mesProgramacaoPrevisto == null && anoProgramacaoPrevisto != null)) {
        throw ArgumentError('Mês e Ano de previsão devem ser ambos preenchidos ou ambos nulos.');
      }

      if (mesProgramacaoPrevisto != null && (mesProgramacaoPrevisto < 1 || mesProgramacaoPrevisto > 12)) {
        throw ArgumentError('Mês previsto deve estar entre 1 e 12.');
      }

      final payload = <String, dynamic>{
        'nome': nome.trim(),
        'descricao': descricao?.trim(),
        'motivo': motivo?.trim(),
        'local_instalacao': localInstalacao?.trim(),
        'equipamento': equipamento?.trim(),
        'centro_trabalho_responsavel': centroTrabalhoResponsavel?.trim(),
        'mes_programacao_previsto': mesProgramacaoPrevisto,
        'ano_programacao_previsto': anoProgramacaoPrevisto,
        'motivo_previsao': motivoPrevisao?.trim(),
        'status_grupo': 'ativo',
        'created_by': usuarioId,
        'previsao_alterada_por': usuarioId,
        'previsao_alterada_por_nome': usuarioNome,
        'previsao_alterada_em': (mesProgramacaoPrevisto != null) ? DateTime.now().toIso8601String() : null,
      };

      final response = await _supabase
          .from('notas_sap_grupos')
          .insert(payload)
          .select()
          .single();

      return NotaSapGrupo.fromMap(response);
    } catch (e) {
      debugPrint('❌ [NotaSapGrupoService.criarGrupo] Erro: $e');
      rethrow;
    }
  }

  /// Edita dados informativos do grupo.
  Future<NotaSapGrupo> editarGrupo(NotaSapGrupo grupo) async {
    try {
      final payload = grupo.toMap();
      payload.remove('created_at');
      payload.remove('updated_at');

      final response = await _supabase
          .from('notas_sap_grupos')
          .update(payload)
          .eq('id', grupo.id)
          .select()
          .single();

      return NotaSapGrupo.fromMap(response);
    } catch (e) {
      debugPrint('❌ [NotaSapGrupoService.editarGrupo] Erro: $e');
      rethrow;
    }
  }

  /// Encerra um grupo administrativamente.
  Future<void> encerrarGrupo(String grupoId) async {
    try {
      await _supabase
          .from('notas_sap_grupos')
          .update({'status_grupo': 'encerrado'})
          .eq('id', grupoId);
    } catch (e) {
      debugPrint('❌ [NotaSapGrupoService.encerrarGrupo] Erro: $e');
      rethrow;
    }
  }

  /// Cancela um grupo administrativamente.
  Future<void> cancelarGrupo(String grupoId) async {
    try {
      await _supabase
          .from('notas_sap_grupos')
          .update({'status_grupo': 'cancelado'})
          .eq('id', grupoId);
    } catch (e) {
      debugPrint('❌ [NotaSapGrupoService.cancelarGrupo] Erro: $e');
      rethrow;
    }
  }

  /// Busca um grupo pelo ID.
  Future<NotaSapGrupo?> buscarGrupoPorId(String grupoId) async {
    try {
      final response = await _supabase
          .from('notas_sap_grupos')
          .select()
          .eq('id', grupoId)
          .maybeSingle();

      if (response == null) return null;
      final itens = await buscarNotasDoGrupo(grupoId);
      return NotaSapGrupo.fromMap(response, itens: itens);
    } catch (e) {
      debugPrint('❌ [NotaSapGrupoService.buscarGrupoPorId] Erro: $e');
      rethrow;
    }
  }

  /// Lista grupos ativos para pesquisa ou vinculação.
  Future<List<NotaSapGrupo>> listarGruposAtivos({int limit = 50}) async {
    try {
      final response = await _supabase
          .from('notas_sap_grupos')
          .select()
          .eq('status_grupo', 'ativo')
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List).map((m) => NotaSapGrupo.fromMap(m)).toList();
    } catch (e) {
      debugPrint('❌ [NotaSapGrupoService.listarGruposAtivos] Erro: $e');
      return [];
    }
  }

  // ===========================================================================
  // 2. VÍNCULOS: ADICIONAR E REMOVER NOTAS DO GRUPO
  // ===========================================================================

  /// Adiciona uma Nota SAP ao grupo.
  ///
  /// Valida a regra de negócio fundamental: Uma Nota só pode participar de 1 grupo ATIVO por vez.
  Future<NotaSapGrupoItem> adicionarNotaAoGrupo({
    required String grupoId,
    required String notaSapId,
    String? motivoVinculo,
    String? usuarioId,
    String? usuarioNome,
  }) async {
    try {
      // 1. Validação prévia de grupo ativo único
      final outroGrupoAtivo = await buscarGrupoAtivoDaNota(notaSapId);
      if (outroGrupoAtivo != null && outroGrupoAtivo.id != grupoId) {
        throw StateError(
          'A Nota SAP já pertence ao grupo ativo "${outroGrupoAtivo.nome}". Remova-a do grupo atual antes de vinculá-la a outro.',
        );
      }

      final payload = <String, dynamic>{
        'grupo_id': grupoId,
        'nota_sap_id': notaSapId,
        'motivo_vinculo': motivoVinculo?.trim(),
        'adicionado_por': usuarioId,
        'adicionado_por_nome': usuarioNome,
      };

      final response = await _supabase
          .from('notas_sap_grupos_itens')
          .insert(payload)
          .select()
          .single();

      return NotaSapGrupoItem.fromMap(response);
    } catch (e) {
      debugPrint('❌ [NotaSapGrupoService.adicionarNotaAoGrupo] Erro: $e');
      rethrow;
    }
  }

  /// Remove uma Nota SAP do grupo.
  Future<void> removerNotaDoGrupo({
    required String grupoId,
    required String notaSapId,
  }) async {
    try {
      await _supabase
          .from('notas_sap_grupos_itens')
          .delete()
          .eq('grupo_id', grupoId)
          .eq('nota_sap_id', notaSapId);
    } catch (e) {
      debugPrint('❌ [NotaSapGrupoService.removerNotaDoGrupo] Erro: $e');
      rethrow;
    }
  }

  /// Busca o grupo ATIVO ao qual uma Nota pertence (se houver).
  Future<NotaSapGrupo?> buscarGrupoAtivoDaNota(String notaSapId) async {
    try {
      final res = await _supabase
          .from('notas_sap_grupos_itens')
          .select('grupo_id, notas_sap_grupos(*)')
          .eq('nota_sap_id', notaSapId);

      for (final item in (res as List)) {
        final gMap = item['notas_sap_grupos'] as Map<String, dynamic>?;
        if (gMap != null) {
          final grupo = NotaSapGrupo.fromMap(gMap);
          if (grupo.statusGrupo == StatusGrupo.ativo) {
            return grupo;
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ [NotaSapGrupoService.buscarGrupoAtivoDaNota] Erro: $e');
      return null;
    }
  }

  /// Lista todos os itens do grupo, resolvendo os dados da Nota SAP e as tarefas vinculadas.
  Future<List<NotaSapGrupoItem>> buscarNotasDoGrupo(String grupoId) async {
    try {
      final resItens = await _supabase
          .from('notas_sap_grupos_itens')
          .select('*, notas_sap(*)')
          .eq('grupo_id', grupoId)
          .order('adicionado_em', ascending: true);

      final notaIds = <String>[];
      final itensBrutos = <Map<String, dynamic>>[];

      for (final item in (resItens as List)) {
        final m = item as Map<String, dynamic>;
        itensBrutos.add(m);
        final nId = m['nota_sap_id']?.toString();
        if (nId != null) notaIds.add(nId);
      }

      // Buscar tarefas vinculadas em tasks_notas_sap (relação oficial)
      final tarefasMap = await _carregarTarefasVinculadas(notaIds);

      final resultado = <NotaSapGrupoItem>[];
      for (final m in itensBrutos) {
        final notaMap = m['notas_sap'] as Map<String, dynamic>?;
        final notaObj = notaMap != null ? NotaSAP.fromMap(notaMap) : null;
        final nId = m['nota_sap_id']?.toString() ?? '';
        final tarefas = tarefasMap[nId] ?? const [];

        resultado.add(
          NotaSapGrupoItem.fromMap(
            m,
            nota: notaObj,
            tarefas: tarefas,
          ),
        );
      }

      return resultado;
    } catch (e) {
      debugPrint('❌ [NotaSapGrupoService.buscarNotasDoGrupo] Erro: $e');
      return [];
    }
  }

  // ===========================================================================
  // 3. PREVISÃO MACRO E HISTÓRICO
  // ===========================================================================

  /// Altera ou remove a previsão de programação do grupo.
  ///
  /// Se `mes` e `ano` forem nulos, a previsão é removida.
  Future<NotaSapGrupo> alterarPrevisao({
    required String grupoId,
    int? mes,
    int? ano,
    String? motivo,
    String? usuarioId,
    String? usuarioNome,
  }) async {
    try {
      // Validação de paridade
      if ((mes != null && ano == null) || (mes == null && ano != null)) {
        throw ArgumentError('Mês e Ano devem ser ambos preenchidos ou ambos nulos.');
      }

      if (mes != null && (mes < 1 || mes > 12)) {
        throw ArgumentError('Mês deve estar entre 1 e 12.');
      }

      final payload = <String, dynamic>{
        'mes_programacao_previsto': mes,
        'ano_programacao_previsto': ano,
        'motivo_previsao': motivo?.trim(),
        'previsao_alterada_por': usuarioId,
        'previsao_alterada_por_nome': usuarioNome,
        'previsao_alterada_em': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('notas_sap_grupos')
          .update(payload)
          .eq('id', grupoId)
          .select()
          .single();

      return NotaSapGrupo.fromMap(response);
    } catch (e) {
      debugPrint('❌ [NotaSapGrupoService.alterarPrevisao] Erro: $e');
      rethrow;
    }
  }

  /// Retorna o histórico de alterações de previsão de um grupo.
  Future<List<NotaSapGrupoPrevisaoHist>> buscarHistoricoPrevisao(String grupoId) async {
    try {
      final response = await _supabase
          .from('notas_sap_grupos_previsoes_hist')
          .select()
          .eq('grupo_id', grupoId)
          .order('alterado_em', ascending: false);

      return (response as List)
          .map((m) => NotaSapGrupoPrevisaoHist.fromMap(m as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ [NotaSapGrupoService.buscarHistoricoPrevisao] Erro: $e');
      return [];
    }
  }

  // ===========================================================================
  // 4. STATUS DERIVADO DE PROGRAMAÇÃO
  // ===========================================================================

  /// Calcula dinamicamente a situação de programação de um grupo.
  Future<GrupoStatusProgramacao> buscarStatusProgramacaoGrupo(String grupoId) async {
    final itens = await buscarNotasDoGrupo(grupoId);
    return GrupoStatusProgramacao.calcular(itens);
  }

  // ===========================================================================
  // 5. HELPER INTERNO: CARREGAR TAREFAS VINCULADAS (tasks_notas_sap)
  // ===========================================================================

  Future<Map<String, List<TarefaHistoricaResumo>>> _carregarTarefasVinculadas(
      List<String> notaIds) async {
    final mapa = <String, List<TarefaHistoricaResumo>>{};
    if (notaIds.isEmpty) return mapa;

    try {
      final res = await _supabase
          .from('tasks_notas_sap')
          .select('nota_sap_id, task_id, tasks(id, tarefa, status, horas_executadas, horas_previstas, executores, data_inicio, data_fim)')
          .inFilter('nota_sap_id', notaIds);

      for (final item in (res as List)) {
        final notaId = item['nota_sap_id']?.toString();
        final taskData = item['tasks'] as Map<String, dynamic>?;
        if (notaId != null && taskData != null) {
          final executoresList = <String>[];
          final rawExec = taskData['executores'];
          if (rawExec is List) {
            executoresList.addAll(rawExec.map((e) => e.toString()));
          }

          final resumo = TarefaHistoricaResumo(
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
          );
          mapa.putIfAbsent(notaId, () => []).add(resumo);
        }
      }
    } catch (_) {}
    return mapa;
  }
}
