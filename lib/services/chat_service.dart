import '../models/mensagem.dart';
import '../models/comunidade.dart';
import '../models/grupo_chat.dart';
import '../config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service_simples.dart';
import 'task_service.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final SupabaseClient _supabase = SupabaseConfig.client;
  final TaskService _taskService = TaskService();

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

  // ========== COMUNIDADES ==========

  // Criar ou obter comunidade para uma divisão + segmento
  Future<Comunidade> criarOuObterComunidade(
    String divisaoId,
    String divisaoNome,
    String segmentoId,
    String segmentoNome,
  ) async {
    try {
      // Verificar se já existe
      final existing = await _supabase
          .from('comunidades')
          .select()
          .eq('divisao_id', divisaoId)
          .eq('segmento_id', segmentoId)
          .maybeSingle();

      if (existing != null) {
        return Comunidade.fromMap(existing);
      }

      // Criar nova comunidade
      final response = await _supabase
          .from('comunidades')
          .insert({
            'divisao_id': divisaoId,
            'divisao_nome': divisaoNome,
            'segmento_id': segmentoId,
            'segmento_nome': segmentoNome,
          })
          .select()
          .single();

      return Comunidade.fromMap(response);
    } catch (e) {
      throw Exception('Erro ao criar/obter comunidade: $e');
    }
  }

  // Listar todas as comunidades (filtradas pelo perfil do usuário)
  Future<List<Comunidade>> listarComunidades() async {
    try {
      final response = await _supabase
          .from('comunidades')
          .select('''
            *,
            grupos_chat!inner(
              id,
              tarefa_id,
              tarefa_nome,
              ultima_mensagem_at,
              ultima_mensagem_preview
            )
          ''')
          .order('updated_at', ascending: false);

      final comunidades = <Comunidade>[];
      for (var item in response) {
        final comunidade = Comunidade.fromMap(item);
        comunidades.add(comunidade);
      }

      // Aplicar filtros de perfil
      return await _aplicarFiltrosPerfilComunidades(comunidades);
    } catch (e) {
      // Se falhar, tentar sem join
      try {
        final response = await _supabase
            .from('comunidades')
            .select()
            .order('updated_at', ascending: false);

        final comunidades = (response as List)
            .map((map) => Comunidade.fromMap(map as Map<String, dynamic>))
            .toList();

        // Aplicar filtros de perfil
        return await _aplicarFiltrosPerfilComunidades(comunidades);
      } catch (e2) {
        throw Exception('Erro ao listar comunidades: $e2');
      }
    }
  }

  // Aplicar filtros de perfil nas comunidades
  Future<List<Comunidade>> _aplicarFiltrosPerfilComunidades(List<Comunidade> comunidades) async {
    try {
      final authService = AuthServiceSimples();
      final usuario = authService.currentUser;
      
      // Se não há usuário logado, não retornar nenhuma comunidade
      if (usuario == null) {
        print('⚠️ Usuário não autenticado - nenhuma comunidade será exibida');
        return [];
      }

      // Usuários root têm acesso a todas as comunidades
      if (usuario.isRoot) {
        print('🔓 Usuário ROOT detectado - acesso total a todas as comunidades');
        return comunidades;
      }
      
      // Se não tem perfil configurado, não retornar nenhuma comunidade
      if (!usuario.temPerfilConfigurado()) {
        print('⚠️ Usuário sem perfil configurado - nenhuma comunidade será exibida');
        return [];
      }

      // Filtrar comunidades baseado no perfil do usuário
      final comunidadesFiltradas = comunidades.where((comunidade) {
        bool passaDivisao = true;
        bool passaSegmento = true;

        // Verificar acesso à divisão
        if (usuario.divisaoIds.isNotEmpty) {
          passaDivisao = usuario.temAcessoDivisao(comunidade.divisaoId);
        }

        // Verificar acesso ao segmento
        if (usuario.segmentoIds.isNotEmpty) {
          passaSegmento = usuario.temAcessoSegmento(comunidade.segmentoId);
        }

        return passaDivisao && passaSegmento;
      }).toList();

      print('✅ Filtros de perfil aplicados em comunidades: ${comunidadesFiltradas.length} de ${comunidades.length} total');
      return comunidadesFiltradas;
    } catch (e) {
      print('Erro ao aplicar filtros de perfil em comunidades: $e');
      return [];
    }
  }

  // Obter comunidade por ID (verificando acesso do usuário)
  Future<Comunidade?> obterComunidadePorId(String id) async {
    try {
      final response = await _supabase
          .from('comunidades')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;

      final comunidade = Comunidade.fromMap(response);
      
      // Verificar acesso do usuário
      final authService = AuthServiceSimples();
      final usuario = authService.currentUser;
      
      if (usuario != null && !usuario.isRoot && usuario.temPerfilConfigurado()) {
        bool temAcesso = true;
        
        if (usuario.divisaoIds.isNotEmpty) {
          temAcesso = temAcesso && usuario.temAcessoDivisao(comunidade.divisaoId);
        }
        
        if (usuario.segmentoIds.isNotEmpty) {
          temAcesso = temAcesso && usuario.temAcessoSegmento(comunidade.segmentoId);
        }
        
        if (!temAcesso) {
          return null;
        }
      }

      return comunidade;
    } catch (e) {
      throw Exception('Erro ao obter comunidade: $e');
    }
  }

  // Obter comunidade por divisão e segmento (verificando acesso do usuário)
  Future<Comunidade?> obterComunidadePorDivisaoSegmento(
    String divisaoId,
    String segmentoId,
  ) async {
    try {
      final response = await _supabase
          .from('comunidades')
          .select()
          .eq('divisao_id', divisaoId)
          .eq('segmento_id', segmentoId)
          .maybeSingle();

      if (response == null) return null;

      final comunidade = Comunidade.fromMap(response);
      
      // Verificar acesso do usuário
      final authService = AuthServiceSimples();
      final usuario = authService.currentUser;
      
      if (usuario != null && !usuario.isRoot && usuario.temPerfilConfigurado()) {
        bool temAcesso = true;
        
        if (usuario.divisaoIds.isNotEmpty) {
          temAcesso = temAcesso && usuario.temAcessoDivisao(divisaoId);
        }
        
        if (usuario.segmentoIds.isNotEmpty) {
          temAcesso = temAcesso && usuario.temAcessoSegmento(segmentoId);
        }
        
        if (!temAcesso) {
          return null;
        }
      }

      return comunidade;
    } catch (e) {
      throw Exception('Erro ao obter comunidade: $e');
    }
  }

  // ========== GRUPOS ==========

  // Criar ou obter grupo para uma tarefa (verificando acesso do usuário)
  Future<GrupoChat> criarOuObterGrupo(
    String tarefaId,
    String tarefaNome,
    String comunidadeId,
  ) async {
    try {
      // Verificar acesso do usuário à tarefa antes de criar/obter grupo
      final authService = AuthServiceSimples();
      final usuario = authService.currentUser;
      
      if (usuario != null && !usuario.isRoot && usuario.temPerfilConfigurado()) {
        final task = await _taskService.getTaskById(tarefaId);
        if (task == null) {
          throw Exception('Tarefa não encontrada ou não acessível');
        }
        
        // Verificar acesso à tarefa
        bool temAcesso = true;
        
        if (usuario.regionalIds.isNotEmpty && task.regionalId != null) {
          temAcesso = temAcesso && usuario.temAcessoRegional(task.regionalId);
        }
        
        if (usuario.divisaoIds.isNotEmpty && task.divisaoId != null) {
          temAcesso = temAcesso && usuario.temAcessoDivisao(task.divisaoId);
        }
        
        if (usuario.segmentoIds.isNotEmpty && task.segmentoId != null) {
          temAcesso = temAcesso && usuario.temAcessoSegmento(task.segmentoId);
        }
        
        if (!temAcesso) {
          throw Exception('Você não tem acesso a esta tarefa');
        }
      }

      // Verificar se já existe
      final existing = await _supabase
          .from('grupos_chat')
          .select()
          .eq('tarefa_id', tarefaId)
          .maybeSingle();

      if (existing != null) {
        return GrupoChat.fromMap(existing);
      }

      // Criar novo grupo
      final response = await _supabase
          .from('grupos_chat')
          .insert({
            'tarefa_id': tarefaId,
            'tarefa_nome': tarefaNome,
            'comunidade_id': comunidadeId,
          })
          .select()
          .single();

      return GrupoChat.fromMap(response);
    } catch (e) {
      throw Exception('Erro ao criar/obter grupo: $e');
    }
  }

  // Listar grupos de uma comunidade
  Future<List<GrupoChat>> listarGruposPorComunidade(String comunidadeId) async {
    try {
      final response = await _supabase
          .from('grupos_chat')
          .select('''
            *,
            mensagens!grupos_chat_ultima_mensagem_fkey(
              id,
              conteudo,
              created_at
            )
          ''')
          .eq('comunidade_id', comunidadeId)
          .order('updated_at', ascending: false);

      final grupos = <GrupoChat>[];
      for (var item in response) {
        final mensagens = item['mensagens'] as List?;
        final ultimaMensagem = mensagens?.isNotEmpty == true
            ? mensagens?.first
            : null;

        final grupo = GrupoChat.fromMap(item);
        if (ultimaMensagem != null) {
          grupos.add(grupo.copyWith(
            ultimaMensagemAt: DateTime.parse(ultimaMensagem['created_at']),
            ultimaMensagemPreview: ultimaMensagem['conteudo'] as String?,
          ));
        } else {
          grupos.add(grupo);
        }
      }

      return grupos;
    } catch (e) {
      // Se falhar, tentar sem join
      try {
        final response = await _supabase
            .from('grupos_chat')
            .select()
            .eq('comunidade_id', comunidadeId)
            .order('updated_at', ascending: false);

        return (response as List)
            .map((map) => GrupoChat.fromMap(map as Map<String, dynamic>))
            .toList();
      } catch (e2) {
        throw Exception('Erro ao listar grupos: $e2');
      }
    }
  }

  // Obter grupo por ID da tarefa (verificando acesso do usuário)
  Future<GrupoChat?> obterGrupoPorTarefaId(String tarefaId) async {
    try {
      // Verificar se a tarefa está acessível ao usuário
      final authService = AuthServiceSimples();
      final usuario = authService.currentUser;
      
      if (usuario != null && !usuario.isRoot && usuario.temPerfilConfigurado()) {
        final task = await _taskService.getTaskById(tarefaId);
        if (task == null) {
          return null;
        }
        
        // Verificar acesso à tarefa
        bool temAcesso = true;
        
        if (usuario.regionalIds.isNotEmpty && task.regionalId != null) {
          temAcesso = temAcesso && usuario.temAcessoRegional(task.regionalId);
        }
        
        if (usuario.divisaoIds.isNotEmpty && task.divisaoId != null) {
          temAcesso = temAcesso && usuario.temAcessoDivisao(task.divisaoId);
        }
        
        if (usuario.segmentoIds.isNotEmpty && task.segmentoId != null) {
          temAcesso = temAcesso && usuario.temAcessoSegmento(task.segmentoId);
        }
        
        if (!temAcesso) {
          print('⚠️ Tarefa não acessível ao usuário');
          return null;
        }
      }

      final response = await _supabase
          .from('grupos_chat')
          .select()
          .eq('tarefa_id', tarefaId)
          .maybeSingle();

      return response != null ? GrupoChat.fromMap(response) : null;
    } catch (e) {
      throw Exception('Erro ao obter grupo: $e');
    }
  }

  // Obter grupo por ID do grupo
  Future<GrupoChat?> obterGrupoPorId(String grupoId) async {
    try {
      final response = await _supabase
          .from('grupos_chat')
          .select()
          .eq('id', grupoId)
          .maybeSingle();

      return response != null ? GrupoChat.fromMap(response) : null;
    } catch (e) {
      throw Exception('Erro ao obter grupo: $e');
    }
  }

  // Contar mensagens de um grupo por tarefa ID
  Future<int> contarMensagensPorTarefa(String tarefaId) async {
    try {
      // Obter grupo da tarefa
      final grupo = await obterGrupoPorTarefaId(tarefaId);
      if (grupo == null || grupo.id == null) {
        return 0;
      }

      // Contar mensagens do grupo
      final response = await _supabase
          .from('mensagens')
          .select()
          .eq('grupo_id', grupo.id!);

      return (response as List).length;
    } catch (e) {
      print('Erro ao contar mensagens da tarefa: $e');
      return 0;
    }
  }

  // Contar mensagens de múltiplas tarefas (otimizado)
  Future<Map<String, int>> contarMensagensPorTarefas(List<String> tarefaIds) async {
    try {
      if (tarefaIds.isEmpty) return {};

      // Obter grupos das tarefas - buscar um por vez se necessário
      final gruposResponse = <Map<String, dynamic>>[];
      for (var tarefaId in tarefaIds) {
        try {
          final grupo = await _supabase
              .from('grupos_chat')
              .select('id, tarefa_id')
              .eq('tarefa_id', tarefaId)
              .maybeSingle();
          if (grupo != null) {
            gruposResponse.add(grupo);
          }
        } catch (e) {
          // Ignorar erros individuais
        }
      }

      if (gruposResponse.isEmpty) return {};

      final grupoIds = gruposResponse
          .map((g) => g['id'] as String)
          .toList();
      final grupoTarefaMap = <String, String>{};
      for (var grupo in gruposResponse) {
        grupoTarefaMap[grupo['id'] as String] = grupo['tarefa_id'] as String;
      }

      if (grupoIds.isEmpty) return {};

      // Contar mensagens por grupo - buscar um por vez
      final contagens = <String, int>{};
      for (var grupoId in grupoIds) {
        try {
          final mensagensResponse = await _supabase
              .from('mensagens')
              .select('grupo_id')
              .eq('grupo_id', grupoId);
          
          final count = (mensagensResponse as List).length;
          final tarefaId = grupoTarefaMap[grupoId];
          if (tarefaId != null && count > 0) {
            contagens[tarefaId] = count;
          }
        } catch (e) {
          // Ignorar erros individuais
        }
      }

      return contagens;
    } catch (e) {
      print('Erro ao contar mensagens das tarefas: $e');
      return {};
    }
  }

  // ========== MENSAGENS ==========

  // Enviar mensagem
  Future<Mensagem> enviarMensagem(
    String grupoId,
    String conteudo, {
    String? tipo,
    String? arquivoUrl,
    String? usuarioNome,
    String? mensagemRespondidaId,
    List<String>? usuariosMencionados,
    Map<String, dynamic>? localizacao,
  }) async {
    try {
      final userId = currentUserId ?? 'anonymous';
      
      final data = {
        'grupo_id': grupoId,
        'usuario_id': userId,
        'usuario_nome': usuarioNome ?? 'Usuário',
        'conteudo': conteudo,
        'tipo': tipo ?? 'texto',
        'arquivo_url': arquivoUrl,
        'lida': false,
      };
      
      if (mensagemRespondidaId != null) {
        data['mensagem_respondida_id'] = mensagemRespondidaId;
      }
      
      if (usuariosMencionados != null && usuariosMencionados.isNotEmpty) {
        data['usuarios_mencionados'] = usuariosMencionados;
      }
      
      if (localizacao != null) {
        // Armazenar localização como JSON
        data['localizacao'] = localizacao;
      }
      
      final response = await _supabase
          .from('mensagens')
          .insert(data)
          .select()
          .single();

      // Atualizar updated_at do grupo
      await _supabase
          .from('grupos_chat')
          .update({'updated_at': DateTime.now().toIso8601String()})
          .eq('id', grupoId);

      return Mensagem.fromMap(response);
    } catch (e) {
      throw Exception('Erro ao enviar mensagem: $e');
    }
  }

  // Editar mensagem
  Future<Mensagem> editarMensagem(
    String mensagemId,
    String novoConteudo,
  ) async {
    try {
      final userId = currentUserId ?? 'anonymous';
      
      // Verificar se a mensagem pertence ao usuário
      final mensagemAtual = await _supabase
          .from('mensagens')
          .select()
          .eq('id', mensagemId)
          .single();
      
      if (mensagemAtual['usuario_id'] != userId) {
        throw Exception('Você não tem permissão para editar esta mensagem');
      }

      final response = await _supabase
          .from('mensagens')
          .update({
            'conteudo': novoConteudo,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', mensagemId)
          .select()
          .single();

      return Mensagem.fromMap(response);
    } catch (e) {
      throw Exception('Erro ao editar mensagem: $e');
    }
  }

  // Excluir mensagem
  Future<void> excluirMensagem(String mensagemId) async {
    try {
      final userId = currentUserId ?? 'anonymous';
      
      // Verificar se a mensagem pertence ao usuário
      final mensagemAtual = await _supabase
          .from('mensagens')
          .select()
          .eq('id', mensagemId)
          .single();
      
      if (mensagemAtual['usuario_id'] != userId) {
        throw Exception('Você não tem permissão para excluir esta mensagem');
      }

      await _supabase
          .from('mensagens')
          .delete()
          .eq('id', mensagemId);
    } catch (e) {
      throw Exception('Erro ao excluir mensagem: $e');
    }
  }

  // Listar mensagens de um grupo
  Future<List<Mensagem>> listarMensagens(String grupoId, {int? limit}) async {
    try {
      var query = _supabase
          .from('mensagens')
          .select()
          .eq('grupo_id', grupoId)
          .order('created_at', ascending: false);

      if (limit != null) {
        query = query.limit(limit);
      }

      final response = await query;

      final mensagens = (response as List)
          .map((map) => Mensagem.fromMap(map as Map<String, dynamic>))
          .toList();

      // Reverter para ordem cronológica (mais antiga primeiro)
      mensagens.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      return mensagens;
    } catch (e) {
      throw Exception('Erro ao listar mensagens: $e');
    }
  }

  // Marcar mensagem como lida
  Future<void> marcarMensagemComoLida(String mensagemId) async {
    try {
      final userId = currentUserId ?? 'anonymous';

      // Verificar se já foi marcada como lida
      final existing = await _supabase
          .from('mensagens_lidas')
          .select()
          .eq('mensagem_id', mensagemId)
          .eq('usuario_id', userId)
          .maybeSingle();

      if (existing == null) {
        await _supabase.from('mensagens_lidas').insert({
          'mensagem_id': mensagemId,
          'usuario_id': userId,
        });
      }
    } catch (e) {
      throw Exception('Erro ao marcar mensagem como lida: $e');
    }
  }

  // Contar mensagens não lidas de um grupo
  Future<int> contarMensagensNaoLidas(String grupoId) async {
    try {
      final userId = currentUserId ?? 'anonymous';

      // Obter todas as mensagens do grupo
      final todasMensagens = await _supabase
          .from('mensagens')
          .select('id')
          .eq('grupo_id', grupoId);

      if (todasMensagens.isEmpty) return 0;

      final mensagemIds = (todasMensagens as List)
          .map((m) => m['id'] as String)
          .toList();

      // Obter mensagens já lidas pelo usuário
      // Como não temos in_, vamos buscar todas e filtrar manualmente
      final todasLidas = await _supabase
          .from('mensagens_lidas')
          .select('mensagem_id')
          .eq('usuario_id', userId);

      final lidasIds = (todasLidas as List)
          .where((m) => mensagemIds.contains(m['mensagem_id'] as String))
          .map((m) => m['mensagem_id'] as String)
          .toSet();

      return mensagemIds.length - lidasIds.length;
    } catch (e) {
      return 0;
    }
  }

  // Stream de mensagens em tempo real (usando Supabase Realtime)
  Stream<List<Mensagem>> streamMensagens(String grupoId) {
    return _supabase
        .from('mensagens')
        .stream(primaryKey: ['id'])
        .eq('grupo_id', grupoId)
        .order('created_at', ascending: true)
        .map((data) => (data as List)
            .map((map) => Mensagem.fromMap(map as Map<String, dynamic>))
            .toList());
  }

}

