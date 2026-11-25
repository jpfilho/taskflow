import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../design_system/taskflow_design_system.dart';
import '../../../../models/task.dart';
import '../../../../widgets/gantt_chart.dart' show GanttChart, GanttScale;
import '../../domain/enums/task_apoio_enums.dart';
import '../../domain/models/task_apoio_periodo.dart';
import '../../domain/models/task_apoio_situacao.dart';
import '../../domain/models/task_apoio_solicitacao.dart';
import '../../domain/models/task_apoio_vinculo.dart';
import '../../domain/rules/task_apoio_state_machine.dart';
import '../task_apoio_status_mapper.dart';
import '../task_apoio_ui_controller.dart';
import 'task_apoio_mensagens_dialog.dart';
import 'task_apoio_negociacao_helper.dart';

/// Abre o Gantt Integrado focado em uma atividade ou conjunto de atividades.
class GanttIntegradoDialog {
  const GanttIntegradoDialog._();

  static Future<void> abrir(
    BuildContext context, {
    required TaskApoioUiController controller,
    required Task atividadePrincipal,
    required String usuarioAtualId,
    String? usuarioAtualNome,
    void Function(Task task)? onAbrirAtividade,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 1180,
            maxHeight: MediaQuery.of(ctx).size.height * 0.9,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.view_timeline_outlined,
                      color: ctx.tfColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Gantt Integrado — ${atividadePrincipal.tarefa}',
                        style: ctx.tfTypography.cardTitle.copyWith(
                          color: ctx.tfColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: GanttIntegradoApoiosWidget(
                  controller: controller,
                  atividadesPrincipais: [atividadePrincipal],
                  usuarioAtualId: usuarioAtualId,
                  usuarioAtualNome: usuarioAtualNome,
                  onAbrirAtividade: onAbrirAtividade,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget do Gantt Integrado de Apoios Operacionais (Fase 7).
/// Reutiliza [TaskApoioCompatibilityEngine] (via [TaskApoioSituacao]),
/// representa períodos descontínuos, lacunas explícitas, recursos pendentes
/// e apoios compartilhados sem duplicar `task_id` nem horas.
class GanttIntegradoApoiosWidget extends StatefulWidget {
  final TaskApoioUiController controller;
  final List<Task> atividadesPrincipais;
  final String usuarioAtualId;
  final String? usuarioAtualNome;
  final void Function(Task task)? onAbrirAtividade;
  final GanttScale escalaInicial;

  const GanttIntegradoApoiosWidget({
    super.key,
    required this.controller,
    required this.atividadesPrincipais,
    required this.usuarioAtualId,
    this.usuarioAtualNome,
    this.onAbrirAtividade,
    this.escalaInicial = GanttScale.daily,
  });

  @override
  State<GanttIntegradoApoiosWidget> createState() =>
      _GanttIntegradoApoiosWidgetState();
}

class _GanttIntegradoApoiosWidgetState
    extends State<GanttIntegradoApoiosWidget> {
  final _fmtDia = DateFormat('dd/MM');
  final _fmtHora = DateFormat('dd/MM HH:mm');

  late GanttScale _escala;
  final ScrollController _ganttScrollCtrl = ScrollController();
  bool _usarCalendarioOficial = false;
  bool _carregando = true;
  bool _somenteEmRisco = false;
  bool _somenteEssenciais = false;
  bool _somenteCompartilhados = false;
  TaskApoioCriticidade? _filtroCrit;
  String? _filtroTipoId;

  List<TaskApoioSolicitacao> _solicitacoes = const [];
  Map<String, TaskApoioSituacao> _situacoes = const {};
  Map<String, List<TaskApoioVinculo>> _vinculosPorSolicitacao = const {};
  Map<String, int> _contagemCompartilhadaPorTaskApoio = const {};

  @override
  void initState() {
    super.initState();
    _escala = widget.escalaInicial;
    widget.controller.registrarTasksConhecidas(widget.atividadesPrincipais);
    _carregar();
  }

  @override
  void dispose() {
    _ganttScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      await widget.controller.carregarTiposAtivos();
      final ids = widget.atividadesPrincipais.map((t) => t.id).toList();
      final (sols, sits) =
          await widget.controller.carregarDadosGanttIntegrado(taskIds: ids);

      final vincMap = <String, List<TaskApoioVinculo>>{};
      final shareCount = <String, int>{};
      for (final s in sols) {
        final vincs = await widget.controller.service
            .consultarRelacionamentoBidirecional(s.taskSolicitanteId ?? '');
        final daSol = vincs.where((v) => v.solicitacaoId == s.id && v.ativo).toList();
        vincMap[s.id] = daSol;
        for (final v in daSol) {
          if (v.taskApoioId != null) {
            shareCount[v.taskApoioId!] = (shareCount[v.taskApoioId!] ?? 0) + 1;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _solicitacoes = sols;
        _situacoes = sits;
        _vinculosPorSolicitacao = vincMap;
        _contagemCompartilhadaPorTaskApoio = shareCount;
      });
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  List<TaskApoioSolicitacao> get _solsFiltradas {
    return _solicitacoes.where((s) {
      if (_filtroCrit != null && s.criticidade != _filtroCrit) return false;
      if (_somenteEssenciais &&
          s.criticidade != TaskApoioCriticidade.essencial) {
        return false;
      }
      if (_filtroTipoId != null && s.tipoApoioId != _filtroTipoId) return false;
      final sit = _situacoes[s.id];
      final vincs = _vinculosPorSolicitacao[s.id] ?? const [];
      if (_somenteEmRisco && sit != null) {
        final op = sit.situacaoOperacional;
        final risco = op ==
                TaskApoioSituacaoOperacional.programadaComIncompatibilidade ||
            op == TaskApoioSituacaoOperacional.parcialmenteProgramada ||
            op == TaskApoioSituacaoOperacional.aceitaSemProgramacao;
        if (!risco) return false;
      }
      if (_somenteCompartilhados) {
        final comp = vincs.any(
          (v) => (_contagemCompartilhadaPorTaskApoio[v.taskApoioId] ?? 0) > 1,
        );
        if (!comp) return false;
      }
      return true;
    }).toList();
  }

  (DateTime, DateTime) _calcularIntervaloTotal(List<TaskApoioSolicitacao> sols) {
    DateTime? minDt;
    DateTime? maxDt;

    void incluir(DateTime dt) {
      if (minDt == null || dt.isBefore(minDt!)) minDt = dt;
      if (maxDt == null || dt.isAfter(maxDt!)) maxDt = dt;
    }

    for (final t in widget.atividadesPrincipais) {
      incluir(t.dataInicio);
      incluir(t.dataFim);
    }
    for (final s in sols) {
      incluir(s.dataInicioSolicitada);
      incluir(s.dataFimSolicitada);
      if (s.contrapropostaInicio != null) incluir(s.contrapropostaInicio!);
      if (s.contrapropostaFim != null) incluir(s.contrapropostaFim!);
      for (final p in s.periodos) {
        incluir(p.dataInicio);
        incluir(p.dataFim);
      }
      for (final v in _vinculosPorSolicitacao[s.id] ?? const []) {
        final ta = widget.controller.tasksConhecidas[v.taskApoioId];
        if (ta != null) {
          incluir(ta.dataInicio);
          incluir(ta.dataFim);
        }
      }
    }

    final baseMin = minDt ?? DateTime.now();
    final baseMax = maxDt ?? baseMin.add(const Duration(days: 5));
    return (
      DateTime(baseMin.year, baseMin.month, baseMin.day),
      DateTime(baseMax.year, baseMax.month, baseMax.day, 23, 59),
    );
  }

  double _larguraPorDia() {
    switch (_escala) {
      case GanttScale.hourly:
        return 110;
      case GanttScale.daily:
        return 68;
      case GanttScale.weekly:
        return 38;
      case GanttScale.biweekly:
        return 26;
      case GanttScale.monthly:
      case GanttScale.quarterly:
      case GanttScale.semiAnnual:
        return 18;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final typo = context.tfTypography;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final sols = _solsFiltradas;
    final (inicioJanela, fimJanela) = _calcularIntervaloTotal(sols);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Barra de controles, filtros e legenda
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Wrap(
                spacing: 4,
                children: [
                  for (final entry in const [
                    (GanttScale.daily, 'Diário'),
                    (GanttScale.weekly, 'Semanal'),
                    (GanttScale.monthly, 'Mensal'),
                  ])
                    ChoiceChip(
                      label: Text(
                        entry.$2,
                        style: TextStyle(
                          color: _escala == entry.$1
                              ? Colors.white
                              : colors.textPrimary,
                          fontWeight: _escala == entry.$1
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                      selected: _escala == entry.$1,
                      selectedColor: colors.primary,
                      backgroundColor: colors.surface,
                      side: BorderSide(
                        color: _escala == entry.$1
                            ? colors.primary
                            : colors.borderSubtle,
                      ),
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _escala = entry.$1),
                    ),
                ],
              ),
              FilterChip(
                label: const Text('Essenciais'),
                selected: _somenteEssenciais,
                onSelected: (v) => setState(() => _somenteEssenciais = v),
              ),
              FilterChip(
                label: const Text('Em risco / pendência'),
                selected: _somenteEmRisco,
                onSelected: (v) => setState(() => _somenteEmRisco = v),
              ),
              FilterChip(
                label: const Text('Compartilhados'),
                selected: _somenteCompartilhados,
                onSelected: (v) => setState(() => _somenteCompartilhados = v),
              ),
              FilterChip(
                avatar: const Icon(Icons.calendar_month_outlined, size: 16),
                label: const Text('Calendário oficial'),
                selected: _usarCalendarioOficial,
                onSelected: (v) => setState(() => _usarCalendarioOficial = v),
              ),
              IconButton(
                tooltip: 'Atualizar',
                icon: const Icon(Icons.refresh),
                onPressed: _carregar,
              ),
            ],
          ),
        ),
        _buildLegenda(colors, typo),
        const Divider(height: 1),
        Expanded(
          child: _carregando
              ? const Center(child: CircularProgressIndicator())
              : widget.controller.isBackendProtegido
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Gantt Integrado protegido: autentique-se ou ative o Modo Demonstração (DEV) para visualizar os apoios.',
                          style: typo.bodyMedium
                              .copyWith(color: colors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : _usarCalendarioOficial
                      ? _buildCalendarioOficialGantt(
                          sols, inicioJanela, fimJanela)
                      : isMobile
                          ? _buildListaMobile(sols, colors, typo)
                          : _buildTimelineDesktop(
                              sols, inicioJanela, fimJanela, colors, typo),
        ),
      ],
    );
  }

  Widget _buildCalendarioOficialGantt(
    List<TaskApoioSolicitacao> sols,
    DateTime inicioJanela,
    DateTime fimJanela,
  ) {
    final mapaTasks = <String, Task>{
      for (final t in widget.atividadesPrincipais) t.id: t,
    };
    for (final s in sols) {
      if (s.taskSolicitanteId != null) {
        final princ = widget.controller.tasksConhecidas[s.taskSolicitanteId!];
        if (princ != null) mapaTasks[princ.id] = princ;
      }
      final vincs = _vinculosPorSolicitacao[s.id] ?? const [];
      for (final v in vincs.where((e) => e.ativo && e.taskApoioId != null)) {
        final apoioTask = widget.controller.tasksConhecidas[v.taskApoioId!];
        if (apoioTask != null) mapaTasks[apoioTask.id] = apoioTask;
      }
    }
    return GanttChart(
      tasks: mapaTasks.values.toList(),
      startDate: inicioJanela,
      endDate: fimJanela,
      scale: _escala,
      onScaleChanged: (s) => setState(() => _escala = s),
      scrollController: _ganttScrollCtrl,
      onEdit: widget.onAbrirAtividade,
    );
  }

  Widget _buildLegenda(TFSemanticColors colors, TFTypography typo) {
    Widget item(Color cor, IconData icon, String label, {bool tracejado = false}) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 10,
            decoration: BoxDecoration(
              color: tracejado ? Colors.transparent : cor,
              border: Border.all(color: cor, width: 1.6),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 4),
          Icon(icon, size: 13, color: cor),
          const SizedBox(width: 3),
          Text(
            label,
            style: typo.labelSmall.copyWith(color: colors.textSecondary),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Wrap(
        spacing: 14,
        runSpacing: 6,
        children: [
          item(colors.primary, Icons.assignment, 'Atividade principal'),
          item(colors.info, Icons.schedule, 'Necessidade solicitada',
              tracejado: true),
          item(colors.success, Icons.event_available, 'Apoio programado'),
          item(colors.warning, Icons.warning_amber_rounded,
              'Parcial / Recurso pendente'),
          item(colors.danger, Icons.error_outline, 'Lacuna / Incompatível'),
        ],
      ),
    );
  }

  Widget _buildTimelineDesktop(
    List<TaskApoioSolicitacao> sols,
    DateTime inicioJanela,
    DateTime fimJanela,
    TFSemanticColors colors,
    TFTypography typo,
  ) {
    final totalDias =
        fimJanela.difference(inicioJanela).inDays.clamp(1, 120) + 1;
    final dayWidth = _larguraPorDia();
    final timelineWidth = totalDias * dayWidth;
    final nomes = widget.controller.nomesUnidades;
    final tiposMap = {
      for (final t in widget.controller.tiposAtivos) t.id: t.nome,
    };

    double posX(DateTime dt) {
      final mins = dt.difference(inicioJanela).inMinutes.toDouble();
      return ((mins / 1440.0) * dayWidth).clamp(0.0, timelineWidth);
    }

    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Coluna esquerda (atividades + necessidades/apoios)
          SizedBox(
            width: 320,
            child: Column(
              children: [
                Container(
                  height: 40,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    border: Border(
                      bottom: BorderSide(color: colors.borderSubtle),
                      right: BorderSide(color: colors.borderSubtle),
                    ),
                  ),
                  child: Text(
                    'Atividade / Apoio vinculado',
                    style: typo.labelMedium.copyWith(color: colors.textSecondary),
                  ),
                ),
                for (final task in widget.atividadesPrincipais) ...[
                  _buildLeftRowPrincipal(task, colors, typo),
                  for (final sol in sols.where(
                      (s) => s.taskSolicitanteId == task.id)) ...[
                    _buildLeftRowSolicitacao(
                        sol, nomes, tiposMap, colors, typo),
                  ],
                ],
              ],
            ),
          ),
          // Área temporal do Gantt
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: timelineWidth,
                child: Column(
                  children: [
                    // Cabeçalho de dias
                    SizedBox(
                      height: 40,
                      child: Row(
                        children: List.generate(totalDias, (i) {
                          final dia = inicioJanela.add(Duration(days: i));
                          return Container(
                            width: dayWidth,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: colors.surface,
                              border: Border(
                                bottom: BorderSide(color: colors.borderSubtle),
                                right: BorderSide(
                                  color: colors.borderSubtle.withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                            child: Text(
                              _fmtDia.format(dia),
                              style: typo.labelSmall
                                  .copyWith(color: colors.textSecondary),
                            ),
                          );
                        }),
                      ),
                    ),
                    // Linhas sincronizadas
                    for (final task in widget.atividadesPrincipais) ...[
                      _buildRightRowPrincipal(
                          task, posX, timelineWidth, colors, typo),
                      for (final sol in sols.where(
                          (s) => s.taskSolicitanteId == task.id)) ...[
                        _buildRightRowSolicitacao(
                            sol, posX, timelineWidth, colors, typo),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftRowPrincipal(
      Task task, TFSemanticColors colors, TFTypography typo) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.05),
        border: Border(
          bottom: BorderSide(color: colors.borderSubtle),
          right: BorderSide(color: colors.borderSubtle),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.assignment, size: 16, color: colors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  task.tarefa,
                  style: typo.labelMedium.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${task.divisao} • ${_fmtDia.format(task.dataInicio)} - ${_fmtDia.format(task.dataFim)}',
                  style: typo.labelSmall.copyWith(color: colors.textSecondary),
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

  Widget _buildLeftRowSolicitacao(
    TaskApoioSolicitacao sol,
    Map<String, String> nomes,
    Map<String, String> tiposMap,
    TFSemanticColors colors,
    TFTypography typo,
  ) {
    final sit = _situacoes[sol.id];
    final destino = nomes[sol.divisaoDestinoId] ?? sol.divisaoDestinoId;
    final tipoNome = tiposMap[sol.tipoApoioId] ?? 'Apoio';
    final badge = sit != null
        ? TaskApoioStatusMapper.paraSituacaoOperacional(sit.situacaoOperacional)
        : null;
    final compartilhado = (_vinculosPorSolicitacao[sol.id] ?? const []).any(
      (v) => (_contagemCompartilhadaPorTaskApoio[v.taskApoioId] ?? 0) > 1,
    );

    return InkWell(
      onTap: () => _mostrarResumoBarra(sol, sit),
      child: Container(
        height: 64,
        padding: const EdgeInsets.fromLTRB(24, 6, 10, 6),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: colors.borderSubtle),
            right: BorderSide(color: colors.borderSubtle),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$tipoNome: ${sol.descricao}',
                    style: typo.bodySmall.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (compartilhado)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Tooltip(
                      message: 'Apoio compartilhado com outras solicitações',
                      child: Icon(Icons.share_outlined,
                          size: 13, color: colors.info),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '$destino • ${badge?.label ?? sol.status.label}',
              style: typo.labelSmall.copyWith(color: colors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightRowPrincipal(
    Task task,
    double Function(DateTime) posX,
    double width,
    TFSemanticColors colors,
    TFTypography typo,
  ) {
    final left = posX(task.dataInicio);
    final right = posX(task.dataFim);
    final barW = (right - left).clamp(18.0, width - left);

    return Container(
      height: 54,
      width: width,
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.03),
        border: Border(bottom: BorderSide(color: colors.borderSubtle)),
      ),
      child: Stack(
        children: [
          Positioned(
            left: left,
            top: 13,
            width: barW,
            height: 28,
            child: Tooltip(
              message:
                  '${task.tarefa}\n${_fmtHora.format(task.dataInicio)} - ${_fmtHora.format(task.dataFim)}',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.centerLeft,
                child: Text(
                  task.tarefa,
                  style: typo.labelSmall.copyWith(color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightRowSolicitacao(
    TaskApoioSolicitacao sol,
    double Function(DateTime) posX,
    double width,
    TFSemanticColors colors,
    TFTypography typo,
  ) {
    final sit = _situacoes[sol.id];
    final periodosNec = sol.periodos.isNotEmpty
        ? sol.periodos
        : [
            TaskApoioPeriodo(
              dataInicio: sol.dataInicioSolicitada,
              dataFim: sol.dataFimSolicitada,
            ),
          ];
    final lacunas = sit?.compatibilidade.lacunas ?? const [];
    final vinculosAtivos = _vinculosPorSolicitacao[sol.id] ?? const [];

    Color corApoio() {
      final op = sit?.situacaoOperacional;
      if (op == TaskApoioSituacaoOperacional.programadaCompativel ||
          op == TaskApoioSituacaoOperacional.concluida) {
        return colors.success;
      }
      if (op == TaskApoioSituacaoOperacional.programadaComIncompatibilidade) {
        return colors.danger;
      }
      return colors.warning;
    }

    return InkWell(
      onTap: () => _mostrarResumoBarra(sol, sit),
      child: Container(
        height: 64,
        width: width,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.borderSubtle)),
        ),
        child: Stack(
          children: [
            // 1. Períodos necessários (contorno tracejado)
            for (final p in periodosNec)
              Positioned(
                left: posX(p.dataInicio),
                top: 8,
                width: (posX(p.dataFim) - posX(p.dataInicio))
                    .clamp(14.0, width - posX(p.dataInicio)),
                height: 20,
                child: CustomPaint(
                  painter: _DashedRectPainter(color: colors.info),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Necessário',
                        style: typo.labelSmall.copyWith(
                          fontSize: 9,
                          color: colors.info,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                      ),
                    ),
                  ),
                ),
              ),

            // 2. Contraproposta não aceita (neutra)
            if (sol.status == TaskApoioStatus.contraproposta &&
                sol.contrapropostaInicio != null &&
                sol.contrapropostaFim != null)
              Positioned(
                left: posX(sol.contrapropostaInicio!),
                top: 34,
                width: (posX(sol.contrapropostaFim!) -
                        posX(sol.contrapropostaInicio!))
                    .clamp(16.0, width - posX(sol.contrapropostaInicio!)),
                height: 22,
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.textSecondary.withValues(alpha: 0.16),
                    border: Border.all(color: colors.textSecondary),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Contraproposta',
                    style: typo.labelSmall.copyWith(fontSize: 9),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

            // 3. Atividades de apoio efetivamente programadas (uma barra por vínculo/atividade, sem fundir lacunas!)
            for (final v in vinculosAtivos)
              if (widget.controller.tasksConhecidas[v.taskApoioId] != null)
                Builder(
                  builder: (_) {
                    final ta =
                        widget.controller.tasksConhecidas[v.taskApoioId]!;
                    final l = posX(ta.dataInicio);
                    final w =
                        (posX(ta.dataFim) - l).clamp(16.0, width - l);
                    return Positioned(
                      left: l,
                      top: 34,
                      width: w,
                      height: 22,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: corApoio(),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${ta.tarefa} (${sit?.compatibilidade.percentualCobertura.toStringAsFixed(0) ?? 0}%)',
                          style: typo.labelSmall
                              .copyWith(fontSize: 10, color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  },
                ),

            // 4. Lacunas explícitas de atendimento
            for (final lac in lacunas)
              Positioned(
                left: posX(lac.inicio),
                top: 34,
                width: (posX(lac.fim) - posX(lac.inicio))
                    .clamp(10.0, width - posX(lac.inicio)),
                height: 22,
                child: Tooltip(
                  message:
                      'Lacuna: ${_fmtHora.format(lac.inicio)} - ${_fmtHora.format(lac.fim)}',
                  child: Container(
                    decoration: BoxDecoration(
                      color: colors.danger.withValues(alpha: 0.25),
                      border: Border.all(color: colors.danger, width: 1.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.error_outline,
                        size: 13, color: colors.danger),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildListaMobile(
    List<TaskApoioSolicitacao> sols,
    TFSemanticColors colors,
    TFTypography typo,
  ) {
    final nomes = widget.controller.nomesUnidades;
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: sols.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, idx) {
        final sol = sols[idx];
        final sit = _situacoes[sol.id];
        final info = sit != null
            ? TaskApoioStatusMapper.paraSituacaoOperacional(
                sit.situacaoOperacional)
            : null;
        return InkWell(
          onTap: () => _mostrarResumoBarra(sol, sit),
          child: Container(
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
                  sol.descricao,
                  style: typo.cardTitle.copyWith(color: colors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Unidade: ${nomes[sol.divisaoDestinoId] ?? sol.divisaoDestinoId}',
                  style: typo.bodySmall.copyWith(color: colors.textSecondary),
                ),
                Text(
                  'Necessário: ${_fmtHora.format(sol.dataInicioSolicitada)} - ${_fmtHora.format(sol.dataFimSolicitada)}',
                  style: typo.labelSmall.copyWith(color: colors.info),
                ),
                if (sit != null)
                  Text(
                    'Situação: ${info?.label ?? ''} • Cobertura: ${sit.compatibilidade.percentualCobertura.toStringAsFixed(0)}%',
                    style: typo.labelSmall.copyWith(color: colors.textPrimary),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _mostrarResumoBarra(
    TaskApoioSolicitacao sol,
    TaskApoioSituacao? sit,
  ) async {
    final nomes = widget.controller.nomesUnidades;
    final info = sit != null
        ? TaskApoioStatusMapper.paraSituacaoOperacional(sit.situacaoOperacional)
        : null;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(sol.descricao),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Unidade prestadora: ${nomes[sol.divisaoDestinoId] ?? sol.divisaoDestinoId}'),
              Text(
                  'Período necessário: ${_fmtHora.format(sol.dataInicioSolicitada)} até ${_fmtHora.format(sol.dataFimSolicitada)}'),
              if (sit != null) ...[
                const SizedBox(height: 6),
                Text('Situação: ${info?.label ?? sol.status.label}'),
                Text(
                    'Cobertura temporal: ${sit.compatibilidade.percentualCobertura.toStringAsFixed(0)}%'),
                Text('Resumo técnico: ${sit.compatibilidade.resumoExplicativo}'),
                if (sit.compatibilidade.lacunas.isNotEmpty)
                  Text(
                    'Lacunas: ${sit.compatibilidade.lacunas.map((l) => "${_fmtHora.format(l.inicio)}-${_fmtHora.format(l.fim)}").join(", ")}',
                    style: TextStyle(color: ctx.tfColors.danger),
                  ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              showDialog(
                context: context,
                builder: (_) => TaskApoioMensagensDialog(
                  solicitacaoId: sol.id,
                  tituloSolicitacao: sol.descricao,
                  usuarioAtualId: widget.usuarioAtualId,
                  usuarioAtualNome:
                      widget.usuarioAtualNome ?? 'Usuário TaskFlow',
                  modoDemonstracao: widget.controller.isModoDemonstracao,
                ),
              );
            },
            child: const Text('Esclarecimentos'),
          ),
          if ((_vinculosPorSolicitacao[sol.id] ?? const []).isNotEmpty &&
              widget.onAbrirAtividade != null)
            TextButton(
              onPressed: () {
                final taskApoio = widget.controller.tasksConhecidas[
                    _vinculosPorSolicitacao[sol.id]!.first.taskApoioId];
                Navigator.of(ctx).pop();
                if (taskApoio != null) widget.onAbrirAtividade!(taskApoio);
              },
              child: const Text('Abrir atividade vinculada'),
            ),
          if (sol.status == TaskApoioStatus.aceita)
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await TaskApoioNegociacaoHelper.executarAcao(
                  context: context,
                  controller: widget.controller,
                  solicitacao: sol,
                  acao: TaskApoioAcao.solicitarReconfirmacao,
                  usuarioAtualId: widget.usuarioAtualId,
                  usuarioAtualNome: widget.usuarioAtualNome,
                );
                await _carregar();
              },
              child: const Text('Solicitar reconfirmação'),
            ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  final Color color;
  _DashedRectPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    const dash = 4.0;
    const gap = 3.0;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    for (double x = rect.left; x < rect.right; x += dash + gap) {
      canvas.drawLine(
        Offset(x, rect.top),
        Offset((x + dash).clamp(rect.left, rect.right), rect.top),
        paint,
      );
      canvas.drawLine(
        Offset(x, rect.bottom),
        Offset((x + dash).clamp(rect.left, rect.right), rect.bottom),
        paint,
      );
    }
    for (double y = rect.top; y < rect.bottom; y += dash + gap) {
      canvas.drawLine(
        Offset(rect.left, y),
        Offset(rect.left, (y + dash).clamp(rect.top, rect.bottom)),
        paint,
      );
      canvas.drawLine(
        Offset(rect.right, y),
        Offset(rect.right, (y + dash).clamp(rect.top, rect.bottom)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) =>
      oldDelegate.color != color;
}
