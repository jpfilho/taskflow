import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/models/task_warning.dart';
import 'warning_severity_theme.dart';
import '../../../../utils/conflict_detection.dart';
import '../../../../models/task.dart';

/// Painel lateral de alertas da tarefa (layout referência: Task Alert Side Panel).
/// Header com ícone + título + subtítulo (tarefa), lista de cards por warning,
/// mensagem "Não há outros alertas pendentes" e rodapé com ações.
/// [debugTaskId], [debugTaskStatus], [debugTaskStatusId]: opcionais para exibir bloco Debug.
class WarningsDetailPanel extends StatelessWidget {
  final String taskTarefaLabel;
  final List<TaskWarning> warnings;
  final Task? task; // tarefa atual para enriquecer conflitos
  final List<Task>? allTasks; // lista completa para resolução pai/filhos
  final VoidCallback? onClose;
  final VoidCallback? onUpdateStatus;
  final VoidCallback? onAdjustDates;
  final VoidCallback? onSnooze;
  final String? debugTaskId;
  final String? debugTaskStatus;
  final String? debugTaskStatusId;

  const WarningsDetailPanel({
    super.key,
    required this.taskTarefaLabel,
    required this.warnings,
    this.task,
    this.allTasks,
    this.onClose,
    this.onUpdateStatus,
    this.onAdjustDates,
    this.onSnooze,
    this.debugTaskId,
    this.debugTaskStatus,
    this.debugTaskStatusId,
  });

