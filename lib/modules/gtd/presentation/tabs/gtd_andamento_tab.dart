import 'package:flutter/material.dart';

import '../../data/models/gtd_models.dart';
import '../../domain/usecases/gtd_actions_usecase.dart';
import '../../domain/usecases/gtd_inbox_usecase.dart';
import '../widgets/gtd_card.dart';
import '../widgets/gtd_empty_state.dart';
import '../widgets/gtd_origin_capture_tile.dart';

/// Aba Em andamento: lista ações que têm andamento (notes) preenchido.
class GtdAndamentoTab extends StatefulWidget {
  const GtdAndamentoTab({super.key});

  @override
  State<GtdAndamentoTab> createState() => _GtdAndamentoTabState();
}

class _GtdAndamentoTabState extends State<GtdAndamentoTab> {
  final _actionsUseCase = GtdActionsUseCase();
  final _inboxUseCase = GtdInboxUseCase();
  final _searchController = TextEditingController();
  List<GtdAction> _actions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _actionsUseCase.getActionsWithAndamento(
      search: _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim(),
    );
    setState(() {
      _actions = list;
      _loading = false;
    });
  }

  Future<void> _showAndamentoDialog(GtdAction a) async {
    final notesController = TextEditingController(text: a.notes ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'Andamento: ${a.title.length > 30 ? "${a.title.substring(0, 30)}..." : a.title}',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notas / feedback de andamento',
                    hintText: 'Ex: 50% feito. Bloqueado por X.',
                    alignLabelWithHint: true,
                  ),
                  maxLines: 5,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final update = await showDialog<String>(
                      context: ctx,
                      builder: (c) {
                        final ctrl = TextEditingController();
                        return AlertDialog(
                          title: const Text('Adicionar atualização'),
                          content: TextField(
                            controller: ctrl,
                            decoration: const InputDecoration(
                              hintText: 'O que aconteceu?',
                            ),
                            autofocus: true,
                            maxLines: 2,
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c),
                              child: const Text('Cancelar'),
                            ),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.pop(c, ctrl.text.trim()),
                              child: const Text('Adicionar'),
                            ),
                          ],
                        );
                      },
                    );
                    if (update != null && update.isNotEmpty) {
                      final now = DateTime.now().toLocal();
                      final line =
                          '\n${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} - $update';
                      notesController.text =
                          (notesController.text + line).trim();
                      setDialogState(() {});
                    }
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Adicionar linha datada'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      final newNotes = notesController.text.trim().isEmpty
          ? null
          : notesController.text.trim();
      await _actionsUseCase.updateAction(a.copyWith(notes: newNotes));
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Andamento salvo.')),
        );
      }
    }
  }

  String _statusLabel(GtdActionStatus s) {
    switch (s) {
      case GtdActionStatus.next:
        return 'Agora';
      case GtdActionStatus.waiting:
        return 'Aguardando';
      case GtdActionStatus.someday:
        return 'Algum dia';
      case GtdActionStatus.done:
        return 'Concluída';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Buscar em Em andamento',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _load(),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _actions.isEmpty
                  ? const GtdEmptyState(
                      icon: Icons.note_alt_outlined,
                      title: 'Nenhuma ação com andamento',
                      subtitle:
                          'Use o botão "Andamento" nas ações da aba Agora (ou Projetos) para registrar progresso. Elas aparecerão aqui.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _actions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final a = _actions[i];
                        final notesPreview = a.notes != null && a.notes!.length > 120
                            ? '${a.notes!.substring(0, 120)}...'
                            : a.notes;
                        return GtdCard(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      a.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                  Chip(
                                    label: Text(
                                      _statusLabel(a.status),
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                              if (a.priority != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Prioridade: ${gtdPriorityLabel(a.priority!)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                              ],
                              if (notesPreview != null &&
                                  notesPreview.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: SelectableText(
                                    notesPreview,
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                    maxLines: 3,
                                  ),
                                ),
                              ],
                              if (a.sourceInboxId != null) ...[
                                const SizedBox(height: 8),
                                GtdOriginCaptureTile(
                                  sourceInboxId: a.sourceInboxId!,
                                  inboxUseCase: _inboxUseCase,
                                ),
                              ],
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  FilledButton.tonalIcon(
                                    onPressed: () => _showAndamentoDialog(a),
                                    icon: const Icon(Icons.note_add, size: 18),
                                    label: const Text('Andamento'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      await _actionsUseCase.completeAction(a);
                                      _load();
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text('Ação concluída.'),
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.check, size: 18),
                                    label: const Text('Concluir'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
