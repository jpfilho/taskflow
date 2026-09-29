import 'package:flutter/material.dart';
import '../../../../design_system/components/buttons/tf_button.dart';
import '../../../../design_system/components/buttons/tf_icon_button.dart';
import '../../../../design_system/components/cards/tf_card.dart';
import '../../../../design_system/components/feedback/tf_empty_state.dart';
import '../../../../design_system/components/feedback/tf_loading.dart';
import '../../../../design_system/components/status/tf_status_badge.dart';
import '../../../../design_system/foundations/tf_breakpoints.dart';
import '../../../../design_system/foundations/tf_icons.dart';
import '../../../../design_system/foundations/tf_radius.dart';
import '../../../../design_system/theme/taskflow_theme_extension.dart';
import '../../models/projeto.dart';
import '../../models/projeto_atividade.dart';
import '../../models/projeto_etapa.dart';
import '../../models/projeto_macroetapa.dart';
import '../../services/projeto_service.dart';
import 'etapa_form_dialog.dart';
import 'macroetapa_form_dialog.dart';
import 'projeto_atividade_form_dialog.dart';
import 'projeto_gantt_chart.dart';
import 'projeto_status_mapper.dart';

enum _ViewMode { wbs, gantt }

class CronogramaTab extends StatefulWidget {
  final Projeto projeto;
  final ProjetoService service;

  const CronogramaTab({super.key, required this.projeto, required this.service});

  @override
  State<CronogramaTab> createState() => _CronogramaTabState();
}

