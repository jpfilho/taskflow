import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/nota_sap.dart';
import '../utils/responsive.dart';

class NotasSAPCalendarView extends StatefulWidget {
  final List<NotaSAP> notas;
  final Function(NotaSAP)? onNotaTap;

  const NotasSAPCalendarView({
    super.key,
    required this.notas,
    this.onNotaTap,
  });

  @override
  State<NotasSAPCalendarView> createState() => _NotasSAPCalendarViewState();
}

class _NotasSAPCalendarViewState extends State<NotasSAPCalendarView> {
  DateTime _currentMonth = DateTime.now();
  final SupabaseClient _supabase = Supabase.instance.client;
  // Cache de tarefas vinculadas por nota
  final Map<String, Map<String, String>> _notaTarefaCache = {};
  // Lista enriquecida com dados de tarefa
  List<NotaSAP> _notasEnriquecidas = [];

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
    final sourceNotas = _notasEnriquecidas.isNotEmpty ? _notasEnriquecidas : widget.notas;
    final notas = _getNotasForMonth(sourceNotas);
    // Prefetch tarefas vinculadas para as notas do mês
    _prefetchTarefasParaNotas(notas.values.expand((e) => e).toList());

    return Column(
      children: [
        _buildMonthNavigator(isMobile),
        Expanded(
          child: _buildCalendar(notas, isMobile),
        ),
      ],
    );
  }

  Widget _buildMonthNavigator(bool isMobile) {
    final monthNames = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
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
                _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
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
                _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(Map<int, List<NotaSAP>> notas, bool isMobile) {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final daysInMonth = lastDay.day;
    final startWeekday = firstDay.weekday;

    return LayoutBuilder(
      builder: (context, constraints) {
        final headerHeight = isMobile ? 40.0 : 50.0;
        final padding = isMobile ? 16.0 : 24.0;
        final spacing = 8.0;
        final availableHeight = constraints.maxHeight - headerHeight - padding - spacing;
        
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
                  notas, 
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

  Future<void> _prefetchTarefasParaNotas(List<NotaSAP> notas) async {
    // Pegar IDs que ainda não temos em cache
    final missingIds = notas
        .where((n) => !_notaTarefaCache.containsKey(n.id))
        .map((n) => n.id)
        .where((id) => id.isNotEmpty)
        .toList();

    if (missingIds.isEmpty) return;

    try {
      dynamic query = _supabase
          .from('tasks_notas_sap')
          .select('nota_sap_id, tasks(id, tarefa, status, coordenador, data_inicio, data_fim, tasks_executores(executores(nome)))')
          .inFilter('nota_sap_id', missingIds);

      final response = await query;
      for (var item in response as List) {
        final notaId = item['nota_sap_id'] as String?;
        final task = item['tasks'] as Map<String, dynamic>?;
        if (notaId == null || task == null) continue;

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
          _notaTarefaCache[notaId] = {
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

      // Atualizar notas locais com a tarefa cacheada
      for (var i = 0; i < notas.length; i++) {
        final cache = _notaTarefaCache[notas[i].id];
        if (cache != null) {
          notas[i] = notas[i].copyWith(
            tarefaId: cache['tarefa_id'],
            tarefaNome: cache['tarefa_nome'],
            tarefaStatus: cache['tarefa_status'],
          );
        }
      }
      // Atualizar lista enriquecida para todo o calendário
      _notasEnriquecidas = widget.notas.map((n) {
        final cache = _notaTarefaCache[n.id];
        if (cache == null) return n;
        return n.copyWith(
          tarefaId: cache['tarefa_id'],
          tarefaNome: cache['tarefa_nome'],
          tarefaStatus: cache['tarefa_status'],
        );
      }).toList();

      if (mounted) setState(() {});
    } catch (e) {
      // Falha silenciosa para não quebrar o calendário
      debugPrint('⚠️ Erro ao prefetch tarefas das notas: $e');
    }
  }

  Widget _buildCalendarGrid(
    Map<int, List<NotaSAP>> notas, 
    int daysInMonth, 
    int startWeekday, 
    bool isMobile,
    {required double cellWidth, required double cellHeight}
  ) {
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

        final dayNotas = notas[day] ?? [];
        final isToday = day == DateTime.now().day && 
                       _currentMonth.month == DateTime.now().month &&
                       _currentMonth.year == DateTime.now().year;

        return _buildDayCell(day, dayNotas, isToday, isMobile);
      },
    );
  }

  Widget _buildDayCell(int day, List<NotaSAP> notas, bool isToday, bool isMobile) {
    return InkWell(
      onTap: () async {
        if (notas.isNotEmpty) {
          await _showDayNotas(day, notas);
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
            if (notas.isNotEmpty)
              Expanded(
                child: Column(
                  children: notas.take(3).map((nota) {
                    final diasRestantes = nota.diasRestantes;
                    Color badgeColor;
                    if (diasRestantes == null) {
                      badgeColor = Colors.grey;
                    } else if (diasRestantes <= 0) {
                      badgeColor = Colors.black;
                    } else if (diasRestantes <= 30) {
                      badgeColor = Colors.red;
                    } else if (diasRestantes <= 90) {
                      badgeColor = Colors.yellow[700] ?? Colors.amber;
                    } else {
                      badgeColor = Colors.blue;
                    }
                    final taskColor = _getTaskStatusColor(nota.tarefaStatus);

                    return Wrap(
                      spacing: 2,
                      runSpacing: 2,
                      alignment: WrapAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: isMobile ? 60 : 70),
                            child: Text(
                              nota.sala != null && nota.sala!.isNotEmpty
                                  ? '${nota.nota} · ${nota.sala}'
                                  : nota.nota,
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
                        if (nota.tarefaStatus != null || nota.tarefaNome != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: taskColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: taskColor, width: 0.6),
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: isMobile ? 50 : 60),
                              child: Text(
                                nota.tarefaStatus ?? (nota.tarefaNome ?? ''),
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
            if (notas.length > 3)
              Padding(
                padding: const EdgeInsets.all(2),
                child: Text(
                  '+${notas.length - 3}',
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

  Future<void> _showDayNotas(int day, List<NotaSAP> notas) async {
    // Garantir tarefas carregadas para estas notas antes de abrir
    await _prefetchTarefasParaNotas(notas);

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
                  'Notas do dia $day',
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
                itemCount: notas.length,
                itemBuilder: (context, index) {
                  final nota = notas[index];
                  return _buildNotaCard(nota);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotaCard(NotaSAP nota) {
    final diasRestantes = nota.diasRestantes;
    Color badgeColor;
    String badgeText;
    
    if (diasRestantes == null) {
      badgeColor = Colors.grey;
      badgeText = 'Sem prazo';
    } else if (diasRestantes <= 0) {
      badgeColor = Colors.black;
      badgeText = diasRestantes == 0 ? 'Vence hoje' : '${diasRestantes} dias';
    } else if (diasRestantes <= 30) {
      badgeColor = Colors.red;
      badgeText = '$diasRestantes dias';
    } else if (diasRestantes <= 90) {
      badgeColor = Colors.yellow[700] ?? Colors.amber;
      badgeText = '$diasRestantes dias';
    } else {
      badgeColor = Colors.blue;
      badgeText = '$diasRestantes dias';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.of(context).pop();
          widget.onNotaTap?.call(nota);
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
                      'Nota: ${nota.nota}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badgeText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (nota.tipo != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Tipo: ${nota.tipo}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
              if (nota.local != null && nota.local!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Local: ${nota.local}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
              ],
              if (nota.sala != null && nota.sala!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'Sala: ${nota.sala}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
              ],
              if (nota.textPrioridade != null && nota.textPrioridade!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Prioridade: ${nota.textPrioridade}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.deepOrange,
                  ),
                ),
              ],
              if (nota.descricao != null) ...[
                const SizedBox(height: 8),
                Text(
                  nota.descricao!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ],
              // Vencimento da nota (antes das infos da tarefa)
              if (nota.dataVencimento != null) ...[
                const SizedBox(height: 8),
                _buildPrazoPill(nota),
              ],
              // Detalhes da tarefa vinculada abaixo das infos da nota e vencimento
              if (nota.tarefaNome != null && nota.tarefaNome!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getTaskStatusColor(nota.tarefaStatus).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _getTaskStatusColor(nota.tarefaStatus),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        nota.tarefaStatus ?? '-',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _getTaskStatusColor(nota.tarefaStatus),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        nota.tarefaNome ?? '-',
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
                const SizedBox(height: 6),
                if (_notaTarefaCache[nota.id]?['tarefa_executores'] != null &&
                    _notaTarefaCache[nota.id]!['tarefa_executores']!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'Executores: ${_notaTarefaCache[nota.id]!['tarefa_executores']}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                if (_notaTarefaCache[nota.id]?['tarefa_coordenador'] != null &&
                    _notaTarefaCache[nota.id]!['tarefa_coordenador']!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'Coordenador: ${_notaTarefaCache[nota.id]!['tarefa_coordenador']}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                if ((_notaTarefaCache[nota.id]?['tarefa_data_inicio']?.isNotEmpty ?? false) ||
                    (_notaTarefaCache[nota.id]?['tarefa_data_fim']?.isNotEmpty ?? false))
                  Row(
                    children: [
                      const Icon(Icons.event, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        [
                          _formatDateString(_notaTarefaCache[nota.id]?['tarefa_data_inicio']),
                          _formatDateString(_notaTarefaCache[nota.id]?['tarefa_data_fim'])
                        ].where((e) => e.isNotEmpty).join(' - '),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
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

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatDateString(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr);
      return _formatDate(dt);
    } catch (_) {
      return dateStr;
    }
  }

  Widget _buildPrazoPill(NotaSAP nota) {
    if (nota.dataVencimento == null) {
      return const SizedBox.shrink();
    }

    final dias = nota.diasRestantes;
    Color bg;
    Color fg = Colors.white;
    if (dias == null) {
      bg = Colors.grey;
    } else if (dias <= 0) {
      bg = Colors.black;
    } else if (dias <= 30) {
      bg = Colors.red;
    } else if (dias <= 90) {
      bg = Colors.orange;
    } else {
      bg = Colors.blue;
    }

    final vencStr = _formatDate(nota.dataVencimento!);
    final diasStr = dias != null ? '${dias.abs()} dias' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_today, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            diasStr.isNotEmpty ? '$vencStr  $diasStr' : vencStr,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Map<int, List<NotaSAP>> _getNotasForMonth(List<NotaSAP> allNotas) {
    final notasByDay = <int, List<NotaSAP>>{};

    for (var nota in allNotas) {
      // Usar dataVencimento para posicionar no calendário
      if (nota.dataVencimento != null) {
        final vencimento = nota.dataVencimento!;
        
        // Verificar se a data de vencimento está no mês atual
        if (vencimento.year == _currentMonth.year &&
            vencimento.month == _currentMonth.month) {
          final day = vencimento.day;
          final dayNotas = notasByDay.putIfAbsent(day, () => <NotaSAP>[]);
          if (!dayNotas.any((n) => n.id == nota.id)) {
            dayNotas.add(nota);
          }
        }
      }
    }

    return notasByDay;
  }
}
