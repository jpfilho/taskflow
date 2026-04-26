// gantt_segment_widget.dart
//
// Widget extraído de gantt_chart.dart para permitir reuso no ActivityGanttView.
// Representa uma barra arrastável no Gantt (execução, planejamento, deslocamento).
// Suporta drag-to-move, drag-to-resize, context menu (editar, duplicar, excluir)
// e exibição de conflitos de executor e frota.

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../utils/conflict_detection.dart';
import 'common/taskflow_tooltip.dart';
import 'gantt_chart.dart' show GanttPeriod;

/// Widget público para barras arrastáveis do Gantt.
/// Equivale ao antigo `_DraggableSegment` (privado em gantt_chart.dart).
class GanttSegmentWidget extends StatefulWidget {
  final Task task;
  final int segmentIndex;
  final GanttSegment segment;
  final DateTime normalizedStartDate;
  final DateTime normalizedEndDate;
  final double barWidth;
  final double dayWidth;
  final List<GanttPeriod> periods;
  final Color color;
  final Color textColor;
  final List<DateTime>? conflictDays;

  /// Mensagem completa do tooltip (todos os dias); usado quando não há mapa por dia.
  final String? conflictTooltipMessage;

  /// Tooltip por dia: ao passar o mouse no dia, mostra só os conflitos daquele dia.
  final Map<DateTime, String>? conflictTooltipMessageByDay;

  /// Dias de conflito de FROTA (exibição em preto com letras brancas).
  final List<DateTime>? conflictDaysFrota;
  final String? conflictTooltipMessageFrota;
  final Map<DateTime, String>? conflictTooltipMessageByDayFrota;
  final TaskService? taskService;
  final Function()? onTasksUpdated;
  final Function(Task)? onTaskUpdated;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;
  final ValueNotifier<int>? conflictsVersionNotifier;

  const GanttSegmentWidget({
    super.key,
    required this.task,
    required this.segmentIndex,
    required this.segment,
    required this.normalizedStartDate,
    required this.normalizedEndDate,
    required this.barWidth,
    required this.dayWidth,
    required this.periods,
    required this.color,
    this.textColor = Colors.white,
    this.conflictDays,
    this.conflictTooltipMessage,
    this.conflictTooltipMessageByDay,
    this.conflictDaysFrota,
    this.conflictTooltipMessageFrota,
    this.conflictTooltipMessageByDayFrota,
    this.taskService,
    this.onTasksUpdated,
    this.onTaskUpdated,
    this.onDragStart,
    this.onDragEnd,
    this.conflictsVersionNotifier,
  });

  @override
  State<GanttSegmentWidget> createState() => _GanttSegmentWidgetState();
}

enum _DragMode { move, resizeStart, resizeEnd }

class _GanttSegmentWidgetState extends State<GanttSegmentWidget> {
  double? _dragStartX;
  DateTime? _originalStartDate;
  DateTime? _originalEndDate;
  DateTime? _currentStartDate;
  DateTime? _currentEndDate;
  bool _isDragging = false;
  bool _pendingConfirmation = false; // bloqueia drag enquanto aguarda confirmação
  _DragMode? _dragMode;
  static const double _resizeHandleWidth = 8.0;
  OverlayEntry? _dayTooltipOverlay;
  OverlayEntry? _confirmationOverlay;

  @override
  void initState() {
    super.initState();
    widget.conflictsVersionNotifier?.addListener(_onConflictsVersionChanged);
  }

