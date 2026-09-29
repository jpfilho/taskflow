import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/si.dart';
import '../utils/responsive.dart';
import '../design_system/taskflow_design_system.dart';

class SiCalendarView extends StatefulWidget {
  final List<SI> sis;
  final Function(SI)? onSITap;

  const SiCalendarView({super.key, required this.sis, this.onSITap});

  @override
  State<SiCalendarView> createState() => _SiCalendarViewState();
}

class _SiCalendarViewState extends State<SiCalendarView> {
  DateTime _currentMonth = DateTime.now();
  final SupabaseClient _supabase = Supabase.instance.client;
  final Map<String, Map<String, String>> _siTarefaCache = {};

  Color _getTaskStatusColor(String? status) {
    if (status == null) return Colors.grey;
    final up = status.toUpperCase();
    if (up.contains('ANDA')) return Colors.orange;
    if (up.contains('CONC')) return Colors.green;
    if (up.contains('PROG')) return Colors.blue;
    if (up.contains('CANC')) return Colors.red;
    return Colors.blueGrey;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final sisPorDia = _getSIsForMonth(widget.sis);
    _prefetchTarefasParaSIs(sisPorDia.values.expand((e) => e).toList());

    return Column(
      children: [
        _buildMonthNavigator(isMobile),
        Expanded(child: _buildCalendar(sisPorDia, isMobile)),
      ],
    );
  }

