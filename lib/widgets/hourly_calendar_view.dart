import 'package:flutter/material.dart';
import '../models/task.dart';

class HourlyCalendarView extends StatefulWidget {
  final List<Task> tasks;
  final DateTime startDate;
  final DateTime endDate;

  const HourlyCalendarView({
    super.key,
    required this.tasks,
    required this.startDate,
    required this.endDate,
  });

  @override
  State<HourlyCalendarView> createState() => _HourlyCalendarViewState();
}

class _HourlyCalendarViewState extends State<HourlyCalendarView> {
  static const double _hourHeight = 44.0;
  static const double _dayWidth = 220.0;
  static const double _headerHeight = 36.0;
  static const double _timeColWidth = 56.0;

  late final List<DateTime> _days;

  @override
  void initState() {
    super.initState();
    _days = _getDaysInRange(widget.startDate, widget.endDate);
  }

  List<DateTime> _getDaysInRange(DateTime start, DateTime end) {
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    final out = <DateTime>[];
    var cur = s;
    while (!cur.isAfter(e)) {
      out.add(cur);
      cur = cur.add(const Duration(days: 1));
    }
    return out;
  }

  String _weekdayShort(DateTime d) {
    const names = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
    // Dart weekday: 1=Mon..7=Sun
    return names[(d.weekday - 1) % 7];
  }

  List<GanttSegment> _segmentsForDay(Task t, DateTime day) {
    final startDay = DateTime(day.year, day.month, day.day);
    final endDay = startDay.add(const Duration(days: 1));
    final segs = <GanttSegment>[];
    // Prefer executorPeriods if exist, else ganttSegments, else fallback to task range
    if (t.executorPeriods.isNotEmpty) {
      for (final ep in t.executorPeriods) {
        for (final sg in ep.periods) {
          if (sg.dataFim.isAfter(startDay) && sg.dataInicio.isBefore(endDay)) {
            segs.add(sg);
          }
        }
      }
    } else if (t.ganttSegments.isNotEmpty) {
      for (final sg in t.ganttSegments) {
        if (sg.dataFim.isAfter(startDay) && sg.dataInicio.isBefore(endDay)) {
          segs.add(sg);
        }
      }
    } else {
      if (t.dataFim.isAfter(startDay) && t.dataInicio.isBefore(endDay)) {
        segs.add(GanttSegment(
          dataInicio: t.dataInicio,
          dataFim: t.dataFim,
          label: t.tarefa,
          tipo: t.tipo,
        ));
      }
    }
    return segs;
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Coluna de horas
            Column(
              children: [
                const SizedBox(height: _headerHeight, width: _timeColWidth),
                Container(
                  width: _timeColWidth,
                  height: _hourHeight * 24,
                  color: Colors.white,
                  child: Column(
                    children: List.generate(24, (h) {
                      return SizedBox(
                        height: _hourHeight,
                        child: Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 6.0, top: 2),
                            child: Text('${h.toString().padLeft(2, '0')}:00', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
            // Colunas de dias
            ..._days.map((day) {
              final dayTasks = widget.tasks.where((t) => _segmentsForDay(t, day).isNotEmpty).toList();
              return Column(
                children: [
                  Container(
                    width: _dayWidth,
                    height: _headerHeight,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      border: const Border(
                        right: BorderSide(color: Color(0xFFE0E0E0)),
                      ),
                    ),
                    child: Text(
                      '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')} • ${_weekdayShort(day)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  SizedBox(
                    width: _dayWidth,
                    height: _hourHeight * 24,
                    child: Stack(
                      children: [
                        // Grade de horas
                        Column(
                          children: List.generate(24, (h) {
                            return Container(
                              height: _hourHeight,
                              decoration: const BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: Color(0xFFF0F0F0)),
                                  right: BorderSide(color: Color(0xFFE0E0E0)),
                                ),
                              ),
                            );
                          }),
                        ),
                        // Blocos das tarefas
                        ...dayTasks.expand((t) {
                          final segs = _segmentsForDay(t, day);
                          return segs.map((sg) {
                            final dayStart = DateTime(day.year, day.month, day.day);
                            final dayEnd = dayStart.add(const Duration(days: 1));
                            final start = sg.dataInicio.isBefore(dayStart) ? dayStart : sg.dataInicio;
                            final end = sg.dataFim.isAfter(dayEnd) ? dayEnd : sg.dataFim;
                            final startHour = start.hour + (start.minute / 60.0);
                            final endHour = end.hour + (end.minute / 60.0);
                            final top = startHour * _hourHeight;
                            final height = ((endHour - startHour).clamp(0.25, 24.0)) * _hourHeight;
                            return Positioned(
                              left: 6,
                              right: 6,
                              top: top,
                              height: height,
                              child: _TaskBlock(task: t, segment: sg),
                            );
                          });
                        }),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _TaskBlock extends StatelessWidget {
  final Task task;
  final GanttSegment segment;
  const _TaskBlock({required this.task, required this.segment});

  @override
  Widget build(BuildContext context) {
    final bg = Colors.deepPurple.withOpacity(0.15);
    final border = Colors.deepPurple.withOpacity(0.45);
    return Material(
      elevation: 0,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: border, width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.tarefa,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              '${_fmt(segment.dataInicio)} - ${_fmt(segment.dataFim)}',
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
