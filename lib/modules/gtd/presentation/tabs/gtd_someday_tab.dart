import 'package:flutter/material.dart';

import '../../../../services/usuario_service.dart';
import '../../data/models/gtd_models.dart';
import '../../domain/usecases/gtd_actions_usecase.dart';
import '../../domain/usecases/gtd_inbox_usecase.dart';
import '../widgets/gtd_card.dart';
import '../widgets/gtd_empty_state.dart';
import '../widgets/gtd_origin_capture_tile.dart';

/// Aba Algum dia: lista ações "algum dia/talvez" com busca e opção de colocar no calendário.
class GtdSomedayTab extends StatefulWidget {
  const GtdSomedayTab({super.key});

  @override
  State<GtdSomedayTab> createState() => _GtdSomedayTabState();
}

class _GtdSomedayTabState extends State<GtdSomedayTab> {
  final _actionsUseCase = GtdActionsUseCase();
  final _inboxUseCase = GtdInboxUseCase();
  final _usuarioService = UsuarioService();
  final _searchController = TextEditingController();
  List<GtdAction> _actions = [];
  final Map<String, String> _userNames = {};
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
    final usuarios = await _usuarioService.listarUsuarios(apenasAtivos: true);
    final names = <String, String>{};
    for (final u in usuarios) {
      if (u.id != null && u.id!.isNotEmpty) {
        names[u.id!] = u.nome?.trim().isNotEmpty == true ? u.nome! : u.email;
      }
    }
    final list = await _actionsUseCase.getSomedayActions(
      search: _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim(),
    );
    setState(() {
      _userNames.clear();
      _userNames.addAll(names);
      _actions = list;
      _loading = false;
    });
  }

  Future<void> _pickDateAndMoveToNext(GtdAction a) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: a.dueAt?.toLocal() ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (date == null || !context.mounted) return;
    final ctx = context;
    final time = await showTimePicker(
      context: ctx,
      initialTime: TimeOfDay.fromDateTime(a.dueAt?.toLocal() ?? now),
    );
    if (!ctx.mounted) return;
    final dueAt = time != null
        ? DateTime(date.year, date.month, date.day, time.hour, time.minute)
            .toUtc()
        : DateTime(date.year, date.month, date.day).toUtc();
    await _actionsUseCase.moveToNext(a, dueAt: dueAt);
    _load();
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(
            'Movido para Agora com data: ${dueAt.toLocal().toString().substring(0, 16)}',
          ),
        ),
      );
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
              hintText: 'Buscar em Algum dia',
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
                      icon: Icons.schedule,
                      title: 'Nenhum item em Algum dia',
                      subtitle:
                          'Mova ações da aba Agora para "Algum dia" ou use a busca acima.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _actions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final a = _actions[i];
                        return GtdCard(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(a.title),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      [
                                        if (a.dueAt != null)
                                          'Data: ${a.dueAt!.toLocal().toString().substring(0, 16)}',
                                        if (a.priority != null)
                                          'Prioridade: ${gtdPriorityLabel(a.priority!)}',
                                        if (a.energy != null)
                                          'Energia: ${a.energy}',
                                        if (a.notes != null &&
                                            a.notes!.isNotEmpty)
                                          a.notes!,
                                      ].join(' • '),
                                    ),
                                    if (a.sourceInboxId != null)
                                      GtdOriginCaptureTile(
                                        sourceInboxId: a.sourceInboxId!,
                                        inboxUseCase: _inboxUseCase,
                                      ),
                                    if (a.delegatedToUserId != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Delegado: ${_userNames[a.delegatedToUserId] ?? a.delegatedToUserId}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              fontStyle: FontStyle.italic,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                    if (a.waitingFor != null &&
                                        a.waitingFor!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Aguardando: ${a.waitingFor}',
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
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  FilledButton.tonalIcon(
                                    onPressed: () => _pickDateAndMoveToNext(a),
                                    icon: const Icon(Icons.calendar_today,
                                        size: 18),
                                    label: const Text('Colocar no calendário'),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      await _actionsUseCase.moveToNext(a);
                                      _load();
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Movido para Agora.'),
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.play_circle_outline,
                                        size: 18),
                                    label: const Text('Voltar para Agora'),
                                  ),
                                  const SizedBox(width: 8),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, size: 20),
                                    onSelected: (value) async {
                                      if (value == 'edit') {
                                        final ctrl = TextEditingController(text: a.title);
                                        String? selectedPriority = a.priority;
                                        GtdInboxItem? captureItem;
                                        if (a.sourceInboxId != null) {
                                          captureItem = await _inboxUseCase.getInboxItem(a.sourceInboxId!);
                                        }
                                        final result = await showDialog<
                                            ({String title, String? priority})>(
                                          context: context,
                                          builder: (ctx) => StatefulBuilder(
                                            builder: (context, setDialogState) {
                                              return AlertDialog(
                                                title: const Text('Editar ação'),
                                                content: SingleChildScrollView(
                                                  child: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                                    children: [
                                                      if (captureItem != null) ...[
                                                        Text(
                                                          'Captura que gerou esta ação:',
                                                          style: Theme.of(ctx).textTheme.labelMedium?.copyWith(
                                                            fontWeight: FontWeight.w600,
                                                            color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 4),
                                                        Container(
                                                          padding: const EdgeInsets.all(10),
                                                          decoration: BoxDecoration(
                                                            color: Theme.of(ctx).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                                                            borderRadius: BorderRadius.circular(8),
                                                          ),
                                                          child: SelectableText(
                                                            captureItem.content,
                                                            style: Theme.of(ctx).textTheme.bodySmall,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 16),
                                                      ],
                                                      TextField(
                                                        controller: ctrl,
                                                        decoration: const InputDecoration(
                                                          labelText: 'Título',
                                                          border: OutlineInputBorder(),
                                                        ),
                                                        autofocus: true,
                                                      ),
                                                      const SizedBox(height: 12),
                                                      DropdownButtonFormField<String?>(
                                                        value: selectedPriority,
                                                        decoration: const InputDecoration(
                                                          labelText: 'Prioridade',
                                                          border: OutlineInputBorder(),
                                                        ),
                                                        items: const [
                                                          DropdownMenuItem(value: null, child: Text('—')),
                                                          DropdownMenuItem(value: 'high', child: Text('Alta')),
                                                          DropdownMenuItem(value: 'med', child: Text('Média')),
                                                          DropdownMenuItem(value: 'low', child: Text('Baixa')),
                                                        ],
                                                        onChanged: (v) {
                                                          setDialogState(() => selectedPriority = v);
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(ctx),
                                                    child: const Text('Cancelar'),
                                                  ),
                                                  FilledButton(
                                                    onPressed: () => Navigator.pop(
                                                      ctx,
                                                      (title: ctrl.text.trim(), priority: selectedPriority),
                                                    ),
                                                    child: const Text('Salvar'),
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                        );
                                        if (result != null && result.title.isNotEmpty && mounted) {
                                          await _actionsUseCase.updateAction(
                                            a.copyWith(
                                              title: result.title,
                                              priority: result.priority,
                                              updatedAt: DateTime.now().toUtc(),
                                            ),
                                          );
                                          _load();
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Ação atualizada.')),
                                            );
                                          }
                                        }
                                      } else if (value == 'delete') {
                                        final ok = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('Excluir ação?'),
                                            content: const Text(
                                              'Esta ação será removida. Não é possível desfazer.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(ctx, false),
                                                child: const Text('Cancelar'),
                                              ),
                                              FilledButton(
                                                style: FilledButton.styleFrom(
                                                  backgroundColor: Theme.of(ctx).colorScheme.error,
                                                ),
                                                onPressed: () => Navigator.pop(ctx, true),
                                                child: const Text('Excluir'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (ok == true && mounted) {
                                          await _actionsUseCase.deleteAction(a);
                                          _load();
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Ação excluída.')),
                                            );
                                          }
                                        }
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit, size: 20),
                                            SizedBox(width: 12),
                                            Text('Editar'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete_outline, size: 20),
                                            SizedBox(width: 12),
                                            Text('Excluir'),
                                          ],
                                        ),
                                      ),
                                    ],
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
