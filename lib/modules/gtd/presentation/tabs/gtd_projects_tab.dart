import 'package:flutter/material.dart';

import '../../../../services/usuario_service.dart';
import '../../data/models/gtd_models.dart';
import '../../domain/usecases/gtd_actions_usecase.dart';
import '../../domain/usecases/gtd_inbox_usecase.dart';
import '../../domain/usecases/gtd_projects_usecase.dart';
import '../widgets/gtd_card.dart';
import '../widgets/gtd_empty_state.dart';
import '../widgets/gtd_origin_capture_tile.dart';

/// Aba Projetos: lista com progresso e ao abrir — ações do projeto + Adicionar ação.
class GtdProjectsTab extends StatefulWidget {
  const GtdProjectsTab({super.key});

  @override
  State<GtdProjectsTab> createState() => _GtdProjectsTabState();
}

class _GtdProjectsTabState extends State<GtdProjectsTab> {
  final _projectsUseCase = GtdProjectsUseCase();
  final _actionsUseCase = GtdActionsUseCase();
  final _inboxUseCase = GtdInboxUseCase();
  final _usuarioService = UsuarioService();

  List<GtdProject> _projects = [];
  final Map<String, String> _userNames = {};
  Map<String, ({int done, int total})> _progress = {};
  GtdProject? _selected;
  List<GtdAction> _projectActions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _projectsUseCase.getProjects();
    final progress = await _projectsUseCase.getProjectProgress();
    final usuarios = await _usuarioService.listarUsuarios(apenasAtivos: true);
    final names = <String, String>{};
    for (final u in usuarios) {
      if (u.id != null && u.id!.isNotEmpty) {
        names[u.id!] = u.nome?.trim().isNotEmpty == true ? u.nome! : u.email;
      }
    }
    setState(() {
      _projects = list;
      _progress = progress;
      _userNames.clear();
      _userNames.addAll(names);
      _loading = false;
    });
  }

  Future<void> _openProject(GtdProject p) async {
    final actions = await _actionsUseCase.getActionsByProject(p.id);
    setState(() {
      _selected = p;
      _projectActions = actions;
    });
  }

  Future<void> _addAction() async {
    if (_selected == null) return;
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('Nova ação'),
          content: TextField(
            controller: c,
            decoration: const InputDecoration(
              labelText: 'Título',
              hintText: 'Próxima ação do projeto',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('Adicionar'),
            ),
          ],
        );
      },
    );
    if (title != null && title.isNotEmpty) {
      await _actionsUseCase.createAction(
        title: title,
        projectId: _selected!.id,
      );
      _openProject(_selected!);
    }
  }

  Future<void> _showProjectAndamentoDialog() async {
    if (_selected == null) return;
    final notesController = TextEditingController(text: _selected!.notes ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Andamento: ${_selected!.name}'),
        content: SingleChildScrollView(
          child: TextField(
            controller: notesController,
            decoration: const InputDecoration(
              labelText: 'Notas / feedback do projeto',
              hintText: 'Ex: Fase 1 concluída. Próximo: orçamento.',
              alignLabelWithHint: true,
            ),
            maxLines: 5,
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
    );
    if (saved == true && _selected != null) {
      final updated = GtdProject(
        id: _selected!.id,
        userId: _selected!.userId,
        name: _selected!.name,
        notes: notesController.text.trim().isEmpty
            ? null
            : notesController.text.trim(),
        createdAt: _selected!.createdAt,
        updatedAt: DateTime.now().toUtc(),
      );
      await _projectsUseCase.updateProject(updated);
      setState(() => _selected = updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Andamento do projeto salvo.')),
        );
      }
    }
  }

  Future<void> _showActionAndamentoDialog(GtdAction a) async {
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
      _openProject(_selected!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Andamento salvo.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selected != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() => _selected = null),
            ),
            title: Text(_selected!.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.note_add),
                onPressed: () => _showProjectAndamentoDialog(),
                tooltip: 'Andamento do projeto',
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _addAction,
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar ação'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _showProjectAndamentoDialog(),
                  icon: const Icon(Icons.note_add, size: 18),
                  label: const Text('Andamento'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _projectActions.isEmpty
                ? const GtdEmptyState(
                    icon: Icons.list,
                    title: 'Nenhuma ação neste projeto',
                    subtitle: 'Toque em Adicionar ação.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _projectActions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final a = _projectActions[i];
                      return GtdCard(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                a.status == GtdActionStatus.done
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: a.status == GtdActionStatus.done
                                    ? Colors.green
                                    : null,
                              ),
                              title: Text(a.title),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    [
                                      a.status.value,
                                      if (a.priority != null)
                                        'Prioridade: ${gtdPriorityLabel(a.priority!)}',
                                      if (a.notes != null && a.notes!.isNotEmpty)
                                        a.notes!.length > 40
                                            ? '${a.notes!.substring(0, 40)}...'
                                            : a.notes!,
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
                            Padding(
                              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => _showActionAndamentoDialog(a),
                                    icon: const Icon(Icons.note_add, size: 16),
                                    label: const Text('Andamento'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    ),
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
                                                        initialValue: selectedPriority,
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
                                          _openProject(_selected!);
                                        }
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Ação atualizada.')),
                                          );
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
                                          _openProject(_selected!);
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

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_projects.isEmpty) {
      return Column(
        children: [
          const Expanded(
            child: GtdEmptyState(
              icon: Icons.folder_open,
              title: 'Nenhum projeto',
              subtitle: 'Toque em Novo projeto para criar um.',
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: _createProject,
              icon: const Icon(Icons.add),
              label: const Text('Novo projeto'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      );
    }

    return Stack(
      children: [
        ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
          itemCount: _projects.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final p = _projects[i];
            final prog = _progress[p.id] ?? (done: 0, total: 0);
            return GtdCard(
              onTap: () => _openProject(p),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(p.name,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: prog.total > 0 ? prog.done / prog.total : 0,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${prog.done} / ${prog.total} ações',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            );
          },
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: _createProject,
            tooltip: 'Novo projeto',
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  Future<void> _createProject() async {
    final nameController = TextEditingController();
    final notesController = TextEditingController();
    final created = await showDialog<GtdProject>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Novo projeto'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome do projeto',
                  hintText: 'Ex: Reforma da cozinha',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Notas (opcional)',
                  hintText: 'Detalhes do projeto',
                ),
                maxLines: 3,
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
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              final p = await _projectsUseCase.createProject(
                name,
                notes: notesController.text.trim().isEmpty
                    ? null
                    : notesController.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx, p);
            },
            child: const Text('Criar'),
          ),
        ],
      ),
    );
    if (created != null) {
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Projeto "${created.name}" criado.')),
        );
      }
    }
  }
}
