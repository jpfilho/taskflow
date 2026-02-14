import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../models/versao.dart';
import '../../../../models/melhoria_bug.dart';
import '../../../../services/melhorias_bugs_service.dart';
import '../widgets/melhoria_bug_card.dart';
import '../widgets/melhoria_bug_form_dialog.dart';

class VersaoDetailScreen extends StatefulWidget {
  final Versao versao;
  final VoidCallback? onChanged;

  const VersaoDetailScreen({
    super.key,
    required this.versao,
    this.onChanged,
  });

  @override
  State<VersaoDetailScreen> createState() => _VersaoDetailScreenState();
}

class _VersaoDetailScreenState extends State<VersaoDetailScreen> {
  final MelhoriasBugsService _service = MelhoriasBugsService();
  List<MelhoriaBug> _items = [];
  List<Versao> _versoes = [];
  bool _loading = true;

  Versao get versao => widget.versao;

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final versoes = await _service.getVersoes();
      final items = await _service.getMelhoriasBugs(
        versaoId: versao.id,
        ativosApenas: false,
      );
      if (mounted) {
        setState(() {
          _versoes = versoes;
          _items = items;
          _loading = false;
        });
        widget.onChanged?.call();
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
        initial: item != null ? item : MelhoriaBug(id: '', tipo: kTipoMelhoria, titulo: '', status: 'BACKLOG', versaoId: versao.id),
        versoes: _versoes,
        onSave: (mb) => _service.saveMelhoriaBug(mb),
      ),
    );
    if (result != null) _load();
  }

  @override
  Widget build(BuildContext context) {
    final total = _items.length;
    final concluidos = _items.where((i) => i.status == 'CONCLUIDO').length;
    final progresso = total > 0 ? (concluidos / total) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(versao.nome),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _openForm(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (versao.descricao != null && versao.descricao!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  versao.descricao!,
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                              ),
                            Row(
                              children: [
                                if (versao.dataPrevistaLancamento != null)
                                  Text(
                                    'Previsto: ${DateFormat('dd/MM/yyyy').format(versao.dataPrevistaLancamento!)}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                  ),
                                if (versao.dataPrevistaLancamento != null) const SizedBox(width: 16),
                                Text(
                                  '$concluidos / $total itens',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: progresso,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Itens desta versão',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.grey.shade700,
                          ),
                    ),
                  ),
                ),
                _items.isEmpty
                    ? const SliverFillRemaining(
                        child: Center(
                          child: Text('Nenhum item nesta versão. Toque em + para adicionar.'),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = _items[index];
                            return MelhoriaBugCard(
                              item: item,
                              onTap: () => _openForm(item),
                              onEdit: () => _openForm(item),
                            );
                          },
                          childCount: _items.length,
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
