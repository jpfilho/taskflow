import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../design_system/taskflow_design_system.dart';
import '../../../../models/task.dart';
import '../../domain/models/task_apoio_gerencial.dart';
import '../../domain/models/task_apoio_historico.dart';
import '../../domain/models/task_apoio_situacao.dart';
import '../../domain/models/task_apoio_solicitacao.dart';
import '../../services/task_apoio_export_service.dart';
import '../../services/task_apoio_gerencial_calculator.dart';
import '../task_apoio_ui_controller.dart';
import '../widgets/gantt_integrado_apoios_widget.dart';

/// Painel Gerencial Consolidado, Indicadores de Desempenho entre Unidades,
/// Distribuição de Demandas e Visão de Reunião Semanal de Programação (Fase 7).
class ApoiosGerencialDashboardView extends StatefulWidget {
  final TaskApoioUiController controller;
  final List<TaskApoioSolicitacao> solicitacoes;
  final Map<String, TaskApoioSituacao> situacoes;
  final String usuarioAtualId;
  final String? usuarioAtualNome;
  final String? divisaoAtualId;
  final void Function(String filtroChave)? onSelecionarIndicador;
  final void Function(Task task)? onAbrirAtividade;

  const ApoiosGerencialDashboardView({
    super.key,
    required this.controller,
    required this.solicitacoes,
    required this.situacoes,
    required this.usuarioAtualId,
    this.usuarioAtualNome,
    this.divisaoAtualId,
    this.onSelecionarIndicador,
    this.onAbrirAtividade,
  });

  @override
  State<ApoiosGerencialDashboardView> createState() =>
      _ApoiosGerencialDashboardViewState();
}

