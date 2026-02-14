import 'package:flutter/material.dart';

import '../../../../services/usuario_service.dart';
import '../../data/models/gtd_models.dart';
import '../../domain/usecases/gtd_inbox_usecase.dart';
import '../../domain/usecases/gtd_actions_usecase.dart';
import '../../domain/usecases/gtd_projects_usecase.dart';
import '../../domain/usecases/gtd_reference_usecase.dart';
import '../widgets/gtd_card.dart';
import '../widgets/gtd_empty_state.dart';

/// Aba Processar: wizard por item do inbox (não processados).
class GtdProcessTab extends StatefulWidget {
  const GtdProcessTab({super.key});

  @override
  State<GtdProcessTab> createState() => _GtdProcessTabState();
}

class _GtdProcessTabState extends State<GtdProcessTab> {
  final _inboxUseCase = GtdInboxUseCase();
  final _actionsUseCase = GtdActionsUseCase();
  final _projectsUseCase = GtdProjectsUseCase();
  final _referenceUseCase = GtdReferenceUseCase();
  final _usuarioService = UsuarioService();

  List<GtdInboxItem> _unprocessed = [];
  List<Usuario> _usuarios = [];
  GtdInboxItem?
  _current; // item sendo processado (primeiro da lista não processada)
  int _step = 0;
  bool _requiresAction = true;
  String? _nextActionTitle;
  String? _projectId;
  String? _contextId;
  String? _energy;
  String? _priority;
  int? _timeMin;
  DateTime? _dueAt;
  String? _waitingFor;
  String? _delegatedToUserId;
  bool _isRoutine = false;
  String? _recurrenceRule; // daily, weekly, monthly
  DateTime? _alarmAt;
  List<GtdContext> _contexts = [];
  List<GtdProject> _projects = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _inboxUseCase.getInboxItems(unprocessedOnly: true);
    _contexts = await _projectsUseCase.getContexts();
    _projects = await _projectsUseCase.getProjects();
    final usuarios = await _usuarioService.listarUsuarios(apenasAtivos: true);
    setState(() {
      _unprocessed = list;
      _current = list.isEmpty ? null : list.first;
      _step = 0;
      _requiresAction = true;
      _nextActionTitle = null;
      _projectId = null;
      _contextId = null;
      _energy = null;
      _priority = null;
      _timeMin = null;
      _dueAt = null;
      _waitingFor = null;
      _delegatedToUserId = null;
      _usuarios = usuarios;
      _isRoutine = false;
      _recurrenceRule = null;
      _alarmAt = null;
      _loading = false;
    });
  }

  Future<void> _finishNoAction(String disposition) async {
    if (_current == null) return;
    if (disposition == 'reference' || disposition == 'someday') {
      await _referenceUseCase.createReference(_current!.content);
    }
    await _inboxUseCase.markProcessed(_current!);
    await _load();
  }

  Future<GtdProject?> _showCreateProjectDialog() async {
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
                maxLines: 2,
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
    return created;
  }

  Future<void> _finishWithAction() async {
    if (_current == null ||
        (_nextActionTitle == null || _nextActionTitle!.trim().isEmpty)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Informe a próxima ação.')));
      return;
    }
    final action = await _actionsUseCase.createAction(
      title: _nextActionTitle!.trim(),
      projectId: _projectId,
      contextId: _contextId,
      energy: _energy,
      priority: _priority,
      timeMin: _timeMin,
      dueAt: _dueAt,
      waitingFor: _waitingFor,
      isRoutine: _isRoutine,
      recurrenceRule: _recurrenceRule,
      alarmAt: _alarmAt,
      sourceInboxId: _current!.id,
      delegatedToUserId: _delegatedToUserId,
    );
    // Se preencheu "Aguardando" ou delegou para usuário, já cria como delegada (status waiting).
    if ((_waitingFor != null && _waitingFor!.trim().isNotEmpty) ||
        _delegatedToUserId != null) {
      await _actionsUseCase.moveToWaiting(
        action,
        _waitingFor?.trim() ?? '',
        delegatedToUserId: _delegatedToUserId,
      );
    }
    await _inboxUseCase.markProcessed(_current!);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_current == null) {
      return GtdEmptyState(
        icon: Icons.check_circle_outline,
        title: 'Inbox zerado',
        subtitle: _unprocessed.isEmpty
            ? 'Não há itens para processar. Use Capturar para adicionar.'
            : null,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GtdCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _current!.content,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                if (_step == 0) ...[
                  Text(
                    'Isso exige ação?',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilledButton(
                        onPressed: () => setState(() {
                          _step = 1;
                          _requiresAction = true;
                        }),
                        child: const Text('Sim'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () => setState(() {
                          _step = 1;
                          _requiresAction = false;
                        }),
                        child: const Text('Não'),
                      ),
                    ],
                  ),
                ] else if (!_requiresAction) ...[
                  Text(
                    'O que fazer?',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Lixo'),
                        selected: false,
                        onSelected: (_) => _finishNoAction('trash'),
                      ),
                      ChoiceChip(
                        label: const Text('Referência'),
                        selected: false,
                        onSelected: (_) => _finishNoAction('reference'),
                      ),
                      ChoiceChip(
                        label: const Text('Algum dia / Talvez'),
                        selected: false,
                        onSelected: (_) => _finishNoAction('someday'),
                      ),
                    ],
                  ),
                ] else ...[
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Próxima ação',
                      hintText: 'Ex: Ligar para João',
                    ),
                    onChanged: (v) => _nextActionTitle = v,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          initialValue: _projectId,
                          decoration: const InputDecoration(
                            labelText: 'Projeto',
                            hintText: 'Selecione ou crie',
                          ),
                          items: [
                            const DropdownMenuItem(
                                value: null, child: Text('—')),
                            ..._projects.map(
                              (p) => DropdownMenuItem(
                                value: p.id,
                                child: Text(p.name),
                              ),
                            ),
                            const DropdownMenuItem(
                              value: '__new_project__',
                              child: Row(
                                children: [
                                  Icon(Icons.add, size: 20),
                                  SizedBox(width: 8),
                                  Text('Novo projeto...'),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (v) async {
                            if (v == '__new_project__') {
                              final created = await _showCreateProjectDialog();
                              if (created != null && mounted) {
                                await _load();
                                setState(() => _projectId = created.id);
                              }
                            } else {
                              setState(() => _projectId = v);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final created = await _showCreateProjectDialog();
                          if (created != null && mounted) {
                            await _load();
                            setState(() => _projectId = created.id);
                          }
                        },
                        icon: const Icon(Icons.add, size: 20),
                        label: const Text('Criar'),
                      ),
                    ],
                  ),
                  if (_contexts.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: _contextId,
                      decoration: const InputDecoration(labelText: 'Contexto'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('—')),
                        ..._contexts.map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _contextId = v),
                    ),
                  ],
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: _energy,
                    decoration: const InputDecoration(labelText: 'Energia'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('—')),
                      DropdownMenuItem(value: 'low', child: Text('Baixa')),
                      DropdownMenuItem(value: 'med', child: Text('Média')),
                      DropdownMenuItem(value: 'high', child: Text('Alta')),
                    ],
                    onChanged: (v) => setState(() => _energy = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    value: _priority,
                    decoration: const InputDecoration(labelText: 'Prioridade'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('—')),
                      DropdownMenuItem(value: 'high', child: Text('Alta')),
                      DropdownMenuItem(value: 'med', child: Text('Média')),
                      DropdownMenuItem(value: 'low', child: Text('Baixa')),
                    ],
                    onChanged: (v) => setState(() => _priority = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Tempo (min)',
                      hintText: 'Ex: 15',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _timeMin = int.tryParse(v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Aguardando (opcional)',
                      hintText: 'Ex: Resposta do João',
                    ),
                    onChanged: (v) => _waitingFor = v.isEmpty ? null : v,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    value: _delegatedToUserId,
                    decoration: const InputDecoration(
                      labelText: 'Delegar para usuário (opcional)',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('—'),
                      ),
                      ..._usuarios
                          .where((u) => (u.id ?? '').isNotEmpty)
                          .map(
                            (u) => DropdownMenuItem<String?>(
                              value: u.id,
                              child: Text(
                                ((u.nome ?? '').trim().isNotEmpty)
                                    ? (u.nome ?? '').trim()
                                    : u.email,
                              ),
                            ),
                          ),
                    ],
                    onChanged: (v) => setState(() => _delegatedToUserId = v),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: _isRoutine,
                    onChanged: (v) =>
                        setState(() => _isRoutine = v ?? false),
                    title: const Text('Tarefa de rotina (recorrente)'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (_isRoutine) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String?>(
                      initialValue: _recurrenceRule,
                      decoration: const InputDecoration(
                        labelText: 'Repetir',
                        hintText: 'Frequência',
                      ),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('—')),
                        DropdownMenuItem(
                          value: 'daily',
                          child: Text('Diária'),
                        ),
                        DropdownMenuItem(
                          value: 'weekly',
                          child: Text('Semanal'),
                        ),
                        DropdownMenuItem(
                          value: 'monthly',
                          child: Text('Mensal'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _recurrenceRule = v),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final now = DateTime.now();
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _alarmAt?.toLocal() ?? now,
                            firstDate: now,
                            lastDate: now.add(const Duration(days: 365 * 2)),
                          );
                          if (date == null || !context.mounted) return;
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(
                                _alarmAt?.toLocal() ?? now),
                          );
                          if (!context.mounted) return;
                          setState(() {
                            _alarmAt = time != null
                                ? DateTime(date.year, date.month, date.day,
                                        time.hour, time.minute)
                                    .toUtc()
                                : DateTime(date.year, date.month, date.day)
                                    .toUtc();
                          });
                        },
                        icon: const Icon(Icons.alarm, size: 18),
                        label: Text(
                          _alarmAt != null
                              ? 'Alarme: ${_alarmAt!.toLocal().toString().substring(0, 16)}'
                              : 'Definir alarme',
                        ),
                      ),
                      if (_alarmAt != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _alarmAt = null),
                          tooltip: 'Remover alarme',
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final now = DateTime.now();
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _dueAt?.toLocal() ?? now,
                            firstDate: now,
                            lastDate: now.add(const Duration(days: 365 * 2)),
                          );
                          if (date == null || !context.mounted) return;
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(
                                _dueAt?.toLocal() ?? now),
                          );
                          if (!context.mounted) return;
                          setState(() {
                            _dueAt = time != null
                                ? DateTime(date.year, date.month, date.day,
                                        time.hour, time.minute)
                                    .toUtc()
                                : DateTime(date.year, date.month, date.day)
                                    .toUtc();
                          });
                        },
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(
                          _dueAt != null
                              ? 'Data: ${_dueAt!.toLocal().toString().substring(0, 16)}'
                              : 'Colocar no calendário',
                        ),
                      ),
                      if (_dueAt != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _dueAt = null),
                          tooltip: 'Limpar data',
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _finishWithAction,
                    child: const Text('Criar ação e processar'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
