import 'package:flutter/material.dart';
import '../models/at.dart';
import '../utils/responsive.dart';

class AtsDashboardView extends StatelessWidget {
  final List<AT> ats;
  final Set<String> atsProgramadasIds;

  const AtsDashboardView({
    super.key,
    required this.ats,
    required this.atsProgramadasIds,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    // Variáveis estatísticas
    final totalATs = ats.length;
    final atsProgramadas = ats
        .where((at) => atsProgramadasIds.contains(at.id))
        .length;
    final atsNaoProgramadas = totalATs > 0 ? totalATs - atsProgramadas : 0;

    final atsPorStatus = <String, int>{};
    final concluidas = ats
        .where((at) => (at.statusUsuario ?? '').toUpperCase().contains('CONC'))
        .length;
    for (final at in ats) {
      final status = at.statusSistema ?? 'Sem Status';
      atsPorStatus[status] = (atsPorStatus[status] ?? 0) + 1;
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row of top cards
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.start,
            children: [
              _buildDashboardCardGrande(
                'ATs Programadas',
                atsProgramadas,
                totalATs > 0 ? (atsProgramadas / totalATs) * 100 : 0,
                Colors.blue,
              ),
              _buildDashboardCardGrande(
                'AT\'s Concluídas',
                concluidas,
                totalATs > 0 ? (concluidas / totalATs) * 100 : 0,
                Colors.green,
              ),
              _buildDashboardCardGrande(
                'Não Programadas',
                atsNaoProgramadas,
                totalATs > 0 ? (atsNaoProgramadas / totalATs) * 100 : 0,
                Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Gráfico principal de barras
          _buildATsPorFimBaseChart(isMobile),
        ],
      ),
    );
  }

  Widget _buildDashboardCardGrande(
    String title,
    int valor,
    double percentual,
    Color color,
  ) {
    final percStr =
        '${percentual.isFinite ? percentual.toStringAsFixed(0) : '0'}%';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.6), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SizedBox(
        width: 160,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  valor.toString(),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  percStr,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildATsPorFimBaseChart(bool isMobile) {
    // Contagem por mês/ano:
    // - Barras: CRSI + CONC (ignora CANC)
    // - Linha: CONC
    final contagemBarra = <DateTime, int>{};
    final contagemCONC = <DateTime, int>{};
    for (final at in ats) {
      final fim = at.dataFim;
      if (fim == null) continue;
      final chave = DateTime(fim.year, fim.month);
      final status = (at.statusUsuario ?? '').toUpperCase();
      if (status.contains('CANC')) continue; // ignorar canceladas
      if (status.contains('CRSI')) {
        contagemBarra[chave] = (contagemBarra[chave] ?? 0) + 1;
      } else if (status.contains('CONC')) {
        contagemBarra[chave] = (contagemBarra[chave] ?? 0) + 1;
        contagemCONC[chave] = (contagemCONC[chave] ?? 0) + 1;
      } else {
        // Outros status
      }
    }

    final chaves = <DateTime>{
      ...contagemBarra.keys,
      ...contagemCONC.keys,
    }.toList()..sort((a, b) => a.compareTo(b));

    int maxBarra = 0;
    int maxCONC = 0;
    for (final chave in chaves) {
      final c1 = contagemBarra[chave] ?? 0;
      final c2 = contagemCONC[chave] ?? 0;
      if (c1 > maxBarra) maxBarra = c1;
      if (c2 > maxCONC) maxCONC = c2;
    }
    final maxQtd = [maxBarra, maxCONC].reduce((a, b) => a > b ? a : b);

    String mesAnoLabel(DateTime dt) =>
        '${dt.month.toString().padLeft(2, '0')}/${dt.year}';

    if (maxQtd == 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: const [
            Icon(Icons.info_outline, color: Colors.grey),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Sem dados (CRSI/CONC) para o período selecionado.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart, color: Colors.blue),
              const SizedBox(width: 8),
              const Text(
                'ATs por Fim Base (mês/ano)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '${ats.length} ATs',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: isMobile ? 220 : 300,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final barMaxHeight = constraints.maxHeight - 40;
                final n = chaves.isEmpty ? 1 : chaves.length;
                final step = (constraints.maxWidth / n).clamp(60.0, 100.0);
                final double barWidth = (step * 0.4)
                    .clamp(16.0, 32.0)
                    .toDouble();
                final totalWidth = step * n;

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: totalWidth < constraints.maxWidth
                        ? constraints.maxWidth
                        : totalWidth,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(chaves.length, (index) {
                        final chave = chaves[index];
                        final valor = contagemBarra[chave] ?? 0;
                        final valorConc = contagemCONC[chave] ?? 0;
                        final fator = maxQtd > 0 ? (valor / maxQtd) : 0.0;
                        final barHeight = barMaxHeight * fator;
                        final double barHeightClamped = barHeight
                            .clamp(0.0, barMaxHeight)
                            .toDouble();
                        final fatorConc = maxQtd > 0
                            ? (valorConc / maxQtd)
                            : 0.0;
                        final double barHeightConc = (barMaxHeight * fatorConc)
                            .clamp(0.0, barMaxHeight)
                            .toDouble();
                        final mesRef = DateTime(chave.year, chave.month);
                        final mesAtual = DateTime(
                          DateTime.now().year,
                          DateTime.now().month,
                        );
                        final bool atrasado =
                            (valor != valorConc) && mesRef.isBefore(mesAtual);
                        final Color corBarra = atrasado
                            ? Colors.red
                            : Colors.blue;
                        final Color corTextoBarra = atrasado
                            ? Colors.red[800]!
                            : Colors.blue[800]!;

                        return SizedBox(
                          width: step,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              SizedBox(
                                height: barMaxHeight,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      height: barHeightClamped,
                                      width: barWidth,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: corBarra,
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(6),
                                            ),
                                      ),
                                      alignment: Alignment.topCenter,
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          valor.toString(),
                                          style: TextStyle(
                                            fontSize: isMobile ? 10 : 11,
                                            fontWeight: FontWeight.w600,
                                            color: corTextoBarra,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      height: barHeightConc,
                                      width: barWidth,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(6),
                                            ),
                                      ),
                                      alignment: Alignment.topCenter,
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          valorConc.toString(),
                                          style: TextStyle(
                                            fontSize: isMobile ? 9 : 10,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.green[800],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                mesAnoLabel(chave),
                                style: TextStyle(
                                  fontSize: isMobile ? 11 : 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
