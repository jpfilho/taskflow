import 'package:flutter/material.dart';
import '../../design_system/taskflow_design_system.dart';
import '../../models/task_table_column.dart';

/// Diálogo modal que permite selecionar quais colunas da tabela de atividades serão exibidas,
/// oferecendo presets inteligentes e persistência completa em SharedPreferences.
class TaskTableColumnPickerDialog extends StatefulWidget {
  final bool isMobile;

  const TaskTableColumnPickerDialog({
    super.key,
    this.isMobile = false,
  });

  /// Exibe o diálogo de seleção de colunas.
  static Future<bool?> show(BuildContext context, {bool isMobile = false}) {
    return showDialog<bool>(
      context: context,
      builder: (context) => TaskTableColumnPickerDialog(isMobile: isMobile),
    );
  }

  @override
  State<TaskTableColumnPickerDialog> createState() =>
      _TaskTableColumnPickerDialogState();
}

class _TaskTableColumnPickerDialogState
    extends State<TaskTableColumnPickerDialog> {
  final TaskTableColumnService _service = TaskTableColumnService.instance;
  late Set<TaskTableColumn> _selectedColumns;
  late String _activePresetId;

  @override
  void initState() {
    super.initState();
    _selectedColumns = Set<TaskTableColumn>.from(_service.visibleColumns);
    _activePresetId = _service.activePresetId;
  }

  void _applyPreset(TaskTablePreset preset) {
    setState(() {
      _selectedColumns = Set<TaskTableColumn>.from(preset.columns);
      // Garantir sempre as obrigatórias
      _selectedColumns.add(TaskTableColumn.status);
      _selectedColumns.add(TaskTableColumn.tarefa);
      _activePresetId = preset.id;
    });
  }

  void _toggleColumn(TaskTableColumn column, bool? value) {
    if (column.isRequired) return; // Não pode ser desmarcada

    setState(() {
      if (value == true) {
        _selectedColumns.add(column);
      } else {
        _selectedColumns.remove(column);
      }
      _activePresetId = 'custom';
    });
  }

  Future<void> _showSavePresetDialog() async {
    final controller = TextEditingController();
    final colors = context.tfColors;

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.bookmark_add_outlined, size: 22, color: Colors.blue),
            SizedBox(width: 8),
            Text('Salvar Preset', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dê um nome para salvar a seleção atual de colunas nas suas preferências:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Ex: Visão Semanal, Modo Resumido...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) Navigator.of(ctx).pop(text);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty && mounted) {
      await _service.saveCustomPreset(name, _selectedColumns);
      setState(() {
        _activePresetId = _service.activePresetId;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Preset "$name" salvo com sucesso nas preferências!'),
            backgroundColor: colors.success,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _deletePreset(TaskTablePreset preset) async {
    final colors = context.tfColors;
    await _service.deleteCustomPreset(preset.id);
    setState(() {
      _activePresetId = _service.activePresetId;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Preset "${preset.name}" excluído das preferências.'),
          backgroundColor: colors.textSecondary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tfColors;
    final totalWidthFull = _service.calculateTotalWidth(widget.isMobile, TaskTableColumnService.presetAll.columns);
    final currentWidth = _service.calculateTotalWidth(widget.isMobile, _selectedColumns);
    final savedGanttPixels = (totalWidthFull - currentWidth).clamp(0.0, 9999.0);
    final allPresets = _service.allPresets;

    return TFModalDialog(
      title: 'Colunas da Tabela & Presets',
      subtitle: 'Configurações de colunas salvas nas preferências para otimizar o Gantt',
      icon: Icons.tune_rounded,
      size: TFDialogSize.medium,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Métricas de Espaço Ganho para o Gantt ──
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: savedGanttPixels > 0
                    ? Colors.green.withValues(alpha: 0.08)
                    : colors.surfaceSecondary,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: savedGanttPixels > 0
                      ? Colors.green.withValues(alpha: 0.3)
                      : colors.borderSubtle,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    savedGanttPixels > 0 ? Icons.tune_rounded : Icons.analytics_outlined,
                    color: savedGanttPixels > 0 ? Colors.green[700] : colors.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_selectedColumns.length} de ${TaskTableColumn.values.length} colunas ativas • Largura: ${currentWidth.toInt()}px',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          savedGanttPixels > 0
                              ? '🎯 +${savedGanttPixels.toInt()}px liberados diretamente para o gráfico Gantt!'
                              : 'Visualização completa de todas as 15 colunas.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: savedGanttPixels > 0 ? FontWeight.w600 : FontWeight.normal,
                            color: savedGanttPixels > 0 ? Colors.green[700] : colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Cabeçalho de Presets com Ação de Salvar ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PRESETS SALVOS EM PREFERENCES',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: colors.textSecondary,
                  ),
                ),
                InkWell(
                  onTap: _showSavePresetDialog,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 14, color: colors.primary),
                        const SizedBox(width: 2),
                        Text(
                          'Salvar Seleção',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Chips de Presets (Sistema + Usuário) ──
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: allPresets.map((preset) {
                final isMatch = _activePresetId == preset.id ||
                    _isEqualColumns(_selectedColumns, preset.columns);

                return _buildPresetChip(
                  preset: preset,
                  isActive: isMatch,
                  onTap: () => _applyPreset(preset),
                  onDelete: preset.isCustom ? () => _deletePreset(preset) : null,
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // ── Lista de Colunas (Checkboxes) ──
            Text(
              'COLUNAS INDIVIDUAIS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: widget.isMobile ? 1 : 2,
                mainAxisExtent: 44,
                crossAxisSpacing: 8,
                mainAxisSpacing: 4,
              ),
              itemCount: TaskTableColumn.values.length,
              itemBuilder: (context, index) {
                final column = TaskTableColumn.values[index];
                final isChecked = _selectedColumns.contains(column);

                return InkWell(
                  onTap: column.isRequired
                      ? null
                      : () => _toggleColumn(column, !isChecked),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: isChecked
                          ? colors.primary.withValues(alpha: 0.04)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isChecked
                            ? colors.primary.withValues(alpha: 0.2)
                            : colors.borderSubtle.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: isChecked,
                          onChanged: column.isRequired
                              ? null
                              : (val) => _toggleColumn(column, val),
                          activeColor: colors.primary,
                        ),
                        Icon(
                          column.icon,
                          size: 16,
                          color: isChecked ? colors.primary : colors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            column.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isChecked ? FontWeight.w600 : FontWeight.normal,
                              color: isChecked ? colors.textPrimary : colors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (column.isRequired)
                          Tooltip(
                            message: 'Coluna obrigatória para subtarefas',
                            child: Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(Icons.lock_outline, size: 14, color: Colors.grey[400]),
                            ),
                          )
                        else
                          Text(
                            '${column.width(widget.isMobile).toInt()}px',
                            style: TextStyle(fontSize: 10, color: colors.textSecondary),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      primaryAction: TFButton(
        label: 'Aplicar',
        variant: TFButtonVariant.primary,
        leadingIcon: Icons.check,
        onPressed: () async {
          await _service.saveColumns(_selectedColumns, presetId: _activePresetId);
          if (mounted) Navigator.of(context).pop(true);
        },
      ),
      secondaryAction: TFButton(
        label: 'Cancelar',
        variant: TFButtonVariant.ghost,
        onPressed: () => Navigator.of(context).pop(false),
      ),
    );
  }

  Widget _buildPresetChip({
    required TaskTablePreset preset,
    required bool isActive,
    required VoidCallback onTap,
    VoidCallback? onDelete,
  }) {
    final colors = context.tfColors;

    return Tooltip(
      message: preset.description,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.only(
            left: 12,
            right: onDelete != null ? 6 : 12,
            top: 5,
            bottom: 5,
          ),
          decoration: BoxDecoration(
            color: isActive ? colors.primary : colors.surfaceSecondary,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive ? colors.primary : colors.borderSubtle,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                preset.name,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  color: isActive ? Colors.white : colors.textPrimary,
                ),
              ),
              if (onDelete != null) ...[
                const SizedBox(width: 4),
                InkWell(
                  onTap: onDelete,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.close,
                      size: 14,
                      color: isActive ? Colors.white70 : colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool _isEqualColumns(Set<TaskTableColumn> a, Set<TaskTableColumn> b) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }
}
