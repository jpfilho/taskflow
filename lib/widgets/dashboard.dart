import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../utils/responsive.dart';
import '../services/tipo_atividade_service.dart';
import '../models/tipo_atividade.dart';
import '../services/status_service.dart';
import '../models/status.dart';
import '../features/warnings/warnings.dart';

class Dashboard extends StatelessWidget {
  final TaskService taskService;
  final List<Task>? filteredTasks; // Tarefas já filtradas (opcional)
  /// Mapa taskId -> alertas (opcional). Se null, usa mock para contadores.
  final Map<String, List<TaskWarning>>? warningsByTaskId;
  final StatusService _statusService = StatusService();

  Dashboard({
    super.key,
    required this.taskService,
    this.filteredTasks,
    this.warningsByTaskId,
  });

  // Calcular estatísticas a partir de uma lista de tarefas
  Map<String, dynamic> _calculateStatsFromTasks(List<Task> tasks) {
    final now = DateTime.now();
    int total = tasks.length;
    int emAndamento = 0;
    int concluidas = 0;
    int programadas = 0;
    int canceladas = 0;
    int atrasadas = 0;
    int venceHoje = 0;
    int semExecutor = 0;
    int semLocal = 0;
    int semCoordenador = 0;

    final Map<String, int> porStatus = {};
    final Map<String, int> porTipo = {};
    final Map<String, int> porRegional = {};
    final Map<String, int> porExecutor = {};
    final Map<String, int> porLocal = {};
    final Map<String, int> porCoordenador = {};
    final List<int> duracoesDias = [];
    final List<int> diasAtraso = [];
    final List<Task> atrasadasList = [];
    final List<Task> venceHojeList = [];
    final List<Task> semExecutorList = [];
    final List<Task> semLocalList = [];
    final List<Task> semCoordenadorList = [];
    final List<Task> canceladasList = [];
    final List<Task> emAndamentoList = [];
    final List<Task> programadasList = [];
    final List<Task> concluidasList = [];
    DateTime? minInicio;
    DateTime? maxFim;

    for (var task in tasks) {
      final status = task.status.trim();
      final statusUpper = status.toUpperCase();
      final isConcluida = statusUpper.contains('CONC') || statusUpper.contains('RPAR');
      final isAndamento = statusUpper.contains('ANDA');
      final isProgramada = statusUpper.contains('PROG');
      final isCancelada = statusUpper.contains('CANC');

      if (isConcluida) {
        concluidas++;
        concluidasList.add(task);
      } else if (isAndamento) {
        emAndamento++;
        emAndamentoList.add(task);
      } else if (isProgramada) {
        programadas++;
        programadasList.add(task);
      } else if (isCancelada) {
        canceladas++;
        canceladasList.add(task);
      }

      porStatus[status.isEmpty ? 'Sem Status' : status] = (porStatus[status.isEmpty ? 'Sem Status' : status] ?? 0) + 1;
      porTipo[task.tipo.isEmpty ? 'Sem Tipo' : task.tipo] = (porTipo[task.tipo.isEmpty ? 'Sem Tipo' : task.tipo] ?? 0) + 1;
      porRegional[task.regional.isEmpty ? 'Sem Regional' : task.regional] =
          (porRegional[task.regional.isEmpty ? 'Sem Regional' : task.regional] ?? 0) + 1;

      final executorKey = task.executores.isNotEmpty ? task.executores.join(', ') : (task.executor.isEmpty ? 'Sem Executor' : task.executor);
      porExecutor[executorKey] = (porExecutor[executorKey] ?? 0) + 1;

      final localKey = task.locais.isNotEmpty ? task.locais.first : 'Sem Local';
      porLocal[localKey] = (porLocal[localKey] ?? 0) + 1;
      final coordKey = task.coordenador.isNotEmpty ? task.coordenador : 'Sem Coordenador';
      porCoordenador[coordKey] = (porCoordenador[coordKey] ?? 0) + 1;

      if (task.executor.isEmpty && task.executores.isEmpty) semExecutor++;
      if (localKey == 'Sem Local') semLocal++;
      if (task.coordenador.isEmpty) semCoordenador++;
      if (task.executor.isEmpty && task.executores.isEmpty) semExecutorList.add(task);
      if (localKey == 'Sem Local') semLocalList.add(task);
      if (task.coordenador.isEmpty) semCoordenadorList.add(task);

      // Prazos e datas
      final fim = task.dataFim;
      if (!isConcluida && !isCancelada && (isAndamento || isProgramada) && fim.isBefore(now)) {
        atrasadas++;
        atrasadasList.add(task);
        diasAtraso.add(now.difference(fim).inDays);
      } else if (!isConcluida && !isCancelada &&
          fim.year == now.year &&
          fim.month == now.month &&
          fim.day == now.day) {
        venceHoje++;
        venceHojeList.add(task);
      }

      // Duração (fim - início) em dias
      final duracao = task.dataFim.difference(task.dataInicio).inDays;
      if (duracao >= 0) {
        duracoesDias.add(duracao);
      }

      final currentMin = minInicio;
      if (currentMin == null || task.dataInicio.isBefore(currentMin)) {
        minInicio = task.dataInicio;
      }
      final currentMax = maxFim;
      if (currentMax == null || task.dataFim.isAfter(currentMax)) {
        maxFim = task.dataFim;
      }
    }

    final mediaDuracao = duracoesDias.isEmpty
        ? 0
        : (duracoesDias.reduce((a, b) => a + b) / duracoesDias.length).toDouble();
    final atrasoMedio =
        diasAtraso.isEmpty ? 0 : (diasAtraso.reduce((a, b) => a + b) / diasAtraso.length).toDouble();
    final startRange = minInicio;
    final endRange = maxFim;
    final diasIntervalo = (startRange != null && endRange != null)
        ? endRange.difference(startRange).inDays.abs() + 1
        : 1;
    final produtividadeDia = diasIntervalo > 0 ? total / diasIntervalo : total.toDouble();
    final eficiencia =
        (concluidas + atrasadas) == 0 ? 0 : (concluidas / (concluidas + atrasadas));

    return {
      'total': total,
      'emAndamento': emAndamento,
      'concluidas': concluidas,
      'programadas': programadas,
      'canceladas': canceladas,
      'atrasadas': atrasadas,
      'venceHoje': venceHoje,
      'semExecutor': semExecutor,
      'semLocal': semLocal,
      'semCoordenador': semCoordenador,
      'mediaDuracaoDias': mediaDuracao,
      'atrasoMedioDias': atrasoMedio,
      'produtividadeDia': produtividadeDia,
      'eficiencia': eficiencia,
      'listaAtrasadas': atrasadasList,
      'listaVenceHoje': venceHojeList,
      'listaSemExecutor': semExecutorList,
      'listaSemLocal': semLocalList,
      'listaSemCoordenador': semCoordenadorList,
      'listaCanceladas': canceladasList,
      'listaEmAndamento': emAndamentoList,
      'listaProgramadas': programadasList,
      'listaConcluidas': concluidasList,
      'listaTotal': tasks,
      'porStatus': porStatus,
      'porTipo': porTipo,
      'porRegional': porRegional,
      'porExecutor': porExecutor,
      'porLocal': porLocal,
      'porCoordenador': porCoordenador,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    Future<Map<String, Color>> _loadStatusColors() async {
      final list = await _statusService.getAllStatus();
      final map = <String, Color>{};
      for (final s in list) {
        map[s.codigo.toUpperCase()] = _hexToColor(s.cor);
      }
      return map;
    }

    Widget _buildWithColors(Map<String, dynamic> stats) {
      return FutureBuilder<Map<String, Color>>(
        future: _loadStatusColors(),
        builder: (context, colorSnap) {
          final statusColors = colorSnap.data ?? {};
      return SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 8 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
                _buildSummaryCards(context, stats, isMobile, statusColors),
            const SizedBox(height: 16),
                _buildDetailedStats(context, stats, isMobile),
          ],
        ),
      );
        },
      );
    }

    // IMPORTANTE: Sempre usar filteredTasks quando disponível para evitar crash
    // Se filteredTasks não foi fornecido, usar lista vazia em vez de buscar todas as tarefas
    final tasksToUse = filteredTasks ?? [];
    
    if (tasksToUse.isEmpty && filteredTasks == null) {
      // Se não há tarefas filtradas e não foram fornecidas, mostrar mensagem
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Nenhuma tarefa disponível',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Aplique filtros para ver as estatísticas',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
          ],
        ),
      );
    }
    
    // Calcular estatísticas a partir das tarefas filtradas
    final stats = _calculateStatsFromTasks(tasksToUse);
    return _buildWithColors(stats);
  }

  Widget _buildSummaryCards(BuildContext context, Map<String, dynamic> stats, bool isMobile, Map<String, Color> statusColors) {
    Color resolve(String code, Color fallback) => statusColors[code.toUpperCase()] ?? fallback;

    // Função auxiliar para converter dinamicamente para List<Task> com proteção
    List<Task> _asTaskList(dynamic v) {
      if (v == null) return <Task>[];
      if (v is List<Task>) return v;
      if (v is List) {
        try {
          return v.whereType<Task>().toList();
        } catch (e) {
          print('⚠️ Erro ao converter lista de tarefas: $e');
          return <Task>[];
        }
      }
      return <Task>[];
    }
    
    final listaTotal = _asTaskList(stats['listaTotal']);
    final listaEmAndamento = _asTaskList(stats['listaEmAndamento']);
    final listaConcluidas = _asTaskList(stats['listaConcluidas']);
    final listaProgramadas = _asTaskList(stats['listaProgramadas']);
    final listaCanceladas = _asTaskList(stats['listaCanceladas']);

    final effectiveWarnings = warningsByTaskId ?? {};
    int highCount = 0, mediumCount = 0, lowCount = 0, tasksWithWarnings = 0;
    for (final list in effectiveWarnings.values) {
      if (list.isEmpty) continue;
      tasksWithWarnings++;
      for (final w in list) {
        switch (w.severity.toUpperCase()) {
          case 'HIGH': highCount++; break;
          case 'MEDIUM': mediumCount++; break;
          case 'LOW': lowCount++; break;
        }
      }
    }

    final cards = <Widget>[
      _buildStatCard(
        'Total',
        stats['total'].toString(),
        Icons.assignment,
        Colors.blue,
        isMobile,
        onTap: () => _showTaskList(context, 'Todas as tarefas', listaTotal),
      ),
      _buildStatCard(
        'Em Andamento',
        stats['emAndamento'].toString(),
        Icons.schedule,
        resolve('ANDA', Colors.orange),
        isMobile,
        onTap: () => _showTaskList(context, 'Em andamento', listaEmAndamento),
      ),
      _buildStatCard(
        'Concluídas',
        stats['concluidas'].toString(),
        Icons.check_circle,
        resolve('CONC', resolve('RPAR', Colors.green)),
        isMobile,
        onTap: () => _showTaskList(context, 'Concluídas', listaConcluidas),
      ),
      _buildStatCard(
        'Programadas',
        stats['programadas'].toString(),
        Icons.event,
        resolve('PROG', Colors.purple),
        isMobile,
        onTap: () => _showTaskList(context, 'Programadas', listaProgramadas),
      ),
      _buildStatCard(
        'Canceladas',
        stats['canceladas'].toString(),
        Icons.cancel,
        resolve('CANC', Colors.redAccent),
        isMobile,
        onTap: () => _showTaskList(context, 'Canceladas', listaCanceladas),
      ),
      _buildAlertasCard(
        context,
        isMobile,
        tasksWithWarnings: tasksWithWarnings,
        highCount: highCount,
        mediumCount: mediumCount,
        lowCount: lowCount,
        effectiveWarnings: effectiveWarnings,
        listaTotal: listaTotal,
      ),
    ];

    return GridView.count(
      crossAxisCount: isMobile ? 2 : 6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: isMobile ? 1.2 : 1.5,
      children: cards,
    );
  }

  Widget _buildAlertasCard(
    BuildContext context,
    bool isMobile, {
    required int tasksWithWarnings,
    required int highCount,
    required int mediumCount,
    required int lowCount,
    required Map<String, List<TaskWarning>> effectiveWarnings,
    required List<Task> listaTotal,
  }) {
    final color = tasksWithWarnings > 0 ? Colors.orange : Colors.grey;
    return _buildStatCard(
      'Alertas Ativos',
      tasksWithWarnings.toString(),
      Icons.warning_amber_rounded,
      color,
      isMobile,
      subtitle: highCount > 0 || mediumCount > 0 || lowCount > 0
          ? 'Alta: $highCount  Média: $mediumCount  Baixa: $lowCount'
          : null,
      onTap: tasksWithWarnings > 0
          ? () => _showAlertasConsolidados(context, effectiveWarnings, listaTotal)
          : null,
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, bool isMobile, {VoidCallback? onTap, String? subtitle}) {
    final content = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.14),
            color.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
          Container(
            width: isMobile ? 34 : 40,
            height: isMobile ? 34 : 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: isMobile ? 20 : 24),
          ),
          const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
              fontSize: isMobile ? 22 : 30,
              fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
              fontSize: isMobile ? 11 : 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: isMobile ? 9 : 10,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: content,
      ),
    );
  }

  Widget _buildDetailedStats(BuildContext context, Map<String, dynamic> stats, bool isMobile) {
    int _asInt(dynamic v) => v is num ? v.toInt() : 0;
    Map<String, int> _asMapInt(dynamic v) {
      if (v is Map) {
        return v.map<String, int>((key, value) {
          final k = key.toString();
          final val = value is num ? value.toInt() : 0;
          return MapEntry(k, val);
        });
      }
      return {};
    }

    final total = _asInt(stats['total']);
    final porStatus = _asMapInt(stats['porStatus']);
    final porTipo = _asMapInt(stats['porTipo']);
    final porRegional = _asMapInt(stats['porRegional']);
    final porExecutor = _asMapInt(stats['porExecutor']);
    final porLocal = _asMapInt(stats['porLocal']);
    final porCoordenador = _asMapInt(stats['porCoordenador']);
    final atrasadas = _asInt(stats['atrasadas']);
    final venceHoje = _asInt(stats['venceHoje']);
    final semExecutor = _asInt(stats['semExecutor']);
    final semLocal = _asInt(stats['semLocal']);
    final semCoordenador = _asInt(stats['semCoordenador']);
    final mediaDuracao = stats['mediaDuracaoDias'] is num ? (stats['mediaDuracaoDias'] as num).toDouble() : 0.0;
    
    // Função auxiliar para converter dinamicamente para List<Task> com proteção
    List<Task> _asTaskList(dynamic v) {
      if (v == null) return <Task>[];
      if (v is List<Task>) return v;
      if (v is List) {
        try {
          return v.whereType<Task>().toList();
        } catch (e) {
          print('⚠️ Erro ao converter lista de tarefas: $e');
          return <Task>[];
        }
      }
      return <Task>[];
    }
    
    final listaAtrasadas = _asTaskList(stats['listaAtrasadas']);
    final listaVenceHoje = _asTaskList(stats['listaVenceHoje']);
    final listaSemExecutor = _asTaskList(stats['listaSemExecutor']);
    final listaSemLocal = _asTaskList(stats['listaSemLocal']);
    final listaSemCoordenador = _asTaskList(stats['listaSemCoordenador']);
    final listaCanceladas = _asTaskList(stats['listaCanceladas']);

    final cardWidth = isMobile ? double.infinity : 420.0;

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildSectionCard(
          'Alertas rápidos',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildChipInfo('Atrasadas', atrasadas, Colors.red, () => _showTaskList(context, 'Atrasadas', listaAtrasadas)),
                  _buildChipInfo('Vencem hoje', venceHoje, Colors.orange, () => _showTaskList(context, 'Vencem hoje', listaVenceHoje)),
                  _buildChipInfo('Sem executor', semExecutor, Colors.purple, () => _showTaskList(context, 'Sem executor', listaSemExecutor)),
                  _buildChipInfo('Sem local', semLocal, Colors.blueGrey, () => _showTaskList(context, 'Sem local', listaSemLocal)),
                  _buildChipInfo('Sem coordenador', semCoordenador, Colors.teal, () => _showTaskList(context, 'Sem coordenador', listaSemCoordenador)),
                  _buildChipInfo('Duração média (dias)', mediaDuracao.toStringAsFixed(1), Colors.indigo, null),
                ],
              ),
            ],
          ),
          isMobile,
          width: cardWidth,
        ),
        _buildSectionCard(
          'Distribuição por Status',
          _buildStatusDistribution(porStatus, total, isMobile),
          isMobile,
          width: cardWidth,
        ),
        _buildSectionCard(
          'Distribuição por Tipo',
          _buildTypeDistribution(context, porTipo, isMobile),
          isMobile,
          width: cardWidth,
        ),
        _buildSectionCard(
          'Distribuição por Regional',
          _buildRegionalDistribution(porRegional, isMobile),
          isMobile,
          width: cardWidth,
        ),
        _buildSectionCard(
          'Top Executores',
          _buildTopList(porExecutor, isMobile, maxItems: 5),
          isMobile,
          width: cardWidth,
        ),
        _buildSectionCard(
          'Top Locais',
          _buildTopList(porLocal, isMobile, maxItems: 5),
          isMobile,
          width: cardWidth,
        ),
        _buildSectionCard(
          'Distribuição por Coordenador',
          _buildTopList(porCoordenador, isMobile, maxItems: 8),
          isMobile,
          width: cardWidth,
        ),
        _buildSectionCard(
          'Canceladas',
          _buildTaskPreviewList(listaCanceladas, isMobile),
          isMobile,
          width: cardWidth,
        ),
        _buildSectionCard(
          'Produtividade & Eficiência',
          _buildProductivityIndicators(stats, isMobile),
          isMobile,
          width: cardWidth,
        ),
      ],
    );
  }

  Widget _buildChipInfo(String label, Object value, Color color, VoidCallback? onTap) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Text(
            '$label: $value',
            style: TextStyle(
              color: color.withOpacity(0.95),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return chip;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: chip,
      ),
    );
  }

  void _showTaskList(BuildContext context, String title, List<Task> tasks) {
    // Proteção: limitar número de tarefas exibidas para evitar crash
    final maxTasks = 500; // Limite razoável para evitar problemas de performance
    final tasksToShow = tasks.length > maxTasks ? tasks.take(maxTasks).toList() : tasks;
    final hasMore = tasks.length > maxTasks;
    
    showDialog(
      context: context,
      builder: (context) {
        return FutureBuilder<List<Status>>(
          future: _statusService.getAllStatus(),
          builder: (context, snapshot) {
            final mapCorStatus = <String, Color>{};
            if (snapshot.hasData) {
              for (final s in snapshot.data!) {
                mapCorStatus[s.codigo.toUpperCase()] = _hexToColor(s.cor);
              }
            }

            Color resolveStatusColor(String status) {
              final key = status.toUpperCase();
              if (mapCorStatus.containsKey(key)) return mapCorStatus[key]!;
              if (key.contains('CONC') || key.contains('RPAR')) return Colors.green;
              if (key.contains('ANDA')) return Colors.orange;
              if (key.contains('PROG')) return Colors.purple;
              if (key.contains('CANC')) return Colors.redAccent;
              return Colors.blueGrey;
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                  if (hasMore)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Mostrando $maxTasks de ${tasks.length} tarefas',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ),
                ],
              ),
              content: SizedBox(
                width: 560,
                height: 440,
                child: tasksToShow.isEmpty
                    ? Center(
                        child: Text(
                          'Nenhuma tarefa encontrada.',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      )
                    : ListView.separated(
                        itemCount: tasksToShow.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final t = tasksToShow[index];
                          final status = t.status.isNotEmpty ? t.status : '—';
                          final statusColor = resolveStatusColor(status);

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              border: Border.all(color: Colors.grey.withOpacity(0.12)),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  margin: const EdgeInsets.only(top: 6, right: 10),
                                  decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t.tarefa,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: [
                                          _buildTag('Status', status, statusColor),
                                          _buildTag(
                                            'Executor',
                                            t.executores.isNotEmpty
                                                ? t.executores.join(', ')
                                                : (t.executor.isNotEmpty ? t.executor : '—'),
                                            Colors.indigo,
                                            wrap: true,
                                          ),
                                          _buildTag(
                                            'Início',
                                            '${t.dataInicio.day}/${t.dataInicio.month}/${t.dataInicio.year}',
                                            Colors.blueGrey,
                                          ),
                                          _buildTag(
                                            'Fim',
                                            '${t.dataFim.day}/${t.dataFim.month}/${t.dataFim.year}',
                                            Colors.blueGrey,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Fechar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAlertasConsolidados(
    BuildContext context,
    Map<String, List<TaskWarning>> effectiveWarnings,
    List<Task> listaTotal,
  ) {
    final tasksById = {for (final t in listaTotal) t.id: t};
    final entries = effectiveWarnings.entries
        .where((e) => e.value.isNotEmpty)
        .map((e) => MapEntry(e.key, e.value))
        .toList();
    if (entries.isEmpty) return;

    final isMobile = MediaQuery.of(context).size.width < 600;
    if (isMobile) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) => _buildAlertasConsolidadosContent(
            context: ctx,
            entries: entries,
            tasksById: tasksById,
            onClose: () => Navigator.of(ctx).pop(),
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange[700]),
              const SizedBox(width: 10),
              const Text('Alertas Ativos'),
            ],
          ),
          content: SizedBox(
            width: 520,
            height: 400,
            child: _buildAlertasConsolidadosContent(
              context: ctx,
              entries: entries,
              tasksById: tasksById,
              onClose: () => Navigator.of(ctx).pop(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildAlertasConsolidadosContent({
    required BuildContext context,
    required List<MapEntry<String, List<TaskWarning>>> entries,
    required Map<String, Task> tasksById,
    VoidCallback? onClose,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onClose != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                  tooltip: 'Fechar',
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final taskId = entries[index].key;
              final warnings = entries[index].value;
              final task = tasksById[taskId];
              final label = task?.tarefa ?? taskId;
              final maxSev = WarningSeverityTheme.maxSeverity(warnings);
              final color = WarningSeverityTheme.colorForSeverity(maxSev);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: color.withOpacity(0.4)),
                ),
                child: ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${warnings.length}',
                        style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 12),
                      ),
                    ),
                  ),
                  title: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  subtitle: Text(
                    '${warnings.length} alerta(s) · ${WarningSeverityTheme.labelForSeverity(maxSev)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                  onTap: () {
                    showWarningsPanel(
                      context: context,
                      taskTarefaLabel: label,
                      warnings: warnings,
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Color _hexToColor(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.blueGrey;
    try {
      String value = hex.trim();
      if (value.startsWith('#')) value = value.substring(1);
      if (value.length == 6) value = 'ff$value';
      return Color(int.parse(value, radix: 16));
    } catch (e) {
      return Colors.blueGrey;
    }
  }

  Widget _buildProductivityIndicators(Map<String, dynamic> stats, bool isMobile) {
    double _asDouble(dynamic v) {
      if (v is num) return v.toDouble();
      return 0.0;
    }

    final atrasoMedio = _asDouble(stats['atrasoMedioDias']);
    final prodDia = _asDouble(stats['produtividadeDia']);
    final eficiencia = _asDouble(stats['eficiencia']);
    final concluidas = stats['concluidas'] ?? 0;
    final total = stats['total'] ?? 0;
    final taxaConclusao = total == 0 ? 0.0 : (concluidas / total);

    Widget buildItem(String title, String value, Color color, IconData icon) {
      return Container(
        padding: EdgeInsets.all(isMobile ? 10 : 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: isMobile ? 18 : 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: isMobile ? 11 : 12, fontWeight: FontWeight.w600, color: color),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(fontSize: isMobile ? 13 : 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: buildItem('Taxa de conclusão', '${(taxaConclusao * 100).toStringAsFixed(1)}%', Colors.green, Icons.trending_up)),
            const SizedBox(width: 8),
            Expanded(child: buildItem('Produtividade/dia', prodDia.toStringAsFixed(2), Colors.blue, Icons.bar_chart)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: buildItem('Eficiência (CONC / CONC+ATR)', '${(eficiencia * 100).toStringAsFixed(1)}%', Colors.indigo, Icons.speed)),
            const SizedBox(width: 8),
            Expanded(child: buildItem('Atraso médio (dias)', atrasoMedio.toStringAsFixed(1), Colors.redAccent, Icons.timer)),
          ],
        ),
      ],
    );
  }

  Widget _buildTaskPreviewList(List<Task> tasks, bool isMobile) {
    if (tasks.isEmpty) {
      return Text(
        'Nenhuma tarefa',
        style: TextStyle(color: Colors.grey[600], fontSize: isMobile ? 12 : 13),
      );
    }
    return Column(
      children: tasks.take(5).map((t) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  t.tarefa,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: isMobile ? 12 : 13),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                t.status.isNotEmpty ? t.status : '—',
                style: TextStyle(color: Colors.grey[700], fontSize: isMobile ? 11 : 12),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTag(String label, String value, Color color, {bool wrap = false}) {
    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: wrap
          ? RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color.withOpacity(0.9),
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                ],
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$label: ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color.withOpacity(0.9),
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionCard(String title, Widget child, bool isMobile, {double? width}) {
    return SizedBox(
      width: width ?? (isMobile ? double.infinity : 480.0),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF6F7FB),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 14 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle(title, isMobile),
              const SizedBox(height: 10),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopList(Map<String, int> data, bool isMobile, {int maxItems = 5}) {
    if (data.isEmpty) {
      return Text(
        'Nenhum dado disponível',
        style: TextStyle(color: Colors.grey[600], fontSize: isMobile ? 12 : 13),
      );
    }
    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(maxItems).toList();
    final maxValue = top.first.value;

    return Column(
      children: top.map((e) {
        final pct = maxValue == 0 ? 0.0 : e.value / maxValue;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  e.key,
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 13,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: Text(
                  e.value.toString(),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 12 : 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 8,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionTitle(String title, bool isMobile) {
    return Text(
      title,
      style: TextStyle(
        fontSize: isMobile ? 14 : 16,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF1E3A5F),
      ),
    );
  }

  Widget _buildStatusDistribution(Map<String, int> distribution, int total, bool isMobile) {
    String _statusDescricao(String sigla) {
      final key = sigla.trim().toUpperCase();
      const map = {
        'ANDA': 'Em Andamento',
        'ANDAMENTO': 'Em Andamento',
        'PROG': 'Programada',
        'PROGR': 'Programada',
        'CONC': 'Concluída',
        'RPAR': 'Realizado Parcialmente',
        'CANC': 'Cancelada',
      };
      return map[key] ?? sigla;
    }

    return Card(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 8 : 16),
        child: Column(
          children: distribution.entries.map((entry) {
            final percentage = total > 0 ? (entry.value / total * 100) : 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: isMobile ? 60 : 80,
                    child: Text(
                      _statusDescricao(entry.key),
                      style: TextStyle(fontSize: isMobile ? 10 : 12),
                    ),
                  ),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        entry.key == 'ANDA' ? Colors.orange :
                        entry.key == 'CONC' || entry.key == 'RPAR' ? Colors.green :
                        entry.key == 'CANC' ? Colors.redAccent :
                        Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${entry.value} (${percentage.toStringAsFixed(1)}%)',
                    style: TextStyle(fontSize: isMobile ? 10 : 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTypeDistribution(BuildContext context, Map<String, int> distribution, bool isMobile) {
    return FutureBuilder<List<TipoAtividade>>(
      future: TipoAtividadeService().getTiposAtividadeAtivos(),
      builder: (context, snapshot) {
        final mapDescricao = <String, String>{};
        if (snapshot.hasData) {
          for (final t in snapshot.data!) {
            mapDescricao[t.codigo.toUpperCase()] = t.descricao;
          }
        }
        String _tipoDescricao(String sigla) {
          final key = sigla.trim().toUpperCase();
          return mapDescricao[key] ?? sigla;
        }

    return Card(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 8 : 16),
        child: Column(
          children: distribution.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                        _tipoDescricao(entry.key),
                    style: TextStyle(fontSize: isMobile ? 10 : 12),
                  ),
                  Text(
                    entry.value.toString(),
                    style: TextStyle(
                      fontSize: isMobile ? 10 : 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
        );
      },
    );
  }

  Widget _buildRegionalDistribution(Map<String, int> distribution, bool isMobile) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 8 : 16),
        child: Column(
          children: distribution.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    entry.key,
                    style: TextStyle(fontSize: isMobile ? 10 : 12),
                  ),
                  Text(
                    entry.value.toString(),
                    style: TextStyle(
                      fontSize: isMobile ? 10 : 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}




