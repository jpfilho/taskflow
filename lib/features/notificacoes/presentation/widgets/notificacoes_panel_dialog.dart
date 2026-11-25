import 'package:flutter/material.dart';

import '../../../../design_system/taskflow_design_system.dart';
import '../../../../services/auth_service_simples.dart';
import '../../../apoios_operacionais/domain/models/task_apoio_solicitacao.dart';
import '../../../apoios_operacionais/presentation/task_apoio_ui_controller.dart';
import '../../domain/models/notificacao_interna.dart';
import '../notificacoes_controller.dart';
import 'notificacao_card.dart';
import 'notificacoes_preferencias_dialog.dart';

class NotificacoesPanelDialog extends StatefulWidget {
  final NotificacoesController controller;
  final TaskApoioUiController? apoioController;
  final Future<void> Function(NotificacaoInterna notificacao)? onSelecionar;

  const NotificacoesPanelDialog({
    super.key,
    required this.controller,
    this.apoioController,
    this.onSelecionar,
  });

  @override
  State<NotificacoesPanelDialog> createState() =>
      _NotificacoesPanelDialogState();
}

class _NotificacoesPanelDialogState extends State<NotificacoesPanelDialog> {
  static const _categorias = <String, String>{
    '': 'Todas as categorias',
    'SOLICITACAO': 'Solicitações',
    'DECISAO': 'Decisões',
    'NEGOCIACAO': 'Negociação',
    'PROGRAMACAO': 'Programação',
    'ALTERACAO': 'Alterações / Risco',
    'EXECUCAO': 'Execução',
    'PRAZO': 'Prazos',
    'CANCELAMENTO': 'Cancelamentos',
  };

