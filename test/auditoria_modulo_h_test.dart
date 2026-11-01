import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:task2026/config/supabase_config.dart';

void main() {
  test('Amostragem de Casos Reais no Supabase', () async {
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: 'http://212.85.0.249:8000',
        anonKey: SupabaseConfig.supabaseAnonKey,
      );
    } catch (_) {}

    final client = Supabase.instance.client;

    // Buscar notas recentes com equipamento preenchido
    final notasComEq = await client
        .from('notas_sap')
        .select('id, nota, equipamento, local_instalacao, centro_trabalho_responsavel, descricao, tipo, status_sistema, ordem, criado_em')
        .not('equipamento', 'is', null)
        .neq('equipamento', '')
        .order('criado_em', ascending: false)
        .limit(100);

    print('Encontradas ${notasComEq.length} notas recentes com equipamento.');

    // Contar quais equipamentos se repetem entre as notas
    final eqMap = <String, List<Map<String, dynamic>>>{};
    for (final n in notasComEq) {
      final eq = n['equipamento'].toString().trim();
      eqMap.putIfAbsent(eq, () => []).add(n);
    }

    // Para os primeiros equipamentos, buscar notas adicionais do mesmo equipamento
    final equipamentosTestar = eqMap.keys.take(8).toList();
    for (final eq in equipamentosTestar) {
      final historico = await client
          .from('notas_sap')
          .select('id, nota, equipamento, local_instalacao, centro_trabalho_responsavel, descricao, tipo, status_sistema, ordem, criado_em')
          .eq('equipamento', eq)
          .order('criado_em', ascending: false)
          .limit(10);
      print('\n======================================================');
      print('EQUIPAMENTO: $eq (Total de notas retornadas: ${historico.length})');
      for (final h in historico) {
        print('Nota: ${h['nota']} | Tipo: ${h['tipo']} | CT: ${h['centro_trabalho_responsavel']} | LocInst: ${h['local_instalacao']} | Status: ${h['status_sistema']}');
        print('  Desc: "${h['descricao']}"');
      }
    }
  });
}
