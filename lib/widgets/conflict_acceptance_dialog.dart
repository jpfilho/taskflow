import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/conflict_service.dart';

/// Candidato a aceite de conflito (um recurso específico em colisão entre duas tarefas).
class ConflictAcceptanceCandidate {
  final String resourceType; // 'EXECUTOR' | 'FROTA'
  final String resourceId;
  final String resourceNome;
  final String taskIdA;
  final String taskIdB;
  final String otherTaskDescription;

  const ConflictAcceptanceCandidate({
    required this.resourceType,
    required this.resourceId,
    required this.resourceNome,
    required this.taskIdA,
    required this.taskIdB,
    required this.otherTaskDescription,
  });

  ConflictAcceptanceDraft toDraft() => ConflictAcceptanceDraft(
        resourceType: resourceType,
        resourceId: resourceId,
        resourceNome: resourceNome,
        taskIdA: taskIdA,
        taskIdB: taskIdB,
      );
}

class ConflictAcceptanceResult {
  final List<ConflictAcceptanceCandidate> selected;
  final String? reason;

  const ConflictAcceptanceResult({
    required this.selected,
    this.reason,
  });
}

/// Modal para confirmar aceite de conflito(s) de executor e/ou frota entre pares de tarefas.
class ConflictAcceptanceDialog extends StatefulWidget {
  final String currentTaskTitle;
  final DateTime day;
  final List<ConflictAcceptanceCandidate> candidates;

  const ConflictAcceptanceDialog({
    super.key,
    required this.currentTaskTitle,
    required this.day,
    required this.candidates,
  });

  static Future<ConflictAcceptanceResult?> show(
    BuildContext context, {
    required String currentTaskTitle,
    required DateTime day,
    required List<ConflictAcceptanceCandidate> candidates,
  }) {
    return showDialog<ConflictAcceptanceResult>(
      context: context,
      builder: (_) => ConflictAcceptanceDialog(
        currentTaskTitle: currentTaskTitle,
        day: day,
        candidates: candidates,
      ),
    );
  }

  @override
  State<ConflictAcceptanceDialog> createState() => _ConflictAcceptanceDialogState();
}

