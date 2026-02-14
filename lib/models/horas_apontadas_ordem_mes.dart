/// Horas apontadas (horas_sap) por empregado, ordem e mês.
class HorasApontadasOrdemMes {
  final String matricula;
  final String ordem;
  final int ano;
  final int mes;
  final String anoMes;
  final double horasApontadas;

  HorasApontadasOrdemMes({
    required this.matricula,
    required this.ordem,
    required this.ano,
    required this.mes,
    required this.anoMes,
    required this.horasApontadas,
  });

  factory HorasApontadasOrdemMes.fromMap(Map<String, dynamic> map) {
    return HorasApontadasOrdemMes(
      matricula: (map['matricula'] as String? ?? '').trim(),
      ordem: (map['ordem'] as String? ?? '').trim(),
      ano: (map['ano'] as num?)?.toInt() ?? 0,
      mes: (map['mes'] as num?)?.toInt() ?? 0,
      anoMes: (map['ano_mes'] as String? ?? '').trim(),
      horasApontadas: (map['horas_apontadas'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
