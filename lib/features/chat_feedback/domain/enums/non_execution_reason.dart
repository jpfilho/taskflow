enum NonExecutionReason {
  materialUnavailable,
  teamUnavailable,
  operationalImpediment,
  shutdownRequired,
  weatherCondition,
  accessProblem,
  registrationDivergence,
  itemNotFound,
  other;

  String get displayName {
    switch (this) {
      case NonExecutionReason.materialUnavailable:
        return 'Falta de material';
      case NonExecutionReason.teamUnavailable:
        return 'Equipe indisponível';
      case NonExecutionReason.operationalImpediment:
        return 'Impedimento operacional';
      case NonExecutionReason.shutdownRequired:
        return 'Requer parada do equipamento';
      case NonExecutionReason.weatherCondition:
        return 'Condição climática desfavorável';
      case NonExecutionReason.accessProblem:
        return 'Problema de acesso';
      case NonExecutionReason.registrationDivergence:
        return 'Divergência de cadastro';
      case NonExecutionReason.itemNotFound:
        return 'Item não encontrado';
      case NonExecutionReason.other:
        return 'Outro motivo';
    }
  }

  static NonExecutionReason? fromString(String? reason) {
    if (reason == null) return null;
    switch (reason.toLowerCase()) {
      case 'material_unavailable':
        return NonExecutionReason.materialUnavailable;
      case 'team_unavailable':
        return NonExecutionReason.teamUnavailable;
      case 'operational_impediment':
        return NonExecutionReason.operationalImpediment;
      case 'shutdown_required':
        return NonExecutionReason.shutdownRequired;
      case 'weather_condition':
        return NonExecutionReason.weatherCondition;
      case 'access_problem':
        return NonExecutionReason.accessProblem;
      case 'registration_divergence':
        return NonExecutionReason.registrationDivergence;
      case 'item_not_found':
        return NonExecutionReason.itemNotFound;
      case 'other':
      default:
        return NonExecutionReason.other;
    }
  }

  String toMapValue() {
    switch (this) {
      case NonExecutionReason.materialUnavailable:
        return 'material_unavailable';
      case NonExecutionReason.teamUnavailable:
        return 'team_unavailable';
      case NonExecutionReason.operationalImpediment:
        return 'operational_impediment';
      case NonExecutionReason.shutdownRequired:
        return 'shutdown_required';
      case NonExecutionReason.weatherCondition:
        return 'weather_condition';
      case NonExecutionReason.accessProblem:
        return 'access_problem';
      case NonExecutionReason.registrationDivergence:
        return 'registration_divergence';
      case NonExecutionReason.itemNotFound:
        return 'item_not_found';
      case NonExecutionReason.other:
        return 'other';
    }
  }
}
