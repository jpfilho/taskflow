import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/models/prompt_version.dart';

class PromptVersionHistoryScreen extends StatelessWidget {
  final List<PromptVersion> versions;
  final PromptVersion? currentVersion;
  final ValueChanged<PromptVersion> onRestoreVersion;

  const PromptVersionHistoryScreen({
    super.key,
    required this.versions,
    this.currentVersion,
    required this.onRestoreVersion,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final DateFormat formatter = DateFormat('dd/MM/yyyy HH:mm');

    // Ordenar as versões (mais recente primeiro)
    final sortedVersions = List<PromptVersion>.from(versions)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de Versões'),
      ),
      body: sortedVersions.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 48,
                    color: dark ? Colors.grey[700] : Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Nenhuma versão salva encontrada.',
                    style: TextStyle(
                      fontSize: 12,
                      color: dark ? Colors.grey[500] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: sortedVersions.length,
              itemBuilder: (context, index) {
                final ver = sortedVersions[index];
                final isCurrent = currentVersion != null && ver.prompt == currentVersion!.prompt;

                return Card(
                  elevation: 1,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isCurrent
                          ? theme.primaryColor
                          : (dark ? Colors.grey[800]! : Colors.grey[200]!),
                      width: isCurrent ? 1.5 : 1,
                    ),
                  ),
                  color: dark ? Colors.grey[900] : Colors.white,
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    title: Row(
                      children: [
                        Text(
                          'Versão em ${formatter.format(ver.createdAt)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: dark ? Colors.white : Colors.black87,
                          ),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: theme.primaryColor.withOpacity(0.3)),
                            ),
                            child: Text(
                              'Ativa',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: theme.primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        ver.changeNote.isNotEmpty ? ver.changeNote : 'Sem observações.',
                        style: TextStyle(
                          fontSize: 11,
                          color: dark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10.0),
                              decoration: BoxDecoration(
                                color: dark ? Colors.grey[950] : Colors.grey[50],
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: dark ? Colors.grey[800]! : Colors.grey[300]!,
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                ver.prompt,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  color: dark ? Colors.grey[300] : Colors.black87,
                                ),
                              ),
                            ),
                            if (!isCurrent) ...[
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.settings_backup_restore, size: 16),
                                    label: const Text('Restaurar esta versão', style: TextStyle(fontSize: 12)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: theme.primaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () {
                                      _confirmRestore(context, ver);
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  void _confirmRestore(BuildContext context, PromptVersion version) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restaurar Versão', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: const Text(
          'Deseja realmente restaurar este prompt? Ele substituirá as definições atuais do assistente.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            child: const Text('Cancelar', style: TextStyle(fontSize: 12)),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
            child: const Text('Restaurar', style: TextStyle(fontSize: 12, color: Colors.white)),
            onPressed: () {
              Navigator.pop(context); // fecha modal
              onRestoreVersion(version);
              Navigator.pop(context); // volta para editor
            },
          ),
        ],
      ),
    );
  }
}
