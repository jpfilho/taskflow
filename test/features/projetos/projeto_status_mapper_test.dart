import 'package:flutter_test/flutter_test.dart';
import 'package:task2026/design_system/components/status/tf_status_badge.dart';
import 'package:task2026/design_system/foundations/tf_icons.dart';
import 'package:task2026/features/projetos/presentation/widgets/projeto_status_mapper.dart';

void main() {
  group('ProjetoStatusMapper Tests', () {
    test('mapProjetoStatus mapeia status do projeto corretamente', () {
      expect(ProjetoStatusMapper.mapProjetoStatus('ATIVO'), TFStatusSeverity.success);
      expect(ProjetoStatusMapper.mapProjetoStatus('EM_ANDAMENTO'), TFStatusSeverity.success);
      expect(ProjetoStatusMapper.mapProjetoStatus('ANDAMENTO'), TFStatusSeverity.success);
      expect(ProjetoStatusMapper.mapProjetoStatus('EM PLANEJAMENTO'), TFStatusSeverity.warning);
      expect(ProjetoStatusMapper.mapProjetoStatus('PLANEJAMENTO'), TFStatusSeverity.warning);
      expect(ProjetoStatusMapper.mapProjetoStatus('PENDENTE'), TFStatusSeverity.warning);
      expect(ProjetoStatusMapper.mapProjetoStatus('CONCLUIDO'), TFStatusSeverity.info);
      expect(ProjetoStatusMapper.mapProjetoStatus('CONCLUÍDO'), TFStatusSeverity.info);
      expect(ProjetoStatusMapper.mapProjetoStatus('CONCLUIDA'), TFStatusSeverity.info);
      expect(ProjetoStatusMapper.mapProjetoStatus('PAUSADO'), TFStatusSeverity.neutral);
      expect(ProjetoStatusMapper.mapProjetoStatus('SUSPENSO'), TFStatusSeverity.neutral);
      expect(ProjetoStatusMapper.mapProjetoStatus('CANCELADO'), TFStatusSeverity.danger);
      expect(ProjetoStatusMapper.mapProjetoStatus('CANCELADA'), TFStatusSeverity.danger);
      expect(ProjetoStatusMapper.mapProjetoStatus('DESCONHECIDO'), TFStatusSeverity.neutral);
    });

    test('mapPrioridade mapeia prioridades corretamente', () {
      expect(ProjetoStatusMapper.mapPrioridade('URGENTE'), TFStatusSeverity.danger);
      expect(ProjetoStatusMapper.mapPrioridade('ALTA'), TFStatusSeverity.danger);
      expect(ProjetoStatusMapper.mapPrioridade('MEDIA'), TFStatusSeverity.warning);
      expect(ProjetoStatusMapper.mapPrioridade('MÉDIA'), TFStatusSeverity.warning);
      expect(ProjetoStatusMapper.mapPrioridade('BAIXA'), TFStatusSeverity.neutral);
      expect(ProjetoStatusMapper.mapPrioridade(null), TFStatusSeverity.neutral);
    });

    test('getStatusIcon retorna ícones corretos', () {
      expect(ProjetoStatusMapper.getStatusIcon('ATIVO'), TFIcons.task);
      expect(ProjetoStatusMapper.getStatusIcon('EM PLANEJAMENTO'), TFIcons.calendar);
      expect(ProjetoStatusMapper.getStatusIcon('CONCLUIDO'), TFIcons.success);
      expect(ProjetoStatusMapper.getStatusIcon('CANCELADO'), TFIcons.cancel);
      expect(ProjetoStatusMapper.getStatusIcon('OUTRO'), TFIcons.info);
    });
  });
}
