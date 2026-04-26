import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  final ScrollController _scrollController = ScrollController();
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
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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

  Widget _buildStatCard(String label, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    final theme = Theme.of(context);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 12),
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalItems = _items.length;
    final bugsCriticos = _items.where((i) => i.tipo == kTipoBug && i.prioridade == 'CRITICA').length;
    final sugestoes = _items.where((i) => i.tipo == kTipoMelhoria).length;
    final roadmapCount = _versoes.length;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Central de Evolução'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Dashboard Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildStatCard('Total', totalItems.toString(), Icons.analytics_outlined, Colors.blue),
                    const SizedBox(width: 12),
                    _buildStatCard('Bugs Críticos', bugsCriticos.toString(), Icons.bug_report_outlined, Colors.red),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatCard('Sugestões', sugestoes.toString(), Icons.lightbulb_outline, Colors.amber),
                    const SizedBox(width: 12),
                    _buildStatCard(
                      'Roadmap', 
                      roadmapCount.toString(), 
                      Icons.map_outlined, 
                      Colors.green,
                      onTap: () => Navigator.pushNamed(context, '/roadmap'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              'FILTROS E ATIVIDADES',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: Colors.grey,
              ),
            ),
          ),

          // Filters Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        isExpanded: true,
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
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        isExpanded: true,
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
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Apenas Ativos'),
                  selected: _apenasAtivos,
                  onSelected: (v) {
                    setState(() => _apenasAtivos = v);
                    _load();
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Items List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _items.isEmpty
                        ? const Center(child: Text('Nenhum item encontrado'))
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                            itemCount: _items.length,
                            itemBuilder: (ctx, idx) {
                              final item = _items[idx];
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        label: const Text('Reportar'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
