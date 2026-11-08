import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/models/capacidade_operacional_models.dart';
import 'package:task2026/models/backlog_macro_models.dart';
import 'package:task2026/services/capacidade_service.dart';

void main() {
  late CapacidadeService service;

  setUp(() {
    service = CapacidadeService.comServicos();
  });

  group('Fase 3 — Incremento 4: Balanceamento Mensal, Memória de Cálculo e Confiabilidade', () {
    test('4.1. Diferenciação de 0,0h: Zero confirmado vs Zero padrão vs Sem análise', () {
      final notas = [
        const BacklogNotaItem(
          id: 'nota_1',
          nota: '10001',
          descricao: 'Substituição de disjuntor',
          estimativaHoras: 16.0,
          statusAnalise: 'concluida',
        ),
        const BacklogNotaItem(
          id: 'nota_2',
          nota: '10002',
          descricao: 'Encerramento administrativo sem intervenção física',
          estimativaHoras: 0.0,
          statusAnalise: 'concluida',
          diagnosticoPrevio: 'Sem necessidade de trabalho de campo.',
        ),
        const BacklogNotaItem(
          id: 'nota_3',
          nota: '10003',
          descricao: 'Nota recém importada com valor padrão zero',
          estimativaHoras: 0.0,
          statusAnalise: 'nao_iniciada',
        ),
        const BacklogNotaItem(
          id: 'nota_4',
          nota: '10004',
          descricao: 'Nota sem análise técnica cadastrada',
          estimativaHoras: null,
        ),
      ];

      final demanda = service.consolidarDemandaCarteiraMes(
        ano: 2026,
        mes: 11,
        notasPrevistasNoMes: notas,
      );

      // Verificações estritas:
      expect(demanda.totalNotasPrevistas, 4);
      expect(demanda.notasZeroConfirmado, 1, reason: 'Nota 2 tem 0h confirmadas com diagnóstico explícito');
      expect(demanda.notasZeroPadrao, 1, reason: 'Nota 3 tem 0h padrão sem análise concluída');
      expect(demanda.notasComEstimativa, 2, reason: 'Nota 1 (16h) + Nota 2 (0h confirmado)');
      expect(demanda.notasSemEstimativa, 2, reason: 'Nota 3 (0h padrão) + Nota 4 (sem análise)');
      expect(demanda.horasEstimadasConfirmadas, 16.0);
      expect(demanda.percentualCoberturaEstimativa, 50.0);
    });

    test('4.2. Prevenção de Dupla Contagem: Nota já convertida em tarefa programada', () {
      final notas = [
        const BacklogNotaItem(
          id: 'nota_com_tarefa',
          nota: '10010',
          descricao: 'Reforma de barramento',
          estimativaHoras: 24.0,
          statusAnalise: 'concluida',
        ),
        const BacklogNotaItem(
          id: 'nota_sem_tarefa',
          nota: '10020',
          descricao: 'Inspeção termográfica',
          estimativaHoras: 8.0,
          statusAnalise: 'concluida',
        ),
      ];

      final demanda = service.consolidarDemandaCarteiraMes(
        ano: 2026,
        mes: 11,
        notasPrevistasNoMes: notas,
        notasComTarefaProgramadaIds: {'nota_com_tarefa'},
      );

      expect(demanda.notasJaProgramadas, 1);
      expect(demanda.horasEstimadasConfirmadas, 32.0, reason: 'Total estimado da carteira');
      expect(demanda.horasEstimadasNaoProgramadas, 8.0, reason: 'Apenas a nota sem tarefa pode ser deduzida do saldo');
    });

    test('4.3. Memória de Cálculo Auditável: Gera passos detalhados para o usuário', () {
      final cal = service.calcularCalendarioMes(ano: 2026, mes: 11);
      final demanda = service.consolidarDemandaCarteiraMes(
        ano: 2026,
        mes: 11,
        notasPrevistasNoMes: [
          const BacklogNotaItem(
            id: 'n1',
            nota: '1',
            descricao: 'Teste',
            estimativaHoras: 10.0,
            statusAnalise: 'concluida',
          ),
        ],
      );

      final balanco = service.calcularBalanceamentoMensal(
        ano: 2026,
        mes: 11,
        capacidadesExecutores: const [
          CapacidadeExecutorMes(
            executorId: 'e1',
            executorNome: 'Técnico 1',
            ano: 2026,
            mes: 11,
            diasUteis: 20,
            jornadaDiaria: 8.0,
            horasBrutas: 160.0,
            horasIndisponiveis: 0.0,
            fatorEficiencia: 0.85,
            horasAjustadas: 136.0,
            horasComprometidas: 36.0,
            saldoHoras: 100.0,
          ),
        ],
        demanda: demanda,
        calendario: cal,
      );

      expect(balanco.memoriaCalculo, isNotNull);
      final mem = balanco.memoriaCalculo!;
      expect(mem.passo1Calendario, contains('dias úteis'));
      expect(mem.passo2CapacidadeBruta, contains('160.0h brutas'));
      expect(mem.passo4CapacidadeAjustada, contains('136.0h ajustadas'));
      expect(mem.passo5HorasComprometidas, contains('36.0h'));
      expect(mem.passo7SaldoEConfiabilidade, contains('Saldo ='));
    });
  });

  group('Fase 3 — Incremento 6: Priorização Explicável e Simulação Não-Destrutiva', () {
    test('6.1. Priorização Explicável: Notas com atraso e criticidade alta recebem maior pontuação', () {
      final hoje = DateTime(2026, 11, 2);
      final notas = [
        BacklogNotaItem(
          id: 'nota_urgente',
          nota: '90001',
          descricao: 'Vazamento em transformador com risco e emergência',
          prioridade: '1 - Muito Alta',
          dataFimDesejada: hoje.subtract(const Duration(days: 10)), // Atrasada 10 dias
          dataCriacao: hoje.subtract(const Duration(days: 400)), // Mais de 1 ano
          grupoId: 'grp_1',
        ),
        BacklogNotaItem(
          id: 'nota_normal',
          nota: '90002',
          descricao: 'Pintura de suporte de cabos',
          prioridade: '4 - Baixa',
          dataFimDesejada: hoje.add(const Duration(days: 90)), // Prazo distante
          dataCriacao: hoje.subtract(const Duration(days: 30)),
        ),
      ];

      final priorizacoes = service.calcularPriorizacaoNotas(
        notas: notas,
        dataReferencia: hoje,
      );

      expect(priorizacoes.length, 2);
      final p1 = priorizacoes.first;
      final p2 = priorizacoes.last;

      expect(p1.notaSapId, 'nota_urgente');
      expect(p1.scoreTotal, greaterThan(80.0));
      expect(p1.categoria, CategoriaPrioridadeNota.critica);
      expect(p1.motivosTexto.any((m) => m.contains('Prazo SAP ultrapassado')), isTrue);
      expect(p1.motivosTexto.any((m) => m.contains('Prioridade máxima')), isTrue);

      expect(p2.notaSapId, 'nota_normal');
      expect(p2.scoreTotal, lessThan(40.0));
      expect(p2.categoria, CategoriaPrioridadeNota.baixa);
    });

    test('6.2. Oportunidade Logística NÃO sobrepõe risco e prazo crítico', () {
      final hoje = DateTime(2026, 11, 2);
      final notas = [
        BacklogNotaItem(
          id: 'nota_seguranca',
          nota: '1',
          descricao: 'Risco de choque e segurança',
          dataFimDesejada: hoje.subtract(const Duration(days: 5)),
          prioridade: '1 - Muito Alta',
        ),
        BacklogNotaItem(
          id: 'nota_agrupada_baixa',
          nota: '2',
          descricao: 'Limpeza geral preventiva',
          grupoId: 'grp_central', // Tem agrupamento
          prioridade: '4 - Baixa',
          dataFimDesejada: hoje.add(const Duration(days: 120)),
        ),
      ];

      final priorizacoes = service.calcularPriorizacaoNotas(
        notas: notas,
        dataReferencia: hoje,
      );

      // A nota com risco e prazo vencido DEVE ter score superior à nota com agrupamento
      expect(priorizacoes.first.notaSapId, 'nota_seguranca');
      expect(priorizacoes.first.scoreTotal, greaterThan(priorizacoes.last.scoreTotal));
    });

    test('6.3. Simulação Não-Destrutiva: Ajuste de executores e eficiência em memória', () {
      final cal = service.calcularCalendarioMes(ano: 2026, mes: 11);
      const capOriginal = CapacidadeExecutorMes(
        executorId: 'exec_1',
        executorNome: 'Técnico Original',
        ano: 2026,
        mes: 11,
        diasUteis: 20,
        jornadaDiaria: 8.0,
        horasBrutas: 160.0,
        horasIndisponiveis: 0.0,
        fatorEficiencia: 0.85,
        horasAjustadas: 136.0,
        horasComprometidas: 100.0,
        saldoHoras: 36.0,
      );

      final balancoBase = service.calcularBalanceamentoMensal(
        ano: 2026,
        mes: 11,
        capacidadesExecutores: const [capOriginal],
        demanda: const DemandaCarteiraMes(
          ano: 2026,
          mes: 11,
          totalNotasPrevistas: 1,
          notasComEstimativa: 1,
          horasEstimadasConfirmadas: 50.0,
          notasSemEstimativa: 0,
          percentualCoberturaEstimativa: 100.0,
        ),
        calendario: cal,
      );

      // No balanço base: Capacidade Ajustada = 136h, Prog = 100h, Demanda = 50h -> Saldo = -14h (Sobrecarga)
      expect(balancoBase.saldoHorasCalculado, -14.0);
      expect(balancoBase.status, StatusBalanceamentoMensal.sobrecarga);

      // Simulação: Adicionar +1 executor na equipe em memória
      final cenario = CenarioSimulacao(
        id: 'sim_1',
        nome: 'Adição de 1 técnico temporário',
        criadoEm: DateTime.now(),
        ajusteExecutoresDisponiveis: 1,
      );

      final balancoSimulado = service.simularCenario(
        balancoBase: balancoBase,
        cenario: cenario,
        capacidadesExecutoresOriginais: const [capOriginal],
      );

      // No balanço simulado: 2 técnicos -> soma da capacidade ajustada original + executor simulado
      expect(balancoSimulado.totalExecutores, 2);
      expect(balancoSimulado.horasAjustadas, greaterThan(270.0));
      expect(balancoSimulado.saldoHorasCalculado, greaterThan(120.0));
      expect(balancoSimulado.status, StatusBalanceamentoMensal.ocioso, reason: 'Comprometimento < 50% após dobrar equipe');

      // O balanço base permanece intacto
      expect(balancoBase.totalExecutores, 1);
      expect(balancoBase.saldoHorasCalculado, -14.0);
    });
  });
}
