import 'package:flutter/material.dart';
import '../design_system/taskflow_design_system.dart';
import '../models/ordem.dart';
import '../utils/responsive.dart';

class OrdemDashboardView extends StatelessWidget {
  final List<Ordem> ordens;
  final Set<String> ordensProgramadasIds;

  const OrdemDashboardView({
    super.key,
    required this.ordens,
    this.ordensProgramadasIds = const {},
  });

  bool _isOrdemConcluida(Ordem ordem) {
    final status = ordem.statusSistema?.toUpperCase() ?? '';
    return status.contains('ENCE') || status.contains('ENTE');
  }

  Map<String, dynamic> _calculateStats(List<Ordem> ordens) {
    int total = ordens.length;
    int abertas = 0;
    int concluidas = 0;
    int programadas = 0;
    int naoProgramadas = 0;
    int vencidas = 0;
    int emRisco = 0;
    int noPrazo = 0;
    int semPrazo = 0;

    final porStatus = <String, int>{};
    final porTipo = <String, int>{};
    final porLocal = <String, int>{};
    final porGPM = <String, int>{};

    final ordensVencidas = <Ordem>[];
    final ordensEmRisco = <Ordem>[];

    final now = DateTime.now();

    for (var ordem in ordens) {
      final status = ordem.statusSistema?.toUpperCase() ?? 'SEM STATUS';
      porStatus[status] = (porStatus[status] ?? 0) + 1;

      final isConcluida = _isOrdemConcluida(ordem);
      if (isConcluida) {
        concluidas++;
      } else {
        abertas++;
      }

      final isProg = ordensProgramadasIds.contains(ordem.id);
      if (isProg) {
        programadas++;
      } else {
        naoProgramadas++;
      }

      final tipo = ordem.tipo ?? 'Sem Tipo';
      porTipo[tipo] = (porTipo[tipo] ?? 0) + 1;

      final local = ordem.local ?? 'Sem Local';
      porLocal[local] = (porLocal[local] ?? 0) + 1;

      final gpm = ordem.gpm ?? 'Sem GPM';
      porGPM[gpm] = (porGPM[gpm] ?? 0) + 1;

      final prazoRef = ordem.tolerancia ?? ordem.fimBase;
      if (prazoRef == null) {
        semPrazo++;
      } else {
        final diffDias = prazoRef.difference(now).inDays;
        if (diffDias < 0 && !isConcluida) {
          vencidas++;
          ordensVencidas.add(ordem);
        } else if (diffDias <= 30 && !isConcluida) {
          emRisco++;
          ordensEmRisco.add(ordem);
        } else if (!isConcluida) {
          noPrazo++;
        }
      }
    }

    return {
      'total': total,
      'abertas': abertas,
      'concluidas': concluidas,
      'programadas': programadas,
      'naoProgramadas': naoProgramadas,
      'vencidas': vencidas,
      'emRisco': emRisco,
      'noPrazo': noPrazo,
      'semPrazo': semPrazo,
      'porStatus': porStatus,
      'porTipo': porTipo,
      'porLocal': porLocal,
      'porGPM': porGPM,
      'ordensVencidas': ordensVencidas,
      'ordensEmRisco': ordensEmRisco,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final stats = _calculateStats(ordens);

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
                    child: _buildOrdensVencimentoPorMesChart(context, ordens, isMobile),
                  ),
                  const SizedBox(width: TFSpacing.s12),
                  Expanded(
                    child: _buildOrdensAbertasPorLocalChart(context, ordens, isMobile),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                _buildOrdensVencimentoPorMesChart(context, ordens, isMobile),
                const SizedBox(height: TFSpacing.s12),
                _buildOrdensAbertasPorLocalChart(context, ordens, isMobile),
              ],
            ),
          const SizedBox(height: TFSpacing.s16),
          if (!isMobile)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildTipoChart(context, stats, isMobile),
                ),
                const SizedBox(width: TFSpacing.s12),
                Expanded(
                  child: _buildStatusChart(context, stats, isMobile),
                ),
              ],
            )
          else
            Column(
              children: [
                _buildTipoChart(context, stats, isMobile),
                const SizedBox(height: TFSpacing.s12),
                _buildStatusChart(context, stats, isMobile),
              ],
            ),
          const SizedBox(height: TFSpacing.s24),
          _buildPrazoSection(context, stats, isMobile),
          const SizedBox(height: TFSpacing.s24),
          _buildTopLocaisGPMs(context, stats, isMobile),
        ],
      ),
    );
  }

  Widget _buildOverviewCards(BuildContext context, Map<String, dynamic> stats, bool isMobile) {
    final colors = context.tfColors;

    final cards = [
      _buildModernStatCard(
        context,
        'Total',
        (stats['total'] as int).toString(),
        Icons.assignment,
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
        'Programadas',
        (stats['programadas'] as int).toString(),
        Icons.event_available,
        colors.info,
        isMobile,
      ),
      _buildModernStatCard(
        context,
        'Não Prog.',
        (stats['naoProgramadas'] as int).toString(),
        Icons.event_busy,
        colors.textSecondary,
        isMobile,
      ),
      _buildModernStatCard(
        context,
        'Atrasadas',
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
          childAspectRatio: isMobile ? 1.6 : 1.9,
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
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? TFSpacing.s8 : TFSpacing.s12,
        vertical: isMobile ? TFSpacing.s8 : TFSpacing.s8,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(TFRadius.r8),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 6 : 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(TFRadius.r8),
            ),
            child: Icon(icon, color: color, size: isMobile ? 18 : 20),
          ),
          SizedBox(width: isMobile ? TFSpacing.s4 : TFSpacing.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: typography.sectionTitle.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                    fontSize: isMobile ? 16 : 18,
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

  Widget _buildOrdensAbertasPorLocalChart(BuildContext context, List<Ordem> ordens, bool isMobile) {
    final colors = context.tfColors;

    final abertasPorLocal = <String, int>{};
    for (var ordem in ordens) {
      if (!_isOrdemConcluida(ordem)) {
        final local = ordem.local ?? 'Sem Local';
        abertasPorLocal[local] = (abertasPorLocal[local] ?? 0) + 1;
      }
    }

    if (abertasPorLocal.isEmpty) {
      return _buildEmptyChart(context, 'Ordens Abertas por Local', isMobile);
    }

    final sortedEntries = abertasPorLocal.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topEntries = sortedEntries.take(10).toList();
    final maxValue = topEntries.isNotEmpty
        ? topEntries.map((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble()
        : 1.0;

    return _buildChartCard(
      context,
      'Ordens Abertas por Local',
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

  Widget _buildOrdensVencimentoPorMesChart(BuildContext context, List<Ordem> ordens, bool isMobile) {
    final colors = context.tfColors;

    final anoAtual = DateTime.now().year;
    final vencimentoPorMes = <int, int>{};

    for (int mes = 1; mes <= 12; mes++) {
      vencimentoPorMes[mes] = 0;
    }

    for (var ordem in ordens) {
      final prazo = ordem.tolerancia ?? ordem.fimBase;
      if (prazo != null && prazo.year == anoAtual) {
        final mes = prazo.month;
        vencimentoPorMes[mes] = (vencimentoPorMes[mes] ?? 0) + 1;
      }
    }

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
      'Tolerância de Ordens em $anoAtual',
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

    return Column(
      children: entries.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final local = item.key;
        final count = item.value;
        final percentage = maxValue > 0 ? count / maxValue : 0.0;
        final barColor = barColors[index % barColors.length];

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: isMobile ? 65 : 85,
                child: Text(
                  local,
                  style: typography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: isMobile ? 10 : 12,
                    color: colors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 18,
                      decoration: BoxDecoration(
                        color: colors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(TFRadius.r4),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: percentage.clamp(0.02, 1.0),
                      child: Container(
                        height: 18,
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: BorderRadius.circular(TFRadius.r4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 35,
                child: Text(
                  count.toString(),
                  style: typography.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 10 : 12,
                    color: colors.textPrimary,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHorizontalBarChart(
    BuildContext context,
    List<int> labels,
    List<double> values,
    List<String> labelTexts,
    double maxValue,
    Color Function(int) colorFunction,
    bool isMobile,
  ) {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return Column(
      children: labels.asMap().entries.map((entry) {
        final index = entry.key;
        final label = entry.value;
        final value = values[index];
        final labelText = labelTexts[index];
        final percentage = maxValue > 0 ? value / maxValue : 0.0;
        final barColor = colorFunction(label);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              SizedBox(
                width: isMobile ? 32 : 40,
                child: Text(
                  labelText,
                  style: typography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: isMobile ? 10 : 11,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 16,
                      decoration: BoxDecoration(
                        color: colors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(TFRadius.r4),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: percentage.clamp(0.01, 1.0),
                      child: Container(
                        height: 16,
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: BorderRadius.circular(TFRadius.r4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 35,
                child: Text(
                  value.toInt().toString(),
                  style: typography.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 10 : 11,
                    color: colors.textPrimary,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTipoChart(BuildContext context, Map<String, dynamic> stats, bool isMobile) {
    final colors = context.tfColors;
    final porTipo = stats['porTipo'] as Map<String, int>;

    if (porTipo.isEmpty) {
      return _buildEmptyChart(context, 'Ordens por Tipo', isMobile);
    }

    final sorted = porTipo.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxValue = sorted.isNotEmpty ? sorted.first.value.toDouble() : 1.0;

    return _buildChartCard(
      context,
      'Ordens por Tipo',
      Icons.category,
      colors.info,
      _buildHorizontalBarChartForLocals(context, sorted.take(8).toList(), maxValue, isMobile),
      null,
      isMobile,
    );
  }

  Widget _buildStatusChart(BuildContext context, Map<String, dynamic> stats, bool isMobile) {
    final colors = context.tfColors;
    final porStatus = stats['porStatus'] as Map<String, int>;

    if (porStatus.isEmpty) {
      return _buildEmptyChart(context, 'Ordens por Status', isMobile);
    }

    final sorted = porStatus.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxValue = sorted.isNotEmpty ? sorted.first.value.toDouble() : 1.0;

    return _buildChartCard(
      context,
      'Ordens por Status Sistema',
      Icons.pie_chart,
      colors.warning,
      _buildHorizontalBarChartForLocals(context, sorted.take(8).toList(), maxValue, isMobile),
      null,
      isMobile,
    );
  }

  Widget _buildPrazoSection(BuildContext context, Map<String, dynamic> stats, bool isMobile) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final ordensVencidas = stats['ordensVencidas'] as List<Ordem>;
    final ordensEmRisco = stats['ordensEmRisco'] as List<Ordem>;

    return Container(
      padding: const EdgeInsets.all(TFSpacing.s16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(TFRadius.r8),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber, color: colors.danger, size: 20),
              const SizedBox(width: 8),
              Text(
                'Ordens Críticas / Atrasadas (${ordensVencidas.length})',
                style: typography.sectionTitle.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              const Spacer(),
              if (ordensEmRisco.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(TFRadius.r4),
                  ),
                  child: Text(
                    '${ordensEmRisco.length} em risco (<30d)',
                    style: typography.caption.copyWith(
                      color: colors.warning,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: TFSpacing.s12),
          if (ordensVencidas.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'Nenhuma ordem aberta atrasada no momento! 🎉',
                  style: typography.bodyMedium.copyWith(color: colors.success),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: ordensVencidas.take(5).length,
              separatorBuilder: (_, __) => const Divider(height: 16),
              itemBuilder: (context, index) {
                final o = ordensVencidas[index];
                final prazo = o.tolerancia ?? o.fimBase;
                final diasAtraso = prazo != null ? DateTime.now().difference(prazo).inDays : 0;

                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.danger.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(TFRadius.r4),
                      ),
                      child: Text(
                        o.ordem,
                        style: typography.caption.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.danger,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (o.local != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.surfaceSecondary,
                          borderRadius: BorderRadius.circular(TFRadius.r4),
                        ),
                        child: Text(
                          o.local!,
                          style: typography.caption.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        o.textoBreve ?? o.denominacaoObjeto ?? '-',
                        style: typography.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${diasAtraso}d atrasada',
                      style: typography.caption.copyWith(
                        color: colors.danger,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTopLocaisGPMs(BuildContext context, Map<String, dynamic> stats, bool isMobile) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final porLocal = stats['porLocal'] as Map<String, int>;
    final porGPM = stats['porGPM'] as Map<String, int>;

    final topLocais = (porLocal.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(5).toList();
    final topGPMs = (porGPM.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(5).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(TFSpacing.s16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(TFRadius.r8),
              border: Border.all(color: colors.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Top 5 Locais com Mais Ordens', style: typography.sectionTitle.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...topLocais.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(e.key, style: typography.bodyMedium),
                      Text('${e.value}', style: typography.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: colors.primary)),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(TFSpacing.s16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(TFRadius.r8),
              border: Border.all(color: colors.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Top 5 GPMs com Mais Ordens', style: typography.sectionTitle.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...topGPMs.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(e.key, style: typography.bodyMedium),
                      Text('${e.value}', style: typography.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: colors.info)),
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

  Widget _buildChartCard(
    BuildContext context,
    String title,
    IconData icon,
    Color iconColor,
    Widget chart,
    Widget? legend,
    bool isMobile,
  ) {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return Container(
      padding: EdgeInsets.all(isMobile ? TFSpacing.s12 : TFSpacing.s16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(TFRadius.r8),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: isMobile ? 18 : 20),
              SizedBox(width: isMobile ? TFSpacing.s8 : TFSpacing.s8),
              Text(
                title,
                style: typography.sectionTitle.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 14 : 16,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? TFSpacing.s12 : TFSpacing.s16),
          chart,
          if (legend != null) ...[
            SizedBox(height: isMobile ? TFSpacing.s12 : TFSpacing.s16),
            legend,
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyChart(BuildContext context, String title, bool isMobile) {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return Container(
      padding: EdgeInsets.all(isMobile ? TFSpacing.s12 : TFSpacing.s16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(TFRadius.r8),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Center(
        child: Text(
          'Sem dados para exibir em $title',
          style: typography.caption.copyWith(color: colors.textSecondary),
        ),
      ),
    );
  }
}
