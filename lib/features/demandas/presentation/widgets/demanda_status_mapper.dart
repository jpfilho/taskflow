import '../../../../design_system/components/status/tf_status_badge.dart';

/// Mapeador de status de domínio de Demandas para severidades visuais do TFDS.
class DemandaStatusMapper {
  static TFStatusSeverity mapSeverity(String status) {
    switch (status) {
      case 'Aberta':
      case 'Programada':
        return TFStatusSeverity.info;
      case 'Em análise':
        return TFStatusSeverity.neutral;
      case 'Em execução':
      case 'Aguardando terceiros':
      case 'Aguardando material':
        return TFStatusSeverity.warning;
      case 'Concluída':
        return TFStatusSeverity.success;
      case 'Cancelada':
      case 'Suspensa':
        return TFStatusSeverity.danger;
      default:
        return TFStatusSeverity.neutral;
    }
  }
}
