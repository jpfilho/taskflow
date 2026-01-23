class HorasEmpregadoMes {
  final String numeroPessoa;
  final String nomeEmpregado;
  final String matricula;
  final int ano;
  final int mes;
  final double horasApontadas;
  final double horasFaltantes;
  final bool semApontamento;
  final double horasExtras; // Horas que começam com HHE
  final Set<String> tiposAtividade; // Tipos de atividade diferentes
  final double metaMensal; // Meta calculada (dias úteis * 8 horas)
  final double horasProgramadas; // Horas programadas nas atividades (excluindo FÉRIAS e COMPENSAÇÃO)

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
  }) : tiposAtividade = tiposAtividade ?? {};
}
