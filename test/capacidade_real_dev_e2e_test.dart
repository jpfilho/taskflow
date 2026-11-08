import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:task2026/config/supabase_config.dart';
import 'package:task2026/models/capacidade_operacional_models.dart';
import 'package:task2026/services/capacidade_service.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    // Inicializar conexão com o ambiente real de desenvolvimento
    await SupabaseConfig.initialize();
  });

  test('Validação de Ponta a Ponta com Dados Reais em Desenvolvimento (Fase 3)', () async {
    final swGeral = Stopwatch()..start();
    final service = CapacidadeService();

    // 1. Carregar balanço do horizonte de 3 meses para o ano corrente (2026)
    final swHorizonte = Stopwatch()..start();
    final horizonte = await service.carregarHorizonteCapacidade(
      anoInicio: 2026,
      mesInicio: 11,
      quantidadeMeses: 3,
      config: const ConfiguracaoCapacidade(
        jornadaDiariaHoras: 8.0,
        fatorEficiencia: 0.85,
        incluirExecutoresSemEquipe: false,
      ),
    );
    swHorizonte.stop();

    expect(horizonte.length, 3);
    final nov26 = horizonte[0];

    // print formatado dos indicadores reais apurados
    print('\n======================================================');
    print('  APURAÇÃO REAL DE CAPACIDADE — NOVEMBRO/2026');
    print('======================================================');
    print('Dias Úteis: ${nov26.calendario.diasUteis} (${nov26.calendario.feriadosEmDiasUteis} feriados úteis)');
    print('Executores em Equipes: ${nov26.totalExecutoresEmEquipes}');
    print('Horas Brutas: ${nov26.horasBrutas.toStringAsFixed(1)}h');
    print('Horas Indisponíveis: ${nov26.horasIndisponiveis.toStringAsFixed(1)}h');
    print('Capacidade Ajustada: ${nov26.horasAjustadas.toStringAsFixed(1)}h');
    print('Horas Programadas em Tarefas: ${nov26.horasComprometidasProgramadas.toStringAsFixed(1)}h');
    print('Horas Estimadas da Carteira (Pendentes): ${nov26.demanda.horasEstimadasNaoProgramadas.toStringAsFixed(1)}h');
    print('Notas sem Estimativa: ${nov26.demanda.notasSemEstimativa} de ${nov26.demanda.totalNotasPrevistas}');
    print('Cobertura de Estimativas: ${nov26.demanda.percentualCoberturaEstimativa.toStringAsFixed(1)}%');
    print('Saldo Calculado: ${nov26.saldoHorasCalculado.toStringAsFixed(1)}h');
    print('Confiabilidade: ${nov26.nivelConfiabilidade.name.toUpperCase()} (Saldo Confiável: ${nov26.isSaldoConfiavel})');
    print('Motivo: ${nov26.motivoConfiabilidade}');
    print('Tempo de carregamento completo do horizonte: ${swHorizonte.elapsedMilliseconds} ms');
    print('======================================================\n');

    expect(nov26.calendario.diasUteis, greaterThan(0));
    expect(nov26.horasAjustadas, greaterThan(0));

    // Validação da trava de falsa ociosidade na base real:
    if (nov26.demanda.percentualCoberturaEstimativa < 80.0) {
      expect(nov26.isSaldoConfiavel, isFalse,
          reason: 'Com baixa cobertura de estimativas, o saldo positivo não pode ser considerado confiável.');
    }

    swGeral.stop();
    print('Tempo total de execução do teste real: ${swGeral.elapsedMilliseconds} ms');
  });
}
