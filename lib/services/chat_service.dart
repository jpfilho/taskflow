import '../models/mensagem.dart';
import '../models/comunidade.dart';
import '../models/grupo_chat.dart';
import '../config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service_simples.dart';
import 'task_service.dart';
import 'telegram_service.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final SupabaseClient _supabase = SupabaseConfig.client;
  final TaskService _taskService = TaskService();
  final TelegramService _telegramService = TelegramService();

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

  // Criar ou obter comunidade para uma regional + divisão + segmento
  Future<Comunidade> criarOuObterComunidade(
    String regionalId,
    String regionalNome,
    String divisaoId,
    String divisaoNome,
    String segmentoId,
    String segmentoNome,
  ) async {
    try {
      // Verificar se já existe (considerando regional + divisão + segmento)
      final existing = await _supabase
          .from('comunidades')
          .select()
          .eq('regional_id', regionalId)
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
            'regional_id': regionalId,
            'regional_nome': regionalNome,
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
          .select()
          .order('updated_at', ascending: false);

      final comunidades = (response as List)
          .map((map) => Comunidade.fromMap(map as Map<String, dynamic>))
          .toList();

      // Aplicar filtros de perfil
      return await _aplicarFiltrosPerfilComunidades(comunidades);
    } catch (e) {
      throw Exception('Erro ao listar comunidades: $e');
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

  // Obter comunidade por regional, divisão e segmento (verificando acesso do usuário)
  Future<Comunidade?> obterComunidadePorDivisaoSegmento(
    String regionalId,
    String divisaoId,
    String segmentoId,
  ) async {
    try {
      final response = await _supabase
          .from('comunidades')
          .select()
          .eq('regional_id', regionalId)
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
      print('Erro no query principal de listarGruposPorComunidade: $e');
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

  // Contar mensagens de múltiplas tarefas (otimizado - usa VIEW do Supabase com fallback)
  Future<Map<String, int>> contarMensagensPorTarefas(List<String> tarefaIds) async {
    if (tarefaIds.isEmpty) return {};

    // Tentativa 1: usar VIEW otimizada
    try {
      dynamic query = _supabase
          .from('contagens_mensagens_tarefas')
          .select('task_id, quantidade');

      if (tarefaIds.length == 1) {
        query = query.eq('task_id', tarefaIds[0]);
      } else {
        final orConditions = tarefaIds.map((id) => 'task_id.eq.$id').join(',');
        query = query.or(orConditions);
      }

      final response = await query as List;

      // Se a VIEW retornou dados, usá-los
      if (response.isNotEmpty) {
        final contagens = <String, int>{};
        for (var item in response) {
          final taskId = item['task_id'] as String;
          final quantidade = item['quantidade'] as int? ?? 0;
          if (quantidade > 0) {
            contagens[taskId] = quantidade;
          }
        }
        return contagens;
      }

      print('⚠️ VIEW contagens_mensagens_tarefas retornou vazio — usando fallback direto.');
    } catch (e) {
      print('⚠️ VIEW contagens_mensagens_tarefas falhou ($e) — usando fallback direto.');
    }

    // Tentativa 2: fallback — buscar grupos das tarefas e contar mensagens diretamente
    try {
      // Buscar grupos_chat das tarefas
      final gruposResp = await _supabase
          .from('grupos_chat')
          .select('id, tarefa_id')
          .inFilter('tarefa_id', tarefaIds);

      if ((gruposResp as List).isEmpty) return {};

      // Mapear grupoId -> tarefaId
      final grupoParaTarefa = <String, String>{};
      for (var g in gruposResp) {
        final grupoId = g['id'] as String;
        final tarefaId = g['tarefa_id'] as String;
        grupoParaTarefa[grupoId] = tarefaId;
      }

      final grupoIds = grupoParaTarefa.keys.toList();

      // Contar mensagens por grupo (excluindo soft-deleted)
      // Fazemos em lote: buscar todas as mensagens dos grupos e contar no cliente
      final mensagensResp = await _supabase
          .from('mensagens')
          .select('grupo_id')
          .inFilter('grupo_id', grupoIds)
          .filter('deleted_at', 'is', null);

      final contagens = <String, int>{};
      for (var m in mensagensResp as List) {
        final grupoId = m['grupo_id'] as String;
        final tarefaId = grupoParaTarefa[grupoId];
        if (tarefaId != null) {
          contagens[tarefaId] = (contagens[tarefaId] ?? 0) + 1;
        }
      }

      print('✅ Fallback chat count: ${contagens.length} tarefas com mensagens');
      return contagens;
    } catch (e) {
      print('❌ Erro no fallback de contarMensagensPorTarefas: $e');
      return {};
    }
  }

  Future<List<GrupoChat>> obterGruposPorTarefasIds(List<String> tarefasIds) async {
    if (tarefasIds.isEmpty) return [];
    try {
      const int chunkSize = 100;
      final futures = <Future<List<dynamic>>>[];
      
      for (var i = 0; i < tarefasIds.length; i += chunkSize) {
        final chunk = tarefasIds.sublist(
          i,
          i + chunkSize > tarefasIds.length ? tarefasIds.length : i + chunkSize,
        );
        futures.add(_supabase.from('grupos_chat').select().inFilter('tarefa_id', chunk));
      }
      
      final results = await Future.wait(futures);
      final todosGrupos = <GrupoChat>[];
      
      for (final res in results) {
        todosGrupos.addAll(res.map((map) => GrupoChat.fromMap(map)));
      }
      return todosGrupos;
    } catch (e) {
      print('Erro ao obter múltiplos grupos por tarefas IDs: $e');
      return [];
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
    // Campos para tags Nota/Ordem
    String? refType,  // 'GERAL' | 'NOTA' | 'ORDEM'
    String? refId,    // UUID da nota_sap ou ordem
    String? refLabel, // Label para exibição (ex: "NOTA 12345")
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
        'source': 'app', // Marcar como mensagem do app (evita loop no Telegram)
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
      
      // Adicionar tags se fornecidas
      if (refType != null) {
        data['ref_type'] = refType;
        if (refId != null) {
          data['ref_id'] = refId;
        }
        if (refLabel != null) {
          data['ref_label'] = refLabel;
        }
      } else {
        // Se não fornecido, usar 'GERAL' como padrão (compatibilidade)
        data['ref_type'] = 'GERAL';
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

      final mensagemEnviada = Mensagem.fromMap(response);

      // Enviar para Telegram (se houver subscription ativa)
      // Não aguardar para não bloquear o envio da mensagem
      _enviarParaTelegramAsync(
        mensagemEnviada.id!, 
        grupoId,
        refType: refType,
        refId: refId,
        refLabel: refLabel,
      );

      return mensagemEnviada;
    } catch (e) {
      throw Exception('Erro ao enviar mensagem: $e');
    }
  }

  // Atualizar tags de uma mensagem existente
  Future<Mensagem> atualizarTagsMensagem(
    String mensagemId, {
    String? refType,
    String? refId,
    String? refLabel,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      if (refType != null) {
        updateData['ref_type'] = refType;
        if (refId != null) {
          updateData['ref_id'] = refId;
        } else {
          updateData['ref_id'] = null;
        }
        if (refLabel != null) {
          updateData['ref_label'] = refLabel;
        } else {
          updateData['ref_label'] = null;
        }
      } else {
        // Se refType é null, resetar para GERAL
        updateData['ref_type'] = 'GERAL';
        updateData['ref_id'] = null;
        updateData['ref_label'] = null;
      }
      
      final response = await _supabase
          .from('mensagens')
          .update(updateData)
          .eq('id', mensagemId)
          .select()
          .single();
      
      return Mensagem.fromMap(response);
    } catch (e) {
      throw Exception('Erro ao atualizar tags da mensagem: $e');
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

      // 1. Deletar mensagem do Telegram primeiro (se foi enviada)
      // Isso também fará soft delete no Supabase via Node.js
      try {
        await _telegramService.deleteMessageFromTelegram(mensagemId);
        print('✅ [Chat] Mensagem deletada via Node.js (Telegram + Supabase soft delete)');
        
        // Aguardar um pouco para garantir que o soft delete foi aplicado
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Verificar se o soft delete foi aplicado
        final mensagemVerificada = await _supabase
            .from('mensagens')
            .select('deleted_at')
            .eq('id', mensagemId)
            .maybeSingle();
        
        if (mensagemVerificada != null && mensagemVerificada['deleted_at'] == null) {
          print('⚠️ [Chat] Soft delete não foi aplicado pelo Node.js, fazendo fallback...');
          // Fallback: fazer soft delete local se o Node.js não aplicou
          await _supabase
              .from('mensagens')
              .update({
                'deleted_at': DateTime.now().toIso8601String(),
                'deleted_by': 'flutter',
              })
              .eq('id', mensagemId);
          print('✅ [Chat] Soft delete local concluído (fallback)');
        } else {
          print('✅ [Chat] Soft delete confirmado no banco');
        }
        
        // A mensagem será removida da UI via Realtime quando deleted_at for atualizado
        return;
      } catch (e) {
        print('⚠️ [Chat] Erro ao deletar mensagem do Telegram: $e');
        print('⚠️ [Chat] Fazendo soft delete local como fallback...');
        // Fallback: fazer soft delete local se o Node.js falhar
        await _supabase
            .from('mensagens')
            .update({
              'deleted_at': DateTime.now().toIso8601String(),
              'deleted_by': 'flutter',
            })
            .eq('id', mensagemId);
        print('✅ [Chat] Soft delete local concluído');
      }
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

  // Buscar última mensagem enviada de múltiplos grupos em uma única requisição customizada em view ou fallback manual
  Future<Map<String, Mensagem>> obterUltimaMensagemPorGrupos(List<String> gruposIds) async {
    if (gruposIds.isEmpty) return {};
    try {
      final resultMap = <String, Mensagem>{};
      
      // Tentativa de leitura em lote usando RPC se existir, ou query indexada se houver limitação PostgREST
      // O Supabase PostgREST não tem suporte nativo p/ GROUP BY max(created_at). Faremos requisições isoladas via Future.wait com limite baixo local.
      final futures = gruposIds.map((grupoId) async {
        try {
          final res = await _supabase
            .from('mensagens')
            .select()
            .eq('grupo_id', grupoId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
            
          if (res != null) {
            return MapEntry(grupoId, Mensagem.fromMap(res));
          }
        } catch (_) {}
        return null;
      });
      
      final results = await Future.wait(futures);
      for (var entry in results) {
        if (entry != null) resultMap[entry.key] = entry.value;
      }
      return resultMap;
    } catch (e) {
      print('Erro no fetch em lote das últimas msgs: $e');
      return {};
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

  // Marcar TODAS as mensagens de um grupo como lidas pelo usuário atual (em lote)
  // Aceita tanto grupo_id quanto tarefa_id (fallback)
  Future<void> marcarMensagensComoLidasPorGrupo(String grupoIdOuTarefaId) async {
    try {
      final userId = currentUserId ?? 'anonymous';
      if (userId == 'anonymous') return;

      // 1. Obter todas as mensagens do grupo (apenas IDs)
      var todasMensagens = await _supabase
          .from('mensagens')
          .select('id')
          .eq('grupo_id', grupoIdOuTarefaId)
          .isFilter('deleted_at', null);

      // Se não encontrou mensagens, pode ser que o ID passado seja tarefa_id
      // (ChatGruposList usa grupo.id ?? grupo.tarefaId)
      if (todasMensagens.isEmpty) {
        // Tentar resolver o grupo_id real a partir do tarefa_id
        final grupo = await _supabase
            .from('grupos_chat')
            .select('id')
            .eq('tarefa_id', grupoIdOuTarefaId)
            .maybeSingle();

        if (grupo != null) {
          final realGrupoId = grupo['id'] as String;
          todasMensagens = await _supabase
              .from('mensagens')
              .select('id')
              .eq('grupo_id', realGrupoId)
              .isFilter('deleted_at', null);
        }
      }

      if (todasMensagens.isEmpty) return;

      final mensagemIds = (todasMensagens as List)
          .map((m) => m['id'] as String)
          .toList();

      // 2. Obter quais já foram marcadas como lidas (em chunks para evitar limite de URL)
      final jaLidasSet = <String>{};
      const chunkSize = 100;
      for (var i = 0; i < mensagemIds.length; i += chunkSize) {
        final chunk = mensagemIds.sublist(
          i,
          i + chunkSize > mensagemIds.length ? mensagemIds.length : i + chunkSize,
        );
        final jaLidas = await _supabase
            .from('mensagens_lidas')
            .select('mensagem_id')
            .eq('usuario_id', userId)
            .inFilter('mensagem_id', chunk);

        for (final m in jaLidas) {
          jaLidasSet.add(m['mensagem_id'] as String);
        }
      }

      // 3. Inserir apenas as não lidas
      final naoLidasIds = mensagemIds.where((id) => !jaLidasSet.contains(id)).toList();

      if (naoLidasIds.isEmpty) return;

      // Inserir em chunks para evitar payloads muito grandes
      for (var i = 0; i < naoLidasIds.length; i += chunkSize) {
        final chunk = naoLidasIds.sublist(
          i,
          i + chunkSize > naoLidasIds.length ? naoLidasIds.length : i + chunkSize,
        );
        final rows = chunk.map((mId) => {
          'mensagem_id': mId,
          'usuario_id': userId,
        }).toList();

        await _supabase.from('mensagens_lidas').upsert(
          rows,
          onConflict: 'mensagem_id,usuario_id',
        );
      }

      print('✅ Marcadas ${naoLidasIds.length} mensagens como lidas no grupo $grupoIdOuTarefaId');
    } catch (e) {
      print('⚠️ Erro ao marcar mensagens como lidas em lote: $e');
      // Não propagar - não afetar a experiência do chat
    }
  }

  // Contar mensagens não lidas de um grupo
  Future<int> contarMensagensNaoLidas(String grupoId) async {
    try {
      final userId = currentUserId ?? 'anonymous';

      // Obter todas as mensagens ativas do grupo (excluir deletadas)
      final todasMensagens = await _supabase
          .from('mensagens')
          .select('id')
          .eq('grupo_id', grupoId)
          .isFilter('deleted_at', null);

      if (todasMensagens.isEmpty) return 0;

      final mensagemIds = (todasMensagens as List)
          .map((m) => m['id'] as String)
          .toList();

      // Obter mensagens já lidas pelo usuário (filtrado pelos IDs relevantes)
      final lidasSet = <String>{};
      const chunkSize = 100;
      for (var i = 0; i < mensagemIds.length; i += chunkSize) {
        final chunk = mensagemIds.sublist(
          i,
          i + chunkSize > mensagemIds.length ? mensagemIds.length : i + chunkSize,
        );
        final lidas = await _supabase
            .from('mensagens_lidas')
            .select('mensagem_id')
            .eq('usuario_id', userId)
            .inFilter('mensagem_id', chunk);
        for (final m in lidas) {
          lidasSet.add(m['mensagem_id'] as String);
        }
      }

      return mensagemIds.length - lidasSet.length;
    } catch (e) {
      return 0;
    }
  }

  // Contar mensagens não lidas de múltiplos grupos em lote
  Future<Map<String, int>> contarMensagensNaoLidasEmLote(List<String> gruposIds) async {
    if (gruposIds.isEmpty) return {};
    
    try {
      final userId = currentUserId ?? 'anonymous';

      // 1. Buscar todas as mensagens ativas dos grupos (excluir deletadas)
      final todasMensagens = <dynamic>[];
      const int chunkSize = 100;
      final futuresMsgs = <Future<List<dynamic>>>[];

      for (var i = 0; i < gruposIds.length; i += chunkSize) {
         final chunk = gruposIds.sublist(
           i,
           i + chunkSize > gruposIds.length ? gruposIds.length : i + chunkSize,
         );
         futuresMsgs.add(
           _supabase.from('mensagens')
               .select('id, grupo_id')
               .inFilter('grupo_id', chunk)
               .isFilter('deleted_at', null),
         );
      }
      
      final resultsMsgs = await Future.wait(futuresMsgs);
      for (final res in resultsMsgs) {
         todasMensagens.addAll(res);
      }

      if (todasMensagens.isEmpty) return {};

      // 2. Buscar quais mensagens o usuário já leu (filtrado pelos IDs relevantes, em chunks)
      final mensagemIds = todasMensagens.map((m) => m['id'] as String).toList();
      final lidasSet = <String>{};

      for (var i = 0; i < mensagemIds.length; i += chunkSize) {
        final chunk = mensagemIds.sublist(
          i,
          i + chunkSize > mensagemIds.length ? mensagemIds.length : i + chunkSize,
        );
        final lidas = await _supabase
            .from('mensagens_lidas')
            .select('mensagem_id')
            .eq('usuario_id', userId)
            .inFilter('mensagem_id', chunk);
        for (final m in lidas) {
          lidasSet.add(m['mensagem_id'] as String);
        }
      }

      // 3. Contabilizar mensagens não lidas por grupo
      final unreadCounts = <String, int>{};
      
      for (var gId in gruposIds) {
          unreadCounts[gId] = 0;
      }

      for (var row in todasMensagens) {
        final mId = row['id'] as String;
        final gId = row['grupo_id'] as String;
        
        if (!lidasSet.contains(mId)) {
          unreadCounts[gId] = (unreadCounts[gId] ?? 0) + 1;
        }
      }

      return unreadCounts;
    } catch (e) {
      print('Erro ao contar mensagens não lidas em lote: $e');
      return {};
    }
  }

  // Contar mensagens não lidas agrupadas por comunidade
  Future<Map<String, int>> contarNaoLidasPorComunidade(List<String> comunidadeIds) async {
    if (comunidadeIds.isEmpty) return {};
    try {
      // 1. Buscar todos os grupos de todas as comunidades de uma vez
      final gruposResp = await _supabase
          .from('grupos_chat')
          .select('id, comunidade_id')
          .inFilter('comunidade_id', comunidadeIds);

      if ((gruposResp as List).isEmpty) return {};

      // Mapear grupoId → comunidadeId
      final grupoComunidade = <String, String>{};
      for (final g in gruposResp) {
        grupoComunidade[g['id'] as String] = g['comunidade_id'] as String;
      }

      // 2. Contar não lidas em lote (por grupo)
      final grupoIds = grupoComunidade.keys.toList();
      final naoLidasPorGrupo = await contarMensagensNaoLidasEmLote(grupoIds);

      // 3. Agregar por comunidade
      final resultado = <String, int>{};
      for (final entry in naoLidasPorGrupo.entries) {
        final comunidadeId = grupoComunidade[entry.key];
        if (comunidadeId != null && entry.value > 0) {
          resultado[comunidadeId] = (resultado[comunidadeId] ?? 0) + entry.value;
        }
      }

      return resultado;
    } catch (e) {
      print('Erro ao contar não lidas por comunidade: $e');
      return {};
    }
  }

  // Contar total de mensagens não lidas em TODOS os grupos acessíveis ao usuário
  Future<int> contarTotalMensagensNaoLidas() async {
    try {
      // 1. Listar todas as comunidades acessíveis ao usuário
      final comunidades = await listarComunidades();
      if (comunidades.isEmpty) return 0;

      // 2. Coletar todos os IDs de grupos de todas as comunidades
      final todosGruposIds = <String>[];
      for (final comunidade in comunidades) {
        if (comunidade.id == null) continue;
        try {
          final grupos = await _supabase
              .from('grupos_chat')
              .select('id')
              .eq('comunidade_id', comunidade.id!);
          for (final g in grupos) {
            todosGruposIds.add(g['id'] as String);
          }
        } catch (e) {
          // Ignorar falha em uma comunidade específica
          print('⚠️ Erro ao listar grupos da comunidade ${comunidade.id}: $e');
        }
      }

      if (todosGruposIds.isEmpty) return 0;

      // 3. Contar não lidas em lote (uma única chamada)
      final naoLidasMap = await contarMensagensNaoLidasEmLote(todosGruposIds);

      // 4. Somar totais
      int total = 0;
      for (final count in naoLidasMap.values) {
        total += count;
      }

      return total;
    } catch (e) {
      print('❌ Erro ao contar total de mensagens não lidas: $e');
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
            .where((map) {
              // Filtrar mensagens deletadas (deleted_at é null)
              final deletedAt = (map as Map<String, dynamic>)['deleted_at'];
              return deletedAt == null;
            })
            .map((map) => Mensagem.fromMap(map as Map<String, dynamic>))
            .toList());
  }

  // ========== INTEGRAÇÃO TELEGRAM ==========

  /// Envia mensagem para Telegram de forma assíncrona (não bloqueia)
  /// Com a arquitetura generalizada, o sistema cria tópicos automaticamente
  /// baseado na comunidade da tarefa, não precisa mais de subscription
  void _enviarParaTelegramAsync(
    String mensagemId, 
    String grupoId, {
    String? refType,
    String? refId,
    String? refLabel,
  }) {
    print('🚀 [Telegram] Iniciando envio assíncrono: mensagemId=$mensagemId, grupoId=$grupoId, refType=$refType');
    
    // Executar em background
    Future(() async {
      try {
        // Com a arquitetura generalizada, sempre tentar enviar
        // O servidor vai verificar se a comunidade tem supergrupo e criar o tópico se necessário
        print('📤 [Telegram] Enviando mensagem $mensagemId para Telegram...');
        await _telegramService.sendMessageToTelegram(
          mensagemId: mensagemId,
          threadType: 'TASK',
          threadId: grupoId,
          refType: refType,
          refId: refId,
          refLabel: refLabel,
        );
        print('✅ [Telegram] Processamento da mensagem $mensagemId concluído (pode ter falhado, verifique logs acima)');
      } catch (e, stackTrace) {
        print('❌ [Telegram] Erro ao enviar mensagem para Telegram: $e');
        print('   Stack trace: $stackTrace');
        // Não propagar erro para não afetar o chat
      }
    }).catchError((error) {
      print('❌ [Telegram] Erro não capturado no Future: $error');
    });
  }

}

