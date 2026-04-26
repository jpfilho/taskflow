import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/feriado.dart';
import '../models/local.dart';
import '../config/supabase_config.dart';
import 'auth_service_simples.dart';
import 'usuario_service.dart';
import 'local_database_service.dart';

class FeriadoService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  // Buscar locais permitidos para o usuário atual
  Future<List<Local>> getLocaisPermitidosParaUsuarioAtual() async {
    try {
      final authService = AuthServiceSimples();
      final usuario = authService.currentUser;
      
      if (usuario == null) return [];

      final response = await _supabase.from('locais').select().order('local', ascending: true);
      final todosLocais = (response as List).map((map) => Local.fromMap(map)).toList();

      if (usuario.isRoot || !usuario.temPerfilConfigurado()) {
        return todosLocais;
      }

      final regionaisSet = usuario.regionalIds.toSet();
      final divisoesSet = usuario.divisaoIds.toSet();
      final segmentosSet = usuario.segmentoIds.toSet();

      return todosLocais.where((local) {
        // Se o local tem regional definida e o usuário tem restrição de regionais, valida se coincide
        bool matchRegional = true;
        if (local.regionalId != null && local.regionalId!.isNotEmpty && regionaisSet.isNotEmpty) {
          matchRegional = regionaisSet.contains(local.regionalId);
        }
        
        // Se o local tem divisão definida e o usuário tem restrição de divisões, valida se coincide
        bool matchDivisao = true;
        if (local.divisaoId != null && local.divisaoId!.isNotEmpty && divisoesSet.isNotEmpty) {
          matchDivisao = divisoesSet.contains(local.divisaoId);
        }
        
        // Se o local tem segmento definido e o usuário tem restrição de segmentos, valida se coincide
        bool matchSegmento = true;
        if (local.segmentoId != null && local.segmentoId!.isNotEmpty && segmentosSet.isNotEmpty) {
          matchSegmento = segmentosSet.contains(local.segmentoId);
        }

        // O local é permitido se passar em todas as validações de nível que ele possui
        return matchRegional && matchDivisao && matchSegmento;
      }).toList();
    } catch (e) {
      print('Erro ao buscar locais do usuário: $e');
      return [];
    }
  }

  // Buscar todos os feriados
  Future<List<Feriado>> getAllFeriados() async {
    try {
      final response = await _supabase
          .from('feriados')
          .select('*, feriados_locais(local_id, locais(local))')
          .order('data', ascending: true);

      return List<Map<String, dynamic>>.from(response)
          .map((map) => Feriado.fromMap(map))
          .toList();
    } catch (e) {
      print('Erro ao buscar feriados: $e');
      rethrow;
    }
  }

  // Buscar feriados por data
  Future<List<Feriado>> getFeriadosByDate(DateTime date) async {
    try {
      final dateStr = date.toIso8601String().split('T')[0]; // YYYY-MM-DD
      
      final response = await _supabase
          .from('feriados')
          .select('*, feriados_locais(local_id, locais(local))')
          .eq('data', dateStr);

      return List<Map<String, dynamic>>.from(response)
          .map((map) => Feriado.fromMap(map))
          .toList();
    } catch (e) {
      print('Erro ao buscar feriados por data: $e');
      rethrow;
    }
  }

  // Buscar feriados em um range de datas
  Future<List<Feriado>> getFeriadosByDateRange(DateTime startDate, DateTime endDate) async {
    try {
      final startStr = startDate.toIso8601String().split('T')[0];
      final endStr = endDate.toIso8601String().split('T')[0];
      
      final response = await _supabase
          .from('feriados')
          .select('*, feriados_locais(local_id, locais(local))')
          .gte('data', startStr)
          .lte('data', endStr)
          .order('data', ascending: true);

      return List<Map<String, dynamic>>.from(response)
          .map((map) => Feriado.fromMap(map))
          .toList();
    } catch (e) {
      print('Erro ao buscar feriados por range de datas: $e');
      rethrow;
    }
  }

  // Buscar feriados por tipo
  Future<List<Feriado>> getFeriadosByTipo(String tipo) async {
    try {
      final response = await _supabase
          .from('feriados')
          .select('*, feriados_locais(local_id, locais(local))')
          .eq('tipo', tipo)
          .order('data', ascending: true);

      return List<Map<String, dynamic>>.from(response)
          .map((map) => Feriado.fromMap(map))
          .toList();
    } catch (e) {
      print('Erro ao buscar feriados por tipo: $e');
      rethrow;
    }
  }

  // Buscar feriado por ID
  Future<Feriado?> getFeriadoById(String id) async {
    try {
      final response = await _supabase
          .from('feriados')
          .select('*, feriados_locais(local_id, locais(local))')
          .eq('id', id)
          .single();

      return Feriado.fromMap(Map<String, dynamic>.from(response));
    } catch (e) {
      print('Erro ao buscar feriado por ID: $e');
      return null;
    }
  }

  // Criar novo feriado
  Future<Feriado> createFeriado(Feriado feriado) async {
    return createFeriadoComLocais(feriado, feriado.localIds);
  }

  Future<Feriado> createFeriadoComLocais(Feriado feriado, List<String> localIds) async {
    try {
      final map = feriado.toMap();
      map.remove('id');
      map.remove('created_at');
      map.remove('updated_at');

      final response = await _supabase
          .from('feriados')
          .insert(map)
          .select()
          .single();

      final novoFeriadoId = response['id'] as String;

      if (localIds.isNotEmpty) {
        final links = localIds.map((localId) => {
          'feriado_id': novoFeriadoId,
          'local_id': localId,
        }).toList();

        await _supabase.from('feriados_locais').insert(links);
      }

      return await getFeriadoById(novoFeriadoId) ?? Feriado.fromMap(response);
    } catch (e) {
      print('Erro ao criar feriado: $e');
      rethrow;
    }
  }

  // Atualizar feriado
  Future<Feriado> updateFeriado(Feriado feriado) async {
    return updateFeriadoComLocais(feriado, feriado.localIds);
  }

  Future<Feriado> updateFeriadoComLocais(Feriado feriado, List<String> localIds) async {
    try {
      final map = feriado.toMap();
      map.remove('created_at');
      map.remove('updated_at');

      final response = await _supabase
          .from('feriados')
          .update(map)
          .eq('id', feriado.id)
          .select()
          .single();

      // Deletar locais antigos
      await _supabase
          .from('feriados_locais')
          .delete()
          .eq('feriado_id', feriado.id);

      // Inserir novos locais
      if (localIds.isNotEmpty) {
        final links = localIds.map((localId) => {
          'feriado_id': feriado.id,
          'local_id': localId,
        }).toList();

        await _supabase.from('feriados_locais').insert(links);
      }

      return await getFeriadoById(feriado.id) ?? Feriado.fromMap(response);
    } catch (e) {
      print('Erro ao atualizar feriado: $e');
      rethrow;
    }
  }

  // Deletar feriado
  Future<void> deleteFeriado(String id) async {
    try {
      await _supabase
          .from('feriados')
          .delete()
          .eq('id', id);
    } catch (e) {
      print('Erro ao deletar feriado: $e');
      rethrow;
    }
  }

  // Verificar se uma data é feriado
  Future<bool> isFeriado(DateTime date) async {
    try {
      final feriados = await getFeriadosByDate(date);
      return feriados.isNotEmpty;
    } catch (e) {
      print('Erro ao verificar se é feriado: $e');
      return false;
    }
  }

  // Obter mapa de feriados por data (para uso no Gantt)
  Future<Map<DateTime, List<Feriado>>> getFeriadosMapByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final feriados = await getFeriadosByDateRange(startDate, endDate);
      final Map<DateTime, List<Feriado>> map = {};

      for (var feriado in feriados) {
        final date = DateTime(feriado.data.year, feriado.data.month, feriado.data.day);
        if (!map.containsKey(date)) {
          map[date] = [];
        }
        map[date]!.add(feriado);
      }

      return map;
    } catch (e) {
      print('Erro ao obter mapa de feriados: $e');
      return {};
    }
  }

  // Obter mapa de feriados por data, mas somente os aplicáveis aos locais fornecidos
  Future<Map<DateTime, List<Feriado>>> getFeriadosMapByDateRangeAndLocais(
    DateTime startDate,
    DateTime endDate,
    List<String> localIds,
  ) async {
    try {
      final startStr = startDate.toIso8601String().split('T')[0];
      final endStr = endDate.toIso8601String().split('T')[0];
      
      // Busca feriados no range e com os locais (ou sem local definido se for algum bug, mas idealmente filtramos)
      // Como o left join `feriados_locais` pode retornar multiplos, a API do Supabase tem um recurso de .filter() em subqueries ou usamos `in_`.
      // Mas para não complicar, buscamos os feriados normais no range e filtramos no Dart.
      // Se houverem muitos feriados, o ideal seria uma query RPC ou subquery filtrando a tabela feriados_locais.
      
      final response = await _supabase
          .from('feriados')
          .select('*, feriados_locais!inner(local_id, locais(local))')
          .gte('data', startStr)
          .lte('data', endStr)
          .filter('feriados_locais.local_id', 'in', '(${localIds.join(",")})')
          .order('data', ascending: true);

      final feriados = List<Map<String, dynamic>>.from(response)
          .map((map) => Feriado.fromMap(map))
          .toList();

      final Map<DateTime, List<Feriado>> map = {};

      for (var feriado in feriados) {
        final date = DateTime(feriado.data.year, feriado.data.month, feriado.data.day);
        if (!map.containsKey(date)) {
          map[date] = [];
        }
        // Evitar duplicidade caso a query retorne o mesmo feriado várias vezes devido ao inner join
        if (!map[date]!.any((f) => f.id == feriado.id)) {
          map[date]!.add(feriado);
        }
      }

      return map;
    } catch (e) {
      print('Erro ao obter mapa de feriados por locais: $e');
      return {};
    }
  }
}