class _CronogramaTabState extends State<CronogramaTab> {
  List<ProjetoMacroetapa> _macroetapas = [];
  bool _isLoading = true;
  _ViewMode _currentMode = _ViewMode.wbs;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _isLoading = true);
    try {
      _macroetapas = await widget.service.getMacroetapas(widget.projeto.id);
      _macroetapas.sort((a, b) => a.ordem.compareTo(b.ordem));
    } catch (e) {
      debugPrint('Erro ao carregar macroetapas: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _novaMacroetapa() async {
    final m = await showDialog<ProjetoMacroetapa>(
      context: context,
      builder: (_) => MacroetapaFormDialog(
        projetoId: widget.projeto.id,
        proximaOrdem: _macroetapas.length + 1,
      ),
    );
    if (m != null) {
      await widget.service.createMacroetapa(m);
      _carregar();
    }
  }

  void _onReorderMacroetapas(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = _macroetapas.removeAt(oldIndex);
    _macroetapas.insert(newIndex, item);
    setState(() {});
    for (int i = 0; i < _macroetapas.length; i++) {
      final m = _macroetapas[i];
      if (m.ordem != i + 1) {
        final updated = ProjetoMacroetapa(
          id: m.id,
          projetoId: m.projetoId,
          ordem: i + 1,
          nome: m.nome,
          descricao: m.descricao,
          status: m.status,
          createdAt: m.createdAt,
          updatedAt: m.updatedAt,
          deletedAt: m.deletedAt,
          syncStatus: m.syncStatus,
        );
        _macroetapas[i] = updated;
        await widget.service.updateMacroetapa(updated);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final spacing = context.tfSpacing;
    final typography = context.tfTypography;

    if (_isLoading) {
      return const Center(child: TFLoading(message: 'Carregando estrutura analítica do projeto (WBS)...'));
    }

    return Column(
      children: [
        // Header de Ações do Cronograma (Switch WBS/Gantt e Botão Nova Macroetapa)
        Padding(
          padding: EdgeInsets.all(spacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Estrutura Analítica & Cronograma',
                style: typography.sectionTitle.copyWith(color: colors.textPrimary),
              ),
              Row(
                children: [
                  SegmentedButton<_ViewMode>(
                    segments: const [
                      ButtonSegment(
                        value: _ViewMode.wbs,
                        icon: Icon(TFIcons.task, size: 16),
                        label: Text('WBS (Árvore)'),
                      ),
                      ButtonSegment(
                        value: _ViewMode.gantt,
                        icon: Icon(Icons.bar_chart_rounded, size: 16),
                        label: Text('Gantt'),
                      ),
                    ],
                    selected: {_currentMode},
                    style: ButtonStyle(
                      textStyle: WidgetStatePropertyAll(typography.labelMedium),
                    ),
                    onSelectionChanged: (Set<_ViewMode> newSelection) {
                      setState(() {
                        _currentMode = newSelection.first;
                      });
                    },
                  ),
                  SizedBox(width: spacing.sm),
                  TFButton(
                    label: 'Nova Macroetapa',
                    leadingIcon: TFIcons.add,
                    onPressed: _novaMacroetapa,
                  ),
                ],
              ),
            ],
          ),
        ),

        // Conteúdo: Gantt Chart ou Árvore WBS Hierárquica
        Expanded(
          child: _currentMode == _ViewMode.gantt
              ? ProjetoGanttChart(projetoId: widget.projeto.id, service: widget.service)
              : _macroetapas.isEmpty
                  ? Center(
                      child: TFEmptyState(
                        title: 'Nenhuma macroetapa definida',
                        description: 'Crie os grandes blocos de trabalho para detalhar etapas e atividades.',
                        icon: TFIcons.task,
                        action: TFButton(
                          label: 'Nova Macroetapa',
                          leadingIcon: TFIcons.add,
                          onPressed: _novaMacroetapa,
                        ),
                      ),
                    )
                  : ReorderableListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.xs),
                      itemCount: _macroetapas.length,
                      onReorder: _onReorderMacroetapas,
                      itemBuilder: (context, index) {
                        final macro = _macroetapas[index];
                        return Padding(
                          key: ValueKey(macro.id),
                          padding: EdgeInsets.only(bottom: spacing.sm),
                          child: MacroetapaTile(
                            macroetapa: macro,
                            service: widget.service,
                            onChanged: _carregar,
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class MacroetapaTile extends StatefulWidget {
  final ProjetoMacroetapa macroetapa;
  final ProjetoService service;
  final VoidCallback onChanged;

  const MacroetapaTile({
    super.key,
    required this.macroetapa,
    required this.service,
    required this.onChanged,
  });

  @override
  State<MacroetapaTile> createState() => _MacroetapaTileState();
}

class _MacroetapaTileState extends State<MacroetapaTile> {
  List<ProjetoEtapa> _etapas = [];
  bool _isLoading = false;

  Future<void> _carregarEtapas() async {
    setState(() => _isLoading = true);
    try {
      _etapas = await widget.service.getEtapas(widget.macroetapa.id);
      _etapas.sort((a, b) => a.ordem.compareTo(b.ordem));
    } catch (e) {
      debugPrint('Erro ao carregar etapas: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _novaEtapa() async {
    final e = await showDialog<ProjetoEtapa>(
      context: context,
      builder: (_) => EtapaFormDialog(
        projetoId: widget.macroetapa.projetoId,
        macroetapaId: widget.macroetapa.id,
        proximaOrdem: _etapas.length + 1,
      ),
    );
    if (e != null) {
      await widget.service.createEtapa(e);
      _carregarEtapas();
    }
  }

  void _onReorderEtapas(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = _etapas.removeAt(oldIndex);
    _etapas.insert(newIndex, item);
    setState(() {});
    for (int i = 0; i < _etapas.length; i++) {
      final e = _etapas[i];
      if (e.ordem != i + 1) {
        final updated = ProjetoEtapa(
          id: e.id,
          projetoId: e.projetoId,
          macroetapaId: e.macroetapaId,
          ordem: i + 1,
          nome: e.nome,
          descricao: e.descricao,
          status: e.status,
          createdAt: e.createdAt,
          updatedAt: e.updatedAt,
          deletedAt: e.deletedAt,
          syncStatus: e.syncStatus,
        );
        _etapas[i] = updated;
        await widget.service.updateEtapa(updated);
      }
    }
  }

  void _editar() async {
    final m = await showDialog<ProjetoMacroetapa>(
      context: context,
      builder: (_) => MacroetapaFormDialog(
        projetoId: widget.macroetapa.projetoId,
        macroetapa: widget.macroetapa,
      ),
    );
    if (m != null) {
      await widget.service.updateMacroetapa(m);
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final spacing = context.tfSpacing;
    final typography = context.tfTypography;

    return TFCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: Material(
          type: MaterialType.transparency,
          child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.xs),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: spacing.xs, vertical: spacing.xxs),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: TFRadius.borderRadiusSm,
                ),
                child: Text(
                  '${widget.macroetapa.ordem}',
                  style: typography.labelSmall.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: Text(
                  widget.macroetapa.nome,
                  style: typography.cardTitle.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(width: spacing.sm),
              TFStatusBadge(
                label: widget.macroetapa.status,
                severity: ProjetoStatusMapper.mapProjetoStatus(widget.macroetapa.status),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TFIconButton(
                icon: TFIcons.edit,
                tooltip: 'Editar Macroetapa',
                onPressed: _editar,
              ),
              TFIconButton(
                icon: TFIcons.add,
                tooltip: 'Nova Etapa',
                onPressed: _novaEtapa,
              ),
              const Icon(Icons.expand_more_rounded),
            ],
          ),
          onExpansionChanged: (expanded) {
            if (expanded && _etapas.isEmpty) {
              _carregarEtapas();
            }
          },
          children: _isLoading
              ? [
                  Padding(
                    padding: EdgeInsets.all(spacing.md),
                    child: const Center(child: TFLoading(message: 'Carregando etapas...')),
                  )
                ]
              : [
                  if (_etapas.isEmpty)
                    Padding(
                      padding: EdgeInsets.all(spacing.md),
                      child: Text(
                        'Nenhuma etapa cadastrada nesta macroetapa. Clique em "+" para adicionar.',
                        style: typography.bodySmall.copyWith(color: colors.textSecondary),
                      ),
                    )
                  else
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs),
                      itemCount: _etapas.length,
                      onReorder: _onReorderEtapas,
                      itemBuilder: (context, index) {
                        final e = _etapas[index];
                        return EtapaTile(
                          key: ValueKey(e.id),
                          etapa: e,
                          service: widget.service,
                          onChanged: _carregarEtapas,
                        );
                      },
                    )
                ],
          ),
        ),
      ),
    );
  }
}

class EtapaTile extends StatefulWidget {
  final ProjetoEtapa etapa;
  final ProjetoService service;
  final VoidCallback onChanged;

  const EtapaTile({
    super.key,
    required this.etapa,
    required this.service,
    required this.onChanged,
  });

  @override
  State<EtapaTile> createState() => _EtapaTileState();
}

class _EtapaTileState extends State<EtapaTile> {
  List<ProjetoAtividade> _atividades = [];
  bool _isLoading = false;

  Future<void> _carregarAtividades() async {
    setState(() => _isLoading = true);
    try {
      _atividades = await widget.service.getAtividades(widget.etapa.id);
      _atividades.sort((a, b) => a.ordem.compareTo(b.ordem));
    } catch (e) {
      debugPrint('Erro ao carregar atividades: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _novaAtividade() async {
    final a = await showDialog<ProjetoAtividade>(
      context: context,
      builder: (_) => ProjetoAtividadeFormDialog(
        projetoId: widget.etapa.projetoId,
        macroetapaId: widget.etapa.macroetapaId,
        etapaId: widget.etapa.id,
        proximaOrdem: _atividades.length + 1,
      ),
    );
    if (a != null) {
      await widget.service.createAtividade(a);
      _carregarAtividades();
    }
  }

  void _onReorderAtividades(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = _atividades.removeAt(oldIndex);
    _atividades.insert(newIndex, item);
    setState(() {});
    for (int i = 0; i < _atividades.length; i++) {
      final a = _atividades[i];
      if (a.ordem != i + 1) {
        final updated = ProjetoAtividade(
          id: a.id,
          projetoId: a.projetoId,
          macroetapaId: a.macroetapaId,
          etapaId: a.etapaId,
          ordem: i + 1,
          nome: a.nome,
          descricao: a.descricao,
          status: a.status,
          peso: a.peso,
          prioridade: a.prioridade,
          horasPrevistas: a.horasPrevistas,
          progresso: a.progresso,
          executorId: a.executorId,
          equipeId: a.equipeId,
          dataInicioPrevista: a.dataInicioPrevista,
          dataFimPrevista: a.dataFimPrevista,
          createdAt: a.createdAt,
          updatedAt: a.updatedAt,
          deletedAt: a.deletedAt,
          syncStatus: a.syncStatus,
        );
        _atividades[i] = updated;
        await widget.service.updateAtividade(updated);
      }
    }
  }

  void _editar() async {
    final e = await showDialog<ProjetoEtapa>(
      context: context,
      builder: (_) => EtapaFormDialog(
        projetoId: widget.etapa.projetoId,
        macroetapaId: widget.etapa.macroetapaId,
        etapa: widget.etapa,
      ),
    );
    if (e != null) {
      await widget.service.updateEtapa(e);
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final spacing = context.tfSpacing;
    final typography = context.tfTypography;
    final isMobile = TFBreakpoints.isMobile(context);

    return Container(
      margin: EdgeInsets.only(
        left: isMobile ? spacing.xs : spacing.lg,
        bottom: spacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceSecondary,
        borderRadius: TFRadius.borderRadiusSm,
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: ExpansionTile(
        tilePadding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xxs),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: spacing.xs, vertical: spacing.xxs),
              decoration: BoxDecoration(
                color: colors.borderSubtle,
                borderRadius: TFRadius.borderRadiusXs,
              ),
              child: Text(
                '${widget.etapa.ordem}',
                style: typography.caption.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(width: spacing.sm),
            Expanded(
              child: Text(
                widget.etapa.nome,
                style: typography.bodyMedium.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(width: spacing.xs),
            TFStatusBadge(
              label: widget.etapa.status,
              severity: ProjetoStatusMapper.mapProjetoStatus(widget.etapa.status),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TFIconButton(
              icon: TFIcons.edit,
              tooltip: 'Editar Etapa',
              onPressed: _editar,
            ),
            TFIconButton(
              icon: TFIcons.add,
              tooltip: 'Nova Atividade',
              onPressed: _novaAtividade,
            ),
            const Icon(Icons.expand_more_rounded, size: 20),
          ],
        ),
        onExpansionChanged: (expanded) {
          if (expanded && _atividades.isEmpty) {
            _carregarAtividades();
          }
        },
        children: _isLoading
            ? [
                Padding(
                  padding: EdgeInsets.all(spacing.sm),
                  child: const Center(child: TFLoading(message: 'Carregando atividades...')),
                )
              ]
            : [
                if (_atividades.isEmpty)
                  Padding(
                    padding: EdgeInsets.all(spacing.sm),
                    child: Text(
                      'Nenhuma atividade cadastrada nesta etapa.',
                      style: typography.bodySmall.copyWith(color: colors.textSecondary),
                    ),
                  )
                else
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.only(
                      left: isMobile ? spacing.xs : spacing.md,
                      right: spacing.xs,
                      bottom: spacing.xs,
                    ),
                    itemCount: _atividades.length,
                    onReorder: _onReorderAtividades,
                    itemBuilder: (context, index) {
                      final a = _atividades[index];
                      return Container(
                        key: ValueKey(a.id),
                        margin: EdgeInsets.symmetric(vertical: spacing.xxs),
                        padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: TFRadius.borderRadiusXs,
                          border: Border.all(color: colors.borderSubtle.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '${a.ordem}.',
                              style: typography.caption.copyWith(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(width: spacing.xs),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a.nome,
                                    style: typography.bodySmall.copyWith(
                                      color: colors.textPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (a.descricao != null && a.descricao!.isNotEmpty)
                                    Text(
                                      a.descricao!,
                                      style: typography.caption.copyWith(color: colors.textSecondary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            SizedBox(width: spacing.xs),
                            TFStatusBadge(
                              label: a.status,
                              severity: ProjetoStatusMapper.mapProjetoStatus(a.status),
                            ),
                            TFIconButton(
                              icon: TFIcons.edit,
                              tooltip: 'Editar Atividade',
                              onPressed: () async {
                                final res = await showDialog<ProjetoAtividade>(
                                  context: context,
                                  builder: (_) => ProjetoAtividadeFormDialog(
                                    projetoId: widget.etapa.projetoId,
                                    macroetapaId: widget.etapa.macroetapaId,
                                    etapaId: widget.etapa.id,
                                    atividade: a,
                                  ),
                                );
                                if (res != null) {
                                  await widget.service.updateAtividade(res);
                                  _carregarAtividades();
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  )
              ],
      ),
    ),
    );
  }
}
