import 'package:flutter/material.dart';
import '../design_system/taskflow_design_system.dart';
import '../models/task.dart';
import '../services/task_service.dart';

class AnalyticsView extends StatelessWidget {
  final TaskService taskService;
  final List<Task>? filteredTasks;

  const AnalyticsView({
    super.key,
    required this.taskService,
    this.filteredTasks,
  });

  Map<String, dynamic> _calculateStatsFromTasks(List<Task> tasks) {
    final now = DateTime.now();
    int total = tasks.length;
    int emAndamento = 0;
    int concluidas = 0;
    int programadas = 0;

    final porStatus = <String, int>{};
    final porTipo = <String, int>{};
    final porRegional = <String, int>{};

    for (var task in tasks) {
      final status = task.status.toLowerCase();
      final statusKey = task.status.isEmpty ? 'Sem Status' : task.status;
      porStatus[statusKey] = (porStatus[statusKey] ?? 0) + 1;

      final tipoKey = task.tipo.isEmpty ? 'Sem Tipo' : task.tipo;
      porTipo[tipoKey] = (porTipo[tipoKey] ?? 0) + 1;

      final regKey = task.regional.isEmpty ? 'Sem Regional' : task.regional;
      porRegional[regKey] = (porRegional[regKey] ?? 0) + 1;

      if (status.contains('conclu') || status.contains('finaliz')) {
        concluidas++;
      } else if (status.contains('andamento') || status.contains('exec')) {
        emAndamento++;
      } else if (task.dataInicio.isAfter(now)) {
        programadas++;
      }
    }

    return {
      'total': total,
      'emAndamento': emAndamento,
      'concluidas': concluidas,
      'programadas': programadas,
      'porStatus': porStatus,
      'porTipo': porTipo,
      'porRegional': porRegional,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final spacing = context.tfSpacing;

    if (filteredTasks != null) {
      final stats = _calculateStatsFromTasks(filteredTasks!);
      return Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: Column(
            children: [
              const TFPageHeader(
                title: 'Análises e Gráficos',
                subtitle: 'Distribuição analítica de atividades por status, tipo e regional.',
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(spacing.md),
                  child: _buildBody(context, stats),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            const TFPageHeader(
              title: 'Análises e Gráficos',
              subtitle: 'Distribuição analítica de atividades por status, tipo e regional.',
            ),
            Expanded(
              child: FutureBuilder<Map<String, dynamic>>(
                future: taskService.getStatistics(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: TFLoading(message: 'Carregando análises estatísticas...'));
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: TFEmptyState(
                        icon: Icons.error_outline_rounded,
                        title: 'Erro ao carregar estatísticas',
                        description: '${snapshot.error}',
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: TFEmptyState(
                        icon: Icons.inbox_outlined,
                        title: 'Nenhum dado disponível',
                        description: 'Não há dados para exibir as estatísticas no momento.',
                      ),
                    );
                  }

                  final stats = snapshot.data ?? {};

                  return SingleChildScrollView(
                    padding: EdgeInsets.all(spacing.md),
                    child: _buildBody(context, stats),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, Map<String, dynamic> stats) {
    final spacing = context.tfSpacing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPerformanceMetrics(context, stats),
        SizedBox(height: spacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= TFBreakpoints.md;

            if (isDesktop) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildChartCard(
                      context,
                      'Distribuição por Status',
                      Icons.pie_chart_outline_rounded,
                      _buildStatusChart(context, stats),
                    ),
                  ),
                  SizedBox(width: spacing.md),
                  Expanded(
                    child: _buildChartCard(
                      context,
                      'Atividades por Tipo',
                      Icons.bar_chart_rounded,
                      _buildTypeChart(context, stats),
                    ),
                  ),
                ],
              );
            }

            return Column(
              children: [
                _buildChartCard(
                  context,
                  'Distribuição por Status',
                  Icons.pie_chart_outline_rounded,
                  _buildStatusChart(context, stats),
                ),
                SizedBox(height: spacing.md),
                _buildChartCard(
                  context,
                  'Atividades por Tipo',
                  Icons.bar_chart_rounded,
                  _buildTypeChart(context, stats),
                ),
              ],
            );
          },
        ),
        SizedBox(height: spacing.md),
        _buildChartCard(
          context,
          'Atividades por Regional',
          Icons.map_outlined,
          _buildRegionalChart(context, stats),
        ),
      ],
    );
  }

