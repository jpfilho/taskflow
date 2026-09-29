import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../design_system/taskflow_design_system.dart';
import '../models/nota_sap.dart';
import '../utils/responsive.dart';

class NotasSAPDashboardView extends StatelessWidget {
  final List<NotaSAP> notas;

  const NotasSAPDashboardView({
    super.key,
    required this.notas,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final stats = _calculateStats(notas);

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? TFSpacing.s8 : TFSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildOverviewCards(context, stats, isMobile),
          const SizedBox(height: TFSpacing.s16),
          if (!isMobile)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildNotasVencimentoPorMesChart(context, notas, isMobile),
                  ),
                  const SizedBox(width: TFSpacing.s12),
                  Expanded(
                    child: _buildNotasAbertasPorLocalChart(context, notas, isMobile),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                _buildNotasVencimentoPorMesChart(context, notas, isMobile),
                const SizedBox(height: TFSpacing.s12),
                _buildNotasAbertasPorLocalChart(context, notas, isMobile),
              ],
            ),
          const SizedBox(height: TFSpacing.s16),
          if (!isMobile)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildStatusChart(context, stats, isMobile),
                ),
                const SizedBox(width: TFSpacing.s12),
                Expanded(
                  child: _buildPrioridadeChart(context, stats, isMobile),
                ),
              ],
            )
          else
            Column(
              children: [
                _buildStatusChart(context, stats, isMobile),
                const SizedBox(height: TFSpacing.s12),
                _buildPrioridadeChart(context, stats, isMobile),
              ],
            ),
          const SizedBox(height: TFSpacing.s24),
          _buildPrazoSection(context, stats, isMobile),
          const SizedBox(height: TFSpacing.s24),
          if (!isMobile)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildTipoChart(context, stats, isMobile),
                ),
                const SizedBox(width: TFSpacing.s12),
                Expanded(
                  child: _buildTopLocaisGPMs(context, stats, isMobile),
                ),
              ],
            )
          else
            Column(
              children: [
                _buildTipoChart(context, stats, isMobile),
                const SizedBox(height: TFSpacing.s12),
                _buildTopLocaisGPMs(context, stats, isMobile),
              ],
            ),
        ],
      ),
    );
  }

  Map<String, dynamic> _calculateStats(List<NotaSAP> notas) {
    int total = notas.length;
    int abertas = 0;
    int concluidas = 0;
    int vencidas = 0;
    int emRisco = 0;
    int semPrazo = 0;
    int noPrazo = 0;

    final porStatus = <String, int>{};
    final porPrioridade = <String, int>{};
    final porTipo = <String, int>{};
    final porLocal = <String, int>{};
    final porGPM = <String, int>{};

    final notasVencidas = <NotaSAP>[];
    final notasEmRisco = <NotaSAP>[];

    for (var nota in notas) {
      final status = nota.statusSistema?.toUpperCase() ?? 'SEM STATUS';
      porStatus[status] = (porStatus[status] ?? 0) + 1;

      if (status.contains('MSEN')) {
        concluidas++;
      } else {
        abertas++;
      }

      final prioridade = nota.textPrioridade ?? 'Sem Prioridade';
      porPrioridade[prioridade] = (porPrioridade[prioridade] ?? 0) + 1;

      final tipo = nota.tipo ?? 'Sem Tipo';
      porTipo[tipo] = (porTipo[tipo] ?? 0) + 1;

      final local = nota.local ?? 'Sem Local';
      porLocal[local] = (porLocal[local] ?? 0) + 1;

      final gpm = nota.gpm ?? 'Sem GPM';
      porGPM[gpm] = (porGPM[gpm] ?? 0) + 1;

      final diasRestantes = nota.diasRestantes;
      // Excluir notas concluídas (MSEN) do cálculo de vencidas e em risco
      final isConcluida = status.contains('MSEN');
      
      if (diasRestantes == null) {
        semPrazo++;
      } else if (diasRestantes <= 0 && !isConcluida) {
        // Só contar como vencida se não estiver concluída
        vencidas++;
        notasVencidas.add(nota);
      } else if (diasRestantes <= 30 && !isConcluida) {
        // Só contar como em risco se não estiver concluída
        emRisco++;
        notasEmRisco.add(nota);
      } else if (!isConcluida) {
        // Só contar como no prazo se não estiver concluída
        noPrazo++;
      }
    }

    return {
      'total': total,
      'abertas': abertas,
      'concluidas': concluidas,
      'vencidas': vencidas,
      'emRisco': emRisco,
      'semPrazo': semPrazo,
      'noPrazo': noPrazo,
      'porStatus': porStatus,
      'porPrioridade': porPrioridade,
      'porTipo': porTipo,
      'porLocal': porLocal,
      'porGPM': porGPM,
      'notasVencidas': notasVencidas,
      'notasEmRisco': notasEmRisco,
    };
  }

  Widget _buildOverviewCards(BuildContext context, Map<String, dynamic> stats, bool isMobile) {
    final colors = context.tfColors;

    final cards = [
      _buildModernStatCard(
        context,
        'Total',
        (stats['total'] as int).toString(),
        Icons.description,
        colors.primary,
        isMobile,
      ),
      _buildModernStatCard(
        context,
        'Abertas',
        (stats['abertas'] as int).toString(),
        Icons.folder_open,
        colors.warning,
        isMobile,
      ),
      _buildModernStatCard(
        context,
        'Concluídas',
        (stats['concluidas'] as int).toString(),
        Icons.check_circle,
        colors.success,
        isMobile,
      ),
      _buildModernStatCard(
        context,
        'Vencidas',
        (stats['vencidas'] as int).toString(),
        Icons.warning,
        colors.danger,
        isMobile,
      ),
      _buildModernStatCard(
        context,
        'Em Risco',
        (stats['emRisco'] as int).toString(),
        Icons.error_outline,
        colors.warning,
        isMobile,
      ),
      _buildModernStatCard(
        context,
        'No Prazo',
        (stats['noPrazo'] as int).toString(),
        Icons.schedule,
        colors.info,
        isMobile,
      ),
      _buildModernStatCard(
        context,
        'Sem Prazo',
        (stats['semPrazo'] as int).toString(),
        Icons.help_outline,
        colors.textSecondary,
        isMobile,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth < TFBreakpoints.sm
            ? 2
            : (constraints.maxWidth < TFBreakpoints.lg ? 4 : 7);
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: TFSpacing.s8,
          crossAxisSpacing: TFSpacing.s8,
          childAspectRatio: isMobile ? 1.4 : 1.6,
          children: cards,
        );
      },
    );
  }

  Widget _buildModernStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
    bool isMobile,
  ) {
    final typography = context.tfTypography;
    final colors = context.tfColors;

    return TFCard(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? TFSpacing.s4 : TFSpacing.s8,
        vertical: isMobile ? TFSpacing.s4 : TFSpacing.s8,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(TFSpacing.s4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(TFRadius.r4),
            ),
            child: Icon(icon, color: color, size: isMobile ? 16 : 18),
          ),
          const SizedBox(width: TFSpacing.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: typography.cardTitle.copyWith(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                    height: 1.1,
                  ),
                ),
                Text(
                  title,
                  style: typography.caption.copyWith(
                    fontSize: isMobile ? 10 : 11,
                    color: colors.textSecondary,
                    height: 1.1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotasAbertasPorLocalChart(BuildContext context, List<NotaSAP> notas, bool isMobile) {
    final colors = context.tfColors;

    // Calcular notas abertas por local
    final abertasPorLocal = <String, int>{};
    for (var nota in notas) {
      final status = nota.statusSistema?.toUpperCase() ?? '';
      if (!status.contains('MSEN')) {
        // Nota aberta
        final local = nota.local ?? 'Sem Local';
        abertasPorLocal[local] = (abertasPorLocal[local] ?? 0) + 1;
      }
    }

    if (abertasPorLocal.isEmpty) {
      return _buildEmptyChart(context, 'Notas Abertas por Local', isMobile);
    }

    // Ordenar e pegar os top 10
    final sortedEntries = abertasPorLocal.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topEntries = sortedEntries.take(10).toList();
    final maxValue = topEntries.isNotEmpty
        ? topEntries.map((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble()
        : 1.0;

    return _buildChartCard(
      context,
      'Notas Abertas por Local',
      Icons.location_on,
      colors.primary,
      _buildHorizontalBarChartForLocals(
        context,
        topEntries,
        maxValue,
        isMobile,
      ),
      null,
      isMobile,
    );
  }

  Widget _buildNotasVencimentoPorMesChart(BuildContext context, List<NotaSAP> notas, bool isMobile) {
    final colors = context.tfColors;

    // Calcular notas que vencem por mês no ano vigente
    final anoAtual = DateTime.now().year;
    final vencimentoPorMes = <int, int>{};
    
    // Inicializar todos os meses com 0
    for (int mes = 1; mes <= 12; mes++) {
      vencimentoPorMes[mes] = 0;
    }
    
    // Contar notas que vencem em cada mês
    for (var nota in notas) {
      if (nota.dataVencimento != null) {
        final vencimento = nota.dataVencimento!;
        if (vencimento.year == anoAtual) {
          final mes = vencimento.month;
          vencimentoPorMes[mes] = (vencimentoPorMes[mes] ?? 0) + 1;
        }
      }
    }
    
    // Converter para lista ordenada
    final meses = List.generate(12, (index) => index + 1);
    final valores = meses.map((mes) => vencimentoPorMes[mes]!.toDouble()).toList();
    final maxValue = valores.isNotEmpty && valores.any((v) => v > 0)
        ? valores.reduce((a, b) => a > b ? a : b) * 1.2
        : 10.0;
    
    final nomesMeses = [
      'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'
    ];
    
    return _buildChartCard(
      context,
      'Notas que Vencem em $anoAtual',
      Icons.calendar_today,
      colors.primary,
      _buildHorizontalBarChart(
        context,
        meses,
        valores,
        nomesMeses,
        maxValue,
        _getColorForMonth,
        isMobile,
      ),
      null,
      isMobile,
    );
  }
  
  Color _getColorForMonth(int mes) {
    final colors = [
      Colors.blue[400]!,
      Colors.blue[500]!,
      Colors.blue[600]!,
      Colors.blue[700]!,
      Colors.blue[800]!,
      Colors.blue[900]!,
      Colors.indigo[400]!,
      Colors.indigo[500]!,
      Colors.indigo[600]!,
      Colors.indigo[700]!,
      Colors.indigo[800]!,
      Colors.indigo[900]!,
    ];
    return colors[(mes - 1) % colors.length];
  }

  Widget _buildHorizontalBarChartForLocals(
    BuildContext context,
    List<MapEntry<String, int>> entries,
    double maxValue,
    bool isMobile,
  ) {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    final barColors = [
      colors.primary,
      colors.info,
      colors.success,
      colors.warning,
      colors.danger,
      Colors.teal,
      Colors.cyan,
      Colors.indigo,
      Colors.deepPurple,
      Colors.blueGrey,
    ];
    
    return SizedBox(
      height: isMobile ? 380 : 460,
      child: ListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: entries.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final valor = item.value.toDouble();
          final percentage = maxValue > 0 ? (valor / maxValue) : 0.0;
          final color = barColors[index % barColors.length];
          
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: isMobile ? 60 : 70,
                  child: Text(
                    item.key.length > (isMobile ? 8 : 12) 
                        ? '${item.key.substring(0, isMobile ? 8 : 12)}...' 
                        : item.key,
                    style: typography.caption.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: isMobile ? 24 : 28,
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Container(
                          height: isMobile ? 24 : 28,
                          decoration: BoxDecoration(
                            color: colors.surfaceSecondary,
                            borderRadius: BorderRadius.circular(TFRadius.r4),
                          ),
                        ),
                        if (percentage > 0)
                          FractionallySizedBox(
                            widthFactor: percentage,
                            alignment: Alignment.centerLeft,
                            child: Container(
                              height: isMobile ? 24 : 28,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(TFRadius.r4),
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: valor > 0
                                  ? Text(
                                      valor.toInt().toString(),
                                      style: typography.caption.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: isMobile ? 30 : 35,
                  child: Text(
                    valor.toInt().toString(),
                    style: typography.caption.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHorizontalBarChart(
    BuildContext context,
    List<int> meses,
    List<double> valores,
    List<String> nomesMeses,
    double maxValue,
    Color Function(int) getColor,
    bool isMobile,
  ) {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return SizedBox(
      height: isMobile ? 380 : 460,
      child: ListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: meses.asMap().entries.map((entry) {
          final index = entry.key;
          final mes = entry.value;
          final valor = valores[index];
          final percentage = maxValue > 0 ? (valor / maxValue) : 0.0;
          
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: isMobile ? 35 : 40,
                  child: Text(
                    nomesMeses[mes - 1],
                    style: typography.caption.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: isMobile ? 24 : 28,
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Container(
                          height: isMobile ? 24 : 28,
                          decoration: BoxDecoration(
                            color: colors.surfaceSecondary,
                            borderRadius: BorderRadius.circular(TFRadius.r4),
                          ),
                        ),
                        if (percentage > 0)
                          FractionallySizedBox(
                            widthFactor: percentage,
                            alignment: Alignment.centerLeft,
                            child: Container(
                              height: isMobile ? 24 : 28,
                              decoration: BoxDecoration(
                                color: getColor(mes),
                                borderRadius: BorderRadius.circular(TFRadius.r4),
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: valor > 0
                                  ? Text(
                                      valor.toInt().toString(),
                                      style: typography.caption.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: isMobile ? 30 : 35,
                  child: Text(
                    valor.toInt().toString(),
                    style: typography.caption.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatusChart(BuildContext context, Map<String, dynamic> stats, bool isMobile) {
    final colors = context.tfColors;
    final porStatus = stats['porStatus'] as Map<String, int>;
    if (porStatus.isEmpty) {
      return _buildEmptyChart(context, 'Status', isMobile);
    }

    final sortedEntries = porStatus.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topEntries = sortedEntries.take(6).toList();

    return _buildChartCard(
      context,
      'Distribuição por Status',
      Icons.assessment,
      colors.primary,
      PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: isMobile ? 40 : 60,
          sections: topEntries.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final sectionColors = [
              colors.primary,
              colors.success,
              colors.warning,
              colors.danger,
              colors.info,
              Colors.teal,
            ];
            return PieChartSectionData(
              value: item.value.toDouble(),
              title: '${item.value}',
              color: sectionColors[index % sectionColors.length],
              radius: isMobile ? 50 : 70,
              titleStyle: TextStyle(
                fontSize: isMobile ? 12 : 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            );
          }).toList(),
        ),
      ),
      _buildLegend(context, topEntries, isMobile),
      isMobile,
    );
  }

  Widget _buildPrioridadeChart(BuildContext context, Map<String, dynamic> stats, bool isMobile) {
    final colors = context.tfColors;
    final porPrioridade = stats['porPrioridade'] as Map<String, int>;
    if (porPrioridade.isEmpty) {
      return _buildEmptyChart(context, 'Prioridade', isMobile);
    }

    final sortedEntries = porPrioridade.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topEntries = sortedEntries.take(5).toList();

    return _buildChartCard(
      context,
      'Distribuição por Prioridade',
      Icons.priority_high,
      colors.warning,
      BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: topEntries.isEmpty
              ? 1
              : topEntries.map((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble() * 1.2,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => colors.surfaceSecondary,
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= topEntries.length) {
                    return const SizedBox.shrink();
                  }
                  final item = topEntries[value.toInt()];
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      item.key.length > 8 ? '${item.key.substring(0, 8)}...' : item.key,
                      style: TextStyle(
                        fontSize: isMobile ? 10 : 12,
                        color: colors.textSecondary,
                      ),
                    ),
                  );
                },
                reservedSize: 40,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: isMobile ? 40 : 50,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      fontSize: isMobile ? 10 : 12,
                      color: colors.textSecondary,
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: colors.borderSubtle,
                strokeWidth: 1,
              );
            },
          ),
          borderData: FlBorderData(show: false),
          barGroups: topEntries.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final barColors = [
              colors.primary,
              colors.info,
              colors.success,
              colors.warning,
              colors.danger,
              Colors.teal,
            ];
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: item.value.toDouble(),
                  color: barColors[index % barColors.length],
                  width: isMobile ? 16 : 24,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
      null,
      isMobile,
    );
  }

  Widget _buildTipoChart(BuildContext context, Map<String, dynamic> stats, bool isMobile) {
    final colors = context.tfColors;
    final porTipo = stats['porTipo'] as Map<String, int>;
    if (porTipo.isEmpty) {
      return _buildEmptyChart(context, 'Tipo', isMobile);
    }

    final sortedEntries = porTipo.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topEntries = sortedEntries.take(6).toList();

    return _buildChartCard(
      context,
      'Distribuição por Tipo',
      Icons.category,
      colors.info,
      BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: topEntries.isEmpty
              ? 1
              : topEntries.map((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble() * 1.2,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => colors.surfaceSecondary,
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= topEntries.length) {
                    return const SizedBox.shrink();
                  }
                  final item = topEntries[value.toInt()];
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      item.key.length > 6 ? '${item.key.substring(0, 6)}...' : item.key,
                      style: TextStyle(
                        fontSize: isMobile ? 10 : 12,
                        color: colors.textSecondary,
                      ),
                    ),
                  );
                },
                reservedSize: 40,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: isMobile ? 40 : 50,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      fontSize: isMobile ? 10 : 12,
                      color: colors.textSecondary,
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: colors.borderSubtle,
                strokeWidth: 1,
              );
            },
          ),
          borderData: FlBorderData(show: false),
          barGroups: topEntries.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final barColors = [
              colors.primary,
              colors.info,
              colors.success,
              colors.warning,
              colors.danger,
              Colors.teal,
            ];
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: item.value.toDouble(),
                  color: barColors[index % barColors.length],
                  width: isMobile ? 16 : 24,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
      null,
      isMobile,
    );
  }

  Widget _buildPrazoSection(BuildContext context, Map<String, dynamic> stats, bool isMobile) {
    final colors = context.tfColors;
    final notasVencidas = stats['notasVencidas'] as List<NotaSAP>;
    final notasEmRisco = stats['notasEmRisco'] as List<NotaSAP>;

    if (notasVencidas.isEmpty && notasEmRisco.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (notasVencidas.isNotEmpty)
          _buildAlertSection(
            context,
            'Notas Vencidas',
            Icons.error_outline,
            colors.danger,
            notasVencidas,
            isMobile,
          ),
        if (notasVencidas.isNotEmpty && notasEmRisco.isNotEmpty)
          const SizedBox(height: TFSpacing.s12),
        if (notasEmRisco.isNotEmpty)
          _buildAlertSection(
            context,
            'Notas em Risco (0-30 dias)',
            Icons.error_outline,
            colors.warning,
            notasEmRisco,
            isMobile,
          ),
      ],
    );
  }

  Widget _buildAlertSection(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    List<NotaSAP> notas,
    bool isMobile,
  ) {
    final typography = context.tfTypography;

    return TFCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(TFSpacing.s12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(TFRadius.r8),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: TFSpacing.s8),
                Expanded(
                  child: Text(
                    title,
                    style: typography.cardTitle.copyWith(
                      fontSize: isMobile ? 16 : 18,
                    ),
                  ),
                ),
                TFStatusBadge(
                  label: '${notas.length}',
                  severity: color == context.tfColors.danger ? TFStatusSeverity.danger : TFStatusSeverity.warning,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(TFSpacing.s12),
            child: Column(
              children: notas.take(10).map((nota) {
                final diasRestantes = nota.diasRestantes ?? 0;
                return _buildNotaTile(context, nota, diasRestantes, isMobile);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotaTile(BuildContext context, NotaSAP nota, int diasRestantes, bool isMobile) {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return Container(
      margin: const EdgeInsets.only(bottom: TFSpacing.s4),
      padding: const EdgeInsets.all(TFSpacing.s8),
      decoration: BoxDecoration(
        color: colors.surfaceSecondary,
        borderRadius: BorderRadius.circular(TFRadius.r4),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 50,
            decoration: BoxDecoration(
              color: diasRestantes <= 0 ? colors.danger : colors.warning,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      nota.nota,
                      style: typography.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (nota.tipo != null && nota.tipo!.isNotEmpty)
                      TFStatusBadge(
                        label: nota.tipo!,
                        severity: TFStatusSeverity.neutral,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  nota.descricao ?? '',
                  style: typography.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (nota.localInstalacao != null && nota.localInstalacao!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Local: ${nota.localInstalacao}',
                    style: typography.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TFStatusBadge(
                label: diasRestantes < 0
                    ? '${diasRestantes.abs()}d atrasada'
                    : diasRestantes == 0
                        ? 'Vence hoje'
                        : '$diasRestantes dias',
                severity: diasRestantes <= 0 ? TFStatusSeverity.danger : TFStatusSeverity.warning,
              ),
              if (nota.dataVencimento != null) ...[
                const SizedBox(height: 4),
                Text(
                  _formatDate(nota.dataVencimento!),
                  style: typography.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopLocaisGPMs(BuildContext context, Map<String, dynamic> stats, bool isMobile) {
    final colors = context.tfColors;
    final porLocal = stats['porLocal'] as Map<String, int>;
    final porGPM = stats['porGPM'] as Map<String, int>;

    return Column(
      children: [
        _buildTopList(context, 'Top Locais', Icons.location_on, colors.primary, porLocal, isMobile),
        const SizedBox(height: TFSpacing.s12),
        _buildTopList(context, 'Top GPMs', Icons.business, colors.info, porGPM, isMobile),
      ],
    );
  }

  Widget _buildTopList(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    Map<String, int> items,
    bool isMobile,
  ) {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    if (items.isEmpty) {
      return _buildEmptyChart(context, title, isMobile);
    }

    final sortedItems = items.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return TFCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(TFSpacing.s12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(TFRadius.r8),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: TFSpacing.s4),
                Text(
                  title,
                  style: typography.cardTitle.copyWith(
                    fontSize: isMobile ? 16 : 18,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(TFSpacing.s12),
            child: Column(
              children: sortedItems.take(5).toList().asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: TFSpacing.s4),
                  padding: const EdgeInsets.all(TFSpacing.s8),
                  decoration: BoxDecoration(
                    color: colors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(TFRadius.r4),
                    border: Border.all(color: colors.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(TFRadius.r4),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.key,
                          style: typography.bodySmall.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(TFRadius.r4),
                        ),
                        child: Text(
                          '${item.value}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    Widget chart,
    Widget? legend,
    bool isMobile,
  ) {
    final typography = context.tfTypography;

    return TFCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(TFSpacing.s12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(TFRadius.r8),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: TFSpacing.s4),
                Expanded(
                  child: Text(
                    title,
                    style: typography.cardTitle.copyWith(
                      fontSize: isMobile ? 16 : 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(TFSpacing.s12),
            child: SizedBox(
              height: isMobile ? 320 : 400,
              child: chart,
            ),
          ),
          if (legend != null) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(TFSpacing.s8),
              child: legend,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyChart(BuildContext context, String title, bool isMobile) {
    return TFCard(
      child: Padding(
        padding: const EdgeInsets.all(TFSpacing.s16),
        child: TFEmptyState(
          icon: Icons.bar_chart,
          title: 'Sem dados de $title',
          description: 'Nenhum dado encontrado para exibição no momento.',
        ),
      ),
    );
  }

  Widget _buildLegend(BuildContext context, List<MapEntry<String, int>> entries, bool isMobile) {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    final legendColors = [
      colors.primary,
      colors.success,
      colors.warning,
      colors.danger,
      colors.info,
      Colors.teal,
    ];

    return Wrap(
      spacing: TFSpacing.s8,
      runSpacing: TFSpacing.s4,
      children: entries.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: legendColors[index % legendColors.length],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              item.key,
              style: typography.caption,
            ),
            const SizedBox(width: 4),
            Text(
              '(${item.value})',
              style: typography.caption.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
