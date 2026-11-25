import 'package:flutter/material.dart';
import '../../../../design_system/taskflow_design_system.dart';
import '../../../../models/task.dart';
import '../../../../services/auth_service_simples.dart';
import '../../../../widgets/task_view_dialog.dart';
import '../../domain/enums/task_apoio_enums.dart';
import '../../domain/models/task_apoio_situacao.dart';
import '../../domain/models/task_apoio_solicitacao.dart';
import '../../domain/models/task_apoio_vinculo.dart';
import '../../domain/rules/task_apoio_state_machine.dart';
import '../task_apoio_ui_controller.dart';
import '../utils/task_apoio_formatters.dart';
import 'task_apoio_banner_estado.dart';
import 'task_apoio_card.dart';

/// Seção de acompanhamento integrado no `TaskViewDialog` (Itens 13, 14, 15, 16, 17, 18, 23, 25).
class TaskApoioViewSection extends StatefulWidget {
  final Task task;
  final TaskApoioUiController controller;
  final String usuarioAtualId;
  final String? usuarioAtualNome;
  final void Function(Map<String, dynamic> rascunhoAtividadeApoio)?
      onAbrirCriarAtividadeApoio;
  final VoidCallback? onSolicitarNovoApoio;
  final Future<void> Function(TaskApoioSolicitacao solicitacao)?
      onVincularExistente;

  final bool showHeader;
  final bool podeEditar;
  final void Function(Task task)? onAbrirAtividade;

  const TaskApoioViewSection({
    super.key,
    required this.task,
    required this.controller,
    required this.usuarioAtualId,
    this.usuarioAtualNome,
    this.onAbrirCriarAtividadeApoio,
    this.onSolicitarNovoApoio,
    this.onVincularExistente,
    this.showHeader = true,
    this.podeEditar = true,
    this.onAbrirAtividade,
  });

  @override
  State<TaskApoioViewSection> createState() => _TaskApoioViewSectionState();
}

