import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../design_system/taskflow_design_system.dart';
import '../models/at.dart';
import '../utils/responsive.dart';

class AtsDashboardView extends StatelessWidget {
  final List<AT> ats;
  final Set<String> atsProgramadasIds;

  const AtsDashboardView({
    super.key,
    required this.ats,
    this.atsProgramadasIds = const {},
  });

  bool _isAtConcluida(AT at) {
    final statusUsr = (at.statusUsuario ?? '').toUpperCase();
    final statusSis = (at.statusSistema ?? '').toUpperCase();
    return statusUsr.contains('CONC') ||
        statusSis.contains('ENCE') ||
        statusSis.contains('ENTE');
  }

  bool _isAtCancelada(AT at) {
    final statusUsr = (at.statusUsuario ?? '').toUpperCase();
    return statusUsr.contains('CANC');
  }

  Map<String, dynamic> _calculateStats(List<AT> listaAts) {
    int total = listaAts.length;
    int abertas = 0;
    int concluidas = 0;
    int canceladas = 0;
    int programadas = 0;
    int naoProgramadas = 0;
    int vencidas = 0;
    int emRisco = 0;
    int noPrazo = 0;
    int semPrazo = 0;

    final porStatusUsr = <String, int>{};
    final porStatusSis = <String, int>{};
    final porLocal = <String, int>{};
    final porCntrTrab = <String, int>{};

    final atsVencidas = <AT>[];
    final atsEmRisco = <AT>[];

    final now = DateTime.now();
    final hojeSemHora = DateTime(now.year, now.month, now.day);

    for (var at in listaAts) {
      final statusUsr = at.statusUsuario?.toUpperCase() ?? 'SEM STATUS';
      porStatusUsr[statusUsr] = (porStatusUsr[statusUsr] ?? 0) + 1;

      final statusSis = at.statusSistema?.toUpperCase() ?? 'SEM STATUS';
      porStatusSis[statusSis] = (porStatusSis[statusSis] ?? 0) + 1;

      final isCanc = _isAtCancelada(at);
      final isConc = _isAtConcluida(at);

      if (isCanc) {
        canceladas++;
      } else if (isConc) {
        concluidas++;
      } else {
        abertas++;
      }

      final isProg = atsProgramadasIds.contains(at.id);
      if (isProg) {
        programadas++;
      } else {
        naoProgramadas++;
      }

      final local = at.local ?? at.edificacao ?? 'Sem Local';
      porLocal[local] = (porLocal[local] ?? 0) + 1;

      final cntr = at.cntrTrab ?? 'Sem CntrTrab';
      porCntrTrab[cntr] = (porCntrTrab[cntr] ?? 0) + 1;

      final fim = at.dataFim;
      if (fim == null) {
        semPrazo++;
      } else {
        final fimSemHora = DateTime(fim.year, fim.month, fim.day);
        final diffDias = fimSemHora.difference(hojeSemHora).inDays;

        if (!isConc && !isCanc) {
          if (diffDias < 0) {
            vencidas++;
            atsVencidas.add(at);
          } else if (diffDias <= 7) {
            emRisco++;
            atsEmRisco.add(at);
          } else {
            noPrazo++;
          }
        }
      }
    }

    // Ordenar vencidas pelas mais antigas em atraso primeiro
    atsVencidas.sort((a, b) {
      final da = a.dataFim ?? DateTime.now();
      final db = b.dataFim ?? DateTime.now();
      return da.compareTo(db);
    });

    return {
      'total': total,
      'abertas': abertas,
      'concluidas': concluidas,
      'canceladas': canceladas,
      'programadas': programadas,
      'naoProgramadas': naoProgramadas,
      'vencidas': vencidas,
      'emRisco': emRisco,
      'noPrazo': noPrazo,
      'semPrazo': semPrazo,
      'porStatusUsr': porStatusUsr,
      'porStatusSis': porStatusSis,
      'porLocal': porLocal,
      'porCntrTrab': porCntrTrab,
      'atsVencidas': atsVencidas,
      'atsEmRisco': atsEmRisco,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final stats = _calculateStats(ats);

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? TFSpacing.s8 : TFSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildOverviewCards(context, stats, isMobile),
          const SizedBox(height: TFSpacing.s16),
          if (!isMobile)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildAtsPorFimBaseMesChart(context, ats, isMobile),
                ),
                const SizedBox(width: TFSpacing.s12),
                Expanded(
                  child: _buildAtsAbertasPorLocalChart(context, ats, isMobile),
                ),
              ],
            )
          else ...[
            _buildAtsPorFimBaseMesChart(context, ats, isMobile),
            const SizedBox(height: TFSpacing.s16),
            _buildAtsAbertasPorLocalChart(context, ats, isMobile),
          ],
          const SizedBox(height: TFSpacing.s16),
          if (!isMobile)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildAtsPorStatusChart(context, stats, isMobile),
                ),
                const SizedBox(width: TFSpacing.s12),
                Expanded(
                  child: _buildAtsCriticasList(context, stats, isMobile),
                ),
              ],
            )
          else ...[
            _buildAtsPorStatusChart(context, stats, isMobile),
            const SizedBox(height: TFSpacing.s16),
            _buildAtsCriticasList(context, stats, isMobile),
          ],
          const SizedBox(height: TFSpacing.s16),
          _buildRankingsSection(context, stats, isMobile),
        ],
      ),
    );
  }

  Widget _buildOverviewCards(BuildContext context, Map<String, dynamic> stats, bool isMobile) {
    final colors = context.tfColors;
    final total = stats['total'] as int;

    double calcPerc(int val) => total > 0 ? (val / total) * 100 : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double itemWidth = isMobile
            ? (constraints.maxWidth - TFSpacing.s8) / 2
            : (constraints.maxWidth - (TFSpacing.s12 * 5)) / 6;

        final double clampedWidth = itemWidth.clamp(140.0, 260.0);

        return Wrap(
          spacing: isMobile ? TFSpacing.s8 : TFSpacing.s12,
          runSpacing: isMobile ? TFSpacing.s8 : TFSpacing.s12,
          alignment: WrapAlignment.start,
          children: [
            _buildKpiCard(
              context,
              'Total de ATs',
              total,
              null,
              colors.primary,
              Icons.assignment,
              clampedWidth,
            ),
            _buildKpiCard(
              context,
              'Abertas (CRSI)',
              stats['abertas'] as int,
              calcPerc(stats['abertas'] as int),
              colors.warning,
              Icons.pending_actions,
              clampedWidth,
            ),
            _buildKpiCard(
              context,
              'Concluídas',
              stats['concluidas'] as int,
              calcPerc(stats['concluidas'] as int),
              colors.success,
              Icons.check_circle_outline,
              clampedWidth,
            ),
            _buildKpiCard(
              context,
              'Programadas',
              stats['programadas'] as int,
              calcPerc(stats['programadas'] as int),
              colors.info,
              Icons.event_available,
              clampedWidth,
            ),
            _buildKpiCard(
              context,
              'Não Programadas',
              stats['naoProgramadas'] as int,
              calcPerc(stats['naoProgramadas'] as int),
              const Color(0xFF8B5CF6),
              Icons.event_busy,
              clampedWidth,
            ),
            _buildKpiCard(
              context,
              'Em Atraso',
              stats['vencidas'] as int,
              calcPerc(stats['vencidas'] as int),
              colors.danger,
              Icons.warning_amber_rounded,
              clampedWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard(
    BuildContext context,
    String title,
    int valor,
    double? percentual,
    Color corTema,
    IconData icon,
    double width,
  ) {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return SizedBox(
      width: width,
      child: TFCard(
        padding: const EdgeInsets.all(TFSpacing.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: typography.caption.copyWith(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(icon, size: 18, color: corTema),
              ],
            ),
            const SizedBox(height: TFSpacing.s8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  valor.toString(),
                  style: typography.sectionTitle.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: corTema,
                  ),
                ),
                if (percentual != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    '${percentual.toStringAsFixed(0)}%',
                    style: typography.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAtsPorFimBaseMesChart(BuildContext context, List<AT> listaAts, bool isMobile) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final anoAtual = DateTime.now().year;

    final mesLabels = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
    final totaisPorMes = List<int>.filled(12, 0);
    final concPorMes = List<int>.filled(12, 0);

    for (var at in listaAts) {
      final fim = at.dataFim;
      if (fim == null || fim.year != anoAtual) continue;
      if (_isAtCancelada(at)) continue;

      final mIdx = fim.month - 1;
      if (mIdx >= 0 && mIdx < 12) {
        totaisPorMes[mIdx]++;
        if (_isAtConcluida(at)) {
          concPorMes[mIdx]++;
        }
      }
    }

    int maxVal = 0;
    for (int i = 0; i < 12; i++) {
      if (totaisPorMes[i] > maxVal) maxVal = totaisPorMes[i];
    }
    if (maxVal == 0) maxVal = 10;

    final barGroups = List.generate(12, (i) {
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: totaisPorMes[i].toDouble(),
            color: colors.primary,
            width: isMobile ? 8 : 12,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
          BarChartRodData(
            toY: concPorMes[i].toDouble(),
            color: colors.success,
            width: isMobile ? 8 : 12,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    });

    return TFCard(
      padding: const EdgeInsets.all(TFSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month, color: colors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ATs por Fim Base em $anoAtual',
                  style: typography.cardTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLegendIndicator(colors.primary, 'Total'),
                  const SizedBox(width: 8),
                  _buildLegendIndicator(colors.success, 'Concluídas'),
                ],
              ),
            ],
          ),
          const SizedBox(height: TFSpacing.s16),
          SizedBox(
            height: isMobile ? 220 : 260,
            child: BarChart(
              BarChartData(
                maxY: (maxVal * 1.2).ceilToDouble(),
                barGroups: barGroups,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: colors.borderSubtle,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: typography.micro.copyWith(color: colors.textSecondary),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < 12) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              mesLabels[idx],
                              style: typography.micro.copyWith(color: colors.textSecondary),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAtsAbertasPorLocalChart(BuildContext context, List<AT> listaAts, bool isMobile) {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    final abertasPorLocal = <String, int>{};
    for (var at in listaAts) {
      if (!_isAtConcluida(at) && !_isAtCancelada(at)) {
        final local = at.local ?? at.edificacao ?? 'Sem Local';
        abertasPorLocal[local] = (abertasPorLocal[local] ?? 0) + 1;
      }
    }

    final sortedLocais = abertasPorLocal.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final top7 = sortedLocais.take(7).toList();
    int maxQtd = top7.isNotEmpty ? top7.first.value : 10;
    if (maxQtd == 0) maxQtd = 10;

    return TFCard(
      padding: const EdgeInsets.all(TFSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: colors.warning, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ATs Abertas por Localidade (Top 7)',
                  style: typography.cardTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: TFSpacing.s16),
          if (top7.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text('Nenhuma AT aberta registrada.'),
              ),
            )
          else
            Column(
              children: top7.map((item) {
                final progresso = item.value / maxQtd;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item.key,
                              style: typography.caption.copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${item.value} ATs',
                            style: typography.caption.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: progresso.clamp(0.0, 1.0),
                        backgroundColor: colors.surfaceSecondary,
                        color: colors.primary,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildAtsPorStatusChart(BuildContext context, Map<String, dynamic> stats, bool isMobile) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final porStatus = stats['porStatusUsr'] as Map<String, int>;

    final sorted = porStatus.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topStatus = sorted.take(5).toList();

    final palette = [
      colors.primary,
      colors.success,
      colors.warning,
      colors.info,
      colors.danger,
    ];

    int totalVal = stats['total'] as int;

    return TFCard(
      padding: const EdgeInsets.all(TFSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart, color: colors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Distribuição por Status do Usuário',
                style: typography.cardTitle,
              ),
            ],
          ),
          const SizedBox(height: TFSpacing.s16),
          if (topStatus.isEmpty || totalVal == 0)
            const Center(child: Text('Sem dados de status.'))
          else
            Row(
              children: [
                SizedBox(
                  height: 160,
                  width: 160,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: List.generate(topStatus.length, (i) {
                        final st = topStatus[i];
                        final cor = palette[i % palette.length];
                        return PieChartSectionData(
                          value: st.value.toDouble(),
                          color: cor,
                          title: '',
                          radius: 30,
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(topStatus.length, (i) {
                      final item = topStatus[i];
                      final cor = palette[i % palette.length];
                      final pct = totalVal > 0 ? (item.value / totalVal) * 100 : 0.0;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: cor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.key,
                                style: typography.caption.copyWith(fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${item.value} (${pct.toStringAsFixed(0)}%)',
                              style: typography.micro.copyWith(color: colors.textSecondary),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildAtsCriticasList(BuildContext context, Map<String, dynamic> stats, bool isMobile) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final vencidas = stats['atsVencidas'] as List<AT>;
    final now = DateTime.now();
    final hojeSemHora = DateTime(now.year, now.month, now.day);

    return TFCard(
      padding: const EdgeInsets.all(TFSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.report_problem, color: colors.danger, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ATs Críticas em Atraso (${vencidas.length})',
                  style: typography.cardTitle.copyWith(color: colors.danger),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: TFSpacing.s12),
          if (vencidas.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(
                child: Text(
                  'Parabéns! Nenhuma AT em atraso no momento.',
                  style: TextStyle(color: Colors.green),
                ),
              ),
            )
          else
            Column(
              children: vencidas.take(6).map((at) {
                final fim = at.dataFim!;
                final fimSemHora = DateTime(fim.year, fim.month, fim.day);
                final diasAtraso = hojeSemHora.difference(fimSemHora).inDays;

                return Column(
                  children: [
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: colors.danger.withValues(alpha: 0.1),
                        child: Text(
                          '${diasAtraso}d',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colors.danger,
                          ),
                        ),
                      ),
                      title: Text(
                        'AT ${at.autorzTrab} - ${at.textoBreve ?? 'Sem Descrição'}',
                        style: typography.caption.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        'Local: ${at.local ?? at.edificacao ?? 'N/A'} • Fim: ${fim.day.toString().padLeft(2, '0')}/${fim.month.toString().padLeft(2, '0')}/${fim.year}',
                        style: typography.micro.copyWith(color: colors.textSecondary),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.danger.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          at.statusUsuario ?? 'CRSI',
                          style: typography.micro.copyWith(
                            color: colors.danger,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                  ],
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildRankingsSection(BuildContext context, Map<String, dynamic> stats, bool isMobile) {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    final porLocal = stats['porLocal'] as Map<String, int>;
    final porCntr = stats['porCntrTrab'] as Map<String, int>;

    final topLocais = (porLocal.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(5).toList();
    final topCntrs = (porCntr.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(5).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TFCard(
            padding: const EdgeInsets.all(TFSpacing.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Top 5 Subestações / Locais', style: typography.cardTitle),
                const SizedBox(height: TFSpacing.s8),
                ...topLocais.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          e.key,
                          style: typography.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${e.value} ATs',
                        style: typography.caption.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ),
        const SizedBox(width: TFSpacing.s12),
        Expanded(
          child: TFCard(
            padding: const EdgeInsets.all(TFSpacing.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Top 5 Centros de Trabalho', style: typography.cardTitle),
                const SizedBox(height: TFSpacing.s8),
                ...topCntrs.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          e.key,
                          style: typography.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${e.value} ATs',
                        style: typography.caption.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendIndicator(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
