import 'package:flutter/material.dart';
import '../design_system/taskflow_design_system.dart';
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

    Future<Map<String, Color>> loadStatusColors() async {
      final list = await _statusService.getAllStatus();
      final map = <String, Color>{};
      for (final s in list) {
        map[s.codigo.toUpperCase()] = _hexToColor(s.cor);
      }
      return map;
    }

    Widget buildWithColors(Map<String, dynamic> stats) {
      return FutureBuilder<Map<String, Color>>(
        future: loadStatusColors(),
        builder: (context, colorSnap) {
          final statusColors = colorSnap.data ?? {};
          return SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? TFSpacing.s8 : TFSpacing.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSummaryCards(context, stats, isMobile, statusColors),
                const SizedBox(height: TFSpacing.s16),
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
      return const Center(
        child: TFEmptyState(
          icon: Icons.info_outline,
          title: 'Nenhuma tarefa disponível',
          description: 'Aplique filtros para ver as estatísticas.',
        ),
      );
    }
    
    // Calcular estatísticas a partir das tarefas filtradas
    final stats = _calculateStatsFromTasks(tasksToUse);
    return buildWithColors(stats);
  }

  Widget _buildSummaryCards(BuildContext context, Map<String, dynamic> stats, bool isMobile, Map<String, Color> statusColors) {
    final colors = context.tfColors;
    Color resolve(String code, Color fallback) => statusColors[code.toUpperCase()] ?? fallback;

    // Função auxiliar para converter dinamicamente para List<Task> com proteção
    List<Task> asTaskList(dynamic v) {
      if (v == null) return <Task>[];
      if (v is List<Task>) return v;
      if (v is List) {
        try {
          return v.whereType<Task>().toList();
        } catch (e) {
          return <Task>[];
        }
      }
      return <Task>[];
    }
    
    final listaTotal = asTaskList(stats['listaTotal']);
    final listaEmAndamento = asTaskList(stats['listaEmAndamento']);
    final listaConcluidas = asTaskList(stats['listaConcluidas']);
    final listaProgramadas = asTaskList(stats['listaProgramadas']);
    final listaCanceladas = asTaskList(stats['listaCanceladas']);

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
        context,
        'Total',
        stats['total'].toString(),
        Icons.assignment,
        colors.primary,
        isMobile,
        onTap: () => _showTaskList(context, 'Todas as tarefas', listaTotal),
      ),
      _buildStatCard(
        context,
        'Em Andamento',
        stats['emAndamento'].toString(),
        Icons.schedule,
        resolve('ANDA', colors.warning),
        isMobile,
        onTap: () => _showTaskList(context, 'Em andamento', listaEmAndamento),
      ),
      _buildStatCard(
        context,
        'Concluídas',
        stats['concluidas'].toString(),
        Icons.check_circle,
        resolve('CONC', resolve('RPAR', colors.success)),
        isMobile,
        onTap: () => _showTaskList(context, 'Concluídas', listaConcluidas),
      ),
      _buildStatCard(
        context,
        'Programadas',
        stats['programadas'].toString(),
        Icons.event,
        resolve('PROG', colors.info),
        isMobile,
        onTap: () => _showTaskList(context, 'Programadas', listaProgramadas),
      ),
      _buildStatCard(
        context,
        'Canceladas',
        stats['canceladas'].toString(),
        Icons.cancel,
        resolve('CANC', colors.danger),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth < TFBreakpoints.sm
            ? 2
            : (constraints.maxWidth < TFBreakpoints.lg ? 3 : 6);
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: TFSpacing.s8,
          crossAxisSpacing: TFSpacing.s8,
          childAspectRatio: isMobile ? 1.3 : 1.5,
          children: cards,
        );
      },
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
    final colors = context.tfColors;
    final color = tasksWithWarnings > 0 ? colors.warning : colors.textSecondary;
    return _buildStatCard(
      context,
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

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
    bool isMobile, {
    VoidCallback? onTap,
    String? subtitle,
  }) {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    final content = TFCard(
      padding: EdgeInsets.all(isMobile ? TFSpacing.s8 : TFSpacing.s12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: isMobile ? 32 : 38,
            height: isMobile ? 32 : 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: isMobile ? 18 : 22),
          ),
          const SizedBox(height: TFSpacing.s4),
          Text(
            value,
            style: typography.cardTitle.copyWith(
              fontSize: isMobile ? 20 : 26,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: typography.caption.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: typography.caption.copyWith(
                fontSize: isMobile ? 9 : 10,
                color: colors.textMuted,
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

    return InkWell(
      borderRadius: BorderRadius.circular(TFRadius.r8),
      onTap: onTap,
      child: content,
    );
  }

  Widget _buildDetailedStats(BuildContext context, Map<String, dynamic> stats, bool isMobile) {
    int asInt(dynamic v) => v is num ? v.toInt() : 0;
    Map<String, int> asMapInt(dynamic v) {
      if (v is Map) {
        return v.map<String, int>((key, value) {
          final k = key.toString();
          final val = value is num ? value.toInt() : 0;
          return MapEntry(k, val);
        });
      }
      return {};
    }

    final total = asInt(stats['total']);
    final porStatus = asMapInt(stats['porStatus']);
    final porTipo = asMapInt(stats['porTipo']);
    final porRegional = asMapInt(stats['porRegional']);
    final porExecutor = asMapInt(stats['porExecutor']);
    final porLocal = asMapInt(stats['porLocal']);
    final porCoordenador = asMapInt(stats['porCoordenador']);
    final atrasadas = asInt(stats['atrasadas']);
    final venceHoje = asInt(stats['venceHoje']);
    final semExecutor = asInt(stats['semExecutor']);
    final semLocal = asInt(stats['semLocal']);
    final semCoordenador = asInt(stats['semCoordenador']);
    final mediaDuracao = stats['mediaDuracaoDias'] is num ? (stats['mediaDuracaoDias'] as num).toDouble() : 0.0;
    
    // Função auxiliar para converter dinamicamente para List<Task> com proteção
    List<Task> asTaskList(dynamic v) {
      if (v == null) return <Task>[];
      if (v is List<Task>) return v;
      if (v is List) {
        try {
          return v.whereType<Task>().toList();
        } catch (e) {
          return <Task>[];
        }
      }
      return <Task>[];
    }
    
    final listaAtrasadas = asTaskList(stats['listaAtrasadas']);
    final listaVenceHoje = asTaskList(stats['listaVenceHoje']);
    final listaSemExecutor = asTaskList(stats['listaSemExecutor']);
    final listaSemLocal = asTaskList(stats['listaSemLocal']);
    final listaSemCoordenador = asTaskList(stats['listaSemCoordenador']);
    final listaCanceladas = asTaskList(stats['listaCanceladas']);

    final cardWidth = isMobile ? double.infinity : 420.0;
    final colors = context.tfColors;

    return Wrap(
      spacing: TFSpacing.s12,
      runSpacing: TFSpacing.s12,
      children: [
        _buildSectionCard(
          context,
          'Alertas rápidos',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Wrap(
                spacing: TFSpacing.s8,
                runSpacing: TFSpacing.s8,
                children: [
                  _buildChipInfo(context, 'Atrasadas', atrasadas, colors.danger, () => _showTaskList(context, 'Atrasadas', listaAtrasadas)),
                  _buildChipInfo(context, 'Vencem hoje', venceHoje, colors.warning, () => _showTaskList(context, 'Vencem hoje', listaVenceHoje)),
                  _buildChipInfo(context, 'Sem executor', semExecutor, colors.info, () => _showTaskList(context, 'Sem executor', listaSemExecutor)),
                  _buildChipInfo(context, 'Sem local', semLocal, colors.textSecondary, () => _showTaskList(context, 'Sem local', listaSemLocal)),
                  _buildChipInfo(context, 'Sem coordenador', semCoordenador, colors.primary, () => _showTaskList(context, 'Sem coordenador', listaSemCoordenador)),
                  _buildChipInfo(context, 'Duração média (dias)', mediaDuracao.toStringAsFixed(1), colors.primary, null),
                ],
              ),
            ],
          ),
          isMobile,
          width: cardWidth,
        ),
        _buildSectionCard(
          context,
          'Distribuição por Status',
          _buildStatusDistribution(context, porStatus, total, isMobile),
          isMobile,
          width: cardWidth,
        ),
        _buildSectionCard(
          context,
          'Distribuição por Tipo',
          _buildTypeDistribution(context, porTipo, isMobile),
          isMobile,
          width: cardWidth,
        ),
        _buildSectionCard(
          context,
          'Distribuição por Regional',
          _buildRegionalDistribution(context, porRegional, isMobile),
          isMobile,
          width: cardWidth,
        ),
        _buildSectionCard(
          context,
          'Top Executores',
          _buildTopList(context, porExecutor, isMobile, maxItems: 5),
          isMobile,
          width: cardWidth,
        ),
        _buildSectionCard(
          context,
          'Top Locais',
          _buildTopList(context, porLocal, isMobile, maxItems: 5),
          isMobile,
          width: cardWidth,
        ),
        _buildSectionCard(
          context,
          'Distribuição por Coordenador',
          _buildTopList(context, porCoordenador, isMobile, maxItems: 8),
          isMobile,
          width: cardWidth,
        ),
        _buildSectionCard(
          context,
          'Canceladas',
          _buildTaskPreviewList(context, listaCanceladas, isMobile),
          isMobile,
          width: cardWidth,
        ),
        _buildSectionCard(
          context,
          'Produtividade & Eficiência',
          _buildProductivityIndicators(context, stats, isMobile),
          isMobile,
          width: cardWidth,
        ),
      ],
    );
  }

  Widget _buildChipInfo(BuildContext context, String label, Object value, Color color, VoidCallback? onTap) {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: TFSpacing.s8, vertical: TFSpacing.s4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(TFRadius.rFull),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Text(
            '$label: $value',
            style: typography.caption.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return chip;

    return InkWell(
      borderRadius: BorderRadius.circular(TFRadius.rFull),
      onTap: onTap,
      child: chip,
    );
  }

  void _showTaskList(BuildContext context, String title, List<Task> tasks) {
    final colors = context.tfColors;
    final typography = context.tfTypography;
    final maxTasks = 500;
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
              if (key.contains('CONC') || key.contains('RPAR')) return colors.success;
              if (key.contains('ANDA')) return colors.warning;
              if (key.contains('PROG')) return colors.info;
              if (key.contains('CANC')) return colors.danger;
              return colors.textSecondary;
            }

            return AlertDialog(
              backgroundColor: colors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TFRadius.r12)),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: typography.sectionTitle,
                  ),
                  if (hasMore)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Mostrando $maxTasks de ${tasks.length} tarefas',
                        style: typography.caption.copyWith(color: colors.textSecondary),
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
                          style: typography.bodySmall.copyWith(color: colors.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        itemCount: tasksToShow.length,
                        separatorBuilder: (_, __) => const SizedBox(height: TFSpacing.s4),
                        itemBuilder: (context, index) {
                          final t = tasksToShow[index];
                          final status = t.status.isNotEmpty ? t.status : '—';
                          final statusColor = resolveStatusColor(status);

                          return Container(
                            decoration: BoxDecoration(
                              color: colors.surfaceSecondary,
                              borderRadius: BorderRadius.circular(TFRadius.r8),
                              border: Border.all(color: colors.borderSubtle),
                            ),
                            padding: const EdgeInsets.all(TFSpacing.s8),
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
                                        style: typography.bodyMedium.copyWith(fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: [
                                          _buildTag(context, 'Status', status, statusColor),
                                          _buildTag(
                                            context,
                                            'Executor',
                                            t.executores.isNotEmpty
                                                ? t.executores.join(', ')
                                                : (t.executor.isNotEmpty ? t.executor : '—'),
                                            colors.primary,
                                            wrap: true,
                                          ),
                                          _buildTag(
                                            context,
                                            'Início',
                                            '${t.dataInicio.day}/${t.dataInicio.month}/${t.dataInicio.year}',
                                            colors.textSecondary,
                                          ),
                                          _buildTag(
                                            context,
                                            'Fim',
                                            '${t.dataFim.day}/${t.dataFim.month}/${t.dataFim.year}',
                                            colors.textSecondary,
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
              actionsPadding: const EdgeInsets.symmetric(horizontal: TFSpacing.s12, vertical: TFSpacing.s8),
              actions: [
                TFButton(
                  label: 'Fechar',
                  variant: TFButtonVariant.secondary,
                  onPressed: () => Navigator.of(context).pop(),
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
    final colors = context.tfColors;
    final typography = context.tfTypography;
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
        backgroundColor: colors.surface,
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
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TFRadius.r12)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: colors.warning),
              const SizedBox(width: 10),
              Text('Alertas Ativos', style: typography.sectionTitle),
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
            TFButton(
              label: 'Fechar',
              variant: TFButtonVariant.secondary,
              onPressed: () => Navigator.of(ctx).pop(),
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
    final colors = context.tfColors;
    final typography = context.tfTypography;

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
                TFIconButton(
                  icon: Icons.close,
                  tooltip: 'Fechar',
                  onPressed: onClose,
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
              return Container(
                margin: const EdgeInsets.only(bottom: TFSpacing.s4),
                decoration: BoxDecoration(
                  color: colors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(TFRadius.r8),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(TFRadius.r4),
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
                    style: typography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${warnings.length} alerta(s) · ${WarningSeverityTheme.labelForSeverity(maxSev)}',
                    style: typography.caption.copyWith(color: colors.textSecondary),
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

  Widget _buildProductivityIndicators(BuildContext context, Map<String, dynamic> stats, bool isMobile) {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    double asDouble(dynamic v) {
      if (v is num) return v.toDouble();
      return 0.0;
    }

    final atrasoMedio = asDouble(stats['atrasoMedioDias']);
    final prodDia = asDouble(stats['produtividadeDia']);
    final eficiencia = asDouble(stats['eficiencia']);
    final concluidas = stats['concluidas'] ?? 0;
    final total = stats['total'] ?? 0;
    final taxaConclusao = total == 0 ? 0.0 : (concluidas / total);

    Widget buildItem(String title, String value, Color color, IconData icon) {
      return Container(
        padding: EdgeInsets.all(isMobile ? TFSpacing.s4 : TFSpacing.s8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(TFRadius.r8),
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
                    style: typography.caption.copyWith(fontWeight: FontWeight.w600, color: color),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: typography.cardTitle.copyWith(fontSize: isMobile ? 13 : 15, fontWeight: FontWeight.bold),
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
            Expanded(child: buildItem('Taxa de conclusão', '${(taxaConclusao * 100).toStringAsFixed(1)}%', colors.success, Icons.trending_up)),
            const SizedBox(width: 8),
            Expanded(child: buildItem('Produtividade/dia', prodDia.toStringAsFixed(2), colors.primary, Icons.bar_chart)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: buildItem('Eficiência (CONC / CONC+ATR)', '${(eficiencia * 100).toStringAsFixed(1)}%', colors.info, Icons.speed)),
            const SizedBox(width: 8),
            Expanded(child: buildItem('Atraso médio (dias)', atrasoMedio.toStringAsFixed(1), colors.danger, Icons.timer)),
          ],
        ),
      ],
    );
  }

  Widget _buildTaskPreviewList(BuildContext context, List<Task> tasks, bool isMobile) {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    if (tasks.isEmpty) {
      return Text(
        'Nenhuma tarefa',
        style: typography.bodySmall.copyWith(color: colors.textSecondary),
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
                  style: typography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                t.status.isNotEmpty ? t.status : '—',
                style: typography.caption.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTag(BuildContext context, String label, String value, Color color, {bool wrap = false}) {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(TFRadius.r4),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: wrap
          ? RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: typography.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: typography.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
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
                  style: typography.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(
                  value,
                  style: typography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionCard(BuildContext context, String title, Widget child, bool isMobile, {double? width}) {
    return SizedBox(
      width: width ?? (isMobile ? double.infinity : 480.0),
      child: TFCard(
        padding: EdgeInsets.all(isMobile ? TFSpacing.s8 : TFSpacing.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(context, title, isMobile),
            const SizedBox(height: TFSpacing.s8),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildTopList(BuildContext context, Map<String, int> data, bool isMobile, {int maxItems = 5}) {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    if (data.isEmpty) {
      return Text(
        'Nenhum dado disponível',
        style: typography.bodySmall.copyWith(color: colors.textSecondary),
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
                  style: typography.bodySmall,
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
                  style: typography.bodySmall.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(TFRadius.rFull),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 8,
                    backgroundColor: colors.surfaceSecondary,
                    valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, bool isMobile) {
    final typography = context.tfTypography;
    return Text(
      title,
      style: typography.cardTitle.copyWith(
        fontSize: isMobile ? 14 : 16,
      ),
    );
  }

  Widget _buildStatusDistribution(BuildContext context, Map<String, int> distribution, int total, bool isMobile) {
    final colors = context.tfColors;
    final typography = context.tfTypography;

    String statusDescricao(String sigla) {
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

    return Column(
      children: distribution.entries.map((entry) {
        final percentage = total > 0 ? (entry.value / total * 100) : 0.0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: isMobile ? 70 : 90,
                child: Text(
                  statusDescricao(entry.key),
                  style: typography.caption,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(TFRadius.rFull),
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    minHeight: 8,
                    backgroundColor: colors.surfaceSecondary,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      entry.key.contains('ANDA') ? colors.warning :
                      entry.key.contains('CONC') || entry.key.contains('RPAR') ? colors.success :
                      entry.key.contains('CANC') ? colors.danger :
                      colors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${entry.value} (${percentage.toStringAsFixed(1)}%)',
                style: typography.caption.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTypeDistribution(BuildContext context, Map<String, int> distribution, bool isMobile) {
    final typography = context.tfTypography;

    return FutureBuilder<List<TipoAtividade>>(
      future: TipoAtividadeService().getTiposAtividadeAtivos(),
      builder: (context, snapshot) {
        final mapDescricao = <String, String>{};
        if (snapshot.hasData) {
          for (final t in snapshot.data!) {
            mapDescricao[t.codigo.toUpperCase()] = t.descricao;
          }
        }
        String tipoDescricao(String sigla) {
          final key = sigla.trim().toUpperCase();
          return mapDescricao[key] ?? sigla;
        }

        return Column(
          children: distribution.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      tipoDescricao(entry.key),
                      style: typography.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    entry.value.toString(),
                    style: typography.bodySmall.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildRegionalDistribution(BuildContext context, Map<String, int> distribution, bool isMobile) {
    final typography = context.tfTypography;

    return Column(
      children: distribution.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                entry.key,
                style: typography.bodySmall,
              ),
              Text(
                entry.value.toString(),
                style: typography.bodySmall.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}




