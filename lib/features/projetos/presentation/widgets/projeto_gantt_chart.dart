import 'package:flutter/material.dart';
import 'package:flutter_gantt/flutter_gantt.dart';
import '../../../../design_system/components/feedback/tf_empty_state.dart';
import '../../../../design_system/components/feedback/tf_loading.dart';
import '../../../../design_system/foundations/tf_icons.dart';
import '../../../../design_system/theme/taskflow_theme_extension.dart';
import '../../models/projeto_atividade.dart';
import '../../models/projeto_etapa.dart';
import '../../models/projeto_macroetapa.dart';
import '../../services/projeto_service.dart';
import 'etapa_form_dialog.dart';
import 'macroetapa_form_dialog.dart';
import 'projeto_atividade_form_dialog.dart';

class ProjetoGanttChart extends StatefulWidget {
  final String projetoId;
  final ProjetoService service;

  const ProjetoGanttChart({
    super.key,
    required this.projetoId,
    required this.service,
  });

  @override
  State<ProjetoGanttChart> createState() => _ProjetoGanttChartState();
}

class _ProjetoGanttChartState extends State<ProjetoGanttChart> {
  bool _isLoading = true;
  GanttController? _ganttController;
  List<GanttActivity> _activities = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final macroetapas = await widget.service.getMacroetapas(widget.projetoId);
      final List<GanttActivity> activities = [];
      DateTime? minDate;
      DateTime? maxDate;

      for (var macro in macroetapas) {
        final etapas = await widget.service.getEtapas(macro.id);

        DateTime? macroMinDate;
        DateTime? macroMaxDate;
        final List<GanttActivity> macroChildren = [];

        for (var etapa in etapas) {
          final atividades = await widget.service.getAtividades(etapa.id);

          DateTime? etapaMinDate;
          DateTime? etapaMaxDate;
          final List<GanttActivity> etapaChildren = [];

          for (var ativ in atividades) {
            final start = ativ.dataInicioPrevista ?? DateTime.now();
            final end = ativ.dataFimPrevista ?? start.add(const Duration(days: 1));

            if (etapaMinDate == null || start.isBefore(etapaMinDate)) etapaMinDate = start;
            if (etapaMaxDate == null || end.isAfter(etapaMaxDate)) etapaMaxDate = end;

            etapaChildren.add(GanttActivity(
              key: ativ.id,
              start: start,
              end: end,
              title: ativ.nome,
              color: _getColorForStatus(ativ.status),
              onCellTap: (_) async {
                final res = await showDialog<ProjetoAtividade>(
                  context: context,
                  builder: (_) => ProjetoAtividadeFormDialog(
                    projetoId: widget.projetoId,
                    macroetapaId: macro.id,
                    etapaId: etapa.id,
                    atividade: ativ,
                  ),
                );
                if (res != null) {
                  await widget.service.updateAtividade(res);
                  _loadData();
                }
              },
            ));
          }

          if (etapaMinDate != null && etapaMaxDate != null) {
            if (macroMinDate == null || etapaMinDate.isBefore(macroMinDate)) macroMinDate = etapaMinDate;
            if (macroMaxDate == null || etapaMaxDate.isAfter(macroMaxDate)) macroMaxDate = etapaMaxDate;

            macroChildren.add(GanttActivity(
              key: etapa.id,
              start: etapaMinDate,
              end: etapaMaxDate,
              title: etapa.nome,
              color: Colors.blueAccent.withValues(alpha: 0.7),
              children: etapaChildren,
              onCellTap: (_) async {
                final e = await showDialog<ProjetoEtapa>(
                  context: context,
                  builder: (_) => EtapaFormDialog(
                    projetoId: widget.projetoId,
                    macroetapaId: macro.id,
                    etapa: etapa,
                  ),
                );
                if (e != null) {
                  await widget.service.updateEtapa(e);
                  _loadData();
                }
              },
            ));
          }
        }

        if (macroMinDate != null && macroMaxDate != null) {
          if (minDate == null || macroMinDate.isBefore(minDate)) minDate = macroMinDate;
          if (maxDate == null || macroMaxDate.isAfter(maxDate)) maxDate = macroMaxDate;

          activities.add(GanttActivity(
            key: macro.id,
            start: macroMinDate,
            end: macroMaxDate,
            title: macro.nome,
            color: Colors.indigo.withValues(alpha: 0.8),
            children: macroChildren,
            onCellTap: (_) async {
              final m = await showDialog<ProjetoMacroetapa>(
                context: context,
                builder: (_) => MacroetapaFormDialog(
                  projetoId: widget.projetoId,
                  macroetapa: macro,
                ),
              );
              if (m != null) {
                await widget.service.updateMacroetapa(m);
                _loadData();
              }
            },
          ));
        }
      }

      if (minDate != null && maxDate != null) {
        final daysDiff = maxDate.difference(minDate).inDays;
        _ganttController = GanttController(
          startDate: minDate.subtract(const Duration(days: 2)), // margem
          daysViews: daysDiff > 0 ? daysDiff + 5 : 30, // margem no fim
        );
      } else {
        _ganttController = GanttController(
          startDate: DateTime.now().subtract(const Duration(days: 2)),
          daysViews: 30,
        );
      }

      _activities = activities;
    } catch (e) {
      debugPrint('Erro ao carregar Gantt: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Color _getColorForStatus(String status) {
    switch (status) {
      case 'PENDENTE':
        return Colors.grey.shade600;
      case 'EM_ANDAMENTO':
      case 'ANDAMENTO':
        return Colors.orange.shade700;
      case 'CONCLUIDA':
      case 'CONCLUIDO':
        return Colors.green.shade600;
      case 'CANCELADA':
      case 'CANCELADO':
        return Colors.red.shade600;
      default:
        return Colors.blue.shade600;
    }
  }

  @override
  void dispose() {
    _ganttController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;

    if (_isLoading) {
      return const Center(child: TFLoading(message: 'Gerando cronograma Gantt...'));
    }

    if (_activities.isEmpty) {
      return const Center(
        child: TFEmptyState(
          title: 'Cronograma Gantt Indisponível',
          description: 'Nenhuma atividade com datas previstas encontrada para gerar o gráfico temporal.',
          icon: TFIcons.calendar,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Gantt(
        controller: _ganttController!,
        theme: GanttTheme(
          cellHeight: 40.0,
          dayMinWidth: 40.0,
          headerHeight: 40.0,
          todayBackgroundColor: colors.danger.withValues(alpha: 0.15),
          weekendColor: colors.borderSubtle.withValues(alpha: 0.2),
        ),
        activities: _activities,
        showIsoWeek: false,
      ),
    );
  }
}
