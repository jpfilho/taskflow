class HorasEmpregadoMes {
  final String numeroPessoa;
  final String nomeEmpregado;
  final String matricula;
  final int ano;
  final int mes;
  final double horasApontadas;
  final double horasFaltantes;
  final bool semApontamento;
  final double horasExtras; // Horas em que tipo_atividade_real começa com HH (hora extra)
  final Set<String> tiposAtividade; // Tipos de atividade diferentes
  final double metaMensal; // Meta calculada (dias úteis * 8 horas)
  final double horasProgramadas; // Horas programadas nas atividades (excluindo FÉRIAS e COMPENSAÇÃO)
  /// Horas apontadas em ordens tipo PROJ (investimento).
  final double horasInvestimento;
  /// Horas apontadas em ordens de outros tipos (custeio).
  final double horasCusteio;

  HorasEmpregadoMes({
    required this.numeroPessoa,
    required this.nomeEmpregado,
    required this.matricula,
    required this.ano,
    required this.mes,
    required this.horasApontadas,
    required this.horasFaltantes,
    required this.semApontamento,
    this.horasExtras = 0.0,
    Set<String>? tiposAtividade,
    required this.metaMensal,
    this.horasProgramadas = 0.0,
    this.horasInvestimento = 0.0,
    this.horasCusteio = 0.0,
  }) : tiposAtividade = tiposAtividade ?? {};
}
