import 'dart:async';
import '../models/equipe.dart';
import '../models/divisao.dart';
import '../config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'divisao_service.dart';
import 'performance_monitor.dart';

class EquipeService {
  static final EquipeService _instance = EquipeService._internal();
  factory EquipeService() => _instance;
  EquipeService._internal();

  final SupabaseClient _supabase = SupabaseConfig.client;

  // Converter Map do Supabase para Equipe
  Equipe _equipeFromMap(Map<String, dynamic> map) {
    return Equipe.fromMap(map);
  }

  // Converter Equipe para Map (para Supabase)
  Map<String, dynamic> _equipeToMap(Equipe equipe) {
    return {
      'nome': equipe.nome,
      'descricao': equipe.descricao,
      'tipo': equipe.tipo,
      'regional_id': equipe.regionalId,
      'divisao_id': equipe.divisaoId,
      'segmento_id': equipe.segmentoId,
      'ativo': equipe.ativo,
    };
  }

  // Buscar todas as equipes
  Future<List<Equipe>> getAllEquipes() async {
    PerformanceMonitor.start('EquipeService.getAllEquipes');
    try {
      final response = await _supabase
          .from('equipes')
          .select('''
            *,
            regionais!left(regional),
            divisoes!left(divisao),
            segmentos!left(segmento),
            equipes_executores!left(executor_id, papel, executores!inner(id, nome))
          ''')
          .order('nome', ascending: true)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => <Map<String, dynamic>>[],
          );

      if (response.isEmpty) return [];

      final equipesList = response as List;
      final result = equipesList
          .map((map) => _equipeFromMap(map as Map<String, dynamic>))
          .toList();
      PerformanceMonitor.stop('EquipeService.getAllEquipes');
      return result;
    } catch (e) {
      PerformanceMonitor.stop('EquipeService.getAllEquipes');
      print('Erro ao buscar equipes: $e');
      return [];
    }
  }

  // Buscar equipes ativas
  Future<List<Equipe>> getEquipesAtivas() async {
    try {
      final response = await _supabase
          .from('equipes')
          .select('''
            *,
            regionais!left(regional),
            divisoes!left(divisao),
            segmentos!left(segmento),
            equipes_executores!left(executor_id, papel, executores!inner(id, nome))
          ''')
          .eq('ativo', true)
          .order('nome', ascending: true)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => <Map<String, dynamic>>[],
          );

      if (response.isEmpty) return [];

      final equipesList = response as List;
      return equipesList
          .map((map) => _equipeFromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Erro ao buscar equipes ativas: $e');
      return [];
    }
  }

  // Buscar equipe por ID
  Future<Equipe?> getEquipeById(String id) async {
    try {
      final response = await _supabase
          .from('equipes')
          .select('''
            *,
            regionais!left(regional),
            divisoes!left(divisao),
            segmentos!left(segmento),
            equipes_executores!left(executor_id, papel, executores!inner(id, nome))
          ''')
          .eq('id', id)
          .single()
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('Timeout ao buscar equipe'),
          );

      return _equipeFromMap(response);
    } catch (e) {
      print('Erro ao buscar equipe por ID: $e');
      return null;
    }
  }

  // Criar nova equipe
  Future<Equipe?> createEquipe(Equipe equipe) async {
    try {
      final data = _equipeToMap(equipe);

      // Inserir equipe
      final response = await _supabase
          .from('equipes')
          .insert(data)
          .select('id')
          .single()
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('Timeout ao criar equipe'),
          );

      final equipeId = response['id'] as String;

      // Inserir relacionamentos com executores
      if (equipe.executores.isNotEmpty) {
        final executoresData = equipe.executores
            .map(
              (equipeExecutor) => {
                'equipe_id': equipeId,
                'executor_id': equipeExecutor.executorId,
                'papel': equipeExecutor.papel,
              },
            )
            .toList();

        await _supabase.from('equipes_executores').insert(executoresData);
      }

      // Buscar equipe completa com joins
      final equipeCompleta = await getEquipeById(equipeId);
      if (equipeCompleta != null) {
        return equipeCompleta;
      }

      throw Exception('Erro ao buscar equipe criada');
    } catch (e) {
      print('Erro ao criar equipe: $e');
      return null;
    }
  }

  // Atualizar equipe
  Future<Equipe?> updateEquipe(String id, Equipe equipe) async {
    try {
      final data = _equipeToMap(equipe);

      // Atualizar dados da equipe
      await _supabase
          .from('equipes')
          .update(data)
          .eq('id', id)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () =>
                throw TimeoutException('Timeout ao atualizar equipe'),
          );

      // Remover relacionamentos antigos com executores
      await _supabase.from('equipes_executores').delete().eq('equipe_id', id);

      // Inserir novos relacionamentos com executores
      if (equipe.executores.isNotEmpty) {
        final executoresData = equipe.executores
            .map(
              (equipeExecutor) => {
                'equipe_id': id,
                'executor_id': equipeExecutor.executorId,
                'papel': equipeExecutor.papel,
              },
            )
            .toList();

        await _supabase.from('equipes_executores').insert(executoresData);
      }

      // Buscar equipe completa com joins
      final equipeCompleta = await getEquipeById(id);
      if (equipeCompleta != null) {
        return equipeCompleta;
      }

      throw Exception('Erro ao buscar equipe atualizada');
    } catch (e) {
      print('Erro ao atualizar equipe: $e');
      return null;
    }
  }

  // Deletar equipe
  Future<bool> deleteEquipe(String id) async {
    try {
      await _supabase
          .from('equipes')
          .delete()
          .eq('id', id)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () =>
                throw TimeoutException('Timeout ao deletar equipe'),
          );

      return true;
    } catch (e) {
      print('Erro ao deletar equipe: $e');
      return false;
    }
  }

  // Filtrar equipes
  Future<List<Equipe>> filterEquipes({String? tipo, bool? ativo}) async {
    try {
      dynamic query = _supabase.from('equipes').select('''
        *,
        regionais!left(regional),
        divisoes!left(divisao),
        segmentos!left(segmento),
        equipes_executores!left(executor_id, papel, executores!inner(id, nome))
      ''');

      if (tipo != null && tipo.isNotEmpty) {
        query = query.eq('tipo', tipo);
      }

      if (ativo != null) {
        query = query.eq('ativo', ativo);
      }

      final response = await query
          .order('nome', ascending: true)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => <Map<String, dynamic>>[],
          );

      if (response.isEmpty) return [];

      final equipesList = response as List;
      return equipesList
          .map((map) => _equipeFromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Erro ao filtrar equipes: $e');
      return [];
    }
  }

  // Buscar equipes por texto
  Future<List<Equipe>> searchEquipes(String query) async {
    PerformanceMonitor.start('EquipeService.searchEquipes');
    if (query.isEmpty) return await getAllEquipes();

    try {
      final response = await _supabase
          .from('equipes')
          .select('''
            *,
            regionais!left(regional),
            divisoes!left(divisao),
            segmentos!left(segmento),
            equipes_executores!left(executor_id, papel, executores!inner(id, nome))
          ''')
          .or('nome.ilike.%$query%,descricao.ilike.%$query%')
          .order('nome', ascending: true)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => <Map<String, dynamic>>[],
          );

      if (response.isEmpty) return [];

      final equipesList = response as List;
      final result = equipesList
          .map((map) => _equipeFromMap(map as Map<String, dynamic>))
          .toList();
      PerformanceMonitor.stop('EquipeService.searchEquipes');
      return result;
    } catch (e) {
      PerformanceMonitor.stop('EquipeService.searchEquipes');
      print('Erro ao buscar equipes: $e');
      return [];
    }
  }

  // Buscar equipes filtradas por regional, divisão e segmento
  Future<List<Equipe>> getEquipesFiltradas({
    String? regionalId,
    String? divisaoId,
    String? segmentoId,
    bool includeInativas = false,
  }) async {
    try {
      final todas = includeInativas ? await getAllEquipes() : await getEquipesAtivas();
      if ((regionalId == null || regionalId.isEmpty) &&
          (divisaoId == null || divisaoId.isEmpty) &&
          (segmentoId == null || segmentoId.isEmpty)) {
        return todas;
      }

      final divisoes = await DivisaoService().getAllDivisoes();
      final Map<String, Divisao> divisaoMap = {for (var d in divisoes) d.id: d};
      final Set<String> divisaoIdsDaRegional = {};
      if (regionalId != null && regionalId.isNotEmpty) {
        divisaoIdsDaRegional.addAll(
          divisoes.where((d) => d.atuaNaRegional(regionalId)).map((d) => d.id),
        );
      }

      return todas.where((eq) {
        if (regionalId != null && regionalId.isNotEmpty) {
          final matchesReg = eq.regionalId == regionalId;
          final matchesDivReg = eq.divisaoId != null && (divisaoIdsDaRegional.contains(eq.divisaoId) || (divisaoMap[eq.divisaoId]?.atuaNaRegional(regionalId) ?? false));
          if (!matchesReg && !matchesDivReg) return false;
        }

        if (divisaoId != null && divisaoId.isNotEmpty) {
          if (eq.divisaoId != divisaoId) return false;
        }

        if (segmentoId != null && segmentoId.isNotEmpty) {
          if (eq.segmentoId != segmentoId) return false;
        }

        return true;
      }).toList();
    } catch (e) {
      print('Erro ao buscar equipes filtradas: $e');
      return [];
    }
  }

  // Buscar equipes por escopo do formulário e perfil do usuário
  Future<List<Equipe>> getEquipesPorPerfilUsuario({
    required List<String> regionalIds,
    required List<String> divisaoIds,
    required List<String> segmentoIds,
    String? formRegionalId,
    String? formDivisaoId,
    String? formSegmentoId,
    bool includeInativas = false,
  }) async {
    try {
      final todas = includeInativas ? await getAllEquipes() : await getEquipesAtivas();
      final divisoes = await DivisaoService().getAllDivisoes();
      final Map<String, Divisao> divisaoMap = {for (var d in divisoes) d.id: d};

      // Mapear divisões permitidas pelo perfil do usuário
      final Set<String> divisaoIdsPermitidasPeloPerfil = Set.from(divisaoIds);
      if (regionalIds.isNotEmpty) {
        for (final rId in regionalIds) {
          divisaoIdsPermitidasPeloPerfil.addAll(
            divisoes.where((d) => d.atuaNaRegional(rId)).map((d) => d.id),
          );
        }
      }

      // Mapear divisões da regional selecionada no formulário
      final Set<String> divisaoIdsDaRegionalForm = {};
      if (formRegionalId != null && formRegionalId.isNotEmpty) {
        divisaoIdsDaRegionalForm.addAll(
          divisoes.where((d) => d.atuaNaRegional(formRegionalId)).map((d) => d.id),
        );
      }

      return todas.where((eq) {
        // 1. Filtrar pelo escopo do formulário (se informado)
        if (formRegionalId != null && formRegionalId.isNotEmpty) {
          final matchesReg = eq.regionalId == formRegionalId;
          final matchesDivReg = eq.divisaoId != null && (divisaoIdsDaRegionalForm.contains(eq.divisaoId) || (divisaoMap[eq.divisaoId]?.atuaNaRegional(formRegionalId) ?? false));
          if (!matchesReg && !matchesDivReg) return false;
        }

        if (formDivisaoId != null && formDivisaoId.isNotEmpty) {
          if (eq.divisaoId != formDivisaoId) return false;
        }

        if (formSegmentoId != null && formSegmentoId.isNotEmpty) {
          if (eq.segmentoId != formSegmentoId) return false;
        }

        // 2. Filtrar pelas restrições do perfil do usuário logado (se houver)
        if (regionalIds.isNotEmpty) {
          final matchesReg = eq.regionalId != null && regionalIds.contains(eq.regionalId);
          final matchesDivReg = eq.divisaoId != null && (
            divisaoIdsPermitidasPeloPerfil.contains(eq.divisaoId) ||
            regionalIds.any((rId) => divisaoMap[eq.divisaoId]?.atuaNaRegional(rId) ?? false)
          );
          if (!matchesReg && !matchesDivReg) return false;
        }

        if (divisaoIdsPermitidasPeloPerfil.isNotEmpty && divisaoIds.isNotEmpty) {
          if (eq.divisaoId != null && !divisaoIdsPermitidasPeloPerfil.contains(eq.divisaoId)) {
            return false;
          }
        }

        if (segmentoIds.isNotEmpty) {
          if (eq.segmentoId != null && !segmentoIds.contains(eq.segmentoId)) {
            return false;
          }
        }

        return true;
      }).toList();
    } catch (e) {
      print('Erro getEquipesPorPerfilUsuario: $e');
      return includeInativas ? await getAllEquipes() : await getEquipesAtivas();
    }
  }
}

