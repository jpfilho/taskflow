import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EstruturaImportResult {
  final int linhasProcessadas;
  final int registrosUpsertados;
  final List<String> avisos;
  final List<String> erros;

  EstruturaImportResult({
    required this.linhasProcessadas,
    required this.registrosUpsertados,
    required this.avisos,
    required this.erros,
  });
}

class EstruturaService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<EstruturaImportResult> importarXlsx(Uint8List bytes, String filename) async {
    final avisos = <String>[];
    final erros = <String>[];
    int processadas = 0;
    int upsertadas = 0;

    try {
      final excel = Excel.decodeBytes(bytes);
      if (excel.tables.isEmpty) throw Exception('Planilha sem abas.');
      final sheet = excel.tables.values.first;
      if (sheet.maxRows < 2) throw Exception('Nenhuma linha de dados encontrada.');

      // Usar a primeira linha como header
      final payload = <Map<String, dynamic>>[];

      for (var i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        if (_rowVazia(row)) continue;
        processadas++;

        String? at(int idx) {
          if (idx >= row.length) return null;
          final v = row[idx]?.value;
          if (v == null) return null;
          return v.toString().trim();
        }

        double? numAt(int idx) {
          final s = at(idx);
          if (s == null || s.isEmpty) return null;
          return double.tryParse(s.replaceAll(',', '.'));
        }

        final lt = at(0);
        final estrutura = at(1);
        if (lt == null || lt.isEmpty || estrutura == null || estrutura.isEmpty) {
          avisos.add('Linha ${i + 1}: LT ou Estrutura vazios, ignorada.');
          continue;
        }

        final map = <String, dynamic>{
          'lt': lt,
          'estrutura': estrutura,
          'familia': at(2),
          'tipo': at(3),
          'progressiva': at(4),
          'vao_m': numAt(5),
          'altura_util_m': numAt(6),
          'deflexao': at(7),
          'equipe': at(8),
          'geo_lat': at(9),
          'geo_lon': at(10),
          'numeracao_antiga': at(11),
        };
        payload.add(map);
      }

      if (payload.isNotEmpty) {
        final resp = await _supabase
            .from('estruturas')
            .upsert(payload, onConflict: 'lt,estrutura')
            .select();
        upsertadas = (resp as List).length;
      }

      return EstruturaImportResult(
        linhasProcessadas: processadas,
        registrosUpsertados: upsertadas,
        avisos: avisos,
        erros: erros,
      );
    } catch (e) {
      erros.add(e.toString());
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> listarEstruturas({
    String? lt,
    String? estrutura,
    String? familia,
    String? tipo,
    int limit = 500,
  }) async {
    PostgrestFilterBuilder<dynamic> query = _supabase.from('estruturas').select();
    if (lt != null && lt.trim().isNotEmpty) {
      query = query.ilike('lt', '%${lt.trim()}%');
    }
    if (estrutura != null && estrutura.trim().isNotEmpty) {
      query = query.ilike('estrutura', '%${estrutura.trim()}%');
    }
    if (familia != null && familia.trim().isNotEmpty) {
      query = query.ilike('familia', '%${familia.trim()}%');
    }
    if (tipo != null && tipo.trim().isNotEmpty) {
      query = query.ilike('tipo', '%${tipo.trim()}%');
    }
    final resp = await query
        .order('lt', ascending: true)
        .order('estrutura', ascending: true)
        .limit(limit);
    return (resp as List).map((e) => e as Map<String, dynamic>).toList();
  }

  Future<void> atualizarEstrutura(String id, Map<String, dynamic> dados) async {
    await _supabase.from('estruturas').update(dados).eq('id', id);
  }

  bool _rowVazia(List<Data?> row) {
    for (final c in row) {
      if (c?.value != null && c!.value.toString().trim().isNotEmpty) return false;
    }
    return true;
  }
}
