import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert' show latin1, utf8;
import '../models/si.dart';
import 'auth_service_simples.dart';
import 'centro_trabalho_service.dart';

class SIService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final AuthServiceSimples _authService = AuthServiceSimples();
  final CentroTrabalhoService _centroTrabalhoService = CentroTrabalhoService();

  // Importar SIs do CSV
  Future<Map<String, dynamic>> importarSIsDoCSV(String csvContent) async {
    try {
      final linhas = csvContent.split('\n');
      if (linhas.length < 5) {
        throw Exception('CSV inválido: menos de 5 linhas');
      }

      // Encontrar o cabeçalho (linha que contém "Solicitação" e "Tp")
      int linhaCabecalho = -1;
      for (int i = 0; i < linhas.length; i++) {
        final linha = linhas[i].trim();
        final linhaLower = linha.toLowerCase();
        if (linhaLower.contains('solicitação') && linhaLower.contains('tp')) {
          linhaCabecalho = i;
          print('📋 Cabeçalho encontrado na linha ${i + 1}');
          break;
        }
      }

      if (linhaCabecalho == -1) {
        throw Exception('Cabeçalho não encontrado no CSV. Procure por uma linha contendo "Solicitação" e "Tp"');
      }

      // Processar linhas de dados (após o separador do cabeçalho)
      final sis = <SI>[];
      int linhasProcessadas = 0;
      int linhasIgnoradas = 0;
      int duplicatas = 0;

      // Começar a processar após o cabeçalho, pulando linhas de separador
      int linhaInicioDados = linhaCabecalho + 1;
      while (linhaInicioDados < linhas.length) {
        final linha = linhas[linhaInicioDados].trim();
        if (linha.isNotEmpty && 
            linha.contains('|') &&
            linha.replaceAll('|', '').replaceAll('-', '').replaceAll(' ', '').replaceAll('_', '').isNotEmpty) {
          break;
        }
        linhaInicioDados++;
      }
      
      print('📋 Iniciando processamento de dados a partir da linha ${linhaInicioDados + 1}');

      for (int i = linhaInicioDados; i < linhas.length; i++) {
        final linha = linhas[i].trim();
        if (linha.isEmpty || linha.startsWith('-')) continue;

        try {
          final si = _parseLinhaCSV(linha);
          if (si != null && si.solicitacao.isNotEmpty) {
            try {
              // Verificar se o SI já existe
              final existe = await _siExiste(si.solicitacao);
              if (existe) {
                duplicatas++;
                continue;
              }
              sis.add(si);
              linhasProcessadas++;
            } catch (e) {
              print('⚠️ Erro ao verificar/processar SI na linha ${i + 1}: $e');
              linhasIgnoradas++;
            }
          } else {
            linhasIgnoradas++;
          }
        } catch (e, stackTrace) {
          print('⚠️ Erro ao processar linha ${i + 1}: $e');
          print('   Stack trace: $stackTrace');
          linhasIgnoradas++;
        }
      }

      // Inserir SIs no banco
      if (sis.isNotEmpty) {
        print('💾 Inserindo ${sis.length} SIs no banco de dados...');
        try {
          await _supabase.from('sis').select('id').limit(1);
          print('✅ Conexão com banco de dados OK');
        } catch (e) {
          print('❌ Erro ao testar conexão com banco: $e');
          throw Exception('Erro de conexão com banco de dados: $e');
        }
        
        await _inserirSIs(sis);
        print('✅ ${sis.length} SIs inseridos com sucesso!');
      } else {
        print('⚠️ Nenhum SI válido para inserir');
      }

      print('📊 Resumo da importação:');
      print('   - Linhas processadas: $linhasProcessadas');
      print('   - SIs importados: ${sis.length}');
      print('   - Duplicatas ignoradas: $duplicatas');
      print('   - Linhas ignoradas: $linhasIgnoradas');

      return {
        'sucesso': true,
        'total': linhasProcessadas,
        'duplicatas': duplicatas,
        'ignoradas': linhasIgnoradas,
        'importadas': sis.length,
      };
    } catch (e) {
      print('❌ Erro ao importar CSV: $e');
      return {
        'sucesso': false,
        'erro': e.toString(),
      };
    }
  }

  // Parse de uma linha do CSV
  SI? _parseLinhaCSV(String linha) {
    try {
      if (linha.trim().isEmpty || 
          linha.replaceAll('|', '').replaceAll('-', '').replaceAll(' ', '').replaceAll('_', '').isEmpty ||
          linha.toLowerCase().contains('solicitação') && linha.toLowerCase().contains('tp')) {
        return null;
      }

      // O CSV usa pipes (|) como delimitadores
      final partes = linha.split('|');
      if (partes.length < 2) {
        return null;
      }

      // Remover espaços e limpar
      final valores = partes.map((p) {
        String trimmed = p.trim();
        if (trimmed.contains('')) {
          try {
            final bytes = latin1.encode(trimmed);
            trimmed = utf8.decode(bytes, allowMalformed: true);
          } catch (e) {
            // Se falhar, manter o original
          }
        }
        return trimmed;
      }).toList();

      return SI.fromCSVParts(valores);
    } catch (e) {
      print('⚠️ Erro ao parsear linha CSV: $e');
      return null;
    }
  }

  // Verificar se um SI já existe
  Future<bool> _siExiste(String solicitacao) async {
    try {
      final response = await _supabase
          .from('sis')
          .select('id')
          .eq('solicitacao', solicitacao)
          .maybeSingle();
      return response != null;
    } catch (e) {
      print('⚠️ Erro ao verificar se SI existe: $e');
      return false;
    }
  }

  // Sanitizar valores para Supabase
  dynamic _sanitizeForSupabase(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      // Remover caracteres de controle e limitar tamanho
      String cleaned = value.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
      if (cleaned.length > 10000) {
        cleaned = cleaned.substring(0, 10000);
      }
      return cleaned.isEmpty ? null : cleaned;
    }
    return value;
  }

  // Inserir SIs em lotes
  Future<void> _inserirSIs(List<SI> sis) async {
    const batchSize = 50;
    
    try {
      for (int i = 0; i < sis.length; i += batchSize) {
        final lote = sis.skip(i).take(batchSize).toList();
        final maps = lote.map((si) {
          final map = si.toMap();
          // Sanitizar todos os valores string
          return map.map((key, value) => MapEntry(key, _sanitizeForSupabase(value)));
        }).toList();

        try {
          await _supabase.from('sis').insert(maps);
          print('✅ Lote ${(i ~/ batchSize) + 1} inserido: ${lote.length} SIs');
        } catch (e, stackTrace) {
          print('❌ Erro ao inserir lote ${(i ~/ batchSize) + 1}: $e');
          print('   Stack trace: $stackTrace');
          // Tentar inserir individualmente
          for (final si in lote) {
            try {
              final map = si.toMap();
              final sanitized = map.map((key, value) => MapEntry(key, _sanitizeForSupabase(value)));
              await _supabase.from('sis').insert(sanitized);
            } catch (e2) {
              print('⚠️ Erro ao inserir SI ${si.solicitacao}: $e2');
            }
          }
        }
      }
    } catch (e, stackTrace) {
      print('❌ Erro crítico ao inserir SIs: $e');
      print('   Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Obter centros de trabalho do usuário baseado no perfil
  Future<List<String>> _obterCentrosTrabalhoUsuario() async {
    try {
      final usuario = _authService.currentUser;
      
      // Se não há usuário ou é root, retornar lista vazia (sem filtro)
      if (usuario == null || usuario.isRoot) {
        return [];
      }

      // Se não tem perfil configurado, retornar lista vazia (sem filtro)
      if (!usuario.temPerfilConfigurado()) {
        return [];
      }

      // Buscar todos os centros de trabalho
      final todosCentros = await _centroTrabalhoService.getAllCentrosTrabalho();
      
      // Filtrar centros de trabalho baseado no perfil do usuário
      final centrosPermitidos = todosCentros.where((centro) {
        // Verificar se o centro pertence a uma regional permitida
        final temRegionalPermitida = usuario.regionalIds.isEmpty || 
            usuario.regionalIds.contains(centro.regionalId);
        
        // Verificar se o centro pertence a uma divisão permitida
        final temDivisaoPermitida = usuario.divisaoIds.isEmpty || 
            usuario.divisaoIds.contains(centro.divisaoId);
        
        // Verificar se o centro pertence a um segmento permitido
        final temSegmentoPermitido = usuario.segmentoIds.isEmpty || 
            usuario.segmentoIds.contains(centro.segmentoId);
        
        return temRegionalPermitida && temDivisaoPermitida && temSegmentoPermitido;
      }).map((centro) => centro.centroTrabalho).toList();

      return centrosPermitidos;
    } catch (e) {
      print('⚠️ Erro ao obter centros de trabalho do usuário: $e');
      return [];
    }
  }

  // Buscar todas as SIs com filtros e paginação (filtros aceitam múltiplos valores)
  Future<List<SI>> getAllSIs({
    List<String>? filtroStatus,
    List<String>? filtroLocal,
    List<String>? filtroStatusUsuario,
    DateTime? dataInicio,
    DateTime? dataFim,
    int? limit,
    int? offset,
  }) async {
    try {
      dynamic query = _supabase.from('sis_com_local').select();

      // Aplicar filtro por centro de trabalho do usuário
      final centrosTrabalhoUsuario = await _obterCentrosTrabalhoUsuario();
      if (centrosTrabalhoUsuario.isNotEmpty) {
        if (centrosTrabalhoUsuario.length == 1) {
          query = query.eq('cntr_trab', centrosTrabalhoUsuario[0]);
        } else {
          final orConditions = centrosTrabalhoUsuario.map((centro) => 'cntr_trab.eq.$centro').join(',');
          query = query.or(orConditions);
        }
      } else {
        final usuario = _authService.currentUser;
        if (usuario != null && !usuario.isRoot && usuario.temPerfilConfigurado()) {
          return [];
        }
      }

      if (filtroStatus != null && filtroStatus.isNotEmpty) {
        if (filtroStatus.length == 1) {
          query = query.eq('status_sistema', filtroStatus.first);
        } else {
          query = query.inFilter('status_sistema', filtroStatus);
        }
      }

      if (filtroLocal != null && filtroLocal.isNotEmpty) {
        if (filtroLocal.length == 1) {
          query = query.or('local.ilike.%${filtroLocal.first}%,local_instalacao.ilike.%${filtroLocal.first}%');
        } else {
          final orParts = filtroLocal.map((v) => 'local.ilike.%$v%,local_instalacao.ilike.%$v%').toList();
          query = query.or(orParts.join(','));
        }
      }

      if (filtroStatusUsuario != null && filtroStatusUsuario.isNotEmpty) {
        if (filtroStatusUsuario.length == 1) {
          query = query.eq('status_usuario', filtroStatusUsuario.first);
        } else {
          query = query.inFilter('status_usuario', filtroStatusUsuario);
        }
      }

      if (dataInicio != null) {
        query = query.gte('data_inicio', dataInicio.toIso8601String().split('T')[0]);
      }

      if (dataFim != null) {
        query = query.lte('data_fim', dataFim.toIso8601String().split('T')[0]);
      }

      query = query.order('created_at', ascending: false);

      if (limit != null) {
        query = query.limit(limit);
      }

      if (offset != null) {
        query = query.range(offset, offset + (limit ?? 100) - 1);
      }

      final response = await query;
      return (response as List).map((map) => SI.fromMap(map)).toList();
    } catch (e) {
      print('❌ Erro ao buscar SIs: $e');
      return [];
    }
  }

  // Buscar todas as SIs sem paginação (para estatísticas)
  Future<List<SI>> getAllSIsSemPaginacao() async {
    try {
      dynamic query = _supabase.from('sis').select();

      // Aplicar filtro por centro de trabalho do usuário
      final centrosTrabalhoUsuario = await _obterCentrosTrabalhoUsuario();
      if (centrosTrabalhoUsuario.isNotEmpty) {
        if (centrosTrabalhoUsuario.length == 1) {
          query = query.eq('cntr_trab', centrosTrabalhoUsuario[0]);
        } else {
          final orConditions = centrosTrabalhoUsuario.map((centro) => 'cntr_trab.eq.$centro').join(',');
          query = query.or(orConditions);
        }
      } else {
        final usuario = _authService.currentUser;
        if (usuario != null && !usuario.isRoot && usuario.temPerfilConfigurado()) {
          return [];
        }
      }

      query = query.order('created_at', ascending: false);

      final response = await query;
      return (response as List).map((map) => SI.fromMap(map)).toList();
    } catch (e) {
      print('❌ Erro ao buscar todas as SIs: $e');
      return [];
    }
  }

  // Contar SIs (filtros aceitam múltiplos valores)
  Future<int> contarSIs({
    List<String>? filtroStatus,
    List<String>? filtroLocal,
    List<String>? filtroStatusUsuario,
    DateTime? dataInicio,
    DateTime? dataFim,
  }) async {
    try {
      dynamic query = _supabase.from('sis_com_local').select('id');

      // Aplicar filtro por centro de trabalho do usuário
      final centrosTrabalhoUsuario = await _obterCentrosTrabalhoUsuario();
      if (centrosTrabalhoUsuario.isNotEmpty) {
        if (centrosTrabalhoUsuario.length == 1) {
          query = query.eq('cntr_trab', centrosTrabalhoUsuario[0]);
        } else {
          final orConditions = centrosTrabalhoUsuario.map((centro) => 'cntr_trab.eq.$centro').join(',');
          query = query.or(orConditions);
        }
      } else {
        final usuario = _authService.currentUser;
        if (usuario != null && !usuario.isRoot && usuario.temPerfilConfigurado()) {
          return 0;
        }
      }

      if (filtroStatus != null && filtroStatus.isNotEmpty) {
        if (filtroStatus.length == 1) {
          query = query.eq('status_sistema', filtroStatus.first);
        } else {
          query = query.inFilter('status_sistema', filtroStatus);
        }
      }

      if (filtroLocal != null && filtroLocal.isNotEmpty) {
        if (filtroLocal.length == 1) {
          query = query.or('local.ilike.%${filtroLocal.first}%,local_instalacao.ilike.%${filtroLocal.first}%');
        } else {
          final orParts = filtroLocal.map((v) => 'local.ilike.%$v%,local_instalacao.ilike.%$v%').toList();
          query = query.or(orParts.join(','));
        }
      }

      if (filtroStatusUsuario != null && filtroStatusUsuario.isNotEmpty) {
        if (filtroStatusUsuario.length == 1) {
          query = query.eq('status_usuario', filtroStatusUsuario.first);
        } else {
          query = query.inFilter('status_usuario', filtroStatusUsuario);
        }
      }

      if (dataInicio != null) {
        query = query.gte('data_inicio', dataInicio.toIso8601String().split('T')[0]);
      }

      if (dataFim != null) {
        query = query.lte('data_fim', dataFim.toIso8601String().split('T')[0]);
      }

      final response = await query;
      return (response as List).length;
    } catch (e) {
      print('❌ Erro ao contar SIs: $e');
      return 0;
    }
  }

  // Buscar valores únicos para filtros
  Future<Map<String, List<String>>> getValoresFiltros() async {
    try {
      dynamic query = _supabase.from('sis_com_local').select('status_sistema, local, local_instalacao, status_usuario');

      // Aplicar filtro por centro de trabalho do usuário
      final centrosTrabalhoUsuario = await _obterCentrosTrabalhoUsuario();
      if (centrosTrabalhoUsuario.isNotEmpty) {
        if (centrosTrabalhoUsuario.length == 1) {
          query = query.eq('cntr_trab', centrosTrabalhoUsuario[0]);
        } else {
          final orConditions = centrosTrabalhoUsuario.map((centro) => 'cntr_trab.eq.$centro').join(',');
          query = query.or(orConditions);
        }
      } else {
        final usuario = _authService.currentUser;
        if (usuario != null && !usuario.isRoot && usuario.temPerfilConfigurado()) {
          return {
            'status': [],
            'local': [],
            'statusUsuario': [],
          };
        }
      }

      final response = await query;
      final statusSet = <String>{};
      final localSet = <String>{};
      final statusUsuarioSet = <String>{};

      for (var item in response) {
        if (item['status_sistema'] != null) {
          statusSet.add(item['status_sistema'] as String);
        }
        final localView = item['local'] as String?;
        final localInst = item['local_instalacao'] as String?;
        final chosenLocal = (localView != null && localView.isNotEmpty)
            ? localView
            : (localInst ?? '');
        if (chosenLocal.isNotEmpty) {
          localSet.add(chosenLocal);
        }
        if (item['status_usuario'] != null) {
          statusUsuarioSet.add(item['status_usuario'] as String);
        }
      }

      return {
        'status': statusSet.toList()..sort(),
        'local': localSet.toList()..sort(),
        'statusUsuario': statusUsuarioSet.toList()..sort(),
      };
    } catch (e) {
      print('❌ Erro ao buscar valores de filtros: $e');
      return {
        'status': [],
        'local': [],
        'statusUsuario': [],
      };
    }
  }

  // Buscar SI por ID
  Future<SI?> getSIById(String id) async {
    try {
      final response = await _supabase
          .from('sis_com_local')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (response == null) return null;
      return SI.fromMap(response);
    } catch (e) {
      print('❌ Erro ao buscar SI: $e');
      return null;
    }
  }

  // Buscar SI por solicitação
  Future<SI?> getSIPorSolicitacao(String solicitacao) async {
    try {
      final response = await _supabase
          .from('sis_com_local')
          .select()
          .eq('solicitacao', solicitacao)
          .maybeSingle();
      if (response == null) return null;
      return SI.fromMap(response);
    } catch (e) {
      print('❌ Erro ao buscar SI por solicitação: $e');
      return null;
    }
  }

  // Vincular SI a uma tarefa
  Future<void> vincularSITarefa(String taskId, String siId) async {
    try {
      await _supabase.from('tasks_sis').insert({
        'task_id': taskId,
        'si_id': siId,
      });
    } catch (e) {
      print('❌ Erro ao vincular SI a tarefa: $e');
      rethrow;
    }
  }

  // Desvincular SI de uma tarefa
  Future<void> desvincularSITarefa(String taskId, String siId) async {
    try {
      await _supabase
          .from('tasks_sis')
          .delete()
          .eq('task_id', taskId)
          .eq('si_id', siId);
    } catch (e) {
      print('❌ Erro ao desvincular SI de tarefa: $e');
      rethrow;
    }
  }

  // Contar SIs vinculadas por tarefas
  Future<Map<String, int>> contarSIsPorTarefas(List<String> taskIds) async {
    try {
      if (taskIds.isEmpty) return {};

      // Usar VIEW otimizada do Supabase para buscar todas as contagens de uma vez
      // Usar .or() para múltiplos valores (já funciona no código)
      dynamic query = _supabase
          .from('contagens_sis_tarefas')
          .select('task_id, quantidade');
      
      if (taskIds.length == 1) {
        query = query.eq('task_id', taskIds[0]);
      } else {
        final orConditions = taskIds.map((id) => 'task_id.eq.$id').join(',');
        query = query.or(orConditions);
      }
      
      final response = await query;

      final contagens = <String, int>{};
      for (var item in response) {
        final taskId = item['task_id'] as String;
        final quantidade = item['quantidade'] as int;
        if (quantidade > 0) {
          contagens[taskId] = quantidade;
        }
      }

      return contagens;
    } catch (e) {
      print('❌ Erro ao contar SIs das tarefas: $e');
      return {};
    }
  }

  // Buscar SIs vinculadas a uma tarefa
  Future<List<SI>> getSIsPorTarefa(String taskId) async {
    try {
      final response = await _supabase
          .from('tasks_sis')
          .select('sis(*)')
          .eq('task_id', taskId);

      // Log removido para evitar problemas de encoding UTF-8

      if ((response as List).isEmpty) {
        return [];
      }

      return (response as List)
          .map((item) {
            // Log removido para evitar problemas de encoding UTF-8
            if (item is Map<String, dynamic> && item.containsKey('sis')) {
              final siData = item['sis'];
              // Log removido para evitar problemas de encoding UTF-8
              if (siData is Map<String, dynamic>) {
                return SI.fromMap(siData);
              } else {
                print('⚠️ getSIsPorTarefa - SI data não é Map: ${siData.runtimeType}');
                return null;
              }
            } else {
              print('⚠️ getSIsPorTarefa - Item não contém "sis": ${item.keys}');
              return null;
            }
          })
          .whereType<SI>()
          .toList();
    } catch (e, stackTrace) {
      print('❌ Erro ao buscar SIs da tarefa: $e');
      print('❌ Stack trace: $stackTrace');
      return [];
    }
  }

  // Buscar tarefas vinculadas a um SI
  Future<List<String>> getTarefasPorSI(String siId) async {
    try {
      final response = await _supabase
          .from('tasks_sis')
          .select('task_id')
          .eq('si_id', siId);

      return (response as List).map((item) => item['task_id'] as String).toList();
    } catch (e) {
      print('❌ Erro ao buscar tarefas do SI: $e');
      return [];
    }
  }

  // Buscar SIs programadas (vinculadas a tarefas) com informações das tarefas
  Future<List<Map<String, dynamic>>> getSIsProgramadas() async {
    try {
      final centrosTrabalhoUsuario = await _obterCentrosTrabalhoUsuario();
      
      dynamic query = _supabase.from('tasks_sis').select('''
            id,
            created_at,
            sis(
              *,
              cntr_trab
            ),
            tasks(
              id,
              tarefa,
              status,
              data_inicio,
              data_fim,
              regional,
              divisao,
              local,
              tipo,
              ordem
            )
          ''');

      query = query.order('created_at', ascending: false);
      final response = await query;

      // Filtrar no código por centro de trabalho
      List<dynamic> filteredResponse = response as List;
      if (centrosTrabalhoUsuario.isNotEmpty) {
        filteredResponse = filteredResponse.where((item) {
          final si = item['sis'] as Map<String, dynamic>?;
          if (si == null) return false;
          final centroTrabalho = si['cntr_trab'] as String?;
          return centroTrabalho != null && centrosTrabalhoUsuario.contains(centroTrabalho);
        }).toList();
      } else {
        final usuario = _authService.currentUser;
        if (usuario != null && !usuario.isRoot && usuario.temPerfilConfigurado()) {
          return [];
        }
      }

      return filteredResponse.map((item) {
        return {
          'vinculo_id': item['id'],
          'vinculado_em': item['created_at'] != null 
              ? DateTime.parse(item['created_at'])
              : null,
          'si': SI.fromMap(item['sis'] as Map<String, dynamic>),
          'tarefa': item['tasks'],
        };
      }).toList();
    } catch (e) {
      print('❌ Erro ao buscar SIs programadas: $e');
      return [];
    }
  }
}
