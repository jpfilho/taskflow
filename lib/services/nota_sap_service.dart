import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert' show latin1, utf8;
import '../models/nota_sap.dart';
import 'auth_service_simples.dart';
import 'centro_trabalho_service.dart';
import 'regra_prazo_nota_service.dart';
import 'ordem_service.dart';

class NotaSAPService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final AuthServiceSimples _authService = AuthServiceSimples();
  final CentroTrabalhoService _centroTrabalhoService = CentroTrabalhoService();
  final RegraPrazoNotaService _regraPrazoNotaService = RegraPrazoNotaService();

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

  // Cache para centros de trabalho do usuário (evita múltiplas chamadas)
  List<Map<String, String>>? _centrosTrabalhoCache;
  String? _centrosTrabalhoCacheUserId;
  DateTime? _centrosTrabalhoCacheTime;
  static const _centrosTrabalhoCacheTimeout = Duration(minutes: 5);

  // Obter centros de trabalho do usuário baseado no perfil
  // Retornar lista de pares (centro, gpm) para o usuário
  Future<List<Map<String, String>>> _obterCentrosTrabalhoComGPMUsuario() async {
    final usuario = _authService.currentUser;
    final userId = usuario?.id;
    
    // Verificar cache
    if (_centrosTrabalhoCache != null && 
        _centrosTrabalhoCacheUserId == userId &&
        _centrosTrabalhoCacheTime != null &&
        DateTime.now().difference(_centrosTrabalhoCacheTime!) < _centrosTrabalhoCacheTimeout) {
      return _centrosTrabalhoCache!;
    }
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
      }).where((centro) => centro.gpm != null).toList(); // Apenas centros com GPM

      // Retornar lista de pares (centro, gpm)
      final centrosComGPM = centrosPermitidos.map((centro) {
        return {
          'centro': centro.centroTrabalho.trim(),
          'gpm': centro.gpm!.toString(),
        };
      }).toList();

      print('🔍 DEBUG _obterCentrosTrabalhoComGPMUsuario:');
      print('   Total de centros no banco: ${todosCentros.length}');
      print('   Centros permitidos para o usuário: ${centrosPermitidos.length}');
      for (final item in centrosComGPM) {
        print('     - ${item['centro']} (GPM: ${item['gpm']})');
      }

      // Atualizar cache
      _centrosTrabalhoCache = centrosComGPM;
      _centrosTrabalhoCacheUserId = userId;
      _centrosTrabalhoCacheTime = DateTime.now();

      return centrosComGPM;
    } catch (e) {
      print('⚠️ Erro ao obter centros de trabalho do usuário: $e');
      return [];
    }
  }

  // Manter método antigo para compatibilidade (retorna apenas nomes)
  Future<List<String>> _obterCentrosTrabalhoUsuario() async {
    final centrosComGPM = await _obterCentrosTrabalhoComGPMUsuario();
    return centrosComGPM.map((item) => item['centro']!).toList();
  }



  // Buscar todas as notas
  Future<List<NotaSAP>> getAllNotas({
    String? filtroTipoNota, // null = todas, 'abertas' = abertas, 'concluidas' = concluídas
    List<String>? filtroLocais,
    List<String>? filtroSalas,
    List<String>? filtroTipos,
    List<String>? filtroNotas,
    List<String>? filtroPrioridades,
    List<String>? filtroStatusUsuario,
    List<String>? filtroResponsaveis,
    List<String>? filtroGPMs,
    int? limit,
    int? offset,
  }) async {
    final totalSw = Stopwatch()..start();
    print('⏱ [getAllNotas] Iniciando | limit=$limit | offset=$offset');
    
    try {
      final querySw = Stopwatch()..start();
      dynamic query = _supabase.from('notas_sap_com_prazo').select();

      // Aplicar filtros por perfil do usuário
      final usuario = _authService.currentUser;
      bool temFiltro = false;
      List<String> centrosTrabalhoUsuario = [];

      // Se o usuário é root, não aplicar filtros de perfil
      if (usuario != null && usuario.isRoot) {
        print('🔓 Usuário root - sem filtros de perfil aplicados');
      } else {
        // Obter centros de trabalho do usuário
        centrosTrabalhoUsuario = await _obterCentrosTrabalhoUsuario();
        
        // Aplicar filtros APENAS pelo centro de trabalho
        if (centrosTrabalhoUsuario.isNotEmpty) {
          final centrosCompletos = centrosTrabalhoUsuario.map((c) => c.trim()).toList();
          
          // Usar ilike com % para buscar qualquer valor que contenha o centro
          if (centrosCompletos.length == 1) {
            query = query.ilike('centro_trabalho_responsavel', '%${centrosCompletos[0]}%');
          } else {
            final orConditions = centrosCompletos.map((centro) => 'centro_trabalho_responsavel.ilike.%$centro%').join(',');
            query = query.or(orConditions);
          }
          
          temFiltro = true;
        }

        // Se o usuário tem perfil mas não tem filtros aplicados, retornar lista vazia
        if (!temFiltro && usuario != null && !usuario.isRoot && usuario.temPerfilConfigurado()) {
          print('⚠️ Usuário com perfil mas sem centros de trabalho - retornando lista vazia');
          return [];
        }
      }

      // Filtros multi-seleção
      // IMPORTANTE: Para múltiplas seleções, usar filtragem no código após buscar
      // O .or() do Supabase pode ter problemas quando combinado com outros filtros
      List<String>? filtroLocaisParaCodigo;
      List<String>? filtroSalasParaCodigo;
      List<String>? filtroTiposParaCodigo;
      List<String>? filtroNotasParaCodigo;
      List<String>? filtroPrioridadesParaCodigo;
      List<String>? filtroStatusUsuarioParaCodigo;
      List<String>? filtroResponsaveisParaCodigo;
      List<String>? filtroGPMsParaCodigo;
      
      if (filtroLocais != null && filtroLocais.isNotEmpty) {
        if (filtroLocais.length == 1) {
          query = query.ilike('local', '%${filtroLocais[0]}%');
        } else {
          // Para múltiplas seleções, vamos filtrar no código
          filtroLocaisParaCodigo = filtroLocais;
        }
      }

      if (filtroSalas != null && filtroSalas.isNotEmpty) {
        if (filtroSalas.length == 1) {
          query = query.ilike('sala', '%${filtroSalas[0]}%');
        } else {
          // Para múltiplas seleções, vamos filtrar no código
          filtroSalasParaCodigo = filtroSalas;
        }
      }

      if (filtroResponsaveis != null && filtroResponsaveis.isNotEmpty) {
        if (filtroResponsaveis.length == 1) {
          query = query.ilike('denominacao_executor', '%${filtroResponsaveis[0]}%');
        } else {
          // Para múltiplas seleções, vamos filtrar no código
          filtroResponsaveisParaCodigo = filtroResponsaveis;
        }
      }

      if (filtroTipos != null && filtroTipos.isNotEmpty) {
        if (filtroTipos.length == 1) {
          query = query.eq('tipo', filtroTipos[0]);
        } else {
          filtroTiposParaCodigo = filtroTipos;
        }
      }

      if (filtroNotas != null && filtroNotas.isNotEmpty) {
        if (filtroNotas.length == 1) {
          query = query.eq('nota', filtroNotas[0]);
        } else {
          filtroNotasParaCodigo = filtroNotas;
        }
      }

      if (filtroPrioridades != null && filtroPrioridades.isNotEmpty) {
        if (filtroPrioridades.length == 1) {
          query = query.eq('text_prioridade', filtroPrioridades[0]);
        } else {
          filtroPrioridadesParaCodigo = filtroPrioridades;
        }
      }

      if (filtroStatusUsuario != null && filtroStatusUsuario.isNotEmpty) {
        if (filtroStatusUsuario.length == 1) {
          query = query.eq('status_usuario', filtroStatusUsuario[0]);
        } else {
          filtroStatusUsuarioParaCodigo = filtroStatusUsuario;
        }
      }

      if (filtroResponsaveis != null && filtroResponsaveis.isNotEmpty) {
        if (filtroResponsaveis.length == 1) {
          query = query.ilike('denominacao_executor', '%${filtroResponsaveis[0]}%');
        } else {
          final orConditions = filtroResponsaveis.map((resp) => 'denominacao_executor.ilike.%$resp%').join(',');
          query = query.or(orConditions);
        }
      }

      if (filtroGPMs != null && filtroGPMs.isNotEmpty) {
        if (filtroGPMs.length == 1) {
          query = query.eq('gpm', filtroGPMs[0]);
        } else {
          filtroGPMsParaCodigo = filtroGPMs;
        }
      }

      // Ordenar por prazo (dias_restantes) antes da paginação
      // NULLS LAST para colocar notas sem prazo por último
      // Ordem crescente: vencidas (negativas) primeiro, depois as que ainda não venceram (positivas)
      query = query.order('dias_restantes', ascending: true, nullsFirst: false);

      if (limit != null) {
        query = query.limit(limit);
      }

      if (offset != null) {
        query = query.range(offset, offset + (limit ?? 100) - 1);
      }

      final response = await query;
      querySw.stop();
      print('⏱ [getAllNotas] Query Supabase concluída em ${querySw.elapsedMilliseconds}ms | registros=${response is List ? response.length : 0}');
      
      final mapSw = Stopwatch()..start();
      // Converter LinkedMap para Map<String, dynamic> se necessário
      var notas = (response as List).map((item) {
        if (item is Map) {
          // Converter LinkedMap ou qualquer Map para Map<String, dynamic>
          final map = item.map((key, value) => MapEntry(key.toString(), value));
          return NotaSAP.fromMap(map);
        }
        return NotaSAP.fromMap(item as Map<String, dynamic>);
      }).toList();
      mapSw.stop();
      print('⏱ [getAllNotas] Mapeamento concluído em ${mapSw.elapsedMilliseconds}ms | notas=${notas.length}');
      
      // O prazo já vem calculado da VIEW notas_sap_com_prazo
      
      final filterSw = Stopwatch()..start();
      // Filtrar no código: sempre excluir MREL e aplicar filtro de tipo
      notas = notas.where((nota) {
        final status = nota.statusSistema?.toUpperCase() ?? '';
        
        // Sempre excluir se contém MREL
        if (status.contains('MREL')) {
          return false;
        }
        
        // Aplicar filtro de tipo de nota
        if (filtroTipoNota == 'abertas') {
          // Abertas: excluir se contém MSEN
          if (status.contains('MSEN')) {
            return false;
          }
        } else if (filtroTipoNota == 'concluidas') {
          // Concluídas: mostrar APENAS se contém MSEN no status_sistema
          if (status.isEmpty || !status.contains('MSEN')) {
            return false;
          }
        }
        
        // Aplicar filtros de múltiplas seleções no código (quando necessário)
        // Filtro de locais (múltiplas seleções)
        if (filtroLocaisParaCodigo != null && filtroLocaisParaCodigo.isNotEmpty) {
          final localNota = nota.local ?? '';
          final matchesLocal = filtroLocaisParaCodigo.any((local) => 
            localNota.toLowerCase().contains(local.toLowerCase())
          );
          if (!matchesLocal) {
            return false;
          }
        }
        
        // Filtro de salas (múltiplas seleções)
        if (filtroSalasParaCodigo != null && filtroSalasParaCodigo.isNotEmpty) {
          final salaNota = nota.sala ?? '';
          final matchesSala = filtroSalasParaCodigo.any((sala) => 
            salaNota.toLowerCase().contains(sala.toLowerCase())
          );
          if (!matchesSala) {
            return false;
          }
        }
        
        // Filtro de responsáveis (múltiplas seleções)
        if (filtroResponsaveisParaCodigo != null && filtroResponsaveisParaCodigo.isNotEmpty) {
          final responsavelNota = nota.denominacaoExecutor ?? '';
          final matchesResponsavel = filtroResponsaveisParaCodigo.any((resp) => 
            responsavelNota.toLowerCase().contains(resp.toLowerCase())
          );
          if (!matchesResponsavel) {
            return false;
          }
        }
        
        // Filtros de múltiplas seleções usando .in_() - agora filtrados no código
        if (filtroTiposParaCodigo != null && filtroTiposParaCodigo.isNotEmpty) {
          if (!filtroTiposParaCodigo.contains(nota.tipo)) {
            return false;
          }
        }
        
        if (filtroNotasParaCodigo != null && filtroNotasParaCodigo.isNotEmpty) {
          if (!filtroNotasParaCodigo.contains(nota.nota)) {
            return false;
          }
        }
        
        if (filtroPrioridadesParaCodigo != null && filtroPrioridadesParaCodigo.isNotEmpty) {
          if (!filtroPrioridadesParaCodigo.contains(nota.textPrioridade)) {
            return false;
          }
        }
        
        if (filtroStatusUsuarioParaCodigo != null && filtroStatusUsuarioParaCodigo.isNotEmpty) {
          if (!filtroStatusUsuarioParaCodigo.contains(nota.statusUsuario)) {
            return false;
          }
        }
        
        if (filtroGPMsParaCodigo != null && filtroGPMsParaCodigo.isNotEmpty) {
          if (!filtroGPMsParaCodigo.contains(nota.gpm)) {
            return false;
          }
        }
        
        return true;
      }).toList();
      filterSw.stop();
      print('⏱ [getAllNotas] Filtros aplicados em ${filterSw.elapsedMilliseconds}ms | notas=${notas.length}');
      
      final sortSw = Stopwatch()..start();
      // Ordenar por prazo (diasRestantes) - nulls por último
      notas.sort((a, b) {
        final diasA = a.diasRestantes ?? 999999;
        final diasB = b.diasRestantes ?? 999999;
        return diasA.compareTo(diasB);
      });
      sortSw.stop();
      print('⏱ [getAllNotas] Ordenação concluída em ${sortSw.elapsedMilliseconds}ms');

      // Enriquecer com status da tarefa vinculada (quando existir)
      final enrichSw = Stopwatch()..start();
      if (notas.isNotEmpty) {
        final notaIds = notas.map((n) => n.id).toList();
        final statusPorNota = <String, String>{};
        const batchSize = 80; // evita URLs gigantes que causam Failed to fetch
        try {
          for (var i = 0; i < notaIds.length; i += batchSize) {
            final batch = notaIds.skip(i).take(batchSize).toList();
            final vinculos = await _supabase
                .from('tasks_notas_sap')
                .select('nota_sap_id, tasks(status)')
                .inFilter('nota_sap_id', batch);

            for (var v in vinculos as List) {
              try {
                final notaId = v['nota_sap_id']?.toString();
                // Converter task (pode ser LinkedMap) para Map<String, dynamic>
                final taskRaw = v['tasks'];
                Map<String, dynamic>? task;
                if (taskRaw is Map) {
                  task = taskRaw.map((key, value) => MapEntry(key.toString(), value));
                }
                final status = task?['status']?.toString();
                if (notaId != null && status != null) {
                  statusPorNota[notaId] = status;
                }
              } catch (e) {
                print('⚠️ Erro ao processar vínculo: $e');
              }
            }
          }

          notas = notas
              .map((n) => statusPorNota.containsKey(n.id)
                  ? n.copyWith(tarefaStatus: statusPorNota[n.id])
                  : n)
              .toList();
        } catch (e) {
          // falha silenciosa para não quebrar carregamento principal
          print('⚠️ Erro ao enriquecer status da tarefa: $e');
        }
      }
      enrichSw.stop();
      totalSw.stop();
      print('⏱ [getAllNotas] Enriquecimento concluído em ${enrichSw.elapsedMilliseconds}ms');
      print('⏱ [getAllNotas] TOTAL: ${totalSw.elapsedMilliseconds}ms | notas=${notas.length}');
      
      return notas;
    } catch (e, stackTrace) {
      print('❌ Erro ao buscar notas: $e');
      print('   Stack trace: $stackTrace');
      return [];
    }
  }

  // Calcular prazo de uma nota (versão assíncrona)
  Future<NotaSAP> calcularPrazoNota(NotaSAP nota, {String? segmentoId}) async {
    try {
      // Se não tem prioridade, não calcula prazo
      if (nota.textPrioridade == null || nota.textPrioridade!.isEmpty) {
        return nota.copyWith(dataVencimento: null, diasRestantes: null);
      }

      // Buscar regra ativa para esta prioridade
      // Tentar primeiro com data de referência = 'inicio_desejado'
      DateTime? dataReferencia;
      String dataReferenciaTipo = 'inicio_desejado';
      
      if (nota.inicioDesejado != null) {
        dataReferencia = nota.inicioDesejado;
        dataReferenciaTipo = 'inicio_desejado';
      } else if (nota.criadoEm != null) {
        dataReferencia = nota.criadoEm;
        dataReferenciaTipo = 'criacao';
      } else {
        // Sem data de referência, não calcula prazo
        return nota.copyWith(dataVencimento: null, diasRestantes: null);
      }

      // Buscar regra ativa
      final regra = await _regraPrazoNotaService.getRegraAtiva(
        nota.textPrioridade!,
        dataReferenciaTipo,
        segmentoId: segmentoId,
      );

      if (regra == null) {
        // Sem regra, não calcula prazo
        return nota.copyWith(dataVencimento: null, diasRestantes: null);
      }

      // Calcular data de vencimento
      final dataVencimento = _regraPrazoNotaService.calcularDataVencimento(regra, dataReferencia);
      if (dataVencimento == null) {
        return nota.copyWith(dataVencimento: null, diasRestantes: null);
      }

      // Calcular dias restantes
      final hoje = DateTime.now();
      final apenasDataHoje = DateTime(hoje.year, hoje.month, hoje.day);
      final apenasDataVencimento = DateTime(dataVencimento.year, dataVencimento.month, dataVencimento.day);
      final diasRestantes = apenasDataVencimento.difference(apenasDataHoje).inDays;

      return nota.copyWith(
        dataVencimento: dataVencimento,
        diasRestantes: diasRestantes,
      );
    } catch (e) {
      print('Erro ao calcular prazo da nota: $e');
      return nota;
    }
  }

  // Buscar nota por ID
  Future<NotaSAP?> getNotaById(String id) async {
    try {
      final response = await _supabase
          .from('notas_sap_com_prazo')
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
          .from('notas_sap_com_prazo')
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
      // Verificar se já está vinculada antes de inserir
      final vinculoExistente = await _supabase
          .from('tasks_notas_sap')
          .select('id')
          .eq('task_id', taskId)
          .eq('nota_sap_id', notaSapId)
          .maybeSingle();
      
      if (vinculoExistente != null) {
        print('ℹ️ Nota $notaSapId já está vinculada à tarefa $taskId');
        return;
      }
      
      // Vincular a nota
      await _supabase.from('tasks_notas_sap').insert({
        'task_id': taskId,
        'nota_sap_id': notaSapId,
      });
      print('✅ Nota vinculada à tarefa');
      
      // Buscar a nota para obter o número da ordem
      print('🔍 Buscando nota $notaSapId para obter número da ordem...');
      final notaResponse = await _supabase
          .from('notas_sap_com_prazo')
          .select('id, ordem, nota')
          .eq('id', notaSapId)
          .maybeSingle();
      
      print('📋 Resposta completa da nota: $notaResponse');
      print('📋 Nota ID: ${notaResponse?['id']}');
      print('📋 Nota número: ${notaResponse?['nota']}');
      print('📋 Ordem na nota: ${notaResponse?['ordem']}');
      print('📋 Tipo da ordem: ${notaResponse?['ordem']?.runtimeType}');
      
      if (notaResponse != null && notaResponse['ordem'] != null) {
        final ordemNumeroRaw = notaResponse['ordem'];
        final ordemNumero = ordemNumeroRaw?.toString().trim();
        
        print('🔢 Número da ordem encontrado (raw): $ordemNumeroRaw');
        print('🔢 Número da ordem encontrado (trimmed): $ordemNumero');
        
        if (ordemNumero != null && ordemNumero.isNotEmpty) {
          // Buscar a ordem correspondente pelo número
          print('🔍 Buscando ordem com número "$ordemNumero"...');
          try {
            final ordemResponse = await _supabase
                .from('ordens')
                .select('id')
                .eq('ordem', ordemNumero)
                .maybeSingle();
            
            print('📋 Resposta da ordem: $ordemResponse');
            
            if (ordemResponse != null && ordemResponse['id'] != null) {
              final ordemId = ordemResponse['id'] as String;
              print('✅ Ordem encontrada com ID: $ordemId');
              
              // Vincular a ordem automaticamente usando o serviço de ordens
              // Isso também vinculará automaticamente outras notas com a mesma ordem (comportamento correto)
              print('🔗 Vinculando ordem $ordemId à tarefa $taskId...');
              try {
                final ordemService = OrdemService();
                await ordemService.vincularOrdemATarefa(taskId, ordemId);
                print('✅ Ordem $ordemNumero vinculada automaticamente à tarefa');
              } catch (e, stackTrace) {
                print('❌ Erro ao vincular ordem automaticamente: $e');
                print('❌ Stack trace: $stackTrace');
                print('   Task ID: $taskId');
                print('   Ordem ID: $ordemId');
                print('   Ordem Número: $ordemNumero');
                // Não fazer rethrow - a vinculação da nota já foi feita
              }
            } else {
              print('⚠️ Ordem "$ordemNumero" não encontrada no banco de dados');
              print('   Verificando se existe ordem com número similar...');
              // Tentar buscar sem filtro exato para debug
              try {
                final todasOrdens = await _supabase
                    .from('ordens')
                    .select('id, ordem')
                    .limit(5);
                print('   Primeiras 5 ordens no banco: $todasOrdens');
              } catch (e) {
                print('   Erro ao buscar ordens para debug: $e');
              }
            }
          } catch (e, stackTrace) {
            print('❌ Erro ao buscar ordem no banco: $e');
            print('❌ Stack trace: $stackTrace');
          }
        } else {
          print('⚠️ Número da ordem está vazio após trim');
        }
      } else {
        print('⚠️ Nota não possui número de ordem ou ordem é nula');
        print('   Resposta completa da nota: $notaResponse');
      }
    } catch (e, stackTrace) {
      print('❌ Erro ao vincular nota: $e');
      print('❌ Stack trace: $stackTrace');
      // Não fazer rethrow para não interromper o processo
      // A vinculação da nota principal já foi feita, apenas a automática falhou
    }
  }

  // Desvincular nota de uma tarefa
  Future<void> desvincularNotaDeTarefa(String taskId, String notaSapId) async {
    try {
      // Buscar a nota para obter o número da ordem
      final notaResponse = await _supabase
          .from('notas_sap_com_prazo')
          .select('ordem')
          .eq('id', notaSapId)
          .maybeSingle();
      
      String? ordemNumero;
      if (notaResponse != null && notaResponse['ordem'] != null) {
        ordemNumero = notaResponse['ordem'] as String;
      }
      
      // Desvincular a nota
      await _supabase
          .from('tasks_notas_sap')
          .delete()
          .eq('task_id', taskId)
          .eq('nota_sap_id', notaSapId);
      print('✅ Nota desvinculada da tarefa');
      
      // Se havia uma ordem associada, verificar se ainda há outras notas vinculadas
      if (ordemNumero != null) {
        // Buscar todas as notas vinculadas a esta tarefa com o mesmo número de ordem
        final outrasNotasResponse = await _supabase
            .from('tasks_notas_sap')
            .select('nota_sap_id')
            .eq('task_id', taskId);
        
        if (outrasNotasResponse.isNotEmpty) {
          final outrasNotasIds = (outrasNotasResponse as List)
              .map((item) => item['nota_sap_id'] as String)
              .toList();
          
          // Verificar se alguma das outras notas tem o mesmo número de ordem
          bool temNotaComMesmaOrdem = false;
          for (final notaId in outrasNotasIds) {
            try {
              final nota = await _supabase
                  .from('notas_sap_com_local')
                  .select('ordem')
                  .eq('id', notaId)
                  .maybeSingle();
              if (nota != null && nota['ordem'] == ordemNumero) {
                temNotaComMesmaOrdem = true;
                break;
              }
            } catch (e) {
              // Ignorar erros individuais
            }
          }
          
          // Se não há mais notas com este número de ordem vinculadas, desvincular a ordem
          if (!temNotaComMesmaOrdem) {
            final ordemResponse = await _supabase
                .from('ordens')
                .select('id')
                .eq('ordem', ordemNumero)
                .maybeSingle();
            
            if (ordemResponse != null) {
              final ordemId = ordemResponse['id'] as String;
              await _supabase
                  .from('tasks_ordens')
                  .delete()
                  .eq('task_id', taskId)
                  .eq('ordem_id', ordemId);
              print('✅ Ordem $ordemNumero desvinculada automaticamente (nenhuma nota restante)');
            }
          } else {
            print('ℹ️ Ordem $ordemNumero mantida vinculada (ainda há outras notas)');
          }
        } else {
          // Não há mais notas vinculadas, desvincular a ordem se existir
          final ordemResponse = await _supabase
              .from('ordens')
              .select('id')
              .eq('ordem', ordemNumero)
              .maybeSingle();
          
          if (ordemResponse != null) {
            final ordemId = ordemResponse['id'] as String;
            await _supabase
                .from('tasks_ordens')
                .delete()
                .eq('task_id', taskId)
                .eq('ordem_id', ordemId);
            print('✅ Ordem $ordemNumero desvinculada automaticamente');
          }
        }
      }
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
          .select('notas_sap_com_prazo(*)')
          .eq('task_id', taskId);

      return (response as List)
          .map((item) => NotaSAP.fromMap(item['notas_sap_com_prazo'] as Map<String, dynamic>))
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

  // Contar notas vinculadas por tarefas
  Future<Map<String, int>> contarNotasPorTarefas(List<String> taskIds) async {
    try {
      if (taskIds.isEmpty) return {};

      // Usar VIEW otimizada do Supabase para buscar todas as contagens de uma vez
      // Usar .or() para múltiplos valores (já funciona no código)
      dynamic query = _supabase
          .from('contagens_notas_sap_tarefas')
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
        // Converter LinkedMap para Map<String, dynamic> se necessário
        Map<String, dynamic> itemMap;
        if (item is Map) {
          itemMap = item.map((key, value) => MapEntry(key.toString(), value));
        } else {
          itemMap = item as Map<String, dynamic>;
        }
        
        final taskId = itemMap['task_id']?.toString();
        final quantidadeRaw = itemMap['quantidade'];
        final quantidade = quantidadeRaw is int ? quantidadeRaw : (quantidadeRaw != null ? int.tryParse(quantidadeRaw.toString()) : null);
        if (taskId != null && quantidade != null && quantidade > 0) {
          contagens[taskId] = quantidade;
        }
      }

      return contagens;
    } catch (e) {
      print('❌ Erro ao contar notas das tarefas: $e');
      return {};
    }
  }

  // Buscar notas programadas (vinculadas a tarefas) com informações das tarefas
  Future<List<Map<String, dynamic>>> getNotasProgramadas() async {
    try {
      dynamic query = _supabase.from('tasks_notas_sap').select('''
            id,
            created_at,
            notas_sap_com_prazo(
              *,
              centro_trabalho_responsavel
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
      final centrosTrabalhoUsuario = await _obterCentrosTrabalhoUsuario();
      final usuario = _authService.currentUser;
      
      List<dynamic> filteredResponse = response as List;
      
      if (centrosTrabalhoUsuario.isNotEmpty) {
        filteredResponse = filteredResponse.where((item) {
          // Converter LinkedMap para Map<String, dynamic> se necessário
          final notaRaw = item['notas_sap_com_prazo'];
          Map<String, dynamic>? nota;
          if (notaRaw is Map) {
            nota = notaRaw.map((key, value) => MapEntry(key.toString(), value));
          } else if (notaRaw != null) {
            nota = notaRaw as Map<String, dynamic>?;
          }
          if (nota == null) return false;
          
          // Filtrar por centro de trabalho
          final centroTrabalho = nota['centro_trabalho_responsavel']?.toString();
          if (centroTrabalho == null) return false;
          
          final centroTrabalhoUpper = centroTrabalho.trim().toUpperCase();
          return centrosTrabalhoUsuario.any((centro) {
            final centroUpper = centro.trim().toUpperCase();
            return centroTrabalhoUpper.contains(centroUpper) || centroUpper.contains(centroTrabalhoUpper);
          });
        }).toList();
      } else if (usuario != null && !usuario.isRoot && usuario.temPerfilConfigurado()) {
        // Se o usuário tem perfil mas não tem centros de trabalho, retornar lista vazia
        print('⚠️ Usuário com perfil mas sem centros de trabalho - retornando lista vazia');
        return [];
      }

      return filteredResponse.map((item) {
        // Converter LinkedMap para Map<String, dynamic> se necessário
        Map<String, dynamic> itemMap;
        if (item is Map) {
          itemMap = item.map((key, value) => MapEntry(key.toString(), value));
        } else {
          itemMap = item as Map<String, dynamic>;
        }
        
        // Converter notas_sap_com_prazo se necessário
        Map<String, dynamic>? notaMap;
        final notaRaw = itemMap['notas_sap_com_prazo'];
        if (notaRaw is Map) {
          notaMap = notaRaw.map((key, value) => MapEntry(key.toString(), value));
        } else if (notaRaw != null) {
          notaMap = notaRaw as Map<String, dynamic>?;
        }
        
        // Converter tasks se necessário
        Map<String, dynamic>? taskMap;
        final taskRaw = itemMap['tasks'];
        if (taskRaw is Map) {
          taskMap = taskRaw.map((key, value) => MapEntry(key.toString(), value));
        } else if (taskRaw != null) {
          taskMap = taskRaw as Map<String, dynamic>?;
        }
        
        return {
          'vinculo_id': itemMap['id'],
          'vinculado_em': itemMap['created_at'] != null 
              ? DateTime.parse(itemMap['created_at'].toString())
              : null,
          'nota': notaMap != null ? NotaSAP.fromMap(notaMap) : null,
          'tarefa': taskMap,
        };
      }).toList();
    } catch (e) {
      print('❌ Erro ao buscar notas programadas: $e');
      return [];
    }
  }

  // Contar notas
  Future<int> contarNotas({
    String? filtroTipoNota, // null = todas, 'abertas' = abertas, 'concluidas' = concluídas
    List<String>? filtroLocais,
    List<String>? filtroTipos,
    List<String>? filtroNotas,
    List<String>? filtroPrioridades,
    List<String>? filtroStatusUsuario,
    List<String>? filtroResponsaveis,
    List<String>? filtroGPMs,
  }) async {
    try {
      dynamic query = _supabase.from('notas_sap_com_prazo').select('id, centro_trabalho_responsavel');

      // Aplicar filtros por perfil do usuário
      final usuario = _authService.currentUser;
      bool temFiltro = false;
      List<String> centrosTrabalhoUsuario = [];

      if (usuario != null && !usuario.isRoot && usuario.temPerfilConfigurado()) {
        centrosTrabalhoUsuario = await _obterCentrosTrabalhoUsuario();
        
        // Aplicar filtros APENAS pelo centro de trabalho
        if (centrosTrabalhoUsuario.isNotEmpty) {
          final centrosCompletos = centrosTrabalhoUsuario.map((c) => c.trim()).toList();
          
          // Usar ilike com % para buscar qualquer valor que contenha o centro
          if (centrosCompletos.length == 1) {
            query = query.ilike('centro_trabalho_responsavel', '%${centrosCompletos[0]}%');
          } else {
            final orConditions = centrosCompletos.map((centro) => 'centro_trabalho_responsavel.ilike.%$centro%').join(',');
            query = query.or(orConditions);
          }
          
          temFiltro = true;
        }
      }

      // Se o usuário tem perfil mas não tem filtros aplicados, retornar 0
      if (!temFiltro && usuario != null && !usuario.isRoot && usuario.temPerfilConfigurado()) {
        return 0;
      }

      // Filtros multi-seleção
      // Declarar variáveis para filtragem no código quando necessário
      List<String>? filtroTiposParaCodigo;
      List<String>? filtroNotasParaCodigo;
      List<String>? filtroPrioridadesParaCodigo;
      List<String>? filtroStatusUsuarioParaCodigo;
      List<String>? filtroGPMsParaCodigo;
      
      if (filtroLocais != null && filtroLocais.isNotEmpty) {
        if (filtroLocais.length == 1) {
          query = query.ilike('local', '%${filtroLocais[0]}%');
        } else {
          final orConditions = filtroLocais.map((local) => 'local.ilike.%$local%').join(',');
          query = query.or(orConditions);
        }
      }

      if (filtroTipos != null && filtroTipos.isNotEmpty) {
        if (filtroTipos.length == 1) {
          query = query.eq('tipo', filtroTipos[0]);
        } else {
          filtroTiposParaCodigo = filtroTipos;
        }
      }

      if (filtroNotas != null && filtroNotas.isNotEmpty) {
        if (filtroNotas.length == 1) {
          query = query.eq('nota', filtroNotas[0]);
        } else {
          filtroNotasParaCodigo = filtroNotas;
        }
      }

      if (filtroPrioridades != null && filtroPrioridades.isNotEmpty) {
        if (filtroPrioridades.length == 1) {
          query = query.eq('text_prioridade', filtroPrioridades[0]);
        } else {
          filtroPrioridadesParaCodigo = filtroPrioridades;
        }
      }

      if (filtroStatusUsuario != null && filtroStatusUsuario.isNotEmpty) {
        if (filtroStatusUsuario.length == 1) {
          query = query.eq('status_usuario', filtroStatusUsuario[0]);
        } else {
          filtroStatusUsuarioParaCodigo = filtroStatusUsuario;
        }
      }

      if (filtroResponsaveis != null && filtroResponsaveis.isNotEmpty) {
        if (filtroResponsaveis.length == 1) {
          query = query.ilike('denominacao_executor', '%${filtroResponsaveis[0]}%');
        } else {
          final orConditions = filtroResponsaveis.map((resp) => 'denominacao_executor.ilike.%$resp%').join(',');
          query = query.or(orConditions);
        }
      }

      if (filtroGPMs != null && filtroGPMs.isNotEmpty) {
        if (filtroGPMs.length == 1) {
          query = query.eq('gpm', filtroGPMs[0]);
        } else {
          filtroGPMsParaCodigo = filtroGPMs;
        }
      }

      final response = await query;
      var notas = (response as List);
      
      // Filtrar no código: sempre excluir MREL e aplicar filtro de tipo
      notas = notas.where((item) {
        final status = (item['status_sistema'] as String?)?.toUpperCase() ?? '';
        
        // Sempre excluir se contém MREL
        if (status.contains('MREL')) {
          return false;
        }
        
        // Aplicar filtro de tipo de nota
        if (filtroTipoNota == 'abertas') {
          // Abertas: excluir se contém MSEN
          if (status.contains('MSEN')) {
            return false;
          }
        } else if (filtroTipoNota == 'concluidas') {
          // Concluídas: mostrar APENAS se contém MSEN no status_sistema
          if (status.isEmpty || !status.contains('MSEN')) {
            return false;
          }
        }
        
        return true;
      }).toList();
      
      return notas.length;
    } catch (e) {
      print('❌ Erro ao contar notas: $e');
      return 0;
    }
  }

  // Buscar valores únicos para filtros
  Future<Map<String, List<String>>> getValoresFiltros({
    String? filtroTipoNota,
    List<String>? filtroLocais,
    List<String>? filtroSalas,
    List<String>? filtroTipos,
    List<String>? filtroNotas,
    List<String>? filtroPrioridades,
    List<String>? filtroStatusUsuario,
    List<String>? filtroResponsaveis,
    List<String>? filtroGPMs,
  }) async {
    try {
      dynamic query = _supabase.from('notas_sap_com_prazo').select('status_sistema, local, sala, tipo, nota, text_prioridade, status_usuario, denominacao_executor, gpm');

      // Aplicar filtros por perfil do usuário
      final usuario = _authService.currentUser;
      bool temFiltro = false;

      // Se o usuário é root, não aplicar filtros de perfil
      if (usuario != null && usuario.isRoot) {
        print('🔓 Usuário root - sem filtros de perfil aplicados');
      } else {
        // Obter centros de trabalho do usuário
        final centrosTrabalhoUsuario = await _obterCentrosTrabalhoUsuario();
        
        // Aplicar filtros APENAS pelo centro de trabalho
        if (centrosTrabalhoUsuario.isNotEmpty) {
          final centrosCompletos = centrosTrabalhoUsuario.map((c) => c.trim()).toList();
          
          // Usar ilike com % para buscar qualquer valor que contenha o centro
          if (centrosCompletos.length == 1) {
            query = query.ilike('centro_trabalho_responsavel', '%${centrosCompletos[0]}%');
          } else {
            final orConditions = centrosCompletos.map((centro) => 'centro_trabalho_responsavel.ilike.%$centro%').join(',');
            query = query.or(orConditions);
          }
          
          temFiltro = true;
        }

        // Se o usuário tem perfil mas não tem filtros aplicados, retornar filtros vazios
        if (!temFiltro && usuario != null && !usuario.isRoot && usuario.temPerfilConfigurado()) {
          return {
            'status': [],
            'local': [],
            'sala': [],
            'tipo': [],
            'nota': [],
            'prioridade': [],
            'status_usuario': [],
            'responsavel': [],
            'gpm': [],
          };
        }
      }

      // Aplicar filtros de tipo de nota (abertas/concluídas)
      // Isso será filtrado no código após buscar, mas não afeta os valores disponíveis

      // Aplicar os filtros ativos para que os valores disponíveis reflitam apenas as opções válidas
      // IMPORTANTE: Para cada campo, aplicar TODOS os outros filtros, mas NÃO aplicar o filtro do próprio campo.
      // Isso garante que os filtros sejam interdependentes: se Local = ELM está filtrado,
      // ao buscar Prioridade, queremos ver apenas as prioridades que existem para ELM.
      
      // Função auxiliar para aplicar filtros (exceto um campo específico)
      dynamic aplicarFiltrosExceto(dynamic q, String? campoExcluir) {
        // Aplicar filtro de locais (exceto se for o campo que estamos buscando)
        if (campoExcluir != 'local' && filtroLocais != null && filtroLocais.isNotEmpty) {
          if (filtroLocais.length == 1) {
            q = q.ilike('local', '%${filtroLocais[0]}%');
          } else {
            final orConditions = filtroLocais.map((local) => 'local.ilike.%$local%').join(',');
            q = q.or(orConditions);
          }
        }

        // Aplicar filtro de salas (exceto se for o campo que estamos buscando)
        if (campoExcluir != 'sala' && filtroSalas != null && filtroSalas.isNotEmpty) {
          if (filtroSalas.length == 1) {
            q = q.ilike('sala', '%${filtroSalas[0]}%');
          } else {
            final orConditions = filtroSalas.map((sala) => 'sala.ilike.%$sala%').join(',');
            q = q.or(orConditions);
          }
        }
        
        // Aplicar filtro de tipos (exceto se for o campo que estamos buscando)
        // Para múltiplas seleções, vamos filtrar no código depois
        if (campoExcluir != 'tipo' && filtroTipos != null && filtroTipos.isNotEmpty) {
          if (filtroTipos.length == 1) {
            q = q.eq('tipo', filtroTipos[0]);
          }
          // Para múltiplas seleções, não aplicar aqui - será filtrado no código
        }

        // Aplicar filtro de notas (exceto se for o campo que estamos buscando)
        // Para múltiplas seleções, vamos filtrar no código depois
        if (campoExcluir != 'nota' && filtroNotas != null && filtroNotas.isNotEmpty) {
          if (filtroNotas.length == 1) {
            q = q.eq('nota', filtroNotas[0]);
          }
          // Para múltiplas seleções, não aplicar aqui - será filtrado no código
        }

        // Aplicar filtro de prioridades (exceto se for o campo que estamos buscando)
        // Para múltiplas seleções, vamos filtrar no código depois
        if (campoExcluir != 'prioridade' && filtroPrioridades != null && filtroPrioridades.isNotEmpty) {
          if (filtroPrioridades.length == 1) {
            q = q.eq('text_prioridade', filtroPrioridades[0]);
          }
          // Para múltiplas seleções, não aplicar aqui - será filtrado no código
        }

        // Aplicar filtro de status usuário (exceto se for o campo que estamos buscando)
        // Para múltiplas seleções, vamos filtrar no código depois
        if (campoExcluir != 'status_usuario' && filtroStatusUsuario != null && filtroStatusUsuario.isNotEmpty) {
          if (filtroStatusUsuario.length == 1) {
            q = q.eq('status_usuario', filtroStatusUsuario[0]);
          }
          // Para múltiplas seleções, não aplicar aqui - será filtrado no código
        }

        // Aplicar filtro de responsáveis (exceto se for o campo que estamos buscando)
        if (campoExcluir != 'responsavel' && filtroResponsaveis != null && filtroResponsaveis.isNotEmpty) {
          if (filtroResponsaveis.length == 1) {
            q = q.ilike('denominacao_executor', '%${filtroResponsaveis[0]}%');
          } else {
            final orConditions = filtroResponsaveis.map((resp) => 'denominacao_executor.ilike.%$resp%').join(',');
            q = q.or(orConditions);
          }
        }

        // Aplicar filtro de GPMs (exceto se for o campo que estamos buscando)
        // Para múltiplas seleções, vamos filtrar no código depois
        if (campoExcluir != 'gpm' && filtroGPMs != null && filtroGPMs.isNotEmpty) {
          if (filtroGPMs.length == 1) {
            q = q.eq('gpm', filtroGPMs[0]);
          }
          // Para múltiplas seleções, não aplicar aqui - será filtrado no código
        }
        
        return q;
      }
      
      // Buscar valores para cada campo separadamente, aplicando todos os filtros EXCETO o do próprio campo
      final localSet = <String>{};
      final salaSet = <String>{};
      final tipoSet = <String>{};
      final notaSet = <String>{};
      final prioridadeSet = <String>{};
      final statusUsuarioSet = <String>{};
      final responsavelSet = <String>{};
      final gpmSet = <String>{};
      
      // Função auxiliar para processar resposta e extrair valores
      void processarResposta(List response, String campo) {
        final itemsFiltrados = response.where((item) {
          final status = (item['status_sistema'] as String? ?? '').toUpperCase();
          
          // Sempre excluir se contém MREL
          if (status.contains('MREL')) {
            return false;
          }
          
          // Aplicar filtro de tipo de nota
          if (filtroTipoNota == 'abertas') {
            // Excluir MSEN (concluídas)
            if (status.contains('MSEN')) {
              return false;
            }
          } else if (filtroTipoNota == 'concluidas') {
            // Apenas incluir se contém MSEN
            if (!status.contains('MSEN')) {
              return false;
            }
          }
          
          // Aplicar filtros de múltiplas seleções no código
          if (filtroTipos != null && filtroTipos.length > 1) {
            final tipo = item['tipo'] as String? ?? '';
            if (!filtroTipos.contains(tipo)) {
              return false;
            }
          }
          
          if (filtroNotas != null && filtroNotas.length > 1) {
            final nota = item['nota'] as String? ?? '';
            if (!filtroNotas.contains(nota)) {
              return false;
            }
          }
          
          if (filtroPrioridades != null && filtroPrioridades.length > 1) {
            final prioridade = item['text_prioridade'] as String? ?? '';
            if (!filtroPrioridades.contains(prioridade)) {
              return false;
            }
          }
          
          if (filtroStatusUsuario != null && filtroStatusUsuario.length > 1) {
            final statusUsuario = item['status_usuario'] as String? ?? '';
            if (!filtroStatusUsuario.contains(statusUsuario)) {
              return false;
            }
          }
          
          if (filtroGPMs != null && filtroGPMs.length > 1) {
            final gpm = item['gpm'] as String? ?? '';
            if (!filtroGPMs.contains(gpm)) {
              return false;
            }
          }
          
          return true;
        }).toList();
        
        for (var item in itemsFiltrados) {
          if (campo == 'local' && item['local'] != null) {
            localSet.add(item['local'] as String);
          } else if (campo == 'sala' && item['sala'] != null) {
            salaSet.add(item['sala'] as String);
          } else if (campo == 'tipo' && item['tipo'] != null) {
            tipoSet.add(item['tipo'] as String);
          } else if (campo == 'nota' && item['nota'] != null) {
            notaSet.add(item['nota'] as String);
          } else if (campo == 'prioridade' && item['text_prioridade'] != null) {
            prioridadeSet.add(item['text_prioridade'] as String);
          } else if (campo == 'status_usuario' && item['status_usuario'] != null) {
            statusUsuarioSet.add(item['status_usuario'] as String);
          } else if (campo == 'responsavel' && item['denominacao_executor'] != null) {
            responsavelSet.add(item['denominacao_executor'] as String);
          } else if (campo == 'gpm' && item['gpm'] != null) {
            gpmSet.add(item['gpm'] as String);
          }
        }
      }
      
      // Buscar valores para cada campo separadamente
      final campos = [
        {'nome': 'local', 'campo': 'local'},
        {'nome': 'sala', 'campo': 'sala'},
        {'nome': 'tipo', 'campo': 'tipo'},
        {'nome': 'nota', 'campo': 'nota'},
        {'nome': 'prioridade', 'campo': 'text_prioridade'},
        {'nome': 'status_usuario', 'campo': 'status_usuario'},
        {'nome': 'responsavel', 'campo': 'denominacao_executor'},
        {'nome': 'gpm', 'campo': 'gpm'},
      ];
      
      for (final campoInfo in campos) {
        final campoNome = campoInfo['nome'] as String;
        
        dynamic campoQuery = _supabase.from('notas_sap_com_prazo').select('status_sistema, local, sala, tipo, nota, text_prioridade, status_usuario, denominacao_executor, gpm');
        
        // Aplicar filtros de perfil (mesma lógica do query principal)
        if (usuario != null && usuario.isRoot) {
          // Sem filtros de perfil para root
        } else {
          final centrosTrabalhoUsuario = await _obterCentrosTrabalhoUsuario();
          if (centrosTrabalhoUsuario.isNotEmpty) {
            final centrosCompletos = centrosTrabalhoUsuario.map((c) => c.trim()).toList();
            if (centrosCompletos.length == 1) {
              campoQuery = campoQuery.ilike('centro_trabalho_responsavel', '%${centrosCompletos[0]}%');
            } else {
              final orConditions = centrosCompletos.map((centro) => 'centro_trabalho_responsavel.ilike.%$centro%').join(',');
              campoQuery = campoQuery.or(orConditions);
            }
          } else {
            if (usuario != null && !usuario.isRoot && usuario.temPerfilConfigurado()) {
              continue; // Pular este campo se não há filtros de perfil
            }
          }
        }
        
        // Aplicar todos os filtros EXCETO o do próprio campo
        campoQuery = aplicarFiltrosExceto(campoQuery, campoNome);
        
        try {
          final campoResponse = await campoQuery;
          processarResposta(campoResponse as List, campoNome);
        } catch (e) {
          print('⚠️ Erro ao buscar valores para campo $campoNome: $e');
        }
      }

      return {
        'status': [], // Status não é mais usado como filtro
        'local': localSet.toList()..sort(),
        'sala': salaSet.toList()..sort(),
        'tipo': tipoSet.toList()..sort(),
        'nota': notaSet.toList()..sort(),
        'prioridade': prioridadeSet.toList()..sort(),
        'status_usuario': statusUsuarioSet.toList()..sort(),
        'responsavel': responsavelSet.toList()..sort(),
        'gpm': gpmSet.toList()..sort(),
      };
    } catch (e) {
      print('❌ Erro ao buscar valores de filtros: $e');
      return {
        'status': [],
        'local': [],
        'sala': [],
        'tipo': [],
        'nota': [],
        'prioridade': [],
        'status_usuario': [],
        'responsavel': [],
        'gpm': [],
      };
    }
  }
}