class _TaskApoioViewSectionState extends State<TaskApoioViewSection> {
  bool _carregando = false;
  String? _erro;
  List<TaskApoioSolicitacao> _solicitadas = const [];
  final Map<String, TaskApoioSituacao> _situacoes = {};
  List<TaskApoioVinculo> _apoiadas = const [];
  final Map<String, List<TaskApoioVinculo>> _vinculosPorSol = {};

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void didUpdateWidget(covariant TaskApoioViewSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task.id != widget.task.id ||
        oldWidget.controller.disponibilidade !=
            widget.controller.disponibilidade) {
      _carregar();
    }
  }

  Future<void> _carregar() async {
    if (widget.controller.isBackendProtegido) {
      setState(() {
        _solicitadas = const [];
        _apoiadas = const [];
        _erro = null;
        _carregando = false;
      });
      return;
    }

    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      await Future.wait([
        widget.controller.carregarTiposAtivos(),
        widget.controller.carregarCatalogoUnidades(),
      ]);
      final (sols, vincs) =
          await widget.controller.carregarDetalhesParaTask(widget.task.id);
      final mapaSit = <String, TaskApoioSituacao>{};
      for (final s in sols) {
        mapaSit[s.id] = await widget.controller.avaliarSituacao(s);
      }
      final mapaVinc = <String, List<TaskApoioVinculo>>{};
      for (final v in vincs.where((e) => e.ativo && e.solicitacaoId != null)) {
        mapaVinc.putIfAbsent(v.solicitacaoId!, () => []).add(v);
      }
      if (!mounted) return;
      setState(() {
        _solicitadas = sols;
        _situacoes
          ..clear()
          ..addAll(mapaSit);
        _vinculosPorSol
          ..clear()
          ..addAll(mapaVinc);
        _apoiadas = vincs
            .where((v) => v.ativo && v.taskApoioId == widget.task.id)
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _erro = e.toString());
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _executarAcao(
    TaskApoioSolicitacao sol,
    TaskApoioAcao acao,
  ) async {
    if (!widget.podeEditar) return;
    String? justificativa;
    DateTime? contraIni;
    DateTime? contraFim;

    if (acao == TaskApoioAcao.enviarContraproposta) {
      final res = await _pedirContraproposta(sol);
      if (res == null) return;
      contraIni = res.$1;
      contraFim = res.$2;
      justificativa = res.$3;
    } else if (acao.exigeJustificativa) {
      justificativa = await _pedirJustificativa(acao.label);
      if (justificativa == null || justificativa.trim().isEmpty) return;
    }

    try {
      await widget.controller.executarAcaoProtegida(() async {
        final svc = widget.controller.service;
        switch (acao) {
          case TaskApoioAcao.encaminharAnalise:
            await svc.encaminharParaAnalise(
              solicitacaoId: sol.id,
              versaoEsperada: sol.versao,
              responsavelId: widget.usuarioAtualId,
              responsavelNome: widget.usuarioAtualNome,
            );
          case TaskApoioAcao.aceitar:
            await svc.aceitar(
              solicitacaoId: sol.id,
              versaoEsperada: sol.versao,
              atorUsuarioId: widget.usuarioAtualId,
              atorNome: widget.usuarioAtualNome,
            );
          case TaskApoioAcao.recusar:
            await svc.recusar(
              solicitacaoId: sol.id,
              versaoEsperada: sol.versao,
              atorUsuarioId: widget.usuarioAtualId,
              atorNome: widget.usuarioAtualNome,
              justificativa: justificativa!,
            );
          case TaskApoioAcao.enviarContraproposta:
            await svc.apresentarContraproposta(
              solicitacaoId: sol.id,
              versaoEsperada: sol.versao,
              atorUsuarioId: widget.usuarioAtualId,
              atorNome: widget.usuarioAtualNome,
              inicioProposto: contraIni!,
              fimProposto: contraFim!,
              justificativa: justificativa!,
            );
          case TaskApoioAcao.aceitarContraproposta:
            await svc.aceitarContraproposta(
              solicitacaoId: sol.id,
              versaoEsperada: sol.versao,
              atorUsuarioId: widget.usuarioAtualId,
              atorNome: widget.usuarioAtualNome,
            );
          case TaskApoioAcao.recusarContraproposta:
            await svc.recusarContraproposta(
              solicitacaoId: sol.id,
              versaoEsperada: sol.versao,
              atorUsuarioId: widget.usuarioAtualId,
              atorNome: widget.usuarioAtualNome,
              justificativa: justificativa!,
            );
          case TaskApoioAcao.cancelar:
            await svc.cancelar(
              solicitacaoId: sol.id,
              versaoEsperada: sol.versao,
              atorUsuarioId: widget.usuarioAtualId,
              atorNome: widget.usuarioAtualNome,
              motivo: justificativa!,
            );
          case TaskApoioAcao.solicitarReconfirmacao:
            await svc.solicitarReconfirmacao(
              solicitacaoId: sol.id,
              versaoEsperada: sol.versao,
              atorUsuarioId: widget.usuarioAtualId,
              atorNome: widget.usuarioAtualNome,
              motivo: justificativa!,
            );
        }
      });
      widget.controller.invalidarCacheTask(widget.task.id);
      await _carregar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível concluir a ação: $e')),
      );
    }
  }

  Future<String?> _pedirJustificativa(String tituloAcao) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tituloAcao),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Justificativa obrigatória *',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TFButton(
            label: 'Voltar',
            variant: TFButtonVariant.tertiary,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TFButton(
            label: 'Confirmar',
            variant: TFButtonVariant.primary,
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.of(ctx).pop(ctrl.text.trim());
            },
          ),
        ],
      ),
    );
  }

  Future<(DateTime, DateTime, String)?> _pedirContraproposta(
    TaskApoioSolicitacao sol,
  ) async {
    final ctrl = TextEditingController();
    var ini = sol.dataInicioSolicitada;
    var fim = sol.dataFimSolicitada;
    return showDialog<(DateTime, DateTime, String)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Apresentar Contraproposta'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Período proposto: ${TaskApoioFormatters.formatarPeriodoHumano(ini.toLocal(), fim.toLocal())}'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: ini,
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2032),
                      );
                      if (d != null) {
                        setDlg(() => ini = DateTime(d.year, d.month, d.day, ini.hour, ini.minute));
                      }
                    },
                    child: const Text('Alterar início'),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: fim,
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2032),
                      );
                      if (d != null) {
                        setDlg(() => fim = DateTime(d.year, d.month, d.day, fim.hour, fim.minute));
                      }
                    },
                    child: const Text('Alterar fim'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ctrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Justificativa da contraproposta *',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TFButton(
              label: 'Cancelar',
              variant: TFButtonVariant.tertiary,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            TFButton(
              label: 'Enviar contraproposta',
              variant: TFButtonVariant.primary,
              onPressed: () {
                if (ctrl.text.trim().isEmpty || fim.isBefore(ini)) return;
                Navigator.of(ctx).pop((ini, fim, ctrl.text.trim()));
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typo = context.tfTypography;
    final nomes = widget.controller.nomesUnidades;
    final tiposMap = {for (final t in widget.controller.tiposAtivos) t.id: t.nome};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showHeader) ...[
          Row(
            children: [
              Icon(Icons.handshake_outlined, size: 18, color: colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Apoios Operacionais',
                  style: typo.cardTitle.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (widget.podeEditar &&
                  widget.onSolicitarNovoApoio != null &&
                  !widget.controller.isBackendProtegido)
                TFButton(
                  label: 'Solicitar apoio',
                  size: TFButtonSize.small,
                  variant: TFButtonVariant.secondary,
                  leadingIcon: Icons.add_rounded,
                  onPressed: widget.onSolicitarNovoApoio,
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        TaskApoioBannerEstado(
          estado: widget.controller.disponibilidade,
          mensagemErro: _erro,
          onAtivarDemo: widget.controller.isModoDemonstracao
              ? null
              : () async {
                  await widget.controller.ativarModoDemonstracaoDev();
                  await _carregar();
                },
          onTentarNovamente: _carregar,
        ),
        if (_carregando) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ] else if (!widget.controller.isBackendProtegido && _erro == null) ...[
          if (_solicitadas.isEmpty && _apoiadas.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Não existem apoios operacionais registrados para esta atividade.',
              style: typo.bodySmall.copyWith(color: colors.textSecondary),
            ),
          ],

          // Indicadores resumidos da atividade
          if (_solicitadas.isNotEmpty || _apoiadas.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildResumoIndicadores(context),
          ],

          // Grupo 1: Apoios solicitados por esta atividade
          if (_solicitadas.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Apoios solicitados por esta atividade (${_solicitadas.length})',
              style: typo.labelMedium.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (final sol in _solicitadas)
              if (_situacoes.containsKey(sol.id))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TaskApoioCard(
                    solicitacao: sol,
                    situacao: _situacoes[sol.id]!,
                    nomeUnidadeDestino: TaskApoioFormatters.formatarUnidade(
                      regionalId: sol.regionalDestinoId,
                      divisaoId: sol.divisaoDestinoId,
                      segmentoId: sol.segmentoDestinoId,
                      nomesUnidades: nomes,
                    ),
                    nomeTipoApoio: tiposMap[sol.tipoApoioId],
                    tarefasVinculadas: _resolverTarefasVinculadas(sol.id),
                    papelAtor: _resolverPapelAtor(sol),
                    acoesHabilitadas: widget.podeEditar,
                    processando: widget.controller.operacaoEmAndamento,
                    onCarregarHistorico: () => widget.controller
                        .buscarHistoricoSolicitacao(sol.id),
                    onExecutarAcao: (acao) => _executarAcao(sol, acao),
                    onAbrirTarefa: widget.onAbrirAtividade,
                    onCriarAtividadeApoio: widget.onAbrirCriarAtividadeApoio ==
                            null
                        ? null
                        : () {
                            final rasc = widget.controller.service
                                .prepararRascunhoNovaAtividadeApoio(
                              solicitacao: sol,
                              tipoApoioNome:
                                  tiposMap[sol.tipoApoioId] ?? 'Apoio',
                            );
                            widget.onAbrirCriarAtividadeApoio!(rasc);
                          },
                    onVincularExistente: widget.onVincularExistente == null
                        ? null
                        : () => widget.onVincularExistente!(sol),
                  ),
                ),
          ],

          // Grupo 2: Atividades apoiadas por esta atividade
          if (_apoiadas.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Atividades apoiadas por esta atividade (${_apoiadas.length})',
              style: typo.labelMedium.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (_apoiadas.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TFStatusBadge(
                  label:
                      'Apoio compartilhado: atende ${_apoiadas.length} atividades solicitantes',
                  severity: TFStatusSeverity.info,
                  icon: Icons.share_outlined,
                ),
              ),
            for (final v in _apoiadas)
              _buildCardAtividadeApoiada(context, v),
          ],
        ],
      ],
    );
  }

  TaskApoioPapelAtor _resolverPapelAtor(TaskApoioSolicitacao sol) {
    final user = AuthServiceSimples().currentUser;
    if (user != null) {
      if (user.isRoot) {
        if (sol.taskSolicitanteId == widget.task.id) {
          return TaskApoioPapelAtor.solicitante;
        }
        return TaskApoioPapelAtor.unidadeApoio;
      }

      final ehDestino = (user.regionalIds.isEmpty ||
              user.regionalIds.contains(sol.regionalDestinoId)) &&
          user.divisaoIds.contains(sol.divisaoDestinoId) &&
          (sol.segmentoDestinoId == null ||
              sol.segmentoDestinoId!.isEmpty ||
              user.segmentoIds.contains(sol.segmentoDestinoId));

      final ehSolicitante =
          (widget.usuarioAtualId.isNotEmpty &&
              sol.solicitanteUsuarioId == widget.usuarioAtualId) ||
          ((user.regionalIds.isEmpty ||
                  user.regionalIds.contains(sol.regionalSolicitanteId)) &&
              user.divisaoIds.contains(sol.divisaoSolicitanteId) &&
              (sol.segmentoSolicitanteId == null ||
                  sol.segmentoSolicitanteId!.isEmpty ||
                  user.segmentoIds.contains(sol.segmentoSolicitanteId)));

      if (ehDestino && !ehSolicitante) return TaskApoioPapelAtor.unidadeApoio;
      if (ehSolicitante && !ehDestino) return TaskApoioPapelAtor.solicitante;
      if (ehDestino && ehSolicitante) {
        return sol.taskSolicitanteId == widget.task.id
            ? TaskApoioPapelAtor.solicitante
            : TaskApoioPapelAtor.unidadeApoio;
      }
      return TaskApoioPapelAtor.solicitante;
    }

    final mesmoDestino = widget.task.divisaoId == sol.divisaoDestinoId &&
        (sol.segmentoDestinoId == null ||
            sol.segmentoDestinoId!.isEmpty ||
            widget.task.segmentoId == sol.segmentoDestinoId);
    return mesmoDestino
        ? TaskApoioPapelAtor.unidadeApoio
        : TaskApoioPapelAtor.solicitante;
  }

  List<Task> _resolverTarefasVinculadas(String solicitacaoId) {
    final vincs = _vinculosPorSol[solicitacaoId] ?? const [];
    final out = <Task>[];
    for (final v in vincs) {
      if (v.taskApoioId == null || v.taskApoioId!.isEmpty) continue;
      final conhecida = widget.controller.tasksConhecidas[v.taskApoioId!];
      if (conhecida != null) {
        out.add(conhecida);
      } else {
        out.add(
          Task(
            id: v.taskApoioId!,
            tarefa: v.taskApoioTituloSnapshot,
            dataInicio: v.coberturaInicio ?? widget.task.dataInicio,
            dataFim: v.coberturaFim ?? widget.task.dataFim,
            status: v.statusConfirmacao.label,
            tipo: 'Apoio Operacional',
            coordenador: '',
            regional: '',
            divisao: '',
          ),
        );
      }
    }
    return out;
  }

  Widget _buildResumoIndicadores(BuildContext context) {
    int pendentes = 0;
    int semProg = 0;
    int programadas = 0;
    int emRisco = 0;

    for (final s in _solicitadas) {
      final sit = _situacoes[s.id];
      if (sit == null) continue;
      switch (sit.situacaoOperacional) {
        case TaskApoioSituacaoOperacional.aguardandoAnalise:
        case TaskApoioSituacaoOperacional.emNegociacao:
          pendentes++;
          break;
        case TaskApoioSituacaoOperacional.aceitaSemProgramacao:
          semProg++;
          if (s.criticidade == TaskApoioCriticidade.essencial) emRisco++;
          break;
        case TaskApoioSituacaoOperacional.parcialmenteProgramada:
        case TaskApoioSituacaoOperacional.programadaComIncompatibilidade:
        case TaskApoioSituacaoOperacional.programadaComRecursosPendentes:
        case TaskApoioSituacaoOperacional.programadaComRecursosNaoVerificados:
          programadas++;
          if (s.criticidade == TaskApoioCriticidade.essencial) emRisco++;
          break;
        case TaskApoioSituacaoOperacional.programadaCompativel:
        case TaskApoioSituacaoOperacional.emAndamento:
        case TaskApoioSituacaoOperacional.concluida:
          programadas++;
          break;
        case TaskApoioSituacaoOperacional.recusada:
        case TaskApoioSituacaoOperacional.cancelada:
          if (s.criticidade == TaskApoioCriticidade.essencial) emRisco++;
          break;
      }
    }

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        TFStatusBadge(
          label: 'Total: ${_solicitadas.length}',
          severity: TFStatusSeverity.neutral,
          compact: true,
        ),
        if (pendentes > 0)
          TFStatusBadge(
            label: 'Pendentes: $pendentes',
            severity: TFStatusSeverity.warning,
            compact: true,
          ),
        if (semProg > 0)
          TFStatusBadge(
            label: 'Aceitas s/ prog.: $semProg',
            severity: TFStatusSeverity.warning,
            compact: true,
          ),
        if (programadas > 0)
          TFStatusBadge(
            label: 'Programadas: $programadas',
            severity: TFStatusSeverity.success,
            compact: true,
          ),
        if (emRisco > 0)
          TFStatusBadge(
            label: 'Em risco: $emRisco',
            severity: TFStatusSeverity.danger,
            compact: true,
          ),
      ],
    );
  }

  Future<void> _abrirAtividadeSomenteLeitura(
    BuildContext context,
    String taskId, {
    Task? taskEmCache,
  }) async {
    if (taskEmCache != null && widget.onAbrirAtividade != null) {
      widget.onAbrirAtividade!(taskEmCache);
      return;
    }

    final task = taskEmCache ??
        await widget.controller.buscarTaskRelacionadaPorId(taskId);
    if (!context.mounted) return;
    if (task == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível carregar os dados desta atividade.'),
        ),
      );
      return;
    }
    await showDialog(
      context: context,
      builder: (_) => TaskViewDialog(
        task: task,
        apoioController: widget.controller,
        onEdit: null,
      ),
    );
  }

  Widget _buildCardAtividadeApoiada(BuildContext context, TaskApoioVinculo v) {
    final colors = context.tfColors;
    final typo = context.tfTypography;
    final principal = v.taskPrincipalId != null
        ? widget.controller.tasksConhecidas[v.taskPrincipalId!]
        : null;
    final taskId = v.taskPrincipalId;
    final clicavel = taskId != null && taskId.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: TFCard(
        padding: const EdgeInsets.all(10),
        onTap: clicavel
            ? () => _abrirAtividadeSomenteLeitura(
                  context,
                  taskId,
                  taskEmCache: principal,
                )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    v.taskPrincipalTituloSnapshot,
                    style: typo.labelMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: clicavel ? colors.primary : colors.textPrimary,
                    ),
                  ),
                ),
                TFStatusBadge(
                  label: v.finalidade.label,
                  severity: TFStatusSeverity.info,
                  compact: true,
                ),
                if (clicavel) ...[
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Visualizar atividade (somente leitura)',
                    child: Icon(
                      Icons.visibility_outlined,
                      size: 17,
                      color: colors.primary,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Vínculo: ${v.statusConfirmacao.label}'
                    '${principal != null ? ' • Status da tarefa: ${principal.status}' : ''}'
                    '${v.coberturaInicio != null && v.coberturaFim != null ? ' • Cobertura: ${TaskApoioFormatters.formatarPeriodoHumano(v.coberturaInicio!.toLocal(), v.coberturaFim!.toLocal())}' : ''}',
                    style: typo.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                if (clicavel)
                  TextButton.icon(
                    onPressed: () => _abrirAtividadeSomenteLeitura(
                      context,
                      taskId,
                      taskEmCache: principal,
                    ),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                    ),
                    icon: const Icon(Icons.visibility_outlined, size: 15),
                    label: const Text('Visualizar'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
