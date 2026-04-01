import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupressaoImportResult {
  final int linhasProcessadas;
  final int registrosUpsertados;
  final List<String> avisos;
  final List<String> erros;

  SupressaoImportResult({
    required this.linhasProcessadas,
    required this.registrosUpsertados,
    required this.avisos,
    required this.erros,
  });
}

class SupressaoVegetacaoService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<SupressaoImportResult> importarXlsx({
    required Uint8List bytes,
    required String filename,
    required String linhaNome,
    String? tensaoKv,
    String? uf,
    String? concessionaria,
  }) async {
    final avisos = <String>[];
    final erros = <String>[];
    int processadas = 0;
    int upsertadas = 0;

    // Cache de IDs de linhas para não buscar no DB 1000x
    final Map<String, String> cacheLinhas = {};
    String? primaryLinhaId;

    if (linhaNome.trim().isNotEmpty) {
      primaryLinhaId = await _obterOuCriarLinha(
        nome: linhaNome,
        tensaoKv: tensaoKv,
        uf: uf,
        concessionaria: concessionaria,
      );
      cacheLinhas[linhaNome.trim().toLowerCase()] = primaryLinhaId;
    }

    // Registrar importação
    String? importId;
    try {
      final importResp = await _supabase
          .from('importacoes_supressao')
          .insert({
            'filename': filename,
            'status': 'pending',
            'filepath': null,
            'imported_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();
      importId = importResp['id'] as String?;
    } catch (_) {
      // seguir mesmo sem log prévio
    }

    try {
      final excel = Excel.decodeBytes(bytes);
      if (excel.tables.isEmpty) {
        throw Exception('Planilha sem abas/tabelas.');
      }
      Sheet? sheet;
      int headerRowIndex = 0;

      for (var table in excel.tables.values) {
        for (var r = 0; r < (table.maxRows < 4 ? table.maxRows : 4); r++) {
          final row = table.row(r);
          if (row.any(
            (cell) => cell?.value?.toString().trim().toLowerCase() == 'est.',
          )) {
            sheet = table;
            headerRowIndex = r;
            break;
          }
        }
        if (sheet != null) break;
      }

      if (sheet == null) {
        throw Exception(
          'Cabeçalho "EST." não encontrado em nenhuma aba da planilha.',
        );
      }

      final headerRow = sheet.row(headerRowIndex);
      final headerMap = _buildHeaderMap(headerRow);
      if (headerMap.isEmpty) {
        throw Exception(
          'Cabeçalho não reconhecido na aba "${sheet.sheetName}".',
        );
      }

      final upsertPayload = <Map<String, dynamic>>[];
      final dataStartRow = headerRowIndex + 1;

      if (sheet.maxRows <= dataStartRow) {
        throw Exception(
          'Nenhuma linha de dados encontrada (apenas cabeçalho).',
        );
      }

      for (var i = dataStartRow; i < sheet.maxRows; i++) {
        final row = sheet.rows[i];
        if (_rowVazia(row)) continue;
        processadas++;

        final mapa = <String, dynamic>{};
        if (primaryLinhaId != null) {
          mapa['linha_id'] = primaryLinhaId;
        }

        for (final entry in headerMap.entries) {
          final idx = entry.key;
          final campo = entry.value;
          if (idx >= row.length) continue;
          final cell = row[idx];
          final valor = cell?.value;
          if (valor == null) continue;
          switch (campo) {
            case 'lt':
            case 'est_codigo':
            case 'numeracao_ggt':
            case 'mapeamento_ggt':
            case 'codigo_ggt_execucao':
            case 'descricao_servicos':
            case 'prioridade':
            case 'conferencia_vao':
            case 'pend_manual':
            case 'pend_mecanizado':
            case 'pend_seletivo':
            case 'pend_manual_extra':
            case 'pend_mecanizado_extra':
            case 'pend_seletivo_extra':
            case 'pendencias_execucao':
              mapa[campo] = valor.toString().trim();
              break;
            case 'roco_concluido':
              mapa[campo] = _parseBool(valor);
              break;
            case 'vao_frente_m':
            case 'vao_largura_m':
            case 'map_mec_extensao_m':
            case 'map_mec_largura_m':
            case 'map_man_extensao_m':
            case 'map_man_largura_m':
            case 'exec_mec_extensao_m':
            case 'exec_mec_largura_m':
            case 'exec_man_extensao_m':
            case 'exec_man_largura_m':
              final numVal = _parseNum(valor);
              if (numVal != null) mapa[campo] = numVal;
              break;
            case 'exec_mec_data':
            case 'exec_man_data':
            case 'vao_data_conclusao':
            case 'map_data':
            case 'execucao_mec_data_inicio':
            case 'execucao_mec_data_fim':
            case 'execucao_man_data_inicio':
            case 'execucao_man_data_fim':
              final dt = _parseDate(valor);
              if (dt != null) mapa[campo] = dt.toIso8601String();
              break;
            default:
              break;
          }
        }

        String? rowLinhaNome = mapa['lt'] as String?;
        if (rowLinhaNome != null && rowLinhaNome.trim().isNotEmpty) {
          final lowerName = rowLinhaNome.trim().toLowerCase();
          if (!cacheLinhas.containsKey(lowerName)) {
            cacheLinhas[lowerName] = await _obterOuCriarLinha(
              nome: rowLinhaNome.trim(),
            );
          }
          mapa['linha_id'] = cacheLinhas[lowerName];
        }
        mapa.remove('lt');

        if (!mapa.containsKey('linha_id') || mapa['linha_id'] == null) {
          avisos.add(
            'Linha ${i + 1}: Sem nome da linha ou linha_id. Ignorada.',
          );
          continue;
        }

        if (!mapa.containsKey('est_codigo') ||
            (mapa['est_codigo'] as String).isEmpty) {
          avisos.add('Linha ${i + 1}: EST. vazio, ignorada.');
          continue;
        }
        upsertPayload.add(mapa);
      }

      if (upsertPayload.isNotEmpty) {
        final resp = await _supabase
            .from('vaos_supressao')
            .upsert(upsertPayload, onConflict: 'linha_id,est_codigo')
            .select();
        upsertadas = (resp as List).length;
      }

      if (importId != null) {
        await _supabase
            .from('importacoes_supressao')
            .update({
              'status': 'success',
              'log':
                  'Processadas: $processadas, Upsertadas: $upsertadas, Avisos: ${avisos.length}, Erros: ${erros.length}',
            })
            .eq('id', importId);
      }

      return SupressaoImportResult(
        linhasProcessadas: processadas,
        registrosUpsertados: upsertadas,
        avisos: avisos,
        erros: erros,
      );
    } catch (e) {
      erros.add(e.toString());
      if (importId != null) {
        await _supabase
            .from('importacoes_supressao')
            .update({'status': 'error', 'log': e.toString()})
            .eq('id', importId);
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> listarVaos({
    String? linhaNome,
    String? linhaId,
    int limit = 200,
  }) async {
    final query = _supabase
        .from('vaos_supressao')
        .select('*, linhas_transmissao ( nome )');

    var filtered = query;
    if (linhaId != null && linhaId.trim().isNotEmpty) {
      filtered = filtered.eq('linha_id', linhaId);
    } else if (linhaNome != null && linhaNome.trim().isNotEmpty) {
      // Buscar IDs por nome parcial
      final linhas = await _supabase
          .from('linhas_transmissao')
          .select('id')
          .ilike('nome', '%${linhaNome.trim()}%');
      if (linhas.isEmpty) return [];
      final ids = linhas.map((e) => e['id'] as String).toList();
      filtered = filtered.inFilter('linha_id', ids);
    }

    final lista = await filtered
        .order('created_at', ascending: false)
        .limit(limit);
    return (lista as List).map((e) => e as Map<String, dynamic>).toList();
  }

  Future<List<Map<String, dynamic>>> listarLinhasTransmissao() async {
    final resp = await _supabase
        .from('linhas_transmissao')
        .select('id, nome, tensao_kv, uf, concessionaria, segmento')
        .ilike('segmento', '%linhas de transmissao%')
        .order('nome', ascending: true);
    return (resp as List).map((e) => e as Map<String, dynamic>).toList();
  }

  Future<List<String>> listarLtEstruturasDistinct() async {
    final resp = await _supabase
        .from('estruturas')
        .select('lt')
        .order('lt', ascending: true);
    return (resp as List)
        .map((e) => (e['lt'] as String?) ?? '')
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<void> atualizarVao(String id, Map<String, dynamic> dados) async {
    await _supabase.from('vaos_supressao').update(dados).eq('id', id);
  }

  Future<List<Map<String, dynamic>>> listarMapeamentoCompleto({
    String? ltNome,
    int? limit,
  }) async {
    PostgrestFilterBuilder<dynamic> query = _supabase
        .from('vw_mapeamento_completo')
        .select();
    if (ltNome != null && ltNome.trim().isNotEmpty) {
      query = query.ilike('lt', '%${ltNome.trim()}%');
    }
    var ordered = query
        .order('lt', ascending: true)
        .order('est_codigo', ascending: true);
    if (limit != null && limit > 0) {
      ordered = ordered.limit(limit);
    }
    final resp = await ordered;
    return (resp as List).map((e) => e as Map<String, dynamic>).toList();
  }

  Future<String?> obterLinhaIdPorNome(String nome) async {
    if (nome.trim().isEmpty) return null;
    final resp = await _supabase
        .from('linhas_transmissao')
        .select('id')
        .ilike('nome', nome)
        .limit(1);
    if (resp.isNotEmpty) {
      return resp.first['id'] as String?;
    }
    return null;
  }

  Future<String> obterOuCriarLinhaPorNome({
    required String nome,
    String? tensaoKv,
    String? uf,
    String? concessionaria,
  }) async {
    return _obterOuCriarLinha(
      nome: nome,
      tensaoKv: tensaoKv,
      uf: uf,
      concessionaria: concessionaria,
    );
  }

  Future<Map<String, dynamic>?> upsertVaoComLinha({
    required String linhaId,
    required String estCodigo,
    required Map<String, dynamic> dados,
  }) async {
    final payload = {'linha_id': linhaId, 'est_codigo': estCodigo, ...dados};
    final resp = await _supabase
        .from('vaos_supressao')
        .upsert(payload, onConflict: 'linha_id,est_codigo')
        .select()
        .maybeSingle();
    return resp;
  }

  /// Exporta os vãos para XLSX com formatação e layout igual ao frontend:
  /// 3 linhas de cabeçalho com células mescladas (Lista de Estruturas / VÃO; Mapeamento / Execução / Fiscalização; Mecanizado / Manual; labels).
  /// A terceira linha contém os rótulos reconhecidos na importação para reimportar o arquivo.
  Future<Uint8List> exportarXlsx(List<Map<String, dynamic>> vaos) async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');
    final sheet = excel['Mapeamento'];

    // Ordem das colunas igual ao frontend; rótulos da linha 2 reconhecidos na importação
    const List<MapEntry<String, String>> colunas = [
      MapEntry('Linha', 'lt'),
      MapEntry('EST.', 'est_codigo'),
      MapEntry('Vão de Frente (m)', 'vao_frente_m'),
      MapEntry('Largura (m)', 'vao_largura_m'),
      MapEntry('Mapeamento Mec. Extensão', 'map_mec_extensao_m'),
      MapEntry('Largura', 'map_mec_largura_m'),
      MapEntry('Mapeamento Man. Extensão', 'map_man_extensao_m'),
      MapEntry('Largura .1', 'map_man_largura_m'),
      MapEntry('Data (mapeamento)', 'map_data'),
      MapEntry('Execução Mec. Data Início', 'execucao_mec_data_inicio'),
      MapEntry('Execução Mec. Data Fim', 'execucao_mec_data_fim'),
      MapEntry('Execução Man. Data Início', 'execucao_man_data_inicio'),
      MapEntry('Execução Man. Data Fim', 'execucao_man_data_fim'),
      MapEntry('Execução Mec. Extensão', 'exec_mec_extensao_m'),
      MapEntry('Largura .2', 'exec_mec_largura_m'),
      MapEntry('Data conclusão', 'exec_mec_data'),
      MapEntry('Execução Man. Extensão', 'exec_man_extensao_m'),
      MapEntry('Largura .3', 'exec_man_largura_m'),
      MapEntry('Data conclusão.1', 'exec_man_data'),
      MapEntry('Data conclusão do vão', 'vao_data_conclusao'),
      MapEntry('Roço concluído: Sim / Não ?', 'roco_concluido'),
      MapEntry('Numeração GGT', 'numeracao_ggt'),
      MapEntry('Mapeamento GGT', 'mapeamento_ggt'),
      MapEntry('Código GGT (execução)', 'codigo_ggt_execucao'),
      MapEntry('Descrição dos serviços', 'descricao_servicos'),
      MapEntry('Prioridade', 'prioridade'),
      MapEntry('Conferência do Vão Sobra (-) ou Falta (+)', 'conferencia_vao'),
      MapEntry('Manual', 'pend_manual'),
      MapEntry('Mecanizado', 'pend_mecanizado'),
      MapEntry('Seletivo / Preservação / Cultivado', 'pend_seletivo'),
      MapEntry('Manual', 'pend_manual_extra'),
      MapEntry('Mecanizado', 'pend_mecanizado_extra'),
      MapEntry('Seletivo / Preservação / Cultivado.1', 'pend_seletivo_extra'),
      MapEntry('Pendências na execução do roço', 'pendencias_execucao'),
    ];

    const int fixedCols = 4; // Linha, EST., Extensão, Largura
    const int mapeamentoCols = 5; // Mec Ext+Larg, Man Ext+Larg, Data
    const int execucaoCols = 4; // Mec Data Início/Fim, Man Data Início/Fim
    const int fiscalizacaoCols = 6; // Mec Ext+Larg+Data, Man Ext+Larg+Data

    // Linha 0: grupos mesclados (Lista de Estruturas, Mapeamento, Execução, Fiscalização)
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      CellIndex.indexByColumnRow(columnIndex: fixedCols - 1, rowIndex: 0),
      customValue: 'Lista de Estruturas',
    );
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: fixedCols, rowIndex: 0),
      CellIndex.indexByColumnRow(
        columnIndex: fixedCols + mapeamentoCols - 1,
        rowIndex: 0,
      ),
      customValue: 'Mapeamento',
    );
    sheet.merge(
      CellIndex.indexByColumnRow(
        columnIndex: fixedCols + mapeamentoCols,
        rowIndex: 0,
      ),
      CellIndex.indexByColumnRow(
        columnIndex: fixedCols + mapeamentoCols + execucaoCols - 1,
        rowIndex: 0,
      ),
      customValue: 'Execução',
    );
    sheet.merge(
      CellIndex.indexByColumnRow(
        columnIndex: fixedCols + mapeamentoCols + execucaoCols,
        rowIndex: 0,
      ),
      CellIndex.indexByColumnRow(
        columnIndex:
            fixedCols + mapeamentoCols + execucaoCols + fiscalizacaoCols - 1,
        rowIndex: 0,
      ),
      customValue: 'Fiscalização da Execução',
    );

    // Linha 1: subgrupos (VÃO; Mecanizado, Manual, Data; Mecanizado, Manual; Mecanizado, Manual)
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
      CellIndex.indexByColumnRow(columnIndex: fixedCols - 1, rowIndex: 1),
      customValue: 'VÃO',
    );
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: fixedCols, rowIndex: 1),
      CellIndex.indexByColumnRow(columnIndex: fixedCols + 1, rowIndex: 1),
      customValue: 'Mecanizado',
    );
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: fixedCols + 2, rowIndex: 1),
      CellIndex.indexByColumnRow(columnIndex: fixedCols + 3, rowIndex: 1),
      customValue: 'Manual',
    );
    // Data (mapeamento) - 1 célula, vazia na linha 1
    sheet
            .cell(
              CellIndex.indexByColumnRow(
                columnIndex: fixedCols + 4,
                rowIndex: 1,
              ),
            )
            .value =
        '';
    sheet.merge(
      CellIndex.indexByColumnRow(
        columnIndex: fixedCols + mapeamentoCols,
        rowIndex: 1,
      ),
      CellIndex.indexByColumnRow(
        columnIndex: fixedCols + mapeamentoCols + 1,
        rowIndex: 1,
      ),
      customValue: 'Mecanizado',
    );
    sheet.merge(
      CellIndex.indexByColumnRow(
        columnIndex: fixedCols + mapeamentoCols + 2,
        rowIndex: 1,
      ),
      CellIndex.indexByColumnRow(
        columnIndex: fixedCols + mapeamentoCols + 3,
        rowIndex: 1,
      ),
      customValue: 'Manual',
    );
    sheet.merge(
      CellIndex.indexByColumnRow(
        columnIndex: fixedCols + mapeamentoCols + execucaoCols,
        rowIndex: 1,
      ),
      CellIndex.indexByColumnRow(
        columnIndex: fixedCols + mapeamentoCols + execucaoCols + 2,
        rowIndex: 1,
      ),
      customValue: 'Mecanizado',
    );
    sheet.merge(
      CellIndex.indexByColumnRow(
        columnIndex: fixedCols + mapeamentoCols + execucaoCols + 3,
        rowIndex: 1,
      ),
      CellIndex.indexByColumnRow(
        columnIndex:
            fixedCols + mapeamentoCols + execucaoCols + fiscalizacaoCols - 1,
        rowIndex: 1,
      ),
      customValue: 'Manual',
    );

    // Linha 2: rótulos das colunas (reconhecidos na importação)
    for (int c = 0; c < colunas.length; c++) {
      sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 2))
              .value =
          colunas[c].key;
    }

    // Dados a partir da linha 3
    for (int r = 0; r < vaos.length; r++) {
      final vao = vaos[r];
      for (int c = 0; c < colunas.length; c++) {
        final key = colunas[c].value;
        Object? val;
        if (key == 'lt') {
          val = vao['linhas_transmissao'] is Map
              ? (vao['linhas_transmissao'] as Map)['nome']
              : vao['lt'];
        } else {
          val = vao[key];
        }
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 3),
        );
        if (val == null) {
          cell.value = '';
        } else if (val is bool) {
          cell.value = val ? 'Sim' : 'Não';
        } else if (val is DateTime) {
          cell.value = _formatDateExport(val);
        } else if (val is num) {
          cell.value = val.toDouble();
        } else {
          cell.value = val.toString();
        }
      }
    }

    final bytes = excel.encode();
    return Uint8List.fromList(bytes ?? []);
  }

  static String _formatDateExport(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  Future<String> _obterOuCriarLinha({
    required String nome,
    String? tensaoKv,
    String? uf,
    String? concessionaria,
  }) async {
    // Tentar localizar por nome (case-insensitive)
    final existentes = await _supabase
        .from('linhas_transmissao')
        .select()
        .ilike('nome', nome)
        .limit(1);
    if (existentes.isNotEmpty) {
      return existentes.first['id'] as String;
    }

    final insert = await _supabase
        .from('linhas_transmissao')
        .insert({
          'nome': nome,
          if (tensaoKv != null && tensaoKv.trim().isNotEmpty)
            'tensao_kv': double.tryParse(tensaoKv.replaceAll(',', '.')),
          if (uf != null && uf.trim().isNotEmpty) 'uf': uf.trim(),
          if (concessionaria != null && concessionaria.trim().isNotEmpty)
            'concessionaria': concessionaria.trim(),
        })
        .select()
        .single();
    return insert['id'] as String;
  }

  Map<int, String> _buildHeaderMap(List<Data?> headerRow) {
    final map = <int, String>{};
    var manualCount = 0;
    var mecanizadoCount = 0;
    var seletivoCount = 0;

    String? normalize(dynamic raw) {
      if (raw == null) return null;
      return raw.toString().trim().toLowerCase();
    }

    for (var i = 0; i < headerRow.length; i++) {
      final raw = normalize(headerRow[i]?.value);
      if (raw == null || raw.isEmpty) continue;
      switch (raw) {
        case 'linha':
          map[i] = 'lt';
          break;
        case 'est.':
          map[i] = 'est_codigo';
          break;
        case 'vão de frente (m)':
          map[i] = 'vao_frente_m';
          break;
        case 'largura (m)':
          map[i] = 'vao_largura_m';
          break;
        case 'mapeamento mec. extensão':
          map[i] = 'map_mec_extensao_m';
          break;
        case 'largura':
        case 'largura ':
          if (!map.containsValue('map_mec_largura_m')) {
            map[i] = 'map_mec_largura_m';
          } else if (!map.containsValue('map_man_largura_m')) {
            map[i] = 'map_man_largura_m';
          }
          break;
        case 'mapeamento man. extensão':
        case 'mapeamento man. extensão ':
          map[i] = 'map_man_extensao_m';
          break;
        case 'largura .1':
          map[i] = 'map_man_largura_m';
          break;
        case 'data (mapeamento)':
        case 'data (mapeamento).1':
          map[i] = 'map_data';
          break;
        case 'execução mec. data início':
          map[i] = 'execucao_mec_data_inicio';
          break;
        case 'execução mec. data fim':
          map[i] = 'execucao_mec_data_fim';
          break;
        case 'execução man. data início':
          map[i] = 'execucao_man_data_inicio';
          break;
        case 'execução man. data fim':
          map[i] = 'execucao_man_data_fim';
          break;
        case 'execução mec. extensão':
        case 'execução mec. extensão ':
          map[i] = 'exec_mec_extensao_m';
          break;
        case 'largura .2':
          map[i] = 'exec_mec_largura_m';
          break;
        case 'data conclusão':
          map[i] = 'exec_mec_data';
          break;
        case 'execução man. extensão':
          map[i] = 'exec_man_extensao_m';
          break;
        case 'largura .3':
          map[i] = 'exec_man_largura_m';
          break;
        case 'data conclusão.1':
          map[i] = 'exec_man_data';
          break;
        case 'data conclusão do vão':
          map[i] = 'vao_data_conclusao';
          break;
        case 'roço concluído: sim / não ?':
          map[i] = 'roco_concluido';
          break;
        case 'numeração ggt':
          map[i] = 'numeracao_ggt';
          break;
        case 'mapeamento ggt':
          map[i] = 'mapeamento_ggt';
          break;
        case 'código ggt (execução)':
          map[i] = 'codigo_ggt_execucao';
          break;
        case 'descrição dos serviços':
          map[i] = 'descricao_servicos';
          break;
        case 'prioridade':
          map[i] = 'prioridade';
          break;
        case 'conferência do vão sobra (-) ou falta (+)':
          map[i] = 'conferencia_vao';
          break;
        case 'manual':
        case 'manual  ':
          manualCount++;
          map[i] = manualCount == 1 ? 'pend_manual' : 'pend_manual_extra';
          break;
        case 'mecanizado':
        case 'mecanizado  ':
          mecanizadoCount++;
          map[i] = mecanizadoCount == 1
              ? 'pend_mecanizado'
              : 'pend_mecanizado_extra';
          break;
        case 'seletivo / preservação / cultivado':
        case 'seletivo/preservação/cultivado':
        case 'seletivo / preservação / cultivado.1':
          seletivoCount++;
          map[i] = seletivoCount == 1 ? 'pend_seletivo' : 'pend_seletivo_extra';
          break;
        case 'pendências na execução do roço':
          map[i] = 'pendencias_execucao';
          break;
        default:
          break;
      }
    }
    return map;
  }

  bool _rowVazia(List<Data?> row) {
    for (final cell in row) {
      if (cell?.value != null && cell!.value.toString().trim().isNotEmpty) {
        return false;
      }
    }
    return true;
  }

  double? _parseNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    final s = v.toString().trim().replaceAll(',', '.');
    return double.tryParse(s);
  }

  bool _parseBool(dynamic v) {
    if (v == null) return false;
    final s = v.toString().trim().toLowerCase();
    return s == 'sim' || s == 'yes' || s == '1' || s == 'true';
  }

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is num) {
      try {
        final excelDate = v.toDouble();
        final milliseconds = (excelDate * 86400000).round();
        return DateTime.fromMillisecondsSinceEpoch(
          milliseconds - 2209161600000, // offset Excel (1900-01-01)
        );
      } catch (_) {
        return null;
      }
    }
    final s = v.toString().trim();
    final parsed = DateTime.tryParse(s);
    return parsed;
  }
}
