import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../design_system/taskflow_design_system.dart';
import '../models/si.dart';
import '../utils/responsive.dart';

class SiDashboardView extends StatelessWidget {
  final List<SI> sis;
  final Set<String> sisProgramadasIds;

  const SiDashboardView({
    super.key,
    required this.sis,
    this.sisProgramadasIds = const {},
  });

  bool _isSiConcluida(SI si) {
    final statusUsr = (si.statusUsuario ?? '').toUpperCase();
    final statusSis = (si.statusSistema ?? '').toUpperCase();
    return statusUsr.contains('CONC') ||
        statusSis.contains('ENCE') ||
        statusSis.contains('ENTE');
  }

  bool _isSiCancelada(SI si) {
    final statusUsr = (si.statusUsuario ?? '').toUpperCase();
    final statusSis = (si.statusSistema ?? '').toUpperCase();
    return statusUsr.contains('CANC') || statusSis.contains('CANC');
  }

  Map<String, dynamic> _calculateStats(List<SI> listaSis) {
    int total = listaSis.length;
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
    final porTipo = <String, int>{};
    final porLocal = <String, int>{};
    final porCriadoPor = <String, int>{};

    final sisVencidas = <SI>[];
    final sisEmRisco = <SI>[];

    final now = DateTime.now();
    final hojeSemHora = DateTime(now.year, now.month, now.day);

    for (var si in listaSis) {
      final statusUsr = si.statusUsuario?.toUpperCase() ?? 'SEM STATUS';
      porStatusUsr[statusUsr] = (porStatusUsr[statusUsr] ?? 0) + 1;

      final statusSis = si.statusSistema?.toUpperCase() ?? 'SEM STATUS';
      porStatusSis[statusSis] = (porStatusSis[statusSis] ?? 0) + 1;

      final tipo = si.tipo?.toUpperCase() ?? 'OUTROS';
      porTipo[tipo] = (porTipo[tipo] ?? 0) + 1;

      final isCanc = _isSiCancelada(si);
      final isConc = _isSiConcluida(si);

      if (isCanc) {
        canceladas++;
      } else if (isConc) {
        concluidas++;
      } else {
        abertas++;
      }

      final isProg = sisProgramadasIds.contains(si.id);
      if (isProg) {
        programadas++;
      } else {
        naoProgramadas++;
      }

      final local = si.local ?? si.localInstalacao ?? 'Sem Local';
      porLocal[local] = (porLocal[local] ?? 0) + 1;

      final criado = si.criadoPor ?? 'Não Identificado';
      porCriadoPor[criado] = (porCriadoPor[criado] ?? 0) + 1;

      final fim = si.dataFim;
      if (fim == null) {
        semPrazo++;
      } else {
        final fimSemHora = DateTime(fim.year, fim.month, fim.day);
        final diffDias = fimSemHora.difference(hojeSemHora).inDays;

        if (!isConc && !isCanc) {
          if (diffDias < 0) {
            vencidas++;
            sisVencidas.add(si);
          } else if (diffDias <= 7) {
            emRisco++;
            sisEmRisco.add(si);
          } else {
            noPrazo++;
          }
        }
      }
    }

    // Ordenar vencidas pelas mais antigas em atraso primeiro
    sisVencidas.sort((a, b) {
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
      'porTipo': porTipo,
      'porLocal': porLocal,
      'porCriadoPor': porCriadoPor,
      'sisVencidas': sisVencidas,
      'sisEmRisco': sisEmRisco,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final stats = _calculateStats(sis);

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
                  child: _buildSisPorFimBaseMesChart(context, sis, isMobile),
                ),
                const SizedBox(width: TFSpacing.s12),
                Expanded(
                  child: _buildSisAbertasPorLocalChart(context, sis, isMobile),
                ),
              ],
            )
          else ...[
            _buildSisPorFimBaseMesChart(context, sis, isMobile),
            const SizedBox(height: TFSpacing.s16),
            _buildSisAbertasPorLocalChart(context, sis, isMobile),
          ],
          const SizedBox(height: TFSpacing.s16),
          if (!isMobile)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildSisPorTipoChart(context, stats, isMobile),
                ),
                const SizedBox(width: TFSpacing.s12),
                Expanded(
                  child: _buildSisCriticasList(context, stats, isMobile),
                ),
              ],
            )
          else ...[
            _buildSisPorTipoChart(context, stats, isMobile),
            const SizedBox(height: TFSpacing.s16),
            _buildSisCriticasList(context, stats, isMobile),
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
              'Total de SIs',
              total,
              null,
              colors.primary,
              Icons.description,
              clampedWidth,
            ),
            _buildKpiCard(
              context,
              'Abertas',
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

  Widget _buildSisPorFimBaseMesChart(BuildContext context, List<SI> listaSis, bool isMobile) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final anoAtual = DateTime.now().year;

    final mesLabels = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
    final totaisPorMes = List<int>.filled(12, 0);
    final concPorMes = List<int>.filled(12, 0);

    for (var si in listaSis) {
      final fim = si.dataFim;
      if (fim == null || fim.year != anoAtual) continue;
      if (_isSiCancelada(si)) continue;

      final mIdx = fim.month - 1;
      if (mIdx >= 0 && mIdx < 12) {
        totaisPorMes[mIdx]++;
        if (_isSiConcluida(si)) {
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
                  'SIs por Data Fim em $anoAtual',
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
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => colors.surface,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final tipo = rodIndex == 0 ? 'Total' : 'Concluídas';
                      return BarTooltipItem(
                        '${mesLabels[group.x.toInt()]}\n$tipo: ${rod.toY.toInt()}',
                        TextStyle(
                          color: rodIndex == 0 ? colors.primary : colors.success,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSisAbertasPorLocalChart(BuildContext context, List<SI> listaSis, bool isMobile) {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    final abertasPorLocal = <String, int>{};
    for (var si in listaSis) {
      if (!_isSiConcluida(si) && !_isSiCancelada(si)) {
        final loc = si.local ?? si.localInstalacao ?? 'Sem Local';
        abertasPorLocal[loc] = (abertasPorLocal[loc] ?? 0) + 1;
      }
    }

    final sorted = abertasPorLocal.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top7 = sorted.take(7).toList();
    final maxQtd = top7.isNotEmpty ? top7.first.value : 1;

    return TFCard(
      padding: const EdgeInsets.all(TFSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.place, color: colors.warning, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Top 7 Locais com Mais SIs Abertas',
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
                child: Text('Nenhuma SI aberta registrada.'),
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
                            '${item.value} SIs',
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

  Widget _buildSisPorTipoChart(BuildContext context, Map<String, dynamic> stats, bool isMobile) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final porTipo = stats['porTipo'] as Map<String, int>;

    final sorted = porTipo.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topTipos = sorted.take(5).toList();

    final palette = [
      colors.primary,
      colors.success,
      colors.warning,
      colors.info,
      const Color(0xFF8B5CF6),
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
              Icon(Icons.category, color: colors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Distribuição por Tipo de SI',
                style: typography.cardTitle,
              ),
            ],
          ),
          const SizedBox(height: TFSpacing.s16),
          if (topTipos.isEmpty || totalVal == 0)
            const Center(child: Text('Sem dados de tipos.'))
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
                      sections: List.generate(topTipos.length, (i) {
                        final st = topTipos[i];
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
                    children: List.generate(topTipos.length, (i) {
                      final item = topTipos[i];
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

  Widget _buildSisCriticasList(BuildContext context, Map<String, dynamic> stats, bool isMobile) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final vencidas = stats['sisVencidas'] as List<SI>;
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
                  'SIs Críticas em Atraso (${vencidas.length})',
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
                  'Parabéns! Nenhuma SI em atraso no momento.',
                  style: TextStyle(color: Colors.green),
                ),
              ),
            )
          else
            Column(
              children: vencidas.take(6).map((si) {
                final fim = si.dataFim!;
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
                        'SI ${si.solicitacao} - ${si.textoBreve ?? 'Sem Descrição'}',
                        style: typography.caption.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        'Local: ${si.local ?? si.localInstalacao ?? 'N/A'} • Fim: ${fim.day.toString().padLeft(2, '0')}/${fim.month.toString().padLeft(2, '0')}/${fim.year}',
                        style: typography.micro.copyWith(color: colors.textSecondary),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.danger.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          si.statusUsuario ?? si.statusSistema ?? 'CRI.',
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
    final porCriado = stats['porCriadoPor'] as Map<String, int>;

    final topLocais = (porLocal.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(5).toList();
    final topCriados = (porCriado.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(5).toList();

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
                        '${e.value} SIs',
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
                Text('Top 5 Solicitantes (Criado Por)', style: typography.cardTitle),
                const SizedBox(height: TFSpacing.s8),
                ...topCriados.map((e) => Padding(
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
                        '${e.value} SIs',
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