class _ConflictAcceptanceDialogState extends State<ConflictAcceptanceDialog> {
  late final List<bool> _selected;
  final _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selected = List<bool>.filled(widget.candidates.length, true);
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dayStr =
        '${widget.day.day.toString().padLeft(2, '0')}/${widget.day.month.toString().padLeft(2, '0')}/${widget.day.year}';
    final anySelected = _selected.any((v) => v);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.check_circle_outline, color: Colors.green[700]),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Aceitar Conflito de Agenda',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ao aceitar, o conflito deixará de aparecer para os recursos selecionados apenas entre as tarefas abaixo (novos conflitos com outras tarefas continuarão sendo alertados).',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  'Tarefa: ${widget.currentTaskTitle}\nDia referência: $dayStr',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Conflitos a aceitar:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              ...List.generate(widget.candidates.length, (i) {
                final c = widget.candidates[i];
                final isFrota = c.resourceType == 'FROTA';
                return CheckboxListTile(
                  value: _selected[i],
                  onChanged: (v) => setState(() => _selected[i] = v ?? false),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isFrota ? Colors.black87 : Colors.red[700],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isFrota ? 'FROTA' : 'EXECUTOR',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          c.resourceNome,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Entre esta tarefa ↔ ${c.otherTaskDescription}\n(O conflito será suprimido em ambas as tarefas)',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 12),
              TextField(
                controller: _reasonController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Justificativa (opcional)',
                  hintText: 'Ex.: Atendimento simultâneo autorizado na mesma subestação',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          onPressed: anySelected
              ? () {
                  final chosen = <ConflictAcceptanceCandidate>[];
                  for (var i = 0; i < widget.candidates.length; i++) {
                    if (_selected[i]) chosen.add(widget.candidates[i]);
                  }
                  Navigator.of(context).pop(
                    ConflictAcceptanceResult(
                      selected: chosen,
                      reason: _reasonController.text.trim().isEmpty
                          ? null
                          : _reasonController.text.trim(),
                    ),
                  );
                }
              : null,
          icon: const Icon(Icons.check, size: 18),
          label: const Text('Confirmar Aceite'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[700],
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

/// Modal para visualizar e revogar aceites de conflito ativos.
class ConflictAcceptancesListDialog extends StatefulWidget {
  final List<ConflictAcceptance> acceptances;
  final List<Task> allTasks;
  final Future<void> Function(ConflictAcceptance acceptance) onRevoke;

  const ConflictAcceptancesListDialog({
    super.key,
    required this.acceptances,
    required this.allTasks,
    required this.onRevoke,
  });

  static Future<void> show(
    BuildContext context, {
    required List<ConflictAcceptance> acceptances,
    required List<Task> allTasks,
    required Future<void> Function(ConflictAcceptance acceptance) onRevoke,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => ConflictAcceptancesListDialog(
        acceptances: acceptances,
        allTasks: allTasks,
        onRevoke: onRevoke,
      ),
    );
  }

  @override
  State<ConflictAcceptancesListDialog> createState() => _ConflictAcceptancesListDialogState();
}

class _ConflictAcceptancesListDialogState extends State<ConflictAcceptancesListDialog> {
  late List<ConflictAcceptance> _items;
  String? _revokingId;

  @override
  void initState() {
    super.initState();
    _items = List<ConflictAcceptance>.from(widget.acceptances);
  }

  String _taskLabel(String taskId) {
    for (final t in widget.allTasks) {
      if (t.id == taskId) {
        final local = t.locais.isNotEmpty ? '${t.locais.join(', ')} — ' : '';
        return '$local${t.tarefa}';
      }
    }
    return 'Tarefa ${taskId.length > 8 ? taskId.substring(0, 8) : taskId}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.fact_check_outlined, color: Colors.green[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Conflitos Aceitos (${_items.length})',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 620,
        height: 400,
        child: _items.isEmpty
            ? const Center(child: Text('Nenhum conflito aceito no momento.'))
            : ListView.separated(
                itemCount: _items.length,
                separatorBuilder: (_, __) => const Divider(height: 12),
                itemBuilder: (ctx, i) {
                  final a = _items[i];
                  final isFrota = a.resourceType == 'FROTA';
                  final dateStr =
                      '${a.acceptedAt.day.toString().padLeft(2, '0')}/${a.acceptedAt.month.toString().padLeft(2, '0')}/${a.acceptedAt.year}';
                  final isRevoking = _revokingId == a.id;

                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isFrota ? Colors.black87 : Colors.red[700],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            a.resourceType,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            a.resourceNome.isNotEmpty ? a.resourceNome : a.resourceId,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('• ${_taskLabel(a.taskIdA)}', style: const TextStyle(fontSize: 12)),
                          Text('• ${_taskLabel(a.taskIdB)}', style: const TextStyle(fontSize: 12)),
                          if (a.reason != null && a.reason!.trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'Motivo: ${a.reason}',
                                style: TextStyle(fontSize: 11, color: Colors.grey[700], fontStyle: FontStyle.italic),
                              ),
                            ),
                          Text(
                            'Aceito em $dateStr${a.acceptedByName != null && a.acceptedByName!.isNotEmpty ? ' por ${a.acceptedByName}' : ''}',
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    trailing: TextButton.icon(
                      onPressed: isRevoking
                          ? null
                          : () async {
                              setState(() => _revokingId = a.id);
                              try {
                                await widget.onRevoke(a);
                                if (mounted) {
                                  setState(() {
                                    _items.removeWhere((item) => item.id == a.id);
                                    _revokingId = null;
                                  });
                                }
                              } catch (_) {
                                if (mounted) setState(() => _revokingId = null);
                              }
                            },
                      icon: isRevoking
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.undo, size: 16, color: Colors.orange),
                      label: const Text('Revogar', style: TextStyle(color: Colors.orange)),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}

