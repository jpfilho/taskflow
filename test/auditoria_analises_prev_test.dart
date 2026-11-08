import 'package:flutter_test/flutter_test.dart';
import 'package:supabase/supabase.dart';

void main() {
  test('Auditoria das Tabelas de Análise e Previsão', () async {
    final client = SupabaseClient(
      'http://212.85.0.249:8000',
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzY1ODE3OTgzLCJleHAiOjIwODExNzc5ODN9.YQByqDrpmw0en7VeEcjDfvvTx8Ind_q8gD6-bzEY4Yc',
    );

    print('\n========== AUDITORIA NOTAS_SAP_ANALISES ==========');
    try {
      final countAnalises = await client.from('notas_sap_analises').select('id').count(CountOption.exact);
      print('Total de Análises Técnicas: ${countAnalises.count}');

      final amostra = await client.from('notas_sap_analises').select('*').limit(5);
      print('Amostra de registros em notas_sap_analises:');
      for (final a in amostra) {
        print('  $a');
      }
    } catch (e) {
      print('Erro ao consultar notas_sap_analises: $e');
    }

    print('\n========== AUDITORIA NOTAS_SAP_PREVISOES ==========');
    try {
      final countPrevisoes = await client.from('notas_sap_previsoes').select('id').count(CountOption.exact);
      print('Total de Previsões Individuais: ${countPrevisoes.count}');

      final amostraPrev = await client.from('notas_sap_previsoes').select('*').limit(5);
      print('Amostra de registros em notas_sap_previsoes:');
      for (final p in amostraPrev) {
        print('  $p');
      }
    } catch (e) {
      print('Erro ao consultar notas_sap_previsoes: $e');
    }
    print('====================================================\n');
  });
}
