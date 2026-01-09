import '../config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'local_database_service.dart';
import 'connectivity_service.dart';
import 'package:sqflite/sqflite.dart';

class Usuario {
  final String? id;
  final String email;
  final String? nome;
  final bool ativo;
  final bool isRoot; // Usuário root tem acesso a tudo
  final DateTime? createdAt;
  final DateTime? updatedAt;
  // Perfil do usuário (filtros de acesso)
  final List<String> regionalIds; // IDs das regionais permitidas
  final List<String> divisaoIds; // IDs das divisões permitidas
  final List<String> segmentoIds; // IDs dos segmentos permitidos
  final List<String> regionais; // Nomes das regionais (para exibição)
  final List<String> divisoes; // Nomes das divisões (para exibição)
  final List<String> segmentos; // Nomes dos segmentos (para exibição)

  Usuario({
    this.id,
    required this.email,
    this.nome,
    this.ativo = true,
    this.isRoot = false,
    this.createdAt,
    this.updatedAt,
    this.regionalIds = const [],
    this.divisaoIds = const [],
    this.segmentoIds = const [],
    this.regionais = const [],
    this.divisoes = const [],
    this.segmentos = const [],
  });

  factory Usuario.fromMap(Map<String, dynamic> map) {
    // Tratar is_root que pode vir como null, bool ou string
    bool isRootValue = false;
    if (map['is_root'] != null) {
      if (map['is_root'] is bool) {
        isRootValue = map['is_root'] as bool;
      } else if (map['is_root'] is String) {
        isRootValue = (map['is_root'] as String).toLowerCase() == 'true';
      }
    }
    
    return Usuario(
      id: map['id'] as String?,
      email: map['email'] as String,
      nome: map['nome'] as String?,
      ativo: map['ativo'] as bool? ?? true,
      isRoot: isRootValue,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
      regionalIds: map['regional_ids'] != null
          ? List<String>.from(map['regional_ids'] as List)
          : [],
      divisaoIds: map['divisao_ids'] != null
          ? List<String>.from(map['divisao_ids'] as List)
          : [],
      segmentoIds: map['segmento_ids'] != null
          ? List<String>.from(map['segmento_ids'] as List)
          : [],
      regionais: map['regionais'] != null
          ? List<String>.from(map['regionais'] as List)
          : [],
      divisoes: map['divisoes'] != null
          ? List<String>.from(map['divisoes'] as List)
          : [],
      segmentos: map['segmentos'] != null
          ? List<String>.from(map['segmentos'] as List)
          : [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'nome': nome,
      'ativo': ativo,
      'is_root': isRoot,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'regional_ids': regionalIds,
      'divisao_ids': divisaoIds,
      'segmento_ids': segmentoIds,
      'regionais': regionais,
      'divisoes': divisoes,
      'segmentos': segmentos,
    };
  }

  // Verificar se o usuário tem acesso a uma regional específica
  bool temAcessoRegional(String? regionalId) {
    if (regionalId == null) return true;
    if (regionalIds.isEmpty) return true; // Sem restrições
    return regionalIds.contains(regionalId);
  }

  // Verificar se o usuário tem acesso a uma divisão específica
  bool temAcessoDivisao(String? divisaoId) {
    if (divisaoId == null) return true;
    if (divisaoIds.isEmpty) return true; // Sem restrições
    return divisaoIds.contains(divisaoId);
  }

  // Verificar se o usuário tem acesso a um segmento específico
  bool temAcessoSegmento(String? segmentoId) {
    if (segmentoId == null) return true;
    if (segmentoIds.isEmpty) return true; // Sem restrições
    return segmentoIds.contains(segmentoId);
  }

  // Verificar se o usuário tem perfil configurado (tem alguma restrição)
  bool temPerfilConfigurado() {
    // Usuários root não precisam de perfil configurado
    if (isRoot) return true;
    return regionalIds.isNotEmpty || divisaoIds.isNotEmpty || segmentoIds.isNotEmpty;
  }
}

class UsuarioService {
  static final UsuarioService _instance = UsuarioService._internal();
  factory UsuarioService() => _instance;
  UsuarioService._internal();

  final SupabaseClient _supabase = SupabaseConfig.client;
  final LocalDatabaseService _localDb = LocalDatabaseService();
  final ConnectivityService _connectivity = ConnectivityService();

