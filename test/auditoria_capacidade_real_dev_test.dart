import 'dart:io';
import 'package:supabase/supabase.dart';

void main() async {
  print('================================================================');
  print('AUDITORIA DETALHADA DE CAPACIDADE OPERACIONAL — TASKFLOW (DEV)');
  print('================================================================');

  final client = SupabaseClient(
    'http://212.85.0.249:8000',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzY1ODE3OTgzLCJleHAiOjIwODExNzc5ODN9.YQByqDrpmw0en7VeEcjDfvvTx8Ind_q8gD6-bzEY4Yc',
  );

  // 1. EQUIPES E EXECUTORES
  print('\n--- 1. EQUIPES E EXECUTORES ---');
  try {
    final equipesRes = await client.from('equipes').select('id, nome, tipo, ativo, regional_id, divisao_id, segmento_id');
    final List equipes = equipesRes as List;
    print('Total de Equipes: ${equipes.length}');
    final ativas = equipes.where((e) => e['ativo'] == true).length;
    print('  - Ativas: $ativas | Inativas: ${equipes.length - ativas}');

    final eqExecRes = await client.from('equipes_executores').select('equipe_id, executor_id, papel');
    final List eqExec = eqExecRes as List;
    print('Total de Vínculos Equipes-Executores: ${eqExec.length}');
    final papeisMap = <String, int>{};
    for (final v in eqExec) {
      final p = v['papel']?.toString() ?? 'SEM_PAPEL';
      papeisMap[p] = (papeisMap[p] ?? 0) + 1;
    }
    print('  - Papéis nas equipes: $papeisMap');

    final executoresRes = await client.from('executores').select('id, nome, matricula, ativo, divisao_id, empresa_id');
    final List executores = executoresRes as List;
    final execAtivos = executores.where((e) => e['ativo'] == true).length;
    print('Total de Executores: ${executores.length}');
    print('  - Ativos: $execAtivos | Inativos: ${executores.length - execAtivos}');

    final idsExecutoresEmEquipes = eqExec.map((v) => v['executor_id'].toString()).toSet();
    final alocadosAtivos = executores.where((e) => e['ativo'] == true && idsExecutoresEmEquipes.contains(e['id'])).length;
    print('  - Executores Ativos em Equipes: $alocadosAtivos');
    print('  - Executores Ativos Sem Equipe: ${execAtivos - alocadosAtivos}');
  } catch (e) {
    print('Erro equipes/executores: $e');
  }

  // 2. ESTRUTURA ORGANIZACIONAL
  print('\n--- 2. REGIONAIS, DIVISÕES E SEGMENTOS ---');
  try {
    final regRes = await client.from('regionais').select('id, regional');
    print('Regionais cadastradas: ${(regRes as List).length}');
    for (final r in regRes) {
      print('  * [${r["id"]}] ${r["regional"]}');
    }

    final divRes = await client.from('divisoes').select('id, divisao, regional_id');
    print('Divisões cadastradas: ${(divRes as List).length}');
    for (final d in (divRes as List).take(8)) {
      print('  * Divisão: ${d["divisao"]} (Regional: ${d["regional_id"]})');
    }

    final segRes = await client.from('segmentos').select('id, segmento');
    print('Segmentos cadastrados: ${(segRes as List).length}');
    for (final s in (segRes as List).take(6)) {
      print('  * Segmento: ${s["segmento"]}');
    }
  } catch (e) {
    print('Erro organizacional: $e');
  }

  // 3. FERIADOS
  print('\n--- 3. FERIADOS E CALENDÁRIO ---');
  try {
    final feriadosRes = await client.from('feriados').select().limit(10);
    final List feriados = feriadosRes as List;
    print('Amostra de Feriados: ${feriados.length}');
    for (final f in feriados.take(5)) {
      print('  * $f');
    }
  } catch (e) {
    print('Erro feriados: $e');
  }

  // 4. GRUPOS DE NOTAS E PREVISÕES
  print('\n--- 4. GRUPOS DE NOTAS E DEMANDA PREVISTA ---');
  try {
    final gruposRes = await client.from('notas_sap_grupos').select('id, nome, mes_programacao_previsto, ano_programacao_previsto, status_grupo');
    final List grupos = gruposRes as List;
    print('Grupos cadastrados: ${grupos.length}');
    for (final g in grupos) {
      print('  * Grupo "${g["nome"]}": ${g["mes_programacao_previsto"]}/${g["ano_programacao_previsto"]} [${g["status_grupo"]}]');
    }

    final prevIndRes = await client.from('notas_sap_previsoes').select('id, mes_previsao, ano_previsao');
    final List prevs = prevIndRes as List;
    print('Previsões individuais ativas: ${prevs.length}');
    final mapaPrev = <String, int>{};
    for (final p in prevs) {
      final ch = '${p["mes_previsao"]?.toString().padLeft(2, "0")}/${p["ano_previsao"]}';
      mapaPrev[ch] = (mapaPrev[ch] ?? 0) + 1;
    }
    print('  - Previsões individuais por Mês/Ano: $mapaPrev');
  } catch (e) {
    print('Erro previsões/grupos: $e');
  }

  // 5. HORAS SAP
  print('\n--- 5. HORAS SAP (ESTRUTURA DA TABELA) ---');
  try {
    final horasRes = await client.from('horas_sap').select('id, numero_pessoa, nome_empregado, trabalho_real, data_lancamento, centro_trabalho_real').order('id', ascending: false).limit(5);
    final List horas = horasRes as List;
    print('Horas SAP acessadas com sucesso! Amostra: ${horas.length}');
    for (final h in horas) {
      print('  * Lançamento #${h["id"]}: ${h["data_lancamento"]} - ${h["nome_empregado"]} (${h["numero_pessoa"]}) | Horas: ${h["trabalho_real"]} h | CT: ${h["centro_trabalho_real"]}');
    }
  } catch (e) {
    print('Erro horas_sap: $e');
  }

  // 6. APONTAMENTOS DE TAREFAS / DESLOCAMENTO / HORAS
  print('\n--- 6. EXECUÇÃO DE TAREFAS E HORAS PLANEJADAS ---');
  try {
    // Checar se tasks tem colunas de deslocamento ou horas
    final colunasTasks = await client.from('tasks').select('id, tarefa, horas_planejadas, horas_executadas, tipo, data_inicio, data_fim').limit(5);
    print('Colunas de horas em "tasks":');
    for (final t in (colunasTasks as List)) {
      print('  * Task "${t["tarefa"]}": Horas Planejadas: ${t["horas_planejadas"]}, Horas Executadas: ${t["horas_executadas"]}');
    }
  } catch (e) {
    print('Erro tasks horas: $e');
  }

  print('\n================================================================');
  print('AUDITORIA DETALHADA CONCLUÍDA');
  print('================================================================');
  exit(0);
}
