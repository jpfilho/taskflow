import 'package:flutter/material.dart';

import '../../../../design_system/taskflow_design_system.dart';
import '../../../../models/task.dart';
import '../../../../widgets/task_view_dialog.dart';
import '../../domain/enums/task_apoio_enums.dart';
import '../../domain/models/task_apoio_historico.dart';
import '../../domain/models/task_apoio_situacao.dart';
import '../../domain/models/task_apoio_solicitacao.dart';
import '../task_apoio_status_mapper.dart';
import '../task_apoio_ui_controller.dart';
import '../utils/task_apoio_formatters.dart';
import 'gantt_integrado_apoios_widget.dart';
import 'task_apoio_mensagens_dialog.dart';

class TaskApoioAcaoUi {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isDestructive;

  const TaskApoioAcaoUi({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isDestructive = false,
  });
}

class _EtapaTimeline {
  final String titulo;
  final String? detalhe;
  final bool concluida;
  final bool atual;
  final bool alerta;

  const _EtapaTimeline({
    required this.titulo,
    this.detalhe,
    this.concluida = false,
    this.atual = false,
    this.alerta = false,
  });
}

/// Painel lateral (ou tela modal no Mobile) de detalhamento de uma solicitação de apoio.
/// Apresenta os 10 campos na ordem de relevância, linha do tempo fiel ao fluxo real,
/// próxima providência/responsável e abas complementares.
class TaskApoioDetailPanel extends StatefulWidget {
  final TaskApoioUiController controller;
  final TaskApoioSolicitacao solicitacao;
  final TaskApoioSituacao? situacao;
  final String usuarioAtualId;
  final String? usuarioAtualNome;
  final TaskApoioAcaoUi? acaoPrincipal;
  final List<TaskApoioAcaoUi> acoesSecundarias;
  final VoidCallback onFechar;
  final void Function(Task task)? onAbrirAtividade;

  const TaskApoioDetailPanel({
    super.key,
    required this.controller,
    required this.solicitacao,
    required this.situacao,
    required this.usuarioAtualId,
    this.usuarioAtualNome,
    this.acaoPrincipal,
    this.acoesSecundarias = const [],
    required this.onFechar,
    this.onAbrirAtividade,
  });

  @override
  State<TaskApoioDetailPanel> createState() => _TaskApoioDetailPanelState();
}

class _TaskApoioDetailPanelState extends State<TaskApoioDetailPanel> {
  int _abaComplementar = 0; // 0: Vinculadas, 1: Compatibilidade, 2: Histórico
  List<TaskApoioHistorico>? _historico;
  bool _carregandoHist = false;