  Widget _buildChartCard(
    BuildContext context,
    String title,
    IconData icon,
    Widget chart,
  ) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    return TFCard(
      padding: EdgeInsets.all(spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: colors.primary, size: 20),
              SizedBox(width: spacing.sm),
              Text(
                title,
                style: typography.sectionTitle.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.md),
          chart,
        ],
      ),
    );
  }

  Widget _buildStatusChart(BuildContext context, Map<String, dynamic> stats) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    final porStatus = (stats['porStatus'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as int)) ?? <String, int>{};
    final total = stats['total'] as int? ?? 0;

    if (porStatus.isEmpty) {
      return Center(
        child: Text('Sem dados de status', style: typography.caption.copyWith(color: colors.textSecondary)),
      );
    }

    return Column(
      children: porStatus.entries.map((entry) {
        final percentage = total > 0 ? (entry.value / total * 100) : 0.0;
        final barColor = _getStatusColor(context, entry.key);

        return Padding(
          padding: EdgeInsets.symmetric(vertical: spacing.xs),
          child: Row(
            children: [
              SizedBox(
                width: 90,
                child: Text(
                  entry.key,
                  style: typography.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: TFRadius.borderRadiusSm,
                      child: LinearProgressIndicator(
                        value: percentage / 100,
                        minHeight: 24,
                        backgroundColor: colors.surfaceSecondary,
                        valueColor: AlwaysStoppedAnimation<Color>(barColor),
                      ),
                    ),
                    Positioned.fill(
                      child: Center(
                        child: Text(
                          '${entry.value} (${percentage.toStringAsFixed(1)}%)',
                          style: typography.caption.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTypeChart(BuildContext context, Map<String, dynamic> stats) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    final porTipo = (stats['porTipo'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as int)) ?? <String, int>{};
    final maxValue = porTipo.values.isEmpty ? 1 : porTipo.values.reduce((a, b) => a > b ? a : b);

    if (porTipo.isEmpty) {
      return Center(
        child: Text('Sem dados de tipo', style: typography.caption.copyWith(color: colors.textSecondary)),
      );
    }

    return Column(
      children: porTipo.entries.map((entry) {
        final percentage = maxValue > 0 ? (entry.value / maxValue) : 0.0;
        final barColor = _getTypeColor(context, entry.key);

        return Padding(
          padding: EdgeInsets.symmetric(vertical: spacing.xs),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  entry.key,
                  style: typography.bodySmall.copyWith(color: colors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 3,
                child: ClipRRect(
                  borderRadius: TFRadius.borderRadiusSm,
                  child: LinearProgressIndicator(
                    value: percentage,
                    minHeight: 18,
                    backgroundColor: colors.surfaceSecondary,
                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
                  ),
                ),
              ),
              SizedBox(width: spacing.sm),
              SizedBox(
                width: 45,
                child: Text(
                  entry.value.toString(),
                  style: typography.bodySmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRegionalChart(BuildContext context, Map<String, dynamic> stats) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    final porRegional = (stats['porRegional'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as int)) ?? <String, int>{};

    if (porRegional.isEmpty) {
      return Center(
        child: Text('Sem dados de regional', style: typography.caption.copyWith(color: colors.textSecondary)),
      );
    }

    return Wrap(
      spacing: spacing.sm,
      runSpacing: spacing.sm,
      children: porRegional.entries.map((entry) {
        final itemColor = _getTypeColor(context, entry.key);

        return Container(
          padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
          decoration: BoxDecoration(
            color: itemColor.withValues(alpha: 0.1),
            borderRadius: TFRadius.borderRadiusMd,
            border: Border.all(
              color: itemColor.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                entry.value.toString(),
                style: typography.sectionTitle.copyWith(
                  fontWeight: FontWeight.bold,
                  color: itemColor,
                ),
              ),
              SizedBox(height: spacing.xxs),
              Text(
                entry.key,
                style: typography.caption.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPerformanceMetrics(BuildContext context, Map<String, dynamic> stats) {
    final colors = context.tfColors;
    final spacing = context.tfSpacing;

    final total = stats['total'] as int? ?? 0;
    final concluidas = stats['concluidas'] as int? ?? 0;
    final emAndamento = stats['emAndamento'] as int? ?? 0;
    final programadas = stats['programadas'] as int? ?? 0;
    final taxaConclusao = total > 0 ? (concluidas / total * 100) : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= TFBreakpoints.md;
        final isTablet = constraints.maxWidth >= TFBreakpoints.sm && !isDesktop;
        final crossAxisCount = isDesktop ? 4 : (isTablet ? 2 : 2);

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: spacing.sm,
          crossAxisSpacing: spacing.sm,
          childAspectRatio: isDesktop ? 1.8 : 1.4,
          children: [
            _buildMetricCard(
              context,
              'Total de Atividades',
              total.toString(),
              Icons.assignment_rounded,
              colors.primary,
            ),
            _buildMetricCard(
              context,
              'Taxa de Conclusão',
              '${taxaConclusao.toStringAsFixed(1)}%',
              Icons.check_circle_rounded,
              colors.success,
            ),
            _buildMetricCard(
              context,
              'Em Andamento',
              emAndamento.toString(),
              Icons.schedule_rounded,
              colors.warning,
            ),
            _buildMetricCard(
              context,
              'Programadas',
              programadas.toString(),
              Icons.event_rounded,
              colors.info,
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    return TFCard(
      padding: EdgeInsets.all(spacing.md),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(spacing.sm),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: TFRadius.borderRadiusMd,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          SizedBox(width: spacing.md),
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
                  ),
                ),
                Text(
                  title,
                  style: typography.caption.copyWith(color: colors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(BuildContext context, String status) {
    final colors = context.tfColors;
    final upper = status.toUpperCase();

    if (upper.contains('CONC') || upper.contains('FINALIZ')) return colors.success;
    if (upper.contains('ANDA') || upper.contains('EXEC')) return colors.warning;
    if (upper.contains('PROG') || upper.contains('PLAN')) return colors.primary;
    if (upper.contains('CANC') || upper.contains('ATRAS')) return colors.danger;
    return colors.info;
  }

  Color _getTypeColor(BuildContext context, String type) {
    final colors = context.tfColors;
    final palette = [
      colors.primary,
      colors.success,
      colors.warning,
      colors.info,
      colors.danger,
    ];
    return palette[type.hashCode.abs() % palette.length];
  }
}





