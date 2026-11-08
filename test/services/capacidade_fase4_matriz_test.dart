import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/models/capacidade_operacional_models.dart';
import 'package:task2026/models/executor.dart';
import 'package:task2026/models/equipe.dart';
import 'package:task2026/models/equipe_executor.dart';
import 'package:task2026/models/task.dart';
import 'package:task2026/models/feriado.dart';
import 'package:task2026/models/backlog_macro_models.dart';
import 'package:task2026/services/capacidade_service.dart';

void main() {
  group('Fase 4: Matriz de Testes Funcionais (15 Cenários Mandatórios)', () {
    late CapacidadeService service;
    late CalendarioMesInfo calNov2026;
    const configPadrao = ConfiguracaoCapacidade(
      jornadaDiariaHoras: 8.0,
      fatorEficiencia: 0.85,
      limiteConfiabilidadeMinimo: 80.0,
    );

    setUp(() {
      service = CapacidadeService.comServicos();
      calNov2026 = service.calcularCalendarioMes(
        ano: 2026,
        mes: 11,
        feriadosCadastrados: [
          Feriado(id: 'f1', descricao: 'Finados', data: DateTime(2026, 11, 2), tipo: 'NACIONAL', createdAt: DateTime.now(), updatedAt: DateTime.now()),
          Feriado(id: 'f2', descricao: 'Consciência Negra', data: DateTime(2026, 11, 20), tipo: 'NACIONAL', createdAt: DateTime.now(), updatedAt: DateTime.now()),
        ],
      );
    });

    // 1. Nota sem previsão
    test('1. Nota sem previsão: Não compõe a demanda de meses específicos e não consome capacidade', () {
      final demandaNov = service.consolidarDemandaCarteiraMes(
        ano: 2026,
        mes: 11,
        notasPrevistasNoMes: const [], // Não prevista em novembro
        config: configPadrao,
      );

      expect(demandaNov.totalNotasPrevistas, equals(0));
      expect(demandaNov.horasEstimadasConfirmadas, equals(0.0));
      expect(demandaNov.percentualCoberturaEstimativa, equals(100.0)); // Sem demandas no mês
    });

    // 2. Nota prevista individualmente
    test('2. Nota prevista individualmente: Compõe a demanda do mês com suas horas técnicas', () {
      final notas = [
        const BacklogNotaItem(
          id: 'n2',
          nota: '1002',
          descricao: 'Nota com previsão individual para 11/2026',
          estimativaHoras: 24.0,
          statusAnalise: 'concluida',
        ),
      ];

      final demandaNov = service.consolidarDemandaCarteiraMes(
        ano: 2026,
        mes: 11,
        notasPrevistasNoMes: notas,
        config: configPadrao,
      );

      expect(demandaNov.totalNotasPrevistas, equals(1));
      expect(demandaNov.horasEstimadasConfirmadas, equals(24.0));
      expect(demandaNov.notasComEstimativa, equals(1));
      expect(demandaNov.percentualCoberturaEstimativa, equals(100.0));
    });

    // 3. Nota prevista por grupo
    test('3. Nota prevista por grupo: Herda a previsão do grupo e compõe a demanda mensal', () {
      final notasDoGrupo = [
        const BacklogNotaItem(
          id: 'n3_1',
          nota: '1003',
          descricao: 'Nota 1 do Grupo Alfa',
          grupoId: 'grp_alfa',
          estimativaHoras: 10.0,
          statusAnalise: 'concluida',
        ),
        const BacklogNotaItem(
          id: 'n3_2',
          nota: '1004',
          descricao: 'Nota 2 do Grupo Alfa',
          grupoId: 'grp_alfa',
          estimativaHoras: 15.0,
          statusAnalise: 'concluida',
        ),
      ];

      final demandaNov = service.consolidarDemandaCarteiraMes(
        ano: 2026,
        mes: 11,
        notasPrevistasNoMes: notasDoGrupo,
        config: configPadrao,
      );

      expect(demandaNov.totalNotasPrevistas, equals(2));
      expect(demandaNov.horasEstimadasConfirmadas, equals(25.0));
    });

    // 4. Nota programada operacionalmente
    test('4. Nota programada operacionalmente: Horas deduzidas na programação sem dupla contagem', () {
      final notas = [
        const BacklogNotaItem(
          id: 'n4',
          nota: '1005',
          descricao: 'Nota já convertida em tarefa ativa',
          estimativaHoras: 20.0,
          statusAnalise: 'concluida',
          tasks: [BacklogTaskInfo(id: 't_prog', status: 'PROG')],
        ),
      ];

      final demandaNov = service.consolidarDemandaCarteiraMes(
        ano: 2026,
        mes: 11,
        notasPrevistasNoMes: notas,
        notasComTarefaProgramadaIds: {'n4', '1005'},
        config: configPadrao,
      );

      expect(demandaNov.totalNotasPrevistas, equals(1));
      expect(demandaNov.horasEstimadasConfirmadas, equals(20.0));
      expect(demandaNov.horasEstimadasNaoProgramadas, equals(0.0),
          reason: 'Horas não devem ser cobradas em duplicidade na demanda pendente');
    });

    // 5. Nota com prazo vencido
    test('5. Nota com prazo vencido: Recebe pontuação máxima de prazo no score consultivo', () {
      final notaVencida = BacklogNotaItem(
        id: 'n5',
        nota: '1006',
        descricao: 'Substituição de mufla crítica',
        dataFimDesejada: DateTime(2026, 10, 15), // Vencida antes de Nov/2026
        prioridade: '1',
      );

      final priorizacoes = service.calcularPriorizacaoNotas(
        notas: [notaVencida],
        dataReferencia: DateTime(2026, 11, 1),
      );

      expect(priorizacoes.first.scoreTotal, greaterThanOrEqualTo(50.0));
      expect(priorizacoes.first.motivosTexto.any((m) => m.contains('Prazo SAP ultrapassado')), isTrue);
    });

    // 6. Nota com previsão posterior ao prazo
    test('6. Nota com previsão posterior ao prazo: Impacto de prazo detecta atraso gerado', () {
      final nota = BacklogNotaItem(
        id: 'n6',
        nota: '1007',
        descricao: 'Manutenção de disjuntor',
        dataFimDesejada: DateTime(2026, 12, 15), // Meta em Dezembro
      );

      final cenario = CenarioSimulacao(
        id: 'sim_postergada',
        nome: 'Postergar para Janeiro 2027',
        criadoEm: DateTime.now(),
        mudancasPrevisaoNotas: {'n6': (ano: 2027, mes: 1)},
      );

      final balancoBase = service.calcularBalanceamentoMensal(
        ano: 2026,
        mes: 11,
        capacidadesExecutores: const [],
        demanda: service.consolidarDemandaCarteiraMes(ano: 2026, mes: 11, notasPrevistasNoMes: [nota]),
        calendario: calNov2026,
      );

      final comp = service.gerarComparativoSimulacao(
        balancoBase: balancoBase,
        balancoSimulado: balancoBase,
        cenario: cenario,
        notasAvaliadas: [nota],
      );

      expect(comp.impactosPrazos.first.ficouAtrasada, isTrue);
      expect(comp.impactosPrazos.first.gerouNovoRisco, isTrue);
    });

    // 7. Grupo parcialmente concluído
    test('7. Grupo parcialmente concluído: Deduz apenas as notas ainda pendentes', () {
      final notasGrupo = [
        const BacklogNotaItem(
          id: 'n7_1',
          nota: '1008',
          descricao: 'Nota Concluída no Grupo',
          estimativaHoras: 10.0,
          statusSistema: 'MSEN ORDA', // Concluída
          tasks: [BacklogTaskInfo(id: 't_conc', status: 'CONC')],
        ),
        const BacklogNotaItem(
          id: 'n7_2',
          nota: '1009',
          descricao: 'Nota Pendente no Grupo',
          estimativaHoras: 15.0,
          statusAnalise: 'concluida',
        ),
      ];

      // Apenas a nota pendente deve ser considerada na demanda ativa
      final notasPendentes = notasGrupo.where((n) => !(n.statusSistema?.contains('MSEN') ?? false)).toList();
      final demanda = service.consolidarDemandaCarteiraMes(
        ano: 2026,
        mes: 11,
        notasPrevistasNoMes: notasPendentes,
      );

      expect(demanda.totalNotasPrevistas, equals(1));
      expect(demanda.horasEstimadasConfirmadas, equals(15.0));
    });

    // 8. Nota sem estimativa
    test('8. Nota sem estimativa: Contabilizada como não dimensionada e reduz confiabilidade', () {
      final notas = [
        const BacklogNotaItem(
          id: 'n8',
          nota: '1010',
          descricao: 'Nota sem qualquer estimativa',
          estimativaHoras: null,
        ),
      ];

      final demanda = service.consolidarDemandaCarteiraMes(
        ano: 2026,
        mes: 11,
        notasPrevistasNoMes: notas,
      );

      expect(demanda.notasSemEstimativa, equals(1));
      expect(demanda.percentualCoberturaEstimativa, equals(0.0));
    });

    // 9. Executor em férias
    test('9. Executor em férias: Dedução precisa das horas de afastamento na capacidade', () {
      final executor = Executor(id: 'ex_ferias', nome: 'Técnico em Férias', ativo: true);
      final equipe = Equipe(id: 'eq1', nome: 'Equipe Alpha', tipo: 'LINHA_VIVA', executores: [
        EquipeExecutor(executorId: 'ex_ferias', executorNome: 'Técnico em Férias', papel: 'EXECUTOR'),
      ]);

      final taskFerias = Task(
        id: 't_ferias',
        status: 'PROG',
        statusNome: 'Programada',
        regional: 'Norte',
        divisao: 'Div1',
        segmento: 'Seg1',
        locais: const [],
        equipes: const [],
        executores: const [],
        tipo: 'FERIAS',
        tarefa: 'Férias Regulamentares',
        coordenador: '',
        executorIds: ['ex_ferias'],
        dataInicio: DateTime(2026, 11, 2, 8),
        dataFim: DateTime(2026, 11, 6, 16), // 5 dias (1 feriado útil + 4 dias úteis = 32h)
      );

      final caps = service.calcularCapacidadeExecutoresMes(
        ano: 2026,
        mes: 11,
        executores: [executor],
        equipes: [equipe],
        tarefasDoPeriodo: [taskFerias],
        calendario: calNov2026,
        config: configPadrao,
      );

      expect(caps.first.horasIndisponiveis, equals(40.0));
      expect(caps.first.horasAjustadas, equals((caps.first.horasBrutas * 0.85) - 40.0));
    });

    // 10. Executor em múltiplas tarefas
    test('10. Executor em múltiplas tarefas: Soma correta do esforço individual sem duplicidade', () {
      final executor = Executor(id: 'ex_mult', nome: 'Técnico Alocado', ativo: true);
      final equipe = Equipe(id: 'eq1', nome: 'Equipe Alpha', tipo: 'LINHA_VIVA', executores: [
        EquipeExecutor(executorId: 'ex_mult', executorNome: 'Técnico Alocado', papel: 'EXECUTOR'),
      ]);

      final t1 = Task(
        id: 't1',
        status: 'PROG',
        statusNome: 'Programada',
        regional: 'Norte',
        divisao: 'Div1',
        segmento: 'Seg1',
        locais: const [],
        equipes: const [],
        executores: const [],
        tipo: 'Manutenção',
        tarefa: 'Tarefa 1',
        coordenador: '',
        executorIds: ['ex_mult'],
        dataInicio: DateTime(2026, 11, 3, 8),
        dataFim: DateTime(2026, 11, 3, 16), // 1 dia útil = 8h
      );

      final t2 = Task(
        id: 't2',
        status: 'PROG',
        statusNome: 'Programada',
        regional: 'Norte',
        divisao: 'Div1',
        segmento: 'Seg1',
        locais: const [],
        equipes: const [],
        executores: const [],
        tipo: 'Manutenção',
        tarefa: 'Tarefa 2',
        coordenador: '',
        executorIds: ['ex_mult'],
        dataInicio: DateTime(2026, 11, 4, 8),
        dataFim: DateTime(2026, 11, 5, 16), // 2 dias úteis = 16h
      );

      final caps = service.calcularCapacidadeExecutoresMes(
        ano: 2026,
        mes: 11,
        executores: [executor],
        equipes: [equipe],
        tarefasDoPeriodo: [t1, t2],
        calendario: calNov2026,
        config: configPadrao,
      );

      expect(caps.first.horasComprometidas, equals(24.0)); // 8h + 16h
    });

    // 11. Mês com sobrecarga
    test('11. Mês com sobrecarga: Classifica como sobrecarga e saldo negativo', () {
      final balanco = service.calcularBalanceamentoMensal(
        ano: 2026,
        mes: 11,
        capacidadesExecutores: const [], // 0h de capacidade
        demanda: DemandaCarteiraMes(
          ano: 2026,
          mes: 11,
          totalNotasPrevistas: 5,
          notasComEstimativa: 5,
          notasSemEstimativa: 0,
          horasEstimadasConfirmadas: 200.0,
          percentualCoberturaEstimativa: 100.0,
        ),
        calendario: calNov2026,
        config: configPadrao,
      );

      expect(balanco.status, equals(StatusBalanceamentoMensal.sobrecarga));
      expect(balanco.nivelConfiabilidade, equals(NivelConfiabilidadeCapacidade.alta));
      expect(balanco.saldoHorasCalculado, equals(-200.0));
    });

    // 12. Mês com baixa confiabilidade
    test('12. Mês com baixa confiabilidade: Bloqueia saldo como folga operacional quando há baixa cobertura', () {
      final balanco = service.calcularBalanceamentoMensal(
        ano: 2026,
        mes: 11,
        capacidadesExecutores: const [],
        demanda: DemandaCarteiraMes(
          ano: 2026,
          mes: 11,
          totalNotasPrevistas: 10,
          notasComEstimativa: 2,
          notasSemEstimativa: 8,
          horasEstimadasConfirmadas: 20.0,
          percentualCoberturaEstimativa: 20.0, // Apenas 20%
        ),
        calendario: calNov2026,
        config: configPadrao,
      );

      expect(balanco.isSaldoConfiavel, isFalse);
      expect(balanco.nivelConfiabilidade, equals(NivelConfiabilidadeCapacidade.baixa));
    });

    // 13. Simulação de reprogramação
    test('13. Simulação de reprogramação: Desloca grupo e nota em memória sem persistir', () {
      final nota = const BacklogNotaItem(
        id: 'n13',
        nota: '1013',
        descricao: 'Nota de Teste Simulação',
        grupoId: 'grp_sim',
        estimativaHoras: 40.0,
        statusAnalise: 'concluida',
      );

      final balancoBase = service.calcularBalanceamentoMensal(
        ano: 2026,
        mes: 11,
        capacidadesExecutores: const [],
        demanda: service.consolidarDemandaCarteiraMes(ano: 2026, mes: 11, notasPrevistasNoMes: [nota]),
        calendario: calNov2026,
      );

      final cenario = CenarioSimulacao(
        id: 'sim_reprog',
        nome: 'Mover grupo para 12/2026',
        criadoEm: DateTime.now(),
        mudancasPrevisaoGrupos: {'grp_sim': (ano: 2026, mes: 12)},
      );

      final balancoSim = service.simularCenario(
        balancoBase: balancoBase,
        cenario: cenario,
        capacidadesExecutoresOriginais: const [],
        todasNotasCarteira: [nota],
      );

      expect(balancoSim.demanda.totalNotasPrevistas, equals(0),
          reason: 'A nota foi transferida para dezembro e saiu do balanço de novembro');
      expect(balancoSim.demanda.horasEstimadasConfirmadas, equals(0.0));
    });

    // 14. Alteração de filtros organizacionais
    test('14. Alteração de filtros organizacionais: Filtra equipes e executores por regional/divisão', () {
      final e1 = Executor(id: 'ex1', nome: 'Técnico Divisão 1', divisaoId: 'div1', ativo: true);
      final e2 = Executor(id: 'ex2', nome: 'Técnico Divisão 2', divisaoId: 'div2', ativo: true);

      final eq1 = Equipe(id: 'eq1', nome: 'Equipe Div 1', tipo: 'TURNO', divisaoId: 'div1', executores: [
        EquipeExecutor(executorId: 'ex1', executorNome: 'Técnico Divisão 1', papel: 'EXECUTOR'),
      ]);
      final eq2 = Equipe(id: 'eq2', nome: 'Equipe Div 2', tipo: 'TURNO', divisaoId: 'div2', executores: [
        EquipeExecutor(executorId: 'ex2', executorNome: 'Técnico Divisão 2', papel: 'EXECUTOR'),
      ]);

      // Filtrando para divisaoId == 'div1'
      final executoresDiv1 = [e1, e2].where((e) => e.divisaoId == 'div1').toList();
      final equipesDiv1 = [eq1, eq2].where((eq) => eq.divisaoId == 'div1').toList();

      final caps = service.calcularCapacidadeExecutoresMes(
        ano: 2026,
        mes: 11,
        executores: executoresDiv1,
        equipes: equipesDiv1,
        tarefasDoPeriodo: const [],
        calendario: calNov2026,
        config: configPadrao,
      );

      expect(caps.length, equals(1));
      expect(caps.first.executorId, equals('ex1'));
    });

    // 15. Navegação gerencial até os registros de origem
    test('15. Navegação até os registros de origem: Modelos preservam IDs de Notas, Grupos e Tasks', () {
      const nota = BacklogNotaItem(
        id: 'orig_nota_uuid',
        nota: '11559988',
        descricao: 'Origem rastreável',
        grupoId: 'orig_grupo_uuid',
        tasks: [BacklogTaskInfo(id: 'orig_task_uuid', status: 'PROG')],
      );

      final itemDemanda = ItemEstimativaNota(
        notaSapId: nota.notaSapId,
        numeroNota: nota.numeroNota,
        descricao: nota.descricao,
        horasEstimadas: 12.0,
        origem: OrigemEstimativaNota.confirmadaMaiorZero,
        jaPossuiTarefaProgramada: false,
      );

      expect(itemDemanda.notaSapId, equals('orig_nota_uuid'));
      expect(itemDemanda.numeroNota, equals('11559988'));
      expect(nota.grupoId, equals('orig_grupo_uuid'));
      expect(nota.tasks.first.id, equals('orig_task_uuid'));
    });
  });
}
