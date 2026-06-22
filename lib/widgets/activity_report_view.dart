import 'package:flutter/material.dart';
import '../utils/platform_utils.dart' as platform;
import '../models/nota_sap.dart';
import '../models/ordem.dart';
import '../models/task.dart';
import '../services/nota_sap_service.dart';
import '../services/ordem_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Tipos auxiliares
// ─────────────────────────────────────────────────────────────────────────────

/// Dados mínimos de uma tarefa para o relatório.
/// Pode ser populado a partir de um Task completo (widget.tasks)
/// ou diretamente de um tarefaMap retornado pelo banco.
class _TaskData {
  final String id;
  final String tarefa;
  final String status;
  final String coordenador;
  final List<String> executores;
  final String executor;
  final DateTime? dataInicio;
  final DateTime? dataFim;

  _TaskData({
    required this.id,
    required this.tarefa,
    required this.status,
    required this.coordenador,
    required this.executores,
    required this.executor,
    this.dataInicio,
    this.dataFim,
  });
}

class _NotaRow {
  final NotaSAP nota;
  final _TaskData task;
  _NotaRow(this.nota, this.task);
}

class _OrdemRow {
  final Ordem ordem;
  final _TaskData task;
  _OrdemRow(this.ordem, this.task);
}


// ─────────────────────────────────────────────────────────────────────────────
// Widget principal
// ─────────────────────────────────────────────────────────────────────────────

class ActivityReportView extends StatefulWidget {
  final List<Task> tasks;
  final DateTime startDate;
  final DateTime endDate;
  final NotaSAPService notaSapService;
  final OrdemService ordemService;

  const ActivityReportView({
    super.key,
    required this.tasks,
    required this.startDate,
    required this.endDate,
    required this.notaSapService,
    required this.ordemService,
  });

  @override
  State<ActivityReportView> createState() => _ActivityReportViewState();
}

class _ActivityReportViewState extends State<ActivityReportView> {
  bool _isLoading = true;
  String? _error;
  List<_NotaRow> _notaRows = [];
  List<_OrdemRow> _ordemRows = [];
  String _debugInfo = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(ActivityReportView old) {
    super.didUpdateWidget(old);
    final tasksChanged = old.tasks.length != widget.tasks.length ||
        !_areListsEqual(old.tasks, widget.tasks);

    if (old.startDate != widget.startDate ||
        old.endDate != widget.endDate ||
        tasksChanged) {
      _loadData();
    }
  }

