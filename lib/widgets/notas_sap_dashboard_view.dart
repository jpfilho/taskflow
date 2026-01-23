import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
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
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildOverviewCards(stats, isMobile),
          const SizedBox(height: 24),
          if (!isMobile)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildNotasVencimentoPorMesChart(notas, isMobile),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildNotasAbertasPorLocalChart(notas, isMobile),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                _buildNotasVencimentoPorMesChart(notas, isMobile),
                const SizedBox(height: 16),
                _buildNotasAbertasPorLocalChart(notas, isMobile),
              ],
            ),
          const SizedBox(height: 24),
          if (!isMobile)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildStatusChart(stats, isMobile),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildPrioridadeChart(stats, isMobile),
                ),
              ],
            )
          else
            Column(
              children: [
                _buildStatusChart(stats, isMobile),
                const SizedBox(height: 16),
                _buildPrioridadeChart(stats, isMobile),
              ],
            ),
          const SizedBox(height: 32),
          _buildPrazoSection(stats, isMobile),
          const SizedBox(height: 32),
          if (!isMobile)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildTipoChart(stats, isMobile),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTopLocaisGPMs(stats, isMobile),
                ),
              ],
            )
          else
            Column(
              children: [
                _buildTipoChart(stats, isMobile),
                const SizedBox(height: 16),
                _buildTopLocaisGPMs(stats, isMobile),
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

  Widget _buildOverviewCards(Map<String, dynamic> stats, bool isMobile) {
    return Row(
      children: [
        Expanded(
          child: _buildModernStatCard(
            'Total',
            (stats['total'] as int).toString(),
            Icons.description,
            Colors.blue,
            isMobile,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildModernStatCard(
            'Abertas',
            (stats['abertas'] as int).toString(),
            Icons.folder_open,
            Colors.orange,
            isMobile,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildModernStatCard(
            'Concluídas',
            (stats['concluidas'] as int).toString(),
            Icons.check_circle,
            Colors.green,
            isMobile,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildModernStatCard(
            'Vencidas',
            (stats['vencidas'] as int).toString(),
            Icons.warning,
            Colors.red,
            isMobile,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildModernStatCard(
            'Em Risco',
            (stats['emRisco'] as int).toString(),
            Icons.error_outline,
            Colors.yellow[700]!,
            isMobile,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildModernStatCard(
            'No Prazo',
            (stats['noPrazo'] as int).toString(),
            Icons.schedule,
            Colors.teal,
            isMobile,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildModernStatCard(
            'Sem Prazo',
            (stats['semPrazo'] as int).toString(),
            Icons.help_outline,
            Colors.grey,
            isMobile,
          ),
        ),
      ],
    );
  }

  Widget _buildModernStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    bool isMobile,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 10 : 14,
          vertical: isMobile ? 8 : 10,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(isMobile ? 6 : 7),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: isMobile ? 16 : 18),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isMobile ? 9 : 10,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotasAbertasPorLocalChart(List<NotaSAP> notas, bool isMobile) {
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
      return _buildEmptyChart('Notas Abertas por Local', isMobile);
    }

    // Ordenar e pegar os top 10
    final sortedEntries = abertasPorLocal.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topEntries = sortedEntries.take(10).toList();
    final maxValue = topEntries.isNotEmpty
        ? topEntries.map((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble()
        : 1.0;

    return _buildChartCard(
      'Notas Abertas por Local',
      Icons.location_on,
      Colors.teal,
      _buildHorizontalBarChartForLocals(
        topEntries,
        maxValue,
        isMobile,
      ),
      null,
      isMobile,
    );
  }

  Widget _buildNotasVencimentoPorMesChart(List<NotaSAP> notas, bool isMobile) {
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
      'Notas que Vencem em $anoAtual',
      Icons.calendar_today,
      Colors.blue,
      _buildHorizontalBarChart(
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
    // Cores diferentes para cada mês
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
    List<MapEntry<String, int>> entries,
    double maxValue,
    bool isMobile,
  ) {
    final colors = [
      Colors.teal,
      Colors.cyan,
      Colors.blue,
      Colors.indigo,
      Colors.purple,
      Colors.deepPurple,
      Colors.blueGrey,
      Colors.grey,
      Colors.brown,
      Colors.amber,
    ];
    
    return SizedBox(
      height: isMobile ? 400 : 500,
      child: ListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: entries.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final valor = item.value.toDouble();
          final percentage = maxValue > 0 ? (valor / maxValue) : 0.0;
          final color = colors[index % colors.length];
          
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: isMobile ? 50 : 60,
                  child: Text(
                    item.key.length > (isMobile ? 8 : 12) 
                        ? '${item.key.substring(0, isMobile ? 8 : 12)}...' 
                        : item.key,
                    style: TextStyle(
                      fontSize: isMobile ? 10 : 11,
                      color: Colors.grey[700],
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
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(6),
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
                                borderRadius: BorderRadius.circular(6),
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: valor > 0
                                  ? Text(
                                      valor.toInt().toString(),
                                      style: TextStyle(
                                        fontSize: isMobile ? 10 : 11,
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
                    style: TextStyle(
                      fontSize: isMobile ? 11 : 12,
                      color: Colors.grey[700],
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
    List<int> meses,
    List<double> valores,
    List<String> nomesMeses,
    double maxValue,
    Color Function(int) getColor,
    bool isMobile,
  ) {
    return SizedBox(
      height: isMobile ? 400 : 500,
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
                    style: TextStyle(
                      fontSize: isMobile ? 10 : 11,
                      color: Colors.grey[700],
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
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(6),
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
                                borderRadius: BorderRadius.circular(6),
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: valor > 0
                                  ? Text(
                                      valor.toInt().toString(),
                                      style: TextStyle(
                                        fontSize: isMobile ? 10 : 11,
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
                    style: TextStyle(
                      fontSize: isMobile ? 11 : 12,
                      color: Colors.grey[700],
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

  Widget _buildStatusChart(Map<String, dynamic> stats, bool isMobile) {
    final porStatus = stats['porStatus'] as Map<String, int>;
    if (porStatus.isEmpty) {
      return _buildEmptyChart('Status', isMobile);
    }

    final sortedEntries = porStatus.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topEntries = sortedEntries.take(6).toList();

    return _buildChartCard(
      'Distribuição por Status',
      Icons.assessment,
      Colors.blue,
      PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: isMobile ? 40 : 60,
          sections: topEntries.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final colors = [
              Colors.blue,
              Colors.green,
              Colors.orange,
              Colors.red,
              Colors.purple,
              Colors.teal,
            ];
            return PieChartSectionData(
              value: item.value.toDouble(),
              title: '${item.value}',
              color: colors[index % colors.length],
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
      _buildLegend(topEntries, isMobile),
      isMobile,
    );
  }

  Widget _buildPrioridadeChart(Map<String, dynamic> stats, bool isMobile) {
    final porPrioridade = stats['porPrioridade'] as Map<String, int>;
    if (porPrioridade.isEmpty) {
      return _buildEmptyChart('Prioridade', isMobile);
    }

    final sortedEntries = porPrioridade.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topEntries = sortedEntries.take(5).toList();

    return _buildChartCard(
      'Distribuição por Prioridade',
      Icons.priority_high,
      Colors.orange,
      BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: topEntries.isEmpty
              ? 1
              : topEntries.map((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble() * 1.2,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => Colors.grey[800]!,
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
                        color: Colors.grey[700],
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
                      color: Colors.grey[700],
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
                color: Colors.grey[200]!,
                strokeWidth: 1,
              );
            },
          ),
          borderData: FlBorderData(show: false),
          barGroups: topEntries.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final colors = [
              Colors.red,
              Colors.orange,
              Colors.yellow[700]!,
              Colors.blue,
              Colors.green,
            ];
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: item.value.toDouble(),
                  color: colors[index % colors.length],
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

  Widget _buildTipoChart(Map<String, dynamic> stats, bool isMobile) {
    final porTipo = stats['porTipo'] as Map<String, int>;
    if (porTipo.isEmpty) {
      return _buildEmptyChart('Tipo', isMobile);
    }

    final sortedEntries = porTipo.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topEntries = sortedEntries.take(6).toList();

    return _buildChartCard(
      'Distribuição por Tipo',
      Icons.category,
      Colors.purple,
      BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: topEntries.isEmpty
              ? 1
              : topEntries.map((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble() * 1.2,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => Colors.grey[800]!,
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
                        color: Colors.grey[700],
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
                      color: Colors.grey[700],
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
                color: Colors.grey[200]!,
                strokeWidth: 1,
              );
            },
          ),
          borderData: FlBorderData(show: false),
          barGroups: topEntries.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final colors = [
              Colors.purple,
              Colors.indigo,
              Colors.blue,
              Colors.teal,
              Colors.green,
              Colors.orange,
            ];
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: item.value.toDouble(),
                  color: colors[index % colors.length],
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

  Widget _buildPrazoSection(Map<String, dynamic> stats, bool isMobile) {
    final notasVencidas = stats['notasVencidas'] as List<NotaSAP>;
    final notasEmRisco = stats['notasEmRisco'] as List<NotaSAP>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (notasVencidas.isNotEmpty)
          _buildAlertSection(
            'Notas Vencidas',
            Icons.warning,
            Colors.red,
            notasVencidas,
            isMobile,
          ),
        if (notasVencidas.isNotEmpty && notasEmRisco.isNotEmpty)
          const SizedBox(height: 16),
        if (notasEmRisco.isNotEmpty)
          _buildAlertSection(
            'Notas em Risco (0-30 dias)',
            Icons.error_outline,
            Colors.yellow[700]!,
            notasEmRisco,
            isMobile,
          ),
      ],
    );
  }

  Widget _buildAlertSection(
    String title,
    IconData icon,
    Color color,
    List<NotaSAP> notas,
    bool isMobile,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: isMobile ? 18 : 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${notas.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: notas.take(10).map((nota) {
                final diasRestantes = nota.diasRestantes ?? 0;
                return _buildNotaTile(nota, diasRestantes, isMobile);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotaTile(NotaSAP nota, int diasRestantes, bool isMobile) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 60,
            decoration: BoxDecoration(
              color: diasRestantes <= 0 ? Colors.red : Colors.yellow[700],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nota: ${nota.nota}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (nota.descricao != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    nota.descricao!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
                if (nota.dataVencimento != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        'Vencimento: ${_formatDate(nota.dataVencimento!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: diasRestantes <= 0 ? Colors.red : Colors.yellow[700],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              diasRestantes <= 0
                  ? '${diasRestantes.abs()} dias'
                  : '$diasRestantes dias',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopLocaisGPMs(Map<String, dynamic> stats, bool isMobile) {
    final porLocal = stats['porLocal'] as Map<String, int>;
    final porGPM = stats['porGPM'] as Map<String, int>;

    return Column(
      children: [
        _buildTopList('Top Locais', Icons.location_on, Colors.teal, porLocal, isMobile),
        const SizedBox(height: 16),
        _buildTopList('Top GPMs', Icons.business, Colors.indigo, porGPM, isMobile),
      ],
    );
  }

  Widget _buildTopList(
    String title,
    IconData icon,
    Color color,
    Map<String, int> items,
    bool isMobile,
  ) {
    if (items.isEmpty) {
      return _buildEmptyChart(title, isMobile);
    }

    final sortedItems = items.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isMobile ? 18 : 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: sortedItems.take(5).toList().asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.key,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${item.value}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
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
    String title,
    IconData icon,
    Color color,
    Widget chart,
    Widget? legend,
    bool isMobile,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: isMobile ? 18 : 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: isMobile ? 400 : 500,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: chart is BarChart || chart is PieChart
                  ? SizedBox(
                      height: isMobile ? 250 : 300,
                      child: chart,
                    )
                  : chart,
            ),
          ),
          if (legend != null) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: legend,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyChart(String title, bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bar_chart, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Sem dados de $title',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegend(List<MapEntry<String, int>> entries, bool isMobile) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.red,
      Colors.purple,
      Colors.teal,
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 12,
      children: entries.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: colors[index % colors.length],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              item.key,
              style: TextStyle(
                fontSize: isMobile ? 11 : 12,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '(${item.value})',
              style: TextStyle(
                fontSize: isMobile ? 11 : 12,
                color: Colors.grey[500],
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
