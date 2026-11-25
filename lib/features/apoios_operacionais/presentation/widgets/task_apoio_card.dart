import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../design_system/taskflow_design_system.dart';
import '../../../../models/task.dart';
import '../../domain/enums/task_apoio_enums.dart';
import '../../domain/models/task_apoio_historico.dart';
import '../../domain/models/task_apoio_situacao.dart';
import '../../domain/models/task_apoio_solicitacao.dart';
import '../../domain/rules/task_apoio_state_machine.dart';
import '../task_apoio_status_mapper.dart';
import '../utils/task_apoio_formatters.dart';

/// Cartão de acompanhamento de um apoio operacional vinculado a uma atividade.
/// Separa visualmente a resposta à solicitação da programação efetiva do recurso,
/// oferece acesso direto às tarefas vinculadas e exibe histórico em linha do tempo.
class TaskApoioCard extends StatefulWidget {
  final TaskApoioSolicitacao solicitacao;
  final TaskApoioSituacao situacao;
  final String nomeUnidadeDestino;
  final String? nomeTipoApoio;
  final String? nomeResponsavel;
  final List<Task> tarefasVinculadas;
  final TaskApoioPapelAtor papelAtor;
  final bool acoesHabilitadas;
  final bool processando;
  final Future<List<TaskApoioHistorico>> Function()? onCarregarHistorico;
  final Future<void> Function(TaskApoioAcao acao)? onExecutarAcao;
  final VoidCallback? onCriarAtividadeApoio;
  final VoidCallback? onVincularExistente;
  final VoidCallback? onAbrirMensagens;
  final void Function(Task task)? onAbrirTarefa;

  const TaskApoioCard({
    super.key,
    required this.solicitacao,
    required this.situacao,
    required this.nomeUnidadeDestino,
    this.nomeTipoApoio,
    this.nomeResponsavel,
    this.tarefasVinculadas = const [],
    this.papelAtor = TaskApoioPapelAtor.solicitante,
    this.acoesHabilitadas = true,
    this.processando = false,
    this.onCarregarHistorico,
    this.onExecutarAcao,
    this.onCriarAtividadeApoio,
    this.onVincularExistente,
    this.onAbrirMensagens,
    this.onAbrirTarefa,
  });

  @override
  State<TaskApoioCard> createState() => _TaskApoioCardState();
}

class _TaskApoioCardState extends State<TaskApoioCard> {
  final _fmtDataHora = DateFormat('dd/MM/yyyy HH:mm');
  bool _expandido = false;
  bool _carregandoHist = false;
  List<TaskApoioHistorico>? _historico;

  Future<void> _toggleExpandir() async {
    final novo = !_expandido;
    setState(() => _expandido = novo);
    if (novo && _historico == null && widget.onCarregarHistorico != null) {
      setState(() => _carregandoHist = true);
      try {
        final h = await widget.onCarregarHistorico!();
        if (mounted) setState(() => _historico = h);
      } finally {
        if (mounted) setState(() => _carregandoHist = false);
      }
    }
  }

  String _responsavelExibicao(TaskApoioSolicitacao sol) {
    final cand = widget.nomeResponsavel;
    if (cand != null && cand.trim().isNotEmpty && !TaskApoioFormatters.isUuid(cand)) {
      return cand.trim();
    }
    return widget.nomeUnidadeDestino;
  }

  TFStatusSeverity _severidadeStatusSolicitacao(TaskApoioStatus status) {
    switch (status) {
      case TaskApoioStatus.aceita:
        return TFStatusSeverity.success;
      case TaskApoioStatus.recusada:
        return TFStatusSeverity.danger;
      case TaskApoioStatus.cancelada:
        return TFStatusSeverity.neutral;
      case TaskApoioStatus.contraproposta:
        return TFStatusSeverity.info;
      case TaskApoioStatus.pendente:
      case TaskApoioStatus.emAnalise:
      case TaskApoioStatus.desconhecido:
        return TFStatusSeverity.warning;
    }
  }