  // Criar novo usuário
  Future<Usuario> criarUsuario({
    required String email,
    required String senha,
    String? nome,
  }) async {
    try {
      // Hash da senha usando bcrypt (precisa ser feito no backend ou usar biblioteca)
      // Por enquanto, vamos armazenar a senha em texto (NÃO RECOMENDADO PARA PRODUÇÃO)
      // Em produção, use bcrypt ou outra função de hash
      
      final senhaHash = senha; // TODO: Implementar hash bcrypt
      
      final response = await _supabase
          .from('usuarios')
          .insert({
            'email': email.toLowerCase().trim(),
            'senha_hash': senhaHash,
            'nome': nome,
            'ativo': true,
          })
          .select()
          .single();

      return Usuario.fromMap(response);
    } catch (e) {
      throw Exception('Erro ao criar usuário: $e');
    }
  }

  // Fazer login (verificar email e senha) - Funciona offline
  Future<Usuario?> fazerLogin({
    required String email,
    required String senha,
  }) async {
    final emailLower = email.toLowerCase().trim();
    
    try {
      // Tentar buscar do Supabase se online
      if (_connectivity.isConnected) {
        try {
          final response = await _supabase
              .from('usuarios')
              .select()
              .eq('email', emailLower)
              .eq('ativo', true)
              .maybeSingle()
              .timeout(const Duration(seconds: 5));

          if (response != null) {
            final senhaHash = response['senha_hash'] as String?;
            if (senhaHash != null && senhaHash == senha) {
              final usuario = Usuario.fromMap(response);
              final usuarioComPerfil = await _carregarPerfilUsuario(usuario);
              
              // Salvar no banco local para uso offline
              await _saveUsuarioToLocal(usuarioComPerfil);
              
              return usuarioComPerfil;
            }
          }
        } catch (e) {
          print('⚠️ Erro ao fazer login online, tentando offline: $e');
        }
      }
      
      // Se offline ou falhou online, buscar do banco local
      final db = await _localDb.database;
      final localUser = await db.query(
        'usuarios_local',
        where: 'email = ? AND ativo = ?',
        whereArgs: [emailLower, 1],
        limit: 1,
      );

      if (localUser.isEmpty) {
        return null; // Usuário não encontrado
      }

      final userData = localUser.first;
      final senhaHash = userData['senha_hash'] as String?;
      
      if (senhaHash == null || senhaHash != senha) {
        return null; // Senha incorreta
      }

      // Converter para Usuario
      final usuario = _usuarioFromLocalMap(userData);
      
      // Carregar perfil do banco local
      final usuarioComPerfil = await _carregarPerfilUsuarioLocal(usuario);
      
      return usuarioComPerfil;
    } catch (e) {
      print('❌ Erro ao fazer login: $e');
      throw Exception('Erro ao fazer login: $e');
    }
  }