  @override
  void didUpdateWidget(covariant TaskApoioDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.solicitacao.id != widget.solicitacao.id) {
      _historico = null;
      if (_abaComplementar == 2) _carregarHistorico();
    }
  }

  Future<void> _carregarHistorico() async {
    if (_carregandoHist) return;
    setState(() => _carregandoHist = true);
    try {
      final list = await widget.controller
          .buscarHistoricoSolicitacao(widget.solicitacao.id);
      if (mounted) setState(() => _historico = list);
    } catch (_) {
      if (mounted) setState(() => _historico = const []);
    } finally {
      if (mounted) setState(() => _carregandoHist = false);
    }
  }

  List<_EtapaTimeline> _construirTimelineReal() {
    final sol = widget.solicitacao;
    final sit = widget.situacao;
    final op = sit?.situacaoOperacional;

    final foiAnalisada = sol.status != TaskApoioStatus.pendente;
    final houveContraproposta = sol.status == TaskApoioStatus.contraproposta ||
        sol.contrapropostaInicio != null;
    final foiAceita = sol.status == TaskApoioStatus.aceita;
    final foiRecusada = sol.status == TaskApoioStatus.recusada;
    final foiCancelada = sol.status == TaskApoioStatus.cancelada;

    final temProgramacao = (sit?.qtdVinculosAtivos ?? 0) > 0;
    final emExecucao = op == TaskApoioSituacaoOperacional.emAndamento ||
        op == TaskApoioSituacaoOperacional.concluida;
    final concluida = op == TaskApoioSituacaoOperacional.concluida;

    final etapas = <_EtapaTimeline>[
      _EtapaTimeline(
        titulo: 'Solicitação enviada',
        detalhe: sol.createdAt != null
            ? TaskApoioFormatters.formatarPeriodoHumano(
                sol.createdAt!.toLocal(),
                sol.createdAt!.toLocal(),
              )
            : null,
        concluida: true,
      ),
      _EtapaTimeline(
        titulo: 'Em análise pela unidade prestadora',
        concluida: foiAnalisada && sol.status != TaskApoioStatus.emAnalise,
        atual: sol.status == TaskApoioStatus.emAnalise ||
            sol.status == TaskApoioStatus.pendente,
      ),
    ];

    if (foiRecusada) {
      etapas.add(
        _EtapaTimeline(
          titulo: 'Solicitação recusada',
          detalhe: sol.justificativaDecisao,
          concluida: true,
          alerta: true,
        ),
      );
      return etapas;
    }

    if (foiCancelada) {
      etapas.add(
        _EtapaTimeline(
          titulo: 'Solicitação cancelada',
          detalhe: sol.motivoCancelamento ?? sol.justificativaDecisao,
          concluida: true,
          alerta: true,
        ),
      );
      return etapas;
    }

    if (houveContraproposta && !foiAceita) {
      etapas.add(
        _EtapaTimeline(
          titulo: 'Contraproposta em negociação',
          detalhe: sol.contrapropostaInicio != null && sol.contrapropostaFim != null
              ? TaskApoioFormatters.formatarPeriodoHumano(
                  sol.contrapropostaInicio!,
                  sol.contrapropostaFim!,
                )
              : null,
          atual: true,
          alerta: true,
        ),
      );
    } else {
      etapas.add(
        _EtapaTimeline(
          titulo: houveContraproposta ? 'Contraproposta aceita' : 'Aceite registrado',
          concluida: foiAceita,
          atual: false,
        ),
      );
    }

    etapas.addAll([
      _EtapaTimeline(
        titulo: 'Programação e alocação',
        concluida: foiAceita && temProgramacao,
        atual: foiAceita && !temProgramacao,
      ),
      _EtapaTimeline(
        titulo: 'Execução em campo',
        concluida: concluida,
        atual: emExecucao && !concluida,
      ),
      _EtapaTimeline(
        titulo: 'Conclusão',
        concluida: concluida,
      ),
    ]);

    return etapas;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typo = context.tfTypography;
    final sol = widget.solicitacao;
    final sit = widget.situacao;
    final nomes = widget.controller.nomesUnidades;

    final badgeInfo = sit != null
        ? TaskApoioStatusMapper.paraSituacaoOperacional(sit.situacaoOperacional)
        : TaskApoioStatusMapper.paraStatusNegociacao(sol.status);
    final (providencia, responsavel) =
        TaskApoioFormatters.proximaProvidencia(sol, sit);

    final unidSolicitante = TaskApoioFormatters.formatarUnidade(
      regionalId: sol.regionalSolicitanteId,
      divisaoId: sol.divisaoSolicitanteId,
      segmentoId: sol.segmentoSolicitanteId,
      nomesUnidades: nomes,
    );
    final unidPrestadora = TaskApoioFormatters.formatarUnidade(
      regionalId: sol.regionalDestinoId,
      divisaoId: sol.divisaoDestinoId,
      segmentoId: sol.segmentoDestinoId,
      nomesUnidades: nomes,
    );
    final taskPrincipal = sol.taskSolicitanteId != null
        ? widget.controller.tasksConhecidas[sol.taskSolicitanteId!]
        : null;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(left: BorderSide(color: colors.borderSubtle)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabeçalho do painel lateral
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.borderSubtle)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detalhamento do Apoio',
                        style: typo.labelSmall.copyWith(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sol.descricao,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: typo.cardTitle.copyWith(color: colors.textPrimary),
                      ),
                    ],
                  ),
                ),
                TFIconButton(
                  icon: Icons.close,
                  tooltip: 'Fechar painel de detalhamento',
                  onPressed: widget.onFechar,
                ),
              ],
            ),
          ),

          // Conteúdo rolável
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 2. Situação atual + 7. Criticidade (somente ESSENCIAL / COMPLEMENTAR)
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TFStatusBadge(
                        label: badgeInfo.label,
                        severity: badgeInfo.severity,
                        icon: badgeInfo.icon,
                      ),
                      TFStatusBadge(
                        label: sol.criticidade.label,
                        severity: sol.criticidade == TaskApoioCriticidade.essencial
                            ? TFStatusSeverity.warning
                            : TFStatusSeverity.neutral,
                        compact: true,
                      ),
                      Text(
                        'Prioridade: ${sol.prioridade.label}',
                        style: typo.labelSmall.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 8. Próxima providência & 9. Responsável
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: colors.primary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Próxima providência',
                          style: typo.labelSmall.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          providencia,
                          style: typo.bodySmall.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Responsável: $responsavel',
                          style: typo.labelSmall.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 1, 3, 4, 5, 6. Bloco de Identificação
                  _infoLinha(
                    context,
                    'Atividade relacionada',
                    sol.taskSolicitanteTituloSnapshot.isNotEmpty
                        ? sol.taskSolicitanteTituloSnapshot
                        : 'Não vinculada a atividade',
                    onTap: (sol.taskSolicitanteId != null &&
                            sol.taskSolicitanteId!.isNotEmpty)
                        ? () async {
                            if (taskPrincipal != null &&
                                widget.onAbrirAtividade != null) {
                              widget.onAbrirAtividade!(taskPrincipal);
                              return;
                            }
                            final loaded = await widget.controller
                                .buscarTaskRelacionadaPorId(
                              sol.taskSolicitanteId!,
                            );
                            if (!context.mounted) return;
                            if (loaded == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Não foi possível carregar os dados desta atividade.',
                                  ),
                                ),
                              );
                              return;
                            }
                            await showDialog(
                              context: context,
                              builder: (_) => TaskViewDialog(
                                task: loaded,
                                apoioController: widget.controller,
                                onEdit: null,
                              ),
                            );
                          }
                        : null,
                  ),
                  _infoLinha(context, 'Unidade solicitante', unidSolicitante),
                  _infoLinha(context, 'Unidade prestadora', unidPrestadora),
                  _infoLinha(
                    context,
                    'Período necessário',
                    TaskApoioFormatters.formatarPeriodoHumano(
                      TaskApoioFormatters.inicioVigente(sol),
                      TaskApoioFormatters.fimVigente(sol),
                    ),
                  ),
                  if (sol.locaisAtendimento != null &&
                      sol.locaisAtendimento!.trim().isNotEmpty)
                    _infoLinha(
                      context,
                      'Local',
                      TaskApoioFormatters.formatarLocaisAtendimento(
                        sol.locaisAtendimento,
                      ),
                    ),

                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  // 10. Programação e recursos
                  Text(
                    'Programação e recursos',
                    style: typo.labelMedium.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    TaskApoioFormatters.formatarResumoCompatibilidade(sol, sit),
                    style: typo.bodySmall.copyWith(color: colors.textSecondary),
                  ),
                  if (sit != null && sit.qtdVinculosAtivos > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Cobertura temporal: ${sit.compatibilidade.percentualCobertura.toStringAsFixed(0)}%',
                      style: typo.labelSmall.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  // Linha do tempo real
                  Text(
                    'Acompanhamento do fluxo',
                    style: typo.labelMedium.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._construirTimelineReal().map(
                    (e) => _buildTimelineItem(context, e),
                  ),

                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  // Abas complementares
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ChoiceChip(
                        label: Text(
                          'Vinculadas (${sit?.qtdVinculosAtivos ?? 0})',
                        ),
                        selected: _abaComplementar == 0,
                        onSelected: (_) => setState(() => _abaComplementar = 0),
                      ),
                      ChoiceChip(
                        label: const Text('Compatibilidade'),
                        selected: _abaComplementar == 1,
                        onSelected: (_) => setState(() => _abaComplementar = 1),
                      ),
                      ChoiceChip(
                        label: const Text('Histórico'),
                        selected: _abaComplementar == 2,
                        onSelected: (_) {
                          setState(() => _abaComplementar = 2);
                          if (_historico == null) _carregarHistorico();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildConteudoComplementar(context),
                  const SizedBox(height: 12),

                  // Atalhos para Esclarecimentos e Gantt Integrado
                  Row(
                    children: [
                      Expanded(
                        child: TFButton(
                          label: 'Esclarecimentos',
                          leadingIcon: Icons.forum_outlined,
                          variant: TFButtonVariant.secondary,
                          size: TFButtonSize.small,
                          onPressed: () {
                            showDialog<void>(
                              context: context,
                              builder: (_) => TaskApoioMensagensDialog(
                                solicitacaoId: sol.id,
                                tituloSolicitacao: sol.descricao,
                                usuarioAtualId: widget.usuarioAtualId,
                                usuarioAtualNome:
                                    widget.usuarioAtualNome ?? 'Usuário',
                                modoDemonstracao:
                                    widget.controller.isModoDemonstracao,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TFButton(
                          label: 'Gantt integrado',
                          leadingIcon: Icons.view_timeline_outlined,
                          variant: TFButtonVariant.secondary,
                          size: TFButtonSize.small,
                          onPressed: () {
                            final t = taskPrincipal ??
                                Task(
                                  id: sol.taskSolicitanteId ?? sol.id,
                                  tarefa: sol.taskSolicitanteTituloSnapshot.isNotEmpty
                                      ? sol.taskSolicitanteTituloSnapshot
                                      : sol.descricao,
                                  dataInicio: TaskApoioFormatters.inicioVigente(sol),
                                  dataFim: TaskApoioFormatters.fimVigente(sol),
                                  status: 'PROG',
                                  tipo: 'Manutenção',
                                  coordenador: '',
                                  regional: '',
                                  divisao: '',
                                );
                            GanttIntegradoDialog.abrir(
                              context,
                              controller: widget.controller,
                              atividadePrincipal: t,
                              usuarioAtualId: widget.usuarioAtualId,
                              usuarioAtualNome: widget.usuarioAtualNome,
                              onAbrirAtividade: widget.onAbrirAtividade,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Rodapé com ação principal contextual + menu secundário
          if (widget.acaoPrincipal != null || widget.acoesSecundarias.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colors.borderSubtle)),
              ),
              child: Row(
                children: [
                  if (widget.acaoPrincipal != null)
                    Expanded(
                      child: TFButton(
                        label: widget.acaoPrincipal!.label,
                        leadingIcon: widget.acaoPrincipal!.icon,
                        variant: TFButtonVariant.primary,
                        onPressed: widget.acaoPrincipal!.onPressed,
                      ),
                    ),
                  if (widget.acoesSecundarias.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    PopupMenuButton<int>(
                      tooltip: 'Mais ações',
                      icon: const Icon(Icons.more_vert),
                      onSelected: (idx) =>
                          widget.acoesSecundarias[idx].onPressed(),
                      itemBuilder: (_) => [
                        for (var i = 0; i < widget.acoesSecundarias.length; i++)
                          PopupMenuItem<int>(
                            value: i,
                            child: Row(
                              children: [
                                Icon(
                                  widget.acoesSecundarias[i].icon,
                                  size: 18,
                                  color: widget.acoesSecundarias[i].isDestructive
                                      ? colors.danger
                                      : colors.textPrimary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  widget.acoesSecundarias[i].label,
                                  style: TextStyle(
                                    color:
                                        widget.acoesSecundarias[i].isDestructive
                                            ? colors.danger
                                            : colors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoLinha(
    BuildContext context,
    String label,
    String valor, {
    VoidCallback? onTap,
  }) {
    final colors = context.tfColors;
    final typo = context.tfTypography;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: typo.labelSmall.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 2),
          onTap != null
              ? InkWell(
                  onTap: onTap,
                  child: Text(
                    valor,
                    style: typo.bodySmall.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                )
              : Text(
                  valor,
                  style: typo.bodySmall.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(BuildContext context, _EtapaTimeline etapa) {
    final colors = context.tfColors;
    final typo = context.tfTypography;
    final Color cor;
    final IconData icon;
    if (etapa.alerta) {
      cor = colors.warning;
      icon = Icons.error_outline;
    } else if (etapa.concluida) {
      cor = colors.success;
      icon = Icons.check_circle;
    } else if (etapa.atual) {
      cor = colors.primary;
      icon = Icons.radio_button_checked;
    } else {
      cor = colors.textSecondary.withValues(alpha: 0.5);
      icon = Icons.radio_button_unchecked;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: cor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  etapa.titulo,
                  style: typo.bodySmall.copyWith(
                    color: etapa.concluida || etapa.atual || etapa.alerta
                        ? colors.textPrimary
                        : colors.textSecondary,
                    fontWeight: etapa.atual || etapa.alerta
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
                if (etapa.detalhe != null && etapa.detalhe!.trim().isNotEmpty)
                  Text(
                    etapa.detalhe!,
                    style: typo.labelSmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConteudoComplementar(BuildContext context) {
    final colors = context.tfColors;
    final typo = context.tfTypography;
    final sit = widget.situacao;

    if (_abaComplementar == 0) {
      final qtdVinc = sit?.qtdVinculosAtivos ?? 0;
      if (qtdVinc == 0) {
        return Text(
          'Nenhuma atividade de apoio vinculada ainda.',
          style: typo.bodySmall.copyWith(color: colors.textSecondary),
        );
      }
      return TFCard(
        padding: const EdgeInsets.all(10),
        child: Text(
          '$qtdVinc atividade(s) de apoio vinculada(s) e confirmada(s). Consulte os detalhes no Gantt integrado.',
          style: typo.bodySmall.copyWith(color: colors.textPrimary),
        ),
      );
    }

    if (_abaComplementar == 1) {
      if (sit == null) {
        return Text(
          'Compatibilidade ainda não calculada.',
          style: typo.bodySmall.copyWith(color: colors.textSecondary),
        );
      }
      final comp = sit.compatibilidade;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cobertura temporal: ${comp.percentualCobertura.toStringAsFixed(0)}%',
            style: typo.bodySmall.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            TaskApoioFormatters.formatarResumoCompatibilidade(
              widget.solicitacao,
              sit,
            ),
            style: typo.bodySmall.copyWith(color: colors.textSecondary),
          ),
        ],
      );
    }

    if (_carregandoHist) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final hist = _historico ?? const [];
    if (hist.isEmpty) {
      return Text(
        'Sem registros de histórico disponíveis.',
        style: typo.bodySmall.copyWith(color: colors.textSecondary),
      );
    }
    return Column(
      children: hist
          .take(8)
          .map(
            (h) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.history, size: 14, color: colors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${h.evento} — ${h.usuarioNome ?? "Sistema"}${h.justificativa != null ? ": ${h.justificativa}" : ""}',
                      style: typo.labelSmall.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
