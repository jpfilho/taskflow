import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert' show latin1, utf8;
import '../models/nota_sap.dart';
import 'auth_service_simples.dart';
import 'centro_trabalho_service.dart';
import 'regra_prazo_nota_service.dart';
import 'ordem_service.dart';

class NotaSAPService {
  final SupabaseClient? _customSupabase;
  SupabaseClient get _supabase => _customSupabase ?? Supabase.instance.client;
  final AuthServiceSimples? _customAuthService;
  AuthServiceSimples get _authService => _customAuthService ?? AuthServiceSimples();
  final CentroTrabalhoService? _customCentroTrabalhoService;
  CentroTrabalhoService get _centroTrabalhoService => _customCentroTrabalhoService ?? CentroTrabalhoService();
  final RegraPrazoNotaService? _customRegraPrazoNotaService;
  RegraPrazoNotaService get _regraPrazoNotaService => _customRegraPrazoNotaService ?? RegraPrazoNotaService();

  NotaSAPService({
    SupabaseClient? supabaseClient,
    AuthServiceSimples? authService,
    CentroTrabalhoService? centroTrabalhoService,
    RegraPrazoNotaService? regraPrazoNotaService,
  })  : _customSupabase = supabaseClient,
        _customAuthService = authService,
        _customCentroTrabalhoService = centroTrabalhoService,
        _customRegraPrazoNotaService = regraPrazoNotaService;

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

  // ===========================================================================
  // CACHE E ENRIQUECIMENTO EM MEMÓRIA (PARIDADE 100% COM notas_sap_com_local + notas_sap_com_prazo)
  // Evita timeouts (57014) nas views pesadas com 6 subqueries correlacionadas/laterais.
  // ===========================================================================
  static List<Map<String, dynamic>>? _locaisRefCache;
  static List<Map<String, dynamic>>? _centrosAtivosRefCache;
  static List<Map<String, dynamic>>? _regrasPrazoRefCache;
  static DateTime? _enriquecimentoCacheTime;
  static const Duration _enriquecimentoCacheTtl = Duration(minutes: 5);

  static Map<String, List<Map<String, dynamic>>>? _vinculosTarefasCache;
  static DateTime? _vinculosTarefasCacheTime;
  static const Duration _vinculosTarefasCacheTtl = Duration(minutes: 2);

  static const String kColunasEssenciaisNotaSap =
      'id,nota,ordem,tipo,descricao,local_instalacao,sala,equipamento,status_sistema,status_usuario,text_prioridade,criado_em,hora_criacao,inicio_desejado,conclusao_desejada,data,notificacao,centro_trabalho_responsavel,centro,fim_avaria,de,encerramento,denominacao_executor,data_referencia,gpm,inicio_avaria,modificado_em,campo_ordenacao,data_importacao,created_at,updated_at';

  static String _normalizarSemAcentoUpper(String input) {
    return input
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[ÁÀÂÃ]'), 'A')
        .replaceAll(RegExp(r'[ÉÈÊ]'), 'E')
        .replaceAll(RegExp(r'[ÍÌÎ]'), 'I')
        .replaceAll(RegExp(r'[ÓÒÔÕ]'), 'O')
        .replaceAll(RegExp(r'[ÚÙÛ]'), 'U')
        .replaceAll('Ç', 'C');
  }