  Widget _buildMonthNavigator(bool isMobile) {
    final colors = context.tfColors;
    final monthNames = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      color: colors.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                _currentMonth = DateTime(
                  _currentMonth.year,
                  _currentMonth.month - 1,
                );
              });
            },
          ),
          Text(
            '${monthNames[_currentMonth.month - 1]} ${_currentMonth.year}',
            style: TextStyle(
              fontSize: isMobile ? 16 : 20,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                _currentMonth = DateTime(
                  _currentMonth.year,
                  _currentMonth.month + 1,
                );
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(Map<int, List<SI>> sisMap, bool isMobile) {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final daysInMonth = lastDay.day;
    final startWeekday = firstDay.weekday;

    return LayoutBuilder(
      builder: (context, constraints) {
        final headerHeight = isMobile ? 40.0 : 50.0;
        const padding = 16.0;
        const spacing = 8.0;
        final availableHeight =
            constraints.maxHeight - headerHeight - padding - spacing;

        final startWeekdayAdjusted = startWeekday % 7;
        final totalCells = daysInMonth + startWeekdayAdjusted;
        final weeksNeeded = (totalCells / 7).ceil();

        const cellSpacing = 4.0;
        final totalSpacing = (weeksNeeded - 1) * cellSpacing;
        final cellHeight = (availableHeight - totalSpacing) / weeksNeeded;

        final availableWidth = constraints.maxWidth - padding;
        const totalCellSpacing = 6 * cellSpacing;
        final cellWidth = (availableWidth - totalCellSpacing) / 7;

        return Padding(
          padding: EdgeInsets.all(isMobile ? 8 : 12),
          child: Column(
            children: [
              _buildWeekdayHeaders(isMobile),
              const SizedBox(height: spacing),
              Expanded(
                child: _buildCalendarGrid(
                  sisMap,
                  daysInMonth,
                  startWeekday,
                  isMobile,
                  cellWidth: cellWidth,
                  cellHeight: cellHeight,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWeekdayHeaders(bool isMobile) {
    final colors = context.tfColors;
    final weekdays = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
    return Row(
      children: weekdays.map((day) {
        return Expanded(
          child: Center(
            child: Text(
              day,
              style: TextStyle(
                fontSize: isMobile ? 11 : 12,
                fontWeight: FontWeight.bold,
                color: colors.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _prefetchTarefasParaSIs(List<SI> sisList) async {
    final missingIds = sisList
        .where((s) => !_siTarefaCache.containsKey(s.id))
        .map((s) => s.id)
        .toList();
    if (missingIds.isEmpty) return;

    try {
      final res = await _supabase
          .from('task_sis')
          .select('si_id, task:tarefas(nome, status, divisao)')
          .inFilter('si_id', missingIds);

      final Map<String, Map<String, String>> newEntries = {};
      for (final row in (res as List)) {
        final sid = row['si_id'] as String;
        final task = row['task'] as Map<String, dynamic>?;
        if (task != null) {
          newEntries[sid] = {
            'nome': task['nome'] as String? ?? 'Sem nome',
            'status': task['status'] as String? ?? 'N/A',
            'divisao': task['divisao'] as String? ?? '',
          };
        }
      }

      for (final id in missingIds) {
        if (!newEntries.containsKey(id)) {
          newEntries[id] = {'nome': '', 'status': '', 'divisao': ''};
        }
      }

      if (mounted) {
        setState(() {
          _siTarefaCache.addAll(newEntries);
        });
      }
    } catch (_) {}
  }

  Map<int, List<SI>> _getSIsForMonth(List<SI> allSis) {
    final map = <int, List<SI>>{};
    for (final si in allSis) {
      final date = si.dataFim ?? si.dataInicio;
      if (date != null &&
          date.year == _currentMonth.year &&
          date.month == _currentMonth.month) {
        map.putIfAbsent(date.day, () => []).add(si);
      }
    }
    return map;
  }

  Widget _buildCalendarGrid(
    Map<int, List<SI>> sisMap,
    int daysInMonth,
    int startWeekday,
    bool isMobile, {
    required double cellWidth,
    required double cellHeight,
  }) {
    final startWeekdayAdjusted = startWeekday % 7;
    final totalCells = daysInMonth + startWeekdayAdjusted;
    final weeksNeeded = (totalCells / 7).ceil();

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: cellWidth / cellHeight,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: weeksNeeded * 7,
      itemBuilder: (context, index) {
        final dayNumber = index - startWeekdayAdjusted + 1;
        if (dayNumber < 1 || dayNumber > daysInMonth) {
          return const SizedBox.shrink();
        }

        final sisDoDia = sisMap[dayNumber] ?? [];
        return _buildDayCell(dayNumber, sisDoDia, isMobile);
      },
    );
  }

  Widget _buildDayCell(int day, List<SI> sisList, bool isMobile) {
    final colors = context.tfColors;
    final today = DateTime.now();
    final isToday = today.year == _currentMonth.year &&
        today.month == _currentMonth.month &&
        today.day == day;

    return InkWell(
      onTap: sisList.isNotEmpty
          ? () => _showDayDetailsDialog(day, sisList)
          : null,
      borderRadius: BorderRadius.circular(TFRadius.r8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isToday
              ? colors.primary.withValues(alpha: 0.08)
              : colors.surface,
          border: Border.all(
            color: isToday ? colors.primary : colors.borderSubtle,
            width: isToday ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(TFRadius.r8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    fontSize: isMobile ? 10 : 12,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                    color: isToday ? colors.primary : colors.textPrimary,
                  ),
                ),
                if (sisList.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${sisList.length}',
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Expanded(
              child: ListView(
                physics: const NeverScrollableScrollPhysics(),
                children: sisList.take(isMobile ? 1 : 2).map((si) {
                  final tarefa = _siTarefaCache[si.id];
                  final statusTarefa = tarefa?['status'];
                  final statusColor = statusTarefa != null && statusTarefa.isNotEmpty
                      ? _getTaskStatusColor(statusTarefa)
                      : colors.primary;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Text(
                      si.solicitacao,
                      style: TextStyle(
                        fontSize: 8,
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDayDetailsDialog(int day, List<SI> sisList) {
    final colors = context.tfColors;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('SIs para o dia $day/${_currentMonth.month}/${_currentMonth.year}'),
          content: SizedBox(
            width: 450,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: sisList.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final si = sisList[index];
                final tarefa = _siTarefaCache[si.id];
                final statusTarefa = tarefa?['status'];

                return ListTile(
                  dense: true,
                  title: Text(
                    'SI ${si.solicitacao} - ${si.textoBreve ?? 'Sem descrição'}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Tipo: ${si.tipo ?? 'N/A'} • Local: ${si.local ?? si.localInstalacao ?? 'N/A'}'
                    '${statusTarefa != null && statusTarefa.isNotEmpty ? ' • Tarefa: $statusTarefa' : ''}',
                  ),
                  trailing: Icon(Icons.chevron_right, color: colors.textSecondary),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onSITap?.call(si);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }
}
