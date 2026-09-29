import 'package:flutter/material.dart';
import '../design_system/taskflow_design_system.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../services/nota_sap_service.dart';
import '../services/ordem_service.dart';
import '../services/at_service.dart';
import '../services/si_service.dart';

class ComprehensiveDashboard extends StatefulWidget {
  final TaskService taskService;
  final List<Task>? filteredTasks;

  const ComprehensiveDashboard({
    super.key,
    required this.taskService,
    this.filteredTasks,
  });

  @override
  State<ComprehensiveDashboard> createState() => _ComprehensiveDashboardState();
}

class _ComprehensiveDashboardState extends State<ComprehensiveDashboard> {
  final NotaSAPService _notaSAPService = NotaSAPService();
  final OrdemService _ordemService = OrdemService();
  final ATService _atService = ATService();
  final SIService _siService = SIService();

  bool _isLoading = true;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadAllStats();
  }

  Future<void> _loadAllStats() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Carregar todas as estatísticas em paralelo
      final results = await Future.wait([
        _loadTaskStats(),
        _loadNotasStats(),
        _loadOrdensStats(),
        _loadATsStats(),
        _loadSIsStats(),
      ]);

      if (!mounted) return;
      setState(() {
        _stats = {
          'tarefas': results[0],
          'notas': results[1],
          'ordens': results[2],
          'ats': results[3],
          'sis': results[4],
        };
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar estatísticas: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>> _loadTaskStats() async {
    final tasks = widget.filteredTasks ?? [];
    
    if (tasks.isEmpty && widget.filteredTasks == null) {
      return {
        'total': 0,
        'emAndamento': 0,
        'concluidas': 0,
        'programadas': 0,
        'vencidas': 0,
        'porStatus': <String, int>{},
        'porTipo': <String, int>{},
      };
    }

    final now = DateTime.now();
    int total = tasks.length;
    int emAndamento = 0;
    int concluidas = 0;
    int programadas = 0;
    int vencidas = 0;

    final porStatus = <String, int>{};
    final porTipo = <String, int>{};

    for (var task in tasks) {
      final status = task.status.toUpperCase();
      final currentStatusCount = porStatus[status] ?? 0;
      porStatus[status] = currentStatusCount + 1;

      final tipo = task.tipo;
      final currentTipoCount = porTipo[tipo] ?? 0;
      porTipo[tipo] = currentTipoCount + 1;

      if (status.contains('CONCLU') || status.contains('FINALIZ')) {
        concluidas++;
      } else if (status.contains('ANDAMENTO') || status.contains('EXEC')) {
        emAndamento++;
      } else if (task.dataInicio.isAfter(now)) {
        programadas++;
      }

      if (task.dataFim.isBefore(now) && !status.contains('CONCLU')) {
        vencidas++;
      }
    }

    return {
      'total': total,
      'emAndamento': emAndamento,
      'concluidas': concluidas,
      'programadas': programadas,
      'vencidas': vencidas,
      'porStatus': porStatus,
      'porTipo': porTipo,
    };
  }

  Future<Map<String, dynamic>> _loadNotasStats() async {
    final notas = await _notaSAPService.getAllNotas();

    int total = notas.length;
    int abertas = 0;
    int concluidas = 0;
    int vencidas = 0;
    int semPrazo = 0;
    int emRisco = 0;

    final porStatus = <String, int>{};
    final porPrioridade = <String, int>{};
    final porTipo = <String, int>{};

    for (var nota in notas) {
      final status = nota.statusSistema?.toUpperCase() ?? 'SEM STATUS';
      porStatus[status] = (porStatus[status] ?? 0) + 1;

      final prioridade = nota.textPrioridade ?? 'Sem Prioridade';
      porPrioridade[prioridade] = (porPrioridade[prioridade] ?? 0) + 1;

      final tipo = nota.tipo ?? 'Sem Tipo';
      porTipo[tipo] = (porTipo[tipo] ?? 0) + 1;

      if (status.contains('MSEN')) {
        concluidas++;
      } else {
        abertas++;
      }

      final diasRestantes = nota.diasRestantes;
      if (diasRestantes == null) {
        semPrazo++;
      } else if (diasRestantes <= 0) {
        vencidas++;
      } else if (diasRestantes <= 30) {
        emRisco++;
      }
    }

    return {
      'total': total,
      'abertas': abertas,
      'concluidas': concluidas,
      'vencidas': vencidas,
      'semPrazo': semPrazo,
      'emRisco': emRisco,
      'porStatus': porStatus,
      'porPrioridade': porPrioridade,
      'porTipo': porTipo,
    };
  }

  Future<Map<String, dynamic>> _loadOrdensStats() async {
    final ordens = await _ordemService.getAllOrdens();

    int total = ordens.length;
    final porStatus = <String, int>{};
    final porTipo = <String, int>{};

    for (var ordem in ordens) {
      final status = ordem.statusSistema?.toUpperCase() ?? 'SEM STATUS';
      porStatus[status] = (porStatus[status] ?? 0) + 1;

      final tipo = ordem.tipo ?? 'Sem Tipo';
      porTipo[tipo] = (porTipo[tipo] ?? 0) + 1;
    }

    return {
      'total': total,
      'porStatus': porStatus,
      'porTipo': porTipo,
    };
  }

  Future<Map<String, dynamic>> _loadATsStats() async {
    final ats = await _atService.getAllATs();

    int total = ats.length;
    final porStatus = <String, int>{};

    for (var at in ats) {
      final status = at.statusSistema?.toUpperCase() ?? 'SEM STATUS';
      porStatus[status] = (porStatus[status] ?? 0) + 1;
    }

    return {
      'total': total,
      'porStatus': porStatus,
    };
  }

  Future<Map<String, dynamic>> _loadSIsStats() async {
    final sis = await _siService.getAllSIs();

    int total = sis.length;
    final porStatus = <String, int>{};
    final porTipo = <String, int>{};

    for (var si in sis) {
      final status = si.statusSistema?.toUpperCase() ?? 'SEM STATUS';
      porStatus[status] = (porStatus[status] ?? 0) + 1;

      final tipo = si.tipo ?? 'Sem Tipo';
      porTipo[tipo] = (porTipo[tipo] ?? 0) + 1;
    }

    return {
      'total': total,
      'porStatus': porStatus,
      'porTipo': porTipo,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final spacing = context.tfSpacing;

    if (_isLoading) {
      return const Center(
        child: TFLoading(message: 'Carregando estatísticas consolidadas...'),
      );
    }

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            TFPageHeader(
              title: 'Dashboard Geral',
              subtitle: 'Visão geral e consolidação operacional de atividades e integrações SAP.',
              secondaryActions: [
                TFIconButton(
                  icon: TFIcons.refresh,
                  tooltip: 'Atualizar Dados',
                  onPressed: _loadAllStats,
                ),
              ],
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadAllStats,
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(spacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildOverviewCards(context),
                      SizedBox(height: spacing.md),
                      _buildTarefasSection(context),
                      SizedBox(height: spacing.md),
                      _buildNotasSection(context),
                      SizedBox(height: spacing.md),
                      _buildSAPSection(context),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCards(BuildContext context) {
    final spacing = context.tfSpacing;
    final colors = context.tfColors;

    final tarefas = _stats['tarefas'] as Map<String, dynamic>? ?? {};
    final notas = _stats['notas'] as Map<String, dynamic>? ?? {};
    final ordens = _stats['ordens'] as Map<String, dynamic>? ?? {};
    final ats = _stats['ats'] as Map<String, dynamic>? ?? {};
    final sis = _stats['sis'] as Map<String, dynamic>? ?? {};

    final totalGeral = (tarefas['total'] as int? ?? 0) +
        (notas['total'] as int? ?? 0) +
        (ordens['total'] as int? ?? 0) +
        (ats['total'] as int? ?? 0) +
        (sis['total'] as int? ?? 0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= TFBreakpoints.md;
        final isTablet = constraints.maxWidth >= TFBreakpoints.sm && !isDesktop;
        final crossAxisCount = isDesktop ? 5 : (isTablet ? 3 : 2);

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: spacing.sm,
          crossAxisSpacing: spacing.sm,
          childAspectRatio: isDesktop ? 1.6 : (isTablet ? 1.4 : 1.2),
          children: [
            _buildOverviewCard(
              context,
              'Total Geral',
              totalGeral.toString(),
              Icons.apps_rounded,
              colors.primary,
            ),
            _buildOverviewCard(
              context,
              'Tarefas',
              (tarefas['total'] as int? ?? 0).toString(),
              Icons.assignment_rounded,
              colors.warning,
            ),
            _buildOverviewCard(
              context,
              'Notas SAP',
              (notas['total'] as int? ?? 0).toString(),
              Icons.description_rounded,
              colors.info,
            ),
            _buildOverviewCard(
              context,
              'Ordens',
              (ordens['total'] as int? ?? 0).toString(),
              Icons.receipt_long_rounded,
              colors.info,
            ),
            _buildOverviewCard(
              context,
              'ATs + SIs',
              ((ats['total'] as int? ?? 0) + (sis['total'] as int? ?? 0)).toString(),
              Icons.engineering_rounded,
              colors.success,
            ),
          ],
        );
      },
    );
  }

  Widget _buildOverviewCard(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: typography.bodySmall.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Container(
                padding: EdgeInsets.all(spacing.xs),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: TFRadius.borderRadiusSm,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          Text(
            value,
            style: typography.sectionTitle.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 26,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTarefasSection(BuildContext context) {
    final colors = context.tfColors;
    final tarefas = _stats['tarefas'] as Map<String, dynamic>? ?? {};

    return _buildSectionCard(
      context,
      'Tarefas Operacionais',
      Icons.assignment_outlined,
      colors.warning,
      [
        _buildStatRow(context, 'Total', (tarefas['total'] as int? ?? 0).toString(), colors.info),
        _buildStatRow(context, 'Em Andamento', (tarefas['emAndamento'] as int? ?? 0).toString(), colors.warning),
        _buildStatRow(context, 'Concluídas', (tarefas['concluidas'] as int? ?? 0).toString(), colors.success),
        _buildStatRow(context, 'Programadas', (tarefas['programadas'] as int? ?? 0).toString(), colors.primary),
        if ((tarefas['vencidas'] as int? ?? 0) > 0)
          _buildStatRow(context, 'Vencidas', (tarefas['vencidas'] as int? ?? 0).toString(), colors.danger),
      ],
      _buildDistributionChart(context, tarefas['porStatus'] as Map<String, int>? ?? {}),
    );
  }

  Widget _buildNotasSection(BuildContext context) {
    final colors = context.tfColors;
    final notas = _stats['notas'] as Map<String, dynamic>? ?? {};

    return _buildSectionCard(
      context,
      'Notas SAP',
      Icons.description_outlined,
      colors.info,
      [
        _buildStatRow(context, 'Total', (notas['total'] as int? ?? 0).toString(), colors.info),
        _buildStatRow(context, 'Abertas', (notas['abertas'] as int? ?? 0).toString(), colors.warning),
        _buildStatRow(context, 'Concluídas', (notas['concluidas'] as int? ?? 0).toString(), colors.success),
        _buildStatRow(context, 'Vencidas', (notas['vencidas'] as int? ?? 0).toString(), colors.danger),
        _buildStatRow(context, 'Em Risco', (notas['emRisco'] as int? ?? 0).toString(), colors.warning),
        _buildStatRow(context, 'Sem Prazo', (notas['semPrazo'] as int? ?? 0).toString(), colors.textSecondary),
      ],
      _buildDistributionChart(context, notas['porPrioridade'] as Map<String, int>? ?? {}),
    );
  }

  Widget _buildSAPSection(BuildContext context) {
    final colors = context.tfColors;
    final spacing = context.tfSpacing;

    final ordens = _stats['ordens'] as Map<String, dynamic>? ?? {};
    final ats = _stats['ats'] as Map<String, dynamic>? ?? {};
    final sis = _stats['sis'] as Map<String, dynamic>? ?? {};

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < TFBreakpoints.sm;

        if (isMobile) {
          return Column(
            children: [
              _buildMiniCard(context, 'Ordens SAP', (ordens['total'] as int? ?? 0).toString(), Icons.receipt_long_outlined, colors.info),
              SizedBox(height: spacing.sm),
              _buildMiniCard(context, 'Autorizações de Trabalho (ATs)', (ats['total'] as int? ?? 0).toString(), Icons.engineering_outlined, colors.primary),
              SizedBox(height: spacing.sm),
              _buildMiniCard(context, 'Solicitações de Intervenção (SIs)', (sis['total'] as int? ?? 0).toString(), Icons.info_outline, colors.success),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: _buildMiniCard(context, 'Ordens SAP', (ordens['total'] as int? ?? 0).toString(), Icons.receipt_long_outlined, colors.info),
            ),
            SizedBox(width: spacing.sm),
            Expanded(
              child: _buildMiniCard(context, 'Autorizações de Trabalho (ATs)', (ats['total'] as int? ?? 0).toString(), Icons.engineering_outlined, colors.primary),
            ),
            SizedBox(width: spacing.sm),
            Expanded(
              child: _buildMiniCard(context, 'Solicitações de Intervenção (SIs)', (sis['total'] as int? ?? 0).toString(), Icons.info_outline, colors.success),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    List<Widget> stats,
    Widget? chart,
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
              Container(
                padding: EdgeInsets.all(spacing.xs),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: TFRadius.borderRadiusSm,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
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
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < TFBreakpoints.sm;

              if (isMobile) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...stats,
                    if (chart != null) ...[
                      SizedBox(height: spacing.md),
                      chart,
                    ],
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(children: stats),
                  ),
                  if (chart != null) ...[
                    SizedBox(width: spacing.lg),
                    Expanded(
                      flex: 3,
                      child: chart,
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(BuildContext context, String label, String value, Color color) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: typography.bodyMedium.copyWith(color: colors.textSecondary),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: TFRadius.borderRadiusSm,
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Text(
              value,
              style: typography.bodySmall.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionChart(BuildContext context, Map<String, int> distribution) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final spacing = context.tfSpacing;

    if (distribution.isEmpty) {
      return Center(
        child: Text(
          'Sem dados cadastrados',
          style: typography.caption.copyWith(color: colors.textSecondary),
        ),
      );
    }

    final total = distribution.values.fold(0, (a, b) => a + b);

    return Column(
      children: distribution.entries.take(5).map((entry) {
        final percentage = total > 0 ? (entry.value / total * 100) : 0.0;
        final barColor = _getColorForStatus(context, entry.key);

        return Padding(
          padding: EdgeInsets.symmetric(vertical: spacing.xxs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      style: typography.bodySmall.copyWith(color: colors.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${entry.value} (${percentage.toStringAsFixed(1)}%)',
                    style: typography.caption.copyWith(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              SizedBox(height: spacing.xxs),
              ClipRRect(
                borderRadius: TFRadius.borderRadiusFull,
                child: LinearProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: colors.surfaceSecondary,
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMiniCard(
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
            child: Icon(icon, color: color, size: 24),
          ),
          SizedBox(width: spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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

  Color _getColorForStatus(BuildContext context, String status) {
    final colors = context.tfColors;
    final upperStatus = status.toUpperCase();

    if (upperStatus.contains('CONCLU') || upperStatus.contains('FINALIZ') || upperStatus.contains('MSEN')) {
      return colors.success;
    } else if (upperStatus.contains('ANDAMENTO') || upperStatus.contains('EXEC') || upperStatus.contains('RISCO')) {
      return colors.warning;
    } else if (upperStatus.contains('PROG') || upperStatus.contains('PLAN') || upperStatus.contains('ALTA')) {
      return colors.primary;
    } else if (upperStatus.contains('VENCI') || upperStatus.contains('ATRAS') || upperStatus.contains('MUITO')) {
      return colors.danger;
    }
    return colors.textSecondary;
  }
}

