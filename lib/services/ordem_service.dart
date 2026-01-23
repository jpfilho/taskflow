import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert' show latin1, utf8;
import 'dart:async';
import '../models/ordem.dart';
import '../services/auth_service_simples.dart';
import '../services/centro_trabalho_service.dart';

class OrdemService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final AuthServiceSimples _authService = AuthServiceSimples();
  final CentroTrabalhoService _centroTrabalhoService = CentroTrabalhoService();

  // Importar ordens do CSV
  Future<Map<String, dynamic>> importarOrdensDoCSV(String csvContent) async {
    try {
      final linhas = csvContent.split('\n');
      if (linhas.length < 5) {
        throw Exception('CSV inválido: menos de 5 linhas');
      }

      // Encontrar o cabeçalho (linha que contém "Ordem" e "InícioBase" ou "Fim-base")
      // O cabeçalho pode não estar na primeira linha
      int linhaCabecalho = -1;
      for (int i = 0; i < linhas.length; i++) {
        final linha = linhas[i].trim();
        // Procurar por "Ordem" e ("InícioBase" ou "InícioBase" ou "Fim-base")
        // Normalizar para buscar sem acentos também
        final linhaLower = linha.toLowerCase();
        if (linhaLower.contains('ordem') && 
            (linhaLower.contains('início') || linhaLower.contains('iniciobase') || linhaLower.contains('fim-base') || linhaLower.contains('fim base'))) {
          linhaCabecalho = i;
          print('📋 Cabeçalho encontrado na linha ${i + 1}: ${linha.substring(0, linha.length > 100 ? 100 : linha.length)}...');
          break;
        }
      }

      if (linhaCabecalho == -1) {
        throw Exception('Cabeçalho não encontrado no CSV. Procure por uma linha contendo "Ordem" e "InícioBase" ou "Fim-base"');
      }

      // Processar linhas de dados (após o separador do cabeçalho)
      // Pular linhas de separador (que começam com |---- ou contêm apenas traços)
      final ordens = <Ordem>[];
      int linhasProcessadas = 0;
      int linhasIgnoradas = 0;
      int duplicatas = 0;

      // Começar a processar após o cabeçalho, pulando linhas de separador
      int linhaInicioDados = linhaCabecalho + 1;
      while (linhaInicioDados < linhas.length) {
        final linha = linhas[linhaInicioDados].trim();
        // Se a linha não é um separador (não começa com |---- ou contém apenas traços e pipes)
        // E contém pipes (delimitadores)
        if (linha.isNotEmpty && 
            linha.contains('|') &&
            !linha.replaceAll('|', '').replaceAll('-', '').replaceAll(' ', '').replaceAll('_', '').isEmpty) {
          break; // Encontrou a primeira linha de dados
        }
        linhaInicioDados++;
      }
      
      print('📋 Iniciando processamento de dados a partir da linha ${linhaInicioDados + 1}');

      for (int i = linhaInicioDados; i < linhas.length; i++) {
        final linha = linhas[i].trim();
        if (linha.isEmpty || linha.startsWith('-')) continue;

        try {
          final ordem = _parseLinhaCSV(linha);
          if (ordem != null && ordem.ordem.isNotEmpty) {
            try {
              // Verificar se a ordem já existe
              final existe = await _ordemExiste(ordem.ordem);
              if (existe) {
                duplicatas++;
                continue;
              }
              ordens.add(ordem);
              linhasProcessadas++;
            } catch (e) {
              print('⚠️ Erro ao verificar/processar ordem na linha ${i + 1}: $e');
              linhasIgnoradas++;
            }
          } else {
            linhasIgnoradas++;
          }
        } catch (e, stackTrace) {
          print('⚠️ Erro ao processar linha ${i + 1}: $e');
          print('   Stack trace: $stackTrace');
          linhasIgnoradas++;
          // Continuar processando as próximas linhas mesmo se uma falhar
        }
      }

      // Inserir ordens no banco
      if (ordens.isNotEmpty) {
        print('💾 Inserindo ${ordens.length} ordens no banco de dados...');
        try {
          // Testar conexão com o banco antes de inserir
          try {
            await _supabase
                .from('ordens')
                .select('id')
                .limit(1);
            print('✅ Conexão com banco de dados OK');
          } catch (e) {
            print('❌ Erro ao testar conexão com banco: $e');
            throw Exception('Erro de conexão com banco de dados: $e');
          }
          
          await _inserirOrdens(ordens);
          print('✅ ${ordens.length} ordens inseridas com sucesso!');
        } catch (e, stackTrace) {
          print('❌ Erro ao inserir ordens no banco: $e');
          print('   Stack trace: $stackTrace');
          throw Exception('Erro ao inserir ordens no banco de dados: $e');
        }
      } else {
        print('⚠️ Nenhuma ordem válida para inserir');
      }

      print('📊 Resumo da importação:');
      print('   - Linhas processadas: $linhasProcessadas');
      print('   - Ordens importadas: ${ordens.length}');
      print('   - Duplicatas ignoradas: $duplicatas');
      print('   - Linhas ignoradas: $linhasIgnoradas');

      return {
        'sucesso': true,
        'total': linhasProcessadas,
        'duplicatas': duplicatas,
        'ignoradas': linhasIgnoradas,
        'importadas': ordens.length,
      };
    } catch (e) {
      print('❌ Erro ao importar CSV: $e');
      return {
        'sucesso': false,
        'erro': e.toString(),
      };
    }
  }

  // Obter centros de trabalho permitidos para o usuário (mesma regra das notas)
  Future<List<String>> _obterCentrosTrabalhoUsuario() async {
    try {
      final usuario = _authService.currentUser;
      // Root ou sem usuário: sem filtro por centro
      if (usuario == null || usuario.isRoot) return [];
      if (!usuario.temPerfilConfigurado()) return [];

      final todosCentros = await _centroTrabalhoService.getAllCentrosTrabalho();
      final centrosPermitidos = todosCentros.where((centro) {
        final okRegional = usuario.regionalIds.isEmpty || usuario.regionalIds.contains(centro.regionalId);
        final okDivisao = usuario.divisaoIds.isEmpty || usuario.divisaoIds.contains(centro.divisaoId);
        final okSegmento = usuario.segmentoIds.isEmpty || usuario.segmentoIds.contains(centro.segmentoId);
        return okRegional && okDivisao && okSegmento;
      }).toList();

      return centrosPermitidos
          .map((c) => c.centroTrabalho.trim())
          .where((c) => c.isNotEmpty)
          .toList();
    } catch (e) {
      print('⚠️ Erro ao obter centros de trabalho do usuário: $e');
      return [];
    }
  }

  // Parse de uma linha do CSV
  Ordem? _parseLinhaCSV(String linha) {
    try {
      // Ignorar linhas que são claramente separadores ou cabeçalhos
      if (linha.trim().isEmpty || 
          linha.replaceAll('|', '').replaceAll('-', '').replaceAll(' ', '').replaceAll('_', '').isEmpty ||
          linha.toLowerCase().contains('ordem') && linha.toLowerCase().contains('início')) {
        return null;
      }

      // O CSV usa pipes (|) como delimitadores
      // Formato: | Ordem | InícioBase | Fim-base | Tp. | Status do sistema | ...
      final partes = linha.split('|');
      if (partes.length < 13) {
        print('⚠️ Linha com número insuficiente de colunas: ${partes.length} (esperado: 13+)');
        return null;
      }

      // Remover espaços e limpar
      final valores = partes.map((p) {
        String trimmed = p.trim();
        // Garantir que a string está em UTF-8 válido
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

      // Validar que pelo menos a ordem não está vazia
      if (valores.length < 2 || valores[1].isEmpty) {
        print('⚠️ Linha sem número de ordem');
        return null;
      }

      // Criar objeto Ordem a partir dos valores parseados
      try {
        return Ordem.fromCSVParts(valores);
      } catch (e) {
        print('⚠️ Erro ao criar objeto Ordem: $e');
        print('   Linha: ${linha.substring(0, linha.length > 200 ? 200 : linha.length)}...');
        return null;
      }
    } catch (e) {
      print('⚠️ Erro ao parsear linha CSV: $e');
      return null;
    }
  }

  // Verificar se uma ordem já existe
  Future<bool> _ordemExiste(String ordem) async {
    try {
      if (ordem.isEmpty) return false;
      final response = await _supabase
          .from('ordens')
          .select('id')
          .eq('ordem', ordem)
          .limit(1)
          .maybeSingle();
      return response != null;
    } catch (e) {
      print('⚠️ Erro ao verificar se ordem existe: $e');
      // Em caso de erro, assumir que não existe para não bloquear a importação
      return false;
    }
  }

  // Sanitizar valores para Supabase (garantir UTF-8 válido)
  dynamic _sanitizeForSupabase(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      // Remover caracteres de controle e garantir UTF-8 válido
      String cleaned = value.replaceAll(RegExp(r'[\x00-\x08\x0B-\x0C\x0E-\x1F\x7F]'), '');
      // Tentar garantir que está em UTF-8 válido
      try {
        final utf8Bytes = utf8.encode(cleaned);
        final verified = utf8.decode(utf8Bytes);
        return verified;
      } catch (e) {
        // Se não for UTF-8 válido, tentar corrigir
        try {
          final latin1Bytes = latin1.encode(cleaned);
          final utf8String = utf8.decode(latin1Bytes, allowMalformed: true);
          return utf8String.replaceAll('', '');
        } catch (e2) {
          print('⚠️ Erro ao sanitizar string: $e2');
          return cleaned; // Retornar limpo mesmo se não conseguir validar UTF-8
        }
      }
    }
    return value;
  }

  // Inserir ordens no banco
  Future<void> _inserirOrdens(List<Ordem> ordens) async {
    try {
      print('💾 Preparando ${ordens.length} ordens para inserção...');
      
      // Inserir em lotes menores para evitar timeouts ou erros de tamanho
      const batchSize = 50;
      int totalInseridas = 0;
      
      for (int i = 0; i < ordens.length; i += batchSize) {
        final batch = ordens.skip(i).take(batchSize).toList();
        print('📦 Processando lote ${(i ~/ batchSize) + 1} (${batch.length} ordens)...');
        
        final maps = <Map<String, dynamic>>[];
        for (final o in batch) {
          try {
            final map = o.toMap();
            // Remover campos que serão gerados pelo banco
            map.remove('id');
            map.remove('created_at');
            map.remove('updated_at');
            map.remove('data_importacao'); // Será definido pelo banco com DEFAULT NOW()
            
            // Validar que a ordem não está vazia
            if (map['ordem'] == null || (map['ordem'] as String).isEmpty) {
              print('⚠️ Ordem sem número, pulando...');
              continue;
            }
            
            // Sanitizar todos os valores de string para garantir UTF-8 válido
            // E remover valores nulos ou vazios que podem causar problemas
            final sanitizedMap = <String, dynamic>{};
            map.forEach((key, value) {
              if (value == null) {
                // Manter null para campos opcionais
                sanitizedMap[key] = null;
              } else if (value is String && value.isEmpty && key != 'ordem') {
                // Campos de texto vazios podem ser null
                sanitizedMap[key] = null;
              } else {
                sanitizedMap[key] = _sanitizeForSupabase(value);
              }
            });
            
            maps.add(sanitizedMap);
          } catch (e) {
            print('⚠️ Erro ao preparar ordem para inserção: $e');
            print('   Ordem: ${o.ordem}');
            continue; // Continuar com as outras ordens
          }
        }

        if (maps.isNotEmpty) {
          try {
            print('💾 Inserindo lote de ${maps.length} ordens no banco...');
            await _supabase.from('ordens').insert(maps);
            totalInseridas += maps.length;
            print('✅ Lote de ${maps.length} ordens inseridas com sucesso (${i + 1}-${i + maps.length} de ${ordens.length})');
          } catch (e, stackTrace) {
            print('❌ Erro ao inserir lote no banco: $e');
            print('   Stack trace: $stackTrace');
            // Log do primeiro mapa para debug
            if (maps.isNotEmpty) {
              print('   Exemplo de dados do primeiro item:');
              final exemplo = maps.first;
              exemplo.forEach((key, value) {
                if (value is String && value.length > 100) {
                  print('   $key: ${value.substring(0, 100)}... (${value.length} chars)');
                } else {
                  print('   $key: $value');
                }
              });
            }
            rethrow;
          }
        } else {
          print('⚠️ Nenhuma ordem válida no lote ${(i ~/ batchSize) + 1}');
        }
      }
      print('✅ Total de $totalInseridas ordens inseridas com sucesso de ${ordens.length} processadas');
    } catch (e, stackTrace) {
      print('❌ Erro crítico ao inserir ordens: $e');
      print('   Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Buscar todas as ordens
  Future<List<Ordem>> getAllOrdens({
    String? filtroStatus,
    String? filtroLocal,
    String? filtroTipo,
    DateTime? dataInicio,
    DateTime? dataFim,
    int? limit,
    int? offset,
    bool apenasAbertas = false,
  }) async {
    // Definir fora do try para uso no fallback
    List<String> centrosUsuario = [];
    final usuario = _authService.currentUser;
    try {
      // Aplicar filtro por centro de trabalho do usuário (igual notas)
      if (usuario != null && !usuario.isRoot) {
        centrosUsuario = await _obterCentrosTrabalhoUsuario();
        if (centrosUsuario.isEmpty && usuario.temPerfilConfigurado()) {
          // Sem centros permitidos -> retornar vazio
          return [];
        }
      }

      // Tentar usar a VIEW ordens_com_local primeiro
      dynamic query = _supabase.from('ordens_com_local').select();

      if (filtroStatus != null && filtroStatus.isNotEmpty) {
        query = query.eq('status_sistema', filtroStatus);
      }

      if (apenasAbertas) {
        query = query.not('status_sistema', 'ilike', '%ENCE%');
        query = query.not('status_sistema', 'ilike', '%ENTE%');
      }

      if (filtroLocal != null && filtroLocal.isNotEmpty) {
        query = query.or('local.ilike.%$filtroLocal%,local_instalacao.ilike.%$filtroLocal%');
      }

      if (filtroTipo != null && filtroTipo.isNotEmpty) {
        query = query.eq('tipo', filtroTipo);
      }

      if (dataInicio != null) {
        query = query.gte('inicio_base', dataInicio.toIso8601String().split('T')[0]);
      }

      if (dataFim != null) {
        query = query.lte('fim_base', dataFim.toIso8601String().split('T')[0]);
      }

      // Filtro por centro de trabalho do usuário
      if (centrosUsuario.isNotEmpty) {
        if (centrosUsuario.length == 1) {
          query = query.ilike('centro_trabalho_responsavel', '%${centrosUsuario.first}%');
        } else {
          final orConditions = centrosUsuario.map((c) => 'centro_trabalho_responsavel.ilike.%$c%').join(',');
          query = query.or(orConditions);
        }
      }

      query = query.order('created_at', ascending: false);

      if (limit != null) {
        query = query.limit(limit);
      }

      if (offset != null) {
        query = query.range(offset, offset + (limit ?? 100) - 1);
      }

      final response = await query;
      return (response as List).map((map) => Ordem.fromMap(map)).toList();
    } catch (e) {
      // Se a VIEW não existir, usar a tabela ordens diretamente como fallback
      print('⚠️ VIEW ordens_com_local não encontrada, usando tabela ordens diretamente: $e');
      try {
        dynamic query = _supabase.from('ordens').select();

        if (filtroStatus != null && filtroStatus.isNotEmpty) {
          query = query.eq('status_sistema', filtroStatus);
        }

        if (apenasAbertas) {
          query = query.not('status_sistema', 'ilike', '%ENCE%');
          query = query.not('status_sistema', 'ilike', '%ENTE%');
        }

        if (filtroLocal != null && filtroLocal.isNotEmpty) {
          query = query.or('local.ilike.%$filtroLocal%,local_instalacao.ilike.%$filtroLocal%');
        }

        if (filtroTipo != null && filtroTipo.isNotEmpty) {
          query = query.eq('tipo', filtroTipo);
        }

        if (dataInicio != null) {
          query = query.gte('inicio_base', dataInicio.toIso8601String().split('T')[0]);
        }

        if (dataFim != null) {
          query = query.lte('fim_base', dataFim.toIso8601String().split('T')[0]);
        }

        // Filtro por centro de trabalho do usuário
        if (centrosUsuario.isNotEmpty) {
          if (centrosUsuario.length == 1) {
            query = query.ilike('centro_trabalho_responsavel', '%${centrosUsuario.first}%');
          } else {
            final orConditions = centrosUsuario.map((c) => 'centro_trabalho_responsavel.ilike.%$c%').join(',');
            query = query.or(orConditions);
          }
        }

        query = query.order('created_at', ascending: false);

        if (limit != null) {
          query = query.limit(limit);
        }

        if (offset != null) {
          query = query.range(offset, offset + (limit ?? 100) - 1);
        }

        final response = await query;
        return (response as List).map((map) => Ordem.fromMap(map)).toList();
      } catch (e2) {
        print('❌ Erro ao buscar ordens (fallback): $e2');
        return [];
      }
    }
  }

  // Contar ordens
  Future<int> contarOrdens({
    String? filtroStatus,
    String? filtroLocal,
    String? filtroTipo,
    DateTime? dataInicio,
    DateTime? dataFim,
  }) async {
    try {
      // Aplicar filtro por centro de trabalho do usuário (igual notas)
      final usuario = _authService.currentUser;
      List<String> centrosUsuario = [];
      if (usuario != null && !usuario.isRoot) {
        centrosUsuario = await _obterCentrosTrabalhoUsuario();
        if (centrosUsuario.isEmpty && usuario.temPerfilConfigurado()) {
          // Sem centros permitidos -> zero
          return 0;
        }
      }

      dynamic query = _supabase.from('ordens').select('id');

      if (filtroStatus != null && filtroStatus.isNotEmpty) {
        query = query.eq('status_sistema', filtroStatus);
      }

      if (filtroLocal != null && filtroLocal.isNotEmpty) {
        query = query.or('local.ilike.%$filtroLocal%,local_instalacao.ilike.%$filtroLocal%');
      }

      if (filtroTipo != null && filtroTipo.isNotEmpty) {
        query = query.eq('tipo', filtroTipo);
      }

      // Filtro por centro de trabalho do usuário
      if (centrosUsuario.isNotEmpty) {
        if (centrosUsuario.length == 1) {
          query = query.ilike('centro_trabalho_responsavel', '%${centrosUsuario.first}%');
        } else {
          final orConditions = centrosUsuario.map((c) => 'centro_trabalho_responsavel.ilike.%$c%').join(',');
          query = query.or(orConditions);
        }
      }

      if (dataInicio != null) {
        query = query.gte('inicio_base', dataInicio.toIso8601String().split('T')[0]);
      }

      if (dataFim != null) {
        query = query.lte('fim_base', dataFim.toIso8601String().split('T')[0]);
      }

      final response = await query;
      return (response as List).length;
    } catch (e) {
      print('❌ Erro ao contar ordens: $e');
      // Fallback: buscar todas e contar
      try {
        final todas = await getAllOrdens(
          filtroStatus: filtroStatus,
          filtroLocal: filtroLocal,
          filtroTipo: filtroTipo,
          dataInicio: dataInicio,
          dataFim: dataFim,
        );
        return todas.length;
      } catch (e2) {
        return 0;
      }
    }
  }

  // Buscar ordem por ID
  Future<Ordem?> getOrdemById(String id) async {
    try {
      // Tentar usar a VIEW ordens_com_local primeiro
      final response = await _supabase
          .from('ordens_com_local')
          .select()
          .eq('id', id)
          .maybeSingle();
      
      if (response == null) return null;
      return Ordem.fromMap(response);
    } catch (e) {
      // Se a VIEW não existir, usar a tabela ordens diretamente como fallback
      print('⚠️ VIEW ordens_com_local não encontrada, usando tabela ordens diretamente: $e');
      try {
        final response = await _supabase
            .from('ordens')
            .select()
            .eq('id', id)
            .maybeSingle();
        
        if (response == null) return null;
        return Ordem.fromMap(response);
      } catch (e2) {
        print('❌ Erro ao buscar ordem por ID (fallback): $e2');
        return null;
      }
    }
  }

  // Buscar ordem por número
  Future<Ordem?> getOrdemPorNumero(String ordem) async {
    try {
      final response = await _supabase
          .from('ordens')
          .select()
          .eq('ordem', ordem)
          .maybeSingle();
      
      if (response == null) return null;
      return Ordem.fromMap(response);
    } catch (e) {
      print('❌ Erro ao buscar ordem por número: $e');
      return null;
    }
  }

  // Obter valores únicos para filtros, com timeout e retry para evitar sumiço em UI
  Future<Map<String, List<String>>> getValoresFiltros({
    Duration timeout = const Duration(seconds: 12),
    int retries = 2,
  }) async {
    Map<String, List<String>> buildResult(List<dynamic> rows) {
      final statusSet = <String>{};
      final localSet = <String>{};
      final tipoSet = <String>{};

      for (final item in rows) {
        final map = item as Map<String, dynamic>;
        final status = map['status_sistema'] as String?;
        final local = map['local'] as String?;
        final localInst = map['local_instalacao'] as String?;
        final tipo = map['tipo'] as String?;

        if (status != null && status.isNotEmpty) statusSet.add(status);
        final loc = (local?.isNotEmpty ?? false) ? local : localInst;
        if (loc != null && loc.isNotEmpty) localSet.add(loc);
        if (tipo != null && tipo.isNotEmpty) tipoSet.add(tipo);
      }

      return {
        'status': statusSet.toList()..sort(),
        'local': localSet.toList()..sort(),
        'tipo': tipoSet.toList()..sort(),
      };
    }

    Future<List<dynamic>> fetchFrom(String table) {
      return _supabase
          .from(table)
          .select('status_sistema, local, local_instalacao, tipo')
          .limit(20000)
          .timeout(timeout);
    }

    for (int attempt = 0; attempt <= retries; attempt++) {
      final isLast = attempt == retries;
      try {
        // Tentar view primeiro, depois fallback para tabela
        try {
          final viewResp = await fetchFrom('ordens_com_local');
          return buildResult(viewResp);
        } catch (e) {
          print('⚠️ Falha na view ordens_com_local (tentativa ${attempt + 1}): $e');
          final tableResp = await fetchFrom('ordens');
          return buildResult(tableResp);
        }
      } catch (e) {
        print('⚠️ Erro ao buscar valores de filtros (tentativa ${attempt + 1}): $e');
        if (isLast) {
          break;
        }
        // pequeno delay antes do retry
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }

    // fallback vazio em caso de falha
    return {
      'status': [],
      'local': [],
      'tipo': [],
    };
  }

  // Deletar ordem
  Future<bool> deleteOrdem(String id) async {
    try {
      await _supabase.from('ordens').delete().eq('id', id);
      return true;
    } catch (e) {
      print('❌ Erro ao deletar ordem: $e');
      return false;
    }
  }

  // Atualizar ordem
  Future<bool> updateOrdem(Ordem ordem) async {
    try {
      await _supabase
          .from('ordens')
          .update(ordem.toMap())
          .eq('id', ordem.id);
      return true;
    } catch (e) {
      print('❌ Erro ao atualizar ordem: $e');
      return false;
    }
  }

  // Vincular ordem a uma tarefa
  Future<void> vincularOrdemATarefa(String taskId, String ordemId) async {
    try {
      print('🔗 Iniciando vinculação de ordem $ordemId à tarefa $taskId...');
      
      // Verificar se a tabela existe (teste de conexão)
      try {
        await _supabase.from('tasks_ordens').select('id').limit(1);
        print('✅ Tabela tasks_ordens existe e está acessível');
      } catch (e) {
        print('❌ ERRO: Tabela tasks_ordens não existe ou não está acessível: $e');
        throw Exception('Tabela tasks_ordens não existe. Execute o script criar_tabela_tasks_ordens.sql no Supabase.');
      }
      
      // Verificar se a ordem existe
      final ordemExiste = await _supabase
          .from('ordens')
          .select('id')
          .eq('id', ordemId)
          .maybeSingle();
      
      if (ordemExiste == null) {
        throw Exception('Ordem com ID $ordemId não encontrada');
      }
      print('✅ Ordem $ordemId existe no banco');
      
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
          .from('tasks_ordens')
          .select('id')
          .eq('task_id', taskId)
          .eq('ordem_id', ordemId)
          .maybeSingle();
      
      if (vinculoExistente != null) {
        print('ℹ️ Ordem já está vinculada a esta tarefa');
        return; // Já está vinculada, não precisa fazer nada
      }
      
      // Vincular a ordem (VINCULAÇÃO PRINCIPAL - se falhar, deve propagar o erro)
      print('🔗 Inserindo vínculo na tabela tasks_ordens...');
      try {
        final resultado = await _supabase.from('tasks_ordens').insert({
          'task_id': taskId,
          'ordem_id': ordemId,
        }).select();
        
        print('✅ Ordem vinculada à tarefa. Resultado: $resultado');
      } catch (e) {
        print('❌ ERRO CRÍTICO ao inserir vínculo principal: $e');
        print('   Task ID: $taskId');
        print('   Ordem ID: $ordemId');
        // Re-lançar o erro para que o UI possa tratá-lo
        throw Exception('Erro ao vincular ordem à tarefa: $e');
      }
      
      // VINCULAÇÃO AUTOMÁTICA DE NOTAS (se falhar, apenas loga, não interrompe)
      try {
        // Buscar o número da ordem
        print('🔍 Buscando ordem $ordemId para obter número da ordem...');
        final ordemResponse = await _supabase
            .from('ordens')
            .select('ordem')
            .eq('id', ordemId)
            .maybeSingle();
        
        print('📋 Resposta da ordem: $ordemResponse');
        
        if (ordemResponse != null && ordemResponse['ordem'] != null) {
          final ordemNumero = ordemResponse['ordem'] as String;
          print('🔢 Número da ordem encontrado: $ordemNumero');
          
          // Buscar todas as notas SAP com o mesmo número de ordem
          final ordemNumeroTrimmed = ordemNumero.trim();
          print('🔍 Buscando notas SAP com ordem "$ordemNumeroTrimmed"...');
          
          try {
            // Buscar na tabela notas_sap (não na VIEW, para garantir que encontre todas)
            final notasResponse = await _supabase
                .from('notas_sap')
                .select('id, nota, ordem')
                .eq('ordem', ordemNumeroTrimmed);
            
            print('📋 Total de notas encontradas: ${notasResponse.length}');
            
            if (notasResponse.isNotEmpty) {
              final notasIds = (notasResponse as List)
                  .map((item) => item['id'] as String)
                  .toList();
              
              print('📝 IDs das notas encontradas: $notasIds');
              
              // Verificar quais notas já estão vinculadas
              final List<String> notasJaVinculadas = [];
              for (final notaId in notasIds) {
                try {
                  final vinculo = await _supabase
                      .from('tasks_notas_sap')
                      .select('id')
                      .eq('task_id', taskId)
                      .eq('nota_sap_id', notaId)
                      .maybeSingle();
                  if (vinculo != null) {
                    notasJaVinculadas.add(notaId);
                  }
                } catch (e) {
                  print('⚠️ Erro ao verificar vínculo da nota $notaId: $e');
                }
              }
              
              print('📋 Notas já vinculadas: ${notasJaVinculadas.length} de ${notasIds.length}');
              
              // Vincular todas as notas que ainda não estão vinculadas
              final notasParaVincular = notasIds
                  .where((notaId) => !notasJaVinculadas.contains(notaId))
                  .toList();
              
              print('📝 Notas para vincular: ${notasParaVincular.length}');
              
              if (notasParaVincular.isNotEmpty) {
                int vinculadasComSucesso = 0;
                
                for (final notaId in notasParaVincular) {
                  try {
                    print('🔗 Vinculando nota $notaId à tarefa $taskId...');
                    // Usar o serviço de notas, mas sem tentar vincular ordem novamente
                    // para evitar loop infinito
                    await _supabase.from('tasks_notas_sap').insert({
                      'task_id': taskId,
                      'nota_sap_id': notaId,
                    });
                    vinculadasComSucesso++;
                    print('✅ Nota $notaId vinculada com sucesso');
                  } catch (e) {
                    print('❌ Erro ao vincular nota $notaId automaticamente: $e');
                    print('   Task ID: $taskId');
                    print('   Nota ID: $notaId');
                  }
                }
                print('✅ $vinculadasComSucesso de ${notasParaVincular.length} nota(s) vinculada(s) automaticamente à tarefa');
              } else {
                print('ℹ️ Todas as notas com ordem "$ordemNumeroTrimmed" já estavam vinculadas');
              }
            } else {
              print('ℹ️ Nenhuma nota SAP encontrada com ordem "$ordemNumeroTrimmed"');
              // Debug: verificar se há notas com ordem similar
              try {
                final notasSimilares = await _supabase
                    .from('notas_sap')
                    .select('id, nota, ordem')
                    .ilike('ordem', '%$ordemNumeroTrimmed%')
                    .limit(5);
                if (notasSimilares.isNotEmpty) {
                  print('   Notas com ordem similar encontradas: $notasSimilares');
                }
              } catch (e) {
                print('   Erro ao buscar notas similares: $e');
              }
            }
          } catch (e, stackTrace) {
            print('❌ Erro ao buscar notas SAP: $e');
            print('❌ Stack trace: $stackTrace');
          }
        } else {
          print('⚠️ Ordem não possui número ou número é nulo');
        }
      } catch (e, stackTrace) {
        // Erro na vinculação automática - apenas loga, não interrompe
        print('⚠️ Erro na vinculação automática de notas (não crítico): $e');
        print('   Stack trace: $stackTrace');
      }
    } catch (e, stackTrace) {
      print('❌ Erro ao vincular ordem: $e');
      print('❌ Stack trace: $stackTrace');
      // Re-lançar o erro para que o UI possa tratá-lo
      rethrow;
    }
  }

  // Desvincular ordem de uma tarefa
  Future<void> desvincularOrdemDeTarefa(String taskId, String ordemId) async {
    try {
      // Buscar o número da ordem
      final ordemResponse = await _supabase
          .from('ordens')
          .select('ordem')
          .eq('id', ordemId)
          .maybeSingle();
      
      String? ordemNumero;
      if (ordemResponse != null && ordemResponse['ordem'] != null) {
        ordemNumero = ordemResponse['ordem'] as String;
      }
      
      // Desvincular a ordem
      await _supabase
          .from('tasks_ordens')
          .delete()
          .eq('task_id', taskId)
          .eq('ordem_id', ordemId);
      print('✅ Ordem desvinculada da tarefa');
      
      // Se havia um número de ordem, desvincular todas as notas correspondentes
      if (ordemNumero != null) {
        // Buscar todas as notas SAP com o mesmo número de ordem
        final notasResponse = await _supabase
            .from('notas_sap')
            .select('id')
            .eq('ordem', ordemNumero);
        
        if (notasResponse.isNotEmpty) {
          final notasIds = (notasResponse as List)
              .map((item) => item['id'] as String)
              .toList();
          
          // Desvincular todas as notas
          for (final notaId in notasIds) {
            try {
              await _supabase
                  .from('tasks_notas_sap')
                  .delete()
                  .eq('task_id', taskId)
                  .eq('nota_sap_id', notaId);
            } catch (e) {
              print('⚠️ Erro ao desvincular nota $notaId: $e');
            }
          }
          
          print('✅ ${notasIds.length} nota(s) desvinculada(s) automaticamente');
        }
      }
    } catch (e) {
      print('❌ Erro ao desvincular ordem: $e');
      rethrow;
    }
  }

  // Contar ordens vinculadas por tarefas
  Future<Map<String, int>> contarOrdensPorTarefas(List<String> taskIds) async {
    try {
      if (taskIds.isEmpty) return {};

      // Usar VIEW otimizada do Supabase para buscar todas as contagens de uma vez
      // Usar .or() para múltiplos valores (já funciona no código)
      dynamic query = _supabase
          .from('contagens_ordens_tarefas')
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
      print('❌ Erro ao contar ordens das tarefas: $e');
      return {};
    }
  }

  // Buscar ordens vinculadas a uma tarefa
  Future<List<Ordem>> getOrdensPorTarefa(String taskId) async {
    try {
      // Buscar IDs das ordens vinculadas à tarefa
      final tasksOrdensResponse = await _supabase
          .from('tasks_ordens')
          .select('ordem_id')
          .eq('task_id', taskId);

      if (tasksOrdensResponse.isEmpty) {
        return [];
      }

      final ordemIds = (tasksOrdensResponse as List)
          .map((item) => item['ordem_id'] as String)
          .toList();

      // Buscar as ordens usando a VIEW ordens_com_local
      if (ordemIds.isEmpty) {
        return [];
      }

      try {
        // Tentar usar a VIEW ordens_com_local primeiro
        dynamic query = _supabase.from('ordens_com_local').select();
        
        if (ordemIds.length == 1) {
          query = query.eq('id', ordemIds[0]);
        } else {
          final orConditions = ordemIds.map((id) => 'id.eq.$id').join(',');
          query = query.or(orConditions);
        }
        
        final response = await query;

        return (response as List)
            .map((item) => Ordem.fromMap(item as Map<String, dynamic>))
            .toList();
      } catch (e) {
        // Se a VIEW não existir, usar a tabela ordens diretamente como fallback
        print('⚠️ VIEW ordens_com_local não encontrada, usando tabela ordens diretamente: $e');
        try {
          dynamic query = _supabase.from('ordens').select();
          
          if (ordemIds.length == 1) {
            query = query.eq('id', ordemIds[0]);
          } else {
            final orConditions = ordemIds.map((id) => 'id.eq.$id').join(',');
            query = query.or(orConditions);
          }
          
          final response = await query;

          return (response as List)
              .map((item) => Ordem.fromMap(item as Map<String, dynamic>))
              .toList();
        } catch (e2) {
          print('❌ Erro ao buscar ordens da tarefa (fallback): $e2');
          return [];
        }
      }
    } catch (e) {
      print('❌ Erro ao buscar ordens da tarefa: $e');
      return [];
    }
  }

  // Buscar tarefas vinculadas a uma ordem
  Future<List<String>> getTarefasPorOrdem(String ordemId) async {
    try {
      final response = await _supabase
          .from('tasks_ordens')
          .select('task_id')
          .eq('ordem_id', ordemId);

      return (response as List).map((item) => item['task_id'] as String).toList();
    } catch (e) {
      print('❌ Erro ao buscar tarefas da ordem: $e');
      return [];
    }
  }

  // Buscar ordens programadas (vinculadas a tarefas) com informações das tarefas
  Future<List<Map<String, dynamic>>> getOrdensProgramadas() async {
    try {
      final response = await _supabase
          .from('tasks_ordens')
          .select('''
            id,
            created_at,
            ordens(*),
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
          ''')
          .order('created_at', ascending: false);

      return (response as List).map((item) {
        return {
          'vinculo_id': item['id'] as String,
          'vinculado_em': item['created_at'] != null
              ? DateTime.parse(item['created_at'] as String)
              : null,
          'ordem': Ordem.fromMap(item['ordens'] as Map<String, dynamic>),
          'tarefa': item['tasks'] as Map<String, dynamic>?,
        };
      }).toList();
    } catch (e) {
      print('❌ Erro ao buscar ordens programadas: $e');
      return [];
    }
  }
}
