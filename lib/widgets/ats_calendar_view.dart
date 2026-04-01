import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/at.dart';
import '../utils/responsive.dart';

class AtsCalendarView extends StatefulWidget {
  final List<AT> ats;
  final Function(AT)? onATTap;

  const AtsCalendarView({super.key, required this.ats, this.onATTap});

  @override
  State<AtsCalendarView> createState() => _AtsCalendarViewState();
}

class _AtsCalendarViewState extends State<AtsCalendarView> {
  DateTime _currentMonth = DateTime.now();
  final SupabaseClient _supabase = Supabase.instance.client;
  // Cache de tarefas vinculadas por at
  final Map<String, Map<String, String>> _atTarefaCache = {};
  // Lista enriquecida com dados de tarefa
  final List<AT> _atsEnriquecidas = [];

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
    final sourceATs = _atsEnriquecidas.isNotEmpty
        ? _atsEnriquecidas
        : widget.ats;
    final ats = _getATsForMonth(sourceATs);
    // Prefetch tarefas vinculadas para as ats do mês
    _prefetchTarefasParaATs(ats.values.expand((e) => e).toList());

    return Column(
      children: [
        _buildMonthNavigator(isMobile),
        Expanded(child: _buildCalendar(ats, isMobile)),
      ],
    );
  }

  Widget _buildMonthNavigator(bool isMobile) {
    final monthNames = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      color: Colors.grey[50],
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

  Widget _buildCalendar(Map<int, List<AT>> ats, bool isMobile) {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final daysInMonth = lastDay.day;
    final startWeekday = firstDay.weekday;

    return LayoutBuilder(
      builder: (context, constraints) {
        final headerHeight = isMobile ? 40.0 : 50.0;
        final padding = isMobile ? 16.0 : 24.0;
        final spacing = 8.0;
        final availableHeight =
            constraints.maxHeight - headerHeight - padding - spacing;

        final startWeekdayAdjusted = startWeekday % 7;
        final totalCells = daysInMonth + startWeekdayAdjusted;
        final weeksNeeded = (totalCells / 7).ceil();

        final cellSpacing = 4.0;
        final totalSpacing = (weeksNeeded - 1) * cellSpacing;
        final cellHeight = (availableHeight - totalSpacing) / weeksNeeded;

        final availableWidth = constraints.maxWidth - padding;
        final totalCellSpacing = 6 * cellSpacing;
        final cellWidth = (availableWidth - totalCellSpacing) / 7;

        return Padding(
          padding: EdgeInsets.all(isMobile ? 8 : 12),
          child: Column(
            children: [
              _buildWeekdayHeaders(isMobile),
              SizedBox(height: spacing),
              Expanded(
                child: _buildCalendarGrid(
                  ats,
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
                color: Colors.grey[700],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _prefetchTarefasParaATs(List<AT> atsList) async {
    // Pegar IDs que ainda não temos em cache
    final missingIds = atsList
        .where((a) => !_atTarefaCache.containsKey(a.id))
        .map((a) => a.id)
        .where((id) => id.isNotEmpty)
        .toList();

    if (missingIds.isEmpty) return;

    try {
      dynamic query = _supabase
          .from('tasks_ats')
          .select(
            'at_id, tasks(id, tarefa, status, coordenador, data_inicio, data_fim, tasks_executores(executores(nome)))',
          )
          .inFilter('at_id', missingIds);

      final response = await query;
      for (var item in response as List) {
        final atId = item['at_id'] as String?;
        final task = item['tasks'] as Map<String, dynamic>?;
        if (atId == null || task == null) continue;

        final tarefaId = task['id'] as String?;
        final tarefaNome = task['tarefa'] as String?;
        final tarefaStatus = task['status'] as String?;
        final tarefaCoordenador = task['coordenador'] as String?;
        final tarefaInicio = task['data_inicio']?.toString();
        final tarefaFim = task['data_fim']?.toString();

        // Montar executores
        String executoresStr = '';
        final tasksExecutores = task['tasks_executores'] as List<dynamic>?;
        if (tasksExecutores != null && tasksExecutores.isNotEmpty) {
          final nomes = <String>[];
          for (var te in tasksExecutores) {
            final exec = te['executores'] as Map<String, dynamic>?;
            final nome = exec != null ? exec['nome'] as String? : null;
            if (nome != null && nome.trim().isNotEmpty) {
              nomes.add(nome.trim());
            }
          }
          executoresStr = nomes.join(', ');
        }

        if (tarefaId != null) {
          _atTarefaCache[atId] = {
            'tarefa_id': tarefaId,
            'tarefa_nome': tarefaNome ?? '',
            'tarefa_status': tarefaStatus ?? '',
            'tarefa_coordenador': tarefaCoordenador ?? '',
            'tarefa_data_inicio': tarefaInicio ?? '',
            'tarefa_data_fim': tarefaFim ?? '',
            'tarefa_executores': executoresStr,
          };
        }
      }

      // Evitamos sobrescrever o objeto local AT (pois At.copyWith depende da sua assinatura)
      // Como na tela de Notas ele tinha tarefas dinâmicas, faremos apenas leitura do cache visual
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('⚠️ Erro ao prefetch tarefas das ATs: $e');
    }
  }

  Widget _buildCalendarGrid(
    Map<int, List<AT>> atsDict,
    int daysInMonth,
    int startWeekday,
    bool isMobile, {
    required double cellWidth,
    required double cellHeight,
  }) {
    final startWeekdayAdjusted = startWeekday % 7;
    final totalCells = daysInMonth + startWeekdayAdjusted;
    final weeksNeeded = (totalCells / 7).ceil();
    final itemCount = weeksNeeded * 7;

    return GridView.builder(
      shrinkWrap: false,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: cellWidth / cellHeight,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index < startWeekdayAdjusted) {
          return const SizedBox.shrink();
        }

        final day = index - startWeekdayAdjusted + 1;

        if (day > daysInMonth) {
          return const SizedBox.shrink();
        }

        final dayATs = atsDict[day] ?? [];
        final isToday =
            day == DateTime.now().day &&
            _currentMonth.month == DateTime.now().month &&
            _currentMonth.year == DateTime.now().year;

        return _buildDayCell(day, dayATs, isToday, isMobile);
      },
    );
  }

  Widget _buildDayCell(int day, List<AT> atsList, bool isToday, bool isMobile) {
    return InkWell(
      onTap: () async {
        if (atsList.isNotEmpty) {
          await _showDayATs(day, atsList);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isToday ? Colors.blue.withOpacity(0.1) : Colors.white,
          border: Border.all(
            color: isToday ? Colors.blue : Colors.grey[300]!,
            width: isToday ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(4),
              child: Text(
                day.toString(),
                style: TextStyle(
                  fontSize: isMobile ? 12 : 14,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  color: isToday ? Colors.blue : Colors.grey[800],
                ),
              ),
            ),
            if (atsList.isNotEmpty)
              Expanded(
                child: Column(
                  children: atsList.take(3).map((at) {
                    final cacheTarefa = _atTarefaCache[at.id];
                    final String? statusTarefa = cacheTarefa?['tarefa_status'];
                    final String? nomeTarefa = cacheTarefa?['tarefa_nome'];
                    final taskColor = _getTaskStatusColor(statusTarefa);

                    final sysStatus = at.statusSistema ?? '';
                    Color bgSystColor = Colors.grey;
                    if (sysStatus.contains('ABER')) bgSystColor = Colors.orange;
                    if (sysStatus.contains('CAPC')) bgSystColor = Colors.blue;

                    return Wrap(
                      spacing: 2,
                      runSpacing: 2,
                      alignment: WrapAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: bgSystColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: isMobile ? 60 : 70,
                            ),
                            child: Text(
                              at.autorzTrab,
                              style: TextStyle(
                                fontSize: isMobile ? 7 : 8,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                            ),
                          ),
                        ),
                        if (statusTarefa != null || nomeTarefa != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: taskColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: taskColor, width: 0.6),
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: isMobile ? 50 : 60,
                              ),
                              child: Text(
                                statusTarefa ?? (nomeTarefa ?? ''),
                                style: TextStyle(
                                  fontSize: isMobile ? 6.5 : 7,
                                  color: taskColor,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                              ),
                            ),
                          ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            if (atsList.length > 3)
              Padding(
                padding: const EdgeInsets.all(2),
                child: Text(
                  '+${atsList.length - 3}',
                  style: TextStyle(
                    fontSize: isMobile ? 8 : 9,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDayATs(int day, List<AT> atsList) async {
    await _prefetchTarefasParaATs(atsList);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ATs do dia $day',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: atsList.length,
                itemBuilder: (context, index) {
                  final at = atsList[index];
                  return _buildATCard(at);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildATCard(AT at) {
    Color badgeColor = Colors.blue;

    final sysStatus = at.statusSistema ?? '';
    if (sysStatus.contains('ABER')) badgeColor = Colors.orange;

    final cacheTarefa = _atTarefaCache[at.id];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.of(context).pop();
          widget.onATTap?.call(at);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'AT: ${at.autorzTrab}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      at.statusSistema ?? 'S/S',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (at.localInstalacao != null &&
                  at.localInstalacao!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Local: ${at.localInstalacao}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ],
              if (at.textoBreve != null) ...[
                const SizedBox(height: 8),
                Text(
                  at.textoBreve!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
              if (cacheTarefa != null) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getTaskStatusColor(
                          cacheTarefa['tarefa_status'],
                        ).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _getTaskStatusColor(
                            cacheTarefa['tarefa_status'],
                          ),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        cacheTarefa['tarefa_status'] ?? '-',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _getTaskStatusColor(
                            cacheTarefa['tarefa_status'],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        cacheTarefa['tarefa_nome'] ?? '-',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.blueGrey,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Map<int, List<AT>> _getATsForMonth(List<AT> allAts) {
    final atsByDay = <int, List<AT>>{};

    for (var at in allAts) {
      if (at.dataFim != null) {
        final vencimento = at.dataFim!;

        if (vencimento.year == _currentMonth.year &&
            vencimento.month == _currentMonth.month) {
          final day = vencimento.day;
          final dayATs = atsByDay.putIfAbsent(day, () => <AT>[]);
          if (!dayATs.any((a) => a.id == at.id)) {
            dayATs.add(at);
          }
        }
      }
    }

    return atsByDay;
  }
}
