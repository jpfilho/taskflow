import 'package:flutter/material.dart';
import '../../design_system/taskflow_design_system.dart';
import '../../models/task_sort_rule.dart';

/// Diálogo modal para configuração de ordenação em múltiplos níveis (sub-ordenações).
class TaskSortRulesDialog extends StatefulWidget {
  final bool isMobile;

  const TaskSortRulesDialog({
    super.key,
    this.isMobile = false,
  });

  /// Exibe o diálogo de configuração de sub-ordenações.
  static Future<bool?> show(BuildContext context, {bool isMobile = false}) {
    return showDialog<bool>(
      context: context,
      builder: (context) => TaskSortRulesDialog(isMobile: isMobile),
    );
  }

  @override
  State<TaskSortRulesDialog> createState() => _TaskSortRulesDialogState();
}

class _TaskSortRulesDialogState extends State<TaskSortRulesDialog> {
  final TaskSortService _service = TaskSortService.instance;
  late List<TaskSortRule> _rules;

  @override
  void initState() {
    super.initState();
    _rules = List<TaskSortRule>.from(_service.rules);
    if (_rules.isEmpty) {
      _rules.add(const TaskSortRule(column: 'LOCAL', ascending: true));
    }
  }

  void _addRule() {
    final usedColumns = _rules.map((r) => r.column).toSet();
    final remainingColumns = TaskSortService.availableColumns
        .where((col) => !usedColumns.contains(col))
        .toList();

    if (remainingColumns.isNotEmpty) {
      setState(() {
        _rules.add(TaskSortRule(column: remainingColumns.first, ascending: true));
      });
    }
  }

  void _removeRule(int index) {
    if (index == 0) return; // Não permite remover o critério principal
    setState(() {
      _rules.removeAt(index);
    });
  }

  void _updateRuleColumn(int index, String newColumn) {
    setState(() {
      _rules[index] = _rules[index].copyWith(column: newColumn);
    });
  }

  void _toggleRuleDirection(int index) {
    setState(() {
      _rules[index] =
          _rules[index].copyWith(ascending: !_rules[index].ascending);
    });
  }

  void _resetToDefault() {
    setState(() {
      _rules = [const TaskSortRule(column: 'LOCAL', ascending: true)];
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final canAddMore = _rules.length < TaskSortService.availableColumns.length;

    return TFModalDialog(
      title: 'Ordenação em Múltiplos Níveis',
      subtitle: 'Defina a ordem principal e critérios secundários para desempate',
      icon: Icons.low_priority_rounded,
      size: TFDialogSize.medium,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Banner Explicativo ──
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 20, color: colors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'O 1º critério define o agrupamento e a ordenação principal na tela. Os critérios seguintes são aplicados sucessivamente quando houver empate no critério anterior.',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Lista de Regras (Níveis) ──
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _rules.length,
              separatorBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(left: 32, top: 4, bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.arrow_downward, size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 6),
                    Text(
                      'em caso de empate, depois ordenar por:',
                      style: TextStyle(fontSize: 10, color: Colors.grey[600], fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
              itemBuilder: (context, index) {
                final rule = _rules[index];
                final isPrimary = index == 0;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isPrimary
                        ? colors.primary.withValues(alpha: 0.04)
                        : colors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isPrimary ? colors.primary.withValues(alpha: 0.3) : colors.borderSubtle,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Badge do Nível
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isPrimary ? colors.primary : Colors.grey[300],
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isPrimary ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Dropdown de Coluna
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: rule.column,
                            isDense: true,
                            items: TaskSortService.availableColumns.map((col) {
                              return DropdownMenuItem<String>(
                                value: col,
                                child: Text(
                                  col,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isPrimary ? FontWeight.bold : FontWeight.w500,
                                    color: colors.textPrimary,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) _updateRuleColumn(index, val);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Botão Toggle Direção (Crescente / Decrescente)
                      InkWell(
                        onTap: () => _toggleRuleDirection(index),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: colors.borderSubtle),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                rule.ascending ? Icons.arrow_upward : Icons.arrow_downward,
                                size: 14,
                                color: colors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                rule.ascending ? 'Crescente' : 'Decrescente',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: colors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Botão Excluir (apenas para sub-níveis)
                      if (!isPrimary) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          color: Colors.red[400],
                          tooltip: 'Remover este critério de desempate',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          onPressed: () => _removeRule(index),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // ── Botão Adicionar Sub-ordenação ──
            if (canAddMore)
              Center(
                child: TextButton.icon(
                  onPressed: _addRule,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text(
                    'Adicionar Sub-ordenação (Critério de Desempate)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
      primaryAction: TFButton(
        label: 'Aplicar',
        variant: TFButtonVariant.primary,
        leadingIcon: Icons.check,
        onPressed: () async {
          final nav = Navigator.of(context);
          await _service.saveRules(_rules);
          if (mounted) nav.pop(true);
        },
      ),
      secondaryAction: TFButton(
        label: 'Restaurar Padrão',
        variant: TFButtonVariant.ghost,
        onPressed: _resetToDefault,
      ),
    );
  }
}