  String _formatarEventoHistorico(String evento) {
    final e = evento.trim().toUpperCase();
    switch (e) {
      case 'SOLICITACAO_CRIADA':
      case 'CRIADA':
        return 'Solicitação registrada';
      case 'ENCAMINHADA_ANALISE':
      case 'EM_ANALISE':
        return 'Encaminhada para análise';
      case 'SOLICITACAO_ACEITA':
      case 'ACEITA':
        return 'Solicitação aceita';
      case 'SOLICITACAO_RECUSADA':
      case 'RECUSADA':
        return 'Solicitação recusada';
      case 'CONTRAPROPOSTA_ENVIADA':
      case 'CONTRAPROPOSTA':
        return 'Contraproposta de período enviada';
      case 'CONTRAPROPOSTA_ACEITA':
        return 'Contraproposta aceita';
      case 'CONTRAPROPOSTA_RECUSADA':
        return 'Contraproposta recusada';
      case 'SOLICITACAO_CANCELADA':
      case 'CANCELADA':
        return 'Solicitação cancelada';
      case 'VINCULO_CRIADO':
        return 'Atividade de apoio vinculada';
      case 'VINCULO_DESATIVADO':
        return 'Vínculo desativado';
      case 'VINCULO_CONFIRMADO':
        return 'Vínculo confirmado';
      default:
        return evento.replaceAll('_', ' ').toLowerCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typo = context.tfTypography;
    final sol = widget.solicitacao;
    final sit = widget.situacao;
    final compat = sit.compatibilidade;
    final badgeInfo =
        TaskApoioStatusMapper.paraSituacaoOperacional(sit.situacaoOperacional);
    final respSeverity = _severidadeStatusSolicitacao(sol.status);
    final syncInfo = TaskApoioStatusMapper.paraSyncStatus(sol.syncStatus);

    final acoes = widget.acoesHabilitadas
        ? TaskApoioStateMachine.acoesDisponiveis(
            statusAtual: sol.status,
            papel: widget.papelAtor,
          )
        : const <TaskApoioAcao>[];

    final periodoNecessario = TaskApoioFormatters.formatarPeriodoHumano(
      TaskApoioFormatters.inicioVigente(sol),
      TaskApoioFormatters.fimVigente(sol),
    );
    final periodoProgramado =
        sit.menorInicioProgramado != null && sit.maiorFimProgramado != null
            ? '${TaskApoioFormatters.formatarPeriodoHumano(sit.menorInicioProgramado!.toLocal(), sit.maiorFimProgramado!.toLocal())} (${compat.percentualCobertura.toStringAsFixed(0)}%)'
            : null;

    return TFCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho: recurso + categoria + unidade + criticidade + situação
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  borderRadius: TFRadius.borderRadiusSm,
                ),
                child: Icon(
                  Icons.handshake_outlined,
                  size: 18,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sol.descricao,
                      style: typo.labelMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (widget.nomeTipoApoio != null &&
                            widget.nomeTipoApoio!.isNotEmpty)
                          Text(
                            widget.nomeTipoApoio!,
                            style: typo.bodySmall.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        Text(
                          widget.nomeUnidadeDestino,
                          style: typo.bodySmall.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  TFStatusBadge(
                    label: sol.criticidade.label,
                    severity: sol.criticidade == TaskApoioCriticidade.essencial
                        ? TFStatusSeverity.warning
                        : TFStatusSeverity.neutral,
                    compact: true,
                  ),
                  if (sol.syncStatus != TaskApoioSyncStatus.confirmadoServidor)
                    TFStatusBadge(
                      label: syncInfo.label,
                      severity: syncInfo.severity,
                      icon: syncInfo.icon,
                      compact: true,
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Blocos separados: Resposta à Solicitação vs Programação Efetiva
          Builder(
            builder: (context) {
              final empilhar = MediaQuery.sizeOf(context).width < 680;
              final blocoResposta = _buildBlocoInfo(
                context,
                titulo: 'Resposta à solicitação',
                badge: TFStatusBadge(
                  label: sol.status.label,
                  severity: respSeverity,
                  compact: true,
                ),
                linhas: [
                  ('Responsável', _responsavelExibicao(sol)),
                  ('Período necessário', periodoNecessario),
                ],
              );

              final blocoProgramacao = _buildBlocoInfo(
                context,
                titulo: 'Programação do recurso',
                badge: TFStatusBadge(
                  label: badgeInfo.label,
                  severity: badgeInfo.severity,
                  icon: badgeInfo.icon,
                  compact: true,
                ),
                linhas: [
                  if (periodoProgramado != null)
                    ('Programado', periodoProgramado)
                  else
                    (
                      'Situação',
                      TaskApoioFormatters.formatarResumoCompatibilidade(sol, sit),
                    ),
                ],
                extra: widget.tarefasVinculadas.isNotEmpty
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 6),
                          for (final t in widget.tarefasVinculadas)
                            _buildTarefaVinculadaItem(context, t),
                        ],
                      )
                    : null,
              );

              if (empilhar) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    blocoResposta,
                    const SizedBox(height: 8),
                    blocoProgramacao,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: blocoResposta),
                  const SizedBox(width: 10),
                  Expanded(child: blocoProgramacao),
                ],
              );
            },
          ),

          // Pendências objetivas (lacunas, recursos, compartilhamento)
          if (compat.lacunas.isNotEmpty ||
              compat.pendenciasRecursos.isNotEmpty ||
              compat.alertasCompartilhamento.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final lacuna in compat.lacunas)
              _buildAlertaLinha(
                context,
                Icons.timelapse_rounded,
                colors.warning,
                'Apoio necessário de ${TaskApoioFormatters.formatarPeriodoHumano(lacuna.inicio.toLocal(), lacuna.fim.toLocal())} ainda não programado.',
              ),
            for (final pend in compat.pendenciasRecursos)
              _buildAlertaLinha(
                context,
                Icons.build_circle_outlined,
                compat.statusRecursos ==
                        TaskApoioStatusCompatibilidadeRecurso.incompativel
                    ? colors.danger
                    : colors.info,
                pend,
              ),
            for (final alerta in compat.alertasCompartilhamento)
              _buildAlertaLinha(
                context,
                Icons.warning_amber_rounded,
                colors.danger,
                alerta,
              ),
          ],

          // Botões de ação contextuais
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final acao in acoes)
                TFButton(
                  label: acao.label,
                  size: TFButtonSize.small,
                  variant: acao == TaskApoioAcao.recusar ||
                          acao == TaskApoioAcao.cancelar ||
                          acao == TaskApoioAcao.recusarContraproposta
                      ? TFButtonVariant.danger
                      : (acao == TaskApoioAcao.aceitar ||
                              acao == TaskApoioAcao.aceitarContraproposta
                          ? TFButtonVariant.primary
                          : TFButtonVariant.secondary),
                  loading: widget.processando,
                  onPressed: widget.processando || widget.onExecutarAcao == null
                      ? null
                      : () => widget.onExecutarAcao!(acao),
                ),
              if (sol.status == TaskApoioStatus.aceita &&
                  sit.qtdVinculosAtivos == 0 &&
                  widget.acoesHabilitadas &&
                  widget.onCriarAtividadeApoio != null)
                TFButton(
                  label: 'Criar atividade de apoio',
                  size: TFButtonSize.small,
                  variant: TFButtonVariant.secondary,
                  leadingIcon: Icons.add_task_rounded,
                  onPressed: widget.onCriarAtividadeApoio,
                ),
              if (sol.status.isAtiva &&
                  widget.acoesHabilitadas &&
                  widget.onVincularExistente != null)
                TFButton(
                  label: 'Vincular existente',
                  size: TFButtonSize.small,
                  variant: TFButtonVariant.tertiary,
                  leadingIcon: Icons.link_rounded,
                  onPressed: widget.onVincularExistente,
                ),
              if (widget.onAbrirMensagens != null)
                TextButton.icon(
                  onPressed: widget.onAbrirMensagens,
                  icon: const Icon(Icons.chat_bubble_outline, size: 16),
                  label: const Text('Esclarecimentos'),
                ),
              TextButton.icon(
                onPressed: _toggleExpandir,
                icon: Icon(
                  _expandido ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                ),
                label: Text(_expandido ? 'Ocultar linha do tempo' : 'Linha do tempo e detalhes'),
              ),
            ],
          ),

          // Linha do tempo cronológica + observações/contraproposta
          if (_expandido) ...[
            const Divider(height: 18),
            if (sol.observacoes != null && sol.observacoes!.trim().isNotEmpty) ...[
              Text(
                'Observações: ${sol.observacoes}',
                style: typo.bodySmall.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: 8),
            ],
            if (sol.contrapropostaInicio != null &&
                sol.contrapropostaFim != null) ...[
              _buildAlertaLinha(
                context,
                Icons.swap_horiz_rounded,
                colors.info,
                'Contraproposta: ${TaskApoioFormatters.formatarPeriodoHumano(sol.contrapropostaInicio!.toLocal(), sol.contrapropostaFim!.toLocal())}'
                '${sol.contrapropostaJustificativa != null && sol.contrapropostaJustificativa!.isNotEmpty ? ' — ${sol.contrapropostaJustificativa}' : ''}',
              ),
              const SizedBox(height: 8),
            ],
            Text(
              'Linha do tempo do apoio',
              style: typo.labelSmall.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            if (_carregandoHist)
              const LinearProgressIndicator()
            else if (_historico == null || _historico!.isEmpty)
              Text(
                'Nenhum evento registrado até o momento.',
                style: typo.bodySmall.copyWith(color: colors.textSecondary),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < _historico!.length; i++)
                    _buildTimelineItem(
                      context,
                      _historico![i],
                      isLast: i == _historico!.length - 1,
                    ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildBlocoInfo(
    BuildContext context, {
    required String titulo,
    required TFStatusBadge badge,
    required List<(String, String)> linhas,
    Widget? extra,
  }) {
    final colors = context.tfColors;
    final typo = context.tfTypography;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surfaceSecondary.withValues(alpha: 0.45),
        borderRadius: TFRadius.borderRadiusSm,
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  titulo,
                  style: typo.labelSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.textSecondary,
                  ),
                ),
              ),
              badge,
            ],
          ),
          const SizedBox(height: 6),
          for (final l in linhas)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: RichText(
                text: TextSpan(
                  style: typo.bodySmall.copyWith(color: colors.textPrimary),
                  children: [
                    TextSpan(
                      text: '${l.$1}: ',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: l.$2),
                  ],
                ),
              ),
            ),
          if (extra != null) extra,
        ],
      ),
    );
  }

  Widget _buildTarefaVinculadaItem(BuildContext context, Task t) {
    final colors = context.tfColors;
    final typo = context.tfTypography;
    final clicavel = widget.onAbrirTarefa != null;
    final periodo = TaskApoioFormatters.formatarPeriodoHumano(
      t.dataInicio.toLocal(),
      t.dataFim.toLocal(),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: InkWell(
        onTap: clicavel ? () => widget.onAbrirTarefa!(t) : null,
        borderRadius: TFRadius.borderRadiusSm,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: TFRadius.borderRadiusSm,
            border: Border.all(
              color: clicavel
                  ? colors.primary.withValues(alpha: 0.35)
                  : colors.borderSubtle,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.task_alt_rounded,
                size: 15,
                color: colors.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.tarefa,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: typo.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: clicavel ? colors.primary : colors.textPrimary,
                      ),
                    ),
                    Text(
                      'Status: ${t.status} • $periodo',
                      style: typo.caption.copyWith(color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (clicavel)
                Icon(
                  Icons.open_in_new_rounded,
                  size: 14,
                  color: colors.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineItem(
    BuildContext context,
    TaskApoioHistorico h, {
    required bool isLast,
  }) {
    final colors = context.tfColors;
    final typo = context.tfTypography;
    final resp = (h.usuarioNome != null &&
            h.usuarioNome!.trim().isNotEmpty &&
            !TaskApoioFormatters.isUuid(h.usuarioNome))
        ? h.usuarioNome!.trim()
        : null;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 20,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: colors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: colors.borderSubtle,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _formatarEventoHistorico(h.evento),
                          style: typo.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        _fmtDataHora.format(h.createdAt.toLocal()),
                        style: typo.caption.copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ),
                  if (resp != null)
                    Text(
                      'Responsável: $resp',
                      style: typo.caption.copyWith(color: colors.textSecondary),
                    ),
                  if (h.justificativa != null &&
                      h.justificativa!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '"${h.justificativa!.trim()}"',
                        style: typo.bodySmall.copyWith(
                          color: colors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertaLinha(
    BuildContext context,
    IconData icon,
    Color color,
    String texto,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              texto,
              style: context.tfTypography.bodySmall.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
