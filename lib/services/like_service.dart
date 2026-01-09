import '../config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service_simples.dart';

class LikeService {
  static final LikeService _instance = LikeService._internal();
  factory LikeService() => _instance;
  LikeService._internal();

  final SupabaseClient _supabase = SupabaseConfig.client;

  // Obter ID do usuário atual
  String? get currentUserId {
    try {
      final authService = AuthServiceSimples();
      final usuario = authService.currentUser;
      if (usuario == null) {
        return null;
      }
      return usuario.id;
    } catch (e) {
      return null;
    }
  }

  // Curtir uma tarefa
  Future<void> curtirTarefa(String taskId) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        throw Exception('Usuário não autenticado');
      }

      // Verificar se já curtiu
      final jaCurtiu = await verificarSeCurtiu(taskId);
      if (jaCurtiu) {
        throw Exception('Você já curtiu esta tarefa');
      }

      // Criar curtida
      await _supabase.from('task_likes').insert({
        'task_id': taskId,
        'usuario_id': userId,
      });
    } catch (e) {
      // Se já existe (UNIQUE constraint), não fazer nada
      if (e.toString().contains('duplicate') || 
          e.toString().contains('unique') ||
          e.toString().contains('violates unique constraint')) {
        return;
      }
      
      // Verificar se a tabela não existe
      if (e.toString().contains('relation') && 
          e.toString().contains('does not exist')) {
        throw Exception('Tabela de curtidas não encontrada. Execute o script SQL criar_tabela_curtidas.sql no Supabase.');
      }
      
      throw Exception('Erro ao curtir tarefa: ${e.toString()}');
    }
  }

  // Descurtir uma tarefa
  Future<void> descurtirTarefa(String taskId) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        throw Exception('Usuário não autenticado');
      }

      await _supabase
          .from('task_likes')
          .delete()
          .eq('task_id', taskId)
          .eq('usuario_id', userId);
    } catch (e) {
      // Verificar se a tabela não existe
      if (e.toString().contains('relation') && 
          e.toString().contains('does not exist')) {
        throw Exception('Tabela de curtidas não encontrada. Execute o script SQL criar_tabela_curtidas.sql no Supabase.');
      }
      throw Exception('Erro ao descurtir tarefa: ${e.toString()}');
    }
  }

  // Verificar se o usuário atual curtiu uma tarefa
  Future<bool> verificarSeCurtiu(String taskId) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return false;
      }

      final response = await _supabase
          .from('task_likes')
          .select('id')
          .eq('task_id', taskId)
          .eq('usuario_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      // Se a tabela não existe, retornar false silenciosamente
      if (e.toString().contains('relation') && 
          e.toString().contains('does not exist')) {
        print('⚠️ Tabela task_likes não encontrada. Execute criar_tabela_curtidas.sql');
        return false;
      }
      print('Erro ao verificar se curtiu: $e');
      return false;
    }
  }

  // Contar curtidas de uma tarefa
  Future<int> contarCurtidas(String taskId) async {
    try {
      final response = await _supabase
          .from('task_likes')
          .select('id')
          .eq('task_id', taskId);

      return (response as List).length;
    } catch (e) {
      // Se a tabela não existe, retornar 0 silenciosamente
      if (e.toString().contains('relation') && 
          e.toString().contains('does not exist')) {
        print('⚠️ Tabela task_likes não encontrada. Execute criar_tabela_curtidas.sql');
        return 0;
      }
      print('Erro ao contar curtidas: $e');
      return 0;
    }
  }

  // Contar curtidas de múltiplas tarefas (otimizado)
  Future<Map<String, int>> contarCurtidasPorTarefas(List<String> taskIds) async {
    try {
      if (taskIds.isEmpty) return {};

      final contagens = <String, int>{};
      
      // Buscar todas as curtidas das tarefas
      for (var taskId in taskIds) {
        try {
          final count = await contarCurtidas(taskId);
          if (count > 0) {
            contagens[taskId] = count;
          }
        } catch (e) {
          // Ignorar erros individuais
          print('Erro ao contar curtidas da tarefa $taskId: $e');
        }
      }

      return contagens;
    } catch (e) {
      print('Erro ao contar curtidas das tarefas: $e');
      return {};
    }
  }

  // Verificar quais tarefas o usuário curtiu (otimizado)
  Future<Map<String, bool>> verificarCurtidasPorTarefas(List<String> taskIds) async {
    try {
      final userId = currentUserId;
      if (userId == null || taskIds.isEmpty) {
        return {};
      }

      final curtidas = <String, bool>{};
      
      // Buscar todas as curtidas do usuário para essas tarefas
      for (var taskId in taskIds) {
        try {
          final jaCurtiu = await verificarSeCurtiu(taskId);
          if (jaCurtiu) {
            curtidas[taskId] = true;
          }
        } catch (e) {
          // Ignorar erros individuais
          print('Erro ao verificar curtida da tarefa $taskId: $e');
        }
      }

      return curtidas;
    } catch (e) {
      print('Erro ao verificar curtidas das tarefas: $e');
      return {};
    }
  }

  // Alternar curtida (curtir se não curtiu, descurtir se já curtiu)
  Future<bool> alternarCurtida(String taskId) async {
    try {
      final jaCurtiu = await verificarSeCurtiu(taskId);
      
      if (jaCurtiu) {
        await descurtirTarefa(taskId);
        return false; // Agora não está curtido
      } else {
        await curtirTarefa(taskId);
        return true; // Agora está curtido
      }
    } catch (e) {
      throw Exception('Erro ao alternar curtida: $e');
    }
  }
}
