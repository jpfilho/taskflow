import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert' show latin1, utf8;
import '../models/at.dart';
import 'auth_service_simples.dart';
import 'centro_trabalho_service.dart';

class ATService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final AuthServiceSimples _authService = AuthServiceSimples();
  final CentroTrabalhoService _centroTrabalhoService = CentroTrabalhoService();

  // Importar ATs do CSV
  Future<Map<String, dynamic>> importarATsDoCSV(String csvContent) async {
    try {
      final linhas = csvContent.split('\n');
      if (linhas.length < 5) {
        throw Exception('CSV inválido: menos de 5 linhas');
      }

      // Encontrar o cabeçalho (linha que contém "AutorzTrab" e "Edificação")
      int linhaCabecalho = -1;
      for (int i = 0; i < linhas.length; i++) {
        final linha = linhas[i].trim();
        final linhaLower = linha.toLowerCase();
        if (linhaLower.contains('autorztrab') &&
            linhaLower.contains('edificação')) {
          linhaCabecalho = i;
          print('📋 Cabeçalho encontrado na linha ${i + 1}');
          break;
        }
      }

      if (linhaCabecalho == -1) {
        throw Exception(
          'Cabeçalho não encontrado no CSV. Procure por uma linha contendo "AutorzTrab" e "Edificação"',
        );
      }

      // Processar linhas de dados (após o separador do cabeçalho)
      final ats = <AT>[];
      int linhasProcessadas = 0;
      int linhasIgnoradas = 0;
      int duplicatas = 0;

      // Começar a processar após o cabeçalho, pulando linhas de separador
      int linhaInicioDados = linhaCabecalho + 1;
      while (linhaInicioDados < linhas.length) {
        final linha = linhas[linhaInicioDados].trim();
        if (linha.isNotEmpty &&
            linha.contains('|') &&
            linha
                .replaceAll('|', '')
                .replaceAll('-', '')
                .replaceAll(' ', '')
                .replaceAll('_', '')
                .isNotEmpty) {
          break;
        }
        linhaInicioDados++;
      }

      print(
        '📋 Iniciando processamento de dados a partir da linha ${linhaInicioDados + 1}',
      );

      for (int i = linhaInicioDados; i < linhas.length; i++) {
        final linha = linhas[i].trim();
        if (linha.isEmpty || linha.startsWith('-')) continue;

        try {
          final at = _parseLinhaCSV(linha);
          if (at != null && at.autorzTrab.isNotEmpty) {
            try {
              // Verificar se a AT já existe
              final existe = await _atExiste(at.autorzTrab);
              if (existe) {
                duplicatas++;
                continue;
              }
              ats.add(at);
              linhasProcessadas++;
            } catch (e) {
              print('⚠️ Erro ao verificar/processar AT na linha ${i + 1}: $e');
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

      // Inserir ATs no banco
      if (ats.isNotEmpty) {
        print('💾 Inserindo ${ats.length} ATs no banco de dados...');
        try {
          await _supabase.from('ats').select('id').limit(1);
          print('✅ Conexão com banco de dados OK');
        } catch (e) {
          print('❌ Erro ao testar conexão com banco: $e');
          throw Exception('Erro de conexão com banco de dados: $e');
        }

        await _inserirATs(ats);
        print('✅ ${ats.length} ATs inseridas com sucesso!');
      } else {
        print('⚠️ Nenhuma AT válida para inserir');
      }

      print('📊 Resumo da importação:');
      print('   - Linhas processadas: $linhasProcessadas');
      print('   - ATs importadas: ${ats.length}');
      print('   - Duplicatas ignoradas: $duplicatas');
      print('   - Linhas ignoradas: $linhasIgnoradas');

      return {
        'sucesso': true,
        'total': linhasProcessadas,
        'duplicatas': duplicatas,
        'ignoradas': linhasIgnoradas,
        'importadas': ats.length,
      };
    } catch (e) {
      print('❌ Erro ao importar CSV: $e');
      return {'sucesso': false, 'erro': e.toString()};
    }
  }

  // Parse de uma linha do CSV
  AT? _parseLinhaCSV(String linha) {
    try {
      if (linha.trim().isEmpty ||
          linha
              .replaceAll('|', '')
              .replaceAll('-', '')
              .replaceAll(' ', '')
              .replaceAll('_', '')
              .isEmpty ||
          linha.toLowerCase().contains('autorztrab') &&
              linha.toLowerCase().contains('edificação')) {
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

      // Validar que pelo menos a AT não está vazia
      if (valores.length < 2 || valores[1].isEmpty) {
        return null;
      }

      try {
        return AT.fromCSVParts(valores);
      } catch (e) {
        print('⚠️ Erro ao criar objeto AT: $e');
        return null;
      }
    } catch (e) {
      print('⚠️ Erro ao parsear linha CSV: $e');
      return null;
    }
  }

  // Verificar se uma AT já existe
  Future<bool> _atExiste(String autorzTrab) async {
    try {
      if (autorzTrab.isEmpty) return false;
      final response = await _supabase
          .from('ats')
          .select('id')
          .eq('autorz_trab', autorzTrab)
          .limit(1)
          .maybeSingle();
      return response != null;
    } catch (e) {
      print('⚠️ Erro ao verificar se AT existe: $e');
      return false;
    }
  }

  // Sanitizar valores para Supabase
  dynamic _sanitizeForSupabase(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      String cleaned = value.replaceAll(
        RegExp(r'[\x00-\x08\x0B-\x0C\x0E-\x1F\x7F]'),
        '',
      );
      try {
        final utf8Bytes = utf8.encode(cleaned);
        final verified = utf8.decode(utf8Bytes);
        return verified;
      } catch (e) {
        return cleaned;
      }
    }
    return value;
  }

  // Inserir ATs em lotes
  Future<void> _inserirATs(List<AT> ats) async {
    const batchSize = 50;

    try {
      for (int i = 0; i < ats.length; i += batchSize) {
        final lote = ats.skip(i).take(batchSize).toList();
        final maps = lote.map((at) {
          final map = at.toMap();
          // Sanitizar todos os valores string
          return map.map(
            (key, value) => MapEntry(key, _sanitizeForSupabase(value)),
          );
        }).toList();

        try {
          await _supabase.from('ats').insert(maps);
          print('✅ Lote ${(i ~/ batchSize) + 1} inserido: ${lote.length} ATs');
        } catch (e, stackTrace) {
          print('❌ Erro ao inserir lote ${(i ~/ batchSize) + 1}: $e');
          print('   Stack trace: $stackTrace');
          // Tentar inserir individualmente
          for (final at in lote) {
            try {
              final map = at.toMap();
              final sanitized = map.map(
                (key, value) => MapEntry(key, _sanitizeForSupabase(value)),
              );
              await _supabase.from('ats').insert(sanitized);
            } catch (e2) {
              print('⚠️ Erro ao inserir AT ${at.autorzTrab}: $e2');
            }
          }
        }
      }
    } catch (e, stackTrace) {
      print('❌ Erro crítico ao inserir ATs: $e');
      print('   Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Obter centros de trabalho do usuário baseado no perfil
  Future<List<String>> _obterCentrosTrabalhoUsuario() async {
    try {
      final usuario = _authService.currentUser;

      print('🔍 DEBUG _obterCentrosTrabalhoUsuario:');
      print('   Usuário: ${usuario?.email}');
      print('   isRoot: ${usuario?.isRoot}');

      // Se não há usuário ou é root, retornar lista vazia (sem filtro)
      if (usuario == null || usuario.isRoot) {
        print('   → Retornando lista vazia (root ou sem usuário)');
        return [];
      }

      // Se não tem perfil configurado, retornar lista vazia (sem filtro)
      if (!usuario.temPerfilConfigurado()) {
        print('   → Retornando lista vazia (sem perfil configurado)');
        return [];
      }

      print('   Perfil do usuário:');
      print('   - Regional IDs: ${usuario.regionalIds}');
      print('   - Divisão IDs: ${usuario.divisaoIds}');
      print('   - Segmento IDs: ${usuario.segmentoIds}');

      // Buscar todos os centros de trabalho
      final todosCentros = await _centroTrabalhoService.getAllCentrosTrabalho();
      print(
        '   Total de centros de trabalho no sistema: ${todosCentros.length}',
      );

      // DEBUG: Verificar se existe centro "MNSE.TSA"
      final centroMNSE = todosCentros
          .where((c) => c.centroTrabalho.contains('MNSE'))
          .toList();
      if (centroMNSE.isNotEmpty) {
        print('   🔍 Centros encontrados com "MNSE":');
        for (var c in centroMNSE) {
          print(
            '      - ${c.centroTrabalho} (Regional: ${c.regional}, Divisão: ${c.divisao}, Segmento: ${c.segmento})',
          );
        }
      }

      // Filtrar centros de trabalho baseado no perfil do usuário
      final centrosPermitidos = todosCentros
          .where((centro) {
            // Verificar se o centro pertence a uma regional permitida
            final temRegionalPermitida =
                usuario.regionalIds.isEmpty ||
                usuario.regionalIds.contains(centro.regionalId);

            // Verificar se o centro pertence a uma divisão permitida
            final temDivisaoPermitida =
                usuario.divisaoIds.isEmpty ||
                usuario.divisaoIds.contains(centro.divisaoId);

            // Verificar se o centro pertence a um segmento permitido
            final temSegmentoPermitido =
                usuario.segmentoIds.isEmpty ||
                usuario.segmentoIds.contains(centro.segmentoId);

            final permitido =
                temRegionalPermitida &&
                temDivisaoPermitida &&
                temSegmentoPermitido;

            if (permitido) {
              print(
                '   ✅ Centro permitido: ${centro.centroTrabalho} (${centro.regional}/${centro.divisao}/${centro.segmento})',
              );
            }

            return permitido;
          })
          .map((centro) => centro.centroTrabalho)
          .toList();

      print('🔍 Centros de trabalho do usuário: ${centrosPermitidos.length}');
      print('   Centros: $centrosPermitidos');

      // DEBUG: Verificar se há ATs com esses centros de trabalho no banco
      if (centrosPermitidos.isNotEmpty) {
        try {
          // Buscar algumas ATs com esses centros de trabalho para debug
          if (centrosPermitidos.length == 1) {
            final response = await _supabase
                .from('ats')
                .select('id, autorz_trab, cntr_trab')
                .eq('cntr_trab', centrosPermitidos[0])
                .limit(5);
            print(
              '   🔍 ATs no banco com cntr_trab="${centrosPermitidos[0]}": ${(response as List).length}',
            );
            if ((response as List).isNotEmpty) {
              print('   Primeiras ATs encontradas:');
              for (var at in response as List) {
                print(
                  '      - ${at['autorz_trab']}: cntr_trab="${at['cntr_trab']}"',
                );
              }
            }
          }
        } catch (e) {
          print('   ⚠️ Erro ao verificar ATs no banco: $e');
        }
      }

      return centrosPermitidos;
    } catch (e) {
      print('⚠️ Erro ao obter centros de trabalho do usuário: $e');
      return [];
    }
  }

  // Buscar todas as ATs com filtros e paginação (filtros aceitam múltiplos valores)
  Future<List<AT>> getAllATs({
    List<String>? filtroStatus,
    List<String>? filtroLocal,
    List<String>? filtroStatusUsuario,
    DateTime? dataInicio,
    DateTime? dataFim,
    int? limit,
    int? offset,
  }) async {
    try {
      // Usar a view com local calculado
      dynamic query = _supabase.from('ats_com_local').select();

      // Aplicar filtro por centro de trabalho do usuário
      final centrosTrabalhoUsuario = await _obterCentrosTrabalhoUsuario();
      if (centrosTrabalhoUsuario.isNotEmpty) {
        // Filtrar ATs onde cntr_trab está na lista de centros de trabalho do usuário
        // Usar filtro OR para múltiplos valores
        if (centrosTrabalhoUsuario.length == 1) {
          query = query.eq('cntr_trab', centrosTrabalhoUsuario[0]);
        } else {
          // Para múltiplos valores, construir filtro OR
          final orConditions = centrosTrabalhoUsuario
              .map((centro) => 'cntr_trab.eq.$centro')
              .join(',');
          query = query.or(orConditions);
        }
        print(
          '🔒 Filtrando ATs por centros de trabalho: ${centrosTrabalhoUsuario.length} centros',
        );
        print('   Centros: $centrosTrabalhoUsuario');
      } else {
        final usuario = _authService.currentUser;
        if (usuario != null &&
            !usuario.isRoot &&
            usuario.temPerfilConfigurado()) {
          // Se o usuário tem perfil mas não tem centros de trabalho, não retornar nenhuma AT
          print(
            '⚠️ Usuário com perfil mas sem centros de trabalho - retornando lista vazia',
          );
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
          query = query.or(
            'local.ilike.%${filtroLocal.first}%,local_instalacao.ilike.%${filtroLocal.first}%',
          );
        } else {
          final orParts = filtroLocal
              .map((v) => 'local.ilike.%$v%,local_instalacao.ilike.%$v%')
              .toList();
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
        query = query.gte(
          'data_inicio',
          dataInicio.toIso8601String().split('T')[0],
        );
      }

      if (dataFim != null) {
        query = query.lte('data_fim', dataFim.toIso8601String().split('T')[0]);
      }

      query = query
          .order('data_inicio', ascending: true)
          .order('data_fim', ascending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      if (offset != null) {
        query = query.range(offset, offset + (limit ?? 100) - 1);
      }

      final response = await query;
      final ats = (response as List).map((map) => AT.fromMap(map)).toList();

      // DEBUG: Verificar valores de cntr_trab nas ATs retornadas
      print('📊 DEBUG getAllATs:');
      print('   Total de ATs retornadas: ${ats.length}');
      if (ats.isNotEmpty) {
        print('   Primeiras 5 ATs:');
        for (var i = 0; i < (ats.length > 5 ? 5 : ats.length); i++) {
          final at = ats[i];
          print('   - AT ${at.autorzTrab}: cntr_trab = "${at.cntrTrab}"');
        }
      }

      return ats;
    } catch (e, stackTrace) {
      print('❌ Erro ao buscar ATs: $e');
      print('   Stack trace: $stackTrace');
      return [];
    }
  }

  // Contar ATs com filtros (filtros aceitam múltiplos valores)
  Future<int> contarATs({
    List<String>? filtroStatus,
    List<String>? filtroLocal,
    List<String>? filtroStatusUsuario,
    DateTime? dataInicio,
    DateTime? dataFim,
  }) async {
    try {
      dynamic query = _supabase.from('ats').select('id');

      // Aplicar filtro por centro de trabalho do usuário
      final centrosTrabalhoUsuario = await _obterCentrosTrabalhoUsuario();
      if (centrosTrabalhoUsuario.isNotEmpty) {
        // Filtrar ATs onde cntr_trab está na lista de centros de trabalho do usuário
        // Usar filtro OR para múltiplos valores
        if (centrosTrabalhoUsuario.length == 1) {
          query = query.eq('cntr_trab', centrosTrabalhoUsuario[0]);
        } else {
          // Para múltiplos valores, construir filtro OR
          final orConditions = centrosTrabalhoUsuario
              .map((centro) => 'cntr_trab.eq.$centro')
              .join(',');
          query = query.or(orConditions);
        }
      } else {
        final usuario = _authService.currentUser;
        if (usuario != null &&
            !usuario.isRoot &&
            usuario.temPerfilConfigurado()) {
          // Se o usuário tem perfil mas não tem centros de trabalho, retornar 0
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
          query = query.ilike('local_instalacao', '%${filtroLocal.first}%');
        } else {
          final orParts = filtroLocal
              .map((v) => 'local_instalacao.ilike.%$v%')
              .toList();
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
        query = query.gte(
          'data_inicio',
          dataInicio.toIso8601String().split('T')[0],
        );
      }

      if (dataFim != null) {
        query = query.lte('data_fim', dataFim.toIso8601String().split('T')[0]);
      }

      final response = await query;
      return (response as List).length;
    } catch (e) {
      print('❌ Erro ao contar ATs: $e');
      // Fallback: buscar todas e contar
      try {
        final todas = await getAllATs(
          filtroStatus: filtroStatus,
          filtroLocal: filtroLocal,
          filtroStatusUsuario: filtroStatusUsuario,
          dataInicio: dataInicio,
          dataFim: dataFim,
        );
        return todas.length;
      } catch (e2) {
        return 0;
      }
    }
  }

  // Buscar valores únicos para filtros
  Future<Map<String, List<String>>> getValoresFiltros() async {
    try {
      dynamic query = _supabase
          .from('ats_com_local')
          .select('status_sistema, local, local_instalacao, status_usuario');

      // Aplicar filtro por centro de trabalho do usuário
      final centrosTrabalhoUsuario = await _obterCentrosTrabalhoUsuario();
      if (centrosTrabalhoUsuario.isNotEmpty) {
        // Filtrar ATs onde cntr_trab está na lista de centros de trabalho do usuário
        // Usar filtro OR para múltiplos valores
        if (centrosTrabalhoUsuario.length == 1) {
          query = query.eq('cntr_trab', centrosTrabalhoUsuario[0]);
        } else {
          // Para múltiplos valores, construir filtro OR
          final orConditions = centrosTrabalhoUsuario
              .map((centro) => 'cntr_trab.eq.$centro')
              .join(',');
          query = query.or(orConditions);
        }
      } else {
        final usuario = _authService.currentUser;
        if (usuario != null &&
            !usuario.isRoot &&
            usuario.temPerfilConfigurado()) {
          // Se o usuário tem perfil mas não tem centros de trabalho, retornar filtros vazios
          return {'status': [], 'local': [], 'statusUsuario': []};
        }
      }

      final response = await query;
      final statusSet = <String>{};
      final localSet = <String>{};
      final statusUsuarioSet = <String>{};

      for (final item in response as List) {
        final map = item as Map<String, dynamic>;
        if (map['status_sistema'] != null) {
          statusSet.add(map['status_sistema'] as String);
        }
        final localView = map['local'] as String?;
        final localInst = map['local_instalacao'] as String?;
        final chosenLocal = (localView != null && localView.isNotEmpty)
            ? localView
            : (localInst ?? '');
        if (chosenLocal.isNotEmpty) {
          localSet.add(chosenLocal);
        }
        if (map['status_usuario'] != null) {
          statusUsuarioSet.add(map['status_usuario'] as String);
        }
      }

      return {
        'status': statusSet.toList()..sort(),
        'local': localSet.toList()..sort(),
        'statusUsuario': statusUsuarioSet.toList()..sort(),
      };
    } catch (e) {
      print('❌ Erro ao buscar valores de filtros: $e');
      return {'status': [], 'local': [], 'statusUsuario': []};
    }
  }

  // Buscar todas as ATs sem paginação (para estatísticas)
  Future<List<AT>> getAllATsSemPaginacao() async {
    try {
      dynamic query = _supabase.from('ats_com_local').select();

      // Aplicar filtro por centro de trabalho do usuário
      final centrosTrabalhoUsuario = await _obterCentrosTrabalhoUsuario();
      if (centrosTrabalhoUsuario.isNotEmpty) {
        // Filtrar ATs onde cntr_trab está na lista de centros de trabalho do usuário
        // Usar filtro OR para múltiplos valores
        if (centrosTrabalhoUsuario.length == 1) {
          query = query.eq('cntr_trab', centrosTrabalhoUsuario[0]);
        } else {
          // Para múltiplos valores, construir filtro OR
          final orConditions = centrosTrabalhoUsuario
              .map((centro) => 'cntr_trab.eq.$centro')
              .join(',');
          query = query.or(orConditions);
        }
      } else {
        final usuario = _authService.currentUser;
        if (usuario != null &&
            !usuario.isRoot &&
            usuario.temPerfilConfigurado()) {
          // Se o usuário tem perfil mas não tem centros de trabalho, retornar lista vazia
          return [];
        }
      }

      query = query.order('data_inicio', ascending: false);
      final response = await query;

      return (response as List)
          .map((item) => AT.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ Erro ao buscar todas as ATs: $e');
      return [];
    }
  }

  // Vincular AT a uma tarefa
  Future<void> vincularATATarefa(String taskId, String atId) async {
    try {
      print('🔗 Iniciando vinculação de AT $atId à tarefa $taskId...');

      // Verificar se a tabela existe
      try {
        await _supabase.from('tasks_ats').select('id').limit(1);
        print('✅ Tabela tasks_ats existe e está acessível');
      } catch (e) {
        print('❌ ERRO: Tabela tasks_ats não existe ou não está acessível: $e');
        throw Exception(
          'Tabela tasks_ats não existe. Execute o script criar_tabela_tasks_at.sql no Supabase.',
        );
      }

      // Verificar se a AT existe
      final atExiste = await _supabase
          .from('ats')
          .select('id')
          .eq('id', atId)
          .maybeSingle();

      if (atExiste == null) {
        throw Exception('AT com ID $atId não encontrada');
      }
      print('✅ AT $atId existe no banco');

      // Verificar se a tarefa existe
      final tarefaExiste = await _supabase
          .from('tasks')
          .select('id')
          .eq('id', taskId)
          .maybeSingle();

      if (tarefaExiste == null) {
        throw Exception('Tarefa com ID $taskId não encontrada');
      }
      print('✅ Tarefa $taskId existe no banco');

      // Verificar se já está vinculada
      final vinculoExistente = await _supabase
          .from('tasks_ats')
          .select('id')
          .eq('task_id', taskId)
          .eq('at_id', atId)
          .maybeSingle();

      if (vinculoExistente != null) {
        print('ℹ️ AT já está vinculada a esta tarefa');
        return;
      }

      // Vincular a AT (VINCULAÇÃO PRINCIPAL)
      print('🔗 Inserindo vínculo na tabela tasks_ats...');
      try {
        final resultado = await _supabase.from('tasks_ats').insert({
          'task_id': taskId,
          'at_id': atId,
        }).select();

        print('✅ AT vinculada à tarefa. Resultado: $resultado');
      } catch (e) {
        print('❌ ERRO CRÍTICO ao inserir vínculo principal: $e');
        throw Exception('Erro ao vincular AT à tarefa: $e');
      }
    } catch (e, stackTrace) {
      print('❌ Erro ao vincular AT: $e');
      print('❌ Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Desvincular AT de uma tarefa
  Future<void> desvincularATDeTarefa(String taskId, String atId) async {
    try {
      await _supabase
          .from('tasks_ats')
          .delete()
          .eq('task_id', taskId)
          .eq('at_id', atId);
      print('✅ AT desvinculada da tarefa');
    } catch (e) {
      print('❌ Erro ao desvincular AT: $e');
      rethrow;
    }
  }

  // Contar ATs vinculadas por tarefas
  Future<Map<String, int>> contarATsPorTarefas(List<String> taskIds) async {
    try {
      if (taskIds.isEmpty) return {};

      // Usar VIEW otimizada do Supabase para buscar todas as contagens de uma vez
      // Usar .or() para múltiplos valores (já funciona no código)
      dynamic query = _supabase
          .from('contagens_ats_tarefas')
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
      print('❌ Erro ao contar ATs das tarefas: $e');
      return {};
    }
  }

  // Buscar ATs vinculadas a uma tarefa
  Future<List<AT>> getATsPorTarefa(String taskId) async {
    try {
      final response = await _supabase
          .from('tasks_ats')
          .select('ats(*)')
          .eq('task_id', taskId);

      return (response as List)
          .map((item) => AT.fromMap(item['ats'] as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ Erro ao buscar ATs da tarefa: $e');
      return [];
    }
  }

  // Buscar tarefas vinculadas a uma AT
  Future<List<String>> getTarefasPorAT(String atId) async {
    try {
      final response = await _supabase
          .from('tasks_ats')
          .select('task_id')
          .eq('at_id', atId);

      return (response as List)
          .map((item) => item['task_id'] as String)
          .toList();
    } catch (e) {
      print('❌ Erro ao buscar tarefas da AT: $e');
      return [];
    }
  }

  // Buscar ATs programadas (vinculadas a tarefas)
  Future<List<Map<String, dynamic>>> getATsProgramadas() async {
    try {
      // Aplicar filtro por centro de trabalho do usuário
      final centrosTrabalhoUsuario = await _obterCentrosTrabalhoUsuario();

      dynamic query = _supabase.from('tasks_ats').select('''
            id,
            created_at,
            ats (
              id,
              autorz_trab,
              texto_breve,
              local_instalacao,
              status_usuario,
              status_sistema,
              data_inicio,
              data_fim,
              cntr_trab
            ),
            tasks (
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

      // Filtrar no código se o usuário tem centros de trabalho
      List<dynamic> filteredResponse = response as List;
      print('📊 DEBUG getATsProgramadas:');
      print('   Total de vínculos retornados: ${filteredResponse.length}');

      if (centrosTrabalhoUsuario.isNotEmpty) {
        print('   Filtrando por centros de trabalho: $centrosTrabalhoUsuario');
        filteredResponse = filteredResponse.where((item) {
          final at = item['ats'] as Map<String, dynamic>?;
          if (at == null) {
            print('   ⚠️ Item sem AT');
            return false;
          }
          final cntrTrab = at['cntr_trab'] as String?;
          final autorzTrab = at['autorz_trab'] as String?;
          final permitido =
              cntrTrab != null && centrosTrabalhoUsuario.contains(cntrTrab);
          if (!permitido && autorzTrab != null) {
            print(
              '   ❌ AT $autorzTrab: cntr_trab="$cntrTrab" não está na lista permitida',
            );
          }
          return permitido;
        }).toList();
        print('   Total após filtro: ${filteredResponse.length}');
      } else {
        final usuario = _authService.currentUser;
        if (usuario != null &&
            !usuario.isRoot &&
            usuario.temPerfilConfigurado()) {
          // Se o usuário tem perfil mas não tem centros de trabalho, retornar lista vazia
          print('   ⚠️ Usuário com perfil mas sem centros de trabalho');
          return [];
        }
      }

      return filteredResponse.map((item) {
        return {
          'vinculo_id': item['id'],
          'vinculado_em': item['created_at'],
          'at': item['ats'],
          'tarefa': item['tasks'],
        };
      }).toList();
    } catch (e) {
      print('❌ Erro ao buscar ATs programadas: $e');
      return [];
    }
  }
}