  bool _areListsEqual(List<Task> a, List<Task> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  // ── Carrega dados em paralelo ──────────────────────────────────────────────
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Map de taskId → Task para enriquecer com executor/coordenador (quando disponível)
      final taskMap = {for (final t in widget.tasks) t.id: t};

      // Busca notas e ordens em paralelo direto do banco
      final notasFuture = widget.notaSapService.getNotasProgramadas();
      final ordensFuture = widget.ordemService.getOrdensProgramadas();
      final notasProgramadas = await notasFuture;
      final ordensProgramadas = await ordensFuture;

      // Helper: verifica se a tarefa se sobrepõe ao período selecionado
      bool overlapsPeriod(Map<String, dynamic> tarefaMap) {
        final inicioStr = tarefaMap['data_inicio']?.toString();
        final fimStr = tarefaMap['data_fim']?.toString();
        if (inicioStr == null || fimStr == null) return false;
        final inicio = DateTime.tryParse(inicioStr);
        final fim = DateTime.tryParse(fimStr);
        if (inicio == null || fim == null) return false;
        // Sobreposição: início da tarefa ≤ fim do período E fim da tarefa ≥ início do período
        return !inicio.isAfter(widget.endDate) && !fim.isBefore(widget.startDate);
      }

      // Helper: extrai dados da tarefa do tarefaMap (banco) e filtra baseando-se nas tarefas ativas
      _TaskData? buildTaskData(Map<String, dynamic> tarefaMap) {
        final taskId = tarefaMap['id']?.toString();
        if (taskId == null) return null;
        final task = taskMap[taskId];
        
        // Se a tarefa associada não faz parte das tarefas filtradas, ignoramos esta nota/ordem.
        if (task == null) return null;
        
        return _TaskData(
          id: taskId,
          tarefa: task.tarefa,
          status: task.status,
          coordenador: task.coordenador,
          executores: task.executores,
          executor: task.executor,
          dataInicio: task.dataInicio,
          dataFim: task.dataFim,
        );
      }

      // ── Notas ─────────────────────────────────────────────────────────────
      final notaRows = <_NotaRow>[];
      int notasRaw = 0, notasSemTarefa = 0, notasForaPeriodo = 0, notasSemNota = 0;
      for (final item in notasProgramadas) {
        notasRaw++;
        final tarefaMap = item['tarefa'] as Map<String, dynamic>?;
        if (tarefaMap == null) { notasSemTarefa++; continue; }
        if (!overlapsPeriod(tarefaMap)) { notasForaPeriodo++; continue; }
        final nota = item['nota'] as NotaSAP?;
        if (nota == null) { notasSemNota++; continue; }
        final taskData = buildTaskData(tarefaMap);
        if (taskData == null) continue;
        notaRows.add(_NotaRow(nota, taskData));
      }

      // ── Ordens ────────────────────────────────────────────────────────────
      final ordemRows = <_OrdemRow>[];
      int ordensRaw = 0, ordensSemTarefa = 0, ordensForaPeriodo = 0;
      final seenPairs = <String>{};
      for (final item in ordensProgramadas) {
        ordensRaw++;
        final tarefaMap = item['tarefa'] as Map<String, dynamic>?;
        if (tarefaMap == null) { ordensSemTarefa++; continue; }
        if (!overlapsPeriod(tarefaMap)) { ordensForaPeriodo++; continue; }
        final ordem = item['ordem'] as Ordem?;
        if (ordem == null) continue;
        final taskData = buildTaskData(tarefaMap);
        if (taskData == null) continue;
        final pairKey = '${ordem.id}_${taskData.id}';
        if (seenPairs.contains(pairKey)) continue;
        seenPairs.add(pairKey);
        ordemRows.add(_OrdemRow(ordem, taskData));
      }

      final debug = 'NOTAS: $notasRaw brutos | sem tarefa: $notasSemTarefa | fora período: $notasForaPeriodo | sem nota: $notasSemNota | resultado: ${notaRows.length}\n'
                   'ORDENS: $ordensRaw brutos | sem tarefa: $ordensSemTarefa | fora período: $ordensForaPeriodo | resultado: ${ordemRows.length}\n'
                   'Período: ${widget.startDate.toIso8601String()} → ${widget.endDate.toIso8601String()}';
      // ignore: avoid_print
      print('[REPORT DEBUG] $debug');


      // Ordenar por número de nota/ordem
      notaRows.sort((a, b) => a.nota.nota.compareTo(b.nota.nota));
      ordemRows.sort((a, b) => a.ordem.ordem.compareTo(b.ordem.ordem));

      if (mounted) {
        setState(() {
          _notaRows = notaRows;
          _ordemRows = ordemRows;
          _debugInfo = debug;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erro ao carregar dados: $e';
          _isLoading = false;
        });
      }
    }
  }

  // ── Formatação de data ─────────────────────────────────────────────────────
  String _fmtDate(DateTime? d) {
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _fmtPeriod() =>
      '${_fmtDate(widget.startDate)} a ${_fmtDate(widget.endDate)}';

  String _fmtNow() {
    final n = DateTime.now();
    return '${_fmtDate(n)} às ${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
  }

  String _executores(_TaskData t) {
    if (t.executores.isNotEmpty) return t.executores.join(', ');
    if (t.executor.isNotEmpty) return t.executor;
    return '—';
  }

  // ── Ação de impressão ─────────────────────────────────────────────────────
  void _print() {
    final notasHeaders = [
      '#', 'Nota', 'Tipo', 'Descrição', 'Local Instalação', 'Sala',
      'Prioridade', 'Status Nota', 'Atividade', 'Status Ativ.',
      'Executor(es)', 'Coordenador', 'Início', 'Fim', 'Observação'
    ];
    final notasData = _notaRows.asMap().entries.map((e) {
      final idx = e.key + 1;
      final row = e.value;
      final n = row.nota;
      final t = row.task;
      return [
        '$idx',
        n.nota,
        n.tipo ?? '-',
        n.descricao ?? '-',
        n.localInstalacao ?? '-',
        n.sala ?? '-',
        n.textPrioridade ?? '-',
        n.statusSistema ?? '-',
        t.tarefa,
        t.status.isNotEmpty ? t.status : '-',
        _executores(t),
        t.coordenador.isNotEmpty ? t.coordenador : '-',
        _fmtDate(t.dataInicio),
        _fmtDate(t.dataFim),
        '', // Coluna Observação vazia para anotações manuais
      ];
    }).toList();

    final ordensHeaders = [
      '#', 'Ordem', 'Tipo', 'Texto Breve', 'Local Instalação', 'Sala',
      'Status Sistema', 'GPM', 'Atividade', 'Executor(es)',
      'Coordenador', 'Início', 'Fim', 'Observação'
    ];
    final ordensData = _ordemRows.asMap().entries.map((e) {
      final idx = e.key + 1;
      final row = e.value;
      final o = row.ordem;
      final t = row.task;
      return [
        '$idx',
        o.ordem,
        o.tipo ?? '-',
        o.textoBreve ?? '-',
        o.localInstalacao ?? '-',
        o.sala ?? '-',
        o.statusSistema ?? '-',
        o.gpm ?? '-',
        t.tarefa,
        _executores(t),
        t.coordenador.isNotEmpty ? t.coordenador : '-',
        _fmtDate(t.dataInicio),
        _fmtDate(t.dataFim),
        '', // Coluna Observação vazia para anotações manuais
      ];
    }).toList();

    platform.printReport(
      title: 'Relatório de Atividades - ${_fmtPeriod()}',
      period: _fmtPeriod(),
      emission: _fmtNow(),
      notasHeaders: notasHeaders,
      notasData: notasData,
      ordensHeaders: ordensHeaders,
      ordensData: ordensData,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // ── Toolbar (não imprime) ────────────────────────────────────────
          _buildToolbar(),
          // ── Conteúdo do relatório ────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Text(_error!,
                            style: const TextStyle(color: Colors.red)))
                    : _buildReportBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.picture_as_pdf_outlined, color: Colors.blueGrey),
              const SizedBox(width: 8),
              Text(
                'Relatório do Período — ${_fmtPeriod()}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const Spacer(),
              if (_isLoading)
                const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              else ...[
                Text(
                  '${_notaRows.length} nota${_notaRows.length != 1 ? 's' : ''} · '
                  '${_ordemRows.length} ordem${_ordemRows.length != 1 ? 's' : ''}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: _print,
                  icon: const Icon(Icons.print, size: 18),
                  label: const Text('Imprimir / Salvar PDF'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.blueGrey[700],
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ],
            ],
          ),
          // ── Debug info (temporário para diagnóstico) ─────────────────────
          if (_debugInfo.isNotEmpty && !_isLoading)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _debugInfo,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.orange[800],
                  fontFamily: 'monospace',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReportBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          // ~1123px ≈ A4 landscape @ 96dpi
          constraints: const BoxConstraints(maxWidth: 1123),
          child: Container(
            key: const ValueKey('taskflow-report-root'),
            color: Colors.white,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                _buildNotasTable(),
                const SizedBox(height: 28),
                _buildOrdensTable(),
                const SizedBox(height: 16),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Cabeçalho do relatório ─────────────────────────────────────────────────
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'RELATÓRIO DE ATIVIDADES PROGRAMADAS',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Período: ${_fmtPeriod()}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
            Text(
              'Emissão: ${_fmtNow()}',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
        const Divider(thickness: 1.5),
      ],
    );
  }

  // ── Tabela de Notas ────────────────────────────────────────────────────────
  Widget _buildNotasTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
            'NOTAS SAP PROGRAMADAS NO PERÍODO', _notaRows.length, Colors.indigo),
        const SizedBox(height: 8),
        if (_notaRows.isEmpty)
          _emptyMsg('Nenhuma nota SAP vinculada às atividades do período.')
        else
          _PrintTable(
            columns: const [
              '#', 'Nota', 'Tipo', 'Descrição', 'Local Instalação', 'Sala',
              'Prioridade', 'Status Nota', 'Atividade', 'Status Ativ.',
              'Executor(es)', 'Coordenador', 'Início', 'Fim', 'Observação'
            ],
            columnWidths: const {
              0: FixedColumnWidth(30), // #
              1: FixedColumnWidth(72), // Nota
              2: FixedColumnWidth(40), // Tipo
              3: FlexColumnWidth(2.2), // Descrição
              4: FlexColumnWidth(1.6), // Local Instalação
              5: FixedColumnWidth(60), // Sala
              6: FixedColumnWidth(80), // Prioridade
              7: FlexColumnWidth(1.3), // Status Nota
              8: FlexColumnWidth(2.0), // Atividade
              9: FixedColumnWidth(70), // Status Ativ.
              10: FlexColumnWidth(1.6), // Executor(es)
              11: FlexColumnWidth(1.4), // Coordenador
              12: FixedColumnWidth(64), // Início
              13: FixedColumnWidth(64), // Fim
              14: FixedColumnWidth(100), // Observação
            },
            rows: _notaRows.asMap().entries.map((e) {
              final idx = e.key + 1;
              final row = e.value;
              final n = row.nota;
              final t = row.task;
              return [
                '$idx',
                n.nota,
                n.tipo ?? '—',
                n.descricao ?? '—',
                n.localInstalacao ?? '—',
                n.sala ?? '—',
                n.textPrioridade ?? '—',
                n.statusSistema ?? '—',
                t.tarefa,
                t.status.isNotEmpty ? t.status : '—',
                _executores(t),
                t.coordenador.isNotEmpty ? t.coordenador : '—',
                _fmtDate(t.dataInicio),
                _fmtDate(t.dataFim),
                '', // Coluna Observação vazia
              ];
            }).toList(),
          ),
      ],
    );
  }

  // ── Tabela de Ordens ───────────────────────────────────────────────────────
  Widget _buildOrdensTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
            'ORDENS SAP PROGRAMADAS NO PERÍODO', _ordemRows.length, Colors.teal),
        const SizedBox(height: 8),
        if (_ordemRows.isEmpty)
          _emptyMsg('Nenhuma ordem SAP vinculada às atividades do período.')
        else
          _PrintTable(
            columns: const [
              '#', 'Ordem', 'Tipo', 'Texto Breve', 'Local Instalação', 'Sala',
              'Status Sistema', 'GPM', 'Atividade', 'Executor(es)',
              'Coordenador', 'Início', 'Fim', 'Observação'
            ],
            columnWidths: const {
              0: FixedColumnWidth(30), // #
              1: FixedColumnWidth(80), // Ordem
              2: FixedColumnWidth(45), // Tipo
              3: FlexColumnWidth(2.0), // Texto Breve
              4: FlexColumnWidth(1.4), // Local Instalação
              5: FixedColumnWidth(60), // Sala
              6: FlexColumnWidth(1.4), // Status Sistema
              7: FixedColumnWidth(45), // GPM
              8: FlexColumnWidth(2.0), // Atividade
              9: FlexColumnWidth(1.6), // Executor(es)
              10: FlexColumnWidth(1.4), // Coordenador
              11: FixedColumnWidth(64), // Início
              12: FixedColumnWidth(64), // Fim
              13: FixedColumnWidth(100), // Observação
            },
            rows: _ordemRows.asMap().entries.map((e) {
              final idx = e.key + 1;
              final row = e.value;
              final o = row.ordem;
              final t = row.task;
              return [
                '$idx',
                o.ordem,
                o.tipo ?? '—',
                o.textoBreve ?? '—',
                o.localInstalacao ?? '—',
                o.sala ?? '—',
                o.statusSistema ?? '—',
                o.gpm ?? '—',
                t.tarefa,
                _executores(t),
                t.coordenador.isNotEmpty ? t.coordenador : '—',
                _fmtDate(t.dataInicio),
                _fmtDate(t.dataFim),
                '', // Coluna Observação vazia
              ];
            }).toList(),
          ),
      ],
    );
  }

  // ── Rodapé ─────────────────────────────────────────────────────────────────
  Widget _buildFooter() {
    return Text(
      'Gerado pelo sistema TaskFlow · ${_fmtNow()}',
      style: TextStyle(fontSize: 10, color: Colors.grey[400]),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _sectionTitle(String title, int count, Color color) {
    return Row(
      children: [
        Container(width: 4, height: 18, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Text('$count registro${count != 1 ? 's' : ''}',
              style: TextStyle(fontSize: 11, color: color)),
        ),
      ],
    );
  }

  Widget _emptyMsg(String msg) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(msg, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Tabela reutilizável — usa Table nativo para melhor controle de largura
// ─────────────────────────────────────────────────────────────────────────────

class _PrintTable extends StatefulWidget {
  final List<String> columns;
  final Map<int, TableColumnWidth> columnWidths;
  final List<List<String>> rows;

  const _PrintTable({
    required this.columns,
    required this.columnWidths,
    required this.rows,
  });

  @override
  State<_PrintTable> createState() => _PrintTableState();
}

class _PrintTableState extends State<_PrintTable> {
  int? _sortCol;
  bool _sortAsc = true;

  // ── Ordenação inteligente ───────────────────────────────────────────────────
  List<List<String>> get _sorted {
    if (_sortCol == null) return widget.rows;
    final col = _sortCol!;
    final sorted = [...widget.rows];
    sorted.sort((a, b) {
      final va = col < a.length ? a[col] : '';
      final vb = col < b.length ? b[col] : '';
      int cmp;
      // Tenta ordenar como inteiro (ex: coluna #)
      final ia = int.tryParse(va);
      final ib = int.tryParse(vb);
      if (ia != null && ib != null) {
        cmp = ia.compareTo(ib);
      } else {
        // Tenta ordenar como data dd/mm/yyyy
        final da = _parseDate(va);
        final db = _parseDate(vb);
        if (da != null && db != null) {
          cmp = da.compareTo(db);
        } else {
          cmp = va.toLowerCase().compareTo(vb.toLowerCase());
        }
      }
      return _sortAsc ? cmp : -cmp;
    });
    return sorted;
  }

  DateTime? _parseDate(String s) {
    // Formato: dd/mm/yyyy
    final parts = s.split('/');
    if (parts.length != 3) return null;
    final d = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final y = int.tryParse(parts[2]);
    if (d == null || m == null || y == null) return null;
    return DateTime(y, m, d);
  }

  void _onHeaderTap(int index) {
    setState(() {
      if (_sortCol == index) {
        _sortAsc = !_sortAsc;
      } else {
        _sortCol = index;
        _sortAsc = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final headerColor = Colors.blueGrey[50]!;
    const borderSide = BorderSide(color: Color(0xFFCCCCCC), width: 0.5);
    const border = TableBorder(
      top: borderSide,
      bottom: borderSide,
      left: borderSide,
      right: borderSide,
      horizontalInside: borderSide,
      verticalInside: borderSide,
    );
    final data = _sorted;

    return Table(
      columnWidths: widget.columnWidths,
      border: border,
      children: [
        // ── Cabeçalho com sorting ──────────────────────────────────────────
        TableRow(
          decoration: BoxDecoration(color: headerColor),
          children: widget.columns.asMap().entries.map((e) {
            final idx = e.key;
            final label = e.value;
            final isActive = _sortCol == idx;
            return GestureDetector(
              onTap: () => _onHeaderTap(idx),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                color: isActive
                    ? Colors.blueGrey[100]
                    : Colors.transparent,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isActive
                              ? Colors.blueGrey[900]
                              : Colors.blueGrey[800],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isActive) ...[
                      const SizedBox(width: 2),
                      Icon(
                        _sortAsc
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 11,
                        color: Colors.blueGrey[700],
                      ),
                    ] else ...[
                      const SizedBox(width: 2),
                      Icon(Icons.unfold_more_rounded,
                          size: 11, color: Colors.blueGrey[300]),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        // ── Dados ──────────────────────────────────────────────────────────
        ...data.asMap().entries.map((e) {
          final isEven = e.key.isEven;
          return TableRow(
            decoration:
                BoxDecoration(color: isEven ? Colors.white : Colors.grey[50]),
            children: e.value.map((cell) => _dataCell(cell)).toList(),
          );
        }),
      ],
    );
  }

  Widget _dataCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, color: Colors.black87),
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
      ),
    );
  }
}
