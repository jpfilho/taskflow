import '../models/executor.dart';
import '../config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'local_database_service.dart';
import 'connectivity_service.dart';
import 'sync_service.dart';
import 'package:sqflite/sqflite.dart';

class ExecutorService {
  static final ExecutorService _instance = ExecutorService._internal();
  factory ExecutorService() => _instance;
  ExecutorService._internal();

  final SupabaseClient _supabase = SupabaseConfig.client;
  final LocalDatabaseService _localDb = LocalDatabaseService();
  final ConnectivityService _connectivity = ConnectivityService();
  final SyncService _syncService = SyncService();

  // Converter Map do Supabase para Executor
  Executor _executorFromMap(Map<String, dynamic> map) {
    return Executor.fromMap(map);
  }

  // Converter Executor para Map (para Supabase)
  Map<String, dynamic> _executorToMap(Executor executor) {
    return executor.toMap();
  }

  // Buscar todos os executores
  Future<List<Executor>> getAllExecutores() async {
    // Se offline, ler do banco local
    if (!_connectivity.isConnected) {
      return await _getAllExecutoresFromLocal();
    }

    try {
      final response = await _supabase
          .from('executores')
          .select('''
            *,
            empresas!left(empresa),
            funcoes!left(funcao),
            divisoes!left(divisao),
            executores_segmentos!left(segmentos!inner(id, segmento))
          ''')
          .order('nome', ascending: true)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              print('⚠️ Timeout ao buscar executores');
              return <Map<String, dynamic>>[];
            },
          );

      if (response.isEmpty) {
        // Se não houver dados online, tentar do banco local
        return await _getAllExecutoresFromLocal();
      }

      final executoresList = response as List;
      final executores = executoresList
          .map((map) => _executorFromMap(map as Map<String, dynamic>))
          .toList();
      
      // Salvar no banco local (apenas se não for web)
      if (!kIsWeb) {
      for (var executor in executores) {
        try {
          await _saveExecutorToLocal(executor);
        } catch (e) {
          print('⚠️ Erro ao salvar executor no banco local: $e');
          }
        }
      }
      
