import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/models/capacidade_operacional_models.dart';
import 'package:task2026/widgets/planejamento_macro/capacidade_balanceamento_panel.dart';

void main() {
  group('Homologação Funcional e Visual: Visão Gerencial e Simulação What-If', () {
    late BalanceamentoCapacidadeMes balanceamentoBase;
    late BalanceamentoCapacidadeMes balanceamentoComDemanda;

    setUp(() {
      const cal = CalendarioMesInfo(
        ano: 2026,
        mes: 11,
        diasNoMes: 30,
        diasFimDeSemana: 8,
        feriadosEmDiasUteis: 2,
        diasUteis: 20,
        feriadosNomes: ['Finados', 'Proclamação da República'],
      );

      const demandaBase = DemandaCarteiraMes(
        ano: 2026,
        mes: 11,
        totalNotasPrevistas: 15,
        notasComEstimativa: 15,
        notasSemEstimativa: 0,
        horasEstimadasConfirmadas: 600.0,
        horasEstimadasNaoProgramadas: 600.0,
        percentualCoberturaEstimativa: 100.0,
      );

      const demandaSobrecarga = DemandaCarteiraMes(
        ano: 2026,
        mes: 11,
        totalNotasPrevistas: 25,
        notasComEstimativa: 21,
        notasSemEstimativa: 4,
        horasEstimadasConfirmadas: 1200.0,
        horasEstimadasNaoProgramadas: 1200.0,
        percentualCoberturaEstimativa: 84.0,
      );

      const memoria = MemoriaCalculoBalanceamento(
        passo1Calendario: '20 dias úteis',
        passo2CapacidadeBruta: '10 técnicos × 20 dias × 8h = 1600.0h',
        passo3Indisponibilidades: '0h de férias registradas',
        passo4CapacidadeAjustada: '1600.0h × 85% = 1360.0h',
        passo5HorasComprometidas: '400.0h programadas',
        passo6DemandaEstimada: '600.0h previstas',
        passo7SaldoEConfiabilidade: 'Saldo = 360.0h (Confiabilidade Alta)',
      );

      balanceamentoBase = const BalanceamentoCapacidadeMes(
        ano: 2026,
        mes: 11,
        calendario: cal,
        totalExecutores: 10,
        totalExecutoresEmEquipes: 10,
        totalExecutoresSemEquipe: 0,
        horasBrutas: 1600.0,
        horasIndisponiveis: 0.0,
        horasAjustadas: 1360.0,
        horasComprometidasProgramadas: 400.0,
        capacidadeDisponivel: 960.0,
        demanda: demandaBase,
        saldoHorasCalculado: 360.0,
        taxaComprometimentoTotal: 73.5,
        status: StatusBalanceamentoMensal.equilibrado,
        nivelConfiabilidade: NivelConfiabilidadeCapacidade.alta,
        isSaldoConfiavel: true,
        motivoConfiabilidade: 'Estimativas técnicas com 100% de cobertura',
        memoriaCalculo: memoria,
      );

      balanceamentoComDemanda = const BalanceamentoCapacidadeMes(
        ano: 2026,
        mes: 11,
        calendario: cal,
        totalExecutores: 10,
        totalExecutoresEmEquipes: 10,
        totalExecutoresSemEquipe: 0,
        horasBrutas: 1600.0,
        horasIndisponiveis: 0.0,
        horasAjustadas: 1360.0,
        horasComprometidasProgramadas: 500.0,
        capacidadeDisponivel: 860.0,
        demanda: demandaSobrecarga,
        saldoHorasCalculado: -340.0,
        taxaComprometimentoTotal: 125.0,
        status: StatusBalanceamentoMensal.sobrecarga,
        nivelConfiabilidade: NivelConfiabilidadeCapacidade.baixa,
        isSaldoConfiavel: false,
        motivoConfiabilidade: '4 notas sem estimativa técnica podem agravar o déficit',
        memoriaCalculo: memoria,
      );
    });

    testWidgets('1. Validação Visual: Painel de Capacidade, Saldo e Confiabilidade', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CapacidadeBalanceamentoPanel(
                balanceamento: balanceamentoBase,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verificar indicadores superiores e métricas
      expect(find.text('Capacidade Equilibrada'), findsOneWidget);
      expect(find.text('Confiabilidade Alta'), findsOneWidget);
      expect(find.text('1360h'), findsOneWidget); // Capacidade Ajustada
      expect(find.text('400h'), findsOneWidget);  // Horas Programadas
      expect(find.text('600h'), findsOneWidget);  // Demanda Estimada
      expect(find.text('+360h'), findsOneWidget); // Saldo Líquido

      // Clicar para abrir a Memória de Cálculo
      final botaoMemoria = find.text('Memória de Cálculo');
      expect(botaoMemoria, findsOneWidget);
      await tester.tap(botaoMemoria);
      await tester.pumpAndSettle();

      expect(find.text('Memória de Cálculo — 11/2026'), findsOneWidget);
      expect(find.text('2. Capacidade Bruta'), findsOneWidget);
      expect(find.text('10 técnicos × 20 dias × 8h = 1600.0h'), findsOneWidget);
      expect(find.text('4. Capacidade Ajustada (com Eficiência)'), findsOneWidget);
      expect(find.text('1600.0h × 85% = 1360.0h'), findsOneWidget);

      // Fechar modal
      await tester.tap(find.text('Fechar'));
      await tester.pumpAndSettle();
    });

    testWidgets('2. Validação Funcional: Simulação What-If (Variação de Técnicos e Eficiência)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CapacidadeBalanceamentoPanel(
                balanceamento: balanceamentoBase,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Clicar na aba do Simulador (What-If)
      final abaSimulador = find.text('Simulação (What-If)');
      expect(abaSimulador, findsOneWidget);
      await tester.tap(abaSimulador);
      await tester.pumpAndSettle();

      // Verificar se os controles de What-If aparecem
      expect(find.text('Simulador What-If Não-Destrutivo (Em Memória)'), findsOneWidget);
      expect(find.text('Variação de Executores: 0'), findsOneWidget);

      // Interagir com botões de incremento (+1 executor)
      final botaoMaisExecutor = find.byIcon(Icons.add_circle_outline);
      expect(botaoMaisExecutor, findsOneWidget);
      await tester.tap(botaoMaisExecutor);
      await tester.pumpAndSettle();

      // Modo simulação deve ser ativado visualmente
      expect(find.text('MODO SIMULAÇÃO ATIVO'), findsOneWidget);
      expect(find.text('Variação de Executores: +1'), findsOneWidget);

      // Clicar novamente para +2
      await tester.tap(botaoMaisExecutor);
      await tester.pumpAndSettle();
      expect(find.text('Variação de Executores: +2'), findsOneWidget);

      // Testar botão de resetar cenário
      final botaoReset = find.text('Resetar Cenário');
      expect(botaoReset, findsOneWidget);
      await tester.tap(botaoReset);
      await tester.pumpAndSettle();

      // Deve desativar o modo de simulação e voltar ao original
      expect(find.text('MODO SIMULAÇÃO ATIVO'), findsNothing);
      expect(find.text('Variação de Executores: 0'), findsOneWidget);
    });

    testWidgets('3. Validação de Travas: Sobrecarga e Confiabilidade Baixa', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CapacidadeBalanceamentoPanel(
                balanceamento: balanceamentoComDemanda,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Deve exibir sobrecarga e baixa confiabilidade
      expect(find.text('Sobrecarga de Capacidade'), findsOneWidget);
      expect(find.text('Baixa Confiabilidade'), findsOneWidget);
      expect(find.text('-340h'), findsOneWidget); // Saldo negativo
      expect(find.textContaining('4 das 25 notas previstas não possuem estimativa técnica'), findsOneWidget);
    });
  });
}
