import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class AiChartWidget extends StatelessWidget {
  final String jsonContent;

  const AiChartWidget({
    super.key,
    required this.jsonContent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    try {
      final parsed = jsonDecode(jsonContent.trim());
      if (parsed is! Map<String, dynamic>) {
        return _buildErrorWidget('Formato de dados de gráfico inválido.');
      }

      final type = (parsed['type'] as String? ?? 'bar').toLowerCase();
      final title = parsed['title'] as String? ?? 'Gráfico Gerado';
      final rawData = parsed['data'] as List<dynamic>? ?? [];

      if (rawData.isEmpty) {
        return _buildErrorWidget('Nenhum dado fornecido para o gráfico.');
      }

      final List<ChartDataItem> items = rawData.map((e) {
        if (e is Map<String, dynamic>) {
          return ChartDataItem(
            label: e['label']?.toString() ?? '',
            value: double.tryParse(e['value']?.toString() ?? '0') ?? 0.0,
            colorHex: e['color']?.toString(),
          );
        }
        return ChartDataItem(label: '', value: 0.0);
      }).where((item) => item.label.isNotEmpty).toList();

      if (items.isEmpty) {
        return _buildErrorWidget('Dados do gráfico estão vazios ou corrompidos.');
      }

      Widget chart;
      if (type == 'pie') {
        chart = _buildPieChart(items, isDark, theme);
      } else if (type == 'line') {
        chart = _buildLineChart(items, isDark, theme);
      } else {
        chart = _buildBarChart(items, isDark, theme);
      }

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 12.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF181818) : Colors.white,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.black12,
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  type == 'pie'
                      ? Icons.pie_chart_outline
                      : type == 'line'
                          ? Icons.show_chart
                          : Icons.bar_chart,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            SizedBox(
              height: 200,
              child: Padding(
                padding: const EdgeInsets.only(top: 8.0, right: 8.0),
                child: chart,
              ),
            ),
            if (type == 'pie' || items.length > 5) ...[
              const SizedBox(height: 16),
              _buildLegends(items, theme),
            ]
          ],
        ),
      );
    } catch (e) {
      return _buildErrorWidget('Erro ao renderizar gráfico: $e');
    }
  }

  Widget _buildErrorWidget(String error) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(List<ChartDataItem> items, bool isDark, ThemeData theme) {
    final maxVal = items.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final limitY = maxVal == 0 ? 10.0 : maxVal * 1.25;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: limitY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => isDark ? Colors.grey[800]! : Colors.grey[200]!,
            tooltipBorder: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${items[groupIndex].label}\n',
                TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
                children: [
                  TextSpan(
                    text: rod.toY.toStringAsFixed(1).replaceFirst('.0', ''),
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: items.length <= 6,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx >= 0 && idx < items.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      items[idx].label,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
              reservedSize: 28,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  textAlign: TextAlign.right,
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: isDark ? Colors.white10 : Colors.black12,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(items.length, (idx) {
          final item = items[idx];
          return BarChartGroupData(
            x: idx,
            barRods: [
              BarChartRodData(
                toY: item.value,
                color: item.getColor(idx, theme),
                width: 16,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildPieChart(List<ChartDataItem> items, bool isDark, ThemeData theme) {
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        sections: List.generate(items.length, (idx) {
          final item = items[idx];
          return PieChartSectionData(
            color: item.getColor(idx, theme),
            value: item.value,
            title: item.value.toStringAsFixed(0),
            radius: 50,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [Shadow(color: Colors.black45, blurRadius: 2)],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildLineChart(List<ChartDataItem> items, bool isDark, ThemeData theme) {
    final maxVal = items.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final limitY = maxVal == 0 ? 10.0 : maxVal * 1.25;

    return LineChart(
      LineChartData(
        maxY: limitY,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => isDark ? Colors.grey[800]! : Colors.grey[200]!,
            tooltipBorder: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((touchedSpot) {
                return LineTooltipItem(
                  '${items[touchedSpot.spotIndex].label}\n',
                  TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                  children: [
                    TextSpan(
                      text: touchedSpot.y.toStringAsFixed(1).replaceFirst('.0', ''),
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
              }).toList();
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: items.length <= 6,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx >= 0 && idx < items.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      items[idx].label,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
              reservedSize: 28,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  textAlign: TextAlign.right,
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: isDark ? Colors.white10 : Colors.black12,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(items.length, (idx) {
              return FlSpot(idx.toDouble(), items[idx].value);
            }),
            isCurved: true,
            color: theme.colorScheme.primary,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: theme.colorScheme.primary.withOpacity(0.15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegends(List<ChartDataItem> items, ThemeData theme) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: List.generate(items.length, (idx) {
        final item = items[idx];
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: item.getColor(idx, theme),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${item.label} (${item.value.toStringAsFixed(0)})',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        );
      }),
    );
  }
}

class ChartDataItem {
  final String label;
  final double value;
  final String? colorHex;

  ChartDataItem({
    required this.label,
    required this.value,
    this.colorHex,
  });

  Color getColor(int index, ThemeData theme) {
    if (colorHex != null) {
      final hex = colorHex!.replaceAll('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      } else if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    }

    final List<Color> palette = [
      theme.colorScheme.primary,
      Colors.teal,
      Colors.orange,
      Colors.indigo,
      Colors.purple,
      Colors.cyan,
      Colors.pink,
      Colors.amber,
      Colors.lightBlue,
      Colors.deepOrange,
    ];
    return palette[index % palette.length];
  }
}
