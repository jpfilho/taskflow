import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/design_system/components/status/tf_status_badge.dart';
import 'package:task2026/features/demandas/presentation/widgets/demanda_prazo_helper.dart';
import 'package:task2026/features/demandas/presentation/widgets/demanda_status_mapper.dart';

void main() {
  group('DemandaPrazoHelper Tests', () {
    test('obterSituacao retorna concluidaOuCancelada quando status e Concluída ou Cancelada', () {
      final prazo = DateTime.now().subtract(const Duration(days: 10));
      expect(
        DemandaPrazoHelper.obterSituacao(prazo, 'Concluída'),
        SituacaoPrazo.concluidaOuCancelada,
      );
      expect(
        DemandaPrazoHelper.obterSituacao(prazo, 'Cancelada'),
        SituacaoPrazo.concluidaOuCancelada,
      );
    });

    test('obterSituacao retorna atrasada quando prazo anterior a hoje', () {
      final prazo = DateTime.now().subtract(const Duration(days: 2));
      expect(
        DemandaPrazoHelper.obterSituacao(prazo, 'Aberta'),
        SituacaoPrazo.atrasada,
      );
    });

    test('obterSituacao retorna venceHoje quando prazo e o dia de hoje', () {
      final hoje = DateTime.now();
      expect(
        DemandaPrazoHelper.obterSituacao(hoje, 'Aberta'),
        SituacaoPrazo.venceHoje,
      );
    });

    test('obterSituacao retorna venceEmAte7Dias quando prazo e nos proximos 7 dias', () {
      final prazo = DateTime.now().add(const Duration(days: 4));
      expect(
        DemandaPrazoHelper.obterSituacao(prazo, 'Aberta'),
        SituacaoPrazo.venceEmAte7Dias,
      );
    });

    test('obterSituacao retorna noPrazo quando prazo e superior a 7 dias', () {
      final prazo = DateTime.now().add(const Duration(days: 15));
      expect(
        DemandaPrazoHelper.obterSituacao(prazo, 'Aberta'),
        SituacaoPrazo.noPrazo,
      );
    });

    test('obterSeverity mapeia corretamente para TFStatusSeverity', () {
      expect(
        DemandaPrazoHelper.obterSeverity(SituacaoPrazo.atrasada),
        TFStatusSeverity.danger,
      );
      expect(
        DemandaPrazoHelper.obterSeverity(SituacaoPrazo.venceHoje),
        TFStatusSeverity.warning,
      );
      expect(
        DemandaPrazoHelper.obterSeverity(SituacaoPrazo.venceEmAte7Dias),
        TFStatusSeverity.warning,
      );
      expect(
        DemandaPrazoHelper.obterSeverity(SituacaoPrazo.noPrazo),
        TFStatusSeverity.success,
      );
      expect(
        DemandaPrazoHelper.obterSeverity(SituacaoPrazo.concluidaOuCancelada),
        TFStatusSeverity.neutral,
      );
    });
  });

  group('DemandaStatusMapper Tests', () {
    test('mapSeverity mapeia todos os status operacionais corretamente', () {
      expect(DemandaStatusMapper.mapSeverity('Aberta'), TFStatusSeverity.info);
      expect(DemandaStatusMapper.mapSeverity('Programada'), TFStatusSeverity.info);
      expect(DemandaStatusMapper.mapSeverity('Em análise'), TFStatusSeverity.neutral);
      expect(DemandaStatusMapper.mapSeverity('Em execução'), TFStatusSeverity.warning);
      expect(DemandaStatusMapper.mapSeverity('Aguardando terceiros'), TFStatusSeverity.warning);
      expect(DemandaStatusMapper.mapSeverity('Aguardando material'), TFStatusSeverity.warning);
      expect(DemandaStatusMapper.mapSeverity('Concluída'), TFStatusSeverity.success);
      expect(DemandaStatusMapper.mapSeverity('Cancelada'), TFStatusSeverity.danger);
      expect(DemandaStatusMapper.mapSeverity('Suspensa'), TFStatusSeverity.danger);
    });
  });
}
