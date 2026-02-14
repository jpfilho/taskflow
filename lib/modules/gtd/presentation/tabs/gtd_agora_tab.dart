import 'package:flutter/material.dart';

import '../../../../services/usuario_service.dart';
import '../../data/models/gtd_models.dart';
import '../../domain/gtd_session.dart';
import '../../domain/usecases/gtd_actions_usecase.dart';
import '../../domain/usecases/gtd_inbox_usecase.dart';
import '../../domain/usecases/gtd_projects_usecase.dart';
import '../widgets/gtd_card.dart';
import '../widgets/gtd_empty_state.dart';
import '../widgets/gtd_origin_capture_tile.dart';

/// Aba Agora: próximas ações com filtros e swipe actions.
class GtdAgoraTab extends StatefulWidget {
  const GtdAgoraTab({super.key});

  @override
  State<GtdAgoraTab> createState() => _GtdAgoraTabState();
}

class _GtdAgoraTabState extends State<GtdAgoraTab> {
  final _actionsUseCase = GtdActionsUseCase();
  final _projectsUseCase = GtdProjectsUseCase();
  final _inboxUseCase = GtdInboxUseCase();
  final _usuarioService = UsuarioService();

  List<GtdAction> _actions = [];
  List<GtdContext> _contexts = [];
  List<Usuario> _usuarios = [];
  final Map<String, String> _userNames = {}; // id -> nome ou email
  String? _filterContextId;
  String? _filterEnergy;
  String? _filterPriority;
  bool _filterWithDue = false;
  bool _filterWithoutDue = false;
  String _search = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _showAndamentoDialog(GtdAction a) async {
    final notesController = TextEditingController(text: a.notes ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Andamento: ${a.title.length > 30 ? "${a.title.substring(0, 30)}..." : a.title}'),
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
                              onPressed: () => Navigator.pop(c, ctrl.text.trim()),
                              child: const Text('Adicionar'),
                            ),
                          ],
                        );
                      },
                    );
                    if (update != null && update.isNotEmpty) {
                      final now = DateTime.now().toLocal();
                      final line = '\n${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} - $update';
                      notesController.text = (notesController.text + line).trim();
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
      final newNotes = notesController.text.trim().isEmpty ? null : notesController.text.trim();
      await _actionsUseCase.updateAction(a.copyWith(notes: newNotes));
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Andamento salvo.')),
        );
      }
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _contexts = await _projectsUseCase.getContexts();
    final usuarios = await _usuarioService.listarUsuarios(apenasAtivos: true);
    final names = <String, String>{};
    for (final u in usuarios) {
      if (u.id != null && u.id!.isNotEmpty) {
        names[u.id!] = u.nome?.trim().isNotEmpty == true ? u.nome! : u.email;
      }
    }
    final list = await _actionsUseCase.getNextActions(
      contextId: _filterContextId,
      energy: _filterEnergy,
      priority: _filterPriority,
      withDueOnly: _filterWithDue,
      withoutDueOnly: _filterWithoutDue,
      search: _search.isEmpty ? null : _search,
    );
    setState(() {
      _usuarios = usuarios;
      _userNames.clear();
      _userNames.addAll(names);
      _actions = list;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Buscar ações',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  setState(() => _search = v);
                  _load();
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Contexto'),
                    selected: _filterContextId != null,
                    onSelected: (_) async {
                      if (_filterContextId != null) {
                        setState(() => _filterContextId = null);
                      } else if (_contexts.isNotEmpty) {
                        final id = await showDialog<String>(
                          context: context,
                          builder: (ctx) => SimpleDialog(
                            title: const Text('Contexto'),
                            children: _contexts
                                .map(
                                  (c) => ListTile(
                                    title: Text(c.name),
                                    onTap: () => Navigator.pop(ctx, c.id),
                                  ),
                                )
                                .toList(),
                          ),
                        );
                        if (id != null) setState(() => _filterContextId = id);
                      }
                      _load();
                    },
                  ),
                  FilterChip(
                    label: Text(
                      _filterEnergy == null
                          ? 'Energia'
                          : _filterEnergy == 'low'
                          ? 'Baixa'
                          : _filterEnergy == 'med'
                          ? 'Média'
                          : 'Alta',
                    ),
                    selected: _filterEnergy != null,
                    onSelected: (_) async {
                      if (_filterEnergy != null) {
                        setState(() => _filterEnergy = null);
                      } else {
                        final v = await showDialog<String>(
                          context: context,
                          builder: (ctx) => SimpleDialog(
                            title: const Text('Energia'),
                            children: [
                              ListTile(
                                title: const Text('Baixa'),
                                onTap: () => Navigator.pop(ctx, 'low'),
                              ),
                              ListTile(
                                title: const Text('Média'),
                                onTap: () => Navigator.pop(ctx, 'med'),
                              ),
                              ListTile(
                                title: const Text('Alta'),
                                onTap: () => Navigator.pop(ctx, 'high'),
                              ),
                            ],
                          ),
                        );
                        if (v != null) setState(() => _filterEnergy = v);
                      }
                      _load();
                    },
                  ),
                  FilterChip(
                    label: Text(
                      _filterPriority == null
                          ? 'Prioridade'
                          : gtdPriorityLabel(_filterPriority!),
                    ),
                    selected: _filterPriority != null,
                    onSelected: (_) async {
                      if (_filterPriority != null) {
                        setState(() => _filterPriority = null);
                      } else {
                        final v = await showDialog<String>(
                          context: context,
                          builder: (ctx) => SimpleDialog(
                            title: const Text('Prioridade'),
                            children: [
                              ListTile(
                                title: const Text('Alta'),
                                onTap: () => Navigator.pop(ctx, 'high'),
                              ),
                              ListTile(
                                title: const Text('Média'),
                                onTap: () => Navigator.pop(ctx, 'med'),
                              ),
                              ListTile(
                                title: const Text('Baixa'),
                                onTap: () => Navigator.pop(ctx, 'low'),
                              ),
                            ],
                          ),
                        );
                        if (v != null) setState(() => _filterPriority = v);
                      }
                      _load();
                    },
                  ),
                  FilterChip(
                    label: const Text('Com data'),
                    selected: _filterWithDue,
                    onSelected: (v) {
                      setState(() {
                        _filterWithDue = v;
                        if (v) _filterWithoutDue = false;
                      });
                      _load();
                    },
                  ),
                  FilterChip(
                    label: const Text('Sem data'),
                    selected: _filterWithoutDue,
                    onSelected: (v) {
                      setState(() {
                        _filterWithoutDue = v;
                        if (v) _filterWithDue = false;
                      });
                      _load();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _actions.isEmpty
              ? const GtdEmptyState(
                  icon: Icons.play_circle_outline,
                  title: 'Nenhuma próxima ação',
                  subtitle: 'Processe o inbox ou adicione ações em Projetos.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _actions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final a = _actions[i];
                    return Dismissible(
                      key: ValueKey(a.id),
                      background: Container(
                        color: Colors.green,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 16),
                        child: const Icon(Icons.check, color: Colors.white),
                      ),
                      secondaryBackground: Container(
                        color: Colors.orange,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        child: const Icon(Icons.schedule, color: Colors.white),
                      ),
                      confirmDismiss: (direction) async {
                        if (direction == DismissDirection.startToEnd) {
                          await _actionsUseCase.completeAction(a);
                          _load();
                          return true;
                        }
                        await _actionsUseCase.moveToSomeday(a);
                        _load();
                        return true;
                      },
                      child: GtdCard(
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
                                      if (a.timeMin != null)
                                        '${a.timeMin} min',
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
                                  if (a.isRoutine || a.alarmAt != null) ...[
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: [
                                        if (a.isRoutine)
                                          Chip(
                                            label: Text(
                                              a.recurrenceRule == 'daily'
                                                  ? 'Rotina diária'
                                                  : a.recurrenceRule == 'weekly'
                                                      ? 'Rotina semanal'
                                                      : a.recurrenceRule ==
                                                              'monthly'
                                                          ? 'Rotina mensal'
                                                          : 'Rotina',
                                              style: const TextStyle(
                                                  fontSize: 12),
                                            ),
                                            padding: EdgeInsets.zero,
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                        if (a.alarmAt != null)
                                          Chip(
                                            avatar: const Icon(
                                                Icons.alarm,
                                                size: 16,
                                                color: Colors.orange),
                                            label: Text(
                                              'Alarme ${a.alarmAt!.toLocal().toString().substring(11, 16)}',
                                              style: const TextStyle(
                                                  fontSize: 12),
                                            ),
                                            padding: EdgeInsets.zero,
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    final now = DateTime.now();
                                    final date = await showDatePicker(
                                      context: context,
                                      initialDate:
                                          a.alarmAt?.toLocal() ?? now,
                                      firstDate: now,
                                      lastDate: now.add(
                                          const Duration(days: 365 * 2)),
                                    );
                                    if (date == null || !context.mounted) return;
                                    final time = await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay.fromDateTime(
                                          a.alarmAt?.toLocal() ?? now),
                                    );
                                    if (!context.mounted) return;
                                    final alarmAt = time != null
                                        ? DateTime(date.year, date.month,
                                                date.day, time.hour, time.minute)
                                            .toUtc()
                                        : DateTime(date.year, date.month,
                                                date.day)
                                            .toUtc();
                                    await _actionsUseCase.setAlarm(a, alarmAt);
                                    _load();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Alarme: ${alarmAt.toLocal().toString().substring(0, 16)}',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  icon: Icon(
                                    a.alarmAt != null
                                        ? Icons.alarm_on
                                        : Icons.alarm_add,
                                    size: 18,
                                  ),
                                  label: Text(
                                    a.alarmAt != null
                                        ? 'Alterar alarme'
                                        : 'Alarme',
                                  ),
                                ),
                                if (a.alarmAt != null) ...[
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.alarm_off, size: 20),
                                    onPressed: () async {
                                      await _actionsUseCase.setAlarm(a, null);
                                      _load();
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text('Alarme removido.'),
                                          ),
                                        );
                                      }
                                    },
                                    tooltip: 'Remover alarme',
                                  ),
                                ],
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: () => _showAndamentoDialog(a),
                                  icon: const Icon(Icons.note_add, size: 18),
                                  label: const Text('Andamento'),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    final now = DateTime.now();
                                    final date = await showDatePicker(
                                      context: context,
                                      initialDate:
                                          a.dueAt?.toLocal() ?? now,
                                      firstDate: now,
                                      lastDate: now.add(
                                          const Duration(days: 365 * 2)),
                                    );
                                    if (date == null || !context.mounted) return;
                                    final time = await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay.fromDateTime(
                                          a.dueAt?.toLocal() ?? now),
                                    );
                                    if (!context.mounted) return;
                                    final dueAt = time != null
                                        ? DateTime(date.year, date.month,
                                                date.day, time.hour, time.minute)
                                            .toUtc()
                                        : DateTime(date.year, date.month,
                                                date.day)
                                            .toUtc();
                                    await _actionsUseCase.deferAction(a, dueAt);
                                    _load();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Data definida: ${dueAt.toLocal().toString().substring(0, 16)}',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.calendar_today,
                                      size: 18),
                                  label: const Text('Calendário'),
                                ),
                                const SizedBox(width: 8),
                                FilledButton.tonalIcon(
                                  onPressed: () async {
                                    await _actionsUseCase.completeAction(a);
                                    _load();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text('Ação concluída.')),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.check, size: 18),
                                  label: const Text('Concluir'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.green.shade100,
                                    foregroundColor: Colors.green.shade800,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    final currentUserId =
                                        GtdSession.currentUserId;
                                    final delegaveis = _usuarios
                                        .where((u) =>
                                            (u.id ?? '').isNotEmpty &&
                                            u.id != currentUserId)
                                        .toList();
                                    final result = await showDialog<
                                        ({String? userId, String waitingFor})>(
                                      context: context,
                                      builder: (ctx) {
                                        final selectedId =
                                            ValueNotifier<String?>(null);
                                        final c = TextEditingController(
                                            text: a.waitingFor ?? '');
                                        return StatefulBuilder(
                                          builder: (context, setDialogState) {
                                            return AlertDialog(
                                              title: const Text('Delegar'),
                                              content: SingleChildScrollView(
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .stretch,
                                                  children: [
                                                    const Text(
                                                      'Delegar para usuário',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w500),
                                                    ),
                                                    const SizedBox(
                                                        height: 8),
                                                    DropdownButtonFormField<
                                                        String?>(
                                                      value: selectedId.value,
                                                      decoration:
                                                          const InputDecoration(
                                                        border:
                                                            OutlineInputBorder(),
                                                        contentPadding:
                                                            EdgeInsets
                                                                .symmetric(
                                                                    horizontal:
                                                                        12,
                                                                    vertical:
                                                                        8),
                                                      ),
                                                      items: [
                                                        const DropdownMenuItem<
                                                            String?>(
                                                          value: null,
                                                          child: Text('—'),
                                                        ),
                                                        ...delegaveis
                                                            .map(
                                                              (u) =>
                                                                  DropdownMenuItem<
                                                                      String?>(
                                                                value: u.id,
                                                                child: Text(
                                                                  ((u.nome ?? '').trim().isNotEmpty)
                                                                      ? (u.nome ?? '').trim()
                                                                      : u.email,
                                                                ),
                                                              ),
                                                            ),
                                                      ],
                                                      onChanged: (v) {
                                                        selectedId.value = v;
                                                        setDialogState(() {});
                                                      },
                                                    ),
                                                    const SizedBox(
                                                        height: 16),
                                                    TextField(
                                                      controller: c,
                                                      decoration:
                                                          const InputDecoration(
                                                        labelText:
                                                            'Aguardando (opcional)',
                                                        hintText:
                                                            'Ex: Resposta até sexta',
                                                      ),
                                                      maxLines: 1,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx),
                                                  child: const Text('Cancelar'),
                                                ),
                                                FilledButton(
                                                  onPressed: () {
                                                    if (selectedId.value ==
                                                            null &&
                                                        c.text.trim().isEmpty) {
                                                      ScaffoldMessenger.of(
                                                              ctx)
                                                          .showSnackBar(
                                                        const SnackBar(
                                                          content: Text(
                                                            'Selecione um usuário ou descreva o que está aguardando.'),
                                                      ));
                                                      return;
                                                    }
                                                    Navigator.pop(
                                                      ctx,
                                                      (
                                                        userId: selectedId.value,
                                                        waitingFor:
                                                            c.text.trim(),
                                                      ),
                                                    );
                                                  },
                                                  child: const Text('Delegar'),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      },
                                    );
                                    if (result != null &&
                                        (result.userId != null ||
                                            result.waitingFor.isNotEmpty)) {
                                      await _actionsUseCase.moveToWaiting(
                                        a,
                                        result.waitingFor,
                                        delegatedToUserId: result.userId,
                                      );
                                      _load();
                                      if (context.mounted) {
                                        final msg = result.userId != null
                                            ? 'Delegado para: ${_userNames[result.userId] ?? result.userId}'
                                            : 'Movido para aguardando: ${result.waitingFor}';
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(content: Text(msg)),
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.person_outline,
                                      size: 18),
                                  label: const Text('Delegar'),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    await _actionsUseCase.moveToSomeday(a);
                                    _load();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Movido para Algum dia.')),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.schedule, size: 18),
                                  label: const Text('Algum dia'),
                                ),
                                const SizedBox(width: 8),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, size: 20),
                                  onSelected: (value) async {
                                    if (value == 'edit') {
                                      final ctrl = TextEditingController(
                                        text: a.title,
                                      );
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
                                                  onPressed: () =>
                                                      Navigator.pop(ctx),
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
                                      if (result != null &&
                                          result.title.isNotEmpty &&
                                          context.mounted) {
                                        await _actionsUseCase.updateAction(
                                          a.copyWith(
                                            title: result.title,
                                            priority: result.priority,
                                            updatedAt: DateTime.now().toUtc(),
                                          ),
                                        );
                                        _load();
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text('Ação atualizada.'),
                                            ),
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
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: const Text('Cancelar'),
                                            ),
                                            FilledButton(
                                              style: FilledButton.styleFrom(
                                                backgroundColor:
                                                    Theme.of(ctx)
                                                        .colorScheme
                                                        .error,
                                              ),
                                              onPressed: () =>
                                                  Navigator.pop(ctx, true),
                                              child: const Text('Excluir'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (ok == true && context.mounted) {
                                        await _actionsUseCase.deleteAction(a);
                                        _load();
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text('Ação excluída.'),
                                            ),
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
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
