import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../design_system/taskflow_design_system.dart';
import '../../../apoios_operacionais/domain/enums/task_apoio_enums.dart';
import '../../../apoios_operacionais/domain/models/task_apoio_solicitacao.dart';
import '../../../apoios_operacionais/presentation/utils/task_apoio_formatters.dart';
import '../../domain/models/notificacao_interna.dart';

/// Cartão padronizado de Notificação Operacional.
/// Reaproveita dados estruturados de [TaskApoioSolicitacao] quando disponível
/// e limpa textos técnicos/redundantes da mensagem bruta.
class NotificacaoCard extends StatelessWidget {
  final NotificacaoInterna notificacao;
  final TaskApoioSolicitacao? solicitacao;
  final Map<String, String> nomesUnidades;
  final bool? isSolicitante;
  final bool? isPrestadora;
  final VoidCallback? onAbrir;
  final VoidCallback? onMarcarLida;

  const NotificacaoCard({
    super.key,
    required this.notificacao,
    this.solicitacao,
    this.nomesUnidades = const {},
    this.isSolicitante,
    this.isPrestadora,
    this.onAbrir,
    this.onMarcarLida,
  });

  static final DateFormat _fmt = DateFormat('dd/MM HH:mm');
  static final RegExp _uuidRegex = RegExp(
    r'\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b',
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typo = context.tfTypography;
    final sevColor = _corSeveridade(colors, notificacao.severidade);
    final parsed = _extrairDados(notificacao, solicitacao, nomesUnidades);
    final situacaoInfo = _resolverSituacao(colors, notificacao, solicitacao);
    final papelInfo = _resolverPapel(colors, isSolicitante, isPrestadora);

    final podeAbrir = onAbrir != null &&
        (notificacao.solicitacaoId != null || notificacao.taskId != null);

    return Material(
      color: notificacao.lida
          ? colors.surface
          : colors.primary.withValues(alpha: 0.045),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: podeAbrir ? onAbrir : null,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: notificacao.lida
                  ? colors.borderSubtle
                  : sevColor.withValues(alpha: 0.45),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    width: 4,
                    color: notificacao.lida ? colors.borderSubtle : sevColor,
                  ),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                          _buildHeader(colors, typo, sevColor),
                          const SizedBox(height: 6),
                          Text(
                            parsed.tituloObjeto,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: typo.bodyMedium.copyWith(
                              color: colors.textPrimary,
                              fontWeight: notificacao.lida
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                            ),
                          ),
                          if (parsed.descricaoCurta.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              parsed.descricaoCurta,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: typo.bodySmall.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                          if (parsed.periodo != null ||
                              parsed.criticidade != null ||
                              situacaoInfo != null ||
                              papelInfo != null ||
                              parsed.fluxoUnidades != null) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                if (papelInfo != null)
                                  _MetaBadge(
                                    icon: papelInfo.icon,
                                    label: papelInfo.label,
                                    color: papelInfo.color,
                                  ),
                                if (situacaoInfo != null)
                                  _MetaBadge(
                                    icon: situacaoInfo.icon,
                                    label: situacaoInfo.label,
                                    color: situacaoInfo.color,
                                  ),
                                if (parsed.periodo != null)
                                  _MetaBadge(
                                    icon: Icons.date_range_outlined,
                                    label: parsed.periodo!,
                                    color: colors.textSecondary,
                                  ),
                                if (parsed.criticidade != null)
                                  _MetaBadge(
                                    icon: Icons.priority_high_rounded,
                                    label: 'Criticidade: ${parsed.criticidade}',
                                    color: _corCriticidade(
                                      colors,
                                      parsed.criticidade!,
                                    ),
                                  ),
                                if (parsed.fluxoUnidades != null)
                                  _MetaBadge(
                                    icon: Icons.swap_horiz_rounded,
                                    label: parsed.fluxoUnidades!,
                                    color: colors.textSecondary,
                                  ),
                              ],
                            ),
                          ],
                          if (podeAbrir || (!notificacao.lida && onMarcarLida != null)) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Wrap(
                                alignment: WrapAlignment.end,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  if (!notificacao.lida && onMarcarLida != null)
                                    TextButton.icon(
                                      onPressed: onMarcarLida,
                                      style: TextButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.done_rounded,
                                        size: 16,
                                      ),
                                      label: const Text('Marcar como lida'),
                                    ),
                                  if (podeAbrir)
                                    FilledButton.tonalIcon(
                                      onPressed: onAbrir,
                                      style: FilledButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                      ),
                                      icon: Icon(
                                        notificacao.solicitacaoId != null
                                            ? Icons.open_in_new_rounded
                                            : Icons.assignment_outlined,
                                        size: 16,
                                      ),
                                      label: Text(
                                        notificacao.solicitacaoId != null
                                            ? 'Abrir solicitação'
                                            : 'Abrir atividade',
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    TFSemanticColors colors,
    TFTypography typo,
    Color sevColor,
  ) {
    final tipoIcon = _iconeEvento(notificacao.eventoTipo);
    return Row(
      children: [
        Icon(tipoIcon, size: 15, color: sevColor),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            notificacao.titulo.isNotEmpty
                ? notificacao.titulo
                : 'NOTIFICAÇÃO OPERACIONAL',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: typo.labelSmall.copyWith(
              color: sevColor,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: notificacao.lida
                ? colors.surfaceSecondary
                : colors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                notificacao.lida
                    ? Icons.mark_email_read_outlined
                    : Icons.mark_email_unread_outlined,
                size: 12,
                color: notificacao.lida ? colors.textSecondary : colors.primary,
              ),
              const SizedBox(width: 4),
              Text(
                notificacao.lida ? 'Lida' : 'Não lida',
                style: typo.labelSmall.copyWith(
                  fontSize: 11,
                  color:
                      notificacao.lida ? colors.textSecondary : colors.primary,
                  fontWeight:
                      notificacao.lida ? FontWeight.w500 : FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _fmt.format(notificacao.createdAt.toLocal()),
          style: typo.labelSmall.copyWith(
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }

  static Color _corSeveridade(TFSemanticColors c, String sev) {
    switch (sev) {
      case 'CRITICO':
      case 'RISCO':
        return c.danger;
      case 'ATENCAO':
        return c.warning;
      default:
        return c.info;
    }
  }

  static Color _corCriticidade(TFSemanticColors c, String criticidade) {
    final up = criticidade.toUpperCase();
    if (up.contains('BLOQ') || up.contains('CRIT')) return c.danger;
    if (up.contains('ESSEN') || up.contains('ALTA')) return c.warning;
    return c.textSecondary;
  }

  static IconData _iconeEvento(String eventoTipo) {
    switch (eventoTipo) {
      case 'SOLICITACAO_CRIADA':
      case 'SOLICITACAO_REABERTA':
        return Icons.handshake_outlined;
      case 'SOLICITACAO_EM_ANALISE':
        return Icons.manage_search_rounded;
      case 'SOLICITACAO_ACEITA':
      case 'CONTRAPROPOSTA_ACEITA':
        return Icons.check_circle_outline_rounded;
      case 'SOLICITACAO_RECUSADA':
        return Icons.cancel_outlined;
      case 'CONTRAPROPOSTA_ENVIADA':
        return Icons.edit_calendar_outlined;
      case 'ATIVIDADE_APOIO_CRIADA':
      case 'VINCULO_CRIADO':
        return Icons.link_rounded;
      case 'ATIVIDADE_REPROGRAMADA':
      case 'RECURSO_ATIVIDADE_ALTERADO':
        return Icons.warning_amber_rounded;
      case 'ATIVIDADE_CANCELADA':
      case 'ATIVIDADE_EXCLUIDA':
      case 'SOLICITACAO_CANCELADA':
        return Icons.event_busy_outlined;
      case 'ALERTA_PRAZO_APOIO':
        return Icons.schedule_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  static _SituacaoVisual? _resolverSituacao(
    TFSemanticColors c,
    NotificacaoInterna n,
    TaskApoioSolicitacao? sol,
  ) {
    if (sol != null) {
      switch (sol.status) {
        case TaskApoioStatus.pendente:
          return _SituacaoVisual(
            label: 'Aguardando resposta',
            icon: Icons.hourglass_top_rounded,
            color: c.warning,
          );
        case TaskApoioStatus.emAnalise:
          return _SituacaoVisual(
            label: 'Em análise',
            icon: Icons.manage_search_rounded,
            color: c.info,
          );
        case TaskApoioStatus.contraproposta:
          return _SituacaoVisual(
            label: 'Contraproposta',
            icon: Icons.edit_calendar_outlined,
            color: c.warning,
          );
        case TaskApoioStatus.aceita:
          return _SituacaoVisual(
            label: 'Aceita',
            icon: Icons.check_circle_outline_rounded,
            color: c.success,
          );
        case TaskApoioStatus.recusada:
          return _SituacaoVisual(
            label: 'Recusada',
            icon: Icons.cancel_outlined,
            color: c.danger,
          );
        case TaskApoioStatus.cancelada:
          return _SituacaoVisual(
            label: 'Cancelada',
            icon: Icons.block_outlined,
            color: c.textSecondary,
          );
        case TaskApoioStatus.desconhecido:
          return null;
      }
    }

    switch (n.eventoTipo) {
      case 'SOLICITACAO_CRIADA':
        return _SituacaoVisual(
          label: 'Aguardando resposta',
          icon: Icons.hourglass_top_rounded,
          color: c.warning,
        );
      case 'SOLICITACAO_EM_ANALISE':
        return _SituacaoVisual(
          label: 'Em análise',
          icon: Icons.manage_search_rounded,
          color: c.info,
        );
      case 'SOLICITACAO_ACEITA':
      case 'CONTRAPROPOSTA_ACEITA':
        return _SituacaoVisual(
          label: 'Aceita',
          icon: Icons.check_circle_outline_rounded,
          color: c.success,
        );
      case 'SOLICITACAO_RECUSADA':
        return _SituacaoVisual(
          label: 'Recusada',
          icon: Icons.cancel_outlined,
          color: c.danger,
        );
      case 'CONTRAPROPOSTA_ENVIADA':
        return _SituacaoVisual(
          label: 'Contraproposta',
          icon: Icons.edit_calendar_outlined,
          color: c.warning,
        );
      case 'ATIVIDADE_APOIO_CRIADA':
      case 'VINCULO_CRIADO':
        return _SituacaoVisual(
          label: 'Programado',
          icon: Icons.event_available_rounded,
          color: c.success,
        );
      default:
        return null;
    }
  }

  static _SituacaoVisual? _resolverPapel(
    TFSemanticColors c,
    bool? isSolicitante,
    bool? isPrestadora,
  ) {
    if (isPrestadora == true && isSolicitante != true) {
      return _SituacaoVisual(
        label: 'Pedido recebido',
        icon: Icons.south_west_rounded,
        color: c.primary,
      );
    }
    if (isSolicitante == true && isPrestadora != true) {
      return _SituacaoVisual(
        label: 'Solicitado por nós',
        icon: Icons.north_east_rounded,
        color: c.info,
      );
    }
    return null;
  }

  static _NotificacaoDadosExtraidos _extrairDados(
    NotificacaoInterna n,
    TaskApoioSolicitacao? sol,
    Map<String, String> nomesUnidades,
  ) {
    final linhas = n.mensagem
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    String? atividadeMsg;
    String? necessidadeMsg;
    String? periodoMsg;
    String? criticidadeMsg;
    final restantes = <String>[];

    for (final linha in linhas) {
      final lower = linha.toLowerCase();
      if (lower.startsWith('atividade:')) {
        atividadeMsg = linha.substring('atividade:'.length).trim();
      } else if (lower.startsWith('atividade principal:')) {
        atividadeMsg ??= linha.substring('atividade principal:'.length).trim();
      } else if (lower.startsWith('necessidade:')) {
        necessidadeMsg = linha.substring('necessidade:'.length).trim();
      } else if (lower.startsWith('período necessário:') ||
          lower.startsWith('periodo necessario:')) {
        periodoMsg = linha.split(':').skip(1).join(':').trim();
      } else if (lower.startsWith('período acordado:') ||
          lower.startsWith('período proposto:')) {
        periodoMsg ??= linha.split(':').skip(1).join(':').trim();
      } else if (lower.startsWith('criticidade:')) {
        criticidadeMsg = linha.substring('criticidade:'.length).trim();
      } else if (lower.startsWith('situação:') ||
          lower.startsWith('situacao:')) {
        // Situação já é exibida no badge estruturado; evita texto repetitivo.
        continue;
      } else {
        restantes.add(linha.replaceAll(_uuidRegex, '').trim());
      }
    }

    final atividadeFinal = _limparTexto(
      sol?.taskSolicitanteTituloSnapshot ??
          atividadeMsg ??
          n.metadata['tarefa']?.toString() ??
          '',
    );
    final necessidadeFinal = _limparTexto(
      sol?.descricao ??
          necessidadeMsg ??
          n.metadata['necessidade']?.toString() ??
          '',
    );

    final String tituloObjeto;
    final String descricaoCurta;
    if (atividadeFinal.isNotEmpty && necessidadeFinal.isNotEmpty) {
      tituloObjeto = atividadeFinal;
      descricaoCurta = 'Apoio solicitado: $necessidadeFinal';
    } else if (atividadeFinal.isNotEmpty) {
      tituloObjeto = atividadeFinal;
      descricaoCurta = restantes.join(' • ');
    } else if (necessidadeFinal.isNotEmpty) {
      tituloObjeto = necessidadeFinal;
      descricaoCurta = restantes.join(' • ');
    } else {
      tituloObjeto = restantes.isNotEmpty
          ? restantes.first
          : _limparTexto(n.titulo);
      descricaoCurta =
          restantes.length > 1 ? restantes.skip(1).join(' • ') : '';
    }

    String? periodoFinal = periodoMsg;
    if (sol != null) {
      final ini = sol.dataInicioAcordada ?? sol.dataInicioSolicitada;
      final fim = sol.dataFimAcordada ?? sol.dataFimSolicitada;
      periodoFinal = TaskApoioFormatters.formatarPeriodoHumano(ini, fim);
    }

    final criticidadeFinal = sol?.criticidade.label ??
        (criticidadeMsg != null && criticidadeMsg.isNotEmpty
            ? criticidadeMsg
            : null);

    String? fluxo;
    if (sol != null && nomesUnidades.isNotEmpty) {
      final orig = TaskApoioFormatters.formatarUnidade(
        regionalId: sol.regionalSolicitanteId,
        divisaoId: sol.divisaoSolicitanteId,
        segmentoId: sol.segmentoSolicitanteId,
        nomesUnidades: nomesUnidades,
        omitirRegional: sol.regionalSolicitanteId == sol.regionalDestinoId,
      );
      final dest = TaskApoioFormatters.formatarUnidade(
        regionalId: sol.regionalDestinoId,
        divisaoId: sol.divisaoDestinoId,
        segmentoId: sol.segmentoDestinoId,
        nomesUnidades: nomesUnidades,
        omitirRegional: sol.regionalSolicitanteId == sol.regionalDestinoId,
      );
      fluxo = 'De: $orig → Para: $dest';
    } else if (n.unidadeOrigemNome != null || n.unidadeDestinoNome != null) {
      fluxo = [
        if (n.unidadeOrigemNome != null && n.unidadeOrigemNome!.isNotEmpty)
          n.unidadeOrigemNome!,
        if (n.unidadeDestinoNome != null && n.unidadeDestinoNome!.isNotEmpty)
          n.unidadeDestinoNome!,
      ].join(' → ');
    }

    return _NotificacaoDadosExtraidos(
      tituloObjeto: tituloObjeto,
      descricaoCurta: _limparTexto(descricaoCurta),
      periodo: periodoFinal,
      criticidade: criticidadeFinal,
      fluxoUnidades: fluxo,
    );
  }

  static String _limparTexto(String texto) {
    return texto
        .replaceAll(_uuidRegex, '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }
}

class _NotificacaoDadosExtraidos {
  final String tituloObjeto;
  final String descricaoCurta;
  final String? periodo;
  final String? criticidade;
  final String? fluxoUnidades;

  const _NotificacaoDadosExtraidos({
    required this.tituloObjeto,
    required this.descricaoCurta,
    this.periodo,
    this.criticidade,
    this.fluxoUnidades,
  });
}

class _SituacaoVisual {
  final String label;
  final IconData icon;
  final Color color;

  const _SituacaoVisual({
    required this.label,
    required this.icon,
    required this.color,
  });
}

class _MetaBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetaBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typo = context.tfTypography;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: colors.surfaceSecondary.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typo.labelSmall.copyWith(
                color: color == colors.textSecondary
                    ? colors.textPrimary
                    : color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
