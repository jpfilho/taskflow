import 'package:flutter_test/flutter_test.dart';
import 'package:supabase/supabase.dart';
import 'package:task2026/models/capacidade_operacional_models.dart';
import 'package:task2026/models/executor.dart';
import 'package:task2026/models/equipe.dart';
import 'package:task2026/models/task.dart';
import 'package:task2026/models/feriado.dart';
import 'package:task2026/services/capacidade_service.dart';

void main() {
  test('Fase 4: Validação Gerencial Integrada com Volume Real de Dados (Carga Completa)', () async {
    print('========================================================================');
    print('  FASE 4: VALIDAÇÃO INTEGRADA COM VOLUME COMPLETO DE DADOS (DEV)        ');
    print('========================================================================');

    final swTotal = Stopwatch()..start();
    int totalConsultas = 0;

    final client = SupabaseClient(
      'http://212.85.0.249:8000',
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzY1ODE3OTgzLCJleHAiOjIwODExNzc5ODN9.YQByqDrpmw0en7VeEcjDfvvTx8Ind_q8gD6-bzEY4Yc',
    );

    final service = CapacidadeService.comServicos();

    // 1. CARGA COMPLETA DE FERIADOS
    final swFeriados = Stopwatch()..start();
    final feriadosRaw = await client.from('feriados').select('*');
    totalConsultas++;
    final List<Feriado> feriados = (feriadosRaw as List)
        .map((f) => Feriado.fromMap(f as Map<String, dynamic>))
        .toList();
    swFeriados.stop();

    // 2. CARGA COMPLETA DE EQUIPES E VÍNCULOS
    final swEquipes = Stopwatch()..start();
    final equipesRaw = await client.from('equipes').select('*, equipes_executores(*, executores(nome))');
    totalConsultas++;
    final List<Equipe> equipes = (equipesRaw as List)
        .map((e) => Equipe.fromMap(e as Map<String, dynamic>))
        .toList();
    swEquipes.stop();

    // 3. CARGA COMPLETA DE TODOS OS EXECUTORES
    final swExec = Stopwatch()..start();
    final executoresRaw = await client.from('executores').select('*');
    totalConsultas++;
    final List<Executor> executores = (executoresRaw as List)
        .map((ex) => Executor.fromMap(ex as Map<String, dynamic>))
        .toList();
    swExec.stop();

    // 4. CARGA COMPLETA DE TAREFAS ATIVAS NO INTERVALO DO ANO/TRIMESTRE
    final swTasks = Stopwatch()..start();
    // Consultando todas as tarefas do 2º semestre de 2026 sem limite amostral
    final tasksRaw = await client
        .from('tasks')
        .select('*')
        .or('and(data_inicio.lte.2026-12-31T23:59:59,data_fim.gte.2026-07-01T00:00:00)');
    totalConsultas++;
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
    swTasks.stop();

    // 5. CARGA DE GRUPOS E ANÁLISES TÉCNICAS
    final swGrupos = Stopwatch()..start();
    final gruposRaw = await client.from('notas_sap_grupos').select('*');
    totalConsultas++;
    final analisesRaw = await client.from('notas_sap_analises').select('*');
    totalConsultas++;
    swGrupos.stop();

    print('\n[Métricas de Carga de Dados Reais]:');
    print('-> Feriados Carregados: ${feriados.length} (${swFeriados.elapsedMilliseconds} ms)');
    print('-> Equipes Carregadas: ${equipes.length} (${swEquipes.elapsedMilliseconds} ms)');
    print('-> Executores Totais: ${executores.length} (${swExec.elapsedMilliseconds} ms)');
    print('-> Tarefas no Período 2S/2026: ${tarefas.length} (${swTasks.elapsedMilliseconds} ms)');
    print('-> Grupos de Notas: ${(gruposRaw as List).length} | Análises Técnicas: ${(analisesRaw as List).length} (${swGrupos.elapsedMilliseconds} ms)');
    print('-> Total de Consultas Executadas: $totalConsultas (Otimizado sem N+1)');

    // 6. PROCESSAMENTO DE CAPACIDADE OPERACIONAL COMPLETA
    final swCalc = Stopwatch()..start();
    final calNov = service.calcularCalendarioMes(
      ano: 2026,
      mes: 11,
      feriadosCadastrados: feriados,
    );

    const config = ConfiguracaoCapacidade(
      jornadaDiariaHoras: 8.0,
      fatorEficiencia: 0.85,
      incluirExecutoresSemEquipe: false,
      limiteConfiabilidadeMinimo: 80.0,
    );

    final capsExec = service.calcularCapacidadeExecutoresMes(
      ano: 2026,
      mes: 11,
      executores: executores,
      equipes: equipes,
      tarefasDoPeriodo: tarefas,
      calendario: calNov,
      config: config,
    );

    double somaBrutas = 0.0;
    double somaAjustadas = 0.0;
    double somaComprometidas = 0.0;
    for (final c in capsExec) {
      somaBrutas += c.horasBrutas;
      somaAjustadas += c.horasAjustadas;
      somaComprometidas += c.horasComprometidas;
    }
    swCalc.stop();

    print('\n[Métricas de Capacidade Operacional (Novembro/2026)]:');
    print('-> Executores Elegíveis Alocados: ${capsExec.length}');
    print('-> Horas Brutas Disponíveis: ${somaBrutas.toStringAsFixed(1)} h');
    print('-> Horas Ajustadas (85% eficiência): ${somaAjustadas.toStringAsFixed(1)} h');
    print('-> Horas Comprometidas em Tarefas: ${somaComprometidas.toStringAsFixed(1)} h');
    print('-> Tempo de Processamento de Capacidade: ${swCalc.elapsedMilliseconds} ms');

    // 7. AUDITORIA DAS ESTIMATIVAS DE ANÁLISE TÉCNICA
    int estimativasConfirmadas = 0;
    int zerosConfirmados = 0;
    int zerosPadrao = 0;

    for (final an in (analisesRaw as List)) {
      final map = an as Map<String, dynamic>;
      final est = double.tryParse(map['estimativa_horas']?.toString() ?? '');
      final status = map['status_analise']?.toString();
      final diag = map['diagnostico_previo']?.toString();

      if (est != null && est > 0) {
        estimativasConfirmadas++;
      } else if (est == 0.0 && status == 'concluida' && diag != null && diag.isNotEmpty) {
        zerosConfirmados++;
      } else {
        zerosPadrao++;
      }
    }

    print('\n[Auditoria Real de Estimativas Técnicas]:');
    print('-> Estimativas Confirmadas (> 0h): $estimativasConfirmadas');
    print('-> Zeros Confirmados (Análise técnica concluída): $zerosConfirmados');
    print('-> Zeros Padrão / Rascunhos de Sistema: $zerosPadrao');

    // 8. SIMULAÇÃO GERENCIAL NÃO-DESTRUTIVA COMPLETA (TESTE DE CONTINGÊNCIA)
    final swSim = Stopwatch()..start();
    final balancoBase = service.calcularBalanceamentoMensal(
      ano: 2026,
      mes: 11,
      capacidadesExecutores: capsExec,
      demanda: DemandaCarteiraMes(
        ano: 2026,
        mes: 11,
        totalNotasPrevistas: 10,
        notasComEstimativa: 8,
        notasSemEstimativa: 2,
        horasEstimadasConfirmadas: 500.0,
        horasEstimadasNaoProgramadas: 400.0,
        percentualCoberturaEstimativa: 80.0,
      ),
      calendario: calNov,
      config: config,
    );

    // Cenário: Contingência com redução de 5 técnicos e postergação de demanda
    final cenario = CenarioSimulacao(
      id: 'sim_contingencia',
      nome: 'Cenário Contingência 2S/2026',
      criadoEm: DateTime.now(),
      ajusteExecutoresDisponiveis: -5,
      fatorEficienciaSimulado: 0.80,
    );

    final balancoSimulado = service.simularCenario(
      balancoBase: balancoBase,
      cenario: cenario,
      capacidadesExecutoresOriginais: capsExec,
      config: config,
    );

    final comparativo = service.gerarComparativoSimulacao(
      balancoBase: balancoBase,
      balancoSimulado: balancoSimulado,
      cenario: cenario,
      notasAvaliadas: const [],
    );
    swSim.stop();

    print('\n[Resultado da Simulação Gerencial Não-Destrutiva]:');
    print('-> Delta de Capacidade: ${comparativo.deltaCapacidadeHoras.toStringAsFixed(1)} h');
    print('-> Delta de Saldo Projetado: ${comparativo.deltaSaldoHoras.toStringAsFixed(1)} h');
    print('-> Variação de Força de Trabalho: ${comparativo.deltaExecutores} executores');
    print('-> Tempo da Simulação em Memória: ${swSim.elapsedMilliseconds} ms');

    swTotal.stop();
    print('\n========================================================================');
    print('  CARGA COMPLETA EXECUTADA COM SUCESSO EM ${swTotal.elapsedMilliseconds} ms! ');
    print('========================================================================\n');

    expect(totalConsultas, lessThanOrEqualTo(6));
    expect(capsExec, isNotEmpty);
    expect(swCalc.elapsedMilliseconds, lessThan(100)); // Processamento veloz < 100ms
  });
}
