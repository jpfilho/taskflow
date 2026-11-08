import 'package:flutter_test/flutter_test.dart';
import 'package:supabase/supabase.dart';
import 'package:task2026/models/capacidade_operacional_models.dart';
import 'package:task2026/models/executor.dart';
import 'package:task2026/models/equipe.dart';
import 'package:task2026/models/task.dart';
import 'package:task2026/models/feriado.dart';
import 'package:task2026/models/backlog_macro_models.dart';
import 'package:task2026/services/capacidade_service.dart';

void main() {
  test('Validação de Ponta a Ponta com Dados Reais da Base Dev (Fase 3)', () async {
    print('========================================================================');
    print('  VALIDAÇÃO COM DADOS REAIS — FASE 3: CAPACIDADE E PRIORIZAÇÃO (DEV)   ');
    print('========================================================================');

    final swTotal = Stopwatch()..start();

    final client = SupabaseClient(
      'http://212.85.0.249:8000',
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzY1ODE3OTgzLCJleHAiOjIwODExNzc5ODN9.YQByqDrpmw0en7VeEcjDfvvTx8Ind_q8gD6-bzEY4Yc',
    );

    final service = CapacidadeService.comServicos();

    // 1. CARREGAR DADOS REAIS DE DESENVOLVIMENTO
    print('\n[1/5] Carregando Feriados, Equipes, Executores e Tarefas reais...');
    final swCarga = Stopwatch()..start();

    final feriadosRaw = await client.from('feriados').select('*');
    final List<Feriado> feriados = (feriadosRaw as List)
        .map((f) => Feriado.fromMap(f as Map<String, dynamic>))
        .toList();

    final equipesRaw = await client.from('equipes').select('*, equipes_executores(*, executores(nome))');
    final List<Equipe> equipes = (equipesRaw as List)
        .map((e) => Equipe.fromMap(e as Map<String, dynamic>))
        .toList();

    final executoresRaw = await client.from('executores').select('*');
    final List<Executor> executores = (executoresRaw as List)
        .map((ex) => Executor.fromMap(ex as Map<String, dynamic>))
        .toList();

    final tasksRaw = await client.from('tasks').select('*').limit(100);
    final List<Task> tarefas = (tasksRaw as List).map((t) {
      final map = t as Map<String, dynamic>;
      return Task(
        id: map['id']?.toString() ?? '',
        status: map['status']?.toString() ?? 'PROG',
        statusNome: map['status']?.toString() ?? 'Programado',
        regional: map['regional']?.toString() ?? '',
        divisao: map['divisao']?.toString() ?? '',
        segmento: map['segmento']?.toString() ?? '',
        locais: const [],
        equipes: const [],
        executorIds: (map['executor_ids'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        equipeIds: (map['equipe_ids'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        tipo: map['tipo']?.toString() ?? '',
        tarefa: map['tarefa']?.toString() ?? '',
        executores: const [],
        executor: map['executor']?.toString() ?? '',
        frota: '',
        coordenador: '',
        dataInicio: (map['data_inicio'] != null ? DateTime.tryParse(map['data_inicio'].toString()) : null) ?? DateTime.now(),
        dataFim: (map['data_fim'] != null ? DateTime.tryParse(map['data_fim'].toString()) : null) ?? DateTime.now(),
      );
    }).toList();

    swCarga.stop();
    print('-> Carregados: ${feriados.length} feriados, ${equipes.length} equipes, ${executores.length} executores, ${tarefas.length} tarefas (${swCarga.elapsedMilliseconds}ms)');

    // 2. INCREMENTO 1: CALENDÁRIO ÚTIL E CAPACIDADE BRUTA / AJUSTADA
    print('\n[2/5] Testando Incremento 1: Calendário Útil e Capacidade Operacional Real (Nov/2026)...');
    final calNov = service.calcularCalendarioMes(
      ano: 2026,
      mes: 11,
      feriadosCadastrados: feriados,
    );
    print('-> Calendário Novembro/2026: ${calNov.diasNoMes} dias corridos, ${calNov.feriadosEmDiasUteis} feriados úteis, ${calNov.diasUteis} dias úteis líquidos.');
    print('-> Feriados no mês: ${calNov.feriadosNomes.join(", ")}');

    const configPadrao = ConfiguracaoCapacidade(
      jornadaDiariaHoras: 8.0,
      fatorEficiencia: 0.85,
      incluirExecutoresSemEquipe: false,
    );

    final capsExec = service.calcularCapacidadeExecutoresMes(
      ano: 2026,
      mes: 11,
      executores: executores,
      equipes: equipes,
      tarefasDoPeriodo: tarefas,
      calendario: calNov,
      config: configPadrao,
    );

    double somaBrutas = 0.0;
    double somaAjustadas = 0.0;
    double somaIndisp = 0.0;
    double somaComprometidas = 0.0;
    for (final c in capsExec) {
      somaBrutas += c.horasBrutas;
      somaAjustadas += c.horasAjustadas;
      somaIndisp += c.horasIndisponiveis;
      somaComprometidas += c.horasComprometidas;
    }
    print('-> Executores avaliados: ${capsExec.length}');
    print('-> Capacidade Bruta Total: ${somaBrutas.toStringAsFixed(1)} h');
    print('-> Indisponibilidades Deduzidas: ${somaIndisp.toStringAsFixed(1)} h');
    print('-> Capacidade Ajustada (85% efic.): ${somaAjustadas.toStringAsFixed(1)} h');
    print('-> Horas Comprometidas em Tarefas: ${somaComprometidas.toStringAsFixed(1)} h');

    // 3. INCREMENTO 2 E 3: DEMANDA REAL DA CARTEIRA E CONFIABILIDADE
    print('\n[3/5] Testando Incrementos 2 e 3: Demanda Real e Bloqueio de Falsa Ociosidade...');
    final notasRaw = await client.from('notas_sap').select('id, nota, descricao, text_prioridade, status_sistema').limit(15);
    final List<BacklogNotaItem> notasReais = (notasRaw as List).map((n) {
      return BacklogNotaItem(
        id: n['id']?.toString() ?? '',
        nota: n['nota']?.toString() ?? '',
        descricao: n['descricao']?.toString() ?? '',
        prioridade: n['text_prioridade']?.toString(),
        statusSistema: n['status_sistema']?.toString(),
        estimativaHoras: null, // Sem análise prévia
      );
    }).toList();

    final demandaNov = service.consolidarDemandaCarteiraMes(
      ano: 2026,
      mes: 11,
      notasPrevistasNoMes: notasReais,
      config: configPadrao,
    );
    print('-> Notas da carteira: ${demandaNov.totalNotasPrevistas}');
    print('-> Notas com estimativa técnica: ${demandaNov.notasComEstimativa}');
    print('-> Notas NÃO dimensionadas: ${demandaNov.notasSemEstimativa}');
    print('-> Taxa de Cobertura: ${demandaNov.percentualCoberturaEstimativa.toStringAsFixed(1)}%');

    // 4. INCREMENTO 4: BALANCEAMENTO MENSAL E TRAVA DE CONFIABILIDADE
    print('\n[4/5] Testando Incremento 4: Balanceamento Mensal e Memória de Cálculo...');
    final balancoNov = service.calcularBalanceamentoMensal(
      ano: 2026,
      mes: 11,
      capacidadesExecutores: capsExec,
      demanda: demandaNov,
      calendario: calNov,
      config: configPadrao,
    );

    print('-> Saldo de Capacidade Calculado: ${balancoNov.saldoHorasCalculado.toStringAsFixed(1)} h');
    print('-> Grau de Confiabilidade: ${balancoNov.nivelConfiabilidade.name.toUpperCase()}');
    print('-> Saldo é Considerado Confiável? ${balancoNov.isSaldoConfiavel ? "SIM" : "NÃO (TRAVA ATIVA)"}');
    print('-> Motivo: ${balancoNov.motivoConfiabilidade}');
    print('\n[Passos da Memória de Cálculo]:');
    print('   ${balancoNov.memoriaCalculo?.passo1Calendario}');
    print('   ${balancoNov.memoriaCalculo?.passo4CapacidadeAjustada}');
    print('   ${balancoNov.memoriaCalculo?.passo6DemandaEstimada}');
    print('   ${balancoNov.memoriaCalculo?.passo7SaldoEConfiabilidade}');

    // 5. INCREMENTO 6: PRIORIZAÇÃO EXPLICÁVEL E SIMULAÇÃO NÃO DESTRUTIVA
    print('\n[5/5] Testando Incremento 6: Score de Prioridade Explicável e Simulação...');
    final priorizacoes = service.calcularPriorizacaoNotas(notas: notasReais);
    print('-> Top 3 demandas com maior prioridade consultiva:');
    for (int i = 0; i < priorizacoes.take(3).length; i++) {
      final p = priorizacoes[i];
      print('   ${i + 1}. Nota ${p.numeroNota}: Score ${p.scoreTotal.toStringAsFixed(0)} pts (${p.categoria.label})');
      print('      Motivos: ${p.motivosTexto.join(" | ")}');
    }

    // Simulação What-If: Reduzir fator de eficiência para 75% e adicionar 2 técnicos temporários
    final cenarioSim = CenarioSimulacao(
      id: 'sim_dev_1',
      nome: 'Cenário Contingencial',
      criadoEm: DateTime.now(),
      ajusteExecutoresDisponiveis: 2,
      fatorEficienciaSimulado: 0.75,
    );

    final balancoSimulado = service.simularCenario(
      balancoBase: balancoNov,
      cenario: cenarioSim,
      capacidadesExecutoresOriginais: capsExec,
      config: configPadrao,
    );

    print('\n-> Resultado da Simulação What-If (em memória):');
    print('   Capacidade Base: ${balancoNov.horasAjustadas.toStringAsFixed(0)}h -> Simulada: ${balancoSimulado.horasAjustadas.toStringAsFixed(0)}h');
    print('   Saldo Base: ${balancoNov.saldoHorasCalculado.toStringAsFixed(0)}h -> Simulado: ${balancoSimulado.saldoHorasCalculado.toStringAsFixed(0)}h');

    swTotal.stop();
    print('\n========================================================================');
    print('  VALIDAÇÃO CONCLUÍDA COM SUCESSO EM ${swTotal.elapsedMilliseconds} ms! ');
    print('========================================================================\n');

    expect(calNov.diasUteis, greaterThan(0));
    expect(capsExec, isNotEmpty);
    expect(balancoNov.isSaldoConfiavel, isFalse); // Trava de não-ociosidade ativa
  });
}