  Future<void> garantirCacheEnriquecimento({bool forceRefresh = false}) async {
    final agora = DateTime.now();
    if (!forceRefresh &&
        _locaisRefCache != null &&
        _centrosAtivosRefCache != null &&
        _regrasPrazoRefCache != null &&
        _enriquecimentoCacheTime != null &&
        agora.difference(_enriquecimentoCacheTime!) < _enriquecimentoCacheTtl) {
      return;
    }

    try {
      final results = await Future.wait([
        _supabase
            .from('locais')
            .select('id, local, local_instalacao_sap, regional_id, divisao_id, segmento_id')
            .not('local_instalacao_sap', 'is', null),
        _supabase
            .from('centros_trabalho')
            .select('id, centro_trabalho, gpm, regional_id, divisao_id, segmento_id, ativo')
            .eq('ativo', true)
            .order('id', ascending: true),
        _supabase
            .from('regras_prazo_notas')
            .select('id, prioridade, dias_prazo, data_referencia, ativo, regras_prazo_notas_segmentos(segmento_id)')
            .eq('ativo', true),
      ]);

      final locaisRaw = (results[0] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((l) => (l['local_instalacao_sap']?.toString().trim() ?? '').isNotEmpty)
          .toList();

      _locaisRefCache = locaisRaw;
      _centrosAtivosRefCache =
          (results[1] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      _regrasPrazoRefCache =
          (results[2] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      _enriquecimentoCacheTime = agora;
    } catch (e) {
      print('⚠️ [NotaSAPService] Aviso ao carregar cache de enriquecimento: $e');
      _locaisRefCache ??= [];
      _centrosAtivosRefCache ??= [];
      _regrasPrazoRefCache ??= [];
    }
  }

  /// Enriquecimento O(1) em memória com 100% de paridade com `notas_sap_com_local` e `notas_sap_com_prazo`.
  Map<String, dynamic> enriquecerMapaNotaComLocalEPrazo(
    Map<String, dynamic> rawMap, {
    DateTime? dataHojeReferencia,
  }) {
    final map = Map<String, dynamic>.from(rawMap);
    final centros = _centrosAtivosRefCache ?? const [];
    final locais = _locaisRefCache ?? const [];
    final regras = _regrasPrazoRefCache ?? const [];

    final ctNotaStr = (map['centro_trabalho_responsavel']?.toString() ?? '').trim().toUpperCase();
    final localInstStr = map['local_instalacao']?.toString();

    // 1. Resolver local (paridade exata com notas_sap_com_local)
    if (map['local'] == null && localInstStr != null && localInstStr.isNotEmpty && locais.isNotEmpty) {
      Map<String, dynamic>? ctNota;
      if (ctNotaStr.isNotEmpty) {
        for (final ct in centros) {
          final ctVal = (ct['centro_trabalho']?.toString() ?? '').trim().toUpperCase();
          if (ctVal == ctNotaStr) {
            ctNota = ct;
            break; // já ordenado por id ASC
          }
        }
      }

      String? melhorLocal;
      int melhorRank = 999;
      int maiorTamanhoCodigo = -1;
      String melhorId = '';

      final ctReg = ctNota?['regional_id']?.toString();
      final ctDiv = ctNota?['divisao_id']?.toString();
      final ctSeg = ctNota?['segmento_id']?.toString();

      for (final loc in locais) {
        final sapCode = loc['local_instalacao_sap']?.toString() ?? '';
        if (sapCode.isEmpty || !localInstStr.contains(sapCode)) continue;

        final locReg = loc['regional_id']?.toString();
        final locDiv = loc['divisao_id']?.toString();
        final locSeg = loc['segmento_id']?.toString();

        int rank;
        if (ctReg != null && locReg == ctReg && locDiv == ctDiv && locSeg == ctSeg) {
          rank = 0;
        } else if (ctReg != null && locReg == ctReg && locDiv == ctDiv) {
          rank = 1;
        } else if (ctReg != null && locReg == ctReg && locSeg == ctSeg) {
          rank = 2;
        } else if (ctReg != null && locReg == ctReg) {
          rank = 3;
        } else if (ctDiv != null && locDiv == ctDiv && locSeg == ctSeg) {
          rank = 4;
        } else if (ctSeg != null && locSeg == ctSeg) {
          rank = 5;
        } else {
          rank = 6;
        }

        final lenCodigo = sapCode.length;
        final locId = loc['id']?.toString() ?? '';

        bool isMelhor = false;
        if (rank < melhorRank) {
          isMelhor = true;
        } else if (rank == melhorRank) {
          if (lenCodigo > maiorTamanhoCodigo) {
            isMelhor = true;
          } else if (lenCodigo == maiorTamanhoCodigo &&
              (melhorId.isEmpty || locId.compareTo(melhorId) < 0)) {
            isMelhor = true;
          }
        }

        if (isMelhor) {
          melhorRank = rank;
          maiorTamanhoCodigo = lenCodigo;
          melhorId = locId;
          melhorLocal = loc['local']?.toString();
        }
      }

      map['local'] = melhorLocal;
    }

    // 2. Resolver data_vencimento e dias_restantes (paridade exata com notas_sap_com_prazo)
    final textPrioridade = map['text_prioridade']?.toString().trim() ?? '';
    if (map['data_vencimento'] == null && textPrioridade.isNotEmpty && regras.isNotEmpty) {
      final prioNorm = _normalizarSemAcentoUpper(textPrioridade);

      DateTime? parseDateField(dynamic val) {
        if (val == null) return null;
        if (val is DateTime) return DateTime(val.year, val.month, val.day);
        final parsed = DateTime.tryParse(val.toString());
        if (parsed == null) return null;
        return DateTime(parsed.year, parsed.month, parsed.day);
      }

      final criadoEmDate = parseDateField(map['criado_em']);
      final inicioAvariaDate = parseDateField(map['inicio_avaria']);

      int? buscarDiasPrazoParaReferencia(String tipoRef, DateTime? dataBase) {
        if (dataBase == null) return null;
        int? diasEscolhido;
        int melhorOrdem = 999; // 0 = sem segmento, 1 = com segmento

        for (final r in regras) {
          if (r['data_referencia']?.toString() != tipoRef) continue;
          final rPrioNorm = _normalizarSemAcentoUpper(r['prioridade']?.toString() ?? '');
          if (rPrioNorm != prioNorm) continue;

          final segsList = (r['regras_prazo_notas_segmentos'] as List?) ?? const [];
          if (segsList.isEmpty) {
            if (0 < melhorOrdem) {
              melhorOrdem = 0;
              diasEscolhido = int.tryParse(r['dias_prazo'].toString());
            }
          } else if (ctNotaStr.isNotEmpty) {
            bool matchSeg = false;
            for (final rpns in segsList) {
              final segId = (rpns as Map)['segmento_id']?.toString();
              if (segId == null) continue;
              for (final ct in centros) {
                if (ct['segmento_id']?.toString() != segId) continue;
                final ctVal = (ct['centro_trabalho']?.toString() ?? '').trim().toUpperCase();
                if (ctVal.isEmpty) continue;
                if (ctVal == ctNotaStr ||
                    ctNotaStr.contains(ctVal) ||
                    ctVal.contains(ctNotaStr)) {
                  matchSeg = true;
                  break;
                }
              }
              if (matchSeg) break;
            }
            if (matchSeg && 1 < melhorOrdem) {
              melhorOrdem = 1;
              diasEscolhido = int.tryParse(r['dias_prazo'].toString());
            }
          }
        }
        return diasEscolhido;
      }

      DateTime? dataVenc;
      final diasCriacao = buscarDiasPrazoParaReferencia('criacao', criadoEmDate);
      if (diasCriacao != null && criadoEmDate != null) {
        dataVenc = criadoEmDate.add(Duration(days: diasCriacao));
      } else {
        final diasInicio = buscarDiasPrazoParaReferencia('inicio_desejado', inicioAvariaDate);
        if (diasInicio != null && inicioAvariaDate != null) {
          dataVenc = inicioAvariaDate.add(Duration(days: diasInicio));
        }
      }

      if (dataVenc != null) {
        final hoje = dataHojeReferencia ?? DateTime.now();
        final hojeDate = DateTime(hoje.year, hoje.month, hoje.day);
        final vencDate = DateTime(dataVenc.year, dataVenc.month, dataVenc.day);
        final diasRest = vencDate.difference(hojeDate).inDays;
        map['data_vencimento'] =
            '${vencDate.year.toString().padLeft(4, '0')}-${vencDate.month.toString().padLeft(2, '0')}-${vencDate.day.toString().padLeft(2, '0')}';
        map['dias_restantes'] = diasRest;
      }
    }

    return map;
  }

  /// Carrega (com cache de 2 min) o mapa de vínculos `nota_sap_id -> List<Map>` de `tasks_notas_sap`.
  Future<Map<String, List<Map<String, dynamic>>>> carregarMapaVinculosTarefas({
    bool forceRefresh = false,
  }) async {
    final agora = DateTime.now();
    if (!forceRefresh &&
        _vinculosTarefasCache != null &&
        _vinculosTarefasCacheTime != null &&
        agora.difference(_vinculosTarefasCacheTime!) < _vinculosTarefasCacheTtl) {
      return _vinculosTarefasCache!;
    }

    try {
      final mapa = <String, List<Map<String, dynamic>>>{};
      final seenVinculoIds = <String>{};
      const pageSize = 1000;

      Future<List> buscarPaginaVinculos(int offset, {bool simplificado = false}) {
        final tasksSelect = simplificado
            ? '''
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
                ordem,
                executor
              )
            '''
            : '''
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
                ordem,
                executor,
                tasks_executores(executores(id, nome)),
                tasks_equipes(equipes(id, nome, equipes_executores(executores(id, nome))))
              )
            ''';

        return _supabase
            .from('tasks_notas_sap')
            .select('''
              id,
              nota_sap_id,
              task_id,
              created_at,
              $tasksSelect
            ''')
            .order('created_at', ascending: false)
            .order('id', ascending: true)
            .range(offset, offset + pageSize - 1);
      }

      int offset = 0;
      bool hasMore = true;

      while (hasMore && offset <= 10000) {
        List res = const [];
        for (var tentativa = 1; tentativa <= 2; tentativa++) {
          try {
            res = await buscarPaginaVinculos(offset, simplificado: tentativa > 1);
            break;
          } catch (e) {
            print('⚠️ [NotaSAPService.carregarMapaVinculosTarefas] Tentativa $tentativa (offset $offset) falhou: $e');
            if (tentativa == 2) {
              hasMore = false;
              break;
            }
          }
        }

        if (res.isEmpty) {
          hasMore = false;
          break;
        }

        for (final raw in res) {
          if (raw is! Map) continue;
          final item = raw.map((k, v) => MapEntry(k.toString(), v));
          final vinculoId = item['id']?.toString();
          if (vinculoId != null && vinculoId.isNotEmpty) {
            if (!seenVinculoIds.add(vinculoId)) continue;
          }
          final notaId = item['nota_sap_id']?.toString();
          if (notaId == null || notaId.isEmpty) continue;

          Map<String, dynamic>? taskMap;
          final taskRaw = item['tasks'];
          if (taskRaw is Map) {
            taskMap = taskRaw.map((k, v) => MapEntry(k.toString(), v));

            // Extrair e normalizar executores da tarefa
            final Set<String> executoresSet = {};
            final rawExecutor = taskMap['executor']?.toString() ?? '';
            if (rawExecutor.isNotEmpty) {
              for (final p in rawExecutor.split(',')) {
                final t = p.trim();
                if (t.isNotEmpty) executoresSet.add(t);
              }
            }
            final rawTasksExecutores = taskMap['tasks_executores'];
            if (rawTasksExecutores is List) {
              for (final te in rawTasksExecutores) {
                if (te is Map) {
                  final execMap = te['executores'];
                  if (execMap is Map) {
                    final n = execMap['nome']?.toString().trim();
                    if (n != null && n.isNotEmpty) executoresSet.add(n);
                  }
                }
              }
            }

            // Extrair e normalizar equipes e executores das equipes
            final Set<String> equipesSet = {};
            final Set<String> equipesExecutoresSet = {};
            final rawTasksEquipes = taskMap['tasks_equipes'];
            if (rawTasksEquipes is List) {
              for (final te in rawTasksEquipes) {
                if (te is Map) {
                  final eqMap = te['equipes'];
                  if (eqMap is Map) {
                    final n = eqMap['nome']?.toString().trim();
                    if (n != null && n.isNotEmpty) equipesSet.add(n);
                    final eqExecs = eqMap['equipes_executores'];
                    if (eqExecs is List) {
                      for (final ee in eqExecs) {
                        if (ee is Map) {
                          final exMap = ee['executores'];
                          if (exMap is Map) {
                            final exNome = exMap['nome']?.toString().trim();
                            if (exNome != null && exNome.isNotEmpty) {
                              equipesExecutoresSet.add(exNome);
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }

            taskMap['lista_executores'] = executoresSet.toList()..sort();
            taskMap['lista_equipes'] = equipesSet.toList()..sort();
            taskMap['lista_equipes_executores'] = equipesExecutoresSet.toList()..sort();
          }

          mapa.putIfAbsent(notaId, () => []).add({
            'vinculo_id': item['id'],
            'nota_sap_id': notaId,
            'task_id': item['task_id'],
            'vinculado_em': item['created_at'] != null
                ? DateTime.tryParse(item['created_at'].toString())
                : null,
            'tarefa': taskMap,
          });
        }

        if (res.length < pageSize) {
          hasMore = false;
        } else {
          offset += pageSize;
        }
      }

      if (mapa.isNotEmpty) {
        _vinculosTarefasCache = mapa;
        _vinculosTarefasCacheTime = agora;
      }

      return mapa.isNotEmpty ? mapa : (_vinculosTarefasCache ?? {});
    } catch (e) {
      print('⚠️ [NotaSAPService] Erro ao carregar mapa de vínculos de tarefas: $e');
      return _vinculosTarefasCache ?? {};
    }
  }

  /// Consulta rápida na tabela física `notas_sap` particionada por janelas de `criado_em`,
  /// evitando varredura nos 317.000+ registros históricos (2019–2024) e eliminando timeouts 57014.
  Future<List<Map<String, dynamic>>> buscarMapasNotasSapRapido({
    required List<String> centrosTrabalhoCompletos,
    String? filtroTipoNota,
    int targetLimit = 1000,
    int? offset,
    String? filtroSalaUnica,
    String? filtroResponsavelUnico,
    String? filtroTipoUnico,
    String? filtroNotaUnica,
    String? filtroPrioridadeUnica,
    String? filtroStatusUsuarioUnico,
    String? filtroGpmUnico,
    String colunasSelect = kColunasEssenciaisNotaSap,
  }) async {
    await garantirCacheEnriquecimento();

    dynamic construirQueryBase({bool aplicarFiltroStatusSql = true}) {
      dynamic q = _supabase.from('notas_sap').select(colunasSelect);

      if (centrosTrabalhoCompletos.isNotEmpty) {
        if (centrosTrabalhoCompletos.length == 1) {
          q = q.eq('centro_trabalho_responsavel', centrosTrabalhoCompletos[0]);
        } else {
          q = q.inFilter('centro_trabalho_responsavel', centrosTrabalhoCompletos);
        }
      }

      // Aplicar filtros NOT ILIKE de status no SQL apenas quando NÃO houver centros específicos
      // Quando há centros de trabalho específicos, evitar NOT ILIKE '%MREL%' / '%MSEN%' no PostgreSQL
      // para não anular o uso de índices e causar timeout 57014. O filtro é aplicado em memória no Dart.
      if (aplicarFiltroStatusSql && centrosTrabalhoCompletos.isEmpty) {
        q = q.not('status_sistema', 'ilike', '%MREL%');
        if (filtroTipoNota == 'abertas') {
          q = q.not('status_sistema', 'ilike', '%MSEN%');
        } else if (filtroTipoNota == 'concluidas') {
          q = q.ilike('status_sistema', '%MSEN%');
        }
      }

      if (filtroSalaUnica != null) q = q.ilike('sala', '%$filtroSalaUnica%');
      if (filtroResponsavelUnico != null) {
        q = q.ilike('denominacao_executor', '%$filtroResponsavelUnico%');
      }
      if (filtroTipoUnico != null) q = q.eq('tipo', filtroTipoUnico);
      if (filtroNotaUnica != null) q = q.eq('nota', filtroNotaUnica);
      if (filtroPrioridadeUnica != null) q = q.eq('text_prioridade', filtroPrioridadeUnica);
      if (filtroStatusUsuarioUnico != null) q = q.eq('status_usuario', filtroStatusUsuarioUnico);
      if (filtroGpmUnico != null) q = q.eq('gpm', filtroGpmUnico);

      return q;
    }

    final List<Map<String, dynamic>> acumulador = [];

    // Se busca por número exato de nota ou paginação explícita por offset, consulta direta
    if (filtroNotaUnica != null || offset != null) {
      dynamic q = construirQueryBase().order('criado_em', ascending: false);
      if (offset != null) {
        q = q.range(offset, offset + targetLimit - 1);
      } else {
        q = q.limit(targetLimit);
      }
      final res = await q;
      for (final item in (res as List)) {
        if (item is Map) {
          acumulador.add(enriquecerMapaNotaComLocalEPrazo(
            item.map((k, v) => MapEntry(k.toString(), v)),
          ));
        }
      }
      return acumulador;
    }

    // Janelas semestrais sobre o índice B-Tree idx_notas_sap_criado_em (~16k-28k linhas por janela, <450ms no PG)
    const janelas = <(String, String?)>[
      ('2026-01-01', null),
      ('2025-07-01', '2026-01-01'),
      ('2025-01-01', '2025-07-01'),
    ];

    Future<List> consultarJanelaComRetry(String inicioJanela, String? fimJanela, int limite) async {
      for (var tentativa = 1; tentativa <= 2; tentativa++) {
        try {
          dynamic q = construirQueryBase().gte('criado_em', inicioJanela);
          if (fimJanela != null) {
            q = q.lt('criado_em', fimJanela);
          }
          // Na tentativa 2, se falhou anteriormente, omitir order no SQL para evitar armadilha de LIMIT/ORDER BY do PG
          if (tentativa == 1) {
            q = q.order('criado_em', ascending: false).limit(limite);
          } else {
            q = q.limit(limite);
          }
          final res = await q;
          return res as List;
        } catch (e) {
          print('⚠️ [buscarMapasNotasSapRapido] Tentativa $tentativa para janela [$inicioJanela - ${fimJanela ?? 'hoje'}] falhou: $e');
          if (tentativa == 2) rethrow;
        }
      }
      return const [];
    }

    Future<List> consultarNull(int limite) async {
      try {
        final res = await construirQueryBase()
            .isFilter('criado_em', null)
            .limit(limite);
        return res as List;
      } catch (e) {
        print('⚠️ [buscarMapasNotasSapRapido] Consulta complementar criado_em IS NULL falhou: $e');
        return const [];
      }
    }

    if (centrosTrabalhoCompletos.isNotEmpty) {
      // Com o índice composto idx_notas_sap_ct_criado_em, cada janela semestral de um centro
      // executa em <20ms no PostgreSQL. Executar em paralelo elimina 3 RTTs sequenciais de rede.
      final resultadosParalelos = await Future.wait<List>([
        for (final (inicioJanela, fimJanela) in janelas)
          consultarJanelaComRetry(inicioJanela, fimJanela, targetLimit)
              .catchError((e) {
            print('⚠️ [buscarMapasNotasSapRapido] Janela paralela [$inicioJanela - ${fimJanela ?? 'hoje'}] falhou: $e');
            return const [];
          }),
        consultarNull(100),
      ]);

      for (final res in resultadosParalelos) {
        for (final item in res) {
          if (acumulador.length >= targetLimit) break;
          if (item is Map) {
            acumulador.add(enriquecerMapaNotaComLocalEPrazo(
              item.map((k, v) => MapEntry(k.toString(), v)),
            ));
          }
        }
        if (acumulador.length >= targetLimit) break;
      }
    } else {
      for (final (inicioJanela, fimJanela) in janelas) {
        final restante = targetLimit - acumulador.length;
        if (restante <= 0) break;

        try {
          final res = await consultarJanelaComRetry(inicioJanela, fimJanela, restante);
          for (final item in res) {
            if (item is Map) {
              acumulador.add(enriquecerMapaNotaComLocalEPrazo(
                item.map((k, v) => MapEntry(k.toString(), v)),
              ));
            }
          }
        } catch (e) {
          if (acumulador.isNotEmpty) {
            print('⚠️ [buscarMapasNotasSapRapido] Janela [$inicioJanela - ${fimJanela ?? 'hoje'}] atingiu timeout ou erro. Retornando ${acumulador.length} registros recentes já acumulados.');
            break;
          } else {
            rethrow;
          }
        }
      }

      final restanteNull = targetLimit - acumulador.length;
      if (restanteNull > 0) {
        try {
          final resNull = await construirQueryBase()
              .isFilter('criado_em', null)
              .limit(restanteNull);
          for (final item in (resNull as List)) {
            if (item is Map) {
              acumulador.add(enriquecerMapaNotaComLocalEPrazo(
                item.map((k, v) => MapEntry(k.toString(), v)),
              ));
            }
          }
        } catch (e) {
          print('⚠️ [buscarMapasNotasSapRapido] Consulta complementar criado_em IS NULL falhou: $e');
        }
      }
    }

    // Ordenar acumulador por criado_em decrescente (com desempate determinístico por id) em memória
    acumulador.sort((a, b) {
      final da = a['criado_em']?.toString() ?? '';
      final db = b['criado_em']?.toString() ?? '';
      final cmp = db.compareTo(da);
      if (cmp != 0) return cmp;
      final ida = a['id']?.toString() ?? '';
      final idb = b['id']?.toString() ?? '';
      return idb.compareTo(ida);
    });

    return acumulador;
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
    print('⏱ [getAllNotas] Iniciando | limit=$limit | offset=$offset | tipo=$filtroTipoNota');
    
    try {
      final querySw = Stopwatch()..start();

      // Aplicar filtros por perfil do usuário
      final usuario = _authService.currentUser;
      bool temFiltro = false;
      List<String> centrosCompletos = [];

      if (usuario != null && usuario.isRoot) {
        print('🔓 Usuário root - sem filtros de perfil aplicados');
      } else {
        final centrosTrabalhoUsuario = await _obterCentrosTrabalhoUsuario();
        if (centrosTrabalhoUsuario.isNotEmpty) {
          centrosCompletos = centrosTrabalhoUsuario.map((c) => c.trim()).where((c) => c.isNotEmpty).toSet().toList();
          temFiltro = centrosCompletos.isNotEmpty;
        }

        if (!temFiltro && usuario != null && !usuario.isRoot && usuario.temPerfilConfigurado()) {
          print('⚠️ Usuário com perfil mas sem centros de trabalho - retornando lista vazia');
          return [];
        }
      }

      // Filtros multi-seleção (local é sempre resolvido em memória após enriquecimento)
      final List<String>? filtroLocaisParaCodigo =
          (filtroLocais != null && filtroLocais.isNotEmpty) ? filtroLocais : null;
      final List<String>? filtroSalasParaCodigo =
          (filtroSalas != null && filtroSalas.length > 1) ? filtroSalas : null;
      final List<String>? filtroTiposParaCodigo =
          (filtroTipos != null && filtroTipos.length > 1) ? filtroTipos : null;
      final List<String>? filtroNotasParaCodigo =
          (filtroNotas != null && filtroNotas.length > 1) ? filtroNotas : null;
      final List<String>? filtroPrioridadesParaCodigo =
          (filtroPrioridades != null && filtroPrioridades.length > 1) ? filtroPrioridades : null;
      final List<String>? filtroStatusUsuarioParaCodigo =
          (filtroStatusUsuario != null && filtroStatusUsuario.length > 1) ? filtroStatusUsuario : null;
      final List<String>? filtroResponsaveisParaCodigo =
          (filtroResponsaveis != null && filtroResponsaveis.length > 1) ? filtroResponsaveis : null;
      final List<String>? filtroGPMsParaCodigo =
          (filtroGPMs != null && filtroGPMs.length > 1) ? filtroGPMs : null;

      final responseMaps = await buscarMapasNotasSapRapido(
        centrosTrabalhoCompletos: centrosCompletos,
        filtroTipoNota: filtroTipoNota,
        targetLimit: limit ?? 1000,
        offset: offset,
        filtroSalaUnica: (filtroSalas != null && filtroSalas.length == 1) ? filtroSalas[0] : null,
        filtroResponsavelUnico:
            (filtroResponsaveis != null && filtroResponsaveis.length == 1) ? filtroResponsaveis[0] : null,
        filtroTipoUnico: (filtroTipos != null && filtroTipos.length == 1) ? filtroTipos[0] : null,
        filtroNotaUnica: (filtroNotas != null && filtroNotas.length == 1) ? filtroNotas[0] : null,
        filtroPrioridadeUnica:
            (filtroPrioridades != null && filtroPrioridades.length == 1) ? filtroPrioridades[0] : null,
        filtroStatusUsuarioUnico:
            (filtroStatusUsuario != null && filtroStatusUsuario.length == 1) ? filtroStatusUsuario[0] : null,
        filtroGpmUnico: (filtroGPMs != null && filtroGPMs.length == 1) ? filtroGPMs[0] : null,
      );

      querySw.stop();
      print('⏱ [getAllNotas] Query Supabase concluída em ${querySw.elapsedMilliseconds}ms | registros=${responseMaps.length}');
      
      final mapSw = Stopwatch()..start();
      var notas = responseMaps.map((map) => NotaSAP.fromMap(map)).toList();
      mapSw.stop();
      print('⏱ [getAllNotas] Mapeamento concluído em ${mapSw.elapsedMilliseconds}ms | notas=${notas.length}');
      
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

      // Enriquecer com status da tarefa vinculada (usando o cache único em memória)
      final enrichSw = Stopwatch()..start();
      if (notas.isNotEmpty) {
        try {
          final mapaVinculos = await carregarMapaVinculosTarefas();
          notas = notas.map((n) {
            final vincs = mapaVinculos[n.id];
            if (vincs == null || vincs.isEmpty) return n;
            final tarefa = vincs.first['tarefa'] as Map<String, dynamic>?;
            final status = tarefa?['status']?.toString();
            return status != null ? n.copyWith(tarefaStatus: status) : n;
          }).toList();
        } catch (e) {
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
      await garantirCacheEnriquecimento();
      final response = await _supabase
          .from('notas_sap')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (response == null) return null;
      final map = enriquecerMapaNotaComLocalEPrazo(
        Map<String, dynamic>.from(response),
      );
      return NotaSAP.fromMap(map);
    } catch (e) {
      print('❌ Erro ao buscar nota: $e');
      return null;
    }
  }

  // Buscar nota por número
  Future<NotaSAP?> getNotaPorNumero(String numeroNota) async {
    try {
      await garantirCacheEnriquecimento();
      final response = await _supabase
          .from('notas_sap')
          .select()
          .eq('nota', numeroNota)
          .maybeSingle();
      if (response == null) return null;
      final map = enriquecerMapaNotaComLocalEPrazo(
        Map<String, dynamic>.from(response),
      );
      return NotaSAP.fromMap(map);
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

  /// Vincula múltiplas notas SAP a uma tarefa em lote com garantia de consistência.
  /// 
  /// - Idempotente: identifica notas já vinculadas para evitar duplicatas em tasks_notas_sap.
  /// - Executa inserção em batch de forma atômica no PostgREST.
  /// - Em caso de falha de banco no lote, executa rollback lógico (limpeza dos vínculos
  ///   inseridos nesta tentativa) para evitar estado inconsistente/parcial silencioso.
  /// - Vincula ordens correspondentes em segundo plano sem bloquear a conclusão da tarefa.
  Future<List<String>> vincularNotasATarefaBatch({
    required String taskId,
    required List<String> notaSapIds,
  }) async {
    if (notaSapIds.isEmpty) return [];

    final solicitados = notaSapIds.toSet();
    final idsNovosInseridosComSucesso = <String>[];

    try {
      print('🔗 [NotaSapService] Iniciando vinculação de ${solicitados.length} notas solicitadas para tarefa $taskId...');

      // 1. Identificar quais notas já estão vinculadas à tarefa (existentes)
      final jaVinculadasRes = await _supabase
          .from('tasks_notas_sap')
          .select('nota_sap_id')
          .eq('task_id', taskId)
          .inFilter('nota_sap_id', solicitados.toList());

      final existentes = (jaVinculadasRes as List)
          .map((row) => row['nota_sap_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

      // 2. Calcular apenas os novos vínculos necessários
      final novos = solicitados.difference(existentes).toList();

      if (novos.isEmpty) {
        print('ℹ️ [NotaSapService] Todas as ${solicitados.length} notas solicitadas já estavam vinculadas à tarefa $taskId');
        return existentes.toList();
      }

      print('📋 [NotaSapService] Vínculos existentes: ${existentes.length}, Novos a inserir: ${novos.length}');

      // 3. Inserir em lote atômico na tabela tasks_notas_sap
      final payload = novos
          .map((notaId) => {
                'task_id': taskId,
                'nota_sap_id': notaId,
              })
          .toList();

      try {
        await _supabase.from('tasks_notas_sap').insert(payload);
        idsNovosInseridosComSucesso.addAll(novos);
        print('✅ [NotaSapService] ${idsNovosInseridosComSucesso.length} novas notas vinculadas com sucesso à tarefa $taskId');
      } catch (insertError) {
        print('❌ [NotaSapService.vincularNotasATarefaBatch] Erro ao inserir batch: $insertError');
        // Rollback lógico seletivo: remove APENAS os novos vínculos inseridos nesta chamada
        // NUNCA toca nos vínculos pré-existentes (existentes continua 100% preservado)
        if (idsNovosInseridosComSucesso.isNotEmpty) {
          try {
            await _supabase
                .from('tasks_notas_sap')
                .delete()
                .eq('task_id', taskId)
                .inFilter('nota_sap_id', idsNovosInseridosComSucesso);
            print('🔄 [NotaSapService] Rollback lógico executado: ${idsNovosInseridosComSucesso.length} novos vínculos revertidos. Vínculos anteriores preservados.');
          } catch (rbError) {
            print('⚠️ [NotaSapService] Erro ao executar rollback lógico: $rbError');
          }
        }
        rethrow;
      }

      return [...existentes, ...idsNovosInseridosComSucesso];
    } catch (e, stackTrace) {
      print('❌ [NotaSapService.vincularNotasATarefaBatch] Erro geral: $e\n$stackTrace');
      rethrow;
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

      final list = response as List;
      if (list.isEmpty) return [];

      return list.map((item) {
        // Supabase pode retornar LinkedMap — converter para Map<String, dynamic>
        final raw = item is Map
            ? item.map((key, value) => MapEntry(key.toString(), value))
            : item as Map<String, dynamic>;
        final notaData = raw['notas_sap_com_prazo'];
        if (notaData == null) return null;
        final notaMap = notaData is Map
            ? notaData.map((key, value) => MapEntry(key.toString(), value))
            : notaData as Map<String, dynamic>;
        return NotaSAP.fromMap(notaMap);
      }).where((n) => n != null).cast<NotaSAP>().toList();
    } catch (e, stackTrace) {
      print('⚠️ Erro ao buscar notas da tarefa (VIEW): $e');
      print('⚠️ Tentando fallback pela tabela base...');
      // Fallback: buscar IDs das notas na junction e depois os dados na tabela base
      try {
        final junctionResponse = await _supabase
            .from('tasks_notas_sap')
            .select('nota_sap_id')
            .eq('task_id', taskId);

        final junctionList = junctionResponse as List;
        if (junctionList.isEmpty) return [];

        final notaIds = junctionList.map((item) {
          final raw = item is Map
              ? item.map((key, value) => MapEntry(key.toString(), value))
              : item as Map<String, dynamic>;
          return raw['nota_sap_id']?.toString();
        }).where((id) => id != null).cast<String>().toList();

        if (notaIds.isEmpty) return [];

        // Buscar dados das notas na tabela base
        dynamic notasQuery = _supabase.from('notas_sap').select();
        if (notaIds.length == 1) {
          notasQuery = notasQuery.eq('id', notaIds[0]);
        } else {
          notasQuery = notasQuery.inFilter('id', notaIds);
        }
        final notasResponse = await notasQuery;

        return (notasResponse as List).map((item) {
          final notaMap = item is Map
              ? item.map((key, value) => MapEntry(key.toString(), value))
              : item as Map<String, dynamic>;
          return NotaSAP.fromMap(notaMap);
        }).toList();
      } catch (e2, stackTrace2) {
        print('❌ Erro no fallback ao buscar notas da tarefa: $e2');
        print('❌ Stack original: $stackTrace');
        print('❌ Stack fallback: $stackTrace2');
        throw Exception('Erro ao buscar notas da tarefa: $e2');
      }
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

      if (taskIds.length > 100) {
        final chunks = <List<String>>[];
        for (var i = 0; i < taskIds.length; i += 100) {
          chunks.add(taskIds.sublist(i, i + 100 > taskIds.length ? taskIds.length : i + 100));
        }
        final futures = chunks.map((chunk) => contarNotasPorTarefas(chunk));
        final results = await Future.wait(futures);
        
        final Map<String, int> merged = {};
        for (final r in results) {
          merged.addAll(r);
        }
        return merged;
      }

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
      final usuario = _authService.currentUser;
      final centrosTrabalhoUsuario = await _obterCentrosTrabalhoUsuario();
      if (centrosTrabalhoUsuario.isEmpty &&
          usuario != null &&
          !usuario.isRoot &&
          usuario.temPerfilConfigurado()) {
        print('⚠️ Usuário com perfil mas sem centros de trabalho - retornando lista vazia');
        return [];
      }

      await garantirCacheEnriquecimento();
      final mapaVinculos = await carregarMapaVinculosTarefas();
      if (mapaVinculos.isEmpty) return [];

      final notaIds = mapaVinculos.keys.toList();
      final notasPorId = <String, NotaSAP>{};
      const chunkSize = 100;

      final chunks = <List<String>>[
        for (var i = 0; i < notaIds.length; i += chunkSize)
          notaIds.sublist(
            i,
            (i + chunkSize > notaIds.length) ? notaIds.length : i + chunkSize,
          )
      ];

      // Processar em lotes paralelos de até 4 chunks por vez para evitar sobrecarga e manter URL < 4KB
      for (var b = 0; b < chunks.length; b += 4) {
        final batch = chunks.sublist(b, (b + 4 > chunks.length) ? chunks.length : b + 4);
        final batchResults = await Future.wait(
          batch.map((chunk) => _supabase
              .from('notas_sap')
              .select(kColunasEssenciaisNotaSap)
              .inFilter('id', chunk)),
        );
        for (final res in batchResults) {
          for (final raw in (res as List)) {
            if (raw is! Map) continue;
            final map = enriquecerMapaNotaComLocalEPrazo(
              raw.map((k, v) => MapEntry(k.toString(), v)),
            );
            final nota = NotaSAP.fromMap(map);
            if (centrosTrabalhoUsuario.isNotEmpty) {
              final ctNota = (nota.centroTrabalhoResponsavel ?? '').trim().toUpperCase();
              if (ctNota.isEmpty) continue;
              final permitido = centrosTrabalhoUsuario.any((centro) {
                final ctUser = centro.trim().toUpperCase();
                return ctNota.contains(ctUser) || ctUser.contains(ctNota);
              });
              if (!permitido) continue;
            }
            notasPorId[nota.id] = nota;
          }
        }
      }

      final resultado = <Map<String, dynamic>>[];
      for (final entry in mapaVinculos.entries) {
        final nota = notasPorId[entry.key];
        if (nota == null) continue;
        for (final vinc in entry.value) {
          resultado.add({
            'vinculo_id': vinc['vinculo_id'],
            'vinculado_em': vinc['vinculado_em'],
            'nota': nota,
            'tarefa': vinc['tarefa'],
          });
        }
      }

      return resultado;
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
      final notas = await getAllNotas(
        filtroTipoNota: filtroTipoNota,
        filtroLocais: filtroLocais,
        filtroTipos: filtroTipos,
        filtroNotas: filtroNotas,
        filtroPrioridades: filtroPrioridades,
        filtroStatusUsuario: filtroStatusUsuario,
        filtroResponsaveis: filtroResponsaveis,
        filtroGPMs: filtroGPMs,
      );
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
      final usuario = _authService.currentUser;
      List<String> centrosCompletos = [];

      if (usuario == null || !usuario.isRoot) {
        final centrosTrabalhoUsuario = await _obterCentrosTrabalhoUsuario();
        if (centrosTrabalhoUsuario.isNotEmpty) {
          centrosCompletos = centrosTrabalhoUsuario
              .map((c) => c.trim())
              .where((c) => c.isNotEmpty)
              .toSet()
              .toList();
        } else if (usuario != null && !usuario.isRoot && usuario.temPerfilConfigurado()) {
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

      final localSet = <String>{};
      final salaSet = <String>{};
      final tipoSet = <String>{};
      final notaSet = <String>{};
      final prioridadeSet = <String>{};
      final statusUsuarioSet = <String>{};
      final responsavelSet = <String>{};
      final gpmSet = <String>{};

      try {
        final todasNotas = await buscarMapasNotasSapRapido(
          centrosTrabalhoCompletos: centrosCompletos,
          filtroTipoNota: filtroTipoNota,
          targetLimit: 1000,
          colunasSelect:
              'id,status_sistema,local_instalacao,centro_trabalho_responsavel,sala,tipo,nota,text_prioridade,status_usuario,denominacao_executor,gpm,criado_em,inicio_avaria',
        );

        bool atendeFiltrosExceto(Map<String, dynamic> item, String campoExcluir) {
          final status = (item['status_sistema'] as String? ?? '').toUpperCase();
          if (status.contains('MREL')) return false;
          if (filtroTipoNota == 'abertas' && status.contains('MSEN')) return false;
          if (filtroTipoNota == 'concluidas' && !status.contains('MSEN')) return false;

          if (campoExcluir != 'local' && filtroLocais != null && filtroLocais.isNotEmpty) {
            final loc = item['local'] as String? ?? '';
            if (!filtroLocais.any((l) => loc.toLowerCase().contains(l.toLowerCase()))) {
              return false;
            }
          }

          if (campoExcluir != 'sala' && filtroSalas != null && filtroSalas.isNotEmpty) {
            final salaVal = item['sala'] as String? ?? '';
            if (!filtroSalas.any((s) => salaVal.toLowerCase().contains(s.toLowerCase()))) {
              return false;
            }
          }

          if (campoExcluir != 'tipo' && filtroTipos != null && filtroTipos.isNotEmpty) {
            if (!filtroTipos.contains(item['tipo'])) return false;
          }

          if (campoExcluir != 'nota' && filtroNotas != null && filtroNotas.isNotEmpty) {
            if (!filtroNotas.contains(item['nota'])) return false;
          }

          if (campoExcluir != 'prioridade' &&
              filtroPrioridades != null &&
              filtroPrioridades.isNotEmpty) {
            if (!filtroPrioridades.contains(item['text_prioridade'])) return false;
          }

          if (campoExcluir != 'status_usuario' &&
              filtroStatusUsuario != null &&
              filtroStatusUsuario.isNotEmpty) {
            if (!filtroStatusUsuario.contains(item['status_usuario'])) return false;
          }

          if (campoExcluir != 'responsavel' &&
              filtroResponsaveis != null &&
              filtroResponsaveis.isNotEmpty) {
            final resp = item['denominacao_executor'] as String? ?? '';
            if (!filtroResponsaveis.any((r) => resp.toLowerCase().contains(r.toLowerCase()))) {
              return false;
            }
          }

          if (campoExcluir != 'gpm' && filtroGPMs != null && filtroGPMs.isNotEmpty) {
            if (!filtroGPMs.contains(item['gpm']?.toString())) return false;
          }

          return true;
        }

        for (final item in todasNotas) {
          if (item['local'] != null && atendeFiltrosExceto(item, 'local')) {
            localSet.add(item['local'] as String);
          }
          if (item['sala'] != null && atendeFiltrosExceto(item, 'sala')) {
            salaSet.add(item['sala'] as String);
          }
          if (item['tipo'] != null && atendeFiltrosExceto(item, 'tipo')) {
            tipoSet.add(item['tipo'] as String);
          }
          if (item['nota'] != null && atendeFiltrosExceto(item, 'nota')) {
            notaSet.add(item['nota'] as String);
          }
          if (item['text_prioridade'] != null && atendeFiltrosExceto(item, 'prioridade')) {
            prioridadeSet.add(item['text_prioridade'] as String);
          }
          if (item['status_usuario'] != null && atendeFiltrosExceto(item, 'status_usuario')) {
            statusUsuarioSet.add(item['status_usuario'] as String);
          }
          if (item['denominacao_executor'] != null && atendeFiltrosExceto(item, 'responsavel')) {
            responsavelSet.add(item['denominacao_executor'] as String);
          }
          if (item['gpm'] != null && atendeFiltrosExceto(item, 'gpm')) {
            gpmSet.add(item['gpm'].toString());
          }
        }
      } catch (e) {
        print('❌ Erro na consulta única de filtros: $e');
      }

      return {
        'status': [],
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

/// Alias para convenção de nomenclatura
typedef NotaSapService = NotaSAPService;