  static const double _panelMaxWidth = 448;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB);
    final surface = isDark ? const Color(0xFF1F2937) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF374151)
        : const Color(0xFFE5E7EB);
    final primaryColor = const Color(0xFF1A56DB);

    return Container(
      constraints: const BoxConstraints(maxWidth: _panelMaxWidth),
      decoration: BoxDecoration(color: bg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context, borderColor),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 0),
                  ...warnings.map((w) => _WarningCard(warning: w)),
                  const SizedBox(height: 24),
                  if (debugTaskId != null ||
                      debugTaskStatus != null ||
                      debugTaskStatusId != null)
                    _buildDebugSection(context),
                  _buildNoOtherAlerts(theme),
                ],
              ),
            ),
          ),
          _buildFooter(context, borderColor, bg, primaryColor, surface),
        ],
      ),
    );
  }

  /// Monta um bloco adicional quando for conflito de executores (W3),
  /// usando a mesma lógica do Gantt para listar TODOS os executores em conflito,
  /// agrupados por dia do período de execução da tarefa.
  Widget? _buildConflictEnrichment(BuildContext context) {
    if (warnings.isEmpty) return null;
    // Encontrar primeiro warning W3 (conflito de executor)
    final w = warnings.firstWhere(
      (x) =>
          x.warningCode.toUpperCase().startsWith('W3') ||
          x.message.toLowerCase().contains('conflito de executor'),
      orElse: () => const TaskWarning(
        taskId: '',
        warningCode: '',
        severity: 'LOW',
        message: '',
        fixHint: '',
      ),
    );
    if (w.taskId.isEmpty) return null;
    if (task == null || allTasks == null || allTasks!.isEmpty) return null;
    final execIds = ConflictDetection.getExecutorIdsForTask(task!);
    if (execIds.isEmpty) return null;

    // Mapa id->nome para exibição
    final idToName = <String, String>{};
    for (final t in allTasks!) {
      for (final ep in t.executorPeriods) {
        if (ep.executorId.trim().isNotEmpty &&
            ep.executorNome.trim().isNotEmpty) {
          idToName[ep.executorId.trim()] = ep.executorNome.trim();
          idToName[ep.executorNome.trim()] = ep.executorNome.trim();
        }
      }
      for (final name in t.executores) {
        if (name.trim().isNotEmpty) idToName[name.trim()] = name.trim();
      }
      if (t.executor.isNotEmpty) {
        for (final name in t.executor.split(',')) {
          if (name.trim().isNotEmpty) idToName[name.trim()] = name.trim();
        }
      }
    }

    // Descobrir o range de execução (somente EXECUCAO)
    DateTime? minStart;
    DateTime? maxEnd;
    for (final ep in task!.executorPeriods) {
      for (final p in ep.periods) {
        if (p.tipoPeriodo.toUpperCase() != 'EXECUCAO') continue;
        minStart = (minStart == null || p.dataInicio.isBefore(minStart))
            ? p.dataInicio
            : minStart;
        maxEnd = (maxEnd == null || p.dataFim.isAfter(maxEnd))
            ? p.dataFim
            : maxEnd;
      }
    }
    if (minStart == null || maxEnd == null) {
      for (final s in task!.ganttSegments) {
        if (s.tipoPeriodo.toUpperCase() != 'EXECUCAO') continue;
        minStart = (minStart == null || s.dataInicio.isBefore(minStart))
            ? s.dataInicio
            : minStart;
        maxEnd = (maxEnd == null || s.dataFim.isAfter(maxEnd))
            ? s.dataFim
            : maxEnd;
      }
    }
    if (minStart == null || maxEnd == null) return null;

    // Coletar conflitos por dia → nome → descrições
    final dayToNameToDescs = <DateTime, Map<String, List<String>>>{};
    var current = DateTime(minStart.year, minStart.month, minStart.day);
    final endDay = DateTime(maxEnd.year, maxEnd.month, maxEnd.day);
    while (!current.isAfter(endDay)) {
      final namesToDescs = <String, List<String>>{};
      for (final id in execIds) {
        if (!ConflictDetection.hasConflictOnDayForExecutor(
          allTasks!,
          current,
          id,
        )) {
          continue;
        }
        final descs = ConflictDetection.getConflictDescriptionsForDay(
          allTasks!,
          current,
          id,
          allTasks: allTasks!,
        )..sort();
        if (descs.isEmpty) continue;
        final display = _displayName(idToName, id);
        if (display.isEmpty) continue;
        namesToDescs[display] = descs;
      }
      if (namesToDescs.isNotEmpty) {
        dayToNameToDescs[current] = namesToDescs;
      }
      current = current.add(const Duration(days: 1));
    }
    if (dayToNameToDescs.isEmpty) return null;

    // Renderização: título + blocos por dia + bullets por executor
    final theme = Theme.of(context);
    final daysSorted = dayToNameToDescs.keys.toList()..sort();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'EXECUTORES EM CONFLITO',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          // Resumo: total de dias e chips com contagem de executores por dia
          Text(
            '${daysSorted.length} dia(s) com conflito',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final d in daysSorted)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    '${_formatDate(d)} · ${dayToNameToDescs[d]!.length} exec',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ...daysSorted.map((d) {
            final entries = dayToNameToDescs[d]!.entries.toList()
              ..sort((a, b) => a.key.compareTo(b.key));
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDate(d),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• '),
                          Expanded(
                            child: Text(
                              '${e.key}: ${e.value.join(' ; ')}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _displayName(Map<String, String> idToName, String idOrName) {
    final t = idOrName.trim();
    if (t.isEmpty) return '';
    // Se for UUID e existir mapeamento, usa nome; caso contrário, usa o próprio valor
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    if (uuidRegex.hasMatch(t)) return idToName[t] ?? '';
    return idToName[t] ?? t;
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Widget _buildHeader(BuildContext context, Color borderColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 32,
            height: 32,
            child: Icon(
              Icons.warning_amber_rounded,
              color: Colors.amber,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alertas da tarefa',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (taskTarefaLabel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    taskTarefaLabel,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (onClose != null)
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close),
              style: IconButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              tooltip: 'Fechar',
            ),
        ],
      ),
    );
  }

  Widget _buildDebugSection(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          childrenPadding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
          leading: Icon(
            Icons.bug_report_outlined,
            size: 20,
            color: theme.colorScheme.outline,
          ),
          title: Text(
            'Debug (tarefa na lista do app)',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.outline,
              fontWeight: FontWeight.w600,
            ),
          ),
          children: [
            _DebugRow(label: 'task.id', value: debugTaskId ?? '—'),
            _DebugRow(
              label: 'task.status (código)',
              value: debugTaskStatus ?? '—',
            ),
            _DebugRow(
              label: 'task.statusId (UUID)',
              value: debugTaskStatusId ?? '—',
            ),
            const SizedBox(height: 8),
            Text(
              'W5 só deve aparecer se status = PROG. Se status = RPGR aqui mas o alerta mostra PROG, o banco ainda tem PROG (salve de novo). Se statusId aponta para RPGR mas status = PROG, ao salvar o app envia status=RPGR.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoOtherAlerts(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 40,
              color: theme.colorScheme.outline.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 8),
            Text(
              'Não há outros alertas pendentes para esta tarefa.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(
    BuildContext context,
    Color borderColor,
    Color bg,
    Color primaryColor,
    Color surface,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final footerBg = isDark
        ? const Color(0xFF1F2937).withValues(alpha: 0.5)
        : const Color(0xFFF9FAFB);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: footerBg,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: () {
              onUpdateStatus?.call();
              if (onUpdateStatus == null) onClose?.call();
            },
            icon: const Icon(Icons.edit_outlined, size: 20),
            label: const Text('Atualizar Status'),
            style: FilledButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              onAdjustDates?.call();
              if (onAdjustDates == null) onClose?.call();
            },
            icon: const Icon(Icons.calendar_today_outlined, size: 20),
            label: const Text('Ajustar Datas'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              onSnooze?.call();
              onClose?.call();
            },
            child: Text(
              'Ignorar este alerta (Snooze)',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningCard extends StatefulWidget {
  final TaskWarning warning;

  const _WarningCard({required this.warning});

  @override
  State<_WarningCard> createState() => _WarningCardState();
}

class _WarningCardState extends State<_WarningCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final w = widget.warning;
    final severity = w.severity.toUpperCase();
    final isExecConflict =
        w.warningCode.toUpperCase().startsWith('W3') ||
        w.message.toLowerCase().contains('conflito de executor');
    final isFleetConflict =
        w.message.toLowerCase().contains('conflito de frota') ||
        w.warningCode.toUpperCase().contains('FROTA');
    final color = WarningSeverityTheme.colorForSeverity(w.severity);
    final bgColor = WarningSeverityTheme.backgroundColorForSeverity(w.severity);
    final severityLabel = WarningSeverityTheme.labelForSeverity(w.severity);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color borderColor;
    Color cardBg;
    if (severity == 'HIGH') {
      borderColor = isDark ? Colors.red.shade900 : Colors.red.shade200;
      cardBg = isDark
          ? Colors.red.shade900.withValues(alpha: 0.2)
          : Colors.red.shade50.withValues(alpha: 0.5);
    } else {
      borderColor = color.withValues(alpha: 0.5);
      cardBg = bgColor;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: severity == 'HIGH'
                          ? (isDark ? Colors.red.shade900 : Colors.red.shade100)
                          : color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      w.warningCode,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: severity == 'HIGH'
                            ? (isDark
                                  ? Colors.red.shade200
                                  : Colors.red.shade700)
                            : color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: severity == 'HIGH'
                          ? Colors.red.shade500
                          : color.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      severityLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: severity == 'HIGH' ? Colors.white : color,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              w.message,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            if (_expanded) ...[
              const SizedBox(height: 24),
              Text(
                'COMO RESOLVER',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                w.fixHint,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              // Para conflitos de executores (W3) e de frota, não repetir "Dados relevantes";
              // os detalhes ricos ficam apenas no tooltip do Gantt.
              if (!isExecConflict &&
                  !isFleetConflict &&
                  w.detailsJson != null &&
                  w.detailsJson!.isNotEmpty) ...[
                const SizedBox(height: 24),
                Divider(height: 1, color: borderColor.withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                Text(
                  'DADOS RELEVANTES',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                ...w.detailsJson!.entries.map(
                  (e) => _DetailRow(
                    label: _formatKey(e.key),
                    value: e.value?.toString() ?? '',
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  static String _formatKey(String key) {
    return key
        .replaceAllMapped(
          RegExp(r'_([a-z])'),
          (Match m) => ' ${m.group(1)!.toUpperCase()}',
        )
        .replaceFirstMapped(
          RegExp(r'^.'),
          (Match m) => m.group(0)!.toUpperCase(),
        );
  }
}

class _DebugRow extends StatelessWidget {
  final String label;
  final String value;

  const _DebugRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatefulWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  State<_DetailRow> createState() => _DetailRowState();
}

class _DetailRowState extends State<_DetailRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = const Color(0xFF1A56DB);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                widget.label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: SelectableText(
                      widget.value,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedOpacity(
                    opacity: _hover ? 1 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: IconButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: widget.value));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Copiado'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      icon: Icon(
                        Icons.copy_outlined,
                        size: 18,
                        color: primaryColor,
                      ),
                      style: IconButton.styleFrom(
                        padding: const EdgeInsets.all(4),
                        minimumSize: const Size(32, 32),
                        backgroundColor: _hover
                            ? primaryColor.withValues(alpha: 0.1)
                            : null,
                      ),
                      tooltip: 'Copiar',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
