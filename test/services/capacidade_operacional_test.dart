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
  group('Fase 3 — Incremento 1: Calendário Útil, Capacidade Bruta e Indisponibilidades', () {
    late CapacidadeService service;

    setUp(() {
      service = CapacidadeService();
    });

    test('1.1. Calendário útil: Deduz finais de semana e feriados em dias úteis com precisão', () {
      // Novembro de 2026: 30 dias
      // 01/11/2026 = Domingo, 02/11/2026 = Segunda (Finados - Feriado Nacional)
      // 15/11/2026 = Domingo (Proclamação da República - cai em domingo, não reduz dias úteis adicionais)
      // 20/11/2026 = Sexta (Dia da Consciência Negra - Feriado Nacional)
      final agora = DateTime.now();
      final feriados = <Feriado>[
        Feriado(
          id: 'f1',
          data: DateTime(2026, 11, 2),
          descricao: 'Finados',
          tipo: 'NACIONAL',
          createdAt: agora,
          updatedAt: agora,
        ),
        Feriado(
          id: 'f2',
          data: DateTime(2026, 11, 15),
          descricao: 'Proclamação da República',
          tipo: 'NACIONAL',
          createdAt: agora,
          updatedAt: agora,
        ),
        Feriado(
          id: 'f3',
          data: DateTime(2026, 11, 20),
          descricao: 'Consciência Negra',
          tipo: 'NACIONAL',
          createdAt: agora,
          updatedAt: agora,
        ),
      ];

      final cal = service.calcularCalendarioMes(
        ano: 2026,
        mes: 11,
        feriadosCadastrados: feriados,
      );

      expect(cal.diasNoMes, equals(30));
      expect(cal.diasFimDeSemana, equals(9)); // 4 sábados e 5 domingos em nov/2026
      expect(cal.feriadosEmDiasUteis, equals(2)); // Dias 02 e 20 caem em dias úteis (dia 15 cai em domingo)
      expect(cal.diasUteis, equals(19)); // 30 - 9 - 2 = 19 dias úteis
      expect(cal.feriadosNomes, contains('Finados'));
      expect(cal.feriadosNomes, contains('Consciência Negra'));
    });

    test('1.2. Capacidade bruta e fator de eficiência: Jornada parametrizável (8h/dia, 85%)', () {
      final cal = CalendarioMesInfo(
        ano: 2026,
        mes: 11,
        diasNoMes: 30,
        diasFimDeSemana: 9,
        feriadosEmDiasUteis: 1,
        diasUteis: 20,
      );

      final executor = Executor(
        id: 'exec-1',
        nome: 'João Eletricista',
        ativo: true,
      );

      final equipe = Equipe(
        id: 'eq-1',
        nome: 'Equipe Subestação',
        tipo: 'FIXA',
        ativo: true,
        executores: [
          EquipeExecutor(executorId: 'exec-1', executorNome: 'João Eletricista', papel: 'EXECUTOR'),
        ],
      );

      final capacidades = service.calcularCapacidadeExecutoresMes(
        ano: 2026,
        mes: 11,
        executores: [executor],
        equipes: [equipe],
        tarefasDoPeriodo: [],
        calendario: cal,
        config: const ConfiguracaoCapacidade(
          jornadaDiariaHoras: 8.0,
          fatorEficiencia: 0.85,
        ),
      );

      expect(capacidades.length, equals(1));
      final cap = capacidades.first;
      expect(cap.horasBrutas, equals(160.0)); // 20 dias * 8h = 160h
      expect(cap.horasAjustadas, equals(136.0)); // 160h * 0.85 = 136h
      expect(cap.horasIndisponiveis, equals(0.0));
      expect(cap.saldoHoras, equals(136.0));
    });

    test('1.3. Indisponibilidades conhecidas: Deduz férias registradas sem dupla perda', () {
      final cal = CalendarioMesInfo(
        ano: 2026,
        mes: 11,
        diasNoMes: 30,
        diasFimDeSemana: 9,
        feriadosEmDiasUteis: 0,
        diasUteis: 21,
      );

      final executor = Executor(id: 'exec-1', nome: 'Carlos Linheiro', ativo: true);
      final equipe = Equipe(
        id: 'eq-1',
        nome: 'Linha Viva',
        tipo: 'FIXA',
        ativo: true,
        executores: [EquipeExecutor(executorId: 'exec-1', executorNome: 'Carlos Linheiro', papel: 'EXECUTOR')],
      );

      // Férias de 5 dias úteis em novembro de 2026 (09/11 a 13/11) = 40h
      final taskFerias = Task(
        id: 'task-ferias-1',
        tipo: 'FERIAS',
        status: 'PROG',
        tarefa: 'Férias Programadas',
        coordenador: 'Coord',
        regional: 'Nordeste',
        divisao: 'Div',
        dataInicio: DateTime(2026, 11, 9, 8),
        dataFim: DateTime(2026, 11, 13, 17),
        executorIds: ['exec-1'],
      );

      final capacidades = service.calcularCapacidadeExecutoresMes(
        ano: 2026,
        mes: 11,
        executores: [executor],
        equipes: [equipe],
        tarefasDoPeriodo: [taskFerias],
        calendario: cal,
        config: const ConfiguracaoCapacidade(jornadaDiariaHoras: 8.0, fatorEficiencia: 0.85),
      );

      final cap = capacidades.first;
      expect(cap.horasBrutas, equals(168.0)); // 21 * 8 = 168h
      expect(cap.horasIndisponiveis, equals(40.0)); // 5 dias * 8h = 40h de férias
      // Ajustada = (168 * 0.85) - 40 = 142.8 - 40 = 102.8h
      expect(cap.horasAjustadas, closeTo(102.8, 0.01));
      // As férias NÃO devem ser contadas como horas comprometidas operacionais
      expect(cap.horasComprometidas, equals(0.0));
    });

    test('1.4. Tratamento de executores sem equipe: Inclusão ou exclusão comutável', () {
      final cal = CalendarioMesInfo(ano: 2026, mes: 11, diasNoMes: 30, diasFimDeSemana: 8, feriadosEmDiasUteis: 0, diasUteis: 22);

      final execComEquipe = Executor(id: 'exec-1', nome: 'Com Equipe', ativo: true);
      final execAvulso = Executor(id: 'exec-2', nome: 'Avulso da Divisão', ativo: true);

      final equipe = Equipe(
        id: 'eq-1',
        nome: 'Equipe Alpha',
        tipo: 'FIXA',
        ativo: true,
        executores: [EquipeExecutor(executorId: 'exec-1', executorNome: 'Com Equipe', papel: 'EXECUTOR')],
      );

      // Modo 1: Apenas equipes formais
      final capEquipes = service.calcularCapacidadeExecutoresMes(
        ano: 2026,
        mes: 11,
        executores: [execComEquipe, execAvulso],
        equipes: [equipe],
        tarefasDoPeriodo: [],
        calendario: cal,
        config: const ConfiguracaoCapacidade(incluirExecutoresSemEquipe: false),
      );
      expect(capEquipes.length, equals(1));
      expect(capEquipes.first.executorId, equals('exec-1'));

      // Modo 2: Quadro completo da divisão (inclui avulsos)
      final capQuadroTotal = service.calcularCapacidadeExecutoresMes(
        ano: 2026,
        mes: 11,
        executores: [execComEquipe, execAvulso],
        equipes: [equipe],
        tarefasDoPeriodo: [],
        calendario: cal,
        config: const ConfiguracaoCapacidade(incluirExecutoresSemEquipe: true),
      );
      expect(capQuadroTotal.length, equals(2));
      expect(capQuadroTotal.any((c) => c.executorId == 'exec-2' && !c.temEquipeVinculada), isTrue);
    });
  });

  group('Fase 3 — Incremento 2: Horas Comprometidas por Executor e Multiplicidade', () {
    late CapacidadeService service;

    setUp(() {
      service = CapacidadeService();
    });

    test('2.1. Multiplicidade de executores: Tarefa de 8h com 4 executores = 32h de esforço total', () {
      final cal = CalendarioMesInfo(ano: 2026, mes: 11, diasNoMes: 30, diasFimDeSemana: 8, feriadosEmDiasUteis: 0, diasUteis: 22);

      final executores = [
        Executor(id: 'e1', nome: 'Técnico 1', ativo: true),
        Executor(id: 'e2', nome: 'Técnico 2', ativo: true),
        Executor(id: 'e3', nome: 'Técnico 3', ativo: true),
        Executor(id: 'e4', nome: 'Técnico 4', ativo: true),
      ];

      final equipe = Equipe(
        id: 'eq-1',
        nome: 'Equipe Pesada',
        tipo: 'FIXA',
        ativo: true,
        executores: executores.map((e) => EquipeExecutor(executorId: e.id, executorNome: e.nome, papel: 'EXECUTOR')).toList(),
      );

      // Atividade de manutenção preventiva de 1 dia útil (8h) com os 4 executores
      final taskMultipla = Task(
        id: 'task-preventiva-1',
        tipo: 'MP',
        status: 'PROG',
        tarefa: 'Manutenção em Transformador 230kV',
        coordenador: 'Coord',
        regional: 'Nordeste',
        divisao: 'Div',
        dataInicio: DateTime(2026, 11, 4, 8),
        dataFim: DateTime(2026, 11, 4, 17),
        executorIds: ['e1', 'e2', 'e3', 'e4'],
      );

      final capacidades = service.calcularCapacidadeExecutoresMes(
        ano: 2026,
        mes: 11,
        executores: executores,
        equipes: [equipe],
        tarefasDoPeriodo: [taskMultipla],
        calendario: cal,
        config: const ConfiguracaoCapacidade(jornadaDiariaHoras: 8.0, fatorEficiencia: 1.0),
      );

      // Cada um dos 4 executores deve ter exatamente 8h comprometidas
      for (final cap in capacidades) {
        expect(cap.horasComprometidas, equals(8.0));
      }

      // Soma do esforço total da equipe nesta tarefa = 32h homem-hora
      final somaComprometida = capacidades.fold<double>(0.0, (acc, c) => acc + c.horasComprometidas);
      expect(somaComprometida, equals(32.0));
    });

    test('2.2. Tarefas canceladas: Não consom capacidade operacional', () {
      final cal = CalendarioMesInfo(ano: 2026, mes: 11, diasNoMes: 30, diasFimDeSemana: 8, feriadosEmDiasUteis: 0, diasUteis: 22);
      final executor = Executor(id: 'e1', nome: 'Técnico 1', ativo: true);
      final equipe = Equipe(
        id: 'eq-1',
        nome: 'Equipe 1',
        tipo: 'FIXA',
        ativo: true,
        executores: [EquipeExecutor(executorId: 'e1', executorNome: 'Técnico 1', papel: 'EXECUTOR')],
      );

      final taskCancelada = Task(
        id: 'task-canc-1',
        tipo: 'MP',
        status: 'CANC',
        tarefa: 'Tarefa Cancelada',
        coordenador: 'Coord',
        regional: 'Nordeste',
        divisao: 'Div',
        dataInicio: DateTime(2026, 11, 4, 8),
        dataFim: DateTime(2026, 11, 4, 17),
        executorIds: ['e1'],
      );

      final capacidades = service.calcularCapacidadeExecutoresMes(
        ano: 2026,
        mes: 11,
        executores: [executor],
        equipes: [equipe],
        tarefasDoPeriodo: [taskCancelada],
        calendario: cal,
      );

      expect(capacidades.first.horasComprometidas, equals(0.0));
    });

    test('2.3. Tarefa transpassando meses: Computa apenas a fração de dias úteis incidente no mês', () {
      // Tarefa que começa em 25/10/2026 e vai até 06/11/2026
      // Em novembro de 2026: 01/11 é domingo. Dias 02 a 06 = 5 dias úteis (sendo 02 a 06 de novembro = 5 dias)
      final cal = CalendarioMesInfo(ano: 2026, mes: 11, diasNoMes: 30, diasFimDeSemana: 8, feriadosEmDiasUteis: 0, diasUteis: 22);
      final executor = Executor(id: 'e1', nome: 'Técnico 1', ativo: true);
      final equipe = Equipe(
        id: 'eq-1',
        nome: 'Equipe 1',
        tipo: 'FIXA',
        ativo: true,
        executores: [EquipeExecutor(executorId: 'e1', executorNome: 'Técnico 1', papel: 'EXECUTOR')],
      );

      final taskLonga = Task(
        id: 'task-longa-1',
        tipo: 'MP',
        status: 'PROG',
        tarefa: 'Campanha de Medições',
        coordenador: 'Coord',
        regional: 'Nordeste',
        divisao: 'Div',
        dataInicio: DateTime(2026, 10, 25, 8),
        dataFim: DateTime(2026, 11, 6, 17),
        executorIds: ['e1'],
      );

      final capacidades = service.calcularCapacidadeExecutoresMes(
        ano: 2026,
        mes: 11,
        executores: [executor],
        equipes: [equipe],
        tarefasDoPeriodo: [taskLonga],
        calendario: cal,
        config: const ConfiguracaoCapacidade(jornadaDiariaHoras: 8.0),
      );

      // Em novembro, a intersecção de dias úteis (02/11 a 06/11) são 5 dias * 8h = 40h
      expect(capacidades.first.horasComprometidas, equals(40.0));
    });
  });

  group('Fase 3 — Incremento 3: Demanda Estimada e Indicadores de Confiabilidade', () {
    late CapacidadeService service;

    setUp(() {
      service = CapacidadeService();
    });

    test('3.1. Segregação mandatória: Notas com estimativa confirmada vs. notas sem dimensionamento', () {
      final notas = [
        const BacklogNotaItem(id: 'n1', nota: '1001', descricao: 'Nota com análise técnica', estimativaHoras: 16.0),
        const BacklogNotaItem(id: 'n2', nota: '1002', descricao: 'Nota com análise técnica 2', estimativaHoras: 24.0),
        const BacklogNotaItem(id: 'n3', nota: '1003', descricao: 'Nota avulsa sem estimativa', estimativaHoras: null),
        const BacklogNotaItem(id: 'n4', nota: '1004', descricao: 'Outra nota sem estimativa', estimativaHoras: 0.0),
      ];

      final demanda = service.consolidarDemandaCarteiraMes(
        ano: 2026,
        mes: 11,
        notasPrevistasNoMes: notas,
        config: const ConfiguracaoCapacidade(horasPadraoBenchmarkPorNota: 5.0),
      );

      expect(demanda.totalNotasPrevistas, equals(4));
      expect(demanda.notasComEstimativa, equals(2));
      expect(demanda.notasSemEstimativa, equals(2));
      expect(demanda.horasEstimadasConfirmadas, equals(40.0)); // 16 + 24 = 40h confirmadas
      expect(demanda.percentualCoberturaEstimativa, equals(50.0)); // 2 / 4 = 50%
      expect(demanda.horasBenchmarkHistorico, equals(20.0)); // 4 * 5.0 = 20h paramétricas de referência
      expect(demanda.temRiscoIncerteza, isTrue); // Menos de 80% cobertas
    });

    test('3.2. Grau de confiabilidade: Saldo aparente positivo NÃO é considerado confiável com baixa cobertura', () {
      final cal = CalendarioMesInfo(ano: 2026, mes: 11, diasNoMes: 30, diasFimDeSemana: 8, feriadosEmDiasUteis: 0, diasUteis: 20);

      // Capacidade: 1 técnico com 160h ajustadas e 20h comprometidas = 140h disponíveis
      const capExec = CapacidadeExecutorMes(
        executorId: 'e1',
        executorNome: 'Técnico',
        ano: 2026,
        mes: 11,
        diasUteis: 20,
        jornadaDiaria: 8.0,
        horasBrutas: 160.0,
        horasIndisponiveis: 0.0,
        fatorEficiencia: 1.0,
        horasAjustadas: 160.0,
        horasComprometidas: 20.0,
        saldoHoras: 140.0,
      );

      // Demanda: 10 notas previstas, mas APENAS 1 com estimativa (10h confirmadas) e 9 sem estimativa!
      const demandaBaixaCobertura = DemandaCarteiraMes(
        ano: 2026,
        mes: 11,
        totalNotasPrevistas: 10,
        notasComEstimativa: 1,
        horasEstimadasConfirmadas: 10.0,
        notasSemEstimativa: 9,
        percentualCoberturaEstimativa: 10.0, // 10% de cobertura
      );

      final balanco = service.calcularBalanceamentoMensal(
        ano: 2026,
        mes: 11,
        capacidadesExecutores: [capExec],
        demanda: demandaBaixaCobertura,
        calendario: cal,
      );

      // O saldo aparente é 140h - 10h = +130h
      expect(balanco.saldoHorasCalculado, equals(130.0));
      // Conforme diretriz fundamental do usuário:
      // Saldo positivo NÃO PODE ser anunciado como folga confirmada quando houver incerteza crítica!
      expect(balanco.nivelConfiabilidade, equals(NivelConfiabilidadeCapacidade.baixa));
      expect(balanco.isSaldoConfiavel, isFalse);
      expect(balanco.motivoConfiabilidade, contains('Incerteza Crítica'));
    });

    test('3.3. Sobrecarga confirmada: Confiabilidade é alta quando horas estimadas excedem a capacidade', () {
      final cal = CalendarioMesInfo(ano: 2026, mes: 11, diasNoMes: 30, diasFimDeSemana: 8, feriadosEmDiasUteis: 0, diasUteis: 20);

      const capExec = CapacidadeExecutorMes(
        executorId: 'e1',
        executorNome: 'Técnico',
        ano: 2026,
        mes: 11,
        diasUteis: 20,
        jornadaDiaria: 8.0,
        horasBrutas: 160.0,
        horasIndisponiveis: 0.0,
        fatorEficiencia: 1.0,
        horasAjustadas: 160.0,
        horasComprometidas: 100.0,
        saldoHoras: 60.0,
      );

      // Demanda confirmada de 120h em 5 notas todas com estimativa (100% de cobertura)
      const demandaAltaCobertura = DemandaCarteiraMes(
        ano: 2026,
        mes: 11,
        totalNotasPrevistas: 5,
        notasComEstimativa: 5,
        horasEstimadasConfirmadas: 120.0,
        notasSemEstimativa: 0,
        percentualCoberturaEstimativa: 100.0,
      );

      final balanco = service.calcularBalanceamentoMensal(
        ano: 2026,
        mes: 11,
        capacidadesExecutores: [capExec],
        demanda: demandaAltaCobertura,
        calendario: cal,
      );

      // Disponível: 60h. Demanda: 120h. Saldo: -60h (Sobrecarga de 60 horas)
      expect(balanco.capacidadeDisponivel, equals(60.0));
      expect(balanco.saldoHorasCalculado, equals(-60.0));
      expect(balanco.status, equals(StatusBalanceamentoMensal.sobrecarga));
      expect(balanco.nivelConfiabilidade, equals(NivelConfiabilidadeCapacidade.alta));
      expect(balanco.isSaldoConfiavel, isTrue);
      // Taxa de comprometimento: (100h programadas + 120h demanda) / 160h = 137.5%
      expect(balanco.taxaComprometimentoTotal, closeTo(137.5, 0.1));
    });
  });
}
