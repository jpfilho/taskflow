import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../design_system/taskflow_design_system.dart';
import '../../models/nota_sap_indicadores.dart';
import '../../utils/responsive.dart';

/// Callback para acionar drill-down para a listagem filtrada de Notas SAP
typedef OnDrillDownAnalise = void Function({
  String? statusAnalise,
  bool? comAnexos,
  bool? comMateriais,
  bool? comComentarios,
  String? centroTrabalho,
});

/// Seção visual de indicadores de análise prévia de Notas SAP
/// Exclusivamente informativa (Medir != Bloquear).
class NotasSapAnaliseDashboardSection extends StatelessWidget {
  final NotaSapIndicadores indicadores;
  final OnDrillDownAnalise? onDrillDown;
  final VoidCallback? onRefresh;

  const NotasSapAnaliseDashboardSection({
    super.key,
    required this.indicadores,
    this.onDrillDown,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cabeçalho da Seção com Banner Informativo
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: TFSpacing.s16,
            vertical: TFSpacing.s12,
          ),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(TFRadius.r8),
            border: Border.all(
              color: colors.primary.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(TFSpacing.s8),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(TFRadius.r8),
                ),
                child: Icon(
                  Icons.analytics_outlined,
                  color: colors.primary,
                  size: isMobile ? 20 : 24,
                ),
              ),
              const SizedBox(width: TFSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'ANÁLISE TÉCNICA DAS NOTAS SAP',
                          style: typography.cardTitle.copyWith(
                            fontSize: isMobile ? 14 : 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: TFSpacing.s8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: TFSpacing.s8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.info.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(TFRadius.r4),
                          ),
                          child: Text(
                            'Informativo',
                            style: typography.caption.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: colors.info,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Visibilidade gerencial sobre maturidade, cobertura e enriquecimento técnico pré-programação.',
                      style: typography.caption.copyWith(
                        color: colors.textSecondary,
                        fontSize: isMobile ? 11 : 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (onRefresh != null)
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: 'Atualizar Indicadores',
                  onPressed: onRefresh,
                ),
            ],
          ),
        ),

        const SizedBox(height: TFSpacing.s16),

        // Cards Principais de Indicadores
        _buildStatCards(context, isMobile),

        const SizedBox(height: TFSpacing.s16),

        // Gráficos Gerenciais
        if (!isMobile)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildStatusPieChart(context, isMobile),
              ),
              const SizedBox(width: TFSpacing.s12),
              Expanded(
                child: _buildMaturidadeChart(context, isMobile),
              ),
            ],
          )
        else
          Column(
            children: [
              _buildStatusPieChart(context, isMobile),
              const SizedBox(height: TFSpacing.s12),
              _buildMaturidadeChart(context, isMobile),
            ],
          ),

        const SizedBox(height: TFSpacing.s16),

        if (!isMobile)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildCentroTrabalhoChart(context, isMobile),
              ),
              const SizedBox(width: TFSpacing.s12),
              Expanded(
                child: _buildProgramacaoChart(context, isMobile),
              ),
            ],
          )
        else
          Column(
            children: [
              _buildCentroTrabalhoChart(context, isMobile),
              const SizedBox(height: TFSpacing.s12),
              _buildProgramacaoChart(context, isMobile),
            ],
          ),
      ],
    );
  }

  // ============================================================================
  // CARDS DE INDICADORES
  // ============================================================================

  Widget _buildStatCards(BuildContext context, bool isMobile) {
    final colors = context.tfColors;

    final cards = [
      _buildInteractiveCard(
        context: context,
        title: 'Cobertura Técnica',
        value: '${indicadores.taxaCobertura.toStringAsFixed(1)}%',
        subtitle:
            '${indicadores.totalNotas - indicadores.notasSemAnalise} / ${indicadores.totalNotas} Notas',
        icon: Icons.pie_chart_outline,
        color: colors.primary,
        isMobile: isMobile,
        onTap: () => onDrillDown?.call(),
      ),
      _buildInteractiveCard(
        context: context,
        title: 'Em Análise',
        value: '${indicadores.notasEmAnalise}',
        subtitle: '${indicadores.percentualEmAnalise.toStringAsFixed(1)}% do total',
        icon: Icons.pending_actions,
        color: colors.warning,
        isMobile: isMobile,
        onTap: () => onDrillDown?.call(statusAnalise: 'em_analise'),
      ),
      _buildInteractiveCard(
        context: context,
        title: 'Concluídas',
        value: '${indicadores.notasConcluidas}',
        subtitle: '${indicadores.percentualConcluidas.toStringAsFixed(1)}% do total',
        icon: Icons.task_alt,
        color: colors.success,
        isMobile: isMobile,
        onTap: () => onDrillDown?.call(statusAnalise: 'concluida'),
      ),
      _buildInteractiveCard(
        context: context,
        title: 'Com Anexos',
        value: '${indicadores.notasComAnexos}',
        subtitle: '${indicadores.percentualComAnexos.toStringAsFixed(1)}% do total',
        icon: Icons.attach_file,
        color: colors.info,
        isMobile: isMobile,
        onTap: () => onDrillDown?.call(comAnexos: true),
      ),
      _buildInteractiveCard(
        context: context,
        title: 'Com Materiais',
        value: '${indicadores.notasComMateriais}',
        subtitle: '${indicadores.percentualComMateriais.toStringAsFixed(1)}% do total',
        icon: Icons.inventory_2_outlined,
        color: Colors.purple,
        isMobile: isMobile,
        onTap: () => onDrillDown?.call(comMateriais: true),
      ),
      _buildInteractiveCard(
        context: context,
        title: 'Na Programação',
        value: '${indicadores.tarefasComAnalisePrevia}',
        subtitle:
            '${indicadores.percentualTarefasComAnalisePrevia.toStringAsFixed(1)}% das tarefas',
        icon: Icons.event_available,
        color: Colors.teal,
        isMobile: isMobile,
        onTap: () => onDrillDown?.call(statusAnalise: 'concluida'),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth < TFBreakpoints.sm
            ? 2
            : (constraints.maxWidth < TFBreakpoints.lg ? 3 : 6);

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: TFSpacing.s8,
          crossAxisSpacing: TFSpacing.s8,
          childAspectRatio: isMobile ? 1.3 : 1.5,
          children: cards,
        );
      },
    );
  }

  Widget _buildInteractiveCard({
    required BuildContext context,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isMobile,
    VoidCallback? onTap,
  }) {
    final typography = context.tfTypography;
    final colors = context.tfColors;

    return TFCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TFRadius.r8),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? TFSpacing.s8 : TFSpacing.s12,
            vertical: isMobile ? TFSpacing.s4 : TFSpacing.s8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                        fontSize: isMobile ? 11 : 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(TFSpacing.s4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(TFRadius.r4),
                    ),
                    child: Icon(icon, color: color, size: isMobile ? 14 : 16),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: typography.cardTitle.copyWith(
                      fontSize: isMobile ? 18 : 22,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: typography.caption.copyWith(
                      color: colors.textSecondary,
                      fontSize: isMobile ? 10 : 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // GRÁFICO 1: DISTRIBUIÇÃO POR STATUS DA ANÁLISE
  // ============================================================================

  Widget _buildStatusPieChart(BuildContext context, bool isMobile) {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    final items = [
      MapEntry('Sem análise', indicadores.notasSemAnalise),
      MapEntry('Em análise', indicadores.notasEmAnalise),
      MapEntry('Concluídas', indicadores.notasConcluidas),
      MapEntry('Aguardando info', indicadores.notasAguardandoInfo),
      MapEntry('Canceladas', indicadores.analisesCanceladas),
    ];

    final statusColors = {
      'Sem análise': colors.textSecondary.withValues(alpha: 0.4),
      'Em análise': colors.warning,
      'Concluídas': colors.success,
      'Aguardando info': colors.info,
      'Canceladas': colors.danger,
    };

    final total = indicadores.totalNotas;

    return TFCard(
      padding: const EdgeInsets.all(TFSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.donut_large, color: colors.primary, size: 20),
              const SizedBox(width: TFSpacing.s8),
              Text(
                'Distribuição por Status',
                style: typography.cardTitle.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: TFSpacing.s16),
          SizedBox(
            height: isMobile ? 180 : 200,
            child: total == 0
                ? Center(
                    child: Text(
                      'Nenhuma nota no período',
                      style: typography.caption.copyWith(color: colors.textSecondary),
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: isMobile ? 35 : 45,
                            sections: items.map((item) {
                              final cor = statusColors[item.key] ?? colors.primary;
                              final val = item.value.toDouble();
                              return PieChartSectionData(
                                value: val > 0 ? val : 0.01,
                                title: val > 0 ? '${val.toInt()}' : '',
                                color: cor,
                                radius: isMobile ? 40 : 50,
                                titleStyle: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(width: TFSpacing.s12),
                      Expanded(
                        flex: 6,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: items.map((item) {
                            final cor = statusColors[item.key] ?? colors.primary;
                            final pct =
                                total > 0 ? (item.value / total) * 100 : 0.0;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                              child: InkWell(
                                onTap: () {
                                  if (item.key == 'Sem análise') {
                                    onDrillDown?.call(statusAnalise: 'nao_iniciada');
                                  } else if (item.key == 'Em análise') {
                                    onDrillDown?.call(statusAnalise: 'em_analise');
                                  } else if (item.key == 'Concluídas') {
                                    onDrillDown?.call(statusAnalise: 'concluida');
                                  } else if (item.key == 'Aguardando info') {
                                    onDrillDown?.call(
                                        statusAnalise: 'aguardando_informacao');
                                  } else if (item.key == 'Canceladas') {
                                    onDrillDown?.call(statusAnalise: 'cancelada');
                                  }
                                },
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
                                    const SizedBox(width: TFSpacing.s4),
                                    Expanded(
                                      child: Text(
                                        item.key,
                                        style: typography.caption.copyWith(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      '${item.value} (${pct.toStringAsFixed(0)}%)',
                                      style: typography.caption.copyWith(
                                        fontSize: 11,
                                        color: colors.textSecondary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // GRÁFICO 2: MATURIDADE TÉCNICA DA INFORMAÇÃO
  // ============================================================================

  Widget _buildMaturidadeChart(BuildContext context, bool isMobile) {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    final niveis = [
      {
        'nivel': 'Nível 0',
        'desc': 'Somente Nota SAP (sem análise)',
        'qtd': indicadores.nivel0SomenteNota,
        'color': colors.textSecondary.withValues(alpha: 0.5),
      },
      {
        'nivel': 'Nível 1',
        'desc': 'Análise iniciada (triagem básica)',
        'qtd': indicadores.nivel1Iniciada,
        'color': colors.warning,
      },
      {
        'nivel': 'Nível 2',
        'desc': 'Diagnóstico ou escopo preenchido',
        'qtd': indicadores.nivel2DiagnosticoEscopo,
        'color': colors.info,
      },
      {
        'nivel': 'Nível 3',
        'desc': 'Análise técnica completa + materiais/anexos',
        'qtd': indicadores.nivel3Completa,
        'color': colors.success,
      },
    ];

    final maxQtd = niveis.fold<int>(
      1,
      (max, e) => (e['qtd'] as int) > max ? (e['qtd'] as int) : max,
    );

    return TFCard(
      padding: const EdgeInsets.all(TFSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.layers_outlined, color: colors.primary, size: 20),
              const SizedBox(width: TFSpacing.s8),
              Expanded(
                child: Text(
                  'Maturidade Técnica da Informação',
                  style: typography.cardTitle.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(TFRadius.r4),
                ),
                child: Text(
                  'Não-bloqueante',
                  style: typography.caption.copyWith(
                    fontSize: 10,
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: TFSpacing.s16),
          Column(
            children: niveis.map((lvl) {
              final qtd = lvl['qtd'] as int;
              final cor = lvl['color'] as Color;
              final pct = indicadores.totalNotas > 0
                  ? (qtd / indicadores.totalNotas)
                  : 0.0;
              final larguraPct = maxQtd > 0 ? (qtd / maxQtd) : 0.0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: TFSpacing.s4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${lvl['nivel']} • ${lvl['desc']}',
                            style: typography.caption.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$qtd notas (${(pct * 100).toStringAsFixed(1)}%)',
                          style: typography.caption.copyWith(
                            color: colors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(TFRadius.r4),
                      child: Container(
                        height: 8,
                        color: colors.surface,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: larguraPct.clamp(0.02, 1.0),
                            child: Container(color: cor),
                          ),
                        ),
                      ),
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

  // ============================================================================
  // GRÁFICO 3: COBERTURA POR CENTRO DE TRABALHO
  // ============================================================================

  Widget _buildCentroTrabalhoChart(BuildContext context, bool isMobile) {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    // Top 5 centros de trabalho com mais notas
    final listaCTs = indicadores.porCentroTrabalho.values.toList()
      ..sort((a, b) => b.totalNotas.compareTo(a.totalNotas));
    final topCTs = listaCTs.take(5).toList();

    return TFCard(
      padding: const EdgeInsets.all(TFSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.business_outlined, color: colors.primary, size: 20),
              const SizedBox(width: TFSpacing.s8),
              Expanded(
                child: Text(
                  'Cobertura por Centro de Trabalho',
                  style: typography.cardTitle.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: TFSpacing.s16),
          if (topCTs.isEmpty)
            SizedBox(
              height: 140,
              child: Center(
                child: Text(
                  'Nenhum dado por Centro de Trabalho',
                  style: typography.caption.copyWith(color: colors.textSecondary),
                ),
              ),
            )
          else
            Column(
              children: topCTs.map((ct) {
                final pct = ct.taxaCobertura;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: TFSpacing.s4),
                  child: InkWell(
                    onTap: () => onDrillDown?.call(centroTrabalho: ct.centroTrabalho),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                ct.centroTrabalho,
                                style: typography.caption.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${ct.comAnalise}/${ct.totalNotas} (${pct.toStringAsFixed(0)}%)',
                              style: typography.caption.copyWith(
                                color: colors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(TFRadius.r4),
                          child: Container(
                            height: 8,
                            color: colors.surface,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: (pct / 100).clamp(0.02, 1.0),
                                child: Container(
                                  color: pct >= 70
                                      ? colors.success
                                      : (pct >= 40 ? colors.warning : colors.info),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // ============================================================================
  // GRÁFICO 4: USO NA PROGRAMAÇÃO (VÍNCULOS COM TAREFAS)
  // ============================================================================

  Widget _buildProgramacaoChart(BuildContext context, bool isMobile) {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    final totalTarefas = indicadores.tarefasTotalVinculadas;
    final comPrevia = indicadores.tarefasComAnalisePrevia;
    final semAnalise = indicadores.tarefasSemAnalise;
    final comPosterior = indicadores.tarefasComAnalisePosteriorOuAtual;

    return TFCard(
      padding: const EdgeInsets.all(TFSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today_outlined,
                  color: colors.primary, size: 20),
              const SizedBox(width: TFSpacing.s8),
              Expanded(
                child: Text(
                  'Uso da Análise na Programação',
                  style: typography.cardTitle.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.info.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(TFRadius.r4),
                ),
                child: Text(
                  'Validação Temporal',
                  style: typography.caption.copyWith(
                    fontSize: 10,
                    color: colors.info,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: TFSpacing.s12),
          Text(
            'Compara se a análise técnica já existia no momento da criação da tarefa (analise.created_at <= task.created_at).',
            style: typography.caption.copyWith(
              color: colors.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: TFSpacing.s16),
          if (totalTarefas == 0)
            SizedBox(
              height: 120,
              child: Center(
                child: Text(
                  'Nenhuma tarefa vinculada a estas notas no período',
                  style: typography.caption.copyWith(color: colors.textSecondary),
                ),
              ),
            )
          else
            Column(
              children: [
                _buildProgRow(
                  context: context,
                  label: 'Tarefas com análise prévia disponível',
                  qtd: comPrevia,
                  total: totalTarefas,
                  cor: colors.success,
                ),
                const SizedBox(height: TFSpacing.s8),
                _buildProgRow(
                  context: context,
                  label: 'Tarefas com análise posterior/atual',
                  qtd: comPosterior,
                  total: totalTarefas,
                  cor: colors.warning,
                ),
                const SizedBox(height: TFSpacing.s8),
                _buildProgRow(
                  context: context,
                  label: 'Tarefas programadas sem análise',
                  qtd: semAnalise,
                  total: totalTarefas,
                  cor: colors.textSecondary.withValues(alpha: 0.4),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildProgRow({
    required BuildContext context,
    required String label,
    required int qtd,
    required int total,
    required Color cor,
  }) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final pct = total > 0 ? (qtd / total) * 100 : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: typography.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
            Text(
              '$qtd tarefas (${pct.toStringAsFixed(1)}%)',
              style: typography.caption.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: cor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(TFRadius.r4),
          child: Container(
            height: 8,
            color: colors.surface,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: (pct / 100).clamp(0.02, 1.0),
                child: Container(color: cor),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
