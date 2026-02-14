import 'package:flutter/material.dart';
import '../../../../models/melhoria_bug.dart';
import '../../../../models/versao.dart';
import '../../../../services/melhorias_bugs_service.dart';
import '../widgets/melhoria_bug_card.dart';
import '../widgets/melhoria_bug_form_dialog.dart';

class MelhoriasBugsListScreen extends StatefulWidget {
  const MelhoriasBugsListScreen({super.key});

  @override
  State<MelhoriasBugsListScreen> createState() => _MelhoriasBugsListScreenState();
}

class _MelhoriasBugsListScreenState extends State<MelhoriasBugsListScreen> {
  final MelhoriasBugsService _service = MelhoriasBugsService();
  List<MelhoriaBug> _items = [];
  List<Versao> _versoes = [];
  bool _loading = true;
  String? _filtroStatus;
  String? _filtroTipo;
  bool _apenasAtivos = true;

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final versoes = await _service.getVersoes();
      final items = await _service.getMelhoriasBugs(
        status: _filtroStatus,
        tipo: _filtroTipo,
        ativosApenas: _apenasAtivos,
      );
      if (mounted) {
        setState(() {
          _versoes = versoes;
          _items = items;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar: $e')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _openForm([MelhoriaBug? item]) async {
    final result = await showDialog<MelhoriaBug>(
      context: context,
      builder: (ctx) => MelhoriaBugFormDialog(
        initial: item,
        versoes: _versoes,
        onSave: (mb) => _service.saveMelhoriaBug(mb),
      ),
    );
    if (result != null) _load();
  }

  void _confirmDelete(MelhoriaBug item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir?'),
        content: Text('Excluir "${item.titulo}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Não'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sim'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _service.deleteMelhoriaBug(item.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                DropdownButton<String?>(
                  value: _filtroTipo,
                  hint: const Text('Tipo'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todos')),
                    const DropdownMenuItem(value: kTipoBug, child: Text('Bug')),
                    const DropdownMenuItem(value: kTipoMelhoria, child: Text('Melhoria')),
                  ],
                  onChanged: (v) {
                    setState(() => _filtroTipo = v);
                    _load();
                  },
                ),
                const SizedBox(width: 8),
                DropdownButton<String?>(
                  value: _filtroStatus,
                  hint: const Text('Status'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todos')),
                    ...kMelhoriasBugsStatusCodes.map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(melhoriaBugStatusLabel(c)),
                      ),
                    ),
                  ],
                  onChanged: (v) {
                    setState(() => _filtroStatus = v);
                    _load();
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Só ativos'),
                  selected: _apenasAtivos,
                  onSelected: (v) {
                    setState(() => _apenasAtivos = v);
                    _load();
                  },
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'Nenhum item',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return MelhoriaBugCard(
                            item: item,
                            onTap: () => _openForm(item),
                            onEdit: () => _openForm(item),
                          );
                        },
                      ),
                    ),
        ),
      ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