  // Salvar usuário no banco local
  Future<void> _saveUsuarioToLocal(Usuario usuario) async {
    try {
      final db = await _localDb.database;
      await db.insert(
        'usuarios_local',
        {
          'id': usuario.id ?? '',
          'email': usuario.email,
          'nome': usuario.nome,
          'senha_hash': '', // Não salvar senha por segurança
          'is_root': usuario.isRoot ? 1 : 0,
          'ativo': usuario.ativo ? 1 : 0,
          'data_criacao': usuario.createdAt?.millisecondsSinceEpoch,
          'data_atualizacao': usuario.updatedAt?.millisecondsSinceEpoch,
          'sync_status': 'synced',
          'last_synced': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('Erro ao salvar usuário localmente: $e');
    }
  }

  // Converter mapa local para Usuario
  Usuario _usuarioFromLocalMap(Map<String, dynamic> map) {
    return Usuario(
      id: map['id'] as String?,
      email: map['email'] as String,
      nome: map['nome'] as String?,
      ativo: (map['ativo'] as int? ?? 1) == 1,
      isRoot: (map['is_root'] as int? ?? 0) == 1,
      createdAt: map['data_criacao'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['data_criacao'] as int)
          : null,
      updatedAt: map['data_atualizacao'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['data_atualizacao'] as int)
          : null,
    );
  }

  // Carregar perfil do usuário do banco local
  Future<Usuario> _carregarPerfilUsuarioLocal(Usuario usuario) async {
    if (usuario.id == null) return usuario;

    try {
      final db = await _localDb.database;
      
      // Carregar regionais
      final regionaisRows = await db.query(
        'usuarios_regionais_local',
        where: 'usuario_id = ?',
        whereArgs: [usuario.id],
      );
      final regionalIds = regionaisRows.map((r) => r['regional_id'] as String).toList();

      // Carregar divisões
      final divisoesRows = await db.query(
        'usuarios_divisoes_local',
        where: 'usuario_id = ?',
        whereArgs: [usuario.id],
      );
      final divisaoIds = divisoesRows.map((r) => r['divisao_id'] as String).toList();

      // Carregar segmentos
      final segmentosRows = await db.query(
        'usuarios_segmentos_local',
        where: 'usuario_id = ?',
        whereArgs: [usuario.id],
      );
      final segmentoIds = segmentosRows.map((r) => r['segmento_id'] as String).toList();

      return Usuario(
        id: usuario.id,
        email: usuario.email,
        nome: usuario.nome,
        ativo: usuario.ativo,
        isRoot: usuario.isRoot,
        createdAt: usuario.createdAt,
        updatedAt: usuario.updatedAt,
        regionalIds: regionalIds,
        divisaoIds: divisaoIds,
        segmentoIds: segmentoIds,
        regionais: usuario.regionais,
        divisoes: usuario.divisoes,
        segmentos: usuario.segmentos,
      );
    } catch (e) {
      print('Erro ao carregar perfil local: $e');
      return usuario;
    }
  }


  // Obter usuário por ID com perfil completo
  Future<Usuario?> obterUsuarioPorId(String id) async {
    try {
      final response = await _supabase
          .from('usuarios')
          .select()
          .eq('id', id)
          .eq('ativo', true)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      // Carregar perfil (regionais, divisões, segmentos)
      final usuario = Usuario.fromMap(response);
      return await _carregarPerfilUsuario(usuario);
    } catch (e) {
      throw Exception('Erro ao obter usuário: $e');
    }
  }

  // Carregar perfil do usuário (regionais, divisões, segmentos)
  Future<Usuario> _carregarPerfilUsuario(Usuario usuario) async {
    if (usuario.id == null) return usuario;

    try {
      // Carregar regionais
      final regionaisResponse = await _supabase
          .from('usuarios_regionais')
          .select('regional_id, regionais(id, regional)')
          .eq('usuario_id', usuario.id!);

      final regionalIds = <String>[];
      final regionais = <String>[];
      for (var item in regionaisResponse) {
        final regionalId = item['regional_id'] as String?;
        final regionalData = item['regionais'] as Map<String, dynamic>?;
        if (regionalId != null) {
          regionalIds.add(regionalId);
          if (regionalData != null) {
            regionais.add(regionalData['regional'] as String? ?? regionalId);
          }
        }
      }

      // Carregar divisões
      final divisoesResponse = await _supabase
          .from('usuarios_divisoes')
          .select('divisao_id, divisoes(id, divisao)')
          .eq('usuario_id', usuario.id!);

      final divisaoIds = <String>[];
      final divisoes = <String>[];
      for (var item in divisoesResponse) {
        final divisaoId = item['divisao_id'] as String?;
        final divisaoData = item['divisoes'] as Map<String, dynamic>?;
        if (divisaoId != null) {
          divisaoIds.add(divisaoId);
          if (divisaoData != null) {
            divisoes.add(divisaoData['divisao'] as String? ?? divisaoId);
          }
        }
      }

      // Carregar segmentos
      final segmentosResponse = await _supabase
          .from('usuarios_segmentos')
          .select('segmento_id, segmentos(id, segmento)')
          .eq('usuario_id', usuario.id!);

      final segmentoIds = <String>[];
      final segmentos = <String>[];
      for (var item in segmentosResponse) {
        final segmentoId = item['segmento_id'] as String?;
        final segmentoData = item['segmentos'] as Map<String, dynamic>?;
        if (segmentoId != null) {
          segmentoIds.add(segmentoId);
          if (segmentoData != null) {
            segmentos.add(segmentoData['segmento'] as String? ?? segmentoId);
          }
        }
      }

      return Usuario(
        id: usuario.id,
        email: usuario.email,
        nome: usuario.nome,
        ativo: usuario.ativo,
        isRoot: usuario.isRoot, // Preservar o status root
        createdAt: usuario.createdAt,
        updatedAt: usuario.updatedAt,
        regionalIds: regionalIds,
        divisaoIds: divisaoIds,
        segmentoIds: segmentoIds,
        regionais: regionais,
        divisoes: divisoes,
        segmentos: segmentos,
      );
    } catch (e) {
      // Se houver erro ao carregar perfil, retornar usuário sem perfil
      print('Erro ao carregar perfil do usuário: $e');
      return usuario;
    }
  }

  // Obter usuário por email com perfil completo
  Future<Usuario?> obterUsuarioPorEmail(String email) async {
    try {
      final response = await _supabase
          .from('usuarios')
          .select()
          .eq('email', email.toLowerCase().trim())
          .eq('ativo', true)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      // Carregar perfil
      final usuario = Usuario.fromMap(response);
      return await _carregarPerfilUsuario(usuario);
    } catch (e) {
      throw Exception('Erro ao obter usuário: $e');
    }
  }

  // Atualizar usuário
  Future<Usuario> atualizarUsuario({
    required String id,
    String? nome,
    String? email,
    bool? ativo,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (nome != null) updates['nome'] = nome;
      if (email != null) updates['email'] = email.toLowerCase().trim();
      if (ativo != null) updates['ativo'] = ativo;

      final response = await _supabase
          .from('usuarios')
          .update(updates)
          .eq('id', id)
          .select()
          .single();

      return Usuario.fromMap(response);
    } catch (e) {
      throw Exception('Erro ao atualizar usuário: $e');
    }
  }

  // Alterar senha
  Future<void> alterarSenha({
    required String id,
    required String novaSenha,
  }) async {
    try {
      // TODO: Implementar hash bcrypt
      final senhaHash = novaSenha;
      
      await _supabase
          .from('usuarios')
          .update({'senha_hash': senhaHash})
          .eq('id', id);
    } catch (e) {
      throw Exception('Erro ao alterar senha: $e');
    }
  }

  // Listar todos os usuários
  Future<List<Usuario>> listarUsuarios({bool? apenasAtivos}) async {
    try {
      var query = _supabase.from('usuarios').select();
      
      if (apenasAtivos == true) {
        query = query.eq('ativo', true);
      }

      final response = await query.order('created_at', ascending: false);

      return (response as List)
          .map((map) => Usuario.fromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Erro ao listar usuários: $e');
    }
  }

  // Deletar usuário (soft delete - marcar como inativo)
  Future<void> deletarUsuario(String id) async {
    try {
      await _supabase
          .from('usuarios')
          .update({'ativo': false})
          .eq('id', id);
    } catch (e) {
      throw Exception('Erro ao deletar usuário: $e');
    }
  }

  // Remover perfil completo do usuário (deletar todas as associações)
  Future<void> removerPerfilCompleto(String usuarioId) async {
    try {
      // Remover todas as regionais
      await _supabase
          .from('usuarios_regionais')
          .delete()
          .eq('usuario_id', usuarioId);

      // Remover todas as divisões
      await _supabase
          .from('usuarios_divisoes')
          .delete()
          .eq('usuario_id', usuarioId);

      // Remover todos os segmentos
      await _supabase
          .from('usuarios_segmentos')
          .delete()
          .eq('usuario_id', usuarioId);
    } catch (e) {
      throw Exception('Erro ao remover perfil: $e');
    }
  }

  // Atualizar perfil do usuário (adicionar novas associações)
  Future<void> atualizarPerfil({
    required String usuarioId,
    required List<String> regionalIds,
    required List<String> divisaoIds,
    required List<String> segmentoIds,
  }) async {
    try {
      // Adicionar regionais
      if (regionalIds.isNotEmpty) {
        final regionaisData = regionalIds.map((id) => {
          'usuario_id': usuarioId,
          'regional_id': id,
        }).toList();
        await _supabase
            .from('usuarios_regionais')
            .upsert(regionaisData, onConflict: 'usuario_id,regional_id');
      }

      // Adicionar divisões
      if (divisaoIds.isNotEmpty) {
        final divisoesData = divisaoIds.map((id) => {
          'usuario_id': usuarioId,
          'divisao_id': id,
        }).toList();
        await _supabase
            .from('usuarios_divisoes')
            .upsert(divisoesData, onConflict: 'usuario_id,divisao_id');
      }

      // Adicionar segmentos
      if (segmentoIds.isNotEmpty) {
        final segmentosData = segmentoIds.map((id) => {
          'usuario_id': usuarioId,
          'segmento_id': id,
        }).toList();
        await _supabase
            .from('usuarios_segmentos')
            .upsert(segmentosData, onConflict: 'usuario_id,segmento_id');
      }
    } catch (e) {
      throw Exception('Erro ao atualizar perfil: $e');
    }
  }
}

