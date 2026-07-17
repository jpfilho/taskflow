import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/models/ai_assistant_config.dart';

class AiAssistantCard extends StatelessWidget {
  final AiAssistantConfig assistant;
  final VoidCallback onEdit;
  final VoidCallback onTest;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  const AiAssistantCard({
    super.key,
    required this.assistant,
    required this.onEdit,
    required this.onTest,
    required this.onDuplicate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final DateFormat formatter = DateFormat('dd/MM/yyyy HH:mm');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: dark ? Colors.grey[800]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      color: dark ? Colors.grey[900] : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    assistant.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: dark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    assistant.modelName.split('/').last.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: theme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              assistant.description.isNotEmpty
                  ? assistant.description
                  : 'Sem descrição fornecida.',
              style: TextStyle(
                fontSize: 12,
                color: dark ? Colors.grey[400] : Colors.grey[600],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Atualizado em: ${formatter.format(assistant.updatedAt)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: dark ? Colors.grey[500] : Colors.grey[500],
                  ),
                ),
                Text(
                  'v${assistant.versions.length}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: dark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.psychology_outlined),
                  tooltip: 'Testar Assistente',
                  color: Colors.blueAccent,
                  onPressed: onTest,
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Editar Assistente',
                  color: theme.primaryColor,
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.copy_outlined),
                  tooltip: 'Duplicar',
                  color: Colors.green,
                  onPressed: onDuplicate,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Excluir',
                  color: Colors.redAccent,
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