class _ApoiosGerencialDashboardViewState
    extends State<ApoiosGerencialDashboardView> {
  final _fmtData = DateFormat('dd/MM HH:mm');
  TaskApoioGerencialPerspectiva _perspectiva =
      TaskApoioGerencialPerspectiva.consolidada;
  final Map<String, List<TaskApoioHistorico>> _historicos = {};

  void _exportarExcel(TaskApoioGerencialIndicadores ind) {
    final tiposMap = {
      for (final t in widget.controller.tiposAtivos) t.id: t.nome,
    };
    final bytes = TaskApoioExportService.gerarRelatorioExcelBytes(
      solicitacoesAutorizadas: widget.solicitacoes,
      situacoesPorSolicitacao: widget.situacoes,
      indicadores: ind,
      nomesUnidades: widget.controller.nomesUnidades,
      nomesTipos: tiposMap,
      filtrosAplicados: _perspectiva.label,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Relatório Excel (.xlsx) gerado com sucesso (${(bytes.length / 1024).toStringAsFixed(1)} KB, 3 planilhas).',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typo = context.tfTypography;
    final tiposMap = {
      for (final t in widget.controller.tiposAtivos) t.id: t.nome,
    };

    final ind = TaskApoioGerencialCalculator.calcular(
      solicitacoes: widget.solicitacoes,
      situacoesPorSolicitacao: widget.situacoes,
      tasksPorId: widget.controller.tasksConhecidas,
      historicoPorSolicitacao: _historicos,
      nomesUnidades: widget.controller.nomesUnidades,
      nomesTipos: tiposMap,
      divisaoAtualId: widget.divisaoAtualId,
      perspectiva: _perspectiva,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Cabeçalho com perspectiva + exportar Excel
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<TaskApoioGerencialPerspectiva>(
              segments: TaskApoioGerencialPerspectiva.values
                  .map((p) => ButtonSegment(value: p, label: Text(p.label)))
                  .toList(),
              selected: {_perspectiva},
              onSelectionChanged: (v) =>
                  setState(() => _perspectiva = v.first),
            ),
            TFButton(
              label: 'Exportar Excel (.xlsx)',
              size: TFButtonSize.small,
              variant: TFButtonVariant.secondary,
              leadingIcon: Icons.download_outlined,
              onPressed: () => _exportarExcel(ind),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Indicadores gerenciais obrigatórios (clicáveis)
        Text(
          'Indicadores Operacionais (clique para detalhar)',
          style: typo.cardTitle.copyWith(color: colors.textPrimary),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _kpiTile(colors, typo, 'Total solicitações',
                '${ind.totalSolicitacoes}', 'solicitações', colors.primary, 'todos'),
            _kpiTile(colors, typo, 'Aguardando resposta',
                '${ind.aguardandoResposta}', 'solicitações', colors.warning, 'pendentes'),
            _kpiTile(colors, typo, 'Em negociação', '${ind.emNegociacao}',
                'contrapropostas', colors.info, 'contrapropostas'),
            _kpiTile(colors, typo, 'Aceitas s/ prog.',
                '${ind.aceitasSemProgramacao}', 'solicitações', colors.warning, 'aceitosSemProg'),
            _kpiTile(colors, typo, 'Parciais', '${ind.parcialmenteProgramados}',
                'solicitações', colors.warning, 'parciais'),
            _kpiTile(colors, typo, 'Programados compatíveis',
                '${ind.programadosCompativeis}', 'solicitações', colors.success, 'todos'),
            _kpiTile(colors, typo, 'Essenciais em risco',
                '${ind.essenciaisEmRisco}', 'solicitações', colors.danger, 'emRisco'),
            _kpiTile(colors, typo, 'Recursos pendentes',
                '${ind.recursosPendentes}', 'solicitações', colors.warning, 'recPendentes'),
            _kpiTile(colors, typo, 'Reconfirmação pendente',
                '${ind.reconfirmacaoPendente}', 'solicitações', colors.warning, 'emRisco'),
            _kpiTile(colors, typo, 'Prazo ultrapassado',
                '${ind.prazoUltrapassado}', 'solicitações', colors.danger, 'pendentes'),
            _kpiTile(colors, typo, 'Atividades afetadas',
                '${ind.atividadesPrincipaisAfetadas}', 'atividades', colors.danger, 'emRisco'),
            _kpiTile(colors, typo, 'Concluídos', '${ind.concluidos}',
                'solicitações', colors.success, 'todos'),
          ],
        ),
        const SizedBox(height: 20),

        // Indicadores de desempenho entre unidades
        Text(
          'Desempenho entre Unidades',
          style: typo.cardTitle.copyWith(color: colors.textPrimary),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _metricCard(
              colors,
              typo,
              'Cobertura temporal média',
              ind.coberturaTemporalMediaPercent != null
                  ? '${ind.coberturaTemporalMediaPercent!.toStringAsFixed(1)}%'
                  : 'Sem dados suficientes',
            ),
            _metricCard(
              colors,
              typo,
              'Tempo médio 1ª resposta',
              ind.tempoMedioPrimeiraRespostaHoras != null
                  ? '${ind.tempoMedioPrimeiraRespostaHoras!.toStringAsFixed(1)} h'
                  : 'Sem dados suficientes',
            ),
            _metricCard(
              colors,
              typo,
              'Taxa de resposta no prazo',
              ind.taxaRespostaNoPrazoPercent != null
                  ? '${ind.taxaRespostaNoPrazoPercent!.toStringAsFixed(1)}%'
                  : 'Sem dados suficientes',
            ),
            _metricCard(
              colors,
              typo,
              'Taxa de atendimento no prazo',
              ind.taxaAtendimentoNoPrazoPercent != null
                  ? '${ind.taxaAtendimentoNoPrazoPercent!.toStringAsFixed(1)}%'
                  : 'Sem dados suficientes',
            ),
            _metricCard(
              colors,
              typo,
              'Reprogramações registradas',
              '${ind.totalReprogramacoes}',
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Distribuição da demanda por Unidade e Tipo
        LayoutBuilder(
          builder: (_, constraints) {
            final col2 = constraints.maxWidth > 760;
            final cardUnidades = _buildDistribuicaoCard(
              colors,
              typo,
              'Distribuição por Unidade',
              ind.distribuicaoPorUnidade,
            );
            final cardTipos = _buildDistribuicaoCard(
              colors,
              typo,
              'Demanda por Tipo de Apoio',
              ind.distribuicaoPorTipo,
            );
            if (col2) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: cardUnidades),
                  const SizedBox(width: 12),
                  Expanded(child: cardTipos),
                ],
              );
            }
            return Column(
              children: [
                cardUnidades,
                const SizedBox(height: 12),
                cardTipos,
              ],
            );
          },
        ),
        const SizedBox(height: 20),

        // Visão de Reunião Semanal de Programação
        Text(
          'Reunião Semanal de Programação — Pendências e Providências (${ind.itensReuniaoSemanal.length})',
          style: typo.cardTitle.copyWith(color: colors.textPrimary),
        ),
        const SizedBox(height: 8),
        if (ind.itensReuniaoSemanal.isEmpty)
          TFCard(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Nenhuma pendência operacional aberta para a perspectiva selecionada.',
              style: typo.bodySmall.copyWith(color: colors.textSecondary),
            ),
          )
        else
          ...ind.itensReuniaoSemanal.map((item) {
            final s = item.solicitacao;
            final taskPrincipal = s.taskSolicitanteId != null
                ? widget.controller.tasksConhecidas[s.taskSolicitanteId!]
                : null;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TFCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${s.taskSolicitanteTituloSnapshot} → ${s.descricao}',
                            style: typo.labelMedium.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (taskPrincipal != null)
                          TextButton.icon(
                            onPressed: () => GanttIntegradoDialog.abrir(
                              context,
                              controller: widget.controller,
                              atividadePrincipal: taskPrincipal,
                              usuarioAtualId: widget.usuarioAtualId,
                              usuarioAtualNome: widget.usuarioAtualNome,
                              onAbrirAtividade: widget.onAbrirAtividade,
                            ),
                            icon: const Icon(Icons.view_timeline_outlined,
                                size: 16),
                            label: const Text('Gantt Integrado'),
                          ),
                      ],
                    ),
                    Text(
                      'Responsável: ${item.unidadeResponsavelNome} • Necessário: ${_fmtData.format(s.dataInicioSolicitada)}',
                      style: typo.labelSmall
                          .copyWith(color: colors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Providência: ${item.providenciaSugerida}',
                      style: typo.bodySmall.copyWith(color: colors.warning),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _kpiTile(
    TFSemanticColors colors,
    TFTypography typo,
    String titulo,
    String valor,
    String unidade,
    Color cor,
    String filtroChave,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: widget.onSelecionarIndicador == null
          ? null
          : () => widget.onSelecionarIndicador!(filtroChave),
      child: Container(
        width: 170,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cor.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              valor,
              style: typo.sectionTitle.copyWith(color: cor),
            ),
            const SizedBox(height: 2),
            Text(
              titulo,
              style: typo.labelSmall.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              unidade,
              style: typo.labelSmall.copyWith(
                color: colors.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricCard(
    TFSemanticColors colors,
    TFTypography typo,
    String label,
    String valor,
  ) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: typo.labelSmall.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            valor,
            style: typo.cardTitle.copyWith(color: colors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildDistribuicaoCard(
    TFSemanticColors colors,
    TFTypography typo,
    String titulo,
    List<TaskApoioDistribuicaoItem> itens,
  ) {
    return TFCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: typo.labelMedium.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          if (itens.isEmpty)
            Text(
              'Sem dados para distribuição.',
              style: typo.bodySmall.copyWith(color: colors.textSecondary),
            )
          else
            ...itens.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.nome,
                        style: typo.bodySmall.copyWith(color: colors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${item.totalSolicitacoes} sol. (${item.pendentesOuRisco} risco/pend.)',
                      style: typo.labelSmall
                          .copyWith(color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