  void _onConflictsVersionChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.conflictsVersionNotifier?.removeListener(_onConflictsVersionChanged);
    _hideDayTooltipOverlay();
    _hideConfirmationOverlay();
    super.dispose();
  }

  void _showDayTooltipOverlay(Offset global, String message) {
    _hideDayTooltipOverlay();
    const double tooltipMaxWidth = 320;
    const double gap = 12;
    final left = (global.dx - tooltipMaxWidth - gap).clamp(
      8.0,
      global.dx - gap - 60,
    );
    _dayTooltipOverlay = OverlayEntry(
      builder: (context) => Positioned(
        left: left,
        top: global.dy + 8,
        width: tooltipMaxWidth,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(4),
          color: Colors.grey[850],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_dayTooltipOverlay!);
  }

  void _hideDayTooltipOverlay() {
    _dayTooltipOverlay?.remove();
    _dayTooltipOverlay = null;
  }

  // ── Overlay de confirmação (Salvar / Cancelar) ────────────────────────────
  void _showConfirmationOverlay(DateTime start, DateTime end) {
    _hideConfirmationOverlay();
    final RenderBox? rb = context.findRenderObject() as RenderBox?;
    if (rb == null || !rb.attached) return;
    final offset = rb.localToGlobal(Offset.zero);
    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

    _confirmationOverlay = OverlayEntry(
      builder: (ctx) {
        // StatefulBuilder local para atualizar o spinner sem rebuildar o widget pai
        bool isSavingLocal = false;
        return StatefulBuilder(
          builder: (ctx2, setSt) => Positioned(
            left: offset.dx.clamp(8.0, double.infinity),
            top: (offset.dy - 74).clamp(8.0, double.infinity),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '${fmt(start)} → ${fmt(end)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        isSavingLocal
                            ? const SizedBox(
                                width: 68,
                                child: Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                ),
                              )
                            : ElevatedButton.icon(
                                onPressed: () async {
                                  setSt(() => isSavingLocal = true);
                                  await _saveChanges();
                                  if (mounted)
                                    setSt(() => isSavingLocal = false);
                                },
                                icon: const Icon(Icons.check, size: 14),
                                label: const Text('Salvar',
                                    style: TextStyle(fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green[600],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6)),
                                ),
                              ),
                        const SizedBox(width: 6),
                        OutlinedButton.icon(
                          onPressed:
                              isSavingLocal ? null : _cancelChanges,
                          icon: const Icon(Icons.close, size: 14),
                          label: const Text('Cancelar',
                              style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey[700],
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            side: BorderSide(color: Colors.grey[400]!),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    Overlay.of(context).insert(_confirmationOverlay!);
  }

  void _hideConfirmationOverlay() {
    _confirmationOverlay?.remove();
    _confirmationOverlay = null;
  }

  @override
  void didUpdateWidget(GanttSegmentWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final segmentChanged =
        oldWidget.segment.dataInicio != widget.segment.dataInicio ||
        oldWidget.segment.dataFim != widget.segment.dataFim ||
        oldWidget.color != widget.color;
    final conflictsChanged =
        _listsNotEqual(oldWidget.conflictDays, widget.conflictDays) ||
        _listsNotEqual(oldWidget.conflictDaysFrota, widget.conflictDaysFrota) ||
        oldWidget.conflictTooltipMessage != widget.conflictTooltipMessage ||
        oldWidget.conflictTooltipMessageFrota !=
            widget.conflictTooltipMessageFrota;
    if (segmentChanged || conflictsChanged) {
      setState(() {
        if (!_isDragging && segmentChanged) {
          _currentStartDate = null;
          _currentEndDate = null;
        }
      });
    }
  }

  bool _listsNotEqual(List<DateTime>? a, List<DateTime>? b) {
    if ((a == null) != (b == null)) return true;
    if (a == null) return false;
    if (a.length != b!.length) return true;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return true;
    }
    return false;
  }

  _DragMode _getDragMode(double x) {
    if (x < _resizeHandleWidth) return _DragMode.resizeStart;
    if (x > widget.barWidth - _resizeHandleWidth) return _DragMode.resizeEnd;
    return _DragMode.move;
  }

  void _onPanStart(DragStartDetails details) {
    _hideDayTooltipOverlay();
    final dragMode = _getDragMode(details.localPosition.dx);
    setState(() {
      _dragStartX = details.localPosition.dx;
      _originalStartDate = widget.segment.dataInicio;
      _originalEndDate = widget.segment.dataFim;
      _isDragging = true;
      _dragMode = dragMode;
    });
    widget.onDragStart?.call();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_dragStartX == null || _dragMode == null || widget.taskService == null)
      return;

    final deltaX = details.localPosition.dx - _dragStartX!;
    final daysDelta = deltaX / widget.dayWidth;

    if (_dragMode == _DragMode.move && daysDelta.abs() < 0.5) return;

    int roundedDaysDelta;
    if (_dragMode == _DragMode.resizeStart ||
        _dragMode == _DragMode.resizeEnd) {
      if (daysDelta.abs() >= 0.2) {
        roundedDaysDelta = daysDelta.round();
        if (roundedDaysDelta == 0) roundedDaysDelta = daysDelta > 0 ? 1 : -1;
      } else {
        return;
      }
    } else {
      roundedDaysDelta = daysDelta.round();
    }

    if (roundedDaysDelta == 0) return;

    DateTime? newStartDate = _originalStartDate;
    DateTime? newEndDate = _originalEndDate;

    switch (_dragMode!) {
      case _DragMode.move:
        newStartDate = _originalStartDate!.add(
          Duration(days: roundedDaysDelta),
        );
        final duration = _originalEndDate!.difference(_originalStartDate!);
        newEndDate = newStartDate.add(duration);
        final minStart = widget.periods.isNotEmpty
            ? widget.periods.first.start
            : newStartDate;
        final maxEnd = widget.periods.isNotEmpty
            ? widget.periods.last.end
            : newEndDate;
        if (newStartDate.isBefore(minStart) || newEndDate.isAfter(maxEnd))
          return;
        break;
      case _DragMode.resizeStart:
        newStartDate = _originalStartDate!.add(
          Duration(days: roundedDaysDelta),
        );
        if (newStartDate.isAfter(_originalEndDate!))
          newStartDate = _originalEndDate!.subtract(const Duration(days: 1));
        if (widget.periods.isNotEmpty &&
            newStartDate.isBefore(widget.periods.first.start))
          newStartDate = widget.periods.first.start;
        break;
      case _DragMode.resizeEnd:
        newEndDate = _originalEndDate!.add(Duration(days: roundedDaysDelta));
        if (newEndDate.isBefore(_originalStartDate!))
          newEndDate = _originalStartDate!.add(const Duration(days: 1));
        if (widget.periods.isNotEmpty) {
          final maxDate = widget.periods.last.end;
          if (newEndDate.isAfter(maxDate)) newEndDate = maxDate;
        }
        break;
    }

    DateTime normalizeDate(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

    setState(() {
      _currentStartDate = newStartDate != null
          ? normalizeDate(newStartDate)
          : null;
      _currentEndDate = newEndDate != null ? normalizeDate(newEndDate) : null;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    final capturedStart = _currentStartDate;
    final capturedEnd = _currentEndDate;
    final hasMoved = capturedStart != null &&
        capturedEnd != null &&
        widget.taskService != null &&
        (capturedStart != _originalStartDate ||
         capturedEnd != _originalEndDate);

    setState(() {
      _isDragging = false;
      _dragStartX = null;
      _dragMode = null;
      if (hasMoved) {
        _pendingConfirmation = true;
      } else {
        _currentStartDate = null;
        _currentEndDate = null;
        _originalStartDate = null;
        _originalEndDate = null;
      }
    });

    if (hasMoved) {
      // usar postFrameCallback para garantir que o RenderBox está na posição final
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showConfirmationOverlay(capturedStart!, capturedEnd!);
      });
    }
    widget.onDragEnd?.call();
  }

  Future<void> _saveChanges() async {
    if (_currentStartDate == null || _currentEndDate == null ||
        widget.taskService == null) return;
    try {
      final normalizedStart = DateTime(
        _currentStartDate!.year, _currentStartDate!.month, _currentStartDate!.day);
      final normalizedEnd = DateTime(
        _currentEndDate!.year, _currentEndDate!.month, _currentEndDate!.day);
      final isExecutorRow = widget.task.id.contains('_executor_');

      if (isExecutorRow) {
        final parts = widget.task.id.split('_executor_');
        if (parts.length == 2) {
          final mainTaskId = parts[0];
          final executorId = parts[1];
          final mainTask = await widget.taskService!.getTaskById(mainTaskId);
          if (mainTask != null) {
            final updatedEPs = List<ExecutorPeriod>.from(mainTask.executorPeriods);
            final epIdx = updatedEPs.indexWhere((ep) => ep.executorId == executorId);
            if (epIdx >= 0) {
              final ep = updatedEPs[epIdx];
              final updatedPeriods = List<GanttSegment>.from(ep.periods);
              if (widget.segmentIndex < updatedPeriods.length) {
                updatedPeriods[widget.segmentIndex] = GanttSegment(
                  label: widget.segment.label,
                  tipo: widget.segment.tipo,
                  tipoPeriodo: widget.segment.tipoPeriodo,
                  dataInicio: normalizedStart,
                  dataFim: normalizedEnd,
                );
                updatedEPs[epIdx] = ExecutorPeriod(
                  executorId: ep.executorId,
                  executorNome: ep.executorNome,
                  periods: updatedPeriods,
                );
              }
            }
            final updatedTask = mainTask.copyWith(
              executorPeriods: updatedEPs,
              dataAtualizacao: DateTime.now(),
            );
            await widget.taskService!.updateTask(mainTaskId, updatedTask);
          }
        }
      } else {
        final updatedSegments = List<GanttSegment>.from(widget.task.ganttSegments);
        updatedSegments[widget.segmentIndex] = GanttSegment(
          label: widget.segment.label,
          tipo: widget.segment.tipo,
          tipoPeriodo: widget.segment.tipoPeriodo,
          dataInicio: normalizedStart,
          dataFim: normalizedEnd,
        );
        final updatedTask = widget.task.copyWith(
          ganttSegments: updatedSegments,
          dataInicio: updatedSegments.map((s) => s.dataInicio).reduce((a, b) => a.isBefore(b) ? a : b),
          dataFim: updatedSegments.map((s) => s.dataFim).reduce((a, b) => a.isAfter(b) ? a : b),
          dataAtualizacao: DateTime.now(),
        );
        final savedTask = await widget.taskService!.updateTask(widget.task.id, updatedTask);
        if (savedTask != null) {
          widget.onTaskUpdated?.call(savedTask);
        } else {
          widget.onTasksUpdated?.call();
        }
      }

      _hideConfirmationOverlay();
      if (mounted) {
        setState(() {
          _pendingConfirmation = false;
          _originalStartDate = null;
          _originalEndDate = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Período atualizado com sucesso!'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
      widget.onTasksUpdated?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }



  void _cancelChanges() {
    _hideConfirmationOverlay();
    setState(() {
      _currentStartDate = null;
      _currentEndDate = null;
      _originalStartDate = null;
      _originalEndDate = null;
      _pendingConfirmation = false;
    });
  }

  void _showContextMenu(BuildContext context, Offset position) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    showMenu<void>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 0, 0),
        Rect.fromLTWH(0, 0, overlay.size.width, overlay.size.height),
      ),
      items: [
        PopupMenuItem<void>(
          child: const Row(
            children: [
              Icon(Icons.content_copy, size: 20),
              SizedBox(width: 8),
              Text('Duplicar Período'),
            ],
          ),
          onTap: () => Future.delayed(
            const Duration(milliseconds: 100),
            () => _duplicatePeriod(),
          ),
        ),
        PopupMenuItem<void>(
          child: const Row(
            children: [
              Icon(Icons.edit, size: 20),
              SizedBox(width: 8),
              Text('Editar Período'),
            ],
          ),
          onTap: () => Future.delayed(
            const Duration(milliseconds: 100),
            () => _showEditPeriodDialog(context),
          ),
        ),
        PopupMenuItem<void>(
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 20),
              SizedBox(width: 8),
              Text('Ver Detalhes'),
            ],
          ),
          onTap: () => Future.delayed(
            const Duration(milliseconds: 100),
            () => _showSegmentDetails(context),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<void>(
          child: const Row(
            children: [
              Icon(Icons.delete_outline, size: 20, color: Colors.red),
              SizedBox(width: 8),
              Text('Excluir Período', style: TextStyle(color: Colors.red)),
            ],
          ),
          onTap: () => Future.delayed(
            const Duration(milliseconds: 100),
            () => _deletePeriod(context),
          ),
        ),
      ],
    );
  }

  Future<void> _duplicatePeriod() async {
    if (widget.taskService == null) return;
    final duration =
        widget.segment.dataFim.difference(widget.segment.dataInicio).inDays + 1;
    final normalizedEnd = DateTime(
      widget.segment.dataFim.year,
      widget.segment.dataFim.month,
      widget.segment.dataFim.day,
    );
    final newStart = DateTime(
      normalizedEnd.year,
      normalizedEnd.month,
      normalizedEnd.day,
    ).add(const Duration(days: 3));
    final newEnd = newStart.add(Duration(days: duration - 1));
    final newSegment = GanttSegment(
      label: widget.segment.label,
      tipo: widget.segment.tipo,
      tipoPeriodo: widget.segment.tipoPeriodo,
      dataInicio: newStart,
      dataFim: newEnd,
    );
    final updatedSegments = List<GanttSegment>.from(widget.task.ganttSegments)
      ..add(newSegment);
    final updatedTask = widget.task.copyWith(
      ganttSegments: updatedSegments,
      dataInicio: updatedSegments
          .map((s) => s.dataInicio)
          .reduce((a, b) => a.isBefore(b) ? a : b),
      dataFim: updatedSegments
          .map((s) => s.dataFim)
          .reduce((a, b) => a.isAfter(b) ? a : b),
      dataAtualizacao: DateTime.now(),
    );
    final savedTask = await widget.taskService!.updateTask(
      widget.task.id,
      updatedTask,
    );
    if (savedTask != null) {
      widget.onTaskUpdated?.call(savedTask);
    } else {
      widget.onTasksUpdated?.call();
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Período duplicado adicionado à tarefa "${widget.task.tarefa}"!',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showEditPeriodDialog(BuildContext context) {
    DateTime newStart = widget.segment.dataInicio;
    DateTime newEnd = widget.segment.dataFim;
    String selectedTipo = widget.segment.tipo.toUpperCase().trim();
    const validSegmentTypes = [
      'BEA',
      'FER',
      'COMP',
      'TRN',
      'BSL',
      'APO',
      'OUT',
      'ADM',
    ];
    if (!validSegmentTypes.contains(selectedTipo)) selectedTipo = 'OUT';
    String selectedTipoPeriodo = widget.segment.tipoPeriodo
        .toUpperCase()
        .trim();
    const validPeriodTypes = ['EXECUCAO', 'PLANEJAMENTO', 'DESLOCAMENTO'];
    if (!validPeriodTypes.contains(selectedTipoPeriodo))
      selectedTipoPeriodo = 'EXECUCAO';

    final tiposSegmento = [
      {'codigo': 'BEA', 'descricao': 'BEA'},
      {'codigo': 'FER', 'descricao': 'Ferramenta'},
      {'codigo': 'COMP', 'descricao': 'Componente'},
      {'codigo': 'TRN', 'descricao': 'Linha de Transmissão'},
      {'codigo': 'BSL', 'descricao': 'Baseline'},
      {'codigo': 'APO', 'descricao': 'Apoio'},
      {'codigo': 'ADM', 'descricao': 'Administrativo'},
      {'codigo': 'OUT', 'descricao': 'Outros'},
    ];
    final tiposPeriodo = [
      {'codigo': 'EXECUCAO', 'descricao': 'Execução'},
      {'codigo': 'PLANEJAMENTO', 'descricao': 'Planejamento'},
      {'codigo': 'DESLOCAMENTO', 'descricao': 'Deslocamento'},
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Editar Período'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Segmento: ${widget.segment.label}'),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedTipo,
                  decoration: const InputDecoration(
                    labelText: 'Tipo do Segmento',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: tiposSegmento
                      .map(
                        (t) => DropdownMenuItem<String>(
                          value: t['codigo'] as String,
                          child: Text('${t['codigo']} - ${t['descricao']}'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedTipo = v);
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedTipoPeriodo,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de Período',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: tiposPeriodo
                      .map(
                        (t) => DropdownMenuItem<String>(
                          value: t['codigo'] as String,
                          child: Text('${t['codigo']} - ${t['descricao']}'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null)
                      setDialogState(() {
                        selectedTipoPeriodo = v;
                        if (v == 'DESLOCAMENTO') newEnd = newStart;
                      });
                  },
                ),
                const SizedBox(height: 16),
                if (selectedTipoPeriodo == 'EXECUCAO' ||
                    selectedTipoPeriodo == 'PLANEJAMENTO')
                  ListTile(
                    title: const Text('Período'),
                    subtitle: Text(
                      '${newStart.day}/${newStart.month}/${newStart.year} - ${newEnd.day}/${newEnd.month}/${newEnd.year}',
                    ),
                    trailing: const Icon(Icons.date_range),
                    onTap: () async {
                      final dr = await showDateRangePicker(
                        context: context,
                        initialDateRange: DateTimeRange(
                          start: newStart,
                          end: newEnd,
                        ),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (dr != null)
                        setDialogState(() {
                          newStart = dr.start;
                          newEnd = dr.end;
                        });
                    },
                  )
                else
                  Column(
                    children: [
                      ListTile(
                        title: const Text('Data de Ida'),
                        subtitle: Text(
                          '${newStart.day}/${newStart.month}/${newStart.year}',
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: newStart,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (d != null) setDialogState(() => newStart = d);
                        },
                      ),
                      ListTile(
                        title: const Text('Data de Volta'),
                        subtitle: Text(
                          '${newEnd.day}/${newEnd.month}/${newEnd.year}',
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: newEnd,
                            firstDate: newStart,
                            lastDate: DateTime(2030),
                          );
                          if (d != null)
                            setDialogState(() {
                              newEnd = d;
                              if (newEnd.isBefore(newStart))
                                newStart = newEnd.subtract(
                                  const Duration(days: 1),
                                );
                            });
                        },
                      ),
                    ],
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (widget.taskService == null) return;
                final tipoFinal =
                    validSegmentTypes.contains(
                      selectedTipo.toUpperCase().trim(),
                    )
                    ? selectedTipo.toUpperCase().trim()
                    : 'OUT';
                final tipoPeriodoFinal =
                    validPeriodTypes.contains(
                      selectedTipoPeriodo.toUpperCase().trim(),
                    )
                    ? selectedTipoPeriodo.toUpperCase().trim()
                    : 'EXECUCAO';
                final finalDataFim = tipoPeriodoFinal == 'DESLOCAMENTO'
                    ? newStart
                    : newEnd;
                final updatedSegments = List<GanttSegment>.from(
                  widget.task.ganttSegments,
                );
                updatedSegments[widget.segmentIndex] = GanttSegment(
                  label: widget.segment.label,
                  tipo: tipoFinal,
                  tipoPeriodo: tipoPeriodoFinal,
                  dataInicio: newStart,
                  dataFim: finalDataFim,
                );
                final updatedTask = widget.task.copyWith(
                  ganttSegments: updatedSegments,
                  dataInicio: updatedSegments
                      .map((s) => s.dataInicio)
                      .reduce((a, b) => a.isBefore(b) ? a : b),
                  dataFim: updatedSegments
                      .map((s) => s.dataFim)
                      .reduce((a, b) => a.isAfter(b) ? a : b),
                  dataAtualizacao: DateTime.now(),
                );
                final savedTask = await widget.taskService!.updateTask(
                  widget.task.id,
                  updatedTask,
                );
                if (savedTask != null) {
                  widget.onTaskUpdated?.call(savedTask);
                } else {
                  widget.onTasksUpdated?.call();
                }
                Navigator.pop(context);
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Período atualizado com sucesso!'),
                    ),
                  );
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSegmentDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.segment.label),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _detailRow('Tarefa', widget.task.tarefa),
            _detailRow('Tipo', widget.segment.tipo),
            _detailRow(
              'Início',
              '${widget.segment.dataInicio.day}/${widget.segment.dataInicio.month}/${widget.segment.dataInicio.year}',
            ),
            _detailRow(
              'Fim',
              '${widget.segment.dataFim.day}/${widget.segment.dataFim.month}/${widget.segment.dataFim.year}',
            ),
            _detailRow(
              'Duração',
              '${widget.segment.dataFim.difference(widget.segment.dataInicio).inDays + 1} dias',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _deletePeriod(BuildContext context) {
    if (widget.task.ganttSegments.length <= 1) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não é possível excluir o último período da tarefa!'),
            backgroundColor: Colors.orange,
          ),
        );
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text(
          'Deseja realmente excluir o período "${widget.segment.label}"?\n\nEsta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmDeletePeriod();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePeriod() async {
    if (widget.taskService == null) return;
    final updatedSegments = List<GanttSegment>.from(widget.task.ganttSegments)
      ..removeAt(widget.segmentIndex);
    if (updatedSegments.isEmpty) return;
    final updatedTask = widget.task.copyWith(
      ganttSegments: updatedSegments,
      dataAtualizacao: DateTime.now(),
    );
    final savedTask = await widget.taskService!.updateTask(
      widget.task.id,
      updatedTask,
    );
    if (savedTask != null) {
      widget.onTaskUpdated?.call(savedTask);
    } else {
      widget.onTasksUpdated?.call();
    }
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Período "${widget.segment.label}" excluído com sucesso!',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  int _getPeriodIndexForDate(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    for (int i = 0; i < widget.periods.length; i++) {
      final p = widget.periods[i];
      if (!d.isBefore(p.start) && d.isBefore(p.end)) return i;
    }
    if (widget.periods.isEmpty) return 0;
    if (d.isBefore(widget.periods.first.start)) return 0;
    return widget.periods.length - 1;
  }

  bool _periodOverlapsConflict(GanttPeriod p, List<DateTime> conflictDays) {
    for (final d in conflictDays) {
      final day = DateTime(d.year, d.month, d.day);
      if (!day.isBefore(p.start) && day.isBefore(p.end)) return true;
    }
    return false;
  }

  double _getOffsetForDate(DateTime date) {
    if (widget.periods.isEmpty) return 0;
    return _getPeriodIndexForDate(date) * widget.dayWidth;
  }

  double _getBarWidthForRange(DateTime start, DateTime end) {
    if (widget.periods.isEmpty) return widget.dayWidth;
    final dStart = DateTime(start.year, start.month, start.day);
    final dEnd = DateTime(end.year, end.month, end.day);
    int i0 = _getPeriodIndexForDate(dStart);
    int i1 = _getPeriodIndexForDate(dEnd);
    if (i0 > i1) i1 = i0;
    return math.max(
      widget.dayWidth * 0.5,
      (i1 - i0 + 1) * widget.dayWidth,
    );
  }

  double _getCurrentBarWidth() {
    if (_currentStartDate != null && _currentEndDate != null)
      return _getBarWidthForRange(_currentStartDate!, _currentEndDate!);
    return widget.barWidth;
  }

  double _getCurrentOffset() {
    if (_currentStartDate != null)
      return _getOffsetForDate(_currentStartDate!) -
          _getOffsetForDate(widget.segment.dataInicio);
    return 0.0;
  }

  Widget _buildSegmentContent(
    double barWidth, {
    Color? segmentTextColorOverride,
  }) {
    final textColor = segmentTextColorOverride ?? widget.textColor;
    final tipoPeriodo = widget.segment.tipoPeriodo.toUpperCase().trim();
    // Segmentos de planejamento e deslocamento não exibem ícone nem texto —
    // apenas a cor da barra é suficiente para identificá-los visualmente.
    if (tipoPeriodo == 'PLANEJAMENTO' || tipoPeriodo == 'DESLOCAMENTO') {
      return const SizedBox.shrink();
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.task.locais.isNotEmpty)
          Text(
            _getTruncatedText(widget.task.locais.join(', '), barWidth),
            style: TextStyle(
              color: textColor,
              fontSize: _getOptimalFontSize(barWidth),
              fontWeight: FontWeight.normal,
              shadows: [
                Shadow(
                  offset: const Offset(0.5, 0.5),
                  blurRadius: 1.0,
                  color: Colors.black.withOpacity(0.5),
                ),
              ],
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            textAlign: TextAlign.center,
          ),
        if (widget.task.tarefa.isNotEmpty)
          Text(
            _getTruncatedText(widget.task.tarefa, barWidth),
            style: TextStyle(
              color: textColor,
              fontSize: _getOptimalFontSize(barWidth),
              fontWeight: FontWeight.normal,
              shadows: [
                Shadow(
                  offset: const Offset(0.5, 0.5),
                  blurRadius: 1.0,
                  color: Colors.black.withOpacity(0.5),
                ),
              ],
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            textAlign: TextAlign.center,
          ),
      ],
    );
  }

  String _getTruncatedText(String text, double barWidth) {
    final availableWidth = barWidth - 8;
    if (availableWidth < 20) return '';
    final maxChars = (availableWidth / 5).floor();
    return text.length > maxChars
        ? '${text.substring(0, maxChars - 3)}...'
        : text;
  }

  double _getOptimalFontSize(double barWidth) {
    if (barWidth < 50) return 7.0;
    if (barWidth < 80) return 8.0;
    if (barWidth < 120) return 9.0;
    if (barWidth < 180) return 10.0;
    return 11.0;
  }

  String _getExecutorLabel() {
    final t = widget.task;
    if (t.executor.trim().isNotEmpty) return t.executor.trim();
    if (t.executores.isNotEmpty)
      return t.executores
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .join(', ');
    if (t.executorPeriods.isNotEmpty)
      return t.executorPeriods
          .map((ep) => ep.executorNome.trim())
          .where((e) => e.isNotEmpty)
          .join(', ');
    return 'Executor(es) desta tarefa';
  }

  @override
  Widget build(BuildContext context) {
    final isResizing =
        _dragMode == _DragMode.resizeStart || _dragMode == _DragMode.resizeEnd;
    final cursorType = isResizing
        ? SystemMouseCursors.resizeLeftRight
        : SystemMouseCursors.move;
    final currentBarWidth = _getCurrentBarWidth();
    final currentOffset = _getCurrentOffset();
    final effectiveStartDate = _currentStartDate ?? widget.normalizedStartDate;
    final effectiveEndDate = _currentEndDate ?? widget.normalizedEndDate;
    final effectiveEndDateExclusive = DateTime(
      effectiveEndDate.year,
      effectiveEndDate.month,
      effectiveEndDate.day,
    ).add(const Duration(days: 1));
    final segmentPeriods = widget.periods
        .where(
          (p) =>
              effectiveStartDate.isBefore(p.end) &&
              effectiveEndDateExclusive.isAfter(p.start),
        )
        .toList();



    return Transform.translate(
      offset: Offset(currentOffset, 0),
      child: MouseRegion(
        cursor: _isDragging
            ? cursorType
            : (_pendingConfirmation
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: _pendingConfirmation ? null : _onPanStart,
          onPanUpdate: _pendingConfirmation ? null : _onPanUpdate,
          onPanEnd: _pendingConfirmation ? null : _onPanEnd,
          onLongPress: _pendingConfirmation
              ? null
              : () {
                  final RenderBox? rb =
                      context.findRenderObject() as RenderBox?;
                  if (rb != null) {
                    final pos = rb.localToGlobal(
                        Offset(rb.size.width / 2, rb.size.height / 2));
                    _showContextMenu(context, pos);
                  }
                },
          child: _buildSegmentStack(segmentPeriods, currentBarWidth, isResizing),
        ),
      ),
    );
  }

  Widget _buildSegmentStack(
    List<GanttPeriod> segmentPeriods,
    double currentBarWidth,
    bool isResizing,
  ) {
    final hasConflictFrota =
        widget.conflictDaysFrota != null &&
        widget.conflictDaysFrota!.isNotEmpty;
    final stack = Stack(
      children: [
        Row(
          children: segmentPeriods.map((p) {
            final isConflictDayFrota =
                widget.conflictDaysFrota != null &&
                _periodOverlapsConflict(p, widget.conflictDaysFrota!);
            final isConflictDay =
                widget.conflictDays != null &&
                _periodOverlapsConflict(p, widget.conflictDays!);
            final cellColor = isConflictDayFrota
                ? Colors.black
                : isConflictDay
                ? Colors.red[600]!
                : (_isDragging ? widget.color.withOpacity(0.7) : widget.color);
                
            Widget cell = Container(
              width: widget.dayWidth,
              height: 48.0,
              decoration: BoxDecoration(
                color: cellColor,
                borderRadius: BorderRadius.circular(2),
              ),
            );

            if (isConflictDay || isConflictDayFrota) {
              final day = DateTime(p.start.year, p.start.month, p.start.day);
              
              List<String> tasksList = [];
              String executorName = '';
              String title = '';
              String reason = '';
              TooltipSeverity severity = TooltipSeverity.danger;

              if (isConflictDay) {
                title = 'Conflito de agenda';
                executorName = _getExecutorLabel();
                reason = widget.conflictTooltipMessageByDay?[day] ?? 'Mesmo executor alocado em mais de um local/tarefa neste dia.';
                if (widget.taskService != null) {
                  // Se tivermos os ids dos executores, podemos pegar as tarefas de todos eles
                  final executorIds = <String>{};
                  executorIds.addAll(widget.task.executorIds);
                  for (var ep in widget.task.executorPeriods) {
                    if (ep.executorId.isNotEmpty) executorIds.add(ep.executorId);
                  }
                  if (widget.task.executor.isNotEmpty) executorIds.add(widget.task.executor);
                  
                  for (final eid in executorIds) {
                    final descs = ConflictDetection.getConflictDescriptionsForDay(
                      widget.taskService!.tasks, day, eid,
                    );
                    tasksList.addAll(descs);
                  }
                  tasksList = tasksList.toSet().toList()..sort();
                }
              } else if (isConflictDayFrota) {
                title = 'Conflito de Frota';
                executorName = 'Frota(s)';
                severity = TooltipSeverity.warning;
                reason = widget.conflictTooltipMessageByDayFrota?[day] ?? 'A frota está alocada em outra tarefa neste dia.';
                // Como não há função pronta para listar tarefas de frota no ConflictDetection, deixamos genérico
              }

              return TaskFlowTooltip(
                content: TooltipContent(
                  title: title,
                  severity: severity,
                  executor: executorName,
                  reason: reason,
                  tasks: tasksList,
                ),
                child: cell,
              );
            }
            return cell;
          }).toList(),
        ),
        IgnorePointer(
          ignoring: true,
          child: Center(
            child: Container(
              width: currentBarWidth - 1,
              height: 48.0,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(2),
                border: _isDragging
                    ? Border.all(
                        color: isResizing ? Colors.orange : Colors.blue,
                        width: 2,
                      )
                    : null,
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 3.0,
                    vertical: 1.0,
                  ),
                  child: currentBarWidth < 40
                      ? const SizedBox.shrink()
                      : _buildSegmentContent(
                          currentBarWidth,
                          segmentTextColorOverride: hasConflictFrota
                              ? Colors.white
                              : null,
                        ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: _resizeHandleWidth,
          child: Container(
            color: Colors.transparent,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeLeftRight,
              child: Container(),
            ),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: _resizeHandleWidth,
          child: Container(
            color: Colors.transparent,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeLeftRight,
              child: Container(),
            ),
          ),
        ),
        if (!_isDragging) ...[
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 2,
            child: IgnorePointer(
              ignoring: true,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(2),
                    bottomLeft: Radius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 2,
            child: IgnorePointer(
              ignoring: true,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(2),
                    bottomRight: Radius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );

    return stack;
  }
}
