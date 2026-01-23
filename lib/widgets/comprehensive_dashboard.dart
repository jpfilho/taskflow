import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../services/nota_sap_service.dart';
import '../services/ordem_service.dart';
import '../services/at_service.dart';
import '../services/si_service.dart';
import '../utils/responsive.dart';

class ComprehensiveDashboard extends StatefulWidget {
  final TaskService taskService;
  final List<Task>? filteredTasks;

  const ComprehensiveDashboard({
    super.key,
    required this.taskService,
    this.filteredTasks,
  });

  @override
  State<ComprehensiveDashboard> createState() => _ComprehensiveDashboardState();
}

class _ComprehensiveDashboardState extends State<ComprehensiveDashboard> {
  final NotaSAPService _notaSAPService = NotaSAPService();
  final OrdemService _ordemService = OrdemService();
  final ATService _atService = ATService();
  final SIService _siService = SIService();

  bool _isLoading = true;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadAllStats();
  }

  Future<void> _loadAllStats() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Carregar todas as estatísticas em paralelo
      final results = await Future.wait([
        _loadTaskStats(),
        _loadNotasStats(),
        _loadOrdensStats(),
        _loadATsStats(),
        _loadSIsStats(),
      ]);

      setState(() {
        _stats = {
          'tarefas': results[0],
          'notas': results[1],
          'ordens': results[2],
          'ats': results[3],
          'sis': results[4],
        };
        _isLoading = false;
      });
    } catch (e) {
      print('Erro ao carregar estatísticas: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>> _loadTaskStats() async {
    List<Task> tasks;
    if (widget.filteredTasks != null) {
      tasks = widget.filteredTasks!;
    } else {
      tasks = await widget.taskService.getAllTasks();
    }

    final now = DateTime.now();
    int total = tasks.length;
    int emAndamento = 0;
    int concluidas = 0;
    int programadas = 0;
    int vencidas = 0;

    final porStatus = <String, int>{};
    final porTipo = <String, int>{};

    for (var task in tasks) {
      final status = task.status.toUpperCase();
      final currentStatusCount = porStatus[status] ?? 0;
      porStatus[status] = currentStatusCount + 1;

      final tipo = task.tipo;
      final currentTipoCount = porTipo[tipo] ?? 0;
      porTipo[tipo] = currentTipoCount + 1;

      if (status.contains('CONCLU') || status.contains('FINALIZ')) {
        concluidas++;
      } else if (status.contains('ANDAMENTO') || status.contains('EXEC')) {
        emAndamento++;
      } else if (task.dataInicio.isAfter(now)) {
        programadas++;
      }

      if (task.dataFim.isBefore(now) && !status.contains('CONCLU')) {
        vencidas++;
      }
    }

    return {
      'total': total,
      'emAndamento': emAndamento,
      'concluidas': concluidas,
      'programadas': programadas,
      'vencidas': vencidas,
      'porStatus': porStatus,
      'porTipo': porTipo,
    };
  }

  Future<Map<String, dynamic>> _loadNotasStats() async {
    final notas = await _notaSAPService.getAllNotas();

    int total = notas.length;
    int abertas = 0;
    int concluidas = 0;
    int vencidas = 0;
    int semPrazo = 0;
    int emRisco = 0; // Entre 0 e 30 dias

    final porStatus = <String, int>{};
    final porPrioridade = <String, int>{};
    final porTipo = <String, int>{};

    for (var nota in notas) {
      final status = nota.statusSistema?.toUpperCase() ?? 'SEM STATUS';
      porStatus[status] = (porStatus[status] ?? 0) + 1;

      final prioridade = nota.textPrioridade ?? 'Sem Prioridade';
      porPrioridade[prioridade] = (porPrioridade[prioridade] ?? 0) + 1;

      final tipo = nota.tipo ?? 'Sem Tipo';
      porTipo[tipo] = (porTipo[tipo] ?? 0) + 1;

      if (status.contains('MSEN')) {
        concluidas++;
      } else {
        abertas++;
      }

      final diasRestantes = nota.diasRestantes;
      if (diasRestantes == null) {
        semPrazo++;
      } else if (diasRestantes <= 0) {
        vencidas++;
      } else if (diasRestantes <= 30) {
        emRisco++;
      }
    }

    return {
      'total': total,
      'abertas': abertas,
      'concluidas': concluidas,
      'vencidas': vencidas,
      'semPrazo': semPrazo,
      'emRisco': emRisco,
      'porStatus': porStatus,
      'porPrioridade': porPrioridade,
      'porTipo': porTipo,
    };
  }

  Future<Map<String, dynamic>> _loadOrdensStats() async {
    final ordens = await _ordemService.getAllOrdens();

    int total = ordens.length;
    final porStatus = <String, int>{};
    final porTipo = <String, int>{};

    for (var ordem in ordens) {
      final status = ordem.statusSistema?.toUpperCase() ?? 'SEM STATUS';
      porStatus[status] = (porStatus[status] ?? 0) + 1;

      final tipo = ordem.tipo ?? 'Sem Tipo';
      porTipo[tipo] = (porTipo[tipo] ?? 0) + 1;
    }

    return {
      'total': total,
      'porStatus': porStatus,
      'porTipo': porTipo,
    };
  }

  Future<Map<String, dynamic>> _loadATsStats() async {
    final ats = await _atService.getAllATs();

    int total = ats.length;
    final porStatus = <String, int>{};

    for (var at in ats) {
      final status = at.statusSistema?.toUpperCase() ?? 'SEM STATUS';
      porStatus[status] = (porStatus[status] ?? 0) + 1;
    }

    return {
      'total': total,
      'porStatus': porStatus,
    };
  }

  Future<Map<String, dynamic>> _loadSIsStats() async {
    final sis = await _siService.getAllSIs();

    int total = sis.length;
    final porStatus = <String, int>{};
    final porTipo = <String, int>{};

    for (var si in sis) {
      final status = si.statusSistema?.toUpperCase() ?? 'SEM STATUS';
      porStatus[status] = (porStatus[status] ?? 0) + 1;

      final tipo = si.tipo ?? 'Sem Tipo';
      porTipo[tipo] = (porTipo[tipo] ?? 0) + 1;
    }

    return {
      'total': total,
      'porStatus': porStatus,
      'porTipo': porTipo,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadAllStats,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 12 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(isMobile),
            const SizedBox(height: 24),
            _buildOverviewCards(isMobile),
            const SizedBox(height: 24),
            _buildTarefasSection(isMobile),
            const SizedBox(height: 24),
            _buildNotasSection(isMobile),
            const SizedBox(height: 24),
            _buildSAPSection(isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[700]!, Colors.blue[500]!],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.dashboard, color: Colors.white, size: 32),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dashboard Geral',
                style: TextStyle(
                  fontSize: isMobile ? 24 : 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              Text(
                'Visão geral de todas as atividades',
                style: TextStyle(
                  fontSize: isMobile ? 14 : 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadAllStats,
          tooltip: 'Atualizar',
        ),
      ],
    );
  }

  Widget _buildOverviewCards(bool isMobile) {
    final tarefas = _stats['tarefas'] as Map<String, dynamic>? ?? {};
    final notas = _stats['notas'] as Map<String, dynamic>? ?? {};
    final ordens = _stats['ordens'] as Map<String, dynamic>? ?? {};
    final ats = _stats['ats'] as Map<String, dynamic>? ?? {};
    final sis = _stats['sis'] as Map<String, dynamic>? ?? {};

    final totalGeral = (tarefas['total'] as int? ?? 0) +
        (notas['total'] as int? ?? 0) +
        (ordens['total'] as int? ?? 0) +
        (ats['total'] as int? ?? 0) +
        (sis['total'] as int? ?? 0);

    return GridView.count(
      crossAxisCount: isMobile ? 2 : 5,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: isMobile ? 1.1 : 1.2,
      children: [
        _buildOverviewCard(
          'Total Geral',
          totalGeral.toString(),
          Icons.apps,
          Colors.blue,
          isMobile,
        ),
        _buildOverviewCard(
          'Tarefas',
          (tarefas['total'] as int? ?? 0).toString(),
          Icons.assignment,
          Colors.orange,
          isMobile,
        ),
        _buildOverviewCard(
          'Notas SAP',
          (notas['total'] as int? ?? 0).toString(),
          Icons.description,
          Colors.blue,
          isMobile,
        ),
        _buildOverviewCard(
          'Ordens',
          (ordens['total'] as int? ?? 0).toString(),
          Icons.receipt_long,
          Colors.purple,
          isMobile,
        ),
        _buildOverviewCard(
          'ATs + SIs',
          ((ats['total'] as int? ?? 0) + (sis['total'] as int? ?? 0)).toString(),
          Icons.work,
          Colors.teal,
          isMobile,
        ),
      ],
    );
  }

  Widget _buildOverviewCard(
    String title,
    String value,
    IconData icon,
    Color color,
    bool isMobile,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: isMobile ? 28 : 36),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: isMobile ? 24 : 32,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: isMobile ? 11 : 13,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTarefasSection(bool isMobile) {
    final tarefas = _stats['tarefas'] as Map<String, dynamic>? ?? {};
    return _buildSectionCard(
      'Tarefas',
      Icons.assignment,
      Colors.orange,
      [
        _buildStatRow('Total', (tarefas['total'] as int? ?? 0).toString(), Colors.blue),
        _buildStatRow('Em Andamento', (tarefas['emAndamento'] as int? ?? 0).toString(), Colors.orange),
        _buildStatRow('Concluídas', (tarefas['concluidas'] as int? ?? 0).toString(), Colors.green),
        _buildStatRow('Programadas', (tarefas['programadas'] as int? ?? 0).toString(), Colors.purple),
        if ((tarefas['vencidas'] as int? ?? 0) > 0)
          _buildStatRow('Vencidas', (tarefas['vencidas'] as int? ?? 0).toString(), Colors.red),
      ],
      _buildDistributionChart(tarefas['porStatus'] as Map<String, int>? ?? {}, isMobile),
      isMobile,
    );
  }

  Widget _buildNotasSection(bool isMobile) {
    final notas = _stats['notas'] as Map<String, dynamic>? ?? {};
    return _buildSectionCard(
      'Notas SAP',
      Icons.description,
      Colors.blue,
      [
        _buildStatRow('Total', (notas['total'] as int? ?? 0).toString(), Colors.blue),
        _buildStatRow('Abertas', (notas['abertas'] as int? ?? 0).toString(), Colors.orange),
        _buildStatRow('Concluídas', (notas['concluidas'] as int? ?? 0).toString(), Colors.green),
        _buildStatRow('Vencidas', (notas['vencidas'] as int? ?? 0).toString(), Colors.red),
        _buildStatRow('Em Risco', (notas['emRisco'] as int? ?? 0).toString(), Colors.yellow[700]!),
        _buildStatRow('Sem Prazo', (notas['semPrazo'] as int? ?? 0).toString(), Colors.grey),
      ],
      _buildDistributionChart(notas['porPrioridade'] as Map<String, int>? ?? {}, isMobile),
      isMobile,
    );
  }

  Widget _buildSAPSection(bool isMobile) {
    final ordens = _stats['ordens'] as Map<String, dynamic>? ?? {};
    final ats = _stats['ats'] as Map<String, dynamic>? ?? {};
    final sis = _stats['sis'] as Map<String, dynamic>? ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMiniCard(
                'Ordens',
                (ordens['total'] as int? ?? 0).toString(),
                Icons.receipt_long,
                Colors.purple,
                isMobile,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMiniCard(
                'ATs',
                (ats['total'] as int? ?? 0).toString(),
                Icons.assignment,
                Colors.indigo,
                isMobile,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMiniCard(
                'SIs',
                (sis['total'] as int? ?? 0).toString(),
                Icons.info,
                Colors.teal,
                isMobile,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionCard(
    String title,
    IconData icon,
    Color color,
    List<Widget> stats,
    Widget? chart,
    bool isMobile,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isMobile ? 18 : 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isMobile)
              Column(children: stats)
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: Column(children: stats)),
                  if (chart != null) ...[
                    const SizedBox(width: 16),
                    Expanded(flex: 3, child: chart),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionChart(Map<String, int> distribution, bool isMobile) {
    if (distribution.isEmpty) {
      return Center(
        child: Text(
          'Sem dados',
          style: TextStyle(color: Colors.grey[400]),
        ),
      );
    }

    final total = distribution.values.fold(0, (a, b) => a + b);

    return Column(
      children: distribution.entries.take(5).map((entry) {
        final percentage = total > 0 ? (entry.value / total * 100) : 0.0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${entry.value} (${percentage.toStringAsFixed(1)}%)',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: percentage / 100,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getColorForStatus(entry.key),
                ),
                minHeight: 8,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMiniCard(
    String title,
    String value,
    IconData icon,
    Color color,
    bool isMobile,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          children: [
            Icon(icon, color: color, size: isMobile ? 24 : 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: isMobile ? 20 : 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: isMobile ? 11 : 13,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Color _getColorForStatus(String status) {
    final upperStatus = status.toUpperCase();
    if (upperStatus.contains('CONCLU') || upperStatus.contains('FINALIZ')) {
      return Colors.green;
    } else if (upperStatus.contains('ANDAMENTO') || upperStatus.contains('EXEC')) {
      return Colors.orange;
    } else if (upperStatus.contains('PROG') || upperStatus.contains('PLAN')) {
      return Colors.blue;
    } else if (upperStatus.contains('VENCI') || upperStatus.contains('ATRAS')) {
      return Colors.red;
    }
    return Colors.grey;
  }
}