      return executores;
    } catch (e) {
      print('Erro ao buscar executores do Supabase: $e');
      // Fallback para banco local
      return await _getAllExecutoresFromLocal();
    }
  }

  Future<List<Executor>> _getAllExecutoresFromLocal() async {
    if (kIsWeb) return [];
    try {
      final db = await _localDb.database;
      final executoresRows = await db.query('executores_local', orderBy: 'nome ASC');
      
      return executoresRows.map((row) => _executorFromLocalMap(row)).toList();
    } catch (e) {
      print('Erro ao buscar executores do banco local: $e');
      return [];
    }
  }

  Executor _executorFromLocalMap(Map<String, dynamic> row) {
    return Executor(
      id: row['id'] as String,
      nome: row['nome'] as String,
      nomeCompleto: row['nome_completo'] as String?,
      login: row['login'] as String?,
      funcao: row['funcao'] as String?,
      empresa: row['empresa'] as String?,
      matricula: row['matricula'] as String?,
      ativo: (row['ativo'] as int? ?? 1) == 1,
    );
  }

  Future<void> _saveExecutorToLocal(Executor executor) async {
    try {
      final db = await _localDb.database;
      await db.insert(
        'executores_local',
        {
          'id': executor.id,
          'nome': executor.nome,
          'nome_completo': executor.nomeCompleto,
          'funcao': executor.funcao,
          'empresa': executor.empresa,
          'matricula': executor.matricula,
          'ativo': executor.ativo ? 1 : 0,
          'sync_status': 'synced',
          'last_synced': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('Erro ao salvar executor no banco local: $e');
    }
  }

  // Buscar executores ativos
  Future<List<Executor>> getExecutoresAtivos() async {
    try {
      final response = await _supabase
          .from('executores')
          .select('''
            *,
            empresas!left(empresa),
            funcoes!left(funcao),
            divisoes!left(divisao),
            executores_segmentos!left(segmentos!inner(id, segmento))
          ''')
          .eq('ativo', true)
          .order('nome', ascending: true)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              print('⚠️ Timeout ao buscar executores ativos');
              return <Map<String, dynamic>>[];
            },
          );

      if (response.isEmpty) return [];

      final executoresList = response as List;
      return executoresList
          .map((map) => _executorFromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Erro ao buscar executores ativos: $e');
      return [];
    }
  }

  // Buscar executores por divisão
  Future<List<Executor>> getExecutoresPorDivisao(String divisaoId) async {
    try {
      final response = await _supabase
          .from('executores')
          .select('''
            *,
            empresas!left(empresa),
            funcoes!left(funcao),
            divisoes!left(divisao),
            executores_segmentos!left(segmentos!inner(id, segmento))
          ''')
          .eq('divisao_id', divisaoId)
          .eq('ativo', true)
          .order('nome', ascending: true);

      if (response.isEmpty) return [];

      final executoresList = response as List;
      return executoresList
          .map((map) => _executorFromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Erro ao buscar executores por divisão: $e');
      return [];
    }
  }

  // Buscar executores por segmento
  Future<List<Executor>> getExecutoresPorSegmento(String segmentoId) async {
    try {
      // Buscar executores que têm o segmento específico via tabela de junção
      final response = await _supabase
          .from('executores_segmentos')
          .select('''
            executores!inner(
              *,
              empresas!left(empresa),
              funcoes!left(funcao),
              divisoes!left(divisao),
              executores_segmentos!left(segmentos!inner(id, segmento))
            )
          ''')
          .eq('segmento_id', segmentoId)
          .eq('executores.ativo', true);

      if (response.isEmpty) return [];

      // Extrair executores da resposta aninhada
      final executoresList = response as List;
      final executores = <Executor>[];
      
      for (var item in executoresList) {
        if (item is Map<String, dynamic> && item['executores'] != null) {
          final executorMap = item['executores'] as Map<String, dynamic>;
          executores.add(_executorFromMap(executorMap));
        }
      }
      
      // Remover duplicatas (mesmo executor pode aparecer múltiplas vezes)
      final uniqueExecutores = <String, Executor>{};
      for (var executor in executores) {
        uniqueExecutores[executor.id] = executor;
      }
      
      final sortedExecutores = uniqueExecutores.values.toList()
        ..sort((a, b) => a.nome.compareTo(b.nome));
      
      return sortedExecutores;
    } catch (e) {
      print('Erro ao buscar executores por segmento: $e');
      return [];
    }
  }

  // Buscar executores filtrados por regional, divisão e segmento
  Future<List<Executor>> getExecutoresFiltrados({
    String? regionalId,
    String? divisaoId,
    String? segmentoId,
  }) async {
    try {
      List<Executor> executores = [];

      // Se tiver segmento, buscar por segmento (mais específico)
      if (segmentoId != null && segmentoId.isNotEmpty) {
        executores = await getExecutoresPorSegmento(segmentoId);
      }
      // Se tiver divisão mas não segmento, buscar por divisão
      else if (divisaoId != null && divisaoId.isNotEmpty) {
        executores = await getExecutoresPorDivisao(divisaoId);
      }
      // Se não tiver filtros específicos, buscar todos ativos
      else {
        executores = await getExecutoresAtivos();
      }

      // Filtrar por regional se especificado (filtro adicional)
      if (regionalId != null && regionalId.isNotEmpty) {
        // Buscar divisões da regional e filtrar executores
        final divisoesDaRegional = await _supabase
            .from('divisoes')
            .select('id')
            .eq('regional_id', regionalId);
        
        if (divisoesDaRegional.isNotEmpty) {
          final divisaoIds = (divisoesDaRegional as List)
              .map((d) => d['id'] as String)
              .toList();
          
          executores = executores.where((e) {
            return e.divisaoId != null && divisaoIds.contains(e.divisaoId);
          }).toList();
        } else {
          executores = [];
        }
      }

      return executores;
    } catch (e) {
      print('Erro ao buscar executores filtrados: $e');
      return [];
    }
  }

  // Buscar executor por ID
  Future<Executor?> getExecutorById(String id) async {
    try {
      final response = await _supabase
          .from('executores')
          .select('''
            *,
            empresas!left(empresa),
            funcoes!left(funcao),
            divisoes!left(divisao),
            executores_segmentos!left(segmentos!inner(id, segmento))
          ''')
          .eq('id', id)
          .single();

      return _executorFromMap(Map<String, dynamic>.from(response));
    } catch (e) {
      print('Erro ao buscar executor por ID: $e');
      return null;
    }
  }

  // Criar executor
  Future<Executor> createExecutor(Executor executor) async {
    // Salvar no banco local primeiro
    final executorId = executor.id.isNotEmpty 
        ? executor.id 
        : 'EXEC_${DateTime.now().millisecondsSinceEpoch}';
    final executorWithId = executor.copyWith(id: executorId);
    
    try {
      await _saveExecutorToLocal(executorWithId);
      await _localDb.updateSyncStatus('executores', executorId, 'pending');
    } catch (e) {
      print('⚠️ Erro ao salvar executor no banco local: $e');
    }
    
    // Se online, tentar salvar no Supabase
    if (_connectivity.isConnected) {
      try {
        final map = _executorToMap(executorWithId);
        map.remove('id'); // Remover ID para deixar o banco gerar
        map.remove('created_at');
        map.remove('updated_at');
        
        // Limpar valores nulos e vazios que podem causar problemas
        map.removeWhere((key, value) => value == null || (value is String && value.isEmpty && key != 'nome'));
        
        print('📝 Criando executor com dados: $map');

        // Inserir executor
        Executor? executorCompleto;
        try {
          final response = await _supabase
              .from('executores')
              .insert(map)
              .select('id')
              .single()
              .timeout(
                const Duration(seconds: 30),
                onTimeout: () {
                  throw Exception('Timeout ao criar executor');
                },
              );

          final supabaseExecutorId = response['id'] as String;
          print('✅ Executor criado com ID: $supabaseExecutorId');

          // Inserir relacionamentos com segmentos
          if (executor.segmentoIds.isNotEmpty) {
            final segmentosData = executor.segmentoIds.map((segmentoId) => {
              'executor_id': supabaseExecutorId,
              'segmento_id': segmentoId,
            }).toList();

            await _supabase
                .from('executores_segmentos')
                .insert(segmentosData);
            print('✅ Relacionamentos com segmentos criados');
          }

          // Buscar executor completo com joins
          executorCompleto = await getExecutorById(supabaseExecutorId);
          if (executorCompleto != null) {
            // Atualizar no banco local com o ID do Supabase
            try {
              await _saveExecutorToLocal(executorCompleto);
              await _localDb.updateSyncStatus('executores', executorCompleto.id, 'synced');
            } catch (e) {
              print('⚠️ Erro ao atualizar executor no banco local: $e');
            }
            return executorCompleto;
          }

          throw Exception('Erro ao buscar executor criado');
        } catch (insertError) {
          print('❌ Erro no insert: $insertError');
          // Se o select falhar, tentar buscar o ID de outra forma
          if (insertError.toString().contains('Failed to fetch') || insertError.toString().contains('select')) {
            // Tentar inserir sem select e depois buscar
            await _supabase.from('executores').insert(map);
            
            // Aguardar um pouco para o banco processar
            await Future.delayed(const Duration(milliseconds: 500));
            
            // Buscar o executor recém-criado pelo nome (assumindo que é único)
            final executores = await _supabase
                .from('executores')
                .select('id')
                .eq('nome', executor.nome)
                .order('created_at', ascending: false)
                .limit(1);
            
            if (executores.isNotEmpty && executores[0]['id'] != null) {
              final supabaseExecutorId = executores[0]['id'] as String;
              print('✅ Executor encontrado pelo nome com ID: $supabaseExecutorId');
              
              // Inserir relacionamentos com segmentos
              if (executor.segmentoIds.isNotEmpty) {
                final segmentosData = executor.segmentoIds.map((segmentoId) => {
                  'executor_id': supabaseExecutorId,
                  'segmento_id': segmentoId,
                }).toList();

                await _supabase
                    .from('executores_segmentos')
                    .insert(segmentosData);
              }

              // Buscar executor completo
              executorCompleto = await getExecutorById(supabaseExecutorId);
              if (executorCompleto != null) {
                // Atualizar no banco local
                try {
                  await _saveExecutorToLocal(executorCompleto);
                  await _localDb.updateSyncStatus('executores', executorCompleto.id, 'synced');
                } catch (e) {
                  print('⚠️ Erro ao atualizar executor no banco local: $e');
                }
                return executorCompleto;
              }
            }
          }
          // Se falhar, adicionar à fila e retornar o executor local
          try {
            await _syncService.queueOperation('executores', 'insert', executorId, _executorToMap(executorWithId));
          } catch (e2) {
            print('⚠️ Erro ao adicionar à fila de sincronização: $e2');
          }
          return executorWithId;
        }
      } catch (e) {
        print('Erro ao criar executor no Supabase: $e');
        // Adicionar à fila de sincronização
        try {
          await _syncService.queueOperation('executores', 'insert', executorId, _executorToMap(executorWithId));
        } catch (e2) {
          print('⚠️ Erro ao adicionar à fila de sincronização: $e2');
        }
        return executorWithId;
      }
    } else {
      // Se offline, apenas retornar o executor salvo localmente
      // Adicionar à fila de sincronização
      try {
        await _syncService.queueOperation('executores', 'insert', executorId, _executorToMap(executorWithId));
      } catch (e) {
        print('⚠️ Erro ao adicionar à fila de sincronização: $e');
      }
      return executorWithId;
    }
  }

  // Atualizar executor
  Future<Executor> updateExecutor(String id, Executor executor) async {
    // Salvar no banco local primeiro
    try {
      await _saveExecutorToLocal(executor);
      await _localDb.updateSyncStatus('executores', id, 'pending');
    } catch (e) {
      print('⚠️ Erro ao salvar executor no banco local: $e');
    }
    
    // Se online, tentar atualizar no Supabase
    if (_connectivity.isConnected) {
      try {
        final map = _executorToMap(executor);
        map.remove('id');
        map.remove('created_at');
        map.remove('updated_at');

        // Atualizar dados do executor
        await _supabase
            .from('executores')
            .update(map)
            .eq('id', id);

        // Remover relacionamentos antigos com segmentos
        await _supabase
            .from('executores_segmentos')
            .delete()
            .eq('executor_id', id);

        // Inserir novos relacionamentos com segmentos
        if (executor.segmentoIds.isNotEmpty) {
          final segmentosData = executor.segmentoIds.map((segmentoId) => {
            'executor_id': id,
            'segmento_id': segmentoId,
          }).toList();

          await _supabase
              .from('executores_segmentos')
              .insert(segmentosData);
        }

        // Buscar executor completo com joins
        final executorCompleto = await getExecutorById(id);
        if (executorCompleto != null) {
          // Atualizar no banco local
          try {
            await _saveExecutorToLocal(executorCompleto);
            await _localDb.updateSyncStatus('executores', id, 'synced');
          } catch (e) {
            print('⚠️ Erro ao atualizar executor no banco local: $e');
          }
          return executorCompleto;
        }

        throw Exception('Erro ao buscar executor atualizado');
      } catch (e) {
        print('Erro ao atualizar executor no Supabase: $e');
        // Adicionar à fila de sincronização
        try {
          await _syncService.queueOperation('executores', 'update', id, _executorToMap(executor));
        } catch (e2) {
          print('⚠️ Erro ao adicionar à fila de sincronização: $e2');
        }
        return executor;
      }
    } else {
      // Se offline, apenas adicionar à fila
      try {
        await _syncService.queueOperation('executores', 'update', id, _executorToMap(executor));
      } catch (e) {
        print('⚠️ Erro ao adicionar à fila de sincronização: $e');
      }
      return executor;
    }
  }

  // Deletar executor
  Future<bool> deleteExecutor(String id) async {
    // Deletar do banco local primeiro
    try {
      final db = await _localDb.database;
      await db.delete('executores_local', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      print('⚠️ Erro ao deletar executor do banco local: $e');
    }
    
    // Se online, tentar deletar do Supabase
    if (_connectivity.isConnected) {
      try {
        await _supabase.from('executores').delete().eq('id', id);
        return true;
      } catch (e) {
        print('Erro ao deletar executor do Supabase: $e');
        // Adicionar à fila de sincronização
        try {
          await _syncService.queueOperation('executores', 'delete', id, {'id': id});
        } catch (e2) {
          print('⚠️ Erro ao adicionar à fila de sincronização: $e2');
        }
        return true; // Retornar true porque já deletou localmente
      }
    } else {
      // Se offline, apenas adicionar à fila
      try {
        await _syncService.queueOperation('executores', 'delete', id, {'id': id});
      } catch (e) {
        print('⚠️ Erro ao adicionar à fila de sincronização: $e');
      }
      return true;
    }
  }

  // Buscar executores que são coordenadores ou gerentes
  // Coordenadores podem ser identificados pela função que contém "COORDENADOR" ou "GERENTE"
  Future<List<Executor>> getCoordenadores() async {
    try {
      final response = await _supabase
          .from('executores')
          .select('''
            *,
            empresas!left(empresa),
            funcoes!left(funcao),
            divisoes!left(divisao),
            executores_segmentos!left(segmentos!inner(id, segmento))
          ''')
          .eq('ativo', true)
          .order('nome', ascending: true)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              print('⚠️ Timeout ao buscar coordenadores');
              return <Map<String, dynamic>>[];
            },
          );

      if (response.isEmpty) return [];

      final executoresList = response as List;
      final todosExecutores = executoresList
          .map((map) => _executorFromMap(map as Map<String, dynamic>))
          .toList();

      // Filtrar apenas executores que têm função de coordenador ou gerente
      // Considera funções que contenham "COORDENADOR" ou "GERENTE" (case insensitive)
      final coordenadores = todosExecutores.where((executor) {
        if (executor.funcao == null || executor.funcao!.isEmpty) {
          return false;
        }
        final funcaoUpper = executor.funcao!.toUpperCase();
        return funcaoUpper.contains('COORDENADOR') || funcaoUpper.contains('GERENTE');
      }).toList();

      print('👔 Coordenadores encontrados: ${coordenadores.length} de ${todosExecutores.length} executores');
      for (var coord in coordenadores) {
        print('   - ${coord.nomeCompleto ?? coord.nome} (${coord.funcao})');
      }

      return coordenadores;
    } catch (e) {
      print('Erro ao buscar coordenadores: $e');
      return [];
    }
  }

  // Buscar coordenadores filtrados por regional, divisão e segmento (mesma lógica dos executores)
  Future<List<Executor>> getCoordenadoresFiltrados({
    String? regionalId,
    String? divisaoId,
    String? segmentoId,
  }) async {
    try {
      print('🔍 DEBUG ExecutorService.getCoordenadoresFiltrados:');
      print('   regionalId: $regionalId');
      print('   divisaoId: $divisaoId');
      print('   segmentoId: $segmentoId');
      
      // Primeiro buscar executores filtrados pelo perfil
      List<Executor> executores = await getExecutoresFiltrados(
        regionalId: regionalId,
        divisaoId: divisaoId,
        segmentoId: segmentoId,
      );
      
      print('   Executores filtrados pelo perfil: ${executores.length}');
      
      // Depois filtrar apenas os que são coordenadores ou gerentes
      final coordenadores = executores.where((executor) {
        if (executor.funcao == null || executor.funcao!.isEmpty) {
          return false;
        }
        final funcaoUpper = executor.funcao!.toUpperCase();
        return funcaoUpper.contains('COORDENADOR') || funcaoUpper.contains('GERENTE');
      }).toList();
      
      print('✅ DEBUG ExecutorService.getCoordenadoresFiltrados: ${coordenadores.length} coordenadores após filtro de função');
      for (var coord in coordenadores) {
        print('   - ${coord.nomeCompleto ?? coord.nome} (${coord.funcao})');
      }
      
      return coordenadores;
    } catch (e, stackTrace) {
      print('❌ Erro ao buscar coordenadores filtrados: $e');
      print('   Stack trace: $stackTrace');
      return [];
    }
  }

  // Buscar executores por login (case-insensitive) - OTIMIZADO
  // Retorna apenas id, nome e login para melhor performance
  Future<List<Executor>> getExecutoresPorLogin(String login) async {
    try {
      if (login.isEmpty) return [];
      
      final loginLower = login.toLowerCase().trim();
      
      // Se offline, buscar do banco local
      if (!_connectivity.isConnected) {
        final db = await _localDb.database;
        final localExecutores = await db.query(
          'executores_local',
          columns: ['id', 'nome', 'nome_completo', 'login'],
          where: 'ativo = ?',
          whereArgs: [1],
        );
        
        // Filtrar localmente por login (case-insensitive)
        final filtrados = localExecutores.where((row) {
          final executorLogin = (row['login'] as String? ?? '').toLowerCase().trim();
          return executorLogin == loginLower;
        }).toList();
        
        return filtrados.map((map) {
          return Executor(
            id: map['id'] as String,
            nome: map['nome'] as String? ?? '',
            nomeCompleto: map['nome_completo'] as String?,
            login: map['login'] as String?,
            ativo: true,
          );
        }).toList();
      }
      
      // Buscar online - query otimizada apenas com campos essenciais
      try {
        // Buscar apenas campos essenciais sem joins pesados
        final response = await _supabase
            .from('executores')
            .select('id, nome, nome_completo, login')
            .eq('ativo', true)
            .timeout(
              const Duration(seconds: 5),
              onTimeout: () {
                print('⚠️ Timeout ao buscar executores por login');
                return <Map<String, dynamic>>[];
              },
            );

        if (response.isEmpty) {
          return [];
        }

        // Filtrar por login case-insensitive localmente
        final executoresFiltrados = (response as List).where((map) {
          final executorLogin = (map['login'] as String? ?? '').toLowerCase().trim();
          return executorLogin == loginLower;
        }).toList();

        return executoresFiltrados.map((map) {
          return Executor(
            id: map['id'] as String,
            nome: map['nome'] as String? ?? '',
            nomeCompleto: map['nome_completo'] as String?,
            login: map['login'] as String?,
            ativo: true,
          );
        }).toList();
      } catch (e) {
        print('⚠️ Erro ao buscar executores por login online: $e');
        // Tentar buscar do banco local como fallback
        final db = await _localDb.database;
        final allLocalExecutores = await db.query(
          'executores_local',
          columns: ['id', 'nome', 'nome_completo', 'login'],
          where: 'ativo = ?',
          whereArgs: [1],
        );
        final localExecutores = allLocalExecutores.where((row) {
          final login = (row['login'] as String? ?? '').toLowerCase().trim();
          return login == loginLower;
        }).toList();
        
        return localExecutores.map((map) {
          return Executor(
            id: map['id'] as String,
            nome: map['nome'] as String? ?? '',
            nomeCompleto: map['nome_completo'] as String?,
            login: map['login'] as String?,
            ativo: true,
          );
        }).toList();
      }
    } catch (e) {
      print('Erro ao buscar executores por login: $e');
      return [];
    }
  }

  // Verificar se o executor do login é COORDENADOR ou GERENTE
  Future<bool> isCoordenadorOuGerentePorLogin(String login) async {
    try {
      if (login.isEmpty) return false;
      final loginLower = login.toLowerCase().trim();

      // Se offline, negar acesso por segurança
      if (!_connectivity.isConnected) {
        print('⚠️ Sem conexão para validar função do executor. Acesso negado.');
        return false;
      }

      final response = await _supabase
          .from('executores')
          .select('login, funcoes!left(funcao)')
          .eq('ativo', true)
          .ilike('login', loginLower)
          .maybeSingle()
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              print('⚠️ Timeout ao validar função do executor');
              return null;
            },
          );

      if (response == null) {
        print('⚠️ Executor não encontrado para login: $loginLower');
        return false;
      }

      String? funcao;
      final funcoesMap = response['funcoes'];
      if (funcoesMap is Map<String, dynamic>) {
        funcao = funcoesMap['funcao'] as String?;
      }

      if (funcao == null || funcao.isEmpty) {
        print('⚠️ Executor sem função definida para login: $loginLower');
        return false;
      }

      final funcaoUpper = funcao.toUpperCase();
      final permitido = funcaoUpper.contains('COORDENADOR') || funcaoUpper.contains('GERENTE');
      // debug silenciado
      return permitido;
    } catch (e, stackTrace) {
      print('❌ Erro ao validar função do executor por login: $e');
      print('   Stack trace: $stackTrace');
      return false;
    }
  }
}