  final Map<String, TaskApoioSolicitacao> _solicitacoesCache = {};
  final Set<String> _solicitacoesConsultadas = {};

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sincronizarSolicitacoesRelacionadas);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.controller.carregarNotificacoes(reset: true);
        _sincronizarSolicitacoesRelacionadas();
      }
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sincronizarSolicitacoesRelacionadas);
    super.dispose();
  }

  Future<void> _sincronizarSolicitacoesRelacionadas() async {
    final apoioCtrl = widget.apoioController;
    if (apoioCtrl == null || !mounted) return;

    final pendentes = widget.controller.notificacoes
        .map((n) => n.solicitacaoId)
        .whereType<String>()
        .where((id) => id.isNotEmpty && !_solicitacoesConsultadas.contains(id))
        .toSet();

    if (pendentes.isEmpty) return;
    _solicitacoesConsultadas.addAll(pendentes);

    if (apoioCtrl.nomesUnidades.isEmpty) {
      try {
        await apoioCtrl.carregarCatalogoUnidades();
      } catch (_) {}
    }

    final resultados = await Future.wait(
      pendentes.map((id) async {
        try {
          return await apoioCtrl.service.buscarSolicitacaoPorId(id);
        } catch (_) {
          return null;
        }
      }),
    );

    if (!mounted) return;
    bool atualizou = false;
    for (final sol in resultados) {
      if (sol != null) {
        _solicitacoesCache[sol.id] = sol;
        atualizou = true;
      }
    }
    if (atualizou) {
      setState(() {});
    }
  }

  bool _exigeFeedback(NotificacaoInterna n) {
    return n.solicitacaoId != null &&
        (n.eventoTipo == 'SOLICITACAO_CRIADA' ||
            n.eventoTipo == 'CONTRAPROPOSTA_ENVIADA' ||
            n.eventoTipo == 'RECONFIRMACAO_SOLICITADA');
  }

  Future<void> _abrirNotificacao(NotificacaoInterna n) async {
    if (!_exigeFeedback(n) && !n.lida) {
      await widget.controller.marcarComoLida(n.id);
    }
    if (widget.onSelecionar != null) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      await widget.onSelecionar!(n);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typo = context.tfTypography;
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    return Dialog(
      insetPadding: EdgeInsets.all(isMobile ? 12 : 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 680,
          maxHeight: size.height * 0.85,
        ),
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final itens = widget.controller.notificacoesFiltradas;
            final temFiltroAtivo = widget.controller.apenasNaoLidas ||
                (widget.controller.categoriaFiltro?.isNotEmpty ?? false);

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context, colors, typo),
                _buildToolbar(context, colors, typo, isMobile),
                const Divider(height: 1),
                if (widget.controller.erro != null)
                  _buildErrorBanner(colors, typo),
                Flexible(
                  child: _buildBody(
                    context,
                    colors,
                    typo,
                    itens,
                    temFiltroAtivo,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    TFSemanticColors colors,
    TFTypography typo,
  ) {
    final naoLidas = widget.controller.naoLidas;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.notifications_outlined,
              size: 20,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Notificações Operacionais',
                  style: typo.cardTitle.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: naoLidas > 0
                        ? colors.primary.withValues(alpha: 0.12)
                        : colors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    naoLidas > 0
                        ? '$naoLidas não lida${naoLidas > 1 ? 's' : ''}'
                        : 'Em dia',
                    style: typo.labelSmall.copyWith(
                      color:
                          naoLidas > 0 ? colors.primary : colors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Preferências de notificação',
            icon: const Icon(Icons.tune, size: 20),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => NotificacoesPreferenciasDialog(
                  controller: widget.controller,
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Fechar',
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(
    BuildContext context,
    TFSemanticColors colors,
    TFTypography typo,
    bool isMobile,
  ) {
    final apenasNaoLidas = widget.controller.apenasNaoLidas;
    final naoLidas = widget.controller.naoLidas;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ChoiceChip(
                label: const Text('Todas'),
                selected: !apenasNaoLidas,
                visualDensity: VisualDensity.compact,
                onSelected: (selected) {
                  if (selected) {
                    widget.controller.definirFiltros(apenasNaoLidas: false);
                  }
                },
              ),
              ChoiceChip(
                label: Text('Não lidas ($naoLidas)'),
                selected: apenasNaoLidas,
                visualDensity: VisualDensity.compact,
                onSelected: (selected) {
                  widget.controller.definirFiltros(apenasNaoLidas: selected);
                },
              ),
              SizedBox(
                width: isMobile ? 190 : 210,
                child: DropdownButtonFormField<String>(
                  initialValue: widget.controller.categoriaFiltro ?? '',
                  isExpanded: true,
                  isDense: true,
                  decoration: const InputDecoration(
                    labelText: 'Categoria',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  items: _categorias.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(
                            e.value,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v == null || v.isEmpty) {
                      widget.controller.definirFiltros(limparCategoria: true);
                    } else {
                      widget.controller.definirFiltros(categoria: v);
                    }
                  },
                ),
              ),
            ],
          ),
          if (naoLidas > 0)
            TextButton.icon(
              onPressed: widget.controller.marcarTodasComoLidas,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.done_all, size: 17),
              label: const Text('Marcar todas como lidas'),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(TFSemanticColors colors, TFTypography typo) {
    return Container(
      color: colors.warning.withValues(alpha: 0.14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: colors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.controller.erro!,
              style: typo.bodySmall.copyWith(color: colors.textPrimary),
            ),
          ),
          TextButton(
            onPressed: () => widget.controller.carregarNotificacoes(reset: true),
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    TFSemanticColors colors,
    TFTypography typo,
    List<NotificacaoInterna> itens,
    bool temFiltroAtivo,
  ) {
    if (widget.controller.carregando && itens.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Carregando notificações...'),
          ],
        ),
      );
    }

    if (itens.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              temFiltroAtivo
                  ? Icons.filter_list_off_rounded
                  : Icons.notifications_none_rounded,
              size: 36,
              color: colors.textSecondary,
            ),
            const SizedBox(height: 10),
            Text(
              temFiltroAtivo
                  ? 'Nenhuma notificação encontrada para os filtros selecionados.'
                  : 'Nenhuma notificação operacional no momento.',
              textAlign: TextAlign.center,
              style: typo.bodyMedium.copyWith(color: colors.textSecondary),
            ),
            if (temFiltroAtivo) ...[
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => widget.controller.definirFiltros(
                  apenasNaoLidas: false,
                  limparCategoria: true,
                ),
                child: const Text('Limpar filtros'),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.all(12),
      itemCount: itens.length + (widget.controller.temMais ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, idx) {
        if (idx >= itens.length) {
          return Center(
            child: TextButton.icon(
              onPressed: widget.controller.carregando
                  ? null
                  : () => widget.controller.carregarNotificacoes(reset: false),
              icon: const Icon(Icons.expand_more_rounded, size: 18),
              label: const Text('Carregar anteriores'),
            ),
          );
        }

        final n = itens[idx];
        final sol =
            n.solicitacaoId != null ? _solicitacoesCache[n.solicitacaoId!] : null;
        final (isSol, isDest) = _resolverPapelUsuario(sol);

        return NotificacaoCard(
          notificacao: n,
          solicitacao: sol,
          nomesUnidades: widget.apoioController?.nomesUnidades ?? const {},
          isSolicitante: isSol,
          isPrestadora: isDest,
          onAbrir: widget.onSelecionar != null ? () => _abrirNotificacao(n) : null,
          onMarcarLida: !n.lida
              ? () => widget.controller.marcarComoLida(n.id)
              : null,
        );
      },
    );
  }

  (bool?, bool?) _resolverPapelUsuario(TaskApoioSolicitacao? sol) {
    if (sol == null) return (null, null);
    final user = AuthServiceSimples().currentUser;
    if (user == null) return (null, null);

    bool pertenceUnidade(String regId, String divId, String? segId) {
      if (user.regionalIds.isNotEmpty && !user.regionalIds.contains(regId)) {
        return false;
      }
      if (!user.divisaoIds.contains(divId)) return false;
      if (segId != null && segId.isNotEmpty && !user.segmentoIds.contains(segId)) {
        return false;
      }
      return true;
    }

    final ehSol = ((user.id?.isNotEmpty ?? false) &&
            sol.solicitanteUsuarioId == user.id) ||
        pertenceUnidade(
          sol.regionalSolicitanteId,
          sol.divisaoSolicitanteId,
          sol.segmentoSolicitanteId,
        );
    final ehDest = pertenceUnidade(
      sol.regionalDestinoId,
      sol.divisaoDestinoId,
      sol.segmentoDestinoId,
    );
    return (ehSol, ehDest);
  }
}
