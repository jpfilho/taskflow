enum ExecutionStatus {
  executado,
  parcial,
  naoExecutado,
  naoAplicavel,
  pendente;

  String get displayName {
    switch (this) {
      case ExecutionStatus.executado:
        return 'Executado';
      case ExecutionStatus.parcial:
        return 'Parcialmente Executado';
      case ExecutionStatus.naoExecutado:
        return 'Não Executado';
      case ExecutionStatus.naoAplicavel:
        return 'Não Aplicável';
      case ExecutionStatus.pendente:
        return 'Pendente';
    }
  }

  static ExecutionStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'executado':
        return ExecutionStatus.executado;
      case 'parcial':
      case 'parcialmente_executado':
        return ExecutionStatus.parcial;
      case 'nao_executado':
      case 'naoexecutado':
        return ExecutionStatus.naoExecutado;
      case 'nao_aplicavel':
      case 'naoaplicavel':
        return ExecutionStatus.naoAplicavel;
      case 'pendente':
      default:
        return ExecutionStatus.pendente;
    }
  }

  String toMapValue() {
    switch (this) {
      case ExecutionStatus.executado:
        return 'executado';
      case ExecutionStatus.parcial:
        return 'parcial';
      case ExecutionStatus.naoExecutado:
        return 'nao_executado';
      case ExecutionStatus.naoAplicavel:
        return 'nao_aplicavel';
      case ExecutionStatus.pendente:
        return 'pendente';
    }
  }
}
