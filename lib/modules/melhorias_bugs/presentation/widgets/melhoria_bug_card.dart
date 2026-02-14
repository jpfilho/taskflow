import 'package:flutter/material.dart';
import '../../../../models/melhoria_bug.dart';

class MelhoriaBugCard extends StatelessWidget {
  final MelhoriaBug item;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;

  const MelhoriaBugCard({
    super.key,
    required this.item,
    this.onTap,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isBug = item.tipo == kTipoBug;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isBug ? Colors.red.shade100 : Colors.blue.shade100,
          child: Icon(
            isBug ? Icons.bug_report : Icons.lightbulb_outline,
            color: isBug ? Colors.red.shade700 : Colors.blue.shade700,
          ),
        ),
        title: Text(
          item.titulo,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${item.statusLabel}${item.prioridade != null ? ' • ${item.prioridade}' : ''}',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed: onEdit,
        ),
        onTap: onTap,
      ),
    );
  }
}
