import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/ordem.dart';
import '../utils/responsive.dart';

class OrdemCalendarView extends StatefulWidget {
  final List<Ordem> ordens;
  final void Function(Ordem)? onOrdemTap;

  const OrdemCalendarView({
    super.key,
    required this.ordens,
    this.onOrdemTap,
  });

  @override
  State<OrdemCalendarView> createState() => _OrdemCalendarViewState();
}

class _OrdemCalendarViewState extends State<OrdemCalendarView> {
  DateTime _currentMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final ordensDoMes = _getOrdensForMonth(widget.ordens);

    return Column(
      children: [
        _buildMonthNavigator(isMobile),
        Expanded(
          child: _buildCalendar(ordensDoMes, isMobile),
        ),
      ],
    );
  }

  Widget _buildMonthNavigator(bool isMobile) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
              });
            },
          ),
          Text(
            _formatMonthYear(_currentMonth),
            style: TextStyle(
              fontSize: isMobile ? 16 : 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(Map<int, List<Ordem>> ordens, bool isMobile) {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final daysInMonth = lastDay.day;
    final startWeekday = firstDay.weekday % 7; // 0 = domingo

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellSpacing = 4.0;
        final weeksNeeded = ((daysInMonth + startWeekday) / 7).ceil();
        final totalSpacing = (weeksNeeded - 1) * cellSpacing;
        final cellHeight = (constraints.maxHeight - totalSpacing) / weeksNeeded;
        final cellWidth = (constraints.maxWidth - (6 * cellSpacing)) / 7;

        return Padding(
          padding: EdgeInsets.all(isMobile ? 8 : 12),
          child: Column(
            children: [
              _buildWeekdayHeaders(isMobile),
              const SizedBox(height: 8),
              Expanded(
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: cellSpacing,
                    crossAxisSpacing: cellSpacing,
                    childAspectRatio: cellWidth / cellHeight,
                  ),
                  itemCount: weeksNeeded * 7,
                  itemBuilder: (context, index) {
                    if (index < startWeekday) return const SizedBox.shrink();
                    final day = index - startWeekday + 1;
                    if (day > daysInMonth) return const SizedBox.shrink();
                    final dayOrdens = ordens[day] ?? [];
                    final isToday = day == DateTime.now().day &&
                        _currentMonth.month == DateTime.now().month &&
                        _currentMonth.year == DateTime.now().year;
                    return _buildDayCell(day, dayOrdens, isToday, isMobile);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWeekdayHeaders(bool isMobile) {
    const headers = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: headers
          .map(
            (h) => Expanded(
              child: Center(
                child: Text(
                  h,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                    fontSize: isMobile ? 12 : 13,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildDayCell(int day, List<Ordem> ordens, bool isToday, bool isMobile) {
    return InkWell(
      onTap: ordens.isEmpty ? null : () => _showDayOrdens(day, ordens),
      child: Container(
        decoration: BoxDecoration(
          color: isToday ? Colors.blue.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isToday ? Colors.blue : Colors.grey[300]!,
          ),
        ),
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$day',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 13 : 14,
              ),
            ),
            const SizedBox(height: 4),
            if (ordens.isNotEmpty)
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: ordens.take(3).map((o) => _buildPill(o, isMobile)).toList(),
                  ),
                ),
              ),
            if (ordens.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '+${ordens.length - 3} ordens',
                  style: const TextStyle(fontSize: 10, color: Colors.blueGrey),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPill(Ordem ordem, bool isMobile) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _statusColor(ordem.statusSistema).withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _statusColor(ordem.statusSistema).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ordem.ordem,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isMobile ? 11 : 12,
              color: Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if ((ordem.textoBreve ?? '').isNotEmpty)
            Text(
              ordem.textoBreve!,
              style: TextStyle(
                fontSize: isMobile ? 10 : 11,
                color: Colors.grey[700],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  Future<void> _showDayOrdens(int day, List<Ordem> ordens) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ordens em ${_formatDay(day)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: ordens.length,
                itemBuilder: (context, index) {
                  final ordem = ordens[index];
                  return _buildOrdemCard(ordem);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdemCard(Ordem ordem) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _statusColor(ordem.statusSistema).withOpacity(0.15),
          child: Text(
            (ordem.tipo ?? '-').toUpperCase().padRight(2).substring(0, 2),
            style: TextStyle(color: _statusColor(ordem.statusSistema)),
          ),
        ),
        title: Text(
          '${ordem.ordem} • ${ordem.textoBreve ?? 'Sem descrição'}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((ordem.local ?? '').isNotEmpty) Text('Local: ${ordem.local}'),
            if ((ordem.localInstalacao ?? '').isNotEmpty) Text('Instalação: ${ordem.localInstalacao}'),
            if (ordem.tolerancia != null) Text('Tolerância: ${_formatDate(ordem.tolerancia!)}'),
            if ((ordem.statusSistema ?? '').isNotEmpty) Text('Status: ${ordem.statusSistema}'),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.copy, color: Colors.blue),
          onPressed: () => _copiar(ordem.ordem),
        ),
        onTap: widget.onOrdemTap != null ? () => widget.onOrdemTap!(ordem) : null,
      ),
    );
  }

  Future<void> _copiar(String texto) async {
    try {
      await Clipboard.setData(ClipboardData(text: texto));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ordem copiada!'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (_) {}
  }

  Map<int, List<Ordem>> _getOrdensForMonth(List<Ordem> ordens) {
    final Map<int, List<Ordem>> mapa = {};
    for (final o in ordens) {
      if (o.tolerancia == null) continue;
      if (o.tolerancia!.year == _currentMonth.year && o.tolerancia!.month == _currentMonth.month) {
        mapa.putIfAbsent(o.tolerancia!.day, () => []);
        mapa[o.tolerancia!.day]!.add(o);
      }
    }
    return mapa;
  }

  String _formatMonthYear(DateTime date) {
    const months = [
      'Jan',
      'Fev',
      'Mar',
      'Abr',
      'Mai',
      'Jun',
      'Jul',
      'Ago',
      'Set',
      'Out',
      'Nov',
      'Dez'
    ];
    return '${months[date.month - 1]} de ${date.year}';
  }

  String _formatDay(int day) {
    return '$day/${_currentMonth.month.toString().padLeft(2, '0')}/${_currentMonth.year}';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Color _statusColor(String? status) {
    if (status == null) return Colors.grey;
    final up = status.toUpperCase();
    if (up.contains('ABER')) return Colors.orange;
    if (up.contains('CAPC')) return Colors.blue;
    if (up.contains('DMNV')) return Colors.red;
    if (up.contains('ERRD')) return Colors.red;
    if (up.contains('SCDM')) return Colors.green;
    return Colors.blueGrey;
  }
}
