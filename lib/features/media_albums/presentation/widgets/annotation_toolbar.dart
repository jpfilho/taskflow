import 'package:flutter/material.dart';
import '../../application/controllers/annotation_controller.dart';
import '../../data/models/annotation_models.dart';

/// Barra de ferramentas de anotação: ferramentas, cor, espessura, undo/redo, salvar/cancelar.
/// Mobile: bottom sheet; desktop: painel lateral.
class AnnotationToolbar extends StatelessWidget {
  const AnnotationToolbar({
    super.key,
    required this.controller,
    required this.onSave,
    required this.onCancel,
    this.isSaving = false,
    this.isCompact = false,
  });

  final AnnotationController controller;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final bool isSaving;
  final bool isCompact;

  static const List<Color> _palette = [
    Color(0xFF000000),
    Color(0xFFE53935),
    Color(0xFFD81B60),
    Color(0xFF8E24AA),
    Color(0xFF5E35B1),
    Color(0xFF3949AB),
    Color(0xFF1E88E5),
    Color(0xFF00ACC1),
    Color(0xFF00897B),
    Color(0xFF43A047),
    Color(0xFF7CB342),
    Color(0xFFC0CA33),
    Color(0xFFFDD835),
    Color(0xFFFFB300),
    Color(0xFFF4511E),
    Color(0xFF795548),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              top: BorderSide(color: theme.dividerColor),
            ),
          ),
          child: isCompact
              ? _buildCompact(context)
              : _buildFull(context),
        );
      },
    );
  }

  Widget _buildFull(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _toolChip(context, AnnotationTool.pan, Icons.pan_tool_rounded, 'Pan'),
            const SizedBox(width: 4),
            _toolChip(context, AnnotationTool.select, Icons.touch_app_rounded, 'Selecionar'),
            const SizedBox(width: 4),
            _toolChip(context, AnnotationTool.pencil, Icons.edit_rounded, 'Lápis'),
            const SizedBox(width: 4),
            _toolChip(context, AnnotationTool.arrow, Icons.arrow_upward_rounded, 'Seta'),
            const SizedBox(width: 4),
            _toolChip(context, AnnotationTool.polygon, Icons.hexagon_outlined, 'Polígono'),
            const SizedBox(width: 4),
            _toolChip(context, AnnotationTool.text, Icons.text_fields_rounded, 'Texto'),
            const Spacer(),
            if (controller.hasSelection)
              IconButton(
                icon: const Icon(Icons.delete_rounded),
                onPressed: controller.deleteSelected,
                tooltip: 'Excluir seleção',
              ),
            IconButton(
              icon: const Icon(Icons.undo_rounded),
              onPressed: controller.canUndo ? controller.undo : null,
              tooltip: 'Desfazer',
            ),
            IconButton(
              icon: const Icon(Icons.redo_rounded),
              onPressed: controller.canRedo ? controller.redo : null,
              tooltip: 'Refazer',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: controller.items.isNotEmpty ? controller.clear : null,
              tooltip: 'Limpar',
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (controller.hasSelection)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(Icons.edit_rounded, size: 16, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  'Editar seleção: cor e espessura abaixo',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        if (controller.hasSelection && controller.selectedIsText)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton.icon(
              onPressed: () => _showEditTextDialog(context),
              icon: const Icon(Icons.text_fields_rounded, size: 18),
              label: const Text('Editar texto da seleção'),
            ),
          ),
        Row(
          children: [
            SizedBox(
              width: 200,
              child: Slider(
                value: controller.selectedIsText ? controller.fontSize : controller.strokeWidth,
                min: controller.selectedIsText ? 8 : 1,
                max: controller.selectedIsText ? 48 : 20,
                divisions: controller.selectedIsText ? 40 : 19,
                label: controller.selectedIsText ? 'Fonte ${controller.fontSize.round()}' : 'Espessura ${controller.strokeWidth.round()}',
                onChanged: controller.selectedIsText ? controller.setFontSize : controller.setStrokeWidth,
              ),
            ),
            const SizedBox(width: 8),
            ..._palette.map((c) => Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: GestureDetector(
                    onTap: () => controller.setColor(c.value),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: controller.colorValue == c.value
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                      ),
                    ),
                  ),
                )),
          ],
        ),
        if (controller.tool == AnnotationTool.polygon) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => controller.undoLastPolygonPoint(),
                icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
                label: const Text('Desfazer ponto'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => controller.closePolygon(),
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('Fechar polígono'),
              ),
            ],
          ),
        ],
        if (controller.tool == AnnotationTool.text) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Text('Tamanho:', style: TextStyle(fontSize: 12)),
              SizedBox(
                width: 120,
                child: Slider(
                  value: controller.fontSize,
                  min: 8,
                  max: 48,
                  divisions: 40,
                  onChanged: controller.setFontSize,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: isSaving ? null : onCancel,
              child: const Text('Cancelar'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: isSaving ? null : onSave,
              child: isSaving
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    )
                  : const Text('Salvar'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompact(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 8,
          children: [
            _toolChip(context, AnnotationTool.pan, Icons.pan_tool_rounded, 'Pan'),
            _toolChip(context, AnnotationTool.select, Icons.touch_app_rounded, 'Selecionar'),
            _toolChip(context, AnnotationTool.pencil, Icons.edit_rounded, 'Lápis'),
            _toolChip(context, AnnotationTool.arrow, Icons.arrow_upward_rounded, 'Seta'),
            _toolChip(context, AnnotationTool.polygon, Icons.hexagon_outlined, 'Polígono'),
            _toolChip(context, AnnotationTool.text, Icons.text_fields_rounded, 'Texto'),
            if (controller.hasSelection)
              IconButton(
                icon: const Icon(Icons.delete_rounded),
                onPressed: controller.deleteSelected,
                tooltip: 'Excluir seleção',
              ),
            if (controller.hasSelection && controller.selectedIsText)
              IconButton(
                icon: const Icon(Icons.text_fields_rounded),
                onPressed: () => _showEditTextDialog(context),
                tooltip: 'Editar texto',
              ),
            IconButton(
              icon: const Icon(Icons.undo_rounded),
              onPressed: controller.canUndo ? controller.undo : null,
            ),
            IconButton(
              icon: const Icon(Icons.redo_rounded),
              onPressed: controller.canRedo ? controller.redo : null,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: controller.items.isNotEmpty ? controller.clear : null,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            SizedBox(
              width: 140,
              child: Slider(
                value: controller.selectedIsText ? controller.fontSize : controller.strokeWidth,
                min: controller.selectedIsText ? 8 : 1,
                max: controller.selectedIsText ? 48 : 20,
                onChanged: controller.selectedIsText ? controller.setFontSize : controller.setStrokeWidth,
              ),
            ),
            ..._palette.take(8).map((c) => GestureDetector(
                  onTap: () => controller.setColor(c.value),
                  child: Container(
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: controller.colorValue == c.value
                          ? Border.all(color: Colors.white, width: 2)
                          : null,
                    ),
                  ),
                )),
            TextButton(
              onPressed: isSaving ? null : onCancel,
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: isSaving ? null : onSave,
              child: isSaving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    )
                  : const Text('Salvar'),
            ),
          ],
        ),
      ],
    );
  }

  void _showEditTextDialog(BuildContext context) {
    final item = controller.selectedItem;
    if (item is! TextAnnotation) return;
    final textController = TextEditingController(text: item.text);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar texto'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Digite o texto',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              controller.updateSelectedText(textController.text);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _toolChip(
    BuildContext context,
    AnnotationTool tool,
    IconData icon,
    String label,
  ) {
    final selected = controller.tool == tool;
    return FilterChip(
      selected: selected,
      showCheckmark: false,
      avatar: Icon(icon, size: 18, color: selected ? Colors.white : null),
      label: Text(label, style: TextStyle(fontSize: 12)),
      onSelected: (_) => controller.setTool(tool),
    );
  }
}
