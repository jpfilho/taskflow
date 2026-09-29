import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/mensagem.dart';
import '../models/comunidade.dart';
import '../models/grupo_chat.dart';
import '../models/chat_unread_snapshot.dart';
import '../config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service_simples.dart';
import 'task_service.dart';
import 'telegram_service.dart';
import 'performance_monitor.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  @visibleForTesting
  ChatService.forTesting();

  static final StreamController<Mensagem> _mensagemEnviadaController =
      StreamController<Mensagem>.broadcast();
  static Stream<Mensagem> get onMensagemEnviada =>
      _mensagemEnviadaController.stream;

  SupabaseClient get _supabase => SupabaseConfig.client;
  TaskService get _taskService => TaskService();
  TelegramService get _telegramService => TelegramService();

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
  // Cache para lista de comunidades
  static List<Comunidade>? _cachedComunidades;
  static DateTime? _lastComunidadesFetch;
  static const _comunidadesCacheDuration = Duration(minutes: 5);

  Future<List<Comunidade>> listarComunidades() async {
    // Verificar cache
    if (_lastComunidadesFetch != null && _cachedComunidades != null &&
        DateTime.now().difference(_lastComunidadesFetch!) < _comunidadesCacheDuration) {
      return List<Comunidade>.from(_cachedComunidades!);
    }

    try {
      final response = await _supabase
          .from('comunidades')
          .select('id, regional_id, regional_nome, divisao_id, divisao_nome, segmento_id, segmento_nome, descricao, foto_url, created_at, updated_at');
      
      final lista = (response as List).map((map) => Comunidade.fromMap(map)).toList();
      final filtradas = await _aplicarFiltrosPerfilComunidades(lista);
      
      // Atualizar cache
      _cachedComunidades = filtradas;
      _lastComunidadesFetch = DateTime.now();
      
      return filtradas;
    } catch (e) {
      print('❌ Erro ao listar comunidades: $e');
      return [];
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

  // Listar grupos de uma comunidade (com última mensagem e contagem pré-populadas)
  Future<List<GrupoChat>> listarGruposPorComunidade(String comunidadeId) async {
    try {
      final response = await _supabase
          .from('grupos_chat')
          .select()
          .eq('comunidade_id', comunidadeId)
          .order('updated_at', ascending: false);

      final gruposRaw = (response as List)
          .map((map) => GrupoChat.fromMap(map as Map<String, dynamic>))
          .toList();

      if (gruposRaw.isEmpty) return [];

      final grupoIds = gruposRaw.map((g) => g.id).whereType<String>().toList();

      // Buscar em paralelo: últimas mensagens e contagens totais de mensagens
      final results = await Future.wait([
        obterUltimaMensagemPorGrupos(grupoIds),
        contarMensagensPorGrupos(grupoIds),
      ]);
      final ultimasMsgs = results[0] as Map<String, Mensagem>;
      final contagens = results[1] as Map<String, int>;

      final grupos = <GrupoChat>[];
      for (final grupo in gruposRaw) {
        final ultimaMsg = ultimasMsgs[grupo.id];
        final total = contagens[grupo.id] ?? 0;

        String? preview = ultimaMsg?.conteudo.trim();
        if (preview != null && preview.isEmpty) {
          if (ultimaMsg?.tipo == 'imagem') {
            preview = '📷 Imagem';
          } else if (ultimaMsg?.tipo == 'audio') {
            preview = '🎵 Áudio';
          } else if (ultimaMsg?.tipo == 'video') {
            preview = '🎥 Vídeo';
          } else if (ultimaMsg?.tipo == 'documento') {
            preview = '📄 Documento';
          }
        }

        grupos.add(grupo.copyWith(
          ultimaMensagemAt: ultimaMsg?.createdAt,
          ultimaMensagemPreview: preview,
          totalMensagens: total,
        ));
      }

      // Ordenar por última mensagem (mais recente primeiro)
      grupos.sort((a, b) {
        final aData = a.ultimaMensagemAt ?? a.updatedAt ?? a.createdAt ?? DateTime(1970);
        final bData = b.ultimaMensagemAt ?? b.updatedAt ?? b.createdAt ?? DateTime(1970);
        return bData.compareTo(aData);
      });

      return grupos;
    } catch (e) {
      print('Erro ao listar grupos por comunidade: $e');
      throw Exception('Erro ao listar grupos: $e');
    }
  }

  // Contar mensagens de múltiplos grupos diretamente
  Future<Map<String, int>> contarMensagensPorGrupos(List<String> gruposIds) async {
    if (gruposIds.isEmpty) return {};
    try {
      final response = await _supabase
          .from('mensagens')
          .select('grupo_id')
          .inFilter('grupo_id', gruposIds);

      final map = <String, int>{};
      for (var item in (response as List)) {
        final gId = item['grupo_id'] as String?;
        if (gId != null) {
          map[gId] = (map[gId] ?? 0) + 1;
        }
      }
      return map;
    } catch (e) {
      print('Erro ao contar mensagens por grupos: $e');
      return {};
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

  // Cache para contagem de mensagens
  static final Map<String, int> _cachedMessageCounts = {};
  static DateTime? _lastCountsFetch;
  static const _countsCacheDuration = Duration(minutes: 1);

  // Contar mensagens de múltiplas tarefas (otimizado - usa VIEW do Supabase com fallback)
  Future<Map<String, int>> contarMensagensPorTarefas(List<String> tarefaIds) async {
    PerformanceMonitor.start('ChatService.contarMensagensPorTarefas');
    
    // Verificar cache
    if (_lastCountsFetch != null && 
        DateTime.now().difference(_lastCountsFetch!) < _countsCacheDuration) {
      PerformanceMonitor.stop('ChatService.contarMensagensPorTarefas');
      return Map<String, int>.from(_cachedMessageCounts);
    }

    if (tarefaIds.isEmpty) {
      PerformanceMonitor.stop('ChatService.contarMensagensPorTarefas');
      return {};
    }

    final totalContagens = <String, int>{};
    const int chunkSize = 100;
    final futures = <Future<Map<String, int>>>[];

    for (var i = 0; i < tarefaIds.length; i += chunkSize) {
      final chunk = tarefaIds.sublist(
        i,
        i + chunkSize > tarefaIds.length ? tarefaIds.length : i + chunkSize,
      );
      futures.add(_contarMensagensPorTarefasChunk(chunk));
    }

    final results = await Future.wait(futures);
    for (final res in results) {
      totalContagens.addAll(res);
    }

    // Atualizar cache global
    totalContagens.forEach((k, v) => _cachedMessageCounts[k] = v);
    _lastCountsFetch = DateTime.now();

    PerformanceMonitor.stop('ChatService.contarMensagensPorTarefas');
    return totalContagens;
  }

  // Método auxiliar para contar um chunk de no máximo 100 IDs concorrentemente
  Future<Map<String, int>> _contarMensagensPorTarefasChunk(List<String> chunk) async {
    if (chunk.isEmpty) return {};
    
    // Tentativa 1: usar VIEW otimizada
    try {
      final response = await _supabase
          .from('contagens_mensagens_tarefas')
          .select('task_id, quantidade')
          .inFilter('task_id', chunk) as List;

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
    } catch (e) {
      print('⚠️ VIEW contagens_mensagens_tarefas falhou para o chunk ($e) — usando fallback.');
    }

    // Tentativa 2: fallback — buscar grupos das tarefas e contar mensagens diretamente
    try {
      final gruposResp = await _supabase
          .from('grupos_chat')
          .select('id, tarefa_id')
          .inFilter('tarefa_id', chunk) as List;

      if (gruposResp.isEmpty) return {};

      // Mapear grupoId -> tarefaId
      final grupoParaTarefa = <String, String>{};
      for (var g in gruposResp) {
        final grupoId = g['id'] as String;
        final tarefaId = g['tarefa_id'] as String;
        grupoParaTarefa[grupoId] = tarefaId;
      }

      final grupoIds = grupoParaTarefa.keys.toList();

      // Contar mensagens por grupo (excluindo soft-deleted)
      final mensagensResp = await _supabase
          .from('mensagens')
          .select('grupo_id')
          .inFilter('grupo_id', grupoIds)
          .filter('deleted_at', 'is', null) as List;

      final contagens = <String, int>{};
      for (var m in mensagensResp) {
        final grupoId = m['grupo_id'] as String;
        final tarefaId = grupoParaTarefa[grupoId];
        if (tarefaId != null) {
          contagens[tarefaId] = (contagens[tarefaId] ?? 0) + 1;
        }
      }
      return contagens;
    } catch (e) {
      print('❌ Erro no fallback de contarMensagensPorTarefas para o chunk: $e');
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
    bool? refExecutado, // Status Executado (Sim/Não)
    Map<String, dynamic>? structuredPayload, // Payload do feedback estruturado
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
        if (refExecutado != null) {
          data['ref_executado'] = refExecutado;
        }
      } else {
        // Se não fornecido, usar 'GERAL' como padrão (compatibilidade)
        data['ref_type'] = 'GERAL';
      }

      if (structuredPayload != null) {
        data['structured_payload'] = structuredPayload;
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
      _mensagemEnviadaController.add(mensagemEnviada);

      invalidateTotalUnreadCache();

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
    bool? refExecutado,
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
        if (refExecutado != null) {
          updateData['ref_executado'] = refExecutado;
        } else {
          updateData['ref_executado'] = null;
        }
      } else {
        // Se refType é null, resetar para GERAL
        updateData['ref_type'] = 'GERAL';
        updateData['ref_id'] = null;
        updateData['ref_label'] = null;
        updateData['ref_executado'] = null;
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
      invalidateTotalUnreadCache();
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
        invalidateTotalUnreadCache();
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

      // 1. Obter todas as mensagens do grupo (apenas IDs e usuario_id)
      var todasMensagens = await _supabase
          .from('mensagens')
          .select('id, usuario_id')
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
              .select('id, usuario_id')
              .eq('grupo_id', realGrupoId)
              .isFilter('deleted_at', null);
        }
      }

      if (todasMensagens.isEmpty) return;

      // Filtrar apenas mensagens de outros usuários (mensagens próprias nunca contam como não lidas)
      final mensagensOutros = (todasMensagens as List).where((m) {
        final senderId = m['usuario_id']?.toString();
        return senderId != userId;
      }).toList();

      if (mensagensOutros.isEmpty) {
        // Todas as mensagens do grupo já são do próprio usuário
        invalidateTotalUnreadCache();
        return;
      }

      final mensagemIds = mensagensOutros
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

      if (naoLidasIds.isEmpty) {
        invalidateTotalUnreadCache();
        return;
      }

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

      invalidateTotalUnreadCache();
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
          .select('id, usuario_id')
          .eq('grupo_id', grupoId)
          .isFilter('deleted_at', null);

      if (todasMensagens.isEmpty) return 0;

      // Mensagens enviadas pelo próprio usuário NUNCA são contabilizadas como não lidas para ele
      final mensagensOutros = (todasMensagens as List).where((m) {
        if (userId == 'anonymous') return true;
        final senderId = m['usuario_id']?.toString();
        return senderId != userId;
      }).toList();

      if (mensagensOutros.isEmpty) return 0;

      final mensagemIds = mensagensOutros
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
               .select('id, grupo_id, usuario_id')
               .inFilter('grupo_id', chunk)
               .isFilter('deleted_at', null),
         );
      }
      
      final resultsMsgs = await Future.wait(futuresMsgs);
      for (final res in resultsMsgs) {
         todasMensagens.addAll(res);
      }

      if (todasMensagens.isEmpty) return {};

      // 2. Buscar quais mensagens o usuário já leu (filtrado pelos IDs relevantes, em chunks concorrentes)
      final mensagemIds = todasMensagens.map((m) => m['id'] as String).toList();
      final lidasSet = <String>{};
      final futuresLidas = <Future<List<dynamic>>>[];

      for (var i = 0; i < mensagemIds.length; i += chunkSize) {
        final chunk = mensagemIds.sublist(
          i,
          i + chunkSize > mensagemIds.length ? mensagemIds.length : i + chunkSize,
        );
        futuresLidas.add(
          _supabase
              .from('mensagens_lidas')
              .select('mensagem_id')
              .eq('usuario_id', userId)
              .inFilter('mensagem_id', chunk)
              .then((value) => value as List<dynamic>),
        );
      }

      final resultsLidas = await Future.wait(futuresLidas);
      for (final lidas in resultsLidas) {
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
        final senderId = row['usuario_id']?.toString();
        
        // Mensagens enviadas pelo próprio usuário NUNCA são contabilizadas como não lidas para ele
        if (userId != 'anonymous' && senderId != null && senderId == userId) {
          continue;
        }

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
  // Cache para contagem total (badge do header)
  static int? _cachedTotalUnread;
  static DateTime? _lastTotalUnreadFetch;
  static String? _cachedUserId;
  // Reduzido para 15 segundos para proteger contra chamadas simultâneas/rajadas sem congelar a UI por 10 minutos
  static const _totalUnreadCacheDuration = Duration(seconds: 15);

  /// Invalida o cache estático de contagem total não lida (ex: ao ler, enviar ou receber mensagens)
  static void invalidateTotalUnreadCache() {
    _cachedTotalUnread = null;
    _lastTotalUnreadFetch = null;
    _cachedUserId = null;
  }

  /// Invalida o cache estático de contagem total não lida (método de instância)
  void invalidarCacheNaoLidas() => invalidateTotalUnreadCache();

  /// Carrega snapshot completo e consistente de mensagens não lidas
  /// (Total, por Comunidade e por Grupo) em apenas uma operação em lote.
  Future<ChatUnreadSnapshot> carregarSnapshotNaoLidasCompleto() async {
    PerformanceMonitor.start('ChatService.carregarSnapshotNaoLidasCompleto');
    final userId = currentUserId;

    try {
      // 1. Listar todas as comunidades acessíveis ao usuário
      final comunidades = await listarComunidades();
      if (comunidades.isEmpty) {
        PerformanceMonitor.stop('ChatService.carregarSnapshotNaoLidasCompleto');
        return ChatUnreadSnapshot.empty();
      }

      // 2. Coletar grupos e mapeamento grupoId -> comunidadeId em lote
      final idsComunidades = comunidades.map((c) => c.id).whereType<String>().toList();
      final todosGruposIds = <String>[];
      final groupToCommunity = <String, String>{};

      if (idsComunidades.isNotEmpty) {
        try {
          final grupos = await _supabase
              .from('grupos_chat')
              .select('id, comunidade_id')
              .inFilter('comunidade_id', idsComunidades);

          for (final g in grupos) {
            final gid = g['id']?.toString();
            final cid = g['comunidade_id']?.toString();
            if (gid != null) {
              todosGruposIds.add(gid);
              if (cid != null) {
                groupToCommunity[gid] = cid;
              }
            }
          }
        } catch (e) {
          print('⚠️ Erro ao listar grupos em lote para snapshot: $e');
        }
      }

      if (todosGruposIds.isEmpty) {
        PerformanceMonitor.stop('ChatService.carregarSnapshotNaoLidasCompleto');
        return ChatUnreadSnapshot.empty();
      }

      // 3. Contar não lidas por grupo em lote (reutiliza método da Fase 1)
      final naoLidasMap = await contarMensagensNaoLidasEmLote(todosGruposIds);

      // 4. Agregar por comunidade e total
      final unreadByCommunity = <String, int>{};
      for (final cid in idsComunidades) {
        unreadByCommunity[cid] = 0;
      }

      int total = 0;
      for (final entry in naoLidasMap.entries) {
        final gId = entry.key;
        final count = entry.value;
        if (count > 0) {
          total += count;
          final cId = groupToCommunity[gId];
          if (cId != null) {
            unreadByCommunity[cId] = (unreadByCommunity[cId] ?? 0) + count;
          }
        }
      }

      _cachedTotalUnread = total;
      _cachedUserId = userId;
      _lastTotalUnreadFetch = DateTime.now();

      final snapshot = ChatUnreadSnapshot(
        totalUnread: total,
        unreadByCommunity: unreadByCommunity,
        unreadByGroup: naoLidasMap,
        groupToCommunity: groupToCommunity,
        timestamp: DateTime.now(),
      );

      PerformanceMonitor.stop('ChatService.carregarSnapshotNaoLidasCompleto');
      return snapshot;
    } catch (e) {
      print('❌ Erro ao carregar snapshot completo de mensagens não lidas: $e');
      PerformanceMonitor.stop('ChatService.carregarSnapshotNaoLidasCompleto');
      rethrow;
    }
  }

  Future<int> contarTotalMensagensNaoLidas({bool forceRefresh = false}) async {
    PerformanceMonitor.start('ChatService.contarTotalMensagensNaoLidas');
    
    final userId = currentUserId;

    // Se o usuário mudou ou foi solicitada atualização forçada, limpa o cache
    if (forceRefresh || userId != _cachedUserId) {
      _cachedTotalUnread = null;
      _lastTotalUnreadFetch = null;
    }

    if (!forceRefresh &&
        _lastTotalUnreadFetch != null &&
        _cachedTotalUnread != null &&
        DateTime.now().difference(_lastTotalUnreadFetch!) < _totalUnreadCacheDuration) {
      PerformanceMonitor.stop('ChatService.contarTotalMensagensNaoLidas');
      return _cachedTotalUnread!;
    }

    try {
      final snapshot = await carregarSnapshotNaoLidasCompleto();
      PerformanceMonitor.stop('ChatService.contarTotalMensagensNaoLidas');
      return snapshot.totalUnread;
    } catch (e) {
      print('❌ Erro ao contar total de mensagens não lidas: $e');
      PerformanceMonitor.stop('ChatService.contarTotalMensagensNaoLidas');
      return _cachedTotalUnread ?? 0;
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

