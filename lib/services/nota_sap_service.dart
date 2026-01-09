import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert' show latin1, utf8;
import '../models/nota_sap.dart';

class NotaSAPService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Importar notas do CSV
  Future<Map<String, dynamic>> importarNotasDoCSV(String csvContent) async {
    try {
      final linhas = csvContent.split('\n');
      if (linhas.length < 5) {
        throw Exception('CSV inválido: menos de 5 linhas');
      }

      // Encontrar o cabeçalho (linha que contém "Tp." e "Nota")
      int linhaCabecalho = -1;
      for (int i = 0; i < linhas.length; i++) {
        if (linhas[i].contains('Tp.') && linhas[i].contains('Nota')) {
          linhaCabecalho = i;
          break;
        }
      }

      if (linhaCabecalho == -1) {
        throw Exception('Cabeçalho não encontrado no CSV');
      }

      print('📋 Cabeçalho encontrado na linha ${linhaCabecalho + 1}');

      // Processar linhas de dados (após o separador do cabeçalho)
      final notas = <NotaSAP>[];
      int linhasProcessadas = 0;
      int linhasIgnoradas = 0;
      int duplicatas = 0;

      for (int i = linhaCabecalho + 2; i < linhas.length; i++) {
        final linha = linhas[i].trim();
        if (linha.isEmpty || linha.startsWith('-')) continue;

        try {
          final nota = _parseLinhaCSV(linha);
          if (nota != null) {
            // Verificar se a nota já existe
            final existe = await _notaExiste(nota.nota);
            if (existe) {
              duplicatas++;
              continue;
            }
            notas.add(nota);
            linhasProcessadas++;
          } else {
            linhasIgnoradas++;
          }
        } catch (e) {
          print('⚠️ Erro ao processar linha ${i + 1}: $e');
          linhasIgnoradas++;
        }
      }

      // Inserir notas no banco (usar upsert para evitar duplicatas)
      if (notas.isNotEmpty) {
        await _inserirNotas(notas);
      }

      return {
        'sucesso': true,
        'total': linhasProcessadas,
        'duplicatas': duplicatas,
        'ignoradas': linhasIgnoradas,
        'importadas': notas.length,
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
  NotaSAP? _parseLinhaCSV(String linha) {
    try {
      // O CSV usa pipes (|) como delimitadores
      // Formato: | Tp. | Criado em | TextPrioridade | Nota | ...
      final partes = linha.split('|');
      if (partes.length < 4) return null;

      // Remover espaços e limpar, garantindo que strings estão em UTF-8
      final valores = partes.map((p) {
        String trimmed = p.trim();
        // Garantir que a string está em UTF-8 válido
        // Se contém caracteres de substituição, tentar corrigir
        if (trimmed.contains('')) {
          try {
            // Tentar re-encodar como Latin-1 e decodificar como UTF-8
            final bytes = latin1.encode(trimmed);
            trimmed = utf8.decode(bytes, allowMalformed: true);
          } catch (e) {
            // Se falhar, manter original
          }
        }
        return trimmed;
      }).toList();

      // Índices esperados (baseado no cabeçalho):
      // 0: vazio (antes do primeiro |)
      // 1: Tp.
      // 2: Criado em
      // 3: TextPrioridade
      // 4: Nota
      // 5: Ordem
      // 6: Descrição
      // 7: Local de instalação
      // 8: Sala
      // 9: Status sistema
      // 10: Iníc.desej
      // 11: Concl.desj
      // 12: HoraCr.
      // 13: StatUsuár.
      // 14: Equipam.
      // 15: Data
      // 16: Notificd.
      // 17: CenTrabRes
      // 18: Cen.
      // 19: Fim avaria
      // 20: De
      // 21: Encerram.
      // 22: Denominação executor
      // 23: Dt.refer.
      // 24: GPM
      // 25: InícioAvar
      // 26: Modif.em
      // 27: Cpo.orden.

      if (valores.length < 5 || valores[4].isEmpty) {
        return null; // Nota é obrigatória
      }

      DateTime? parseDate(String? value) {
        if (value == null || value.isEmpty) return null;
        try {
          // Formato DD.MM.YYYY
          if (value.contains('.')) {
            final parts = value.split('.');
            if (parts.length == 3) {
              return DateTime(
                int.parse(parts[2]),
                int.parse(parts[1]),
                int.parse(parts[0]),
              );
            }
          }
          return DateTime.parse(value);
        } catch (e) {
          return null;
        }
      }

      // Função para normalizar strings e garantir UTF-8 válido
      // Quando o arquivo é decodificado como Latin-1, os caracteres acentuados
      // já estão corretos na string Dart (UTF-16), mas precisamos garantir
      // que ao serializar para JSON/Supabase, sejam enviados como UTF-8 válido
      String? normalizeString(String? value) {
        if (value == null || value.isEmpty) return value;
        
        // Se contém caracteres de substituição, tentar corrigir
        if (value.contains('')) {
          try {
            // Assumir que foi lido incorretamente como UTF-8 quando era Latin-1
            // Re-encodar como Latin-1 e decodificar como UTF-8
            final bytes = latin1.encode(value);
            final corrected = utf8.decode(bytes, allowMalformed: true);
            if (!corrected.contains('')) {
              return corrected;
            }
          } catch (e) {
            // Se falhar, manter original
          }
        }
        
        // Verificar se é UTF-8 válido ao serializar
        // Em Dart, strings são UTF-16, mas ao enviar para Supabase via JSON,
        // precisamos garantir que a serialização seja UTF-8 válida
        try {
          // Testar se pode ser encodado e decodificado como UTF-8
          final utf8Bytes = utf8.encode(value);
          final verified = utf8.decode(utf8Bytes);
          // Se não contém caracteres de substituição, está OK
          if (!verified.contains('')) {
            return verified;
          }
        } catch (e) {
          // Se não for UTF-8 válido, a string já está corrompida
          print('⚠️ String não é UTF-8 válida: ${value.substring(0, value.length > 30 ? 30 : value.length)}...');
        }
        
        // Se chegou aqui, a string está OK (Dart já garante UTF-16 válido)
        return value;
      }

      String? getValue(int index) {
        if (index < valores.length && valores[index].isNotEmpty) {
          return normalizeString(valores[index]);
        }
        return null;
      }

      return NotaSAP(
        id: '', // Será gerado pelo banco
        tipo: getValue(1),
        criadoEm: parseDate(getValue(2)),
        textPrioridade: getValue(3),
        nota: normalizeString(valores[4]) ?? '', // Obrigatório, normalizado
        ordem: getValue(5),
        descricao: getValue(6),
        localInstalacao: getValue(7),
        sala: getValue(8),
        statusSistema: getValue(9),
        inicioDesejado: parseDate(getValue(10)),
        conclusaoDesejada: parseDate(getValue(11)),
        horaCriacao: getValue(12),
        statusUsuario: getValue(13),
        equipamento: getValue(14),
        data: parseDate(getValue(15)),
        notificacao: getValue(16),
        centroTrabalhoResponsavel: getValue(17),
        centro: getValue(18),
        fimAvaria: parseDate(getValue(19)),
        de: getValue(20),
        encerramento: parseDate(getValue(21)),
        denominacaoExecutor: getValue(22),
        dataReferencia: parseDate(getValue(23)),
        gpm: getValue(24),
        inicioAvaria: parseDate(getValue(25)),
        modificadoEm: parseDate(getValue(26)),
        campoOrdenacao: getValue(27),
      );
    } catch (e) {
      print('⚠️ Erro ao parsear linha: $e');
      return null;
    }
  }

  // Verificar se nota já existe
  Future<bool> _notaExiste(String numeroNota) async {
    try {
      final response = await _supabase
          .from('notas_sap')
          .select('id')
          .eq('nota', numeroNota)
          .maybeSingle();
      return response != null;
    } catch (e) {
      print('⚠️ Erro ao verificar nota: $e');
      return false;
    }
  }

  // Função para garantir que strings estão em UTF-8 válido antes de salvar
  static dynamic _sanitizeForSupabase(dynamic value) {
    if (value == null) return value;
    if (value is String) {
      // Remover caracteres de substituição () diretamente
      String cleaned = value.replaceAll('', '');
      
      // Se havia caracteres de substituição e foram removidos, logar
      if (cleaned.length < value.length) {
        print('⚠️ Removidos ${value.length - cleaned.length} caracteres de substituição');
      }
      
      // Mapeamento de correções comuns de caracteres corrompidos
      final Map<String, String> correcoes = {
        'operao': 'operação',
        'operacao': 'operação',
        'PSSARO': 'PÁSSARO',
        'Passaro': 'Pássaro',
        'LEO': 'ÓLEO',
        'Oleo': 'Óleo',
        'ALIMENTAO': 'ALIMENTAÇÃO',
        'Alimentao': 'Alimentação',
        'SEGURAN': 'SEGURANÇA',
        'Seguran': 'Segurança',
        'RELE': 'RELÉ',
        'Rele': 'Relé',
        'PRESSO': 'PRESSÃO',
        'Presso': 'Pressão',
        'TENSO': 'TENSÃO',
        'Tenso': 'Tensão',
        'Media': 'Média',
        'MEDIA': 'MÉDIA',
        'Med': 'Méd',
        'MED': 'MÉD',
      };
      
      // Aplicar correções
      String corrigido = cleaned;
      correcoes.forEach((errado, certo) {
        corrigido = corrigido.replaceAll(errado, certo);
      });
      
      // Se houve correções, logar
      if (corrigido != cleaned) {
        print('✅ Aplicadas correções de encoding em: ${cleaned.substring(0, cleaned.length > 50 ? 50 : cleaned.length)}...');
      }
      
      // Verificar se é UTF-8 válido ao serializar
      try {
        // Testar se pode ser encodado e decodificado como UTF-8
        final utf8Bytes = utf8.encode(corrigido);
        final verified = utf8.decode(utf8Bytes);
        return verified;
      } catch (e) {
        // Se não for UTF-8 válido, tentar corrigir
        try {
          // Assumir que a string está em Latin-1 e converter para UTF-8
          final latin1Bytes = latin1.encode(corrigido);
          final utf8String = utf8.decode(latin1Bytes, allowMalformed: true);
          // Remover caracteres de substituição novamente
          return utf8String.replaceAll('', '');
        } catch (e2) {
          print('❌ Erro ao converter para UTF-8: $e2');
          return corrigido; // Retornar corrigido mesmo se não conseguir validar UTF-8
        }
      }
    }
    return value;
  }

  // Inserir notas no banco
  Future<void> _inserirNotas(List<NotaSAP> notas) async {
    try {
      final maps = notas.map((n) {
        final map = n.toMap();
        map.remove('id'); // Remover ID para deixar o banco gerar
        map.remove('created_at');
        map.remove('updated_at');
        map.remove('data_importacao');
        
        // Sanitizar todos os valores de string para garantir UTF-8 válido
        final sanitizedMap = <String, dynamic>{};
        map.forEach((key, value) {
          sanitizedMap[key] = _sanitizeForSupabase(value);
        });
        
        return sanitizedMap;
      }).toList();

      // Log de exemplo para debug com verificação de encoding
      if (maps.isNotEmpty) {
        final exemplo = maps.first;
        print('📤 Exemplo de dados sendo salvos:');
        print('   descricao: ${exemplo['descricao']}');
        print('   text_prioridade: ${exemplo['text_prioridade']}');
        print('   denominacao_executor: ${exemplo['denominacao_executor']}');
        
        // Verificar encoding dos dados
        if (exemplo['descricao'] != null) {
          final descBytes = utf8.encode(exemplo['descricao'] as String);
          print('   descricao (UTF-8 bytes): ${descBytes.length} bytes');
          if (exemplo['descricao'].toString().contains('ão') || 
              exemplo['descricao'].toString().contains('ção')) {
            print('   ✅ descricao contém acentos corretos');
          }
        }
      }

      await _supabase.from('notas_sap').upsert(
        maps,
        onConflict: 'nota', // Usar nota como chave única para upsert
      );

      print('✅ ${notas.length} notas inseridas/atualizadas');
    } catch (e) {
      print('❌ Erro ao inserir notas: $e');
      rethrow;
    }
  }

  // Buscar todas as notas
  Future<List<NotaSAP>> getAllNotas({
    String? filtroStatus,
    String? filtroLocal,
    DateTime? dataInicio,
    DateTime? dataFim,
    int? limit,
    int? offset,
  }) async {
    try {
      dynamic query = _supabase.from('notas_sap').select();

      if (filtroStatus != null && filtroStatus.isNotEmpty) {
        query = query.eq('status_sistema', filtroStatus);
      }

      if (filtroLocal != null && filtroLocal.isNotEmpty) {
        query = query.ilike('local_instalacao', '%$filtroLocal%');
      }

      if (dataInicio != null) {
        query = query.gte('criado_em', dataInicio.toIso8601String().split('T')[0]);
      }

      if (dataFim != null) {
        query = query.lte('criado_em', dataFim.toIso8601String().split('T')[0]);
      }

      query = query.order('criado_em', ascending: false);

      if (limit != null) {
        query = query.limit(limit);
      }

      if (offset != null) {
        query = query.range(offset, offset + (limit ?? 100) - 1);
      }

      final response = await query;
      return (response as List).map((map) => NotaSAP.fromMap(map)).toList();
    } catch (e) {
      print('❌ Erro ao buscar notas: $e');
      return [];
    }
  }

  // Buscar nota por ID
  Future<NotaSAP?> getNotaById(String id) async {
    try {
      final response = await _supabase
          .from('notas_sap')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (response == null) return null;
      return NotaSAP.fromMap(response);
    } catch (e) {
      print('❌ Erro ao buscar nota: $e');
      return null;
    }
  }

  // Buscar nota por número
  Future<NotaSAP?> getNotaPorNumero(String numeroNota) async {
    try {
      final response = await _supabase
          .from('notas_sap')
          .select()
          .eq('nota', numeroNota)
          .maybeSingle();
      if (response == null) return null;
      return NotaSAP.fromMap(response);
    } catch (e) {
      print('❌ Erro ao buscar nota: $e');
      return null;
    }
  }

  // Vincular nota a uma tarefa
  Future<void> vincularNotaATarefa(String taskId, String notaSapId) async {
    try {
      await _supabase.from('tasks_notas_sap').insert({
        'task_id': taskId,
        'nota_sap_id': notaSapId,
      });
      print('✅ Nota vinculada à tarefa');
    } catch (e) {
      print('❌ Erro ao vincular nota: $e');
      rethrow;
    }
  }

  // Desvincular nota de uma tarefa
  Future<void> desvincularNotaDeTarefa(String taskId, String notaSapId) async {
    try {
      await _supabase
          .from('tasks_notas_sap')
          .delete()
          .eq('task_id', taskId)
          .eq('nota_sap_id', notaSapId);
      print('✅ Nota desvinculada da tarefa');
    } catch (e) {
      print('❌ Erro ao desvincular nota: $e');
      rethrow;
    }
  }

  // Buscar notas vinculadas a uma tarefa
  Future<List<NotaSAP>> getNotasPorTarefa(String taskId) async {
    try {
      final response = await _supabase
          .from('tasks_notas_sap')
          .select('notas_sap(*)')
          .eq('task_id', taskId);

      return (response as List)
          .map((item) => NotaSAP.fromMap(item['notas_sap'] as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ Erro ao buscar notas da tarefa: $e');
      return [];
    }
  }

  // Buscar tarefas vinculadas a uma nota
  Future<List<String>> getTarefasPorNota(String notaSapId) async {
    try {
      final response = await _supabase
          .from('tasks_notas_sap')
          .select('task_id')
          .eq('nota_sap_id', notaSapId);

      return (response as List).map((item) => item['task_id'] as String).toList();
    } catch (e) {
      print('❌ Erro ao buscar tarefas da nota: $e');
      return [];
    }
  }

  // Contar notas
  Future<int> contarNotas({
    String? filtroStatus,
    String? filtroLocal,
    DateTime? dataInicio,
    DateTime? dataFim,
  }) async {
    try {
      dynamic query = _supabase.from('notas_sap').select('id');

      if (filtroStatus != null && filtroStatus.isNotEmpty) {
        query = query.eq('status_sistema', filtroStatus);
      }

      if (filtroLocal != null && filtroLocal.isNotEmpty) {
        query = query.ilike('local_instalacao', '%$filtroLocal%');
      }

      if (dataInicio != null) {
        query = query.gte('criado_em', dataInicio.toIso8601String().split('T')[0]);
      }

      if (dataFim != null) {
        query = query.lte('criado_em', dataFim.toIso8601String().split('T')[0]);
      }

      final response = await query;
      return (response as List).length;
    } catch (e) {
      print('❌ Erro ao contar notas: $e');
      return 0;
    }
  }

  // Buscar valores únicos para filtros
  Future<Map<String, List<String>>> getValoresFiltros() async {
    try {
      final response = await _supabase.from('notas_sap').select('status_sistema, local_instalacao');

      final statusSet = <String>{};
      final localSet = <String>{};

      for (var item in response) {
        if (item['status_sistema'] != null) {
          statusSet.add(item['status_sistema'] as String);
        }
        if (item['local_instalacao'] != null) {
          localSet.add(item['local_instalacao'] as String);
        }
      }

      return {
        'status': statusSet.toList()..sort(),
        'local': localSet.toList()..sort(),
      };
    } catch (e) {
      print('❌ Erro ao buscar valores de filtros: $e');
      return {'status': [], 'local': []};
    }
  }
}

