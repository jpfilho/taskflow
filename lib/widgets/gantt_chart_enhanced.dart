import 'package:flutter/material.dart';
import 'package:flutter_gantt/flutter_gantt.dart';
import '../models/task.dart';
import '../services/task_service.dart';

/// GanttChart aprimorado usando o pacote flutter_gantt
/// Mantém compatibilidade com a interface existente
class GanttChartEnhanced extends StatefulWidget {
  final List<Task> tasks;
  final DateTime startDate;
  final DateTime endDate;
  final ScrollController scrollController;
  final TaskService? taskService;
  final Function()? onTasksUpdated;

  const GanttChartEnhanced({
    super.key,
    required this.tasks,
    required this.startDate,
    required this.endDate,
    required this.scrollController,
    this.taskService,
    this.onTasksUpdated,
  });

  @override
  State<GanttChartEnhanced> createState() => _GanttChartEnhancedState();
}

class _GanttChartEnhancedState extends State<GanttChartEnhanced> {
  late GanttController _ganttController;
  List<GanttActivity> _activities = [];

  @override
  void initState() {
    super.initState();
    final daysDiff = widget.endDate.difference(widget.startDate).inDays;
    _ganttController = GanttController(
      startDate: widget.startDate,
      daysViews: daysDiff > 0 ? daysDiff : 30,
    );
    _activities = _convertTasksToActivities(widget.tasks);
    _ganttController.setActivities(_activities);
  }

  @override
  void didUpdateWidget(GanttChartEnhanced oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.tasks.length != widget.tasks.length ||
        oldWidget.startDate != widget.startDate ||
        oldWidget.endDate != widget.endDate) {
      _activities = _convertTasksToActivities(widget.tasks);
      _ganttController.setActivities(_activities);
    }
  }

  @override
  void dispose() {
    _ganttController.dispose();
    super.dispose();
  }

  Color _getTaskColor(String status, String tipo) {
    switch (status) {
      case 'ANDA':
        return Colors.orange;
      case 'CONC':
        return Colors.green;
      case 'PROG':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Color _getSegmentColor(String tipo) {
    switch (tipo) {
      case 'FER':
        return Colors.lightBlue[300]!;
      case 'COMP':
      case 'BSL':
      case 'TRN':
        return Colors.blue[700]!;
      case 'APO':
        return Colors.grey[400]!;
      case 'OUT':
        return Colors.blue[700]!;
      case 'ADM':
        return Colors.blue[700]!;
      case 'BEA':
        return Colors.blue[700]!;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Gantt(
        controller: _ganttController,
        theme: GanttTheme(
          cellHeight: 50.0,
          dayMinWidth: 40.0,
          headerHeight: 40.0,
          todayBackgroundColor: Colors.red[500]!,
          weekendColor: Colors.grey[200]!,
        ),
        activities: _activities,
        showIsoWeek: false,
      ),
    );
  }

  List<GanttActivity> _convertTasksToActivities(List<Task> tasks) {
    final List<GanttActivity> activities = [];

    for (final task in tasks) {
      var startDate = task.dataInicio;
      var endDate = task.dataFim;
      
      if (startDate.isAfter(endDate)) {
        final temp = startDate;
        startDate = endDate;
        endDate = temp;
      }
      
      if (startDate.isAtSameMomentAs(endDate)) {
        endDate = endDate.add(const Duration(days: 1));
      }

      final mainActivity = GanttActivity(
        key: task.id,
        start: startDate,
        end: endDate,
        title: task.tarefa,
        color: _getTaskColor(task.status, task.tipo),
        children: _buildSegmentChildren(task, startDate, endDate),
      );

      activities.add(mainActivity);
    }

    return activities;
  }

  List<GanttActivity>? _buildSegmentChildren(Task task, DateTime parentStart, DateTime parentEnd) {
    if (task.ganttSegments.isEmpty) return null;

    final List<GanttActivity> children = [];

    for (final segment in task.ganttSegments) {
      var segStart = segment.dataInicio;
      var segEnd = segment.dataFim;
      
      if (segStart.isAfter(segEnd)) {
        final temp = segStart;
        segStart = segEnd;
        segEnd = temp;
      }
      
      if (segStart.isAtSameMomentAs(segEnd)) {
        segEnd = segEnd.add(const Duration(days: 1));
      }

      if (segStart.isBefore(parentStart)) {
        segStart = parentStart;
      }
      if (segEnd.isAfter(parentEnd)) {
        segEnd = parentEnd;
      }
      
      if (segStart.isAfter(parentEnd) || segEnd.isBefore(parentStart)) {
        segStart = parentStart;
        segEnd = parentStart.add(const Duration(days: 1));
      }
      
      if (segStart.isAfter(segEnd)) {
        segStart = parentStart;
        segEnd = parentStart.add(const Duration(days: 1));
      }

      children.add(
        GanttActivity(
          key: '${task.id}_${segment.label}',
          start: segStart,
          end: segEnd,
          title: segment.label,
          color: _getSegmentColor(segment.tipo),
        ),
      );
    }

    return children.isEmpty ? null : children;
  }
}
